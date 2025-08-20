#!/bin/bash

# VM Atölyeleri Kapat Script - İyileştirilmiş Versiyon
# Kapatılacak makinelerin isim listesi
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

# Varsayılan ayarlar
SHUTDOWN_TIMEOUT=60
FORCE_SHUTDOWN=false
PARALLEL=false
WAIT_FOR_SHUTDOWN=true
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

# Fonksiyon: VM'in tamamen kapanmasını bekle
wait_for_shutdown() {
    local vm_name="$1"
    local timeout="$2"
    local wait_time=0
    
    echo -e "${CYAN}    [$vm_name] Güvenli kapatma bekleniyor...${NC}"
    
    while [[ $wait_time -lt $timeout ]]; do
        local state=$(check_vm_state "$vm_name")
        if [[ "$state" == "shut off" ]]; then
            echo -e "${GREEN}    [$vm_name] ✓ Güvenli şekilde kapandı (${wait_time}s)${NC}"
            return 0
        elif [[ -z "$state" ]]; then
            echo -e "${YELLOW}    [$vm_name] ⚠️ VM durumu belirlenemedi${NC}"
            return 2
        fi
        
        sleep 2
        ((wait_time += 2))
        
        # Her 15 saniyede progress göster
        if [[ $((wait_time % 15)) -eq 0 ]]; then
            echo -e "${YELLOW}    [$vm_name] Hala bekleniyor... (${wait_time}s/${timeout}s)${NC}"
        fi
    done
    
    echo -e "${YELLOW}    [$vm_name] ⚠️ Güvenli kapatma zaman aşımı${NC}"
    return 1
}

# Fonksiyon: VM'i zorla kapat
force_shutdown_vm() {
    local vm_name="$1"
    
    echo -e "${RED}    [$vm_name] Zorla kapatılıyor...${NC}"
    if virsh destroy "$vm_name" 2>/dev/null; then
        sleep 2
        local state=$(check_vm_state "$vm_name")
        if [[ "$state" == "shut off" ]]; then
            echo -e "${YELLOW}    [$vm_name] ✓ Zorla kapatıldı${NC}"
            return 0
        else
            echo -e "${RED}    [$vm_name] ✗ Zorla kapatma başarısız!${NC}"
            return 1
        fi
    else
        echo -e "${RED}    [$vm_name] ✗ Destroy komutu başarısız!${NC}"
        return 1
    fi
}

# Fonksiyon: Tek VM kapatma
shutdown_vm() {
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
        "shut off")
            echo -e "${GREEN}    [$vm_name] ✓ Zaten kapalı${NC}"
            return 0
            ;;
        "paused")
            echo -e "${YELLOW}    [$vm_name] Duraklatılmış durumda, önce devam ettiriliyor...${NC}"
            virsh resume "$vm_name" 2>/dev/null
            sleep 2
            ;;
        "running")
            echo -e "${YELLOW}    [$vm_name] Çalışıyor, kapatılıyor...${NC}"
            ;;
        "")
            echo -e "${RED}    [$vm_name] ✗ VM durumu belirlenemedi!${NC}"
            return 1
            ;;
        *)
            echo -e "${YELLOW}    [$vm_name] Bilinmeyen durum: $current_state${NC}"
            ;;
    esac
    
    # Güvenli kapatma
    echo -e "${YELLOW}    [$vm_name] Güvenli kapatma komutu gönderiliyor...${NC}"
    if virsh shutdown "$vm_name" 2>/dev/null; then
        echo -e "${GREEN}    [$vm_name] Shutdown komutu başarıyla gönderildi${NC}"
        
        local shutdown_result=0
        
        # Kapatılmasını bekle
        if [[ "$WAIT_FOR_SHUTDOWN" == "true" ]]; then
            wait_for_shutdown "$vm_name" "$SHUTDOWN_TIMEOUT"
            shutdown_result=$?
            
            # Eğer zaman aşımı olduysa ve force aktifse, zorla kapat
            if [[ $shutdown_result -eq 1 && "$FORCE_SHUTDOWN" == "true" ]]; then
                force_shutdown_vm "$vm_name"
                shutdown_result=$?
            fi
        else
            sleep 3
            local new_state=$(check_vm_state "$vm_name")
            if [[ "$new_state" == "shut off" ]]; then
                echo -e "${GREEN}    [$vm_name] ✓ Kapatma işlemi başlatıldı${NC}"
            else
                echo -e "${YELLOW}    [$vm_name] ⚠️ Durum: $new_state${NC}"
                shutdown_result=2
            fi
        fi
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${CYAN}    [$vm_name] İşlem süresi: ${duration}s${NC}"
        
        return $shutdown_result
    else
        echo -e "${RED}    [$vm_name] ✗ Shutdown komutu başarısız!${NC}"
        
        # Force aktifse direkt zorla kapat
        if [[ "$FORCE_SHUTDOWN" == "true" ]]; then
            force_shutdown_vm "$vm_name"
            return $?
        fi
        
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

