#!/bin/bash
kubectl get nodes -o wide |awk '{ print  $1 , $6}'

alias  ssh="ssh -l vmware-system-user -i /secrets/ssh-secret/ssh-privatekey  -o StrictHostKeyChecking=no "

read  -p "enter the IP to login:" ans

while [[ -n $ans ]]; do
ssh $ans
kubectl get nodes -o wide |awk '{ print $1 , $6}'
read  -p "enter the IP to login:" ans

done

