variable "headless" {
  type =  string
  default = "false"
}

variable "opnsense_release" {
  type =  string
  default = "21.7"
}

source "virtualbox-iso" "opnsense" {
  guest_os_type = "FreeBSD_64"
  
  # FreeBSD Version should match with the opnsense version
  # Typically that information can be found at https://opnsense.org/blog/
  
  iso_url = "https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/12.2/FreeBSD-12.2-RELEASE-amd64-disc1.iso"
  iso_checksum = "sha256:289522e2f4e1260859505adab6d7b54ab83d19aeb147388ff7e28019984da5dc"
 
  guest_additions_mode = "disable"
  headless = "${var.headless}"
  
  # TODO Correct memory / disk size
  memory = 1024
  # 25 GB
  disk_size = 25600
    
  boot_command = [    
        "<esc><wait>",
        "boot -s<wait>",
        "<enter><wait10>",
        "/bin/sh<enter><wait>",
        "mdmfs -s 100m md1 /tmp<enter><wait>",
        "mdmfs -s 100m md2 /mnt<enter><wait>",
        "dhclient -l /tmp/dhclient.lease.em0 em0<enter><wait10>",
        "fetch -o /tmp/installerconfig http://{{ .HTTPIP }}:{{ .HTTPPort }}/installerconfig && bsdinstall script /tmp/installerconfig<enter>"
  ]
  
  boot_wait = "5s"
  
  http_directory = "18/http"
  ssh_timeout = "10000s"
  
  ssh_username = "root"
  ssh_password = "opnsense"
  shutdown_command = "shutdown -p now"
  
  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--nic2", "intnet"],
    ["modifyvm", "{{.Name}}", "--intnet2", "internal_lmn"],
  ] 
}

build {
  sources = ["sources.virtualbox-iso.opnsense"]
  
  provisioner "file" {
    source = "18/http/config.xml"
    destination = "/tmp/config.xml"
  }
  
  provisioner "shell" {
      # FreeBSD uses tcsh
      execute_command = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"
      
      inline = [
         "env ASSUME_ALWAYS_YES=YES pkg install ca_root_nss",
         "fetch https://raw.githubusercontent.com/opnsense/update/master/src/bootstrap/opnsense-bootstrap.sh.in",
         "echo 'Installing OpnSense ${var.opnsense_release}'",
         # Disable reboot
         "sed -i '' 's/reboot//' opnsense-bootstrap.sh.in",
         "sh ./opnsense-bootstrap.sh.in -r ${var.opnsense_release} -y",
         "mkdir /conf",
         "mv /tmp/config.xml /conf/config.xml"
      ]
  }
  
  # TODO Configure em0 static during boot and use jumphost. Otherwise after reboot ssh won't be reachable.
  
}


