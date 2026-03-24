using System.Text.Json;
using Microsoft.Extensions.AI;
using MovieTriviaAgent.Core.Models;

namespace MovieTriviaAgent.Agent;

public class MovieGreatnessAgent
{
    private readonly IChatClient _chatClient;

    public MovieGreatnessAgent(IChatClient chatClient)
    {
        _chatClient = chatClient;
    }

    public async Task<JobResponse> RunAsync(JobRequest request, CancellationToken ct = default)
    {
        var messages = new List<ChatMessage>
        {
            new(ChatRole.System,
                """
                You are a movie critic AI. When given a movie name, evaluate it for "greatness"
                on a scale from 0 (worst ever) to 100 (cannot possibly be better).
                Consider acting, direction, cultural impact, writing, and entertainment value.
                """),
            new(ChatRole.User, $"Rate the movie: {request.Topic}")
        };

        var response = await _chatClient.GetResponseAsync<MovieRating>(messages, cancellationToken: ct);

        if (response.Result is { } rating)
        {
            return new JobResponse
            {
                Score = Math.Clamp(rating.Score, 0, 100),
                Reasoning = rating.Reasoning
            };
        }

        return new JobResponse
        {
            Score = -1,
            Reasoning = $"Agent did not produce a structured rating. Raw response: {response.Text}"
        };
    }

    private record MovieRating(int Score, string Reasoning);
}
