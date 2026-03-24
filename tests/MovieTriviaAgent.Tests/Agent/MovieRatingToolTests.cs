using MovieTriviaAgent.Agent.Tools;

namespace MovieTriviaAgent.Tests.Agent;

public class MovieRatingToolTests
{
    [Fact]
    public void RateMovie_ReturnsResult_WithCorrectValues()
    {
        var result = MovieRatingTool.RateMovie("Citizen Kane", 95, "Groundbreaking cinema");

        Assert.Equal("Citizen Kane", result.MovieName);
        Assert.Equal(95, result.Score);
        Assert.Equal("Groundbreaking cinema", result.Reasoning);
    }

    [Theory]
    [InlineData(-10, 0)]
    [InlineData(150, 100)]
    [InlineData(50, 50)]
    public void RateMovie_ClampsScore_ToValidRange(int input, int expected)
    {
        var result = MovieRatingTool.RateMovie("Test Movie", input, "Test");
        Assert.Equal(expected, result.Score);
    }
}
