#!/bin/bash

set -e

export DEBIAN_FRONTEND=noninteractive 

# Fix hostname
sed -i "s/.*$(hostname)/$(hostname -I)\t$(hostname)/" /etc/hosts

# Install proxmox repository key
wget https://enterprise.proxmox.com/debian/proxmox-release-bullseye.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg
echo 'deb [arch=amd64] http://download.proxmox.com/debian/pve bullseye pve-no-subscription' > /etc/apt/sources.list.d/pve-install-repo.list
echo '7fb03ec8a1675723d2853b84aa4fdb49a46a3bb72b9951361488bfd19b29aab0a789a4f8c7406e71a69aabbc727c936d3549731c4659ffa1a08f44db8fdcebfa  /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg' \
  | sha512sum -c -

# Make sure system is up to date
apt-get update
apt-get full-upgrade -y

# Preconfigure postfix
echo 'postfix postfix/main_mailer_type select No configuration' | debconf-set-selections

# Install proxmox with dhcp server
DEBIAN_FRONTEND=noninteractive apt-get install -y proxmox-ve postfix open-iscsi isc-dhcp-server
apt-get remove -y os-prober

# Allow iso and vm images on local storage
pvesm set local -content images,snippets,rootdir,backup,iso,vztmpl

# Setup bridges
DEFAULT_IFACE=$(ip route show default | grep -o 'dev \w*' | cut -d' ' -f 2)

WAN_ADDRESS="${WAN_PREFIX}.1"

cat << EOF >> /etc/network/interfaces

# Wan interface for OPNSense
auto vmbr0
iface vmbr0 inet static
        address ${WAN_ADDRESS}/24
        bridge-ports none
        bridge-stp off
        bridge-fd 0

        post-up   echo 1 > /proc/sys/net/ipv4/ip_forward
        post-up   iptables -t nat -A POSTROUTING -s '${WAN_ADDRESS}/24' -o ${DEFAULT_IFACE} -j MASQUERADE
        post-down iptables -t nat -D POSTROUTING -s '${WAN_ADDRESS}/24' -o ${DEFAULT_IFACE} -j MASQUERADE

# Lan interface for OPNSense
auto vmbr1
iface vmbr1 inet static
       address 10.0.0.253/24
       bridge-ports none 
       bridge-stp off
       bridge-fd 0
EOF

ifreload -a

# Setup DHCP Server for WAN interface

cat << EOF > /etc/default/isc-dhcp-server
INTERFACESv4="vmbr0"
INTERFACESv6=""
authoritative;
EOF

cat << EOF > /etc/dhcp/dhcpd.conf
subnet ${WAN_PREFIX}.0 netmask 255.255.255.0 {
  range ${WAN_PREFIX}.10 ${WAN_PREFIX}.20;
  option routers ${WAN_ADDRESS};
  option domain-name-servers ${NAMESERVER};
}
EOF
