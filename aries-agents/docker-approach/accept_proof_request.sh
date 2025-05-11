#!/bin/bash

# Usage:
#   ./accept_proof_request.sh <holder_name>              # Auto-accept first proof request
#   ./accept_proof_request.sh <holder_name> list         # List all pending proof requests
#   ./accept_proof_request.sh <holder_name> <pres_ex_id> # Accept specific proof request

set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
HOLDER="$1"
OPTION="$2"

if [[ -z "$HOLDER" ]]; then
  echo "Usage: $0 <holder_name> [list | <pres_ex_id>]"
  exit 1
fi

source "$SCRIPT_DIR/agent_envs/$HOLDER.env"
PORT="$AGENT_ADMIN_PORT"

if [[ "$OPTION" == "list" ]]; then
  echo "[INFO] Listing pending proof requests for $HOLDER..."

  PROOFS=$(curl -s http://localhost:$PORT/present-proof-2.0/records)
  CONNECTIONS=$(curl -s http://localhost:$PORT/connections)

  echo "$PROOFS" | jq -c '.results[] | select(.state == "request-received")' \
  | while read -r record; do
      PRES_ID=$(echo "$record" | jq -r '.pres_ex_id')
      THREAD_ID=$(echo "$record" | jq -r '.thread_id')
      CONN_ID=$(echo "$record" | jq -r '.connection_id')
      DID=$(echo "$CONNECTIONS" | jq -r ".results[] | select(.connection_id == \"$CONN_ID\") | .their_public_did // \"n/a\"")

      # Format detection
      FORMAT=$(echo "$record" | jq -r 'if .by_format.pres_request.anoncreds then "anoncreds" elif .by_format.pres_request.indy then "indy" else "unknown" end')

      ATTRS=$(echo "$record" | jq -r ".by_format.pres_request.$FORMAT.requested_attributes | to_entries | map(.value.name) | join(\", \")")
      PREDICATES=$(echo "$record" | jq -r ".by_format.pres_request.$FORMAT.requested_predicates | to_entries | map(\"\(.value.name) \(.value.p_type) \(.value.p_value)\") | join(\", \")")

      echo "pres_ex_id:     $PRES_ID"
      echo "thread_id:      $THREAD_ID"
      echo "verifier_did:   $DID"
      echo "requested:      $ATTRS"
      if [[ -n "$PREDICATES" && "$PREDICATES" != "null" ]]; then
        echo "predicates:     $PREDICATES"
      fi
      echo "---"
  done

  exit 0
fi

# Use provided ID or auto-select first
if [[ -n "$OPTION" ]]; then
  PRES_EX_ID="$OPTION"
else
  PRES_EX_ID=$(curl -s http://localhost:$PORT/present-proof-2.0/records \
    | jq -r '.results[] | select(.state == "request-received") | .pres_ex_id' | head -n 1)

  if [[ -z "$PRES_EX_ID" ]]; then
    echo "[INFO] No pending proof requests for $HOLDER"
    exit 0
  fi

  echo "[INFO] Auto-selecting proof request: $PRES_EX_ID"
fi

echo "[INFO] Preparing and sending proof for request $PRES_EX_ID..."

curl -s -X POST "http://localhost:$PORT/present-proof-2.0/records/$PRES_EX_ID/send-presentation" \
  -H "Content-Type: application/json" \
  -d '{}' > /dev/null

echo "[DONE] Proof presentation sent from $HOLDER"
