-- LeelUI / Veil.lua
-- 준비 화면: 접속 · /reload 직후 화면을 잠깐 덮고, 무거운 일(지도 미리 읽기 등)을 그 뒤에서 몰아서 해요
--   토끼 링 + 진행 막대 + "지금 하는 일" + 팁 카드 한 장 (3초마다 다음 팁)
--   전투 중이면 안 덮어요 · ESC / 클릭으로 바로 걷기 · 허브 > 시작 > 준비 화면 에서 끄기
-- 멈추는 순간엔 와우가 화면을 안 그려서 링도 같이 멈춰 보여요 → 그래서 단계 글자 · 막대가 중요해요

local _, ns = ...
local C = ns.C

----------------------------------------------------------------------
-- 팁 (안 써 본 기능 먼저 · 본 횟수가 적은 것 먼저)
----------------------------------------------------------------------
local TIPS = {
    { k = "stash", icon = "hb_gift", tag = "창고 부캐",
      text = "우편함 아래 [창고로 보내기] 한 번이면\n재료가 창고 캐릭에게 저절로 가요",
      fresh = function() local s = ns.StashDB and ns.StashDB(); return not (s and s.target) end },
    { k = "stash2", icon = "hb_gift", tag = "창고 부캐",
      text = "가방에서 템을 휠클릭하면\n창고로 늘 보내기 · 안 보내기를 정할 수 있어요",
      fresh = function() local s = ns.StashDB and ns.StashDB(); return s and s.target and next(s.always) == nil and next(s.never) == nil end },
    { k = "hub", icon = "hb_search", tag = "허브",
      text = "/leel 이나 미니맵 토끼로 허브를 열고\n위 검색창에 \"크기\"만 쳐도 찾아요" },
    { k = "move", icon = "hb_ui", tag = "이동 모드",
      text = "허브 위 [이동 모드]를 누르고\n분홍 테두리를 끌어서 창 자리를 옮겨요" },
    { k = "party", icon = "hb_party", tag = "파티",
      text = "파티 창 칸에 내가 풀 수 있는\n디버프만 색으로 떠요" },
    { k = "roll", icon = "hb_loot", tag = "주사위",
      text = "주사위 창에 지금 내 장비와의\n비교가 같이 나와요" },
    { k = "mark", icon = "hb_mark", tag = "징표",
      text = "징표를 찍으면 르엘마크를 쓰는\n파티원 화면에도 같은 징표가 보여요" },
    { k = "map", icon = "hb_map", tag = "지도",
      text = "이 준비 시간에 지도를 미리 읽어 둬서\nM을 처음 누를 때 안 멈춰요" },
    { k = "profile", icon = "hb_share", tag = "설정 나누기",
      text = "설정을 글 한 줄로 복사해서\n다른 캐릭 · 친구에게 그대로 옮겨요 (/르엘설정)" },
    { k = "prof", icon = "hb_bolt", tag = "측정",
      text = "어딘가 버벅이면 /르엘측정\n어느 애드온이 느린지 보여요" },
    { k = "bag", icon = "hb_bag", tag = "가방",
      text = "가방 [정리] 한 번 · 위 탭으로\n장비 · 재료 · 회색템만 골라 봐요" },
}

