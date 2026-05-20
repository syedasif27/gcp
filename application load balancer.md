#  Set Up Application Load Balancers 

## Task 1. Set the default region and zone for all resources

```bash
gcloud config set compute/region us-west1

gcloud config set compute/zone us-west1-b
```

## Task 2. Create multiple web server instances

#### Create a virtual machine, www, in your default zone using the following code:

```bash
  gcloud compute instances create www1 \
    --zone=us-west1-b \
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
    --zone=us-west1-b \
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
    --zone=us-west1-b  \
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

## Task 3. Create an Application Load Balancer

#### First, create the load balancer template:

```bash
gcloud compute instance-templates create lb-backend-template \
   --region=us-west1 \
   --network=default \
   --subnet=default \
   --tags=allow-health-check \
   --machine-type=e2-medium \
   --image-family=debian-11 \
   --image-project=debian-cloud \
   --metadata=startup-script='#!/bin/bash
     apt-get update
     apt-get install apache2 -y
     a2ensite default-ssl
     a2enmod ssl
     vm_hostname="$(curl -H "Metadata-Flavor:Google" \
     http://169.254.169.254/computeMetadata/v1/instance/name)"
     echo "Page served from: $vm_hostname" | \
     tee /var/www/html/index.html
     systemctl restart apache2'
```

#### Create a managed instance group based on the template:

```bash
gcloud compute instance-groups managed create lb-backend-group \
   --template=lb-backend-template --size=2 --zone=us-west1-b
```

#### Create the fw-allow-health-check firewall rule.

```bash
gcloud compute firewall-rules create fw-allow-health-check \
  --network=default \
  --action=allow \
  --direction=ingress \
  --source-ranges=130.211.0.0/22,35.191.0.0/16 \
  --target-tags=allow-health-check \
  --rules=tcp:80
```

#### Now that the instances are up and running, set up a global static external IP address that your customers use to reach your load balancer:

```bash
gcloud compute addresses create lb-ipv4-1 \
  --ip-version=IPV4 \
  --global
```

#### Notice that the IPv4 address that was reserved:

```bash
gcloud compute addresses describe lb-ipv4-1 \
  --format="get(address)" \
  --global
```

#### Create a health check for the load balancer (to ensure that only healthy backends are sent traffic):

```bash
gcloud compute health-checks create http http-basic-check \
  --port 80
```

#### Create a backend service:

```bash
gcloud compute backend-services create web-backend-service \
  --protocol=HTTP \
  --port-name=http \
  --health-checks=http-basic-check \
  --global
```

#### Add your instance group as the backend to the backend service:

```bash
gcloud compute backend-services add-backend web-backend-service \
  --instance-group=lb-backend-group \
  --instance-group-zone=us-west1-b \
  --global
```

#### Create a URL map to route the incoming requests to the default backend service:

```bash
gcloud compute url-maps create web-map-http \
    --default-service web-backend-service
```

#### Create a target HTTP proxy to route requests to your URL map:
```bash
gcloud compute target-http-proxies create http-lb-proxy \
    --url-map web-map-http
```

#### Create a global forwarding rule to route incoming requests to the proxy:

```bash
gcloud compute forwarding-rules create http-content-rule \
   --address=lb-ipv4-1\
   --global \
   --target-http-proxy=http-lb-proxy \
   --ports=80
```

## Task 4. Test traffic sent to your instances


On the Google Cloud console in the Search field type Load balancing, then choose Load balancing from the search results.

Click on the load balancer that you just created, web-map-http.

In the Backend section, click on the name of the backend and confirm that the VMs are Healthy. If they are not healthy, wait a few moments and try reloading the page.

When the VMs are healthy, test the load balancer using a web browser, going to http://IP_ADDRESS/, replacing IP_ADDRESS with the load balancer's IP address that you copied previously.


