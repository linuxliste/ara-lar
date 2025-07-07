host=1.2.3.4
packet_size=8196
paket_sayisi=5

ping -M do -c ${packet_sayisi} -s  ${packet_size} ${host}

