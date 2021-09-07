locals {
  iso_url       = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-11.0.0-amd64-netinst.iso"
  iso_checksum  = "sha512:5f6aed67b159d7ccc1a90df33cc8a314aa278728a6f50707ebf10c02e46664e383ca5fa19163b0a1c6a4cb77a39587881584b00b45f512b4a470f1138eaa1801"
  memory        = 8192
  root_password = "Muster!"
  netmask = "255.255.255.240"
  gateway = "192.168.10.1"
  nameserver = "192.168.10.1"
  
  builds = {
    proxmox = {
       ip = "192.168.10.13"
       hostname = "proxmox"
       vm_id = 500
    }
  }
}

variable "github_token" {
  type      = string
  sensitive = true
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
    disk_size         = "25G"
    format            = var.proxmox_disk_format
  }

  unmount_iso = true
  onboot      = true

  boot_wait = "5s"

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
  dynamic "source" {
     for_each = local.builds
     labels = ["source.proxmox-iso.base-debian"]
     
     content {
        vm_id = source.value.vm_id
        name = source.key
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
    inline = [
       "apt-get install -y lsb-release curl software-properties-common gnupg2",
       "curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -",
       "apt-add-repository \"deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main\"",
       "apt-get install -y packer sudo"
    ]
  }
  
  provisioner "shell" {
    inline = [
       "adduser --system github"
    ]
  }
  
  provisioner "file" {
  source = "sudoers"
  destination = "/etc/sudoers.d/github"
}
  
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} su -s {{ .Path }} github"
    inline = [
       "cd /home/github",
       "mkdir actions-runner && cd actions-runner",
       "curl -o actions-runner-linux-x64-2.281.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.281.1/actions-runner-linux-x64-2.281.1.tar.gz",
       "echo '04f6c17235d4b29fc1392d5fae63919a96e7d903d67790f81cffdd69c58cb563  actions-runner-linux-x64-2.281.1.tar.gz' | shasum -a 256 -c",
       "tar xzf ./actions-runner-linux-x64-2.281.1.tar.gz",
       "./config.sh --unattended --labels proxmox --url https://github.com/flx5/lmn-packer --token ${var.github_token}"
    ]
  }
  
  provisioner "shell" {
    inline = [
       "cd /home/github/actions-runner/",
       "./svc.sh install github"
    ]
  }
  
  # TODO Provision Github runner
  
    provisioner "shell" {
    only = [ "proxmox-iso.proxmox" ]
    inline = [
      "sed -i \"s/.*$(hostname)/$(hostname -I)\t$(hostname)/\" /etc/hosts",
      "wget https://enterprise.proxmox.com/debian/proxmox-release-bullseye.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg",
      "echo 'deb [arch=amd64] http://download.proxmox.com/debian/pve bullseye pve-no-subscription' > /etc/apt/sources.list.d/pve-install-repo.list",
      "echo '7fb03ec8a1675723d2853b84aa4fdb49a46a3bb72b9951361488bfd19b29aab0a789a4f8c7406e71a69aabbc727c936d3549731c4659ffa1a08f44db8fdcebfa  /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg' | sha512sum -c -",
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y",
      "echo 'postfix postfix/main_mailer_type select No configuration' | debconf-set-selections",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y proxmox-ve postfix open-iscsi isc-dhcp-server",
      "apt-get remove -y os-prober",
      "pvesm set local -content images,snippets,rootdir,backup,iso,vztmpl"
    ]
  }
  
  provisioner "file" {
  only = [ "proxmox-iso.proxmox" ]
  source = "proxmox_iface"
  destination = "/etc/network/interfaces"
}

  provisioner "file" {
  only = [ "proxmox-iso.proxmox" ]
  source = "isc-dhcp-server"
  destination = "/etc/default/isc-dhcp-server"
}

  provisioner "file" {
  only = [ "proxmox-iso.proxmox" ]
  source = "dhcpd.conf"
  destination = "/etc/dhcp/dhcpd.conf"
}

}


