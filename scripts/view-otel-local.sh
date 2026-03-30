#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# view-otel-local.sh — Inspect local OTel file exports for completeness
#
# Reads JSONL files written by the OTel Collector (./otel-export/) and
# summarises traces, GenAI spans, and attribute coverage.
#
# Usage:
#   ./scripts/view-otel-local.sh              # summary of all signals
#   ./scripts/view-otel-local.sh --genai      # GenAI spans + attribute check
#   ./scripts/view-otel-local.sh --spans      # list all span names
#   ./scripts/view-otel-local.sh --clean      # delete export files
# ---------------------------------------------------------------------------
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORT_DIR="${REPO_ROOT}/otel-export"
TRACES_FILE="${EXPORT_DIR}/traces.jsonl"
METRICS_FILE="${EXPORT_DIR}/metrics.jsonl"
LOGS_FILE="${EXPORT_DIR}/logs.jsonl"

# ── Pre-flight ─────────────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "Error: 'jq' is required. Install with: brew install jq"
  exit 1
fi

if [[ ! -d "$EXPORT_DIR" ]]; then
  echo "No otel-export/ directory found. Run 'aspire run' first to generate telemetry."
  exit 1
fi

# ── Commands ───────────────────────────────────────────────────────────────
show_summary() {
  echo "==> OTel File Export Summary"
  echo "    Directory: ${EXPORT_DIR}"
  echo ""

  for f in "$TRACES_FILE" "$METRICS_FILE" "$LOGS_FILE"; do
    local name
    name="$(basename "$f")"
    if [[ -f "$f" ]]; then
      local lines size
      lines="$(wc -l < "$f" | tr -d ' ')"
      size="$(du -h "$f" | cut -f1 | tr -d ' ')"
      echo "    ${name}: ${lines} batches, ${size}"
    else
      echo "    ${name}: (not found)"
    fi
  done

  if [[ -f "$TRACES_FILE" ]]; then
    echo ""
    echo "── Span counts by name ──────────────────────────────────────"
    jq -r '
      [.resourceSpans[]?.scopeSpans[]?.spans[]?.name] | .[]
    ' "$TRACES_FILE" 2>/dev/null \
      | sort | uniq -c | sort -rn \
      | head -20 \
      | while read -r count name; do
          printf "    %5s  %s\n" "$count" "$name"
        done
  fi
  echo ""
}

show_spans() {
  if [[ ! -f "$TRACES_FILE" ]]; then
    echo "No traces.jsonl found."
    exit 1
  fi

  echo "==> All spans (most recent batches last)"
  echo ""
  jq -r '
    .resourceSpans[]?.scopeSpans[]? |
    .scope.name as $scope |
    .spans[]? |
    "\(.startTimeUnixNano // "?") | \($scope) | \(.name) | kind=\(.kind) | status=\(.status.code // 0)"
  ' "$TRACES_FILE" 2>/dev/null | tail -50
  echo ""
}

show_genai() {
  if [[ ! -f "$TRACES_FILE" ]]; then
    echo "No traces.jsonl found."
    exit 1
  fi

  echo "==> GenAI Spans — Attribute Completeness Check"
  echo ""

  # Required attributes per GenAI semantic conventions
  local required_attrs=(
    "gen_ai.operation.name"
    "gen_ai.request.model"
    "gen_ai.response.model"
    "gen_ai.system"
  )

  # Recommended attributes
  local recommended_attrs=(
    "gen_ai.usage.input_tokens"
    "gen_ai.usage.output_tokens"
    "gen_ai.response.finish_reasons"
  )

  # Agent-level attributes
  local agent_attrs=(
    "gen_ai.agent.name"
    "gen_ai.agent.version"
  )

  # Extract GenAI spans
  local genai_spans
  genai_spans="$(jq -c '
    [.resourceSpans[]?.scopeSpans[]?.spans[]?
     | select(.attributes[]? | .key | startswith("gen_ai."))
    ][]
  ' "$TRACES_FILE" 2>/dev/null)" || true

  if [[ -z "$genai_spans" ]]; then
    echo "    No GenAI spans found in traces."
    echo ""
    echo "    Possible causes:"
    echo "      - No agent jobs have been run yet"
    echo "      - M.E.AI ActivitySource not registered (check Extensions.cs)"
    echo "      - Collector not receiving data (check 'aspire run' dashboard)"
    exit 1
  fi

  # Count GenAI spans
  local total
  total="$(echo "$genai_spans" | wc -l | tr -d ' ')"
  echo "    Found ${total} GenAI span(s)"
  echo ""

  # Show each GenAI span with attribute coverage
  echo "$genai_spans" | jq -r '
    "── \(.name) ──",
    "   Attributes:",
    (.attributes[] | select(.key | startswith("gen_ai.")) |
      "     \(.key) = \(.value | to_entries[0].value // "?")"
    ),
    ""
  ' 2>/dev/null

  # Check required attribute coverage
  echo "── Attribute Coverage ──────────────────────────────────────"
  echo ""

  for attr in "${required_attrs[@]}"; do
    local count
    count="$(echo "$genai_spans" | jq -r --arg a "$attr" '
      select(.attributes[]? | .key == $a) | .name
    ' 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$count" -gt 0 ]]; then
      printf "    ✓ %-40s (%s/%s spans)\n" "$attr" "$count" "$total"
    else
      printf "    ✗ %-40s MISSING\n" "$attr"
    fi
  done

  echo ""
  echo "  Recommended:"
  for attr in "${recommended_attrs[@]}"; do
    local count
    count="$(echo "$genai_spans" | jq -r --arg a "$attr" '
      select(.attributes[]? | .key == $a) | .name
    ' 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$count" -gt 0 ]]; then
      printf "    ✓ %-40s (%s/%s spans)\n" "$attr" "$count" "$total"
    else
      printf "    · %-40s not present\n" "$attr"
    fi
  done

  echo ""
  echo "  Agent:"
  for attr in "${agent_attrs[@]}"; do
    local count
    count="$(echo "$genai_spans" | jq -r --arg a "$attr" '
      select(.attributes[]? | .key == $a) | .name
    ' 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$count" -gt 0 ]]; then
      printf "    ✓ %-40s (%s/%s spans)\n" "$attr" "$count" "$total"
    else
      printf "    · %-40s not present\n" "$attr"
    fi
  done

  echo ""
}

do_clean() {
  echo "==> Cleaning otel-export/ files..."
  rm -f "${EXPORT_DIR}"/*.jsonl "${EXPORT_DIR}"/*.jsonl.*
  echo "    Done."
}

# ── Main ───────────────────────────────────────────────────────────────────
MODE="${1:-}"

case "$MODE" in
  --genai)  show_genai ;;
  --spans)  show_spans ;;
  --clean)  do_clean ;;
  --help|-h)
    echo "Usage: $0 [--genai | --spans | --clean]"
    echo ""
    echo "  (default)   Summary of all signal types + span counts"
    echo "  --genai     GenAI spans with attribute completeness check"
    echo "  --spans     List all span names from traces"
    echo "  --clean     Delete export files"
    exit 0
    ;;
  "")       show_summary ;;
  *)
    echo "Unknown option: $MODE"
    echo "Run $0 --help for usage."
    exit 1
    ;;
esac
