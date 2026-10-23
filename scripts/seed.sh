#!/usr/bin/env bash
# Cài WordPress + nạp nội dung mẫu bằng wp-cli (container chạy một lần, profile "setup").
# wpcli được nối thêm mạng "egress" để tải theme/plugin, rồi ghi vào volume wp_html dùng chung;
# dịch vụ WordPress chạy thường vẫn chỉ nằm trên mạng nội bộ (backend).
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose --profile setup run --rm wpcli
