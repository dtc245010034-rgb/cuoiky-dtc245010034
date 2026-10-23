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
127.0.0.1:8081 ────────────┤   └── proxy ────► phpmyadmin ───────────────────────────┘
127.0.0.1:3001 / 9090 / 8082┘   └── proxy ────► grafana · prometheus · cadvisor  [monitoring]
        [frontend]                         [backend: internal, không ra Internet]
```
- Mọi mạng dùng subnet cố định (dải `10.250.0.0/16`, không trùng LAN/tailscale/bridge mặc định): `frontend` `10.250.10.0/24`, `backend` `10.250.20.0/24` (biến `BACKEND_SUBNET`), `monitoring` `10.250.30.0/24`, `egress` `10.250.50.0/24`, `dockerapi` `10.250.250.0/29`. Đổi subnet thì phải `docker compose down` rồi `up`.
- `frontend`: mạng thường, chỉ Nginx có cổng publish.
- `backend`: `internal: true` — db, wordpress, phpmyadmin, nginx; không có đường ra Internet, MySQL không publish cổng.
- `monitoring`: `internal: true` — prometheus, grafana, cadvisor, node-exporter, nginx-exporter, mysqld-exporter và nginx. Chỉ `mysqld-exporter` nối thêm `backend` (để tới `db:3306`); db không bao giờ vào mạng `monitoring`.
- `dockerapi`: `internal: true`, subnet cố định `10.250.250.0/29` — chỉ `docker-socket-proxy` và `promtail`.
- `monitoring` còn có thêm `loki` và `promtail` (log tập trung).
- `egress`: chỉ dùng cho container `wpcli` (profile `setup`) khi tải theme/plugin lúc cài đặt.
- Mã WordPress nằm trong volume `wp_html`, dùng chung (Nginx gắn `:ro`) để Nginx phục vụ file tĩnh.

Stack: WordPress (php-fpm) · MySQL · phpMyAdmin · Nginx (HTTPS tự ký) · Prometheus · Grafana · Loki · Promtail.

## Yêu cầu
- Docker Engine + Docker Compose v2 (`docker compose`)
- ≥ 4 GB RAM, ≥ 15 GB đĩa trống; cổng 8080, 8443, 8081, 3001, 9090, 8082, 3100 còn trống
- `openssl`, `python3` (chỉ khi muốn sinh lại ảnh minh họa)

## Cài đặt nhanh
```bash
git clone https://github.com/dtc245010034-rgb/cuoiky-dtc245010034.git
cd cuoiky-dtc245010034

# 1. Cấu hình không bí mật (tên user, cổng, ...)
cp .env.example .env
# GID của group docker (docker-socket-proxy chạy non-root cần để đọc docker.sock)
sed -i "s|^DOCKER_GID=.*|DOCKER_GID=$(getent group docker | cut -d: -f3)|" .env

# 2. Bí mật: sinh ngẫu nhiên (openssl rand) thẳng vào secrets/ — mật khẩu, khóa TLS tự ký
#    (RSA 2048, CN=localhost, SAN) và htpasswd của Nginx. KHÔNG cần điền mật khẩu vào .env.
scripts/gen-secrets.sh

# 3. Khởi động toàn bộ stack
docker compose up -d
docker compose ps                  # tất cả phải "healthy"

