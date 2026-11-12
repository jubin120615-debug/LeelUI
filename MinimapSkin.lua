-- LeelUI / MinimapSkin.lua
-- 르엘 미니맵: 모양 4가지 (A 분홍 테 / B 둥근 네모 카드 / C 토끼 귀 / D 아래 버튼 줄) + 블리자드 기본
-- 지도 내용(지형, 화살표, 퀘스트 점)은 그대로, 겉모양만 바꿈. 바꾸면 다시 불러오기.

local _, ns = ...
local C = ns.C

ns.MINIMAP_STYLES = {
    { key = "ring",  label = "분홍 테 동그라미" },
    { key = "card",  label = "둥근 네모 카드" },
    { key = "bunny", label = "토끼 귀" },
    { key = "bar",   label = "동그라미 + 아래 버튼 줄" },
    { key = "blizz", label = "블리자드 기본" },
}

-- 르엘 미니맵은 D(동그라미 + 아래 버튼 줄)로 고정. 끄면 블리자드 기본
local function Style() return (ns.db and ns.db.mmStyle == "blizz") and "blizz" or "bar" end

local hidden = CreateFrame("Frame"); hidden:Hide()
local function Bury(obj)
    if not obj or obj.leelBuried then return end
    obj.leelBuried = true
    if obj.SetParent and obj.IsObjectType and obj:IsObjectType("Frame") then
        pcall(obj.SetParent, obj, hidden)
    elseif obj.Hide then
        obj:Hide()
        if obj.SetAlpha then obj:SetAlpha(0) end
        hooksecurefunc(obj, "Show", function(self) self:Hide() end)
    end
end

local function Font(parent, size, color) return ns.Font(parent, size, color) end

-- 둥근 알약 판 (글자 하나 들어가는)
local function Pill(parent, num)
    local p = CreateFrame("Frame", nil, parent)
    p:SetHeight(22)
    ns.RoundPlate(p, 11, { 0.125, 0.094, 0.086, 0.95 }, { 0.949, 0.702, 0.761, 0.55 })
    p.fs = num and ns.Num(p, 14, C.tx) or Font(p, 12.5)
    p.fs:SetPoint("CENTER", 0, num and 0 or 0)
    function p:Set(t)
        self.fs:SetText(t or "")
        self:SetWidth(math.max(30, (self.fs:GetStringWidth() or 20) + 22))
    end
    return p
end

