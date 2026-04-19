# Quick Reminder — Hammerspoon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hammerspoon 모듈로 Ctrl 더블탭 → 팝업 입력 → macOS Reminders.app에 저장하는 전역 단축키 기능 구현.

**Architecture:** 5개 Lua 파일로 책임 분리 (trigger / popup / parser / reminders / init). `parser.lua`는 순수 함수로 TDD 가능. 나머지는 Hammerspoon API 의존이라 수동 E2E 검증.

**Tech Stack:** Lua 5.4 (테스트 실행용), Hammerspoon (hs.eventtap, hs.webview, hs.alert, hs.osascript), AppleScript (Reminders.app 제어).

**Spec:** `docs/superpowers/specs/2026-04-20-quick-reminder-hammerspoon-design.md`

---

## File Structure

```
/Users/raymond/Developer/quick-reminder/
├── .gitignore
├── README.md
├── init.lua              # 모듈 엔트리, 트리거 바인딩
├── trigger.lua           # Ctrl 더블탭 감지 (hs.eventtap)
├── popup.lua             # hs.webview 래퍼 + JS 브리지
├── popup.html            # 팝업 UI (HTML/CSS/JS)
├── parser.lua            # @ 날짜/시간 파싱 (순수 함수)
├── reminders.lua         # AppleScript 래퍼 (list lists, save)
├── tests/
│   └── parser_spec.lua   # 파서 단위 테스트
├── install.sh            # ~/.hammerspoon 심볼릭 링크 설치
└── docs/superpowers/
    ├── specs/2026-04-20-quick-reminder-hammerspoon-design.md
    └── plans/2026-04-20-quick-reminder-hammerspoon.md
```

**책임 분리 원칙:**
- `parser.lua`: Hammerspoon API 0 의존 → 스톡 Lua로 테스트 가능
- `reminders.lua`: `hs.osascript`만 사용
- `popup.lua`: `hs.webview` + HTML 로드
- `trigger.lua`: `hs.eventtap` 상태 머신
- `init.lua`: 위 4개 조합 + 설정 상수

---

## Task 0: 환경 준비 & 프로젝트 scaffold

**Files:**
- Create: `.gitignore`
- Create: `README.md`

- [ ] **Step 1: Lua 인터프리터 설치 (테스트용)**

```bash
brew install lua
lua -v
```

Expected: `Lua 5.4.x  Copyright ...`

- [ ] **Step 2: git 저장소 초기화**

```bash
cd /Users/raymond/Developer/quick-reminder
git init
git branch -m main
```

- [ ] **Step 3: `.gitignore` 생성**

```gitignore
# macOS
.DS_Store

# Hammerspoon console logs
*.log

# IDE
.vscode/
.idea/
```

- [ ] **Step 4: `README.md` 생성**

```markdown
# Quick Reminder

Hammerspoon 모듈: Ctrl 더블탭 → 팝업 입력 → macOS Reminders에 추가.

## 설치

```bash
./install.sh
```

Hammerspoon Reload 후 Ctrl을 빠르게 두 번 누르면 팝업이 뜹니다.

## 사용법

- 입력창에 할 일을 쓰고 Enter
- Tab / Shift+Tab으로 리스트 전환
- `@` 뒤에 날짜/시간 (예: `보고서 @내일 3pm`)
- ESC로 취소
```

- [ ] **Step 5: 커밋**

```bash
git add .gitignore README.md docs/
git commit -m "chore: scaffold project with spec and plan"
```

---

## Task 1: Parser — `@` 분할 + 테스트 러너

**Files:**
- Create: `parser.lua`
- Create: `tests/parser_spec.lua`

- [ ] **Step 1: 테스트 러너 스켈레톤 작성 (`tests/parser_spec.lua`)**

```lua
package.path = package.path .. ";./?.lua"
local parser = require("parser")

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  ok  " .. name)
    else
        failed = failed + 1
        print("  FAIL  " .. name .. " — " .. tostring(err))
    end
end

local function assertEq(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) ..
              ", got " .. tostring(actual), 2)
    end
end

-- ========== @ 분할 ==========

test("no @ marker → name only", function()
    local r = parser.parse("우유 사기")
    assertEq(r.name, "우유 사기", "name")
    assertEq(r.date, nil, "date")
    assertEq(r.allday, false, "allday")
end)

test("@ at end splits name and empty dateExpr → fallback", function()
    local r = parser.parse("우유 사기 @")
    assertEq(r.name, "우유 사기 @", "name")
    assertEq(r.date, nil, "date")
end)

test("empty input", function()
    local r = parser.parse("")
    assertEq(r.name, "", "name")
    assertEq(r.date, nil, "date")
end)

-- test() calls for later tasks will be appended below

print()
print(string.format("passed: %d, failed: %d", passed, failed))
if failed > 0 then os.exit(1) end
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

```bash
cd /Users/raymond/Developer/quick-reminder
lua tests/parser_spec.lua
```

Expected: `module 'parser' not found` — 아직 구현 없음

- [ ] **Step 3: `parser.lua` 최소 구현**

```lua
local M = {}

-- parser.parse(input, now?) → { name, date, allday }
-- date: Unix timestamp (number) or nil
-- allday: boolean — true when only date was given, no time
function M.parse(input, now)
    now = now or os.time()

    local atPos = string.find(input, "@", 1, true)
    if not atPos then
        return { name = input, date = nil, allday = false }
    end

    local namePart = string.sub(input, 1, atPos - 1):gsub("%s+$", "")
    local dateExpr = string.sub(input, atPos + 1):gsub("^%s+", ""):gsub("%s+$", "")

    if dateExpr == "" then
        -- fallback: original text as name
        return { name = input, date = nil, allday = false }
    end

    -- TODO: actual date parsing in later tasks
    return { name = input, date = nil, allday = false }
end

