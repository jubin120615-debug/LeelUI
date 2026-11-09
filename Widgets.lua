-- LeelUI / Widgets.lua
-- 연분홍 둥근 테마: ForG 톤의 따뜻한 판 + 장미색 테두리, 알약 모양 바, 둥근 초상화

local _, ns = ...

-- 색 (연분홍 시안 2번과 동일)
ns.C = {
    acc   = { 0.949, 0.702, 0.761 },        -- 연분홍 #F2B3C2
    accHi = { 1.00, 0.84, 0.878 },          -- 밝은 분홍 #FFD6E0 (기력, 숫자)
    dmg   = { 0.85, 0.26, 0.18 },           -- 피해 / 위험
    mana  = { 0.24, 0.48, 1.00 },
    plate = { 0.184, 0.145, 0.133, 0.88 },  -- ForG 판 #2F2522
    edge  = { 0.839, 0.627, 0.612, 0.38 },  -- 장미색 테두리
    tx    = { 0.965, 0.925, 0.91 },
    tx2   = { 0.839, 0.627, 0.612 },        -- 연분홍 보조 글자 #D6A09C
    ink   = { 0.227, 0.11, 0.141 },         -- 분홍 바 위 숫자 #3A1C24
    grey  = { 0.49, 0.52, 0.58 },
}
local C = ns.C

local function Tex(parent, layer, sub, file, c, a)
    local t = parent:CreateTexture(nil, layer, nil, sub or 0)
    t:SetTexture(file)
    t:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1)
    return t
end
ns.Tex = Tex

