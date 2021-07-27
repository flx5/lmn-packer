# Linuxmuster Appliance Builder

[![Build status](https://ci.appveyor.com/api/projects/status/jxp2ve26sd2yvq57/branch/main?svg=true)](https://ci.appveyor.com/project/flx5/lmn-packer/branch/main)

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