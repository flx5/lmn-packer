source "qemu" "ubuntu-qemu" {
  disk_image       = true
  use_backing_file = true

  headless = "${var.headless}"

  ssh_timeout      = "2m"
  ssh_port         = 22
  ssh_username     = "root"
  ssh_password     = local.server.root_password
  skip_nat_mapping = true

  shutdown_command = "shutdown -P now"


}

build {

  dynamic "source" {
    for_each = local.builds
    labels   = ["qemu.ubuntu-qemu"]

    content {
      name = "${source.key}-qemu"

      output_directory = "output/${source.key}-qemu"

      iso_url      = "output/${source.key}/packer-ubuntu"
      iso_checksum = "file:output/${source.key}/packer_ubuntu_sha256.checksum"

      ssh_host = source.value.ip

      qemuargs = concat(source.value.qemu_import, [
        # Lan   
        # Lan must be on bridge because with user network the source address of packer ssh would not be within the correct subnet.

        ["-netdev", "bridge,id=lan,br=${var.qemu_bridge}"],
        ["-device", "virtio-net,netdev=lan"],
        
        ["-drive", "file=output/${source.key}-qemu/packer-${source.key}-qemu,if=virtio,cache=writeback,discard=ignore,format=qcow2"],
      ])

    }
  }


  provisioner "shell" {
    inline = [
      "DEBIAN_FRONTEND=noninteractive apt-get install -y qemu-guest-agent"
    ]
  }

  post-processors {
    post-processor "shell-local" {
      inline = ["qemu-img convert -f qcow2 -O qcow2 output/${source.name}/packer-ubuntu-qemu output/${source.name}/packer-${source.name}.qcow2"]
    }

    post-processor "shell-local" {
      only   = ["qemu.server-qemu"]
      inline = ["qemu-img convert -f qcow2 -O qcow2 output/tmp/packer-server-qemu-1 output/${source.name}/packer-${source.name}-1.qcow2"]
    }

    post-processor "artifice" {
      files = [
        "output/${source.name}/packer-${source.name}.qcow2",
        "output/${source.name}/packer-${source.name}-1.qcow2"
      ]
    }

    post-processor "checksum" {
      checksum_types = ["sha256"]
      output         = "output/${source.name}/packer_{{.BuildName}}_{{.ChecksumType}}.checksum"
    }
  }
}
