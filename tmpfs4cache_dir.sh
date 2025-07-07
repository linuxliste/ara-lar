#!/bin/bash
sudo rm -rf /home/remzi/.cache
sudo mkdir /home/remzi/.cache
sudo /usr/bin/mount -t tmpfs tmpfs /home/remzi/.cache

