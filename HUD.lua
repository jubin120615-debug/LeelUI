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
local function CreateSide(hud, unit, mirrored, preview)
    local A  = mirrored and "TOPRIGHT" or "TOPLEFT"
    local sx = mirrored and -1 or 1
    local J  = mirrored and "RIGHT" or "LEFT"

    -- preview = 허브 미리 보기용 모형 (보통 프레임 · 클릭 없음, 생김새는 진짜와 같아요)
    local f = preview and CreateFrame("Frame", nil, hud)
        or CreateFrame("Button", "LeelUI_" .. unit, hud, "SecureUnitButtonTemplate")
    f.isPv = preview and true or false
    f:SetSize(SIDE_W, 140)
    f:SetPoint(A, hud, A, 0, 0)
    if not preview then
        f:SetAttribute("unit", unit)
        f:SetAttribute("*type1", "target")
        f:SetAttribute("*type2", "togglemenu")
        f:RegisterForClicks("AnyUp")
    end
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
    ns.PaintHealthRed(f.hp)

    -- 받을 치유: 체력 끝에서 이어서 민트 빗금 (바 모양 밖은 잘림)
    do
        local sb = f.hp.bar
        local hb = CreateFrame("StatusBar", nil, f.hp)
        hb:SetFrameLevel(sb:GetFrameLevel() + 1)
        hb:SetSize(BAR_W - 4, BAR_H - 4)
        f.hp.heal = hb
        if mirrored then
            hb:SetPoint("TOPRIGHT", f.hp.fill, "TOPLEFT", 0, 0)
            hb:SetReverseFill(true)
        else
            hb:SetPoint("TOPLEFT", f.hp.fill, "TOPRIGHT", 0, 0)
        end
        hb:SetStatusBarTexture(ns.WHITE)
        hb:SetStatusBarColor(0.50, 0.84, 0.76, 0.85)
        hb:SetMinMaxValues(0, 1); hb:SetValue(0)
        local m = hb:CreateMaskTexture()
        m:SetTexture(ns.MEDIA .. f.hp.shapeName, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(sb)
        hb:GetStatusBarTexture():AddMaskTexture(m)
        local st = hb:CreateTexture(nil, "OVERLAY")
        st:SetTexture(ns.MEDIA .. "stripes", "REPEAT", "REPEAT")
        st:SetHorizTile(true); st:SetVertTile(true)
        st:SetAllPoints(hb:GetStatusBarTexture())
        st:SetVertexColor(1, 1, 1, 0.3)
        st:AddMaskTexture(m)
        f.heal = hb
    end

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

    f.hpValue = ns.Num(f.hp.over, 23, { 1, 0.953, 0.953 })
    f.hpValue:SetShadowColor(0.35, 0.06, 0.1, 0.8); f.hpValue:SetShadowOffset(1, -1)
    f.hpPct = ns.Num(f.hp.over, 15, { 1, 0.86, 0.86 })
    f.hpPct:SetShadowColor(0.35, 0.06, 0.1, 0.8); f.hpPct:SetShadowOffset(1, -1)
    -- 숫자는 초상화 쪽 끝, %는 바깥쪽 끝 (대상은 거울처럼)
    if mirrored then
        f.hpValue:SetPoint("RIGHT", f.hp, "RIGHT", -20, 0)
        f.hpPct:SetPoint("LEFT", f.hp, "LEFT", 14, 0)
    else
        f.hpValue:SetPoint("LEFT", f.hp, "LEFT", 20, 0)
        f.hpPct:SetPoint("RIGHT", f.hp, "RIGHT", -14, 0)
    end
    f.hpBase = { 23, 15 }
    f.nameBase, f.lvBase, f.lvLabelBase = 18, 18, 13
    if ns.ApplyHpTextSize then ns.ApplyHpTextSize(f) end

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
    local show = ok and ((not okc) or res) and not (ns.db and ns.db.tPowerOff) and true or false
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
    -- 위협 빛 · 디버프 줄 보이기/크기 · 연계 점수 칸 (허브 > 대상 창)
    if ns.HudTargetExtras then ns.HudTargetExtras(f) end
    if ns.HudTargetCombo then ns.HudTargetCombo(f) end
    if ns.HudTargetAuras then ns.HudTargetAuras(f) end
end

----------------------------------------------------------------------
-- 갱신
----------------------------------------------------------------------
local function SameGUID(a, b)
    local ok, r = pcall(function() return a ~= nil and a == b end)
    return ok and r or false
end

-- 대상 창 설정 (허브 > Leel HUD > 대상 창): ns.db.tgt
--   rankOn 등급 테두리 · nameCol "react"|"white" · lvCol "diff"|"white" · threatOn 위협 빛
--   deadKeep 죽어도 회색 안 함 · debOff · buffOff · debScale · castIntOnly
local TGT_DEF = { nameCol = "white", lvCol = "diff", debScale = 100 }   -- 처음 값 = 예전 모습 그대로
function ns.TgtOpt(k)
    local t = ns.db and ns.db.tgt
    local v = t and t[k]
    if v == nil then v = TGT_DEF[k] end
    return v
end

local function UpdateDead(f)
    local dead = Try(UnitIsDeadOrGhost, f.unit)
    if f.unit == "target" and ns.TgtOpt("deadKeep") then dead = false end
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

local function UpdateHeal(f)
    local hb = f.heal
    if not hb then return end
    local u = f.unit
    if not UnitExists(u) or Try(UnitIsDeadOrGhost, u) then hb:SetValue(0) return end
    local ok, inc = pcall(UnitGetIncomingHeals or function() end, u)
    pcall(hb.SetMinMaxValues, hb, 0, UnitHealthMax(u))
    if not ok or inc == nil or not pcall(hb.SetValue, hb, inc) then hb:SetValue(0) end
end

local function UpdateHealth(f)
    local u = f.unit
    if not UnitExists(u) then return end
    local cur, max = UnitHealth(u), UnitHealthMax(u)
    ns.SetBar(f.hp.bar, cur, max)
    UpdateHeal(f)
    ns.SetText(f.hpValue, cur)
    ns.HealthPercentText(f.hpPct, u, cur, max)
    if f.mirrored then
        local tapped = UnitIsTapDenied and Try(UnitIsTapDenied, u) or false
        if tapped ~= f.tapped then
            -- 선점이 바뀌면 레벨이 달라질 수 있어(레벨 맞춤) 이름·레벨을 다시 읽음
            if f.tapped ~= nil and ns.HudRefreshInfo then pcall(ns.HudRefreshInfo, f) end
            f.tapped = tapped
            ns.SetTapped(f.hp, tapped)
            ns.SetStrike(f.name, tapped)
            if not tapped then ns.PaintHealthRed(f.hp) end
        end
    end
    UpdateDead(f)
end

-- 체력 숫자: 직업 캡이 있으면 캡에 안 가리게 안쪽으로
-- 체력 숫자 · % 글씨 크기 (허브 > 위쪽 HUD > 체력 글씨 크기: +0 ~ +8)
-- 글씨 · 바를 조각마다 하나씩 (허브 > Leel HUD > 내 창 · 대상 창)
--   name 이름 · lv 레벨 · hp 체력 숫자 · pct % · bar 체력 바 두께 · sub 자원 글씨 (+더할 크기)
--   아직 안 만진 칸은 예전 '글씨 강조' 값에서 시작해요
function ns.HudTextAdd(unit, k)
    local db = ns.db or {}
    local side = (unit == "target") and "target" or "player"
    local t = db.hudText and db.hudText[side]
    if t and tonumber(t[k]) then return tonumber(t[k]) end
    local own = (side == "target") and db.hpTextAddT or db.hpTextAddP
    local add = tonumber(own) or tonumber(db.hpTextAdd) or 0
    if k == "pct" or k == "sub" then return math.floor(add * 0.75 + 0.5) end
    return add
end
-- 체력 숫자 · % 보이기 (예전 '숫자 / % / 둘 다' 값에서 시작)
function ns.HudTextShow(unit, k)
    local db = ns.db or {}
    local side = (unit == "target") and "target" or "player"
    local t = db.hudText and db.hudText[side]
    if t and t[k] ~= nil then return t[k] and true or false end
    local mode = ((side == "target") and db.hpShowT or db.hpShowP) or "both"
    if k == "showHp" then return mode ~= "pct" end
    if k == "showPct" then return mode ~= "num" end
    return true
end
-- 마나 · 기력 바 (허브 > Leel HUD > 내 창 · 대상 창)
--   powH 두께 · powW 길이(%) · showPow 바 보이기 · showPowTx 숫자 보이기 · powTicks 눈금
function ns.HudPow(unit, k)
    local side = (unit == "target") and "target" or "player"
    local t = ns.db and ns.db.hudText and ns.db.hudText[side]
    local v = t and t[k]
    if k == "powH" then return tonumber(v) or (side == "target" and 4 or 6) end
    if k == "powW" then return tonumber(v) or 100 end
    return v ~= false
end
function ns.SetHudText(side, k, v)
    ns.db.hudText = ns.db.hudText or {}
    ns.db.hudText[side] = ns.db.hudText[side] or {}
    ns.db.hudText[side][k] = v
    local fr = ns.hudFrames
    if fr and fr[side] then
        ns.ApplyHpTextSize(fr[side])
        if (k == "porArt" or k == "porFace") and ns.HudRefreshInfo then pcall(ns.HudRefreshInfo, fr[side]) end
    end
end

function ns.ApplyHpTextSize(f)
    if not (f and f.hpValue and f.hpBase) then return end
    local u = f.unit
    local A = function(k) return ns.HudTextAdd(u, k) end
    local aName, aLv, aHp, aPct, aBar, aSub = A("name"), A("lv"), A("hp"), A("pct"), A("bar"), A("sub")
    f.hpValue:SetAlpha(ns.HudTextShow(u, "showHp") and 1 or 0)
    if f.hpPct then f.hpPct:SetAlpha(ns.HudTextShow(u, "showPct") and 1 or 0) end
    local file = ns.NUM
    -- 체력 바 두께 (위아래로 반씩 늘려서 이름 · 아래 줄과 안 겹치게)
    if f.hp and f.nameA then
        f.hp:SetHeight(math.max(6, BAR_H + aBar))
        f.hp:ClearAllPoints()
        f.hp:SetPoint(f.nameA, f, f.nameA, BAR_X * (f.nameSx or 1), -34 + math.floor(aBar / 2 + 0.5))
        if f.hp.heal then f.hp.heal:SetHeight(math.max(4, BAR_H - 4 + aBar)) end
    end
    local function Sz(base, add) return math.max(6, base + add) end
    if not f.hpValue:SetFont(file, Sz(f.hpBase[1], aHp), "") then f.hpValue:SetFont(ns.FONT, Sz(f.hpBase[1], aHp), "") end
    if not f.hpPct:SetFont(file, Sz(f.hpBase[2], aPct), "") then f.hpPct:SetFont(ns.FONT, Sz(f.hpBase[2], aPct), "") end
    -- 이름 (글꼴을 바꿔도 이 크기를 지키게 TrackText에 새 크기로 다시 알려요)
    if f.name and f.nameBase then
        local ns_ = Sz(f.nameBase, aName)
        f.name:SetFont(ns.FONT, ns_, "")
        -- 커진 만큼 이름 줄을 위로 (체력 바 두께도 같이 봐요)
        if f.nameA then
            local up = math.max(aName * 0.8, aBar / 2)
            f.name:ClearAllPoints()
            f.name:SetPoint(f.nameA, f, f.nameA, (POR_W + 6) * (f.nameSx or 1), -6 + math.floor(up + 0.5))
        end
        if ns.TrackText then ns.TrackText(f.name, ns_, "") end
    end
    if f.lv and f.lvBase then
        local lvFile = ns.NUM_B or ns.NUM
        if not f.lv:SetFont(lvFile, Sz(f.lvBase, aLv), "") then f.lv:SetFont(ns.FONT, Sz(f.lvBase, aLv), "") end
    end
    if f.lvLabel and f.lvLabelBase then
        local la = Sz(f.lvLabelBase, math.floor(aLv * 0.75 + 0.5))
        f.lvLabel:SetFont(ns.FONT, la, "")
        if ns.TrackText then ns.TrackText(f.lvLabel, la, "") end
    end
    -- 아래 줄 (자원 숫자 · 마나/기력/분노 글씨)
    local half = math.floor(aBar / 2 + 0.5)
    if f.power then
        f.power:ClearAllPoints()
        f.power:SetPoint("TOPLEFT", f, "TOPLEFT", BAR_X + 14, -73 - half)
    end
    if f.manaLine then
        f.manaLine:ClearAllPoints()
        f.manaLine:SetPoint("TOPLEFT", f, "TOPLEFT", BAR_X + 12, -90 - half - math.max(0, aSub))
    end
    -- 초상화: 보이기 · 크기 · 테두리 색
    if f.portrait then
        local T = (ns.db and ns.db.hudText and ns.db.hudText[(u == "target") and "target" or "player"]) or {}
        f.portrait:SetAlpha(T.porOff and 0 or 1)
        f.portrait:SetScale(math.max(0.4, (tonumber(T.porScale) or 100) / 100))
        if ns.HudPorEdge then ns.HudPorEdge(f) end
    end
    -- 마나 · 기력 바: 두께 · 길이 · 눈금 · 보이기
    do
        local pH, pW = ns.HudPow(u, "powH"), ns.HudPow(u, "powW")
        local showBar, showTx = ns.HudPow(u, "showPow"), ns.HudPow(u, "showPowTx")
        if f.power then
            local w = math.floor(220 * pW / 100 + 0.5)
            f.power:SetSize(w, pH)
            local tk = f.power.ticks
            if tk then
                local on = ns.HudPow(u, "powTicks")
                for i, t in ipairs(tk) do
                    t:SetSize(1, pH); t:ClearAllPoints(); t:SetPoint("LEFT", w * i / (#tk + 1), 0); t:SetShown(on)
                end
            end
            f.power:SetAlpha(showBar and 1 or 0)
            if f.powerText then f.powerText:SetAlpha(showTx and 1 or 0) end
        end
        if f.tpower then
            f.tpower:SetSize(math.floor(200 * pW / 100 + 0.5), pH)
            f.tpower:SetAlpha(showBar and 1 or 0)
            if f.tpowerText then f.tpowerText:SetAlpha(showTx and 1 or 0) end
            if f.tpowerLabel then f.tpowerLabel:SetAlpha(showTx and 1 or 0) end
        end
    end
    for _, k in ipairs({ "powerText", "manaText", "tpowerText", "manaLabel", "tpowerLabel" }) do
        local fs = f[k]
        if fs then
            f.subBase = f.subBase or {}
            if not f.subBase[k] then
                local file2, size = fs:GetFont()
                f.subBase[k] = { file = file2, size = size or 12 }
            end
            local b = f.subBase[k]
            local sz = Sz(b.size, aSub)
            if not (b.file and fs:SetFont(b.file, sz, "")) then fs:SetFont(ns.FONT, sz, "") end
            if (k == "manaLabel" or k == "tpowerLabel") and ns.TrackText then ns.TrackText(fs, sz, "") end
        end
    end
end
function ns.SetHpTextAdd(v, which)
    if which == "player" then ns.db.hpTextAddP = v
    elseif which == "target" then ns.db.hpTextAddT = v
    else ns.db.hpTextAdd = v end
    local fr = ns.hudFrames
    if fr then
        for _, k in ipairs({ "player", "target" }) do if fr[k] then ns.ApplyHpTextSize(fr[k]) end end
    end
end

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
ns.HudClassColorOf = function(u) local f = ClassOf(u); return f and ClassColor(f) end

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
        local col = C.tx
        -- 대상 이름 색: 적 빨강 · 중립 노랑 · 아군 초록 (플레이어는 위에서 직업 색)
        if f.unit == "target" and ns.TgtOpt("nameCol") == "react" then
            local ok, r = pcall(UnitReaction, "player", "target")
            if ok and type(r) == "number" and not ns.IsSecret(r) then
                if r <= 3 then col = { 1, 0.45, 0.45 } elseif r == 4 then col = { 1, 0.86, 0.4 } else col = { 0.55, 0.9, 0.55 } end
            end
        end
        f.name:SetTextColor(col[1], col[2], col[3])
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
        if u ~= "player" and getColor and lvl and not (u == "target" and ns.TgtOpt("lvCol") == "white") then
            local d = getColor(lvl); c = { d.r, d.g, d.b }
        end
    end
    f.lv:SetTextColor(c[1], c[2], c[3])

    -- 초상화는 늘 얼굴 (직업 아이콘은 체력 바 앞에 따로 있어요)
    f.portrait.tex:SetTexCoord(0, 1, 0, 1)
    -- 내 창: 허브에서 "르엘 토끼"를 고르면 캐릭터 얼굴 대신 토끼 (시연 그림과 같은 토끼)
    local PT = ns.db and ns.db.hudText and ns.db.hudText.player
    if u == "player" and PT and PT.porFace == "bunny" then f.portrait.tex:SetTexture(ns.MEDIA .. "pv_leel")
    else SetPortraitTexture(f.portrait.tex, u) end
    if ns.HudPorEdge then ns.HudPorEdge(f) end
end
ns.HudRefreshInfo = UpdateInfo

-- 초상화 테 색: 분홍 · 직업 색 · 끔 (+ 대상 등급 테두리: 정예 · 보스 = 금테 · 희귀 = 은테)
--   대상이 바뀔 때마다 다시 칠해요 (직업 색 · 등급이 대상마다 달라서)
function ns.HudPorEdge(f)
    if not (f and f.portrait and f.portrait.cut) then return end
    local side = (f.unit == "target") and "target" or "player"
    local T = (ns.db and ns.db.hudText and ns.db.hudText[side]) or {}
    local edge = T.porEdge or "pink"
    local col = C.acc
    if edge == "class" and ns.HudClassColorOf then
        -- 미리 보기 모형(르엘)은 내 직업 색으로
        col = ns.HudClassColorOf((f.isPv and "player") or side) or C.acc
    end
    if side == "target" and not f.isPv and ns.TgtOpt("rankOn") and UnitExists("target") then
        local ok, c = pcall(UnitClassification, "target")
        if ok and type(c) == "string" and not ns.IsSecret(c) then
            if c == "elite" or c == "worldboss" or c == "rareelite" then col, edge = { 1, 0.83, 0.42 }, "rank"
            elseif c == "rare" then col, edge = { 0.82, 0.86, 0.92 }, "rank" end
        end
    end
    if edge == "off" then f.portrait.cut:SetAlpha(0) return end
    f.portrait.cut:SetAlpha(1)
    f.portrait.cut:SetVertexColor(col[1], col[2], col[3], 1)
end
ns.HudRankEdge = ns.HudPorEdge

-- 대상 창 위협 빛 (켰을 때만)
function ns.HudTargetExtras(f)
    if not f or f.thrGlow then return end
    local g = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    g:SetTexture(ns.MEDIA .. "soft_glow"); g:SetBlendMode("ADD")
    g:SetPoint("TOPLEFT", f.portrait, "TOPLEFT", -22, 22); g:SetPoint("BOTTOMRIGHT", f.portrait, "BOTTOMRIGHT", 22, -22)
    g:SetVertexColor(1, 0.23, 0.29, 0.9); g:Hide()
    f.thrGlow = g
    local function Threat()
        local on = false
        if ns.TgtOpt("threatOn") and UnitExists("target") then
            local ok, st = pcall(UnitThreatSituation, "player", "target")
            if ok and type(st) == "number" and not ns.IsSecret(st) then on = st >= 2 end
        end
        g:SetShown(on)
    end
    f.tgtExtras = function() Threat() end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED"); ev:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function() Threat() end)
end

-- 연계 점수 칸 (도적 · 표범 드루): 체력 바 바로 밑 기울어진 칸 5개 · 대상 쪽부터 차요
--   comboOff 끔 · comboH 두께 · comboNum 숫자 · comboRedOff 다 차도 분홍 · comboShow0 0점이어도 보이기
function ns.MakeComboBar(f)
    local h = math.max(4, math.min(14, tonumber(ns.TgtOpt("comboH")) or 7))
    local cb = ns.CreateSkewBar(f, 200, h, { mirrored = true, ticks = 4, inset = 1, noShadow = true })
    cb:SetPoint("TOPRIGHT", f.hp, "BOTTOMRIGHT", -16, -6)
    for _, t in ipairs(cb.ticks or {}) do t:SetWidth(3); t:SetColorTexture(0.05, 0.03, 0.03, 1) end
    -- 빈 칸도 또렷하게: 옅은 분홍 테
    if cb.border then cb.border:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.55) end
    cb.bar:SetMinMaxValues(0, 5); cb.bar:SetValue(0)
    cb.num = ns.Num(cb.over, 13, C.accHi, false); cb.num:SetPoint("RIGHT", cb, "LEFT", -6, 0)
    local glow = cb:CreateTexture(nil, "BACKGROUND", nil, -3)
    glow:SetTexture(ns.MEDIA .. "soft_glow"); glow:SetBlendMode("ADD")
    glow:SetPoint("TOPLEFT", -14, 10); glow:SetPoint("BOTTOMRIGHT", 14, -10)
    glow:SetVertexColor(1, 0.3, 0.25, 1); glow:Hide()
    local ag = glow:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
    local al = ag:CreateAnimation("Alpha"); al:SetFromAlpha(1); al:SetToAlpha(0.25); al:SetDuration(0.6); al:SetSmoothing("IN_OUT")
    -- 칸 자체도 숨쉬어요 (밝은 바닥 위에서는 둘레 빛이 잘 안 보여서)
    local ag2 = cb.bar:CreateAnimationGroup(); ag2:SetLooping("BOUNCE")
    local a2 = ag2:CreateAnimation("Alpha"); a2:SetFromAlpha(1); a2:SetToAlpha(0.35); a2:SetDuration(0.6); a2:SetSmoothing("IN_OUT")
    function cb:SetCount(n)
        local hh = math.max(4, math.min(14, tonumber(ns.TgtOpt("comboH")) or 7))
        self:SetHeight(hh); for _, t in ipairs(self.ticks or {}) do t:SetHeight(hh) end
        ns.SetBar(self.bar, n, 5)
        local full = not ns.TgtOpt("comboRedOff") and ns.Try(function() return n >= 5 end)
        local c = full and { 1, 0.35, 0.29 } or C.acc
        self.bar:SetStatusBarColor(c[1], c[2], c[3], 1)
        -- 기력이 바뀔 때마다 불려서, 이미 숨쉬는 중이면 다시 시작하지 않아요 (계속 처음으로 돌아가 멈춘 것처럼 보였어요)
        if full then
            glow:Show()
            if not ag:IsPlaying() then ag:Play() end
            if not ag2:IsPlaying() then ag2:Play() end
        else
            ag:Stop(); ag2:Stop(); glow:Hide()
        end
        self.num:SetShown(ns.TgtOpt("comboNum") and true or false)
        ns.SetText(self.num, n)
    end
    return cb
end
function ns.HudTargetCombo(f)
    if not f or f.combo then return end
    local cb = ns.MakeComboBar(f)
    cb:Hide()
    f.combo = cb
    local function Shift(D)
        if (ns.ComboShift or 0) == D then return end
        ns.ComboShift = D
        if f.tpower then f.tpower:ClearAllPoints(); f.tpower:SetPoint("TOPRIGHT", f.hp, "BOTTOMRIGHT", -16, -8 - D) end
        local tc = ns.casts and ns.casts.target
        if tc and tc.OnLayout then tc:OnLayout()
        else
            if f.debuffs then pcall(function() f.debuffs:ClearAllPoints(); f.debuffs:SetPoint("TOPRIGHT", f.hp, "BOTTOMRIGHT", -76, -17 - D) end) end
            if f.buffs then pcall(function() f.buffs:ClearAllPoints(); f.buffs:SetPoint("TOPRIGHT", f.hp, "BOTTOMRIGHT", -76, -17 - 36 - 6 - D) end) end
        end
    end
    local function Update()
        local on = not ns.TgtOpt("comboOff") and UnitExists("target") and ns.UsesCombo and ns.UsesCombo()
        if on then
            local n = ns.ComboOn and ns.ComboOn("target")
            if n == nil then on = false
            elseif not ns.TgtOpt("comboShow0") and ns.Try(function() return n <= 0 end) then on = false   -- 0점이면 숨겨요
            else cb:SetCount(n) end
        end
        cb:SetShown(on and true or false)
        Shift(on and (cb:GetHeight() + 6) or 0)
    end
    f.comboUpdate = Update
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED"); ev:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    ev:RegisterUnitEvent("UNIT_POWER_UPDATE", "player"); ev:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", Update)
end

-- 대상의 대상 알약 꾸미기 (허브 > 대상의 대상): 진짜 알약 · 미리 보기 알약 둘 다
--   totPctOff % 끔 · totHpOff 체력 줄 끔 · totMeOn 나를 노리면 강조 · totName 이름 글씨 · totW 길이(%)
--   totStripe "class"|"pink" · totVis "all"|"combat" · totHideMe 나일 땐 숨기기
function ns.StyleToT(tt, me, col, isPv)
    if not (tt and tt.name) then return end
    local O = ns.TgtOpt
    tt.pct:SetShown(not O("totPctOff"))
    tt.hp:SetShown(not O("totHpOff"))
    local f, _, fl = tt.name:GetFont()
    if f then tt.name:SetFont(f, math.max(9, 17 + (tonumber(O("totName")) or 0)), fl or "") end
    -- 배경: 어둡게(처음) · 분홍 · 직업 색(옅게) · 반투명
    if tt.bg then
        local b = O("totBg") or "dark"
        if b == "pink" then tt.bg:SetColor({ 0.36, 0.16, 0.22 }, 0.94)
        elseif b == "class" then
            local cc = col or C.acc
            tt.bg:SetColor({ cc[1] * 0.38, cc[2] * 0.38, cc[3] * 0.38 }, 0.94)
        elseif b == "clear" then tt.bg:SetColor({ 0.078, 0.047, 0.055 }, 0.35)
        else tt.bg:SetColor({ 0.078, 0.047, 0.055 }, 0.92) end
    end
    if O("totStripe") == "pink" then col = nil end
    if tt.stripe then tt.stripe:SetColor(col or C.acc, 1) end
    local hi = me and O("totMeOn") and true or false
    if tt.rim then tt.rim:SetColor(hi and { 1, 0.42, 0.48 } or { 0.29, 0.204, 0.22 }, 1) end
    if not tt.meTag then
        tt.meTag = ns.Font(tt, 12, { 1, 0.42, 0.48 }, "OVERLAY"); tt.meTag:SetText("나")
    end
    tt.meTag:ClearAllPoints()
    if tt.pct:IsShown() then tt.meTag:SetPoint("RIGHT", tt.pct, "LEFT", -6, 0) else tt.meTag:SetPoint("RIGHT", tt, "RIGHT", -10, 2) end
    tt.meTag:SetShown(hi)
    local w = math.floor((tt.baseW or 120) * math.max(60, math.min(200, tonumber(O("totW")) or 100)) / 100 + 0.5)
    if isPv or not InCombatLockdown() then tt:SetWidth(w); tt.name:SetWidth(math.max(30, w - 64)) end
    if not isPv then
        local a = 1
        if O("totVis") == "combat" and not UnitAffectingCombat("player") then a = 0 end
        if me and O("totHideMe") and not O("totMeOn") then a = 0 end
        tt:SetAlpha(a)
    end
end

-- 대상 창 디버프 · 버프 줄 보이기 · 크기
function ns.HudTargetAuras(f)
    if not f then return end
    local sc = math.max(0.5, math.min(1.6, (tonumber(ns.TgtOpt("debScale")) or 100) / 100))
    if f.debuffs then pcall(function() f.debuffs:SetShown(not ns.TgtOpt("debOff")); f.debuffs:SetScale(sc) end) end
    if f.buffs then pcall(function() f.buffs:SetShown(not ns.TgtOpt("buffOff")); f.buffs:SetScale(sc) end) end
end

-- 허브에서 대상 창 설정을 바꿀 때
function ns.SetTgtOpt(k, v)
    ns.db.tgt = ns.db.tgt or {}
    ns.db.tgt[k] = v
    local f = ns.hudFrames and ns.hudFrames.target
    if not f then return end
    if UnitExists("target") then pcall(UpdateInfo, f); pcall(UpdateDead, f) end
    if ns.ApplyHpTextSize then pcall(ns.ApplyHpTextSize, f) end
    if f.tgtExtras then f.tgtExtras() end
    if f.comboUpdate then f.comboUpdate() end
    ns.HudTargetAuras(f)
end

local function UpdatePower(f)
    local pType = UnitPowerType("player")
    local cur, max = UnitPower("player", pType), UnitPowerMax("player", pType)
    ns.SetBar(f.power.bar, cur, max)
    ns.SetText(f.powerText, cur)

    local c, tc = C.accHi, nil
    if pType == ENERGY then
        c = { 1.00, 0.84, 0.30 }   -- 기력: 노랑 (게임 기본 노랑보다 살짝 부드럽게)
    elseif pType == MANA then
        c, tc = C.mana, { 0.56, 0.69, 1 }   -- 마나: 대상 창과 같은 파스텔 파랑
    else
        local pc = PowerBarColor and PowerBarColor[pType]
        if pc then c = { pc.r, pc.g, pc.b } end
    end
    tc = tc or c
    f.power.fill:SetVertexColor(c[1], c[2], c[3], 1)
    f.powerText:SetTextColor(tc[1], tc[2], tc[3])


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

-- 허브 미리 보기: 진짜 위쪽 HUD와 같은 코드로 그린 모형 (내 캐릭터 + 가짜 대상)
function ns.BuildHudPreview(parent)
    local hud = CreateFrame("Frame", nil, parent)
    hud:SetSize(SIDE_W * 2 + GAP, POR_H + 14 + 64)
    local p = CreateSide(hud, "player", false, true)
    AddPlayerExtras(p)
    local t = CreateSide(hud, "target", true, true)
    AddTargetPower(t)
    -- 대상 창 미리 보기 덤: 내 디버프 · 버프 줄 · 시전바 · 위협 빛 · 퀘스트 표시 (허브 > 대상 창 설정대로)
    do
        local function Ring(parent, sz, ring, num)
            local b = CreateFrame("Frame", nil, parent); b:SetSize(sz, sz)
            local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetPoint("TOPLEFT", 3, -3); ic:SetPoint("BOTTOMRIGHT", -3, 3)
            ic:SetTexture(ns.MEDIA .. "circle"); ic:SetVertexColor(0.27, 0.2, 0.3)
            local rg = b:CreateTexture(nil, "OVERLAY"); rg:SetTexture(ns.MEDIA .. "ring"); rg:SetAllPoints(); rg:SetVertexColor(ring[1], ring[2], ring[3], 1)
            local n = ns.Num(b, sz * 0.42, { 1, 1, 1 }); n:SetPoint("CENTER", 0, 0); n:SetText(num)
            return b
        end
        local deb = CreateFrame("Frame", nil, t); deb:SetSize(3 * 42, 36)
        deb:SetPoint("TOPRIGHT", t.hp, "BOTTOMRIGHT", -76, -17)
        for i, n in ipairs({ "12", "8", "3" }) do
            local b = Ring(deb, 36, C.acc, n); b:SetPoint("TOPRIGHT", -(i - 1) * 42, 0)
        end
        local buf = CreateFrame("Frame", nil, t); buf:SetSize(2 * 33, 28)
        buf:SetPoint("TOPRIGHT", deb, "BOTTOMRIGHT", 0, -6)
        for i, n in ipairs({ "30", "" }) do
            local b = Ring(buf, 28, { 0.62, 0.90, 0.76 }, n); b:SetPoint("TOPRIGHT", -(i - 1) * 33, 0)
        end
        -- 대상 시전바: '예전 얇은 바' 모양일 때만 대상 창 체력 바 바로 아래 (토끼 · 발자국은 화면 아래 내 시전바 위)
        local cast = CreateFrame("Frame", nil, t); cast:SetSize(230, 18)
        cast:SetPoint("TOPRIGHT", t.hp, "BOTTOMRIGHT", -14, -7)
        local cbg = ns.RoundRect(cast, 9, { 0.13, 0.1, 0.095 }, "BACKGROUND", 0, 0)
        local cf = CreateFrame("Frame", nil, cast); cf:SetPoint("TOPLEFT"); cf:SetPoint("BOTTOMLEFT"); cf:SetWidth(140)
        ns.RoundRect(cf, 9, C.acc, "ARTWORK", 0, 0)
        local ct = ns.Font(cast, 11, C.ink, "OVERLAY"); ct:SetPoint("LEFT", 10, 0); ct:SetText("화염구"); ct:SetShadowColor(0, 0, 0, 0)
        local cn = ns.Num(cast, 11, C.tx); cn:SetPoint("RIGHT", -8, 0); cn:SetText("1.2")
        local thr = t:CreateTexture(nil, "BACKGROUND", nil, -2)
        thr:SetTexture(ns.MEDIA .. "soft_glow"); thr:SetBlendMode("ADD")
        thr:SetPoint("TOPLEFT", t.portrait, "TOPLEFT", -22, 22); thr:SetPoint("BOTTOMRIGHT", t.portrait, "BOTTOMRIGHT", 22, -22)
        thr:SetVertexColor(1, 0.23, 0.29, 0.9)
        t.pvDeb, t.pvBuf, t.pvCast, t.pvThr = deb, buf, cast, thr
        t.pvCombo = ns.MakeComboBar(t)
    end
    -- 가운데 금빛 귀 + 거리
    local mid = CreateFrame("Frame", nil, hud)
    mid:SetSize(GAP, 120); mid:SetPoint("TOP", hud, "TOP", 0, -6)
    local e1 = mid:CreateTexture(nil, "ARTWORK"); e1:SetTexture(ns.MEDIA .. "ear_gold"); e1:SetSize(34, 62)
    e1:SetPoint("BOTTOMRIGHT", mid, "TOP", -2, -64); e1:SetTexCoord(1, 0, 0, 1)
    local e2 = mid:CreateTexture(nil, "ARTWORK"); e2:SetTexture(ns.MEDIA .. "ear_gold"); e2:SetSize(34, 62)
    e2:SetPoint("BOTTOMLEFT", mid, "TOP", 2, -64)
    local dist = ns.Num(mid, 40, { 1, 1, 1 }); dist:SetPoint("TOP", mid, "TOP", 0, -64)
    local sub = ns.Font(mid, 12, C.tx2); sub:SetPoint("TOP", dist, "BOTTOM", 0, -2)
    -- 비전투 모습: 짧은 귀 + zzz (진짜 가운데와 같은 그림)
    local il = mid:CreateTexture(nil, "ARTWORK"); il:SetTexture(ns.MEDIA .. "ear_short_l"); il:SetSize(42, 42); il:SetPoint("BOTTOM", mid, "TOP", 0, -66)
    local ir = mid:CreateTexture(nil, "ARTWORK"); ir:SetTexture(ns.MEDIA .. "ear_short_r"); ir:SetSize(42, 42); ir:SetPoint("BOTTOM", mid, "TOP", 0, -66)
    local zzz = {}
    for i = 1, 3 do
        local z = ns.Font(mid, 10 + i, { 0.8, 0.73, 0.71 }); z:SetText("z")
        z:SetPoint("BOTTOMLEFT", mid, "TOP", 10 + i * 7, -40 + i * 9)
        local ag = z:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
        local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(0.15); a:SetToAlpha(0.85); a:SetDuration(0.9 + i * 0.25); a:SetSmoothing("IN_OUT")
        z.ag = ag; zzz[i] = z
    end
    -- 전투 모습(각성): 금빛 귀 뒤 빛 + 노란 번개
    local glow = mid:CreateTexture(nil, "BACKGROUND"); glow:SetTexture(ns.MEDIA .. "soft_glow"); glow:SetBlendMode("ADD")
    glow:SetSize(150, 150); glow:SetPoint("CENTER", mid, "TOP", 0, -40); glow:SetVertexColor(1, 0.85, 0.45, 0.55)
    local bolts = {}
    for i, b in ipairs({ { -34, -18, "bolt1", -20 }, { 36, -14, "bolt2", 25 }, { -46, -52, "bolt2", -10 }, { 46, -50, "bolt1", 15 } }) do
        local tx = mid:CreateTexture(nil, "OVERLAY"); tx:SetTexture(ns.MEDIA .. b[3]); tx:SetBlendMode("ADD"); tx:SetSize(14, 28)
        tx:SetPoint("CENTER", mid, "TOP", b[1], b[2]); tx:SetRotation(math.rad(b[4])); tx.home = { b[1], b[2] }
        local ag = tx:CreateAnimationGroup(); ag:SetLooping("REPEAT")
        local a1 = ag:CreateAnimation("Alpha"); a1:SetFromAlpha(0); a1:SetToAlpha(1); a1:SetDuration(0.05); a1:SetStartDelay(i * 0.35); a1:SetOrder(1)
        local a2 = ag:CreateAnimation("Alpha"); a2:SetFromAlpha(1); a2:SetToAlpha(0); a2:SetDuration(0.25); a2:SetOrder(2)
        local a3 = ag:CreateAnimation("Alpha"); a3:SetFromAlpha(0); a3:SetToAlpha(0); a3:SetDuration(1.2); a3:SetOrder(3)
        tx:SetAlpha(0); tx.ag = ag; bolts[i] = tx
    end
    hud.p, hud.t, hud.mid = p, t, mid
    hud.midNum, hud.midSub, hud.midEarIdle, hud.midEarGold, hud.midGlow = dist, sub, il, e1, glow
    -- 양쪽 귀를 한 번에 감싸는 틀 (허브 강조용 · 그림 없음)
    local earBox = CreateFrame("Frame", nil, mid)
    hud.midEarBox = earBox
    -- 실제 가운데와 같은 모양: 작은 m · 분홍 줄 · 거리 점 4개 · 빛줄기 · 안내 글씨
    local unitm = ns.Num(mid, 18, { 1, 1, 1 }); unitm:SetPoint("BOTTOMLEFT", dist, "BOTTOMRIGHT", 1, 4)
    local rule = mid:CreateTexture(nil, "ARTWORK"); rule:SetTexture(ns.MEDIA .. "pill32"); rule:SetSize(46, 3)
    rule:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1); rule:SetPoint("TOP", dist, "BOTTOM", 0, -6)
    local pdots = {}
    for i = 1, 4 do
        local d = mid:CreateTexture(nil, "ARTWORK", nil, 1); d:SetTexture(ns.MEDIA .. "circle"); d:SetSize(8, 8)
        d:SetPoint("CENTER", rule, "CENTER", (i - 2.5) * 12, 0); pdots[i] = d
    end
    sub:ClearAllPoints(); sub:SetPoint("TOP", rule, "BOTTOM", 0, -9)
    local streaks = {}
    for i, x in ipairs({ -30, -14, 0, 15, 31 }) do
        local t2 = mid:CreateTexture(nil, "BACKGROUND", nil, 1); t2:SetTexture(ns.MEDIA .. "streak"); t2:SetBlendMode("ADD")
        t2:SetSize(3, 30 + (i * 11) % 20); t2:SetVertexColor(1, 0.843, 0.353); t2:SetPoint("BOTTOM", mid, "TOP", x, -118)
        local ag = t2:CreateAnimationGroup(); ag:SetLooping("REPEAT")
        local d = 1.1 + (i % 3) * 0.3
        local mv = ag:CreateAnimation("Translation"); mv:SetOffset(0, 40); mv:SetDuration(d); mv:SetOrder(1)
        local fi = ag:CreateAnimation("Alpha"); fi:SetFromAlpha(0); fi:SetToAlpha(0.7); fi:SetDuration(d * 0.35); fi:SetOrder(1)
        local fo = ag:CreateAnimation("Alpha"); fo:SetFromAlpha(0.7); fo:SetToAlpha(0); fo:SetStartDelay(d * 0.55); fo:SetDuration(d * 0.45); fo:SetOrder(1)
        t2.ag = ag; streaks[i] = t2
    end
    local note = ns.Font(mid, 12, { 0.48, 0.4, 0.38 }); note:SetPoint("TOP", mid, "TOP", 0, -80); note:SetJustifyH("CENTER")
    local dbox = CreateFrame("Frame", nil, mid); dbox:SetPoint("TOPLEFT", pdots[1], "TOPLEFT"); dbox:SetPoint("BOTTOMRIGHT", pdots[4], "BOTTOMRIGHT")
    hud.midDots = dbox
    -- 펫 창 (진짜와 같은 모양) · 내 창 아래
    local pet = ns.HudPetPreview and ns.HudPetPreview(hud)
    if pet then
        pet.portrait.tex:SetTexture("Interface\\Icons\\Ability_Hunter_Pet_Cat")
        pet.name:SetText("펫 예시"); pet.lv:SetText("25"); pet.chip:Hide()
        pet.hp.bar:SetMinMaxValues(0, 1000); pet.hp.bar:SetValue(860)
        pet.hpValue:SetText("860"); pet.hpPct:SetText("86%")
        pet.focus:SetMinMaxValues(0, 100); pet.focus:SetValue(70)
        pet:EnableMouse(false)
        -- 만족도 얼굴 (설정대로) · 켜 둔 채 그 줄에 마우스를 올리면 불만 얼굴 + 빨간 빛 (끄면 마우스를 올려도 없음)
        function pet:PvMood()
            local off = ns.db and ns.db.petMoodOff
            local sad = ns.hudPvPeek == "mood"
            if off then self.moodFrame:Hide(); self.moodAg:Stop(); self.moodGlow:Hide(); self.portrait.cut:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1) return end
            local c = sad and { 1, 0.42, 0.42 } or { 0.5, 0.84, 0.48 }
            self.portrait.cut:SetVertexColor(c[1], c[2], c[3], 1)
            self.mood:SetTexture(ns.MEDIA .. (sad and "pet_sad" or "pet_happy")); self.moodFrame:Show()
            if sad then self.moodGlow:Show(); if not self.moodAg:IsPlaying() then self.moodAg:Play() end
            else self.moodAg:Stop(); self.moodGlow:Hide() end
        end
        local oldMood = pet.PvMood
        function pet:PvMood()
            oldMood(self)
            if not ns.PetOpt("chipOff") then self.chip:Set("공격 중", C.acc, C.ink) end
            ns.StylePet(self, true)
        end
    end
    -- 대상의 대상 (진짜와 같은 모양의 어두운 알약) · 대상 초상화 밑
    local tt = CreateFrame("Frame", nil, t)
    do
        local W_, H_ = POR_W + 40, 32
        tt:SetSize(W_, H_)
        tt.rim = ns.RoundRect(tt, 10, { 0.29, 0.204, 0.22 }, "BACKGROUND", 0, -2)
        local bg = ns.RoundRect(tt, 9, { 0.078, 0.047, 0.055 }, "BACKGROUND", 1, 0); bg:SetColor({ 0.078, 0.047, 0.055 }, 0.92)
        tt.bg = bg
        local sfr = CreateFrame("Frame", nil, tt); sfr:SetPoint("TOPLEFT", 4, -4); sfr:SetPoint("BOTTOMLEFT", 4, 4); sfr:SetWidth(6)
        tt.stripe = ns.RoundRect(sfr, 3, C.acc, "ARTWORK", 0, 0)
        tt.baseW = W_
        local hp = CreateFrame("StatusBar", nil, tt)
        hp:SetPoint("BOTTOMLEFT", 14, 3); hp:SetPoint("BOTTOMRIGHT", -8, 3); hp:SetHeight(3)
        hp:SetStatusBarTexture(ns.WHITE); hp:SetStatusBarColor(0.937, 0.416, 0.486, 1); hp:SetMinMaxValues(0, 1); hp:SetValue(1)
        local nm = ns.Font(tt, 17, { 1, 0.97, 0.96 }); nm:SetPoint("LEFT", tt, "LEFT", 16, 2); nm:SetText("르엘")
        local pc = tt:CreateFontString(nil, "OVERLAY"); pc:SetFont(ns.NUM, 14, ""); pc:SetTextColor(0.85, 0.78, 0.76)
        pc:SetPoint("RIGHT", tt, "RIGHT", -10, 2); pc:SetText("100%")
        tt.name, tt.pct, tt.hp = nm, pc, hp
    end
    hud.pet, hud.tot = pet, tt
    local function PlaceExtras()
        -- 조각마다 크기 (진짜 HUD와 같게)
        local PS = ns.HudPartScale or function() return 1 end
        p:SetScale(PS("player")); t:SetScale(PS("target"))
        local ms = PS("center"); mid:SetScale(ms); mid:ClearAllPoints(); mid:SetPoint("TOP", hud, "TOP", 0, -6 / ms)
        if pet then
            local sc = (tonumber(ns.db and ns.db.petScale) or 130) / 100
            local ps = p:GetScale()
            pet:SetScale(sc); pet:ClearAllPoints()
            pet:SetPoint("TOPLEFT", p, "TOPLEFT", 14 * ps / sc, -(POR_H + 14) * ps / sc)
        end
        local sc2 = (tonumber(ns.db and ns.db.totScale) or 100) / 100
        tt:SetScale(sc2); tt:ClearAllPoints()
        tt:SetPoint("TOPRIGHT", t.portrait, "TOPRIGHT", 0, -(POR_H + 8) / sc2)
        tt:SetShown(not (ns.db and ns.db.tot == false))
    end
    -- 보일 부분 고르기: all · player · center · target · pet
    function hud:Focus(part)
        part = part or "all"
        p:SetShown(part == "all" or part == "player")
        t:SetShown(part == "all" or part == "target" or part == "tot")
        mid:SetShown(part == "all" or part == "center")
        if pet then pet:SetShown(part == "all" or part == "pet") end
        if part == "pet" then p:Show(); p:SetAlpha(0.18); t:Hide() else p:SetAlpha(1) end
        self.focus = part
    end
    function hud:Refresh()
        PlaceExtras()
        -- 내 캐릭터 대신 늘 같은 모형 '르엘' (누구 화면이든 같고, 전투 중 비밀 값도 안 써요)
        ns.SetText(p.name, "르엘")
        p.name:SetTextColor(C.acc[1], C.acc[2], C.acc[3])
        p.lv:SetText("60"); p.lv:SetTextColor(C.tx[1], C.tx[2], C.tx[3])
        p.portrait.tex:SetTexture(ns.MEDIA .. "pv_leel"); p.portrait.tex:SetTexCoord(0, 1, 0, 1)
        if p.portrait.tex.SetDesaturated then p.portrait.tex:SetDesaturated(false) end
        if p.cls then
            p.cls.icon:SetTexture(ns.MEDIA .. "bunny"); p.cls.icon:SetTexCoord(0, 1, 0, 1)
            p.cls.ring:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
            p.cls:Show()
            pcall(PlaceHpValue, p, true)
        end
        pcall(ns.SetBar, p.hp.bar, 9999, 9999)
        p.hpValue:SetText("9999"); p.hpPct:SetText("100%")
        if p.hp.heal then p.hp.heal:Hide() end
        if p.power then
            pcall(ns.SetBar, p.power.bar, 9999, 9999)
            p.power.fill:SetVertexColor(C.mana[1], C.mana[2], C.mana[3], 1)
            p.powerText:SetText("9999"); p.powerText:SetTextColor(0.56, 0.69, 1)
        end
        if p.manaLine then p.manaLine:Hide(); p.manaLabel:Hide(); p.manaText:Hide() end
        if p.state then p.state:Hide() end
        -- 대상도 내 창과 같은 모형 '르엘' (LV 60 · 9999 · 토끼 초상화)
        ns.SetText(t.name, "르엘"); t.name:SetTextColor(C.acc[1], C.acc[2], C.acc[3])
        t.lv:SetText("60"); t.lv:SetTextColor(C.tx[1], C.tx[2], C.tx[3])
        t.portrait.tex:SetTexture(ns.MEDIA .. "pv_leel"); t.portrait.tex:SetTexCoord(0, 1, 0, 1)
        if t.portrait.tex.SetDesaturated then t.portrait.tex:SetDesaturated(false) end
        if t.cls then
            t.cls.icon:SetTexture(ns.MEDIA .. "bunny"); t.cls.icon:SetTexCoord(0, 1, 0, 1)
            t.cls.ring:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
            t.cls:Show()
            pcall(PlaceHpValue, t, true)
        end
        pcall(ns.SetBar, t.hp.bar, 9999, 9999)
        t.hpValue:SetText("9999"); t.hpPct:SetText("100%")
        if t.hp.heal then t.hp.heal:Hide() end
        if t.tpower and ns.db and ns.db.tPowerOff then
            t.tpower:Hide(); t.tpowerText:Hide(); t.tpowerLabel:Hide()
        elseif t.tpower then
            t.tpower:Show(); t.tpowerText:Show(); t.tpowerLabel:Show()
            t.tpower:SetMinMaxValues(0, 1); t.tpower:SetValue(1)
            t.tpower:SetStatusBarColor(C.mana[1], C.mana[2], C.mana[3])
            t.tpowerText:SetText("9999"); t.tpowerLabel:SetText("마나")
        end
        -- 대상 창 덤 (설정대로 · 죽은 대상은 그 줄에 마우스를 올렸을 때만)
        local TO = ns.TgtOpt or function() end
        local sc = math.max(0.5, math.min(1.6, (tonumber(TO("debScale")) or 100) / 100))
        t.pvDeb:SetShown(not TO("debOff")); t.pvDeb:SetScale(sc)
        t.pvBuf:SetShown(not TO("buffOff")); t.pvBuf:SetScale(sc)
        -- 대상의 대상 알약: 설정대로 (나를 노리면 강조 줄에 마우스 = 강조된 모습)
        ns.StyleToT(tt, ns.hudPvPeek == "totme", ns.HudClassColorOf and ns.HudClassColorOf("player"), true)
        if pet and pet.PvMood then pet:PvMood() end
        -- 연계 점수 칸: 미리 보기는 3점 (그 줄에 마우스를 올리면 5점 꽉 찬 모습)
        local cOn = not TO("comboOff")
        t.pvCombo:SetShown(cOn and true or false)
        if cOn then t.pvCombo:SetCount(ns.hudPvPeek == "combo" and 5 or 3) end
        local D = cOn and (t.pvCombo:GetHeight() + 6) or 0
        if t.tpower then t.tpower:ClearAllPoints(); t.tpower:SetPoint("TOPRIGHT", t.hp, "BOTTOMRIGHT", -16, -8 - D) end
        local hudCast = ns.db and ns.db.castStyle == "hud" and not ns.db.castMineOnly
        t.pvCast:SetShown(hudCast and true or false)
        t.pvCast:ClearAllPoints(); t.pvCast:SetPoint("TOPRIGHT", t.hp, "BOTTOMRIGHT", -14, -7 - D)
        t.pvDeb:ClearAllPoints(); t.pvDeb:SetPoint("TOPRIGHT", t.hp, "BOTTOMRIGHT", -76, (hudCast and -51 or -17) - D)
        -- 마우스를 올린 줄(ns.hudPvPeek)은 꺼져 있어도 어떤 모습인지 잠깐 보여줘요
        local peek = ns.hudPvPeek
        t.pvThr:SetShown((TO("threatOn") or peek == "thr") and true or false)
        local dead = ns.hudPvDead and not TO("deadKeep")
        t.portrait.tex:SetDesaturated(dead and true or false)
        t.hp:SetAlpha(dead and 0.5 or 1); t.name:SetAlpha(dead and 0.5 or 1)
        t.hpValue:SetShown(not dead); t.hpPct:SetShown(not dead)
        if t.state then
            if dead then t.state:SetText("쓰러짐"); t.state:Show() else t.state:Hide() end
        end
        ns.ApplyHpTextSize(p); ns.ApplyHpTextSize(t)
        -- 등급 테두리: 미리 보기는 정예(금테)로 보여줘요
        if (TO("rankOn") or peek == "rank") and t.portrait.cut then t.portrait.cut:SetAlpha(1); t.portrait.cut:SetVertexColor(1, 0.83, 0.42, 1) end
        -- 이름 · 레벨 색: 미리 보기 대상은 '적'처럼
        if TO("nameCol") == "react" then t.name:SetTextColor(1, 0.45, 0.45) end
        if TO("lvCol") == "white" then t.lv:SetTextColor(C.tx[1], C.tx[2], C.tx[3]) else t.lv:SetTextColor(1, 0.5, 0.25) end
        -- 가운데: 허브의 [비전투 | 전투 중]에 맞춰 (ns.hudPvFight) · 세부 설정도 같이
        local O = (ns.db and ns.db.ctr) or {}
        local useDist = not (ns.db and ns.db.centerTime)
        local fight = ns.hudPvFight and true or false
        local awake = fight and not O.numOff   -- '끔'이면 전투 효과도 없음
        local es = math.max(0.4, (tonumber(O.earScale) or 100) / 100)
        e1:SetSize(34 * es, 62 * es); e2:SetSize(34 * es, 62 * es); il:SetSize(42 * es, 42 * es); ir:SetSize(42 * es, 42 * es)
        local earOn = false   -- 가운데 토끼 귀는 없앴어요
        e1:SetShown(awake and earOn); e2:SetShown(awake and earOn); glow:SetShown(awake)
        glow:SetAlpha(O.fx == "soft" and 0.45 or 1)
        glow:ClearAllPoints(); glow:SetPoint("CENTER", mid, "TOP", 0, -86)
        local BN = { { -46, -78 }, { 46, -74 }, { -54, -100 }, { 54, -98 } }
        for i, b in ipairs(bolts) do
            local bp = BN[i] or b.home
            if bp then b:ClearAllPoints(); b:SetPoint("CENTER", mid, "TOP", bp[1], bp[2]) end
        end
        for _, b in ipairs(bolts) do
            local on = awake and not O.boltOff
            b:SetShown(on); if on then b.ag:Play() else b.ag:Stop() end
            b:SetSize(O.fx == "strong" and 18 or 14, O.fx == "strong" and 36 or 28)
        end
        il:SetShown(not awake and earOn); ir:SetShown(not awake and earOn)
        local eb = hud.midEarBox
        if eb then
            eb:ClearAllPoints()
            if awake then eb:SetPoint("TOPLEFT", e1, "TOPLEFT"); eb:SetPoint("BOTTOMRIGHT", e2, "BOTTOMRIGHT")
            else eb:SetPoint("TOPLEFT", il, "TOPLEFT"); eb:SetPoint("BOTTOMRIGHT", ir, "BOTTOMRIGHT") end
            eb:SetShown(earOn)
        end
        for _, z in ipairs(zzz) do z:Hide(); z.ag:Stop() end   -- 비전투는 그냥 거리 화면
        -- 숫자 · m · 줄 · 점 · 아래 글씨 (실제 가운데 코드와 같은 규칙)
        local nf = dist:GetFont(); if nf then dist:SetFont(nf, math.max(14, 40 + (tonumber(O.numAdd) or 0)), "") end
        local mf2 = unitm:GetFont(); if mf2 then unitm:SetFont(mf2, math.max(9, 18 + math.floor((tonumber(O.numAdd) or 0) * 0.4 + 0.5)), "") end
        local NEAR, MID, GOLD = { 0.62, 0.88, 0.66 }, C.acc, { 1, 0.843, 0.353 }
        local OFFC = { 0.36, 0.27, 0.25 }
        local hidden = O.numOff or ((not useDist) and not fight)
        dist:SetShown(not hidden); unitm:SetShown(not hidden and useDist)
        sub:SetShown(not hidden and not O.subOff)
        note:SetShown(hidden)
        if O.numOff then note:SetText("가운데 사용 안 함")
        elseif hidden then note:SetText("전투 전엔 가운데가 안 보여요\n(전투 시간 모드)") end
        local showDots = (not hidden) and useDist and not O.dotsOff
        local showRule = (not hidden) and not useDist
        rule:SetShown(showRule)
        local n, col
        if useDist then
            if fight then dist:SetText("20"); col = MID; n = 2; sub:SetText("대상과 거리")
            else dist:SetText("5"); col = NEAR; n = 1; sub:SetText("근접 거리") end
            unitm:SetText("m")
            local tc = fight and C.tx or col
            if O.white then tc = C.tx end
            dist:SetTextColor(tc[1], tc[2], tc[3]); unitm:SetTextColor(tc[1], tc[2], tc[3])
            local dc = fight and GOLD or (O.white and C.acc or col)
            for i, d in ipairs(pdots) do
                local k = (i <= n) and dc or OFFC
                d:SetVertexColor(k[1], k[2], k[3], 1); d:SetShown(showDots)
            end
            hud.midDots:SetShown(showDots)
        else
            dist:SetText("42"); dist:SetTextColor(C.tx[1], C.tx[2], C.tx[3]); sub:SetText("전투 시간")
            for _, d in ipairs(pdots) do d:Hide() end
        end
        -- 전투 중 효과: 빛 · 번개 · 빛줄기 (숫자 둘레)
        for _, st in ipairs(streaks) do
            local on = awake and not O.streakOff
            st:SetShown(on); if on then st.ag:Play() else st.ag:Stop() end
        end
        dist:SetAlpha(1); sub:SetAlpha(1)
        self:SetScale(ns.db.scale or 0.7)
    end
    hud:Refresh()
    return hud
