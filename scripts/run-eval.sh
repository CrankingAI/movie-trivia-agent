#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# run-eval.sh — Run eval tests against the deployed Foundry endpoint
#
# Usage:
#   ./scripts/run-eval.sh
#   ./scripts/run-eval.sh range
#   ./scripts/run-eval.sh stability --runs 10
#   ./scripts/run-eval.sh quality
#   ./scripts/run-eval.sh all --verbosity detailed
#   ./scripts/run-eval.sh --filter "FullyQualifiedName~RangeCorrectnessEvalTests"
# ---------------------------------------------------------------------------
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${REPO_ROOT}/tests/MovieTriviaAgent.Eval/MovieTriviaAgent.Eval.csproj"
AI_NAME="ai-movie-trivia-agent-dev"
RESOURCE_GROUP="rg-movie-trivia-agent-dev"

MODE="all"
FILTER=""
RUNS="${MOVIE_EVAL_RUNS:-7}"
VERBOSITY="normal"
LOGGER_VERBOSITY="${MOVIE_EVAL_LOGGER_VERBOSITY:-detailed}"

usage() {
  cat <<EOF
Usage: ./scripts/run-eval.sh [mode] [options]

Modes:
  all         Run all eval tests (default)
  range       Run range correctness evals
  stability   Run stability / variance evals
  quality     Run quality / formatting evals

Options:
  --runs <n>        Override MOVIE_EVAL_RUNS for repeated-run evals
  --verbosity <v>   dotnet test verbosity (minimal, normal, detailed, diagnostic)
  --logger-verbosity <v>
                    Console logger verbosity (quiet, minimal, normal, detailed, diagnostic)
  --filter <expr>   Pass a raw dotnet test filter expression
  --help            Show this help text
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    all|range|stability|quality)
      MODE="$1"
      shift
      ;;
    --runs)
      RUNS="$2"
      shift 2
      ;;
    --verbosity)
      VERBOSITY="$2"
      shift 2
      ;;
    --logger-verbosity)
      LOGGER_VERBOSITY="$2"
      shift 2
      ;;
    --filter)
      FILTER="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$FILTER" ]]; then
  case "$MODE" in
    range)
      FILTER="FullyQualifiedName~RangeCorrectnessEvalTests"
      ;;
    stability)
      FILTER="FullyQualifiedName~StabilityVarianceEvalTests"
      ;;
    quality)
      FILTER="FullyQualifiedName~QualityEvalTests"
      ;;
    all)
      FILTER=""
      ;;
  esac
fi

export MOVIE_EVAL_RUNS="$RUNS"

if [[ -z "${FOUNDRY_ENDPOINT:-}" || -z "${FOUNDRY_API_KEY:-}" ]]; then
  echo "==> Fetching Foundry credentials from Azure..."
  export FOUNDRY_ENDPOINT="$(az cognitiveservices account show --name "${AI_NAME}" --resource-group "${RESOURCE_GROUP}" --query properties.endpoint -o tsv)"
  export FOUNDRY_API_KEY="$(az cognitiveservices account keys list --name "${AI_NAME}" --resource-group "${RESOURCE_GROUP}" --query key1 -o tsv)"
  echo "    Endpoint: ${FOUNDRY_ENDPOINT}"
fi

echo "==> Running eval tests"
echo "    Mode: ${MODE}"
echo "    Runs: ${MOVIE_EVAL_RUNS}"
echo "    Verbosity: ${VERBOSITY}"
echo "    Logger verbosity: ${LOGGER_VERBOSITY}"
if [[ -n "$FILTER" ]]; then
  echo "    Filter: ${FILTER}"
  dotnet test "$PROJECT_PATH" --filter "$FILTER" --verbosity "$VERBOSITY" --logger "console;verbosity=${LOGGER_VERBOSITY}"
else
  dotnet test "$PROJECT_PATH" --verbosity "$VERBOSITY" --logger "console;verbosity=${LOGGER_VERBOSITY}"
fi