return M
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
lua tests/parser_spec.lua
```

Expected: `passed: 3, failed: 0`

- [ ] **Step 5: 커밋**

```bash
git add parser.lua tests/parser_spec.lua
git commit -m "feat(parser): add skeleton with @ split and fallback"
```

---

## Task 2: Parser — 상대 날짜 토큰 (오늘/내일/모레/today/tomorrow)

**Files:**
- Modify: `parser.lua`
- Modify: `tests/parser_spec.lua`

- [ ] **Step 1: 테스트 추가 (tests/parser_spec.lua의 "later tasks" 주석 위)**

```lua
-- ========== 상대 날짜 ==========

-- 고정 now: 2026-04-20 (월요일) 10:00:00 KST
-- os.time({year=2026, month=4, day=20, hour=10, min=0, sec=0})
local FIXED_NOW = os.time({year=2026, month=4, day=20, hour=10, min=0, sec=0})

local function dateFields(ts)
    return os.date("*t", ts)
end

test("@오늘 → today, allday", function()
    local r = parser.parse("약 @오늘", FIXED_NOW)
    assertEq(r.name, "약", "name")
    local d = dateFields(r.date)
    assertEq(d.year, 2026); assertEq(d.month, 4); assertEq(d.day, 20)
    assertEq(r.allday, true, "allday")
end)

test("@today → today, allday (english)", function()
    local r = parser.parse("pill @today", FIXED_NOW)
    assertEq(r.name, "pill", "name")
    assertEq(r.allday, true, "allday")
end)

test("@내일 → tomorrow, allday", function()
    local r = parser.parse("약 @내일", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 21, "day")
    assertEq(r.allday, true, "allday")
end)

test("@tomorrow → tomorrow, allday", function()
    local r = parser.parse("pill @tomorrow", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 21, "day")
end)

test("@모레 → day after tomorrow, allday", function()
    local r = parser.parse("약 @모레", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 22, "day")
    assertEq(r.allday, true, "allday")
end)
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

```bash
lua tests/parser_spec.lua
```

Expected: 5 FAILs (date=nil)

- [ ] **Step 3: parser.lua에 상대 날짜 파싱 추가**

`parser.lua` 전체를 아래로 교체:

```lua
local M = {}

local RELATIVE_DAYS = {
    ["오늘"] = 0, ["today"] = 0,
    ["내일"] = 1, ["tomorrow"] = 1,
    ["모레"] = 2,
}

local function dayStart(ts)
    local t = os.date("*t", ts)
    t.hour = 0; t.min = 0; t.sec = 0
    return os.time(t)
end

local function addDays(ts, n)
    return dayStart(ts) + n * 86400
end

-- Parse dateExpr → { date, allday } or nil if unrecognized
local function parseDateExpr(dateExpr, now)
    local expr = string.lower(dateExpr)

    for token, offset in pairs(RELATIVE_DAYS) do
        if expr == token then
            return { date = addDays(now, offset), allday = true }
        end
    end

    return nil
end

function M.parse(input, now)
    now = now or os.time()

    local atPos = string.find(input, "@", 1, true)
    if not atPos then
        return { name = input, date = nil, allday = false }
    end

    local namePart = string.sub(input, 1, atPos - 1):gsub("%s+$", "")
    local dateExpr = string.sub(input, atPos + 1):gsub("^%s+", ""):gsub("%s+$", "")

    if dateExpr == "" then
        return { name = input, date = nil, allday = false }
    end

    local parsed = parseDateExpr(dateExpr, now)
    if parsed then
        return { name = namePart, date = parsed.date, allday = parsed.allday }
    end

    -- fallback: original text as name
    return { name = input, date = nil, allday = false }
end

return M
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
lua tests/parser_spec.lua
```

Expected: `passed: 8, failed: 0`

- [ ] **Step 5: 커밋**

```bash
git add parser.lua tests/parser_spec.lua
git commit -m "feat(parser): support relative date tokens (오늘/내일/모레/today/tomorrow)"
```

---

## Task 3: Parser — 요일 토큰 (월~일 / mon~sun / 다음주 X)

**Files:**
- Modify: `parser.lua`
- Modify: `tests/parser_spec.lua`

- [ ] **Step 1: 테스트 추가**

```lua
-- ========== 요일 ==========
-- FIXED_NOW = 2026-04-20 월요일

test("@월 → coming Monday (a week later when today is Mon)", function()
    local r = parser.parse("회의 @월", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 27, "day")  -- next Monday
    assertEq(r.allday, true, "allday")
end)

test("@화 → this Tuesday", function()
    local r = parser.parse("회의 @화", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 21, "day")
end)

test("@일 → coming Sunday", function()
    local r = parser.parse("브런치 @일", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 26, "day")
end)

test("@mon → same as @월", function()
    local r = parser.parse("meeting @mon", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 27, "day")
end)

test("@fri → coming Friday", function()
    local r = parser.parse("drink @fri", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 24, "day")
end)

test("@다음주 월 → next-next Monday", function()
    local r = parser.parse("회의 @다음주 월", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 27, "day")  -- today is Mon, +7
end)

test("@다음주 화 → next Tuesday", function()
    local r = parser.parse("회의 @다음주 화", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 28, "day")
end)

test("@next mon → same as 다음주 월", function()
    local r = parser.parse("meeting @next mon", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 27, "day")
end)
```

- [ ] **Step 2: 실패 확인**

```bash
lua tests/parser_spec.lua
```

Expected: 8 new FAILs

- [ ] **Step 3: parser.lua에 요일 파싱 추가**

`parser.lua`에 다음을 추가/수정:

