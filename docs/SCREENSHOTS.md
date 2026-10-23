# Danh mục ảnh minh chứng

Ảnh nằm trong `docs/screenshots/` (tiền tố `00`–`04b` theo giai đoạn thực hiện). Đánh số hình theo tiêu chí chấm (Hình *tiêu chí*.*thứ tự*). **★** = ảnh chính của tiêu chí (nên đặt trong thân báo cáo; ảnh còn lại làm bổ trợ/phụ lục).

Ghi chú:
- Ảnh chụp trước khi cố định subnet và chuyển sang Docker secrets có thể hiện địa chỉ/host cũ (`172.x`, host `%`); ý nghĩa vẫn đúng, trạng thái hiện tại xem nhóm ảnh `04a-`/`04b-`.
- Ảnh nhóm `04a-`, `04b-` không chứa mật khẩu hay nội dung `secrets/`. Bản chạy đầy đủ của script kiểm tra: `docs/verify-hardening-full.txt` (dùng làm phụ lục).
- Hai ảnh tiêu chí 1 chưa có trong thư mục: cần chụp trước khi làm báo cáo.

Tổng: 53 ảnh có sẵn.

## Tiêu chí 1 — GitHub (≥ 3 commit có ý nghĩa + README)

| Hình | File | Mô tả |
|---|---|---|
| Hình 1.1 ★ | (cần chụp) | Trang GitHub repo `dtc245010034-rgb/cuoiky-dtc245010034` hiển thị README và sơ đồ kiến trúc — chưa có trong `docs/screenshots/` |
| Hình 1.2 | (cần chụp) | `git log --oneline | head -12`: các commit theo mốc (Conventional Commits) — chưa có trong `docs/screenshots/` |

## Tiêu chí 2 — App + DB + phpMyAdmin chạy ổn

| Hình | File | Mô tả |
|---|---|---|
| Hình 2.1 ★ | `01-home-https.png` | Trang chủ PhucTech Smart Home qua HTTPS (banner, menu, danh mục, sản phẩm nổi bật) |
| Hình 2.2 | `01-products.png` | Trang `/san-pham/`: lưới 8 sản phẩm có ảnh và giá VND, không có nút giỏ hàng |
| Hình 2.3 | `01-product-detail.png` | Chi tiết sản phẩm `pt-echo-mini`: giá 1.290.000 ₫, mô tả, danh mục, không nút mua |
| Hình 2.4 | `01-wp-admin.png` | Bảng điều khiển `/wp-admin/` đăng nhập bằng `phuc_admin` qua HTTPS |
| Hình 2.5 | `01-phpmyadmin-home.png` | phpMyAdmin đăng nhập `wp_user`: MySQL 8.4.13, cột trái chỉ có 3 DB (ảnh cũ, kết nối hiển thị IP subnet trước 4a) |
| Hình 2.6 | `01-phpmyadmin-tables.png` | phpMyAdmin: danh sách bảng `wp_*` của DB `wordpress` |
| Hình 2.7 | `01-compose-ps.png` | `docker compose ps` giai đoạn đầu (db, wordpress, phpmyadmin, nginx `healthy`; 8081 chỉ `127.0.0.1`) |

## Tiêu chí 3 — Nginx reverse proxy + HTTPS tự ký + security headers

| Hình | File | Mô tả |
|---|---|---|
| Hình 3.1 ★ | `01-curl-headers.png` | `curl -skI https://localhost:8443` (HTTP/2 200 + 6 security headers) và `curl -I http://localhost:8080` (301 → HTTPS) |
| Hình 3.2 | `01-cert-popup.png` | Cảnh báo "Không an toàn" của trình duyệt + chi tiết chứng chỉ tự ký |
| Hình 3.3 | `01-cert-details.png` | Thông tin chứng chỉ: CN=localhost, SAN localhost/127.0.0.1, RSA 2048, hiệu lực 365 ngày |
| Hình 3.4 | `03-nginx-json-log.png` | Access log JSON của Nginx (`docker compose logs --tail 5 nginx`) |

