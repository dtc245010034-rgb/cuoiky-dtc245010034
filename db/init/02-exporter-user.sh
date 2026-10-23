#!/bin/bash
# User riêng cho mysqld-exporter: chỉ đọc số liệu giám sát, không đụng dữ liệu website.
# Chạy tự động khi khởi tạo volume mới; với DB đang chạy dùng scripts/apply-exporter-user.sh.
# User chỉ đăng nhập được từ subnet mạng backend (DB_CLIENT_SUBNET), không dùng host '%'.
# Idempotent: chạy lại chỉ đồng bộ mật khẩu/quyền. Mật khẩu đọc từ Docker secrets (/run/secrets).
set -euo pipefail
source /docker-entrypoint-initdb.d/host-pattern.inc

CLIENT_HOST="$(cidr_to_host_pattern "${DB_CLIENT_SUBNET:?thiếu DB_CLIENT_SUBNET}")"
EXPORTER_DB_PASSWORD="$(< /run/secrets/mysql_exporter_password)"
export MYSQL_PWD="$(< /run/secrets/mysql_root_password)"

mysql -uroot <<SQL
CREATE USER IF NOT EXISTS '${EXPORTER_DB_USER}'@'${CLIENT_HOST}' IDENTIFIED BY '${EXPORTER_DB_PASSWORD}' WITH MAX_USER_CONNECTIONS 3;
ALTER USER '${EXPORTER_DB_USER}'@'${CLIENT_HOST}' IDENTIFIED BY '${EXPORTER_DB_PASSWORD}' WITH MAX_USER_CONNECTIONS 3;
GRANT PROCESS, REPLICATION CLIENT ON *.* TO '${EXPORTER_DB_USER}'@'${CLIENT_HOST}';
GRANT SELECT ON performance_schema.* TO '${EXPORTER_DB_USER}'@'${CLIENT_HOST}';
FLUSH PRIVILEGES;
SQL