# 4. Cài WordPress và nạp nội dung mẫu (wp-cli, chạy một lần, có thể chạy lại)
scripts/seed.sh
```
Mở https://localhost:8443 (trình duyệt cảnh báo chứng chỉ tự ký: chọn tiếp tục). Quản trị tại `/wp-admin/`.

### Mật khẩu nằm ở đâu
Mật khẩu **không** nằm trong `.env` mà trong thư mục `secrets/` (không commit). Xem bằng `cat`:

| Đăng nhập | User (trong `.env`) | Mật khẩu |
|---|---|---|
| WordPress `/wp-admin/` | `WP_ADMIN_USER` | `secrets/wp_admin_password` |
| Grafana | `GRAFANA_ADMIN_USER` | `secrets/grafana_admin_password` |
| Prometheus / cAdvisor / Loki (Basic Auth) | `MONITOR_BASIC_USER` | `secrets/monitor_basic_password` |
| phpMyAdmin | `MYSQL_USER` (wp_user) | `secrets/mysql_password` |

Máy đã có `.env` cũ chứa `*_PASSWORD` (cài trước khi chuyển sang secrets): chạy **một lần** `scripts/gen-secrets.sh --migrate` để chép nguyên giá trị đang dùng sang `secrets/` (không đổi mật khẩu, nên DB và Grafana đã khởi tạo vẫn đăng nhập được), rồi xóa các dòng `*_PASSWORD` khỏi `.env`.

> **Sao lưu `secrets/`.** Mất thư mục này là mất quyền vào DB và Grafana (mật khẩu root MySQL và admin Grafana chỉ có tác dụng ở lần khởi tạo đầu, sau đó nằm trong volume). Chép bằng `cp -a secrets ~/backup/` để giữ quyền 700/644.

Các lệnh hữu ích:
```bash
curl -kI https://localhost:8443          # 200 + security headers
curl -I  http://localhost:8080           # 301 -> https://localhost:8443/
docker compose logs -f nginx wordpress
docker compose down                      # dừng, giữ dữ liệu (thêm -v để xoá volume)
```

## Cổng dịch vụ
Chỉ Nginx 8080/8443 mở ra ngoài; mọi công cụ quản trị bind `127.0.0.1` (Docker bỏ qua ufw với cổng publish).

| Dịch vụ | Địa chỉ | Đăng nhập |
|---|---|---|
| Website (HTTPS) | https://localhost:8443 (HTTP 8080 → redirect) | `/wp-admin/`: `WP_ADMIN_USER` |
| phpMyAdmin (qua Nginx) | http://127.0.0.1:8081 | `MYSQL_USER` (wp_user) |
| Grafana (qua Nginx) | http://127.0.0.1:3001 | `GRAFANA_ADMIN_USER` (`phuc_grafana`) / `secrets/grafana_admin_password` |
| Prometheus (qua Nginx) | http://127.0.0.1:9090 | Basic Auth `MONITOR_BASIC_USER` / `secrets/monitor_basic_password` |
| cAdvisor (qua Nginx) | http://127.0.0.1:8082 | Basic Auth như Prometheus |
| Loki (qua Nginx, chỉ đọc) | http://127.0.0.1:3100 | Basic Auth như Prometheus |
| node / mysqld / nginx exporter, Promtail | không publish (chỉ mạng `monitoring`) | — |

## Hardening
- **Cô lập mạng**: `backend` là `internal: true`; WordPress/MySQL/phpMyAdmin không có đường ra Internet. MySQL không publish cổng.
- **Docker bỏ qua ufw với cổng publish** nên phpMyAdmin (và các công cụ quản trị sau này) chỉ bind `127.0.0.1`; chỉ Nginx 8080/8443 mở ra ngoài.
- **Hạn chế quyền tiến trình**: php-fpm chạy `www-data` (uid 33) và MySQL chạy user `mysql`; WordPress `cap_drop: ALL`; `no-new-privileges`.
  - Hạn chế hiện tại: tiến trình master của Nginx vẫn chạy bằng root, `cap_drop: ALL` nhưng được `cap_add` 4 quyền (CHOWN, SETUID, SETGID, DAC_OVERRIDE); phpMyAdmin (Apache) chưa `cap_drop`. Dự kiến chuyển Nginx sang non-root (`nginx-unprivileged`) ở giai đoạn hardening (Phiên 4).
- **Hạn chế quyền DB**: user WordPress chỉ có `SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, INDEX, REFERENCES` trên đúng DB của nó; root chỉ đăng nhập từ localhost trong container. `wp_user` và `exporter` được tạo theo **subnet backend** (`'wp_user'@'10.250.20.0/255.255.255.0'`), không còn host `'%'`: container ở mạng khác (kể cả khi tới được cổng 3306) bị `ERROR 1130 ... is not allowed to connect`. DB đang chạy dùng `scripts/migrate-db-users.sh` (tạo bản theo subnet, kiểm tra đăng nhập, rồi `DROP USER` bản `'%'`); volume mới được tạo đúng ngay từ init script.
- **Mật khẩu mạnh** sinh bằng `openssl rand` và **Docker secrets**: mọi mật khẩu (MySQL root, `wp_user`, `exporter`, admin WordPress, admin Grafana, Basic Auth), khóa TLS và `htpasswd` nằm trong `secrets/` (thư mục `700`, file `644`, không commit) và được mount vào `/run/secrets` của đúng container cần dùng; dịch vụ đọc qua `*_FILE` (`MYSQL_ROOT_PASSWORD_FILE`, `WORDPRESS_DB_PASSWORD_FILE`, `GF_SECURITY_ADMIN_PASSWORD__FILE`), init script và `seed.sh` đọc trực tiếp từ file (`seed.sh` truyền mật khẩu admin cho wp-cli qua stdin, `--prompt=admin_password`). Tài khoản quản trị WordPress không dùng tên `admin`.
  - **Giới hạn cần nêu rõ:** Compose không dùng Swarm nên secrets chỉ là **bind mount file không mã hóa** (không có `uid`/`mode` như Swarm). Lợi ích: mật khẩu không nằm trong `environment` hay argv nên không lộ qua `docker inspect`, `docker compose config`, `docker compose logs` hay `ps`. Bảo vệ trên host dựa hoàn toàn vào quyền thư mục `700` của `secrets/`; ai đọc được file (root, hoặc user chủ sở hữu) thì đọc được mật khẩu, và người có quyền `docker exec` vào container vẫn xem được `/run/secrets`.
  - Mật khẩu root MySQL và admin Grafana chỉ có tác dụng ở lần khởi tạo đầu tiên (volume trống); đổi file secret sau đó không đổi mật khẩu trong DB.
- **Nginx**: TLS 1.2/1.3, HSTS, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy; `server_tokens off`; giới hạn tốc độ POST `/wp-login.php` (429); chặn `xmlrpc.php`, `wp-config.php`, file ẩn và thực thi PHP trong `wp-content/uploads`; `DISALLOW_FILE_EDIT`, `FORCE_SSL_ADMIN`.
- `stub_status` ở cổng nội bộ 8088 (không publish), chỉ cho `127.0.0.1` (healthcheck) và subnet `monitoring` `10.250.30.0/24` (nginx-exporter).
- **Giới hạn listener quản trị của Nginx**: các cổng 8081, 3001, 9090, 8082, 3100 chỉ `allow 10.250.10.1` (gateway mạng frontend — đây là IP nguồn đo thật trong access log JSON khi truy cập từ host qua `127.0.0.1`), `deny all` còn lại. Container khác (ví dụ `wordpress`, vốn cùng mạng `backend` với Nginx) gọi `nginx:8081`/`:3001`/`:9090`/`:8082`/`:3100`/`:8088` đều nhận 403.
- **Hạn chế đã biết (docker-proxy):** request tới cổng publish qua loopback (`127.0.0.1`) đi qua `docker-proxy` nên Nginx thấy nguồn là IP gateway mạng frontend (`10.250.10.1`, đã đo). Khi truy cập bằng IP LAN của chính máy (`192.168.1.149`) log thấy đúng địa chỉ đó; client từ máy khác trong LAN chưa được kiểm thử. Hệ quả với truy cập qua docker-proxy: `limit_req` trên `/wp-login.php` dùng chung một bucket, và trường `ip` trong log `LOGIN_FAIL`/cảnh báo Loki là IP gateway, không phải IP thật. Cách khắc phục: `"userland-proxy": false` trong `/etc/docker/daemon.json` rồi restart Docker (cần quyền admin, chưa áp dụng).
- **Giám sát**: Prometheus/cAdvisor sau Basic Auth của Nginx; Nginx trả 403 cho `/-/quit` và `/-/reload` của Prometheus; Grafana tắt đăng ký, truy cập ẩn danh, Gravatar, analytics và kiểm tra cập nhật, tài khoản quản trị không dùng tên `admin`; mật khẩu `mysqld-exporter` nằm trong file cấu hình dạng Docker secret (không lộ qua `docker inspect`); user MySQL `exporter` chỉ có `PROCESS, REPLICATION CLIENT` và `SELECT` trên `performance_schema`, giới hạn 3 kết nối.
- **Ngoại lệ đặc quyền của cAdvisor** (bắt buộc để đọc số liệu cgroup/Docker): chạy root, mount chỉ-đọc `/`, `/sys`, `/var/lib/docker`, `/var/run` (có `docker.sock`) và `/dev/disk`; không dùng `privileged`. node-exporter dùng `pid: host` và mount `/` chỉ-đọc nhưng chạy user `nobody`.

- **Log tập trung**: Promtail đọc log qua Docker API qua `docker-socket-proxy` (không mount `docker.sock` hay `/var/lib/docker/containers`); proxy chạy non-root, `read_only`, `cap_drop: ALL`, chỉ cho `GET` vài đường dẫn đọc (container list/inspect/logs, networks, ping, version) — `archive`, `export`, `attach`, `images`, `exec` và mọi `POST/PUT/DELETE` trả 403. Mount `docker.sock:ro` thì KHÔNG giới hạn được Docker API (chỉ chặn ghi file socket). `GET /networks` (chỉ danh sách) được mở vì `docker_sd_configs` của Promtail gọi nó để tính nhãn mạng của container — thiếu thì Promtail báo `Forbidden` và không phát hiện được container nào; `GET /networks/<id>` vẫn bị 403. Lưu ý còn lại: `GET /containers/{id}/json` vẫn trả biến môi trường của container, nên mạng `dockerapi` chỉ có Promtail. Loki/Promtail `cap_drop: ALL`, `read_only`, chạy uid 10001; Loki ra host qua Nginx với Basic Auth và allowlist chỉ đọc (push/delete → 403).

## Giám sát & Log
### Giám sát (Prometheus + Grafana)
- Truy cập Grafana bằng **http://127.0.0.1:3001** (khớp `GF_SERVER_ROOT_URL`; vào bằng `localhost` thì websocket `/api/live` bị từ chối Origin). Đăng nhập `GRAFANA_ADMIN_USER` (trong `.env`) / mật khẩu trong `secrets/grafana_admin_password`.
- Datasource Prometheus (uid `prometheus`) và 5 dashboard trong thư mục **dtc245010034** được nạp bằng file provisioning, không cần cấu hình tay: *Tổng quan dtc245010034* (tự dựng), *Node Exporter Full* (1860), *cAdvisor / Docker containers* (19792), *MySQL (mysqld-exporter)* (14057), *NGINX (exporter)* (12708).
- Prometheus thu thập mỗi 15 s: `prometheus`, `node-exporter`, `cadvisor`, `nginx`, `mysql`; lưu 7 ngày. Quy tắc cảnh báo ở `monitoring/prometheus/rules/alerts.yml` (TargetDown, HostHighCPU, HostHighMemory, HostDiskLow, ContainerHighMemory, MySQLDown, NginxDown) xem tại http://127.0.0.1:9090/alerts.
- Nạp lại cấu hình Prometheus (Nginx chặn `/-/reload` từ ngoài): `docker compose exec prometheus wget -qO- --post-data= http://localhost:9090/-/reload`.
- Sinh tải để biểu đồ có biến động: `scripts/load.sh 5` (5 phút, chỉ GET).
- User MySQL `exporter` được tạo tự động ở lần khởi tạo DB đầu tiên (`db/init/02-exporter-user.sh`); với DB đã chạy sẵn dùng `scripts/apply-exporter-user.sh`.
- node-exporter chạy trong mạng bridge (không `network_mode: host` để giữ cô lập) nên `node_network_*` là số liệu của container; CPU/RAM/đĩa là của máy chủ.

