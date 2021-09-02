# If this is changed it has to be changed in cidata/user-data too...
variable "sudo_password" {
  type =  string
  default = "Muster!"
  sensitive = true
}

variable "proxmox_host" {
  type =  string
  default = "localhost:8006"
}

variable "proxmox_user" {
  type =  string
  default = "root@pam"
  sensitive = true
}

variable "proxmox_password" {
  type =  string
  default = "vagrant"
  sensitive = true
}

variable "proxmox_node" {
  type =  string
  default = "proxmox"
}

variable "proxmox_iso_pool" {
  type =  string
  default = "local"
}

variable "proxmox_disk_pool" {
  type =  string
  default = "local"
}

variable "proxmox_disk_pool_type" {
  type =  string
  default = "directory"
}

variable "proxmox_disk_format" {
  type =  string
  default = "qcow2"
}


#TODO Template the preseed.cfg so we don't install  qemu-guest-agent on virtualbox

variable "headless" {
  type =  string
  default = "false"
}

source "proxmox-iso" "server" {
  proxmox_url = "https://${var.proxmox_host}/api2/json"
  username = "${var.proxmox_user}"
  password = "${var.proxmox_password}"
  insecure_skip_tls_verify = true
  node = "${var.proxmox_node}"
  
  vm_id = 301
  vm_name = "lmn7-server"
  
  template_description = "Linuxmuster.net Server Appliance"
  qemu_agent = "true"
  
  
  iso_url = "http://cdimage.ubuntu.com/ubuntu/releases/bionic/release/ubuntu-18.04.5-server-amd64.iso"
  iso_checksum = "sha256:8c5fc24894394035402f66f3824beb7234b757dd2b5531379cb310cedfdf0996"
  iso_storage_pool = "${var.proxmox_iso_pool}"
  memory = 1024
  cpu_type = "host"
  cores = 2
  
  os = "l26"
  
  # TODO format seems to be ignored
  disks {
    storage_pool = "${var.proxmox_disk_pool}"
    storage_pool_type = "${var.proxmox_disk_pool_type}"
    disk_size = "25G"
    format = "${var.proxmox_disk_format}"
  }
  
  disks {
    storage_pool = "${var.proxmox_disk_pool}"
    storage_pool_type = "${var.proxmox_disk_pool_type}"
    disk_size = "100G"
    format = "${var.proxmox_disk_format}"
  }
  
  unmount_iso = true
  onboot = true
  
  boot_command = [    
            "<esc><esc><enter><wait>",
            "/install/vmlinuz noapic ",
            "initrd=/install/initrd.gz ",
            "debian-installer/locale=en_US keymap=de hostname=server ",
            "netcfg/disable_autoconfig=true netcfg/get_nameservers=1.1.1.1 ",
            "netcfg/get_ipaddress=10.0.0.1 netcfg/get_netmask=255.255.255.0 ",
            "netcfg/get_gateway=10.0.0.254 netcfg/confirm_static=true ",
            "netcfg/get_domain=linuxmuster.lan ",
            "preseed/url=http://{{ .HTTPIP }}:{{.HTTPPort}}/preseed.cfg -- <enter>"
  ]
  
  boot_wait = "5s"
  
  http_directory = "18/http"
  ssh_timeout = "10000s"
  ssh_username = "linuxadmin"
  ssh_password = "${var.sudo_password}"
  
  # TODO virtio
  # TODO on proxmox one adapter might be enough.
  network_adapters {
    bridge = "vmbr1"
  }
}

