# OpenVPN Server Setup on Rocky Linux 9 in Google Cloud Platform (GCP)

## Overview

This document describes the complete deployment of an OpenVPN server on Rocky Linux 9 running in Google Cloud Platform (GCP) using a custom VPC network. The setup includes:

* Custom VPC creation
* Custom subnet creation
* Firewall rules
* Rocky Linux VM deployment
* OpenVPN installation
* Easy-RSA PKI configuration
* Certificate generation
* OpenVPN server configuration
* NAT configuration
* Client profile generation
* Connectivity verification

---

# Environment Details

| Component        | Value                 |
| ---------------- | --------------------- |
| Cloud Provider   | Google Cloud Platform |
| Region           | asia-south1           |
| Zone             | asia-south1-b         |
| OS               | Rocky Linux 9         |
| OpenVPN Protocol | UDP                   |
| OpenVPN Port     | 1194                  |
| VPN Network      | 10.8.0.0/24           |
| VPC Network      | 10.10.10.0/24         |
| VM Private IP    | 10.10.10.10           |
| Public IP        | 35.200.153.108        |

---

# Step 1: Create Custom VPC

```bash
gcloud compute networks create openvpn-vpc \
    --subnet-mode=custom
```

Verify:

```bash
gcloud compute networks list
```

---

# Step 2: Create Subnet

```bash
gcloud compute networks subnets create openvpn-subnet \
    --network=openvpn-vpc \
    --region=asia-south1 \
    --range=10.10.10.0/24
```

Verify:

```bash
gcloud compute networks subnets list
```

---

# Step 3: Create Firewall Rules

## Allow SSH

```bash
gcloud compute firewall-rules create allow-ssh-openvpn \
    --network=openvpn-vpc \
    --allow=tcp:22 \
    --source-ranges=0.0.0.0/0
```

## Allow OpenVPN

```bash
gcloud compute firewall-rules create allow-openvpn \
    --network=openvpn-vpc \
    --allow=udp:1194 \
    --source-ranges=0.0.0.0/0
```

## Allow ICMP

```bash
gcloud compute firewall-rules create allow-icmp-openvpn \
    --network=openvpn-vpc \
    --allow=icmp \
    --source-ranges=0.0.0.0/0
```

Verify:

```bash
gcloud compute firewall-rules list
```

---

# Step 4: Create Rocky Linux VM

```bash
gcloud compute instances create openvpn-server \
    --zone=asia-south1-b \
    --machine-type=e2-medium \
    --network=openvpn-vpc \
    --subnet=openvpn-subnet \
    --private-network-ip=10.10.10.10 \
    --image-family=rocky-linux-9 \
    --image-project=rocky-linux-cloud \
    --boot-disk-size=20GB
```

Connect:

```bash
gcloud compute ssh openvpn-server --zone asia-south1-b
```

---

# Step 5: Prepare Rocky Linux

Update system:

```bash
sudo dnf update -y
```

Install EPEL:

```bash
sudo dnf install epel-release -y
```

Install OpenVPN and Easy-RSA:

```bash
sudo dnf install openvpn easy-rsa -y
```

Disable firewalld (Lab Environment):

```bash
sudo systemctl disable --now firewalld
```

Disable SELinux temporarily:

```bash
sudo setenforce 0
```

---

# Step 6: Create PKI

Create Easy-RSA workspace:

```bash
mkdir ~/easy-rsa

cp -r /usr/share/easy-rsa/* ~/easy-rsa/

cd ~/easy-rsa/3
```

Initialize PKI:

```bash
./easyrsa init-pki
```

Create CA without password:

```bash
./easyrsa build-ca nopass
```

Common Name:

```text
OpenVPN-CA
```

---

# Step 7: Generate Server Certificate

Create request:

```bash
./easyrsa gen-req server nopass
```

Common Name:

```text
OpenVPN
```

Sign certificate:

```bash
./easyrsa sign-req server server
```

Type:

```text
yes
```

---

# Step 8: Generate Client Certificate

Create request:

```bash
./easyrsa gen-req client1 nopass
```

Sign certificate:

```bash
./easyrsa sign-req client client1
```

Type:

```text
yes
```

---

# Step 9: Generate Diffie-Hellman Parameters

```bash
./easyrsa gen-dh
```

Generated file:

```text
pki/dh.pem
```

---

# Step 10: Generate TLS Authentication Key

```bash
openvpn --genkey secret ta.key
```

---

# Step 11: Configure OpenVPN Server

