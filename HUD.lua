-- LeelUI / HUD.lua
-- 메인 HUD: 플레이어 VS 대상 + 펫 (B안 컴팩트)

local _, ns = ...
local C = ns.C
local Try = ns.Try

local PT = Enum and Enum.PowerType or {}
local ENERGY = PT.Energy or 3
local MANA   = PT.Mana or 0
local COMBO  = PT.ComboPoints or 4

-- B안(컴팩트): 바 약 35% 짧게, 초상화 살짝 작게, 가운데 간격 160
local POR_W, POR_H = 108, 114
local BAR_W, BAR_H = 285, 28
local BAR_X = 96                       -- 초상화와 살짝 겹치게
local SIDE_W = BAR_X + BAR_W + 4
local GAP = 160

----------------------------------------------------------------------
-- 한쪽(플레이어 또는 대상)
----------------------------------------------------------------------
local function CreateSide(hud, unit, mirrored)
    local A  = mirrored and "TOPRIGHT" or "TOPLEFT"
    local sx = mirrored and -1 or 1
    local J  = mirrored and "RIGHT" or "LEFT"

    local f = CreateFrame("Button", "LeelUI_" .. unit, hud, "SecureUnitButtonTemplate")
    f:SetSize(SIDE_W, 140)
    f:SetPoint(A, hud, A, 0, 0)
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    f.unit, f.mirrored = unit, mirrored

    -- 초상화
    f.portrait = ns.CreatePortrait(f, POR_W, POR_H)
    f.portrait:SetPoint(A, f, A, 0, 0)

    -- 이름 · 레벨
    f.name = ns.Font(f, 18)
    f.name:SetPoint(A, f, A, (POR_W + 6) * sx, -6)
    f.nameA, f.nameSx = A, sx
    f.name:SetJustifyH(J)
    f.lvLabel = ns.Font(f, 13, C.tx2)
    f.lvLabel:SetText("LV")
    f.lv = ns.Num(f, 18, C.tx, false)
    if mirrored then
        f.lv:SetPoint("BOTTOMRIGHT", f.name, "BOTTOMLEFT", -10, 0)
        f.lvLabel:SetPoint("BOTTOMRIGHT", f.lv, "BOTTOMLEFT", -3, 1)
    else
        f.lvLabel:SetPoint("BOTTOMLEFT", f.name, "BOTTOMRIGHT", 10, 1)
        f.lv:SetPoint("BOTTOMLEFT", f.lvLabel, "BOTTOMRIGHT", 3, -1)
    end

    -- 체력바
    f.hp = ns.CreateSkewBar(f, BAR_W, BAR_H, { mirrored = mirrored, inset = 2 })
    f.hp:SetPoint(A, f, A, BAR_X * sx, -34)
    ns.PaintHealth(f.hp)

    -- 직업 아이콘 캡 (G안): 체력바 시작점에 동그란 직업 아이콘, 플레이어 캐릭터일 때만
    f.cls = CreateFrame("Frame", nil, f)
    f.cls:SetSize(44, 44)   -- HUD 60%에서 화면상 약 26px
    f.cls:SetPoint("CENTER", f.hp, mirrored and "RIGHT" or "LEFT", 12 * sx, 0)
    f.cls:SetFrameLevel(f.hp.over:GetFrameLevel() + 5)
    local cbg = f.cls:CreateTexture(nil, "BACKGROUND")
    cbg:SetTexture(ns.MEDIA .. "circle"); cbg:SetVertexColor(0, 0, 0, 0.95)
    cbg:SetPoint("TOPLEFT", -2, 2); cbg:SetPoint("BOTTOMRIGHT", 2, -2)
    local cfill = f.cls:CreateTexture(nil, "BORDER")
    cfill:SetTexture(ns.MEDIA .. "circle"); cfill:SetVertexColor(0.11, 0.08, 0.08, 1)
    cfill:SetAllPoints()
    f.cls.icon = f.cls:CreateTexture(nil, "ARTWORK")
    f.cls.icon:SetPoint("TOPLEFT", 6, -6); f.cls.icon:SetPoint("BOTTOMRIGHT", -6, 6)
    local cm = f.cls:CreateMaskTexture()
    cm:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    cm:SetAllPoints(f.cls.icon)
    f.cls.icon:AddMaskTexture(cm)
    f.cls.ring = f.cls:CreateTexture(nil, "OVERLAY")
    f.cls.ring:SetTexture(ns.MEDIA .. "ring")
    f.cls.ring:SetAllPoints()
    f.cls:Hide()

    f.hpValue = ns.Num(f.hp.over, 23, C.ink)
    f.hpValue:SetShadowColor(0, 0, 0, 0)
    f.hpPct = ns.Num(f.hp.over, 15, { 0.416, 0.227, 0.275 })
    f.hpPct:SetShadowColor(0, 0, 0, 0)
    if mirrored then
        f.hpValue:SetPoint("RIGHT", f.hp, "RIGHT", -20, 0)
        f.hpPct:SetPoint("BOTTOMRIGHT", f.hpValue, "BOTTOMLEFT", -6, 2)
    else
        f.hpValue:SetPoint("LEFT", f.hp, "LEFT", 20, 0)
        f.hpPct:SetPoint("BOTTOMLEFT", f.hpValue, "BOTTOMRIGHT", 6, 2)
    end

    -- 쓰러졌을 때 바 가운데 조용한 상태 글씨 ("쓰러짐" / "다 주웠어요")
    f.state = ns.Font(f, 13, { 0.78, 0.74, 0.74 })
    f.state:SetPoint("CENTER", f.hp, "CENTER", 0, 0)
    f.state:Hide()

    return f
