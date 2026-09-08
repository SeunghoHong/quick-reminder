# Quick Reminder

Hammerspoon 모듈: Shift+Space → 팝업 입력 → macOS Reminders에 추가.

## 요구사항

- macOS
- [Hammerspoon](https://www.hammerspoon.org) (`brew install --cask hammerspoon`)
- Lua 5.4+ (테스트 실행용, `brew install lua`)

## 설치

원격 설치 (클론 불필요, 재실행하면 업데이트):

```bash
curl -fsSL https://raw.githubusercontent.com/SeunghoHong/quick-reminder/main/install.sh | bash
```

특정 버전 고정:

```bash
curl -fsSL https://raw.githubusercontent.com/SeunghoHong/quick-reminder/main/install.sh | bash -s -- v0.1.0
```

로컬 체크아웃에서 (심볼릭 링크, 개발용):

```bash
./install.sh
```

1. Hammerspoon 앱을 열고 **Accessibility** 권한 부여
2. Hammerspoon 메뉴 → **Reload Config**
3. 첫 저장 시 **Automation → Reminders** 권한 요청 → 허용

### 삭제

```bash
curl -fsSL https://raw.githubusercontent.com/SeunghoHong/quick-reminder/main/uninstall.sh | bash
```

설치 방식에 따라 심볼릭 링크 또는 클론을 지우고, `~/.hammerspoon/init.lua`의 `require` 줄을 제거합니다.
심볼릭 링크였다면 원본 체크아웃은 그대로 둡니다.

## 릴리스

`v` 로 시작하는 태그를 푸시하면 GitHub Actions가 파서 테스트를 돌린 뒤 릴리스를 만듭니다.

```bash
git tag v0.1.0
git push origin v0.1.0
```

## 사용법

- **Shift+Space**: 팝업 열기
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
- `toastDuration` — 토스트 표시 시간 (기본값: 1.2)