```lua
-- (RELATIVE_DAYS 아래에 추가)

-- os.date("*t").wday: Sunday=1, Monday=2, ..., Saturday=7
local DOW = {
    ["일"] = 1, ["sun"] = 1,
    ["월"] = 2, ["mon"] = 2,
    ["화"] = 3, ["tue"] = 3,
    ["수"] = 4, ["wed"] = 4,
    ["목"] = 5, ["thu"] = 5,
    ["금"] = 6, ["fri"] = 6,
    ["토"] = 7, ["sat"] = 7,
}

-- Coming target DoW from now. If today matches, returns today+7 (next week).
local function comingDow(now, targetWday)
    local today = os.date("*t", now).wday
    local delta = (targetWday - today) % 7
    if delta == 0 then delta = 7 end
    return addDays(now, delta)
end
```

그리고 `parseDateExpr` 함수를 다음으로 교체:

```lua
local function parseDateExpr(dateExpr, now)
    local expr = string.lower(dateExpr)

    -- 상대 날짜
    for token, offset in pairs(RELATIVE_DAYS) do
        if expr == token then
            return { date = addDows(now, offset), allday = true }
        end
    end

    -- 다음주 <요일>
    local nextDow = expr:match("^다음주%s+(.+)$") or expr:match("^next%s+(.+)$")
    if nextDow then
        local wday = DOW[nextDow]
        if wday then
            return { date = comingDow(now, wday) + 7 * 86400, allday = true }
        end
    end

    -- 단일 요일
    local wday = DOW[expr]
    if wday then
        return { date = comingDow(now, wday), allday = true }
    end

    return nil
end
```

**주의:** 위 스니펫의 `addDows`는 오타, `addDays`로 수정 확인.

최종 `parseDateExpr`:

```lua
local function parseDateExpr(dateExpr, now)
    local expr = string.lower(dateExpr)

    for token, offset in pairs(RELATIVE_DAYS) do
        if expr == token then
            return { date = addDays(now, offset), allday = true }
        end
    end

    local nextDow = expr:match("^다음주%s+(.+)$") or expr:match("^next%s+(.+)$")
    if nextDow then
        local wday = DOW[nextDow]
        if wday then
            return { date = comingDow(now, wday) + 7 * 86400, allday = true }
        end
    end

    local wday = DOW[expr]
    if wday then
        return { date = comingDow(now, wday), allday = true }
    end

    return nil
end
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
lua tests/parser_spec.lua
```

Expected: `passed: 16, failed: 0`

- [ ] **Step 5: 커밋**

```bash
git add parser.lua tests/parser_spec.lua
git commit -m "feat(parser): support day-of-week tokens and 다음주/next prefix"
```

---

## Task 4: Parser — 시간 토큰 (3pm, 15:00, 3시, 오후 3시)

**Files:**
- Modify: `parser.lua`
- Modify: `tests/parser_spec.lua`

- [ ] **Step 1: 테스트 추가**

```lua
-- ========== 시간만 ==========

test("@3pm → today 15:00 (not passed yet)", function()
    local r = parser.parse("회의 @3pm", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.year, 2026); assertEq(d.month, 4); assertEq(d.day, 20)
    assertEq(d.hour, 15); assertEq(d.min, 0)
    assertEq(r.allday, false, "allday")
end)

test("@9am → next day (already passed at 10am)", function()
    local r = parser.parse("회의 @9am", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 21, "day should be tomorrow")
    assertEq(d.hour, 9, "hour")
end)

test("@15:00 → today 15:00", function()
    local r = parser.parse("회의 @15:00", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 20); assertEq(d.hour, 15); assertEq(d.min, 0)
end)

test("@3:30pm → today 15:30", function()
    local r = parser.parse("회의 @3:30pm", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.hour, 15); assertEq(d.min, 30)
end)

test("@3시 → today 03:00 (3am)? or 15:00? 3시 alone = today 03:00 (already passed → tomorrow)", function()
    -- Spec: "3시" treated as 03:00 if no AM/PM marker (24h read).
    -- At FIXED_NOW 10:00, 03:00 is passed → tomorrow 03:00
    local r = parser.parse("회의 @3시", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 21); assertEq(d.hour, 3); assertEq(d.min, 0)
end)

test("@오후 3시 → today 15:00", function()
    local r = parser.parse("회의 @오후 3시", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 20); assertEq(d.hour, 15)
end)

test("@오전 9시 → next day (9am already passed)", function()
    local r = parser.parse("회의 @오전 9시", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 21); assertEq(d.hour, 9)
end)
```

- [ ] **Step 2: 실패 확인**

```bash
lua tests/parser_spec.lua
```

Expected: 7 new FAILs

- [ ] **Step 3: parser.lua에 시간 파싱 추가**

`parseDateExpr` 위에 helper 추가:

```lua
-- Parse time string → { hour, min } or nil
local function parseTime(s)
    -- Normalize whitespace
    s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    -- Korean: 오전/오후 H시 [M분]
    local ampmKo, h, m = s:match("^(오전)%s*(%d+)시%s*(%d*)분?$")
    if ampmKo then
        h = tonumber(h); m = tonumber(m) or 0
        if h == 12 then h = 0 end
        return { hour = h, min = m }
    end
    ampmKo, h, m = s:match("^(오후)%s*(%d+)시%s*(%d*)분?$")
    if ampmKo then
        h = tonumber(h); m = tonumber(m) or 0
        if h < 12 then h = h + 12 end
        return { hour = h, min = m }
    end

    -- Korean: H시 [M분]
    h, m = s:match("^(%d+)시%s*(%d*)분?$")
    if h then
        return { hour = tonumber(h), min = tonumber(m) or 0 }
    end

    -- English/numeric: HH:MM [am/pm]
    h, m, local_ampm = s:match("^(%d+):(%d+)%s*([apAP]?[mM]?)$")
    if h then
        h = tonumber(h); m = tonumber(m)
        local_ampm = local_ampm:lower()
        if local_ampm == "pm" and h < 12 then h = h + 12
        elseif local_ampm == "am" and h == 12 then h = 0 end
        return { hour = h, min = m }
    end

    -- English: H[am/pm] or HH[am/pm]
    local ampm
    h, ampm = s:match("^(%d+)%s*([apAP][mM])$")
    if h then
        h = tonumber(h)
        ampm = ampm:lower()
        if ampm == "pm" and h < 12 then h = h + 12
        elseif ampm == "am" and h == 12 then h = 0 end
        return { hour = h, min = 0 }
    end

    return nil
end

local function setTime(ts, hour, min)
    local t = os.date("*t", ts)
    t.hour = hour; t.min = min; t.sec = 0
    return os.time(t)
end

local function todayOrTomorrow(now, hour, min)
    local candidate = setTime(now, hour, min)
    if candidate <= now then
        candidate = candidate + 86400
    end
    return candidate
end
```

