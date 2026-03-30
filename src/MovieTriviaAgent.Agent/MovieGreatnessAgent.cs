using System.Diagnostics;
using Microsoft.Agents.AI.Workflows;
using Microsoft.Extensions.AI;
using Microsoft.Extensions.Logging;
using MovieTriviaAgent.Agent.Executors;
using MovieTriviaAgent.Agent.Models;
using MovieTriviaAgent.Core;
using MovieTriviaAgent.Core.Models;
using MovieTriviaAgent.Core.Observability;

namespace MovieTriviaAgent.Agent;

public class MovieGreatnessAgent
{
    private static readonly ActivitySource ActivitySourceInstance = new("MovieTriviaAgent.Agent");
    private static readonly string TitleResolutionPrompt =
        """
        You resolve movie titles for a rating system.
        Given a user-provided movie request, return the most likely exact movie title that should be rated.
        Rules:
        - Keep RequestedMovie exactly as provided.
        - Set RatedMovie to the canonical movie title you believe the user intended.
        - Fix obvious punctuation, spacing, apostrophes, accents, subtitles, and common misspellings when confidence is high.
        - If the request is already a clear exact movie title, keep RatedMovie the same as RequestedMovie.
        - Do not add commentary.
        """;

    private readonly IChatClient _chatClient;
    private readonly ILogger<MovieGreatnessAgent> _logger;
    private readonly string _modelId;

    public MovieGreatnessAgent(IChatClient chatClient, ILogger<MovieGreatnessAgent> logger, AgentOptions options)
    {
        _chatClient = chatClient;
        _logger = logger;
        _modelId = options.ModelId;
    }

    public async Task<JobResponse> RunAsync(JobRequest request, CancellationToken ct = default)
    {
        using var activity = ActivitySourceInstance.StartActivity(
            "invoke_agent MovieGreatnessAgent",
            ActivityKind.Internal);
        activity?.SetTag("gen_ai.operation.name", "invoke_agent");
        activity?.SetTag("gen_ai.agent.name", "MovieGreatnessAgent");
        activity?.SetTag("gen_ai.agent.version", AgentVersion.Current);
        activity?.SetTag(TelemetryTags.MovieRequested, request.Topic);

        var movieSelection = await ResolveMovieSelectionAsync(request.Topic, ct);
        activity?.SetTag(TelemetryTags.MovieRequested, movieSelection.RequestedMovie);
        activity?.SetTag(TelemetryTags.MovieRated, movieSelection.RatedMovie);

        var workflow = BuildWorkflow();
        var run = await InProcessExecution.RunAsync<string>(workflow, movieSelection.RatedMovie, sessionId: Guid.NewGuid().ToString(), ct);

        WorkflowResult? workflowResult = null;
        foreach (var evt in run.OutgoingEvents)
        {
            if (evt is WorkflowOutputEvent outputEvt && outputEvt.Is<WorkflowResult>(out var result))
            {
                workflowResult = result;
                break;
            }
        }

        if (workflowResult is null)
        {
            return new JobResponse
            {
                RequestedMovie = movieSelection.RequestedMovie,
                RatedMovie = movieSelection.RatedMovie,
                Score = -1,
                Reasoning = "Workflow did not produce a result.",
            };
        }

        var reasoning = $"Popularity: {workflowResult.SubScores.Popularity}/100 (30%), " +
                        $"Artistic Value: {workflowResult.SubScores.ArtisticValue}/100 (40%), " +
                        $"Iconicness: {workflowResult.SubScores.Iconicness}/100 (30%) → " +
                        $"Weighted Score: {workflowResult.Score}/100";

        return new JobResponse
        {
            RequestedMovie = movieSelection.RequestedMovie,
            RatedMovie = movieSelection.RatedMovie,
            Score = workflowResult.Score,
            Reasoning = reasoning,
            SubScores = new SubScores
            {
                Popularity = workflowResult.SubScores.Popularity,
                ArtisticValue = workflowResult.SubScores.ArtisticValue,
                Iconicness = workflowResult.SubScores.Iconicness,
            },
            Pros = workflowResult.ProsConsRollup.Pros,
            Cons = workflowResult.ProsConsRollup.Cons,
            Conflicts = workflowResult.ProsConsRollup.Conflicts,
        };
    }

