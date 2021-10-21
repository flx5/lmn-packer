locals {
  server = {
    root_password = "Muster!"
  }

  builds = {
    server = {
      prepare   = "linuxmuster-prepare --initial --unattended --profile=server --pvdevice=/dev/vdb"
      ip        = "10.0.0.1"
      disk_size = "25G"
      disk_additional_size = [
        "100G"
      ]
    }
    opsi = {
      prepare              = "linuxmuster-prepare --initial --unattended --profile=opsi "
      ip                   = "10.0.0.2"
      disk_size            = "25G"
      disk_additional_size = []
    }
    docker = {
      prepare              = "linuxmuster-prepare --initial --unattended --profile=docker "
      ip                   = "10.0.0.3"
      disk_size            = "25G"
      disk_additional_size = []
    }

  }
}

variable "red_network" {
  type    = string
  default = "192.168.122.0/24"
}

variable "qemu_bridge" {
  type    = string
  default = "virbr5"
}

variable "headless" {
  type    = string
  default = "false"
}

source "qemu" "ubuntu" {
  iso_url      = "http://old-releases.ubuntu.com/releases/bionic/ubuntu-18.04.5-server-amd64.iso"
  iso_checksum = "sha256:8c5fc24894394035402f66f3824beb7234b757dd2b5531379cb310cedfdf0996"

  headless = var.headless

  memory = 1024

  boot_wait = "5s"

  ssh_timeout  = "30m"
  ssh_username = "root"
  ssh_password = local.server.root_password

  shutdown_command = "shutdown -P now"

  skip_nat_mapping = true

  http_content = {
    "/preseed.cfg" = templatefile("preseed.pkrtpl.hcl", { root_pw = local.server.root_password, installs = [] })
  }
  
  qemuargs = [
    ["-netdev", "bridge,id=lan,br=${var.qemu_bridge}"],
    ["-device", "virtio-net,netdev=lan"]
  ]
}

build {
  dynamic "source" {
    for_each = local.builds
    labels   = ["qemu.ubuntu"]

    content {
      name = source.key
      
      ssh_host = source.value.ip

      disk_size            = source.value.disk_size
      disk_additional_size = source.value.disk_additional_size

      output_directory = "output/${source.key}"

      boot_command = [
        "<esc><esc><wait5><enter><wait5>",
        "/install/vmlinuz noapic ",
        "initrd=/install/initrd.gz ",
        "debian-installer/locale=en_US keymap=de hostname=${source.key} ",
        "netcfg/disable_autoconfig=true netcfg/get_nameservers=1.1.1.1 ",
        "netcfg/get_ipaddress=${source.value.ip} netcfg/get_netmask=255.255.255.0 ",
        "netcfg/get_gateway=10.0.0.254 netcfg/confirm_static=true ",
        "netcfg/get_domain=linuxmuster.lan ",
        "preseed/url=http://${cidrhost(var.red_network, 2)}:{{.HTTPPort}}/preseed.cfg -- <enter>"
      ]
    }
  }

  provisioner "shell" {
    # Network is restarted by linuxmuster-prepare
    expect_disconnect = true

    inline = [
      "apt-get clean",
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get -y purge lxd lxd-client lxcfs lxc-common snapd",
      # Upgrade first to make sure we have a current ssl chain.
      "DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade",
      "wget -O- http://pkg.linuxmuster.net/archive.linuxmuster.net.key | apt-key add -",
      "wget https://archive.linuxmuster.net/lmn7/lmn7.list -O /etc/apt/sources.list.d/lmn7.list",
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y  linuxmuster-prepare",
      local.builds[source.name].prepare,
      "reboot"
    ]
  }
  
  post-processor "checksum" {
    checksum_types = ["sha256"]
    output         = "output/${source.name}/packer_${source.name}_{{.ChecksumType}}.checksum"
  }
}

