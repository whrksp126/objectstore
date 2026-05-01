---
description: 로컬 맥북에서 objectstore(MinIO) 기동 (개발/검증용)
allowed-tools: Bash
---

`bash scripts/up.sh local`을 실행하고 결과를 보여줘.

기동 후:
- `curl -fsSL http://localhost:9000/minio/health/live` 한 번 호출해서 헬스 확인
- 컨테이너가 running이면 접속 URL 안내:
  - Console (Web UI): http://localhost:9001
  - API (S3 SDK endpoint): http://localhost:9000
- root user/password는 `.env.local`에서 사용자가 설정한 값이라고 짧게 알려줘
