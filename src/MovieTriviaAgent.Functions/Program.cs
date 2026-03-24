using Azure.Storage.Blobs;
using Azure.Storage.Queues;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using MovieTriviaAgent.Agent;
using MovieTriviaAgent.Core.Services;

var builder = FunctionsApplication.CreateBuilder(args);

var storageConnectionString = builder.Configuration["AzureWebJobsStorage"]
    ?? "UseDevelopmentStorage=true";

builder.Services.AddSingleton(_ => new BlobServiceClient(storageConnectionString));
builder.Services.AddSingleton(_ => new QueueServiceClient(storageConnectionString, new QueueClientOptions
{
    MessageEncoding = QueueMessageEncoding.Base64
}));
builder.Services.AddSingleton<JobBlobService>();
builder.Services.AddSingleton<JobQueueService>();

var foundryEndpoint = builder.Configuration["Foundry:Endpoint"]
    ?? throw new InvalidOperationException("Foundry:Endpoint configuration is required");
var foundryApiKey = builder.Configuration["Foundry:ApiKey"]
    ?? throw new InvalidOperationException("Foundry:ApiKey configuration is required");

builder.Services.AddMovieGreatnessAgent(
    new Uri(foundryEndpoint),
    foundryApiKey);

builder.Build().Run();
