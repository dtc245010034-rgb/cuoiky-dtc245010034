#!/bin/bash
# Chạy một lần khi khởi tạo volume. Tạo DB + user riêng cho WordPress với quyền tối thiểu
# (không dùng ALL PRIVILEGES, không có quyền trên DB khác, không có GRANT OPTION).
# User chỉ đăng nhập được từ subnet mạng backend (DB_CLIENT_SUBNET), không dùng host '%'.
# Mật khẩu đọc từ Docker secrets (/run/secrets), không qua biến môi trường.
# Idempotent: scripts/migrate-db-users.sh chạy lại script này cho DB đang chạy.
set -euo pipefail
source /docker-entrypoint-initdb.d/host-pattern.inc

CLIENT_HOST="$(cidr_to_host_pattern "${DB_CLIENT_SUBNET:?thiếu DB_CLIENT_SUBNET}")"
WP_DB_PASSWORD="$(< /run/secrets/mysql_password)"
export MYSQL_PWD="$(< /run/secrets/mysql_root_password)"

mysql -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`${WP_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${WP_DB_USER}'@'${CLIENT_HOST}' IDENTIFIED BY '${WP_DB_PASSWORD}';
ALTER USER '${WP_DB_USER}'@'${CLIENT_HOST}' IDENTIFIED BY '${WP_DB_PASSWORD}';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, INDEX, REFERENCES
  ON \`${WP_DB_NAME}\`.* TO '${WP_DB_USER}'@'${CLIENT_HOST}';
FLUSH PRIVILEGES;
SQL
