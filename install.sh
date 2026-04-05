#!/bin/bash

# ======================================================================================
#  PTERODACTYL ADDONS PANEL - ADVANCED ULTIMATE INSTALLER
#  Versi: 3.5.0 (Hyper-Stable, Cyber UI, Deep Self-Healing)
#  Update: Deep Collision Recovery & Auto-Repair Logic
#  OS: Ubuntu 20.04/22.04/24.04, Debian 11/12
# ======================================================================================

set -e

# ==========================================
# KONFIGURASI WARNA & BRANDING CYBER
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'
BG_BLUE='\033[44m'

# Komponen UI Modern
msg_step()  { echo -e "\n${BG_BLUE}${WHITE}${BOLD} STEP $1 ${NC} ${CYAN}➤${NC} ${WHITE}$2${NC}"; }
msg_info()  { echo -e " ${BLUE}󰋼${NC}  ${WHITE}$1${NC}"; }
msg_ok()    { echo -e " ${GREEN}󰄬${NC}  ${GREEN}$1${NC}"; }
msg_warn()  { echo -e " ${YELLOW}󱈸${NC}  ${YELLOW}$1${NC}"; }
msg_error() { echo -e " ${RED}󰅚${NC}  ${RED}${BOLD}$1${NC}"; exit 1; }

divider()   { echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# Variabel Global
INSTALL_DIR="/var/www/pterodactyl"
GITHUB_REPO="https://github.com/jackdogle/pterodactyl-addons"
VERSION="3.5.0-ULTIMATE"

# ==========================================
# BANNER & CHECKER
# ==========================================
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    echo "    ┃  ██████╗ ████████╗███████╗██████╗  ██████╗               ┃"
    echo "    ┃  ██╔══██╗╚══██╔══╝██╔════╝██╔══██╗██╔═══██╗              ┃"
    echo "    ┃  ██████╔╝   ██║   █████╗  ██████╔╝██║   ██║              ┃"
    echo "    ┃  ██╔═══╝    ██║   ██╔══╝  ██╔══██╗██║   ██║              ┃"
    echo "    ┃  ██║        ██║   ███████╗██║  ██║╚██████╔╝              ┃"
    echo "    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    echo -e "${NC}"
    echo -e "      ${BOLD}${WHITE}PTERODACTYL ADDONS PANEL INSTALLER${NC}"
    echo -e "      ${PURPLE}Status: ${VERSION} | Deep Healing Enabled${NC}\n"
    divider
}

check_env() {
    if [[ $EUID -ne 0 ]]; then
        msg_error "Akses Ditolak! Jalankan sebagai ROOT (sudo bash install.sh)."
    fi
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        msg_error "OS tidak didukung."
    fi
    msg_ok "Sistem: $OS terdeteksi. Lingkungan siap."
}

# ==========================================
# DEEP SELF-HEALING & PRE-CLEANUP
# ==========================================
system_healing() {
    msg_step "0" "Protokol Pembersihan Bentrok & Self-Healing"
    
    msg_info "Mendeteksi proses zombie (Yarn/PHP/Node)..."
    pkill -9 -f "yarn" || true
    pkill -9 -f "node" || true
    pkill -9 -f "artisan" || true
    msg_ok "Proses memori dibersihkan."

    msg_info "Memeriksa port 80/443 (Nginx Collision)..."
    if lsof -Pi :80 -sTCP:LISTEN -t >/dev/null ; then
        msg_warn "Port 80 sedang digunakan! Mencoba membebaskan..."
        systemctl stop apache2 2>/dev/null || true
        systemctl restart nginx 2>/dev/null || true
    fi

    if [ -d "$INSTALL_DIR" ]; then
        msg_warn "Instalasi lama ditemukan. Melakukan sanitasi file..."
        rm -f "$INSTALL_DIR/bootstrap/cache/*.php"
        rm -f "$INSTALL_DIR/composer.lock"
        rm -f "$INSTALL_DIR/yarn.lock"
        # Hapus sisa install yang korup
        find "$INSTALL_DIR" -name ".DS_Store" -delete
    fi
    msg_ok "Sistem bersih dari bentrok instalasi sebelumnya."
}

