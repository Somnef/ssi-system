#!/bin/bash

# Usage:
#   ./poll_verify_proofs.sh <verifier_name>

set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
VERIFIER="$1"

if [[ -z "$VERIFIER" ]]; then
  echo "Usage: $0 <verifier_name>"
  exit 1
fi

source "$SCRIPT_DIR/../agent_envs/$VERIFIER.env"
PORT="$AGENT_ADMIN_PORT"

echo "[INFO] Polling proof records on $VERIFIER ($PORT)..."

while true; do
  RECORDS=$(curl -s "http://localhost:$PORT/present-proof-2.0/records")
  VERIFIED=$(echo "$RECORDS" | jq -c '.results[] | select(.state == "done")')

  if [[ -n "$VERIFIED" ]]; then
    echo "$VERIFIED" | jq -r '
      "✅ pres_ex_id: \(.pres_ex_id)\n    verified:   \(.verified)\n    thread_id:  \(.thread_id)\n---"
    '
  else
    echo "[INFO] No verified presentations yet."
  fi

  sleep 2
done
