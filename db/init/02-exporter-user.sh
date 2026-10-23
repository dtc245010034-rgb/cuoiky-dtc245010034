#!/bin/bash
# User riêng cho mysqld-exporter: chỉ đọc số liệu giám sát, không đụng dữ liệu website.
# Chạy tự động khi khởi tạo volume mới; với DB đang chạy dùng scripts/apply-exporter-user.sh.
# Idempotent: chạy lại chỉ đồng bộ mật khẩu/quyền.
set -euo pipefail

mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<SQL
CREATE USER IF NOT EXISTS '${EXPORTER_DB_USER}'@'%' IDENTIFIED BY '${EXPORTER_DB_PASSWORD}' WITH MAX_USER_CONNECTIONS 3;
ALTER USER '${EXPORTER_DB_USER}'@'%' IDENTIFIED BY '${EXPORTER_DB_PASSWORD}' WITH MAX_USER_CONNECTIONS 3;
GRANT PROCESS, REPLICATION CLIENT ON *.* TO '${EXPORTER_DB_USER}'@'%';
GRANT SELECT ON performance_schema.* TO '${EXPORTER_DB_USER}'@'%';
FLUSH PRIVILEGES;
SQL
