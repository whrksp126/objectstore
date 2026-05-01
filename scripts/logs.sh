#!/usr/bin/env bash
# 홈서버 objectstore 컨테이너 로그 조회
# 사용:
#   bash scripts/logs.sh                  # 마지막 50줄
#   bash scripts/logs.sh 200              # 마지막 200줄
#   bash scripts/logs.sh -f               # follow (Ctrl+C로 종료)
set -euo pipefail

ARG="${1:-50}"

CONTAINER="objectstore_minio_prod"
SSH="ssh -i ${HOME}/.ssh/ghmate_server -p 222 ghmate@ghmate.iptime.org"

if [[ "${ARG}" == "-f" ]]; then
  ${SSH} -t "docker logs -f --tail 50 ${CONTAINER}"
else
  ${SSH} "docker logs --tail ${ARG} ${CONTAINER}"
fi
