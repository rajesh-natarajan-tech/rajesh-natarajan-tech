kubectl run -n e2dev-tanzu-dcops -i --rm --tty ubuntu --overrides='{
  "apiVersion": "v1",
  "spec": {
     "imagePullSecrets": [
       {
        "name": "regcred"
       }
    ],
    "containers": [
      {
        "name": "ubuntu",
        "image": "ubuntu",
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
          "secretName": "sv4-dev-dcops-ssh"
        }
      },
      {
        "name": "kubeconig",
        "secret": {
          "secretName": "sv4-dev-dcops-kubeconfig"
        }
      }
    ]
  }
}
'  --image=ubuntu --restart=Never -- bash
