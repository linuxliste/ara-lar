#/bin/bash
#ifconfig enp7s0 172.16.0.10 up
dnsmasq -i enp7s0 --dhcp-range=172.16.0.100,172.16.0.200 \
--dhcp-boot=openwrt-ar71xx-mikrotik-vmlinux-initramfs.elf  \
--enable-tftp --tftp-root=/var/lib/tftpboot/ -d -u root -p0 -K --log-dhcp --bootp-dynamic
