#!/bin/bash
set +x
if [ $# -eq  "1" ]
then
certname=$1
else
certname=`hostname -f`
fi
# openssl genrsa -des3 -out $certname.key  2048
openssl genrsa -out $certname.key  2048
openssl req    -new  -key $certname.key -out $certname.csr
openssl x509   -req  -days 3650 -in $certname.csr -signkey $certname.key -out $certname.cert
#mv $certname.key $certname.encrypted.key
#openssl rsa -in $certname.encrypted.key -out $certname.key
#openssl x509   -in $certname.cert -out $certname.pem -outform PEM



