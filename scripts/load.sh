#!/usr/bin/env bash
# Sinh tải nhẹ trong N phút (mặc định 5) để biểu đồ Nginx/MySQL/CPU có biến động.
# Chỉ GET (không POST đăng nhập để tránh 429 làm nhiễu).
set -euo pipefail

MINUTES="${1:-5}"
BASE="${BASE_URL:-https://localhost:8443}"
END=$(( $(date +%s) + MINUTES * 60 ))
PATHS=(/ /san-pham/ /product/pt-echo-mini/ /lien-he/ /wp-login.php /?s=den /?s=loa)

echo "Sinh tải $MINUTES phút tới $BASE (Ctrl+C để dừng)..."
n=0
while (( $(date +%s) < END )); do
  for p in "${PATHS[@]}"; do
    curl -sk -o /dev/null "$BASE$p" || true
    n=$((n + 1))
  done
  sleep 0.5
done
echo "Xong: $n yêu cầu."