-- 동그라미 겹 (뒤에 깔리는 테)
local function Disc(parent, size, color, a, layer, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetTexture(ns.MEDIA .. "mm_round")
    t:SetSize(size, size)
    t:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    t:SetVertexColor(color[1], color[2], color[3], a or 1)
    return t
end

----------------------------------------------------------------------
-- 게임 미니맵 버튼 (우편, 추적, 시계/달력, 전장, 파티찾기) 데려오기
----------------------------------------------------------------------
local function Find(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v then return v end
    end
end

local FindSunCached
local UpdateSun
-- 지도 오른쪽 위 해/달(낮밤) 표시: 이름이 없어서 크기와 모양으로 찾음
local function FindSun()
    local box = (MinimapCluster and MinimapCluster.MinimapContainer) or Minimap:GetParent()
    if not box then return end
    for _, c in ipairs({ box:GetChildren() }) do
        local w = c:GetWidth() or 0
        if c ~= Minimap and c.Background and w >= 30 and w <= 56 then return c end
    end
end

local function Buttons()
    FindSunCached = FindSun()
    local mc = MinimapCluster or {}
    local ind = mc.IndicatorFrame or {}
    return {
        sun   = FindSunCached,
        comp  = _G.AddonCompartmentFrame,

        mail  = Find(_G.MiniMapMailFrame, ind.MailFrame),
        track = Find(_G.MiniMapTrackingFrame, _G.MiniMapTracking, mc.Tracking),
        cal   = _G.GameTimeFrame,
        pvp   = _G.MiniMapBattlefieldFrame,
        lfg   = Find(_G.MiniMapLFGFrame, _G.LFGMinimapFrame, _G.QueueStatusMinimapButton),
    }
end

-- 동그란 어두운 판 + 분홍 테 위에 게임 아이콘 그대로 (누르면 원래 기능)
local function Orb(btn, size, flat)
    if not btn or btn.leelOrb then return btn end
    btn.leelOrb = true
    -- 해/달 표시는 그림 자체가 "Background"라서 숨기지 않고 크기만 줄임
    local keepArt = btn == FindSunCached
    for _, r in ipairs(keepArt and {} or { btn:GetRegions() }) do
        if r:IsObjectType("Texture") then
            local nm = (r:GetDebugName() or "") .. tostring(r:GetTexture() or "")
            if nm:find("Border") or nm:find("Background") or nm:find("border") or nm:find("background") then
                r:SetAlpha(0)
            end
        end
    end
    if not keepArt then
        for _, k in ipairs({ "Border", "Background" }) do if btn[k] and btn[k].SetAlpha then btn[k]:SetAlpha(0) end end
    end
    -- 동그라미 판은 버튼 "뒤" 따로 만든 판에 (버튼 그림이 BACKGROUND 층이어도 안 가려지게)
    local plate = CreateFrame("Frame", nil, btn:GetParent() or Minimap)
    plate:SetSize(size + 4, size + 4)
    plate:SetPoint("CENTER", btn, "CENTER", 0, 0)
    plate:SetFrameStrata("MEDIUM")
    plate:SetFrameLevel(Minimap:GetFrameLevel() + 7)
    local edge = plate:CreateTexture(nil, "BACKGROUND", nil, 0)
    edge:SetTexture(ns.MEDIA .. "mm_round"); edge:SetAllPoints()
    edge:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    local bg = plate:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetTexture(ns.MEDIA .. "mm_round")
    bg:SetSize(size, size); bg:SetPoint("CENTER")
    bg:SetVertexColor(0.16, 0.12, 0.11, 1)
    -- 알약 줄(B안)에서는 단추마다 동그라미 판 없이 아이콘만
    if flat then edge:Hide(); bg:Hide() end
    -- 버튼이 숨으면 판도 같이
    plate:SetShown(btn:IsShown())
    btn:HookScript("OnShow", function() plate:Show() end)
    btn:HookScript("OnHide", function() plate:Hide() end)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    -- 해/달 달력처럼 큰 버튼은 동그라미 크기에 맞게 줄임
    -- 실제로 보이는 크기 기준 (부모 비율이 달라도 같은 크기로)
    local w = btn:GetWidth() or 0
    local ratio = 1
    pcall(function() ratio = (btn:GetParent():GetEffectiveScale()) / Minimap:GetEffectiveScale() end)
    if w * ratio > size + 6 then btn:SetScale((size + 4) / (w * ratio)) end
    return btn
end

-- 줄인 버튼은 좌표도 줄인 비율만큼 나눠야 제자리 (버튼 크기 비율이 위치에도 곱해짐)
-- 게임이 나중에 버튼 위치나 크기를 다시 바꿔도(편집 모드 배치, 달력 알림 등) 르엘 자리로 되돌림
-- 좌표 단위: SetPoint 숫자는 '버튼 자신의 크기 비율'로 읽힘.
-- 편집 모드에서 미니맵 크기를 바꾼 컴퓨터는 버튼 부모 비율이 달라서, 기준 틀과 버튼의 실제 비율로 맞춤
local pendingApply = {}
local function Apply(btn)
    local a = btn.leelAnchor
    if not a then return end
    if InCombatLockdown() and btn:IsProtected() then pendingApply[btn] = true return end
    btn.leelBusy = true
    local k = 1
    pcall(function()
        local r, me = a[2]:GetEffectiveScale(), btn:GetEffectiveScale()
        if r and me and me > 0 then k = r / me end
    end)
    btn:ClearAllPoints()
    btn:SetPoint(a[1], a[2], a[3], (a[4] or 0) * k, (a[5] or 0) * k)
    btn.leelBusy = false
end
local applyEv = CreateFrame("Frame")
applyEv:RegisterEvent("PLAYER_REGEN_ENABLED")
applyEv:SetScript("OnEvent", function()
    for btn in pairs(pendingApply) do pendingApply[btn] = nil; Apply(btn) end
end)

local function Put(btn, p, rel, rp, x, y)
    if not btn then return end
    btn.leelAnchor = { p, rel, rp, x, y }
    if not btn.leelPutHooked then
        btn.leelPutHooked = true
        local function again(self)
            if self.leelBusy or not self.leelAnchor then return end
            C_Timer.After(0, function() Apply(self) end)
        end
        pcall(hooksecurefunc, btn, "SetPoint", again)
        pcall(hooksecurefunc, btn, "SetScale", again)
    end
    Apply(btn)
end

-- 지도 테 둘레 각도에 붙이기 (0 = 오른쪽, 90 = 위)
local function OnRing(btn, deg, r)
    if not btn then return end
    local a = math.rad(deg)
    Put(btn, "CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

----------------------------------------------------------------------
-- 지역 이름, 좌표, 시계
----------------------------------------------------------------------
local zonePill, coordPill, clockPill, cardHead
local function Coords()
    local ok, x, y = pcall(function()
        local id = C_Map.GetBestMapForUnit("player")
        if not id then return end
        local p = C_Map.GetPlayerMapPosition(id, "player")
        if not p then return end
        local px, py = p:GetXY()
        return px * 100, py * 100
    end)
    if ok and x and y and (x > 0 or y > 0) then return string.format("%.1f, %.1f", x, y) end
    return "-"
end

local function Clock()
    local h, m = GetGameTime()
    if GetCVarBool and GetCVarBool("timeMgrUseLocalTime") then
        return date("%H:%M")
    end
    return string.format("%d:%02d", h, m)
end

local function ClockButton(parent, flat)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(22)
    if not flat then ns.RoundPlate(b, 11, { 0.125, 0.094, 0.086, 0.95 }, { 0.949, 0.702, 0.761, 0.55 }) end
    b.fs = ns.Num(b, 14, C.accHi)
    b.fs:SetPoint("CENTER", 0, 0)
    function b:Set(t) self.fs:SetText(t); self:SetWidth(math.max(40, self.fs:GetStringWidth() + 22)) end
    b:SetScript("OnClick", function()
        if TimeManager_Toggle then TimeManager_Toggle()
        elseif ToggleTimeManager then ToggleTimeManager()
        elseif TimeManagerFrame then TimeManagerFrame:SetShown(not TimeManagerFrame:IsShown()) end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("시계")
        GameTooltip:AddLine("누르면 시계/알람 창", 0.84, 0.63, 0.61)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function ZoneText()
    local t = GetMinimapZoneText and GetMinimapZoneText() or ""
    return t
end

local function BunnyButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local t = b:CreateTexture(nil, "ARTWORK"); t:SetTexture(ns.MEDIA .. "icon"); t:SetAllPoints()
    b:RegisterForClicks("AnyUp")
    b:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" then ns:ToggleMoveMode() else ns:ToggleHub() end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine("|cfff2b3c2르엘|r UI")
        GameTooltip:AddLine("좌클릭: 르엘 허브   우클릭: 이동 모드", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

----------------------------------------------------------------------
-- 모양별 꾸미기
----------------------------------------------------------------------
local skin, foot
local function Common(mask)
    -- 게임 테두리, 확대 버튼, 지역 글씨, 시계, 북쪽 표시 숨김
    local mc = MinimapCluster or {}
    -- 이름이 없는 것(nil)이 섞여 있어도 끝까지 보도록 개수로 돎 (ipairs는 nil에서 멈춤)
    local list = { _G.MinimapBorder, _G.MinimapBorderTop, _G.MinimapZoomIn, _G.MinimapZoomOut,
                         _G.MiniMapWorldMapButton, _G.MinimapToggleButton, _G.MinimapZoneTextButton,
                         _G.MinimapNorthTag, _G.MinimapCompassTexture, _G.TimeManagerClockButton,
                         mc.BorderTop, mc.ZoneTextButton, Minimap.ZoomIn, Minimap.ZoomOut,
                         _G.MinimapBackdrop and _G.MinimapBackdrop.MinimapBorder,
                         _G.MinimapCompassTexture, mc.MinimapContainer and mc.MinimapContainer.BorderTop }
    for i = 1, 20 do Bury(list[i]) end
    -- 미니맵 뒤판(MinimapBackdrop)의 그림들(갈색 테, 홈 파인 테)도 숨김
    local bd = _G.MinimapBackdrop
    if bd then
        for _, r in ipairs({ bd:GetRegions() }) do
            if r:IsObjectType("Texture") then r:SetAlpha(0) end
        end
    end
    pcall(Minimap.SetMaskTexture, Minimap, ns.MEDIA .. mask)
    -- 휠로 확대/축소
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function(self, d)
        local z = self:GetZoom() + (d > 0 and 1 or -1)
        if z >= 0 and z <= (self:GetZoomLevels() - 1) then self:SetZoom(z) end
    end)
    skin = CreateFrame("Frame", "LeelUI_MinimapSkin", Minimap)
    skin:SetAllPoints(Minimap)
    skin:SetFrameLevel(Minimap:GetFrameLevel() + 4)
end

local function BackFrame()
    local back = CreateFrame("Frame", nil, Minimap:GetParent() or UIParent)
    back:SetAllPoints(Minimap)
    back:SetFrameStrata(Minimap:GetFrameStrata())
    back:SetFrameLevel(math.max(0, Minimap:GetFrameLevel() - 1))
    return back
end

local function Foot(anchorTo, gap)
    foot = CreateFrame("Frame", nil, skin)
    foot:SetSize(10, 22)
    foot:SetPoint("TOP", anchorTo, "BOTTOM", 0, gap)
    coordPill = Pill(foot, true)
    clockPill = ClockButton(foot)
    coordPill:SetPoint("RIGHT", foot, "CENTER", -3, 0)
    clockPill:SetPoint("LEFT", foot, "CENTER", 3, 0)
    ns.MinimapFoot = foot
end

local B
local RingDragLater
local styles = {}

-- A. 분홍 테 동그라미: 어두운 3 / 분홍 4 / 어두운 2 겹 테, 위 지역 알약, 아래 좌표+시계, 버튼은 테 둘레
styles.ring = function()
    Common("mm_round")
    local S = Minimap:GetWidth()
    local back = BackFrame()
    Disc(back, S + 20, { 0.11, 0.08, 0.07 }, 1, "BACKGROUND", 0)
    Disc(back, S + 14, C.acc, 1, "BACKGROUND", 1)
    Disc(back, S + 5, { 0.11, 0.08, 0.07 }, 1, "BACKGROUND", 2)
    zonePill = Pill(skin)
    zonePill:SetPoint("BOTTOM", Minimap, "TOP", 0, 6)
    Foot(Minimap, -14)
    local r = S / 2 + 6
    OnRing(Orb(B.cal, 24), 40, r)
    OnRing(Orb(B.sun, 24), 68, r)
    Orb(B.comp, 24); RingDragLater = { B.comp, 112, r, "ring" }
    OnRing(Orb(B.mail, 24), 140, r)
    OnRing(Orb(B.track, 24), 180, r)
    OnRing(Orb(B.pvp, 24), 220, r)
    OnRing(Orb(B.lfg, 24), 320, r)
end

-- C. 토끼 귀: 흰 테 + 귀 두 개 + 볼터치, 지역 알약은 지도 아래쪽에 겹쳐서
styles.bunny = function()
    Common("mm_round")
    local S = Minimap:GetWidth()
    local back = BackFrame()
    local ears = CreateFrame("Frame", nil, back)
    ears:SetAllPoints(Minimap)
    ears:SetFrameLevel(math.max(0, back:GetFrameLevel() - 1))
    for i, side in ipairs({ -1, 1 }) do
        local e = ears:CreateTexture(nil, "BACKGROUND")
        e:SetTexture(ns.MEDIA .. "mm_ear")
        e:SetSize(S * 0.2, S * 0.4)
        e:SetPoint("BOTTOM", Minimap, "TOP", side * S * 0.24, -S * 0.12)
        e:SetRotation(math.rad(-14 * side))
    end
    Disc(back, S + 16, { 0.11, 0.08, 0.07 }, 1, "BACKGROUND", 0)
    Disc(back, S + 12, { 1, 1, 1 }, 1, "BACKGROUND", 1)
    Disc(back, S + 3, { 0.11, 0.08, 0.07 }, 1, "BACKGROUND", 2)
    for _, side in ipairs({ -1, 1 }) do
        local c = skin:CreateTexture(nil, "OVERLAY")
        c:SetTexture(ns.MEDIA .. "mm_round")
        c:SetSize(18, 11)
        c:SetPoint("CENTER", Minimap, "CENTER", side * (S / 2 + 2), -S * 0.08)
        c:SetVertexColor(1, 0.62, 0.71, 0.95)
    end
    zonePill = Pill(skin)
    zonePill:SetPoint("CENTER", Minimap, "BOTTOM", 0, 2)
    Foot(zonePill, -6)
    local r = S / 2 + 8
    OnRing(Orb(B.cal, 24), 32, r)
    OnRing(Orb(B.sun, 24), 4, r)
    Orb(B.comp, 24); RingDragLater = { B.comp, 336, r, "bunny" }
    OnRing(Orb(B.mail, 24), 150, r)
    OnRing(Orb(B.track, 24), 190, r)
    OnRing(Orb(B.pvp, 24), 220, r)
    OnRing(Orb(B.lfg, 24), 306, r)
end

-- B. 둥근 네모 카드: 머리(지역+좌표) / 네모 지도 / 아래(시계, 토끼 허브), 버튼은 지도 오른쪽 위 안쪽에 한 줄
styles.card = function()
    Common("mm_squircle")
    GetMinimapShape = function() return "SQUARE" end   -- 다른 애드온 미니맵 버튼이 네모 둘레에 붙게
    local S = Minimap:GetWidth()
    local back = BackFrame()
    local card = CreateFrame("Frame", nil, back)
    card:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -8, 30)
    card:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 8, -34)
    card:SetFrameLevel(back:GetFrameLevel())
    ns.RoundPlate(card, 16, { 0.125, 0.094, 0.086, 0.96 }, { 0.949, 0.702, 0.761, 0.6 })
    cardHead = Font(skin, 13)
    cardHead:SetPoint("BOTTOMLEFT", Minimap, "TOPLEFT", 2, 8)
    coordPill = { fs = ns.Num(skin, 13, C.tx2), Set = function(self, t) self.fs:SetText(t) end }
    coordPill.fs:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", -2, 8)
    clockPill = ClockButton(skin)
    clockPill:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 0, -6)
    local bun = BunnyButton(skin, 24)
    bun:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -5)
    ns.MinimapFoot = card
    -- 버튼: 지도 오른쪽 위 안쪽에서 왼쪽으로
    local x = -18
    for _, k in ipairs({ "cal", "sun", "comp", "track", "mail", "lfg", "pvp" }) do
        local btn = B[k]
        if btn then
            Orb(btn, 22)
            Put(btn, "CENTER", Minimap, "TOPRIGHT", x, -18)
            x = x - 32
        end
    end