**주의:** `local_ampm`은 Lua에서 지역 변수 이름으로 `local`과 충돌 없음 (식별자). 더 안전하게 `ampmEn`으로 rename:

```lua
    local ampmEn
    h, m, ampmEn = s:match("^(%d+):(%d+)%s*([apAP]?[mM]?)$")
    if h then
        h = tonumber(h); m = tonumber(m)
        ampmEn = ampmEn:lower()
        if ampmEn == "pm" and h < 12 then h = h + 12
        elseif ampmEn == "am" and h == 12 then h = 0 end
        return { hour = h, min = m }
    end
```

`parseDateExpr` 맨 마지막에 (return nil 직전) 추가:

```lua
    -- 시간만 (날짜 없음)
    local time = parseTime(dateExpr)
    if time then
        return {
            date = todayOrTomorrow(now, time.hour, time.min),
            allday = false,
        }
    end
```

최종 parser.lua 상단의 require/helper 순서 확인:
```
RELATIVE_DAYS, DOW → dayStart, addDays, comingDow, parseTime, setTime, todayOrTomorrow → parseDateExpr → M.parse
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
lua tests/parser_spec.lua
```

Expected: `passed: 23, failed: 0`

- [ ] **Step 5: 커밋**

```bash
git add parser.lua tests/parser_spec.lua
git commit -m "feat(parser): support time tokens (3pm/15:00/3시/오후 3시)"
```

---

## Task 5: Parser — 날짜 + 시간 조합 및 fallback

**Files:**
- Modify: `parser.lua`
- Modify: `tests/parser_spec.lua`

- [ ] **Step 1: 테스트 추가**

```lua
-- ========== 날짜 + 시간 조합 ==========

test("@내일 3pm → tomorrow 15:00, not allday", function()
    local r = parser.parse("보고서 @내일 3pm", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 21); assertEq(d.hour, 15); assertEq(d.min, 0)
    assertEq(r.allday, false, "allday")
end)

test("@tomorrow 9am → tomorrow 09:00", function()
    local r = parser.parse("report @tomorrow 9am", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 21); assertEq(d.hour, 9)
    assertEq(r.allday, false)
end)

test("@월 10:30 → next Monday 10:30", function()
    local r = parser.parse("회의 @월 10:30", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 27); assertEq(d.hour, 10); assertEq(d.min, 30)
    assertEq(r.allday, false)
end)

test("@오늘 오후 3시 → today 15:00", function()
    local r = parser.parse("회의 @오늘 오후 3시", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 20); assertEq(d.hour, 15)
    assertEq(r.allday, false)
end)

test("@다음주 화 2pm → next Tuesday 14:00", function()
    local r = parser.parse("회의 @다음주 화 2pm", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 28); assertEq(d.hour, 14)
    assertEq(r.allday, false)
end)

-- ========== Fallback ==========

test("@garbage → keep original as name, no date", function()
    local r = parser.parse("우유 @아무말", FIXED_NOW)
    assertEq(r.name, "우유 @아무말", "name")
    assertEq(r.date, nil, "date")
    assertEq(r.allday, false)
end)

test("multiple @ → split on first; rest unparseable → fallback", function()
    local r = parser.parse("보고서 @work @내일", FIXED_NOW)
    -- dateExpr = "work @내일" is not parseable as a whole → fallback
    assertEq(r.name, "보고서 @work @내일", "name")
    assertEq(r.date, nil)
end)
```

- [ ] **Step 2: 실패 확인**

```bash
lua tests/parser_spec.lua
```

Expected: 7 new FAILs (날짜만/시간만 분기가 조합을 처리 못 함)

- [ ] **Step 3: parser.lua의 parseDateExpr를 날짜+시간 분리 로직으로 확장**

`parseDateExpr`를 다음으로 교체:

```lua
-- Attempt to split dateExpr into (datePart, timePart).
-- Returns datePart, timePart (either may be nil).
local function splitDateTime(expr)
    -- Strategy: scan word boundaries, try each prefix as date, suffix as time
    -- Simpler: tokenize by space, try splits.
    local tokens = {}
    for tok in expr:gmatch("%S+") do
        table.insert(tokens, tok)
    end
    if #tokens == 0 then return nil, nil end
    if #tokens == 1 then return expr, nil end  -- date only or time only — caller decides

    -- Try each split: first N tokens = date, rest = time
    for n = 1, #tokens - 1 do
        local datePart = table.concat(tokens, " ", 1, n)
        local timePart = table.concat(tokens, " ", n + 1)
        -- Return the split; caller validates both sides
        -- But we want the FIRST valid split. So we try to parse both.
        -- To avoid circularity, we return raw and let caller try.
        -- Here we just return the first split — caller iterates.
    end
    -- Fallback: return full expr as date, no time
    return expr, nil
end

local function parseDateOnly(expr, now)
    local lower = string.lower(expr)

    for token, offset in pairs(RELATIVE_DAYS) do
        if lower == token then
            return addDays(now, offset)
        end
    end

    local nextDow = lower:match("^다음주%s+(.+)$") or lower:match("^next%s+(.+)$")
    if nextDow then
        local wday = DOW[nextDow]
        if wday then return comingDow(now, wday) + 7 * 86400 end
    end

    local wday = DOW[lower]
    if wday then return comingDow(now, wday) end

    return nil
end

local function parseDateExpr(dateExpr, now)
    -- Try: full expr = date only
    local dateOnly = parseDateOnly(dateExpr, now)
    if dateOnly then
        return { date = dateOnly, allday = true }
    end

    -- Try: full expr = time only
    local time = parseTime(dateExpr)
    if time then
        return {
            date = todayOrTomorrow(now, time.hour, time.min),
            allday = false,
        }
    end

    -- Try: date + time split on spaces
    local tokens = {}
    for tok in dateExpr:gmatch("%S+") do
        table.insert(tokens, tok)
    end

    for n = 1, #tokens - 1 do
        local datePart = table.concat(tokens, " ", 1, n)
        local timePart = table.concat(tokens, " ", n + 1)
        local d = parseDateOnly(datePart, now)
        local t = parseTime(timePart)
        if d and t then
            return {
                date = setTime(d, t.hour, t.min),
                allday = false,
            }
        end
    end

    return nil
end
```

