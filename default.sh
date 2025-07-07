#!/bin/bash
whoami=`/usr/bin/whoami`
userid=`/usr/bin/id -u`

checkisroot()
{
if [ "$userid" != "0" ]
then
echo "Root Degilsiniz!"
exit
fi
}


