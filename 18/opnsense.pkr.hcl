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

    "proxmox-iso" = {
      wan_iface = "vtnet0"
      lan_iface = "vtnet1"
      packages  = "os-qemu-guest-agent"

      wan_configure = "dhclient -l /tmp/dhclient.lease.wan_iface vtnet0<enter><wait10>"
      partitions = "da0"
    }
    
    # TODO Fix these values
    "xenserver-iso" = {
      wan_iface = "xn0"
      lan_iface = "xn1"
      packages  = "os-xen"

      wan_configure = "dhclient -l /tmp/dhclient.lease.wan_iface xn0<enter><wait10>"
      partitions = "ada0"
    }
  }
  }
}

source "proxmox-iso" "opnsense" {
  proxmox_url              = "https://${var.proxmox_host}/api2/json"
  username                 = var.proxmox_user
  password                 = var.proxmox_password
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  vm_id   = 200
  vm_name = "lmn7-opnsense"

  template_description = "Linuxmuster.net OPNSense Appliance"
  qemu_agent           = "true"

  iso_url          = local.opnsense.iso_url
  iso_checksum     = "${local.opnsense.iso_checksum_type}:${local.opnsense.iso_checksum}"
  iso_storage_pool = "${var.proxmox_iso_pool}"

  # TODO Correct memory / disk size
  memory = local.opnsense.memory

  cpu_type = "host"
  cores    = 2
  sockets  = 2

  os = "l26"

  scsi_controller = "virtio-scsi-pci"

  disks {
    storage_pool      = "${var.proxmox_disk_pool}"
    storage_pool_type = "${var.proxmox_disk_pool_type}"
    disk_size         = "25G"
    format            = var.proxmox_disk_format
  }

  unmount_iso = true
  onboot      = true

  boot_wait = "5s"

  ssh_timeout  = "20m"
  ssh_host         = "10.0.0.254"
  ssh_username = "root"
  ssh_password = local.opnsense.root_password

  ssh_bastion_host     = "127.0.0.1"
  ssh_bastion_port     = 2222
  ssh_bastion_username = "root"
  ssh_bastion_password = local.opnsense.root_password

  network_adapters {
    bridge = "vmbr0"
    model  = "virtio"
  }

  network_adapters {
    bridge = "vmbr1"
    model  = "virtio"
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

source "xenserver-iso" "opnsense" { 
  remote_host = var.xen_host
  remote_port = var.xen_api_port
  remote_ssh_port = var.xen_ssh_port
  remote_username = var.xen_user
  remote_password = var.xen_password
  
  vm_name = "opnsense"

  # Xenserver doesn't have an FreeBSD template
  clone_template = "Other install media"

  iso_url      = local.opnsense.iso_url
  iso_checksum     = "${local.opnsense.iso_checksum_type}:${local.opnsense.iso_checksum}"
  
  tools_iso_name = "guest-tools.iso"
  
  
  # TODO Correct memory / disk size / cores
  vm_memory = local.opnsense.memory

  # 25 GB
  disk_size = 25600

  boot_wait = "1m"

  ssh_username         = "root"
  ssh_password         = local.opnsense.root_password
  ssh_host         = "10.0.0.254"

  shutdown_command = "shutdown -p now"
  ssh_timeout = "30m"
  
  sr_iso_name = "Local storage"
  sr_name = "Local storage"
  
  network_names = [
   "Red",
   "Green"
  ]
  
  keep_vm = var.xcp_keep
}

build {

  dynamic "source" {
    for_each = local.opnsense.sources

    labels = ["${source.key}.opnsense"]

    content {
      name = "opnsense"
      /*
      boot_command = [
        "<esc><wait>",
        "boot -s<wait>",
        # Wait for quite some time just to be sure (on nested virtualization this is slow...)
        "<enter><wait60><wait60>",
        "/bin/sh<enter><wait>",
        "mdmfs -s 100m md1 /tmp<enter><wait>",
        "mdmfs -s 100m md2 /mnt<enter><wait>",
        source.value.wan_configure,
        "fetch -o /tmp/installerconfig http://{{ .HTTPIP }}:{{ .HTTPPort }}/installerconfig && bsdinstall script /tmp/installerconfig<enter>"
      ]*/
      
      boot_command = [
        "s<wait>",
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
      "pkg install -y ${local.opnsense.sources["${source.type}"].packages}"
    ]
  }

  provisioner "shell" {
    only = [ "proxmox-iso.opnsense" ]
    # FreeBSD uses tcsh
    execute_command = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"

    inline = [
      "echo 'qemu_guest_agent_enable=\"YES\"' >> /etc/rc.conf",
      "echo 'qemu_guest_agent_flags=\"-d -v -l /var/log/qemu-ga.log\"' >> /etc/rc.conf",
      "kldload virtio_console",
      "echo virtio_console_load=\"YES\" >> /boot/loader.conf",
      "service qemu-guest-agent start",
      "service qemu-guest-agent status"
    ]
  }
  
  provisioner "shell" {
    # FreeBSD uses tcsh
    execute_command = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"
    expect_disconnect = true
    
    # Give the system time to come fully up before shutdown
    pause_after = "2m"

    inline = [
      # Run fsck offline only, otherwise ssh is available while running fsck...
      "echo 'fsck_y_enable=\"YES\"' >> /etc/rc.conf",
      "echo 'background_fsck=\"NO\"' >> /etc/rc.conf",
      "echo 'keymap=\"de.noacc.kbd\"' >> /etc/rc.conf",
      # Reboot into configured opnsense
      "reboot"
    ]
  }
}


