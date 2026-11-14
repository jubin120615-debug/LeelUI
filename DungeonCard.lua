-- LeelUI / DungeonCard.lua
-- 던전 속 나: Forever Dungeon Routes(FDR)가 깔려 있으면, 던전에서 르엘 미니맵 왼쪽에 "층 지도 카드".
--   던전 안에선 게임이 애드온에 좌표를 안 줘요 → 게임이 알려주는 "방" 단위로 (FDR의 방 자료)
--   카드 = 던전 전체에서 지금 어느 방 · 길 · 우두머리 진행 · 다음 할 일 · 파티원 방
--   [⤢] = 미니맵을 크게 (게임이 그리는 미니맵이라 방 안에서도 내 위치가 정확해요)
-- 그림: 게임 지도 그림(12조각) 또는 게임 미니맵 그림만 써요. FDR maps 폴더의 그림(Santiago Reyes)은
-- FDR에만 허락된 그림이라 안 써요 → 그런 층은 게임 방 자료로 평면도를 그려요.
local ADDON, ns = ...
local C = ns.C

local DR
local card, smallBtn
local MAPW, MAPH, TILE = 1002, 668, 256
local CW, MH = 212, 112          -- 카드 너비 · 지도 칸 높이
local ZOOM = 0.42                -- 카드 지도 배율 (층 지도 1002x668 → 421x281)
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function On() return ns.db and ns.db.fdrCard ~= false end
local function Font(p, s, c) return ns.Font(p, s, c) end
local function Safe(v) if DR and DR.Safe then return DR.Safe(v) end return v end

local cur = { key = nil, floor = nil, sig = nil }
local Pulse   -- 아래에서 만들어요
local dirty = true

----------------------------------------------------------------------
-- 만들기
----------------------------------------------------------------------
local function Pool(list, make)
    local n = 0
    return function()
        n = n + 1
        local o = list[n]
        if not o then o = make(); list[n] = o end
        o:Show()
        return o
    end, function()
        for i = n + 1, #list do list[i]:Hide() end
        n = 0
    end, function() return n end
end

