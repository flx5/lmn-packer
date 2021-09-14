locals {
   root_password = "Muster!"
}

variable "headless" {
  type    = string
  default = "false"
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
  
      boot_command = [
        "mboot.c32 /boot/xen.gz ",
        "dom0_max_vcpus=1-16 dom0_mem=max:8192M ",
        "com1=115200,8n1 console=com1,va --- ",
        "/boot/vmlinuz console=hvc0 console=tty0 ",
        "answerfile=http://{{.HTTPIP}}:{{.HTTPPort}}/answerfile ",
        "install --- /install.img<enter>"
      ]
}


# Run successfull build using  qemu-system-x86_64 -cpu host --accel kvm -m 4096 -nic user,id=wandev,net=192.168.70.0/24,hostfwd=tcp::2255-:22,hostfwd=tcp::8443-:443 output-base-debian/proxmox
build {
  sources = [ "sources.qemu.base-debian" ]
  
  provisioner "shell" {


    inline = [
      "yum update -y",
      
      # Install socat for VNC forwarding
      "yum install socat",
      
      # Install packer
      "yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo",
      "yum -y install packer",
      
      # Setup SR
      "SR_UUID=$(xe sr-create type=ext content-type=user name-label="Local" device-config:device=/dev/sda3)",
      "POOL_UUID=$(xe pool-list --minimal)",
      "xe pool-param-set uuid=$POOL_UUID default-SR=$SR_UUID",
      "/usr/bin/create-guest-templates"
    ]
  }
}
