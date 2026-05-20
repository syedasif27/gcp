# Setting up Network load balancer from cloud shell

## Login with student mail id

## Task 1. Set the default region and zone for all resources

```bash
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-f
```

## Task 2. Create multiple web server instances

```bash
  gcloud compute instances create www1 \
    --zone=us-central1-f \
    --tags=network-lb-tag \
    --machine-type=e2-small \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --metadata=startup-script='#!/bin/bash
      apt-get update
      apt-get install apache2 -y
      service apache2 restart
      echo "
<h3>Web Server: www1</h3>" | tee /var/www/html/index.html'

  gcloud compute instances create www2 \
    --zone=us-central1-f \
    --tags=network-lb-tag \
    --machine-type=e2-small \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --metadata=startup-script='#!/bin/bash
      apt-get update
      apt-get install apache2 -y
      service apache2 restart
      echo "
<h3>Web Server: www2</h3>" | tee /var/www/html/index.html'

  gcloud compute instances create www3 \
    --zone=us-central1-f  \
    --tags=network-lb-tag \
    --machine-type=e2-small \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --metadata=startup-script='#!/bin/bash
      apt-get update
      apt-get install apache2 -y
      service apache2 restart
      echo "
<h3>Web Server: www3</h3>" | tee /var/www/html/index.html'
```

#### Create a firewall rule to allow external traffic to the VM instances:

```bash
gcloud compute firewall-rules create www-firewall-network-lb \
    --target-tags network-lb-tag --allow tcp:80
```


#### Run the following to list your instances. You'll see their IP addresses in the EXTERNAL_IP column:

```bash
gcloud compute instances list
```


#### Verify that each instance is running with curl, replacing [IP_ADDRESS] with the external IP address for each of your VMs:

```bash
curl http://[IP_ADDRESS]
```

## Task 3. Configure the load balancing service

#### Create a static external IP address for your load balancer:

```
gcloud compute addresses create network-lb-ip-1 \
  --region us-central1
```

#### Add a legacy HTTP health check resource:

```bash
gcloud compute http-health-checks create basic-check
```


## Task 4. Create the target pool and forwarding rule

#### Run the following to create the target pool and use the health check, which is required for the service to function:

```bash
gcloud compute target-pools create www-pool \
  --region us-central1 --http-health-check basic-check

gcloud compute target-pools add-instances www-pool \
    --instances www1,www2,www3
```

#### Add a forwarding rule:

```bash
gcloud compute forwarding-rules create www-rule \
    --region  us-central1 \
    --ports 80 \
    --address network-lb-ip-1 \
    --target-pool www-pool
```

## Task 5. Send traffic to your instances

#### Enter the following command to view the external IP address of the www-rule forwarding rule used by the load balancer:

```bash
gcloud compute forwarding-rules describe www-rule --region us-central1
```

#### Access the external IP address:

```bash
IPADDRESS=$(gcloud compute forwarding-rules describe www-rule --region us-central1 --format="json" | jq -r .IPAddress)
```

#### Show the external IP address:
```bash
echo $IPADDRESS
```

#### Use the curl command to access the external IP address, replacing IP_ADDRESS with an external IP address from the previous command:

```bash
while true; do curl -m1 $IPADDRESS; done
```
 #### Use Ctrl + C to stop running the command.

