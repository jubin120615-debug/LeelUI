-- LeelUI / Party.lua
-- 파티 프레임 (힐러 타일): 칸이 체력만큼 직업색 파스텔로 차요
-- 민트 = 들어올 치유, 아래 얇은 줄 = 마나/분노/기력, 오른쪽 위 = 내가 건 버프, 오른쪽 아래 = 해제할 디버프
-- 상황: 35% 아래 산호 빛, 20% 아래 맥박 / 테두리 어그로 빨강, 내 대상 흰색 / 쓰러짐·유령·끊김·부활 중 / 멀리 있음(흐림)

local _, ns = ...
local C = ns.C
local Try = ns.Try

local CELL_W, CELL_H = 152, 76
local GAP = 8
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
local function SetIcon(f, unit)
    local file = CLASS_ICON[f.classFile or ""]
    f.por:SetTexCoord(0, 1, 0, 1)
    if file then
        f.por:SetTexture(ns.MEDIA .. file)
    elseif unit then
        SetPortraitTexture(f.por, unit)
    end
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
local DSIZE, BSIZE = 18, 16
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
            cont:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left,
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

local function CreateMember(parent, i)
    local unit = "party" .. i
    local f = CreateFrame("Button", "LeelUI_party" .. i, parent, "SecureUnitButtonTemplate")
    f.unit = unit
    f:SetSize(CELL_W, CELL_H)
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")

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
    local sh = TileTex(f, "BACKGROUND", -6, { 0, 0, 0 }, 0.45)
    sh:SetPoint("TOPLEFT", 0, -3); sh:SetPoint("BOTTOMRIGHT", 0, -5)
    f.rim = TileTex(f, "BACKGROUND", -5, RIM, 1)
    f.rim:SetPoint("TOPLEFT", -2, 2); f.rim:SetPoint("BOTTOMRIGHT", 2, -2)
    local bg = TileTex(f, "BACKGROUND", -4, { 0.102, 0.075, 0.07 }, 0.96)
    bg:SetAllPoints()

    f.mask = f:CreateMaskTexture()
    f.mask:SetTexture(TILE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    f.mask:SetAllPoints(f)

    local lv = f:GetFrameLevel()
    -- 체력 (직업색)
    f.hp = MaskedBar(f, lv + 1)
    f.hp:SetAllPoints()
    -- 들어올 치유: 체력 끝에서 이어서, 칸 밖으로 넘치는 건 둥근 틀에 잘림
    f.heal = MaskedBar(f, lv + 1)
    f.heal:SetSize(CELL_W, CELL_H)
    f.heal:SetPoint("TOPLEFT", f.hp:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    f.heal:SetStatusBarColor(MINT[1], MINT[2], MINT[3], 0.7)
    local stripes = f.heal:CreateTexture(nil, "OVERLAY")
    stripes:SetTexture(ns.MEDIA .. "stripes", "REPEAT", "REPEAT")
    stripes:SetHorizTile(true); stripes:SetVertTile(true)
    stripes:SetAllPoints(f.heal:GetStatusBarTexture())
    stripes:SetVertexColor(1, 1, 1, 0.25)
    stripes:AddMaskTexture(f.mask)
    -- 위쪽 윤기
    local shine = f.hp:CreateTexture(nil, "OVERLAY")
    shine:SetTexture(ns.WHITE)
    shine:SetAllPoints(f)
    shine:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.10), CreateColor(1, 1, 1, 0.16))
    shine:AddMaskTexture(f.mask)

    -- 아래 자원 줄
    f.pw = MaskedBar(f, lv + 2)
    f.pw:SetPoint("BOTTOMLEFT"); f.pw:SetPoint("BOTTOMRIGHT"); f.pw:SetHeight(4)
    local pbg = f.pw:CreateTexture(nil, "BACKGROUND")
    pbg:SetTexture(ns.WHITE); pbg:SetAllPoints(); pbg:SetVertexColor(0.08, 0.06, 0.055, 0.85)
    pbg:AddMaskTexture(f.mask)

    -- 글씨·아이콘 층
    local top = CreateFrame("Frame", nil, f)
    top:SetAllPoints()
    top:SetFrameLevel(lv + 4)
    f.top = top

    local pf = CreateFrame("Frame", nil, top)
    pf:SetSize(20, 20)
    pf:SetPoint("TOPLEFT", PAD, -PAD + 1)
    local pring = pf:CreateTexture(nil, "BACKGROUND")
    pring:SetTexture(ns.MEDIA .. "circle"); pring:SetVertexColor(0.16, 0.09, 0.08, 0.9)
    pring:SetPoint("TOPLEFT", -1.5, 1.5); pring:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
    f.por = pf:CreateTexture(nil, "ARTWORK")
    f.por:SetAllPoints()
    local pm = pf:CreateMaskTexture()
    pm:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    pm:SetAllPoints(f.por)
    f.por:AddMaskTexture(pm)

    f.name = OFont(top, 14)
    f.name:SetPoint("LEFT", pf, "RIGHT", 5, 0)
    f.name:SetWidth(CELL_W - PAD * 2 - 25 - 56)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)

    f.val = ONum(top, 26)
    f.val:SetPoint("BOTTOMLEFT", PAD, PAD + 1)
    f.pct = ONum(top, 13)
    f.pct:SetText("%")
    f.pct:SetPoint("BOTTOMLEFT", f.val, "BOTTOMRIGHT", 1, 2)

    -- 쓰러짐 / 유령 / 끊김
    f.state = OFont(top, 15, { 0.78, 0.70, 0.67 })
    f.state:SetPoint("BOTTOMLEFT", PAD, PAD + 3)
    f.state:Hide()
    f.mid = top:CreateTexture(nil, "OVERLAY")
    f.mid:SetSize(20, 20)
    f.mid:SetPoint("LEFT", f.state, "RIGHT", 4, 0)
    f.mid:Hide()

    -- 힐러 마나 부족
    f.mana = OFont(top, 11, { 0.68, 0.76, 1 })
    f.mana:SetPoint("BOTTOMRIGHT", -PAD, PAD + 1)
    f.mana:Hide()

    -- 파티장 왕관 (왼쪽 위 모서리)
    f.lead = top:CreateTexture(nil, "OVERLAY", nil, 2)
    f.lead:SetTexture(ns.MEDIA .. "crown")
    f.lead:SetSize(18, 18)
    f.lead:SetPoint("CENTER", top, "TOPLEFT", 6, -2)
    f.lead:SetRotation(math.rad(18))
    f.lead:Hide()

    -- 내가 건 버프 (오른쪽 위), 해제할 디버프 (오른쪽 아래)
    f.buffs = AuraBox(f, "leelMine", "HELPFUL|PLAYER", 3, BSIZE, "mm_squircle", "TOPRIGHT", -PAD + 2, -PAD + 2)
    f.debuffs = AuraBox(f, "leelDispel", "HARMFUL|RAID", 2, DSIZE, "mm_squircle", "BOTTOMRIGHT", -PAD + 2, PAD + 4)
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
        f.val:Hide(); f.pct:Hide(); f.mana:Hide()
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
    f.val:Show(); f.pct:Show()
    f.name:SetTextColor(1, 0.97, 0.955)
    local col = Pastel(f.classFile)
    f.hp:SetStatusBarColor(col[1], col[2], col[3], 0.9)

    local cur, max = UnitHealth(u), UnitHealthMax(u)
    ns.SetBar(f.hp, cur, max)
    PctText(f.val, u, cur, max)

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
    ns.SetText(f.name, UnitName(u))
    SetIcon(f, u)
    f.lead:SetShown(Try(UnitIsGroupLeader, u))
