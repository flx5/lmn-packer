locals {
   root_password = "Muster!"
}

variable "headless" {
  type    = string
  default = "false"
}

source "qemu" "base-debian" {

  headless = var.headless
 
  # TODO Guest agent config?
  #qemu_agent           = "true"

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
  
      boot_command = [
        "mboot.c32 /boot/xen.gz ",
        "dom0_max_vcpus=1-16 dom0_mem=max:8192M ",
        "com1=115200,8n1 console=com1,va --- ",
        "/boot/vmlinuz console=hvc0 console=tty0 ",
        "answerfile=http://{{.HTTPIP}}:{{.HTTPPort}}/answerfile ",
        "install --- /install.img<enter>"
      ]
}


# Run successfull build using qemu-system-x86_64 --accel kvm -m 2048 -nic user,id=wandev,net=192.168.70.0/24 proxmox
build {
  sources = [ "sources.qemu.base-debian" ]
}
