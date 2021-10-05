source "qemu" "base-debian" {

  headless = var.headless

  iso_url          = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-11.0.0-amd64-netinst.iso"
  iso_checksum     = "sha512:5f6aed67b159d7ccc1a90df33cc8a314aa278728a6f50707ebf10c02e46664e383ca5fa19163b0a1c6a4cb77a39587881584b00b45f512b4a470f1138eaa1801"

  memory   = 2048
  cpus    = 2


  disk_size = "500G"
  format    = "qcow2"
  accelerator = "kvm"
  vm_name = "proxmox"
  net_device = "virtio-net"
  disk_interface = "virtio"

  boot_wait = "5s"

  http_content = {
    "/preseed.cfg" = templatefile("preseed.pkrtpl.hcl", { root_pw = local.root_password, installs = ["qemu-guest-agent"], grub_disk = "vda" })
  }

  ssh_timeout  = "20m"
  ssh_username = "root"
  ssh_password = local.root_password
  
      boot_command = [
        "<wait5><esc><wait>",
        "auto url=http://${cidrhost(var.red_network,2)}:{{.HTTPPort}}/preseed.cfg ",
      
        "<enter>"
      ]
      
  qemuargs = [
    [ "-cpu", "host"],
    [ "-smp", "cores=${var.cores},sockets=${var.sockets}" ],
    [ "-netdev", "user,id=user.0,net=${var.red_network},dhcpstart=${cidrhost(var.red_network,9)},hostfwd=tcp::{{ .SSHHostPort }}-:22"],
    [ "-device", "virtio-net,netdev=user.0" ]
  ]
}


# Run successfull build using 
/*
qemu-img create -f qcow2 -b proxmox output-base-debian/disk.qcow2

qemu-system-x86_64 -machine type=pc,accel=kvm -cpu host -m 4096 -smp $(nproc)  \
 -drive file=output-base-debian/disk.qcow2,if=virtio,cache=writeback,discard=ignore,format=qcow2 \
 -netdev user,id=user.0,net=192.168.122.0/24,dhcpstart=192.168.122.9,hostfwd=tcp::2222-:22,hostfwd=tcp::4444-:8006 \
 -device virtio-net,netdev=user.0 

*/
build {
  name = "proxmox"

  sources = [ "sources.qemu.base-debian" ]
  
 provisioner "shell" {
    script = "${path.root}/scripts/install_proxmox.sh"
    expect_disconnect = true
    environment_vars = [
        "WAN_ADDRESS=${cidrhost(var.red_network,9)}/24",
        "WAN_GATEWAY=${cidrhost(var.red_network,2)}",
    ]
  }
}
