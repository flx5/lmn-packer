locals {
  iso_url       = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-11.0.0-amd64-netinst.iso"
  iso_checksum  = "sha512:5f6aed67b159d7ccc1a90df33cc8a314aa278728a6f50707ebf10c02e46664e383ca5fa19163b0a1c6a4cb77a39587881584b00b45f512b4a470f1138eaa1801"
  memory        = 16384
  root_password = "Muster!"
  netmask       = "255.255.255.240"
  gateway       = "192.168.10.1"
  nameserver    = "192.168.10.1"

  builds = {
    proxmox = {
      ip       = "192.168.10.13"
      wan_prefix = "192.168.50"
      hostname = "proxmox"
      vm_id    = 500
    }
  }
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "github_owner" {
  type = string
}

variable "github_repository" {
  type = string
}

source "proxmox-iso" "base-debian" {
  proxmox_url              = "https://${var.proxmox_host}/api2/json"
  username                 = var.proxmox_user
  password                 = var.proxmox_password
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

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
    disk_size         = "500G"
    format            = var.proxmox_disk_format
  }

  unmount_iso = true
  onboot      = true

  boot_wait = "5s"

  http_content = {
    "/preseed.cfg" = templatefile("preseed.pkrtpl.hcl", { root_pw = local.root_password, installs = ["qemu-guest-agent"] })
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
  dynamic "source" {
    for_each = local.builds
    labels   = ["source.proxmox-iso.base-debian"]

    content {
      vm_id   = source.value.vm_id
      name    = source.key
      vm_name = source.key
      boot_command = [
        "<wait5><esc><wait>",
        "auto url=http://{{.HTTPIP}}:{{.HTTPPort}}/preseed.cfg ",
        "netcfg/get_hostname=${source.value.hostname} ",
        "netcfg/disable_autoconfig=true netcfg/get_nameservers=${local.nameserver} ",
        "netcfg/get_ipaddress=${source.value.ip} netcfg/get_netmask=${local.netmask} ",
        "netcfg/get_gateway=${local.gateway} netcfg/confirm_static=true ",
        "<enter>"
      ]
    }
  }

  provisioner "shell" {
    scripts = [
      "scripts/install_packer.sh",
      "scripts/install_github.sh"
    ]
    environment_vars = [
      "GITHUB_OWNER=${var.github_owner}",
      "GITHUB_REPOSITORY=${var.github_repository}",
      "GITHUB_PAT=${var.github_token}",
      "GITHUB_LABEL=${source.name}"
    ]
  }

  provisioner "shell" {
    only   = ["proxmox-iso.proxmox"]
    script = "scripts/install_proxmox.sh"
    expect_disconnect = true
    environment_vars = [
       "WAN_PREFIX=${local.builds[source.name].wan_prefix}"
    ]
  }
}


