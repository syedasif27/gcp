# Google Cloud Network Connectivity Center (NCC) Lab Guide

## Architecture

### Initial Architecture

![NCC
Architecture](images/ncc.png)

> Reference:
> https://cdn.qwiklabs.com/f%2FrYkUz2QOROG4tS2AolpxthW2GglI3KQRCq4QYjKIA%3D

------------------------------------------------------------------------

# Task 1 -- Connect Two On-Prem VPCs

## Create Hub

``` bash
gcloud network-connectivity hubs create globaltech-hub
```

## Create Office 1 Spoke

``` bash
gcloud network-connectivity spokes linked-vpn-tunnels create office-1-spoke \
    --hub=globaltech-hub \
    --region=us-east1 \
    --vpn-tunnels=projects/$(gcloud config get-value project)/regions/us-east1/vpnTunnels/routing-to-onprem-office1-tunnel-0 \
    --vpn-tunnels=projects/$(gcloud config get-value project)/regions/us-east1/vpnTunnels/routing-to-onprem-office1-tunnel-1
```

## Create Office 2 Spoke

``` bash
gcloud network-connectivity spokes linked-vpn-tunnels create office-2-spoke \
    --hub=globaltech-hub \
    --region=us-east1 \
    --vpn-tunnels=projects/$(gcloud config get-value project)/regions/us-east1/vpnTunnels/routing-to-onprem-office2-tunnel-0 \
    --vpn-tunnels=projects/$(gcloud config get-value project)/regions/us-east1/vpnTunnels/routing-to-onprem-office2-tunnel-1
```

## Verify Connectivity

``` bash
gcloud compute ssh onprem-office1-vm --zone us-east1-b
ping -c 4 10.2.0.2
```

Click **Check my progress** before continuing.

------------------------------------------------------------------------

# Task 2 -- Connect VPC to VPC

## Create Workload 1 Spoke

``` bash
gcloud network-connectivity spokes linked-vpc-network create workload-1-spoke \
    --hub=globaltech-hub \
    --global \
    --vpc-network=workload-vpc-1
```

## Create Workload 2 Spoke

``` bash
gcloud network-connectivity spokes linked-vpc-network create workload-2-spoke \
    --hub=globaltech-hub \
    --global \
    --vpc-network=workload-vpc-2
```

## Verify Connectivity

``` bash
gcloud compute ssh workload1-vm --zone us-east1-b
ping -c 4 10.20.0.2
```

Click **Check my progress**.

------------------------------------------------------------------------

# Task 3 -- Connect VPC to On-Prem

Delete the existing spokes after Task 2 is graded.

## Delete Office 1 Spoke

``` bash
gcloud network-connectivity spokes delete office-1-spoke --region=us-east1
```

## Recreate Office 1 Spoke

``` bash
gcloud network-connectivity spokes linked-vpn-tunnels create hybrid-office-1-spoke \
    --hub=globaltech-hub \
    --region=us-east1 \
    --vpn-tunnels=projects/$(gcloud config get-value project)/regions/us-east1/vpnTunnels/routing-to-onprem-office1-tunnel-0 \
    --vpn-tunnels=projects/$(gcloud config get-value project)/regions/us-east1/vpnTunnels/routing-to-onprem-office1-tunnel-1
```

## Delete Workload 1 Spoke

``` bash
gcloud network-connectivity spokes delete workload-1-spoke --global
```

## Recreate Workload 1 Spoke

``` bash
gcloud network-connectivity spokes linked-vpc-network create hybrid-workload-1-spoke \
    --hub=globaltech-hub \
    --global \
    --vpc-network=workload-vpc-1
```

## Verify Connectivity

``` bash
gcloud compute ssh workload1-vm --zone us-east1-b
ping -c 4 10.1.0.2
```

Click **Check my progress**.

------------------------------------------------------------------------

# Useful Commands

``` bash
gcloud network-connectivity hubs list
gcloud network-connectivity spokes list
gcloud compute vpn-tunnels list
gcloud compute instances list
```
