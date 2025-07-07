#!/bin/bash

# Kullanım: rar_split dosya_adi
# rar'ın sisteminizde kurulu olması gerekmektedir.

if [ "$#" -ne 1 ]; then
    echo "Belirttiğiniz dosya bulunamadı"
    echo "Kullanım: $0 dosya_adı"
    exit 1
fi

DOSYA_ADI="$1"

# rar ile recovery records ekleyerek 4GB (4096 MB) boyutunda bölünmüş arşiv oluştur
rar a -sfx -rr -v4096M "${DOSYA_ADI}.rar" "$DOSYA_ADI"

echo "Arşivleme tamamlandı. Parçalar '${DOSYA_ADI}.part*.rar' olarak oluşturuldu."

