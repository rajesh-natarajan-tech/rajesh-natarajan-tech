# --- Define your shell variables ---
kubectl delete pod -n e2dev-tanzu-dcops sv4-dev-dcops-jumphost

NAMESPACE="e2dev-tanzu-dcops"
PODNAME="sv4-dev-dcops-jumphost"
SSH_SECRET="sv4-dev-dcops-ssh"
KUBECFG_SECRET="sv4-dev-dcops-kubeconfig"

# --- Construct the overrides JSON using a heredoc ---
OVERRIDES_JSON=$(cat <<EOF
{
  "apiVersion": "v1",
  "spec": {
    "imagePullSecrets": [
      {
        "name": "regcred"
      }
    ],
    "containers": [
      {
        "name": "jumpbox",
        "image": "sv4.art.e2open.com/dcops-docker-repo/jumphost:v01",
        "stdin": true,
        "stdinOnce": true,
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
          "secretName": "${SSH_SECRET}",
          "defaultMode": 256
        }
      },
      {
        "name": "kubeconfig-volume",
        "secret": {
          "secretName": "${KUBECFG_SECRET}",
          "defaultMode": 256
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
  --image=sv4.art.e2open.com/dcops-docker-repo/jumphost:v01 --restart=Never -- bash
