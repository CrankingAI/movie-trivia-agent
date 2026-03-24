using System.ComponentModel;
using Microsoft.Extensions.AI;

namespace MovieTriviaAgent.Agent.Tools;

public static class MovieRatingTool
{
    [Description("Rates a movie for greatness on a scale of 0-100, where 0 is the worst movie ever made and 100 means it cannot possibly be better.")]
    public static MovieRatingResult RateMovie(
        [Description("The name of the movie to rate")] string movieName,
        [Description("The greatness score from 0 to 100")] int score,
        [Description("A brief explanation of why the movie received this score")] string reasoning)
    {
        return new MovieRatingResult(movieName, Math.Clamp(score, 0, 100), reasoning);
    }
}

public record MovieRatingResult(string MovieName, int Score, string Reasoning);
