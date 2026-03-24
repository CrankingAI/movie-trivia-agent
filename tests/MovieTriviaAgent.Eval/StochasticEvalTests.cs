using AgentEval.Comparison;
using AgentEval.Core;
using AgentEval.Models;
using Microsoft.Extensions.AI;
using MovieTriviaAgent.Agent;
using MovieTriviaAgent.Core.Models;

namespace MovieTriviaAgent.Eval;

/// <summary>
/// Stochastic evaluation tests using AgentEval.
/// These tests run the agent many times and assert rating consistency.
/// Requires a live Foundry endpoint — set FOUNDRY_ENDPOINT and FOUNDRY_API_KEY env vars.
/// </summary>
public class StochasticEvalTests
{
    private static readonly string[] TestMovies =
    [
        "Citizen Kane",
        "The Godfather",
        "Santa Claus Conquers the Martians",
        "Planet of the Apes",
        "Porky's"
    ];

    /// <summary>
    /// Wraps our MovieGreatnessAgent as an IEvaluableAgent for AgentEval.
    /// </summary>
    private class MovieAgentAdapter : IEvaluableAgent
    {
        private readonly MovieGreatnessAgent _agent;

        public MovieAgentAdapter(MovieGreatnessAgent agent)
        {
            _agent = agent;
        }

        public string Name => "MovieGreatnessAgent";

        public async Task<AgentResponse> InvokeAsync(string prompt, CancellationToken cancellationToken = default)
        {
            var request = new JobRequest { Topic = prompt };
            var response = await _agent.RunAsync(request, cancellationToken);
            return new AgentResponse
            {
                Text = $"Score: {response.Score}/100. {response.Reasoning}"
            };
        }
    }

    [Theory(Skip = "Requires live Foundry endpoint")]
    [MemberData(nameof(GetTestMovies))]
    public async Task Agent_RatesConsistently_Over1000Runs(string movieName)
    {
        var agent = CreateAgent();
        var adapter = new MovieAgentAdapter(agent);

        var testCase = new TestCase
        {
            Name = $"Rate {movieName}",
            Input = movieName,
            EvaluationCriteria = ["Returns a consistent numeric score between 0-100 with reasoning"],
            PassingScore = 70
        };

        var options = new StochasticOptions(
            Runs: 1000,
            SuccessRateThreshold: 0.90,
            MaxParallelism: 10);

        var runner = new StochasticRunner(
            harness: null!, // TODO: Wire IEvaluationHarness once AgentEval stabilizes from beta
            statisticsCalculator: null,
            evaluationOptions: null);

        var result = await runner.RunStochasticTestAsync(adapter, testCase, options);

        Assert.True(result.Passed,
            $"Stochastic eval failed for '{movieName}': " +
            $"passed {result.PassedCount}/{options.Runs}");
    }

    public static TheoryData<string> GetTestMovies()
    {
        var data = new TheoryData<string>();
        foreach (var movie in TestMovies)
            data.Add(movie);
        return data;
    }

    private static MovieGreatnessAgent CreateAgent()
    {
        var endpoint = Environment.GetEnvironmentVariable("FOUNDRY_ENDPOINT")
            ?? throw new InvalidOperationException("FOUNDRY_ENDPOINT env var required");
        var apiKey = Environment.GetEnvironmentVariable("FOUNDRY_API_KEY")
            ?? throw new InvalidOperationException("FOUNDRY_API_KEY env var required");

        var openAiClient = new OpenAI.OpenAIClient(
            new System.ClientModel.ApiKeyCredential(apiKey),
            new OpenAI.OpenAIClientOptions { Endpoint = new Uri(endpoint) });

        var chatClient = openAiClient.GetChatClient("gpt-5.4").AsIChatClient();

        var pipeline = new ChatClientBuilder(chatClient)
            .UseFunctionInvocation()
            .Build();

        return new MovieGreatnessAgent(pipeline);
    }
}