end

-- 플레이어 전용: 연계 점수, 기력, 마나
local function AddPlayerExtras(f)
    -- 연계 점수는 몹마다 따로라 대상 쪽으로 옮김 (AddTargetExtras)
    f.power = ns.CreateSkewBar(f, 220, 6, { inset = 1, ticks = 4, noShadow = true, shape = "pill32" })
    f.power:SetPoint("TOPLEFT", f, "TOPLEFT", BAR_X + 14, -73)
    f.powerText = ns.Num(f, 17, C.accHi)
    f.powerText:SetPoint("LEFT", f.power, "RIGHT", 10, 0)

    f.manaLine = CreateFrame("StatusBar", nil, f)
    f.manaLine:SetSize(190, 3)
    f.manaLine:SetPoint("TOPLEFT", f, "TOPLEFT", BAR_X + 12, -90)
    f.manaLine:SetStatusBarTexture(ns.WHITE)
    f.manaLine:SetStatusBarColor(C.mana[1], C.mana[2], C.mana[3])
    local bg = ns.Tex(f.manaLine, "BACKGROUND", 0, ns.WHITE, { 1, 1, 1 }, 0.12)
    bg:SetAllPoints()
    f.manaLabel = ns.Font(f, 12, { 0.56, 0.69, 1 })
    f.manaLabel:SetText("마나")
    f.manaLabel:SetPoint("LEFT", f.manaLine, "RIGHT", 10, 0)
    f.manaText = ns.Num(f, 15, { 0.56, 0.69, 1 }, false)
    f.manaText:SetPoint("LEFT", f.manaLabel, "RIGHT", 4, 0)
end

-- 대상 자원(마나/기력/분노): 체력바 바로 아래 얇은 줄 + 숫자 (디버프 줄과 안 겹치게 붙여서)
local function AddTargetPower(f)
    local line = CreateFrame("StatusBar", nil, f)
    line:SetSize(200, 4)
    line:SetPoint("TOPRIGHT", f.hp, "BOTTOMRIGHT", -16, -8)   -- 체력바와 띄움 (디버프 줄은 그만큼 아래로)
    line:SetStatusBarTexture(ns.WHITE)
    line:SetReverseFill(true)
    line:SetFrameLevel(f.hp:GetFrameLevel() + 5)
    local bg = ns.Tex(line, "BACKGROUND", 0, ns.WHITE, { 0, 0, 0 }, 0.55)
    bg:SetPoint("TOPLEFT", -1, 1); bg:SetPoint("BOTTOMRIGHT", 1, -1)
    f.tpower = line
    -- 내 쪽 마나 줄과 같은 모양: 숫자 + 이름 (대상은 거울처럼 왼쪽에)
    -- 글씨는 체력바보다 위층에 (체력바 판에 가려지지 않게)
    local tx = CreateFrame("Frame", nil, f)
    tx:SetAllPoints(line)
    tx:SetFrameLevel(f.hp:GetFrameLevel() + 6)
    f.tpowerText = ns.Num(tx, 14, C.tx, false)
    f.tpowerText:SetPoint("RIGHT", line, "LEFT", -8, -1)
    f.tpowerLabel = ns.Font(tx, 11.5, { 0.56, 0.69, 1 })
    f.tpowerLabel:SetPoint("RIGHT", f.tpowerText, "LEFT", -4, 0)
    line:Hide(); f.tpowerText:Hide(); f.tpowerLabel:Hide()
