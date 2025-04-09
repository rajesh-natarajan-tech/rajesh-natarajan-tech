#!/bin/bash 



export KUBECONFIG=/secrets/kubeconig/value

echo $KUBECONFIG
kubectl config view --merge --flatten > ~/.kube/config

echo "successfully generated kube contexts" 




kubectl config get-contexts 


