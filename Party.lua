-- LeelUI / Party.lua
-- 파티 프레임 (C안: 동글 체력 링)
-- 바깥 링 = 체력, 안쪽 얇은 링 = 마나/분노/기력, 가운데 르엘 UI 직업 아이콘(파스텔 원), 분홍 왕관
-- 상황: 체력 35% 아래 산호색(20% 아래 맥박), 테두리 한 자리(어그로 빨강 / 내 대상 흰색),
--       해제할 디버프(작은 동그라미 아이콘), 힐러 마나 부족, 쓰러짐/유령/접속 끊김, 부활 중, 멀리 있음(흐림)

local _, ns = ...
local C = ns.C
local Try = ns.Try

local RING   = 84    -- 체력 링 지름 (기본 크기 75%에서 화면상 약 63px)
local MRING  = 62    -- 마나 링 지름
local POR    = 52    -- 초상화 지름
local CELL_W = 104
local CELL_H = RING + 52
local GAP    = 10
local LOW_HP, CRIT_HP, LOW_MANA = 0.35, 0.20, 0.20
local HEALERS = { PRIEST = true, DRUID = true, SHAMAN = true, PALADIN = true }

local PCOL = {
    [0] = { 0.31, 0.49, 1.00 },   -- 마나
    [1] = { 0.88, 0.28, 0.28 },   -- 분노
    [2] = { 1.00, 0.61, 0.25 },   -- 집중
    [3] = { 1.00, 0.82, 0.12 },   -- 기력
}
local CORAL = { 1.00, 0.48, 0.40 }

----------------------------------------------------------------------
-- 동그란 진행 링
-- 숫자를 계산할 수 있으면 12시부터 시계 방향으로 줄어드는 호(반원 두 장 회전)
-- 전투 중 숨겨진 값이면 계산을 못 하니 아래에서 위로 차는 링으로 대신
----------------------------------------------------------------------
local function CreateRing(parent, size, full, half, layer)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(size, size)

    local track = r:CreateTexture(nil, layer, nil, 0)
    track:SetTexture(ns.MEDIA .. full)
    track:SetAllPoints()
    track:SetVertexColor(0.23, 0.17, 0.16, 1)

    local function Half(side)
        local t = r:CreateTexture(nil, layer, nil, 1)
        t:SetTexture(ns.MEDIA .. half)
        t:SetAllPoints()
        local m = r:CreateMaskTexture()
        m:SetTexture(ns.WHITE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if side == "RIGHT" then
            m:SetPoint("TOPLEFT", r, "TOP", 0, 0); m:SetPoint("BOTTOMRIGHT")
        else
            m:SetPoint("TOPLEFT"); m:SetPoint("BOTTOMRIGHT", r, "BOTTOM", 0, 0)
        end
        t:AddMaskTexture(m)
        return t
    end
    r.right, r.left = Half("RIGHT"), Half("LEFT")

    -- 숨겨진 값용: 세로로 차는 링
    local sb = CreateFrame("StatusBar", nil, r)
    sb:SetAllPoints()
    sb:SetOrientation("VERTICAL")
    sb:SetStatusBarTexture(ns.MEDIA .. full)
    sb:SetMinMaxValues(0, 1)
    sb:Hide()
    r.sb = sb

    function r:SetColor(c)
        self.right:SetVertexColor(c[1], c[2], c[3], 1)
        self.left:SetVertexColor(c[1], c[2], c[3], 1)
        self.sb:SetStatusBarColor(c[1], c[2], c[3], 1)
    end

    -- 반환: 0~1 비율 (숨겨진 값이면 nil)
    function r:SetValue(cur, max)
        local ok, p = pcall(function()
            if not max or max <= 0 then return 0 end
            local v = cur / max
            if v < 0 then v = 0 elseif v > 1 then v = 1 end
            return v
        end)
        if not ok or type(p) ~= "number" then
            self.right:Hide(); self.left:Hide()
            self.sb:Show()
            ns.SetBar(self.sb, cur, max)
            return nil
        end
        self.sb:Hide()
        -- 시계 방향 회전 = 음수 각도
        if p <= 0 then
            self.right:Hide(); self.left:Hide()
        elseif p <= 0.5 then
            self.right:Show(); self.right:SetRotation(-p * 2 * math.pi)
            self.left:Hide()
        else
            self.right:Show(); self.right:SetRotation(-math.pi)
            self.left:Show(); self.left:SetRotation(-math.pi - (p - 0.5) * 2 * math.pi)
        end
        return p
    end

    function r:Clear()
        self.right:Hide(); self.left:Hide(); self.sb:Hide()
    end
    return r
end

----------------------------------------------------------------------
-- 직업
----------------------------------------------------------------------
local function ClassOf(u)
    local ok, _, file = pcall(UnitClass, u)
    if not ok or type(file) ~= "string" or ns.IsSecret(file) then return end
    return file
end

local function ClassColor(file)
    local c = file and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(file))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]))
    if c then return { c.r, c.g, c.b } end
    return C.tx