end

local function UpdateTargetPower(f)
    if not f.tpower then return end
    local ok, pType, cur, max = pcall(function()
        local t = UnitPowerType("target")
        return t, UnitPower("target", t), UnitPowerMax("target", t)
    end)
    -- 자원이 없거나(0) 분노가 0인 몹은 숨김
    -- 숨겨진 값(전투 중 일부 대상)이라 비교가 안 되면 일단 보여줌 (줄과 숫자는 그대로 그려짐)
    local okc, res = pcall(function() return max > 0 and (pType == MANA or cur > 0) end)
    local show = ok and ((not okc) or res) and true or false
    f.tpower:SetShown(show); f.tpowerText:SetShown(show); f.tpowerLabel:SetShown(show)
    if not show then return end
    ns.SetBar(f.tpower, cur, max)
    ns.SetText(f.tpowerText, cur)
    pcall(function()
        local c = C.mana
        if pType == ENERGY then c = { 1.00, 0.84, 0.30 }
        elseif pType ~= MANA then
            local pc = PowerBarColor and PowerBarColor[pType]
            if pc then c = { pc.r, pc.g, pc.b } end
        end
        f.tpower:SetStatusBarColor(c[1], c[2], c[3])
        local tc = pType == MANA and { 0.56, 0.69, 1 } or c
        f.tpowerText:SetTextColor(tc[1], tc[2], tc[3])
        f.tpowerLabel:SetTextColor(tc[1], tc[2], tc[3])
        f.tpowerLabel:SetText(pType == MANA and "마나" or pType == ENERGY and "기력" or (pType == (PT.Rage or 1)) and "분노" or "")
    end)
end

-- 대상 전용: 루팅 안내
local function AddTargetExtras(f)
    -- 줍기 알약 (A안): 쓰러진 몹에 전리품이 있으면 체력바 자리가 반짝이는 분홍 버튼으로
    -- 마우스는 안 받음 → 우클릭은 그대로 유닛 버튼(몹)으로 감
    local p = CreateFrame("Frame", nil, f)
    p:SetAllPoints(f.hp)
    p:SetFrameLevel(f.hp.over:GetFrameLevel() + 3)
    local shape = ns.MEDIA .. "pill16"
    local glow = p:CreateTexture(nil, "BACKGROUND", nil, 0)
    glow:SetTexture(shape); glow:SetVertexColor(C.accHi[1], C.accHi[2], C.accHi[3], 1)
    glow:SetPoint("TOPLEFT", -6, 6); glow:SetPoint("BOTTOMRIGHT", 6, -6)
    glow:SetBlendMode("ADD")
    local edge = p:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetTexture(shape); edge:SetVertexColor(0, 0, 0, 1)
    edge:SetPoint("TOPLEFT", -2, 2); edge:SetPoint("BOTTOMRIGHT", 2, -2)
    local fill = p:CreateTexture(nil, "BORDER")
    fill:SetTexture(shape); fill:SetAllPoints()
    if fill.SetGradient and CreateColor then
        fill:SetGradient("VERTICAL", CreateColor(0.91, 0.60, 0.68, 1), CreateColor(1, 0.88, 0.92, 1))
    else
        fill:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    end
    p.text = ns.Font(p, 16, C.ink)
    p.text:SetShadowColor(0, 0, 0, 0)
    p.text:SetText("우클릭으로 줍기")
    p.text:SetPoint("CENTER", p, "CENTER", 14, 0)
    local dot = p:CreateTexture(nil, "ARTWORK", nil, 0)
    dot:SetTexture(ns.MEDIA .. "circle"); dot:SetVertexColor(C.ink[1], C.ink[2], C.ink[3], 1)
    dot:SetSize(26, 26)
    dot:SetPoint("RIGHT", p.text, "LEFT", -8, 0)
    local hand = p:CreateTexture(nil, "ARTWORK", nil, 1)
    hand:SetTexture(ns.MEDIA .. "q_loot")
    hand:SetPoint("TOPLEFT", dot, "TOPLEFT", 2, -2); hand:SetPoint("BOTTOMRIGHT", dot, "BOTTOMRIGHT", -2, 2)
    -- 은은하게 숨 쉬는 빛
    local ag = glow:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(0.15); a:SetToAlpha(0.6); a:SetDuration(0.8); a:SetSmoothing("IN_OUT")
    p:SetScript("OnShow", function() ag:Play() end)
    p:SetScript("OnHide", function() ag:Stop() end)
    p:Hide()
    f.loot = p

    -- 내 디버프: 블리자드 애드온용 오라 컨테이너(CustomAuraContainer)
    -- 숨겨진 오라도 게임이 직접 채워 줌. 우리는 모양(분홍 진행 링)만 정함
    ns.CreateTargetDebuffs(f)
