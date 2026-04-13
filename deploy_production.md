# 🚀 Hướng Dẫn Deploy Dự Án LearningChinese (Docker)

Hệ thống **LearningChinese** mang thiết kế Clean Architecture siêu nhẹ (Chỉ dùng .NET 9 & Angular 18, Audio được generate trực tiếp từ trình duyệt Client bằng Web Speech API). Việc này giúp hệ thống tiết kiệm cực nhiều tài nguyên và có thể scale rất dễ dàng qua Docker.

---

## 📋 1. Yêu Cầu Cấu Hình Máy Chủ (Production)

Vì hệ thống không còn gánh dịch vụ Audio AI Model (MeloTTS) lỗi thời, cấu hình yêu cầu hiện tại cực kỳ nhẹ nhàng:

| Resource            | Tối Thiểu     | Đề Nghị (Production) | Căn Cứ Lựa Chọn                             |
| ------------------- | ------------- | -------------------- | ------------------------------------------- |
| **Hệ Điều Hành**    | Ubuntu 22.04+ | Ubuntu 24.04 LTS     | Standard Docker Environment                 |
| **RAM**             | 1 GB          | 2 GB                 | .NET 9 Minimal APIs tốn rất ít RAM (<150MB) |
| **Storage (Disk)**  | 10 GB         | 20 GB                | Rất nhẹ, File Audio không lưu lại trên HD!  |
| **Port / Firewall** | 80, 443, 22   | Ưu tiên mở Firewall  | Certbot & Web App chạy Ingress SSL          |

_Tại Server đã cần cài đặt sẵn: `Docker`, `Docker Compose`, `Git`._

---

## 🏗️ 2. Mô Hình Triển Khai (Workflow)

```mermaid
flowchart TD
    A[MÁY DEV (Windows)] -->|Step 1: Run build.prod.ps1| B(Compile tĩnh FE/BE)
    B -->|Step 2: Git Commit & Push| C{Github / Gitlab}
    C -->|Step 3: Server Git Pull| D[SERVER (Ubuntu)]
    D -->|Step 4: deploy.sh| E[(Docker Compose Build)]
    E --> F[HTTPS Server Live!]
```

- **Máy tính Dev (Windows):** Đảm nhiệm việc tải Package (`npm`, `nuget`) và dịch mã nguồn ra thành HTML/JS và DLL .NET. Không ném rác NodeModules hay dư thừa lên Server.
- **Server Ubuntu:** Chỉ nhận file đã dịch/Release rút gọn, chạy `.Dockerfile` tĩnh cực nhanh và gắn Postgres Database.

---

## 🔄 3. Hướng Dẫn Chạy Môi Trường DEV / Local

Bạn đang ở nhà, test tính năng mới xong mún giả lập hệ thống Docker Backend/Frontend trên máy cá nhân? Rất đơn giản:

1. **Build mã nguồn cho Local:** Di chuyển tới thư mục `Web_Build`, khởi chạy script PowerShell build ngầm dành riêng cho dev:

```powershell
cd D:\Persional\LearningChinese\Web_Build
powershell -ExecutionPolicy Bypass -File build.ps1
```

_(Cục build rỗng sẽ được thả vào thư mục build ảo)_

2. **Khởi Động Docker Container Local:**

```bash
docker compose -f docker-compose.yaml up -d --build
```

Hệ thống Frontend & Backend + Local Postgres sẽ được nâng lên ngay lập tức tại Localhost của bạn. Ngừng test: `docker compose down`.

---

## ☁️ 4. Hướng Dẫn Deploy PRODUCTION Lên Server

Quy trình Deploy bản mới ra Internet cho User trải nghiệm (Đòi hỏi HTTPS trỏ Domain):

### BƯỚC A: Build tĩnh tại Local (Windows)

Đứng tại thư mục `Web_Build` (Nơi cấu hình chứa các file Docker Prod), gọi lệnh Script:

