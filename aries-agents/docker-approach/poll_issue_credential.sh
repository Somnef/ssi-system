#!/bin/bash

# Usage: ./poll_issue_credential.sh <issuer_name>

set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
ISSUER="$1"

if [[ -z "$ISSUER" ]]; then
  echo "Usage: $0 <issuer_name>"
  exit 1
fi

source "$SCRIPT_DIR/agent_envs/$ISSUER.env"
PORT="$AGENT_ADMIN_PORT"

echo "[INFO] Polling for credential requests to issue as $ISSUER..."
while true; do
  PENDING=$(curl -s http://localhost:$PORT/issue-credential-2.0/records \
    | jq -r '.results[] | select(.cred_ex_record.state == "request-received") | .cred_ex_record.cred_ex_id')

  for CRED_EX_ID in $PENDING; do
    echo "[INFO] Issuing credential for exchange ID: $CRED_EX_ID"
    curl -s -X POST "http://localhost:$PORT/issue-credential-2.0/records/$CRED_EX_ID/issue" \
      -H "Content-Type: application/json" -d '{}' > /dev/null
    echo "[DONE] Issued credential for $CRED_EX_ID"
  done

  sleep 3
done
