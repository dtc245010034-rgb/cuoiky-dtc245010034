#!/usr/bin/env bash
# Kiểm tra hardening của stack đang chạy; in PASS/FAIL theo nhóm, thoát mã 1 nếu có FAIL.
# Không in mật khẩu.
#   scripts/verify-hardening.sh             đầy đủ: một dòng cho mỗi kiểm tra
#   scripts/verify-hardening.sh --summary   vẫn chạy đủ mọi kiểm tra, chỉ in 1 dòng mỗi nhóm
#                                           (+ INFO ngoại lệ, + chi tiết các dòng FAIL nếu có)
# Lưu ý: nhóm Nginx gửi 7 POST sai tới /wp-login.php để kiểm limit_req (sinh vài dòng LOGIN_FAIL
# với user "verify-hardening"; dưới ngưỡng cảnh báo >5/5 phút).
set -uo pipefail

cd "$(dirname "$0")/.."
SUMMARY=0
case "${1:-}" in
  "") ;;
  --summary) SUMMARY=1 ;;
  *) echo "Cách dùng: $0 [--summary]" >&2; exit 2 ;;
esac
[[ -f .env ]] || { echo "Thiếu .env" >&2; exit 2; }
P=dtc245010034
env_get() { grep -E "^$1=" .env | head -1 | cut -d= -f2-; }
MON_USER="$(env_get MONITOR_BASIC_USER)"
MON_PASS="$(< secrets/monitor_basic_password)"
HTTPS_PORT="$(env_get NGINX_HTTPS_PORT)"; HTTPS_PORT="${HTTPS_PORT:-8443}"
HTTP_PORT="$(env_get NGINX_HTTP_PORT)"; HTTP_PORT="${HTTP_PORT:-8080}"
LOKI_PORT="$(env_get LOKI_PORT)"; LOKI_PORT="${LOKI_PORT:-3100}"
PROM_PORT="$(env_get PROMETHEUS_PORT)"; PROM_PORT="${PROM_PORT:-9090}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
# Chế độ --summary gom kết quả theo nhóm; chế độ đầy đủ in ngay từng dòng.
gname=""; gpass=0; gfail=0; gbad=""; ginfo=""
flush_group() {
  [[ "$SUMMARY" -eq 1 && -n "$gname" ]] || return 0
  local t=$((gpass + gfail)) tag=PASS
  [[ "$gfail" -gt 0 ]] && tag=FAIL
  printf '[%s] %s %d/%d\n' "$tag" "$gname" "$gpass" "$t"
  [[ -n "$ginfo" ]] && printf '%s' "$ginfo"
  [[ -n "$gbad" ]] && printf '%s' "$gbad"
  gname=""
  return 0
}
ok() {
  pass=$((pass + 1)); gpass=$((gpass + 1))
  [[ "$SUMMARY" -eq 1 ]] || printf 'PASS  %s\n' "$1"
}
bad() {
  fail=$((fail + 1)); gfail=$((gfail + 1))
  if [[ "$SUMMARY" -eq 1 ]]; then gbad+="$(printf '       FAIL  %s' "$1")"$'\n'; else printf 'FAIL  %s\n' "$1"; fi
}
info() {
  if [[ "$SUMMARY" -eq 1 ]]; then ginfo+="$(printf '       INFO  %s' "$1")"$'\n'; else printf 'INFO  %s\n' "$1"; fi
}
detail() { # dòng chi tiết phụ của một FAIL
  if [[ "$SUMMARY" -eq 1 ]]; then gbad+="$(printf '       %s' "$1")"$'\n'; else printf '      %s\n' "$1"; fi
}
check() { # check "mô tả" lệnh... : PASS nếu lệnh thoát 0
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi
}
eq() { # eq "mô tả" thực_tế mong_đợi
  if [[ "$2" == "$3" ]]; then ok "$1 ($2)"; else bad "$1: được '$2', cần '$3'"; fi
}
group() { # group "tiêu đề đầy đủ" "tên ngắn cho --summary"
  flush_group; gpass=0; gfail=0; gbad=""; ginfo=""
  if [[ "$SUMMARY" -eq 1 ]]; then gname="$2"; else printf '\n== %s\n' "$1"; fi
}
code() { curl -s -o /dev/null -m 8 -w '%{http_code}' "$@" 2>/dev/null || true; }
cname() { echo "$P-$1"; }
running() { docker inspect -f '{{.State.Running}}' "$(cname "$1")" 2>/dev/null | grep -q true; }
euid() { local pid; pid="$(docker inspect -f '{{.State.Pid}}' "$(cname "$1")")"; awk '/^Uid:/ {print $3}' "/proc/$pid/status"; }

