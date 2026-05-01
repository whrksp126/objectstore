---
description: 홈서버 objectstore(MinIO) 컨테이너 로그 보기
allowed-tools: Bash
argument-hint: [tail-lines | -f]
---

`bash scripts/logs.sh $ARGUMENTS`를 실행해서 로그를 보여줘.

- 인자 없이 호출되면 마지막 50줄
- 숫자만 주면 그 줄 수만큼 (예: `/logs 200`)
- `-f`이면 follow 모드 — 사용자가 Ctrl+C로 끊어야 함, 절대 자동으로 끊지 마
- 에러 라인(level=ERROR 또는 ERR/FATAL)이 보이면 출력 끝에 "에러 N건 감지" 한 줄 짧게 추가
