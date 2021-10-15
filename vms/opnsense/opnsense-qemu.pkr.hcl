locals {
   qemu = {
      output_dir = "output/qemu"
   }
}


source "qemu" "qemu" {
  disk_image       = true
  use_backing_file = true
  
  iso_url          = "${local.opnsense.output_dir}/packer-opnsense"
  iso_checksum = "file:${local.opnsense.output_dir}/packer_opnsense_sha256.checksum"
  
  output_directory = local.qemu.output_dir

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
  sources = ["qemu.qemu"]

  provisioner "shell" {
    # FreeBSD uses tcsh
    execute_command = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"

    inline = [
      "pkg install -y os-qemu-guest-agent",
      "echo 'qemu_guest_agent_enable=\"YES\"' >> /etc/rc.conf",
      "echo 'qemu_guest_agent_flags=\"-d -v -l /var/log/qemu-ga.log\"' >> /etc/rc.conf",
      "kldload virtio_console",
      "echo virtio_console_load=\"YES\" >> /boot/loader.conf",
      "service qemu-guest-agent start",
      "service qemu-guest-agent status"
    ]
  }

  post-processors {
    post-processor "shell-local" {
      inline = ["qemu-img convert -f qcow2 -O qcow2 ${local.qemu.output_dir}/packer-qemu ${local.qemu.output_dir}/packer-qemu.qcow2"]
    }

    post-processor "artifice" {
      files = [
        "${local.qemu.output_dir}/packer-qemu.qcow2"
      ]
    }

    post-processor "checksum" {
      checksum_types = ["sha256"]
      output         = "${local.qemu.output_dir}/packer_{{.BuildName}}_{{.ChecksumType}}.checksum"
    }
  }


  /*
   qemu-system-x86_64 -snapshot -machine type=pc,accel=kvm -m 4096 -drive file=output/qemu/packer-qemu,if=virtio,cache=writeback,discard=ignore,format=qcow2 -netdev user,id=user.0,net=192.168.122.0/24  -device virtio-net,netdev=user.0 -netdev bridge,id=user.1,br=virbr5 -device virtio-net,netdev=user.1
  */
}
