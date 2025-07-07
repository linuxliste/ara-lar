#!/bin/bash

# Script to install and configure OpenVPN on Ubuntu 20.04

# Update system packages
sudo apt-get update
sudo apt-get upgrade -y

# Install OpenVPN and Easy-RSA
sudo apt-get install -y openvpn easy-rsa

# Set up the CA directory
make-cadir ~/openvpn-ca
cd ~/openvpn-ca

# Configure the vars file
cat << EOF > ~/openvpn-ca/vars
export EASYRSA_ALGO="ec"
export EASYRSA_CURVE="prime256v1"
export EASYRSA_PKI="pki"
export EASYRSA_REQ_CN="ChangeMe"
EOF

# Initialize the PKI, build the CA
./easyrsa init-pki
./easyrsa build-ca nopass

# Generate server certificate and key
./easyrsa gen-req server nopass
./easyrsa sign-req server server

# Generate Diffie-Hellman key exchange
./easyrsa gen-dh

# Generate client certificate and key
./easyrsa gen-req client1 nopass
./easyrsa sign-req client client1

# Copy the necessary files to the OpenVPN directory
sudo cp pki/ca.crt pki/private/server.key pki/issued/server.crt pki/dh.pem /etc/openvpn/

# Generate OpenVPN server configuration
cat << EOF > /etc/openvpn/server.conf
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
EOF

# Enable IP forwarding
sudo sed -i '/net.ipv4.ip_forward=1/s/^#//g' /etc/sysctl.conf
sudo sysctl -p

# Configure UFW
sudo ufw allow 1194/udp
sudo ufw allow OpenSSH
sudo ufw disable
sudo ufw enable

# Start and enable OpenVPN service
sudo systemctl start openvpn@server
sudo systemctl enable openvpn@server

echo "OpenVPN kurulumu tamamlandı. Client yapılandırması için aşağıdaki komutları çalıştırın:"
echo "1. Client config dosyası oluşturun: sudo nano /etc/openvpn/client1.ovpn"
echo "2. Aşağıdaki satırları config dosyasına ekleyin:"
cat << EOF
client
dev tun
proto udp
remote your_server_ip 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
verb 3
<ca>
$(cat ~/openvpn-ca/pki/ca.crt)
</ca>
<cert>
$(cat ~/openvpn-ca/pki/issued/client1.crt)
</cert>
<key>
$(cat ~/openvpn-ca/pki/private/client1.key)
</key>
EOF



echo  iptables -t nat -A PREROUTING -p tcp --dport 1025:65000 -j DNAT --to-destination 10.8.0.2
echo iptables -t nat -A PREROUTING -p tcp --dport 1025:65000 -j DNAT --to-destination 10.8.0.2
echo iptables -A FORWARD -p tcp -d 1.2.3.4 --dport 1025:65000 -j ACCEPT
echo iptables -t nat -A PREROUTING -p udp --dport 1025:65000 -j DNAT --to-destination  10.8.0.2
echo iptables -A FORWARD -p udp -d 1.2.3.4 --dport 1025:65000 -j ACCEPT

