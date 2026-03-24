using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using MovieTriviaAgent.Core.Models;
using MovieTriviaAgent.Core.Services;

namespace MovieTriviaAgent.Functions.Functions;

public class GetJobFunction
{
    private readonly JobBlobService _blobService;

    public GetJobFunction(JobBlobService blobService)
    {
        _blobService = blobService;
    }

    [Function("GetJob")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "jobs/{jobId}")] HttpRequestData req,
        string jobId,
        CancellationToken ct)
    {
        var meta = await _blobService.ReadMetaAsync(jobId, ct);
        if (meta is null)
        {
            var notFound = req.CreateResponse(HttpStatusCode.NotFound);
            await notFound.WriteAsJsonAsync(new { error = "Job not found" }, ct);
            return notFound;
        }

        JobResponse? result = null;
        if (meta.Status == JobStatus.Completed)
        {
            result = await _blobService.ReadResponseAsync(jobId, ct);
        }

        var response = req.CreateResponse(HttpStatusCode.OK);
        await response.WriteAsJsonAsync(new { meta, result }, ct);
        return response;
    }
}
