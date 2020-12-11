#!/bin/bash
set -e

terraform init
terraform apply -auto-approve

export NODE_1=`terraform output -json instance_public_ip_addresses | jq '.[]' | awk 'NR==1'| tr -d '"'`
export NODE_2=`terraform output -json instance_public_ip_addresses | jq '.[]' | awk 'NR==2'| tr -d '"'`
export NODE_3=`terraform output -json instance_public_ip_addresses | jq '.[]' | awk 'NR==3'| tr -d '"'`

export USER=ec2-user

echo "Node1 : $NODE_1 "
echo "Node2 : $NODE_2 "
echo "Node3 : $NODE_3 "

# The first server starts the cluster
k3sup install  --cluster --user $USER --ssh-key .sshkeys/clusterkeys --k3s-channel stable  --ip $NODE_1

if [[ $1 == 'cluster' ]]; then
 for i in {1..10}
  do 
  sleep $i
  echo "Waiting..."
  done

 # The second node joins

 k3sup join --ip $NODE_2  --server-ip $NODE_1 --user $USER  --ssh-key .sshkeys/clusterkeys
 #kubectl label node worker1 node-role.kubernetes.io/worker=worker

 # The third node joins

 k3sup join --ip $NODE_3  --server-ip $NODE_1  --user $USER  --ssh-key .sshkeys/clusterkeys
 #kubectl label node worker2 node-role.kubernetes.io/worker=worker
fi

export KUBECONFIG=$(pwd)/kubeconfig
