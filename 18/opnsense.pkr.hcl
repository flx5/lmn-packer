packer {
  required_plugins {
   xenserver= {
      version = "= v0.3.3-dev7"
      source = "github.com/flx5/xenserver"
    }
  }
}

  # FreeBSD Version should match with the opnsense version
  # Typically that information can be found at https://opnsense.org/blog/

locals {
  opnsense = {
  root_password = "Muster!"
  iso_url       = "https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/12.2/FreeBSD-12.2-RELEASE-amd64-disc1.iso"
  iso_checksum  = "289522e2f4e1260859505adab6d7b54ab83d19aeb147388ff7e28019984da5dc"
  iso_checksum_type = "sha256"

  memory        = 1024
  opnsense_release = "21.7"
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

source "qemu" "opnsense" {
  iso_url      = local.opnsense.iso_url
  iso_checksum = "${local.opnsense.iso_checksum_type}:${local.opnsense.iso_checksum}"

  headless             = "${var.headless}"

  # TODO Correct memory / disk size
  memory = local.opnsense.memory
  # 25 GB
  disk_size = 25600

  boot_wait = "5s"

  ssh_timeout      = "20m"
  ssh_host   = "10.0.0.254"
  ssh_port   = 22
  ssh_username         = "root"
  ssh_password         = local.opnsense.root_password
  skip_nat_mapping = true

  shutdown_command = "shutdown -p now"

  qemuargs = [
    # Wan
    [ "-netdev", "user,id=user.0,net=${var.red_network}"],
    [ "-device", "virtio-net,netdev=user.0" ],
    
    # Lan
    [ "-netdev", "bridge,id=user.1,br=${var.qemu_bridge}"],
    [ "-device", "virtio-net,netdev=user.1"]
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
        "fetch -o /tmp/installerconfig http://${cidrhost(var.red_network,2)}:{{ .HTTPPort }}/installerconfig && bsdinstall script /tmp/installerconfig<enter>"
      ]

      http_content = {
        "/config.xml" = templatefile("opnsense/config.xml", {
          root_pw_hash = bcrypt(local.opnsense.root_password),
          wan_iface    = "vtnet0",
          lan_iface    = "vtnet1"
          }),
        "/installerconfig" = templatefile("opnsense/installerconfig.pkrtpl.hcl", { 
                                   root_pw = local.opnsense.root_password, 
                                   wan_iface = "vtnet0", 
                                   lan_iface = "vtnet1", 
                                   partitions =  "vtbd0"
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
      "fetch -o /conf/config.xml http://${cidrhost(var.red_network,2)}:${build.PackerHTTPPort}/config.xml"
    ]
  }
  

  # Reboot manually because we deactivated it after bootstrap.
  provisioner "shell" {
    # FreeBSD uses tcsh
    execute_command = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"
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
    output = "output-opnsense/packer_{{.BuildName}}_{{.ChecksumType}}.checksum"
  }
}



source "qemu" "opnsense-virtualbox" {
  disk_image = true
  
  use_backing_file = true
  iso_url = "output-opnsense/packer-opnsense"
  
  iso_checksum = "file:output-opnsense/packer_opnsense_sha256.checksum"

  headless             = "${var.headless}"

  ssh_timeout      = "2m"
  ssh_host   = "10.0.0.254"
  ssh_port   = 22
  ssh_username         = "root"
  ssh_password         = local.opnsense.root_password
  skip_nat_mapping = true

  shutdown_command = "shutdown -p now"

  qemuargs = [
    # Wan
    [ "-netdev", "user,id=user.0,net=${var.red_network}"],
    [ "-device", "virtio-net,netdev=user.0" ],
    
    # Lan
    [ "-netdev", "bridge,id=user.1,br=${var.qemu_bridge}"],
    [ "-device", "virtio-net,netdev=user.1"]
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
        inline = ["qemu-img convert -f qcow2 -O vmdk output-opnsense-virtualbox/packer-opnsense-virtualbox output-opnsense-virtualbox/packer-opnsense-virtualbox.vmdk"]
   }
   
   post-processor "artifice" {
       files = [
          "output-opnsense-virtualbox/packer-opnsense-virtualbox.vmdk"
       ]
   }
  
   post-processor "shell-local" {
        inline = [
          "python3 tools/scripts/convert.py -d output-opnsense-virtualbox/packer-opnsense-virtualbox.vmdk -t  hypervisor/virtualbox/packer-opnsense-virtualbox.ovf -o output-opnsense-virtualbox/packer-opnsense-virtualbox.ovf"
         ]
   }
  
   post-processor "checksum" {
    checksum_types = ["sha256"]
    output = "output-opnsense-virtualbox/packer_{{.BuildName}}_{{.ChecksumType}}.checksum"
  }
  }
  
  # Afer import run vboxmanage modifyvm packer-opnsense --natnet1 "192.168.122/24" to fix the wan address range
}

# Don't run this on the same host as qemu because virtualbox requires own internal network bridge.
source "virtualbox-ovf" "opnsense-virtualbox-test" {
  source_path = "output-opnsense-virtualbox/packer-opnsense-virtualbox.ovf"

  # For some weird reason packer keeps overwriting the ssh_host with 127.0.0.1.
  # The workaround connects to the target as a fake "bastion host" and then packer can use the loopback device...

  ssh_host         = "127.0.0.1"
  ssh_port         = 22
  ssh_timeout      = "20m"
  skip_nat_mapping = true

  ssh_username         = "root"
  ssh_password         = local.opnsense.root_password
  ssh_bastion_host     = "10.0.0.254"
  ssh_bastion_username = "root"
  ssh_bastion_password = local.opnsense.root_password

  shutdown_command = "shutdown -p now"
  guest_additions_mode = "disable"
  
  vboxmanage = [
    # TODO Respect red network config
    ["modifyvm", "{{.Name}}", "--natnet1", "192.168.122/24"]
  ]
  
  format = "ova"
}

build {
  sources = ["sources.virtualbox-ovf.opnsense-virtualbox-test"]
}


source "qemu" "opnsense-qemu" {
  disk_image = true
  use_backing_file = true
  iso_url = "output-opnsense/packer-opnsense"
  
  iso_checksum = "file:output-opnsense/packer_opnsense_sha256.checksum"

  headless             = "${var.headless}"

  ssh_timeout      = "2m"
  ssh_host   = "10.0.0.254"
  ssh_port   = 22
  ssh_username         = "root"
  ssh_password         = local.opnsense.root_password
  skip_nat_mapping = true

  shutdown_command = "shutdown -p now"

  qemuargs = [
    # Wan
    [ "-netdev", "user,id=user.0,net=${var.red_network}"],
    [ "-device", "virtio-net,netdev=user.0" ],
    
    # Lan
    [ "-netdev", "bridge,id=user.1,br=${var.qemu_bridge}"],
    [ "-device", "virtio-net,netdev=user.1"]
  ]
}


build {
   sources = ["qemu.opnsense-qemu"]
   
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
        inline = ["qemu-img convert -f qcow2 -O qcow2 output-opnsense-qemu/packer-opnsense-qemu output-opnsense-qemu/packer-opnsense-qemu.qcow2"]
   }
   
   post-processor "artifice" {
       files = [
          "output-opnsense-qemu/packer-opnsense-qemu.qcow2"
       ]
   }
  
   post-processor "checksum" {
    checksum_types = ["sha256"]
    output = "output-opnsense-qemu/packer_{{.BuildName}}_{{.ChecksumType}}.checksum"
  }
  }
  
  
  /*
   qemu-system-x86_64 -snapshot -machine type=pc,accel=kvm -m 4096 -drive file=output-opnsense-qemu/packer-opnsense-qemu,if=virtio,cache=writeback,discard=ignore,format=qcow2 -netdev user,id=user.0,net=192.168.122.0/24  -device virtio-net,netdev=user.0 -netdev bridge,id=user.1,br=virbr5 -device virtio-net,netdev=user.1
  */
}


