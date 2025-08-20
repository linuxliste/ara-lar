#!/bin/bash

# VM Atölyeleri Yönetici Script - Birleşik Versiyon
# Tüm VM işlemlerini tek script'ten yönetme aracı

# Altyapı VM'leri (revert olmaz, sadece start/stop)
INFRASTRUCTURE_VMS=(
    "00-ipa.local.lab"
    "00-sat.local.lab"
    "00-util.local.lab"
    "ex374-ansible-controller"
    "ex374-control22.local.lab"
    "00-git.local.lab"
    "00-bastion.local.lab"
    "ex374-hub22.local.lab"
    "rh294admin.local.lab"
)

# Laboratuvar VM'leri (revert yapılabilir)
LAB_VMS=(
    "servera.local.lab"
    "serverb.local.lab"
    "serverc.local.lab"
    "serverd.local.lab"
    "servere.local.lab"
)

# Tüm VM'ler (start/stop işlemleri için)
ALL_VMS=(
    "${INFRASTRUCTURE_VMS[@]}"
    "${LAB_VMS[@]}"
)

# Snapshot ayarları
SNAPSHOT_NAME="lab"

# Renkli çıktı
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Varsayılan ayarlar
SHUTDOWN_TIMEOUT=60
FORCE_SHUTDOWN=false
PARALLEL=false
WAIT_FOR_BOOT=false
WAIT_FOR_SHUTDOWN=true
MAX_JOBS=5

# Progress tracking
PROGRESS_TOTAL=0
PROGRESS_CURRENT=0

# ========================= ORTAK FONKSİYONLAR =========================

# VM durumunu kontrol et
check_vm_state() {
    local vm_name="$1"
    virsh domstate "$vm_name" 2>/dev/null
}

