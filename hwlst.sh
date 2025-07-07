#!/bin/sh

if [ $(whoami) != 'root' ]; then
 echo "\n\n\t\tBu $0 scripti root kullanicisi ile calistiriniz!!!\n\n"
        exit 1;
fi

logfile="/tmp/"`/bin/hostname`_`date +%Y%m%W`".txt"

free            >> $logfile
df -i           >> $logfile
df -h           >> $logfile
grep "model name" /proc/cpuinfo >> $logfile
ps -efL         >> $logfile

echo "Lutfen \n\t" $logfile "\n\ndosyasini eposta ile gonderiniz.\n\n"
echo "Tesekkurler."
