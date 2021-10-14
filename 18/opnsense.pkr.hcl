packer {
  required_plugins {
   xenserver= {
      version = "= v0.3.3-dev7"
      source = "github.com/flx5/xenserver"
    }
  }
}

# TODO Correct memory / disk size

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

  sources = {
    "virtualbox-iso" = {
      wan_iface   = "em0"
      lan_iface   = "em1"
      packages    = "os-virtualbox"
      wan_configure = "dhclient -l /tmp/dhclient.lease.wan_iface em0<enter><wait10>"
      partitions = "ada0"
    }
  }
  }
}

source "virtualbox-iso" "opnsense" {
  guest_os_type = "FreeBSD_64"

  iso_url      = local.opnsense.iso_url
  iso_checksum = "${local.opnsense.iso_checksum_type}:${local.opnsense.iso_checksum}"

  guest_additions_mode = "disable"
  headless             = "${var.headless}"
  keep_registered      = var.vbox_keep_registered

  # TODO Correct memory / disk size
  memory = local.opnsense.memory
  # 25 GB
  disk_size = 25600

  boot_wait = "5s"

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

  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--nic2", "hostonly", "--hostonlyadapter2", var.vbox_internal_net],
    ["modifyvm", "{{.Name}}", "--paravirtprovider", "kvm"]
  ]
}

source "virtualbox-ovf" "opnsense-qemu" {
  checksum = "none"
  source_path  = "output-opnsense/packer-opnsense-1634205698.ovf"

  guest_additions_mode = "disable"
  headless             = "${var.headless}"
  keep_registered      = var.vbox_keep_registered


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

  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--nic2", "hostonly", "--hostonlyadapter2", var.vbox_internal_net],
    ["modifyvm", "{{.Name}}", "--paravirtprovider", "kvm"]
  ]
}


build {
   sources = ["virtualbox-ovf.opnsense-qemu"]
   
  provisioner "shell" {
    # FreeBSD uses tcsh
    execute_command = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"

    inline = [
      "sed -i '' 's/ada0/vtbd0/' /etc/fstab",
      "sed -i '' 's/em0/vtnet0/' /conf/config.xml",
      "sed -i '' 's/em1/vtnet1/' /conf/config.xml"
    ]
  }
  
  /*
   qemu-img convert output-opnsense-qemu/packer-opnsense-qemu-1634209661-disk001.vmdk output-opnsense-qemu/disk001.qcow2 -O qcow2
  qemu-system-x86_64 -snapshot -machine type=pc,accel=kvm -m 4096 -drive file=output-opnsense-qemu/disk001.qcow2,if=virtio,cache=writeback,discard=ignore,format=qcow2 -netdev user,id=user.0,net=192.168.122.0/24,dhcpstart=192.168.122.9,hostfwd=tcp::0-:22,hostfwd=tcp::0-:443  -device virtio-net,netdev=user.0 -netdev user,id=user.1,net=10.0.0.0/8 -device virtio-net,netdev=user.1
  */
}

build {

  dynamic "source" {
    for_each = local.opnsense.sources

    labels = ["${source.key}.opnsense"]

    content {
      name = "opnsense"
    
      boot_command = [
        # Exit menu
        "<esc><wait>",
        # Enter boot sequence
        "boot -s<enter>",
        "<wait10s>",
        "/bin/sh<enter><wait>",
        "mdmfs -s 100m md1 /tmp<enter><wait>",
        "mdmfs -s 100m md2 /mnt<enter><wait>",
        source.value.wan_configure,
        "fetch -o /tmp/installerconfig http://{{ .HTTPIP }}:{{ .HTTPPort }}/installerconfig && bsdinstall script /tmp/installerconfig<enter>"
      ]

      http_content = {
        "/config.xml" = templatefile("opnsense/config.xml", {
          root_pw_hash = bcrypt(local.opnsense.root_password),
          wan_iface    = source.value.wan_iface,
          lan_iface    = source.value.lan_iface
          }),
        "/installerconfig" = templatefile("opnsense/installerconfig.pkrtpl.hcl", { 
                                   root_pw = local.opnsense.root_password, 
                                   wan_iface = source.value.wan_iface, 
                                   lan_iface = source.value.lan_iface, 
                                   partitions =  source.value.partitions
                             })
      }
    }
  }
  
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
      "fetch -o /conf/config.xml http://${build.PackerHTTPAddr}/config.xml"
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
}


