#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# view-otel.sh — Query App Insights for recent OpenTelemetry data
#
# Usage:
#   ./scripts/view-otel.sh                # last 1 hour (default)
#   ./scripts/view-otel.sh --timespan PT4H   # last 4 hours
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────
APP_INSIGHTS="appi-movie-trivia-agent-dev"
RESOURCE_GROUP="rg-movie-trivia-agent-dev"
TIMESPAN="PT1H"

# ── Parse flags ────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --timespan)
      TIMESPAN="$2"
      shift 2
      ;;
    *)
      echo "Unknown flag: $1"
      echo "Usage: $0 [--timespan <ISO-8601-duration>]"
      exit 1
      ;;
  esac
done

echo "==> Querying App Insights (${APP_INSIGHTS}) — timespan: ${TIMESPAN}"
echo ""

# ── Helper: run a Kusto query and pretty-print with jq ────────────────────
run_query() {
  local title="$1"
  local query="$2"

  echo "── ${title} ──────────────────────────────────────────────"
  az monitor app-insights query \
    --app "$APP_INSIGHTS" \
    --resource-group "$RESOURCE_GROUP" \
    --analytics-query "$query" \
    --offset "$TIMESPAN" \
    --output json 2>/dev/null \
  | jq -r '
      # App Insights query returns { "tables": [ { "columns": [...], "rows": [...] } ] }
      .tables[0] as $t |
      if ($t.rows | length) == 0 then
        "  (no results)"
      else
        # Build header from column names
        ([$t.columns[].name] | join(" | ")),
        ([$t.columns[] | "---"] | join(" | ")),
        # Build each row
        ($t.rows[] | [.[] | tostring] | join(" | "))
      end
    ' 2>/dev/null || echo "  (query returned no data or App Insights is unavailable)"
  echo ""
}

# ── 1. Recent requests ────────────────────────────────────────────────────
run_query "Recent Requests (last ${TIMESPAN})" \
  "requests | order by timestamp desc | take 20 | project timestamp, name, resultCode, duration, success"

# ── 2. Recent traces ──────────────────────────────────────────────────────
run_query "Recent Traces (last ${TIMESPAN})" \
  "traces | order by timestamp desc | take 20 | project timestamp, message, severityLevel"

# ── 3. Recent dependencies ────────────────────────────────────────────────
run_query "Recent Dependencies (last ${TIMESPAN})" \
  "dependencies | order by timestamp desc | take 20 | project timestamp, type, target, name, duration, success"

# ── 4. Gen AI spans (OpenTelemetry semantic conventions for gen_ai) ───────
run_query "Gen AI Spans (last ${TIMESPAN})" \
  "dependencies | where customDimensions has 'gen_ai' or type has 'gen_ai' or name has 'gen_ai' | order by timestamp desc | take 20 | project timestamp, type, name, duration, customDimensions"

echo "==> Done."
