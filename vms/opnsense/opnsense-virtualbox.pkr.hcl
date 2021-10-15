locals {
   virtualbox = {
     output_dir = "output/opnsense-virtualbox/"
   
     output_vmdk = "output/opnsense-virtualbox/packer-opnsense-virtualbox.vmdk"
     ovf_template = "${path.root}/virtualbox/packer-opnsense-virtualbox.ovf"
   }
}

source "qemu" "opnsense-virtualbox" {
  disk_image = true
  use_backing_file = true
  
  iso_url          = "${local.opnsense.output_dir}/packer-opnsense"
  iso_checksum = "file:${local.opnsense.output_dir}/packer_opnsense_sha256.checksum"

  output_directory = local.virtualbox.output_dir

  headless = "${var.headless}"

  ssh_timeout      = "2m"
  ssh_host         = "10.0.0.254"
  ssh_port         = 22
  ssh_username     = "root"
  ssh_password     = var.ssh_password
  skip_nat_mapping = true

  shutdown_command = "shutdown -p now"

  qemuargs = [
    # Wan
    ["-netdev", "user,id=user.0,net=${var.red_network}"],
    ["-device", "virtio-net,netdev=user.0"],

    # Lan
    ["-netdev", "bridge,id=user.1,br=${var.qemu_bridge}"],
    ["-device", "virtio-net,netdev=user.1"]
  ]
}

build {
  sources = ["qemu.opnsense-virtualbox"]

  provisioner "shell" {
    # FreeBSD uses tcsh
    execute_command = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"

    inline = [
      "sed -i '' 's/vtbd0/ada0/' /etc/fstab",
      "sed -i '' 's/vtnet0/em0/' /conf/config.xml",
      "sed -i '' 's/vtnet1/em1/' /conf/config.xml",
      "pkg install -y os-virtualbox"
    ]
  }
  post-processors {
    post-processor "shell-local" {
      inline = ["qemu-img convert -f qcow2 -O vmdk ${local.virtualbox.output_dir}/packer-opnsense-virtualbox ${local.virtualbox.output_vmdk}"]
    }

    post-processor "artifice" {
      files = [
        local.virtualbox.output_vmdk
      ]
    }

    post-processor "shell-local" {
      inline = [
        "python3 tools/scripts/convert.py -d ${local.virtualbox.output_vmdk} -t ${local.virtualbox.ovf_template} -o ${local.virtualbox.output_dir}/packer-opnsense-virtualbox.ovf"
      ]
    }

    post-processor "checksum" {
      checksum_types = ["sha256"]
      output         = "${local.virtualbox.output_dir}/packer_{{.BuildName}}_{{.ChecksumType}}.checksum"
    }
  }

  # Afer import run vboxmanage modifyvm packer-opnsense --natnet1 "192.168.122/24" to fix the wan address range
}

source "virtualbox-ovf" "opnsense-virtualbox-test" {
  source_path = "output-opnsense-virtualbox/packer-opnsense-virtualbox.ovf"

  # For some weird reason packer keeps overwriting the ssh_host with 127.0.0.1.
  # The workaround connects to the target as a fake "bastion host" and then packer can use the loopback device...

  ssh_host         = "127.0.0.1"
  ssh_port         = 22
  ssh_timeout      = "20m"
  skip_nat_mapping = true

  ssh_username         = "root"
  ssh_password         = var.ssh_password
  ssh_bastion_host     = "10.0.0.254"
  ssh_bastion_username = "root"
  ssh_bastion_password = var.ssh_password

  shutdown_command     = "shutdown -p now"
  guest_additions_mode = "disable"

  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--natnet1", var.red_network]
    # TODO Specify interface for lan
  ]

  format = "ova"
}

build {
  sources = ["sources.virtualbox-ovf.opnsense-virtualbox-test"]
}