end

-- D. 동그라미 + 아래 버튼 줄: 분홍 테 하나, 아래 알약 줄에 버튼/시계/토끼, 그 아래 지역+좌표
styles.bar = function()
    Common("mm_round")
    local S = Minimap:GetWidth()
    local back = BackFrame()
    Disc(back, S + 10, { 0.11, 0.08, 0.07 }, 1, "BACKGROUND", 0)
    Disc(back, S + 7, C.acc, 1, "BACKGROUND", 1)
    Disc(back, S + 1, { 0.11, 0.08, 0.07 }, 1, "BACKGROUND", 2)
    local bar = CreateFrame("Frame", nil, skin)
    bar:SetHeight(32)
    bar:SetPoint("TOP", Minimap, "BOTTOM", 0, -10)
    ns.RoundPlate(bar, 16, { 0.125, 0.094, 0.086, 0.95 }, { 0.949, 0.702, 0.761, 0.55 })
    -- B안: 아이콘 + 시계를 알약 하나에 (칸막이 선으로만 나눔), 토끼는 알약 오른쪽에 따로
    ns.mmLine = true
    clockPill = ClockButton(bar, true)
    local bun = BunnyButton(skin, 28)
    local sep = bar:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.3); sep:SetSize(1, 16)
    local list = {}
    for _, k in ipairs({ "mail", "track", "cal", "sun", "comp", "lfg", "pvp" }) do
        if B[k] then Orb(B[k], 22, true); list[#list + 1] = B[k] end
    end
    local function Lay()
        local x = 6   -- 버튼 크기가 제각각이라 "가운데"를 기준으로 28px 간격
        for _, btn in ipairs(list) do
            if btn:IsShown() then
                Put(btn, "CENTER", bar, "LEFT", x + 12, 0)
                x = x + 28
            end
        end
        sep:ClearAllPoints(); sep:SetPoint("CENTER", bar, "LEFT", x + 4, 0)
        x = x + 8
        clockPill:ClearAllPoints(); clockPill:SetPoint("LEFT", bar, "LEFT", x, 0)
        x = x + clockPill:GetWidth() + 2
        bar:SetWidth(x)
        bun:ClearAllPoints(); bun:SetPoint("LEFT", bar, "RIGHT", 6, 0)
    end
    for _, btn in ipairs(list) do
        btn:HookScript("OnShow", function() C_Timer.After(0, Lay) end)
        btn:HookScript("OnHide", function() C_Timer.After(0, Lay) end)
    end
    bar.Lay = Lay
    -- 지역 이름 + 좌표: 지도 바로 위 알약 (분홍 테 바깥으로 살짝 띄워서)
    zonePill = Pill(skin)
    zonePill:SetPoint("BOTTOM", Minimap, "TOP", 0, 11)
    coordPill = { fs = ns.Num(zonePill, 13, C.tx2), Set = function(self, t) self.fs:SetText(t) end }
    ns.MinimapFoot = bar   -- 미니맵 묶음의 맨 아래 = 버튼 줄 (퀘스트 목록이 여기 밑에 붙어요)
    styles.barFrame = bar
end

----------------------------------------------------------------------
local function Update()
    local z = ZoneText()
    if zonePill then
        if styles.barFrame then
            -- D: 지역 이름 + 좌표 한 알약
            zonePill.fs:SetText(z .. "   |cffd6a09c" .. Coords() .. "|r")
            zonePill:SetWidth(math.max(60, zonePill.fs:GetStringWidth() + 24))
        else
            zonePill:Set(z)
        end
    end
    if cardHead then cardHead:SetText(z) end
    if B and B.sun and UpdateSun then UpdateSun(B.sun) end
    if B and B.cal and B.cal.leelDay then B.cal.leelDay:SetText((date("%d"):gsub("^0", ""))) end
    if coordPill and not styles.barFrame then coordPill:Set(Coords()) end
    if clockPill then
        clockPill:Set(Clock())
        if styles.barFrame then styles.barFrame.Lay() end
    end
    if foot and coordPill and clockPill and foot.SetWidth then
        foot:SetWidth((coordPill.GetWidth and coordPill:GetWidth() or 0) + clockPill:GetWidth() + 6)
    end
end

-- 게임이 지도 아래 따로 띄우는 좌표 글씨("60.1, 66.7") 찾아서 숨김 (르엘 좌표와 겹침)
local function HideNativeCoords(f, depth)
    if not f or depth > 4 or f == skin then return end
    for _, r in ipairs({ f:GetRegions() }) do
        if r:IsObjectType("FontString") then
            local ok, t = pcall(r.GetText, r)
            if ok and type(t) == "string" and t:match("^%s*%d+%.?%d*%s*,%s*%d+%.?%d*%s*$") then
                r:SetAlpha(0)
            end
        end
    end
    for _, c in ipairs({ f:GetChildren() }) do
        if c ~= skin and not (c.GetName and (c:GetName() or ""):find("^LeelUI")) then HideNativeCoords(c, depth + 1) end
    end
end

-- 게임 버튼 그림을 모두 가리고 르엘 토끼 그림으로 (누르는 기능은 그대로)
local function HideArt(f, depth)
    if not f or depth > 2 then return end
    for _, r in ipairs({ f:GetRegions() }) do
        if r:IsObjectType("Texture") or r:IsObjectType("FontString") then
            r:SetAlpha(0)
            if not r.leelMute then
                r.leelMute = true
                hooksecurefunc(r, "SetAlpha", function(self, a) if a and a > 0 and self.leelMuted then self:SetAlpha(0) end end)
            end
            r.leelMuted = true
        end
    end
    for _, k in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
        local t = f[k] and f[k](f); if t then t:SetAlpha(0); t.leelMuted = true end
    end
    for _, c in ipairs({ f:GetChildren() }) do HideArt(c, depth + 1) end
end

local function LeelIcon(btn, file, size)
    if not btn or btn.leelIcon then return btn and btn.leelIcon end
    HideArt(btn, 0)
    local holder = CreateFrame("Frame", nil, btn)
    holder:SetAllPoints()
    holder:SetFrameLevel(btn:GetFrameLevel() + 5)
    local t = holder:CreateTexture(nil, "OVERLAY")
    -- B안(알약 줄): 알록달록 토끼 아이콘 대신 분홍 선 아이콘
    if ns.mmLine and file:find("^mmi_") then
        file = file:gsub("^mmi_", "li_")
        t:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
        size = 17
        btn:HookScript("OnEnter", function() t:SetVertexColor(C.accHi[1], C.accHi[2], C.accHi[3], 1) end)
        btn:HookScript("OnLeave", function() t:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1) end)
    end
    t:SetTexture(ns.MEDIA .. file)
    local sc = btn:GetScale() or 1
    t:SetSize((size or 22) / sc, (size or 22) / sc)
    t:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.leelIcon = t
    btn.leelIconHolder = holder
    return t
