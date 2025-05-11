#!/bin/bash

# Usage:
#   ./get_proof_credentials.sh <holder_name> <pres_ex_id>

set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
HOLDER="$1"
PRES_EX_ID="$2"

if [[ -z "$HOLDER" || -z "$PRES_EX_ID" ]]; then
  echo "Usage: $0 <holder_name> <pres_ex_id>"
  exit 1
fi

source "$SCRIPT_DIR/agent_envs/$HOLDER.env"
PORT="$AGENT_ADMIN_PORT"

# Query matching credentials for each referent
RESP=$(curl -s "http://localhost:$PORT/present-proof-2.0/records/$PRES_EX_ID/credentials?count=100")

if [[ -z "$RESP" || "$RESP" == "[]" ]]; then
  echo "[]"
  exit 0
fi

# Group by referent (referent is the internal ACA-Py key like "attr1_revealed")
echo "$RESP" | jq -rs '
  group_by(.presentation_referents[0]) | 
  map({ (.[0].presentation_referents[0]): 
    map({
      cred_id: .cred_info.referent,
      schema_id: .cred_info.schema_id,
      cred_def_id: .cred_info.cred_def_id,
      attrs: .cred_info.attrs
    })
  }) | add'
