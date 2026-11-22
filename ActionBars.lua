-- LeelUI / ActionBars.lua
-- 르엘 액션바 (시험): 판 없는 둥둥 바 + 토끼 메뉴 버튼
--  * 블리자드 액션 버튼은 그대로 쓰고(부모도 그대로 → 드루이드 변신 쪽 바뀜 정상) 자리·모양만 바꿔요
--  * 바 테·사자 조각상·나무 판은 투명하게, 메뉴 버튼·가방 칸은 숨기고 토끼 메뉴로
--  * 자리 옮기기·크기 바꾸기는 전투 밖에서만 (전투 중엔 끝나고 적용)

local _, ns = ...
local C = ns.C

-- 잠금: 다음 업데이트 전까지 르엘 액션바는 안 켜져요 (게임 기본 바 그대로)
ns.ABAR_LOCKED = false

local BASE_SIZE, GAP, BASE_PET = 40, 6, 34
local SIZE, PET = BASE_SIZE, BASE_PET

local function DB()
    ns.db.abar = ns.db.abar or {}
    local d = ns.db.abar
    if d.on == nil then d.on = false end
    -- 처음 켰을 때 기본값 = 슈엘 화면 (화면 아래 가운데, 액션바 80%, 토끼 메뉴 80%)
    if d.scale == nil then d.scale = 80 end
    if d.mscale == nil then d.mscale = 80 end
    if d.style == nil then d.style = "float" end   -- float = 둥둥 3줄 · wing = 날개 (왼쪽 4×2 페이지 · 오른쪽 5×2 고정)
    if d.pgKeys == nil then d.pgKeys = "off" end   -- 페이지 넘기기 키 (off · zx)
    if d.laTop == nil then d.laTop = true end      -- 날개일 때 로아식: 내 창 숨기기 · 대상 창은 화면 위 가운데 큰 줄
    if d.menuStyle == nil then d.menuStyle = "row" end   -- 메뉴: row = 오른쪽 위 네모 단추 한 줄(모바일식) · bunny = 토끼 메뉴
    if d.wskin == nil then d.wskin = "tac" end     -- 날개 스킨: la = 로아풍 검은 강철 / gold · iron = 실사 금테 · 쇠테 / pink = 예전 분홍
    if (d.wskinV or 0) < 3 then d.wskin = "tac"; d.wskinV = 3 end
    return d
end
ns.ABarDB = DB

local function P(msg) DEFAULT_CHAT_FRAME:AddMessage("|cfff2b3c2[르엘 액션바]|r " .. msg) end

local hider = CreateFrame("Frame")
hider:Hide()

local function G(name) return _G[name] end

----------------------------------------------------------------------
-- 버튼 모음
----------------------------------------------------------------------
local function Buttons(prefix, n)
    local t = {}
    for i = 1, n do
        local b = G(prefix .. i)
        if b then t[#t + 1] = b end
    end
    return t
end

local ROWS -- { {key, buttons, barFrame} ... } 아래부터 위로
local function Collect()
    ROWS = {
        { key = "main",  btns = Buttons("ActionButton", 12) },
        { key = "bl",    btns = Buttons("MultiBarBottomLeftButton", 12),  bar = G("MultiBarBottomLeft") },
        { key = "br",    btns = Buttons("MultiBarBottomRightButton", 12), bar = G("MultiBarBottomRight") },
    }
end

local managed = {}   -- 버튼 → true (우리가 자리 잡는 버튼)

----------------------------------------------------------------------
-- 버튼 꾸미기
----------------------------------------------------------------------
local function ShortKey(t)
    if type(t) ~= "string" then return t end
    t = t:gsub("^[cC]%-", "C"):gsub("^[sS]%-", "S"):gsub("^[aA]%-", "A")
    t = t:gsub("CTRL%-", "C"):gsub("SHIFT%-", "S"):gsub("ALT%-", "A")
    return t
end

local function HideTex(t)
    if t and t.SetAlpha then t:SetAlpha(0) end
end

local function Skin(b, round)
    if not b or b.leelSkin then return end
    b.leelSkin = true
    local name = b:GetName() or ""
    local shape = ns.MEDIA .. (round and "circle" or "mm_squircle")

    -- 블리자드 테·바닥 숨기기
    local function Strip()
        pcall(function() HideTex(b:GetNormalTexture()) end)
        HideTex(b.NormalTexture); HideTex(_G[name .. "NormalTexture"])
        HideTex(b.Border); HideTex(_G[name .. "Border"])
        HideTex(b.SlotBackground); HideTex(b.SlotArt); HideTex(b.FloatingBG)
        HideTex(_G[name .. "FloatingBG"])
        if b.RightDivider then HideTex(b.RightDivider) end
        if b.BottomDivider then HideTex(b.BottomDivider) end
    end
    Strip()
    b.leelStrip = Strip
    pcall(hooksecurefunc, b, "SetNormalTexture", function() HideTex(b:GetNormalTexture()) end)
    if b.Update then pcall(hooksecurefunc, b, "Update", Strip) end

    -- 아이콘: 둥근 모양으로 자르기
    local icon = b.icon or b.Icon or _G[name .. "Icon"]
    if icon then
        if b.IconMask then pcall(icon.RemoveMaskTexture, icon, b.IconMask) end
        icon:ClearAllPoints(); icon:SetAllPoints(b)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        local m = b:CreateMaskTexture()
        m:SetTexture(shape, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(b)
        icon:AddMaskTexture(m)
    end

    -- D안: 테 없이 진한 그림자로 띄우기 (빈 칸은 흐린 장미 테)
    local sh1 = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    sh1:SetTexture(shape); sh1:SetVertexColor(0, 0, 0, 0.35)
    sh1:SetPoint("TOPLEFT", -3, 0); sh1:SetPoint("BOTTOMRIGHT", 3, -6)
    local sh2 = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    sh2:SetTexture(shape); sh2:SetVertexColor(0, 0, 0, 0.45)
    sh2:SetPoint("TOPLEFT", -1, -1); sh2:SetPoint("BOTTOMRIGHT", 1, -3)
    local slot = b:CreateTexture(nil, "BACKGROUND", nil, -6)
    slot:SetTexture(shape); slot:SetVertexColor(0.788, 0.42, 0.51, 0.35); slot:SetAllPoints()
    local slotIn = b:CreateTexture(nil, "BACKGROUND", nil, -5)
    slotIn:SetTexture(shape); slotIn:SetVertexColor(0.07, 0.05, 0.047, 0.85)
    slotIn:SetPoint("TOPLEFT", 1.5, -1.5); slotIn:SetPoint("BOTTOMRIGHT", -1.5, 1.5)

    -- 누름·마우스·켜짐 표시
    for _, f in ipairs({ "SetHighlightTexture", "SetPushedTexture", "SetCheckedTexture" }) do
        pcall(b[f], b, shape)
    end
    pcall(function()
        local h = b:GetHighlightTexture(); h:SetAllPoints(b); h:SetVertexColor(1, 1, 1, 0.22); h:SetBlendMode("ADD")
        local p = b:GetPushedTexture(); p:SetAllPoints(b); p:SetVertexColor(0, 0, 0, 0.35)
        local c = b:GetCheckedTexture(); c:SetAllPoints(b); c:SetVertexColor(1, 1, 1, 0.28); c:SetBlendMode("ADD")
    end)

    -- 재사용 대기: 같은 모양으로 걷히게
    local cd = b.cooldown or b.Cooldown or _G[name .. "Cooldown"]
    if cd then
        pcall(cd.SetSwipeTexture, cd, shape)
        pcall(cd.SetSwipeColor, cd, 0.08, 0.05, 0.05, 0.75)
        cd:ClearAllPoints(); cd:SetAllPoints(b)
    end

    -- 단축키: 분홍 알약
    local hk = b.HotKey or _G[name .. "HotKey"]
    if hk then
        local pill = CreateFrame("Frame", nil, b)
        pill:SetFrameLevel(b:GetFrameLevel() + 4)
        pill:SetHeight(14)
        local flat = (DB().style == "wing") and not round   -- 날개 2: 알약 없이 왼쪽 위 흰 글자 (로아처럼)
        if not flat then
            -- 둥근 알약: 모서리 원 4개로 만든 판 (짧아도 양끝이 둥글게)
            ns.RoundPlate(pill, 7, { 0.788, 0.42, 0.51, 1 }, { 0.788, 0.42, 0.51, 1 })   -- 장미 알약
        end
        if flat then pill:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -1)
        elseif round then pill:SetPoint("CENTER", b, "TOP", 0, 0) else pill:SetPoint("CENTER", b, "TOPRIGHT", -4, -1) end
        hk:SetParent(pill)
        hk:ClearAllPoints(); hk:SetPoint(flat and "TOPLEFT" or "CENTER", pill, flat and "TOPLEFT" or "CENTER", 0, 0)
        hk:SetJustifyH(flat and "LEFT" or "CENTER")
        pcall(hk.SetFont, hk, ns.NUM or ns.FONT, flat and 11 or 10, flat and "OUTLINE" or "")
        hk:SetTextColor(1, 0.953, 0.965)
        hk:SetShadowColor(0, 0, 0, flat and 0.9 or 0)
        local function Fit()
            local t = hk:GetText()
            if t and t ~= "" and t ~= RANGE_INDICATOR then
                local s = ShortKey(t)
                if s ~= t then hk:SetText(s) return end
                pill:SetWidth(math.max(16, (hk:GetStringWidth() or 8) + 9))
                pill:Show()
            else
                pill:Hide()
            end
        end
        hooksecurefunc(hk, "SetText", Fit)
        pcall(hooksecurefunc, hk, "SetVertexColor", function(_, r) if r and r < 0.99 then hk:SetTextColor(1, 0.953, 0.965) end end)
        Fit()
    end

    -- 개수(화살, 물약)
    local ct = b.Count or _G[name .. "Count"]
    if ct then
        pcall(ct.SetFont, ct, ns.NUM or ns.FONT, 13, "OUTLINE")
        ct:ClearAllPoints(); ct:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    end
    local nm = b.Name or _G[name .. "Name"]
    if nm then nm:SetAlpha(0) end   -- 매크로 이름은 숨김 (칸이 작아서)
end

----------------------------------------------------------------------
-- 블리자드 판·조각상·경험치 바 투명하게
----------------------------------------------------------------------
local function StripArt(frame, depth)
    if not frame or depth > 4 or managed[frame] then return end
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.IsObjectType and r:IsObjectType("Texture") then r:SetAlpha(0) end
    end
    for _, ch in ipairs({ frame:GetChildren() }) do
        if not managed[ch] and not ch.leelKeep then StripArt(ch, depth + 1) end
    end
end

local function HideArt()
    for _, n in ipairs({ "MainMenuBar", "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight",
                         "MainMenuBarArtFrame", "MainMenuBarArtFrameBackground", "StanceBar", "StanceBarFrame",
                         "PetActionBar", "PetActionBarFrame", "BagsBar" }) do
        local f = G(n)
        if f then StripArt(f, 0) end
    end
    -- 경험치·평판 바
    for _, n in ipairs({ "MainMenuExpBar", "ReputationWatchBar", "MainMenuBarMaxLevelBar", "StatusTrackingBarManager",
                         "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer", "ExhaustionTick" }) do
        local f = G(n)
        if f then f:SetAlpha(0); pcall(f.EnableMouse, f, false) end
    end
    -- 쪽 넘기기 화살표
    for _, n in ipairs({ "ActionBarUpButton", "ActionBarDownButton", "MainMenuBarPageNumber" }) do
        local f = G(n)
        if f then f:SetAlpha(0); pcall(f.EnableMouse, f, false) end
    end
    local mb = G("MainMenuBar") or G("MainActionBar")
    if mb then
        if mb.ActionBarPageNumber then mb.ActionBarPageNumber:SetAlpha(0) end
        pcall(mb.EnableMouse, mb, false)
    end
end

----------------------------------------------------------------------
-- 메뉴 버튼·가방 칸 숨기기 (토끼 메뉴에서 대신 눌러요)
----------------------------------------------------------------------
local MICRO = { "CharacterMicroButton", "ProfessionMicroButton", "SpellbookMicroButton", "PlayerSpellsMicroButton",
                "TalentMicroButton", "AchievementMicroButton", "QuestLogMicroButton", "GuildMicroButton",
                "SocialsMicroButton", "LFDMicroButton", "LFGMicroButton", "CollectionsMicroButton", "EJMicroButton",
                "WorldMapMicroButton", "PVPMicroButton", "StoreMicroButton", "MainMenuMicroButton", "HelpMicroButton" }
local MICRO_KO = {
    CharacterMicroButton = "캐릭터", ProfessionMicroButton = "전문 기술", SpellbookMicroButton = "주문책",
    PlayerSpellsMicroButton = "주문·특성", TalentMicroButton = "특성", AchievementMicroButton = "업적",
    QuestLogMicroButton = "퀘스트 일지", GuildMicroButton = "길드", SocialsMicroButton = "친구",
    LFDMicroButton = "파티 찾기", LFGMicroButton = "파티 찾기", CollectionsMicroButton = "탈것·펫",
    EJMicroButton = "던전 안내", WorldMapMicroButton = "지도", PVPMicroButton = "PvP",
    StoreMicroButton = "상점", MainMenuMicroButton = "게임 메뉴", HelpMicroButton = "도움말",
}
local BAGS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
               "CharacterBag3Slot", "CharacterReagentBag0Slot", "KeyRingButton", "BagBarExpandToggle" }