local function Build()
    card = CreateFrame("Button", "LeelUI_DungeonCard", UIParent)
    card:SetSize(CW, 200)
    card:SetFrameStrata("MEDIUM")
    card:SetClampedToScreen(true)
    card:RegisterForClicks("LeftButtonUp")
    ns.RoundPlate(card, 12, { 0.094, 0.07, 0.075, 0.95 }, { C.acc[1], C.acc[2], C.acc[3], 0.9 })

    card.title = Font(card, 12.5, C.tx); card.title:SetPoint("TOPLEFT", 11, -9)
    card.title:SetJustifyH("LEFT"); card.title:SetWordWrap(false); card.title:SetWidth(CW - 70)
    card.pips = {}
    for i = 1, 6 do
        local p = card:CreateTexture(nil, "ARTWORK"); p:SetTexture(ns.MEDIA .. "circle"); p:SetSize(6, 6)
        card.pips[i] = p
    end
    -- [⤢] 미니맵 크게
    local bb = CreateFrame("Button", nil, card); bb:SetSize(20, 20); bb:SetPoint("TOPRIGHT", -6, -5)
    local bo = bb:CreateTexture(nil, "BACKGROUND"); bo:SetTexture(ns.MEDIA .. "circle"); bo:SetAllPoints(); bo:SetVertexColor(0.24, 0.18, 0.19, 1)
    local bi = bb:CreateTexture(nil, "ARTWORK"); bi:SetTexture(ns.MEDIA .. "hb_scale"); bi:SetSize(11, 11); bi:SetPoint("CENTER")
    bi:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    local bh = bb:CreateTexture(nil, "HIGHLIGHT"); bh:SetTexture(ns.MEDIA .. "circle"); bh:SetAllPoints(); bh:SetVertexColor(1, 1, 1, 0.2); bh:SetBlendMode("ADD")
    bb:SetScript("OnClick", function() ns.DungeonBig(true) end)
    bb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText("미니맵 크게")
        GameTooltip:AddLine("미니맵을 2배로 · 가장 멀리 보기. 방 안에서 내 위치는 미니맵이 정확해요", 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    bb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    card.bigBtn = bb

    card.prog = Font(card, 10.5, { 0.72, 0.64, 0.61 }); card.prog:SetPoint("TOPLEFT", 11, -27)
    card.prog:SetJustifyH("LEFT")
    local barBg = card:CreateTexture(nil, "ARTWORK"); barBg:SetTexture(WHITE)
    barBg:SetPoint("TOPLEFT", 11, -43); barBg:SetSize(CW - 22, 3); barBg:SetVertexColor(0.23, 0.17, 0.18, 1)
    card.barFill = card:CreateTexture(nil, "ARTWORK", nil, 1); card.barFill:SetTexture(WHITE)
    card.barFill:SetPoint("TOPLEFT", barBg, "TOPLEFT"); card.barFill:SetHeight(3); card.barFill:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    card.barW = CW - 22

    -- 지도 칸
    local clip = CreateFrame("Frame", nil, card)
    clip:SetPoint("TOPLEFT", 1, -52); clip:SetSize(CW - 2, MH)
    clip:SetClipsChildren(true)
    local cbg = clip:CreateTexture(nil, "BACKGROUND", nil, -8); cbg:SetAllPoints(); cbg:SetColorTexture(0.06, 0.05, 0.05, 1)
    card.clip = clip
    local cv = CreateFrame("Frame", nil, clip); cv:SetSize(MAPW * ZOOM, MAPH * ZOOM); cv:SetPoint("TOPLEFT")
    card.canvas = cv
    card.tiles = {}
    for i = 1, 12 do
        local row, col = math.floor((i - 1) / 4), (i - 1) % 4
        local w, h = math.min(TILE, MAPW - col * TILE), math.min(TILE, MAPH - row * TILE)
        local t = cv:CreateTexture(nil, "BACKGROUND", nil, 0)
        t:SetSize(w * ZOOM, h * ZOOM); t:SetPoint("TOPLEFT", col * TILE * ZOOM, -row * TILE * ZOOM)
        t:SetTexCoord(0, w / TILE, 0, h / TILE); t:Hide()
        card.tiles[i] = t
    end
    local shade = cv:CreateTexture(nil, "BACKGROUND", nil, 6); shade:SetAllPoints(); shade:SetColorTexture(0.08, 0.05, 0.06, 0.28)
    card.mt, card.rm, card.dt, card.pn, card.pm = {}, {}, {}, {}, {}
    card.nextMT, card.endMT = Pool(card.mt, function() return cv:CreateTexture(nil, "BACKGROUND", nil, 1) end)
    card.nextRM, card.endRM = Pool(card.rm, function() local t = cv:CreateTexture(nil, "ARTWORK", nil, 0); t:SetTexture(WHITE); return t end)
    card.nextDT, card.endDT = Pool(card.dt, function()
        local t = cv:CreateTexture(nil, "ARTWORK", nil, 3); t:SetTexture(ns.MEDIA .. "circle"); t:SetSize(3.5, 3.5); return t
    end)
    card.nextPN, card.endPN = Pool(card.pn, function()
        local f = CreateFrame("Frame", nil, cv); f:SetSize(14, 14); f:SetFrameLevel(cv:GetFrameLevel() + 3)
        f.o = f:CreateTexture(nil, "ARTWORK", nil, 0); f.o:SetTexture(ns.MEDIA .. "circle"); f.o:SetPoint("TOPLEFT", -1.5, 1.5); f.o:SetPoint("BOTTOMRIGHT", 1.5, -1.5); f.o:SetVertexColor(0.08, 0.06, 0.06, 1)
        f.b = f:CreateTexture(nil, "ARTWORK", nil, 1); f.b:SetTexture(ns.MEDIA .. "circle"); f.b:SetAllPoints()
        f.t = f:CreateFontString(nil, "OVERLAY"); f.t:SetFont(ns.NUM or ns.FONT, 10, ""); f.t:SetPoint("CENTER", 0.5, 0)
        return f
    end)
    card.ln = {}
    card.nextLN, card.endLN = Pool(card.ln, function() local t = cv:CreateTexture(nil, "ARTWORK", nil, 4); t:SetTexture(WHITE); return t end)
    card.nextPM, card.endPM = Pool(card.pm, function()
        local t = cv:CreateTexture(nil, "OVERLAY", nil, 2); t:SetTexture(ns.MEDIA .. "circle"); t:SetSize(8, 8); return t
    end)
    -- 내 위치 (게임이 알려주는 던전에서만: 밖이 트인 새 던전 일부)
    local me = CreateFrame("Frame", nil, cv); me:SetSize(12, 12); me:SetFrameLevel(cv:GetFrameLevel() + 5)
    local mo = me:CreateTexture(nil, "ARTWORK"); mo:SetTexture(ns.MEDIA .. "circle"); mo:SetAllPoints(); mo:SetVertexColor(1, 1, 1, 1)
    local mi = me:CreateTexture(nil, "ARTWORK", nil, 1); mi:SetTexture(ns.MEDIA .. "circle"); mi:SetPoint("TOPLEFT", 2, -2); mi:SetPoint("BOTTOMRIGHT", -2, 2)
    mi:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    me:Hide(); card.me = me
    -- 좌표가 없을 때: 지금 방 가운데에 토끼 (이 방 안 어딘가)
    local rb = CreateFrame("Frame", nil, cv); rb:SetSize(20, 20); rb:SetFrameLevel(cv:GetFrameLevel() + 6)
    local ro = rb:CreateTexture(nil, "ARTWORK"); ro:SetTexture(ns.MEDIA .. "circle"); ro:SetPoint("TOPLEFT", -1.5, 1.5); ro:SetPoint("BOTTOMRIGHT", 1.5, -1.5); ro:SetVertexColor(1, 1, 1, 1)
    local rf = rb:CreateTexture(nil, "ARTWORK", nil, 1); rf:SetTexture(ns.MEDIA .. "circle"); rf:SetAllPoints(); rf:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    local ri = rb:CreateTexture(nil, "ARTWORK", nil, 2); ri:SetTexture(ns.MEDIA .. "bunny"); ri:SetAllPoints()
    local rr = rb:CreateTexture(nil, "BACKGROUND"); rr:SetTexture(ns.MEDIA .. "ring"); rr:SetPoint("CENTER"); rr:SetSize(34, 34); rr:SetVertexColor(1, 1, 1, 0.7)
    rb.ring = rr
    rb:Hide(); card.roomMe = rb
    -- 그림이 없는 층: 안내
    card.noArt = Font(clip, 10, { 0.6, 0.53, 0.51 }); card.noArt:SetPoint("BOTTOMRIGHT", -5, 3)
    card.noArt:SetText("게임 방 자료로 그린 평면도")

    -- 아래 글
    card.nextT = Font(card, 11, { 0.88, 0.8, 0.78 }); card.nextT:SetJustifyH("LEFT"); card.nextT:SetWordWrap(false); card.nextT:SetWidth(CW - 22)
    card.memo = Font(card, 10.5, { 0.92, 0.86, 0.84 }); card.memo:SetJustifyH("LEFT"); card.memo:SetWidth(CW - 34)
    if card.memo.SetMaxLines then card.memo:SetMaxLines(2) end
    card.memoBar = card:CreateTexture(nil, "ARTWORK"); card.memoBar:SetTexture(WHITE); card.memoBar:SetWidth(2); card.memoBar:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    card.party = Font(card, 10, { 0.66, 0.58, 0.56 }); card.party:SetJustifyH("LEFT"); card.party:SetWidth(CW - 22)
    if card.party.SetMaxLines then card.party:SetMaxLines(2) end

    local pa = 0
    card:SetScript("OnUpdate", function(_, el) pa = pa + el; if pa > 0.05 then pa = 0; Pulse() end end)
    card:SetScript("OnClick", function()
        if DR and DR.Window and cur.key then pcall(DR.Window.Open, DR.Window, cur.key, cur.floor) end
    end)
    card:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText("던전 층 지도")
        GameTooltip:AddLine("분홍 = 지금 있는 방 · 점선 = FDR 길 · 노랑 = 다음 우두머리", 0.85, 0.85, 0.85, true)
        GameTooltip:AddLine("클릭: FDR 큰 지도 · ⤢: 미니맵 크게", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function() GameTooltip:Hide() end)
    card:Hide()

    -- 크게 볼 때: 미니맵 위 [작게] 알약
    smallBtn = CreateFrame("Button", nil, UIParent)
    smallBtn:SetSize(64, 22); smallBtn:SetFrameStrata("HIGH")
    ns.RoundPlate(smallBtn, 11, { 0.07, 0.05, 0.055, 0.95 }, { C.acc[1], C.acc[2], C.acc[3], 1 })
    local st = Font(smallBtn, 11.5, C.tx); st:SetPoint("CENTER"); st:SetText("작게 보기")
    smallBtn:SetScript("OnClick", function() ns.DungeonBig(false) end)
    smallBtn:Hide()
end

----------------------------------------------------------------------
-- 그리기
----------------------------------------------------------------------
local function ClassOf(name)
    for i = 1, 4 do
        local u = "party" .. i
        local n = Safe(UnitName(u))
        if n and name and (n == name or name:match("^" .. n)) then
            local _, cls = UnitClass(u); cls = Safe(cls)
            local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
            if c then return c.r, c.g, c.b end
        end
    end
    return 0.55, 0.78, 1
end

local function RoomName(key, en)
    for _, room in ipairs(DR.Rooms and DR.Rooms[key] or {}) do
        if room.name == en then return DR.LocText(room, "name") end
    end
    return en
end

local function ChooseFloor(key, route)
    local dungeon = DR:GetDungeon(key)
    local _, f = DR:LocatePlayer(cur.floor)
    if f then return f end
    local room = DR.Room and DR.Room:Get()
    if room then
        if cur.floor and DR.Room:OnFloor(room, cur.floor) then return cur.floor end
        return DR.Room:MainFloor(room)
    end
    if cur.key == key and cur.floor then return cur.floor end
    local ni = DR:GetNextStopIndex(key, route)
    if ni and route.stops[ni] and route.stops[ni].floor then return route.stops[ni].floor end
    return DR:GetRouteStartFloor(route) or (dungeon and dungeon.floors and dungeon.floors[1])
end

local function DrawStatic(key, route, floor)
    local info = DR.Floors and DR.Floors[floor]
    local art = info and info.tiles and #info.tiles == 12 and not info.image
    for i, t in ipairs(card.tiles) do
        if art then t:SetTexture(info.tiles[i], nil, nil, "TRILINEAR"); t:Show() else t:Hide() end
    end
    local mm = (not art) and DR.MinimapArt and DR.MinimapArt[floor]
    if mm then
        for _, part in ipairs(mm) do
            local t = card.nextMT()
            t:SetTexture(part[1], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "TRILINEAR")
            t:SetTexCoord(part[6], part[7], part[8], part[9], part[10], part[11], part[12], part[13])
            t:SetDrawLayer("BACKGROUND", math.min(5, 1 + (part[14] or 0)))
            t:SetSize(part[4] * ZOOM, part[5] * ZOOM)
            t:ClearAllPoints(); t:SetPoint("TOPLEFT", card.canvas, "TOPLEFT", part[2] * ZOOM, -part[3] * ZOOM)
        end
    end
    card.endMT()
    card.schematic = not art and not mm
    card.noArt:SetShown(card.schematic)

    -- 방: 지금 방은 분홍, 그림이 없으면 모든 방을 어두운 칸으로 (평면도)
    local room = DR.Room and DR.Room:Get()
    local curBoxes = {}
    for _, r in ipairs(DR.Rooms and DR.Rooms[key] or {}) do
        local isCur = (r == room)
        if isCur or card.schematic then
            for _, box in ipairs(r.boxes or {}) do
                if box[1] == floor then
                    local t = card.nextRM()
                    t:SetSize(math.max(2, box[4] * ZOOM), math.max(2, box[5] * ZOOM))
                    t:ClearAllPoints(); t:SetPoint("CENTER", card.canvas, "TOPLEFT", box[2] * MAPW * ZOOM, -box[3] * MAPH * ZOOM)
                    pcall(t.SetRotation, t, -(box[6] or 0))
                    if isCur then
                        -- 지금 방: 안은 아주 살짝 + 바깥 둘레만 반짝이는 테두리
                        t:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1); t:SetAlpha(0.08); t:SetDrawLayer("ARTWORK", 2)
                        curBoxes[#curBoxes + 1] = { cx = box[2] * MAPW * ZOOM, cy = box[3] * MAPH * ZOOM, w = box[4] * ZOOM, h = box[5] * ZOOM, th = box[6] or 0 }
                    else t:SetVertexColor(0.36, 0.3, 0.31, 0.9); t:SetAlpha(1); t:SetDrawLayer("ARTWORK", 0) end
                end
            end
        end
    end
    -- 테두리: 같은 방 다른 네모와 겹치거나 맞닿은 변은 빼고 바깥 둘레만 (1.5px 선 + 5px 빛)
    local function Inside(px, py, skip, pad)
        for k, bx in ipairs(curBoxes) do
            if k ~= skip then
                local dx, dy = px - bx.cx, py - bx.cy
                local c, sn = math.cos(bx.th), math.sin(bx.th)
                local u, v = dx * c + dy * sn, -dx * sn + dy * c
                if math.abs(u) < bx.w / 2 + pad and math.abs(v) < bx.h / 2 + pad then return true end
            end
        end
        return false
    end
    local function Line(x1, y1, x2, y2, th)
        local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        local horiz = math.abs((x2 - x1) * math.cos(th) + (y2 - y1) * math.sin(th)) >= len * 0.5
        for g = 1, 2 do
            local ln = card.nextLN()
            local wdt = (g == 1) and 5 or 1.5
            if horiz then ln:SetSize(len + wdt, wdt) else ln:SetSize(wdt, len + wdt) end
            ln:ClearAllPoints(); ln:SetPoint("CENTER", card.canvas, "TOPLEFT", (x1 + x2) / 2, -(y1 + y2) / 2)
            pcall(ln.SetRotation, ln, -th)
            if g == 1 then ln:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1); ln:SetDrawLayer("ARTWORK", 3); ln.leelGlow = true
            else ln:SetVertexColor(1, 0.84, 0.88, 1); ln:SetAlpha(1); ln:SetDrawLayer("ARTWORK", 4); ln.leelGlow = nil end
        end
    end
    for k, bx in ipairs(curBoxes) do
        local c, sn = math.cos(bx.th), math.sin(bx.th)
        local hw, hh = bx.w / 2, bx.h / 2
        local corners = { { -hw, -hh }, { hw, -hh }, { hw, hh }, { -hw, hh } }
        for e = 1, 4 do
            local a1, a2 = corners[e], corners[e % 4 + 1]
            local ax, ay = bx.cx + a1[1] * c - a1[2] * sn, bx.cy + a1[1] * sn + a1[2] * c
            local ex, ey = bx.cx + a2[1] * c - a2[2] * sn, bx.cy + a2[1] * sn + a2[2] * c
            local nx, ny
            if e == 1 then nx, ny = sn, -c elseif e == 2 then nx, ny = c, sn elseif e == 3 then nx, ny = -sn, c else nx, ny = -c, -sn end
            local len = math.sqrt((ex - ax) ^ 2 + (ey - ay) ^ 2)
            local n = math.max(1, math.ceil(len / 3))
            local runStart
            for i = 1, n + 1 do
                local vis = false
                if i <= n then
                    local t = (i - 0.5) / n
                    local px, py = ax + (ex - ax) * t, ay + (ey - ay) * t
                    vis = not Inside(px, py, k, -0.5) and not Inside(px + nx * 3, py + ny * 3, k, 0.5)
                end
                if vis and not runStart then runStart = i end
                if not vis and runStart then
                    local t1, t2 = (runStart - 1) / n, (i - 1) / n
                    Line(ax + (ex - ax) * t1, ay + (ey - ay) * t1, ax + (ex - ax) * t2, ay + (ey - ay) * t2, bx.th)
                    runStart = nil
                end
            end
        end
    end
    card.endLN()
    -- 파티원이 있는 방: 직업 색 점
    if DR.Group and DR.Group.RoomsOn then
        local ok, list = pcall(DR.Group.RoomsOn, DR.Group, key, floor)
        if ok and type(list) == "table" then
            for _, entry in ipairs(list) do
                local u, v = DR.Room:Center(entry.room, floor)
                if u then
                    for j, name in ipairs(entry.names or {}) do
                        local t = card.nextPM()
                        t:SetVertexColor(ClassOf(name))
                        t:ClearAllPoints(); t:SetPoint("CENTER", card.canvas, "TOPLEFT", u * MAPW * ZOOM + (j - 1) * 7 - 4, -v * MAPH * ZOOM + 5)
                    end
                end
            end
        end
    end
    card.endRM(); card.endPM()

    -- 길: 점선
    local step = 7
    for _, path in ipairs(route.paths or {}) do
        if DR.OnFloor(path, floor) then
            local pts = path.pts or {}
            local carry = 0
            for j = 1, #pts - 3, 2 do
                local ax, ay = pts[j] * MAPW * ZOOM, pts[j + 1] * MAPH * ZOOM
                local bx, by = pts[j + 2] * MAPW * ZOOM, pts[j + 3] * MAPH * ZOOM
                local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
                local d = carry
                while d < len do
                    local t = card.nextDT()
                    local k = d / len
                    t:ClearAllPoints(); t:SetPoint("CENTER", card.canvas, "TOPLEFT", ax + (bx - ax) * k, -(ay + (by - ay) * k))
                    t:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], path.kind == "side" and 0.5 or 0.95)
                    d = d + step
                end
                carry = d - len
            end
        end
    end
    card.endDT()

    -- 우두머리: 잡음 초록 · 다음 노랑 · 남음 회색 (번호 = FDR 순서)
    local labels = DR:GetStopLabels(route)
    local nextI = DR:GetNextStopIndex(key, route)
    for i, stop in ipairs(route.stops or {}) do
        if (stop.kind == "boss" or stop.kind == "rare") and DR.OnFloor(stop, floor) and stop.x then
            local f = card.nextPN()
            local done = DR:IsStopDone(key, route, i)
            if done then f.b:SetVertexColor(0.33, 0.62, 0.36, 1); f.t:SetTextColor(0.06, 0.14, 0.07)
            elseif i == nextI then f.b:SetVertexColor(1, 0.83, 0.42, 1); f.t:SetTextColor(0.23, 0.16, 0.06)
            else f.b:SetVertexColor(0.33, 0.28, 0.29, 1); f.t:SetTextColor(0.85, 0.8, 0.78) end
            f.t:SetText(labels[i] or "")
            f:SetSize(i == nextI and 16 or 14, i == nextI and 16 or 14)
            f:ClearAllPoints(); f:SetPoint("CENTER", card.canvas, "TOPLEFT", stop.x * MAPW * ZOOM, -stop.y * MAPH * ZOOM)
        end
    end
    card.endPN()
