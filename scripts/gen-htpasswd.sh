#!/usr/bin/env bash
# Sinh secrets/htpasswd (Basic Auth của Nginx cho Prometheus, cAdvisor, Loki): user từ .env,
# mật khẩu từ secrets/monitor_basic_password (gen-secrets.sh đã tạo sẵn cả hai).
# Băm bằng openssl passwd -apr1; mật khẩu không được in ra.
set -euo pipefail

cd "$(dirname "$0")/.."
SEC="${SECRETS_DIR:-secrets}"
[[ -f .env ]] || { echo "Thiếu .env" >&2; exit 1; }
[[ -f "$SEC/monitor_basic_password" ]] || { echo "Thiếu $SEC/monitor_basic_password (chạy scripts/gen-secrets.sh)" >&2; exit 1; }

user=$(grep -E '^MONITOR_BASIC_USER=' .env | head -1 | cut -d= -f2-)
[[ -n "$user" ]] || { echo "Đặt MONITOR_BASIC_USER trong .env" >&2; exit 1; }

printf '%s:%s' "$user" "$(openssl passwd -apr1 -stdin < "$SEC/monitor_basic_password")" > "$SEC/htpasswd"
chmod 644 "$SEC/htpasswd"   # container non-root đọc qua bind mount :ro; thư mục secrets/ là 700
echo "Đã tạo $SEC/htpasswd cho user '$user'."
