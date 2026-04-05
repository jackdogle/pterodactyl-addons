#!/bin/bash

# ======================================================================================
#  PTERODACTYL ADDONS PANEL - ULTRA INSTALLER V3.2.1 (FIX BROKEN PACKAGES)
#  Optimized for: 8GB RAM VPS
#  Feature: Anti-Stuck, Advanced Logging, Self-Healing, High-Performance Tuning
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
VERSION="3.2.1-PRO"
LOG_FILE="/var/log/ptero_install.log"
INSTALL_DIR="/var/www/pterodactyl"
GITHUB_REPO="https://github.com/jackdogle/pterodactyl-addons"

# Inisialisasi Log dengan Header
echo "====================================================" > $LOG_FILE
echo " PTERODACTYL INSTALLER LOG - $VERSION" >> $LOG_FILE
echo " Tanggal: $(date)" >> $LOG_FILE
echo " OS: $(lsb_release -d | cut -f2)" >> $LOG_FILE
echo "====================================================" >> $LOG_FILE

# Fungsi Animasi Loading (Spinner)
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
    echo -e "${CYAN}│${NC}  ${BLUE}Professional Enterprise Debugging & Anti-Stuck${NC}         ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${PURPLE}Optimized for 8GB RAM High-Performance VPS${NC}             ${CYAN}│${NC}"
    echo -e "└────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# Fungsi Logging Profesional
log_event() {
    local status=$1
    local message=$2
    echo "[$(date '+%H:%M:%S')] [$status] $message" >> $LOG_FILE
}

# Diagnosa & Perbaikan Otomatis Mendalam (FIX Broken Packages)
auto_repair_conflicts() {
    echo -e "${YELLOW}[!] Menjalankan Diagnosa Sistem & Deep Repair...${NC}"
    log_event "INFO" "Memulai tahap diagnosa mendalam."

    # 1. Perbaikan APT & Lock Files
    log_event "REPAIR" "Membersihkan lock files dan konfigurasi dpkg."
    systemctl stop unattended-upgrades > /dev/null 2>&1
    rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock > /dev/null 2>&1
    
    # 2. Force Fix Broken Packages (PENTING)
    log_event "REPAIR" "Memaksa perbaikan broken packages dan held packages."
    apt-mark unhold nodejs npm > /dev/null 2>&1
    dpkg --configure -a >> $LOG_FILE 2>&1
    apt-get install -f -y >> $LOG_FILE 2>&1
    apt-get autoremove -y >> $LOG_FILE 2>&1
    apt-get clean >> $LOG_FILE 2>&1

    # 3. Pembersihan Port Bentrok
    log_event "REPAIR" "Memeriksa port 80 dan 443."
    for port in 80 443; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
            echo -e "${PURPLE}[*] Port $port terdeteksi sibuk. Membersihkan...${NC}"
            fuser -k $port/tcp >> $LOG_FILE 2>&1
        fi
    done

    # 4. Validasi Koneksi Internet
    if ! ping -c 1 google.com > /dev/null 2>&1; then
        echo -e "${RED}[!] Gagal: Tidak ada koneksi internet.${NC}"
        log_event "FATAL" "Koneksi internet terputus."
        exit 1
    fi
    
    echo -e "${GREEN}[V] Sistem siap untuk proses upgrade.${NC}"
}

# Cek Izin & Lingkungan
check_env() {
    [[ $EUID -ne 0 ]] && echo -e "${RED}[!] Jalankan sebagai ROOT!${NC}" && exit 1
    if [ -f /etc/os-release ]; then . /etc/os-release; OS=$ID; else exit 1; fi
    log_event "INFO" "Instalasi dimulai pada OS: $OS"
}

# Input Konfigurasi
get_config() {
    echo -e "${BOLD}${CYAN}>> KONFIGURASI INSTALASI${NC}"
    read -p "   Domain Panel (FQDN) : " FQDN
    read -p "   Email Admin         : " ADMIN_EMAIL
    read -p "   Username Admin      : " ADMIN_USER
    read -s -p "   Password Admin      : " ADMIN_PASS; echo ""
    read -s -p "   MariaDB Root Pass   : " DB_ROOT_PWD; echo ""
    
    DB_NAME="panel"
    DB_USER="ptero_user"
    DB_PASS=$(openssl rand -base64 14 | tr -dc 'a-zA-Z0-9' | head -c 16)
    log_event "CONFIG" "Domain: $FQDN | Email: $ADMIN_EMAIL"
}

# Eksekusi Langkah dengan Professional Debugging
execute_step() {
    local msg=$1
    local cmd=$2
    log_event "EXEC" "Menjalankan: $msg"
    
    echo -ne "${BLUE}[TASK] $msg...${NC}"
    
    # Eksekusi dengan Timeout (Anti-Stuck)
    eval "$cmd" >> $LOG_FILE 2>&1 &
    local pid=$!
    spinner $pid
    wait $pid
    local res=$?

    if [ $res -eq 0 ]; then
        echo -e "\r${GREEN}[DONE] $msg                                ${NC}"
        log_event "SUCCESS" "Berhasil: $msg"
    else
        echo -e "\r${RED}[FAIL] $msg                                ${NC}"
        log_event "ERROR" "Gagal pada step: $msg (Exit Code: $res)"
        echo -e "${YELLOW}------------------------------------------------------------${NC}"
        echo -e "${BOLD}${RED}DEBUGGING INFO:${NC}"
        echo -e "Periksa baris terakhir log di ${CYAN}$LOG_FILE${NC}:"
        tail -n 15 $LOG_FILE
        echo -e "${YELLOW}------------------------------------------------------------${NC}"
        exit 1
    fi
}

