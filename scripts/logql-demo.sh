#!/usr/bin/env bash
# Chạy các truy vấn LogQL mẫu qua Nginx (127.0.0.1:3100, Basic Auth lấy từ .env) và in kết quả rút gọn.
# Dùng sau khi sinh dữ liệu: scripts/load.sh 2 và vài lần đăng nhập sai/đúng vào /wp-login.php.
# Tham số: $1 = khoảng thời gian tính ngược (mặc định 1h).
set -euo pipefail

cd "$(dirname "$0")/.."
[[ -f .env ]] || { echo "Thiếu .env" >&2; exit 1; }
user=$(grep -E '^MONITOR_BASIC_USER=' .env | head -1 | cut -d= -f2-)
pass=$(grep -E '^MONITOR_BASIC_PASSWORD=' .env | head -1 | cut -d= -f2-)
port=$(grep -E '^LOKI_PORT=' .env | head -1 | cut -d= -f2-)
base="http://127.0.0.1:${port:-3100}"
range="${1:-1h}"
now=$(date +%s)
case "$range" in
  *h) secs=$(( ${range%h} * 3600 )) ;;
  *m) secs=$(( ${range%m} * 60 )) ;;
  *)  secs=3600 ;;
esac
start=$(( now - secs ))

# $1 = tiêu đề, $2 = LogQL, $3 = log|metric (cách hiển thị)
run() {
  local title=$1 query=$2 kind=$3
  echo; echo "### $title"; echo "LogQL: $query"
  local out
  out=$(curl -sS -G -u "$user:$pass" "$base/loki/api/v1/query_range" \
        --data-urlencode "query=$query" --data-urlencode "start=${start}000000000" \
        --data-urlencode "end=${now}000000000" --data-urlencode "limit=3" \
        --data-urlencode "step=60")
  if [[ $(jq -r .status <<<"$out") != success ]]; then echo "LỖI: $out"; return; fi
  if [[ $kind == log ]]; then
    echo "Số stream: $(jq '.data.result|length' <<<"$out"); 3 dòng mới nhất:"
    jq -r '[.data.result[].values[]]|sort_by(.[0])|reverse|.[0:3][]|.[1]' <<<"$out" | cut -c1-230
  else
    jq -r '.data.result[]|"\(.metric|tostring)  tổng/đỉnh=\([.values[][1]|tonumber]|max)"' <<<"$out"
  fi
}

run "1. Request GET trên Nginx" '{service="nginx", stream="stdout"} | json | method="GET"' log
run "2. Lỗi 4xx/5xx của Nginx" '{service="nginx", stream="stdout"} | json | status >= 400' log
run "3. Log có chữ error toàn project" '{service=~".+"} |~ "(?i)error"' log
run "4. Tốc độ request Nginx theo status (req/s)" 'sum by (status) (rate({service="nginx", stream="stdout"}[1m]))' metric
run "5. Đăng nhập thất bại theo IP (5 phút)" 'sum by (ip) (count_over_time({service="wordpress"} |= "LOGIN_FAIL" | json [5m]))' metric
run "6. Request bị rate limit 429 trên wp-login.php" '{service="nginx", stream="stdout"} | json | status = 429 | uri =~ "/wp-login.php.*"' log
run "7a. Log MySQL" '{service="db"}' log
run "7b. Log php-fpm / WordPress" '{service="wordpress"} !~ "LOGIN_"' log
