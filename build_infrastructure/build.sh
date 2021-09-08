#!/bin/bash

echo -n Personal Github Token:
read -s github_token
echo ""

export PKR_VAR_github_token=$github_token

if qm status 500 > /dev/null 2>&1; then
 qm destroy 500
fi

if qm status 600 > /dev/null 2>&1; then 
 qm stop 600
 qm destroy 600
fi


packer build -only=proxmox-iso.proxmox  -var 'proxmox_password=Muster!' -var 'proxmox_node=pve' \
     -var 'proxmox_disk_pool=vd-hdd-1400' -var 'proxmox_disk_pool_type=lvm-thin' -var 'proxmox_disk_format=raw' \
     -var 'github_owner=flx5' -var 'github_repository=lmn-packer' \
     .



qm clone 500 600 -full 0 -name proxmox-runner
qm start 600
