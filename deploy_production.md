# 🚀 Hướng dẫn Deploy Production - learnzh.website

## 📋 Yêu cầu

### Server Ubuntu

| Yêu cầu | Tối thiểu                                 |
| ------- | ----------------------------------------- |
| OS      | Ubuntu 22.04+                             |
| RAM     | 4GB+ (MeloTTS cần ~2GB)                   |
| Disk    | 20GB+                                     |
| Port    | 80, 443 mở                                |
| Domain  | learnzh.website trỏ A record về IP server |

### Đã cài sẵn trên server

- ✅ Docker + Docker Compose
- ✅ Nginx (Docker sẽ dùng, không cần trên host)
- ✅ Git

---

## 🔄 Tổng quan workflow

```
┌─────────────────────────────────┐
│  Windows (máy dev)              │
│                                 │
│  1. build.prod.ps1              │
│     ├── ng build → frontend/    │
│     ├── dotnet publish → backend│
│     └── copy MeloTTS → audio/   │
│                                 │
│  2. git push                    │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│  Ubuntu Server                  │
│                                 │
│  3. git clone / git pull        │
│  4. deploy.sh (tự động tất cả) │
│                                 │
│  → https://learnzh.website ✅   │
└─────────────────────────────────┘
```

---

## 📁 Cấu trúc Web_Build sau khi build

```
Web_Build/
├── docker-compose.prod.yaml     ← Docker compose cho production
├── .env.prod                    ← Biến môi trường (DB password, domain)
├── deploy.sh                    ← Script tự động deploy
├── build.ps1                    ← Build cho local dev (Windows)
├── build.prod.ps1               ← Build cho production (Windows → Server)
├── frontend/
│   ├── Dockerfile.prod          ← Nginx + SSL
│   ├── nginx.prod.conf          ← Nginx config production
│   └── build/                   ← ⭐ Angular output (do build.prod.ps1 tạo)
├── backend/
│   ├── Dockerfile               ← .NET runtime
│   └── build/                   ← ⭐ .NET publish output (do build.prod.ps1 tạo)
└── audio/
    ├── Dockerfile               ← Python + MeloTTS
    ├── .dockerignore
    ├── setup.py                 ← ⭐ MeloTTS source (do build.prod.ps1 copy)
    ├── melo/                    ← ⭐ MeloTTS source
    └── ...
```

---

## 🛠️ TỪNG BƯỚC CHI TIẾT

---

### BƯỚC 1 — Build trên Windows (máy dev)

Mở PowerShell, chạy:

```powershell
cd D:\Persional\LearningChinese\Web_Build
powershell -ExecutionPolicy Bypass -File build.prod.ps1
```

Script sẽ tự động:

1. Build Angular (production) → `frontend/build/`
2. Build .NET (Release) → `backend/build/`
3. Copy MeloTTS source → `audio/`
4. Kiểm tra tất cả file config

---

### BƯỚC 2 — Push lên Git

```powershell
cd D:\Persional\LearningChinese\Web_Build
git add -A
git commit -m "Production build $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
git push origin main
```

> ⚠️ Build output (~50MB+) sẽ được push lên git. Đảm bảo repo hỗ trợ file lớn.

---

### BƯỚC 3 — SSH vào Server

```bash
ssh root@<IP_SERVER>
```

---

### BƯỚC 4 — Clone repo (LẦN ĐẦU TIÊN)

```bash
# Tạo thư mục
mkdir -p /opt/learnchinese
cd /opt/learnchinese

# Clone repo
git clone <URL_REPO_WEB_BUILD> Web_Build
cd Web_Build
```

> Nếu đã clone rồi, chỉ cần pull:
>
> ```bash
> cd /opt/learnchinese/Web_Build
> git pull origin main
> ```

---

### BƯỚC 5 — Cấu hình environment

```bash
# Sửa password database (quan trọng!)
nano .env.prod
```

File `.env.prod`:

```env
DB_PASSWORD=<ĐỔI_MẬT_KHẨU_MẠNH>
DOMAIN=learnzh.website
EMAIL=admin@learnzh.website
```

