-- 르엘 퀘스트 판 (ForgLeveling 자리)
-- 다른 애드온(Questie) 없이 내 퀘스트 목록만 읽어서, 고른 퀘로 짧은 길을 짜고 따라가요.
--  * 고르기 판: 이 지역 · 다 한 퀘 · 다른 지역, 지도 위 번호 + 점선 길
--  * 따라가기 창: 지금 할 일 · 방향 화살표 · 거리 (르엘 UI 퀘스트 목록 "르엘 퀘스트 판" 자리)
--  * 위치 찾는 순서: 내가 잡던 곳 → 게임 지도 표시 → 길잡이 자료(퀘 준 사람 근처, 보고할 때)
-- /forg · /길잡이 · /퀘판

local ADDON, ns = ...
local D = ns.data or { brackets = {}, maps = {} }
local L = _G.LeelUI

local DB, CDB
local function Print(msg)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cfff2b3c2[르엘 퀘스트 판]|r " .. msg) end
end

----------------------------------------------------------------------
-- 색 · 그리기 (르엘 UI가 있으면 그 부품을 씀)
----------------------------------------------------------------------
local P = (L and L.C) or {
    acc = { 0.949, 0.702, 0.761 }, accHi = { 1, 0.84, 0.878 }, tx = { 0.965, 0.925, 0.91 },
    tx2 = { 0.839, 0.627, 0.612 }, ink = { 0.227, 0.11, 0.141 }, plate = { 0.184, 0.145, 0.133, 0.88 },
    edge = { 0.839, 0.627, 0.612, 0.38 },
}
local MEDIA = (L and L.MEDIA) or "Interface\\AddOns\\LeelUI\\media\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local CHIP = { 0.173, 0.133, 0.125 }
local DIM = { 0.72, 0.64, 0.61 }
local COL = {
    easy = { { 0.184, 0.29, 0.173 }, { 0.75, 0.9, 0.706 } },
    mid  = { { 0.29, 0.247, 0.133 }, { 0.945, 0.851, 0.541 } },
    hard = { { 0.29, 0.141, 0.141 }, { 1, 0.69, 0.69 } },
    grey = { { 0.227, 0.18, 0.169 }, { 0.85, 0.8, 0.78 } },
    pink = { P.acc, P.ink },
    done = { { 0.945, 0.851, 0.541 }, P.ink },    -- 보고할 퀘 = 노랑 (따라가기 창 · 지도 번호와 같은 색)
}

local function Font(parent, size, color)
    if L and L.Font then return L.Font(parent, size, color) end
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(STANDARD_TEXT_FONT, size, "")
    fs:SetShadowColor(0, 0, 0, 0.85); fs:SetShadowOffset(1, -1)
    color = color or P.tx
    fs:SetTextColor(color[1], color[2], color[3])
    return fs
end
local function Num(parent, size, color)
    if L and L.Num then return L.Num(parent, size, color) end
    return Font(parent, size, color)
end
local function RR(parent, r, color, layer, sub, inset)
    if L and L.RoundRect then return L.RoundRect(parent, r, color, layer, sub, inset) end
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetTexture(WHITE); t:SetAllPoints()
    local o = { tex = { t } }
    function o:SetColor(c, a) t:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1) end
    if color then o:SetColor(color) end
    return o
end
local function Plate(parent, r, fill, edge)
    if L and L.RoundPlate then return L.RoundPlate(parent, r, fill, edge) end
    local e = RR(parent, r, edge or P.edge, "BACKGROUND", 0)
    local f = RR(parent, r, fill or P.plate, "BACKGROUND", 1)
    return f, e
end
local function Button(parent, text, primary, fn, minW)
    if L and L.MakeButton then return L.MakeButton(parent, text, primary, fn, minW) end
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(math.max(minW or 0, 90), 24); b:SetText(text); b:SetScript("OnClick", fn)
    function b:SetLabel(t) self:SetText(t) end
    return b
end

-- 작은 색 알약 글씨
local function MakeChip(parent)
    local c = CreateFrame("Frame", nil, parent)
    c:SetHeight(18)
    c.bg = RR(c, 7, COL.grey[1], "BACKGROUND", 2, 0)
    c.fs = Font(c, 11, COL.grey[2]); c.fs:SetPoint("CENTER", 0, 0)
    function c:Set(text, kind)
        if not text then self:Hide() return end
        local k = COL[kind or "grey"] or COL.grey
        self.bg:SetColor(k[1]); self.fs:SetTextColor(k[2][1], k[2][2], k[2][3])
        self.fs:SetText(text)
        self:SetWidth(self.fs:GetStringWidth() + 14)
        self:Show()
    end
    return c
end

----------------------------------------------------------------------
-- 길잡이 자료 (forg.gg): 퀘 이름 → 준 사람 · 좌표 · 지역
----------------------------------------------------------------------
local function Norm(s)
    if not s then return "" end
    s = s:gsub("^%[[^%]]*%]%s*", "")
    s = s:gsub("%b()", "")
    s = s:gsub("[%s%p]", "")
    return s
end

local guide = {}       -- key → { zone, x, y, npc, level, order }
do
    local order = 0
    for _, b in ipairs(D.brackets or {}) do
        for _, z in ipairs(b.zones or {}) do
            for _, q in ipairs(z.quests or {}) do
                order = order + 1
                local k = Norm(q[2])
                if not guide[k] then
                    guide[k] = { zone = q[6] or z.name, x = q[4], y = q[5], npc = q[3], level = q[1], order = order }
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- 지도 · 내 위치
----------------------------------------------------------------------
local function PlayerMap()
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
        if ok then return m end
    end
end
local function PlayerXY(m)
    m = m or PlayerMap()
    if not (m and C_Map and C_Map.GetPlayerMapPosition) then return end
    local ok, p = pcall(C_Map.GetPlayerMapPosition, m, "player")
    if ok and p then
        local x, y = p:GetXY()
        if x and (x > 0 or y > 0) then return x * 100, y * 100 end
    end
end
local function ZoneText() return (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "" end
local function MapName(m)
    if m and C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, m)
        if ok and info then return info.name end
    end
end
-- 이 지역 이름이 지금 지도인지
local function IsHere(zone, m)
    if not zone then return false end
    if D.maps and D.maps[zone] and m then return D.maps[zone] == m end
    return zone == ZoneText() or zone == MapName(m)
end

-- 지도 % 두 점 사이 거리(야드). 모르면 nil
local function Yards(m, ax, ay, bx, by)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
    local ok, _, a = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(ax / 100, ay / 100))
    local ok2, _, b = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(bx / 100, by / 100))
    if ok and ok2 and a and b then
        local dx, dy = b.x - a.x, b.y - a.y
        return math.sqrt(dx * dx + dy * dy), dx, dy
    end
end

----------------------------------------------------------------------
-- 내 퀘스트 목록 읽기
----------------------------------------------------------------------
local log, byId = {}, {}

local function ParseObjective(text, have, need, done)
    text = text or ""
    local name, a, b = text:match("^(.-)%s*:%s*(%d+)%s*/%s*(%d+)%s*$")
    if not name then a, b, name = text:match("^(%d+)%s*/%s*(%d+)%s+(.+)$") end
    if name and name ~= "" then text = name end
    have = have or tonumber(a); need = need or tonumber(b)
    if done == nil and have and need then done = have >= need end
    return { text = text, have = have, need = need, done = done and true or false }
end

