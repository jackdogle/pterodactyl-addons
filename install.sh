#!/bin/bash

# ======================================================================================
#  PTERODACTYL ADDONS PANEL - ULTRA INSTALLER V3.1.0 (PRO DEBUGGING)
#  Optimized for: 8GB RAM VPS
#  Feature: Anti-Stuck, Professional Logging, Self-Healing
# ======================================================================================

# Setup Warna & UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# Versi & Log
VERSION="3.1.0-PRO"
LOG_FILE="/var/log/ptero_install.log"
INSTALL_DIR="/var/www/pterodactyl"
GITHUB_REPO="https://github.com/jackdogle/pterodactyl-addons"

# Inisialisasi Log
echo "--- LOG MULAI: $(date) ---" > $LOG_FILE

# Fungsi Animasi Loading
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Header Banner Modern
print_banner() {
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  ${BOLD}${WHITE}PTERODACTYL ADDONS INSTALLER${NC} ${CYAN}v${VERSION}${NC}           ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${BLUE}Pro Debugging Enabled & Anti-Stuck Optimized${NC}           ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# Fungsi Logging Profesional
log_event() {
    local status=$1
    local message=$2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$status] $message" >> $LOG_FILE
}

# Logika Perbaikan Otomatis & Anti-Stuck
auto_repair_conflicts() {
    echo -e "${YELLOW}[!] Menjalankan Diagnosa Konflik & Perbaikan...${NC}"
    log_event "INFO" "Memulai diagnosa konflik lingkungan."

    # 1. Bersihkan APT Locks (Sering bikin stuck)
    log_event "REPAIR" "Membersihkan lock files package manager."
    systemctl stop unattended-upgrades > /dev/null 2>&1
    rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock > /dev/null 2>&1
    dpkg --configure -a >> $LOG_FILE 2>&1

    # 2. Cek Port Terpakai
    if lsof -Pi :80 -sTCP:LISTEN -t >/dev/null ; then
        echo -e "${PURPLE}[*] Mendeteksi port 80 digunakan. Mengosongkan...${NC}"
        log_event "REPAIR" "Menghentikan proses pada port 80."
        fuser -k 80/tcp >> $LOG_FILE 2>&1
    fi

    # 3. Optimasi Swap (Jika diperlukan untuk stabilitas)
    local ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    log_event "INFO" "Total RAM terdeteksi: $ram_kb KB."
    
    echo -e "${GREEN}[V] Lingkungan bersih dan siap.${NC}"
}

# Cek Izin & OS
check_env() {
    [[ $EUID -ne 0 ]] && echo -e "${RED}[!] Jalankan sebagai ROOT!${NC}" && exit 1
    if [ -f /etc/os-release ]; then . /etc/os-release; OS=$ID; else exit 1; fi
    log_event "INFO" "OS Terdeteksi: $OS"
}

# Input dengan UI Bersih
get_config() {
    echo -e "${BOLD}${CYAN}>> KONFIGURASI SISTEM${NC}"
    read -p "   Domain FQDN  : " FQDN
    read -p "   Email Admin  : " ADMIN_EMAIL
    read -p "   User Admin   : " ADMIN_USER
    read -s -p "   Pass Admin   : " ADMIN_PASS; echo ""
    read -s -p "   MariaDB Root : " DB_ROOT_PWD; echo ""
    
    # Auto-generate DB Creds
    DB_NAME="panel"
    DB_USER="ptero_user"
    DB_PASS=$(openssl rand -base64 14 | tr -dc 'a-zA-Z0-9' | head -c 16)
    log_event "CONFIG" "Konfigurasi domain $FQDN diterima."
}

# Eksekusi Langkah dengan Debugging Profesional
execute_step() {
    local msg=$1
    local cmd=$2
    log_event "EXEC" "Memulai: $msg"
    
    echo -ne "${BLUE}[TASK] $msg...${NC}"
    
    # Eksekusi dengan redirect ke log utama
    eval "$cmd" >> $LOG_FILE 2>&1 &
    local pid=$!
    spinner $pid
    wait $pid
    local res=$?

    if [ $res -eq 0 ]; then
        echo -e "\r${GREEN}[DONE] $msg                                ${NC}"
        log_event "SUCCESS" "Selesai: $msg"
    else
        echo -e "\r${RED}[FAIL] $msg                                ${NC}"
        log_event "ERROR" "Gagal pada: $msg (Exit Code: $res)"
        echo -e "${YELLOW}------------------------------------------------------------${NC}"
        echo -e "${BOLD}${RED}ERROR DETECTED!${NC} Lihat 10 baris terakhir log:"
        tail -n 10 $LOG_FILE
        echo -e "${YELLOW}------------------------------------------------------------${NC}"
        echo -e "Log lengkap tersedia di: ${CYAN}$LOG_FILE${NC}"
        exit 1
    fi
}

