#!/bin/bash

set -e

# eth0 red
# eth1 green

xe network-list

RED_NETWORK=$(xe network-list bridge=xenbr0 --minimal)
echo "Red UUID: $RED_NETWORK"

xe network-param-set name-label=Red uuid=$RED_NETWORK

GREEN_NETWORK=$(xe network-list bridge=xenbr1 --minimal)
echo "Green UUID: $GREEN_NETWORK"

xe network-param-set name-label=Green uuid=$GREEN_NETWORK

GREEN_PIF=$(xe pif-list device=eth1 --minimal)
xe pif-reconfigure-ip uuid=$GREEN_PIF IP=10.0.0.70 mode=static netmask=255.0.0.0

xe network-list

ifconfig