end

----------------------------------------------------------------------
-- 갱신
----------------------------------------------------------------------
local function SameGUID(a, b)
    local ok, r = pcall(function() return a ~= nil and a == b end)
    return ok and r or false
end

local function UpdateDead(f)
    local dead = Try(UnitIsDeadOrGhost, f.unit)
    f.hpValue:SetShown(not dead)
    f.hpPct:SetShown(not dead)
    f.hp:SetAlpha(dead and 0.5 or 1)
    f.name:SetAlpha(dead and 0.5 or 1)
    f.portrait.tex:SetDesaturated(dead)
    f.portrait.cut:SetShown(not dead)
    local canLoot = false
    local guid
    if f.loot and dead then
        guid = UnitGUID(f.unit)
        canLoot = CanLootUnit and Try(function() return CanLootUnit(guid) end) or false
        if canLoot then f.lootGUID = guid end
    end
    -- 줍기 알림은 시체 위 반짝 상자(Leel Spot)가 맡음. 대상 창은 '쓰러짐' / '다 주웠어요'만
    if f.loot then f.loot:Hide() end
    if dead then
        f.state:SetText((not canLoot and SameGUID(f.lootGUID, guid)) and "다 주웠어요" or "쓰러짐")
        f.state:Show()
    else
        f.state:Hide()
    end
end

local function UpdateHealth(f)
    local u = f.unit
    if not UnitExists(u) then return end
    local cur, max = UnitHealth(u), UnitHealthMax(u)
    ns.SetBar(f.hp.bar, cur, max)
    ns.SetText(f.hpValue, cur)
    ns.HealthPercentText(f.hpPct, u, cur, max)
    if f.mirrored then
        local tapped = UnitIsTapDenied and Try(UnitIsTapDenied, u) or false
        if tapped ~= f.tapped then
            f.tapped = tapped
            ns.SetTapped(f.hp, tapped)
            if not tapped then ns.PaintHealth(f.hp) end
        end
    end
    UpdateDead(f)
end

-- 체력 숫자: 직업 캡이 있으면 캡에 안 가리게 안쪽으로
local function PlaceHpValue(f, capShown)
    local side = f.mirrored and "RIGHT" or "LEFT"
    f.hpValue:ClearAllPoints()
    f.hpValue:SetPoint(side, f.hp, side, (capShown and 40 or 20) * (f.mirrored and -1 or 1), 0)
end

-- 플레이어 캐릭터면 직업 파일명(DRUID 등), 아니면 nil
local function ClassOf(u)
    if not Try(UnitIsPlayer, u) then return end
    local ok, _, file = pcall(UnitClass, u)
    if not ok or type(file) ~= "string" or ns.IsSecret(file) then return end
    return file
end

local function ClassColor(file)
    local c = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(file))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[file])
    if c then return { c.r, c.g, c.b } end
end

local function SetClassIcon(tex, file)
    local atlas = "classicon-" .. file:lower()
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        tex:SetAtlas(atlas)
        return true
    end
    local tc = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[file]
    if tc then
        tex:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes")
        tex:SetTexCoord(tc[1] + 0.02, tc[2] - 0.02, tc[3] + 0.02, tc[4] - 0.02)
        return true
    end
end

