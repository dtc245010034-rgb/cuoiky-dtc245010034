#!/usr/bin/env bash
# Sinh chứng chỉ TLS tự ký cho Nginx: RSA 2048, CN=localhost, có SAN.
# Chứng chỉ (công khai) → nginx/certs/server.crt; khóa riêng → secrets/server.key (Docker secret).
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="${CERT_DIR:-nginx/certs}"
SEC="${SECRETS_DIR:-secrets}"
DAYS="${CERT_DAYS:-365}"

mkdir -p "$OUT" "$SEC"
chmod 700 "$SEC"
if [[ -f "$OUT/server.crt" && -f "$SEC/server.key" && "${1:-}" != "--force" ]]; then
  echo "Đã có $OUT/server.crt và $SEC/server.key (dùng --force để sinh lại)."
  exit 0
fi

openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days "$DAYS" \
  -keyout "$SEC/server.key" -out "$OUT/server.crt" \
  -subj "/C=VN/O=ICTU/OU=KTMT K23/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
  -addext "basicConstraints=critical,CA:FALSE" \
  -addext "keyUsage=critical,digitalSignature,keyEncipherment" \
  -addext "extendedKeyUsage=serverAuth"

chmod 644 "$SEC/server.key"   # thư mục secrets/ là 700; container non-root cần đọc được
chmod 644 "$OUT/server.crt"
echo "Đã tạo $OUT/server.crt và $SEC/server.key (hiệu lực $DAYS ngày)."
openssl x509 -in "$OUT/server.crt" -noout -subject -enddate -ext subjectAltName
