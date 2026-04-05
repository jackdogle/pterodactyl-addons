#!/bin/bash

# ======================================================================================
#  PTERODACTYL ADDONS PANEL - PROFESSIONAL ENTERPRISE EDITION
#  Ref Fork: https://github.com/MuLTiAcidi/pterodactyl-addons
#  Optimized by Gemini for 8GB RAM VPS
# ======================================================================================

# --- KONFIGURASI WARNA & UI ---
export DEBIAN_FRONTEND=noninteractive
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# --- GLOBAL VARIABLES ---
LOG_FILE="/var/log/ptero_pro_install.log"
INSTALL_DIR="/var/www/pterodactyl"
GITHUB_REPO="https://github.com/jackdogle/pterodactyl-addons"
VERSION="4.0.0-PRO"

# --- FUNGSI DEBUGGING & LOGGER ---
exec 3>&1 # Save stdout
exec 4>&2 # Save stderr

log_init() {
    echo -e "====================================================" > "$LOG_FILE"
    echo -e " PTERODACTYL INSTALLER LOG - $VERSION" >> "$LOG_FILE"
    echo -e " Started: $(date)" >> "$LOG_FILE"
    echo -e "====================================================" >> "$LOG_FILE"
}

log_step() {
    local status=$1
    local message=$2
    echo -e "[$(date '+%H:%M:%S')] [$status] $message" >> "$LOG_FILE"
}

# --- UI COMPONENTS ---
print_header() {
    clear
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  ${BOLD}${WHITE}🚀 PTERODACTYL ADDONS PANEL PRO INSTALLER${NC}                              ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${BLUE}Version: ${VERSION} | Basis: MuLTiAcidi Fork${NC}                             ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo -e ""
}

show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " ${CYAN}%c${NC}  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# --- ENGINE UTILITY ---
execute() {
    local msg=$1
    local cmd=$2
    
    echo -ne "${WHITE} • ${msg}...${NC}"
    log_step "START" "$msg"
    
    # Run command and capture output to log
    eval "$cmd" >> "$LOG_FILE" 2>&1 &
    local pid=$!
    
    show_spinner $pid
    wait $pid
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo -e "\r ${GREEN}✔${NC} ${WHITE}${msg}${NC}           "
        log_step "SUCCESS" "$msg"
    else
        echo -e "\r ${RED}✘${NC} ${RED}${msg} (FAILED)${NC}           "
        log_step "ERROR" "Failed on: $msg | Exit Code: $exit_code"
        echo -e "\n${BOLD}${RED}CRITICAL ERROR DETECTED!${NC}"
        echo -e "${YELLOW}Silakan periksa log di: ${WHITE}$LOG_FILE${NC}"
        echo -e "${YELLOW}Penyebab umum: Koneksi internet atau package lock.${NC}\n"
        exit 1
    fi
}

# --- PRE-INSTALLATION REPAIR ---
pre_flight_check() {
    log_init
    echo -e "${YELLOW}[!] Mempersiapkan Sistem & Memperbaiki Paket Terkunci...${NC}"
    
    # Force unlock APT
    execute "Melepas kunci paket (Apt Lock)" "rm -f /var/lib/dpkg/lock* /var/lib/apt/lists/lock* /var/cache/apt/archives/lock*"
    execute "Konfigurasi ulang paket tertunda" "dpkg --configure -a"
    execute "Pembersihan Repository lama" "apt-get clean && apt-get update -y"
    
    # Hapus NPM lama yang sering bikin stuck
    execute "Menghapus NPM/NodeJS lama (Anti-Conflict)" "apt-get remove -y nodejs npm node-npm-package-arg || true"
}

