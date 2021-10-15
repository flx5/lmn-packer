<?xml version="1.0"?>
    <installation srtype="ext">
        <primary-disk guest-storage="True">vda</primary-disk>
        <keymap>de</keymap>
        <root-password>${root_pw}</root-password>
        <source type="local" />
      <!--  <post-install-script type="url">
          http://pxe.example.org/myscripts/post-install-script
        </post-install-script>-->
        <admin-interface name="eth0" proto="dhcp" />
        <timezone>Europe/Berlin</timezone>
    </installation>

