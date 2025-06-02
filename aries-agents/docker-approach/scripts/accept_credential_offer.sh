#!/bin/bash

# Usage:
#   ./accept_credential_offer.sh <holder_name>              # Auto-accept first credential offer
#   ./accept_credential_offer.sh <holder_name> list         # List offers
#   ./accept_credential_offer.sh <holder_name> <cred_ex_id> # Accept specific offer

set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
HOLDER="$1"
OPTION="$2"

if [[ -z "$HOLDER" ]]; then
  echo "Usage: $0 <holder_name> [list | <cred_ex_id>]"
  exit 1
fi

source "$SCRIPT_DIR/../agent_envs/$HOLDER.env"
PORT="$AGENT_ADMIN_PORT"

if [[ "$OPTION" == "list" ]]; then
  echo "[INFO] Listing credential offers for $HOLDER..."

  curl -s http://localhost:$PORT/issue-credential-2.0/records \
    | jq -r '
      .results[] | select(.cred_ex_record.state == "offer-received") |
      "cred_ex_id: \(.cred_ex_record.cred_ex_id)\nthread_id: \(.cred_ex_record.thread_id)\nissuer_connection_id: \(.cred_ex_record.connection_id)\n---"'
  exit 0
fi

# Use provided ID or auto-select first
if [[ -n "$OPTION" ]]; then
  CRED_EX_ID="$OPTION"
else
  CRED_EX_ID=$(curl -s http://localhost:$PORT/issue-credential-2.0/records \
    | jq -r '.results[] | select(.cred_ex_record.state == "offer-received") | .cred_ex_record.cred_ex_id' | head -n 1)

  if [[ -z "$CRED_EX_ID" ]]; then
    echo "[INFO] No credential offer to accept for $HOLDER"
    exit 0
  fi

  echo "[INFO] Auto-selecting credential offer: $CRED_EX_ID"
fi

echo "[INFO] Accepting credential offer..."
curl -s -X POST "http://localhost:$PORT/issue-credential-2.0/records/$CRED_EX_ID/send-request" \
  -H "Content-Type: application/json" -d '{}' > /dev/null

# Wait for credential to be received
echo "[INFO] Waiting for credential to be received..."
for i in {1..20}; do
  STATE=$(curl -s http://localhost:$PORT/issue-credential-2.0/records/$CRED_EX_ID | jq -r '.cred_ex_record.state')
  if [[ "$STATE" == "credential-received" ]]; then
    echo "[INFO] Credential received. Storing it..."
    curl -s -X POST "http://localhost:$PORT/issue-credential-2.0/records/$CRED_EX_ID/store" \
      -H "Content-Type: application/json" -d '{}' > /dev/null
    echo "[DONE] Credential stored successfully."
    exit 0
  fi
  sleep 1
done

echo "[ERROR] Credential was not received within timeout."
exit 1
