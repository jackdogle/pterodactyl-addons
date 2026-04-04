#!/bin/bash

# ======================================================================================
#  Pterodactyl Addons Panel - Professional Installer
#  Versi: 2.1.0 (Maximized Stability)
#  OS Didukung: Ubuntu 20.04/22.04/24.04, Debian 11/12
# ======================================================================================

set -e

# Warna untuk output Terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Variabel Utama
INSTALL_DIR="/var/www/pterodactyl"
PANEL_VERSION="2.1.0 (Maximized Stability)
GITHUB_REPO="https://github.com/jackdogle/pterodactyl-addons"

# Header Banner
print_banner() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║            🚀 PTERODACTYL ADDONS PANEL INSTALLER (ULTRA STABLE)               ║"
    echo -e "║                              v${PANEL_VERSION}                                ║"
    echo -e "╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Cek Izin Root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[!] Skrip ini harus dijalankan sebagai ROOT (sudo bash install.sh)${NC}"
        exit 1
    fi
}

# Deteksi OS & Arsitektur
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VER=$VERSION_ID
    else
        echo -e "${RED}[!] Gagal mendeteksi Sistem Operasi.${NC}"
        exit 1
    fi
    echo -e "${BLUE}[*] Mendeteksi: $OS $OS_VER${NC}"
}

# Input Pengguna dengan Validasi
get_config() {
    echo -e "${YELLOW}--- Konfigurasi Dasar ---${NC}"
    
    read -p "Masukkan Domain/FQDN (cth: panel.domain.com): " FQDN
    while [[ -z "$FQDN" ]]; do read -p "Domain tidak boleh kosong: " FQDN; done

    read -p "Masukkan Nama Panel [Ptero Addons]: " PANEL_NAME
    PANEL_NAME=${PANEL_NAME:-"Ptero Addons"}

    echo -e "\n${YELLOW}--- Konfigurasi Admin ---${NC}"
    read -p "Email Admin: " ADMIN_EMAIL
    while [[ ! $ADMIN_EMAIL =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; do
        read -p "Email tidak valid, masukkan ulang: " ADMIN_EMAIL
    done
    
    read -p "Username Admin: " ADMIN_USER
    read -s -p "Password Admin (min 8 karakter): " ADMIN_PASS
    echo ""

    echo -e "\n${YELLOW}--- Konfigurasi Database ---${NC}"
    read -s -p "Password ROOT MariaDB (Setup Awal): " DB_ROOT_PWD
    echo ""
    
    # Generate Password Aman untuk User Database
    DB_APP_USER="pterodactyl"
    DB_APP_PASS=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 16)
    DB_NAME="panel"

    read -p "Gunakan SSL Let's Encrypt? (y/n) [y]: " USE_SSL
    USE_SSL=${USE_SSL:-"y"}

    echo -e "\n${CYAN}--- Konfirmasi Akhir ---${NC}"
    echo "Domain: $FQDN"
    echo "Admin: $ADMIN_USER ($ADMIN_EMAIL)"
    echo "DB User: $DB_APP_USER"
    read -p "Lanjutkan Instalasi? (y/n): " FINAL_CONFIRM
    if [[ "$FINAL_CONFIRM" != "y" ]]; then echo "Dibatalkan."; exit 0; fi
}

# Langkah 1: Instalasi Repositori & Paket
install_packages() {
    echo -e "${BLUE}[1/8] Memperbarui sistem & menginstal repositori...${NC}"
    apt update && apt upgrade -y
    apt install -y software-properties-common curl apt-transport-https ca-certificates gnupg lsb-release git unzip tar cron psmisc

    # PHP Repositori
    if [[ "$OS" == "ubuntu" ]]; then
        add-apt-repository -y ppa:ondrej/php
    else
        curl -sSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
        echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/sury-php.list
    fi

    # MariaDB & Node.js Repositori
    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -

    apt update -y
    apt install -y php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,curl,zip,intl,redis,fpm} \
                mariadb-server nginx redis-server nodejs

    # Composer & Yarn
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    npm install -g yarn
    echo -e "${GREEN}[V] Paket berhasil diinstal.${NC}"
}

# Langkah 2: Setup Database yang Sangat Aman
setup_database() {
    echo -e "${BLUE}[2/8] Menyiapkan MariaDB...${NC}"
    systemctl enable --now mariadb
    
    # Amankan MySQL (Non-interactive)
    mysql -u root -p"${DB_ROOT_PWD}" <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_APP_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_APP_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_APP_USER}'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
    # Bersihkan history untuk keamanan
    rm -f ~/.mysql_history
    echo -e "${GREEN}[V] Database berhasil disiapkan.${NC}"
}

