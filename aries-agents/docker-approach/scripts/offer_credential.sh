#!/bin/bash

# Usage: ./offer_credential.sh <issuer_name> <holder_name> <cred_def_id>

set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
ISSUER="$1"
HOLDER="$2"
CRED_DEF_ID="$3"

if [[ -z "$ISSUER" || -z "$HOLDER" || -z "$CRED_DEF_ID" ]]; then
  echo "Usage: $0 <issuer_name> <holder_name> <cred_def_id>"
  exit 1
fi

# Load envs
source "$SCRIPT_DIR/../agent_envs/$ISSUER.env"
PORT_ISSUER="$AGENT_ADMIN_PORT"

source "$SCRIPT_DIR/../agent_envs/$HOLDER.env"
PORT_HOLDER="$AGENT_ADMIN_PORT"

DID_ISSUER=$(curl -s http://localhost:$PORT_ISSUER/wallet/did | jq -r '.results[] | select(.posture=="posted") | .did')
DID_HOLDER=$(curl -s http://localhost:$PORT_HOLDER/wallet/did | jq -r '.results[] | select(.posture=="posted") | .did')

# --- Robust connection lookup ---
CONN_JSON=$(curl -s http://localhost:$PORT_ISSUER/connections)

CONN_ID=$(echo "$CONN_JSON" | jq -r ".results[] | select(.state == \"active\" and .their_public_did == \"$DID_HOLDER\") | .connection_id" | head -n 1)

if [[ -z "$CONN_ID" ]]; then
  CONN_ID=$(echo "$CONN_JSON" | jq -r ".results[] | select(.state == \"active\" and .their_label == \"$HOLDER\") | .connection_id" | head -n 1)
fi

if [[ -z "$CONN_ID" ]]; then
  REQ_ID=$(curl -s http://localhost:$PORT_HOLDER/connections | jq -r ".results[] | select(.state == \"active\" and .their_public_did == \"$DID_ISSUER\") | .request_id" | head -n 1)
  if [[ -n "$REQ_ID" ]]; then
    CONN_ID=$(echo "$CONN_JSON" | jq -r ".results[] | select(.request_id == \"$REQ_ID\") | .connection_id" | head -n 1)
  fi
fi

if [[ -z "$CONN_ID" ]]; then
  echo "[ERROR] No active connection found between $ISSUER and $HOLDER"
  exit 1
fi

echo "[INFO] Found active connection: $CONN_ID"

# --- Send credential offer ---
RESPONSE=$(curl -s -X POST "http://localhost:$PORT_ISSUER/issue-credential-2.0/send-offer" \
  -H "Content-Type: application/json" \
  -d '{
    "connection_id": "'"$CONN_ID"'",
    "filter": {
      "indy": {
        "cred_def_id": "'"$CRED_DEF_ID"'",
        "issuer_did": "'"$DID_ISSUER"'"
      }
    },
    "credential_preview": {
      "@type": "issue-credential/2.0/credential-preview",
      "attributes": [
        { "name": "first_name", "value": "Ahmed" },
        { "name": "last_name", "value": "Bousselat" },
        { "name": "degree", "value": "Master in Data Science" },
        { "name": "year", "value": "2023" }
      ]
    },
    "auto_remove": true,
    "trace": false
  }')

# Attempt to parse, fallback to raw if invalid
if echo "$RESPONSE" | jq . >/dev/null 2>&1; then
  echo "$RESPONSE" | jq .
else
  echo "[ERROR] Invalid JSON response:"
  echo "$RESPONSE"
fi
