ifconfig wlan2 down
macchanger --mac=00:01:02:03:04:05 wlan2
ifconfig wlan2 10.44.44.88 netmask 255.255.255.0 up
service isc-dhcp-server restart
/usr/sbin/hostapd /etc/hostapd/hostapd.conf -B
