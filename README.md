# argocd with CAPI example on Hetzner
## Bootstrap the CAPI cluster 


- [ ] Remove exports for Hetzner
- [ ] Allow Installation from other providers
- [ ] Make Capi HA installation and scale up replicas



# GCP
# Prepare gcloud
## get project id
gcloud projects list
## enable compute in project
gcloud services enable compute.googleapis.com --project "$GCP_PROJECT_ID"
## Set environemnt 
export GCP_REGION=europe-west3
export GCP_NETWORK_NAME=default
export GCP_PROJECT_ID=capi-371508
export CLUSTER_NAME="test"
export GCP_SA="capi-sa"

# CAPI GCP config

export GCP_CONTROL_PLANE_MACHINE_TYPE=n1-standard-2
export GCP_NODE_MACHINE_TYPE=n1-standard-2


gcloud compute networks list --project="${GCP_PROJECT_ID}"
gcloud compute networks describe "${GCP_NETWORK_NAME}" --project="${GCP_PROJECT_ID}"
gcloud compute firewall-rules list --project "$GCP_PROJECT_ID"
gcloud compute routers create "${CLUSTER_NAME}-myrouter" --project="${GCP_PROJECT_ID}" --region="${GCP_REGION}" --network="default"
gcloud compute routers nats create "${CLUSTER_NAME}-mynat" --project="${GCP_PROJECT_ID}" --router-region="${GCP_REGION}" --router="${CLUSTER_NAME}-myrouter" --nat-all-subnet-ip-ranges --auto-allocate-nat-external-ips

# CAPI SA 
gcloud iam service-accounts create $GCP_SA --description="Service account for capi" --display-name="${GCP_SA}" --project="${GCP_PROJECT_ID}"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member="serviceAccount:${GCP_SA}@${GCP_PROJECT_ID}.iam.gserviceaccount.com" --role="roles/editor"
gcloud iam service-accounts keys create /tmp/${GCP_SA}-key.json --iam-account=${GCP_SA}@${GCP_PROJECT_ID}.iam.gserviceaccount.com

# Controller install
export GCP_B64ENCODED_CREDENTIALS=$( cat /tmp/${GCP_SA}-key.json | base64 | tr -d '\n' )
clusterctl generate provider --infrastructure gcp


# Create Downstream cluster
export GCP_PROJECT="$GCP_PROJECT_ID"
export GCP_CONTROL_PLANE_MACHINE_TYPE=n1-standard-2
export GCP_NODE_MACHINE_TYPE=n1-standard-2
clusterctl generate cluster gcp-test --kubernetes-version 1.25.5 --control-plane-machine-count=1 --worker-machine-count=1 > ./cluster/gcp-test/cluster.yaml

# Build OS image
export GCP_PROJECT_ID=$GCP_PROJECT_ID"

export GOOGLE_APPLICATION_CREDENTIALS=/tmp/${GCP_SA}-key.json

git clone https://github.com/kubernetes-sigs/image-builder.git

cd image-builder/images/capi/
make deps-gce

# Cleanup
gcloud compute routers nats delete "${CLUSTER_NAME}-mynat" --project="${GCP_PROJECT}" \
--router-region="${GCP_REGION}" --router="${CLUSTER_NAME}-myrouter" --quiet || true
gcloud compute routers delete "${CLUSTER_NAME}-myrouter" --project="${GCP_PROJECT}" \
--region="${GCP_REGION}" --quiet || true


# Hetzner
## Create downstream cluster

