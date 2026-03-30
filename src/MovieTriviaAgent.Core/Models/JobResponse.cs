namespace MovieTriviaAgent.Core.Models;

public record JobResponse
{
    public required string RequestedMovie { get; init; }
    public required string RatedMovie { get; init; }
    public required int Score { get; init; }
    public required string Reasoning { get; init; }
    public SubScores? SubScores { get; init; }
    public IReadOnlyList<string>? Pros { get; init; }
    public IReadOnlyList<string>? Cons { get; init; }
    public IReadOnlyList<string>? Conflicts { get; init; }
}

public record SubScores
{
    public required int Popularity { get; init; }
    public required int ArtisticValue { get; init; }
    public required int Iconicness { get; init; }
}