end

-- 체력 알약 색: 평소 분홍 + 진한 글씨, 위험하면 빨강 + 흰 글씨
local function PaintPill(f, low)
    if low then
        f.pill.fill:SetVertexColor(0.88, 0.33, 0.25, 1)
        f.val:SetTextColor(1, 1, 1)
    else
        f.pill.fill:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
        f.val:SetTextColor(C.ink[1], C.ink[2], C.ink[3])
    end
end

-- 르엘 UI 전용 직업 아이콘 (파스텔 원). 직업을 모르면 게임 초상화
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

-- 체력 숫자 (% 기호 없이)
local function PctText(fs, unit, cur, max)
    local ok = pcall(function()
        if max > 0 then fs:SetFormattedText("%d", math.floor(cur / max * 100 + 0.5)) else fs:SetText("") end
    end)
    if ok then return end
    if UnitHealthPercent then
        ok = pcall(function()
            local scale = CurveConstants and CurveConstants.ScaleTo100
            fs:SetFormattedText("%.0f", UnitHealthPercent(unit, true, scale))
        end)
        if ok then return end
    end
    fs:SetText("")
end

----------------------------------------------------------------------
-- 해제할 디버프 (블리자드 애드온용 오라 컨테이너, 내가 풀 수 있는 것만)
----------------------------------------------------------------------
local DSIZE = 22
local function InitDebuff(btn)
    btn:SetSize(DSIZE, DSIZE)
    local black = btn:CreateTexture(nil, "BACKGROUND")
    black:SetTexture(ns.MEDIA .. "circle"); black:SetVertexColor(0.11, 0.08, 0.07, 1)
    black:SetPoint("TOPLEFT", -2, 2); black:SetPoint("BOTTOMRIGHT", 2, -2)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local m = btn:CreateMaskTexture()
    m:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(icon)
    icon:AddMaskTexture(m)
    btn:SetIcon(icon)
end

local function CreateDebuffs(f)
    local ok, cont = pcall(CreateFrame, "AuraContainer", nil, f, "CustomAuraContainerTemplate")
    if not ok or not cont then return end
    local ok2 = pcall(function()
        cont:SetPoint("TOP", f.ring, "TOPRIGHT", -8, 2)
        if cont.SetFlowLayoutAnchorPoint then cont:SetFlowLayoutAnchorPoint("TOP") end
        if cont.SetFlowLayoutGrowthDirection and AnchorUtil and AnchorUtil.FlowDirection then
            cont:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Down, AnchorUtil.FlowDirection.Left)
        end
        cont:AddAuraGroup("leelDispel", "HARMFUL|RAID", {
            maxFrameCount = 3,
            sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.Expiration or 0,
            sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal or 0,
            initializeFrame = InitDebuff,
            layout = { elementSpacing = 4, elementWidth = DSIZE, elementHeight = DSIZE },
        })
        cont:SetUnit(f.unit)
    end)
    if ok2 then
        cont:SetFrameLevel(f.top:GetFrameLevel() + 1)
        f.debuffs = cont
    end
