-- LeelUI / FlightBar.lua
-- 비행 띠 (1안): 와이번 · 그리폰 · 박쥐를 타면 화면 위 가운데에 띠 하나
--   [동물] 목적지 (지역) · 출발지 · 경유 N곳          남은 시간 1:42
--          23:24 도착 · 남은 거리 2.4km
--   ●────●━━━(나)───●────●   (지나온 곳은 분홍 점 · 경유지 이름)
--   [다음 지점에서 내리기]
-- 시간: 그 구간을 예전에 날아본 시간 (구간마다 저장 · 다음부터 초 단위) · 처음 가는 구간은 거리 ÷ 비행 속도로 "약"
-- 거리: 비행 조련사 지도의 지점 위치 → 지도 크기(야드)로 계산 · 지금 위치는 같은 지도 위 내 좌표

local _, ns = ...
local C = ns.C
local L = function(s) return ns.L and ns.L(s) or s end

local W, H = 520, 82
local ICON = {
    wyvern = "Interface\\Icons\\Ability_Mount_Wyvern_01",
    gryphon = "Interface\\Icons\\Ability_Mount_Gryphon_01",
    bat = "Interface\\Icons\\Ability_Hunter_Pet_Bat",
}
local BAT = { [1420] = true, [1458] = true, [1421] = true, [1424] = true, [1422] = true, [1423] = true }

local function DB() return ns.db or {} end
local function On() return DB().flyBar ~= false end
local function Times() local d = ns.db; if not d then return {} end; d.flyTimes = d.flyTimes or {}; return d.flyTimes end
local function Speed() return (ns.db and ns.db.flySpeed) or 27 end   -- 야드/초 (지점 사이 직선 기준)
local function Secret(v) return ns.IsSecret and ns.IsSecret(v) end

local function Short(name)
    if type(name) ~= "string" then return "?" end
    return name:match("^(.-)%s*%(") or name:match("^[^,]+") or name
end
local function Zone(name)
    return type(name) == "string" and name:match("%((.-)%)") or nil
end
local function Clock(s)
    s = math.max(0, math.floor(s + 0.5))
    return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

----------------------------------------------------------------------
-- 경로 읽기 (비행 조련사 지도가 열려 있을 때 · 목적지를 누른 순간)
----------------------------------------------------------------------
local route        -- { stops = { {name, x, y} ... }, len = { [k] = 야드 }, total, map, kind }
local fly          -- { started, leg, legStart, early }

local function NodePositions(mapID)
    local pos = {}
    if C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and mapID then
        local ok, list = pcall(C_TaxiMap.GetAllTaxiNodes, mapID)
        if ok and type(list) == "table" then
            for _, n in ipairs(list) do
                if n.slotIndex and n.position then
                    local x, y = n.position:GetXY()
                    pos[n.slotIndex] = { x, y }
                end
            end
        end
    end
    return pos
end

