#!/usr/bin/env bash
# Sinh nginx/auth/htpasswd (Basic Auth cho Prometheus 9090 và cAdvisor 8082) từ .env.
# Băm bằng openssl passwd -apr1; mật khẩu không được in ra.
set -euo pipefail

cd "$(dirname "$0")/.."
[[ -f .env ]] || { echo "Thiếu .env" >&2; exit 1; }

user=$(grep -E '^MONITOR_BASIC_USER=' .env | head -1 | cut -d= -f2-)
pass=$(grep -E '^MONITOR_BASIC_PASSWORD=' .env | head -1 | cut -d= -f2-)
[[ -n "$user" && -n "$pass" && "$pass" != "CHANGE_ME" ]] || { echo "Đặt MONITOR_BASIC_USER/PASSWORD trong .env" >&2; exit 1; }

mkdir -p nginx/auth
printf '%s:%s\n' "$user" "$(printf '%s' "$pass" | openssl passwd -apr1 -stdin)" > nginx/auth/htpasswd
chmod 644 nginx/auth/htpasswd   # nginx (root trong container) đọc qua bind mount :ro
echo "Đã tạo nginx/auth/htpasswd cho user '$user'."