end

----------------------------------------------------------------------
-- 한 칸
----------------------------------------------------------------------
local function Circle(parent, layer, sub, size, color, alpha)
    local t = parent:CreateTexture(nil, layer, nil, sub or 0)
    t:SetTexture(ns.MEDIA .. "circle")
    t:SetSize(size, size)
    t:SetVertexColor(color[1], color[2], color[3], alpha or 1)
    return t
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

    -- 링 영역
    local ringHolder = CreateFrame("Frame", nil, f)
    ringHolder:SetSize(RING, RING)
    ringHolder:SetPoint("TOP", 0, -8)
    f.ring = ringHolder

    -- 바깥 테두리 한 자리: 평소 검정, 어그로 빨강, 내 대상 흰색
    f.rim = ringHolder:CreateTexture(nil, "BACKGROUND", nil, -7)
    f.rim:SetTexture(ns.MEDIA .. "tring")
    f.rim:SetPoint("TOPLEFT", -4, 4); f.rim:SetPoint("BOTTOMRIGHT", 4, -4)
    f.rim:SetVertexColor(0, 0, 0, 0.9)

    local bg = Circle(ringHolder, "BACKGROUND", -6, RING + 6, { 0.078, 0.055, 0.051 }, 0.95)
    bg:SetPoint("CENTER")

    f.hp = CreateRing(ringHolder, RING, "pring", "pring_half", "BORDER")
    f.hp:SetPoint("CENTER")
    f.hp:SetColor(C.acc)

    f.pw = CreateRing(ringHolder, MRING, "mring", "mring_half", "BORDER")
    f.pw:SetPoint("CENTER")
    f.pw:SetFrameLevel(f.hp:GetFrameLevel() + 1)

    -- 초상화
    local pf = CreateFrame("Frame", nil, ringHolder)
    pf:SetSize(POR, POR)
    pf:SetPoint("CENTER")
    pf:SetFrameLevel(f.pw:GetFrameLevel() + 1)
    local pbg = Circle(pf, "BACKGROUND", 0, POR + 4, { 0.11, 0.08, 0.07 })
    pbg:SetPoint("CENTER")
    f.por = pf:CreateTexture(nil, "ARTWORK")
    f.por:SetAllPoints()
    local pm = pf:CreateMaskTexture()
    pm:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    pm:SetAllPoints(f.por)
    f.por:AddMaskTexture(pm)

    -- 체력 20% 아래: 붉은 기운 맥박
    f.danger = Circle(pf, "OVERLAY", 0, POR, { 1, 0.24, 0.16 }, 1)
    f.danger:SetPoint("CENTER")
    f.danger:SetBlendMode("ADD")
    local ag = f.danger:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(0.05); a:SetToAlpha(0.4); a:SetDuration(0.6); a:SetSmoothing("IN_OUT")
    f.danger:SetScript("OnShow", function() ag:Play() end)
    f.danger:SetScript("OnHide", function() ag:Stop() end)
    f.danger:Hide()

    -- 배지들 (맨 위 층)
    local top = CreateFrame("Frame", nil, ringHolder)
    top:SetAllPoints()
    top:SetFrameLevel(pf:GetFrameLevel() + 3)
    f.top = top

    -- 가운데 상태 아이콘 (해골 / 부활)
    f.mid = top:CreateTexture(nil, "OVERLAY")
    f.mid:SetSize(26, 26)
    f.mid:SetPoint("CENTER")
    f.mid:Hide()

    -- 파티장 왕관 (위 가운데)
    f.lead = top:CreateTexture(nil, "OVERLAY")
    f.lead:SetTexture(ns.MEDIA .. "crown")
    f.lead:SetSize(20, 20)
    f.lead:SetPoint("CENTER", ringHolder, "TOP", 0, 0)
    f.lead:Hide()

    -- 한 줄: 이름 + 체력 숫자 (쓰러지면 숫자 대신 상태 글씨)
    -- 링 아래에 걸친 체력 숫자 알약 (B안): 평소 분홍, 35% 아래 빨강
    -- capsule.tga = 2:1 알약 모양 (끝이 완전히 둥글게)
    local pill = CreateFrame("Frame", nil, ringHolder)
    pill:SetSize(40, 20)
    pill:SetPoint("CENTER", ringHolder, "BOTTOM", 0, 4)
    pill:SetFrameLevel(top:GetFrameLevel() + 2)
    local pe = pill:CreateTexture(nil, "BACKGROUND")
    pe:SetTexture(ns.MEDIA .. "capsule"); pe:SetVertexColor(0.09, 0.07, 0.06, 1)
    pe:SetPoint("TOPLEFT", -2, 2); pe:SetPoint("BOTTOMRIGHT", 2, -2)
    pill.fill = pill:CreateTexture(nil, "BORDER")
    pill.fill:SetTexture(ns.MEDIA .. "capsule"); pill.fill:SetAllPoints()
    local shine = pill:CreateTexture(nil, "ARTWORK")
    shine:SetTexture(ns.MEDIA .. "capsule"); shine:SetVertexColor(1, 1, 1, 0.28)
    shine:SetPoint("TOPLEFT", 5, -2); shine:SetPoint("TOPRIGHT", -5, -2); shine:SetHeight(6)
    f.val = ns.Num(pill, 16, C.ink)
    f.val:SetShadowColor(0, 0, 0, 0)
    f.val:SetPoint("CENTER", 0, 0)
    f.pill = pill

    -- 이름 (알약 아래), 쓰러지면 이름 아래 상태 글씨, 힐러 마나 경고
    f.name = ns.Font(f, 14)
    f.name:SetPoint("TOP", ringHolder, "BOTTOM", 0, -16)
    f.name:SetWidth(CELL_W)
    f.name:SetWordWrap(false)
    f.state = ns.Font(f, 12, { 0.62, 0.58, 0.58 })
    f.state:SetPoint("TOP", f.name, "BOTTOM", 0, -1)
    f.state:Hide()
    f.mana = ns.Font(f, 11, { 0.58, 0.67, 0.94 })
    f.mana:SetPoint("TOP", f.name, "BOTTOM", 0, -1)
    f.mana:Hide()

    CreateDebuffs(f)
    return f
