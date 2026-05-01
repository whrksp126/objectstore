# objectstore — Claude Code 작업 지침

홈서버용 **AWS S3 호환 오브젝트 스토리지** (MinIO 기반).

## 프로젝트 목표

홈서버에서 도는 자체 S3. 외부 클라우드(AWS S3 등) 의존 없이 본인 서비스/실험에서 버킷을
자유롭게 만들고, 사람은 Web Console로, 코드는 S3 SDK로 접근한다. 같은 부모 경로의
`serverState`와 동일한 배포 패턴(docker compose 분리, nginx_proxy 외부 네트워크,
deploy.sh 자동화)을 답습한다.

## 워크플로우 (불변)

### 일상 개발 — 슬래시 커맨드 한 줄
| 명령 | 동작 |
|---|---|
| `/local-up` | 로컬 맥북에 MinIO 기동 (`scripts/up.sh local`) |
| `/local-down` | 로컬 중지 |
| `/deploy` | uncommitted 체크 → push → 홈서버 pull/up/nginx 동기화 → 헬스체크 |
| `/deploy --restart` | 코드 변경 없을 때도 컨테이너 강제 재기동 |
| `/status` | 홈서버 컨테이너/헬스/디스크/버킷 한눈에 |
| `/logs [N \| -f]` | 홈서버 minio 로그 (예: `/logs 200`, `/logs -f`) |

### 흐름 요약
1. 로컬 변경 → `/local-up` 검증 → http://localhost:9001 에서 Console 확인
2. `git commit`
3. `/deploy` 한 줄로 홈서버 반영
4. `/status`로 정상 동작 확인

### 최초 1회 (이미 완료됐다면 스킵)
- 홈서버에 `/srv/projects/objectstore/` clone, `.env.dev` 작성 (chmod 600)
- `/srv/nginx-proxy/conf.d/objectstore.conf` 배치, nginx_proxy 재시작
- Cloudflare DNS CNAME 두 개:
  - `objectstore` → `ghmate.iptime.org` (Proxy ON)
  - `objectstore-console` → `ghmate.iptime.org` (Proxy ON)

## 절대 규칙

- **`.env.local`, `.env.dev`는 절대 git에 커밋하지 않는다.** 이미 `.gitignore`에 포함.
- **호스트 포트는 hardcode 금지.** docker-compose.yml의 ports는 모두 `${VAR:-default}` 형식.
- **다른 도커 프로젝트의 포트(예: serverState의 3000/9090)와 충돌하면 안 된다.** 변경은 `.env.local`/`.env.dev`에서.
- **Root key는 Console 관리용.** 앱이 SDK로 부를 때는 Console에서 별도 access key를 발급해 사용.
- **nginx 설정 변경 시 두 도메인 블록을 모두 검토.** API/Console 둘 중 한 쪽만 깨지면 사용자가 진단하기 어렵다.

## 컨테이너 / 네트워크 / 볼륨

| 항목 | 값 |
|---|---|
| 컨테이너 (로컬) | `objectstore-minio` |
| 컨테이너 (운영) | `objectstore_minio_prod` |
| 네트워크 (내부) | `objectstore-net` |
| 네트워크 (운영, nginx 연결) | `nginx_proxy` (external) |
| 데이터 볼륨 | `objectstore_minio_data` (named) |
| API 포트 | 9000 |
| Console 포트 | 9001 |

## 변경 시 자동 검증 (settings.json hooks)

`.claude/settings.json`에 PostToolUse 훅이 걸려 있어 다음 파일을 편집하면 자동 검증된다:

- `docker-compose.yml`, `docker-compose.prod.yml` → `docker compose config -q`
- `deploy/objectstore.conf` → `nginx -t` (도커 컨테이너 사용)

훅이 실패하면 커밋/배포하지 말고 실패 메시지를 따라 수정한다.

## 환경변수

전체 변수 목록과 예시 값은 `README.md`의 "환경변수" 표 참조.
새 변수를 추가할 때는 `docker-compose.yml`에 `${VAR:-default}` 형태로 노출하고
`.env.example`과 README 표에 1줄씩 추가.

## 외부 도메인

- API (S3 SDK endpoint): `https://objectstore.ghmate.com`
- Console (Web UI): `https://objectstore-console.ghmate.com`
- 흐름: Cloudflare(Proxy) → iptime DDNS(`ghmate.iptime.org`) → 홈서버 `nginx_proxy` → MinIO 컨테이너
- 다른 기존 서비스(`serverstate`, `heyvoca-back`, `dev-openday` 등)와 동일 패턴

## 절대 하지 말 것

- 운영 환경에서 root password를 약하게 (8자 미만이면 컨테이너가 즉시 crash)
- 큰 파일 업로드 시 단일 PUT 사용 (Cloudflare 무료 플랜 100MB 제한) — SDK 멀티파트 사용
- nginx conf의 `proxy_buffering off` / `client_max_body_size 5G` 제거 (대용량 업로드 깨짐)
- root key를 애플리케이션 코드에 박아넣기 — Console에서 access key 발급해서 쓸 것
- 기존 서비스가 쓰는 호스트 포트와 겹치는 매핑

## 자주 쓰는 명령 (셸에서 직접)

```bash
# 로컬
bash scripts/up.sh local
bash scripts/down.sh local
docker compose --env-file .env.local logs -f minio

# 클라이언트 검증
mc alias set local http://localhost:9000 admin <PASSWORD>
mc ls local
aws --endpoint-url http://localhost:9000 --profile minio-local s3 ls

# 홈서버 자동화
bash scripts/deploy.sh                          # 표준 배포
bash scripts/deploy.sh --restart                # 강제 재기동
bash scripts/status.sh                          # 상태
bash scripts/logs.sh 200                        # 마지막 200줄
bash scripts/logs.sh -f                         # follow
```

## cmux 사용

사용자는 항상 cmux에서 작업한다. setup 스크립트가 띄워둔 로그 탭은 `cmux capture-pane`으로
가져올 것 — `docker logs`나 SSH로 재실행하지 말 것.

## 슬래시 커맨드 (Claude Code 내부)
`/deploy`, `/status`, `/logs [N|-f]`, `/local-up`, `/local-down` — 위 셸 명령을 한 줄로 트리거.
