# If this is changed it has to be changed in cidata/user-data too...
variable "sudo_password" {
  type =  string
  default = "Muster!"
  sensitive = true
}

source "virtualbox-iso" "basic-example" {
  guest_os_type = "Ubuntu_64"
  iso_url = "http://releases.ubuntu.com/20.04/ubuntu-20.04.2-live-server-amd64.iso"
  iso_checksum = "sha256:d1f2bf834bbe9bb43faf16f9be992a6f3935e65be0edece1dee2aa6eb1767423"
  ssh_username = "linuxadmin"
  ssh_password = "${var.sudo_password}"
  shutdown_command = "echo ${var.sudo_password} | sudo -S shutdown -P now"
  guest_additions_mode = "disable"
  headless = true
  
  memory = 1024
  # 25 GB
  disk_size = 25600
  
  # 100 GB
  disk_additional_size = [ 102400 ]
  
  boot_command = [    
                " <wait>",
                " <wait>",
                " <wait>",
                " <wait>",
                " <wait>",
                "<esc><wait>",
                "<f6><wait>",
                "<esc><wait>",
                "<bs><bs><bs><bs><wait>",
                " autoinstall",
                " ds=nocloud-net",
                ";s=http://{{.HTTPIP}}:{{.HTTPPort}}/",
                " ---",
                "<enter>"
  ]
  
  boot_wait = "5s"
  
  http_directory = "./cidata/"
  ssh_timeout = "10000s"
}

build {
  sources = ["sources.virtualbox-iso.basic-example"]
  
  provisioner "file" {
    source = "workaround/insecure_apt.txt"
    destination = "/tmp/insecure_apt.txt"
  }
  
  provisioner "shell" {
      # Todo disable autoupdate
      # Todo disable cloud-init
      inline = [
         # REQUIRED UNTIL https://ask.linuxmuster.net/t/v7-repo-not-signed/5428/7 is fixed
         "echo ${var.sudo_password} | sudo -S mv /tmp/insecure_apt.txt /etc/apt/apt.conf.d/99insecure",
      ]
  }
  
  provisioner "shell" {
      script = "install_packages.sh"
      execute_command = "echo ${var.sudo_password} | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
  }
  
  provisioner "shell" {
      inline = [
         "echo ${var.sudo_password} | sudo -S linuxmuster-prepare -i -u -p server",
      ]
  }
}


