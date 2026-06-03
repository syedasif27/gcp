# Implement Cloud Security Fundamentals: Challenge Lab (GSP342)

## Overview

This document contains the steps performed to complete the GSP342 Challenge Lab.

Region: europe-west1  
Zone: europe-west1-b

---

# Task 1: Create a Custom IAM Role

Create a YAML definition:

```bash
cat > role.yaml <<EOF
title: orca_storage_editor_871
description: Custom role for managing Cloud Storage objects
stage: GA
includedPermissions:
- storage.buckets.get
- storage.objects.get
- storage.objects.list
- storage.objects.update
- storage.objects.create
EOF
```

Create the custom role:

```bash
gcloud iam roles create orca_storage_editor_871     --project=$(gcloud config get-value project)     --file=role.yaml
```

Verify:

```bash
gcloud iam roles describe orca_storage_editor_871     --project=$(gcloud config get-value project)
```

---

# Task 2: Create a Service Account

Create the service account:

```bash
gcloud iam service-accounts create orca-private-cluster-101-sa     --display-name="Orca Private Cluster Service Account"
```

Verify:

```bash
gcloud iam service-accounts list     --filter="email:orca-private-cluster-101-sa"
```

---

# Task 3: Bind IAM Roles

Set variables:

```bash
PROJECT_ID=$(gcloud config get-value project)

SA_EMAIL="orca-private-cluster-101-sa@${PROJECT_ID}.iam.gserviceaccount.com"
```

Assign Monitoring Viewer:

```bash
gcloud projects add-iam-policy-binding $PROJECT_ID     --member="serviceAccount:${SA_EMAIL}"     --role="roles/monitoring.viewer"
```

Assign Monitoring Metric Writer:

```bash
gcloud projects add-iam-policy-binding $PROJECT_ID     --member="serviceAccount:${SA_EMAIL}"     --role="roles/monitoring.metricWriter"
```

Assign Logging Writer:

```bash
gcloud projects add-iam-policy-binding $PROJECT_ID     --member="serviceAccount:${SA_EMAIL}"     --role="roles/logging.logWriter"
```

Assign Custom Storage Role:

```bash
gcloud projects add-iam-policy-binding $PROJECT_ID     --member="serviceAccount:${SA_EMAIL}"     --role="projects/${PROJECT_ID}/roles/orca_storage_editor_871"
```

Verify:

```bash
gcloud projects get-iam-policy $PROJECT_ID     --flatten="bindings[].members"     --filter="bindings.members:${SA_EMAIL}"     --format="table(bindings.role)"
```

---

# Task 4: Create a Private GKE Cluster

Retrieve the jumphost IP:

```bash
JUMPHOST_IP=$(gcloud compute instances describe orca-jumphost     --zone=europe-west1-b     --format="value(networkInterfaces[0].networkIP)")
```

Create the cluster:

```bash
gcloud container clusters create orca-cluster-728     --zone=europe-west1-b     --network=orca-build-vpc     --subnetwork=orca-build-subnet     --service-account=$SA_EMAIL     --enable-master-authorized-networks     --master-authorized-networks=$JUMPHOST_IP/32     --enable-ip-alias     --enable-private-nodes     --enable-private-endpoint
```

Verify:

```bash
gcloud container clusters describe orca-cluster-728     --zone=europe-west1-b     --format="yaml(privateClusterConfig)"
```

---

# Task 5: Deploy an Application

Connect to the jumphost:

```bash
gcloud compute ssh orca-jumphost --zone=europe-west1-b
```

Install GKE authentication plugin:

```bash
sudo apt-get update

sudo apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin
```

Retrieve cluster credentials using the private endpoint:

```bash
gcloud container clusters get-credentials orca-cluster-728     --zone=europe-west1-b     --internal-ip
```

Verify node access:

```bash
kubectl get nodes
```

Deploy the sample application:

```bash
kubectl create deployment hello-server     --image=gcr.io/google-samples/hello-app:1.0
```

Verify deployment:

```bash
kubectl get deployments
```

Expose the deployment:

```bash
kubectl expose deployment hello-server     --type=LoadBalancer     --port=80     --target-port=8080
```

Verify service:

```bash
kubectl get svc
kubectl get pods
```

---

# Result

Completed all challenge lab tasks:

- Created custom IAM role.
- Created dedicated service account.
- Assigned required IAM permissions.
- Created a private GKE cluster.
- Configured master authorized networks.
- Connected through the jumphost using the private endpoint.
- Deployed and verified the hello-server application.