# Langkah 3: Unduh & Extract Panel
download_panel() {
    echo -e "${BLUE}[3/8] Mengunduh file panel...${NC}"
    mkdir -p $INSTALL_DIR
    cd $INSTALL_DIR
    
    if ! curl -Lo panel.tar.gz "${GITHUB_REPO}/releases/latest/download/pterodactyl-addons-panel.tar.gz"; then
        echo -e "${RED}[!] Gagal mengunduh file release. Mencoba clone repository...${NC}"
        git clone $GITHUB_REPO .
    else
        tar -xzf panel.tar.gz
    fi

    chmod -R 755 storage/* bootstrap/cache/
    echo -e "${GREEN}[V] File berhasil disiapkan.${NC}"
}

# Langkah 4: Konfigurasi Core (.env & Composer)
configure_core() {
    echo -e "${BLUE}[4/8] Mengonfigurasi inti panel...${NC}"
    if [ ! -f .env ]; then
        cp .env.example .env
    fi
    
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction
    php artisan key:generate --force

    # Setup Environment Dasar
    php artisan p:environment:setup \
        --author="$ADMIN_EMAIL" \
        --url="https://$FQDN" \
        --timezone="Asia/Jakarta" \
        --cache=redis \
        --session=redis \
        --queue=redis \
        --redis-host=127.0.0.1 \
        --redis-pass= \
        --redis-port=6379 \
        --settings-ui=true

    # Setup Database Link
    php artisan p:environment:database \
        --host=127.0.0.1 \
        --port=3306 \
        --database=$DB_NAME \
        --username=$DB_APP_USER \
        --password="$DB_APP_PASS"

    sed -i "s/APP_NAME=.*/APP_NAME=\"$PANEL_NAME\"/" .env
    echo -e "${GREEN}[V] Konfigurasi dasar selesai.${NC}"
}

# Langkah 5: Migrasi & Admin User
setup_admin() {
    echo -e "${BLUE}[5/8] Migrasi database & membuat akun admin...${NC}"
    sleep 3 # Jeda extra untuk kestabilan DB
    php artisan migrate --seed --force

    php artisan p:user:make \
        --email="$ADMIN_EMAIL" \
        --username="$ADMIN_USER" \
        --name-first="Admin" \
        --name-last="User" \
        --password="$ADMIN_PASS" \
        --admin=1
    echo -e "${GREEN}[V] Migrasi & Admin berhasil dibuat.${NC}"
}

# Langkah 6: Kompilasi Frontend
build_assets() {
    echo -e "${BLUE}[6/8] Membangun aset frontend...${NC}"
    # Gunakan cache yarn jika memungkinkan
    yarn install --frozen-lockfile --production
    yarn build:production
    echo -e "${GREEN}[V] Frontend berhasil dikompilasi.${NC}"
}

# Langkah 7: Konfigurasi Webserver (Nginx)
setup_webserver() {
    echo -e "${BLUE}[7/8] Mengonfigurasi Nginx & PHP-FPM...${NC}"
    
    # Optimasi PHP-FPM
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' /etc/php/8.3/fpm/php.ini
    sed -i 's/post_max_size = .*/post_max_size = 100M/' /etc/php/8.3/fpm/php.ini
    sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php/8.3/fpm/php.ini

    cat > /etc/nginx/sites-available/pterodactyl.conf <<EOF
server {
    listen 80;
    server_name $FQDN;
    root $INSTALL_DIR/public;
    index index.php;
    charset utf-8;

    client_max_body_size 100m;
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
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht { deny all; }
}
EOF
    ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    systemctl restart php8.3-fpm
    nginx -t && systemctl restart nginx

    if [[ "$USE_SSL" == "y" ]]; then
        echo -e "${YELLOW}[*] Menyiapkan SSL Certbot...${NC}"
        apt install -y certbot python3-certbot-nginx
        certbot --nginx -d "$FQDN" --non-interactive --agree-tos --email "$ADMIN_EMAIL" --redirect
        # Pastikan auto-renewal aktif
        systemctl enable --now certbot.timer
    fi
}

# Langkah 8: Izin & Background Services
finalize_installation() {
    echo -e "${BLUE}[8/8] Finalisasi sistem...${NC}"
    chown -R www-data:www-data $INSTALL_DIR/*

    # Queue Worker Service
    cat > /etc/systemd/system/pteroq.service <<EOF
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php $INSTALL_DIR/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now pteroq
    
    # Cronjob (Hapus duplikasi jika ada)
    crontab -l | grep -v "artisan schedule:run" | crontab -
    (crontab -l 2>/dev/null; echo "* * * * * php $INSTALL_DIR/artisan schedule:run >> /dev/null 2>&1") | crontab -
    
    # Cache optimization
    cd $INSTALL_DIR
    php artisan config:cache
    php artisan view:cache
    php artisan route:cache
}

# Main Execution
main() {
    print_banner
    check_root
    detect_os
    get_config
    install_packages
    setup_database
    download_panel
    configure_core
    setup_admin
    build_assets
    setup_webserver
    finalize_installation

    echo -e "\n${GREEN}═══════════════════════════════════════════════════════════════"
    echo -e "         INSTALASI SELESAI DENGAN SUKSES! 🎉"
    echo -e "═══════════════════════════════════════════════════════════════${NC}"
    echo -e "URL Panel:   ${CYAN}https://$FQDN${NC}"
    echo -e "Admin User:  ${CYAN}$ADMIN_USER${NC}"
    echo -e "Admin Pass:  ${CYAN}(Rahasia)${NC}"
    echo -e "DB User:     ${CYAN}$DB_APP_USER${NC}"
    echo -e "DB Pass:     ${CYAN}$DB_APP_PASS${NC}"
    echo -e "═══════════════════════════════════════════════════════════════"
    echo -e "${YELLOW}Simpan kredensial ini di tempat aman!${NC}\n"
}

main
