iptables -A INPUT -i eth0 -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i eth0 -j DROP
iptables -A INPUT -i wlan0 -j DROP