local function ReadRoute(dest)
    local mapID = GetTaxiMapID and GetTaxiMapID()
    if not mapID or not (C_Map and C_Map.GetMapWorldSize) then return end
    local mw, mh = C_Map.GetMapWorldSize(mapID)
    if not mw or mw <= 0 then return end
    local pos = NodePositions(mapID)
    local function P(slot)
        local p = pos[slot]
        if not p and TaxiNodePosition then
            local ok, x, y = pcall(TaxiNodePosition, slot)
            if ok and x then p = { x, y } end
        end
        return p
    end
    local hops = (GetNumRoutes and GetNumRoutes(dest)) or 0
    if hops < 1 then return end
    local stops = {}
    for hop = 1, hops do
        if hop == 1 then
            local s = TaxiGetNodeSlot(dest, hop, true)
            local p = P(s); if not p then return end
            stops[1] = { TaxiNodeName(s), p[1], p[2] }
        end
        local d = TaxiGetNodeSlot(dest, hop, false)
        local p = P(d); if not p then return end
        stops[#stops + 1] = { TaxiNodeName(d), p[1], p[2] }
    end
    local r = { stops = stops, len = {}, total = 0, map = mapID, mw = mw, mh = mh }
    for k = 1, #stops - 1 do
        local a, b = stops[k], stops[k + 1]
        local l = math.sqrt(((b[2] - a[2]) * mw) ^ 2 + ((b[3] - a[3]) * mh) ^ 2)
        r.len[k] = l; r.total = r.total + l
    end
    local startMap = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if UnitFactionGroup("player") ~= "Horde" then r.kind = "gryphon"
    else r.kind = (startMap and BAT[startMap]) and "bat" or "wyvern" end
    return r
end

-- 지금 위치를 경로 위에 놓기: 지금 구간(k)부터 다음 구간까지만 봐요 (뒤로 가지 않게)
local function Project(px, py)
    local best, bk, bt
    local s = route.stops
    local from = fly.leg
    for k = from, math.min(from + 1, #s - 1) do
        local a, b = s[k], s[k + 1]
        local ax, ay = a[2] * route.mw, a[3] * route.mh
        local bx, by = b[2] * route.mw, b[3] * route.mh
        local x, y = px * route.mw, py * route.mh
        local dx, dy = bx - ax, by - ay
        local l2 = dx * dx + dy * dy
        local t = l2 > 0 and (((x - ax) * dx + (y - ay) * dy) / l2) or 0
        t = math.max(0, math.min(1, t))
        local qx, qy = ax + dx * t, ay + dy * t
        local d = (x - qx) ^ 2 + (y - qy) ^ 2
        -- 다음 구간은 꽤 들어갔을 때만 (모퉁이에서 왔다 갔다 하지 않게)
        if k > from and t < 0.04 then d = math.huge end
        if not best or d < best then best, bk, bt = d, k, t end
    end
    return bk, bt
end

local function LegKey(k) local s = route.stops; return Short(s[k][1]) .. "|" .. Short(s[k + 1][1]) end

local function SaveLeg(k, secs)
    if not route or not route.stops[k + 1] or not secs or secs < 5 or (fly and fly.test) then return end
    Times()[LegKey(k)] = math.floor(secs + 0.5)
    local l = route.len[k]
    if l and l > 50 and ns.db then
        local v = l / secs
        if v > 8 and v < 80 then ns.db.flySpeed = math.floor(((ns.db.flySpeed or 27) * 0.7 + v * 0.3) * 10 + 0.5) / 10 end
    end
end

----------------------------------------------------------------------
-- 띠
----------------------------------------------------------------------
local bar
local function Slice(t, m) pcall(t.SetTextureSliceMargins, t, m, m, m, m) end

local function Build()
    local f = CreateFrame("Frame", "LeelUI_FlightBar", UIParent)
    f:SetSize(W, H); f:SetPoint("TOP", UIParent, "TOP", 0, -26)
    f:SetFrameStrata("MEDIUM"); f:SetFrameLevel(40)
    local sh = f:CreateTexture(nil, "BACKGROUND", nil, -2); sh:SetTexture(ns.MEDIA .. "fly_panel"); Slice(sh, 16)
    sh:SetPoint("TOPLEFT", -2, -2); sh:SetPoint("BOTTOMRIGHT", 2, -6); sh:SetVertexColor(0, 0, 0, 0.35)
    local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(ns.MEDIA .. "fly_panel"); Slice(bg, 16); bg:SetAllPoints()
    bg:SetVertexColor(0.11, 0.078, 0.086, 0.92)
    local rim = f:CreateTexture(nil, "BORDER"); rim:SetTexture(ns.MEDIA .. "fly_rim"); Slice(rim, 16); rim:SetAllPoints()
    rim:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.55)

    -- 동물 동그라미
    local ic = f:CreateTexture(nil, "ARTWORK"); ic:SetSize(30, 30); ic:SetPoint("TOPLEFT", 14, -10)
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mk = f:CreateMaskTexture(); mk:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); mk:SetAllPoints(ic)
    ic:AddMaskTexture(mk)
    local ir = f:CreateTexture(nil, "OVERLAY"); ir:SetTexture(ns.MEDIA .. "ring"); ir:SetPoint("TOPLEFT", ic, -2, 2); ir:SetPoint("BOTTOMRIGHT", ic, 2, -2)
    ir:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    f.icon = ic

    f.to = ns.Font(f, 15, C.tx); f.to:SetPoint("TOPLEFT", ic, "TOPRIGHT", 10, 1)
    f.zone = ns.Font(f, 12, { 0.66, 0.59, 0.57 }); f.zone:SetPoint("LEFT", f.to, "RIGHT", 5, 0)
    f.from = ns.Font(f, 11.5, { 0.66, 0.59, 0.57 }); f.from:SetPoint("TOPLEFT", f.to, "BOTTOMLEFT", 0, -3)
    f.time = ns.Num(f, 26, { 1, 1, 1 }); f.time:SetPoint("TOPRIGHT", -16, -7)
    f.about = ns.Font(f, 11, C.tx2); f.about:SetPoint("RIGHT", f.time, "LEFT", -4, -2); f.about:SetText(L("약"))
    f.eta = ns.Font(f, 11, { 0.66, 0.59, 0.57 }); f.eta:SetPoint("TOPRIGHT", f.time, "BOTTOMRIGHT", 0, -1)

    -- 길 줄
    local tr = CreateFrame("Frame", nil, f); tr:SetPoint("BOTTOMLEFT", 22, 26); tr:SetPoint("BOTTOMRIGHT", -22, 26); tr:SetHeight(8)
    local tb = tr:CreateTexture(nil, "BACKGROUND"); tb:SetTexture(ns.MEDIA .. "fly_pill"); Slice(tb, 4); tb:SetAllPoints()
    tb:SetVertexColor(0.23, 0.165, 0.176, 1)
    local fill = tr:CreateTexture(nil, "BORDER"); fill:SetTexture(ns.MEDIA .. "fly_pill"); Slice(fill, 4)
    fill:SetPoint("TOPLEFT"); fill:SetPoint("BOTTOMLEFT"); fill:SetWidth(1)
    fill:SetVertexColor(1, 0.56, 0.67, 1)
    f.track, f.fill, f.dots, f.lbls = tr, fill, {}, {}
    local me = CreateFrame("Frame", nil, tr); me:SetSize(24, 24); me:SetFrameLevel(tr:GetFrameLevel() + 3)
    local mb = me:CreateTexture(nil, "BACKGROUND"); mb:SetTexture(ns.MEDIA .. "circle"); mb:SetAllPoints(); mb:SetVertexColor(1, 0.56, 0.67, 1)
    local mi = me:CreateTexture(nil, "ARTWORK"); mi:SetPoint("TOPLEFT", 3, -3); mi:SetPoint("BOTTOMRIGHT", -3, 3); mi:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mm = me:CreateMaskTexture(); mm:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); mm:SetAllPoints(mi); mi:AddMaskTexture(mm)
    me.icon = mi
    f.me = me

    -- 다음 지점에서 내리기
    local b = CreateFrame("Button", nil, f); b:SetHeight(20); b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, -9)
    b:SetFrameLevel(f:GetFrameLevel() + 6)
    local bb = b:CreateTexture(nil, "BACKGROUND"); bb:SetTexture(ns.MEDIA .. "fly_pill"); Slice(bb, 10); bb:SetAllPoints()
    b.fs = ns.Font(b, 11.5, C.ink); b.fs:SetShadowColor(0, 0, 0, 0); b.fs:SetPoint("CENTER", 0, 0)
    b.bg = bb
    b:SetScript("OnClick", function()
        if fly and not fly.early and TaxiRequestEarlyLanding then
            pcall(TaxiRequestEarlyLanding); fly.early = true
            if bar and bar.Paint then bar.Paint() end
        end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L("다음 비행 지점에서 내려요"), 1, 1, 1); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.land = b
    f:Hide()
    return f
