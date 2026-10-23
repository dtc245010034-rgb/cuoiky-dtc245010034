#!/usr/bin/env bash
# Áp dụng user exporter cho DB ĐANG CHẠY (db/init chỉ tự chạy khi volume còn trống).
# Cần container db đã có biến EXPORTER_DB_* (docker compose up -d db nếu vừa thêm vào compose).
set -euo pipefail

cd "$(dirname "$0")/.."
docker compose exec -T db bash /docker-entrypoint-initdb.d/02-exporter-user.sh
echo "Đã áp dụng user exporter. Kiểm tra:"
docker compose exec -T db bash -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -e "SHOW GRANTS FOR \"$EXPORTER_DB_USER\"@\"%\""'
