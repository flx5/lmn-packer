#!/bin/bash

VBOX_IF=$(vboxmanage hostonlyif create | grep -o -E 'vboxnet[0-9]+')
vboxmanage hostonlyif ipconfig $VBOX_IF --ip 10.0.0.30

packer build -var "vbox_internal_net=$VBOX_IF" -only=virtualbox-iso.opnsense 18

OPNSENSE_VM=$(basename output-freebsd/*.ovf .ovf)

vboxmanage import "output-freebsd/$OPNSENSE_VM.ovf"

vboxmanage startvm "$OPNSENSE_VM" --type headless

packer build -var "vbox_internal_net=$VBOX_IF" -only=virtualbox-iso.server 18

vboxmanage controlvm "$OPNSENSE_VM" poweroff
vboxmanage unregistervm "$OPNSENSE_VM" --delete

vboxmanage hostonlyif remove "$VBOX_IF"

