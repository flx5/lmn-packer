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
  iso_url = "https://ci-01.nyi.hardenedbsd.org/pub/hardenedbsd/12-stable/amd64/amd64/build-517/disc1.iso"
  iso_checksum = "sha256:f9f98ffef9e4390b1cb9c9555959d95d5b41c9bbc64bc2311a6c388399df37d4"
 
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
  ssh_password = "Muster!"
  shutdown_command = "shutdown -p now"
  
}

build {
  sources = ["sources.virtualbox-iso.opnsense"]
  
  provisioner "shell" {
      expect_disconnect = true
      
      # FreeBSD uses tcsh
      execute_command = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"
      
      inline = [
         "env ASSUME_ALWAYS_YES=YES pkg install ca_root_nss",
         "fetch https://raw.githubusercontent.com/opnsense/update/master/src/bootstrap/opnsense-bootstrap.sh.in",
         "echo 'Installing OpnSense ${var.opnsense_release}'",
         "sh ./opnsense-bootstrap.sh.in -r ${var.opnsense_release} -y"
      ]
  }
}