end

----------------------------------------------------------------------
-- 가운데: 대상과 거리 (기본) 또는 전투 시간 (허브에서 고름)
-- 와우는 정확한 거리를 안 알려줘서, 내 기술 사거리로 '~몇 m' 구간을 재요
----------------------------------------------------------------------
local rangeSpells, rangeDirty = {}, true
local RANGE_ITEMS   -- { {r=사거리, ids={...}}, ... } 가까운 순

local function SpellRangeOf(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, i = pcall(C_Spell.GetSpellInfo, id)
        if ok and type(i) == "table" then return i.maxRange end
    end
    if GetSpellInfo then
        local ok, _, _, _, _, _, maxR = pcall(GetSpellInfo, id)
        if ok then return maxR end
    end
end

-- { 사거리, 아이템 번호 }: 부두 부적 5, 리넨 붕대 15, 겨우살이 20, 체력의 두루마리 30
RANGE_ITEMS = { { 5, 8149 }, { 15, 1251 }, { 20, 21519 }, { 30, 1180 } }
local function ItemInRange(id, unit)
    local f = (C_Item and C_Item.IsItemInRange) or IsItemInRange
    if not f then return nil end
    -- 전투 중 아군 대상엔 게임이 막아요 (pcall로도 '차단' 알림이 떠요) → 적일 때만
    if InCombatLockdown() then
        local okA, atk = pcall(UnitCanAttack, "player", unit)
        if not (okA and atk == true) then return nil end
    end
    local ok, v = pcall(function()
        local x = f(id, unit)
        if issecretvalue and issecretvalue(x) then return nil end
        if x == true or x == 1 then return true end
        if x == false or x == 0 then return false end
    end)
    if ok then return v end
end
do  -- 아이템 정보 미리 받아두기 (처음엔 비어 있으면 거리 확인이 안 돼요)
    for _, it in ipairs(RANGE_ITEMS) do
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, it[2])
        elseif GetItemInfo then pcall(GetItemInfo, it[2]) end
    end
