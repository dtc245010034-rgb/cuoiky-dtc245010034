#!/usr/bin/env bash
# Áp dụng user exporter cho DB ĐANG CHẠY (db/init chỉ tự chạy khi volume còn trống).
# Cần container db đã có DB_CLIENT_SUBNET, EXPORTER_DB_USER và các Docker secrets (docker compose up -d db).
set -euo pipefail

cd "$(dirname "$0")/.."
docker compose exec -T db bash /docker-entrypoint-initdb.d/02-exporter-user.sh
echo "Đã áp dụng user exporter. Kiểm tra:"
docker compose exec -T db bash -c 'source /docker-entrypoint-initdb.d/host-pattern.inc
  MYSQL_PWD="$(< /run/secrets/mysql_root_password)" mysql -uroot -e "SHOW GRANTS FOR \"$EXPORTER_DB_USER\"@\"$(cidr_to_host_pattern "$DB_CLIENT_SUBNET")\""'
