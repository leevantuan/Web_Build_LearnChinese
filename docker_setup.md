# 🐳 Hướng Dẫn Build & Deploy Docker - LearningChinese

## Yêu cầu

- **Docker Desktop** đã cài và đang chạy
- **.NET 9 SDK** (để build BE local)
- **Node.js 22+** (để build FE local)

---

## Cấu trúc thư mục

```
LearningChinese/
├── LearningChinese_FE/          # Angular source
├── LearningChinese_BE/          # .NET 9 source
├── Audio_Melo/MeloTTS/          # Python TTS (giữ nguyên vị trí)
│
└── Web_Build/                   # ← Docker workspace
    ├── build.ps1                # Script tự động build
    ├── docker-compose.yaml      # Orchestrate 4 containers
    ├── frontend/
    │   ├── Dockerfile           # nginx:alpine
    │   ├── nginx.conf
    │   └── build/               # ← output ng build (auto)
    └── backend/
        ├── Dockerfile           # aspnet:alpine
        └── build/               # ← output dotnet publish (auto)
```

---

## 🚀 Cách Build & Chạy (3 bước)

### Bước 1: Build FE + BE (chạy script)

```powershell
cd d:\Persional\LearningChinese\Web_Build
powershell -ExecutionPolicy Bypass -File build.ps1
```

Script sẽ tự động:
- `ng build --configuration=production` → copy vào `frontend/build/`
- `dotnet publish -c Release` → copy vào `backend/build/`

### Bước 2: Build Docker Images & Start

```powershell
cd d:\Persional\LearningChinese\Web_Build
docker-compose up -d --build
```

### Bước 3: Kiểm tra

```powershell
docker-compose ps
```

| Service | URL | Mô tả |
|---------|-----|-------|
| **Frontend** | http://localhost:4200 | Trang web chính |
| **Backend** | http://localhost:5154/swagger | API docs |
| **PostgreSQL** | localhost:5432 | Database |
| **Audio** | http://localhost:8888 | MeloTTS service |

---

## 🔧 Hoặc Build thủ công (không dùng script)

### Build FE thủ công

```powershell
cd d:\Persional\LearningChinese\LearningChinese_FE

# Build production
npx ng build --configuration=production

# Copy output vào Web_Build
Copy-Item -Recurse .\dist\LearningChinese_FE\browser\* ..\Web_Build\frontend\build\
```

### Build BE thủ công

```powershell
cd d:\Persional\LearningChinese\LearningChinese_BE

# Publish
dotnet publish .\src\LearningChinese.API\LearningChinese.API.csproj -c Release -o ..\Web_Build\backend\build -p:EnvironmentName=Production

# Sau đó start Docker
cd ..\Web_Build
docker-compose up -d --build
```

---

## 📋 Các lệnh Docker thường dùng

```powershell
# Xem trạng thái containers
docker-compose ps

# Xem log realtime
docker-compose logs -f backend
docker-compose logs -f frontend

# Restart 1 service
docker-compose restart backend

# Rebuild lại 1 service (sau khi sửa code)
docker-compose up -d --build backend

# Dừng tất cả
docker-compose down

# Dừng + xóa data (⚠️ MẤT DATABASE)
docker-compose down -v
```

---

## 🔄 Khi cập nhật code

```powershell
# 1. Build lại
cd d:\Persional\LearningChinese\Web_Build
powershell -ExecutionPolicy Bypass -File build.ps1

# 2. Rebuild containers
docker-compose up -d --build
```

---

## ⚙️ Luồng hoạt động

```
Browser (localhost:4200)
    │
    ├── GET /api/v1/... ──→ Nginx proxy ──→ Backend :8080 ──→ PostgreSQL :5432
    ├── GET /audio/...   ──→ Nginx proxy ──→ Backend :8080 (static files)
    └── GET /*.js, *.css ──→ Nginx serve trực tiếp (static Angular files)
```

- FE goi API qua `/api/v1/...` (same origin, khong CORS)
- Nginx reverse proxy chuyen request sang Backend container
- Backend ket noi PostgreSQL qua Docker internal network (hostname: `postgres`)

---

## 📖 Docker Syntax Cheat Sheet

### 1. Docker CLI

```bash
# ── Images ──
docker images                          # Dnah sách tất cả images
docker pull nginx:alpine               # Tải image từ Docker Hub
docker build -t myapp:1.0 .            # Build image từ Dockerfile
docker rmi <image_id>                  # Xóa image
docker image prune -a                  # Xóa tất cả images không dùng

# ── Containers ──
docker ps                              # Danh sách containers đang chạy
docker ps -a                           # Danh sách tất cả containers (kể cả đã dừng)
docker run -d -p 8080:80 nginx         # Chạy container (chạy ngầm, map port)
docker run -it ubuntu bash             # Chạy container chế độ tương tác
docker stop <container_id>             # Dừng container
docker start <container_id>            # Khởi động lại container đã dừng
docker rm <container_id>               # Xóa container
docker container prune                 # Xóa tất cả containers đã dừng

# ── Logs & Debug ──
docker logs <container_id>             # Xem logs
docker logs -f <container_id>          # Theo dõi logs (realtime)
docker logs --tail 100 <container_id>  # Xem 100 dòng logs cuối
docker exec -it <container_id> sh      # Truy cập terminal của container đang chạy
docker inspect <container_id>          # Xem chi tiết container (định dạng JSON)

# ── Volumes ──
docker volume ls                       # Danh sách volumes
docker volume create mydata            # Tạo volume mới
docker volume rm mydata                # Xóa volume
docker volume prune                    # Xóa tất cả volumes không dùng

# ── Network ──
docker network ls                      # Danh sách networks
docker network inspect bridge          # Xem chi tiết một network

# ── System ──
docker system df                       # Xem dung lượng ổ đĩa đang sử dụng
docker system prune -a                 # Xóa sạch mọi thứ không dùng (images, containers, volumes)
```