-- 이름 앞 직업 아이콘 + 직업 색 이름 (몹이면 흰 이름, 아이콘 없음)
local function UpdateClass(f)
    local file = ClassOf(f.unit)
    local col = file and ClassColor(file)
    local shown = false
    if col then
        local ok, res = pcall(SetClassIcon, f.cls.icon, file)
        shown = ok and res
    end
    if shown then
        f.cls.ring:SetVertexColor(col[1], col[2], col[3], 1)
        f.cls:Show()
        f.name:SetTextColor(col[1], col[2], col[3])
    else
        f.cls:Hide()
        f.name:SetTextColor(C.tx[1], C.tx[2], C.tx[3])
    end
    PlaceHpValue(f, shown)
end

local function UpdateInfo(f)
    local u = f.unit
    if not UnitExists(u) then return end
    ns.SetText(f.name, UnitName(u))
    UpdateClass(f)

    local lvl = UnitLevel(u)
    local c = C.tx
    if ns.IsSecret(lvl) then
        ns.SetText(f.lv, lvl)
    elseif lvl and lvl < 0 then
        f.lv:SetText("??"); c = C.dmg
    else
        f.lv:SetText(lvl or "")
        local getColor = GetCreatureDifficultyColor or GetQuestDifficultyColor
        if u ~= "player" and getColor and lvl then
            local d = getColor(lvl); c = { d.r, d.g, d.b }
        end
    end
    f.lv:SetTextColor(c[1], c[2], c[3])

    SetPortraitTexture(f.portrait.tex, u)
end

local function UpdatePower(f)
    local pType = UnitPowerType("player")
    local cur, max = UnitPower("player", pType), UnitPowerMax("player", pType)
    ns.SetBar(f.power.bar, cur, max)
    ns.SetText(f.powerText, cur)

    local c = C.accHi
    if pType == ENERGY then
        c = { 1.00, 0.84, 0.30 }   -- 기력: 노랑 (게임 기본 노랑보다 살짝 부드럽게)
    else
        local pc = PowerBarColor and PowerBarColor[pType]
        if pc then c = { pc.r, pc.g, pc.b } end
    end
    f.power.fill:SetVertexColor(c[1], c[2], c[3], 1)
    f.powerText:SetTextColor(c[1], c[2], c[3])


    -- 마나: 주 자원이 마나가 아닐 때 얇은 줄로
    local hasMana = (pType ~= MANA) and Try(function()
        return UnitPowerMax("player", MANA) > 0
    end)
    f.manaLine:SetShown(hasMana)
    f.manaLabel:SetShown(hasMana)
    f.manaText:SetShown(hasMana)
    if hasMana then
        local m = UnitPower("player", MANA)
        ns.SetBar(f.manaLine, m, UnitPowerMax("player", MANA))
        ns.SetText(f.manaText, m)
    end
end

----------------------------------------------------------------------
-- 가운데: 전투 시간 (전투 중에만 표시, 숫자 + 분홍 줄)
----------------------------------------------------------------------
local function CreateCenter(hud)
    local c = CreateFrame("Frame", nil, hud)
    c:SetSize(GAP, 100)
    c:SetPoint("TOP", hud, "TOP", 0, -12)

    c.text = ns.Num(c, 50, C.tx)
    c.text:SetPoint("TOP", c, "TOP", 0, 0)
    c.text:SetShadowColor(0, 0, 0, 0.7)
    c.text:SetShadowOffset(0, -3)

    c.rule = ns.Tex(c, "ARTWORK", 0, ns.MEDIA .. "pill32", C.acc)
    c.rule:SetSize(56, 3)
    c.rule:SetPoint("TOP", c.text, "BOTTOM", 0, -6)

    c.sub = ns.Font(c, 11, C.tx2)
    c.sub:SetPoint("TOP", c.rule, "BOTTOM", 0, -6)

    -- 전투 중에만 보임 (전투 시간 타이머)
    function c:Idle()
        self:SetScript("OnUpdate", nil)
        self:Hide()
        self.text:SetText("VS")
        self.text:SetTextColor(C.acc[1], C.acc[2], C.acc[3])
        self.sub:SetText("전투 전")
    end

    function c:Fight()
        local start, acc = GetTime(), 0
        self.text:SetTextColor(C.tx[1], C.tx[2], C.tx[3])
        self.sub:SetText("전투 시간")
        self.text:SetText("0")
        self:Show()
        self:SetScript("OnUpdate", function(s, el)
            acc = acc + el
            if acc < 0.2 then return end
            acc = 0
            local t = math.floor(GetTime() - start)
            if t < 100 then
                s.text:SetText(t)
            else
                s.text:SetFormattedText("%d:%02d", t / 60, t % 60)
            end
        end)
    end

    c:Idle()
    return c
