#!/bin/bash

# ======================================================================================
#  PTERODACTYL ADDONS PANEL - ENTERPRISE INSTALLER V4.0.0
#  Ref Fork: https://github.com/MuLTiAcidi/pterodactyl-addons
#  Feature: Advanced Terminal UI | 8GB RAM Optimized | Anti-Stuck | Deep Debugging
# ======================================================================================

# Memaksa APT agar tidak interaktif (Anti-Stuck pada prompt package)
export DEBIAN_FRONTEND=noninteractive

# ==========================================
# 1. SETUP UI, WARNA, DAN VARIABEL
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

VERSION="4.0.0-ENTERPRISE"
LOG_FILE="/var/log/ptero_install_v4.log"
INSTALL_DIR="/var/www/pterodactyl"
GITHUB_URL="https://github.com/jackdogle/pterodactyl-addons"
CURRENT_STEP=0
TOTAL_STEPS=22

# Inisialisasi File Log Professional
cat <<EOF > "$LOG_FILE"
======================================================================
 PTERODACTYL ENTERPRISE INSTALLER LOG
 Versi   : $VERSION
 Tanggal : $(date '+%Y-%m-%d %H:%M:%S')
 Sistem  : $(uname -a)
 Source  : $GITHUB_URL
======================================================================
EOF

# ==========================================
# 2. UI ENGINE & PROFESSIONAL DEBUGGING
# ==========================================

print_banner() {
    clear
    echo -e "${CYAN}╭────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC} ${BOLD}${WHITE} PTERODACTYL ADDONS PANEL - ADVANCED INSTALLER ${NC}                     ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${DIM} Versi: $VERSION | Base: MuLTiAcidi Fork${NC}                          ${CYAN}│${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}✔ Anti-Stuck Engine${NC}   ${YELLOW}✔ 8GB RAM Optimized${NC}   ${PURPLE}✔ Professional Debugging${NC} ${CYAN}│${NC}"
    echo -e "${CYAN}╰────────────────────────────────────────────────────────────────────────╯${NC}\n"
}

# Advanced Spinner dengan Step Counter
spinner() {
    local pid=$1
    local msg=$2
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local temp
    
    while kill -0 $pid 2>/dev/null; do
        temp=${spinstr#?}
        printf "\r${CYAN} [%c]${NC} ${WHITE}%s${NC}..." "$spinstr" "$msg"
        local spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
    done
}

# Eksekutor Anti-Stuck dengan Advanced Error Handling
run_step() {
    local msg=$1
    local cmd=$2
    ((CURRENT_STEP++))
    
    # Logging
    echo -e "\n[$(date '+%H:%M:%S')] [STEP $CURRENT_STEP/$TOTAL_STEPS] $msg" >> "$LOG_FILE"
    echo -e "COMMAND: $cmd" >> "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"
    
    # Menampilkan UI
    printf "\r${CYAN} [⏳]${NC} ${WHITE}%s${NC}..." "$msg"
    
    # Eksekusi command di background menggunakan bash subshell
    bash -c "$cmd" >> "$LOG_FILE" 2>&1 &
    local pid=$!
    
    spinner $pid "$msg"
    wait $pid
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        printf "\r${GREEN} [✔]${NC} ${WHITE}%-50s${NC} ${GREEN}[OK]${NC}\n" "$msg"
    else
        printf "\r${RED} [✖]${NC} ${WHITE}%-50s${NC} ${RED}[FAILED]${NC}\n" "$msg"
        echo -e "\n${RED}╭─────────────────── CRITICAL ERROR DETECTED ───────────────────╮${NC}"
        echo -e "${RED}│${NC} ${WHITE}Gagal saat mengeksekusi:${NC} $msg"
        echo -e "${RED}│${NC} ${WHITE}Exit Code:${NC} $exit_code"
        echo -e "${RED}│${NC} ${WHITE}Log Lengkap:${NC} ${YELLOW}$LOG_FILE${NC}"
        echo -e "${RED}├──────────────────── DEBUGGING OUTPUT (Tail) ──────────────────┤${NC}"
        tail -n 20 "$LOG_FILE" | while read -r line; do echo -e "${RED}│${NC} ${DIM}$line${NC}"; done
        echo -e "${RED}╰───────────────────────────────────────────────────────────────╯${NC}"
        exit 1
    fi
}

# ==========================================
# 3. PRE-FLIGHT CHECKS & AUTO HEALING
# ==========================================

check_env() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[!] Akses Ditolak: Skrip ini wajib dijalankan sebagai ROOT!${NC}"
        exit 1
    fi
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        echo -e "${RED}[!] Error: OS tidak didukung!${NC}"
        exit 1
    fi
}