for s in db wordpress nginx phpmyadmin prometheus grafana loki promtail docker-socket-proxy; do
  running "$s" || { echo "Container $s không chạy: docker compose up -d trước đã." >&2; exit 2; }
done
CONTAINERS="$(docker ps -aq --filter "label=com.docker.compose.project=$P")"

# ---------------------------------------------------------------------------
group "1. Non-root / quyền tiến trình" "Non-root"
for s in db wordpress nginx grafana prometheus loki promtail docker-socket-proxy node-exporter mysqld-exporter nginx-exporter; do
  running "$s" || { bad "$s không chạy"; continue; }
  u="$(euid "$s")"
  if [[ "$u" != 0 ]]; then ok "$s chạy non-root (uid $u)"; else bad "$s chạy bằng root"; fi
done
info "cAdvisor chạy root (ngoại lệ): cần đọc cgroup và metadata Docker của host qua mount chỉ-đọc"
info "phpMyAdmin chạy root (ngoại lệ): image Apache; chỉ ở mạng backend internal, truy cập qua loopback + ACL"
for s in wordpress nginx grafana loki promtail docker-socket-proxy nginx-exporter mysqld-exporter; do
  c="$(cname "$s")"
  drop="$(docker inspect -f '{{.HostConfig.CapDrop}}' "$c")"; add="$(docker inspect -f '{{.HostConfig.CapAdd}}' "$c")"
  nnp="$(docker inspect -f '{{.HostConfig.SecurityOpt}}' "$c")"
  if [[ "$drop" == *ALL* && "$add" == "[]" && "$nnp" == *no-new-privileges* ]]; then
    ok "$s: cap_drop ALL, không cap_add, no-new-privileges"
  else bad "$s: CapDrop=$drop CapAdd=$add SecurityOpt=$nnp"; fi
done
for s in loki promtail docker-socket-proxy; do
  eq "$s: rootfs read-only" "$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' "$(cname "$s")")" true
done
priv=0; for c in $CONTAINERS; do [[ "$(docker inspect -f '{{.HostConfig.Privileged}}' "$c")" == true ]] && priv=1; done
eq "không container nào privileged" "$priv" 0
eq "Nginx dùng image unprivileged" "$(docker inspect -f '{{.Config.Image}}' "$(cname nginx)" | cut -d: -f1)" nginxinc/nginx-unprivileged

