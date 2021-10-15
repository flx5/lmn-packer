# FreeBSD Version should match with the opnsense version
# Typically that information can be found at https://opnsense.org/blog/

locals {
  opnsense = {
    iso_url           = "https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/12.2/FreeBSD-12.2-RELEASE-amd64-disc1.iso"
    iso_checksum      = "sha256:289522e2f4e1260859505adab6d7b54ab83d19aeb147388ff7e28019984da5dc"

    opnsense_release = "21.7"
  }
}

variable "ssh_password" {
  type    = string
  default = "Muster!"
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

source "qemu" "opnsense" {
  iso_url      = local.opnsense.iso_url
  iso_checksum = local.opnsense.iso_checksum

  headless = var.headless

  memory = 1024
  # 25 GB
  disk_size = 25600

  boot_wait = "5s"

  ssh_timeout      = "20m"
  ssh_host         = "10.0.0.254"
  ssh_port         = 22
  ssh_username     = "root"
  ssh_password     = var.ssh_password
  skip_nat_mapping = true

  shutdown_command = "shutdown -p now"
  
  output_directory = "output/opnsense/"

  qemuargs = [
    # Wan
    ["-netdev", "user,id=user.0,net=${var.red_network}"],
    ["-device", "virtio-net,netdev=user.0"],

    # Lan
    ["-netdev", "bridge,id=user.1,br=${var.qemu_bridge}"],
    ["-device", "virtio-net,netdev=user.1"]
  ]

  boot_command = [
    # Exit menu
    "<esc><wait>",
    # Enter boot sequence
    "boot -s<enter>",
    "<wait20s>",
    "/bin/sh<enter><wait>",
    "mdmfs -s 100m md1 /tmp<enter><wait>",
    "mdmfs -s 100m md2 /mnt<enter><wait>",
    "dhclient -l /tmp/dhclient.lease.wan_iface vtnet0<enter><wait10>",
    "fetch -o /tmp/installerconfig http://${cidrhost(var.red_network, 2)}:{{ .HTTPPort }}/installerconfig && bsdinstall script /tmp/installerconfig<enter>"
  ]

  http_content = {
    "/config.xml" = templatefile("http/config.xml", {
      root_pw_hash = bcrypt(var.root_password),
      wan_iface    = "vtnet0",
      lan_iface    = "vtnet1"
    }),
    "/installerconfig" = templatefile("http/installerconfig.pkrtpl.hcl", {
      root_pw    = var.root_password,
      wan_iface  = "vtnet0",
      lan_iface  = "vtnet1",
      partitions = "vtbd0"
    })
  }
}


build {

  sources = ["qemu.opnsense"]

  provisioner "shell" {
    # FreeBSD uses tcsh
    execute_command = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"

    inline = [
      "env ASSUME_ALWAYS_YES=YES pkg install ca_root_nss",
      "fetch https://raw.githubusercontent.com/opnsense/update/master/src/bootstrap/opnsense-bootstrap.sh.in",
      "echo 'Installing OpnSense ${local.opnsense.opnsense_release}'",
      # Disable reboot
      "sed -i '' 's/reboot//' opnsense-bootstrap.sh.in",
      "sh ./opnsense-bootstrap.sh.in -r ${local.opnsense.opnsense_release} -y",
      # Write config after running bootstrap because bootstrap would delete the
      "mkdir -p /conf",
      "fetch -o /conf/config.xml http://${cidrhost(var.red_network, 2)}:${build.PackerHTTPPort}/config.xml"
    ]
  }


  # Reboot manually because we deactivated it after bootstrap.
  provisioner "shell" {
    # FreeBSD uses tcsh
    execute_command   = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"
    expect_disconnect = true

    inline = [
      "reboot"
    ]
  }

  provisioner "shell" {
    # FreeBSD uses tcsh
    execute_command = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"

    inline = [
      # Run fsck offline only, otherwise ssh is available while running fsck...
      "echo 'fsck_y_enable=\"YES\"' >> /etc/rc.conf",
      "echo 'background_fsck=\"NO\"' >> /etc/rc.conf",
      "echo 'keymap=\"de.noacc.kbd\"' >> /etc/rc.conf"
    ]
  }

  post-processor "checksum" {
    checksum_types = ["sha256"]
    output         = "output/opnsense/packer_{{.BuildName}}_{{.ChecksumType}}.checksum"
  }
}