# VM'in mevcut olup olmadığını kontrol et
vm_exists() {
    local vm_name="$1"
    virsh dominfo "$vm_name" >/dev/null 2>&1
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

# ========================= BAŞLATMA FONKSİYONLARI =========================

# VM'in tamamen başlamasını bekle
wait_for_vm_boot() {
    local vm_name="$1"
    local max_wait=60
    local wait_time=0
    
    echo -e "${CYAN}    [$vm_name] Sistem tamamen başlaması bekleniyor...${NC}"
    
    while [[ $wait_time -lt $max_wait ]]; do
        local state=$(check_vm_state "$vm_name")
        if [[ "$state" == "running" ]]; then
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
        
        if [[ $((wait_time % 10)) -eq 0 ]]; then
            echo -e "${YELLOW}    [$vm_name] Hala bekleniyor... (${wait_time}s/${max_wait}s)${NC}"
        fi
    done
    
    echo -e "${YELLOW}    [$vm_name] ⚠️ Zaman aşımı, ancak başlatma komutu gönderildi${NC}"
    return 2
}

# VM başlatma
start_vm() {
    local vm_name="$1"
    local start_time=$(date +%s)
    
    echo -e "${BLUE}[$(date +%H:%M:%S)] $vm_name kontrol ediliyor...${NC}"
    
    if ! vm_exists "$vm_name"; then
        echo -e "${RED}    [$vm_name] ✗ VM bulunamadı!${NC}"
        return 1
    fi
    
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
    
    if virsh start "$vm_name" 2>/dev/null; then
        echo -e "${GREEN}    [$vm_name] Başlatma komutu başarıyla gönderildi${NC}"
        
        local boot_result=0
        if [[ "$WAIT_FOR_BOOT" == "true" ]]; then
            wait_for_vm_boot "$vm_name"
            boot_result=$?
        else
            sleep 2
            local new_state=$(check_vm_state "$vm_name")
            if [[ "$new_state" == "running" ]]; then
                echo -e "${GREEN}    [$vm_name] ✓ Başarıyla başlatıldı${NC}"
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

# ========================= KAPATMA FONKSİYONLARI =========================

# VM'in tamamen kapanmasını bekle
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
        
        if [[ $((wait_time % 15)) -eq 0 ]]; then
            echo -e "${YELLOW}    [$vm_name] Hala bekleniyor... (${wait_time}s/${timeout}s)${NC}"
        fi
    done
    
    echo -e "${YELLOW}    [$vm_name] ⚠️ Güvenli kapatma zaman aşımı${NC}"
    return 1
}

# VM'i zorla kapat
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

# VM güvenli kapatma
safe_shutdown() {
    local vm_name="$1"
    local current_state=$(check_vm_state "$vm_name")
    
    if [[ "$current_state" == "running" ]]; then
        echo -e "${YELLOW}[$vm_name] VM çalışıyor, güvenli kapatma yapılıyor...${NC}"
        virsh shutdown "$vm_name" 2>/dev/null
        
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
        
        echo -e "${YELLOW}[$vm_name] Güvenli kapatma zaman aşımı, zorla kapatılıyor...${NC}"
        virsh destroy "$vm_name" 2>/dev/null
        sleep 2
    fi
}

# VM kapatma
shutdown_vm() {
    local vm_name="$1"
    local start_time=$(date +%s)
    
    echo -e "${BLUE}[$(date +%H:%M:%S)] $vm_name kontrol ediliyor...${NC}"
    
    if ! vm_exists "$vm_name"; then
        echo -e "${RED}    [$vm_name] ✗ VM bulunamadı!${NC}"
        return 1
    fi
    
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
    
    echo -e "${YELLOW}    [$vm_name] Güvenli kapatma komutu gönderiliyor...${NC}"
    if virsh shutdown "$vm_name" 2>/dev/null; then
        echo -e "${GREEN}    [$vm_name] Shutdown komutu başarıyla gönderildi${NC}"
        
        local shutdown_result=0
        
        if [[ "$WAIT_FOR_SHUTDOWN" == "true" ]]; then
            wait_for_shutdown "$vm_name" "$SHUTDOWN_TIMEOUT"
            shutdown_result=$?
            
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
        
        if [[ "$FORCE_SHUTDOWN" == "true" ]]; then
            force_shutdown_vm "$vm_name"
            return $?
        fi
        
        return 1
    fi
}

# ========================= SNAPSHOT FONKSİYONLARI =========================

# VM snapshot'a geri döndürme
revert_vm() {
    local vm_name="$1"
    
    echo -e "${BLUE}[$vm_name] İşlem başlıyor...${NC}"
    
    if ! vm_exists "$vm_name"; then
        echo -e "${RED}[$vm_name] VM bulunamadı! Atlanıyor...${NC}"
        return 1
    fi
    
    if ! virsh snapshot-info "$vm_name" "$SNAPSHOT_NAME" >/dev/null 2>&1; then
        echo -e "${RED}[$vm_name] '$SNAPSHOT_NAME' snapshot'ı bulunamadı! Atlanıyor...${NC}"
        return 1
    fi
    
    safe_shutdown "$vm_name"
    
    echo -e "${YELLOW}[$vm_name] Snapshot'a geri döndürülüyor: $SNAPSHOT_NAME${NC}"
    if virsh snapshot-revert "$vm_name" "$SNAPSHOT_NAME" 2>/dev/null; then
        echo -e "${GREEN}[$vm_name] Başarıyla snapshot'a geri döndürüldü.${NC}"
        
        echo -e "${YELLOW}[$vm_name] Başlatılıyor...${NC}"
        if virsh start "$vm_name" 2>/dev/null; then
            echo -e "${GREEN}[$vm_name] Başarıyla başlatıldı.${NC}"
            
            echo -e "${YELLOW}[$vm_name] Sistem tamamen başlaması bekleniyor...${NC}"
            sleep 5
            
            local current_state=$(check_vm_state "$vm_name")
            if [[ "$current_state" == "running" ]]; then
                echo -e "${GREEN}[$vm_name] ✓ İşlem başarıyla tamamlandı.${NC}"
                return 0
            else
                echo -e "${RED}[$vm_name] ✗ VM başlatıldı ancak durumu beklenmedik: $current_state${NC}"
                return 1
            fi
        else
            echo -e "${RED}[$vm_name] ✗ Başlatılamadı!${NC}"
            return 1
        fi
    else
        echo -e "${RED}[$vm_name] ✗ Snapshot'a geri döndürmede hata oluştu!${NC}"
        return 1
    fi
}

# ========================= ANA FONKSİYONLAR =========================

# VM'leri paralel veya sıralı işle
process_vms() {
    local operation="$1"
    local vm_list=()
    
    # Hangi VM listesini kullanacağını belirle
    case "$operation" in
        "revert")
            vm_list=("${LAB_VMS[@]}")
            echo -e "${CYAN}Sadece laboratuvar VM'leri işlenecek: ${#LAB_VMS[@]} VM${NC}"
            ;;
        *)
            vm_list=("${ALL_VMS[@]}")
            echo -e "${CYAN}Tüm VM'ler işlenecek: ${#ALL_VMS[@]} VM${NC}"
            ;;
    esac
    
    local success_count=0
    local error_count=0
    local already_status=0
    
    PROGRESS_TOTAL=${#vm_list[@]}
    PROGRESS_CURRENT=0
    
    local total_start_time=$(date +%s)
    
    if [[ "$PARALLEL" == "true" ]]; then
        echo -e "${YELLOW}Paralel işlem modu aktif (Maksimum $MAX_JOBS eş zamanlı)${NC}"
        echo ""
        
        for vm in "${vm_list[@]}"; do
            while [[ $(jobs -r | wc -l) -ge $MAX_JOBS ]]; do
                sleep 1
            done
            
            {
                case "$operation" in
                    "start") start_vm "$vm" ;;
                    "shutdown") shutdown_vm "$vm" ;;
                    "revert") revert_vm "$vm" ;;
                esac
                
                local result=$?
                case $result in
                    0) ((success_count++)) ;;
                    1) ((error_count++)) ;;
                    *) ((already_status++)) ;;
                esac
                update_progress
            } &
        done
        
        wait
    else
        for vm in "${vm_list[@]}"; do
            case "$operation" in
                "start") start_vm "$vm" ;;
                "shutdown") shutdown_vm "$vm" ;;
                "revert") revert_vm "$vm" ;;
            esac
            
            local result=$?
            case $result in
                0) ((success_count++)) ;;
                1) ((error_count++)) ;;
                *) ((already_status++)) ;;
            esac
            update_progress
            echo ""
        done
    fi
    
    local total_end_time=$(date +%s)
    local total_duration=$((total_end_time - total_start_time))
    
    echo ""
    echo -e "${BLUE}=== İşlem Özeti ===${NC}"
    echo -e "${GREEN}Başarılı: $success_count${NC}"
    echo -e "${YELLOW}Zaten uygun durumda: $already_status${NC}"
    echo -e "${RED}Hatalı: $error_count${NC}"
    echo -e "${CYAN}Toplam süre: ${total_duration}s${NC}"
    
    return $error_count
}

