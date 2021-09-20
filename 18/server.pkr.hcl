locals {
server = {
  iso_url       = "http://old-releases.ubuntu.com/releases/bionic/ubuntu-18.04.5-server-amd64.iso"
  iso_checksum  = "sha256:8c5fc24894394035402f66f3824beb7234b757dd2b5531379cb310cedfdf0996"
  memory        = 4096
  root_password = "Muster!"

  boot_command = [
    "<esc><esc><wait5><enter><wait5>",
    "/install/vmlinuz noapic ",
    "initrd=/install/initrd.gz ",
    "debian-installer/locale=en_US keymap=de hostname=server ",
    "netcfg/disable_autoconfig=true netcfg/get_nameservers=1.1.1.1 ",
    "netcfg/get_ipaddress=10.0.0.1 netcfg/get_netmask=255.255.255.0 ",
    "netcfg/get_gateway=10.0.0.254 netcfg/confirm_static=true ",
    "netcfg/get_domain=linuxmuster.lan ",
    "preseed/url=http://{{ .HTTPIP }}:{{.HTTPPort}}/preseed.cfg -- <enter>"
  ]
}
}

packer {
  required_version = ">= 1.7.4"
}

source "proxmox-iso" "server" {
  proxmox_url              = "https://${var.proxmox_host}/api2/json"
  username                 = var.proxmox_user
  password                 = var.proxmox_password
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  vm_id   = 201
  vm_name = "lmn7-server"

  template_description = "Linuxmuster.net Server Appliance"
  qemu_agent           = "true"

  iso_url          = local.server.iso_url
  iso_checksum     = local.server.iso_checksum
  iso_storage_pool = "${var.proxmox_iso_pool}"

  memory   = local.server.memory
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

  disks {
    storage_pool      = var.proxmox_disk_pool
    storage_pool_type = var.proxmox_disk_pool_type
    disk_size         = "100G"
    format            = var.proxmox_disk_format
  }

  unmount_iso = true
  onboot      = true

  boot_wait = "5s"
  boot_command = local.server.boot_command

  http_content = {
    "/preseed.cfg" = templatefile("preseed.pkrtpl.hcl", { root_pw = local.server.root_password, installs = ["qemu-guest-agent"] })
  }

  ssh_timeout  = "20m"
  ssh_username = "root"
  ssh_password = local.server.root_password

  network_adapters {
    bridge = "vmbr1"
    model  = "virtio"
  }
}

source "virtualbox-iso" "server" {
  guest_os_type = "Ubuntu_64"
  iso_url       = local.server.iso_url
  iso_checksum  = local.server.iso_checksum

  shutdown_command     = "shutdown -P now"
  guest_additions_mode = "disable"
  headless             = "${var.headless}"
  keep_registered      = var.vbox_keep_registered

  memory = local.server.memory
  # 25 GB
  disk_size = 25600

  # 100 GB
  disk_additional_size = [102400]
  
  boot_command = local.server.boot_command

  boot_wait = "5s"

  http_content = {
    "/preseed.cfg" = templatefile("preseed.pkrtpl.hcl", { root_pw = local.server.root_password, installs = [] })
  }

  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--nic1", "hostonly", "--hostonlyadapter1", var.vbox_internal_net]
  ]
  
  # For some weird reason packer keeps overwriting the ssh_host with 127.0.0.1.
  # The workaround connects to the target as a fake "bastion host" and then packer can use the loopback device...
  
  ssh_host = "127.0.0.1"
  ssh_port = 22
  ssh_timeout = "20m"
  skip_nat_mapping = true
  
  ssh_username         = "root"
  ssh_password         = local.server.root_password
  ssh_bastion_host = "10.0.0.1"
  ssh_bastion_username = "root"
  ssh_bastion_password = local.server.root_password
}

build {
  sources = ["sources.proxmox-iso.server", "sources.virtualbox-iso.server"]

  provisioner "shell" {
    # Network is restarted by linuxmuster-prepare
    expect_disconnect = true

    inline = [
      "wget -O- http://pkg.linuxmuster.net/archive.linuxmuster.net.key | apt-key add -",
      "wget https://archive.linuxmuster.net/lmn7/lmn7.list -O /etc/apt/sources.list.d/lmn7.list",
      "apt-get clean",
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get -y purge lxd lxd-client lxcfs lxc-common snapd",
      "DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y  linuxmuster-prepare",

      "linuxmuster-prepare --initial -u -p server -l /dev/sdb",
      "reboot"
    ]
  }
}

