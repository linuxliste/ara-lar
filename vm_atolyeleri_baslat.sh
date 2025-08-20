#!/bin/bash

# VM Atölyeleri Başlat Script - İyileştirilmiş Versiyon
# Başlatılacak makinelerin isim listesi
machines=(
    "00-ipa.local.lab"
    "00-sat.local.lab"
    "00-util.local.lab"
    "ex374-ansible-controller"
    "ex374-control22.local.lab"
    "00-git.local.lab"
    "00-bastion.local.lab"
    "servera.local.lab"
    "serverb.local.lab"
    "serverc.local.lab"
    "serverd.local.lab"
    "servere.local.lab"
    "ex374-hub22.local.lab"
    "rh294admin.local.lab"
)

# Renkli çıktı için
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Paralel işlem için maksimum eş zamanlı job sayısı
MAX_JOBS=5

# Progress bar için
PROGRESS_TOTAL=${#machines[@]}
PROGRESS_CURRENT=0

# Fonksiyon: VM durumunu kontrol et
check_vm_state() {
    local vm_name="$1"
    virsh domstate "$vm_name" 2>/dev/null
}

# Fonksiyon: VM'in mevcut olup olmadığını kontrol et
vm_exists() {
    local vm_name="$1"
    virsh dominfo "$vm_name" >/dev/null 2>&1
}

# Fonksiyon: VM'in tamamen başlamasını bekle
wait_for_vm_boot() {
    local vm_name="$1"
    local max_wait=60
    local wait_time=0
    
    echo -e "${CYAN}    [$vm_name] Sistem tamamen başlaması bekleniyor...${NC}"
    
    while [[ $wait_time -lt $max_wait ]]; do
        local state=$(check_vm_state "$vm_name")
        if [[ "$state" == "running" ]]; then
            # Ek kontrol: VM gerçekten erişilebilir mi?
            sleep 2
            if virsh dominfo "$vm_name" | grep -q "running"; then
                echo -e "${GREEN}    [$vm_name] ✓ Sistem tamamen başladı (${wait_time}s)${NC}"
                return 0
            fi
        elif [[ "$state" == "shut off" ]] || [[ "$state" == "crashed" ]]; then
            echo -e "${RED}    [$vm_name] ✗ Başlatma sırasında sorun oluştu: $state${NC}"
            return 1
        fi
        
        sleep 2
        ((wait_time += 2))
        
        # Her 10 saniyede progress göster
        if [[ $((wait_time % 10)) -eq 0 ]]; then
            echo -e "${YELLOW}    [$vm_name] Hala bekleniyor... (${wait_time}s/${max_wait}s)${NC}"
        fi
    done
    
    echo -e "${YELLOW}    [$vm_name] ⚠️ Zaman aşımı, ancak başlatma komutu gönderildi${NC}"
    return 2
}

# Fonksiyon: Tek VM başlatma
start_vm() {
    local vm_name="$1"
    local start_time=$(date +%s)
    
    echo -e "${BLUE}[$(date +%H:%M:%S)] $vm_name kontrol ediliyor...${NC}"
    
    # VM'in mevcut olup olmadığını kontrol et
    if ! vm_exists "$vm_name"; then
        echo -e "${RED}    [$vm_name] ✗ VM bulunamadı!${NC}"
        return 1
    fi
    
    # Mevcut durumu kontrol et
    local current_state=$(check_vm_state "$vm_name")
    case "$current_state" in
        "running")
            echo -e "${GREEN}    [$vm_name] ✓ Zaten çalışıyor${NC}"
            return 0
            ;;
        "paused")
            echo -e "${YELLOW}    [$vm_name] Duraklatılmış durumda, devam ettiriliyor...${NC}"
            virsh resume "$vm_name" 2>/dev/null
            return $?
            ;;
        "shut off"|"crashed"|"")
            echo -e "${YELLOW}    [$vm_name] Başlatılıyor... (Durum: $current_state)${NC}"
            ;;
        *)
            echo -e "${YELLOW}    [$vm_name] Bilinmeyen durum: $current_state, başlatma deneniyor...${NC}"
            ;;
    esac
    
    # VM'i başlat
    if virsh start "$vm_name" 2>/dev/null; then
        echo -e "${GREEN}    [$vm_name] Başlatma komutu başarıyla gönderildi${NC}"
        
        # Başlamasını bekle (opsiyonel)
        if [[ "$WAIT_FOR_BOOT" == "true" ]]; then
            wait_for_vm_boot "$vm_name"
            local boot_result=$?
        else
            sleep 2
            local new_state=$(check_vm_state "$vm_name")
            if [[ "$new_state" == "running" ]]; then
                echo -e "${GREEN}    [$vm_name] ✓ Başarıyla başlatıldı${NC}"
                boot_result=0
            else
                echo -e "${YELLOW}    [$vm_name] ⚠️ Durum: $new_state${NC}"
                boot_result=2
            fi
        fi
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${CYAN}    [$vm_name] İşlem süresi: ${duration}s${NC}"
        
        return $boot_result
    else
        echo -e "${RED}    [$vm_name] ✗ Başlatma komutu başarısız!${NC}"
        return 1
    fi
}

