#!/bin/bash

createCluster() {
    kind create cluster --name bootstrap-cluster --image kindest/node:v1.25.0
    if [ $? -eq 0 ]
    then
        echo "Cluster created"
    else
        echo "Error at creation of Bootstrap cluster"
        exit 1
    fi
}

createCluster
kind get kubeconfig --name bootstrap-cluster > /tmp/bootstrap-kubeconfig.yaml
export KUBECONFIG=/tmp/bootstrap-kubeconfig.yaml
clusterctl init --infrastructure hetzner
echo $?
if [ $? -eq 0 ]
then
    echo "ClusterAPI is initialized"
else
    echo "Error at initialization of ClusterAPI failed"
    exit 1
fi

# Add Check if ever pod is running
sleep 120
#



# Export defaults for capi-mgm cluster
export HCLOUD_SSH_KEY="mover@mbmover" 
export HCLOUD_REGION="nbg1" 
export HCLOUD_CONTROL_PLANE_MACHINE_TYPE=cx21 
export HCLOUD_WORKER_MACHINE_TYPE=cx21
export HCLOUD_TOKEN=""


# Create capi-mgm cluster
kubectl create secret generic hetzner --from-literal=hcloud=$HCLOUD_TOKEN
kubectl patch secret hetzner -p '{"metadata":{"labels":{"clusterctl.cluster.x-k8s.io/move":""}}}'
kubectl apply -f ./cluster/capi-mgm
# Add check if Downstreamcluster is online
sleep 420
#

export CAPH_WORKER_CLUSTER_KUBECONFIG=/tmp/workload-kubeconfig 
clusterctl get kubeconfig capi-mgm > $CAPH_WORKER_CLUSTER_KUBECONFIG

# Install needed tools in cluster
KUBECONFIG=$CAPH_WORKER_CLUSTER_KUBECONFIG helm install cilium ./apps/cilium/chart -f ./apps/cilium/overlays/capi-mgm/values.yaml -n kube-system
sleep 30
KUBECONFIG=$CAPH_WORKER_CLUSTER_KUBECONFIG kubectl apply -k ./apps/ccm-hcloud/overlays/capi-mgm
sleep 30
export KUBECONFIG=$CAPH_WORKER_CLUSTER_KUBECONFIG
kubectl get nodes
clusterctl init --infrastructure hetzner
export KUBECONFIG=/tmp/bootstrap-kubeconfig.yaml
clusterctl move --to-kubeconfig $CAPH_WORKER_CLUSTER_KUBECONFIG
if [ $? -eq 0 ]
then
    echo "ClusterAPI is Installed on remote cluster"
else
    echo "Error at moving of ClusterAPI to remote cluster"
    exit 1
fi
export KUBECONFIG=$CAPH_WORKER_CLUSTER_KUBECONFIG
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Init argocd
kubectl apply -f init-argo.yaml
