# Kịch bản demo (8 phút)

Thứ tự bám theo 7 tiêu chí chấm. Mỗi bước: thao tác (lệnh/URL chính xác), điều cần chỉ, và lời nói gợi ý 1–2 câu.

| Bước | Tiêu chí | Thời gian |
|---|---|---|
| 1 | GitHub | 0:40 |
| 2 | App + DB + phpMyAdmin | 1:20 |
| 3 | Nginx HTTPS | 1:00 |
| 4 | Giám sát (Prometheus + Grafana) | 1:30 |
| 5 | Log (Loki + LogQL) | 1:30 |
| 6 | Hardening | 1:00 |
| 7 | Toàn bộ bằng `docker compose` | 1:00 |

## Chuẩn bị trước buổi demo
1. **Khởi động stack trước ≥ 10 phút** để Prometheus/Loki có dữ liệu và mọi container `healthy`:
   ```bash
   cd ~/cuoiky-dtc245010034
   docker compose up -d
   docker compose ps          # đợi tất cả healthy (loki, nginx-exporter chỉ "Up")
   ```
   Kiểm tra Loki sẵn sàng (sau `up`, `/ready` có thể trả 503 vài chục giây):
   ```bash
   curl -s -o /dev/null -w '%{http_code}\n' -u "phuc_monitor:$(cat secrets/monitor_basic_password)" http://127.0.0.1:3100/ready   # 200
   ```
2. **Sinh tải** cho biểu đồ có biến động: `scripts/load.sh 5` (chạy nền, 5 phút, chỉ GET).
3. **Mở sẵn các tab** (đăng nhập sẵn, mật khẩu lấy bằng `cat secrets/<tên>`):
   - https://localhost:8443/ (bấm "tiếp tục" qua cảnh báo chứng chỉ tự ký trước), `/san-pham/`
   - http://127.0.0.1:8081 — phpMyAdmin, user `wp_user`, mật khẩu `secrets/mysql_password`
   - http://127.0.0.1:3001/d/tong-quan-dtc245010034 — Grafana (vào bằng `127.0.0.1`, không dùng `localhost`), user `phuc_grafana`, mật khẩu `secrets/grafana_admin_password`
   - http://127.0.0.1:9090/targets — Basic Auth `phuc_monitor` / `secrets/monitor_basic_password`
   - Tab Grafana Explore → datasource Loki
   - Tab trang GitHub repo
4. **Lưu sẵn 3 truy vấn trong Explore** (dán, chạy, bấm ngôi sao ở "Query history" để mở lại nhanh):
   ```logql
   {service="nginx", stream="stdout"} | json | status >= 400
   sum by (status) (rate({service="nginx", stream="stdout"}[1m]))
   sum by (ip) (count_over_time({service="wordpress"} |= "LOGIN_FAIL" | json [5m]))
   ```
   Truy vấn thứ 3 chỉ có dữ liệu nếu đã có `LOGIN_FAIL` trong 5 phút gần nhất: chạy `scripts/login-fail-burst.sh` (7 lần đăng nhập sai, ~90 s, không in mật khẩu) trước demo ~3 phút, hoặc chạy `scripts/verify-hardening.sh --summary` một lần ở bước 6.
5. **Phóng to chữ terminal** (Ctrl + `+` đến khi đọc được từ xa), xóa màn hình (`clear`), đặt terminal ở thư mục repo.
6. Chọn trước một lần: **không chạy `verify-hardening.sh` quá 1 lần trong 5 phút** (xem bước 6).

---

## Bước 1 — GitHub (tiêu chí 1)
**Thao tác**
- Mở https://github.com/dtc245010034-rgb/cuoiky-dtc245010034 (README hiển thị sơ đồ kiến trúc).
- Terminal: `git log --oneline | head -12`

**Chỉ**: tên repo/MSSV, README, danh sách commit theo từng giai đoạn (app + DB + Nginx, Prometheus + Grafana, Loki + Promtail, hardening).

**Nói**: "Repo có đầy đủ README và các commit theo từng mốc, tiền tố Conventional Commits. Mọi cấu hình nằm trong repo; bí mật nằm ngoài git trong thư mục `secrets/`."