end

-- 달력: 토끼 귀 달력 + 오늘 날짜 숫자
local function CalendarIcon(btn)
    local t = LeelIcon(btn, "mmi_cal", 22)
    if not t or btn.leelDay then return end
    local sc = btn:GetScale() or 1
    btn.leelDay = ns.Num(btn.leelIconHolder, (ns.mmLine and 8 or 10) / sc, ns.mmLine and C.acc or C.ink, true)
    btn.leelDay:SetShadowColor(0, 0, 0, 0)
    btn.leelDay:SetPoint("CENTER", t, "CENTER", 0, (ns.mmLine and -2 or -3) / sc)
    btn.leelDay:SetText((date("%d"):gsub("^0", "")))
end

-- 낮/밤: 게임 시간 6~18시는 웃는 해, 나머지는 달 위에서 자는 토끼
UpdateSun = function(btn)
    if not (btn and btn.leelIcon) then return end
    local h = GetGameTime()
    local pre = ns.mmLine and "li_" or "mmi_"
    btn.leelIcon:SetTexture(ns.MEDIA .. pre .. ((h >= 6 and h < 18) and "day" or "night"))
end

local function TidyCompartment(btn)
    if not btn or btn.leelTidy then return end
    btn.leelTidy = true
    LeelIcon(btn, "mmi_comp", 21)