```powershell
cd D:\Persional\LearningChinese\Web_Build
powershell -ExecutionPolicy Bypass -File build.prod.ps1
```

_Script sẽ tự động quét, Build Angular Production (AOT), Publish .NET (Release) và quăng file gọn lỏn vào `Web_Build/frontend/build` và `Web_Build/backend/build`._

### BƯỚC B: Gói ghém, Đẩy lên Git

```powershell
git add -A
git commit -m "🔖 Release Bản Mới $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
git push origin main
```

### BƯỚC C: Kéo & Kích hoạt siêu tốc tại Server

Mở terminal kết nối SSH vào máy chủ Ubuntu:

```bash
# 1. Kéo Source Code mới nhất
cd /opt/learnchinese/Web_Build
git pull origin main
```

**(QUAN TRỌNG):** Kể từ bản cập nhật mới, Server bị cắt giảm chức năng tự tạo file mp3 để tiết kiệm bộ nhớ. Do đó, bạn cần phải Tự chép thư mục `audio_files` từ Local của bạn lên Server, nằm ngang hàng với file `docker-compose.prod.yaml`.

```text
/opt/learnchinese/Web_Build
  ├── deploy.sh
  ├── docker-compose.prod.yaml
  ├── audio_files/          <-- CHÉP VÀO ĐÂY (Dùng FTP / FileZilla)
  │    ├── vocabularies/
  │    └── examples/
  ...
```

Sau khi chép xong file (hoặc không có file cũng không sao, tự Fallback sang Google TTS), tiến hành chạy lệnh kích hoạt:

```bash
# 2. Cấp quyền thực thi và chạy kịch bản deploy
chmod +x deploy.sh
./deploy.sh
```

> Lúc này do cấu trúc mới đã loại bỏ MeloTTS, Server chỉ mất chưa tới **1 -> 2 Phút** để nâng cấp thay vì chờ tải hàng GB Models cài đặt Python như ngày xưa!

---

## 🔑 5. Cấu Hình Bảo Mật Ban Đầu (Setup SSL & Database)

**Lưu ý:** Nếu là lần khởi chạy Server ĐẦU TIÊN (Mới mua Cloud), hãy set up những thứ này:

```bash
# 1. SSH Server, tạo thư mục và Clone (nếu chưa có)
mkdir -p /opt/learnchinese
cd /opt/learnchinese
git clone <URL_REPO> Web_Build
cd Web_Build

# 2. Cài đặt Password DB & Domain môi trường Sản phẩm
nano .env.prod
```

Nội dung file `.env.prod`:

```env
DB_PASSWORD=<MẬT_KHẨU_DÀI_BÍ_MẬT>
DOMAIN=learnzh.website
EMAIL=admin@learnzh.website
```

Dùng công cụ setup chứng chỉ số Tự động All-in-One:

```bash
chmod +x deploy.sh
sudo ./deploy.sh
```

_Lệnh này sẽ cài NGINX, xin Certbot SSL cho tên miền, Map SSL Key bằng Let's Encrypts vô cùng mạnh mẽ vào Nginx Config (Tất cả tự động)._

---

## ❓ 6. Khắc Phục Lỗi (Troubleshoot)

- **Xem hệ thống đang có khỏe không:**

```bash
docker compose -f docker-compose.prod.yaml ps
# Mong đợi: lc-postgres (Healthy), lc-backend (Up), lc-frontend (Up)...
```

- **Cháy / Sập CSDL & Muốn dọn sạch làm lại:**
  _(Lệnh này XÓA DỮ LIỆU)_

```bash
docker compose -f docker-compose.prod.yaml down
docker volume prune -f
docker compose -f docker-compose.prod.yaml up -d --build
```

- **Gia hạn Chứng Chỉ Số (Nếu hết hạn 90 ngày):**

```bash
docker compose -f docker-compose.prod.yaml run --rm certbot renew
docker compose -f docker-compose.prod.yaml restart frontend
```
