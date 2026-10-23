#!/usr/bin/env bash
# Tạo thư mục secrets/ (Docker secrets dạng file) — nguồn mật khẩu duy nhất của stack.
#
#   scripts/gen-secrets.sh            Cài mới: sinh mật khẩu ngẫu nhiên (openssl rand) vào secrets/.
#   scripts/gen-secrets.sh --migrate  Một lần, cho máy đã có .env cũ: chép các *_PASSWORD hiện có
#                                     sang secrets/ (KHÔNG đổi giá trị), chuyển khóa TLS và htpasswd.
#
# Idempotent: file đã tồn tại thì giữ nguyên, không bao giờ ghi đè. Không in giá trị bí mật,
# chỉ in tên file. Thư mục chmod 700, file chmod 644 (container non-root đọc được qua bind mount;
# việc chặn truy cập trên host dựa vào quyền 700 của thư mục).
# Đặt SECRETS_DIR=<thư mục> (và CERT_DIR=<thư mục>) để thử mà không đụng secrets/ và nginx/certs/ thật.
set -euo pipefail

cd "$(dirname "$0")/.."
SEC="${SECRETS_DIR:-secrets}"
MODE=fresh
case "${1:-}" in
  "") ;;
  --migrate) MODE=migrate ;;
  *) echo "Cách dùng: $0 [--migrate]" >&2; exit 2 ;;
esac

env_get() { # env_get KEY → giá trị trong .env (rỗng nếu thiếu)
  [[ -f .env ]] && { grep -E "^$1=" .env | head -1 | cut -d= -f2- || true; } || true
}
gen_pw() { openssl rand -base64 33 | tr -d '/+=\n' | cut -c1-24; }

mkdir -p "$SEC"
chmod 700 "$SEC"

# put NAME VALUE: chỉ tạo khi chưa có
put() {
  local name="$1" value="$2" f="$SEC/$1"
  if [[ -e "$f" ]]; then
    echo "giữ nguyên : $name"
    return 0
  fi
  [[ -n "$value" ]] || { echo "Thiếu giá trị cho $name" >&2; exit 1; }
  ( umask 077; printf '%s' "$value" > "$f" )
  chmod 644 "$f"
  echo "đã tạo     : $name"
}

# Mật khẩu: tên file ← tên biến trong .env cũ
declare -a PW=(
  "mysql_root_password:MYSQL_ROOT_PASSWORD"
  "mysql_password:MYSQL_PASSWORD"
  "mysql_exporter_password:MYSQL_EXPORTER_PASSWORD"
  "wp_admin_password:WP_ADMIN_PASSWORD"
  "grafana_admin_password:GRAFANA_ADMIN_PASSWORD"
  "monitor_basic_password:MONITOR_BASIC_PASSWORD"
)

for pair in "${PW[@]}"; do
  name="${pair%%:*}"; var="${pair##*:}"
  if [[ "$MODE" == migrate ]]; then
    val="$(env_get "$var")"
    if [[ -z "$val" || "$val" == CHANGE_ME ]]; then
      if [[ -e "$SEC/$name" ]]; then val="-"; else
        echo "Thiếu $var trong .env (không thể --migrate $name)" >&2; exit 1
      fi
    fi
    put "$name" "$val"
    if [[ -e "$SEC/$name" && "$val" != "-" && "$(cat "$SEC/$name")" != "$val" ]]; then
      echo "CẢNH BÁO   : $name khác $var trong .env (không ghi đè)" >&2
    fi
  else
    put "$name" "$(gen_pw)"
  fi
done

# mysqld-exporter: file cấu hình dẫn xuất
exp_user="$(env_get MYSQL_EXPORTER_USER)"
[[ -n "$exp_user" ]] || { echo "Đặt MYSQL_EXPORTER_USER trong .env" >&2; exit 1; }
put mysqld-exporter.cnf "$(printf '[client]\nuser=%s\npassword=%s\n' "$exp_user" "$(cat "$SEC/mysql_exporter_password")")"

# Khóa TLS và htpasswd
if [[ "$MODE" == migrate ]]; then
  if [[ ! -e "$SEC/server.key" && -f nginx/certs/server.key ]]; then
    ( umask 077; cp nginx/certs/server.key "$SEC/server.key" )
    chmod 644 "$SEC/server.key"
    rm -f nginx/certs/server.key
    echo "đã chuyển  : server.key (từ nginx/certs/)"
  fi
  if [[ ! -e "$SEC/htpasswd" && -f nginx/auth/htpasswd ]]; then
    cp nginx/auth/htpasswd "$SEC/htpasswd"
    chmod 644 "$SEC/htpasswd"
    rm -f nginx/auth/htpasswd
    echo "đã chuyển  : htpasswd (từ nginx/auth/)"
  fi
fi
if [[ ! -e "$SEC/htpasswd" ]]; then
  mon_user="$(env_get MONITOR_BASIC_USER)"
  [[ -n "$mon_user" ]] || { echo "Đặt MONITOR_BASIC_USER trong .env" >&2; exit 1; }
  put htpasswd "$(printf '%s:%s' "$mon_user" "$(openssl passwd -apr1 -stdin < "$SEC/monitor_basic_password")")"
else
  echo "giữ nguyên : htpasswd"
fi
if [[ ! -e "$SEC/server.key" ]]; then
  SECRETS_DIR="$SEC" bash scripts/gen-cert.sh >/dev/null 2>&1
  echo "đã tạo     : server.key (+ nginx/certs/server.crt)"
else
  echo "giữ nguyên : server.key"
fi

echo
ls -la "$SEC"
