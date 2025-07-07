#!/bin/bash

# iozone-nfs-test.sh
# Bonnie ve fio benzeri NFS performans testi scripti

# --- KULLANIM ---
# ./iozone-nfs-test.sh /mnt/nfs 16G

# --- Parametreler ---
TESTDIR="${1:-/mnt/tmpfs}"         # Test yapılacak dizin (varsayılan /mnt/nfs)
TESTSIZE="${2:-8G}"             # Test dosya boyutu (varsayılan 16G, RAM'den büyük olmalı)
THREADS_LIST=(1 2 4 8)           # Paralel thread sayıları
FILE_SIZES=(64M 512M 2G 4G)      # Farklı dosya boyutları

# Sonuçları kaydetmek için
RESULTS="iozone_nfs_$(date +%Y%m%d_%H%M%S).csv"

# --- Komut Kontrolü ---
command -v iozone >/dev/null 2>&1 || { echo >&2 "iozone kurulu değil!"; exit 1; }

echo "Test dizini   : $TESTDIR"
echo "Test boyutu   : $TESTSIZE"
echo "Sonuç dosyası : $RESULTS"
echo ""

# --- Test Döngüsü ---
for FILESIZE in "${FILE_SIZES[@]}"; do
  for THREADS in "${THREADS_LIST[@]}"; do
    echo "[$(date)] Test başlıyor: Boyut=$FILESIZE Thread=$THREADS"
    iozone -i 0 -i 1 -r 64k -s $FILESIZE -t $THREADS -F $(for n in $(seq 1 $THREADS); do echo -n "$TESTDIR/testfile$n "; done) -w -b temp.xls | tee -a $RESULTS
    sleep 2
    # Test dosyalarını sil
    rm -f $TESTDIR/testfile*
  done
done

echo "Tüm testler tamamlandı."
echo "Sonuçlar $RESULTS dosyasına kaydedildi."

# Ekstra: Sonuçları insan okuyacak şekilde tabloya çevirmek için
echo "iozone'un kendi .xls çıktısını LibreOffice veya Excel ile açabilirsiniz."