end

-- 지도 칸을 보고 싶은 곳(내 위치 · 지금 방 · 다음 우두머리)에 맞춰요
local function Focus(key, route, floor)
    local fu, fv
    local k, f, u, v = DR:LocatePlayer(floor)
    if f == floor and u then
        fu, fv = u, v
        card.me:ClearAllPoints(); card.me:SetPoint("CENTER", card.canvas, "TOPLEFT", u * MAPW * ZOOM, -v * MAPH * ZOOM)
        card.me:Show(); card.roomMe:Hide()
    else
        card.me:Hide()
        local room = DR.Room and DR.Room:Get()
        local ru, rv
        if room then ru, rv = DR.Room:Center(room, floor) end
        if ru then
            card.roomMe:Hide()   -- 토끼 표시는 뺐어요 (방 테두리로)
        else
            card.roomMe:Hide()
        end
    end
    if not fu then
        local room = DR.Room and DR.Room:Get()
        if room then fu, fv = DR.Room:Center(room, floor) end
    end
    if not fu then
        local ni = DR:GetNextStopIndex(key, route)
        local s = ni and route.stops[ni]
        if s and DR.OnFloor(s, floor) then fu, fv = s.x, s.y end
    end
    fu, fv = fu or 0.5, fv or 0.5
    local cw, ch = MAPW * ZOOM, MAPH * ZOOM
    local vw, vh = CW - 2, MH
    local x = math.max(vw - cw, math.min(0, vw / 2 - fu * cw))
    local y = math.max(vh - ch, math.min(0, vh / 2 - fv * ch))
    card.canvas:ClearAllPoints(); card.canvas:SetPoint("TOPLEFT", card.clip, "TOPLEFT", x, -y)
