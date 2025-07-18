#!/bin/bash


if [ $(tanzu package installed list -n kube-infra |wc -l) > 2 ]
then  
tanzu package installed delete  -n kube-infra cert-manager --yes &
tanzu package installed delete  -n kube-infra contour --yes &


kubectl patch app  -n kube-infra cert-manager \
  --type='json' \
  -p='[{"op": "remove", "path": "/metadata/finalizers"}]'

kubectl patch app  -n kube-infra contour \
  --type='json' \
  -p='[{"op": "remove", "path": "/metadata/finalizers"}]'

kubectl get app -n kube-infra
tanzu package installed list -n kube-infra
fi 

kubectl  get app -n tkg-system  cert-manager |grep Error > /dev/null 
if [ $? == 0 ] 
then 

printf "Cert Manager Not running ..fixing Cert-Manager"
kubectl get  app -n tkg-system  cert-manager -o yaml |grep ' Resource' |grep cluster  |awk -F "'" '{ print $2}' |awk '{print $1}' > fix-cert-manager
kubectl  get  app -n tkg-system  cert-manager -o yaml |grep ' Resource' |grep -v cluster  |awk -F "'" '{ print $2}' |awk '{print $1 , "-n "  $4}'  >> fix-cert-manager

while read -r line; 
do  
kubectl label  ${line}  "kapp.k14s.io/association"-; 
kubectl label ${line}  "kapp.k14s.io/app"-
done < fix-cert-manager
kubectl delete cm -n cert-manager cert-manager-ver-1


fi
kubectl  get app -n tkg-system  contour |grep Error > /dev/null
if [ $? == 0 ]
then


printf  "Contour Not running ..Fixing Contour"
kubectl get  app -n tkg-system  contour  -o yaml |grep ' Resource' |grep cluster  |awk -F "'" '{ print $2}' |awk '{print $1}' > fix-contour
kubectl  get  app -n tkg-system  contour  -o yaml |grep ' Resource' |grep -v cluster  |awk -F "'" '{ print $2}' |awk '{print $1 , "-n "  $4}'  >> fix-contour

while read -r line;
do
kubectl label  ${line}  "kapp.k14s.io/association"-;
kubectl label ${line}  "kapp.k14s.io/app"-
done < fix-contour
kubectl delete daemonset.apps/envoy -n tanzu-system-ingress 
kubectl delete deployments.apps -n tanzu-system-ingress contour
fi

