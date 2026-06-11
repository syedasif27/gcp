# OpenVPN Server Setup on Ubuntu Server (Lab Environment)

## Overview

This document describes the complete deployment of an OpenVPN server on Ubuntu Server using Easy-RSA. The setup includes:

* OpenVPN installation
* Easy-RSA PKI setup
* Certificate generation
* OpenVPN server configuration
* IP forwarding
* NAT configuration
* Client profile creation
* VPN connectivity verification

---

# Environment Details

| Component        | Value                   |
| ---------------- | ----------------------- |
| Operating System | Ubuntu Server 24.04 LTS |
| OpenVPN Protocol | UDP                     |
| OpenVPN Port     | 1194                    |
| VPN Network      | 10.8.0.0/24             |
| Server VPN IP    | 10.8.0.1                |
| Client VPN IP    | 10.8.0.2                |

---

# Step 1: Update Ubuntu

```bash
sudo apt update
sudo apt upgrade -y
```

Install required packages:

```bash
sudo apt install -y openvpn easy-rsa net-tools iptables
```

Verify:

```bash
openvpn --version
```

---

# Step 2: Create Easy-RSA Workspace

```bash
mkdir ~/easy-rsa

cp -r /usr/share/easy-rsa/* ~/easy-rsa/

cd ~/easy-rsa
```

Initialize PKI:

```bash
./easyrsa init-pki
```

---

# Step 3: Create Certificate Authority (CA)

Create CA without passphrase:

```bash
./easyrsa build-ca nopass
```

Example:

```text
Common Name: OpenVPN-CA
```

Verify CA key:

```bash
openssl pkey -in pki/private/ca.key -text -noout | head
```

---

# Step 4: Generate Server Certificate

Generate request:

```bash
./easyrsa gen-req server nopass
```

Example:

```text
Common Name: OpenVPN
```

Sign certificate:

```bash
./easyrsa sign-req server server
```

Type:

```text
yes
```

Verify:

```bash
ls pki/issued/server.crt
```

---

# Step 5: Generate Client Certificate

Generate request:

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

Verify:

```bash
ls pki/issued/client1.crt
```

---

# Step 6: Generate Diffie-Hellman Parameters

```bash
./easyrsa gen-dh
```

Output:

```text
pki/dh.pem
```

---

# Step 7: Generate TLS Authentication Key

```bash
openvpn --genkey secret ta.key
```

Verify:

```bash
ls -lh ta.key
```

---

# Step 8: Create OpenVPN Server Directory

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

Verify:

```bash
ls -l /etc/openvpn/server/
```

Expected:

```text
ca.crt
dh.pem
server.crt
server.key
ta.key
```

---

# Step 9: Create OpenVPN Server Configuration

Create:

```bash
sudo nano /etc/openvpn/server/server.conf
```

Paste:

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
group nogroup

verb 3
```

---

# Step 10: Enable IP Forwarding

Create configuration:

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

# Step 11: Configure NAT

Identify outbound interface:

```bash
ip route get 8.8.8.8
```

Example:

```text
dev ens5
```

Add NAT rule:

```bash
sudo iptables -t nat -A POSTROUTING \
-s 10.8.0.0/24 \
-o ens5 \
-j MASQUERADE
```

Verify:

```bash
sudo iptables -t nat -L POSTROUTING -n -v
```

---

# Step 12: Make iptables Persistent

Install:

```bash
sudo apt install -y iptables-persistent
```

Save rules:

```bash
sudo netfilter-persistent save
```

Enable:

```bash
sudo systemctl enable netfilter-persistent
```

Verify:

```bash
sudo iptables -t nat -L POSTROUTING -n -v
```

---

# Step 13: Start OpenVPN Service

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

Check listening port:

```bash
sudo ss -lunp | grep 1194
```

Expected:

```text
udp 0 0 0.0.0.0:1194
```

---

# Step 14: Verify Tunnel Interface

Check:

```bash
ip a
```

Expected:

```text
tun0
10.8.0.1/24
```

---

# Step 15: Create Client Profile

Create directory:

```bash
mkdir ~/client-configs

cd ~/client-configs
```

Copy files:

```bash
cp ~/easy-rsa/pki/ca.crt .

cp ~/easy-rsa/pki/issued/client1.crt .

cp ~/easy-rsa/pki/private/client1.key .

cp ~/easy-rsa/ta.key .
```

Create:

```bash
nano client1.ovpn
```

Paste:

```conf
client
dev tun
proto udp

remote <SERVER_PUBLIC_IP> 1194

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

---

# Step 16: Embed Certificates

Append CA:

```bash
echo "<ca>" >> client1.ovpn
cat ca.crt >> client1.ovpn
echo "</ca>" >> client1.ovpn
```

Append client certificate:

```bash
echo "<cert>" >> client1.ovpn
cat client1.crt >> client1.ovpn
echo "</cert>" >> client1.ovpn
```

Append client key:

```bash
echo "<key>" >> client1.ovpn
cat client1.key >> client1.ovpn
echo "</key>" >> client1.ovpn
```

Append TLS key:

```bash
echo "<tls-auth>" >> client1.ovpn
cat ta.key >> client1.ovpn
echo "</tls-auth>" >> client1.ovpn
```

---

# Step 17: Import Client Profile

Install OpenVPN client on:

* Ubuntu Desktop
* Windows
* macOS
* Android
* iPhone

Import:

```text
client1.ovpn
```

Connect to VPN.

---

# Step 18: Verify Connectivity

Check VPN interface:

```bash
ip a
```

Expected:

```text
tun0
10.8.0.2/24
```

Ping VPN server:

```bash
ping -c 4 10.8.0.1
```

Verify public IP:

```bash
curl ifconfig.me
```

Expected output:

```text
<Server Public IP>
```

This confirms traffic is routed through the VPN.

---

# Step 19: Useful Troubleshooting Commands

Service status:

```bash
sudo systemctl status openvpn-server@server
```

Live logs:

```bash
sudo journalctl -u openvpn-server@server -f
```

Check tunnel:

```bash
ip a | grep tun0
```

Check listening port:

```bash
sudo ss -lunp | grep 1194
```

Check NAT:

```bash
sudo iptables -t nat -L -n -v
```

Check routes:

```bash
ip route
```

---

# Final Result

Successfully deployed OpenVPN on Ubuntu Server with:

* Easy-RSA PKI
* Server and Client Certificates
* TLS Authentication
* OpenVPN Server
* NAT Configuration
* Internet Access Through VPN
* Persistent Firewall Rules

Status: SUCCESSFUL

