# Build a Secure Google Cloud Network: Challenge Lab (GSP322)

## Overview

This challenge lab covers:
- Secure firewall configuration
- Identity-Aware Proxy (IAP)
- Bastion host architecture
- Secure SSH access
- Network tags
- Internal-only VM communication

---

# Initial Configuration

## Set project

```bash
gcloud config set project PROJECT_ID
```

## Set region and zone

```bash
gcloud config set compute/region asia-south1
gcloud config set compute/zone asia-south1-b
```

Verify:

```bash
gcloud config list
```

---

# Environment

Instances:
- bastion
- juice-shop

Network:
- acme-vpc

Subnets:
- acme-mgmt-subnet
- acme-app-subnet

---

# Task 1 - Remove Overly Permissive Firewall Rules

## List firewall rules

```bash
gcloud compute firewall-rules list
```

## Delete overly permissive SSH rules

Example:

```bash
gcloud compute firewall-rules delete default-allow-ssh
```

Delete any:
- allow-all
- 0.0.0.0/0 SSH rules
- broad ingress rules

---

# Task 2 - Start Bastion Host

## Start instance

```bash
gcloud compute instances start bastion \
  --zone=asia-south1-b
```

---

# Task 3 - Configure IAP SSH Access

## Remove old tags if present

```bash
gcloud compute instances remove-tags bastion \
  --tags=grant-ssh-iap-ingress-ql-192 \
  --zone=asia-south1-b
```

## Add required bastion tag

```bash
gcloud compute instances add-tags bastion \
  --tags=allow-ssh-iap-ingress-ql-192 \
  --zone=asia-south1-b
```

---

## Create IAP Firewall Rule

```bash
gcloud compute firewall-rules create allow-ssh-iap \
  --network=acme-vpc \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:22 \
  --source-ranges=35.235.240.0/20 \
  --target-tags=allow-ssh-iap-ingress-ql-192
```

---

# Task 4 - Configure HTTP Access for juice-shop

## Add HTTP tag

```bash
gcloud compute instances add-tags juice-shop \
  --tags=allow-http-ingress-ql-192 \
  --zone=asia-south1-b
```

---

## Create HTTP Firewall Rule

```bash
gcloud compute firewall-rules create allow-http \
  --network=acme-vpc \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:80 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=allow-http-ingress-ql-192
```

---

# Task 5 - Configure Internal SSH Access

## Add Internal SSH Tag

```bash
gcloud compute instances add-tags juice-shop \
  --tags=allow-ssh-internal-ingress-ql-192 \
  --zone=asia-south1-b
```

---

## Create Internal SSH Firewall Rule

```bash
gcloud compute firewall-rules create allow-ssh-internal \
  --network=acme-vpc \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:22 \
  --source-ranges=192.168.10.0/24 \
  --target-tags=allow-ssh-internal-ingress-ql-192
```

---

# Verify Bastion Has No External IP

```bash
gcloud compute instances list
```

Expected:
- bastion has NO external IP
- juice-shop has external IP

---

# SSH Validation

## SSH to bastion through IAP

```bash
gcloud compute ssh bastion \
  --zone=asia-south1-b \
  --tunnel-through-iap
```

---

## SSH from bastion to juice-shop

Inside bastion:

```bash
gcloud compute ssh juice-shop \
  --zone=asia-south1-b \
  --internal-ip
```

---

# Verification Commands

## Check instance tags

```bash
gcloud compute instances describe bastion
```

```bash
gcloud compute instances describe juice-shop
```

## Check firewall rules

```bash
gcloud compute firewall-rules list
```

---

# Final Expected State

## Bastion
- No external IP
- SSH allowed only from IAP
- Network tag:
  - allow-ssh-iap-ingress-ql-192

## juice-shop
- HTTP open to world
- SSH allowed only internally
- Network tags:
  - allow-http-ingress-ql-192
  - allow-ssh-internal-ingress-ql-192

## Firewall Rules
- IAP SSH:
  - 35.235.240.0/20 → tcp:22
- HTTP:
  - 0.0.0.0/0 → tcp:80
- Internal SSH:
  - 192.168.10.0/24 → tcp:22