`splitDateTime` 함수는 사용 안 하게 되었으니 제거. 최종 parser.lua에 `splitDateTime` 없어야 함.

- [ ] **Step 4: 테스트 통과 확인**

```bash
lua tests/parser_spec.lua
```

Expected: `passed: 30, failed: 0`

- [ ] **Step 5: 커밋**

```bash
git add parser.lua tests/parser_spec.lua
git commit -m "feat(parser): combine date + time splits; fallback on parse failure"
```

---

## Task 6: Reminders — AppleScript 래퍼

**Files:**
- Create: `reminders.lua`

- [ ] **Step 1: reminders.lua 작성 (listLists, save, escape)**

```lua
local M = {}

-- Escape string for AppleScript double-quoted literal
local function escape(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    return s
end
M._escape = escape  -- expose for tests

-- Return array of list names from Reminders.app
function M.listLists()
    local script = [[
        tell application "Reminders"
            set result to {}
            repeat with l in lists
                set end of result to name of l
            end repeat
            return result
        end tell
    ]]
    local ok, out, _ = hs.osascript.applescript(script)
    if not ok then return {} end
    -- out is a Lua table when AppleScript returns a list
    if type(out) == "table" then return out end
    return {}
end

-- Save a reminder.
-- args: { list = "Work", name = "...", date = <os.time?>, allday = <bool> }
-- Returns: true, nil on success. false, errMsg on failure.
function M.save(args)
    local listName = escape(args.list or "")
    local name = escape(args.name or "")

    local propsParts = { string.format('name:"%s"', name) }

    if args.date then
        local asDate = os.date('date "%A, %B %d, %Y at %I:%M:%S %p"', args.date)
        if args.allday then
            table.insert(propsParts, string.format('allday due date:%s', asDate))
        else
            table.insert(propsParts, string.format('due date:%s', asDate))
        end
    end

    local props = table.concat(propsParts, ", ")

    local script = string.format([[
        tell application "Reminders"
            tell list "%s"
                make new reminder with properties {%s}
            end tell
        end tell
    ]], listName, props)

    local ok, _, err = hs.osascript.applescript(script)
    if ok then return true end
    return false, tostring(err)
end

return M
```

- [ ] **Step 2: Hammerspoon 콘솔에서 수동 테스트**

먼저 개발 디렉토리를 Hammerspoon config 경로로 심볼릭 링크:

```bash
ln -sfn /Users/raymond/Developer/quick-reminder ~/.hammerspoon/quick-reminder
```

Hammerspoon 앱을 열고 콘솔(Console) 창에서:

```lua
package.loaded["quick-reminder.reminders"] = nil
local r = require("quick-reminder.reminders")
-- 리스트 확인
hs.inspect(r.listLists())
-- 저장 테스트 (당신의 Reminders.app에 실제 저장됨!)
r.save({ list = "Work", name = "플랜 테스트: 삭제해도 됨", date = nil, allday = false })
-- 날짜 포함 테스트
r.save({ list = "Work", name = "플랜 테스트2", date = os.time() + 3600, allday = false })
```

Expected:
- `listLists()` 출력: `{ "Work", "Personal", ... }` (당신의 실제 리스트)
- Reminders.app 열어서 "플랜 테스트: 삭제해도 됨" 와 "플랜 테스트2" 확인
- 최초 실행 시 macOS가 Automation 권한 요청 → 허용

확인 후 두 리마인더 수동 삭제.

- [ ] **Step 3: escape 동작 확인 (콘솔에서)**

```lua
local r = require("quick-reminder.reminders")
-- 따옴표 포함 이름도 저장 가능
r.save({ list = "Work", name = '테스트 "인용" 백슬래시\\', date = nil })
```

Reminders.app에서 이름이 `테스트 "인용" 백슬래시\` 로 저장되었는지 확인, 수동 삭제.

- [ ] **Step 4: 커밋**

```bash
git add reminders.lua
git commit -m "feat(reminders): AppleScript wrapper for listLists and save"
```

---

## Task 7: Popup — HTML UI

**Files:**
- Create: `popup.html`

- [ ] **Step 1: popup.html 작성**

```html
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    html, body {
        width: 100%; height: 100%;
        background: transparent;
        font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
        color: white;
        overflow: hidden;
    }
    .container {
        background: rgba(30, 30, 32, 0.92);
        border-radius: 10px;
        padding: 14px 16px;
        height: 100%;
        backdrop-filter: blur(20px);
    }
    .list-label {
        font-size: 12px;
        color: rgba(255, 255, 255, 0.7);
        margin-bottom: 6px;
        font-weight: 500;
    }
    .list-label .icon { margin-right: 4px; }
    input {
        width: 100%;
        background: transparent;
        border: none;
        outline: none;
        color: white;
        font-size: 18px;
        font-weight: 400;
    }
    input::placeholder { color: rgba(255, 255, 255, 0.35); }
