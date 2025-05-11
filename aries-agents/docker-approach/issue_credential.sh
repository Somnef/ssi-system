#!/bin/bash

# Usage:
#   ./issue_credential.sh <issuer_name>                 # Auto-issue first pending request
#   ./issue_credential.sh <issuer_name> list            # List pending requests
#   ./issue_credential.sh <issuer_name> <cred_ex_id>    # Issue specific credential

set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
ISSUER="$1"
OPTION="$2"

if [[ -z "$ISSUER" ]]; then
  echo "Usage: $0 <issuer_name> [list | <cred_ex_id>]"
  exit 1
fi

source "$SCRIPT_DIR/agent_envs/$ISSUER.env"
PORT="$AGENT_ADMIN_PORT"

if [[ "$OPTION" == "list" ]]; then
  echo "[INFO] Listing credential requests awaiting issuance for $ISSUER..."
  curl -s http://localhost:$PORT/issue-credential-2.0/records \
    | jq -r '
      .results[] | select(.cred_ex_record.state == "request-received") |
      "cred_ex_id: \(.cred_ex_record.cred_ex_id)\nthread_id: \(.cred_ex_record.thread_id)\nholder: \(.cred_ex_record.connection_id)\n---"'
  exit 0
fi

# Use provided ID or auto-select first
if [[ -n "$OPTION" ]]; then
  CRED_EX_ID="$OPTION"
else
  CRED_EX_ID=$(curl -s http://localhost:$PORT/issue-credential-2.0/records \
    | jq -r '.results[] | select(.cred_ex_record.state == "request-received") | .cred_ex_record.cred_ex_id' | head -n 1)

  if [[ -z "$CRED_EX_ID" ]]; then
    echo "[INFO] No pending credential requests found."
    exit 0
  fi

  echo "[INFO] Auto-selecting credential exchange ID: $CRED_EX_ID"
fi

echo "[INFO] Issuing credential..."
curl -s -X POST "http://localhost:$PORT/issue-credential-2.0/records/$CRED_EX_ID/issue" \
  -H "Content-Type: application/json" \
  -d '{}' > /dev/null

echo "[DONE] Credential issued for $CRED_EX_ID"