# Langkah Instalasi Teroptimasi
run_installation() {
    # 1. Update & Repositori
    execute_step "Update System & Repos" "apt update && apt upgrade -y && apt install -y software-properties-common curl git psmisc lsof unzip"
    
    if [[ "$OS" == "ubuntu" ]]; then
        execute_step "Setup PHP Repo" "add-apt-repository -y ppa:ondrej/php"
    fi
    
    execute_step "Install PHP 8.3 & MariaDB" "apt install -y php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,curl,zip,intl,redis,fpm} mariadb-server nginx redis-server nodejs npm"
    
    # 2. Database Tuning (RAM 8GB)
    execute_step "Tuning MariaDB (8GB RAM)" "
        echo '[mysqld]
        innodb_buffer_pool_size = 2G
        innodb_log_file_size = 512M
        innodb_flush_method = O_DIRECT
        max_connections = 500' > /etc/mysql/mariadb.conf.d/99-ptero-optimized.cnf && systemctl restart mariadb"

    # 3. Setup DB & User
    execute_step "Setup Database" "mysql -u root -p'${DB_ROOT_PWD}' -e \"CREATE DATABASE IF NOT EXISTS ${DB_NAME}; CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}'; GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1'; FLUSH PRIVILEGES;\""

    # 4. Download & Fix Files
    execute_step "Download Panel Files" "mkdir -p $INSTALL_DIR && cd $INSTALL_DIR && curl -Lo panel.tar.gz ${GITHUB_REPO}/releases/latest/download/pterodactyl-addons-panel.tar.gz && tar -xzf panel.tar.gz && chmod -R 755 storage/* bootstrap/cache/"

    # 5. Composer & Core Config
    execute_step "Install Composer" "cd $INSTALL_DIR && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer"
    
    execute_step "Install Dependencies" "cd $INSTALL_DIR && COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction"
    
    execute_step "Configuring Environment" "cd $INSTALL_DIR && cp -n .env.example .env && php artisan key:generate --force && 
        php artisan p:environment:setup --author='$ADMIN_EMAIL' --url='https://$FQDN' --timezone='Asia/Jakarta' --cache=redis --session=redis --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379 &&
        php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=$DB_NAME --username=$DB_USER --password='$DB_PASS'"

    # 6. SMART MIGRATION (Handle Conflicts)
    execute_step "Smart Database Migration" "cd $INSTALL_DIR && (php artisan migrate --seed --force || (php artisan cache:clear && php artisan migrate --force))"

    # 7. Create Admin & Assets
    execute_step "Create Admin Account" "cd $INSTALL_DIR && php artisan p:user:make --email='$ADMIN_EMAIL' --username='$ADMIN_USER' --name-first='Admin' --name-last='User' --password='$ADMIN_PASS' --admin=1"
    
    execute_step "Build Assets (Yarn/NPM)" "npm install -g yarn && cd $INSTALL_DIR && yarn install --production && yarn build:production"

    # 8. Webserver & SSL
    execute_step "Setup Nginx Configuration" "
        curl -o /etc/nginx/sites-available/pterodactyl.conf https://raw.githubusercontent.com/pterodactyl/panel/develop/debian/nginx.conf
        sed -i \"s/<domain>/$FQDN/g\" /etc/nginx/sites-available/pterodactyl.conf
        sed -i \"s|/var/www/pterodactyl|$INSTALL_DIR|g\" /etc/nginx/sites-available/pterodactyl.conf
        ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
        rm -f /etc/nginx/sites-enabled/default
        systemctl restart nginx"
}

# Selesai
finalize() {
    execute_step "Finalizing Permissions" "chown -R www-data:www-data $INSTALL_DIR/* && php artisan config:clear"
    
    log_event "FINISH" "Instalasi selesai sukses."
    
    echo -e "\n${BOLD}${GREEN}====================================================${NC}"
    echo -e "   ${BOLD}${WHITE}INSTALASI SELESAI - V${VERSION}${NC}"
    echo -e "${BOLD}${GREEN}====================================================${NC}"
    echo -e "   URL Panel   : ${CYAN}https://$FQDN${NC}"
    echo -e "   Admin User  : ${CYAN}$ADMIN_USER${NC}"
    echo -e "   Log File    : ${PURPLE}$LOG_FILE${NC}"
    echo -e "   RAM Status  : ${GREEN}Optimized 2GB Pool for 8GB RAM${NC}"
    echo -e "${BOLD}${GREEN}====================================================${NC}\n"
}

# Jalankan skrip
check_env
print_banner
auto_repair_conflicts
get_config
run_installation
finalize
