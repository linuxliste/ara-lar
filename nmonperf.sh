#!/usr/bin/ksh
FNAME=$(hostname)'.'$(date "+%Y%m%d")'.nmon'
/usr/bin/nmon -f -F /home/nmon/$FNAME -s 15 -c 2880