end

local function ScanSpells()
    rangeDirty = false
    local by = {}
    local function add(id)
        if not id then return end
        local r = SpellRangeOf(id)
        if type(r) ~= "number" then return end
        if r < 5 then r = 5 end            -- 근접 기술 (사거리 0)
        r = math.floor(r + 0.5)
        if r > 45 then return end
        by[r] = by[r] or {}
        if #by[r] < 4 then table.insert(by[r], id) end
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        for t = 1, (C_SpellBook.GetNumSpellBookSkillLines() or 0) do
            local ok, line = pcall(C_SpellBook.GetSpellBookSkillLineInfo, t)
            if ok and line and not line.offSpecID then
                for i = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                    local ok2, it = pcall(C_SpellBook.GetSpellBookItemInfo, i, bank)
                    if ok2 and it and not it.isPassive and it.spellID
                       and (not Enum.SpellBookItemType or it.itemType == Enum.SpellBookItemType.Spell) then
                        add(it.spellID)
                    end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
        for t = 1, GetNumSpellTabs() do
            local _, _, off, num = GetSpellTabInfo(t)
            for i = off + 1, off + num do
                local ok, kind, id = pcall(GetSpellBookItemInfo, i, "spell")
                if ok and kind == "SPELL" and id then add(id) end
            end
        end
    end
    wipe(rangeSpells)
    for r, ids in pairs(by) do rangeSpells[#rangeSpells + 1] = { r = r, ids = ids } end
    -- 아군·NPC도 잴 수 있게 사거리가 정해진 물건 (갖고 있지 않아도 돼요)
    for _, it in ipairs(RANGE_ITEMS) do
        rangeSpells[#rangeSpells + 1] = { r = it[1], ids = { it[2] }, item = true }
    end
    table.sort(rangeSpells, function(x, y) return x.r < y.r end)
end

local function InRangeRaw(id, unit)
    local v
    if C_Spell and C_Spell.IsSpellInRange then
        v = C_Spell.IsSpellInRange(id, unit)
    elseif IsSpellInRange then
        local name = GetSpellInfo and GetSpellInfo(id)
        if name then v = IsSpellInRange(name, unit) end
    end
    if issecretvalue and issecretvalue(v) then return nil end
    if v == true or v == 1 then return true end
    if v == false or v == 0 then return false end
    return nil   -- 이 대상에겐 못 쓰는 기술
end
local function InRange(id, unit)
    local ok, v = pcall(InRangeRaw, id, unit)
    if ok then return v end
end

-- 전투 밖에서만: 상호작용 거리 (3 = 약 10m, 4 = 약 28m)
local function Interact(unit, i)
    if InCombatLockdown() or not CheckInteractDistance then return nil end
    local ok, v = pcall(CheckInteractDistance, unit, i)
    if ok then return v and true or false end
end

-- 돌려주는 값: 숫자(이 거리 안), "far"(가장 먼 기술보다 멀리), nil(모름)
local function TargetRange(unit)
    if rangeDirty then pcall(ScanSpells) end
    local any, maxR, hit = false, 0, nil
    for _, b in ipairs(rangeSpells) do
        for _, id in ipairs(b.ids) do
            local v
            if b.item then v = ItemInRange(id, unit) else v = InRange(id, unit) end
            if v == true then hit = b.r break end
            if v == false then any = true; maxR = b.r end
        end
        if hit then break end
    end
    -- 전투 밖이면 상호작용 거리로 구간을 더 잘게
    if not (hit and hit <= 5) then
        if (not hit or hit > 10) and Interact(unit, 3) then return 10 end
        if (not hit or hit > 28) and Interact(unit, 4) then return 28 end
    end
    if hit then return hit end
    if any then return "far", maxR end
    if Interact(unit, 4) == false then return "far", 28 end
end

ns.UnitRange = TargetRange   -- Leel Mark가 무리 고를 때 씀 (숫자 = 그 안, "far" = 그보다 멂)

local DIST_COL = {
    near = { 0.62, 0.88, 0.66 },   -- 근접
    mid  = C.acc,                  -- ~20
    long = { 0.97, 0.76, 0.6 },    -- ~40
    far  = { 0.55, 0.48, 0.46 },   -- 너무 멂
}

local UseDistFn
local function CreateCenter(hud)
    local c = CreateFrame("Frame", nil, hud)
    c:SetSize(GAP, 100)
    c:SetPoint("TOP", hud, "TOP", 0, -12)

    c.text = ns.Num(c, 50, C.tx)
    c.text:SetPoint("TOP", c, "TOP", 0, 0)
    c.text:SetShadowColor(0, 0, 0, 0.7)
    c.text:SetShadowOffset(0, -3)

    c.unitm = ns.Num(c, 22, C.tx)        -- 작은 m
    c.unitm:SetPoint("BOTTOMLEFT", c.text, "BOTTOMRIGHT", 1, 4)
    c.unitm:SetShadowColor(0, 0, 0, 0.7)
    c.unitm:SetShadowOffset(0, -2)

    c.rule = ns.Tex(c, "ARTWORK", 0, ns.MEDIA .. "pill32", C.acc)
    c.rule:SetSize(56, 3)
    c.rule:SetPoint("TOP", c.text, "BOTTOM", 0, -6)

    c.sub = ns.Font(c, 11, C.tx2)
    c.sub:SetPoint("TOP", c.rule, "BOTTOM", 0, -9)

    -- 거리 점 4개 (분홍 줄 자리, 멀수록 하나씩 차요)
    c.dots = {}
    for i = 1, 4 do
        local d = ns.Tex(c, "ARTWORK", 1, ns.MEDIA .. "circle", C.acc)
        d:SetSize(9, 9)
        d:SetPoint("CENTER", c.rule, "CENTER", (i - 2.5) * 14, 0)
        d:Hide()
        c.dots[i] = d
    end
    local DOT_OFF = { 0.36, 0.27, 0.25 }
    local GOLD = { 1, 0.843, 0.353 }
    local function Dots(n, col)
        c.rule:Hide()
        if c.awake and col and col ~= DIST_COL.far then col = GOLD end
        if ns.db and ns.db.ctr and ns.db.ctr.white and col then col = C.acc end
        for i, d in ipairs(c.dots) do
            local k = (n and i <= n) and col or DOT_OFF
            d:SetVertexColor(k[1], k[2], k[3], 1)
            d:Show()
        end
    end
    local function Rule()
        c.rule:Show()
        for _, d in ipairs(c.dots) do d:Hide() end
    end
    c.Rule = Rule
    c.Dots = Dots

    -- 토끼 귀 + 전투 중 각성: 귀가 금빛으로 쭉 서고, 숫자 뒤로 금빛 줄기가 솟아요
    -- 평소: 짧은 회색 귀 (오른쪽 귀가 가끔 까딱) + 졸음 z
    c.ear = c:CreateTexture(nil, "ARTWORK"); c.ear:SetTexture(ns.MEDIA .. "ear_short_l")
    c.ear:SetSize(42, 42); c.ear:SetPoint("BOTTOM", c, "TOP", 0, -13)
    c.earR = c:CreateTexture(nil, "ARTWORK"); c.earR:SetTexture(ns.MEDIA .. "ear_short_r")
    c.earR:SetSize(42, 42); c.earR:SetPoint("BOTTOM", c, "TOP", 0, -13)
    do
        local ag = c.earR:CreateAnimationGroup(); ag:SetLooping("REPEAT")
        local function Hold(d, o) local a = ag:CreateAnimation("Translation"); a:SetOffset(0, 0); a:SetDuration(d); a:SetOrder(o) end
        local function Rot(deg, o) local a = ag:CreateAnimation("Rotation"); a:SetDegrees(deg); a:SetOrigin("BOTTOM", 6, 1); a:SetDuration(0.06); a:SetOrder(o) end
        Hold(2.8, 1); Rot(-14, 2); Rot(14, 3); Hold(0.05, 4); Rot(-12, 5); Rot(12, 6); Hold(0.9, 7)
        c.twitchAg = ag
    end
    c.zzz = {}
    for i = 1, 3 do
        local z = ns.Font(c, 10 + i, { 0.8, 0.73, 0.71 }); z:SetText("z"); z:SetAlpha(0)
        z:SetPoint("BOTTOMLEFT", c, "TOP", 10, 2)
        local ag = z:CreateAnimationGroup(); ag:SetLooping("REPEAT")
        local mv = ag:CreateAnimation("Translation"); mv:SetOffset(18, 30); mv:SetDuration(3); mv:SetOrder(1)
        local fi = ag:CreateAnimation("Alpha"); fi:SetFromAlpha(0); fi:SetToAlpha(0.8); fi:SetDuration(0.9); fi:SetOrder(1)
        local fo = ag:CreateAnimation("Alpha"); fo:SetFromAlpha(0.8); fo:SetToAlpha(0); fo:SetStartDelay(1.8); fo:SetDuration(1.2); fo:SetOrder(1)
        c.zzz[i] = { fs = z, ag = ag }
    end
    function c:IdleFx(on)
        self.idleGen = (self.idleGen or 0) + 1
        local gen = self.idleGen
        if on then
            self.ear:SetAlpha(1); self.earR:SetAlpha(1)   -- 까딱은 뺐어요 (가만히)
            if not (ns.db and ns.db.ctr and ns.db.ctr.zzzOff) then
                for i, z in ipairs(self.zzz) do
                    C_Timer.After((i - 1) * 1.0, function() if c.idleGen == gen then z.ag:Play() end end)
                end
            end
        else
            self.twitchAg:Stop(); self.ear:SetAlpha(0); self.earR:SetAlpha(0)
            for _, z in ipairs(self.zzz) do z.ag:Stop(); z.fs:SetAlpha(0) end
        end
    end
    c.earG = c:CreateTexture(nil, "ARTWORK", nil, 1); c.earG:SetTexture(ns.MEDIA .. "ear_gold")
    c.earG:SetSize(36, 36); c.earG:SetPoint("BOTTOM", c, "TOP", 0, -12); c.earG:SetAlpha(0)
    do
        local ag = c.earG:CreateAnimationGroup()
        -- 짧은 귀에서 쭉 자라나요 (0.6 → 1.08 → 1)
        local a1 = ag:CreateAnimation("Scale"); a1:SetOrigin("BOTTOM", 0, 0); a1:SetDuration(0.22); a1:SetOrder(1); a1:SetSmoothing("OUT")
        if a1.SetScaleFrom then a1:SetScaleFrom(1, 0.7); a1:SetScaleTo(1, 1.08) else a1:SetScale(1, 1.08) end
        local a2 = ag:CreateAnimation("Scale"); a2:SetOrigin("BOTTOM", 0, 0); a2:SetDuration(0.12); a2:SetOrder(2); a2:SetSmoothing("IN")
        if a2.SetScaleFrom then a2:SetScaleFrom(1, 1.08); a2:SetScaleTo(1, 1) else a2:SetScale(1, 1 / 1.08) end
        c.earPop = ag
    end
    -- 번쩍
    c.flash = c:CreateTexture(nil, "BACKGROUND", nil, 2); c.flash:SetTexture(ns.MEDIA .. "soft_glow"); c.flash:SetBlendMode("ADD")
    c.flash:SetSize(140, 140); c.flash:SetPoint("CENTER", c, "TOP", 0, -22); c.flash:SetVertexColor(1, 0.9, 0.55); c.flash:SetAlpha(0)
    do
        local ag = c.flash:CreateAnimationGroup()
        local a1 = ag:CreateAnimation("Alpha"); a1:SetFromAlpha(0); a1:SetToAlpha(0.95); a1:SetDuration(0.1); a1:SetOrder(1)
        local a2 = ag:CreateAnimation("Alpha"); a2:SetFromAlpha(0.95); a2:SetToAlpha(0); a2:SetDuration(0.45); a2:SetOrder(2)
        c.flashAg = ag
    end
    -- 솟는 빛줄기
    c.streaks = {}
    local SX = { -52, -40, -29, -19, -8, 8, 19, 30, 41, 53 }
    for i, x in ipairs(SX) do
        local t = c:CreateTexture(nil, "BACKGROUND", nil, 1); t:SetTexture(ns.MEDIA .. "streak"); t:SetBlendMode("ADD")
        local h = 34 + ((i * 37) % 30)
        t:SetSize(3 + (i % 2), h); t:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]); t:SetAlpha(0)
        t:SetPoint("BOTTOM", c, "TOP", x, -62 - (i % 3) * 4)
        t.leelX, t.leelY = x, -62 - (i % 3) * 4
        local d = 1.1 + ((i * 53) % 9) / 10
        local ag = t:CreateAnimationGroup(); ag:SetLooping("REPEAT")
        local mv = ag:CreateAnimation("Translation"); mv:SetOffset(0, 46); mv:SetDuration(d); mv:SetOrder(1)
        local fi = ag:CreateAnimation("Alpha"); fi:SetFromAlpha(0); fi:SetToAlpha(0.45 + (i % 4) * 0.12); fi:SetDuration(d * 0.35); fi:SetOrder(1)
        local fo = ag:CreateAnimation("Alpha"); fo:SetFromAlpha(0.45 + (i % 4) * 0.12); fo:SetToAlpha(0); fo:SetStartDelay(d * 0.55); fo:SetDuration(d * 0.45); fo:SetOrder(1)
        c.streaks[i] = { t = t, ag = ag, d = d }
    end
    do
        local ag = c.earG:CreateAnimationGroup()
        local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(0.5)
        ag:SetScript("OnFinished", function() c.earG:SetAlpha(0) end)
        c.earOut = ag
    end
    -- 노란 번개: 각성 중 여기저기서 빠직빠직
    c.bolts = {}
    for i = 1, 4 do
        local t = c:CreateTexture(nil, "OVERLAY", nil, 2); t:SetBlendMode("ADD"); t:SetAlpha(0)
        local ag = t:CreateAnimationGroup()
        local function A(from, to, d, o) local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(from); a:SetToAlpha(to); a:SetDuration(d); a:SetOrder(o) end
        A(0, 1, 0.03, 1); A(1, 1, 0.05, 2); A(1, 0.15, 0.03, 3); A(0.15, 1, 0.03, 4); A(1, 1, 0.04, 5); A(1, 0, 0.12, 6)
        c.bolts[i] = { t = t, ag = ag }
    end
    -- 번개 자리: 귀 양옆 · 숫자 양옆 (거리 칸 위쪽 기준)
    local BOLT_AT = { { -30, 6 }, { 30, 8 }, { -48, -26 }, { 48, -24 }, { -40, -50 }, { 42, -48 }, { -16, 18 }, { 16, 20 } }
    -- 귀를 끄면 번개는 숫자 둘레로 (숫자 가운데 ≈ 위에서 25 아래)
    local BOLT_NUM = { { -44, -8 }, { 44, -6 }, { -54, -28 }, { 54, -26 }, { -42, -48 }, { 44, -46 }, { -22, 4 }, { 22, 6 } }
    local boltN, boltWait, boltLast = 0, 0, 0
    local function Crackle(n)
        for _ = 1, n do
            boltN = boltN % #c.bolts + 1
            local b = c.bolts[boltN]
            local at
            local AT = BOLT_NUM   -- 귀는 없앴어요: 번개는 숫자 둘레로
            repeat at = math.random(#AT) until at ~= boltLast
            boltLast = at
            local p = AT[at]
            local big = math.random() < 0.35
            b.t:SetTexture(ns.MEDIA .. (math.random() < 0.5 and "bolt1" or "bolt2"))
            b.t:SetSize(big and 16 or 12, big and 32 or 24)
            b.t:ClearAllPoints(); b.t:SetPoint("CENTER", c, "TOP", p[1] + math.random(-4, 4), p[2] + math.random(-4, 4))
            local r = math.rad((p[1] < 0 and 1 or -1) * math.random(10, 35))
            b.t:SetRotation(r)
            b.ag:Stop(); b.ag:Play()
        end
    end
    c.boltTick = CreateFrame("Frame", nil, c); c.boltTick:Hide()
    c.boltTick:SetScript("OnUpdate", function(_, el)
        boltWait = boltWait - el
        if boltWait > 0 then return end
        Crackle(math.random() < 0.3 and 2 or 1)
        boltWait = 0.35 + math.random() * 0.9
        if ns.db and ns.db.ctr and ns.db.ctr.fx == "strong" then boltWait = boltWait * 0.5 end
    end)

    function c:Awaken(on)
        on = on and true or false
        if on == (self.awake or false) then return end
        self.awake = on
        if on then
            self.fightStart = GetTime()
            self.earOut:Stop(); self:IdleFx(false); self.earG:SetAlpha(1)
            local O = (ns.db and ns.db.ctr) or {}
            self.earPop:Play()
            if not O.flashOff then self.flashAg:Stop(); self.flashAg:Play() end
            if not O.boltOff and not O.numOff then Crackle(3); boltWait = 0.5; self.boltTick:Show() end   -- 변신 순간 번개 세 갈래
            if not O.streakOff then
                for _, st in ipairs(self.streaks) do
                    C_Timer.After(0.15 + math.random() * st.d, function() if c.awake then st.ag:Play() end end)
                end
            end
        else
            for _, st in ipairs(self.streaks) do st.ag:Stop(); st.t:SetAlpha(0) end
            self.boltTick:Hide(); for _, b in ipairs(self.bolts) do b.ag:Stop(); b.t:SetAlpha(0) end
            self.earOut:Play(); self:IdleFx(true)
        end
        if self.ShowDist and UseDistFn and UseDistFn() and self:IsShown() then self:ShowDist() end
    end

    local function Color(col)
        if c.awake and col ~= DIST_COL.far then col = C.tx end
        if ns.db and ns.db.ctr and ns.db.ctr.white then col = C.tx end   -- 허브: 거리 색 = 흰색
        c.text:SetTextColor(col[1], col[2], col[3])
        c.unitm:SetTextColor(col[1], col[2], col[3])
    end

    local function UseDist() return not ns.db.centerTime end
    UseDistFn = UseDist

    function c:ShowDist()
        local unit = "target"
        if not UnitExists(unit) then
            if UnitAffectingCombat("player") then
                -- 대상 없음: 숫자 · 점 · 글자는 숨기고 귀(+ 각성 빛)만
                self.text:SetText(""); self.unitm:SetText("")
                c.rule:Hide(); for _, d in ipairs(c.dots) do d:Hide() end
                self.sub:SetText(""); self:Show()
            else
                self:Hide()
            end
            return
        end
        if UnitIsUnit(unit, "player") then self:Hide() return end
        local r, maxR = TargetRange(unit)
        if r == "far" then
            self.text:SetText(maxR or 40); Color(DIST_COL.far)
            self.unitm:SetText("m+"); Dots(4, DIST_COL.far)
            self.sub:SetText("너무 멀어요"); self:Show()
            return
        elseif type(r) == "number" then
            self.text:SetText(r)
            local col = r <= 5 and DIST_COL.near or r <= 20 and DIST_COL.mid or DIST_COL.long
            Color(col)
            Dots(r <= 5 and 1 or r <= 20 and 2 or r <= 30 and 3 or 4, col)
            self.sub:SetText(r <= 5 and "근접 거리" or "대상과 거리")
        else
            self.text:SetText("?"); self.unitm:SetText(""); Color(DIST_COL.far)
            Dots(0)
            self.sub:SetText("대상과 거리"); self:Show()
            return
        end
        self.unitm:SetText("m")
        self:Show()
    end

    -- 거리 모드: 대상이 있으면 늘 / 전투 시간 모드: 전투 중에만
    function c:Idle()
        self:Awaken(false)
        if UseDist() then return self:Dist() end
        self:SetScript("OnUpdate", nil)
        self:Hide()
        Rule()
        self.unitm:SetText("")
        self.text:SetText("VS")
        self.text:SetTextColor(C.acc[1], C.acc[2], C.acc[3])
        self.sub:SetText("전투 전")
    end

    function c:Dist()
        local acc = 1
        self:ShowDist()
        self:SetScript("OnUpdate", function(s, el)
            acc = acc + el
            if acc < 0.2 then return end
            acc = 0
            s:ShowDist()
        end)
    end

    function c:Fight()
        self:Awaken(true)
        if UseDist() then return self:Dist() end
        local start, acc = GetTime(), 0
        Rule()
        self.unitm:SetText("")
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

    -- 허브에서 모드를 바꿨을 때
    function c:Apply()
        if UseDist() then self:Dist()
        elseif UnitAffectingCombat("player") then self:Fight()
        else self:Idle() end
    end

    -- 거리 모드는 숨겨져 있어도 대상이 생기면 다시 보여야 해서, 바깥 틀에서 돌려요
    local tick = CreateFrame("Frame", nil, hud)
    local tacc = 0
    tick:SetScript("OnUpdate", function(_, el)
        tacc = tacc + el
        if tacc < 0.2 then return end
        tacc = 0
        if UseDist() and not ns.moving and not c:IsShown() then c:ShowDist() end
    end)
    -- /르엘각성 : 전투 없이 각성 모습 미리 보기 (한 번 더 = 끄기)
    SLASH_LEELAWAKE1 = "/르엘각성"
    SlashCmdList.LEELAWAKE = function() c:Awaken(not c.awake); if c.awake and not c:IsShown() then c:ShowDist() end end
    ns.hudCenter = c   -- 르엘 허브: 위쪽 HUD를 고르면 각성 모습 미리 보기

    -- 허브 > Leel HUD > 가운데 세부 설정 (ns.db.ctr)
    --   귀 · 숫자 · 아래 글씨 · 졸음 z · 각성 효과를 틀 하나씩에 담아 켜고 끄기 · 크기
    do
        local function L(f, lv) f:SetAllPoints(c); f:SetFrameLevel(c:GetFrameLevel() + lv); return f end
        local fxF = L(CreateFrame("Frame", nil, c), 1)
        local earF = L(CreateFrame("Frame", nil, c), 2)
        local numF = L(CreateFrame("Frame", nil, c), 3)
        local subF = L(CreateFrame("Frame", nil, numF), 1)
        local zF = L(CreateFrame("Frame", nil, c), 3)
        c.flash:SetParent(fxF)
        for _, st in ipairs(c.streaks) do st.t:SetParent(fxF) end
        for _, b in ipairs(c.bolts) do b.t:SetParent(fxF) end
        for _, t in ipairs({ c.ear, c.earR, c.earG }) do t:SetParent(earF) end
        for _, t in ipairs({ c.text, c.unitm, c.rule }) do t:SetParent(numF) end
        for _, d in ipairs(c.dots) do d:SetParent(numF) end
        c.sub:SetParent(subF)
        for _, z in ipairs(c.zzz) do z.fs:SetParent(zF) end
        local f1 = c.text:GetFont()
        local f2 = c.unitm:GetFont()
        function c:ApplyOpts()
            local O = (ns.db and ns.db.ctr) or {}
            earF:SetAlpha(0)   -- 가운데 토끼 귀는 없앴어요 (숫자 + 효과만)
            earF:SetScale(math.max(0.4, (tonumber(O.earScale) or 100) / 100))
            zF:SetAlpha(0)   -- 비전투는 그냥 거리 화면 (zzz 없음)
            numF:SetAlpha(O.numOff and 0 or 1)
            subF:SetAlpha(O.subOff and 0 or 1)
            for _, d in ipairs(c.dots) do d:SetAlpha(O.dotsOff and 0 or 1) end
            local add = tonumber(O.numAdd) or 0
            if f1 then c.text:SetFont(f1, math.max(16, 50 + add), "") end
            if f2 then c.unitm:SetFont(f2, math.max(10, 22 + math.floor(add * 0.4 + 0.5)), "") end
            -- 가운데 '끔' = 숫자도 전투 효과도 안 보여요
            fxF:SetAlpha(O.numOff and 0 or (O.fx == "soft" and 0.45 or 1))
            if O.numOff then c.boltTick:Hide() end
            -- 귀를 끄면 빛 · 빛줄기도 숫자 쪽으로 내려와요
            local dy = -14   -- 귀가 없으니 빛 · 빛줄기도 숫자 쪽으로
            c.flash:ClearAllPoints(); c.flash:SetPoint("CENTER", c, "TOP", 0, -22 + dy)
            for _, st in ipairs(c.streaks) do
                if st.t.leelX then st.t:ClearAllPoints(); st.t:SetPoint("BOTTOM", c, "TOP", st.t.leelX, st.t.leelY + dy * 2) end
            end
            if O.boltOff then c.boltTick:Hide(); for _, b in ipairs(c.bolts) do b.ag:Stop(); b.t:SetAlpha(0) end end
            if O.streakOff then for _, st in ipairs(c.streaks) do st.ag:Stop(); st.t:SetAlpha(0) end end
        end
        -- 언제 보일지: 늘 · 대상 있을 때(처음) · 전투 중만
        local function Vis()
            if ns.moving then return end
            local v = ns.db and ns.db.ctr and ns.db.ctr.vis or "target"
            local fight = UnitAffectingCombat("player")
            if v == "combat" and not fight then
                c:Hide()
            elseif v == "always" and not c:IsShown() then
                if not UnitExists("target") and not fight then
                    c.text:SetText(""); c.unitm:SetText(""); c.sub:SetText("")
                    c.rule:Hide(); for _, d in ipairs(c.dots) do d:Hide() end
                end
                c:Show()
            end
        end
        hooksecurefunc(c, "ShowDist", Vis)
        hooksecurefunc(c, "Idle", Vis)
        hooksecurefunc(c, "Fight", Vis)
        c:ApplyOpts()
    end
    function ns.SetCtr(k, v)
        ns.db.ctr = ns.db.ctr or {}
        ns.db.ctr[k] = v
        if c.ApplyOpts then c:ApplyOpts() end
        if c.Apply then c:Apply() end
    end
    SLASH_LEELTOTEM1 = "/르엘토템"; SLASH_LEELTOTEM2 = "/leeltotem"
    SlashCmdList.LEELTOTEM = function(msg)
        msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if msg == "기록" then
            local L = ns.db and ns.db.tlog or {}
            for i = math.max(1, #L - 15), #L do print("|cfff2b3c2[토템]|r " .. L[i]) end
            print("|cfff2b3c2[토템]|r 기록 " .. #L .. "줄 · /reload 하면 저장 파일(WTF > SavedVariables > LeelUI.lua)에 남아요")
            return
        elseif msg == "지우기" then
            if ns.db then ns.db.tlog = {} end
            print(ns.L("|cfff2b3c2[토템]|r 기록을 지웠어요"))
            return
        end
        if ns.ToggleHub then ns:ToggleHub("LeelUI_TotemSet") end
    end
    local sev = CreateFrame("Frame")
    sev:RegisterEvent("SPELLS_CHANGED")
    pcall(sev.RegisterEvent, sev, "LEARNED_SPELL_IN_TAB")
    sev:SetScript("OnEvent", function() rangeDirty = true end)

    c:IdleFx(true)
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

local function CreatePet(hud, preview)
    local f = preview and CreateFrame("Button", nil, hud) or CreateFrame("Button", "LeelUI_pet", hud, "SecureUnitButtonTemplate")
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
    ns.PaintHealthRed(f.hp)
    f.hpValue = ns.Num(f.hp.over, 15, { 1, 0.953, 0.953 })
    f.hpValue:SetShadowColor(0.35, 0.06, 0.1, 0.8); f.hpValue:SetShadowOffset(1, -1)
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
    -- 펫의 대상 (허브 > 펫 · 켰을 때만): 집중 바 아래 작은 글씨
    f.ptg = ns.Font(f, 11, C.tx2); f.ptg:SetPoint("TOPLEFT", f.focus, "BOTTOMLEFT", 0, -4); f.ptg:Hide()

    -- 펫 만족도 (사냥꾼): 초상화 테두리 색 + 오른쪽 아래 얼굴 · 불만이면 빨간 빛이 숨쉬듯
    f.moodGlow = f.portrait:CreateTexture(nil, "BACKGROUND", nil, -1)
    f.moodGlow:SetTexture(ns.MEDIA .. "portrait_edge")
    f.moodGlow:SetPoint("TOPLEFT", -5, 5); f.moodGlow:SetPoint("BOTTOMRIGHT", 5, -5)
    f.moodGlow:SetVertexColor(1, 0.42, 0.42, 1); f.moodGlow:SetBlendMode("ADD"); f.moodGlow:Hide()
    local ag = f.moodGlow:CreateAnimationGroup()
    local a1 = ag:CreateAnimation("Alpha"); a1:SetFromAlpha(0.25); a1:SetToAlpha(1); a1:SetDuration(0.7); a1:SetOrder(1)
    local a2 = ag:CreateAnimation("Alpha"); a2:SetFromAlpha(1); a2:SetToAlpha(0.25); a2:SetDuration(0.7); a2:SetOrder(2)
    ag:SetLooping("REPEAT"); f.moodAg = ag
    local mf = CreateFrame("Frame", nil, f); mf:SetFrameLevel(f:GetFrameLevel() + 5)
    mf:SetSize(22, 22); mf:SetPoint("CENTER", f.portrait, "BOTTOMRIGHT", -4, 4)
    f.mood = mf:CreateTexture(nil, "OVERLAY"); f.mood:SetAllPoints(); mf:Hide(); f.moodFrame = mf
    -- 마우스 올리면 툴팁 아래에 만족도 · 피해 % · 충성도
    f:HookScript("OnEnter", function(self)
        local ok, h, dmg, loy = pcall(GetPetHappiness)
        if not ok or not h then return end
        if issecretvalue and (issecretvalue(h) or issecretvalue(dmg)) then return end
        if not GameTooltip:IsOwned(self) then GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetUnit("pet") end
        local N = { "불만", "보통", "행복" }
        local CC = { { 1, 0.42, 0.42 }, { 1, 0.83, 0.42 }, { 0.5, 0.84, 0.48 } }
        local c = CC[h] or { 1, 1, 1 }
        ns.TAdd(GameTooltip, " ")
        ns.TAdd(GameTooltip, "만족도: " .. (N[h] or "?") .. (dmg and ("  ·  피해 " .. dmg .. "%") or ""), c[1], c[2], c[3])
        if loy and loy ~= 0 then ns.TAdd(GameTooltip, "충성도 " .. (loy > 0 and "오르는 중" or "내려가는 중"), 0.8, 0.74, 0.72) end
        if h == 1 then ns.TAdd(GameTooltip, "먹이를 주세요!", 1, 0.42, 0.42) end
        GameTooltip:Show()
    end)
    return f
end
-- 허브 미리 보기용 펫 창 (진짜 펫 창과 같은 모양 · 클릭 없음)
ns.HudPetPreview = function(h) return CreatePet(h, true) end

-- 펫 창 세부 (허브 > 펫): ns.db.petO
--   chipOff 상태 칩 · focusOff 집중 바 · tgtOn 펫의 대상 · porOff 초상화 · porEdge "state"|"pink"|"off"
--   nameAdd · lvAdd 글씨 · barW 체력 바 길이(%) · hpOff · pctOff · vis "all"|"combat" · alert "off"|"chat"|"sound"
local PET_DEF = { porEdge = "state", barW = 100, vis = "all", alert = "off" }
function ns.PetOpt(k)
    local t = ns.db and ns.db.petO
    local v = t and t[k]
    if v == nil then v = PET_DEF[k] end
    return v
end
function ns.SetPetOpt(k, v)
    ns.db.petO = ns.db.petO or {}
    ns.db.petO[k] = v
    if ns.HudPetRefresh then ns.HudPetRefresh() end
end
function ns.StylePet(f, isPv)
    if not f then return end
    local O = ns.PetOpt
    if O("chipOff") then f.chip:Hide() end
    f.focus:SetShown(not O("focusOff"))
    -- 펫의 대상
    if O("tgtOn") then
        if isPv then f.ptg:SetText("▸ 붉은갈기 노움"); f.ptg:Show()
        elseif UnitExists("pettarget") then f.ptg:SetFormattedText("▸ %s", UnitName("pettarget") or ""); f.ptg:Show()
        else f.ptg:Hide() end
        f.ptg:ClearAllPoints()
        if f.focus:IsShown() then f.ptg:SetPoint("TOPLEFT", f.focus, "BOTTOMLEFT", 0, -4) else f.ptg:SetPoint("TOPLEFT", f.hp, "BOTTOMLEFT", 12, -4) end
    else
        f.ptg:Hide()
    end
    f.portrait:SetAlpha(O("porOff") and 0 or 1)
    local e = O("porEdge")
    if e == "off" then f.portrait.cut:SetAlpha(0)
    else
        f.portrait.cut:SetAlpha(1)
        if e == "pink" then f.portrait.cut:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1) end
    end
    local nf, _, nfl = f.name:GetFont(); if nf then f.name:SetFont(nf, math.max(9, 15 + (tonumber(O("nameAdd")) or 0)), nfl or "") end
    local lf, _, lfl = f.lv:GetFont(); if lf then f.lv:SetFont(lf, math.max(9, 15 + (tonumber(O("lvAdd")) or 0)), lfl or "") end
    f.hp:SetWidth(math.floor(PET_BAR * math.max(50, math.min(160, tonumber(O("barW")) or 100)) / 100 + 0.5))
    f.hpValue:SetAlpha(O("hpOff") and 0 or 1)
    f.hpPct:SetAlpha(O("pctOff") and 0 or 1)
    if isPv then return end
    f:SetAlpha((O("vis") == "combat" and not UnitAffectingCombat("player")) and 0 or 1)
    -- 불만으로 바뀌는 순간 한 번 알림
    local ok, h = pcall(GetPetHappiness)
    if ok and type(h) == "number" and not ns.IsSecret(h) then
        if h == 1 and (f.lastHappy or 0) > 1 then
            local a = O("alert")
            if a == "chat" then print(ns.L("|cfff2b3c2[르엘 펫]|r 펫이 배고파요. 먹이를 주세요!"))
            elseif a == "sound" then pcall(PlaySoundFile, ns.MEDIA .. "leel_black_warn.ogg", "Master") end
        end
        f.lastHappy = h
    end
end

----------------------------------------------------------------------
-- 따라가는 중 표시: 대상 초상화 분홍 빛 맥박 + 두 사람 배지 + 아래 알약
----------------------------------------------------------------------
local function SetupFollow(f)
    local por = f.portrait
    local pending
    local glow = por:CreateTexture(nil, "BACKGROUND", nil, -2)
    glow:SetTexture(ns.MEDIA .. "soft_glow"); glow:SetBlendMode("ADD"); glow:SetVertexColor(1, 0.561, 0.639)
    glow:SetPoint("TOPLEFT", -22, 22); glow:SetPoint("BOTTOMRIGHT", 22, -22); glow:SetAlpha(0)
    local gag = glow:CreateAnimationGroup(); gag:SetLooping("BOUNCE")
    local ga = gag:CreateAnimation("Alpha"); ga:SetFromAlpha(0.25); ga:SetToAlpha(0.9); ga:SetDuration(0.8); ga:SetSmoothing("IN_OUT")
    -- 따라가기 단추 (두 사람 그림): 같은 편 플레이어가 대상이면 초상화 오른쪽 아래에 보여요 · 누르면 따라가기
    local bf = CreateFrame("Button", "LeelUI_FollowBtn", f, "SecureActionButtonTemplate")
    bf:SetSize(44, 44); bf:SetFrameLevel(por:GetFrameLevel() + 12)
    bf:SetPoint("CENTER", por, "BOTTOMRIGHT", -2, 2)
    bf:SetAttribute("type", "macro"); bf:SetAttribute("macrotext", "/follow target")
    local down = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")
    bf:RegisterForClicks(down and "AnyDown" or "AnyUp")
    local bt = bf:CreateTexture(nil, "OVERLAY"); bt:SetTexture(ns.MEDIA .. "follow_badge"); bt:SetAllPoints()
    -- 따라가는 중: 두 사람이 번갈아 콩콩 + 둘레 분홍 점선이 빙글
    local live = CreateFrame("Frame", nil, bf); live:SetAllPoints(); live:Hide()
    local lbg = live:CreateTexture(nil, "ARTWORK"); lbg:SetTexture(ns.MEDIA .. "follow_bg"); lbg:SetAllPoints()
    local p2 = live:CreateTexture(nil, "OVERLAY", nil, 1); p2:SetTexture(ns.MEDIA .. "follow_p2"); p2:SetAllPoints()
    local p1 = live:CreateTexture(nil, "OVERLAY", nil, 2); p1:SetTexture(ns.MEDIA .. "follow_p1"); p1:SetAllPoints()
    local ring = live:CreateTexture(nil, "OVERLAY", nil, 3); ring:SetTexture(ns.MEDIA .. "follow_ring"); ring:SetAllPoints()
    -- 움직임은 애니메이션 대신 직접 (텍스처 이동 애니메이션이 위로 튀어 오르는 문제가 있어서)
    local liveT = 0
    live:SetScript("OnUpdate", function(_, el)
        liveT = liveT + el
        local w = (bf:GetWidth() or 44) / 44
        local y1 = 2.5 * w * math.abs(math.sin(liveT * math.pi / 0.32))
        local y2 = 2.5 * w * math.abs(math.sin(liveT * math.pi / 0.32 + math.pi / 2))   -- 반 박자 늦게
        p1:ClearAllPoints(); p1:SetPoint("TOPLEFT", bf, "TOPLEFT", 0, y1); p1:SetPoint("BOTTOMRIGHT", bf, "BOTTOMRIGHT", 0, y1)
        p2:ClearAllPoints(); p2:SetPoint("TOPLEFT", bf, "TOPLEFT", 0, y2); p2:SetPoint("BOTTOMRIGHT", bf, "BOTTOMRIGHT", 0, y2)
        ring:SetRotation(-liveT * 2 * math.pi / 2.4)
    end)
    local liveOn = false
    local function Live(on)
        if on == liveOn then return end
        liveOn = on
        if on then
            bt:Hide(); liveT = 0; live:Show()
        else
            live:Hide(); bt:Show()
        end
    end
    local bag = bf:CreateAnimationGroup()
    local b1 = bag:CreateAnimation("Scale"); b1:SetScale(1.35, 1.35); b1:SetDuration(0.12); b1:SetOrder(1); b1:SetSmoothing("OUT")
    local b2 = bag:CreateAnimation("Scale"); b2:SetScale(1 / 1.35, 1 / 1.35); b2:SetDuration(0.16); b2:SetOrder(2); b2:SetSmoothing("IN")
    bf:SetAlpha(0)
    bf:HookScript("PreClick", function() local ok, n = pcall(UnitName, "target"); if ok then pending = n end end)
    bf:SetScript("OnEnter", function(s2)
        GameTooltip:SetOwner(s2, "ANCHOR_RIGHT"); ns.TAdd(GameTooltip, "따라가기", 1, 0.84, 0.88)
        ns.TAdd(GameTooltip, "초상화 Alt + 클릭도 돼요 · 움직이면 멈춰요", 0.75, 0.68, 0.66); GameTooltip:Show()
    end)
    bf:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local pill = CreateFrame("Frame", nil, f); pill:SetHeight(20); pill:SetFrameLevel(por:GetFrameLevel() + 9)
    pill:SetPoint("TOPRIGHT", por, "BOTTOMRIGHT", 0, -10)
    pill.bg = ns.RoundRect(pill, 10, { 0.07, 0.047, 0.047 }, "BACKGROUND", 0, 0); pill.bg:SetColor({ 0.07, 0.047, 0.047 }, 0.9)
    pill.rim = ns.RoundRect(pill, 10, { 1, 0.561, 0.639 }, "BACKGROUND", -1, -1); pill.rim:SetColor({ 1, 0.561, 0.639 }, 0.8)
    pill.fs = ns.Font(pill, 11, { 1, 0.96, 0.95 }); pill.fs:SetPoint("CENTER", 0, 0)
    pill:Hide()
    local followName
    -- 이름 비교: 와우 포에버는 "르엘 무이"처럼 띄어쓴 이름이 와서, 앞 단어만 같아도 같은 사람
    local function First(n) if type(n) ~= "string" then return nil end; return (n:gsub("%-.*$", ""):match("^(%S+)")) end
    local function Same(a, b)
        local ok, r = pcall(function()
            if a == nil or b == nil then return false end
            if a == b then return true end
            return First(a) ~= nil and First(a) == First(b)
        end)
        return ok and r
    end
    f:HookScript("PreClick", function(_, btn) if IsAltKeyDown() then local ok, n = pcall(UnitName, "target"); if ok then pending = n end end end)
    ns.FollowPending = function(n) pending = n end
    local function Paint()
        local on = followName and UnitExists("target") and Same(UnitName("target"), followName)
        local friend = UnitExists("target") and UnitIsPlayer("target") and UnitIsFriend("player", "target") and not UnitIsUnit("target", "player")
        if on then
            if bf:GetAlpha() < 1 then bag:Play() end
            bf:SetAlpha(1); Live(true)
            glow:Show(); gag:Play()
            pill:Hide()   -- 글자 대신 아이콘이 움직여요
        else
            Live(false); bf:SetAlpha(friend and 0.9 or 0)   -- 같은 편 플레이어면 흐리게 보여서 누를 수 있다는 걸 알려줘요
            gag:Stop(); glow:SetAlpha(0); pill:Hide()
        end
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("AUTOFOLLOW_BEGIN"); ev:RegisterEvent("AUTOFOLLOW_END"); ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    ev:SetScript("OnEvent", function(_, event, name)
        if event == "AUTOFOLLOW_BEGIN" then
            followName = (type(name) == "string" and name ~= "") and name or pending
            if type(followName) == "string" then followName = followName:gsub("%-.*$", "") end
            if ns.db and ns.db.followDbg then print("|cfff2b3c2[따라가기]|r 시작 이름=" .. tostring(name) .. " · 대상=" .. tostring(UnitName("target"))) end
        elseif event == "AUTOFOLLOW_END" then
            if followName then print(ns.L("|cfff2b3c2르엘|r 따라가기 끝: " .. followName)) end
            followName = nil
        end
        Paint()
    end)
    ns.FollowName = function() return followName end
    SLASH_LEELFOLLOW1 = "/르엘따라"
    SlashCmdList.LEELFOLLOW = function()
        ns.db.followDbg = not ns.db.followDbg
        print("|cfff2b3c2[따라가기]|r 점검 " .. (ns.db.followDbg and "켬 · Alt+클릭으로 따라가 보세요" or "끔") .. " · 지금: " .. tostring(followName))
    end
end

local function UpdatePetCore(f)
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
    -- 만족도 (사냥꾼 펫만 값이 있어요)
    local ok, h = pcall(GetPetHappiness)
    if ok and h and not (issecretvalue and issecretvalue(h)) and not dead and not (ns.db and ns.db.petMoodOff) then
        local CC = { { 1, 0.42, 0.42 }, { 1, 0.83, 0.42 }, { 0.5, 0.84, 0.48 } }
        local FACE = { "pet_sad", "pet_ok", "pet_happy" }
        local c = CC[h]
        if c then
            if not aggro then f.portrait.cut:SetVertexColor(c[1], c[2], c[3], 1) end
            f.mood:SetTexture(ns.MEDIA .. FACE[h]); f.moodFrame:Show()
            if h == 1 then f.moodGlow:Show(); if not f.moodAg:IsPlaying() then f.moodAg:Play() end
            else f.moodAg:Stop(); f.moodGlow:Hide() end
            return
        end
    end
    f.moodFrame:Hide(); f.moodAg:Stop(); f.moodGlow:Hide()
end
local function UpdatePet(f)
    UpdatePetCore(f)
    if ns.StylePet then pcall(ns.StylePet, f, false) end
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
        fr.center:SetScript("OnUpdate", nil)
        fr.center.text:SetText(ns.db.centerTime and "42" or "20")
        if ns.db.centerTime then fr.center.Rule() else fr.center.Dots(2, C.acc) end
        fr.center.unitm:SetText(ns.db.centerTime and "" or "m")
        fr.center.text:SetTextColor(C.tx[1], C.tx[2], C.tx[3])
        fr.center.unitm:SetTextColor(C.tx[1], C.tx[2], C.tx[3])
        fr.center.sub:SetText("예시 화면")
        fr.center:Show()
        if ns.SetCastPreview then ns:SetCastPreview(true) end
    else
        if ns.SetCastPreview then ns:SetCastPreview(false) end
        ns:RunOutOfCombat("preview", function()
            RegisterUnitWatch(fr.target)
            RegisterUnitWatch(fr.pet)
        end)
        fr.center:Apply()
        fr.refresh()
    end
end

----------------------------------------------------------------------
-- 만들기 + 이벤트
----------------------------------------------------------------------
-- Leel HUD 안 씀 (허브 > Leel HUD 쓰기 끔): 게임 기본 플레이어 · 대상 창은 숨기지 않아요
do
    local orig = ns.HideBlizzard
    if orig then
        ns.HideBlizzard = function(self, ...)
            if ns.db and ns.db.hudOff then return end
            return orig(self, ...)
        end
    end
end

function ns:CreateHUD()
    -- 잠깐 있던 '초상화 그림' 설정 지우기
    for _, sd in ipairs({ "player", "target" }) do
        local T = ns.db and ns.db.hudText and ns.db.hudText[sd]
        if T then T.porArt = nil end
    end
    -- 안 쓸 때도 만들어 두고(이동 모드 · 허브가 찾아요) 숨겨요
    if ns.db and ns.db.hudOff then C_Timer.After(0, function() if ns.hud then ns.hud:Hide() end end) end
    -- 게임 기본 플레이어 · 대상 창: Leel HUD를 쓰면 숨기고, 안 쓰면 보여요 (따로 고르는 스위치 없음)
    if ns.db then ns.db.hideBlizzard = not ns.db.hudOff end
    -- 가운데는 늘 대상과 거리 (전투 시간 보기는 없앴어요 · 전투 중은 효과로)
    if ns.db then ns.db.centerTime = nil end
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
    -- 아래 줄 글씨가 만들어진 뒤라 글씨 강조를 한 번 더 (자원 · 마나 글씨까지)
    ns.ApplyHpTextSize(player); ns.ApplyHpTextSize(target)
    RegisterUnitWatch(target)
    -- 따라가기: 대상 초상화를 Alt + 클릭
    target:SetAttribute("alt-type1", "macro")
    target:SetAttribute("alt-macrotext1", "/follow target")
    SetupFollow(target)
    local center = CreateCenter(hud)
    local pet = CreatePet(hud)
    RegisterUnitWatch(pet)
    -- 펫 창은 내 창을 따라다님 (조각 이동 때 같이)
    -- 펫 창 크기 (허브 > 위쪽 HUD · 80~160%, 처음 130%) · 자리는 크기와 상관없이 내 창 아래 그대로
    local function PlacePet()
        if InCombatLockdown() then return end
        local sc = (tonumber(ns.db and ns.db.petScale) or 130) / 100
        local ps = player:GetScale()   -- 내 창 크기만큼 아래로
        pet:SetScale(sc)
        pet:ClearAllPoints()
        pet:SetPoint("TOPLEFT", player, "TOPLEFT", 14 * ps / sc, -(POR_H + 14) * ps / sc)
    end
    PlacePet()
    ns.HudPlacePet = PlacePet
    -- 이동 모드: 펫 창 테두리 (크기만)
    C_Timer.After(0, function() if ns.MoveSizeOnly then ns.MoveSizeOnly(pet, "펫 창 크기 (사냥꾼 · 흑마법사)", "펫 창") end end)
    function ns.SetPetScale(v)
        if ns.db then ns.db.petScale = v end
        if InCombatLockdown() then
            local w = CreateFrame("Frame"); w:RegisterEvent("PLAYER_REGEN_ENABLED")
            w:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); PlacePet() end)
            return
        end
        PlacePet()
    end

    -- 대상의 대상: 대상 초상화 밑 어두운 알약 (왼쪽 직업색 띠 · 흰 이름 · % · 바닥 체력 줄)
    --   클릭 = 그 대상으로 바꾸기
    do
        local W_, H_ = POR_W + 40, 32   -- 어두운 알약 + 왼쪽 직업색 띠 + 바닥 체력 줄
        local tt = CreateFrame("Button", "LeelUI_targettarget", target, "SecureUnitButtonTemplate")
        tt:SetSize(W_, H_)
        tt:SetPoint("TOPRIGHT", target.portrait, "BOTTOMRIGHT", 0, -8)
        tt:SetAttribute("unit", "targettarget")
        tt:SetAttribute("*type1", "target")
        tt:RegisterForClicks("AnyUp")
        local rim = ns.RoundRect(tt, 10, { 0.29, 0.204, 0.22 }, "BACKGROUND", 0, -2)
        local bg = ns.RoundRect(tt, 9, { 0.078, 0.047, 0.055 }, "BACKGROUND", 1, 0)
        bg:SetColor({ 0.078, 0.047, 0.055 }, 0.92)
        tt.rim, tt.bg, tt.baseW = rim, bg, W_
        tt.sfr = CreateFrame("Frame", nil, tt)
        tt.sfr:SetPoint("TOPLEFT", 4, -4); tt.sfr:SetPoint("BOTTOMLEFT", 4, 4); tt.sfr:SetWidth(6)
        tt.stripe = ns.RoundRect(tt.sfr, 3, C.acc, "ARTWORK", 0, 0)
        tt.hp = CreateFrame("StatusBar", nil, tt)
        tt.hp:SetPoint("BOTTOMLEFT", 14, 3); tt.hp:SetPoint("BOTTOMRIGHT", -8, 3); tt.hp:SetHeight(3)
        tt.hp:SetStatusBarTexture(ns.WHITE)
        tt.hp:SetStatusBarColor(0.937, 0.416, 0.486, 1)
        local hb = tt.hp:CreateTexture(nil, "BACKGROUND"); hb:SetTexture(ns.WHITE); hb:SetAllPoints(); hb:SetVertexColor(1, 1, 1, 0.08)
        tt.name = ns.Font(tt, 17, { 1, 0.97, 0.96 })
        tt.name:SetPoint("LEFT", tt, "LEFT", 16, 2)
        tt.name:SetWidth(W_ - 64); tt.name:SetJustifyH("LEFT"); tt.name:SetWordWrap(false)
        tt.pct = tt:CreateFontString(nil, "OVERLAY")
        tt.pct:SetFont(ns.NUM, 14, "")
        tt.pct:SetTextColor(0.85, 0.78, 0.76)
        tt.pct:SetPoint("RIGHT", tt, "RIGHT", -10, 2)
        local function PaintTT()
            if not UnitExists("targettarget") then return end
            -- 이름은 캐릭터 이름 (흰 글씨) · 왼쪽 띠 = 플레이어면 직업 색, 몹 · NPC는 분홍
            tt.name:SetFormattedText("%s", UnitName("targettarget") or "")   -- 전투 중 비밀 이름도 그대로 넘겨요
            local col
            local okP, isP = pcall(UnitIsPlayer, "targettarget")
            if okP and isP and not ns.IsSecret(isP) then
                local okC, _, file = pcall(UnitClass, "targettarget")
                if okC and file and not ns.IsSecret(file) then
                    local cc = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(file)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[file])
                    if cc then col = { cc.r, cc.g, cc.b } end
                end
            end
            local okm, me = pcall(UnitIsUnit, "targettarget", "player")
            me = okm and not ns.IsSecret(me) and me and true or false
            ns.StyleToT(tt, me, col, false)
            local cur, max = UnitHealth("targettarget"), UnitHealthMax("targettarget")
            tt.hp:SetMinMaxValues(0, max or 1)
            tt.hp:SetValue(cur or 0)
            if ns.HealthPercentText then ns.HealthPercentText(tt.pct, "targettarget", cur, max) end
        end
        local acc = 0
        tt:SetScript("OnUpdate", function(_, el) acc = acc + el; if acc > 0.2 then acc = 0; PaintTT() end end)
        tt:SetScript("OnShow", PaintTT)
        tt:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT"); GameTooltip:SetUnit("targettarget"); GameTooltip:Show()
        end)
        tt:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- 크기 (허브 > 위쪽 HUD · 60~160%) · 자리는 크기와 상관없이 대상 초상화 밑
        local function PlaceTT()
            local sc = (tonumber(ns.db and ns.db.totScale) or 100) / 100
            tt:SetScale(sc)
            tt:ClearAllPoints()
            tt:SetPoint("TOPRIGHT", target.portrait, "BOTTOMRIGHT", 0, -8 / sc)
        end
        PlaceTT()
        function ns.SetToTScale(v)
            if ns.db then ns.db.totScale = v end
            if InCombatLockdown() then
                local w = CreateFrame("Frame"); w:RegisterEvent("PLAYER_REGEN_ENABLED")
                w:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); PlaceTT() end)
                return
            end
            PlaceTT()
        end
        if ns.db and ns.db.tot == false then tt:Hide() else RegisterUnitWatch(tt) end
        function ns.SetToT(on)
            if ns.db then ns.db.tot = on and true or false end
            if InCombatLockdown() then return end
            if on then RegisterUnitWatch(tt) else UnregisterUnitWatch(tt); tt:Hide() end
        end
        target.tot = tt
        -- 이동 모드: 대상의 대상 테두리 (크기만) · 켜 두었으면 예시로 보이게
        C_Timer.After(0, function()
            if not ns.MoveSizeOnly then return end
            ns.MoveSizeOnly(tt, "대상의 대상 크기", "대상의 대상", function(on)
                if InCombatLockdown() or (ns.db and ns.db.tot == false) then return end
                if on then
                    UnregisterUnitWatch(tt); tt:Show()
                    tt.name:SetText("대상의 대상"); tt.pct:SetText("100%"); tt.stripe:SetColor(C.acc, 1)
                    tt.hp:SetMinMaxValues(0, 1); tt.hp:SetValue(1)
                else
                    RegisterUnitWatch(tt)
                end
            end)
        end)
        ns.hudToT = tt
    end

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
    if ns.ApplyHudParts then ns:ApplyHudParts() end

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("LOOT_CLOSED")
    ev:RegisterEvent("LOOT_OPENED")
    for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_FLAGS",
                         "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED",
                         "UNIT_HEAL_PREDICTION" }) do
        pcall(ev.RegisterUnitEvent, ev, e, "player", "target")
    end
    for _, e in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
        ev:RegisterUnitEvent(e, "player", "target")
    end
    -- 펫 이벤트는 따로 받음 (같은 이벤트를 다른 유닛으로 다시 등록하면 플레이어/대상 등록이 덮어써짐)
    local petEv = CreateFrame("Frame")
    petEv:RegisterUnitEvent("UNIT_PET", "player")
    for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER",
                         "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_PORTRAIT_UPDATE", "UNIT_FLAGS",
                         "UNIT_THREAT_SITUATION_UPDATE", "UNIT_HAPPINESS", "UNIT_TARGET" }) do
        pcall(petEv.RegisterUnitEvent, petEv, e, "pet")
    end
    pcall(petEv.RegisterEvent, petEv, "PET_UI_UPDATE")
    pcall(petEv.RegisterEvent, petEv, "UNIT_HAPPINESS")
    pcall(petEv.RegisterEvent, petEv, "PLAYER_REGEN_ENABLED"); pcall(petEv.RegisterEvent, petEv, "PLAYER_REGEN_DISABLED")
    -- 점검: /르엘펫검사 (만족도가 안 보일 때)
    SLASH_LEELPETCHK1 = "/르엘펫검사"
    SlashCmdList.LEELPETCHK = function()
        local P = function(m) print("|cfff2b3c2[르엘 펫]|r " .. m) end
        P("GetPetHappiness 함수: " .. tostring(type(GetPetHappiness)) .. " · 펫 있음: " .. tostring(UnitExists("pet")))
        local ok, h, dmg, loy = pcall(GetPetHappiness)
        local sec = issecretvalue and h ~= nil and issecretvalue(h)
        P("결과: ok=" .. tostring(ok) .. " · 만족도=" .. (sec and "(숨김 값)" or tostring(h)) .. " · 피해=" .. tostring(not sec and dmg or "?") .. " · 충성=" .. tostring(not sec and loy or "?"))
        P("펫 칸: " .. tostring(pet and pet:IsShown()) .. " · 얼굴 표시: " .. tostring(pet and pet.moodFrame and pet.moodFrame:IsShown()))
        if C_PetInfo then P("C_PetInfo 있음") end
        if PetFrameHappiness then P("블리자드 펫 만족도 그림: " .. tostring(PetFrameHappiness:IsShown())) end
    end
    ns.HudPetRefresh = function() if pet and not ns.moving then pcall(UpdatePet, pet) end end
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
            if not ns.db.centerTime then center:ShowDist() end
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
            if event == "UNIT_HEAL_PREDICTION" then
                UpdateHeal(f)
            elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS" then
                UpdateHealth(f)
            elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
                if f == player then UpdatePower(f) else UpdateTargetPower(f) end
            else
                UpdateInfo(f)
            end
        end
    end)
