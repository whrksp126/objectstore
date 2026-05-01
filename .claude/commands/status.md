---
description: 홈서버 objectstore 상태 한눈에 보기 (컨테이너/헬스/디스크/버킷)
allowed-tools: Bash
---

`bash scripts/status.sh`를 실행하고, 출력을 그대로 보여줘.

이상 신호(컨테이너 not running, 헬스 FAIL, /data 디스크 85% 초과)가 있으면
출력 아래에 한 줄로 짧게 강조해서 알려줘. 아무 이상 없으면 강조 없이 넘어가.
