locals {
   root_password = "Muster!"
}

variable "headless" {
  type    = string
  default = "false"
}

variable "net_bridge" {
  type    = string
  default = "virbr0"
}

source "qemu" "xcp-ng" {

  headless = var.headless

  iso_url          = "https://mirrors.xcp-ng.org/isos/8.2/xcp-ng-8.2.0.iso?https=1"
  iso_checksum     = "sha256:789c0e33454211c06867dd5f48f8449abe4ca581adada5052f7cef3a731e450e"

  memory   = 2048
  cpus    = 2


  disk_size = "500G"
  format    = "qcow2"
  accelerator = "kvm"
  vm_name = "proxmox"
  net_device = "virtio-net"
  disk_interface = "virtio"

  boot_wait = "3s"

  http_content = {
    "/answerfile" = templatefile("answerfile.pkrtpl.hcl", { root_pw = local.root_password })
  }

  ssh_timeout  = "10000s"
  ssh_username = "root"
  ssh_password = local.root_password
  
  # TODO Document non-root use https://mike42.me/blog/2019-08-how-to-use-the-qemu-bridge-helper-on-debian-10
  # TODO Must be nat bridge
  net_bridge = var.net_bridge
  
      boot_command = [
        "mboot.c32 /boot/xen.gz ",
        "dom0_max_vcpus=1-16 dom0_mem=max:8192M ",
        "com1=115200,8n1 console=com1,va --- ",
        "/boot/vmlinuz console=hvc0 console=tty0 ",
        "answerfile=http://{{.HTTPIP}}:{{.HTTPPort}}/answerfile ",
        "install --- /install.img<enter>"
      ]
}

# TODO Document this
# Run successfull build using
/*
virbr0 is nat bridge

TODO Add libvirt xml files

qemu-img create -f qcow2 -b proxmox output-xcp-ng/disk.qcow2

qemu-system-x86_64 -cpu host --accel kvm -m 4096 -smp cpus=4,sockets=1 \
-drive file=output-xcp-ng/disk.qcow2,if=virtio,cache=writeback,discard=ignore,format=qcow2 \
-netdev bridge,id=user.0,br=virbr0 -device virtio-net,netdev=user.0
*/
build {
  sources = [ "sources.qemu.xcp-ng" ]

  # Need to create service to persist network changes
  # https://serverfault.com/a/414796
  provisioner "file" {
    source = "ovs-init.sh"
    destination = "/etc/init.d/ovs-init"
  }


  provisioner "shell" {
    inline = [
       "chmod +x /etc/init.d/ovs-init",
       "chkconfig --add ovs-init",
    #  "yum update -y",
      
      # Install socat for VNC forwarding
      "yum install -y socat",
      
      "HOST_UUID=$(xe pif-list params=host-uuid --minimal)",
      "RED_PIF=$(xe pif-list --minimal)",
      "RED_NETWORK=$(xe network-list PIF-uuids=$RED_PIF --minimal)",
      "xe network-param-set name-label=Red uuid=$RED_NETWORK",

      "xe network-create name-label=Green bridge=br1",
      "xe network-list",
      "ifconfig"
    ]
  }
}
