#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# local-run.sh — Start the Aspire AppHost for local development
#
# Usage:
#   ./scripts/local-run.sh
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Resolve repo root (so the script works from any working directory) ─────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APPHOST_PROJECT="${REPO_ROOT}/aspire/MovieTriviaAgent.AppHost"

# ── Pre-flight checks ─────────────────────────────────────────────────────
if ! command -v dotnet &>/dev/null; then
  echo "Error: 'dotnet' CLI not found. Install the .NET SDK first."
  exit 1
fi

# ── Print helpful info ─────────────────────────────────────────────────────
echo "==> Starting Aspire AppHost for local development..."
echo ""
echo "    Project : ${APPHOST_PROJECT}"
echo ""
echo "    Once running, the Aspire dashboard will be available at:"
echo "      https://localhost:15888"
echo ""
echo "    Press Ctrl+C to stop."
echo ""

# ── Launch ─────────────────────────────────────────────────────────────────
dotnet run --project "$APPHOST_PROJECT"
