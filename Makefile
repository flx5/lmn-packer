WAN = 192.168.122.0/24
OPT = 192.168.123.0/24
LAN = virbr5

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

opnsense.PID: output/opnsense/packer-opnsense
	qemu-system-x86_64 \
	-snapshot \
	-machine type=pc,accel=kvm \
	-m 1024 \
	-drive file=output/opnsense/packer-opnsense,if=virtio,cache=writeback,discard=ignore,format=qcow2 \
	-netdev user,id=user.0,net=$(WAN) -device virtio-net,netdev=user.0 \
	-netdev user,id=opt,net=$(OPT) -device virtio-net,netdev=opt \
	-netdev bridge,id=user.1,br=$(LAN) -device virtio-net,netdev=user.1 \
	& echo $$! > opnsense.PID
	
	
opnsense-start: opnsense.PID
	wget --no-check-certificate --tries 20 --wait=10 --waitretry=10 --retry-connrefused https://10.0.0.254/ -O /dev/null

opnsense-stop: opnsense.PID
	kill `cat $<` && rm $<
	




	
server-base: | output/server
	
output/server: | opnsense-start
	packer build -var red_network=$(WAN) -var qemu_bridge=$(LAN) -only qemu.server vms/server/
	
output/server-qemu: | server-base
	mkdir -p output/tmp/
	qemu-img create -f qcow2 -b $(ROOT_DIR)/output/server/packer-server-1 output/tmp/packer-server-1
	packer build -only qemu.server-qemu vms/server/

server-qemu: output/server-qemu


output/server-virtualbox: | server-base
	mkdir -p output/tmp/
	rm -f output/tmp/packer-server-1
	qemu-img create -f qcow2 -b $(ROOT_DIR)/output/server/packer-server-1 output/tmp/packer-server-1
	packer build -only qemu.server-virtualbox vms/server/

server-virtualbox: | output/server-virtualbox



opsi-base: | output/opsi
	
output/opsi: | opnsense-start
	packer build -var red_network=$(WAN) -var qemu_bridge=$(LAN) -only qemu.opsi vms/server/

output/opsi-qemu: | output/opsi
	packer build -only qemu.opsi-qemu vms/server/

opsi-qemu: output/opsi-qemu
