-- LeelUI / Party.lua
-- 파티 프레임 (힐러 타일): 칸이 체력만큼 직업색 파스텔로 차요
-- 민트 = 들어올 치유, 아래 얇은 줄 = 마나/분노/기력, 오른쪽 위 = 내가 건 버프, 오른쪽 아래 = 해제할 디버프
-- 상황: 35% 아래 산호 빛, 20% 아래 맥박 / 테두리 어그로 빨강, 내 대상 흰색 / 쓰러짐·유령·끊김·부활 중 / 멀리 있음(흐림)

local _, ns = ...
local C = ns.C
local Try = ns.Try

-- 칸 크기 · 사이: 허브 > 파티 프레임 > 세부 설정 (가로 · 세로 따로)
-- 모양: tile = 힐러 타일 (처음) · modern = 로아식 세로 줄 (왼쪽 각진 직업 문장 + 이름 위 + 번호 칸 체력 줄) · 다시 불러오기 후 적용
local function Modern() return ns.db and ns.db.partyStyle == "modern" end
ns.PartyModern = Modern
local function CW() if Modern() then return 300 end return tonumber(ns.db and ns.db.partyW) or 152 end
local function CH() if Modern() then return 64 end return tonumber(ns.db and ns.db.partyH) or 76 end
local function CG() if Modern() then return 12 end return tonumber(ns.db and ns.db.partyGap) or 8 end
local PAD = 8
local LOW_HP, CRIT_HP, LOW_MANA = 0.35, 0.20, 0.20
local HEALERS = { PRIEST = true, DRUID = true, SHAMAN = true, PALADIN = true }
local TILE = ns.MEDIA .. "tile"

local PCOL = {
    [0] = { 0.44, 0.55, 1.00 },   -- 마나
    [1] = { 0.88, 0.28, 0.28 },   -- 분노
    [2] = { 1.00, 0.61, 0.25 },   -- 집중
    [3] = { 1.00, 0.82, 0.12 },   -- 기력
}
local CORAL = { 1.00, 0.48, 0.40 }
-- 내가 풀 수 있는 디버프: 종류별 색 (모르면 분홍)
local DISPEL = {
    Magic = { 0.20, 0.60, 1.00 }, Curse = { 0.62, 0.30, 1.00 },
    Poison = { 0.20, 0.78, 0.30 }, Disease = { 0.88, 0.58, 0.18 },
}
local DISPEL_ANY = { 1.00, 0.56, 0.67 }
local DISPEL_ICON = {
    Magic = "Interface\\Icons\\Spell_Holy_DispelMagic", Curse = "Interface\\Icons\\Spell_Holy_RemoveCurse",
    Poison = "Interface\\Icons\\Spell_Nature_NullifyPoison", Disease = "Interface\\Icons\\Spell_Holy_NullifyDisease",
}
local MINT  = { 0.50, 0.84, 0.76 }
local RIM   = { 0.23, 0.165, 0.157 }

-- 직업색 파스텔 (블리자드 직업색을 흰색 쪽으로 섞음)
local PASTEL = {
    WARRIOR = { 0.902, 0.804, 0.690 }, PALADIN = { 0.980, 0.776, 0.863 }, HUNTER  = { 0.824, 0.910, 0.702 },
    ROGUE   = { 1.000, 0.953, 0.651 }, PRIEST  = { 0.949, 0.933, 0.914 }, SHAMAN  = { 0.651, 0.784, 0.957 },
    MAGE    = { 0.678, 0.886, 0.965 }, WARLOCK = { 0.788, 0.741, 0.918 }, DRUID   = { 1.000, 0.776, 0.604 },
    DEATHKNIGHT = { 0.933, 0.627, 0.667 }, MONK = { 0.600, 1.000, 0.820 }, DEMONHUNTER = { 0.855, 0.659, 0.929 },
    EVOKER  = { 0.580, 0.835, 0.780 },
}

----------------------------------------------------------------------
-- 직업
----------------------------------------------------------------------
local function ClassOf(u)
    local ok, _, file = pcall(UnitClass, u)
    if not ok or type(file) ~= "string" or ns.IsSecret(file) then return end
    return file
end

local function Pastel(file)
    return (file and PASTEL[file]) or C.acc
end

local CLASS_ICON = {
    WARRIOR = "cls_warrior", PALADIN = "cls_paladin", HUNTER = "cls_hunter",
    ROGUE = "cls_rogue", PRIEST = "cls_priest", SHAMAN = "cls_shaman",
    MAGE = "cls_mage", WARLOCK = "cls_warlock", DRUID = "cls_druid",
}
-- 직업 아이콘: 게임 안 와우 직업 아이콘 (동그라미 + 직업색 링)
local function ClassColor(file)
    local c = file and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
    if c then return { c.r, c.g, c.b } end
    return { 0.16, 0.09, 0.08 }
end
local function SetIcon(f, unit)
    local file = f.classFile
    f.por:SetTexCoord(0, 1, 0, 1)
    local done = false
    if file then
        -- 와우 직업 아이콘 그림 (시안 B: 네모 그림을 동그랗게)
        local nm = file:sub(1, 1) .. file:sub(2):lower()
        if file == "DEATHKNIGHT" then nm = "Deathknight" elseif file == "DEMONHUNTER" then nm = "Demonhunter" end
        local ok, r = pcall(f.por.SetTexture, f.por, "Interface\\Icons\\ClassIcon_" .. nm)
        if ok and r ~= false then f.por:SetTexCoord(0.08, 0.92, 0.08, 0.92); done = true end
    end
    if not done and file and f.por.SetAtlas then
        local ok, r = pcall(f.por.SetAtlas, f.por, "classicon-" .. file:lower())
        done = ok and r ~= false and (not f.por.GetAtlas or f.por:GetAtlas() ~= nil)
    end
    if not done and file and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[file] then
        local t = CLASS_ICON_TCOORDS[file]
        f.por:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        f.por:SetTexCoord(t[1] + 0.02, t[2] - 0.02, t[3] + 0.02, t[4] - 0.02)
        done = true
    end
    if not done then
        local own = CLASS_ICON[file or ""]
        if own then f.por:SetTexture(ns.MEDIA .. own)
        elseif unit then SetPortraitTexture(f.por, unit) end
    end
    if f.pring then
        local c = ClassColor(file)
        f.pring:SetVertexColor(c[1], c[2], c[3], 1)
    end
end

-- 역할 배지 (직업 동그라미 오른쪽 아래): 파티 찾기 역할
local ROLE_TEX = { TANK = "role_tank", HEALER = "role_heal", DAMAGER = "role_dps" }
local function SetRole(f, role)
    local t = role and ROLE_TEX[role]
    if t then f.role:SetTexture(ns.MEDIA .. t); f.role:Show() else f.role:Hide() end
    f.roleKey = role
end

-- 체력 숫자 (% 기호는 따로)
local function PctText(fs, unit, cur, max)
    local ok = pcall(function()
        if max > 0 then fs:SetFormattedText("%d", math.floor(cur / max * 100 + 0.5)) else fs:SetText("") end
    end)
    if ok then return end
    if UnitHealthPercent then
        ok = pcall(function()
            local scale = CurveConstants and CurveConstants.ScaleTo100
            fs:SetFormattedText("%.0f", UnitHealthPercent(unit, false, scale))
        end)
        if ok then return end
    end
    fs:SetText("")
end

-- 전투 중 숨겨진 체력에서도 '35% 아래'를 알 수 있게: 체력% → 빛 투명도 곡선
local LOWCURVE
local function LowCurve()
    if LOWCURVE ~= nil then return LOWCURVE or nil end
    LOWCURVE = false
    if not (C_CurveUtil and C_CurveUtil.CreateCurve) then return nil end
    local ok, c = pcall(function()
        local c = C_CurveUtil.CreateCurve()
        if c.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then c:SetType(Enum.LuaCurveType.Linear) end
        c:AddPoint(0, 1); c:AddPoint(LOW_HP - 0.005, 1); c:AddPoint(LOW_HP, 0); c:AddPoint(1, 0)
        return c
    end)
    if ok and c then LOWCURVE = c end
    return LOWCURVE or nil
end

----------------------------------------------------------------------
-- 글씨: 밝은 칸 위에서도 읽히게 외곽선
----------------------------------------------------------------------
local function OFont(parent, size, color)
    local fs = ns.Font(parent, size, color)
    fs:SetFont(ns.FONT, size, "OUTLINE")
    if ns.TrackText then ns.TrackText(fs, size, "OUTLINE") end
    fs:SetShadowColor(0.16, 0.09, 0.08, 0.9)
    fs:SetShadowOffset(1, -1)
    return fs
end
local function ONum(parent, size, color)
    local fs = ns.Num(parent, size, color)
    local file = ns.NUM
    if not fs:SetFont(file, size, "OUTLINE") then fs:SetFont(ns.FONT, size, "OUTLINE") end
    fs:SetShadowColor(0.16, 0.09, 0.08, 0.9)
    fs:SetShadowOffset(1, -1)
    return fs
end

