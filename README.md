# Quick Reminder

Hammerspoon 모듈: Shift 더블탭 → 팝업 입력 → macOS Reminders에 추가.

## 요구사항

- macOS
- [Hammerspoon](https://www.hammerspoon.org) (`brew install --cask hammerspoon`)
- Lua 5.4+ (테스트 실행용, `brew install lua`)

## 설치

```bash
./install.sh
```

1. Hammerspoon 앱을 열고 **Accessibility** 권한 부여
2. Hammerspoon 메뉴 → **Reload Config**
3. 첫 저장 시 **Automation → Reminders** 권한 요청 → 허용

## 사용법

- **Shift 더블탭** (빠르게 두 번): 팝업 열기
- 할 일 이름 입력 → **Enter**
- **Tab / Shift+Tab**: 리스트 순환 (기본 `Work`)
- **ESC**: 취소

### 날짜/시간 문법

입력 끝에 `@` 뒤에 날짜/시간을 붙이세요.

| 예시 | 결과 |
|---|---|
| `보고서 @내일 3pm` | 내일 15:00 |
| `회의 @월 10:30` | 다가오는 월요일 10:30 |
| `약 @오늘` | 오늘 하루종일 |
| `브런치 @다음주 일 11am` | 다음주 일요일 11:00 |
| `회의 @오후 3시` | 오늘 15:00 (지났으면 내일) |

지원 어휘:
- **상대일**: `오늘`, `내일`, `모레`, `today`, `tomorrow`
- **요일**: `월`~`일`, `mon`~`sun` (다가오는 가장 가까운)
- **다음주**: `다음주 월`, `next mon`
- **시간**: `3pm`, `15:00`, `3:30pm`, `3시`, `오후 3시`, `오전 9시`

파싱에 실패하면 원문 그대로 이름에 저장됩니다 (오류 없이).

## 개발

```bash
# 파서 단위 테스트
lua tests/parser_spec.lua

# 수정 후 Hammerspoon Reload Config
```

## 설정

`init.lua` 상단의 `CONFIG` 테이블에서:

- `defaultList` — 기본 리스트 (기본값: `"Work"`)
- `doubleTapWindowMs` — 더블탭 인식 시간 (기본값: 200)
- `toastDuration` — 토스트 표시 시간 (기본값: 1.2)
