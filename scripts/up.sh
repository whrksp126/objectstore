#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-local}"
ENV_FILE=".env.${ENV_NAME}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "${ROOT_DIR}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "[up] ${ENV_FILE} 파일이 없습니다."
  echo "    README.md의 '환경변수' 표를 보고 ${ENV_FILE}을 먼저 작성하세요."
  echo "    예) cp .env.example .env.local"
  exit 1
fi

COMPOSE_FILES="-f docker-compose.yml"
if [[ "${ENV_NAME}" != "local" ]]; then
  # 홈서버: prod override (nginx_proxy 네트워크, 컨테이너 네이밍, 호스트 포트 제거)
  COMPOSE_FILES="${COMPOSE_FILES} -f docker-compose.prod.yml"
fi

echo "[up] using ${ENV_FILE}"
docker compose ${COMPOSE_FILES} --env-file "${ENV_FILE}" config >/dev/null
docker compose ${COMPOSE_FILES} --env-file "${ENV_FILE}" up -d
docker compose ${COMPOSE_FILES} --env-file "${ENV_FILE}" ps
