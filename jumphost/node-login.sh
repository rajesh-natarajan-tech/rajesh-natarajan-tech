#!/bin/bash

# Strict mode: exit on error, unset variables, and fail on pipe errors
set -euo pipefail

# Function to display the list of nodes with their IPs
list_nodes() {
    echo "Fetching node details..."
    kubectl get nodes -o wide | awk 'NR==1 {print $1, $6} NR>1 {print $1, $6}' # Include headers for clarity
}

# Function to handle SSH login
ssh_to_node() {
    local ip="$1"
    echo "Attempting to SSH into node with IP: $ip"
    ssh -l vmware-system-user \
        -i /secrets/ssh-secret/ssh-privatekey \
        -o StrictHostKeyChecking=no \
        "$ip" || echo "Error: Unable to connect to $ip. Please check the IP or your credentials."
}

# Main script logic
while true; do
    list_nodes
    read -p "Enter the IP to login (or press Enter to exit): " ans

    if [[ -z "$ans" ]]; then
        echo "Exiting script. Goodbye!"
        break
    fi

    ssh_to_node "$ans"
done