end

----------------------------------------------------------------------
-- 갱신
----------------------------------------------------------------------
local function UpdateHealth(f)
    local u = f.unit
    if not UnitExists(u) then return end
    local dead = Try(UnitIsDeadOrGhost, u)
    local ghost = dead and Try(UnitIsGhost, u)
    local off = not Try(UnitIsConnected, u)
    local gone = dead or off

    f.por:SetDesaturated(gone)
    f.por:SetVertexColor(gone and 0.5 or 1, gone and 0.5 or 1, gone and 0.5 or 1)

    if gone then
        f.hp:Clear(); f.pw:Clear()
        f.danger:Hide()
        f.pill:Hide(); f.mana:Hide()
        f.state:SetText(off and "접속 끊김" or (ghost and "유령" or "쓰러짐"))
        f.state:Show()
        f.name:SetTextColor(0.62, 0.58, 0.58)
        local res = not off and UnitHasIncomingResurrection and Try(UnitHasIncomingResurrection, u)
        if res then
            f.mid:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
            f.mid:SetVertexColor(0.62, 1, 0.66)
            f.mid:Show()
        elseif dead then
            f.mid:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
            f.mid:SetVertexColor(1, 1, 1)
            f.mid:Show()
        else
            f.mid:Hide()
        end
        return
    end

    f.mid:Hide()
    f.state:Hide()
    f.pill:Show()
    local col = ClassColor(f.classFile)
    f.name:SetTextColor(col[1], col[2], col[3])

    local cur, max = UnitHealth(u), UnitHealthMax(u)
    local p = f.hp:SetValue(cur, max)
    PctText(f.val, u, cur, max)
    local low = p and p < LOW_HP
    f.hp:SetColor(low and CORAL or C.acc)
    PaintPill(f, low)
    f.danger:SetShown(p and p < CRIT_HP and true or false)
