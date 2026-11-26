-- 르엘 UI · 오류 알리기 (C안)
-- 오류가 나면 게임 기본 "애드온 오류" 창 대신 토끼 알림 → 캡처용 카드 · 코드 복사 · 자세히
-- 오류는 최근 20개까지 저장 (같은 오류는 횟수만) · BugSack(BugGrabber)이 있으면 그쪽에 맡기고 기록만
local ADDON, ns = ...
local C = ns.C
local L = function(s) return ns.L and ns.L(s) or s end

local E = {}
ns.Err = E
local MAX = 20
local buf = {}            -- ns.db 가 생기기 전 오류
local enteredAt = 0       -- 지역 들어온 시각 (몇 초 안 오류 = "지역 들어갈 때")
local pending = false     -- 전투 중 미뤄 둔 알림

local function Mode()  return (ns.db and ns.db.errMode) or "bunny" end   -- bunny / blizz / off
local function Others() return not (ns.db and ns.db.errOthers == "log") end
local function Log()
    if not ns.db then return buf end
    local l = ns.db.errLog
    if type(l) ~= "table" then l = {}; ns.db.errLog = l end
    if #buf > 0 then for _, e in ipairs(buf) do table.insert(l, 1, e) end; buf = {}; while #l > MAX do table.remove(l) end end
    return l
end
E.Log = Log

local function IsLeel(a) return a and (a:find("^Leel") or a == "ForgLeveling") and true or false end
E.IsLeel = IsLeel

local function GetMeta(a, k)
    local f = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ok, v = pcall(f, a, k)
    return ok and v or nil
end
local function Ver() return GetMeta(ADDON, "Version") or "?" end
local function Lang() return (ns.db and ns.db.lang == "en") and "en" or "ko" end
local function BugGrabberOn() return _G.BugGrabber ~= nil end

-- "Interface/AddOns/Questie/Modules/QuestieQuest.lua:1043: 글" → 애드온 · 파일 · 줄 · 글
local function Parse(msg, stack)
    local s = tostring(msg or "")
    local a = s:match("AddOns[\\/]([^\\/]+)[\\/]")
    if not a and stack then a = stack:match("AddOns[\\/]([^\\/]+)[\\/]") end
    local file, line, text = s:match("([^\\/%s%[]+%.lua)%D*(%d+)%]?:%s*(.*)")
    if not file then file, line = s:match("([^\\/%s%[]+%.lua)%D*(%d+)") end
    if not a and s:find("Blizzard_", 1, true) then a = s:match("(Blizzard_[%w_]+)") end
    return a or "?", file or "?", tonumber(line) or 0, (text and text ~= "" and text) or s
end

local function Stack(raw)
    local ok, st = true, raw
    if not raw then ok, st = pcall(debugstack, 2, 14, 0) end
    if not ok or type(st) ~= "string" then return "" end
    local out, n = {}, 0
    for raw in st:gmatch("[^\n]+") do
        local ln = raw
        if not ln:find("ErrReport.lua", 1, true) and not (n == 0 and ln:find("in function [`']x?pcall'")) then
            ln = ln:gsub("^%[string \"@?Interface[\\/]AddOns[\\/]", "["):gsub("Interface[\\/]AddOns[\\/]", "")
            n = n + 1; out[n] = ln
            if n >= 8 then break end
        end
    end
    return table.concat(out, "\n")
end

local function Where()
    local z = (GetRealZoneText and GetRealZoneText()) or ""
    local _, it = IsInInstance()
    local when
    if GetTime() - enteredAt < 8 then when = (it and it ~= "none") and "던전 들어갈 때" or "지역 들어갈 때"
    elseif InCombatLockdown() then when = "전투 중" end
    return z, (it and it ~= "none") and true or false, when
end

local function Now() return date("%m/%d %H:%M:%S") end

local function Short(e)
    local minor = (e.ver or ""):match("%d+%.%d+%.(%d+)") or e.ver or "?"
    local base = (e.file or "?"):gsub("%.lua$", "")
    return ("LEEL %s · %s:%d · %d"):format(minor, base, e.line or 0, e.n or 1)
end
E.Short = Short