end

-- 지금 방: 지도를 가리지 않게 연하게, 천천히 숨 쉬듯
Pulse = function()
    local a = 0.18 + 0.14 * (0.5 + 0.5 * math.sin(GetTime() * 2.4))
    local ga = 0.15 + 0.4 * (0.5 + 0.5 * math.sin(GetTime() * 2.4))
    for _, t in ipairs(card.ln) do
        if t:IsShown() and t.leelGlow then t:SetAlpha(ga) end
    end
    if card.roomMe and card.roomMe:IsShown() then
        local k = (GetTime() * 0.8) % 1
        card.roomMe.ring:SetSize(22 + 22 * k, 22 + 22 * k); card.roomMe.ring:SetAlpha(0.8 * (1 - k))
    end
end

local function Texts(key, route, floor)
    local room = DR.Room and DR.Room:Get()
    local title = room and DR.LocText(room, "name") or DR:GetFloorName(floor) or DR:GetKeyName(key)
    if not room then title = title .. " |cff8a7a76근처|r" end
    card.title:SetText(title)
    -- 층 점
    local dungeon = DR:GetDungeon(key)
    local floors = dungeon and dungeon.floors or {}
    local n = math.min(#floors, 6)
    for i, p in ipairs(card.pips) do
        if i <= n and n > 1 then
            p:ClearAllPoints(); p:SetPoint("TOPRIGHT", card, "TOPRIGHT", -32 - (n - i) * 9, -13); p:Show()
            if floors[i] == floor then p:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1) else p:SetVertexColor(0.35, 0.27, 0.28, 1) end
        else p:Hide() end
    end
    -- 진행
    local total, done = 0, 0
    for i, stop in ipairs(route.stops or {}) do
        if stop.kind == "boss" then total = total + 1; if DR:IsStopDone(key, route, i) then done = done + 1 end end
    end
    local started, finished, best = DR:GetRunTimes(key)
    local t = ""
    if started then t = "  ·  " .. DR.FormatDuration((finished or time()) - started) end
    if best then t = t .. "  |cff8a7a76최고 " .. DR.FormatDuration(best) .. "|r" end
    card.prog:SetText(("우두머리 |cffefe3df%d/%d|r%s"):format(done, total, t))
    card.barFill:SetWidth(math.max(0.01, card.barW * (total > 0 and done / total or 0)))
    -- 다음
    local ni = DR:GetNextStopIndex(key, route)
    local y = -52 - MH - 7
    card.nextT:ClearAllPoints(); card.nextT:SetPoint("TOPLEFT", 11, y)
    local memo
    if ni then
        local s = route.stops[ni]
        local lab = DR:GetStopLabels(route)[ni] or ""
        local where = (s.floor and s.floor ~= floor) and (" · " .. DR:GetFloorName(s.floor)) or ""
        card.nextT:SetText(("다음 |cffffd36b%s · %s|r%s"):format(lab, DR:GetStopName(s), where))
        memo = s.noteKO   -- 한국어 메모만 (영어 · 독일어만 있는 메모는 안 보여요)
    else
        card.nextT:SetText(total > 0 and "|cff8fdc9b우두머리 다 잡았어요!|r" or DR:GetKeyName(key))
    end
    y = y - 16
    if memo and memo ~= "" then
        card.memo:ClearAllPoints(); card.memo:SetPoint("TOPLEFT", 19, y)
        card.memo:SetText(memo); card.memo:Show()
        local h = math.min(card.memo:GetStringHeight() or 12, 28)
        card.memoBar:ClearAllPoints(); card.memoBar:SetPoint("TOPLEFT", 11, y + 1); card.memoBar:SetHeight(h + 2); card.memoBar:Show()
        y = y - h - 6
    else
        card.memo:Hide(); card.memoBar:Hide()
    end
    -- 파티원 방
    local parts = {}
    if DR.Group and DR.Group.Members then
        local ok, m = pcall(DR.Group.Members, DR.Group, key)
        if ok and type(m) == "table" then
            for name, r in pairs(m) do
                local cr, cg, cb = ClassOf(name)
                parts[#parts + 1] = ("|cff%02x%02x%02x●|r %s%s"):format(cr * 255, cg * 255, cb * 255, name, r and (" · " .. RoomName(key, r)) or "")
            end
        end
    end
    if #parts > 0 then
        table.sort(parts)
        card.party:ClearAllPoints(); card.party:SetPoint("TOPLEFT", 11, y)
        card.party:SetText(table.concat(parts, "   ")); card.party:Show()
        y = y - math.min(card.party:GetStringHeight() or 12, 26) - 4
    else
        card.party:Hide()
    end
    card:SetHeight(-y + 8)
end

local function Refresh()
    if not card then return end
    DR = DR or _G.ForeverDungeonRoutes
    local key = DR and DR.db and DR.currentKey
    local route = key and DR:GetActiveRoute(key)
    if not (On() and key and route and Minimap and Minimap:IsVisible()) or ns.dungeonBig then
        card:Hide()
        if not key and ns.dungeonBig then ns.DungeonBig(false) end
        return
    end
    local ok, err = pcall(function()
        local floor = ChooseFloor(key, route)
        local room = DR.Room and DR.Room:Get()
        local sig = table.concat({ key, tostring(floor), tostring(route.id), tostring(room and room.name) }, "|")
        if dirty or sig ~= cur.sig then
            cur.key, cur.floor, cur.sig = key, floor, sig
            DrawStatic(key, route, floor)
            dirty = false
        end
        Focus(key, route, floor)
        Texts(key, route, floor)
    end)
    if not ok then card:Hide(); return end
    card:ClearAllPoints(); card:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -14, 4)
    card:Show()