end

local function BunnyIcons()
    if B.track then LeelIcon(B.track, "mmi_track", 21) end
    if B.mail then LeelIcon(B.mail, "mmi_mail", 21) end
    if B.cal then CalendarIcon(B.cal) end
    if B.sun then LeelIcon(B.sun, "mmi_day", 23); UpdateSun(B.sun) end
end

----------------------------------------------------------------------
-- 다른 애드온 미니맵 아이콘을 애드온 목록 버튼(네 칸 그림) 하나로 모으기
----------------------------------------------------------------------
local collected = {}
local function Keep(btn)
    if btn.leelKept then return end
    btn.leelKept = true
    btn:Hide()
    hooksecurefunc(btn, "Show", function(self) if ns.db and ns.db.mmCollect ~= false then self:Hide() end end)
end

-- 목록에 이미 같은 애드온이 있는지 (애드온이 스스로 넣은 것과 겹치지 않게)
--   "Leatrix Maps" = "Leatrix_Maps" 처럼 띄어쓰기 · 밑줄 · 색 코드는 무시하고 비교
local function NormName(t)
    t = tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return (t:lower():gsub("[%s_%-%.]", ""))
end
-- 애드온이 .toc 파일로 직접 목록에 들어오는 경우 (registeredAddons에 늦게 들어오거나 안 보일 때가 있어요)
local tocNames
local function TocCompartment()
    if tocNames then return tocNames end
    tocNames = {}
    local A = C_AddOns
    local n = (A and A.GetNumAddOns and A.GetNumAddOns()) or (GetNumAddOns and GetNumAddOns()) or 0
    for i = 1, n do
        local meta = (A and A.GetAddOnMetadata) or GetAddOnMetadata
        local ok, f = pcall(meta, i, "AddonCompartmentFunc")
        if ok and f and f ~= "" then
            local okI, name, title = pcall((A and A.GetAddOnInfo) or GetAddOnInfo, i)
            if okI then
                if name then tocNames[NormName(name)] = true end
                if title then tocNames[NormName(title)] = true end
            end
        end
    end
    return tocNames
