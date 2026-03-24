# movie-trivia-agent

An AI agent helpful with movie trivia. A "movie" in this context is generally a mainstream (Hollywood) movie.

## Local Development

**Prerequisites:** .NET 10 SDK, Docker (for Azurite via Aspire), Azure Functions Core Tools (`func`)

### Build & Test

```bash
dotnet build MovieTriviaAgent.slnx
dotnet test MovieTriviaAgent.slnx
```

Run a single test:
```bash
dotnet test tests/MovieTriviaAgent.Tests --filter "MovieRatingToolTests"
```

### Run Locally (Aspire)

```bash
./scripts/local-run.sh
```

This starts the Aspire AppHost with Azurite (storage emulator) and the Functions app. The Aspire dashboard opens at `https://localhost:15888`.

Set your Foundry credentials in Aspire user secrets:
```bash
dotnet user-secrets set "Foundry:Endpoint" "https://YOUR-ENDPOINT.openai.azure.com/" --project aspire/MovieTriviaAgent.AppHost
dotnet user-secrets set "Foundry:ApiKey" "YOUR-KEY" --project aspire/MovieTriviaAgent.AppHost
```

### Run Locally (Functions standalone)

Edit `src/MovieTriviaAgent.Functions/local.settings.json` with your Foundry endpoint and API key, then:
```bash
cd src/MovieTriviaAgent.Functions
func start
```

### Test the API

```bash
# Submit a job
curl -X POST http://localhost:7071/api/jobs \
  -H "Content-Type: application/json" \
  -d '{"topic": "The Godfather"}'

# Check job status (use the jobId from above)
curl http://localhost:7071/api/jobs/{jobId}
```

## Cloud

### View Telemetry

```bash
./scripts/view-otel.sh                  # last 1 hour
./scripts/view-otel.sh --timespan PT4H  # last 4 hours
```

### Test the Deployed API

```bash
FUNC_HOST="func-movie-trivia-agent-dev.azurewebsites.net"

# Submit
curl -X POST "https://$FUNC_HOST/api/jobs" \
  -H "Content-Type: application/json" \
  -d '{"topic": "Citizen Kane"}'

# Poll status
curl "https://$FUNC_HOST/api/jobs/{jobId}"
```

## Initial Cloud Deploy (Step by Step)

1. **Login to Azure and GitHub CLIs:**
   ```bash
   az login
   gh auth login
   ```

2. **Deploy infrastructure + code:**
   ```bash
   ./scripts/deploy.sh
   ```
   This runs `az deployment sub create` with the Bicep templates (creates resource group, storage, Foundry + gpt-5.4, App Insights, Function App) then publishes the Functions code.

3. **Set up GitHub Actions OIDC for CI/CD:**
   ```bash
   ./scripts/setup-oidc.sh
   ```
   Creates the Entra app registration, service principal, federated credentials, and sets `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` as GitHub secrets.

4. **Create the `dev` GitHub environment:**
   ```bash
   gh api repos/$(gh repo view --json nameWithOwner -q .nameWithOwner)/environments/dev -X PUT
   ```

5. **Verify:** Push to `main` and confirm the `deploy.yml` workflow succeeds, then test the API:
   ```bash
   curl -X POST "https://func-movie-trivia-agent-dev.azurewebsites.net/api/jobs" \
     -H "Content-Type: application/json" \
     -d '{"topic": "Planet of the Apes"}'
   ```
