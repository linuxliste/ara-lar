#!/bin/bash
set +x
chk=$1
if [[ "$chk" == "1" ]]
then
/usr/bin/uuidgen | /usr/bin/sed   's/-//g' > /etc/machine-id
else
echo  Machine ID degistirmek istiyorsaniz asagidaki gibi calistirmaniz gerekiyor!
echo
echo "                      $0 1 "
echo " "
fi
