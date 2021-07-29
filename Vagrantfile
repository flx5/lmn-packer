# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = "debian/buster64"
  config.vm.hostname = "proxmox"
  
  config.vm.synced_folder ".", "/vagrant", disabled: false, type: "rsync",
  	rsync__exclude: [".git", ".vagrant", "output-*", "packer_*"]
  
  # enable nested virtualization
  config.vm.provider "virtualbox" do |vb|
    vb.customize ['modifyvm', :id, '--nested-hw-virt', 'on']
    vb.customize ["modifyvm", :id, "--vram", "128"]
    vb.memory = 4096
    vb.check_guest_additions = false
    vb.cpus = 2
  end
  
  config.vm.provider :libvirt do |libvirt|
    libvirt.nested = true
    libvirt.memory = 4096
    libvirt.cpus = 2
    libvirt.video_type = "virtio"
  end

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # NOTE: This will enable public access to the opened port
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  config.vm.network "forwarded_port", guest: 8006, host: 8006, host_ip: "127.0.0.1"
  config.vm.network :forwarded_port, guest: 22, host: 2322, host_ip: "127.0.0.1"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  
  config.vm.provision "file", source: "interfaces", destination: "/tmp/interfaces"
  config.vm.provision "shell", inline: <<-SHELL
     set -e
     
     apt-get update
     apt-get install -y gnupg2
     
     curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
     echo "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
     apt-get update
     apt-get install -y packer
     
     mv /tmp/interfaces /etc/network/interfaces
     chown root:root /etc/network/interfaces
     apt-get install -y ifupdown2 bridge-utils debconf-utils
     ifreload -a
     
     echo "postfix postfix/main_mailer_type select No configuration" | debconf-set-selections
     DEBIAN_FRONTEND=noninteractive apt-get install -y postfix

     sed -i "s/.*proxmox/$(hostname -I)\t$(hostname)/" /etc/hosts
     echo "deb [arch=amd64] http://download.proxmox.com/debian/pve buster pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
     wget http://download.proxmox.com/debian/proxmox-ve-release-6.x.gpg -O /etc/apt/trusted.gpg.d/proxmox-ve-release-6.x.gpg
     apt-get update
     DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
     DEBIAN_FRONTEND=noninteractive apt-get install -y proxmox-ve
     
     pvesm set local -content images,snippets,rootdir,backup,iso,vztmpl
  SHELL
  

end