----------------------------------------------------------------------
-- 오라 (블리자드 애드온용 오라 컨테이너)
----------------------------------------------------------------------
local DSIZE, BSIZE = 22, 16   -- 해제할 디버프는 조금 크게
local function InitAura(size, shape)
    return function(btn)
        btn:SetSize(size, size)
        local black = btn:CreateTexture(nil, "BACKGROUND")
        black:SetTexture(ns.MEDIA .. shape); black:SetVertexColor(0.11, 0.08, 0.07, 1)
        black:SetPoint("TOPLEFT", -1.5, 1.5); black:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local m = btn:CreateMaskTexture()
        m:SetTexture(ns.MEDIA .. shape, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(icon)
        icon:AddMaskTexture(m)
        btn:SetIcon(icon)
    end
end

local function AuraBox(f, key, filter, max, size, shape, point, x, y)
    local ok, cont = pcall(CreateFrame, "AuraContainer", nil, f.top, "CustomAuraContainerTemplate")
    if not ok or not cont then return end
    local ok2 = pcall(function()
        cont:SetPoint(point, f, point, x, y)
        if cont.SetFlowLayoutAnchorPoint then cont:SetFlowLayoutAnchorPoint(point) end
        if cont.SetFlowLayoutGrowthDirection and AnchorUtil and AnchorUtil.FlowDirection then
            cont:SetFlowLayoutGrowthDirection(point:find("LEFT") and AnchorUtil.FlowDirection.Right or AnchorUtil.FlowDirection.Left,
                point:find("TOP") and AnchorUtil.FlowDirection.Down or AnchorUtil.FlowDirection.Up)
        end
        cont:AddAuraGroup(key, filter, {
            maxFrameCount = max,
            sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.Expiration or 0,
            sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal or 0,
            initializeFrame = InitAura(size, shape),
            layout = { elementSpacing = 3, elementWidth = size, elementHeight = size },
        })
        cont:SetUnit(f.unit)
    end)
    if ok2 then
        cont:SetFrameLevel(f.top:GetFrameLevel() + 1)
        return cont
    end
end

----------------------------------------------------------------------
-- 한 칸 (타일)
----------------------------------------------------------------------
local function TileTex(parent, layer, sub, c, a)
    local t = parent:CreateTexture(nil, layer, nil, sub or 0)
    t:SetTexture(TILE)
    t:SetVertexColor(c[1], c[2], c[3], a or 1)
    return t
end

local function MaskedBar(f, level)
    local b = CreateFrame("StatusBar", nil, f)
    b:SetFrameLevel(level)
    b:SetStatusBarTexture(ns.WHITE)
    b:SetMinMaxValues(0, 1); b:SetValue(0)
    b:GetStatusBarTexture():AddMaskTexture(f.mask)
    return b
end

-- 모던 (로아식): 왼쪽 각진 직업 문장 + 금 꺾쇠 · 위 이름 · 번호 칸 + 직업 색 체력 줄 · 아래 자원 줄 · 오른쪽 밖 해제할 디버프
function ns.PartyModernSkin(f)
    f.modern = true
    local MASK = ns.MEDIA .. "ab_tac_mask"
    local EM, BX = 46, 56
    f.sh:Hide(); f.shine:Hide(); f.stripes:SetAlpha(0.35)
    local area = CreateFrame("Frame", nil, f)
    area:SetPoint("TOPLEFT", f, "TOPLEFT", BX, -18); area:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -18); area:SetHeight(22)
    f.area = area
    f.mask:ClearAllPoints()
    f.mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    f.mask:SetAllPoints(area)
    f.hp:ClearAllPoints(); f.hp:SetAllPoints(area)
    f.bg:SetTexture(MASK); f.bg:ClearAllPoints(); f.bg:SetAllPoints(area); f.bg:SetVertexColor(0.04, 0.04, 0.05, 0.92)
    f.rim:SetTexture(MASK); f.rim:ClearAllPoints()
    f.rim:SetPoint("TOPLEFT", area, "TOPLEFT", -2, 2); f.rim:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", 2, -2)
    f.glow:ClearAllPoints(); f.glow:SetPoint("TOPLEFT", area, -14, 12); f.glow:SetPoint("BOTTOMRIGHT", area, 14, -12)
    -- 자원 줄: 체력 줄 아래 (틀 밖이라 가림 빼기)
    pcall(f.pw:GetStatusBarTexture().RemoveMaskTexture, f.pw:GetStatusBarTexture(), f.mask)
    pcall(f.pbg.RemoveMaskTexture, f.pbg, f.mask)
    f.pw:ClearAllPoints()
    f.pw:SetPoint("TOPLEFT", area, "BOTTOMLEFT", 0, -3); f.pw:SetPoint("TOPRIGHT", area, "BOTTOMRIGHT", 0, -3); f.pw:SetHeight(4)
    -- 눈금 (액션바와 같은 느낌)
    f.ticks = {}
    for k = 1, 9 do
        local t = f.top:CreateTexture(nil, "ARTWORK"); t:SetColorTexture(1, 1, 1, 0.22); t:SetSize(1, (k % 5 == 0) and 4 or 2)
        f.ticks[k] = t
    end
    area:SetScript("OnSizeChanged", function(a, w)
        for k, t in ipairs(f.ticks) do t:ClearAllPoints(); t:SetPoint("TOP", a, "BOTTOMLEFT", (w or a:GetWidth()) * k / 10, -9) end
    end)
    -- 번호 칸 (금)
    local idx = CreateFrame("Frame", nil, f.top); idx:SetSize(22, 22); idx:SetPoint("TOPLEFT", area, "TOPLEFT", 0, 0)
    local ib = idx:CreateTexture(nil, "ARTWORK"); ib:SetAllPoints(); ib:SetColorTexture(0.91, 0.75, 0.38, 1)
    idx.t = idx:CreateFontString(nil, "OVERLAY"); idx.t:SetFont(ns.NUM or ns.FONT, 13, ""); idx.t:SetTextColor(0.1, 0.08, 0.07); idx.t:SetPoint("CENTER", 0, 0)
    f.mIdx = idx
    -- 직업 문장: 각진 네모 · 테 = 직업 색 · 금 꺾쇠
    f.pf:ClearAllPoints(); f.pf:SetSize(EM, EM); f.pf:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -9)
    f.pout:SetTexture(MASK); f.pout:SetVertexColor(0, 0, 0, 0.6)
    f.pring:SetTexture(MASK); f.pring:ClearAllPoints(); f.pring:SetPoint("TOPLEFT", 0, 0); f.pring:SetPoint("BOTTOMRIGHT", 0, 0)
    local inner = f.pf:CreateTexture(nil, "BACKGROUND", nil, 2); inner:SetTexture(MASK); inner:SetVertexColor(0.07, 0.07, 0.08, 1)
    inner:SetPoint("TOPLEFT", 2, -2); inner:SetPoint("BOTTOMRIGHT", -2, 2)
    f.por:ClearAllPoints(); f.por:SetPoint("TOPLEFT", 4, -4); f.por:SetPoint("BOTTOMRIGHT", -4, 4)
    f.pmask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    local G = { 0.91, 0.75, 0.38 }
    for _, c in ipairs({ { "TOPLEFT", -4, 4 }, { "BOTTOMRIGHT", 4, -4 } }) do
        local h = f.top:CreateTexture(nil, "OVERLAY"); h:SetColorTexture(G[1], G[2], G[3], 1); h:SetSize(10, 2); h:SetPoint(c[1], f.pf, c[1], c[2], c[3])
        local v = f.top:CreateTexture(nil, "OVERLAY"); v:SetColorTexture(G[1], G[2], G[3], 1); v:SetSize(2, 10); v:SetPoint(c[1], f.pf, c[1], c[2], c[3])
    end
    f.lead:ClearAllPoints(); f.lead:SetPoint("CENTER", f.pf, "TOPLEFT", 2, 2)
    -- 이름 (체력 줄 위) · 마나 부족은 이름 줄 오른쪽
    f.name:ClearAllPoints(); f.name:SetPoint("BOTTOMLEFT", area, "TOPLEFT", 2, 3)
    f.name:SetWidth(170); f.name:SetFont(ns.FONT, 13, "OUTLINE")
    f.mana:ClearAllPoints(); f.mana:SetPoint("BOTTOMRIGHT", area, "TOPRIGHT", 0, 3)
    -- 체력 글씨: 줄 안 오른쪽
    f.pct:ClearAllPoints(); f.pct:SetPoint("RIGHT", area, "RIGHT", -6, 0); f.pct:SetFont(ns.NUM or ns.FONT, 10, "OUTLINE")
    f.val:ClearAllPoints(); f.val:SetPoint("RIGHT", f.pct, "LEFT", -1, 0); f.val:SetFont(ns.NUM or ns.FONT, 13, "OUTLINE")
    f.state:ClearAllPoints(); f.state:SetPoint("LEFT", area, "LEFT", 30, 0)
    -- 해제할 디버프: 테 색으로 (세로 줄은 안 씀) · 디버프 칸은 줄 오른쪽 밖
    f.dspBar:SetAlpha(0)
    local FW = (f.unit ~= "player") and 36 or 0   -- 따라가기 배지 자리
    f.dspRF:ClearAllPoints(); f.dspRF:SetPoint("CENTER", f, "TOPRIGHT", 8 + FW + DSIZE / 2, -18 - 11)
    if f.debuffs then pcall(function()
        f.debuffs:ClearAllPoints(); f.debuffs:SetPoint("LEFT", f, "TOPRIGHT", 8 + FW, -29)
        if f.debuffs.SetFlowLayoutAnchorPoint then f.debuffs:SetFlowLayoutAnchorPoint("LEFT") end
    end) end
    if f.buffs then pcall(function()
        f.buffs:ClearAllPoints(); f.buffs:SetPoint("TOPRIGHT", area, "BOTTOMRIGHT", 0, -14)
    end) end
    if FW > 0 and not f.preview then ns.PartyFollowBadge(f, area) end
end

-- 따라가기 배지 (대상 초상화와 같은 두 사람 배지): 체력 줄 오른쪽 끝 · 누르면 따라가기
--  평소 흐리게 · 따라가는 사람은 두 사람이 콩콩 + 분홍 점선 고리가 빙글 + 이름 옆 "따라가는 중"
local followBadges = {}
local function FirstWord(n) if type(n) ~= "string" then return nil end; return (n:gsub("%-.*$", ""):match("^(%S+)")) end
local function PaintFollow(f)
    local b = f.follow
    if not b then return end
    local fn = ns.FollowName and ns.FollowName()
    local on = false
    if fn and UnitExists(f.unit) then
        local ok, r = pcall(function() local n = UnitName(f.unit); return n == fn or (FirstWord(n) ~= nil and FirstWord(n) == FirstWord(fn)) end)
        on = ok and r or false
    end
    if on ~= b.liveOn then
        b.liveOn = on
        b.bt:SetShown(not on); b.live:SetShown(on); b.liveT = 0
    end
    b:SetAlpha(on and 1 or 0.6)
    f.folTag:SetShown(on)
