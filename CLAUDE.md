# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A general-purpose pattern for running AI agents as async jobs on Azure. The repo name is domain-flavored (movie trivia) but the code and infrastructure are domain-agnostic — establishing a reusable template, not a specific product. The concrete example agent rates movies for "greatness" on a 0-100 scale.

## Tech Stack

- **.NET 10**, C#, isolated worker model
- **Microsoft.Extensions.AI Agent Framework** — WorkflowBuilder with tool executors
- **Microsoft Foundry** back-end for LLMs, model: **gpt-5.4**
- **Azure Functions** (Linux, App Service plan with AlwaysOn)
- **Azure Storage** — Blob Storage for job persistence, Storage Queue for job dispatch
- **Bicep** for infrastructure-as-code
- **OpenTelemetry (OTel)** + **.NET Aspire** (local dev only) for observability
- **Azure Monitor**, **Log Analytics**, **Application Insights** for deployed monitoring
- **GitHub Actions** with OIDC auth for CI/CD (single `dev` environment)

## Architecture

Async job-based agent execution via Azure Functions:

1. **SubmitJob** (HTTP POST → 202 Accepted) — validates request, writes `request.json` + initial `meta.json` to blob, enqueues job ID to Storage Queue
2. **GetJob** (HTTP GET → 200) — reads `meta.json` + `response.json` (if complete), returns status/result
3. **RunJob** (Queue trigger) — reads `request.json`, runs the AI agent, writes `response.json` + updates `meta.json`

### Blob Layout

```
jobs/{jobId}/request.json    # Input (e.g., { "topic": "Citizen Kane" })
jobs/{jobId}/response.json   # Agent output (rating, reasoning)
jobs/{jobId}/meta.json       # Status, timing, agent version, etc.
```

### Job Request Format

Simple `topic` field for now — designed to be expanded later.

## Solution Structure

```
MovieTriviaAgent.sln
src/
  MovieTriviaAgent.Functions/        # Azure Functions isolated worker (HTTP + queue triggers)
  MovieTriviaAgent.Agent/            # WorkflowBuilder pipeline + tool executors
  MovieTriviaAgent.Core/             # Shared models, blob service, queue service, job lifecycle
tests/
  MovieTriviaAgent.Tests/            # xUnit unit tests (Core, Agent, Functions)
  MovieTriviaAgent.Eval/             # xUnit eval tests (AgentEval + M.E.AI.Evaluation)
aspire/
  MovieTriviaAgent.AppHost/          # Aspire host (local dev orchestration only)
  MovieTriviaAgent.ServiceDefaults/  # Aspire service defaults (OTel + logging)
infra/
  main.bicep                         # Orchestrator
  main.bicepparam                    # Parameters (region, naming)
  storage.bicep                      # Storage account (blobs + queues)
  functionApp.bicep                  # Function App (Linux, AlwaysOn plan)
  foundry.bicep                      # Foundry endpoint + gpt-5.4 deployment
  monitoring.bicep                   # Log Analytics + App Insights
scripts/
  deploy.sh                          # Deploy infra (Bicep) + code to dev
  setup-oidc.sh                      # Create Entra app reg, OIDC federated cred, GitHub secrets
  view-otel.sh                       # Query App Insights / Log Analytics for telemetry
  local-run.sh                       # Start Aspire AppHost for local dev
.github/workflows/
  ci.yml                             # Build + test on PR/push
  deploy.yml                         # Deploy infra + code to dev
```

## OTel Instrumentation

- Follow [OpenTelemetry Gen AI Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/) for all LLM calls
- Use [Azure AI Inference conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/azure-ai-inference/): `gen_ai.provider.name` = `"azure.ai.inference"`, span names `{gen_ai.operation.name} {gen_ai.request.model}`, `azure.resource_provider.namespace` = `"Microsoft.CognitiveServices"`
- Local: Aspire dashboard
- Deployed: Azure Monitor exporter → Application Insights

## Eval Strategy

Two evaluation approaches in `tests/MovieTriviaAgent.Eval/`:

1. **Stochastic Eval ([AgentEval](https://agenteval.dev/))** — NuGet `AgentEval`. Run the rating agent 1000x on known movies (Citizen Kane, The Godfather, Santa Claus Conquers the Martians, Planet of the Apes, Porky's). Assert ratings are consistent within acceptable variance using `RunStochasticTestAsync()`.

2. **Microsoft.Extensions.AI.Evaluation** — structured quality metrics using `IEvaluator`, `NumericMetric`, `BooleanMetric`, `CompositeEvaluator`, `EvaluationResult` types. Assess agent output quality with framework-provided evaluators.

## Azure Resources

All resource naming derived from repo name. US region with Foundry + gpt-5.4 support. Single `dev` environment.

- Resource Group
- Storage Account (blobs + queues)
- App Service Plan (Linux, AlwaysOn)
- Function App (isolated worker, .NET 10)
- Foundry endpoint + gpt-5.4 model deployment
- Log Analytics Workspace
- Application Insights

## Scripts

All scripts are CLI-driven (az, gh, func, dotnet) — no portal visits required. Located in `./scripts/`.

## Commit Messages

Use Conventional Commits format: `<type>: <description>`

- Append `!` for breaking changes (e.g., `feat!:`, `fix!:`)
- `feat` for new functionality
- `fix` for bug fixes, refactors, or performance improvements
- `chore` for everything else
- For multiple changes, use the most impactful type