-- 메뉴마다 알아보기 쉬운 그림 (없으면 원래 버튼 그림)
local MICRO_ICON = {
    ProfessionMicroButton   = "Trade_BlackSmithing",
    SpellbookMicroButton    = "INV_Misc_Book_09",
    PlayerSpellsMicroButton = "INV_Misc_Book_09",
    TalentMicroButton       = "Ability_Marksmanship",
    AchievementMicroButton  = "INV_Misc_Gift_02",
    QuestLogMicroButton     = "INV_Scroll_03",
    GuildMicroButton        = "INV_Shirt_GuildTabard_01",
    SocialsMicroButton      = "INV_Shirt_GuildTabard_01",
    LFDMicroButton          = "INV_Misc_GroupLooking",
    LFGMicroButton          = "INV_Misc_GroupLooking",
    CollectionsMicroButton  = "Ability_Mount_RidingHorse",
    StoreMicroButton        = "INV_Misc_Coin_02",
    MainMenuMicroButton     = "INV_Misc_Gear_01",
    HelpMicroButton         = "INV_Misc_QuestionMark",
}
local menuList = {}
local function HideMenus()
    wipe(menuList)
    local names = {}
    if type(_G.MICRO_BUTTONS) == "table" then
        for _, n in ipairs(_G.MICRO_BUTTONS) do names[#names + 1] = n end
    else
        names = MICRO
    end
    local seen = {}
    -- 1순위: 블리자드 메뉴 줄에 실제로 놓인 버튼만, 놓인 순서 그대로
    --        (보이지만 줄에서 빠진 모험 안내서·옛 특성 버튼 같은 건 안 들어가요)
    local mm = G("MicroMenu")
    if mm and mm.GetLayoutChildren then
        local ok, kids = pcall(mm.GetLayoutChildren, mm)
        if ok and type(kids) == "table" then
            for _, b in ipairs(kids) do
                if b and not seen[b] and b.GetName and b:GetName() and b:IsShown() then
                    seen[b] = true
                    menuList[#menuList + 1] = { btn = b, name = b:GetName() }
                end
            end
        end
    end
    -- 2순위: 이름 목록 (줄 정보를 못 얻으면)
    if #menuList == 0 then
        for _, n in ipairs(names) do
            local b = G(n)
            if b and not seen[b] and b:IsShown() and n ~= "EJMicroButton" then
                seen[b] = true
                menuList[#menuList + 1] = { btn = b, name = n }
            end
        end
    end
    -- 부모를 바꾸면 블리자드 메뉴 배치가 깨져요 → 자리는 그대로 두고 투명 + 마우스 끄기
    -- (토끼 메뉴는 이 버튼들을 대신 눌러줘서 숨겨 있어도 동작)
    local function Ghost(b)
        if not b then return end
        b:SetAlpha(0)
        pcall(b.EnableMouse, b, false)
    end
    for _, m in ipairs(menuList) do Ghost(m.btn) end
    for _, n in ipairs(BAGS) do Ghost(G(n)) end
    for _, n in ipairs({ "MicroMenuContainer", "MicroMenu", "BagsBar", "MicroButtonAndBagsBar" }) do
        local f = G(n)
        if f then f:SetAlpha(0); pcall(f.EnableMouse, f, false) end
    end
end

----------------------------------------------------------------------
-- 바 자리 잡기
----------------------------------------------------------------------
local holder, xp, launchHolder, launcher, fan
local pending, placing = false, false

local function Shown(b)
    return b and b:IsShown()
end

local function PlaceRow(btns, y, size, bar)
    local x, n = 0, 0
    for i, b in ipairs(btns) do
        b:ClearAllPoints()
        b:SetSize(size, size)
        b:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", (i - 1) * (size + GAP), y)
        n = n + 1
    end
    return n
end

-- 펫·변신 바: 보이는 칸만, 번호가 끊기면 조금 띄워서
local function PlaceSmall(btns, y)
    local x, last, any = 0, nil, false
    for i, b in ipairs(btns) do
        b:ClearAllPoints()
        b:SetSize(PET, PET)
        if Shown(b) then
            if last and i - last > 1 then x = x + 12 end
            b:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", x, y)
            x = x + PET + GAP + 2
            last = i; any = true
        else
            b:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, y)
        end
    end
    return any
end


----------------------------------------------------------------------
-- 날개 모양 (날개 2): 왼쪽 5×2 (전투 · 페이지로 바뀜) · 가운데 페이지 원 · 오른쪽 7×3 (고정 · 작은 칸)
--  * 왼쪽 = 블리자드 주 바 1~10 (Z · X 또는 원을 누르면 다음 · 이전 페이지, 변신하면 저절로)
--  * 오른쪽 = 왼쪽 아래 바 1~12 + 오른쪽 아래 바 1~9 · 왼쪽과 같은 크기 상자
--  * 판 · 테 없이 아래쪽 어둠 번짐 · 단축키 = 왼쪽 위 흰 글자 · 쿨 = 칸 가운데 큰 숫자 · 원 둘레 = 기력 · 분노 · 마나 링
--  * 페이지 넘기기는 블리자드 쪽 넘기기 버튼을 대신 눌러서 전투 중에도 돼요
----------------------------------------------------------------------
local wing   -- { L, R, core, big, prev, next, hp, mp, ... }
local WG, WPAD = 4, 8

local function WBar(parent, r, g, b)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(ns.WHITE or "Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(r, g, b, 1)
    local m = bar:CreateMaskTexture()
    m:SetTexture(ns.MEDIA .. "pill16", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints()
    bar:GetStatusBarTexture():AddMaskTexture(m)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(ns.MEDIA .. "pill16"); bg:SetVertexColor(0.07, 0.05, 0.047, 0.9); bg:SetAllPoints()
    local edge = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    edge:SetTexture(ns.MEDIA .. "pill16"); edge:SetVertexColor(0.788, 0.42, 0.51, 0.45)
    edge:SetPoint("TOPLEFT", -1, 1); edge:SetPoint("BOTTOMRIGHT", 1, -1)
    bar.t = ns.Font(bar, 10, { 1, 0.96, 0.97 }, "OVERLAY")
    bar.t:SetPoint("CENTER", bar, "CENTER", 0, 0)
    pcall(bar.t.SetShadowOffset, bar.t, 1, -1)
    bar.bg, bar.edge, bar.pm = bg, edge, m
    -- 금선 새김 스킨용: 바깥 금선 · 홈 · 윤 · 그늘 · 숫자 / 퍼센트
    bar.outer = bar:CreateTexture(nil, "BACKGROUND", nil, -4); bar.outer:SetTexture(ns.MEDIA .. "pill16")
    bar.groove = bar:CreateTexture(nil, "BACKGROUND", nil, -3); bar.groove:SetTexture(ns.MEDIA .. "pill16")
    bar.gloss = bar:CreateTexture(nil, "ARTWORK", nil, 2); bar.gloss:SetTexture(ns.WHITE or "Interface\\Buttons\\WHITE8x8")
    bar.gloss:SetPoint("TOPLEFT", bar:GetStatusBarTexture(), "TOPLEFT", 2, -2); bar.gloss:SetPoint("TOPRIGHT", bar:GetStatusBarTexture(), "TOPRIGHT", -4, -2)
    bar.gloss:AddMaskTexture(m)
    bar.shade = bar:CreateTexture(nil, "ARTWORK", nil, 1); bar.shade:SetTexture(ns.WHITE or "Interface\\Buttons\\WHITE8x8")
    bar.shade:SetPoint("BOTTOMLEFT", bar:GetStatusBarTexture(), "BOTTOMLEFT"); bar.shade:SetPoint("BOTTOMRIGHT", bar:GetStatusBarTexture(), "BOTTOMRIGHT")
    bar.shade:AddMaskTexture(m)
    bar.n = ns.Font(bar, 12, { 1, 1, 1 }, "OVERLAY"); pcall(bar.n.SetShadowOffset, bar.n, 1, -1)
    bar.pc = ns.Font(bar, 12, { 1, 1, 1 }, "OVERLAY"); pcall(bar.pc.SetShadowOffset, bar.pc, 1, -1)
    -- 끝 마개 (둥근 금 + 작은 보석)
    bar.cap = bar:CreateTexture(nil, "OVERLAY", nil, 1); bar.cap:SetTexture(ns.MEDIA .. "circle")
    bar.capIn = bar:CreateTexture(nil, "OVERLAY", nil, 2); bar.capIn:SetTexture(ns.MEDIA .. "circle")
    bar.gem = bar:CreateTexture(nil, "OVERLAY", nil, 3); bar.gem:SetTexture(ns.MEDIA .. "circle")
    return bar
end

local function WOrb(parent, big)
    local o = CreateFrame("Frame", nil, parent)
    o.edge = o:CreateTexture(nil, "BACKGROUND", nil, -2)
    o.edge:SetTexture(ns.MEDIA .. "circle")
    o.edge:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], big and 1 or 0.45)
    o.edge:SetPoint("TOPLEFT", big and -3 or -2, big and 3 or 2); o.edge:SetPoint("BOTTOMRIGHT", big and 3 or 2, big and -3 or -2)
    o.ring = o:CreateTexture(nil, "BACKGROUND", nil, -3)
    o.ring:SetTexture(ns.MEDIA .. "circle"); o.ring:SetVertexColor(0.1, 0.07, 0.07, 1)
    o.ring:SetPoint("TOPLEFT", big and -6 or -4, big and 6 or 4); o.ring:SetPoint("BOTTOMRIGHT", big and 6 or 4, big and -6 or -4)
    o.fill = o:CreateTexture(nil, "BACKGROUND", nil, -1)
    o.fill:SetTexture(ns.MEDIA .. "circle")
    if big then o.fill:SetVertexColor(0.27, 0.19, 0.24, 1) else o.fill:SetVertexColor(0.07, 0.05, 0.047, 1) end
    o.fill:SetAllPoints()
    return o
end

-- 페이지 넘기기 버튼 (보안 버튼: 블리자드 쪽 넘기기 버튼을 대신 눌러요)
local function WPager(name, parent, target, key)
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    local real = G(target)
    if not real then
        local mb = G("MainMenuBar") or G("MainActionBar")
        local pn = mb and mb.ActionBarPageNumber
        real = pn and pn[key]
    end
    if real then
        b:SetAttribute("type", "click"); b:SetAttribute("clickbutton", real)
    end
    return b
end

local function WUpdatePage()
    if not wing then return end
    local page = (GetActionBarPage and GetActionBarPage()) or 1
    local bonus = (GetBonusBarOffset and GetBonusBarOffset()) or 0
    local n = (NUM_ACTIONBAR_PAGES or 6)
    local prev = page - 1; if prev < 1 then prev = n end
    local nxt = page + 1; if nxt > n then nxt = 1 end
    wing.prev.n:SetText(prev); wing.next.n:SetText(nxt)
    if not (wing.real or wing.la) then wing.badge.t:SetText(page) end
    if bonus > 0 and page == 1 then
        local form = GetShapeshiftForm and GetShapeshiftForm() or 0
        local name
        if form and form > 0 and GetShapeshiftFormInfo then
            local _, nm = GetShapeshiftFormInfo(form)
            if type(nm) == "string" then name = nm end
            if not name and GetSpellInfo then
                local _, _, _, sid = GetShapeshiftFormInfo(form)
                if sid then name = GetSpellInfo(sid) end
            end
        end
        wing.lab:SetText(name or "변신")
    else
        wing.lab:SetText(page .. "페이지")
    end
    if wing.lastPage and wing.lastPage ~= page .. ":" .. bonus then
        wing.flash:Stop(); wing.flash:Play()
    end
    wing.lastPage = page .. ":" .. bonus
end

-- 금선 스킨: 줄 안 숫자(현재 / 최대) · 퍼센트 (전투 중 숨겨진 숫자면 계산 없이 그대로 넘기거나 비워요)
local function WText(bar, v, mx, unit, pt)
    if not pcall(function() bar.n:SetFormattedText("%s / %s", BreakUpLargeNumbers(v), BreakUpLargeNumbers(mx)) end) then
        if not pcall(bar.n.SetText, bar.n, "") then end
    end
    if bar.tacVal then
        if not pcall(function() bar.tacVal:SetFormattedText("%s / %s", BreakUpLargeNumbers(v), BreakUpLargeNumbers(mx)) end) then bar.tacVal:SetText("") end
    end
    local ok = pcall(function()
        if issecretvalue and (issecretvalue(v) or issecretvalue(mx)) then error("secret") end
        bar.pc:SetFormattedText("%d%%", (mx and mx > 0) and math.floor(v / mx * 100 + 0.5) or 0)
    end)
    if not ok then
        local cs = CurveConstants and CurveConstants.ScaleTo100
        local ok2 = pcall(function()
            if pt == nil and UnitHealthPercent then bar.pc:SetFormattedText("%d%%", UnitHealthPercent(unit, true, cs))
            elseif pt ~= nil and UnitPowerPercent then bar.pc:SetFormattedText("%d%%", UnitPowerPercent(unit, pt, true, cs))
            else error("none") end
        end)
        if not ok2 then bar.pc:SetText("") end
    end
end

local function WUpdateBars()
    if not wing then return end
    local h, hm = UnitHealth("player"), UnitHealthMax("player")
    ns.SetBar(wing.hp, h, hm)
    if not pcall(function() wing.hp.t:SetFormattedText("%s / %s", BreakUpLargeNumbers(h), BreakUpLargeNumbers(hm)) end) then
        wing.hp.t:SetText("")
    end
    WText(wing.hp, h, hm, "player", nil)
    if ns.ABarHealUpdate then ns.ABarHealUpdate() end
    local pt = UnitPowerType("player") or 0
    local p, pm = UnitPower("player", pt), UnitPowerMax("player", pt)
    ns.SetBar(wing.mp, p, pm)
    -- 날개 2: 색은 조금 차분하게 (마나 하늘 · 분노 장미빨강 · 기력 옅은 금)
    local CALM = { [0] = { 0.44, 0.58, 0.86 }, [1] = { 0.86, 0.38, 0.42 }, [2] = { 0.86, 0.6, 0.36 }, [3] = { 0.9, 0.78, 0.4 } }
    local col = CALM[pt] or (PowerBarColor and PowerBarColor[pt] and { PowerBarColor[pt].r, PowerBarColor[pt].g, PowerBarColor[pt].b }) or CALM[0]
    wing.mp:SetStatusBarColor(col[1], col[2], col[3], 1)
    if wing.pips then
        local ok, frac = pcall(function() return (pm and pm > 0) and (p / pm) or 0 end)
        frac = ok and frac or 0
        if issecretvalue and issecretvalue(frac) then frac = 0 end
        local okOn, on = pcall(function() return math.floor(frac * #wing.pips + 0.5) end)
        on = okOn and on or 0
        for i, t in ipairs(wing.pips) do
            if i <= on then t:SetVertexColor(col[1], col[2], col[3], 1) else t:SetVertexColor(1, 1, 1, 0.13) end
        end
    end
    if not pcall(function() wing.mp.t:SetFormattedText("%s / %s", BreakUpLargeNumbers(p), BreakUpLargeNumbers(pm)) end) then
        wing.mp.t:SetText("")
    end
    WText(wing.mp, p, pm, "player", pt)
end

local function WKeys()
    if not wing then return end
    if InCombatLockdown() then wing.keysPending = true return end
    ClearOverrideBindings(wing.core)
    if DB().pgKeys == "zx" then
        SetOverrideBindingClick(wing.core, false, "Z", "LeelUI_ABarPrev", "LeftButton")
        SetOverrideBindingClick(wing.core, false, "X", "LeelUI_ABarNext", "LeftButton")
    end
end
ns.ABarKeys = WKeys

local function BuildWing()
    wing = {}
    local function Panel(label, hot)
        local f = CreateFrame("Frame", nil, holder)
        f:SetFrameLevel(math.max(1, holder:GetFrameLevel()))
        ns.RoundPlate(f, 10, { 0.05, 0.04, 0.035, 0.72 }, { C.acc[1], C.acc[2], C.acc[3], hot and 0.65 or 0.25 })
        local tag = CreateFrame("Frame", nil, f)
        tag:SetHeight(15)
        ns.RoundPlate(tag, 7, hot and { C.acc[1], C.acc[2], C.acc[3], 1 } or { 0.23, 0.17, 0.16, 1 }, hot and { C.acc[1], C.acc[2], C.acc[3], 1 } or { 0.23, 0.17, 0.16, 1 })
        tag.t = ns.Font(tag, 10, hot and { 0.16, 0.1, 0.11 } or { 0.79, 0.71, 0.68 })
        tag.t:SetPoint("CENTER", 0, 0); tag.t:SetText(label)
        tag:SetWidth((tag.t:GetStringWidth() or 30) + 16)
        tag:SetFrameLevel(f:GetFrameLevel() + 20)
        f.tag = tag
        return f
    end
    wing.L = Panel("페이지", true)
    wing.L.tag:SetPoint("BOTTOMLEFT", wing.L, "TOPLEFT", 10, -8)
    wing.R = Panel("고정", false)
    wing.R.tag:SetPoint("BOTTOMRIGHT", wing.R, "TOPRIGHT", -10, -8)
    -- 날개 2: 판 · 꼬리표는 숨기고 바 뒤 아래쪽만 어둡게 번짐
    wing.L:SetAlpha(0); wing.R:SetAlpha(0)
    wing.fade = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
    wing.fade:SetTexture(ns.WHITE or "Interface\\Buttons\\WHITE8x8")
    pcall(wing.fade.SetGradient, wing.fade, "VERTICAL", CreateColor(0.03, 0.02, 0.02, 0.85), CreateColor(0.03, 0.02, 0.02, 0))
    -- 페이지 원이 바뀌면 왼쪽 판 테가 반짝

    wing.hp = WBar(holder, 0.95, 0.70, 0.76)
    wing.mp = WBar(holder, 0.44, 0.58, 0.86)
    -- 금선 스킨: 줄 안쪽 끝에서 문장 원으로 이어지는 금선
    wing.lnL = holder:CreateLine(nil, "ARTWORK"); wing.lnR = holder:CreateLine(nil, "ARTWORK")
    for _, l in ipairs({ wing.lnL, wing.lnR }) do
        l:SetTexture(ns.WHITE or "Interface\\Buttons\\WHITE8x8"); l:SetThickness(2); l:Hide()
    end

    wing.core = CreateFrame("Frame", nil, holder)
    wing.prev = WOrb(wing.core, false)
    wing.next = WOrb(wing.core, false)
    wing.big = WOrb(wing.core, true)
    wing.big:SetFrameLevel(wing.prev:GetFrameLevel() + 3)
    for _, o in ipairs({ wing.prev, wing.next }) do
        o.n = ns.Font(o, 16, { 0.79, 0.71, 0.68 }); o.n:SetPoint("CENTER", 0, 1)
    end
    local bun = wing.big:CreateTexture(nil, "ARTWORK")
    bun:SetTexture(ns.MEDIA .. "icon"); bun:SetPoint("CENTER", 0, 4)
    local bm = wing.big:CreateMaskTexture()
    bm:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    bm:SetPoint("TOPLEFT", 2, -2); bm:SetPoint("BOTTOMRIGHT", -2, 2)
    bun:AddMaskTexture(bm)
    wing.bun = bun
    local badge = CreateFrame("Frame", nil, wing.big)
    badge:SetSize(22, 22); badge:SetPoint("CENTER", wing.big, "BOTTOMRIGHT", -10, 12)
    badge:SetFrameLevel(wing.big:GetFrameLevel() + 2)
    local bt = badge:CreateTexture(nil, "ARTWORK"); bt:SetTexture(ns.MEDIA .. "circle"); bt:SetAllPoints()
    bt:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    badge.bt = bt
    badge.edge = badge:CreateTexture(nil, "BORDER"); badge.edge:SetTexture(ns.MEDIA .. "circle")
    badge.edge:SetPoint("TOPLEFT", -3, 3); badge.edge:SetPoint("BOTTOMRIGHT", 3, -3); badge.edge:Hide()
    badge.t = ns.Font(badge, 12, { 0.16, 0.1, 0.11 }); badge.t:SetPoint("CENTER", 0, 0)
    wing.badge = badge
    wing.lab = ns.Font(wing.core, 11, C.accHi or C.acc); wing.lab:SetPoint("TOP", wing.big, "BOTTOM", 0, -3)
    -- 원 둘레 = 기력 · 분노 · 마나 링 (쿨 그림을 멈춘 듯이 써서 비율만큼 채워요)
    wing.resTrack = wing.big:CreateTexture(nil, "BACKGROUND", nil, -5)
    wing.resTrack:SetTexture(ns.MEDIA .. "ring_thin"); wing.resTrack:SetVertexColor(1, 1, 1, 0.12)
    wing.resTrack:SetPoint("TOPLEFT", -9, 9); wing.resTrack:SetPoint("BOTTOMRIGHT", 9, -9)
    wing.resTrack:Hide()
    -- 둘레 점 24개: 자원 비율만큼 켜져요 (위에서부터 시계 방향)
    wing.pips = {}
    for i = 1, 24 do
        local t = wing.big:CreateTexture(nil, "OVERLAY")
        t:SetTexture(ns.MEDIA .. "circle")
        wing.pips[i] = t
    end
    wing.zk = ns.Font(wing.core, 12, { 1, 0.96, 0.97 }); wing.zk:SetText("Z")
    wing.xk = ns.Font(wing.core, 12, { 1, 0.96, 0.97 }); wing.xk:SetText("X")

    -- 반짝 (페이지 바뀔 때)
    local glow = wing.big:CreateTexture(nil, "BACKGROUND", nil, -4)
    glow:SetTexture(ns.MEDIA .. "circle"); glow:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    glow:SetPoint("TOPLEFT", -12, 12); glow:SetPoint("BOTTOMRIGHT", 12, -12); glow:SetAlpha(0)
    local ag = glow:CreateAnimationGroup()
    local a1 = ag:CreateAnimation("Alpha"); a1:SetFromAlpha(0); a1:SetToAlpha(0.55); a1:SetDuration(0.08); a1:SetOrder(1)
    local a2 = ag:CreateAnimation("Alpha"); a2:SetFromAlpha(0.55); a2:SetToAlpha(0); a2:SetDuration(0.45); a2:SetOrder(2)
    wing.flash = ag

    -- 눌러서 넘기기 (원 · 키)
    wing.prevBtn = WPager("LeelUI_ABarPrev", wing.prev, "ActionBarDownButton", "DownButton")
    wing.prevBtn:SetAllPoints(wing.prev)
    wing.nextBtn = WPager("LeelUI_ABarNext", wing.next, "ActionBarUpButton", "UpButton")
    wing.nextBtn:SetAllPoints(wing.next)
    for _, pair in ipairs({ { wing.prevBtn, "이전 페이지", "Z" }, { wing.nextBtn, "다음 페이지", "X" } }) do
        local b = pair[1]
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetTexture(ns.MEDIA .. "circle"); hl:SetAllPoints()
        hl:SetVertexColor(1, 1, 1, 0.15); hl:SetBlendMode("ADD")
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(pair[2], C.acc[1], C.acc[2], C.acc[3])
            GameTooltip:AddLine("왼쪽 10칸만 바뀌어요 · 오른쪽은 그대로", 1, 1, 1)
            if DB().pgKeys == "zx" then GameTooltip:AddLine("키: " .. pair[3], 0.85, 0.78, 0.76)
            else GameTooltip:AddLine("허브에서 Z · X 키로 넘기게 할 수 있어요", 0.85, 0.78, 0.76) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local hf = CreateFrame("Frame")
    hf:RegisterUnitEvent("UNIT_HEALTH", "player")
    pcall(hf.RegisterUnitEvent, hf, "UNIT_HEALTH_FREQUENT", "player")
    hf:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
    pcall(hf.RegisterUnitEvent, hf, "UNIT_HEAL_PREDICTION", "player")
    hf:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    pcall(hf.RegisterUnitEvent, hf, "UNIT_POWER_FREQUENT", "player")
    hf:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    hf:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    hf:RegisterEvent("PLAYER_ENTERING_WORLD")
    for _, e in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP" }) do pcall(hf.RegisterEvent, hf, e) end
    hf:SetScript("OnEvent", function(_, e)
        if e == "PLAYER_XP_UPDATE" or e == "UPDATE_EXHAUSTION" or e == "PLAYER_LEVEL_UP" then
            if ns.ABarXP then C_Timer.After(0, ns.ABarXP) end
            return
        end
        WUpdateBars()
        if e == "PLAYER_ENTERING_WORLD" and ns.ABarXP then ns.ABarXP() end
    end)
    local pf = CreateFrame("Frame")
    for _, e in ipairs({ "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD" }) do
        pcall(pf.RegisterEvent, pf, e)
    end
    pf:SetScript("OnEvent", function() C_Timer.After(0, WUpdatePage) end)
    -- 날개 2: 쿨은 칸 가운데 큰 숫자 (공통 재사용 1.5초 이하는 빼고)
    local cdt = CreateFrame("Frame")
    local acc = 0
    cdt:SetScript("OnUpdate", function(_, e)
        acc = acc + e
        if acc < 0.1 then return end
        acc = 0
        if not (DB().on and DB().style == "wing" and ROWS) then return end
        local now = GetTime() * 1000
        for _, row in ipairs(ROWS) do
            for _, b in ipairs(row.btns) do
                local cd = b.cooldown or b.Cooldown
                if cd and b:GetAlpha() > 0 and b:IsVisible() then
                    if not b.leelCD then
                        b.leelCD = b:CreateFontString(nil, "OVERLAY", nil, 7)
                        b.leelCD:SetPoint("CENTER", 0, 0)
                        b.leelCD:SetTextColor(1, 1, 1)
                    end
                    local ok, st, du = pcall(cd.GetCooldownTimes, cd)
                    -- 숨겨진 값(전투 중 비밀 숫자)이면 비교 · 계산을 못 하니 숫자는 안 보여요
                    if not ok or (issecretvalue and (issecretvalue(st) or issecretvalue(du))) then st, du = nil, nil end
                    local okL, left = pcall(function() return (st and du and du > 1600) and (st + du - now) / 1000 or 0 end)
                    left = okL and left or 0
                    if left > 0.5 then
                        local w = b:GetWidth() or 40
                        local sz = math.max(9, math.floor(w * (left >= 60 and 0.34 or 0.42)))
                        if b.leelCDsz ~= sz then b.leelCDsz = sz; pcall(b.leelCD.SetFont, b.leelCD, ns.NUM or ns.FONT, sz, "OUTLINE") end
                        b.leelCD:SetText(left >= 60 and (math.ceil(left / 60) .. "m") or math.ceil(left))
                        b.leelCD:Show()
                    else
                        b.leelCD:Hide()
                    end
                elseif b.leelCD then
                    b.leelCD:Hide()
                end
            end
        end
    end)
    WKeys()
end

-- 날개에 안 쓰는 칸 (주 바 11 · 12, 왼쪽 아래 11 · 12, 오른쪽 아래 바)은 안 보이게 (단축키는 그대로 동작)
local function WGhost(b)
    if not b then return end
    b:SetAlpha(0)
    pcall(b.EnableMouse, b, false)
    b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
end

----------------------------------------------------------------------
-- 날개 스킨: 금선 새김 · 진영 문장 (얼라이언스 = 푸른 · 호드 = 붉은) / 분홍(예전)
--  * 문장 그림은 게임 안 진영 로고(전장 시작 카운트다운 그림)를 경로로 불러와요
----------------------------------------------------------------------
local GOLD = { 0.86, 0.70, 0.40 }
local FAC = {
    Alliance = { logo = "Interface\\Timer\\Alliance-Logo", disc = "ab_disc_blue", gem = "ab_gem_blue" },
    Horde    = { logo = "Interface\\Timer\\Horde-Logo",    disc = "ab_disc_red",  gem = "ab_gem_red" },
}
local function WMetal() return DB().wskin == "iron" and "iron" or "gold" end

-- 줄: 실사 금속 테 (3조각: 왼 끝 · 가운데 늘림 · 오른 끝)
local function WSkinBar(bar, real, left, BH, metal)
    local function Out(t, n) t:ClearAllPoints(); t:SetPoint("TOPLEFT", -n, n); t:SetPoint("BOTTOMRIGHT", n, -n) end
    if left then
        if real then bar:SetStatusBarColor(0.80, 0.10, 0.17, 1) else bar:SetStatusBarColor(0.95, 0.70, 0.76, 1) end
    end
    if not bar.rl then
        bar.rl = bar:CreateTexture(nil, "OVERLAY", nil, -2)
        bar.rm = bar:CreateTexture(nil, "OVERLAY", nil, -2)
        bar.rr = bar:CreateTexture(nil, "OVERLAY", nil, -2)
        bar.rl:SetTexCoord(0, 0.125, 0, 1); bar.rm:SetTexCoord(0.125, 0.875, 0, 1); bar.rr:SetTexCoord(0.875, 1, 0, 1)
    end
    local parts = { bar.gloss, bar.shade, bar.n, bar.pc, bar.cap, bar.gem, bar.rl, bar.rm, bar.rr }
    for _, t in ipairs(parts) do t:SetShown(real) end
    bar.outer:Hide(); bar.groove:Hide(); bar.capIn:Hide()
    bar.t:SetShown(not real)
    bar.edge:SetShown(not real)
    if not real then
        Out(bar.edge, 1); bar.edge:SetVertexColor(0.788, 0.42, 0.51, 0.45)
        bar.bg:SetVertexColor(0.07, 0.05, 0.047, 0.9)
        return
    end
    bar.bg:SetVertexColor(0.03, 0.02, 0.02, 0.95)
    local k = BH / 30
    local p, cw = 17 * k, 32 * k
    local tex = ns.MEDIA .. "ab_rail_" .. metal
    for _, t in ipairs({ bar.rl, bar.rm, bar.rr }) do t:SetTexture(tex); t:ClearAllPoints() end
    bar.rl:SetPoint("TOPLEFT", bar, "TOPLEFT", -p, p); bar.rl:SetSize(cw, BH + 2 * p)
    bar.rr:SetPoint("TOPRIGHT", bar, "TOPRIGHT", p, p); bar.rr:SetSize(cw, BH + 2 * p)
    bar.rm:SetPoint("TOPLEFT", bar.rl, "TOPRIGHT", 0, 0); bar.rm:SetPoint("BOTTOMRIGHT", bar.rr, "BOTTOMLEFT", 0, 0)
    bar.gloss:SetHeight(math.max(2, math.floor(BH * 0.28))); bar.gloss:SetVertexColor(1, 1, 1, 0.22)
    bar.shade:SetHeight(math.max(2, math.floor(BH * 0.4))); bar.shade:SetVertexColor(0, 0, 0, 0.28)
    local fs = math.max(10, math.floor(BH * 0.62))
    for _, f in ipairs({ bar.n, bar.pc }) do pcall(f.SetFont, f, ns.NUM or ns.FONT, fs, "OUTLINE"); f:ClearAllPoints() end
    if left then
        bar.n:SetPoint("LEFT", bar, "LEFT", 10, 0); bar.pc:SetPoint("RIGHT", bar, "RIGHT", -10, 0)
    else
        bar.pc:SetPoint("LEFT", bar, "LEFT", 10, 0); bar.n:SetPoint("RIGHT", bar, "RIGHT", -10, 0)
    end
    local c = math.floor(BH * 1.45)
    local side = left and "LEFT" or "RIGHT"
    local ox = left and -p * 0.9 or p * 0.9
    bar.cap:SetTexture(ns.MEDIA .. "ab_cap_" .. metal); bar.cap:SetVertexColor(1, 1, 1, 1)
    bar.cap:ClearAllPoints(); bar.cap:SetSize(c, c); bar.cap:SetPoint("CENTER", bar, side, ox, 0)
    bar.gem:SetTexture(ns.MEDIA .. (left and "ab_gem_red" or "ab_gem_blue")); bar.gem:SetVertexColor(1, 1, 1, 1)
    bar.gem:ClearAllPoints(); bar.gem:SetSize(math.floor(c * 0.42), math.floor(c * 0.42)); bar.gem:SetPoint("CENTER", bar.cap, "CENTER", 0, 0)
end

-- 경험치 고리 · 레벨 보석
local function WUpdateXP()
    if not wing or not (wing.real or wing.la or wing.tac) then return end
    local b = wing.badge
    if not wing.tac then pcall(function() b.t:SetText(UnitLevel("player")) end) end
    local dots = wing.xpd or {}
    local lv = UnitLevel("player") or 1
    local maxLv = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or MAX_PLAYER_LEVEL or 80
    local f, r = 1, 0
    local maxed = lv >= maxLv or (IsXPUserDisabled and IsXPUserDisabled())
    if not maxed then
        local ok = pcall(function()
            local cur, mx = UnitXP("player"), UnitXPMax("player")
            f = (mx and mx > 0) and cur / mx or 0
            r = math.min(1 - f, ((GetXPExhaustion and GetXPExhaustion()) or 0) / ((mx and mx > 0) and mx or 1))
        end)
        if not ok then f, r = 0, 0 end
    end
    if wing.la and wing.laT and wing.geo then
        local t, h = wing.laT, 126 * (wing.geo.u or 1)
        local fv = maxed and 1 or math.max(0.001, f)
        local rv = maxed and 0.001 or math.max(0.001, math.min(1, f + r))
        t.fill:SetHeight(h * fv); t.fill:SetTexCoord(0, 1, 1 - fv, 1)
        t.rest:SetHeight(h * rv); t.rest:SetTexCoord(0, 1, 1 - rv, 1); t.rest:SetShown(not maxed and r > 0.005)
    end
    if wing.tac and wing.tc then
        local T2 = wing.tc
        pcall(function() T2.lv:SetText(UnitLevel("player")) end)
        T2.pc:SetText(maxed and "MAX" or (math.floor(f * 100) .. "%"))
        -- 쿨다운을 아주 길게 걸어 둔 채 비율만큼 지난 것처럼 (사실상 멈춘 고리)
        local fv = maxed and 1 or math.max(0, math.min(1, f))
        local rv = maxed and 0 or math.min(1, f + r)
        T2.cd:Set(fv)
        if rv > fv + 0.003 then T2.restCD:Set(rv) else T2.restCD:Set(0) end
        if not maxed and f > 0.01 then
            local a = math.pi / 2 - f * 2 * math.pi
            T2.tip:ClearAllPoints(); T2.tip:SetPoint("CENTER", wing.big, "CENTER", math.cos(a) * (T2.ringR or 50), math.sin(a) * (T2.ringR or 50))
            T2.tip:Show(); T2.tipG:Show()
        else T2.tip:Hide(); T2.tipG:Hide() end
    end
    local n = #dots
    for i, t in ipairs(dots) do
        local q = (i - 0.5) / n
        if maxed then t:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
        elseif q <= f then t:SetVertexColor(0.70, 0.40, 0.98, 1)
        elseif q <= f + r then t:SetVertexColor(0.30, 0.55, 0.95, 0.75)
        else t:SetVertexColor(0, 0, 0, 0.6) end
    end
    if maxed then wing.xpt:SetText("")
    elseif r > 0.005 then wing.xpt:SetFormattedText("경험치 %d%% · 휴식 +%d%%", math.floor(f * 100), math.floor(r * 100 + 0.5))
    else wing.xpt:SetFormattedText("경험치 %d%%", math.floor(f * 100)) end
end
ns.ABarXP = WUpdateXP

-- 로아풍 (검은 강철 칼날 줄 · 가운데 고딕 방패 · 진영 색 수정 = 경험치)
--  * 그림 좌표는 설계도 단위(u = 왼쪽 칸 크기 / 54) 기준
local LACOL = { Horde = { 1.0, 0.32, 0.18 }, Alliance = { 0.35, 0.62, 1.0 } }
local function WLABar(bar, on, left, u, BH)
    if not bar.la then
        bar.la = {}
        for i, n in ipairs({ "tip", "mid", "end" }) do
            local t = bar:CreateTexture(nil, "OVERLAY", nil, -1)
            t:SetTexture(ns.MEDIA .. "ab_la_" .. n); bar.la[i] = t
        end
    end
    for _, t in ipairs(bar.la) do t:SetShown(on) end
    if not on then return end
    bar.t:Hide(); bar.edge:Hide(); bar.outer:Hide(); bar.groove:Hide()
    for _, t in ipairs({ bar.cap, bar.capIn, bar.gem, bar.rl, bar.rm, bar.rr }) do if t then t:Hide() end end
    for _, t in ipairs({ bar.gloss, bar.shade, bar.n, bar.pc }) do t:Show() end
    if left then bar:SetStatusBarColor(0.86, 0.14, 0.08, 1) end
    bar.bg:SetVertexColor(0.03, 0.02, 0.02, 0.95)
    bar.gloss:SetHeight(math.max(2, math.floor(BH * 0.3))); bar.gloss:SetVertexColor(1, 1, 1, 0.25)
    bar.shade:SetHeight(math.max(2, math.floor(BH * 0.4))); bar.shade:SetVertexColor(0, 0, 0, 0.3)
    local fs = math.max(10, math.floor(BH * 0.78))
    for _, f in ipairs({ bar.n, bar.pc }) do pcall(f.SetFont, f, ns.NUM or ns.FONT, fs, "OUTLINE"); f:ClearAllPoints() end
    if left then
        bar.n:SetPoint("LEFT", bar, "LEFT", 14 * u, 0); bar.pc:SetPoint("RIGHT", bar, "RIGHT", -18 * u, 0)
    else
        bar.pc:SetPoint("LEFT", bar, "LEFT", 18 * u, 0); bar.n:SetPoint("RIGHT", bar, "RIGHT", -14 * u, 0)
    end
    local tip, mid, en = bar.la[1], bar.la[2], bar.la[3]
    local top = 24.5 * u + (BH - 13 * u) / 2   -- 칼날 위끝 = 줄 위끝보다 24.5u 위
    for _, t in ipairs(bar.la) do t:ClearAllPoints() end
    tip:SetSize(44 * u, 48 * u); en:SetSize(60 * u, 48 * u)
    if left then
        for _, t in ipairs(bar.la) do t:SetTexCoord(0, 1, 0, 1) end
        tip:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, top)
        en:SetPoint("TOPLEFT", bar, "TOPRIGHT", -32 * u, top)
        mid:SetPoint("TOPLEFT", tip, "TOPRIGHT", 0, 0); mid:SetPoint("BOTTOMRIGHT", en, "BOTTOMLEFT", 0, 0)
    else
        for _, t in ipairs(bar.la) do t:SetTexCoord(1, 0, 0, 1) end
        tip:SetPoint("TOPLEFT", bar, "TOPRIGHT", 0, top)
        en:SetPoint("TOPRIGHT", bar, "TOPLEFT", 32 * u, top)
        mid:SetPoint("TOPRIGHT", tip, "TOPLEFT", 0, 0); mid:SetPoint("BOTTOMLEFT", en, "BOTTOMRIGHT", 0, 0)
    end
end

local function WLA(on, fac, u)
    local core, big = wing.core, wing.big
    if on and not wing.laT then
        local t = {}
        t.wellBg = core:CreateTexture(nil, "ARTWORK", nil, 1); t.wellBg:SetTexture(ns.MEDIA .. "ab_la_crystal")
        t.rest = core:CreateTexture(nil, "ARTWORK", nil, 2); t.rest:SetTexture(ns.MEDIA .. "ab_la_crystal")
        t.fill = core:CreateTexture(nil, "ARTWORK", nil, 3); t.fill:SetTexture(ns.MEDIA .. "ab_la_crystal")
        t.gemL = core:CreateTexture(nil, "ARTWORK", nil, 4); t.gemR = core:CreateTexture(nil, "ARTWORK", nil, 4)
        t.shield = core:CreateTexture(nil, "OVERLAY", nil, 5)
        wing.laT = t
    end
    local t = wing.laT
    if not t then return end
    for _, x in pairs(t) do x:SetShown(on) end
    if not on then return end
    local key = (UnitFactionGroup and UnitFactionGroup("player")) or ""
    local col = LACOL[key] or { 0.75, 0.42, 1.0 }
    t.shield:SetTexture(ns.MEDIA .. (key == "Horde" and "ab_la_shield_r" or "ab_la_shield_b"))
    t.shield:ClearAllPoints(); t.shield:SetSize(220 * u, 220 * u); t.shield:SetPoint("CENTER", big, "CENTER", 0, 15 * u)
    t.wellBg:ClearAllPoints(); t.wellBg:SetSize(48 * u, 126 * u); t.wellBg:SetPoint("CENTER", big, "CENTER", 0, 17 * u)
    t.wellBg:SetVertexColor(col[1] * 0.18, col[2] * 0.18, col[3] * 0.18, 1)
    t.fill:SetVertexColor(col[1], col[2], col[3], 1)
    t.rest:SetVertexColor(0.6, 0.8, 1, 0.45)
    for _, x in ipairs({ t.fill, t.rest }) do x:ClearAllPoints(); x:SetWidth(48 * u); x:SetPoint("BOTTOM", t.wellBg, "BOTTOM", 0, 0) end
    local gm = key == "Horde" and "ab_gem_red" or "ab_gem_blue"
    t.gemL:SetTexture(ns.MEDIA .. "ab_gem_red"); t.gemR:SetTexture(ns.MEDIA .. "ab_gem_blue")
    for i, g in ipairs({ t.gemL, t.gemR }) do
        g:ClearAllPoints(); g:SetSize(24 * u, 24 * u); g:SetPoint("CENTER", big, "CENTER", (i == 1 and -36 or 36) * u, -30 * u)
    end
    -- 문장: 수정 속에 비치게
    wing.bun:SetTexture(fac and fac.logo or (ns.MEDIA .. "icon")); wing.bun:SetTexCoord(0, 1, 0, 1)
    wing.bun:SetVertexColor(1, 1, 1, 0.9)
    wing.bun:ClearAllPoints(); wing.bun:SetSize(42 * u, 42 * u); wing.bun:SetPoint("CENTER", big, "CENTER", 0, 24 * u)
    -- 레벨 보석 (방패 꼭대기 구멍)
    local b = wing.badge
    b:ClearAllPoints(); b:SetSize(24 * u, 24 * u); b:SetPoint("CENTER", big, "CENTER", 0, 100 * u)
    b.bt:SetTexture(ns.MEDIA .. gm); b.bt:SetVertexColor(1, 1, 1, 1); b.edge:Hide()
    b.t:SetTextColor(1, 1, 1); pcall(b.t.SetFont, b.t, ns.NUM or ns.FONT, math.max(10, math.floor(12 * u)), "OUTLINE")
    b.t:ClearAllPoints(); b.t:SetPoint("CENTER", 0, -1)
    if b.lv then b.lv:Hide() end
    wing.xpt:ClearAllPoints(); wing.xpt:SetPoint("TOP", big, "CENTER", 0, -90 * u)
    wing.xpt:Show()
    -- 칸 테 (얇은 검은 강철)
end

local function WLASlots(on)
    if not ROWS then return end
    for _, row in ipairs(ROWS) do
        for _, b in ipairs(row.btns) do
            if on and b:GetAlpha() > 0 then
                if not b.leelLA then
                    b.leelLA = b:CreateTexture(nil, "OVERLAY", nil, 6); b.leelLA:SetTexture(ns.MEDIA .. "ab_la_slot")
                end
                local o = math.max(2, math.floor((b:GetWidth() or 40) * 3.5 / 53 + 0.5))
                b.leelLA:ClearAllPoints(); b.leelLA:SetPoint("TOPLEFT", -o, o); b.leelLA:SetPoint("BOTTOMRIGHT", o, -o)
                b.leelLA:Show()
            elseif b.leelLA then
                b.leelLA:Hide()
            end
        end
    end
end


----------------------------------------------------------------------
-- 각진 전술형 (A3): 칸 모서리 꺾쇠 · 깎은 줄 + 눈금 · 가운데 레벨 + 경험치 고리 + 눈금
----------------------------------------------------------------------
local TACCOL = { Horde = { 1.0, 0.29, 0.24 }, Alliance = { 0.29, 0.55, 1.0 } }
local function TacAcc()
    local k = (UnitFactionGroup and UnitFactionGroup("player")) or ""
    return TACCOL[k] or { C.acc[1], C.acc[2], C.acc[3] }
end
local function WTacBar(bar, on, left, BH, acc)
    if not bar.tac then
        local t = {}
        t.mask = bar:CreateMaskTexture()
        t.mask:SetTexture(ns.MEDIA .. "ab_tac_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); t.mask:SetAllPoints()
        t.bg = bar:CreateTexture(nil, "BACKGROUND", nil, 2); t.bg:SetColorTexture(0, 0, 0, 0.6); t.bg:SetAllPoints(); t.bg:AddMaskTexture(t.mask)
        t.lab = ns.Font(bar, 9, { 0.81, 0.78, 0.77 }, "OVERLAY")
        t.val = ns.Font(bar, 12, { 1, 1, 1 }, "OVERLAY")
        t.ticks = {}
        for i = 1, 9 do local k = bar:CreateTexture(nil, "OVERLAY"); k:SetColorTexture(1, 1, 1, 0.25); t.ticks[i] = k end
        bar.tac = t
    end
    local t = bar.tac
    if not t.added and on then
        local st = bar:GetStatusBarTexture()
        if bar.pm then pcall(st.RemoveMaskTexture, st, bar.pm) end
        st:AddMaskTexture(t.mask); t.added = true
    end
    for _, x in ipairs({ t.bg, t.lab, t.val }) do x:SetShown(on) end
    for _, k in ipairs(t.ticks) do k:SetShown(on) end
    if not on then
        if t.added then
            local st = bar:GetStatusBarTexture()
            pcall(st.RemoveMaskTexture, st, t.mask); t.added = nil
            if bar.pm then pcall(st.AddMaskTexture, st, bar.pm) end
        end
        bar.bg:Show()
        return
    end
    bar.t:Hide(); bar.edge:Hide(); bar.bg:Hide()
    for _, x in ipairs({ bar.outer, bar.groove, bar.cap, bar.capIn, bar.gem, bar.rl, bar.rm, bar.rr, bar.gloss, bar.shade }) do if x then x:Hide() end end
    if bar.la then for _, x in ipairs(bar.la) do x:Hide() end end
    bar.n:Hide()
    if left then bar:SetStatusBarColor(acc[1], acc[2], acc[3], 1) end
    local w = bar:GetWidth() or 200
    for i, k in ipairs(t.ticks) do
        k:ClearAllPoints(); k:SetSize(2, 4); k:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", math.floor(w * i / 10), -2)
    end
    pcall(t.lab.SetFont, t.lab, ns.FONT, 9, ""); t.lab:SetText(left and "HP" or "MP")
    pcall(t.val.SetFont, t.val, ns.NUM or ns.FONT, 12, "OUTLINE")
    pcall(bar.pc.SetFont, bar.pc, ns.NUM or ns.FONT, 12, "OUTLINE")
    t.lab:ClearAllPoints(); t.val:ClearAllPoints(); bar.pc:ClearAllPoints(); bar.pc:Show()
    if left then
        t.lab:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 4); t.val:SetPoint("LEFT", t.lab, "RIGHT", 8, 0)
        bar.pc:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 3); bar.pc:SetTextColor(math.min(1, acc[1] + 0.2), math.min(1, acc[2] + 0.3), math.min(1, acc[3] + 0.3))
    else
        t.lab:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 4); t.val:SetPoint("RIGHT", t.lab, "LEFT", -8, 0)
        bar.pc:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 3); bar.pc:SetTextColor(0.5, 0.71, 1)
    end
    bar.tacVal = t.val
