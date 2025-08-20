#!/bin/bash

# VM Atölyeleri Başa Al Script - İyileştirilmiş Versiyon
# Geri döndürülecek VM isimleri
VMS=(servera.local.lab serverb.local.lab serverc.local.lab serverd.local.lab servere.local.lab)
SNAPSHOT_NAME="lab"

# Renkli çıktı için
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonksiyon: VM durumunu kontrol et
check_vm_state() {
    local vm_name="$1"
    virsh domstate "$vm_name" 2>/dev/null
}

# Fonksiyon: VM'i güvenli şekilde durdur
safe_shutdown() {
    local vm_name="$1"
    local current_state=$(check_vm_state "$vm_name")
    
    if [[ "$current_state" == "running" ]]; then
        echo -e "${YELLOW}[$vm_name] VM çalışıyor, güvenli kapatma yapılıyor...${NC}"
        virsh shutdown "$vm_name" 2>/dev/null
        
        # Kapatılmasını bekle (maksimum 30 saniye)
        local timeout=30
        while [[ $timeout -gt 0 ]]; do
            current_state=$(check_vm_state "$vm_name")
            if [[ "$current_state" != "running" ]]; then
                echo -e "${GREEN}[$vm_name] Güvenli şekilde kapatıldı.${NC}"
                return 0
            fi
            sleep 1
            ((timeout--))
        done
        
        # Eğer güvenli kapatma başarısız olursa zorla kapat
        echo -e "${YELLOW}[$vm_name] Güvenli kapatma zaman aşımı, zorla kapatılıyor...${NC}"
        virsh destroy "$vm_name" 2>/dev/null
        sleep 2
    fi
}

# Ana döngü
echo -e "${BLUE}=== VM Atölyeleri Snapshot'a Geri Döndürme İşlemi Başladı ===${NC}"
echo ""

success_count=0
error_count=0

for VM in "${VMS[@]}"; do
    echo -e "${BLUE}[$VM] İşlem başlıyor...${NC}"
    
    # VM'in mevcut olup olmadığını kontrol et
    if ! virsh dominfo "$VM" >/dev/null 2>&1; then
        echo -e "${RED}[$VM] VM bulunamadı! Atlanıyor...${NC}"
        ((error_count++))
        echo "---------------------------"
        continue
    fi
    
    # Snapshot'ın mevcut olup olmadığını kontrol et
    if ! virsh snapshot-info "$VM" "$SNAPSHOT_NAME" >/dev/null 2>&1; then
        echo -e "${RED}[$VM] '$SNAPSHOT_NAME' snapshot'ı bulunamadı! Atlanıyor...${NC}"
        ((error_count++))
        echo "---------------------------"
        continue
    fi
    
    # VM'i güvenli şekilde durdur
    safe_shutdown "$VM"
    
    # Snapshot'a geri döndür
    echo -e "${YELLOW}[$VM] Snapshot'a geri döndürülüyor: $SNAPSHOT_NAME${NC}"
    if virsh snapshot-revert "$VM" "$SNAPSHOT_NAME" 2>/dev/null; then
        echo -e "${GREEN}[$VM] Başarıyla snapshot'a geri döndürüldü.${NC}"
        
        # VM'i başlat
        echo -e "${YELLOW}[$VM] Başlatılıyor...${NC}"
        if virsh start "$VM" 2>/dev/null; then
            echo -e "${GREEN}[$VM] Başarıyla başlatıldı.${NC}"
            
            # VM'in başlamasını bekle
            echo -e "${YELLOW}[$VM] Sistem tamamen başlaması bekleniyor...${NC}"
            sleep 5
            
            # Durum kontrolü
            current_state=$(check_vm_state "$VM")
            if [[ "$current_state" == "running" ]]; then
                echo -e "${GREEN}[$VM] ✓ İşlem başarıyla tamamlandı.${NC}"
                ((success_count++))
            else
                echo -e "${RED}[$VM] ✗ VM başlatıldı ancak durumu beklenmedik: $current_state${NC}"
                ((error_count++))
            fi
        else
            echo -e "${RED}[$VM] ✗ Başlatılamadı!${NC}"
            ((error_count++))
        fi
    else
        echo -e "${RED}[$VM] ✗ Snapshot'a geri döndürmede hata oluştu!${NC}"
        ((error_count++))
    fi
    
    echo "---------------------------"
done

# Özet
echo ""
echo -e "${BLUE}=== İşlem Özeti ===${NC}"
echo -e "${GREEN}Başarılı: $success_count${NC}"
echo -e "${RED}Hatalı: $error_count${NC}"
echo -e "${BLUE}Toplam VM: ${#VMS[@]}${NC}"

if [[ $success_count -eq ${#VMS[@]} ]]; then
    echo -e "${GREEN}🎉 Tüm VM'ler başarıyla işlendi!${NC}"
    exit 0
elif [[ $error_count -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  Bazı VM'lerde sorun yaşandı.${NC}"
    exit 1
fi