-- Leel Map / Dungeon.lua
-- 던전 경로 지도 (B안): 던전 안에서 M → 르엘 지도 위에 그 던전 지도 + 분홍 경로 선 · 방향 화살표
--   · 우두머리 순서 번호 (잡으면 ✓ · 다음 차례는 반짝) · 위에 "다음" 알약 · 번호에 마우스 = 한국어 메모
--   · 층 단추 · 계단(↓↑) 누르면 그 층으로 · 게임이 알려주는 방 이름으로 "여기" 표시
-- 데이터: DungeonData.lua (Forever Dungeon Routes 의 경로 데이터 · MIT)
-- 지도 그림은 게임 것: 고전 던전 = 지도 그림 12장, 포에버 새 던전 = 미니맵 그림 조각

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"
local NUM = MEDIA .. "BarlowCondensed-ExtraBoldItalic.ttf"
local MAP_W, MAP_H, TILE = 1002, 668, 256
local ACC = { 0.949, 0.702, 0.761 }
local INK = { 0.12, 0.08, 0.075 }

local function T(s) local L = _G.LeelUI; if L and L.L then return L.L(s) end return s end
local function IsKo() return (GetLocale and GetLocale() == "koKR") or (_G.LeelUI and _G.LeelUI.lang == "ko") end
local function Pick(ko, en) if IsKo() or not en or en == "" then return ko end return en end
local function FontOf() local L = _G.LeelUI; return (L and L.FONT) or STANDARD_TEXT_FONT end
local function MakeFS(parent, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(FontOf(), size, "")
    if color then fs:SetTextColor(color[1], color[2], color[3], color[4] or 1) end
    fs:SetShadowColor(0, 0, 0, 0.9); fs:SetShadowOffset(1, -1)
    return fs
end
local function DB()
    LeelMapDB = LeelMapDB or {}
    return LeelMapDB
end

----------------------------------------------------------------------
-- 지금 던전 · 층 찾기
----------------------------------------------------------------------
local D
local function Data() D = D or ns.DungeonData; return D end
local byKey = {}
local function Dungeon(key)
    if not next(byKey) and Data() then for _, d in ipairs(D.dungeons) do byKey[d.key] = d end end
    return byKey[key]
end
local function InList(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end

-- 방 이름 (게임이 알려주는 작은 지역 이름) → { 층, u, v }
local function RoomHere(key)
    local rooms = Data() and D.rooms[key]
    if not rooms then return end
    local names = { GetSubZoneText and GetSubZoneText(), GetMinimapZoneText and GetMinimapZoneText() }
    for _, nm in ipairs(names) do
        if type(nm) == "string" and nm ~= "" and not (issecretvalue and issecretvalue(nm)) then
            for _, r in ipairs(rooms) do
                if r[1] == nm or r[2] == nm then return { floor = r[3], u = r[4], v = r[5], name = r[1] } end
            end
        end
    end
end

local function CurrentKey()
    if not Data() then return end
    local inInst, kind = IsInInstance()
    if not inInst or (kind ~= "party" and kind ~= "raid") then return end
    local _, _, _, _, _, _, _, instID = GetInstanceInfo()
    if not instID or (issecretvalue and issecretvalue(instID)) then return end
    local cands = {}
    for _, d in ipairs(D.dungeons) do if d.inst == instID then cands[#cands + 1] = d end end
    if #cands <= 1 then return cands[1] and cands[1].key end
    -- 한 인스턴스에 여러 날개 (붉은십자군 수도원 · 혈투의 전장 …): 게임 지도 번호 · 방 이름으로
    local mid = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if mid and not (issecretvalue and issecretvalue(mid)) then
        for _, d in ipairs(cands) do if InList(d.floors, mid) then return d.key end end
    end
    for _, d in ipairs(cands) do if RoomHere(d.key) then return d.key end end
    return cands[1].key
end

----------------------------------------------------------------------
-- 이번 판 기록 (잡은 우두머리)
----------------------------------------------------------------------
local function Run(key)
    local db = DB()
    local r = db.drun
    if not r or r.key ~= key then
        r = { key = key, t = time(), done = {} }
        db.drun = r
    end
    return r
end
local function StopDone(run, s)
    local enc = s[9]
    if not enc or #enc == 0 then return run.done["s:" .. s[5]] end
    for _, e in ipairs(enc) do if run.done[e] then return true end end
    return false
end
-- 우두머리만 번호 (순서대로) · 다음 차례
local function Bosses(route)
    local list = {}
    for _, s in ipairs(route.stops) do if s[1] == "boss" then list[#list + 1] = s end end
    return list
end

----------------------------------------------------------------------
-- 화면
----------------------------------------------------------------------
local V                 -- 덮개 (지도 칸 전체)
local cv                -- 1002x668 그림판 (크기에 맞게 늘이고 줄여요)
local cur = { key = nil, floor = nil }
local hiddenByUser = false
local openMapID
local previewKey     -- 허브 미리 보기 (던전 밖에서도)
local seenKey        -- 던전 밖: OpenMap 이나 게임 지도가 띄운 던전 지도 (그 던전 경로로 바꿔 보여줘요)

local pools = { tex = {}, arr = {}, line = {}, btn = {} }
local used = { tex = 0, arr = 0, line = 0, btn = 0 }
local function ResetPools()
    for _, k in ipairs({ "tex", "arr", "line", "btn" }) do
        for i = 1, #pools[k] do pools[k][i]:Hide() end
        used[k] = 0
    end
end
local function Tex(layer, sub, arrow)
    local k = arrow and "arr" or "tex"
    used[k] = used[k] + 1
    local t = pools[k][used[k]]
    if not t then t = (arrow and V.arrowLayer or cv):CreateTexture(nil, "BACKGROUND"); pools[k][used[k]] = t end
    t:SetDrawLayer(layer or "BACKGROUND", sub or 0)
    t:SetVertexColor(1, 1, 1, 1); t:SetTexCoord(0, 1, 0, 1); t:SetRotation(0)
    t:ClearAllPoints(); t:Show()
    return t
end
local function Line(x1, y1, x2, y2, w, r, g, b, a, sub, glow)
    used.line = used.line + 1
    local l = pools.line[used.line]
    if not l then l = V.lineLayer:CreateLine(nil, "ARTWORK"); pools.line[used.line] = l end
    l:SetDrawLayer("ARTWORK", sub or 0)
    if glow then
        -- 내비게이션 빛: 가운데가 진하고 가장자리로 흐려지는 그림을 선 굵기 방향으로
        l:SetTexture(MEDIA .. "glowline"); l:SetVertexColor(r, g, b, a or 1); l:SetBlendMode("ADD")
    else
        l:SetBlendMode("BLEND"); l:SetColorTexture(r, g, b, a or 1)
    end
    l:SetThickness(w)
    l:SetStartPoint("TOPLEFT", cv, x1 * MAP_W, -y1 * MAP_H)
    l:SetEndPoint("TOPLEFT", cv, x2 * MAP_W, -y2 * MAP_H)
    l:Show()
    return l
end
local function Pin(size)
    used.btn = used.btn + 1
    local b = pools.btn[used.btn]
    if not b then
        b = CreateFrame("Button", nil, V.pinLayer)
        b.bg = b:CreateTexture(nil, "ARTWORK"); b.bg:SetTexture(MEDIA .. "circle"); b.bg:SetAllPoints()
        b.ring = b:CreateTexture(nil, "BORDER"); b.ring:SetTexture(MEDIA .. "circle")
        b.ring:SetPoint("TOPLEFT", -3, 3); b.ring:SetPoint("BOTTOMRIGHT", 3, -3)
        b.glow = b:CreateTexture(nil, "BACKGROUND"); b.glow:SetTexture(MEDIA .. "circle")
        b.glow:SetPoint("TOPLEFT", -9, 9); b.glow:SetPoint("BOTTOMRIGHT", 9, -9); b.glow:SetBlendMode("ADD")
        b.fs = b:CreateFontString(nil, "OVERLAY"); b.fs:SetFont(NUM, 19, ""); b.fs:SetPoint("CENTER", 0, 0)
        b.icon = b:CreateTexture(nil, "OVERLAY"); b.icon:SetPoint("CENTER"); b.icon:SetSize(14, 14)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        pools.btn[used.btn] = b
    end
    b:SetSize(size, size)
    b:SetFrameLevel(V.pinLayer:GetFrameLevel() + 2)
    b.glow:Hide(); b.icon:Hide(); b.icon:SetRotation(0); b.fs:SetText("")
    b:SetScript("OnEnter", nil); b:SetScript("OnClick", nil)
    b:ClearAllPoints(); b:Show()
    return b
end
local function Place(f, x, y) f:SetPoint("CENTER", cv, "TOPLEFT", x * MAP_W, -y * MAP_H) end

-- 지도 그림
local function DrawArt(floor)
    local info = D.floors[floor]
    V.noArt:Hide()
    if info and info.tiles then
        for i = 1, 12 do
            local row, col = math.floor((i - 1) / 4), (i - 1) % 4
            local w = math.min(TILE, MAP_W - col * TILE)
            local h = math.min(TILE, MAP_H - row * TILE)
            local t = Tex("BACKGROUND", 0)
            t:SetTexture(info.tiles[i])
            t:SetSize(w, h)
            t:SetPoint("TOPLEFT", cv, "TOPLEFT", col * TILE, -row * TILE)
            t:SetTexCoord(0, w / TILE, 0, h / TILE)
        end
    elseif info and info.mm then
        for _, p in ipairs(info.mm) do
            local t = Tex("BACKGROUND", math.max(-7, math.min(7, (p[14] or 0) + 1)))
            t:SetTexture(p[1])
            t:SetSize(p[4], p[5])
            t:SetPoint("TOPLEFT", cv, "TOPLEFT", p[2], -p[3])
            t:SetTexCoord(p[6], p[7], p[8], p[9], p[10], p[11], p[12], p[13])
        end
    else
        V.noArt:Show()
    end
end

-- 큰 길을 우두머리(멈춤)마다 구간으로 나눠요: 구간 = 앞 멈춤 → 이 멈춤까지 가는 길
--   멈춤은 길이 그 근처를 처음 제대로 지나가는 곳에서 잘라요 (가장 가까운 거리 + 12픽셀 안에 처음 든 점)
local legCache = {}
local function Legs(key, route)
    if legCache[key] then return legCache[key] end
    local legs = {}
    local si = 1
    local stops = route.stops
    for _, p in ipairs(route.main) do
        local floor, pts = p[1], p[4]
        local n = #pts / 2
        local from = 1
        while stops[si] and stops[si][2] == floor do
            local sx, sy = stops[si][3] * MAP_W, stops[si][4] * MAP_H
            local best = math.huge
            for k = from, n do
                local dx, dy = pts[2 * k - 1] * MAP_W - sx, pts[2 * k] * MAP_H - sy
                local d = math.sqrt(dx * dx + dy * dy)
                if d < best then best = d end
            end
            if best > 60 then
                si = si + 1   -- 큰 길이 그 근처로 안 가요 (곁길 끝 · 희귀): 건너뛰어요
            else
            local cut = n
            for k = from, n do
                local dx, dy = pts[2 * k - 1] * MAP_W - sx, pts[2 * k] * MAP_H - sy
                if math.sqrt(dx * dx + dy * dy) <= best + 12 then cut = k; break end
            end
            local seg = {}
            for k = from, cut do seg[#seg + 1] = pts[2 * k - 1]; seg[#seg + 1] = pts[2 * k] end
            legs[#legs + 1] = { floor = floor, pts = seg, stop = si }
            from = cut
            si = si + 1
            end
        end
        -- 이 층의 남은 길은 다음 멈춤으로 가는 길 (다른 층에 있어요)
        if from < n then
            local seg = {}
            for k = from, n do seg[#seg + 1] = pts[2 * k - 1]; seg[#seg + 1] = pts[2 * k] end
            legs[#legs + 1] = { floor = floor, pts = seg, stop = si }
        end
    end
    legCache[key] = legs
    return legs
end

-- 선 하나: 지금 갈 길 = 진한 분홍 + 테두리 + 화살표 · 앞으로 = 연한 분홍 · 지나온 길 = 흐린 회색 · 곁길 = 흰 점선 느낌
local function DrawPath(pts, style)
    local n = #pts
    if n < 4 then return end
    local main = style == "now"
    if style == "now" then
        -- C안 내비게이션 빛 선: 하늘색 빛 + 가는 흰 선 (화살표 없이 · 방향은 "다음" 꼬리표로)
        for j = 1, n - 3, 2 do Line(pts[j], pts[j + 1], pts[j + 2], pts[j + 3], 16, 0.5, 0.85, 1, 0.55, 1, true) end
        for j = 1, n - 3, 2 do Line(pts[j], pts[j + 1], pts[j + 2], pts[j + 3], 2.6, 1, 1, 1, 1, 3) end
        return
    elseif style == "later" then   -- 앞으로 갈 길: 하늘색 가는 선 (빛 없음)
        for j = 1, n - 3, 2 do Line(pts[j], pts[j + 1], pts[j + 2], pts[j + 3], 1.8, 0.56, 0.85, 1, 0.8, 0) end
    elseif style == "walked" then  -- 지나온 길: 흐린 회색
        for j = 1, n - 3, 2 do Line(pts[j], pts[j + 1], pts[j + 2], pts[j + 3], 1.4, 0.6, 0.6, 0.6, 0.45, -1) end
    else   -- 곁길: 연한 하늘색 점선 (3픽셀 선 · 5픽셀 빔)
        local on, carry = true, 0
        for j = 1, n - 3, 2 do
            local x1, y1, x2, y2 = pts[j] * MAP_W, pts[j + 1] * MAP_H, pts[j + 2] * MAP_W, pts[j + 3] * MAP_H
            local dx, dy = x2 - x1, y2 - y1
            local len = math.sqrt(dx * dx + dy * dy)
            local pos = 0
            while len > 0 and pos < len do
                local seg = math.max(0.5, (on and 3 or 5) - carry)
                local fits = pos + seg <= len
                local e = fits and (pos + seg) or len
                if on then Line((x1 + dx * pos / len) / MAP_W, (y1 + dy * pos / len) / MAP_H, (x1 + dx * e / len) / MAP_W, (y1 + dy * e / len) / MAP_H, 1.3, 0.81, 0.93, 1, 0.5, -1) end
                if fits then carry = 0; on = not on else carry = carry + (len - pos) end
                pos = e
                if not fits then break end
            end
        end
    end
    if not main then return end
    -- 화살표: 길을 따라 70픽셀마다
    local acc, STEP = 35, 70
    for j = 1, n - 3, 2 do
        local x1, y1, x2, y2 = pts[j] * MAP_W, pts[j + 1] * MAP_H, pts[j + 2] * MAP_W, pts[j + 3] * MAP_H
        local dx, dy = x2 - x1, y2 - y1
        local len = math.sqrt(dx * dx + dy * dy)
        local pos = 0
        while len > 0 and acc + (len - pos) >= STEP do
            pos = pos + (STEP - acc); acc = 0
            local f = pos / len
            local a = Tex("OVERLAY", 3, true)
            a:SetTexture(MEDIA .. "exit_glyph")
            a:SetSize(17, 17)
            a:SetPoint("CENTER", cv, "TOPLEFT", x1 + dx * f, -(y1 + dy * f))
            a:SetRotation(-math.atan2(dy, dx))
        end
        acc = acc + (len - pos)
    end
end

local function TipStop(self)
    local s = self.stop
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText((self.num and (self.num .. " · ") or "") .. Pick(s[5], s[6]), ACC[1], ACC[2], ACC[3])
    local note = Pick(s[7], s[8])
    if note and note ~= "" then GameTooltip:AddLine(note, 1, 1, 1, true) end
    if s[1] == "optional" then GameTooltip:AddLine(T("선택 · 안 잡아도 돼요"), 0.7, 0.7, 0.7)
    elseif s[1] == "rare" then GameTooltip:AddLine(T("희귀 · 있을 때만"), 0.7, 0.7, 0.7) end
    GameTooltip:AddLine(self.done and T("잡았어요 · 오른쪽 클릭 = 되돌리기") or T("오른쪽 클릭 = 잡았어요로 표시"), 0.55, 0.55, 0.55)
    GameTooltip:Show()
end

local Paint
local function ToggleDone(s)
    local run = Run(cur.key)
    local enc = s[9]
    local k = (enc and enc[1]) or ("s:" .. s[5])
    if StopDone(run, s) then
        if enc then for _, e in ipairs(enc) do run.done[e] = nil end end
        run.done["s:" .. s[5]] = nil
    else run.done[k] = true end
    Paint()
end

function Paint()
    if not V or not V:IsShown() or not cur.key then return end
    local route = D.routes[cur.key]
    local dg = Dungeon(cur.key)
    ResetPools()
    DrawArt(cur.floor)
    if route then
        for _, p in ipairs(route.side) do if p[1] == cur.floor then DrawPath(p[3], "side") end end
    end
    local run = Run(cur.key)
    if route then
        -- 구간마다: 그 멈춤을 잡았으면 지나온 길 · 아직이고 그 앞 우두머리를 다 잡았으면 지금 갈 길 · 나머지는 앞으로
        local legs = Legs(cur.key, route)
        local firstOpenBoss
        for i, s in ipairs(route.stops) do if s[1] == "boss" and not StopDone(run, s) then firstOpenBoss = i; break end end
        -- 그 우두머리로 가는 구간이 따로 없으면 (다른 멈춤 구간에 묻혔으면) 그다음 구간까지가 지금 갈 길
        if firstOpenBoss then
            local tgt
            for _, lg in ipairs(legs) do if lg.stop >= firstOpenBoss and (not tgt or lg.stop < tgt) then tgt = lg.stop end end
            firstOpenBoss = tgt or firstOpenBoss
        end
        local order = { walked = 1, later = 2, now = 3 }
        local todo = {}
        for _, lg in ipairs(legs) do
            if lg.floor == cur.floor then
                local s = route.stops[lg.stop]
                local st
                if s and StopDone(run, s) then st = "walked"
                elseif not s then st = firstOpenBoss and "later" or "walked"
                elseif firstOpenBoss and lg.stop <= firstOpenBoss then st = "now"
                else st = "later" end
                todo[#todo + 1] = { lg, st }
            end
        end
        table.sort(todo, function(a, b) return order[a[2]] < order[b[2]] end)   -- 지금 갈 길이 맨 위에
        for _, t in ipairs(todo) do DrawPath(t[1].pts, t[2]) end
    end
    local bosses = route and Bosses(route) or {}
    local nextIdx
    for i, s in ipairs(bosses) do if not StopDone(run, s) then nextIdx = i; break end end
    if route then
        -- 우두머리 번호 · 선택/희귀 점
        local bi = 0
        for _, s in ipairs(route.stops) do
            local isBoss = s[1] == "boss"
            if isBoss then bi = bi + 1 end
            if s[2] == cur.floor then
                local done = StopDone(run, s)
                local b = Pin(isBoss and 30 or 18)
                b.stop, b.num, b.done = s, isBoss and bi or nil, done
                Place(b, s[3], s[4])
                b.ring:SetVertexColor(INK[1], INK[2], INK[3], 1)
                if isBoss then
                    if done then b.bg:SetVertexColor(0.42, 0.37, 0.36, 1) else b.bg:SetVertexColor(ACC[1], ACC[2], ACC[3], 1) end
                    if done then
                        b.icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready"); b.icon:SetVertexColor(1, 1, 1, 1); b.icon:SetSize(18, 18); b.icon:SetRotation(0); b.icon:Show()
                    else
                        b.fs:SetFont(NUM, 19, ""); b.fs:SetText(tostring(bi)); b.fs:SetTextColor(0.23, 0.11, 0.14, 1)
                    end
                    if bi == nextIdx then
                        b.ring:SetVertexColor(1, 1, 1, 1)
                        b.glow:SetVertexColor(ACC[1], ACC[2], ACC[3], 0.55); b.glow:Show()
                    end
                else
                    b.bg:SetVertexColor(done and 0.42 or 0.78, done and 0.37 or 0.72, done and 0.36 or 0.95, 1)
                    b.fs:SetText("")
                end
                b:RegisterForClicks("RightButtonUp")
                b:SetScript("OnEnter", TipStop)
                b:SetScript("OnClick", function(self) ToggleDone(self.stop) end)
            end
        end
        -- 메모 (노란 !)
        for _, n in ipairs(route.notes) do
            if n[1] == cur.floor then
                local b = Pin(20)
                Place(b, n[2], n[3])
                b.ring:SetVertexColor(INK[1], INK[2], INK[3], 1)
                b.bg:SetVertexColor(1, 0.82, 0.35, 1)
                b.fs:SetFont(FontOf(), 13, ""); b.fs:SetText("!"); b.fs:SetTextColor(0.23, 0.16, 0.06, 1)
                b.text = Pick(n[4], n[5])
                b:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(T("메모"), 1, 0.82, 0.35)
                    GameTooltip:AddLine(self.text, 1, 1, 1, true); GameTooltip:Show()
                end)
            end
        end
        -- 계단 · 층 잇기 (누르면 그 층으로)
        for _, l in ipairs(route.links) do
            if l[1] == cur.floor then
                local b = Pin(22)
                Place(b, l[2], l[3])
                b.ring:SetVertexColor(INK[1], INK[2], INK[3], 1)
                b.bg:SetVertexColor(0.62, 0.89, 0.75, 1)
                local up = l[5] == "^"
                b.icon:SetTexture(MEDIA .. "exit_glyph"); b.icon:SetSize(15, 15); b.icon:SetVertexColor(1, 1, 1, 1)
                b.icon:SetRotation(up and (math.pi / 2) or (-math.pi / 2)); b.icon:Show()
                b.to = l[4]
                b:RegisterForClicks("LeftButtonUp")
                b:SetScript("OnEnter", function(self)
                    local fi = D.floors[self.to]
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(T(up and "위층으로" or "아래층으로"), 0.62, 0.89, 0.75)
                    if fi then GameTooltip:AddLine(Pick(fi.ko, fi.en), 1, 1, 1) end
                    GameTooltip:AddLine(T("누르면 그 층 지도"), 0.55, 0.55, 0.55); GameTooltip:Show()
                end)
                b:SetScript("OnClick", function(self) cur.floor = self.to; Paint() end)
            end
        end
    end
    -- 여기 (게임이 알려주는 방)
    local here = RoomHere(cur.key)
    if here and here.floor == cur.floor then
        local b = Pin(16)
        Place(b, here.u, here.v)
        b.bg:SetVertexColor(1, 0.84, 0.36, 1); b.ring:SetVertexColor(INK[1], INK[2], INK[3], 1)
        b.glow:SetVertexColor(1, 0.84, 0.36, 0.5); b.glow:Show()
        b.fs:SetText("")
        b.name = here.name
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(T("여기 (대략)"), 1, 0.84, 0.36)
            GameTooltip:AddLine(self.name, 1, 1, 1); GameTooltip:Show()
        end)
    end
    -- C안: 다음 우두머리 옆에 분홍 꼬리표 · 입구에 "출발" · 왼쪽 위 작은 진행 칩
    V.tag:Hide(); V.start:Hide()
    local s = nextIdx and bosses[nextIdx]
    if s and s[2] == cur.floor then
        V.tag.fs:SetText(T("다음") .. " · " .. Pick(s[5], s[6]))
        V.tag:SetWidth(V.tag.fs:GetStringWidth() + 26)
        V.tag:ClearAllPoints()
        if s[3] > 0.72 then V.tag:SetPoint("RIGHT", cv, "TOPLEFT", s[3] * MAP_W - 24, -s[4] * MAP_H)
        else V.tag:SetPoint("LEFT", cv, "TOPLEFT", s[3] * MAP_W + 24, -s[4] * MAP_H) end
        V.tag.stop, V.tag.num = s, nextIdx
        V.tag:Show()
    end
    local m1 = route and route.main[1]
    if m1 and m1[1] == cur.floor and #m1[4] >= 2 and not (nextIdx and nextIdx > 1) then
        V.start:ClearAllPoints(); V.start:SetPoint("TOP", cv, "TOPLEFT", m1[4][1] * MAP_W, -m1[4][2] * MAP_H - 14)
        V.start:Show()
    end
    local chip = V.pill
    if s and s[2] ~= cur.floor then
        local fl = D.floors[s[2]]
        chip.fs:SetText((nextIdx - 1) .. "/" .. #bosses .. "   |cffa99692" .. T("다음") .. "|r " .. Pick(s[5], s[6])
            .. (fl and ("  |cff9fe3c0(" .. Pick(fl.ko, fl.en) .. ")|r") or ""))
    elseif s then chip.fs:SetText((nextIdx - 1) .. "/" .. #bosses)
    elseif #bosses > 0 then chip.fs:SetText("|cff9fe3c0" .. #bosses .. "/" .. #bosses .. "  " .. T("다 잡았어요") .. "|r")
    else chip.fs:SetText(Pick(dg.ko, dg.en)) end
    chip.stop, chip.num = s, nextIdx
    chip:SetWidth(chip.fs:GetStringWidth() + 46)
    -- 층 단추
    for i, b in ipairs(V.floorBtns) do b:Hide() end
    if dg and #dg.floors > 1 then
        for i, f in ipairs(dg.floors) do
            local b = V.floorBtns[i]
            if not b then
                b = CreateFrame("Button", nil, V)
                b:SetSize(56, 22)
                b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetTexture(MEDIA .. "pill22")
                b.fs = MakeFS(b, 12); b.fs:SetPoint("CENTER")
                b:SetScript("OnLeave", function() GameTooltip:Hide() end)
                V.floorBtns[i] = b
            end
            b:SetFrameLevel(V:GetFrameLevel() + 20)
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", V, "TOPLEFT", 12, -48 - (i - 1) * 26)
            b.fs:SetText(i .. T("층"))
            local on = f == cur.floor
            if on then b.bg:SetVertexColor(ACC[1], ACC[2], ACC[3], 1); b.fs:SetTextColor(0.23, 0.11, 0.14)
            else b.bg:SetVertexColor(0.2, 0.15, 0.14, 0.95); b.fs:SetTextColor(0.85, 0.78, 0.76) end
            b.floor = f
            b:SetScript("OnClick", function(self) cur.floor = self.floor; Paint() end)
            b:SetScript("OnEnter", function(self)
                local fi = D.floors[self.floor]
                if fi then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(Pick(fi.ko, fi.en)); GameTooltip:Show() end
            end)
            b:Show()
        end
    end
end

-- 크기 맞추기 (지도 칸에 꽉 · 비율 그대로)
local function Fit()
    if not V then return end
    local w, h = V:GetWidth(), V:GetHeight()
    if not w or w < 10 or not h or h < 10 then return end
    local s = math.min(w / MAP_W, h / MAP_H)
    cv:SetScale(s)
    cv:ClearAllPoints(); cv:SetPoint("CENTER", V, "CENTER", 0, 0)
end

local function Build()
    local wm = WorldMapFrame
    local sc = wm.ScrollContainer
    V = CreateFrame("Frame", "LeelMap_DungeonView", wm)
    V:SetAllPoints(sc)
    V:SetFrameLevel(sc:GetFrameLevel() + 40)
    V:EnableMouse(true)
    V.bg = V:CreateTexture(nil, "BACKGROUND", nil, -8); V.bg:SetAllPoints(); V.bg:SetColorTexture(0.06, 0.045, 0.04, 1)
    cv = CreateFrame("Frame", nil, V); cv:SetSize(MAP_W, MAP_H)
    V.lineLayer = CreateFrame("Frame", nil, cv); V.lineLayer:SetAllPoints(cv); V.lineLayer:SetFrameLevel(cv:GetFrameLevel() + 2)
    V.arrowLayer = CreateFrame("Frame", nil, cv); V.arrowLayer:SetAllPoints(cv); V.arrowLayer:SetFrameLevel(cv:GetFrameLevel() + 4)
    V.pinLayer = CreateFrame("Frame", nil, cv); V.pinLayer:SetAllPoints(cv); V.pinLayer:SetFrameLevel(cv:GetFrameLevel() + 6)
    V.noArt = MakeFS(cv, 16, { 0.6, 0.55, 0.53 }); V.noArt:SetPoint("CENTER")
    V.noArt:SetText(T("이 층은 게임에 지도 그림이 없어요 · 경로만 보여줘요"))
    -- 왼쪽 위: 작은 진행 칩 (몇 마리 잡았나 · 다음이 다른 층이면 그 이름) + 끄기
    local pill = CreateFrame("Button", nil, V)
    pill:SetHeight(26); pill:SetPoint("TOPLEFT", V, "TOPLEFT", 12, -10); pill:SetFrameLevel(V:GetFrameLevel() + 20)
    pill.bg = pill:CreateTexture(nil, "BACKGROUND"); pill.bg:SetAllPoints(); pill.bg:SetTexture(MEDIA .. "pill22")
    pill.bg:SetVertexColor(0.1, 0.075, 0.07, 0.92)
    pill.ic = pill:CreateTexture(nil, "ARTWORK"); pill.ic:SetTexture(MEDIA .. "icon"); pill.ic:SetSize(18, 18); pill.ic:SetPoint("LEFT", 6, 0)
    pill.fs = MakeFS(pill, 13, ACC); pill.fs:SetPoint("LEFT", pill.ic, "RIGHT", 6, 0)
    pill:SetScript("OnEnter", function(self)
        local dg = Dungeon(cur.key)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText(dg and Pick(dg.ko, dg.en) or "", ACC[1], ACC[2], ACC[3])
        local s = self.stop
        if s then
            GameTooltip:AddLine(T("다음") .. " · " .. self.num .. " " .. Pick(s[5], s[6]), 1, 1, 1)
            local note = Pick(s[7], s[8]); if note and note ~= "" then GameTooltip:AddLine(note, 0.85, 0.85, 0.85, true) end
            if s[2] ~= cur.floor then GameTooltip:AddLine(T("누르면 그 층 지도"), 0.55, 0.55, 0.55) end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(T("경로 데이터: Forever Dungeon Routes (Checkov23, MIT)"), 0.45, 0.45, 0.45)
        GameTooltip:Show()
    end)
    pill:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pill:SetScript("OnClick", function(self) if self.stop then cur.floor = self.stop[2]; Paint() end end)
    V.pill = pill
    local off = CreateFrame("Button", nil, V)
    off:SetSize(26, 26); off:SetPoint("LEFT", pill, "RIGHT", 6, 0); off:SetFrameLevel(V:GetFrameLevel() + 20)
    off.bg = off:CreateTexture(nil, "BACKGROUND"); off.bg:SetAllPoints(); off.bg:SetTexture(MEDIA .. "circle")
    off.bg:SetVertexColor(0.1, 0.075, 0.07, 0.92)
    off.ic = off:CreateTexture(nil, "ARTWORK"); off.ic:SetTexture(MEDIA .. "ic_x"); off.ic:SetSize(14, 14); off.ic:SetPoint("CENTER")
    off.ic:SetVertexColor(0.85, 0.78, 0.76)
    off:SetScript("OnClick", function() hiddenByUser = true; V:Hide() end)
    off:SetScript("OnEnter", function(self)
        self.ic:SetVertexColor(ACC[1], ACC[2], ACC[3])
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT"); GameTooltip:SetText(T("경로 지도 끄기"))
        GameTooltip:AddLine(T("지도를 다시 열면 또 떠요 · 아예 끄기는 허브 > 지도"), 0.7, 0.7, 0.7, true); GameTooltip:Show()
    end)
    off:SetScript("OnLeave", function(self) self.ic:SetVertexColor(0.85, 0.78, 0.76); GameTooltip:Hide() end)
    -- 다음 우두머리 옆 분홍 꼬리표 (지도 위 · 지도와 같이 커지고 작아져요)
    local tag = CreateFrame("Button", nil, V.pinLayer)
    tag:SetHeight(28); tag:SetFrameLevel(V.pinLayer:GetFrameLevel() + 8)
    tag.bg = tag:CreateTexture(nil, "BACKGROUND"); tag.bg:SetAllPoints(); tag.bg:SetTexture(MEDIA .. "pill22")
    tag.bg:SetVertexColor(ACC[1], ACC[2], ACC[3], 1)
    tag.sh = tag:CreateTexture(nil, "BACKGROUND", nil, -1); tag.sh:SetTexture(MEDIA .. "pill22")
    tag.sh:SetPoint("TOPLEFT", -2, 2); tag.sh:SetPoint("BOTTOMRIGHT", 2, -3); tag.sh:SetVertexColor(INK[1], INK[2], INK[3], 0.8)
    tag.fs = tag:CreateFontString(nil, "OVERLAY"); tag.fs:SetFont(FontOf(), 15, ""); tag.fs:SetPoint("CENTER", 0, 0)
    tag.fs:SetTextColor(0.23, 0.11, 0.14)
    tag:SetScript("OnEnter", function(self) TipStop(self) end)
    tag:RegisterForClicks("RightButtonUp")
    tag:SetScript("OnClick", function(self) if self.stop then ToggleDone(self.stop) end end)
    tag:SetScript("OnLeave", function() GameTooltip:Hide() end)
    V.tag = tag
    -- 입구 "출발"
    local start = CreateFrame("Frame", nil, V.pinLayer)
    start:SetSize(48, 22); start:SetFrameLevel(V.pinLayer:GetFrameLevel() + 7)
    start.bg = start:CreateTexture(nil, "BACKGROUND"); start.bg:SetAllPoints(); start.bg:SetTexture(MEDIA .. "pill22")
    start.bg:SetVertexColor(INK[1], INK[2], INK[3], 0.9)
    start.fs = start:CreateFontString(nil, "OVERLAY"); start.fs:SetFont(FontOf(), 13, ""); start.fs:SetPoint("CENTER")
    start.fs:SetTextColor(1, 1, 1); start.fs:SetText(T("출발"))
    start:SetWidth(start.fs:GetStringWidth() + 20)
    V.start = start
    -- 아래 가운데 범례 한 줄
    local lg = CreateFrame("Frame", nil, V)
    lg:SetHeight(24); lg:SetPoint("BOTTOM", V, "BOTTOM", 0, 10); lg:SetFrameLevel(V:GetFrameLevel() + 20)
    lg.bg = lg:CreateTexture(nil, "BACKGROUND"); lg.bg:SetAllPoints(); lg.bg:SetTexture(MEDIA .. "pill22")
    lg.bg:SetVertexColor(0.1, 0.075, 0.07, 0.85)
    local x = 12
    local items = {
        { ACC, "우두머리" }, { { 0.78, 0.72, 0.95 }, "선택 · 희귀" }, { { 1, 0.82, 0.35 }, "메모" },
        { { 0.62, 0.89, 0.75 }, "계단" }, { { 1, 0.84, 0.36 }, "여기" },
    }
    for _, it in ipairs(items) do
        local d = lg:CreateTexture(nil, "ARTWORK"); d:SetTexture(MEDIA .. "circle"); d:SetSize(10, 10)
        d:SetVertexColor(it[1][1], it[1][2], it[1][3], 1); d:SetPoint("LEFT", lg, "LEFT", x, 0)
        local f = MakeFS(lg, 11.5, { 0.85, 0.78, 0.76 }); f:SetPoint("LEFT", d, "RIGHT", 4, 0); f:SetText(T(it[2]))
        x = x + 14 + f:GetStringWidth() + 12
    end
    local ln = lg:CreateTexture(nil, "ARTWORK"); ln:SetColorTexture(ACC[1], ACC[2], ACC[3], 1); ln:SetSize(16, 4); ln:SetPoint("LEFT", lg, "LEFT", x, 0)
    local lf = MakeFS(lg, 11.5, ACC); lf:SetPoint("LEFT", ln, "RIGHT", 5, 0); lf:SetText(T("지금 갈 길"))
    x = x + 21 + lf:GetStringWidth() + 12
    lg:SetWidth(x)
    V.legend = lg
    V.floorBtns = {}
    V:SetScript("OnSizeChanged", Fit)
    V:SetScript("OnShow", function() Fit(); Paint() end)
    V:Hide()
end

-- 지도를 열 때 · 바뀔 때
local function Update(opening)
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
    local db = DB()
    if db.droute == false then if V then V:Hide() end return end
    local key = CurrentKey() or previewKey or seenKey
    if not key or not Data() or not D.routes[key] then if V then V:Hide() end return end
    if opening and key == previewKey and key ~= CurrentKey() then opening = false end
    if opening then
        hiddenByUser = false
        openMapID = WorldMapFrame:GetMapID()
        -- 층: 방 이름 > 게임 지도 번호 > 다음 우두머리 층 > 첫 층
        local dg = Dungeon(key)
        local floor
        local here = RoomHere(key)
        if here then floor = here.floor end
        if not floor then
            local mid = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
            if mid and not (issecretvalue and issecretvalue(mid)) and InList(dg.floors, mid) then floor = mid end
        end
        if not floor then
            local run = Run(key)
            for _, s in ipairs(Bosses(D.routes[key])) do if not StopDone(run, s) then floor = s[2]; break end end
        end
        cur.key, cur.floor = key, floor or dg.floors[1]
    end
    if hiddenByUser then return end
    if not V then Build() end
    cur.key = key
    if not cur.floor then cur.floor = Dungeon(key).floors[1] end
    V:Show(); Fit(); Paint()
end
ns.DungeonUpdate = Update

-- 던전 밖에서 던전 지도를 볼 때: 게임 지도가 던전 층으로 바뀌었거나 OpenMap 이 던전 지도를 띄우면 → 그 던전 경로
local function NameKey(nm)
    if type(nm) ~= "string" or nm == "" or not Data() then return end
    nm = nm:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")
    for _, d in ipairs(D.dungeons) do if d.ko == nm or d.en == nm then return d.key end end
end
local function FloorKey(mid)
    if not mid or not Data() then return end
    for _, d in ipairs(D.dungeons) do if InList(d.floors, mid) then return d.key, mid end end
end
-- OpenMap 이 필드에서 던전 입구를 눌렀을 때 띄우는 작은 카드 ("통곡의 동굴  15-24") 찾기
local omCard
local function FindCard()
    if omCard then return omCard end
    for _, c in ipairs({ WorldMapFrame:GetChildren() }) do
        if type(c) == "table" and c.title and c.close and c.back and c.title.GetText then omCard = c; return c end
    end
end
local function CardKey()
    local c = FindCard()
    if not (c and c:IsVisible() and c.close:IsShown()) then return end
    local t = c.title:GetText()
    if type(t) ~= "string" then return end
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    for part in (t .. ","):gmatch("([^,]+),") do
        local nm = part:gsub("%s+%d+%s*%-%s*%d+%s*$", "")
        local k = NameKey(nm)
        if k then return k end
    end
end
local watch = CreateFrame("Frame")
local wt = 0
watch:SetScript("OnUpdate", function(_, el)
    wt = wt + el
    if wt < 0.3 then return end
    wt = 0
    if not WorldMapFrame or not WorldMapFrame:IsShown() or CurrentKey() or previewKey then return end
    if DB().droute == false then return end
    local key, floor
    local omv = _G.OpenMapDungeonView
    if omv and omv:IsVisible() and omv.where and omv.where.GetText then key = NameKey(omv.where:GetText()) end
    if not key then key, floor = FloorKey(WorldMapFrame:GetMapID()) end
    if not key then key = CardKey() end
    if key ~= seenKey then
        seenKey = key
        if key and D.routes[key] then
            hiddenByUser = false
            if not V then Build() end
            cur.key, cur.floor = key, floor or Dungeon(key).floors[1]
            openMapID = nil
            V:Show(); Fit(); Paint()
        elseif V and V:IsShown() then
            V:Hide()
        end
    elseif key and floor and V and V:IsShown() and cur.floor ~= floor then
        cur.floor = floor; Paint()
    end
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ENCOUNTER_END")
ev:RegisterEvent("BOSS_KILL")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_INDOORS")
ev:RegisterEvent("ZONE_CHANGED")
ev:SetScript("OnEvent", function(_, e, a1, _, _, _, a5)
    if e == "PLAYER_LOGIN" then
        if ns.ApplyOpenMapDungeons then ns.ApplyOpenMapDungeons() end
        if WorldMapFrame then
            WorldMapFrame:HookScript("OnShow", function() C_Timer.After(0, function() Update(true) end) end)
            WorldMapFrame:HookScript("OnHide", function() previewKey = nil; seenKey = nil; if V then V:Hide() end end)
            -- 다른 지역으로 넘겨 보면 경로 지도는 비켜요 (다시 열면 또 떠요)
            hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
                if V and V:IsShown() and openMapID and WorldMapFrame:GetMapID() ~= openMapID then V:Hide(); hiddenByUser = true end
            end)
        end
    elseif e == "ENCOUNTER_END" or e == "BOSS_KILL" then
        local id = a1
        local ok = (e == "BOSS_KILL") or (a5 == 1)
        if not ok or not id or (issecretvalue and issecretvalue(id)) then return end
        local key = CurrentKey()
        if not key then return end
        local run = Run(key)
        run.done[id] = true; run.t = time()
        if V and V:IsShown() then Paint() end
    elseif e == "PLAYER_ENTERING_WORLD" then
        -- 다른 던전에 들어가거나 오래 지나면 새 판
        local key = CurrentKey()
        if key then
            local r = DB().drun
            if r and (r.key ~= key or (time() - (r.t or 0)) > 3 * 3600) then DB().drun = nil end
            Run(key).t = time()
        end
    else
        if V and V:IsShown() then Paint() end
    end
end)

-- OpenMap 던전 지도 끄기 (르엘 경로 지도만 쓰기) · 허브 > 지도 에서 다시 켤 수 있어요
--   OpenMap 의 설정 "Dungeon maps" (OpenMapDB.worldmap.dungeonMaps) 를 그대로 바꿔요
function ns.ApplyOpenMapDungeons()
    local om = _G.OpenMapDB and _G.OpenMapDB.worldmap
    if not om then return end
    local off = DB().omDungeonOff ~= false
    if off then om.dungeonMaps = false
    elseif DB().omDungeonTouched then om.dungeonMaps = true end
    DB().omDungeonTouched = true
    -- 지금 떠 있는 OpenMap 던전 지도도 닫아요
    if off and _G.OpenMapDungeonView and _G.OpenMapDungeonView:IsShown() then pcall(_G.OpenMapDungeonView.Hide, _G.OpenMapDungeonView) end
end
_G.LeelMap_ApplyOpenMapDungeons = ns.ApplyOpenMapDungeons

-- 허브 미리 보기 · 슬래시: /lmap 던전 (던전 밖에서도 아무 던전이나)
function ns.DungeonPreview(key)
    if not Data() then return end
    key = key or "deadmines"
    previewKey = key
    if not WorldMapFrame:IsShown() then ToggleWorldMap() end
    if not V then Build() end
    cur.key, cur.floor = key, Dungeon(key).floors[1]
    hiddenByUser = false
    openMapID = WorldMapFrame:GetMapID()
    V:Show(); Fit(); Paint()
end
_G.LeelMap_DungeonPreview = ns.DungeonPreview
