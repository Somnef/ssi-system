#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

echo ""

# Read all agent names after --agent-names and store them in an array
agent_names=()
for arg in "$@"; do
    if [[ "$arg" == "--agent-names" ]]; then
        shift
        while [[ "$1" && "$1" != "--"* ]]; do
            agent_names+=("$1")
            shift
        done
        break
    fi
done

# Check if "admin-agent" is in the agent_names array
tmp_arr=()
for agent_name in "${agent_names[@]}"; do
    if [[ "$agent_name" == "admin-agent" ]]; then
        echo -e "[INFO] 'admin-agent' cannot be deleted automatically and must be removed manually. Skipping.\n"
    fi

    [[ "$agent_name" != "admin-agent" ]] && tmp_arr+=( "$agent_name" )
done
agent_names=("${tmp_arr[@]}")


# Look for docker containers with matching agent names
matching_containers=()
for agent in "${agent_names[@]}"; do
    containers=$(docker ps -a --filter "name=^${agent}$" --format "{{.ID}}: {{.Names}}")
    if [[ -z "$containers" ]]; then
        echo "[NO MATCH] No matching Docker containers found for agent name '$agent'"
        :
    else
        # echo "[MATCH] Found container(s) for agent '$agent': '$containers'"
        matching_containers+=("$containers")
    fi
done

# Request confirmation for deletion
if [[ ${#matching_containers[@]} -gt 0 ]]; then
    echo -e "\nThe following containers will be deleted:"
    for container in "${matching_containers[@]}"; do
        echo "- $container"
    done

    echo ""
    read -p "Are you sure you want to delete these containers? (y/N): " confirmation
    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        echo ""
        for container in "${matching_containers[@]}"; do
            container_id=$(echo "$container" | cut -d':' -f1)
            docker rm -f "$container_id"
            echo "Deleted container: '$container'"
        done
    else
        echo "Deletion canceled."
    fi
else
    echo -e "\nNo containers to delete."
fi

# Check for --delete-data parameter
delete_data=false
for arg in "$@"; do
    if [[ "$arg" == "--delete-data" ]]; then
        delete_data=true
        break
    fi
done

if [[ "$delete_data" == true ]]; then
    echo ""

    files_to_delete=()
    for agent in "${agent_names[@]}"; do
        files_to_delete+=$(find $SCRIPT_DIR -name "*$agent*")
    done

    echo "The --delete-data flag is set. The following files/directories will be deleted (env, did and wallet):"
    echo -e "$files_to_delete\n"

    echo ""
    read -p "Are you sure you want to proceed ? (y/N): " delete_data_confirmation
    if [[ ! "$delete_data_confirmation" =~ ^[Yy]$ ]]; then
        echo "Data deletion canceled."
        exit 0
    fi
        
    echo -e "\nDeleting..."
fi

# check for --reset-db parameter
reset_db=false
for arg in "$@"; do
    if [[ "$arg" == "--reset-db" ]]; then
        reset_db=true
        break
    fi
done

if [[ "$reset_db" == true ]]; then
    echo ""

    echo "[INFO] For this part of the script to work, make ensure that the 'ssi-app-env' conda environment is active. Otherwise, deny the next step and start over."
    echo "Resetting MongoDB collections."
    read -p "Are you sure you want to proceed ? (y/N): " reset_db_confirmation

    if [[ ! "$reset_db_confirmation" =~ ^[Yy]$ ]]; then
        echo "DB reset canceled."
        exit 0
    fi

    echo -e "\nResetting..."

    (
        # conda activate ssi-app-env
        cd $SCRIPT_DIR/../../../backend
        python -c "from utils.user_store import reset_db; reset_db()"
    )

fi