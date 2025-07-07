#!/bin/bash
DOMAINNAME="akyuz.tech"
PORT=443

if [ $# -gt 0 ]
then
        DOMAINNAME="$2"
else
        echo
        echo Kullanim sekli: $0 domain_name
        echo
        echo                 $0 $DOMAINNAME
        echo
        echo

fi
printf Q | openssl s_client -servername $DOMAINNAME -connect $DOMAINNAME:$PORT | openssl x509 -noout -dates

echo sifir $0
echo Bir $1
echo iki $2
