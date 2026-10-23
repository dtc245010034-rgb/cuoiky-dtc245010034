# Website Quảng bá Sản phẩm (WordPress) — Docker Compose

Bài tập lớn môn **Triển khai và Quản trị Hệ thống Phần mềm** — Đề 3.

| | |
|---|---|
| Sinh viên | NGUYỄN ANH PHÚC |
| MSSV | dtc245010034 |
| Lớp | KTMT K23 |
| GVHD | HOÀNG VĂN TÂM |

## Giới thiệu
Website quảng bá sản phẩm **PhucTech Smart Home** (thiết bị nhà thông minh, thương hiệu giả định) xây dựng bằng WordPress + WooCommerce ở chế độ *catalog* (chỉ giới thiệu: ảnh, giá, mô tả, danh mục; không giỏ hàng/thanh toán), chạy hoàn toàn bằng Docker Compose phía sau Nginx HTTPS tự ký.

## Kiến trúc
```
Internet/LAN ──8080 (301)──┐
             ──8443 (TLS)──┤ nginx ── fastcgi ──► wordpress (php-fpm, www-data) ──► db (MySQL 8.4)
127.0.0.1:8081 ────────────┘   └── proxy ────► phpmyadmin ───────────────────────────┘
        [frontend]                         [backend: internal, không ra Internet]
```
- `frontend`: mạng thường, chỉ Nginx có cổng publish.
- `backend`: `internal: true` — db, wordpress, phpmyadmin, nginx; không có đường ra Internet, MySQL không publish cổng.
- `egress`: chỉ dùng cho container `wpcli` (profile `setup`) khi tải theme/plugin lúc cài đặt.
- Mã WordPress nằm trong volume `wp_html`, dùng chung (Nginx gắn `:ro`) để Nginx phục vụ file tĩnh.

Stack: WordPress (php-fpm) · MySQL · phpMyAdmin · Nginx (HTTPS tự ký) · Prometheus · Grafana · Loki · Promtail.

## Yêu cầu
- Docker Engine + Docker Compose v2 (`docker compose`)
- ≥ 4 GB RAM, ≥ 15 GB đĩa trống; cổng 8080, 8443, 8081 còn trống
- `openssl`, `python3` (chỉ khi muốn sinh lại ảnh minh họa)

## Cài đặt nhanh
```bash
git clone https://github.com/dtc245010034-rgb/cuoiky-dtc245010034.git
cd cuoiky-dtc245010034

# 1. Tạo .env với mật khẩu ngẫu nhiên
cp .env.example .env
for k in MYSQL_ROOT_PASSWORD MYSQL_PASSWORD WP_ADMIN_PASSWORD GRAFANA_ADMIN_PASSWORD; do
  sed -i "s|^$k=.*|$k=$(openssl rand -base64 33 | tr -d '/+=\n' | cut -c1-24)|" .env
done

# 2. Chứng chỉ TLS tự ký (RSA 2048, CN=localhost, SAN)
scripts/gen-cert.sh

# 3. Khởi động MySQL + WordPress + phpMyAdmin + Nginx
docker compose up -d
docker compose ps                  # tất cả phải "healthy"

# 4. Cài WordPress và nạp nội dung mẫu (wp-cli, chạy một lần, có thể chạy lại)
scripts/seed.sh
```
Mở https://localhost:8443 (trình duyệt cảnh báo chứng chỉ tự ký: chọn tiếp tục). Quản trị tại `/wp-admin/`, tài khoản `WP_ADMIN_USER` / `WP_ADMIN_PASSWORD` trong `.env`.

Các lệnh hữu ích:
```bash
curl -kI https://localhost:8443          # 200 + security headers
curl -I  http://localhost:8080           # 301 -> https://localhost:8443/
docker compose logs -f nginx wordpress
docker compose down                      # dừng, giữ dữ liệu (thêm -v để xoá volume)
```

## Cổng dịch vụ
| Dịch vụ | Địa chỉ |
|---|---|
| Website (HTTPS) | https://localhost:8443 (HTTP 8080 → redirect) |
| phpMyAdmin (qua Nginx, chỉ loopback) | http://127.0.0.1:8081 |
| Prometheus | http://127.0.0.1:9090 |
| Grafana | http://127.0.0.1:3001 |
| Loki | http://127.0.0.1:3100 |
| cAdvisor | http://127.0.0.1:8082 |

## Hardening
- **Cô lập mạng**: `backend` là `internal: true`; WordPress/MySQL/phpMyAdmin không có đường ra Internet. MySQL không publish cổng.
- **Docker bỏ qua ufw với cổng publish** nên phpMyAdmin (và các công cụ quản trị sau này) chỉ bind `127.0.0.1`; chỉ Nginx 8080/8443 mở ra ngoài.
- **Không chạy root**: php-fpm chạy `www-data`; MySQL chạy user `mysql`; `cap_drop: ALL` cho WordPress và Nginx; `no-new-privileges`.
- **Hạn chế quyền DB**: user WordPress chỉ có `SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, INDEX, REFERENCES` trên đúng DB của nó; root chỉ đăng nhập từ localhost trong container.
- **Mật khẩu mạnh** sinh bằng `openssl rand`, nằm trong `.env` (không commit); tài khoản quản trị WordPress không dùng tên `admin`.
- **Nginx**: TLS 1.2/1.3, HSTS, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy; `server_tokens off`; giới hạn tốc độ POST `/wp-login.php` (429); chặn `xmlrpc.php`, `wp-config.php`, file ẩn và thực thi PHP trong `wp-content/uploads`; `DISALLOW_FILE_EDIT`, `FORCE_SSL_ADMIN`.
- `stub_status` ở cổng nội bộ 8088 (không publish), chỉ cho dải mạng riêng.

## Giám sát & Log
_(đang cập nhật)_

## Minh chứng
Xem `docs/screenshots/`.
