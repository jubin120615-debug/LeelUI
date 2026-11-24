-- Leel Map / Exits.lua
-- 세계 지도 지역 출구 화살표: 이 지역에서 옆 지역으로 넘어가는 곳에 분홍 화살표.
--   마우스 → 이어지는 지역 이름 · 레벨(난이도 색), 클릭 → 그 지역 지도로.
--   자리 정하기 (우리 자료만 써요):
--     1) 내가 실제로 지역을 넘어간 자리를 기억해서 그 자리에 (LeelMapDB.exitSeen, 가장 정확)
--     2) 아직 안 넘어가 본 곳은 게임 지도의 지역 경계를 읽어서 맞닿은 경계 가운데에
--   어느 지역끼리 이어지는지는 아래 LINKS 표 (걸어서 넘어갈 수 있는 곳만)

local M = "Interface\\AddOns\\LeelMap\\media\\"
local LM = "Interface\\AddOns\\LeelUI\\media\\"
local FONT = STANDARD_TEXT_FONT or "Fonts\\2002.TTF"
-- 영어 (르엘 UI 언어 설정을 따라가요)
local function T(s) local L = _G.LeelUI; if L and L.L then return L.L(s) end return s end
local function TipAdd(s, ...) return GameTooltip:AddLine(T(s), ...) end
local function TipSet(s, ...) return GameTooltip:SetText(T(s), ...) end
local ACC = { 0.949, 0.702, 0.761 }
local INK = { 0.227, 0.11, 0.141 }

-- 이어지는 지역은 게임 지도에서 맞닿은 지역을 읽어서 정해요 (와우 포에버 새 지역도 자동으로).
-- 산맥 · 막힌 문처럼 걸어서 못 넘는 경계만 여기서 빼요
local BLOCK = {
    { 1427, 1426 }, { 1426, 1437 }, { 1433, 1435 }, { 1433, 1430 }, { 1436, 1434 },
    { 1416, 1421 }, { 1412, 1442 }, { 1439, 1448 },
}
local BLOCKED = {}
for _, p in ipairs(BLOCK) do BLOCKED[p[1] .. ":" .. p[2]] = true; BLOCKED[p[2] .. ":" .. p[1]] = true end
local function Passable(a, b) return a ~= b and not BLOCKED[a .. ":" .. b] end

