#!/bin/bash

set -e

if ! qm status 200 | grep -q running; then 
   echo "OPNSense must be running"
   exit 1
fi

if [[ -d dump ]]; then
  rm dump/vzdump-qemu-401*
else
  mkdir dump
fi


# Build the VM
packer build -only=proxmox-iso.server -var 'proxmox_password=Muster!' -var 'proxmox_node=pve' -var 'proxmox_disk_pool=vd-hdd-1400' -var 'proxmox_disk_pool_type=lvm-thin' -var 'proxmox_disk_format=raw' 18/server.pkr.hcl

# Dump the VM
qm set 401 --template 0
vzdump --compress lzo --dumpdir ./dump/ 401

# Cleanup
qm destroy 401

#TODO Move the dumped lzo somewhere
