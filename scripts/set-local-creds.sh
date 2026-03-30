#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# set-local-creds.sh — Fetch Foundry credentials from Azure and set them
#                       as user secrets for local Aspire development
#
# Usage:
#   ./scripts/set-local-creds.sh
# ---------------------------------------------------------------------------
set -euo pipefail

AI_NAME="ai-movie-trivia-agent-dev"
RESOURCE_GROUP="rg-movie-trivia-agent-dev"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPHOST_PROJECT="${REPO_ROOT}/aspire/MovieTriviaAgent.AppHost"

APPI_NAME="appi-movie-trivia-agent-dev"

echo "==> Fetching Foundry credentials from Azure..."
ENDPOINT="$(az cognitiveservices account show --name "${AI_NAME}" --resource-group "${RESOURCE_GROUP}" --query properties.endpoint -o tsv)"
API_KEY="$(az cognitiveservices account keys list --name "${AI_NAME}" --resource-group "${RESOURCE_GROUP}" --query key1 -o tsv)"

echo "    Endpoint: ${ENDPOINT}"
echo "    API Key:  ${API_KEY:0:8}..."

echo "==> Fetching Application Insights connection string..."
APPI_CONN_STR="$(az monitor app-insights component show --app "${APPI_NAME}" --resource-group "${RESOURCE_GROUP}" --query connectionString -o tsv 2>/dev/null)" || true

if [[ -n "$APPI_CONN_STR" ]]; then
  echo "    App Insights: ${APPI_CONN_STR:0:40}..."
else
  echo "    App Insights: (not found — Azure Monitor export will be disabled locally)"
fi

echo "==> Setting user secrets for Aspire AppHost..."
dotnet user-secrets set "Parameters:foundry-endpoint" "${ENDPOINT}" --project "${APPHOST_PROJECT}"
dotnet user-secrets set "Parameters:foundry-apikey" "${API_KEY}" --project "${APPHOST_PROJECT}"

if [[ -n "$APPI_CONN_STR" ]]; then
  dotnet user-secrets set "APPLICATIONINSIGHTS_CONNECTION_STRING" "${APPI_CONN_STR}" --project "${APPHOST_PROJECT}"
  echo "    (Set APPLICATIONINSIGHTS_CONNECTION_STRING — local runs will export to Azure Monitor)"
fi

echo "==> Done. Restart ./scripts/local-run.sh to pick up the new credentials."
