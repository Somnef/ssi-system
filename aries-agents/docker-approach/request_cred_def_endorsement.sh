#!/bin/bash

# Usage: ./request_cred_def_endorsement.sh <agent_name> <admin_name> <schema_id> <tag>

set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
AGENT_NAME="$1"
ADMIN_NAME="$2"
SCHEMA_ID="$3"
TAG="${4:-default}"

if [[ -z "$AGENT_NAME" || -z "$ADMIN_NAME" || -z "$SCHEMA_ID" ]]; then
  echo "Usage: $0 <agent_name> <admin_name> <schema_id> [tag]"
  exit 1
fi

# Load agent configs
source "$SCRIPT_DIR/agent_envs/$AGENT_NAME.env"
PORT1="$AGENT_ADMIN_PORT"

source "$SCRIPT_DIR/agent_envs/$ADMIN_NAME.env"
PORT2="$AGENT_ADMIN_PORT"

# Get posted DIDs
DID1=$(curl -s http://localhost:$PORT1/wallet/did | jq -r '.results[] | select(.posture == "posted") | .did')
DID2=$(curl -s http://localhost:$PORT2/wallet/did | jq -r '.results[] | select(.posture == "posted") | .did')

echo "[INFO] $AGENT_NAME DID: $DID1"
echo "[INFO] $ADMIN_NAME DID: $DID2"

# Get connection from agent to admin
CONN_JSON=$(curl -s http://localhost:$PORT1/connections)

# Try to match by public DID
CONN_ID=$(echo "$CONN_JSON" | jq -r ".results[] | select(.state == \"active\" and .their_public_did == \"$DID2\") | .connection_id" | head -n 1)

# Fallback: match by label
if [[ -z "$CONN_ID" ]]; then
  CONN_ID=$(echo "$CONN_JSON" | jq -r ".results[] | select(.state == \"active\" and .their_label == \"$ADMIN_NAME\") | .connection_id" | head -n 1)
fi

# Fallback: match by request_id
if [[ -z "$CONN_ID" ]]; then
  REQUEST_ID=$(curl -s http://localhost:$PORT2/connections | jq -r ".results[] | select(.state == \"active\" and .their_public_did == \"$DID1\") | .request_id" | head -n 1)

  if [[ -n "$REQUEST_ID" ]]; then
    CONN_ID=$(echo "$CONN_JSON" | jq -r ".results[] | select(.request_id == \"$REQUEST_ID\") | .connection_id" | head -n 1)
  fi
fi

if [[ -z "$CONN_ID" ]]; then
  echo "[ERROR] No active connection from $AGENT_NAME to $ADMIN_NAME"
  exit 1
fi

echo "[INFO] Agent-to-Admin connection_id: $CONN_ID"

# Set roles and endorser info
curl -s -X POST "http://localhost:$PORT1/transactions/$CONN_ID/set-endorser-role?transaction_my_job=TRANSACTION_AUTHOR" > /dev/null
curl -s -X POST "http://localhost:$PORT1/transactions/$CONN_ID/set-endorser-info?endorser_did=$DID2" > /dev/null

# Create the transaction for endorsement
RESP=$(curl -s -X POST "http://localhost:$PORT1/credential-definitions?conn_id=$CONN_ID&create_transaction_for_endorser=true" \
  -H "Content-Type: application/json" \
  -d '{
    "schema_id": "'"$SCHEMA_ID"'",
    "support_revocation": false,
    "tag": "'"$TAG"'"
  }')

if echo "$RESP" | grep -q "already exists"; then
  echo "[INFO] Credential definition with tag <$TAG> already exists. Skipping creation."
  exit 0
fi

TXN_ID=$(echo "$RESP" | jq -r '.txn.transaction_id')

if [[ -z "$TXN_ID" || "$TXN_ID" == "null" ]]; then
  echo "[ERROR] Failed to create transaction:"
  echo "$RESP"
  exit 1
fi

# Send the transaction to admin
curl -s -X POST "http://localhost:$PORT1/transactions/create-request?tran_id=$TXN_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "expires_time": "'"$(date -u -d '+1 day' +%Y-%m-%dT%H:%M:%SZ)"'"
  }' > /dev/null

echo "Credential Definition transaction created and sent for endorsement."
echo "transaction_id: $TXN_ID"
echo "Next, run this on $ADMIN_NAME:"
echo "./endorse_transaction.sh $ADMIN_NAME $AGENT_NAME $TXN_ID"
