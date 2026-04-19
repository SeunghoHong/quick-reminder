# Quick Reminder — Hammerspoon Module Design

**Date:** 2026-04-20
**Status:** Approved (brainstorming complete)

## 1. 목적

맥에서 전역 단축키로 빠르게 macOS Reminders.app에 할 일을 추가하는 Hammerspoon 모듈. Claude Desktop의 "Alt 더블탭 → 입력창" UX에서 영감을 받았으며, 손을 마우스로 옮기지 않고 어디서든 몇 초 안에 할 일을 기록하는 것이 목표.

## 2. 범위

**포함:**
- 전역 트리거 (Ctrl 더블탭) 감지
- 중앙 팝업 입력창
- 리스트 선택 (기본 `Work`, Tab으로 순환)
- `@` 마커 이후 간단 날짜/시간 파싱 (한/영)
- Reminders.app에 저장
- 성공/실패 토스트 피드백

**제외 (비목표):**
- 리마인더 조회/편집/삭제 — 추가만
- 풀 자연어 파싱 — `@` 뒤 한정된 어휘만
- 다중 리마인더 일괄 입력
- 반복 리마인더 (`매주 월요일` 등)
- GUI 환경설정 창 — 코드 상단 상수로만 설정
- iCloud 동기화 처리 — Reminders.app이 알아서

## 3. 아키텍처

### 파일 구조
```
~/.hammerspoon/quick-reminder/
├── init.lua          # 모듈 엔트리, 트리거 바인딩
├── trigger.lua       # Ctrl 더블탭 감지 (hs.eventtap)
├── popup.lua         # 입력 UI (hs.webview + HTML/JS)
├── parser.lua        # @ 날짜/시간 파싱 (순수 함수)
└── reminders.lua     # AppleScript 래퍼 (list lists, save)
```

개발 저장소는 `/Users/raymond/Developer/quick-reminder/`, 배포 시 `~/.hammerspoon/quick-reminder/`로 심볼릭 링크.

### 데이터 흐름
```
[Ctrl×2]
   → trigger.lua detects double-tap
   → popup.lua opens webview (center of active screen)
   → reminders.listLists() → populate Tab cycle
   → user types + Tab → Enter
   → parser.parse(input) → { name, date, allday }
   → reminders.save(list, name, date, allday) via osascript
   → hs.alert toast
   → popup closes
```

## 4. 트리거: Ctrl 더블탭

**메커니즘:** `hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, ...)`

**상태 머신:**
1. `idle` — 대기
2. Ctrl down → `firstDown`, 타이머 시작 (300ms)
3. Ctrl up → `firstUp`
4. 300ms 이내 Ctrl down → `secondDown` → **트리거 발동**, 상태 `idle`로
5. 300ms 타임아웃 → 상태 `idle`로 리셋 (원본 이벤트 방해 없음)
6. 어느 단계든 다른 modifier/key 이벤트 들어오면 리셋

**설정:** `doubleTapWindowMs = 300`

**주의:**
- 팝업이 이미 열려있으면 발동하지 않음
- 이벤트 `consume`하지 않음 — Ctrl 단독 조합(예: `Ctrl+C`)을 방해하지 않기 위해

## 5. 팝업 UI

**구현:** `hs.webview` + 최소 HTML/JS/CSS

**위치/크기:**
- 활성 스크린 중앙 (멀티 모니터면 마우스가 있는 화면)
- 가로 560px, 세로 약 90px

**레이아웃:**
```
┌────────────────────────────────────────┐
│ 📋 Work                                │   (현재 리스트 라벨)
│ ▌                                      │   (입력 필드)
└────────────────────────────────────────┘
```

**스타일:** 다크 블러 배경, 라운드 코너, 시스템 폰트

**키 바인딩 (webview 내부 JS):**
| 키 | 동작 |
|---|---|
| `Enter` | 저장 → 토스트 → 닫기 |
| `ESC` | 취소하고 닫기 |
| `Tab` | 다음 리스트로 순환 |
| `Shift+Tab` | 이전 리스트로 순환 |
| 포커스 아웃 | 취소로 간주, 닫기 |

**webview ↔ Lua 통신:** `hs.webview`의 `navigationCallback` 또는 URL 스킴 기반 메시지로 JS 이벤트를 Lua로 전달.

## 6. 리스트 관리

**로드:**
- 팝업이 열릴 때 `reminders.listLists()` 호출 → `{ "Work", "Personal", ... }`
- 캐싱하지 않음. 팝업 1회 오픈 시 1회 조회.

**초기 선택:**
- `config.defaultList`("Work") 인덱스 탐색
- 찾으면 그 인덱스, 없으면 0번째 + 토스트에 경고

**순환:**
- Tab: `index = (index + 1) % count`
- Shift+Tab: `index = (index - 1 + count) % count`
- 순환 시 webview JS로 라벨 텍스트만 교체

**리스트 0개:** 팝업 열지 않고 `hs.alert("리마인더 리스트가 없습니다")`.

## 7. 입력 파싱

**문법:** `<이름> [@<날짜시간>]`

**분할:** 입력을 `@` 첫 등장에서 2분할. `@`가 없으면 전체가 `name`, 날짜 없음.

**지원 어휘:**

