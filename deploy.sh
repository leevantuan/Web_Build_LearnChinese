#!/bin/bash
# ============================================================
# LearningChinese - Deploy Script cho Ubuntu Server
# Domain: learnzh.website | IP: 103.149.87.43
# ============================================================
# Cach dung:
#   1. Upload folder Web_Build len server
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

# ── Buoc 1: Cai dat Docker (neu chua co) ──
echo "[1/5] Kiem tra Docker..."
if ! command -v docker &> /dev/null; then
    echo ">> Dang cai dat Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo ">> Docker da cai xong. Hay logout va login lai de apply group."
else
    echo ">> Docker da co san: $(docker --version)"
fi

# ── Buoc 2: Cai dat Docker Compose plugin (neu chua co) ──
echo ""
echo "[2/5] Kiem tra Docker Compose..."
if ! docker compose version &> /dev/null; then
    echo ">> Dang cai dat Docker Compose plugin..."
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
else
    echo ">> Docker Compose da co san: $(docker compose version)"
fi

# ── Buoc 3: Tao SSL bang Let's Encrypt (lan dau) ──
echo ""
echo "[3/5] Kiem tra SSL certificate..."
if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo ">> Chua co SSL. Bat dau tao certificate..."
    echo ""
    echo ">> Buoc 3a: Khoi dong Nginx tam thoi (chi HTTP)..."

    # Tao nginx config tam thoi (chi HTTP, khong SSL)
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

    echo ">> Buoc 3b: Chay Certbot de lay SSL certificate..."
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

# ── Buoc 4: Copy .env ──
echo ""
echo "[4/5] Cau hinh environment..."
if [ -f ".env.prod" ]; then
    cp .env.prod .env
    echo ">> Da copy .env.prod -> .env"
else
    echo ">> CANH BAO: Khong tim thay .env.prod. Dung gia tri mac dinh."
fi

# ── Buoc 5: Build va chay Docker ──
echo ""
echo "[5/5] Build va khoi dong tat ca services..."
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
