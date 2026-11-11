-- LeelUI / ActionBars.lua
-- 르엘 액션바 (시험): 판 없는 둥둥 바 + 토끼 메뉴 버튼
--  * 블리자드 액션 버튼은 그대로 쓰고(부모도 그대로 → 드루이드 변신 쪽 바뀜 정상) 자리·모양만 바꿔요
--  * 바 테·사자 조각상·나무 판은 투명하게, 메뉴 버튼·가방 칸은 숨기고 토끼 메뉴로
--  * 자리 옮기기·크기 바꾸기는 전투 밖에서만 (전투 중엔 끝나고 적용)

local _, ns = ...
local C = ns.C

local BASE_SIZE, GAP, BASE_PET = 40, 6, 34
local SIZE, PET = BASE_SIZE, BASE_PET

local function DB()
    ns.db.abar = ns.db.abar or {}
    local d = ns.db.abar
    if d.on == nil then d.on = false end
    -- 처음 켰을 때 기본값 = 슈엘 화면 (화면 아래 가운데, 액션바 80%, 토끼 메뉴 80%)
    if d.scale == nil then d.scale = 80 end
    if d.mscale == nil then d.mscale = 80 end
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
        -- 둥근 알약: 모서리 원 4개로 만든 판 (짧아도 양끝이 둥글게)
        ns.RoundPlate(pill, 7, { 0.788, 0.42, 0.51, 1 }, { 0.788, 0.42, 0.51, 1 })   -- 장미 알약
        if round then pill:SetPoint("CENTER", b, "TOP", 0, 0) else pill:SetPoint("CENTER", b, "TOPRIGHT", -4, -1) end
        hk:SetParent(pill)
        hk:ClearAllPoints(); hk:SetPoint("CENTER", pill, "CENTER", 0, 0)
        hk:SetJustifyH("CENTER")
        pcall(hk.SetFont, hk, ns.NUM or ns.FONT, 10, "")
        hk:SetTextColor(1, 0.953, 0.965)
        hk:SetShadowColor(0, 0, 0, 0)
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

local function Layout()
    if not holder or not DB().on then return end
    if InCombatLockdown() then pending = true return end
    local sc = (DB().scale or 100) / 100
    SIZE = math.floor(BASE_SIZE * sc + 0.5)
    PET = math.floor(BASE_PET * sc + 0.5)
    placing = true
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
        GameTooltip:AddLine("Shift + 끌기로 옮기기", 0.85, 0.78, 0.76)
        GameTooltip:Show()
    end)
    launcher:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Shift 누른 채 끌면 토끼 메뉴 옮기기 (전투 밖에서만)
    launcher:RegisterForDrag("LeftButton")
    launcher:SetScript("OnDragStart", function()
        if IsShiftKeyDown() and not InCombatLockdown() then
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
    if msg == "켜기" or msg == "on" then
        DB().on = true; P("켰어요. /reload 하면 적용돼요.")
        return
    elseif msg == "끄기" or msg == "off" then
        DB().on = false; P("껐어요. /reload 하면 원래 바로 돌아가요.")
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