local function Objectives(id, index)
    local out = {}
    if id and C_QuestLog and C_QuestLog.GetQuestObjectives then
        local ok, list = pcall(C_QuestLog.GetQuestObjectives, id)
        if ok and type(list) == "table" then
            for _, o in ipairs(list) do out[#out + 1] = ParseObjective(o.text, o.numFulfilled, o.numRequired, o.finished) end
        end
    end
    if #out == 0 and index and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
        local ok, n = pcall(GetNumQuestLeaderBoards, index)
        for i = 1, (ok and n or 0) do
            local ok2, text, _, fin = pcall(GetQuestLogLeaderBoard, i, index)
            if ok2 and text then out[#out + 1] = ParseObjective(text, nil, nil, fin and true or nil) end
        end
    end
    return out
end

local function RewardXP(id)
    if not (id and GetQuestLogRewardXP) then return end
    local ok, xp = pcall(GetQuestLogRewardXP, id)
    if ok and type(xp) == "number" and xp > 0 then return xp end
end

local function ReadLog()
    local list, header = {}, nil
    local n = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
    if type(n) ~= "number" then n = 0 end
    local function Title(i)
        if GetQuestLogTitle then return GetQuestLogTitle(i) end
        local info = C_QuestLog and C_QuestLog.GetInfo and C_QuestLog.GetInfo(i)
        if not info then return end
        local comp = info.questID and C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID)
        return info.title, info.level, info.suggestedGroup, info.isHeader, nil, comp and 1 or nil, nil, info.questID
    end
    if n == 0 and not GetNumQuestLogEntries and C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        n = C_QuestLog.GetNumQuestLogEntries() or 0
    end
    for i = 1, n do
        local title, level, group, isHeader, _, isComplete, _, id = Title(i)
        if title then
            if isHeader then
                header = title
            else
                local objs = Objectives(id, i)
                local done = (isComplete == 1 or isComplete == true)
                if not done and id and C_QuestLog and C_QuestLog.IsComplete then
                    local ok, r = pcall(C_QuestLog.IsComplete, id); if ok and r then done = true end
                end
                if not done and #objs > 0 then
                    done = true
                    for _, o in ipairs(objs) do if not o.done then done = false break end end
                end
                local failed = isComplete == -1
                list[#list + 1] = {
                    id = id, title = title, key = Norm(title), level = level or 0, group = tonumber(group) or 0,
                    zone = header, done = done and not failed, failed = failed, objs = objs, xp = RewardXP(id), index = i,
                }
            end
        end
    end
    log, byId = list, {}
    for _, e in ipairs(list) do if e.id then byId[e.id] = e end end
end

-- 목표 숫자가 오를 때 서 있던 곳 기억 (예전 길잡이 기록과 같은 모양: 이름 기준)
local lastSum = {}
local function Learn()
    if not DB then return end
    DB.learned = DB.learned or {}
    local m = PlayerMap()
    local px, py = PlayerXY(m)
    for _, e in ipairs(log) do
        local sum = 0
        for _, o in ipairs(e.objs) do sum = sum + (o.have or (o.done and 1 or 0)) end
        local prev = lastSum[e.key]
        if prev and sum > prev and px then
            local zone = ZoneText()
            local Lr = DB.learned[e.key]
            if Lr and Lr.map == m and Lr.n then
                local k = math.min(Lr.n, 9)
                Lr.x = (Lr.x * k + px) / (k + 1); Lr.y = (Lr.y * k + py) / (k + 1); Lr.n = Lr.n + 1
            else
                DB.learned[e.key] = { zone = zone, x = px, y = py, n = 1, map = m }
            end
        end
        lastSum[e.key] = sum
    end
end

----------------------------------------------------------------------
-- 위치 찾기 (지금 지도 기준, 지도 %)
----------------------------------------------------------------------
local SRC = { questie = "Questie", learned = "내가 잡던 곳", game = "게임 지도 표시", guide = "길잡이 자료", none = "위치 모름" }
local SRC_ICON = { questie = "|cfff1d98a●|r ", learned = "|cffffd6e0●|r ", game = "|cffb4d2f2●|r ", guide = "|cfff2b3c2●|r ", none = "|cff8a7a76●|r " }

-- Questie가 켜져 있으면: 그 퀘스트의 지도 아이콘(목표 · 반납 NPC) 중 내 위치에서 가장 가까운 곳
local qieCache = {}
local function QuestiePos(e, m, px, py)
    if not (e.id and m and _G.QuestieLoader and _G.QuestieLoader.ImportModule) then return end
    local now = GetTime()
    local c = qieCache[e.id]
    if not c or now - c.t > 4 then
        c = { t = now, obj = {}, fin = {} }
        qieCache[e.id] = c
        local ok, QM = pcall(_G.QuestieLoader.ImportModule, _G.QuestieLoader, "QuestieMap")
        local frames = ok and type(QM) == "table" and type(QM.questIdFrames) == "table" and QM.questIdFrames[e.id]
        if type(frames) == "table" then
            for _, fname in pairs(frames) do
                local fr = type(fname) == "string" and _G[fname] or fname
                local d = type(fr) == "table" and fr.data
                if type(d) == "table" and fr.x and fr.y and fr.UiMapID and #c.obj < 300 then
                    local pt = { map = fr.UiMapID, x = fr.x, y = fr.y, idx = d.ObjectiveIndex, npc = d.Name }
                    if d.Type == "complete" then c.fin[#c.fin + 1] = pt
                    elseif d.ObjectiveIndex then c.obj[#c.obj + 1] = pt end
                end
            end
        end
    end
    -- 완료 퀘: 반납 NPC (보통 한 곳) → 가장 가까운 것
    if e.done then
        local best, bd
        for _, p in ipairs(c.fin) do
            if p.map == m then
                local d = px and ((p.x - px) ^ 2 + (p.y - py) ^ 2) or 0
                if not bd or d < bd then best, bd = p, d end
            end
        end
        if best then return best.x, best.y end
        return
    end
    -- 하는 중인 퀘: 남은 목표의 몹/물건이 가장 많이 몰린 곳의 가운데 (내 위치와 상관없이 늘 같은 자리)
    local key = m .. ":" .. (function()
        local t = {}
        for i, o in ipairs(e.objs) do t[#t + 1] = o.done and "1" or "0" end
        return table.concat(t)
    end)()
    if c.centerKey == key and c.center ~= nil then
        if c.center then return c.center[1], c.center[2] end
        return
    end
    local pts = {}
    for _, p in ipairs(c.obj) do
        if p.map == m then
            local o = p.idx and e.objs[p.idx]
            if not (o and o.done) then pts[#pts + 1] = p end
        end
    end
    c.centerKey = key
    if #pts == 0 then c.center = false return end
    local R2 = 6 * 6          -- 지도 % 기준 반경 6
    local bestI, bestN = 1, -1
    for i, a in ipairs(pts) do
        local n = 0
        for _, b in ipairs(pts) do
            if (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 <= R2 then n = n + 1 end
        end
        if n > bestN then bestI, bestN = i, n end
    end
    local a, sx, sy, n = pts[bestI], 0, 0, 0
    for _, b in ipairs(pts) do
        if (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 <= R2 then sx, sy, n = sx + b.x, sy + b.y, n + 1 end
    end
    c.center = { sx / n, sy / n }
    return c.center[1], c.center[2]
end

-- 완료한 퀘의 반납 NPC (Questie): { map, x, y, npc } 하나 (지금 지도에 있으면 그것, 아니면 첫 번째)
local function TurnInInfo(e)
    if not (e.done and e.id) then return end
    QuestiePos(e, PlayerMap(), nil, nil)        -- 캐시 채우기
    local c = qieCache[e.id]
    if not (c and #c.fin > 0) then return end
    local m = PlayerMap()
    for _, p in ipairs(c.fin) do if p.map == m then return p end end
    return c.fin[1]
end

-- 완료한 퀘는 반납 NPC가 있는 지역으로, 하는 중인 퀘는 퀘스트 일지 지역으로
local mapNameCache = {}
local function ZoneKey(e)
    if e.done then
        local t = TurnInInfo(e)
        if t and t.map then
            local n = mapNameCache[t.map]
            if n == nil then n = MapName(t.map) or false; mapNameCache[t.map] = n end
            if n then return n end
        end
    end
    return e.zone or "기타"
end

local function GamePos(id, m)
    if not (id and m) then return end
    if C_QuestLog and C_QuestLog.GetQuestsOnMap then
        local ok, list = pcall(C_QuestLog.GetQuestsOnMap, m)
        if ok and type(list) == "table" then
            for _, info in ipairs(list) do
                if info.questID == id and info.x and (info.x > 0 or info.y > 0) then return info.x * 100, info.y * 100 end
            end
        end
    end
end

local function QuestPos(e, m)
    local g = guide[e.key]
    -- 1) Questie 자료가 있으면 그게 가장 정확해요
    do
        local px, py = PlayerXY(m)
        local qx, qy = QuestiePos(e, m, px, py)
        if qx then return qx, qy, "questie" end
    end
    if e.done then
        if g and g.x and IsHere(g.zone, m) then return g.x, g.y, "guide" end
        local x, y = GamePos(e.id, m); if x then return x, y, "game" end
        return nil, nil, "none"
    end
    local Lr = DB and DB.learned and DB.learned[e.key]
    if Lr and Lr.x and (Lr.map == m or (not Lr.map and Lr.zone == ZoneText())) then return Lr.x, Lr.y, "learned" end
    local x, y = GamePos(e.id, m); if x then return x, y, "game" end
    return nil, nil, "none"
end

local function InZone(e, m)
    if e.zone and (e.zone == ZoneText() or e.zone == MapName(m)) then return true end
    local x = QuestPos(e, m)
    return x ~= nil
end

-- 난이도: 글씨는 퀘 레벨, 색이 난이도 (빨강 어려움 · 노랑 보통 · 초록 쉬움 · 회색 너무 쉬움)
-- 와우 포에버는 퀘 레벨이 조금만 높아도 힘들어서: 내 레벨보다 3 이상 = 어려움, 1~2 = 보통
local function Diff(e)
    local lv = e.level or 0
    local me = UnitLevel("player") or 1
    local d = lv - me
    local txt = lv > 0 and ("Lv " .. lv) or "Lv ?"
    if e.group and e.group > 1 then return txt .. " · 파티", "hard" end
    if d >= 3 then return txt, "hard" end
    if d >= 1 then return txt, "mid" end
    local greyAt = me - ((GetQuestGreenRange and GetQuestGreenRange()) or 7) - 1
    if lv > 0 and lv <= greyAt then return txt, "easy", "grey" end
    return txt, "easy"
end

local function Progress(e)
    if e.done then
        local t = TurnInInfo(e)
        local g = guide[e.key]
        local npc = (t and t.npc) or (g and g.npc)
        return "완료 · " .. (npc and ("반납: " .. npc) or "반납하러 가기")
    end
    for _, o in ipairs(e.objs) do
        if not o.done then
            if o.have and o.need then return ("%s %d/%d"):format(o.text, o.have, o.need) end
            return o.text
        end
    end
    return ""
end

----------------------------------------------------------------------
-- 길 짜기: 내 위치에서 가장 가까운 것부터 차례로 (위치 모르는 건 맨 뒤)
----------------------------------------------------------------------
local function Sel() CDB.sel = CDB.sel or {}; return CDB.sel end

local NEAR = 4      -- 지도 % : 이만큼 가까운 보고는 가는 길에 들러요
local BuildOrderNN
local function BuildOrder()
    -- 토끼 추천으로 짠 순서가 있으면 그 순서(묶음 순서)를 지켜요
    local rec = CDB and CDB.rec
    if rec and rec.order then
        local order, seen, late = {}, {}, {}
        for _, id in ipairs(rec.order) do
            local e = byId[id]
            if e and Sel()[id] and not e.failed then
                seen[id] = true
                -- 추천 뒤에 다 한 퀘(반납 NPC가 다른 곳일 수 있음)는 맨 뒤로
                if e.done and not (rec.done and rec.done[id]) then late[#late + 1] = id
                else order[#order + 1] = id end
            end
        end
        -- 추천 밖에서 직접 고른 퀘는 가까운 순으로 뒤에
        for _, id in ipairs(BuildOrderNN()) do if not seen[id] then order[#order + 1] = id end end
        for _, id in ipairs(late) do order[#order + 1] = id end
        return order
    end
    return BuildOrderNN()
end

BuildOrderNN = function()
    local m = PlayerMap()
    local px, py = PlayerXY(m)
    local todo, turn, todoUnknown, turnUnknown = {}, {}, {}, {}
    for _, e in ipairs(log) do
        if e.id and Sel()[e.id] and not e.failed then
            local x, y = QuestPos(e, m)
            if x then
                local list = e.done and turn or todo
                list[#list + 1] = { id = e.id, x = x, y = y }
            else
                local list = e.done and turnUnknown or todoUnknown
                list[#list + 1] = e.id
            end
        end
    end
    local order = {}
    local cx, cy = px or 50, py or 50
    local function nearest(list)
        local bi, bd = nil, math.huge
        for i, k in ipairs(list) do
            local d = (k.x - cx) ^ 2 + (k.y - cy) ^ 2
            if d < bd then bi, bd = i, d end
        end
        return bi, bd
    end
    local function take(list, i)
        local k = table.remove(list, i)
        order[#order + 1] = k.id; cx, cy = k.x, k.y
    end
    -- 1) 할 일 먼저 (가까운 순). 바로 옆에 보고할 곳이 있으면 그때 들러요
    while #todo > 0 do
        local ti, td = nearest(turn)
        if ti and td <= NEAR * NEAR then take(turn, ti)
        else take(todo, (nearest(todo))) end
    end
    local ti, td = nearest(turn)
    while ti and td <= NEAR * NEAR do take(turn, ti); ti, td = nearest(turn) end
    -- 2) 위치 모르는 할 일
    for _, id in ipairs(todoUnknown) do order[#order + 1] = id end
    -- 3) 남은 보고는 맨 끝에 한 번에 (가까운 순)
    while #turn > 0 do take(turn, (nearest(turn))) end
    for _, id in ipairs(turnUnknown) do order[#order + 1] = id end
    return order
end

-- 따라가는 중인 길 (퀘스트를 반납하면 저절로 빠져요)
local function Route()
    if not (CDB and CDB.route) then return {} end
    local out = {}
    for _, id in ipairs(CDB.route) do
        local e = byId[id]
        if e and Sel()[id] then out[#out + 1] = e end
    end
    return out
end

----------------------------------------------------------------------
-- 지도 그림 (지역 지도 조각을 이어 붙임)
----------------------------------------------------------------------
local function PaintMapArt(panel, m)
    panel.tiles = panel.tiles or {}
    for _, t in ipairs(panel.tiles) do t:Hide() end
    panel.noArt:Show()
    if not (m and C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then return end
    local ok, layers = pcall(C_Map.GetMapArtLayers, m)
    local ok2, files = pcall(C_Map.GetMapArtLayerTextures, m, 1)
    if not (ok and ok2 and layers and layers[1] and files and #files > 0) then return end
    local ly = layers[1]
    local cols = math.ceil(ly.layerWidth / ly.tileWidth)
    local W, H = panel:GetWidth(), panel:GetHeight()
    local sx, sy = W / ly.layerWidth, H / ly.layerHeight
    for i, file in ipairs(files) do
        local t = panel.tiles[i]
        if not t then t = panel.art:CreateTexture(nil, "BACKGROUND", nil, 1); panel.tiles[i] = t end
        local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
        t:SetTexture(file)
        t:SetSize(ly.tileWidth * sx, ly.tileHeight * sy)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", panel.art, "TOPLEFT", c * ly.tileWidth * sx, -r * ly.tileHeight * sy)
        t:SetVertexColor(0.86, 0.82, 0.78, 1)
        t:Show()
    end
    panel.noArt:Hide()

    -- 밝혀진 지도: 가 본 곳(게임) + 안 가 본 곳(밝힌 지도 자료)을 모두 덮어요
    panel.ov = panel.ov or {}
    for _, t in ipairs(panel.ov) do t:Hide() end
    local TW, TH = ly.tileWidth or 256, ly.tileHeight or 256
    local n = 0
    local function fileSize(px)
        local f = 16
        while f < px do f = f * 2 end
        return f
    end
    local function Draw(width, height, offX, offY, files)
        local wide, tall = math.ceil(width / TW), math.ceil(height / TH)
        for j = 1, tall do
            local ph, fh
            if j < tall then ph, fh = TH, TH
            else ph = height % TH; if ph == 0 then ph = TH end; fh = fileSize(ph) end
            for k = 1, wide do
                local pw, fw
                if k < wide then pw, fw = TW, TW
                else pw = width % TW; if pw == 0 then pw = TW end; fw = fileSize(pw) end
                local file = files[(j - 1) * wide + k]
                if file then
                    n = n + 1
                    local t = panel.ov[n]
                    if not t then t = panel.art:CreateTexture(nil, "BACKGROUND", nil, 2); panel.ov[n] = t end
                    t:SetTexture(file, nil, nil, "TRILINEAR")
                    t:SetTexCoord(0, pw / fw, 0, ph / fh)
                    t:SetSize(pw * sx, ph * sy)
                    t:ClearAllPoints()
                    t:SetPoint("TOPLEFT", panel.art, "TOPLEFT", (offX + TW * (k - 1)) * sx, -(offY + TH * (j - 1)) * sy)
                    t:SetVertexColor(0.86, 0.82, 0.78, 1)
                    t:Show()
                end
            end
        end
    end
    local done = {}
    if C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures then
        local ok3, list = pcall(C_MapExplorationInfo.GetExploredMapTextures, m)
        if ok3 and type(list) == "table" then
            for _, info in ipairs(list) do
                local w, h, x, y = info.textureWidth or 0, info.textureHeight or 0, info.offsetX or 0, info.offsetY or 0
                done[w .. ":" .. h .. ":" .. x .. ":" .. y] = true
                Draw(w, h, x, y, info.fileDataIDs or {})
            end
        end
    end
    local artID = C_Map.GetMapArtID and select(2, pcall(C_Map.GetMapArtID, m))
    local zone = ns.reveal and artID and ns.reveal[artID]
    if zone then
        for key, files in pairs(zone) do
            if not done[key] then
                local w, h, x, y = strsplit(":", key)
                local ids = {}
                for id in files:gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
                Draw(tonumber(w), tonumber(h), tonumber(x), tonumber(y), ids)
            end
        end
    end
end

local function MakeMapPanel(parent, w, h)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(w, h)
    if p.SetClipsChildren then p:SetClipsChildren(true) end
    RR(p, 12, { 0.18, 0.23, 0.15 }, "BACKGROUND", 0, 0)
    p.art = CreateFrame("Frame", nil, p); p.art:SetAllPoints()
    p.noArt = Font(p, 12, DIM); p.noArt:SetPoint("CENTER"); p.noArt:SetText("지도를 못 그렸어요")
    local shade = p.art:CreateTexture(nil, "BORDER")
    shade:SetTexture(WHITE); shade:SetAllPoints(); shade:SetVertexColor(0.07, 0.05, 0.05, 0.12)
    p.layer = CreateFrame("Frame", nil, p); p.layer:SetAllPoints(); p.layer:SetFrameLevel(p:GetFrameLevel() + 3)
    p.dots, p.marks = {}, {}
    p.me = p.layer:CreateTexture(nil, "OVERLAY", nil, 3)
    p.me:SetTexture("Interface\\MINIMAP\\MinimapArrow"); p.me:SetSize(22, 22)
    return p
end

local function MapPoint(p, x, y) return x / 100 * p:GetWidth(), -y / 100 * p:GetHeight() end

local function MapMark(p, i)
    local mk = p.marks[i]
    if not mk then
        mk = CreateFrame("Frame", nil, p.layer)
        mk:SetSize(22, 22); mk:SetFrameLevel(p.layer:GetFrameLevel() + 2)
        mk.glow = mk:CreateTexture(nil, "BACKGROUND"); mk.glow:SetTexture(MEDIA .. "circle")
        mk.glow:SetPoint("TOPLEFT", -4, 4); mk.glow:SetPoint("BOTTOMRIGHT", 4, -4)
        mk.disc = mk:CreateTexture(nil, "BORDER"); mk.disc:SetTexture(MEDIA .. "circle"); mk.disc:SetAllPoints()
        mk.n = Num(mk, 13, P.ink); mk.n:SetPoint("CENTER", 0, 0); mk.n:SetShadowColor(0, 0, 0, 0)
        p.marks[i] = mk
    end
    return mk
end

local function MapDots(p, pts)
    local n = 0
    for i = 2, #pts do
        local a, b = pts[i - 1], pts[i]
        local ax, ay = MapPoint(p, a[1], a[2])
        local bx, by = MapPoint(p, b[1], b[2])
        local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
        local cnt = math.floor(len / 9)
        for j = 1, cnt - 1 do
            local t = j / cnt
            n = n + 1
            local d = p.dots[n]
            if not d then
                d = p.layer:CreateTexture(nil, "ARTWORK"); d:SetTexture(MEDIA .. "circle"); d:SetSize(4, 4)
                d:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 0.9); p.dots[n] = d
            end
            d:ClearAllPoints(); d:SetPoint("CENTER", p.layer, "TOPLEFT", ax + (bx - ax) * t, ay + (by - ay) * t); d:Show()
        end
    end
    for i = n + 1, #p.dots do p.dots[i]:Hide() end
end

----------------------------------------------------------------------
-- 고르기 판
----------------------------------------------------------------------
local board
local ROW_H, SEC_H = 44, 24
local zoneSel = nil            -- nil = 알아서 / "all" / "turnin" / 지역 이름
local onlyEasy, onlySolo = false, false
local sortBy = "near"          -- near / xp

local function Visible(e, m)
    if e.failed then return false end
    if onlyEasy then local _, k = Diff(e); if k ~= "easy" then return false end end
    if onlySolo and e.group and e.group > 1 then return false end
    return true
end

-- 퀘스트 일지의 지역 머리별로 할 일 · 보고 수
local function ZoneStats()
    local z, order = {}, {}
    for _, e in ipairs(log) do
        if not e.failed then
            local k = ZoneKey(e)
            if not z[k] then z[k] = { name = k, todo = 0, done = 0 }; order[#order + 1] = z[k] end
            if e.done then z[k].done = z[k].done + 1 else z[k].todo = z[k].todo + 1 end
        end
    end
    return z, order
end

local function HereName()
    return MapName(PlayerMap()) or ZoneText()
end

-- 고른 지역 (안 골랐으면: 지금 지역에 퀘가 있으면 거기, 없으면 할 일이 가장 많은 지역)
local function CurZone()
    if zoneSel then return zoneSel end
    local z, order = ZoneStats()
    local here = HereName()
    if z[here] and (z[here].todo + z[here].done) > 0 then return here end
    local best
    for _, v in ipairs(order) do if v.todo > 0 and (not best or v.todo > best.todo) then best = v end end
    return best and best.name or "all"
end

local function BuildItems()
    local m = PlayerMap()
    local px, py = PlayerXY(m)
    local sel = CurZone()
    local todo, done = {}, {}
    for _, e in ipairs(log) do
        if Visible(e, m) then
            local inSel = sel == "all" or sel == "turnin" or ZoneKey(e) == sel
            if inSel and not (sel == "turnin" and not e.done) then
                local x, y, src = QuestPos(e, m)
                e._x, e._y, e._src = x, y, src
                e._d = (x and px) and ((x - px) ^ 2 + (y - py) ^ 2) or 1e9
                if e.done then done[#done + 1] = e else todo[#todo + 1] = e end
            end
        end
    end
    local function sorter(a, b)
        if sortBy == "xp" then return (a.xp or 0) > (b.xp or 0) end
        if a._d ~= b._d then return a._d < b._d end
        return (a.title or "") < (b.title or "")
    end
    table.sort(todo, sorter); table.sort(done, sorter)
    local items = {}
    local function sec(t, list)
        items[#items + 1] = { sec = t, count = #list }
        for _, e in ipairs(list) do items[#items + 1] = { e = e } end
    end
    local label = (sel == "all" and "모든 지역") or (sel == "turnin" and nil) or sel
    if sel == "turnin" then
        sec("완료한 퀘", done)
    else
        sec(label .. " · 할 일", todo)
        if #done > 0 or sel ~= "all" then sec(label .. " · 완료", done) end
    end
    return items
end

local RefreshBoard, RefreshTracker

-- 퀘스트 포기 (확인 창을 한 번 거쳐요)
local function LeelAbandon(e)
    if not (e and e.title) then return end
    StaticPopupDialogs["LEELQ_ABANDON"] = {
        text = "|cfff2b3c2%s|r\n\n이 퀘스트를 포기할까요?\n진행한 목표와 받은 퀘스트 아이템이 사라져요.",
        button1 = "포기", button2 = "취소",
        OnAccept = function(_, data)
            local q = data
            local ok = false
            -- 새 방식
            if C_QuestLog and C_QuestLog.SetSelectedQuest and C_QuestLog.SetAbandonQuest and C_QuestLog.AbandonQuest and q.id then
                ok = pcall(function()
                    C_QuestLog.SetSelectedQuest(q.id); C_QuestLog.SetAbandonQuest(); C_QuestLog.AbandonQuest()
                end)
            end
            -- 옛 방식 (퀘스트 일지 칸 번호)
            if not ok and SelectQuestLogEntry and SetAbandonQuest and _G.AbandonQuest then
                local idx = q.index
                if q.id and GetQuestLogIndexByID then
                    local okI, r = pcall(GetQuestLogIndexByID, q.id); if okI and r and r > 0 then idx = r end
                end
                if idx then ok = pcall(function() SelectQuestLogEntry(idx); SetAbandonQuest(); _G.AbandonQuest() end) end
            end
            if ok then
                Print(q.title .. " 퀘스트를 포기했어요.")
                if CDB and CDB.sel then CDB.sel[q.id] = nil end
            else
                Print("퀘스트를 포기하지 못했어요. 퀘스트 일지에서 직접 포기해 주세요.")
            end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
    }
    StaticPopup_Show("LEELQ_ABANDON", e.title, nil, { id = e.id, title = e.title, index = e.index })
end

local function Row(i)
    local r = board.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, board.list)
    r:SetHeight(ROW_H)
    r.bg = RR(r, 11, CHIP, "BACKGROUND", 0, 0)
    r.sel = RR(r, 11, P.acc, "BACKGROUND", -1, -1)
    r.ck = CreateFrame("Frame", nil, r); r.ck:SetSize(20, 20); r.ck:SetPoint("LEFT", 10, 0)
    r.ckE = RR(r.ck, 6, P.acc, "ARTWORK", 0, 0)
    r.ckF = RR(r.ck, 5, { 0.173, 0.133, 0.125 }, "ARTWORK", 1, 2)
    r.ckM = r.ck:CreateTexture(nil, "OVERLAY"); r.ckM:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    r.ckM:SetSize(22, 22); r.ckM:SetPoint("CENTER", 1, 0); r.ckM:SetDesaturated(true); r.ckM:SetVertexColor(P.ink[1], P.ink[2], P.ink[3], 1)
    r.title = Font(r, 13, P.tx); r.title:SetPoint("TOPLEFT", 40, -7); r.title:SetJustifyH("LEFT"); r.title:SetWordWrap(false)
    r.sub = Font(r, 11, DIM); r.sub:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -3); r.sub:SetJustifyH("LEFT"); r.sub:SetWordWrap(false)
    r.xp = Num(r, 15, P.accHi); r.xp:SetPoint("RIGHT", -10, 0)
    r.c1 = MakeChip(r); r.c2 = MakeChip(r)
    -- 포기 단추 (오른쪽 끝 작은 X)
    r.ab = CreateFrame("Button", nil, r); r.ab:SetSize(20, 20); r.ab:SetPoint("RIGHT", -6, 0)
    r.ab:SetFrameLevel(r:GetFrameLevel() + 3)
    r.abi = r.ab:CreateTexture(nil, "ARTWORK"); r.abi:SetTexture(MEDIA .. "hb_x"); r.abi:SetSize(11, 11); r.abi:SetPoint("CENTER")
    r.abi:SetVertexColor(0.6, 0.5, 0.48, 1)
    r.ab:SetScript("OnEnter", function(self)
        r.abi:SetVertexColor(1, 0.55, 0.55, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("퀘스트 포기", 1, 0.6, 0.6); GameTooltip:Show()
    end)
    r.ab:SetScript("OnLeave", function() r.abi:SetVertexColor(0.6, 0.5, 0.48, 1); GameTooltip:Hide() end)
    r.ab:SetScript("OnClick", function() local e = r.item and r.item.e; if e then LeelAbandon(e) end end)
    r.qi = r:CreateTexture(nil, "OVERLAY"); r.qi:SetTexture(MEDIA .. "q_turnin"); r.qi:SetSize(19, 19); r.qi:Hide()
    -- 섹션 머리
    r.secText = Font(r, 12, P.tx2); r.secText:SetPoint("LEFT", 4, 0)
    r.secN = MakeChip(r)
    r:RegisterForClicks("LeftButtonUp")
    r:SetScript("OnClick", function(self)
        if self.item and self.item.sec then return end
        local e = self.item and self.item.e
        if not (e and e.id) then return end
        Sel()[e.id] = not Sel()[e.id] or nil
        if CDB.route then CDB.route = BuildOrder() end
        RefreshBoard(); RefreshTracker()
    end)
    r:SetScript("OnEnter", function(self)
        local e = self.item and self.item.e
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(e.title, 1, 0.84, 0.88)
        GameTooltip:AddLine(("레벨 %d%s"):format(e.level or 0, e.zone and (" · " .. e.zone) or ""), 0.84, 0.63, 0.61)
        for _, o in ipairs(e.objs) do
            local t = (o.have and o.need) and ("%s %d/%d"):format(o.text, o.have, o.need) or o.text
            if o.done then GameTooltip:AddLine("(완료) " .. t, 0.6, 0.85, 0.6) else GameTooltip:AddLine("· " .. t, 1, 1, 1) end
        end
        if e.done then GameTooltip:AddLine("완료했어요 · 반납하러 가요", 0.95, 0.7, 0.76) end
        if e.xp then GameTooltip:AddLine("경험치 +" .. (BreakUpLargeNumbers and BreakUpLargeNumbers(e.xp) or e.xp), 1, 0.84, 0.88) end
        local g = guide[e.key]
        if g and g.npc then GameTooltip:AddLine(("준 사람: %s (%s %.0f, %.0f)"):format(g.npc, g.zone or "", g.x or 0, g.y or 0), 0.7, 0.7, 0.7) end
        GameTooltip:AddLine("위치: " .. SRC[e._src or "none"], 0.7, 0.7, 0.7)
        GameTooltip:AddLine("누르면 고르기 / 빼기", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    board.rows[i] = r
    return r
end

local function PaintRow(r, it, w)
    r.item = it
    r:SetWidth(w)
    local isSec = it.sec ~= nil
    for _, t in ipairs(r.bg.tex) do t:SetShown(not isSec) end
    r.ck:SetShown(not isSec); r.title:SetShown(not isSec); r.sub:SetShown(not isSec); r.xp:SetShown(not isSec)
    r.secText:SetShown(isSec)
    if isSec then
        r:SetHeight(SEC_H)
        for _, t in ipairs(r.sel.tex) do t:Hide() end
        r.c1:Hide(); r.c2:Hide(); r.qi:Hide(); r.ab:Hide()
        r.secText:SetText(it.sec)
        r.secN:ClearAllPoints(); r.secN:SetPoint("LEFT", r.secText, "RIGHT", 6, 0)
        r.secN:Set(tostring(it.count), "grey")
        r:SetAlpha(1)
        return
    end
    r.secN:Hide(); r.ab:Show()
    r:SetHeight(ROW_H)
    local e = it.e
    local on = e.id and Sel()[e.id]
    for _, t in ipairs(r.sel.tex) do t:SetShown(on and true or false) end
    r.bg:SetColor(on and { 0.204, 0.149, 0.165 } or CHIP)
    r.ckF:SetColor(on and P.acc or { 0.173, 0.133, 0.125 })
    r.ckM:SetShown(on and true or false)
    r.title:SetText(e.title)
    local prog = Progress(e)
    local where = SRC_ICON[e._src or "none"] .. SRC[e._src or "none"]
    if CurZone() == "all" or CurZone() == "turnin" then where = ZoneKey(e) end
    r.sub:SetText((prog ~= "" and (prog .. " · ") or "") .. where)
    r.xp:SetText("")       -- 목록이 좁아서 경험치는 마우스를 올리면 (툴팁)
    local dt, dk, dc = Diff(e)
    r.c1:ClearAllPoints()
    r.c1:SetPoint("RIGHT", r.ab, "LEFT", -4, 0)
    r.c1:Set(dt, dc or dk)
    if e.done then
        r.c2:Hide()
        r.qi:ClearAllPoints(); r.qi:SetPoint("RIGHT", r.c1, "LEFT", -5, 0); r.qi:Show()
    else r.c2:Hide(); r.qi:Hide() end
    local right = 30 + r.c1:GetWidth() + (r.qi:IsShown() and 24 or 0) + 10
    r.title:SetWidth(w - 40 - right); r.sub:SetWidth(w - 40 - right)
    r:SetAlpha(1)
end

local function PaintList()
    local items = BuildItems()
    board.items = items
    local w = board.list:GetWidth()
    local H = board.list:GetHeight()
    board.offset = math.max(0, math.min(board.offset or 0, #items - 1))
    local y, n = 0, 0
    for i = board.offset + 1, #items do
        local it = items[i]
        local h = it.sec and SEC_H or ROW_H
        if y + h > H then break end
        n = n + 1
        local r = Row(n)
        PaintRow(r, it, w - 6)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", board.list, "TOPLEFT", 0, -y)
        r:Show()
        y = y + h + 6
    end
    for i = n + 1, #board.rows do board.rows[i]:Hide() end
    board.more:SetShown(board.offset + n < #items)
    local any = false
    for _, it in ipairs(items) do if it.e then any = true break end end
    board.empty:SetShown(not any)
end

local function PaintMap()
    local p = board.map
    local m = PlayerMap()
    if p.mapID ~= m then p.mapID = m; PaintMapArt(p, m) end
    local px, py = PlayerXY(m)
    if px then
        p.me:ClearAllPoints(); p.me:SetPoint("CENTER", p.layer, "TOPLEFT", MapPoint(p, px, py))
        if GetPlayerFacing then local f = GetPlayerFacing(); if f then p.me:SetRotation(f) end end
        p.me:Show()
    else p.me:Hide() end
    local order = (CDB.route and #CDB.route > 0) and Route() or nil
    if not order then
        order = {}
        for _, id in ipairs(BuildOrder()) do if byId[id] then order[#order + 1] = byId[id] end end
    end
    local pts = { px and { px, py } or nil }
    if not pts[1] then pts = {} end
    local n = 0
    for i, e in ipairs(order) do
        local x, y = QuestPos(e, m)
        if x then
            n = n + 1
            local mk = MapMark(p, n)
            mk.disc:SetVertexColor(e.done and 0.945 or P.acc[1], e.done and 0.851 or P.acc[2], e.done and 0.541 or P.acc[3], 1)
            mk.glow:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 0.3)
            mk.n:SetText(i)
            -- 같은 자리에 겹치면 살짝 옆으로
            local ox, oy = MapPoint(p, x, y)
            for _, q in ipairs(pts) do
                local qx, qy = MapPoint(p, q[1], q[2])
                if math.abs(qx - ox) < 14 and math.abs(qy - oy) < 14 and q.mark then ox = ox + 16 end
            end
            mk:ClearAllPoints(); mk:SetPoint("CENTER", p.layer, "TOPLEFT", ox, oy); mk:Show()
            pts[#pts + 1] = { x, y, mark = true }
        end
    end
    for i = n + 1, #p.marks do p.marks[i]:Hide() end
    MapDots(p, pts)
    return order
end

local function PaintSummary(order)
    local cnt, mins, xp, unknownXP = #order, 0, 0, false
    local names = {}
    for i, e in ipairs(order) do
        mins = mins + (e.done and 2 or 6)
        if e.xp then xp = xp + e.xp else unknownXP = true end
        if i <= 6 then names[#names + 1] = ("|cfff2b3c2%d|r %s"):format(i, e.done and ("반납 " .. e.title) or e.title) end
    end
    if #order > 6 then names[#names + 1] = ("… +%d"):format(#order - 6) end
    board.sCount:SetText(cnt .. "개")
    board.sTime:SetText(cnt > 0 and ("약 " .. mins .. "분") or "-")
    board.sXP:SetText(xp > 0 and ("+" .. (BreakUpLargeNumbers and BreakUpLargeNumbers(xp) or xp) .. (unknownXP and "+" or "")) or "-")
    local lv = UnitLevel("player") or 1
    local cur, max = UnitXP("player") or 0, UnitXPMax("player") or 1
    if xp > 0 and max > 0 then
        local after = lv + (cur + xp) / max
        board.sLv:SetText(("%d → %.1f"):format(lv, after))
    else board.sLv:SetText(tostring(lv)) end
    board.order:SetText(#names > 0 and table.concat(names, "  →  ") or "왼쪽에서 하고 싶은 퀘를 눌러 골라요.")
    board.go:SetLabel((CDB.route and #CDB.route > 0) and "길 다시 짜기" or "이 길로 출발")
end

local function PaintHead()
    local m = PlayerMap()
    board.title:SetText((MapName(m) or ZoneText()) .. " · Leel Quest")
    local nlog = #log
    local max = (C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()) or MAX_QUESTLOG_QUESTS or 20
    board.cLv:Set("내 레벨 " .. (UnitLevel("player") or 1), "grey")
    board.cLog:Set(("내 퀘스트 %d / %d"):format(nlog, max), "grey")
    for _, f in ipairs(board.filters) do f:Paint() end
end

-- 왼쪽 지역 줄
local function ZoneBtn(i)
    local b = board.zbtn[i]
    if b then return b end
    b = CreateFrame("Button", nil, board.zones)
    b:SetHeight(26)
    b.bg = RR(b, 9, P.acc, "BACKGROUND", 0, 0)
    b.dot = b:CreateTexture(nil, "ARTWORK"); b.dot:SetTexture(MEDIA .. "circle"); b.dot:SetSize(7, 7); b.dot:SetPoint("LEFT", 9, 0)
    b.pin = b:CreateTexture(nil, "ARTWORK"); b.pin:SetTexture(MEDIA .. "pin"); b.pin:SetSize(15, 15); b.pin:SetPoint("LEFT", 6, 0); b.pin:Hide()
    b.fs = Font(b, 13, P.tx); b.fs:SetJustifyH("LEFT"); b.fs:SetWordWrap(false)
    b.tag = MakeChip(b); b.tag:SetHeight(14)
    b.n2 = MakeChip(b); b.n2:SetHeight(16); b.n2:SetPoint("RIGHT", -6, 0)
    b.n1 = MakeChip(b); b.n1:SetHeight(16)
    b.head = Font(b, 11, P.tx2); b.head:SetPoint("BOTTOMLEFT", 9, 3)
    b:SetScript("OnClick", function(self)
        if not self.key then return end
        zoneSel = self.key; board.offset = 0
        RefreshBoard()
    end)
    board.zbtn[i] = b
    return b
end

local function PaintZones()
    local z, order = ZoneStats()
    local here = HereName()
    local cur = CurZone()
    local list = {}
    local tTodo, tDone = 0, 0
    for _, v in ipairs(order) do tTodo = tTodo + v.todo; tDone = tDone + v.done end
    list[#list + 1] = { key = "all", name = "모든 지역", todo = tTodo, done = tDone, dot = { 0.79, 0.7, 0.67 } }
    list[#list + 1] = { key = "turnin", name = "완료한 퀘만", todo = 0, done = tDone, dot = { 0.945, 0.851, 0.541 }, yellow = true }
    -- 지금 있는 곳: 맨 위 따로 칸 (퀘가 없어도 보여요), 아래 목록에는 다시 안 나와요
    local hv = z[here] or { name = here, todo = 0, done = 0 }
    list[#list + 1] = { head = "지금 있는 곳" }
    list[#list + 1] = { key = here, name = here, todo = hv.todo, done = hv.done, here = true }
    local withTodo, onlyDone = {}, {}
    for _, v in ipairs(order) do
        if v.name ~= here then
            if v.todo > 0 then withTodo[#withTodo + 1] = v elseif v.done > 0 then onlyDone[#onlyDone + 1] = v end
        end
    end
    local function byHere(a, b)
        if (a.name == here) ~= (b.name == here) then return a.name == here end
        return (a.todo + a.done) > (b.todo + b.done)
    end
    table.sort(withTodo, byHere); table.sort(onlyDone, byHere)
    if #withTodo > 0 then
        list[#list + 1] = { head = "할 일이 있는 지역" }
        for _, v in ipairs(withTodo) do list[#list + 1] = { key = v.name, name = v.name, todo = v.todo, done = v.done } end
    end
    if #onlyDone > 0 then
        list[#list + 1] = { head = "완료만 있는 지역" }
        for _, v in ipairs(onlyDone) do list[#list + 1] = { key = v.name, name = v.name, todo = 0, done = v.done } end
    end
    local y, H = 0, board.zones:GetHeight()
    local W = board.zones:GetWidth()
    local n = 0
    for _, it in ipairs(list) do
        local h = it.head and 22 or 26
        if it.here then y = y + 3 end
        if y + h > H then break end
        n = n + 1
        local b = ZoneBtn(n)
        b.key = it.key
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", board.zones, "TOPLEFT", 0, -y); b:SetSize(W, h)
        if it.head then
            for _, t in ipairs(b.bg.tex) do t:Hide() end
            b.dot:Hide(); b.fs:Hide(); b.tag:Hide(); b.n1:Hide(); b.n2:Hide()
            b.head:SetText(it.head); b.head:Show()
            b:EnableMouse(false)
        else
            b:EnableMouse(true)
            b.head:Hide(); b.fs:Show()
            local on = (it.key == cur)
            for _, t in ipairs(b.bg.tex) do t:SetShown(on) end
            local c = on and P.ink or (it.yellow and { 0.945, 0.851, 0.541 } or P.tx)
            b.fs:SetTextColor(c[1], c[2], c[3]); b.fs:SetShadowColor(0, 0, 0, on and 0 or 0.85)
            b.fs:SetText(it.name)
            b.pin:Hide()
            if it.here then
                b.dot:Hide(); b.pin:Show()
                local pc = on and P.ink or P.acc
                b.pin:SetVertexColor(pc[1], pc[2], pc[3], 1)
                b.fs:ClearAllPoints(); b.fs:SetPoint("LEFT", b.pin, "RIGHT", 5, 0)
            elseif it.dot then
                b.dot:SetVertexColor(it.dot[1], it.dot[2], it.dot[3], 1); b.dot:Show()
                b.fs:ClearAllPoints(); b.fs:SetPoint("LEFT", b.dot, "RIGHT", 6, 0)
            else
                b.dot:Hide(); b.fs:ClearAllPoints(); b.fs:SetPoint("LEFT", 9, 0)
            end
            if it.here and it.todo + it.done == 0 then
                b.fs:SetText(it.name .. "  |cff8a7a76할 퀘 없음|r")
            end
            -- 숫자: 초록 = 할 일, 노랑 = 보고
            local right = b
            if it.done > 0 then b.n2:Set(tostring(it.done), "mid"); right = b.n2 else b.n2:Hide() end
            if it.todo > 0 then
                b.n1:ClearAllPoints()
                if right == b then b.n1:SetPoint("RIGHT", -6, 0) else b.n1:SetPoint("RIGHT", right, "LEFT", -3, 0) end
                b.n1:Set(tostring(it.todo), "easy")
            else b.n1:Hide() end
            b.tag:Hide()
            local used = (b.n1:IsShown() and b.n1:GetWidth() + 4 or 0) + (b.n2:IsShown() and b.n2:GetWidth() + 4 or 0) + (b.tag:IsShown() and b.tag:GetWidth() + 6 or 0)
            b.fs:SetWidth(math.min(b.fs:GetStringWidth() + 2, W - 30 - used))
        end
        b:Show()
        y = y + h + 2 + (it.here and 6 or 0)
    end
    for i = n + 1, #board.zbtn do board.zbtn[i]:Hide() end
    -- 지금 있는 곳 칸: 점선 상자
    local box = board.hereBox
    if not box then
        box = CreateFrame("Frame", nil, board.zones)
        box.d = {}
        local W2, H2 = board.zones:GetWidth() + 6, 32
        local function dash(x, y, w, h)
            local t = box:CreateTexture(nil, "OVERLAY"); t:SetTexture(WHITE)
            t:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 0.6); t:SetSize(w, h); t:SetPoint("TOPLEFT", x, -y)
        end
        for x = 6, W2 - 10, 9 do dash(x, 0, 5, 1.2); dash(x, H2 - 1.2, 5, 1.2) end
        for y = 6, H2 - 10, 9 do dash(0, y, 1.2, 5); dash(W2 - 1.2, y, 1.2, 5) end
        box:SetSize(W2, H2)
        board.hereBox = box
    end
    box:Hide()
    for i = 1, n do
        local b = board.zbtn[i]
        if b.key == here and b:IsShown() and b.fs:IsShown() and b.pin:IsShown() then
            box:ClearAllPoints(); box:SetPoint("CENTER", b, "CENTER", 0, 0); box:Show()
            break
        end
    end
end

RefreshBoard = function()
    if not (board and board:IsShown()) then return end
    PaintHead()
    PaintZones()
    PaintList()
    local order = PaintMap()
    PaintSummary(order)
end

local function Toggle(btn, label, get, set)
    local b = CreateFrame("Button", nil, board)
    b:SetHeight(24)
    b.bg = RR(b, 9, CHIP, "BACKGROUND", 0, 0)
    b.fs = Font(b, 12, P.tx); b.fs:SetPoint("CENTER", 0, 0); b.fs:SetText(label)
    b:SetWidth(b.fs:GetStringWidth() + 22)
    function b:Paint()
        local on = get()
        self.bg:SetColor(on and P.acc or CHIP)
        self.fs:SetTextColor(on and P.ink[1] or P.tx[1], on and P.ink[2] or P.tx[2], on and P.ink[3] or P.tx[3])
        self.fs:SetShadowColor(0, 0, 0, on and 0 or 0.85)
    end
    b:SetScript("OnClick", function() set(); board.offset = 0; RefreshBoard() end)
    b:SetScript("OnEnter", function(self) if not get() then self.bg:SetColor({ 0.26, 0.19, 0.18 }) end end)
    b:SetScript("OnLeave", function(self) self:Paint() end)
    board.filters[#board.filters + 1] = b
    return b
end

local function Start()
    CDB.route = BuildOrder()
    CDB.total = #CDB.route
    if #CDB.route == 0 then Print("먼저 하고 싶은 퀘를 골라요.") return end
    -- 따라가기 창이 보이게 르엘 UI 퀘스트 목록을 "르엘 퀘스트 판"으로
    if L and L.QuestTrackerMode and L.QuestTrackerMode() ~= "guide" and L.SetQuestTrackerMode then
        L:SetQuestTrackerMode("guide")
        Print("화면 퀘스트 목록을 르엘 퀘스트 판으로 바꿨어요. (허브 > 퀘스트 목록에서 바꿀 수 있어요)")
    end
    local trk = _G.ForgLevelingFrame
    if trk then trk:Show() end
    RefreshTracker(); RefreshBoard()
end

-- 토끼 추천: 이 지도에서 낮은 레벨 퀘부터, 근처(150m)에서 같이 할 수 있는 어렵지 않은 퀘를 묶어서
local REC_NEAR = 150
local function FillGuide()
    local m = PlayerMap()
    local px, py = PlayerXY(m)
    local lv = UnitLevel("player") or 1
    local grey = lv - ((GetQuestGreenRange and GetQuestGreenRange()) or 7) - 1   -- 이 레벨 이하 = 회색
    local function dist(ax, ay, bx, by)
        local yd = Yards(m, ax, ay, bx, by)
        return yd or (math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) * 15)
    end
    local pool, greys, dones = {}, {}, {}
    for _, e in ipairs(log) do
        if e.id and not e.failed then
            local x, y = QuestPos(e, m)
            if x then
                local it = { e = e, x = x, y = y }
                if e.done then dones[#dones + 1] = it
                else
                    local _, k = Diff(e)
                    if k ~= "hard" then                         -- 어려움(+3 이상) · 파티는 빼요
                        if (e.level or 0) <= grey then greys[#greys + 1] = it else pool[#pool + 1] = it end
                    end
                end
            end
        end
    end
    local order, bundles = {}, 0
    local cx, cy = px or 50, py or 50
    local function take(list, i) local it = table.remove(list, i); order[#order + 1] = it.e.id; return it end
    while #pool > 0 do
        -- 시작 퀘: 레벨 × 300 + 거리 가 가장 작은 것 (레벨이 1 낮으면 300m 더 멀어도 먼저)
        local bi, bs
        for i, it in ipairs(pool) do
            local sc = (it.e.level or 0) * 300 + dist(cx, cy, it.x, it.y)
            if not bs or sc < bs then bi, bs = i, sc end
        end
        local anchor = take(pool, bi)
        bundles = bundles + 1
        local members = { anchor }
        -- 근처 묶기: 같은 몹(목표 이름이 같은 퀘) 먼저, 그다음 가까운 순
        local function near(list)
            local found = {}
            for i, it in ipairs(list) do
                if dist(anchor.x, anchor.y, it.x, it.y) <= REC_NEAR then found[#found + 1] = i end
            end
            return found
        end
        local function sameMob(it)
            for _, o in ipairs(it.e.objs) do
                for _, ao in ipairs(anchor.e.objs) do if o.text == ao.text then return true end end
            end
            return false
        end
        for _, list in ipairs({ pool, greys }) do
            local idx = near(list)
            table.sort(idx, function(a, b)
                local sa, sb = sameMob(list[a]), sameMob(list[b])
                if sa ~= sb then return sa end
                return dist(anchor.x, anchor.y, list[a].x, list[a].y) < dist(anchor.x, anchor.y, list[b].x, list[b].y)
            end)
            local picked = {}
            for _, i in ipairs(idx) do picked[#picked + 1] = list[i] end
            for _, it in ipairs(picked) do
                for j, it2 in ipairs(list) do if it2 == it then table.remove(list, j) break end end
                order[#order + 1] = it.e.id; members[#members + 1] = it
            end
        end
        -- 이 묶음 근처에서 반납할 완료 퀘도 같이
        for i = #dones, 1, -1 do
            local it = dones[i]
            for _, mb in ipairs(members) do
                if dist(mb.x, mb.y, it.x, it.y) <= REC_NEAR then
                    table.remove(dones, i); order[#order + 1] = it.e.id
                    break
                end
            end
        end
        cx, cy = anchor.x, anchor.y
    end
    -- 남은 완료 퀘(이 지도에서 반납)는 맨 끝에 가까운 순
    table.sort(dones, function(a, b) return dist(cx, cy, a.x, a.y) < dist(cx, cy, b.x, b.y) end)
    for _, it in ipairs(dones) do order[#order + 1] = it.e.id end

    if #order == 0 then
        Print("토끼 추천: 이 지도엔 지금 추천할 퀘가 없어요. (어려움 · 파티 퀘는 빼요)")
        return
    end
    CDB.sel = {}
    local doneNow = {}
    for _, id in ipairs(order) do
        CDB.sel[id] = true
        if byId[id] and byId[id].done then doneNow[id] = true end
    end
    CDB.rec = { order = order, done = doneNow, map = m }
    CDB.route = BuildOrder()
    CDB.total = #CDB.route
    Print(("토끼 추천: 낮은 레벨부터 묶음 %d개 · 퀘 %d개를 골랐어요."):format(bundles, #order))
    RefreshBoard(); RefreshTracker()
end

local function MakeBoard()
    if board then return board end
    board = CreateFrame("Frame", "LeelQuestBoard", UIParent)
    board:SetSize(1040, 600)
    board:SetFrameStrata("HIGH")
    board:SetToplevel(true)
    board:SetClampedToScreen(true)
    board:EnableMouse(true); board:SetMovable(true)
    board:RegisterForDrag("LeftButton")
    board:SetScript("OnDragStart", board.StartMoving)
    board:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local pt, _, rp, x, y = self:GetPoint()
        DB.boardPos = { pt, rp, x, y }
    end)
    local bp = DB.boardPos
    if bp then board:SetPoint(bp[1], UIParent, bp[2], bp[3], bp[4]) else board:SetPoint("CENTER", 0, 30) end
    Plate(board, 20, { 0.114, 0.082, 0.078, 0.97 }, { P.acc[1], P.acc[2], P.acc[3], 0.6 })
    tinsert(UISpecialFrames, "LeelQuestBoard")
    board.rows, board.filters, board.zbtn = {}, {}, {}

    -- 머리
    local bun = CreateFrame("Frame", nil, board); bun:SetSize(30, 30); bun:SetPoint("TOPLEFT", 18, -14)
    local bd = bun:CreateTexture(nil, "ARTWORK"); bd:SetTexture(MEDIA .. "circle"); bd:SetAllPoints(); bd:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 1)
    local bi = bun:CreateTexture(nil, "OVERLAY"); bi:SetTexture(MEDIA .. "bunny"); bi:SetAllPoints()
    board.title = Font(board, 19, P.tx); board.title:SetPoint("LEFT", bun, "RIGHT", 10, 0)
    board.cLv = MakeChip(board); board.cLv:SetPoint("LEFT", board.title, "RIGHT", 10, 0)
    local close = CreateFrame("Button", nil, board); close:SetSize(26, 26); close:SetPoint("TOPRIGHT", -16, -16)
    RR(close, 8, CHIP, "BACKGROUND", 0, 0)
    local cx = close:CreateTexture(nil, "ARTWORK"); cx:SetTexture(MEDIA .. "hb_x"); cx:SetSize(14, 14); cx:SetPoint("CENTER")
    cx:SetVertexColor(P.tx2[1], P.tx2[2], P.tx2[3], 1)
    close:SetScript("OnClick", function() board:Hide() end)
    board.cLog = MakeChip(board); board.cLog:SetPoint("RIGHT", close, "LEFT", -10, 0)

    -- 왼쪽 지역 줄 (퀘스트 일지의 지역 머리처럼)
    board.zones = CreateFrame("Frame", nil, board)
    board.zones:SetPoint("TOPLEFT", 18, -56)
    board.zones:SetSize(196, 526)
    local zl = board:CreateTexture(nil, "ARTWORK"); zl:SetTexture(WHITE)
    zl:SetPoint("TOPLEFT", board.zones, "TOPRIGHT", 8, 0); zl:SetPoint("BOTTOMLEFT", board.zones, "BOTTOMRIGHT", 8, 0); zl:SetWidth(1)
    zl:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 0.15)

    -- 가운데 위: 거르기 + 정렬
    local fx = 232
    local function place(b) b:SetPoint("TOPLEFT", board, "TOPLEFT", fx, -56); fx = fx + b:GetWidth() + 6 end
    place(Toggle(nil, "쉬움만", function() return onlyEasy end, function() onlyEasy = not onlyEasy end))
    place(Toggle(nil, "혼자 가능", function() return onlySolo end, function() onlySolo = not onlySolo end))
    -- 토끼 추천: 고른 지역에서 forg.gg 레벨링 길에 나오는 퀘만 체크
    local rec = Toggle(nil, "토끼 추천", function() return false end, FillGuide)
    local ri = rec:CreateTexture(nil, "ARTWORK"); ri:SetTexture(MEDIA .. "bunny"); ri:SetSize(16, 16); ri:SetPoint("LEFT", 8, 0)
    rec.fs:ClearAllPoints(); rec.fs:SetPoint("LEFT", ri, "RIGHT", 5, 0)
    rec:SetWidth(rec.fs:GetStringWidth() + 16 + 5 + 18)
    rec:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText("토끼 추천")
        GameTooltip:AddLine("이 지도에서 낮은 레벨 퀘부터 골라요", 1, 1, 1)
        GameTooltip:AddLine("근처(150m)에서 같이 할 수 있는 쉬움 · 보통 퀘를 묶어요", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("어려움(+3 레벨) · 파티 퀘는 빼요 · 근처 완료 퀘는 같이 반납", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)
    rec:HookScript("OnLeave", function() GameTooltip:Hide() end)
    place(rec)
    local sx = -18
    local s2 = Toggle(nil, "경험치 순", function() return sortBy == "xp" end, function() sortBy = "xp" end)
    s2:SetPoint("TOPRIGHT", board, "TOPRIGHT", sx, -56); sx = sx - s2:GetWidth() - 6
    local s1 = Toggle(nil, "가까운 순", function() return sortBy == "near" end, function() sortBy = "near" end)
    s1:SetPoint("TOPRIGHT", board, "TOPRIGHT", sx, -56)

    -- 가운데 목록
    board.list = CreateFrame("Frame", nil, board)
    board.list:SetPoint("TOPLEFT", 232, -92)
    board.list:SetSize(372, 490)
    board.list:EnableMouseWheel(true)
    board.list:SetScript("OnMouseWheel", function(_, d)
        board.offset = math.max(0, (board.offset or 0) - d * 2)
        PaintList()
    end)
    board.more = Font(board, 11, DIM); board.more:SetPoint("BOTTOM", board.list, "BOTTOM", 0, -4); board.more:SetText("휠을 굴리면 더 있어요")
    board.empty = Font(board.list, 13, DIM); board.empty:SetPoint("TOP", 0, -60)
    board.empty:SetText("여기엔 퀘가 없어요.\n왼쪽에서 다른 지역을 골라 보세요.")

    -- 오른쪽 지도
    board.map = MakeMapPanel(board, 402, 268)
    board.map:SetPoint("TOPRIGHT", -18, -92)

    -- 요약
    local sum = CreateFrame("Frame", nil, board)
    sum:SetPoint("TOPLEFT", board.map, "BOTTOMLEFT", 0, -10); sum:SetPoint("TOPRIGHT", board.map, "BOTTOMRIGHT", 0, -10)
    sum:SetHeight(210)
    RR(sum, 13, { 0.141, 0.106, 0.102 }, "BACKGROUND", 0, 0)
    local function stat(x, label)
        local l = Font(sum, 11, DIM); l:SetPoint("TOPLEFT", x, -12); l:SetText(label)
        local v = Font(sum, 20, P.tx); v:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -4)
        return v
    end
    board.sCount = stat(14, "고른 퀘"); board.sTime = stat(90, "예상 시간"); board.sXP = stat(196, "경험치"); board.sLv = stat(300, "레벨")
    board.order = Font(sum, 12, P.tx); board.order:SetPoint("TOPLEFT", 14, -66); board.order:SetPoint("RIGHT", -14, 0)
    board.order:SetJustifyH("LEFT"); board.order:SetSpacing(4)
    board.go = Button(sum, "이 길로 출발", true, Start, 120)
    board.go:SetPoint("BOTTOMLEFT", 14, 14)
    local clear = Button(sum, "모두 빼기", false, function()
        CDB.sel = {}; CDB.route = nil; CDB.rec = nil; RefreshBoard(); RefreshTracker()
    end)
    clear:SetPoint("LEFT", board.go, "RIGHT", 8, 0)
    local legend = Font(sum, 10.5, DIM); legend:SetPoint("BOTTOMLEFT", 14, 50); legend:SetJustifyH("LEFT")
    legend:SetText(SRC_ICON.questie .. "Questie  " .. SRC_ICON.learned .. "잡던 곳  " .. SRC_ICON.game .. "게임 표시  " .. SRC_ICON.guide .. "길잡이 자료")

    board:SetScript("OnShow", function() board.map.mapID = nil; zoneSel = nil; board.offset = 0; ReadLog(); RefreshBoard() end)
    local acc = 0
    board:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc > 0.25 then acc = 0; PaintMap() end
    end)
    board:Hide()
    return board
end

local function ToggleBoard()
    MakeBoard()
    board:SetShown(not board:IsShown())
end

----------------------------------------------------------------------
-- 따라가기 창 (르엘 UI 퀘스트 목록 "르엘 퀘스트 판" 자리 = ForgLevelingFrame)
----------------------------------------------------------------------
local trk
local NearTurnins, Toast, NearToast   -- 아래에서 채워요
local MAXQ = 8                 -- 한 번에 보이는 퀘 수 (손잡이로 길이를 정하면 그만큼)
local YEL = { 0.945, 0.851, 0.541 }

local function ShowQuest(e)
    if QuestLogFrame and e.index and SelectQuestLogEntry then
        pcall(SelectQuestLogEntry, e.index); ShowUIPanel(QuestLogFrame)
        if QuestLog_UpdateQuestDetails then pcall(QuestLog_UpdateQuestDetails) end
    end
end

local function MakeRow(i)
    local r = CreateFrame("Button", nil, trk)
    r:SetHeight(20)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- 번호 (분홍 동그라미, 보고할 퀘는 노란 ?)
    r.n = CreateFrame("Frame", nil, r); r.n:SetSize(20, 20); r.n:SetPoint("TOPLEFT", 0, 0)
    r.glow = r.n:CreateTexture(nil, "BACKGROUND"); r.glow:SetTexture(MEDIA .. "circle")
    r.glow:SetPoint("TOPLEFT", -4, 4); r.glow:SetPoint("BOTTOMRIGHT", 4, -4)
    r.glow:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 0.35)
    r.edge = r.n:CreateTexture(nil, "BORDER"); r.edge:SetTexture(MEDIA .. "circle"); r.edge:SetAllPoints(); r.edge:SetVertexColor(0, 0, 0, 0.8)
    r.disc = r.n:CreateTexture(nil, "ARTWORK"); r.disc:SetTexture(MEDIA .. "circle")
    r.disc:SetPoint("TOPLEFT", 1.5, -1.5); r.disc:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
    r.nt = Num(r.n, 13, P.ink); r.nt:SetPoint("CENTER", 0, 0); r.nt:SetShadowColor(0, 0, 0, 0)
    r.qi = r.n:CreateTexture(nil, "OVERLAY"); r.qi:SetTexture(MEDIA .. "q_turnin"); r.qi:SetAllPoints(); r.qi:Hide()
    r.title = Font(r, 15, P.tx); r.title:SetPoint("TOPLEFT", 28, -1); r.title:SetJustifyH("LEFT"); r.title:SetWordWrap(false)
    r.title:SetShadowColor(0, 0, 0, 1); r.title:SetShadowOffset(1, -1)
    r.arrow = r:CreateTexture(nil, "OVERLAY"); r.arrow:SetTexture("Interface\\MINIMAP\\MinimapArrow")
    -- 난이도 작은 알약 (쉬움 · 보통 · 어려움 · 파티)
    r.diff = MakeChip(r); r.diff:SetHeight(16); r.diff:SetPoint("LEFT", r.title, "RIGHT", 6, 0)
    r.arrow:SetSize(18, 18); r.arrow:SetPoint("LEFT", r.diff, "RIGHT", 4, 0); r.arrow:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 1)
    r.dist = Num(r, 14, P.accHi); r.dist:SetPoint("LEFT", r.arrow, "RIGHT", 1, 0)
    r.objs = {}
    r:SetScript("OnClick", function(self, btn)
        local e = self.e
        if not e then return end
        if btn == "RightButton" then
            -- 오른쪽 클릭: 이번 길에서 빼기 (퀘스트 포기는 고르기 판에서)
            Sel()[e.id] = nil
            CDB.route = BuildOrder()
            Print(e.title .. " 를 이번 길에서 뺐어요.")
            RefreshTracker(); RefreshBoard()
        elseif IsShiftKeyDown() and ChatEdit_InsertLink and GetQuestLink then
            local ok, link = pcall(GetQuestLink, e.id); if ok and link then ChatEdit_InsertLink(link) end
        else
            ShowQuest(e)
        end
    end)
    r:SetScript("OnEnter", function(self)
        if not self.e then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(self.e.title, 1, 0.84, 0.88)
        local _, _, src = QuestPos(self.e, PlayerMap())
        GameTooltip:AddLine("위치: " .. SRC[src or "none"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine("클릭: 퀘스트 보기 · 오른쪽 클릭: 이번 길에서 빼기", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    trk.rows[i] = r
    return r
end

local function ObjLine(r, j)
    local fs = r.objs[j]
    if not fs then
        fs = Font(r, 12, DIM); fs:SetJustifyH("LEFT"); fs:SetWordWrap(true); fs:SetNonSpaceWrap(true); fs:SetSpacing(2); if fs.SetMaxLines then fs:SetMaxLines(4) end
        fs:SetShadowColor(0, 0, 0, 1); fs:SetShadowOffset(1, -1)
        r.objs[j] = fs
    end
    return fs
end

local function MakeTracker()
    trk = CreateFrame("Frame", "ForgLevelingFrame", UIParent)
    trk:SetSize(DB.trkW or 290, 60)
    -- 자리는 항상 "왼쪽 위 모서리" 기준으로 저장 → 접거나 길이가 바뀌어도 위쪽이 그 자리에 그대로
    function trk.SavePos()
        local us, ts = UIParent:GetEffectiveScale(), trk:GetEffectiveScale()
        local l, t = trk:GetLeft(), trk:GetTop()
        if not (l and t) then return end
        l, t = l * ts / us, t * ts / us
        DB.trkPos = { "TOPLEFT", "BOTTOMLEFT", math.floor(l + 0.5), math.floor(t + 0.5) }
        trk:ClearAllPoints()
        trk:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", DB.trkPos[3], DB.trkPos[4])
    end
    trk:SetFrameStrata("MEDIUM")
    trk:SetClampedToScreen(true)
    trk:SetMovable(true)
    trk.rows = {}
    trk.offset = 0

    -- 머리: Leel Quest  3 / 11  [−]   (머리를 끌면 옮겨져요)
    local head = CreateFrame("Frame", nil, trk)
    head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT"); head:SetHeight(28)
    head:EnableMouse(true); head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() trk:StartMoving() end)
    head:SetScript("OnDragStop", function()
        trk:StopMovingOrSizing()
        trk.SavePos()
    end)
    head:SetScript("OnMouseUp", function(_, b) if b == "RightButton" then ToggleBoard() end end)
    -- 토끼 마크 (누르면 고르기 판)
    local bun = CreateFrame("Button", nil, head); bun:SetSize(26, 26); bun:SetPoint("LEFT", 0, 0)
    local bg = bun:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(MEDIA .. "circle")
    bg:SetPoint("TOPLEFT", -1.5, 1.5); bg:SetPoint("BOTTOMRIGHT", 1.5, -1.5); bg:SetVertexColor(0, 0, 0, 0.8)
    local bd = bun:CreateTexture(nil, "BORDER"); bd:SetTexture(MEDIA .. "circle"); bd:SetAllPoints()
    bd:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 1)
    local bi = bun:CreateTexture(nil, "ARTWORK"); bi:SetTexture(MEDIA .. "bunny"); bi:SetAllPoints()
    local bh = bun:CreateTexture(nil, "HIGHLIGHT"); bh:SetTexture(MEDIA .. "circle"); bh:SetAllPoints()
    bh:SetVertexColor(1, 1, 1, 0.25); bh:SetBlendMode("ADD")
    bun:SetScript("OnClick", ToggleBoard)
    bun:RegisterForDrag("LeftButton")
    bun:SetScript("OnDragStart", function() trk:StartMoving() end)
    bun:SetScript("OnDragStop", function()
        trk:StopMovingOrSizing()
        trk.SavePos()
    end)
    bun:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText("Leel Quest")
        GameTooltip:AddLine("클릭: 고르기 판 · 끌기: 창 옮기기", 0.8, 0.8, 0.8); GameTooltip:Show()
    end)
    bun:SetScript("OnLeave", function() GameTooltip:Hide() end)
    trk.title = Font(head, 17, P.acc); trk.title:SetPoint("LEFT", bun, "RIGHT", 7, 0); trk.title:SetText("Leel Quest")
    trk.title:SetShadowColor(0, 0, 0, 1)
    trk.count = Font(head, 12, P.tx2); trk.count:SetPoint("LEFT", trk.title, "RIGHT", 8, -1)
    trk.count:SetShadowColor(0, 0, 0, 1)
    local mini = CreateFrame("Button", nil, head); mini:SetSize(18, 18); mini:SetPoint("RIGHT", 0, 0)
    RR(mini, 4, { 0.114, 0.082, 0.078, 0.6 }, "BACKGROUND", 0, 0)
    local me = RR(mini, 4, P.acc, "BACKGROUND", -1, -1)
    local mt = mini:CreateTexture(nil, "ARTWORK"); mt:SetTexture(WHITE); mt:SetSize(9, 2); mt:SetPoint("CENTER")
    mt:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 1)
    local mv = mini:CreateTexture(nil, "ARTWORK"); mv:SetTexture(WHITE); mv:SetSize(2, 9); mv:SetPoint("CENTER")
    mv:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 1)
    trk.miniV = mv
    mini:SetScript("OnClick", function() DB.trkFold = not DB.trkFold; RefreshTracker() end)
    mini:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText(DB.trkFold and "펼치기" or "접기")
        GameTooltip:AddLine("머리를 끌면 옮기기 · 오른쪽 클릭: 고르기 판", 0.75, 0.75, 0.75); GameTooltip:Show()
    end)
    mini:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local line = trk:CreateTexture(nil, "ARTWORK"); line:SetTexture(WHITE)
    line:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2); line:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, -2); line:SetHeight(1)
    line:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 0.35)
    trk.head = head

    -- 알림 띠 (새 지역 도착 · 새 퀘): 제목 바로 아래 분홍 띠, 8초 뒤 접혀요
    local band = CreateFrame("Frame", nil, trk)
    band:SetHeight(26)
    band:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6); band:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, -6)
    Plate(band, 9, { 0.114, 0.082, 0.078, 0.96 }, { P.acc[1], P.acc[2], P.acc[3], 0.75 })
    band.t = Font(band, 12.5, P.accHi); band.t:SetPoint("LEFT", 9, 0); band.t:SetJustifyH("LEFT"); band.t:SetWordWrap(false)
    band.s = Font(band, 12, P.tx); band.s:SetPoint("LEFT", band.t, "RIGHT", 7, 0); band.s:SetJustifyH("LEFT"); band.s:SetWordWrap(false)
    -- 띠 안에 맞는 작은 분홍 알약 단추
    local bb = CreateFrame("Button", nil, band)
    bb:SetHeight(18); bb:SetPoint("RIGHT", -5, 0)
    bb.bg = RR(bb, 9, P.acc, "ARTWORK", 0, 0)
    bb.fs = Font(bb, 11.5, P.ink); bb.fs:SetPoint("CENTER", 0, 0); bb.fs:SetShadowColor(0, 0, 0, 0)
    function bb:SetLabel(t)
        self.fs:SetText(t)
        local w = 0
        pcall(function() w = self.fs:GetStringWidth() end)
        if type(w) ~= "number" or w <= 0 then w = 40 end
        self:SetWidth(w + 18)
    end
    bb:SetScript("OnEnter", function(self) self.bg:SetColor(P.accHi) end)
    bb:SetScript("OnLeave", function(self) self.bg:SetColor(P.acc) end)
    bb:SetLabel("고르기")
    band.b = bb
    band.s:SetPoint("RIGHT", band.b, "LEFT", -6, 0)
    band:EnableMouse(true)
    band:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText(self.full1 or "", P.accHi[1], P.accHi[2], P.accHi[3])
        if self.full2 then GameTooltip:AddLine(self.full2, 1, 1, 1, true) end
        GameTooltip:AddLine("오른쪽 클릭: 닫기", 0.7, 0.7, 0.7)
        GameTooltip:Show()
        self.hover = true
    end)
    band:SetScript("OnLeave", function(self) GameTooltip:Hide(); self.hover = false end)
    band:SetScript("OnMouseUp", function(self, btn) if btn == "RightButton" then self:Hide(); RefreshTracker() end end)
    band:SetScript("OnUpdate", function(self, el)
        if self.hover then return end
        self.left = (self.left or 0) - el
        if self.left <= 0 then self:Hide(); RefreshTracker() end
    end)
    band:Hide()
    trk.band = band

    -- 근처 반납 노란 띠 (누르면 그 퀘들을 길 맨 앞으로)
    local near = CreateFrame("Button", nil, trk)
    near:SetHeight(24)
    near:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6); near:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, -6)
    local nb = near:CreateTexture(nil, "BACKGROUND"); nb:SetTexture(WHITE); nb:SetAllPoints()
    nb:SetVertexColor(0.945, 0.851, 0.541, 0.2)
    if CreateColor then
        pcall(nb.SetGradient, nb, "HORIZONTAL", CreateColor(0.945, 0.851, 0.541, 0.32), CreateColor(0.945, 0.851, 0.541, 0.04))
    end
    local nl = near:CreateTexture(nil, "ARTWORK"); nl:SetTexture(WHITE); nl:SetWidth(3)
    nl:SetPoint("TOPLEFT"); nl:SetPoint("BOTTOMLEFT"); nl:SetVertexColor(0.945, 0.851, 0.541, 1)
    local nq = near:CreateTexture(nil, "ARTWORK"); nq:SetTexture(MEDIA .. "q_turnin"); nq:SetSize(18, 18); nq:SetPoint("LEFT", 8, 0)
    near.t = Font(near, 12.5, { 1, 0.95, 0.8 }); near.t:SetPoint("LEFT", nq, "RIGHT", 6, 0); near.t:SetJustifyH("LEFT"); near.t:SetWordWrap(false)
    near.t:SetPoint("RIGHT", -50, 0); near.t:SetShadowColor(0, 0, 0, 1)
    near.d = Num(near, 14, P.accHi); near.d:SetPoint("RIGHT", -6, 0)
    near:SetScript("OnClick", function() if trk.PullNear then trk.PullNear() end end)
    near:SetScript("OnEnter", function(self)
        local g = trk.nearG
        if not g then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText(g.npc .. " 에게 반납", 1, 0.95, 0.8)
        for _, e in ipairs(g.list) do GameTooltip:AddLine("· " .. e.title, 1, 1, 1) end
        GameTooltip:AddLine("누르면 길 맨 앞으로", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)
    near:SetScript("OnLeave", function() GameTooltip:Hide() end)
    near:Hide()
    trk.near = near
    function trk.PullNear()
        local g = trk.nearG or NearTurnins()
        if not g then return end
        CDB.route = CDB.route or {}
        local front, keep = {}, {}
        for _, e in ipairs(g.list) do Sel()[e.id] = true; front[#front + 1] = e.id end
        local inFront = {}
        for _, id in ipairs(front) do inFront[id] = true end
        for _, id in ipairs(CDB.route) do if not inFront[id] then keep[#keep + 1] = id end end
        for _, id in ipairs(keep) do front[#front + 1] = id end
        CDB.total = math.max(CDB.total or 0, #front)
        CDB.route = front
        RefreshTracker(); RefreshBoard()
    end

    trk.more = Font(trk, 11, DIM); trk.more:SetJustifyH("LEFT"); trk.more:SetShadowColor(0, 0, 0, 1)
    trk.hint = Font(trk, 12, P.tx); trk.hint:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -10); trk.hint:SetPoint("RIGHT", 0, 0)
    trk.hint:SetJustifyH("LEFT"); trk.hint:SetSpacing(3); trk.hint:SetShadowColor(0, 0, 0, 1)
    trk.pick = Button(trk, "할 퀘 고르기", true, ToggleBoard, 110)


    local tp = DB.trkPos
    if tp then trk:SetPoint(tp[1], UIParent, tp[2], tp[3], tp[4]) else trk:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -280) end
    -- 예전 방식(가운데 기준)으로 저장된 자리는 처음 한 번 왼쪽 위 기준으로 바꿔요
    if not tp or tp[1] ~= "TOPLEFT" then C_Timer.After(0.5, function() if trk:GetLeft() then trk.SavePos() end end) end

    -- 크기 손잡이 (오른쪽 아래): 끌면 폭 · 최대 길이 조절, 오른쪽 클릭 = 처음 크기
    local grip = CreateFrame("Button", nil, trk)
    grip:SetSize(18, 18)
    grip:SetFrameLevel(trk:GetFrameLevel() + 10)
    local gt = grip:CreateTexture(nil, "OVERLAY"); gt:SetTexture(MEDIA .. "grip_resize"); gt:SetAllPoints()
    grip:SetAlpha(0.55)
    grip:RegisterForClicks("RightButtonUp")
    -- 끄는 동안 최대 크기 테두리
    local box = CreateFrame("Frame", nil, trk)
    box:SetPoint("TOPLEFT", -6, 6)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = box:CreateTexture(nil, "OVERLAY"); e:SetTexture(WHITE)
        e:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 0.7)
        if side == "TOP" or side == "BOTTOM" then e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(1.5)
        else e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(1.5) end
    end
    box:Hide()
    trk.grip, trk.box = grip, box
    grip:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("끌면 크기 조절")
        GameTooltip:AddLine("옆으로 = 폭 · 아래로 = 최대 길이", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("오른쪽 클릭: 처음 크기", 0.75, 0.75, 0.75); GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function(self) if not self.drag then self:SetAlpha(0.55) end; GameTooltip:Hide() end)
    grip:SetScript("OnClick", function() DB.trkW, DB.trkH = nil, nil; trk:SetWidth(290); RefreshTracker() end)
    grip:SetScript("OnMouseDown", function(self, b)
        if b ~= "LeftButton" then return end
        local s = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        self.drag = { x = cx / s, y = cy / s, w = trk:GetWidth(), h = DB.trkH or math.max(trk:GetHeight(), 120) }
        box:Show()
        self:SetScript("OnUpdate", function()
            local nx, ny = GetCursorPosition()
            nx, ny = nx / s, ny / s
            local w = math.max(200, math.min(560, self.drag.w + (nx - self.drag.x)))
            local h = math.max(90, math.min(1000, self.drag.h + (self.drag.y - ny)))
            DB.trkW, DB.trkH = math.floor(w + 0.5), math.floor(h + 0.5)
            trk:SetWidth(DB.trkW)
            box:SetSize(DB.trkW + 12, DB.trkH + 12)
            RefreshTracker()
        end)
        box:SetSize(trk:GetWidth() + 12, self.drag.h + 12)
    end)
    grip:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil); self.drag = nil; box:Hide(); self:SetAlpha(0.55)
    end)

    -- 지금 할 퀘(첫 줄)의 방향 · 거리
    local acc = 0
    local nearAcc = 0
    trk:SetScript("OnUpdate", function(self, el)
        acc = acc + el
        nearAcc = nearAcc + el
        if nearAcc > 1 then
            nearAcc = 0
            local g = NearTurnins()
            local sig = g and (g.npc .. #g.list) or ""
            if sig ~= (self.nearSig or "") then
                self.nearSig = sig
                if g then NearToast(g) end
                RefreshTracker()
            elseif g and self.near:IsShown() then
                self.near.d:SetText(g.d < 15 and "" or ("%dm"):format(g.d))
            end
        end
        if acc < 0.1 then return end
        acc = 0
        local r = self.rows[1]
        local e = r and r:IsShown() and r.cur and r.e
        if not e then return end
        local m = PlayerMap()
        local px, py = PlayerXY(m)
        local x, y = QuestPos(e, m)
        if not (px and x) then r.arrow:Hide(); r.dist:SetText("") return end
        local yd, dx, dy = Yards(m, px, py, x, y)
        local ang = yd and math.atan2(dy, dx) or math.atan2(-(x - px) * 1.5, -(y - py))
        local f = GetPlayerFacing and GetPlayerFacing()
        if f then r.arrow:SetRotation(ang - f); r.arrow:Show() else r.arrow:Hide() end
        if yd then
            r.dist:SetText(yd < 15 and "" or (yd >= 1000 and ("%.1fk"):format(yd / 1000) or ("%dm"):format(yd)))
        else
            r.dist:SetText("")
        end
    end)
    trk:Hide()
end

-- 근처(약 150m)에서 반납할 수 있는 완료 퀘: 가장 가까운 NPC 하나 기준으로 묶어요
local NEAR_YD = 150
NearTurnins = function()
    if DB and DB.nearTurnin == false then return end
    local m = PlayerMap()
    local px, py = PlayerXY(m)
    if not px then return end
    local groups = {}
    for _, e in ipairs(log) do
        if e.done and e.id then
            local x, y, src = QuestPos(e, m)
            if x and src ~= "none" then
                local yd = Yards(m, px, py, x, y)
                local d = yd or (math.sqrt((x - px) ^ 2 + (y - py) ^ 2) * 15)
                if d <= NEAR_YD then
                    local t = TurnInInfo(e)
                    local npc = (t and t.npc) or (guide[e.key] and guide[e.key].npc) or "반납 NPC"
                    local g = groups[npc]
                    if not g then g = { npc = npc, list = {}, d = d, x = x, y = y }; groups[npc] = g end
                    g.list[#g.list + 1] = e
                    if d < g.d then g.d = d end
                end
            end
        end
    end
    local best
    for _, g in pairs(groups) do if not best or g.d < best.d then best = g end end
    return best
end

local seenNear = {}
NearToast = function(g)
    if not g or seenNear[g.npc] then return end
    seenNear[g.npc] = true
    local t0 = _G.ForgLevelingFrame
    if t0 and t0:IsShown() and not DB.trkFold then return end   -- 추적 창의 노란 반납 띠가 이미 알려 줘요
    if Toast then Toast("근처에서 반납할 수 있어요", ("%s · %d개"):format(g.npc, #g.list), "길 앞으로", function()
        if trk and trk.PullNear then trk.PullNear() end
    end) end
end

RefreshTracker = function()
    if not trk then return end
    -- 근처 반납 노란 띠
    local near = NearTurnins()
    trk.nearG = near
    if near and not DB.trkFold then
        trk.near.t:SetText(("여기서 반납 %d개 · %s"):format(#near.list, near.npc))
        trk.near.d:SetText(near.d < 15 and "" or ("%dm"):format(near.d))
        trk.near:Show()
    else
        trk.near:Hide()
    end
    local bandH = trk.band:IsShown() and 32 or 0
    trk.near:ClearAllPoints()
    trk.near:SetPoint("TOPLEFT", trk.head, "BOTTOMLEFT", 0, -6 - bandH); trk.near:SetPoint("TOPRIGHT", trk.head, "BOTTOMRIGHT", 0, -6 - bandH)
    local nearH = (trk.near:IsShown() and 30 or 0) + bandH
    local route = Route()
    local total = math.max(CDB.total or #route, #route)
    for _, r in ipairs(trk.rows) do r:Hide(); r.e = nil; r.cur = nil end
    trk.more:Hide()
    trk.miniV:SetShown(DB.trkFold and true or false)
    if #route == 0 then
        local m = PlayerMap()
        local here, done = 0, 0
        for _, e in ipairs(log) do
            if e.done then done = done + 1 elseif InZone(e, m) then here = here + 1 end
        end
        trk.count:SetText("")
        trk.grip:Hide()
        if DB.trkFold then trk.hint:Hide(); trk.pick:Hide(); trk:SetHeight(30 + bandH) return end
        trk.hint:SetText(("%s\n여기서 할 퀘 %d개 · 완료 %d개"):format(MapName(m) or ZoneText(), here, done))
        trk.hint:ClearAllPoints(); trk.hint:SetPoint("TOPLEFT", trk.head, "BOTTOMLEFT", 0, -10 - nearH); trk.hint:SetPoint("RIGHT", 0, 0)
        trk.hint:Show()
        trk.pick:ClearAllPoints(); trk.pick:SetPoint("TOPLEFT", trk.hint, "BOTTOMLEFT", 0, -8); trk.pick:Show()
        trk:SetHeight(110 + nearH)
        return
    end
    trk.hint:Hide(); trk.pick:Hide()
    local doneN = math.max(0, total - #route)
    trk.count:SetText(("%d / %d"):format(doneN + 1, total))
    if DB.trkFold then trk:SetHeight(30 + bandH); trk.grip:Hide() return end

    trk.offset = 0
    local y = -38 - nearH
    local shown = 0
    local W = trk:GetWidth()
    local room = DB.trkH or 100000
    local maxq = DB.trkH and 99 or MAXQ        -- 길이를 직접 정했으면 개수 제한 없이 채워요
    for i = trk.offset + 1, math.min(#route, trk.offset + maxq) do
        local e = route[i]
        local need = 20 + math.max(1, e.done and 1 or #e.objs) * 15 + 8
        if shown > 0 and (-y + need + 22) > room then break end
        shown = shown + 1
        local r = trk.rows[shown] or MakeRow(shown)
        r.e = e
        r.cur = (i == 1)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", trk, "TOPLEFT", 0, y); r:SetWidth(W)
        -- 번호
        if e.done then
            r.disc:Hide(); r.edge:Hide(); r.nt:SetText(""); r.qi:Show()
        else
            r.disc:Show(); r.edge:Show(); r.qi:Hide()
            r.disc:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 1); r.nt:SetText(doneN + i)
        end
        r.glow:SetShown(r.cur)
        -- 이름 (보고할 퀘는 노란 글씨)
        r.title:SetText(e.title)
        if e.done then r.title:SetTextColor(YEL[1], YEL[2], YEL[3]) else r.title:SetTextColor(P.tx[1], P.tx[2], P.tx[3]) end
        local dt, dk, dc = Diff(e)
        r.diff:Set(dt, dc or dk)
        r.title:SetWidth(math.min(r.title:GetStringWidth() + 2, W - 28 - r.diff:GetWidth() - 8 - (r.cur and 70 or 0)))
        r.arrow:SetShown(r.cur); r.dist:SetShown(r.cur)
        if not r.cur then r.dist:SetText("") end
        -- 목표 줄
        local lines = {}
        if e.done then
            local g = guide[e.key]
            lines[1] = { "· " .. Progress(e), false }
        else
            for _, o in ipairs(e.objs) do
                local t = (o.have and o.need) and ("%s %d/%d"):format(o.text, o.have, o.need) or o.text
                lines[#lines + 1] = { "· " .. t, o.done }
            end
            if #lines == 0 then lines[1] = { "· " .. Progress(e), false } end
        end
        -- 목표 줄: 길면 다음 줄로 넘겨요 (잘리지 않게)
        local oy = 20
        for j, l in ipairs(lines) do
            local fs = ObjLine(r, j)
            fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", r, "TOPLEFT", 30, -oy); fs:SetWidth(W - 34)
            fs:SetText(l[1])
            if l[2] then fs:SetTextColor(0.54, 0.48, 0.46) else fs:SetTextColor(0.9, 0.84, 0.82) end
            fs:Show()
            oy = oy + math.max(15, math.ceil(fs:GetStringHeight() or 13) + 3)
        end
        for j = #lines + 1, #r.objs do r.objs[j]:Hide() end
        local h = oy + 8
        -- 실제 높이로 다시 확인: 공간을 넘으면 이 퀘는 "+ N개 더"로
        if shown > 1 and (-y + h + 22) > room then
            r:Hide(); shown = shown - 1
            break
        end
        r:SetHeight(h)
        r:Show()
        y = y - h
    end
    local rest = #route - shown
    if rest > 0 then
        trk.more:ClearAllPoints(); trk.more:SetPoint("TOPLEFT", trk, "TOPLEFT", 0, y - 2)
        trk.more:SetText(("+ %d개 더"):format(rest))
        trk.more:Show()
        y = y - 18
    end
    -- 길이를 직접 정했으면 창 높이 = 정한 길이 (손잡이도 그 끝에), 아니면 내용만큼
    if DB.trkH then
        trk:SetHeight(math.max(-y + 4, DB.trkH))
    else
        trk:SetHeight(-y + 4)
    end
    trk.grip:ClearAllPoints(); trk.grip:SetPoint("BOTTOMRIGHT", trk, "BOTTOMRIGHT", 4, -4); trk.grip:Show()
end

----------------------------------------------------------------------
-- 세계 지도 · 미니맵 위 분홍 점선 길 (따라가는 중일 때만)
----------------------------------------------------------------------
local function RoutePoints(m)
    -- { {x, y, n, done}, ... }  지도 % (위치 아는 것만)
    local out = {}
    local doneN = math.max(0, (CDB.total or 0) - #Route())
    for i, e in ipairs(Route()) do
        local x, y = QuestPos(e, m)
        if x then out[#out + 1] = { x, y, doneN + i, e.done, e } end
    end
    return out
end

local function DotPool(owner, layerFrame, size)
    owner.dots = owner.dots or {}
    owner.marks = owner.marks or {}
    owner.nd, owner.nm = 0, 0
    function owner:Dot(x, y, at)
        self.nd = self.nd + 1
        local d = self.dots[self.nd]
        if not d then
            d = layerFrame:CreateTexture(nil, "OVERLAY", nil, 1); d:SetTexture(MEDIA .. "circle")
            d:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 0.95); self.dots[self.nd] = d
        end
        d:SetSize(size, size)
        d:ClearAllPoints(); d:SetPoint("CENTER", layerFrame, at or "TOPLEFT", x, y); d:Show()
        return d
    end
    function owner:Mark(n, done, msize)
        self.nm = self.nm + 1
        local mk = self.marks[self.nm]
        if not mk then
            mk = CreateFrame("Frame", nil, layerFrame)
            mk.glow = mk:CreateTexture(nil, "BACKGROUND"); mk.glow:SetTexture(MEDIA .. "circle")
            mk.glow:SetPoint("TOPLEFT", -3, 3); mk.glow:SetPoint("BOTTOMRIGHT", 3, -3); mk.glow:SetVertexColor(0, 0, 0, 0.45)
            mk.disc = mk:CreateTexture(nil, "BORDER"); mk.disc:SetTexture(MEDIA .. "circle"); mk.disc:SetAllPoints()
            mk.n = Num(mk, 12, P.ink); mk.n:SetPoint("CENTER", 0, 0); mk.n:SetShadowColor(0, 0, 0, 0)
            self.marks[self.nm] = mk
        end
        mk:SetFrameLevel(layerFrame:GetFrameLevel() + 2)
        mk:SetSize(msize, msize)
        local c = done and { 0.945, 0.851, 0.541 } or P.acc
        mk.disc:SetVertexColor(c[1], c[2], c[3], 1)
        mk.n:SetText(n)
        mk:Show()
        return mk
    end
    function owner:Finish()
        for i = self.nd + 1, #self.dots do self.dots[i]:Hide() end
        for i = self.nm + 1, #self.marks do self.marks[i]:Hide() end
        self.nd, self.nm = 0, 0
    end
end

-- 세계 지도: 지도 그림판(캔버스) 위에 그려요
local wmLayer
local function PaintWorldMap()
    local wm = _G.WorldMapFrame
    if not (wm and wm:IsShown() and wm.ScrollContainer and wm.ScrollContainer.Child and CDB) then return end
    local canvas = wm.ScrollContainer.Child
    if not wmLayer then
        wmLayer = CreateFrame("Frame", nil, canvas)
        wmLayer:SetAllPoints(canvas)
        DotPool(wmLayer, wmLayer, 7)
    end
    wmLayer:SetFrameLevel(math.min(canvas:GetFrameLevel() + 6000, 9000))   -- Questie 아이콘보다 위
    local m = wm.GetMapID and wm:GetMapID()
    local here = PlayerMap()
    local W, H = canvas:GetWidth(), canvas:GetHeight()
    if not (m and m == here and W and W > 0) then
        for _, bd in ipairs(wmLayer.badges or {}) do bd:Hide() end
        wmLayer:Finish(); return
    end
    local pts = RoutePoints(m)
    local px, py = PlayerXY(m)
    local scale = math.max(0.5, W / 1002)
    local line = {}
    if px then line[1] = { px, py } end
    for _, p in ipairs(pts) do line[#line + 1] = p end
    for i = 2, #line do
        local a, b = line[i - 1], line[i]
        local ax, ay, bx, by = a[1] / 100 * W, -a[2] / 100 * H, b[1] / 100 * W, -b[2] / 100 * H
        local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
        local step = 14 * scale
        local cnt = math.floor(len / step)
        for j = 1, cnt - 1 do
            local t = j / cnt
            local d = wmLayer:Dot(ax + (bx - ax) * t, ay + (by - ay) * t)
            d:SetSize(6 * scale, 6 * scale)
        end
    end
    -- 가까이 붙은 번호는 한 무리로 모아요
    local groups = {}
    for _, p in ipairs(pts) do
        local x, y = p[1] / 100 * W, -p[2] / 100 * H
        local g
        for _, q in ipairs(groups) do
            if math.abs(q.x - x) < 22 * scale and math.abs(q.y - y) < 22 * scale then g = q break end
        end
        if g then
            g.ns[#g.ns + 1] = p[3]; g.es[#g.es + 1] = p[5]; g.done = g.done and p[4]
        else
            groups[#groups + 1] = { x = x, y = y, ns = { p[3] }, es = { p[5] }, done = p[4] }
        end
    end
    -- 대표 번호 + 개수: 제일 앞 번호 원을 그 자리에, 겹치면 오른쪽 위에 "+N", 마우스를 올리면 묶인 퀘 목록
    wmLayer.badges = wmLayer.badges or {}
    local nb = 0
    local h = 20 * scale
    for _, g in ipairs(groups) do
        local n = #g.ns
        local mk = wmLayer:Mark(g.ns[1], g.done, h)
        mk.n:SetFont(mk.n:GetFont(), math.floor(12 * scale), "")
        mk.disc:SetTexture(MEDIA .. "circle"); mk.glow:SetTexture(MEDIA .. "circle")
        mk:SetFrameLevel(wmLayer:GetFrameLevel() + 2)
        mk:ClearAllPoints(); mk:SetPoint("CENTER", wmLayer, "TOPLEFT", g.x, g.y)
        mk.leelG = g
        if not mk.leelHover then
            mk.leelHover = true
            mk:EnableMouse(true)
            mk:SetScript("OnEnter", function(self)
                local gg = self.leelG
                if not (gg and #gg.ns > 1) then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("이 자리 퀘 " .. #gg.ns .. "개", 1, 0.84, 0.88)
                for i, num in ipairs(gg.ns) do
                    local e = gg.es[i]
                    local t = e and e.title or "?"
                    if e and e.done then t = t .. " |cffffd34d(반납)|r" end
                    GameTooltip:AddLine(("|cfff2b3c2%d|r  %s"):format(num, t), 1, 1, 1)
                end
                GameTooltip:Show()
            end)
            mk:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        if n > 1 then
            nb = nb + 1
            local bd = wmLayer.badges[nb]
            if not bd then
                bd = CreateFrame("Frame", nil, wmLayer)
                bd.bg = bd:CreateTexture(nil, "BACKGROUND"); bd.bg:SetTexture(MEDIA .. "circle"); bd.bg:SetAllPoints()
                bd.bg:SetVertexColor(0.17, 0.12, 0.12, 1)
                bd.ring = bd:CreateTexture(nil, "BACKGROUND", nil, -1); bd.ring:SetTexture(MEDIA .. "circle")
                bd.ring:SetPoint("TOPLEFT", -1.5, 1.5); bd.ring:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
                bd.ring:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 1)
                bd.n = Num(bd, 10, P.accHi or P.acc); bd.n:SetPoint("CENTER", 0, 0); bd.n:SetShadowColor(0, 0, 0, 0)
                wmLayer.badges[nb] = bd
            end
            local bs = 15 * scale
            bd:SetSize(bs + (n > 9 and 6 * scale or 0), bs)
            bd.n:SetFont(bd.n:GetFont(), math.floor(10 * scale), "")
            bd.n:SetText("+" .. (n - 1))
            bd:SetFrameLevel(wmLayer:GetFrameLevel() + 4)
            bd:ClearAllPoints(); bd:SetPoint("CENTER", wmLayer, "TOPLEFT", g.x + h * 0.45, g.y + h * 0.45)
            bd:Show()
        end
    end
    for i = nb + 1, #wmLayer.badges do wmLayer.badges[i]:Hide() end
    wmLayer:Finish()
end

-- 미니맵: 내 위치 기준, 미니맵 확대 단계에 맞춰 야드 → 화면
local MM_OUT = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
local MM_IN  = { [0] = 300, 240, 180, 120, 80, 50 }
local mmLayer
local function World(m, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
    local ok, _, v = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x / 100, y / 100))
    if ok and v then return v.x, v.y end     -- x = 북, y = 서
end
local function PaintMinimap()
    local mm = _G.Minimap
    if not (mm and CDB) then return end
    if not mmLayer then
        mmLayer = CreateFrame("Frame", nil, mm)
        mmLayer:SetAllPoints(mm)
        DotPool(mmLayer, mmLayer, 4)
    end
    mmLayer:SetFrameLevel(mm:GetFrameLevel() + 5)
    local m = PlayerMap()
    local px, py = PlayerXY(m)
    local route = Route()
    if not (px and #route > 0) then mmLayer:Finish(); return end
    local pn, pw = World(m, px, py)
    if not pn then mmLayer:Finish(); return end
    local zoom = mm:GetZoom() or 0
    local indoor = IsIndoors and IsIndoors()
    local diam = (indoor and MM_IN or MM_OUT)[zoom] or 300
    local R = mm:GetWidth() / 2
    local k = R * 2 / diam                       -- 야드 → 화면
    local rot = GetCVar and GetCVar("rotateMinimap") == "1"
    local f = rot and GetPlayerFacing and GetPlayerFacing() or 0
    local cs, sn = math.cos(f), math.sin(f)
    local function ToScreen(n, w)
        local east, north = -(w - pw), (n - pn)
        if rot then east, north = east * cs + north * sn, -east * sn + north * cs end
        return east * k, north * k
    end
    local line = { { pn, pw } }
    for _, p in ipairs(RoutePoints(m)) do
        local n, w = World(m, p[1], p[2])
        if n then line[#line + 1] = { n, w, p[3], p[4] } end
    end
    local limit = R - 6
    for i = 2, #line do
        local a, b = line[i - 1], line[i]
        local ax, ay = ToScreen(a[1], a[2])
        local bx, by = ToScreen(b[1], b[2])
        local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
        local cnt = math.floor(len / 8)
        for j = 1, cnt - 1 do
            local t = j / cnt
            local x, y = ax + (bx - ax) * t, ay + (by - ay) * t
            if x * x + y * y < limit * limit then
                mmLayer:Dot(x, y, "CENTER")
            end
        end
        if bx * bx + by * by < (R - 10) ^ 2 then
            local mk = mmLayer:Mark(b[3], b[4], 16)
            mk.n:SetFont(mk.n:GetFont(), 10, "")
            mk:ClearAllPoints(); mk:SetPoint("CENTER", mmLayer, "CENTER", bx, by)
        end
    end
    mmLayer:Finish()
end

local lineTicker = CreateFrame("Frame")
local lineAcc = 0
lineTicker:SetScript("OnUpdate", function(_, el)
    lineAcc = lineAcc + el
    if lineAcc < 0.15 then return end
    lineAcc = 0
    if not CDB then return end
    local active = CDB.route and #CDB.route > 0 and DB.mapLines ~= false
    if active then
        PaintMinimap()
        if _G.WorldMapFrame and _G.WorldMapFrame:IsShown() then PaintWorldMap() end
    else
        if mmLayer then mmLayer:Finish() end
        if wmLayer then wmLayer:Finish() end
    end
end)

----------------------------------------------------------------------
-- 알림 (새 지역 · 새 퀘)
----------------------------------------------------------------------
local toast
Toast = function(title, text, btnLabel, fn, short1, short2)
    local t0 = _G.ForgLevelingFrame
    if trk and trk.band and t0 and t0:IsShown() then
        local b = trk.band
        b.full1, b.full2 = title, text
        b.t:SetText(short1 or title); b.s:SetText(short2 or text)
        b.b:SetLabel(btnLabel)
        b.b:SetScript("OnClick", function() b:Hide(); fn(); RefreshTracker() end)
        b.left = 8; b.hover = false
        b:Show()
        RefreshTracker()
        return
    end
    if not toast then
        toast = CreateFrame("Frame", nil, UIParent)
        toast:SetSize(380, 62); toast:SetFrameStrata("HIGH")
        Plate(toast, 18, { 0.114, 0.082, 0.078, 0.96 }, { P.acc[1], P.acc[2], P.acc[3], 0.9 })
        local bun = CreateFrame("Frame", nil, toast); bun:SetSize(30, 30); bun:SetPoint("LEFT", 14, 0)
        local bd = bun:CreateTexture(nil, "ARTWORK"); bd:SetTexture(MEDIA .. "circle"); bd:SetAllPoints(); bd:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 1)
        local bi = bun:CreateTexture(nil, "OVERLAY"); bi:SetTexture(MEDIA .. "bunny"); bi:SetAllPoints()
        toast.t = Font(toast, 15, P.tx); toast.t:SetPoint("TOPLEFT", 54, -12); toast.t:SetPoint("RIGHT", -120, 0); toast.t:SetJustifyH("LEFT"); toast.t:SetWordWrap(false)
        toast.s = Font(toast, 11.5, DIM); toast.s:SetPoint("TOPLEFT", toast.t, "BOTTOMLEFT", 0, -4); toast.s:SetPoint("RIGHT", -120, 0); toast.s:SetJustifyH("LEFT"); toast.s:SetWordWrap(false)
        local x = CreateFrame("Button", nil, toast); x:SetSize(22, 22); x:SetPoint("RIGHT", -12, 0)
        RR(x, 7, CHIP, "BACKGROUND", 0, 0)
        local xt = x:CreateTexture(nil, "ARTWORK"); xt:SetTexture(MEDIA .. "hb_x"); xt:SetSize(12, 12); xt:SetPoint("CENTER")
        xt:SetVertexColor(P.tx2[1], P.tx2[2], P.tx2[3], 1)
        x:SetScript("OnClick", function() toast:Hide() end)
        toast.b = Button(toast, "고르기", true, function() end, 60)
        toast.b:SetPoint("RIGHT", x, "LEFT", -8, 0)
        toast:SetScript("OnUpdate", function(self, el)
            self.left = (self.left or 0) - el
            if self.left <= 0 then self:Hide() end
        end)
    end
    toast.t:SetText(title); toast.s:SetText(text)
    toast.b:SetLabel(btnLabel)
    toast.b:SetScript("OnClick", function() toast:Hide(); fn() end)
    -- 자리: 게임 퀘스트 메시지(화면 위 가운데)와 안 겹치게 Leel Quest 창 왼쪽 옆, 창이 없으면 화면 가운데 조금 위
    toast:ClearAllPoints()
    toast:SetClampedToScreen(true)
    local t = _G.ForgLevelingFrame
    if t and t:IsShown() and t:GetLeft() then
        toast:SetPoint("TOPRIGHT", t, "TOPLEFT", -12, 0)
    else
        toast:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
    end
    toast.left = 15
    toast:Show()
end

local seenZone = {}
local function ZoneToast()
    if DB.zoneToast == false or InCombatLockdown() then return end
    local m = PlayerMap()
    local zone = MapName(m) or ZoneText()
    if not zone or zone == "" or seenZone[zone] then return end
    if IsInInstance and IsInInstance() then return end
    local here, done = 0, 0
    for _, e in ipairs(log) do
        if e.done then if QuestPos(e, m) then done = done + 1 end
        elseif InZone(e, m) then here = here + 1 end
    end
    if here + done == 0 then return end
    seenZone[zone] = true
    Toast(zone .. " 도착!", ("받아 둔 퀘 중 여기서 할 것 %d개 · 완료 %d개"):format(here, done), "고르기", function()
        MakeBoard(); board:Show()
    end, zone, ("할 것 %d · 완료 %d"):format(here, done))
end

local function NewQuestToast(id)
    if not (id and CDB.route and #CDB.route > 0) then return end
    local e = byId[id]
    if not e then return end
    Toast("새 퀘: " .. e.title, "지금 길에 넣을까요? 가까운 순서로 끼워 넣어요", "넣기", function()
        Sel()[id] = true
        CDB.route = BuildOrder()
        CDB.total = (CDB.total or 0) + 1
        RefreshTracker(); RefreshBoard()
    end, "새 퀘", e.title)
end

----------------------------------------------------------------------
-- 이벤트
----------------------------------------------------------------------
local pendingRefresh = false
local function SoonRefresh()
    if pendingRefresh then return end
    pendingRefresh = true
    C_Timer.After(0.3, function()
        pendingRefresh = false
        ReadLog(); Learn()
        -- 로그에서 사라진 퀘(반납 · 포기)는 고른 목록에서도 빼요
        for id in pairs(Sel()) do if not byId[id] then Sel()[id] = nil end end
        -- 퀘를 다 하면(보고할 곳이 생기면) 길을 다시 짜요: 할 일 먼저, 보고는 끝에
        CDB.doneSeen = CDB.doneSeen or {}
        local changed = false
        for id in pairs(Sel()) do
            local e = byId[id]
            local d = e and e.done or false
            if CDB.doneSeen[id] ~= d then
                if CDB.doneSeen[id] ~= nil then changed = true end
                CDB.doneSeen[id] = d
            end
        end
        if changed and CDB.route and #CDB.route > 0 then CDB.route = BuildOrder() end
        RefreshTracker(); RefreshBoard()
    end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("QUEST_ACCEPTED")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function(_, e, a1, a2)
    if e == "PLAYER_LOGIN" then
        ForgLevelingDB = ForgLevelingDB or {}
        ForgLevelingCharDB = ForgLevelingCharDB or {}
        DB, CDB = ForgLevelingDB, ForgLevelingCharDB
        MakeTracker()
        ReadLog(); Learn()
        RefreshTracker()
        C_Timer.After(6, function() ReadLog(); ZoneToast() end)
        return
    end
    if not DB then return end
    if e == "QUEST_ACCEPTED" then
        local id = a2 or a1
        if type(id) == "number" and id < 100 and a2 == nil then id = nil end
        C_Timer.After(0.5, function() ReadLog(); NewQuestToast(id); RefreshTracker(); RefreshBoard() end)
    elseif e == "ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(2, function() ReadLog(); ZoneToast(); RefreshTracker(); RefreshBoard() end)
    else
        SoonRefresh()
    end
end)

----------------------------------------------------------------------
-- 명령어 (허브 "고르기 판 열기"도 이걸 불러요)
----------------------------------------------------------------------
SLASH_FORGLEVELING1 = "/forg"
SLASH_FORGLEVELING2 = "/길잡이"
SLASH_FORGLEVELING3 = "/퀘판"
SlashCmdList.FORGLEVELING = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if not DB then return end
    if msg == "따라" or msg == "창" then
        if trk then trk:SetShown(not trk:IsShown()) end
    elseif msg == "알림" then
        DB.zoneToast = DB.zoneToast == false
        Print("지역 알림 " .. (DB.zoneToast ~= false and "켬" or "끔"))
    elseif msg == "점검" then
        local m = PlayerMap(); local px, py = PlayerXY(m)
        local e = Route()[1]
        Print(("지도 %s · 내 위치 %s"):format(tostring(m), px and ("%.1f, %.1f"):format(px, py) or "모름"))
        if e then
            local x, y, src = QuestPos(e, m)
            Print(("첫 퀘 %s · 위치 %s (%s)"):format(e.title, x and ("%.1f, %.1f"):format(x, y) or "모름", SRC[src]))
            if px and x then
                local yd, dx, dy = Yards(m, px, py, x, y)
                Print(("거리 %s야드 · 북 %s · 서 %s"):format(tostring(yd and math.floor(yd)), tostring(dx and math.floor(dx)), tostring(dy and math.floor(dy))))
            end
        end
    elseif msg == "초기화" then
        DB.trkPos, DB.boardPos, DB.trkW, DB.trkH = nil, nil, nil, nil
        if trk then trk:ClearAllPoints(); trk:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -280) end
        if board then board:ClearAllPoints(); board:SetPoint("CENTER", 0, 30) end
        Print("창 자리를 처음대로.")
    else
        ToggleBoard()
    end
end

ns.ToggleBoard = ToggleBoard
ns.RabbitRec = FillGuide
_G.LeelQuestBoard_Toggle = ToggleBoard
