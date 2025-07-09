#!/bin/bash
set -e

# Kullanıcıdan FQDN, KISA AD ve IP al
FQDN="${1:-hub22.local.lab}"
SHORTNAME="${2:-hub22}"
IP1="${3:-10.253.10.72}"

# Subject değerleri
CA_SUBJECT="/C=TR/ST=Istanbul/L=Istanbul/O=local.lab/CN=local.lab Root CA"
SERVER_SUBJECT="/C=TR/ST=Istanbul/L=Istanbul/O=local.lab/CN=${FQDN}"

# Dosya isimleri
ROOT_CA_KEY="my-root-ca.key"
ROOT_CA_CRT="my-root-ca.crt"
SERVER_KEY="${FQDN}.key"
SERVER_CSR="${FQDN}.csr"
SERVER_CRT="${FQDN}.crt"
OPENSSL_CNF="openssl-san.cnf"

# 1. Root CA varsa atla, yoksa oluştur
if [[ ! -f $ROOT_CA_KEY || ! -f $ROOT_CA_CRT ]]; then
  echo "Root CA anahtarı ve sertifikası oluşturuluyor..."
  openssl genrsa -out $ROOT_CA_KEY 4096
  openssl req -x509 -new -nodes -key $ROOT_CA_KEY -sha256 -days 3650 -out $ROOT_CA_CRT -subj "$CA_SUBJECT"
else
  echo "Root CA dosyaları mevcut, yeniden üretmiyorum."
fi

# 2. SAN destekli openssl config dosyası oluştur
cat > $OPENSSL_CNF <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = TR
ST = Istanbul
L = Istanbul
O = local.lab
CN = $FQDN
OU = ta3rda

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $FQDN
DNS.2 = $SHORTNAME
IP.1 = $IP1
EOF

# 3. Server için key ve CSR oluştur
echo "Server key ve CSR oluşturuluyor..."
openssl genrsa -out $SERVER_KEY 2048
openssl req -new -key $SERVER_KEY -out $SERVER_CSR -config $OPENSSL_CNF

# 4. Server sertifikasını Root CA ile imzala (SAN uzantısı ile)
echo "Server sertifikası imzalanıyor..."
openssl x509 -req -in $SERVER_CSR -CA $ROOT_CA_CRT -CAkey $ROOT_CA_KEY -CAcreateserial \
  -out $SERVER_CRT -days 825 -sha256 -extfile $OPENSSL_CNF -extensions req_ext

# 5. Root CA'yı sistem CA store'a ekle
cp $ROOT_CA_CRT /etc/pki/ca-trust/source/anchors/
update-ca-trust extract

echo
echo "==== Özet ===="
echo "Root CA sertifikası:        $ROOT_CA_CRT"
echo "Server key dosyası:         $SERVER_KEY"
echo "Server imzalı sertifika:    $SERVER_CRT"
echo "Server CSR dosyası:         $SERVER_CSR"
echo
echo "Root CA sisteme yüklendi! Server cert'inizi servis(ler)inizde kullanabilirsiniz."
echo
echo "Örnek sunucuya yükleme:"
echo "  Sertifika: $SERVER_CRT"
echo "  Anahtar:   $SERVER_KEY"
echo "SAN detayları ile üretilmiştir (FQDN, kısa ad, IP)."

