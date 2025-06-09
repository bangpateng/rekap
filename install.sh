#!/bin/bash

# Script Setup Environment untuk Bot Telegram yang Sudah Ada
# Untuk bot yang sudah memiliki file main.js, package.json, dll

set -e

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fungsi untuk mencetak pesan berwarna
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Deteksi versi Ubuntu dan set metode instalasi
detect_ubuntu_version() {
    print_step "Mendeteksi versi Ubuntu..."
    
    if [ -f /etc/lsb-release ]; then
        UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || grep DISTRIB_RELEASE /etc/lsb-release | cut -d= -f2)
    elif [ -f /etc/os-release ]; then
        UBUNTU_VERSION=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
    else
        UBUNTU_VERSION="unknown"
    fi
    
    print_message "Terdeteksi Ubuntu $UBUNTU_VERSION"
    
    # Set metode instalasi berdasarkan versi
    case "$UBUNTU_VERSION" in
        "22.04"|"22.10")
            CERTBOT_METHOD="snap"
            PYTHON_VERSION="3.10"
            print_message "Menggunakan konfigurasi untuk Ubuntu 22.x"
            ;;
        "24.04"|"24.10")
            CERTBOT_METHOD="apt"
            PYTHON_VERSION="3.12"
            print_message "Menggunakan konfigurasi untuk Ubuntu 24.x"
            ;;
        "20.04"|"20.10")
            CERTBOT_METHOD="ppa"
            PYTHON_VERSION="3.8"
            print_message "Menggunakan konfigurasi untuk Ubuntu 20.x"
            ;;
        *)
            print_warning "Versi Ubuntu tidak dikenali ($UBUNTU_VERSION), menggunakan metode default"
            CERTBOT_METHOD="snap"
            PYTHON_VERSION="3.10"
            ;;
    esac
}

# Fungsi untuk meminta input dari user
get_user_input() {
    print_step "Mengumpulkan informasi konfigurasi..."
    
    echo -n "Masukkan domain bot Anda (contoh: bot.recapairdrops.xyz): "
    read DOMAIN
    
    echo -n "Masukkan Bot Token Telegram: "
    read BOT_TOKEN
    
    echo -n "Masukkan Channel ID utama (contoh: -100xxxxxxxxxx): "
    read CHANNEL_ID
    
    echo -n "Masukkan Relay Channel ID [default: -1002471877417]: "
    read RELAY_CHANNEL_ID
    if [ -z "$RELAY_CHANNEL_ID" ]; then
        RELAY_CHANNEL_ID="-1002471877417"
    fi
    
    # Validasi input
    if [ -z "$DOMAIN" ] || [ -z "$BOT_TOKEN" ] || [ -z "$CHANNEL_ID" ]; then
        print_error "Domain, Bot Token, dan Channel ID harus diisi!"
        exit 1
    fi
    
    print_message "Konfigurasi yang akan digunakan:"
    echo "Domain: $DOMAIN"
    echo "Bot Token: ${BOT_TOKEN:0:10}..."
    echo "Channel ID: $CHANNEL_ID"
    echo "Relay Channel ID: $RELAY_CHANNEL_ID"
    echo
    echo -n "Lanjutkan setup environment? (y/n): "
    read CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        print_error "Setup dibatalkan"
        exit 1
    fi
}

# Cek file bot yang sudah ada
check_existing_files() {
    print_step "Memeriksa file bot yang sudah ada..."
    
    if [ ! -f "/root/rekap/main.js" ]; then
        print_error "File main.js tidak ditemukan di /root/rekap/"
        exit 1
    fi
    
    if [ ! -f "/root/rekap/package.json" ]; then
        print_error "File package.json tidak ditemukan di /root/rekap/"
        exit 1
    fi
    
    print_message "File bot ditemukan ✓"
}

# Update sistem
update_system() {
    print_step "Memperbarui sistem..."
    apt update && apt upgrade -y
    print_message "Sistem berhasil diperbarui"
}

