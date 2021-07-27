# If this is changed it has to be changed in cidata/user-data too...
variable "sudo_password" {
  type =  string
  default = "Muster!"
  sensitive = true
}

variable "headless" {
  type =  string
  default = "false"
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


