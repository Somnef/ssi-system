#!/bin/bash

# Capture PIDs to clean up later
pids=()
services=()

# On exit or Ctrl+C, kill all backgrounded minikube services
cleanup() {
    echo -e "\nStopping tunnels..."
    for pid in "${pids[@]}"; do
        kill "$pid" 2>/dev/null
    done
    wait
    echo "All tunnels stopped."
}
trap cleanup EXIT

# Get all matching service names
while read -r lin; do
    services+=("$lin")
done < <(kubectl get svc | grep -Po 'acapy-.*?service')

# Start each service tunnel in the background and get its URL
for svc in "${services[@]}"; do
    echo "Starting tunnel for $svc..."
    
    # This runs in the background and keeps the tunnel open
    minikube service "$svc" --url 2>/dev/null > "./tmp/${svc}_url.txt" &
    
    pid=$!
    pids+=("$pid")
    
    # Wait briefly to ensure the URL is written
    sleep 2
    
    # Read the URL from the temp file
    if [[ -f "./tmp/${svc}_url.txt" ]]; then
        url=$(cat "./tmp/${svc}_url.txt")
        echo "$url"
        echo ""
    else
        echo "[No URL retrieved]"
    fi
done

echo -e "\nTunnels are up. Press Ctrl+C to terminate."
# Keep the script running so tunnels stay alive
wait