# VM durumlarını listele
list_vms() {
    echo -e "${BLUE}=== VM Durumları ===${NC}"
    echo ""
    
    local running=0
    local stopped=0
    local other=0
    
    echo -e "${MAGENTA}--- Altyapı VM'leri ---${NC}"
    for vm in "${INFRASTRUCTURE_VMS[@]}"; do
        if vm_exists "$vm"; then
            local state=$(check_vm_state "$vm")
            case "$state" in
                "running")
                    echo -e "${GREEN}✓ $vm - Çalışıyor${NC}"
                    ((running++))
                    ;;
                "shut off")
                    echo -e "${RED}✗ $vm - Kapalı${NC}"
                    ((stopped++))
                    ;;
                "paused")
                    echo -e "${YELLOW}⏸ $vm - Duraklatılmış${NC}"
                    ((other++))
                    ;;
                *)
                    echo -e "${CYAN}? $vm - $state${NC}"
                    ((other++))
                    ;;
            esac
        else
            echo -e "${RED}! $vm - Bulunamadı${NC}"
            ((other++))
        fi
    done
    
    echo ""
    echo -e "${MAGENTA}--- Laboratuvar VM'leri ---${NC}"
    for vm in "${LAB_VMS[@]}"; do
        if vm_exists "$vm"; then
            local state=$(check_vm_state "$vm")
            case "$state" in
                "running")
                    echo -e "${GREEN}✓ $vm - Çalışıyor${NC}"
                    ((running++))
                    ;;
                "shut off")
                    echo -e "${RED}✗ $vm - Kapalı${NC}"
                    ((stopped++))
                    ;;
                "paused")
                    echo -e "${YELLOW}⏸ $vm - Duraklatılmış${NC}"
                    ((other++))
                    ;;
                *)
                    echo -e "${CYAN}? $vm - $state${NC}"
                    ((other++))
                    ;;
            esac
        else
            echo -e "${RED}! $vm - Bulunamadı${NC}"
            ((other++))
        fi
    done
    
    echo ""
    echo -e "${BLUE}=== Özet ===${NC}"
    echo -e "${GREEN}Çalışan: $running${NC}"
    echo -e "${RED}Kapalı: $stopped${NC}"
    echo -e "${YELLOW}Diğer: $other${NC}"
    echo -e "${CYAN}Altyapı VM: ${#INFRASTRUCTURE_VMS[@]}${NC}"
    echo -e "${CYAN}Laboratuvar VM: ${#LAB_VMS[@]}${NC}"
    echo -e "${CYAN}Toplam: ${#ALL_VMS[@]}${NC}"
}

