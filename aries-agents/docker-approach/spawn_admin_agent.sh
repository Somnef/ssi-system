#!/bin/bash

# Special script to spawn the admin agent and create its DID
# Usage: ./spawn_admin_agent.sh <admin_agent_admin_port>

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

ADMIN_AGENT_NAME="admin-agent"
ADMIN_AGENT_HTTP_PORT=$1
ADMIN_AGENT_ADMIN_PORT=$2

if [ -z "$ADMIN_AGENT_ADMIN_PORT" ] || [ -z "$ADMIN_AGENT_HTTP_PORT" ]; then
  echo "Usage: $0 <admin_agent_http_port> <admin_agent_admin_port>"
  exit 1
fi

WALLET_NAME="${ADMIN_AGENT_NAME}_wallet"
WALLET_KEY="key_${ADMIN_AGENT_NAME}"
GENESIS_URL="http://greenlight.bcovrin.vonx.io/genesis"

# Create directories
mkdir -p agent_envs agent_dids

# Check if HTTP_PORT is already in use
if check_port_in_use $ADMIN_AGENT_HTTP_PORT ; then
  echo "/!\ ERROR /!\ Port $ADMIN_AGENT_HTTP_PORT is already in use (possibly by another agent)."
  exit 1
fi

# Check if ADMIN_PORT is already in use
if check_port_in_use $ADMIN_AGENT_ADMIN_PORT ; then
  echo "/!\ ERROR /!\ Port $ADMIN_AGENT_ADMIN_PORT is already in use (possibly by another agent)."
  exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -wq "$AGENT_NAME"; then
  echo "/!\ ERROR /!\ A Docker container named '$AGENT_NAME' already exists."
  echo "You can remove it with: docker rm -f $AGENT_NAME"
  exit 1
fi

# Save admin agent ports to env file
ENV_FILE="agent_envs/${ADMIN_AGENT_NAME}.env"
echo "HTTP_PORT=$ADMIN_AGENT_HTTP_PORT" > "$ENV_FILE"
echo "ADMIN_PORT=$ADMIN_AGENT_ADMIN_PORT" >> "$ENV_FILE"

# Run the ACA-Py admin agent
docker ps | grep -q "$ADMIN_AGENT_NAME"
if [ $? -eq 0 ]; then
  echo "Warning: A container named $ADMIN_AGENT_NAME is already running. It may conflict with this one."
  exit 1
fi
docker run -d \
  --name $ADMIN_AGENT_NAME \
  -p $ADMIN_AGENT_HTTP_PORT:8020 \
  -p $ADMIN_AGENT_ADMIN_PORT:8031 \
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
  --label $ADMIN_AGENT_NAME \
  --endpoint http://localhost:$ADMIN_AGENT_HTTP_PORT

# Wait for readiness
echo "Waiting for admin agent to become ready on port $ADMIN_AGENT_ADMIN_PORT..."
until curl -s http://localhost:$ADMIN_AGENT_ADMIN_PORT/status/ready | grep -q "ready"; do
  echo -n "."
  sleep 2
done

echo "Admin agent is ready. Creating new DID..."

DID_FILE="agent_dids/${ADMIN_AGENT_NAME}_did.json"

if [ -f "$DID_FILE" ]; then
    echo "/!\ WARNING /!\ DID file already exists for $ADMIN_AGENT_NAME: $DID_FILE"
    
    read -p "Do you want to overwrite it? (y/n) " choice
    case "$choice" in 
        y|Y ) echo "Overwriting existing DID file...";;
        n|N ) 
        echo "Aborting DID creation. Cleaning up agent container..."
        docker stop "$ADMIN_AGENT_NAME" >/dev/null 2>&1
        docker rm "$ADMIN_AGENT_NAME" >/dev/null 2>&1
        echo "🧹 Agent container $ADMIN_AGENT_NAME stopped and removed."
        exit 1
        ;;
        * ) 
        echo "Invalid input. Aborting."
        docker stop "$ADMIN_AGENT_NAME" >/dev/null 2>&1
        docker rm "$ADMIN_AGENT_NAME" >/dev/null 2>&1
        exit 1
        ;;
    esac
fi

RESPONSE=$(curl -s -X POST "http://localhost:$ADMIN_AGENT_ADMIN_PORT/wallet/did/create?method=sov&options.key_type=ed25519")
echo "$RESPONSE" > "$DID_FILE"

DID=$(echo "$RESPONSE" | pcregrep -o1 '"did": "(.*?)",')
VERKEY=$(echo "$RESPONSE" | pcregrep -o1 '"verkey": "(.*?)",')

# Output for Greenlight manual registration
echo -e "\nAdmin DID ready. Please register the following DID as ENDORSER via Greenlight (http://greenlight.bcovrin.vonx.io):"
echo "DID: $DID"
echo "Verkey: $VERKEY"
echo "Saved to: $DID_FILE"
