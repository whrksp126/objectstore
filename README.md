# objectstore

홈서버에서 도는 **AWS S3 호환 오브젝트 스토리지** (MinIO 기반).
같은 부모 경로의 [`serverState`](https://github.com/whrksp126/serverState) 배포 패턴을 그대로 답습한다.

- API 엔드포인트 (S3 SDK 용): `https://objectstore.ghmate.com`
- Console (사람이 쓰는 Web UI): `https://objectstore-console.ghmate.com`

---

## 폴더 구조

```
objectstore/
├── docker-compose.yml          # 베이스 (로컬 macOS에서도 동작)
├── docker-compose.prod.yml     # 홈서버 override
├── .env.example                # 커밋되는 템플릿
├── .env.local                  # 로컬용 (gitignore)
├── .env.dev                    # 홈서버용 (gitignore, 서버에만 존재)
├── deploy/
│   └── objectstore.conf        # nginx vhost (API + Console 두 개)
├── scripts/
│   ├── up.sh                   # ./up.sh local | dev
│   ├── down.sh
│   ├── logs.sh
│   ├── status.sh
│   └── deploy.sh               # 로컬→서버 자동 배포
└── .claude/                    # Claude Code 하네스
```

---

## 환경변수

| 변수 | 기본값 | 설명 |
|---|---|---|
| `MINIO_ROOT_USER` | `admin` | root 계정 — Console 관리용. 길이 ≥ 3자 |
| `MINIO_ROOT_PASSWORD` | — | root 패스워드. 길이 ≥ 8자, 운영에서는 강력하게 |
| `MINIO_API_HOST_PORT` | `9000` | 로컬 호스트의 API 포트 (prod에선 무시됨) |
| `MINIO_CONSOLE_HOST_PORT` | `9001` | 로컬 호스트의 Console 포트 (prod에선 무시됨) |
| `MINIO_SERVER_URL` | `http://localhost:9000` | MinIO가 자기 자신을 외부에 어떻게 부르는지. 운영에선 `https://objectstore.ghmate.com` |
| `MINIO_BROWSER_REDIRECT_URL` | `http://localhost:9001` | Console이 자기 자신을 외부에 어떻게 부르는지. 운영에선 `https://objectstore-console.ghmate.com` |

---

## 로컬 실행 (맥북)

```bash
cp .env.example .env.local
# .env.local 의 MINIO_ROOT_PASSWORD 를 8자 이상으로 수정

./scripts/up.sh local

# Console: http://localhost:9001 (admin / 본인 패스워드)
# API:    http://localhost:9000

./scripts/down.sh local
```

### S3 호환 클라이언트로 동작 확인

```bash
# AWS CLI
aws configure --profile minio-local
# AWS Access Key ID:     <MINIO_ROOT_USER>
# AWS Secret Access Key: <MINIO_ROOT_PASSWORD>
# region: us-east-1 (아무거나)
# format: json

aws --endpoint-url http://localhost:9000 --profile minio-local s3 mb s3://test
aws --endpoint-url http://localhost:9000 --profile minio-local s3 cp ./somefile s3://test/
aws --endpoint-url http://localhost:9000 --profile minio-local s3 ls s3://test/
```

```bash
# MinIO 공식 CLI (mc)
mc alias set local http://localhost:9000 admin <MINIO_ROOT_PASSWORD>
mc ls local
mc admin user add local appkey1 <strong-secret>
```

---

## 홈서버 배포

### 최초 1회 (이미 완료됐다면 스킵)

```bash
ssh -i ~/.ssh/ghmate_server -p 222 ghmate@ghmate.iptime.org
sudo mkdir -p /srv/projects/objectstore && sudo chown ghmate:ghmate /srv/projects/objectstore
git clone <repo URL> /srv/projects/objectstore
cd /srv/projects/objectstore

cat > .env.dev <<'EOF'
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=<강력한_패스워드>
MINIO_SERVER_URL=https://objectstore.ghmate.com
MINIO_BROWSER_REDIRECT_URL=https://objectstore-console.ghmate.com
EOF
chmod 600 .env.dev

cp deploy/objectstore.conf /srv/nginx-proxy/conf.d/objectstore.conf
docker exec nginx_proxy nginx -t && docker restart nginx_proxy

./scripts/up.sh dev
```

그리고 Cloudflare DNS:

| Type | Name | Target | Proxy |
|---|---|---|---|
| CNAME | `objectstore` | `ghmate.iptime.org` | ON |
| CNAME | `objectstore-console` | `ghmate.iptime.org` | ON |

### 반복 배포

로컬에서:
```bash
./scripts/deploy.sh           # 표준 (변경 없으면 컨테이너 재기동 생략)
./scripts/deploy.sh --restart # 강제 재기동
```

`scripts/deploy.sh`가 5단계 자동 처리: 사전체크 → push → 서버 pull/up → nginx 동기화 → 헬스체크 → 외부 도메인 검증.

---

## 다른 프로젝트에서 사용하기

heyvoca / openday / orderandgo 등 같은 사용자의 다른 프로젝트가 이 objectstore를
S3처럼 사용하는 절차. 사용자뿐 아니라 **각 프로젝트의 Claude Code AI도** 동일 컨벤션을
따른다 (글로벌 skill `~/.claude/skills/objectstore/SKILL.md`로 자동 인지됨).

### 1) 사용자가 한 번만 (Console 작업)

브라우저로 https://objectstore-console.ghmate.com 로그인 후:

1. **버킷 생성** — 명명 컨벤션 `<project>-<env>` (예: `heyvoca-prod`, `heyvoca-dev`).
2. **Access Key 발급** — `Access Keys → Create access key`.
   - 가능하면 **해당 버킷에만** read/write 권한 주는 policy를 첨부해서 사고 격리.
3. 발급된 `accessKeyId` / `secretAccessKey`를 프로젝트의 `.env` 또는 secret 매니저에 저장.

### 2) 환경변수 컨벤션 (각 프로젝트의 `.env`)

```env
OBJECTSTORE_ENDPOINT=https://objectstore.ghmate.com
OBJECTSTORE_ACCESS_KEY=<bucket-scoped-key>
OBJECTSTORE_SECRET_KEY=<bucket-scoped-secret>
OBJECTSTORE_BUCKET=<project>-<env>
```

### 3) 코드 예시

#### Node.js (`@aws-sdk/client-s3` v3)

```js
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

const s3 = new S3Client({
  endpoint: process.env.OBJECTSTORE_ENDPOINT,
  region: 'us-east-1',                   // 아무 값. 비어있으면 SDK가 reject.
  credentials: {
    accessKeyId: process.env.OBJECTSTORE_ACCESS_KEY,
    secretAccessKey: process.env.OBJECTSTORE_SECRET_KEY,
  },
  forcePathStyle: true,                  // 필수
});

await s3.send(new PutObjectCommand({
  Bucket: process.env.OBJECTSTORE_BUCKET,
  Key: 'avatars/u123.png',
  Body: buffer,
  ContentType: 'image/png',
}));
```

#### Python (`boto3`)

```py
import os, boto3
from botocore.config import Config

s3 = boto3.client(
    's3',
    endpoint_url=os.environ['OBJECTSTORE_ENDPOINT'],
    aws_access_key_id=os.environ['OBJECTSTORE_ACCESS_KEY'],
    aws_secret_access_key=os.environ['OBJECTSTORE_SECRET_KEY'],
    region_name='us-east-1',
    config=Config(s3={'addressing_style': 'path'}),
)

s3.put_object(Bucket=os.environ['OBJECTSTORE_BUCKET'], Key='exports/x.csv', Body=data)
```

### 4) 트러블슈팅

| 증상 | 원인 |
|---|---|
| `400 BadRequest` 모든 요청 | `forcePathStyle: true` / `addressing_style: 'path'` 빠짐 |
| `403 SignatureDoesNotMatch` | secret key 오타 또는 region 빈 문자열 |
| `403 InvalidAccessKeyId` | Console에서 비활성화됐거나 만료 |
| `NoSuchBucket` | 버킷 미생성 또는 이름 오타 |
| 100MB 이상 업로드 실패 | SDK의 멀티파트 업로드(`Upload`/`upload_file`) 사용 |

서비스 자체가 죽은 것 같으면: `bash scripts/status.sh` 또는 `curl https://objectstore.ghmate.com/minio/health/live` (200이어야 정상).

---

## 운영 메모

- **Root key는 Console 관리용**. 애플리케이션 SDK 호출은 Console에서 `Identity → Service Accounts` 또는 `Users → Access Keys`로 별도 키를 발급해 사용.
- **Path-style URL 권장**: SDK에 `forcePathStyle: true` (boto3는 자동, aws-sdk-js는 명시 필요).
- **대용량 업로드**: SDK의 멀티파트 업로드 사용. 단일 PUT은 Cloudflare 무료 플랜의 100MB 제한에 걸릴 수 있음.
- **데이터 위치**: named volume `objectstore_minio_data` → `/var/lib/docker/volumes/objectstore_minio_data/_data` (서버).

---

## 외부 도메인

- 진입점: `https://objectstore.ghmate.com` (API), `https://objectstore-console.ghmate.com` (Console)
- 흐름: Cloudflare(Proxy) → iptime DDNS(`ghmate.iptime.org`) → 홈서버 nginx_proxy → MinIO 컨테이너
- 같은 홈서버의 다른 서비스(`serverstate`, `heyvoca-back`, `dev-openday` 등)와 동일 패턴