end

----------------------------------------------------------------------
-- 토템 (주술사만): 체력 · 자원 바 아래 동그라미 4칸 (불 · 대지 · 물 · 바람)
--   둘레가 시계처럼 줄어들고 아래 남은 시간 · 안 깐 칸은 흐리게 · 오른쪽 클릭 = 그 토템 없애기
--   게임 보호 단추라 전투 전에 만들어 두고, 숨기지 않고 흐리게만 바꿔요
----------------------------------------------------------------------
do
    local ELEM = {
        { "불", { 0.91, 0.45, 0.23 }, "Interface\\Icons\\Spell_Fire_SearingTotem" },
        { "대지", { 0.62, 0.48, 0.27 }, "Interface\\Icons\\Spell_Nature_StoneSkinTotem" },
        { "물", { 0.25, 0.56, 1.00 }, "Interface\\Icons\\INV_Spear_04" },
        { "바람", { 0.75, 0.82, 0.88 }, "Interface\\Icons\\Spell_Nature_Windfury" },
    }
    local row
    local lastSig
    -- 전투 중엔 게임이 토템 값을 "비밀 값"으로 줘요: 비교 · 계산은 못 하고 그림 · 쿨다운에 넘기기만 돼요
    local issecret = issecretvalue or function() return false end
    -- 깔린 토템만 왼쪽부터 차곡차곡 (전투 중엔 게임이 단추 자리를 못 옮기게 해서, 끝나면 맞춰요)
    local function Layout(force)
        if not row then return end
        local vis, hid = {}, {}
        for i, b in ipairs(row.s) do
            local have, _, _, dur = GetTotemInfo(i)
            if issecret(have) or issecret(dur) then row.pending = true return end
            if have and dur and dur > 0 then vis[#vis + 1] = b else hid[#hid + 1] = b end
        end
        local sig = #vis .. ":" .. table.concat((function() local t = {} for _, b in ipairs(vis) do t[#t + 1] = b:GetID() end return t end)(), ",")
        if sig == lastSig and not force then return end
        if InCombatLockdown() then row.pending = true return end
        lastSig = sig; row.pending = false
        local n = 0
        for _, list in ipairs({ vis, hid }) do
            for _, b in ipairs(list) do
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", (row.x0 or 0) + n * 50, 0); n = n + 1
            end
        end
    end
    local function TimeText(rem)
        if rem >= 60 then return math.ceil(rem / 60) .. "분" end
        return math.max(0, math.floor(rem)) .. "초"
    end
    local function Bar(b, rem, dur)
        if rem and dur and dur > 0 and rem > 0 then
            local k = math.max(0, math.min(1, rem / dur))
            b.bar:SetWidth(math.max(0.01, 38 * k))
            local c = (rem <= 10) and { 1, 0.42, 0.42 } or b.elemColor
            b.bar:SetVertexColor(c[1], c[2], c[3], 1)
            b.bar:Show(); b.barBg:Show()
        else
            b.bar:Hide(); b.barBg:Hide()
        end
    end
    local function Paint()
        if not row then return end
        Layout()
        local now = GetTime()
        for i, b in ipairs(row.s) do
            local have, _, start, dur, icon = GetTotemInfo(i)
            local secret = issecret(have) or issecret(start) or issecret(dur) or issecret(icon)
            if secret then
                -- 비밀 값: 그림 · 쿨다운(게임이 남은 시간 숫자를 직접 그림) · 보일지 말지를 게임에 맡겨요
                -- 전투 전에 알던 값(아이콘 · 시작 · 길이)이 있으면 그걸로, 없으면 게임에 맡겨요
                if b.lastIcon then b.icon:SetTexture(b.lastIcon)
                else b.icon:SetTexture(ELEM[i][3]) end   -- 전투 중 새로 깐 토템: 그 원소 대표 그림
                b.icon:Show(); b.letter:Hide()
                -- 있는지는 우리가 따로 기억해요: 전투 전 상태 + 전투 중 "토템 주문 시전 → 그 칸 바뀜"
                if b.known and b.start and b.dur and (b.start + b.dur - now) <= 0 then b.known = false end
                if not b.known then
                    b:SetAlpha(0); b.time:Hide(); b.cd:Clear(); Bar(b)
                elseif b.start and b.dur then
                    b.cd:SetHideCountdownNumbers(true)
                    local rem = b.start + b.dur - now
                    if rem > 0 then b.time:SetText(TimeText(rem)); b.time:Show() else b.time:Hide() end
                    Bar(b, rem, b.dur)
                else
                    b.time:Hide(); Bar(b)
                    b.cd:SetHideCountdownNumbers(false)
                    -- 남은 시간: 게임이 비밀 값을 직접 그리게 (되는 방법부터)
                    local done = false
                    if not b.secretSet then
                        if GetTotemDuration and b.cd.SetCooldownFromDurationObject then
                            done = pcall(function() b.cd:SetCooldownFromDurationObject(GetTotemDuration(i)) end)
                        end
                        if not done then done = pcall(b.cd.SetCooldown, b.cd, start, dur) end
                        b.secretSet = done
                    end
                end
                if b.known then b:SetAlpha(1) end
            end
            local on = (not secret) and have and dur and dur > 0 and icon
            if secret then
                -- (위에서 처리)
            elseif on then
                b.cd:SetHideCountdownNumbers(true); b.secretSet = nil
                b.icon:SetTexture(icon); b.icon:Show(); b.letter:Hide()
                b:SetAlpha(1)
                if b.start ~= start then b.start = start; b.cd:SetCooldown(start, dur) end
                b.dur, b.lastIcon, b.known = dur, icon, true
                -- 토템마다 지속 시간을 배워 둬요: 전투 중 새로 깐 토템도 아래 글씨로 시간을 보여주게
                if ns.db then ns.db.totemDur = ns.db.totemDur or {}; ns.db.totemDur[tostring(icon)] = dur end
                b.time:SetText(TimeText(start + dur - now)); b.time:Show()
                Bar(b, start + dur - now, dur)
            else
                b.icon:Hide(); b.letter:Hide(); b.time:Hide(); Bar(b)
                b:SetAlpha(0)          -- 안 깐 칸은 안 보여요
                if b.start then b.start = nil; b.cd:Clear() end
                b.dur, b.lastIcon, b.secretSet, b.known = nil, nil, nil, false
            end
        end
    end
    local function Build()
        local fr = ns.hudFrames
        local f = fr and fr.player
        if row or not (f and f.manaLine) then return end
        local _, cls = UnitClass("player")
        if cls ~= "SHAMAN" then return end
        if InCombatLockdown() then return end
        row = CreateFrame("Frame", nil, f)
        row:SetSize(4 * 50, 72)
        row:SetPoint("TOPLEFT", f.manaLine, "BOTTOMLEFT", -2, -12)
        row.s = {}
        for i = 1, 4 do
            local e = ELEM[i]
            local b = CreateFrame("Button", "LeelUI_Totem" .. i, row, "SecureActionButtonTemplate")
            b:SetID(i)
            b:SetSize(40, 40)
            b:SetPoint("TOPLEFT", (i - 1) * 50, 0)
            b:RegisterForClicks("RightButtonUp", "RightButtonDown")
            b:SetAttribute("type2", "destroytotem")
            b:SetAttribute("totem-slot", i)
            local o = b:CreateTexture(nil, "BACKGROUND", nil, 0); o:SetTexture(ns.MEDIA .. "circle")
            o:SetPoint("TOPLEFT", -2, 2); o:SetPoint("BOTTOMRIGHT", 2, -2); o:SetVertexColor(0.07, 0.05, 0.055, 0.95)
            local rim = b:CreateTexture(nil, "BACKGROUND", nil, 1); rim:SetTexture(ns.MEDIA .. "circle")
            rim:SetAllPoints(); rim:SetVertexColor(e[2][1], e[2][2], e[2][3], 1)
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
            b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local mask = b:CreateMaskTexture()
            mask:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(b.icon)
            b.icon:AddMaskTexture(mask)
            b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
            b.cd:SetAllPoints(b.icon)
            pcall(b.cd.SetSwipeTexture, b.cd, ns.MEDIA .. "circle")
            b.cd:SetDrawSwipe(false)            -- 어두운 그림자는 안 써요 (아래 막대로 시간 표시)
            b.cd:SetDrawEdge(false)
            b.cd:SetHideCountdownNumbers(true)
            b.letter = ns.Font(b, 14, { 1, 1, 1 }); b.letter:SetPoint("CENTER"); b.letter:SetText(e[1]:sub(1, 3))
            -- 아래 얇은 막대: 남은 시간만큼 왼쪽으로 줄어요 (마지막 10초는 빨강)
            b.barBg = row:CreateTexture(nil, "ARTWORK"); b.barBg:SetTexture(ns.WHITE); b.barBg:SetVertexColor(0.23, 0.17, 0.18, 1)
            b.barBg:SetSize(38, 4); b.barBg:SetPoint("TOP", b, "BOTTOM", 0, -4)
            b.bar = row:CreateTexture(nil, "ARTWORK", nil, 1); b.bar:SetTexture(ns.WHITE); b.bar:SetHeight(4)
            b.bar:SetPoint("LEFT", b.barBg, "LEFT")
            b.elemColor = e[2]
            b.time = ns.Font(row, 14, { 1, 1, 1 }); b.time:SetPoint("TOP", b.barBg, "BOTTOM", 0, -3)   -- 한글(분 · 초)이 나오는 글꼴
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                local have = GetTotemInfo(i)
                if issecret(have) then have = self.lastIcon ~= nil end
                if have and GameTooltip.SetTotem then pcall(GameTooltip.SetTotem, GameTooltip, i)
                else ns.TSet(GameTooltip, e[1] .. " 토템"); ns.TAdd(GameTooltip, "깔린 토템이 없어요", 0.8, 0.8, 0.8) end
                ns.TAdd(GameTooltip, "오른쪽 클릭: 토템 없애기", 0.95, 0.70, 0.76)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row.s[i] = b
        end
        local acc = 0
        row:SetScript("OnUpdate", function(_, el) acc = acc + el; if acc > 0.25 then acc = 0; Paint(); if ns.TotemSetPaint then ns.TotemSetPaint() end end end)
        Paint()
        if ns.TotemSetBuild then ns.TotemSetBuild(row) end
    end

    ------------------------------------------------------------------
    -- 토템 세트 단추 (Q): 누를 때마다 세트의 다음 토템 하나 (게임 /castsequence)
    --   둘레 4칸 링 = 불 · 대지 · 물 · 바람 (깔린 것만 색) · 마우스 올리면 토끼 4형제가 콩콩
    --   세트는 허브 > 토템 세트에서 (전투 밖에서만 바꿀 수 있어요)
    ------------------------------------------------------------------
    local TOTEMS = {   -- { 주문 번호(1랭크), 원소 }
        { 3599, 1 }, { 1535, 1 }, { 8190, 1 }, { 8181, 1 }, { 8227, 1 },
        { 8071, 2 }, { 8075, 2 }, { 5730, 2 }, { 2484, 2 }, { 8143, 2 },
        { 5394, 3 }, { 5675, 3 }, { 8166, 3 }, { 8170, 3 }, { 8184, 3 },
        { 8512, 4 }, { 8835, 4 }, { 8177, 4 }, { 10595, 4 }, { 15107, 4 }, { 25908, 4 }, { 6495, 4 },
    }
    local TLog
    local SETNAMES = { "사냥", "던전", "보스" }
    local RECALL = "토템의 귀환"
    function ns.TotemRecallKnown()
        local ok, r = pcall(function()
            if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(RECALL) ~= nil end
            return GetSpellInfo and GetSpellInfo(RECALL) ~= nil
        end)
        return ok and r
    end
    local function SpellName(id)
        local n = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
        if not n and GetSpellInfo then n = GetSpellInfo(id) end
        return n
    end
    local function SpellIcon(id)
        return (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or (GetSpellTexture and GetSpellTexture(id))
    end
    local function Knows(id)
        local ok, r = pcall(function() return (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) end)
        return ok and r and true or false
    end
    local function SDB()
        local d = ns.db
        if not d then return nil end
        d.tset = d.tset or {}
        local t = d.tset
        if t.on == nil then t.on = true end
        t.cur = t.cur or 1
        if t.key == nil then t.key = "Q" end
        if t.shift == nil then t.shift = true end
        t.sets = t.sets or {}
        for i = 1, 3 do
            if not t.sets[i] then
                -- 처음엔 아는 토템 중 원소마다 첫 번째로 채워요
                local s = {}
                for e = 1, 4 do
                    for _, tt in ipairs(TOTEMS) do
                        if tt[2] == e and Knows(tt[1]) then s[#s + 1] = tt[1]; break end
                    end
                end
                if #s > 0 then t.sets[i] = s end
            end
        end
        return t
    end
    ns.TotemSetDB = SDB
    ns.TOTEM_SETNAMES = SETNAMES
    -- 허브 고르기 칸에 쓸 목록: 아는 토템만 (원소 · 이름)
    function ns.TotemOptions()
        local out = { { key = 0, label = "— 비워 두기" } }
        for _, tt in ipairs(TOTEMS) do
            if Knows(tt[1]) then
                local n = SpellName(tt[1])
                if n then out[#out + 1] = { key = tt[1], label = ELEM[tt[2]][1] .. " · " .. n, elem = tt[2], icon = SpellIcon(tt[1]) } end
            end
        end
        return out
    end
    local function ElemOf(id) for _, tt in ipairs(TOTEMS) do if tt[1] == id then return tt[2] end end end

    local q          -- 큰 단추
    local seq = {}   -- 지금 단추에 걸린 순서 (주문 번호)
    local step = 0   -- 깐 개수 (우리가 따로 셈)
    local lastOk, pressT, flip, lastPress = 0, 0, false, 0
    local fighting = false
    local function Active(e)
        local b = row and row.s[e]
        return b and b:GetAlpha() > 0.5
    end
    local function CurList()
        local t = SDB(); if not t then return {} end
        local src = t.sets[t.cur] or {}
        local list = {}
        for k = 1, 4 do local id = src[k]; if id and id ~= 0 and Knows(id) then list[#list + 1] = id end end
        return list
    end
    -- 깔린 토템은 건너뛰어요: 안 깔린(또는 다른 토템 · 10초 안 남은) 것부터
    --   전투 밖: 안 깔린 것만 (다 깔려 있으면 아무것도 안 깔아요)
    --   전투 시작할 때: 안 깔린 것 먼저 + 깔린 건 빨리 끝나는 순서로 뒤에 (전투 중엔 애드온이 다시 못 짜서)
    -- 기록: 허브 없이 확인용 (/르엘토템 기록) · 저장 파일에 최근 300줄
    TLog = function(msg)
        local d = ns.db; if not d then return end
        d.tlog = d.tlog or {}
        local L = d.tlog
        L[#L + 1] = string.format("%s %.1f %s", date("%H:%M:%S"), GetTime() % 1000, msg)
        while #L > 300 do table.remove(L, 1) end
    end
    local function SlotText()
        local out = {}
        for e = 1, 4 do
            local have, name, start, dur = GetTotemInfo(e)
            if issecret(have) or issecret(name) then out[#out + 1] = e .. ":비밀"
            elseif have and name and name ~= "" then out[#out + 1] = e .. ":" .. name .. string.format(ns.L("(%d초)"), math.max(0, (start or 0) + (dur or 0) - GetTime()))
            else out[#out + 1] = e .. ":-" end
        end
        return table.concat(out, " ")
    end
    local function Remain(id)
        local e = ElemOf(id)
        if not e then return 0 end
        local have, name, start, dur = GetTotemInfo(e)
        if issecret(have) or issecret(name) or issecret(start) then return Active(e) and 999 or 0 end
        if not (have and dur and dur > 0) then return 0 end
        -- 같은 원소 칸에 아무 토템이나 깔려 있으면 "깔림" (직접 깐 다른 토템을 덮어쓰지 않아요)
        return math.max(0.5, start + dur - GetTime())
    end
    -- 전투 직전엔 게임 값이 비밀로 바뀌기도 해서, 전투 밖에서 본 마지막 상태를 기억해 둬요
    local cacheAll, cacheMiss = {}, {}
    local function SmartList(full)
        if full then
            -- 전투용: 안 깔린 것(전투 밖에서 마지막으로 본) 먼저 + 나머지 세트 토템 뒤에
            local out, seen = {}, {}
            for _, id in ipairs(cacheMiss) do out[#out + 1] = id; seen[id] = true end
            for _, id in ipairs(cacheAll) do if not seen[id] then out[#out + 1] = id end end
            return out
        end
        local list = CurList()
        local miss = {}
        for _, id in ipairs(list) do
            if Remain(id) <= 0 then miss[#miss + 1] = id end
        end
        cacheAll, cacheMiss = list, miss
        return miss
    end
    local function Apply(force, full)
        if not q or InCombatLockdown() then if q then q.pending = true end return end
        q.pending = false
        local t = SDB()
        local show = t and t.on
        q:SetShown(show and true or false)
        local x0 = show and 62 or 0
        q.full = full
        if row and row.x0 ~= x0 then row.x0 = x0; Layout(true) end
        if q.tabs then for _, tb in ipairs(q.tabs) do tb:SetShown(show and true or false) end end
        ClearOverrideBindings(q)
        if not show then return end
        local list = SmartList(full)
        local sig = (full and "F:" or "N:") .. table.concat(list, ",")
        if sig ~= q.sig or force then
            q.sig = sig
            seq = list; step = 0
            local names = {}
            for _, id in ipairs(list) do names[#names + 1] = SpellName(id) end
            -- 전투 밖: 안 깔린 첫 토템 하나만 /cast (깔리면 바로 다음으로 다시 짜요 · 순서 기억 없음)
            -- 전투 중: 게임 /castsequence (전투가 끝나면 게임이 순서를 지워요) · 끝의 null = 연타해도 끝에서 멈춤
            local text = ""
            if #names > 0 then
                if full then text = "/castsequence reset=combat/3 " .. table.concat(names, ", ") .. ", null"
                else text = "/cast " .. names[1] end
            end
            q:SetAttribute("type1", "macro")
            q:SetAttribute("macrotext1", text)
            TLog("짜기 " .. (full and "[전투]" or "[밖]") .. " " .. (text ~= "" and text or "(다 깔림)"))
        end
        local key = t.key
        if key and key ~= "" then
            SetOverrideBindingClick(q, true, key, "LeelUI_TotemSet", "LeftButton")
            -- Shift+키 = 다음 세트 (키에 이미 Shift · Ctrl · Alt가 붙어 있으면 안 걸어요)
            if t.shift and not key:find("-", 1, true) then SetOverrideBindingClick(q, true, "SHIFT-" .. key, "LeelUI_TotemSetNext", "LeftButton") end
        end
        -- 토템의 귀환: 깐 토템을 거둬들이고 마나 일부를 돌려받는 주문
        if q.recall then
            q.recall:SetAttribute("type1", "macro")
            q.recall:SetAttribute("macrotext1", "/cast " .. RECALL)
            local rk = t.recallKey
            if rk and rk ~= "" and rk ~= key then SetOverrideBindingClick(q, true, rk, "LeelUI_TotemRecall", "LeftButton") end
        end
    end
    ns.TotemSetApply = function() Apply(true) end

    local function Hop(tex, d, up)
        local ag = tex:CreateAnimationGroup()
        local a = ag:CreateAnimation("Translation"); a:SetOffset(0, up); a:SetDuration(0.18); a:SetStartDelay(d); a:SetSmoothing("OUT"); a:SetOrder(1)
        local b = ag:CreateAnimation("Translation"); b:SetOffset(0, -up); b:SetDuration(0.24); b:SetSmoothing("IN"); b:SetOrder(2)
        b:SetEndDelay(math.max(0, 1.1 - 0.42 - d))
        ag:SetLooping("REPEAT")
        return ag
    end
    function ns.TotemSetBuild(r)
        if q or not r then return end
        local t = SDB(); if not t then return end
        q = CreateFrame("Button", "LeelUI_TotemSet", r, "SecureActionButtonTemplate")
        -- 토템 칸 맨 앞(왼쪽)에 크게: 깔린 토템은 그 오른쪽으로 차곡차곡
        q:SetSize(48, 48)
        q:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 4)
        r.x0 = 62
        r:SetWidth(62 + 4 * 50)
        Layout(true)
        local down = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")
        q:RegisterForClicks(down and "AnyDown" or "AnyUp")
        -- 바탕 (어두운 칸)
        local bg = q:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(ns.MEDIA .. "circle")
        bg:SetAllPoints(); bg:SetVertexColor(0.10, 0.075, 0.08, 0.96)
        local hi = q:CreateTexture(nil, "BACKGROUND", nil, 1); hi:SetTexture(ns.MEDIA .. "circle")
        hi:SetPoint("TOPLEFT", 3, -2); hi:SetPoint("BOTTOMRIGHT", -3, 6); hi:SetVertexColor(0.20, 0.15, 0.16, 0.6)
        -- 4칸 링 (위에서 시계 방향: 불 → 대지 → 물 → 바람)
        q.seg = {}
        for e = 1, 4 do
            local s = q:CreateTexture(nil, "BORDER")
            s:SetTexture(ns.MEDIA .. "tring_q")
            s:SetPoint("TOPLEFT", -5, 5); s:SetPoint("BOTTOMRIGHT", 5, -5)
            s:SetRotation(-math.rad((e - 1) * 90))
            q.seg[e] = s
        end
        -- 마우스 올리면 링을 따라 도는 빛
        local sw = q:CreateTexture(nil, "ARTWORK", nil, 7); sw:SetTexture(ns.MEDIA .. "tring_sw")
        sw:SetPoint("TOPLEFT", -5, 5); sw:SetPoint("BOTTOMRIGHT", 5, -5); sw:SetBlendMode("ADD"); sw:SetAlpha(0)
        local swAg = sw:CreateAnimationGroup()
        local rot = swAg:CreateAnimation("Rotation"); rot:SetDegrees(-360); rot:SetDuration(1.1)
        swAg:SetLooping("REPEAT")
        -- 토끼 4형제 + 대장 (따로 그려서 따로 뛰어요)
        local function Layer(file, sub)
            local x = q:CreateTexture(nil, "ARTWORK", nil, sub); x:SetTexture(ns.MEDIA .. file)
            x:SetPoint("CENTER", 0, 0); x:SetSize(44, 44)
            return x
        end
        local L3 = Layer("tb_l3", 1); local L2 = Layer("tb_l2", 2); local L1 = Layer("tb_l1", 3); local L0 = Layer("tb_l0", 4)
        local T = Layer("tb_top", 5); local S = Layer("tb_spark", 6)
        q.layers = { L0, L1, L2, L3, T }
        q.anims = { Hop(L0, 0, 3), Hop(L1, 0.09, 3), Hop(L2, 0.18, 3), Hop(L3, 0.27, 3), Hop(T, 0.36, 4.5) }
        local spAg = S:CreateAnimationGroup()
        local f1 = spAg:CreateAnimation("Alpha"); f1:SetFromAlpha(0.35); f1:SetToAlpha(1); f1:SetDuration(0.35); f1:SetOrder(1)
        local f2 = spAg:CreateAnimation("Alpha"); f2:SetFromAlpha(1); f2:SetToAlpha(0.35); f2:SetDuration(0.4); f2:SetOrder(2)
        spAg:SetLooping("REPEAT")
        S:SetAlpha(0.35)
        q.glow = q:CreateTexture(nil, "BACKGROUND", nil, -1); q.glow:SetTexture(ns.MEDIA .. "circle")
        q.glow:SetPoint("TOPLEFT", -10, 10); q.glow:SetPoint("BOTTOMRIGHT", 10, -10); q.glow:SetVertexColor(0.95, 0.70, 0.76, 0.0)
        -- 단축키 표시 (왼쪽 위) · 다 깔면 ✓ (오른쪽 아래)
        q.key = CreateFrame("Frame", nil, q); q.key:SetSize(18, 16); q.key:SetPoint("TOPLEFT", -7, 6)
        q.key:SetFrameLevel(q:GetFrameLevel() + 3)
        local kb = q.key:CreateTexture(nil, "BACKGROUND"); kb:SetTexture(ns.MEDIA .. "pill16"); kb:SetAllPoints(); kb:SetVertexColor(0.07, 0.05, 0.055, 0.95)
        q.key.fs = ns.Font(q.key, 12, { 1, 1, 1 }); q.key.fs:SetPoint("CENTER", 0, 0)
        q.done = q:CreateTexture(nil, "OVERLAY", nil, 7); q.done:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        q.done:SetSize(18, 18); q.done:SetPoint("BOTTOMRIGHT", 4, -2)
        q.done:Hide()
        local function Motion(on)
            for _, ag in ipairs(q.anims) do if on then ag:Play() else ag:Stop() end end
            if on then swAg:Play(); spAg:Play(); sw:SetAlpha(0.95); q.glow:SetVertexColor(0.95, 0.70, 0.76, 0.35)
            else swAg:Stop(); spAg:Stop(); sw:SetAlpha(0); S:SetAlpha(0.35); q.glow:SetVertexColor(0.95, 0.70, 0.76, 0) end
        end
        q:SetScript("OnEnter", function(self)
            Motion(true)
            local tt = SDB()
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            ns.TSet(GameTooltip, "토템 세트 · " .. (SETNAMES[tt.cur] or ""), 0.95, 0.70, 0.76)
            for k, id in ipairs(seq) do
                local e = ElemOf(id)
                local c = e and ELEM[e][2] or { 1, 1, 1 }
                local mark = (k <= step) and "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t " or (k == step + 1 and "|cfff2b3c2>>|r " or "     ")
                ns.TAdd(GameTooltip, mark .. (SpellName(id) or "?"), c[1], c[2], c[3])
            end
            if #seq == 0 then
                if #CurList() > 0 then ns.TAdd(GameTooltip, "토템이 다 깔려 있어요 (끝나거나 거두면 다시 깔 수 있어요)", 0.62, 0.88, 0.54)
                else ns.TAdd(GameTooltip, "허브 > 토템 세트에서 토템을 골라 주세요", 0.8, 0.8, 0.8) end
            end
            local key = tt.key or ""
            ns.TAdd(GameTooltip, " ")
            if key ~= "" then ns.TAdd(GameTooltip, key .. ": 다음 토템 깔기" .. ((tt.shift and not key:find("-", 1, true)) and ("  ·  Shift+" .. key .. ": 다음 세트") or ""), 0.8, 0.74, 0.72) end
            if tt.recallKey and tt.recallKey ~= "" then ns.TAdd(GameTooltip, tt.recallKey .. ": " .. RECALL, 0.8, 0.74, 0.72) end
            ns.TAdd(GameTooltip, "오른쪽 클릭: 1번부터 다시 (전투 밖)", 0.8, 0.74, 0.72)
            ns.TAdd(GameTooltip, "세트 고치기: 아래 세트 이름 오른쪽 클릭 · /르엘토템", 0.8, 0.74, 0.72)
            GameTooltip:Show()
        end)
        q:SetScript("OnLeave", function() Motion(false); GameTooltip:Hide() end)
        q:SetScript("PreClick", function(_, btn)
            if btn ~= "RightButton" then
                pressT = GetTime(); lastPress = GetTime()
                TLog("누름 " .. (InCombatLockdown() and "[전투]" or "[밖]") .. " 다음=" .. tostring(seq[step + 1] and SpellName(seq[step + 1]) or "-") .. " | " .. SlotText())
                if not InCombatLockdown() and #seq == 0 and #CurList() > 0 and ns.Print then
                    if (q.saidAll or 0) < GetTime() - 5 then q.saidAll = GetTime(); ns.Print("토템이 다 깔려 있어요.") end
                end
            end
        end)
        q:SetScript("PostClick", function(_, btn)
            if btn == "RightButton" and not InCombatLockdown() then Apply(true); ns.TotemSetPaint() end
            if btn == "MiddleButton" and ns.ToggleHub then ns:ToggleHub("LeelUI_TotemSet") end
        end)
        -- 토템의 귀환 단추 (보이지 않는 보호 단추 · 단축키로만)
        q.recall = CreateFrame("Button", "LeelUI_TotemRecall", q, "SecureActionButtonTemplate")
        q.recall:SetSize(1, 1); q.recall:SetPoint("CENTER")
        q.recall:RegisterForClicks(down and "AnyDown" or "AnyUp")
        q.recall:SetScript("PostClick", function() lastOk = 0; step = 0 end)
        -- Shift+키 = 다음 세트 (전투 밖에서만)
        local nx = CreateFrame("Button", "LeelUI_TotemSetNext", q)
        nx:SetScript("OnClick", function()
            if InCombatLockdown() then return end
            local tt = SDB(); tt.cur = (tt.cur % 3) + 1
            Apply(true); ns.TotemSetPaint()
            if ns.Print then ns.Print("토템 세트: " .. SETNAMES[tt.cur]) end
        end)
        -- 지금 세트 이름 (단추 아래) · 누르면 다음 세트 (전투 밖)
        local tb = CreateFrame("Button", nil, r)
        tb:SetSize(40, 14)
        tb:SetPoint("TOP", q, "BOTTOM", 0, -6)
        -- 세트 점 3개 (사냥 · 던전 · 보스) · 지금 세트만 분홍
        tb.dots = {}
        for i = 1, 3 do
            local d = tb:CreateTexture(nil, "ARTWORK"); d:SetTexture(ns.MEDIA .. "circle")
            d:SetSize(7, 7); d:SetPoint("CENTER", (i - 2) * 11, 0)
            tb.dots[i] = d
        end
        tb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        tb:SetScript("OnClick", function(_, btn)
            if btn == "RightButton" then if ns.ToggleHub then ns:ToggleHub("LeelUI_TotemSet") end
            else nx:Click() end
        end)
        tb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            ns.TSet(GameTooltip, "토템 세트 · " .. (SETNAMES[SDB().cur] or ""), 0.95, 0.70, 0.76)
            ns.TAdd(GameTooltip, "클릭: 사냥 → 던전 → 보스 (전투 밖)", 0.8, 0.74, 0.72)
            ns.TAdd(GameTooltip, "오른쪽 클릭: 세트 고치기 (허브)", 0.8, 0.74, 0.72)
            GameTooltip:Show()
        end)
        tb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        q.tabs = { tb }
        Apply(true)
        ns.TotemSetPaint()
    end
    function ns.TotemSetPaint()
        if not q then return end
        local t = SDB(); if not t then return end
        -- 3초 동안 안 누르면 처음부터 (게임 순서와 같이)
        if step > 0 and lastPress > 0 and GetTime() - lastPress > 3 then step = 0 end
        -- 전투 밖: 깔린 상태가 바뀌면 다시 짜요 (방금 누른 직후는 잠깐 기다렸다가)
        if not InCombatLockdown() and not fighting and t.on then
            local sig = "N:" .. table.concat(SmartList(), ",")
            if sig ~= q.sig then Apply(false) end
        end
        for e = 1, 4 do
            local s = q.seg[e]
            local c = ELEM[e][2]
            if Active(e) then s:SetVertexColor(c[1], c[2], c[3], 1) else s:SetVertexColor(0.29, 0.24, 0.25, 1) end
        end
        local n = #seq
        -- ✓ = 세트 토템이 실제로 다 깔려 있을 때만
        local cur = CurList()
        local all = #cur > 0
        for _, id in ipairs(cur) do if Remain(id) <= 0 then all = false end end
        q.done:Hide()   -- 다 깔림 표시(V)는 안 써요
        local key = t.key or ""
        q.key:SetShown(key ~= "")
        q.key.fs:SetText(key)
        local tb = q.tabs[1]
        for i, d in ipairs(tb.dots) do
            if i == t.cur then d:SetVertexColor(0.95, 0.70, 0.76, 1) else d:SetVertexColor(0.29, 0.24, 0.25, 1) end
        end
        if not InCombatLockdown() then   -- 보호 단추에 붙은 칸이라 전투 중엔 크기를 못 바꿔요
            q.key:SetWidth(math.max(18, q.key.fs:GetStringWidth() + 10))
        end
    end
    local sev = CreateFrame("Frame")
    sev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    sev:RegisterEvent("PLAYER_REGEN_ENABLED")
    sev:RegisterEvent("PLAYER_TOTEM_UPDATE")
    sev:RegisterEvent("PLAYER_REGEN_DISABLED")
    sev:RegisterEvent("SPELLS_CHANGED")
    sev:SetScript("OnEvent", function(_, ev, a1, a2, a3)
        if not q then return end
        if ev == "UNIT_SPELLCAST_SUCCEEDED" then
            if a3 and not issecret(a3) then
                local nm = SpellName(a3)
                if nm and nm:find("토템", 1, true) then TLog("시전 " .. nm .. " (" .. tostring(a3) .. ")") end
            elseif a3 then TLog("시전 (비밀)") end
            if pressT > 0 and GetTime() - pressT < 1 then
                local ok = true
                local want = seq[step + 1]
                if a3 and not issecret(a3) and want then
                    -- 같은 토템이면(랭크가 달라도 이름으로) 하나 깔았다고 셈
                    ok = (a3 == want) or (SpellName(a3) == SpellName(want))
                end
                if ok then
                    step = step + 1; if step > #seq then step = 1 end
                    pressT = 0; lastOk = GetTime()   -- 한 번 누름 = 하나만 셈
                end
            end
        elseif ev == "PLAYER_REGEN_DISABLED" then
            -- 전투 시작 (아직 바꿀 수 있는 마지막 순간): 안 깔린 것 먼저 + 깔린 것도 뒤에
            -- fighting: 이 뒤로는 전투가 끝날 때까지 다시 짜지 않아요 (전투용 순서를 덮어쓰지 않게)
            fighting = true
            Apply(false, true)
        elseif ev == "PLAYER_REGEN_ENABLED" then
            step = 0; fighting = false
            Apply(q.pending)
        elseif ev == "PLAYER_TOTEM_UPDATE" then
            TLog("토템바뀜 칸" .. tostring(not issecret(a1) and a1 or "?") .. " | " .. SlotText())
            -- 깔리자마자 바로 다음 토템으로 (연타해도 같은 걸 또 깔지 않게)
            if not InCombatLockdown() and not fighting then Apply(false) end
        elseif ev == "SPELLS_CHANGED" then
            -- 새 토템을 배웠을 때만 다시 (자주 와요 · 순서가 1번으로 돌아가면 안 돼요)
            if not InCombatLockdown() and not fighting then Apply(false) end
        end
        ns.TotemSetPaint()
    end)

    local tev = CreateFrame("Frame")
    tev:RegisterEvent("PLAYER_ENTERING_WORLD")
    tev:RegisterEvent("PLAYER_TOTEM_UPDATE")
    tev:RegisterEvent("PLAYER_REGEN_ENABLED")
    tev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    local lastCast
    -- 처음 접속 때는 위쪽 HUD가 늦게 만들어질 수 있어요: 생길 때까지 1초마다 다시 (최대 30번)
    local tries = 0
    local function TryBuild()
        if row then return end
        if not InCombatLockdown() then Build() end
        tries = tries + 1
        if not row and tries < 30 then C_Timer.After(1, TryBuild) end
    end
    tev:SetScript("OnEvent", function(_, ev, a1, a2, a3)
        if not row then
            if ev == "PLAYER_ENTERING_WORLD" then tries = 0; C_Timer.After(0.5, TryBuild) else C_Timer.After(0.5, Build) end
        end
        if ev == "UNIT_SPELLCAST_SUCCEEDED" then
            local spell = a3
            if issecret(spell) then return end
            -- 토템 주문일 때만 기억 (대지 충격 같은 다른 주문을 쓴 직후 토템이 사라지면 그 그림이 들어가던 문제)
            local nm
            pcall(function() nm = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spell)) or (GetSpellInfo and (GetSpellInfo(spell))) end)
            if type(nm) ~= "string" or issecret(nm) then return end
            local isTotem = (nm:find("토템") or nm:find("Totem")) and not (nm:find("귀환") or nm:find("Recall"))
            if not isTotem then return end
            lastCast = { t = GetTime(), spell = spell }
            return
        end
        if ev == "PLAYER_TOTEM_UPDATE" and row then
            local slot = a1
            -- 전투 중 바뀐 칸: 방금 주문을 썼으면 새로 깐 것, 아니면 사라진 것
            if not issecret(slot) and row.s[slot] and InCombatLockdown() then
                local b = row.s[slot]
                b.start, b.dur, b.secretSet = nil, nil, nil
                if lastCast and GetTime() - lastCast.t < 1.5 then
                    b.known = true
                    local tex
                    if lastCast.spell then
                        local ok, t = pcall(function() return (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(lastCast.spell)) or (GetSpellTexture and GetSpellTexture(lastCast.spell)) end)
                        if ok and t and not issecret(t) then tex = t end
                    end
                    b.lastIcon = tex
                    local learned = tex and ns.db and ns.db.totemDur and ns.db.totemDur[tostring(tex)]
                    if learned then
                        b.start, b.dur = lastCast.t, learned
                        b.cd:SetHideCountdownNumbers(true)
                        pcall(b.cd.SetCooldown, b.cd, lastCast.t, learned)
                    end
                else
                    b.known = false; b.lastIcon = nil
                end
            end
            for _, b in ipairs(row.s) do b.secretSet = nil end
        end
        if ev == "PLAYER_REGEN_ENABLED" and row and row.pending then Layout(true) end
        Paint()
    end)
end


----------------------------------------------------------------------
-- 내 창 전투 밖에서 흐리게 (허브 > Leel HUD > 내 창 · 처음엔 꺼짐)
--   또렷할 때: 전투 중 · 대상 있음 · 체력 / 마나 · 기력이 덜 참 (분노는 있을 때) · 마우스를 올림
--   흐리게만 바꿔요 (게임 보호 창이라 숨기거나 옮기진 않아요)
----------------------------------------------------------------------
do
    local cur, want = 1, 1
    local function Frames()
        local t = {}
        local p = _G.LeelUI_player; if p then t[#t + 1] = p end
        local pet = ns.hudFrames and ns.hudFrames.pet; if pet then t[#t + 1] = pet end
        return t
    end
    local function Busy()
        if InCombatLockdown() or UnitAffectingCombat("player") then return true end
        if UnitExists("target") then return true end
        local ok, r = pcall(function()
            if UnitHealth("player") < UnitHealthMax("player") then return true end
            local pt = UnitPowerType("player")
            local pw, pm = UnitPower("player", pt), UnitPowerMax("player", pt)
            if pt == 1 or pt == 6 then return pw > 0 end      -- 분노 · 룬마력: 있으면
            return pm > 0 and pw < pm
        end)
        if ok and r then return true end
        for _, f in ipairs(Frames()) do if f:IsMouseOver() then return true end end
        return false
    end
    local fr = CreateFrame("Frame")
    local acc = 0
    fr:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc >= 0.2 then
            acc = 0
            if ns.db and ns.db.hudFade == true and not ns.db.hudOff then
                want = Busy() and 1 or ((tonumber(ns.db.hudFadeA) or 25) / 100)
            else want = 1 end
        end
        if cur ~= want then
            local step = el * 3
            if cur < want then cur = math.min(want, cur + step) else cur = math.max(want, cur - step) end
            for _, f in ipairs(Frames()) do pcall(f.SetAlpha, f, cur) end
        end
    end)
    function ns.HudFadeUpdate(now)
        acc = 1
        if now then want = 1 end
    end
end