end
function ns.PartyFollowBadge(f, area)
    local b = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
    b:SetSize(30, 30); b:SetPoint("LEFT", area, "RIGHT", 6, 0)
    b:SetFrameLevel(f:GetFrameLevel() + 10)
    b:SetAttribute("type", "macro"); b:SetAttribute("macrotext", "/follow " .. f.unit)
    local down = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")
    b:RegisterForClicks(down and "AnyDown" or "AnyUp")
    b.bt = b:CreateTexture(nil, "OVERLAY"); b.bt:SetTexture(ns.MEDIA .. "follow_badge"); b.bt:SetAllPoints()
    local live = CreateFrame("Frame", nil, b); live:SetAllPoints(); live:Hide(); b.live = live
    local lbg = live:CreateTexture(nil, "ARTWORK"); lbg:SetTexture(ns.MEDIA .. "follow_bg"); lbg:SetAllPoints()
    local p2 = live:CreateTexture(nil, "OVERLAY", nil, 1); p2:SetTexture(ns.MEDIA .. "follow_p2"); p2:SetAllPoints()
    local p1 = live:CreateTexture(nil, "OVERLAY", nil, 2); p1:SetTexture(ns.MEDIA .. "follow_p1"); p1:SetAllPoints()
    local ring = live:CreateTexture(nil, "OVERLAY", nil, 3); ring:SetTexture(ns.MEDIA .. "follow_ring"); ring:SetAllPoints()
    b.liveT = 0
    live:SetScript("OnUpdate", function(_, el)
        b.liveT = b.liveT + el
        local w = (b:GetWidth() or 30) / 44
        local y1 = 2.5 * w * math.abs(math.sin(b.liveT * math.pi / 0.32))
        local y2 = 2.5 * w * math.abs(math.sin(b.liveT * math.pi / 0.32 + math.pi / 2))
        p1:ClearAllPoints(); p1:SetPoint("TOPLEFT", b, "TOPLEFT", 0, y1); p1:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, y1)
        p2:ClearAllPoints(); p2:SetPoint("TOPLEFT", b, "TOPLEFT", 0, y2); p2:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, y2)
        ring:SetRotation(-b.liveT * 2 * math.pi / 2.4)
    end)
    b:HookScript("PreClick", function() local ok, n = pcall(UnitName, f.unit); if ok and ns.FollowPending then ns.FollowPending(n) end end)
    b:SetScript("OnEnter", function(self)
        b:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); ns.TAdd(GameTooltip, "따라가기", 1, 0.84, 0.88)
        ns.TAdd(GameTooltip, "Alt + 클릭도 돼요 · 움직이면 멈춰요", 0.75, 0.68, 0.66); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide(); PaintFollow(f) end)
    f.follow = b
    -- 이름 옆 "따라가는 중"
    local tg = CreateFrame("Frame", nil, f.top); tg:SetHeight(14)
    local tb = tg:CreateTexture(nil, "ARTWORK"); tb:SetAllPoints(); tb:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 1)
    tg.t = tg:CreateFontString(nil, "OVERLAY"); tg.t:SetFont(ns.FONT, 10, ""); tg.t:SetTextColor(0.1, 0.07, 0.08); tg.t:SetPoint("CENTER", 0, 0)
    tg.t:SetText("따라가는 중"); tg:SetWidth((tg.t:GetStringWidth() or 50) + 10)
    tg:SetPoint("BOTTOMRIGHT", area, "TOPRIGHT", 0, 3); tg:Hide()
    f.folTag = tg
    followBadges[#followBadges + 1] = f
    PaintFollow(f)
end
do
    local fe = CreateFrame("Frame")
    for _, e in ipairs({ "AUTOFOLLOW_BEGIN", "AUTOFOLLOW_END", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do fe:RegisterEvent(e) end
    fe:SetScript("OnEvent", function() C_Timer.After(0, function() for _, f in ipairs(followBadges) do PaintFollow(f) end end) end)
end

local function CreateMember(parent, i, unit, preview)
    unit = unit or ("party" .. i)
    -- preview = 허브 미리 보기용 모형 (이름 없는 보통 프레임 · 클릭 · 이벤트 없음, 생김새는 진짜와 같아요)
    local f = preview and CreateFrame("Frame", nil, parent)
        or CreateFrame("Button", unit == "player" and "LeelUI_partyMe" or ("LeelUI_party" .. i), parent, "SecureUnitButtonTemplate")
    f.unit = unit
    f.preview = preview
    f:SetSize(CW(), CH())
    if not preview then
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    if unit ~= "player" then   -- Alt + 클릭 = 이 파티원 따라가기
        f:SetAttribute("alt-type1", "macro")
        f:SetAttribute("alt-macrotext1", "/follow " .. unit)
    end
    f:HookScript("PreClick", function(s2) if IsAltKeyDown() and ns.FollowPending then local ok, n = pcall(UnitName, s2.unit or unit); if ok then ns.FollowPending(n) end end end)
    f:RegisterForClicks("AnyUp")
    end

    -- 바깥 빛 (체력 낮음): 테두리 바깥이라 흰/빨강 테두리와 같이 보임
    f.glow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    f.glow:SetTexture(ns.MEDIA .. "tile_glow")
    f.glow:SetPoint("TOPLEFT", -18, 16); f.glow:SetPoint("BOTTOMRIGHT", 18, -16)
    f.glow:SetVertexColor(CORAL[1], CORAL[2], CORAL[3], 1)
    f.glow:SetAlpha(0)
    f.pulse = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    f.pulse:SetTexture(ns.MEDIA .. "tile_glow")
    f.pulse:SetAllPoints(f.glow)
    f.pulse:SetVertexColor(1, 0.3, 0.2, 1)
    local ag = f.pulse:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(0.1); a:SetToAlpha(0.9); a:SetDuration(0.55); a:SetSmoothing("IN_OUT")
    f.pulse:SetScript("OnShow", function() ag:Play() end)
    f.pulse:SetScript("OnHide", function() ag:Stop() end)
    f.pulse:Hide()

    -- 그림자, 테두리, 바탕
    local sh = TileTex(f, "BACKGROUND", -6, { 0, 0, 0 }, 0.45); f.sh = sh
    sh:SetPoint("TOPLEFT", 0, -3); sh:SetPoint("BOTTOMRIGHT", 0, -5)
    f.rim = TileTex(f, "BACKGROUND", -5, RIM, 1)
    f.rim:SetPoint("TOPLEFT", -2, 2); f.rim:SetPoint("BOTTOMRIGHT", 2, -2)
    local bg = TileTex(f, "BACKGROUND", -4, { 0.102, 0.075, 0.07 }, 0.96)
    bg:SetAllPoints(); f.bg = bg

    f.mask = f:CreateMaskTexture()
    f.mask:SetTexture(TILE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    f.mask:SetAllPoints(f)

    local lv = f:GetFrameLevel()
    -- 체력 (직업색)
    f.hp = MaskedBar(f, lv + 1)
    f.hp:SetAllPoints()
    -- 들어올 치유: 체력 끝에서 이어서, 칸 밖으로 넘치는 건 둥근 틀에 잘림
    f.heal = MaskedBar(f, lv + 1)
    f.heal:SetSize(CW(), CH())
    f.heal:SetPoint("TOPLEFT", f.hp:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    f.heal:SetStatusBarColor(MINT[1], MINT[2], MINT[3], 0.7)
    local stripes = f.heal:CreateTexture(nil, "OVERLAY")
    stripes:SetTexture(ns.MEDIA .. "stripes", "REPEAT", "REPEAT")
    stripes:SetHorizTile(true); stripes:SetVertTile(true)
    stripes:SetAllPoints(f.heal:GetStatusBarTexture())
    stripes:SetVertexColor(1, 1, 1, 0.25)
    stripes:AddMaskTexture(f.mask); f.stripes = stripes
    -- 위쪽 윤기
    local shine = f.hp:CreateTexture(nil, "OVERLAY")
    shine:SetTexture(ns.WHITE)
    shine:SetAllPoints(f)
    shine:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.10), CreateColor(1, 1, 1, 0.16))
    shine:AddMaskTexture(f.mask); f.shine = shine

    -- 해제할 디버프 (D안): 칸 왼쪽 가장자리 세로 줄 + 디버프 아이콘 둘레 링 맥박 (직업색 칸은 그대로)
    local dsp = CreateFrame("Frame", nil, f)
    dsp:SetAllPoints(); dsp:SetFrameLevel(lv + 5)
    f.dspBar = dsp:CreateTexture(nil, "OVERLAY")
    f.dspBar:SetTexture(ns.WHITE); f.dspBar:SetWidth(4)
    f.dspBar:SetPoint("TOPLEFT", 0, -7); f.dspBar:SetPoint("BOTTOMLEFT", 0, 7)
    local rf = CreateFrame("Frame", nil, dsp)
    rf:SetSize(DSIZE + 12, DSIZE + 12)
    rf:SetPoint("CENTER", f, "BOTTOMLEFT", PAD + DSIZE / 2, PAD + 4 + DSIZE / 2)
    rf:SetFrameLevel(lv + 3); f.dspRF = rf   -- 디버프 아이콘 밑에 (링이 아이콘보다 커서 둘레만 보여요)
    f.dspRing = rf:CreateTexture(nil, "OVERLAY")
    f.dspRing:SetTexture(ns.MEDIA .. "ring"); f.dspRing:SetAllPoints()
    f.dspGlow = rf:CreateTexture(nil, "BORDER")
    f.dspGlow:SetTexture(ns.MEDIA .. "circle"); f.dspGlow:SetBlendMode("ADD")
    f.dspGlow:SetPoint("TOPLEFT", -6, 6); f.dspGlow:SetPoint("BOTTOMRIGHT", 6, -6)
    local dag = rf:CreateAnimationGroup(); dag:SetLooping("BOUNCE")
    local sc = dag:CreateAnimation("Scale"); sc:SetDuration(0.5); sc:SetSmoothing("IN_OUT")
    if sc.SetScaleFrom then sc:SetScaleFrom(1, 1); sc:SetScaleTo(1.18, 1.18) else sc:SetFromScale(1, 1); sc:SetToScale(1.18, 1.18) end
    local da = dag:CreateAnimation("Alpha"); da:SetFromAlpha(0.5); da:SetToAlpha(1); da:SetDuration(0.5); da:SetSmoothing("IN_OUT")
    f.dspAg = dag
    local bag = f.dspBar:CreateAnimationGroup(); bag:SetLooping("BOUNCE")
    local ba = bag:CreateAnimation("Alpha"); ba:SetFromAlpha(0.45); ba:SetToAlpha(1); ba:SetDuration(0.5); ba:SetSmoothing("IN_OUT")
    f.dspGag = bag
    f.dspFrame = dsp
    dsp:Hide()

    -- 아래 자원 줄
    f.pw = MaskedBar(f, lv + 2)
    f.pw:SetPoint("BOTTOMLEFT"); f.pw:SetPoint("BOTTOMRIGHT"); f.pw:SetHeight(4)
    local pbg = f.pw:CreateTexture(nil, "BACKGROUND")
    pbg:SetTexture(ns.WHITE); pbg:SetAllPoints(); pbg:SetVertexColor(0.08, 0.06, 0.055, 0.85)
    pbg:AddMaskTexture(f.mask); f.pbg = pbg

    -- 글씨·아이콘 층
    local top = CreateFrame("Frame", nil, f)
    top:SetAllPoints()
    top:SetFrameLevel(lv + 4)
    f.top = top

    local pf = CreateFrame("Frame", nil, top)
    pf:SetSize(28, 28)   -- 직업 아이콘 (시안 B: 크게)
    f.pf = pf
    pf:SetPoint("TOPLEFT", PAD, -PAD + 1)
    local pout = pf:CreateTexture(nil, "BACKGROUND", nil, -1)
    pout:SetTexture(ns.MEDIA .. "circle"); pout:SetVertexColor(0.11, 0.07, 0.06, 0.95)
    pout:SetPoint("TOPLEFT", -4, 4); pout:SetPoint("BOTTOMRIGHT", 4, -4); f.pout = pout
    local pring = pf:CreateTexture(nil, "BACKGROUND")
    pring:SetTexture(ns.MEDIA .. "circle"); pring:SetVertexColor(0.16, 0.09, 0.08, 0.9)
    pring:SetPoint("TOPLEFT", -2.5, 2.5); pring:SetPoint("BOTTOMRIGHT", 2.5, -2.5)
    f.pring = pring
    f.por = pf:CreateTexture(nil, "ARTWORK")
    f.por:SetAllPoints()
    local pm = pf:CreateMaskTexture()
    pm:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    pm:SetAllPoints(f.por)
    f.por:AddMaskTexture(pm); f.pmask = pm
    local rlf = CreateFrame("Frame", nil, pf)   -- 직업 아이콘보다 위 층 (안 그러면 아이콘 뒤로 가려져요)
    rlf:SetAllPoints(pf); rlf:SetFrameLevel(pf:GetFrameLevel() + 3)
    f.role = rlf:CreateTexture(nil, "OVERLAY", nil, 4)
    f.role:SetSize(16, 16)
    f.role:SetPoint("CENTER", pf, "BOTTOMRIGHT", -2, 2)
    f.role:Hide()

    f.name = OFont(top, 14)
    f.name:SetPoint("LEFT", pf, "RIGHT", 5, 0)
    f.name:SetWidth(CW() - PAD * 2 - 33 - 56)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)

    -- 체력 숫자: 오른쪽 아래 끝 · % 는 숫자 바로 뒤 (디버프는 왼쪽 아래, 해제 줄 옆)
    f.pct = ONum(top, 13)
    f.pct:SetText("%")
    f.pct:SetPoint("BOTTOMRIGHT", top, "BOTTOMRIGHT", -PAD, PAD + 3)
    f.val = ONum(top, 26)
    f.val:SetPoint("BOTTOMRIGHT", f.pct, "BOTTOMLEFT", -1, -2)

    -- 쓰러짐 / 유령 / 끊김
    f.state = OFont(top, 15, { 0.78, 0.70, 0.67 })
    f.state:SetPoint("BOTTOMRIGHT", -PAD - 24, PAD + 3)
    f.state:Hide()
    f.mid = top:CreateTexture(nil, "OVERLAY")
    f.mid:SetSize(20, 20)
    f.mid:SetPoint("LEFT", f.state, "RIGHT", 4, 0)
    f.mid:Hide()

    -- 힐러 마나 부족
    f.mana = OFont(top, 11, { 0.68, 0.76, 1 })
    f.mana:SetPoint("BOTTOMRIGHT", f.pct, "TOPRIGHT", 0, 3)   -- 체력 숫자 위
    f.mana:Hide()

    -- 파티장 왕관 (왼쪽 위 모서리)
    f.lead = top:CreateTexture(nil, "OVERLAY", nil, 2)
    f.lead:SetTexture(ns.MEDIA .. "crown")
    f.lead:SetSize(18, 18)
    f.lead:SetPoint("CENTER", top, "TOPLEFT", 6, -2)
    f.lead:SetRotation(math.rad(18))
    f.lead:Hide()

    -- 내가 건 버프 (오른쪽 위), 해제할 디버프 (오른쪽 아래)
    if not preview then
    f.buffs = AuraBox(f, "leelMine", "HELPFUL|PLAYER", 3, BSIZE, "mm_squircle", "TOPRIGHT", -PAD + 2, -PAD + 2)
    f.debuffs = AuraBox(f, "leelDispel", "HARMFUL|RAID", 2, DSIZE, "mm_squircle", "BOTTOMLEFT", PAD, PAD + 4)
    end
    if Modern() then ns.PartyModernSkin(f) end
    return f
end

----------------------------------------------------------------------
-- 갱신
----------------------------------------------------------------------
local function UpdateHeal(f)
    local u = f.unit
    if not UnitExists(u) or f.gone then f.heal:SetValue(0) return end
    local inc = UnitGetIncomingHeals and select(2, pcall(UnitGetIncomingHeals, u)) or nil
    pcall(f.heal.SetMinMaxValues, f.heal, 0, UnitHealthMax(u))
    if inc == nil or not pcall(f.heal.SetValue, f.heal, inc) then f.heal:SetValue(0) end
end

local function UpdateHealth(f)
    local u = f.unit
    if not UnitExists(u) then return end
    local dead = Try(UnitIsDeadOrGhost, u)
    local ghost = dead and Try(UnitIsGhost, u)
    local off = not Try(UnitIsConnected, u)
    local gone = dead or off
    f.gone = gone

    f.por:SetDesaturated(gone)
    f.por:SetVertexColor(gone and 0.55 or 1, gone and 0.55 or 1, gone and 0.55 or 1)

    if gone then
        f.hp:SetValue(0); f.heal:SetValue(0); f.pw:SetValue(0)
        f.glow:SetAlpha(0); f.pulse:Hide()
        f.val:Hide(); f.pct:SetText(""); f.mana:Hide()
        f.state:SetText(off and "접속 끊김" or (ghost and "유령" or "쓰러짐"))
        f.state:Show()
        f.name:SetTextColor(0.72, 0.66, 0.64)
        local res = not off and UnitHasIncomingResurrection and Try(UnitHasIncomingResurrection, u)
        if res then
            f.mid:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez"); f.mid:SetVertexColor(0.62, 1, 0.66); f.mid:Show()
        elseif dead then
            f.mid:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull"); f.mid:SetVertexColor(1, 1, 1); f.mid:Show()
        else
            f.mid:Hide()
        end
        return
    end

    f.mid:Hide(); f.state:Hide()
    f.val:Show(); f.pct:SetText("%")
    local col = f.modern and ClassColor(f.classFile) or Pastel(f.classFile)
    if f.modern and not f.classFile then col = C.acc end
    if f.modern then f.name:SetTextColor(col[1], col[2], col[3]) else f.name:SetTextColor(1, 0.97, 0.955) end
    f.hp:SetStatusBarColor(col[1], col[2], col[3], f.modern and 1 or 0.9)

    local cur, max = UnitHealth(u), UnitHealthMax(u)
    ns.SetBar(f.hp, cur, max)
    -- 체력 글씨: % (기본) · 숫자 · 잃은 만큼 · 없음
    local mode = ns.db and ns.db.partyHp or "pct"
    if mode == "none" then
        f.val:Hide(); f.pct:SetText("")
    elseif mode == "num" then
        f.pct:SetText(""); ns.SetText(f.val, cur)
    elseif mode == "deficit" then
        f.pct:SetText("")
        local okD = pcall(function()
            local miss = max - cur
            if miss > 0 then f.val:SetFormattedText("-%d", miss) else f.val:SetText("") end
        end)
        if not okD then
            local okM = UnitHealthMissing and pcall(function() f.val:SetFormattedText("-%d", UnitHealthMissing(u)) end)
            if not okM then PctText(f.val, u, cur, max); f.pct:SetText("%") end
        end
    else
        PctText(f.val, u, cur, max)
    end

    local okp, p = pcall(function() if max > 0 then return cur / max end return 1 end)
    if okp and type(p) == "number" then
        f.glow:SetAlpha(p < LOW_HP and 1 or 0)
        f.pulse:SetShown(p < CRIT_HP)
        local lc = p < LOW_HP and { 1, 0.83, 0.80 } or { 1, 0.97, 0.955 }
        f.val:SetTextColor(lc[1], lc[2], lc[3]); f.pct:SetTextColor(lc[1], lc[2], lc[3])
    else
        -- 전투 중 숨겨진 값: 곡선으로 빛만 (맥박은 생략)
        f.pulse:Hide()
        local lc = LowCurve()
        local ok = lc and UnitHealthPercent and pcall(function() f.glow:SetAlpha(UnitHealthPercent(u, false, lc)) end)
        if not ok then f.glow:SetAlpha(0) end
        f.val:SetTextColor(1, 0.97, 0.955); f.pct:SetTextColor(1, 0.97, 0.955)
    end
    UpdateHeal(f)
end

local function UpdatePower(f)
    local u = f.unit
    if not UnitExists(u) then return end
    if f.gone then f.pw:SetValue(0); f.mana:Hide(); return end
    local pt = UnitPowerType(u)
    if ns.IsSecret(pt) then pt = 0 end
    local c = PCOL[pt] or PCOL[0]
    f.pw:SetStatusBarColor(c[1], c[2], c[3], 1)
    local cur, max = UnitPower(u, pt), UnitPowerMax(u, pt)
    ns.SetBar(f.pw, cur, max)
    local okp, p = pcall(function() if max > 0 then return cur / max end end)
    if pt == 0 and okp and type(p) == "number" and p < LOW_MANA and HEALERS[f.classFile or ""] then
        f.mana:SetFormattedText("마나 %d%%", math.floor(p * 100 + 0.5))
        f.mana:Show()
    else
        f.mana:Hide()
    end
end

local function UpdateInfo(f)
    local u = f.unit
    if not UnitExists(u) then return end
    f.classFile = ClassOf(u)
    local nm = UnitName(u)
    local lim = tonumber(ns.db and ns.db.partyNameLen) or 0
    if lim > 0 and nm and not ns.IsSecret(nm) then
        -- 한글도 글자 단위로 자르기
        local out, n = {}, 0
        for ch in nm:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            n = n + 1
            if n > lim then out[#out + 1] = "…"; break end
            out[#out + 1] = ch
        end
        nm = table.concat(out)
    end
    ns.SetText(f.name, nm)
    -- 블랙리스트 (주사위 창 토끼 단추): 빨간 테 + 표시
    local raw = UnitName(u)
    f.blackOn = raw and not ns.IsSecret(raw) and ns.IsBlack and ns.IsBlack(raw) or false
    if f.blackOn and not f.blackIc then
        local b = f:CreateTexture(nil, "OVERLAY", nil, 6)
        b:SetTexture(ns.MEDIA .. "roll_ban"); b:SetSize(14, 14); b:SetPoint("TOPRIGHT", -4, -4)
        b:SetVertexColor(1, 0.42, 0.5)
        f.blackIc = b
    end
    if f.blackIc then f.blackIc:SetShown(f.blackOn and true or false) end
    SetIcon(f, u)
    local okR, role = pcall(UnitGroupRolesAssigned, u)
    SetRole(f, (okR and type(role) == "string" and not ns.IsSecret(role)) and role or nil)
    f.lead:SetShown(Try(UnitIsGroupLeader, u))
end

-- 테두리: 어그로 빨강 > 내 대상 흰색 > 평소 진한 갈색
local function PaintRim(f)
    if f.modern and f.dspCol and not f.aggroOn then
        f.rim:SetVertexColor(f.dspCol[1], f.dspCol[2], f.dspCol[3], 1)
    elseif f.modern and not (f.aggroOn or f.selOn or f.blackOn) then
        f.rim:SetVertexColor(1, 1, 1, 0.14)
    elseif f.aggroOn then
        f.rim:SetVertexColor(1, 0.35, 0.35, 1)
    elseif f.selOn then
        f.rim:SetVertexColor(1, 0.953, 0.965, 1)
    elseif f.blackOn then
        f.rim:SetVertexColor(1, 0.42, 0.5, 1)
    elseif f.unit == "player" then
        f.rim:SetVertexColor(1, 0.70, 0.76, 1)   -- 내 칸: 분홍 테
    else
        f.rim:SetVertexColor(RIM[1], RIM[2], RIM[3], 1)
    end
end

function ns.PartyBlackRefresh()
    local members = ns.partyMembers
    if not members then return end
    for _, f in ipairs(members) do if f.unit and UnitExists(f.unit) then UpdateInfo(f); PaintRim(f) end end
end

local function UpdateThreat(f)
    local ok, s = pcall(UnitThreatSituation, f.unit)
    f.aggroOn = ok and Try(function() return s and s >= 2 end)
    PaintRim(f)
end

local function UpdateTarget(f)
    f.selOn = Try(UnitIsUnit, f.unit, "target")
    PaintRim(f)
end

local function UpdateRange(f)
    local u = f.unit
    if u == "player" then f:SetAlpha(1) return end
    if not UnitExists(u) then return end
    local ok, inRange, checked = pcall(UnitInRange, u)
    if not ok then f:SetAlpha(1) return end
    if ns.IsSecret(inRange) or ns.IsSecret(checked) then
        if f.SetAlphaFromBoolean then
            if not pcall(f.SetAlphaFromBoolean, f, inRange, 1, 0.42) then f:SetAlpha(1) end
        else
            f:SetAlpha(1)
        end
        return
    end
    f:SetAlpha((inRange or not checked) and 1 or 0.42)
end

-- 해제할 디버프 표시 켜기/끄기 (col = 색, nil = 끄기)
local function ShowDispel(f, col)
    if col then
        f.dspBar:SetVertexColor(col[1], col[2], col[3], 1)
        f.dspRing:SetVertexColor(col[1], col[2], col[3], 1)
        f.dspGlow:SetVertexColor(col[1], col[2], col[3], 0.55)
        if not f.dspFrame:IsShown() then f.dspFrame:Show(); f.dspAg:Play(); f.dspGag:Play() end
    else
        f.dspAg:Stop(); f.dspGag:Stop(); f.dspFrame:Hide()
    end
    f.dspCol = col
end

-- 내가 풀 수 있는 디버프가 있나 · 있으면 그 종류
--   1) 게임이 디버프 종류를 알려 주면 그 색
--   2) 숨겨진 값이면 "있다"만 (분홍)
--   3) 그것도 못 읽으면 디버프 칸에 뭔가 떠 있나로
local function DispelOf(unit, box)
    local found, typ = false, nil
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 8 do
            local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL|RAID")
            if not ok or type(a) ~= "table" or ns.IsSecret(a) then break end
            found = true
            local okD, dn = pcall(function() return a.dispelName end)
            if not okD then dn = nil end
            if dn and not ns.IsSecret(dn) and DISPEL[dn] then typ = dn; break end
        end
    end
    local secretShown, hasSecret = nil, false
    if not found and box then
        local ok, kids = pcall(function() return { box:GetChildren() } end)
        if ok then
            for _, c in ipairs(kids) do
                local okS, sh = pcall(c.IsShown, c)
                if okS then
                    if ns.IsSecret(sh) then
                        -- 숨겨진 값: 비교는 못 하고, 첫 칸이 보이는지를 그대로 빛 투명도에 넘겨요
                        if not hasSecret then secretShown, hasSecret = sh, true end
                    elseif sh then found = true; break end
                end
            end
        end
    end
    if found then return true, typ, false, nil end
    return false, typ, hasSecret, secretShown   -- 숨긴 값은 비교 · 참거짓 검사 없이 그대로 넘겨요
end

local function UpdateDispel(f)
    if ns.party and ns.party.preview then return end
    if not UnitExists(f.unit) or f.gone or (ns.db and ns.db.partyDispelFx == false) then ShowDispel(f, nil); PaintRim(f) return end
    local found, typ, hasSecret, secret = DispelOf(f.unit, f.debuffs)
    if hasSecret then
        ShowDispel(f, DISPEL_ANY)
        if not (f.dspFrame.SetAlphaFromBoolean and pcall(f.dspFrame.SetAlphaFromBoolean, f.dspFrame, secret, 1, 0)) then ShowDispel(f, nil) end
    else
        f.dspFrame:SetAlpha(1)
        ShowDispel(f, found and (DISPEL[typ] or DISPEL_ANY) or nil)
    end
    PaintRim(f)
end

local function UpdateAuras(f)
    if f.debuffs then pcall(f.debuffs.UpdateAllAuras, f.debuffs) end
    if f.buffs then pcall(f.buffs.UpdateAllAuras, f.buffs) end
    C_Timer.After(0, function() UpdateDispel(f) end)
end

local function UpdateAll(f)
    if not UnitExists(f.unit) then return end
    UpdateInfo(f)
    UpdateHealth(f)
    UpdatePower(f)
    UpdateThreat(f)
    UpdateTarget(f)
    UpdateRange(f)
    UpdateAuras(f)
end

----------------------------------------------------------------------
-- 배치 (가로 줄 / 세로 줄 / 2x2)
----------------------------------------------------------------------
local LAYOUTS = { "row", "col", "grid" }
ns.PARTY_LAYOUT_NAMES = { row = "가로 줄", col = "세로 줄", grid = "2×2" }

local function Five() return ns.db and ns.db.partyFive == true end

-- 내 칸 보이기: 5인일 때 파티 중에만
local function ApplyMeDriver()
    local me = ns.partyMe
    if not me or (ns.party and ns.party.preview) then return end
    ns:RunOutOfCombat("partyMe", function()
        UnregisterStateDriver(me, "visibility")
        RegisterStateDriver(me, "visibility", Five() and "[group] show; hide" or "hide")
    end)
end

local function Layout(pbox, pmembers, pme)
    local box, members = pbox or ns.party, pmembers or ns.partyMembers
    if not box then return end
    local run = pbox and function(_, fn) fn() end or function(_, fn) ns:RunOutOfCombat("partyLayout", fn) end
    run(nil, function()
        local mode = Modern() and "col" or (ns.db.partyLayout or "row")
        local W, H, G = CW(), CH(), CG()
        local party, me = {}, pbox and pme or ns.partyMe
        for i = 1, 4 do party[i] = members[i] end
        local list = {}
        if Five() and me then
            if ns.db.partyMePos == "bottom" then
                for _, f in ipairs(party) do list[#list + 1] = f end; list[#list + 1] = me
            else
                list[1] = me; for _, f in ipairs(party) do list[#list + 1] = f end
            end
        else
            list = party
        end
        for _, f in ipairs(members) do f:SetSize(W, H); f.heal:SetSize(W, H) end
        for i, f in ipairs(list) do if f.mIdx then f.mIdx.t:SetText(i) end end
        local n = #list
        if mode == "grid" and n == 5 then
            -- 2×2 + 넓은 칸 하나: 탱커가 있으면 탱커, 없으면 나
            local wide = me
            for _, f in ipairs(party) do
                if f.roleKey == "TANK" and (box.preview or UnitExists(f.unit)) then wide = f break end
            end
            local rest = {}
            for _, f in ipairs(list) do if f ~= wide then rest[#rest + 1] = f end end
            local bottomWide = ns.db.partyMePos == "bottom" and wide == me
            wide:SetSize(W * 2 + G, H); wide.heal:SetSize(W * 2 + G, H)
            wide:ClearAllPoints()
            wide:SetPoint("TOPLEFT", box, "TOPLEFT", 0, bottomWide and -2 * (H + G) or 0)
            for i, f in ipairs(rest) do
                local cx, cy = (i - 1) % 2, math.floor((i - 1) / 2) + (bottomWide and 0 or 1)
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", box, "TOPLEFT", cx * (W + G), -cy * (H + G))
            end
            box:SetSize(2 * W + G, 3 * H + 2 * G)
            return
        end
        for i, f in ipairs(list) do
            local cx, cy
            if mode == "col" then cx, cy = 0, i - 1
            elseif mode == "grid" then cx, cy = (i - 1) % 2, math.floor((i - 1) / 2)
            else cx, cy = i - 1, 0 end
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", box, "TOPLEFT", cx * (W + G), -cy * (H + G))
        end
        local cols = mode == "col" and 1 or (mode == "grid" and 2 or n)
        local rows = mode == "col" and n or (mode == "grid" and math.ceil(n / 2) or 1)
        box:SetSize(cols * W + (cols - 1) * G, rows * H + (rows - 1) * G)
    end)
end
ns.PartyLayout = function() Layout() end

function ns:ApplyPartyFive()
    ApplyMeDriver()
    Layout()
    if ns.partyMe and not (ns.party and ns.party.preview) then
        C_Timer.After(0.1, function() if ns.partyMe:IsShown() then ns.PartyUpdateAll(ns.partyMe) end end)
    end
end

-- 세부 설정 적용: 칸 크기 · 이름 칸 · 글씨 크기 · 버프 칸 (전투 중이면 끝나고)
function ns:ApplyPartyCells()
    local members = ns.partyMembers
    if not members then return end
    ns:RunOutOfCombat("partyCells", function()
        local W, H = CW(), CH()
        local auras = ns.db.partyAuras ~= false
        for _, f in ipairs(members) do
            f:SetSize(W, H)
            f.heal:SetSize(W, H)
            if not f.modern then
            f.name:SetWidth(math.max(30, W - PAD * 2 - 33 - (auras and 56 or 0)))
            local vs = math.max(14, math.min(26, math.floor(H * 0.34)))
            f.val:SetFont(ns.NUM, vs, "OUTLINE")
            end
            if f.buffs then f.buffs:SetShown(auras) end
            if f.debuffs then f.debuffs:SetShown(auras) end
            if not ns.party.preview then UpdateAll(f) end
        end
        Layout()
    end)
end

function ns:CyclePartyLayout()
    local cur = ns.db.partyLayout or "row"
    local nxt = LAYOUTS[1]
    for i, m in ipairs(LAYOUTS) do
        if m == cur then nxt = LAYOUTS[i % #LAYOUTS + 1] end
    end
    ns.db.partyLayout = nxt
    Layout()
    if InCombatLockdown() then ns.Print("전투가 끝나면 파티 배치가 바뀌어요.") end
end

function ns:ApplyPartyPosition()
    local box = ns.party
    if not box then return end
    ns:RunOutOfCombat("partyPos", function()
        local p = ns.db.partyPoint
        box:ClearAllPoints()
        box:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end)
end

function ns:SetPartyScale(v)
    local box = ns.party
    if not box then ns.db.partyScale = v return end
    ns:RunOutOfCombat("partyScale", function()
        local cx, cy = box:GetCenter()
        local s0 = box:GetScale()
        box:SetScale(v)
        ns.db.partyScale = v
        if cx then
            ns.db.partyPoint = { "CENTER", "BOTTOMLEFT", math.floor(cx * s0 / v + 0.5), math.floor(cy * s0 / v + 0.5) }
            ns:ApplyPartyPosition()
        end
    end)
end

function ns:ResetPartyPosition()
    ns.db.partyPoint = CopyTable(ns.defaults.partyPoint)
    ns:ApplyPartyPosition()
end

----------------------------------------------------------------------
-- 기본 파티 창 숨기기
----------------------------------------------------------------------
local hidden = CreateFrame("Frame")
hidden:Hide()
local function HideBlizzardParty()
    if InCombatLockdown() then return end
    local list = { PartyFrame, CompactPartyFrame }
    for i = 1, 4 do list[#list + 1] = _G["PartyMemberFrame" .. i] end
    -- 새 게임 판: 파티원 칸은 PartyFrame 안 틀 묶음(풀)에서 나와요 → 그 칸들도 신호를 끊어야
    --   숨겨 둔 기본 칸이 체력 신호를 받다가 "secret number" 오류를 내지 않아요
    local pf = _G.PartyFrame
    if pf then
        if pf.PartyMemberFramePool and pf.PartyMemberFramePool.EnumerateActive then
            pcall(function() for m in pf.PartyMemberFramePool:EnumerateActive() do list[#list + 1] = m end end)
        end
        for i = 1, 4 do local m = pf["MemberFrame" .. i]; if m then list[#list + 1] = m end end
        pcall(function() for _, c in ipairs({ pf:GetChildren() }) do list[#list + 1] = c end end)
    end
    for _, fr in pairs(list) do
        if fr then
            pcall(fr.UnregisterAllEvents, fr)
            pcall(fr.Hide, fr)
            if fr == pf or fr == _G.CompactPartyFrame or (fr.GetName and fr:GetName() and fr:GetName():find("^PartyMemberFrame%d$")) then
                pcall(fr.SetParent, fr, hidden)
            end
        end
    end
    -- 기본 창이 파티 칸을 새로 만들면 그 칸도 다시 끊어요 (한 번만 걸어요)
    if pf and pf.UpdatePartyFrames and not hidden.leelHooked then
        hidden.leelHooked = true
        hooksecurefunc(pf, "UpdatePartyFrames", function(self)
            if not (ns.db and ns.db.partyHideBlizzard ~= false) then return end
            if self.PartyMemberFramePool and self.PartyMemberFramePool.EnumerateActive then
                for m in self.PartyMemberFramePool:EnumerateActive() do pcall(m.UnregisterAllEvents, m); pcall(m.Hide, m) end
            end
        end)
    end
end

----------------------------------------------------------------------
-- 이동 모드: 예시 파티 + 분홍 테두리 드래그
----------------------------------------------------------------------
local FAKE = {
    -- 이름, 직업, 체력, 자원종류, 자원, 어그로, 파티장, 들어올 치유
    { "든든곰",   "WARRIOR", 0.71, 1, 0.38, false, true,  0.12, "Magic",   "TANK" },
    { "눈꽃별",   "MAGE",    0.24, 0, 0.80, false, false, 0.30, "Curse",   "DAMAGER" },
    { "보라밤",   "WARLOCK", 0.93, 0, 0.55, false, false, 0,    "Poison",  "DAMAGER" },
    { "달빛사냥", "HUNTER",  1.00, 0, 0.90, false, false, 0,    "Disease", "DAMAGER" },
    { "나",       "PRIEST",  0.94, 0, 0.80, false, false, 0,    nil,       "HEALER" },
}

local function Fake(f, d)
    local name, file, hp, pt, pw, agg, lead, inc = unpack(d)
    f.classFile, f.gone = file, false
    if f.unit == "player" then
        local okN, nm = pcall(UnitName, "player"); if okN and nm and not ns.IsSecret(nm) then name = nm end
        local okC, _, cf = pcall(UnitClass, "player"); if okC and cf and not ns.IsSecret(cf) then file = cf; f.classFile = cf end
    end
    SetRole(f, d[10])
    f.name:SetText(name); f.name:SetTextColor(1, 0.97, 0.955)
    f.por:SetDesaturated(false); f.por:SetVertexColor(1, 1, 1)
    SetIcon(f)
    f.mid:Hide(); f.state:Hide(); f.val:Show(); f.pct:SetText("%")
    local col = Pastel(file)
    f.hp:SetStatusBarColor(col[1], col[2], col[3], 0.9)
    f.hp:SetMinMaxValues(0, 1); f.hp:SetValue(hp)
    f.heal:SetMinMaxValues(0, 1); f.heal:SetValue(inc or 0)
    f.val:SetFormattedText("%d", math.floor(hp * 100 + 0.5))
    local low = hp < LOW_HP
    local lc = low and { 1, 0.83, 0.80 } or { 1, 0.97, 0.955 }
    f.val:SetTextColor(lc[1], lc[2], lc[3]); f.pct:SetTextColor(lc[1], lc[2], lc[3])
    f.glow:SetAlpha(low and 1 or 0)
    f.pulse:SetShown(hp < CRIT_HP)
    local c = PCOL[pt]
    f.pw:SetStatusBarColor(c[1], c[2], c[3], 1); f.pw:SetMinMaxValues(0, 1); f.pw:SetValue(pw)
    f.mana:Hide()
    f.aggroOn, f.selOn = agg, false
    -- 해제 디버프 시험: 칸마다 다른 종류
    local box = ns.party
    local typ = box and box.dispelTest and d[9]
    ShowDispel(f, typ and DISPEL[typ] or nil)
    if not f.fakeDeb then
        local fd = f.top:CreateTexture(nil, "OVERLAY", nil, 3)
        fd:SetSize(DSIZE, DSIZE); fd:SetPoint("BOTTOMRIGHT", -PAD + 2, PAD + 4)
        fd:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local fm = f.top:CreateMaskTexture()
        fm:SetTexture(ns.MEDIA .. "mm_squircle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); fm:SetAllPoints(fd)
        fd:AddMaskTexture(fm)
        f.fakeDeb = fd
        f.fakeDebTxt = OFont(f.top, 11)
        f.fakeDebTxt:SetPoint("RIGHT", fd, "LEFT", -8, 0)
    end
    if typ then
        f.fakeDeb:SetTexture(DISPEL_ICON[typ]); f.fakeDeb:Show()
        f.fakeDebTxt:SetText(({ Magic = "마법", Curse = "저주", Poison = "독", Disease = "질병" })[typ])
        local c = DISPEL[typ]; f.fakeDebTxt:SetTextColor(c[1] * 0.5 + 0.5, c[2] * 0.5 + 0.5, c[3] * 0.5 + 0.5); f.fakeDebTxt:Show()
    else
        f.fakeDeb:Hide(); f.fakeDebTxt:Hide()
    end
    PaintRim(f)
    f.lead:SetShown(lead)
    f:SetAlpha(1)
end

-- 허브 미리 보기: 진짜 파티 칸과 똑같이 생긴 모형 (가짜 파티원 · 설정 그대로)
function ns.BuildPartyPreview(parent)
    local box = CreateFrame("Frame", nil, parent)
    box.preview = true
    local members = {}
    for i = 1, 4 do members[i] = CreateMember(box, i, nil, true) end
    local me = CreateMember(box, 5, "player", true)
    members[5] = me
    box.members = members   -- 허브 미리 보기 강조에 써요
    function box:Refresh()
        local W, H = CW(), CH()
        for i, f in ipairs(members) do
            f:SetSize(W, H); f.heal:SetSize(W, H)
            f.name:SetWidth(math.max(30, W - PAD * 2 - 33))
            local vs = math.max(14, math.min(26, math.floor(H * 0.34)))
            f.val:SetFont(ns.NUM, vs, "OUTLINE")
            pcall(Fake, f, FAKE[i])
            f:Show()
        end
        me:SetShown(Five())
        Layout(box, { members[1], members[2], members[3], members[4], me }, me)
        self:SetScale(ns.db.partyScale or 0.75)
    end
    box:Refresh()
    return box
end

local function CreatePartyMover(box)
    local m = CreateFrame("Frame", nil, box)
    m:SetPoint("TOPLEFT", -6, 6); m:SetPoint("BOTTOMRIGHT", 6, -6)
    m:SetFrameStrata("DIALOG")
    m:EnableMouse(true)
    m:RegisterForDrag("LeftButton")
    local tint = m:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints()
    tint:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.07)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = m:CreateTexture(nil, "BORDER")
        e:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 1)
        if side == "TOP" or side == "BOTTOM" then
            e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(3)
        else
            e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(3)
        end
    end
    local label = ns.Font(m, 13, C.accHi)
    label:SetText("파티 프레임")
    label:SetPoint("BOTTOMLEFT", m, "TOPLEFT", 4, 4)
    if ns.MoveSizeHook then ns.MoveSizeHook(m, "파티 프레임 크기", "파티 프레임") end

    m:SetScript("OnDragStart", function()
        if not InCombatLockdown() then box:StartMoving() end
    end)
    m:SetScript("OnDragStop", function()
        box:StopMovingOrSizing()
        local x, y = box:GetCenter()
        if ns.db.grid then
            x = math.floor(x / 8 + 0.5) * 8
            y = math.floor(y / 8 + 0.5) * 8
        end
        ns.db.partyPoint = { "CENTER", "BOTTOMLEFT", math.floor(x + 0.5), math.floor(y + 0.5) }
        ns:ApplyPartyPosition()
    end)
    m:Hide()
    return m
end

function ns:SetPartyPreview(on)
    local box, members = ns.party, ns.partyMembers
    if not box then return end
    if on then
        if InCombatLockdown() then return end
        box.preview = true
        UnregisterStateDriver(box, "visibility")
        box:Show()
        for i, f in ipairs(members) do
            if f == ns.partyMe then
                UnregisterStateDriver(f, "visibility")
                f:SetShown(Five())
            else
                UnregisterUnitWatch(f)
                f:Show()
            end
            Fake(f, FAKE[i])
        end
        Layout()
        box.mover:Show()
    else
        box.preview = false
        box.dispelTest = false
        box.mover:Hide()
        for _, f in ipairs(members) do if f.fakeDeb then f.fakeDeb:Hide(); f.fakeDebTxt:Hide() end end
        ns:RunOutOfCombat("partyPreview", function()
            RegisterStateDriver(box, "visibility", "[group:raid] hide; show")
            for _, f in ipairs(members) do if f ~= ns.partyMe then RegisterUnitWatch(f) end end
        end)
        ApplyMeDriver()
        Layout()
        for _, f in ipairs(members) do UpdateAll(f) end
    end
end

----------------------------------------------------------------------
-- 만들기 + 이벤트
----------------------------------------------------------------------
function ns:CreateParty()
    if ns.party then return end
    if ns.db.partyHideBlizzard ~= false then HideBlizzardParty() end

    local box = CreateFrame("Frame", "LeelUI_Party", UIParent, "SecureHandlerStateTemplate")
    box:SetMovable(true)
    box:SetClampedToScreen(true)
    box:SetScale(ns.db.partyScale or 0.75)
    ns.party = box
    ns:ApplyPartyPosition()
    RegisterStateDriver(box, "visibility", "[group:raid] hide; show")

    local members = {}
    for i = 1, 4 do
        local f = CreateMember(box, i)
        members[i] = f
        RegisterUnitWatch(f)
        f:HookScript("OnShow", function(self) if not box.preview then UpdateAll(self) end end)

        local ev = CreateFrame("Frame")
        for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER",
                             "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_PORTRAIT_UPDATE",
                             "UNIT_MODEL_CHANGED", "UNIT_CONNECTION", "UNIT_FLAGS",
                             "UNIT_THREAT_SITUATION_UPDATE", "INCOMING_RESURRECT_CHANGED",
                             "UNIT_HEAL_PREDICTION", "UNIT_AURA" }) do
            pcall(ev.RegisterUnitEvent, ev, e, f.unit)
        end
        ev:SetScript("OnEvent", function(_, event)
            if box.preview then return end
            if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS"
               or event == "UNIT_CONNECTION" or event == "INCOMING_RESURRECT_CHANGED" then
                UpdateHealth(f)
                if event ~= "UNIT_HEALTH" then UpdatePower(f) end
            elseif event == "UNIT_HEAL_PREDICTION" then
                UpdateHeal(f)
            elseif event == "UNIT_AURA" then
                C_Timer.After(0, function() UpdateDispel(f) end)
            elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
                UpdateThreat(f)
            elseif event == "UNIT_NAME_UPDATE" or event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
                UpdateInfo(f); UpdateHealth(f)
            else
                UpdatePower(f)
            end
        end)
    end
    -- 내 칸 (5인)
    do
        local f = CreateMember(box, 5, "player")
        members[5] = f
        ns.partyMe = f
        f:HookScript("OnShow", function(self) if not box.preview then UpdateAll(self) end end)
        local ev = CreateFrame("Frame")
        for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER",
                             "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_FLAGS", "UNIT_THREAT_SITUATION_UPDATE",
                             "UNIT_HEAL_PREDICTION", "UNIT_AURA" }) do
            pcall(ev.RegisterUnitEvent, ev, e, "player")
        end
        ev:SetScript("OnEvent", function(_, event)
            if box.preview or not f:IsShown() then return end
            if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS" then UpdateHealth(f); UpdatePower(f)
            elseif event == "UNIT_HEAL_PREDICTION" then UpdateHeal(f)
            elseif event == "UNIT_THREAT_SITUATION_UPDATE" then UpdateThreat(f)
            elseif event == "UNIT_AURA" then C_Timer.After(0, function() UpdateDispel(f) end)
            elseif event == "UNIT_NAME_UPDATE" then UpdateInfo(f)
            else UpdatePower(f) end
        end)
        ApplyMeDriver()
    end
    ns.partyMembers = members
    ns.PartyUpdateAll = UpdateAll
    box.mover = CreatePartyMover(box)
    Layout()
    ns:ApplyPartyCells()

    local gev = CreateFrame("Frame")
    gev:RegisterEvent("GROUP_ROSTER_UPDATE")
    gev:RegisterEvent("PLAYER_ENTERING_WORLD")
    gev:RegisterEvent("PARTY_LEADER_CHANGED")
    gev:RegisterEvent("PLAYER_TARGET_CHANGED")
    pcall(gev.RegisterEvent, gev, "PLAYER_ROLES_ASSIGNED")
    gev:SetScript("OnEvent", function(_, event)
        if box.preview then return end
        for _, f in ipairs(members) do
            if event == "PLAYER_TARGET_CHANGED" then UpdateTarget(f) else UpdateAll(f) end
        end
        if event ~= "PLAYER_TARGET_CHANGED" and Five() and (ns.db.partyLayout == "grid") then Layout() end
        if event == "PLAYER_ENTERING_WORLD" and ns.db.partyHideBlizzard ~= false then HideBlizzardParty() end
    end)

    -- 사거리: 0.3초마다
    local t = 0
    box:HookScript("OnUpdate", function(_, el)
        t = t + el
        if t < 0.3 or box.preview then return end
        t = 0
        for _, f in ipairs(members) do
            if f:IsShown() then UpdateRange(f) end
        end
    end)
end


-- 점검: /르엘파티
SLASH_LEELPARTYDBG1 = "/르엘파티"
SlashCmdList.LEELPARTYDBG = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "해제" or msg == "테스트" then
        local box = ns.party
        if not box then return end
        if box.preview and box.dispelTest then
            ns:SetPartyPreview(false)
            print(ns.L("|cfff2b3c2[르엘 파티]|r 해제 디버프 시험을 끝냈어요."))
        else
            if InCombatLockdown() then print(ns.L("|cfff2b3c2[르엘 파티]|r 전투가 끝나고 해 주세요.")) return end
            box.dispelTest = true
            ns:SetPartyPreview(true)
            print(ns.L("|cfff2b3c2[르엘 파티]|r 해제 디버프 시험: 마법(파랑) · 저주(보라) · 독(초록) · 질병(주황). 끄기 = /르엘파티 해제"))
        end
        return
    end
    if msg == "해제검사" then
        for i, f in ipairs(ns.partyMembers or {}) do
            if UnitExists(f.unit) then
                local found, typ, hasSecret = DispelOf(f.unit, f.debuffs)
                print(ns.L("|cfff2b3c2[르엘 파티]|r %d번: 해제할 디버프 %s · 종류 %s"):format(i, hasSecret and "(숨김 값)" or tostring(found), tostring(typ or "모름")))
            end
        end
        return
    end
    local inc = UnitGetIncomingHeals and select(2, pcall(UnitGetIncomingHeals, "player"))
    print("|cfff2b3c2[르엘 파티]|r 들어올치유함수=" .. tostring(UnitGetIncomingHeals ~= nil) ..
        " 값=" .. (ns.IsSecret(inc) and "<숨김>" or tostring(inc)) ..
        "  체력%곡선=" .. tostring(LowCurve() ~= nil) .. "  오라상자=" .. tostring(ns.partyMembers and ns.partyMembers[1] and ns.partyMembers[1].buffs ~= nil))
end

----------------------------------------------------------------------
-- 파티 찾기: 신청한 사람 위치 알약 (게임이 주는 지역 · 없으면 레벨대 /누구 한 번으로 채우기)
--   같은 지역 = 초록 · 그 던전 안 = 분홍 · 그 밖 = 회색 · 못 찾음 = 표시 없음
----------------------------------------------------------------------
do
    local whoLoc = {}        -- [이름] = { area, t }
    local function Short(n) return type(n) == "string" and (n:gsub("%-.*$", "")) or nil end
    local function Secret(v) return issecretvalue and issecretvalue(v) end
    local function PlayerInfo(id)
        if not (C_LFGList and C_LFGList.GetSearchResultPlayerInfo) then return end
        local ok, info = pcall(C_LFGList.GetSearchResultPlayerInfo, id, 1)
        if ok and type(info) == "table" then return info end
    end
    local function AreaOf(id)
        local info = PlayerInfo(id)
        if not info then return end
        local name = info.name
        if Secret(name) then return end
        local area = info.areaName
        if Secret(area) then area = nil end
        if (not area or area == "") and name then
            local w = whoLoc[Short(name)]
            if w and GetTime() - w.t < 300 then area = w.area end
        end
        return area, Short(name), info.level
    end
    local function DungeonName(id)
        local ok, r = pcall(C_LFGList.GetSearchResultInfo, id)
        if not (ok and type(r) == "table") then return end
        local aid = r.activityID or (r.activityIDs and r.activityIDs[1])
        if aid and C_LFGList.GetActivityInfoTable then
            local ok2, a = pcall(C_LFGList.GetActivityInfoTable, aid)
            if ok2 and type(a) == "table" then return a.fullName or a.shortName, a.shortName end
        end
    end
    -- 이름 글씨 찾기: 줄 안 글자 중 그 사람 이름으로 시작하는 것
    local function NameFS(f, name, depth)
        for _, r in ipairs({ f:GetRegions() }) do
            if r:GetObjectType() == "FontString" then
                local t = r:GetText()
                if type(t) == "string" and not Secret(t) then
                    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", "")
                    if t:find(name, 1, true) == 1 then return r end
                end
            end
        end
        if (depth or 0) < 2 then
            for _, c in ipairs({ f:GetChildren() }) do
                local fs = NameFS(c, name, (depth or 0) + 1); if fs then return fs end
            end
        end
    end
    -- 던전 → 입구가 있는 지역 (이름 일부로 찾아요)
    local ENTRANCE = {
        { "붉은십자군", "티리스팔 숲" }, { "죽음의 폐광", "서부 몰락지대" }, { "통곡의 동굴", "불모의 땅" },
        { "그림자송곳니", "은빛소나무 숲" }, { "스톰윈드 지하감옥", "스톰윈드" }, { "검은심연", "잿빛 골짜기" },
        { "놈리건", "던 모로" }, { "가시덩굴", "불모의 땅" }, { "성난불길", "오그리마" }, { "울다만", "황야의 땅" },
        { "줄파락", "타나리스" }, { "마라우돈", "잊혀진 땅" }, { "아탈학카르", "슬픔의 늪" }, { "가라앉은 사원", "슬픔의 늪" },
        { "검은바위", "이글거리는 협곡" }, { "혈투의 전장", "페랄라스" }, { "스칼로맨스", "서부 역병지대" },
        { "스트라솔름", "동부 역병지대" },
    }
    local function EntranceOf(dn)
        if type(dn) ~= "string" then return end
        for _, e in ipairs(ENTRANCE) do if dn:find(e[1], 1, true) then return e[2] end end
    end
    -- E안(막대 없이): 둘째 줄 던전 이름 옆 "· 지역" + 셋째 줄(배우기 · 여유로움) 옆 거리 말 (같은 곳 · 던전 안 · 입구 · 멀리)
    local function Pill(entry)
        if entry.leelLoc then return entry.leelLoc end
        local p = { fs = ns.Font(entry, 11.5, { 0.72, 0.67, 0.69 }), tag = ns.Font(entry, 11.5, { 0.72, 0.67, 0.69 }) }
        function p:Hide() self.fs:Hide(); self.tag:Hide() end
        function p:Show() self.fs:Show(); self.tag:Show() end
        entry.leelLoc = p
        return p
    end
    -- 셋째 줄 글씨: 던전 이름 글씨 바로 아래 · 왼쪽이 비슷한 것
    local function MemoFS(entry, dfs)
        if not dfs then return end
        local dl, db = dfs:GetLeft(), dfs:GetBottom()
        if not (dl and db) or Secret(dl) or Secret(db) then return end
        local best, bd
        local function Look(f, d)
            for _, r in ipairs({ f:GetRegions() }) do
                if r:GetObjectType() == "FontString" and r ~= dfs and r:IsShown() and r ~= entry.leelLoc.fs and r ~= entry.leelLoc.tag then
                    local l, t = r:GetLeft(), r:GetTop()
                    if l and t and not Secret(l) and not Secret(t) and math.abs(l - dl) < 12 and t <= db + 2 then
                        local dist = db - t
                        if not bd or dist < bd then best, bd = r, dist end
                    end
                end
            end
            if d < 2 then for _, c in ipairs({ f:GetChildren() }) do Look(c, d + 1) end end
        end
        Look(entry, 0)
        return best
    end
    local Paint
    Paint = function(entry, here)
        local id = entry.resultID
        if type(id) ~= "number" then return end
        local area, name = AreaOf(id)
        local p = entry.leelLoc
        -- 내 등록 줄은 빼요 (이름이 같거나 · 앞이 같거나 · "내 등록 사항" 글자가 있는 줄)
        if entry.leelMineId ~= id then
            local me = UnitName and UnitName("player")
            me = me and not Secret(me) and Short(me) or nil
            local mine = me and name and (name == me or name:find(me, 1, true) == 1 or me:find(name, 1, true) == 1) or false
            if not mine then mine = (NameFS(entry, ns.L("내 등록")) or NameFS(entry, "내 등록")) and true or false end
            entry.leelMine, entry.leelMineId = mine, id
            entry.leelDgFS, entry.leelMemoFS = nil, nil
        end
        if not (area and area ~= "" and name) or entry.leelMine then if p then p:Hide() end return end
        p = Pill(entry)
        local dn = DungeonName(id)
        local inDg = dn and (area == dn or dn:find(area, 1, true) or area:find(dn, 1, true))
        local ent = EntranceOf(dn)
        local col, tag
        if area == here then col, tag = { 0.56, 0.91, 0.6 }, "같은 곳"
        elseif inDg then col, tag = C.acc, "던전 안"
        elseif ent and area == ent then col, tag = { 0.94, 0.83, 0.54 }, "입구"
        else col, tag = { 0.66, 0.6, 0.63 }, "멀리" end
        p.fs:SetTextColor(col[1], col[2], col[3]); p.fs:SetText("· " .. (inDg and ns.L("던전 안") or area))
        p.tag:SetTextColor(col[1], col[2], col[3]); p.tag:SetText(ns.L(tag))
        -- 둘째 줄 던전 이름 글씨
        local dfs = entry.leelDgFS
        if not dfs and dn then
            local _, sn = DungeonName(id)
            dfs = NameFS(entry, dn) or (sn and NameFS(entry, sn))
            local w1 = dn:match("^(%S+)")
            if not dfs and w1 then dfs = NameFS(entry, w1) end     -- "붉은십자군 수도원: 무기고" ↔ "붉은십자군 무기고"
            entry.leelDgFS = dfs
        end
        local function After(fs, target, gap)
            local w = 100
            pcall(function() local x = target:GetStringWidth(); if type(x) == "number" and not Secret(x) then w = x end end)
            fs:ClearAllPoints(); fs:SetPoint("LEFT", target, "LEFT", w + gap, 0)
        end
        if dfs then After(p.fs, dfs, 5) else p.fs:ClearAllPoints(); p.fs:SetPoint("BOTTOMRIGHT", entry, "BOTTOMRIGHT", -14, 6) end
        local mfs = entry.leelMemoFS
        if not (mfs and mfs:IsShown()) then mfs = MemoFS(entry, dfs); entry.leelMemoFS = mfs end
        if mfs and type(mfs:GetText()) == "string" and mfs:GetText() ~= "" then After(p.tag, mfs, 10); p.tag:Show()
        elseif dfs then p.tag:ClearAllPoints(); p.tag:SetPoint("TOPLEFT", dfs, "BOTTOMLEFT", 0, -3); p.tag:Show()
        else p.tag:Hide() end
        p.fs:Show()
    end
    local function Walk(f, here, depth)
        for _, c in ipairs({ f:GetChildren() }) do
            if c.resultID and c:IsVisible() then pcall(Paint, c, here)
            elseif depth < 8 then Walk(c, here, depth + 1) end
        end
    end
    local function Root() return _G.LFGBrowseFrame end
    -- 레벨대 /누구 한 번: 지역을 안 주는 사람만 채워요 (검색을 누른 그 순간에만 · 게임 규칙)
    local whoBusy, lastWho = false, 0
    local function WhoFill()
        if whoBusy or GetTime() - lastWho < 8 then return end
        if not (C_FriendList and C_FriendList.SendWho and C_LFGList and C_LFGList.GetSearchResults) then return end
        local ok, ids = pcall(C_LFGList.GetSearchResults)
        if not ok or type(ids) ~= "table" then return end
        local lo, hi, need = 999, 0, 0
        for _, id in ipairs(ids) do
            local info = PlayerInfo(id)
            if info and not Secret(info.name) and not (info.areaName and not Secret(info.areaName) and info.areaName ~= "") then
                local w = whoLoc[Short(info.name)]
                if not (w and GetTime() - w.t < 300) and type(info.level) == "number" and not Secret(info.level) then
                    need = need + 1; lo = math.min(lo, info.level); hi = math.max(hi, info.level)
                end
            end
        end
        if need == 0 then return end
        if hi - lo > 10 then lo = hi - 10 end
        whoBusy, lastWho = true, GetTime()
        local ff = _G.FriendsFrame
        if ff then pcall(ff.UnregisterEvent, ff, "WHO_LIST_UPDATE") end
        pcall(C_FriendList.SetWhoToUi, true)
        pcall(C_FriendList.SendWho, lo .. "-" .. hi)
        C_Timer.After(6, function()      -- 답이 안 오면 원래대로
            if whoBusy then whoBusy = false; if ff then pcall(ff.RegisterEvent, ff, "WHO_LIST_UPDATE") end; pcall(C_FriendList.SetWhoToUi, false) end
        end)
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("WHO_LIST_UPDATE")
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:SetScript("OnEvent", function(_, e)
        if e == "PLAYER_LOGIN" then
            if C_LFGList and C_LFGList.Search then
                hooksecurefunc(C_LFGList, "Search", function() if ns.db and ns.db.lfgLoc ~= false then WhoFill() end end)
            end
            return
        end
        if not whoBusy then return end
        whoBusy = false
        local n = C_FriendList.GetNumWhoResults and C_FriendList.GetNumWhoResults() or 0
        for i = 1, n do
            local ok, w = pcall(C_FriendList.GetWhoInfo, i)
            if ok and type(w) == "table" and w.fullName and not Secret(w.fullName) and w.area and not Secret(w.area) then
                whoLoc[Short(w.fullName)] = { area = w.area, t = GetTime() }
            end
        end
        local ff = _G.FriendsFrame
        if ff then C_Timer.After(0, function() pcall(ff.RegisterEvent, ff, "WHO_LIST_UPDATE") end) end
        pcall(C_FriendList.SetWhoToUi, false)
    end)
    -- 목록이 보이는 동안 0.5초마다 알약 다시 그리기
    local tick, acc = CreateFrame("Frame"), 0
    tick:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc < 0.5 then return end
        acc = 0
        if ns.db and ns.db.lfgLoc == false then return end
        local r = Root()
        if not (r and r:IsVisible()) then return end
        local here = GetRealZoneText and GetRealZoneText() or ""
        pcall(Walk, r, here, 0)
    end)
end