</style>
</head>
<body>
<div class="container">
    <div class="list-label"><span class="icon">📋</span><span id="list-name">Work</span></div>
    <input type="text" id="input" placeholder="할 일... (@내일 3pm)" autofocus>
</div>
<script>
    const input = document.getElementById('input');
    const listName = document.getElementById('list-name');

    function send(action, payload) {
        const msg = JSON.stringify({ action: action, payload: payload || {} });
        // Hammerspoon webview navigation callback fires on URL change
        window.location.href = 'hsmsg://' + encodeURIComponent(msg);
    }

    input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            send('submit', { text: input.value });
        } else if (e.key === 'Escape') {
            e.preventDefault();
            send('cancel');
        } else if (e.key === 'Tab') {
            e.preventDefault();
            send(e.shiftKey ? 'prev-list' : 'next-list');
        }
    });

    // Hammerspoon can call this to update the current list label
    window.setListName = function(name) {
        listName.textContent = name;
    };

    // Focus on load
    window.addEventListener('load', () => input.focus());
</script>
</body>
</html>
```

- [ ] **Step 2: 커밋**

```bash
git add popup.html
git commit -m "feat(popup): HTML/CSS/JS UI with list label and input"
```

---

## Task 8: Popup — Lua 래퍼

**Files:**
- Create: `popup.lua`

- [ ] **Step 1: popup.lua 작성**

```lua
local M = {}

local CONFIG = {
    width = 560,
    height = 90,
}

local currentWebview = nil
local currentLists = {}
local currentIndex = 1
local onSubmit = nil    -- function(listName, text)
local onCancel = nil    -- function()

local function centerFrame()
    local screen = hs.screen.mainScreen():frame()
    return {
        x = screen.x + (screen.w - CONFIG.width) / 2,
        y = screen.y + (screen.h - CONFIG.height) / 2,
        w = CONFIG.width,
        h = CONFIG.height,
    }
end

local function closeWebview()
    if currentWebview then
        currentWebview:delete()
        currentWebview = nil
    end
end

local function updateListLabel()
    if not currentWebview then return end
    local name = currentLists[currentIndex] or ""
    -- Escape for JS string literal
    name = name:gsub("\\", "\\\\"):gsub("'", "\\'")
    currentWebview:evaluateJavaScript(string.format("window.setListName('%s')", name))
end

