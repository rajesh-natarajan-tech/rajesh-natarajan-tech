#!/bin/bash 
source /etc/k8s-login.conf
current_user=$(whoami)
empty_line=$(printf "\n")


CLUSTER=$1

export CLUSTER
print_usage() {
echo "Usage: tanzu-jumphost.sh <cluster-name>"
echo "Example: tanzu-jumphost.sh sv4-dev-sharedservices"
}


LOGGER(){
    local message="$1"
    LOGGER_COMMAND="logger -p local1.info"
    $LOGGER_COMMAND "($(basename $0)) {$KUBECTL_VSPHERE_USER} $1"

}


get_secrets() {

KUBECTL_VSPHERE_USER="$(whoami | cut -d '@' -f1)@prod.e2open.com"
log_message="Execute: $0 $@"
LOGGER "$log_message"

MY_HOSTNAME=$(hostname -s)
config_file="${HOME}/.k8s-login"
# OpenSSL Version
openssl_version=$(openssl version)
if [[ $openssl_version =~ "1.1.1" ]]; then
    OPENSSL_OPTS="$OPENSSL_OPTS -pbkdf2"
fi

. $config_file

if test ! -e $encryptPW && test -e $PASSCODE; then
    read -p "Passcode: " -s PASSCODE
    echo

    KUBECTL_VSPHERE_PASSWORD=$(echo $encryptPW | openssl aes-256-cbc -d -a -pass pass:$(whoami)$PASSCODE $OPENSSL_OPTS)
    res=$?

    if test $res -ne 0; then
        echo "Invaild Passcode"
        echo
        echo "If you need to reset Passcode, please execute"
        echo
        echo "  $0 --reset"
        echo
        LOGGER "Invaild passcode: DC-ENV=\"${ENVIRONMENT//_/ }\""
        exit 1
    fi

elif test -e $KUBECTL_VSPHERE_PASSWORD; then
    echo "PROD AD Username: $KUBECTL_VSPHERE_USER"
    read -p "PROD AD Password: " -s KUBECTL_VSPHERE_PASSWORD
    echo
fi

export KUBECTL_VSPHERE_PASSWORD

}


pod_creation(){


kubectl vsphere login --server=$SUPERVISOR_CLUSTER --insecure-skip-tls-verify -u $current_user > /dev/null

kubectl config use-context $SUPERVISOR_CLUSTER


while [ -z $CLUSTER ]
do 
kubectl get cluster -A |  awk '{print $2}'
read -p "enter the cluster name:"    CLUSTER 
done

NAMESPACE=`kubectl get cluster -A | grep " $CLUSTER  " | awk '{print $1}'`


printf "jumphost pod getting created for the cluster :  $CLUSTER  and Namespace $NAMESPACE "



#

PODNAME="${CLUSTER}-jumphost-$$"
SSH_SECRET="${CLUSTER}-ssh"
KUBECFG_SECRET="${CLUSTER}-kubeconfig"
#
OVERRIDES_JSON=$(cat <<EOF
{
  "apiVersion": "v1",
  "spec": {
    "containers": [
      {
        "name": "jumpbox",
        "image": "nrajeshdit/jumphost:v02",
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
  --image=nrajeshdit/jumphost:v02 --restart=Never -- bash 


#
}

	if id -nG "$current_user" | grep -qw "dcops"; then
  		echo "User $current_user is part of the dcops group."

		get_secrets
                pod_creation
	else
  		echo "User $current_user is NOT part of the dcops group."
	fi






