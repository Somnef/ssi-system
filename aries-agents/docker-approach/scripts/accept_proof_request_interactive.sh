#!/bin/bash

# Usage:
#   ./accept_proof_request_interactive.sh <holder_name>

set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
HOLDER="$1"

if [[ -z "$HOLDER" ]]; then
  echo "Usage: $0 <holder_name>"
  exit 1
fi

source "$SCRIPT_DIR/../agent_envs/$HOLDER.env"
PORT="$AGENT_ADMIN_PORT"

PRES_EX_ID=$(curl -s http://localhost:$PORT/present-proof-2.0/records \
  | jq -r '.results[] | select(.state == "request-received") | .pres_ex_id' | head -n 1)

if [[ -z "$PRES_EX_ID" ]]; then
  echo "[INFO] No pending proof requests for $HOLDER"
  exit 0
fi

echo "[INFO] Selected pres_ex_id: $PRES_EX_ID"

# List matching credentials
CREDS=$(curl -s "http://localhost:$PORT/present-proof-2.0/records/$PRES_EX_ID/credentials")

echo "[INFO] Matching credentials found:"
INDEX=0
echo "$CREDS" | jq -c '.[]' | while read -r cred; do
  DEGREE=$(echo "$cred" | jq -r '.cred_info.attrs.degree')
  YEAR=$(echo "$cred" | jq -r '.cred_info.attrs.year')
  FIRST=$(echo "$cred" | jq -r '.cred_info.attrs.first_name')
  LAST=$(echo "$cred" | jq -r '.cred_info.attrs.last_name')
  echo "[$INDEX] $FIRST $LAST, $DEGREE, $YEAR"
  INDEX=$((INDEX + 1))
done

read -rp "Select credential to present (0 to $(($INDEX - 1))): " SELECTION

SELECTED_CRED_ID=$(echo "$CREDS" | jq -r ".[$SELECTION].cred_info.referent")
echo "[INFO] Sending proof presentation using credential: $SELECTED_CRED_ID"

# Send the presentation
jq -n \
  --arg cred_id "$SELECTED_CRED_ID" \
  '{
    indy: {
      requested_attributes: {
        attr1_revealed: {cred_id: $cred_id, revealed: true},
        attr2_revealed: {cred_id: $cred_id, revealed: true}
      },
      requested_predicates: {},
      self_attested_attributes: {},
      trace: false
    }
  }' | curl -s -X POST \
  "http://localhost:$PORT/present-proof-2.0/records/$PRES_EX_ID/send-presentation" \
  -H "Content-Type: application/json" \
  -d @- > /dev/null

echo "[DONE] Proof presentation sent from $HOLDER"