    private async Task<MovieSelection> ResolveMovieSelectionAsync(string requestedMovie, CancellationToken ct)
    {
        using var activity = ActivitySourceInstance.StartActivity("chat ResolveMovieTitle");
        activity?.SetTag("gen_ai.operation.name", "chat");
        activity?.SetTag("gen_ai.agent.name", "ResolveMovieTitle");
        activity?.SetTag("gen_ai.request.model", _modelId);
        activity?.SetTag("gen_ai.provider.name", "azure.ai.inference");
        activity?.SetTag("azure.resource_provider.namespace", "Microsoft.CognitiveServices");

        var normalizedRequestedMovie = requestedMovie.Trim();

        try
        {
            var response = await _chatClient.GetResponseAsync<MovieSelection>(
                [
                    new(ChatRole.System, TitleResolutionPrompt),
                    new(ChatRole.User, normalizedRequestedMovie)
                ],
                cancellationToken: ct);

            var selection = response.Result;
            if (selection is not null
                && !string.IsNullOrWhiteSpace(selection.RequestedMovie)
                && !string.IsNullOrWhiteSpace(selection.RatedMovie))
            {
                var resolvedRequestedMovie = selection.RequestedMovie?.Trim();
                var resolvedRatedMovie = selection.RatedMovie?.Trim();

                if (!string.IsNullOrWhiteSpace(resolvedRequestedMovie)
                    && !string.IsNullOrWhiteSpace(resolvedRatedMovie))
                {
                    return new MovieSelection(resolvedRequestedMovie, resolvedRatedMovie);
                }

                return selection with
                {
                    RequestedMovie = normalizedRequestedMovie,
                    RatedMovie = normalizedRequestedMovie
                };
            }
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "Failed to resolve movie title for request '{RequestedMovie}'", normalizedRequestedMovie);
        }

