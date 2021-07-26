#!/bin/bash

set -e

wget -O- http://pkg.linuxmuster.net/archive.linuxmuster.net.key | apt-key add -
wget https://archive.linuxmuster.net/lmn7/lmn7.list -O /etc/apt/sources.list.d/lmn7.list
apt-get update

DEBIAN_FRONTEND=noninteractive apt -y purge lxd lxd-client lxcfs lxc-common snapd
DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade

# TODO Remove  --allow-unauthenticated once linuxmuster repo catches up..
DEBIAN_FRONTEND=noninteractive apt-get install -y  --allow-unauthenticated linuxmuster-prepare
