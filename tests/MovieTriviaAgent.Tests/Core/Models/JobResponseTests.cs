using System.Text.Json;
using MovieTriviaAgent.Core.Models;

namespace MovieTriviaAgent.Tests.Core.Models;

public class JobResponseTests
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    [Fact]
    public void JobResponse_RoundTrips_ThroughJson()
    {
        var response = new JobResponse { Score = 95, Reasoning = "A masterpiece." };
        var json = JsonSerializer.Serialize(response, JsonOptions);
        var deserialized = JsonSerializer.Deserialize<JobResponse>(json, JsonOptions);

        Assert.NotNull(deserialized);
        Assert.Equal(95, deserialized.Score);
        Assert.Equal("A masterpiece.", deserialized.Reasoning);
    }
}
