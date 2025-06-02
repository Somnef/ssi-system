#!/bin/bash

# Special script to spawn the admin agent and create its DID
# Usage: ./spawn_admin_agent.sh <admin_agent_http_port> <admin_agent_admin_port>

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

ADMIN_AGENT_NAME="admin-agent"
ADMIN_AGENT_HTTP_PORT=$1
ADMIN_AGENT_ADMIN_PORT=$2

if [ -z "$ADMIN_AGENT_ADMIN_PORT" ] || [ -z "$ADMIN_AGENT_HTTP_PORT" ]; then
    echo "Usage: $0 <admin_agent_http_port> <admin_agent_admin_port>"
    exit 1
fi

WALLET_NAME="${ADMIN_AGENT_NAME}_wallet"
WALLET_KEY="key_${ADMIN_AGENT_NAME}"

GENESIS_FILE="$SCRIPT_DIR/genesis.txn"
curl http://localhost:9000/genesis -o $GENESIS_FILE

# GENESIS_URL="http://greenlight.bcovrin.vonx.io/genesis"

# Create directories
mkdir -p "$SCRIPT_DIR/../agent_envs" "$SCRIPT_DIR/../agent_dids"

mkdir -p "$SCRIPT_DIR/../agent_wallets"
chmod -R 777 "$SCRIPT_DIR/../agent_wallets"

mkdir -p "$SCRIPT_DIR/../agent_wallets/$ADMIN_AGENT_NAME"
chmod -R 777 "$SCRIPT_DIR/../agent_wallets/$ADMIN_AGENT_NAME"

# Check if HTTP_PORT is already in use
if check_port_in_use $ADMIN_AGENT_HTTP_PORT; then
    echo "/!\ ERROR /!\ Port $ADMIN_AGENT_HTTP_PORT is already in use (possibly by another agent)."
    exit 1
fi

# Check if ADMIN_PORT is already in use
if check_port_in_use $ADMIN_AGENT_ADMIN_PORT; then
    echo "/!\ ERROR /!\ Port $ADMIN_AGENT_ADMIN_PORT is already in use (possibly by another agent)."
    exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -wq "$ADMIN_AGENT_NAME"; then
    echo "/!\ ERROR /!\ A Docker container named '$ADMIN_AGENT_NAME' already exists."
    echo "You can remove it with: docker rm -f $ADMIN_AGENT_NAME"
    exit 1
fi

# Save admin agent ports to env file
ENV_FILE="$SCRIPT_DIR/../agent_envs/${ADMIN_AGENT_NAME}.env"
echo "AGENT_HTTP_PORT=$ADMIN_AGENT_HTTP_PORT" >"$ENV_FILE"
echo "AGENT_ADMIN_PORT=$ADMIN_AGENT_ADMIN_PORT" >>"$ENV_FILE"

IMAGE_NAME="ghcr.io/openwallet-foundation/acapy-agent:py3.12-nightly-2025-05-08"

DOCKER_OPTIONS=(
    --name "$ADMIN_AGENT_NAME"
    -p "$ADMIN_AGENT_HTTP_PORT:$ADMIN_AGENT_HTTP_PORT"
    -p "$ADMIN_AGENT_ADMIN_PORT:8031"
    --network von_von
    -v "$SCRIPT_DIR/../agent_wallets/$ADMIN_AGENT_NAME:/home/aries/.acapy_agent/wallet/${ADMIN_AGENT_NAME}_wallet/"
    -v $GENESIS_FILE:/home/aries/genesis.txn
)

AGENT_ARGS=(
    start \
    --inbound-transport http 0.0.0.0 $ADMIN_AGENT_HTTP_PORT
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
    --label $ADMIN_AGENT_NAME
    --endpoint http://host.docker.internal:$ADMIN_AGENT_HTTP_PORT
    --public-invites
    --requests-through-public-did
)

# Run the ACA-Py admin agent
docker run -d "${DOCKER_OPTIONS[@]}" $IMAGE_NAME "${AGENT_ARGS[@]}"

# Wait for readiness
echo "Waiting for admin agent to become ready on port $ADMIN_AGENT_ADMIN_PORT..."
until curl -s http://localhost:$ADMIN_AGENT_ADMIN_PORT/status/ready | grep -q "ready"; do
    echo -n "."
    sleep 2
done

echo "Admin agent is ready."

DID_FILE="$SCRIPT_DIR/../agent_dids/${ADMIN_AGENT_NAME}_did.json"

# Check if DID already exists in the wallet
EXISTING_DID=$(curl -s http://localhost:$ADMIN_AGENT_ADMIN_PORT/wallet/did | jq -r '.results[0].did // empty')

if [ -n "$EXISTING_DID" ]; then
    echo "Wallet already contains a DID: $EXISTING_DID"
    echo "Skipping DID creation."

    # Optionally recreate the did.json file if it was missing
    if [ ! -f "$DID_FILE" ]; then
        curl -s http://localhost:$ADMIN_AGENT_ADMIN_PORT/wallet/did | jq '.results[0]' > "$DID_FILE"
    fi
else
    echo "Creating new DID..."
    RESPONSE=$(curl -s -X POST "http://localhost:$ADMIN_AGENT_ADMIN_PORT/wallet/did/create?method=sov&options.key_type=ed25519")
    echo "$RESPONSE" > "$DID_FILE"

    DID=$(echo "$RESPONSE" | pcregrep -o1 '"did": "(.*?)",')
    VERKEY=$(echo "$RESPONSE" | pcregrep -o1 '"verkey": "(.*?)",')

    # Output for Greenlight manual registration
    echo -e "\nAdmin DID ready. Please register the following DID as ENDORSER via Greenlight (http://greenlight.bcovrin.vonx.io):"
    echo "DID: $DID"
    echo "Verkey: $VERKEY"
    echo "Saved to: $DID_FILE"
fi