## Bước 2 — App + DB + phpMyAdmin (tiêu chí 2)
**Thao tác**
1. Terminal: `docker compose ps`
2. Trình duyệt: https://localhost:8443 → bấm vào "Sản phẩm" (`/san-pham/`) → một sản phẩm.
3. http://127.0.0.1:8081 → đăng nhập `wp_user` → DB `wordpress` → bảng `wp_*`.

**Chỉ**: cột STATUS toàn `healthy`; cổng 8081 bind `127.0.0.1`, MySQL không có cổng publish; website có 8 sản phẩm, có giá, không có nút mua; phpMyAdmin chỉ thấy DB `wordpress` (không thấy DB khác).

**Nói**: "Website WordPress chạy php-fpm, nói chuyện với MySQL trong mạng nội bộ; phpMyAdmin chỉ truy cập được từ máy chủ. User `wp_user` chỉ có quyền trên đúng DB của website."

## Bước 3 — Nginx HTTPS (tiêu chí 3)
**Thao tác**
```bash
curl -skI https://localhost:8443
curl -I http://localhost:8080
```
(tùy chọn: nhấp vào ổ khóa "Không an toàn" → xem chứng chỉ.)

**Chỉ**: `HTTP/2 200` kèm `strict-transport-security`, `content-security-policy`, `x-frame-options`, `x-content-type-options`, `referrer-policy`, `permissions-policy`; cổng 8080 trả `301` với `location: https://localhost:8443/`.

**Nói**: "Nginx là reverse proxy duy nhất mở ra ngoài, ép HTTPS bằng chứng chỉ tự ký nên trình duyệt cảnh báo; có đủ security headers và chỉ cho TLS 1.2/1.3."

## Bước 4 — Giám sát (tiêu chí 4)
**Thao tác**
1. Grafana: http://127.0.0.1:3001/d/tong-quan-dtc245010034 (time range *Last 15 minutes*).
2. Prometheus: http://127.0.0.1:9090/targets

**Chỉ**: dashboard *Tổng quan*: Target UP, CPU/RAM máy chủ, RAM theo container, Nginx req/s, MySQL queries/s đang biến động; trang Targets có **7 target đều UP**. Nhắc: còn dashboard cAdvisor/Node/MySQL/NGINX, và 7 rule cảnh báo ở `/alerts`.

**Nói**: "Prometheus kéo metric (mô hình pull) của máy chủ, từng container, Nginx và MySQL; Grafana nạp datasource và dashboard từ file nên `docker compose up` là có ngay, không phải cấu hình tay."

## Bước 5 — Log (tiêu chí 5)
**Thao tác**: Grafana → Explore → datasource **Loki** → chạy lần lượt 3 truy vấn đã lưu:
1. `{service="nginx", stream="stdout"} | json | status >= 400` — các request lỗi (404/429…).
2. `sum by (status) (rate({service="nginx", stream="stdout"}[1m]))` — đồ thị req/s theo status.
3. `sum by (ip) (count_over_time({service="wordpress"} |= "LOGIN_FAIL" | json [5m]))` — đăng nhập sai theo IP.

(tùy chọn: dashboard *Nhật ký dtc245010034*, panel "Cảnh báo Loki"; hoặc `scripts/logql-demo.sh 1h` ở terminal.)

**Chỉ**: dòng log JSON của Nginx với `uri`, `status`; trường `ip` trong audit đăng nhập (không có mật khẩu). Lưu ý nếu được hỏi: IP là IP gateway Docker khi truy cập qua `127.0.0.1` (xem README, mục Hạn chế).

**Nói**: "Promtail đẩy log của mọi container vào Loki (mô hình push); Loki chỉ index nhãn nên nhẹ, còn nội dung lọc bằng LogQL. Em có 8 truy vấn mẫu, đây là 3 cái tiêu biểu."

## Bước 6 — Hardening (tiêu chí 6)
**Thao tác**
```bash
scripts/verify-hardening.sh --summary
```

**Chỉ**: 7 dòng nhóm `[PASS] … n/n` (Non-root, Mạng, Secrets, Quyền DB, Nginx, Xác thực giám sát, Socket-proxy), dòng `Tổng: 109/109 PASS`, 2 dòng INFO ngoại lệ (cAdvisor, phpMyAdmin chạy root, kèm lý do). Mở nhanh bảng "Hardening" trong README.