-- 실제 길목 자리 (걸어서 넘어가는 곳) · { 지역A, x, y, 지역B, x, y }  (지역 지도 좌표 %)
--   자료: Carbonite Classic 지역 연결 자료(GPL) + 르엘이 직접 다니며 모은 자리
local ROUTES = {
    { 1417, 20.34, 29.73, 1424, 81.96, 56.91 },
    { 1417, 45.45, 89.06, 1437, 51.06, 11.95 },
    { 1439, 43.69, 94.70, 1440, 29.16, 14.99 },
    { 1440, 42.34, 70.96, 1442, 78.21, 42.94 },
    { 1440, 55.85, 31.70, 1448, 54.91, 92.71 },
    { 1440, 94.56, 47.60, 1447, 10.72, 75.27 },
    { 1440, 68.63, 86.25, 1413, 48.44, 11.33 },
    { 1448, 64.97, 8.36, 1450, 35.77, 72.20 },
    { 1448, 64.97, 8.36, 1452, 27.96, 34.56 },
    { 1411, 45.54, 12.28, 1454, 52.49, 84.40 },
    { 1411, 37.20, 43.00, 1413, 60.80, 19.80 },
    { 1434, 40.81, 4.19, 1431, 44.50, 87.51 },
    { 1431, 10.60, 63.80, 1436, 68.90, 63.00 },
    { 1436, 60.90, 19.00, 1429, 22.30, 78.20 },
    { 1429, 32.33, 49.86, 1453, 73.34, 90.73 },
    { 1429, 93.21, 72.27, 1433, 8.95, 71.90 },
    { 1431, 93.75, 11.43, 1433, 7.10, 89.26 },
    { 1431, 89.88, 41.25, 1430, 33.05, 35.96 },
    { 1430, 58.29, 41.44, 1435, 5.84, 60.78 },
    { 1419, 52.03, 5.60, 1435, 33.83, 66.07 },
    { 1433, 46.52, 8.56, 1428, 78.85, 82.50 },
    { 1427, 34.81, 83.74, 1428, 31.83, 50.44 },
    { 1427, 76.63, 56.67, 1418, 1.09, 62.92 },
    { 1432, 47.19, 80.82, 1418, 49.36, 7.97 },
    { 1432, 19.61, 62.81, 1426, 86.13, 51.16 },
    { 1432, 19.23, 17.21, 1426, 84.37, 31.09 },
    { 1455, 21.62, 77.79, 1426, 53.40, 35.01 },
    { 1432, 25.57, 10.47, 1437, 53.97, 70.33 },
    { 1416, 51.20, 65.60, 1424, 55.50, 16.60 },
    { 1425, 9.66, 55.77, 1424, 85.06, 31.27 },
    { 1425, 24.94, 45.71, 1422, 65.48, 88.64 },
    { 1416, 80.66, 36.42, 1422, 44.05, 86.19 },
    { 1420, 84.09, 70.49, 1422, 28.62, 57.46 },
    { 1423, 8.82, 66.22, 1422, 69.67, 50.24 },
    { 1421, 66.36, 79.80, 1424, 14.35, 46.20 },
    { 1421, 67.56, 5.45, 1420, 54.14, 75.77 },
    { 1458, 66.01, 36.85, 1420, 61.86, 64.95 },
    { 1454, 18.00, 60.43, 1413, 63.88, 0.00 },
    { 1413, 39.42, 29.68, 1442, 82.78, 96.94 },
    { 1443, 53.40, 5.52, 1442, 30.21, 75.61 },
    { 1443, 40.91, 90.72, 1444, 45.45, 2.82 },
    { 1444, 89.10, 41.14, 1441, 7.98, 10.93 },
    { 1413, 44.15, 91.23, 1441, 31.92, 24.22 },
    { 1446, 50.68, 24.29, 1441, 74.24, 93.62 },
    { 1446, 27.08, 57.20, 1449, 71.44, 77.23 },
    { 1449, 29.43, 22.42, 1451, 83.68, 14.26 },
    { 1445, 30.02, 47.11, 1413, 49.53, 78.41 },
    { 1413, 41.87, 58.62, 1412, 68.59, 60.59 },
    { 1450, 35.77, 72.20, 1452, 27.96, 34.56 },
    { 1438, 36.32, 54.38, 1457, 85.73, 35.93 },
    { 1412, 37.59, 33.03, 1456, 35.69, 63.08 },
    { 1412, 34.59, 27.91, 1456, 35.69, 63.08 },
    { 1412, 38.97, 19.09, 1456, 51.17, 31.54 },
    { 1412, 42.13, 20.20, 1456, 51.17, 31.54 },
    -- 르엘이 모은 자리 (와우 포에버 새 지역)
    { 1418, 54.42, 92.71, 2548, 31.84, 29.99 },
}
local SEED = {}   -- [지역] = { [옆 지역] = { {x, y}, ... } }
for _, r in ipairs(ROUTES) do
    local function Add(z, to, x, y)
        SEED[z] = SEED[z] or {}
        SEED[z][to] = SEED[z][to] or {}
        local t = SEED[z][to]
        for _, p in ipairs(t) do if math.abs(p[1] - x) < 0.02 and math.abs(p[2] - y) < 0.02 then return end end
        t[#t + 1] = { x, y }
    end
    Add(r[1], r[4], r[2] / 100, r[3] / 100)
    Add(r[4], r[1], r[5] / 100, r[6] / 100)
end

local function DB()
    LeelMapDB = LeelMapDB or {}
    LeelMapDB.exitSeen = LeelMapDB.exitSeen or {}
    return LeelMapDB
end
local function On() return not (LeelMapDB and LeelMapDB.exits == false) end
-- 길목 자료가 없는 지역(와우 포에버 새 지역 등)만 지도 경계로 짐작 · 연하게 "?"로 · 끌 수 있어요
local function Guess() return not (LeelMapDB and LeelMapDB.exitGuess == false) end

local function Info(m)
    local ok, i = pcall(C_Map.GetMapInfo, m)
    return ok and i or nil
end
local function Continent(m)
    local i = Info(m)
    for _ = 1, 6 do
        if not i then return end
        if i.mapType == 2 then return i.mapID end   -- Enum.UIMapType.Continent
        i = i.parentMapID and Info(i.parentMapID)
    end
end

-- 지도 좌표 바꾸기 (같은 대륙)
local function WorldPos(m, x, y)
    if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
    local ok, cont, v = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x, y))
    if ok and v then return cont, v.x, v.y end
