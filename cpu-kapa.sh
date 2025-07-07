#!/bin/bash
for i in `seq 2 7` ; do echo 0 > /sys/devices/system/cpu/cpu$i/online; done
