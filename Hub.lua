-- LeelUI / Hub.lua
-- 르엘 허브: 르엘 애드온 전부를 한 창에서 켜고 끄고 설정 (미니맵 토끼 / /르엘)

local _, ns = ...
local C = ns.C

local W, H = 1000, 760  -- 왼쪽 목록 + 머리 · 탭 + 미리 보기 줄 + 두 칸 설정
local RAIL = 236
local HEAD = 54          -- 제목 줄 (로고 · 찾기 · 이동 모드)
local PHEAD = 84         -- 기능 머리 (아이콘 · 이름 · 설명 · 쓰기)
local TABH = 36
local TOP = HEAD + PHEAD + TABH
local FOOT = 58
local PVW = 0             -- (예전 오른쪽 칸) 이제 위쪽 줄
local PVH = 196           -- 위쪽 미리 보기 줄 높이

local function Print(msg) if ns.Print then ns.Print(msg) else print("|cfff2b3c2[르엘 UI]|r " .. msg) end end

----------------------------------------------------------------------
-- 애드온 정보 도우미
----------------------------------------------------------------------
local A = C_AddOns or {}
local function Exists(name)
    local ok, n = pcall(A.GetAddOnInfo or GetAddOnInfo, name)
    return ok and n ~= nil
end
local function Loaded(name)
    local f = A.IsAddOnLoaded or IsAddOnLoaded
    local ok, v = pcall(f, name)
    return ok and v and true or false
end
local function Enabled(name)
    local f = A.GetAddOnEnableState or GetAddOnEnableState
    local ok, v = pcall(f, name, UnitName("player"))
    if not ok then ok, v = pcall(f, UnitName("player"), name) end
    return ok and (tonumber(v) or 0) > 0
end
local function SetEnabled(name, on)
    local f = on and (A.EnableAddOn or EnableAddOn) or (A.DisableAddOn or DisableAddOn)
    pcall(f, name)
end
local function Version(name)
    local f = A.GetAddOnMetadata or GetAddOnMetadata
    local ok, v = pcall(f, name, "Version")
    return ok and v or ""
end
local function MExists(m) return m.builtin or Exists(m.key) end
local function MLoaded(m) return m.builtin or Loaded(m.key) end
local function MEnabled(m) return m.builtin or Enabled(m.key) end
local function MVersion(m) return Version(m.builtin and "LeelUI" or m.key) end

local function Slash(key, msg)
    local fn = SlashCmdList and SlashCmdList[key]
    if fn then fn(msg or "") return true end
end

StaticPopupDialogs["LEELUI_HUB_RELOAD"] = {
    text = "|cfff2b3c2르엘 허브|r\n다시 불러와야 적용돼요.\n지금 다시 불러올까요?",
    button1 = "다시 불러오기",
    button2 = "나중에",
    OnAccept = function() ReloadUI() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

----------------------------------------------------------------------
-- 모듈 목록 + 오른쪽 설정 내용
----------------------------------------------------------------------
local function MapDB() return LeelMapDB or {} end
local function MarkDB() return LeelMarkDB or {} end
local function SpotDB() return LeelSpotDB or {} end
local function GuideDB() return ForgLevelingDB or {} end
local function SpotRefresh() if LeelSpotAPI and LeelSpotAPI.Refresh then LeelSpotAPI.Refresh() end end
local function SpotSet(k, v)
    if not LeelSpotDB then return end
    LeelSpotDB[k] = v
    SpotRefresh()
end

-- 시전바 모양 고르기 (하나만 켜짐)
local function SetCastStyle(style)
    if (ns.db.castStyle or "bunny") == style then return end
    ns.db.castStyle = style
    StaticPopup_Show("LEELUI_HUB_RELOAD")
end

-- 화면 퀘스트 목록이 Leel Quest 인지 (아니면 Leel Quest 설정은 흐리게)
local function LQOn() return ns.QuestTrackerMode and ns.QuestTrackerMode() == "guide" end

local function PartyCells()
    if ns.ApplyPartyCells then ns:ApplyPartyCells() end
    if InCombatLockdown() then Print("전투가 끝나면 파티 프레임이 바뀌어요.") end
end
local function TSApply()
    if InCombatLockdown() then Print("전투가 끝나면 토템 세트가 바뀌어요.") end
    if ns.TotemSetApply then ns.TotemSetApply() end
    if ns.TotemSetPaint then ns.TotemSetPaint() end
end
local function TSSlot(k)
    return { t = "choice", label = k .. "번", hl = "s" .. k, hint = k == 1 and "가장 먼저 깔 토템" or nil,
        options = function() return ns.TotemOptions and ns.TotemOptions() or {} end,
        get = function()
            local t = ns.TotemSetDB and ns.TotemSetDB()
            local s = t and t.sets[t.cur]
            return s and s[k] or 0
        end,
        set = function(v)
            local t = ns.TotemSetDB()
            t.sets[t.cur] = t.sets[t.cur] or {}
            local s = t.sets[t.cur]
            for i = 1, 4 do s[i] = s[i] or 0 end
            s[k] = v
            TSApply()
        end }
end

-- 허브 → 이동 모드로 (그 창 크기 줄까지 바로)
function ns.HubMoveOpen(getMover, label, title)
    if InCombatLockdown() then Print("전투가 끝나면 할 수 있어요.") return end
    local h = _G.LeelUI_Hub
    if h and h:IsShown() then h:Hide() end
    if not ns.moving and ns.SetMoveMode then ns:SetMoveMode(true) end
    if not getMover then return end
    C_Timer.After(0.15, function()
        local mv = getMover()
        if mv and mv:IsShown() and ns.MoveSelect then ns.MoveSelect(mv, label, title) end
    end)
end

local MODULES = {
    {
        key = "LeelUI", title = "Leel HUD", sub = "내 체력 · 대상 · 거리", icon = "hb_ui",
        always = true, tabs = true, sideview = true,   -- 오른쪽 설명 칸은 뺐어요 (다른 탭과 같게)
        onoff = { reload = true, get = function() return not ns.db.hudOff end,
                  set = function(v) ns.db.hudOff = not v end },
        desc = "내 체력 · 대상 · 거리를 화면 위에서 한눈에. 부분마다 따로 맞춰요.\n크기 · 자리는 이동 모드에서 바꿔요.",
        items = {
            -- 크기 줄 (이동 모드에서만 · 허브엔 안 보여요 · 이동 모드가 이 이름으로 찾아요)
            { moveOnly = true, t = "slider", label = "Leel HUD 크기", min = 50, max = 150,
              get = function() return math.floor((ns.db.scale or 0.7) * 100 + 0.5) end,
              set = function(v) ns:SetHudScale(v / 100); if InCombatLockdown() then Print("전투가 끝나면 HUD 크기가 바뀌어요.") end end },
            { moveOnly = true, t = "slider", label = "내 창 크기", min = 50, max = 160,
              get = function() return ns.db.partScale and ns.db.partScale.player or 100 end,
              set = function(v) if ns.SetHudPartScale then ns.SetHudPartScale("player", v) end end },
            { moveOnly = true, t = "slider", label = "가운데 크기", min = 50, max = 160,
              get = function() return ns.db.partScale and ns.db.partScale.center or 100 end,
              set = function(v) if ns.SetHudPartScale then ns.SetHudPartScale("center", v) end end },
            { moveOnly = true, t = "slider", label = "대상 창 크기", min = 50, max = 160,
              get = function() return ns.db.partScale and ns.db.partScale.target or 100 end,
              set = function(v) if ns.SetHudPartScale then ns.SetHudPartScale("target", v) end end },
            { moveOnly = true, t = "slider", label = "대상의 대상 크기", min = 60, max = 160,
              get = function() return tonumber(ns.db.totScale) or 100 end,
              set = function(v) if ns.SetToTScale then ns.SetToTScale(v) else ns.db.totScale = v end end },
            { moveOnly = true, t = "slider", label = "펫 창 크기 (사냥꾼 · 흑마법사)", min = 80, max = 160,
              get = function() return tonumber(ns.db.petScale) or 130 end,
              set = function(v) if ns.SetPetScale then ns.SetPetScale(v) else ns.db.petScale = v end end },

            -- 탭마다: 미리 보기는 그 부분만 (pv) · 오른쪽 '설정 설명' (more) · 크기가 늘 첫 줄
            { t = "header", label = "내 창", pv = "player",
              more = "내 초상화 · 이름 · 체력 · 자원 줄이에요.\n줄에 마우스를 올리면 여기에 설명이 나와요." },
            { t = "size", label = "내 창 크기", sl = "내 창 크기", title = "내 창",
              mover = function() return ns.HudPartMover and ns.HudPartMover("player") end,
              get = function() return ns.db.partScale and ns.db.partScale.player or 100 end,
              more = "내 창만 크게 · 작게 (HUD 전체 크기에 곱해요).\n이동 모드에서 내 창 테두리를 누르면 위에 크기 줄이 떠요. 휠로도 돼요." },
            { t = "sub", label = "초상화" },
            { t = "toggle", label = "초상화 사용", hint = "왼쪽 얼굴 그림", hl = "por",
              get = function() return not (ns.db.hudText and ns.db.hudText.player and ns.db.hudText.player.porOff) end,
              set = function(v) if ns.SetHudText then ns.SetHudText("player", "porOff", not v) end end,
              more = "내 창 왼쪽 초상화를 쓰거나 안 써요. 직업 아이콘은 체력 바 앞에 그대로 있어요.\n안 써도 이름 · 체력 바 자리는 그대로예요." },
            { t = "seg", label = "초상화 그림", hint = "내 얼굴 대신 르엘 토끼", hl = "por",
              options = { { "캐릭터 얼굴", "face" }, { "르엘 토끼", "bunny" } },
              get = function() return (ns.db.hudText and ns.db.hudText.player and ns.db.hudText.player.porFace) or "face" end,
              set = function(v) if ns.SetHudText then ns.SetHudText("player", "porFace", v) end end,
              more = "르엘 토끼 = 소개 그림의 분홍 토끼가 내 초상화로 · 쓰러지면 회색이 돼요." },
            { t = "slider", label = "초상화 크기", min = 50, max = 150, step = 5, fmt = "%d%%", noPeek = true, hl = "por",
              get = function() return (ns.db.hudText and ns.db.hudText.player and tonumber(ns.db.hudText.player.porScale)) or 100 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("player", "porScale", v) end end,
              more = "초상화만 크게 · 작게. 100% = 처음 크기." },
            { t = "seg", label = "초상화 테두리", hint = "둘레 색", hl = "por",
              options = { { "분홍", "pink" }, { "직업 색", "class" }, { "끔", "off" } },
              get = function() return (ns.db.hudText and ns.db.hudText.player and ns.db.hudText.player.porEdge) or "pink" end,
              set = function(v) if ns.SetHudText then ns.SetHudText("player", "porEdge", v) end end,
              more = "초상화 둘레 테 색. 분홍 = 르엘 · 직업 색 = 내 직업 색 · 끔 = 테 없이." },
            { t = "sub", label = "이름 줄" },
            { t = "slider", label = "이름 글씨", min = -4, max = 12, step = 1, fmt = "%+d", noPeek = true, hl = "name",
              get = function() return ns.HudTextAdd and ns.HudTextAdd("player", "name") or 0 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("player", "name", v) end end,
              more = "내 창 이름 글씨 크기만 키우거나 줄여요. 커지면 이름 줄이 조금 위로 올라가요.\n0 = 처음 크기 · 휠 = 1씩." },
            { t = "slider", label = "레벨 글씨", min = -4, max = 12, step = 1, fmt = "%+d", noPeek = true, hl = "lv",
              get = function() return ns.HudTextAdd and ns.HudTextAdd("player", "lv") or 0 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("player", "lv", v) end end,
              more = "내 창 LV 43 숫자 크기.\n0 = 처음 크기 · 휠 = 1씩." },
            { t = "sub", label = "체력 바" },
            { t = "slider", label = "체력 바 두께", min = -4, max = 12, step = 1, fmt = "%+d", noPeek = true, hl = "bar",
              get = function() return ns.HudTextAdd and ns.HudTextAdd("player", "bar") or 0 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("player", "bar", v) end end,
              more = "내 창 체력 바를 두껍게 · 얇게. 위아래로 반씩 늘어나요.\n0 = 처음 크기 · 휠 = 1씩." },
            { t = "slider", label = "체력 숫자 글씨", min = -4, max = 12, step = 1, fmt = "%+d", noPeek = true, hl = "hp",
              get = function() return ns.HudTextAdd and ns.HudTextAdd("player", "hp") or 0 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("player", "hp", v) end end,
              more = "내 창 체력 바 안 큰 숫자(1609) 크기.\n0 = 처음 크기 · 휠 = 1씩." },
            { t = "toggle", label = "체력 숫자 보이기", hint = "체력 바 안 큰 숫자", hl = "hp",
              get = function() return ns.HudTextShow and ns.HudTextShow("player", "showHp") end,
              set = function(v) if ns.SetHudText then ns.SetHudText("player", "showHp", v and true or false) end end,
              more = "내 창 체력 바 안 큰 숫자(1609)를 보이거나 숨겨요." },
            { t = "slider", label = "% 글씨", min = -4, max = 12, step = 1, fmt = "%+d", noPeek = true, hl = "pct",
              get = function() return ns.HudTextAdd and ns.HudTextAdd("player", "pct") or 0 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("player", "pct", v) end end,
              more = "내 창 체력 바 오른쪽 %(100%) 크기.\n0 = 처음 크기 · 휠 = 1씩." },
            { t = "toggle", label = "% 보이기", hint = "체력 바 오른쪽 %", hl = "pct",
              get = function() return ns.HudTextShow and ns.HudTextShow("player", "showPct") end,
              set = function(v) if ns.SetHudText then ns.SetHudText("player", "showPct", v and true or false) end end,
              more = "내 창 체력 바 오른쪽 %를 보이거나 숨겨요." },
            { t = "sub", label = "마나 바" },
            { t = "slider", label = "마나 바 두께", min = 2, max = 16, step = 1, fmt = "%d", noPeek = true, hl = "pow",
              get = function() return ns.HudPow and ns.HudPow("player", "powH") or 6 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("player", "powH", v) end end,
              more = "내 창 마나 · 기력 · 분노 바 두께. 처음 6." },
            { t = "slider", label = "마나 바 길이", min = 50, max = 150, step = 5, fmt = "%d%%", noPeek = true, hl = "pow",
              get = function() return ns.HudPow and ns.HudPow("player", "powW") or 100 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("player", "powW", v) end end,
              more = "내 창 마나 바 길이. 100% = 처음 길이." },
            { t = "toggle", label = "마나 바 눈금", hint = "바를 다섯 칸으로 나누는 선", hl = "pow",
              get = function() return ns.HudPow and ns.HudPow("player", "powTicks") end,
              set = function(v) if ns.SetHudText then ns.SetHudText("player", "powTicks", v and true or false) end end,
              more = "마나 바를 20%씩 다섯 칸으로 나누는 얇은 선이에요." },
            { t = "toggle", label = "마나 바 보이기", hint = "줄만 숨기고 숫자는 따로", hl = "pow",
              get = function() return ns.HudPow and ns.HudPow("player", "showPow") end,
              set = function(v) if ns.SetHudText then ns.SetHudText("player", "showPow", v and true or false) end end,
              more = "내 창 마나 바(줄)를 보이거나 숨겨요. 숫자는 아래 '마나 숫자 보이기'로 따로." },
            { t = "slider", label = "마나 숫자 글씨", min = -4, max = 12, step = 1, fmt = "%+d", noPeek = true, hl = "sub",
              get = function() return ns.HudTextAdd and ns.HudTextAdd("player", "sub") or 0 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("player", "sub", v) end end,
              more = "내 창 마나 · 기력 · 분노 숫자와 글씨 크기.\n0 = 처음 크기 · 휠 = 1씩." },
            { t = "toggle", label = "마나 숫자 보이기", hint = "바 옆 숫자", hl = "powtx",
              get = function() return ns.HudPow and ns.HudPow("player", "showPowTx") end,
              set = function(v) if ns.SetHudText then ns.SetHudText("player", "showPowTx", v and true or false) end end,
              more = "내 창 마나 바 옆 숫자를 보이거나 숨겨요." },
            { t = "header", label = "가운데", pv = "center",
              more = "내 창과 대상 창 사이 대상과 거리 숫자와 전투 중 효과예요." },
            { t = "size", label = "가운데 크기", sl = "가운데 크기", title = "가운데",
              mover = function() return ns.HudPartMover and ns.HudPartMover("center") end,
              get = function() return ns.db.partScale and ns.db.partScale.center or 100 end,
              more = "토끼 귀 · 거리 숫자만 크게 · 작게.\n이동 모드에서 가운데 테두리를 누르면 크기 줄이 떠요." },
            { t = "toggle", label = "가운데 사용", hint = "끄면 내 창 · 대상 창만", hl = "part",
              get = function() return not (ns.db.ctr and ns.db.ctr.numOff) end,
              set = function(v) if ns.SetCtr then ns.SetCtr("numOff", not v) end end,
              more = "끄면 가운데 숫자 · 전투 효과가 모두 사라져요. 내 창과 대상 창은 그대로." },
            { t = "slider", label = "숫자 글씨", min = -20, max = 20, step = 1, fmt = "%+d", noPeek = true, hl = "num",
              get = function() return tonumber(ns.db.ctr and ns.db.ctr.numAdd) or 0 end,
              set = function(v) if ns.SetCtr then ns.SetCtr("numAdd", v) end end,
              more = "가운데 큰 숫자(5m · 0:42) 크기. 0 = 처음 크기." },
            { t = "toggle", label = "아래 글씨", hint = "대상과 거리 · 근접 거리", hl = "csub",
              get = function() return not (ns.db.ctr and ns.db.ctr.subOff) end,
              set = function(v) if ns.SetCtr then ns.SetCtr("subOff", not v) end end,
              more = "숫자 아래 작은 글씨를 보이거나 숨겨요." },
            { t = "toggle", label = "거리 점", hint = "멀수록 하나씩 차요", hl = "dots",
              get = function() return not (ns.db.ctr and ns.db.ctr.dotsOff) end,
              set = function(v) if ns.SetCtr then ns.SetCtr("dotsOff", not v) end end,
              more = "멀수록 하나씩 차는 점 네 개. 숫자 아래 작은 글씨 위에 있어요." },
            { t = "seg", label = "거리 색", hint = "가까우면 초록 · 멀면 빨강", hl = "num",
              options = { { "색깔로", "color" }, { "흰색", "white" } },
              get = function() return (ns.db.ctr and ns.db.ctr.white) and "white" or "color" end,
              set = function(v) if ns.SetCtr then ns.SetCtr("white", v == "white") end end,
              more = "색깔로 = 거리마다 숫자 색이 바뀌어요 · 흰색 = 늘 흰 숫자 (점은 분홍)." },
            { pvFight = true, dep = function() return not (ns.db.ctr and ns.db.ctr.numOff) end, t = "toggle", label = "번쩍", hint = "시작할 때 한 번 빛", hl = "fx",
              get = function() return not (ns.db.ctr and ns.db.ctr.flashOff) end,
              set = function(v) if ns.SetCtr then ns.SetCtr("flashOff", not v) end end,
              more = "전투가 시작되는 순간 가운데가 한 번 번쩍 빛나요." },
            { pvFight = true, dep = function() return not (ns.db.ctr and ns.db.ctr.numOff) end, t = "toggle", label = "노란 번개", hint = "귀 옆 빠직빠직", hl = "fx",
              get = function() return not (ns.db.ctr and ns.db.ctr.boltOff) end,
              set = function(v) if ns.SetCtr then ns.SetCtr("boltOff", not v) end end,
              more = "각성 중 귀와 숫자 옆으로 노란 번개가 튀어요." },
            { pvFight = true, dep = function() return not (ns.db.ctr and ns.db.ctr.numOff) end, t = "toggle", label = "솟는 빛줄기", hint = "숫자 뒤 금빛 줄기", hl = "fx",
              get = function() return not (ns.db.ctr and ns.db.ctr.streakOff) end,
              set = function(v) if ns.SetCtr then ns.SetCtr("streakOff", not v) end end,
              more = "각성 중 숫자 뒤로 금빛 줄기가 위로 솟아요." },
            { pvFight = true, t = "seg", label = "효과 세기", hint = "번개 · 빛 밝기", hl = "fx",
              options = { { "은은", "soft" }, { "보통", "normal" }, { "화려", "strong" } },
              get = function() return (ns.db.ctr and ns.db.ctr.fx) or "normal" end,
              set = function(v) if ns.SetCtr then ns.SetCtr("fx", v) end end,
              more = "은은 = 빛 · 번개를 흐리게 · 보통 = 처음 · 화려 = 번개가 두 배로 자주." },
            { t = "seg", label = "보일 때", hint = "가운데 전체", hl = "part",
              options = { { "늘", "always" }, { "대상 있을 때", "target" }, { "전투 중만", "combat" } },
              get = function() return (ns.db.ctr and ns.db.ctr.vis) or "target" end,
              set = function(v) if ns.SetCtr then ns.SetCtr("vis", v) end end,
              more = "늘 = 대상이 없어도 가운데가 떠 있어요 · 대상 있을 때 = 처음 · 전투 중만 = 싸울 때만." },
            { t = "header", label = "대상 창", pv = "target",
              more = "내가 고른 대상의 초상화 · 이름 · 체력 · 마나예요." },
            { t = "size", label = "대상 창 크기", sl = "대상 창 크기", title = "대상 창",
              mover = function() return ns.HudPartMover and ns.HudPartMover("target") end,
              get = function() return ns.db.partScale and ns.db.partScale.target or 100 end,
              more = "대상 창만 크게 · 작게. 밑의 대상의 대상도 같이 커져요.\n이동 모드에서 대상 창 테두리를 누르면 크기 줄이 떠요." },
            -- ② 무엇을 보일까
            { sec = 2, t = "toggle", label = "내 디버프", hint = "대상에 건 내 주문 · 남은 시간 링", hl = "deb",
              get = function() return not (ns.TgtOpt and ns.TgtOpt("debOff")) end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("debOff", not v) end end,
              more = "대상에 내가 건 디버프를 체력 바 아래 동그란 아이콘으로. 분홍 링 = 남은 시간." },
            { sec = 2, t = "toggle", label = "대상 버프 줄", hint = "디버프 아래 민트 링", hl = "buf",
              get = function() return not (ns.TgtOpt and ns.TgtOpt("buffOff")) end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("buffOff", not v) end end,
              more = "대상에 걸린 버프. 적이면 해제할 버프를, 아군이면 내가 줄 버프를 확인해요." },
            { sec = 2, pvPeek = "thr", t = "toggle", label = "위협 표시", hint = "어그로를 잡으면 초상화 둘레 빨간 빛", hl = "thr",
              get = function() return ns.TgtOpt and ns.TgtOpt("threatOn") and true or false end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("threatOn", v and true or false) end end,
              more = "대상이 나를 노리고 있으면(어그로) 초상화 둘레가 빨갛게 빛나요." },
            { sec = 2, pvPeek = "combo", t = "toggle", label = "연계 점수 칸", hint = "도적 · 표범 드루 · 체력 바 밑 기울어진 칸", hl = "combo",
              get = function() return not (ns.TgtOpt and ns.TgtOpt("comboOff")) end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("comboOff", not v) end end,
              more = "도적 · 표범 변신 드루이드만 보여요. 체력 바 바로 밑 기울어진 칸 5개가 대상 쪽부터 분홍으로 차요.\n다른 직업이면 자리도 안 차지해요." },
            -- ③ 모양: 초상화
            { t = "sub", label = "초상화" },
            { t = "toggle", label = "초상화 사용", hint = "오른쪽 얼굴 그림", hl = "por",
              get = function() return not (ns.db.hudText and ns.db.hudText.target and ns.db.hudText.target.porOff) end,
              set = function(v) if ns.SetHudText then ns.SetHudText("target", "porOff", not v) end end,
              more = "대상 창 오른쪽 초상화를 쓰거나 안 써요. 안 써도 이름 · 체력 바 자리는 그대로예요." },
            { t = "slider", label = "초상화 크기", min = 50, max = 150, step = 5, fmt = "%d%%", noPeek = true, hl = "por",
              get = function() return (ns.db.hudText and ns.db.hudText.target and tonumber(ns.db.hudText.target.porScale)) or 100 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("target", "porScale", v) end end,
              more = "초상화만 크게 · 작게. 100% = 처음 크기." },
            { t = "seg", label = "초상화 테두리", hint = "둘레 색", hl = "por",
              options = { { "분홍", "pink" }, { "직업 색", "class" }, { "끔", "off" } },
              get = function() return (ns.db.hudText and ns.db.hudText.target and ns.db.hudText.target.porEdge) or "pink" end,
              set = function(v) if ns.SetHudText then ns.SetHudText("target", "porEdge", v) end end,
              more = "초상화 둘레 테 색. 직업 색 = 플레이어일 때 그 직업 색 (몹이면 분홍)." },
            { pvPeek = "rank", t = "seg", label = "등급 테두리", hint = "정예 = 금테 · 희귀 = 은테", hl = "por",
              options = { { "끔", "off" }, { "금 · 은", "on" } },
              get = function() return (ns.TgtOpt and ns.TgtOpt("rankOn")) and "on" or "off" end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("rankOn", v == "on") end end,
              more = "정예 · 보스면 초상화 테가 금색, 희귀면 은색이에요. 보통 몹은 위 '초상화 테두리' 색." },
            { t = "sub", label = "이름 줄" },
            { t = "slider", label = "이름 글씨", min = -4, max = 12, step = 1, fmt = "%+d", noPeek = true, hl = "name",
              get = function() return ns.HudTextAdd and ns.HudTextAdd("target", "name") or 0 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("target", "name", v) end end,
              more = "대상 창 이름 글씨 크기만 키우거나 줄여요. 커지면 이름 줄이 조금 위로 올라가요.\n0 = 처음 크기 · 휠 = 1씩." },
            { t = "slider", label = "레벨 글씨", min = -4, max = 12, step = 1, fmt = "%+d", noPeek = true, hl = "lv",
              get = function() return ns.HudTextAdd and ns.HudTextAdd("target", "lv") or 0 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("target", "lv", v) end end,
              more = "대상 창 LV 43 숫자 크기.\n0 = 처음 크기 · 휠 = 1씩." },
            { t = "seg", label = "이름 색", hint = "플레이어는 직업 색", hl = "name",
              options = { { "흰색", "white" }, { "관계 색", "react" } },
              get = function() return ns.TgtOpt and ns.TgtOpt("nameCol") or "white" end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("nameCol", v) end end,
              more = "관계 색 = 적 빨강 · 중립 노랑 · 아군 초록. 플레이어는 늘 직업 색이에요." },
            { t = "seg", label = "레벨 색", hint = "나보다 높을수록 빨강", hl = "lv",
              options = { { "난이도", "diff" }, { "흰색", "white" } },
              get = function() return ns.TgtOpt and ns.TgtOpt("lvCol") or "diff" end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("lvCol", v) end end,
              more = "난이도 = 회색 · 초록 · 노랑 · 주황 · 빨강 (게임과 같은 색)." },
            { t = "sub", label = "체력 바" },
            { t = "slider", label = "체력 바 두께", min = -4, max = 12, step = 1, fmt = "%+d", noPeek = true, hl = "bar",
              get = function() return ns.HudTextAdd and ns.HudTextAdd("target", "bar") or 0 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("target", "bar", v) end end,
              more = "대상 창 체력 바를 두껍게 · 얇게. 위아래로 반씩 늘어나요.\n0 = 처음 크기 · 휠 = 1씩." },
            { t = "slider", label = "체력 숫자 글씨", min = -4, max = 12, step = 1, fmt = "%+d", noPeek = true, hl = "hp",
              get = function() return ns.HudTextAdd and ns.HudTextAdd("target", "hp") or 0 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("target", "hp", v) end end,
              more = "대상 창 체력 바 안 큰 숫자(1609) 크기.\n0 = 처음 크기 · 휠 = 1씩." },
            { t = "toggle", label = "체력 숫자 보이기", hint = "체력 바 안 큰 숫자", hl = "hp",
              get = function() return ns.HudTextShow and ns.HudTextShow("target", "showHp") end,
              set = function(v) if ns.SetHudText then ns.SetHudText("target", "showHp", v and true or false) end end,
              more = "대상 창 체력 바 안 큰 숫자(1609)를 보이거나 숨겨요." },
            { t = "slider", label = "% 글씨", min = -4, max = 12, step = 1, fmt = "%+d", noPeek = true, hl = "pct",
              get = function() return ns.HudTextAdd and ns.HudTextAdd("target", "pct") or 0 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("target", "pct", v) end end,
              more = "대상 창 체력 바 오른쪽 %(100%) 크기.\n0 = 처음 크기 · 휠 = 1씩." },
            { t = "toggle", label = "% 보이기", hint = "체력 바 오른쪽 %", hl = "pct",
              get = function() return ns.HudTextShow and ns.HudTextShow("target", "showPct") end,
              set = function(v) if ns.SetHudText then ns.SetHudText("target", "showPct", v and true or false) end end,
              more = "대상 창 체력 바 오른쪽 %를 보이거나 숨겨요." },
            { t = "sub", label = "마나 줄" },
            { t = "toggle", label = "대상 마나 줄", hint = "대상 체력 바 아래 파란 줄 · 숫자", hl = "sub",
              get = function() return not ns.db.tPowerOff end,
              set = function(v) ns.db.tPowerOff = not v end,
              more = "대상의 마나 · 기력 · 분노 줄이에요. 자원이 없는 몹은 원래 안 보여요." },
            { t = "slider", label = "마나 바 두께", min = 2, max = 12, step = 1, fmt = "%d", noPeek = true, hl = "pow",
              get = function() return ns.HudPow and ns.HudPow("target", "powH") or 4 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("target", "powH", v) end end,
              more = "대상 창 마나 · 기력 · 분노 바 두께. 처음 4." },
            { t = "slider", label = "마나 바 길이", min = 50, max = 150, step = 5, fmt = "%d%%", noPeek = true, hl = "pow",
              get = function() return ns.HudPow and ns.HudPow("target", "powW") or 100 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("target", "powW", v) end end,
              more = "대상 창 마나 바 길이. 100% = 처음 길이." },
            { t = "slider", label = "마나 숫자 글씨", min = -4, max = 12, step = 1, fmt = "%+d", noPeek = true, hl = "sub",
              get = function() return ns.HudTextAdd and ns.HudTextAdd("target", "sub") or 0 end,
              set = function(v) if ns.SetHudText then ns.SetHudText("target", "sub", v) end end,
              more = "대상 창 마나 · 기력 · 분노 숫자와 글씨 크기.\n0 = 처음 크기 · 휠 = 1씩." },
            { t = "toggle", label = "마나 숫자 보이기", hint = "바 옆 숫자", hl = "powtx",
              get = function() return ns.HudPow and ns.HudPow("target", "showPowTx") end,
              set = function(v) if ns.SetHudText then ns.SetHudText("target", "showPowTx", v and true or false) end end,
              more = "대상 창 마나 바 옆 숫자를 보이거나 숨겨요." },
            { t = "sub", label = "연계 점수 칸" },
            { pvPeek = "combo", t = "slider", label = "칸 두께", min = 4, max = 14, step = 1, fmt = "%d", noPeek = true, hl = "combo",
              get = function() return ns.TgtOpt and tonumber(ns.TgtOpt("comboH")) or 7 end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("comboH", v) end end,
              more = "연계 점수 칸 두께. 7 = 처음." },
            { pvPeek = "combo", t = "toggle", label = "다 차면 빨갛게", hint = "5점이면 빨강 + 숨쉬는 빛", hl = "combo",
              get = function() return not (ns.TgtOpt and ns.TgtOpt("comboRedOff")) end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("comboRedOff", not v) end end,
              more = "5점이 다 차면 칸이 빨갛게 바뀌고 둘레가 숨쉬듯 빛나요." },
            { pvPeek = "combo", t = "toggle", label = "숫자 붙이기", hint = "칸 왼쪽 끝에 점수", hl = "combo",
              get = function() return ns.TgtOpt and ns.TgtOpt("comboNum") and true or false end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("comboNum", v and true or false) end end,
              more = "칸 왼쪽 끝에 지금 점수(3)를 숫자로." },
            { sec = 4, pvPeek = "combo", t = "seg", label = "연계 점수 칸 보일 때", hl = "combo",
              options = { { "점수가 있을 때", "pts" }, { "늘", "all" } },
              get = function() return (ns.TgtOpt and ns.TgtOpt("comboShow0")) and "all" or "pts" end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("comboShow0", v == "all") end end,
              more = "점수가 있을 때 = 0점이면 칸을 숨겨요 (첫 점수가 쌓이면 나타나고 마나 줄 · 디버프가 한 칸 내려가요).\n늘 = 0점이어도 빈 칸을 보여줘요 (자리가 안 움직여요)." },
            { t = "sub", label = "디버프 · 버프" },
            { t = "slider", label = "디버프 크기", min = 60, max = 150, step = 5, fmt = "%d%%", noPeek = true, hl = "deb",
              get = function() return ns.TgtOpt and tonumber(ns.TgtOpt("debScale")) or 100 end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("debScale", v) end end,
              more = "대상 창 아래 디버프 · 버프 아이콘 크기. 100% = 처음 크기." },
            -- ④ 언제
            { sec = 4, pvDead = true, t = "seg", label = "죽은 대상", hint = "초상화 · 바", hl = "por",
              options = { { "회색으로", "grey" }, { "그대로", "keep" } },
              get = function() return (ns.TgtOpt and ns.TgtOpt("deadKeep")) and "keep" or "grey" end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("deadKeep", v == "keep") end end,
              more = "대상이 죽으면 초상화를 회색 · 바를 흐리게 + '쓰러짐'. 그대로 = 바꾸지 않아요." },

            { t = "header", label = "대상의 대상", pv = "tot",
              more = "대상 초상화 밑 작은 알약. 대상이 누구를 노리는지 보여요. 누르면 그 대상으로 바뀌어요." },
            { t = "size", label = "대상의 대상 크기", sl = "대상의 대상 크기", title = "대상의 대상",
              mover = function() local f = _G.LeelUI_targettarget; return f and f.leelSizeOnly end,
              get = function() return tonumber(ns.db.totScale) or 100 end,
              more = "작은 알약만 크게 · 작게. 자리는 대상 초상화 밑 그대로예요." },
            { t = "toggle", label = "대상의 대상 보이기", hint = "직업색 띠 · 이름 · 체력 · 클릭 = 그 대상",
              get = function() return ns.db.tot ~= false end,
              set = function(v)
                  if ns.SetToT then ns.SetToT(v) else ns.db.tot = v end
                  if InCombatLockdown() then Print("전투가 끝나면 바뀌어요.") end
              end,
              more = "왼쪽 띠 = 플레이어면 직업 색, 몹 · NPC면 분홍.\n오른쪽 % = 그 대상의 체력." },
            { sec = 2, t = "toggle", label = "체력 %", hint = "알약 오른쪽 100%", hl = "part",
              get = function() return not (ns.TgtOpt and ns.TgtOpt("totPctOff")) end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("totPctOff", not v) end end,
              more = "알약 오른쪽 체력 % 숫자를 보이거나 숨겨요." },
            { sec = 2, t = "toggle", label = "체력 줄", hint = "알약 아래 얇은 줄", hl = "part",
              get = function() return not (ns.TgtOpt and ns.TgtOpt("totHpOff")) end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("totHpOff", not v) end end,
              more = "알약 바닥 얇은 체력 줄을 보이거나 숨겨요." },
            { sec = 2, pvPeek = "totme", t = "toggle", label = "나를 노리면 강조", hint = "빨간 테 + \"나\"", hl = "part",
              get = function() return ns.TgtOpt and ns.TgtOpt("totMeOn") and true or false end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("totMeOn", v and true or false) end end,
              more = "대상이 나를 노리면 알약 테가 빨갛게 + 이름 옆에 \"나\". 몹이 나한테 오는지 바로 보여요." },
            { t = "slider", label = "이름 글씨", min = -6, max = 8, step = 1, fmt = "%+d", noPeek = true, hl = "part",
              get = function() return ns.TgtOpt and tonumber(ns.TgtOpt("totName")) or 0 end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("totName", v) end end,
              more = "알약 이름 글씨 크기. 0 = 처음 크기." },
            { t = "slider", label = "알약 길이", min = 60, max = 200, step = 5, fmt = "%d%%", noPeek = true, hl = "part",
              get = function() return ns.TgtOpt and tonumber(ns.TgtOpt("totW")) or 100 end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("totW", v) end end,
              more = "알약을 왼쪽으로 늘려요. 긴 이름도 안 잘리게. 전투 중엔 끝나고 바뀌어요." },
            { t = "seg", label = "배경 색", hint = "알약 바탕", hl = "part",
              options = { { "어둡게", "dark" }, { "분홍", "pink" }, { "직업 색", "class" }, { "반투명", "clear" } },
              get = function() return ns.TgtOpt and ns.TgtOpt("totBg") or "dark" end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("totBg", v) end end,
              more = "어둡게 = 처음 · 분홍 = 진한 분홍 바탕 · 직업 색 = 그 직업 색을 어둡게 (몹은 분홍) · 반투명 = 뒤가 비쳐요." },
            { t = "seg", label = "왼쪽 띠 색", hint = "몹은 늘 분홍", hl = "part",
              options = { { "직업 색", "class" }, { "분홍", "pink" } },
              get = function() return ns.TgtOpt and ns.TgtOpt("totStripe") or "class" end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("totStripe", v) end end,
              more = "직업 색 = 플레이어면 그 직업 색 · 분홍 = 늘 분홍." },
            { sec = 4, t = "seg", label = "보일 때", hint = "알약", hl = "part",
              options = { { "늘", "all" }, { "전투 중만", "combat" } },
              get = function() return ns.TgtOpt and ns.TgtOpt("totVis") or "all" end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("totVis", v) end end,
              more = "전투 중만 = 싸울 때만 알약이 보여요 (안 보일 때도 그 자리는 클릭돼요)." },
            { sec = 4, t = "seg", label = "대상이 나를 노릴 때", hint = "알약", hl = "part",
              options = { { "보이기", "show" }, { "숨기기", "hide" } },
              get = function() return (ns.TgtOpt and ns.TgtOpt("totHideMe")) and "hide" or "show" end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("totHideMe", v == "hide") end end,
              more = "숨기기 = 대상의 대상이 나면 알약을 감춰요 (솔로 사냥 땐 늘 나라서).\n'나를 노리면 강조'를 켜 두면 강조가 먼저예요." },

            { t = "header", label = "펫", pv = "pet",
              more = "사냥꾼 · 흑마법사 펫 창이에요. 내 창 아래에 붙어 다녀요." },
            { t = "size", label = "펫 창 크기", sl = "펫 창 크기 (사냥꾼 · 흑마법사)", title = "펫 창",
              mover = function() local f = ns.hudFrames and ns.hudFrames.pet; return f and f.leelSizeOnly end,
              get = function() return tonumber(ns.db.petScale) or 130 end,
              more = "펫 창만 크게 · 작게 (처음 130%). 자리는 내 창 아래 그대로예요." },
            { sec = 2, pvPeek = "mood", t = "toggle", label = "만족도 얼굴", hint = "사냥꾼 펫 · 초상화 아래 얼굴",
              get = function() return not ns.db.petMoodOff end,
              set = function(v) ns.db.petMoodOff = not v; if ns.HudPetRefresh then ns.HudPetRefresh() end end,
              more = "사냥꾼 펫의 만족도를 초상화 아래 얼굴로 (행복 · 보통 · 불만). 불만이면 빨간 빛이 숨쉬듯 깜빡여요." },
            { sec = 2, t = "toggle", label = "상태 칩", hint = "공격 중 · 맞는 중 · 쓰러짐", hl = "part",
              get = function() return not (ns.PetOpt and ns.PetOpt("chipOff")) end,
              set = function(v) if ns.SetPetOpt then ns.SetPetOpt("chipOff", not v) end end,
              more = "이름 옆 작은 칩. 공격 중 = 분홍 · 맞는 중 = 빨강 · 쓰러짐 = 회색." },
            { sec = 2, t = "toggle", label = "집중 · 마나 바", hint = "체력 바 아래 줄", hl = "part",
              get = function() return not (ns.PetOpt and ns.PetOpt("focusOff")) end,
              set = function(v) if ns.SetPetOpt then ns.SetPetOpt("focusOff", not v) end end,
              more = "체력 바 아래 얇은 집중(사냥꾼) · 마나(흑마법사 펫) 줄." },
            { sec = 2, t = "toggle", label = "펫의 대상", hint = "펫이 때리는 몹 이름", hl = "part",
              get = function() return ns.PetOpt and ns.PetOpt("tgtOn") and true or false end,
              set = function(v) if ns.SetPetOpt then ns.SetPetOpt("tgtOn", v and true or false) end end,
              more = "펫이 지금 노리는 대상 이름을 작게. 엉뚱한 몹을 때리는지 바로 보여요." },
            { t = "sub", label = "초상화" },
            { t = "toggle", label = "초상화 사용", hint = "왼쪽 얼굴 그림", hl = "part",
              get = function() return not (ns.PetOpt and ns.PetOpt("porOff")) end,
              set = function(v) if ns.SetPetOpt then ns.SetPetOpt("porOff", not v) end end,
              more = "펫 초상화를 쓰거나 안 써요. 안 써도 자리는 그대로예요." },
            { t = "seg", label = "초상화 테두리", hint = "둘레 색", hl = "part",
              options = { { "상태 색", "state" }, { "분홍", "pink" }, { "끔", "off" } },
              get = function() return ns.PetOpt and ns.PetOpt("porEdge") or "state" end,
              set = function(v) if ns.SetPetOpt then ns.SetPetOpt("porEdge", v) end end,
              more = "상태 색 = 만족도 · 맞는 중이면 빨강 (처음) · 분홍 = 늘 분홍 · 끔 = 테 없이." },
            { t = "sub", label = "이름 줄" },
            { t = "slider", label = "펫 이름 글씨", min = -4, max = 10, step = 1, fmt = "%+d", noPeek = true, hl = "part",
              get = function() return ns.PetOpt and tonumber(ns.PetOpt("nameAdd")) or 0 end,
              set = function(v) if ns.SetPetOpt then ns.SetPetOpt("nameAdd", v) end end,
              more = "펫 이름 글씨 크기. 0 = 처음 크기." },
            { t = "slider", label = "펫 레벨 글씨", min = -4, max = 10, step = 1, fmt = "%+d", noPeek = true, hl = "part",
              get = function() return ns.PetOpt and tonumber(ns.PetOpt("lvAdd")) or 0 end,
              set = function(v) if ns.SetPetOpt then ns.SetPetOpt("lvAdd", v) end end,
              more = "펫 LV 숫자 크기. 0 = 처음 크기." },
            { t = "sub", label = "체력 바" },
            { t = "slider", label = "펫 체력 바 길이", min = 50, max = 160, step = 5, fmt = "%d%%", noPeek = true, hl = "part",
              get = function() return ns.PetOpt and tonumber(ns.PetOpt("barW")) or 100 end,
              set = function(v) if ns.SetPetOpt then ns.SetPetOpt("barW", v) end end,
              more = "펫 체력 바를 오른쪽으로 늘리거나 줄여요. 100% = 처음." },
            { t = "toggle", label = "펫 체력 숫자", hint = "체력 바 안 숫자", hl = "part",
              get = function() return not (ns.PetOpt and ns.PetOpt("hpOff")) end,
              set = function(v) if ns.SetPetOpt then ns.SetPetOpt("hpOff", not v) end end,
              more = "체력 바 안 큰 숫자(860)를 보이거나 숨겨요." },
            { t = "toggle", label = "펫 % 숫자", hint = "체력 바 오른쪽 %", hl = "part",
              get = function() return not (ns.PetOpt and ns.PetOpt("pctOff")) end,
              set = function(v) if ns.SetPetOpt then ns.SetPetOpt("pctOff", not v) end end,
              more = "체력 바 오른쪽 %를 보이거나 숨겨요." },
            { sec = 4, t = "seg", label = "펫 창 보일 때", hint = "", hl = "part",
              options = { { "늘", "all" }, { "전투 중만", "combat" } },
              get = function() return ns.PetOpt and ns.PetOpt("vis") or "all" end,
              set = function(v) if ns.SetPetOpt then ns.SetPetOpt("vis", v) end end,
              more = "전투 중만 = 싸울 때만 펫 창이 보여요 (안 보일 때도 그 자리는 클릭돼요)." },
            { sec = 4, t = "seg", label = "불만이면 알림", hint = "먹이를 주세요!", hl = "part",
              options = { { "끔", "off" }, { "채팅 한 줄", "chat" }, { "소리", "sound" } },
              get = function() return ns.PetOpt and ns.PetOpt("alert") or "off" end,
              set = function(v) if ns.SetPetOpt then ns.SetPetOpt("alert", v) end end,
              more = "사냥꾼 펫이 불만으로 바뀌는 순간 한 번 알려요." },

        },
    },
    {
        key = "LeelUI_ABar", builtin = true, cat = "view",
        title = "액션바", sub = "모던 · 둥둥 3줄 · 날개", icon = "hb_apps",
        desc = "UI 모드를 '모던'으로 고르면 저절로 켜져요. 끄고 다시 불러오기 하면 게임 기본 바로 돌아가요.\n블리자드 액션 단추는 그대로 쓰고 자리 · 모양만 바꿔요.\n날개 = 왼쪽 5×2(전투 · 페이지로 바뀜) · 가운데 페이지 원 · 오른쪽 7×3(고정 · 작은 칸).",
        onoff = { reload = true, get = function() return ns.ABarDB and ns.ABarDB().on end,
                  set = function(v) ns.ABarDB().on = v and true or false end },
        items = {
            { t = "seg", label = "모양", hint = "다시 불러오기 후 적용", sec = 3,
              options = { { "둥둥 3줄", "float" }, { "날개", "wing" } },
              get = function() return (ns.ABarDB and ns.ABarDB().style) or "float" end,
              set = function(v) ns.ABarDB().style = v; Print("액션바 모양을 바꿨어요. /reload 하면 적용돼요.") end,
              more = "둥둥 3줄 = 지금 모양. 날개 = 왼쪽 5×2(전투 · 페이지로 바뀜) · 가운데 페이지 원(둘레 = 기력 · 마나 링) · 오른쪽 7×3(왼쪽 아래 바 12 + 오른쪽 아래 바 9) + 위에 체력 · 자원 줄. 오른쪽 아래 바는 게임 설정에서 켜 두세요." },
            { t = "toggle", label = "스킨 쓰기", hint = "끄면 입히기 전 모습으로 (게임 기본 단축바 · 원래 HUD)", sec = 2,
              get = function() return ns.Skin and ns.Skin.On() end,
              set = function(v) if ns.Skin then ns.Skin.SetOn(v) end end,
              more = "스킨 = 액션바 모양 · 자리 · 크기 · 대상 줄 · 버프 줄 · 설정을 한 묶음으로. 처음 켜면 지금 모습을 저장해 두고, 끄면 그대로 돌아가요. 이동 모드에서 옮긴 자리는 지금 입은 스킨에 저장돼요." },
            { t = "choice", label = "입은 스킨", hint = "고르면 바로 갈아입어요 · 스킨마다 자리 따로 기억", sec = 2, when = "now",
              dimIf = function() return not (ns.Skin and ns.Skin.On()) end, dimWhy = "스킨 쓰기를 켜면",
              options = function() return ns.Skin and ns.Skin.List() or {} end,
              get = function() return ns.Skin and ns.Skin.Cur() end,
              set = function(v) if ns.Skin then ns.Skin.Apply(v) end end },
            { t = "button", label = "지금 모습을 내 스킨으로 저장", sec = 2,
              run = function() if ns.Skin then ns.Skin.SaveAs() end end },
            { t = "input", label = "내 스킨 이름 바꾸기", hint = "지금 입은 내 스킨의 이름", button = "바꾸기", sec = 5,
              run = function(t) return ns.Skin and ns.Skin.Rename(t) end },
            { t = "button", label = "공유 글 만들기 (채팅 입력칸에 · Ctrl+C로 복사)", sec = 5,
              run = function() if ns.Skin then local t = ns.Skin.Export(); if ChatFrame_OpenChat then ChatFrame_OpenChat(t) else Print(t) end end end },
            { t = "input", label = "공유 글로 스킨 받기", hint = "!LeelSkin: 으로 시작하는 글", button = "받기", sec = 5,
              run = function(t) return ns.Skin and ns.Skin.Import(t) end },
            { t = "button", label = "지금 입은 내 스킨 지우기", sec = 5,
              run = function() if ns.Skin then ns.Skin.Delete() end end },
            { t = "header", label = "스킨에 같이 저장할 것", sec = 5 },
            { t = "toggle", label = "액션바 모양 · 자리 · 크기", sec = 5, get = function() return ns.Skin and ns.Skin.Incl("ab") end, set = function(v) ns.Skin.Incl("ab", v) end },
            { t = "toggle", label = "대상 줄 자리 · 크기", sec = 5, get = function() return ns.Skin and ns.Skin.Incl("tg") end, set = function(v) ns.Skin.Incl("tg", v) end },
            { t = "toggle", label = "버프 / 디버프 줄", sec = 5, get = function() return ns.Skin and ns.Skin.Incl("bf") end, set = function(v) ns.Skin.Incl("bf", v) end },
            { t = "toggle", label = "로아식 화면 (내 창 숨김)", sec = 5, get = function() return ns.Skin and ns.Skin.Incl("la") end, set = function(v) ns.Skin.Incl("la", v) end },
            { t = "toggle", label = "페이지 넘기기 키", sec = 5, get = function() return ns.Skin and ns.Skin.Incl("pg") end, set = function(v) ns.Skin.Incl("pg", v) end },
            { t = "seg", label = "메뉴 모양", hint = "바로 바뀌어요", sec = 3,
              options = { { "오른쪽 위 단추 줄", "row" }, { "토끼 메뉴", "bunny" } },
              get = function() return (ns.ABarDB and ns.ABarDB().menuStyle) or "row" end,
              set = function(v) ns.ABarDB().menuStyle = v; if ns.ABarMenuStyle then ns.ABarMenuStyle() end end,
              more = "단추 줄 = 자주 쓰는 메뉴(처음엔 캐릭터 · 주문 · 특성 · 퀘스트 · 지도 · 가방 · 르엘 허브)만 투명한 네모 단추로 늘 보이고, 나머지는 맨 끝 [더보기]를 누르면 판으로 떠요. 오른쪽 클릭으로 줄 ↔ 판 옮기기. 자리는 이동 모드에서." },
            { t = "slider", label = "생명력 · 마나 줄 두께", hint = "각진 전술형", sec = 3, min = 6, max = 28, step = 1, noPeek = true,
              dimIf = function() return not (ns.ABarDB and ns.ABarDB().wskin == "tac") end, dimWhy = "각진 전술형에서만",
              get = function() return (ns.ABarDB and ns.ABarDB().tacBH) or 14 end,
              set = function(v) ns.ABarDB().tacBH = math.floor(v); if ns.ABarSkin then ns.ABarSkin() end end },
            { t = "toggle", label = "버프 / 디버프 줄 보이기", hint = "각진 전술형 · 생명력 위 = 내 버프 · 마나 위 = 디버프", sec = 3,
              dimIf = function() return not (ns.ABarDB and ns.ABarDB().wskin == "tac") end, dimWhy = "각진 전술형에서만",
              get = function() return ns.ABarDB and ns.ABarDB().tacAuras ~= false end,
              set = function(v) ns.ABarDB().tacAuras = v and true or false; if ns.ABarSkin then ns.ABarSkin() end end },
            { t = "slider", label = "버프 줄 크기", hint = "내 버프 · 이동 모드에서 끌어 옮기기 · 휠 = 크기", sec = 3, min = 50, max = 200, step = 5, noPeek = true,
              dimIf = function() return not (ns.ABarDB and ns.ABarDB().wskin == "tac") end, dimWhy = "각진 전술형에서만",
              get = function() return (ns.ABarDB and ns.ABarDB().buffPct) or 100 end,
              set = function(v) if ns.ABarAuraSize then ns.ABarAuraSize("b", v) end end },
            { t = "slider", label = "디버프 줄 크기", hint = "내 디버프 · 이동 모드에서 끌어 옮기기 · 휠 = 크기", sec = 3, min = 50, max = 200, step = 5, noPeek = true,
              dimIf = function() return not (ns.ABarDB and ns.ABarDB().wskin == "tac") end, dimWhy = "각진 전술형에서만",
              get = function() return (ns.ABarDB and ns.ABarDB().debuffPct) or 100 end,
              set = function(v) if ns.ABarAuraSize then ns.ABarAuraSize("d", v) end end },
            { t = "button", label = "버프 · 디버프 줄 위치 초기화", sec = 5,
              run = function() if ns.ABarAuraReset then ns.ABarAuraReset() end end },
            { t = "toggle", label = "로아식 화면", hint = "날개 모양일 때 · 내 창 숨기기 · 대상은 화면 위 가운데 긴 줄", sec = 3,
              dimIf = function() return not (ns.ABarDB and ns.ABarDB().style == "wing") end, dimWhy = "날개 모양에서만",
              get = function() return ns.ABarDB and ns.ABarDB().laTop ~= false end,
              set = function(v) ns.ABarDB().laTop = v and true or false; if ns.ABarLAApply then ns.ABarLAApply() end end,
              more = "체력 · 자원은 날개 위 줄에 있으니 Leel HUD의 내 창은 숨겨요. 대상은 로스트아크처럼 화면 위 가운데에 레벨 · 이름 · 등급 · 체력 숫자 · % · 내가 건 디버프(남은 초)로 보여요. 끄면 원래 HUD 그대로." },
            { t = "slider", label = "대상 줄 크기", hint = "화면 위 대상 줄 · 이동 모드에서 끌어 옮기기 · 휠 = 크기", sec = 3, min = 60, max = 160, step = 5, noPeek = true,
              dimIf = function() return not (ns.ABarDB and ns.ABarDB().style == "wing" and ns.ABarDB().laTop ~= false) end, dimWhy = "로아식 화면에서만",
              get = function() return (ns.ABarDB and ns.ABarDB().laScale) or 100 end,
              set = function(v) if ns.ABarLASetScale then ns.ABarLASetScale(v) else ns.ABarDB().laScale = v end end },
            { t = "button", label = "대상 줄 위치 초기화", sec = 5,
              run = function() ns.ABarDB().laPos = nil; if ns.ABarLAPlace then ns.ABarLAPlace() end end },
            { t = "toggle", label = "비행 중 내리기 구슬", hint = "와이번 · 그리폰 · 박쥐를 탈 때 가운데 원 위에 · 누르면 다음 비행 지점에서 내려요", sec = 3,
              get = function() return not (ns.ABarDB and ns.ABarDB().taxiBtn == false) end,
              set = function(v) if ns.ABarDB then ns.ABarDB().taxiBtn = v and true or false end; if ns.ABarTaxiUpdate then ns.ABarTaxiUpdate() end end },
            { t = "seg", label = "페이지 넘기기 키", hint = "왼쪽 10칸만 바뀌어요", sec = 3,
              dimIf = function() return not (ns.ABarDB and ns.ABarDB().style == "wing") end, dimWhy = "날개 모양에서만",
              options = { { "끔", "off" }, { "Z · X", "zx" } },
              get = function() return (ns.ABarDB and ns.ABarDB().pgKeys) or "off" end,
              set = function(v) ns.ABarDB().pgKeys = v; if ns.ABarKeys then ns.ABarKeys() end end,
              more = "Z = 이전 페이지 · X = 다음 페이지. 원래 Z(무기 넣기) · X(앉기) 대신 쓰여요. 끔이면 가운데 작은 원을 눌러 넘겨요. 변신 · 태세는 저절로 바뀌어요." },
            { moveOnly = true, t = "slider", label = "액션바 크기", min = 60, max = 150,
              get = function() return (ns.ABarDB and ns.ABarDB().scale) or 100 end,
              set = function(v)
                  if ns.SetABarScale then ns:SetABarScale(v) else ns.ABarDB().scale = v end
                  if InCombatLockdown() then Print("전투가 끝나면 액션바 크기가 바뀌어요.") end
              end },
            { moveOnly = true, t = "slider", label = "메뉴 줄 크기", min = 50, max = 160,
              get = function() return (ns.ABarDB and ns.ABarDB().mrScale) or 100 end,
              set = function(v) if ns.ABarMenuScale then ns.ABarMenuScale(v) else ns.ABarDB().mrScale = v end end },
            { moveOnly = true, t = "slider", label = "토끼 메뉴 크기", min = 60, max = 150,
              get = function() return (ns.ABarDB and ns.ABarDB().mscale) or 100 end,
              set = function(v)
                  if ns.SetABarMenuScale then ns:SetABarMenuScale(v) else ns.ABarDB().mscale = v end
                  if InCombatLockdown() then Print("전투가 끝나면 토끼 메뉴 크기가 바뀌어요.") end
              end },
            { t = "button", label = "액션바 · 토끼 메뉴 위치 초기화",
              run = function() if ns.ResetABarPosition then ns:ResetABarPosition() end; Print("액션바와 토끼 메뉴를 처음 자리로 돌렸어요.") end },
            { t = "button", label = "점검 (채팅창)", run = function() SlashCmdList.LEELABAR("") end },
        },
    },
    {
        key = "LeelUI_Cast", builtin = true, always = true, cat = "view",
        title = "시전바", sub = "깡충 토끼, 발자국", icon = "hb_cast",
        desc = "모양을 바꾸면 다시 불러오기 후 적용.\n자리 옮기기는 아래 '이동 모드'.",
        items = {
            { sec = 2, t = "seg", label = "모양", hint = "내 시전바 · 적 시전바 같이",
              options = { { "깡충 토끼", "bunny" }, { "토끼 발자국", "paw" }, { "예전 얇은 바", "hud" } },
              get = function() return ns.db.castStyle or "bunny" end,
              set = function(v) SetCastStyle(v) end },
            { sec = 2, t = "toggle", label = "내 시전바", hint = "내가 주문을 걸 때",
              get = function() return not ns.db.castMineOff end,
              set = function(v)
                  ns.db.castMineOff = not v
                  local pc = ns.casts and ns.casts.player
                  if pc and not v then pc.casting, pc.finishing = false, false; pc:SetScript("OnUpdate", nil); pc:Hide() end
              end },
            { sec = 2, t = "toggle", label = "적 시전바", hint = "대상이 주문을 걸 때",
              get = function() return not ns.db.castMineOnly end,
              set = function(v)
                  ns.db.castMineOnly = not v
                  local tc = ns.casts and ns.casts.target
                  if tc and not v then tc.casting, tc.finishing = false, false; tc:SetScript("OnUpdate", nil); tc:Hide(); if tc.OnLayout then tc:OnLayout() end end
              end },
            -- ③ 모양
            { sec = 3, t = "slider", label = "바 길이", hint = "가로 길이만", min = 60, max = 160, step = 5, fmt = "%d%%", noPeek = true,
              get = function() return ns.CastOpt and ns.CastOpt("len") or 100 end,
              set = function(v) if ns.SetCastOpt then ns.SetCastOpt("len", v) end end,
              more = "시전바 가로 길이만. 100% = 처음 길이." },
            { sec = 3, t = "slider", label = "바 두께", hint = "바 높이", min = 50, max = 200, step = 10, fmt = "%d%%", noPeek = true,
              get = function() return ns.CastOpt and ns.CastOpt("thick") or 100 end,
              set = function(v) if ns.SetCastOpt then ns.SetCastOpt("thick", v) end end,
              more = "바 높이 (토끼 · 발자국 · 얇은 바 모두). 100% = 처음 두께." },
            { sec = 3, t = "seg", label = "주문 아이콘", hint = "바 옆 동그란 주문 그림",
              options = { { "왼쪽", "left" }, { "오른쪽", "right" }, { "끔", "off" } },
              get = function() return ns.CastOpt and ns.CastOpt("icon") or "left" end,
              set = function(v) if ns.SetCastOpt then ns.SetCastOpt("icon", v) end end },
            { sec = 3, t = "seg", label = "글씨", hint = "주문 이름 · 남은 시간",
              options = { { "이름 + 시간", "both" }, { "이름만", "name" }, { "시간만", "time" }, { "끔", "off" } },
              get = function() return ns.CastOpt and ns.CastOpt("text") or "both" end,
              set = function(v) if ns.SetCastOpt then ns.SetCastOpt("text", v) end end },
            { sec = 3, child = true, t = "seg", label = "시간 모양",
              dimIf = function() local t = ns.CastOpt and ns.CastOpt("text"); return t == "name" or t == "off" end, dimWhy = "시간을 끄면 안 보여요",
              options = { { "남은 1.4", "left" }, { "지난 / 전체", "of" }, { "남은 / 전체", "leftof" } },
              get = function() return ns.CastOpt and ns.CastOpt("tfmt") or "left" end,
              set = function(v) if ns.SetCastOpt then ns.SetCastOpt("tfmt", v) end end,
              more = "남은 1.4 = 지금처럼 남은 초. 지난 / 전체 = 1.1 / 2.5. 남은 / 전체 = 1.4 / 2.5." },
            { sec = 3, t = "seg", label = "내 시전바 색",
              options = { { "분홍", "pink" }, { "직업 색", "class" }, { "흰색", "white" } },
              get = function() return ns.CastOpt and ns.CastOpt("col") or "pink" end,
              set = function(v) if ns.SetCastOpt then ns.SetCastOpt("col", v) end end,
              more = "내 주문 시전 색만. 정신 집중(하늘) · 적 시전 색은 그대로." },
            { sec = 3, t = "slider", label = "글씨 크기", hint = "이름 · 시간", min = -4, max = 8, step = 1, fmt = "%+d", noPeek = true,
              get = function() return ns.CastOpt and ns.CastOpt("fsz") or 0 end,
              set = function(v) if ns.SetCastOpt then ns.SetCastOpt("fsz", v) end end },
            -- ④ 언제
            { sec = 4, t = "seg", label = "적 시전바 보일 때",
              dimIf = function() return ns.db.castMineOnly end, dimWhy = "적 시전바가 꺼져 있어요",
              options = { { "늘", "all" }, { "끊을 수 있을 때만", "int" } },
              get = function() return (ns.TgtOpt and ns.TgtOpt("castIntOnly")) and "int" or "all" end,
              set = function(v) if ns.SetTgtOpt then ns.SetTgtOpt("castIntOnly", v == "int") end end },
            { sec = 4, t = "seg", label = "적 시전바 대상", hint = "대상이 시전 안 할 때 대신 보여줄 적",
              dimIf = function() return ns.db.castMineOnly end, dimWhy = "적 시전바가 꺼져 있어요",
              options = { { "대상만", "target" }, { "+ 주시 대상", "focus" }, { "+ 마우스 올린 적", "mouse" } },
              get = function() return ns.CastOpt and ns.CastOpt("who") or "target" end,
              set = function(v) if ns.SetCastOpt then ns.SetCastOpt("who", v) end end,
              more = "대상이 시전 중이면 늘 대상 먼저. 대상이 조용할 때 주시 대상(있으면) · 마우스를 올린 적의 시전을 보여줘요." },
            { sec = 4, t = "toggle", label = "전투 밖에서도", hint = "낚시 · 요리 · 귀환석 같은 내 시전",
              get = function() return not ns.CastOpt or ns.CastOpt("ooc") end,
              set = function(v) if ns.SetCastOpt then ns.SetCastOpt("ooc", v and true or false) end end,
              more = "끄면 내 시전바는 전투 중에만 보여요." },
            -- ⑤ 더
            { sec = 5, t = "toggle", label = "지연 꼬리", hint = "내 시전바 끝 빨간 부분 = 핑만큼 미리 눌러도 돼요",
              get = function() return ns.CastOpt and ns.CastOpt("lag") end,
              set = function(v) if ns.SetCastOpt then ns.SetCastOpt("lag", v and true or false) end end },
            { sec = 5, t = "toggle", label = "정신 집중 눈금", hint = "정신 집중 주문의 1초마다 세로 줄",
              get = function() return ns.CastOpt and ns.CastOpt("ticks") end,
              set = function(v) if ns.SetCastOpt then ns.SetCastOpt("ticks", v and true or false) end end },
            { sec = 5, t = "toggle", label = "끝날 때 반짝", hint = "완료 = 흰빛 · 끊김 = 빨강",
              get = function() return not ns.CastOpt or ns.CastOpt("flash") end,
              set = function(v) if ns.SetCastOpt then ns.SetCastOpt("flash", v and true or false) end end,
              more = "끄면 시전이 끝나는 순간 바로 사라져요." },
            { sec = 5, t = "seg", label = "끊었을 때 알림", hint = "내가 적 시전을 끊으면",
              options = { { "끔", "off" }, { "화면 글씨", "screen" }, { "채팅", "chat" }, { "소리", "sound" } },
              get = function() return ns.CastOpt and ns.CastOpt("kick") or "off" end,
              set = function(v) if ns.SetCastOpt then ns.SetCastOpt("kick", v) end end,
              more = "\"끊음! 화염구 (적 이름)\" 처럼 알려줘요. 펫이 끊어도 알려요." },
            { sec = 5, t = "toggle", label = "내가 끊겼을 때", hint = "내 시전이 끊기면 바가 흔들 + 짧은 소리",
              get = function() return ns.CastOpt and ns.CastOpt("gotKick") end,
              set = function(v) if ns.SetCastOpt then ns.SetCastOpt("gotKick", v and true or false) end end },
            { t = "button", label = "시전바 위치 초기화",
              run = function() if ns.ResetCastPosition then ns:ResetCastPosition() end; Print("시전바 위치를 처음대로 돌렸어요.") end },
        },
    },
    {
        key = "LeelUI_Plates", builtin = true, cat = "view",
        title = "적 이름표", sub = "몹 등급 · 선공 구별", icon = "hb_plate",
        desc = "적 머리 위 분홍 이름표. 왼쪽 스위치는 다시 불러오기 후 적용.",
        onoff = { reload = true, get = function() return ns.db.nameplates end,
                  set = function(v) ns.db.nameplates = v end },
        items = {
            { sec = 2, t = "toggle", label = "선공 / 비선공 구별", hl = "calm", hint = "선공은 분홍 바, 비선공은 크림색 바",
              get = function() return ns.db.npAggro ~= false end,
              set = function(v) ns.db.npAggro = v; if ns.RefreshPlateInfo then ns:RefreshPlateInfo() end end },
            { sec = 2, t = "toggle", label = "퀘스트 몹 표시", hl = "quest", hint = "퀘스트 원 (Questie 없이도: 한 번 잡은 몹은 기억)",
              get = function() return ns.db.questCircle ~= false end,
              set = function(v) ns.db.questCircle = v; if ns.RefreshNameplates then ns:RefreshNameplates() end end },
            { sec = 2, t = "seg", label = "이름표 시전바", hl = "cast", hint = "적이 주문을 걸 때 바 아래",
              options = { { "늘", "all" }, { "끊을 수 있을 때만", "int" }, { "끔", "off" } },
              get = function() return ns.NPOpt and ns.NPOpt("cast") end, set = function(v) if ns.SetNPOpt then ns.SetNPOpt("cast", v) end end },
            { sec = 2, t = "toggle", label = "내 디버프", hl = "deb", hint = "바 아래 내가 건 디버프",
              get = function() return ns.NPOpt and ns.NPOpt("deb") end, set = function(v) if ns.SetNPOpt then ns.SetNPOpt("deb", v) end end },
            { sec = 2, t = "toggle", label = "연계 점수 구슬", hl = "combo", hint = "도적 · 드루 (대상 · 점수 쌓인 몹)",
              get = function() return ns.NPOpt and ns.NPOpt("combo") end, set = function(v) if ns.SetNPOpt then ns.SetNPOpt("combo", v) end end },
            -- ③ 모양
            { sec = 3, t = "slider", label = "이름표 크기", hl = "all", min = 40, max = 150, noPeek = true,
              get = function() return math.floor((ns.db.npScale or 1) * 100 + 0.5) end,
              set = function(v) ns.db.npScale = v / 100; if ns.RefreshNameplates then ns:RefreshNameplates() end end,
              more = "이름표 전체 (글씨 · 아이콘 포함) 크기." },
            { sec = 3, t = "slider", label = "바 크기", hl = "bar", hint = "체력 · 시전 바 너비 · 높이만", min = 60, max = 160, step = 5, fmt = "%d%%", noPeek = true,
              get = function() return ns.NPOpt and ns.NPOpt("size") end, set = function(v) if ns.SetNPOpt then ns.SetNPOpt("size", v) end end },
            { sec = 3, t = "seg", label = "체력 글씨", hl = "pct", hint = "바 안 오른쪽",
              options = { { "62%", "pct" }, { "1,240", "num" }, { "1,240 · 62%", "both" }, { "끔", "off" } },
              get = function() return ns.NPOpt and ns.NPOpt("hpTxt") end, set = function(v) if ns.SetNPOpt then ns.SetNPOpt("hpTxt", v) end end },
            { sec = 3, t = "seg", label = "레벨 · 등급 알약", hl = "lv", hint = "이름 앞",
              options = { { "둘 다", "both" }, { "레벨만", "lv" }, { "끔", "off" } },
              get = function() return ns.NPOpt and ns.NPOpt("lvRank") end, set = function(v) if ns.SetNPOpt then ns.SetNPOpt("lvRank", v) end end },
            { sec = 3, t = "slider", label = "이름 글씨 크기", hl = "name", min = -4, max = 8, step = 1, fmt = "%+d", noPeek = true,
              get = function() return ns.NPOpt and ns.NPOpt("nameAdd") end, set = function(v) if ns.SetNPOpt then ns.SetNPOpt("nameAdd", v) end end },
            { sec = 3, t = "seg", label = "내 대상 표시", hl = "mark", hint = "고른 적 이름 위",
              options = { { "조준", "aim" }, { "화살표", "arrow" }, { "끄기", "off" } },
              get = function() return ns.db.npMark or "aim" end,
              set = function(v) ns.db.npMark = v; if ns.RefreshNameplates then ns:RefreshNameplates() end end },
            { sec = 3, child = true, depOn = function() return (ns.db.npMark or "aim") ~= "off" end, t = "slider", label = "표시 크기", hl = "mark", min = 50, max = 200, noPeek = true,
              get = function() return tonumber(ns.db.npMarkScale) or 100 end,
              set = function(v) ns.db.npMarkScale = v; if ns.RefreshNameplates then ns:RefreshNameplates() end end },
            { sec = 3, t = "toggle", label = "내 대상 흐르는 빛", hl = "bar", hint = "바 위를 스윽 지나가는 빛",
              get = function() return ns.NPOpt and ns.NPOpt("shine") end, set = function(v) if ns.SetNPOpt then ns.SetNPOpt("shine", v) end end },
            -- ④ 언제
            { sec = 4, t = "slider", label = "대상 아닌 이름표", hl = "others", hint = "대상이 있을 때 나머지 진하기", min = 20, max = 100, step = 2, fmt = "%d%%", noPeek = true,
              get = function() return ns.NPOpt and ns.NPOpt("dim") end, set = function(v) if ns.SetNPOpt then ns.SetNPOpt("dim", v) end end, more = "100% = 흐리게 안 함. 지금은 62%." },
            { sec = 4, t = "seg", label = "죽은 몹 이름표",
              options = { { "바로 숨김", "hide" }, { "보이기", "show" } },
              get = function() return (ns.db.npHideDead == false) and "show" or "hide" end,
              set = function(v) ns.db.npHideDead = (v == "hide"); if ns.RefreshDeadPlates then ns:RefreshDeadPlates() end end },
            { sec = 4, t = "seg", label = "남의 몹", hl = "tap", hint = "다른 사람이 먼저 친 몹",
              options = { { "회색 + 줄", "grey" }, { "그대로", "keep" } },
              get = function() return ns.NPOpt and ns.NPOpt("tapped") end, set = function(v) if ns.SetNPOpt then ns.SetNPOpt("tapped", v) end end },
            -- ⑤ 더
            { sec = 5, t = "seg", label = "체력 낮으면 강조", hl = "exec", hint = "처형 구간이면 바가 주황",
              options = { { "끔", "off" }, { "20%", "20" }, { "35%", "35" } },
              get = function() return ns.NPOpt and ns.NPOpt("exec") end, set = function(v) if ns.SetNPOpt then ns.SetNPOpt("exec", v) end end },
            { sec = 5, t = "toggle", label = "나를 공격 중", hl = "aggro", hint = "빨간 테 + 빛 (어그로)",
              get = function() return ns.NPOpt and ns.NPOpt("aggro") end, set = function(v) if ns.SetNPOpt then ns.SetNPOpt("aggro", v) end end },
            { sec = 5, t = "seg", label = "징표 자리", hl = "raid", hint = "해골 · 별 등",
              options = { { "바 왼쪽", "left" }, { "이름 위", "top" } },
              get = function() return ns.NPOpt and ns.NPOpt("raid") end, set = function(v) if ns.SetNPOpt then ns.SetNPOpt("raid", v) end end },
        },
    },
    {
        key = "LeelUI_Minimap", builtin = true, always = true, cat = "view",
        title = "미니맵", sub = "르엘 미니맵", icon = "hb_minimap",
        desc = "동그란 지도 + 아래 버튼 줄. 휠 = 확대/축소.\n옮기기: 아래 '이동 모드'. 애드온 아이콘은 네 칸 버튼 하나로.",
        items = {
            { t = "toggle", label = "르엘 미니맵 쓰기", hint = "끄면 블리자드 기본 (다시 불러오기)", hl = "all",
              get = function() return ns.db.mmStyle ~= "blizz" end,
              set = function(v) ns:SetMinimapStyle(v and "bar" or "blizz") end },
            { t = "seg", label = "미니맵 모양", hint = "다시 불러오기 후 적용",
              dimIf = function() return ns.db.mmStyle == "blizz" end, dimWhy = "르엘 미니맵을 켜면",
              options = { { "동그라미 + 버튼 줄", "bar" }, { "네모 · 꺾쇠", "tac" } },
              get = function() return ns.db.mmStyle == "tac" and "tac" or "bar" end,
              set = function(v) ns:SetMinimapStyle(v) end,
              more = "네모 · 꺾쇠 = 네모 지도 + 네 모서리 진영 색 꺾쇠 + 아래 안쪽 지역 띠(이름 · 좌표 · 시계) + 지도 오른쪽에 네모 단추 세로 줄. 각진 전술형 액션바와 짝이에요." },
            { t = "button", label = "미니맵 위치 초기화",
              run = function() if ns.ResetMinimapPosition then ns:ResetMinimapPosition() end; Print("미니맵을 처음 자리로 돌렸어요.") end },
            { sec = 2, t = "toggle", label = "지역 이름 알약", hl = "zone", hint = "지도 위 \"지역 이름 + 좌표\" 알약",
              get = function() return ns.db.mmZone ~= false end, set = function(v) ns.db.mmZone = v and true or false end },
            { sec = 2, child = true, t = "toggle", label = "좌표", hl = "zone",
              get = function() return ns.db.mmCoords ~= false end, set = function(v) ns.db.mmCoords = v and true or false end },
            { sec = 2, t = "seg", label = "시계", hl = "clock", hint = "아래 버튼 줄 오른쪽 시계",
              options = { { "게임 설정대로", "auto" }, { "내 컴퓨터", "local" }, { "서버", "server" } },
              get = function() return ns.db.mmClock or "auto" end, set = function(v) ns.db.mmClock = (v ~= "auto") and v or nil end },
            { sec = 4, t = "toggle", label = "휠로 확대 · 축소", hl = "map", hint = "지도 위에서 마우스 휠",
              get = function() return ns.db.mmWheel ~= false end, set = function(v) ns.db.mmWheel = v and true or false end },
            { sec = 4, child = true, t = "toggle", label = "저절로 다시 축소", hl = "map", hint = "확대하고 10초 지나면 가장 멀리 (주변이 다시 넓게)",
              get = function() return ns.db.mmAutoZoom and true or false end, set = function(v) ns.db.mmAutoZoom = v and true or nil end },
            { sec = 5, t = "toggle", label = "미니맵 아이콘", hl = "bunny", hint = "허브를 여는 르엘 토끼 단추",
              get = function() return not ns.db.minimap.hide end,
              set = function(v)
                  ns:SetMinimapShown(v)
                  if not v then Print("아이콘을 숨겼어요. /르엘 로 허브를 열 수 있어요.") end
              end,
              more = "미니맵 둘레의 토끼 아이콘. 숨겨도 /르엘 로 허브를 열 수 있어요." },
            { sec = 5, child = true, t = "toggle", label = "미니맵 아이콘 정리", hl = "bunny", hint = "길잡이 버튼은 숨기고 토끼 하나만",
              get = function() return ns.db.hub.tidy end,
              set = function(v) ns.db.hub.tidy = v; ns:ApplyHubTidy() end },
            { sec = 5, t = "toggle", label = "다른 애드온 아이콘 모으기", hl = "bar", hint = "애드온 미니맵 아이콘을 아래 줄 네 칸 단추 하나로 (다시 불러오기)",
              get = function() return ns.db.mmCollect ~= false end,
              set = function(v) ns.db.mmCollect = v; StaticPopup_Show("LEELUI_HUB_RELOAD") end },
        },
    },
    {
        key = "LeelUI_Tip", builtin = true, always = true, cat = "view",
        title = "툴팁", sub = "마우스 설명 창", icon = "hb_search",
        desc = "몹·아이템에 마우스를 올리면 뜨는 설명 창.\n르엘 판 + 왼쪽 색 줄(적 빨강, 중립 노랑, 우호 초록).",
        items = {
            { sec = 2, t = "toggle", label = "대상의 대상", hl = "tot", hint = "\"대상: 르엘\" 한 줄 (몹이 누구를 노리는지)", get = function() return ns.TipOpt and ns.TipOpt("tot") end, set = function(v) if ns.SetTipOpt then ns.SetTipOpt("tot", v) end end },
            { sec = 2, t = "seg", label = "체력 줄", hl = "hp", hint = "툴팁 아래 얇은 체력 바",
              options = { { "바 + %", "both" }, { "바만", "bar" }, { "끔", "off" } }, get = function() return ns.TipOpt and ns.TipOpt("hpBar") end, set = function(v) if ns.SetTipOpt then ns.SetTipOpt("hpBar", v) end end },
            { sec = 2, t = "toggle", label = "길드 이름", hl = "guild", hint = "플레이어 툴팁의 길드 줄", get = function() return ns.TipOpt and ns.TipOpt("guild") end, set = function(v) if ns.SetTipOpt then ns.SetTipOpt("guild", v) end end },
            { sec = 2, t = "toggle", label = "아이템 레벨", hl = "ilvl", hint = "아이템 툴팁에 한 줄", get = function() return ns.TipOpt and ns.TipOpt("ilvl") end, set = function(v) if ns.SetTipOpt then ns.SetTipOpt("ilvl", v) end end },
            { sec = 3, t = "slider", label = "툴팁 크기", hl = "all", min = 60, max = 150, step = 5, fmt = "%d%%", noPeek = true, get = function() return ns.TipOpt and ns.TipOpt("scale") end, set = function(v) if ns.SetTipOpt then ns.SetTipOpt("scale", v) end end },
            { sec = 3, t = "seg", label = "관계 표시", hl = "rel", hint = "적대 · 중립 · 우호",
              options = { { "이름 옆 칩", "chip" }, { "왼쪽 색 줄", "stripe" }, { "끔", "off" } }, get = function() return ns.TipOpt and ns.TipOpt("rel") end, set = function(v) if ns.SetTipOpt then ns.SetTipOpt("rel", v) end end },
            { sec = 3, t = "toggle", label = "토끼 장식", hl = "bunny", hint = "오른쪽 위 작은 토끼", get = function() return ns.TipOpt and ns.TipOpt("bunny") end, set = function(v) if ns.SetTipOpt then ns.SetTipOpt("bunny", v) end end },
            { sec = 3, t = "slider", label = "배경 진하기", hl = "all", min = 50, max = 100, step = 1, fmt = "%d%%", noPeek = true, get = function() return ns.TipOpt and ns.TipOpt("bgA") end, set = function(v) if ns.SetTipOpt then ns.SetTipOpt("bgA", v) end end },
            { sec = 3, t = "toggle", label = "아이템 품질 테두리", hl = "item", hint = "희귀 = 파랑 · 영웅 = 보라 테", get = function() return ns.TipOpt and ns.TipOpt("quality") end, set = function(v) if ns.SetTipOpt then ns.SetTipOpt("quality", v) end end },
            { sec = 4, t = "toggle", label = "마우스 따라다니기", hl = "all", hint = "끄면 블리자드 기본 자리(오른쪽 아래)",
              get = function() return ns.db.tipCursor ~= false end,
              set = function(v) ns.db.tipCursor = v and true or false end },
            { sec = 4, child = true, depOn = function() return ns.db.tipCursor ~= false end, t = "seg", label = "커서 기준 자리",
              options = { { "오른쪽 아래", "br" }, { "오른쪽 위", "tr" }, { "왼쪽 아래", "bl" } }, get = function() return ns.TipOpt and ns.TipOpt("pos") end, set = function(v) if ns.SetTipOpt then ns.SetTipOpt("pos", v) end end },
            { sec = 4, t = "seg", label = "전투 중", hint = "몹 · 플레이어 툴팁",
              options = { { "보이기", "show" }, { "Shift 누를 때만", "shift" }, { "숨기기", "hide" } }, get = function() return ns.TipOpt and ns.TipOpt("combat") end, set = function(v) if ns.SetTipOpt then ns.SetTipOpt("combat", v) end end,
              more = "전투 중엔 툴팁이 시야를 가려요. Shift 누를 때만 = Shift를 누른 채 마우스를 올리면 보여요." },
            { sec = 5, t = "toggle", label = "아이템 · 주문 번호", hl = "ids", hint = "ID (정보 찾을 때)", get = function() return ns.TipOpt and ns.TipOpt("ids") end, set = function(v) if ns.SetTipOpt then ns.SetTipOpt("ids", v) end end },
            { sec = 5, t = "toggle", label = "지금 대상이면 표시", hl = "mine", hint = "내가 고른 몹에 마우스를 올리면 \"● 내 대상\"", get = function() return ns.TipOpt and ns.TipOpt("mine") end, set = function(v) if ns.SetTipOpt then ns.SetTipOpt("mine", v) end end },
        },
    },
    {
        key = "LeelUI_Mouse", builtin = true, always = true, cat = "view",
        title = "마우스", sub = "클릭 퐁 · 반응 · 꼬리", icon = "hb_mouse",
        desc = "커서 그림은 게임이 정해서 못 바꾸지만, 커서 둘레에 르엘 효과를 그려요.",
        items = {
            { sec = 2, t = "toggle", label = "클릭 퐁", hl = "click", hint = "짧게 누르면 분홍 링 + 하트 (오른클릭은 크림)",
              get = function() return ns.db.cfxClick ~= false end,
              set = function(v) ns.db.cfxClick = v and true or false end },
            { sec = 2, t = "toggle", label = "가리키면 반응", hl = "react", hint = "적 빨간 점선 · NPC 하트 · 주울 시체 별",
              get = function() return ns.db.cfxReact ~= false end,
              set = function(v) ns.db.cfxReact = v and true or false; if ns.CursorFxRefresh then ns.CursorFxRefresh() end end },
            { sec = 2, t = "toggle", label = "반짝 꼬리", hl = "trail", hint = "빠르게 움직일 때만 분홍 점 · 별",
              get = function() return ns.db.cfxTrail ~= false end,
              set = function(v) ns.db.cfxTrail = v and true or false end },
            { sec = 2, t = "toggle", label = "커서 찾기", hl = "find", hint = "Ctrl 두 번 · 전투 시작할 때 커서 둘레로 링",
              get = function() return ns.CfxOpt and ns.CfxOpt("find") end, set = function(v) if ns.SetCfxOpt then ns.SetCfxOpt("find", v) end end, more = "큰 화면에서 커서를 잃어버릴 때. Ctrl을 빠르게 두 번 누르거나 전투가 시작되면 커서 둘레로 분홍 링이 조여들어요." },
            { sec = 3, t = "slider", label = "효과 크기", hl = "all", min = 50, max = 200, step = 10, fmt = "%d%%", noPeek = true, get = function() return ns.CfxOpt and ns.CfxOpt("size") end, set = function(v) if ns.SetCfxOpt then ns.SetCfxOpt("size", v) end end },
            { sec = 3, t = "seg", label = "효과 색", hl = "all",
              options = { { "분홍", "pink" }, { "직업 색", "class" }, { "흰색", "white" } }, get = function() return ns.CfxOpt and ns.CfxOpt("col") end, set = function(v) if ns.SetCfxOpt then ns.SetCfxOpt("col", v) end end,
              more = "분홍 = 지금처럼 (오른클릭은 크림). 직업 색 = 내 직업 색으로." },
            { sec = 3, t = "seg", label = "클릭 모양", hl = "click",
              options = { { "하트", "heart" }, { "별", "star" }, { "동그라미", "dot" } }, get = function() return ns.CfxOpt and ns.CfxOpt("shape") end, set = function(v) if ns.SetCfxOpt then ns.SetCfxOpt("shape", v) end end },
            { sec = 3, t = "seg", label = "꼬리 길이", hl = "trail",
              options = { { "짧게", "short" }, { "보통", "mid" }, { "길게", "long" } }, get = function() return ns.CfxOpt and ns.CfxOpt("trail") end, set = function(v) if ns.SetCfxOpt then ns.SetCfxOpt("trail", v) end end },
            { sec = 4, t = "seg", label = "전투 중", hint = "효과가 정신없으면 전투 중엔 꺼요",
              options = { { "켬", "on" }, { "끔", "off" } }, get = function() return ns.CfxOpt and ns.CfxOpt("combat") end, set = function(v) if ns.SetCfxOpt then ns.SetCfxOpt("combat", v) end end },
        },
    },
    {
        key = "LeelUI_Chat", builtin = true, cat = "view",
        title = "채팅창", sub = "채널 기둥 · 새 글 숫자", icon = "hb_chat",
        desc = "왼쪽 채널 기둥 + 분홍 테 카드. 다른 탭에 새 글이 오면 숫자, 귓말은 분홍 점.\n기둥 오른쪽 클릭 = 탭 메뉴, Shift + 끌기 = 채팅창 옮기기. 스위치는 다시 불러오기 후 적용.",
        onoff = { reload = true, get = function() return ns.ChatDB and ns.ChatDB().on end,
                  set = function(v) ns.ChatDB().on = v and true or false end },
        items = {
            { sec = 2, t = "toggle", label = "채널 칩", hl = "chips", hint = "[길드] [1. 공개] 글자를 작은 색 칩으로 (눌러서 말하기는 그대로)",
              get = function() return ns.ChatDB and ns.ChatDB().chips ~= false end,
              set = function(v) if ns.ChatDB then ns.ChatDB().chips = v and true or false end end, more = "새로 오는 글부터 바뀌어요." },
            { sec = 2, t = "toggle", label = "음성 채팅 칩", hint = "말하는 사람을 머리줄 오른쪽 분홍 칩으로 · 블리자드 기본 알림은 숨김",
              get = function() return ns.ChatDB and ns.ChatDB().voiceChip ~= false end,
              set = function(v) if ns.ChatDB then ns.ChatDB().voiceChip = v and true or false end; if ns.ChatVoiceQuiet then ns.ChatVoiceQuiet() end; if ns.ChatVoicePaint then ns.ChatVoicePaint() end end },
            { sec = 2, t = "seg", label = "시간 표시", hl = "ts", hint = "글 앞에 받은 시각",
              options = { { "끔", "off" }, { "시:분", "hm" }, { "초까지", "hms" } },
              get = function() return ns.ChatDB and ns.ChatDB().ts or "off" end,
              set = function(v) if ns.ChatDB then ns.ChatDB().ts = v end end },
            { sec = 2, t = "toggle", label = "내 이름 나오면 하트", hl = "me", hint = "누가 내 이름을 말하면 그 줄 앞에 분홍 하트",
              get = function() return ns.ChatDB and ns.ChatDB().myName and true or false end,
              set = function(v) if ns.ChatDB then ns.ChatDB().myName = v and true or nil end end },
            { sec = 2, t = "toggle", label = "@ 불러 주면 알림", hl = "at", hint = "누가 \"@내이름\" 을 쓰면 그 줄 분홍 띠 + 소리 (상대가 르엘 UI가 아니어도)",
              get = function() return ns.ChatDB and ns.ChatDB().atOn ~= false end,
              set = function(v) if ns.ChatDB then ns.ChatDB().atOn = v and true or false end end },
            { sec = 2, child = true, t = "choice", label = "알림 소리", hl = "at", hint = "고르면 한 번 들려줘요",
              options = function() return { { key = "pager", label = "삐삐 호출 (르엘)" }, { key = "ready", label = "준비 확인" }, { key = "warn", label = "공격대 경보" }, { key = "ding", label = "귓말 띵" }, { key = "off", label = "소리 없음" } } end,
              get = function() return ns.ChatDB and ns.ChatDB().atSnd or "pager" end,
              set = function(v) if ns.ChatDB then ns.ChatDB().atSnd = v; if ns.ChatAtSound then ns.ChatAtSound(v) end end end,
              more = "삐삐 호출 = 르엘 UI용으로 만든 \"삐빅 삐빅\" (처음 한 번은 게임을 껐다 켜야 들려요, 그 전엔 준비 확인 소리로)" },
            { sec = 2, child = true, t = "toggle", label = "전투 중엔 소리 끔", hl = "at",
              get = function() return ns.ChatDB and ns.ChatDB().atCombat and true or false end,
              set = function(v) if ns.ChatDB then ns.ChatDB().atCombat = v and true or nil end end },
            { sec = 3, t = "slider", label = "배경 진하기", hl = "alpha", min = 0, max = 100, noPeek = true,
              get = function() return (ns.ChatDB and ns.ChatDB().alpha) or 0 end,
              set = function(v) if ns.SetChatAlpha then ns:SetChatAlpha(v) end end },
            { sec = 3, t = "slider", label = "글씨 크기", hl = "font", min = 10, max = 20, step = 1, fmt = "%d", noPeek = true,
              get = function() local d = ns.ChatDB and ns.ChatDB(); if d and d.fsize then return d.fsize end; local _, sz = ChatFrame1:GetFont(); return math.floor((sz or 14) + 0.5) end,
              set = function(v) if ns.ChatDB then ns.ChatDB().fsize = v; if ns.ChatApplyLook then ns.ChatApplyLook(true) end end end,
              more = "묶여 있는 채팅 탭 전부에 적용돼요. (글씨체 탭의 글씨 크기를 바꾸면 그쪽이 다시 덮어써요)" },
            { sec = 3, t = "toggle", label = "파티원 말풍선 직업 색", hl = "bubble", hint = "파티 중 파티원(나 포함) 말풍선 왼쪽에 직업 색 띠 · 던전 안에서는 게임이 막아서 기본 그대로",
              get = function() return ns.ChatDB and ns.ChatDB().bubbleCls ~= false end,
              set = function(v) if ns.ChatDB then ns.ChatDB().bubbleCls = v and true or false; if ns.ChatBubbleRefresh then ns.ChatBubbleRefresh() end end end },
            { sec = 4, t = "toggle", label = "오래된 글 흐려지기", hl = "fade", hint = "한동안 새 글이 없으면 글이 사라져요 (끄면 늘 보여요)",
              get = function() return not (ns.ChatDB and ns.ChatDB().fade == false) end,
              set = function(v) if ns.ChatDB then ns.ChatDB().fade = v and true or false; if ns.ChatApplyLook then ns.ChatApplyLook() end end end },
            { sec = 4, t = "toggle", label = "귓말 오면 소리", hl = "whisper", hint = "귓말 · 배틀넷 귓말이 오면 띵",
              get = function() return ns.ChatDB and ns.ChatDB().wSound and true or false end,
              set = function(v) if ns.ChatDB then ns.ChatDB().wSound = v and true or nil; if v then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081, "Master") end end end },
            { sec = 5, t = "toggle", label = "보낸 말 다시 쓰기", hl = "hist", hint = "입력칸에서 ↑ = 최근 보낸 말 목록 · ↑ ↓ 고르고 Enter 로 보내기 (채널도 같이)",
              get = function() return ns.ChatDB and ns.ChatDB().histOn ~= false end,
              set = function(v) if ns.ChatDB then ns.ChatDB().histOn = v and true or false; if ns.ChatHistApply then ns.ChatHistApply() end end end },
            { sec = 5, t = "toggle", label = "@ 치면 이름 고르기", hl = "atpick", hint = "입력칸에 @ = 파티원 · 길드원 · 최근 말한 사람 목록 · ↑ ↓ 고르고 Tab",
              get = function() return ns.ChatDB and ns.ChatDB().atPick ~= false end,
              set = function(v) if ns.ChatDB then ns.ChatDB().atPick = v and true or false end end },
            { sec = 5, t = "toggle", label = "탭 따로 띄우기 허용", hl = "rail", hint = "끄면 채팅창에서 떨어져 나온 탭을 기둥으로 다시 붙여요",
              get = function() return ns.ChatDB and ns.ChatDB().allowFloat and true or false end,
              set = function(v) if ns.ChatDB then ns.ChatDB().allowFloat = v and true or nil; if not v and ns.ChatRedock then ns.ChatRedock() end end end },
            { sec = 5, t = "button", label = "떨어진 탭 다시 붙이기", hl = "rail",
              run = function() if ns.ChatRedock then local a = ns.ChatDB().allowFloat; ns.ChatDB().allowFloat = nil; ns.ChatRedock(); ns.ChatDB().allowFloat = a end end },
        },
    },
    {
        key = "LeelUI_RankUp", builtin = true, cat = "view",
        title = "단축바 주문 레벨", sub = "새 레벨 배우면 알려줘요", icon = "hb_bolt",
        desc = "주문을 새로 배웠는데 단축바에는 아직 낮은 레벨이 있으면 알려줘요.\n바꾸기는 전투 밖에서만 · 매크로 · 아이템 칸은 그대로.",
        onoff = { get = function() return ns.RankDB and ns.RankDB().on end,
                  set = function(v) if ns.RankDB then ns.RankDB().on = v and true or false; if ns.RankRefresh then ns.RankRefresh() end end end },
        items = {
            { sec = 2, t = "toggle", label = "배우면 화면 위 알약", hl = "toast", hint = "\"되살리기 4레벨 배웠어요 · 단축바 1칸은 아직 3레벨\" [바꾸기] [그대로]",
              get = function() return ns.RankDB().toast ~= false end, set = function(v) ns.RankDB().toast = v and true or false end },
            { sec = 2, t = "toggle", label = "단축바 칸에 표시", hl = "mark", hint = "바꿀 때까지 직업 색 테 + ↑ + 지금 레벨 · 마우스를 올리면 툴팁에 한 줄",
              get = function() return ns.RankDB().mark ~= false end, set = function(v) ns.RankDB().mark = v and true or false; if ns.RankRefresh then ns.RankRefresh() end end },
            { sec = 5, t = "button", label = function() return "지금 모두 새 레벨로 (" .. ((ns.RankLowCount and ns.RankLowCount()) or 0) .. "칸)" end, hl = "mark",
              run = function() if ns.RankReplaceAll then ns.RankReplaceAll() end end },
            { sec = 5, t = "button", label = "지금 낮은 칸은 일부러로", hl = "mark", hint = "힐러처럼 낮은 레벨을 일부러 쓰는 칸은 표시를 그만해요",
              run = function() if ns.RankKeepAll then ns.RankKeepAll(); Print("지금 낮은 레벨 칸은 일부러 쓰는 걸로 기억했어요.") end end },
            { sec = 5, t = "button", label = function() local n = 0; for _ in pairs((ns.RankDB and ns.RankDB().keep) or {}) do n = n + 1 end; return "일부러 목록 비우기 (" .. n .. ")" end,
              run = function() if ns.RankKeepClear then ns.RankKeepClear() end end },
        },
    },
    {
        key = "LeelUI_Font", builtin = true, always = true, cat = "view",
        title = "|cfff2b3c2르엘|r 글씨체", sub = "게임 글씨 바꾸기", icon = "hb_font",
        desc = "재접속 = 캐릭터 선택 화면에 갔다 오기\n내 글꼴: LeelUI\\MyFonts 폴더의 '글꼴 넣는 법' 참고",
        items = {
            { sec = 2, t = "choice", label = "기본 글씨", hl = "body", hint = "메뉴, 퀘스트, 툴팁", slot = "body", when = "now" },
            { sec = 2, t = "choice", label = "이름/제목", hl = "name", hint = "이름표, 창 제목", slot = "name", when = "now" },
            { sec = 2, t = "choice", label = "채팅", hl = "chat", hint = "채팅창, 말풍선", slot = "chat", when = "now" },
            { sec = 2, t = "choice", label = "숫자", hl = "num", hint = "피해, 게임 숫자", slot = "num", when = "relog" },
            { sec = 3, t = "choice", label = "글씨 크기", hl = "size", hint = "기본 글씨, 채팅", slot = "size", when = "now" },
            { sec = 3, t = "slider", label = "이름/제목 크기", hl = "name", min = 80, max = 130, step = 5, noPeek = true,
              get = function() return math.floor(((ns.FontOpt and ns.FontOpt("nameK")) or 1) * 100 + 0.5) end,
              set = function(v) if ns.SetFontOpt then ns.SetFontOpt("nameK", v / 100) end end,
              more = "머리 위 이름 · 창 제목 글씨 크기. 머리 위 이름은 다시 불러오기 후 확실히 바뀌어요." },
            { sec = 3, t = "seg", label = "이름 테두리", hl = "name", hint = "밝은 곳에서 이름이 잘 안 보이면",
              options = { { "없음", "none" }, { "얇게", "thin" }, { "굵게", "thick" } },
              get = function() return (ns.FontOpt and ns.FontOpt("outline")) or "none" end,
              set = function(v) if ns.SetFontOpt then ns.SetFontOpt("outline", v) end end },
            { sec = 3, t = "slider", label = "피해 숫자 크기", hl = "num", min = 50, max = 250, step = 10, noPeek = true,
              get = function() return (ns.FontOpt and ns.FontOpt("dmg")) or 100 end,
              set = function(v) if ns.SetFontOpt then ns.SetFontOpt("dmg", v) end end,
              more = "몹 머리 위에 뜨는 피해 · 치유 숫자 크기 (게임 설정 WorldTextScale)" },
            { sec = 5, t = "button", label = "추천 조합", hl = "all", run = function() ns:SetFontPreset(); Print("추천 조합: 기본 글씨와 채팅은 고운돋움, 이름/제목은 주아.") end },
            { sec = 5, t = "button", label = "모두 와우 기본으로", hl = "all", run = function() if ns.SetFontReset then ns:SetFontReset(); Print("글씨를 모두 와우 기본으로 되돌렸어요. 숫자는 재접속 후.") end end },
            { sec = 5, t = "button", label = "다시 불러오기", run = function() ReloadUI() end },
        },
    },
    {
        key = "LeelMap", title = "Leel Map", sub = "세계 지도", icon = "hb_map", slash = "LEELMAP",
        desc = "작은 지도 창, 걸을 때 흐려짐, 좌표, 지역 레벨.\n르엘 UI 쓰는 길드원 위치 (/lmap 길드), 지역 출구 화살표.",
        items = {
            { sec = 2, t = "toggle", label = "작은 창 지도", hl = "win", hint = "화면 전체 대신 작은 창 (지도를 다시 열면 적용)", get = function() return MapDB().mini end, cmd = "작게" },
            { sec = 3, t = "toggle", label = "좌표 줄", hl = "coords", hint = "지도 아래 내 위치 · 커서 좌표", get = function() return MapDB().coords end, cmd = "좌표" },
            { sec = 3, t = "toggle", label = "지역 레벨", hl = "level", hint = "지역 이름 옆 레벨 (난이도 색)", get = function() return MapDB().levels end, cmd = "레벨" },
            { sec = 3, t = "toggle", label = "지역 출구 화살표", hl = "exits", hint = "옆 지역으로 넘어가는 곳에 분홍 동그라미 화살표 (클릭하면 그 지역 지도로)",
              get = function() return MapDB().exits ~= false end,
              set = function(v) if LeelMapDB then LeelMapDB.exits = v and true or false; if LeelMapExits then LeelMapExits.Refresh() end end end },
            { sec = 2, t = "toggle", label = "지도 미리 불러오기", hint = "접속 · 리로드 후 처음 M이 멈추지 않게 (로딩 화면 동안 몰래 한 번 열어 둬요)",
              get = function() return MapDB().preload ~= false end,
              set = function(v) if LeelMapDB then LeelMapDB.preload = v and true or false end end },
            { sec = 3, t = "toggle", label = "확인 안 된 출구도 (대략)", hint = "길목 자료가 없는 지역(와우 포에버 새 지역 등)은 경계로 짐작해서 연하게 \"?\"로",
              get = function() return MapDB().exitGuess ~= false end,
              set = function(v) if LeelMapDB then LeelMapDB.exitGuess = v and true or false; if LeelMapExits then LeelMapExits.Refresh() end end end },
            { sec = 3, t = "toggle", label = "길드원 위치 보기", hl = "guild", hint = "르엘 UI 쓰는 길드원이 지도 · 미니맵에 토끼 점으로",
              get = function() return MapDB().gShow ~= false end,
              set = function(v) if LeelMapDB then LeelMapDB.gShow = v and true or false end end },
            { sec = 3, t = "toggle", label = "지도 창 꾸미기", hl = "skin", hint = "르엘 분홍 테 · 둥근 모서리 (다시 불러오기 후 적용)",
              get = function() return MapDB().skin ~= false end, cmd = "꾸미기" },
            { sec = 4, t = "toggle", label = "걸을 때 흐리게", hl = "fade", hint = "걷는 동안 지도가 옅어져서 앞이 보여요 · 마우스를 올리면 다시 진하게",
              get = function() return MapDB().fade end, cmd = "흐림" },
            { sec = 4, child = true, t = "slider", label = "흐릴 때 진하기", hl = "fade", min = 10, max = 90, step = 5, noPeek = true,
              get = function() return math.floor((tonumber(MapDB().fadeAlpha) or 0.4) * 100 + 0.5) end,
              set = function(v) if LeelMapDB then LeelMapDB.fadeAlpha = v / 100 end end },
            { sec = 4, t = "toggle", label = "내 위치 길드에 알리기", hl = "guild", hint = "끄면 내 위치는 보내지 않아요",
              get = function() return MapDB().gShare ~= false end,
              set = function(v) if LeelMapDB then LeelMapDB.gShare = v and true or false; if LeelMapGuild then LeelMapGuild.Send() end end end },
            { sec = 4, t = "toggle", label = "던전 · 전장에선 숨기기", hl = "guild", hint = "던전 · 전장 안에선 내 위치를 안 보내요",
              get = function() return MapDB().gHideInst ~= false end,
              set = function(v) if LeelMapDB then LeelMapDB.gHideInst = v and true or false; if LeelMapGuild then LeelMapGuild.Send() end end end },
            { sec = 5, t = "slider", label = "지도 창 크기", min = 60, max = 150, step = 5,
              get = function() return tonumber(MapDB().mapScale) or 100 end,
              set = function(v) if LeelMapDB then LeelMapDB.mapScale = v; if LeelMapApplyScale then LeelMapApplyScale() end end end },
            { sec = 5, t = "button", label = "지도 크기 처음으로", run = function()
                  if LeelMapDB then LeelMapDB.mapScale = nil; if LeelMapApplyScale then LeelMapApplyScale() end end end },
            { sec = 5, t = "button", label = "지도 위치 초기화", cmd = "위치" },
            { sec = 5, t = "button", label = "퀘스티 르엘 추천 설정", hint = "지도엔 받을 퀘 ! + 진행 목표 · 반납 아이콘만 끄기",
              run = function() if ns.QuestiePresetAsk then ns.QuestiePresetAsk() end end },
        },
    },
    {
        key = "LeelUI_TotemSet", builtin = true, cat = "party",
        title = "토템 세트", sub = "주술사 · 한 키로 토템", icon = "hb_bolt",
        onoff = { get = function() local t = ns.TotemSetDB and ns.TotemSetDB(); return t and t.on end,
                  set = function(v) local t = ns.TotemSetDB(); t.on = v and true or false; TSApply() end },
        desc = "단축키 하나를 누를 때마다 세트의 다음 토템을 하나씩 깔아요.\n토템 칸 옆 토끼 단추 · 둘레 링 = 깔린 원소. 바꾸기는 전투 밖에서만.",
        items = {
            { t = "toggle", label = "토템 세트 단추 쓰기", hint = "주술사만 보여요",
              get = function() local t = ns.TotemSetDB and ns.TotemSetDB(); return t and t.on end,
              set = function(v) local t = ns.TotemSetDB(); t.on = v and true or false; TSApply() end },
            { t = "seg", label = "고칠 세트", hl = "set", hint = "지금 쓰는 세트도 이걸로",
              options = { { "사냥", 1 }, { "던전", 2 }, { "보스", 3 } },
              get = function() local t = ns.TotemSetDB and ns.TotemSetDB(); return t and t.cur or 1 end,
              set = function(v) ns.TotemSetDB().cur = v; TSApply() end },
            { t = "header", sec = 2, label = function() return "순서 (" .. ((ns.TOTEM_SETNAMES or {})[(ns.TotemSetDB and ns.TotemSetDB() or {}).cur or 1] or "") .. " 세트)" end },
            TSSlot(1), TSSlot(2), TSSlot(3), TSSlot(4),
            { t = "header", sec = 4, label = "단축키" },
            { sec = 4, t = "bind", label = "토템 깔기", hl = "key", hint = "누를 때마다 다음 토템",
              get = function() local t = ns.TotemSetDB and ns.TotemSetDB(); return t and t.key or "" end,
              set = function(v) ns.TotemSetDB().key = v; TSApply() end },
            { sec = 4, t = "bind", label = "토템의 귀환", hl = "key", hint = function() return (ns.TotemRecallKnown and ns.TotemRecallKnown()) and "깐 토템 거두고 마나 일부 돌려받기" or "아직 안 배웠어요" end,
              get = function() local t = ns.TotemSetDB and ns.TotemSetDB(); return t and t.recallKey or "" end,
              set = function(v) ns.TotemSetDB().recallKey = v; TSApply() end },
            { sec = 4, t = "toggle", label = "Shift + 깔기 키 = 다음 세트", hl = "set", hint = "사냥 → 던전 → 보스 (전투 밖 · 깔기 키에 Shift 등이 없을 때)",
              get = function() local t = ns.TotemSetDB and ns.TotemSetDB(); return t and t.shift end,
              set = function(v) ns.TotemSetDB().shift = v and true or false; TSApply() end },
            { sec = 5, t = "button", label = "1번부터 다시", hl = "s1", run = function() TSApply() end },
        },
    },
    {
        key = "LeelUI_Roll", builtin = true, cat = "party",
        title = "주사위 창", sub = "입찰 · 차비 · 토끼 추천", icon = "hb_gift",
        onoff = { get = function() return ns.RollDB and ns.RollDB().on end,
                  set = function(v) ns.RollDB().on = v and true or false; if ns.RollApply then ns.RollApply() end end },
        desc = "템이 나오면 토끼 단추에서 경매 카드가 튀어나와요. 토끼가 내 특성 기준으로 추천 단추를 빛내 줘요 (대신 누르지는 않아요).\n토끼 단추: 클릭 = 기록장 · 오른쪽 클릭 = 경매 창 접기 · 끌기 = 옮기기 · Shift + 휠 = 크기",
        items = {
            { t = "toggle", label = "르엘 주사위 창", hint = "끄면 게임 기본 창",
              get = function() return ns.RollDB and ns.RollDB().on end,
              set = function(v) ns.RollDB().on = v and true or false; if ns.RollApply then ns.RollApply() end end },
            { t = "toggle", label = "토끼 추천", hint = "더 좋은 템 = 입찰 추천 · 못 쓰거나 다른 특성용 = 차비 추천",
              get = function() return ns.RollDB and ns.RollDB().rec end,
              set = function(v) ns.RollDB().rec = v and true or false; if ns.RollApply then ns.RollApply() end end },
            { t = "toggle", label = "파티원 착용 보기", hint = "펼친 카드 아래 · 같은 부위에 파티원이 지금 낀 템 · 템레벨 · 이 템과 차이",
              get = function() return ns.RollDB and ns.RollDB().gear ~= false end,
              set = function(v) ns.RollDB().gear = v and true or false; if ns.RollGearChanged then ns.RollGearChanged() end end },
            { t = "choice", label = "내 역할", hint = "장비 비교와 같이 써요 · 곰 탱을 할 땐 탱커로",
              options = function()
                  local auto = "자동"
                  if ns.GearRoleName and ns.GearRole and ns.GearDB then
                      local cur = ns.GearDB().role
                      ns.GearDB().role = nil
                      auto = "자동 (" .. (ns.GearRoleName[ns.GearRole()] or "") .. ")"
                      ns.GearDB().role = cur
                  end
                  return { { key = "auto", label = auto }, { key = "tank", label = "탱커" }, { key = "melee", label = "근접 딜" },
                           { key = "ranged", label = "원거리 딜" }, { key = "caster", label = "주문 딜" }, { key = "healer", label = "힐러" } }
              end,
              get = function() return (ns.GearDB and ns.GearDB().role) or "auto" end,
              set = function(v) if ns.GearSetRole then ns.GearSetRole(v ~= "auto" and v or nil) end; if ns.RollApply then ns.RollApply() end end },
            { t = "toggle", label = "블리자드 획득 알림 숨기기", hint = "\"다음을 획득했습니다 · 주사위\" 기본 알림 (르엘 \"획득!\" 알림과 겹쳐서)",
              get = function() return ns.RollDB and ns.RollDB().hideWon ~= false end,
              set = function(v) ns.RollDB().hideWon = v and true or false; if ns.RollBlizzWon then ns.RollBlizzWon() end end },
            { t = "seg", label = "결과 보드", hint = "고른 뒤 알약 아래로 파티원 숫자",
              options = { { "끔", "off" }, { "마우스 올리면", "mine" }, { "항상 펼치기", "all" } },
              get = function() return ns.RollDB and ns.RollDB().board or "mine" end,
              set = function(v) ns.RollDB().board = v; if ns.RollApply then ns.RollApply() end end },
            { noPeek = true, t = "slider", label = "주사위 창 · 토끼 단추 크기", min = 60, max = 150,
              get = function() return ns.RollDB and ns.RollDB().scale or 100 end,
              set = function(v) if ns.RollSetScale then ns.RollSetScale(v) end end },
            { t = "toggle", label = "토끼 단추 항상 보이기", hint = "끄면 파티 · 공격대에서만 · 클릭 = 기록장",
              get = function() return ns.RollDB and ns.RollDB().badgeAlways end,
              set = function(v) ns.RollDB().badgeAlways = v and true or false; if ns.RollPaintBadge then ns.RollPaintBadge() end end },
            { t = "seg", label = "파티 인사 말풍선", hint = "파티에 들어가면 토끼가 인사 · 블랙리스트가 있으면 빨간 풍선",
              options = { { "끔", "off" }, { "짧게", "short" }, { "전부", "all" } },
              get = function() return ns.RollDB and ns.RollDB().greet or "all" end,
              set = function(v) ns.RollDB().greet = v end },
            { t = "button", label = "인사 미리 보기", run = function() if ns.RollGreetTest then ns.RollGreetTest() end end },
            { t = "toggle", label = "블랙리스트 굴림 알림", hint = "블랙리스트가 입찰 · 차비하면 주사위 창 위에 빨간 띠 (나만 보여요)",
              get = function() local d = ns.RollDB and ns.RollDB(); return d and d.blackAlert ~= false end,
              set = function(v) ns.RollDB().blackAlert = v and true or false end },
            { t = "choice", label = "경고음", hint = "블랙리스트가 파티에 들어올 때 · 입찰/차비할 때", child = true, depOn = function() local d = ns.RollDB and ns.RollDB(); return d and d.blackAlert ~= false end,
              options = function() return { { key = "warn", label = "르엘 경고 (띠디 띠디)" }, { key = "chime", label = "르엘 종 (맑은 두 음)" },
                          { key = "ding", label = "게임 공격대 경보" }, { key = "alarm", label = "게임 알람" }, { key = "off", label = "끔" } } end,
              get = function() local d = ns.RollDB and ns.RollDB(); return d and d.blackSound or "warn" end,
              set = function(v) ns.RollDB().blackSound = v; if ns.RollBlackSound then ns.RollBlackSound() end end },
            { t = "toggle", label = "채팅창에도 한 줄", child = true, depOn = function() local d = ns.RollDB and ns.RollDB(); return d and d.blackAlert ~= false end,
              get = function() local d = ns.RollDB and ns.RollDB(); return d and d.blackChat ~= false end,
              set = function(v) ns.RollDB().blackChat = v and true or false end },
            { t = "button", label = "블랙리스트 알림 미리 보기", run = function() if ns.RollBlackTest then ns.RollBlackTest() end end },
                        { t = "button", label = "주사위 기록장", run = function() if ns.RollLog then ns.RollLog(true) end end },
            { t = "button", label = "블랙리스트", run = function() if ns.BlackOpen then ns.BlackOpen(true) end end },
            { t = "button", label = "미리 보기", run = function() if ns.RollTest then ns.RollTest() end end },
            { t = "button", label = "처음 자리 · 크기로", run = function() SlashCmdList.LEELROLL("위치") end },
        },
    },
    {
        key = "LeelUI_Party", builtin = true, cat = "party",
        title = "파티 프레임", sub = "둥근 파티 창", icon = "hb_party",
        desc = "르엘 파티 프레임. 왼쪽 스위치는 다시 불러오기 후 적용.\n자리 옮기기는 아래 '이동 모드'.",
        onoff = { reload = true, get = function() return ns.db.party end,
                  set = function(v) ns.db.party = v end },
        items = {
            { moveOnly = true, t = "slider", label = "파티 프레임 크기", min = 50, max = 150,
              get = function() return math.floor((ns.db.partyScale or 0.75) * 100 + 0.5) end,
              set = function(v)
                  ns:SetPartyScale(v / 100)
                  if InCombatLockdown() then Print("전투가 끝나면 파티 프레임 크기가 바뀌어요.") end
              end },
            { t = "header", label = "배치" },
            { t = "seg", label = "파티 인원", hint = "5인 = 내 칸도 같이 (분홍 테) · 2×2면 탱커 칸이 위에 넓게",
              options = { { "4인 · 나 빼고", "four" }, { "5인 · 나 포함", "five" } },
              get = function() return ns.db.partyFive and "five" or "four" end,
              set = function(v) ns.db.partyFive = (v == "five"); if ns.ApplyPartyFive then ns:ApplyPartyFive() end end },
            { child = true, t = "seg", label = "내 칸 자리", hint = "5인일 때 · 가로면 맨 왼쪽 / 맨 오른쪽",
              options = { { "맨 위", "top" }, { "맨 아래", "bottom" } },
              get = function() return ns.db.partyMePos or "top" end,
              set = function(v) ns.db.partyMePos = v; if ns.ApplyPartyFive then ns:ApplyPartyFive() end end },
            { t = "seg", label = "정렬",
              options = { { "가로", "row" }, { "세로", "col" }, { "2×2", "grid" } },
              get = function() return ns.db.partyLayout or "row" end,
              set = function(v) ns.db.partyLayout = v; PartyCells() end },
            { t = "slider", label = "칸 가로", noPeek = true, min = 100, max = 280, fmt = "%d",
              get = function() return tonumber(ns.db.partyW) or 152 end,
              set = function(v) ns.db.partyW = v; PartyCells() end },
            { t = "slider", label = "칸 세로", noPeek = true, min = 36, max = 110, fmt = "%d",
              get = function() return tonumber(ns.db.partyH) or 76 end,
              set = function(v) ns.db.partyH = v; PartyCells() end },
            { t = "slider", label = "칸 사이", noPeek = true, min = 0, max = 24, fmt = "%d",
              get = function() return tonumber(ns.db.partyGap) or 8 end,
              set = function(v) ns.db.partyGap = v; PartyCells() end },
            { adv = true, t = "button", label = "세부 설정 처음으로",
              run = function()
                  ns.db.partyW, ns.db.partyH, ns.db.partyGap, ns.db.partyNameLen, ns.db.partyHp, ns.db.partyAuras = nil, nil, nil, nil, nil, nil
                  PartyCells()
              end },
            { adv = true, t = "toggle", label = "기본 파티 창 숨기기", hint = "다시 불러오기 후 적용",
              get = function() return ns.db.partyHideBlizzard ~= false end,
              set = function(v) ns.db.partyHideBlizzard = v; StaticPopup_Show("LEELUI_HUB_RELOAD") end },
            { adv = true, t = "button", label = "위치 초기화",
              run = function() ns:ResetPartyPosition(); Print("파티 프레임 위치를 처음대로 돌렸어요.") end },
            { t = "header", label = "보이는 것" },
            { t = "seg", label = "이름", hint = "길면 자르기",
              options = { { "4글자", 4 }, { "6글자", 6 }, { "전부", 0 } },
              get = function() return tonumber(ns.db.partyNameLen) or 0 end,
              set = function(v) ns.db.partyNameLen = v; PartyCells() end },
            { t = "seg", label = "체력 글씨",
              options = { { "없음", "none" }, { "%", "pct" }, { "숫자", "num" }, { "잃은 만큼", "deficit" } },
              get = function() return ns.db.partyHp or "pct" end,
              set = function(v) ns.db.partyHp = v; PartyCells() end },
            { t = "toggle", label = "버프 · 디버프 보이기", hint = "내가 건 버프 (왼쪽 아래) · 해제할 디버프 (오른쪽 위 해제 칸)",
              get = function() return ns.db.partyAuras ~= false end,
              set = function(v) ns.db.partyAuras = v and true or false; PartyCells() end },
            { t = "header", label = "알림" },
            { t = "toggle", label = "해제할 디버프 알림", hint = "내가 풀 수 있는 디버프: 체력 빈 칸이 그 색으로 맥박 + 오른쪽 위 해제 칸 (종류별 색)",
              get = function() return ns.db.partyDispelFx ~= false end,
              set = function(v) ns.db.partyDispelFx = v and true or false; PartyCells() end },
            { t = "toggle", label = "해제 칸 클릭 = 바로 해제", hint = "켜진 해제 칸을 누르면 그 사람한테 내 해제 주문 · 전투 중엔 빈 칸도 눌리니 조심",
              get = function() return ns.db.partyDispelClick ~= false end,
              set = function(v)
                  ns.db.partyDispelClick = v and true or false
                  if InCombatLockdown() then print(ns.L("|cfff2b3c2[르엘 파티]|r 전투가 끝나면 적용돼요.")) end
                  if ns.PartyArmSlots then ns.PartyArmSlots(false) end
              end },
        },
    },
    {
        key = "LeelUI_LFG", builtin = true, cat = "party",
        title = "파티 찾기", sub = "신청한 사람 위치 · 거리", icon = "hb_search",
        desc = "게임 파티 찾기 목록에서 신청한 사람이 어디 있는지 보여줘요.\n던전 이름 옆에 지역 · 메모 옆에 거리 말 (같은 곳 · 던전 안 · 입구 · 멀리).",
        onoff = { get = function() return ns.db.lfgLoc ~= false end,
                  set = function(v) ns.db.lfgLoc = v and true or false; if ns.LFGLocRefresh then ns.LFGLocRefresh() end end },
        items = {
            { t = "toggle", label = "지역 이름", hint = "던전 이름 옆 \"· 티리스팔 숲\"", hl = "zone",
              get = function() return ns.db.lfgZone ~= false end,
              set = function(v) ns.db.lfgZone = v and true or false; if ns.LFGLocRefresh then ns.LFGLocRefresh() end end },
            { t = "toggle", label = "거리 말", hint = "메모 옆 같은 곳 · 던전 안 · 입구 · 멀리 (색)", hl = "tag",
              get = function() return ns.db.lfgTag ~= false end,
              set = function(v) ns.db.lfgTag = v and true or false; if ns.LFGLocRefresh then ns.LFGLocRefresh() end end },
            { t = "toggle", label = "모르는 위치는 /누구로 찾기", hint = "게임이 지역을 안 주는 사람만 · 검색할 때 레벨대로 한 번 (채팅엔 안 떠요)", hl = "who",
              get = function() return ns.db.lfgWho ~= false end,
              set = function(v) ns.db.lfgWho = v and true or false end,
              more = "게임이 지역을 알려주지 않는 신청자는 /누구 검색으로 찾아 채워요. 8초에 한 번까지만 해요." },
        },
    },
    {
        key = "LeelMark", title = "Leel Mark", sub = "파티 징", icon = "hb_mark", slash = "LEELMARK",
        desc = "자동 징 찍기 바. 단축키는 게임 메뉴 > 단축키 > 애드온.",
        items = {
            { sec = 2, t = "seg", label = "징 바", hl = "bar", hint = "숨겨도 단축키는 동작 (게임 메뉴 > 단축키 > 애드온)",
              options = { { "파티일 때", "group" }, { "항상", "always" }, { "숨기기", "never" } },
              get = function() return MarkDB().show or "group" end,
              set = function(v)
                  if not LeelMarkDB then return end
                  if v == "never" then Slash("LEELMARK", "숨기기") return end
                  LeelMarkDB.show = (v == "group") and "always" or "group"   -- "보이기"는 둘 사이를 바꿔요
                  Slash("LEELMARK", "보이기")
              end },
            { sec = 2, t = "seg", label = "자동 찍기 범위", hl = "auto", hint = "[자동] 단추 · 단축키 (전투 밖)",
              options = { { "대상 둘레 무리", "pack" }, { "보이는 적 전부", "all" } },
              get = function() return MarkDB().packOnly == false and "all" or "pack" end,
              set = function(v) if LeelMarkDB then LeelMarkDB.packOnly = (v == "pack") end end },
            { sec = 3, t = "slider", label = "바 크기", hl = "bar", min = 60, max = 160, step = 5, noPeek = true,
              get = function() return math.floor((MarkDB().scale or 1) * 100 + 0.5) end,
              set = function(v)
                  if not LeelMarkDB then return end
                  LeelMarkDB.scale = v / 100
                  local bb = _G.LeelMarkBar
                  if bb and not InCombatLockdown() then
                      bb:SetScale(v / 100)
                      local ps = LeelMarkDB.pos
                      if ps then bb:ClearAllPoints(); bb:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ps[1], ps[2]) end
                  end
              end },
            { sec = 3, t = "toggle", label = "이름표에 잡는 순서", hl = "order", hint = "르엘 이름표: 징 옆 순서 숫자 · 앞 몹이 죽으면 다음! 반짝 · CC 징은 자물쇠",
              get = function() return MarkDB().order ~= false end,
              set = function(v) if LeelMarkDB then LeelMarkDB.order = v and true or false end; if ns.RefreshNameplates then ns:RefreshNameplates() end end },
            { sec = 4, t = "toggle", label = "파티 채팅 알림", hl = "auto", hint = "[자동]으로 찍을 때 파티 채팅에 한 줄", get = function() return MarkDB().announce end, cmd = "알림" },
            { sec = 5, t = "button", label = "징 약속 처음대로", hl = "order", hint = "징 아래 글씨로 바꾼 약속을 모두 자동으로",
              run = function() if LeelMarkDB then LeelMarkDB.roles = nil end end },
            { sec = 5, t = "button", label = "바 위치 초기화", cmd = "위치" },
        },
    },
    {
        key = "LeelSpot", title = "Leel Spot", sub = "퀘스트 물건", icon = "hb_spot", slash = "LEELSPOT",
        desc = "퀘스트 물건 위 토끼 이름표와 분홍 선.",
        items = {
            { sec = 2, t = "toggle", label = "이름표 켜기", hl = "pill", hint = "상호작용 키가 고른 물건 위에 토끼 알약",
              get = function() return SpotDB().on ~= false end,
              set = function(v) Slash("LEELSPOT", v and "켜기" or "끄기") end },
            { sec = 2, t = "toggle", label = "퀘스트 물건만", hl = "other", hint = "끄면 모든 물건에 표시 (퀘스트 물건이 아니면 회색)",
              get = function() return not SpotDB().all end, cmd = "퀘만" },
            { sec = 2, t = "toggle", label = "진행도 숫자", hl = "prog", hint = "알약 오른쪽 \"3/8\"",
              get = function() return SpotDB().prog ~= false end, set = function(v) SpotSet("prog", v and true or false) end },
            { sec = 3, t = "slider", label = "이름표 크기", hl = "pill", min = 60, max = 200, step = 10, noPeek = true,
              get = function() return math.floor((SpotDB().size or 1) * 100 + 0.5) end, set = function(v) SpotSet("size", v / 100) end },
            { sec = 3, t = "slider", label = "이름표 높이", hl = "pill", min = -40, max = 80, step = 5, fmt = "%d", noPeek = true,
              get = function() return SpotDB().y or 0 end, set = function(v) SpotSet("y", v) end },
            { sec = 3, t = "toggle", label = "물건 가리키는 선", hl = "stem",
              get = function() return (SpotDB().stem or 34) > 0 end,
              set = function(v)
                  if not LeelSpotDB then return end
                  if v then SpotSet("stem", LeelSpotDB.stemLen or 34) else LeelSpotDB.stemLen = (LeelSpotDB.stem or 34) > 0 and LeelSpotDB.stem or LeelSpotDB.stemLen; SpotSet("stem", 0) end
              end },
            { sec = 3, child = true, t = "slider", label = "선 길이", hl = "stem", min = 10, max = 150, step = 2, fmt = "%d", noPeek = true,
              get = function() local n = SpotDB().stem or 34; return n > 0 and n or (SpotDB().stemLen or 34) end,
              set = function(v) if (SpotDB().stem or 34) > 0 then SpotSet("stem", v) elseif LeelSpotDB then LeelSpotDB.stemLen = v end end },
            { sec = 3, t = "toggle", label = "숨쉬는 빛", hl = "halo", hint = "퀘스트 물건이면 토끼 둘레 분홍 빛",
              get = function() return SpotDB().halo ~= false end, set = function(v) SpotSet("halo", v and true or false) end },
            { sec = 3, t = "toggle", label = "멀리서도 반짝이", hl = "far", hint = "퀘스트 물건에 게임 반짝이 (테두리 강조 대신)",
              get = function() return SpotDB().sparkle ~= false end, cmd = "반짝" },
            { sec = 5, t = "button", label = "점검", cmd = "점검" },
        },
    },
    {
        key = "ForgLeveling", title = "퀘스트 목록", sub = "Leel Quest · 셋 중 하나", icon = "hb_guide", slash = "FORGLEVELING",
        always = true,
        desc = "화면에 띄울 퀘스트 목록을 하나 골라요.\nLeel Quest는 받은 퀘 중 고른 것을 가까운 순서로 길 안내해요. /퀘판",
        items = {
            { t = "header", label = "화면에 띄울 목록 (하나만)" },
            { t = "toggle", label = "블리자드 기본", hl = "m_blizz",
              get = function() return ns.QuestTrackerMode and ns.QuestTrackerMode() == "blizz" end,
              set = function() ns:SetQuestTrackerMode("blizz") end },
            { t = "toggle", label = "Questie 추적창  (다시 불러오기)", hl = "m_questie",
              get = function() return ns.QuestTrackerMode and ns.QuestTrackerMode() == "questie" end,
              set = function() ns:SetQuestTrackerMode("questie") ; StaticPopup_Show("LEELUI_HUB_RELOAD") end },
            { t = "toggle", label = "Leel Quest", hl = "m_guide", hint = "고른 퀘를 가까운 순서로 길 안내 (당근 방향 · 거리)",
              get = function() return ns.QuestTrackerMode and ns.QuestTrackerMode() == "guide" end,
              set = function() ns:SetQuestTrackerMode("guide") end },
            { t = "header", label = function()
                  return LQOn() and "Leel Quest" or "Leel Quest  |cff9d8a80· Leel Quest를 고르면 바꿀 수 있어요|r" end,
              btn = { label = "창 자리 처음대로", dep = function() return LQOn() end,
                      run = function() Slash("FORGLEVELING", "초기화") end } },
            { sec = 5, t = "toggle", label = "L 키로 Leel Quest 열기", hl = "head", hint = "Shift+L = 블리자드 퀘스트 목록 (전투가 끝나면 적용)", dep = function() return LQOn() end,
              get = function() return GuideDB().lKey ~= false end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.lKey = v and true or false; if LeelQuestApplyKeys then LeelQuestApplyKeys() end end end },
            { sec = 3, t = "toggle", label = "같은 NPC 반납은 한 상자로", hl = "box", hint = "\"토끼상인에게 반납 2\" 노란 상자", dep = function() return LQOn() end,
              get = function() return GuideDB().groupTurnin ~= false end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.groupTurnin = v and true or false; if LeelQuestRefresh then LeelQuestRefresh() end end end },
            { sec = 3, t = "toggle", label = "완료 도장 효과", hl = "stamp", hint = "퀘를 끝내면 토끼 도장 쾅", dep = function() return LQOn() end,
              get = function() return not GuideDB().fxOff end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.fxOff = (not v) or nil end end },
            { sec = 3, t = "toggle", label = "M 키 지도에서 퀘스트 목록 칸 숨기기", hl = "map", hint = "Shift+M = 목록이 붙은 원래 지도", dep = function() return LQOn() end,
              get = function() return GuideDB().mapOnly ~= false end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.mapOnly = v and true or false; if LeelQuestApplyKeys then LeelQuestApplyKeys() end end end },
            { sec = 3, t = "toggle", label = "지도 · 미니맵에 길 그리기", hl = "map", hint = "번호 동그라미 + 점선 길", dep = function() return LQOn() end,
              get = function() return GuideDB().mapLines ~= false end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.mapLines = v and true or false end end },
            { sec = 2, t = "toggle", label = "파티원 진행도", hl = "party", hint = "파티일 때 같은 퀘 하는 파티원 얼굴 + 진행 고리 · 얼굴에 마우스 = 목표별 숫자", dep = function() return LQOn() end,
              get = function() return GuideDB().partyFaces ~= false end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.partyFaces = v and true or false; if LeelQuestRefresh then LeelQuestRefresh() end end end,
              more = "진행 숫자는 파티원도 르엘 UI를 쓸 때만 보여요. 아니면 같은 퀘라는 얼굴만 (고리는 회색)." },
            { sec = 2, child = true, t = "toggle", label = "진행 고리", hl = "party", hint = "끄면 얼굴만", dep = function() return LQOn() end,
              get = function() return GuideDB().partyRing ~= false end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.partyRing = v and true or false; if LeelQuestRefresh then LeelQuestRefresh() end end end },
            { sec = 2, child = true, t = "toggle", label = "다 한 파티원은 숨기기", hl = "party", hint = "목표를 다 한 파티원 얼굴은 빼요", dep = function() return LQOn() end,
              get = function() return GuideDB().partyHideDone and true or false end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.partyHideDone = v and true or nil; if LeelQuestRefresh then LeelQuestRefresh() end end end },
            { sec = 2, child = true, t = "toggle", label = "파티원이 다 하면 알림", hl = "party", hint = "같은 퀘를 파티원이 다 하면 채팅창에 한 줄 + 띵", dep = function() return LQOn() end,
              get = function() return GuideDB().partyToast and true or false end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.partyToast = v and true or nil end end },
            { sec = 2, child = true, t = "toggle", label = "내 진행도 보내기", hl = "party", hint = "끄면 파티원 창에 내 진행 숫자가 안 보여요 (얼굴은 게임이 보여줘요)", dep = function() return LQOn() end,
              get = function() return GuideDB().partyShare ~= false end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.partyShare = v and true or false end
                  if _G.LeelQuestShareChanged then _G.LeelQuestShareChanged() end end },
            { sec = 2, t = "seg", label = "그 밖의 퀘", hl = "other", hint = "길에 안 넣은 받은 퀘 (창 아래쪽)", dep = function() return LQOn() end,
              options = { { "접기", "fold" }, { "펴기", "open" } },
              get = function() return GuideDB().trkOtherFold and "fold" or "open" end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.trkOtherFold = (v == "fold") or nil; if LeelQuestRefresh then LeelQuestRefresh() end end end },
            { sec = 2, t = "slider", label = "그 밖의 퀘 최대 줄", hl = "other", min = 3, max = 20, step = 1, fmt = "%d줄", noPeek = true, child = true,
              dep = function() return LQOn() end, depOn = function() return not GuideDB().trkOtherFold end,
              get = function() return GuideDB().trkOtherMax or 10 end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.trkOtherMax = v; if LeelQuestRefresh then LeelQuestRefresh() end end end },
            { sec = 4, t = "toggle", label = "새 지역 알림", hl = "zone", hint = "새 지역에 오면 창 위에 분홍 띠 (여기서 할 퀘 수)", dep = function() return LQOn() end,
              get = function() return GuideDB().zoneToast ~= false end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.zoneToast = v and true or false end end },
            { sec = 4, t = "toggle", label = "퀘스트 소리", hl = "head", hint = "목표 달성 · 완료 · 근처 반납", dep = function() return LQOn() end,
              get = function() return not GuideDB().sndOff end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.sndOff = (not v) or nil end end },
            { sec = 4, t = "toggle", label = "완료된 퀘 반납을 길에 자동으로", hl = "rows", dep = function() return LQOn() end,
              get = function() return GuideDB().autoTurnin ~= false end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.autoTurnin = v and true or false end end },
            { sec = 4, t = "toggle", label = "근처 반납 알림", hl = "near", hint = "약 150m 안에 반납할 NPC가 있으면 알려줘요", dep = function() return LQOn() end,
              get = function() return GuideDB().nearTurnin ~= false end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.nearTurnin = v and true or false; if LeelQuestRefresh then LeelQuestRefresh() end end end },
            { sec = 4, t = "toggle", label = "근처(150m) 반납을 길 앞으로", hl = "near", hint = "끄면 길은 그대로 · 창 위에 노란 띠로만", child = true, dep = function() return LQOn() end,
              depOn = function() return GuideDB().nearTurnin ~= false end,
              get = function() return GuideDB().autoNear ~= false end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.autoNear = v and true or false; if LeelQuestRefresh then LeelQuestRefresh() end end end },
            { sec = 4, t = "toggle", label = "파티 땐 어려운 퀘도 길에", hl = "rows", hint = "파티 중이면 정예 · 파티 퀘도 길 순서에 (던전 퀘는 던전 안에서만)", dep = function() return LQOn() end,
              get = function() return GuideDB().partyHard ~= false end,
              set = function(v) if ForgLevelingDB then ForgLevelingDB.partyHard = v and true or false; if LeelQuestRefresh then LeelQuestRefresh() end end end },
            { sec = 5, t = "button", label = "고르기 판 열기", cmd = "", dep = function() return LQOn() end },
            { sec = 5, t = "button", label = "소리 들어 보기", cmd = "소리", dep = function() return LQOn() end },
        },
    },
    {
        key = "LeelUI_Shop", builtin = true, cat = "util",
        title = "상점 토끼", sub = "자동 수리, 잡템 판매", icon = "hb_shop",
        desc = "상인 창을 열면 알아서. Shift 누른 채 열면 이번엔 쉬어요.\n안 팔고 싶은 회색 템은 가방에서 Alt+클릭.",
        onoff = { get = function() return ns.ShopDB().on end,
                  set = function(v) ns.ShopDB().on = v end },
        items = {
            { sec = 2, t = "toggle", label = "자동 수리", hl = "repair", hint = "돈이 모자라면 건너뛰어요",
              get = function() return ns.ShopDB().repair end, set = function(v) ns.ShopDB().repair = v end },
            { sec = 2, t = "toggle", label = "회색 잡템 자동 판매", hl = "sell", hint = "안 팔고 싶은 회색 템은 가방에서 Alt+클릭",
              get = function() return ns.ShopDB().sell end, set = function(v) ns.ShopDB().sell = v end },
            { sec = 3, t = "toggle", label = "판매 결과 알려주기", hl = "report", hint = "상인 창 위에 작은 판 + 채팅 한 줄",
              get = function() return ns.ShopDB().report end, set = function(v) ns.ShopDB().report = v end },
            { sec = 4, t = "seg", label = "쉬는 키", hl = "all", hint = "이 키를 누른 채 상인 창을 열면 이번엔 쉬어요",
              options = { { "Shift", "shift" }, { "Ctrl", "ctrl" }, { "Alt", "alt" } },
              get = function() return ns.ShopDB().pauseKey or "shift" end, set = function(v) ns.ShopDB().pauseKey = v end },
            { sec = 5, t = "button", hl = "sell", label = function() return "안 팔기 목록 비우기 (" .. ns:ShopKeepCount() .. ")" end,
              run = function() ns:ShopClearKeep() end },
        },
    },
    {
        key = "LeelUI_Quest", builtin = true, cat = "util",
        title = "퀘스트 자동", sub = "받기, 완료", icon = "hb_bolt",
        desc = "말만 걸면 받고, 고를 보상이 없으면 완료까지. 보상 고르기는 직접.\n쉬는 키(기본 Shift)를 누른 채 말 걸면 그때만 쉬어요.",
        onoff = { get = function() return ns.QuestDB().on end, set = function(v) ns.QuestDB().on = v end },
        items = {
            { sec = 2, t = "toggle", label = "자동 수락", hl = "accept", hint = "대화창의 ! 퀘를 받아요",
              get = function() return ns.QuestDB().accept end, set = function(v) ns.QuestDB().accept = v end },
            { sec = 2, t = "toggle", label = "자동 완료", hl = "complete", hint = "? 퀘를 보고 · 보상을 골라야 하면 멈춰요",
              get = function() return ns.QuestDB().complete end, set = function(v) ns.QuestDB().complete = v end },
            { sec = 2, t = "toggle", label = "회색 퀘스트 건너뛰기", hl = "trivial", hint = "내 레벨보다 한참 낮은 퀘는 안 받아요",
              get = function() return ns.QuestDB().skipTrivial end, set = function(v) ns.QuestDB().skipTrivial = v end },
            { sec = 2, t = "toggle", label = "정예 · 파티 퀘는 직접", hl = "group", hint = "권장 인원 2명 이상인 퀘는 자동으로 안 받아요",
              get = function() return ns.QuestDB().skipGroup end, set = function(v) ns.QuestDB().skipGroup = v and true or false end },
            { sec = 2, t = "toggle", label = "대화 하나뿐이면 넘기기", hl = "gossip", hint = "퀘스트 없이 대화 고르기 하나만 있을 때",
              get = function() return ns.QuestDB().gossip end, set = function(v) ns.QuestDB().gossip = v end },
            { sec = 3, t = "toggle", label = "가장 비싼 보상 표시", hl = "best", hint = "팔 때 제일 비싼 보상에 분홍 테 + 값",
              get = function() return ns.QuestDB().best end, set = function(v) ns.QuestDB().best = v end },
            { sec = 3, t = "toggle", label = "받음 · 완료 알림", hl = "toast", hint = "화면 위 가운데 작은 분홍 알약",
              get = function() return ns.QuestDB().toast ~= false end, set = function(v) ns.QuestDB().toast = v and true or false end },
            { sec = 3, child = true, t = "toggle", label = "완료 알림에 경험치", hl = "xp",
              get = function() return ns.QuestDB().toastXp ~= false end, set = function(v) ns.QuestDB().toastXp = v and true or false end },
            { sec = 4, t = "seg", label = "쉬는 키", hl = "pause", hint = "이 키를 누른 채 말 걸면 그때만 자동이 쉬어요",
              options = { { "Shift", "shift" }, { "Ctrl", "ctrl" }, { "Alt", "alt" } },
              get = function() return ns.QuestDB().pauseKey or "shift" end, set = function(v) ns.QuestDB().pauseKey = v end },
            { sec = 4, t = "toggle", label = "파티원이 나눈 퀘도 받기", hl = "shared", hint = "끄면 파티원이 공유한 퀘는 직접 받아요",
              get = function() return ns.QuestDB().shared ~= false end, set = function(v) ns.QuestDB().shared = v and true or false end },
        },
    },
    {
        key = "LeelUI_Err", builtin = true, always = true, cat = "start",
        title = "오류 알리기", sub = "캡처 · 코드 복사로 알려주기", icon = "hb_bell",
        desc = "애드온 오류가 나면 게임 기본 창 대신 토끼 알림이 떠요.\n'보기' → 카드를 캡처하거나 '코드 복사' → 채채TV 커뮤니티에 붙여넣으면 끝. (/르엘오류)",
        items = {
            { t = "seg", label = "알림 방식", hint = "끄기 = 알림 없이 기록만",
              options = { { "토끼 알림", "bunny" }, { "게임 기본 창", "blizz" }, { "끄기", "off" } },
              get = function() return ns.db.errMode or "bunny" end,
              set = function(v) ns.db.errMode = v end,
              more = "BugSack을 쓰면 BugSack이 그대로 받아요 · 빨간 오류 창(/console scriptErrors 1)을 켠 사람도 그대로예요." },
            { t = "seg", label = "다른 애드온 오류도", hint = "르엘 말고 Questie · DBM 같은 애드온",
              options = { { "알리기", "all" }, { "기록만", "log" } },
              get = function() return ns.db.errOthers or "all" end,
              set = function(v) ns.db.errOthers = v end },
            { t = "button", label = function() local n = ns.Err and #ns.Err.Log() or 0; return "최근 오류 보기 (" .. n .. ")" end,
              run = function() if ns.Err then ns.Err.Open(1) end end },
            { t = "button", label = "알림 미리 보기", run = function() if ns.Err then ns.Err.Test() end end },
            { t = "button", label = "기록 비우기", run = function() if ns.Err then ns.Err.Clear() end end },
        },
    },
    {
        key = "LeelUI_Profile", builtin = true, always = true, cat = "util",
        title = "설정 나누기", sub = "내보내기 · 가져오기", icon = "hb_apps",
        desc = "르엘 UI · 지도 · 징 · 반짝 상자 설정을 글자 한 줄로.\n친구에게 보내거나 다른 컴퓨터·캐릭터로 옮길 때 써요. (/르엘설정)",
        share = true,   -- 그림은 Profile.lua (ns.HubSharePane)
        items = {},
    },
    {
        key = "LeelUI_QTracker", builtin = true, always = true, cat = "util",
        title = "퀘스트 목록", sub = "셋 중 하나만", icon = "hb_quest",
        desc = "화면에 띄울 퀘스트 목록을 하나만 골라요.\n고르지 않은 둘은 자동으로 숨겨요.",
        items = {
            { t = "toggle", label = "블리자드 기본", hint = "미니맵 아래 기본 퀘스트 목록",
              get = function() return ns.QuestTrackerMode and ns.QuestTrackerMode() == "blizz" end,
              set = function() ns:SetQuestTrackerMode("blizz") end },
            { t = "toggle", label = "Questie 추적창", hint = "Questie를 켰을 때만 (다시 불러오기 후 적용)",
              get = function() return ns.QuestTrackerMode and ns.QuestTrackerMode() == "questie" end,
              set = function() ns:SetQuestTrackerMode("questie") ; StaticPopup_Show("LEELUI_HUB_RELOAD") end },
            { t = "toggle", label = "르엘 퀘스트 판", hint = "오늘 할 퀘 따라가기 창",
              get = function() return ns.QuestTrackerMode and ns.QuestTrackerMode() == "guide" end,
              set = function() ns:SetQuestTrackerMode("guide") end },
        },
    },
    {
        key = "LeelUI_QItem", builtin = true, cat = "util",
        title = "퀘템 알림", sub = "이 몹엔 이 템", icon = "hb_bell",
        desc = "퀘스트에 써야 하는 템이 가방에 있고 지금 대상이 그 몹이면\n이름표 위와 대상 창 옆에 템이 떠요. 누르면 바로 써요.\n한 번 쓴 몹은 기억해서 다음부터 바로 알려줘요.",
        onoff = { get = function() return ns.QItemDB and ns.QItemDB().on end,
                  set = function(v) if ns.QItemDB then ns.QItemDB().on = v; if ns.QuestItemRefresh then ns.QuestItemRefresh() end end end },
        items = {
            { sec = 2, t = "toggle", label = "이름표 위 아이콘", hl = "plate", hint = "대상 몹 이름표 위에 템 그림",
              get = function() return ns.QItemDB().plate ~= false end, set = function(v) ns.QItemDB().plate = v and true or false; if ns.QItemApply then ns.QItemApply() end end },
            { sec = 2, t = "toggle", label = "대상 창 옆 단추", hl = "btn", hint = "누르면 바로 쓰기 · 오른쪽 클릭 = 이 몹에선 그만 보기",
              get = function() return ns.QItemDB().btn ~= false end, set = function(v) ns.QItemDB().btn = v and true or false; if ns.QItemApply then ns.QItemApply() end end },
            { sec = 2, child = true, t = "toggle", label = "남은 개수", hl = "count", hint = "단추 아래 \"쓰기 3\"",
              get = function() return ns.QItemDB().count ~= false end, set = function(v) ns.QItemDB().count = v and true or false; if ns.QItemApply then ns.QItemApply() end end },
            { sec = 3, t = "seg", label = "단추 자리", hl = "btn",
              options = { { "오른쪽", "right" }, { "왼쪽", "left" }, { "아래", "below" } },
              get = function() return ns.QItemDB().side or "right" end, set = function(v) ns.QItemDB().side = v; if ns.QItemApply then ns.QItemApply() end end },
            { sec = 3, t = "slider", label = "단추 크기", hl = "btn", min = 28, max = 56, step = 2, fmt = "%d", noPeek = true,
              get = function() return ns.QItemDB().bsz or 38 end, set = function(v) ns.QItemDB().bsz = v; if ns.QItemApply then ns.QItemApply() end end },
            { sec = 3, t = "slider", label = "이름표 아이콘 크기", hl = "plate", min = 18, max = 40, step = 2, fmt = "%d", noPeek = true,
              get = function() return ns.QItemDB().psz or 26 end, set = function(v) ns.QItemDB().psz = v; if ns.QItemApply then ns.QItemApply() end end },
            { sec = 3, t = "toggle", label = "반짝임", hl = "glow", hint = "아이콘 둘레 분홍 빛이 천천히 숨 쉬어요",
              get = function() return ns.QItemDB().glow ~= false end, set = function(v) ns.QItemDB().glow = v and true or false; if ns.QItemApply then ns.QItemApply() end end },
            { sec = 4, t = "toggle", label = "쓴 몹 기억하기", hl = "learn", hint = "한 번 쓴 몹은 다음부터 바로 알려줘요",
              get = function() return ns.QItemDB().learn ~= false end, set = function(v) ns.QItemDB().learn = v and true or false end },
            { sec = 5, t = "button", label = function() local n = 0; for _, t in pairs(ns.QItemDB().no or {}) do for _ in pairs(t) do n = n + 1 end end; return "그만 보기 목록 비우기 (" .. n .. ")" end,
              run = function() if ns.QItemDB then ns.QItemDB().no = {} ; ns.Print("그만 보기 목록을 비웠어요.") end end },
            { sec = 5, t = "button", label = function() local n = 0; for _, t in pairs(ns.QItemDB().mobs or {}) do for _ in pairs(t) do n = n + 1 end end; return "기억한 몹 비우기 (" .. n .. ")" end,
              run = function() if ns.QItemDB then ns.QItemDB().mobs = {} ; ns.Print("기억한 몹을 비웠어요.") end end },
        },
    },
    {
        key = "LeelUI_Gear", builtin = true, cat = "util",
        title = "장비 비교", sub = "시험 중 · 바꿀까 말까", icon = "hb_scale",
        desc = "장비 툴팁 위에 토끼가 말풍선으로 '끼자 / 그대로 쓰자'를 알려줘요.\n못 끼는 장비(사슬 · 판금 · 레벨)는 바로 알려줘요.\n판정은 대략이에요. 비슷하면 '비슷비슷해'로 말해요.",
        onoff = { get = function() return ns.GearDB and ns.GearDB().on end,
                  set = function(v) if ns.GearDB then ns.GearDB().on = v end end },
        items = {
            { sec = 2, t = "choice", label = "비교 기준 역할", hl = "role", hint = "이 역할에 좋은 능력치로 '끼자 / 그대로' 판단",
              options = function()
                  return { { key = "auto", label = "자동 (특성 보고 짐작)" }, { key = "tank", label = "탱커" }, { key = "melee", label = "근접 딜" },
                           { key = "ranged", label = "원거리 딜" }, { key = "caster", label = "주문 딜" }, { key = "healer", label = "힐러" } }
              end,
              get = function() return (ns.GearDB and ns.GearDB().role) or "auto" end,
              set = function(v) if ns.GearSetRole then ns.GearSetRole(v ~= "auto" and v or nil) end end,
              more = "주사위 창의 '내 역할'과 같은 설정이에요." },
        },
    },
    {
        key = "LeelUI_AH", builtin = true, cat = "util",
        title = "경매장 시세", sub = "가방 툴팁에 경매 가격", icon = "hb_scale",
        desc = "경매장에서 본 가격을 기억해서 가방 · 은행 · 우편 템 툴팁 아래에 보여줘요.\n경매장에서 찾기만 해도 쌓이고, 경매장 창 위 '시세 훑기'를 누르면 전체를 한 번에 (15분에 한 번).",
        onoff = { get = function() return ns.AH and ns.AH.DB() and ns.AH.DB().tip end,
                  set = function(v) if ns.AH and ns.AH.DB() then ns.AH.DB().tip = v and true or false end end },
        items = {
            { t = "toggle", label = "7일 평균", hint = "날마다 본 최저가의 평균 (이틀 이상 본 템만)",
              get = function() return ns.AH and ns.AH.DB() and ns.AH.DB().avg end,
              set = function(v) ns.AH.DB().avg = v and true or false end },
            { t = "toggle", label = "상점과 비교", hint = "어디에 파는 게 이득인지 한 줄 (수수료 5% 뺀 값 · 가방에 든 만큼 · Shift = 1개)",
              get = function() return ns.AH and ns.AH.DB() and ns.AH.DB().cmp ~= false end,
              set = function(v) ns.AH.DB().cmp = v and true or false end },
            { t = "button", label = function() return "시세 비우기 (" .. ((ns.AH and ns.AH.Count()) or 0) .. "개)" end,
              run = function() if ns.AH then ns.AH.Clear() end end },
        },
    },
    {
        key = "LeelUI_Bags", builtin = true, cat = "util",
        title = "르엘 가방", sub = "통합 가방, 남은 칸", icon = "hb_bag",
        desc = "가방 5개를 분홍 창 하나로. 창 머리를 끌면 옮겨져요.",
        onoff = { get = function() return ns.BagsDB().on end,
                  set = function(v) ns.BagsDB().on = v; if ns.UpdateBags then ns.UpdateBags() end end },
        items = {
            { t = "header", label = "가방 창",
              btn = { label = "위치 초기화", run = function() ns.BagsDB().winPos = nil; local w = _G.LeelUI_Bag; if w and w.Place then w.Place() end end } },
            { t = "slider", label = "한 줄 칸 수", min = 8, max = 16, step = 1, fmt = "%d",
              get = function() return tonumber(ns.BagsDB().cols) or 12 end,
              set = function(v) ns.BagsDB().cols = v; if ns.BagsApplySize then ns.BagsApplySize() end end },
            { t = "slider", label = "가방 창 크기", min = 70, max = 130, step = 5,
              get = function() return tonumber(ns.BagsDB().scale) or 100 end,
              set = function(v) ns.BagsDB().scale = v; if ns.BagsApplySize then ns.BagsApplySize() end end },
            { t = "button", label = "크기 처음으로", run = function()
                  local d = ns.BagsDB(); d.cols, d.scale = nil, nil
                  if ns.BagsApplySize then ns.BagsApplySize() end end },
            { t = "header", label = "남은 칸" },
            { t = "toggle", label = "거의 찼을 때 알림", hint = "남은 칸 3개 이하가 되는 순간 한 번",
              get = function() return ns.BagsDB().warn end,
              set = function(v) ns.BagsDB().warn = v end },
            { t = "header", label = "꽉 찼을 때" },
            { t = "toggle", label = "재료는 재료 가방으로 자동 이동", hint = "일반 가방이 거의 · 꽉 차면 재료를 재료 가방 빈칸으로 (전투 밖 · 알림 한 줄)",
              get = function() return ns.BagsDB().autoReag ~= false end,
              set = function(v) ns.BagsDB().autoReag = v and true or false end },
            { t = "toggle", label = "버릴 템 고르기 창", hint = "제일 싼 템 3개 + 각각 버리기 버튼 (전투가 끝나면 떠요)",
              get = function() return ns.BagsDB().full ~= false end,
              set = function(v) ns.BagsDB().full = v; if not v and ns.HideBagFull then ns.HideBagFull() end end },
            { t = "toggle", label = "새로 들어온 것, 가방을 닫아도 남기기", hint = "끄면 가방을 닫을 때 제자리로 돌아가요",
              get = function() return ns.BagsDB().keepNew end,
              set = function(v) ns.BagsDB().keepNew = v end },
        },
    },
    {
        key = "LeelUI_LootWin", builtin = true, cat = "util",
        title = "줍기 창", sub = "분홍 줍기 창", icon = "hb_loot",
        desc = "루팅 창을 르엘 모양으로. 마우스 근처에 떠요.\n왼쪽 스위치를 끄면 게임 기본 창 (다시 불러오기 후 적용).",
        onoff = { reload = true, get = function() return ns.LootDB().win end,
                  set = function(v) ns.LootDB().win = v end },
        items = {
            { sec = 3, t = "slider", label = "창 크기", hl = "win", min = 70, max = 150, step = 5, noPeek = true,
              get = function() return tonumber(ns.LootDB().scale) or 100 end,
              set = function(v) ns.LootDB().scale = v; local w = _G.LeelUI_Loot; if w then w:SetScale(v / 100) end end },
            { sec = 4, t = "seg", label = "창 자리", hl = "win", hint = "열릴 때마다",
              options = { { "마우스 근처", "cursor" }, { "화면 가운데", "center" } },
              get = function() return ns.LootDB().pos or "cursor" end, set = function(v) ns.LootDB().pos = (v ~= "cursor") and v or nil end },
            { sec = 4, t = "toggle", label = "자동 줍기", hl = "all", hint = "게임 설정. 켜면 창 없이 바로 주워요 (가방이 차서 남은 것만 창)",
              get = function() return GetCVar("autoLootDefault") == "1" end,
              set = function(v) SetCVar("autoLootDefault", v and "1" or "0") end },
        },
    },
    {
        key = "LeelUI_Loot", builtin = true, cat = "util",
        title = "르엘 줍기", sub = "시체 반짝 상자", icon = "hb_gift",
        needs = "LeelSpot", needsText = "상자는 Leel Spot이 그려요.\n애드온 목록에서 Leel Spot을 켜고 다시 불러오면 설정할 수 있어요.",
        desc = "주울 게 남은 가장 가까운 시체 하나에 반짝 상자.\n높이는 '미리보기'를 누르고 시체 앞에서 맞추면 쉬워요.",
        onoff = { get = function() return Loaded("LeelSpot") and SpotDB().loot ~= false end,
                  set = function(v) SpotSet("loot", v) end },
        items = {
            { sec = 2, t = "toggle", label = "죽은 몹 이름표 숨기기", hl = "plate", hint = "0% 체력바 대신 상자만",
              get = function() return ns.db.npHideDead ~= false end,
              set = function(v) ns.db.npHideDead = v; if ns.RefreshDeadPlates then ns:RefreshDeadPlates() end end },
            { sec = 2, t = "toggle", label = "여러 시체 표시", hl = "multi", hint = "가까운 건 큰 상자, 나머지는 작고 흐린 상자",
              get = function() return SpotDB().lootMulti ~= false end,
              set = function(v) SpotSet("lootMulti", v) end },
            { sec = 3, t = "toggle", label = "통통 튀는 움직임", hl = "box",
              get = function() return SpotDB().lootBob ~= false end,
              set = function(v) SpotSet("lootBob", v) end },
            { sec = 3, t = "slider", label = "상자 높이  (왼쪽 = 시체 쪽 아래)", hl = "box", noPeek = true, min = -200, max = 40, fmt = "%d",
              get = function() return SpotDB().lootY or -70 end,
              set = function(v) SpotSet("lootY", v) end },
            { sec = 3, t = "slider", label = "상자 크기", hl = "box", noPeek = true, min = 60, max = 160,
              get = function() return math.floor((SpotDB().lootSize or 1) * 100 + 0.5) end,
              set = function(v) SpotSet("lootSize", v / 100) end },
            { sec = 5, t = "button", label = "미리보기 5초", hl = "box",
              run = function() if LeelSpotAPI and LeelSpotAPI.Preview then LeelSpotAPI.Preview(5) end end },
            { sec = 5, t = "button", label = "기본값으로", hl = "box",
              run = function()
                  if not LeelSpotDB then return end
                  LeelSpotDB.lootY, LeelSpotDB.lootSize, LeelSpotDB.lootBob = -70, 1.0, true
                  SpotRefresh()
              end },
        },
    },
}
ns.HUB_MODULES = MODULES
-- 새 소식: 왼쪽 목록 맨 위 (설정 대신 업데이트 기록)
table.insert(MODULES, 1, { key = "_news", builtin = true, always = true, news = true,
    title = "새 소식", sub = "업데이트 기록", icon = "bag_bunny",
    desc = "새로 나온 건 분홍 NEW · 단추로 바로 켜러 가요", items = {} })

-- 대분류 (알약). 애드온이 하나도 없는 분류는 안 보여요
-- 하는 일 기준 5개. "설정 나누기"는 목록 대신 아래 줄 단추로 (cat = "none")
local CATS = {
    { key = "view",  label = "화면",        icon = "hb_c_view" },
    { key = "quest", label = "퀘스트",      icon = "hb_guide" },
    { key = "map",   label = "지도",        icon = "hb_c_map" },
    { key = "party", label = "파티·전투",   icon = "hb_c_party" },
    { key = "item",  label = "가방·아이템", icon = "hb_c_util" },
    { key = "dev",   label = "개발 중",     icon = "hb_apps" },   -- 아직 만드는 중인 기능 (시험용)
}
local MOD_CAT = {
    LeelUI = "view", LeelUI_ABar = "view", LeelUI_Cast = "view", LeelUI_Plates = "view", LeelUI_Tip = "view", LeelUI_Mouse = "view",
    LeelUI_Chat = "view", LeelUI_Font = "view", LeelUI_RankUp = "view",
    ForgLeveling = "quest", LeelUI_QTracker = "none", LeelUI_Quest = "quest", LeelUI_QItem = "quest", LeelSpot = "quest",
    LeelMap = "map", LeelUI_Minimap = "map",
    LeelUI_Party = "party", LeelUI_LFG = "party", LeelMark = "party", LeelUI_TotemSet = "party", LeelUI_Roll = "party",
    LeelUI_Bags = "item", LeelUI_AH = "item", LeelUI_LootWin = "item", LeelUI_Loot = "item", LeelUI_Shop = "item", LeelUI_Gear = "item",
    LeelUI_Profile = "start", LeelUI_Err = "start", _news = "start",
}
local MOD_ORDER = {}
do
    local order = { "_news", "LeelUI_Profile", "LeelUI_Err", "LeelUI", "LeelUI_Cast", "LeelUI_Plates", "LeelUI_Tip", "LeelUI_Mouse", "LeelUI_Chat", "LeelUI_Font", "LeelUI_RankUp", "LeelUI_ABar",
        "ForgLeveling", "LeelUI_QTracker", "LeelUI_Quest", "LeelUI_QItem", "LeelSpot",
        "LeelMap", "LeelUI_Minimap", "LeelUI_Party", "LeelUI_LFG", "LeelMark", "LeelUI_TotemSet", "LeelUI_Roll",
        "LeelUI_Bags", "LeelUI_AH", "LeelUI_LootWin", "LeelUI_Loot", "LeelUI_Shop", "LeelUI_Gear", "LeelUI_Profile" }
    for i, k in ipairs(order) do MOD_ORDER[k] = i end
end
for i, m in ipairs(MODULES) do m.cat = MOD_CAT[m.key] or m.cat or "item"; m.ord = MOD_ORDER[m.key] or (100 + i) end
table.sort(MODULES, function(a, b) return a.ord < b.ord end)
local curCat = "view"

----------------------------------------------------------------------
-- 부품
----------------------------------------------------------------------
local function Switch(parent)
    local sw = CreateFrame("Frame", nil, parent)
    sw:SetSize(36, 18)
    local bg = ns.RoundRect(sw, 9, nil, "ARTWORK", 0, 0)
    local knob = sw:CreateTexture(nil, "OVERLAY"); knob:SetSize(12, 12)
    knob:SetTexture(ns.MEDIA .. "circle")
    function sw:Set(on, onPink)
        if on then
            bg:SetColor(onPink and C.ink or C.acc, 1)
            local k = onPink and C.accHi or C.ink
            knob:SetVertexColor(k[1], k[2], k[3], 1)
            knob:ClearAllPoints(); knob:SetPoint("RIGHT", -3, 0)
        else
            bg:SetColor({ 1, 1, 1 }, 0.14)
            knob:SetVertexColor(C.tx2[1], C.tx2[2], C.tx2[3], 1)
            knob:ClearAllPoints(); knob:SetPoint("LEFT", 3, 0)
        end
    end
    return sw
end

local function IconDisc(parent, size, file)
    local h = CreateFrame("Frame", nil, parent)
    h:SetSize(size, size)
    h.bg = h:CreateTexture(nil, "ARTWORK")
    h.bg:SetTexture(ns.MEDIA .. "circle"); h.bg:SetAllPoints()
    h.ic = h:CreateTexture(nil, "OVERLAY")
    h.ic:SetTexture(ns.MEDIA .. file)
    h.ic:SetSize(size * 0.6, size * 0.6); h.ic:SetPoint("CENTER")
    return h
end

----------------------------------------------------------------------
-- 창 만들기
----------------------------------------------------------------------
local hub
local sel = 1

local function Refresh() end -- 아래에서 다시 정의

local dd
local PaintRail
local LiveFor, LiveText, LiveOff, Apply, Docked, SetCompact
local EDIT, EditStart
-- 크기 줄이 이동 모드에만 있는 것: 허브 칸 → { 크기 줄 이름, 이동 모드 테두리, 보일 이름 }
local MOVE_SIZE = {
    LeelUI_Party = { "파티 프레임 크기", function() return ns.party and ns.party.mover end, "파티 프레임" },
    LeelUI_ABar = { "액션바 크기", function() return ns.ABarMovers and ns.ABarMovers["액션바"] end, "액션바" },
    LeelUI_Roll = { "주사위 창 · 토끼 단추 크기", function() return ns.RollMover end, "주사위 토끼" },
}
local CMP_W = 330         -- 크기 · 위치: 오른쪽 좁은 허브 너비
local NEWS = {
    { "1.3.54", "징 새로 · 파티 해제 칸 · 주사위 파티원 템", "Leel Mark: 키 하나 (전투 밖 = 대상 둘레 무리 전부 · 전투 중 = 마우스 몹에 다음 징) · 이름표에 지금 칠 몹 징이 크게 + 금 고리 · 잡으면 다음 몹에 \"지금!\" · 바는 칠 순서 줄 (전투 중 접힘) · 르엘 쓰는 파티원끼리 대상 징 나누기 · 파티 칸: 오른쪽 위 해제 칸을 누르면 그 사람한테 바로 해제 · 주사위 카드에 파티원이 지금 낀 템 · 템레벨 비교 · 오류 · 차단 기록과 여러 던전 오류 고침" },
    { "1.3.53", "경매장 전체 시세 훑기 고침", "와우 포에버에서 시세 훑기가 \"답이 없어요\"로 끝나던 것 → 빈 검색으로 모든 템 최저가를 끝까지 받아요 (받는 중 개수 표시 · 2분에 한 번) · 글 앞 네모 기호 없앰" },
    { "1.3.52", "경매장 시세 · 재료 가방 자동 이동 · 지도 출구 길목", "가방 툴팁에 경매 최저가 + 상점과 비교 한 줄 (경매가 이득 / 상점에 팔아요 · 수수료 뺀 값) · 경매장 검색 칸 옆 시세 훑기 (모으는 중 % · 저장됨 표시) · 가방이 차면 재료를 재료 가방으로 알아서 옮기고 재료는 버리라고 안 해요 · 지도 출구 화살표를 실제 길목 자리로 (클래식 54곳) · 자료 없는 곳은 연한 ?" },
    { "1.3.51", "모던: 비행 중 내리기 구슬", "모던 모드에서 와이번 · 그리폰 · 박쥐를 타면 가운데 레벨 원 위에 그 동물 아이콘 구슬 · 누르면 다음 비행 지점에서 내려요 (허브 > 액션바 \"비행 중 내리기 구슬\")" },
    { "1.3.50", "오류 알리기 · 지도 첫 M 멈춤 고침 · 파티 찾기 칸 · 토끼 초상화", "애드온 오류가 나면 토끼 알림 → 캡처용 카드 · 코드 복사 (허브 > 시작 > 오류 알리기 · /르엘오류) · 리로드 후 처음 M 지도 멈춤을 로딩 화면 동안 미리 불러오기 · 파티 찾기 설정을 파티·전투 새 칸으로 + 미리 보기 · Leel HUD 내 초상화를 르엘 토끼로 · 허브 새 로고 · 멈춤 찾기 /르엘측정" },
    { "1.3.49", "음성 채팅 칩 · 파티 찾기 위치 · Leel Quest 파티 같이 · 오류 고침", "채팅 머리줄에 말하는 사람 칩 · 음성 소리 · 마이크 단추 르엘 모양 · 파티 찾기 신청자 지역 + 같은 곳 · 던전 안 · 입구 · 멀리 · Leel Quest 파티원과 같은 퀘만 길 (얼굴로 고르기) · 단축바 주문 레벨 바꾸기 · 숨긴 기본 파티 창 오류" },
    { "1.3.48", "영어 지원 (English) · 모던 버프 줄 옮기기 · 퀘스티 아이콘 · 주문 레벨 고침", "게임 언어가 영어면 자동으로 영어 · 허브 맨 위 언어 고르기 · /leel lang en · ko · 모던 버프 · 디버프 줄을 이동 모드에서 따로 옮기기 · 크기 · 미니맵 모음의 퀘스티 = 왼쪽 클릭 설정 창 · 단축바 주문 레벨 알림이 와우 포에버 주문책을 읽게" },
    { "1.3.47", "모던: 가운데 원 보기 · 빠른 설정 · 오른쪽 쪽 탭 · 혜성 · 변신 구슬", "원 왼쪽 클릭 = 레벨 · 직업 자원 · 진영 문장 · 오른쪽 클릭 = 빠른 설정 (버프 · 디버프 크기 · 줄 두께) · 오른쪽 칸 I · II · III 쪽 · 전투 중 원 둘레 혜성 · 변신 · 태세는 원 위 구슬" },
    { "1.3.46", "고침: 펫 원 팝업 · 지도 퀘 툴팁 오류", "펫 원을 눌러도 기술이 안 펼쳐지던 것 · 지도 퀘스트 아이콘에 마우스를 올리면 C stack overflow 오류가 나던 것" },
    { "1.3.45", "모던: 펫 원 · 나 찍기 · 들어오는 치유 · 파티 따라가기 배지", "펫 = 생명력 줄 왼쪽 동그라미 (둘레 = 펫 체력 · 누르면 기술 부채꼴) · 생명력 줄 · 레벨 원 누르면 나 · 내 생명력 줄에 들어올 치유 + 숫자 · 모던 파티 칸 따라가기 배지 · 다른 사람이 찍은 징도 이름표에" },
    { "1.3.44", "UI 모드: 기본 ↔ 모던", "허브 맨 위 'UI 모드'에서 한 번에 · 모던 = 각진 액션바 · 위쪽 대상 바 · 네모 미니맵 · 투명 메뉴 줄 · 로아식 파티 창 · 르엘UI 안에서 단축키 정하기" },
    { "1.3.43", "Leel Quest: 내 진행도 보내기 고침", "끄면 파티원 창에서 내 숫자가 바로 지워지고 · 켜면 바로 보내요" },
    { "1.3.42", "이동 모드 새 단장 · Leel Mark 잡는 순서 · 주사위 토끼 미리 보기", "위 가운데 캡슐 바 · 들어갈 때 효과 · 목록(찾기 · 크기 초기화 · 잠깐 숨기기) · HUD 조각 안내선 · 착 붙기 · 방향키 · 징 순서 번호 · 군중 제어 역할 · 계획 알리기 · 이름표에 순서 · CC 남은 시간" },
    { "1.3.41", "르엘 허브 새 단장: 탭마다 미리 보기 + 세부 설정", "위쪽 미리 보기 · 줄에 마우스 = 그 부분 반짝 · 시전바 · 이름표 · 툴팁 · 마우스 · 채팅 · 글씨 · 퀘스트 · 지도 · 미니맵 · 파티 · 줍기 · 상점 · 장비 비교 · 액션바는 잠시 쉬어요" },
    { "1.3.40", "@불러 주기 알림 · 단축바 주문 레벨 알림 · 파티원 퀘 진행도", "@내이름 = 분홍 띠 + 삐삐 · @ 치면 이름 고르기 · 낮은 레벨 칸 표시 · Leel Quest 파티원 얼굴 고리 · Shift+클릭 = Leel Quest에서 보기" },
    { "1.3.39", "이동 모드에서 HUD 조각마다 크기 · 가운데는 숫자와 효과만", "내 창 · 가운데 · 대상 창 따로 크기 · 대상의 대상 · 펫 창 크기 · 주사위 토끼 · 토끼 메뉴는 이동 모드에서 · 설정 나누기 빨라짐" },
    { "1.3.38", "Leel Quest 퀘 정리 · 파티 땐 어려운 퀘도 길에 · ESC 메뉴 르엘 UI", "골라서 한 번에 포기 · 파티 정예 · 던전 퀘 자동 · 편지 든 토끼 · 말풍선 왼쪽 직업 색 테",
      head = "퀘 정리가 쉬워졌어요",
      feats = { { "퀘 정리하기", "휴지통 → 골라서 한 번에 포기 · 회색 퀘는 미리 골라 둬요", "ForgLeveling" },
                { "파티 땐 어려운 퀘도 길에", "파티 중이면 정예 · 던전 퀘도 토끼 자동 길에", "ForgLeveling" },
                { "ESC 메뉴 르엘 UI", "게임 메뉴에 르엘 UI 단추 · 새 소식이면 편지 든 토끼" },
                { "말풍선 직업 색 다듬기", "왼쪽 직업 색 테 · 길드 이름 붙은 파티원도", "LeelUI_Chat" } } },
    { "1.3.37", "채팅: 보낸 말 다시 쓰기 · 파티원 말풍선 직업 색", "입력칸에서 ↑ · 최근 5개 · 말풍선 왼쪽 직업 색 테",
      head = "채팅이 더 편해졌어요",
      feats = { { "보낸 말 다시 쓰기", "입력칸에서 ↑ = 최근 보낸 말 5개 · ↑ ↓ 고르고 Enter", "LeelUI_Chat" },
                { "파티원 말풍선 직업 색", "파티원 말풍선 왼쪽 테가 직업 색 · 던전 안은 기본", "LeelUI_Chat" } } },
    { "1.3.36", "블랙리스트 굴림 알림 · 파티와 같은 퀘", "화난 토끼 · 르엘 경고음 · 토끼 표정 · 회색 정예 · 퀘스티 추천 설정",
      feats = { { "블랙리스트 굴림 알림", "화난 토끼 · 르엘 경고음", "LeelUI_Roll" },
                { "파티와 같은 퀘", "같은 퀘 파티원 얼굴 · 회색 정예 퀘", "ForgLeveling" },
                { "퀘스티 추천 설정", "지도엔 받을 퀘 ! + 진행 목표", "LeelMap" } } },
    { "1.3.35", "적 이름표 내 대상 표시 · 이동 모드 크기 줄", "조준 · 화살표 · 디버프 고침 · 지도 퀘 경험치 · 채팅창 크기",
      feats = { { "적 이름표 내 대상 표시", "고른 적 위에 조준 · 화살표", "LeelUI_Plates" },
                { "이동 모드 크기 줄", "테두리 누르면 바로 위에 크기 줄" },
                { "지도 퀘 정보", "퀘 아이콘에 레벨 · 경험치 · 보상", "LeelMap" } } },
    { "1.3.34", "따라가기 아이콘 고침", "따라갈 때 아이콘이 위로 날아가던 것" },
    { "1.3.33", "따라가기 단추 · 주사위 결과 · 클릭 막힘 고침", "초상화 두 사람 아이콘 · 누가 뭘 눌러 먹었나 · 남은 시간 시계" },
    { "1.3.32", "전투 중 노란 번개", "금빛 토끼 귀 옆으로 빠직빠직" },
    { "1.3.31", "파티 5인 · 해제 알림 · 주사위 토끼", "직업 아이콘 · 역할 배지 · 전투 중 금빛 토끼 귀" },
    { "1.3.30", "화살통 칸에 남은 화살", "세로 게이지 · 200발 노랑 · 50발 빨강" },
    { "1.3.29", "르엘 주사위 창 · 토끼 추천 · 블랙리스트", "파티 인사 말풍선 · 던전 퀘 보고 모드" },
    { "1.3.28", "주술사 토템 세트 (Q 한 키) · 토템 칸", "펫 창 크기 · 펫 만족도 · 가방 등급 테 · 던전 카드" },
    { "1.3.27", "Leel Quest 퀘스트 창 대신 · 검색", "지도 머리 줄 · 시전바 · 가방 크기" },
    { "1.3.26", "몹 시전바 크게 · 아이콘", "지역 출구 화살표 · 재료 가방" },
    { "1.3.25", "전문기술 재료 클릭 → 제작식", "Leel Map 길드원 위치" },
    { "1.3.24", "버리기 창 잠금 · 휴지통 슝", "몹 등급 아이콘 알약" },
    { "1.3.23", "마우스 효과 · 몹 등급 알약", "던전 안 Leel Quest · 글씨 강조" },
    { "1.3.22", "OpenMap 같이 설치", "이어 붙인 세계 지도" },
    { "1.3.21", "Leel Quest 자동 길 · 반납 상자", "허브 정리 · OpenMap 맞춤" },
    { "1.3.20", "전투 중 오류 · 툴팁 수정", "던전 시체 반짝 상자" },
    { "1.3.19", "퀘스트 판 토끼 사용법 안내", "처음 열 때 한 번 저절로" },
    { "1.3.18", "채팅 탭 많으면 ··· 더보기", "미니맵 목록 중복 정리" },
    { "1.3.17", "퀘스트 목표 달성 알림 · 당근 링", "채팅 떨어진 탭 다시 붙이기" },
    { "1.3.16", "장비 비교 토끼 (시험 중)", "정예 · 던전 퀘 조심 표시" },
    { "1.3.15", "퀘스트 물건 멀리서도 반짝", "새 지역 알림을 Leel Quest 띠로" },
    { "1.3.14", "르엘 퀘스트 판 · Leel Quest", "퀘템 알림 · 채팅창 직접 옮기기" },
    { "1.3.13", "르엘 채팅창 · 새 글 숫자", "남의 몹 자물쇠 · 자동 징 무리만" },
    { "1.3.12", "파티 힐러 타일 · 들어올 치유", "르엘 툴팁 · 남의 몹 자물쇠" },
    { "1.3.5", "줍기 창이 분홍 카드로", "파티 링이 전투 중에도 시계 방향으로" },
    { "1.3.4", "르엘 가방 · 상점 토끼 · 시체 반짝 상자", "퀘스트 자동, 토끼 미니맵" },
    { "1.3.3", "르엘 허브 · 르엘 글씨체", "몹 등급 토끼 이름표" },
}

-- 미리 보기 단추: 기능마다 게임 안에서 진짜 모습 띄우기
local PREVIEW = {
    LeelUI = { "각성 미리 보기", function() if SlashCmdList.LEELAWAKE then SlashCmdList.LEELAWAKE("") end end },
    LeelUI_Party = { "가짜 파티 띄우기", function()
        if InCombatLockdown() then Print("전투가 끝나면 볼 수 있어요.") return end
        if ns.SetPartyPreview then local b = ns.party; ns:SetPartyPreview(not (b and b.preview)) end end },
    -- A안: 탭을 열 땐 조용히 · 누르면 허브가 잠깐 숨고 진짜 주사위 창이 진짜 자리에 (위 알약 = 남은 시간 · 허브로 돌아가기)
    LeelUI_Roll = { "실제 자리에서 보기", function()
        if InCombatLockdown() then Print("전투가 끝나면 볼 수 있어요.") return end
        if not ns.RollTest then return end
        local P = ns.hubRollPeek
        if not P then
            P = CreateFrame("Frame", nil, UIParent); P:SetFrameStrata("FULLSCREEN_DIALOG"); P:SetHeight(36)
            P:SetPoint("TOP", UIParent, "TOP", 0, -12)
            local e = ns.RoundRect(P, 18, C.acc, "BACKGROUND", 0, -1); e:SetColor(C.acc, 0.7)
            local f = ns.RoundRect(P, 18, { 0.114, 0.082, 0.078 }, "BACKGROUND", 1, 0); f:SetColor({ 0.114, 0.082, 0.078 }, 0.97)
            P.ring = P:CreateTexture(nil, "ARTWORK"); P.ring:SetTexture(ns.MEDIA .. "ring_thin"); P.ring:SetSize(18, 18); P.ring:SetPoint("LEFT", 12, 0)
            P.ring:SetVertexColor(C.acc[1], C.acc[2], C.acc[3])
            P.t = ns.Font(P, 12.5, C.accHi); P.t:SetPoint("LEFT", P.ring, "RIGHT", 8, 0); P.t:SetText("주사위 창 미리 보기 중")
            P.n = ns.Font(P, 11.5, C.tx2); P.n:SetPoint("LEFT", P.t, "RIGHT", 8, 0)
            P.b = ns.MakeButton(P, "허브로 돌아가기", true, function() P.Back() end); P.b:SetHeight(26)
            P.b:SetPoint("LEFT", P.n, "RIGHT", 10, 0)
            P:EnableKeyboard(true)
            P:SetScript("OnKeyDown", function(self, key)
                if key == "ESCAPE" then self:SetPropagateKeyboardInput(false); P.Back() else self:SetPropagateKeyboardInput(true) end
            end)
            function P.Back()
                P:SetScript("OnUpdate", nil); P:Hide()
                if ns.RollTestStop then ns.RollTestStop() end
                if hub and not hub:IsShown() then hub:Show() end
            end
            P:Hide()
            ns.hubRollPeek = P
        end
        hub:Hide()
        ns.RollTest()
        local endAt = GetTime() + 30
        P:Show()
        P:SetScript("OnUpdate", function(self)
            local left = endAt - GetTime()
            if left <= 0 then self.Back() return end
            self.n:SetText(math.ceil(left) .. "초")
            self:SetWidth(12 + 18 + 8 + self.t:GetStringWidth() + 8 + self.n:GetStringWidth() + 10 + self.b:GetWidth() + 6)
        end)
    end },
    LeelUI_Loot = { "상자 미리 보기 5초", function() if LeelSpotAPI and LeelSpotAPI.Preview then LeelSpotAPI.Preview(5) end end },
}


----------------------------------------------------------------------
-- A안: 크기 슬라이더를 잡는 동안 허브가 비켜요 (그 칸만 남고 투명)
--      진짜 UI에 분홍 테 + 지금 크기 말풍선
----------------------------------------------------------------------
local PEEK = {
    ["Leel HUD 크기"] = function() return ns.hud end,
    ["펫 창 크기 (사냥꾼 · 흑마법사)"] = function() return ns.hudFrames and ns.hudFrames.pet end,
    ["대상의 대상 크기"] = function() return _G.LeelUI_targettarget end,
    ["액션바 크기"] = function() return _G.LeelUI_ActionBars end,
    ["주사위 창 · 토끼 단추 크기"] = function() return _G.LeelUI_RollBadge end,
    ["파티 프레임 크기"] = function() return ns.party end,
    ["칸 가로"] = function() return ns.party end,
    ["칸 세로"] = function() return ns.party end,
    ["칸 사이"] = function() return ns.party end,
    ["한 줄 칸 수"] = function() return _G.LeelUI_Bag end,
    ["가방 창 크기"] = function() return _G.LeelUI_Bag end,
}
local peekHL, peekRow
local function PeekHL()
    if peekHL then return peekHL end
    local h = CreateFrame("Frame", nil, UIParent)
    h:SetFrameStrata("FULLSCREEN_DIALOG")
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = h:CreateTexture(nil, "BORDER")
        e:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 1)
        if side == "TOP" or side == "BOTTOM" then e:SetPoint(side .. "LEFT", -4, 0); e:SetPoint(side .. "RIGHT", 4, 0); e:SetHeight(2)
        else e:SetPoint("TOP" .. side, 0, 4); e:SetPoint("BOTTOM" .. side, 0, -4); e:SetWidth(2) end
    end
    local glow = h:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(ns.MEDIA .. "tile_glow"); glow:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.6)
    glow:SetPoint("TOPLEFT", -18, 18); glow:SetPoint("BOTTOMRIGHT", 18, -18)
    local bb = CreateFrame("Frame", nil, h); bb:SetHeight(26); bb:SetPoint("BOTTOM", h, "TOP", 0, 8)
    ns.RoundRect(bb, 13, C.acc, "BACKGROUND", 0, 0)
    h.fs = ns.Font(bb, 13.5, C.ink); h.fs:SetShadowColor(0, 0, 0, 0); h.fs:SetPoint("CENTER", 0, 0)
    h.bb = bb
    h:Hide()
    peekHL = h
    return h
end
local function PeekText(label, v, fmt)
    local h = peekHL
    if not h or not h:IsShown() then return end
    h.fs:SetText(label .. "  " .. (fmt or "%d%%"):format(v))
    h.bb:SetWidth(h.fs:GetStringWidth() + 26)
end
local function PeekOn(r, label)
    if peekRow == r then return end
    peekRow = r
    hub:SetAlpha(0.04)
    r:SetIgnoreParentAlpha(true)
    if r.card then r.card:SetIgnoreParentAlpha(true) end
    local get = PEEK[label]
    local fr = get and get()
    if fr and fr.IsShown and fr:IsShown() then
        local h = PeekHL()
        h:ClearAllPoints(); h:SetAllPoints(fr); h:Show()
    end
end
local peekWatch = CreateFrame("Frame")
peekWatch:Hide()
local PeekOff
peekWatch:SetScript("OnUpdate", function(self)
    -- 마우스를 슬라이더 밖에서 놓아도 꼭 돌아오게
    if self.drag and not IsMouseButtonDown("LeftButton") then self:Hide(); PeekOff() end
end)
PeekOff = function()
    peekWatch.drag = false; peekWatch:Hide()
    local r = peekRow
    if not r then return end
    peekRow = nil
    r:SetIgnoreParentAlpha(false)
    if r.card then r.card:SetIgnoreParentAlpha(false) end
    if hub then hub:SetAlpha(1) end
    if peekHL then peekHL:Hide(); peekHL:ClearAllPoints() end
end

local PADX, CGAP, GAP, CP, CPV = 20, 10, 5, 14, 6
-- ShowPane 안에서 쓰는 고정 값 (올림값 60개 제한 · 한 통으로)
local K = { PADX = PADX, CGAP = CGAP, GAP = GAP, CP = CP, CPV = CPV, HEAD = HEAD, PHEAD = PHEAD, TOP = TOP, FOOT = FOOT, RAIL = RAIL, TABH = TABH, PVH = PVH, W = W, H = H }
local curTab = {}
local advOpen = {}   -- 기능마다 "고급" 펼침

-- 묶음(탭) 나누기: 'header' 줄이 나올 때마다 새 묶음
local function LabelOf(x) if type(x) == "function" then local ok, v = pcall(x); return ok and v or "" end; return x or "" end
-- 크기 · 위치 설정: 게임 화면을 보면서 맞추도록 따로 모아요 (오른쪽 좁은 허브)
local function IsSizeItem(it)
    do return nil end   -- (C안 옆으로 접기는 쓰지 않아요 · B안 화면에서 조절)
    local l = type(it.label) == "string" and it.label or ""
    if it.t == "slider" then
        return l:find("크기", 1, true) or l:find("칸 가로", 1, true) or l:find("칸 세로", 1, true)
            or l:find("칸 사이", 1, true) or l:find("한 줄 칸 수", 1, true)
    elseif it.t == "button" then
        return l:find("위치", 1, true) or l:find("크기", 1, true)
    end
end
local function Groups(m)
    local groups, map = {}, {}
    local cur = { items = {} }
    local size = { items = {}, size = true }
    for idx, it in ipairs(m.items or {}) do
        if it.t == "header" then
            if #cur.items > 0 or (cur.head and cur.head.btn) then groups[#groups + 1] = cur end
            cur = { head = it, items = {} }
        elseif it.moveOnly then
            -- 크기는 이동 모드에서만 (허브엔 안 보여요)
        elseif IsSizeItem(it) then
            size.items[#size.items + 1] = idx
        else
            cur.items[#cur.items + 1] = idx
        end
    end
    if #cur.items > 0 or (cur.head and cur.head.btn) then groups[#groups + 1] = cur end
    if #size.items > 0 then groups[#groups + 1] = size end
    for gi, g in ipairs(groups) do
        g.label = g.size and "크기 · 위치" or (g.head and LabelOf(g.head.label) or "기본")
        for _, idx in ipairs(g.items) do map[idx] = gi end
    end
    return groups, map
end

-- 오른쪽 '설정 설명' 칸 (m.explain): 탭 소개 → 줄에 마우스를 올리면 그 설정 설명
local XP = { EXPW = 270, SVW = 360, snap = {} }
-- 허브 공통 규칙: 머리 띠(크기 · 위치) → ① 쓰기 ② 무엇을 ③ 모양 ④ 언제 ⑤ 더
--   SEC[기능][설정 이름] = 칸 번호 (0 = 숨김 · _d = 정해지지 않은 줄 · 없으면 ⑤)
XP.SECNAME = { "쓰기", "무엇을", "모양", "언제", "더" }
XP.SEC = {
    LeelUI = { _d = 3, ["가운데 사용"] = 1, ["보일 때"] = 4,
        ["번쩍"] = 5, ["노란 번개"] = 5, ["솟는 빛줄기"] = 5, ["효과 세기"] = 5,
        ["대상의 대상 보이기"] = 1, ["미니맵 아이콘"] = 5, ["미니맵 아이콘 정리"] = 5 },
    LeelUI_ABar = { ["점검 (채팅창)"] = 5 },
    LeelUI_Cast = { _d = 3 },
    LeelUI_Plates = { _d = 3 },
    LeelUI_Minimap = { ["르엘 미니맵 쓰기"] = 1, _d = 5 },
    LeelUI_Tip = { _d = 3 },
    LeelUI_Mouse = { _d = 3 },
    LeelUI_Chat = { _d = 5 },
    LeelUI_Font = { _d = 5 },
    LeelMap = { _d = 5 },
    LeelUI_TotemSet = { ["토템 세트 단추 쓰기"] = 0, ["고칠 세트"] = 2, ["1번"] = 2, ["2번"] = 2, ["3번"] = 2, ["4번"] = 2 },
    LeelUI_Roll = { ["르엘 주사위 창"] = 0, ["토끼 추천"] = 2, ["내 역할"] = 2, ["결과 보드"] = 3, ["블리자드 획득 알림 숨기기"] = 4,
        ["토끼 단추 항상 보이기"] = 4, ["파티 인사 말풍선"] = 4, ["인사 미리 보기"] = 4, ["블랙리스트 굴림 알림"] = 4,
        ["경고음"] = 4, ["채팅창에도 한 줄"] = 4, ["블랙리스트 알림 미리 보기"] = 4 },
    LeelUI_Party = { ["이름"] = 2, ["체력 글씨"] = 2, ["버프 · 디버프 보이기"] = 2, ["칸 가로"] = 3, ["칸 세로"] = 3, ["칸 사이"] = 3,
        ["세부 설정 처음으로"] = 3, ["파티 인원"] = 4, ["내 칸 자리"] = 4, ["정렬"] = 4 },
    LeelMark = { _d = 5 },
    LeelSpot = { _d = 5 },
    ForgLeveling = { _d = 5, ["블리자드 기본"] = 2, ["Questie 추적창  (다시 불러오기)"] = 2, ["Leel Quest"] = 2 },
    LeelUI_Shop = { _d = 5 },
    LeelUI_Quest = { _d = 2 },
    LeelUI_QTracker = { _d = 2 },
    LeelUI_Gear = { _d = 2 },
    LeelUI_Bags = { ["한 줄 칸 수"] = 3, ["거의 찼을 때 알림"] = 4, ["버릴 템 고르기 창"] = 4 },
    LeelUI_LootWin = { _d = 4 },
    LeelUI_Loot = { ["죽은 몹 이름표 숨기기"] = 2, ["여러 시체 표시"] = 2, ["통통 튀는 움직임"] = 3,
        ["상자 높이  (왼쪽 = 시체 쪽 아래)"] = 3, ["상자 크기"] = 3 },
}
-- 머리 띠: ms = 이동 모드 크기 줄 · move = 이동 모드로 옮기기 · note = 끌어서 옮기는 창 · sz = 띠 바로 아래 크기 줄 · reset = 초기화 단추가 누를 줄
XP.BAND = {
    LeelUI = { reset = { "HUD 위치 초기화" } },
    LeelUI_ABar = { ms = true, reset = { "액션바 · 토끼 메뉴 위치 초기화" } },
    LeelUI_Cast = { move = true, title = "시전바", reset = { "시전바 위치 초기화" } },
    LeelUI_Minimap = { move = true, title = "미니맵", reset = { "미니맵 위치 초기화" } },
    LeelUI_Chat = { move = true, title = "채팅창" },
    LeelUI_Roll = { title = "주사위 토끼", note = "토끼를 끌어서 옮겨요 · Shift + 휠 = 크기", sz = "주사위 창 · 토끼 단추 크기", reset = { "처음 자리 · 크기로" } },
    LeelUI_Party = { ms = true, reset = { "위치 초기화" } },
    LeelMap = { title = "지도 창", note = "지도 창 머리를 끌어서 옮겨요", sz = "지도 창 크기", reset = { "지도 위치 초기화", "지도 크기 처음으로" } },
    LeelMark = { title = "징 바", note = "토끼를 끌어서 옮겨요 · 징에 마우스 = 약속 서랍", reset = { "바 위치 초기화" } },
    LeelUI_Bags = { title = "가방 창", note = "창 머리를 끌어서 옮겨요", sz = "가방 창 크기", reset = { "위치 초기화", "크기 처음으로" } },
    ForgLeveling = { title = "Leel Quest 창", note = "창을 끌어서 옮겨요 · 크기는 오른쪽 아래 손잡이" },
}   -- snap: 허브를 열 때 값 (줄마다 처음 볼 때 기억)
--   -- 설명 칸 · B안 미리 보기 폭 · 강조 (ShowPane 올림값 60개 제한 때문에 한 통에)
local EXPW, SVW = XP.EXPW, XP.SVW
-- 미리 보기 강조 (A안 스포트라이트): 지금 마우스를 올린 줄 · 값이 바뀌어도 다시 그려요
local hlIt
local function ValText(it)
    local ok, v = pcall(it.get or function() end)
    if not ok or v == nil then return "" end
    if it.t == "slider" then return (it.fmt or "%d%%"):format(v)
    elseif it.t == "toggle" then return v and "켬" or "끔"
    elseif it.t == "size" then return v .. "%" end
    return ""
end
-- 미리 보기마다 강조 그리는 곳이 달라요 (Leel HUD · 적 이름표)
XP.HLF = function()
    local mm = MODULES[sel]
    if mm and mm.key == "LeelUI_Plates" then return ns.NPPvHL, ns.NPPvHLAlpha end
    if mm and mm.key == "LeelUI_Tip" then return ns.TipPvHL, ns.TipPvHLAlpha end
    if mm and mm.key == "LeelUI_Mouse" then return ns.CfxPvHL, ns.CfxPvHLAlpha end
    if mm and mm.key == "LeelUI_Chat" then return ns.ChatPvHL, ns.ChatPvHLAlpha end
    if mm and mm.key == "LeelUI_Font" then return ns.FontPvHL, ns.FontPvHLAlpha end
    if mm and mm.key == "ForgLeveling" then return ns.LQPvHL, ns.LQPvHLAlpha end
    if mm and mm.key == "LeelUI_Quest" then return ns.QAPvHL, ns.QAPvHLAlpha end
    if mm and mm.key == "LeelUI_QItem" then return ns.QIPvHL, ns.QIPvHLAlpha end
    if mm and mm.key == "LeelSpot" then return ns.SpotPvHL, ns.SpotPvHLAlpha end
    if mm and mm.key == "LeelMap" then return ns.MapPvHL, ns.MapPvHLAlpha end
    if mm and mm.key == "LeelUI_RankUp" then return ns.RankPvHL, ns.RankPvHLAlpha end
    if mm and mm.key == "LeelUI_Minimap" then return ns.MMPvHL, ns.MMPvHLAlpha end
    -- 그 밖의 탭: 미리 보기를 만들 때 XP.HLREG[탭] = { 강조, 진하기 } 로 등록
    local reg = mm and XP.HLREG and XP.HLREG[mm.key]
    if reg then return reg[1], reg[2] end
    return ns.HudPvHL, ns.HudPvHLAlpha
end
XP.HLA = function(a) local _, fa = XP.HLF(); if fa then fa(a) end end
local function HLRefresh()
    local fn = XP.HLF()
    if not fn then return end
    local it = hlIt
    if not it then fn(nil) return end
    local t = LabelOf(it.label); t = type(t) == "string" and t or ""
    local vt = ValText(it)
    -- hl 이 없는 예전 줄은 탭별 이름표(XP.HLMAP)로 강조할 곳을 찾아요
    local mk = MODULES[sel] and MODULES[sel].key
    local byLabel = mk and XP.HLMAP and XP.HLMAP[mk] and XP.HLMAP[mk][t]
    fn(it.hl or byLabel or (it.t == "size" and "part") or nil, vt ~= "" and (t .. "  " .. vt) or t)
end
local function HLSet(it) hlIt = it; HLRefresh() end
XP.Set, XP.Refresh, XP.Cur = HLSet, HLRefresh, function() return hlIt end
-- 줄에서 마우스를 떼면 0.3초 동안 스르르 → 전체 모습 + 탭 소개 (B안)
--   다른 줄로 바로 옮기면 그 줄로 · 슬라이더를 끄는 중이면 놓을 때까지 그대로
XP.Idle = function()
    HLSet(nil)
    XP.HLA(1)
    local pv = hub and hub.pv
    if not (pv and pv:IsShown()) then return end
    if pv.cap and pv.cap:IsShown() and pv.introT then pv.capT:SetText(pv.introT); pv.cap:SetText(pv.introC or "") end
    local want = ns.hudPvFightManual and true or false
    if (ns.hudPvFight and true or false) ~= want or ns.hudPvDead or ns.hudPvPeek then
        ns.hudPvFight, ns.hudPvDead, ns.hudPvPeek = want, false, nil; pv:Update()
    end
end
XP.fader = CreateFrame("Frame"); XP.fader:Hide()
XP.fader:SetScript("OnUpdate", function(f, el)
    -- 끄는 중이거나 아직 그 줄 안(슬라이더 · 단추 위)이면 그대로
    local row = XP.leaveRow
    if IsMouseButtonDown("LeftButton") or (row and row:IsVisible() and row:IsMouseOver()) then
        if (f.t or 0) > 0 then XP.HLA(1) end
        f.t = 0; return
    end
    f.t = (f.t or 0) + el
    XP.HLA(math.max(0, 1 - f.t / 0.3))
    if f.t >= 0.3 then f:Hide(); XP.Idle() end
end)
XP.Leave = function(row) XP.leaveRow = row; XP.fader.t = 0; XP.fader:Show() end
XP.Enter = function() XP.fader:Hide(); XP.HLA(1) end
local function ExplainBuild()
    local ex = CreateFrame("Frame", nil, hub)
    ex:SetFrameLevel(hub:GetFrameLevel() + 8)
    ex:EnableMouse(true)
    ex.fill, ex.edge = ns.RoundPlate(ex, 14, { 0.145, 0.11, 0.1, 0.96 }, { 1, 1, 1, 0.06 })
    ex.cap = ns.Font(ex, 10.5, { 0.62, 0.54, 0.52 }); ex.cap:SetPoint("TOPLEFT", 16, -14); ex.cap:SetText("설정 설명")
    ex.title = ns.Font(ex, 15, C.tx); ex.title:SetPoint("TOPLEFT", ex.cap, "BOTTOMLEFT", 0, -6)
    ex.title:SetWidth(EXPW - 32); ex.title:SetJustifyH("LEFT")
    ex.body = ns.Font(ex, 12, { 0.83, 0.74, 0.71 }); ex.body:SetPoint("TOPLEFT", ex.title, "BOTTOMLEFT", 0, -10)
    ex.body:SetWidth(EXPW - 32); ex.body:SetJustifyH("LEFT"); ex.body:SetJustifyV("TOP"); ex.body:SetWordWrap(true)
    if ex.body.SetSpacing then ex.body:SetSpacing(4) end
    ex.line = ex:CreateTexture(nil, "ARTWORK"); ex.line:SetColorTexture(1, 1, 1, 0.06); ex.line:SetHeight(1)
    ex.line:SetPoint("BOTTOMLEFT", 16, 52); ex.line:SetPoint("BOTTOMRIGHT", -16, 52)
    ex.tip = ns.Font(ex, 11, { 0.62, 0.54, 0.52 }); ex.tip:SetPoint("TOPLEFT", ex.line, "BOTTOMLEFT", 0, -10)
    ex.tip:SetWidth(EXPW - 32); ex.tip:SetJustifyH("LEFT"); ex.tip:SetWordWrap(true)
    ex.tip:SetText("줄에 마우스를 올리면 여기에 설명이 나와요.\n크기 · 자리는 이동 모드에서 바꿔요.")
    function ex:Say(it)
        if not it then return end
        local t = LabelOf(it.label or it.title)
        t = (type(t) == "string" and t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        self.title:SetText(t)
        local body = it.more or LabelOf(it.hint) or it.desc or ""
        self.body:SetText(type(body) == "string" and body or "")
    end
    ex:Hide()
    hub.explain = ex
    return ex
end
XP.Build = ExplainBuild

local function BuildPane(f)
    -- 줄이 많으면 넘치지 않게 휠로 내려 보는 칸 (안쪽 pane이 실제 내용)
    local sf = CreateFrame("ScrollFrame", nil, f)
    sf:SetPoint("TOPLEFT", RAIL + 1, -TOP)
    sf:SetPoint("BOTTOMRIGHT", -2, FOOT)
    local pane = CreateFrame("Frame", nil, sf)
    pane:SetSize(1, 1)
    sf:SetScrollChild(pane)
    pane.sf = sf
    local thumb = sf:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.55)
    thumb:SetWidth(3)
    thumb:Hide()
    local function PaintThumb()
        local vh, ch = sf:GetHeight(), pane:GetHeight()
        if not vh or vh <= 0 or ch <= vh + 1 then thumb:Hide(); return end
        local th = math.max(24, vh * vh / ch)
        local off = (sf:GetVerticalScroll() / (ch - vh)) * (vh - th)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", sf, "TOPRIGHT", -3, -off)
        thumb:SetHeight(th)
        thumb:Show()
    end
    pane.PaintThumb = PaintThumb
    sf:SetScript("OnSizeChanged", function(_, w, h)
        pane:SetWidth(w)
        if pane:GetHeight() < h then pane:SetHeight(h) end
        PaintThumb()
    end)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(_, d)
        local max = math.max(0, pane:GetHeight() - sf:GetHeight())
        sf:SetVerticalScroll(math.min(max, math.max(0, sf:GetVerticalScroll() - d * 40)))
        PaintThumb()
    end)
    function pane:SetContentHeight(h)
        local vh = sf:GetHeight() or 0
        local w = sf:GetWidth() or 0
        if w > 0 then self:SetWidth(w) end
        self:SetHeight(math.max(h, vh))
        local max = math.max(0, self:GetHeight() - vh)
        if self.keepY and h > 0 then sf:SetVerticalScroll(math.min(self.keepY, max)); self.keepY = nil end
        if sf:GetVerticalScroll() > max then sf:SetVerticalScroll(max) end
        PaintThumb()
    end

    -- 기능 머리: 아이콘 · 이름 · 설명 · (미리 보기) · 쓰기 스위치
    local hd = CreateFrame("Frame", nil, f)
    hd:SetPoint("TOPLEFT", RAIL + 1, -HEAD); hd:SetPoint("TOPRIGHT", -1, -HEAD); hd:SetHeight(PHEAD)
    hd:SetClipsChildren(true)
    local glow = hd:CreateTexture(nil, "BACKGROUND", nil, 2)
    glow:SetTexture(ns.MEDIA .. "soft_glow"); glow:SetBlendMode("ADD")
    glow:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.22)
    glow:SetSize(420, 200); glow:SetPoint("CENTER", hd, "TOPLEFT", 120, 0)
    hd.glow = glow
    hd.disc = IconDisc(hd, 48, "icon")
    hd.disc:SetPoint("LEFT", 22, -2)
    hd.disc.bg:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.16)
    hd.disc.ic:SetVertexColor(C.accHi[1], C.accHi[2], C.accHi[3], 1)
    hd.title = ns.Font(hd, 21)
    hd.title:SetPoint("TOPLEFT", hd.disc, "TOPRIGHT", 14, 0)
    hd.desc = ns.Font(hd, 11.5, { 0.74, 0.64, 0.62 })
    hd.desc:SetPoint("TOPLEFT", hd.title, "BOTTOMLEFT", 0, -5)
    hd.desc:SetJustifyH("LEFT"); hd.desc:SetJustifyV("TOP")
    if hd.desc.SetMaxLines then hd.desc:SetMaxLines(2) end
    hd.use = CreateFrame("Button", nil, hd)
    hd.use:SetSize(128, 32); hd.use:SetPoint("RIGHT", -20, 0)
    hd.use.bg, hd.use.edge = ns.RoundPlate(hd.use, 16, { 0.15, 0.11, 0.10, 0.95 }, { 1, 1, 1, 0.08 })
    hd.use.fs = ns.Font(hd.use, 12.5); hd.use.fs:SetPoint("LEFT", 14, 0)
    hd.use.sw = Switch(hd.use); hd.use.sw:SetPoint("RIGHT", -10, 0)
    hd.pv = ns.MakeButton(hd, "미리 보기", false, nil, 80)
    hd.pv:SetHeight(28)
    -- Leel HUD: 전체 크기 · 자리 초기화 (예전 '기타' 탭 자리)
    hd.allB = ns.MakeButton(hd, "전체 크기", false, nil, 76); hd.allB:SetHeight(28)
    hd.allB:SetPoint("RIGHT", hd.use, "LEFT", -8, 0)
    hd.rstB = ns.MakeButton(hd, "자리 초기화", false, nil, 80); hd.rstB:SetHeight(28)
    hd.rstB:SetPoint("RIGHT", hd.allB, "LEFT", -6, 0)
    hd.allB:Hide(); hd.rstB:Hide()
    hd.desc:SetPoint("RIGHT", hd, "RIGHT", -170, 0)

    -- 탭 줄
    local tb = CreateFrame("Frame", nil, f)
    tb:SetPoint("TOPLEFT", RAIL + 1, -(HEAD + PHEAD)); tb:SetPoint("TOPRIGHT", -1, -(HEAD + PHEAD))
    tb:SetHeight(TABH)
    local tbg = tb:CreateTexture(nil, "BACKGROUND"); tbg:SetAllPoints(); tbg:SetColorTexture(0, 0, 0, 0.16)
    local tl = tb:CreateTexture(nil, "BORDER"); tl:SetColorTexture(0.949, 0.702, 0.761, 0.15); tl:SetHeight(1)
    tl:SetPoint("BOTTOMLEFT"); tl:SetPoint("BOTTOMRIGHT")
    tb.tabs = {}

    pane.hd, pane.tb = hd, tb
    pane.title, pane.desc = hd.title, hd.desc
    pane.note = ns.Font(pane, 12.5, C.tx2)
    pane.note:SetPoint("TOPLEFT", PADX + 2, -18)
    pane.note:SetPoint("RIGHT", -PADX, 0)
    pane.note:SetJustifyH("LEFT")
    pane.rows, pane.btns, pane.cards, pane.newsFS = {}, {}, {}, {}
    return pane
end

local function TabBtn(tb, i)
    local b = tb.tabs[i]
    if b then return b end
    b = CreateFrame("Button", nil, tb)
    b:SetHeight(TABH)
    b.fs = ns.Font(b, 13); b.fs:SetPoint("CENTER", 0, 1)
    b.bar = b:CreateTexture(nil, "OVERLAY")
    b.bar:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 1)
    b.bar:SetHeight(3); b.bar:SetPoint("BOTTOMLEFT", 8, 0); b.bar:SetPoint("BOTTOMRIGHT", -8, 0)
    b.glow = b:CreateTexture(nil, "ARTWORK")
    b.glow:SetTexture(ns.MEDIA .. "soft_glow"); b.glow:SetBlendMode("ADD")
    b.glow:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.35)
    b.glow:SetPoint("BOTTOMLEFT", 0, -10); b.glow:SetPoint("BOTTOMRIGHT", 0, -10); b.glow:SetHeight(22)
    tb.tabs[i] = b
    return b
end

local function Card(pane, i)
    local c = pane.cards[i]
    if c then return c end
    c = CreateFrame("Frame", nil, pane)
    c.fill, c.edge = ns.RoundPlate(c, 12, { 0.165, 0.125, 0.115, 0.92 }, { 1, 1, 1, 0.06 })
    pane.cards[i] = c
    return c
end

local function ClearPane(pane)
    for _, r in ipairs(pane.rows) do r:Hide() end
    for _, r in ipairs(pane.choices or {}) do r:Hide() end
    for _, r in ipairs(pane.sliders or {}) do r:Hide() end
    for _, r in ipairs(pane.segs or {}) do r:Hide() end
    for _, c in ipairs(pane.cards) do c:Hide() end
    for _, fs in ipairs(pane.newsFS) do fs:Hide() end
    if pane.news then pane.news:Hide() end
    if ns.HubShareHide then ns.HubShareHide() end
    if pane.editRow then pane.editRow:Hide() end
    if pane.sizeRow then pane.sizeRow:Hide() end
    if pane.fstateRow then pane.fstateRow:Hide() end
    if pane.band then pane.band:Hide() end
    if pane.cardRow then pane.cardRow:Hide() end
    if pane.input then pane.input:Hide() end
    if dd then dd:Hide() end
    for _, b in ipairs(pane.btns) do b:Hide() end
    for _, h in ipairs(pane.heads or {}) do h:Hide() end
    pane.note:SetText("")
end

-- 묶음 제목 줄: 분홍 작은 제목 + 가는 선 (+ 오른쪽 작은 글자 버튼)
local function HeaderRow(pane, i)
    pane.heads = pane.heads or {}
    local h = pane.heads[i]
    if h then return h end
    h = CreateFrame("Frame", nil, pane)
    h:SetHeight(20)
    h.label = ns.Font(h, 11.5, C.acc); h.label:SetPoint("LEFT", 0, 0)
    h.line = h:CreateTexture(nil, "BORDER")
    h.line:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.25); h.line:SetHeight(1)
    h.line:SetPoint("LEFT", h.label, "RIGHT", 8, 0)
    h.btn = CreateFrame("Button", nil, h)
    h.btn:SetHeight(18)
    h.btn.fs = ns.Font(h.btn, 10.5, { 0.62, 0.54, 0.52 }); h.btn.fs:SetPoint("RIGHT", 0, 0)
    h.btn:SetScript("OnEnter", function(self) self.fs:SetTextColor(C.accHi[1], C.accHi[2], C.accHi[3]) end)
    h.btn:SetScript("OnLeave", function(self) self.fs:SetTextColor(0.62, 0.54, 0.52) end)
    h.btn:SetPoint("RIGHT", 0, 0)
    h.no = h:CreateTexture(nil, "ARTWORK"); h.no:SetTexture(ns.MEDIA .. "circle"); h.no:SetSize(20, 20)
    h.no:SetVertexColor(C.acc[1], C.acc[2], C.acc[3]); h.no:SetPoint("LEFT", 0, 0)
    h.nofs = ns.Font(h, 11, C.ink, "OVERLAY"); h.nofs:SetPoint("CENTER", h.no, "CENTER", 0, 0)
    pane.heads[i] = h
    return h
end

local function ToggleRow(pane, i)
    local r = pane.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, pane)
    r:SetHeight(36)
    r.name = ns.Font(r, 13); r.name:SetPoint("TOPLEFT", 0, -6)
    r.hint = ns.Font(r, 10.5, { 0.62, 0.54, 0.52 }); r.hint:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
    r.sw = Switch(r); r.sw:SetPoint("RIGHT", 0, 0)
    -- 하위 설정 표시 (└)
    r.tv = r:CreateTexture(nil, "BORDER"); r.tv:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.45)
    r.tv:SetWidth(1.5); r.tv:SetPoint("TOPLEFT", 6, 2); r.tv:SetPoint("BOTTOMLEFT", r, "LEFT", 6, 0)
    r.th = r:CreateTexture(nil, "BORDER"); r.th:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.45)
    r.th:SetHeight(1.5); r.th:SetPoint("LEFT", 6, 0); r.th:SetWidth(8)
    r.line = r:CreateTexture(nil, "BORDER")
    r.line:SetColorTexture(0.839, 0.627, 0.612, 0.10); r.line:SetHeight(1)
    r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT")
    r:SetScript("OnEnter", function(self) self.name:SetTextColor(1, 1, 1) end)
    r:SetScript("OnLeave", function(self) self.name:SetTextColor(C.tx[1], C.tx[2], C.tx[3]) end)
    pane.rows[i] = r
    return r
end

-- 고르기 줄: 이름 + 회색 설명 + 오른쪽 알약(현재 값, 그 글꼴로)
-- 한 줄짜리 고르기 (보통 · 크게 · 아주 크게 같은 몇 단계)
local function SegRow(pane, i)
    pane.segs = pane.segs or {}
    local r = pane.segs[i]
    if r then return r end
    r = CreateFrame("Frame", nil, pane)
    r:SetHeight(36)
    r.name = ns.Font(r, 13); r.name:SetPoint("LEFT", 0, 0)
    r.hint = ns.Font(r, 10.5, { 0.62, 0.54, 0.52 }); r.hint:SetPoint("LEFT", r.name, "RIGHT", 8, -1)
    r.btns = {}
    r.line = r:CreateTexture(nil, "BORDER")
    r.line:SetColorTexture(0.839, 0.627, 0.612, 0.10); r.line:SetHeight(1)
    r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT")
    function r:Btn(k)
        local b = self.btns[k]
        if b then return b end
        b = CreateFrame("Button", nil, self)
        b:SetHeight(24)
        b.bg = ns.RoundRect(b, 12, { 0.23, 0.18, 0.17 }, "BACKGROUND", 0, 0)
        b.fs = ns.Font(b, 12); b.fs:SetPoint("CENTER", 0, 0)
        self.btns[k] = b
        return b
    end
    pane.segs[i] = r
    return r
end

local function ChoiceRow(pane, i)
    pane.choices = pane.choices or {}
    local r = pane.choices[i]
    if r then return r end
    r = CreateFrame("Frame", nil, pane)
    r:SetHeight(36)
    r.name = ns.Font(r, 13); r.name:SetPoint("LEFT", 0, 0)
    r.hint = ns.Font(r, 10.5, { 0.62, 0.54, 0.52 }); r.hint:SetPoint("LEFT", r.name, "RIGHT", 8, -1)
    r.pill = CreateFrame("Button", nil, r)
    r.pill:SetHeight(24); r.pill:SetPoint("RIGHT", 0, 0)
    r.pill.bg = ns.RoundRect(r.pill, 12, { 0.23, 0.18, 0.17 }, "BACKGROUND", 0, 0)
    r.pill.fs = ns.LWrap(r.pill:CreateFontString(nil, "OVERLAY"))
    r.pill.fs:SetPoint("LEFT", 12, 0)
    r.pill.ic = r.pill:CreateTexture(nil, "OVERLAY"); r.pill.ic:SetSize(18, 18); r.pill.ic:SetPoint("LEFT", 4, 0)
    r.pill.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local icm = r.pill:CreateMaskTexture(); icm:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icm:SetAllPoints(r.pill.ic); r.pill.ic:AddMaskTexture(icm)
    r.pill.ar = r.pill:CreateTexture(nil, "OVERLAY"); r.pill.ar:SetTexture(ns.MEDIA .. "hb_down")
    r.pill.ar:SetSize(11, 11); r.pill.ar:SetVertexColor(C.acc[1], C.acc[2], C.acc[3]); r.pill.ar:SetPoint("RIGHT", -9, 0)
    r.pill:SetScript("OnEnter", function(self) self.bg:SetColor({ 0.32, 0.25, 0.24 }, 1) end)
    r.pill:SetScript("OnLeave", function(self) self.bg:SetColor({ 0.23, 0.18, 0.17 }, 1) end)
    -- 적용 시점 꼬리표: 바로 / 다시 불러오기 / 재접속
    r.when = CreateFrame("Frame", nil, r)
    r.when:SetHeight(16)
    r.when:SetPoint("RIGHT", r.pill, "LEFT", -6, 0)
    r.when.bg = ns.RoundRect(r.when, 8, nil, "BACKGROUND", 0, 0)
    r.when.fs = ns.Font(r.when, 10); r.when.fs:SetPoint("CENTER", 0, 0)
    r.line = r:CreateTexture(nil, "BORDER")
    r.line:SetColorTexture(0.839, 0.627, 0.612, 0.10); r.line:SetHeight(1)
    r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT")
    pane.choices[i] = r
    return r
end

local function ChoiceOptions(slot)
    if slot == "size" then return ns.FONT_SIZES or {} end
    local out = {}
    for _, f in ipairs(ns.FONT_LIST or {}) do
        if not f.numOnly or slot == "num" then out[#out + 1] = f end
    end
    return out
end

local function LabelFor(slot, key)
    for _, o in ipairs(ChoiceOptions(slot)) do if o.key == key then return o.label, o.file end end
    return tostring(key)
end

local ShowPane
local function OpenDropdown(anchor, slot, onPick)
    if not dd then
        dd = CreateFrame("Frame", nil, hub)
        dd:SetFrameStrata("FULLSCREEN_DIALOG")
        dd:EnableMouse(true)
        ns.RoundPlate(dd, 12, { 0.125, 0.094, 0.086, 0.98 }, { 0.949, 0.702, 0.761, 0.6 })
        dd.items = {}
        dd:SetScript("OnUpdate", function(self)
            if not self:IsMouseOver(20, -20, -20, 20) and not (self.anchor and self.anchor:IsMouseOver()) then
                self.away = (self.away or 0) + 1
                if self.away > 40 then self:Hide() end
            else
                self.away = 0
            end
        end)
    end
    local opts, cur
    if type(slot) == "table" then opts = slot.options(); cur = slot.get()
    else opts = ChoiceOptions(slot); cur = ns.db.font and ns.db.font[slot] end
    local w = 150
    for i, o in ipairs(opts) do
        local b = dd.items[i]
        if not b then
            b = CreateFrame("Button", nil, dd)
            b:SetHeight(24)
            b.hl = ns.RoundRect(b, 10, nil, "BACKGROUND", 2, 0)
            b.fs = ns.LWrap(b:CreateFontString(nil, "OVERLAY")); b.fs:SetPoint("LEFT", 10, 0)
            b.tag = ns.Font(b, 10, { 0.62, 0.54, 0.52 }); b.tag:SetPoint("RIGHT", -8, 0)
            b.ic = b:CreateTexture(nil, "OVERLAY"); b.ic:SetSize(20, 20); b.ic:SetPoint("LEFT", 6, 0)
            b.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local m_ = b:CreateMaskTexture(); m_:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            m_:SetAllPoints(b.ic); b.ic:AddMaskTexture(m_)
            dd.items[i] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 25); b:SetPoint("TOPRIGHT", -6, -6 - (i - 1) * 25)
        if not (o.file and b.fs:SetFont(o.file, 14, "")) then b.fs:SetFont(ns.FONT, 13, "") end
        b.fs:SetText(o.label)
        b.tag:SetText("")
        b.ic:SetShown(o.icon and true or false); if o.icon then b.ic:SetTexture(o.icon) end
        b.fs:ClearAllPoints(); b.fs:SetPoint("LEFT", o.icon and 32 or 10, 0)
        local on = o.key == cur
        b.hl:SetColor(on and C.acc or { 1, 1, 1 }, on and 1 or 0)
        local tc = on and C.ink or C.tx
        b.fs:SetTextColor(tc[1], tc[2], tc[3])
        b:SetScript("OnEnter", function(self) if not on then self.hl:SetColor({ 1, 1, 1 }, 0.08) end end)
        b:SetScript("OnLeave", function(self) self.hl:SetColor(on and C.acc or { 1, 1, 1 }, on and 1 or 0) end)
        b:SetScript("OnClick", function() dd:Hide(); onPick(o.key) end)
        b:Show()
        w = math.max(w, b.fs:GetStringWidth() + 80 + (o.icon and 22 or 0))
    end
    for i = #opts + 1, #dd.items do dd.items[i]:Hide() end
    dd:SetSize(w, #opts * 25 + 12)
    dd.anchor = anchor
    dd.away = 0
    dd:ClearAllPoints()
    dd:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    dd:Show()
end

-- 글자 입력 줄 (파일 이름 등)
local function InputRow(pane)
    if pane.input then return pane.input end
    local r = CreateFrame("Frame", nil, pane)
    r:SetHeight(40)
    r.name = ns.Font(r, 13); r.name:SetPoint("TOPLEFT", 0, -2)
    r.hint = ns.Font(r, 10.5, { 0.62, 0.54, 0.52 }); r.hint:SetPoint("LEFT", r.name, "RIGHT", 8, -1)
    r.btn = ns.MakeButton(r, "추가", true, nil, 56)
    r.btn:SetHeight(24)
    r.btn:SetPoint("BOTTOMRIGHT", 0, 0)
    local box = CreateFrame("EditBox", nil, r)
    box:SetHeight(24)
    box:SetPoint("BOTTOMLEFT", 0, 0)
    box:SetPoint("RIGHT", r.btn, "LEFT", -6, 0)
    box:SetAutoFocus(false)
    box:SetFont(STANDARD_TEXT_FONT or ns.FONT, 12, "")
    box:SetTextInsets(10, 10, 0, 0)
    box:SetMaxLetters(80)
    box.bg = ns.RoundRect(box, 12, { 0.23, 0.18, 0.17 }, "BACKGROUND", 0, 0)
    box.ph = ns.LWrap(box:CreateFontString(nil, "ARTWORK")); box.ph:SetFont(STANDARD_TEXT_FONT or ns.FONT, 12, "")
    box.ph:SetTextColor(0.5, 0.44, 0.42); box.ph:SetPoint("LEFT", 10, 0)
    box.ph:SetText("예: Cafe24DongdongRegular.ttf")
    box:SetScript("OnTextChanged", function(self) self.ph:SetShown(self:GetText() == "") end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self) self.bg:SetColor({ 0.32, 0.25, 0.24 }, 1) end)
    box:SetScript("OnEditFocusLost", function(self) self.bg:SetColor({ 0.23, 0.18, 0.17 }, 1) end)
    r.box = box
    r.line = r:CreateTexture(nil, "BORDER")
    r.line:SetColorTexture(0.839, 0.627, 0.612, 0.10); r.line:SetHeight(1)
    r.line:SetPoint("BOTTOMLEFT", 0, -8); r.line:SetPoint("BOTTOMRIGHT", 0, -8)
    pane.input = r
    return r
end

-- 크기 줄: 이름 + 큰 숫자 + 분홍 트랙 (휠로도 조절)
local function SliderRow(pane, i)
    pane.sliders = pane.sliders or {}
    local r = pane.sliders[i]
    if r then return r end
    r = CreateFrame("Frame", nil, pane)
    r:SetHeight(50)
    r.name = ns.Font(r, 13); r.name:SetPoint("TOPLEFT", 0, -4)
    r.val = ns.Num(r, 17, C.accHi); r.val:SetPoint("TOPRIGHT", 0, -1)
    local s = CreateFrame("Slider", nil, r)
    s:SetOrientation("HORIZONTAL")
    s:SetHeight(16)
    s:SetPoint("TOPLEFT", 0, -26); s:SetPoint("TOPRIGHT", 0, -26)
    s:SetValueStep(1)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)
    -- 트랙은 줄(r)에 붙이고 슬라이더를 그 위로 (손잡이가 가려지지 않게)
    -- B안 젤리 바: 안으로 파인 어두운 홈 + 분홍 그라데이션 + 은은한 빛 · 끄는 동안 값 말풍선
    local tr = CreateFrame("Frame", nil, r)
    tr:SetHeight(10); tr:SetPoint("LEFT", s, "LEFT"); tr:SetPoint("RIGHT", s, "RIGHT")
    s:SetFrameLevel(tr:GetFrameLevel() + 3)
    ns.RoundRect(tr, 5, nil, "BACKGROUND", 0, 0):SetColor({ 0.075, 0.055, 0.05 }, 1)
    local inner = tr:CreateTexture(nil, "BACKGROUND", nil, 1)   -- 홈 위쪽 그늘 (파인 느낌)
    inner:SetTexture(ns.WHITE); inner:SetVertexColor(0, 0, 0, 0.55); inner:SetHeight(2)
    inner:SetPoint("TOPLEFT", 4, 0); inner:SetPoint("TOPRIGHT", -4, 0)
    r.fill = CreateFrame("Frame", nil, tr)
    r.fill:SetHeight(10); r.fill:SetPoint("LEFT")
    ns.RoundRect(r.fill, 5, C.acc, "BORDER", 0, 0)
    -- 왼쪽은 진한 분홍 → 오른쪽 밝은 분홍
    local grad = r.fill:CreateTexture(nil, "BORDER", nil, 2)
    grad:SetTexture(ns.WHITE); grad:SetPoint("TOPLEFT", 3, 0); grad:SetPoint("BOTTOMRIGHT", -3, 0)
    if grad.SetGradient and CreateColor then
        grad:SetGradient("HORIZONTAL", CreateColor(0.72, 0.38, 0.48, 0.85), CreateColor(1, 0.88, 0.91, 0.35))
    else
        grad:SetVertexColor(0.72, 0.38, 0.48, 0.4)
    end
    local gloss = r.fill:CreateTexture(nil, "ARTWORK")   -- 위쪽 윤기
    gloss:SetTexture(ns.WHITE); gloss:SetVertexColor(1, 1, 1, 0.22); gloss:SetHeight(3)
    gloss:SetPoint("TOPLEFT", 5, -1); gloss:SetPoint("TOPRIGHT", -5, -1)
    local glow = r.fill:CreateTexture(nil, "BACKGROUND", nil, -2)
    glow:SetTexture(ns.MEDIA .. "soft_glow"); glow:SetBlendMode("ADD"); glow:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.28)
    glow:SetPoint("TOPLEFT", -8, 10); glow:SetPoint("BOTTOMRIGHT", 8, -10)
    -- 손잡이: 어두운 테 + 연분홍 젤리 + 왼쪽 위 반짝
    local thumb = s:CreateTexture(nil, "OVERLAY", nil, 1)
    thumb:SetTexture(ns.MEDIA .. "circle"); thumb:SetSize(24, 24)
    thumb:SetVertexColor(0.165, 0.1, 0.11, 1)
    s:SetThumbTexture(thumb)
    local tin = s:CreateTexture(nil, "OVERLAY", nil, 2)
    tin:SetTexture(ns.MEDIA .. "circle"); tin:SetPoint("TOPLEFT", thumb, "TOPLEFT", 2, -2); tin:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", -2, 2)
    tin:SetVertexColor(1, 0.84, 0.88, 1)
    local shine = s:CreateTexture(nil, "OVERLAY", nil, 3)
    shine:SetTexture(ns.MEDIA .. "circle"); shine:SetSize(8, 8); shine:SetPoint("CENTER", thumb, "CENTER", -4, 4)
    shine:SetVertexColor(1, 1, 1, 0.85)
    -- 끄는 동안 값 말풍선 (글자를 먼저 놓고 판이 감싸요)
    local bub = CreateFrame("Frame", nil, s); bub:SetFrameLevel(s:GetFrameLevel() + 6)
    bub.fs = ns.Font(bub, 11.5, C.ink); bub.fs:SetShadowColor(0, 0, 0, 0)
    bub.fs:SetPoint("BOTTOM", thumb, "TOP", 0, 7)
    bub:SetPoint("TOPLEFT", bub.fs, "TOPLEFT", -7, 3); bub:SetPoint("BOTTOMRIGHT", bub.fs, "BOTTOMRIGHT", 7, -3)
    ns.RoundRect(bub, 7, C.acc, "BACKGROUND", 0, 0)
    bub:Hide()
    r.bub = bub
    r.s = s
    r.line = r:CreateTexture(nil, "BORDER")
    r.line:SetColorTexture(0.839, 0.627, 0.612, 0.10); r.line:SetHeight(1)
    r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT")
    -- 노란 눈금 = 허브를 열 때 값 (끌다가 가까이 가면 착 · 오른쪽 클릭 = 그 값으로)
    local mf = CreateFrame("Frame", nil, tr); mf:SetAllPoints(tr); mf:SetFrameLevel(r.fill:GetFrameLevel() + 2)   -- 분홍 바 위에
    r.mark = mf:CreateTexture(nil, "ARTWORK", nil, 3)
    r.mark:SetTexture(ns.WHITE); r.mark:SetVertexColor(1, 0.84, 0.35, 1); r.mark:SetSize(2, 14)
    r.markDot = mf:CreateTexture(nil, "ARTWORK", nil, 3)
    r.markDot:SetTexture(ns.MEDIA .. "circle"); r.markDot:SetVertexColor(1, 0.84, 0.35, 1); r.markDot:SetSize(6, 6)
    r.markDot:SetPoint("BOTTOM", r.mark, "TOP", 0, -1)
    r.mark:Hide(); r.markDot:Hide()
    function r:Paint(v)
        local lo, hi = self.s:GetMinMaxValues()
        self.val:SetFormattedText(self.fmt or "%d%%", v)
        if self.bub and self.bub:IsShown() then self.bub.fs:SetFormattedText(self.fmt or "%d%%", v) end
        local w = self.s:GetWidth(); if not w or w < 10 then w = 320 end
        self.fill:SetWidth(math.max(10, (v - lo) / math.max(1, hi - lo) * w))
        local sv = self.snapV
        if sv and sv ~= v then
            self.mark:ClearAllPoints()
            self.mark:SetPoint("CENTER", self.fill:GetParent(), "LEFT", (sv - lo) / math.max(1, hi - lo) * w, 0)
            self.mark:Show(); self.markDot:Show()
        else
            self.mark:Hide(); self.markDot:Hide()
        end
    end
    s:SetScript("OnSizeChanged", function() r:Paint(math.floor(s:GetValue() + 0.5)) end)
    pane.sliders[i] = r
    return r
end

local function PaneButton(pane, i)
    local b = pane.btns[i]
    if b then return b end
    b = ns.MakeButton(pane, "", false, nil, 80)
    pane.btns[i] = b
    return b
end

local function NewsCount()
    local seen = ns.db.hub and ns.db.hub.seenNews
    if not seen then return #NEWS > 0 and 1 or 0 end
    for i, n in ipairs(NEWS) do if n[1] == seen then return i - 1 end end
    return #NEWS
end

-- 기능 머리 칠하기
local function PaintHead(m)
    local hd = hub.pane.hd
    hd.disc.ic:SetTexture(ns.MEDIA .. m.icon)
    hd.title:SetText(m.title)
    hd.desc:SetText((m.desc or ""):gsub("\n", "  "))
    -- 새 소식도 다른 칸처럼 아이콘 · 빛 · 제목 · 설명 (모양을 맞춰요)
    hd.disc:Show(); if hd.glow then hd.glow:Show() end
    local exists = MExists(m)
    local show, on = true, false
    if m.news or (m.always and not m.onoff) then show = false
    elseif m.onoff then on = m.onoff.get() and true or false
    elseif not exists then show = false
    else on = Enabled(m.key) end
    hd.use:SetShown(show and m.tabs and true or false)
    if show then
        hd.use.fs:SetText((m.title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) .. " 쓰기")
        hd.use:SetWidth(math.min(220, hd.use.fs:GetStringWidth() + 72))
        hd.use.sw:Set(on)
        hd.use:SetScript("OnClick", function()
            if m.onoff then
                m.onoff.set(not m.onoff.get())
                Refresh()
                if m.onoff.reload then StaticPopup_Show("LEELUI_HUB_RELOAD") end
                return
            end
            if m.always or not Exists(m.key) then return end
            SetEnabled(m.key, not Enabled(m.key))
            Refresh()
            StaticPopup_Show("LEELUI_HUB_RELOAD")
        end)
    end
    local pv = PREVIEW[m.key]
    if false and pv then
        hd.pv:SetLabel(pv[1]); hd.pv:SetHeight(28)
        hd.pv:SetScript("OnClick", pv[2])
        hd.pv:ClearAllPoints()
        if show then hd.pv:SetPoint("RIGHT", hd.use, "LEFT", -8, 0) else hd.pv:SetPoint("RIGHT", hd, "RIGHT", -20, 0) end
        hd.pv:Show()
    else
        hd.pv:Hide()
    end
    -- Leel HUD 전체 크기 · 자리 초기화
    local isHud = m.key == "LeelUI" and MLoaded(m)
    hd.allB:SetShown(isHud and hd.use:IsShown()); hd.rstB:SetShown(isHud and hd.use:IsShown())
    if isHud then
        hd.allB:SetScript("OnClick", function() ns.HubMoveOpen(function() return ns.mover end, "Leel HUD 크기", "Leel HUD") end)
        hd.rstB:SetScript("OnClick", function()
            ns:ResetPosition(); if ns.ResetHudParts then ns:ResetHudParts() end
            Print("Leel HUD 자리를 처음대로 돌렸어요 (내 창 · 가운데 · 대상 창).")
        end)
        hd.allB:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText(ns.L("Leel HUD 전체 크기")); GameTooltip:AddLine(ns.L("이동 모드에서 토끼 손잡이 테두리 위 크기 줄"), 1, 1, 1); GameTooltip:Show() end)
        hd.allB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    -- 설명 글은 오른쪽 단추들 앞까지만
    local reserve = 24 + (hd.use:IsShown() and (hd.use:GetWidth() + 8) or 0)
        + (hd.allB:IsShown() and (hd.allB:GetWidth() + hd.rstB:GetWidth() + 16) or 0) + (hd.pv:IsShown() and (hd.pv:GetWidth() + 8) or 0)
    hd.desc:SetPoint("RIGHT", hd, "RIGHT", -reserve, 0)
end

-- ① 쓰기: 기능 켜기 · 끄기 줄 (머리 스위치 대신)
XP.UseOn = function(m)
    if m.news or (m.always and not m.onoff) then return nil end
    if m.onoff then return m.onoff.get() and true or false end
    if not MExists(m) then return nil end
    return Enabled(m.key) and true or false
end
XP.UseItem = function(m)
    if m.tabs or XP.UseOn(m) == nil then return nil end
    local name = (m.title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    local reload = (m.onoff and m.onoff.reload) or (not m.onoff)
    return { t = "toggle", label = name .. " 사용", hint = reload and "바꾸면 다시 불러오기" or nil,
        get = function() return XP.UseOn(m) end,
        set = function(v)
            if m.onoff then m.onoff.set(v and true or false)
            elseif not m.always and Exists(m.key) then SetEnabled(m.key, v and true or false) end
            if reload then StaticPopup_Show("LEELUI_HUB_RELOAD") end
            C_Timer.After(0.02, function() Refresh() end)
        end }
end

ShowPane = function()
    local pane, m = hub.pane, MODULES[sel]
    ClearPane(pane)
    if not hub.snapHooked then hub.snapHooked = true; hub:HookScript("OnShow", function() wipe(XP.snap) end) end
    -- 같은 칸에서 다시 그릴 때(스위치 · 고르기)는 내려 둔 자리 그대로
    local keepY = (pane.lastSel == sel) and (pane.sf:GetVerticalScroll() or 0) or 0
    if pane.lastSel ~= sel then pane.lastSel = sel; pane.sf:SetVerticalScroll(0) end
    pane:SetContentHeight(0)
    pane.keepY = keepY > 0 and keepY or nil
    pane.itemCard = {}
    PaintHead(m)

    -- 탭 줄
    local groups = Groups(m)
    local tabbed = m.tabs and #groups >= 2 and MLoaded(m) and not (m.needs and not Loaded(m.needs))
    local tb = pane.tb
    local tab = 1
    if tabbed then tab = math.min(curTab[m.key] or 1, #groups) end
    -- 크기 · 위치 탭 = 오른쪽 좁은 허브 (게임 화면을 보면서)
    local wantCompact = tabbed and groups[tab].size and true or false
    if wantCompact ~= (hub.compact or false) then SetCompact(wantCompact); return end
    if hub.compact then
        hub.cTitle:SetText(m.title)
        tb:Hide(); pane.hd:Hide()
        if hub.pv then hub.pv:Hide() end
        pane.sf:ClearAllPoints()
        pane.sf:SetPoint("TOPLEFT", 1, -(K.HEAD + 46))
        pane.sf:SetPoint("BOTTOMRIGHT", -2, K.FOOT)
    end
    pane.hd:SetShown(not hub.compact)
    if tabbed and not hub.compact then
        local x = 14
        for i, g in ipairs(groups) do
            local b = TabBtn(tb, i)
            b.fs:SetText(g.label)
            b:SetWidth(b.fs:GetStringWidth() + 30)
            b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", x, 0)
            x = x + b:GetWidth() + 2
            local on = i == tab
            local c = on and { 1, 1, 1 } or C.tx2
            b.fs:SetTextColor(c[1], c[2], c[3])
            b.bar:SetShown(on); b.glow:SetShown(on)
            b:SetScript("OnClick", function() curTab[m.key] = i; pane.sf:SetVerticalScroll(0); ShowPane() end)
            b:SetScript("OnEnter", function(self) if not on then self.fs:SetTextColor(1, 1, 1) end end)
            b:SetScript("OnLeave", function(self) if not on then self.fs:SetTextColor(C.tx2[1], C.tx2[2], C.tx2[3]) end end)
            b:Show()
        end
        for i = #groups + 1, #tb.tabs do tb.tabs[i]:Hide() end
        tb:Show()
    else
        tb:Hide()
    end
    local topY = tabbed and K.TOP or (K.HEAD + K.PHEAD)
    local wantPv = hub.pv and hub.pv:Wants(m) and not hub.compact
    -- 미리 보기가 있는 곳은 모두 같은 자리: 위에 가로 미리 보기 · 아래 설정 (Leel HUD 포함)
    m._sv = false
    if hub.pv then
        hub.pv:SetShown(wantPv and true or false)
        if wantPv then
            hub.pv:ClearAllPoints()
            if m._sv then
                -- B안: 왼쪽에 키 큰 미리 보기 (고정) · 오른쪽이 설정
                hub.pv:SetPoint("TOPLEFT", K.RAIL + 1 + K.PADX, -(topY + 12))
                hub.pv:SetPoint("BOTTOMLEFT", K.RAIL + 1 + K.PADX, K.FOOT + 12)
                hub.pv:SetWidth(XP.SVW)
                hub.pv:Update()
                C_Timer.After(0, function() if hub.pv:IsShown() then hub.pv:Update() end end)
            else
                hub.pv:SetPoint("TOPLEFT", K.RAIL + 1 + K.PADX, -(topY + 12))
                hub.pv:SetPoint("TOPRIGHT", -(K.PADX + 8 + ((m.explain and not hub.compact) and (XP.EXPW + 14) or 0)), -(topY + 12))
                local ph = K.PVH + 50   -- 모든 탭 미리 보기 높이 = Leel HUD 와 같게
                hub.pv:SetHeight(ph)
                hub.pv:Update()
                topY = topY + ph + 16
            end
        end
    end
    -- 꺼 둔 기능(설명 칸이 있는 곳): 설정은 흐리게
    pane.sf:SetAlpha((m.explain and m.onoff and not m.onoff.get()) and 0.4 or 1)
    -- B안: 미리 보기 아래 설명 (줄에 마우스를 올리면 바뀌어요)
    if hub.pv then
        local pv = hub.pv
        if m._sv and wantPv then
            if not pv.cap then
                pv.capLine = pv:CreateTexture(nil, "ARTWORK"); pv.capLine:SetColorTexture(1, 1, 1, 0.06); pv.capLine:SetHeight(1)
                pv.capT = ns.Font(pv, 13.5, C.tx)
                pv.cap = ns.Font(pv, 11.5, { 0.79, 0.7, 0.67 })
                pv.cap:SetJustifyH("LEFT"); pv.cap:SetJustifyV("TOP"); pv.cap:SetWordWrap(true)
                if pv.cap.SetSpacing then pv.cap:SetSpacing(3) end
            end
            pv.cap:ClearAllPoints(); pv.cap:SetPoint("BOTTOMLEFT", 14, 14); pv.cap:SetWidth(XP.SVW - 28)
            pv.capT:ClearAllPoints(); pv.capT:SetPoint("BOTTOMLEFT", pv.cap, "TOPLEFT", 0, 6)
            pv.capLine:ClearAllPoints(); pv.capLine:SetPoint("BOTTOMLEFT", pv.capT, "TOPLEFT", 0, 10); pv.capLine:SetWidth(XP.SVW - 28)
            local g = tabbed and groups[tab]
            local hd = g and g.head
            pv.capT:SetText(hd and LabelOf(hd.label) or "")
            pv.cap:SetText((hd and hd.more) or "오른쪽 줄에 마우스를 올리면 바뀌는 곳이 분홍 테로 반짝여요.")
            if m.onoff and not m.onoff.get() then
                pv.capT:SetText(m.title .. " 안 쓰는 중")
                pv.cap:SetText("게임 기본 플레이어 · 대상 창을 써요.\n위 '" .. m.title .. " 쓰기'를 켜면 다시 불러온 뒤 바뀌어요.")
            end
            pv.introT, pv.introC = pv.capT:GetText(), pv.cap:GetText()
            pv.cap:Show(); pv.capT:Show(); pv.capLine:Show()
            pv.stage:ClearAllPoints(); pv.stage:SetPoint("TOPLEFT", 8, -32); pv.stage:SetPoint("BOTTOMRIGHT", -8, 118)
            XP.Set(nil)
        elseif pv.cap then
            pv.cap:Hide(); pv.capT:Hide(); pv.capLine:Hide()
            pv.stage:ClearAllPoints(); pv.stage:SetPoint("TOPLEFT", 8, -32); pv.stage:SetPoint("BOTTOMRIGHT", -8, 8)
            XP.Set(nil)
        end
    end
    -- 오른쪽 '설정 설명' 칸 (Leel HUD)
    do
        local ex = hub.explain
        if m.explain and not m._sv and not hub.compact then
            ex = ex or XP.Build()
            ex:ClearAllPoints()
            ex:SetPoint("TOPRIGHT", hub, "TOPRIGHT", -(K.PADX + 8), -((tabbed and K.TOP or (K.HEAD + K.PHEAD)) + 12))
            ex:SetPoint("BOTTOMRIGHT", hub, "BOTTOMRIGHT", -(K.PADX + 8), K.FOOT + 12)
            ex:SetWidth(XP.EXPW)
            ex:Show()
            local g = tabbed and groups[tab]
            ex:Say(g and g.head or m)
        elseif ex then
            ex:Hide()
        end
    end
    if not hub.compact then
        pane.sf:ClearAllPoints()
        pane.sf:SetPoint("TOPLEFT", K.RAIL + 1 + ((m._sv and wantPv) and (XP.SVW + 4) or 0), -topY)
        pane.sf:SetPoint("BOTTOMRIGHT", -2, K.FOOT)
    end

    -- 새 소식: 최신 버전은 큰 카드(기능마다 한 칸 + 바로 가기) · 그 다음은 한 줄 카드 · 나머지는 작은 줄 3개 + 더 보기
    if m.news then
        local nw = pane.news
        if not nw then
            nw = CreateFrame("Frame", nil, pane); nw:SetPoint("TOPLEFT"); nw:SetPoint("TOPRIGHT"); nw:SetHeight(1)
            nw.fs, nw.plates, nw.btns, nw.badges = {}, {}, {}, {}
            nw.top = CreateFrame("Frame", nil, nw); nw.top:SetAllPoints()   -- 글자는 카드 판 위에
            pane.news = nw
        end
        nw:Show()
        nw.top:SetFrameLevel(nw:GetFrameLevel() + 5)
        local nfs, npl, nbt, nbd = 0, 0, 0, 0
        local function FS(size, col, num)
            nfs = nfs + 1
            local f = nw.fs[nfs]
            if not f then
                f = num and ns.LWrap(nw.top:CreateFontString(nil, "OVERLAY")) or ns.Font(nw.top, size, col)
                nw.fs[nfs] = f
            end
            if num then f:SetFont(ns.NUM or ns.FONT, size, "") else f:SetFont(ns.FONT, size, "") end
            if col then f:SetTextColor(col[1], col[2], col[3]) end
            f:ClearAllPoints(); f:SetWidth(0); f:SetJustifyH("LEFT"); f:Show()
            return f
        end
        local function Plate(fill, edge)
            npl = npl + 1
            local pl = nw.plates[npl]
            if not pl then
                pl = CreateFrame("Frame", nil, nw)
                pl.fill, pl.edge = ns.RoundPlate(pl, 14, fill, edge)
                nw.plates[npl] = pl
            end
            pl.fill:SetColor({ fill[1], fill[2], fill[3] }, fill[4] or 1); pl.edge:SetColor({ edge[1], edge[2], edge[3] }, edge[4] or 1)
            pl:ClearAllPoints(); pl:Show()
            return pl
        end
        local function Badge(anchor)
            nbd = nbd + 1
            local bd = nw.badges[nbd]
            if not bd then
                bd = CreateFrame("Frame", nil, nw); bd:SetSize(34, 16)
                ns.RoundRect(bd, 6, { 1, 0.48, 0.58 }, "ARTWORK", 0, 0)
                bd.fs = ns.Font(bd, 10); bd.fs:SetPoint("CENTER", 0, 0); bd.fs:SetText("NEW"); bd.fs:SetTextColor(0.1, 0.05, 0.06); bd.fs:SetShadowColor(0, 0, 0, 0)
                nw.badges[nbd] = bd
            end
            bd:SetFrameLevel(nw:GetFrameLevel() + 6)
            bd:ClearAllPoints(); bd:SetPoint("LEFT", anchor, "RIGHT", 8, 0); bd:Show()
            return bd
        end
        local function Btn(label, primary, fn)
            nbt = nbt + 1
            local b = nw.btns[nbt]
            if not b then b = ns.MakeButton(nw, label, primary, nil, 60); nw.btns[nbt] = b end
            b.primary = primary; b:Paint(false); b:SetLabel(label); b:SetHeight(28)
            b:SetScript("OnClick", fn); b:SetFrameLevel(nw:GetFrameLevel() + 6)
            b:ClearAllPoints(); b:Show()
            return b
        end
        local function GoTo(key)
            for i, mm in ipairs(MODULES) do if mm.key == key then sel = i; Refresh(); return end end
        end
        local W = math.max(400, (pane.sf:GetWidth() or 700) - K.PADX * 2 - 8)
        local newN = NewsCount()
        -- A안: 타임라인 · 세로 선 위에 버전 점 (안 본 버전 = 분홍 점) · 기능마다 한 줄 + 오른쪽 "메뉴 ›" 바로 가기
        nw.rowsB = nw.rowsB or {}
        local nrw = 0
        local function RowB(fn)
            nrw = nrw + 1
            local r = nw.rowsB[nrw]
            if not r then
                r = CreateFrame("Button", nil, nw)
                r.fill, r.edge = ns.RoundPlate(r, 10, { 0.165, 0.125, 0.118, 0.95 }, { 1, 1, 1, 0.05 })
                r:SetScript("OnEnter", function(self) if self.fn then self.fill:SetColor({ 0.23, 0.17, 0.17 }, 0.98); self.edge:SetColor(C.acc, 0.5) end end)
                r:SetScript("OnLeave", function(self) self.fill:SetColor({ 0.165, 0.125, 0.118 }, 0.95); self.edge:SetColor({ 1, 1, 1 }, 0.05) end)
                nw.rowsB[nrw] = r
            end
            r.fn = fn
            r:SetScript("OnClick", fn)
            r:EnableMouse(fn and true or false)
            r.fill:SetColor({ 0.165, 0.125, 0.118 }, 0.95); r.edge:SetColor({ 1, 1, 1 }, 0.05)
            r:ClearAllPoints(); r:Show()
            return r
        end
        nw.icons = nw.icons or {}
        local nic = 0
        local function Icon(tex)
            nic = nic + 1
            local t = nw.icons[nic]
            if not t then t = nw.top:CreateTexture(nil, "OVERLAY"); t:SetSize(15, 15); nw.icons[nic] = t end
            t:SetTexture(tex); t:SetVertexColor(C.accHi[1], C.accHi[2], C.accHi[3], 1)
            t:ClearAllPoints(); t:Show()
            return t
        end
        local function ModOf(key) for _, mm in ipairs(MODULES) do if mm.key == key then return mm end end end
        -- 세로 선
        if not nw.line then nw.line = nw:CreateTexture(nil, "BACKGROUND", nil, 1); nw.line:SetTexture(ns.WHITE) end
        local LX = K.PADX + 10
        nw.line:SetVertexColor(0.24, 0.18, 0.17, 1); nw.line:SetWidth(2)
        nw.dots = nw.dots or {}
        local ndt = 0
        local function Dot(on, yy)
            ndt = ndt + 1
            local d = nw.dots[ndt]
            if not d then
                d = CreateFrame("Frame", nil, nw); d:SetSize(14, 14)
                d.ring = d:CreateTexture(nil, "ARTWORK"); d.ring:SetTexture(ns.MEDIA .. "circle"); d.ring:SetAllPoints()
                d.core = d:CreateTexture(nil, "OVERLAY"); d.core:SetTexture(ns.MEDIA .. "circle"); d.core:SetSize(9, 9); d.core:SetPoint("CENTER")
                d.glow = d:CreateTexture(nil, "BACKGROUND"); d.glow:SetTexture(ns.MEDIA .. "soft_glow"); d.glow:SetBlendMode("ADD"); d.glow:SetSize(34, 34); d.glow:SetPoint("CENTER")
                nw.dots[ndt] = d
            end
            d:SetFrameLevel(nw:GetFrameLevel() + 4)
            if on then
                d.ring:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1); d.core:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
                d.glow:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.5); d.glow:Show()
            else
                d.ring:SetVertexColor(0.42, 0.27, 0.28, 1); d.core:SetVertexColor(0.165, 0.125, 0.118, 1); d.glow:Hide()
            end
            d:ClearAllPoints(); d:SetPoint("CENTER", nw, "TOPLEFT", LX + 1, yy); d:Show()
        end
        local y = -10
        local last = pane.newsAll and #NEWS or math.min(#NEWS, 4)
        local RX = K.PADX + 30            -- 줄 시작
        local RW = W - 30
        for i = 1, last do
            local n = NEWS[i]
            local new = i <= newN
            Dot(new, y - 9)
            local v = FS(15, new and C.acc or C.accHi, true); v:SetPoint("TOPLEFT", nw, "TOPLEFT", RX, y); v:SetText(n[1])
            if new then Badge(v) end
            y = y - 26
            local feats = n.feats or { { n[2], n[3] } }
            for _, ft in ipairs(feats) do
                local mm = ft[3] and ModOf(ft[3])
                local r = RowB(mm and function() GoTo(ft[3]) end or nil)
                r:SetPoint("TOPLEFT", nw, "TOPLEFT", RX, y); r:SetSize(RW, 32)
                local ic = Icon(ns.MEDIA .. ((mm and mm.icon) or "hb_bell")); ic:SetPoint("LEFT", r, "LEFT", 10, 0)
                local a = FS(13, { 1, 0.96, 0.95 }); a:SetPoint("LEFT", r, "LEFT", 34, 0); a:SetText(ft[1])
                if ft[2] and ft[2] ~= "" then
                    local d = FS(11, { 0.56, 0.48, 0.46 }); d:SetPoint("LEFT", a, "RIGHT", 8, 0); d:SetText("· " .. ft[2])
                    d:SetPoint("RIGHT", r, "RIGHT", -110, 0); if d.SetWordWrap then d:SetWordWrap(false) end
                end
                if mm then
                    local g = FS(11.5, C.acc); g:SetPoint("RIGHT", r, "RIGHT", -12, 0); g:SetJustifyH("RIGHT")
                    g:SetText((mm.title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) .. " ›")
                end
                y = y - 36
            end
            y = y - 12
        end
        nw.line:ClearAllPoints()
        nw.line:SetPoint("TOP", nw, "TOPLEFT", LX + 1, -8); nw.line:SetPoint("BOTTOM", nw, "TOPLEFT", LX + 1, y + 16)
        nw.line:Show()
        if #NEWS > 4 then
            local lbl = pane.newsAll and "접기" or ("지난 소식 " .. (#NEWS - 4) .. "개 더 보기")
            local b = Btn(lbl, false, function() pane.newsAll = not pane.newsAll; ShowPane() end)
            b:SetPoint("TOPLEFT", nw, "TOPLEFT", RX, y - 2)
            y = y - 42
        end
        for i = nrw + 1, #nw.rowsB do nw.rowsB[i]:Hide() end
        for i = nic + 1, #nw.icons do nw.icons[i]:Hide() end
        for i = ndt + 1, #nw.dots do nw.dots[i]:Hide() end
        for i = nfs + 1, #nw.fs do nw.fs[i]:Hide() end
        for i = npl + 1, #nw.plates do nw.plates[i]:Hide() end
        for i = nbt + 1, #nw.btns do nw.btns[i]:Hide() end
        for i = nbd + 1, #nw.badges do nw.badges[i]:Hide() end
        pane:SetContentHeight(-y + 10)
        C_Timer.After(1.5, function()
            if NEWS[1] and ns.db.hub then ns.db.hub.seenNews = NEWS[1][1]; if hub:IsShown() then PaintRail() end end
        end)
        return
    end

    -- 설정 나누기 (B안): 보내기 / 받기 · 토끼 배달 · 3단계
    if m.share and ns.HubSharePane then
        local W = math.max(300, (pane.sf:GetWidth() or 700) - K.PADX * 2 - 8)
        local hh = ns.HubSharePane(pane, K.PADX, -12, W)
        pane:SetContentHeight(hh + 24)
        return
    end
    if not MExists(m) then
        pane.note:SetText("이 컴퓨터에는 설치되어 있지 않아요.")
        return
    end
    if not MLoaded(m) then
        local en = MEnabled(m)
        pane.note:SetText(en and "켜 두었어요. 다시 불러오면 설정이 나타나요."
            or (m.always and "애드온 목록에서 꺼져 있어요. 아래 단추로 켜고 다시 불러오세요."
                or "꺼져 있어요. 위 '쓰기' 스위치로 켜고 다시 불러오면 설정할 수 있어요."))
        if m.always and not m.builtin then
            local b = PaneButton(pane, 1)
            b:SetLabel(en and "다시 불러오기" or "켜고 다시 불러오기")
            b:SetScript("OnClick", function() if not en then SetEnabled(m.key, true) end; ReloadUI() end)
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", pane.note, "BOTTOMLEFT", 0, -12)
            b:Show()
        end
        return
    end
    if m.needs and not Loaded(m.needs) then
        pane.note:SetText(m.needsText or (m.needs .. " 애드온이 필요해요."))
        return
    end

    -- 두 칸 배치
    local pw = pane.sf:GetWidth()
    if not pw or pw < 100 then pw = hub.compact and (CMP_W - 3) or (K.W - K.RAIL - 3) end
    local CW = pw - K.PADX * 2 - 6
    if m.explain and not m._sv and not hub.compact then CW = CW - XP.EXPW - 14 end
    local HW = CW   -- 한 줄에 하나 (이름 왼쪽 · 조절 오른쪽 끝)
    if m.explain and not m._sv then HW = math.floor((CW - K.CGAP) / 2) end   -- 설명 칸이 있는 곳: 두 칸씩 (덜 넓게)
    local IW_H, IW_F = HW - K.CP * 2, CW - K.CP * 2

    local y = -14
    local ncard = 0
    local col, rowTop, rowH, rowCards = 0, 0, 0, {}
    local function Flush()
        if col == 1 then
            for _, c in ipairs(rowCards) do c:SetHeight(rowH) end
            y = rowTop - rowH - K.GAP
        end
        col, rowH = 0, 0
        wipe(rowCards)
    end
    local placeIndent, placeDim, placeTip = 0, false, nil
    local function Place(r, h, full, idx)
        if not (m.explain and not m._sv) then full = true end
        ncard = ncard + 1
        local c = Card(pane, ncard)
        c:ClearAllPoints()
        local x, w
        if full then
            Flush(); rowTop = y; x, w = K.PADX + placeIndent, CW - placeIndent
        else
            if col == 0 then rowTop = y; x = K.PADX; col = 1 else x = K.PADX + HW + K.CGAP; col = 2 end
            w = HW
        end
        local ch = h + K.CPV * 2
        c:SetPoint("TOPLEFT", x, rowTop); c:SetWidth(w); c:SetHeight(ch)
        c:SetFrameLevel(pane:GetFrameLevel())
        c.edge:SetColor({ 1, 1, 1 }, 0.06)
        c:Show()
        r.card = c
        -- 딸린 설정: 위 스위치가 꺼져 있으면 흐리게
        c:SetAlpha(placeDim and 0.45 or 1); r:SetAlpha(placeDim and 0.45 or 1)
        -- 긴 설명 · 다시 불러오기는 마우스를 올리면
        r.tipText = placeTip
        if not r.leelTipHooked then
            r.leelTipHooked = true
            r:HookScript("OnEnter", function(self)
                if self.tipText then GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT"); GameTooltip:SetText(ns.L(self.tipText), 1, 0.92, 0.94, 1, true); GameTooltip:Show() end
            end)
            r:HookScript("OnLeave", function(self) if self.tipText then GameTooltip:Hide() end end)
        end
        if placeTip and not r:IsMouseEnabled() then r:EnableMouse(true) end
        -- 설명 칸: 줄에 마우스를 올리면 그 설정 설명 + 분홍 테
        r.sideIt = (idx and hub.pv and hub.pv:IsShown()) and m.items[idx] or nil
        if r.sideIt and not r:IsMouseEnabled() then r:EnableMouse(true) end
        if not r.leelExHooked then
            r.leelExHooked = true
            r:HookScript("OnEnter", function(self)
                local ex = hub.explain
                local it = self.sideIt
                if it and ex and ex:IsShown() then
                    ex:Say(it)
                    if self.card then self.card.edge:SetColor(C.acc, 0.75) end
                elseif it and hub.pv and hub.pv:IsShown() then
                    XP.Enter()
                    -- 미리 보기에서 바뀌는 곳에 테 (아래 설명 칸이 있으면 설명도)
                    if hub.pv.cap and hub.pv.cap:IsShown() then
                        local t = LabelOf(it.label); t = type(t) == "string" and t or ""
                        hub.pv.capT:SetText(t)
                        hub.pv.cap:SetText(it.more or LabelOf(it.hint) or "")
                    end
                    -- 각성 줄 = 미리 보기도 전투 중으로 · 졸린 토끼 = 비전투 · 나머지는 고른 대로
                    local want = it.pvFight
                    if want == nil then want = ns.hudPvFightManual and true or false end
                    local wd = it.pvDead and true or false   -- 죽은 대상 줄 = 미리 보기도 쓰러진 모습
                    local pk = it.pvPeek                     -- 꺼져 있어도 그 줄은 모습을 잠깐 보여줘요
                    if (ns.hudPvFight and true or false) ~= want or (ns.hudPvDead and true or false) ~= wd or ns.hudPvPeek ~= pk then
                        ns.hudPvFight, ns.hudPvDead, ns.hudPvPeek = want, wd, pk; hub.pv:Update()
                    end
                    XP.Set(it)
                    if self.card then self.card.edge:SetColor(C.acc, 0.75) end
                end
            end)
            r:HookScript("OnLeave", function(self)
                if self.sideIt and self.card then self.card.edge:SetColor({ 1, 1, 1 }, 0.06) end
                if self.sideIt and hub.pv and hub.pv:IsShown() then XP.Leave(self) end
            end)
        end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", c, "TOPLEFT", K.CP, -K.CPV)
        r:SetPoint("TOPRIGHT", c, "TOPRIGHT", -K.CP, -K.CPV)
        if r.line then r.line:Hide() end
        if full then
            y = rowTop - ch - K.GAP
        else
            rowCards[#rowCards + 1] = c
            rowH = math.max(rowH, ch)
            if col == 2 then
                for _, cc in ipairs(rowCards) do cc:SetHeight(rowH) end
                y = rowTop - rowH - K.GAP
                col, rowH = 0, 0
                wipe(rowCards)
            end
        end
        if idx then pane.itemCard[idx] = c end
    end

    local hideItem = {}
    local ti, bi, ci, si, hi, gi = 0, 0, 0, 0, 0, 0
    local lastBtn

    local function Header(it)
        Flush()
        lastBtn = nil
        hi = hi + 1
        local h = HeaderRow(pane, hi)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", K.PADX + 2, y - 6); h:SetPoint("TOPRIGHT", -K.PADX - 6, y - 6)
        h.label:SetText(LabelOf(it.label))
        local ff, _, fl = h.label:GetFont()
        h.label:ClearAllPoints()
        if it.num then
            h.no:Show(); h.nofs:SetText(it.num); h.nofs:Show()
            h.label:SetFont(ff, 13.5, fl); h.label:SetPoint("LEFT", h.no, "RIGHT", 8, 0)
            h.label:SetTextColor(C.accHi[1], C.accHi[2], C.accHi[3])
        else
            h.no:Hide(); h.nofs:Hide()
            h.label:SetFont(ff, 11.5, fl); h.label:SetPoint("LEFT", 0, 0)
            h.label:SetTextColor(C.acc[1], C.acc[2], C.acc[3])
        end
        if it.btn and not (it.btn.dep and not it.btn.dep()) then
            h.btn.fs:SetText(it.btn.label)
            h.btn:SetWidth(h.btn.fs:GetStringWidth() + 4)
            h.btn:SetScript("OnClick", function() Apply(it.btn.run); C_Timer.After(0.05, ShowPane) end)
            h.btn:Show()
            h.line:SetPoint("RIGHT", h.btn, "LEFT", -8, 0)
        else
            h.btn:Hide()
            h.line:SetPoint("RIGHT", h, "RIGHT", 0, 0)
        end
        h:Show()
        y = y - 32
    end

    local function Item(idx, it)
        if type(it.label) == "string" and hideItem[it.label] then return end
        if it.t == "sub" then Header(it) return end   -- 묶음 안 작은 제목 (HUD 순서대로)
        if it.t == "slider" then
            lastBtn = nil
            si = si + 1
            local r = SliderRow(pane, si)
            r.name:SetText(it.label)
            r.fmt = it.fmt
            local s = r.s
            s:SetScript("OnValueChanged", nil)
            s:SetMinMaxValues(it.min, it.max)
            -- B안: 이름 · 줄 · 숫자를 한 줄에 (촘촘하게)
            local tight = m._sv and true or false
            if r.tight ~= tight then
                r.tight = tight
                r.name:ClearAllPoints(); r.val:ClearAllPoints(); s:ClearAllPoints()
                if tight then
                    r.name:SetPoint("LEFT", 0, 0); r.val:SetPoint("RIGHT", 0, 0)
                    s:SetPoint("LEFT", r, "LEFT", 120, 0); s:SetPoint("RIGHT", r, "RIGHT", -48, 0)
                else
                    r.name:SetPoint("TOPLEFT", 0, -4); r.val:SetPoint("TOPRIGHT", 0, -1)
                    s:SetPoint("TOPLEFT", 0, -26); s:SetPoint("TOPRIGHT", 0, -26)
                end
            end
            r:SetHeight(tight and 24 or 50)
            Place(r, tight and 24 or 50, false, idx)
            local v = it.get()
            -- 허브를 열 때 값 기억 (이 줄을 처음 볼 때)
            if XP.snap[it] == nil and type(v) == "number" then XP.snap[it] = v end
            r.snapV = XP.snap[it]
            s:SetValue(v); r:Paint(v)
            s:SetScript("OnMouseDown", function(_, btn)
                if btn == "RightButton" and r.snapV then   -- 오른쪽 클릭 = 허브 열 때 값으로
                    local sv = r.snapV
                    s:SetValue(sv); r:Paint(sv)
                    Apply(function() it.set(sv) end)
                    if hub.pv then hub.pv:Update() end
                    if XP.Cur() == it then XP.Refresh() end
                    return
                end
                r.bub:Show(); r.bub.fs:SetFormattedText(it.fmt or "%d%%", math.floor(s:GetValue() + 0.5)); r.val:SetAlpha(0.3)
                if it.noPeek then   -- 미리 보기로 보는 줄은 허브를 안 비켜요 · 대신 미리 보기에 강조
                    if hub.pv and hub.pv:IsShown() then XP.Set(it) end
                    return
                end
                PeekOn(r, it.label); PeekText(it.label, math.floor(s:GetValue() + 0.5), it.fmt)
                peekWatch.drag = true; peekWatch:Show()
            end)
            s:SetScript("OnMouseUp", function() r.bub:Hide(); r.val:SetAlpha(1); PeekOff() end)
            r.bub:Hide(); r.val:SetAlpha(1)
            s:SetScript("OnValueChanged", function(_, nv, user)
                nv = math.floor(nv + 0.5)
                -- 허브 열 때 값 가까이 오면 착 붙기
                local sv = r.snapV
                if user and sv and nv ~= sv and math.abs(nv - sv) <= math.max(1, (it.max - it.min) * 0.03) then
                    nv = sv; s:SetValue(sv)
                end
                if peekRow == r then PeekText(it.label, nv, it.fmt) end
                r:Paint(nv)
                if user then Apply(function() it.set(nv) end); if hub.pv then hub.pv:Update() end; if XP.Cur() == it then XP.Refresh() end end
            end)
            s:SetScript("OnMouseWheel", function(self, d)
                -- 그냥 휠 = 화면 내리기 (값은 그대로) · Shift + 휠 = 값 바꾸기
                if not IsShiftKeyDown() then
                    local wf = pane.sf:GetScript("OnMouseWheel")
                    if wf then wf(pane.sf, d) end
                    return
                end
                if not it.noPeek then PeekOn(r, it.label) end
                r.peekT = (r.peekT or 0) + 1
                local tk = r.peekT
                C_Timer.After(1.2, function() if r.peekT == tk and peekRow == r then PeekOff() end end)
                local nv = math.min(it.max, math.max(it.min, math.floor(self:GetValue() + 0.5) + d * (it.step or 5)))
                self:SetValue(nv)
                r:Paint(nv)
                Apply(function() it.set(nv) end)
                PeekText(it.label, nv, it.fmt)
                if hub.pv then hub.pv:Update() end
                if it.noPeek and hub.pv and hub.pv:IsShown() then XP.Set(it) end
            end)
            C_Timer.After(0, function() if r:IsShown() then r:Paint(math.floor(s:GetValue() + 0.5)) end end)
            r:Show()
        elseif it.t == "seg" and it.cards then
            -- ② 무엇을: 모습으로 고르는 카드
            lastBtn = nil
            local r = pane.cardRow
            if not r then r = CreateFrame("Frame", nil, pane); r.c = {}; r:EnableMouse(true); pane.cardRow = r end
            local cur = it.get()
            for k, o in ipairs(it.options) do
                local b = r.c[k]
                if not b then
                    b = CreateFrame("Button", nil, r)
                    b:SetSize(158, 82)
                    b.fill, b.edge = ns.RoundPlate(b, 12, { 0.165, 0.125, 0.115, 0.95 }, { 1, 1, 1, 0.08 })
                    b.num = b:CreateFontString(nil, "OVERLAY"); b.num:SetPoint("TOP", -4, -10)
                    b.unit = b:CreateFontString(nil, "OVERLAY"); b.unit:SetPoint("BOTTOMLEFT", b.num, "BOTTOMRIGHT", 1, 3)
                    b.lab = ns.Font(b, 12.5); b.lab:SetPoint("TOP", 0, -44)
                    b.sub = ns.Font(b, 10, C.tx2); b.sub:SetPoint("TOP", b.lab, "BOTTOM", 0, -3)
                    b:SetScript("OnEnter", function() local f = r:GetScript("OnEnter"); if f then f(r) end end)
                    b:SetScript("OnLeave", function() local f = r:GetScript("OnLeave"); if f then f(r) end end)
                    r.c[k] = b
                end
                local cd = it.cards[k] or {}
                local col = cd[4] or { 1, 1, 1 }
                b.num:SetFont(ns.NUM or ns.FONT, 26, "OUTLINE"); b.num:SetText(cd[1] or "")
                b.unit:SetFont(ns.NUM or ns.FONT, 12, "OUTLINE"); b.unit:SetText(cd[2] or "")
                b.num:SetTextColor(col[1], col[2], col[3]); b.unit:SetTextColor(col[1], col[2], col[3])
                b.lab:SetText(o[1]); b.sub:SetText(cd[3] or "")
                local on = cur == o[2]
                b.edge:SetColor(on and C.acc or { 1, 1, 1 }, on and 1 or 0.08)
                b.fill:SetColor(on and { 0.2, 0.145, 0.16 } or { 0.165, 0.125, 0.115 }, 0.95)
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", r, "TOPLEFT", (k - 1) * 168, 0)
                b:SetScript("OnClick", function() Apply(function() it.set(o[2]) end); ShowPane() end)
                b:Show()
            end
            for k = #it.options + 1, #r.c do r.c[k]:Hide() end
            r:SetHeight(82)
            Place(r, 82, true, idx)
            r:Show()
        elseif it.t == "seg" then
            lastBtn = nil
            gi = gi + 1
            local r = SegRow(pane, gi)
            r.name:SetText(it.label)
            r.hint:SetText(it.hint or "")
            local cur = it.get()
            local prev
            local total = 0
            for k = #it.options, 1, -1 do
                local o = it.options[k]
                local b = r:Btn(k)
                b.fs:SetText(o[1])
                b:SetWidth(math.max(46, b.fs:GetStringWidth() + 22))
                total = total + b:GetWidth() + 4
                b:ClearAllPoints()
                if prev then b:SetPoint("RIGHT", prev, "LEFT", -4, 0) else b:SetPoint("RIGHT", 0, 0) end
                prev = b
                local on = (cur == o[2])
                b.bg:SetColor(on and C.acc or { 0.23, 0.18, 0.17 }, 1)
                b.fs:SetTextColor(on and C.ink[1] or C.tx[1], on and C.ink[2] or C.tx[2], on and C.ink[3] or C.tx[3])
                b.fs:SetShadowColor(0, 0, 0, on and 0 or 0.85)
                b:SetScript("OnClick", function() Apply(function() it.set(o[2]) end); ShowPane() end)
                b:Show()
            end
            for k = #it.options + 1, #r.btns do r.btns[k]:Hide() end
            local full = r.name:GetStringWidth() + 18 + total > IW_H
            local iw = full and IW_F or IW_H
            local hasHint = (it.hint or "") ~= ""
            r.name:ClearAllPoints()
            r.hint:ClearAllPoints()
            r.hint:SetWordWrap(false); r.hint:SetJustifyH("LEFT")
            if hasHint then
                r.name:SetPoint("TOPLEFT", 0, -3)
                r.hint:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
                r.hint:SetWidth(math.max(40, iw - total - 12))
                r:SetHeight(40)
            else
                r.name:SetPoint("LEFT", 0, 0)
                r:SetHeight(32)
            end
            r.hint:SetShown(hasHint)
            Place(r, r:GetHeight(), full, idx)
            r:Show()
        elseif it.t == "choice" or it.t == "bind" then
            lastBtn = nil
            ci = ci + 1
            local r = ChoiceRow(pane, ci)
            r.name:SetText(it.label)
            local hintText = LabelOf(it.hint)
            r.hint:SetText(hintText)
            r.pill:EnableKeyboard(false); r.pill:SetScript("OnKeyDown", nil); r.pill:SetScript("OnMouseDown", nil); r.pill.capturing = nil
            if it.t == "choice" then
                r.pill.ar:Show()
                r.pill:RegisterForClicks("LeftButtonUp")
                r.pill.bg:SetColor({ 0.23, 0.18, 0.17 }, 1)
                local label, file, icon
                if it.options then
                    local cur = it.get()
                    label = "—"
                    for _, o in ipairs(it.options()) do if o.key == cur then label = o.label; icon = o.icon end end
                else
                    local cur = ns.db.font and ns.db.font[it.slot]
                    label, file = LabelFor(it.slot, cur)
                end
                if not (file and r.pill.fs:SetFont(file, 14, "")) then r.pill.fs:SetFont(ns.FONT, 13, "") end
                r.pill.fs:SetText(label)
                r.pill.fs:SetTextColor(C.tx[1], C.tx[2], C.tx[3])
                r.pill.fs:ClearAllPoints(); r.pill.fs:SetPoint("LEFT", icon and 27 or 12, 0)
                r.pill.ic:SetShown(icon and true or false); if icon then r.pill.ic:SetTexture(icon) end
                r.pill:SetWidth(math.max(70, r.pill.fs:GetStringWidth() + 40 + (icon and 15 or 0)))
                local W_ = { now = { "바로", C.acc, C.ink }, reload = { "다시 불러오기", { 0.32, 0.25, 0.24 }, C.tx },
                             relog = { "재접속", { 0.32, 0.25, 0.24 }, C.tx } }
                local w = it.when and W_[it.when]
                if w then
                    r.when.fs:SetText(w[1])
                    r.when.fs:SetTextColor(w[3][1], w[3][2], w[3][3]); r.when.fs:SetShadowColor(0, 0, 0, it.when == "now" and 0 or 0.85)
                    r.when.bg:SetColor(w[2], 1)
                    r.when:SetWidth(r.when.fs:GetStringWidth() + 14)
                    r.when:Show()
                else
                    r.when:Hide()
                end
                r.pill:SetScript("OnClick", function(self)
                    if dd and dd:IsShown() and dd.anchor == self then dd:Hide() return end
                    if it.options then
                        OpenDropdown(self, it, function(key) Apply(function() it.set(key) end); ShowPane() end)
                        return
                    end
                    OpenDropdown(self, it.slot, function(key)
                        ns:SetFontSlot(it.slot, key)
                        if it.slot == "num" then
                            Print("피해 숫자 글꼴은 재접속(캐릭터 선택 화면에 갔다 오기) 후 바뀌어요.")
                        end
                        ShowPane()
                    end)
                end)
            else
                -- 단축키 직접 입력: 알약을 누르고 원하는 키(Shift · Ctrl · Alt 조합 가능)를 누르면 저장
                r.when:Hide(); r.pill.ic:Hide(); r.pill.ar:Hide()
                r.pill.fs:SetFont(ns.FONT, 13, "")
                r.pill.fs:ClearAllPoints(); r.pill.fs:SetPoint("CENTER", 0, 0)
                local function Show_(txt, hot)
                    r.pill.fs:SetText(txt)
                    local c = hot and C.ink or C.tx
                    r.pill.fs:SetTextColor(c[1], c[2], c[3])
                    r.pill.bg:SetColor(hot and C.acc or { 0.23, 0.18, 0.17 }, 1)
                    r.pill:SetWidth(math.max(90, r.pill.fs:GetStringWidth() + 28))
                end
                local function Stop()
                    r.pill:EnableKeyboard(false); r.pill:SetScript("OnKeyDown", nil); r.pill.capturing = nil
                end
                local cur = it.get()
                Show_((cur ~= "" and cur) or "없음", false)
                Stop()
                r.pill:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                local function Save(k) Stop(); it.set(k); C_Timer.After(0, ShowPane) end
                r.pill:SetScript("OnClick", function(self, btn)
                    if InCombatLockdown() then Print("전투가 끝나면 바꿀 수 있어요."); return end
                    if btn == "RightButton" then Save("") return end
                    if self.capturing then return end
                    self.capturing = true
                    Show_("키를 누르세요 · Esc 취소", true)
                    self:EnableKeyboard(true)
                    if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
                    self:SetScript("OnKeyDown", function(_, key)
                        if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then return end
                        if key == "ESCAPE" then Stop(); C_Timer.After(0, ShowPane) return end
                        local pre = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
                        Save(pre .. key)
                    end)
                end)
                r.pill:SetScript("OnMouseDown", function(self, btn)
                    if self.capturing and (btn == "MiddleButton" or btn == "Button4" or btn == "Button5") then
                        local mm = (btn == "MiddleButton" and "BUTTON3") or (btn == "Button4" and "BUTTON4") or "BUTTON5"
                        local pre = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
                        Save(pre .. mm)
                    end
                end)
            end
            -- 이름 · 설명 자리 (알약 왼쪽까지만)
            local right = r.pill:GetWidth() + (r.when:IsShown() and (r.when:GetWidth() + 8) or 0) + 12
            local full = r.name:GetStringWidth() + right + 10 > IW_H
            local iw = full and IW_F or IW_H
            r.name:ClearAllPoints(); r.hint:ClearAllPoints()
            r.hint:SetWordWrap(false); r.hint:SetJustifyH("LEFT")
            if hintText ~= "" then
                r.name:SetPoint("TOPLEFT", 0, -3)
                r.hint:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
                r.hint:SetWidth(math.max(40, iw - right))
                r:SetHeight(40)
            else
                r.name:SetPoint("LEFT", 0, 0)
                r:SetHeight(32)
            end
            r.hint:SetShown(hintText ~= "")
            Place(r, r:GetHeight(), full, idx)
            r:Show()
        elseif it.t == "input" then
            lastBtn = nil
            local r = InputRow(pane)
            r.name:SetText(it.label); r.hint:SetText(it.hint or "")
            r.btn:SetLabel(it.button or "추가"); r.btn:SetHeight(24)
            local function Go()
                local text = r.box:GetText()
                if it.run(text) then r.box:SetText("") end
                r.box:ClearFocus()
                C_Timer.After(0, ShowPane)
            end
            r.btn:SetScript("OnClick", Go)
            r.box:SetScript("OnEnterPressed", Go)
            Place(r, 54, true, idx)
            r:Show()
        elseif it.t == "fstate" then
            -- [비전투 | 전투 중] 알약 (가운데 탭 · 크기 줄 바로 아래)
            lastBtn = nil
            local r = pane.fstateRow
            if not r then
                r = CreateFrame("Frame", nil, pane)
                r.bg = ns.RoundRect(r, 18, { 0.08, 0.06, 0.055 }, "BACKGROUND", 0, 0)
                r.b = {}
                for i, lab in ipairs({ "비전투", "전투 중", "사용 안 함" }) do
                    local b = CreateFrame("Button", nil, r)
                    b.bg = ns.RoundRect(b, 15, C.acc, "ARTWORK", 0, 0)
                    b.fs = ns.Font(b, 13.5, C.tx); b.fs:SetPoint("CENTER"); b.fs:SetText(lab)
                    b:SetScript("OnClick", function()
                        if i == 3 then
                            if ns.SetCtr then ns.SetCtr("numOff", true) end   -- 가운데를 아예 안 써요 (숫자 · 효과 모두)
                        else
                            if ns.SetCtr and ns.db.ctr and ns.db.ctr.numOff then ns.SetCtr("numOff", false) end
                            ns.hudPvFight = (i == 2); ns.hudPvFightManual = (i == 2)
                        end
                        pane.sf:SetVerticalScroll(0)
                        ShowPane()
                    end)
                    r.b[i] = b
                end
                pane.fstateRow = r
            end
            r:SetHeight(36)
            local off = ns.db.ctr and ns.db.ctr.numOff
            local cur = off and 3 or (ns.hudPvFightManual and 2 or 1)
            local bw = math.floor((CW - 2 * K.CP - 6 - 8) / 3)
            for i, b in ipairs(r.b) do
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 3 + (i - 1) * (bw + 4), -3); b:SetSize(bw, 30)
                local on = (i == cur)
                b.bg:SetColor(C.acc, on and 1 or 0)
                local c = on and C.ink or C.tx2
                b.fs:SetTextColor(c[1], c[2], c[3]); b.fs:SetShadowColor(0, 0, 0, on and 0 or 0.85)
            end
            Place(r, 36, true, idx)
            if r.card then r.card:SetAlpha(0) end   -- 판 없이 알약만
            r:Show()
        elseif it.t == "size" then
            -- 크기: 이름 · 지금 % · [이동 모드에서 조절] (늘 탭 첫 줄)
            lastBtn = nil
            local r = pane.sizeRow
            if not r then
                r = CreateFrame("Frame", nil, pane)
                r.name = ns.Font(r, 14); r.name:SetPoint("TOPLEFT", 2, -4)
                r.hint = ns.Font(r, 11, C.tx2); r.hint:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
                r.b = ns.MakeButton(r, "이동 모드에서 조절", true, nil, 150)
                r.b:SetHeight(30); r.b:SetPoint("RIGHT", 0, 0)
                r:EnableMouse(true)
                pane.sizeRow = r
            end
            r:SetHeight(40)
            r.name:SetText(LabelOf(it.label))
            local okv, cur = pcall(it.get)
            r.hint:SetText("지금 " .. (okv and cur or "?") .. "%  ·  이동 모드에서 테두리를 누르면 크기 줄 · 휠로도")
            r.b:SetScript("OnClick", function() ns.HubMoveOpen(it.mover, it.sl, it.title) end)
            Place(r, 40, true, idx)
            r:Show()
        elseif it.t == "toggle" then
            lastBtn = nil
            ti = ti + 1
            local r = ToggleRow(pane, ti)
            r.name:SetText(it.label)
            local hintText = LabelOf(it.hint)
            local ind = it.child and 20 or 0
            r.name:ClearAllPoints(); r.name:SetPoint("TOPLEFT", ind, -6)
            r.name:SetWidth(IW_H - 60 - ind); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
            r.tv:SetShown(it.child and true or false); r.th:SetShown(it.child and true or false)
            r.hint:SetText(hintText); r.hint:SetShown(hintText ~= "")
            r.hint:ClearAllPoints(); r.hint:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
            r.hint:SetWidth(IW_H - 60 - ind); r.hint:SetJustifyH("LEFT"); r.hint:SetWordWrap(true)
            local h = 30
            if hintText ~= "" then h = 28 + math.ceil(r.hint:GetStringHeight()) end
            r:SetHeight(h)
            r.sw:Set(it.get() and true or false)
            local on = not (it.dep and not it.dep())
            r:SetEnabled(on); r:SetAlpha(on and 1 or 0.4)
            r:SetScript("OnClick", function(self)
                local new = not (it.get() and true or false)
                Apply(function() if it.set then it.set(new) elseif it.cmd then Slash(m.slash, it.cmd) end end)
                C_Timer.After(0, function() self.sw:Set(it.get() and true or false); ShowPane() end)
            end)
            Place(r, h, false, idx)
            r:Show()
        else
            Flush()
            bi = bi + 1
            local b = PaneButton(pane, bi)
            b:SetLabel(LabelOf(it.label))
            local bon = not (it.dep and not it.dep())
            b:SetEnabled(bon); b:SetAlpha(bon and 1 or 0.4)
            b:SetScript("OnClick", function()
                Apply(function() if it.run then it.run() elseif it.cmd then Slash(m.slash, it.cmd) end end)
                C_Timer.After(0.05, function() if hub:IsShown() then ShowPane() end end)
            end)
            b:ClearAllPoints()
            local bw = b:GetWidth() or 80
            if lastBtn and (pane.rowX or 0) + 8 + bw <= K.PADX + CW then
                b:SetPoint("LEFT", lastBtn, "RIGHT", 8, 0)
                pane.rowX = pane.rowX + 8 + bw
            else
                b:SetPoint("TOPLEFT", K.PADX, y - (lastBtn and 0 or 4))
                y = y - (lastBtn and 36 or 40)
                pane.rowX = K.PADX + bw
            end
            lastBtn = b
            if idx then pane.itemCard[idx] = nil end
            b:Show()
        end
    end

    -- 정리 규칙: 딸린 설정 들여쓰기 · 긴 설명은 (?) · 다시 불러오기는 ↻ · 잘 안 쓰는 건 "고급"
    local RawItem = Item
    local parentItem
    local function ParentOn(it)
        if it.depOn then local ok, v = pcall(it.depOn); return not ok or v and true or false end
        local p = parentItem
        if not p then return true end
        local ok, v = pcall(p.get)
        if not ok then return true end
        if p.t == "toggle" then return v and true or false end
        if p.t == "seg" then return v ~= p.options[1][2] end
        return true
    end
    Item = function(idx, it)
        if not it.child then parentItem = (it.t == "toggle" or it.t == "seg") and it or nil end
        local view = setmetatable({}, { __index = it })
        local h = LabelOf(it.hint)
        local suffix, tip = "", nil
        if type(h) == "string" and h ~= "" then
            if h:find("다시 불러오기", 1, true) or h:find("재접속", 1, true) then
                suffix = "  |TInterface\\Buttons\\UI-RefreshButton:12:12:0:0|t"; tip = h; view.hint = ""
            elseif false and select(2, h:gsub("[^\128-\191]", "")) > 18 then
                suffix = "  |cff9a8a86(?)|r"; tip = h; view.hint = ""
            end
        end
        if suffix ~= "" and type(it.label) == "string" and it.t ~= "button" then view.label = it.label .. suffix end
        if it.child then
            view.child = false   -- 들여쓰기는 칸 자체를 옮겨서 (안쪽 선은 안 그려요)
            if it.t ~= "slider" and type(view.label) == "string" then view.label = "|cffff8fab└|r  " .. view.label end
        end
        local on = (not it.child) or ParentOn(it)
        if it.dimIf then
            local okd, d = pcall(it.dimIf)
            if okd and d then on = false; view.hint = it.dimWhy or view.hint; view.dep = function() return false end end
        end
        if it.child and (it.t == "toggle" or it.t == "button") then view.dep = function() return on end end
        placeIndent, placeDim, placeTip = it.child and 28 or 0, not on, tip
        RawItem(idx, view)
        placeIndent, placeDim, placeTip = 0, false, nil
    end
    local function IsAdv(it)
        if m.explain then return false end   -- 설명 칸이 있는 곳은 다 펼쳐 보여요
        if it.adv then return true end
        local l = type(it.label) == "string" and it.label or ""
        local hh = LabelOf(it.hint)
        if it.t == "button" and (l:find("초기화", 1, true) or l:find("처음", 1, true) or l:find("점검", 1, true) or l:find("기본값", 1, true)) then return true end
        if it.t == "toggle" and l:find("숨기기", 1, true) and type(hh) == "string" and hh:find("다시 불러오기", 1, true) then return true end
    end
    local function AdvBlock(list)
        if #list == 0 then return end
        local open = advOpen[m.key]
        Header({ label = "고급 · 잘 안 쓰는 것 (" .. #list .. ")",
                 btn = { label = open and "접기" or "펼치기", run = function() advOpen[m.key] = not advOpen[m.key] end } })
        if open then for _, p in ipairs(list) do Item(p[1], p[2]) end end
    end

    -- 크기 · 위치는 게임 화면에서 (B안)
    local E = EDIT and EDIT[m.key]
    if E and m.key == "LeelUI_Bags" then E = nil end   -- 가방은 허브 슬라이더로 (이동 모드에 없어요)
    hideItem = E and E.hide or {}
    if pane.editRow then pane.editRow:Hide() end

    -- 공통 규칙: [머리 띠] → ① 쓰기 ② 무엇을 ③ 모양 ④ 언제 ⑤ 더
    local BD = XP.BAND[m.key] or {}
    local SC = XP.SEC[m.key] or {}
    local page = {}
    if tabbed then for _, i in ipairs(groups[tab].items) do page[#page + 1] = { i, m.items[i] } end
    else for i, it in ipairs(m.items or {}) do page[#page + 1] = { i, it } end end
    local skip, resets, sizeIt, szIdx = {}, {}, nil, nil
    for _, p in ipairs(page) do
        local it = p[2]
        for _, L in ipairs(BD.reset or {}) do
            if it.label == L or (it.btn and it.btn.label == L) then resets[#resets + 1] = it; skip[it] = true end
        end
        if BD.sz and it.label == BD.sz then szIdx = p[1]; skip[it] = true end
        if it.t == "size" then sizeIt = it end
    end
    local MS = BD.ms and MOVE_SIZE[m.key]
    local msItem
    if MS then for _, it in ipairs(m.items or {}) do if it.label == MS[1] then msItem = it end end end
    local useOn = XP.UseOn(m)
    if (sizeIt or msItem or BD.move or BD.note) and useOn ~= false then
        local r = pane.band
        if not r then
            r = CreateFrame("Frame", nil, pane)
            r.t = ns.Font(r, 14.5); r.t:SetPoint("TOPLEFT", 4, -6)
            r.s = ns.Font(r, 11, C.tx2); r.s:SetPoint("TOPLEFT", r.t, "BOTTOMLEFT", 0, -5)
            r.r = ns.MakeButton(r, "초기화", false, nil, 64); r.r:SetHeight(30); r.r:SetPoint("RIGHT", -2, 0)
            r.b = ns.MakeButton(r, "이동 모드", true, nil, 96); r.b:SetHeight(30)
            pane.band = r
        end
        r:SetHeight(44)
        local cur
        if sizeIt then local ok, v = pcall(sizeIt.get); cur = ok and v or nil
        elseif msItem then local ok, v = pcall(msItem.get); cur = ok and v or nil
        elseif szIdx then local ok, v = pcall(m.items[szIdx].get); cur = ok and v or nil end
        r.t:SetText((sizeIt and sizeIt.title) or BD.title or (MS and MS[3]) or m.title)
        local canMove = sizeIt or msItem or BD.move
        r.s:SetText((cur and ("크기 " .. cur .. "%  ·  ") or "")
            .. (canMove and (cur and "이동 모드에서 테두리를 누르면 크기 줄" or "이동 모드에서 끌어서 옮겨요") or (BD.note or "")))
        r.b:SetShown(canMove and true or false)
        r.b:SetScript("OnClick", function()
            if sizeIt then ns.HubMoveOpen(sizeIt.mover, sizeIt.sl, sizeIt.title) return end
            if InCombatLockdown() then Print("전투가 끝나면 할 수 있어요.") return end
            hub:Hide()
            if not ns.moving then ns:SetMoveMode(true) end
            if MS then
                C_Timer.After(0.15, function()
                    local mv = ns.MoveSelect and MS[2]()
                    if mv and mv:IsShown() then ns.MoveSelect(mv, MS[1], MS[3]) end
                end)
            end
        end)
        r.r:SetShown(#resets > 0)
        r.r:SetScript("OnClick", function()
            Apply(function()
                for _, it in ipairs(resets) do
                    local fn = it.run or (it.btn and it.btn.run)
                    local dep = it.dep or (it.btn and it.btn.dep)
                    if not (dep and not dep()) then
                        if fn then fn() elseif it.cmd then Slash(m.slash, it.cmd) end
                    end
                end
            end)
            C_Timer.After(0.05, function() if hub:IsShown() then ShowPane() end end)
        end)
        r.b:ClearAllPoints()
        if #resets > 0 then r.b:SetPoint("RIGHT", r.r, "LEFT", -6, 0) else r.b:SetPoint("RIGHT", -2, 0) end
        Place(r, 44, true)
        if r.card then r.card.edge:SetColor(C.acc, 0.55) end
        r:Show()
        if szIdx then Item(szIdx, m.items[szIdx]) end
    elseif pane.band then
        pane.band:Hide()
    end

    local secs = { {}, {}, {}, {}, {} }
    local ui = XP.UseItem(m)
    if ui then secs[1][1] = { nil, ui } end
    local pendSub
    for _, p in ipairs(page) do
        local i, it = p[1], p[2]
        local lab = type(it.label) == "string" and it.label or nil
        if it.t == "header" and it.sec then
            pendSub = { nil, setmetatable({ t = "sub" }, { __index = it }) }
        elseif it.t == "header" or it.t == "size" or it.t == "fstate" or it.moveOnly or skip[it] or (lab and hideItem[lab]) then
            -- 띠 · 이동 모드로 갔거나 숨기는 줄
        elseif it.t == "sub" then
            pendSub = { nil, it }
        else
            local sn = it.sec or (lab and SC[lab]) or SC._d or 5
            if sn ~= 0 then
                local t = secs[sn]
                if pendSub then t[#t + 1] = pendSub; pendSub = nil end
                t[#t + 1] = { i, it }
            end
        end
    end
    local cut = false
    for sn = 1, 5 do
        if #secs[sn] > 0 and not cut then
            Header({ label = XP.SECNAME[sn], num = sn })
            for _, q in ipairs(secs[sn]) do Item(q[1], q[2]) end
            if sn == 1 then
                -- 쓰기를 끄면 ②~⑤는 숨겨요
                for _, q in ipairs(secs[1]) do
                    if q[2].t == "toggle" then local ok, v = pcall(q[2].get); if ok and not v then cut = true end end
                end
            end
        end
    end
    Flush()
    pane:SetContentHeight(-y + 16)
end

-- 왼쪽 목록: 묶음 제목 + 기능 줄 (접기 가능)
PaintRail = function()
    local side = hub.side
    local shut = ns.db.hub.shut or {}
    ns.db.hub.shut = shut
    local y = -6
    for _, g in ipairs(hub.groups) do
        local gh = g.btn
        gh:ClearAllPoints(); gh:SetPoint("TOPLEFT", 6, y); gh:SetPoint("RIGHT", side.child, "RIGHT", -6, 0)
        gh.ar:SetRotation(shut[g.key] and (math.pi / 2) or 0)
        y = y - 26
        for _, i in ipairs(g.rows) do
            local row = hub.rail[i]
            if shut[g.key] then
                row:Hide()
            else
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", 6, y); row:SetPoint("RIGHT", side.child, "RIGHT", -6, 0)
                row:Show()
                y = y - 32
            end
            local m = MODULES[i]
            local on = i == sel
            row.fill:SetColor(on and C.acc or { 1, 1, 1 }, on and 0.22 or 0)
            row.bar:SetShown(on)
            local nc = on and { 1, 1, 1 } or C.tx
            row.name:SetText(m.title)
            row.name:SetTextColor(nc[1], nc[2], nc[3])
            local exists = MExists(m)
            local off = exists and (not m.always or m.onoff) and (
                (m.onoff and not m.onoff.get()) or (not m.onoff and not m.builtin and not Enabled(m.key)))
            row.ic:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
            local dim = (not exists or off) and not on and 0.55 or 1
            row.ic:SetAlpha(dim); row.name:SetAlpha(dim)
            row.tag:Hide(); row.dot:Hide(); row.badge:Hide()
            if m.news then
                local n = NewsCount()
                if n > 0 then row.badge.fs:SetText(n); row.badge:Show() end
            elseif not exists then
                row.tag:SetText("없음"); row.tag:Show()
            elseif not m.always and off then
                -- 꺼진 것만 작게 "꺼짐" (켜진 건 아무 표시 없음)
                row.tag:SetText("꺼짐"); row.tag:Show()
            end
        end
        y = y - 4
    end
    side.child:SetHeight(-y + 6)
    local max = math.max(0, side.child:GetHeight() - side:GetHeight())
    if side:GetVerticalScroll() > max then side:SetVerticalScroll(max) end
end

Refresh = function()
    if not hub or not hub:IsShown() then return end
    ns.db.hub.last = MODULES[sel] and MODULES[sel].key
    if LiveFor then LiveFor(MODULES[sel]) end
    PaintRail()
    ShowPane()
    hub.moveBtn:SetLabel(ns.moving and "이동 모드 끄기" or "이동 모드")
end

-- 찾기: 모든 기능의 설정 이름 · 설명에서
local function SearchAll(q)
    local out = {}
    q = q:lower()
    for i, m in ipairs(MODULES) do
        if m.cat ~= "none" then
            local mt = (m.title or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if mt:lower():find(q, 1, true) then out[#out + 1] = { i = i, label = mt, sub = "기능 열기" } end
            local groups, map = Groups(m)
            for idx, it in ipairs(m.items or {}) do
                if it.t ~= "header" and it.t ~= "sub" and not it.moveOnly then
                    local label = LabelOf(it.label)
                    local hint = LabelOf(it.hint)
                    if type(label) == "string" and (label:lower():find(q, 1, true) or (type(hint) == "string" and hint:lower():find(q, 1, true))) then
                        local g = groups[map[idx] or 1]
                        out[#out + 1] = { i = i, idx = idx, g = map[idx], label = label,
                            sub = mt .. ((#groups >= 2 and g) and (" · " .. g.label) or "") }
                    end
                end
            end
        end
        if #out >= 9 then break end
    end
    return out
end


----------------------------------------------------------------------
-- 르엘 소통방: 질문 · 제보 · 새 소식은 채채TV에서
----------------------------------------------------------------------
local CHANNEL  = "https://www.youtube.com/@채채TV_2"
local DOWNLOAD = "https://github.com/jubin120615-debug/LeelUI/releases/latest"
local PROBLEMS = { "오류 창이 떠요", "모양이 이상해요", "위치가 틀어져요", "기타" }

-- 르엘 애드온에서 난 마지막 오류 (ns.lastErr) 는 ErrReport.lua 가 기억해요

-- 읽기 전용 복사 칸: '복사'를 누르면 글자가 선택되고 Ctrl+C
local function CopyBox(parent, w)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(w, 28)
    ns.RoundRect(b, 9, { 0.08, 0.06, 0.06 }, "BACKGROUND", 0, 0)
    local e = CreateFrame("EditBox", nil, b)
    e:SetPoint("LEFT", 9, 0); e:SetPoint("RIGHT", -58, 0); e:SetHeight(20)
    e:SetAutoFocus(false)
    e:SetFontObject(ChatFontNormal)
    pcall(e.SetFont, e, ns.FONT, 11.5, "")
    e:SetTextColor(C.accHi[1], C.accHi[2], C.accHi[3])
    e:SetScript("OnTextChanged", function(self, user) if user and b.value then self:SetText(b.value); self:HighlightText() end end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    e:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0); b.tip:SetText("복사") end)
    local btn = CreateFrame("Button", nil, b)
    btn:SetSize(50, 20); btn:SetPoint("RIGHT", -4, 0)
    ns.RoundRect(btn, 10, C.acc, "ARTWORK", 0, 0)
    b.tip = ns.Font(btn, 10.5, C.ink); b.tip:SetShadowColor(0, 0, 0, 0); b.tip:SetPoint("CENTER"); b.tip:SetText("복사")
    btn:SetScript("OnClick", function() e:SetFocus(); e:HighlightText(); b.tip:SetText("Ctrl+C") end)
    function b:Set(t) self.value = t; e:SetText(t); e:SetCursorPosition(0) end
    b.edit = e
    return b
end

local talk
local function BuildTalk(f)
    local W2 = 360
    local t = CreateFrame("Frame", "LeelUI_Talk", f)
    t:SetSize(W2, 300)
    t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, FOOT + 6)
    t:SetFrameLevel(f:GetFrameLevel() + 20)
    t:EnableMouse(true)
    ns.RoundPlate(t, 16, { 0.125, 0.094, 0.086, 0.99 }, { 0.949, 0.702, 0.761, 0.9 })

    local bun = t:CreateTexture(nil, "ARTWORK")
    bun:SetTexture(ns.MEDIA .. "bag_bunny"); bun:SetSize(24, 24); bun:SetPoint("TOPLEFT", 12, -10)
    local title = ns.Font(t, 14, C.accHi); title:SetPoint("LEFT", bun, "RIGHT", 7, 0); title:SetText("르엘 소통방")
    local x = CreateFrame("Button", nil, t)
    x:SetSize(18, 18); x:SetPoint("TOPRIGHT", -10, -12)
    local xt = x:CreateTexture(nil, "ARTWORK"); xt:SetTexture(ns.MEDIA .. "hb_x"); xt:SetAllPoints()
    xt:SetVertexColor(C.tx[1], C.tx[2], C.tx[3], 0.7)
    x:SetScript("OnClick", function() t:Hide() end)

    -- 탭
    local pages, tabs = {}, {}
    local function Show(i)
        for k, pg in ipairs(pages) do pg:SetShown(k == i) end
        for k, tb in ipairs(tabs) do
            local on = k == i
            tb.bg:SetColor(on and C.acc or { 0.949, 0.702, 0.761 }, on and 1 or 0.12)
            tb.fs:SetTextColor(on and C.ink[1] or C.accHi[1], on and C.ink[2] or C.accHi[2], on and C.ink[3] or C.accHi[3])
            tb.fs:SetShadowColor(0, 0, 0, on and 0 or 0.8)
        end
        if pages[i].OnShow2 then pages[i].OnShow2() end
    end
    local tx = 12
    for i, label in ipairs({ "채채TV", "문제 알리기", "새 소식" }) do
        local b = CreateFrame("Button", nil, t)
        b:SetHeight(22)
        b.bg = ns.RoundRect(b, 11, C.acc, "BACKGROUND", 0, 0)
        b.fs = ns.Font(b, 11.5); b.fs:SetPoint("CENTER"); b.fs:SetText(label)
        b:SetWidth(b.fs:GetStringWidth() + 22)
        b:SetPoint("TOPLEFT", tx, -42)
        tx = tx + b:GetWidth() + 6
        b:SetScript("OnClick", function() Show(i) end)
        tabs[i] = b
        local pg = CreateFrame("Frame", nil, t)
        pg:SetPoint("TOPLEFT", 12, -74); pg:SetPoint("BOTTOMRIGHT", -12, 12)
        pages[i] = pg
    end

    -- 1. 채채TV
    do
        local pg = pages[1]
        local card = CreateFrame("Frame", nil, pg)
        card:SetPoint("TOPLEFT"); card:SetPoint("TOPRIGHT"); card:SetHeight(54)
        ns.RoundRect(card, 12, { 0.949, 0.702, 0.761 }, "BACKGROUND", 0, 0):SetColor({ 0.949, 0.702, 0.761 }, 0.12)
        local ic = card:CreateTexture(nil, "ARTWORK"); ic:SetTexture(ns.MEDIA .. "bag_bunny"); ic:SetSize(34, 34); ic:SetPoint("LEFT", 10, 0)
        local nm = ns.Font(card, 15, C.tx); nm:SetPoint("TOPLEFT", ic, "TOPRIGHT", 10, -2); nm:SetText("채채TV")
        local sub = ns.Font(card, 10.5, { 0.81, 0.64, 0.62 }); sub:SetPoint("TOPLEFT", nm, "BOTTOMLEFT", 0, -3)
        sub:SetText("르엘 UI 질문 · 제보 · 업데이트 소식은 여기서")
        local l1 = ns.Font(pg, 10.5, { 0.62, 0.54, 0.52 }); l1:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -10); l1:SetText("방송 (유튜브)")
        local b1 = CopyBox(pg, W2 - 24); b1:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -4); b1:Set(CHANNEL)
        local l2 = ns.Font(pg, 10.5, { 0.62, 0.54, 0.52 }); l2:SetPoint("TOPLEFT", b1, "BOTTOMLEFT", 0, -8); l2:SetText("최신 파일 받기 · GitHub (올리자마자 바로)")
        local b2 = CopyBox(pg, W2 - 24); b2:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 0, -4); b2:Set(DOWNLOAD)
        local note = ns.Font(pg, 10.5, { 0.62, 0.54, 0.52 }); note:SetPoint("TOPLEFT", b2, "BOTTOMLEFT", 0, -8)
        note:SetWidth(W2 - 24); note:SetJustifyH("LEFT")
        note:SetText("급한 수정은 GitHub에서 바로, 평소엔 CurseForge 앱 업데이트(검토 후).\n링크는 복사(Ctrl+C)해서 브라우저 주소창에 붙여 넣어요.")
    end

    -- 2. 문제 알리기
    do
        local pg = pages[2]
        local pick = 1
        local function Step(n, text, anchor, dy)
            local d = pg:CreateTexture(nil, "ARTWORK"); d:SetTexture(ns.MEDIA .. "circle"); d:SetSize(18, 18)
            d:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
            if anchor then d:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, dy) else d:SetPoint("TOPLEFT") end
            local num = pg:CreateFontString(nil, "OVERLAY"); num:SetFont(ns.NUM or ns.FONT, 12, ""); num:SetTextColor(C.ink[1], C.ink[2], C.ink[3])
            num:SetPoint("CENTER", d); num:SetText(n)
            local fs = ns.Font(pg, 12); fs:SetPoint("LEFT", d, "RIGHT", 7, 0); fs:SetText(text)
            return d
        end
        local s1 = Step(1, "어떤 문제였나요?")
        local chips, row = {}, CreateFrame("Frame", nil, pg)
        row:SetPoint("TOPLEFT", s1, "BOTTOMLEFT", 24, -6); row:SetSize(W2 - 48, 48)
        local box
        local function Line()
            local ver = Version("LeelUI")
            local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
            local t = "#르엘 " .. ver .. " · " .. PROBLEMS[pick]
            if ns.lastErr then t = t .. " · " .. ns.lastErr end
            if n > 0 then t = t .. " · 파티 " .. n .. "명" end
            return t
        end
        local function Paint()
            for i, c in ipairs(chips) do
                local on = i == pick
                c.bg:SetColor(on and { 1, 0.56, 0.64 } or { 1, 1, 1 }, on and 1 or 0.07)
                c.fs:SetTextColor(on and C.ink[1] or 0.81, on and C.ink[2] or 0.64, on and C.ink[3] or 0.62)
                c.fs:SetShadowColor(0, 0, 0, on and 0 or 0.8)
            end
            if box then box:Set(Line()) end
        end
        local cx, cy = 0, 0
        for i, label in ipairs(PROBLEMS) do
            local c = CreateFrame("Button", nil, row)
            c:SetHeight(20)
            c.bg = ns.RoundRect(c, 10, C.acc, "BACKGROUND", 0, 0)
            c.fs = ns.Font(c, 10.5); c.fs:SetPoint("CENTER"); c.fs:SetText(label)
            c:SetWidth(c.fs:GetStringWidth() + 18)
            if cx + c:GetWidth() > W2 - 48 then cx, cy = 0, cy - 24 end
            c:SetPoint("TOPLEFT", cx, cy)
            cx = cx + c:GetWidth() + 5
            c:SetScript("OnClick", function() pick = i; Paint() end)
            chips[i] = c
        end
        row:SetHeight(-cy + 22)
        local s2 = Step(2, "아래 줄을 복사해서 |cffffd6e0채채TV 방송 채팅|r에", row, -4)
        box = CopyBox(pg, W2 - 24); box:SetPoint("TOPLEFT", s2, "BOTTOMLEFT", 0, -6)
        Step(3, "화면을 찍어 두면 더 빨리 고쳐요 (|cffffd6e0PrtSc|r)", box, -10)
        pg.OnShow2 = Paint
        Paint()
    end

    -- 3. 새 소식
    do
        local pg = pages[3]
        local y = 0
        for i, n in ipairs(NEWS) do
            local v = pg:CreateFontString(nil, "OVERLAY"); v:SetFont(ns.NUM or ns.FONT, 15, ""); v:SetTextColor(C.accHi[1], C.accHi[2], C.accHi[3])
            v:SetPoint("TOPLEFT", 0, y); v:SetText(n[1])
            local a = ns.Font(pg, 12); a:SetPoint("TOPLEFT", 46, y); a:SetText(n[2])
            local b = ns.Font(pg, 10.5, { 0.62, 0.54, 0.52 }); b:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -3); b:SetText(n[3])
            if i > 1 then
                local ln = pg:CreateTexture(nil, "BORDER"); ln:SetColorTexture(0.949, 0.702, 0.761, 0.12); ln:SetHeight(1)
                ln:SetPoint("TOPLEFT", 0, y + 7); ln:SetPoint("TOPRIGHT", 0, y + 7)
            end
            y = y - 46
        end
        local note = ns.Font(pg, 10.5, { 0.62, 0.54, 0.52 }); note:SetPoint("TOPLEFT", 0, y - 2)
        note:SetText("새 버전 소식은 채채TV 방송 공지에서 먼저 알려요.")
    end

    t:SetScript("OnShow", function() Show(1) end)
    t:Hide()
    return t
end

----------------------------------------------------------------------
-- 오른쪽 미리 보기: 르엘 텍스처로 그린 작은 모형 (설정을 바꾸면 바로 반영)
----------------------------------------------------------------------
local function Val(m, label)
    for _, it in ipairs(m.items or {}) do
        if it.label == label and it.get then
            local ok, v = pcall(it.get)
            if ok then return v end
        end
    end
end
local function Box(p, w, h, r, col, a, layer)
    local f = CreateFrame("Frame", nil, p)
    f:SetSize(w, h)
    f.rr = ns.RoundRect(f, r, col or { 1, 1, 1 }, layer or "ARTWORK", 0, 0)
    if a then f.rr:SetColor(col or { 1, 1, 1 }, a) end
    return f
end
-- 알약 바: 어두운 바탕 + 채움 + (테)
local function PillBar(p, w, h, col, edge)
    local b = CreateFrame("Frame", nil, p)
    b:SetSize(w, h)
    if edge then b.e = ns.RoundRect(b, h / 2 + 1, edge, "BACKGROUND", 0, -1) end
    b.bg = ns.RoundRect(b, h / 2, { 0.16, 0.12, 0.11 }, "BACKGROUND", 1, 0)
    b.fill = Box(b, w, h, h / 2, col)
    b.fill:SetPoint("LEFT")
    function b:Set(pct, c)
        self.fill:SetWidth(math.max(h, (self:GetWidth()) * math.max(0, math.min(1, pct))))
        if c then self.fill.rr:SetColor(c, 1) end
    end
    return b
end
local function Tex(p, file, w, h, layer)
    local t = p:CreateTexture(nil, layer or "OVERLAY")
    t:SetTexture(ns.MEDIA .. file); t:SetSize(w, h or w)
    return t
end
local function ClassCol(cls)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    return c and { c.r, c.g, c.b } or { 0.6, 0.6, 0.6 }
end

local PV = {}
-- 줄 이름 → 강조할 곳 (hl 이 없는 예전 줄)
XP.HLREG = XP.HLREG or {}
XP.HLMAP = {
    LeelUI_Party = { ["파티 인원"] = "me", ["내 칸 자리"] = "me", ["정렬"] = "all", ["칸 가로"] = "all", ["칸 세로"] = "all", ["칸 사이"] = "all",
        ["세부 설정 처음으로"] = "all", ["기본 파티 창 숨기기"] = "all", ["이름"] = "name", ["체력 글씨"] = "hp",
        ["버프 · 디버프 보이기"] = "aura", ["해제할 디버프 알림"] = "dispel" },
    LeelUI_Roll = { ["토끼 추천"] = "rec", ["내 역할"] = "rec", ["결과 보드"] = "card", ["블리자드 획득 알림 숨기기"] = "card",
        ["토끼 단추 항상 보이기"] = "bun", ["파티 인사 말풍선"] = "bun", ["인사 미리 보기"] = "bun", ["블랙리스트 굴림 알림"] = "card",
        ["경고음"] = "card", ["채팅창에도 한 줄"] = "card", ["블랙리스트 알림 미리 보기"] = "card", ["주사위 기록장"] = "card", ["블랙리스트"] = "card" },
    LeelUI_Bags = { ["한 줄 칸 수"] = "all", ["거의 찼을 때 알림"] = "all", ["버릴 템 고르기 창"] = "all",
        ["새로 들어온 것, 가방을 닫아도 남기기"] = "new" },
}
-- 미리 보기 강조 (스포트라이트): 그 부분만 밝게 · 나머지 어둡게 + 분홍 테 + 말풍선
XP.Spot = function(st)
    local PAD = 5
    local dim = CreateFrame("Frame", nil, st); dim:SetAllPoints(st); dim:SetFrameLevel(st:GetFrameLevel() + 25)
    local bands = {}
    for i = 1, 4 do local b = dim:CreateTexture(nil, "BACKGROUND"); b:SetColorTexture(0.035, 0.022, 0.02, 0.74); bands[i] = b end
    local rim = CreateFrame("Frame", nil, st); rim:SetFrameLevel(st:GetFrameLevel() + 30)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = rim:CreateTexture(nil, "OVERLAY"); e:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 1)
        if side == "TOP" or side == "BOTTOM" then e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(3)
        else e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(3) end
    end
    local glow = rim:CreateTexture(nil, "BACKGROUND"); glow:SetTexture(ns.MEDIA .. "soft_glow"); glow:SetBlendMode("ADD")
    glow:SetPoint("TOPLEFT", -18, 18); glow:SetPoint("BOTTOMRIGHT", 18, -18); glow:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.55)
    local ag = glow:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
    local al = ag:CreateAnimation("Alpha"); al:SetFromAlpha(1); al:SetToAlpha(0.35); al:SetDuration(0.7); al:SetSmoothing("IN_OUT")
    local bub = CreateFrame("Frame", nil, rim)
    ns.RoundRect(bub, 12, C.acc, "ARTWORK", 0, 0)
    bub.fs = ns.Font(bub, 13, C.ink); bub.fs:SetShadowColor(0, 0, 0, 0); bub.fs:SetPoint("CENTER", 0, 0)
    rim:Hide(); dim:Hide()
    local o = {}
    function o.Off() rim:Hide(); dim:Hide(); ag:Stop() end
    function o.Alpha(a) rim:SetAlpha(a); dim:SetAlpha(a) end
    -- 탭을 바꾸면 다른 탭 미리 보기의 강조가 남지 않게 전부 끄려고 모아 둬요
    XP.spots = XP.spots or {}; XP.spots[#XP.spots + 1] = o
    function o.Show(e1, e2, text)
        rim:ClearAllPoints()
        rim:SetPoint("TOPLEFT", e1, "TOPLEFT", -PAD, PAD); rim:SetPoint("BOTTOMRIGHT", e2 or e1, "BOTTOMRIGHT", PAD, -PAD)
        local t, b, l, r = bands[1], bands[2], bands[3], bands[4]
        t:ClearAllPoints(); t:SetPoint("TOPLEFT", st, "TOPLEFT"); t:SetPoint("TOPRIGHT", st, "TOPRIGHT"); t:SetPoint("BOTTOM", rim, "TOP")
        b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", st, "BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT", st, "BOTTOMRIGHT"); b:SetPoint("TOP", rim, "BOTTOM")
        l:ClearAllPoints(); l:SetPoint("TOPRIGHT", rim, "TOPLEFT"); l:SetPoint("BOTTOMRIGHT", rim, "BOTTOMLEFT"); l:SetPoint("LEFT", st, "LEFT")
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", rim, "TOPRIGHT"); r:SetPoint("BOTTOMLEFT", rim, "BOTTOMRIGHT"); r:SetPoint("RIGHT", st, "RIGHT")
        bub:SetShown(text and text ~= "" and true or false)
        if text and text ~= "" then
            bub.fs:SetText(text)
            bub.fs:ClearAllPoints(); bub.fs:SetPoint("BOTTOMLEFT", rim, "TOPLEFT", 10, 16)
            bub:ClearAllPoints(); bub:SetPoint("TOPLEFT", bub.fs, "TOPLEFT", -12, 6); bub:SetPoint("BOTTOMRIGHT", bub.fs, "BOTTOMRIGHT", 12, -6)
        end
        dim:Show(); rim:Show(); ag:Play()
    end
    return o
end

-- 크기 맞추기: 슬라이더 최대 크기가 줄에 딱 맞는 비율로 늘 똑같이 줄여요
-- → 설정 크기를 키우면 미리 보기도 끝까지 같은 비율로 커져요
local function FitView(v, st, maxS)
    v:SetScale(1)
    local s = v.baseScale or 1
    local w, h = v:GetWidth(), v:GetHeight()
    local sw, sh = st:GetWidth(), st:GetHeight()
    local k = 1
    if w > 0 and h > 0 and sw and sw > 0 then k = math.min((sw * 0.96) / (w * maxS), (sh * 0.94) / (h * maxS)) end
    v:SetScale(math.max(0.05, s * k))
    v:ClearAllPoints(); v:SetPoint("CENTER", st, "CENTER", 0, 0)
    return k
end

-- 위쪽 HUD: 진짜 HUD와 같은 코드로 그린 모형 (내 캐릭터 + 가짜 대상)
PV.LeelUI = function(st)
    local wrap = CreateFrame("Frame", nil, st); wrap:SetAllPoints(st)
    local v = ns.BuildHudPreview(wrap)
    -- 지금 탭의 부분만 크게 (전체 · 내 창 · 가운데 · 대상 창 · 펫)
    local function Part()
        for _, m in ipairs(MODULES) do
            if m.key == "LeelUI" then
                local groups = Groups(m)
                local g = groups[math.min(curTab[m.key] or 1, #groups)]
                return g and g.head and g.head.pv or "all"
            end
        end
        return "all"
    end
    -- 줄에 마우스를 올리면: 바뀌는 곳만 밝게 · 나머지는 어둡게 (스포트라이트) + 굵은 빛 테 + 말풍선 (이름 · 지금 값)
    local PAD = 5
    local dim = CreateFrame("Frame", nil, st); dim:SetAllPoints(st); dim:SetFrameLevel(st:GetFrameLevel() + 25)
    local bands = {}
    for i = 1, 4 do
        local b = dim:CreateTexture(nil, "BACKGROUND"); b:SetColorTexture(0.035, 0.022, 0.02, 0.74); bands[i] = b
    end
    local rim = CreateFrame("Frame", nil, st)
    rim:SetFrameLevel(st:GetFrameLevel() + 30)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = rim:CreateTexture(nil, "OVERLAY")
        e:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 1)
        if side == "TOP" or side == "BOTTOM" then e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(3)
        else e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(3) end
    end
    rim.glow = rim:CreateTexture(nil, "BACKGROUND"); rim.glow:SetTexture(ns.MEDIA .. "soft_glow"); rim.glow:SetBlendMode("ADD")
    rim.glow:SetPoint("TOPLEFT", -18, 18); rim.glow:SetPoint("BOTTOMRIGHT", 18, -18); rim.glow:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.55)
    local ag = rim.glow:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
    local al = ag:CreateAnimation("Alpha"); al:SetFromAlpha(1); al:SetToAlpha(0.35); al:SetDuration(0.7); al:SetSmoothing("IN_OUT")
    -- 말풍선
    local bub = CreateFrame("Frame", nil, rim)
    ns.RoundRect(bub, 12, C.acc, "ARTWORK", 0, 0)
    bub.fs = ns.Font(bub, 13, C.ink); bub.fs:SetShadowColor(0, 0, 0, 0); bub.fs:SetPoint("CENTER", 0, 0)
    bub.tail = bub:CreateTexture(nil, "ARTWORK"); bub.tail:SetTexture(ns.MEDIA .. "circle"); bub.tail:SetSize(10, 10)
    bub.tail:SetVertexColor(C.acc[1], C.acc[2], C.acc[3]); bub.tail:SetPoint("CENTER", bub, "BOTTOMLEFT", 20, 1)
    rim:Hide(); dim:Hide()
    local function Off() rim:Hide(); dim:Hide(); ag:Stop() end
    function ns.HudPvHLAlpha(a) rim:SetAlpha(a); dim:SetAlpha(a) end
    function ns.HudPvHL(key, text)
        if not key or not wrap:IsVisible() then Off() return end
        local part = Part()
        local side = (part == "target" or part == "tot") and v.t or v.p
        local el
        if key == "part" then
            el = (part == "center" and v.mid) or (part == "pet" and v.pet) or (part == "tot" and v.tot) or (part == "all" and v) or side
        elseif key == "name" then el = side.name
        elseif key == "lv" then el = side.lv
        elseif key == "hp" then el = side.hpValue
        elseif key == "pct" then el = side.hpPct
        elseif key == "bar" then el = side.hp
        elseif key == "sub" then el = side.tpower or side.powerText or side.manaText or side.power
        elseif key == "pow" then el = side.power or side.tpower
        elseif key == "por" then el = side.portrait
        elseif key == "ear" then el = v.midEarBox or v.midEarIdle   -- 양쪽 귀 함께
        elseif key == "num" then el = v.midNum
        elseif key == "csub" then el = v.midSub
        elseif key == "dots" then el = v.midDots
        elseif key == "fx" then el = v.midGlow and v.midGlow:IsShown() and v.midGlow or v.midEarIdle
        elseif key == "powtx" then el = side.powerText or side.tpowerText
        elseif key == "deb" then el = side.pvDeb
        elseif key == "buf" then el = side.pvBuf
        elseif key == "cast" then el = side.pvCast
        elseif key == "combo" then el = side.pvCombo
        elseif key == "thr" or key == "rank" then el = side.portrait
        end
        if not (el and el.IsVisible and el:IsVisible()) then Off() return end
        rim:ClearAllPoints()
        rim:SetPoint("TOPLEFT", el, "TOPLEFT", -PAD, PAD); rim:SetPoint("BOTTOMRIGHT", el, "BOTTOMRIGHT", PAD, -PAD)
        -- 어두운 띠 넷 (위 · 아래 · 왼쪽 · 오른쪽)
        local t, b, l, r = bands[1], bands[2], bands[3], bands[4]
        t:ClearAllPoints(); t:SetPoint("TOPLEFT", st, "TOPLEFT"); t:SetPoint("TOPRIGHT", st, "TOPRIGHT"); t:SetPoint("BOTTOM", rim, "TOP")
        b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", st, "BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT", st, "BOTTOMRIGHT"); b:SetPoint("TOP", rim, "BOTTOM")
        l:ClearAllPoints(); l:SetPoint("TOPRIGHT", rim, "TOPLEFT"); l:SetPoint("BOTTOMRIGHT", rim, "BOTTOMLEFT"); l:SetPoint("LEFT", st, "LEFT")
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", rim, "TOPRIGHT"); r:SetPoint("BOTTOMLEFT", rim, "BOTTOMRIGHT"); r:SetPoint("RIGHT", st, "RIGHT")
        bub:SetShown(text and text ~= "" and true or false)
        if text and text ~= "" then
            -- 폭 계산 없이: 글자를 테 위에 놓고 말풍선이 글자를 감싸게 (전투 중 비밀 값이어도 안전)
            bub.fs:SetText(text)
            bub.fs:ClearAllPoints(); bub.fs:SetPoint("BOTTOMLEFT", rim, "TOPLEFT", 10, 16)
            bub:ClearAllPoints(); bub:SetPoint("TOPLEFT", bub.fs, "TOPLEFT", -12, 6); bub:SetPoint("BOTTOMRIGHT", bub.fs, "BOTTOMRIGHT", 12, -6)
        end
        dim:Show(); rim:Show(); ag:Play()
    end
    function wrap:Update()
        Off()
        v:Refresh()
        local part = Part()
        if v.Focus then v:Focus(part) end
        v.baseScale = ns.db.scale or 0.7
        if part == "all" then
            v:SetSize(v.fullW or v:GetWidth(), v.fullH or v:GetHeight())
            local k = FitView(v, st, 1.5)
            self.zoom = k
            return
        end
        -- 부분만: 그 부분이 칸 가운데 오게 · 너무 크게는 안 (1.6배까지)
        local tgt = (part == "player" and v.p) or (part == "target" and v.t) or (part == "center" and v.mid)
            or (part == "pet" and v.pet) or (part == "tot" and v.tot) or v
        if part == "tot" and not (v.tot and v.tot:IsShown()) then tgt = v.t end
        v:SetScale(1)
        v:ClearAllPoints(); v:SetPoint("CENTER", st, "CENTER", 0, 0)
        -- 크기 · 자리 계산 (전투 중 비밀 값이면 그냥 가운데 · 그대로)
        local ok, k = pcall(function()
            local rel = tgt:GetEffectiveScale() / v:GetEffectiveScale()
            local w, h = tgt:GetWidth() * rel, tgt:GetHeight() * rel
            local sw, sh = st:GetWidth(), st:GetHeight()
            local k = 1
            if w > 0 and h > 0 and sw > 0 then k = math.min(sw * 0.8 / w, sh * 0.75 / h) end
            k = math.min(k, part == "tot" and 1.6 or 1.1)
            v:SetScale(k)
            local cx, cy = tgt:GetCenter()
            local sx, sy = st:GetCenter()
            if cx and sx then
                local te, se, ve = tgt:GetEffectiveScale(), st:GetEffectiveScale(), v:GetEffectiveScale()
                v:SetPoint("CENTER", st, "CENTER", (sx * se - cx * te) / ve, (sy * se - cy * te) / ve)
            end
            return k
        end)
        if not ok then
            k = 1; v:SetScale(1); v:ClearAllPoints(); v:SetPoint("CENTER", st, "CENTER", 0, 0)
        end
        self.zoom = k
    end
    return wrap
end

-- 파티 프레임: 진짜 파티 칸과 같은 코드로 그린 모형 (가짜 파티원)
PV.LeelUI_Party = function(st)
    local wrap = CreateFrame("Frame", nil, st); wrap:SetAllPoints(st)
    local v = ns.BuildPartyPreview(wrap)
    function wrap:Update()
        v:Refresh()
        v.baseScale = ns.db.partyScale or 0.75
        local k = FitView(v, st, 1.5)
        self.zoom = k
    end
    local spot = XP.Spot(st)
    XP.HLREG.LeelUI_Party = { function(k, text)
        if not k or not wrap:IsVisible() then spot.Off() return end
        local m = v.members or {}
        local a = m[1]
        if k == "name" and a then spot.Show(a.name, a.name, text)
        elseif k == "hp" and a and a.val:IsShown() then spot.Show(a.val, a.val, text)
        elseif k == "aura" and a and a.buffs then spot.Show(a.buffs, a.buffs, text)
        elseif k == "dispel" and a then spot.Show(a, a, text)
        elseif k == "me" and m[5] and m[5]:IsShown() then spot.Show(m[5], m[5], text)
        else spot.Show(v, v, text) end
    end, function(x) spot.Alpha(x) end }
    return wrap
end

-- 적 이름표: 알약 바 + 내 대상 표시 (조준 / 화살표)
PV.LeelUI_Plates = function(st)
    -- 내 창 미리 보기처럼: 진짜 이름표 코드로 만든 이름표 하나를 가운데 크게
    --   줄에 마우스를 올리면 바뀌는 곳만 밝게 · 나머지는 어둡게 + 분홍 테 + 말풍선 (상황이 필요한 줄은 그 모습으로)
    local v = CreateFrame("Frame", nil, st); v:SetSize(240, 120); v:SetPoint("CENTER")
    if ns.NPPreview then v.np = ns.NPPreview(v); v.np:SetPoint("CENTER", v, "CENTER", 0, 0) end
    local PAD = 5
    local dim = CreateFrame("Frame", nil, st); dim:SetAllPoints(st); dim:SetFrameLevel(st:GetFrameLevel() + 25)
    local bands = {}
    for i = 1, 4 do local b = dim:CreateTexture(nil, "BACKGROUND"); b:SetColorTexture(0.035, 0.022, 0.02, 0.74); bands[i] = b end
    local rim = CreateFrame("Frame", nil, st); rim:SetFrameLevel(st:GetFrameLevel() + 30)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = rim:CreateTexture(nil, "OVERLAY"); e:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 1)
        if side == "TOP" or side == "BOTTOM" then e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(3)
        else e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(3) end
    end
    rim.glow = rim:CreateTexture(nil, "BACKGROUND"); rim.glow:SetTexture(ns.MEDIA .. "soft_glow"); rim.glow:SetBlendMode("ADD")
    rim.glow:SetPoint("TOPLEFT", -18, 18); rim.glow:SetPoint("BOTTOMRIGHT", 18, -18); rim.glow:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.55)
    local ag = rim.glow:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
    local al = ag:CreateAnimation("Alpha"); al:SetFromAlpha(1); al:SetToAlpha(0.35); al:SetDuration(0.7); al:SetSmoothing("IN_OUT")
    local bub = CreateFrame("Frame", nil, rim)
    ns.RoundRect(bub, 12, C.acc, "ARTWORK", 0, 0)
    bub.fs = ns.Font(bub, 13, C.ink); bub.fs:SetShadowColor(0, 0, 0, 0); bub.fs:SetPoint("CENTER", 0, 0)
    rim:Hide(); dim:Hide()
    local function Off() rim:Hide(); dim:Hide(); ag:Stop() end
    function ns.NPPvHLAlpha(a) rim:SetAlpha(a); dim:SetAlpha(a) end
    function ns.NPPvHL(key, text)
        local np = v.np
        if not np then return end
        np:Temp(key)
        if not key or not v:IsVisible() then Off() return end
        local e1, e2 = np:Elem(key)
        if not (e1 and e1:IsVisible()) then Off() return end
        e2 = (e2 and e2:IsVisible()) and e2 or e1
        rim:ClearAllPoints()
        rim:SetPoint("TOPLEFT", e1, "TOPLEFT", -PAD, PAD); rim:SetPoint("BOTTOMRIGHT", e2, "BOTTOMRIGHT", PAD, -PAD)
        local t, b, l, r = bands[1], bands[2], bands[3], bands[4]
        t:ClearAllPoints(); t:SetPoint("TOPLEFT", st, "TOPLEFT"); t:SetPoint("TOPRIGHT", st, "TOPRIGHT"); t:SetPoint("BOTTOM", rim, "TOP")
        b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", st, "BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT", st, "BOTTOMRIGHT"); b:SetPoint("TOP", rim, "BOTTOM")
        l:ClearAllPoints(); l:SetPoint("TOPRIGHT", rim, "TOPLEFT"); l:SetPoint("BOTTOMRIGHT", rim, "BOTTOMLEFT"); l:SetPoint("LEFT", st, "LEFT")
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", rim, "TOPRIGHT"); r:SetPoint("BOTTOMLEFT", rim, "BOTTOMRIGHT"); r:SetPoint("RIGHT", st, "RIGHT")
        bub:SetShown(text and text ~= "" and true or false)
        if text and text ~= "" then
            bub.fs:SetText(text)
            bub.fs:ClearAllPoints(); bub.fs:SetPoint("BOTTOMLEFT", rim, "TOPLEFT", 10, 16)
            bub:ClearAllPoints(); bub:SetPoint("TOPLEFT", bub.fs, "TOPLEFT", -12, 6); bub:SetPoint("BOTTOMRIGHT", bub.fs, "BOTTOMRIGHT", 12, -6)
        end
        dim:Show(); rim:Show(); ag:Play()
    end
    function v:Update(m)
        if not self.np then return end
        Off(); self.np.temp = nil
        self.np:Arrange()
        self:SetSize(self.np:GetWidth(), self.np:GetHeight())
        self.np:Apply()
        local sw, sh = st:GetWidth() or 600, st:GetHeight() or 160
        self:SetScale(math.max(0.8, math.min(2.0, (sw * 0.6) / self:GetWidth(), (sh * 0.92) / self:GetHeight())))
    end
    return v
end

-- 툴팁: 진짜 툴팁과 같은 판 (몹 · 아이템 나란히) + 줄에 마우스를 올리면 그 줄 강조
PV.LeelUI_Tip = function(st)
    local v = CreateFrame("Frame", nil, st); v:SetSize(560, 150); v:SetPoint("CENTER")
    local function TO(k) return ns.TipOpt and ns.TipOpt(k) end
    local function Tip(w, h)
        local t = CreateFrame("Frame", nil, v); t:SetSize(w, h)
        t.fill, t.edge = ns.RoundPlate(t, 14, { 0.114, 0.082, 0.078, 0.97 }, { 0.949, 0.702, 0.761, 0.38 })
        t.stripe = t:CreateTexture(nil, "BORDER"); t.stripe:SetTexture(ns.WHITE)
        t.stripe:SetPoint("TOPLEFT", 1, -10); t.stripe:SetPoint("BOTTOMLEFT", 1, 10); t.stripe:SetWidth(5)
        t.lines = {}
        return t
    end
    local function Line(t, text, size, col)
        local fs = ns.Font(t, size or 12, col or C.tx); fs:SetJustifyH("LEFT"); fs:SetText(text)
        local prev = t.lines[#t.lines]
        if prev then fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -3) else fs:SetPoint("TOPLEFT", t, "TOPLEFT", 12, -10) end
        t.lines[#t.lines + 1] = fs
        return fs
    end
    -- 몹 툴팁
    local u = Tip(250, 120); u:SetPoint("RIGHT", v, "CENTER", -10, 0)
    u.name = Line(u, "붉은갈기 노움", 14, { 1, 0.54, 0.54 })
    u.l2 = Line(u, "36 레벨 정예 인간형", 12)
    u.guild = Line(u, "<토끼 길드>", 12, { 0.6, 0.9, 0.6 })
    u.tot = Line(u, "대상: |cfff2b3c2나|r", 12, { 0.85, 0.78, 0.76 })
    u.mine = Line(u, "|cfff2b3c2● 내 대상|r", 12)
    u.chip = CreateFrame("Frame", nil, u); u.chip:SetSize(36, 15)
    ns.RoundRect(u.chip, 7, { 0.29, 0.14, 0.14 }, "ARTWORK", 0, 0)
    local cf = ns.Font(u.chip, 10.5, { 1, 0.69, 0.69 }); cf:SetPoint("CENTER"); cf:SetText("적대")
    u.chip:SetPoint("LEFT", u.name, "LEFT", (u.name:GetStringWidth() or 90) + 6, 0)
    u.bar = CreateFrame("StatusBar", nil, u); u.bar:SetStatusBarTexture(ns.WHITE); u.bar:SetHeight(8)
    u.bar:SetPoint("BOTTOMLEFT", 12, 12); u.bar:SetPoint("BOTTOMRIGHT", -52, 12)
    u.bar:SetMinMaxValues(0, 100); u.bar:SetValue(62)
    local RED = ns.HP_RED or { 0.722, 0.118, 0.208 }; u.bar:SetStatusBarColor(RED[1], RED[2], RED[3], 1)
    local bbg = u.bar:CreateTexture(nil, "BACKGROUND"); bbg:SetAllPoints(); bbg:SetColorTexture(0.11, 0.08, 0.075, 0.9)
    u.pct = ns.Num(u.bar, 12, C.accHi); u.pct:SetPoint("LEFT", u.bar, "RIGHT", 8, 0); u.pct:SetText("62%")
    u.bun = CreateFrame("Frame", nil, u); u.bun:SetSize(24, 24); u.bun:SetPoint("CENTER", u, "TOPRIGHT", -4, -2)
    local r1 = u.bun:CreateTexture(nil, "BACKGROUND"); r1:SetTexture(ns.MEDIA .. "circle"); r1:SetVertexColor(0.949, 0.702, 0.761, 0.8); r1:SetPoint("TOPLEFT", -1.5, 1.5); r1:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
    local r2 = u.bun:CreateTexture(nil, "BORDER"); r2:SetTexture(ns.MEDIA .. "circle"); r2:SetVertexColor(0.17, 0.13, 0.125, 1); r2:SetAllPoints()
    local r3 = u.bun:CreateTexture(nil, "ARTWORK"); r3:SetTexture(ns.MEDIA .. "bunny"); r3:SetPoint("CENTER"); r3:SetSize(20, 20)
    -- 아이템 툴팁
    local it = Tip(250, 120); it:SetPoint("LEFT", v, "CENTER", 10, 0)
    it.name = Line(it, "늑대 가죽 장화", 14, { 0.0, 0.44, 0.87 })
    Line(it, "발 · 가죽", 12); Line(it, "방어도 74 · 민첩성 +8", 12)
    it.ilvl = Line(it, "아이템 레벨 38", 12, { 1, 0.84, 0.54 })
    it.price = Line(it, "판매 가격  |cffffd27a1 은 24 동|r", 12)
    it.ids = Line(it, "아이템 번호 6085", 12, { 0.55, 0.48, 0.47 })
    v.u, v.it = u, it
    local function Relayout(t, list)
        local prev
        for _, fs in ipairs(list) do
            if fs:IsShown() then
                fs:ClearAllPoints()
                if prev then fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -3) else fs:SetPoint("TOPLEFT", t, "TOPLEFT", 12, -10) end
                prev = fs
            end
        end
    end
    function v:Update(m)
        local bgA = (tonumber(TO("bgA")) or 97) / 100
        for _, t in ipairs({ u, it }) do t.fill:SetColor({ 0.114, 0.082, 0.078 }, bgA); t.edge:SetColor({ 0.949, 0.702, 0.761 }, 0.38) end
        u.tot:SetShown(TO("tot") and true or false)
        u.guild:SetShown(TO("guild") and true or false)
        u.mine:SetShown(TO("mine") and true or false)
        local rel = TO("rel") or "chip"
        u.chip:SetShown(rel == "chip")
        u.stripe:SetShown(rel == "stripe"); u.stripe:SetVertexColor(1, 0.54, 0.54, 1)
        it.stripe:Hide()
        u.bun:SetShown(TO("bunny") and true or false)
        local hb = TO("hpBar") or "both"
        u.bar:SetShown(hb ~= "off"); u.pct:SetShown(hb == "both")
        it.ilvl:SetShown(TO("ilvl") and true or false)
        it.ids:SetShown(TO("ids") and true or false)
        if TO("quality") then it.edge:SetColor({ 0.0, 0.44, 0.87 }, 0.95) end
        Relayout(u, { u.name, u.l2, u.guild, u.tot, u.mine })
        Relayout(it, { it.name, it.lines[2], it.lines[3], it.ilvl, it.price, it.ids })
        local function H(t, list, extra)
            local hh = 20
            for _, fs in ipairs(list) do if fs:IsShown() then hh = hh + (fs:GetStringHeight() or 14) + 3 end end
            t:SetHeight(hh + (extra or 0))
        end
        H(u, { u.name, u.l2, u.guild, u.tot, u.mine }, hb ~= "off" and 22 or 0)
        H(it, { it.name, it.lines[2], it.lines[3], it.ilvl, it.price, it.ids })
        local sc = (tonumber(TO("scale")) or 100) / 100
        local sw, sh = st:GetWidth() or 600, st:GetHeight() or 160
        v:SetScale(math.max(0.6, math.min(1.4, sc * math.min(1.3, (sw - 20) / 560, (sh - 10) / 170))))
    end
    -- 줄 강조 (적 이름표 · 내 창과 같은 분홍 테 + 말풍선 · 나머지는 어둡게)
    local spot = XP.Spot(st)
    function ns.TipPvHLAlpha(a) spot.Alpha(a) end
    function ns.TipPvHL(key, text)
        if not key or not v:IsVisible() then spot.Off() return end
        local el = (key == "tot" and u.tot) or (key == "guild" and u.guild) or (key == "mine" and u.mine) or (key == "rel" and (u.chip:IsShown() and u.chip or u.stripe))
            or (key == "bunny" and u.bun) or (key == "hp" and u.bar) or (key == "ilvl" and it.ilvl) or (key == "ids" and it.ids)
            or (key == "item" and it) or u
        if key == "all" then spot.Show(u, it, text) return end
        if not (el and el:IsVisible()) then spot.Off() return end
        spot.Show(el, el, text)
    end
    return v
end

-- 마우스: 같은 효과 코드로 작은 칸 안에서 커서가 돌아다녀요 (꼬리 → 클릭 퐁 → 적 반응 → 커서 찾기)
PV.LeelUI_Mouse = function(st)
    local v = CreateFrame("Frame", nil, st); v:SetSize(520, 140); v:SetPoint("CENTER")
    if ns.CursorDemo then v.d = ns.CursorDemo(v); v.d:SetPoint("CENTER") end
    local spot = XP.Spot(st)
    function ns.CfxPvHLAlpha(a) spot.Alpha(a) end
    function ns.CfxPvHL(key, text)
        local d = v.d
        if not key or not d or not v:IsVisible() then spot.Off() return end
        if key == "react" then spot.Show(d.mob, d.mob, text)
        elseif key == "click" or key == "find" then spot.Show(d.cur, d.cur, text)
        else spot.Show(d, d, text) end
    end
    function v:Update(m)
        local sw, sh = st:GetWidth() or 600, st:GetHeight() or 160
        self:SetScale(math.max(0.6, math.min(1.3, (sw - 16) / 520, (sh - 8) / 140)))
    end
    return v
end

-- 채팅창: 진짜 채팅창 모양 (채널 기둥 + 분홍 테 카드 + 입력 알약 + 새 글 알약) + 말풍선
PV.LeelUI_Chat = function(st)
    local v = CreateFrame("Frame", nil, st); v:SetSize(600, 160); v:SetPoint("CENTER")
    local function D() return (ns.ChatDB and ns.ChatDB()) or {} end
    -- 채널 기둥
    local rail = Box(v, 40, 160, 12, { 0.129, 0.094, 0.086 }); rail:SetPoint("LEFT", v, "LEFT", 0, 0)
    local icons = { "ci_chat", "ci_guild", "ci_party", "ci_whisper" }
    rail.btn = {}
    for i, ic in ipairs(icons) do
        local b = Box(rail, 30, 30, 15, i == 1 and C.acc or { 0.2, 0.15, 0.14 }); b:SetPoint("TOP", rail, "TOP", 0, -8 - (i - 1) * 36)
        local t = Tex(b, ic, 17, 17); t:SetPoint("CENTER"); if i == 1 then t:SetVertexColor(0.11, 0.08, 0.075) end
        rail.btn[i] = b
    end
    local badge = Box(rail.btn[2], 16, 14, 7, { 1, 0.48, 0.40 }); badge:SetPoint("CENTER", rail.btn[2], "TOPRIGHT", -2, -2)
    local bt = ns.Font(badge, 9.5, { 1, 1, 1 }); bt:SetPoint("CENTER", 0, 0); bt:SetText("3")
    local wd = Tex(rail.btn[4], "circle", 9, 9); wd:SetPoint("CENTER", rail.btn[4], "TOPRIGHT", -3, -3); wd:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    -- 카드
    local card = CreateFrame("Frame", nil, v); card:SetSize(400, 160); card:SetPoint("LEFT", rail, "RIGHT", 6, 0)
    card.fill, card.edge = ns.RoundPlate(card, 14, { 0.114, 0.082, 0.078, 0.95 }, { 0.949, 0.702, 0.761, 0.4 })
    local head = ns.Font(card, 12, C.accHi); head:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -9); head:SetText("일반")
    local body = CreateFrame("Frame", nil, card); body:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -28); body:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -28); body:SetHeight(92)
    local me = UnitName("player") or "나"
    local MSG = {
        { "cc_general", "|cffffc9a8[토끼상인]|r: 은빛 실 싸게 팔아요", "21:02" },
        { "cc_guild", "|cff8fdc9c[당근]|r: 레이드 8시 반 출발해요~", "21:04" },
        { "cc_party", "|cff9fbcf4[토리]|r: @" .. me .. " 물약 하나만 줘~", "21:05", nil, true },
        { "cc_whisper", "|cffeda0d6[깡충이]|r 님의 귓속말: " .. me .. "님 같이 가요", "21:06", true },
    }
    local lines = {}
    for i = 1, #MSG do lines[i] = ns.Font(body, 13, C.tx); lines[i]:SetJustifyH("LEFT"); lines[i]:SetWordWrap(false); lines[i]:SetWidth(380) end
    -- 입력 알약 · 새 글 알약
    local input = Box(card, 376, 22, 11, { 0.17, 0.13, 0.125 }); input:SetPoint("BOTTOM", card, "BOTTOM", 0, 8)
    local it = ns.Font(input, 11, { 0.55, 0.48, 0.47 }); it:SetPoint("LEFT", 10, 0); it:SetText("|cfff2b3c2[파티]|r  ↑ 최근 보낸 말 · @ 이름 고르기")
    local snd = Tex(input, "ci_send", 12, 12); snd:SetPoint("RIGHT", -8, 0)
    local newP = Box(card, 86, 18, 9, C.acc); newP:SetPoint("BOTTOM", input, "TOP", 0, 4); newP:SetFrameLevel(card:GetFrameLevel() + 5)
    local nt = ns.Font(newP, 10.5, C.ink); nt:SetShadowColor(0, 0, 0, 0); nt:SetPoint("CENTER"); nt:SetText("새 글 2개")
    -- 파티원 말풍선
    local bub = CreateFrame("Frame", nil, v); bub:SetSize(138, 48); bub:SetPoint("LEFT", card, "RIGHT", 14, 12)
    bub.fill, bub.edge = ns.RoundPlate(bub, 12, { 0.96, 0.94, 0.92, 0.96 }, { 0.6, 0.55, 0.5, 0.5 })
    bub.cls = bub:CreateTexture(nil, "ARTWORK"); bub.cls:SetTexture(ns.WHITE); bub.cls:SetPoint("TOPLEFT", 2, -7); bub.cls:SetPoint("BOTTOMLEFT", 2, 7); bub.cls:SetWidth(4)
    local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS.MAGE; bub.cls:SetVertexColor(cc and cc.r or 0.25, cc and cc.g or 0.78, cc and cc.b or 0.92, 1)
    local bf = ns.Font(bub, 11.5, { 0.15, 0.11, 0.1 }); bf:SetShadowColor(0, 0, 0, 0); bf:SetPoint("LEFT", 12, 0); bf:SetText("넵 준비 완료!")
    local tail = bub:CreateTexture(nil, "ARTWORK"); tail:SetTexture(ns.MEDIA .. "circle"); tail:SetSize(9, 9); tail:SetPoint("TOPLEFT", bub, "BOTTOMLEFT", 16, 2); tail:SetVertexColor(0.96, 0.94, 0.92, 0.96)
    local bcap = ns.Font(v, 10, { 0.66, 0.58, 0.56 }); bcap:SetPoint("TOP", bub, "BOTTOM", 0, -10); bcap:SetText("파티원 말풍선")
    function v:Update(m)
        local d = D()
        local a = (tonumber(d.alpha) or 0) / 100
        card.fill:SetColor({ 0.114, 0.082, 0.078 }, math.max(0.18, a * 0.95)); card.edge:SetColor({ 0.949, 0.702, 0.761 }, math.max(0.22, a * 0.45))
        rail.rr:SetColor({ 0.129, 0.094, 0.086 }, math.max(0.3, math.min(1, a * 1.1)))
        local fsz = tonumber(d.fsize); if not fsz then local _, z = ChatFrame1:GetFont(); fsz = math.floor((z or 14) + 0.5) end
        local ts, chips, heart = d.ts or "off", d.chips ~= false, d.myName and true or false
        local h = math.floor(fsz * 1.15 + 0.5)
        local y = 0
        for i, msg in ipairs(MSG) do
            local fs = lines[i]
            local f, _, fl = fs:GetFont(); if f then pcall(fs.SetFont, fs, f, fsz * 0.95, fl) end
            local t = msg[2]
            if chips then t = ("|T%s%s:%d:%d:0:-1|t "):format(ns.MEDIA, msg[1], h, h * 2) .. t
            else t = ({ cc_general = "[1. 공개] ", cc_guild = "[길드] ", cc_party = "[파티] ", cc_whisper = "" })[msg[1]] .. t end
            if heart and msg[4] then t = ("|T%sfx_heart:%d:%d|t "):format(ns.MEDIA, h, h) .. t end
            if msg[5] and d.atOn ~= false then
                t = t:gsub("@" .. me, "|cffffb3c6@" .. me .. "|r")
                t = ("|TInterface\\Buttons\\WHITE8X8:%d:3:0:0:8:8:0:8:0:8:242:179:194|t "):format(h + 2) .. t
            end
            if ts ~= "off" then t = "|cff8a7a78" .. msg[3] .. (ts == "hms" and ":17" or "") .. "|r " .. t end
            fs:SetText(t)
            fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
            y = y + fsz + 6
            fs:SetAlpha((i == 1 and d.fade ~= false) and 0.38 or 1)
        end
        bub.cls:SetShown(d.bubbleCls ~= false)
        local sw, sh = st:GetWidth() or 600, st:GetHeight() or 160
        self:SetScale(math.max(0.6, math.min(1.3, (sw - 16) / 600, (sh - 8) / 166)))
    end
    local spot = XP.Spot(st)
    function ns.ChatPvHLAlpha(x) spot.Alpha(x) end
    function ns.ChatPvHL(key, text)
        if not key or not v:IsVisible() then spot.Off() return end
        if key == "alpha" then spot.Show(rail, card, text)
        elseif key == "font" or key == "ts" or key == "chips" then spot.Show(lines[1], lines[#lines], text)
        elseif key == "me" or key == "whisper" then spot.Show(lines[4], lines[4], text)
        elseif key == "fade" then spot.Show(lines[1], lines[1], text)
        elseif key == "bubble" then spot.Show(bub, bub, text)
        elseif key == "hist" or key == "atpick" then spot.Show(input, input, text)
        elseif key == "at" then spot.Show(lines[3], lines[3], text)
        elseif key == "rail" then spot.Show(rail, rail, text)
        else spot.Show(rail, bub, text) end
    end
    return v
end

-- 시전바: 차오르는 알약 + 깡충 토끼
PV.LeelUI_Cast = function(st)
    -- 진짜 시전바와 같은 모양 (깡충 토끼 / 토끼 발자국 / 예전 얇은 바) + 허브 세부 설정 그대로
    local v = CreateFrame("Frame", nil, st); v:SetSize(330, 250); v:SetPoint("CENTER")
    local COLME, COLEN = { 0.95, 0.70, 0.76 }, { 1.00, 0.54, 0.44 }
    local function Row(me)
        local r = CreateFrame("Frame", nil, v); r:SetSize(330, 90)
        r.cap = ns.Font(r, 10.5, { 0.66, 0.58, 0.56 }); r.cap:SetText(me and "내 시전바" or "적 시전바")
        r.bar = PillBar(r, 260, 16, me and COLME or COLEN, { 0.07, 0.05, 0.04 })
        r.pawBg = Tex(r, "cb_paws", 208, 26, "ARTWORK"); r.pawBg:SetVertexColor(1, 1, 1, 0.22)
        r.pawFill = Tex(r, "cb_paws", 208, 26, "OVERLAY")
        r.icon = r:CreateTexture(nil, "OVERLAY", nil, 2)
        r.icon:SetTexture(me and 135812 or 136048); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local mk = r:CreateMaskTexture(); mk:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); mk:SetAllPoints(r.icon)
        r.icon:AddMaskTexture(mk)
        r.iconEdge = r:CreateTexture(nil, "OVERLAY", nil, 1); r.iconEdge:SetTexture(ns.MEDIA .. "circle"); r.iconEdge:SetVertexColor(0.07, 0.05, 0.04, 1)
        r.iconEdge:SetPoint("TOPLEFT", r.icon, -1.5, 1.5); r.iconEdge:SetPoint("BOTTOMRIGHT", r.icon, 1.5, -1.5)
        r.name = ns.Font(r, 14); r.name:SetText(me and "화염구" or "번개 화살")
        r.time = (ns.Num and ns.Num(r, 18, C.tx)) or ns.Font(r, 18); pcall(r.time.SetShadowOffset, r.time, 0, -1)
        r.kick = Box(r, 34, 16, 8, { 0.85, 0.26, 0.18 })
        local kt = ns.Font(r.kick, 10.5, { 1, 1, 1 }); kt:SetPoint("CENTER"); kt:SetText("끊기")
        local top = CreateFrame("Frame", nil, r); top:SetAllPoints(); top:SetFrameLevel(r:GetFrameLevel() + 6)
        r.goal = Tex(top, me and "cb_heart" or "cb_carrot", 18, 18)
        r.bun = Tex(top, "bunny", 30, 30)
        r.lag = top:CreateTexture(nil, "ARTWORK"); r.lag:SetColorTexture(0.85, 0.26, 0.18, 0.6)
        r.ticks = {}
        for i = 1, 3 do local t = top:CreateTexture(nil, "ARTWORK"); t:SetColorTexture(1, 1, 1, 0.7); t:SetWidth(1.5); r.ticks[i] = t end
        r.me = me
        return r
    end
    v.en = Row(false); v.me = Row(true)
    v.en:SetPoint("CENTER", v, "CENTER", 0, 58)
    v.me:SetPoint("CENTER", v, "CENTER", 0, -52)
    local function O(k) return ns.CastOpt and ns.CastOpt(k) end
    local function Fsz(fs, base)
        local f, _, fl = fs:GetFont()
        if f then pcall(fs.SetFont, fs, f, math.max(7, base + (tonumber(O("fsz")) or 0)), fl) end
    end
    local function Lay(r, p)
        local style = ns.db.castStyle or "bunny"
        local len, th = (tonumber(O("len")) or 100) / 100, (tonumber(O("thick")) or 100) / 100
        local col = r.me and COLME or COLEN
        if r.me then
            local m = O("col")
            if m == "white" then col = { 1, 0.97, 0.98 }
            elseif m == "class" then local _, cls = UnitClass("player"); col = ClassCol(cls) end
        end
        local W, H
        if style == "paw" then W, H = math.floor(208 * len + 0.5), math.max(10, math.floor(26 * th + 0.5))
        elseif style == "hud" then W, H = math.floor((r.me and 220 or 230) * len + 0.5), math.max(4, math.floor(10 * th + 0.5))
        else W, H = math.floor((r.me and 300 or 250) * len * 0.86 + 0.5), math.max(6, math.floor(16 * th + 0.5)) end
        local paw = style == "paw"
        r.bar:SetShown(not paw); r.pawBg:SetShown(paw); r.pawFill:SetShown(paw)
        r.bun:SetShown(style == "bunny"); r.goal:SetShown(style == "bunny")
        r.kick:SetShown(not r.me and style ~= "hud")
        local fillAnchor
        if paw then
            r.pawBg:ClearAllPoints(); r.pawBg:SetPoint("CENTER", r, "CENTER", 0, 4); r.pawBg:SetSize(W, H)
            r.pawFill:ClearAllPoints(); r.pawFill:SetPoint("LEFT", r.pawBg, "LEFT", 0, 0)
            r.pawFill:SetSize(math.max(1, W * p), H); r.pawFill:SetTexCoord(0, math.max(0.01, p), 0, 1)
            r.pawFill:SetVertexColor(col[1], col[2], col[3], 1)
            fillAnchor = r.pawBg
        else
            r.bar:ClearAllPoints(); r.bar:SetPoint("CENTER", r, "CENTER", 0, style == "hud" and 10 or 0); r.bar:SetSize(W, H)
            r.bar.fill:SetHeight(H)
            r.bar:Set(p, col)
            fillAnchor = r.bar
        end
        if style == "bunny" then
            r.bun:ClearAllPoints(); r.bun:SetPoint("CENTER", r.bar.fill, "RIGHT", 0, 3)
            r.goal:ClearAllPoints(); r.goal:SetPoint("CENTER", r.bar, "RIGHT", -2, 0)
        end
        -- 글씨 · 아이콘
        local mode, tx, tf = O("icon") or "left", O("text") or "both", O("tfmt") or "left"
        local dur, left = r.me and 2.5 or 1.5, (r.me and 2.5 or 1.5) * (1 - p)
        if tf == "of" then r.time:SetFormattedText("%.1f / %.1f", dur - left, dur)
        elseif tf == "leftof" then r.time:SetFormattedText("%.1f / %.1f", left, dur)
        else r.time:SetFormattedText("%.1f", left) end
        r.name:SetShown(tx == "both" or tx == "name"); r.time:SetShown(tx == "both" or tx == "time")
        r.icon:SetShown(mode ~= "off"); r.iconEdge:SetShown(mode ~= "off")
        local isz = style == "hud" and 15 or (paw and 16 or 18)
        r.icon:SetSize(isz, isz)
        Fsz(r.name, style == "hud" and 12 or 14); Fsz(r.time, style == "hud" and 14 or 18)
        r.icon:ClearAllPoints(); r.name:ClearAllPoints(); r.time:ClearAllPoints(); r.kick:ClearAllPoints()
        if paw then
            local nw = math.min(r.name:GetStringWidth() or 60, 200)
            local total = (mode == "left" and 22 or 0) + nw + (r.kick:IsShown() and 40 or 0) + 38 + (mode == "right" and 22 or 0)
            local x0 = -total / 2
            if mode == "left" then r.icon:SetPoint("LEFT", r.pawBg, "BOTTOM", x0 + 8, -13); x0 = x0 + 22 end
            r.name:SetPoint("LEFT", r.pawBg, "BOTTOM", x0 + 8, -13)
            r.kick:SetPoint("LEFT", r.name, "RIGHT", 6, 0)
            r.time:SetPoint("LEFT", r.name, "RIGHT", 8 + (r.kick:IsShown() and 40 or 0), -1)
            if mode == "right" then r.icon:SetPoint("LEFT", r.time, "RIGHT", 6, 1) end
        elseif style == "hud" then
            if mode == "left" then
                r.icon:SetPoint("TOPLEFT", r.bar, "BOTTOMLEFT", 2, -3); r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
            else
                r.name:SetPoint("TOPLEFT", r.bar, "BOTTOMLEFT", 2, -3)
                if mode == "right" then r.icon:SetPoint("LEFT", r.bar, "RIGHT", 6, 0) end
            end
            r.time:SetPoint("TOPRIGHT", r.bar, "BOTTOMRIGHT", -2, -2)
        else
            if mode == "left" then
                r.icon:SetPoint("BOTTOMLEFT", r.bar, "TOPLEFT", 4, 5); r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
            else
                r.name:SetPoint("BOTTOMLEFT", r.bar, "TOPLEFT", 4, 5)
                if mode == "right" then r.icon:SetPoint("LEFT", r.bar, "RIGHT", 18, 0) end
            end
            r.kick:SetPoint("LEFT", r.name, "RIGHT", 6, 0)
            r.time:SetPoint("BOTTOMRIGHT", r.bar, "TOPRIGHT", -4, 4)
        end
        r.cap:ClearAllPoints(); r.cap:SetPoint("BOTTOMLEFT", fillAnchor, "TOPLEFT", 0, (style == "hud") and 6 or 28)
        -- 지연 꼬리 · 정신 집중 눈금 (내 시전바 예시)
        local showLag = r.me and O("lag")
        r.lag:SetShown(showLag and true or false)
        if showLag then
            r.lag:ClearAllPoints(); r.lag:SetPoint("TOPRIGHT", fillAnchor, "TOPRIGHT", paw and 0 or -2, paw and -6 or -1)
            r.lag:SetPoint("BOTTOMRIGHT", fillAnchor, "BOTTOMRIGHT", paw and 0 or -2, paw and 6 or 1); r.lag:SetWidth(W * 0.12)
        end
        for i, t in ipairs(r.ticks) do
            local on = r.me and O("ticks")
            t:SetShown(on and true or false)
            if on then
                t:ClearAllPoints(); t:SetPoint("TOP", fillAnchor, "TOPLEFT", W * i / 4, 1); t:SetPoint("BOTTOM", fillAnchor, "BOTTOMLEFT", W * i / 4, -1)
            end
        end
    end
    v.k = 0
    v:SetScript("OnUpdate", function(self, el)
        self.k = (self.k + el) % 2.5
        if self.me:IsShown() then Lay(self.me, self.k / 2.5) end
    end)
    function v:Update(m)
        local meOn, enOn = not ns.db.castMineOff, not ns.db.castMineOnly
        self.me:SetShown(meOn); self.en:SetShown(enOn)
        self.me:ClearAllPoints(); self.en:ClearAllPoints()
        local sw, sh = st:GetWidth() or 600, st:GetHeight() or 160
        local wide = sw > sh * 1.6
        if meOn and enOn then
            if wide then
                self:SetSize(720, 110)
                self.en:SetPoint("CENTER", self, "CENTER", -185, -4); self.me:SetPoint("CENTER", self, "CENTER", 185, -4)
            else
                self:SetSize(330, 250)
                self.en:SetPoint("CENTER", self, "CENTER", 0, 58); self.me:SetPoint("CENTER", self, "CENTER", 0, -52)
            end
        else
            self:SetSize(360, 110)
            self.en:SetPoint("CENTER"); self.me:SetPoint("CENTER")
        end
        if sw > 0 and sh > 0 then self:SetScale(math.max(0.5, math.min(1.2, (sw - 16) / self:GetWidth(), (sh - 8) / self:GetHeight()))) end
        if enOn then Lay(self.en, 0.4) end
        if meOn then Lay(self.me, self.k / 2.5) end
    end
    return v
end

-- 주사위 창: 실제 창과 같은 모양 (유리 카드 · 동그란 아이콘 + 시간 링 · 초 · 글자 탭 + 접힌 줄 · 주사위 토끼)
PV.LeelUI_Roll = function(st)
    local W0, PX = 230, 8
    local v = CreateFrame("Frame", nil, st); v:SetSize(W0 + 70, 160); v:SetPoint("CENTER")
    local function Glass(f, h)
        f:SetSize(W0, h)
        local rim = ns.RoundRect(f, 10, { 1, 1, 1 }, "BACKGROUND", -1, -1); rim:SetColor({ 1, 1, 1 }, 0.12)
        local bg = ns.RoundRect(f, 10, { 0.07, 0.047, 0.047 }, "BACKGROUND", 0, 0); bg:SetColor({ 0.07, 0.047, 0.047 }, 0.86)
    end
    local function Icon(f, file, sz, ring)
        local ic = CreateFrame("Frame", nil, f); ic:SetSize(sz, sz)
        local t = ic:CreateTexture(nil, "ARTWORK"); t:SetAllPoints(); t:SetTexture(file); t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local mk = ic:CreateMaskTexture(); mk:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); mk:SetAllPoints(t)
        t:AddMaskTexture(mk)
        if ring then
            local tr = ic:CreateTexture(nil, "BACKGROUND", nil, 1); tr:SetTexture(ns.MEDIA .. "ring_thin")
            tr:SetPoint("TOPLEFT", -4, 4); tr:SetPoint("BOTTOMRIGHT", 4, -4); tr:SetVertexColor(1, 1, 1, 0.12)
            -- 남은 시간 (분홍 링 3/4)
            local cd = CreateFrame("Cooldown", nil, ic, "CooldownFrameTemplate")
            cd:SetPoint("TOPLEFT", -4, 4); cd:SetPoint("BOTTOMRIGHT", 4, -4)
            cd:SetSwipeTexture(ns.MEDIA .. "ring_thin"); cd:SetSwipeColor(1, 0.561, 0.639, 1)
            cd:SetReverse(true); cd:SetDrawEdge(false); cd:SetDrawBling(false)
            if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
            ic.cd = cd
        end
        return ic
    end
    -- 펼친 카드
    local card = CreateFrame("Frame", nil, v); Glass(card, 92); card:SetPoint("TOPLEFT", 0, 0)
    local ic = Icon(card, "Interface\\Icons\\INV_Belt_04", 28, true); ic:SetPoint("TOPLEFT", PX, -6)
    v.ic = ic
    local nm = ns.Font(card, 12, { 0.12, 1, 0 }); nm:SetPoint("TOPLEFT", ic, "TOPRIGHT", 8, 1); nm:SetText("두꺼운 가죽 허리띠")
    v.adv = ns.Font(card, 10, { 1, 0.84, 0.35 }); v.adv:SetPoint("TOPLEFT", nm, "BOTTOMLEFT", 0, -3); v.adv:SetText("● 지금 허리 장비가 더 좋아요")
    v.secs = card:CreateFontString(nil, "OVERLAY"); v.secs:SetFont(ns.NUM or ns.FONT, 20, ""); v.secs:SetPoint("TOPRIGHT", -PX, -6)
    v.secs:SetText("29"); v.secs:SetTextColor(1, 0.84, 0.88)
    local seg = CreateFrame("Frame", nil, card); seg:SetHeight(26)
    seg:SetPoint("BOTTOMLEFT", PX, 10); seg:SetPoint("BOTTOMRIGHT", -PX, 10)
    local sl = card:CreateTexture(nil, "BORDER"); sl:SetTexture(ns.WHITE); sl:SetHeight(1); sl:SetVertexColor(1, 1, 1, 0.12)
    sl:SetPoint("BOTTOMLEFT", seg, "TOPLEFT", -2, 1); sl:SetPoint("BOTTOMRIGHT", seg, "TOPRIGHT", 2, 1)
    v.tabs = {}
    local tw = (W0 - PX * 2) / 3
    for i, lab in ipairs({ "입찰", "차비", "포기" }) do
        local t = CreateFrame("Frame", nil, seg); t:SetSize(tw, 26); t:SetPoint("LEFT", (i - 1) * tw, 0)
        t.fs = ns.Font(t, 12); t.fs:SetShadowColor(0, 0, 0, 0); t.fs:SetPoint("CENTER", 0, 1); t.lab = lab
        t.ul = t:CreateTexture(nil, "ARTWORK"); t.ul:SetTexture(ns.WHITE); t.ul:SetHeight(2.5)
        t.ul:SetPoint("BOTTOMLEFT", 16, 0); t.ul:SetPoint("BOTTOMRIGHT", -16, 0); t.ul:SetVertexColor(1, 0.82, 0.35, 1)
        v.tabs[i] = t
    end
    local bar = CreateFrame("StatusBar", nil, card); bar:SetStatusBarTexture(ns.WHITE); bar:SetMinMaxValues(0, 1); bar:SetValue(0.72)
    bar:SetPoint("BOTTOMLEFT", PX, 4); bar:SetPoint("BOTTOMRIGHT", -PX, 4); bar:SetHeight(3); bar:SetStatusBarColor(1, 0.561, 0.639)
    local bb = bar:CreateTexture(nil, "BACKGROUND"); bb:SetAllPoints(); bb:SetColorTexture(1, 1, 1, 0.16)
    -- 접힌 줄 둘
    v.pills = {}
    local PILLS = { { "Interface\\Icons\\INV_Misc_Gear_01", "네트 페이글의 다나이 FC-5", { 0.12, 1, 0 }, "내 템 아님", { 0.72, 0.65, 0.63 } },
                    { "Interface\\Icons\\INV_Shoulder_02", "무두질한 어깨보호대", { 0.12, 1, 0 }, "차비 ★", { 1, 0.82, 0.35 } } }
    for i, d in ipairs(PILLS) do
        local p = CreateFrame("Frame", nil, v); Glass(p, 30); p:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -4 - (i - 1) * 34)
        local pi = Icon(p, d[1], 20, false); pi:SetPoint("LEFT", PX, 0)
        local ch = p:CreateTexture(nil, "ARTWORK"); ch:SetTexture(ns.MEDIA .. "roll_chev"); ch:SetSize(10, 10); ch:SetPoint("RIGHT", -PX, 0)
        ch:SetVertexColor(0.72, 0.65, 0.63)
        local hn = ns.Font(p, 10.5, d[5]); hn:SetPoint("RIGHT", ch, "LEFT", -6, 0); hn:SetText(d[4])
        local pn = ns.Font(p, 11.5, d[3]); pn:SetPoint("LEFT", pi, "RIGHT", 8, 0); pn:SetPoint("RIGHT", hn, "LEFT", -6, 0)
        pn:SetJustifyH("LEFT"); pn:SetWordWrap(false); pn:SetText(d[2])
        p.hint = hn
        v.pills[i] = p
    end
    -- 주사위 토끼 (유리 주사위 + 굴릴 수)
    local bun = CreateFrame("Frame", nil, v); bun:SetSize(50, 50); bun:SetPoint("TOPLEFT", card, "TOPRIGHT", 10, 4)
    local au = bun:CreateTexture(nil, "BACKGROUND"); au:SetTexture(ns.MEDIA .. "soft_glow"); au:SetBlendMode("ADD")
    au:SetPoint("CENTER", 0, -2); au:SetSize(80, 80); au:SetVertexColor(1, 0.561, 0.639, 0.25)
    local bi = Tex(bun, "roll_badge_dice", 50, 50, "ARTWORK"); bi:SetPoint("CENTER")
    local cnt = CreateFrame("Frame", nil, bun); cnt:SetSize(20, 20); cnt:SetPoint("CENTER", bun, "TOPRIGHT", -6, -6)
    local cr = cnt:CreateTexture(nil, "ARTWORK"); cr:SetTexture(ns.MEDIA .. "circle"); cr:SetPoint("CENTER"); cr:SetSize(24, 24); cr:SetVertexColor(0.165, 0.122, 0.114)
    local cdt = cnt:CreateTexture(nil, "ARTWORK", nil, 1); cdt:SetTexture(ns.MEDIA .. "circle"); cdt:SetAllPoints(); cdt:SetVertexColor(1, 0.353, 0.431)
    local cfs = cnt:CreateFontString(nil, "OVERLAY"); cfs:SetFont(ns.NUM or ns.FONT, 14, ""); cfs:SetPoint("CENTER"); cfs:SetText("3")
    v.bun = bun
    function v:Update(m)
        local adv = Val(m, "토끼 추천") ~= false
        self.adv:SetShown(adv)
        for i, t in ipairs(self.tabs) do
            local rec = adv and i == 2
            t.fs:SetText(t.lab .. (rec and " ★" or ""))
            if rec then t.fs:SetTextColor(1, 0.82, 0.35) else local k = (i == 3) and 0.45 or 0.72; t.fs:SetTextColor(k, k, k) end
            t.ul:SetShown(rec)
        end
        self.pills[2].hint:SetText(adv and "차비 ★" or "")
        if self.ic.cd and not self.cdSet then self.cdSet = true; self.ic.cd:SetCooldown(GetTime() - 15, 60) end
        local sc = (Val(m, "주사위 창 · 토끼 단추 크기") or 100) / 100
        local fit = math.min((self:GetParent():GetWidth() - 20) / self:GetWidth(), (self:GetParent():GetHeight() - 10) / self:GetHeight())
        self:SetScale(math.max(0.5, math.min(fit, 1.15, sc)))
    end
    local spot = XP.Spot(st)
    XP.HLREG.LeelUI_Roll = { function(k, text)
        if not k or not v:IsVisible() then spot.Off() return end
        if k == "rec" then spot.Show(v.adv:IsShown() and v.adv or card, v.tabs[2], text)
        elseif k == "bun" then spot.Show(v.bun, v.bun, text)
        elseif k == "card" then spot.Show(card, card, text)
        else spot.Show(card, v.bun, text) end
    end, function(x) spot.Alpha(x) end }
    return v
end

-- 르엘 가방: 칸 수 · 크기 · 등급 테
PV.LeelUI_Bags = function(st)
    local v = CreateFrame("Frame", nil, st); v:SetSize(10, 10); v:SetPoint("CENTER")
    ns.RoundPlate(v, 12, { 0.13, 0.1, 0.09, 0.97 }, { 0.949, 0.702, 0.761, 0.6 })
    v.slots = {}
    local q = { 4, 3, 2, 2, 1, 1, 0, 1, 2, 1, 3, 1, 1, 0, 1, 1, 2, 1, 1, 1, 2, 0, 1, 1, 3, 1, 1, 1, 0, 1, 1, 2 }
    local QC = { [0] = { 0.6, 0.6, 0.6 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 } }
    for i = 1, 32 do
        local s = CreateFrame("Frame", nil, v); s:SetSize(28, 28)
        s.e = ns.RoundRect(s, 7, QC[q[i]], "BACKGROUND", 0, -1)
        ns.RoundRect(s, 6, { 0.2, 0.15, 0.14 }, "BACKGROUND", 1, 1)
        s.q = q[i]
        v.slots[i] = s
    end
    function v:Update(m)
        local cols = Val(m, "한 줄 칸 수") or 12
        local n = cols * 3
        for i, s in ipairs(self.slots) do
            if i <= n then
                s:ClearAllPoints(); s:SetPoint("TOPLEFT", 10 + ((i - 1) % cols) * 31, -10 - math.floor((i - 1) / cols) * 31)
                s.e:SetColor(s.q >= 2 and ({ [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 } })[s.q] or { 0.3, 0.24, 0.22 }, 1)
                s:Show()
            else s:Hide() end
        end
        self:SetSize(20 + cols * 31 - 3, 20 + 3 * 31 - 3)
        local fit = math.min((self:GetParent():GetWidth() - 30) / self:GetWidth(), (self:GetParent():GetHeight() - 10) / self:GetHeight())
        self:SetScale(math.max(0.4, math.min(1, fit) * ((Val(m, "가방 창 크기") or 100) / 100)))
    end
    local spot = XP.Spot(st)
    XP.HLREG.LeelUI_Bags = { function(k, text)
        if not k or not v:IsVisible() then spot.Off() return end
        if k == "new" then spot.Show(v.slots[1], v.slots[3], text) else spot.Show(v, v, text) end
    end, function(x) spot.Alpha(x) end }
    return v
end

-- 글씨체: 고른 글꼴로 예시
PV.LeelUI_Font = function(st)
    -- 게임 장면 네 곳 (퀘스트 글 · 머리 위 이름 · 채팅 · 피해 숫자) 을 진짜로 고른 글꼴로
    local v = CreateFrame("Frame", nil, st); v:SetSize(640, 150); v:SetPoint("CENTER")
    local function Zone(x, w, cap)
        local z = CreateFrame("Frame", nil, v); z:SetSize(w, 124); z:SetPoint("TOPLEFT", v, "TOPLEFT", x, 0)
        local c = ns.Font(v, 10, { 0.66, 0.58, 0.56 }); c:SetPoint("TOP", z, "BOTTOM", 0, -6); c:SetText(cap)
        z.cap = c
        return z
    end
    local function FS(p, col)
        local fs = ns.LWrap(p:CreateFontString(nil, "OVERLAY")); fs:SetFont(ns.FONT, 12, "")
        fs:SetTextColor(col[1], col[2], col[3]); fs:SetShadowColor(0, 0, 0, 0.85); fs:SetShadowOffset(1, -1)
        return fs
    end
    -- ① 퀘스트 글 (기본 글씨)
    local q = Zone(0, 190, "기본 글씨")
    q.fill, q.edge = ns.RoundPlate(q, 12, { 0.114, 0.082, 0.078, 0.95 }, { 0.949, 0.702, 0.761, 0.3 })
    q.t = FS(q, { 1, 0.82, 0.35 }); q.t:SetPoint("TOPLEFT", 12, -12); q.t:SetText("늑대 가죽 모으기")
    q.b = FS(q, { 0.93, 0.88, 0.86 }); q.b:SetPoint("TOPLEFT", q.t, "BOTTOMLEFT", 0, -8); q.b:SetWidth(166); q.b:SetJustifyH("LEFT")
    q.b:SetText("골짜기 늑대의 가죽 10장을 모아 오게. 겨울이 오기 전에 말일세.")
    q.o = FS(q, { 0.75, 0.7, 0.68 }); q.o:SetPoint("BOTTOMLEFT", 12, 12); q.o:SetText("- 늑대 가죽: 3/10")
    -- ② 머리 위 이름 (이름/제목)
    local n = Zone(204, 150, "이름/제목")
    n.ttl = FS(n, { 1, 0.82, 0.35 }); n.ttl:SetPoint("TOP", 0, -14); n.ttl:SetText("<토끼 길드>")
    n.nm = FS(n, { 1, 0.42, 0.42 }); n.nm:SetPoint("TOP", n.ttl, "BOTTOM", 0, -4); n.nm:SetText("붉은갈기 노움")
    n.bar = CreateFrame("StatusBar", nil, n); n.bar:SetStatusBarTexture(ns.WHITE); n.bar:SetSize(120, 8); n.bar:SetPoint("TOP", n.nm, "BOTTOM", 0, -6)
    n.bar:SetMinMaxValues(0, 100); n.bar:SetValue(70); n.bar:SetStatusBarColor(0.72, 0.12, 0.21, 1)
    local nb = n.bar:CreateTexture(nil, "BACKGROUND"); nb:SetAllPoints(); nb:SetColorTexture(0.11, 0.08, 0.075, 0.9)
    n.me = FS(n, { 0.55, 0.85, 1 }); n.me:SetPoint("TOP", n.bar, "BOTTOM", 0, -18); n.me:SetText(UnitName("player") or "르엘")
    -- ③ 채팅 (채팅)
    local c = Zone(368, 150, "채팅")
    c.l1 = FS(c, { 0.56, 0.86, 0.61 }); c.l1:SetPoint("TOPLEFT", 4, -14); c.l1:SetText("[길드] [당근]: 8시 출발~")
    c.l2 = FS(c, { 0.62, 0.74, 0.96 }); c.l2:SetPoint("TOPLEFT", c.l1, "BOTTOMLEFT", 0, -6); c.l2:SetText("[파티] [나]: 넵 준비 완료!")
    c.bub = CreateFrame("Frame", nil, c); c.bub:SetSize(130, 34); c.bub:SetPoint("BOTTOM", c, "BOTTOM", 0, 10)
    ns.RoundPlate(c.bub, 11, { 0.96, 0.94, 0.92, 0.96 }, { 0.6, 0.55, 0.5, 0.5 })
    c.bt = ns.LWrap(c.bub:CreateFontString(nil, "OVERLAY")); c.bt:SetFont(ns.FONT, 12, ""); c.bt:SetTextColor(0.15, 0.11, 0.1); c.bt:SetPoint("CENTER"); c.bt:SetText("안녕하세요!")
    -- ④ 피해 숫자 (숫자)
    local d = Zone(532, 108, "숫자")
    d.big = FS(d, { 1, 0.84, 0.35 }); d.big:SetPoint("CENTER", 0, 14); d.big:SetText("1,284")
    d.sm = FS(d, { 1, 1, 1 }); d.sm:SetPoint("CENTER", -14, -22); d.sm:SetText("342")
    d.heal = FS(d, { 0.45, 0.95, 0.5 }); d.heal:SetPoint("CENTER", 22, -40); d.heal:SetText("+96")
    local function Set(fs, slot, size, flags)
        local f = (ns.FontPreviewFile and ns.FontPreviewFile(slot)) or ns.FONT
        if not (f and fs:SetFont(f, size, flags or "")) then fs:SetFont(ns.FONT, size, flags or "") end
    end
    function v:Update()
        local db = ns.db.font or {}
        local k = tonumber(db.size) or 1
        local nk = tonumber(db.nameK) or 1
        local ol = (db.outline == "thick" and "THICKOUTLINE") or (db.outline == "thin" and "OUTLINE") or ""
        local dk = ((ns.FontOpt and ns.FontOpt("dmg")) or 100) / 100
        Set(q.t, "body", 14 * k); Set(q.b, "body", 12 * k); Set(q.o, "body", 11.5 * k)
        Set(n.ttl, "name", 11 * nk, ol); Set(n.nm, "name", 14 * nk, ol); Set(n.me, "name", 13 * nk, ol)
        Set(c.l1, "chat", 12 * k); Set(c.l2, "chat", 12 * k); Set(c.bt, "chat", 12 * k)
        Set(d.big, "num", math.min(40, 24 * dk), "OUTLINE"); Set(d.sm, "num", math.min(30, 16 * dk), "OUTLINE"); Set(d.heal, "num", math.min(26, 14 * dk), "OUTLINE")
        local sw, sh = st:GetWidth() or 640, st:GetHeight() or 160
        self:SetScale(math.max(0.6, math.min(1.25, (sw - 16) / 640, (sh - 6) / 156)))
    end
    v.q, v.n, v.c, v.d = q, n, c, d
    local spot = XP.Spot(st)
    function ns.FontPvHLAlpha(a) spot.Alpha(a) end
    function ns.FontPvHL(key, text)
        if not key or not v:IsVisible() then spot.Off() return end
        if key == "body" then spot.Show(q, q, text)
        elseif key == "name" then spot.Show(n, n, text)
        elseif key == "chat" then spot.Show(c, c, text)
        elseif key == "num" then spot.Show(d, d, text)
        elseif key == "size" then spot.Show(q, c, text)
        else spot.Show(q, d, text) end
    end
    return v
end

-- Leel Quest: 진짜 따라가기 창 모양 (머리 · 새 지역 띠 · 지금 퀘 당근 링 · 반납 상자 · 그 밖의 퀘) + 지도 길
PV.ForgLeveling = function(st)
    local FLM = "Interface\\AddOns\\ForgLeveling\\media\\"
    local YEL, DIM, CARROT = { 0.945, 0.851, 0.541 }, { 0.72, 0.64, 0.61 }, { 1, 0.6, 0.3 }
    local v = CreateFrame("Frame", nil, st); v:SetSize(300, 200); v:SetPoint("CENTER")
    local function G() return ForgLevelingDB or {} end
    local trk = CreateFrame("Frame", nil, v); trk:SetSize(300, 200); trk:SetPoint("TOPLEFT")
    -- 머리
    local head = CreateFrame("Frame", nil, trk); head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT"); head:SetHeight(28)
    local bun = CreateFrame("Frame", nil, head); bun:SetSize(26, 26); bun:SetPoint("LEFT")
    local b1 = bun:CreateTexture(nil, "BORDER"); b1:SetTexture(ns.MEDIA .. "circle"); b1:SetAllPoints(); b1:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    local b2 = bun:CreateTexture(nil, "ARTWORK"); b2:SetTexture(ns.MEDIA .. "bunny"); b2:SetAllPoints()
    local ttl = ns.Font(head, 17, C.acc); ttl:SetPoint("LEFT", bun, "RIGHT", 7, 0); ttl:SetText("Leel Quest")
    local cnt = ns.Font(head, 12, C.tx2); cnt:SetPoint("LEFT", ttl, "RIGHT", 8, -1); cnt:SetText("3 / 11")
    local key = Box(head, 18, 18, 4, { 0.2, 0.15, 0.14 }); key:SetPoint("RIGHT", 0, 0)
    local kt = ns.Font(key, 11, C.accHi); kt:SetPoint("CENTER", 0, 0); kt:SetText("L")
    local ln = trk:CreateTexture(nil, "ARTWORK"); ln:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.35); ln:SetHeight(1)
    ln:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2); ln:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, -2)
    -- 새 지역 띠
    local band = CreateFrame("Frame", nil, trk); band:SetSize(300, 24)
    ns.RoundPlate(band, 9, { 0.114, 0.082, 0.078, 0.96 }, { C.acc[1], C.acc[2], C.acc[3], 0.75 })
    local bt = ns.Font(band, 12, C.accHi); bt:SetPoint("LEFT", 9, 0); bt:SetText("엘윈 숲")
    local bs = ns.Font(band, 11.5, C.tx); bs:SetPoint("LEFT", bt, "RIGHT", 7, 0); bs:SetText("여기서 할 퀘 6개")
    local bb = Box(band, 44, 16, 8, C.acc); bb:SetPoint("RIGHT", -5, 0)
    local bbt = ns.Font(bb, 10.5, C.ink); bbt:SetShadowColor(0, 0, 0, 0); bbt:SetPoint("CENTER"); bbt:SetText("고르기")
    -- 근처 반납 노란 띠 (길 앞으로를 끄면)
    local near = CreateFrame("Frame", nil, trk); near:SetSize(300, 24)
    ns.RoundPlate(near, 9, { 0.235, 0.172, 0.078, 0.95 }, { YEL[1], YEL[2], YEL[3], 0.8 })
    local nt = ns.Font(near, 12, YEL); nt:SetPoint("LEFT", 9, 0); nt:SetText("여기서 반납 2개 · 토끼상인")
    local nd = ns.Font(near, 12, C.tx); nd:SetPoint("RIGHT", -9, 0); nd:SetText("38m")
    -- 줄
    local function Disc(p, n, col)
        local f = CreateFrame("Frame", nil, p); f:SetSize(20, 20)
        local e = f:CreateTexture(nil, "BORDER"); e:SetTexture(ns.MEDIA .. "circle"); e:SetAllPoints(); e:SetVertexColor(0, 0, 0, 0.8)
        local d = f:CreateTexture(nil, "ARTWORK"); d:SetTexture(ns.MEDIA .. "circle"); d:SetPoint("TOPLEFT", 1.5, -1.5); d:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
        d:SetVertexColor(col[1], col[2], col[3], 1)
        local t = ns.Num(f, 13, C.ink); t:SetPoint("CENTER", 0, 0); t:SetShadowColor(0, 0, 0, 0); t:SetText(n)
        return f
    end
    local function Chip(p, text, bg, fg)
        local c = Box(p, 40, 16, 8, bg); local t = ns.Font(c, 10.5, fg); t:SetPoint("CENTER"); t:SetShadowColor(0, 0, 0, 0); t:SetText(text)
        c:SetWidth(t:GetStringWidth() + 14)
        return c
    end
    -- ① 지금 퀘 (당근 링 + 거리 + 목표)
    local r1 = CreateFrame("Frame", nil, trk); r1:SetSize(300, 38)
    local g1 = r1:CreateTexture(nil, "BACKGROUND"); g1:SetTexture(ns.MEDIA .. "circle"); g1:SetSize(28, 28); g1:SetPoint("CENTER", r1, "TOPLEFT", 10, -10); g1:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.35)
    local d1 = Disc(r1, 3, C.acc); d1:SetPoint("TOPLEFT")
    local t1 = ns.Font(r1, 15, C.tx); t1:SetPoint("TOPLEFT", 28, -1); t1:SetText("늑대 사냥")
    local c1 = Chip(r1, "보통", { 0.29, 0.247, 0.133 }, { 0.945, 0.851, 0.541 }); c1:SetPoint("LEFT", t1, "RIGHT", 6, 0)
    local o1 = ns.Font(r1, 12, DIM); o1:SetPoint("TOPLEFT", t1, "BOTTOMLEFT", 0, -4); o1:SetText("- 늑대 가죽: 3/10")
    -- 파티원 얼굴 + 진행 고리
    local faces = CreateFrame("Frame", nil, r1); faces:SetSize(44, 20); faces:SetPoint("LEFT", c1, "RIGHT", 6, 0)
    local arcs = {}
    for i, f in ipairs({ { "당", { 0.25, 0.78, 0.92 }, 0.38 }, { "토", { 0.96, 0.55, 0.73 }, 0.62 } }) do
        local fc = CreateFrame("Frame", nil, faces); fc:SetSize(20, 20); fc:SetPoint("LEFT", (i - 1) * 22, 0)
        local tr = fc:CreateTexture(nil, "BACKGROUND"); tr:SetTexture(FLM .. "nav_ring"); tr:SetAllPoints(); tr:SetVertexColor(0.227, 0.169, 0.157, 1)
        local hf = CreateFrame("Frame", nil, fc); hf:SetPoint("TOPLEFT", fc, "TOP"); hf:SetPoint("BOTTOMRIGHT"); pcall(hf.SetClipsChildren, hf, true); arcs[#arcs + 1] = hf; arcs[#arcs + 1] = tr
        local ht = hf:CreateTexture(nil, "ARTWORK"); ht:SetTexture(FLM .. "nav_half"); ht:SetSize(20, 20); ht:SetPoint("CENTER", fc); ht:SetVertexColor(0.56, 0.91, 0.6, 1)
        pcall(ht.SetRotation, ht, -math.min(0.5, f[3]) * math.pi * 2)
        if f[3] > 0.5 then
            local hl = CreateFrame("Frame", nil, fc); hl:SetPoint("TOPLEFT"); hl:SetPoint("BOTTOMRIGHT", fc, "BOTTOM"); pcall(hl.SetClipsChildren, hl, true); arcs[#arcs + 1] = hl
            local lt = hl:CreateTexture(nil, "ARTWORK"); lt:SetTexture(FLM .. "nav_half"); lt:SetSize(20, 20); lt:SetPoint("CENTER", fc); lt:SetVertexColor(0.56, 0.91, 0.6, 1)
            pcall(lt.SetRotation, lt, math.pi - (f[3] - 0.5) * math.pi * 2); pcall(ht.SetRotation, ht, -math.pi)
        end
        local inner = CreateFrame("Frame", nil, fc); inner:SetAllPoints(); inner:SetFrameLevel(fc:GetFrameLevel() + 5)
        local d = inner:CreateTexture(nil, "ARTWORK"); d:SetTexture(ns.MEDIA .. "circle"); d:SetPoint("TOPLEFT", 3, -3); d:SetPoint("BOTTOMRIGHT", -3, 3); d:SetVertexColor(f[2][1], f[2][2], f[2][3], 1)
        local t = ns.Font(inner, 9.5, C.ink); t:SetShadowColor(0, 0, 0, 0); t:SetPoint("CENTER"); t:SetText(f[1])
    end
    local ring = CreateFrame("Frame", nil, r1); ring:SetSize(28, 28); ring:SetPoint("TOPRIGHT", r1, "TOPRIGHT", -44, 4)
    local rt = ring:CreateTexture(nil, "BACKGROUND"); rt:SetTexture(FLM .. "nav_ring"); rt:SetAllPoints(); rt:SetVertexColor(0.227, 0.169, 0.157, 1)
    local rc = ring:CreateTexture(nil, "ARTWORK"); rc:SetTexture(FLM .. "nav_carrot"); rc:SetAllPoints(); pcall(rc.SetRotation, rc, -0.7)
    local dist = ns.Num(r1, 16, { 1, 0.945, 0.957 }); dist:SetPoint("LEFT", ring, "RIGHT", 5, 0); dist:SetText("142m")
    -- ② 반납 상자
    local r2 = CreateFrame("Frame", nil, trk); r2:SetSize(300, 22)
    local bx = r2:CreateTexture(nil, "BACKGROUND"); bx:SetPoint("TOPLEFT", -6, 2); bx:SetPoint("BOTTOMRIGHT", 0, -1); bx:SetColorTexture(0.235, 0.172, 0.078, 0.7)
    local bxb = r2:CreateTexture(nil, "BORDER"); bxb:SetColorTexture(YEL[1], YEL[2], YEL[3], 1); bxb:SetWidth(3); bxb:SetPoint("TOPLEFT", bx); bxb:SetPoint("BOTTOMLEFT", bx)
    local q2 = r2:CreateTexture(nil, "ARTWORK"); q2:SetTexture(ns.MEDIA .. "q_turnin"); q2:SetSize(20, 20); q2:SetPoint("TOPLEFT")
    local t2 = ns.Font(r2, 15, YEL); t2:SetPoint("TOPLEFT", 28, -1); t2:SetText("토끼상인에게 반납 2")
    -- ②' 상자 대신 낱개 (한 상자로를 끄면)
    local r2b = CreateFrame("Frame", nil, trk); r2b:SetSize(300, 22)
    local q2b = r2b:CreateTexture(nil, "ARTWORK"); q2b:SetTexture(ns.MEDIA .. "q_turnin"); q2b:SetSize(20, 20); q2b:SetPoint("TOPLEFT")
    local t2b = ns.Font(r2b, 15, YEL); t2b:SetPoint("TOPLEFT", 28, -1); t2b:SetText("수상한 발자국")
    local st2 = r2b:CreateTexture(nil, "OVERLAY"); st2:SetTexture(FLM .. "stamp"); st2:SetSize(20, 20); st2:SetPoint("LEFT", t2b, "RIGHT", 6, 0); pcall(st2.SetRotation, st2, -0.21)
    -- ③ 다음 퀘
    local r3 = CreateFrame("Frame", nil, trk); r3:SetSize(300, 22)
    local d3 = Disc(r3, 4, C.acc); d3:SetPoint("TOPLEFT")
    local t3 = ns.Font(r3, 15, C.tx); t3:SetPoint("TOPLEFT", 28, -1); t3:SetText("코볼트 촛불 찾기")
    local c3 = Chip(r3, "쉬움", { 0.184, 0.29, 0.173 }, { 0.75, 0.9, 0.706 }); c3:SetPoint("LEFT", t3, "RIGHT", 6, 0)
    -- ④ 그 밖의 퀘
    local oh = CreateFrame("Frame", nil, trk); oh:SetSize(300, 18)
    local ohf = ns.Font(oh, 11, DIM); ohf:SetPoint("LEFT", 2, 0)
    local ohl = oh:CreateTexture(nil, "ARTWORK"); ohl:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.18); ohl:SetHeight(1); ohl:SetPoint("LEFT", ohf, "RIGHT", 8, 0); ohl:SetPoint("RIGHT")
    local o2 = ns.Font(trk, 12, DIM); o2:SetJustifyH("LEFT"); o2:SetText("· 붉은 두건단 두건   · 정예 |cff8a7a76호그|r")
    -- 지도 (길 그리기)
    local map = Box(v, 200, 180, 14, { 0.16, 0.2, 0.14 }); map:SetPoint("TOPLEFT", trk, "TOPRIGHT", 30, -6)
    local mapCap = ns.Font(v, 10, { 0.66, 0.58, 0.56 }); mapCap:SetPoint("TOP", map, "BOTTOM", 0, -6); mapCap:SetText("M 지도 · 미니맵")
    local PTS = { { 40, -130, "me" }, { 92, -96, 3 }, { 140, -60, "?" }, { 166, -126, 4 } }
    local dots, nums = {}, {}
    for i = 1, #PTS - 1 do
        local a, b = PTS[i], PTS[i + 1]
        for k = 1, 7 do
            local t = map:CreateTexture(nil, "ARTWORK"); t:SetTexture(ns.MEDIA .. "circle"); t:SetSize(4, 4)
            t:SetPoint("CENTER", map, "TOPLEFT", a[1] + (b[1] - a[1]) * k / 8, a[2] + (b[2] - a[2]) * k / 8)
            t:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.9); dots[#dots + 1] = t
        end
    end
    for i, p in ipairs(PTS) do
        if p[3] == "me" then
            local t = map:CreateTexture(nil, "OVERLAY"); t:SetTexture(ns.MEDIA .. "np_arrow"); t:SetSize(18, 18); t:SetPoint("CENTER", map, "TOPLEFT", p[1], p[2])
        elseif p[3] == "?" then
            local t = map:CreateTexture(nil, "OVERLAY"); t:SetTexture(ns.MEDIA .. "q_turnin"); t:SetSize(20, 20); t:SetPoint("CENTER", map, "TOPLEFT", p[1], p[2]); nums[#nums + 1] = t
        else
            local d = Disc(map, p[3], C.acc); d:SetPoint("CENTER", map, "TOPLEFT", p[1], p[2]); nums[#nums + 1] = d
        end
    end
    -- 블리자드 기본 퀘스트 목록 (미니맵 아래 · 바탕 없이 노란 제목 + 흰 목표)
    local function Line(p, t, size, col, x, y)
        local fs = ns.LWrap(p:CreateFontString(nil, "OVERLAY")); fs:SetFont(STANDARD_TEXT_FONT, size, ""); fs:SetShadowColor(0, 0, 0, 1); fs:SetShadowOffset(1, -1)
        fs:SetTextColor(col[1], col[2], col[3]); fs:SetText(t); fs:SetJustifyH("LEFT"); fs:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
        return fs
    end
    -- 블리자드 기본: 바탕 없이 노란 제목 + 흰 목표 (게임 글꼴)
    local bl = CreateFrame("Frame", nil, st); bl:SetSize(230, 136); bl:SetPoint("CENTER")
    do
        local Y, W = { 1, 0.82, 0 }, { 0.92, 0.92, 0.92 }
        local y = -6
        for _, q in ipairs({ { "늑대 가죽 모으기", "- 늑대 가죽: 3/10" }, { "코볼트 촛불 찾기", "- 큰 촛불: 0/8" }, { "수상한 발자국", "- (완료)" } }) do
            Line(bl, q[1], 15, Y, 8, y); Line(bl, q[2], 13, W, 18, y - 20); y = y - 44
        end
    end
    -- Questie 추적창: 옅은 검은 판 · 머리 · 지역 · [레벨] 제목 (레벨 색) · 진행 색 목표
    local qs = CreateFrame("Frame", nil, st); qs:SetSize(320, 160); qs:SetPoint("CENTER")
    do
        local bg = qs:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0.5)
        local hd = qs:CreateTexture(nil, "BORDER"); hd:SetPoint("TOPLEFT"); hd:SetPoint("TOPRIGHT"); hd:SetHeight(24); hd:SetColorTexture(0, 0, 0, 0.45)
        Line(qs, "Questie Tracker: 3/20", 13, { 1, 0.82, 0 }, 10, -6)
        Line(qs, "엘윈 숲", 13, { 0.8, 0.8, 0.8 }, 10, -32)
        local y = -52
        for _, q in ipairs({ { "[10] 늑대 가죽 모으기", { 1, 1, 0 }, "늑대 가죽: 3/10", { 0.95, 0.6, 0.2 } },
                             { "[8] 코볼트 촛불 찾기", { 0.25, 0.75, 0.25 }, "큰 촛불: 0/8", { 0.9, 0.25, 0.2 } },
                             { "[11] 수상한 발자국", { 1, 1, 0 }, "완료 · 보고하기", { 0.3, 0.9, 0.3 } } }) do
            Line(qs, q[1], 14, q[2], 18, y); Line(qs, q[3], 12.5, q[4], 32, y - 18); y = y - 36
        end
    end
    local function Fit(f)
        local sw, sh = st:GetWidth() or 600, st:GetHeight() or 156
        f:SetScale(math.max(0.5, math.min(1.25, (sw - 16) / f:GetWidth(), (sh - 10) / f:GetHeight())))
    end
    local function Mode(mm)
        mm = mm or "guide"
        trk:SetShown(mm == "guide"); map:Hide(); mapCap:Hide()   -- 추적창만 보여줘요
        bl:SetShown(mm == "blizz"); qs:SetShown(mm == "questie")
        if mm == "blizz" then Fit(bl) elseif mm == "questie" then Fit(qs) end
    end
    v:HookScript("OnHide", function() bl:Hide(); qs:Hide() end)   -- 다른 탭으로 가면 같이 숨겨요 (둘은 미리 보기 판에 바로 붙어 있어서)
    local function CurMode() return (ns.QuestTrackerMode and ns.QuestTrackerMode()) or "guide" end
    local listCol = Box(map, 50, 168, 8, { 0.11, 0.08, 0.075 }, 0.9); listCol:SetPoint("RIGHT", map, "RIGHT", -6, 0)
    local lct = ns.Font(listCol, 9.5, DIM); lct:SetPoint("TOP", 0, -8); lct:SetText("퀘스트\n목록")
    function v:Update()
        local d = G()
        local y = -34
        local function Put(f, h, x) f:ClearAllPoints(); f:SetPoint("TOPLEFT", trk, "TOPLEFT", x or 0, y); f:Show(); y = y - h end
        if d.zoneToast ~= false then Put(band, 30) else band:Hide() end
        if d.nearTurnin ~= false and d.autoNear == false then Put(near, 30) else near:Hide() end
        local nearFront = d.nearTurnin ~= false and d.autoNear ~= false
        local group = d.groupTurnin ~= false
        local function Turn() if group then r2b:Hide(); Put(r2, 26) else r2:Hide(); Put(r2b, 26) end end
        if nearFront then Turn() end
        Put(r1, 42)
        if not nearFront then Turn() end
        Put(r3, 28)
        st2:SetShown(not d.fxOff)
        ohf:SetText(("그 밖의 퀘 2  |cff8a7a76%s|r"):format(d.trkOtherFold and "· 펴기" or "· 접기"))
        Put(oh, 20)
        if d.trkOtherFold then o2:Hide() else Put(o2, 18, 2) end
        trk:SetHeight(-y)
        key:SetShown(d.lKey ~= false)
        faces:SetShown(d.partyFaces ~= false)
        for _, a in ipairs(arcs) do a:SetShown(d.partyRing ~= false) end
        local lines = d.mapLines ~= false
        for _, t in ipairs(dots) do t:SetShown(lines) end
        for _, t in ipairs(nums) do t:SetShown(lines) end
        listCol:SetShown(d.mapOnly == false)
        v:SetHeight(-y)
        local sk = (tonumber(d.trkScale) or 1)
        trk:SetScale(sk)
        Mode(CurMode())
        local sw, sh = st:GetWidth() or 640, st:GetHeight() or 160
        self:SetScale(math.max(0.45, math.min(1.4, (sw - 16) / (300 * sk + 20), (sh - 6) / math.max(200, -y * sk))))
    end
    local spot = XP.Spot(st)
    function ns.LQPvHLAlpha(a) spot.Alpha(a) end
    function ns.LQPvHL(k, text)
        if not v:IsVisible() then spot.Off() return end
        if not k then spot.Off(); Mode(CurMode()) return end
        -- 목록 고르기 줄: 그 목록 모양을 잠깐 보여줘요
        if k:sub(1, 2) == "m_" then
            local mm = k:sub(3); Mode(mm)
            if mm == "guide" then spot.Show(trk, trk, text) elseif mm == "blizz" then spot.Show(bl, bl, text) else spot.Show(qs, qs, text) end
            return
        end
        Mode(CurMode())
        local function S(a, b) if a and a:IsVisible() then spot.Show(a, b or a, text) else spot.Off() end end
        if k == "head" then S(head)
        elseif k == "zone" then if band:IsShown() then S(band) else S(head) end
        elseif k == "near" then if near:IsShown() then S(near) elseif r2:IsShown() then S(r2) else S(r2b) end
        elseif k == "box" then if r2:IsShown() then S(r2) else S(r2b) end
        elseif k == "stamp" then S(r2b:IsShown() and r2b or r2)
        elseif k == "rows" then S(r1, r3)
        elseif k == "other" then S(oh, o2:IsShown() and o2 or oh)
        elseif k == "party" then if faces:IsVisible() then S(faces) else S(r1) end
        else S(trk) end
    end
    return v
end

-- 퀘스트 자동: 대화창 (! ? 회색 · 대화) → 보상 고르기 (가장 비싼 것 분홍 테) → 받음 · 완료 알약
PV.LeelUI_Quest = function(st)
    local v = CreateFrame("Frame", nil, st); v:SetSize(640, 150); v:SetPoint("CENTER")
    local function QD() return (ns.QuestDB and ns.QuestDB()) or {} end
    local function Card(x, w, h, cap)
        local c = CreateFrame("Frame", nil, v); c:SetSize(w, h); c:SetPoint("TOPLEFT", v, "TOPLEFT", x, 0)
        c.fill, c.edge = ns.RoundPlate(c, 12, { 0.114, 0.082, 0.078, 0.95 }, { 0.949, 0.702, 0.761, 0.3 })
        local t = ns.Font(v, 10, { 0.66, 0.58, 0.56 }); t:SetPoint("TOP", c, "BOTTOM", 0, -6); t:SetText(cap)
        return c
    end
    -- ① 대화창
    local g = Card(0, 220, 124, "말 걸면")
    local gn = ns.Font(g, 13, C.accHi); gn:SetPoint("TOPLEFT", 12, -10); gn:SetText("마샬 듀건")
    local function GL(y, icon, text, col)
        local f = CreateFrame("Frame", nil, g); f:SetSize(196, 20); f:SetPoint("TOPLEFT", g, "TOPLEFT", 10, y)
        local ic = f:CreateTexture(nil, "ARTWORK"); ic:SetTexture(icon); ic:SetSize(16, 16); ic:SetPoint("LEFT")
        f.fs = ns.Font(f, 12.5, col); f.fs:SetPoint("LEFT", ic, "RIGHT", 6, 0); f.fs:SetText(text)
        f.ic = ic
        return f
    end
    local gDone = GL(-32, "Interface\\GossipFrame\\ActiveQuestIcon", "수상한 발자국", { 1, 0.82, 0 })
    local gNew = GL(-52, "Interface\\GossipFrame\\AvailableQuestIcon", "늑대 가죽 모으기", { 1, 0.82, 0 })
    local gGrp = GL(-72, "Interface\\GossipFrame\\AvailableQuestIcon", "호그 사냥 (정예)", { 1, 0.6, 0.45 })
    local gTriv = GL(-92, "Interface\\GossipFrame\\AvailableQuestIcon", "닭 쫓기 (회색)", { 0.6, 0.6, 0.6 })
    gTriv.ic:SetDesaturated(true)
    -- 쉬는 키 알약
    local pk = Box(g, 60, 18, 9, { 0.23, 0.18, 0.17 }); pk:SetPoint("TOPRIGHT", g, "TOPRIGHT", -8, -8)
    local pkt = ns.Font(pk, 10.5, C.tx); pkt:SetPoint("CENTER")
    -- 화살표
    local function Arrow(x) local a = ns.Font(v, 18, C.acc); a:SetPoint("CENTER", v, "TOPLEFT", x, -62); a:SetText(">") return a end
    Arrow(232)
    -- ② 보상 고르기
    local rw = Card(244, 200, 124, "보상 고르기")
    local rt = ns.Font(rw, 12, C.tx2); rt:SetPoint("TOPLEFT", 12, -10); rt:SetText("하나를 고르세요")
    local ICONS = { "Interface\\Icons\\INV_Boots_01", "Interface\\Icons\\INV_Chest_Leather_09", "Interface\\Icons\\INV_Sword_04" }
    local slots = {}
    for i, path in ipairs(ICONS) do
        local b = CreateFrame("Frame", nil, rw); b:SetSize(44, 44); b:SetPoint("TOPLEFT", rw, "TOPLEFT", 16 + (i - 1) * 60, -50)
        local t = b:CreateTexture(nil, "ARTWORK"); t:SetAllPoints(); t:SetTexture(path); t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slots[i] = b
    end
    local mark = CreateFrame("Frame", nil, rw); mark:SetPoint("TOPLEFT", slots[2], -4, 4); mark:SetPoint("BOTTOMRIGHT", slots[2], 4, -4)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = mark:CreateTexture(nil, "OVERLAY"); e:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 1)
        if side == "TOP" or side == "BOTTOM" then e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(2)
        else e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(2) end
    end
    local tag = CreateFrame("Frame", nil, mark); tag:SetSize(110, 18); tag:SetPoint("TOP", mark, "BOTTOM", 0, -4)
    ns.RoundPlate(tag, 9, { 0.125, 0.094, 0.086, 0.97 }, { C.acc[1], C.acc[2], C.acc[3], 1 })
    local tgf = ns.Font(tag, 10.5, { 1, 0.84, 0.87 }); tgf:SetPoint("CENTER"); tgf:SetText("가장 비싸요 · |cffffffff1|r은 |cffffffff24|r동")
    Arrow(456)
    -- ③ 알림 알약
    local pills = CreateFrame("Frame", nil, v); pills:SetSize(170, 80); pills:SetPoint("TOPLEFT", v, "TOPLEFT", 468, -22)
    local function Pill(y, text)
        local p = CreateFrame("Frame", nil, pills); p:SetSize(170, 28); p:SetPoint("TOPLEFT", 0, y)
        ns.RoundPlate(p, 14, { 0.125, 0.094, 0.086, 0.96 }, { C.acc[1], C.acc[2], C.acc[3], 0.65 })
        local d = p:CreateTexture(nil, "ARTWORK"); d:SetTexture(ns.MEDIA .. "circle"); d:SetSize(20, 20); d:SetPoint("LEFT", 4, 0); d:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
        local ic = p:CreateTexture(nil, "OVERLAY"); ic:SetTexture(ns.MEDIA .. "hb_quest"); ic:SetSize(12, 12); ic:SetPoint("CENTER", d); ic:SetVertexColor(C.ink[1], C.ink[2], C.ink[3], 1)
        p.fs = ns.Font(p, 11.5, C.tx); p.fs:SetPoint("LEFT", d, "RIGHT", 6, 0); p.fs:SetText(text)
        return p
    end
    local pAcc = Pill(0, "퀘스트 받음  |cff9fe3a8늑대 가죽 모으기|r")
    local pDone = Pill(-36, "")
    local pOff = ns.Font(pills, 11, { 0.55, 0.48, 0.47 }); pOff:SetPoint("TOP", pills, "TOP", 0, -30); pOff:SetText("알림 없이 조용히")
    local pcap = ns.Font(v, 10, { 0.66, 0.58, 0.56 }); pcap:SetPoint("TOP", pills, "TOP", 0, -102); pcap:SetText("화면 위 알림")
    function v:Update()
        local d = QD()
        local on = d.on ~= false
        pkt:SetText(((d.pauseKey == "ctrl" and "Ctrl") or (d.pauseKey == "alt" and "Alt") or "Shift") .. " = 쉬기")
        gDone:SetAlpha((on and d.complete) and 1 or 0.4)
        gNew:SetAlpha((on and d.accept) and 1 or 0.4)
        gGrp:SetAlpha((on and d.accept and not d.skipGroup) and 1 or 0.4)
        gTriv:SetAlpha((on and d.accept and not d.skipTrivial) and 1 or 0.4)
        mark:SetShown(d.best and true or false)
        local toast = d.toast ~= false
        pAcc:SetShown(toast); pDone:SetShown(toast); pOff:SetShown(not toast)
        pDone.fs:SetText("퀘스트 완료  수상한 발자국" .. ((d.toastXp ~= false) and "  |cff9fe3a8+450|r" or ""))
        pDone:SetWidth(math.max(170, pDone.fs:GetStringWidth() + 40)); pAcc:SetWidth(math.max(170, pAcc.fs:GetStringWidth() + 40))
        local sw, sh = st:GetWidth() or 640, st:GetHeight() or 160
        self:SetScale(math.max(0.55, math.min(1.25, (sw - 16) / 660, (sh - 6) / 150)))
    end
    local spot = XP.Spot(st)
    function ns.QAPvHLAlpha(a) spot.Alpha(a) end
    function ns.QAPvHL(k, text)
        if not k or not v:IsVisible() then spot.Off() return end
        if k == "accept" then spot.Show(gNew, gNew, text)
        elseif k == "complete" then spot.Show(gDone, gDone, text)
        elseif k == "trivial" then spot.Show(gTriv, gTriv, text)
        elseif k == "group" then spot.Show(gGrp, gGrp, text)
        elseif k == "gossip" or k == "shared" then spot.Show(g, g, text)
        elseif k == "pause" then spot.Show(pk, pk, text)
        elseif k == "best" then spot.Show(rw, rw, text)
        elseif k == "toast" then spot.Show(pills, pills, text)
        elseif k == "xp" then if pDone:IsShown() then spot.Show(pDone, pDone, text) else spot.Show(pills, pills, text) end
        else spot.Show(g, pills, text) end
    end
    return v
end

-- 퀘템 알림: 몹 이름표 위 템 아이콘 + 대상 창 옆 "쓰기" 단추
PV.LeelUI_QItem = function(st)
    local v = CreateFrame("Frame", nil, st); v:SetSize(560, 150); v:SetPoint("CENTER")
    local function QD() return (ns.QItemDB and ns.QItemDB()) or {} end
    local ITEM = "Interface\\Icons\\INV_Misc_Bag_10"
    local glows = {}
    local function Round(p, size)
        local f = CreateFrame("Frame", nil, p); f:SetSize(size, size)
        local function D(layer, sub, sz, col, a) local t = f:CreateTexture(nil, layer, nil, sub); t:SetTexture(ns.MEDIA .. "circle"); t:SetSize(sz, sz); t:SetPoint("CENTER"); t:SetVertexColor(col[1], col[2], col[3], a or 1) return t end
        f.glow = D("BACKGROUND", -1, size + 14, C.acc, 0.4); glows[#glows + 1] = f.glow
        D("BACKGROUND", 0, size + 2, { 0, 0, 0 }, 0.75); D("BACKGROUND", 1, size, C.acc, 1); D("BACKGROUND", 2, size - 4, { 0.114, 0.082, 0.078 }, 1)
        local ic = f:CreateTexture(nil, "ARTWORK"); ic:SetSize(size - 7, size - 7); ic:SetPoint("CENTER"); ic:SetTexture(ITEM); ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local m = f:CreateMaskTexture(); m:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); m:SetAllPoints(ic); ic:AddMaskTexture(m)
        return f
    end
    -- ① 몹 이름표
    local np = CreateFrame("Frame", nil, v); np:SetSize(170, 110); np:SetPoint("TOPLEFT", v, "TOPLEFT", 10, 0)
    local nn = ns.Font(np, 13, { 1, 0.42, 0.42 }); nn:SetPoint("BOTTOM", np, "BOTTOM", 0, 26); nn:SetText("코볼트 땅꾼")
    local hp = CreateFrame("StatusBar", nil, np); hp:SetStatusBarTexture(ns.WHITE); hp:SetSize(140, 10); hp:SetPoint("TOP", nn, "BOTTOM", 0, -4)
    hp:SetMinMaxValues(0, 100); hp:SetValue(80); hp:SetStatusBarColor(0.72, 0.12, 0.21, 1)
    local hb = hp:CreateTexture(nil, "BACKGROUND"); hb:SetAllPoints(); hb:SetColorTexture(0.11, 0.08, 0.075, 0.9)
    local pIcon = Round(np, 26); pIcon:SetPoint("BOTTOM", nn, "TOP", 0, 8)
    local pcap = ns.Font(v, 10, { 0.66, 0.58, 0.56 }); pcap:SetPoint("TOP", np, "BOTTOM", 0, -6); pcap:SetText("몹 이름표")
    -- ② 대상 창 + 단추
    local tf = CreateFrame("Frame", nil, v); tf:SetSize(190, 56); tf:SetPoint("LEFT", v, "LEFT", 260, -2)
    ns.RoundPlate(tf, 14, { 0.114, 0.082, 0.078, 0.95 }, { 0.949, 0.702, 0.761, 0.3 })
    local por = tf:CreateTexture(nil, "ARTWORK"); por:SetTexture(ns.MEDIA .. "circle"); por:SetSize(40, 40); por:SetPoint("LEFT", 8, 0); por:SetVertexColor(0.45, 0.32, 0.28, 1)
    local tn = ns.Font(tf, 12.5, { 1, 0.42, 0.42 }); tn:SetPoint("TOPLEFT", por, "TOPRIGHT", 8, -2); tn:SetText("코볼트 땅꾼")
    local th = CreateFrame("StatusBar", nil, tf); th:SetStatusBarTexture(ns.WHITE); th:SetSize(124, 8); th:SetPoint("TOPLEFT", tn, "BOTTOMLEFT", 0, -6)
    th:SetMinMaxValues(0, 100); th:SetValue(80); th:SetStatusBarColor(0.72, 0.12, 0.21, 1)
    local tb = th:CreateTexture(nil, "BACKGROUND"); tb:SetAllPoints(); tb:SetColorTexture(0.11, 0.08, 0.075, 0.9)
    local tcap = ns.Font(v, 10, { 0.66, 0.58, 0.56 }); tcap:SetPoint("TOP", tf, "BOTTOM", 0, -40); tcap:SetText("대상 창")
    local btn = Round(v, 38)
    local say = Box(btn, 52, 16, 8, C.accHi); say:SetPoint("TOP", btn, "BOTTOM", 0, 3); say:SetFrameLevel(btn:GetFrameLevel() + 3)
    local sayT = ns.Font(say, 10, C.ink); sayT:SetShadowColor(0, 0, 0, 0); sayT:SetPoint("CENTER")
    function v:Update()
        local d = QD()
        pIcon:SetShown(d.plate ~= false); pIcon:SetScale((tonumber(d.psz) or 26) / 26)
        btn:SetShown(d.btn ~= false)
        local k = (tonumber(d.bsz) or 38) / 38; btn:SetScale(k)
        btn:ClearAllPoints()
        if d.side == "left" then btn:SetPoint("RIGHT", tf, "LEFT", -10 / k, 2 / k)
        elseif d.side == "below" then btn:SetPoint("TOP", tf, "BOTTOM", 0, -8 / k)
        else btn:SetPoint("LEFT", tf, "RIGHT", 10 / k, 2 / k) end
        sayT:SetText(d.count ~= false and "쓰기 3" or "쓰기"); say:SetWidth(sayT:GetStringWidth() + 12)
        for _, g in ipairs(glows) do g:SetShown(d.glow ~= false) end
        local sw, sh = st:GetWidth() or 640, st:GetHeight() or 160
        self:SetScale(math.max(0.6, math.min(1.3, (sw - 16) / 560, (sh - 6) / 150)))
    end
    local spot = XP.Spot(st)
    function ns.QIPvHLAlpha(a) spot.Alpha(a) end
    function ns.QIPvHL(k, text)
        if not k or not v:IsVisible() then spot.Off() return end
        local function S(a, b) if a:IsVisible() then spot.Show(a, b or a, text) else spot.Off() end end
        if k == "plate" then S(pIcon)
        elseif k == "btn" or k == "count" then S(btn, btn:IsVisible() and say or btn)
        elseif k == "glow" then if pIcon:IsVisible() then S(pIcon) else S(btn) end
        elseif k == "learn" then spot.Show(np, np, text)
        else spot.Show(np, tf, text) end
    end
    return v
end

-- Leel Spot: 물건 위 토끼 알약 (이름 · 진행도) + 분홍 선 + 끝 점 · 옆에 퀘스트 아닌 물건 (회색)
PV.LeelSpot = function(st)
    local M = "Interface\\AddOns\\LeelSpot\\media\\"
    local PK, DIMC = { 0.949, 0.702, 0.761 }, { 0.80, 0.64, 0.62 }
    local v = CreateFrame("Frame", nil, st); v:SetSize(520, 150); v:SetPoint("CENTER")
    local function SD() return LeelSpotDB or {} end
    local function Slice(t) pcall(t.SetTextureSliceMargins, t, 11, 11, 11, 11) end
    local function Obj(x, quest, name)
        local o = CreateFrame("Frame", nil, v); o:SetSize(200, 60); o:SetPoint("BOTTOM", v, "BOTTOMLEFT", x, 18)
        -- 물건 (상자 그림 + 그림자)
        local sh = o:CreateTexture(nil, "BACKGROUND"); sh:SetTexture(ns.MEDIA .. "circle"); sh:SetSize(54, 14); sh:SetPoint("BOTTOM", 0, 4); sh:SetVertexColor(0, 0, 0, 0.5)
        local it = o:CreateTexture(nil, "ARTWORK"); it:SetTexture(quest and "Interface\\Icons\\INV_Misc_Herb_07" or "Interface\\Icons\\INV_Box_01"); it:SetSize(34, 34); it:SetPoint("BOTTOM", 0, 10)
        local m = o:CreateMaskTexture(); m:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); m:SetAllPoints(it); it:AddMaskTexture(m)
        o.obj = it
        local pill = CreateFrame("Frame", nil, o); pill:SetSize(140, 30)
        local bg = pill:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(M .. "pill22"); Slice(bg); bg:SetAllPoints(); bg:SetVertexColor(0.125, 0.094, 0.086, 0.94)
        local rim = pill:CreateTexture(nil, "BORDER"); rim:SetTexture(M .. "pill22rim"); Slice(rim); rim:SetAllPoints()
        if quest then rim:SetVertexColor(PK[1], PK[2], PK[3], 0.85) else rim:SetVertexColor(DIMC[1], DIMC[2], DIMC[3], 0.45) end
        local halo = pill:CreateTexture(nil, "BACKGROUND", nil, -2); halo:SetTexture(M .. "circle"); halo:SetSize(40, 40); halo:SetBlendMode("ADD"); halo:SetVertexColor(PK[1], PK[2], PK[3], 0.55)
        local ic = pill:CreateTexture(nil, "ARTWORK"); ic:SetTexture(M .. "bunny"); ic:SetSize(26, 26); ic:SetPoint("LEFT", 2, 0); halo:SetPoint("CENTER", ic)
        if not quest then ic:SetDesaturated(true); ic:SetAlpha(0.8) end
        local nm = ns.Font(pill, 12.5, { 0.965, 0.925, 0.91 }); nm:SetPoint("LEFT", ic, "RIGHT", 6, 0); nm:SetText(name)
        local pg = pill:CreateFontString(nil, "OVERLAY"); pg:SetFont(M .. "BarlowCondensed-ExtraBoldItalic.ttf", 15, ""); pg:SetTextColor(1, 0.839, 0.878); pg:SetPoint("LEFT", nm, "RIGHT", 6, 0); pg:SetText(quest and "3/8" or "")
        local stem = pill:CreateTexture(nil, "BACKGROUND", nil, -1); stem:SetColorTexture(PK[1], PK[2], PK[3], 0.8); stem:SetWidth(2); stem:SetPoint("TOP", pill, "BOTTOM", 0, 1)
        local dot = pill:CreateTexture(nil, "ARTWORK"); dot:SetTexture(M .. "circle"); dot:SetSize(8, 8); dot:SetVertexColor(PK[1], PK[2], PK[3], 1); dot:SetPoint("CENTER", stem, "BOTTOM")
        local spark = o:CreateTexture(nil, "OVERLAY"); spark:SetTexture(ns.MEDIA .. "soft_glow"); spark:SetBlendMode("ADD"); spark:SetSize(70, 70); spark:SetPoint("CENTER", it); spark:SetVertexColor(1, 0.95, 0.7, 0.55)
        o.pill, o.halo, o.pg, o.nm, o.stem, o.dot, o.spark, o.quest = pill, halo, pg, nm, stem, dot, spark, quest
        return o
    end
    local q = Obj(150, true, "평온초")
    local n = Obj(370, false, "낡은 상자")
    local qcap = ns.Font(v, 10, { 0.66, 0.58, 0.56 }); qcap:SetPoint("TOP", q, "BOTTOM", 0, -3); qcap:SetText("퀘스트 물건")
    local ncap = ns.Font(v, 10, { 0.66, 0.58, 0.56 }); ncap:SetPoint("TOP", n, "BOTTOM", 0, -4); ncap:SetText("그 밖의 물건")
    function v:Update()
        local d = SD()
        local on = d.on ~= false
        local L = tonumber(d.stem) or 34
        local Lp = math.min(L, 90)   -- 미리 보기 칸 안에 들어가게
        for _, o in ipairs({ q, n }) do
            local show = on and (o.quest or d.all)
            o.pill:SetShown(show)
            o.pill:SetScale(math.min(1.6, tonumber(d.size) or 1))
            o.pill:ClearAllPoints(); o.pill:SetPoint("BOTTOM", o.obj, "CENTER", 0, (Lp + math.max(-30, math.min(40, tonumber(d.y) or 0))) / o.pill:GetScale())
            o.stem:SetHeight(Lp / o.pill:GetScale()); o.stem:SetShown(L > 0); o.dot:SetShown(L > 0)
            local prog = o.quest and d.prog ~= false
            o.pg:SetShown(prog)
            o.pill:SetWidth(2 + 26 + 6 + 10 + o.nm:GetStringWidth() + (prog and (6 + o.pg:GetStringWidth()) or 0))
            o.halo:SetShown(o.quest and d.halo ~= false)
            o.spark:SetShown(o.quest and d.sparkle ~= false)
        end
        ncap:SetAlpha(d.all and 1 or 0.45)
        -- 높이 = 이름 칸 18 + 물건 (중심 27) + 선 + 알약 + 위 여백 → 내용만큼만 잡고 가운데로
        local ps = math.min(1.6, tonumber(d.size) or 1)
        local top = math.max(0, Lp + math.max(-30, math.min(40, tonumber(d.y) or 0))) + 30 * ps
        local H = 18 + 27 + top + 40   -- 위 40 = 줄에 마우스를 올렸을 때 말풍선 자리
        self:SetHeight(H)
        local sw, sh = st:GetWidth() or 640, st:GetHeight() or 160
        self:SetScale(math.max(0.55, math.min(1.5, (sw - 16) / 520, (sh - 10) / H)))
    end
    local spot = XP.Spot(st)
    function ns.SpotPvHLAlpha(a) spot.Alpha(a) end
    function ns.SpotPvHL(k, text)
        if not k or not v:IsVisible() then spot.Off() return end
        local function S(a, b) if a and a:IsVisible() then spot.Show(a, b or a, text) else spot.Off() end end
        if k == "pill" then S(q.pill)
        elseif k == "other" then S(n)
        elseif k == "prog" then if q.pg:IsVisible() then S(q.pg) else S(q.pill) end
        elseif k == "stem" then if q.stem:IsVisible() then spot.Show(q.stem, q.dot, text) else S(q.pill) end
        elseif k == "halo" then S(q.pill)
        elseif k == "far" then S(q.obj)
        else spot.Show(q, n, text) end
    end
    return v
end

-- Leel Map: 작은 지도 창 = 지금 있는 지역의 진짜 지도 (게임 지도 그림 · 내 위치 · 출구 화살표 · 지역 레벨 · 좌표 줄)
PV.LeelMap = function(st)
    local v = CreateFrame("Frame", nil, st); v:SetSize(460, 250); v:SetPoint("CENTER")
    local function MD() return LeelMapDB or {} end
    local win = CreateFrame("Frame", nil, v); win:SetSize(300, 247); win:SetPoint("CENTER")
    win.fill, win.edge = ns.RoundPlate(win, 14, { 0.114, 0.082, 0.078, 0.97 }, { 0.949, 0.702, 0.761, 0.55 })
    win.plain = win:CreateTexture(nil, "BACKGROUND", nil, 2); win.plain:SetAllPoints(); win.plain:SetColorTexture(0.12, 0.1, 0.07, 1)
    local head = CreateFrame("Frame", nil, win); head:SetPoint("TOPLEFT", 10, -6); head:SetPoint("TOPRIGHT", -10, -6); head:SetHeight(20)
    local zn = ns.Font(head, 13, C.tx); zn:SetPoint("LEFT")
    local lv = ns.Font(head, 12, { 0.25, 0.75, 0.25 }); lv:SetPoint("LEFT", zn, "RIGHT", 6, 0)
    local cl = ns.Font(head, 12, C.tx2); cl:SetPoint("RIGHT"); cl:SetText("×")
    -- 지도 칸 (게임 지도 그림 조각을 이어 붙여요)
    local map = CreateFrame("Frame", nil, win); map:SetClipsChildren(true)
    local mbg = map:CreateTexture(nil, "BACKGROUND"); mbg:SetAllPoints(); mbg:SetColorTexture(0.2, 0.18, 0.14, 1)
    local tiles, curMap = {}, nil
    local function Tiles(m)
        for _, t in ipairs(tiles) do t:Hide() end
        local W, H = map:GetWidth(), map:GetHeight()
        local okL, layers = pcall(C_Map.GetMapArtLayers, m)
        local L = okL and layers and layers[1]
        local okT, texs = pcall(C_Map.GetMapArtLayerTextures, m, 1)
        if not (L and okT and texs and #texs > 0 and W > 0) then return end
        local cols = math.ceil(L.layerWidth / L.tileWidth)
        local sx, sy = W / L.layerWidth, H / L.layerHeight
        for i, tex in ipairs(texs) do
            local t = tiles[i] or map:CreateTexture(nil, "BORDER"); tiles[i] = t
            local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
            t:SetTexture(tex); t:SetSize(L.tileWidth * sx, L.tileHeight * sy)
            t:ClearAllPoints(); t:SetPoint("TOPLEFT", map, "TOPLEFT", c * L.tileWidth * sx, -r * L.tileHeight * sy)
            t:Show()
        end
    end
    local me = map:CreateTexture(nil, "OVERLAY"); me:SetTexture("Interface\\Minimap\\MinimapArrow"); me:SetSize(22, 22)
    -- 출구 화살표 (이 지역 진짜 출구 · 없으면 숨김)
    local exits = {}
    local function Exit(i)
        local e = exits[i]
        if e then return e end
        e = CreateFrame("Frame", nil, map); e:SetSize(20, 20); e:SetFrameLevel(map:GetFrameLevel() + 3)
        local d = e:CreateTexture(nil, "ARTWORK"); d:SetTexture(ns.MEDIA .. "circle"); d:SetAllPoints(); d:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
        e.a = e:CreateTexture(nil, "OVERLAY"); e.a:SetTexture(ns.MEDIA .. "np_arrow"); e.a:SetSize(12, 12); e.a:SetPoint("CENTER"); e.a:SetVertexColor(C.ink[1], C.ink[2], C.ink[3], 1)
        e.t = ns.Font(e, 9.5, C.accHi)
        exits[i] = e
        return e
    end
    -- 길드원 토끼 (보기 예시)
    local gd = CreateFrame("Frame", nil, map); gd:SetSize(18, 18); gd:SetFrameLevel(map:GetFrameLevel() + 3)
    local g1 = gd:CreateTexture(nil, "ARTWORK"); g1:SetTexture(ns.MEDIA .. "circle"); g1:SetAllPoints(); g1:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    local g2 = gd:CreateTexture(nil, "OVERLAY"); g2:SetTexture(ns.MEDIA .. "bunny"); g2:SetSize(14, 14); g2:SetPoint("CENTER")
    local gn = ns.Font(gd, 9.5, C.tx); gn:SetPoint("TOP", gd, "BOTTOM", 0, -1); gn:SetText("당근")
    -- 좌표 줄
    local co = CreateFrame("Frame", nil, win); co:SetPoint("BOTTOMLEFT", 10, 6); co:SetPoint("BOTTOMRIGHT", -10, 6); co:SetHeight(18)
    local cf = ns.Font(co, 11.5, C.tx2); cf:SetPoint("CENTER")
    local walk = ns.Font(v, 10.5, C.accHi); walk:SetPoint("TOP", win, "BOTTOM", 0, -4)
    local px, py = 0.5, 0.5
    local function Where()
        local m = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        local x, y
        if m then local ok, p = pcall(C_Map.GetPlayerMapPosition, m, "player"); if ok and p then x, y = p:GetXY() end end
        return m, x, y
    end
    local function Place()
        local W, H = map:GetWidth(), map:GetHeight()
        me:ClearAllPoints(); me:SetPoint("CENTER", map, "TOPLEFT", px * W, -py * H)
        local f = GetPlayerFacing and GetPlayerFacing()
        if f then pcall(me.SetRotation, me, f) end
        cf:SetText(("나  |cffffffff%.1f, %.1f|r"):format(px * 100, py * 100))
    end
    function v:Update()
        local d = MD()
        local mini = d.mini and true or false
        local ww = mini and 300 or 400
        local mh = math.floor((ww - 16) / 1.5 + 0.5)          -- 게임 지도 비율 (가로 1.5 : 세로 1)
        local coH = d.coords and 22 or 0
        win:SetSize(ww, 28 + mh + 8 + coH)
        v:SetSize(win:GetWidth() + 20, win:GetHeight() + 22)
        map:ClearAllPoints(); map:SetPoint("TOPLEFT", 8, -28); map:SetSize(ww - 16, mh)
        win.plain:SetShown(d.skin == false)
        co:SetShown(d.coords and true or false)
        local m, x, y = Where()
        if m then
            local info = C_Map.GetMapInfo and C_Map.GetMapInfo(m)
            zn:SetText(info and info.name or "")
            local minL, maxL, c = nil, nil, nil
            if _G.LeelMapLevelInfo then minL, maxL, c = LeelMapLevelInfo(m) end
            if minL and d.levels then
                lv:SetText("(" .. (minL == maxL and maxL or (minL .. "-" .. maxL)) .. ")")
                if type(c) == "table" then lv:SetTextColor(c[1] or c.r or 1, c[2] or c.g or 1, c[3] or c.b or 1) end
                lv:Show()
            else lv:Hide() end
            if m ~= curMap or self.lastW ~= map:GetWidth() then curMap = m; self.lastW = map:GetWidth(); Tiles(m) end
        end
        if x then px, py = x, y end
        Place()
        -- 출구
        for _, e in ipairs(exits) do e:Hide() end
        if d.exits ~= false and m and _G.LeelMapExits and LeelMapExits.List then
            local W, H = map:GetWidth(), map:GetHeight()
            for i, e in ipairs(LeelMapExits.List(m)) do
                if i > 6 then break end
                local f = Exit(i)
                local ex, ey = math.max(0.04, math.min(0.96, e.x)), math.max(0.05, math.min(0.95, e.y))
                f:ClearAllPoints(); f:SetPoint("CENTER", map, "TOPLEFT", ex * W, -ey * H)
                pcall(f.a.SetRotation, f.a, -math.atan2(ey - 0.5, ex - 0.5) + math.pi / 2)   -- 화살표 그림은 아래를 봐요 → 지도 밖(가장자리) 쪽으로
                f.t:ClearAllPoints()
                if ex < 0.5 then f.t:SetPoint("LEFT", f, "RIGHT", 3, 0) else f.t:SetPoint("RIGHT", f, "LEFT", -3, 0) end
                f.t:SetText(e.name or "")
                f:Show()
            end
        end
        gd:SetShown(d.gShow ~= false)
        gd:ClearAllPoints(); gd:SetPoint("CENTER", map, "TOPLEFT", math.min(0.9, px + 0.12) * map:GetWidth(), -math.max(0.1, py - 0.1) * map:GetHeight())
        win:SetAlpha(1); walk:SetText("")
        local sw, sh = st:GetWidth() or 640, st:GetHeight() or 160
        self:SetScale(math.max(0.45, math.min(1.5, (sw - 16) / v:GetWidth(), (sh - 6) / v:GetHeight())))
    end
    -- 걸으면 내 화살표가 따라 움직여요 (미리 보기가 보일 때만)
    local acc = 0
    v:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc < 0.2 then return end
        acc = 0
        local m, x, y = Where()
        if m and m ~= curMap then v:Update() return end
        if x then px, py = x, y; Place() end
    end)
    local spot = XP.Spot(st)
    function ns.MapPvHLAlpha(a) spot.Alpha(a) end
    function ns.MapPvHL(k, text)
        win:SetAlpha(1); walk:SetText("")
        if not k or not v:IsVisible() then spot.Off() return end
        local function S(a, b) if a and a:IsVisible() then spot.Show(a, b or a, text) else spot.Show(win, win, text) end end
        if k == "coords" then S(co)
        elseif k == "level" then S(lv)
        elseif k == "exits" then
            local first, last
            for _, e in ipairs(exits) do if e:IsShown() then first = first or e; last = e end end
            if first then spot.Show(map, map, text) else S(map) end
        elseif k == "guild" then S(gd)
        elseif k == "fade" then
            local d = MD()
            if d.fade then win:SetAlpha(tonumber(d.fadeAlpha) or 0.4); walk:SetText("걷는 중 · " .. math.floor((tonumber(d.fadeAlpha) or 0.4) * 100 + 0.5) .. "%") end
            spot.Show(win, win, text)
        else S(win) end
    end
    return v
end

-- Leel Mark: 가로 알약 징 바 [토끼][해골 X 네모 달 세모 다이아 동그라미 별][자동][지우기]
PV.LeelMark = function(st)
    local M = "Interface\\AddOns\\LeelMark\\media\\"
    local v = CreateFrame("Frame", nil, st); v:SetSize(470, 96); v:SetPoint("CENTER")
    local function Sl(t, m) pcall(t.SetTextureSliceMargins, t, m, m, m, m) end
    local bar = CreateFrame("Frame", nil, v); bar:SetHeight(44); bar:SetPoint("TOP", 0, -6)
    local bg = bar:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(M .. "pill44"); Sl(bg, 22); bg:SetAllPoints(); bg:SetVertexColor(0.125, 0.094, 0.086, 0.96)
    local rim = bar:CreateTexture(nil, "BORDER"); rim:SetTexture(M .. "pill44rim"); Sl(rim, 22); rim:SetAllPoints(); rim:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.6)
    local bun = bar:CreateTexture(nil, "ARTWORK"); bun:SetTexture(M .. "icon"); bun:SetSize(30, 30); bun:SetPoint("LEFT", 8, 0)
    local marks = {}
    for idx = 1, 8 do
        local b = CreateFrame("Frame", nil, bar); b:SetSize(30, 30)
        local c = b:CreateTexture(nil, "BACKGROUND"); c:SetTexture(M .. "circle"); c:SetAllPoints(); c:SetVertexColor(0.18, 0.137, 0.129, 1)
        local r = b:CreateTexture(nil, "BORDER"); r:SetTexture(M .. "ring"); r:SetAllPoints(); r:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.35)
        local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons"); ic:SetSize(19, 19); ic:SetPoint("CENTER")
        if SetRaidTargetIconTexture then pcall(SetRaidTargetIconTexture, ic, idx) end
        local bd = CreateFrame("Frame", nil, b); bd:SetSize(15, 15); bd:SetPoint("CENTER", b, "TOPRIGHT", -3, -3)
        local bo = bd:CreateTexture(nil, "ARTWORK"); bo:SetTexture(M .. "circle"); bo:SetPoint("CENTER"); bo:SetSize(18, 18); bo:SetVertexColor(0.125, 0.094, 0.086, 1)
        bd.inT = bd:CreateTexture(nil, "ARTWORK", nil, 1); bd.inT:SetTexture(M .. "circle"); bd.inT:SetAllPoints()
        bd.fs = ns.Num(bd, 10, C.ink); bd.fs:SetPoint("CENTER")
        b.bd = bd
        marks[idx] = b
    end
    local function Round(icon, filled)
        local b = CreateFrame("Frame", nil, bar); b:SetSize(32, 32)
        local t = b:CreateTexture(nil, "BACKGROUND"); t:SetTexture(M .. "circle"); t:SetAllPoints()
        local col = filled and C.acc or { 0.18, 0.137, 0.129 }; t:SetVertexColor(col[1], col[2], col[3], 1)
        if not filled then local rr = b:CreateTexture(nil, "BORDER"); rr:SetTexture(M .. "ring"); rr:SetAllPoints(); rr:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.45) end
        local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetTexture(M .. icon); ic:SetSize(15, 15); ic:SetPoint("CENTER")
        local fc = filled and C.ink or C.tx; ic:SetVertexColor(fc[1], fc[2], fc[3], 1)
        return b
    end
    local mEnd = 8 + 30 + 12 + 8 * 30 + 7 * 6
    local auto = Round("ic_wand", true); auto:SetPoint("LEFT", mEnd + 13, 0)
    local tell = Round("ic_horn", false); tell:SetPoint("LEFT", auto, "RIGHT", 6, 0)
    local clr = Round("ic_eraser", false); clr:SetPoint("LEFT", tell, "RIGHT", 6, 0)
    bar:SetWidth(mEnd + 13 + 3 * 32 + 12 + 8)
    -- 서랍 예시 (달 징에 마우스)
    local dr = CreateFrame("Frame", nil, v); dr:SetHeight(30); dr:SetPoint("TOP", bar, "BOTTOM", 0, -4)
    local dbg = dr:CreateTexture(nil, "BACKGROUND"); dbg:SetTexture(M .. "pill22"); Sl(dbg, 11); dbg:SetAllPoints(); dbg:SetVertexColor(0.125, 0.094, 0.086, 0.98)
    local drm = dr:CreateTexture(nil, "BORDER"); drm:SetTexture(M .. "pill22rim"); Sl(drm, 11); drm:SetAllPoints(); drm:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.5)
    local dic = dr:CreateTexture(nil, "ARTWORK"); dic:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons"); dic:SetSize(18, 18); dic:SetPoint("LEFT", 8, 0)
    if SetRaidTargetIconTexture then pcall(SetRaidTargetIconTexture, dic, 5) end
    local dx = 32
    for _, t in ipairs({ { "자동" }, { "순서" }, { "변이 · 마법사", true }, { "덫" }, { "혼절" }, { "안 씀" } }) do
        local ch = CreateFrame("Frame", nil, dr); ch:SetHeight(22); ch:SetPoint("LEFT", dx, 0)
        local cb = ch:CreateTexture(nil, "BACKGROUND"); cb:SetTexture(M .. "pill22"); Sl(cb, 11); cb:SetAllPoints()
        local col = t[2] and C.acc or { 0.18, 0.137, 0.129 }; cb:SetVertexColor(col[1], col[2], col[3], 1)
        local fs = ns.Font(ch, 11.5, t[2] and C.ink or C.tx); fs:SetShadowColor(0, 0, 0, t[2] and 0 or 0.8); fs:SetPoint("CENTER"); fs:SetText(t[1])
        ch:SetWidth(fs:GetStringWidth() + 18); dx = dx + ch:GetWidth() + 4
    end
    dr:SetWidth(dx + 4)
    local note = ns.Font(v, 10.5, { 0.66, 0.58, 0.56 }); note:SetPoint("TOP", dr, "BOTTOM", 0, -6)
    local DEF = { [8] = { kind = "kill", n = 1 }, [7] = { kind = "kill", n = 2 }, [6] = { kind = "cc", role = "덫", who = "사냥꾼", cls = "HUNTER" },
                  [5] = { kind = "cc", role = "변이", who = "마법사", cls = "MAGE" }, [4] = { kind = "kill", n = 3 }, [3] = { kind = "kill", n = 4 },
                  [2] = { kind = "kill", n = 5 }, [1] = { kind = "cc", role = "혼절", who = "도적", cls = "ROGUE" } }
    function v:Update()
        local d = LeelMarkDB or {}
        local hide = d.show == "never"
        bar:SetAlpha(hide and 0.35 or 1)
        note:SetText((hide and "바는 숨김 · 단축키만 동작" or (d.show == "always" and "혼자일 때도 보여요" or "파티일 때만 보여요")) .. " · 징에 마우스 = 약속 서랍")
        local plan = DEF
        if IsInGroup() and _G.LeelMarkAPI then local ok, p = pcall(_G.LeelMarkAPI.Plan); if ok and p and next(p) then plan = p end end
        local list = {}
        for idx = 1, 8 do
            local p = plan[idx]
            local key
            if not p then key = 300 + idx elseif p.kind == "kill" then key = p.n else local cr = ({ [5] = 1, [6] = 2, [1] = 3 })[idx]; key = cr and (100 + cr) or (150 + idx) end
            list[#list + 1] = { idx, key }
        end
        table.sort(list, function(a, b) return a[2] < b[2] end)
        for k, e in ipairs(list) do
            local b, p = marks[e[1]], plan[e[1]]
            b:ClearAllPoints(); b:SetPoint("LEFT", bar, "LEFT", 8 + 30 + 12 + (k - 1) * 36, 0)
            b:SetAlpha(p and 1 or 0.35)
            if p and p.kind == "kill" then b.bd:Show(); b.bd.inT:SetVertexColor(C.acc[1], C.acc[2], C.acc[3]); b.bd.fs:SetText(p.n)
            elseif p then local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.cls]; b.bd:Show(); b.bd.fs:SetText(""); if c then b.bd.inT:SetVertexColor(c.r, c.g, c.b) end
            else b.bd:Hide() end
        end
        bar:SetScale(tonumber(d.scale) or 1)
        local sw, sh = st:GetWidth() or 640, st:GetHeight() or 160
        self:SetScale(math.max(0.45, math.min(1.3, (sw - 16) / (bar:GetWidth() * (tonumber(d.scale) or 1) + 20), (sh - 10) / 110)))
    end
    local spot = XP.Spot(st)
    XP.HLREG.LeelMark = { function(k, text)
        if not k or not v:IsVisible() then spot.Off() return end
        if k == "auto" then spot.Show(auto, tell, text)
        elseif k == "order" then spot.Show(bar, dr, text)
        else spot.Show(bar, bar, text) end
    end, function(a) spot.Alpha(a) end }
    return v
end

-- 토템 세트: 큰 토끼 단추 (둘레 4칸 원소 링 · 단축키) + 세트 순서 1~4
PV.LeelUI_TotemSet = function(st)
    local v = CreateFrame("Frame", nil, st); v:SetSize(400, 120); v:SetPoint("CENTER")
    local ELC = { { 0.91, 0.45, 0.23 }, { 0.62, 0.48, 0.27 }, { 0.25, 0.56, 1.00 }, { 0.75, 0.82, 0.88 } }
    local q = CreateFrame("Frame", nil, v); q:SetSize(64, 64); q:SetPoint("LEFT", 18, -6)
    local bg = q:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(ns.MEDIA .. "circle"); bg:SetAllPoints(); bg:SetVertexColor(0.10, 0.075, 0.08, 0.96)
    for e = 1, 4 do
        local sg = q:CreateTexture(nil, "BORDER"); sg:SetTexture(ns.MEDIA .. "tring_q")
        sg:SetPoint("TOPLEFT", -6, 6); sg:SetPoint("BOTTOMRIGHT", 6, -6); pcall(sg.SetRotation, sg, -math.rad((e - 1) * 90))
        sg:SetVertexColor(ELC[e][1], ELC[e][2], ELC[e][3], e <= 2 and 1 or 0.3)
    end
    for i, f in ipairs({ "tb_l3", "tb_l2", "tb_l1", "tb_l0", "tb_top" }) do
        local t = q:CreateTexture(nil, "ARTWORK", nil, i); t:SetTexture(ns.MEDIA .. f); t:SetSize(58, 58); t:SetPoint("CENTER")
    end
    local key = CreateFrame("Frame", nil, q); key:SetSize(22, 18); key:SetPoint("TOPLEFT", -8, 8); key:SetFrameLevel(q:GetFrameLevel() + 3)
    local kb = key:CreateTexture(nil, "BACKGROUND"); kb:SetTexture(ns.MEDIA .. "pill16"); kb:SetAllPoints(); kb:SetVertexColor(0.07, 0.05, 0.055, 0.95)
    local kf = ns.Font(key, 12, { 1, 1, 1 }); kf:SetPoint("CENTER")
    local title = ns.Font(v, 13, C.accHi); title:SetPoint("TOPLEFT", q, "TOPRIGHT", 22, 10)
    local sub = ns.Font(v, 10.5, { 0.66, 0.58, 0.56 }); sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    local slots = {}
    for k = 1, 4 do
        local b = CreateFrame("Frame", nil, v); b:SetSize(40, 40); b:SetPoint("TOPLEFT", title, "BOTTOMLEFT", (k - 1) * 50, -24)
        b.ic = b:CreateTexture(nil, "ARTWORK"); b.ic:SetAllPoints(); b.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local mk = b:CreateMaskTexture(); mk:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); mk:SetAllPoints(b.ic); b.ic:AddMaskTexture(mk)
        b.n = ns.Num(b, 13, C.accHi); b.n:SetPoint("BOTTOMRIGHT", 3, -3); b.n:SetText(k)
        b.empty = ns.Font(b, 9.5, { 0.55, 0.48, 0.47 }); b.empty:SetPoint("CENTER"); b.empty:SetText("빈칸")
        slots[k] = b
        if k < 4 then local ar = ns.Font(v, 11, C.acc); ar:SetPoint("LEFT", b, "RIGHT", 1, 0); ar:SetText("›") end
    end
    function v:Update()
        local t = ns.TotemSetDB and ns.TotemSetDB() or {}
        local cur = t.cur or 1
        title:SetText(((ns.TOTEM_SETNAMES or {})[cur] or "") .. " 세트")
        sub:SetText("누를 때마다 다음 토템 하나" .. (t.shift and " · Shift + 키 = 다음 세트" or ""))
        kf:SetText((t.key and t.key ~= "") and t.key:gsub("SHIFT%-", "S-"):gsub("CTRL%-", "C-"):gsub("ALT%-", "A-") or "–")
        key:SetWidth(math.max(22, kf:GetStringWidth() + 10))
        local set = (t.sets or {})[cur] or {}
        local opts = ns.TotemOptions and ns.TotemOptions() or {}
        for k = 1, 4 do
            local id, icon = set[k], nil
            for _, o in ipairs(opts) do if o.key == id then icon = o.icon end end
            slots[k].ic:SetTexture(icon); slots[k].ic:SetShown(icon ~= nil); slots[k].empty:SetShown(icon == nil)
        end
        local sw, sh = st:GetWidth() or 640, st:GetHeight() or 160
        self:SetScale(math.max(0.6, math.min(1.5, (sw - 16) / 400, (sh - 10) / 130)))
    end
    local spot = XP.Spot(st)
    XP.HLREG.LeelUI_TotemSet = { function(k, text)
        if not k or not v:IsVisible() then spot.Off() return end
        local n = k:match("^s(%d)$")
        if n then spot.Show(slots[tonumber(n)], slots[tonumber(n)], text)
        elseif k == "key" then spot.Show(key, key, text)
        elseif k == "set" then spot.Show(title, slots[4], text)
        else spot.Show(q, slots[4], text) end
    end, function(a) spot.Alpha(a) end }
    return v
end

-- 줍기 창: 분홍 카드 목록 (토끼 · 시체 이름 · 줄마다 등급 색 띠) + 모두 줍기
PV.LeelUI_LootWin = function(st)
    local v = CreateFrame("Frame", nil, st); v:SetSize(260, 220); v:SetPoint("CENTER")
    local win = CreateFrame("Frame", nil, v); win:SetSize(244, 216); win:SetPoint("CENTER")
    ns.RoundPlate(win, 16, { 0.125, 0.094, 0.086, 0.97 }, { 0.949, 0.702, 0.761, 0.7 })
    local bunny = win:CreateTexture(nil, "ARTWORK"); bunny:SetTexture(ns.MEDIA .. "bag_bunny"); bunny:SetSize(24, 24); bunny:SetPoint("TOPLEFT", 10, -8)
    local tt = ns.Font(win, 13, C.accHi); tt:SetPoint("LEFT", bunny, "RIGHT", 7, 0); tt:SetText("코볼트 땅꾼")
    local xb = win:CreateTexture(nil, "ARTWORK"); xb:SetTexture(ns.MEDIA .. "hb_x"); xb:SetSize(16, 16); xb:SetPoint("TOPRIGHT", -11, -12)
    local ROWS = { { "Interface\\Icons\\INV_Misc_Coin_02", "24 은 12 동", { 1, 0.84, 0.42 }, "돈" },
                   { "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", "늑대 가죽", { 1, 1, 1 }, "|cffffd76a퀘스트 템|r", "3" },
                   { "Interface\\Icons\\INV_Boots_01", "늑대 가죽 장화", { 0.12, 1, 0 }, "고급" } }
    for i, r in ipairs(ROWS) do
        local row = CreateFrame("Frame", nil, win); row:SetSize(228, 40); row:SetPoint("TOPLEFT", 8, -40 - (i - 1) * 44)
        local rb = ns.RoundRect(row, 11, { 0.949, 0.702, 0.761 }, "BACKGROUND", 1, 0); rb:SetColor({ 0.949, 0.702, 0.761 }, 0.06)
        local bar = row:CreateTexture(nil, "ARTWORK"); bar:SetTexture(ns.WHITE); bar:SetSize(3, 22); bar:SetPoint("LEFT", 5, 0); bar:SetVertexColor(r[3][1], r[3][2], r[3][3], 1)
        local ic = row:CreateTexture(nil, "ARTWORK"); ic:SetSize(32, 32); ic:SetPoint("LEFT", 14, 0); ic:SetTexture(r[1]); ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        local nm = ns.Font(row, 12.5, r[3]); nm:SetPoint("TOPLEFT", ic, "TOPRIGHT", 9, -1); nm:SetText(r[2])
        local sb = ns.Font(row, 10, { 0.62, 0.54, 0.52 }); sb:SetPoint("TOPLEFT", nm, "BOTTOMLEFT", 0, -2); sb:SetText(r[4])
        if r[5] then local c = row:CreateFontString(nil, "OVERLAY"); c:SetFont(ns.NUM or ns.FONT, 13, "OUTLINE"); c:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", 1, -1); c:SetText(r[5]) end
    end
    local all = Box(win, 120, 26, 13, C.acc); all:SetPoint("BOTTOM", 0, 10)
    local af = ns.Font(all, 12, C.ink); af:SetShadowColor(0, 0, 0, 0); af:SetPoint("CENTER"); af:SetText("모두 줍기")
    local auto = ns.Font(v, 10.5, { 0.66, 0.58, 0.56 }); auto:SetPoint("TOP", win, "BOTTOM", 0, -4)
    function v:Update()
        local d = ns.LootDB and ns.LootDB() or {}
        local sc = (tonumber(d.scale) or 100) / 100
        win:SetScale(sc)
        local al = GetCVar and GetCVar("autoLootDefault") == "1"
        auto:SetText(al and "자동 줍기 켬 · 가방이 차서 남은 것만 이 창" or ((d.pos == "center") and "화면 가운데에 떠요" or "마우스 근처에 떠요"))
        local sw, sh = st:GetWidth() or 640, st:GetHeight() or 160
        self:SetScale(math.max(0.5, math.min(1.2, (sw - 16) / (260 * sc), (sh - 10) / (236 * sc))))
    end
    local spot = XP.Spot(st)
    XP.HLREG.LeelUI_LootWin = { function(k, text)
        if not k or not v:IsVisible() then spot.Off() return end
        spot.Show(win, win, text)
    end, function(a) spot.Alpha(a) end }
    return v
end

-- 르엘 줍기: 시체 위 반짝 상자 (가까운 것 크게 · 나머지 작고 흐리게) · 죽은 몹 이름표
PV.LeelUI_Loot = function(st)
    local M = "Interface\\AddOns\\LeelSpot\\media\\"
    local v = CreateFrame("Frame", nil, st); v:SetSize(480, 190); v:SetPoint("CENTER")
    local function Corpse(x, big)
        local c = CreateFrame("Frame", nil, v); c:SetSize(120, 40); c:SetPoint("BOTTOM", v, "BOTTOMLEFT", x, 18)
        local sh = c:CreateTexture(nil, "BACKGROUND"); sh:SetTexture(ns.MEDIA .. "circle"); sh:SetSize(big and 110 or 80, big and 26 or 18); sh:SetPoint("BOTTOM"); sh:SetVertexColor(0, 0, 0, 0.55)
        local body = c:CreateTexture(nil, "ARTWORK"); body:SetTexture("Interface\\Icons\\Ability_Hunter_Pet_Wolf"); body:SetSize(big and 44 or 32, big and 44 or 32); body:SetPoint("BOTTOM", 0, 6); body:SetDesaturated(true); body:SetVertexColor(0.6, 0.55, 0.55, 1)
        local mk = c:CreateMaskTexture(); mk:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); mk:SetAllPoints(body); body:AddMaskTexture(mk)
        c.body = body
        local box = CreateFrame("Frame", nil, c); box:SetSize(28, 28)
        local gl = box:CreateTexture(nil, "BACKGROUND"); gl:SetTexture(M .. "circle"); gl:SetSize(36, 36); gl:SetPoint("CENTER"); gl:SetBlendMode("ADD"); gl:SetVertexColor(1, 0.85, 0.5, 0.5)
        local bt = box:CreateTexture(nil, "ARTWORK"); bt:SetTexture(M .. "loot_box"); bt:SetAllPoints()
        c.box = box
        -- 죽은 몹 이름표 (0% 빈 바)
        local pl = CreateFrame("Frame", nil, c); pl:SetSize(90, 8); pl:SetPoint("BOTTOM", body, "TOP", 0, 26)
        local pb = pl:CreateTexture(nil, "BACKGROUND"); pb:SetAllPoints(); pb:SetColorTexture(0.11, 0.08, 0.075, 0.9)
        local pn = ns.Font(pl, 10.5, { 0.6, 0.6, 0.6 }); pn:SetPoint("BOTTOM", pl, "TOP", 0, 2); pn:SetText("늑대")
        local pp = ns.Font(pl, 9.5, { 0.6, 0.6, 0.6 }); pp:SetPoint("LEFT", pl, "RIGHT", 4, 0); pp:SetText("0%")
        c.plate = pl
        c.big = big
        return c
    end
    local near = Corpse(170, true)
    local far1 = Corpse(330, false)
    local far2 = Corpse(420, false)
    function v:Update()
        local d = LeelSpotDB or {}
        local on = d.loot ~= false
        local y = tonumber(d.lootY) or -70
        local sz = tonumber(d.lootSize) or 1
        for _, c in ipairs({ near, far1, far2 }) do
            local show = on and (c.big or d.lootMulti ~= false)
            c.box:SetShown(show)
            local k = c.big and sz or sz * 0.65
            c.box:SetScale(k); c.box:SetAlpha(c.big and 1 or 0.55)
            -- 게임은 이름표 가운데 기준 -70 → 미리 보기에선 몸 위쪽 기준으로 줄여서
            c.box:ClearAllPoints(); c.box:SetPoint("CENTER", c.body, "TOP", 0, (70 + y) * 0.35 / k + 10 / k)
            c.plate:SetShown(ns.db.npHideDead == false)
        end
        local sw, sh = st:GetWidth() or 640, st:GetHeight() or 160
        self:SetScale(math.max(0.6, math.min(1.4, (sw - 16) / 480, (sh - 10) / 190)))
    end
    local spot = XP.Spot(st)
    XP.HLREG.LeelUI_Loot = { function(k, text)
        if not k or not v:IsVisible() then spot.Off() return end
        if k == "multi" then spot.Show(far1, far2, text)
        elseif k == "plate" then spot.Show(near.body, near.body, text)
        elseif k == "box" and near.box:IsShown() then spot.Show(near.box, near.box, text)
        else spot.Show(near, far2, text) end
    end, function(a) spot.Alpha(a) end }
    return v
end

-- 상점 토끼: 상인 창 위 결과 판 (판매 · 수리 · 남은 돈)
PV.LeelUI_Shop = function(st)
    local v = CreateFrame("Frame", nil, st); v:SetSize(420, 140); v:SetPoint("CENTER")
    local mer = Box(v, 130, 120, 12, { 0.2, 0.15, 0.12 }); mer:SetPoint("LEFT", 10, 0)
    local mt = ns.Font(mer, 11.5, { 1, 0.84, 0.5 }); mt:SetPoint("TOP", 0, -8); mt:SetText("상인")
    for i = 1, 6 do
        local sl = Box(mer, 30, 30, 6, { 0.3, 0.24, 0.2 }); sl:SetPoint("TOPLEFT", 12 + ((i - 1) % 3) * 36, -30 - math.floor((i - 1) / 3) * 36)
    end
    local rep_ = Box(mer, 106, 18, 9, { 0.35, 0.28, 0.24 }); rep_:SetPoint("BOTTOM", 0, 8)
    local rf = ns.Font(rep_, 10, C.tx); rf:SetPoint("CENTER"); rf:SetText("수리")
    local toast = CreateFrame("Frame", nil, v); toast:SetSize(250, 100); toast:SetPoint("LEFT", mer, "RIGHT", 18, 0)
    ns.RoundPlate(toast, 14, { 0.125, 0.094, 0.086, 0.96 }, { 0.949, 0.702, 0.761, 0.6 })
    local disc = toast:CreateTexture(nil, "ARTWORK"); disc:SetTexture(ns.MEDIA .. "circle"); disc:SetSize(30, 30); disc:SetPoint("TOPLEFT", 14, -12); disc:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    local ic = toast:CreateTexture(nil, "OVERLAY"); ic:SetTexture(ns.MEDIA .. "hb_shop"); ic:SetSize(17, 17); ic:SetPoint("CENTER", disc); ic:SetVertexColor(C.ink[1], C.ink[2], C.ink[3], 1)
    local tt = ns.Font(toast, 13, C.accHi); tt:SetPoint("TOPLEFT", 56, -12); tt:SetText("상점 토끼")
    local rows = {}
    local function Row(i)
        local l = ns.Font(toast, 11.5); l:SetJustifyH("LEFT"); l:SetPoint("TOPLEFT", 56, -34 - (i - 1) * 17)
        local r = ns.Font(toast, 11.5); r:SetJustifyH("RIGHT"); r:SetPoint("TOPRIGHT", -14, -34 - (i - 1) * 17)
        rows[i] = { l, r }
        return l, r
    end
    for i = 1, 3 do Row(i) end
    function v:Update()
        local d = ns.ShopDB and ns.ShopDB() or {}
        local list = {}
        if d.sell then list[#list + 1] = { "회색 잡템 5개 판매", "|cff9fe3a8+1 은 24 동|r", "sell" } end
        if d.repair then list[#list + 1] = { "장비 수리", "|cffff8fa3-3 은 60 동|r", "repair" } end
        list[#list + 1] = { "|cffd6a09c남은 돈|r", "66 금 89 은" }
        for i = 1, 3 do
            local r, e = rows[i], list[i]
            r[1]:SetText(e and e[1] or ""); r[2]:SetText(e and e[2] or "")
            r.key = e and e[3]
        end
        toast:SetHeight(34 + #list * 17 + 12)
        toast:SetShown(d.report ~= false)
        local sw, sh = st:GetWidth() or 640, st:GetHeight() or 160
        self:SetScale(math.max(0.6, math.min(1.4, (sw - 16) / 420, (sh - 10) / 140)))
    end
    local spot = XP.Spot(st)
    XP.HLREG.LeelUI_Shop = { function(k, text)
        if not k or not v:IsVisible() then spot.Off() return end
        if (k == "sell" or k == "repair") and toast:IsShown() then
            for _, r in ipairs(rows) do if r.key == k then spot.Show(r[1], r[2], text) return end end
        end
        if k == "repair" then spot.Show(rep_, rep_, text)
        elseif k == "report" and toast:IsShown() then spot.Show(toast, toast, text)
        else spot.Show(mer, toast:IsShown() and toast or mer, text) end
    end, function(a) spot.Alpha(a) end }
    return v
end

-- 파티 찾기: 가짜 신청자 4명 (실제 창 모양) · 지역 이름 / 거리 말 줄에 마우스 = 그 부분 반짝
PV.LeelUI_LFG = function(st)
    local v = CreateFrame("Frame", nil, st); v:SetSize(560, 176); v:SetPoint("CENTER")
    local box = CreateFrame("Frame", nil, v); box:SetAllPoints()
    ns.RoundPlate(box, 6, { 0.043, 0.035, 0.031, 0.98 }, { 0.35, 0.29, 0.16, 0.9 })
    local GR, PK, YL, GY = { 0.56, 0.91, 0.6 }, C.acc, { 0.94, 0.83, 0.54 }, { 0.66, 0.6, 0.63 }
    local ROWS = {
        { "언데드기사 언기", { 0.78, 0.61, 0.43 }, 37, "아라시 고원", GR, "같은 곳", "배우기", "탱" },
        { "Only Faans", { 0.96, 0.55, 0.73 }, 38, "던전 안", PK, "던전 안", "배우기", "힐" },
        { "다크 시크", { 0.58, 0.51, 0.79 }, 43, "티리스팔 숲", YL, "입구", "여유로움", "딜" },
        { "멀리보는 눈", { 0.25, 0.78, 0.92 }, 41, "은빛소나무 숲", GY, "멀리", "여유로움", "딜" },
    }
    local zs, ts, rws = {}, {}, {}
    local RW, RH = 270, 80
    for i, r in ipairs(ROWS) do
        local row = CreateFrame("Frame", nil, box); row:SetSize(RW, RH)
        row:SetPoint("TOPLEFT", 6 + ((i - 1) % 2) * (RW + 8), -6 - math.floor((i - 1) / 2) * (RH + 4))
        ns.RoundPlate(row, 4, { 0.13, 0.105, 0.075, 1 }, { 0.29, 0.23, 0.14, 1 })
        local n = ns.Font(row, 12.5, r[2]); n:SetPoint("TOPLEFT", 9, -9); n:SetText(ns.L(r[1]))
        local lv = ns.Font(row, 10.5, { 0.8, 0.8, 0.8 }); lv:SetPoint("LEFT", n, "RIGHT", 5, 0); lv:SetText("Lv " .. r[3])
        local dg = ns.Font(row, 11.5, { 0.37, 0.69, 1 }); dg:SetPoint("TOPLEFT", 9, -33); dg:SetText(ns.L("붉은십자군 무기고"))
        local z = ns.Font(row, 11, r[5]); z:SetPoint("LEFT", dg, "RIGHT", 4, 0); z:SetText("· " .. ns.L(r[4]))
        local cm = ns.Font(row, 11.5, { 0.48, 0.82, 0.42 }); cm:SetPoint("TOPLEFT", 9, -56); cm:SetText(ns.L(r[7]))
        local t = ns.Font(row, 11, r[5]); t:SetPoint("LEFT", cm, "RIGHT", 8, 0); t:SetText(ns.L(r[6]))
        local ro = ns.Font(row, 10.5, { 0.87, 0.87, 0.87 }); ro:SetPoint("RIGHT", -9, 0); ro:SetText(ns.L(r[8]))
        zs[i], ts[i], rws[i] = z, t, row
    end
    function v:Update()
        local on = ns.db.lfgLoc ~= false
        for i = 1, 4 do zs[i]:SetShown(on and ns.db.lfgZone ~= false); ts[i]:SetShown(on and ns.db.lfgTag ~= false) end
        local sw, sh = st:GetWidth() or 640, st:GetHeight() or 200
        self:SetScale(math.max(0.5, math.min(1.3, (sw - 16) / 560, (sh - 10) / 176)))
    end
    local spot = XP.Spot(st)
    XP.HLREG.LeelUI_LFG = { function(k, text)
        if not k or not v:IsVisible() then spot.Off() return end
        if k == "zone" then spot.Show(zs[3], zs[3], text)
        elseif k == "tag" then spot.Show(ts[3], ts[3], text)
        else spot.Show(rws[4], rws[4], text) end
    end, function(a) spot.Alpha(a) end }
    return v
end

-- 장비 비교: 장비 툴팁 위에 토끼 + 말풍선 ("끼자! / 그대로 쓰자")
PV.LeelUI_Gear = function(st)
    local v = CreateFrame("Frame", nil, st); v:SetSize(300, 190); v:SetPoint("CENTER")
    local tip = CreateFrame("Frame", nil, v); tip:SetSize(240, 110); tip:SetPoint("BOTTOMLEFT", 10, 6)
    ns.RoundPlate(tip, 12, { 0.114, 0.082, 0.078, 0.97 }, { 0.949, 0.702, 0.761, 0.38 })
    local y = -10
    local function L(t, col, size) local fs = ns.Font(tip, size or 12, col or C.tx); fs:SetPoint("TOPLEFT", 12, y); fs:SetText(t); y = y - (size or 12) - 4; return fs end
    L("늑대 가죽 장화", { 0.12, 1, 0 }, 14); L("발 · 가죽"); L("방어도 74"); L("민첩성 +8  체력 +5"); L("요구 레벨 18", { 0.75, 0.7, 0.68 })
    local bun = CreateFrame("Frame", nil, tip); bun:SetSize(26, 26); bun:SetPoint("CENTER", tip, "TOPRIGHT", -4, -2)
    local b1 = bun:CreateTexture(nil, "BACKGROUND"); b1:SetTexture(ns.MEDIA .. "circle"); b1:SetAllPoints(); b1:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    local b2 = bun:CreateTexture(nil, "ARTWORK"); b2:SetTexture(ns.MEDIA .. "bunny"); b2:SetSize(22, 22); b2:SetPoint("CENTER")
    local bub = CreateFrame("Frame", nil, v); bub:SetSize(200, 46); bub:SetPoint("BOTTOMRIGHT", tip, "TOPRIGHT", 8, 14)
    ns.RoundPlate(bub, 12, { 1, 0.9, 0.93, 0.97 }, { 0.949, 0.702, 0.761, 0.9 })
    local tail = bub:CreateTexture(nil, "ARTWORK"); tail:SetTexture(ns.WHITE); tail:SetSize(10, 10); tail:SetPoint("CENTER", bub, "BOTTOMRIGHT", -14, 0); pcall(tail.SetRotation, tail, math.rad(45)); tail:SetVertexColor(1, 0.9, 0.93, 0.97)
    local l1 = ns.Font(bub, 12.5, { 0.23, 0.11, 0.14 }); l1:SetShadowColor(0, 0, 0, 0); l1:SetPoint("TOPLEFT", 11, -7)
    local l2 = ns.Font(bub, 11, { 0.45, 0.35, 0.37 }); l2:SetShadowColor(0, 0, 0, 0); l2:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -3)
    function v:Update()
        local d = ns.GearDB and ns.GearDB() or {}
        local role = d.role or "auto"
        local name = (ns.GearRoleName or {})[role] or "자동"
        l1:SetText("끼자! 지금 장화보다 좋아")
        l2:SetText(role == "auto" and "민첩성이 올라가 (역할: 특성 보고 짐작)" or ("민첩성이 올라가 (" .. name .. " 기준)"))
        bub:SetWidth(math.max(l1:GetStringWidth(), l2:GetStringWidth()) + 24)
        bub:SetShown(d.on ~= false); bun:SetShown(d.on ~= false)
        local sw, sh = st:GetWidth() or 640, st:GetHeight() or 160
        self:SetScale(math.max(0.6, math.min(1.4, (sw - 16) / 300, (sh - 10) / 190)))
    end
    local spot = XP.Spot(st)
    XP.HLREG.LeelUI_Gear = { function(k, text)
        if not k or not v:IsVisible() then spot.Off() return end
        if bub:IsShown() then spot.Show(bub, bub, text) else spot.Show(tip, tip, text) end
    end, function(a) spot.Alpha(a) end }
    return v
end

-- 미니맵: 르엘 미니맵 (D안) 모양 그대로 · 동그라미 안은 지금 지역의 진짜 지도 (내 위치 둘레를 크게)
PV.LeelUI_Minimap = function(st)
    local v = CreateFrame("Frame", nil, st); v:SetSize(300, 230); v:SetPoint("CENTER")
    local D = 150
    -- 지역 알약
    local zone = CreateFrame("Frame", nil, v); zone:SetHeight(22); zone:SetPoint("TOP", 0, -2)
    ns.RoundPlate(zone, 11, { 0.125, 0.094, 0.086, 0.95 }, { 0.949, 0.702, 0.761, 0.55 })
    local zf = ns.Font(zone, 12.5); zf:SetPoint("CENTER")
    -- 동그라미 지도
    local disc = CreateFrame("Frame", nil, v); disc:SetSize(D, D); disc:SetPoint("TOP", zone, "BOTTOM", 0, -11)
    local function Ring(sz, col, sub) local t = disc:CreateTexture(nil, "BACKGROUND", nil, sub); t:SetTexture(ns.MEDIA .. "mm_round"); t:SetSize(sz, sz); t:SetPoint("CENTER"); t:SetVertexColor(col[1], col[2], col[3], 1) return t end
    Ring(D + 10, { 0.11, 0.08, 0.07 }, 0); Ring(D + 7, C.acc, 1); Ring(D + 1, { 0.11, 0.08, 0.07 }, 2)
    local mask = disc:CreateMaskTexture(); mask:SetTexture(ns.MEDIA .. "mm_round", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); mask:SetAllPoints()
    local bg = disc:CreateTexture(nil, "BORDER"); bg:SetAllPoints(); bg:SetColorTexture(0.22, 0.26, 0.18, 1); bg:AddMaskTexture(mask)
    local tiles, curMap, L = {}, nil, nil
    local ZOOM = 4   -- 지도 한 장을 동그라미 폭의 4배로 = 내 둘레를 가까이
    local function Build(m)
        for _, t in ipairs(tiles) do t:Hide() end
        local okL, layers = pcall(C_Map.GetMapArtLayers, m)
        L = okL and layers and layers[1] or nil
        local okT, texs = pcall(C_Map.GetMapArtLayerTextures, m, 1)
        if not (L and okT and texs) then L = nil return end
        for i, tex in ipairs(texs) do
            local t = tiles[i] or disc:CreateTexture(nil, "ARTWORK"); tiles[i] = t
            if not t.leelMask then t:AddMaskTexture(mask); t.leelMask = true end
            t:SetTexture(tex); t:Show()
        end
        for i = #texs + 1, #tiles do tiles[i]:Hide() end
    end
    local me = disc:CreateTexture(nil, "OVERLAY"); me:SetTexture("Interface\\Minimap\\MinimapArrow"); me:SetSize(24, 24); me:SetPoint("CENTER")
    local px, py = 0.5, 0.5
    local function Lay()
        if not L then return end
        local MW = D * ZOOM
        local s = MW / L.layerWidth
        local cols = math.ceil(L.layerWidth / L.tileWidth)
        local ox, oy = D / 2 - px * MW, -(D / 2 - py * (L.layerHeight * s))
        for i, t in ipairs(tiles) do
            if t:IsShown() then
                local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
                t:SetSize(L.tileWidth * s, L.tileHeight * s)
                t:ClearAllPoints(); t:SetPoint("TOPLEFT", disc, "TOPLEFT", ox + c * L.tileWidth * s, oy - r * L.tileHeight * s)
            end
        end
        local f = GetPlayerFacing and GetPlayerFacing()
        if f then pcall(me.SetRotation, me, f) end
    end
    -- 아래 버튼 줄 (알약 하나에 아이콘 + 칸막이 + 시계) + 오른쪽 토끼
    local bar = CreateFrame("Frame", nil, v); bar:SetHeight(32); bar:SetPoint("TOP", disc, "BOTTOM", -18, -10)
    ns.RoundPlate(bar, 16, { 0.125, 0.094, 0.086, 0.95 }, { 0.949, 0.702, 0.761, 0.55 })
    local ICONS = { "Interface\\Minimap\\Tracking\\Mailbox", "Interface\\Minimap\\Tracking\\None", ns.MEDIA .. "hb_apps" }
    local x = 6
    for _, ic in ipairs(ICONS) do
        local t = bar:CreateTexture(nil, "ARTWORK"); t:SetTexture(ic); t:SetSize(18, 18); t:SetPoint("CENTER", bar, "LEFT", x + 12, 0)
        if ic:find("hb_") then t:SetVertexColor(C.accHi[1], C.accHi[2], C.accHi[3], 1) end
        x = x + 28
    end
    local sep = bar:CreateTexture(nil, "ARTWORK"); sep:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.3); sep:SetSize(1, 16); sep:SetPoint("CENTER", bar, "LEFT", x + 4, 0)
    x = x + 8
    local clock = CreateFrame("Frame", nil, bar); clock:SetSize(50, 22); clock:SetPoint("LEFT", bar, "LEFT", x, 0)
    local cf = ns.Num(clock, 14, C.accHi); cf:SetPoint("CENTER")
    bar:SetWidth(x + 52)
    local bun = CreateFrame("Frame", nil, v); bun:SetSize(28, 28); bun:SetPoint("LEFT", bar, "RIGHT", 6, 0)
    local b1 = bun:CreateTexture(nil, "BACKGROUND"); b1:SetTexture(ns.MEDIA .. "circle"); b1:SetAllPoints(); b1:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    local b2 = bun:CreateTexture(nil, "ARTWORK"); b2:SetTexture(ns.MEDIA .. "bunny"); b2:SetSize(24, 24); b2:SetPoint("CENTER")
    local function Where()
        local m = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        local x_, y_
        if m then local ok, p = pcall(C_Map.GetPlayerMapPosition, m, "player"); if ok and p then x_, y_ = p:GetXY() end end
        return m, x_, y_
    end
    local function Text()
        local db = ns.db
        local z = (GetMinimapZoneText and GetMinimapZoneText()) or ""
        if db.mmCoords ~= false then z = z .. ("   |cffd6a09c%.1f, %.1f|r"):format(px * 100, py * 100) end
        zf:SetText(z); zone:SetWidth(math.max(60, zf:GetStringWidth() + 24))
        local mode = db.mmClock
        local h, mi = GetGameTime()
        local t = (mode == "local" or (mode == nil and GetCVarBool and GetCVarBool("timeMgrUseLocalTime"))) and date("%H:%M") or ("%d:%02d"):format(h, mi)
        cf:SetText(t)
    end
    function v:Update()
        local db = ns.db
        local m, x_, y_ = Where()
        if m and m ~= curMap then curMap = m; Build(m) end
        if x_ then px, py = x_, y_ end
        Lay(); Text()
        zone:SetShown(db.mmZone ~= false)
        bun:SetShown(not db.minimap.hide)
        local sw, sh = st:GetWidth() or 640, st:GetHeight() or 160
        self:SetScale(math.max(0.6, math.min(1.4, (sw - 16) / 300, (sh - 6) / 232)))
    end
    local acc = 0
    v:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc < 0.2 then return end
        acc = 0
        local m, x_, y_ = Where()
        if m and m ~= curMap then curMap = m; Build(m) end
        if x_ then px, py = x_, y_ end
        Lay(); Text()
    end)
    local spot = XP.Spot(st)
    function ns.MMPvHLAlpha(a) spot.Alpha(a) end
    function ns.MMPvHL(k, text)
        if not k or not v:IsVisible() then spot.Off() return end
        if k == "zone" then if zone:IsShown() then spot.Show(zone, zone, text) else spot.Show(disc, disc, text) end
        elseif k == "clock" then spot.Show(clock, clock, text)
        elseif k == "map" then spot.Show(disc, disc, text)
        elseif k == "bunny" then spot.Show(bun, bun, text)
        elseif k == "bar" then spot.Show(bar, bar, text)
        else spot.Show(zone, bun, text) end
    end
    return v
end

-- 단축바 주문 레벨: 화면 위 알약 + 단축바 칸 (직업 색 테 · ↑ · 지금 레벨)
PV.LeelUI_RankUp = function(st)
    local v = CreateFrame("Frame", nil, st); v:SetSize(520, 170); v:SetPoint("CENTER")
    local function RD() return (ns.RankDB and ns.RankDB()) or {} end
    -- 알약
    local toast = CreateFrame("Frame", nil, v); toast:SetSize(440, 32); toast:SetPoint("TOP", 0, -6)
    ns.RoundPlate(toast, 16, { 0.125, 0.094, 0.086, 0.97 }, { 0.949, 0.702, 0.761, 0.85 })
    -- 되살리기 그림은 게임에서 바로 (판마다 그림이 달라서)
    local ICON = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(20484)) or (GetSpellTexture and GetSpellTexture(20484)) or "Interface\\Icons\\Spell_Nature_Reincarnation"
    local ti = toast:CreateTexture(nil, "ARTWORK"); ti:SetSize(24, 24); ti:SetPoint("LEFT", 5, 0); ti:SetTexture(ICON)
    local mk = toast:CreateMaskTexture(); mk:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); mk:SetAllPoints(ti); ti:AddMaskTexture(mk)
    local tf = ns.Font(toast, 12.5); tf:SetPoint("LEFT", ti, "RIGHT", 8, 0); tf:SetText("|cffffd0db되살리기 4레벨|r 배웠어요 · 단축바 |cffff9a4d1칸|r은 아직 3레벨")
    local b2 = Box(toast, 54, 20, 10, { 0.42, 0.35, 0.34 }); b2:SetPoint("RIGHT", -6, 0)
    local b2i = Box(b2, 52, 18, 9, { 0.125, 0.094, 0.086 }); b2i:SetPoint("CENTER")
    local b2t = ns.Font(b2i, 11.5); b2t:SetPoint("CENTER"); b2t:SetText("그대로")   -- 안쪽 판 위에 (밑에 깔리면 안 보여요)
    local b1 = Box(toast, 54, 20, 10, C.acc); b1:SetPoint("RIGHT", b2, "LEFT", -5, 0)
    local b1t = ns.Font(b1, 11.5, C.ink); b1t:SetShadowColor(0, 0, 0, 0); b1t:SetPoint("CENTER"); b1t:SetText("바꾸기")
    -- 단축바
    local ICONS = { "Spell_Nature_Rejuvenation", "Spell_Nature_HealingTouch", "Spell_Nature_StarFall", "Ability_Druid_Maul",
                    "Spell_Nature_Reincarnation", "Spell_Nature_Regeneration", "Ability_Racial_BearForm", "Spell_Nature_Thorns" }
    local bar = CreateFrame("Frame", nil, v); bar:SetSize(8 * 44 + 8, 52); bar:SetPoint("BOTTOM", 0, 8)
    local bbg = bar:CreateTexture(nil, "BACKGROUND"); bbg:SetAllPoints(); bbg:SetColorTexture(0, 0, 0, 0.45)
    local slot
    for i, ic in ipairs(ICONS) do
        local b = CreateFrame("Frame", nil, bar); b:SetSize(40, 40); b:SetPoint("LEFT", 6 + (i - 1) * 44, 0)
        local t = b:CreateTexture(nil, "ARTWORK"); t:SetAllPoints(); t:SetTexture(i == 5 and ICON or ("Interface\\Icons\\" .. ic)); t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if i == 5 then slot = b end
    end
    local m = CreateFrame("Frame", nil, slot); m:SetAllPoints(); m:SetFrameLevel(slot:GetFrameLevel() + 5)
    local edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = m:CreateTexture(nil, "OVERLAY"); e:SetTexture(ns.WHITE)
        if side == "TOP" or side == "BOTTOM" then e:SetPoint(side .. "LEFT", -1, 0); e:SetPoint(side .. "RIGHT", 1, 0); e:SetHeight(2)
        else e:SetPoint("TOP" .. side, 0, 1); e:SetPoint("BOTTOM" .. side, 0, -1); e:SetWidth(2) end
        edges[#edges + 1] = e
    end
    local glow = m:CreateTexture(nil, "BACKGROUND"); glow:SetTexture(ns.MEDIA .. "soft_glow"); glow:SetBlendMode("ADD"); glow:SetPoint("TOPLEFT", -10, 10); glow:SetPoint("BOTTOMRIGHT", 10, -10)
    local badge = CreateFrame("Frame", nil, m); badge:SetSize(16, 16); badge:SetPoint("CENTER", m, "TOPRIGHT", -2, -2); badge:SetFrameLevel(m:GetFrameLevel() + 2)
    local bk = badge:CreateTexture(nil, "BACKGROUND"); bk:SetTexture(ns.MEDIA .. "circle"); bk:SetPoint("TOPLEFT", -1.5, 1.5); bk:SetPoint("BOTTOMRIGHT", 1.5, -1.5); bk:SetVertexColor(0, 0, 0, 0.9)
    local disc = badge:CreateTexture(nil, "ARTWORK"); disc:SetTexture(ns.MEDIA .. "circle"); disc:SetAllPoints()
    local ar = badge:CreateTexture(nil, "OVERLAY"); ar:SetTexture(ns.MEDIA .. "np_arrow"); ar:SetSize(10, 10); ar:SetPoint("CENTER"); pcall(ar.SetRotation, ar, math.pi); ar:SetVertexColor(0.1, 0.07, 0.06, 1)
    local rk = m:CreateFontString(nil, "OVERLAY"); rk:SetFont(ns.NUM or ns.FONT, 12, "OUTLINE"); rk:SetPoint("BOTTOMRIGHT", -2, 2); rk:SetText("3")
    function v:Update()
        local d = RD()
        toast:SetShown(d.toast ~= false)
        m:SetShown(d.mark ~= false)
        local col = (ns.RankClassCol and ns.RankClassCol()) or C.acc
        for _, e in ipairs(edges) do e:SetVertexColor(col[1], col[2], col[3], 1) end
        glow:SetVertexColor(col[1], col[2], col[3], 0.6); disc:SetVertexColor(col[1], col[2], col[3], 1)
        local sw, sh = st:GetWidth() or 640, st:GetHeight() or 160
        self:SetScale(math.max(0.6, math.min(1.4, (sw - 16) / 520, (sh - 10) / 170)))
    end
    local spot = XP.Spot(st)
    function ns.RankPvHLAlpha(a) spot.Alpha(a) end
    function ns.RankPvHL(k, text)
        if not k or not v:IsVisible() then spot.Off() return end
        if k == "toast" then spot.Show(toast, toast, text)
        elseif k == "mark" then spot.Show(slot, slot, text)
        else spot.Show(toast, bar, text) end
    end
    return v
end

-- 그 밖의 기능: 큰 아이콘 + 미리 보기 안내
local function Generic(st)
    local v = CreateFrame("Frame", nil, st); v:SetSize(240, 140); v:SetPoint("CENTER")
    v.disc = IconDisc(v, 72, "icon"); v.disc:SetPoint("TOP", 0, -6)
    v.disc.bg:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.16)
    v.disc.ic:SetVertexColor(C.accHi[1], C.accHi[2], C.accHi[3], 1)
    v.t = ns.Font(v, 14); v.t:SetPoint("TOP", v.disc, "BOTTOM", 0, -10)
    v.s = ns.Font(v, 11, C.tx2); v.s:SetPoint("TOP", v.t, "BOTTOM", 0, -6)
    v.s:SetWidth(240); v.s:SetJustifyH("CENTER")
    function v:Update(m)
        self.disc.ic:SetTexture(ns.MEDIA .. m.icon)
        self.t:SetText(m.title)
        self.s:SetText(m.sub or "")
    end
    return v
end

local function BuildPreview(f)
    local pv = CreateFrame("Frame", nil, f)
    pv.plate = { ns.RoundPlate(pv, 14, { 0.07, 0.05, 0.045, 0.95 }, { 0.949, 0.702, 0.761, 0.25 }) }
    local t = ns.Font(pv, 12.5, C.accHi); t:SetPoint("TOPLEFT", 14, -10); t:SetText("미리 보기")
    pv.note = ns.Font(pv, 10.5, C.tx2); pv.note:SetPoint("LEFT", t, "RIGHT", 12, 0)
    pv.btn = ns.MakeButton(pv, "게임에서 보기", false, nil, 110)
    pv.btn:SetHeight(24); pv.btn:SetPoint("TOPRIGHT", -8, -5)
    local st = CreateFrame("Frame", nil, pv)
    st:SetPoint("TOPLEFT", 8, -32); st:SetPoint("BOTTOMRIGHT", -8, 8)
    st:SetClipsChildren(true)
    local glow = st:CreateTexture(nil, "BACKGROUND"); glow:SetTexture(ns.MEDIA .. "soft_glow"); glow:SetBlendMode("ADD")
    glow:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.10); glow:SetSize(700, 260); glow:SetPoint("CENTER")
    pv.stage = st
    pv.off = ns.Font(pv, 12, C.tx2); pv.off:SetPoint("CENTER", st, "CENTER"); pv.off:SetText("꺼져 있어요 · 위 '쓰기' 스위치로 켜 보세요")
    pv.views = {}
    function pv:Wants(m)
        return m and not m.news and (PV[m.key] or PREVIEW[m.key]) and true or false
    end
    function pv:Update()
        local m = MODULES[sel]
        if not m then return end
        if self.lastKey ~= m.key then
            self.lastKey = m.key
            for _, o in ipairs(XP.spots or {}) do pcall(o.Off) end
            if ns.HudPvHL then pcall(ns.HudPvHL, nil) end
            if ns.NPPvHL then pcall(ns.NPPvHL, nil) end
        end
        for _, vw in pairs(self.views) do vw:Hide() end
        local key = PV[m.key] and m.key or "_generic"
        local on = MLoaded(m) and not (m.onoff and not m.onoff.get())
        self.off:SetShown(not on)
        if on then
            local vw = self.views[key]
            if not vw then local ok, r = pcall(PV[m.key] or Generic, self.stage); vw = ok and r or nil; self.views[key] = vw end
            if vw then
                local ok = pcall(vw.Update, vw, m)
                vw:SetShown(ok)
            end
        end
        local p = PREVIEW[m.key]
        local lt = LiveText and LiveText(m)
        -- Leel HUD 가운데 탭: 단추 대신 [비전투 | 전투 중] (모형이 그 모습으로)
        local isCenter = false
        if m.tabs and m.key == "LeelUI" then
            local groups = Groups(m)
            local g = groups[math.min(curTab[m.key] or 1, #groups)]
            isCenter = (g and g.head and g.head.pv == "center") and true or false
            p = nil
        end
        if false and isCenter and MLoaded(m) then   -- 고르기는 오른쪽 크기 줄 아래로 옮겼어요
            if not self.fseg then
                local fs = CreateFrame("Frame", nil, self); fs:SetSize(150, 24)
                fs:SetPoint("TOPRIGHT", -8, -5)
                ns.RoundRect(fs, 12, { 0.1, 0.075, 0.07 }, "BACKGROUND", 0, 0)
                fs.b = {}
                for i, lab in ipairs({ "비전투", "전투 중" }) do
                    local b = CreateFrame("Button", nil, fs); b:SetSize(72, 20); b:SetPoint("LEFT", 2 + (i - 1) * 74, 0)
                    b.bg = ns.RoundRect(b, 10, C.acc, "ARTWORK", 0, 0)
                    b.fs = ns.Font(b, 11.5, C.tx); b.fs:SetPoint("CENTER"); b.fs:SetText(lab)
                    b:SetScript("OnClick", function()
                        ns.hudPvFight = (i == 2); ns.hudPvFightManual = (i == 2)
                        if hub and hub.pane then hub.pane.sf:SetVerticalScroll(0) end
                        if ShowPane then ShowPane() else self:Update() end
                    end)
                    fs.b[i] = b
                end
                self.fseg = fs
            end
            for i, b in ipairs(self.fseg.b) do
                local on = (i == 2) == (ns.hudPvFight and true or false)
                b.bg:SetColor(C.acc, on and 1 or 0)
                local c = on and C.ink or C.tx2
                b.fs:SetTextColor(c[1], c[2], c[3]); b.fs:SetShadowColor(0, 0, 0, on and 0 or 0.85)
            end
            self.fseg:Show()
        elseif self.fseg then
            self.fseg:Hide()
        end
        if p and MLoaded(m) then
            self.btn:SetLabel(p[1]); self.btn:SetHeight(24); self.btn:SetScript("OnClick", p[2]); self.btn:Show()
        else
            self.btn:Hide()
        end
        local vw = on and self.views[key]
        local z = vw and vw.zoom
        local zt = z and ("  ·  실제 크기의 |cffffd6e0%d%%|r로 줄여 보여줘요 (비율은 그대로)"):format(math.floor(z * 100 + 0.5)) or ""
        if m.explain then   -- 좁은 칸: 짧게
            self.note:SetText(z and ("실제 크기의 |cffffd6e0%d%%|r"):format(math.floor(z * 100 + 0.5)) or "설정을 바꾸면 바로 바뀌어요")
        else
            self.note:SetText((lt and ("|cff7fd67a●|r " .. lt) or "설정을 바꾸면 바로 바뀌어요") .. zt)
        end
    end
    return pv
end


----------------------------------------------------------------------
-- 진짜 UI를 미리 보기 칸으로 잠깐 옮겨 오기 (전투 밖에서만, 떠나면 제자리)
----------------------------------------------------------------------
local DOCK = {}   -- 진짜 UI는 옮기지 않아요 (미리 보기는 같은 코드로 만든 모형)
local dock -- { frame, pts, scale, strata, key }
local function Undock()
    local d = dock
    if not d then return end
    dock = nil
    local function back()
        local fr = d.frame
        fr:SetScale(d.scale)
        fr:ClearAllPoints()
        for _, p in ipairs(d.pts) do fr:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
        fr:SetFrameStrata(d.strata)
    end
    if InCombatLockdown() then ns:RunOutOfCombat("hubUndock", back) else back() end
end
local function DockFor(m)
    Undock()
    if not hub or not hub:IsShown() or InCombatLockdown() or ns.moving then return end
    local get = m and DOCK[m.key]
    local fr = get and get()
    if not fr or not hub.pv or not MLoaded(m) or (m.onoff and not m.onoff.get()) then return end
    if not fr:IsShown() then return end
    local st = hub.pv.stage
    local cx, cy = st:GetCenter()
    local fw, fh = fr:GetWidth(), fr:GetHeight()
    if not cx or not fw or fw < 1 or fh < 1 then return end
    local d = { frame = fr, pts = {}, scale = fr:GetScale(), strata = fr:GetFrameStrata(), key = m.key }
    for i = 1, fr:GetNumPoints() do d.pts[i] = { fr:GetPoint(i) } end
    -- 실제로 보이는 부분만 (대상이 없으면 내 쪽만) 묶어서 칸 가운데에 크게
    local L, B, R, T
    local function add(o)
        if not (o and o.IsVisible and o:IsVisible() and o.GetRect) then return end
        local ok, l, b, w, h = pcall(o.GetRect, o)
        if not ok or not l or not w or w < 2 or h < 2 then return end
        local e = o:GetEffectiveScale()
        l, b, w, h = l * e, b * e, w * e, h * e
        L = L and math.min(L, l) or l; B = B and math.min(B, b) or b
        R = R and math.max(R, l + w) or l + w; T = T and math.max(T, b + h) or b + h
    end
    for _, ch in ipairs({ fr:GetChildren() }) do add(ch) end
    if not L then add(fr) end
    if not L then return end
    local fe = fr:GetEffectiveScale()
    local fcx, fcy = fr:GetCenter()
    fcx, fcy = fcx * fe, fcy * fe
    local se = st:GetEffectiveScale()
    local k = math.min(1.6, (st:GetWidth() * se * 0.92) / (R - L), (st:GetHeight() * se * 0.88) / (T - B))
    local dx, dy = (L + R) / 2 - fcx, (B + T) / 2 - fcy      -- 보이는 덩어리 가운데가 프레임 가운데에서 얼마나 떨어졌나
    fr:SetScale(d.scale * k)
    local es = fr:GetEffectiveScale()
    fr:ClearAllPoints()
    fr:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (cx * se - dx * k) / es, (cy * se - dy * k) / es)
    fr:SetFrameStrata("FULLSCREEN_DIALOG")
    dock = d
end
Docked = function(m) return dock and m and dock.key == m.key end
-- 설정을 바꿀 땐 제자리로 돌려놓고 바꾼 뒤 다시 옮겨 와요 (위치 저장이 꼬이지 않게)
Apply = function(fn)
    local had = dock and MODULES[sel]
    if had then Undock() end
    pcall(fn)
    if had then C_Timer.After(0.08, function() if hub and hub:IsShown() then DockFor(MODULES[sel]); if hub.pv then hub.pv:Update() end end end) end
end
do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:SetScript("OnEvent", function() Undock() end)   -- 전투 들어가기 직전엔 아직 옮길 수 있어요
end

----------------------------------------------------------------------
-- 진짜 모습 띄우기: 허브에서 기능을 고르면 게임 화면에 실제 UI를 미리 보기로
-- (다른 기능으로 옮기거나 허브를 닫으면 원래대로)
----------------------------------------------------------------------
local LIVE = {
    LeelUI = {
        on = function()
            local c = ns.hudCenter
            if not c or UnitAffectingCombat("player") then return end
            c:Awaken(true)
            if not c:IsShown() and c.ShowDist then c:ShowDist() end
            return true
        end,
        off = function() local c = ns.hudCenter; if c and not UnitAffectingCombat("player") then c:Awaken(false) end end,
        text = "화면 가운데 토끼가 각성 모습으로 떠 있어요",
    },
    LeelUI_Party = {
        on = function()
            if InCombatLockdown() or not ns.SetPartyPreview or not ns.party then return end
            if ns.party.preview then return end
            ns:SetPartyPreview(true); return true
        end,
        off = function() if ns.party and ns.party.preview and not ns.party.dispelTest and ns.SetPartyPreview then ns:SetPartyPreview(false) end end,
        text = "화면에 가짜 파티가 떠 있어요 (진짜 파티 창)",
    },
    -- 시전바: 허브 모형이 진짜와 같은 모양이라 화면 예시는 안 띄워요 (다른 탭과 같은 미리 보기 틀)
    -- 주사위 창: 탭을 열어도 진짜 창은 안 띄워요 (허브 모형이 같은 모양 · [실제 자리에서 보기] 로만)
    LeelUI_Loot = {
        on = function() if LeelSpotAPI and LeelSpotAPI.Preview then LeelSpotAPI.Preview(600); return true end end,
        off = function() if LeelSpotAPI and LeelSpotAPI.Preview then LeelSpotAPI.Preview(0) end end,
        text = "화면에 반짝 상자가 떠 있어요",
    },
    LeelUI_Bags = {
        on = function()
            local w = _G.LeelUI_Bag
            if w and not w:IsShown() and ns.ToggleLeelBag then ns.ToggleLeelBag(); return true end
            if not w and ns.ToggleLeelBag then ns.ToggleLeelBag(); return true end
        end,
        off = function() local w = _G.LeelUI_Bag; if w and w:IsShown() and ns.ToggleLeelBag then ns.ToggleLeelBag() end end,
        text = "르엘 가방 창이 열려 있어요",
    },
}
local liveKey, liveOn
LiveOff = function()
    Undock()
    if liveKey and liveOn and LIVE[liveKey] then pcall(LIVE[liveKey].off) end
    liveKey, liveOn = nil, nil
end
LiveFor = function(m)
    local key = m and m.key
    if key == liveKey then return end
    LiveOff()
    liveKey = key
    local L = LIVE[key]
    if L and MLoaded(m) and not (m.onoff and not m.onoff.get()) then
        local ok, r = pcall(L.on)
        liveOn = ok and r or nil
    end
    -- 진짜 UI를 미리 보기 칸으로 (화면에 떠 있을 때)
    C_Timer.After(0.05, function()
        if liveKey == key then DockFor(m); if hub and hub.pv then hub.pv:Update() end end
    end)
end
LiveText = function(m)
    local L = m and LIVE[m.key]
    return (L and liveKey == m.key and liveOn) and L.text or nil
end


-- 오른쪽 좁은 허브 (크기 · 위치) ↔ 넓은 허브
SetCompact = function(on)
    local f = hub
    on = on and true or false
    if (f.compact or false) == on then return end
    f.compact = on
    local wide = { f.side, f.sideBgF, f.search, f.moveBtn, f.talkBtn, f.hintF, f.reloadBtn, f.pane.tb, f.pane.hd }
    for _, o in ipairs(wide) do if o then o:SetShown(not on) end end
    if f.sideBg then f.sideBg:SetShown(not on) end
    if f.vline then f.vline:SetShown(not on) end
    if f.hint then f.hint:SetShown(not on) end
    if f.pv and on then f.pv:Hide() end
    f.cHead:SetShown(on); f.expandBtn:SetShown(on)
    f:ClearAllPoints()
    if on then
        f:SetSize(CMP_W, math.min(H, (UIParent:GetHeight() or 800) - 120))
        f:SetPoint("RIGHT", UIParent, "RIGHT", -14, 0)
    else
        f:SetSize(W, H)
        local p = ns.db.hub.pos2
        if p then f:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else f:SetPoint("CENTER", 0, 30) end
    end
    f.pane.sf:SetVerticalScroll(0)
    C_Timer.After(0, function() if f:IsShown() then ShowPane() end end)
end

----------------------------------------------------------------------
-- 화면에서 조절 (B안): 허브를 닫고 진짜 UI에 손잡이
-- 끌기 = 옮기기 · 모서리 끌기 / 휠 = 크기 · Enter = 완료 · Esc = 취소(처음 그대로)
----------------------------------------------------------------------
local function Snap(t) return t and CopyTable(t) or nil end
EDIT = {
    LeelUI = {
        label = "Leel HUD", min = 50, max = 150,
        hide = { ["Leel HUD 크기"] = true },
        frame = function() return ns.hud end,
        get = function() return math.floor((ns.db.scale or 0.7) * 100 + 0.5) end,
        set = function(v) ns:SetHudScale(v / 100) end,
        save = function(fr)
            local x, y = fr:GetCenter()
            ns.db.point = { "CENTER", "BOTTOMLEFT", math.floor(x + 0.5), math.floor(y + 0.5) }
            ns:ApplyPosition()
        end,
        reset = function() ns:ResetPosition() end,
        snapshot = function() return { s = ns.db.scale, p = Snap(ns.db.point), parts = Snap(ns.db.hudParts) } end,
        -- 조절하는 동안 대상 · 펫 · 가운데 · 시전바도 예시로 다 보이게 (이동 모드와 같은 예시)
        prep = function() if ns.SetPreview and not ns.moving then ns:SetPreview(true); return true end end,
        unprep = function() if ns.SetPreview and not ns.moving then ns:SetPreview(false) end end,
        restore = function(s)
            ns:SetHudScale(s.s or 0.7)
            ns.db.point = s.p; ns:ApplyPosition()
            ns.db.hudParts = s.parts; if ns.ApplyHudParts then ns:ApplyHudParts() end
        end,
    },
    LeelUI_Party = {
        label = "파티 프레임", min = 50, max = 150,
        hide = { ["파티 프레임 크기"] = true },
        frame = function() return ns.party end,
        get = function() return math.floor((ns.db.partyScale or 0.75) * 100 + 0.5) end,
        set = function(v) ns:SetPartyScale(v / 100) end,
        save = function(fr)
            local x, y = fr:GetCenter()
            ns.db.partyPoint = { "CENTER", "BOTTOMLEFT", math.floor(x + 0.5), math.floor(y + 0.5) }
            ns:ApplyPartyPosition()
        end,
        reset = function() ns:ResetPartyPosition() end,
        snapshot = function() return { s = ns.db.partyScale, p = Snap(ns.db.partyPoint) } end,
        restore = function(s) ns:SetPartyScale(s.s or 0.75); ns.db.partyPoint = s.p; ns:ApplyPartyPosition() end,
        prep = function()
            if ns.party and not ns.party.preview and ns.SetPartyPreview then ns:SetPartyPreview(true); return true end
        end,
        unprep = function() if ns.SetPartyPreview then ns:SetPartyPreview(false) end end,
    },
    LeelUI_Bags = {
        label = "르엘 가방", min = 70, max = 130,
        hide = { ["가방 창 크기"] = true },
        frame = function() return _G.LeelUI_Bag end,
        get = function() return tonumber(ns.BagsDB().scale) or 100 end,
        set = function(v) ns.BagsDB().scale = v; if ns.BagsApplySize then ns.BagsApplySize() end end,
        save = function(fr) local p, _, rp, x, y = fr:GetPoint(); ns.BagsDB().winPos = { p, rp, x, y } end,
        reset = function() ns.BagsDB().winPos = nil; local w = _G.LeelUI_Bag; if w and w.Place then w.Place() end end,
        snapshot = function() local d = ns.BagsDB(); return { s = d.scale, p = Snap(d.winPos) } end,
        restore = function(s)
            local d = ns.BagsDB(); d.scale, d.winPos = s.s, s.p
            if ns.BagsApplySize then ns.BagsApplySize() end
            local w = _G.LeelUI_Bag; if w and w.Place then w.Place() end
        end,
        prep = function()
            local w = _G.LeelUI_Bag
            if not (w and w:IsShown()) and ns.ToggleLeelBag then ns.ToggleLeelBag(); return true end
        end,
        unprep = function() local w = _G.LeelUI_Bag; if w and w:IsShown() and ns.ToggleLeelBag then ns.ToggleLeelBag() end end,
    },
}

local ed, edBar
local edState   -- { key, E, snap, prepped, fr }
local EditFinish

local function EditPaint()
    if not edState then return end
    local v = edState.E.get()
    edBar.val:SetText(v .. "%")
    ed.bubble:SetText(edState.E.label .. "  " .. v .. "%")
end

local function EditSet(v)
    local E = edState.E
    v = math.max(E.min, math.min(E.max, math.floor(v + 0.5)))
    if v ~= E.get() then pcall(E.set, v) end
    EditPaint()
end

local function EditBuild()
    ed = CreateFrame("Frame", nil, UIParent)
    ed:SetFrameStrata("FULLSCREEN_DIALOG")
    ed:EnableMouse(true); ed:EnableMouseWheel(true)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = ed:CreateTexture(nil, "BORDER")
        e:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 1)
        if side == "TOP" or side == "BOTTOM" then e:SetPoint(side .. "LEFT", -2, 0); e:SetPoint(side .. "RIGHT", 2, 0); e:SetHeight(2)
        else e:SetPoint("TOP" .. side, 0, 2); e:SetPoint("BOTTOM" .. side, 0, -2); e:SetWidth(2) end
    end
    ed.bubble = ns.Font(ed, 13, C.ink); ed.bubble:SetShadowColor(0, 0, 0, 0)
    local bb = CreateFrame("Frame", nil, ed); bb:SetHeight(24)
    bb:SetPoint("BOTTOM", ed, "TOP", 0, 6)
    ns.RoundRect(bb, 12, C.acc, "BACKGROUND", 0, 0)
    ed.bubble:SetParent(bb); ed.bubble:SetPoint("CENTER", bb, "CENTER", 0, 0)
    bb:SetScript("OnUpdate", function(self) self:SetWidth(ed.bubble:GetStringWidth() + 24) end)
    bb:Hide()   -- 크기는 위 도구 줄에 보여요
    local tip = ns.Font(ed, 11.5, C.tx); tip:SetPoint("TOP", ed, "BOTTOM", 0, -8)
    tip:SetText("모서리 끌기 / 휠 = 크기 (Shift = 1%씩)  ·  Enter = 완료  ·  Esc = 취소")
    local tipBg = ed:CreateTexture(nil, "BACKGROUND"); tipBg:SetColorTexture(0, 0, 0, 0.6)
    tipBg:SetPoint("TOPLEFT", tip, "TOPLEFT", -10, 4); tipBg:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", 10, -4)

    -- 모서리 손잡이: 끌면 크기
    for _, pt in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local h = CreateFrame("Button", nil, ed)
        h:SetSize(18, 18); h:SetPoint("CENTER", ed, pt, 0, 0)
        h:SetFrameLevel(ed:GetFrameLevel() + 5)
        local o = h:CreateTexture(nil, "ARTWORK"); o:SetTexture(ns.MEDIA .. "circle"); o:SetAllPoints(); o:SetVertexColor(C.acc[1], C.acc[2], C.acc[3])
        local i = h:CreateTexture(nil, "OVERLAY"); i:SetTexture(ns.MEDIA .. "circle"); i:SetPoint("TOPLEFT", 4, -4); i:SetPoint("BOTTOMRIGHT", -4, 4)
        h:SetScript("OnMouseDown", function()
            local fr = edState and edState.fr
            if not fr then return end
            local s = UIParent:GetEffectiveScale()
            local mx, my = GetCursorPosition(); mx, my = mx / s, my / s
            local cx, cy = ed:GetCenter()
            ed.scaling = { v0 = edState.E.get(), cx = cx, cy = cy, d0 = math.max(10, math.sqrt((mx - cx) ^ 2 + (my - cy) ^ 2)) }
        end)
        h:SetScript("OnMouseUp", function() ed.scaling = nil end)
    end
    ed:SetScript("OnUpdate", function(self)
        local sc = self.scaling
        if not sc then return end
        local s = UIParent:GetEffectiveScale()
        local mx, my = GetCursorPosition(); mx, my = mx / s, my / s
        local d = math.sqrt((mx - sc.cx) ^ 2 + (my - sc.cy) ^ 2)
        local v = math.floor(sc.v0 * d / sc.d0 / 2 + 0.5) * 2
        if v ~= sc.last then sc.last = v; EditSet(v) end
    end)
    ed:SetScript("OnMouseWheel", function(_, d)
        if edState then EditSet(edState.E.get() + d * (IsShiftKeyDown() and 1 or 5)) end
    end)
    ed:EnableKeyboard(true)
    ed:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:SetPropagateKeyboardInput(false); EditFinish(false)
        elseif key == "ENTER" then self:SetPropagateKeyboardInput(false); EditFinish(true)
        else self:SetPropagateKeyboardInput(true) end
    end)

    -- 도구 줄 (화면 위 가운데)
    edBar = CreateFrame("Frame", nil, UIParent)
    edBar:SetFrameStrata("FULLSCREEN_DIALOG"); edBar:SetHeight(40)
    edBar:SetClampedToScreen(true)
    edBar:EnableMouse(true)
    ns.RoundPlate(edBar, 20, { 0.11, 0.08, 0.075, 0.97 }, { 0.949, 0.702, 0.761, 0.8 })
    edBar.title = ns.Font(edBar, 15); edBar.title:SetPoint("LEFT", 18, 0)
    local x = edBar.title
    local function Btn(text, primary, fn, w)
        local b = ns.MakeButton(edBar, text, primary, fn, w)
        b:SetPoint("LEFT", x, "RIGHT", 8, 0); x = b
        return b
    end
    edBar.minus = Btn("−", false, function() if edState then EditSet(edState.E.get() - 5) end end, 34)
    edBar.val = ns.Num(edBar, 20, C.accHi); edBar.val:SetPoint("LEFT", x, "RIGHT", 10, 0); edBar.val:SetWidth(54)
    local holder = CreateFrame("Frame", nil, edBar); holder:SetSize(54, 20); holder:SetPoint("LEFT", edBar.minus, "RIGHT", 10, 0)
    x = holder
    edBar.plus = Btn("+", false, function() if edState then EditSet(edState.E.get() + 5) end end, 34)
    edBar.reset = Btn("처음 크기", false, function()
        if not edState then return end
        local E = edState.E
        if edState.key == "LeelUI" then EditSet(math.floor((ns.defaults.scale or 0.61) * 100 + 0.5)) elseif edState.key == "LeelUI_Party" then EditSet(math.floor((ns.defaults.partyScale or 0.75) * 100 + 0.5)) else EditSet(100) end
    end)
    edBar.cancel = Btn("취소", false, function() EditFinish(false) end)
    edBar.done = Btn("완료", true, function() EditFinish(true) end, 80)
    edBar:SetScript("OnUpdate", function(self)
        local w = 18 + edBar.title:GetStringWidth()
        for _, b in ipairs({ self.minus, holder, self.plus, self.reset, self.cancel, self.done }) do w = w + 8 + b:GetWidth() end
        self:SetWidth(w + 26)
    end)
    ed:Hide(); edBar:Hide()
end

EditStart = function(key)
    local E = EDIT[key]
    if not E then return end
    if InCombatLockdown() then Print("전투가 끝나면 조절할 수 있어요.") return end
    ed = ed or (EditBuild() or ed)
    if hub and hub:IsShown() then hub:Hide() end   -- 먼저 닫아야 허브 미리 보기가 정리돼요
    local prepped = E.prep and E.prep()
    local fr = E.frame()
    if not fr then Print("지금은 " .. E.label .. "이(가) 화면에 없어요."); ns:ToggleHub(key) return end
    edState = { key = key, E = E, snap = E.snapshot(), prepped = prepped, fr = fr }
    C_Timer.After(0.05, function()
        if not edState then return end
        if not fr:IsShown() then fr:Show() end
        ed:ClearAllPoints(); ed:SetAllPoints(fr)
        edBar:ClearAllPoints(); edBar:SetPoint("BOTTOM", ed, "TOP", 0, 12)   -- 바로 위에
        edBar.title:SetText(E.label)
        EditPaint()
        ed:Show(); edBar:Show()
    end)
end

EditFinish = function(keep)
    local st = edState
    if not st then return end
    edState = nil
    if ed then ed.scaling = nil; ed:Hide(); ed:ClearAllPoints() end
    if edBar then edBar:Hide() end
    if not keep then pcall(st.E.restore, st.snap) end
    if st.prepped and st.E.unprep then pcall(st.E.unprep) end
    if keep then Print(st.E.label .. " 크기를 저장했어요.") else Print(st.E.label .. "을(를) 처음 그대로 두었어요.") end
    C_Timer.After(0.05, function() ns:ToggleHub(st.key) end)
end

do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:SetScript("OnEvent", function() if edState then EditFinish(true) end end)
end

local function Build()
    local f = CreateFrame("Frame", "LeelUI_Hub", UIParent)
    f:SetSize(W, H)
    f:SetPoint("CENTER", 0, 30)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) Undock(); self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if not self.compact then
            local p, _, rp, x, y = self:GetPoint()
            ns.db.hub.pos2 = { p, rp, x, y }
        end
        C_Timer.After(0.05, function() DockFor(MODULES[sel]); if self.pv then self.pv:Update() end end)
    end)
    tinsert(UISpecialFrames, "LeelUI_Hub")
    ns.RoundPlate(f, 18, { 0.11, 0.08, 0.075, 0.97 }, { 0.949, 0.702, 0.761, 0.6 })

    -- 제목 줄
    local tbar = f:CreateTexture(nil, "BACKGROUND", nil, 3)
    tbar:SetColorTexture(1, 1, 1, 0.03)
    tbar:SetPoint("TOPLEFT", 2, -2); tbar:SetPoint("TOPRIGHT", -2, -2); tbar:SetHeight(HEAD - 2)
    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(ns.MEDIA .. "hub_logo"); logo:SetSize(36, 36)
    logo:SetPoint("TOPLEFT", 14, -9)
    local title = ns.Font(f, 19)
    title:SetText("|cfff2b3c2르엘|r 허브")
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    local ver = ns.Num(f, 12, C.tx2, false)
    ver:SetText(Version("LeelUI") ~= "" and ("v" .. Version("LeelUI")) or "")
    ver:SetPoint("LEFT", title, "RIGHT", 8, -1)

    local close = CreateFrame("Button", nil, f)
    close:SetSize(28, 28)
    close:SetPoint("TOPRIGHT", -14, -13)
    local cbg = close:CreateTexture(nil, "ARTWORK"); cbg:SetTexture(ns.MEDIA .. "circle"); cbg:SetAllPoints()
    cbg:SetVertexColor(0.23, 0.18, 0.17, 1)
    local cx = close:CreateTexture(nil, "OVERLAY"); cx:SetTexture(ns.MEDIA .. "hb_x"); cx:SetSize(15, 15); cx:SetPoint("CENTER")
    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function() cbg:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1); cx:SetVertexColor(C.ink[1], C.ink[2], C.ink[3]) end)
    close:SetScript("OnLeave", function() cbg:SetVertexColor(0.23, 0.18, 0.17, 1); cx:SetVertexColor(1, 1, 1) end)
    f.moveBtn = ns.MakeButton(f, "이동 모드", false, function() Undock(); ns:ToggleMoveMode(); Refresh() end, 90)
    f.moveBtn:SetPoint("RIGHT", close, "LEFT", -10, 0)

    -- 찾기 칸
    local sb = CreateFrame("EditBox", nil, f)
    sb:SetSize(320, 30)
    sb:SetPoint("RIGHT", f.moveBtn, "LEFT", -12, 0)
    sb:SetAutoFocus(false)
    sb:SetFont(ns.FONT, 13, "")
    sb:SetTextInsets(34, 12, 0, 0)
    sb:SetMaxLetters(30)
    sb.bg, sb.edge = ns.RoundPlate(sb, 15, { 0.07, 0.05, 0.05, 1 }, { 0.949, 0.702, 0.761, 0.35 })
    local sic = sb:CreateTexture(nil, "OVERLAY"); sic:SetTexture(ns.MEDIA .. "hb_search"); sic:SetSize(16, 16)
    sic:SetPoint("LEFT", 12, 0); sic:SetVertexColor(C.acc[1], C.acc[2], C.acc[3])
    sb.ph = ns.Font(sb, 12.5, { 0.5, 0.44, 0.42 }); sb.ph:SetPoint("LEFT", 34, 0)
    sb.ph:SetText("설정 찾기 (예: 크기, 디버프)")
    local res = CreateFrame("Frame", nil, f)
    res:SetPoint("TOPLEFT", sb, "BOTTOMLEFT", 0, -6); res:SetPoint("TOPRIGHT", sb, "BOTTOMRIGHT", 0, -6)
    res:SetFrameLevel(f:GetFrameLevel() + 40)
    res:EnableMouse(true)
    ns.RoundPlate(res, 12, { 0.125, 0.094, 0.086, 0.99 }, { 0.949, 0.702, 0.761, 0.8 })
    res.items = {}
    res:Hide()
    local function Jump(r)
        sb:SetText(""); sb:ClearFocus(); res:Hide()
        sel = r.i
        local m = MODULES[sel]
        if r.g then curTab[m.key] = r.g end
        for _, g in ipairs(f.groups) do
            for _, i in ipairs(g.rows) do if i == sel then ns.db.hub.shut[g.key] = nil end end
        end
        Refresh()
        local c = r.idx and f.pane.itemCard and f.pane.itemCard[r.idx]
        if c then
            local _, _, _, _, cy = c:GetPoint()
            local sf = f.pane.sf
            local max = math.max(0, f.pane:GetHeight() - sf:GetHeight())
            sf:SetVerticalScroll(math.min(max, math.max(0, -(cy or 0) - 40)))
            f.pane.PaintThumb()
            c.edge:SetColor(C.acc, 1)
            local token = {}
            c.flash = token
            C_Timer.After(1.8, function() if c.flash == token then c.edge:SetColor({ 1, 1, 1 }, 0.06) end end)
        end
    end
    local function ShowResults()
        local q = sb:GetText() or ""
        q = q:gsub("^%s+", ""):gsub("%s+$", "")
        if q == "" then res:Hide() return end
        local list = SearchAll(q)
        local n = math.min(#list, 8)
        for k = 1, n do
            local r = list[k]
            local b = res.items[k]
            if not b then
                b = CreateFrame("Button", nil, res)
                b:SetHeight(36)
                b.hl = ns.RoundRect(b, 10, nil, "BACKGROUND", 2, 0)
                b.ic = b:CreateTexture(nil, "ARTWORK"); b.ic:SetSize(18, 18); b.ic:SetPoint("LEFT", 10, 0)
                b.a = ns.Font(b, 12.5); b.a:SetPoint("TOPLEFT", 36, -4)
                b.b = ns.Font(b, 10.5, { 0.62, 0.54, 0.52 }); b.b:SetPoint("TOPLEFT", b.a, "BOTTOMLEFT", 0, -2)
                b:SetScript("OnEnter", function(self) self.hl:SetColor(C.acc, 0.16) end)
                b:SetScript("OnLeave", function(self) self.hl:SetColor(C.acc, self.first and 0.1 or 0) end)
                res.items[k] = b
            end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 6, -6 - (k - 1) * 37); b:SetPoint("TOPRIGHT", -6, -6 - (k - 1) * 37)
            b.ic:SetTexture(ns.MEDIA .. MODULES[r.i].icon); b.ic:SetVertexColor(C.acc[1], C.acc[2], C.acc[3])
            b.a:SetText(r.label); b.b:SetText(r.sub)
            b.first = k == 1
            b.hl:SetColor(C.acc, b.first and 0.1 or 0)
            b:SetScript("OnClick", function() Jump(r) end)
            b:Show()
        end
        for k = n + 1, #res.items do res.items[k]:Hide() end
        res.first = list[1]
        if n == 0 then
            res.empty = res.empty or ns.Font(res, 12, { 0.62, 0.54, 0.52 })
            res.empty:SetPoint("TOPLEFT", 14, -12); res.empty:SetText("찾는 설정이 없어요"); res.empty:Show()
            res:SetHeight(38)
        else
            if res.empty then res.empty:Hide() end
            res:SetHeight(n * 37 + 10)
        end
        res:Show()
    end
    sb:SetScript("OnTextChanged", function(self) self.ph:SetShown(self:GetText() == ""); ShowResults() end)
    sb:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); res:Hide() end)
    sb:SetScript("OnEnterPressed", function(self) if res.first then Jump(res.first) else self:ClearFocus() end end)
    sb:SetScript("OnEditFocusGained", function(self) self.edge:SetColor(C.acc, 1); ShowResults() end)
    sb:SetScript("OnEditFocusLost", function(self)
        self.edge:SetColor({ 0.949, 0.702, 0.761 }, 0.35)
        C_Timer.After(0.2, function() if not sb:HasFocus() then res:Hide() end end)
    end)
    f.search = sb

    local function HLine(yy)
        local t = f:CreateTexture(nil, "BORDER")
        t:SetColorTexture(0.949, 0.702, 0.761, 0.15); t:SetHeight(1)
        t:SetPoint("TOPLEFT", 1, yy); t:SetPoint("TOPRIGHT", -1, yy)
    end
    HLine(-HEAD)
    local foot = f:CreateTexture(nil, "BORDER")
    foot:SetColorTexture(0.949, 0.702, 0.761, 0.15); foot:SetHeight(1)
    foot:SetPoint("BOTTOMLEFT", 1, FOOT); foot:SetPoint("BOTTOMRIGHT", -1, FOOT)
    local vline = f:CreateTexture(nil, "BORDER")
    vline:SetColorTexture(0.949, 0.702, 0.761, 0.12); vline:SetWidth(1)
    vline:SetPoint("TOPLEFT", RAIL, -HEAD); vline:SetPoint("BOTTOMLEFT", RAIL, FOOT)
    f.vline = vline
    local sideBg = f:CreateTexture(nil, "BACKGROUND", nil, 3)
    f.sideBg = sideBg
    sideBg:SetColorTexture(0, 0, 0, 0.18)
    sideBg:SetPoint("TOPLEFT", 2, -HEAD); sideBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", RAIL, FOOT)

    -- 왼쪽 목록 (휠로 내려 보기)
    local side = CreateFrame("ScrollFrame", nil, f)
    side:SetPoint("TOPLEFT", 4, -HEAD - 4)
    side:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", RAIL - 2, FOOT + 2)
    side.child = CreateFrame("Frame", nil, side)
    side.child:SetSize(RAIL - 6, 10)
    side:SetScrollChild(side.child)
    side:EnableMouseWheel(true)
    side:SetScript("OnMouseWheel", function(self, d)
        local max = math.max(0, self.child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * 40)))
    end)
    f.side = side
    local sc = side.child

    ns.db.hub.shut = ns.db.hub.shut or {}
    local GROUPS = { { key = "start", label = "시작" } }
    for _, c in ipairs(CATS) do GROUPS[#GROUPS + 1] = { key = c.key, label = c.label } end
    f.groups = {}
    f.rail = {}
    for _, g in ipairs(GROUPS) do
        local rows = {}
        for i, m in ipairs(MODULES) do if m.cat == g.key then rows[#rows + 1] = i end end
        if #rows > 0 then
            local gh = CreateFrame("Button", nil, sc)
            gh:SetHeight(22)
            gh.fs = ns.Font(gh, 11.5, C.acc); gh.fs:SetPoint("LEFT", 8, 0); gh.fs:SetText(g.label)
            gh.ar = gh:CreateTexture(nil, "OVERLAY"); gh.ar:SetTexture(ns.MEDIA .. "hb_down")
            gh.ar:SetSize(10, 10); gh.ar:SetPoint("RIGHT", -8, 0); gh.ar:SetVertexColor(C.tx2[1], C.tx2[2], C.tx2[3])
            gh:SetScript("OnClick", function()
                ns.db.hub.shut[g.key] = not ns.db.hub.shut[g.key] or nil
                PaintRail()
            end)
            g.btn, g.rows = gh, rows
            f.groups[#f.groups + 1] = g
            for _, i in ipairs(rows) do
                local m = MODULES[i]
                local row = CreateFrame("Button", nil, sc)
                row:SetHeight(30)
                row.fill = ns.RoundRect(row, 10, nil, "BACKGROUND", 2, 0)
                row.bar = row:CreateTexture(nil, "ARTWORK"); row.bar:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 1)
                row.bar:SetSize(3, 18); row.bar:SetPoint("LEFT", 0, 0)
                row.ic = row:CreateTexture(nil, "ARTWORK"); row.ic:SetTexture(ns.MEDIA .. m.icon)
                row.ic:SetSize(18, 18); row.ic:SetPoint("LEFT", 12, 0)
                row.name = ns.Font(row, 12.5); row.name:SetPoint("LEFT", row.ic, "RIGHT", 9, 0)
                row.name:SetPoint("RIGHT", -26, 0); row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
                row.dot = row:CreateTexture(nil, "OVERLAY"); row.dot:SetTexture(ns.MEDIA .. "circle")
                row.dot:SetSize(8, 8); row.dot:SetPoint("RIGHT", -12, 0)
                row.tag = ns.Font(row, 10.5, C.tx2); row.tag:SetPoint("RIGHT", -10, 0)
                row.badge = CreateFrame("Frame", nil, row); row.badge:SetSize(20, 16); row.badge:SetPoint("RIGHT", -8, 0)
                ns.RoundRect(row.badge, 8, { 1, 0.35, 0.43 }, "ARTWORK", 0, 0)
                row.badge.fs = ns.Num(row.badge, 11, { 1, 1, 1 }, false); row.badge.fs:SetPoint("CENTER", 0, 0)
                row:SetScript("OnClick", function() sel = i; Refresh() end)
                row:SetScript("OnEnter", function(self) if sel ~= i then self.fill:SetColor({ 1, 1, 1 }, 0.05) end end)
                row:SetScript("OnLeave", function() PaintRail() end)
                f.rail[i] = row
            end
        end
    end

    f.pane = BuildPane(f)
    f.pv = BuildPreview(f)

    -- 아래 줄
    local hint = ns.Font(f, 11.5, { 0.81, 0.64, 0.62 })
    hint:SetText("질문 · 제보 · 새 소식은 |cffffd6e0채채TV|r에서")
    hint:SetPoint("BOTTOMLEFT", 18, 21)
    f.hint = hint
    f.talkBtn = ns.MakeButton(f, "소통하러 가기", false, function()
        talk = talk or BuildTalk(f)
        talk:SetShown(not talk:IsShown())
    end, 104)
    f.talkBtn:SetPoint("LEFT", hint, "RIGHT", 10, 0)
    f.doneBtn = ns.MakeButton(f, "완료", true, function() f:Hide() end, 110)
    f.doneBtn:SetHeight(32)
    f.doneBtn:SetPoint("BOTTOMRIGHT", -16, 12)
    f.reloadBtn = ns.MakeButton(f, "다시 불러오기", false, function() ReloadUI() end, 110)
    f.reloadBtn:SetPoint("RIGHT", f.doneBtn, "LEFT", -8, 0)

    -- 좁은 허브 머리 · 펼치기 단추
    f.cHead = CreateFrame("Frame", nil, f)
    f.cHead:SetPoint("TOPLEFT", 0, -HEAD); f.cHead:SetPoint("TOPRIGHT", 0, -HEAD); f.cHead:SetHeight(46)
    f.cTitle = ns.Font(f.cHead, 16); f.cTitle:SetPoint("TOPLEFT", 18, -8)
    local csub = ns.Font(f.cHead, 10.5, C.tx2); csub:SetPoint("TOPLEFT", f.cTitle, "BOTTOMLEFT", 0, -3)
    csub:SetText("크기 · 위치 · 게임 화면을 보면서 맞춰요")
    f.cHead:Hide()
    f.expandBtn = ns.MakeButton(f, "펼치기", false, function()
        local m = MODULES[sel]
        if m then curTab[m.key] = 1 end
        SetCompact(false)
    end, 80)
    f.expandBtn:SetPoint("BOTTOMLEFT", 16, 14)
    f.expandBtn:Hide()

    f:SetScript("OnHide", function(self)
        PeekOff()
        LiveOff()
        if self.compact then
            local m = MODULES[sel]; if m then curTab[m.key] = 1 end
            SetCompact(false)
        end
    end)
    f:SetScript("OnShow", function(self)
        local p = ns.db.hub.pos2
        if p then self:ClearAllPoints(); self:SetPoint(p[1], UIParent, p[2], p[3], p[4]) end
        Refresh()
    end)
    f:Hide()
    return f
end

----------------------------------------------------------------------
-- 바깥에서 부르는 것
----------------------------------------------------------------------
function ns:ToggleHub(key)
    ns.db.hub = ns.db.hub or {}
    if not hub then
        hub = Build()
        local want = key or ns.db.hub.last or "LeelUI"
        for i, m in ipairs(MODULES) do if m.key == want then sel = i end end
    end
    if key then
        for i, m in ipairs(MODULES) do if m.key == key then sel = i; if m.cat ~= "none" then curCat = m.cat end end end
        hub:Show(); Refresh()
        return
    end
    hub:SetShown(not hub:IsShown())
end

function ns:RefreshHub() Refresh() end
-- 아직 안 본 새 소식 수 (게임 메뉴 단추 NEW 등)
function ns.HubNewsCount() return NewsCount() end
-- /르엘새소식테스트 : 업데이트된 것처럼 (새 소식 2개를 안 본 걸로 · 다음 /reload 때 채팅 알림도)
SLASH_LEELNEWSTEST1 = "/르엘새소식테스트"
SlashCmdList.LEELNEWSTEST = function()
    ns.db.hub = ns.db.hub or {}
    ns.db.hub.seenNews = NEWS[3] and NEWS[3][1] or nil
    ns.db.lastVer = "0.0.0"
    print("|cfff2b3c2[르엘 UI]|r 새 소식 테스트: 2개를 안 본 걸로 바꿨어요 · ESC 메뉴 단추에 NEW · /reload 하면 업데이트 알림도 나와요")
    if hub and hub:IsShown() then Refresh() end
end

-- 미니맵 아이콘 정리: 길잡이 버튼 숨김 (토끼 하나만)
function ns:ApplyHubTidy()
    ns.db.hub = ns.db.hub or {}
    local b = _G.ForgLevelingMinimapButton
    if not b then return end
    if ns.db.hub.tidy then
        b:Hide()
        if not b.leelHooked then
            b.leelHooked = true
            hooksecurefunc(b, "Show", function(self) if ns.db.hub.tidy then self:Hide() end end)
        end
    elseif not (ForgLevelingDB and ForgLevelingDB.minimapHide) then
        b:Show()
    end
end

-- 이동 모드가 바뀌면 허브 단추 글자도
if hooksecurefunc then
    C_Timer.After(0, function()
        if ns.SetMoveMode then hooksecurefunc(ns, "SetMoveMode", function() Refresh() end) end
    end)
end

-- /르엘
SLASH_LEELHUB1 = "/르엘"
SLASH_LEELHUB2 = "/leelhub"
SlashCmdList.LEELHUB = function() ns:ToggleHub() end

-- 접속 후 아이콘 정리 적용 (길잡이 버튼이 만들어진 다음)
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    C_Timer.After(1, function()
        if ns.db then ns.db.hub = ns.db.hub or {}; ns:ApplyHubTidy() end
    end)
    -- 업데이트 알림: 버전이 바뀐 뒤 첫 접속에 채팅으로 한 번
    C_Timer.After(4, function()
        if not ns.db then return end
        local v = Version("LeelUI")
        if v == "" then return end
        local last = ns.db.lastVer
        ns.db.lastVer = v
        if not last or last == v then return end
        print(("|cfff2b3c2르엘 UI|r: |cffffd6e0v%s|r 버전으로 업데이트되었어요."):format(v))
        local top = NEWS[1]
        if top and top[1] == v then print("   |cffb9a6a0" .. top[2] .. "|r") end
        print("   허브(|cffffd6e0/르엘|r)의 '새 소식'에서 바뀐 점을 확인하세요.")
    end)
end)
