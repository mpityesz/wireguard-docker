#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e


### --- Configuration --- ###
# Match script names from run.sh
UFW_SCRIPT="./wireguard-ufw-manager.sh"
DOCKER_NET_SCRIPT="./wireguard-docker-network.sh"
IPTABLES_SCRIPT="./wireguard-iptables-manager.sh"
COMPOSE_FILE="wireguard-vpn-compose.yml"


# Match parameters used during setup (needed for rule removal)
UFW_PORTS="51820/udp"
DOCKER_NETWORK_NAME="wireguard_vpn_net"
WG_SUBNET="10.13.13.0/24"
# HOST_INTERFACE is auto-detected in the iptables script


echo "--- Starting WireGuard VPN Termination ---"


### --- 1. Stop and Remove Docker Container --- ###
echo "Stopping and removing WireGuard container..."
# Use -f if compose file is not named docker-compose.yml or is elsewhere
docker-compose -f "$COMPOSE_FILE" down


### --- 2. Disable IPTables Rules --- ###
echo "Disabling IPTables rules..."
# Using default WG subnet from script ('10.13.13.0/24')
# Using auto-detected interface from script
sudo "$IPTABLES_SCRIPT" --action=disable --wg-subnet="$WG_SUBNET"
# Add --interface here if auto-detect was overridden during setup


### --- 3. Disable UFW Rules --- ###
echo "Disabling UFW rules..."
sudo "$UFW_SCRIPT" --action=disable --ports="$UFW_PORTS"


### --- 4. Remove Docker Network --- ###
# Note: Only do this if the network is exclusively for this service
echo "Removing Docker Network..."
# Using default network name from script ('wireguard_vpn_net')
sudo "$DOCKER_NET_SCRIPT" --action=disable --network="$DOCKER_NETWORK_NAME"
# Add --subnet and --gateway here if they were non-default during creation


echo "--- WireGuard VPN Termination Finished ---"
echo "Note: If IPTables rules were saved with iptables-persistent, they might be restored on reboot unless persistence is updated/saved again."

