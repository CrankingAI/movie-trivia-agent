#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# test-local.sh — Submit a job and poll until complete
#
# Usage:
#   ./scripts/test-local.sh                     # defaults to "The Godfather"
#   ./scripts/test-local.sh "Citizen Kane"
#   ./scripts/test-local.sh "Planet of the Apes" 8080
# ---------------------------------------------------------------------------
set -euo pipefail

MOVIE="${1:-The Godfather}"
PORT="${2:-}"

# Auto-detect port from the running Functions process if not provided
if [[ -z "$PORT" ]]; then
  CANDIDATES="$(lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | grep '^func ' | grep -oE ':\d+' | tr -d ':' | sort -u)" || true
  for P in $CANDIDATES; do
    if curl -s -o /dev/null -w '%{http_code}' "http://localhost:${P}/api/jobs/probe" 2>/dev/null | grep -qE '^(404|200)'; then
      PORT="$P"
      break
    fi
  done
  if [[ -z "$PORT" ]]; then
    echo "Error: Could not detect Functions port. Pass it as the second argument:"
    echo "  $0 \"${MOVIE}\" 51238"
    exit 1
  fi
fi

BASE="http://localhost:${PORT}/api/jobs"
echo "==> Submitting: \"${MOVIE}\" to ${BASE}"

SUBMIT_RESPONSE="$(curl -s -X POST "${BASE}" -H 'Content-Type: application/json' -d "{\"topic\": \"${MOVIE}\"}" 2>&1)" || true
JOB_ID="$(echo "$SUBMIT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('jobId',''))" 2>/dev/null)" || true

if [[ -z "$JOB_ID" ]]; then
  echo "Error: Failed to submit job."
  echo "  Port: ${PORT}"
  echo "  Response: ${SUBMIT_RESPONSE}"
  exit 1
fi

echo "    Job ID: ${JOB_ID}"
echo ""

while true; do
  RESPONSE="$(curl -s "${BASE}/${JOB_ID}")"
  STATUS="$(echo "$RESPONSE" | grep -o '"Status":[0-9]*' | cut -d: -f2)"

  case "$STATUS" in
    0) echo "    [$(date +%H:%M:%S)] Queued..." ;;
    1) echo "    [$(date +%H:%M:%S)] Running..." ;;
    2)
      echo "    [$(date +%H:%M:%S)] Completed!"
      echo ""
      echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
      exit 0
      ;;
    3)
      echo "    [$(date +%H:%M:%S)] Failed!"
      echo ""
      echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
      exit 1
      ;;
    *)
      echo "    [$(date +%H:%M:%S)] Unknown status: ${STATUS}"
      echo "$RESPONSE"
      exit 1
      ;;
  esac

  sleep 2
done