auto_repair_system() {
    echo -e "${YELLOW}>> Menjalankan Self-Healing & System Cleanup...${NC}"
    run_step "Menghentikan layanan yang memblokir" "systemctl stop unattended-upgrades 2>/dev/null || true; fuser -k 80/tcp 2>/dev/null || true; fuser -k 443/tcp 2>/dev/null || true"
    run_step "Membersihkan APT Lock Files" "rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock"
    run_step "Purge NodeJS/NPM Lama (Anti-Conflict)" "apt-get remove -y --purge nodejs npm libnode* node-* 2>/dev/null || true; apt-get autoremove -y"
    run_step "Fixing Broken APT Dependencies" "dpkg --configure -a && apt-get --fix-broken install -y"
    echo ""
}

get_user_input() {
    echo -e "${BOLD}${CYAN}╭── KONFIGURASI PANEL ──────────────────────────────────────────╮${NC}"
    
    read -p " │ Domain Panel (FQDN)    : " FQDN
    while [[ -z "$FQDN" ]]; do read -p " │ Domain tidak boleh kosong: " FQDN; done

    read -p " │ Nama Panel             : " PANEL_NAME
    PANEL_NAME=${PANEL_NAME:-"Ptero Addons"}

    read -p " │ Email Administrator    : " ADMIN_EMAIL
    while [[ -z "$ADMIN_EMAIL" ]]; do read -p " │ Email tidak boleh kosong: " ADMIN_EMAIL; done

    read -p " │ Username Admin         : " ADMIN_USER
    read -s -p " │ Password Admin         : " ADMIN_PASS; echo ""
    read -s -p " │ Database Root Password : " DB_ROOT_PASS; echo ""
    
    DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 18)
    
    read -p " │ Auto-Setup SSL? (y/n)  : " USE_SSL
    USE_SSL=${USE_SSL:-"y"}

    read -p " │ Timezone [Asia/Jakarta]: " TIMEZONE
    TIMEZONE=${TIMEZONE:-"Asia/Jakarta"}

    echo -e "${CYAN}╰───────────────────────────────────────────────────────────────╯${NC}\n"
    
    echo -e "${YELLOW}[!] Memulai Instalasi Automatis... Dilarang menutup terminal!${NC}\n"
}

# ==========================================
# 4. INSTALASI DEPENDENCIES
# ==========================================

install_dependencies() {
    run_step "Update System Repository" "apt-get update -y && apt-get upgrade -y"
    run_step "Install Basic Utilities" "apt-get install -y software-properties-common curl apt-transport-https ca-certificates gnupg lsb-release git unzip tar psmisc"

    if [[ "$OS" == "ubuntu" ]]; then
        run_step "Menambahkan PPA PHP Ondrej" "LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php"
    elif [[ "$OS" == "debian" ]]; then
        run_step "Menambahkan Repo PHP Sury" "curl -sSL https://packages.sury.org/php/apt.gpg | gpg --dearmor --yes -o /usr/share/keyrings/sury-php.gpg && echo 'deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main' > /etc/apt/sources.list.d/sury-php.list"
    fi

    run_step "Setup MariaDB Repository" "curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash"
    run_step "Setup NodeSource (Node.js 20)" "curl -fsSL https://deb.nodesource.com/setup_22.x | bash -"
    
    run_step "Install Nginx, MariaDB, Redis" "apt-get update -y && apt-get install -y mariadb-server nginx redis-server"
    run_step "Install Node.js & Yarn" "apt-get install -y nodejs && npm install -g yarn"
    
    run_step "Install PHP 8.3 & Extensions" "apt-get install -y php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,curl,zip,intl,redis,fpm}"
    run_step "Install Composer (Global)" "curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer"
}

# ==========================================
# 5. TUNING & CONFIGURATION
# ==========================================

configure_database() {
    run_step "Tuning MariaDB (8GB RAM Mode)" "
        echo '[mysqld]
innodb_buffer_pool_size = 2G
innodb_log_file_size = 512M
innodb_flush_method = O_DIRECT
max_connections = 500
query_cache_type = 1
query_cache_size = 64M' > /etc/mysql/mariadb.conf.d/99-ptero-optimized.cnf
        systemctl restart mariadb"

    run_step "Setup Pterodactyl Database" "mysql -u root -p'${DB_ROOT_PASS}' -e \"CREATE DATABASE IF NOT EXISTS panel; CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}'; GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION; FLUSH PRIVILEGES;\""
}

install_panel() {
    run_step "Download MuLTiAcidi Pterodactyl Fork" "
        mkdir -p $INSTALL_DIR && cd $INSTALL_DIR &&
        curl -Lo panel.tar.gz ${GITHUB_URL}/releases/latest/download/pterodactyl-addons-panel.tar.gz || curl -Lo panel.tar.gz ${GITHUB_URL}/archive/refs/heads/main.tar.gz &&
        tar -xzf panel.tar.gz --strip-components=1 -C $INSTALL_DIR || tar -xzf panel.tar.gz &&
        chmod -R 755 storage/* bootstrap/cache/"
}

configure_panel() {
    run_step "Composer Install Dependencies" "cd $INSTALL_DIR && cp -n .env.example .env && COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction"
    
    run_step "Setup Laravel Environment & App Key" "cd $INSTALL_DIR && 
        php artisan key:generate --force &&
        php artisan p:environment:setup --author='$ADMIN_EMAIL' --url='https://$FQDN' --timezone='$TIMEZONE' --cache=redis --session=redis --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379 &&
        php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password='$DB_PASS' &&
        sed -i 's/APP_NAME=.*/APP_NAME=\"$PANEL_NAME\"/' .env"
}

