# Linuxmuster Appliance Builder

[![Proxmox](https://github.com/flx5/lmn-packer/actions/workflows/proxmox.yml/badge.svg?event=schedule)](https://github.com/flx5/lmn-packer/actions/workflows/proxmox.yml)


Build the Linuxmuster 7 Server Appliance with Packer.


Currently only VirtualBox is supported.

### Required Software

- VirtualBox
- Packer


### Build

`packer build 18/server.pkr.hcl`

### Future Plans

- Create Vagrant Demo Environment
- Support all relevant provisioners (KVM, Proxmox, XEN)
- Automatically build Linbo cloops (qcow2 for new linbo)