# ==========================================
# CONFIGURATION INPUT
# ==========================================
get_config() {
    msg_step "1" "Konfigurasi Identitas Panel"
    
    read -p " $(echo -e "${CYAN}󰁔${NC} Domain/FQDN (cth: panel.domain.com): ")" FQDN
    while [[ -z "$FQDN" ]]; do read -p " Domain wajib diisi: " FQDN; done

    read -p " $(echo -e "${CYAN}󰁔${NC} Nama Panel [Jack Store]: ")" PANEL_NAME
    PANEL_NAME=${PANEL_NAME:-"Jack Store"}

    read -p " $(echo -e "${CYAN}󰁔${NC} Email Admin Utama: ")" ADMIN_EMAIL
    while [[ ! $ADMIN_EMAIL =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; do
        read -p " Email tidak valid: " ADMIN_EMAIL
    done
    
    read -p " $(echo -e "${CYAN}󰁔${NC} Username Admin [admin]: ")" ADMIN_USER
    ADMIN_USER=${ADMIN_USER:-"admin"}
    
    read -s -p " $(echo -e "${CYAN}󰁔${NC} Password Admin (min 8 karakter): ")" ADMIN_PASS
    echo ""

    read -s -p " $(echo -e "${CYAN}󰁔${NC} Password ROOT MariaDB (Sangat Penting): ")" DB_ROOT_PWD
    echo ""
    
    DB_APP_USER="pterodactyl"
    DB_APP_PASS=$(openssl rand -base64 14 | tr -dc 'a-zA-Z0-9' | head -c 18)
    DB_NAME="panel"

    read -p " $(echo -e "${CYAN}󰁔${NC} Gunakan SSL Let's Encrypt? (y/n) [y]: ")" USE_SSL
    USE_SSL=${USE_SSL:-"y"}

    divider
    echo -e " ${BOLD}REKAPITULASI:${NC}"
    echo -e " • Hostname : ${BLUE}$FQDN${NC}"
    echo -e " • Admin    : ${WHITE}$ADMIN_USER ($ADMIN_EMAIL)${NC}"
    echo -e " • Versi    : ${PURPLE}$VERSION${NC}"
    divider
    
    read -p " Mulai proses instalasi sekarang? (y/n): " FINAL_CONFIRM
    if [[ "$FINAL_CONFIRM" != "y" ]]; then msg_error "Dibatalkan oleh pengguna."; fi
}

# ==========================================
# CORE INSTALLATION
# ==========================================
install_core() {
    msg_step "2" "Instalasi Dependensi & Arsitektur"
    
    msg_info "Sinkronisasi repositori sistem..."
    apt update -y && apt upgrade -y > /dev/null 2>&1
    apt install -y software-properties-common curl git unzip tar cron psmisc lsof > /dev/null 2>&1

    msg_info "Injeksi Repositori Eksternal (PHP 8.3 & Node 22)..."
    if [[ "$OS" == "ubuntu" ]]; then
        add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
    else
        curl -sSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
        echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/sury-php.list
    fi

    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash > /dev/null 2>&1
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - > /dev/null 2>&1

    apt update -y > /dev/null 2>&1
    apt install -y php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,curl,zip,intl,redis,fpm} \
                mariadb-server nginx redis-server nodejs > /dev/null 2>&1

    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer > /dev/null 2>&1
    npm install -g yarn > /dev/null 2>&1
    msg_ok "Seluruh paket core berhasil dikunci."
}

# ==========================================
# DATABASE COLLISION RECOVERY
# ==========================================
setup_database() {
    msg_step "3" "Database Recovery & Provisioning"
    
    systemctl enable --now mariadb
    
    msg_info "Menangani bentrok user database pterodactyl..."
    mysql -u root -p"${DB_ROOT_PWD}" <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
DROP USER IF EXISTS '${DB_APP_USER}'@'127.0.0.1';
CREATE USER '${DB_APP_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_APP_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_APP_USER}'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
    rm -f ~/.mysql_history
    msg_ok "Database user diregenerasi dengan password baru."
}

download_panel() {
    msg_step "4" "Deployment Pterodactyl Addons Source"
    
    mkdir -p $INSTALL_DIR
    cd $INSTALL_DIR
    
    msg_info "Menarik source code terbaru dari GitHub..."
    if ! curl -sSL -o panel.tar.gz "${GITHUB_REPO}/releases/latest/download/pterodactyl-addons-panel.tar.gz"; then
        msg_warn "Gagal mengunduh file release. Melakukan Git Clone..."
        git clone $GITHUB_REPO . > /dev/null 2>&1
    else
        tar -xzf panel.tar.gz
        rm panel.tar.gz
    fi
    
    msg_info "Mengatur izin direktori (Chmod)..."
    chmod -R 755 storage/* bootstrap/cache/
    [ ! -f .env ] && cp .env.example .env
    
    msg_info "Menjalankan Composer (Optimal Autoload)..."
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction > /dev/null 2>&1
    php artisan key:generate --force > /dev/null 2>&1

    php artisan p:environment:setup --author="$ADMIN_EMAIL" --url="https://$FQDN" --timezone="Asia/Jakarta" --cache=redis --session=redis --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379 --settings-ui=true > /dev/null 2>&1
    php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=$DB_NAME --username=$DB_APP_USER --password="$DB_APP_PASS" > /dev/null 2>&1

    sed -i "s/APP_NAME=.*/APP_NAME=\"$PANEL_NAME\"/" .env
    msg_ok "File core siap di $INSTALL_DIR."
}

# ==========================================
# SMART-MIGRATE & AUTO-FIX
# ==========================================
smart_migrate() {
    msg_step "5" "Smart-Migrate & Auto-Repair Schema"
    
    cd $INSTALL_DIR
    msg_info "Menjalankan migrasi database..."
    
    # Mode perbaikan jika gagal
    set +e
    php artisan migrate --seed --force 2>/tmp/migration_error.log
    MIGRATE_STATUS=$?
    
    if [ $MIGRATE_STATUS -ne 0 ]; then
        msg_warn "Bentrok migrasi terdeteksi! Mengaktifkan Auto-Repair..."
        
        # Cek apakah tabel migrations sudah ada
        if grep -q "Table 'migrations' already exists" /tmp/migration_error.log; then
            msg_info "Mendeteksi tabel gantung. Mencoba membersihkan cache database..."
            php artisan cache:clear > /dev/null 2>&1
            # Coba jalankan migrasi tanpa seeding (jika seed sudah ada)
            php artisan migrate --force > /dev/null 2>&1
        else
            msg_warn "Skema rusak parah. Melakukan Re-sync total..."
            php artisan migrate:fresh --seed --force > /dev/null 2>&1
        fi
        
        if [ $? -eq 0 ]; then
            msg_ok "Database berhasil diperbaiki otomatis."
        else
            msg_error "Gagal memperbaiki database secara otomatis. Cek /tmp/migration_error.log"
        fi
    else
        msg_ok "Migrasi berjalan mulus."
    fi

    msg_info "Memperbarui akun Administrator..."
    php artisan p:user:make --email="$ADMIN_EMAIL" --username="$ADMIN_USER" --name-first="Admin" --name-last="User" --password="$ADMIN_PASS" --admin=1 > /dev/null 2>&1 || msg_warn "Akun sudah ada, melewati pembuatan user."
    set -e
}

# ==========================================
# FRONTEND BUILD & WEBSERVER
# ==========================================
build_frontend() {
    msg_step "6" "Kompilasi Aset Frontend (Yarn)"
    
    msg_info "Memasang node modules (Ini butuh waktu)..."
    yarn install --production=false > /dev/null 2>&1 || { msg_warn "Yarn macet, membersihkan cache..."; yarn cache clean; yarn install; }
    
    msg_info "Membangun aset produksi..."
    yarn build:production > /dev/null 2>&1
    msg_ok "Frontend berhasil dikompilasi dengan UI Modern."
}

setup_nginx() {
    msg_step "7" "Konfigurasi Webserver & SSL"
    
    msg_info "Optimasi PHP-FPM 8.3 untuk beban berat..."
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 128M/' /etc/php/8.3/fpm/php.ini
    sed -i 's/post_max_size = .*/post_max_size = 128M/' /etc/php/8.3/fpm/php.ini
    sed -i 's/memory_limit = .*/memory_limit = 1G/' /etc/php/8.3/fpm/php.ini

    msg_info "Menerapkan vHost Nginx Pterodactyl..."
    cat > /etc/nginx/sites-available/pterodactyl.conf <<EOF
server {
    listen 80;
    server_name $FQDN;
    root $INSTALL_DIR/public;
    index index.php;
    charset utf-8;

    client_max_body_size 128m;
    client_body_timeout 120s;

    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Frame-Options SAMEORIGIN;
    add_header Content-Security-Policy "frame-ancestors 'self';";

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 600;
        fastcgi_send_timeout 600;
        fastcgi_read_timeout 600;
    }

    location ~ /\.ht { deny all; }
}
EOF
    ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    systemctl restart php8.3-fpm
    nginx -t > /dev/null 2>&1 && systemctl restart nginx
    msg_ok "Webserver berhasil di-tuning dan aktif."

    if [[ "$USE_SSL" == "y" ]]; then
        msg_info "Mengamankan domain dengan SSL Let's Encrypt..."
        apt install -y certbot python3-certbot-nginx > /dev/null 2>&1
        certbot --nginx -d "$FQDN" --non-interactive --agree-tos --email "$ADMIN_EMAIL" --redirect > /dev/null 2>&1 || msg_warn "Gagal memasang SSL. Pastikan domain terarah ke IP ini."
        systemctl enable --now certbot.timer > /dev/null 2>&1
    fi
}

