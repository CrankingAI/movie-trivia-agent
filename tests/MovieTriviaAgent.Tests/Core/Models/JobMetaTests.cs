using System.Text.Json;
using MovieTriviaAgent.Core.Models;

namespace MovieTriviaAgent.Tests.Core.Models;

public class JobMetaTests
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    [Fact]
    public void JobMeta_RoundTrips_ThroughJson()
    {
        var meta = new JobMeta
        {
            JobId = "abc123",
            Status = JobStatus.Completed,
            AgentVersion = "1.0.0",
            CreatedAt = DateTimeOffset.Parse("2026-01-01T00:00:00Z"),
            StartedAt = DateTimeOffset.Parse("2026-01-01T00:00:01Z"),
            CompletedAt = DateTimeOffset.Parse("2026-01-01T00:00:05Z")
        };

        var json = JsonSerializer.Serialize(meta, JsonOptions);
        var deserialized = JsonSerializer.Deserialize<JobMeta>(json, JsonOptions);

        Assert.NotNull(deserialized);
        Assert.Equal(meta.JobId, deserialized.JobId);
        Assert.Equal(meta.Status, deserialized.Status);
        Assert.Equal(meta.AgentVersion, deserialized.AgentVersion);
        Assert.Equal(meta.CreatedAt, deserialized.CreatedAt);
        Assert.Equal(meta.StartedAt, deserialized.StartedAt);
        Assert.Equal(meta.CompletedAt, deserialized.CompletedAt);
    }

    [Fact]
    public void JobMeta_WithRecord_CreatesModifiedCopy()
    {
        var meta = new JobMeta
        {
            JobId = "abc123",
            Status = JobStatus.Queued,
            AgentVersion = "1.0.0",
            CreatedAt = DateTimeOffset.UtcNow
        };

        var updated = meta with { Status = JobStatus.Running, StartedAt = DateTimeOffset.UtcNow };

        Assert.Equal(JobStatus.Queued, meta.Status);
        Assert.Equal(JobStatus.Running, updated.Status);
        Assert.Equal(meta.JobId, updated.JobId);
        Assert.NotNull(updated.StartedAt);
    }
}
