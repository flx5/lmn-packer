packer {
  required_plugins {
   xenserver= {
      version = "= v0.3.3-dev1"
      source = "github.com/flx5/xenserver"
    }
  }
}

source "xenserver-iso" "test" {
  # Ubuntu 18.04.5 boots very slowly on xen in bios mode and not at all in uefi mode.
  # 18.04.4 boots fine in uefi mode and also very slow in bios.
  iso_url          =  "http://old-releases.ubuntu.com/releases/bionic/ubuntu-18.04.4-server-amd64.iso"
  iso_checksum     = "e2ecdace33c939527cbc9e8d23576381c493b071107207d2040af72595f8990b"
  iso_checksum_type = "sha256"
  tools_iso_name = "guest-tools.iso"
  clone_template = "Ubuntu Bionic Beaver 18.04"

  vm_memory = 2048
   
  firmware = "uefi"
  vcpus_max = 2
  vcpus_atstartup = 2
  
  remote_host = "192.168.122.76"
  remote_username = "root"
  remote_password = "Muster!"
  
  ssh_username = "root"
  ssh_password = "Muster!"
  ssh_timeout = "20m"
  
  sr_iso_name = "Local storage"
  sr_name = "Local storage"
  
 # http_directory = "${path.root}/http/"
 
 http_content = {
   "/preseed.cfg" = file("http/preseed.cfg")
 }
  
  vm_name = "server"
  
  boot_wait = "20s"
  
  boot_command = [
     "<esc>",
     "set gfxpayload=keep<enter>",
     "linux /install/vmlinuz noapic debian-installer/locale=en_US keymap=de hostname=server preseed/url=http://{{ .HTTPIP }}:{{.HTTPPort}}/preseed.cfg ---<enter>",
     "initrd /install/initrd.gz<enter>",
     "boot<enter>"
  ]  
}

build {
  sources = ["sources.xenserver-iso.test"]
}
