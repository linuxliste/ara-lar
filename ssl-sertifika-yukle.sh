#!/bin/bash

set -e

function fail() {
    echo "HATA: $1"
    exit 1
}

function usage() {
    echo "Kullanım: $0 <registry_adresi> [port]"
    echo "Örnek: $0 myregistry.domain.com 443"
    exit 1
}

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
fi

REGISTRY="$1"
PORT="$2"
if [[ -z "$REGISTRY" ]]; then
    echo "Registry adresi parametre olarak verilmedi."
    usage
fi
if [[ -z "$PORT" ]]; then
    PORT="443"
    echo "Port belirtilmedi. Varsayılan olarak 443 kullanılacak."
fi

TMP_CERT="/tmp/$REGISTRY.crt"

echo "== $REGISTRY registry için sertifika kurulumu başlatılıyor =="

echo "1) Sertifika registry'den çekiliyor..."
openssl s_client -showcerts -connect "$REGISTRY:$PORT" </dev/null 2>/dev/null | openssl x509 -outform PEM > "$TMP_CERT" || fail "Sertifika indirilemedi."
if grep -q "BEGIN CERTIFICATE" "$TMP_CERT"; then
    echo "   Sertifika başarıyla indirildi."
else
    fail "Sertifika dosyası geçersiz veya bulunamadı."
fi

# Platform tespiti
if [ -f /etc/redhat-release ]; then
    # RHEL/CentOS/AlmaLinux/Rocky
    CERT_DIR="/etc/containers/certs.d/$REGISTRY"
    CERT_PATH="$CERT_DIR/ca.crt"
    CA_TRUST_DIR="/etc/pki/ca-trust/source/anchors"
    CA_TRUST_PATH="$CA_TRUST_DIR/$REGISTRY.crt"

    echo "2) Sertifika dizini oluşturuluyor: $CERT_DIR"
    sudo mkdir -p "$CERT_DIR" || fail "Dizin oluşturulamadı."
    if [ -f "$CERT_PATH" ]; then
        echo "   Eski sertifika yedekleniyor."
        sudo mv "$CERT_PATH" "$CERT_PATH.bak.$(date +%s)" || fail "Yedekleme başarısız."
    fi

    echo "3) Sertifika doğru yere kopyalanıyor."
    sudo cp "$TMP_CERT" "$CERT_PATH" || fail "Sertifika kopyalanamadı."
    sudo chmod 644 "$CERT_PATH"

    echo "4) CA anchor'a ekleniyor: $CA_TRUST_PATH"
    sudo cp "$TMP_CERT" "$CA_TRUST_PATH" || fail "CA trust'a eklenemedi."
    sudo chmod 644 "$CA_TRUST_PATH"

    echo "5) CA deposu güncelleniyor..."
    sudo update-ca-trust extract || fail "CA deposu güncellenemedi."

elif [ -f /etc/debian_version ]; then
    # Debian/Ubuntu
    CERT_DIR="/etc/containers/certs.d/$REGISTRY"
    CERT_PATH="$CERT_DIR/ca.crt"
    CA_TRUST_DIR="/usr/local/share/ca-certificates"
    CA_TRUST_PATH="$CA_TRUST_DIR/$REGISTRY.crt"

    echo "2) Sertifika dizini oluşturuluyor: $CERT_DIR"
    sudo mkdir -p "$CERT_DIR" || fail "Dizin oluşturulamadı."
    if [ -f "$CERT_PATH" ]; then
        echo "   Eski sertifika yedekleniyor."
        sudo mv "$CERT_PATH" "$CERT_PATH.bak.$(date +%s)" || fail "Yedekleme başarısız."
    fi

    echo "3) Sertifika doğru yere kopyalanıyor."
    sudo cp "$TMP_CERT" "$CERT_PATH" || fail "Sertifika kopyalanamadı."
    sudo chmod 644 "$CERT_PATH"

    echo "4) CA anchor'a ekleniyor: $CA_TRUST_PATH"
    sudo cp "$TMP_CERT" "$CA_TRUST_PATH" || fail "CA trust'a eklenemedi."
    sudo chmod 644 "$CA_TRUST_PATH"

    echo "5) CA deposu güncelleniyor..."
    sudo update-ca-certificates || fail "CA deposu güncellenemedi."

else
    fail "Desteklenmeyen bir dağıtım!"
fi

echo "6) Geçici dosya siliniyor."
rm -f "$TMP_CERT"

echo -e "\nTüm işlemler başarılı şekilde tamamlandı!"
echo "Şimdi tekrar podman veya docker pull komutunu deneyebilirsiniz."
exit 0

