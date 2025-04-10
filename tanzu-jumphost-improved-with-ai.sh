#!/bin/bash

# Strict mode: exit on error, exit on unset variable, fail pipe chains
set -euo pipefail

: <<'END'
This script simplifies logging into a Tanzu worker node jumphost container.
Environment: Tanzu Kubernetes with NSX-T backend, where worker nodes
             are not directly accessible from external networks.
Purpose: Provides a temporary, interactive jumphost pod within the
         target cluster's namespace for troubleshooting.

Authorization: Allowed for members of the 'dcops' group only.

Configuration: Reads Supervisor Cluster details from /etc/k8s-login.conf
               Expects SUPERVISOR_CLUSTER variable to be defined there.

Author: Rajesh
Improvements: Added error handling, efficiency, robustness, clarity.
END

# --- Configuration & Setup ---

CONFIG_FILE="/etc/k8s-login.conf"
REQUIRED_GROUP="dcops"
JUMPHOST_IMAGE="nrajeshdit/jumphost:v02" # Define image centrally

# Check if config file exists and source it
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Configuration file '$CONFIG_FILE' not found." >&2
  exit 1
fi
# Use 'source' or '.' - source is generally preferred for readability
source "$CONFIG_FILE"

# Check if SUPERVISOR_CLUSTER is set
if [[ -z "${SUPERVISOR_CLUSTER:-}" ]]; then
    echo "Error: SUPERVISOR_CLUSTER variable not set in '$CONFIG_FILE'." >&2
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl command not found. Please ensure it's installed and in your PATH." >&2
    exit 1
fi

current_user=$(whoami)
echo "Running as user: $current_user"

# --- Authorization Check ---

echo "Checking group membership..."
if ! id -nG "$current_user" | grep -qw "$REQUIRED_GROUP"; then
  echo "Error: User '$current_user' is NOT part of the required '$REQUIRED_GROUP' group." >&2
  echo "Permission denied." >&2
  exit 1
else
  echo "User '$current_user' is authorized (member of '$REQUIRED_GROUP')."
fi

# --- Main Function ---

