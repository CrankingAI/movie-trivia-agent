# movie-trivia-agent

> **Archived.** This repo is superseded by **[CrankingAI/movie-rating-agent](https://github.com/CrankingAI/movie-rating-agent)**. Go there for current code, docs, and the live deployment at [movieratingagent.com](https://movieratingagent.com).

This was the first take on running an AI agent as an async job on Azure Functions (a .NET 10 isolated worker using the Agent Framework's WorkflowBuilder, with Foundry, Blob and Queue storage, Bicep, and OTel through Aspire). The example agent rated movies for "greatness" on a 0-100 scale.

Its Azure resources (`rg-movie-trivia-agent-dev`) were deleted on 2026-09-26, so the deploy scripts and workflows here no longer have anything to target. The original README is in git history.
