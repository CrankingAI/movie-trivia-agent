using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using MovieTriviaAgent.Agent;
using MovieTriviaAgent.Core;
using MovieTriviaAgent.Core.Models;
using MovieTriviaAgent.Core.Services;

namespace MovieTriviaAgent.Functions.Functions;

public class RunJobFunction
{
    private readonly JobBlobService _blobService;
    private readonly MovieGreatnessAgent _agent;
    private readonly ILogger<RunJobFunction> _logger;

    public RunJobFunction(
        JobBlobService blobService,
        MovieGreatnessAgent agent,
        ILogger<RunJobFunction> logger)
    {
        _blobService = blobService;
        _agent = agent;
        _logger = logger;
    }

    [Function("RunJob")]
    public async Task Run(
        [QueueTrigger("job-requests", Connection = "AzureWebJobsStorage")] string jobId,
        CancellationToken ct)
    {
        _logger.LogInformation("Processing job {JobId}", jobId);

        var request = await _blobService.ReadRequestAsync(jobId, ct);
        if (request is null)
        {
            _logger.LogError("Job {JobId}: request.json not found", jobId);
            return;
        }

        var meta = await _blobService.ReadMetaAsync(jobId, ct);
        if (meta is null)
        {
            _logger.LogError("Job {JobId}: meta.json not found", jobId);
            return;
        }

        meta = meta with
        {
            Status = JobStatus.Running,
            StartedAt = DateTimeOffset.UtcNow
        };
        await _blobService.WriteMetaAsync(jobId, meta, ct);

        try
        {
            var result = await _agent.RunAsync(request, ct);
            await _blobService.WriteResponseAsync(jobId, result, ct);

            meta = meta with
            {
                Status = JobStatus.Completed,
                CompletedAt = DateTimeOffset.UtcNow
            };
            await _blobService.WriteMetaAsync(jobId, meta, ct);

            _logger.LogInformation("Job {JobId} completed. Score: {Score}", jobId, result.Score);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Job {JobId} failed", jobId);

            meta = meta with
            {
                Status = JobStatus.Failed,
                CompletedAt = DateTimeOffset.UtcNow,
                Error = ex.Message
            };
            await _blobService.WriteMetaAsync(jobId, meta, ct);
        }
    }
}
