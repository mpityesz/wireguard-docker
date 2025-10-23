#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e


### --- Configuration --- ###
# Optional: Define script paths if not in the same directory
UFW_SCRIPT="./wireguard-ufw-manager.sh"
DOCKER_NET_SCRIPT="./wireguard-docker-network.sh"
IPTABLES_SCRIPT="./wireguard-iptables-manager.sh"
COMPOSE_FILE="wireguard-vpn-compose.yml" # Optional: Add -f flag later if needed


# Optional: Define parameters if defaults are not desired
UFW_PORTS="51820/udp"
DOCKER_NETWORK_NAME="wireguard_vpn_net"
#DOCKER_SUBNET="172.35.0.0/24" # Using default from script
#DOCKER_GATEWAY="172.35.0.1"   # Using default from script
#WG_SUBNET="10.13.13.0/24"     # Using default from script
#HOST_INTERFACE="enp1s0"       # Using auto-detect from script


echo "--- Starting WireGuard VPN Setup ---"


### --- 1. Configure UFW --- ###
echo "Configuring UFW..."
sudo "$UFW_SCRIPT" --action=enable --ports="$UFW_PORTS"
# Note: This script doesn't handle the FORWARD policy in /etc/default/ufw
# Ensure DEFAULT_FORWARD_POLICY="DROP" if using specific IPTables FORWARD rules,
# OR set DEFAULT_FORWARD_POLICY="ACCEPT" manually for simpler forwarding setup.
# Assuming specific IPTables rules will be used based on wireguard-iptables-manager.sh


### --- 2. Configure Docker Network --- ###
echo "Configuring Docker Network..."
# Using default network name from script ('wireguard_vpn_net')
sudo "$DOCKER_NET_SCRIPT" --action=enable --network="$DOCKER_NETWORK_NAME"
# Add --subnet and --gateway here if not using script defaults


### --- 3. Configure IPTables --- ###
echo "Configuring IPTables..."
# Using default WG subnet from script ('10.13.13.0/24')
# Using auto-detected interface from script
WG_FLAGS=()
if [[ -n "$WG_SUBNET" ]]; then
  WG_FLAGS+=(--wg-subnet="$WG_SUBNET")
fi
sudo "$IPTABLES_SCRIPT" --action=enable "${WG_FLAGS[@]}"
# Add --interface here if auto-detect is not desired/reliable


### --- 4. Start Docker Container --- ###
echo "Starting WireGuard container..."
# Use -f if compose file is not named docker-compose.yml or is elsewhere
docker-compose -f "$COMPOSE_FILE" up -d


echo "--- WireGuard VPN Setup Finished ---"
echo "Note: IPTables rules are currently live but may not persist after reboot unless saved (e.g., with iptables-persistent)."
