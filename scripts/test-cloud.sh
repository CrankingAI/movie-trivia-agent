#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# test-cloud.sh — Submit a job to the deployed Function App and poll for result
#
# Usage:
#   ./scripts/test-cloud.sh                       # defaults to "The Godfather"
#   ./scripts/test-cloud.sh "Citizen Kane"
#   ./scripts/test-cloud.sh "Planet of the Apes" my-func-app.azurewebsites.net
# ---------------------------------------------------------------------------
set -euo pipefail

MOVIE="${1:-The Godfather}"
FUNC_HOST="${2:-func-movie-trivia-agent-dev.azurewebsites.net}"
BASE="https://${FUNC_HOST}/api/jobs"

echo "==> Submitting: \"${MOVIE}\" to ${BASE}"

SUBMIT_RESPONSE="$(curl -s -X POST "${BASE}" -H 'Content-Type: application/json' -d "{\"topic\": \"${MOVIE}\"}" 2>&1)" || true
JOB_ID="$(echo "$SUBMIT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('jobId',''))" 2>/dev/null)" || true

if [[ -z "$JOB_ID" ]]; then
  echo "Error: Failed to submit job."
  echo "  Host: ${FUNC_HOST}"
  echo "  Response: ${SUBMIT_RESPONSE}"
  exit 1
fi

echo "    Job ID: ${JOB_ID}"
echo ""

while true; do
  RESPONSE="$(curl -s "${BASE}/${JOB_ID}")"
  STATUS="$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['meta']['Status'])" 2>/dev/null)" || true

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
      echo "  Response: ${RESPONSE}"
      exit 1
      ;;
  esac

  sleep 2
done