end

-- 나 찍기: 생명력 줄 · 가운데 레벨 원을 누르면 나를 대상 (오른쪽 = 내 메뉴)
local function WSelfBtn(anchor, l, t, r, b, tipText)
    local btn = CreateFrame("Button", nil, holder, "SecureUnitButtonTemplate")
    btn:SetAttribute("unit", "player")
    btn:SetAttribute("*type1", "target")
    btn:SetAttribute("*type2", "togglemenu")
    btn:RegisterForClicks("AnyUp")
    btn:SetPoint("TOPLEFT", anchor, "TOPLEFT", l, t); btn:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", r, b)
    btn:SetFrameLevel(anchor:GetFrameLevel() + 8)
    local hl = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = btn:CreateTexture(nil, "OVERLAY"); e:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.9)
        if side == "TOP" or side == "BOTTOM" then e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(1.5)
        else e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(1.5) end
        e:Hide(); hl[#hl + 1] = e
    end
    btn.hl = hl
    btn:HookScript("OnEnter", function(self)
        if not self.noEdge then for _, e in ipairs(hl) do e:Show() end end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(tipText, C.acc[1], C.acc[2], C.acc[3])
        GameTooltip:AddLine("왼쪽 클릭 = 나를 대상 · 오른쪽 클릭 = 내 메뉴", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", function() for _, e in ipairs(hl) do e:Hide() end; GameTooltip:Hide() end)
    return btn
end
local function WSelfTarget(on)
    if InCombatLockdown() then pending = true return end
    if on and not wing.selfHP then
        wing.selfHP = WSelfBtn(wing.hp, -2, 20, 2, -2, "내 생명력")
        wing.selfRing = WSelfBtn(wing.big, 0, 0, 0, 0, "나")
        wing.selfRing.noEdge = true
        -- 원은 둥근 빛으로
        local g = wing.selfRing:CreateTexture(nil, "OVERLAY"); g:SetTexture(ns.MEDIA .. "ring"); g:SetAllPoints()
        g:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.9); g:Hide()
        wing.selfRing:HookScript("OnEnter", function() g:Show() end)
        wing.selfRing:HookScript("OnLeave", function() g:Hide() end)
    end
    if wing.selfHP then wing.selfHP:SetShown(on); wing.selfRing:SetShown(on) end
end

-- 들어오는 치유: 내 생명력 줄 끝에 민트로 이어서 + 숫자 (+350)
local function WHealBar(on)
    local hp = wing.hp
    if on and not wing.heal and hp.tac then
        local h = CreateFrame("StatusBar", nil, hp)
        h:SetStatusBarTexture(ns.WHITE or "Interface\\Buttons\\WHITE8x8")
        h:SetStatusBarColor(0.45, 0.92, 0.72, 0.65)
        h:SetFrameLevel(hp:GetFrameLevel())
        h:SetPoint("TOPLEFT", hp:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
        h:SetPoint("BOTTOMLEFT", hp:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
        h:SetMinMaxValues(0, 1); h:SetValue(0)
        h:GetStatusBarTexture():AddMaskTexture(hp.tac.mask)
        wing.heal = h
        wing.healT = ns.Font(hp, 12, { 0.55, 0.95, 0.78 }, "OVERLAY")
        pcall(wing.healT.SetFont, wing.healT, ns.NUM or ns.FONT, 12, "OUTLINE")
    end
    if not wing.heal then return end
    wing.heal:SetShown(on); wing.healT:SetShown(on)
    if on then
        wing.heal:SetWidth(hp:GetWidth() or 200)
        wing.healT:ClearAllPoints()
        if hp.tacVal then wing.healT:SetPoint("LEFT", hp.tacVal, "RIGHT", 6, 0) end
    end
end
local function WUpdateHeal()
    if not (wing and wing.heal and wing.heal:IsShown()) then return end
    local hm = UnitHealthMax("player")
    local okI, inc = pcall(UnitGetIncomingHeals, "player")
    if not okI then inc = nil end
    pcall(wing.heal.SetMinMaxValues, wing.heal, 0, hm)
    if inc == nil or not pcall(wing.heal.SetValue, wing.heal, inc) then wing.heal:SetValue(0) end
    local shown = pcall(function()
        if inc and inc > 0 then wing.healT:SetFormattedText("+%s", BreakUpLargeNumbers(inc)); wing.healT:Show()
        else wing.healT:SetText("") end
    end)
    if not shown then wing.healT:SetText("") end
end
ns.ABarHealUpdate = WUpdateHeal


-- 펫 원 (모던): 생명력 줄 왼쪽 끝 · 동그란 펫 얼굴 + 둘레 빨간 고리 = 펫 체력 · LV
--  왼쪽 클릭 = 펫 기술이 원 둘레 부채꼴로 펼쳐짐 (다시 누르면 접힘 · 전투 중에도) · 오른쪽 클릭 = 펫 대상
local function WPetUpdate()
    local P = wing and wing.pet
    if not P or not UnitExists("pet") then return end
    pcall(SetPortraitTexture, P.por, "pet")
    local okL, lv = pcall(UnitLevel, "pet")
    P.lv:SetText((okL and type(lv) == "number" and not (issecretvalue and issecretvalue(lv)) and lv > 0) and lv or "")
    P.lvb:SetWidth(math.max(18, (P.lv:GetStringWidth() or 10) + 10))
    local ok, f = pcall(function() local h, m = UnitHealth("pet"), UnitHealthMax("pet"); return (m and m > 0) and h / m or 0 end)
    if ok and type(f) == "number" and not (issecretvalue and issecretvalue(f)) then P.frac = f end
    local fr = P.frac or 1
    P.ring:Set(fr)
    local low = fr < 0.3
    if low ~= P.low then
        P.low = low
        if low then P.glow:Show(); P.gag:Play() else P.gag:Stop(); P.glow:Hide() end
    end
end
ns.ABarPetUpdate = WPetUpdate

local function WPetArc()
    local P = wing and wing.pet
    if not P or InCombatLockdown() then return end
    local btns = Buttons("PetActionButton", 10)
    local sz = math.max(28, math.floor(PET * 1.0 + 0.5))
    local R = P.size * 0.5 + sz * 0.5 + 95
    local list = {}
    for i = 1, 7 do
        local b = btns[i]
        if b then
            local ok, name, tex = pcall(GetPetActionInfo, i)
            if ok and (name or tex) then list[#list + 1] = b else b:SetAlpha(0); b:ClearAllPoints(); b:SetPoint("CENTER", P.btn, "CENTER") end
        end
    end
    local n = #list
    local span = math.min(95, math.max(30, (n - 1) * 16))
    for k, b in ipairs(list) do
        if b:GetParent() ~= P.pop then b.leelOrigParent = b.leelOrigParent or b:GetParent(); b:SetParent(P.pop) end
        b:SetAlpha(1); b:SetSize(sz, sz); b:ClearAllPoints()
        -- 왼쪽(180°)에서 위쪽으로 부채꼴
        local a = math.rad(180 - ((n > 1) and (k - 1) * span / (n - 1) or 0))
        b:SetPoint("CENTER", P.btn, "CENTER", R * math.cos(a), R * math.sin(a))
    end
    -- 8 · 9 · 10 = 공격적 · 방어적 · 수동 (원 안쪽 위 한 줄)
    for k = 8, 10 do
        local b = btns[k]
        if b then
            if b:GetParent() ~= P.pop then b.leelOrigParent = b.leelOrigParent or b:GetParent(); b:SetParent(P.pop) end
            b:SetAlpha(1); b:SetSize(sz - 6, sz - 6); b:ClearAllPoints()
            b:SetPoint("CENTER", P.btn, "CENTER", -52 + (k - 9) * (sz - 2), 58)
        end
    end
    for i = 1, 7 do local b = btns[i]; if b and b:GetParent() ~= P.pop then b.leelOrigParent = b.leelOrigParent or b:GetParent(); b:SetParent(P.pop) end end
end

local function WPetRing(on)
    if InCombatLockdown() then pending = true return end
    if on and not wing.pet then
        local P = {}
        local SZ = 60
        P.size = SZ
        local b = CreateFrame("Button", "LeelUI_PetRing", holder, "SecureActionButtonTemplate")
        b:SetSize(SZ, SZ)
        b:SetAttribute("unit", "pet")
        b:SetAttribute("*type2", "target")
        b:SetAttribute("*type1", "click")
        -- 게임 설정 "키를 누를 때 실행"이 켜져 있으면 보안 단추는 누를 때(down)만 동작 → 둘 다 받기
        b:RegisterForClicks("AnyUp", "AnyDown")
        local tog = CreateFrame("Button", "LeelUI_PetPopToggle", b, "SecureHandlerClickTemplate")
        local pop = CreateFrame("Frame", "LeelUI_PetPop", b)
        pop:SetAllPoints(b); pop:SetFrameLevel(b:GetFrameLevel() + 6); pop:Hide()
        tog:SetFrameRef("pop", pop)
        tog:SetAttribute("_onclick", [[ local p = self:GetFrameRef("pop"); if p:IsShown() then p:Hide() else p:Show() end ]])
        b:SetAttribute("*clickbutton1", tog)
        P.btn, P.pop, P.tog = b, pop, tog
        -- 그림
        local sh = b:CreateTexture(nil, "BACKGROUND", nil, -2); sh:SetTexture(ns.MEDIA .. "circle"); sh:SetVertexColor(0, 0, 0, 0.75)
        sh:SetPoint("TOPLEFT", -3, 3); sh:SetPoint("BOTTOMRIGHT", 3, -3)
        local bg = b:CreateTexture(nil, "BACKGROUND", nil, 1); bg:SetTexture(ns.MEDIA .. "circle"); bg:SetVertexColor(0.04, 0.035, 0.05, 1); bg:SetAllPoints()
        P.por = b:CreateTexture(nil, "ARTWORK")
        P.por:SetPoint("TOPLEFT", 7, -7); P.por:SetPoint("BOTTOMRIGHT", -7, 7)
        local m = b:CreateMaskTexture(); m:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); m:SetAllPoints(P.por)
        P.por:AddMaskTexture(m)
        local rsz = (SZ / 2 - 3) / 0.9 * 2
        local track = b:CreateTexture(nil, "ARTWORK", nil, 1); track:SetTexture(ns.MEDIA .. "ab_tac_ring")
        track:SetSize(rsz, rsz); track:SetPoint("CENTER"); track:SetVertexColor(1, 1, 1, 0.14)
        -- 체력 고리: 반쪽 고리 두 장을 반쪽 창 안에서 돌려요 (가운데 원과 같은 방법)
        local g = {}
        g.R = CreateFrame("Frame", nil, b); g.L = CreateFrame("Frame", nil, b)
        for _, f in ipairs({ g.R, g.L }) do f:SetClipsChildren(true); f:SetFrameLevel(b:GetFrameLevel() + 2) end
        g.tR = g.R:CreateTexture(nil, "ARTWORK"); g.tR:SetTexture(ns.MEDIA .. "ab_tac_halfL")
        g.tL = g.L:CreateTexture(nil, "ARTWORK"); g.tL:SetTexture(ns.MEDIA .. "ab_tac_halfR")
        g.R:SetPoint("TOPLEFT", b, "CENTER", 0, rsz / 2); g.R:SetSize(rsz / 2 + 2, rsz)
        g.L:SetPoint("TOPRIGHT", b, "CENTER", 0, rsz / 2); g.L:SetSize(rsz / 2 + 2, rsz)
        for _, t in ipairs({ g.tR, g.tL }) do t:SetSize(rsz, rsz); t:SetPoint("CENTER", b, "CENTER"); t:SetVertexColor(1, 0.29, 0.24, 1) end
        function g:Set(f)
            f = math.max(0, math.min(1, f or 0))
            self.tR:SetRotation(-math.min(f, 0.5) * 2 * math.pi); self.R:SetShown(f > 0)
            self.tL:SetRotation(-math.max(0, f - 0.5) * 2 * math.pi); self.L:SetShown(f > 0.5)
        end
        P.ring = g
        -- 체력 낮음 (30% 아래): 빨간 빛 깜빡
        P.glow = b:CreateTexture(nil, "BACKGROUND", nil, -3); P.glow:SetTexture(ns.MEDIA .. "circle"); P.glow:SetBlendMode("ADD")
        P.glow:SetVertexColor(1, 0.25, 0.2, 0.7); P.glow:SetPoint("TOPLEFT", -10, 10); P.glow:SetPoint("BOTTOMRIGHT", 10, -10); P.glow:Hide()
        P.gag = P.glow:CreateAnimationGroup(); P.gag:SetLooping("BOUNCE")
        local ga = P.gag:CreateAnimation("Alpha"); ga:SetFromAlpha(0.2); ga:SetToAlpha(1); ga:SetDuration(0.5); ga:SetSmoothing("IN_OUT")
        -- LV (금 칸)
        local over = CreateFrame("Frame", nil, b); over:SetAllPoints(); over:SetFrameLevel(b:GetFrameLevel() + 4)
        P.lvb = CreateFrame("Frame", nil, over); P.lvb:SetHeight(15); P.lvb:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 6, -3)
        local lb = P.lvb:CreateTexture(nil, "ARTWORK"); lb:SetAllPoints(); lb:SetColorTexture(0.91, 0.75, 0.38, 1)
        P.lv = P.lvb:CreateFontString(nil, "OVERLAY"); P.lv:SetFont(ns.NUM or ns.FONT, 11, ""); P.lv:SetTextColor(0.1, 0.08, 0.07); P.lv:SetPoint("CENTER", 0, 0)
        -- 마우스 올리면 분홍 고리 + 설명
        local hl = over:CreateTexture(nil, "OVERLAY"); hl:SetTexture(ns.MEDIA .. "ring"); hl:SetAllPoints(); hl:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.9); hl:Hide()
        b:HookScript("OnEnter", function(self)
            hl:Show()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            local okN, nm = pcall(UnitName, "pet")
            GameTooltip:AddLine(okN and nm or "펫", C.acc[1], C.acc[2], C.acc[3])
            GameTooltip:AddLine("왼쪽 클릭 = 펫 기술 펼치기 · 접기", 1, 1, 1)
            GameTooltip:AddLine("오른쪽 클릭 = 펫 대상", 0.85, 0.8, 0.8)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() hl:Hide(); GameTooltip:Hide() end)
        RegisterStateDriver(b, "visibility", "[@pet,exists] show; hide")
        local ev = CreateFrame("Frame")
        for _, e in ipairs({ "UNIT_PET", "PET_BAR_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
        for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_PORTRAIT_UPDATE", "UNIT_LEVEL", "UNIT_MODEL_CHANGED" }) do pcall(ev.RegisterUnitEvent, ev, e, "pet") end
        ev:SetScript("OnEvent", function(_, e)
            if not (wing.pet and wing.pet.on) then return end
            if e == "UNIT_PET" or e == "PET_BAR_UPDATE" or e == "PLAYER_REGEN_ENABLED" or e == "PLAYER_ENTERING_WORLD" then
                C_Timer.After(0.1, function() WPetArc(); WPetUpdate() end)
            else WPetUpdate() end
        end)
        wing.pet = P
    end
    local P = wing.pet
    if not P then return end
    P.on = on
    if on then
        P.btn:ClearAllPoints(); P.btn:SetPoint("RIGHT", wing.hp, "LEFT", -8, -2)
        RegisterStateDriver(P.btn, "visibility", "[@pet,exists] show; hide")
        WPetArc(); WPetUpdate()
    else
        UnregisterStateDriver(P.btn, "visibility"); P.btn:Hide()
        for _, b in ipairs(Buttons("PetActionButton", 10)) do
            if b.leelOrigParent and b:GetParent() == P.pop then b:SetParent(b.leelOrigParent); b:SetAlpha(1) end
        end
    end
end

local function WTacCenter(on, fac, D)
    local big = wing.big
    if on and not wing.tc then
        local T2 = {}
        T2.fill = big:CreateTexture(nil, "BACKGROUND", nil, 2); T2.fill:SetTexture(ns.MEDIA .. "circle")
        T2.edge = big:CreateTexture(nil, "BACKGROUND", nil, 1); T2.edge:SetTexture(ns.MEDIA .. "circle")
        T2.emb = big:CreateTexture(nil, "ARTWORK", nil, -2)
        -- 경험치 고리: 매끈한 고리 그림 + 쿨다운 돌림(멈춘 채)으로 비율만큼 · 둘레 눈금도 한 장 그림
        T2.track = big:CreateTexture(nil, "ARTWORK", nil, 1); T2.track:SetTexture(ns.MEDIA .. "ab_tac_ring")
        T2.ticks = big:CreateTexture(nil, "ARTWORK", nil, 1); T2.ticks:SetTexture(ns.MEDIA .. "ab_tac_ticks")
        -- 반쪽 고리 두 장을 반쪽 창(넘치면 잘림) 안에서 돌려서 비율만큼 보여요
        local function Ring(lv)
            local g = { }
            g.R = CreateFrame("Frame", nil, big); g.L = CreateFrame("Frame", nil, big)
            for _, f in ipairs({ g.R, g.L }) do f:SetClipsChildren(true); f:SetFrameLevel(big:GetFrameLevel() + lv) end
            g.tR = g.R:CreateTexture(nil, "ARTWORK"); g.tR:SetTexture(ns.MEDIA .. "ab_tac_halfL")
            g.tL = g.L:CreateTexture(nil, "ARTWORK"); g.tL:SetTexture(ns.MEDIA .. "ab_tac_halfR")
            function g:SetShown(v) self.R:SetShown(v); self.L:SetShown(v) end
            function g:Show() self:SetShown(true) end
            function g:Hide() self:SetShown(false) end
            function g:Place(sz)
                self.R:ClearAllPoints(); self.R:SetPoint("TOPLEFT", big, "CENTER", 0, sz / 2); self.R:SetSize(sz / 2 + 2, sz)
                self.L:ClearAllPoints(); self.L:SetPoint("TOPRIGHT", big, "CENTER", 0, sz / 2); self.L:SetSize(sz / 2 + 2, sz)
                for _, t in ipairs({ self.tR, self.tL }) do t:ClearAllPoints(); t:SetSize(sz, sz); t:SetPoint("CENTER", big, "CENTER") end
            end
            function g:Color(r, gg, b, a) self.tR:SetVertexColor(r, gg, b, a); self.tL:SetVertexColor(r, gg, b, a) end
            function g:Set(f)
                f = math.max(0, math.min(1, f or 0))
                -- 오른쪽 반: 왼쪽 반 고리를 시계 방향으로 f*360 (최대 180) 돌려서 위에서부터 채움
                local a1 = math.min(f, 0.5) * 2 * math.pi
                self.tR:SetRotation(-a1); self.R:SetShown(f > 0)
                -- 왼쪽 반: 오른쪽 반 고리를 (f-0.5)*360 돌려서 아래에서부터 채움
                local a2 = math.max(0, f - 0.5) * 2 * math.pi
                self.tL:SetRotation(-a2); self.L:SetShown(f > 0.5)
            end
            return g
        end
        T2.restCD = Ring(1); T2.cd = Ring(2)
        T2.xp, T2.tk = {}, {}
        T2.tipG = big:CreateTexture(nil, "OVERLAY", nil, 1); T2.tipG:SetTexture(ns.MEDIA .. "circle")
        T2.tip = big:CreateTexture(nil, "OVERLAY", nil, 2); T2.tip:SetTexture(ns.MEDIA .. "circle"); T2.tip:SetVertexColor(1, 1, 1, 1)
        T2.cap = ns.Font(big, 8, { 0.81, 0.78, 0.77 }, "OVERLAY"); T2.cap:SetText("LEVEL")
        T2.lv = ns.Font(big, 30, { 1, 1, 1 }, "OVERLAY")
        T2.pc = ns.Font(big, 9, { 1, 0.6, 0.5 }, "OVERLAY")
        wing.tc = T2
    end
    local T2 = wing.tc
    if not T2 then return end
    for _, k in ipairs({ "fill", "edge", "emb", "cap", "lv", "pc", "tip", "tipG", "track", "ticks", "cd", "restCD" }) do T2[k]:SetShown(on) end
    if not on then return end
    local acc = TacAcc(); T2.acc = acc
    local R = D / 2
    T2.fill:ClearAllPoints(); T2.fill:SetPoint("CENTER", big, "CENTER"); T2.fill:SetSize(D, D); T2.fill:SetVertexColor(0.03, 0.03, 0.045, 0.82)
    T2.edge:ClearAllPoints(); T2.edge:SetPoint("CENTER", big, "CENTER"); T2.edge:SetSize(D + 2, D + 2); T2.edge:SetVertexColor(1, 1, 1, 0.18)
    T2.emb:SetTexture(fac and fac.logo or (ns.MEDIA .. "icon")); T2.emb:SetVertexColor(1, 1, 1, 0.13)
    T2.emb:ClearAllPoints(); T2.emb:SetPoint("CENTER", big, "CENTER"); T2.emb:SetSize(D * 0.85, D * 0.85)
    local rx = R + math.max(5, D * 0.08)                 -- 경험치 고리 반지름
    local ds = math.max(3, math.floor(D * 0.05 + 0.5))   -- 고리 굵기
    local rsz = rx / 0.9 * 2                             -- 고리 그림: 반지름 0.9 자리에 굵기 0.09
    T2.ringR, T2.ds = rx, ds
    T2.track:ClearAllPoints(); T2.track:SetSize(rsz, rsz); T2.track:SetPoint("CENTER", big, "CENTER"); T2.track:SetVertexColor(1, 1, 1, 0.1)
    for _, cd in ipairs({ T2.cd, T2.restCD }) do cd:Place(rsz) end
    T2.cd:Color(acc[1], acc[2], acc[3], 1); T2.restCD:Color(0.5, 0.71, 1, 0.5)
    local rt = rx + ds / 2 + 4
    local tsz = rt / 0.86 * 2
    T2.ticks:ClearAllPoints(); T2.ticks:SetSize(tsz, tsz); T2.ticks:SetPoint("CENTER", big, "CENTER"); T2.ticks:SetVertexColor(1, 1, 1, 0.55)
    rt = tsz / 2
    T2.tipG:SetSize(ds * 3, ds * 3); T2.tipG:SetVertexColor(acc[1], acc[2], acc[3], 0.35); T2.tipG:ClearAllPoints(); T2.tipG:SetPoint("CENTER", T2.tip, "CENTER")
    T2.tip:SetSize(ds, ds)
    pcall(T2.lv.SetFont, T2.lv, ns.NUM or ns.FONT, math.max(16, math.floor(D * 0.32)), "")
    pcall(T2.cap.SetFont, T2.cap, ns.FONT, math.max(7, math.floor(D * 0.085)), "")
    pcall(T2.pc.SetFont, T2.pc, ns.NUM or ns.FONT, math.max(8, math.floor(D * 0.1)), "")
    T2.pc:SetTextColor(math.min(1, acc[1] + 0.2), math.min(1, acc[2] + 0.3), math.min(1, acc[3] + 0.3))
    T2.cap:ClearAllPoints(); T2.cap:SetPoint("CENTER", big, "CENTER", 0, D * 0.2)
    T2.lv:ClearAllPoints(); T2.lv:SetPoint("CENTER", big, "CENTER", 0, -D * 0.02)
    T2.pc:ClearAllPoints(); T2.pc:SetPoint("CENTER", big, "CENTER", 0, -D * 0.27)
    wing.xpt:ClearAllPoints(); wing.xpt:SetPoint("TOP", big, "CENTER", 0, -rt - 6); wing.xpt:Show()
    wing.xpt:SetTextColor(0.85, 0.82, 0.8)
end

local function WTacSlots(on)
    if not ROWS then return end
    local acc = TacAcc()
    for _, row in ipairs(ROWS) do
        for _, b in ipairs(row.btns) do
            if on and b:GetAlpha() > 0 then
                if not b.leelTac then
                    local t = {}
                    for i = 1, 8 do t[i] = b:CreateTexture(nil, "OVERLAY", nil, 6) end
                    t.ln = b:CreateTexture(nil, "OVERLAY", nil, 5)
                    b.leelTac = t
                end
                local t = b.leelTac
                local w = b:GetWidth() or 40
                local c = math.max(4, math.floor(w * 0.12 + 0.5))
                local pts = { { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMRIGHT", -1, 1 }, { "BOTTOMLEFT", 1, 1 } }
                for k, p in ipairs(pts) do
                    local h, v = t[k * 2 - 1], t[k * 2]
                    h:SetColorTexture(acc[1], acc[2], acc[3], 0.9); v:SetColorTexture(acc[1], acc[2], acc[3], 0.9)
                    h:ClearAllPoints(); v:ClearAllPoints()
                    h:SetSize(c, 2); v:SetSize(2, c)
                    h:SetPoint(p[1], b, p[1], 0, 0); v:SetPoint(p[1], b, p[1], 0, 0)
                    h:Show(); v:Show()
                end
                t.ln:Hide()
            elseif b.leelTac then
                for i = 1, 8 do b.leelTac[i]:Hide() end
            end
        end
    end
end

-- 각진 전술형: 생명력 줄 위 = 내 버프 · 마나 줄 위 = 나에게 걸린 디버프
--  * WoW Forever는 애드온이 오라를 직접 못 읽어서 게임 공식 오라 칸(CustomAuraContainer)에 모양만 입혀요
local function TacAuraInit(debuff, sz)
    return function(btn)
        btn:SetSize(sz, sz)
        local acc = debuff and { 1, 0.29, 0.24 } or { 1, 1, 1 }
        local bg = btn:CreateTexture(nil, "BACKGROUND", nil, -8); bg:SetColorTexture(0, 0, 0, 0.85)
        bg:SetPoint("TOPLEFT", -1, 1); bg:SetPoint("BOTTOMRIGHT", 1, -1)
        local icon = btn:CreateTexture(nil, "ARTWORK"); icon:SetAllPoints(); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn:SetIcon(icon)
        local ov = CreateFrame("Frame", nil, btn); ov:SetAllPoints(); ov:SetFrameLevel(btn:GetFrameLevel() + 3)
        local c = math.max(4, math.floor(sz * 0.22))
        for _, pt in ipairs({ "TOPLEFT", "BOTTOMRIGHT" }) do
            local h = ov:CreateTexture(nil, "OVERLAY"); h:SetColorTexture(acc[1], acc[2], acc[3], debuff and 0.95 or 0.5); h:SetSize(c, 1.2); h:SetPoint(pt)
            local v = ov:CreateTexture(nil, "OVERLAY"); v:SetColorTexture(acc[1], acc[2], acc[3], debuff and 0.95 or 0.5); v:SetSize(1.2, c); v:SetPoint(pt)
        end
        local strip = ov:CreateTexture(nil, "ARTWORK"); strip:SetColorTexture(0, 0, 0, 0.55)
        strip:SetPoint("BOTTOMLEFT"); strip:SetPoint("BOTTOMRIGHT"); strip:SetHeight(math.max(8, math.floor(sz * 0.38)))
        local tm = ov:CreateFontString(nil, "OVERLAY")
        local fs = math.max(8, math.floor(sz * 0.36))
        local fmt = ns.AuraDurFmt and ns.AuraDurFmt()
        tm:SetFont(ns.NUM or ns.FONT, fs, "OUTLINE")
        if debuff then tm:SetTextColor(1, 0.82, 0.78) end
        if not (fmt and pcall(btn.SetDurationText, btn, tm, { textFormatter = fmt })) then
            tm:SetFont(ns.FONT, fs, "OUTLINE"); pcall(btn.SetDurationText, btn, tm)
        end
        tm:SetPoint("BOTTOM", 0, 0)
        local cnt = ov:CreateFontString(nil, "OVERLAY"); cnt:SetFont(ns.NUM or ns.FONT, fs, "OUTLINE"); cnt:SetPoint("TOPRIGHT", -1, -1)
        pcall(btn.SetApplicationCount, btn, cnt)
    end
end

local function WTacAuras(on, sz)
    if on and not wing.au then
        local au = {}
        for _, k in ipairs({ "b", "d" }) do
            local ok, c = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
            if ok and c then
                local dbf = k == "d"
                local bar = dbf and wing.mp or wing.hp
                local n = math.max(3, math.floor((bar:GetWidth() or 200) / (sz + 5)))
                local ok2, err2 = pcall(function()
                    if dbf then
                        c:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 20)
                        if c.SetFlowLayoutAnchorPoint then c:SetFlowLayoutAnchorPoint("BOTTOMRIGHT") end
                        if c.SetFlowLayoutGrowthDirection and AnchorUtil and AnchorUtil.FlowDirection then
                            c:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Up)
                        end
                    else
                        c:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 20)
                        if c.SetFlowLayoutAnchorPoint then c:SetFlowLayoutAnchorPoint("BOTTOMLEFT") end
                        if c.SetFlowLayoutGrowthDirection and AnchorUtil and AnchorUtil.FlowDirection then
                            c:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
                        end
                    end
                    c:AddAuraGroup(dbf and "leelTacD" or "leelTacB", dbf and "HARMFUL" or "HELPFUL", {
                        maxFrameCount = n,
                        sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.Expiration or 0,
                        sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal or 0,
                        initializeFrame = TacAuraInit(dbf, sz),
                        layout = { elementSpacing = 5, elementWidth = sz, elementHeight = sz },
                    })
                    c:SetUnit("player")
                end)
                if ok2 then au[k] = c else P("버프 줄을 만들지 못했어요: " .. tostring(err2)) end
            else
                P("이 게임 버전엔 애드온용 오라 칸이 없어서 버프 줄을 못 띄워요.")
            end
        end
        wing.au = au
    end
    if wing.au then
        -- 처음 만들 때 바 자리가 덜 잡혀 있으면 엉뚱한 데 붙을 수 있어서 매번 다시 붙임
        pcall(function()
            local au = wing.au
            if au.d then au.d:ClearAllPoints(); au.d:SetPoint("BOTTOMRIGHT", wing.mp, "TOPRIGHT", 0, 20) end
            if au.b then au.b:ClearAllPoints(); au.b:SetPoint("BOTTOMLEFT", wing.hp, "TOPLEFT", (wing.wenN or 0) * (sz + 5), 20) end
        end)
        for _, c in pairs(wing.au) do c:SetShown(on) end
    end
    -- 무기 강화(질풍의 무기 · 독 등)는 오라가 아니라 게임 오라 칸에 안 나와요 → 버프 줄 맨 앞에 따로 칸 2개
    if on and not wing.wen then
        local wen = {}
        for i = 1, 2 do
            local f = CreateFrame("Frame", nil, holder); f:SetSize(sz, sz)
            local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetColorTexture(0, 0, 0, 0.85); bg:SetPoint("TOPLEFT", -1, 1); bg:SetPoint("BOTTOMRIGHT", 1, -1)
            f.ic = f:CreateTexture(nil, "ARTWORK"); f.ic:SetAllPoints(); f.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local c = math.max(4, math.floor(sz * 0.22))
            for _, pt in ipairs({ "TOPLEFT", "BOTTOMRIGHT" }) do
                local h = f:CreateTexture(nil, "OVERLAY"); h:SetColorTexture(0.75, 0.55, 1, 0.9); h:SetSize(c, 1.5); h:SetPoint(pt)
                local v = f:CreateTexture(nil, "OVERLAY"); v:SetColorTexture(0.75, 0.55, 1, 0.9); v:SetSize(1.5, c); v:SetPoint(pt)
            end
            local strip = f:CreateTexture(nil, "OVERLAY", nil, -1); strip:SetColorTexture(0, 0, 0, 0.55)
            strip:SetPoint("BOTTOMLEFT"); strip:SetPoint("BOTTOMRIGHT"); strip:SetHeight(math.max(8, math.floor(sz * 0.38)))
            f.t = f:CreateFontString(nil, "OVERLAY"); f.t:SetFont(ns.NUM or ns.FONT, math.max(8, math.floor(sz * 0.36)), "OUTLINE"); f.t:SetPoint("BOTTOM", 0, 0)
            f.n = f:CreateFontString(nil, "OVERLAY"); f.n:SetFont(ns.NUM or ns.FONT, math.max(8, math.floor(sz * 0.36)), "OUTLINE"); f.n:SetPoint("TOPRIGHT", -1, -1)
            f:EnableMouse(true)
            f:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP"); pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", self.slot); GameTooltip:Show()
            end)
            f:SetScript("OnLeave", function() GameTooltip:Hide() end)
            f:Hide()
            wen[i] = f
        end
        wing.wen = wen
        local acc = 0
        local tick = CreateFrame("Frame", nil, holder)
        tick:SetScript("OnUpdate", function(_, e)
            acc = acc + e; if acc < 0.5 then return end; acc = 0
            if not wing.wenOn then for _, f in ipairs(wen) do f:Hide() end return end
            local ok, mh, mt, mc, _, oh, ot, oc = pcall(GetWeaponEnchantInfo)
            if not ok then return end
            local list = {}
            if mh then list[#list + 1] = { 16, mt, mc } end
            if oh then list[#list + 1] = { 17, ot, oc } end
            for i, f in ipairs(wen) do
                local d = list[i]
                if d then
                    f.slot = d[1]
                    f.ic:SetTexture(GetInventoryItemTexture("player", d[1]))
                    local left = (type(d[2]) == "number" and not (issecretvalue and issecretvalue(d[2]))) and d[2] / 1000 or nil
                    f.t:SetText(left and (left >= 60 and (math.ceil(left / 60) .. "m") or math.ceil(left)) or "")
                    f.n:SetText((type(d[3]) == "number" and d[3] > 1) and d[3] or "")
                    f:ClearAllPoints(); f:SetPoint("BOTTOMLEFT", wing.hp, "TOPLEFT", (i - 1) * (wing.wenSz + 5), 20)
                    f:Show()
                else f:Hide() end
            end
            -- 버프 칸은 무기 칸 뒤에서 시작
            local n = #list
            if wing.au and wing.au.b and wing.wenN ~= n then
                wing.wenN = n
                pcall(function() wing.au.b:ClearAllPoints(); wing.au.b:SetPoint("BOTTOMLEFT", wing.hp, "TOPLEFT", n * (wing.wenSz + 5), 20) end)
            end
        end)
    end
    wing.wenOn = on; wing.wenSz = sz
    if wing.wen and not on then for _, f in ipairs(wing.wen) do f:Hide() end end
    -- 게임 기본 버프 창은 숨겨요 (같은 걸 두 번 안 보이게) · 다른 스킨이면 다시 보여요
    local bf = _G.BuffFrame
    if bf then
        wing.hideBuff = on and wing.au ~= nil and next(wing.au) ~= nil
        if not wing.bfHooked then
            wing.bfHooked = true
            bf:HookScript("OnShow", function(self) if wing.hideBuff and not InCombatLockdown() then self:Hide() end end)
        end
        pcall(bf.SetShown, bf, not wing.hideBuff)
        local dfr = _G.DebuffFrame
        if dfr then pcall(dfr.SetShown, dfr, not wing.hideBuff) end
        local te = _G.TemporaryEnchantFrame
        if te then pcall(te.SetShown, te, not wing.hideBuff) end
    end
end

local function WSkin()
    if not wing or not wing.geo then return end
    local skin = DB().wskin
    local la = skin == "la"
    local tac = skin == "tac"
    local real = skin == "gold" or skin == "iron"
    local metal = WMetal()
    wing.real = real; wing.la = la; wing.tac = tac
    local g = wing.geo
    local fac = FAC[(UnitFactionGroup and UnitFactionGroup("player")) or ""]
    WSkinBar(wing.hp, real, true, g.BH, metal)
    WSkinBar(wing.mp, real, false, g.BH, metal)
    WLABar(wing.hp, la, true, g.u or 1, g.BH)
    WLABar(wing.mp, la, false, g.u or 1, g.BH)
    WTacBar(wing.hp, tac, true, g.BH, TacAcc())
    WTacBar(wing.mp, tac, false, g.BH, TacAcc())
    local big, D = wing.big, g.D
    for _, l in ipairs({ wing.lnL, wing.lnR }) do l:SetShown(real); l:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.9) end
    -- 실사 원 부품 (처음 한 번 만들기)
    if (real or la or tac) and not wing.disc then
        wing.disc = big:CreateTexture(nil, "ARTWORK", nil, -3)
        wing.symSh = big:CreateTexture(nil, "ARTWORK", nil, -2)
        wing.symHi = big:CreateTexture(nil, "ARTWORK", nil, -1)
        wing.rimg = big:CreateTexture(nil, "OVERLAY", nil, 4)
        wing.xpd = {}
        for i = 1, 72 do
            local t = big:CreateTexture(nil, "OVERLAY", nil, 2); t:SetTexture(ns.MEDIA .. "circle"); wing.xpd[i] = t
        end
        wing.xpt = ns.Font(wing.core, 11, { 0.89, 0.76, 1 }, "OVERLAY")
        pcall(wing.xpt.SetShadowOffset, wing.xpt, 1, -1)
        local b = wing.badge
        b.lv = ns.Font(b, 8, { 1, 0.91, 0.76 }, "OVERLAY"); b.lv:SetText("LV")
    end
    local rs = math.floor(D * 1.22)        -- 금속 테 지름
    local ds = math.floor(rs * 0.74)       -- 가죽 판
    if wing.disc then
        for _, t in ipairs({ wing.disc, wing.symSh, wing.symHi, wing.rimg, wing.xpt, wing.badge.lv }) do t:SetShown(real) end
        for _, t in ipairs(wing.xpd) do t:SetShown(real) end
    end
    local fancy = real or la or tac
    for _, t in ipairs({ big.edge, big.ring, big.fill }) do t:SetShown(not fancy) end
    if wing.pips then for _, t in ipairs(wing.pips) do t:SetShown(not fancy) end end
    for _, o in ipairs({ wing.prev, wing.next }) do o:SetShown(not fancy) end
    wing.zk:SetShown(not fancy and DB().pgKeys == "zx"); wing.xk:SetShown(not fancy and DB().pgKeys == "zx")
    if xp then xp:SetAlpha(fancy and 0 or 1) end
    for _, l in ipairs({ wing.lnL, wing.lnR }) do if la then l:Hide() end end
    WLA(la, fac, g.u or 1)
    WLASlots(la)
    WTacCenter(tac, fac, D)
    WTacSlots(tac)
    WTacAuras(tac and DB().tacAuras ~= false, g.asz or 24)
    WSelfTarget(tac)
    WHealBar(tac)
    WPetRing(tac)
    if tac then wing.bun:Hide(); wing.badge:Hide() else wing.bun:Show(); wing.badge:Show() end
    local b = wing.badge
    if real then
        wing.lnL:SetStartPoint("RIGHT", wing.hp, 4, 0); wing.lnL:SetEndPoint("CENTER", big, -rs * 0.22, rs * 0.44)
        wing.lnR:SetStartPoint("LEFT", wing.mp, -4, 0); wing.lnR:SetEndPoint("CENTER", big, rs * 0.22, rs * 0.44)
        wing.rimg:SetTexture(ns.MEDIA .. "ab_ring_" .. metal)
        wing.rimg:ClearAllPoints(); wing.rimg:SetSize(rs, rs); wing.rimg:SetPoint("CENTER", big, "CENTER", 0, 0)
        wing.disc:SetTexture(ns.MEDIA .. (fac and fac.disc or "ab_disc_blue"))
        wing.disc:ClearAllPoints(); wing.disc:SetSize(ds, ds); wing.disc:SetPoint("CENTER", big, "CENTER", 0, 0)
        -- 문장: 게임 안 진영 로고 + 그늘 · 빛 겹쳐 입체
        local ss = math.floor(ds * 0.92)
        local logo = fac and fac.logo or (ns.MEDIA .. "icon")
        wing.bun:SetTexture(logo); wing.bun:SetTexCoord(0, 1, 0, 1); wing.bun:SetVertexColor(1, 1, 1, 1)
        wing.bun:ClearAllPoints(); wing.bun:SetSize(ss, ss); wing.bun:SetPoint("CENTER", big, "CENTER", 0, 0)
        wing.symSh:SetTexture(logo); wing.symSh:SetVertexColor(0, 0, 0, 0.85)
        wing.symSh:ClearAllPoints(); wing.symSh:SetSize(ss, ss); wing.symSh:SetPoint("CENTER", big, "CENTER", 3, -3)
        wing.symHi:SetTexture(logo); wing.symHi:SetVertexColor(1, 0.86, 0.6, 0.9); pcall(wing.symHi.SetDesaturated, wing.symHi, true)
        wing.symHi:ClearAllPoints(); wing.symHi:SetSize(ss, ss); wing.symHi:SetPoint("CENTER", big, "CENTER", -1, 1)
        -- 경험치 고리 (점 72개를 이어 붙여 둥근 줄처럼)
        local R0, dsz = ds / 2 - math.max(3, D * 0.04), math.max(4, math.floor(D * 0.065))
        for i, t in ipairs(wing.xpd) do
            local a = math.pi / 2 - (i - 0.5) / #wing.xpd * 2 * math.pi
            t:ClearAllPoints(); t:SetSize(dsz, dsz); t:SetPoint("CENTER", big, "CENTER", math.cos(a) * R0, math.sin(a) * R0)
        end
        wing.xpt:ClearAllPoints(); wing.xpt:SetPoint("TOP", big, "CENTER", 0, -rs / 2 - 2)
        -- 레벨 보석 (위 가운데)
        local gs = math.floor(rs * 0.2)
        b:ClearAllPoints(); b:SetSize(gs, gs); b:SetPoint("CENTER", big, "CENTER", 0, rs / 2 - 2)
        b.bt:SetTexture(ns.MEDIA .. (fac and fac.gem or "ab_gem_blue")); b.bt:SetVertexColor(1, 1, 1, 1)
        b.edge:SetTexture(ns.MEDIA .. "ab_cap_" .. metal); b.edge:SetVertexColor(1, 1, 1, 1)
        b.edge:ClearAllPoints(); b.edge:SetPoint("CENTER", 0, 0); b.edge:SetSize(math.floor(rs * 0.32), math.floor(rs * 0.32)); b.edge:Show()
        b.t:SetTextColor(1, 1, 1); pcall(b.t.SetFont, b.t, ns.NUM or ns.FONT, math.max(10, math.floor(gs * 0.5)), "OUTLINE")
        b.t:ClearAllPoints(); b.t:SetPoint("CENTER", 0, -math.floor(gs * 0.12))
        b.lv:ClearAllPoints(); b.lv:SetPoint("BOTTOM", b.t, "TOP", 0, -2)
        WUpdateXP()
    elseif la then
        wing.symSh:Hide(); wing.symHi:Hide()
        WUpdateXP()
    elseif tac then
        wing.symSh:Hide(); wing.symHi:Hide()
        WUpdateXP()
    else
        big.edge:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
        big.edge:ClearAllPoints(); big.edge:SetPoint("TOPLEFT", -3, 3); big.edge:SetPoint("BOTTOMRIGHT", 3, -3)
        big.ring:SetVertexColor(0.1, 0.07, 0.07, 1)
        big.ring:ClearAllPoints(); big.ring:SetPoint("TOPLEFT", -6, 6); big.ring:SetPoint("BOTTOMRIGHT", 6, -6)
        big.fill:SetVertexColor(0.27, 0.19, 0.24, 1)
        wing.bun:SetTexture(ns.MEDIA .. "icon"); wing.bun:SetVertexColor(1, 1, 1, 1)
        wing.bun:SetSize(math.floor(D * 0.5), math.floor(D * 0.5))
        wing.bun:ClearAllPoints(); wing.bun:SetPoint("CENTER", big, "CENTER", 0, 4)
        for _, o in ipairs({ wing.prev, wing.next }) do
            o.edge:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.45)
            o.fill:SetVertexColor(0.07, 0.05, 0.047, 1)
            if o.n then o.n:SetTextColor(0.79, 0.71, 0.68) end
        end
        b:ClearAllPoints(); b:SetSize(22, 22); b:SetPoint("CENTER", big, "BOTTOMRIGHT", -10, 12)
        b.bt:SetTexture(ns.MEDIA .. "circle"); b.bt:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1); b.edge:Hide()
        b.t:SetTextColor(0.16, 0.1, 0.11); pcall(b.t.SetFont, b.t, ns.NUM or ns.FONT, 12, "")
        if b.lv then b.lv:Hide() end
        b.t:ClearAllPoints(); b.t:SetPoint("CENTER", 0, 0)
    end