-- 한글/일반 글씨: 외곽선 없이 그림자만
function ns.Font(parent, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(ns.FONT, size, "")
    if ns.TrackText then ns.TrackText(fs, size, "") end
    fs:SetShadowColor(0, 0, 0, 0.85)
    fs:SetShadowOffset(1, -1)
    color = color or C.tx
    fs:SetTextColor(color[1], color[2], color[3])
    return fs
end

-- 숫자 전용: Barlow Condensed 이탤릭
function ns.Num(parent, size, color, bold)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local file = bold == false and ns.NUM_B or ns.NUM
    if not fs:SetFont(file, size, "") then fs:SetFont(ns.FONT, size, "") end
    fs:SetShadowColor(0, 0, 0, 0.6)
    fs:SetShadowOffset(0, -2)
    color = color or C.tx
    fs:SetTextColor(color[1], color[2], color[3])
    return fs
end

local function Mask(frame, file)
    local m = frame:CreateMaskTexture()
    m:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(frame)
    return m
end

-- 반투명 판 + 1px 테두리 + 아래 그림자
local function Plate(holder, shape, edgePx)
    edgePx = edgePx or 1
    local sh = Tex(holder, "BACKGROUND", 0, shape, { 0, 0, 0 }, 0.4)
    sh:SetPoint("TOPLEFT", -2, -2)
    sh:SetPoint("BOTTOMRIGHT", 2, -5)
    local edge = Tex(holder, "BACKGROUND", 1, shape, C.edge)
    edge:SetPoint("TOPLEFT", -edgePx, edgePx)
    edge:SetPoint("BOTTOMRIGHT", edgePx, -edgePx)
    local bg = Tex(holder, "BORDER", 0, shape, C.plate)
    bg:SetAllPoints()
    holder.border, holder.shadow = edge, sh
end

----------------------------------------------------------------------
-- 사선 상태바
-- opts.mirrored : 대상 쪽 (오른쪽에서 줄어듦)
-- opts.inset    : 판 안쪽 여백 (채움이 판보다 살짝 작게)
-- opts.ticks    : 눈금 수
----------------------------------------------------------------------
function ns.CreateSkewBar(parent, w, h, opts)
    opts = opts or {}
    local shape = ns.MEDIA .. (opts.shape or "pill16")
    local inset = opts.inset or 0

    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(w, h)
    Plate(holder, shape, opts.edge or 1)
    if opts.noShadow then holder.shadow:Hide() end

    local sb = CreateFrame("StatusBar", nil, holder)
    sb:SetPoint("TOPLEFT", inset, -inset)
    sb:SetPoint("BOTTOMRIGHT", -inset, inset)
    sb:SetStatusBarTexture(ns.WHITE)
    sb:SetReverseFill(opts.mirrored and true or false)
    sb:SetMinMaxValues(0, 1)
    sb:SetValue(1)
    local fill = sb:GetStatusBarTexture()
    fill:AddMaskTexture(Mask(sb, shape))

    local over = CreateFrame("Frame", nil, holder)
    over:SetAllPoints()
    over:SetFrameLevel(sb:GetFrameLevel() + 2)

    if opts.ticks then
        for i = 1, opts.ticks do
            local t = Tex(over, "ARTWORK", 0, ns.WHITE, C.plate, 0.9)
            t:SetSize(1, h)
            t:SetPoint("LEFT", w * i / (opts.ticks + 1), 0)
        end
    end

    holder.bar, holder.fill, holder.over = sb, fill, over
    holder.shapeName = opts.shape or "pill16"
    return holder
end

-- 분홍 체력바: 거의 단색, 위쪽만 살짝 밝게
function ns.PaintHealth(holder)
    local fill = holder.fill
    if fill.SetGradient and CreateColor then
        fill:SetVertexColor(1, 1, 1, 1)
        fill:SetGradient("VERTICAL",
            CreateColor(C.acc[1], C.acc[2], C.acc[3], 1),
            CreateColor(1.00, 0.86, 0.90, 1))
    else
        fill:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    end
end

-- 선점된 몹: 회색 바 + 사선 빗금 (바 모양대로 잘라서)
ns.TAP = { 0.6, 0.58, 0.6 }
function ns.SetTapped(holder, tapped)
    if tapped and not holder.hatch then
        local h = holder.over:CreateTexture(nil, "BACKGROUND")
        h:SetTexture(ns.MEDIA .. "stripes", "REPEAT", "REPEAT")
        h:SetHorizTile(true); h:SetVertTile(true)
        h:SetAllPoints(holder.bar)
        local m = holder.over:CreateMaskTexture()
        m:SetTexture(ns.MEDIA .. (holder.shapeName or "pill16"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(holder.bar)
        h:AddMaskTexture(m)
        holder.hatch = h
    end
    if holder.hatch then holder.hatch:SetShown(tapped and true or false) end
    if tapped then ns.PaintFlat(holder, ns.TAP) end
end

function ns.PaintFlat(holder, c)
    local fill = holder.fill
    if fill.SetGradient and CreateColor then
        local col = CreateColor(c[1], c[2], c[3], 1)
        fill:SetGradient("VERTICAL", col, col)
    end
    fill:SetVertexColor(c[1], c[2], c[3], 1)
end

----------------------------------------------------------------------
-- 연계 점수 5칸 (작은 둥근 칸)
----------------------------------------------------------------------
function ns.CreatePips(parent, w, h)
    local shape = ns.MEDIA .. "pips_round"
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(w, h)
    local bg = Tex(holder, "BORDER", 0, shape, { 1, 1, 1 }, 0.14)
    bg:SetAllPoints()

    local sb = CreateFrame("StatusBar", nil, holder)
    sb:SetAllPoints()
    sb:SetStatusBarTexture(ns.WHITE)
    sb:SetStatusBarColor(C.dmg[1], C.dmg[2], C.dmg[3], 1)
    sb:SetMinMaxValues(0, 5)
    sb:SetValue(0)
    sb:GetStatusBarTexture():AddMaskTexture(Mask(sb, shape))
    holder.bar = sb
    return holder
end

----------------------------------------------------------------------
-- 연계 점수 구슬 5개 (몹마다 따로): 어두운 구슬 위에 분홍 채움, 5개면 빨강
----------------------------------------------------------------------
function ns.CreateDots(parent, w, h)
    local shape = ns.MEDIA .. "dots"
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(w, h)
    local edge = Tex(holder, "BACKGROUND", 0, shape, { 0, 0, 0 }, 0.9)
    edge:SetPoint("TOPLEFT", -1, 1); edge:SetPoint("BOTTOMRIGHT", 1, -1)
    local bg = Tex(holder, "BORDER", 0, shape, C.plate, 1)
    bg:SetAllPoints()
    local sb = CreateFrame("StatusBar", nil, holder)
    sb:SetAllPoints()
    sb:SetStatusBarTexture(ns.WHITE)
    sb:SetMinMaxValues(0, 5)
    sb:SetValue(0)
    sb:GetStatusBarTexture():AddMaskTexture(Mask(sb, shape))
    holder.bar = sb
    function holder:SetCount(n)
        ns.SetBar(self.bar, n, 5)
        local full = ns.Try(function() return n >= 5 end)
        local c = full and { 1, 0.35, 0.29 } or C.acc
        self.bar:SetStatusBarColor(c[1], c[2], c[3], 1)
    end
    return holder
end

-- 이 몹에 쌓인 내 연계 점수 (몹마다 따로). 못 읽으면 nil
local PT = Enum and Enum.PowerType or {}
local COMBO, ENERGY = PT.ComboPoints or 4, PT.Energy or 3
function ns.UsesCombo()
    return ns.Try(function() return UnitPowerType("player") == ENERGY end)
end
function ns.ComboOn(unit)
    if GetComboPoints then
        local ok, n = pcall(GetComboPoints, "player", unit)
        if ok then return n end
    end
    if ns.Try(UnitIsUnit, unit, "target") then
        local ok, n = pcall(UnitPower, "player", COMBO)
        if ok then return n end
    end
end

----------------------------------------------------------------------
-- 둥근 초상화: 둥근 사각형으로 자르고 연분홍 테두리
----------------------------------------------------------------------
function ns.CreatePortrait(parent, w, h)
    local shape = ns.MEDIA .. "portrait_round"
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(w, h)

    local sh = Tex(holder, "BACKGROUND", 0, shape, { 0, 0, 0 }, 0.45)
    sh:SetPoint("TOPLEFT", 0, -4)
    sh:SetPoint("BOTTOMRIGHT", 0, -8)
    local bg = Tex(holder, "BORDER", 0, shape, { 0.08, 0.06, 0.06 }, 1)
    bg:SetAllPoints()

    local tex = holder:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:AddMaskTexture(Mask(holder, shape))

    local edge = Tex(holder, "OVERLAY", 0, ns.MEDIA .. "portrait_edge", C.acc)
    edge:SetAllPoints()

    holder.tex, holder.cut = tex, edge
    return holder
end

----------------------------------------------------------------------
-- 둥근 사각형 (설정 창, 버튼, 스위치용): 원 그림 4조각 + 사각형 3개
-- r 이 높이의 절반이면 알약 모양
----------------------------------------------------------------------
function ns.RoundRect(parent, r, color, layer, sub, inset)
    layer, sub, inset = layer or "BACKGROUND", sub or 0, inset or 0
    local o = { tex = {} }
    local function add(t) o.tex[#o.tex + 1] = t; return t end
    local corners = {
        TOPLEFT = { 0, 0.5, 0, 0.5 }, TOPRIGHT = { 0.5, 1, 0, 0.5 },
        BOTTOMLEFT = { 0, 0.5, 0.5, 1 }, BOTTOMRIGHT = { 0.5, 1, 0.5, 1 },
    }
    for point, tc in pairs(corners) do
        local c = add(parent:CreateTexture(nil, layer, nil, sub))
        c:SetTexture(ns.MEDIA .. "circle")
        c:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        c:SetSize(r, r)
        c:SetPoint(point, parent, point, point:find("LEFT") and inset or -inset, point:find("TOP") and -inset or inset)
    end
    local mid = add(parent:CreateTexture(nil, layer, nil, sub))
    mid:SetTexture(ns.WHITE)
    mid:SetPoint("TOPLEFT", inset + r, -inset)
    mid:SetPoint("BOTTOMRIGHT", -inset - r, inset)
    local left = add(parent:CreateTexture(nil, layer, nil, sub))
    left:SetTexture(ns.WHITE)
    left:SetPoint("TOPLEFT", inset, -inset - r)
    left:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", inset + r, inset + r)
    local right = add(parent:CreateTexture(nil, layer, nil, sub))
    right:SetTexture(ns.WHITE)
    right:SetPoint("TOPRIGHT", -inset, -inset - r)
    right:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", -inset - r, inset + r)

    function o:SetColor(c, a)
        for _, t in ipairs(self.tex) do t:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1) end
    end
    if color then o:SetColor(color) end
    return o
end

-- 테두리 있는 둥근 판: 바깥 = 테두리 색, 1px 안쪽 = 바탕 색
function ns.RoundPlate(parent, r, fill, edge)
    local e = ns.RoundRect(parent, r, edge or C.edge, "BACKGROUND", 0, 0)
    local f = ns.RoundRect(parent, math.max(1, r - 1), fill or C.plate, "BACKGROUND", 1, 1)
    return f, e
end