source "qemu" "opnsense-xen" {
  disk_image = true
  use_backing_file = true
  iso_url = "output-opnsense/packer-opnsense"
  
  iso_checksum = "file:output-opnsense/packer_opnsense_sha256.checksum"

  headless             = "${var.headless}"

  ssh_timeout      = "2m"
  ssh_host   = "10.0.0.254"
  ssh_port   = 22
  ssh_username         = "root"
  ssh_password         = local.opnsense.root_password
  skip_nat_mapping = true

  shutdown_command = "shutdown -p now"

  qemuargs = [
    # Wan
    [ "-netdev", "user,id=user.0,net=${var.red_network}"],
    [ "-device", "virtio-net,netdev=user.0" ],
    
    # Lan
    [ "-netdev", "bridge,id=user.1,br=${var.qemu_bridge}"],
    [ "-device", "virtio-net,netdev=user.1"]
  ]
}


build {
   sources = ["qemu.opnsense-xen"]
   
  provisioner "shell" {
    # FreeBSD uses tcsh
    execute_command = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"

    inline = [
      "sed -i '' 's/vtbd0/ada0/' /etc/fstab",
      "sed -i '' 's/vtnet0/xn0/' /conf/config.xml",
      "sed -i '' 's/vtnet1/xn1/' /conf/config.xml",
      "pkg install -y os-xen"
    ]
  }
  
  post-processors {
   post-processor "shell-local" {
        inline = [
        "qemu-img convert -f qcow2 -O raw output-opnsense-xen/packer-opnsense-xen output-opnsense-xen/packer-opnsense-xen.raw",
        "mkdir 'output-opnsense-xen/Ref:37/'",
        "./tools/xva-img/xva-img -p disk-import 'output-opnsense-xen/Ref:37/' output-opnsense-xen/packer-opnsense-xen.raw",
        "python3 tools/scripts/convert.py -d output-opnsense-xen/packer-opnsense-xen.raw -t hypervisor/xen/ova.xml -o output-opnsense-xen/ova.xml",
        "./tools/xva-img/xva-img -p package output-opnsense-xen/lmn7-opnsense.xva output-opnsense-xen/ova.xml 'output-opnsense-xen/Ref:37/'"
        ]
   }
   
   post-processor "artifice" {
       files = [
          "output-opnsense-xen/lmn7-opnsense.xva"
       ]
   }
  
   post-processor "checksum" {
    checksum_types = ["sha256"]
    output = "output-opnsense-xen/packer_{{.BuildName}}_{{.ChecksumType}}.checksum"
  }
  }
  
  
  /*
   qemu-system-x86_64 -snapshot -machine type=pc,accel=kvm -m 4096 -drive file=output-opnsense-qemu/packer-opnsense-qemu,if=virtio,cache=writeback,discard=ignore,format=qcow2 -netdev user,id=user.0,net=192.168.122.0/24  -device virtio-net,netdev=user.0 -netdev bridge,id=user.1,br=virbr5 -device virtio-net,netdev=user.1
  */
}
