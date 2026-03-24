var builder = DistributedApplication.CreateBuilder(args);

var foundryEndpoint = builder.AddParameter("foundry-endpoint", secret: false);
var foundryApiKey = builder.AddParameter("foundry-apikey", secret: true);

var storage = builder.AddAzureStorage("storage")
    .RunAsEmulator();

var blobs = storage.AddBlobs("blobs");
var queues = storage.AddQueues("queues");

builder.AddAzureFunctionsProject<Projects.MovieTriviaAgent_Functions>("functions")
    .WithHostStorage(storage)
    .WithReference(blobs)
    .WithReference(queues)
    .WithEnvironment("Foundry__Endpoint", foundryEndpoint)
    .WithEnvironment("Foundry__ApiKey", foundryApiKey);

builder.Build().Run();
