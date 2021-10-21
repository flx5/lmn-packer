locals {
   virtualbox = {
     output_dir = "output/server-virtualbox"
     ovf_template = "${path.root}/virtualbox/server-virtualbox.ovf"
   }
}

source "qemu" "server-virtualbox" {
  disk_image       = true
  use_backing_file = true

  headless = "${var.headless}"

  ssh_timeout      = "2m"
  ssh_port         = 22
  ssh_username     = "root"
  ssh_password     = local.server.root_password
  skip_nat_mapping = true

  shutdown_command = "shutdown -P now"

      vm_name = "server-virtualbox"
      
       output_directory = local.virtualbox.output_dir
       
   iso_url      = "output/server/packer-server"
   iso_checksum = "file:output/server/packer_server_sha256.checksum"
   
   ssh_host = "10.0.0.1"
   
      qemuargs =  [
        # Lan   
        # Lan must be on bridge because with user network the source address of packer ssh would not be within the correct subnet.

        ["-netdev", "bridge,id=lan,br=${var.qemu_bridge}"],
        ["-device", "virtio-net,netdev=lan"],
        
        ["-drive", "file=${local.virtualbox.output_dir}/server-virtualbox,if=virtio,cache=writeback,discard=ignore,format=qcow2"],
        ["-drive", "file=output/tmp/packer-server-1,if=virtio,cache=writeback,discard=ignore,format=qcow2"],
      ]
}

build {

  sources = ["qemu.server-virtualbox"]


  provisioner "shell" {
    inline = [
      "DEBIAN_FRONTEND=noninteractive apt-get install -y virtualbox-guest-utils",
      "sed -i 's/ens3/enp0s3/' /etc/netplan/01-netcfg.yaml"
    ]
  }

  post-processors {
    post-processor "shell-local" {
      inline = ["qemu-img convert -f qcow2 -O vmdk ${local.virtualbox.output_dir}/${source.name} ${local.virtualbox.output_dir}/server-virtualbox.vmdk"]
    }

    post-processor "shell-local" {
      only   = ["qemu.server-virtualbox"]
      inline = ["qemu-img convert -f qcow2 -O vmdk output/tmp/packer-server-1 ${local.virtualbox.output_dir}/server-virtualbox-1.vmdk"]
    }

    post-processor "artifice" {
      files = [
        "${local.virtualbox.output_dir}/${source.name}.vmdk",
        "${local.virtualbox.output_dir}/${source.name}-1.vmdk"
      ]
    }
    
    post-processor "shell-local" {
      inline = [
        "python3 tools/scripts/convert.py \\",
        "-d ${local.virtualbox.output_dir}/${source.name}.vmdk ${local.virtualbox.output_dir}/server-virtualbox-1.vmdk \\",
        "-t '${local.virtualbox.ovf_template}' \\",
        "-o ${local.virtualbox.output_dir}/packer-server-virtualbox.ovf"
      ]
    }

    post-processor "checksum" {
      checksum_types = ["sha256"]
      output         = "${local.virtualbox.output_dir}/packer_{{.BuildName}}_{{.ChecksumType}}.checksum"
    }
  }
}
