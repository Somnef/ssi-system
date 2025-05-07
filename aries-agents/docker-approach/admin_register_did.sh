#!/bin/bash

# Admin DID registration script
# Usage: ./admin_register_did.sh <agent_name>

AGENT_NAME=$1

if [ -z "$AGENT_NAME" ]; then
  echo "Usage: $0 <agent_name>"
  exit 1
fi

# Load admin agent ports
if [ ! -f agent_envs/admin-agent.env ]; then
  echo "Error: agent_envs/admin-agent.env not found."
  exit 1
fi

ADMIN_AGENT_ADMIN_PORT=$(grep ADMIN_PORT agent_envs/admin-agent.env | cut -d '=' -f2)

# Load target agent ports
if [ ! -f agent_envs/${AGENT_NAME}.env ]; then
  echo "Error: agent_envs/${AGENT_NAME}.env not found."
  exit 1
fi

AGENT_ADMIN_PORT=$(grep ADMIN_PORT agent_envs/${AGENT_NAME}.env | cut -d '=' -f2)

if [ -z "$ADMIN_AGENT_ADMIN_PORT" ] || [ -z "$AGENT_ADMIN_PORT" ]; then
  echo "Error: Could not parse admin ports from .env files."
  exit 1
fi

# Wait for target agent to be ready
echo "Checking if $AGENT_NAME is ready on port $AGENT_ADMIN_PORT..."
until curl -s http://localhost:$AGENT_ADMIN_PORT/status/ready | grep -q "ready"; do
  echo -n "."
  sleep 2
done

# Create DID if not already done
mkdir -p agent_dids
DID_FILE="agent_dids/${AGENT_NAME}_did.json"

if [ ! -f "$DID_FILE" ]; then
  echo "/!\ ERROR /!\ DID file $DID_FILE does not exist for agent $AGENT_NAME, please make sure the agent was setup correctly. Exiting."
  exit 1
else
  echo "DID already exists for $AGENT_NAME. Reusing existing file."
  RESPONSE=$(cat "$DID_FILE")
fi

DID=$(echo "$RESPONSE" | pcregrep -o1 '"did": "(.*?)",')
VERKEY=$(echo "$RESPONSE" | pcregrep -o1 '"verkey": "(.*?)",')

# Register DID using admin agent
echo -e "\nRegistering DID on ledger..."
curl -s -X POST "http://localhost:$ADMIN_AGENT_ADMIN_PORT/ledger/register-nym?did=$DID&verkey=$VERKEY&alias=somnef-$AGENT_NAME"

# Assign DID as public
echo -e "\nAssigning public DID..."
curl -s -X POST "http://localhost:$AGENT_ADMIN_PORT/wallet/did/public?did=$DID"

echo -e "\nDID registered, imported, and assigned for $AGENT_NAME: $DID"
