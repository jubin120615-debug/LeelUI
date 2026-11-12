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

-- 위쪽 HUD · 몹 이름표 체력바: 루비 레드 (아래 깊은 빨강, 위 밝게)
ns.HP_RED = { 0.722, 0.118, 0.208 }   -- #B81E35
function ns.PaintHealthRed(holder)
    local fill = holder.fill
    if fill.SetGradient and CreateColor then
        fill:SetVertexColor(1, 1, 1, 1)
        fill:SetGradient("VERTICAL",
            CreateColor(0.722, 0.118, 0.208, 1),
            CreateColor(0.949, 0.439, 0.498, 1))
    else
        fill:SetVertexColor(ns.HP_RED[1], ns.HP_RED[2], ns.HP_RED[3], 1)
    end
end

-- 선점된 몹: 회색 바 + 사선 빗금 (바 모양대로 잘라서)
ns.TAP = { 0.56, 0.54, 0.55 }
function ns.SetTapped(holder, tapped)
    if tapped and not holder.hatch then
        -- 굵고 진한 빗금 (C안): 무늬 한 장을 크게 늘려서 줄을 두껍게
        local h = holder.over:CreateTexture(nil, "BACKGROUND")
        h:SetTexture(ns.MEDIA .. "stripes", "REPEAT", "REPEAT")
        h:SetAllPoints(holder.bar)
        local bw, bh = holder:GetSize()
        h:SetTexCoord(0, math.max(1, (bw or 160) / 44), 0, math.max(0.3, (bh or 16) / 44))
        h:SetVertexColor(0.16, 0.14, 0.15, 1)
        local h2 = holder.over:CreateTexture(nil, "BACKGROUND", nil, 1)
        h2:SetTexture(ns.MEDIA .. "stripes", "REPEAT", "REPEAT")
        h2:SetAllPoints(holder.bar)
        h2:SetTexCoord(0, math.max(1, (bw or 160) / 44), 0, math.max(0.3, (bh or 16) / 44))
        h2:SetVertexColor(0.16, 0.14, 0.15, 1)
        local m = holder.over:CreateMaskTexture()
        m:SetTexture(ns.MEDIA .. (holder.shapeName or "pill16"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(holder.bar)
        h:AddMaskTexture(m); h2:AddMaskTexture(m)
        holder.hatch, holder.hatch2 = h, h2
    end
    if holder.hatch then
        holder.hatch:SetShown(tapped and true or false)
        holder.hatch2:SetShown(tapped and true or false)
    end
    if tapped then ns.PaintFlat(holder, ns.TAP) end
end

-- 글씨 위 가로줄 (남의 몹 이름)
function ns.SetStrike(fs, on)
    local line = fs.leelStrike
    if on and not line then
        local parent = fs:GetParent()
        line = parent:CreateTexture(nil, "OVERLAY", nil, 7)
        line:SetTexture(ns.WHITE)
        line:SetVertexColor(0.86, 0.82, 0.84, 0.95)
        line:SetHeight(2)
        line:SetPoint("LEFT", fs, "LEFT", -1, 0)
        line:SetPoint("RIGHT", fs, "LEFT", 1, 0)
        fs.leelStrike = line
    end
    if line then
        if on then
            line:ClearAllPoints()
            line:SetPoint("LEFT", fs, "LEFT", -1, -1)
            if not pcall(function() line:SetWidth(math.max(4, (fs:GetStringWidth() or 0) + 2)) end) then line:SetWidth(40) end
        end
        line:SetShown(on and true or false)
    end
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

----------------------------------------------------------------------
-- 마우스 툴팁 (C안): 진한 둥근 판 + 왼쪽 색 줄(적/중립/우호/직업) + 오른쪽 위 작은 토끼
-- 내용은 블리자드 그대로, 겉모양과 위치(커서 오른쪽 아래)만 바꿈
----------------------------------------------------------------------
do
    local PASTEL = {
        WARRIOR = { 0.902, 0.804, 0.690 }, PALADIN = { 0.980, 0.776, 0.863 }, HUNTER = { 0.824, 0.910, 0.702 },
        ROGUE = { 1.000, 0.953, 0.651 }, PRIEST = { 0.949, 0.933, 0.914 }, SHAMAN = { 0.651, 0.784, 0.957 },
        MAGE = { 0.678, 0.886, 0.965 }, WARLOCK = { 0.788, 0.741, 0.918 }, DRUID = { 1.000, 0.776, 0.604 },
    }
    local HOSTILE, NEUTRAL, FRIEND = { 1, 0.54, 0.54 }, { 1, 0.85, 0.42 }, { 0.62, 0.92, 0.66 }

    local function SetStripe(tt, c)
        if tt.leelStripe then tt.leelStripe:SetVertexColor(c[1], c[2], c[3], 1) end
        local sb = tt == GameTooltip and _G.GameTooltipStatusBar
        if sb and sb.leelSkinned then sb:SetStatusBarColor(c[1], c[2], c[3], 1) end
    end

    local function Skin(tt, bunny)
        if not tt or tt.leelSkin then return end
        tt.leelSkin = true
        if tt.NineSlice then tt.NineSlice:SetAlpha(0) end
        if tt.SetBackdrop then pcall(tt.SetBackdrop, tt, nil) end
        local bg = CreateFrame("Frame", nil, tt)
        bg:SetAllPoints()
        bg:SetFrameLevel(math.max(0, tt:GetFrameLevel() - 1))
        ns.RoundPlate(bg, 14, { 0.114, 0.082, 0.078, 0.97 }, { 0.949, 0.702, 0.761, 0.38 })
        local st = bg:CreateTexture(nil, "BORDER")
        st:SetTexture(ns.WHITE)
        st:SetPoint("TOPLEFT", bg, "TOPLEFT", 1, -10)
        st:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT", 1, 10)
        st:SetWidth(5)
        st:Hide()          -- A안: 왼쪽 세로 줄 대신 이름 옆 "적대/중립/우호" 칩 (빨강은 체력 바만)
        tt.leelStripe = st
        if bunny then
            local b = CreateFrame("Frame", nil, tt)
            b:SetSize(24, 24)
            b:SetPoint("CENTER", tt, "TOPRIGHT", -4, -2)
            b:SetFrameLevel(tt:GetFrameLevel() + 5)
            local r = b:CreateTexture(nil, "BACKGROUND")
            r:SetTexture(ns.MEDIA .. "circle"); r:SetVertexColor(0.949, 0.702, 0.761, 0.8)
            r:SetPoint("TOPLEFT", -1.5, 1.5); r:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
            local d = b:CreateTexture(nil, "BORDER")
            d:SetTexture(ns.MEDIA .. "circle"); d:SetVertexColor(0.17, 0.13, 0.125, 1); d:SetAllPoints()
            local i = b:CreateTexture(nil, "ARTWORK")
            i:SetTexture(ns.MEDIA .. "bunny"); i:SetPoint("CENTER"); i:SetSize(20, 20)
        end
        SetStripe(tt, C.acc)
        tt:HookScript("OnHide", function(self) self.leelUnitCol = nil; SetStripe(self, C.acc) end)
        -- 다른 곳에서 테두리를 다시 그리면 또 숨김
        if tt.NineSlice then
            hooksecurefunc(tt.NineSlice, "Show", function(ns9) ns9:SetAlpha(0) end)
        end
    end

    -- 체력바 자리 맞추기: 마지막 글줄 아래로 바가 들어갈 만큼(26) 툴팁을 늘려요
    --   (게임이 툴팁 높이를 다시 계산해도 매 프레임 다시 맞춰서, 짧은 툴팁 줄이 바에 가리지 않게)
    local function FitBar()
        pcall(function()
            local tt = GameTooltip
            local n = tt:NumLines()
            if type(n) ~= "number" or (issecretvalue and issecretvalue(n)) then return end
            local last
            for i = n, 1, -1 do
                local l = _G["GameTooltipTextLeft" .. i]
                if l and l:IsShown() then last = l; break end
            end
            if not last then return end
            local lb, tb, h = last:GetBottom(), tt:GetBottom(), tt:GetHeight()
            if not (lb and tb and h) then return end
            if issecretvalue and (issecretvalue(lb) or issecretvalue(tb) or issecretvalue(h)) then return end
            local room = lb - tb
            if room < 25 then tt:SetHeight(h + (26 - room)) end
        end)
    end

    -- 체력바: 툴팁 아래 얇은 알약
    local function SkinStatusBar()
        local sb = _G.GameTooltipStatusBar
        if not sb or sb.leelSkinned then return end
        sb.leelSkinned = true
        -- 블리자드가 체력에 따라 초록/노랑으로 다시 칠해도 우리 색으로
        local painting = false
        local RED = ns.HP_RED or { 0.722, 0.118, 0.208 }
        hooksecurefunc(sb, "SetStatusBarColor", function(self)
            if painting then return end
            painting = true
            self:SetStatusBarColor(RED[1], RED[2], RED[3], 1)   -- 체력은 항상 빨강
            painting = false
        end)
        sb:SetStatusBarTexture(ns.WHITE)
        -- 툴팁 안쪽 아래에 넣어요 (자리는 툴팁에 빈 줄 2개를 더해서 마련)
        local function Place()
            sb:ClearAllPoints()
            sb:SetPoint("BOTTOMLEFT", GameTooltip, "BOTTOMLEFT", 12, 12)
            sb:SetPoint("BOTTOMRIGHT", GameTooltip, "BOTTOMRIGHT", -52, 12)
            sb:SetHeight(8)
        end
        Place()
        hooksecurefunc(sb, "SetPoint", function() if not sb.leelPlacing then sb.leelPlacing = true; Place(); sb.leelPlacing = false end end)
        -- "체력" 글씨는 빼고, % 숫자만 바 오른쪽 끝에
        sb.leelR = ns.Num(sb, 12, C.accHi); sb.leelR:SetPoint("LEFT", sb, "RIGHT", 8, 0)
        local acc = 0
        sb:HookScript("OnUpdate", function(self, el)
            FitBar()
            acc = acc + el
            if acc < 0.2 then return end
            acc = 0
            -- 숨겨진 체력 값도 게임 API(UnitHealthPercent)로 % 를 그려요
            local unit
            pcall(function()
                local _, u = GameTooltip:GetUnit()
                if type(u) == "string" and not (issecretvalue and issecretvalue(u)) then unit = u end
            end)
            if not unit and UnitExists("mouseover") then unit = "mouseover" end
            if not unit then self.leelR:SetText(""); return end
            local h, m
            pcall(function() h = UnitHealth(unit); m = UnitHealthMax(unit) end)
            if not pcall(ns.HealthPercentText, self.leelR, unit, h, m) then
                self.leelR:SetText("")
            end
        end)
        local m = sb:CreateMaskTexture()
        m:SetTexture(ns.MEDIA .. "pill32", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(sb)
        sb:GetStatusBarTexture():AddMaskTexture(m)
        local bg = sb:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(ns.WHITE); bg:SetAllPoints(); bg:SetVertexColor(0.11, 0.08, 0.075, 0.9)
        bg:AddMaskTexture(m)
        if sb.NineSlice then sb.NineSlice:SetAlpha(0) end
        for _, r in ipairs({ sb:GetRegions() }) do
            if r ~= sb:GetStatusBarTexture() and r ~= bg and r.GetObjectType and r:GetObjectType() == "Texture"
               and r.GetTexture and r:GetTexture() ~= nil and r ~= m then
                local ok, file = pcall(r.GetTexture, r)
                if ok and type(file) == "string" and file:lower():find("border") then r:SetAlpha(0) end
            end
        end
    end

    -- 유닛 색: 플레이어 = 직업 파스텔, 몹 = 적대 빨강 / 중립 노랑 / 우호 초록
    local function UnitColor(unit)
        local col
        pcall(function()
            if UnitIsPlayer(unit) then
                local _, file = UnitClass(unit)
                col = PASTEL[file]
            end
            if not col then
                local r = UnitReaction(unit, "player")
                if r then col = (r <= 3 and HOSTILE) or (r == 4 and NEUTRAL) or FRIEND end
            end
        end)
        return col
    end

    -- 커서 오른쪽 아래에 붙어서 따라다니기
    local follow = CreateFrame("Frame")
    follow:Hide()
    follow:SetScript("OnUpdate", function()
        local tt = GameTooltip
        if not tt:IsShown() or not tt.leelCursor then follow:Hide() return end
        local x, y = GetCursorPosition()
        local s = tt:GetEffectiveScale()
        tt:ClearAllPoints()
        tt:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s + 20, y / s - 22)
    end)

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:SetScript("OnEvent", function()
        Skin(GameTooltip, true)
        for _, n in ipairs({ "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip" }) do
            Skin(_G[n], false)
        end
        SkinStatusBar()
        GameTooltip:SetClampedToScreen(true)

        hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tt, parent)
            if tt ~= GameTooltip then return end
            if ns.db and ns.db.tipCursor == false then tt.leelCursor = nil return end
            tt:SetOwner(parent, "ANCHOR_NONE")
            tt.leelCursor = true
            follow:Show()
            local x, y = GetCursorPosition()
            local s = tt:GetEffectiveScale()
            tt:ClearAllPoints()
            tt:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s + 20, y / s - 22)
        end)
        GameTooltip:HookScript("OnHide", function(self) self.leelCursor = nil end)

        -- 마우스를 떼면 천천히 사라지지 말고 바로 닫기
        if GameTooltip.FadeOut then
            hooksecurefunc(GameTooltip, "FadeOut", function(self) self:Hide() end)
        end
        local mo = CreateFrame("Frame")
        mo:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        -- 마우스 올린 몹 색으로 왼쪽 줄 + 체력바 (툴팁 자료가 숨겨져 있어도 mouseover로 직접)
        mo:SetScript("OnEvent", function()
            if not UnitExists("mouseover") then return end
            local col = UnitColor("mouseover")
            if col then
                GameTooltip.leelUnitCol = col
                SetStripe(GameTooltip, col)
            end
        end)
        mo:SetScript("OnUpdate", function()
            local tt = GameTooltip
            if not tt:IsShown() then return end
            local owner = tt:GetOwner()
            if owner and owner ~= UIParent and owner ~= WorldFrame then
                -- 버튼이 꺼지거나(잡동사니 다 팔림 등) 숨겨지면 마우스를 떼도 안 닫히는 블리자드 문제 보완
                pcall(function()
                    if not owner:IsVisible() then tt:Hide() return end
                    if owner.IsEnabled and not owner:IsEnabled() and owner.IsMouseOver and not owner:IsMouseOver() then
                        tt:Hide()
                    end
                end)
                return
            end
            if UnitExists("mouseover") then return end
            local ok, isUnit = pcall(function() local _, u = tt:GetUnit(); return u ~= nil end)
            if ok and isUnit then tt:Hide() end
        end)

        if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
            -- 이름 옆 관계 칩 (적대 · 중립 · 우호)
            local chip = CreateFrame("Frame", nil, GameTooltip)
            chip:SetHeight(15)
            chip:SetFrameLevel(GameTooltip:GetFrameLevel() + 3)
            chip.bg = ns.RoundRect(chip, 7, { 0.29, 0.14, 0.14 }, "ARTWORK", 0, 0)
            chip.fs = ns.Font(chip, 10.5, { 1, 0.69, 0.69 }); chip.fs:SetPoint("CENTER", 0, 0); chip.fs:SetShadowColor(0, 0, 0, 0)
            chip:Hide()
            GameTooltip:HookScript("OnHide", function() chip:Hide() end)
            local KIND = {
                hostile = { "적대", { 0.29, 0.14, 0.14 }, { 1, 0.69, 0.69 } },
                neutral = { "중립", { 0.29, 0.247, 0.133 }, { 0.945, 0.851, 0.541 } },
                friend  = { "우호", { 0.184, 0.29, 0.173 }, { 0.75, 0.9, 0.706 } },
            }
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt)
                if not tt or not tt.leelStripe then return end
                local ok, _, unit = pcall(tt.GetUnit, tt)
                if not ok or not unit then return end
                local col = UnitColor(unit)
                if col then tt.leelUnitCol = col; SetStripe(tt, col) end
                if tt ~= GameTooltip then return end
                -- 관계 칩 (플레이어는 직업 색 이름이라 생략)
                local kind
                pcall(function()
                    if not UnitIsPlayer(unit) then
                        local r = UnitReaction(unit, "player")
                        if r then kind = (r <= 3 and "hostile") or (r == 4 and "neutral") or "friend" end
                    end
                end)
                local line1 = _G.GameTooltipTextLeft1
                if kind and line1 then
                    local k = KIND[kind]
                    chip.fs:SetText(k[1]); chip.fs:SetTextColor(k[3][1], k[3][2], k[3][3])
                    chip.bg:SetColor(k[2])
                    chip:SetWidth(36)      -- 글자 폭은 비밀 값일 수 있어 고정 (두 글자)
                    -- 이름 뒤에 칩 들어갈 자리를 띄워 둠
                    pcall(function()
                        local t = line1:GetText()
                        if type(t) == "string" and not t:find("%s%s%s%s%s%s%s$") then
                            local w = line1:GetStringWidth()
                            line1.leelW = not (issecretvalue and issecretvalue(w)) and w or nil
                            line1:SetText(t .. "            ")
                        end
                        chip:ClearAllPoints()
                        local w = line1.leelW
                        if w == nil or (issecretvalue and issecretvalue(w)) then w = nil end
                        if w then chip:SetPoint("LEFT", line1, "LEFT", w + 6, 0) else chip:SetPoint("LEFT", line1, "RIGHT", -60, 0) end
                    end)
                    chip:Show()
                else
                    chip:Hide()
                end
            end)
            -- 체력 바 자리: 툴팁 줄이 다 들어간 뒤(Questie 줄 포함) 맨 아래에 높이를 더해요
            hooksecurefunc(GameTooltip, "Show", function(self)
                local sb = _G.GameTooltipStatusBar
                if not (sb and sb:IsShown()) then return end
                local ok, _, unit = pcall(self.GetUnit, self)
                if not (ok and unit) then return end
                FitBar()
            end)
        end
    end)
end