finalize() {
    msg_step "8" "Finalisasi Layanan & Background Worker"
    
    msg_info "Mengatur izin kepemilikan file ke www-data..."
    chown -R www-data:www-data $INSTALL_DIR/*

    msg_info "Mendaftarkan Pterodactyl Queue Worker (pteroq)..."
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

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now pteroq > /dev/null 2>&1
    
    (crontab -l 2>/dev/null | grep -v "artisan schedule:run"; echo "* * * * * php $INSTALL_DIR/artisan schedule:run >> /dev/null 2>&1") | crontab -
    
    msg_info "Optimasi cache Laravel..."
    cd $INSTALL_DIR
    php artisan config:cache > /dev/null 2>&1
    php artisan view:cache > /dev/null 2>&1
    php artisan route:cache > /dev/null 2>&1
    msg_ok "Layanan background aktif 24/7."
}

# ==========================================
# EKSEKUSI MAIN
# ==========================================
main() {
    print_banner
    check_env
    system_healing
    get_config
    install_core
    setup_database
    download_panel
    smart_migrate
    build_frontend
    setup_nginx
    finalize

    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${GREEN}${BOLD}✔ INSTALASI SELESAI! PANEL SIAP DIGUNAKAN.${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${BOLD}Link Panel${NC}   : ${BLUE}https://$FQDN${NC}"
    echo -e " ${BOLD}Admin User${NC}  : ${WHITE}$ADMIN_USER${NC}"
    echo -e " ${BOLD}Admin Pass${NC}  : ${YELLOW}(Sesuai input Anda)${NC}"
    echo -e ""
    echo -e " ${BOLD}Database User${NC} : ${WHITE}$DB_APP_USER${NC}"
    echo -e " ${BOLD}Database Pass${NC} : ${RED}$DB_APP_PASS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}CATATAN: Harap simpan Database Pass untuk keperluan maintenance!${NC}\n"
}

main
