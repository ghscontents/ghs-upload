#!/bin/bash
# GHS 업로드 환경설정: 설치 + 진단
# 사용법 (터미널에 붙여넣기):
#   curl -fsSL https://ghscontents.github.io/ghs-upload/setup.sh | bash
#
# 하는 일
#   1. macOS 확인
#   2. GHS 업로드(우클릭 메뉴) 설치 / 업데이트
#   3. macOS 보안 차단 표시 제거
#   4. 회사 서버(1_GHS) 연결 확인 (안 돼 있으면 연결 창을 띄우고 기다림)
#   5. 업로드 폴더 쓰기 권한 확인
#   6. 테스트 알림 보내기
#   7. 결과 요약
#
# 스크립트 전체를 함수로 감싸서, 다운로드가 중간에 끊기면 아무것도 실행되지 않게 했어요.

main() {
  set -u
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
  local BASE="${GHS_BASE_URL:-https://ghscontents.github.io/ghs-upload}"
  local VOLUME="/Volumes/1_GHS"
  local APP="$HOME/Library/Application Support/GHS업로드"
  local SVC="$HOME/Library/Services"
  local WF="GHS 업로드.workflow"
  local RESULTS=()
  local FAILS=0

  say()  { printf "\n\033[1m%s\033[0m\n" "$1"; }
  ok()   { printf "   ✅ %s\n" "$1"; RESULTS+=("✅ $1"); }
  bad()  { printf "   ❌ %s\n      → %s\n" "$1" "$2"; RESULTS+=("❌ $1 → $2"); FAILS=$((FAILS + 1)); }
  info() { printf "   %s\n" "$1"; }

  printf "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
  printf "  GHS 업로드 환경설정\n"
  printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

  # 1. macOS
  say "1/6  macOS 확인"
  if [ "$(uname -s)" != "Darwin" ]; then
    bad "Mac이 아니에요" "이 도구는 Mac에서만 동작해요"
    return 1
  fi
  ok "macOS $(sw_vers -productVersion)"

  # 2. 설치
  say "2/6  GHS 업로드 설치"
  local TMP; TMP="$(mktemp -d "${TMPDIR:-/tmp}/ghs_setup.XXXXXX")"
  if curl -fsSL "$BASE/GHS-upload-installer.zip" -o "$TMP/installer.zip" \
     && ditto -x -k "$TMP/installer.zip" "$TMP/x"; then
    local SRC; SRC="$(find "$TMP/x" -maxdepth 3 -type d -name files | head -1)"
    if [ -n "$SRC" ] && [ -f "$SRC/ghs_upload.sh" ] && [ -d "$SRC/$WF" ]; then
      mkdir -p "$APP" "$SVC"
      cp "$SRC/ghs_upload.sh" "$APP/ghs_upload.sh" && chmod +x "$APP/ghs_upload.sh"
      rm -rf "$SVC/$WF"
      ditto "$SRC/$WF" "$SVC/$WF"
      /System/Library/CoreServices/pbs -flush >/dev/null 2>&1
      ok "우클릭 메뉴 'GHS 업로드' 설치 완료"
    else
      bad "설치 파일 내용이 이상해요" "잠시 후 다시 실행하거나 담당자에게 알려 주세요"
    fi
  else
    bad "설치 파일을 받지 못했어요" "인터넷 연결을 확인하고 다시 실행해 주세요"
  fi
  rm -rf "$TMP"

  # 3. 보안 차단 표시 제거
  say "3/6  macOS 보안 차단 해제"
  xattr -dr com.apple.quarantine "$APP" "$SVC/$WF" 2>/dev/null
  ok "보안 차단 표시 제거"

  # 4. 서버 연결
  say "4/6  회사 서버(1_GHS) 연결 확인"
  if ! mount | grep -q " on $VOLUME "; then
    info "서버가 연결돼 있지 않아요. 연결 창을 띄울게요."
    info "회사 계정으로 로그인하고 '1_GHS'를 선택해 주세요. (최대 2분 기다려요)"
    open "smb://GHS" >/dev/null 2>&1
    local i=0
    while [ $i -lt 60 ] && ! mount | grep -q " on $VOLUME "; do sleep 2; i=$((i + 1)); done
  fi
  local DEST=""
  if mount | grep -q " on $VOLUME "; then
    ok "서버 연결됨"
    DEST="$(find "$VOLUME" -maxdepth 3 -type d -path "$VOLUME/13_*/01_GHS_*/01_*" 2>/dev/null | head -1)"
  else
    bad "서버에 연결하지 못했어요" "회사 밖이면 VPN을 켜고, Finder에서 ⌘K → smb://GHS 로 연결한 뒤 다시 실행해 주세요"
  fi

  # 5. 쓰기 권한
  say "5/6  업로드 폴더 쓰기 권한 확인"
  if [ -n "$DEST" ]; then
    local PROBE="$DEST/.ghs_setup_check_$$"
    if touch "$PROBE" 2>/dev/null && rm -f "$PROBE"; then
      ok "업로드 폴더에 쓸 수 있어요"
    else
      rm -f "$PROBE" 2>/dev/null
      bad "업로드 폴더에 쓰기 권한이 없어요" "서버 관리자에게 '01_릴_사운드_라이브러리' 쓰기 권한을 요청해 주세요"
    fi
  elif mount | grep -q " on $VOLUME "; then
    bad "업로드 폴더를 찾지 못했어요" "서버 폴더 이름이 바뀌었는지 담당자에게 확인해 주세요"
  else
    info "서버가 연결되지 않아서 건너뛰었어요"
  fi

  # 6. 알림
  say "6/6  테스트 알림"
  osascript -e 'display notification "알림이 보이면 정상이에요" with title "GHS 업로드 환경설정"' >/dev/null 2>&1
  ok "테스트 알림을 보냈어요 (화면 오른쪽 위에 안 보이면 시스템 설정 → 알림에서 허용해 주세요)"

  # 요약
  printf "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
  if [ "$FAILS" -eq 0 ]; then
    printf "  🎉 모두 정상이에요!\n"
    printf "  Finder에서 .fcpbundle 우클릭 → 빠른 동작 → GHS 업로드\n"
  else
    printf "  ⚠️  확인이 필요한 항목이 %d개 있어요\n" "$FAILS"
    local r
    for r in "${RESULTS[@]}"; do case "$r" in "❌"*) printf "  %s\n" "$r";; esac; done
    printf "  해결한 뒤 같은 명령어를 다시 실행하면 돼요.\n"
  fi
  printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
}

main "$@"