end
ns.ABarSkin = function() if wing and wing.geo and not InCombatLockdown() then ns.ABarRelayout() end end

local function LayoutWing()
    if not wing then BuildWing() end
    local S = math.floor(SIZE * 1.2 + 0.5)   -- 날개: 왼쪽 전투 칸은 조금 크게
    -- 왼쪽 5×2 (전투 · 페이지로 바뀜 · 메인 바 1~10) · 오른쪽 7×3 (고정 · 작은 칸 · 왼쪽과 같은 크기 상자)
    local LC, RC, RR, RG = 5, 7, 3, 3
    local RS = math.floor((2 * S + WG - (RR - 1) * RG) / RR)   -- 오른쪽 칸: 3줄 높이 = 왼쪽 2줄 높이
    local PWL = LC * S + (LC - 1) * WG + 2 * WPAD
    local PWR = PWL                                            -- 좌우 같은 폭 (대칭)
    local PH = 2 * S + WG + 2 * WPAD + 4
    -- 가운데: 큰 원 + 양옆 작은 원(이전 · 다음 페이지)이 겹치지 않게
    local D, d = math.floor(S * 2.05 + 0.5), math.floor(S * 0.78 + 0.5)
    local CW = D + 2 * d + 4 * 6
    -- 각진 전술형은 양옆 작은 원이 없으니 칸 묶음을 원 눈금 바로 옆까지 당겨요
    if DB().wskin == "tac" then CW = math.floor(D * 1.5 + 12 + 0.5) end
    local base = 14   -- 경험치 바 자리
    wing.L:ClearAllPoints(); wing.L:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, base); wing.L:SetSize(PWL, PH)
    wing.R:ClearAllPoints(); wing.R:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", PWL + CW, base); wing.R:SetSize(PWR, PH)
    local function Grid(btns, x0, cols)
        for i, b in ipairs(btns) do
            if i <= cols * 2 then
                local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
                if b.leelStrip then b.leelStrip() end
                b:ClearAllPoints(); b:SetSize(S, S)
                b:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", x0 + WPAD + c * (S + WG), base + WPAD + (1 - r) * (S + WG))
                b:SetAlpha(1); pcall(b.EnableMouse, b, true)
            else
                WGhost(b)
            end
        end
    end
    Grid(ROWS[1].btns, 0, LC)
    -- 오른쪽 7×3: 왼쪽 아래 바 12칸 + 오른쪽 아래 바 앞 9칸 (상자 가운데 맞춤)
    local right = {}
    for _, b in ipairs(ROWS[2].btns) do right[#right + 1] = b end
    for i, b in ipairs(ROWS[3].btns) do if i <= RC * RR - #ROWS[2].btns then right[#right + 1] = b else WGhost(b) end end
    local rw = RC * RS + (RC - 1) * RG
    local rh = RR * RS + (RR - 1) * RG
    local rx = PWL + CW + math.floor((PWR - rw) / 2)
    local ry = base + WPAD + math.floor(((2 * S + WG) - rh) / 2)
    for i, b in ipairs(right) do
        local c, r = (i - 1) % RC, math.floor((i - 1) / RC)
        b:ClearAllPoints(); b:SetSize(RS, RS)
        b:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", rx + c * (RS + RG), ry + (RR - 1 - r) * (RS + RG))
        b:SetAlpha(1); pcall(b.EnableMouse, b, true)
    end
    -- 체력 · 마나 줄
    local by = base + PH + 6
    local goldSkin = DB().wskin ~= "pink"
    local laSkin = DB().wskin == "la"
    local tacSkin = DB().wskin == "tac"
    local u = S / 54
    local BH = laSkin and math.max(10, math.floor(13 * u + 0.5)) or (goldSkin and math.max(14, math.floor(S * 0.4 + 0.5)) or 10)
    local midY0 = WPAD + (2 * S + WG) / 2
    if tacSkin then
        BH = math.max(6, math.floor((DB().tacBH or 14) * S / 48 + 0.5))   -- 허브: 줄 두께 (기본 14 · 칸 크기 따라)
        by = base + PH + 4
        wing.hp:ClearAllPoints(); wing.hp:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", WPAD, by); wing.hp:SetSize(PWL - 2 * WPAD, BH)
        wing.mp:ClearAllPoints(); wing.mp:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", PWL + CW + WPAD, by); wing.mp:SetSize(PWR - 2 * WPAD, BH)
    elseif laSkin then
        -- 로아풍: 칼날 줄은 칸 가운데보다 89u 위 · 안쪽 끝은 가운데 방패 어깨 밑으로
        by = math.floor(base + midY0 + 89 * u - BH / 2 + 0.5)
        local cx = PWL + CW / 2
        local l = math.max(math.floor(cx - 396 * u), math.floor(44 * u))
        local w = math.floor(cx - 68 * u - l)
        wing.hp:ClearAllPoints(); wing.hp:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", l, by); wing.hp:SetSize(w, BH)
        wing.mp:ClearAllPoints(); wing.mp:SetPoint("BOTTOMRIGHT", holder, "BOTTOMLEFT", 2 * cx - l, by); wing.mp:SetSize(w, BH)
    elseif goldSkin then
        -- 금선: 굵은 줄, 안쪽 끝은 문장 원 어깨까지 (바깥 끝은 마름모 마개 자리)
        local cx = PWL + CW / 2
        local x0 = WPAD + math.floor(BH * 0.6)
        local w = math.floor(cx - D * 0.42 - x0)
        wing.hp:ClearAllPoints(); wing.hp:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", x0, by); wing.hp:SetSize(w, BH)
        wing.mp:ClearAllPoints(); wing.mp:SetPoint("BOTTOMRIGHT", holder, "BOTTOMLEFT", PWL + CW + PWR - x0, by); wing.mp:SetSize(w, BH)
    else
        wing.hp:ClearAllPoints(); wing.hp:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", WPAD, by); wing.hp:SetSize(PWL - 2 * WPAD, 10)
        wing.mp:ClearAllPoints(); wing.mp:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", PWL + CW + WPAD, by); wing.mp:SetSize(PWR - 2 * WPAD, 10)
    end
    -- 가운데 원
    wing.core:ClearAllPoints(); wing.core:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", PWL, base); wing.core:SetSize(CW, PH + 30)
    -- 큰 원 가운데 = 칸들의 가운데 높이
    local midY = WPAD + (2 * S + WG) / 2
    wing.big:ClearAllPoints(); wing.big:SetSize(D, D); wing.big:SetPoint("CENTER", wing.core, "BOTTOM", 0, midY)
    wing.prev:ClearAllPoints(); wing.prev:SetSize(d, d); wing.prev:SetPoint("RIGHT", wing.big, "LEFT", -10, -D * 0.22)
    wing.next:ClearAllPoints(); wing.next:SetSize(d, d); wing.next:SetPoint("LEFT", wing.big, "RIGHT", 10, -D * 0.22)
    for _, o in ipairs({ wing.prev, wing.next }) do if o.n then pcall(o.n.SetFont, o.n, ns.NUM or ns.FONT, math.max(10, math.floor(d * 0.45)), "") end end
    wing.lab:Hide()   -- 페이지 숫자는 원의 분홍 배지로 (아래 경험치 줄과 겹치지 않게)
    if wing.pips then
        local R0 = D / 2 + 7
        for i, t in ipairs(wing.pips) do
            local a = math.pi / 2 - (i - 1) / #wing.pips * 2 * math.pi
            t:ClearAllPoints(); t:SetPoint("CENTER", wing.big, "CENTER", math.cos(a) * R0, math.sin(a) * R0)
            t:SetSize(math.max(4, math.floor(D * 0.07)), math.max(4, math.floor(D * 0.07)))
        end
    end
    wing.zk:ClearAllPoints(); wing.zk:SetPoint("BOTTOM", wing.prev, "TOP", 0, 4)
    wing.xk:ClearAllPoints(); wing.xk:SetPoint("BOTTOM", wing.next, "TOP", 0, 4)
    wing.zk:SetShown(DB().pgKeys == "zx"); wing.xk:SetShown(DB().pgKeys == "zx")
    wing.bun:SetSize(math.floor(D * 0.5), math.floor(D * 0.5))
    wing.geo = { BH = BH, D = D, u = u, asz = math.floor(S * 0.44 + 0.5) }
    WSkin()
    local W = PWL + CW + PWR
    -- 변신 · 펫 바: 왼쪽 판 위
    local stance = Buttons("StanceButton", 10)
    if #stance == 0 then stance = Buttons("ShapeshiftButton", 10) end
    local pet = Buttons("PetActionButton", 10)
    local top = by + BH + 3 + 10
    if tacSkin then top = by + BH + 20 + math.floor(S * 0.44 + 0.5) + 10 end
    if (GetNumShapeshiftForms and GetNumShapeshiftForms() or 0) > 0 and PlaceSmall(stance, top) then
        top = top + PET + GAP + 8
    end
    if tacSkin then WPetArc()   -- 모던: 펫 기술은 펫 원 부채꼴로
    elseif PetHasActionBar and PetHasActionBar() then PlaceSmall(pet, top) end
    holder:SetSize(W, top + PET)
    xp:SetWidth(W); xp:SetHeight(4)
    if wing.fade then
        wing.fade:Hide()   -- 배경은 투명하게 (칸만 떠 있게)
        wing.fade:ClearAllPoints()
        wing.fade:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", -60, -14)
        wing.fade:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", 60, by + 40)
    end
    local ex = G("ExtraActionButton1")
    if ex then ex:ClearAllPoints(); ex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMLEFT", -18, 14) end
    WUpdateBars(); WUpdatePage()
end

local function Layout()
    if not holder or not DB().on then return end
    if InCombatLockdown() then pending = true return end
    local sc = (DB().scale or 100) / 100
    SIZE = math.floor(BASE_SIZE * sc + 0.5)
    PET = math.floor(BASE_PET * sc + 0.5)
    placing = true
    if DB().style == "wing" then LayoutWing(); placing = false; return end
    local y = 14  -- 경험치 바 자리
    for _, row in ipairs(ROWS) do
        if #row.btns > 0 and (not row.bar or row.bar:IsShown()) then
            PlaceRow(row.btns, y, SIZE)
            y = y + SIZE + GAP + 4
        end
    end
    -- 위에 변신 바 / 펫 바
    local stance = Buttons("StanceButton", 10)
    if #stance == 0 then stance = Buttons("ShapeshiftButton", 10) end
    local pet = Buttons("PetActionButton", 10)
    local top = y + 4
    if (GetNumShapeshiftForms and GetNumShapeshiftForms() or 0) > 0 and PlaceSmall(stance, top) then
        top = top + PET + GAP + 8
    end
    local hasPet = PetHasActionBar and PetHasActionBar()
    if hasPet then PlaceSmall(pet, top) end
    holder:SetSize(12 * SIZE + 11 * GAP, top + PET)
    xp:SetWidth(12 * SIZE + 11 * GAP)

    -- 특수 행동 (있으면 왼쪽에 크게)
    local ex = G("ExtraActionButton1")
    if ex then
        ex:ClearAllPoints()
        ex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMLEFT", -18, 14)
    end
    placing = false
end
ns.ABarLayout = Layout

ns.ABarRelayout = function() Layout() end

local function Apply()
    local p = DB().point or { "CENTER", "BOTTOM", 0, 104 }
    holder:ClearAllPoints()
    holder:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

----------------------------------------------------------------------
-- 경험치 바 (분홍 + 휴식 보라 빗금)
----------------------------------------------------------------------
local function BuildXP()
    xp = CreateFrame("StatusBar", nil, holder)
    xp:SetHeight(8)
    xp:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    xp:SetStatusBarTexture(ns.WHITE or "Interface\\Buttons\\WHITE8x8")
    xp:SetStatusBarColor(0.86, 0.52, 0.62, 1)   -- 장미
    local m = xp:CreateMaskTexture()
    m:SetTexture(ns.MEDIA .. "pill16", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints()
    xp:GetStatusBarTexture():AddMaskTexture(m)
    local bg = xp:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(ns.MEDIA .. "pill16"); bg:SetVertexColor(0.165, 0.114, 0.106, 1); bg:SetAllPoints()
    local edge = xp:CreateTexture(nil, "BACKGROUND", nil, -1)
    edge:SetTexture(ns.MEDIA .. "pill16"); edge:SetVertexColor(0, 0, 0, 0.55)
    edge:SetPoint("TOPLEFT", -2, 2); edge:SetPoint("BOTTOMRIGHT", 2, -2)
    local rest = xp:CreateTexture(nil, "ARTWORK")
    rest:SetTexture(ns.MEDIA .. "stripes", "REPEAT", "REPEAT"); rest:SetHorizTile(true)
    rest:SetVertexColor(0.73, 0.55, 1, 0.75)
    rest:AddMaskTexture(m)
    xp.rest = rest
    xp:EnableMouse(true)
    xp:SetScript("OnEnter", function(self)
        local cur, max = UnitXP("player"), UnitXPMax("player")
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("경험치", C.acc[1], C.acc[2], C.acc[3])
        GameTooltip:AddLine(string.format("%s / %s  (%.1f%%)", BreakUpLargeNumbers(cur), BreakUpLargeNumbers(max), max > 0 and cur / max * 100 or 0), 1, 1, 1)
        local ex = GetXPExhaustion and GetXPExhaustion()
        if ex and ex > 0 then GameTooltip:AddLine("휴식 +" .. BreakUpLargeNumbers(ex), 0.73, 0.55, 1) end
        GameTooltip:Show()
    end)
    xp:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function UpdateXP()
    if not xp then return end
    local maxLv = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
    if UnitLevel("player") >= maxLv then xp:Hide() return end
    xp:Show()
    local cur, max = UnitXP("player"), UnitXPMax("player")
    if not max or max <= 0 then max = 1 end
    xp:SetMinMaxValues(0, max); xp:SetValue(cur)
    local ex = (GetXPExhaustion and GetXPExhaustion()) or 0
    local w = xp:GetWidth()
    if ex > 0 and w > 0 then
        local a = cur / max
        local b = math.min(1, (cur + ex) / max)
        xp.rest:ClearAllPoints()
        xp.rest:SetPoint("TOPLEFT", xp, "TOPLEFT", w * a, 0)
        xp.rest:SetPoint("BOTTOMLEFT", xp, "BOTTOMLEFT", w * a, 0)
        xp.rest:SetWidth(math.max(1, w * (b - a)))
        xp.rest:Show()
    else
        xp.rest:Hide()
    end
end

----------------------------------------------------------------------
-- 토끼 메뉴 (누르면 두 겹 부채로 펼쳐짐, 전투 중에도 동작)
----------------------------------------------------------------------
local ITEM = 40
local items = {}

local function CopyIcon(dst, src)
    local nt = src and src.GetNormalTexture and src:GetNormalTexture()
    if not nt then return end
    local atlas = nt.GetAtlas and nt:GetAtlas()
    if atlas then dst:SetAtlas(atlas) return end
    dst:SetTexture(nt:GetTexture())
    dst:SetTexCoord(nt:GetTexCoord())
end

-- 토끼 옆 작은 카드: 2줄 × 6칸, 아이콘 아래 이름 (기본은 오른쪽, 화면 오른쪽 끝이면 왼쪽)
local CELLW, CELLH, COLS, PAD = 74, 62, 6, 10
local function FanPlace()
    if not fan or InCombatLockdown() then return end
    local n = #items
    local cols = math.min(COLS, math.max(1, n))
    local rows = math.max(1, math.ceil(n / cols))
    local w = cols * CELLW + (cols - 1) * 4 + PAD * 2
    fan:SetSize(w, rows * CELLH + (rows - 1) * 6 + PAD * 2)
    -- 오른쪽에 카드가 들어갈 자리가 있으면 오른쪽, 없을 때만 왼쪽
    local rx = launcher:GetRight() or 0
    local right = rx * launcher:GetEffectiveScale() / UIParent:GetEffectiveScale() + 12 + w + 8 <= UIParent:GetWidth()
    fan:ClearAllPoints()
    if right then fan:SetPoint("BOTTOMLEFT", launcher, "BOTTOMRIGHT", 12, -6)
    else fan:SetPoint("BOTTOMRIGHT", launcher, "BOTTOMLEFT", -12, -6) end
    for i, it in ipairs(items) do
        local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
        it:ClearAllPoints()
        it:SetPoint("TOPLEFT", fan, "TOPLEFT", PAD + c * (CELLW + 4), -PAD - r * (CELLH + 6))
    end
end

local function BuildLauncher()
    launchHolder = CreateFrame("Frame", "LeelUI_MenuHolder", UIParent)
    launchHolder:SetSize(52, 52)
    launchHolder:SetMovable(true); launchHolder:SetClampedToScreen(true)

    launcher = CreateFrame("Button", "LeelUI_MenuBunny", launchHolder, "SecureHandlerClickTemplate")
    launcher:SetAllPoints()
    launcher:RegisterForClicks("AnyUp")
    local glow = launcher:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(ns.MEDIA .. "circle"); glow:SetPoint("TOPLEFT", -5, 5); glow:SetPoint("BOTTOMRIGHT", 5, -5)
    glow:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.35)
    local ic = launcher:CreateTexture(nil, "ARTWORK")
    ic:SetTexture(ns.MEDIA .. "icon"); ic:SetAllPoints()
    local hl = launcher:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(ns.MEDIA .. "circle"); hl:SetAllPoints(); hl:SetVertexColor(1, 1, 1, 0.18); hl:SetBlendMode("ADD")

    fan = CreateFrame("Frame", "LeelUI_MenuFan", launcher, "SecureHandlerShowHideTemplate")
    fan:SetSize(100, 100)
    fan:Hide()
    fan.fill, fan.edge = ns.RoundPlate(fan, 16, { 0.125, 0.094, 0.086, 0.95 }, { C.acc[1], C.acc[2], C.acc[3], 0.6 })
    fan:SetFrameStrata("DIALOG")
    launcher:SetFrameRef("fan", fan)
    launcher:SetAttribute("_onclick", [[
        if IsShiftKeyDown() then return end   -- Shift는 옮기기용
        local f = self:GetFrameRef("fan")
        if f:IsShown() then f:Hide() else f:Show() end
    ]])
    launcher:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("르엘 메뉴", C.acc[1], C.acc[2], C.acc[3])
        GameTooltip:AddLine("누르면 메뉴가 펼쳐져요", 1, 1, 1)
        GameTooltip:AddLine("자리 · 크기는 이동 모드에서", 0.85, 0.78, 0.76)
        GameTooltip:Show()
    end)
    launcher:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- 옮기기는 이동 모드에서만 (평소엔 고정)
    launcher:RegisterForDrag("LeftButton")
    launcher:SetScript("OnDragStart", function()
        if ns.moving and not InCombatLockdown() then
            GameTooltip:Hide()
            launchHolder:StartMoving()
            launchHolder.leelDragging = true
        end
    end)
    launcher:SetScript("OnDragStop", function()
        if not launchHolder.leelDragging then return end
        launchHolder.leelDragging = false
        launchHolder:StopMovingOrSizing()
        local x, y = launchHolder:GetCenter()
        if ns.db.grid then x = math.floor(x / 8 + 0.5) * 8; y = math.floor(y / 8 + 0.5) * 8 end
        DB().lpoint = { "CENTER", "BOTTOMLEFT", math.floor(x + 0.5), math.floor(y + 0.5) }
        if ns.ABarApplyLauncher then ns.ABarApplyLauncher() end
    end)

    local function AddItem(target, label, iconFn)
        local it = CreateFrame("Button", nil, fan, "SecureActionButtonTemplate")
        it:SetSize(CELLW, CELLH)
        it:RegisterForClicks("AnyUp", "AnyDown")  -- 게임 설정(키 누를 때 실행)에 맞는 쪽 하나만 동작
        it:SetAttribute("type", "click")
        it:SetAttribute("clickbutton", target)
        -- 마우스를 올리면 칸 전체가 연분홍으로
        local hov = ns.RoundRect(it, 12, C.acc, "BACKGROUND", 0, 0); hov:SetColor(C.acc, 0.16)
        local function HovShow(on) for _, x in ipairs(hov.tex) do x:SetShown(on) end end
        HovShow(false)
        local ic = CreateFrame("Frame", nil, it)
        ic:SetSize(36, 36); ic:SetPoint("TOP", it, "TOP", 0, -5)
        local e = ic:CreateTexture(nil, "BACKGROUND")
        e:SetTexture(ns.MEDIA .. "circle"); e:SetPoint("TOPLEFT", -2, 2); e:SetPoint("BOTTOMRIGHT", 2, -2)
        e:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
        local d = ic:CreateTexture(nil, "BORDER")
        d:SetTexture(ns.MEDIA .. "circle"); d:SetAllPoints(); d:SetVertexColor(0.125, 0.094, 0.086, 1)
        local t = ic:CreateTexture(nil, "ARTWORK")
        t:SetPoint("TOPLEFT", 4, -4); t:SetPoint("BOTTOMRIGHT", -4, 4)
        local m = ic:CreateMaskTexture()
        m:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); m:SetAllPoints(t)
        t:AddMaskTexture(m)
        iconFn(t)
        local ring2 = ic:CreateTexture(nil, "BACKGROUND", nil, -1)
        ring2:SetTexture(ns.MEDIA .. "circle"); ring2:SetPoint("TOPLEFT", -4.5, 4.5); ring2:SetPoint("BOTTOMRIGHT", 4.5, -4.5)
        ring2:SetVertexColor(1, 1, 1, 1); ring2:Hide()
        local tf = ns.Font(it, 10.5, { 0.85, 0.78, 0.76 })
        tf:SetPoint("TOP", ic, "BOTTOM", 0, -4); tf:SetWidth(CELLW - 2); tf:SetWordWrap(false)
        tf:SetText(label)
        local tip = { Show = function() HovShow(true); tf:SetTextColor(1, 0.84, 0.88) end,
                      Hide = function() HovShow(false); tf:SetTextColor(0.85, 0.78, 0.76) end }
        it:SetScript("OnEnter", function() tip:Show(); ring2:Show() end)
        it:SetScript("OnLeave", function() tip:Hide(); ring2:Hide() end)
        -- 고르면 메뉴 접기 (전투 중엔 토끼를 한 번 더 누르면 접혀요)
        it:HookScript("PostClick", function()
            if not InCombatLockdown() then C_Timer.After(0, function() if not InCombatLockdown() then fan:Hide() end end) end
        end)
        it.tip, it.ring2 = tip, ring2
        items[#items + 1] = it
        return it
    end

    -- 게임 메뉴 버튼은 '대신 누르기'로는 안 열려요 → 진짜 버튼을 투명하게 그 칸 위에 올려서 직접 누르게
    local function Overlay(it, real)
        local function Steal()
            if InCombatLockdown() then return end
            real.leelStealing = true
            real:SetParent(it)
            real:ClearAllPoints(); real:SetAllPoints(it)
            real:SetFrameLevel(it:GetFrameLevel() + 5)
            pcall(real.EnableMouse, real, true)
            real.leelStealing = false
        end
        it:SetAttribute("type", nil)
        Steal()
        hooksecurefunc(real, "SetParent", function(_, p) if not real.leelStealing and p ~= it then C_Timer.After(0, Steal) end end)
        real:HookScript("OnEnter", function() it.tip:Show(); it.ring2:Show() end)
        real:HookScript("OnLeave", function() it.tip:Hide(); it.ring2:Hide() end)
        real:HookScript("OnMouseUp", function()
            C_Timer.After(0.05, function() if not InCombatLockdown() then fan:Hide() end end)
        end)
    end

    for _, m in ipairs(menuList) do
        local label = m.btn.tooltipText or MICRO_KO[m.name] or m.name  -- 게임 속 이름 그대로
        -- 단축키 "(K)" 같은 꼬리는 빼기
        label = label:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s*%b()", "")
        local it = AddItem(m.btn, label, function(t)
            if m.name == "CharacterMicroButton" then
                SetPortraitTexture(t, "player"); t:SetTexCoord(0, 1, 0, 1)
            elseif MICRO_ICON[m.name] and t:SetTexture("Interface\\Icons\\" .. MICRO_ICON[m.name]) then
                t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            else
                CopyIcon(t, m.btn)
            end
        end)
        if m.name == "MainMenuMicroButton" then Overlay(it, m.btn) end
    end
    local bag = G("MainMenuBarBackpackButton")
    if bag then
        AddItem(bag, "가방", function(t) t:SetTexture(ns.MEDIA .. "bag_bunny"); t:SetTexCoord(0, 1, 0, 1) end)
    end
    FanPlace()
end

local function ApplyLauncher()
    ns.ABarApplyLauncher = ApplyLauncher
    local p = DB().lpoint
    launchHolder:ClearAllPoints()
    if p then
        launchHolder:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        launchHolder:SetPoint("BOTTOMLEFT", holder, "BOTTOMRIGHT", 40, 6)
    end
    FanPlace()
end

----------------------------------------------------------------------
-- 이동 모드
----------------------------------------------------------------------
local function Mover(frame, label, key, after)
    local m = CreateFrame("Frame", nil, frame)
    m:SetPoint("TOPLEFT", -4, 4); m:SetPoint("BOTTOMRIGHT", 4, -4)
    m:SetFrameStrata("DIALOG")
    m:EnableMouse(true); m:RegisterForDrag("LeftButton")
    local tint = m:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints(); tint:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.12)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = m:CreateTexture(nil, "BORDER")
        e:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 1)
        if side == "TOP" or side == "BOTTOM" then
            e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(2)
        else
            e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(2)
        end
    end
    local lab = ns.Font(m, 12, C.accHi)
    lab:SetPoint("BOTTOM", m, "TOP", 0, 4); lab:SetText(label)
    if ns.MoveSizeHook then ns.MoveSizeHook(m, label .. " 크기", label) end
    ns.ABarMovers = ns.ABarMovers or {}; ns.ABarMovers[label] = m
    m:SetScript("OnDragStart", function() if not InCombatLockdown() then frame:StartMoving() end end)
    m:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local x, y = frame:GetCenter()
        if ns.db.grid then x = math.floor(x / 8 + 0.5) * 8; y = math.floor(y / 8 + 0.5) * 8 end
        DB()[key] = { "CENTER", "BOTTOMLEFT", math.floor(x + 0.5), math.floor(y + 0.5) }
        after()
    end)
    m:Hide()
    if ns.SetMoveMode then
        hooksecurefunc(ns, "SetMoveMode", function() m:SetShown(ns.moving and not InCombatLockdown() and true or false) end)
    end