# Yardım mesajı
show_help() {
    echo -e "${BLUE}VM Atölyeleri Yönetici Script${NC}"
    echo ""
    echo -e "${CYAN}Kullanım: $0 <komut> [seçenekler]${NC}"
    echo ""
    echo -e "${YELLOW}Komutlar:${NC}"
    echo "  start       Tüm VM'leri başlat"
    echo "  stop        Tüm VM'leri kapat"
    echo "  restart     Tüm VM'leri yeniden başlat"
    echo "  revert      Sadece laboratuvar VM'lerini snapshot'a geri döndür"
    echo "  status      VM durumlarını listele"
    echo "  list        VM durumlarını detaylı göster"
    echo ""
    echo -e "${YELLOW}Genel Seçenekler:${NC}"
    echo "  -p, --parallel      Paralel işlem"
    echo "  -h, --help          Yardım mesajı"
    echo ""
    echo -e "${YELLOW}Başlatma Seçenekleri:${NC}"
    echo "  -w, --wait          VM'lerin tamamen başlamasını bekle"
    echo ""
    echo -e "${YELLOW}Kapatma Seçenekleri:${NC}"
    echo "  -f, --force         Gerekirse zorla kapat"
    echo "  -t, --timeout SEC   Güvenli kapatma timeout (varsayılan: 60s)"
    echo "  -n, --no-wait       Kapatma sonucunu bekleme"
    echo "  -q, --quick         Hızlı mod (paralel + zorla)"
    echo ""
    echo -e "${YELLOW}Örnekler:${NC}"
    echo "  $0 start                    # VM'leri başlat"
    echo "  $0 start --parallel --wait  # Paralel başlat ve bekle"
    echo "  $0 stop --force             # Zorla kapat"
    echo "  $0 stop --quick             # Hızlı kapatma"
    echo "  $0 restart --parallel       # Paralel yeniden başlat"
    echo "  $0 revert                   # Snapshot'a geri döndür"
    echo "  $0 status                   # Durum göster"
}

