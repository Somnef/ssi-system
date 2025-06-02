#!/bin/bash

# Usage:
#   ./accept_connection.sh <agent_name>           # Auto-accept first pending
#   ./accept_connection.sh <agent_name> list      # List all pending requests
#   ./accept_connection.sh <agent_name> <request_id>  # Accept specific one

set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
AGENT_NAME="$1"
OPTION="$2"

if [[ -z "$AGENT_NAME" ]]; then
  echo "Usage: $0 <agent_name> [list | <request_id>]"
  exit 1
fi

source "$SCRIPT_DIR/../agent_envs/$AGENT_NAME.env"
AGENT_PORT="$AGENT_ADMIN_PORT"

if [[ "$OPTION" == "list" ]]; then
  echo "[INFO] Listing pending connection requests for $AGENT_NAME..."
  curl -s http://localhost:$AGENT_PORT/connections | jq -r '
    .results[] | select(.rfc23_state == "request-received") | 
    "connection_id: \(.connection_id)\nrequest_id: \(.request_id)\ntheir_label: \(.their_label // "unknown")\n---"'
  exit 0
fi

if [[ -n "$OPTION" ]]; then
  REQ_ID="$OPTION"
else
  # Auto-select first pending request
  REQ_ID=$(curl -s http://localhost:$AGENT_PORT/connections | jq -r '
    .results[] | select(.rfc23_state == "request-received") | .request_id' | head -n 1)

  if [[ -z "$REQ_ID" ]]; then
    echo "[INFO] No pending connection requests found for $AGENT_NAME."
    exit 0
  fi

  echo "[INFO] Auto-selecting request_id: $REQ_ID"
fi

# Get connection ID from request ID
CONN_ID=$(curl -s http://localhost:$AGENT_PORT/connections | jq -r --arg rid "$REQ_ID" '
  .results[] | select(.request_id == $rid) | .connection_id' | head -n 1)

if [[ -z "$CONN_ID" ]]; then
  echo "[ERROR] Could not find connection for request_id: $REQ_ID"
  exit 1
fi

echo "[INFO] Accepting connection request ($CONN_ID)..."
curl -s -X POST "http://localhost:$AGENT_PORT/didexchange/$CONN_ID/accept-request" > /dev/null
echo "Accepted: connection_id=$CONN_ID"
