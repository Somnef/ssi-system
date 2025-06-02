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
    echo "Usage: $0 <agent_name> <http_port> <admin_port> [--export-wallet] [--import-wallet]"
    exit 1
fi

WALLET_NAME="${AGENT_NAME}_wallet"
WALLET_KEY="key_${AGENT_NAME}"

GENESIS_FILE="$SCRIPT_DIR/genesis.txn"
curl http://localhost:9000/genesis -o $GENESIS_FILE

# GENESIS_URL="http://greenlight.bcovrin.vonx.io/genesis"

# Create directory for env files and dids
mkdir -p "$SCRIPT_DIR/../agent_envs" "$SCRIPT_DIR/../agent_dids"

mkdir -p "$SCRIPT_DIR/../agent_wallets"
chmod -R 777 "$SCRIPT_DIR/../agent_wallets"

mkdir -p "$SCRIPT_DIR/../agent_wallets/$AGENT_NAME"
chmod -R 777 "$SCRIPT_DIR/../agent_wallets/$AGENT_NAME"

# Check if HTTP_PORT is already in use
if check_port_in_use $AGENT_HTTP_PORT; then
    echo "/!\ ERROR /!\ Port $AGENT_HTTP_PORT is already in use (possibly by another agent)."
    exit 1
fi

# Check if ADMIN_PORT is already in use
if check_port_in_use $AGENT_ADMIN_PORT; then
    echo "/!\ ERROR /!\ Port $AGENT_ADMIN_PORT is already in use (possibly by another agent)."
    exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -wq "$AGENT_NAME"; then
    echo "/!\ ERROR /!\ A Docker container named '$AGENT_NAME' already exists."
    echo "You can remove it with: docker rm -f $AGENT_NAME"
    exit 1
fi

# Save ports to individual agent .env file
ENV_FILE="$SCRIPT_DIR/../agent_envs/${AGENT_NAME}.env"
echo "AGENT_HTTP_PORT=$AGENT_HTTP_PORT" >"$ENV_FILE"
echo "AGENT_ADMIN_PORT=$AGENT_ADMIN_PORT" >>"$ENV_FILE"

IMAGE_NAME="ghcr.io/openwallet-foundation/acapy-agent:py3.12-nightly-2025-05-08"

DOCKER_OPTIONS=(
    --name "$AGENT_NAME"
    -p "$AGENT_HTTP_PORT:$AGENT_HTTP_PORT"
    -p "$AGENT_ADMIN_PORT:8031"
    --network von_von
    -v "$SCRIPT_DIR/../agent_wallets/$AGENT_NAME:/home/aries/.acapy_agent/wallet/${AGENT_NAME}_wallet/"
    -v $GENESIS_FILE:/home/aries/genesis.txn
)

AGENT_ARGS=(
    start \
    --inbound-transport http 0.0.0.0 $AGENT_HTTP_PORT
    --outbound-transport http
    --admin 0.0.0.0 8031
    --admin-insecure-mode
    --log-level info
    --wallet-type askar
    --wallet-name $WALLET_NAME
    --wallet-key $WALLET_KEY
    --auto-provision
    # --genesis-url $GENESIS_URL
    --genesis-file /home/aries/genesis.txn
    --label $AGENT_NAME
    --endpoint http://host.docker.internal:$AGENT_HTTP_PORT
    --public-invites
    --requests-through-public-did
)

docker run -d "${DOCKER_OPTIONS[@]}" $IMAGE_NAME "${AGENT_ARGS[@]}"

# Wait for the agent to be ready
echo "Waiting for $AGENT_NAME to be ready on port $AGENT_ADMIN_PORT..."
until curl -s http://localhost:$AGENT_ADMIN_PORT/status/ready | grep -q "ready"; do
    echo -n "."
    sleep 2
done

echo "Agent is ready."

DID_FILE="$SCRIPT_DIR/../agent_dids/${AGENT_NAME}_did.json"

# Check if DID already exists in the wallet
EXISTING_DID=$(curl -s http://localhost:$AGENT_ADMIN_PORT/wallet/did | jq -r '.results[0].did // empty')

if [ -n "$EXISTING_DID" ]; then
    echo "Wallet already contains a DID: $EXISTING_DID"
    echo "Skipping DID creation."

    # Optionally recreate the did.json file if it was missing
    if [ ! -f "$DID_FILE" ]; then
        curl -s http://localhost:$AGENT_ADMIN_PORT/wallet/did | jq '.results[0]' > "$DID_FILE"
    fi
else
    echo "Creating new DID..."
    RESPONSE=$(curl -s -X POST "http://localhost:$AGENT_ADMIN_PORT/wallet/did/create?method=sov&options.key_type=ed25519")
    echo "$RESPONSE" > "$DID_FILE"

    DID=$(echo "$RESPONSE" | pcregrep -o1 '"did": "(.*?)",')
    VERKEY=$(echo "$RESPONSE" | pcregrep -o1 '"verkey": "(.*?)",')

    echo -e "\nAgent DID ready. Please register it using ./admin_register_did.sh $AGENT_NAME"
    echo "DID: $DID"
    echo "Verkey: $VERKEY"
    echo "Saved to: $DID_FILE"
fi
