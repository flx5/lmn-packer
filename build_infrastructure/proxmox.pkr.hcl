locals {
  memory        = 4096
  root_password = "Muster!"
}

packer {
  required_plugins {
    myproxmox = {
      version = ">= 1.0.2"
      source = "github.com/hashicorp/proxmox"
    }
  }
}


source "myproxmox-proxmox-clone" "proxmox" {
  proxmox_url              = "https://${var.proxmox_host}/api2/json"
  username                 = var.proxmox_user
  password                 = var.proxmox_password
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node
  
  # Clone can take some time (if full)
  task_timeout           = "10m"
  
  # TODO For testing this is faster, but for production?
  full_clone             = false

  vm_name = "proxmox"

  template_description = "Proxmox Template"
  qemu_agent           = "true"

  clone_vm               = "debian-template"

  memory   = local.memory
  cpu_type = "host"
  cores    = 2
  sockets  = 2

  os = "l26"

  onboot      = true

  ssh_timeout  = "10000s"
  ssh_username = "root"
  ssh_password = local.root_password

}

build {
  sources = ["sources.myproxmox-proxmox-clone.proxmox"]
  
  provisioner "shell" {
    inline = [
      "wget https://enterprise.proxmox.com/debian/proxmox-release-bullseye.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg",
      "echo 'deb [arch=amd64] http://download.proxmox.com/debian/pve bullseye pve-no-subscription' > /etc/apt/sources.list.d/pve-install-repo.list",
      "echo '7fb03ec8a1675723d2853b84aa4fdb49a46a3bb72b9951361488bfd19b29aab0a789a4f8c7406e71a69aabbc727c936d3549731c4659ffa1a08f44db8fdcebfa  /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg' | sha512sum -c -",
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y",
      "echo 'postfix postfix/main_mailer_type select No configuration' | debconf-set-selections",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y proxmox-ve postfix open-iscsi ifupdown2",
      "apt-get remove -y os-prober",
      "pvesm set local -content images,snippets,rootdir,backup,iso,vztmpl"
    ]
  }
}


