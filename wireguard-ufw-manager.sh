#!/bin/bash

### --- Parse arguments --- ###
ACTION=""
PORT_LIST=""

for arg in "$@"; do
    case $arg in
        --action=*) ACTION="${arg#*=}"; shift ;;
        --ports=*) PORT_LIST="${arg#*=}"; shift ;;
        *) echo "Unknown parameter: $arg"; exit 1 ;;
    esac
done


### --- Validate action --- ###
if [[ -z "$ACTION" ]]; then
    echo "Missing --action parameter (must be 'enable' or 'disable')"
    exit 1
fi
if [[ "$ACTION" != "enable" && "$ACTION" != "disable" ]]; then
    echo "Invalid action: $ACTION (must be 'enable' or 'disable')"
    exit 1
fi


### --- Default port list --- ###
: "${PORT_LIST:=51820/udp}" ### Default to WireGuard port


### --- Validate port list --- ###
if [[ -z "$PORT_LIST" ]]; then
    echo "Missing --ports parameter (e.g. --ports=500/udp,4500/udp)"
    exit 1
fi


### --- Convert comma-separated list to array --- ###
IFS=',' read -ra PORTS <<< "$PORT_LIST"


### --- Function to check if UFW rule exists based on 'ufw status' output --- ###
rule_exists() {
    local port_spec="$1"
    # Grep for lines starting with optional space, the port_spec,
    # potentially followed by (v6), then whitespace, then ALLOW
    ufw status | grep -qE "^\s*${port_spec}(\s+|\s+\(v6\))\s+ALLOW"
}


### --- Apply rules --- ###
echo "${ACTION^}ing UFW rules for port(s): $PORT_LIST..." # Capitalize first letter of action

for PORT_SPEC in "${PORTS[@]}"; do
    echo " Processing rule for $PORT_SPEC..."
    if [[ "$ACTION" == "enable" ]]; then
        # Check if rule already exists
        if ! rule_exists "$PORT_SPEC"; then
            # Add rule with comment
            ufw allow "$PORT_SPEC" comment "VPN rule for $PORT_SPEC"
            echo " + Added UFW rule for $PORT_SPEC"
        else
            echo " = UFW rule for $PORT_SPEC already seems to exist."
        fi
    elif [[ "$ACTION" == "disable" ]]; then
        # Check if rule exists before trying to delete
        if rule_exists "$PORT_SPEC"; then
            # Attempt deletion (ufw delete usually handles v4/v6 pairs)
            ufw delete allow "$PORT_SPEC"
            echo " - Attempted deletion of UFW rule for $PORT_SPEC"
            # Optional: Re-check if deletion was successful
            # sleep 1
            # if ! rule_exists "$PORT_SPEC"; then echo "   Deletion confirmed."; else echo "   WARN: Rule might still exist."; fi
        else
            echo " = UFW rule for $PORT_SPEC does not seem to exist."
        fi
    fi
done


### --- Show current UFW status --- ###
echo
echo "Current UFW status:"
ufw status verbose ### Or 'numbered', whichever you prefer