# Install dependencies berdasarkan versi Ubuntu
install_dependencies() {
    print_step "Menginstall dependencies sistem..."
    
    # Dependencies dasar untuk semua versi
    apt install -y nginx ufw curl wget software-properties-common
    
    # Install certbot berdasarkan metode yang sesuai
    case "$CERTBOT_METHOD" in
        "snap")
            print_message "Menginstall certbot via snap untuk Ubuntu $UBUNTU_VERSION"
            # Hapus certbot apt jika ada
            apt remove certbot python3-certbot-nginx -y 2>/dev/null || true
            
            # Install snapd dan certbot
            apt install -y snapd
            snap install core 2>/dev/null || true
            snap refresh core 2>/dev/null || true
            snap install --classic certbot
            
            # Buat symlink
            ln -sf /snap/bin/certbot /usr/bin/certbot
            ;;
            
        "apt")
            print_message "Menginstall certbot via apt untuk Ubuntu $UBUNTU_VERSION"
            apt install -y certbot
            ;;
            
        "ppa")
            print_message "Menginstall certbot via PPA untuk Ubuntu $UBUNTU_VERSION"
            # Hapus certbot lama
            apt remove certbot -y 2>/dev/null || true
            
            # Tambah PPA dan install
            add-apt-repository ppa:certbot/certbot -y
            apt update
            apt install -y certbot
            ;;
    esac
    
    # Verifikasi instalasi certbot
    if certbot --version >/dev/null 2>&1; then
        print_message "Certbot berhasil diinstall: $(certbot --version 2>&1 | head -1)"
    else
        print_error "Gagal menginstall certbot"
        exit 1
    fi
    
    print_message "Dependencies sistem berhasil diinstall"
}

# Install Node.js berdasarkan versi Ubuntu
install_nodejs() {
    print_step "Memeriksa dan menginstall Node.js..."
    
    # Cek apakah node sudah terinstall
    if command -v node &> /dev/null; then
        NODE_CURRENT_VERSION=$(node --version)
        print_message "Node.js sudah terinstall: $NODE_CURRENT_VERSION"
        
        # Cek apakah versi Node.js kompatibel (minimal v16)
        NODE_MAJOR=$(echo $NODE_CURRENT_VERSION | cut -d'.' -f1 | sed 's/v//')
        if [ "$NODE_MAJOR" -ge 16 ]; then
            print_message "Versi Node.js sudah kompatibel"
            return
        else
            print_warning "Versi Node.js terlalu lama, akan diupdate"
        fi
    fi
    
    # Install NVM berdasarkan versi Ubuntu
    print_message "Menginstall Node.js untuk Ubuntu $UBUNTU_VERSION"
    
    # Install NVM jika belum ada
    if [ ! -d "$HOME/.nvm" ]; then
        print_message "Menginstall NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        
        # Tunggu sebentar untuk memastikan instalasi selesai
        sleep 2
    fi
    
    # Load NVM dengan berbagai cara untuk kompatibilitas
    export NVM_DIR="$HOME/.nvm"
    
    # Coba berbagai cara untuk load NVM
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        \. "$NVM_DIR/nvm.sh"
    elif [ -f ~/.bashrc ] && grep -q "nvm.sh" ~/.bashrc; then
        source ~/.bashrc
    fi
    
    # Load bash completion jika ada
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    # Instalasi Node.js berdasarkan versi Ubuntu
    case "$UBUNTU_VERSION" in
        "20.04"|"20.10")
            print_message "Menginstall Node.js 16 LTS untuk Ubuntu 20.x"
            nvm install 16
            nvm use 16
            nvm alias default 16
            ;;
        "22.04"|"22.10")
            print_message "Menginstall Node.js 18 LTS untuk Ubuntu 22.x"
            nvm install 18
            nvm use 18
            nvm alias default 18
            ;;
        "24.04"|"24.10")
            print_message "Menginstall Node.js 20 LTS untuk Ubuntu 24.x"
            nvm install 20
            nvm use 20
            nvm alias default 20
            ;;
        *)
            print_message "Menginstall Node.js 18 LTS (default)"
            nvm install 18
            nvm use 18
            nvm alias default 18
            ;;
    esac
    
    # Verifikasi instalasi
    if command -v node &> /dev/null; then
        print_message "Node.js berhasil diinstall: $(node --version)"
        print_message "NPM version: $(npm --version)"
    else
        print_error "Gagal menginstall Node.js"
        exit 1
    fi
}