**Nói**: "Em kiểm tra hardening bằng một script chạy 109 phép thử thật, không chỉ liệt kê cấu hình: non-root, cô lập mạng, Docker secrets, quyền DB theo subnet, headers/TLS/rate limit, xác thực Prometheus và Loki."

> **Lưu ý cảnh báo:** mỗi lần chạy script sinh ~4 dòng `LOGIN_FAIL` (phép thử rate limit). Chạy **2 lần trong 5 phút** sẽ vượt ngưỡng cảnh báo Loki `WordPressLoginFailBurst` (> 5/5 phút) → Firing. Có thể dùng đó làm điểm demo: chạy lần 2 rồi mở Grafana → Alerting → Alert rules (hoặc panel "Cảnh báo Loki") thấy **Firing** sau ~1 phút; nếu không muốn, chỉ chạy 1 lần. Cảnh báo tự hết sau ~5 phút kể từ lần cuối.

## Bước 7 — Toàn bộ bằng `docker compose` (tiêu chí 7)
**Thao tác**
```bash
docker compose config --services       # danh sách dịch vụ trong một file compose
docker compose ps                      # trạng thái và cổng
docker stats --no-stream               # RAM từng container so với mem_limit
```
(mở nhanh `docker-compose.yml`: `name:`, `secrets:`, `networks:`.)

**Chỉ**: 13 dịch vụ chạy thường (+ `log-init` chạy một lần và `wpcli` ở profile `setup`) trong một file; healthcheck, `restart: unless-stopped`, `mem_limit`; không có lệnh `docker run` thủ công nào; ảnh/minh chứng ở `docs/screenshots/` và `docs/SCREENSHOTS.md`.

**Nói**: "Cài mới chỉ cần bốn lệnh trong README: sinh bí mật, `docker compose up -d`, `seed.sh`. Em đã thử clone sạch sang thư mục khác (project tên khác) và chạy lại từ đầu: mọi container healthy, 7/7 target UP, hardening đủ PASS."

---

## Nếu sự cố
| Tình huống | Lệnh khôi phục nhanh |
|---|---|
| Một container `unhealthy`/dừng | `docker compose ps` → `docker compose restart <dịch vụ>` |
| Website 502 sau khi khởi động | `docker compose restart wordpress nginx` (đợi healthy) |
| Loki `/ready` 503 hoặc Explore không có dữ liệu | Đợi ~30 s; nếu vẫn 503: `docker compose restart loki` |
| Grafana `/api/live` lỗi / panel "Live" 403 | Vào bằng `http://127.0.0.1:3001` (không dùng `localhost`) |
| Trình duyệt chặn trang HTTPS | Bấm "Nâng cao" → "Tiếp tục tới localhost"; hoặc chuyển sang `curl -k` |
| Quên mật khẩu đăng nhập | `cat secrets/wp_admin_password` (hoặc `grafana_admin_password`, `monitor_basic_password`, `mysql_password`) |
| Bị 429 khi đăng nhập thử | Đợi ~1 phút (giới hạn 5 yêu cầu/phút) |
| Cả stack lỗi lạ | `docker compose down` rồi `docker compose up -d` (**không** `-v`, giữ dữ liệu); đợi healthy |
| Cần chạy lại kiểm tra hardening | `scripts/verify-hardening.sh` (tránh chạy lặp trong 5 phút, xem bước 6) |
| Mất dữ liệu WordPress (đã có bản dump) | `docker compose up -d db` rồi `docker compose exec -T db sh -c 'MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" mysql -uroot wordpress' < <file dump .sql>` |
| Trắng trơn (không có nội dung mẫu) | `scripts/seed.sh` (chạy lại được, không tạo trùng) |
| Dữ liệu demo biểu đồ thưa | `scripts/load.sh 2` rồi đợi ~1 phút |

Tạo dump trước khi demo (khuyến nghị): `docker compose exec -T db bash -c 'MYSQL_PWD="$(< /run/secrets/mysql_root_password)" mysqldump -uroot --single-transaction --no-tablespaces --databases wordpress' > ~/wordpress-demo.sql && chmod 600 ~/wordpress-demo.sql`
