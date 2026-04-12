# 📖 LearningChinese - Hướng dẫn sử dụng Docker

## 📋 Mục lục

1. [Tổng quan kiến trúc](#-tổng-quan-kiến-trúc)
2. [Chạy trên Windows (Development)](#-chạy-trên-windows-development)
3. [Deploy lên Ubuntu (Production)](#-deploy-lên-ubuntu-production)
4. [Lệnh Docker thường dùng](#-lệnh-docker-thường-dùng)
5. [Xử lý sự cố](#-xử-lý-sự-cố)

---

## 🏗 Tổng quan kiến trúc

```
                    ┌─────────────────────────────────────────┐
                    │              Docker Network             │
                    │                                         │
 User ─── :443 ──► │  ┌──────────┐    ┌──────────┐          │
 (HTTPS)           │  │ Nginx/FE │───►│ Backend  │          │
                    │  │ :80/:443 │    │ .NET :8080│          │
                    │  └──────────┘    └────┬─────┘          │
                    │                       │                 │
                    │                  ┌────▼─────┐          │
                    │                  │ Postgres │          │
                    │                  │  :5432   │          │
                    │                  └──────────┘          │
                    │                                         │
                    │  ┌──────────┐                           │
                    │  │ MeloTTS  │ (Audio Generation)       │
                    │  │  :8888   │                           │
                    │  └──────────┘                           │
                    └─────────────────────────────────────────┘
```

| Service | Image | Port (Dev) | Port (Prod) | Mô tả |
|---------|-------|------------|-------------|-------|
| Frontend | nginx:1.27-alpine (~45MB) | 4200 | 80, 443 | Serve Angular + reverse proxy |
| Backend | aspnet:9.0-alpine (~220MB) | 5154 | Ẩn (qua nginx) | .NET API |
| Postgres | postgres:16-alpine (~80MB) | 5432 | Ẩn | Database |
| Audio | python:3.9-slim (~2.5GB) | 8888 | Ẩn | MeloTTS text-to-speech |

---

## 💻 Chạy trên Windows (Development)

### Yêu cầu
- Docker Desktop đã cài và đang chạy
- Node.js 18+ (để build Angular)
- .NET 9 SDK (để build Backend)

### Bước 1: Build FE + BE

```powershell
cd D:\Persional\LearningChinese\Web_Build
powershell -ExecutionPolicy Bypass -File build.ps1
```

> Script sẽ tự động:
> - `ng build` Angular → `frontend/build/`
> - `dotnet publish` .NET → `backend/build/`

### Bước 2: Chạy Docker

```powershell
# Chạy 3 service chính (không cần Audio)
docker-compose up -d --build postgres backend frontend

# Hoặc chạy tất cả (bao gồm Audio - lần đầu rất lâu ~30-60 phút)
docker-compose up -d --build
```

### Bước 3: Mở web

| URL | Mô tả |
|-----|-------|
| http://localhost:4200 | 🌐 Trang web chính |
| http://localhost:5154/swagger | ⚙️ API Documentation |
| http://localhost:8888 | 🔊 Audio Service (nếu chạy) |

### Tắt Docker

```powershell
# Tắt tất cả container
docker-compose down

# Tắt và xóa volume (XÓA HẾT DATA)
docker-compose down -v
```

---

## 🚀 Deploy lên Ubuntu (Production)

### Yêu cầu Server
- Ubuntu 22.04+
- RAM 4GB+ (MeloTTS cần ~2GB)
- Disk 20GB+
- Port 80, 443 mở
- Domain `learnzh.website` đã trỏ A record về IP server

### Bước 1: Build trên Windows

```powershell
cd D:\Persional\LearningChinese\Web_Build
powershell -ExecutionPolicy Bypass -File build.ps1
```

### Bước 2: Upload lên Server

```bash
# Cách 1: Dùng SCP
scp -r D:\Persional\LearningChinese\Web_Build root@103.149.87.43:/opt/learnchinese/Web_Build

# Cách 2: Dùng rsync (nhanh hơn khi update)
rsync -avz --progress Web_Build/ root@103.149.87.43:/opt/learnchinese/Web_Build/

# Cách 3: Dùng WinSCP hoặc FileZilla (GUI)
# Kết nối SFTP → root@103.149.87.43 → upload folder Web_Build
```

> **Lưu ý:** Nếu chạy Audio service, cần upload thêm folder `Audio_Melo/MeloTTS/`

### Bước 3: SSH vào server và deploy

```bash
ssh root@103.149.87.43

cd /opt/learnchinese/Web_Build

# Sửa mật khẩu DB nếu cần
nano .env.prod

# Chạy deploy tự động (cài Docker + SSL + start services)
chmod +x deploy.sh
sudo ./deploy.sh
```

### Bước 4: Kiểm tra

```bash
# Xem trạng thái
docker compose -f docker-compose.prod.yaml ps

# Nên thấy output như này:
# NAME           IMAGE                STATUS          PORTS
# lc-postgres    postgres:16-alpine   Up (healthy)
# lc-backend     web_build-backend    Up
# lc-frontend    web_build-frontend   Up              0.0.0.0:80->80, 0.0.0.0:443->443
```

### Truy cập website

| URL | Mô tả |
|-----|-------|
| https://learnzh.website | 🌐 Trang web chính (HTTPS) |
| https://learnzh.website/swagger | ⚙️ API Documentation |
| https://learnzh.website/api/v1/ | 🔌 API Endpoint |

---

## 🔄 Cập nhật code mới

### Trên Windows (máy dev):

```powershell
# 1. Build lại
cd D:\Persional\LearningChinese\Web_Build
powershell -ExecutionPolicy Bypass -File build.ps1

# 2. Upload chỉ phần build (nhanh)
scp -r frontend/build/ root@103.149.87.43:/opt/learnchinese/Web_Build/frontend/build/
scp -r backend/build/ root@103.149.87.43:/opt/learnchinese/Web_Build/backend/build/
```

### Trên Ubuntu (server):

```bash
cd /opt/learnchinese/Web_Build

# Rebuild và restart FE + BE
docker compose -f docker-compose.prod.yaml up -d --build frontend backend

# Nếu chỉ thay đổi FE
docker compose -f docker-compose.prod.yaml up -d --build frontend

# Nếu chỉ thay đổi BE
docker compose -f docker-compose.prod.yaml up -d --build backend
```

---

## 📝 Lệnh Docker thường dùng

### Quản lý Container

```bash
# Xem container đang chạy
docker compose ps

# Khởi động tất cả
docker compose up -d

# Tắt tất cả
docker compose down

# Restart 1 service
docker compose restart backend

# Build lại và chạy
docker compose up -d --build
```

### Xem Logs

```bash
# Xem log tất cả service
docker compose logs

# Xem log 1 service (theo dõi realtime)
docker compose logs -f backend

# Xem 50 dòng log cuối
docker compose logs --tail 50 backend
```

### Database

```bash
# Vào PostgreSQL CLI
docker exec -it lc-postgres psql -U postgres -d LearningChinese

# Liệt kê bảng
docker exec -it lc-postgres psql -U postgres -d LearningChinese -c "\dt"

# Xem dữ liệu 1 bảng
docker exec -it lc-postgres psql -U postgres -d LearningChinese -c "SELECT * FROM \"Users\" LIMIT 5;"

# Backup database
docker exec -t lc-postgres pg_dump -U postgres LearningChinese > backup_$(date +%Y%m%d).sql

# Restore database
cat backup_20260412.sql | docker exec -i lc-postgres psql -U postgres -d LearningChinese
```

### Dọn dẹp Docker

```bash
# Xóa images không dùng
docker image prune -a

# Xóa tất cả cache build
docker builder prune -a

# Xóa volumes không dùng (CẨN THẬN - mất data)
docker volume prune
```

---

## ❓ Xử lý sự cố

### 1. Container không khởi động được

```bash
# Xem log lỗi
docker compose logs backend

# Xem chi tiết 1 container
docker inspect lc-backend
```

### 2. Database lỗi

```bash
# Kiểm tra Postgres có healthy không
docker compose ps postgres

# Xem log Postgres
docker compose logs postgres

# Restart Postgres
docker compose restart postgres
```

### 3. Frontend trả về 502 Bad Gateway

> Nguyên nhân: Backend chưa khởi động xong hoặc bị crash

```bash
# Kiểm tra backend
docker compose logs backend

# Restart backend
docker compose restart backend
```

### 4. SSL Certificate hết hạn

```bash
# Renew thủ công
docker compose -f docker-compose.prod.yaml run --rm certbot renew

# Restart nginx để load cert mới
docker compose -f docker-compose.prod.yaml restart frontend
```

### 5. Audio Service build quá lâu hoặc timeout

> Audio service (MeloTTS) cần tải ~2-3GB thư viện Python + AI models.
> Lần đầu có thể mất 30-60 phút tùy tốc độ mạng.
> Nếu bị timeout, chỉ cần chạy lại lệnh build.

```bash
# Chạy riêng Audio service
docker compose up -d --build audio
```

### 6. Hết dung lượng ổ đĩa

```bash
# Kiểm tra dung lượng
df -h

# Dọn Docker
docker system prune -a --volumes
```

---

## 📁 Cấu trúc thư mục

```
Web_Build/
│
├── 📄 docker-compose.yaml        # Compose cho Development (Windows)
├── 📄 docker-compose.prod.yaml   # Compose cho Production (Ubuntu + SSL)
├── 📄 .env.prod                  # Biến môi trường production
├── 📄 .gitignore                 # Bỏ qua file không cần thiết
│
├── 📄 build.ps1                  # Script build FE + BE (Windows)
├── 📄 deploy.sh                  # Script deploy lên Ubuntu
│
├── 📄 docker_setup.md            # Cheat sheet lệnh Docker
├── 📄 deploy_production.md       # Hướng dẫn deploy chi tiết
├── 📄 README.md                  # ← File này
│
├── 📁 frontend/
│   ├── Dockerfile                # FE Dockerfile (Dev)
│   ├── Dockerfile.prod           # FE Dockerfile (Production + SSL)
│   ├── nginx.conf                # Nginx config (Dev)
│   ├── nginx.prod.conf           # Nginx config (Production + SSL)
│   └── build/                    # ← Angular output (ng build)
│
├── 📁 backend/
│   ├── Dockerfile                # BE Dockerfile
│   └── build/                    # ← .NET publish output
│
└── 📁 audio/
    └── Dockerfile                # Audio Dockerfile (MeloTTS)
```
#   W e b _ B u i l d _ L e a r n C h i n e s e  
 