### 2. Docker Compose CLI

```bash
# ── Lifecycle ──
docker-compose up                      # Chạy tất cả services (hiện log)
docker-compose up -d                   # Chạy tất cả services (chạy ngầm)
docker-compose up -d --build           # Build lại images rồi chạy
docker-compose up -d --build backend   # Chỉ build lại 1 service cụ thể
docker-compose down                    # Dừng và xóa tất cả containers
docker-compose down -v                 # Dừng, xóa containers và xóa luôn volumes
docker-compose stop                    # Chỉ dừng services (không xóa)
docker-compose start                   # Chạy lại services đã dừng
docker-compose restart                 # Khởi động lại tất cả services
docker-compose restart backend         # Khởi động lại 1 service cụ thể

# ── Monitoring ──
docker-compose ps                      # Danh sách services và trạng thái
docker-compose logs                    # Xem logs tất cả services
docker-compose logs -f backend         # Theo dõi logs của 1 service cụ thể
docker-compose logs --tail 50          # Xem 50 dòng logs cuối của tất cả services
docker-compose top                     # Xem các process đang chạy

# ── Execute ──
docker-compose exec backend sh         # Truy cập terminal của 1 service
docker-compose exec postgres psql -U postgres -d LearningChinese  # Kết nối tới Database

# ── Scale ──
docker-compose up -d --scale backend=3 # Chạy 3 instance của service backend
```

### 3. Dockerfile Syntax

```dockerfile
# ── Base image ──
FROM node:22-alpine                    # Bắt đầu từ image cơ sở
FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine AS runtime

# ── Working directory ──
WORKDIR /app                           # Thiết lập thư mục làm việc

# ── Copy files ──
COPY package.json ./                   # Copy một file cụ thể
COPY . .                               # Copy toàn bộ file hiện tại
COPY --from=build /app/dist ./         # Copy từ một stage khác trong multi-stage build

# ── Run commands ──
RUN npm install                        # Chạy lệnh trong quá trình build image
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# ── Environment variables ──
ENV NODE_ENV=production                # Thiết lập biến môi trường
ENV ASPNETCORE_URLS=http://+:8080

# ── Expose port ──
EXPOSE 80                              # Khai báo port container sử dụng
EXPOSE 8080

# ── Start command ──
CMD ["nginx", "-g", "daemon off;"]     # Lệnh mặc định chạy khi start (có thể bị ghi đè)
ENTRYPOINT ["dotnet", "MyApp.dll"]     # Lệnh cố định chạy khi start (không thể bị ghi đè)
```

### 4. docker-compose.yaml Syntax

```yaml
services:
  myservice:
    # ── Build ──
    image: nginx:alpine                # Sử dụng image có sẵn
    build:                             # Hoặc build image từ Dockerfile
      context: ./myapp
      dockerfile: Dockerfile

    # ── Container ──
    container_name: my-container       # Đặt tên cho container
    restart: unless-stopped            # Các tùy chọn: always | no | on-failure | unless-stopped

    # ── Ports ──
    ports:
      - "8080:80"                      # Map port: host:container

    # ── Environment ──
    environment:                       # Khai báo biến môi trường
      DB_HOST: postgres
      DB_PORT: "5432"
    env_file:
      - .env                           # Tải biến môi trường từ file

    # ── Volumes ──
    volumes:
      - mydata:/var/lib/data           # Dùng named volume
      - ./config:/app/config           # Map thư mục local vào container (Bind mount)

    # ── Dependencies ──
    depends_on:
      postgres:
        condition: service_healthy     # Đợi service postgres "healthy" rồi mới khởi chạy

    # ── Health Check ──
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:80 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

    # ── Network ──
    networks:
      - app-network

# ── Volumes declaration ──
volumes:
  mydata:
    driver: local

# ── Networks declaration ──
networks:
  app-network:
    driver: bridge
```

### 5. Tips

| Tip | Lệnh |
|-----|------|
| Xóa tất cả containers đã dừng | `docker container prune` |
| Xóa tất cả images không dùng | `docker image prune -a` |
| Xóa HOÀN TOÀN (images + containers + volumes) | `docker system prune -a --volumes` |
| Xem dung lượng Docker đang chiếm | `docker system df` |
| Copy file từ container ra máy thật | `docker cp <container>:/path/file ./local` |
| Copy file từ máy thật vào container | `docker cp ./local <container>:/path/file` |
| Xem biến môi trường của container | `docker exec <container> env` |
| Kết nối PostgreSQL trong Docker | `docker exec -it lc-postgres psql -U postgres -d LearningChinese` |