# Install dependencies npm
install_npm_dependencies() {
    print_step "Menginstall dependencies npm..."
    
    cd /root/rekap
    
    # Install dependencies jika node_modules belum ada atau tidak lengkap
    if [ ! -d "node_modules" ] || [ ! -f "package-lock.json" ]; then
        npm install
        print_message "Dependencies npm berhasil diinstall"
    else
        print_message "Dependencies npm sudah terinstall"
    fi
}

# Update file .env
update_env_file() {
    print_step "Mengupdate file .env..."
    
    # Backup file .env yang lama jika ada
    if [ -f "/root/rekap/.env" ]; then
        cp /root/rekap/.env /root/rekap/.env.backup
        print_message "File .env lama sudah dibackup ke .env.backup"
    fi
    
    # Buat file .env baru
    cat > /root/rekap/.env << EOF
BOT_TOKEN=$BOT_TOKEN
CHANNEL_ID=$CHANNEL_ID
RELAY_CHANNEL_ID=$RELAY_CHANNEL_ID
WEBHOOK_URL=https://$DOMAIN
EOF
    
    print_message "File .env berhasil diupdate"
}

# Setup SSL certificate dengan pre-check firewall
setup_ssl() {
    print_step "Mengsetup SSL certificate..."
    
    # Pre-check: Pastikan firewall sudah dikonfigurasi
    UFW_HTTP=$(ufw status | grep "80/tcp" | grep "ALLOW")
    if [ -z "$UFW_HTTP" ]; then
        print_warning "Port 80 belum dibuka di firewall, membuka sekarang..."
        ufw allow 80/tcp
    fi
    
    # Pre-check: Test DNS resolution
    print_message "Memeriksa DNS resolution untuk $DOMAIN..."
    if ! dig +short $DOMAIN >/dev/null 2>&1; then
        print_warning "DNS resolution untuk $DOMAIN mungkin bermasalah"
    else
        RESOLVED_IP=$(dig +short $DOMAIN | head -1)
        SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com)
        print_message "Domain $DOMAIN mengarah ke: $RESOLVED_IP"
        print_message "IP server ini: $SERVER_IP"
        
        if [ "$RESOLVED_IP" != "$SERVER_IP" ]; then
            print_warning "WARNING: Domain tidak mengarah ke IP server ini!"
            print_warning "Pastikan DNS A record untuk $DOMAIN mengarah ke $SERVER_IP"
            echo -n "Lanjutkan setup SSL? (y/n): "
            read CONTINUE_SSL
            if [ "$CONTINUE_SSL" != "y" ] && [ "$CONTINUE_SSL" != "Y" ]; then
                print_warning "Setup SSL dibatalkan. Melanjutkan dengan HTTP only."
                SSL_ENABLED=false
                return
            fi
        fi
    fi
    
    # Stop services yang mungkin menggunakan port 80
    print_message "Menghentikan services yang menggunakan port 80/443..."
    systemctl stop nginx 2>/dev/null || true
    systemctl stop apache2 2>/dev/null || true
    
    # Kill processes yang menggunakan port 80 jika ada
    lsof -ti:80 | xargs kill -9 2>/dev/null || true
    
    # Cek apakah certificate sudah ada
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        print_message "SSL certificate untuk $DOMAIN sudah ada"
        # Verifikasi masih valid (belum expire)
        if openssl x509 -checkend 86400 -noout -in "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" >/dev/null 2>&1; then
            print_message "SSL certificate masih valid"
            return
        else
            print_warning "SSL certificate akan expire, akan diperbaharui"
        fi
    fi
    
    # Setup berdasarkan versi Ubuntu
    case "$UBUNTU_VERSION" in
        "22.04"|"22.10")
            print_message "Menggunakan metode SSL untuk Ubuntu 22.x"
            # Ubuntu 22 sering ada masalah dengan cryptography library
            # Fix dependencies dulu jika diperlukan
            if ! python3 -c "import cryptography" 2>/dev/null; then
                print_message "Memperbaiki cryptography dependencies..."
                apt install -y python3-pip
                pip3 install --upgrade pip 2>/dev/null || true
                pip3 install --upgrade 'cryptography>=3.4.8' 'pyopenssl>=22.1.0' 2>/dev/null || true
            fi
            ;;
        "24.04"|"24.10")
            print_message "Menggunakan metode SSL untuk Ubuntu 24.x"
            ;;
        "20.04"|"20.10")
            print_message "Menggunakan metode SSL untuk Ubuntu 20.x"
            if ! python3 -c "import cryptography" 2>/dev/null; then
                apt install -y python3-pip
                pip3 install --upgrade cryptography 2>/dev/null || true
            fi
            ;;
    esac
    
    # Generate SSL certificate dengan retry mechanism
    CERT_ATTEMPTS=0
    MAX_ATTEMPTS=3
    
    while [ $CERT_ATTEMPTS -lt $MAX_ATTEMPTS ]; do
        print_message "Mencoba generate SSL certificate (attempt $((CERT_ATTEMPTS + 1))/$MAX_ATTEMPTS)"
        
        # Tambahkan verbose logging untuk debugging
        CERTBOT_LOG="/tmp/certbot_${DOMAIN}.log"
        
        if certbot certonly \
            --standalone \
            --non-interactive \
            --agree-tos \
            --email "admin@$DOMAIN" \
            --domains "$DOMAIN" \
            --force-renewal \
            --logs-dir /var/log/letsencrypt \
            --work-dir /var/lib/letsencrypt \
            --config-dir /etc/letsencrypt \
            --verbose 2>"$CERTBOT_LOG"; then
            
            print_message "SSL certificate berhasil dibuat"
            rm -f "$CERTBOT_LOG"
            return
        else
            CERT_ATTEMPTS=$((CERT_ATTEMPTS + 1))
            print_warning "Gagal membuat certificate (attempt $CERT_ATTEMPTS/$MAX_ATTEMPTS)"
            
            # Show error detail dari log
            if [ -f "$CERTBOT_LOG" ]; then
                print_warning "Error detail:"
                tail -10 "$CERTBOT_LOG" | sed 's/^/  /'
            fi
            
            if [ $CERT_ATTEMPTS -lt $MAX_ATTEMPTS ]; then
                print_warning "Mencoba lagi dalam 10 detik..."
                sleep 10
                
                # Coba fix untuk attempt selanjutnya
                case $CERT_ATTEMPTS in
                    1)
                        if [ "$UBUNTU_VERSION" = "22.04" ]; then
                            print_message "Mencoba refresh certbot untuk Ubuntu 22.04"
                            snap refresh certbot 2>/dev/null || true
                        fi
                        ;;
                    2)
                        print_message "Mencoba bersihkan cache dan restart"
                        rm -rf /tmp/tmp* 2>/dev/null || true
                        ;;
                esac
            fi
        fi
    done
    
    # Jika masih gagal, berikan opsi manual
    print_error "Gagal membuat SSL certificate setelah $MAX_ATTEMPTS percobaan"
    print_warning "Kemungkinan penyebab:"
    print_warning "1. Domain $DOMAIN tidak mengarah ke IP server ini ($(curl -s ifconfig.me))"
    print_warning "2. Port 80 diblokir oleh firewall atau provider"
    print_warning "3. Ada web server lain yang menggunakan port 80"
    print_warning "4. Rate limit dari Let's Encrypt"
    
    echo -n "Lanjutkan tanpa SSL? (tidak disarankan untuk production) [y/N]: "
    read CONTINUE_WITHOUT_SSL
    if [ "$CONTINUE_WITHOUT_SSL" = "y" ] || [ "$CONTINUE_WITHOUT_SSL" = "Y" ]; then
        print_warning "Melanjutkan tanpa SSL (HTTP only)"
        SSL_ENABLED=false
    else
        print_error "Setup dihentikan. Silakan perbaiki masalah di atas dan jalankan ulang script."
        exit 1
    fi
}

