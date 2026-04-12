# 🚀 Hướng dẫn Deploy Production - learnzh.website

## 📋 Yêu cầu Server Ubuntu

| Yêu cầu | Tối thiểu |
|----------|-----------|
| OS | Ubuntu 22.04+ |
| RAM | 4GB+ (MeloTTS cần ~2GB) |
| Disk | 20GB+ |
| Port | 80, 443 mở |
| Domain | learnzh.website → 103.149.87.43 |

## 📁 Cấu trúc file Production

```
Web_Build/
├── docker-compose.yaml          # ← Dev (local Windows)
├── docker-compose.prod.yaml     # ← Production (Ubuntu + SSL)
├── .env.prod                    # ← Biến môi trường production
├── deploy.sh                    # ← Script 1-lệnh deploy
├── build.ps1                    # ← Build FE/BE (Windows)
├── frontend/
│   ├── Dockerfile               # ← Dev (HTTP only)
│   ├── Dockerfile.prod          # ← Production (HTTPS)
│   ├── nginx.conf               # ← Dev nginx
│   ├── nginx.prod.conf          # ← Production nginx + SSL
│   └── build/                   # ← Angular output
├── backend/
│   ├── Dockerfile
│   └── build/                   # ← .NET publish output
└── audio/
    └── Dockerfile
```

## 🔧 Bước 1: Build trên Windows (máy dev)

```powershell
# Build FE + BE
cd D:\Persional\LearningChinese\Web_Build
powershell -ExecutionPolicy Bypass -File build.ps1
```

## 🚀 Bước 2: Upload lên Server

```bash
# Dùng SCP hoặc rsync
scp -r Web_Build/ root@103.149.87.43:/opt/learnchinese/

# Hoặc dùng FileZilla/WinSCP upload folder Web_Build
```

## 🔒 Bước 3: Deploy trên Ubuntu

```bash
# SSH vào server
ssh root@103.149.87.43

# Vào thư mục
cd /opt/learnchinese/Web_Build

# Sửa password database nếu cần
nano .env.prod

# Chạy deploy (tự động cài Docker + SSL + start services)
chmod +x deploy.sh
sudo ./deploy.sh
```

> Script sẽ tự động:
> 1. Cài Docker + Docker Compose (nếu chưa có)
> 2. Tạo SSL certificate qua Let's Encrypt
> 3. Build và chạy tất cả containers

## ✅ Bước 4: Kiểm tra

```bash
# Xem trạng thái containers
docker compose -f docker-compose.prod.yaml ps

# Xem logs
docker compose -f docker-compose.prod.yaml logs -f backend

# Test HTTPS
curl -I https://learnzh.website
```

## 🔄 Cập nhật code mới

```powershell
# === Trên Windows (máy dev) ===
# 1. Build lại FE/BE
cd D:\Persional\LearningChinese\Web_Build
powershell -ExecutionPolicy Bypass -File build.ps1

# 2. Upload build mới lên server
scp -r frontend/build/ root@103.149.87.43:/opt/learnchinese/Web_Build/frontend/build/
scp -r backend/build/ root@103.149.87.43:/opt/learnchinese/Web_Build/backend/build/
```

```bash
# === Trên Ubuntu (server) ===
cd /opt/learnchinese/Web_Build
docker compose -f docker-compose.prod.yaml up -d --build frontend backend
```

## 📊 So sánh Dev vs Production

| Tính năng | Dev (Windows) | Production (Ubuntu) |
|-----------|---------------|---------------------|
| File compose | `docker-compose.yaml` | `docker-compose.prod.yaml` |
| SSL | ❌ HTTP only | ✅ HTTPS (Let's Encrypt) |
| Domain | localhost | learnzh.website |
| DB Port | 5432 exposed | 🔒 Internal only |
| API Port | 5154 exposed | 🔒 Via nginx proxy |
| Audio Port | 8888 exposed | 🔒 Internal only |
| Certbot | ❌ | ✅ Auto-renew 12h |
| Security Headers | ❌ | ✅ HSTS, XSS, etc. |

## 🛡️ Bảo mật Production

### Đã có sẵn:
- ✅ HTTPS với TLS 1.2/1.3
- ✅ HTTP → HTTPS redirect
- ✅ Security headers (HSTS, X-Frame-Options, X-XSS-Protection)
- ✅ DB/API không expose port ra ngoài
- ✅ SSL auto-renew

### Nên làm thêm:
- 🔲 Đổi password DB trong `.env.prod`
- 🔲 Setup firewall (UFW): chỉ mở 22, 80, 443
- 🔲 Disable Swagger trong production
- 🔲 Setup backup database tự động

### Setup Firewall (khuyến nghị):
```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP (redirect)
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

## 🔑 DNS đã cấu hình đúng

| Tên | Loại | Giá trị |
|-----|------|---------|
| @ | A | 103.149.87.43 |
| www | CNAME | learnzh.website |
| * | A | 103.149.87.43 |

> DNS của bạn đã cấu hình đúng, không cần chỉnh gì thêm.

## ❓ Troubleshoot

### SSL không tạo được?
```bash
# Kiểm tra port 80 có mở chưa
sudo ufw status
# Kiểm tra DNS đã trỏ đúng chưa
dig learnzh.website
```

### Container lỗi?
```bash
# Xem logs chi tiết
docker compose -f docker-compose.prod.yaml logs backend
docker compose -f docker-compose.prod.yaml logs frontend
```

### Renew SSL thủ công?
```bash
docker compose -f docker-compose.prod.yaml run --rm certbot renew
docker compose -f docker-compose.prod.yaml restart frontend
```
