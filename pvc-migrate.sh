#!/bin/bash 
 
cluster=`kubectl config current-context`
mkdir $cluster
kubectl get ns |egrep -v "tanzu|vmware-system-cloud-provider|trivy-system|vmware-system-tmc|k8smonitor|vmware-system-csi|monitor-zabbix|trident|monitor-logging|falco|external-secrets|tanzu-system-ingress|velero|vmware-system-auth|ingress-nginx|cert-manager|tanzu-system|vmware-system-cloud-provider|trivy-system|cloudhealth|kube-system|NAMESPACE"

read -p "enter the migration namespace: " ns 

pvcs=`kubectl get pvc -n $ns |grep -iv name |awk '{ print $1}'`

for pvc in $pvcs 
do 
kubectl get pvc -n $ns $pvc -o yaml | kubectl neat |egrep -v "pv.kubernetes.io|volumeName:" > ${cluster}/$pvc.yaml 
pvname=`kubectl get pvc -n $ns $pvc -o json |jq  .spec.volumeName|sed -e 's/^"//' -e 's/"$//'`
volume=`kubectl get pv ${pvname} -o json |jq .spec.csi.volumeAttributes.internalName `
printf  "tridentctl import volume ontap-nas ${volume} -f ${pvc}.yaml -n trident \n" >> ${cluster}/${cluster}-migrate.sh 
printf " -  \"$volume\" " >> ${cluster}/${cluster}vars.yaml 

done 

echo "pvc yamls files are prepared, login to destination cluster and run the script `cat  ${cluster}/${cluster}-migrate.sh `"