# Progress bar güncelleme
update_progress() {
    ((PROGRESS_CURRENT++))
    local percent=$((PROGRESS_CURRENT * 100 / PROGRESS_TOTAL))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${CYAN}Progress: ["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' ' '
    printf "] %d%% (%d/%d)${NC}" "$percent" "$PROGRESS_CURRENT" "$PROGRESS_TOTAL"
    
    if [[ $PROGRESS_CURRENT -eq $PROGRESS_TOTAL ]]; then
        echo ""
    fi
}

# Ana fonksiyon
main() {
    # Parametreleri kontrol et
    WAIT_FOR_BOOT=false
    PARALLEL=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -w|--wait)
                WAIT_FOR_BOOT=true
                shift
                ;;
            -p|--parallel)
                PARALLEL=true
                shift
                ;;
            -h|--help)
                echo "Kullanım: $0 [seçenekler]"
                echo "Seçenekler:"
                echo "  -w, --wait      VM'lerin tamamen başlamasını bekle"
                echo "  -p, --parallel  VM'leri paralel olarak başlat"
                echo "  -h, --help      Bu yardım mesajını göster"
                exit 0
                ;;
            *)
                echo "Bilinmeyen parametre: $1"
                echo "Yardım için: $0 --help"
                exit 1
                ;;
        esac
    done
    
    echo -e "${BLUE}=== VM Atölyeleri Başlatma İşlemi ===${NC}"
    echo -e "${CYAN}Toplam VM sayısı: ${#machines[@]}${NC}"
    echo -e "${CYAN}Paralel işlem: $([ "$PARALLEL" == "true" ] && echo "Aktif" || echo "Pasif")${NC}"
    echo -e "${CYAN}Boot bekleme: $([ "$WAIT_FOR_BOOT" == "true" ] && echo "Aktif" || echo "Pasif")${NC}"
    echo ""
    
    # Sayaçlar
    local success_count=0
    local error_count=0
    local already_running=0
    
    # İşlem başlangıç zamanı
    local total_start_time=$(date +%s)
    
    if [[ "$PARALLEL" == "true" ]]; then
        echo -e "${YELLOW}Paralel başlatma modu aktif (Maksimum $MAX_JOBS eş zamanlı)${NC}"
        echo ""
        
        # Paralel işlem
        for machine in "${machines[@]}"; do
            # Eş zamanlı job sayısını kontrol et
            while [[ $(jobs -r | wc -l) -ge $MAX_JOBS ]]; do
                sleep 1
            done
            
            # Background'da başlat
            {
                start_vm "$machine"
                local result=$?
                case $result in
                    0) ((success_count++)) ;;
                    1) ((error_count++)) ;;
                    *) ((already_running++)) ;;
                esac
                update_progress
            } &
        done
        
        # Tüm background job'ların bitmesini bekle
        wait
    else
        # Sıralı işlem
        for machine in "${machines[@]}"; do
            start_vm "$machine"
            local result=$?
            case $result in
                0) ((success_count++)) ;;
                1) ((error_count++)) ;;
                *) ((already_running++)) ;;
            esac
            update_progress
            echo ""
        done
    fi
    
    # Toplam süre
    local total_end_time=$(date +%s)
    local total_duration=$((total_end_time - total_start_time))
    
    echo ""
    echo -e "${BLUE}=== İşlem Özeti ===${NC}"
    echo -e "${GREEN}Başarıyla başlatılan: $success_count${NC}"
    echo -e "${YELLOW}Zaten çalışan: $already_running${NC}"
    echo -e "${RED}Hata olan: $error_count${NC}"
    echo -e "${CYAN}Toplam süre: ${total_duration}s${NC}"
    
    echo ""
    echo -e "${BLUE}=== Mevcut VM Durumu ===${NC}"
    virsh list --all | grep -E "$(IFS="|"; echo "${machines[*]}")" || echo "İlgili VM'ler bulunamadı"
    
    # Exit kodu
    if [[ $error_count -eq 0 ]]; then
        echo -e "${GREEN}🎉 Tüm işlemler başarılı!${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️ Bazı VM'lerde sorun yaşandı.${NC}"
        exit 1
    fi
}

# Script'i çalıştır
main "$@"