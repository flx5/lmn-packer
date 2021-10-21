locals {
   opsi-virtualbox = {
     output_dir = "output/opsi-virtualbox"
     ovf_template = "${path.root}/virtualbox/opsi-virtualbox.ovf"
   }
}

source "qemu" "opsi-virtualbox" {
  disk_image       = true
  use_backing_file = true

  headless = "${var.headless}"

  ssh_timeout      = "2m"
  ssh_port         = 22
  ssh_username     = "root"
  ssh_password     = local.server.root_password
  skip_nat_mapping = true

  shutdown_command = "shutdown -P now"

      vm_name = "opsi-virtualbox"
      
       output_directory = local.opsi-virtualbox.output_dir
       
   iso_url      = "output/opsi/packer-opsi"
   iso_checksum = "file:output/opsi/packer_opsi_sha256.checksum"
   
   ssh_host = "10.0.0.2"
   
      qemuargs =  [
        # Lan   
        # Lan must be on bridge because with user network the source address of packer ssh would not be within the correct subnet.

        ["-netdev", "bridge,id=lan,br=${var.qemu_bridge}"],
        ["-device", "virtio-net,netdev=lan"],
      ]
}

build {

  sources = ["qemu.opsi-virtualbox"]


  provisioner "shell" {
    inline = [
      "DEBIAN_FRONTEND=noninteractive apt-get install -y virtualbox-guest-utils",
      "sed -i 's/ens3/enp0s3/' /etc/netplan/01-netcfg.yaml"
    ]
  }

  post-processors {
    post-processor "shell-local" {
      inline = ["qemu-img convert -f qcow2 -O vmdk ${local.opsi-virtualbox.output_dir}/${source.name} ${local.opsi-virtualbox.output_dir}/opsi-virtualbox.vmdk"]
    }

    post-processor "artifice" {
      files = [
        "${local.opsi-virtualbox.output_dir}/opsi-virtualbox.vmdk"
      ]
    }
    
    post-processor "shell-local" {
      inline = [
        "python3 tools/scripts/convert.py \\",
        "-d ${local.opsi-virtualbox.output_dir}/${source.name}.vmdk \\",
        "-t '${local.opsi-virtualbox.ovf_template}' \\",
        "-o ${local.opsi-virtualbox.output_dir}/packer-opsi-virtualbox.ovf"
      ]
    }

    post-processor "checksum" {
      checksum_types = ["sha256"]
      output         = "${local.opsi-virtualbox.output_dir}/packer_{{.BuildName}}_{{.ChecksumType}}.checksum"
    }
  }
}
