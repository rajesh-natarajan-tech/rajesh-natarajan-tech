#!/bin/bash 



export KUBECONFIG=/secrets/kubeconfig/value

echo $KUBECONFIG



kubectl get nodes --kubeconfig=/secrets/kubeconfig/value 


