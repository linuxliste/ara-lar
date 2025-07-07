#!/bin/bash
#
# Remzi AKYUZ
# 2019.04.11 21:21
# remzi@akyuz.tech
#
# Bu script, temel seviyede disk io testi nasil yapildigini gostermek icin hazirlanmistir.
# İhtiyaclara gore duzenlenmesi gerekebilir
# 
# Ayni anda paralel olarak yapilacak islem
threads=32

# Test icin kullanilacak dizin/bolur
tmpdir=/data/testdir

# test sonucu
reportfile=/tmp/iozone-report.txt

#Disk block size 512 veya 4k

blocksize=512b

#Test dosyalarinin boyutu
testfilesize=1024M

checkpkg=`dpkg-query -W -f='${Package} ${Status}\n'  iozone3`
echo   $checkpkg
if [[ "$checkpkg" = "iozone3 install ok installed" ]]
then
echo "iozone3 yuklenmis"
else
apt-get -y install iozone3
fi

for cnt in `seq 1 32`
do
tmpfile="$tmpfile ""$tmpdir/tmpf$cnt"
done
echo $tmpfile
iozone -R -l $threads -u $threads -r $blocksize -s $testfilesize -F $tmpfile |tee $reportfile