end

local function UpdatePower(f)
    local u = f.unit
    if not UnitExists(u) then return end
    if Try(UnitIsDeadOrGhost, u) or not Try(UnitIsConnected, u) then f.pw:Clear(); f.mana:Hide(); return end
    local pt = UnitPowerType(u)
    if ns.IsSecret(pt) then pt = 0 end
    local c = PCOL[pt] or PCOL[0]
    f.pw:SetColor(c)
    local cur, max = UnitPower(u, pt), UnitPowerMax(u, pt)
    local p = f.pw:SetValue(cur, max)
    if pt == 0 and p and p < LOW_MANA and HEALERS[f.classFile or ""] then
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

-- 테두리: 어그로 빨강 > 내 대상 흰색 > 평소 검정
local function PaintRim(f)
    if f.aggroOn then
        f.rim:SetVertexColor(C.dmg[1], C.dmg[2], C.dmg[3], 1)
    elseif f.selOn then
        f.rim:SetVertexColor(1, 1, 1, 1)
    else
        f.rim:SetVertexColor(0, 0, 0, 0.9)
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

local function UpdateAll(f)
    if not UnitExists(f.unit) then return end
    UpdateInfo(f)
    UpdateHealth(f)
    UpdatePower(f)
    UpdateThreat(f)
    UpdateTarget(f)
    UpdateRange(f)
    if f.debuffs then pcall(f.debuffs.UpdateAllAuras, f.debuffs) end
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
    { "슈엘",   "DRUID",   0.92, 0, 0.74, false, false },
    { "빵떡이", "WARRIOR", 0.48, 1, 0.62, true,  true  },
    { "모모",   "PRIEST",  0.86, 0, 0.18, false, false },
    { "구름",   "ROGUE",   0.17, 3, 0.80, false, false },
}

local function Fake(f, d)
    local name, file, hp, pt, pw, agg, lead = unpack(d)
    f.classFile = file
    local col = ClassColor(file)
    f.name:SetText(name); f.name:SetTextColor(col[1], col[2], col[3])
    f.por:SetDesaturated(false); f.por:SetVertexColor(1, 1, 1)
    SetIcon(f)
    f.mid:Hide(); f.state:Hide(); f.pill:Show()
    f.hp:SetValue(hp, 1)
    local low = hp < LOW_HP
    f.hp:SetColor(low and CORAL or C.acc)
    f.val:SetFormattedText("%d", math.floor(hp * 100 + 0.5))
    PaintPill(f, low)
    f.danger:SetShown(hp < CRIT_HP)
    f.pw:SetColor(PCOL[pt]); f.pw:SetValue(pw, 1)
    if pt == 0 and pw < LOW_MANA and HEALERS[file] then
        f.mana:SetFormattedText("마나 %d%%", math.floor(pw * 100 + 0.5)); f.mana:Show()
    else
        f.mana:Hide()
    end
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
                             "UNIT_THREAT_SITUATION_UPDATE", "INCOMING_RESURRECT_CHANGED" }) do
            pcall(ev.RegisterUnitEvent, ev, e, f.unit)
        end
        ev:SetScript("OnEvent", function(_, event)
            if box.preview then return end
            if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS"
               or event == "UNIT_CONNECTION" or event == "INCOMING_RESURRECT_CHANGED" then
                UpdateHealth(f)
                if event ~= "UNIT_HEALTH" then UpdatePower(f) end
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
