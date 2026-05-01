#!/usr/bin/env bash
# settings.json의 PostToolUse hook이 인라인으로 처리하지만,
# 수동 검증할 때 쓸 수 있도록 동일 로직을 별도 파일로도 둠.
# 사용: bash .claude/hooks/validate-compose.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

echo "[validate] docker-compose.yml"
docker compose -f docker-compose.yml config -q

echo "[validate] docker-compose.prod.yml (merged)"
docker compose -f docker-compose.yml -f docker-compose.prod.yml config -q

echo "[validate] deploy/objectstore.conf"
docker run --rm -v "${ROOT_DIR}/deploy":/conf nginx:1.27-alpine sh -c \
  "cp /conf/objectstore.conf /etc/nginx/conf.d/objectstore.conf && nginx -t" \
  2>&1 | tail -3

echo "[validate] ✅ all green"