PromQL mẫu:
```promql
sum(up) / count(up)                                                        # tỉ lệ target đang UP
100 - avg(rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100             # CPU máy chủ (%)
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100    # RAM máy chủ (%)
container_memory_working_set_bytes{name=~"dtc245010034-.*"}                # RAM từng container
rate(nginx_http_requests_total[1m])                                        # yêu cầu/giây của Nginx
rate(mysql_global_status_queries[1m])                                      # truy vấn/giây của MySQL
```

### Log tập trung (Loki + Promtail)
```
container (stdout/stderr) ──Docker API (GET)──► docker-socket-proxy ──► promtail ──push──► loki ◄── grafana (datasource `loki`)
  [dockerapi, internal]                          [dockerapi]           [dockerapi+monitoring]   [monitoring]
127.0.0.1:3100 (Basic Auth, chỉ đọc) ──► nginx ──► loki
```
- **Loki 3.7.9** chạy một tiến trình, lưu filesystem (schema v13/tsdb), giữ **7 ngày** (compactor). Image Loki là distroless (không shell) — cố ý giữ nguyên, nên Loki **không có healthcheck** (như `nginx-exporter`); trạng thái theo dõi bằng `up{job="loki"}` và rule `TargetDown` trong Prometheus. Container một lần `log-init` chỉ `chown` volume positions cho Promtail (user non-root).
- **Promtail 3.6.11** là tag 3.x cuối cùng còn tồn tại; Promtail đã deprecated/hết hỗ trợ, sản phẩm thay thế là **Grafana Alloy**. Chỉ lấy container của project (`com.docker.compose.project=dtc245010034`). Nhãn Loki: `container`, `service` (tên service compose), `stream` (stdout/stderr); riêng log Nginx thêm `status`, `method` (cardinality thấp). `uri`, `remote_addr`, `ip`... giữ trong dòng log, lọc bằng `| json`.
- **Nginx** ghi access log JSON (`log_format json_combined`) ra stdout; error log ra stderr.
- **Audit đăng nhập WordPress**: mu-plugin `seed/mu-plugins/auth-audit.php` ghi một dòng JSON (`event` = `LOGIN_OK`/`LOGIN_FAIL`, `user`, `ip`, `ts`) ra `error_log` → stderr của php-fpm (image đã bật `catch_workers_output`, `decorate_workers_output = no`). Không ghi mật khẩu. IP lấy từ `REMOTE_ADDR` do Nginx đặt; truy cập từ chính máy chủ qua cổng đã publish có thể hiện IP gateway Docker (`172.x.0.1`), còn truy cập qua IP LAN hiện IP LAN. `scripts/seed.sh` cài mu-plugin (chạy lại được).
- **Cảnh báo log**: Loki ruler đánh giá `monitoring/loki/rules/fake/alerts.yml` (`WordPressLoginFailBurst`: hơn 5 `LOGIN_FAIL` trong 5 phút từ một IP). Không có Alertmanager nên chỉ hiển thị trạng thái: Grafana → Alerting → Alert rules (datasource Loki, `manageAlerts: true`), panel "Cảnh báo Loki" của dashboard, hoặc `GET /prometheus/api/v1/alerts` qua cổng 3100.
- Tạo lại cảnh báo để thử/chụp ảnh: `scripts/login-fail-burst.sh` (7 lần đăng nhập sai cách 13 s, dùng tên/mật khẩu giả; đợi ~1 phút để rule đánh giá).
- Grafana: datasource **Loki** (uid `loki`) và dashboard **Nhật ký dtc245010034** (panel Logs, tốc độ request Nginx theo status, top URI lỗi, LOGIN_FAIL theo IP, cảnh báo) nạp bằng file provisioning.
- Prometheus thu thêm job `loki` và `promtail` (tổng 7 target).

Truy cập Loki từ máy chủ (Basic Auth như Prometheus; chỉ đọc, `POST`/push/delete → 403):
```bash
curl -s -u "$MONITOR_BASIC_USER:$MONITOR_BASIC_PASSWORD" http://127.0.0.1:3100/ready
scripts/logql-demo.sh 1h        # chạy 8 truy vấn LogQL mẫu bên dưới (Basic Auth: user trong `.env`, mật khẩu trong `secrets/monitor_basic_password`)
```

LogQL mẫu:
```logql
{service="nginx", stream="stdout"} | json | method="GET"                       # request GET
{service="nginx", stream="stdout"} | json | status >= 400                      # lỗi 4xx/5xx
{service=~".+"} |~ "(?i)error"                                                 # chữ "error" toàn project
sum by (status) (rate({service="nginx", stream="stdout"}[1m]))                 # req/s theo status
sum by (ip) (count_over_time({service="wordpress"} |= "LOGIN_FAIL" | json [5m]))  # đăng nhập sai theo IP
{service="nginx", stream="stdout"} | json | status = 429 | uri =~ "/wp-login.php.*" # bị rate limit
{service="db"}                                                                 # log MySQL
```

## Minh chứng
Xem `docs/screenshots/`.
