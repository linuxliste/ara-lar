#!/bin/bash
# Multipath lun/disk sistemden kaldirir
# Remzi AKYUZ
# remzi@akyuz.tech

tmpf="/tmp/deldevlst.txt"
if (( $# > 0 )) 
then
	export mpathdev=$1

dev=/dev/mapper/$mpathdev
if [ -e $dev ]
then
	multipath -ll $mpathdev |egrep -v "status=active|size|status=enabled|$mpathdev"|sed 's/| `-//g'|sed 's/`-//g' |awk '{print $2}' > $tmpf
	multipath -f $mpathdev && echo $mpathdev silindi..
	for devname in `cat $tmpf`
	do
	echo 1 > /sys/block/$devname/device/delete  && echo $devname Silindi..
	done

	echo $mpathdev baglantisini disk unitesinden iptal edebilirsiniz.
else
echo $dev bulunamadi
fi

else
	echo Kullanim sekli: $0 multipath-name
fi

