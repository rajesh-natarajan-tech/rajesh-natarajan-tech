#!/bin/bash 
: <<'END'
This Script for the login to tanzu worker node using jumphost container, 
Tanzu Kubernetes envionment secured by NSX-T Network Backend with Isolated T1 Networks, on which we cannot connect worker nodes from external network.
This Scirt Symplifies the troubleshooting login

This Script allowed to execute by DCops team members only 

Author: Rajesh 

END
source /etc/k8s-login.conf
current_user=$(whoami)
empty_line=$(printf "\n")

get_secrets() {



read -p "Enter the PROD AD Password:"  -s  KUBECTL_VSPHERE_PASSWORD


export KUBECTL_VSPHERE_PASSWORD




kubectl vsphere login --server=$SUPERVISOR_CLUSTER --insecure-skip-tls-verify -u $current_user > /dev/null

kubectl config use-context $SUPERVISOR_CLUSTER

echo ${empty_line} 

kubectl get cluster -A --no-headers | awk '{ print $2}' | sort


read -rep "Enter the cluster name:" cluster

vns=$(kubectl get cluster -A |grep -w $cluster |awk '{ print $1}' )

word_count=$(echo $vns | wc -w)


if [ $word_count -gt 1 ]; then

  echo ${empty_line}
  echo "multiple vns matching for the cluster."
  kubectl get cluster -A |grep -w $cluster   
  read -p "Enter the correct vns: "  vns  
fi







#

NAMESPACE=${vns}
PODNAME="${cluster}-jumphost"
SSH_SECRET="${cluster}-ssh"
KUBECFG_SECRET="${cluster}-kubeconfig"

kubectl get pods -n $NAMESPACE  $PODNAME && kubectl delete pod -n $NAMESPACE  $PODNAME

# --- Construct the overrides JSON using a heredoc ---
OVERRIDES_JSON=$(cat <<EOF
{
  "apiVersion": "v1",
  "spec": {
    "containers": [
      {
        "name": "jumpbox",
        "image": "nrajeshdit/jumphost:v01",
        "imagePullPolicy": "IfNotPresent",
        "stdin": true,
        "stdinOnce": true,
        "securityContext": {
           "allowPrivilegeEscalation": false,
           "capabilities": {
               "drop": [
                            "ALL"
               ]
            },
            "runAsNonRoot": true,
            "runAsUser": 1000,
            "seccompProfile": {
                "type": "RuntimeDefault"
            }
           },

        "tty": true,
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
          "secretName": "${SSH_SECRET}"
        }
      },
      {
        "name": "kubeconfig-volume",
        "secret": {
          "secretName": "${KUBECFG_SECRET}"
        }
      }
    ]
  }
}
EOF
)

# --- Run kubectl, passing the generated JSON in double quotes ---
# Note: Use the variables defined above for other flags too
kubectl run -n "${NAMESPACE}" -i --rm --tty "${PODNAME}" \
  --overrides="${OVERRIDES_JSON}" \
  --image=nrajeshdit/jumphost:v01 --restart=Never -- bash




#
}



# Check if the user is part of the 'dcops' group
if id -nG "$current_user" | grep -qw "dcops"; then
  echo "User $current_user is part of the dcops group."

get_secrets
else
  echo "User $current_user is NOT part of the dcops group."
fi

