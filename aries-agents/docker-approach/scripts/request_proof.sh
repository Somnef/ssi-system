#!/bin/bash

# Usage:
#   ./request_proof.sh <verifier_name> <holder_name>

set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
VERIFIER="$1"
HOLDER="$2"

if [[ -z "$VERIFIER" || -z "$HOLDER" ]]; then
  echo "Usage: $0 <verifier_name> <holder_name>"
  exit 1
fi

# Load agent envs
source "$SCRIPT_DIR/../agent_envs/$VERIFIER.env"
PORT_VERIFIER="$AGENT_ADMIN_PORT"

source "$SCRIPT_DIR/../agent_envs/$HOLDER.env"
PORT_HOLDER="$AGENT_ADMIN_PORT"

# Get posted DIDs (for connection match)
DID_VERIFIER=$(curl -s http://localhost:$PORT_VERIFIER/wallet/did | jq -r '.results[] | select(.posture=="posted") | .did')
DID_HOLDER=$(curl -s http://localhost:$PORT_HOLDER/wallet/did | jq -r '.results[] | select(.posture=="posted") | .did')

# Lookup connection ID from verifier to holder
CONN_JSON=$(curl -s http://localhost:$PORT_VERIFIER/connections)
CONN_ID=$(echo "$CONN_JSON" | jq -r ".results[] | select(.state == \"active\" and .their_public_did == \"$DID_HOLDER\") | .connection_id" | head -n 1)

if [[ -z "$CONN_ID" ]]; then
  CONN_ID=$(echo "$CONN_JSON" | jq -r ".results[] | select(.state == \"active\" and .their_label == \"$HOLDER\") | .connection_id" | head -n 1)
fi

if [[ -z "$CONN_ID" ]]; then
  echo "[ERROR] No active connection found between $VERIFIER and $HOLDER"
  exit 1
fi

echo "[INFO] Using connection_id: $CONN_ID"

# Send proof request (selective disclosure example: only requesting degree, year)
curl -s -X POST "http://localhost:$PORT_VERIFIER/present-proof-2.0/send-request" \
  -H "Content-Type: application/json" \
  -d '{
    "connection_id": "'"$CONN_ID"'",
    "auto_verify": true,
    "auto_remove": false,
    "presentation_request": {
      "indy": {
        "name": "Proof of degree",
        "version": "1.0",
        "requested_attributes": {
          "attr1_revealed": {
            "name": "degree",
            "restrictions": [{}]
          },
          "attr2_revealed": {
            "name": "year",
            "restrictions": [{}]
          }
        },
        "requested_predicates": {}
      }
    }
  }' | jq


echo "[DONE] Proof request sent from $VERIFIER to $HOLDER"