end

----------------------------------------------------------------------
-- 펫 프레임 (사냥꾼 등): 플레이어 아래, 작은 둥근 초상화 + 알약 바 + 집중력 줄
----------------------------------------------------------------------
local PET_POR, PET_BAR = 60, 190
local FOCUS = { 1, 0.69, 0.44 }

local function Chip(parent)
    local c = CreateFrame("Frame", nil, parent)
    c:SetHeight(16)
    c.bg = ns.RoundRect(c, 8, C.acc, "ARTWORK", 0, 0)
    c.fs = ns.Font(c, 11)
    c.fs:SetShadowColor(0, 0, 0, 0)
    c.fs:SetPoint("CENTER", 0, 0)
    function c:Set(text, bg, fg)
        self.fs:SetText(text)
        self.fs:SetTextColor(fg[1], fg[2], fg[3])
        self.bg:SetColor(bg, 1)
        self:SetWidth(self.fs:GetStringWidth() + 16)
        self:Show()
    end
    c:Hide()
    return c
end

local function CreatePet(hud)
    local f = CreateFrame("Button", "LeelUI_pet", hud, "SecureUnitButtonTemplate")
    f:SetSize(PET_POR + PET_BAR, PET_POR + 4)
    f:SetPoint("TOPLEFT", hud, "TOPLEFT", 14, -(POR_H + 14))
    f:SetAttribute("unit", "pet")
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    f.unit = "pet"

    f.portrait = ns.CreatePortrait(f, PET_POR, PET_POR)
    f.portrait:SetPoint("TOPLEFT")

    f.name = ns.Font(f, 15)
    f.name:SetPoint("TOPLEFT", f, "TOPLEFT", PET_POR + 6, -2)
    f.lvLabel = ns.Font(f, 11, C.tx2)
    f.lvLabel:SetText("LV")
    f.lvLabel:SetPoint("BOTTOMLEFT", f.name, "BOTTOMRIGHT", 8, 1)
    f.lv = ns.Num(f, 15, C.tx, false)
    f.lv:SetPoint("BOTTOMLEFT", f.lvLabel, "BOTTOMRIGHT", 2, -1)
    f.chip = Chip(f)
    f.chip:SetPoint("LEFT", f.lv, "RIGHT", 8, 1)

    f.hp = ns.CreateSkewBar(f, PET_BAR, 18, { inset = 2, noShadow = true })
    f.hp:SetPoint("TOPLEFT", f, "TOPLEFT", PET_POR - 8, -22)
    ns.PaintHealth(f.hp)
    f.hpValue = ns.Num(f.hp.over, 15, C.ink)
    f.hpValue:SetShadowColor(0, 0, 0, 0)
    f.hpValue:SetPoint("LEFT", f.hp, "LEFT", 16, 0)
    f.hpPct = f.hp.over:CreateFontString(nil, "OVERLAY")
    f.hpPct:SetFont(ns.NUM, 12, "OUTLINE")
    f.hpPct:SetPoint("RIGHT", f.hp, "RIGHT", -10, 0)

    f.focus = CreateFrame("StatusBar", nil, f)
    f.focus:SetSize(PET_BAR * 0.7, 4)
    f.focus:SetPoint("TOPLEFT", f.hp, "BOTTOMLEFT", 12, -5)
    f.focus:SetStatusBarTexture(ns.MEDIA .. "pill32")
    f.focus:SetStatusBarColor(FOCUS[1], FOCUS[2], FOCUS[3])
    local fbg = ns.Tex(f.focus, "BACKGROUND", 0, ns.MEDIA .. "pill32", { 1, 1, 1 }, 0.12)
    fbg:SetAllPoints()
    return f
end

