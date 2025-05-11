#!/bin/bash

# Usage:
#   ./accept_credential_offer.sh <holder_name>           # Auto-accept first pending offer
#   ./accept_credential_offer.sh <holder_name> list      # List all pending offers
#   ./accept_credential_offer.sh <holder_name> <cred_ex_id>  # Accept specific offer by ID

set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
HOLDER="$1"
OPTION="$2"

if [[ -z "$HOLDER" ]]; then
  echo "Usage: $0 <holder_name> [list | <cred_ex_id>]"
  exit 1
fi

source "$SCRIPT_DIR/agent_envs/$HOLDER.env"
PORT="$AGENT_ADMIN_PORT"

if [[ "$OPTION" == "list" ]]; then
  echo "[INFO] Listing credential offers for $HOLDER..."
  curl -s http://localhost:$PORT/issue-credential-2.0/records \
    | jq -r '
      .results[] | select(.cred_ex_record.state == "offer-received") |
      "cred_ex_id: \(.cred_ex_record.cred_ex_id)\nthread_id: \(.cred_ex_record.thread_id)\nissuer: \(.cred_ex_record.connection_id)\n---"'
  exit 0
fi

# Use provided ID or auto-select first
if [[ -n "$OPTION" ]]; then
  CRED_EX_ID="$OPTION"
else
  CRED_EX_ID=$(curl -s http://localhost:$PORT/issue-credential-2.0/records \
    | jq -r '.results[] | select(.cred_ex_record.state == "offer-received") | .cred_ex_record.cred_ex_id' | head -n 1)

  if [[ -z "$CRED_EX_ID" ]]; then
    echo "[INFO] No pending credential offers for $HOLDER."
    exit 0
  fi

  echo "[INFO] Auto-selecting credential exchange ID: $CRED_EX_ID"
fi

echo "[INFO] Accepting offer..."
curl -s -X POST "http://localhost:$PORT/issue-credential-2.0/records/$CRED_EX_ID/send-request" > /dev/null
echo "[DONE] Credential request sent for $CRED_EX_ID"
