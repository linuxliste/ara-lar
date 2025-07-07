#!/bin/bash
# Remzi AKYUZ
# sistemdeki tum ağ kartlarının ip adreslerini siler
for nic in $(ls /sys/class/net)
do
ip addr flus $nic
done

