#!/bin/bash

USER_NAME="$1"

EASYRSA_DIR="/opt/easy-rsa"
CLIENT_DIR="/opt/client-config"

# Detect public IP automatically

PUBLIC_IP=$(curl -4 -s ifconfig.me)

if [ -z "$USER_NAME" ]; then
echo "Usage: $0 <username>"
exit 1
fi

if [ "$EUID" -ne 0 ]; then
echo "Please run as root"
exit 2
fi

if [ -z "$PUBLIC_IP" ]; then
echo "Unable to determine public IP"
exit 3
fi

mkdir -p "${CLIENT_DIR}/${USER_NAME}"

cd "$EASYRSA_DIR" || exit 1

# Check if certificate already exists

if [ -f "pki/issued/${USER_NAME}.crt" ]; then
echo ""
echo "User '${USER_NAME}' already exists!"
echo ""
exit 4
fi

echo ""
echo "Detected Public IP: ${PUBLIC_IP}"
echo "Creating VPN user: ${USER_NAME}"
echo ""

# Generate client request

./easyrsa gen-req "${USER_NAME}" nopass <<EOF

EOF

# Sign certificate

./easyrsa sign-req client "${USER_NAME}" <<EOF
yes
EOF

# Create OVPN profile

cat > "${CLIENT_DIR}/${USER_NAME}/${USER_NAME}.ovpn" <<EOF
client
dev tun
proto udp

remote ${PUBLIC_IP} 1194

resolv-retry infinite
nobind

persist-key
persist-tun

remote-cert-tls server

cipher AES-256-GCM
auth SHA256

key-direction 1

verb 3
EOF

# Embed CA

echo "<ca>" >> "${CLIENT_DIR}/${USER_NAME}/${USER_NAME}.ovpn"
cat "${EASYRSA_DIR}/pki/ca.crt" >> "${CLIENT_DIR}/${USER_NAME}/${USER_NAME}.ovpn"
echo "</ca>" >> "${CLIENT_DIR}/${USER_NAME}/${USER_NAME}.ovpn"

# Embed certificate

echo "<cert>" >> "${CLIENT_DIR}/${USER_NAME}/${USER_NAME}.ovpn"
cat "${EASYRSA_DIR}/pki/issued/${USER_NAME}.crt" >> "${CLIENT_DIR}/${USER_NAME}/${USER_NAME}.ovpn"
echo "</cert>" >> "${CLIENT_DIR}/${USER_NAME}/${USER_NAME}.ovpn"

# Embed private key

echo "<key>" >> "${CLIENT_DIR}/${USER_NAME}/${USER_NAME}.ovpn"
cat "${EASYRSA_DIR}/pki/private/${USER_NAME}.key" >> "${CLIENT_DIR}/${USER_NAME}/${USER_NAME}.ovpn"
echo "</key>" >> "${CLIENT_DIR}/${USER_NAME}/${USER_NAME}.ovpn"

# Embed TLS key

echo "<tls-auth>" >> "${CLIENT_DIR}/${USER_NAME}/${USER_NAME}.ovpn"
cat "${EASYRSA_DIR}/ta.key" >> "${CLIENT_DIR}/${USER_NAME}/${USER_NAME}.ovpn"
echo "</tls-auth>" >> "${CLIENT_DIR}/${USER_NAME}/${USER_NAME}.ovpn"

# Create archive

cd "${CLIENT_DIR}" || exit 1
tar czf "${USER_NAME}.tar.gz" "${USER_NAME}"

echo ""
echo "==========================================="
echo "VPN User Created Successfully"
echo "==========================================="
echo "Username    : ${USER_NAME}"
echo "Public IP   : ${PUBLIC_IP}"
echo "OVPN File   : ${CLIENT_DIR}/${USER_NAME}/${USER_NAME}.ovpn"
echo "Archive     : ${CLIENT_DIR}/${USER_NAME}.tar.gz"
echo "==========================================="
echo ""