source "virtualbox-iso" "server" {
  guest_os_type = "Ubuntu_64"
  iso_url = "http://cdimage.ubuntu.com/ubuntu/releases/bionic/release/ubuntu-18.04.5-server-amd64.iso"
  iso_checksum = "sha256:8c5fc24894394035402f66f3824beb7234b757dd2b5531379cb310cedfdf0996"
  ssh_username = "linuxadmin"
  ssh_password = "${var.sudo_password}"
  shutdown_command = "echo ${var.sudo_password} | sudo -S shutdown -P now"
  guest_additions_mode = "disable"
  headless = "${var.headless}"
  
  memory = 1024
  # 25 GB
  disk_size = 25600
  
  # 100 GB
  disk_additional_size = [ 102400 ]
  
  boot_command = [    
            "<esc><esc><enter><wait>",
            "/install/vmlinuz noapic ",
            "initrd=/install/initrd.gz ",
            "debian-installer/locale=en_US keymap=de hostname=server netcfg/choose_interface=enp0s3 ",
            "preseed/url=http://{{ .HTTPIP }}:{{.HTTPPort}}/preseed.cfg -- <enter>"
  ]
  
  boot_wait = "5s"
  
  http_directory = "18/http"
  ssh_timeout = "10000s"
  
  # TODO Figure out if this can be avoided by using another network type...
  #skip_nat_mapping = true
 ## ssh_port = 2234
  
  # TODO To avoid having an additional nic it might be possible to use an internal network + jumphost + gateway vm
  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--nic2", "nat"],
  #  ["modifyvm", "{{.Name}}", "--intnet2", "internal_lmn"],
    ["modifyvm", "{{.Name}}", "--natnet2", "10.0.0.0/24"],
  #  ["modifyvm", "{{.Name}}", "--natpf2", "packerconn,tcp,127.0.0.1,2234,,22"]
  ]
  
  vboxmanage_post = [
    ["modifyvm", "{{.Name}}", "--nic1", "none"],
    
  ]
}

build {
  # Build a basic box just for test purposes. Would still need to configure network stuff in the below scripts..
  # TODO For provisioning the qemu-guest-agent package has to be installed during installation on proxmox boxes...
  sources = [ "sources.proxmox-iso.server"]
  
  # Post processors won't work -> have to pull manually from proxmox
}

build {
  sources = ["sources.virtualbox-iso.server"]
        # Todo disable autoupdate
      # Todo disable cloud-init
      
  provisioner "file" {
    source = "18/02-packer-before.yaml"
    destination = "/tmp/02-packer-before.yaml"
  }
  
  provisioner "file" {
    source = "18/02-packer-after.yaml"
    destination = "/tmp/02-packer-after.yaml"
  }

  # Initial network configuration
  provisioner "shell" {
      expect_disconnect = true
  
      inline = [
         "rm /etc/netplan/*.yaml",
         "mv /tmp/02-packer-before.yaml /etc/netplan/02-packer.yaml",
         "netplan generate",
         "netplan apply",
      ]
      execute_command = "echo ${var.sudo_password} | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
  }

  provisioner "shell" {
      # Network is restarted by linuxmuster-prepare
      expect_disconnect = true
  
      inline = [
         "wget -O- http://pkg.linuxmuster.net/archive.linuxmuster.net.key | apt-key add -",
         "wget https://archive.linuxmuster.net/lmn7/lmn7.list -O /etc/apt/sources.list.d/lmn7.list",
         "apt-get clean",
         "apt-get update",
         "DEBIAN_FRONTEND=noninteractive apt-get -y purge lxd lxd-client lxcfs lxc-common snapd",
         "DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade",
         "DEBIAN_FRONTEND=noninteractive apt-get install -y  linuxmuster-prepare",
         
         "linuxmuster-prepare --initial -u -p server -l /dev/sdb",
         
         # Add timeout in welcome script
         "sed 's/wget/wget --timeout 1/' -i /etc/profile.d/Z99-linuxmuster.sh",
         
         # Fix network to allow packer to reconnect.
         "mv /tmp/02-packer-after.yaml /etc/netplan/02-packer.yaml",
         "netplan generate",
         "netplan apply",
         
         # Generate network config for production use but do only apply after reboot.
         "rm /etc/netplan/02-packer.yaml",
         "netplan generate"
      ]
      execute_command = "echo ${var.sudo_password} | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
  }
  
  provisioner "shell" {
     inline = [
        "echo done",
        "date"
     ]
  }
  
  post-processor "checksum" { # checksum image
    checksum_types = [ "sha512" ] # checksum the artifact
  }
  
  post-processor "vagrant" {
      keep_input_artifact = true
  }
}


