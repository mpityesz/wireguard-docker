#!/bin/bash

### --- Parse arguments --- ###
ACTION=""
DOCKER_NETWORK=""
DOCKER_SUBNET=""
DOCKER_GATEWAY=""

for arg in "$@"; do
    case $arg in
        --action=*) ACTION="${arg#*=}"; shift ;;
        --network=*) DOCKER_NETWORK="${arg#*=}"; shift ;;
        --subnet=*) DOCKER_SUBNET="${arg#*=}"; shift ;;
        --gateway=*) DOCKER_GATEWAY="${arg#*=}"; shift ;;
        *) echo "Unknown parameter: $arg"; exit 1 ;;
    esac
done


### --- Default values --- ###
# Default network name matches the docker-compose.yml
: "${DOCKER_NETWORK:=wireguard_vpn_net}"
# Default subnet/gateway from the original script (user can override)
: "${DOCKER_SUBNET:=172.35.0.0/24}"
: "${DOCKER_GATEWAY:=172.35.0.1}"


### --- Validate action --- ###
if [[ -z "$ACTION" ]]; then
    echo "Missing --action parameter (must be 'enable' or 'disable')"
    exit 1
fi
if [[ "$ACTION" != "enable" && "$ACTION" != "disable" ]]; then
    echo "Invalid action: $ACTION (must be 'enable' or 'disable')"
    exit 1
fi


### --- Perform action --- ###
if [[ "$ACTION" == "enable" ]]; then
    echo "Ensuring Docker network '$DOCKER_NETWORK' exists..."
    # Check if network exists
    if docker network inspect "$DOCKER_NETWORK" > /dev/null 2>&1; then
        echo " = Docker network '$DOCKER_NETWORK' already exists."
    else
        # Create Docker bridge network with specified subnet and gateway
        echo "   Creating Docker network '$DOCKER_NETWORK'..."
        docker network create \
            --driver=bridge \
            --subnet="$DOCKER_SUBNET" \
            --gateway="$DOCKER_GATEWAY" \
            "$DOCKER_NETWORK"
        if [[ $? -eq 0 ]]; then
             echo " + Docker network '$DOCKER_NETWORK' created with subnet $DOCKER_SUBNET and gateway $DOCKER_GATEWAY."
        else
             echo " ! ERROR: Failed to create Docker network '$DOCKER_NETWORK'."
             # Optional: exit 1 here if creation failure should stop everything
        fi
    fi

elif [[ "$ACTION" == "disable" ]]; then
    echo "Removing Docker network '$DOCKER_NETWORK' if it exists..."
    # Check if network exists
    if docker network inspect "$DOCKER_NETWORK" > /dev/null 2>&1; then
        # Remove Docker network
        docker network rm "$DOCKER_NETWORK"
        if [[ $? -eq 0 ]]; then
            echo " - Docker network '$DOCKER_NETWORK' removed."
        else
            echo " ! ERROR: Failed to remove Docker network '$DOCKER_NETWORK'. Is it in use?"
            # Optional: exit 1 here
        fi
    else
        echo " = Docker network '$DOCKER_NETWORK' does not exist."
    fi
fi

echo "Docker network operation finished."