setup_database_tables() {
    run_step "Smart Migration & Seeding" "cd $INSTALL_DIR && php artisan migrate --seed --force || (php artisan cache:clear && php artisan migrate --force)"
    run_step "Membuat Akun Administrator" "cd $INSTALL_DIR && php artisan p:user:make --email='$ADMIN_EMAIL' --username='$ADMIN_USER' --name-first='Admin' --name-last='Enterprise' --password='$ADMIN_PASS' --admin=1"
}

build_frontend() {
    run_step "Yarn Install Dependencies" "cd $INSTALL_DIR && yarn install --frozen-lockfile --production=false"
    run_step "Yarn Build Production (Proses Lama)" "cd $INSTALL_DIR && yarn build:production"
}

configure_webserver() {
    run_step "Tuning PHP-FPM (8GB RAM Mode)" "
        sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php/8.3/fpm/php.ini
        sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' /etc/php/8.3/fpm/php.ini
        sed -i 's/post_max_size = .*/post_max_size = 100M/' /etc/php/8.3/fpm/php.ini
        systemctl restart php8.3-fpm"

    run_step "Setup Nginx VirtualHost" "
        curl -o /etc/nginx/sites-available/pterodactyl.conf https://raw.githubusercontent.com/pterodactyl/panel/develop/debian/nginx.conf &&
        sed -i \"s/<domain>/$FQDN/g\" /etc/nginx/sites-available/pterodactyl.conf &&
        sed -i \"s|/var/www/pterodactyl|$INSTALL_DIR|g\" /etc/nginx/sites-available/pterodactyl.conf &&
        sed -i 's/php8.1-fpm.sock/php8.3-fpm.sock/g' /etc/nginx/sites-available/pterodactyl.conf &&
        ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf &&
        rm -f /etc/nginx/sites-enabled/default &&
        systemctl restart nginx"

    if [[ "$USE_SSL" == "y" || "$USE_SSL" == "Y" ]]; then
        run_step "Instalasi & Registrasi SSL (Certbot)" "apt-get install -y certbot python3-certbot-nginx && certbot --nginx -d \"$FQDN\" --non-interactive --agree-tos --email \"$ADMIN_EMAIL\" --redirect"
    fi
}

finalize_installation() {
    run_step "Set Ownership (www-data)" "chown -R www-data:www-data $INSTALL_DIR/*"
    
    run_step "Setup Pterodactyl Queue Worker" "
        cat > /etc/systemd/system/pteroq.service <<EOF
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php $INSTALL_DIR/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload && systemctl enable --now pteroq"

    run_step "Setup Cronjob Otomatis" "
        crontab -l | grep -v 'pterodactyl' | crontab - &&
        (crontab -l 2>/dev/null; echo \"* * * * * php $INSTALL_DIR/artisan schedule:run >> /dev/null 2>&1\") | crontab -"

    run_step "Optimalisasi System Caches" "cd $INSTALL_DIR && php artisan config:cache && php artisan view:cache && php artisan route:cache"
}

# ==========================================
# 6. PENUTUPAN & INFORMASI
# ==========================================

print_complete() {
    echo -e "\n${CYAN}╭────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC} ${BOLD}${GREEN}✔ INSTALASI PTERODACTYL ADDONS SUKSES - V${VERSION}${NC}                ${CYAN}│${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}🔗 URL Panel      :${NC} ${CYAN}https://$FQDN${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}👤 Admin Username :${NC} ${CYAN}$ADMIN_USER${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}🔑 Admin Password :${NC} ${DIM}(Tersimpan rahasia)${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}⚙️ INFORMASI INTERNAL DATABASE (SIMPAN DENGAN BAIK!)${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}Database Name     :${NC} ${GREEN}panel${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}Database User     :${NC} ${GREEN}pterodactyl${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}Database Pass     :${NC} ${GREEN}$DB_PASS${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}Debug Log File    :${NC} ${PURPLE}$LOG_FILE${NC}"
    echo -e "${CYAN}╰────────────────────────────────────────────────────────────────────────╯${NC}\n"
    echo -e "${GREEN}Panel Anda sekarang berjalan dengan konfigurasi maksimal untuk VPS 8GB!${NC}\n"
}

# ==========================================
# 7. MAIN EKSEKUSI
# ==========================================
main() {
    print_banner
    check_env
    auto_repair_system
    get_user_input
    
    install_dependencies
    configure_database
    install_panel
    configure_panel
    setup_database_tables
    build_frontend
    configure_webserver
    finalize_installation
    
    print_complete
}

# Mulai instalasi
main