        return new MovieSelection(normalizedRequestedMovie, normalizedRequestedMovie);
    }

    private Workflow BuildWorkflow()
    {
        var chatClient = _chatClient;
        Func<string, string> forwardRequestedMovie = static movie => movie;

        // 1. Start — entry point, forwards movie name to fan-out
        var start = ExecutorBindingExtensions.BindAsExecutor(
            forwardRequestedMovie!, "Start");

        // 2-4. Three parallel scorer executors
        var popularityScorer = CreateScorerBinding(ScorerExecutors.PopularityId, chatClient, _modelId);
        var artisticScorer = CreateScorerBinding(ScorerExecutors.ArtisticValueId, chatClient, _modelId);
        var iconicnessScorer = CreateScorerBinding(ScorerExecutors.IconicnessId, chatClient, _modelId);

        // 5. ResultCollector — accumulates 3 ScorerResults from the fan-in barrier.
        //    The barrier guarantees all 3 arrive before any are delivered, and they
        //    are processed sequentially within the SuperStep. We return the current
        //    aggregate and only forward the completed set once all three results exist.
        var collectedResults = new List<ScorerResult>();
        var resultCollector = ExecutorBindingExtensions.BindAsExecutor<ScorerResult, ScorerResultSet>(
            (ScorerResult result) =>
            {
                collectedResults.Add(result);
                return new ScorerResultSet
                {
                    Results = collectedResults.ToList()
                };
            },
            "ResultCollector");

        // 6. ProsConsRollup — LLM-based semantic merge of pros/cons with conflict detection
        var modelId = _modelId;
        var prosConsRollup = ExecutorBindingExtensions.BindAsExecutor<ScorerResultSet, RollupInput>(
            async (ScorerResultSet scorerResultSet, IWorkflowContext ctx, CancellationToken ct) =>
            {
                using var activity = ActivitySourceInstance.StartActivity(
                    $"chat {ProsConsRollupExecutor.Id}");
                activity?.SetTag("gen_ai.operation.name", "chat");
                activity?.SetTag("gen_ai.agent.name", ProsConsRollupExecutor.Id);
                activity?.SetTag("gen_ai.request.model", modelId);
                activity?.SetTag("gen_ai.provider.name", "azure.ai.inference");
                activity?.SetTag("azure.resource_provider.namespace", "Microsoft.CognitiveServices");

                var rollup = await ProsConsRollupExecutor.RunAsync(
                    scorerResultSet.Results, chatClient, ct);

                return new RollupInput
                {
                    ScorerResults = scorerResultSet,
                    ProsConsRollup = rollup,
                };
            },
            ProsConsRollupExecutor.Id);

        // 7. WeightedScoreRollup — pure computation (no LLM): 30/40/30 weighted average
        var weightedRollup = ExecutorBindingExtensions.BindAsExecutor<RollupInput, WorkflowResult>(
            (RollupInput input) =>
            {
                var (score, subScores) = WeightedScoreRollupExecutor.Calculate(
                    input.ScorerResults.Results);

                return new WorkflowResult
                {
                    Score = score,
                    ProsConsRollup = input.ProsConsRollup,
                    SubScores = subScores,
                };
            },
            WeightedScoreRollupExecutor.Id);

        // Wire the graph:
        // Start ──fanout──┬── PopularityScorer   ──┐
        //                 ├── ArtisticValueScorer ──┼──barrier──> ResultCollector ──> ProsConsRollup ──> WeightedScoreRollup
        //                 └── IconicnessScorer    ──┘
        var scorers = new[] { popularityScorer, artisticScorer, iconicnessScorer };

        var workflow = new WorkflowBuilder(start)
            .WithName("MovieGreatnessWorkflow")
            .AddFanOutEdge(start, scorers)
            .AddFanInBarrierEdge(scorers, resultCollector)
            .AddEdge<ScorerResultSet>(resultCollector, prosConsRollup, resultSet => resultSet?.Results?.Count == 3)
            .AddEdge(prosConsRollup, weightedRollup)
            .WithOutputFrom(weightedRollup)
            .WithOpenTelemetry(opts =>
            {
                opts.EnableSensitiveData = false;
            }, ActivitySourceInstance)
            .Build();

        EmitMermaidDiagram(workflow);

        return workflow;
    }

    private static ExecutorBinding CreateScorerBinding(string category, IChatClient chatClient, string modelId)
    {
        var scorer = ScorerExecutors.CreateScorer(category);

        return ExecutorBindingExtensions.BindAsExecutor<string, ScorerResult>(
            async (string movieName, IWorkflowContext ctx, CancellationToken ct) =>
            {
                using var activity = ActivitySourceInstance.StartActivity($"chat {category}");
                activity?.SetTag("gen_ai.operation.name", "chat");
                activity?.SetTag("gen_ai.agent.name", category);
                activity?.SetTag("gen_ai.request.model", modelId);
                activity?.SetTag("gen_ai.provider.name", "azure.ai.inference");
                activity?.SetTag("azure.resource_provider.namespace", "Microsoft.CognitiveServices");

                return await scorer(movieName, chatClient, ct);
            },
            category);
    }

    private void EmitMermaidDiagram(Workflow workflow)
    {
        try
        {
            var repoRoot = FindRepoRoot();
            if (repoRoot is not null)
            {
                var path = Path.Combine(repoRoot, "workflow.mmd");
                var mermaid = WorkflowVisualizer.ToMermaidString(workflow);
                File.WriteAllText(path, mermaid);
                _logger.LogInformation("Workflow diagram written to {Path}", path);
            }
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "Failed to write workflow diagram");
        }
    }

    private static string? FindRepoRoot()
    {
        var dir = AppContext.BaseDirectory;
        while (dir is not null)
        {
            if (File.Exists(Path.Combine(dir, "MovieTriviaAgent.slnx")))
                return dir;
            dir = Path.GetDirectoryName(dir);
        }
        return null;
    }

    private sealed record MovieSelection(string RequestedMovie, string RatedMovie);
}
