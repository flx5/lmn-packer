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
