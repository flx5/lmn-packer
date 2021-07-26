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

source "virtualbox-iso" "basic-example" {
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
            "debian-installer/locale=en_US keymap=us hostname=server ",
            "preseed/url=http://10.0.0.2:{{.HTTPPort}}/preseed.cfg -- <enter>"
  ]
  
  boot_wait = "5s"
  
  http_directory = "18/http"
  ssh_timeout = "10000s"
  
  vboxmanage = [
     ["modifyvm", "{{.Name}}", "--natnet1", "10.0.0.0/24"]
  ]
}

build {
  sources = ["sources.virtualbox-iso.basic-example"]
        # Todo disable autoupdate
      # Todo disable cloud-init

  provisioner "shell" {
      # Network is restarted by linuxmuster-prepare
      expect_disconnect = true
  
      inline = [
         "echo 'ENABLED=0' > /etc/default/motd-news",
         "wget https://archive.linuxmuster.net/lmn7/lmn7-appliance",
         "chmod +x lmn7-appliance",
         "./lmn7-appliance -p server -u -l /dev/sdb 2>&1 | tee /root/log.txt",
         "service sshd restart"
      ]
      execute_command = "echo ${var.sudo_password} | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
  }
  
  provisioner "shell" {
     inline = [
        "echo done",
        "date"
     ]
  }
}