# --- CORE LOGIC (ORIGINAL ADAPTED) ---
get_configuration() {
    echo -e "\n${CYAN}📑 KONFIGURASI INSTALASI${NC}"
    echo -e "${WHITE}------------------------------------------------${NC}"
    
    read -p "  Domain Panel (e.g panel.id): " FQDN
    [[ -z "$FQDN" ]] && echo -e "${RED}Domain wajib diisi!${NC}" && exit 1
    
    read -p "  Email Administrator: " ADMIN_EMAIL
    read -p "  Nama Panel [DOGLE STORE PANEL]: " PANEL_NAME
    PANEL_NAME=${PANEL_NAME:-"DOGLE STORE PANE"}
    
    read -p "  Password Root MariaDB: " DB_ROOT_PASS
    DB_USER_PASS=$(openssl rand -base64 12)
    
    echo -e "\n${GREEN}Konfigurasi disimpan. Memulai proses optimasi...${NC}\n"
}

install_core_dependencies() {
    echo -e "${CYAN}📦 STEP 1: INSTALASI DEPENDENCIES${NC}"
    
    execute "Update Sistem & Repositori" "apt-get update -y && apt-get upgrade -y"
    execute "Install Alat Dasar (Curl, Git, Zip)" "apt-get install -y software-properties-common curl git unzip zip tar psmisc"
    
    # PHP Repository
    execute "Setup PHP Repository (Ondrej)" "add-apt-repository -y ppa:ondrej/php"
    
    # MariaDB Repository
    execute "Setup MariaDB Repository" "curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash"
    
    # NodeJS & Yarn (Modern Way)
    execute "Setup NodeSource (Node 20)" "curl -fsSL https://deb.nodesource.com/setup_22.x | bash -"
    
    execute "Install Server Stack (Nginx, MariaDB, Redis)" "apt-get update -y && apt-get install -y mariadb-server nginx redis-server nodejs"
    execute "Install PHP 8.3 & Extensions" "apt-get install -y php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,curl,zip,intl,redis,fpm}"
    execute "Install Composer Global" "curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer"
    execute "Install Yarn Global" "npm install --global yarn"
}

setup_database_tuning() {
    echo -e "\n${CYAN}⚙️ STEP 2: TUNING DATABASE (8GB RAM MODE)${NC}"
    
    execute "Mengamankan MariaDB" "mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASS'; FLUSH PRIVILEGES;\""
    
    execute "Optimasi My.cnf (Buffer Pool 2GB)" "
        echo '[mysqld]
        innodb_buffer_pool_size = 2G
        innodb_flush_log_at_trx_commit = 2
        innodb_log_file_size = 512M
        max_connections = 500
        query_cache_limit = 2M
        query_cache_size = 64M' > /etc/mysql/mariadb.conf.d/99-pterodactyl.cnf &&
        systemctl restart mariadb"
        
    execute "Membuat Database Panel" "mysql -u root -p'$DB_ROOT_PASS' -e \"CREATE DATABASE IF NOT EXISTS panel; CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DB_USER_PASS'; GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1'; FLUSH PRIVILEGES;\""
}

download_and_extract() {
    echo -e "\n${CYAN}📂 STEP 3: DOWNLOADING PANEL ASSETS${NC}"
    
    execute "Menyiapkan Direktori" "mkdir -p $INSTALL_DIR && cd $INSTALL_DIR"
    execute "Mengunduh Source (MuLTiAcidi Fork)" "cd $INSTALL_DIR && curl -Lo panel.tar.gz ${GITHUB_REPO}/archive/refs/heads/main.tar.gz"
    execute "Mengekstrak Source Code" "cd $INSTALL_DIR && tar -xzf panel.tar.gz --strip-components=1 && chmod -R 755 storage/* bootstrap/cache/"
}

configure_environment() {
    echo -e "\n${CYAN}🔧 STEP 4: KONFIGURASI ENVIRONMENT${NC}"
    
    execute "Composer Install (Dependencies)" "cd $INSTALL_DIR && COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction"
    execute "Setup .env file" "cd $INSTALL_DIR && cp .env.example .env && php artisan key:generate --force"
    
    execute "Setting App Details" "cd $INSTALL_DIR && 
        php artisan p:environment:setup --author='$ADMIN_EMAIL' --url='https://$FQDN' --timezone='Asia/Jakarta' --cache=redis --session=redis --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379 &&
        php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password='$DB_USER_PASS'"
    
    execute "Migrasi Database & Seeding" "cd $INSTALL_DIR && php artisan migrate --seed --force"
}

