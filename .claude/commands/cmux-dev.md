---
description: cmux 개발 환경 세팅 — 워크스페이스명 ObjectStore, 위는 Claude, 아래는 minio 로그 follow 패널
allowed-tools: Bash
argument-hint: [--rebuild]
---

`bash scripts/cmux-dev.sh $ARGUMENTS`를 실행하고 결과를 그대로 보여줘.

동작:
- 현재 cmux 워크스페이스 이름을 "ObjectStore"로 통일
- Claude 패널 아래에 minio 로그 패널 1개 배치
- 그 패널에서 `bash scripts/logs.sh -f`로 홈서버 minio follow 모드 로그 스트리밍

호출 의도 해석:
- 처음 호출 / "세팅해줘" / "개발 환경 띄워줘" → 그대로 실행
- "재시작" / "다시 띄워" / "로그 다시" / "로그 끊어졌어" → 그대로 실행 (스크립트가 멱등하게 follow 재시작)
- "싹 다시 깔아" / "레이아웃 깨졌어" → `--rebuild` 인자 붙여 실행

배치 결과:
```
[Claude Code]
[minio]
```

주의:
- Claude 패널(현재 포커스)은 절대 닫지 마. 스크립트가 알아서 보존하지만, 직접 cmux 명령을 더 호출해야 한다면 focused pane은 손대지 마.
- follow 모드 로그는 사용자가 Ctrl+C로 끊는 것이고, 스크립트의 재시작은 같은 패널 안에서 한 번만 일어난다 — 자동으로 죽이지 마.
- 출력에서 어떤 패널이 생성/재시작됐는지 한 줄로 사용자에게 보고.