end

-- 허브 크기 조절 (전투 중이면 끝나고 적용)
function ns:SetABarScale(v)
    DB().scale = v
    if holder then Layout(); if xp then UpdateXP() end; FanPlace() end
end
function ns:SetABarMenuScale(v)
    DB().mscale = v
    if launchHolder and not InCombatLockdown() then launchHolder:SetScale(v / 100); FanPlace() end
end

function ns:ResetABarPosition()
    local d = DB()
    d.point, d.lpoint = nil, nil
    if holder and not InCombatLockdown() then Apply(); ApplyLauncher() end
end


----------------------------------------------------------------------
-- 메뉴 줄 (모바일식): 화면 오른쪽 위 네모 단추 한 줄 + 아래 단축키 글자 · 맨 끝 = 접기
--  * 단추는 블리자드 메뉴 버튼을 대신 눌러줘요(보안 단추) · 게임 메뉴는 Esc
----------------------------------------------------------------------
local ROW_ICON = {
    CharacterMicroButton = "hb_ui", ProfessionMicroButton = "hb_guide", SpellbookMicroButton = "hb_bolt",
    PlayerSpellsMicroButton = "hb_bolt", TalentMicroButton = "hb_spot", AchievementMicroButton = "ic_star",
    QuestLogMicroButton = "hb_quest", GuildMicroButton = "ci_guild", SocialsMicroButton = "ci_social",
    LFDMicroButton = "hb_dungeon", LFGMicroButton = "hb_dungeon", CollectionsMicroButton = "hb_gift",
    EJMicroButton = "hb_guide", WorldMapMicroButton = "hb_map", PVPMicroButton = "ic_shield", StoreMicroButton = "hb_shop",
}
local ROW_BIND = {
    CharacterMicroButton = "TOGGLECHARACTER0", ProfessionMicroButton = "TOGGLEPROFESSIONBOOK", SpellbookMicroButton = "TOGGLESPELLBOOK",
    PlayerSpellsMicroButton = "TOGGLESPELLBOOK", TalentMicroButton = "TOGGLETALENTS", AchievementMicroButton = "TOGGLEACHIEVEMENT",
    QuestLogMicroButton = "TOGGLEQUESTLOG", GuildMicroButton = "TOGGLEGUILDTAB", SocialsMicroButton = "TOGGLESOCIAL",
    LFDMicroButton = "TOGGLEGROUPFINDER", LFGMicroButton = "TOGGLELFGPARENT", CollectionsMicroButton = "TOGGLECOLLECTIONS",
    EJMicroButton = "TOGGLEENCOUNTERJOURNAL", WorldMapMicroButton = "TOGGLEWORLDMAP", PVPMicroButton = "TOGGLECHARACTER4",
}
local menuRow
local function RowKey(bind)
    local k = bind and GetBindingKey and GetBindingKey(bind)
    if not k then return "" end
    k = k:gsub("SHIFT%-", "S"):gsub("CTRL%-", "C"):gsub("ALT%-", "A"):gsub("ESCAPE", "Esc")
    return k
end
local function PlaceRow()
    if not menuRow then return end
    menuRow:SetScale(math.max(0.5, math.min(1.6, (DB().mrScale or 100) / 100)))
    local p = DB().mrpoint
    menuRow:ClearAllPoints()
    if p then menuRow:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else menuRow:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -250, -14) end
end
local ROW_DEFPIN = { CharacterMicroButton = true, SpellbookMicroButton = true, PlayerSpellsMicroButton = true,
                     TalentMicroButton = true, QuestLogMicroButton = true, WorldMapMicroButton = true, _bag = true, _hub = true,
                     LFDMicroButton = true, LFGMicroButton = true }
local function RowPinned(id)
    local d = DB()
    if d.mrPins and (d.mrPinsV or 0) < 2 then d.mrPins.LFDMicroButton = true; d.mrPins.LFGMicroButton = true end
    d.mrPinsV = 2
    local pins = d.mrPins
    if pins == nil then return ROW_DEFPIN[id] and true or false end
    return pins[id] and true or false
