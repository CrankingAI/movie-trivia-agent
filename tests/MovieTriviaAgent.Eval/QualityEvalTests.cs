using Microsoft.Extensions.AI;
using Microsoft.Extensions.AI.Evaluation;
using Microsoft.Extensions.AI.Evaluation.Quality;

namespace MovieTriviaAgent.Eval;

/// <summary>
/// Quality evaluation tests using Microsoft.Extensions.AI.Evaluation.
/// Assesses agent output quality with structured metrics.
/// Requires a live Foundry endpoint — set FOUNDRY_ENDPOINT and FOUNDRY_API_KEY env vars.
/// </summary>
public class QualityEvalTests
{
    [Fact(Skip = "Requires live Foundry endpoint")]
    public async Task Agent_Output_MeetsQualityMetrics()
    {
        var chatClient = CreateEvalChatClient();

        // Set up evaluators for quality assessment
        var coherenceEvaluator = new CoherenceEvaluator();
        var relevanceEvaluator = new RelevanceEvaluator();
        var compositeEvaluator = new CompositeEvaluator(coherenceEvaluator, relevanceEvaluator);

        // Create the chat configuration for evaluation
        var chatConfig = new ChatConfiguration(chatClient);

        // Simulate agent conversation for evaluation
        var messages = new List<ChatMessage>
        {
            new(ChatRole.User, "Rate the movie: The Godfather")
        };

        var response = await chatClient.GetResponseAsync(messages);

        // Run evaluation
        var result = await compositeEvaluator.EvaluateAsync(messages, response, chatConfig);

        // Assert quality metrics
        foreach (var metric in result.Metrics)
        {
            if (metric.Value is NumericMetric numericMetric)
            {
                Assert.True(numericMetric.Value >= 3,
                    $"Metric '{metric.Key}' scored {numericMetric.Value}, expected >= 3");
            }

            // Check for no errors in diagnostics
            var errors = metric.Value.Diagnostics?
                .Where(d => d.Severity == EvaluationDiagnosticSeverity.Error)
                .ToList();
            Assert.True(errors is null or [],
                $"Metric '{metric.Key}' had evaluation errors");
        }
    }

    [Fact(Skip = "Requires live Foundry endpoint")]
    public async Task Agent_Rating_IsNumericAndInRange()
    {
        var agent = CreateAgent();
        var request = new MovieTriviaAgent.Core.Models.JobRequest { Topic = "Citizen Kane" };

        var response = await agent.RunAsync(request);

        Assert.InRange(response.Score, 0, 100);
        Assert.False(string.IsNullOrWhiteSpace(response.Reasoning));
    }

    private static IChatClient CreateEvalChatClient()
    {
        var endpoint = Environment.GetEnvironmentVariable("FOUNDRY_ENDPOINT")
            ?? throw new InvalidOperationException("FOUNDRY_ENDPOINT env var required");
        var apiKey = Environment.GetEnvironmentVariable("FOUNDRY_API_KEY")
            ?? throw new InvalidOperationException("FOUNDRY_API_KEY env var required");

        var openAiClient = new OpenAI.OpenAIClient(
            new System.ClientModel.ApiKeyCredential(apiKey),
            new OpenAI.OpenAIClientOptions { Endpoint = new Uri(endpoint) });

        return openAiClient.GetChatClient("gpt-5.4").AsIChatClient();
    }

    private static MovieTriviaAgent.Agent.MovieGreatnessAgent CreateAgent()
    {
        var chatClient = CreateEvalChatClient();
        var pipeline = new ChatClientBuilder(chatClient)
            .UseFunctionInvocation()
            .Build();

        return new MovieTriviaAgent.Agent.MovieGreatnessAgent(pipeline);
    }
}