end

-- 테두리: 어그로 빨강 > 내 대상 흰색 > 평소 진한 갈색
local function PaintRim(f)
    if f.aggroOn then
        f.rim:SetVertexColor(1, 0.35, 0.35, 1)
    elseif f.selOn then
        f.rim:SetVertexColor(1, 0.953, 0.965, 1)
    else
        f.rim:SetVertexColor(RIM[1], RIM[2], RIM[3], 1)
    end
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

local function UpdateAuras(f)
    if f.debuffs then pcall(f.debuffs.UpdateAllAuras, f.debuffs) end
    if f.buffs then pcall(f.buffs.UpdateAllAuras, f.buffs) end
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

local function Layout()
    local box, members = ns.party, ns.partyMembers
    if not box then return end
    ns:RunOutOfCombat("partyLayout", function()
        local mode = ns.db.partyLayout or "row"
        for i, f in ipairs(members) do
            local cx, cy
            if mode == "col" then cx, cy = 0, i - 1
            elseif mode == "grid" then cx, cy = (i - 1) % 2, math.floor((i - 1) / 2)
            else cx, cy = i - 1, 0 end
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", box, "TOPLEFT", cx * (CELL_W + GAP), -cy * (CELL_H + GAP))
        end
        local cols = mode == "col" and 1 or (mode == "grid" and 2 or 4)
        local rows = mode == "col" and 4 or (mode == "grid" and 2 or 1)
        box:SetSize(cols * CELL_W + (cols - 1) * GAP, rows * CELL_H + (rows - 1) * GAP)
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
    for _, fr in pairs(list) do
        if fr then
            pcall(fr.UnregisterAllEvents, fr)
            pcall(fr.Hide, fr)
            pcall(fr.SetParent, fr, hidden)
        end
    end
end

----------------------------------------------------------------------
-- 이동 모드: 예시 파티 + 분홍 테두리 드래그
----------------------------------------------------------------------
local FAKE = {
    -- 이름, 직업, 체력, 자원종류, 자원, 어그로, 파티장, 들어올 치유
    { "든든곰",   "WARRIOR", 0.71, 1, 0.38, true,  true,  0.12 },
    { "눈꽃별",   "MAGE",    0.24, 0, 0.80, false, false, 0.30 },
    { "보라밤",   "WARLOCK", 0.93, 0, 0.55, false, false, 0 },
    { "달빛사냥", "HUNTER",  1.00, 0, 0.90, false, false, 0 },
}

local function Fake(f, d)
    local name, file, hp, pt, pw, agg, lead, inc = unpack(d)
    f.classFile, f.gone = file, false
    f.name:SetText(name); f.name:SetTextColor(1, 0.97, 0.955)
    f.por:SetDesaturated(false); f.por:SetVertexColor(1, 1, 1)
    SetIcon(f)
    f.mid:Hide(); f.state:Hide(); f.val:Show(); f.pct:Show()
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
    PaintRim(f)
    f.lead:SetShown(lead)
    f:SetAlpha(1)
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
            UnregisterUnitWatch(f)
            f:Show()
            Fake(f, FAKE[i])
        end
        box.mover:Show()
    else
        box.preview = false
        box.mover:Hide()
        ns:RunOutOfCombat("partyPreview", function()
            RegisterStateDriver(box, "visibility", "[group:raid] hide; show")
            for _, f in ipairs(members) do RegisterUnitWatch(f) end
        end)
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
                             "UNIT_HEAL_PREDICTION" }) do
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
            elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
                UpdateThreat(f)
            elseif event == "UNIT_NAME_UPDATE" or event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
                UpdateInfo(f); UpdateHealth(f)
            else
                UpdatePower(f)
            end
        end)
    end
    ns.partyMembers = members
    box.mover = CreatePartyMover(box)
    Layout()

    local gev = CreateFrame("Frame")
    gev:RegisterEvent("GROUP_ROSTER_UPDATE")
    gev:RegisterEvent("PLAYER_ENTERING_WORLD")
    gev:RegisterEvent("PARTY_LEADER_CHANGED")
    gev:RegisterEvent("PLAYER_TARGET_CHANGED")
    gev:SetScript("OnEvent", function(_, event)
        if box.preview then return end
        for _, f in ipairs(members) do
            if event == "PLAYER_TARGET_CHANGED" then UpdateTarget(f) else UpdateAll(f) end
        end
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
SlashCmdList.LEELPARTYDBG = function()
    local inc = UnitGetIncomingHeals and select(2, pcall(UnitGetIncomingHeals, "player"))
    print("|cfff2b3c2[르엘 파티]|r 들어올치유함수=" .. tostring(UnitGetIncomingHeals ~= nil) ..
        " 값=" .. (ns.IsSecret(inc) and "<숨김>" or tostring(inc)) ..
        "  체력%곡선=" .. tostring(LowCurve() ~= nil) .. "  오라상자=" .. tostring(ns.partyMembers and ns.partyMembers[1] and ns.partyMembers[1].buffs ~= nil))
end