## Tiêu chí 4 — Prometheus + Grafana giám sát container / web / DB

| Hình | File | Mô tả |
|---|---|---|
| Hình 4.1 ★ | `02-dash-overview.png` | Dashboard *Tổng quan*: Target UP, CPU/RAM host, RAM theo container, Nginx req/s, MySQL queries/s |
| Hình 4.2 ★ | `03-prom-targets-7.png` | Prometheus Targets: 7 target đều UP (thêm `loki`, `promtail`) |
| Hình 4.3 | `02-prom-targets.png` | Prometheus Targets giai đoạn giám sát: 5 target UP (prometheus, node-exporter, cadvisor, nginx, mysql) |
| Hình 4.4 | `02-prom-rules.png` | Prometheus Rules: 7 quy tắc cảnh báo, health OK |
| Hình 4.5 | `02-prom-alerts-firing.png` | Prometheus Alerts: `TargetDown` FIRING khi dừng nginx-exporter và mysqld-exporter |
| Hình 4.6 | `02-grafana-datasource.png` | Grafana datasource `Prometheus` (default, provisioned) + "Save & test" thành công |
| Hình 4.7 | `02-dash-node.png` | Dashboard *Node Exporter Full*: CPU, RAM, đĩa của máy chủ |
| Hình 4.8 | `02-dash-cadvisor.png` | Dashboard *cAdvisor / Docker containers*: CPU/RAM từng container `dtc245010034-*` |
| Hình 4.9 | `02-dash-mysql.png` | Dashboard *MySQL*: uptime, connections, queries (khoảng trống ~14:50 là lúc thử cảnh báo) |
| Hình 4.10 | `02-dash-nginx.png` | Dashboard *NGINX*: requests, connections |

## Tiêu chí 5 — Loki + Promtail + LogQL (≥ 3 truy vấn)

| Hình | File | Mô tả |
|---|---|---|
| Hình 5.1 ★ | `03-dash-logs.png` | Dashboard *Nhật ký dtc245010034*: 4 stat, rate theo status, top URI lỗi, LOGIN_FAIL theo IP, cảnh báo Loki (ảnh cũ: IP hiển thị 172.19.0.1 trước 4a) |
| Hình 5.2 | `03-explore-q1-get.png` | LogQL 1: `{service="nginx", stream="stdout"} | json | method="GET"` — dòng JSON request GET |
| Hình 5.3 | `03-explore-q2-4xx.png` | LogQL 2: `… | json | status >= 400` — các dòng 404/429 |
| Hình 5.4 | `03-explore-q3-error.png` | LogQL 3: `{service=~".+"} |~ "(?i)error"` — dòng chứa "error" (dòng đầu là log của chính Grafana, nhiễu tự tham chiếu) |
| Hình 5.5 | `03-explore-q4-rate.png` | LogQL 4: `sum by (status) (rate(…[1m]))` — đồ thị req/s theo status |
| Hình 5.6 | `03-explore-q5-loginfail.png` | LogQL 5: `sum by (ip) (count_over_time(… |= "LOGIN_FAIL" | json [5m]))` — đăng nhập sai theo IP |
| Hình 5.7 | `03-explore-q6-429.png` | LogQL 6: `… | json | status = 429 | uri =~ "/wp-login.php.*"` — request bị rate limit |
| Hình 5.8 | `03-explore-q7-mysql.png` | LogQL 7: `{service="db"}` — log MySQL |
| Hình 5.9 | `03-dash-logs-panel.png` | Dashboard Nhật ký (cuộn xuống): LOGIN_FAIL, panel cảnh báo Firing, panel Logs |
| Hình 5.10 | `03-alert-firing.png` | Grafana → Alerting: `WordPressLoginFailBurst` ở trạng thái Firing (ruler của Loki) |
| Hình 5.11 | `03-login-audit.png` | Dòng audit `LOGIN_FAIL`/`LOGIN_OK` của WordPress (JSON, không có mật khẩu) |

