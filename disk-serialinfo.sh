#!/bin/bash
diskname=$1
uuid=`udevadm info --query=property --name=$diskname |grep SERIAL_RAW | cut -d\= -f2`