end
local function Same(a, b)
    return a ~= "" and b ~= "" and (a == b or (#a >= 5 and #b >= 5 and (a:find(b, 1, true) or b:find(a, 1, true))))
end
local function InCompartment(comp, label)
    local want = NormName(label)
    if want == "" then return false end
    for k in pairs(TocCompartment()) do if Same(k, want) then return true end end
    local list = comp.registeredAddons
    if type(list) ~= "table" then return false end
    for _, d in ipairs(list) do
        local have = type(d) == "table" and not d.leelOurs and NormName(d.text) or ""
        if Same(have, want) then return true end
    end
    return false
end

-- 이미 들어간 것 중 겹치는 게 있으면(애드온이 늦게 스스로 넣은 경우) 우리가 넣은 쪽을 빼요
local addedByUs = {}
local function Dedupe(comp)
    local list = comp and comp.registeredAddons
    if type(list) ~= "table" then return end
    local Icon = LibStub and LibStub("LibDBIcon-1.0", true)
    local changed = false
    for i = #list, 1, -1 do
        local d = list[i]
        local mine = type(d) == "table" and (d.leelOurs or addedByUs[NormName(d.text)])
        if mine then
            local me = NormName(d.text)
            local dup = false
            for k in pairs(TocCompartment()) do if Same(k, me) then dup = true end end
            for j, o in ipairs(list) do
                if j ~= i and type(o) == "table" and not o.leelOurs and not addedByUs[NormName(o.text)] and Same(NormName(o.text), me) then dup = true end
            end
            if dup then
                local lname = addedByUs[me]
                if type(lname) == "string" and Icon and Icon.RemoveButtonFromCompartment then
                    pcall(Icon.RemoveButtonFromCompartment, Icon, lname)
                else
                    table.remove(list, i)
                end
                changed = true
            end
        end
    end
    -- 예전에 우리가 LibDBIcon으로 넣어 둔 게 애드온 설정에 남아 매번 다시 들어오는 경우:
    --   그 애드온이 .toc로 스스로 목록에 들어오면 LibDBIcon 쪽 칸은 빼요 (애드온 설정의 "목록에 넣기"도 꺼져요)
    if Icon and Icon.objects and Icon.IsButtonInCompartment and Icon.RemoveButtonFromCompartment then
        local toc = TocCompartment()
        for lname in pairs(Icon.objects) do
            if lname ~= "LeelUI" and Icon:IsButtonInCompartment(lname) then
                local me = NormName(lname)
                for k in pairs(toc) do
                    if Same(k, me) then pcall(Icon.RemoveButtonFromCompartment, Icon, lname); changed = true; break end
                end
            end
        end
    end
    if changed and comp.UpdateDisplay then pcall(comp.UpdateDisplay, comp) end
end

local function Collect()
    if not (ns.db and ns.db.mmCollect ~= false) then return end
    local comp = _G.AddonCompartmentFrame
    if not (comp and comp.RegisterAddon) then return end
    local Icon = LibStub and LibStub("LibDBIcon-1.0", true)
    -- LibDBIcon 버튼: 라이브러리 기능으로 목록에 넣고 숨김
    if Icon and Icon.objects then
        for name, btn in pairs(Icon.objects) do
            if not collected[name] then
                collected[name] = true
                -- 르엘 UI는 이미 목록에 따로 들어 있음 (겹치지 않게 숨기기만)
                if name ~= "LeelUI" and Icon.AddButtonToCompartment and not (Icon.IsButtonInCompartment and Icon:IsButtonInCompartment(name))
                   and not InCompartment(comp, name) then
                    if pcall(Icon.AddButtonToCompartment, Icon, name) then addedByUs[NormName(name)] = name end
                end
                Keep(btn)
            end
        end
    end
    -- 그 밖에 미니맵에 붙은 이름 있는 버튼 (NeedRoll, 르엘 길잡이 등): 목록에 "누르기"로 넣고 숨김
    for _, c in ipairs({ Minimap:GetChildren() }) do
        local name = c.GetName and c:GetName()
        if name and c:IsObjectType("Button") and not collected[name] and not name:find("^LibDBIcon10_")
           and not name:find("^Questie") and not name:find("^LeelUI") and c ~= B.mail and c ~= B.track then
            local w = c:GetWidth() or 0
            if w >= 20 and w <= 40 then
                collected[name] = true
                local icon = c.icon or c.Icon
                local tex = icon and icon.GetTexture and icon:GetTexture()
                local label = name:gsub("MinimapButton$", ""):gsub("Minimap$", ""):gsub("Button$", "")
                if name == "ForgLevelingMinimapButton" then label = "르엘 길잡이" end
                if not InCompartment(comp, label) then pcall(comp.RegisterAddon, comp, { leelOurs = true,
                    text = label, icon = tex or 134400, notCheckable = true, registerForAnyClick = true,
                    func = function(_, data)
                        local f = c:GetScript("OnClick")
                        if f then f(c, (data and data.buttonName) or "LeftButton") end
                    end,
                    funcOnEnter = function(b)
                        local f = c:GetScript("OnEnter"); if f then pcall(f, c) end
                    end,
                    funcOnLeave = function() GameTooltip:Hide() end,
                }) end
                Keep(c)
            end
        end
    end
    Dedupe(comp)
end

-- 테 둘레에서 끌어서 자리 옮기기 (A, C 모양). 각도는 모양마다 따로 저장
local function RingDrag(btn, defDeg, r, key)
    if not btn then return end
    ns.db.mmAngles = ns.db.mmAngles or {}
    local deg = ns.db.mmAngles[key] or defDeg
    OnRing(btn, deg, r)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local s = Minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            local a = math.deg(math.atan2(cy / s - my, cx / s - mx))
            OnRing(self, a, r)
            self.leelDeg = a
        end)
    end)
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if self.leelDeg then ns.db.mmAngles[key] = math.floor(self.leelDeg + 0.5) end
    end)
