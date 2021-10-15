locals {
   output_dir = "output/opnsense-xen/"
   input_dir = "output/opnsense/"

   raw_disk = "${local.output_dir}/packer-opnsense-xen.raw"
   ova_template = "${path.root}/ova.xml"
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

source "qemu" "opnsense-xen" {
  disk_image       = true
  use_backing_file = true
  
  iso_url          = "${input_dir}/packer-opnsense"
  iso_checksum = "file:${input_dir}/packer_opnsense_sha256.checksum"
  
  output_directory = local.output_dir

  headless = var.headless

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
  sources = ["qemu.opnsense-xen"]

  provisioner "shell" {
    # FreeBSD uses tcsh
    execute_command = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"

    inline = [
      "sed -i '' 's/vtbd0/ada0/' /etc/fstab",

      # Red is on xn0
      "sed -i '' 's/vtnet0/xn0/' /conf/config.xml",

      # TODO Blue is on xn1


      # Green is on xn2
      "sed -i '' 's/vtnet1/xn2/' /conf/config.xml",
      "pkg install -y os-xen"
    ]
  }

  post-processors {
    post-processor "shell-local" {
      inline = [
        # Convert qcow2 to raw
        "qemu-img convert -f qcow2 -O raw ${local.output_dir}/packer-opnsense-xen ${local.raw_disk}",
        
        # Convert raw to xva disk slices
        "mkdir '${local.output_dir}/Ref:37/'",
        "./tools/xva-img/xva-img -p disk-import '${local.output_dir}/Ref:37/' ${local.raw_disk}",
        
        # Convert the template
        "python3 tools/scripts/convert.py -d ${local.raw_disk} -t ${local.ova_template} -o ${local.output_dir}/ova.xml",
        
        # Create xva
        "./tools/xva-img/xva-img -p package ${local.output_dir}/lmn7-opnsense.xva ${local.output_dir}/ova.xml '${local.output_dir}/Ref:37/'"
      ]
    }

    post-processor "artifice" {
      files = [
        "${local.output_dir}/lmn7-opnsense.xva"
      ]
    }

    post-processor "checksum" {
      checksum_types = ["sha256"]
      output         = "${local.output_dir}/packer_{{.BuildName}}_{{.ChecksumType}}.checksum"
    }
  }
}