end
local function ToMap(src, x, y, dst)
    if src == dst then return x, y end
    local c1, wx, wy = WorldPos(src, x, y)
    local c0, ax, ay = WorldPos(dst, 0, 0)
    local _, bx, by = WorldPos(dst, 1, 1)
    if not (c1 and c0 and bx) or c1 ~= c0 then return end
    local dy, dx = by - ay, bx - ax
    if math.abs(dy) < 1e-6 or math.abs(dx) < 1e-6 then return end
    return (wy - ay) / dy, (wx - ax) / dx
end
local function OMCanvas(m, x, y)
    local OM = _G.OpenMapAPI
    if not (OM and OM.major == 1 and (OM.version or 0) >= 2 and OM.IsStitched and OM.IsStitched()) then return end
    local cont, wx, wy = WorldPos(m, x, y)
    if not cont then return false end
    local ok, cx, cy = pcall(OM.CanvasFromWorldPos, cont, wx, wy)
    if ok and cx then return cx, cy end
    return false
end

----------------------------------------------------------------------
-- 경계 읽기: 지역 안을 촘촘히 찍어 보고, 옆 지역과 맞닿은 칸들의 가운데를 출구로
----------------------------------------------------------------------
local N = 64
local GAP = 4            -- 지역 사이 빈 칸(바다 · 경계선)이 있어도 이만큼은 건너서 찾아요
local cache = {}         -- [zone] = { [to] = { x, y, ang } }
local zoneType = {}
local function IsZone(m)
    if zoneType[m] == nil then
        local i = Info(m)
        zoneType[m] = (i and i.mapType == 3) or false
    end
    return zoneType[m]
