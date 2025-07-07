#!/bin/bash
set +x

# Bu script chrome ve firefox icin sertifikanin  kullanicilara ilave edilmesini saglar
#
# Detayli bilgiyi merak ederseniz asagidaki sayfalara goz atabilirsiniz
# https://chromium.googlesource.com/chromium/src.git/+/master/docs/linux/cert_management.md
# https://chromium.googlesource.com/chromium/src/+/refs/heads/lkgr/docs/linux/cert_management.md

#
# Scriptint calismasi icin libnss3-tools sistemde yuklu olmasi gerekiyor.
# Yuklu degilse : 
#                apt -y install libnss3-tools

certfile='/usr/local/share/ca-certificates/ym.tekirdag.yerel.crt'
certname='ym.tekirdag.yerel'
if [ -f /var/log/certimport.log ]
then
exit 0
fi

users=`ls /home`

for user in $users
do
idcheck=`/usr/bin/id -u ${user}`
if [ $idcheck -qt 1 ]
then
   nssdb="/home/${user}/.pki/nssdb/cert9.db"

   echo '#!/bin/bash'  >  /var/tmp/nssdb-ekle.sh

   if [ -f  $nssdb ]
   then
       # NSSDB mevcutsa , mevcut olan db ye  ym.tekirdag.yerel eklenir
       echo "/usr/bin/certutil -d sql:/home/${user}/.pki/nssdb -A -t \"C,,\" -n ym.tekirdag.yerel -i /usr/local/share/ca-certificates/ym.tekirdag.yerel.crt" >> /var/tmp/nssdb-ekle.sh
   else
      # NSS DB mevcut degilse , yeni db olusturularak eklenir
      echo "mkdir -p  /home/${user}/.pki/nssdb" >> /var/tmp/nssdb-ekle.sh
      echo "/usr/bin/certutil --empty-password -d sql:/home/${user}/.pki/nssdb -N" >>  /var/tmp/nssdb-ekle.sh

      echo "/usr/bin/certutil -d sql:/home/${user}/.pki/nssdb -A -t \"C,,\" -n ym.tekirdag.yerel -i /usr/local/share/ca-certificates/ym.tekirdag.yerel.crt" >> /var/tmp/nssdb-ekle.sh

   fi

    echo "/usr/bin/certutil -d sql:/home/${user}/.pki/nssdb -L" >> /var/tmp/nssdb-ekle.sh

    chmod 755 /var/tmp/nssdb-ekle.sh
    su - $user -c /var/tmp/nssdb-ekle.sh  > /var/log/certimport.log 2>&1
else
    echo $user."Bulunamadi."
fi

done

exit 0 

