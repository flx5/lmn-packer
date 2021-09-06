variable "proxmox_host" {
  type    = string
  default = "localhost:8006"
}

variable "proxmox_user" {
  type      = string
  default   = "root@pam"
  sensitive = true
}

variable "proxmox_password" {
  type      = string
  default   = "vagrant"
  sensitive = true
}

variable "proxmox_node" {
  type    = string
  default = "proxmox"
}

variable "proxmox_iso_pool" {
  type    = string
  default = "local"
}

variable "proxmox_disk_pool" {
  type    = string
  default = "local"
}

variable "proxmox_disk_pool_type" {
  type    = string
  default = "directory"
}

variable "proxmox_disk_format" {
  type    = string
  default = "qcow2"
}

locals {
  iso_url       = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-11.0.0-amd64-netinst.iso"
  iso_checksum  = "sha512:5f6aed67b159d7ccc1a90df33cc8a314aa278728a6f50707ebf10c02e46664e383ca5fa19163b0a1c6a4cb77a39587881584b00b45f512b4a470f1138eaa1801"
  memory        = 4096
  root_password = "Muster!"

  boot_command = [
                "<wait5><esc><wait>",
                "auto url=http://{{.HTTPIP}}:{{.HTTPPort}}/preseed.cfg ",
                "netcfg/disable_autoconfig=true netcfg/get_nameservers=1.1.1.1 ",
                "netcfg/get_ipaddress=192.168.10.13 netcfg/get_netmask=255.255.255.240 ",
                "netcfg/get_gateway=192.168.10.1 netcfg/confirm_static=true ",
                "<enter>"
  ]
}

source "proxmox-iso" "debian-template" {
  proxmox_url              = "https://${var.proxmox_host}/api2/json"
  username                 = var.proxmox_user
  password                 = var.proxmox_password
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  vm_name = "debian-template"

  template_description = "Debian Template"
  qemu_agent           = "true"

  iso_url          = local.iso_url
  iso_checksum     = local.iso_checksum
  iso_storage_pool = "${var.proxmox_iso_pool}"

  memory   = local.memory
  cpu_type = "host"
  cores    = 2
  sockets  = 2

  os = "l26"

  scsi_controller = "virtio-scsi-pci"

  disks {
    storage_pool      = "${var.proxmox_disk_pool}"
    storage_pool_type = "${var.proxmox_disk_pool_type}"
    disk_size         = "25G"
    format            = var.proxmox_disk_format
  }

  unmount_iso = true
  onboot      = true

  boot_wait = "5s"
  boot_command = local.boot_command

  http_content = {
    "/preseed.cfg" = templatefile("preseed.pkrtpl.hcl", { root_pw = local.root_password, installs = ["qemu-guest-agent"]  })
  }

  ssh_timeout  = "10000s"
  ssh_username = "root"
  ssh_password = local.root_password

  network_adapters {
    bridge = "vmbr0"
    model  = "virtio"
  }
}

build {
  sources = ["sources.proxmox-iso.debian-template"]
}