end
local function Borders(z)
    if cache[z] then return cache[z] end
    local out = {}
    cache[z] = out
    local cont = Continent(z)
    if not (cont and C_Map.GetMapInfoAtPosition) then return out end
    local grid = {}
    for j = 0, N - 1 do
        local row = {}
        grid[j] = row
        for i = 0, N - 1 do
            local cx, cy = ToMap(z, (i + 0.5) / N, (j + 0.5) / N, cont)
            local who
            if cx and cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 then
                local ok, inf = pcall(C_Map.GetMapInfoAtPosition, cont, cx, cy)
                who = ok and inf and inf.mapID or nil
            end
            row[i] = who or 0
        end
    end
    local acc = {}
    local D = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
    for j = 0, N - 1 do
        for i = 0, N - 1 do
            if grid[j][i] == z then
                for _, d in ipairs(D) do
                    for k = 1, GAP do
                        local r = grid[j + d[2] * k]
                        local b = r and r[i + d[1] * k]
                        if b == nil or b == z then break end
                        if b ~= 0 then
                            if Passable(z, b) and IsZone(b) then
                                local a = acc[b] or { n = 0, sx = 0, sy = 0, dx = 0, dy = 0, cells = {} }
                                acc[b] = a
                                a.n = a.n + 1
                                a.sx, a.sy = a.sx + i, a.sy + j
                                local l = math.sqrt(d[1] * d[1] + d[2] * d[2])
                                a.dx, a.dy = a.dx + d[1] / l, a.dy + d[2] / l
                                a.cells[#a.cells + 1] = { i, j }
                            end
                            break
                        end
                    end
                end
            end
        end
    end
    for b, a in pairs(acc) do
        if a.n >= 3 then                      -- 한두 칸만 스치는 모서리는 빼요
            local mx, my = a.sx / a.n, a.sy / a.n
            local best, bd = nil, math.huge
            for _, c in ipairs(a.cells) do     -- 경계 위 칸 중 가운데에 제일 가까운 칸
                local d = (c[1] - mx) ^ 2 + (c[2] - my) ^ 2
                if d < bd then best, bd = c, d end
            end
            local l = math.max(0.001, math.sqrt(a.dx * a.dx + a.dy * a.dy))
            local ux, uy = a.dx / l, a.dy / l
            -- 경계선 바로 위가 아니라 살짝 안쪽(이 지역 쪽)에 놓아요
            local x = (best[1] + 0.5 - ux * 1.5) / N
            local y = (best[2] + 0.5 - uy * 1.5) / N
            out[b] = { x = x, y = y, ang = math.atan2(-uy, ux) }
        end
    end
    return out
end

-- 이 지역에서 보여 줄 출구들: 다녀 본 자리 > 경계 가운데
local function Exits(z)
    local list = {}
    -- 내 PC 전용 자료(ExitsData.lua)가 있으면 그 자리를 그대로 써요
    local fixed = _G.LeelMapExitData and LeelMapExitData[z]
    if fixed then
        for _, e in ipairs(fixed) do
            list[#list + 1] = { x = e[1], y = e[2], ang = e[3], to = e[4], sure = true }
        end
        return list
    end
    local seen = DB().exitSeen[z] or {}
    local seed = SEED[z]
    -- 길목 자료가 있는 지역은 짐작 안 해요 (절벽 · 산으로 막힌 경계에 엉뚱한 화살표가 생겨서)
    local auto = (not seed and Guess()) and Borders(z) or {}
    seed = seed or {}
    local tos = {}
    for b in pairs(auto) do tos[b] = true end
    for b in pairs(seed) do tos[b] = true end
    for b in pairs(seen) do if Passable(z, b) then tos[b] = true end end
    local function Ang(x, y, a) return (a and a.ang) or math.atan2(-(y - 0.5), x - 0.5) end
    for b in pairs(tos) do
        local s, sd, a = seen[b], seed[b], auto[b]
        if sd then
            for _, p in ipairs(sd) do list[#list + 1] = { to = b, x = p[1], y = p[2], ang = Ang(p[1], p[2], a), sure = true } end
            -- 내가 다닌 길이 자료와 많이 다르면 (새 길) 그것도
            if s then
                local far = true
                for _, p in ipairs(sd) do if math.abs(p[1] - s.x) < 0.05 and math.abs(p[2] - s.y) < 0.05 then far = false end end
                if far then list[#list + 1] = { to = b, x = s.x, y = s.y, ang = Ang(s.x, s.y, a), sure = true } end
            end
        elseif s then
            list[#list + 1] = { to = b, x = s.x, y = s.y, ang = Ang(s.x, s.y, a), sure = true }
        else
            list[#list + 1] = { to = b, x = a.x, y = a.y, ang = a.ang, guess = true }
        end
    end
    return list
end

----------------------------------------------------------------------
-- 지역을 넘어갈 때 자리 기억 (내 길이 곧 출구)
----------------------------------------------------------------------
local prev = {}
local function Learn()
    local m = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not m then return end
    local ok, p = pcall(C_Map.GetPlayerMapPosition, m, "player")
    if not (ok and p) then prev = {} return end
    local x, y = p:GetXY()
    if not x or (x == 0 and y == 0) then prev = {} return end
    local now = GetTime()
    if prev.m and prev.m ~= m and IsZone(prev.m) and IsZone(m) and Passable(prev.m, m) and now - prev.t < 4
        and Borders(prev.m)[m]   -- 지도에서 정말 맞닿은 지역만 (배 · 차원문 · 순간이동은 빼요)
        and not (UnitOnTaxi and UnitOnTaxi("player")) then
        local s = DB().exitSeen
        local function Put(a, b, px, py)
            s[a] = s[a] or {}
            local o = s[a][b]
            if o then   -- 여러 번 다니면 자주 쓰는 길 쪽으로 천천히
                local n = math.min(o.n or 1, 4)
                o.x = (o.x * n + px) / (n + 1); o.y = (o.y * n + py) / (n + 1); o.n = (o.n or 1) + 1
            else
                s[a][b] = { x = px, y = py, n = 1 }
            end
        end
        Put(prev.m, m, prev.x, prev.y)
        Put(m, prev.m, x, y)
    end
    prev = { m = m, x = x, y = y, t = now }
end

----------------------------------------------------------------------
-- 그리기
----------------------------------------------------------------------
local layer, pins = nil, {}

local function Tip(self)
    local e = self.e
    if not e then return end
    local name = (Info(e.to) or {}).name or "?"
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    TipSet("→ " .. name, ACC[1], ACC[2], ACC[3])
    local f = _G.LeelMapLevelInfo
    local minL, maxL, c, hint
    if f then minL, maxL, c, hint = f(e.to) end
    if minL then
        TipAdd(T("레벨 %s  %s"):format(minL == maxL and minL or (minL .. "-" .. maxL), T(hint or "")), c[1], c[2], c[3])
    end
    TipAdd("클릭하면 그 지역 지도로", 0.8, 0.8, 0.8)
    if e.guess then TipAdd("대략적인 자리 (아직 확인 안 된 길) · 한 번 넘어가 보면 실제 길 자리로 옮겨져요", 0.6, 0.6, 0.6, true) end
    GameTooltip:Show()
end

local SIZE = 15
-- 분홍 동그라미 + 안에 작은 화살표. 동그라미는 그대로, 화살표만 가는 쪽으로 돌려요
local function Shade(b, hot)
    local a = (b.e and b.e.sure) and 1 or 0.55   -- 짐작한 출구는 연하게 + "?"
    if hot then a = 1 end
    if b.q then b.q:SetShown(b.e and b.e.guess and true or false); b.glyph:SetShown(not (b.e and b.e.guess)) end
    b:SetAlpha(a)
    if hot then b.disc:SetVertexColor(1, 0.9, 0.93) else b.disc:SetVertexColor(1, 1, 1) end
end
local function MakePin()
    local b = CreateFrame("Button", nil, layer)
    b:SetSize(SIZE, SIZE)
    b.disc = b:CreateTexture(nil, "ARTWORK"); b.disc:SetTexture(M .. "exit_disc"); b.disc:SetAllPoints()
    b.glyph = b:CreateTexture(nil, "OVERLAY"); b.glyph:SetTexture(M .. "exit_glyph"); b.glyph:SetAllPoints()
    b.q = b:CreateFontString(nil, "OVERLAY"); pcall(b.q.SetFont, b.q, FONT, 10, ""); b.q:SetPoint("CENTER", 0, 0)
    b.q:SetTextColor(INK[1], INK[2], INK[3]); b.q:SetShadowOffset(0, 0); b.q:SetText("?"); b.q:Hide()
    b:SetHitRectInsets(-4, -4, -4, -4)
    b:SetScript("OnEnter", function(self)
        Shade(self, true); self:SetSize(SIZE * 1.25, SIZE * 1.25)
        Tip(self)
    end)
    b:SetScript("OnLeave", function(self)
        Shade(self, false); self:SetSize(SIZE, SIZE)
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(self)
        if self.e and WorldMapFrame and WorldMapFrame.SetMapID then
            PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
            pcall(WorldMapFrame.SetMapID, WorldMapFrame, self.e.to)
        end
    end)
    return b
end

local function Paint()
    local W = _G.WorldMapFrame
    if not (W and W:IsShown() and W.ScrollContainer and W.ScrollContainer.Child) then return end
    local canvas = W.ScrollContainer.Child
    if not layer then
        layer = CreateFrame("Frame", nil, canvas)
        layer:SetAllPoints(canvas)
    end
    layer:SetFrameLevel(math.min(canvas:GetFrameLevel() + 5900, 8900))   -- Leel Quest 길 · 길드원 아래
    local n = 0
    local m = W.GetMapID and W:GetMapID()
    local cw, ch = canvas:GetWidth(), canvas:GetHeight()
    local s = canvas:GetScale() or 1
    if On() and m and cw and cw > 0 then
        -- OpenMap 이어 붙인 지도면 보이는 대륙의 모든 지역 출구를, 아니면 보고 있는 지역 출구를
        local stitched = OMCanvas(m, 0.5, 0.5) ~= nil
        local zones = {}
        if stitched then
            local here = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
            local seen = {}
            local function Add(z) if z and not seen[z] and IsZone(z) then seen[z] = true; zones[#zones + 1] = z end end
            Add(here)
            for z in pairs(_G.LeelMapExitData or {}) do Add(z) end
            for z in pairs(DB().exitSeen) do Add(z) end
            for z in pairs(SEED) do Add(z) end
        elseif IsZone(m) then
            zones[1] = m
        end
        local here = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        local cand = {}
        for _, z in ipairs(zones) do
            for _, e in ipairs(Exits(z)) do
                local x, y
                if stitched then x, y = OMCanvas(z, e.x, e.y) else x, y = e.x, e.y end
                if x then cand[#cand + 1] = { e = e, from = z, x = x, y = y } end
            end
        end
        -- 경계 양쪽에서 서로 마주보는 한 쌍은 하나만: 내 지역에서 나가는 쪽 > 번호 작은 지역 쪽
        if stitched then
            for i, c in ipairs(cand) do
                if not c.drop then
                    for j = i + 1, #cand do
                        local d = cand[j]
                        if not d.drop and d.from == c.e.to and d.e.to == c.from
                            and math.abs(d.x - c.x) < 0.03 and math.abs(d.y - c.y) < 0.03 then
                            local keepC = (c.from == here) or (d.from ~= here and c.from < d.from)
                            if keepC then d.drop = true else c.drop = true end
                        end
                    end
                end
            end
        end
        for _, c in ipairs(cand) do
            if not c.drop then
                local e = c.e
                n = n + 1
                local b = pins[n] or MakePin()
                pins[n] = b
                b.e = e
                b:SetScale(1 / s)
                b:SetSize(SIZE, SIZE)
                b:ClearAllPoints(); b:SetPoint("CENTER", layer, "TOPLEFT", c.x * cw * s, -c.y * ch * s)
                Shade(b, false)
                b.glyph:SetRotation(e.ang or 0)
                b:SetFrameLevel(layer:GetFrameLevel() + 2)
                b:Show()
            end
        end
    end
    for i = n + 1, #pins do pins[i]:Hide() end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    DB()
    -- 예전에 잘못 기억한 자리 (맞닿지 않은 지역끼리: 배 · 순간이동) 지우기
    C_Timer.After(3, function()
        local seen = DB().exitSeen
        for a, t in pairs(seen) do
            for b in pairs(t) do
                local ok, nb = pcall(Borders, a)
                if ok and type(nb) == "table" and not nb[b] then t[b] = nil end
            end
            if not next(t) then seen[a] = nil end
        end
    end)
    C_Timer.NewTicker(1, Learn)
    local acc = 0
    f:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc < 0.25 then return end
        acc = 0
        if _G.WorldMapFrame and WorldMapFrame:IsShown() then Paint() end
    end)
end)

_G.LeelMapExits = {
    -- /lmap 출구: 지금 지역에서 찾은 출구 목록
    Dump = function()
        local z = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        if not z then return end
        cache[z] = nil
        local p = function(t) DEFAULT_CHAT_FRAME:AddMessage("|cfff2b3c2[Leel Map]|r " .. t) end
        p(T("%s (%d) 출구:"):format((Info(z) or {}).name or "?", z))
        for _, e in ipairs(Exits(z)) do
            p(("  → %s (%d)  %.1f, %.1f  %s"):format((Info(e.to) or {}).name or "?", e.to, e.x * 100, e.y * 100, e.sure and "길목" or "짐작"))
        end
    end,
    Refresh = function() Paint() end,
    Forget = function() if LeelMapDB then LeelMapDB.exitSeen = {} end; Paint() end,
    -- 르엘 허브 미리 보기: 이 지역 출구 { to = 지도 번호, x, y (0~1), name }
    List = function(z)
        local out = {}
        local ok, list = pcall(Exits, z)
        for _, e in ipairs(ok and list or {}) do out[#out + 1] = { to = e.to, x = e.x, y = e.y, name = (Info(e.to) or {}).name } end
        return out
    end,
}
