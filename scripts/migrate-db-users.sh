#!/usr/bin/env bash
# Chuyển user DB đang chạy từ host '%' sang đúng subnet mạng backend (DB_CLIENT_SUBNET). Idempotent.
#   1. tạo wp_user và exporter @<subnet> bằng chính init script (cùng mật khẩu, cùng quyền);
#   2. kiểm chứng đăng nhập bằng tài khoản mới (CURRENT_USER() phải là bản theo subnet);
#   3. DROP USER bản '%'; kiểm lại kết nối từ container wordpress.
# Cần: container db đã được tạo lại với DB_CLIENT_SUBNET (docker compose up -d) và secrets/ đã có.
set -euo pipefail

cd "$(dirname "$0")/.."
DB="docker compose exec -T db bash -c"

echo "==> 1. Tạo user theo subnet"
docker compose exec -T db bash /docker-entrypoint-initdb.d/01-wordpress-user.sh
docker compose exec -T db bash /docker-entrypoint-initdb.d/02-exporter-user.sh

echo "==> 2. Kiểm chứng đăng nhập bằng tài khoản theo subnet (từ chính IP backend của db)"
$DB 'source /docker-entrypoint-initdb.d/host-pattern.inc
  want="$(cidr_to_host_pattern "$DB_CLIENT_SUBNET")"; ip="$(awk "/^[0-9.]+[[:space:]]/ {l=\$1} END {print l}" /etc/hosts)"   # image không có lệnh hostname
  [[ -n "$ip" ]] || { echo "LỖI: không xác định được IP backend của db" >&2; exit 1; }
  for pair in "$WP_DB_USER:mysql_password" "$EXPORTER_DB_USER:mysql_exporter_password"; do
    u="${pair%%:*}"; f="${pair##*:}"
    got="$(MYSQL_PWD="$(< /run/secrets/$f)" mysql -h "$ip" -u"$u" -N -e "SELECT CURRENT_USER()")"
    [[ "$got" == "$u@$want" ]] || { echo "LỖI: $u khớp tài khoản $got, mong đợi $u@$want" >&2; exit 1; }
    echo "OK  $got"
  done'

echo "==> 3. Xóa user host '%'"
$DB 'MYSQL_PWD="$(< /run/secrets/mysql_root_password)" mysql -uroot -e "
  DROP USER IF EXISTS \"$WP_DB_USER\"@\"%\", \"$EXPORTER_DB_USER\"@\"%\"; FLUSH PRIVILEGES"'

echo "==> 4. Kiểm lại kết nối từ container wordpress (IP nguồn thật)"
docker compose exec -T wordpress php -r '
  $m = new mysqli("db", getenv("WORDPRESS_DB_USER"), trim(file_get_contents("/run/secrets/mysql_password")), getenv("WORDPRESS_DB_NAME"));
  if ($m->connect_error) { fwrite(STDERR, "LỖI: ".$m->connect_error."\n"); exit(1); }
  echo "OK  wordpress -> db: ", $m->query("SELECT CURRENT_USER()")->fetch_row()[0], "\n";'

echo "==> mysql.user"
$DB 'MYSQL_PWD="$(< /run/secrets/mysql_root_password)" mysql -uroot -e "SELECT user, host FROM mysql.user ORDER BY user, host"'