# Ana fonksiyon
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    local command="$1"
    shift
    
    # Parametreleri işle
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--parallel)
                PARALLEL=true
                shift
                ;;
            -w|--wait)
                WAIT_FOR_BOOT=true
                shift
                ;;
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
    
    # Komutları işle
    case "$command" in
        start|başlat)
            echo -e "${BLUE}=== VM Atölyeleri Başlatma İşlemi ===${NC}"
            echo -e "${CYAN}Altyapı VM sayısı: ${#INFRASTRUCTURE_VMS[@]}${NC}"
            echo -e "${CYAN}Laboratuvar VM sayısı: ${#LAB_VMS[@]}${NC}"
            echo -e "${CYAN}Toplam VM sayısı: ${#ALL_VMS[@]}${NC}"
            echo -e "${CYAN}Paralel işlem: $([ "$PARALLEL" == "true" ] && echo "Aktif" || echo "Pasif")${NC}"
            echo -e "${CYAN}Boot bekleme: $([ "$WAIT_FOR_BOOT" == "true" ] && echo "Aktif" || echo "Pasif")${NC}"
            echo ""
            
            process_vms "start"
            local exit_code=$?
            
            echo ""
            virsh list --all | grep -E "$(IFS="|"; echo "${ALL_VMS[*]}")" || echo "İlgili VM'ler bulunamadı"
            
            if [[ $exit_code -eq 0 ]]; then
                echo -e "${GREEN}🎉 Tüm işlemler başarılı!${NC}"
            else
                echo -e "${YELLOW}⚠️ Bazı VM'lerde sorun yaşandı.${NC}"
            fi
            exit $exit_code
            ;;
            
        stop|kapat)
            echo -e "${BLUE}=== VM Atölyeleri Kapatma İşlemi ===${NC}"
            echo -e "${CYAN}Altyapı VM sayısı: ${#INFRASTRUCTURE_VMS[@]}${NC}"
            echo -e "${CYAN}Laboratuvar VM sayısı: ${#LAB_VMS[@]}${NC}"
            echo -e "${CYAN}Toplam VM sayısı: ${#ALL_VMS[@]}${NC}"
            echo -e "${CYAN}Paralel işlem: $([ "$PARALLEL" == "true" ] && echo "Aktif" || echo "Pasif")${NC}"
            echo -e "${CYAN}Zorla kapatma: $([ "$FORCE_SHUTDOWN" == "true" ] && echo "Aktif" || echo "Pasif")${NC}"
            echo -e "${CYAN}Kapatma bekleme: $([ "$WAIT_FOR_SHUTDOWN" == "true" ] && echo "Aktif (${SHUTDOWN_TIMEOUT}s)" || echo "Pasif")${NC}"
            echo ""
            
            process_vms "shutdown"
            local exit_code=$?
            
            echo ""
            virsh list --all | grep -E "$(IFS="|"; echo "${ALL_VMS[*]}")" || echo "İlgili VM'ler bulunamadı"
            
            if [[ $exit_code -eq 0 ]]; then
                echo -e "${GREEN}🎉 Tüm kapatma işlemleri başarılı!${NC}"
            else
                echo -e "${YELLOW}⚠️ Bazı VM'lerde sorun yaşandı.${NC}"
            fi
            exit $exit_code
            ;;
            
        restart|yeniden|yenidenbaslat)
            echo -e "${BLUE}=== VM Atölyeleri Yeniden Başlatma İşlemi ===${NC}"
            echo ""
            
            # Önce kapat
            echo -e "${YELLOW}1. Aşama: Tüm VM'ler kapatılıyor...${NC}"
            WAIT_FOR_SHUTDOWN=true
            process_vms "shutdown"
            
            echo ""
            sleep 3
            
            # Sonra başlat
            echo -e "${YELLOW}2. Aşama: Tüm VM'ler başlatılıyor...${NC}"
            process_vms "start"
            local exit_code=$?
            
            echo ""
            virsh list --all | grep -E "$(IFS="|"; echo "${ALL_VMS[*]}")" || echo "İlgili VM'ler bulunamadı"
            
            if [[ $exit_code -eq 0 ]]; then
                echo -e "${GREEN}🎉 Yeniden başlatma işlemi başarılı!${NC}"
            else
                echo -e "${YELLOW}⚠️ Bazı VM'lerde sorun yaşandı.${NC}"
            fi
            exit $exit_code
            ;;
            
        revert|geridon|snapshot)
            echo -e "${BLUE}=== Laboratuvar VM'leri Snapshot'a Geri Döndürme İşlemi ===${NC}"
            echo -e "${CYAN}Snapshot: $SNAPSHOT_NAME${NC}"
            echo -e "${CYAN}Sadece laboratuvar VM'leri işlenecek: ${#LAB_VMS[@]} VM${NC}"
            echo -e "${YELLOW}Not: Altyapı VM'leri (${#INFRASTRUCTURE_VMS[@]} VM) snapshot'a geri döndürülmeyecek${NC}"
            echo ""
            
            process_vms "revert"
            local exit_code=$?
            
            echo ""
            echo -e "${BLUE}=== Laboratuvar VM'leri Son Durum ===${NC}"
            virsh list --all | grep -E "$(IFS="|"; echo "${LAB_VMS[*]}")" || echo "Laboratuvar VM'leri bulunamadı"
            
            if [[ $exit_code -eq 0 ]]; then
                echo -e "${GREEN}🎉 Tüm laboratuvar VM'leri başarıyla işlendi!${NC}"
            else
                echo -e "${YELLOW}⚠️ Bazı laboratuvar VM'lerinde sorun yaşandı.${NC}"
            fi
            exit $exit_code
            ;;
            
        status|durum)
            echo -e "${BLUE}=== Hızlı Durum Özeti ===${NC}"
            virsh list --all | grep -E "$(IFS="|"; echo "${ALL_VMS[*]}")" || echo "İlgili VM'ler bulunamadı"
            ;;
            
        list|listele)
            list_vms
            ;;
            
        help|yardim)
            show_help
            ;;
            
        *)
            echo -e "${RED}Bilinmeyen komut: $command${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Script'i çalıştır
main "$@"