---

### BƯỚC 6 — Chạy Deploy

```bash
chmod +x deploy.sh
sudo ./deploy.sh
```

Script `deploy.sh` sẽ **tự động** thực hiện:

| Bước | Hành động                                                  |
| ---- | ---------------------------------------------------------- |
| 1/5  | Kiểm tra Docker (skip nếu đã có)                           |
| 2/5  | Kiểm tra Docker Compose (skip nếu đã có)                   |
| 3/5  | Tạo SSL certificate qua Let's Encrypt (skip nếu đã có)     |
| 4/5  | Copy `.env.prod` → `.env`                                  |
| 5/5  | `docker compose -f docker-compose.prod.yaml up -d --build` |

⏱️ Lần đầu chạy mất **10-20 phút** (build Docker images + download MeloTTS models).
Các lần sau chỉ mất **1-2 phút**.

---

### BƯỚC 7 — Kiểm tra

```bash
# Xem trạng thái containers
docker compose -f docker-compose.prod.yaml ps

# Kết quả mong đợi:
# lc-postgres   ✅ running (healthy)
# lc-backend    ✅ running
# lc-frontend   ✅ running
# lc-audio      ✅ running
# lc-certbot    ✅ running
```

```bash
# Test HTTPS
curl -I https://learnzh.website

# Xem logs nếu có lỗi
docker compose -f docker-compose.prod.yaml logs -f backend
docker compose -f docker-compose.prod.yaml logs -f frontend
```

Truy cập:

- 🌐 Web: **https://learnzh.website**
- 📡 API: **https://learnzh.website/api/v1/**
- 📖 Swagger: **https://learnzh.website/swagger**

---

## 🔄 CẬP NHẬT CODE MỚI (các lần sau)

### Trên Windows:

```powershell
cd D:\Persional\LearningChinese\Web_Build
powershell -ExecutionPolicy Bypass -File build.prod.ps1
git add -A
git commit -m "Update $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
git push origin main
```

### Trên Server:

```bash
cd /opt/learnchinese/Web_Build
git pull origin main
docker compose -f docker-compose.prod.yaml up -d --build frontend backend
```

> 💡 Nếu chỉ update FE/BE, không cần rebuild audio (mất lâu):
>
> ```bash
> docker compose -f docker-compose.prod.yaml up -d --build frontend backend
> ```
>
> Nếu update cả audio:
>
> ```bash
> docker compose -f docker-compose.prod.yaml up -d --build
> ```

---

## 🔒 Setup Firewall (khuyến nghị)

```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP (redirect → HTTPS)
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

---

## 🔑 DNS — Cấu hình domain

Tại nhà cung cấp domain, thêm các record:

| Tên | Loại  | Giá trị         |
| --- | ----- | --------------- |
| @   | A     | `<IP_SERVER>`   |
| www | CNAME | learnzh.website |

> DNS cần propagate 5-30 phút. Kiểm tra bằng: `dig learnzh.website`

---

## ❓ Troubleshoot

### SSL không tạo được?

```bash
# Kiểm tra port 80 mở chưa
sudo ufw status
# Kiểm tra DNS đã trỏ đúng
dig learnzh.website
# Xem logs certbot
docker logs lc-certbot
```

### Backend lỗi kết nối database?

```bash
# Kiểm tra postgres đã healthy chưa
docker compose -f docker-compose.prod.yaml ps postgres
# Xem logs
docker compose -f docker-compose.prod.yaml logs backend
```

### Renew SSL thủ công?

```bash
docker compose -f docker-compose.prod.yaml run --rm certbot renew
docker compose -f docker-compose.prod.yaml restart frontend
```

### Xóa sạch và deploy lại?

```bash
docker compose -f docker-compose.prod.yaml down
# ⚠️ Lệnh dưới sẽ XÓA database! Cẩn thận!
# docker volume rm $(docker volume ls -q --filter name=web_build_)
docker compose -f docker-compose.prod.yaml up -d --build
```