local function Seen() ns.db.veilSeen = ns.db.veilSeen or {}; return ns.db.veilSeen end
-- 르엘 허브에 있는 기능 설명을 모두 팁으로 (허브 제목 · 설명 그대로 · 영어 판이면 영어로)
local SKIP = { _news = true, LeelUI_Veil = true }
local function HubTips()
    local out = {}
    for _, m in ipairs(ns.HubModules or {}) do
        if type(m) == "table" and type(m.key) == "string" and not SKIP[m.key] and type(m.title) == "string" and type(m.desc) == "string" and m.desc ~= "" then
            out[#out + 1] = { k = "hub:" .. m.key, icon = m.icon, tag = m.title, text = m.desc }
        end
    end
    return out
end
local function PickOrder()
    local seen = Seen()
    local list = {}
    local all = {}
    for _, t in ipairs(TIPS) do all[#all + 1] = t end
    for _, t in ipairs(HubTips()) do all[#all + 1] = t end
    for _, t in ipairs(all) do
        local ok, fresh = true, true
        if t.fresh then ok, fresh = pcall(t.fresh); if not ok then fresh = false end end
        if fresh ~= false and fresh ~= nil then
            list[#list + 1] = { t = t, w = (seen[t.k] or 0) * 10 + math.random() * 8 - ((t.fresh and fresh) and 20 or 0) }
        end
    end
    table.sort(list, function(a, b) return a.w < b.w end)
    local out = {}
    for _, e in ipairs(list) do out[#out + 1] = e.t end
    return out
end

----------------------------------------------------------------------
-- 화면 (C안: 와우 로딩 화면 자리 그대로 · 가운데 토끼 · 아래 긴 막대 + "팁:" 한 줄)
----------------------------------------------------------------------
local V
local function Build()
    V = CreateFrame("Frame", "LeelUI_Veil", UIParent)
    V:SetFrameStrata("FULLSCREEN_DIALOG"); V:SetFrameLevel(50)
    V:SetAllPoints(UIParent)
    V:EnableMouse(true)
    -- B안: 게임 화면이 안 비치게 완전히 덮어요 (진짜 로딩 화면처럼) · 위아래는 더 어둡고 가운데는 은은하게
    V.bg = V:CreateTexture(nil, "BACKGROUND", nil, -8); V.bg:SetAllPoints(); V.bg:SetColorTexture(0.028, 0.02, 0.018, 1)
    local function Shade(top)
        local t = V:CreateTexture(nil, "BACKGROUND", nil, -7)
        t:SetColorTexture(1, 1, 1, 1)
        t:SetPoint("LEFT"); t:SetPoint("RIGHT")
        if top then t:SetPoint("TOP"); t:SetPoint("BOTTOM", V, "CENTER", 0, 40)
        else t:SetPoint("TOP", V, "CENTER", 0, 40); t:SetPoint("BOTTOM") end
        local dark, glow = { r = 0.028, g = 0.02, b = 0.018, a = 1 }, { r = 0.1, g = 0.07, b = 0.062, a = 1 }
        if CreateColor and t.SetGradient then
            local cd, cg = CreateColor(dark.r, dark.g, dark.b, 1), CreateColor(glow.r, glow.g, glow.b, 1)
            if top then pcall(t.SetGradient, t, "VERTICAL", cg, cd) else pcall(t.SetGradient, t, "VERTICAL", cd, cg) end
        else
            t:SetColorTexture(0.06, 0.045, 0.04, 1)
        end
    end
    Shade(true); Shade(false)

    -- 가운데: 토끼 링 + 제목만
    local box = CreateFrame("Frame", nil, V); box:SetSize(300, 170); box:SetPoint("CENTER", 0, 40)
    local ringBg = box:CreateTexture(nil, "ARTWORK"); ringBg:SetTexture(ns.MEDIA .. "ring_thin"); ringBg:SetSize(110, 110)
    ringBg:SetPoint("TOP", 0, 0); ringBg:SetVertexColor(0.23, 0.17, 0.16, 1)
    local spin = box:CreateTexture(nil, "OVERLAY"); spin:SetTexture(ns.MEDIA .. "mring_half"); spin:SetSize(110, 110)
    spin:SetPoint("CENTER", ringBg); spin:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    local ag = spin:CreateAnimationGroup(); ag:SetLooping("REPEAT")
    local rot = ag:CreateAnimation("Rotation"); rot:SetDegrees(-360); rot:SetDuration(1.1)
    V.spinAG = ag
    local bun = box:CreateTexture(nil, "OVERLAY", nil, 2); bun:SetTexture(ns.MEDIA .. "bunny"); bun:SetSize(58, 58); bun:SetPoint("CENTER", ringBg)
    V.title = ns.Font(box, 26, C.acc); V.title:SetPoint("TOP", ringBg, "BOTTOM", 0, -16)
    V.title:SetText(ns.L("르엘UI 준비 중"))

    -- 아래: 팁 한 줄 · 긴 막대 · 지금 하는 일
    local w = math.min(1100, (UIParent:GetWidth() or 1600) * 0.62)
    local track = V:CreateTexture(nil, "ARTWORK"); track:SetSize(w, 16); track:SetPoint("BOTTOM", 0, 120)
    track:SetColorTexture(0.23, 0.17, 0.16, 1)
    local fill = V:CreateTexture(nil, "OVERLAY"); fill:SetHeight(16); fill:SetPoint("LEFT", track, "LEFT", 0, 0)
    fill:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 1); fill:SetWidth(1)
    V.track, V.fill = track, fill
    V.step = ns.Font(V, 14, { 0.66, 0.59, 0.57 }); V.step:SetPoint("TOP", track, "BOTTOM", 0, -12)
    V.tip = ns.Font(V, 19, { 0.95, 0.91, 0.9 }); V.tip:SetPoint("BOTTOM", track, "TOP", 0, 20)
    if V.tip.SetSpacing then V.tip:SetSpacing(5) end
    V.tip:SetWidth(w); V.tip:SetJustifyH("CENTER"); V.tip:SetWordWrap(true)
    if V.tip.SetMaxLines then V.tip:SetMaxLines(3) end
    V.tip:SetShadowColor(0, 0, 0, 1); V.tip:SetShadowOffset(1, -1)
    -- 팁 바뀔 때 살짝 사라졌다 나타나게
    V.tipAG = V.tip:CreateAnimationGroup()
    local a1 = V.tipAG:CreateAnimation("Alpha"); a1:SetFromAlpha(0); a1:SetToAlpha(1); a1:SetDuration(0.35)

    V.hint = ns.Font(V, 12, { 0.44, 0.37, 0.36 }); V.hint:SetPoint("BOTTOMRIGHT", -24, 20)
    V.hint:SetText(ns.L("ESC 로 바로 걷기 · 허브 > 시작 > 준비 화면 에서 끄기"))

    -- ESC · 클릭으로 걷기 (다른 키는 그대로 게임으로)
    V:EnableKeyboard(true)
    V:SetPropagateKeyboardInput(true)
    V:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(false) end
            ns.VeilClose(true)
        elseif not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
    end)
    V:SetScript("OnMouseDown", function() ns.VeilClose(true) end)
    V:Hide()
end

local tips, tipI, tipT = {}, 0, 0
local function Clean(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function ShowTip(i)
    local t = tips[i]
    if not t then V.tip:SetText("") return end
    local body = ns.L(t.text)   -- 설명의 줄바꿈은 그대로 (2~3줄)
    V.tip:SetText("|cffffd25a" .. ns.L("팁") .. ":|r |cfff2b3c2" .. Clean(ns.L(t.tag)) .. "|r · " .. body)
    V.tipAG:Stop(); V.tipAG:Play()
    local seen = Seen(); seen[t.k] = (seen[t.k] or 0) + 1
end

----------------------------------------------------------------------
-- 단계: 하나씩 다음 화면 그림 뒤에 (덮개가 먼저 보이게)
----------------------------------------------------------------------
local STEPS = {
    { "가방 · 창고", function() if ns.StashRecord then pcall(ns.StashRecord) end end },
    { "이름표 · 파티", function() end },
    { "지도 미리 읽기", function() if _G.LeelMap_Preload then pcall(_G.LeelMap_Preload) end end },
    { "퀘스트 · 길안내", function() end },
    { "마무리", function() end },
}
local running, t0, minT, closing = false, 0, 1, false
-- 게임 쪽 멈춤 기다리기: 우리 일이 끝나도 게임(퀘스트 · 다른 애드온)이 몇 초 뒤에 한 번 크게 멈춰요
--   → 화면이 0.4초 넘게 멈춘 걸 본 뒤, 1초 동안 부드러우면 걷어요 (못 보면 7초 · 길어도 15초)
local waitGame, stallSeen, lastStall, lastFrame = false, false, 0, 0
local STALL, CALM, NOSTALL_MAX, HARD_MAX = 0.4, 1.0, 6, 15

local function SetProg(i)
    local f = 0.6 * i / #STEPS   -- 우리 단계 = 막대 앞 60% · 나머지는 게임 마무리
    V.fill:SetWidth(math.max(1, (V.track:GetWidth() or 320) * f))
    local s = STEPS[math.min(i + 1, #STEPS)]
    if i >= #STEPS then V.step:SetText(ns.L("준비 끝"))
    else V.step:SetText(ns.L(s[1]) .. " " .. ns.L("하는 중") .. " · " .. (i + 1) .. " / " .. #STEPS) end
end

function ns.VeilClose(now)
    if not V or not V:IsShown() or closing then return end
    closing = true
    running = false
    _G.LeelUI_VeilOn = nil
    -- 아직 못 한 일은 덮개 없이 마저 해요
    for _, s in ipairs(STEPS) do if not s.done then s.done = true; pcall(s[2]) end end
    local took = GetTime() - t0
    if ns.db then ns.db.veilLast = took end
    if now or not UIFrameFadeOut then
        V:Hide(); V.spinAG:Stop(); closing = false
    else
        UIFrameFadeOut(V, 0.4, 1, 0)
        C_Timer.After(0.42, function() V:Hide(); V:SetAlpha(1); V.spinAG:Stop(); closing = false end)
    end
end

local function Run(i)
    if not running then return end
    local s = STEPS[i]
    if not s then
        -- 우리 일은 끝 · 이제 게임이 마무리하며 멈추는 걸 기다려요
        V.fill:SetWidth(math.max(1, (V.track:GetWidth() or 320) * 0.6))
        V.step:SetText(ns.L("게임이 마무리하는 중"))
        waitGame = true
        return
    end
    SetProg(i - 1)
    -- 글이 화면에 먼저 그려지고 나서 무거운 일을 해요
    C_Timer.After(0.05, function()
        if not running then return end
        if not s.done then s.done = true; pcall(s[2]) end
        Run(i + 1)
    end)
end

local function Open(initial)
    if not V then Build() end
    for _, s in ipairs(STEPS) do s.done = nil end
    tips = PickOrder(); tipI = 1; tipT = GetTime()
    ShowTip(tipI)
    V:SetAlpha(1); V:Show(); V.spinAG:Play()
    running, closing = true, false
    waitGame, stallSeen, lastStall = false, false, GetTime()
    _G.LeelUI_VeilOn = true
    t0 = GetTime()
    minT = initial and 3 or 1.6
    SetProg(0)
    Run(1)
end

-- 팁 돌리기 (3초마다)
local tk = CreateFrame("Frame")
tk:SetScript("OnUpdate", function(_, el)
    if not (V and V:IsShown() and running) then return end
    local now = GetTime()
    -- 우리 단계가 끝난 뒤의 멈춤만 세요 (그 전 멈춤은 우리 일이라 이미 덮였어요)
    if el and el > STALL then
        lastStall = now
        if waitGame then stallSeen = true; if ns.db then ns.db.veilStall = { at = now - t0, len = el } end end
    end
    if waitGame then
        local up = now - t0
        -- 막대: 60% → 95% 천천히
        local f = 0.6 + 0.35 * math.min(1, up / NOSTALL_MAX)
        V.fill:SetWidth(math.max(1, (V.track:GetWidth() or 320) * f))
        V.step:SetText(ns.L("게임이 마무리하는 중") .. " · " .. math.floor(f * 100) .. "%")
        local calm = now - lastStall > CALM
        if up >= minT and ((stallSeen and calm) or up > NOSTALL_MAX or up > HARD_MAX) then
            waitGame = false
            V.fill:SetWidth(V.track:GetWidth() or 320); V.step:SetText(ns.L("준비 끝"))
            ns.VeilClose()
            return
        end
    end
    if GetTime() - tipT > 4 and #tips > 1 then
        tipT = GetTime(); tipI = (tipI % #tips) + 1; ShowTip(tipI)
        minT = math.max(minT, GetTime() - t0 + 0.5)
    end
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, e, isLogin, isReload)
    if e ~= "PLAYER_ENTERING_WORLD" then return end
    if not ns.db or ns.db.veil == false then return end
    if not (isLogin or isReload) then return end   -- 인던 들어갈 때 같은 로딩엔 안 띄워요
    if InCombatLockdown() then return end
    local ok, err = pcall(Open, isLogin)
    if not ok then _G.LeelUI_VeilOn = nil; if V then V:Hide() end end
end)
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
-- 접속 뒤에 늦게 불러오는 애드온(지도 · 경매장 같은 필요할 때 읽는 것)이 오는 동안은 안 걷어요
ev:RegisterEvent("ADDON_LOADED")
ev:HookScript("OnEvent", function(_, e)
    if e == "ADDON_LOADED" and running then lastStall = GetTime() end
end)
ev:HookScript("OnEvent", function(_, e) if e == "PLAYER_REGEN_DISABLED" then ns.VeilClose(true) end end)

-- 허브 미리 보기
function ns.VeilTest() if not InCombatLockdown() then Open(true) end end