# Konfigurasi Nginx dengan support HTTP/HTTPS
configure_nginx() {
    print_step "Mengkonfigurasi Nginx..."
    
    # Backup konfigurasi nginx default jika ada
    if [ -f "/etc/nginx/sites-enabled/default" ]; then
        mv /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.backup 2>/dev/null || true
    fi
    
    # Buat konfigurasi nginx berdasarkan apakah SSL tersedia
    if [ "${SSL_ENABLED:-true}" = "true" ] && [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        print_message "Membuat konfigurasi Nginx dengan SSL"
        
        cat > /etc/nginx/sites-available/bot-recap << EOF
# HTTPS Server Block
server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    # Security Headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # Proxy Configuration
    location / {
        proxy_pass http://127.0.0.1:5555;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}

# HTTP to HTTPS Redirect
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}
EOF
    else
        print_warning "Membuat konfigurasi Nginx tanpa SSL (HTTP only)"
        
        cat > /etc/nginx/sites-available/bot-recap << EOF
# HTTP Server Block (No SSL)
server {
    listen 80;
    server_name $DOMAIN;

    # Security Headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # Proxy Configuration
    location / {
        proxy_pass http://127.0.0.1:5555;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    fi
    
    # Aktifkan konfigurasi
    ln -sf /etc/nginx/sites-available/bot-recap /etc/nginx/sites-enabled/
    
    # Test konfigurasi nginx
    if nginx -t 2>/dev/null; then
        print_message "Konfigurasi Nginx valid"
    else
        print_error "Konfigurasi Nginx tidak valid"
        nginx -t
        exit 1
    fi
    
    # Start dan enable nginx dengan handling error
    if systemctl start nginx; then
        systemctl enable nginx
        print_message "Nginx berhasil dikonfigurasi dan dijalankan"
    else
        print_error "Gagal menjalankan Nginx"
        systemctl status nginx --no-pager
        exit 1
    fi
}

# Setup systemd service
setup_systemd_service() {
    print_step "Mengsetup systemd service..."
    
    # Dapatkan path node yang benar
    NODE_PATH=$(which node 2>/dev/null || echo "/usr/bin/node")
    
    # Jika menggunakan NVM, dapatkan path yang benar
    if [ -d "$HOME/.nvm" ]; then
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        NODE_PATH=$(which node)
    fi
    
    print_message "Menggunakan Node.js di: $NODE_PATH"
    
    # Buat file service systemd
    cat > /etc/systemd/system/telegrambot.service << EOF
[Unit]
Description=Telegram Recap Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/rekap
ExecStart=$NODE_PATH /root/rekap/main.js
Restart=on-failure
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=telegrambot

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd dan enable service
    systemctl daemon-reload
    systemctl enable telegrambot
    
    print_message "Systemd service berhasil dibuat dan dienable"
}

# Konfigurasi firewall (dipindah ke atas sebelum SSL)
configure_firewall() {
    print_step "Mengkonfigurasi firewall (sebelum setup SSL)..."
    
    # Cek status UFW current
    UFW_STATUS=$(ufw status | head -1)
    print_message "Status UFW saat ini: $UFW_STATUS"
    
    # Reset UFW untuk memastikan konfigurasi bersih
    ufw --force reset
    
    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow essential ports
    print_message "Membuka port yang diperlukan..."
    ufw allow 22/tcp comment 'SSH'
    ufw allow 80/tcp comment 'HTTP for SSL verification'
    ufw allow 443/tcp comment 'HTTPS'
    ufw allow 5555/tcp comment 'Bot application port'
    
    # Enable UFW
    ufw --force enable
    
    # Verifikasi konfigurasi
    print_message "Konfigurasi firewall aktif:"
    ufw status numbered
    
    print_message "Firewall berhasil dikonfigurasi dengan port:"
    print_message "  • 22 (SSH)"
    print_message "  • 80 (HTTP - untuk verifikasi SSL)"
    print_message "  • 443 (HTTPS)"
    print_message "  • 5555 (Bot)"
}

# Setup webhook Telegram
setup_webhook() {
    print_step "Mengsetup webhook Telegram..."
    
    # Delete webhook lama jika ada
    print_message "Menghapus webhook lama..."
    curl -s "https://api.telegram.org/bot$BOT_TOKEN/deleteWebhook?drop_pending_updates=true" > /dev/null
    
    # Set webhook baru
    print_message "Mengatur webhook baru..."
    WEBHOOK_RESULT=$(curl -s -F "url=https://$DOMAIN/webhook" "https://api.telegram.org/bot$BOT_TOKEN/setWebhook")
    
    if echo "$WEBHOOK_RESULT" | grep -q '"ok":true'; then
        print_message "Webhook berhasil disetup ke: https://$DOMAIN/webhook"
    else
        print_warning "Webhook mungkin belum berhasil. Response: $WEBHOOK_RESULT"
        print_warning "Webhook akan diatur ulang setelah bot berjalan."
    fi
}

# Start bot service
start_bot() {
    print_step "Memulai bot service..."
    
    # Start bot service
    systemctl start telegrambot
    
    # Tunggu sebentar untuk memastikan service berjalan
    sleep 3
    
    # Cek status service
    if systemctl is-active --quiet telegrambot; then
        print_message "Bot service berhasil dimulai dan berjalan!"
    else
        print_warning "Bot service mungkin belum berjalan dengan baik"
        print_warning "Cek log dengan: sudo journalctl -u telegrambot -f"
    fi
}

# Verifikasi setup
verify_setup() {
    print_step "Verifikasi setup..."
    
    echo "1. Cek status Nginx:"
    systemctl is-active nginx && echo "   ✓ Nginx running" || echo "   ✗ Nginx not running"
    
    echo "2. Cek status Bot:"
    systemctl is-active telegrambot && echo "   ✓ Bot running" || echo "   ✗ Bot not running"
    
    echo "3. Cek SSL certificate:"
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        echo "   ✓ SSL certificate exists"
    else
        echo "   ✗ SSL certificate not found"
    fi
    
    echo "4. Test koneksi ke bot:"
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/" 2>/dev/null || echo "000")
    if [ "$HTTP_STATUS" = "200" ]; then
        echo "   ✓ Bot accessible via HTTPS"
    else
        echo "   ✗ Bot not accessible (HTTP $HTTP_STATUS)"
    fi
}

# Fungsi utama
main() {
    print_message "=== Script Setup Environment Bot Telegram ==="
    print_message "Script ini akan mengsetup environment untuk bot yang sudah ada"
    echo
    
    # Cek apakah script dijalankan sebagai root
    if [ "$EUID" -ne 0 ]; then
        print_error "Script ini harus dijalankan sebagai root!"
        exit 1
    fi
    
    # Cek direktori kerja
    if [ ! -d "/root/rekap" ]; then
        print_error "Direktori /root/rekap tidak ditemukan!"
        exit 1
    fi
    
    # Eksekusi langkah setup
    detect_ubuntu_version
    check_existing_files
    get_user_input
    update_system
    configure_firewall  # Pindah ke atas sebelum SSL
    install_dependencies
    install_nodejs
    install_npm_dependencies
    update_env_file
    setup_ssl
    configure_nginx
    setup_systemd_service
    setup_webhook
    start_bot
    
    echo
    print_message "=== SETUP ENVIRONMENT SELESAI ==="
    echo
    verify_setup
    echo
    print_message "INFORMASI PENTING:"
    echo "• Ubuntu Version: $UBUNTU_VERSION"
    echo "• Certbot Method: $CERTBOT_METHOD"
    echo "• Node.js Version: $(node --version 2>/dev/null || echo 'Not detected')"
    echo "• SSL Status: ${SSL_ENABLED:-true}"
    if [ "${SSL_ENABLED:-true}" = "true" ]; then
        echo "• Domain bot: https://$DOMAIN"
        echo "• Webhook URL: https://$DOMAIN/webhook"
    else
        echo "• Domain bot: http://$DOMAIN"
        echo "• Webhook URL: http://$DOMAIN/webhook"
    fi
    echo "• File konfigurasi: /root/rekap/.env"
    echo "• File service: /etc/systemd/system/telegrambot.service"
    echo
    print_message "PERINTAH BERGUNA:"
    echo "• Cek status bot: sudo systemctl status telegrambot"
    echo "• Lihat log bot: sudo journalctl -u telegrambot -f"
    echo "• Restart bot: sudo systemctl restart telegrambot"
    echo "• Test webhook: curl https://api.telegram.org/bot$BOT_TOKEN/getWebhookInfo"
    if [ "${SSL_ENABLED:-true}" = "true" ]; then
        echo "• Test bot: curl https://$DOMAIN/"
    else
        echo "• Test bot: curl http://$DOMAIN/"
    fi
    echo "• Check SSL: curl -I https://$DOMAIN/ 2>/dev/null | head -1"
}

# Jalankan script
main "$@"