# ---------------------------------------------------------------------------
group "2. Mạng" "Mạng"
net() { docker network inspect "${P}_$1" -f "{{(index .IPAM.Config 0).Subnet}} internal={{.Internal}}" 2>/dev/null; }
eq "frontend subnet cố định"   "$(net frontend)"   "10.250.10.0/24 internal=false"
eq "backend internal"          "$(net backend)"    "10.250.20.0/24 internal=true"
eq "monitoring internal"       "$(net monitoring)" "10.250.30.0/24 internal=true"
eq "dockerapi internal"        "$(net dockerapi)"  "10.250.250.0/29 internal=true"
eq "db chỉ ở mạng backend" "$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$(cname db)" | xargs)" "${P}_backend"
others="$(docker ps --filter "label=com.docker.compose.project=$P" --format '{{.Names}} {{.Ports}}' | grep -v "^$P-nginx " | grep -c -- '->' || true)"
eq "ngoài nginx không container nào publish cổng" "$others" 0
ports="$(docker port "$(cname nginx)" | grep -v '\[::\]')"
exposed_ok=1
while read -r line; do
  [[ -z "$line" ]] && continue
  cport="${line%%/*}"; bind="${line##*-> }"; host="${bind%:*}"
  case "$cport" in
    8080|8443) [[ "$host" == 0.0.0.0 ]] || exposed_ok=0 ;;
    *) [[ "$host" == 127.0.0.1 ]] || { exposed_ok=0; detail "cổng $cport bind $host"; } ;;
  esac
done <<<"$ports"
eq "cổng quản trị chỉ bind 127.0.0.1 (8080/8443 mở ngoài)" "$exposed_ok" 1
if docker exec "$(cname wordpress)" bash -c 'timeout 4 bash -c "exec 3<>/dev/tcp/1.1.1.1/443"' >/dev/null 2>&1; then
  bad "wordpress ra được Internet"; else ok "wordpress không có đường ra Internet"; fi
lan="$(ip -4 route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' | head -1)"
if [[ -n "$lan" ]]; then
  for p in 8081 3001 "$PROM_PORT" 8082 "$LOKI_PORT"; do
    eq "cổng $p không truy cập được qua IP LAN $lan" "$(code -m 4 "http://$lan:$p/")" 000
  done
else info "không xác định IP LAN, bỏ qua kiểm tra cổng loopback từ LAN"; fi