# Yardım mesajı
show_help() {
    echo "VM Atölyeleri Kapatma Script"
    echo ""
    echo "Kullanım: $0 [seçenekler]"
    echo ""
    echo "Seçenekler:"
    echo "  -f, --force         Güvenli kapatma başarısızsa zorla kapat"
    echo "  -t, --timeout SEC   Güvenli kapatma için bekleme süresi (varsayılan: 60s)"
    echo "  -p, --parallel      VM'leri paralel olarak kapat"
    echo "  -n, --no-wait       Kapatma komutunu gönder, sonucu bekleme"
    echo "  -q, --quick         Hızlı mod: paralel + zorla kapatma"
    echo "  -h, --help          Bu yardım mesajını göster"
    echo ""
    echo "Örnekler:"
    echo "  $0                  # Normal kapatma"
    echo "  $0 --force          # Gerekirse zorla kapat"
    echo "  $0 --parallel --force # Paralel ve zorla kapatma"
    echo "  $0 --quick          # En hızlı kapatma"
}

# Ana fonksiyon
main() {
    # Parametreleri işle
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                FORCE_SHUTDOWN=true
                shift
                ;;
            -t|--timeout)
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    SHUTDOWN_TIMEOUT="$2"
                    shift 2
                else
                    echo "Hata: --timeout için geçerli bir sayı belirtin"
                    exit 1
                fi
                ;;
            -p|--parallel)
                PARALLEL=true
                shift
                ;;
            -n|--no-wait)
                WAIT_FOR_SHUTDOWN=false
                shift
                ;;
            -q|--quick)
                PARALLEL=true
                FORCE_SHUTDOWN=true
                SHUTDOWN_TIMEOUT=30
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Bilinmeyen parametre: $1"
                echo "Yardım için: $0 --help"
                exit 1
                ;;
        esac
    done
    
    echo -e "${BLUE}=== VM Atölyeleri Kapatma İşlemi ===${NC}"
    echo -e "${CYAN}Toplam VM sayısı: ${#machines[@]}${NC}"
    echo -e "${CYAN}Paralel işlem: $([ "$PARALLEL" == "true" ] && echo "Aktif" || echo "Pasif")${NC}"
    echo -e "${CYAN}Zorla kapatma: $([ "$FORCE_SHUTDOWN" == "true" ] && echo "Aktif" || echo "Pasif")${NC}"
    echo -e "${CYAN}Kapatma bekleme: $([ "$WAIT_FOR_SHUTDOWN" == "true" ] && echo "Aktif (${SHUTDOWN_TIMEOUT}s)" || echo "Pasif")${NC}"
    echo ""
    
    # Sayaçlar
    local success_count=0
    local error_count=0
    local already_off=0
    
    # İşlem başlangıç zamanı
    local total_start_time=$(date +%s)
    
    if [[ "$PARALLEL" == "true" ]]; then
        echo -e "${YELLOW}Paralel kapatma modu aktif (Maksimum $MAX_JOBS eş zamanlı)${NC}"
        echo ""
        
        # Paralel işlem
        for machine in "${machines[@]}"; do
            # Eş zamanlı job sayısını kontrol et
            while [[ $(jobs -r | wc -l) -ge $MAX_JOBS ]]; do
                sleep 1
            done
            
            # Background'da kapat
            {
                shutdown_vm "$machine"
                local result=$?
                case $result in
                    0) ((success_count++)) ;;
                    1) ((error_count++)) ;;
                    *) ((already_off++)) ;;
                esac
                update_progress
            } &
        done
        
        # Tüm background job'ların bitmesini bekle
        wait
    else
        # Sıralı işlem
        for machine in "${machines[@]}"; do
            shutdown_vm "$machine"
            local result=$?
            case $result in
                0) ((success_count++)) ;;
                1) ((error_count++)) ;;
                *) ((already_off++)) ;;
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
    echo -e "${GREEN}Başarıyla kapatılan: $success_count${NC}"
    echo -e "${YELLOW}Zaten kapalı: $already_off${NC}"
    echo -e "${RED}Hata olan: $error_count${NC}"
    echo -e "${CYAN}Toplam süre: ${total_duration}s${NC}"
    
    echo ""
    echo -e "${BLUE}=== Son Durum ===${NC}"
    virsh list --all | grep -E "$(IFS="|"; echo "${machines[*]}")" || echo "İlgili VM'ler bulunamadı"
    
    # Exit kodu
    if [[ $error_count -eq 0 ]]; then
        echo -e "${GREEN}🎉 Tüm kapatma işlemleri başarılı!${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️ Bazı VM'lerde sorun yaşandı.${NC}"
        exit 1
    fi
}

# Script'i çalıştır
main "$@"