#!/bin/bash

VBOX_IF=$(vboxmanage hostonlyif create | grep -o -E 'vboxnet[0-9]+')
vboxmanage hostonlyif ipconfig $VBOX_IF --ip 10.0.0.30

(cd vagrant/opnsense-emulate; VBOX_IFACE=$VBOX_IF vagrant up gateway)

packer build -var "vbox_internal_net=$VBOX_IF" -only=virtualbox-iso.server 18

(cd vagrant/opnsense-emulate; vagrant destroy -f)

vboxmanage hostonlyif remove "$VBOX_IF"

