#!/bin/bash
for i in `seq 1 7` ; do echo 1 > /sys/devices/system/cpu/cpu$i/online; done