build_frontend_assets() {
    echo -e "\n${CYAN}🎨 STEP 5: BUILDING FRONTEND (MODERN UI)${NC}"
    
    execute "Yarn Production Install" "cd $INSTALL_DIR && yarn install --production"
    execute "Compiling Assets (Yarn Build)" "cd $INSTALL_DIR && yarn build:production"
}

finalize_system() {
    echo -e "\n${CYAN}🚀 STEP 6: WEB SERVER & PERMISSIONS${NC}"
    
    execute "Set Permissions (www-data)" "chown -R www-data:www-data $INSTALL_DIR/*"
    
    execute "Configuring Nginx" "
        curl -o /etc/nginx/sites-available/pterodactyl.conf https://raw.githubusercontent.com/pterodactyl/panel/develop/debian/nginx.conf &&
        sed -i 's/<domain>/$FQDN/g' /etc/nginx/sites-available/pterodactyl.conf &&
        sed -i 's|/var/www/pterodactyl|$INSTALL_DIR|g' /etc/nginx/sites-available/pterodactyl.conf &&
        sed -i 's/php8.1-fpm.sock/php8.3-fpm.sock/g' /etc/nginx/sites-available/pterodactyl.conf &&
        ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf &&
        rm -f /etc/nginx/sites-enabled/default &&
        systemctl restart nginx"
        
    execute "Setup Crontab" "(crontab -l 2>/dev/null; echo \"* * * * * php $INSTALL_DIR/artisan schedule:run >> /dev/null 2>&1\") | crontab -"
    
    execute "Setup Queue Worker Service" "
        printf \"[Unit]\nDescription=Pterodactyl Queue Worker\nAfter=redis-server.service\n\n[Service]\nUser=www-data\nGroup=www-data\nRestart=always\nExecStart=/usr/bin/php $INSTALL_DIR/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3\n\n[Install]\nWantedBy=multi-user.target\" > /etc/systemd/system/pteroq.service &&
        systemctl daemon-reload && systemctl enable --now pteroq"
}

print_final_report() {
    clear
    print_header
    echo -e "${GREEN}${BOLD}🎉 INSTALASI SELESAI DENGAN OPTIMAL!${NC}"
    echo -e "${WHITE}------------------------------------------------${NC}"
    echo -e "${CYAN}🌐 URL PANEL      :${NC} ${WHITE}https://$FQDN${NC}"
    echo -e "${CYAN}📧 EMAIL ADMIN    :${NC} ${WHITE}$ADMIN_EMAIL${NC}"
    echo -e "${CYAN}💾 DATABASE USER  :${NC} ${WHITE}pterodactyl${NC}"
    echo -e "${CYAN}🔑 DATABASE PASS  :${NC} ${WHITE}$DB_USER_PASS${NC}"
    echo -e "${WHITE}------------------------------------------------${NC}"
    echo -e "${YELLOW}Catatan: Password Root MariaDB adalah yang Anda masukkan tadi.${NC}"
    echo -e "${YELLOW}Log instalasi lengkap: ${WHITE}$LOG_FILE${NC}"
    echo -e "${GREEN}${BOLD}Silakan buka browser dan akses domain Anda!${NC}\n"
}

# --- MAIN EXECUTION ---
main() {
    check_root() { [[ $EUID -ne 0 ]] && echo "Run as root!" && exit 1; }
    check_root
    
    print_header
    get_configuration
    pre_flight_check
    install_core_dependencies
    setup_database_tuning
    download_and_extract
    configure_environment
    build_frontend_assets
    finalize_system
    print_final_report
}

main
