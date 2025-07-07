#!/bin/bash
set -x
for file in  /usr/java/latest/* 
do
   if [ -x $file ]
   then
   filename=`basename $file`
   update-alternatives --install /usr/bin/$filename $filename $file 100
   update-alternatives --set $filename $file
   echo $file $filename
   fi
done
