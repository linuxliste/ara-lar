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

if [ $# -eq 2 ]
then
     certfile=${1}
     certname=${2}

    if [ -f "$certfile" ]
    then
        echo ${certfile}
        echo ${certname}
        #
        # For cert8 (legacy - DBM)
        
        for certDB in $(find ~/ -name "cert8.db")
        do
          certdir=$(dirname ${certDB});
          certutil -A -n "${certname}" -t "TCu,Cu,Tu" -i ${certfile} -d dbm:${certdir}
        done

        #
        # For cert9 (SQL)
        #

        for certDB in $(find ~/ -name "cert9.db")
        do
         certdir=$(dirname ${certDB});
         certutil -A -n "${certname}" -t "TCu,Cu,Tu" -i ${certfile} -d sql:${certdir}
        done
    fi
    certutil -d sql:$HOME/.pki/nssdb -L
else
    clear
    echo "kullanim sekli" "$0"  "dosya.crt" "sertifika ismi"
fi