Create directory:

```bash
sudo mkdir -p /etc/openvpn/server
```

Copy certificates:

```bash
sudo cp pki/ca.crt /etc/openvpn/server/

sudo cp pki/issued/server.crt /etc/openvpn/server/

sudo cp pki/private/server.key /etc/openvpn/server/

sudo cp pki/dh.pem /etc/openvpn/server/

sudo cp ta.key /etc/openvpn/server/
```

---

# Step 12: Create Server Configuration

File:

```bash
sudo vi /etc/openvpn/server/server.conf
```

Content:

```conf
port 1194
proto udp
dev tun

ca ca.crt
cert server.crt
key server.key
dh dh.pem

tls-auth ta.key 0

topology subnet
server 10.8.0.0 255.255.255.0

push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 1.1.1.1"

keepalive 10 120

cipher AES-256-GCM
auth SHA256

persist-key
persist-tun

user nobody
group nobody

verb 3
```

---

# Step 13: Enable IP Forwarding

```bash
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-openvpn.conf
```

Apply:

```bash
sudo sysctl --system
```

Verify:

```bash
sysctl net.ipv4.ip_forward
```

Expected:

```text
net.ipv4.ip_forward = 1
```

---

# Step 14: Configure NAT

Identify interface:

```bash
ip route get 8.8.8.8
```

Output:

```text
dev eth0
```

Add NAT rule:

```bash
sudo iptables -t nat -A POSTROUTING \
-s 10.8.0.0/24 \
-o eth0 \
-j MASQUERADE
```

Verify:

```bash
sudo iptables -t nat -L POSTROUTING -n -v
```

---

# Step 15: Start OpenVPN

Enable service:

```bash
sudo systemctl enable openvpn-server@server
```

Start service:

```bash
sudo systemctl start openvpn-server@server
```

Verify:

```bash
sudo systemctl status openvpn-server@server
```

Verify port:

```bash
sudo netstat -npatu | grep 1194
```

Expected:

```text
udp 0 0 0.0.0.0:1194
```

---

# Step 16: Verify Tunnel Interface

Server:

```bash
ip a
```

Expected:

```text
tun0
10.8.0.1/24
```

---

# Step 17: Create Client Profile

Create directory:

```bash
mkdir ~/client-configs

cd ~/client-configs
```

Copy client files:

```bash
cp ~/easy-rsa/3/pki/ca.crt .

cp ~/easy-rsa/3/pki/issued/client1.crt .

cp ~/easy-rsa/3/pki/private/client1.key .

cp ~/easy-rsa/3/ta.key .
```

Create:

```bash
vi client1.ovpn
```

Content:

```conf
client
dev tun
proto udp

remote 35.200.153.108 1194

resolv-retry infinite
nobind

persist-key
persist-tun

remote-cert-tls server

cipher AES-256-GCM
auth SHA256

key-direction 1

verb 3
```

Append certificates:

```bash
echo "<ca>" >> client1.ovpn
cat ca.crt >> client1.ovpn
echo "</ca>" >> client1.ovpn

echo "<cert>" >> client1.ovpn
cat client1.crt >> client1.ovpn
echo "</cert>" >> client1.ovpn

echo "<key>" >> client1.ovpn
cat client1.key >> client1.ovpn
echo "</key>" >> client1.ovpn

echo "<tls-auth>" >> client1.ovpn
cat ta.key >> client1.ovpn
echo "</tls-auth>" >> client1.ovpn
```

---

# Step 18: Import Client Profile

Install OpenVPN Client on:

* Windows
* Linux
* Android
* iOS

Import:

```text
client1.ovpn
```

Connect.

---

# Step 19: Verification

Client Tunnel Interface:

```bash
ip a
```

Expected:

```text
tun0
10.8.0.2/24
```

Server Tunnel Interface:

```text
10.8.0.1/24
```

Ping VPN Server:

```bash
ping 10.8.0.1
```

Check Public IP:

```bash
curl ifconfig.me
```

Expected:

```text
35.200.153.108
```

This confirms all client traffic is routed through the OpenVPN server.

---

# Final Result

Successfully deployed OpenVPN on Rocky Linux 9 in Google Cloud Platform with:

* Custom VPC
* Custom Subnet
* UDP 1194 Access
* Easy-RSA PKI
* OpenVPN Server
* Client Authentication
* TLS Authentication
* NAT Configuration
* Internet Access Through VPN

Status: SUCCESSFUL