end
local function RowSetPin(id, v)
    local d = DB()
    if not d.mrPins then d.mrPins = {}; for k in pairs(ROW_DEFPIN) do d.mrPins[k] = true end end
    d.mrPins[id] = v and true or nil
end
local function BuildMenuRow()
    if menuRow then return end
    local SZ, GP = 38, 6
    menuRow = CreateFrame("Frame", "LeelUI_MenuRow", UIParent)
    menuRow:SetMovable(true); menuRow:SetClampedToScreen(true); menuRow:SetFrameStrata("MEDIUM")
    -- 더보기 판 (덜 쓰는 메뉴): 보안 손잡이로 전투 중에도 열고 닫기
    local pop = CreateFrame("Frame", "LeelUI_MenuPop", menuRow, "SecureHandlerShowHideTemplate")
    pop:SetFrameStrata("DIALOG"); pop:Hide()
    local pbg = pop:CreateTexture(nil, "BACKGROUND"); pbg:SetAllPoints(); pbg:SetColorTexture(0.03, 0.035, 0.05, 0.86)
    for _, sd in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = pop:CreateTexture(nil, "BORDER"); e:SetColorTexture(1, 1, 1, 0.12)
        if sd == "TOP" or sd == "BOTTOM" then e:SetPoint(sd .. "LEFT"); e:SetPoint(sd .. "RIGHT"); e:SetHeight(1)
        else e:SetPoint("TOP" .. sd); e:SetPoint("BOTTOM" .. sd); e:SetWidth(1) end
    end
    pop.tip = ns.Font(pop, 9.5, { 0.7, 0.66, 0.64 }); pop.tip:SetPoint("BOTTOMLEFT", 8, 6); pop.tip:SetText("오른쪽 클릭 = 위 줄에 꺼내 두기 · 줄에서 오른쪽 클릭 = 여기로")
    menuRow.pop = pop
    local items = {}
    local function Line(f, a)
        for _, sd in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
            local e = f:CreateTexture(nil, "BORDER"); e:SetColorTexture(1, 1, 1, a)
            if sd == "TOP" or sd == "BOTTOM" then e:SetPoint(sd .. "LEFT"); e:SetPoint(sd .. "RIGHT"); e:SetHeight(1)
            else e:SetPoint("TOP" .. sd); e:SetPoint("BOTTOM" .. sd); e:SetWidth(1) end
        end
    end
    -- 단추 하나 (줄용 = 작은 네모 · 판용 = 이름 붙은 칸)
    local function Make(it, inPop)
        local b
        if it.target then
            b = CreateFrame("Button", nil, inPop and pop or menuRow, "SecureActionButtonTemplate")
            b:RegisterForClicks("AnyUp", "AnyDown")
            b:SetAttribute("type", "click"); b:SetAttribute("clickbutton", it.target)
            b:SetAttribute("type2", "leelnone")   -- 오른쪽 클릭은 꺼내기 · 넣기만
        else
            b = CreateFrame("Button", nil, inPop and pop or menuRow)
            b:RegisterForClicks("AnyUp")
            b:SetScript("OnClick", function(_, btn) if btn == "LeftButton" and it.run then it.run() end end)
        end
        if inPop then b:SetSize(76, 58) else b:SetSize(SZ, SZ) end
        local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.03, 0.035, 0.05, 0)
        local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetTexture(ns.MEDIA .. it.icon)
        if inPop then ic:SetSize(26, 26); ic:SetPoint("TOP", 0, -7) else ic:SetSize(SZ * 0.58, SZ * 0.58); ic:SetPoint("CENTER", 0, 2) end
        ic:SetAlpha(0.95)
        if not inPop then   -- 바탕이 없으니 아이콘 뒤에 옅은 그림자
            local sh = b:CreateTexture(nil, "BORDER"); sh:SetTexture(ns.MEDIA .. it.icon); sh:SetVertexColor(0, 0, 0, 0.7)
            sh:SetSize(SZ * 0.58, SZ * 0.58); sh:SetPoint("CENTER", ic, "CENTER", 1, -1)
        end
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.1)
        if inPop then
            local nm = ns.Font(b, 10.5, { 1, 1, 1 }); nm:SetPoint("TOP", ic, "BOTTOM", 0, -3); nm:SetText(it.label); nm:SetWidth(72); nm:SetWordWrap(false)
            if it.key ~= "" then local kf = ns.Font(b, 8.5, { 0.75, 0.7, 0.68 }); kf:SetPoint("TOP", nm, "BOTTOM", 0, -1); kf:SetText(it.key) end
        elseif it.key ~= "" then
            local kb = b:CreateTexture(nil, "OVERLAY"); kb:SetColorTexture(0, 0, 0, 0.35)
            kb:SetSize(22, 12); kb:SetPoint("CENTER", b, "BOTTOM", 0, 0)
            local kf = b:CreateFontString(nil, "OVERLAY"); kf:SetFont(ns.NUM or ns.FONT, 8.5, ""); kf:SetPoint("CENTER", kb, "CENTER", 0, 0)
            kf:SetText(it.key); kf:SetTextColor(0.91, 0.89, 0.87)
            kb:SetWidth(math.max(14, kf:GetStringWidth() + 8))
        end
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(it.label, 1, 1, 1)
            if it.key ~= "" then GameTooltip:AddLine("단축키: " .. it.key, 0.85, 0.78, 0.76) end
            GameTooltip:AddLine(inPop and "오른쪽 클릭: 위 줄에 늘 보이게" or "오른쪽 클릭: 더보기 판으로 넣기", 0.7, 0.66, 0.64)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:HookScript("OnMouseUp", function(_, btn)
            if btn ~= "RightButton" then
                if inPop then C_Timer.After(0.05, function() if not InCombatLockdown() then pop:Hide() end end) end
                return
            end
            if InCombatLockdown() then P("전투가 끝나면 바꿀 수 있어요."); return end
            RowSetPin(it.id, inPop); menuRow.Lay()
        end)
        return b
    end
    local function Item(id, target, icon, key, label, run)
        local it = { id = id, target = target, icon = icon, key = key or "", label = label, run = run }
        it.row = Make(it, false); it.pop = Make(it, true)
        items[#items + 1] = it
    end
    for _, m in ipairs(menuList) do
        if m.name ~= "MainMenuMicroButton" and m.name ~= "HelpMicroButton" then
            local label = (m.btn.tooltipText or MICRO_KO[m.name] or m.name):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s*%b()", "")
            Item(m.name, m.btn, ROW_ICON[m.name] or "hb_apps", RowKey(ROW_BIND[m.name]), label)
        end
    end
    local bag = G("MainMenuBarBackpackButton")
    if bag then Item("_bag", bag, "hb_bag", RowKey("OPENALLBAGS"), "가방") end
    Item("_hub", nil, "icon", "", "르엘 허브", function() ns:ToggleHub() end)
    -- 더보기 단추 (판 열고 닫기)
    local more = CreateFrame("Button", nil, menuRow, "SecureHandlerClickTemplate")
    more:SetSize(SZ, SZ); more:RegisterForClicks("AnyUp")

    local mi = more:CreateTexture(nil, "ARTWORK"); mi:SetTexture(ns.MEDIA .. "hb_apps"); mi:SetSize(SZ * 0.55, SZ * 0.55); mi:SetPoint("CENTER")
    local mh = more:CreateTexture(nil, "HIGHLIGHT"); mh:SetAllPoints(); mh:SetColorTexture(1, 1, 1, 0.12)
    more:SetFrameRef("pop", pop)
    more:SetAttribute("_onclick", [[ local f = self:GetFrameRef("pop"); if f:IsShown() then f:Hide() else f:Show() end ]])
    more:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine("더보기", 1, 1, 1); GameTooltip:AddLine("덜 쓰는 메뉴", 0.85, 0.78, 0.76); GameTooltip:Show() end)
    more:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function menuRow.Lay()
        if InCombatLockdown() then return end
        local x, n = 0, 0
        for _, it in ipairs(items) do
            local pin = RowPinned(it.id)
            it.row:ClearAllPoints(); it.pop:ClearAllPoints()
            if pin then it.row:SetPoint("TOPLEFT", menuRow, "TOPLEFT", x, 0); it.row:Show(); it.pop:Hide(); x = x + SZ + GP
            else
                it.row:Hide()
                it.pop:SetPoint("TOPLEFT", pop, "TOPLEFT", 6 + (n % 4) * 78, -6 - math.floor(n / 4) * 60); it.pop:Show(); n = n + 1
            end
        end
        more:ClearAllPoints(); more:SetPoint("TOPLEFT", menuRow, "TOPLEFT", x, 0); more:SetShown(n > 0)
        menuRow:SetSize(x + (n > 0 and SZ or 0), SZ + 8)
        local rows = math.max(1, math.ceil(n / 4))
        pop:SetSize(4 * 78 + 10, rows * 60 + 30)
        pop:ClearAllPoints(); pop:SetPoint("TOPRIGHT", more, "BOTTOMRIGHT", 0, -8)
    end
    menuRow.Lay()
    PlaceRow()
    Mover(menuRow, "메뉴 줄", "mrpoint", PlaceRow)
end
function ns.ABarMenuScale(v)
    DB().mrScale = math.floor(tonumber(v) or 100)
    if menuRow and not InCombatLockdown() then PlaceRow() end
end
function ns.ABarMenuStyle()
    local row = DB().menuStyle ~= "bunny"
    if InCombatLockdown() then return end
    if row then BuildMenuRow() end
    if menuRow then menuRow:SetShown(row) end
    if launchHolder then launchHolder:SetShown(not row) end
end

----------------------------------------------------------------------
-- 시작
----------------------------------------------------------------------
local function Hooks()
    local function Again()
        if placing or not DB().on then return end
        if InCombatLockdown() then pending = true return end
        C_Timer.After(0, Layout)
    end
    for _, n in ipairs({ "MainMenuBar", "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight",
                         "StanceBar", "PetActionBar" }) do
        local f = G(n)
        if f then
            for _, fn in ipairs({ "UpdateGridLayout", "Layout", "UpdateShownButtons" }) do
                if f[fn] then pcall(hooksecurefunc, f, fn, Again) end
            end
            f:HookScript("OnShow", Again); f:HookScript("OnHide", Again)
        end
    end
    for _, fn in ipairs({ "UIParent_ManageFramePositions", "MultiActionBar_Update", "StanceBar_Update",
                          "PetActionBar_Update", "ActionBarController_UpdateAll" }) do
        if _G[fn] then pcall(hooksecurefunc, fn, Again) end
    end
    -- 메뉴 버튼이 다시 보이게 바뀌면 다시 투명하게
    for _, m in ipairs(menuList) do
        pcall(hooksecurefunc, m.btn, "SetAlpha", function(b, a)
            if a and a > 0 then b:SetAlpha(0) end
        end)
    end
end

local function Start()
    if ns.ABAR_LOCKED then return end
    local d = DB()
    if not d.on or holder then return end
    Collect()
    for _, row in ipairs(ROWS) do for _, b in ipairs(row.btns) do managed[b] = true; Skin(b) end end
    for _, b in ipairs(Buttons("StanceButton", 10)) do managed[b] = true; Skin(b, true) end
    for _, b in ipairs(Buttons("ShapeshiftButton", 10)) do managed[b] = true; Skin(b, true) end
    for _, b in ipairs(Buttons("PetActionButton", 10)) do managed[b] = true; Skin(b, true) end
    local ex = G("ExtraActionButton1")
    if ex then managed[ex] = true end

    holder = CreateFrame("Frame", "LeelUI_ActionBars", UIParent)
    holder:SetSize(12 * SIZE + 11 * GAP, 200)
    holder:SetMovable(true); holder:SetClampedToScreen(true)
    Apply()
    BuildXP()
    HideMenus()
    HideArt()
    BuildLauncher()
    launchHolder:SetScale((d.mscale or 100) / 100)
    ApplyLauncher()
    Mover(holder, "액션바", "point", function() Apply(); FanPlace() end)
    Mover(launchHolder, "토끼 메뉴", "lpoint", ApplyLauncher)
    ns.ABarMenuStyle()
    Hooks()
    Layout()
    UpdateXP()
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_XP_UPDATE",
                     "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "UPDATE_SHAPESHIFT_FORMS", "PET_BAR_UPDATE",
                     "UNIT_PET", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "UPDATE_BONUS_ACTIONBAR" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
    if not ns.db then return end
    if event == "PLAYER_LOGIN" then
        if DB().on then C_Timer.After(0.5, Start) end
        return
    end
    if not holder then return end
    if event == "PLAYER_XP_UPDATE" or event == "UPDATE_EXHAUSTION" or event == "PLAYER_LEVEL_UP" then
        UpdateXP()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then pending = false; Layout() end
        if wing and wing.keysPending then wing.keysPending = false; WKeys() end
        if launchHolder and math.abs(launchHolder:GetScale() - (DB().mscale or 100) / 100) > 0.001 then
            launchHolder:SetScale((DB().mscale or 100) / 100); FanPlace()
        end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function() HideArt(); Layout(); UpdateXP() end)
        return
    end
    C_Timer.After(0.05, Layout)
end)

----------------------------------------------------------------------
-- 점검: /르엘바
----------------------------------------------------------------------
SLASH_LEELABAR1 = "/르엘바"
SLASH_LEELABAR2 = "/leelbar"
SlashCmdList.LEELABAR = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if ns.ABAR_LOCKED then P("르엘 액션바는 준비 중이에요. 다음 업데이트에서 열려요.") return end
    if msg == "켜기" or msg == "on" then
        DB().on = true; P("켰어요. /reload 하면 적용돼요.")
        return
    elseif msg == "끄기" or msg == "off" then
        DB().on = false; P("껐어요. /reload 하면 원래 바로 돌아가요.")
        return
    elseif msg == "날개" or msg == "둥둥" then
        DB().style = (msg == "날개") and "wing" or "float"; P("모양: " .. msg .. ". /reload 하면 적용돼요.")
        return
    elseif msg == "키" then
        DB().pgKeys = (DB().pgKeys == "zx") and "off" or "zx"
        if ns.ABarKeys then ns.ABarKeys() end
        P("페이지 넘기기 Z · X: " .. (DB().pgKeys == "zx" and "켬" or "끔"))
        return
    elseif msg == "위치" then
        ns:ResetABarPosition(); P("액션바·토끼 메뉴 자리를 처음대로.")
        return
    end
    P("점검 (켜짐: " .. tostring(DB().on) .. ")")
    local function has(n)
        local f = G(n)
        local s = f and (f:IsShown() and "보임" or "숨김") or "없음"
        local par = f and f.GetParent and f:GetParent()
        return n .. "=" .. s .. (par and par.GetName and par:GetName() and (" <" .. par:GetName() .. ">") or "")
    end
    for _, n in ipairs({ "MainMenuBar", "MainActionBar", "MainMenuBarArtFrame", "MultiBarBottomLeft", "MultiBarBottomRight",
                         "StanceBar", "StanceBarFrame", "PetActionBar", "PetActionBarFrame", "MicroMenuContainer",
                         "MicroMenu", "BagsBar", "ExtraActionButton1", "MainMenuExpBar", "StatusTrackingBarManager",
                         "MainStatusTrackingBarContainer", "ActionButton1", "StanceButton1", "ShapeshiftButton1",
                         "PetActionButton1", "MainMenuBarBackpackButton", "KeyRingButton" }) do
        P(has(n))
    end
    local b = G("ActionButton1")
    if b then P(string.format("ActionButton1 크기 %.0f x %.0f", b:GetWidth(), b:GetHeight())) end
    for i, m in ipairs(menuList) do P("  메뉴 " .. i .. ": " .. m.name .. " (" .. tostring(m.btn.tooltipText) .. ")") end
    P("메뉴 버튼 " .. #menuList .. "개  MICRO_BUTTONS=" .. tostring(type(_G.MICRO_BUTTONS) == "table" and #_G.MICRO_BUTTONS or "없음"))
end


----------------------------------------------------------------------
-- 로아식 화면 (날개 모양일 때): 체력 · 자원은 날개 위 줄에 있으니 HUD 내 창은 숨기고,
-- 대상은 화면 위 가운데 긴 줄로 (레벨 · 이름 · 등급 · 체력 숫자 · % · 자원 · 내가 건 디버프)
-- HUD 내 창 · 대상 창은 보안 단추라 전투 밖에서만 숨김/다시 보이기 (투명 + 마우스 끔)
----------------------------------------------------------------------
local top
local function LAOn() local d = DB(); return d.on and d.style == "wing" and d.laTop and not ns.ABAR_LOCKED end

local function HudParts(hide)
    local fr = ns.hudFrames
    if not fr then return end
    ns:RunOutOfCombat("abar_la", function()
        for _, k in ipairs({ "player", "target", "pet" }) do
            local f = fr[k]
            if f then f:SetAlpha(hide and 0 or 1); pcall(f.EnableMouse, f, not hide) end
        end
    end)
end

local TopExtra
local function TopUpdate()
    if not top then return end
    if not (LAOn() and UnitExists("target")) then top:Hide() return end
    top:Show()
    local okN, name = pcall(UnitName, "target")
    top.name:SetText(okN and name or "")
    local okL, lv = pcall(UnitLevel, "target")
    top.lv:SetText((okL and type(lv) == "number" and lv > 0) and lv or "??")
    local okC, cls = pcall(UnitClassification, "target")
    local tag = okC and ({ elite = "정예", worldboss = "우두머리", rareelite = "희귀 정예", rare = "희귀" })[cls] or nil
    top.tag:SetShown(tag ~= nil); if tag then top.tag.t:SetText(tag); top.tag:SetWidth(top.tag.t:GetStringWidth() + 14) end
    local okK, kind = pcall(UnitCreatureType, "target")
    top.kind:SetText((okK and type(kind) == "string") and kind or "")
    -- 체력 (적 = 장미빨강 · 중립 = 금 · 아군 = 초록)
    local r, g, b = 1.0, 0.29, 0.24
    -- 반응 수치만 믿으면 적이 초록으로 나올 때가 있어서, 공격 가능 여부를 먼저 봄
    local okF, fr = pcall(UnitIsFriend, "player", "target")
    local okA, atk = pcall(UnitCanAttack, "player", "target")
    local okR, react = pcall(UnitReaction, "target", "player")
    if okR and (type(react) ~= "number" or (issecretvalue and issecretvalue(react))) then okR = false end
    if okF and fr then r, g, b = 0.37, 0.83, 0.54
    elseif okR and react == 4 then r, g, b = 0.92, 0.76, 0.36
    elseif okA and atk then r, g, b = 1.0, 0.29, 0.24
    elseif okR and react >= 5 then r, g, b = 0.37, 0.83, 0.54 end
    top.hp:SetStatusBarColor(r, g, b, 1)
    local h, hm = UnitHealth("target"), UnitHealthMax("target")
    ns.SetBar(top.hp, h, hm)
    if not pcall(function() top.hp.t:SetFormattedText("%s / %s", BreakUpLargeNumbers(h), BreakUpLargeNumbers(hm)) end) then top.hp.t:SetText("") end
    if ns.HealthPercentText then ns.HealthPercentText(top.pct, "target", h, hm) end
    local okP, pt = pcall(UnitPowerType, "target")
    local p, pm = UnitPower("target"), UnitPowerMax("target")
    -- 최대 마나가 숨김 값이면 비교가 안 되므로 그냥 보여 줌
    local okC, gt = pcall(function() return pm > 0 end)
    local showP = (not okC) or gt
    top.mp:SetShown(showP and true or false)
    if showP then
        ns.SetBar(top.mp, p, pm)
        local col = okP and PowerBarColor and PowerBarColor[pt]
        if col then top.mp:SetStatusBarColor(col.r, col.g, col.b, 1) end
    end
    if TopExtra then TopExtra(h, hm) end
end

local function TopCast()
    local c = top.cast
    local ok, nm, s0, e0, noInt = pcall(function()
        local n, _, _, st, en, _, _, ni = UnitCastingInfo("target")
        if not n and UnitChannelInfo then
            local _, ni2
            n, _, _, st, en, _, ni2 = UnitChannelInfo("target"); ni = ni2
        end
        return n, st, en, ni
    end)
    if not ok or not nm then c:Hide() return end
    local ex = top.ex
    if ex and ex.intr then
        if noInt ~= nil and not (issecretvalue and issecretvalue(noInt)) then
            if noInt then ex.intr.bg:SetColorTexture(0.45, 0.45, 0.45, 1); ex.intr.t:SetText("x"); ex.intr.lab:SetText("못 끊음"); ex.intr.lab:SetTextColor(0.7, 0.7, 0.7)
            else ex.intr.bg:SetColorTexture(0.37, 0.83, 0.54, 1); ex.intr.t:SetText("!"); ex.intr.lab:SetText("끊을 수 있음"); ex.intr.lab:SetTextColor(0.37, 0.83, 0.54) end
            ex.intr:Show()
        else ex.intr:Hide() end
    end
    local ok2, frac, left = pcall(function()
        if issecretvalue and (issecretvalue(s0) or issecretvalue(e0)) then return nil end
        local now = GetTime() * 1000
        return (now - s0) / math.max(1, e0 - s0), (e0 - now) / 1000
    end)
    c:SetMinMaxValues(0, 1); c:SetValue((ok2 and frac) or 0)
    pcall(c.n.SetText, c.n, nm)
    c.r:SetText((ok2 and left and left > 0) and string.format("%.1f", left) or "")
    c:Show()
end

local function TopTick()
    if not (top and top:IsShown()) then return end
    TopCast()
    top.tk = (top.tk or 0) + 1
    if top.tk % 5 == 0 and TopExtra then TopExtra() end
end

-- 대상 줄 더하기: 징 + 잡는 순서 · 어그로 · 기준선(35 · 20%) · 깎임 잔상 · 끊기 표시 · 대상 버프 · 대상의 대상 · 같이 치는 파티원 · 사거리
--   아군: 직업 색 이름 · 직업 아이콘 · 길드 · 초록 줄 + 어두운 글자
local RAIDICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local function ExBuild()
    local WH = ns.WHITE or "Interface\\Buttons\\WHITE8x8"
    local ex = {}
    top.ex = ex
    -- 징 · 순서
    ex.mark = top:CreateTexture(nil, "OVERLAY"); ex.mark:SetSize(18, 18); ex.mark:SetPoint("TOPLEFT", top, "TOPLEFT", 54, -1)
    ex.ord = CreateFrame("Frame", nil, top); ex.ord:SetSize(14, 14); ex.ord:SetPoint("LEFT", ex.mark, "RIGHT", 1, 0)
    local ob = ex.ord:CreateTexture(nil, "BACKGROUND"); ob:SetAllPoints(); ob:SetColorTexture(1, 0.29, 0.24, 1)
    ex.ord.fs = ex.ord:CreateFontString(nil, "OVERLAY"); ex.ord.fs:SetFont(ns.NUM or ns.FONT, 10, ""); ex.ord.fs:SetPoint("CENTER", 0, 0)
    -- 길드
    ex.guild = ns.Font(top, 10.5, { 0.37, 0.83, 0.54 }); ex.guild:SetPoint("LEFT", top.tag, "RIGHT", 8, 0)
    -- 어그로 알약
    ex.thr = CreateFrame("Frame", nil, top); ex.thr:SetSize(86, 16)
    ex.thr:SetPoint("RIGHT", top.kind, "LEFT", -10, 0)
    ex.thr.bg = ex.thr:CreateTexture(nil, "BACKGROUND"); ex.thr.bg:SetAllPoints()
    ex.thr.fs = ex.thr:CreateFontString(nil, "OVERLAY"); ex.thr.fs:SetFont(ns.FONT, 10, "OUTLINE"); ex.thr.fs:SetPoint("CENTER")
    -- 직업 아이콘 (레벨 원 왼쪽 아래)
    ex.cls = top:CreateTexture(nil, "OVERLAY"); ex.cls:SetSize(16, 16); ex.cls:SetPoint("BOTTOMLEFT", top, "TOPLEFT", 0, -46)
    ex.cls:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    -- 깎임 잔상 (체력 줄 아래 깔린 두 번째 줄 · 조금 늦게 따라와요)
    ex.trail = CreateFrame("StatusBar", nil, top)
    ex.trail:SetAllPoints(top.hp); ex.trail:SetFrameLevel(math.max(0, top.hp:GetFrameLevel() - 1))
    ex.trail:SetStatusBarTexture(WH); ex.trail:SetStatusBarColor(1, 0.85, 0.78, 0.55)
    local tm = ex.trail:CreateMaskTexture(); tm:SetTexture(ns.MEDIA .. "ab_tac_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); tm:SetAllPoints()
    ex.trail:GetStatusBarTexture():AddMaskTexture(tm)
    local tb = ex.trail:CreateTexture(nil, "BACKGROUND"); tb:SetColorTexture(0, 0, 0, 0.62); tb:SetAllPoints(); tb:AddMaskTexture(tm)
    -- 기준선 35% · 20%
    ex.lines = {}
    for i, f in ipairs({ 0.35, 0.2 }) do
        local l = top.hp:CreateTexture(nil, "OVERLAY", nil, 2); l:SetColorTexture(1, 0.8, 0.4, 0.85); l:SetSize(1.5, 22)
        l.f = f; ex.lines[i] = l
    end
    -- 끊기 표시 (시전 줄 오른쪽)
    ex.intr = CreateFrame("Frame", nil, top.cast); ex.intr:SetSize(14, 14); ex.intr:SetPoint("LEFT", top.cast, "RIGHT", 4, 0)
    ex.intr.bg = ex.intr:CreateTexture(nil, "BACKGROUND"); ex.intr.bg:SetAllPoints()
    ex.intr.t = ex.intr:CreateFontString(nil, "OVERLAY"); ex.intr.t:SetFont(ns.NUM or ns.FONT, 10, ""); ex.intr.t:SetPoint("CENTER")
    ex.intr.lab = ns.Font(ex.intr, 9.5, { 0.37, 0.83, 0.54 }); ex.intr.lab:SetPoint("LEFT", ex.intr, "RIGHT", 5, 0)
    -- 대상의 대상 상자 (오른쪽 바깥)
    ex.tot = CreateFrame("Frame", nil, top); ex.tot:SetSize(124, 42); ex.tot:SetPoint("TOPLEFT", top, "TOPRIGHT", 14, -20)
    local tb2 = ex.tot:CreateTexture(nil, "BACKGROUND"); tb2:SetAllPoints(); tb2:SetColorTexture(0.03, 0.03, 0.045, 0.82)
    for _, pp in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true } }) do
        local e = ex.tot:CreateTexture(nil, "BORDER"); e:SetColorTexture(1, 1, 1, 0.14); e:SetPoint(pp[1]); e:SetPoint(pp[2]); e:SetHeight(1)
    end
    ex.tot.cap = ns.Font(ex.tot, 8.5, { 0.81, 0.78, 0.77 }); ex.tot.cap:SetPoint("TOPLEFT", 8, -5); ex.tot.cap:SetText("대상의 대상")
    ex.tot.nm = ns.Font(ex.tot, 11.5, { 1, 1, 1 }); ex.tot.nm:SetPoint("BOTTOMLEFT", 8, 6); ex.tot.nm:SetWidth(70); ex.tot.nm:SetJustifyH("LEFT"); ex.tot.nm:SetWordWrap(false)
    ex.tot.hp = CreateFrame("StatusBar", nil, ex.tot); ex.tot.hp:SetSize(36, 5); ex.tot.hp:SetPoint("BOTTOMRIGHT", -8, 10)
    ex.tot.hp:SetStatusBarTexture(WH); ex.tot.hp:SetStatusBarColor(0.37, 0.83, 0.54)
    local hb = ex.tot.hp:CreateTexture(nil, "BACKGROUND"); hb:SetAllPoints(); hb:SetColorTexture(0, 0, 0, 0.6)
    -- 같이 치는 파티원 (직업 색 점)
    ex.pt = CreateFrame("Frame", nil, top); ex.pt:SetSize(124, 26); ex.pt:SetPoint("TOPLEFT", ex.tot, "BOTTOMLEFT", 0, -6)
    ex.pt.cap = ns.Font(ex.pt, 8.5, { 0.81, 0.78, 0.77 }); ex.pt.cap:SetPoint("TOPLEFT", 2, 0); ex.pt.cap:SetText("같이 치는 파티원")
    ex.pt.d = {}
    for i = 1, 4 do
        local d = ex.pt:CreateTexture(nil, "ARTWORK"); d:SetTexture(ns.MEDIA .. "circle"); d:SetSize(11, 11)
        d:SetPoint("TOPLEFT", 2 + (i - 1) * 15, -12); ex.pt.d[i] = d
    end
    -- 내가 건 디버프 (시전 줄 아래 왼쪽) · 대상 버프 (오른쪽) = 게임 공식 오라 칸
    local function Cont(filter, right, dbf)
        local ok, c = pcall(CreateFrame, "AuraContainer", nil, top, "CustomAuraContainerTemplate")
        if not (ok and c) then return nil end
        local ok2 = pcall(function()
            if right then
                c:SetPoint("TOPRIGHT", top.mp, "BOTTOMRIGHT", 0, -6)
                if c.SetFlowLayoutAnchorPoint then c:SetFlowLayoutAnchorPoint("TOPRIGHT") end
                if c.SetFlowLayoutGrowthDirection and AnchorUtil and AnchorUtil.FlowDirection then c:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Down) end
            else
                c:SetPoint("TOPLEFT", top.mp, "BOTTOMLEFT", 0, -24)
                if c.SetFlowLayoutAnchorPoint then c:SetFlowLayoutAnchorPoint("TOPLEFT") end
                if c.SetFlowLayoutGrowthDirection and AnchorUtil and AnchorUtil.FlowDirection then c:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down) end
            end
            c:AddAuraGroup(dbf and "leelTopD" or "leelTopB", filter, {
                maxFrameCount = 8,
                sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.Expiration or 0,
                sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal or 0,
                initializeFrame = TacAuraInit(dbf, 24),
                layout = { elementSpacing = 6, elementWidth = 24, elementHeight = 24 },
            })
            c:SetUnit("target")
        end)
        return ok2 and c or nil
    end
    ex.deb = Cont("HARMFUL|PLAYER", false, true)
    ex.buf = Cont("HELPFUL", true, false)
    local function Rebind()
        for _, c in ipairs({ ex.deb, ex.buf }) do if c then pcall(c.SetUnit, c, nil); pcall(c.SetUnit, c, "target"); pcall(c.UpdateAllAuras, c) end end
    end
    ex.rebind = Rebind
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED"); ev:RegisterEvent("RAID_TARGET_UPDATE"); ev:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_TARGET", "target")
    ev:SetScript("OnEvent", function(_, e)
        if e == "PLAYER_TARGET_CHANGED" then
            ex.newTarget = true; Rebind(); C_Timer.After(0.3, Rebind)
        end
        if top:IsShown() then TopExtra() end
    end)
