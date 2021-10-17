locals {
  server = {
    root_password = "Muster!"
    output_dir    = "output/server"
  }
}

variable "qemu_bridge" {
  type    = string
  default = "virbr5"
}

variable "headless" {
  type    = string
  default = "false"
}

source "qemu" "server" {
  iso_url      = "http://old-releases.ubuntu.com/releases/bionic/ubuntu-18.04.5-server-amd64.iso"
  iso_checksum = "sha256:8c5fc24894394035402f66f3824beb7234b757dd2b5531379cb310cedfdf0996"

  headless = var.headless

  memory = 1024

  disk_size = "25G"
  disk_additional_size = [
    "100G"
  ]

  boot_wait = "5s"

  ssh_timeout  = "30m"
  ssh_username = "root"
  ssh_password = local.server.root_password

  shutdown_command = "shutdown -P now"

  output_directory = local.server.output_dir

  net_bridge = var.qemu_bridge

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

  http_content = {
    "/preseed.cfg" = templatefile("preseed.pkrtpl.hcl", { root_pw = local.server.root_password, installs = [] })
  }
}

build {
  sources = ["sources.qemu.server"]

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

      "linuxmuster-prepare --initial -u -p server -l /dev/vdb",
      "reboot"
    ]
  }
}

