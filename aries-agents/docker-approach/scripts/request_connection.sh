#!/bin/bash

# Usage: ./request_connection.sh <agent1> <agent2>

set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
AGENT1="$1"
AGENT2="$2"

if [[ -z "$AGENT1" || -z "$AGENT2" ]]; then
  echo "Usage: $0 <agent1> <agent2>"
  exit 1
fi

# Load agent configs
source "$SCRIPT_DIR/../agent_envs/$AGENT1.env"
PORT1="$AGENT_ADMIN_PORT"

source "$SCRIPT_DIR/../agent_envs/$AGENT2.env"
PORT2="$AGENT_ADMIN_PORT"

# Get posted DIDs
DID1=$(curl -s http://localhost:$PORT1/wallet/did | jq -r '.results[] | select(.posture == "posted") | .did')
DID2=$(curl -s http://localhost:$PORT2/wallet/did | jq -r '.results[] | select(.posture == "posted") | .did')

echo "[INFO] $AGENT1 DID: $DID1"
echo "[INFO] $AGENT2 DID: $DID2"

# Check both sides for an existing connection with each other's DID
CONN_INFO_1=$(curl -s http://localhost:$PORT1/connections | jq -r --arg did "$DID2" '
  .results[] | select(.their_public_did == $did) | "\(.connection_id) \(.rfc23_state)"' | head -n 1)

CONN_INFO_2=$(curl -s http://localhost:$PORT2/connections | jq -r --arg did "$DID1" '
  .results[] | select(.their_public_did == $did) | "\(.connection_id) \(.rfc23_state)"' | head -n 1)

if [[ -n "$CONN_INFO_1" || -n "$CONN_INFO_2" ]]; then
  echo "[INFO] Existing connection found:"
  [[ -n "$CONN_INFO_1" ]] && echo "$AGENT1 → $AGENT2: $CONN_INFO_1"
  [[ -n "$CONN_INFO_2" ]] && echo "$AGENT2 → $AGENT1: $CONN_INFO_2"
  exit 0
fi

# No connection found → initiate request from agent1 to agent2
echo "[INFO] No existing connection. Sending request from $AGENT1 to $AGENT2..."

RESP=$(curl -s -X POST "http://localhost:$PORT1/didexchange/create-request?their_public_did=$DID2&label=$AGENT1")
echo "$RESP" | jq '{connection_id, request_id, rfc23_state}'