# ---------------------------------------------------------------------------
group "3. Secrets" "Secrets"
eq "secrets/ chmod 700" "$(stat -c %a secrets)" 700
check "secrets/ bị git bỏ qua" git check-ignore -q secrets/mysql_password
eq ".env không còn biến *PASSWORD*" "$(grep -c PASSWORD .env || true)" 0
leaks=0
for c in $CONTAINERS; do
  docker inspect "$c" > "$TMP/i.json"
  for f in secrets/*password; do
    grep -qF -- "$(< "$f")" "$TMP/i.json" && { leaks=$((leaks + 1)); detail "LỘ $(basename "$f") trong $(docker inspect -f '{{.Name}}' "$c")"; }
  done
done
eq "docker inspect $(echo "$CONTAINERS" | wc -w) container không lộ mật khẩu" "$leaks" 0
docker compose --profile setup config > "$TMP/cfg.txt" 2>&1
cl=0; for f in secrets/*password; do grep -qF -- "$(< "$f")" "$TMP/cfg.txt" && cl=$((cl + 1)); done
eq "docker compose config không chứa mật khẩu" "$cl" 0
for pair in "nginx:tls_key" "nginx:nginx_htpasswd" "db:mysql_root_password" "wordpress:mysql_password" "grafana:grafana_admin_password"; do
  s="${pair%%:*}"; f="${pair##*:}"
  u="$(euid "$s")"
  if docker exec -u "$u" "$(cname "$s")" sh -c "cat /run/secrets/$f >/dev/null" 2>/dev/null; then
    ok "$s (uid $u) đọc được /run/secrets/$f"; else bad "$s (uid $u) không đọc được /run/secrets/$f"; fi
done

# ---------------------------------------------------------------------------
group "4. Quyền DB" "Quyền DB"
rootsql() { docker exec -i "$(cname db)" bash -c 'MYSQL_PWD="$(< /run/secrets/mysql_root_password)" mysql -uroot -N' ; }
eq "không user nào host '%'" "$(echo "SELECT COUNT(*) FROM mysql.user WHERE host='%'" | rootsql 2>/dev/null)" 0
eq "root chỉ localhost" "$(echo "SELECT GROUP_CONCAT(host) FROM mysql.user WHERE user='root'" | rootsql 2>/dev/null)" localhost
subnet_users="$(echo "SELECT COUNT(*) FROM mysql.user WHERE user IN ('wp_user','exporter') AND host LIKE '10.250.20.0/%'" | rootsql 2>/dev/null)"
eq "wp_user và exporter gắn subnet backend" "$subnet_users" 2
wpg="$(echo "SHOW GRANTS FOR 'wp_user'@'10.250.20.0/255.255.255.0'" | rootsql 2>/dev/null)"
if grep -q 'ALL PRIVILEGES\|GRANT OPTION' <<<"$wpg"; then bad "wp_user có ALL PRIVILEGES/GRANT OPTION"; else ok "wp_user không có ALL PRIVILEGES/GRANT OPTION"; fi
eq_wp="$(docker exec "$(cname db)" bash -c '
  ip="$(awk "/^[0-9.]+[[:space:]]/ {l=\$1} END {print l}" /etc/hosts)"
  export MYSQL_PWD="$(< /run/secrets/mysql_password)"
  q() { mysql -h "$ip" -uwp_user -N -e "$1" 2>&1; }
  echo "dbs=$(q "SHOW DATABASES" | tr "\n" ,)"
  q "SELECT 1 FROM mysql.user LIMIT 1" | grep -q "denied" && echo mysql_user_denied
  q "CREATE DATABASE hardening_test" | grep -q "denied" && echo create_db_denied' 2>/dev/null)"
eq "wp_user chỉ thấy DB wordpress" "$(grep -o '^dbs=.*' <<<"$eq_wp")" "dbs=information_schema,performance_schema,wordpress,"
check "wp_user không đọc được mysql.user" grep -q mysql_user_denied <<<"$eq_wp"
check "wp_user không tạo được DB" grep -q create_db_denied <<<"$eq_wp"
eg="$(echo "SHOW GRANTS FOR 'exporter'@'10.250.20.0/255.255.255.0'" | rootsql 2>/dev/null)"
if grep -q 'PROCESS, REPLICATION CLIENT' <<<"$eg" && ! grep -q 'ALL PRIVILEGES' <<<"$eg"; then ok "exporter chỉ PROCESS, REPLICATION CLIENT, SELECT performance_schema"; else bad "grant exporter không đúng"; fi
eq "mysql_up (Prometheus)" "$(curl -s -m 8 -u "$MON_USER:$MON_PASS" --data-urlencode 'query=mysql_up' "http://127.0.0.1:$PROM_PORT/api/v1/query" | jq -r '.data.result[0].value[1]' 2>/dev/null)" 1

# ---------------------------------------------------------------------------
group "5. Nginx (headers / 301 / TLS / 429 / 403)" "Nginx"
U="https://localhost:$HTTPS_PORT"
curl -skI -m 8 "$U/" > "$TMP/h.txt" 2>&1 || true
eq "HTTPS trang chủ" "$(code -k "$U/")" 200
for h in X-Frame-Options X-Content-Type-Options Referrer-Policy Strict-Transport-Security Permissions-Policy Content-Security-Policy; do
  check "header $h" grep -qi "^$h:" "$TMP/h.txt"
done
eq "Server không lộ phiên bản" "$(grep -i '^server:' "$TMP/h.txt" | tr -d '\r' | awk '{print tolower($2)}')" nginx
r="$(curl -s -o /dev/null -m 8 -w '%{http_code} %{redirect_url}' "http://localhost:$HTTP_PORT/abc?x=1")"
eq "HTTP $HTTP_PORT → 301 sang HTTPS" "$r" "301 https://localhost:$HTTPS_PORT/abc?x=1"
t12="$(echo | timeout 8 openssl s_client -connect "localhost:$HTTPS_PORT" -tls1_2 2>&1)"
t11="$(echo | timeout 8 openssl s_client -connect "localhost:$HTTPS_PORT" -tls1_1 2>&1)"
check "TLS 1.2 được chấp nhận" grep -Eq 'Protocol *: TLSv1\.2' <<<"$t12"
if grep -Eq 'Protocol *: TLSv1\.1' <<<"$t11"; then bad "TLS 1.1 vẫn được chấp nhận"; else ok "TLS 1.1 bị từ chối"; fi
eq "chứng chỉ tự ký còn hạn > 30 ngày" "$(openssl x509 -in nginx/certs/server.crt -noout -checkend $((30*86400)) >/dev/null 2>&1 && echo yes || echo no)" yes
codes=""; for _ in 1 2 3 4 5 6 7; do codes+="$(code -k -d 'log=verify-hardening&pwd=wrong' "$U/wp-login.php") "; done
if grep -q 429 <<<"$codes"; then ok "limit_req /wp-login.php trả 429 ($codes)"; else bad "không thấy 429 ($codes)"; fi
eq "/xmlrpc.php bị ngắt (444)" "$(code -k "$U/xmlrpc.php")" 000
for pair in "/wp-config.php:404" "/.git/config:404" "/.env:404" "/readme.html:404" "/wp-content/uploads/test.php:403"; do
  eq "${pair%%:*}" "$(code -k "$U${pair%%:*}")" "${pair##*:}"
done
css="$(curl -sk -m 8 "$U/" | grep -o '/wp-content/[^"]*\.css' | head -1)"
[[ -n "$css" ]] && eq "file tĩnh có đúng 1 header Cache-Control" "$(curl -skI -m 8 "$U$css" | grep -ic '^cache-control')" 1
for t in "nginx:8081/" "nginx:3001/" "nginx:$PROM_PORT/" "nginx:8082/" "nginx:$LOKI_PORT/ready" "nginx:8088/stub_status"; do
  c="$(docker exec "$(cname wordpress)" php -r '$h=@get_headers($argv[1]); echo $h ? explode(" ", $h[0])[1] : "ERR";' "http://$t" 2>/dev/null)"
  eq "từ container wordpress → $t" "$c" 403
done
eq "nginx-exporter đọc được stub_status (nginx_up)" "$(curl -s -m 8 -u "$MON_USER:$MON_PASS" --data-urlencode 'query=nginx_up' "http://127.0.0.1:$PROM_PORT/api/v1/query" | jq -r '.data.result[0].value[1]' 2>/dev/null)" 1

# ---------------------------------------------------------------------------
group "6. Prometheus / Loki / cAdvisor / Grafana — xác thực" "Xác thực giám sát"
eq "Prometheus không auth" "$(code "http://127.0.0.1:$PROM_PORT/-/healthy")" 401
eq "Prometheus có auth" "$(code -u "$MON_USER:$MON_PASS" "http://127.0.0.1:$PROM_PORT/-/healthy")" 200
eq "Prometheus POST /-/quit" "$(code -X POST -u "$MON_USER:$MON_PASS" "http://127.0.0.1:$PROM_PORT/-/quit")" 403
eq "Prometheus POST /-/reload" "$(code -X POST -u "$MON_USER:$MON_PASS" "http://127.0.0.1:$PROM_PORT/-/reload")" 403
eq "cAdvisor không auth" "$(code http://127.0.0.1:8082/healthz)" 401
eq "cAdvisor có auth" "$(code -u "$MON_USER:$MON_PASS" http://127.0.0.1:8082/healthz)" 200
eq "Loki /ready không auth" "$(code "http://127.0.0.1:$LOKI_PORT/ready")" 401
lr=000; for _ in $(seq 1 12); do lr="$(code -u "$MON_USER:$MON_PASS" "http://127.0.0.1:$LOKI_PORT/ready")"; [[ "$lr" == 200 ]] && break; sleep 5; done
eq "Loki /ready có auth" "$lr" 200
eq "Loki POST push" "$(code -X POST -u "$MON_USER:$MON_PASS" "http://127.0.0.1:$LOKI_PORT/loki/api/v1/push")" 403
eq "Loki /config" "$(code -u "$MON_USER:$MON_PASS" "http://127.0.0.1:$LOKI_PORT/config")" 403
eq "Grafana chưa đăng nhập → /login" "$(curl -s -o /dev/null -m 8 -w '%{http_code} %{redirect_url}' http://127.0.0.1:3001/ | sed 's|http://127.0.0.1:3001||')" "302 /login"
GU="$(env_get GRAFANA_ADMIN_USER)"
eq "Grafana đăng nhập admin" "$(code -u "$GU:$(< secrets/grafana_admin_password)" http://127.0.0.1:3001/api/search)" 200
eq "Grafana từ chối admin/admin" "$(code -u admin:admin http://127.0.0.1:3001/api/search)" 401
tg="$(curl -s -m 8 -u "$MON_USER:$MON_PASS" "http://127.0.0.1:$PROM_PORT/api/v1/targets" | jq -r '[.data.activeTargets[].health] | "\(map(select(.=="up"))|length)/\(length)"' 2>/dev/null)"
eq "Prometheus targets UP" "$tg" "7/7"

# ---------------------------------------------------------------------------
group "7. docker-socket-proxy" "Socket-proxy"
if docker image inspect curlimages/curl:8.11.1 >/dev/null 2>&1 || docker pull -q curlimages/curl:8.11.1 >/dev/null 2>&1; then
  pid="$(docker inspect -f '{{.Id}}' "$(cname promtail)")"
  api() { docker run --rm --network "${P}_dockerapi" --entrypoint curl curlimages/curl:8.11.1 -s -m 8 -o /dev/null -w '%{http_code}' "$@" 2>/dev/null; }
  B=http://docker-socket-proxy:2375
  eq "GET /containers/json"              "$(api "$B/containers/json")" 200
  eq "GET /containers/<id>/json"         "$(api "$B/containers/$pid/json")" 200
  eq "GET /networks"                     "$(api "$B/networks")" 200
  eq "GET /networks/<id>"                "$(api "$B/networks/bridge")" 403
  eq "GET /images/json"                  "$(api "$B/images/json")" 403
  eq "GET /containers/<id>/archive"      "$(api "$B/containers/$pid/archive?path=/etc/hostname")" 403
  eq "POST /containers/create"           "$(api -X POST -H 'Content-Type: application/json' -d '{}' "$B/containers/create")" 403
  eq "POST /containers/<id>/exec"        "$(api -X POST "$B/containers/$pid/exec")" 403
  eq "DELETE /containers/<id>"           "$(api -X DELETE "$B/containers/$pid")" 403
else
  bad "không có image curlimages/curl:8.11.1 để thử proxy"
fi
sock="$(docker inspect -f '{{range .Mounts}}{{.Source}} {{end}}' "$(cname promtail)")"
if grep -q docker.sock <<<"$sock"; then bad "promtail mount docker.sock"; else ok "promtail không mount docker.sock"; fi
eq "proxy mount docker.sock chỉ-đọc" "$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/var/run/docker.sock"}}{{.RW}}{{end}}{{end}}' "$(cname docker-socket-proxy)")" false
eq "proxy chỉ nối mạng dockerapi" "$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$(cname docker-socket-proxy)" | xargs)" "${P}_dockerapi"

# ---------------------------------------------------------------------------
flush_group
if [[ "$SUMMARY" -eq 1 ]]; then
  if [[ "$fail" -eq 0 ]]; then printf 'Tổng: %d/%d PASS\n' "$pass" "$pass"; else printf 'Tổng: %d PASS, %d FAIL\n' "$pass" "$fail"; fi
else
  printf '\n== Tổng kết: %d PASS, %d FAIL\n' "$pass" "$fail"
fi
[[ "$fail" -eq 0 ]]
