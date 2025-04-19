#!/bin/bash

# Read Cluster IP  & Password
source /etc/k8s-login.conf
current_user=$(whoami)
empty_line=$(printf "\n")



print_usage() {
echo "Usage: all-tkc.sh  <kubectl get resource >"
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

get_secrets
kubectl vsphere login --server=$SUPERVISOR_CLUSTER --insecure-skip-tls-verify -u $current_user > /dev/null

kubectl config use-context $SUPERVISOR_CLUSTER


kubectl  get cluster -A|egrep -v "NAME|sv4-dr" |awk '{ print $1" " $2}'|while read line;
 do
VNS=$( echo $line |awk '{print $1}');
TKC=$( echo $line |awk '{print $2}')
printf "executing ${TKC}"
kubectl vsphere login --server=$SUPERVISOR_CLUSTER --insecure-skip-tls-verify  --tanzu-kubernetes-cluster-namespace=${VNS} --tanzu-kubernetes-cluster-name=${TKC} -u  $current_user > /dev/null

kubectl config use-context ${TKC}

echo $TKC

$@


echo "-----"


done

