### Base system installation
d-i base-installer/kernel/override-image string linux-server

d-i debian-installer/locale string en_US
d-i console-keymaps-at/keymap select de
d-i keyboard-configuration/xkb-keymap select de

d-i debconf/frontend string noninteractive

### Account setup
# Don't create an additional account
d-i passwd/make-user boolean false
# Set root password
d-i passwd/root-login boolean true
d-i passwd/root-password password ${root_pw}
d-i passwd/root-password-again password ${root_pw}
d-i user-setup/allow-password-weak boolean true

# Enable root ssh login with password
d-i preseed/late_command string \
   in-target sed -i "s/^#PermitRootLogin.*\$/PermitRootLogin yes/g" /etc/ssh/sshd_config

### Clock and time zone setup
d-i clock-setup/utc boolean true
d-i time/zone string Europe/Berlin

### Partitioning
d-i partman-auto/method string regular

d-i partman-auto/choose_recipe select atomic

# This makes partman automatically partition without confirmation, provided
# that you told it what to do using one of the methods above.
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

### Mirror settings
d-i mirror/country string DE
d-i mirror/http/proxy string

### Package selection
tasksel tasksel/first multiselect standard

# Disable automatic updates
d-i pkgsel/update-policy select none

# No inital updates
d-i pkgsel/upgrade select none

d-i pkgsel/include string %{ for install in installs ~}${install} %{ endfor } openssh-server ifupdown2 gnupg2 sudo lsb-release
d-i pkgsel/install-language-support boolean false

### Boot loader installation
d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string /dev/${grub_disk}

### Finishing up the installation
d-i finish-install/reboot_in_progress note
