PARTITIONS="${partitions}"
DISTRIBUTIONS="kernel.txz base.txz"

export nonInteractive="YES"

HOSTNAME=opnsense

#!/bin/sh
sysrc ifconfig_${wan_iface}=DHCP
sysrc ifconfig_${lan_iface}="inet 10.0.0.254 netmask 255.255.255.0"
sysrc sshd_enable=YES
sysrc keymap="de"

# Change root password
echo '${root_pw}' | pw usermod root -h 0

# Enable root ssh
sed -i "" -e "s/.*PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config

reboot
