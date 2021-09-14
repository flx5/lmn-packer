packer {
  required_plugins {
   xenserver= {
      version = ">= v0.3.2"
      source = "github.com/ddelnano/xenserver"
    }
  }
}

source "xenserver-iso" "test" {
  iso_url          =  "http://cdimage.ubuntu.com/ubuntu/releases/bionic/release/ubuntu-18.04.5-server-amd64.iso"
  iso_checksum     = "8c5fc24894394035402f66f3824beb7234b757dd2b5531379cb310cedfdf0996"
  iso_checksum_type = "sha256"
  tools_iso_name = "guest-tools.iso"
  clone_template = "Ubuntu Bionic Beaver 18.04"
  vm_memory = 2048
  
  
  remote_host = "localhost"
  remote_username = "root"
  remote_password = "Muster!"
  
  ssh_username = "root"
  ssh_password = "Muster!"
  
  sr_iso_name = "Local"
  sr_name = "Local"
  
  http_directory = "http"
  
  vm_name = "server"
  
  boot_command = [
    "<esc><esc><wait5><enter><wait5>",
    "/install/vmlinuz noapic ",
    "initrd=/install/initrd.gz ",
    "debian-installer/locale=en_US keymap=de hostname=server ",
    "preseed/url=http://{{ .HTTPIP }}:{{.HTTPPort}}/preseed.cfg -- <enter>"
  ]
}

build {
  sources = ["sources.xenserver-iso.test"]
}