local function UpdatePet(f)
    if not UnitExists("pet") then return end
    ns.SetText(f.name, UnitName("pet"))
    ns.SetText(f.lv, UnitLevel("pet"))
    SetPortraitTexture(f.portrait.tex, "pet")

    local cur, max = UnitHealth("pet"), UnitHealthMax("pet")
    ns.SetBar(f.hp.bar, cur, max)
    ns.SetText(f.hpValue, cur)
    ns.HealthPercentText(f.hpPct, "pet", cur, max)
    local pType = UnitPowerType("pet")
    ns.SetBar(f.focus, UnitPower("pet", pType), UnitPowerMax("pet", pType))

    local dead = Try(UnitIsDead, "pet")
    local aggro = Try(function()
        local st = UnitThreatSituation("pet")
        return st and st >= 2
    end)
    local fighting = Try(UnitAffectingCombat, "pet")

    f.portrait.tex:SetDesaturated(dead)
    f.hpValue:SetShown(not dead)
    f.hpPct:SetShown(not dead)
    if dead then
        f.portrait.cut:SetVertexColor(C.grey[1], C.grey[2], C.grey[3], 1)
        f.hp.border:SetVertexColor(C.edge[1], C.edge[2], C.edge[3], C.edge[4])
        f.chip:Set("쓰러짐", { 0.23, 0.2, 0.21 }, { 0.84, 0.82, 0.8 })
    elseif aggro then
        f.portrait.cut:SetVertexColor(C.dmg[1], C.dmg[2], C.dmg[3], 1)
        f.hp.border:SetVertexColor(C.dmg[1], C.dmg[2], C.dmg[3], 1)
        f.chip:Set("맞는 중", C.dmg, { 1, 1, 1 })
    else
        f.portrait.cut:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
        f.hp.border:SetVertexColor(C.edge[1], C.edge[2], C.edge[3], C.edge[4])
        if fighting then f.chip:Set("공격 중", C.acc, C.ink) else f.chip:Hide() end
    end
end

----------------------------------------------------------------------
-- 이동 모드 예시 화면: 대상·펫·가운데를 예시 데이터로 띄워서 자리 맞추기 쉽게
----------------------------------------------------------------------
local Q = "Interface\\Icons\\INV_Misc_QuestionMark"

local function Fake(f, name, lvl, cur, max, tex)
    f.name:SetText(name)
    f.name:SetTextColor(C.tx[1], C.tx[2], C.tx[3])
    if f.cls then
        f.cls:Hide()
        PlaceHpValue(f, false)
    end
    f.lv:SetText(lvl)
    f.lv:SetTextColor(C.tx[1], C.tx[2], C.tx[3])
    f.portrait.tex:SetTexture(tex or Q)
    f.portrait.tex:SetDesaturated(false)
    f.hp.bar:SetMinMaxValues(0, max)
    f.hp.bar:SetValue(cur)
    f.hp:SetAlpha(1); f.name:SetAlpha(1)
    f.hpValue:SetText(cur); f.hpValue:Show()
    f.hpPct:SetFormattedText("%d%%", math.floor(cur / max * 100 + 0.5)); f.hpPct:Show()
    if f.state then f.state:Hide() end
    if f.loot then f.loot:Hide() end
end

function ns:SetPreview(on)
    local fr = ns.hudFrames
    if not fr then return end
    if on then
        if InCombatLockdown() then return end
        UnregisterUnitWatch(fr.target); fr.target:Show()
        UnregisterUnitWatch(fr.pet); fr.pet:Show()
        Fake(fr.target, "대상 예시", 25, 620, 1000)
        Fake(fr.pet, "펫 예시", 25, 860, 1000)
        fr.pet.focus:SetMinMaxValues(0, 100); fr.pet.focus:SetValue(70)
        fr.pet.chip:Hide()
        fr.center.text:SetText("42")
        fr.center.text:SetTextColor(C.tx[1], C.tx[2], C.tx[3])
        fr.center.sub:SetText("예시 화면")
        fr.center:Show()
        if ns.SetCastPreview then ns:SetCastPreview(true) end
    else
        if ns.SetCastPreview then ns:SetCastPreview(false) end
        ns:RunOutOfCombat("preview", function()
            RegisterUnitWatch(fr.target)
            RegisterUnitWatch(fr.pet)
        end)
        if not UnitAffectingCombat("player") then fr.center:Idle() end
        fr.refresh()
    end
end

