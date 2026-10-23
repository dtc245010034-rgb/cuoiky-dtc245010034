#!/usr/bin/env bash
# Sinh chứng chỉ TLS tự ký cho Nginx: RSA 2048, CN=localhost, có SAN.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT=nginx/certs
DAYS="${CERT_DAYS:-365}"

mkdir -p "$OUT"
if [[ -f "$OUT/server.crt" && -f "$OUT/server.key" && "${1:-}" != "--force" ]]; then
  echo "Đã có $OUT/server.crt và server.key (dùng --force để sinh lại)."
  exit 0
fi

openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days "$DAYS" \
  -keyout "$OUT/server.key" -out "$OUT/server.crt" \
  -subj "/C=VN/O=ICTU/OU=KTMT K23/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
  -addext "basicConstraints=critical,CA:FALSE" \
  -addext "keyUsage=critical,digitalSignature,keyEncipherment" \
  -addext "extendedKeyUsage=serverAuth"

chmod 600 "$OUT/server.key"
chmod 644 "$OUT/server.crt"
echo "Đã tạo $OUT/server.crt và $OUT/server.key (hiệu lực $DAYS ngày)."
openssl x509 -in "$OUT/server.crt" -noout -subject -enddate -ext subjectAltName