end

local function Apply()
    local st = Style()
    if st == "blizz" or not styles[st] or not Minimap then return end
    B = Buttons()
    ns.mmLine = (st == "bar")      -- 알약 줄 모양이면 분홍 선 아이콘
    pcall(TidyCompartment, B.comp)
    local ok, err = pcall(styles[st])
    if not ok then ns.Print("미니맵 꾸미기 오류: " .. tostring(err)) return end
    if RingDragLater then pcall(RingDrag, unpack(RingDragLater)) end
    local okI, errI = pcall(BunnyIcons)
    if not okI then ns.Print("미니맵 아이콘 오류: " .. tostring(errI)) end
    Update()
    local function Hunt()
        HideNativeCoords(MinimapCluster, 0)
        if Minimap:GetParent() ~= MinimapCluster then HideNativeCoords(Minimap:GetParent(), 0) end
    end
    Hunt(); C_Timer.After(3, Hunt); C_Timer.After(10, Hunt)
    -- 애드온들이 버튼을 늦게 만들 수 있어서 몇 번 나눠서 모음
    C_Timer.After(1, Collect); C_Timer.After(5, Collect); C_Timer.After(15, Collect)
    local t = 0
    skin:SetScript("OnUpdate", function(_, el)
        t = t + el
        if t > 0.5 then t = 0; Update() end
    end)
    -- 가방 숫자가 미니맵 아래 새 줄 밑으로 오게
    local chip = _G.LeelUI_BagChip
    if chip and ns.MinimapFoot then
        if ns.BagsDB then ns.BagsDB().chipPos = nil end
        chip:ClearAllPoints()
        chip:SetPoint("TOP", ns.MinimapFoot, "BOTTOM", 0, -6)
    end
    -- 토끼 버튼이 들어간 모양(B, D)은 미니맵 둘레 토끼 아이콘은 숨김
    if st == "card" or st == "bar" then
        local Icon = LibStub and LibStub("LibDBIcon-1.0", true)
        if Icon then pcall(Icon.Hide, Icon, "LeelUI") end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ZONE_CHANGED")