end

TopExtra = function(h, hm)
    if not top then return end
    if not top.ex then ExBuild() end
    local ex = top.ex
    local u = "target"
    if not UnitExists(u) then return end
    local okF, friend = pcall(UnitIsFriend, "player", u); friend = okF and friend and true or false
    local okP, isPlayer = pcall(UnitIsPlayer, u); isPlayer = okP and isPlayer and true or false
    -- 징 · 순서
    local okM, mi = pcall(GetRaidTargetIndex, u)
    if okM and type(mi) == "number" and not (issecretvalue and issecretvalue(mi)) then
        ex.mark:SetTexture(RAIDICON .. mi); ex.mark:Show()
        top.name:ClearAllPoints(); top.name:SetPoint("TOPLEFT", top, "TOPLEFT", 92, -2)
        local api = _G.LeelMarkAPI
        local plan = api and api.Plan and select(2, pcall(api.Plan))
        local e = type(plan) == "table" and plan[mi]
        if e and e.kind == "kill" and e.n and not (api.OrderOn and not api.OrderOn()) then ex.ord.fs:SetText(e.n); ex.ord:Show() else ex.ord:Hide() end
        if not ex.ord:IsShown() then top.name:ClearAllPoints(); top.name:SetPoint("TOPLEFT", top, "TOPLEFT", 76, -2) end
    else
        ex.mark:Hide(); ex.ord:Hide()
        top.name:ClearAllPoints(); top.name:SetPoint("TOPLEFT", top, "TOPLEFT", 56, -2)
    end
    -- 이름 색 · 직업 · 길드
    local okC, _, cls = pcall(UnitClass, u)
    local cc = isPlayer and okC and cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    if cc then top.name:SetTextColor(cc.r, cc.g, cc.b) else top.name:SetTextColor(1, 1, 1) end
    if isPlayer and okC and cls and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[cls] then
        local t = CLASS_ICON_TCOORDS[cls]; ex.cls:SetTexCoord(t[1], t[2], t[3], t[4]); ex.cls:Show()
        local ok2, ln = pcall(UnitClass, u); top.kind:SetText((ok2 and type(ln) == "string") and ln or "")
    else ex.cls:Hide() end
    local okG, gn = pcall(GetGuildInfo, u)
    if isPlayer and okG and type(gn) == "string" and gn ~= "" then ex.guild:SetText("<" .. gn .. ">"); ex.guild:Show() else ex.guild:Hide() end
    if top.tag:IsShown() then ex.guild:ClearAllPoints(); ex.guild:SetPoint("LEFT", top.tag, "RIGHT", 8, 0)
    else ex.guild:ClearAllPoints(); ex.guild:SetPoint("LEFT", top.name, "RIGHT", 8, 0) end
    -- 사거리 (왼쪽 1번 칸 기술 기준 · 아군은 28m)
    local rng
    if friend then
        local okR, inr = pcall(UnitInRange, u)
        if okR and inr ~= nil and not (issecretvalue and issecretvalue(inr)) then rng = inr and true or false
        elseif not InCombatLockdown() then local ok3, c4 = pcall(CheckInteractDistance, u, 4); if ok3 and c4 ~= nil then rng = c4 and true or false end end
    else
        local okA, ar = pcall(IsActionInRange, 1)
        if okA and ar ~= nil and not (issecretvalue and issecretvalue(ar)) then rng = (ar == true or ar == 1) end
    end
    local kind = top.kind:GetText() or ""
    kind = kind:gsub(" · .*$", "")
    if rng ~= nil then
        kind = kind .. (rng and (friend and " · 치유 가능" or " · 사거리 안") or " · 사거리 밖")
        top.hp:SetAlpha(rng and 1 or 0.55)
    else top.hp:SetAlpha(1) end
    top.kind:SetText(kind)
    -- 체력 글자 (아군 = 초록 줄 위 어두운 글자)
    -- 어두운 글자에 검은 테두리를 두르면 뭉개져 보여서, 아군일 땐 테두리 없이
    if top.isFriend ~= friend then
        top.isFriend = friend
        local fl = friend and "" or "OUTLINE"
        pcall(top.hp.t.SetFont, top.hp.t, ns.NUM or ns.FONT, friend and 12 or 11, fl)
        pcall(top.pct.SetFont, top.pct, ns.NUM or ns.FONT, friend and 12.5 or 11.5, fl)
    end
    if friend then top.hp.t:SetTextColor(0.02, 0.1, 0.04); top.pct:SetTextColor(0.02, 0.1, 0.04); top.hp:SetStatusBarColor(0.37, 0.83, 0.54, 1)
    else top.hp.t:SetTextColor(1, 1, 1); top.pct:SetTextColor(1, 1, 1) end
    -- 기준선 (적만)
    local w = top.hp:GetWidth() or 0
    for _, l in ipairs(ex.lines) do
        l:ClearAllPoints(); l:SetPoint("CENTER", top.hp, "LEFT", w * l.f, 0); l:SetShown(not friend)
    end
    -- 깎임 잔상: 줄이 줄면 잔상은 0.45초 뒤에 따라와요 (숨겨진 숫자도 그대로 넘겨요)
    if h ~= nil then
        pcall(ex.trail.SetMinMaxValues, ex.trail, 0, hm or 1)
        if ex.newTarget then pcall(ex.trail.SetValue, ex.trail, h); ex.newTarget = nil
        else
            ex.seq = (ex.seq or 0) + 1; local my = ex.seq
            C_Timer.After(0.45, function() if ex.seq == my then pcall(ex.trail.SetValue, ex.trail, h) end end)
        end
    end
    -- 어그로 (적 · 전투 중)
    local okT, tank, st, pct = pcall(UnitDetailedThreatSituation, "player", u)
    if not friend and okT and st ~= nil and not (issecretvalue and issecretvalue(st)) then
        local col = (st >= 3 and { 1, 0.29, 0.24 }) or (st >= 2 and { 1, 0.6, 0.3 }) or (st >= 1 and { 1, 0.85, 0.4 }) or { 0.6, 0.6, 0.6 }
        local txt
        if pct ~= nil and not (issecretvalue and issecretvalue(pct)) then txt = string.format("어그로 %d%%", math.floor(pct + 0.5))
        else txt = (st >= 3 and "어그로 나!") or (st >= 1 and "어그로 높음") or "어그로 낮음" end
        ex.thr.fs:SetText(txt); ex.thr.fs:SetTextColor(col[1], col[2], col[3])
        ex.thr.bg:SetColorTexture(col[1], col[2], col[3], 0.18); ex.thr:SetWidth(ex.thr.fs:GetStringWidth() + 16); ex.thr:Show()
    else ex.thr:Hide() end
    -- 대상의 대상
    if UnitExists("targettarget") then
        local okN, nm = pcall(UnitName, "targettarget")
        local me = select(2, pcall(UnitIsUnit, "targettarget", "player"))
        if me == true then ex.tot.nm:SetText((okN and nm or "") .. " (나!)"); ex.tot.nm:SetTextColor(1, 0.54, 0.44)
        else
            ex.tot.nm:SetText(okN and nm or "")
            local okc, _, c2 = pcall(UnitClass, "targettarget")
            local col = okc and c2 and select(2, pcall(UnitIsPlayer, "targettarget")) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c2]
            if col then ex.tot.nm:SetTextColor(col.r, col.g, col.b) else ex.tot.nm:SetTextColor(1, 1, 1) end
        end
        ns.SetBar(ex.tot.hp, UnitHealth("targettarget"), UnitHealthMax("targettarget"))
        ex.tot:Show()
    else ex.tot:Hide() end
    -- 같이 치는 파티원
    local n = 0
    if not friend and IsInGroup and IsInGroup() then
        for i = 1, 4 do
            local pu = "party" .. i
            local okU, same = pcall(UnitIsUnit, pu .. "target", u)
            if UnitExists(pu) and okU and same == true then
                n = n + 1
                local _, pc = UnitClass(pu)
                local col = pc and RAID_CLASS_COLORS and RAID_CLASS_COLORS[pc]
                ex.pt.d[n]:SetVertexColor(col and col.r or 1, col and col.g or 1, col and col.b or 1, 1); ex.pt.d[n]:Show()
            end
        end
    end
    for i = n + 1, 4 do ex.pt.d[i]:Hide() end
    ex.pt:SetShown(n > 0)
end

local function BuildTop()
    if top then return end
    top = CreateFrame("Frame", "LeelUI_LATarget", UIParent)
    top:SetSize(560, 74)
    top:SetFrameStrata("MEDIUM")
    top:SetMovable(true); top:SetClampedToScreen(true)
    local WH = ns.WHITE or "Interface\\Buttons\\WHITE8x8"
    -- 레벨 동그라미 (왼쪽 · 둘레 눈금)
    local lvF = CreateFrame("Frame", nil, top); lvF:SetSize(40, 40); lvF:SetPoint("TOPLEFT", 2, -6)
    local lvE = lvF:CreateTexture(nil, "BACKGROUND"); lvE:SetTexture(ns.MEDIA .. "circle"); lvE:SetPoint("TOPLEFT", -1, 1); lvE:SetPoint("BOTTOMRIGHT", 1, -1)
    lvE:SetVertexColor(1, 1, 1, 0.2)
    local lvB = lvF:CreateTexture(nil, "BORDER"); lvB:SetTexture(ns.MEDIA .. "circle"); lvB:SetAllPoints(); lvB:SetVertexColor(0.03, 0.03, 0.045, 0.88)
    for i = 1, 36 do
        local a = math.pi / 2 - (i - 1) / 36 * 2 * math.pi
        local d = lvF:CreateTexture(nil, "ARTWORK"); d:SetColorTexture(1, 1, 1, (i % 3 == 1) and 0.35 or 0.18)
        local r = (i % 3 == 1) and 25 or 24; local sz = (i % 3 == 1) and 2 or 1.5
        d:SetSize(sz, sz); d:SetPoint("CENTER", lvF, "CENTER", math.cos(a) * r, math.sin(a) * r)
    end
    top.lvCap = lvF:CreateFontString(nil, "OVERLAY"); top.lvCap:SetFont(ns.FONT, 7, ""); top.lvCap:SetPoint("CENTER", 0, 8)
    top.lvCap:SetTextColor(0.81, 0.78, 0.77, 0.8); top.lvCap:SetText("LV")
    top.lv = lvF:CreateFontString(nil, "OVERLAY"); top.lv:SetFont(ns.NUM or ns.FONT, 15, ""); top.lv:SetPoint("CENTER", 0, -4)
    top.lv:SetTextColor(1, 1, 1)
    -- 이름 · 등급 상자 · 종류
    top.name = ns.Font(top, 15, { 1, 1, 1 }); top.name:SetPoint("TOPLEFT", top, "TOPLEFT", 56, -2)
    top.tag = CreateFrame("Frame", nil, top); top.tag:SetHeight(15); top.tag:SetPoint("LEFT", top.name, "RIGHT", 8, 0)
    top.tag.e = {}
    for i, pt in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 }, { "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
        local e = top.tag:CreateTexture(nil, "BORDER"); e:SetColorTexture(1, 0.8, 0.4, 0.9)
        e:SetPoint(pt[1]); e:SetPoint(pt[2]); if pt[3] == 1 then e:SetWidth(1) else e:SetHeight(1) end
        top.tag.e[i] = e
    end
    top.tag.t = ns.Font(top.tag, 9.5, { 1, 0.8, 0.4 }); top.tag.t:SetShadowColor(0, 0, 0, 0); top.tag.t:SetPoint("CENTER")
    top.kind = ns.Font(top, 10.5, { 0.81, 0.78, 0.77 }); top.kind:SetPoint("TOPRIGHT", top, "TOPRIGHT", 0, -3)
    -- 체력 줄 (모서리 깎음 · 아래 눈금)
    top.hp = CreateFrame("StatusBar", nil, top)
    top.hp:SetPoint("TOPLEFT", top, "TOPLEFT", 56, -22); top.hp:SetPoint("RIGHT", top, "RIGHT", 0, 0); top.hp:SetHeight(16)
    top.hp:SetStatusBarTexture(WH)
    local m = top.hp:CreateMaskTexture(); m:SetTexture(ns.MEDIA .. "ab_tac_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); m:SetAllPoints()
    top.hp:GetStatusBarTexture():AddMaskTexture(m)
    top.hpMask = m
    local shine = top.hp:CreateTexture(nil, "OVERLAY"); shine:SetColorTexture(1, 1, 1, 0.14); shine:SetHeight(1)
    shine:SetPoint("TOPLEFT", 8, -2); shine:SetPoint("TOPRIGHT", -8, -2)
    top.hp.ticks = {}
    for i = 1, 9 do local k = top.hp:CreateTexture(nil, "OVERLAY"); k:SetColorTexture(1, 1, 1, 0.25); k:SetSize(1, 3); top.hp.ticks[i] = k end
    top.hp:SetScript("OnSizeChanged", function(self, w)
        for i, k in ipairs(self.ticks) do k:ClearAllPoints(); k:SetPoint("TOPLEFT", self, "BOTTOMLEFT", math.floor((w or 0) * i / 10), -2) end
    end)
    top.hp.t = top.hp:CreateFontString(nil, "OVERLAY"); top.hp.t:SetFont(ns.NUM or ns.FONT, 11, "OUTLINE"); top.hp.t:SetPoint("LEFT", 10, 0)
    top.pct = top.hp:CreateFontString(nil, "OVERLAY"); top.pct:SetFont(ns.NUM or ns.FONT, 11.5, "OUTLINE"); top.pct:SetPoint("RIGHT", -10, 0)
    -- 자원 줄 (얇게 · 체력 줄과 같은 길이)
    top.mp = CreateFrame("StatusBar", nil, top)
    top.mp:SetPoint("TOPLEFT", top.hp, "BOTTOMLEFT", 0, -8); top.mp:SetPoint("RIGHT", top.hp, "RIGHT", 0, 0); top.mp:SetHeight(3)
    top.mp:SetStatusBarTexture(WH)
    local mb = top.mp:CreateTexture(nil, "BACKGROUND"); mb:SetAllPoints(); mb:SetColorTexture(0, 0, 0, 0.55)
    -- 적 시전 줄 (기술 이름 · 남은 초)
    top.cast = CreateFrame("StatusBar", nil, top)
    top.cast:SetPoint("TOPLEFT", top.mp, "BOTTOMLEFT", 0, -6); top.cast:SetSize(270, 12)
    top.cast:SetStatusBarTexture(WH); top.cast:SetStatusBarColor(0.78, 0.64, 0.29, 0.9)
    local cb = top.cast:CreateTexture(nil, "BACKGROUND"); cb:SetAllPoints(); cb:SetColorTexture(0, 0, 0, 0.55)
    top.cast.n = top.cast:CreateFontString(nil, "OVERLAY"); top.cast.n:SetFont(ns.FONT, 9, "OUTLINE"); top.cast.n:SetPoint("LEFT", 6, 0)
    top.cast.r = top.cast:CreateFontString(nil, "OVERLAY"); top.cast.r:SetFont(ns.NUM or ns.FONT, 9, "OUTLINE"); top.cast.r:SetPoint("RIGHT", -5, 0)
    top.cast:Hide()
    top.debuffs = {}
    top:Hide()
    -- 이동 모드: 끌기 = 옮기기 · 누르면 크기 줄 · 휠 / 모서리 = 크기
    local mv = CreateFrame("Frame", nil, top)
    mv:SetPoint("TOPLEFT", -6, 22); mv:SetPoint("BOTTOMRIGHT", 6, -24)
    mv:SetFrameStrata("DIALOG"); mv:EnableMouse(true); mv:RegisterForDrag("LeftButton")
    mv:SetScript("OnDragStart", function() if not InCombatLockdown() then top:StartMoving() end end)
    mv:SetScript("OnDragStop", function()
        top:StopMovingOrSizing()
        local x, y = top:GetCenter()
        local sc = top:GetScale()
        DB().laPos = { math.floor(x * sc + 0.5), math.floor(y * sc + 0.5) }
        ns.ABarLAPlace()
    end)
    mv:Hide()
    top.mover = mv
    if ns.SetMoveMode then
        hooksecurefunc(ns, "SetMoveMode", function()
            local on = ns.moving and LAOn()
            mv:SetShown(on and true or false)
            -- 이동 모드에선 대상이 없어도 예시로 보여요
            if on then top:Show(); if not UnitExists("target") then top.name:SetText("대상 예시"); top.lv:SetText("60"); ns.SetBar(top.hp, 7, 10); top.hp.t:SetText("70 / 100"); top.pct:SetText("70%") end
            else TopUpdate() end
        end)
    end
    C_Timer.After(0, function()
        if ns.MoveSizeHook then ns.MoveSizeHook(mv, "대상 줄 크기", "대상 줄") end
    end)
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_AURA", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION" }) do
        pcall(ev.RegisterUnitEvent, ev, e, "target")
    end
    ev:SetScript("OnEvent", TopUpdate)
    local acc = 0
    top:SetScript("OnUpdate", function(_, e) acc = acc + e; if acc > 0.05 then acc = 0; TopTick() end end)
end

-- 자리 · 크기 (기본 = 화면 위 가운데)
function ns.ABarLAPlace()
    if not top then return end
    local d = DB()
    local sc = math.max(0.5, math.min(1.6, (d.laScale or 100) / 100))
    top:SetScale(sc)
    top:ClearAllPoints()
    if d.laPos then top:SetPoint("CENTER", UIParent, "BOTTOMLEFT", d.laPos[1] / sc, d.laPos[2] / sc)
    else top:SetPoint("TOP", UIParent, "TOP", 0, -64 / sc) end
end
function ns.ABarLASetScale(v)
    DB().laScale = math.floor(tonumber(v) or 100)
    ns.ABarLAPlace()
end

function ns.ABarLAApply()
    if LAOn() then BuildTop(); ns.ABarLAPlace(); HudParts(true); TopUpdate()
    else HudParts(false); if top then top:Hide() end end
end
local laEv = CreateFrame("Frame")
laEv:RegisterEvent("PLAYER_LOGIN")
laEv:SetScript("OnEvent", function() C_Timer.After(1.5, ns.ABarLAApply) end)
if ns.ApplyHudParts then hooksecurefunc(ns, "ApplyHudParts", function() if LAOn() then HudParts(true) end end) end

----------------------------------------------------------------------
-- 르엘 스킨: 모양 + 자리 + 크기 + 설정을 한 묶음으로 저장 · 입히기 · 끄면 원래대로
--  * 입히기 전 모습(액션바 설정 전체)을 backup 에 저장 → 스킨 쓰기 끄면 그대로 되돌림
--  * 스킨마다 자리 · 크기를 따로 기억 (갈아입을 때 지금 스킨 것을 저장)
----------------------------------------------------------------------
local SKIN_CATS = {
    ab = { "style", "wskin", "scale", "mscale", "point", "lpoint", "tacBH", "menuStyle", "mrpoint", "mrPins", "mrScale" },
    tg = { "laScale", "laPos" },
    bf = { "tacAuras" },
    la = { "laTop" },
    pg = { "pgKeys" },
}
local SKIN_ALL = { "on", "tacBH", "menuStyle", "mrpoint", "mrPins", "mrScale", "style", "wskin", "scale", "mscale", "point", "lpoint", "laScale", "laPos", "tacAuras", "laTop", "pgKeys" }
local SKIN_BUILTIN = {
    { key = "tac", label = "각진 전술형" }, { key = "la", label = "로아풍 강철" },
    { key = "gold", label = "실사 금테" }, { key = "iron", label = "실사 쇠테" }, { key = "pink", label = "분홍 (예전)" },
}
local function Copy(v)
    if type(v) ~= "table" then return v end
    local t = {}; for k, x in pairs(v) do t[k] = Copy(x) end; return t
end
local function SDB()
    ns.db.skin = ns.db.skin or {}
    local s = ns.db.skin
    s.saved = s.saved or {}; s.mine = s.mine or {}
    s.incl = s.incl or { ab = true, tg = true, bf = true, la = true, pg = true }
    s.cur = s.cur or "tac"
    return s
end
local function Mine(id) for i, m in ipairs(SDB().mine) do if m.id == id then return m, i end end end
local function Capture()
    local d, s, t = DB(), SDB(), {}
    for cat, keys in pairs(SKIN_CATS) do
        if s.incl[cat] then for _, k in ipairs(keys) do t[k] = Copy(d[k]) end end
    end
    return t
end
local function Default(id)
    local m = Mine(id)
    if m then return Copy(m.data) end
    return { style = "wing", wskin = id }
end
local function SkinRefresh(before)
    local d = DB()
    if before.on ~= d.on or before.style ~= d.style then
        P("스킨을 바꿨어요. |cfff2b3c2/reload|r (허브 아래 '다시 불러오기') 하면 액션바가 바뀌어요.")
        return
    end
    if InCombatLockdown() then P("전투가 끝나면 스킨이 바뀌어요."); pending = true; return end
    if holder then Apply(); pcall(ApplyLauncher); Layout() end
    if launchHolder then launchHolder:SetScale((d.mscale or 100) / 100) end
    if ns.ABarLAApply then ns.ABarLAApply() end
    if ns.ABarKeys then ns.ABarKeys() end
    if ns.ABarMenuStyle then ns.ABarMenuStyle() end
