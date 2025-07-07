#!/bin/sh
iptables -t nat -A POSTROUTING -o wan0 -j MASQUERADE
iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
