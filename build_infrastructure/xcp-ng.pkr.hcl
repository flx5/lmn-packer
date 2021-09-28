locals {
   root_password = "Muster!"
}

variable "headless" {
  type    = string
  default = "false"
}

variable "red_network" {
  type    = string
  default = "192.168.122.0/24"
}

variable "sockets" {
  type    = number
  default = 1
}

variable "cores" {
  type    = number
  default = 4
}

source "qemu" "xcp-ng" {

  headless = var.headless

  iso_url          = "https://mirrors.xcp-ng.org/isos/8.2/xcp-ng-8.2.0.iso?https=1"
  iso_checksum     = "sha256:789c0e33454211c06867dd5f48f8449abe4ca581adada5052f7cef3a731e450e"

  memory   = 2048

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

  ssh_timeout  = "20m"
  ssh_username = "root"
  ssh_password = local.root_password
 
  qemuargs = [
    [ "-cpu", "host"],
    [ "-smp", "cores=${var.cores},sockets=${var.sockets}" ],
    [ "-netdev", "user,id=user.0,net=${var.red_network},dhcpstart=${cidrhost(var.red_network,9)},hostfwd=tcp::{{ .SSHHostPort }}-:22"],
    [ "-device", "virtio-net,netdev=user.0" ],
    [ "-netdev", "user,id=user.1,net=10.0.0.0/8,restrict=y"],
    [ "-device", "virtio-net,netdev=user.1"]
  ]
  
      boot_command = [
        "mboot.c32 /boot/xen.gz ",
        "dom0_max_vcpus=1-16 dom0_mem=max:8192M ",
        "com1=115200,8n1 console=com1,va --- ",
        "/boot/vmlinuz console=hvc0 console=tty0 ",
        "answerfile_device=eth0 ",
        "answerfile=http://192.168.122.2:{{.HTTPPort}}/answerfile ",
        "install --- /install.img<enter>"
      ]
}

# TODO Document this
# Run successfull build using
/*

qemu-img create -f qcow2 -b proxmox output-xcp-ng/disk.qcow2

qemu-system-x86_64 -cpu host --accel kvm -m 4096 -smp $(nproc)  \
-drive file=output-xcp-ng/disk.qcow2,if=virtio,cache=writeback,discard=ignore,format=qcow2 \
-netdev user,id=user.0,net=192.168.122.0/24,dhcpstart=192.168.122.9,hostfwd=tcp::0-:22,hostfwd=tcp::0-:443 \
-device virtio-net,netdev=user.0 \
-netdev user,id=user.1,net=10.0.0.0/8,restrict=y \
-device virtio-net,netdev=user.1 \
-monitor unix:$PWD/mon.sock,server,nowait


To find ports use
echo 'info usernet' | socat - UNIX-CONNECT:./mon.sock | grep HOST_FORWARD | tr -s ' ' | cut -d' ' -f 5,7

*/
build {
  sources = [ "sources.qemu.xcp-ng" ]

  provisioner "shell" {
    script = "${path.root}/xcp_network.sh"
  }
}