ev:RegisterEvent("ZONE_CHANGED_INDOORS")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(0.5, Apply)   -- 미니맵 버튼들이 다 만들어진 뒤
    elseif skin then
        Update()
    end
end)

function ns:SetMinimapStyle(key)
    if not ns.db then return end
    if Style() == key then return end
    ns.db.mmStyle = key
    StaticPopup_Show("LEELUI_HUB_RELOAD")
end

-- 점검: 미니맵 주변 게임 버튼 이름을 저장 (/르엘미니맵 → 다시 불러오기 후 파일로 남음)
local function Dump()
    local out = {}
    local function Walk(f, depth, path)
        if not f or depth > 3 then return end
        local ok, name = pcall(f.GetName, f)
        name = ok and name or nil
        local w, h = f:GetSize()
        local p1, rel, p2, x, y = f:GetPoint(1)
        local relName = rel and rel.GetName and rel:GetName() or tostring(rel)
        out[#out + 1] = string.format("%s%s [%s] shown=%s size=%.0fx%.0f at %s %s %s %.0f %.0f lvl=%d",
            string.rep("  ", depth), name or path, f:GetObjectType(), tostring(f:IsShown()), w or 0, h or 0,
            tostring(p1), tostring(relName), tostring(p2), x or 0, y or 0, f:GetFrameLevel())
        for _, r in ipairs({ f:GetRegions() }) do
            local rn = r.GetDebugName and r:GetDebugName() or "?"
            local tex = r.GetTexture and tostring(r:GetTexture() or "") or ""
            out[#out + 1] = string.format("%s  - %s (%s) %s shown=%s", string.rep("  ", depth), rn, r:GetObjectType(), tex, tostring(r:IsShown()))
        end
        for i, c in ipairs({ f:GetChildren() }) do Walk(c, depth + 1, (name or path) .. "." .. i) end
    end
    Walk(MinimapCluster, 0, "MinimapCluster")
    if Minimap:GetParent() ~= MinimapCluster then Walk(Minimap:GetParent(), 0, "MinimapParent") end
    ns.db.mmDump = out
    ns.Print("미니맵 점검 저장: " .. #out .. "줄. /reload 하면 파일에 남아요.")
end
SLASH_LEELMMDUMP1 = "/르엘미니맵"
SLASH_LEELMMDUMP2 = "/leelmm"
SlashCmdList.LEELMMDUMP = Dump

----------------------------------------------------------------------
-- 이동 모드(르엘 아이콘 우클릭)로 미니맵 옮기기
-- 미니맵 묶음(MinimapCluster)을 저장한 자리로. 게임이 자리를 되돌리면 다시 맞춤
----------------------------------------------------------------------
local placing = false
local function PlaceCluster()
    local mc = MinimapCluster
    local p = ns.db and ns.db.mmPos
    if not (mc and p) or placing then return end
    placing = true
    mc:ClearAllPoints()
    mc:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p[1], p[2])
    placing = false
end

function ns:ResetMinimapPosition()
    if not (ns.db and MinimapCluster) then return end
    ns.db.mmPos = nil
    placing = true
    MinimapCluster:ClearAllPoints()
    MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    placing = false
end

local function BuildMover()
    local mc = MinimapCluster
    if not mc or mc.leelMover then return end
    local m = CreateFrame("Frame", nil, UIParent)
    mc.leelMover = m
    m:SetFrameStrata("DIALOG")
    m:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -26, 30)
    m:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 26, -64)
    m:EnableMouse(true)
    m:RegisterForDrag("LeftButton")
    local tint = m:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints(); tint:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.10)
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
    lab:SetPoint("BOTTOM", m, "TOP", 0, 4); lab:SetText("미니맵")
    -- 끌기: 커서와 미니맵 묶음 가운데의 차이를 유지하며 따라감 (게임 창을 직접 StartMoving 하지 않음)
    m:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        local s = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        local x, y = mc:GetCenter()
        local ms = mc:GetEffectiveScale() / s
        local dx, dy = cx / s - x * ms, cy / s - y * ms
        m:SetScript("OnUpdate", function()
            local nx, ny = GetCursorPosition()
            nx, ny = nx / s - dx, ny / s - dy
            if ns.db.grid then nx = math.floor(nx / 8 + 0.5) * 8; ny = math.floor(ny / 8 + 0.5) * 8 end
            ns.db.mmPos = { math.floor(nx / ms + 0.5), math.floor(ny / ms + 0.5) }
            PlaceCluster()
        end)
    end)
    m:SetScript("OnDragStop", function() m:SetScript("OnUpdate", nil) end)
    m:Hide()
    if ns.SetMoveMode then
        hooksecurefunc(ns, "SetMoveMode", function() m:SetShown(ns.moving and true or false) end)
    end
    -- 게임(편집 모드 등)이 자리를 다시 잡으면 저장한 자리로
    hooksecurefunc(mc, "SetPoint", function() if not placing and ns.db and ns.db.mmPos then C_Timer.After(0, PlaceCluster) end end)
end

local mev = CreateFrame("Frame")
mev:RegisterEvent("PLAYER_LOGIN")
mev:RegisterEvent("PLAYER_ENTERING_WORLD")
mev:SetScript("OnEvent", function(_, event)
    if not ns.db then return end
    if event == "PLAYER_LOGIN" then C_Timer.After(0.6, function() BuildMover(); PlaceCluster() end)
    else C_Timer.After(1, PlaceCluster) end
end)