end
ns.DungeonCardRefresh = function() dirty = true; Refresh() end

----------------------------------------------------------------------
-- 미니맵 크게 (게임 미니맵 = 방 안 정확한 위치)
----------------------------------------------------------------------
local saved
function ns.DungeonBig(on)
    local mc = MinimapCluster
    if not (mc and Minimap) then return end
    if on and not ns.dungeonBig then
        saved = { scale = mc:GetScale(), zoom = Minimap:GetZoom() }
        local ok = pcall(mc.SetScale, mc, saved.scale * 1.9)
        if not ok then saved = nil; return end
        pcall(Minimap.SetZoom, Minimap, 0)
        ns.dungeonBig = true
        if card then card:Hide() end
        if smallBtn then
            smallBtn:ClearAllPoints(); smallBtn:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -6, 0); smallBtn:Show()
        end
    elseif not on and ns.dungeonBig then
        ns.dungeonBig = false
        if saved then
            pcall(mc.SetScale, mc, saved.scale)
            pcall(Minimap.SetZoom, Minimap, saved.zoom or 0)
        end
        saved = nil
        if smallBtn then smallBtn:Hide() end
        Refresh()
    end
end

----------------------------------------------------------------------
-- 연결: FDR 이벤트 · 1초마다 시간 · 위치
----------------------------------------------------------------------
local function Hook()
    DR = _G.ForeverDungeonRoutes
    if not (DR and DR.On and DR.GetActiveRoute) then return end
    if not card then Build() end
    for _, ev in ipairs({ "DUNGEON_CHANGED", "ROOM_CHANGED", "PROGRESS_CHANGED", "ROUTE_CHANGED", "RUN_RESET", "BOSS_KILLED" }) do
        DR:On(ev, function() dirty = true; C_Timer.After(0, Refresh) end)
    end
    -- 던전에 들어갈 때 FDR 작은 지도 대신 르엘 카드 (FDR 설정은 그대로 두고 그때만 건너뛰어요)
    if DR.OnZoneChanged and not DR.leelWrapped then
        DR.leelWrapped = true
        local orig = DR.OnZoneChanged
        DR.OnZoneChanged = function(self, ...)
            local db = self.db
            local keep = db and db.onEnter
            if On() and db and keep == "mini" then db.onEnter = "none"; self.hinted = true end
            local ok, err = pcall(orig, self, ...)
            if db then db.onEnter = keep end
            C_Timer.After(0.1, function() dirty = true; Refresh() end)
            if not ok then geterrorhandler()(err) end
        end
    end
    local acc = 0
    local tick = CreateFrame("Frame")
    tick:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc < 1 then return end
        acc = 0
        if DR.currentKey or (card and card:IsShown()) or ns.dungeonBig then Refresh() end
    end)
    Refresh()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() C_Timer.After(1, Hook) end)

SLASH_LEELDUNGEON1 = "/르엘던전"
SlashCmdList.LEELDUNGEON = function(msg)
    msg = strtrim(msg or "")
    if msg == "크게" then ns.DungeonBig(not ns.dungeonBig)
    elseif msg == "끄기" then ns.db.fdrCard = false; Refresh(); print("|cfff2b3c2르엘|r 던전 카드를 껐어요. (/르엘던전 켜기)")
    elseif msg == "켜기" then ns.db.fdrCard = true; dirty = true; Refresh(); print("|cfff2b3c2르엘|r 던전 카드를 켰어요.")
    else
        if not _G.ForeverDungeonRoutes then print("|cfff2b3c2르엘|r 던전 카드는 Forever Dungeon Routes가 있어야 보여요.") return end
        print("|cfff2b3c2르엘|r /르엘던전 크게 · 끄기 · 켜기")
    end
end
