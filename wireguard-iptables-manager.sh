#!/bin/bash

### --- Parse arguments --- ###
ACTION=""
HOST_INTERFACE=""
WG_SUBNET=""

for arg in "$@"; do
    case $arg in
        --action=*) ACTION="${arg#*=}"; shift ;;
        --interface=*) HOST_INTERFACE="${arg#*=}"; shift ;;
        --wg-subnet=*) WG_SUBNET="${arg#*=}"; shift ;;
        *) echo "Unknown parameter: $arg"; exit 1 ;;
    esac
done


### --- Default values --- ###
: "${HOST_INTERFACE:=}"
: "${WG_SUBNET:=10.13.13.0/24}"


### --- Auto-detect default interface if not provided --- ###
if [[ -z "$HOST_INTERFACE" ]]; then
    echo "   Attempting to auto-detect default interface..."
    DETECTED_IFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)
    if [[ -n "$DETECTED_IFACE" ]]; then
        HOST_INTERFACE="$DETECTED_IFACE"
        echo "   Auto-detected default interface: $HOST_INTERFACE"
    else
        echo "   ERROR: Could not auto-detect default interface. Please specify using --interface."
        exit 1
    fi
fi


### --- Validate action --- ###
if [[ -z "$ACTION" ]]; then
    echo "Missing --action parameter (must be 'enable' or 'disable')"
    exit 1
fi
if [[ "$ACTION" != "enable" && "$ACTION" != "disable" ]]; then
    echo "Invalid action: $ACTION (must be 'enable' or 'disable')"
    exit 1
fi

### --- Define Rule Specifications (Rule parameters only) --- ###
NAT_RULE_SPEC=(-s "$WG_SUBNET" -o "$HOST_INTERFACE" -j MASQUERADE)
FWD1_RULE_SPEC=(-s "$WG_SUBNET" -o "$HOST_INTERFACE" -j ACCEPT)
FWD2_RULE_SPEC=(-i "$HOST_INTERFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT)


### --- Perform action --- ###
if [[ "$ACTION" == "enable" ]]; then
    echo "Enabling WireGuard IPTables rules for $WG_SUBNET via $HOST_INTERFACE..."

    # Check and Add NAT rule
    if ! iptables -t nat -C POSTROUTING "${NAT_RULE_SPEC[@]}" > /dev/null 2>&1; then
         iptables -t nat -A POSTROUTING "${NAT_RULE_SPEC[@]}"
         echo " + Added NAT rule."
    else
         echo " = NAT rule already exists."
    fi

    # Check and Add FORWARD rule 1 (Allow WG Out)
    if ! iptables -C FORWARD "${FWD1_RULE_SPEC[@]}" > /dev/null 2>&1; then
         iptables -A FORWARD "${FWD1_RULE_SPEC[@]}"
         echo " + Added FORWARD rule 1 (WG Out)."
    else
         echo " = FORWARD rule 1 (WG Out) already exists."
    fi

    # Check and Add FORWARD rule 2 (Allow Established In)
    if ! iptables -C FORWARD "${FWD2_RULE_SPEC[@]}" > /dev/null 2>&1; then
         iptables -A FORWARD "${FWD2_RULE_SPEC[@]}"
         echo " + Added FORWARD rule 2 (Established In)."
    else
         echo " = FORWARD rule 2 (Established In) already exists."
    fi

    # Enable IP forwarding (if not already enabled)
    if [[ $(cat /proc/sys/net/ipv4/ip_forward) == "0" ]]; then
        echo "   Enabling IP forwarding (net.ipv4.ip_forward=1)..."
        sysctl -w net.ipv4.ip_forward=1 > /dev/null
    else
        echo " = IP forwarding already enabled."
    fi

elif [[ "$ACTION" == "disable" ]]; then
    echo "Disabling WireGuard IPTables rules for $WG_SUBNET via $HOST_INTERFACE..."

    # Check and Delete NAT rule
    if iptables -t nat -C POSTROUTING "${NAT_RULE_SPEC[@]}" > /dev/null 2>&1; then
         iptables -t nat -D POSTROUTING "${NAT_RULE_SPEC[@]}"
         echo " - Removed NAT rule."
    else
         echo " = NAT rule does not exist."
    fi

    # Check and Delete FORWARD rule 1 (Allow WG Out)
    if iptables -C FORWARD "${FWD1_RULE_SPEC[@]}" > /dev/null 2>&1; then
         iptables -D FORWARD "${FWD1_RULE_SPEC[@]}"
         echo " - Removed FORWARD rule 1 (WG Out)."
    else
         echo " = FORWARD rule 1 (WG Out) does not exist."
    fi

    # Check and Delete FORWARD rule 2 (Allow Established In)
    if iptables -C FORWARD "${FWD2_RULE_SPEC[@]}" > /dev/null 2>&1; then
         iptables -D FORWARD "${FWD2_RULE_SPEC[@]}"
         echo " - Removed FORWARD rule 2 (Established In)."
    else
         echo " = FORWARD rule 2 (Established In) does not exist."
    fi

    # Note: We intentionally do not disable net.ipv4.ip_forward here,
    # as other services might depend on it. Leaving it enabled is usually safe.
fi

echo "Operation finished."
