#!/usr/bin/env bash
# cmux 개발 환경 세팅:
#   현재 워크스페이스를 "ObjectStore"로 만들고, Claude 패널 아래에
#   minio 로그 follow 패널을 한 개 배치한다.
#
# 멱등(idempotent):
#   다시 실행하면 기존 follow를 Ctrl+C로 끊고 같은 패널에서 재시작한다.
#   "재시작" / "다시 띄워" / "로그 다시" 같은 요청도 이 스크립트로 처리.
#
# 깨끗한 재배치가 필요하면:
#   bash scripts/cmux-dev.sh --rebuild
#
# 주의:
#   - macOS의 bash 3.2 호환 (associative array 미사용)
#   - cmux list-pane-surfaces 는 --pane 없이는 "포커스된 패널"의 surface만 반환한다.
#     따라서 워크스페이스 전체에서 서비스 패널을 찾으려면 list-panes 로 모든 pane을
#     얻은 뒤, 각 pane의 surface를 따로 조회해야 한다.

set -euo pipefail

REBUILD=0
if [[ "${1:-}" == "--rebuild" ]]; then
  REBUILD=1
fi

if ! command -v cmux >/dev/null 2>&1; then
  echo "❌ cmux CLI를 찾을 수 없습니다." >&2
  exit 1
fi

PANE_TITLE="minio"
LOG_CMD="bash scripts/logs.sh -f"

WS=$(cmux current-workspace 2>/dev/null || true)
if [[ -z "${WS}" ]]; then
  echo "❌ cmux 워크스페이스를 감지하지 못했습니다. cmux 안에서 실행해주세요." >&2
  exit 1
fi

cmux rename-workspace ObjectStore >/dev/null

# 패널의 selected surface ref + title 한 줄로 출력 ("surface:N|TITLE")
pane_surface_info() {
  local pane="$1"
  cmux list-pane-surfaces --pane "${pane}" 2>/dev/null | awk '
    /\[selected\]/ {
      line = $0
      if (match(line, /surface:[0-9]+/)) {
        sref = substr(line, RSTART, RLENGTH)
        sub(/^[[:space:]]*[*]?[[:space:]]*surface:[0-9]+[[:space:]]+/, "", line)
        sub(/[[:space:]]*\[selected\][[:space:]]*$/, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        print sref "|" line
        exit
      }
    }
  '
}

# title에 해당하는 surface ref를 워크스페이스 전체에서 찾는다 (없으면 빈 문자열)
find_surface_by_title() {
  local target="$1"
  local panes_raw
  panes_raw=$(cmux list-panes 2>/dev/null)
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    pane=$(printf '%s' "${line}" | grep -oE 'pane:[0-9]+' | head -1)
    [[ -z "${pane}" ]] && continue
    info=$(pane_surface_info "${pane}")
    [[ -z "${info}" ]] && continue
    surf="${info%%|*}"
    title="${info#*|}"
    if [[ "${title}" == "${target}" ]]; then
      printf '%s' "${surf}"
      return 0
    fi
  done <<EOF
${panes_raw}
EOF
}

# 비-focus pane들의 selected surface 모두 닫기 (Claude 패널 보존)
close_all_service_panes() {
  local panes_raw
  panes_raw=$(cmux list-panes 2>/dev/null)
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    if printf '%s' "${line}" | grep -q '\[focused\]'; then
      continue
    fi
    pane=$(printf '%s' "${line}" | grep -oE 'pane:[0-9]+' | head -1)
    [[ -z "${pane}" ]] && continue
    info=$(pane_surface_info "${pane}")
    [[ -z "${info}" ]] && continue
    surf="${info%%|*}"
    title="${info#*|}"
    echo "✕ 기존 패널 닫음: ${title} (${surf})"
    cmux close-surface --surface "${surf}" >/dev/null 2>&1 || true
  done <<EOF
${panes_raw}
EOF
}

restart_pane() {
  local surf="$1"
  echo "↻ 재시작: ${PANE_TITLE} (${surf})"
  cmux send-key --surface "${surf}" ctrl-c >/dev/null 2>&1 || true
  sleep 0.4
  cmux send --surface "${surf}" "clear && ${LOG_CMD}" >/dev/null
  cmux send-key --surface "${surf}" enter >/dev/null
}

create_pane_from_scratch() {
  close_all_service_panes
  sleep 0.6

  out=$(cmux new-split down 2>&1)
  surf=$(printf '%s' "${out}" | grep -oE 'surface:[0-9]+' | head -1)
  if [[ -z "${surf}" ]]; then
    echo "❌ ${PANE_TITLE} 패널 생성 실패: ${out}" >&2
    exit 1
  fi
  cmux rename-tab --surface "${surf}" "${PANE_TITLE}" >/dev/null
  cmux send --surface "${surf}" "${LOG_CMD}" >/dev/null
  cmux send-key --surface "${surf}" enter >/dev/null
  echo "+ 생성: ${PANE_TITLE} (${surf})"
}

existing_surf=$(find_surface_by_title "${PANE_TITLE}")

if [[ ${REBUILD} -eq 1 ]]; then
  echo "📐 --rebuild: 로그 패널 재생성"
  create_pane_from_scratch
elif [[ -n "${existing_surf}" ]]; then
  echo "🔁 ${PANE_TITLE} 로그 패널 존재 — follow 재시작"
  restart_pane "${existing_surf}"
else
  echo "📐 로그 패널 없음 — 새로 생성"
  create_pane_from_scratch
fi

echo "✅ ObjectStore 개발 환경 준비 완료"