run_jumphost_session() {
    local cluster_name target_namespace pod_name ssh_secret_name kubeconfig_secret_name overrides_json cluster_list matching_clusters num_matches

    # 1. Get vSphere Password securely
    # Use read builtin for prompt and sensitive input
    read -rsp "Enter the PROD AD Password for user '$current_user':" KUBECTL_VSPHERE_PASSWORD
    printf "\n" # Add a newline after password input for cleaner output
    export KUBECTL_VSPHERE_PASSWORD

    # Ensure the password variable is unset upon exiting the function or script
    # Use trap to ensure cleanup even if errors occur
    trap 'unset KUBECTL_VSPHERE_PASSWORD' RETURN EXIT

    # 2. Login to vSphere Supervisor Cluster
    echo "Logging into vSphere Supervisor Cluster '$SUPERVISOR_CLUSTER'..."
    if ! kubectl vsphere login --server="$SUPERVISOR_CLUSTER" --insecure-skip-tls-verify -u "$current_user" &> /dev/null; then
        echo "Error: kubectl vsphere login failed. Check credentials or server reachability." >&2
        # Don't explicitly unset password here, trap will handle it
        exit 1
    fi
    echo "Login successful."

    # 3. Set kubectl context
    echo "Setting kubectl context to '$SUPERVISOR_CLUSTER'..."
    if ! kubectl config use-context "$SUPERVISOR_CLUSTER"; then
        echo "Error: Failed to set kubectl context to '$SUPERVISOR_CLUSTER'." >&2
        exit 1
    fi

    printf "\n"
    echo "Fetching available Tanzu Kubernetes Clusters..."

    # 4. Get Cluster List (more robustly)
    # Use custom-columns for reliable output, fetch once
    if ! cluster_list=$(kubectl get cluster -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers); then
         echo "Error: Failed to retrieve cluster list." >&2
         exit 1
    fi

    if [[ -z "$cluster_list" ]]; then
        echo "Error: No Tanzu Kubernetes clusters found in supervisor cluster '$SUPERVISOR_CLUSTER'." >&2
        exit 1
    fi

    echo "Available clusters (NAMESPACE NAME):"
    echo "$cluster_list" | sort -k2 # Sort by name for better readability
    printf "\n"

    # 5. Select Cluster and Determine Namespace
    while true; do
        read -rp "Enter the target cluster name: " cluster_name

        if [[ -z "$cluster_name" ]]; then
            echo "Cluster name cannot be empty. Please try again."
            continue
        fi

        # Filter the list for the entered name (match whole word at the end of line)
        # Use grep -E 'pattern$' to match the end more reliably if needed, -w often sufficient
        matching_clusters=$(echo "$cluster_list" | grep -w -- "$cluster_name")
        num_matches=$(echo "$matching_clusters" | wc -l)

        if [[ "$num_matches" -eq 0 ]]; then
            echo "Error: Cluster '$cluster_name' not found. Please check the name and try again."
            # Optionally loop back or exit: continue / exit 1
            continue
        elif [[ "$num_matches" -eq 1 ]]; then
            # Exactly one match found, extract namespace
            target_namespace=$(echo "$matching_clusters" | awk '{print $1}')
            echo "Found cluster '$cluster_name' in namespace '$target_namespace'."
            break # Exit the loop
        else
            # Multiple matches found
            echo "Error: Multiple clusters found matching '$cluster_name':"
            echo "$matching_clusters"
            read -rp "Please enter the exact NAMESPACE for the desired cluster: " target_namespace
            # Verify the selected namespace is in the list of matches
            if echo "$matching_clusters" | awk '{print $1}' | grep -qxw -- "$target_namespace"; then
                 echo "Using cluster '$cluster_name' in selected namespace '$target_namespace'."
                 break # Exit the loop
            else
                 echo "Error: Invalid namespace '$target_namespace' entered for cluster '$cluster_name'. Please try again."
                 # Optionally loop back or exit: continue / exit 1
                 continue
            fi
        fi
    done

    # 6. Define Pod and Secret Names
    pod_name="${cluster_name}-jumphost-$$" # Add PID for slight uniqueness if run concurrently by same user
    ssh_secret_name="${cluster_name}-ssh"
    kubeconfig_secret_name="${cluster_name}-kubeconfig"

    echo "Preparing jumphost pod '$pod_name' in namespace '$target_namespace'..."



    # 7. Construct the Pod Overrides JSON
    # Using a variable makes it slightly cleaner than direct cat redirection
    # Ensure variable expansions inside are safe (no user input directly forming JSON structure)
    overrides_json=$(cat <<EOF
{
  "apiVersion": "v1",
  "spec": {
    "securityContext": {
        "runAsNonRoot": true,
        "runAsUser": 1000,
        "seccompProfile": {
            "type": "RuntimeDefault"
        }
    },
    "containers": [
      {
        "name": "jumpbox",
        "image": "${JUMPHOST_IMAGE}",
        "imagePullPolicy": "IfNotPresent",
        "stdin": true,
        "stdinOnce": true,
        "tty": true,
        "securityContext": {
           "allowPrivilegeEscalation": false,
           "capabilities": {
               "drop": ["ALL"]
            }
        },
        "volumeMounts": [
          {
            "mountPath": "/secrets/ssh-secret",
            "name": "ssh-secret-volume",
            "readOnly": true
          },
          {
            "mountPath": "/secrets/kubeconfig",
            "name": "kubeconfig-volume",
            "readOnly": true
          }
        ]
      }
    ],
    "volumes": [
      {
        "name": "ssh-secret-volume",
        "secret": {
          "secretName": "${ssh_secret_name}"
        }
      },
      {
        "name": "kubeconfig-volume",
        "secret": {
          "secretName": "${kubeconfig_secret_name}"
        }
      }
    ]
  }
}
EOF
)
    # Could add a label here for easier cleanup later:
    # "metadata": { "labels": { "app": "${cluster_name}-jumphost" } },

    # 9. Run the ephemeral jumphost pod
    echo "Launching interactive jumphost pod '$pod_name'..."
    echo "Image: ${JUMPHOST_IMAGE}"
    echo "Namespace: ${target_namespace}"
    echo "Secrets mounted: ssh='${ssh_secret_name}', kubeconfig='${kubeconfig_secret_name}'"
    echo "Please wait for the POD startup ... , Type 'exit' or press Ctrl+D to terminate the pod session."
    printf "\n"

    # Use --rm to automatically delete the pod on exit
    # Use -i for stdin, -t for tty
    if ! kubectl run -n "${target_namespace}" -i --rm --tty "${pod_name}" \
      --overrides="${overrides_json}" \
      --image="${JUMPHOST_IMAGE}" \
      --restart=Never -- \
      bash; then # Specify 'bash' as the command after '--'
        echo "Error: Failed to start or attach to the jumphost pod '$pod_name'." >&2
        echo "Check pod logs in namespace '$target_namespace' if it was created but failed to run." >&2
        # Pod might be left running if attach failed but creation succeeded without --rm (though --rm should handle most cases)
        # Consider adding cleanup here too: kubectl delete pod -n "${target_namespace}" "${pod_name}" --ignore-not-found=true
        exit 1
    fi

    echo "Jumphost pod session for '$pod_name' ended."
}

# --- Script Execution ---

run_jumphost_session

echo "Script finished."
exit 0