end

local function Dot(i)
    local d = bar.dots[i]
    if d then return d end
    d = CreateFrame("Frame", nil, bar.track); d:SetSize(14, 14); d:SetFrameLevel(bar.track:GetFrameLevel() + 2)
    d.o = d:CreateTexture(nil, "BACKGROUND"); d.o:SetTexture(ns.MEDIA .. "circle"); d.o:SetAllPoints(); d.o:SetVertexColor(0.11, 0.078, 0.086, 1)
    d.i = d:CreateTexture(nil, "ARTWORK"); d.i:SetTexture(ns.MEDIA .. "circle"); d.i:SetPoint("TOPLEFT", 3, -3); d.i:SetPoint("BOTTOMRIGHT", -3, 3)
    bar.dots[i] = d
    local l = ns.Font(bar.track, 10.5, { 0.78, 0.71, 0.69 }); bar.lbls[i] = l
    return d
end

-- 경로가 바뀔 때 한 번: 점 · 이름 자리
local function Layout()
    local s = route.stops
    local tw = bar.track:GetWidth()
    if not tw or tw < 10 then tw = W - 44 end
    route.frac = {}
    local acc = 0
    for k = 1, #s do
        route.frac[k] = route.total > 0 and acc / route.total or (k - 1) / math.max(1, #s - 1)
        if route.len[k] then acc = acc + route.len[k] end
    end
    local lastX
    Dot(#s); bar.lbls[#s]:SetText(Short(s[#s][1]))
    local endLeft = tw + 6 - bar.lbls[#s]:GetStringWidth()
    for k = 1, math.max(#s, #bar.dots) do
        local d = k <= #s and Dot(k) or bar.dots[k]
        local l = bar.lbls[k]
        if k <= #s then
            local x = route.frac[k] * tw
            d:ClearAllPoints(); d:SetPoint("CENTER", bar.track, "LEFT", x, 0); d:Show()
            l:ClearAllPoints(); l:SetText(Short(s[k][1]))
            if k == 1 then l:SetPoint("TOPLEFT", bar.track, "BOTTOMLEFT", -6, -5)
            elseif k == #s then l:SetPoint("TOPRIGHT", bar.track, "BOTTOMRIGHT", 6, -5)
            else l:SetPoint("TOP", bar.track, "BOTTOMLEFT", x, -5) end
            -- 겹치면 가운데 이름은 빼요 (처음 · 끝은 늘)
            local w = l:GetStringWidth()
            local left = (k == 1) and -6 or (k == #s and tw + 6 - w) or (x - w / 2)
            local show = k == 1 or k == #s or not lastX or left > lastX + 8
            if k > 1 and k < #s and left + w > endLeft - 8 then show = false end
            l:SetShown(show)
            if show then lastX = left + w end
        else
            d:Hide(); if l then l:Hide() end
        end
    end
    local n = #s - 2
    bar.to:SetText(Short(s[#s][1]))
    local z = Zone(s[#s][1]); bar.zone:SetText(z and ("(" .. z .. ")") or "")
    local fromTxt = (L("%s에서")):format(Short(s[1][1]))
    if n > 0 then fromTxt = fromTxt .. " · " .. (L("경유 %d곳")):format(n) end
    bar.from:SetText(fromTxt)
    local tex = ICON[route.kind] or ICON.wyvern
    bar.icon:SetTexture(tex); bar.me.icon:SetTexture(tex)
end

-- 내 위치 (비행 지도 위 0~1): 비행 지도에서 바로 → 안 되면 지금 지역 지도 → 세계 좌표 → 비행 지도
local function PlayerPos()
    local function XY(p)
        if not p or Secret(p) then return end
        local x, y = p:GetXY()
        if x and not Secret(x) and not Secret(y) and x > 0 and x < 1 and y > 0 and y < 1 then return x, y end
    end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, route.map, "player")
    local x, y = XY(ok and pos)
    if x then return x, y end
    local best = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if best and best ~= route.map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos then
        local ok2, p2 = pcall(C_Map.GetPlayerMapPosition, best, "player")
        if ok2 and p2 and not Secret(p2) then
            local ok3, cont, wpos = pcall(C_Map.GetWorldPosFromMapPos, best, p2)
            if ok3 and cont and wpos then
                local ok4, _, mp = pcall(C_Map.GetMapPosFromWorldPos, cont, wpos, route.map)
                if ok4 then return XY(mp) end
            end
        end
    end
end

-- 구간 시간: 날아본 시간 또는 거리 ÷ 속도
local function LegTime(j)
    local m = Times()[LegKey(j)]
    if m then return m, false end
    return (route.len[j] or 0) / Speed(), true
end

-- 위치를 못 읽을 때: 뜬 뒤 지난 시간으로 어디쯤인지
local function ByTime()
    local el = GetTime() - fly.started
    local acc = 0
    local n = #route.stops - 1
    for j = 1, n do
        local T = LegTime(j)
        if el < acc + T or j == n then
            fly.legStart = fly.started + acc
            return j, math.max(0, math.min(1, (el - acc) / math.max(1, T)))
        end
        acc = acc + T
    end
    return n, 1
end

local function Paint()
    if not (bar and route and fly) then return end
    local s = route.stops
    -- 지금 위치
    local k, t
    if route.testPos then
        k, t = Project(route.testPos[1], route.testPos[2])
    else
        local px, py = PlayerPos()
        if px then k, t = Project(px, py); fly.posSeen = true end
    end
    if not k then
        k, t = ByTime(); fly.byTime = true
        fly.leg = math.max(fly.leg, k)
    elseif k > fly.leg then
        -- 경유지를 지났어요: 그 구간 시간 저장
        for j = fly.leg, k - 1 do SaveLeg(j, GetTime() - fly.legStart); fly.legStart = GetTime() end
        fly.leg = k
    end
    k = math.max(k, fly.leg)
    fly.t = t
    -- 남은 거리 · 시간
    local remD = (route.len[k] or 0) * (1 - t)
    local remT, guess = 0, false
    local m, g = LegTime(k)
    if not g then remT = math.max(0, m - (GetTime() - fly.legStart))
    else remT = m * (1 - t); guess = true end
    local m = not g and m or nil
    for j = k + 1, #s - 1 do
        remD = remD + (route.len[j] or 0)
        local tj, gj = LegTime(j)
        remT = remT + tj
        if gj then guess = true end
    end
    -- 일찍 내리기를 눌렀으면 다음 지점까지만
    if fly.early then
        remD = (route.len[k] or 0) * (1 - t)
        remT = m and math.max(0, m - (GetTime() - fly.legStart)) or remD / Speed()
        guess = not m
    end
    bar.time:SetText(Clock(remT))
    bar.about:SetShown(guess)
    local meters = remD * 0.9144
    local dist = meters >= 1000 and ("%.1fkm"):format(meters / 1000) or ("%dm"):format(math.floor(meters / 10 + 0.5) * 10)
    local when = date("%H:%M", time() + math.floor(remT + 0.5))
    local target = fly.early and Short(s[math.min(k + 1, #s)][1]) or nil
    if target then
        bar.eta:SetText((L("%s에서 내려요 · %s 도착 · 남은 거리 %s")):format(target, when, dist))
    else
        bar.eta:SetText((L("%s 도착 · 남은 거리 %s")):format(when, dist))
    end
    -- 줄 채우기 · 나 · 점
    local tw = bar.track:GetWidth() or (W - 44)
    local f0 = route.frac[k] or 0
    local f1 = route.frac[k + 1] or 1
    local fr = f0 + (f1 - f0) * t
    bar.fill:SetWidth(math.max(1, fr * tw))
    bar.me:ClearAllPoints(); bar.me:SetPoint("CENTER", bar.track, "LEFT", fr * tw, 0)
    for j = 1, #s do
        local d = bar.dots[j]
        if d then
            if j <= k then d.i:SetVertexColor(1, 0.56, 0.67, 1) else d.i:SetVertexColor(0.35, 0.25, 0.27, 1) end
        end
    end
    -- 내리기 단추: 다음 지점이 끝이 아닐 때만
    local canEarly = k + 1 < #s
    bar.land:SetShown(canEarly or fly.early)
    if fly.early then
        bar.land.fs:SetText(L("다음 지점에서 내려요")); bar.land.bg:SetVertexColor(0.35, 0.27, 0.28, 1)
        bar.land.fs:SetTextColor(0.85, 0.78, 0.76)
    else
        bar.land.fs:SetText(L("다음 지점에서 내리기")); bar.land.bg:SetVertexColor(1, 0.56, 0.67, 1)
        bar.land.fs:SetTextColor(C.ink[1], C.ink[2], C.ink[3])
    end
    bar.land:SetWidth(bar.land.fs:GetStringWidth() + 22)
end

----------------------------------------------------------------------
-- 켜고 끄기
----------------------------------------------------------------------
local ticker
local pending       -- 목적지를 눌렀는데 아직 안 떴을 때

local function Stop()
    if ticker then ticker:Cancel(); ticker = nil end
    if bar then bar:Hide() end
end

local function Update()
    local on = UnitOnTaxi and UnitOnTaxi("player")
    if on and pending then
        route, pending = pending, nil
        fly = { leg = 1, legStart = GetTime(), started = GetTime() }
    end
    if not on then
        -- 내렸어요: 마지막 구간 시간 저장 (끝까지 갔을 때 · 일찍 내리기로 다음 지점에 내렸을 때)
        if route and fly and not fly.test then
            if fly.posSeen then
                local k = fly.leg
                if (fly.t or 0) > 0.85 or k == #route.stops - 1 or fly.early then SaveLeg(k, GetTime() - fly.legStart) end
            elseif not fly.early and route.total > 0 then
                -- 위치를 못 읽었으면: 전체 비행 시간을 구간 거리 비율로 나눠 저장
                local total = GetTime() - fly.started
                for j = 1, #route.stops - 1 do SaveLeg(j, total * (route.len[j] or 0) / route.total) end
            end
        end
        route, fly = nil, nil
        Stop()
        return
    end
    if not (route and fly and On()) then Stop() return end
    bar = bar or Build()
    bar.Paint = Paint
    if not bar:IsShown() then bar:Show(); Layout() end
    Paint()
    if not ticker then ticker = C_Timer.NewTicker(0.25, function() pcall(Paint) end) end
end
ns.FlightBarUpdate = function() if route and fly then if On() then Update() else Stop() end end end

if TakeTaxiNode then
    hooksecurefunc("TakeTaxiNode", function(i)
        local ok, r = pcall(ReadRoute, i)
        pending = ok and r or nil
    end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_CONTROL_LOST"); ev:RegisterEvent("PLAYER_CONTROL_GAINED"); ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
    C_Timer.After(0.4, function() pcall(Update) end)
    C_Timer.After(1.5, function() pcall(Update) end)
end)

-- 시험: /르엘비행  (비행 조련사 없이 띠 모양 보기 · 다시 치면 꺼요)
SLASH_LEELFLY1 = "/르엘비행"; SLASH_LEELFLY2 = "/leelfly"
SlashCmdList.LEELFLY = function()
    if bar and bar:IsShown() and fly and fly.test then
        route, fly = nil, nil; Stop(); return
    end
    route = {
        stops = { { "오그리마 (듀로타)", 0.10, 0.50 }, { "크로스로드 (불모의 땅)", 0.30, 0.52 }, { "톱니항 (불모의 땅)", 0.55, 0.60 }, { "그롬골 (가시덤불 골짜기)", 0.90, 0.55 } },
        len = { 800, 900, 1300 }, total = 3000, map = 0, mw = 1, mh = 1, kind = UnitFactionGroup("player") == "Horde" and "wyvern" or "gryphon",
    }
    fly = { leg = 2, legStart = GetTime() - 20, started = GetTime() - 60, test = true }
    bar = bar or Build(); bar.Paint = Paint
    bar:Show(); Layout()
    local t0 = GetTime()
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(0.25, function()
        if not (fly and fly.test) then return end
        -- 가짜 위치: 2번째 구간을 30초 동안 지나가요
        local p = math.min(1, (GetTime() - t0) / 30)
        local a, b = route.stops[2], route.stops[3]
        route.testPos = { a[2] + (b[2] - a[2]) * p, a[3] + (b[3] - a[3]) * p }
        pcall(Paint)
    end)
end