| 토큰 (한) | 토큰 (영) | 결과 |
|---|---|---|
| `오늘` | `today` | 오늘 |
| `내일` | `tomorrow` | 내일 |
| `모레` | — | 2일 뒤 |
| `월 화 수 목 금 토 일` | `mon tue wed thu fri sat sun` | 다가오는 가장 가까운 해당 요일 (오늘 기준) |
| `다음주 <요일>` | `next <dow>` | 다음주 해당 요일 |
| `3시`, `오후 3시`, `오전 9시` | `3pm`, `3 PM`, `15:00`, `3:30 pm` | 해당 시각 |

**조합 규칙:**
- 날짜 + 시간: 해당 날짜의 해당 시각
- 날짜만: `allday` 플래그 활성 → Reminders의 `allday due date` 속성으로 저장
- 시간만: 오늘 해당 시각. 이미 지난 시각이면 내일로.
- 둘 다 없음 / 파싱 실패: **입력 전체를 `name`으로 사용, 날짜 없이 저장**. 에러 안 띄움.

**파싱 실패 예시:**
- `"보고서 @랜덤텍스트"` → name: `"보고서 @랜덤텍스트"`, date: nil

**파서 시그니처:**
```lua
-- parser.parse(input: string): { name: string, date: os.time? , allday: bool }
```

## 8. 저장

**메커니즘:** `hs.osascript.applescript(script)` 사용.

**AppleScript (템플릿):**
```applescript
tell application "Reminders"
    tell list "<LIST_NAME>"
        make new reminder with properties {name:"<NAME>" [, due date:date "..."] [, allday due date:date "..."]}
    end tell
end tell
```

**이스케이프:**
- `"` → `\"`
- `\` → `\\`
- 리스트 이름과 할 일 이름 모두 이스케이프

**결과 처리:**
- 성공 (return true): 성공 토스트
- 실패 (return false / error string): 실패 토스트에 에러 메시지 일부 포함

## 9. 피드백

**성공:**
- `hs.alert.show("✓ " .. listName .. "에 추가됨", 1.2)`
- 화면 중앙 하단 (hs.alert 기본 위치)

**실패:**
- `hs.alert.show("✗ 저장 실패: " .. errMsg, { strokeColor = {red=1} }, 2.0)`

**경고 (기본 리스트 없음):**
- 성공 토스트에 추가: `"✓ <실제이름>에 추가됨 (Work 없음)"`

## 10. 권한

**Accessibility** (`hs.eventtap` 필수):
- Hammerspoon 자체에 부여되면 OK
- 없으면 초기 로드에서 `hs.alert`로 안내

**Automation → Reminders** (`osascript` 필수):
- 최초 저장 시 macOS가 1회 다이얼로그로 묻고 허용 후 영구
- 거부 시 실패 토스트로 안내

## 11. 엣지 케이스

| 상황 | 동작 |
|---|---|
| 리스트 0개 | 팝업 열지 않고 경고 |
| `Work` 리스트 없음 | 배열 0번째 + 토스트 경고 |
| 입력 비어있음 + Enter | 아무것도 안 하고 닫기 |
| 팝업 바깥 클릭 | 취소로 간주 |
| Reminders.app 닫혀있음 | `osascript`가 자동 기동 |
| 팝업 열린 상태에서 Ctrl×2 재입력 | 무시 |
| 파싱 실패 | 원문을 name으로, 날짜 없이 저장 |
| `@` 두 개 이상 | 첫 `@`에서 분할 (뒤의 `@`는 dateExpr에 포함되어 파싱 실패 → 원문 유지) |

## 12. 설정

모듈 상단 상수로 노출:
```lua
local config = {
    defaultList = "Work",
    doubleTapWindowMs = 300,
    popupWidth = 560,
    popupHeight = 90,
    dateMarker = "@",
    toastDuration = 1.2,
}
```

## 13. 설치

1. `brew install --cask hammerspoon`
2. Hammerspoon을 로그인 항목에 추가
3. 개발 저장소를 `~/.hammerspoon/quick-reminder/`로 심볼릭 링크
   ```
   ln -s /Users/raymond/Developer/quick-reminder ~/.hammerspoon/quick-reminder
   ```
4. `~/.hammerspoon/init.lua`에 추가:
   ```lua
   require("quick-reminder")
   ```
5. Hammerspoon Reload
6. 최초 Ctrl 더블탭 → Accessibility 권한 허용
7. 최초 저장 → Automation → Reminders 권한 허용

## 14. 테스트 전략

**파서 단위 테스트** (`parser.lua`는 순수 함수):
- 테이블 기반 케이스 (~20개)
- 예: `"보고서 @내일 3pm"` → `{name="보고서", date=<tomorrow 15:00>, allday=false}`
- 한/영 각 어휘 커버
- 파싱 실패 케이스 (원문 유지) 포함
- Hammerspoon 콘솔에서 실행하거나 외부 `lua` 인터프리터 (단, `os.time` 의존 있음)

**수동 E2E:**
- Reminders.app에서 실제 저장 확인
- Tab 순환 확인
- 권한 플로우 확인

**트리거:**
- 자동화 불가 (타이머/이벤트 기반) — 수동 확인

## 15. 열린 질문 / 향후 확장

- **반복 리마인더**: `@매주 월요일` 등 — v2
- **설정 창**: 텍스트 편집 대신 GUI — v2
- **태그 문법**: `"우유 #장보기"` → 장보기 리스트 — Tab 기반 전환과 중복이라 보류
- **노트 필드**: 할 일 본문 외에 메모 — 현재 scope 밖
