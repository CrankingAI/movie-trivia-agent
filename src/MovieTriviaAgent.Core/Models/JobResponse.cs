namespace MovieTriviaAgent.Core.Models;

public record JobResponse
{
    public required int Score { get; init; }
    public required string Reasoning { get; init; }
}
