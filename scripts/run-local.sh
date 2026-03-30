#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# run-local.sh — Start the Aspire AppHost for local development
#
# Usage:
#   ./scripts/run-local.sh
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Resolve repo root (so the script works from any working directory) ─────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APPHOST_PROJECT="${REPO_ROOT}/aspire/MovieTriviaAgent.AppHost"

# ── Normalize common tool locations across shells / VS Code terminals ──────
export PATH="$HOME/.dotnet/tools:$PATH"

if [[ -d "$HOME/.docker/bin" ]]; then
  export PATH="$HOME/.docker/bin:$PATH"
fi

# ── Pre-flight checks ─────────────────────────────────────────────────────
if ! command -v dotnet &>/dev/null; then
  echo "Error: 'dotnet' CLI not found. Install the .NET SDK first."
  exit 1
fi

if ! command -v aspire &>/dev/null; then
  echo "Error: 'aspire' CLI not found."
  echo ""
  echo "This script uses 'aspire run' so the Aspire MCP server can detect the AppHost"
  echo "and make MCP available to tools such as Claude Code and GitHub Copilot."
  echo ""
  echo "Install the Aspire CLI, then rerun this script:"
  echo "  https://learn.microsoft.com/dotnet/aspire/fundamentals/cli/overview"
  exit 1
fi

# ── Ensure OTel file export directory exists ───────────────────────────────
mkdir -p "${REPO_ROOT}/otel-export"

# ── Print helpful info ─────────────────────────────────────────────────────
echo "==> Starting Aspire AppHost for local development..."
echo ""
echo "    Project : ${APPHOST_PROJECT}"
echo ""
echo "    Once running, the Aspire dashboard will be available at:"
echo "      https://localhost:15888"
echo ""
echo "    OTel file export: ${REPO_ROOT}/otel-export/"
echo "    Inspect with:     ./scripts/view-otel-local.sh --genai"
echo ""
echo "    MCP note:         This uses 'aspire run' so the AppHost is discoverable"
echo "                      by the Aspire MCP server."
echo ""
echo "    Press Ctrl+C to stop."
echo ""

# ── Launch ─────────────────────────────────────────────────────────────────
cd "$APPHOST_PROJECT"
aspire run