----------------------------------------------------------------------
-- 만들기 + 이벤트
----------------------------------------------------------------------
function ns:CreateHUD()
    local hud = CreateFrame("Frame", "LeelUI_HUD", UIParent)
    hud:SetSize(SIDE_W * 2 + GAP, POR_H + 14 + 64)
    hud:SetMovable(true)
    hud:SetClampedToScreen(true)
    hud:SetScale(ns.db.scale or 0.7)
    ns.hud = hud
    ns:ApplyPosition()

    local player = CreateSide(hud, "player", false)
    AddPlayerExtras(player)
    local target = CreateSide(hud, "target", true)
    AddTargetExtras(target)
    AddTargetPower(target)
    RegisterUnitWatch(target)
    local center = CreateCenter(hud)
    local pet = CreatePet(hud)
    RegisterUnitWatch(pet)

    -- 대상 징표: 대상 초상화 위 가운데
    local raid = target:CreateTexture(nil, "OVERLAY", nil, 7)
    raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    raid:SetSize(30, 30)
    raid:SetPoint("CENTER", target.portrait, "TOP", 0, 2)
    raid:Hide()
    local function UpdateTargetRaid()
        local ok, shown = pcall(function()
            local idx = GetRaidTargetIndex("target")
            if not idx then return false end
            SetRaidTargetIconTexture(raid, idx)
            return true
        end)
        raid:SetShown(ok and shown or false)
    end
    local rev = CreateFrame("Frame")
    rev:RegisterEvent("RAID_TARGET_UPDATE")
    rev:RegisterEvent("PLAYER_TARGET_CHANGED")
    rev:SetScript("OnEvent", UpdateTargetRaid)

    ns:CreateHUDCasts(player, target, BAR_X)
    ns:CreateMover(hud)

    local frames = { player = player, target = target, pet = pet }

    local function All(f)
        if not UnitExists(f.unit) then return end
        UpdateInfo(f)
        UpdateHealth(f)
        if f == player then UpdatePower(f) else UpdateTargetPower(f) end
    end

    ns.hudFrames = {
        player = player, target = target, pet = pet, center = center,
        refresh = function() All(player); All(target); UpdatePet(pet) end,
    }

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("LOOT_CLOSED")
    ev:RegisterEvent("LOOT_OPENED")
    for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_FLAGS",
                         "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED" }) do
        ev:RegisterUnitEvent(e, "player", "target")
    end
    for _, e in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
        ev:RegisterUnitEvent(e, "player", "target")
    end
    -- 펫 이벤트는 따로 받음 (같은 이벤트를 다른 유닛으로 다시 등록하면 플레이어/대상 등록이 덮어써짐)
    local petEv = CreateFrame("Frame")
    petEv:RegisterUnitEvent("UNIT_PET", "player")
    for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER",
                         "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_PORTRAIT_UPDATE", "UNIT_FLAGS",
                         "UNIT_THREAT_SITUATION_UPDATE" }) do
        pcall(petEv.RegisterUnitEvent, petEv, e, "pet")
    end
    petEv:SetScript("OnEvent", function()
        if not ns.moving then UpdatePet(pet) end
    end)

    ev:SetScript("OnEvent", function(_, event, unit)
        if ns.moving then return end   -- 이동 모드 중엔 예시 화면 유지
        if event == "PLAYER_ENTERING_WORLD" then
            All(player); All(target); UpdatePet(pet)
        elseif event == "PLAYER_TARGET_CHANGED" then
            target.tapped = nil
            All(target)
        elseif event == "LOOT_CLOSED" or event == "LOOT_OPENED" then
            -- 창이 닫힌 직후엔 아직 줍기 상태가 안 바뀌어 있을 수 있어 한 번 더 확인
            if UnitExists("target") then UpdateDead(target) end
            C_Timer.After(0.4, function()
                if not ns.moving and UnitExists("target") then UpdateDead(target) end
            end)
        elseif event == "PLAYER_REGEN_DISABLED" then
            center:Fight(); UpdatePet(pet)
        elseif event == "PLAYER_REGEN_ENABLED" then
            center:Idle(); UpdatePet(pet)
        else
            local f = frames[unit]
            if not f then return end
            if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS" then
                UpdateHealth(f)
            elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
                if f == player then UpdatePower(f) else UpdateTargetPower(f) end
            else
                UpdateInfo(f)
            end
        end
    end)
end
