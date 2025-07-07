
#!/bin/bash
amule_ports="3838,38436,4184,4232,4242,4321,4500,4661,4662,4672,57995,7111"

iptables -t nat -I PREROUTING -i eth0 -p tcp -m multiport --dports $amule_ports -j DNAT --to 172.16.2.73
iptables -t nat -I PREROUTING -i eth0 -p udp -m multiport --dports $amule_ports -j DNAT --to 172.16.2.73

