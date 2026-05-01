#!/usr/bin/env bash
# 홈서버 objectstore 상태 한눈에 보기
# 사용: bash scripts/status.sh
set -euo pipefail

SSH="ssh -i ${HOME}/.ssh/ghmate_server -p 222 ghmate@ghmate.iptime.org"

${SSH} bash -se <<'REMOTE'
set -e
echo "=== 컨테이너 상태 ==="
docker ps --filter "name=objectstore_" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo ""
echo "=== 헬스 ==="
# MINIO_SERVER_URL이 설정된 컨테이너는 Host 헤더가 일치해야 함
echo -n "  minio API     "
docker exec objectstore_minio_prod curl -fs -H "Host: objectstore.ghmate.com" http://localhost:9000/minio/health/live >/dev/null 2>&1 && echo OK || echo FAIL
echo -n "  minio ready   "
docker exec objectstore_minio_prod curl -fs -H "Host: objectstore.ghmate.com" http://localhost:9000/minio/health/ready >/dev/null 2>&1 && echo OK || echo FAIL

echo ""
echo "=== 데이터 디스크 사용량 ==="
docker exec objectstore_minio_prod df -h /data 2>/dev/null | awk 'NR==1 || NR==2 {printf "  %s\n", $0}'

echo ""
echo "=== 버킷 목록 ==="
# mc client는 컨테이너에 없을 수 있음 → admin info를 통해 간접 조회는 복잡하니, AWS S3 LIST API 직접 호출은 인증 필요.
# 컨테이너의 데이터 디렉토리에서 .minio.sys 제외하고 ls 한 줄로 표기.
docker exec objectstore_minio_prod ls /data 2>/dev/null | grep -v '^\.minio' | sed 's/^/  /' || echo "  (없음)"
REMOTE
