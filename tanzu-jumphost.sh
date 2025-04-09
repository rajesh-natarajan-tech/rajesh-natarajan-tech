#!/bin/bash 
: <<'END'
This Script for the login to tanzu worker node using jumphost container, 
Tanzu Kubernetes envionment secured by NSX-T Network Backend with Isolated T1 Networks, on which we cannot connect worker nodes from external network.
This Scirt Symplifies the troubleshooting login

This Script for the DCops team members 

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




echo ${empty_line}
echo $vns 
export ssh_secre=t${cluster}-ssh
export cluster_kubeconfig=${cluster}-kubeconfig



#
OVERRIDES_JSON=$(cat <<EOF
  "apiVersion": "v1",
  "spec": {
    "containers": [
      {
        "name": "jumphost",
        "image": "ghcr.io/rajesh-natarajan-tech/jumphost:v01",
        "args": [
          "bash"
        ],
        "stdin": true,
        "stdinOnce": true,
        "tty": true,
        "volumeMounts": [
          {
            "mountPath": "/secrets/ssh-secret",
            "name": "ssh-secret"
          },
          {
            "mountPath": "/secrets/kubeconig",
            "name": "kubeconig"
          }
        ]
      }
    ],
    "volumes": [
      {
        "name": "ssh-secret",
        "secret": {
          "secretName": "${ssh_secret}"
        }
      },
      {
        "name": "kubeconig",
        "secret": {
          "secretName": "${cluster_kubeconfig}"
        }
      }
    ]
  }
}

EOF
)

kubectl run -n "${vns}" -i --rm --tty "${cluster}-jumpbox" \
  --overrides="${OVERRIDES_JSON}" \
  --image=sv4.art.e2open.com/dcops-docker-repo/jumphost:v01  --restart=Never -- bash




#
}



# Check if the user is part of the 'dcops' group
if id -nG "$current_user" | grep -qw "dcops"; then
  echo "User $current_user is part of the dcops group."

get_secrets
else
  echo "User $current_user is NOT part of the dcops group."
fi