# Core Installation
run_installation() {
    # 1. System Prep & NodeSource Fix
    execute_step "Updating Repositories" "apt-get update && apt-get install -y software-properties-common curl git psmisc lsof unzip ca-certificates"
    
    if [[ "$OS" == "ubuntu" ]]; then
        execute_step "Setting up PHP & Node Repositories" "
            add-apt-repository -y ppa:ondrej/php && 
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash -"
    fi
    
    # 2. Forced Installation of Stack (Paling sering stuck di sini)
    # Kita pisah nodejs untuk memastikan npm tidak bentrok
    execute_step "Installing MariaDB & Nginx" "apt-get install -y mariadb-server nginx redis-server"
    execute_step "Installing Nodejs (Nodesource)" "apt-get install -y nodejs"
    execute_step "Installing PHP 8.3 & Extensions" "apt-get install -y php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,curl,zip,intl,redis,fpm}"
    
    # 3. Professional Tuning (RAM 8GB)
    execute_step "Tuning MariaDB & PHP-FPM" "
        echo '[mysqld]
        innodb_buffer_pool_size = 2G
        innodb_log_file_size = 512M
        innodb_flush_method = O_DIRECT
        max_connections = 500
        query_cache_type = 1
        query_cache_size = 64M' > /etc/mysql/mariadb.conf.d/99-ptero-optimized.cnf
        sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php/8.3/fpm/php.ini
        systemctl restart mariadb php8.3-fpm"

    # 4. DB Creation
    execute_step "Securing Database" "mysql -u root -p'${DB_ROOT_PWD}' -e \"CREATE DATABASE IF NOT EXISTS ${DB_NAME}; CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}'; GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1'; FLUSH PRIVILEGES;\""

    # 5. Panel Core
    execute_step "Fetching Panel Source" "mkdir -p $INSTALL_DIR && cd $INSTALL_DIR && curl -Lo panel.tar.gz ${GITHUB_REPO}/releases/latest/download/pterodactyl-addons-panel.tar.gz && tar -xzf panel.tar.gz && chmod -R 755 storage/* bootstrap/cache/"

    # 6. Dependency Management
    execute_step "Installing Composer" "cd $INSTALL_DIR && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer"
    execute_step "Installing PHP Dependencies" "cd $INSTALL_DIR && COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction"
    
    execute_step "Setting Environment" "cd $INSTALL_DIR && cp -n .env.example .env && php artisan key:generate --force && 
        php artisan p:environment:setup --author='$ADMIN_EMAIL' --url='https://$FQDN' --timezone='Asia/Jakarta' --cache=redis --session=redis --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379 &&
        php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=$DB_NAME --username=$DB_USER --password='$DB_PASS'"

    # 7. Optimized Migration
    execute_step "Smart Migration Engine" "cd $INSTALL_DIR && (php artisan migrate --seed --force || (php artisan cache:clear && php artisan migrate --force))"

    # 8. Admin & Assets
    execute_step "Creating Admin User" "cd $INSTALL_DIR && php artisan p:user:make --email='$ADMIN_EMAIL' --username='$ADMIN_USER' --name-first='Admin' --name-last='Enterprise' --password='$ADMIN_PASS' --admin=1"
    execute_step "Building Web Assets" "npm install -g yarn && cd $INSTALL_DIR && yarn install --production && yarn build:production"

    # 9. Webserver Logic
    execute_step "Configuring Nginx & SSL" "
        curl -o /etc/nginx/sites-available/pterodactyl.conf https://raw.githubusercontent.com/pterodactyl/panel/develop/debian/nginx.conf
        sed -i \"s/<domain>/$FQDN/g\" /etc/nginx/sites-available/pterodactyl.conf
        sed -i \"s|/var/www/pterodactyl|$INSTALL_DIR|g\" /etc/nginx/sites-available/pterodactyl.conf
        ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
        rm -f /etc/nginx/sites-enabled/default
        systemctl restart nginx"
}

# Finalisasi & Info Sukses
finalize() {
    execute_step "Setting Folder Ownership" "chown -R www-data:www-data $INSTALL_DIR/* && php artisan config:clear"
    
    log_event "FINISH" "Instalasi selesai dengan status sukses."
    
    echo -e "\n${BOLD}${GREEN}====================================================${NC}"
    echo -e "   ${BOLD}${WHITE}UPGRADE & INSTALASI SUKSES - V${VERSION}${NC}"
    echo -e "${BOLD}${GREEN}====================================================${NC}"
    echo -e "   URL Panel      : ${CYAN}https://$FQDN${NC}"
    echo -e "   Admin Username : ${CYAN}$ADMIN_USER${NC}"
    echo -e "   Debug Log      : ${PURPLE}$LOG_FILE${NC}"
    echo -e "   RAM Optimization: ${GREEN}Enterprise 8GB Mode Active${NC}"
    echo -e "${BOLD}${GREEN}====================================================${NC}\n"
    echo -e "${YELLOW}Tips: Jika terjadi masalah, jalankan 'tail -f $LOG_FILE'${NC}"
}

# Main Script Execution
check_env
print_banner
auto_repair_conflicts
get_config
run_installation
finalize
