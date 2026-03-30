# movie-trivia-agent

An AI agent helpful with movie trivia. A "movie" in this context is generally a mainstream (Hollywood) movie.

## Local Development

**Prerequisites:** .NET 10 SDK, Docker (for Azurite via Aspire), Aspire CLI, Azure Functions Core Tools (`func`)

### Build & Test

```bash
dotnet build MovieTriviaAgent.slnx
dotnet test MovieTriviaAgent.slnx
```

### Run Locally (Aspire)

```bash
./scripts/run-local.sh
```

This starts the Aspire AppHost with `aspire run`, which allows the Aspire MCP server to detect the AppHost and expose MCP to tools such as Claude Code and GitHub Copilot. It also starts Azurite (storage emulator) and the Functions app. The Aspire dashboard opens at `https://localhost:15888`.

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

## Configuration

The agent requires a Foundry (Azure OpenAI) endpoint, API key, and model deployment name. All three flow through `Foundry__*` environment variables (or `Foundry:*` in .NET configuration).

| Setting | Env Var / Config Key | Default | Description |
| ------- | -------------------- | ------- | ----------- |
| Endpoint | `Foundry__Endpoint` / `Foundry:Endpoint` | *(required)* | Azure AI Foundry endpoint URL |
| API Key | `Foundry__ApiKey` / `Foundry:ApiKey` | *(required)* | Azure AI Foundry API key |
| Model ID | `Foundry__ModelId` / `Foundry:ModelId` | `gpt-5.4` | Model deployment name |

### Where each setting is configured

| Context | How to set |
| ------- | ---------- |
| **Local (Aspire)** | `dotnet user-secrets` on the AppHost project — parameters `foundry-endpoint`, `foundry-apikey`, `foundry-modelid` |
| **Local (standalone Functions)** | `src/MovieTriviaAgent.Functions/local.settings.json` — keys `Foundry__Endpoint`, `Foundry__ApiKey`, `Foundry__ModelId` |
| **Deployed (Azure)** | Bicep app settings in `infra/functionApp.bicep` — `foundryModelId` param (defaults to the deployment name from `foundry.bicep`) |
| **Eval tests** | Environment variables `FOUNDRY_ENDPOINT`, `FOUNDRY_API_KEY`, `FOUNDRY_MODEL_ID` |

### Changing the model deployment

To use a different model deployment (e.g. `gpt-4o` or a fine-tuned model):

1. **Local (Aspire):** `dotnet user-secrets set "Parameters:foundry-modelid" "your-deployment" --project aspire/MovieTriviaAgent.AppHost`
2. **Local (standalone):** Edit `Foundry__ModelId` in `local.settings.json`
3. **Deployed:** Either update `foundry.bicep` to deploy a different model, or override the `foundryModelId` parameter in `main.bicep`

The configured model ID is used for the `IChatClient` and propagated to OTel span tags (`gen_ai.request.model`), so traces accurately reflect which deployment served each request.

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
