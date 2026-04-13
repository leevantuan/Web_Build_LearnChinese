#!/bin/bash
# ============================================================
# LearningChinese - Deploy Script cho Ubuntu Server
# Domain: learnzh.website
# ============================================================
# Cach dung:
#   1. git clone repo Web_Build len server
#   2. chmod +x deploy.sh
#   3. sudo ./deploy.sh
# ============================================================

set -e

DOMAIN="learnzh.website"
EMAIL="admin@learnzh.website"

echo ""
echo "============================================"
echo "  LearningChinese Production Deploy"
echo "  Domain: $DOMAIN"
echo "============================================"
echo ""

# ── Buoc 1: Kiem tra Docker ──
echo "[1/6] Kiem tra Docker..."
if ! command -v docker &> /dev/null; then
    echo ">> Dang cai dat Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo ">> Docker da cai xong."
else
    echo ">> Docker da co san: $(docker --version)"
fi

# ── Buoc 2: Kiem tra Docker Compose ──
echo ""
echo "[2/6] Kiem tra Docker Compose..."
if ! docker compose version &> /dev/null 2>&1; then
    echo ">> Dang cai dat Docker Compose plugin..."
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
else
    echo ">> Docker Compose da co san: $(docker compose version)"
fi

# ── Buoc 3: Tat Nginx host neu dang chay (tranh conflict port 80/443) ──
echo ""
echo "[3/6] Kiem tra Nginx tren host..."
if systemctl is-active --quiet nginx 2>/dev/null; then
    echo ">> Nginx dang chay tren host. Dang tat..."
    systemctl stop nginx
    systemctl disable nginx
    echo ">> Da tat Nginx host (Docker se thay the)."
elif command -v nginx &> /dev/null; then
    echo ">> Nginx da cai nhung khong chay. OK."
else
    echo ">> Khong co Nginx tren host. OK."
fi

# Kiem tra port 80 co dang bi chiem khong
if ss -tlnp | grep -q ':80 ' 2>/dev/null; then
    echo ">> CANH BAO: Port 80 van dang bi chiem boi:"
    ss -tlnp | grep ':80 '
    echo ">> Dang thu tat..."
    fuser -k 80/tcp 2>/dev/null || true
    sleep 2
fi

# ── Buoc 4: Tao SSL bang Let's Encrypt (lan dau) ──
echo ""
echo "[4/6] Kiem tra SSL certificate..."
if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo ">> Chua co SSL. Bat dau tao certificate..."
    echo ""

    # Kiem tra DNS truoc khi lay SSL
    echo ">> Kiem tra DNS $DOMAIN..."
    RESOLVED_IP=$(dig +short "$DOMAIN" 2>/dev/null | head -1)
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null)
    echo "   DNS tro ve: $RESOLVED_IP"
    echo "   IP server:  $SERVER_IP"
    if [ "$RESOLVED_IP" != "$SERVER_IP" ] && [ -n "$SERVER_IP" ] && [ -n "$RESOLVED_IP" ]; then
        echo ">> CANH BAO: DNS chua tro dung ve server nay!"
        echo "   Certbot co the that bai. Tiep tuc thu..."
    fi

    echo ""
    echo ">> Buoc 4a: Khoi dong Nginx tam thoi (chi HTTP)..."

    # Xoa container cu neu con sot
    docker rm -f lc-nginx-temp 2>/dev/null || true

    # Tao nginx config tam thoi
    mkdir -p /tmp/lc-certbot
    cat > /tmp/lc-nginx-temp.conf << 'NGINX_TEMP'
server {
    listen 80;
    server_name learnzh.website www.learnzh.website;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 200 'LearningChinese - Setting up SSL...';
        add_header Content-Type text/plain;
    }
}
NGINX_TEMP

    # Chay nginx tam thoi de Certbot xac thuc
    docker run -d --name lc-nginx-temp \
        -p 80:80 \
        -v /tmp/lc-nginx-temp.conf:/etc/nginx/conf.d/default.conf:ro \
        -v /tmp/lc-certbot:/var/www/certbot \
        nginx:1.27-alpine

    sleep 3

    echo ">> Buoc 4b: Chay Certbot de lay SSL certificate..."
    docker run --rm \
        -v /etc/letsencrypt:/etc/letsencrypt \
        -v /tmp/lc-certbot:/var/www/certbot \
        certbot/certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        -d "$DOMAIN" \
        -d "www.$DOMAIN"

    # Tat nginx tam thoi
    docker stop lc-nginx-temp && docker rm lc-nginx-temp
    rm -f /tmp/lc-nginx-temp.conf

    echo ">> SSL certificate da tao thanh cong!"
else
    echo ">> SSL certificate da ton tai."
fi

# ── Buoc 5: Copy .env ──
echo ""
echo "[5/6] Cau hinh environment..."
if [ -f ".env.prod" ]; then
    cp .env.prod .env
    echo ">> Da copy .env.prod -> .env"
else
    echo ">> CANH BAO: Khong tim thay .env.prod. Dung gia tri mac dinh."
fi

# ── Buoc 6: Build va chay Docker ──
echo ""
echo "[6/6] Build va khoi dong tat ca services..."
echo ">> Build va khoi dong services (postgres + backend + frontend)..."
echo ""
docker compose -f docker-compose.prod.yaml up -d --build

echo ""
echo "============================================"
echo "  DEPLOY THANH CONG!"
echo "============================================"
echo ""
echo "  Web:     https://$DOMAIN"
echo "  API:     https://$DOMAIN/api/v1/"
echo "  Swagger: https://$DOMAIN/swagger"
echo ""
echo "  Kiem tra trang thai:"
echo "    docker compose -f docker-compose.prod.yaml ps"
echo ""
echo "  Xem logs:"
echo "    docker compose -f docker-compose.prod.yaml logs -f"
echo ""
echo "============================================"