end
local Skin = {}
ns.Skin = Skin
function Skin.On() return SDB().on and true or false end
function Skin.Cur() return SDB().cur end
function Skin.List()
    local l = {}
    for _, b in ipairs(SKIN_BUILTIN) do l[#l + 1] = { key = b.key, label = b.label } end
    for _, m in ipairs(SDB().mine) do l[#l + 1] = { key = m.id, label = m.name .. " (내 스킨)" } end
    return l
end
function Skin.Apply(id)
    local s, d = SDB(), DB()
    local before = { on = d.on, style = d.style }
    if not s.on then
        local b = {}; for _, k in ipairs(SKIN_ALL) do b[k] = Copy(d[k]) end
        s.backup = b; s.on = true
    else
        s.saved[s.cur] = Capture()
        local m = Mine(s.cur); if m then m.data = Capture() end
    end
    local data = s.saved[id] or Default(id)
    for k, v in pairs(data) do d[k] = Copy(v) end
    d.on = true
    s.cur = id
    SkinRefresh(before)
end
function Skin.Off()
    local s, d = SDB(), DB()
    if not s.on then return end
    s.saved[s.cur] = Capture()
    local m = Mine(s.cur); if m then m.data = Capture() end
    local before = { on = d.on, style = d.style }
    local b = s.backup or {}
    for _, k in ipairs(SKIN_ALL) do d[k] = Copy(b[k]) end
    if d.on == nil then d.on = false end
    s.on = false; s.backup = nil
    SkinRefresh(before)
end
function Skin.SetOn(v) if v then Skin.Apply(SDB().cur) else Skin.Off() end end
function Skin.SaveAs(name)
    local s = SDB()
    local id = "m" .. time() .. math.random(100, 999)
    name = (name and name ~= "") and name or ("내 스킨 " .. (#s.mine + 1))
    local data = Capture(); data.wskin = data.wskin or DB().wskin; data.style = data.style or DB().style
    table.insert(s.mine, { id = id, name = name, data = data })
    s.saved[id] = Copy(data)
    if s.on then s.cur = id end
    P("'" .. name .. "' 스킨으로 저장했어요.")
    return id
end
function Skin.Rename(name)
    local m = Mine(SDB().cur)
    if not m then P("지금 입은 스킨이 내 스킨이 아니에요."); return false end
    if not name or name == "" then return false end
    m.name = name; P("스킨 이름을 '" .. name .. "'(으)로 바꿨어요."); return true
end
function Skin.Delete()
    local s = SDB()
    local m, i = Mine(s.cur)
    if not m then P("지금 입은 스킨이 내 스킨이 아니에요."); return end
    table.remove(s.mine, i); s.saved[m.id] = nil
    P("'" .. m.name .. "' 스킨을 지웠어요.")
    if s.on then s.cur = "tac"; local data = Default("tac"); local d = DB(); local before = { on = d.on, style = d.style }
        for k, v in pairs(data) do d[k] = Copy(v) end; SkinRefresh(before)
    else s.cur = "tac" end
end
-- 공유 글: !LeelSkin:1:키=값;키=값! (값: 숫자 · 글자 · 참/거짓 · 표는 , 로)
local function Enc(v)
    if type(v) == "table" then local t = {}; for i, x in ipairs(v) do t[i] = tostring(x) end; return "{" .. table.concat(t, ",") .. "}" end
    if type(v) == "boolean" then return v and "T" or "F" end
    return tostring(v)
end
local function Dec(s)
    if s == "T" then return true elseif s == "F" then return false end
    local inner = s:match("^{(.*)}$")
    if inner then local t = {}; for x in inner:gmatch("[^,]+") do t[#t + 1] = tonumber(x) or x end; return t end
    return tonumber(s) or s
end
function Skin.Export()
    local s = SDB()
    local data = s.on and Capture() or (s.saved[s.cur] or Default(s.cur))
    local parts = {}
    for k, v in pairs(data) do if v ~= nil then parts[#parts + 1] = k .. "=" .. Enc(v) end end
    table.sort(parts)
    return "!LeelSkin:1:" .. table.concat(parts, ";") .. "!"
end
function Skin.Import(str)
    local body = type(str) == "string" and str:match("!LeelSkin:1:(.-)!")
    if not body then P("공유 글이 아니에요. !LeelSkin: 으로 시작하는 글을 붙여 넣어 주세요."); return false end
    local ok = {}; for _, keys in pairs(SKIN_CATS) do for _, k in ipairs(keys) do ok[k] = true end end
    local data = {}
    for kv in body:gmatch("[^;]+") do
        local k, v = kv:match("^(%w+)=(.+)$")
        if k and ok[k] then data[k] = Dec(v) end
    end
    local s = SDB()
    local id = "m" .. time() .. math.random(100, 999)
    local name = "받은 스킨 " .. (#s.mine + 1)
    table.insert(s.mine, { id = id, name = name, data = data }); s.saved[id] = Copy(data)
    P("'" .. name .. "'을 받았어요. 허브 '입은 스킨'에서 골라 입혀 보세요.")
    return true
end
function Skin.Incl(cat, v) local s = SDB(); if v == nil then return s.incl[cat] ~= false end; s.incl[cat] = v and true or false end

SLASH_LEELSKIN1 = "/르엘스킨"
SLASH_LEELSKIN2 = "/leelskin"
SlashCmdList.LEELSKIN = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "원래대로" or msg == "끄기" or msg == "off" then Skin.Off(); P("스킨을 끄고 입히기 전 모습으로 돌렸어요.")
    elseif msg == "공유" then local t = Skin.Export(); if ChatFrame_OpenChat then ChatFrame_OpenChat(t) else P(t) end
    elseif msg:find("^!LeelSkin") then Skin.Import(msg)
    else
        P("스킨 쓰기: " .. (Skin.On() and "켬" or "끔") .. " · 입은 스킨: " .. tostring(Skin.Cur()))
        P("/르엘스킨 원래대로 · /르엘스킨 공유 · /르엘스킨 !LeelSkin:...! (받기)")
    end
end

----------------------------------------------------------------------
-- 단축키 정하기 (르엘UI 안에서): 단추 위에 마우스 → 키 누르기
--  Delete / Backspace = 그 단추 단축키 지우기 · Esc 또는 [완료] = 끝 · 전투 중엔 안 돼요
----------------------------------------------------------------------
do
local CMD_PREFIX = {
    { "^ActionButton(%d+)$", "ACTIONBUTTON" },
    { "^MultiBarBottomLeftButton(%d+)$", "MULTIACTIONBAR1BUTTON" },
    { "^MultiBarBottomRightButton(%d+)$", "MULTIACTIONBAR2BUTTON" },
    { "^MultiBarRightButton(%d+)$", "MULTIACTIONBAR3BUTTON" },
    { "^MultiBarLeftButton(%d+)$", "MULTIACTIONBAR4BUTTON" },
    { "^StanceButton(%d+)$", "SHAPESHIFTBUTTON" },
    { "^ShapeshiftButton(%d+)$", "SHAPESHIFTBUTTON" },
    { "^PetActionButton(%d+)$", "BONUSACTIONBUTTON" },
}
local function CmdOf(btn)
    local n = btn and btn.GetName and btn:GetName()
    if not n then return end
    for _, c in ipairs(CMD_PREFIX) do
        local i = n:match(c[1])
        if i then return c[2] .. i end
    end
end
local MODS = { LSHIFT = 1, RSHIFT = 1, LCTRL = 1, RCTRL = 1, LALT = 1, RALT = 1, UNKNOWN = 1, LMETA = 1, RMETA = 1 }
local MOUSE = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }
local function WithMods(k)
    if IsShiftKeyDown() then k = "SHIFT-" .. k end
    if IsControlKeyDown() then k = "CTRL-" .. k end
    if IsAltKeyDown() then k = "ALT-" .. k end
    return k
end
local function KeysText(cmd)
    local t = { GetBindingKey(cmd) }
    for i, k in ipairs(t) do t[i] = GetBindingText and GetBindingText(k, "KEY_") or k end
    return #t > 0 and table.concat(t, ", ") or "없음"
end

local binder, banner, cur
local hooked = {}
local active = false

local function Save()
    local set = GetCurrentBindingSet and GetCurrentBindingSet() or 1
    pcall(SaveBindings, set)
end
local function Paint()
    if not (binder and cur) then return end
    local cmd = CmdOf(cur)
    binder.t:SetText(cmd and KeysText(cmd) or "")
    if GameTooltip:IsOwned(binder) or true then
        GameTooltip:SetOwner(binder, "ANCHOR_TOP")
        GameTooltip:SetText("단축키: " .. (cmd and KeysText(cmd) or "-"), 1, 1, 1)
        GameTooltip:AddLine("키를 누르면 바뀌어요 · Delete = 지우기 · Esc = 끝", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end
end
local function Bind(key)
    if not cur or InCombatLockdown() then return end
    local cmd = CmdOf(cur)
    if not cmd then return end
    for _, k in ipairs({ GetBindingKey(cmd) }) do SetBinding(k) end
    if key then SetBinding(key, cmd) end
    Save()
    Paint()
end

local Stop
local function Over(btn)
    if not active or not CmdOf(btn) then return end
    cur = btn
    binder:ClearAllPoints(); binder:SetAllPoints(btn)
    binder:SetFrameStrata("DIALOG"); binder:Show()
    Paint()
end

local function Build()
    binder = CreateFrame("Button", nil, UIParent)
    binder:Hide()
    binder:EnableKeyboard(true); binder:EnableMouseWheel(true)
    binder:RegisterForClicks("AnyUp")
    local ov = binder:CreateTexture(nil, "OVERLAY"); ov:SetAllPoints(); ov:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.28)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = binder:CreateTexture(nil, "OVERLAY", nil, 1); e:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 1)
        if side == "TOP" or side == "BOTTOM" then e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(2)
        else e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(2) end
    end
    binder.t = binder:CreateFontString(nil, "OVERLAY"); binder.t:SetFont(ns.NUM or ns.FONT, 11, "OUTLINE"); binder.t:SetPoint("CENTER")
    binder:SetScript("OnLeave", function() binder:Hide(); cur = nil; GameTooltip:Hide() end)
    binder:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then Stop() return end
        if MODS[key] then return end
        if key == "DELETE" or key == "BACKSPACE" then Bind(nil) return end
        Bind(WithMods(key))
    end)
    binder:SetScript("OnMouseWheel", function(_, d) Bind(WithMods(d > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")) end)
    binder:SetScript("OnClick", function(_, b) local m = MOUSE[b]; if m then Bind(WithMods(m)) end end)

    banner = CreateFrame("Frame", nil, UIParent)
    banner:SetSize(520, 64); banner:SetPoint("TOP", 0, -150); banner:SetFrameStrata("DIALOG")
    ns.RoundPlate(banner, 10, { 0.1, 0.09, 0.11, 0.95 }, { C.acc[1], C.acc[2], C.acc[3], 0.9 })
    local t1 = ns.Font(banner, 14); t1:SetPoint("TOPLEFT", 16, -12); t1:SetText("단축키 정하기")
    local t2 = ns.Font(banner, 11, C.tx2); t2:SetPoint("TOPLEFT", t1, "BOTTOMLEFT", 0, -5)
    t2:SetText("단추 위에 마우스를 올리고 키를 누르세요 · Shift/Ctrl/Alt · 휠 · 마우스 3~5번도 돼요\nDelete = 지우기 · Esc = 끝")
    t2:SetJustifyH("LEFT")
    local done = CreateFrame("Button", nil, banner); done:SetSize(64, 28); done:SetPoint("RIGHT", -14, 0)
    ns.RoundRect(done, 8, C.acc, "BACKGROUND", 0, 0)
    local dt = ns.Font(done, 12.5, C.ink); dt:SetPoint("CENTER"); dt:SetText("완료")
    done:SetScript("OnClick", function() Stop() end)
    banner:Hide()

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:SetScript("OnEvent", function() if active then Stop(); P("전투가 시작돼서 단축키 정하기를 끝냈어요.") end end)
end

Stop = function()
    active = false; cur = nil
    if binder then binder:Hide() end
    if banner then banner:Hide() end
    GameTooltip:Hide()
    Save()
    P("단축키를 저장했어요.")
end

function ns.ABarBindMode()
    if InCombatLockdown() then P("전투가 끝나고 해 주세요.") return end
    if not holder then P("모던 액션바를 켜고 다시 불러오기 한 뒤에 쓸 수 있어요.") return end
    if not binder then Build() end
    for b in pairs(managed) do
        if not hooked[b] and CmdOf(b) then
            hooked[b] = true
            b:HookScript("OnEnter", Over)
        end
    end
    active = true
    banner:Show()
    local hub = _G.LeelUI_Hub
    if hub and hub:IsShown() then hub:Hide() end
    P("단축키 정하기: 단추 위에 마우스를 올리고 키를 누르세요. Esc = 끝")
end
end

----------------------------------------------------------------------
-- UI 모드: 기본 ↔ 모던을 한 번에 (허브 "UI 모드" + 처음 켤 때 고르는 창)
--  부분: ab 액션바 · tg 대상 표시 · mm 미니맵 · menu 메뉴 · bf 버프 줄
----------------------------------------------------------------------
do
local UIMode = {}
ns.UIMode = UIMode
local function MDB() ns.db.uimode = ns.db.uimode or {}; return ns.db.uimode end
local function Reload() if StaticPopup_Show then StaticPopup_Show("LEELUI_HUB_RELOAD") end end

function UIMode.Part(p)
    local d = DB()
    if p == "ab" then return (d.on and d.style == "wing" and d.wskin == "tac") and "tac" or (d.on and "leel" or "base") end
    if p == "tg" then return d.laTop ~= false and "top" or "hud" end
    if p == "mm" then local s = ns.db.mmStyle; return s == "tac" and "tac" or (s == "blizz" and "blizz" or "bar") end
    if p == "menu" then return d.menuStyle == "bunny" and "bunny" or "row" end
    if p == "bf" then return d.tacAuras ~= false and "on" or "off" end
    if p == "party" then return ns.db.partyStyle == "modern" and "modern" or "tile" end
end
function UIMode.Get()
    local P = UIMode.Part
    if P("ab") == "base" and P("mm") == "bar" and P("party") == "tile" then return "base" end
    if P("ab") == "tac" and P("tg") == "top" and P("mm") == "tac" and P("menu") == "row" and P("bf") == "on" and P("party") == "modern" then return "tac" end
    return "custom"
end
-- 액션바가 모던일 때만 의미 있는 부분
function UIMode.TacOnly() return UIMode.Part("ab") ~= "tac" end

local function Live()
    if InCombatLockdown() then P("전투가 끝나면 바뀌어요."); pending = true; return end
    if ns.ABarLAApply then ns.ABarLAApply() end
    if ns.ABarMenuStyle then ns.ABarMenuStyle() end
    if ns.ABarSkin then ns.ABarSkin() end
end
-- 값만 바꾸고 다시 불러오기가 필요한지 돌려줌
local function Set(p, v)
    local d = DB()
    if p == "ab" then
        if UIMode.Part("ab") == v then return false end
        if v == "tac" then d.on = true; d.style = "wing"; d.wskin = "tac" else d.on = false end
        return true
    elseif p == "mm" then
        if UIMode.Part("mm") == v then return false end
        ns.db.mmStyle = v; return true
    elseif p == "party" then
        if UIMode.Part("party") == v then return false end
        ns.db.partyStyle = v
        ns.db.partyScale = (v == "modern") and 0.75 or ns.db.partyScale
        return true
    elseif p == "tg" then d.laTop = (v == "top")
    elseif p == "menu" then d.menuStyle = v
    elseif p == "bf" then d.tacAuras = (v == "on") end
    return false
end
function UIMode.SetPart(p, v)
    if Set(p, v) then Reload() else Live() end
end
function UIMode.Set(m)
    local need = false
    local fresh = m == "tac" and UIMode.Get() ~= "tac"
    if m == "base" then
        need = Set("ab", "base") or need
        need = Set("mm", "bar") or need
        need = Set("party", "tile") or need
    elseif m == "tac" then
        need = Set("ab", "tac") or need
        need = Set("mm", "tac") or need
        need = Set("party", "modern") or need
        Set("tg", "top"); Set("menu", "row"); Set("bf", "on")
    else return end
    MDB().mode = m
    if fresh then pcall(UIMode.ResetPos) end   -- 모던으로 처음 바꿀 때 모던 기본 자리
    if need then Reload() else Live() end
    return need
end

-- 모던 기본 자리 (르엘 화면 기준 · 화면 크기에 맞춰 계산)
--  르엘 화면(1920×1080)에서 맞춘 값: 미니맵 = 왼쪽 위 · 메뉴 줄 = 오른쪽 위 (145%) · 대상 바 = 위 가운데 · 파티 창 = 채팅창 바로 위 · 액션바 = 아래 가운데
function UIMode.ResetPos()
    local d = DB()
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local R = function(v) return math.floor(v + 0.5) end
    d.point = { "CENTER", "BOTTOM", 0, 168 }   -- 액션바: 아래 가운데 (크기 130%)
    d.scale = 130
    d.laPos = { R(W / 2 - 5), R(H - 74) }
    d.mrScale = 145
    d.mrpoint = { "CENTER", "BOTTOMLEFT", R((W - 203) / 1.45), R((H - 59) / 1.45) }
    ns.db.mmPos = { 138, R(H - 141) }
    if MinimapCluster and not InCombatLockdown() then
        MinimapCluster:ClearAllPoints()
        MinimapCluster:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ns.db.mmPos[1], ns.db.mmPos[2])
    end
    if ns.db.partyStyle == "modern" then
        ns.db.partyScale = 0.75
        if ns.party and not InCombatLockdown() then ns.party:SetScale(0.75) end
    end
    local s = tonumber(ns.db.partyScale) or 1
    if ns.db.partyStyle == "modern" then
        ns.db.partyPoint = { "CENTER", "BOTTOMLEFT", R(156 / s), R(H * 0.55 / s) }   -- 로아식 세로 줄 (75%): 미니맵 아래 · 채팅창 위
    else
        ns.db.partyPoint = { "CENTER", "BOTTOMLEFT", R(200 / s), R(H * 0.4963 / s) }   -- 채팅창 바로 위
    end
    if ns.ApplyPartyPosition then ns:ApplyPartyPosition() end
    if InCombatLockdown() then pending = true; return end
    if holder then Apply() end
    if ns.SetABarScale then pcall(ns.SetABarScale, ns, 130) end
    if ns.ABarLAPlace then ns.ABarLAPlace() end
    if ns.ABarMenuScale then ns.ABarMenuScale(d.mrScale) end
end

----------------------------------------------------------------------
-- 처음 켤 때 고르는 창
----------------------------------------------------------------------
local win
local function Box(parent, x, y, w, h, col, a)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(col[1], col[2], col[3], a or 1)
    t:SetPoint("TOPLEFT", x, -y); t:SetSize(w, h)
    return t
end
local function Mini(card, kind)
    local sc = CreateFrame("Frame", nil, card)
    sc:SetPoint("TOPLEFT", 14, -14); sc:SetSize(252, 130)
    local bg = sc:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
    bg:SetColorTexture(0.2, 0.22, 0.19, 1)
    local g = { 1, 1, 1 }
    if kind == "base" then
        Box(sc, 76, 10, 100, 11, g, 0.22)                       -- 대상
        local mm = sc:CreateTexture(nil, "ARTWORK"); mm:SetTexture(ns.MEDIA .. "circle"); mm:SetVertexColor(1, 1, 1, 0.22)
        mm:SetSize(48, 48); mm:SetPoint("TOPRIGHT", -8, -8)
        Box(sc, 10, 34, 58, 22, g, 0.22)                         -- 내 창
        Box(sc, 66, 94, 120, 12, g, 0.22); Box(sc, 66, 110, 120, 12, g, 0.22)   -- 기본 액션바
    else
        Box(sc, 56, 9, 140, 6, { 0.89, 0.42, 0.35 }, 1)           -- 위쪽 대상 바
        Box(sc, 196, 8, 48, 48, g, 0.22)                          -- 네모 미니맵
        Box(sc, 104, 8, 86, 6, g, 0.12)                           -- 메뉴 줄
        local ring = sc:CreateTexture(nil, "ARTWORK"); ring:SetTexture(ns.MEDIA .. "ab_tac_ring"); ring:SetVertexColor(0.79, 0.64, 0.29, 1)
        ring:SetSize(28, 28); ring:SetPoint("BOTTOM", 0, 8)
        Box(sc, 26, 92, 84, 5, { 0.37, 0.83, 0.54 }, 1); Box(sc, 142, 92, 84, 5, { 0.35, 0.56, 0.9 }, 1)
        Box(sc, 26, 102, 84, 18, g, 0.22); Box(sc, 142, 102, 84, 18, g, 0.22)
    end
end

local function ShowWizard()
    if win then win:Show(); win:Paint(); return end
    win = CreateFrame("Frame", "LeelUI_ModeWizard", UIParent)
    win:SetSize(640, 360); win:SetPoint("CENTER", 0, 40)
    win:SetFrameStrata("DIALOG"); win:EnableMouse(true); win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
    ns.RoundPlate(win, 14, { 0.11, 0.1, 0.12, 0.97 }, { 1, 1, 1, 0.1 })
    tinsert(UISpecialFrames, "LeelUI_ModeWizard")
    local title = ns.Font(win, 18); title:SetPoint("TOP", 0, -20); title:SetText("어떤 화면으로 시작할까요?")
    local sub = ns.Font(win, 11.5, C.tx2); sub:SetPoint("TOP", title, "BOTTOM", 0, -6)
    sub:SetText("나중에 르엘 허브 > UI 모드에서 언제든 바꿀 수 있어요")

    local pick = UIMode.Get() == "base" and "base" or "tac"
    local cards = {}
    local DATA = {
        { "base", "기본", "지금까지 쓰던 르엘UI 그대로\n둥근 미니맵 · 게임 기본 액션바" },
        { "tac", "모던", "각진 액션바 · 위쪽 대상 바 · 네모 미니맵\n투명 메뉴 줄 · 버프 / 디버프 줄" },
    }
    for i, dt in ipairs(DATA) do
        local c = CreateFrame("Button", nil, win)
        c:SetSize(280, 212); c:SetPoint("TOPLEFT", 30 + (i - 1) * 300, -70)
        c.fill, c.edge = ns.RoundPlate(c, 12, { 0.16, 0.14, 0.17, 1 }, { 1, 1, 1, 0.1 })
        Mini(c, dt[1])
        c.name = ns.Font(c, 15); c.name:SetPoint("TOPLEFT", 16, -154)
        c.name:SetText(dt[2])
        c.desc = ns.Font(c, 11, C.tx2); c.desc:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -6)
        c.desc:SetJustifyH("LEFT"); c.desc:SetText(dt[3])
        c.key = dt[1]
        c:SetScript("OnClick", function() pick = dt[1]; win:Paint() end)
        cards[i] = c
    end
    local function Btn(text, primary, x)
        local b = CreateFrame("Button", nil, win)
        b.fs = ns.Font(b, 13, primary and C.ink or C.tx); b.fs:SetPoint("CENTER"); b.fs:SetText(text)
        b:SetSize(b.fs:GetStringWidth() + 40, 32)
        ns.RoundRect(b, 8, primary and C.acc or { 0.23, 0.18, 0.17 }, "BACKGROUND", 0, 0)
        b:SetPoint("BOTTOM", x, 22)
        return b
    end
    local later = Btn("나중에", false, -80)
    later:SetScript("OnClick", function()
        MDB().asked = true; win:Hide()
        P("르엘 허브 > UI 모드에서 언제든 고를 수 있어요.")
    end)
    local go = Btn("이걸로 시작", true, 70)
    go:SetScript("OnClick", function()
        if InCombatLockdown() then P("전투가 끝나고 눌러 주세요."); return end
        MDB().asked = true; win:Hide()
        local first = UIMode.Get() ~= "tac" and pick == "tac"
        if first then UIMode.ResetPos() end
        local need = UIMode.Set(pick)
        if not need then P(pick == "tac" and "모던으로 바꿨어요." or "기본으로 바꿨어요.") end
    end)

    function win:Paint()
        for _, c in ipairs(cards) do
            local on = c.key == pick
            c.edge:SetColor(on and C.acc or { 1, 1, 1 }, on and 1 or 0.1)
            c.name:SetTextColor(on and C.acc[1] or C.tx[1], on and C.acc[2] or C.tx[2], on and C.acc[3] or C.tx[3])
        end
    end
    win:Paint()
end
UIMode.Wizard = ShowWizard

-- 허브: "시작" 묶음 맨 위 (새 소식 다음)
if ns.HUB_MODULES then
    local tacDim = function() return UIMode.TacOnly() end
    local function Part(p, label, hint, options, more, dim)
        return { t = "seg", label = label, hint = hint, options = options, more = more,
                 dimIf = dim and tacDim or nil, dimWhy = dim and "액션바가 모던일 때" or nil,
                 get = function() return UIMode.Part(p) end, set = function(v) UIMode.SetPart(p, v) end }
    end
    table.insert(ns.HUB_MODULES, 2, {
        key = "LeelUI_Mode", builtin = true, always = true, cat = "start", ord = 1.5,
        title = "UI 모드", sub = "기본 · 모던", icon = "hb_c_view",
        desc = "화면 전체 모습을 한 번에 바꿔요. 부분마다 따로 골라 섞을 수도 있어요 (섞으면 '사용자 지정').\n액션바 · 미니맵을 바꾸면 다시 불러오기가 필요해요.",
        items = {
            { t = "seg", label = "UI 모드", hint = "고르면 아래가 한꺼번에 바뀌어요",
              options = { { "기본", "base" }, { "모던", "tac" }, { "사용자 지정", "custom" } },
              get = function() return UIMode.Get() end,
              set = function(v) if v ~= "custom" then UIMode.Set(v) end end,
              more = "기본 = 게임 기본 액션바 + 둥근 미니맵 (지금까지 쓰던 르엘UI).\n모던 = 각진 액션바 · 위쪽 대상 바 · 네모 미니맵 · 투명 메뉴 줄 · 버프 / 디버프 줄.\n사용자 지정 = 아래에서 부분마다 따로 고른 상태." },
            { t = "header", label = "부분마다 고르기" },
            Part("ab", "액션바", "다시 불러오기 후 적용", { { "게임 기본", "base" }, { "모던", "tac" } },
                 "모던 = 가운데 레벨 링 + 양옆 생명력 · 마나 줄 + 날개 단추."),
            Part("tg", "대상 표시", "", { { "HUD 초상화", "hud" }, { "위쪽 대상 바", "top" } },
                 "위쪽 대상 바 = 화면 위 가운데 긴 줄 (어그로 · 대상의 대상 · 사거리 · 내 디버프).", true),
            Part("mm", "미니맵", "다시 불러오기 후 적용", { { "블리자드", "blizz" }, { "동그라미", "bar" }, { "네모", "tac" } }),
            Part("menu", "메뉴", "", { { "토끼 버튼", "bunny" }, { "투명 메뉴 줄", "row" } },
                 "투명 메뉴 줄 = 자주 쓰는 것만 늘 보이고 나머지는 [더보기].", true),
            Part("party", "파티 창", "다시 불러오기 후 적용", { { "힐러 타일", "tile" }, { "모던 (로아식)", "modern" } },
                 "모던 = 왼쪽 각진 직업 문장 + 이름 위 + 번호 칸 · 직업 색 체력 줄 · 해제할 디버프는 테 색으로. 세로 줄로 놓여요."),
            Part("bf", "버프 · 디버프", "생명력 · 마나 위", { { "끔", "off" }, { "켬", "on" } },
                 "생명력 줄 위 = 내 버프 (무기 강화 포함) · 마나 줄 위 = 내 디버프.", true),
            { t = "button", label = "액션바 단축키 정하기 (단추에 마우스 올리고 키 누르기)",
              run = function() if ns.ABarBindMode then ns.ABarBindMode() end end },
            { t = "button", label = "모던 기본 자리로 돌리기 (액션바 · 대상 바 · 메뉴 줄 · 파티 창 · 미니맵)",
              run = function() UIMode.ResetPos(); P("모던 기본 자리로 돌렸어요.") end },
        },
    })
end

local wev = CreateFrame("Frame")
wev:RegisterEvent("PLAYER_LOGIN")
wev:SetScript("OnEvent", function()
    C_Timer.After(2, function()
        -- 개발 중: 이미 모던을 쓰는 사람은 모던 기본 자리를 한 번 입혀요
        if ns.db and (MDB().posV or 0) < 3 and not InCombatLockdown() and UIMode.Part("ab") == "tac" then
            MDB().posV = 3
            if ns.db.partyStyle ~= "modern" then ns.db.partyStyle = "modern"; ns.db.partyScale = 1; MDB().partyReload = true end
            local ok, err = pcall(UIMode.ResetPos)
            if ok then P("모던 기본 자리로 맞췄어요 (미니맵 왼쪽 위 · 메뉴 줄 오른쪽 위 · 파티 창 왼쪽).")
            else P("자리 맞추기 실패: " .. tostring(err)) end
            if MDB().partyReload then
                MDB().partyReload = nil
                P("파티 창을 모던(로아식)으로 바꿨어요. 다시 불러오기 하면 보여요.")
                Reload()
            end
        end
    end)
end)

end
