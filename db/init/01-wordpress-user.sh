#!/bin/bash
# Chạy một lần khi khởi tạo volume. Tạo DB + user riêng cho WordPress với quyền tối thiểu
# (không dùng ALL PRIVILEGES, không có quyền trên DB khác, không có GRANT OPTION).
set -euo pipefail

mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${WP_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${WP_DB_USER}'@'%' IDENTIFIED BY '${WP_DB_PASSWORD}';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, INDEX, REFERENCES
  ON \`${WP_DB_NAME}\`.* TO '${WP_DB_USER}'@'%';
FLUSH PRIVILEGES;
SQL