local function Full(e)
    local fl = {}
    for ln in (e.stack or ""):gmatch("[^\n]+") do
        local f = ln:match("([%w_]+)%.lua") ; local fn = ln:match("in function [`'<]([^'>]+)")
        if f then fl[#fl + 1] = fn and (f .. ":" .. fn) or f end
        if #fl >= 3 then break end
    end
    local av = (not IsLeel(e.addon) and e.aver) and (" " .. e.aver) or ""
    return ("[LEEL %s %s] %s%s · %s:%d: %s · x%d · %s%s%s · 애드온 %d개"):format(
        e.ver or "?", e.lang or "ko", e.addon or "?", av, e.file or "?", e.line or 0, (e.text or ""):sub(1, 160),
        e.n or 1, e.zone or "", e.when and (" (" .. e.when .. ")") or "",
        #fl > 0 and (" · " .. table.concat(fl, " ← ")) or "", e.addons or 0)
end
E.Full = Full

local function AddonCount()
    local n = 0
    local num = (C_AddOns and C_AddOns.GetNumAddOns or GetNumAddOns)()
    local isl = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    for i = 1, num do if isl(i) then n = n + 1 end end
    return n
end
local function AddonList()
    local t = {}
    local num = (C_AddOns and C_AddOns.GetNumAddOns or GetNumAddOns)()
    local isl = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    local info = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
    for i = 1, num do
        if isl(i) then local name = info(i); local v = GetMeta(name, "Version"); t[#t + 1] = v and (name .. " " .. v) or name end
    end
    return table.concat(t, " · ")
end

----------------------------------------------------------------------
-- 기록
----------------------------------------------------------------------
local busy = false
-- 같은 글이 쏟아지면(매 순간 막힘 등) 무거운 일(스택 · 위치 · 애드온 세기) 없이 횟수만 · 1초에 20개 넘으면 버려요
--   (안 그러면 "insecure scripts exceeded execution limit" 으로 게임이 르엘을 멈춰요)
local fast, fastN, burstT, burstN = {}, 0, 0, 0
local function Record(msg, rawStack)
    if busy then return end
    local now = GetTime()
    local fk = tostring(msg):sub(1, 200)
    local fe = fast[fk]
    if fe and now - fe.at < 5 then fe.e.n = (fe.e.n or 1) + 1; fe.e.t2 = Now(); return fe.e end
    if now - burstT > 1 then burstT, burstN = now, 0 end
    burstN = burstN + 1
    if burstN > 20 then return nil end
    busy = true
    local ok, e = pcall(function()
        local stack = Stack(rawStack)
        local a, file, line, text = Parse(msg, stack)
        local key = a .. "|" .. file .. "|" .. line .. "|" .. text:sub(1, 60)
        local log = Log()
        for i, x in ipairs(log) do
            if x.key == key then
                x.n = (x.n or 1) + 1; x.t2 = Now()
                if i > 1 then table.remove(log, i); table.insert(log, 1, x) end
                return x
            end
        end
        local z, inst, when = Where()
        local x = { key = key, addon = a, file = file, line = line, text = text, msg = tostring(msg):sub(1, 400), stack = stack,
                    n = 1, t1 = Now(), t2 = Now(), zone = z, inst = inst, when = when, ver = Ver(), lang = Lang(),
                    aver = (a ~= "?" and not a:find("^Blizzard_")) and GetMeta(a, "Version") or nil, addons = AddonCount() }
        table.insert(log, 1, x)
        while #log > MAX do table.remove(log) end
        return x
    end)
    busy = false
    if ok and e then
        fastN = fastN + 1
        if fastN > 60 then wipe(fast); fastN = 0 end
        fast[fk] = { e = e, at = now }
        if IsLeel(e.addon) then local f = e.file ~= "?" and (e.file .. ":" .. e.line) or e.text:sub(1, 40); ns.lastErr = f end
        return e
    end
end

----------------------------------------------------------------------
-- 토끼 알림 (위 가운데)
----------------------------------------------------------------------
local toast, card
local function Col(e) return IsLeel(e.addon) and C.acc or { 1, 0.82, 0.48 } end
local function AName(e)
    if IsLeel(e.addon) then return e.addon == "LeelUI" and L("르엘 UI") or e.addon end
    if e.addon:find("^Blizzard_") then return L("게임 기본 UI") end
    if e.addon == "?" then return L("알 수 없는 애드온") end
    return e.addon
end

local function Plate(f, r, a)
    ns.RoundPlate(f, r, { 0.10, 0.075, 0.07, a or 0.96 }, { C.acc[1], C.acc[2], C.acc[3], 0.6 })
end

local function Btn(parent, text, primary, w, fn)
    local b = ns.MakeButton(parent, L(text), primary, fn, w)
    b:SetHeight(22); if b.fs then pcall(b.fs.SetFont, b.fs, ns.FONT, 11, "") end
    return b
end

local function BuildToast()
    local t = CreateFrame("Button", "LeelUI_ErrToast", UIParent)
    t:SetSize(260, 34); t:SetPoint("TOP", UIParent, "TOP", 0, -70)
    t:SetFrameStrata("FULLSCREEN_DIALOG"); t:SetFrameLevel(50); t:SetClampedToScreen(true)
    Plate(t, 17)
    local bc = t:CreateTexture(nil, "ARTWORK"); bc:SetTexture(ns.MEDIA .. "circle"); bc:SetSize(26, 26); bc:SetPoint("LEFT", 4, 0)
    bc:SetVertexColor(C.acc[1], C.acc[2], C.acc[3])
    local bn = t:CreateTexture(nil, "OVERLAY"); bn:SetTexture(ns.MEDIA .. "bunny"); bn:SetSize(20, 20); bn:SetPoint("CENTER", bc)
    t.fs = ns.Font(t, 12, C.tx); t.fs:SetPoint("LEFT", bc, "RIGHT", 7, 0)
    t.go = Btn(t, "보기", true, 46, function() t:Hide(); E.Open(1) end)
    t.go:SetPoint("RIGHT", -6, 0)
    t:SetScript("OnClick", function() t:Hide(); E.Open(1) end)
    t:Hide()
    return t
end

function E.Toast()
    if Mode() ~= "bunny" then return end
    local log = Log()
    local e = log[1]
    if not e or e.quiet then return end
    if not IsLeel(e.addon) and not Others() then return end
    if InCombatLockdown() then pending = true return end
    toast = toast or BuildToast()
    local c = Col(e)
    local live = 0; for _, x in ipairs(log) do if not x.quiet then live = live + 1 end end
    toast.fs:SetText(("%s %d · |cff%02x%02x%02x%s|r ×%d"):format(L("오류"), live, c[1] * 255, c[2] * 255, c[3] * 255, AName(e), e.n or 1))
    toast:SetWidth(toast.fs:GetStringWidth() + 98)
    toast:Show()
    if toast.timer then toast.timer:Cancel() end
    toast.timer = C_Timer.NewTimer(15, function() if toast then toast:Hide() end end)
    if card and card:IsShown() then E.Open(card.idx or 1) end
end

----------------------------------------------------------------------
-- 카드 (캡처용) · 코드 복사 · 자세히
----------------------------------------------------------------------
local function CopyEdit(parent, multi)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetAutoFocus(false); e:SetMultiLine(multi and true or false)
    e:SetFontObject(ChatFontNormal); pcall(e.SetFont, e, ns.FONT, multi and 10.5 or 11, "")
    e:SetTextColor(1, 0.86, 0.9)
    e:SetScript("OnTextChanged", function(self, user) if user and self.value then self:SetText(self.value); self:HighlightText() end end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    function e:Set(t) self.value = t; self:SetText(t); self:SetCursorPosition(0) end
    return e
end

local function BuildCard()
    local f = CreateFrame("Frame", "LeelUI_ErrCard", UIParent)
    f:SetSize(440, 268); f:SetPoint("TOP", UIParent, "TOP", 0, -110)
    f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(50); f:SetToplevel(true); f:SetClampedToScreen(true); f:EnableMouse(true); f:SetMovable(true)
    f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    Plate(f, 14, 0.97)
    tinsert(UISpecialFrames, "LeelUI_ErrCard")
    local bc = f:CreateTexture(nil, "ARTWORK"); bc:SetTexture(ns.MEDIA .. "bunny"); bc:SetSize(18, 18); bc:SetPoint("TOPLEFT", 12, -10)
    local h = ns.Font(f, 13.5, C.accHi); h:SetPoint("LEFT", bc, "RIGHT", 5, 0); h:SetText(L("오류 알리기"))
    f.close = Btn(f, "닫기", false, 44, function() f:Hide() end); f.close:SetPoint("TOPRIGHT", -10, -8)
    f.next = Btn(f, "▶", false, 26, function() E.Open((f.idx or 1) + 1) end); f.next:SetPoint("RIGHT", f.close, "LEFT", -4, 0)
    f.pos = ns.Font(f, 11, C.tx2); f.pos:SetPoint("RIGHT", f.next, "LEFT", -6, 0)
    f.prev = Btn(f, "◀", false, 26, function() E.Open((f.idx or 1) - 1) end); f.prev:SetPoint("RIGHT", f.pos, "LEFT", -6, 0)

    -- 요약 면
    local m = CreateFrame("Frame", nil, f); m:SetPoint("TOPLEFT", 12, -36); m:SetPoint("BOTTOMRIGHT", -12, 10); f.main = m
    f.name = ns.Font(m, 16, C.tx); f.name:SetPoint("TOPLEFT", 0, 0)
    f.meta = ns.Font(m, 11, C.tx2); f.meta:SetPoint("LEFT", f.name, "RIGHT", 7, -1); f.meta:SetPoint("RIGHT", m, "RIGHT", 0, 0); f.meta:SetJustifyH("LEFT"); f.meta:SetWordWrap(false)
    f.err = ns.Font(m, 12, { 1, 0.55, 0.55 }); f.err:SetPoint("TOPLEFT", 0, -24); f.err:SetPoint("RIGHT", m, "RIGHT", 0, 0); f.err:SetJustifyH("LEFT"); f.err:SetWordWrap(true); f.err:SetMaxLines(2)
    f.note = ns.Font(m, 11, { 0.56, 0.91, 0.6 }); f.note:SetPoint("TOPLEFT", f.err, "BOTTOMLEFT", 0, -4)
    local lab = ns.Font(m, 10.5, C.tx2); lab:SetPoint("TOPLEFT", 0, -84); lab:SetText(L("캡처해서 보내거나 · 코드를 복사해서 보내 주세요"))
    local cb = CreateFrame("Frame", nil, m); cb:SetHeight(34); cb:SetPoint("TOPLEFT", 0, -100); cb:SetPoint("RIGHT", m, "RIGHT", 0, 0)
    ns.RoundPlate(cb, 8, { 0.047, 0.035, 0.035, 1 }, { C.acc[1], C.acc[2], C.acc[3], 0.55 })
    f.code = ns.Font(cb, 16, { 1, 1, 1 }); f.code:SetPoint("CENTER")
    f.bCopy = Btn(m, "코드 복사", true, 84, function() E.Pane("copy") end)
    f.bMore = Btn(m, "자세히", false, 60, function() E.Pane("more") end)
    f.bQuiet = Btn(m, "다시 안 알리기", false, 104, function()
        local e = Log()[f.idx or 1]; if e then e.quiet = not e.quiet; E.Open(f.idx) end end)
    f.bMore:SetPoint("TOP", cb, "BOTTOM", 0, -8)
    f.bCopy:SetPoint("RIGHT", f.bMore, "LEFT", -5, 0); f.bQuiet:SetPoint("LEFT", f.bMore, "RIGHT", 5, 0)
    local to = ns.Font(m, 10.5, C.tx2); to:SetPoint("BOTTOMLEFT", 0, 0)
    to:SetText(L("보낼 곳: 유튜브 @채채TV_2 커뮤니티 · 허브 아래 \"르엘 소통방\""))

    -- 코드 복사 면
    local cp = CreateFrame("Frame", nil, f); cp:SetAllPoints(m); cp:Hide(); f.copy = cp
    local cbx = CreateFrame("Frame", nil, cp); cbx:SetPoint("TOPLEFT", 0, 0); cbx:SetPoint("RIGHT", cp, "RIGHT", 0, 0); cbx:SetHeight(86)
    ns.RoundPlate(cbx, 8, { 0.16, 0.09, 0.12, 1 }, { C.acc[1], C.acc[2], C.acc[3], 0.9 })
    f.cEdit = CopyEdit(cbx, true); f.cEdit:SetPoint("TOPLEFT", 8, -7); f.cEdit:SetPoint("BOTTOMRIGHT", -8, 7)
    local k1 = ns.Font(cp, 12.5, C.tx); k1:SetPoint("TOPLEFT", cbx, "BOTTOMLEFT", 0, -10); k1:SetText(L("지금 Ctrl + C 누르세요"))
    local k2 = ns.Font(cp, 11, C.tx2); k2:SetPoint("TOPLEFT", k1, "BOTTOMLEFT", 0, -8); k2:SetJustifyH("LEFT"); k2:SetSpacing(4)
    k2:SetText(L("① 게임 밖 유튜브 · 카톡 · 디스코드 열기\n② 글 칸에 Ctrl + V\n③ \"던전 들어가니까 떠요\"처럼 한 줄 쓰면 끝!"))
    local bk = Btn(cp, "◀ 돌아가기", false, 84, function() E.Pane("main") end); bk:SetPoint("BOTTOMRIGHT", 0, 0)

    -- 자세히 면
    local mo = CreateFrame("Frame", nil, f); mo:SetAllPoints(m); mo:Hide(); f.more = mo
    local sb = CreateFrame("ScrollFrame", nil, mo); sb:SetPoint("TOPLEFT", 0, 0); sb:SetPoint("BOTTOMRIGHT", 0, 30)
    local bgp = CreateFrame("Frame", nil, mo); bgp:SetAllPoints(sb); bgp:SetFrameLevel(sb:GetFrameLevel() - 1)
    ns.RoundPlate(bgp, 8, { 0.047, 0.035, 0.035, 1 }, { 0.3, 0.2, 0.2, 1 })
    f.mEdit = CopyEdit(sb, true); f.mEdit:SetWidth(400); sb:SetScrollChild(f.mEdit)
    sb:EnableMouseWheel(true)
    sb:SetScript("OnMouseWheel", function(self, d)
        local max = math.max(0, f.mEdit:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * 30)))
    end)
    local all = Btn(mo, "전체 복사", true, 74, function() f.mEdit:SetFocus(); f.mEdit:HighlightText() end); all:SetPoint("BOTTOMLEFT", 0, 0)
    local priv = ns.Font(mo, 10, C.tx2); priv:SetPoint("LEFT", all, "RIGHT", 8, 0); priv:SetText(L("캐릭터 이름 · 계정 · 채팅은 안 들어가요"))
    local bk2 = Btn(mo, "◀ 돌아가기", false, 84, function() E.Pane("main") end); bk2:SetPoint("BOTTOMRIGHT", 0, 0)
    f:Hide()
    return f
end

function E.Pane(which)
    if not card then return end
    card.main:SetShown(which == "main"); card.copy:SetShown(which == "copy"); card.more:SetShown(which == "more")
    local e = Log()[card.idx or 1]
    if not e then return end
    if which == "copy" then card.cEdit:Set(Full(e)); card.cEdit:SetFocus(); card.cEdit:HighlightText()
    elseif which == "more" then
        local t = (e.msg or "") .. "\n" .. (e.stack or "") ..
            "\n\n" .. L("시간") .. " " .. (e.t1 or "") .. (e.n and e.n > 1 and (" ~ " .. (e.t2 or "") .. " · " .. e.n .. L("번")) or "") ..
            "\n" .. L("지역") .. " " .. (e.zone or "") .. (e.when and (" · " .. L(e.when)) or "") ..
            "\n" .. L("버전") .. " LeelUI " .. (e.ver or "") .. " (" .. (e.lang or "ko") .. ")" ..
            "\n" .. L("애드온") .. " " .. AddonList()
        card.mEdit:Set(t)
    end
end

function E.Open(idx)
    local log = Log()
    if #log == 0 then ns.Print(L("저장된 오류가 없어요.")) return end
    card = card or BuildCard()
    idx = math.max(1, math.min(#log, idx or 1))
    card.idx = idx
    local e = log[idx]
    local c = Col(e)
    card.name:SetText(AName(e)); card.name:SetTextColor(c[1], c[2], c[3])
    local who = IsLeel(e.addon) and L("르엘") or L("르엘 아님")
    card.meta:SetText(who .. (e.when and (" · " .. L(e.when)) or "") .. " · " .. (e.n or 1) .. L("번") .. " · " .. (e.t2 or ""))
    card.err:SetText((e.file ~= "?" and (e.file .. " " .. e.line .. " · ") or "") .. (e.text or ""))
    if IsLeel(e.addon) then card.note:SetText(L("르엘 오류예요 · 보내 주시면 다음 업데이트에 고쳐요")); card.note:SetTextColor(C.accHi[1], C.accHi[2], C.accHi[3])
    else card.note:SetText(("%s · %s"):format(L("게임엔 큰 영향 없어요"), AName(e) .. L(" 쪽 문제예요"))); card.note:SetTextColor(0.56, 0.91, 0.6) end
    card.code:SetText(Short(e))
    card.pos:SetText(idx .. "/" .. #log)
    card.prev:SetEnabled(idx > 1); card.next:SetEnabled(idx < #log)
    card.bQuiet.fs:SetText(L(e.quiet and "다시 알리기" or "다시 안 알리기"))
    E.Pane("main")
    card:Show(); card:Raise()
    if toast then toast:Hide() end
end

function E.Clear()
    if ns.db then ns.db.errLog = {} end; buf = {}
    if card then card:Hide() end; if toast then toast:Hide() end
    ns.Print(L("오류 기록을 비웠어요."))
end

-- 미리 보기: 가짜 오류 하나 (기록엔 안 남김)
function E.Test()
    local log = Log()
    local fake = { key = "_test", addon = "Questie", file = "QuestieQuest.lua", line = 1043, text = "invalid key to 'next'",
        msg = "Interface/AddOns/Questie/Modules/Quest/QuestieQuest.lua:1043: invalid key to 'next'",
        stack = "[C]: in function 'next'\nQuestie/Modules/Quest/QuestieQuest.lua:1043: in function 'ClearAllNotes'\nQuestie/Modules/EventHandler/QuestieEventHandler.lua:212: in function <...>",
        n = 3, t1 = Now(), t2 = Now(), zone = GetRealZoneText and GetRealZoneText() or "", when = "던전 들어갈 때", ver = Ver(), lang = Lang(), aver = "11.2", addons = AddonCount() }
    for i = #log, 1, -1 do if log[i].key == "_test" then table.remove(log, i) end end
    table.insert(log, 1, fake)
    local m, o = Mode(), ns.db and ns.db.errOthers
    if ns.db then ns.db.errMode, ns.db.errOthers = "bunny", nil end
    E.Toast()
    if ns.db then ns.db.errMode, ns.db.errOthers = m, o end
    C_Timer.After(30, function() local l = Log(); for i = #l, 1, -1 do if l[i].key == "_test" then table.remove(l, i) end end end)
end

----------------------------------------------------------------------
-- 오류 잡기
----------------------------------------------------------------------
local errQ, errQT = {}, false
local function FlushErr()
    errQT = false
    local q = errQ; errQ = {}
    local toastIt = false
    for _, it in ipairs(q) do
        local e = Record(it[1], it[2])
        if e and (e.n == 1 or (e.n and e.n % 20 == 0)) then toastIt = true end
    end
    local cv = GetCVar and GetCVar("scriptErrors")
    if toastIt and not (BugGrabberOn() or Mode() == "blizz" or cv == "1") then pcall(E.Toast) end
end
do
    local okH, orig = pcall(geterrorhandler)
    if okH and orig and seterrorhandler then
        pcall(seterrorhandler, function(msg, ...)
            -- 와우 포에버 특성 창 자체 오류 (게임 문구 버그 · 기능 영향 없음) → 조용히
            if type(msg) == "string" and msg:find("Blizzard_SharedTalentUtil", 1, true) and msg:find("invalid option in `format'", 1, true) then
                return
            end
            -- 오류 처리기는 게임 코드 안에서도 불려요 → 거기서 오래 일하면 "insecure scripts exceeded execution limit"
            --   그래서 여기선 글만 줄에 넣고, 기록 · 알림은 다음 순간(게임 코드 밖)에 해요
            if #errQ < 30 then
                local st
                if #errQ < 3 then local okS, r = pcall(debugstack, 2, 14, 0); if okS then st = r end end   -- 어디서 났는지는 여기서만 알 수 있어요
                errQ[#errQ + 1] = { msg, st }
            end
            if not errQT then errQT = true; C_Timer.After(0, FlushErr) end
            -- BugSack이 있거나 · "게임 기본 창"이거나 · 빨간 오류 창을 켠 사람은 원래대로
            local cv = GetCVar and GetCVar("scriptErrors")
            if BugGrabberOn() or Mode() == "blizz" or cv == "1" then return orig(msg, ...) end
        end)
    end
    -- 그래도 "애드온 오류가 많아요" 기본 창이 뜨면 닫기 (토끼 알림 쓰는 동안)
    if StaticPopup_Show then
        hooksecurefunc("StaticPopup_Show", function(which)
            if which == "TOO_MANY_LUA_ERRORS" and Mode() ~= "blizz" and not BugGrabberOn() and StaticPopup_Hide then StaticPopup_Hide(which) end
        end)
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("ADDON_ACTION_BLOCKED"); ev:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD"); ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function(_, event, who, what)
        if event == "PLAYER_ENTERING_WORLD" then enteredAt = GetTime(); Log()
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pending then pending = false; C_Timer.After(0.5, function() pcall(E.Toast) end) end
        else
            -- 게임이 막은 동작 (클릭이 안 먹히는 원인) · 오류 창이 안 떠서 기록에도 남겨요 · 다른 애드온 것도
            local addon = type(who) == "string" and who or "?"
            if addon:find("^Leel") or addon == "ForgLeveling" then ns.lastErr = "차단:" .. tostring(what or "?") end
            local e = Record(("Interface/AddOns/%s/차단.lua:0: 게임이 막은 동작 (%s) %s"):format(addon,
                event == "ADDON_ACTION_FORBIDDEN" and "금지" or "전투 중 차단", tostring(what or "?")))
            if e and (e.n == 1) then pcall(E.Toast) end
        end
    end)
end

SLASH_LEELERR1 = "/르엘오류"; SLASH_LEELERR2 = "/leelerr"
SlashCmdList.LEELERR = function(a)
    if a == "test" or a == "시험" then E.Test() elseif a == "clear" or a == "비우기" then E.Clear() else E.Open(1) end
end

----------------------------------------------------------------------
-- 멈춤 찾기: /르엘측정 → 어느 애드온 때문에 화면이 멈추는지 (지도 M 등)
-- 게임 "스크립트 측정"을 잠깐 켜고 · 0.12초 넘게 멈춘 순간마다 그 사이 가장 많이 일한 애드온을 적어요
----------------------------------------------------------------------
do
    local AC = C_AddOns or {}
    local GetNum = AC.GetNumAddOns or GetNumAddOns
    local Info = AC.GetAddOnInfo or GetAddOnInfo
    local Loaded = AC.IsAddOnLoaded or IsAddOnLoaded
    local mf, last, hits, names, t0
    local function P(s) ns.Print(L(s)) end
    local function Snap()
        UpdateAddOnCPUUsage()
        local t = {}
        for i = 1, #names do t[i] = GetAddOnCPUUsage(names[i]) or 0 end
        return t
    end
    local function Stop(show)
        if mf then mf:SetScript("OnUpdate", nil) end
        if show then
            if not hits or #hits == 0 then P("측정 끝: 0.12초 넘게 멈춘 적이 없었어요.")
            else
                ns.Print(L("측정 끝: 멈춤") .. " " .. #hits .. L("번 (긴 순서)"))
                table.sort(hits, function(a, b) return a.ms > b.ms end)
                for k = 1, math.min(5, #hits) do
                    local h = hits[k]
                    local parts = {}
                    for j = 1, math.min(3, #h.top) do parts[j] = ("%s %dms"):format(h.top[j][1], h.top[j][2]) end
                    local sum = 0; for _, x in ipairs(h.top) do sum = sum + x[2] end
                    local tail = (#parts == 0 or sum < h.ms * 0.3) and L(" · 대부분 게임 자체 (그림 불러오기)") or ""
                    ns.Print(("  %d. %dms%s · %s%s"):format(k, h.ms, h.map and L(" · 지도 열 때") or "", table.concat(parts, " · "), tail))
                end
            end
            SetCVar("scriptProfile", "0")
            P("측정을 껐어요 · /reload 하면 원래 속도로 돌아가요. 위 줄을 캡처해서 보내 주세요.")
        end
        hits = nil
    end
    local function Start()
        names = {}
        for i = 1, GetNum() do local n = Info(i); if n and Loaded(i) then names[#names + 1] = n end end
        mf = mf or CreateFrame("Frame")
        hits, t0, last = {}, GetTime(), Snap()
        local mapAt = 0
        if WorldMapFrame and not mf.hooked then mf.hooked = true; WorldMapFrame:HookScript("OnShow", function() mapAt = GetTime() end) end
        mf:SetScript("OnUpdate", function(_, el)
            local now = Snap()
            if el > 0.12 then
                local top = {}
                for i = 1, #names do local d = now[i] - last[i]; if d >= 5 then top[#top + 1] = { names[i], math.floor(d + 0.5) } end end
                table.sort(top, function(a, b) return a[2] > b[2] end)
                hits[#hits + 1] = { ms = math.floor(el * 1000 + 0.5), top = top, map = GetTime() - mapAt < el + 0.5 }
            end
            last = now
            if GetTime() - t0 > (mf.limit or 120) then Stop(true) end
        end)
        if not mf.boot then P("측정 시작 (2분) · 지금 M으로 지도를 여러 번 열었다 닫아 보세요 · 끝내려면 /르엘측정 한 번 더") end
    end
    -- 리로드 · 접속 순간 멈춤: 준비만 해 두면 다음 접속 때 처음부터 20초 재고 · 불러올 때 오래 걸린 애드온도
    local bev = CreateFrame("Frame")
    bev:RegisterEvent("PLAYER_LOGIN")
    bev:SetScript("OnEvent", function()
        if not (ns.db and ns.db.profBoot) or GetCVar("scriptProfile") ~= "1" then return end
        ns.db.profBoot = nil
        mf = mf or CreateFrame("Frame"); mf.boot = true; mf.limit = 20
        Start()
        C_Timer.After(20.5, function()
            -- 불러올 때부터 지금까지 일한 시간 (애드온별 합계)
            UpdateAddOnCPUUsage()
            local tot = {}
            for i = 1, #names do tot[#tot + 1] = { names[i], math.floor((GetAddOnCPUUsage(names[i]) or 0) + 0.5) } end
            table.sort(tot, function(a, b) return a[2] > b[2] end)
            local parts = {}
            for k = 1, math.min(6, #tot) do parts[k] = ("%s %dms"):format(tot[k][1], tot[k][2]) end
            ns.Print(L("접속 후 20초 동안 일한 시간 (많은 순서):") .. " " .. table.concat(parts, " · "))
            mf.boot, mf.limit = nil, nil
        end)
    end)
    SLASH_LEELPROF1 = "/르엘측정"; SLASH_LEELPROF2 = "/leelprof"
    SlashCmdList.LEELPROF = function()
        if hits then Stop(true) return end
        if GetCVar("scriptProfile") ~= "1" then
            SetCVar("scriptProfile", "1")
            if ns.db then ns.db.profBoot = true end
            P("측정 준비 완료 · /reload 하면 접속 순간부터 20초를 저절로 재서 채팅에 보여줘요 (지도 등 다른 멈춤은 그 뒤 /르엘측정)")
            return
        end
        if ns.db then ns.db.profBoot = true end   -- 다음 /reload 때도 접속 순간부터 재요
        Start()
    end
end
