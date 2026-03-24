using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using MovieTriviaAgent.Core;
using MovieTriviaAgent.Core.Models;
using MovieTriviaAgent.Core.Services;

namespace MovieTriviaAgent.Functions.Functions;

public class SubmitJobFunction
{
    private readonly JobBlobService _blobService;
    private readonly JobQueueService _queueService;
    private readonly ILogger<SubmitJobFunction> _logger;

    public SubmitJobFunction(
        JobBlobService blobService,
        JobQueueService queueService,
        ILogger<SubmitJobFunction> logger)
    {
        _blobService = blobService;
        _queueService = queueService;
        _logger = logger;
    }

    [Function("SubmitJob")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "jobs")] HttpRequestData req,
        CancellationToken ct)
    {
        var jobRequest = await req.ReadFromJsonAsync<JobRequest>(ct);
        if (jobRequest is null || string.IsNullOrWhiteSpace(jobRequest.Topic))
        {
            var badRequest = req.CreateResponse(HttpStatusCode.BadRequest);
            await badRequest.WriteAsJsonAsync(new { error = "Request must include a 'topic' field" }, ct);
            return badRequest;
        }

        var jobId = Guid.NewGuid().ToString("N");

        await _blobService.EnsureContainerExistsAsync(ct);
        await _blobService.WriteRequestAsync(jobId, jobRequest, ct);

        var meta = new JobMeta
        {
            JobId = jobId,
            Status = JobStatus.Queued,
            AgentVersion = AgentVersion.Current,
            CreatedAt = DateTimeOffset.UtcNow
        };
        await _blobService.WriteMetaAsync(jobId, meta, ct);

        await _queueService.EnsureQueueExistsAsync(ct);
        await _queueService.EnqueueJobAsync(jobId, ct);

        _logger.LogInformation("Job {JobId} submitted for topic: {Topic}", jobId, jobRequest.Topic);

        var response = req.CreateResponse(HttpStatusCode.Accepted);
        await response.WriteAsJsonAsync(new { jobId }, ct);
        return response;
    }
}
