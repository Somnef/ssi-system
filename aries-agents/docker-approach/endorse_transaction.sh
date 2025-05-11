#!/bin/bash

# Usage: ./endorse_transaction.sh <admin_name> <author_name> <author_transaction_id>

set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
ADMIN_NAME="$1"
AUTHOR_NAME="$2"
AUTHOR_TXN_ID="$3"

if [[ -z "$ADMIN_NAME" || -z "$AUTHOR_NAME" || -z "$AUTHOR_TXN_ID" ]]; then
  echo "Usage: $0 <admin_name> <author_name> <author_transaction_id>"
  exit 1
fi

# Load agent configs
source "$SCRIPT_DIR/agent_envs/$ADMIN_NAME.env"
PORT1="$AGENT_ADMIN_PORT"

source "$SCRIPT_DIR/agent_envs/$AUTHOR_NAME.env"
PORT2="$AGENT_ADMIN_PORT"

# Get posted DIDs
DID1=$(curl -s http://localhost:$PORT1/wallet/did | jq -r '.results[] | select(.posture == "posted") | .did')
DID2=$(curl -s http://localhost:$PORT2/wallet/did | jq -r '.results[] | select(.posture == "posted") | .did')

echo "[INFO] $ADMIN_NAME DID: $DID1"
echo "[INFO] $AUTHOR_NAME DID: $DID2"

# Get connection from admin to author
CONN_JSON=$(curl -s http://localhost:$PORT1/connections)

# Try to match by public DID
CONN_ID=$(echo "$CONN_JSON" | jq -r ".results[] | select(.state == \"active\" and .their_public_did == \"$DID2\") | .connection_id" | head -n 1)

# Fallback: match by label (if author initiated)
if [[ -z "$CONN_ID" ]]; then
  CONN_ID=$(echo "$CONN_JSON" | jq -r ".results[] | select(.state == \"active\" and .their_label == \"$AUTHOR_NAME\") | .connection_id" | head -n 1)
fi

# Fallback: match by request_id
if [[ -z "$CONN_ID" ]]; then
  REQUEST_ID=$(curl -s http://localhost:$PORT2/connections | jq -r ".results[] | select(.state == \"active\" and .their_public_did == \"$DID1\") | .request_id" | head -n 1)

  if [[ -n "$REQUEST_ID" ]]; then
    CONN_ID=$(echo "$CONN_JSON" | jq -r ".results[] | select(.request_id == \"$REQUEST_ID\") | .connection_id" | head -n 1)
  fi
fi

if [[ -z "$CONN_ID" ]]; then
  echo "[ERROR] No active connection found between $ADMIN_NAME and $AUTHOR_NAME"
  exit 1
fi

echo "[INFO] Connection ID: $CONN_ID"

# Set admin as ENDORSER on this connection
curl -s -X POST "http://localhost:$PORT1/transactions/$CONN_ID/set-endorser-role?transaction_my_job=TRANSACTION_ENDORSER" > /dev/null

# Look up admin-side transaction via thread_id
TXN_ID=$(curl -s http://localhost:$PORT1/transactions | jq -r ".results[] | select(.thread_id == \"$AUTHOR_TXN_ID\" and .state == \"request_received\") | .transaction_id" | head -n 1)

if [[ -z "$TXN_ID" ]]; then
  echo "[ERROR] No transaction found on admin with thread_id: $AUTHOR_TXN_ID"
  exit 1
fi

echo "[INFO] Admin-local transaction ID: $TXN_ID"

# Endorse and write
curl -s -X POST "http://localhost:$PORT1/transactions/$TXN_ID/endorse" > /dev/null
curl -s -X POST "http://localhost:$PORT1/transactions/$TXN_ID/write" > /dev/null

echo "Transaction endorsed and written to the ledger"
