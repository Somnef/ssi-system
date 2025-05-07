#!/bin/bash

# ACA-Py Docker Agent Launcher Script
# Usage: ./spawn_agent.sh <agent_name> <http_port> <admin_port>

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# Check if a port is in use
check_port_in_use() {
  PORT=$1
  if ss -ltn | grep -q ":$PORT "; then
    return 0
  elif netstat -ltn 2>/dev/null | grep -q ":$PORT "; then
    return 0
  else
    return 1
  fi
}

AGENT_NAME=$1
AGENT_HTTP_PORT=$2
AGENT_ADMIN_PORT=$3

if [ -z "$AGENT_NAME" ] || [ -z "$AGENT_HTTP_PORT" ] || [ -z "$AGENT_ADMIN_PORT" ]; then
  echo "Usage: $0 <agent_name> <http_port> <admin_port>"
  exit 1
fi

WALLET_NAME="${AGENT_NAME}_wallet"
WALLET_KEY="key_${AGENT_NAME}"
GENESIS_URL="http://greenlight.bcovrin.vonx.io/genesis"

# Create directory for env files and dids
mkdir -p "$SCRIPT_DIR/agent_envs" "$SCRIPT_DIR/agent_dids"

# Check if HTTP_PORT is already in use
if check_port_in_use $AGENT_HTTP_PORT ; then
  echo "/!\ ERROR /!\ Port $AGENT_HTTP_PORT is already in use (possibly by another agent)."
  exit 1
fi

# Check if ADMIN_PORT is already in use
if check_port_in_use $AGENT_ADMIN_PORT ; then
  echo "/!\ ERROR /!\ Port $AGENT_ADMIN_PORT is already in use (possibly by another agent)."
  exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -wq "$AGENT_NAME"; then
  echo "/!\ ERROR /!\ A Docker container named '$AGENT_NAME' already exists."
  echo "You can remove it with: docker rm -f $AGENT_NAME"
  exit 1
fi

# Save ports to individual agent .env file
ENV_FILE="$SCRIPT_DIR/agent_envs/${AGENT_NAME}.env"
echo "AGENT_HTTP_PORT=$AGENT_HTTP_PORT" > "$ENV_FILE"
echo "AGENT_ADMIN_PORT=$AGENT_ADMIN_PORT" >> "$ENV_FILE"

# Run the ACA-Py agent container
docker run -d \
  --name $AGENT_NAME \
  -p $AGENT_HTTP_PORT:8020 \
  -p $AGENT_ADMIN_PORT:8031 \
  ghcr.io/openwallet-foundation/aries-cloudagent-python:py3.9-indy-1.16.0-0.12.6 \
  start \
  --inbound-transport http 0.0.0.0 8020 \
  --outbound-transport http \
  --admin 0.0.0.0 8031 \
  --admin-insecure-mode \
  --log-level info \
  --wallet-type askar \
  --wallet-name $WALLET_NAME \
  --wallet-key $WALLET_KEY \
  --auto-provision \
  --genesis-url $GENESIS_URL \
  --label $AGENT_NAME \
  --endpoint http://localhost:$AGENT_HTTP_PORT

# Wait for the agent to be ready
echo "Waiting for $AGENT_NAME to be ready on port $AGENT_ADMIN_PORT..."
until curl -s http://localhost:$AGENT_ADMIN_PORT/status/ready | grep -q "ready"; do
  echo -n "."
  sleep 2
done

echo "Agent is ready. Creating new DID..."

DID_FILE="$SCRIPT_DIR/agent_dids/${AGENT_NAME}_did.json"

if [ -f "$DID_FILE" ]; then
    echo "/!\ WARNING /!\ DID file already exists for $AGENT_NAME: $DID_FILE"
    
    read -p "Do you want to overwrite it? (y/n) " choice
    case "$choice" in 
        y|Y ) echo "Overwriting existing DID file...";;
        n|N ) 
        echo "Aborting DID creation. Cleaning up agent container..."
        docker stop "$AGENT_NAME" >/dev/null 2>&1
        docker rm "$AGENT_NAME" >/dev/null 2>&1
        echo "🧹 Agent container $AGENT_NAME stopped and removed."
        exit 1
        ;;
        * ) 
        echo "Invalid input. Aborting."
        docker stop "$AGENT_NAME" >/dev/null 2>&1
        docker rm "$AGENT_NAME" >/dev/null 2>&1
        exit 1
        ;;
    esac
fi

RESPONSE=$(curl -s -X POST "http://localhost:$AGENT_ADMIN_PORT/wallet/did/create?method=sov&options.key_type=ed25519")
echo "$RESPONSE" > "$DID_FILE"

DID=$(echo "$RESPONSE" | pcregrep -o1 '"did": "(.*?)",')
VERKEY=$(echo "$RESPONSE" | pcregrep -o1 '"verkey": "(.*?)",')

echo -e "\nAgent DID ready. Please register it using ./admin_register_did.sh $AGENT_NAME"
echo "DID: $DID"
echo "Verkey: $VERKEY"
echo "Saved to: $DID_FILE"
