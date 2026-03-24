#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# deploy.sh — Deploy infrastructure (Bicep) and code to the dev environment
#
# Usage:
#   ./scripts/deploy.sh              # deploy infra + code
#   ./scripts/deploy.sh --infra-only # deploy infra only
#   ./scripts/deploy.sh --code-only  # deploy code only
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────
RESOURCE_GROUP="rg-movie-trivia-agent-dev"
FUNCTION_APP="func-movie-trivia-agent-dev"
LOCATION="eastus2"
ENVIRONMENT="dev"
BICEP_FILE="infra/main.bicep"
FUNCTIONS_PROJECT="src/MovieTriviaAgent.Functions"

# ── Parse flags ────────────────────────────────────────────────────────────
DEPLOY_INFRA=true
DEPLOY_CODE=true

for arg in "$@"; do
  case "$arg" in
    --infra-only)
      DEPLOY_CODE=false
      ;;
    --code-only)
      DEPLOY_INFRA=false
      ;;
    *)
      echo "Unknown flag: $arg"
      echo "Usage: $0 [--infra-only | --code-only]"
      exit 1
      ;;
  esac
done

# ── Resolve repo root (so the script works from any working directory) ─────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Infrastructure deployment ──────────────────────────────────────────────
if [[ "$DEPLOY_INFRA" == true ]]; then
  echo "==> Deploying infrastructure via Bicep..."
  az deployment sub create \
    --location "$LOCATION" \
    --template-file "${REPO_ROOT}/${BICEP_FILE}" \
    --parameters environmentName="$ENVIRONMENT" location="$LOCATION" \
    --name "movie-trivia-agent-${ENVIRONMENT}-$(date +%Y%m%d%H%M%S)"
  echo "==> Infrastructure deployment complete."
  if [[ "$DEPLOY_CODE" == false ]]; then
    AI_NAME="ai-movie-trivia-agent-${ENVIRONMENT}"
    ENDPOINT="$(az cognitiveservices account show --name "${AI_NAME}" --resource-group "${RESOURCE_GROUP}" --query properties.endpoint -o tsv)"
    API_KEY="$(az cognitiveservices account keys list --name "${AI_NAME}" --resource-group "${RESOURCE_GROUP}" --query key1 -o tsv)"
    echo ""
    echo "Foundry endpoint: ${ENDPOINT}"
    echo "Foundry API key:  ${API_KEY}"
    echo ""
    echo "To configure for local Aspire development, run:"
    echo "  dotnet user-secrets set \"Foundry:Endpoint\" \"${ENDPOINT}\" --project aspire/MovieTriviaAgent.AppHost"
    echo "  dotnet user-secrets set \"Foundry:ApiKey\" \"${API_KEY}\" --project aspire/MovieTriviaAgent.AppHost"
  fi
fi

# ── Code deployment ────────────────────────────────────────────────────────
if [[ "$DEPLOY_CODE" == true ]]; then
  echo "==> Publishing Function App code..."
  (
    cd "${REPO_ROOT}/${FUNCTIONS_PROJECT}"
    func azure functionapp publish "$FUNCTION_APP"
  )
  echo "==> Code deployment complete."
fi

echo "==> Done."