## Tiêu chí 6 — Hardening (≥ 4 biện pháp)

| Hình | File | Mô tả |
|---|---|---|
| Hình 6.1 ★ | `04b-verify-hardening.png` | `scripts/verify-hardening.sh --summary`: 7 nhóm PASS, "Tổng: 109/109 PASS", INFO ngoại lệ cAdvisor/phpMyAdmin |
| Hình 6.2 | `04b-nginx-nonroot.png` | Nginx non-root: `user=101`, `capadd=[]`, `capdrop=[ALL]`, image `nginx-unprivileged`, mọi tiến trình user `nginx` |
| Hình 6.3 | `04a-inspect-clean.png` | Docker secrets: `docker inspect` chỉ thấy biến `*_FILE=/run/secrets/…`, `docker compose config` không chứa `password=` |
| Hình 6.4 | `04a-secrets-ls.png` | `ls -la secrets/`: thư mục `drwx------`, file `-rw-r--r--` (chỉ quyền, không nội dung) |
| Hình 6.5 | `04a-network-inspect.png` | Subnet cố định `10.250.x` và cờ `internal` của frontend/backend/monitoring/dockerapi |
| Hình 6.6 | `04a-mysql-users.png` | `mysql.user`: `wp_user`/`exporter` chỉ theo subnet backend, không còn host `%` |
| Hình 6.7 | `04a-db-denied.png` | Container mạng khác đăng nhập `wp_user` → `ERROR 1130 … is not allowed to connect` |
| Hình 6.8 | `04a-nginx-403.png` | Từ container wordpress gọi `nginx:8081/3001/9090/8088` → 403; từ host vẫn 200/302 |
| Hình 6.9 | `01-wp-login-429.png` | Giới hạn tốc độ đăng nhập: `200 200 200 200 429 429 429` |
| Hình 6.10 | `01-network-isolation.png` | Cô lập mạng: wordpress → Internet "Network is unreachable"; 8081 chỉ `127.0.0.1`, 3306 không publish |
| Hình 6.11 | `01-db-grants.png` | `SHOW GRANTS` của `wp_user`: chỉ `SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER` trên `wordpress.*` (ảnh cũ: host `%`, nay xem `04a-mysql-users`) |
| Hình 6.12 | `02-exporter-grants.png` | Quyền user `exporter`: `PROCESS, REPLICATION CLIENT`, `SELECT` trên `performance_schema` (ảnh cũ: host `%`) |
| Hình 6.13 | `02-basic-auth.png` | Prometheus: không auth → 401, có auth → 200, `POST /-/quit` → 403 |
| Hình 6.14 | `02-lan-denied.png` | Cổng quản trị bị từ chối từ IP LAN (000), 8080 → 301; `ss` chỉ `127.0.0.1` |
| Hình 6.15 | `03-loki-401-403.png` | Loki: không auth 401, có auth 200, `POST push` 403, LAN 000 |
| Hình 6.16 | `03-loki-no-shell.png` | Loki distroless: `docker compose exec loki sh` → `executable file not found` |
| Hình 6.17 | `03-socket-proxy-403.png` | docker-socket-proxy: `GET /containers/json` 200; `POST create`, `GET /images/json`, `archive` → 403 |
| Hình 6.18 | `00-ufw-status.png` | `sudo ufw status verbose`: tường lửa active (Docker vẫn bỏ qua ufw với cổng publish) |

## Tiêu chí 7 — Toàn bộ chạy bằng `docker compose`, có minh chứng

| Hình | File | Mô tả |
|---|---|---|
| Hình 7.1 ★ | `03-compose-ps.png` | `docker compose ps` toàn stack 13 container healthy; 3100/3001/9090/8082/8081 chỉ `127.0.0.1` |
| Hình 7.2 | `02-compose-ps.png` | `docker compose ps` giai đoạn giám sát (10 container healthy) |
| Hình 7.3 | `00-env-versions.png` | Môi trường: Docker 29.1.3, Docker Compose v2, kernel |
