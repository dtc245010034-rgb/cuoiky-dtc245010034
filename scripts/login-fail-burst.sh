#!/usr/bin/env bash
# Đăng nhập sai N lần (mặc định 7) vào /wp-login.php, cách nhau 13 giây, để mỗi lần vượt qua giới hạn
# 5 yêu cầu/phút của Nginx và tạo một dòng LOGIN_FAIL. Hơn 5 lần trong 5 phút từ cùng một IP sẽ làm
# rule Loki "WordPressLoginFailBurst" chuyển sang Firing (sau tối đa ~1 phút do chu kỳ đánh giá).
# Dùng tên đăng nhập giả và mật khẩu giả cố định; không đọc hay in bất kỳ mật khẩu thật nào.
# Dùng: scripts/login-fail-burst.sh [số_lần] [giây_chờ]      BASE_URL mặc định https://localhost:8443
set -euo pipefail

N="${1:-7}"
GAP="${2:-13}"
BASE="${BASE_URL:-https://localhost:8443}"

echo "Gửi $N lần đăng nhập sai tới $BASE/wp-login.php (cách nhau ${GAP}s)..."
for i in $(seq "$N"); do
  code=$(curl -sk -o /dev/null -w '%{http_code}' \
    --data-urlencode "log=burst-user-$i" --data-urlencode "pwd=sai-mat-khau-gia" \
    "$BASE/wp-login.php" || echo 000)
  echo "  lần $i/$N -> HTTP $code (200 = đã tới WordPress và bị ghi LOGIN_FAIL; 429 = bị rate limit)"
  (( i < N )) && sleep "$GAP"
done
echo "Xong. Xem trạng thái cảnh báo sau ~1 phút: Grafana → Alerting → Alert rules (Loki)."