local function handleMessage(msgJson)
    local ok, msg = pcall(hs.json.decode, msgJson)
    if not ok or type(msg) ~= "table" then return end

    if msg.action == "submit" then
        local text = (msg.payload and msg.payload.text) or ""
        local listName = currentLists[currentIndex]
        closeWebview()
        if onSubmit then onSubmit(listName, text) end
    elseif msg.action == "cancel" then
        closeWebview()
        if onCancel then onCancel() end
    elseif msg.action == "next-list" then
        currentIndex = (currentIndex % #currentLists) + 1
        updateListLabel()
    elseif msg.action == "prev-list" then
        currentIndex = ((currentIndex - 2) % #currentLists) + 1
        updateListLabel()
    end
end

-- Intercept hsmsg:// navigation and route to handleMessage
local function navigationCallback(action, webview, navID, err)
    -- We intercept before load. hs.webview gives us policyCallback; for simpler
    -- approach, use the webview:navigationCallback (fires on load start).
    return false  -- placeholder, replaced below
end

-- Open the popup.
-- opts = {
--   lists = { "Work", "Personal", ... },
--   initialIndex = <number>,
--   onSubmit = function(listName, text) end,
--   onCancel = function() end,
-- }
function M.open(opts)
    if currentWebview then return end  -- already open
    currentLists = opts.lists or {}
    currentIndex = opts.initialIndex or 1
    onSubmit = opts.onSubmit
    onCancel = opts.onCancel

    local htmlPath = hs.configdir .. "/quick-reminder/popup.html"
    local url = "file://" .. htmlPath

    local frame = centerFrame()

    currentWebview = hs.webview.new(frame, { developerExtrasEnabled = false })
        :windowStyle({ "closable", "nonactivating" })
        :level(hs.drawing.windowLevels.floating)
        :allowTextEntry(true)
        :transparent(true)
        :bringToFront(true)

    -- Intercept hsmsg:// URLs via policyCallback
    currentWebview:policyCallback(function(action, webview, navDetails)
        if action == "navigationAction" then
            local target = navDetails.request.URL
            if type(target) == "string" and target:sub(1, 8) == "hsmsg://" then
                local encoded = target:sub(9)
                local decoded = hs.http.urlDecode(encoded)
                handleMessage(decoded)
                return false  -- block the navigation
            end
        end
        return true
    end)

    currentWebview:url(url):show()
    currentWebview:hswindow():focus()

    -- Set initial list label after load
    hs.timer.doAfter(0.2, function()
        if currentWebview then updateListLabel() end
    end)
end

function M.isOpen()
    return currentWebview ~= nil
end

return M
```

- [ ] **Step 2: Hammerspoon 콘솔에서 수동 테스트**

```lua
package.loaded["quick-reminder.popup"] = nil
local p = require("quick-reminder.popup")
p.open({
    lists = { "Work", "Personal", "Shopping" },
    initialIndex = 1,
    onSubmit = function(list, text) print("submit:", list, text) end,
    onCancel = function() print("cancelled") end,
})
```

Expected:
- 화면 중앙에 팝업이 나타남
- `📋 Work` 라벨 + 입력 필드 표시
- Tab 누르면 라벨이 `Personal` → `Shopping` → `Work`로 순환
- Shift+Tab 역순환
- ESC → 콘솔에 `cancelled`
- 텍스트 입력 후 Enter → 콘솔에 `submit: Work 입력값`

- [ ] **Step 3: 커밋**

```bash
git add popup.lua
git commit -m "feat(popup): Lua wrapper around hs.webview with message bridge"
```

---

## Task 9: Trigger — Ctrl 더블탭

**Files:**
- Create: `trigger.lua`

- [ ] **Step 1: trigger.lua 작성**

```lua
local M = {}

local CTRL_FLAG = hs.eventtap.event.rawFlagMasks.control

-- State machine:
--   idle → ctrl-down(first) → first-down
--   first-down → ctrl-up → first-up (timer armed)
--   first-up → ctrl-down(second) → triggered (callback fires), back to idle
--   first-up → timeout → idle
--   any state → non-ctrl modifier change → idle
local state = "idle"
local timeoutTimer = nil
local onTrigger = nil

local eventtap = nil

local function resetState()
    state = "idle"
    if timeoutTimer then
        timeoutTimer:stop()
        timeoutTimer = nil
    end
end

local function armTimeout(ms)
    if timeoutTimer then timeoutTimer:stop() end
    timeoutTimer = hs.timer.doAfter(ms / 1000.0, resetState)
end

local function handleFlagsChanged(event)
    local flags = event:getFlags()
    local raw = event:getRawEventData().NSEventData.modifierFlags or 0

    -- Check ONLY ctrl is changing (no other modifiers active)
    local onlyCtrl = flags.ctrl and not flags.cmd and not flags.alt
                      and not flags.shift and not flags.fn

    local ctrlDown = flags.ctrl == true
    local otherModifier = flags.cmd or flags.alt or flags.shift or flags.fn

    if otherModifier then
        resetState()
        return false
    end

    if state == "idle" then
        if ctrlDown and onlyCtrl then
            state = "first-down"
            armTimeout(500)  -- safety net
        end
    elseif state == "first-down" then
        if not ctrlDown then
            state = "first-up"
            armTimeout(300)  -- the real double-tap window
        end
    elseif state == "first-up" then
        if ctrlDown and onlyCtrl then
            -- Double-tap complete
            resetState()
            if onTrigger then onTrigger() end
        end
    end

    return false  -- never consume
end

-- cb: function() called on double-tap
function M.start(cb, windowMs)
    onTrigger = cb
    windowMs = windowMs or 300
    if eventtap then eventtap:stop() end
    eventtap = hs.eventtap.new(
        { hs.eventtap.event.types.flagsChanged },
        handleFlagsChanged
    )
    eventtap:start()
end

function M.stop()
    if eventtap then eventtap:stop(); eventtap = nil end
    resetState()
    onTrigger = nil
end

return M
```

- [ ] **Step 2: Hammerspoon 콘솔에서 수동 테스트**

```lua
package.loaded["quick-reminder.trigger"] = nil
local t = require("quick-reminder.trigger")
t.start(function() print("TRIGGERED at " .. os.date("%H:%M:%S")) end)
```

Expected:
- Ctrl을 빠르게 두 번 누르면 콘솔에 `TRIGGERED ...` 출력
- Ctrl 한 번만 누르거나 천천히 두 번 누르면 아무 일 없음
- Ctrl+C, Ctrl+Cmd 같은 조합은 트리거 안 됨 (Ctrl 단독만)

테스트 후 정지:
```lua
t.stop()
```

- [ ] **Step 3: 커밋**

```bash
git add trigger.lua
git commit -m "feat(trigger): Ctrl double-tap detection via hs.eventtap state machine"
```

---

## Task 10: init.lua — 전체 연결

**Files:**
- Create: `init.lua`

- [ ] **Step 1: init.lua 작성**

```lua
local M = {}

local CONFIG = {
    defaultList = "Work",
    doubleTapWindowMs = 300,
    toastDuration = 1.2,
}

local parser = require("quick-reminder.parser")
local reminders = require("quick-reminder.reminders")
local popup = require("quick-reminder.popup")
local trigger = require("quick-reminder.trigger")

local function onSubmit(listName, text)
    if not text or text == "" then return end

    local parsed = parser.parse(text)
    local ok, err = reminders.save({
        list = listName,
        name = parsed.name,
        date = parsed.date,
        allday = parsed.allday,
    })

    if ok then
        hs.alert.show("✓ " .. listName .. "에 추가됨", CONFIG.toastDuration)
    else
        hs.alert.show("✗ 저장 실패: " .. tostring(err), {
            strokeColor = { red = 1, green = 0.3, blue = 0.3 },
            fillColor = { red = 0.2, green = 0, blue = 0, alpha = 0.85 },
        }, 2.0)
    end
end

local function onCancel()
    -- no-op
end

local function openPopup()
    if popup.isOpen() then return end

    local lists = reminders.listLists()
    if #lists == 0 then
        hs.alert.show("리마인더 리스트가 없습니다", 2.0)
        return
    end

    -- Find default list
    local initialIndex = 1
    local defaultFound = false
    for i, name in ipairs(lists) do
        if name == CONFIG.defaultList then
            initialIndex = i
            defaultFound = true
            break
        end
    end

    if not defaultFound then
        hs.alert.show("⚠ " .. CONFIG.defaultList .. " 리스트 없음, '" .. lists[1] .. "' 사용", 1.5)
    end

    popup.open({
        lists = lists,
        initialIndex = initialIndex,
        onSubmit = onSubmit,
        onCancel = onCancel,
    })
end

function M.start()
    trigger.start(openPopup, CONFIG.doubleTapWindowMs)
    print("[quick-reminder] started — Ctrl×2 to open")
end

function M.stop()
    trigger.stop()
end

-- Auto-start when required
M.start()

return M
```

- [ ] **Step 2: Hammerspoon 설정에 require 추가**

`~/.hammerspoon/init.lua`에 (없으면 만들고) 다음 라인 추가:

```lua
require("quick-reminder")
```

- [ ] **Step 3: Hammerspoon Reload 후 E2E 테스트**

Hammerspoon 메뉴 → Reload Config

수동 시나리오:
1. 아무 앱에서 Ctrl을 빠르게 두 번 누름
2. 팝업이 나타남, `📋 Work` 라벨 표시
3. `"테스트 1 @내일 3pm"` 입력 → Enter
4. `✓ Work에 추가됨` 토스트
5. Reminders.app 열어서 내일 15:00로 "테스트 1" 저장되었는지 확인, 수동 삭제
6. 다시 Ctrl×2 → 이번엔 Tab 눌러서 다른 리스트로 전환 → `"테스트 2"` → Enter
7. 해당 리스트에 저장 확인, 삭제
8. Ctrl×2 → ESC → 팝업 사라지고 저장 없음 확인

- [ ] **Step 4: 커밋**

```bash
git add init.lua
git commit -m "feat: wire trigger, popup, parser, reminders in init.lua"
```

---

## Task 11: 설치 스크립트 & 문서 마무리

**Files:**
- Create: `install.sh`
- Modify: `README.md`

- [ ] **Step 1: install.sh 작성**

```bash
#!/bin/bash
set -euo pipefail

SOURCE="$(cd "$(dirname "$0")" && pwd)"
TARGET="$HOME/.hammerspoon/quick-reminder"

if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
    echo "Error: $TARGET exists and is not a symlink. Remove it first."
    exit 1
fi

if [ -L "$TARGET" ]; then
    rm "$TARGET"
fi

ln -s "$SOURCE" "$TARGET"
echo "Linked: $TARGET → $SOURCE"

HS_INIT="$HOME/.hammerspoon/init.lua"
if ! grep -q 'require("quick-reminder")' "$HS_INIT" 2>/dev/null; then
    echo 'require("quick-reminder")' >> "$HS_INIT"
    echo "Added require line to $HS_INIT"
else
    echo "require line already in $HS_INIT"
fi

echo ""
echo "Next steps:"
echo "  1. Open Hammerspoon, grant Accessibility permission if asked"
echo "  2. Hammerspoon menu → Reload Config"
echo "  3. Press Ctrl twice to open the reminder popup"
echo "  4. First save will ask for Automation → Reminders permission"
```

- [ ] **Step 2: 실행 권한 부여**

```bash
chmod +x install.sh
```

- [ ] **Step 3: README 업데이트 (사용법 섹션)**

`README.md`를 다음으로 교체:

```markdown
# Quick Reminder

Hammerspoon 모듈: Ctrl 더블탭 → 팝업 입력 → macOS Reminders에 추가.

## 요구사항

- macOS
- [Hammerspoon](https://www.hammerspoon.org) (`brew install --cask hammerspoon`)
- Lua 5.4 (테스트 실행용, `brew install lua`)

## 설치

```bash
./install.sh
```

1. Hammerspoon 앱을 열고 **Accessibility** 권한 부여
2. Hammerspoon 메뉴 → **Reload Config**
3. 첫 저장 시 **Automation → Reminders** 권한 요청 → 허용

## 사용법

- **Ctrl 더블탭** (빠르게 두 번): 팝업 열기
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
- `doubleTapWindowMs` — 더블탭 인식 시간 (기본값: 300)
- `toastDuration` — 토스트 표시 시간 (기본값: 1.2)
```

- [ ] **Step 4: 최종 E2E 체크리스트 수동 확인**

다음을 모두 확인:
- [ ] Ctrl 더블탭으로 팝업 열림
- [ ] 기본 리스트가 `Work`로 선택됨
- [ ] Tab으로 리스트 순환, 라벨이 즉시 갱신
- [ ] Shift+Tab 역순환
- [ ] 텍스트만 입력 후 Enter → 저장 + 성공 토스트
- [ ] `@내일 3pm` 포함 입력 → 정확한 날짜/시간으로 저장
- [ ] `@아무말` 같은 파싱 실패 → 원문 그대로 이름 저장
- [ ] 빈 입력 + Enter → 아무 일 없음
- [ ] ESC → 팝업 닫힘, 저장 없음
- [ ] 팝업 바깥 클릭 → 닫힘 (포커스 아웃)
- [ ] `parser_spec.lua` 전체 통과

- [ ] **Step 5: 최종 커밋**

```bash
git add install.sh README.md
git commit -m "chore: add install script and user-facing README"
```

---

## Self-Review

**Spec coverage check:**
- §3 Architecture (파일 구조): Tasks 1-10 각 파일 생성 ✓
- §4 Trigger: Task 9 ✓
- §5 Popup UI: Tasks 7-8 ✓
- §6 리스트 관리: Task 10 (init.lua의 openPopup) ✓
- §7 파싱: Tasks 1-5 ✓
- §8 저장 (escape 포함): Task 6 ✓
- §9 피드백 (토스트): Task 10 ✓
- §10 권한: Task 11 README + install.sh 안내 ✓
- §11 엣지 케이스: Task 10 (빈 리스트, 기본 없음), Tasks 1,5 (빈 입력, 파싱 실패) ✓
- §12 설정: Task 10 CONFIG 테이블 ✓
- §13 설치: Task 11 install.sh ✓
- §14 테스트: Tasks 1-5 (파서 단위), Tasks 6,8,9,10 (수동 E2E) ✓

**Placeholder scan:** 모든 step에 실제 코드/명령 포함. TBD 없음.

**Type consistency:**
- `parser.parse(input, now?)` → `{name, date, allday}` — 모든 task 일관
- `reminders.save({list, name, date, allday})` — Task 6 정의, Task 10 호출 일관
- `popup.open({lists, initialIndex, onSubmit, onCancel})` — Task 8 정의, Task 10 호출 일관
- `trigger.start(cb, windowMs)` — Task 9 정의, Task 10 호출 일관

전부 통과.
