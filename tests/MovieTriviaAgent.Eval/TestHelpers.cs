using Azure;
using Azure.AI.OpenAI;
using Microsoft.Extensions.AI;

namespace MovieTriviaAgent.Eval;

internal static class TestHelpers
{
    internal static IChatClient CreateChatClient()
    {
        var endpoint = Environment.GetEnvironmentVariable("FOUNDRY_ENDPOINT")
            ?? throw new InvalidOperationException("FOUNDRY_ENDPOINT env var required");
        var apiKey = Environment.GetEnvironmentVariable("FOUNDRY_API_KEY")
            ?? throw new InvalidOperationException("FOUNDRY_API_KEY env var required");
        var modelId = Environment.GetEnvironmentVariable("FOUNDRY_MODEL_ID") ?? "gpt-5.4";

        var azureClient = new AzureOpenAIClient(new Uri(endpoint), new AzureKeyCredential(apiKey));
        return azureClient.GetChatClient(modelId).AsIChatClient();
    }

    internal static MovieTriviaAgent.Agent.MovieGreatnessAgent CreateAgent()
    {
        var chatClient = CreateChatClient();
        var modelId = Environment.GetEnvironmentVariable("FOUNDRY_MODEL_ID") ?? "gpt-5.4";
        var pipeline = new ChatClientBuilder(chatClient)
            .UseFunctionInvocation()
            .Build();

        return new MovieTriviaAgent.Agent.MovieGreatnessAgent(pipeline,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<MovieTriviaAgent.Agent.MovieGreatnessAgent>.Instance,
            new MovieTriviaAgent.Agent.AgentOptions { ModelId = modelId });
    }
}
