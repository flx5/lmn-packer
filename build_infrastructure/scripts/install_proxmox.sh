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

cat << EOF > /etc/network/interfaces

auto lo
iface lo inet loopback

allow-hotplug $DEFAULT_IFACE
iface $DEFAULT_IFACE inet manual

# Wan interface for OPNSense
auto vmbr0
iface vmbr0 inet static
	address $WAN_ADDRESS
	gateway $WAN_GATEWAY
        bridge-ports $DEFAULT_IFACE
        bridge-stp off
        bridge-fd 0

# Lan interface for OPNSense
auto vmbr1
iface vmbr1 inet static
       address 10.0.0.253/24
       bridge-ports none 
       bridge-stp off
       bridge-fd 0
EOF

cat /etc/network/interfaces

ifreload -a
