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
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cfff2b3c2[Leel Quest]|r " .. msg) end
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

-- 정예 · 던전 · 공격대 퀘 알아내기 (Questie가 고친 값 → 게임 값)
local TAG_KIND = { [1] = "elite", [81] = "dungeon", [62] = "raid", [88] = "raid", [89] = "raid", [85] = "dungeon" }
local TAG_NAME = { elite = "정예", dungeon = "던전", raid = "공격대" }
local tagCache, tagMiss = {}, {}
local function KindFromName(n)
    if type(n) ~= "string" or n == "" then return end
    if n:find("던전") or n:find("Dungeon") or n:find("영웅") or n:find("Heroic") then return "dungeon" end
    if n:find("공격대") or n:find("Raid") then return "raid" end
    if n:find("정예") or n:find("Elite") or n:find("파티") or n:find("Group") then return "elite" end
end
-- 게임 퀘스트 일지에 보이는 표시(던전 · 정예 · 공격대)를 먼저 믿고, 없으면 Questie 자료로
local function QuestTag(id, logTag)
    if not id then return KindFromName(logTag) end
    if tagCache[id] then return tagCache[id] end
    local kind = KindFromName(logTag)
    if kind then tagCache[id] = kind; return kind end
    tagMiss = tagMiss or {}
    if tagMiss[id] and GetTime() - tagMiss[id] < 20 then return end   -- 못 찾은 퀘는 20초에 한 번만 다시
    local answered = false
    if not kind and C_QuestLog and C_QuestLog.GetQuestTagInfo then
        local ok, info = pcall(C_QuestLog.GetQuestTagInfo, id)
        if ok and type(info) == "table" then
            answered = true
            kind = TAG_KIND[info.tagID] or KindFromName(info.tagName)
        end
    end
    if not kind and GetQuestTagInfo then
        local ok, a, b = pcall(GetQuestTagInfo, id)
        if ok and (a or b) then
            answered = true
            kind = TAG_KIND[a] or KindFromName(b)
        end
    end
    if not kind then
        local QL = _G.QuestieLoader
        if QL and QL.ImportModule then
            local ok, QDB = pcall(QL.ImportModule, QL, "QuestieDB")
            if ok and type(QDB) == "table" and QDB.GetQuestTagInfo then
                local ok2, a, b = pcall(QDB.GetQuestTagInfo, id)
                if ok2 and (a or b) then kind = TAG_KIND[a] or KindFromName(b) end
            end
        end
    end
    if kind then tagCache[id] = kind else tagMiss[id] = GetTime() end   -- 찾았을 때만 기억
    return kind
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
                    id = id, title = title, key = Norm(title), level = level or 0, group = tonumber(group) or 0, tag = QuestTag(id, type(group) == "string" and group or nil),
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
-- 다른 지도(옆 지역)의 좌표를 지금 지도 좌표로 바꿔요 (지금 지도 밖이면 0~100 밖 값이 나와요)
local function ToMap(src, x, y, m)
    if src == m then return x, y end
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
    local ok, c1, w = pcall(C_Map.GetWorldPosFromMapPos, src, CreateVector2D(x / 100, y / 100))
    local ok0, c0, w00 = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(0, 0))
    local ok1, _, w11 = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(1, 1))
    if not (ok and ok0 and ok1 and w and w00 and w11) or c1 ~= c0 then return end
    local dy, dx = w11.y - w00.y, w11.x - w00.x
    if math.abs(dy) < 1e-6 or math.abs(dx) < 1e-6 then return end
    return (w.y - w00.y) / dy * 100, (w.x - w00.x) / dx * 100
end

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
                -- 다른 퀘에 다시 쓰인 아이콘 틀은 건너뛰어요
                local qid = type(d) == "table" and (d.Id or (type(d.QuestData) == "table" and d.QuestData.Id))
                if type(d) == "table" and fr.x and fr.y and fr.UiMapID and #c.obj < 300 and (not qid or qid == e.id) then
                    local od = type(d.ObjectiveData) == "table" and d.ObjectiveData or nil
                    local pt = { map = fr.UiMapID, x = fr.x, y = fr.y, idx = d.ObjectiveIndex, npc = d.Name,
                                 qdone = od and od.Completed or nil, desc = od and od.Description or nil }
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
        -- 반납 NPC가 옆 지역에 있으면 그쪽을 가리켜요
        for _, p in ipairs(c.fin) do
            local x, y = ToMap(p.map, p.x, p.y, m)
            if x then return x, y end
        end
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
    -- 이 아이콘의 목표가 끝났나: Questie가 아는 완료 → 목표 글자로 맞춰 본 게임 값 → 번호로 맞춘 게임 값
    --   (Questie의 목표 번호가 게임 순서와 다를 때가 있어서 번호는 마지막에)
    local function ObjDone(p)
        if p.qdone ~= nil then return p.qdone and true or false end
        if type(p.desc) == "string" and p.desc ~= "" then
            local want = Norm(p.desc)
            for _, o in ipairs(e.objs) do
                local t = Norm(o.text or "")
                if t ~= "" and (t == want or t:find(want, 1, true) or want:find(t, 1, true)) then return o.done end
            end
        end
        local o = p.idx and e.objs[p.idx]
        return o and o.done or false
    end
    local here, other = {}, {}
    for _, p in ipairs(c.obj) do
        if not ObjDone(p) then
            if p.map == m then here[#here + 1] = p
            else other[p.map] = other[p.map] or {}; table.insert(other[p.map], p) end
        end
    end
    c.centerKey = key
    -- 몹/물건이 가장 많이 몰린 곳의 가운데
    local function Center(pts)
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
        return sx / n, sy / n
    end
    if #here > 0 then
        local x, y = Center(here)
        c.center = { x, y }
        return x, y
    end
    -- 이 지도엔 남은 목표가 없어요 → 남은 목표가 있는 옆 지역(가장 많은 곳)을 이 지도 좌표로 바꿔서 가리켜요
    local bestMap, bestN = nil, 0
    for mp, list in pairs(other) do if #list > bestN then bestMap, bestN = mp, #list end end
    if bestMap then
        local ox, oy = Center(other[bestMap])
        local x, y = ToMap(bestMap, ox, oy, m)
        if x then c.center = { x, y }; return x, y end
    end
    c.center = false
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

-- 반납 NPC 이름 (모르면 nil)
local function TurnNpc(e)
    if not (e and e.done) then return end
    local t = TurnInInfo(e)
    local g = guide[e.key]
    return (t and t.npc) or (g and g.npc) or nil
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

local function OnMap(x, y) return x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100 end
local function InZone(e, m)
    if e.zone and (e.zone == ZoneText() or e.zone == MapName(m)) then return true end
    local x, y = QuestPos(e, m)
    return x ~= nil and x >= 0 and x <= 100 and y >= 0 and y <= 100   -- 옆 지역을 가리키는 값은 "여기"가 아니에요
end

-- 난이도: 글씨는 퀘 레벨, 색이 난이도 (빨강 어려움 · 노랑 보통 · 초록 쉬움 · 회색 너무 쉬움)
-- 와우 포에버는 퀘 레벨이 조금만 높아도 힘들어서: 내 레벨보다 3 이상 = 어려움, 1~2 = 보통
local function Diff(e)
    local lv = e.level or 0
    local me = UnitLevel("player") or 1
    local d = lv - me
    local txt = lv > 0 and ("Lv " .. lv) or "Lv ?"
    if e.tag then return txt .. " · " .. (TAG_NAME[e.tag] or "정예"), "hard" end
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
-- 정예 · 던전 · 파티 퀘(아직 안 한 것)는 길 맨 뒤로: 혼자 가다 죽지 않게
local function PartyLast(order)
    local solo, party = {}, {}
    for _, id in ipairs(order) do
        local e = byId[id]
        if e and not e.done and (e.tag or (e.group and e.group > 1)) then party[#party + 1] = id
        else solo[#solo + 1] = id end
    end
    for _, id in ipairs(party) do solo[#solo + 1] = id end
    return solo
end

local BuildOrderRaw
local function BuildOrder() return PartyLast(BuildOrderRaw()) end
BuildOrderRaw = function()
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
    if onlySolo and ((e.group and e.group > 1) or e.tag) then return false end
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

----------------------------------------------------------------------
-- 지도 칸: 평소엔 지금 지역 지도 + 다른 지역 번호는 가장자리 표,
-- 이 지역 할 일이 끝나고 다음 번호가 다른 지역이면 넓은 지도로 가는 길, 그 지역에 들어서면 다시 지역 지도
----------------------------------------------------------------------
local zoneIdCache = {}
local function ZoneIdByName(name)
    if not name then return end
    local c = zoneIdCache[name]
    if c ~= nil then return c or nil end
    if D.maps and D.maps[name] then zoneIdCache[name] = D.maps[name]; return D.maps[name] end
    local found = false
    local ok, kids = pcall(C_Map.GetMapChildrenInfo, 947, Enum.UIMapType.Zone, true)
    for _, k in ipairs(ok and kids or {}) do
        if k.name == name then found = k.mapID; break end
    end
    zoneIdCache[name] = found
    return found or nil
end

local function ContinentOf(m)
    for _ = 1, 8 do
        local info = m and C_Map.GetMapInfo(m)
        if not info then return end
        if info.mapType == Enum.UIMapType.Continent then return m end
        m = info.parentMapID
    end
end

local function RectOn(m, cont)
    local ok, l, r, t, b = pcall(C_Map.GetMapRectOnMap, m, cont)
    if ok and l and r > l and b > t then return l, r, t, b end
end

-- 이 퀘가 지금 지역(m) 일인지
local function HereEntry(e, m)
    local x, y = QuestPos(e, m)
    if OnMap(x, y) then return true end
    local z = ZoneKey(e)
    return z == MapName(m) or (z == ZoneText() and not x)
end

-- 다른 지역 퀘가 지금 지역 지도에서 어느 쪽인지 (지도 %, 범위 밖일 수 있음)
local function OffMapPos(e, m)
    local x, y = QuestPos(e, m)
    if x then return x, y end
    local z = ZoneIdByName(ZoneKey(e))
    local cont = ContinentOf(m)
    if not (z and cont) then return end
    local zl, zr, zt, zb = RectOn(z, cont)
    local ml, mr, mt, mb = RectOn(m, cont)
    if not (zl and ml) then return end
    local cx, cy = (zl + zr) / 2, (zt + zb) / 2
    return (cx - ml) / (mr - ml) * 100, (cy - mt) / (mb - mt) * 100
end

local function EdgeChip(p, i)
    p.chips = p.chips or {}
    local c = p.chips[i]
    if not c then
        c = CreateFrame("Frame", nil, p.layer)
        c:SetSize(120, 22)
        c:SetFrameLevel(p.layer:GetFrameLevel() + 4)
        Plate(c, 11, { 0.13, 0.09, 0.085, 0.95 }, P.acc)
        c.disc = c:CreateTexture(nil, "ARTWORK"); c.disc:SetTexture(MEDIA .. "circle"); c.disc:SetSize(17, 17)
        c.disc:SetPoint("LEFT", 3, 0)
        c.n = Num(c, 11, P.ink); c.n:SetPoint("CENTER", c.disc, "CENTER", 0, 0); c.n:SetShadowColor(0, 0, 0, 0)
        c.t = Font(c, 11, P.tx); c.t:SetPoint("LEFT", c.disc, "RIGHT", 5, 0)
        p.chips[i] = c
    end
    return c
end

-- 넓은 지도 (대륙 그림 + 두 지역의 밝혀진 조각)
local function WideTiles(w, parent, files, li, x, y, wd, ht, sx, sy, x0, y0, overlay, sub, tint)
    local TW, TH = li.tileWidth or 256, li.tileHeight or 256
    local cols, rows = math.ceil(wd / TW), math.ceil(ht / TH)
    local function fs(px) local f = 16; while f < px do f = f * 2 end; return f end
    for j = 1, rows do
        local ph = (j < rows) and TH or (ht - (rows - 1) * TH)
        local fh = (j < rows or not overlay) and TH or fs(ph)
        for k = 1, cols do
            local f = files[(j - 1) * cols + k]
            local pw = (k < cols) and TW or (wd - (cols - 1) * TW)
            local fw = (k < cols or not overlay) and TW or fs(pw)
            if f and pw > 0 and ph > 0 then
                w.n = w.n + 1
                local t = w.tex[w.n]
                if not t then t = parent:CreateTexture(nil, "BACKGROUND"); w.tex[w.n] = t end
                t:SetDrawLayer("BACKGROUND", sub)
                t:SetTexture(f, nil, nil, "TRILINEAR")
                t:SetTexCoord(0, pw / fw, 0, ph / fh)
                t:SetSize(pw * sx, ph * sy)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", parent, "TOPLEFT", x0 + (x + (k - 1) * TW) * sx, -(y0 + (y + (j - 1) * TH) * sy))
                t:SetVertexColor(tint, tint * 0.96, tint * 0.92, 1)
                t:Show()
            end
        end
    end
end

local function WideZone(w, zid, cont, K, ox, oy, tint)
    local ok, layers = pcall(C_Map.GetMapArtLayers, zid)
    local li = ok and layers and layers[1]
    local l, r, t, b = RectOn(zid, cont)
    if not (li and l) then return end
    local sx, sy = (r - l) * K.w / li.layerWidth, (b - t) * K.h / li.layerHeight
    local x0, y0 = ox + l * K.w, oy + t * K.h
    local done = {}
    local ok2, list = pcall(C_MapExplorationInfo.GetExploredMapTextures, zid)
    for _, info in ipairs(ok2 and list or {}) do
        done[info.textureWidth .. ":" .. info.textureHeight .. ":" .. info.offsetX .. ":" .. info.offsetY] = true
        if not info.isShownByMouseOver then
            WideTiles(w, w.art, info.fileDataIDs or {}, li, info.offsetX, info.offsetY, info.textureWidth, info.textureHeight, sx, sy, x0, y0, true, 2, tint)
        end
    end
    local okA, artID = pcall(C_Map.GetMapArtID, zid)
    local zone = ns.reveal and okA and artID and ns.reveal[artID]
    for key, ids in pairs(zone or {}) do
        if not done[key] then
            local wd, ht, x, y = strsplit(":", key)
            local files = {}
            for id in ids:gmatch("%d+") do files[#files + 1] = tonumber(id) end
            WideTiles(w, w.art, files, li, tonumber(x), tonumber(y), tonumber(wd), tonumber(ht), sx, sy, x0, y0, true, 1, tint * 0.85)
        end
    end
end

local DIRS = { "동", "남동", "남", "남서", "서", "북서", "북", "북동" }
local function DirText(dx, dy)   -- 지도 위 (오른쪽 +x, 아래 +y)
    local a = math.atan2(dy, dx)
    local i = math.floor((a / (math.pi / 4)) + 0.5) % 8
    return DIRS[i + 1]
end

local function Banner(p)
    if p.ban then return p.ban end
    local b = CreateFrame("Frame", nil, p)
    b:SetHeight(26)
    b:SetPoint("TOPLEFT", 8, -8); b:SetPoint("TOPRIGHT", -8, -8)
    b:SetFrameLevel(p:GetFrameLevel() + 12)
    b.fill, b.edge = Plate(b, 12, { 0.13, 0.09, 0.085, 0.95 }, P.acc)
    b.head = Font(b, 12, P.acc); b.head:SetPoint("LEFT", 10, 0)
    b.text = Font(b, 12, P.tx); b.text:SetPoint("LEFT", b.head, "RIGHT", 6, 0)
    b.right = Font(b, 11, DIM); b.right:SetPoint("RIGHT", -10, 0)
    p.ban = b
    return b
end

local function ShowBanner(p, kind, head, text, right)
    local b = Banner(p)
    local c = kind == "arrive" and { 0.62, 0.85, 0.6 } or P.acc
    if b.edge and b.edge.SetColor then b.edge:SetColor(c) end
    b.head:SetTextColor(c[1], c[2], c[3])
    b.head:SetText(head); b.text:SetText(text or ""); b.right:SetText(right or "")
    b:Show()
end

local function PaintWide(p, m, order, target, zid, from)
    local cont = ContinentOf(m)
    local okL, layers = pcall(C_Map.GetMapArtLayers, cont or 0)
    local li = okL and layers and layers[1]
    if not (cont and li) then return false end
    local zl, zr, zt, zb = RectOn(zid, cont)
    if not zl then return false end
    local okP, pos = pcall(C_Map.GetPlayerMapPosition, cont, "player")
    local ux, uy
    if okP and pos then ux, uy = pos:GetXY() end
    if not ux or (ux == 0 and uy == 0) then
        local ml, mr, mt, mb = RectOn(m, cont)
        if not ml then return false end
        ux, uy = (ml + mr) / 2, (mt + mb) / 2
    end
    -- 목표 자리: 다음 지역 첫 퀘 (모르면 지역 가운데)
    local tx, ty = QuestPos(target, zid)
    if tx and OnMap(tx, ty) then
        tx, ty = zl + tx / 100 * (zr - zl), zt + ty / 100 * (zb - zt)
    else
        tx, ty = (zl + zr) / 2, (zt + zb) / 2
    end
    -- 보이는 범위: 내 자리 + 다음 지역, 여유 두고 칸 비율에 맞춤
    local W, H = p:GetWidth(), p:GetHeight()
    local K = { w = li.layerWidth, h = li.layerHeight }
    local bl, br = math.min(ux, zl), math.max(ux, zr)
    local bt, bb = math.min(uy, zt), math.max(uy, zb)
    local bw, bh = (br - bl) * K.w, (bb - bt) * K.h
    local s = math.min(W / (bw * 1.25), (H - 30) / (bh * 1.25))
    local cxp, cyp = (bl + br) / 2 * K.w, (bt + bb) / 2 * K.h
    local ox, oy = W / 2 - cxp * s, (H + 26) / 2 - cyp * s
    local w = p.wide
    if not w then
        w = CreateFrame("Frame", nil, p); w:SetAllPoints()
        w:SetFrameLevel(p.art:GetFrameLevel())
        w.art = CreateFrame("Frame", nil, w); w.art:SetAllPoints()
        w.tex, w.n = {}, 0
        w.top = CreateFrame("Frame", nil, w); w.top:SetAllPoints(); w.top:SetFrameLevel(w:GetFrameLevel() + 3)
        w.zoneFill = w.top:CreateTexture(nil, "BACKGROUND"); w.zoneFill:SetTexture(WHITE)
        w.lines = {}
        for i = 1, 4 do w.lines[i] = w.top:CreateTexture(nil, "BORDER"); w.lines[i]:SetTexture(WHITE) end
        w.name = Font(w.top, 13, P.tx); w.name:SetShadowColor(0, 0, 0, 1)
        w.from = Font(w.top, 11, DIM); w.from:SetShadowColor(0, 0, 0, 1)
        w.me = w.top:CreateTexture(nil, "OVERLAY", nil, 3)
        w.me:SetTexture("Interface\\MINIMAP\\MinimapArrow"); w.me:SetSize(22, 22)
        w.mk = MapMark(p, 1)   -- (번호 원 하나를 빌려 씀: 지역 지도 번호는 이때 다 숨김)
        w.dots = {}
        p.wide = w
    end
    local key = cont .. ":" .. zid .. ":" .. m .. ":" .. math.floor(s * 50) .. ":" .. math.floor(ox / 8) .. ":" .. math.floor(oy / 8)
    if w.key ~= key then
        w.key = key
        w.n = 0
        local okF, files = pcall(C_Map.GetMapArtLayerTextures, cont, 1)
        if okF and files then WideTiles(w, w.art, files, li, 0, 0, li.layerWidth, li.layerHeight, s, s, ox, oy, false, 0, 0.5) end
        WideZone(w, m, cont, { w = K.w * s, h = K.h * s }, ox, oy, 0.6)
        WideZone(w, zid, cont, { w = K.w * s, h = K.h * s }, ox, oy, 1.05)
        for i = w.n + 1, #w.tex do w.tex[i]:Hide() end
        -- 다음 지역: 테 대신 그 지역만 밝게 + 이름 알약 (지역 위쪽, 띠 아래로)
        w.zoneFill:Hide()
        for _, t in ipairs(w.lines) do t:Hide() end
        local x1, y1, x2 = ox + zl * K.w * s, oy + zt * K.h * s, ox + zr * K.w * s
        if not w.pill then
            w.pill = CreateFrame("Frame", nil, w.top); w.pill:SetHeight(20)
            w.pill:SetFrameLevel(w.top:GetFrameLevel() + 3)
            Plate(w.pill, 10, { 0.13, 0.09, 0.085, 0.92 }, P.acc)
            w.name:SetParent(w.pill); w.name:ClearAllPoints(); w.name:SetPoint("CENTER", 0, 0)
        end
        w.name:SetText(MapName(zid) or "")
        w.pill:SetWidth(w.name:GetStringWidth() + 20)
        local py = math.max(44, math.min(H - 14, y1 + 2))
        local px = math.max(w.pill:GetWidth() / 2 + 6, math.min(W - w.pill:GetWidth() / 2 - 6, (x1 + x2) / 2))
        w.pill:ClearAllPoints(); w.pill:SetPoint("CENTER", w.top, "TOPLEFT", px, -py)
        w.pillXY = { px, py }
        -- 지금 지역 이름 (작게, 내 화살표 아래)
        w.from:SetText("지금 · " .. (MapName(m) or ""))
    end
    -- 내 자리 · 목표 · 점선 (매번)
    local mx, my = ox + ux * K.w * s, oy + uy * K.h * s
    local gx, gy = ox + tx * K.w * s, oy + ty * K.h * s
    w.me:ClearAllPoints(); w.me:SetPoint("CENTER", w.top, "TOPLEFT", mx, -my)
    w.from:ClearAllPoints(); w.from:SetPoint("TOP", w.top, "TOPLEFT", math.max(40, math.min(W - 40, mx)), -(my + 12)); w.from:Show()
    if GetPlayerFacing then local okF, f = pcall(GetPlayerFacing); if okF and f and not (issecretvalue and issecretvalue(f)) then w.me:SetRotation(f) end end
    local mk = w.mk
    mk:SetParent(w.top); mk:SetFrameLevel(w.top:GetFrameLevel() + 2)
    mk.disc:SetVertexColor(target.done and 0.945 or P.acc[1], target.done and 0.851 or P.acc[2], target.done and 0.541 or P.acc[3], 1)
    mk.glow:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 0.3)
    mk.n:SetText(from)
    mk:ClearAllPoints(); mk:SetPoint("CENTER", w.top, "TOPLEFT", gx, -gy); mk:Show()
    local len = math.sqrt((gx - mx) ^ 2 + (gy - my) ^ 2)
    local cnt = math.min(80, math.floor(len / 9))
    for j = 1, cnt - 1 do
        local d = w.dots[j]
        if not d then
            d = w.top:CreateTexture(nil, "ARTWORK"); d:SetTexture(MEDIA .. "circle"); d:SetSize(5, 5)
            d:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 0.95); w.dots[j] = d
        end
        local t = j / cnt
        d:ClearAllPoints(); d:SetPoint("CENTER", w.top, "TOPLEFT", mx + (gx - mx) * t, -(my + (gy - my) * t)); d:Show()
    end
    for j = math.max(cnt, 1), #w.dots do w.dots[j]:Hide() end
    -- 띠: 다음 지역 · 번호 범위 · 거리 · 방향
    local last = from
    for i = from + 1, #order do
        if ZoneKey(order[i]) == ZoneKey(target) then last = i else break end
    end
    local dist
    local ok1, _, a = pcall(C_Map.GetWorldPosFromMapPos, cont, CreateVector2D(ux, uy))
    local ok2, _, b = pcall(C_Map.GetWorldPosFromMapPos, cont, CreateVector2D(tx, ty))
    if ok1 and ok2 and a and b then
        local d = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
        dist = d >= 1000 and ("약 %.1fkm"):format(d / 1000) or ("약 %dm"):format(d)
    end
    ShowBanner(p, "next", "다음 지역", ("%s · %s번"):format(MapName(zid) or ZoneKey(target), last > from and (from .. "~" .. last) or tostring(from)),
        (dist and (dist .. " · ") or "") .. DirText(gx - mx, gy - my) .. "쪽")
    w:Show()
    return true
end

local function PaintMap()
    local p = board.map
    local m = PlayerMap()
    local order = (CDB.route and #CDB.route > 0) and Route() or nil
    if not order then
        order = {}
        for _, id in ipairs(BuildOrder()) do if byId[id] then order[#order + 1] = byId[id] end end
    end

    -- 넓은 지도: 다음 번호가 다른 지역이고, 이 지역에 남은 게 없을 때
    local first = order[1]
    local wideOn = false
    if m and first and not HereEntry(first, m) then
        local zid = ZoneIdByName(ZoneKey(first))
        if zid and zid ~= m then
            for _, mk in ipairs(p.marks) do mk:Hide() end
            for _, d in ipairs(p.dots) do d:Hide() end
            for _, c in ipairs(p.chips or {}) do c:Hide() end
            p.me:Hide()
            wideOn = PaintWide(p, m, order, first, zid, 1)
            if wideOn then
                p.art:Hide()
                p.wideTarget = zid
            end
        end
    end
    if wideOn then return order end
    if p.wide then
        p.wide:Hide()
        if p.wide.mk then p.wide.mk:SetParent(p.layer); p.wide.mk:SetFrameLevel(p.layer:GetFrameLevel() + 2) end
    end
    p.art:Show()
    -- 넘어가던 지역에 들어섰으면 "도착!" 띠 3초
    if p.wideTarget then
        if p.wideTarget == m then
            local left = 0
            for _, e in ipairs(order) do if HereEntry(e, m) then left = left + 1 end end
            ShowBanner(p, "arrive", "도착!", ("%s · 남은 %d"):format(MapName(m) or "", left), "")
            p.arriveUntil = GetTime() + 3
        end
        p.wideTarget = nil
    end
    if p.ban and p.ban:IsShown() and not (p.arriveUntil and GetTime() < p.arriveUntil) then p.ban:Hide() end

    if p.mapID ~= m then p.mapID = m; PaintMapArt(p, m) end
    local px, py = PlayerXY(m)
    if px then
        p.me:ClearAllPoints(); p.me:SetPoint("CENTER", p.layer, "TOPLEFT", MapPoint(p, px, py))
        if GetPlayerFacing then local f = GetPlayerFacing(); if f then p.me:SetRotation(f) end end
        p.me:Show()
    else p.me:Hide() end
    local pts = { px and { px, py } or nil }
    if not pts[1] then pts = {} end
    local n, nc = 0, 0
    local W, H = p:GetWidth(), p:GetHeight()
    local chipBy = {}       -- 지역 이름 → 표 (같은 지역은 표 하나, 첫 번호)
    for i, e in ipairs(order) do
        local x, y = QuestPos(e, m)
        if OnMap(x, y) then
            n = n + 1
            local mk = MapMark(p, n)
            mk:SetParent(p.layer)
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
        elseif not HereEntry(e, m) and nc < 3 then
            -- 다른 지역: 가장자리 표 (지역마다 하나)
            local zk = ZoneKey(e)
            if not chipBy[zk] then
                local ex, ey = OffMapPos(e, m)
                nc = nc + 1
                local c = EdgeChip(p, nc)
                c.disc:SetVertexColor(e.done and 0.945 or P.acc[1], e.done and 0.851 or P.acc[2], e.done and 0.541 or P.acc[3], 1)
                c.n:SetText(i)
                c.t:SetText(zk .. " →")
                local cw = c.t:GetStringWidth() + 34
                c:SetWidth(cw)
                local cx, cy
                if ex then
                    -- 지도 가운데에서 그 방향으로, 칸 가장자리에 붙임
                    local dx, dy = ex / 100 * W - W / 2, ey / 100 * H - H / 2
                    local kx = math.abs(dx) > 0.01 and (W / 2 - cw / 2 - 6) / math.abs(dx) or math.huge
                    local ky = math.abs(dy) > 0.01 and (H / 2 - 17) / math.abs(dy) or math.huge
                    local k = math.min(kx, ky, 1)
                    cx, cy = W / 2 + dx * k, H / 2 + dy * k
                else
                    cx, cy = W - cw / 2 - 6, 30 + (nc - 1) * 28
                end
                for _, o in pairs(chipBy) do
                    if math.abs(o[2] - cy) < 24 and math.abs(o[1] - cx) < cw then cy = cy + 26 end
                end
                c:ClearAllPoints(); c:SetPoint("CENTER", p.layer, "TOPLEFT", cx, -cy); c:Show()
                chipBy[zk] = { cx, cy }
                pts[#pts + 1] = { cx / W * 100, cy / H * 100 }
            end
        end
    end
    for i = n + 1, #p.marks do p.marks[i]:Hide() end
    for i = nc + 1, #(p.chips or {}) do p.chips[i]:Hide() end
    MapDots(p, pts)
    return order
end

local function PaintSummary(order)
    local cnt, mins, xp, unknownXP = #order, 0, 0, false
    local names = {}
    for i, e in ipairs(order) do
        mins = mins + (e.done and 2 or 6)
        if e.xp then xp = xp + e.xp else unknownXP = true end
        local warnTag = ""
        if not e.done then
            if e.tag then warnTag = " |cffff8f8f[" .. (TAG_NAME[e.tag] or "정예") .. "]|r"
            elseif e.group and e.group > 1 then warnTag = " |cffff8f8f[파티]|r" end
        end
        if i <= 6 then names[#names + 1] = ("|cfff2b3c2%d|r %s"):format(i, e.done and ("반납 " .. e.title) or e.title) .. warnTag end
    end
    if #order > 6 then
        -- 맨 끝이 정예 · 던전이면 그것까지 보여 줘요 (뒤로 보낸 걸 알 수 있게)
        local last = order[#order]
        if last and not last.done and (last.tag or (last.group and last.group > 1)) and #order > 7 then
            names[#names + 1] = "…"
            names[#names + 1] = ("|cfff2b3c2%d|r %s |cffff8f8f[%s]|r"):format(#order, last.title, last.tag and (TAG_NAME[last.tag] or "정예") or "파티")
        else
            names[#names + 1] = ("… +%d"):format(#order - 6)
        end
    end
    board.sCount:SetText(cnt .. "개")
    -- 조심할 퀘: 정예 · 던전 · 공격대 · 파티, 그리고 내 레벨보다 3 이상 높은 퀘 (아직 안 한 것만)
    local warn, kinds, party = {}, {}, false
    for _, e in ipairs(order) do
        if not e.done then
            local why
            if e.tag then why = TAG_NAME[e.tag] or "정예"; party = true
            elseif e.group and e.group > 1 then why = "파티"; party = true
            else
                local _, k = Diff(e)
                if k == "hard" then why = "어려움" end
            end
            if why then
                warn[#warn + 1] = { e = e, why = why }
                kinds[why] = (kinds[why] or 0) + 1
            end
        end
    end
    board.warnList, board.warnParty = warn, party
    if cnt == 0 then
        board.sTime:SetText("-"); board.sTime:SetTextColor(P.tx[1], P.tx[2], P.tx[3]); board.sWarnSub:SetText("")
    elseif #warn == 0 then
        board.sTime:SetText("없음"); board.sTime:SetTextColor(0.62, 0.88, 0.56)
        board.sWarnSub:SetText("혼자 해도 돼요")
    else
        local parts = {}
        for _, k in ipairs({ "정예", "던전", "공격대", "파티", "어려움" }) do
            if kinds[k] then parts[#parts + 1] = k .. " " .. kinds[k] end
        end
        board.sTime:SetText(parts[1]); board.sTime:SetTextColor(1, 0.56, 0.56)
        local rest = {}
        for i = 2, #parts do rest[#rest + 1] = parts[i] end
        if party then rest[#rest + 1] = "길 맨 뒤" end
        board.sWarnSub:SetText(#rest > 0 and table.concat(rest, " · ") or "조심해서 가요")
    end
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
        Print("화면 퀘스트 목록을 Leel Quest로 바꿨어요. (허브 > 퀘스트 > 퀘스트 목록에서 바꿀 수 있어요)")
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
            if OnMap(x, y) then
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

local StartTour     -- 사용법 안내 (아래에서 만들어요)
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
    board.fFirst = Toggle(nil, "쉬움만", function() return onlyEasy end, function() onlyEasy = not onlyEasy end)
    place(board.fFirst)
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
    board.fRec = rec
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
    board.sCount = stat(14, "고른 퀘"); board.sTime = stat(90, "조심할 퀘"); board.sXP = stat(196, "경험치"); board.sLv = stat(300, "레벨")
    -- 조심할 퀘: 아래 작은 글 + 마우스를 올리면 목록
    board.sWarnSub = Font(sum, 10.5, DIM); board.sWarnSub:SetPoint("TOPLEFT", board.sTime, "BOTTOMLEFT", 0, -2)
    board.sWarnSub:SetWidth(104); board.sWarnSub:SetJustifyH("LEFT"); board.sWarnSub:SetWordWrap(false)
    local hov = CreateFrame("Frame", nil, sum); hov:SetPoint("TOPLEFT", 86, -8); hov:SetSize(108, 56)
    hov:EnableMouse(true)
    hov:SetScript("OnEnter", function(self)
        local list = board.warnList
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if not list or #list == 0 then
            GameTooltip:SetText("조심할 퀘 없음", 0.62, 0.88, 0.56)
            GameTooltip:AddLine("정예 · 던전 퀘나 내 레벨보다 3 이상 높은 퀘가 없어요.", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:SetText(("조심할 퀘 %d개"):format(#list), 1, 0.56, 0.56)
            for _, w in ipairs(list) do
                GameTooltip:AddDoubleLine(w.e.title, "|cffff8f8f" .. w.why .. "|r  Lv " .. (w.e.level or "?"), 1, 1, 1, 1, 1, 1)
            end
            if board.warnParty then GameTooltip:AddLine("정예 · 던전 퀘는 길 맨 뒤로 보냈어요. 파티를 구해서 가요.", 0.8, 0.8, 0.8, true)
            else GameTooltip:AddLine("혼자 하면 위험할 수 있어요. 레벨을 조금 올리고 가요.", 0.8, 0.8, 0.8, true) end
        end
        GameTooltip:Show()
    end)
    hov:SetScript("OnLeave", function() GameTooltip:Hide() end)
    board.order = Font(sum, 12, P.tx); board.order:SetPoint("TOPLEFT", 14, -66); board.order:SetPoint("RIGHT", -14, 0)
    board.order:SetJustifyH("LEFT"); board.order:SetSpacing(4)
    board.sum = sum
    board.go = Button(sum, "이 길로 출발", true, Start, 120)
    board.go:SetPoint("BOTTOMLEFT", 14, 14)
    local clear = Button(sum, "모두 빼기", false, function()
        CDB.sel = {}; CDB.route = nil; CDB.rec = nil; RefreshBoard(); RefreshTracker()
    end)
    clear:SetPoint("LEFT", board.go, "RIGHT", 8, 0)
    local legend = Font(sum, 10.5, DIM); legend:SetPoint("BOTTOMLEFT", 14, 50); legend:SetJustifyH("LEFT")
    legend:SetText(SRC_ICON.questie .. "Questie  " .. SRC_ICON.learned .. "잡던 곳  " .. SRC_ICON.game .. "게임 표시  " .. SRC_ICON.guide .. "길잡이 자료")

    -- "?" 사용법 (C안): 토끼가 말풍선으로 하나씩 알려줘요. 처음 열면 한 번 저절로
    local help = CreateFrame("Button", nil, board); help:SetSize(26, 26); help:SetPoint("RIGHT", board.cLog, "LEFT", -12, 0)
    -- E안: 토끼 동그라미 + 노란 "?" 뱃지
    local ho = help:CreateTexture(nil, "BACKGROUND"); ho:SetTexture(MEDIA .. "circle"); ho:SetPoint("TOPLEFT", -1.5, 1.5); ho:SetPoint("BOTTOMRIGHT", 1.5, -1.5); ho:SetVertexColor(0, 0, 0, 0.9)
    local hb = help:CreateTexture(nil, "BORDER"); hb:SetTexture(MEDIA .. "circle"); hb:SetAllPoints(); hb:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 1)
    local hi = help:CreateTexture(nil, "ARTWORK"); hi:SetTexture(MEDIA .. "bunny"); hi:SetAllPoints()
    local badge = CreateFrame("Frame", nil, help); badge:SetSize(14, 14); badge:SetPoint("CENTER", help, "TOPRIGHT", -1, -1)
    badge:SetFrameLevel(help:GetFrameLevel() + 2)
    local bo2 = badge:CreateTexture(nil, "BACKGROUND"); bo2:SetTexture(MEDIA .. "circle"); bo2:SetPoint("TOPLEFT", -1.5, 1.5); bo2:SetPoint("BOTTOMRIGHT", 1.5, -1.5); bo2:SetVertexColor(0, 0, 0, 0.9)
    local by = badge:CreateTexture(nil, "BORDER"); by:SetTexture(MEDIA .. "circle"); by:SetAllPoints(); by:SetVertexColor(1, 0.824, 0.478, 1)
    help.fs = Font(badge, 11, P.ink); help.fs:SetPoint("CENTER", 0, 0); help.fs:SetText("?"); help.fs:SetShadowColor(0, 0, 0, 0)
    local hh = help:CreateTexture(nil, "HIGHLIGHT"); hh:SetTexture(MEDIA .. "circle"); hh:SetAllPoints(); hh:SetVertexColor(1, 1, 1, 0.25); hh:SetBlendMode("ADD")
    help:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText("사용법"); GameTooltip:AddLine("토끼가 하나씩 알려줘요", 0.85, 0.85, 0.85); GameTooltip:Show()
    end)
    help:SetScript("OnLeave", function() GameTooltip:Hide() end)
    board.StartTour = function() if StartTour then StartTour() end end
    help:SetScript("OnClick", function() board.StartTour() end)
    board.help = help
    board:HookScript("OnShow", function()
        if not DB.helpSeen then
            DB.helpSeen = true
            C_Timer.After(0.4, function() if board:IsShown() then board.StartTour() end end)
        end
    end)
    board:SetScript("OnShow", function() board.map.mapID = nil; zoneSel = nil; board.offset = 0; ReadLog(); RefreshBoard() end)
    local acc = 0
    board:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc > 0.25 then acc = 0; PaintMap() end
    end)
    board:Hide()
    return board
end

----------------------------------------------------------------------
-- 사용법 안내 (C안): 판을 어둡게 하고 한 곳만 밝혀서, 토끼가 말풍선으로 하나씩
----------------------------------------------------------------------
local TOUR = {
    { "zones", "지역 고르기", "왼쪽에서 퀘를 할 지역을 눌러요.\n지금 있는 곳이 맨 위에 있어요. 숫자는 할 일 · 완료 수예요." },
    { "list", "하고 싶은 퀘 체크", "네모를 눌러 체크하면 길에 들어가요.\n빨간 Lv은 어려운 퀘, \"정예\" · \"던전\"은 혼자 하기 힘들어요. X는 퀘 포기." },
    { "filter", "고르기 힘들면 토끼 추천!", "\"토끼 추천\"을 누르면 쉬운 퀘부터, 가까운 것끼리 제가 골라 줄게요.\n\"쉬움만\" · \"혼자 가능\"으로 걸러 볼 수도 있어요." },
    { "map", "지도에서 확인", "고른 퀘가 번호로 찍히고, 분홍 점선이 가는 순서예요.\n오른쪽 아래 \"조심할 퀘\"에 마우스를 올리면 위험한 퀘가 보여요." },
    { "go", "출발!", "\"이 길로 출발\"을 누르면 Leel Quest 창이 당근으로 길을 알려줘요.\n목표를 다 채우면 소리로 알려 줄게요. 언제든 \"?\"로 다시 볼 수 있어요." },
}
local function MakeTour()
    if board.tour then return board.tour end
    local t = CreateFrame("Frame", nil, board)
    t:SetAllPoints(board); t:SetFrameLevel(board:GetFrameLevel() + 60); t:EnableMouse(true)
    t.dim = {}
    for i = 1, 4 do
        local d = t:CreateTexture(nil, "BACKGROUND"); d:SetTexture(WHITE); d:SetVertexColor(0.047, 0.031, 0.027, 0.78)
        t.dim[i] = d
    end
    t.edge = {}
    for i = 1, 4 do
        local e = t:CreateTexture(nil, "BORDER"); e:SetTexture(WHITE); e:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 1)
        t.edge[i] = e
    end
    -- 토끼
    t.bun = CreateFrame("Frame", nil, t); t.bun:SetSize(74, 74)
    local bo = t.bun:CreateTexture(nil, "BACKGROUND"); bo:SetTexture(MEDIA .. "circle"); bo:SetPoint("TOPLEFT", -2.5, 2.5); bo:SetPoint("BOTTOMRIGHT", 2.5, -2.5); bo:SetVertexColor(0, 0, 0, 0.9)
    local bc = t.bun:CreateTexture(nil, "BORDER"); bc:SetTexture(MEDIA .. "circle"); bc:SetAllPoints(); bc:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 1)
    local bi = t.bun:CreateTexture(nil, "ARTWORK"); bi:SetTexture(MEDIA .. "bunny"); bi:SetPoint("TOPLEFT", 6, -6); bi:SetPoint("BOTTOMRIGHT", -6, 6)
    local ag = t.bun:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
    local tr = ag:CreateAnimation("Translation"); tr:SetOffset(0, 5); tr:SetDuration(0.7); tr:SetSmoothing("IN_OUT")
    t.bunAnim = ag
    -- 말풍선
    local b = CreateFrame("Frame", nil, t); b:SetSize(360, 120)
    Plate(b, 14, { 0.125, 0.094, 0.086, 0.98 }, { P.acc[1], P.acc[2], P.acc[3], 1 })
    b.title = Font(b, 16, P.accHi); b.title:SetPoint("TOPLEFT", 16, -14); b.title:SetPoint("RIGHT", -16, 0); b.title:SetJustifyH("LEFT")
    b.body = Font(b, 12.5, P.tx); b.body:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -7); b.body:SetPoint("RIGHT", -16, 0)
    b.body:SetJustifyH("LEFT"); b.body:SetSpacing(3); b.body:SetWordWrap(true)
    b.dots = {}
    for i = 1, #TOUR do
        local d = b:CreateTexture(nil, "ARTWORK"); d:SetTexture(MEDIA .. "circle"); d:SetSize(8, 8)
        d:SetPoint("BOTTOMLEFT", 16 + (i - 1) * 13, 16)
        b.dots[i] = d
    end
    b.next = Button(b, "다음", true, function() t.Go(t.step + 1) end, 56)
    b.next:SetPoint("BOTTOMRIGHT", -12, 10)
    b.prev = Button(b, "이전", false, function() t.Go(t.step - 1) end, 56)
    b.prev:SetPoint("RIGHT", b.next, "LEFT", -6, 0)
    b.skip = CreateFrame("Button", nil, b); b.skip:SetSize(60, 20); b.skip:SetPoint("RIGHT", b.prev, "LEFT", -6, 0)
    b.skip.fs = Font(b.skip, 11.5, DIM); b.skip.fs:SetPoint("RIGHT", 0, 0); b.skip.fs:SetText("건너뛰기")
    b.skip:SetScript("OnClick", function() t:Hide() end)
    t.bub = b
    t:SetScript("OnMouseUp", function(_, btn) if btn == "RightButton" then t:Hide() end end)
    t:SetScript("OnHide", function() t.bunAnim:Stop() end)

    local function Target(key)
        if key == "zones" then return board.zones
        elseif key == "list" then return board.list
        elseif key == "filter" then return board.fFirst, board.fRec
        elseif key == "map" then return board.map
        elseif key == "go" then return board.sum end
    end
    function t.Go(i)
        if i < 1 then i = 1 end
        if i > #TOUR then t:Hide(); return end
        t.step = i
        local st = TOUR[i]
        local a, a2 = Target(st[1])
        local L0, T0 = board:GetLeft(), board:GetTop()
        local W, H = board:GetWidth(), board:GetHeight()
        local l, r, top, bot = 20, 200, 60, 200
        if a and a:GetLeft() and L0 then
            l, r = a:GetLeft() - L0, a:GetRight() - L0
            top, bot = T0 - a:GetTop(), T0 - a:GetBottom()
            if a2 and a2:GetLeft() then
                r = math.max(r, a2:GetRight() - L0); bot = math.max(bot, T0 - a2:GetBottom())
            end
        end
        local pad = 5
        l, r, top, bot = math.max(0, l - pad), math.min(W, r + pad), math.max(0, top - pad), math.min(H, bot + pad)
        local d = t.dim
        d[1]:ClearAllPoints(); d[1]:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0); d[1]:SetPoint("BOTTOMRIGHT", t, "TOPRIGHT", 0, -top)
        d[2]:ClearAllPoints(); d[2]:SetPoint("TOPLEFT", t, "TOPLEFT", 0, -bot); d[2]:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 0, 0)
        d[3]:ClearAllPoints(); d[3]:SetPoint("TOPLEFT", t, "TOPLEFT", 0, -top); d[3]:SetPoint("BOTTOMRIGHT", t, "TOPLEFT", l, -bot)
        d[4]:ClearAllPoints(); d[4]:SetPoint("TOPLEFT", t, "TOPLEFT", r, -top); d[4]:SetPoint("BOTTOMRIGHT", t, "TOPRIGHT", 0, -bot)
        local e = t.edge
        e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT", t, "TOPLEFT", l, -top); e[1]:SetSize(r - l, 2)
        e[2]:ClearAllPoints(); e[2]:SetPoint("TOPLEFT", t, "TOPLEFT", l, -bot + 2); e[2]:SetSize(r - l, 2)
        e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT", t, "TOPLEFT", l, -top); e[3]:SetSize(2, bot - top)
        e[4]:ClearAllPoints(); e[4]:SetPoint("TOPLEFT", t, "TOPLEFT", r - 2, -top); e[4]:SetSize(2, bot - top)
        -- 말풍선 글
        b.title:SetText(st[2]); b.body:SetText(st[3])
        local bh = 14 + 20 + 7 + math.ceil(b.body:GetStringHeight() or 40) + 48
        b:SetHeight(math.max(118, bh))
        for k, dt in ipairs(b.dots) do
            if k == i then dt:SetVertexColor(P.acc[1], P.acc[2], P.acc[3], 1) else dt:SetVertexColor(0.35, 0.27, 0.26, 1) end
        end
        b.prev:SetShown(i > 1)
        if b.next.SetLabel then b.next:SetLabel(i == #TOUR and "알겠어!" or "다음") end
        -- 자리: 길쭉한 곳(왼쪽 지역 · 퀘 목록)은 옆에, 나머지는 아래(자리 없으면 위)에. 토끼는 말풍선 왼쪽
        b:ClearAllPoints(); t.bun:ClearAllPoints()
        local bw = b:GetWidth()
        if bot - top > 300 then
            local x = r + 96
            if x + bw > W - 10 then x = l - bw - 20 end
            b:SetPoint("TOPLEFT", t, "TOPLEFT", x, -(top + 60))
        elseif H - bot > b:GetHeight() + 24 then
            b:SetPoint("TOPLEFT", t, "TOPLEFT", math.max(96, math.min(W - bw - 16, l + 40)), -(bot + 16))
        else
            b:SetPoint("BOTTOMLEFT", t, "TOPLEFT", math.max(96, math.min(W - bw - 16, l + 40)), -(top - 16))
        end
        t.bun:SetPoint("RIGHT", b, "LEFT", -12, -10)
        t.bunAnim:Play()
    end
    board.tour = t
    t:Hide()
    return t
end
StartTour = function()
    if not board then return end
    MakeTour()
    board.tour:Show()
    board.tour.Go(1)
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

-- 퀘스트 일지에서 그 퀘 열기 (게임 판마다 창이 달라서 되는 방법을 차례로)
local function ShowQuest(e)
    if not e or InCombatLockdown() then return end
    local id = e.id
    -- 1) 지도 옆 퀘스트 일지 (최신 창)
    if id and QuestMapFrame_OpenToQuestDetails then
        if pcall(QuestMapFrame_OpenToQuestDetails, id) then return end
    end
    -- 2) 클래식 퀘스트 일지: 줄 번호를 지금 다시 찾아서 (퀘가 늘거나 줄면 번호가 바뀜)
    local idx = e.index
    if id then
        if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
            local ok, i = pcall(C_QuestLog.GetLogIndexForQuestID, id); if ok and i then idx = i end
        elseif GetQuestLogIndexByID then
            local ok, i = pcall(GetQuestLogIndexByID, id); if ok and i and i > 0 then idx = i end
        end
    end
    local frame = _G.QuestLogFrame
    if frame and idx then
        if not frame:IsShown() then
            if ShowUIPanel then pcall(ShowUIPanel, frame) else frame:Show() end
            if not frame:IsShown() and ToggleQuestLog then pcall(ToggleQuestLog) end
        end
        if QuestLog_SetSelection then pcall(QuestLog_SetSelection, idx)
        elseif SelectQuestLogEntry then pcall(SelectQuestLogEntry, idx) end
        if QuestLog_Update then pcall(QuestLog_Update) end
        if QuestLog_UpdateQuestDetails then pcall(QuestLog_UpdateQuestDetails) end
        -- 목록에서 그 줄이 보이게 스크롤
        local sf = _G.QuestLogListScrollFrame
        if sf and FauxScrollFrame_SetOffset and QUESTS_DISPLAYED then
            local off = math.max(0, idx - math.floor(QUESTS_DISPLAYED / 2))
            pcall(FauxScrollFrame_SetOffset, sf, off)
            if sf.ScrollBar then pcall(sf.ScrollBar.SetValue, sf.ScrollBar, off * (QUESTLOG_QUEST_HEIGHT or 16)) end
            if QuestLog_Update then pcall(QuestLog_Update) end
        end
        return
    end
    -- 3) 마지막: 그냥 퀘스트 일지 열기
    if id and C_QuestLog and C_QuestLog.SetSelectedQuest then pcall(C_QuestLog.SetSelectedQuest, id) end
    if ToggleQuestLog then pcall(ToggleQuestLog) end
end

-- 당근 게이지 링 (G안): 링이 가까워질수록 주황으로 차오르고, 안의 당근이 가야 할 방향을 가리켜요
--   반쪽 링 두 장을 각각 왼쪽/오른쪽 반만 보이는 틀 안에서 돌려서 시계 방향으로 채워요
local FLM = "Interface\\AddOns\\ForgLeveling\\media\\"
local CARROT = { 1, 0.604, 0.235 }
local function NavRing(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    local edge = f:CreateTexture(nil, "BACKGROUND", nil, 0); edge:SetTexture(MEDIA .. "circle")
    edge:SetPoint("TOPLEFT", -1.5, 1.5); edge:SetPoint("BOTTOMRIGHT", 1.5, -1.5); edge:SetVertexColor(0, 0, 0, 0.85)
    local track = f:CreateTexture(nil, "BACKGROUND", nil, 1); track:SetTexture(FLM .. "nav_ring"); track:SetAllPoints()
    track:SetVertexColor(0.227, 0.169, 0.157, 1)
    local function Half(right)
        local c = CreateFrame("Frame", nil, f)
        if right then c:SetPoint("TOPLEFT", f, "TOP", 0, 0); c:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        else c:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); c:SetPoint("BOTTOMRIGHT", f, "BOTTOM", 0, 0) end
        local okClip = pcall(c.SetClipsChildren, c, true)
        local t = c:CreateTexture(nil, "ARTWORK"); t:SetTexture(FLM .. "nav_half")
        t:SetSize(size, size); t:SetPoint("CENTER", f, "CENTER", 0, 0)
        t:SetVertexColor(CARROT[1], CARROT[2], CARROT[3], 1)
        return c, t, okClip
    end
    f.cR, f.tR, f.clip = Half(true)
    f.cL, f.tL = Half(false)
    local inner = CreateFrame("Frame", nil, f); inner:SetAllPoints(); inner:SetFrameLevel(f:GetFrameLevel() + 5)
    local disc = inner:CreateTexture(nil, "BACKGROUND"); disc:SetTexture(MEDIA .. "circle")
    disc:SetPoint("TOPLEFT", 3.5, -3.5); disc:SetPoint("BOTTOMRIGHT", -3.5, 3.5); disc:SetVertexColor(0.125, 0.094, 0.086, 1)
    f.carrot = inner:CreateTexture(nil, "ARTWORK"); f.carrot:SetTexture(FLM .. "nav_carrot")
    f.carrot:SetSize(size * 0.62, size * 0.62); f.carrot:SetPoint("CENTER", 0, 0)
    function f:SetProgress(p)
        p = math.max(0, math.min(1, p or 0))
        if not self.clip then self.cR:Hide(); self.cL:Hide(); return end   -- 잘라 보이기가 안 되면 빈 링만
        local tau = math.pi * 2
        if p <= 0.5 then
            self.tR:SetRotation(-p * tau); self.cR:SetShown(p > 0); self.cL:Hide()
        else
            self.tR:SetRotation(-math.pi); self.cR:Show()
            self.tL:SetRotation(math.pi - (p - 0.5) * tau); self.cL:Show()
        end
    end
    f:SetProgress(0)
    return f
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

    -- 난이도 작은 알약 (쉬움 · 보통 · 어려움 · 파티)
    r.diff = MakeChip(r); r.diff:SetHeight(16); r.diff:SetPoint("LEFT", r.title, "RIGHT", 6, 0)
    -- 지금 퀘: 줄 오른쪽 끝에 당근 링 + 거리
    r.dist = Num(r, 16, { 1, 0.945, 0.957 }); r.dist:SetPoint("RIGHT", r, "TOPRIGHT", -2, -10); r.dist:SetJustifyH("LEFT")
    r.dist:SetWidth(40)       -- 폭 고정: 숫자 길이가 바뀌어도 링이 안 흔들려요
    r.dist:SetShadowColor(0, 0, 0, 1); r.dist:SetShadowOffset(1, -1)
    -- "여기" 같은 한글은 숫자 글씨체(Barlow)에 없어서 네모로 나와요: 한글용 글씨를 따로 겹쳐 둬요
    r.distKo = Font(r, 14, CARROT); r.distKo:SetPoint("LEFT", r.dist, "LEFT", 0, 0)
    r.distKo:SetShadowColor(0, 0, 0, 1); r.distKo:SetShadowOffset(1, -1); r.distKo:Hide()
    r.ring = NavRing(r, 28); r.ring:SetPoint("RIGHT", r.dist, "LEFT", -5, 0)
    r.arrow = r.ring.carrot
    -- 목표 달성 반짝: 왼쪽 초록 띠 + 오른쪽으로 옅어지는 초록 판
    r.hl = r:CreateTexture(nil, "BACKGROUND"); r.hl:SetTexture(WHITE)
    r.hl:SetPoint("TOPLEFT", -6, 3); r.hl:SetPoint("BOTTOMRIGHT", 0, 2)
    if not pcall(function()
        r.hl:SetGradient("HORIZONTAL", CreateColor(0.227, 0.51, 0.275, 0.45), CreateColor(0.227, 0.51, 0.275, 0))
    end) then r.hl:SetVertexColor(0.227, 0.51, 0.275, 0.25) end
    r.hlBar = r:CreateTexture(nil, "BORDER"); r.hlBar:SetTexture(WHITE); r.hlBar:SetWidth(3)
    r.hlBar:SetPoint("TOPLEFT", r.hl, "TOPLEFT", 0, 0); r.hlBar:SetPoint("BOTTOMLEFT", r.hl, "BOTTOMLEFT", 0, 0)
    r.hlBar:SetVertexColor(0.56, 0.86, 0.61, 1)
    r.hl:Hide(); r.hlBar:Hide()
    -- 반납 상자 (같은 NPC 반납을 한 줄로 묶을 때): 노란 둥근 판
    r.boxF = CreateFrame("Frame", nil, r)
    r.boxF:SetPoint("TOPLEFT", -6, 4); r.boxF:SetPoint("BOTTOMRIGHT", 2, 0)
    r.boxF:SetFrameLevel(math.max(0, r:GetFrameLevel() - 1))
    r.boxFill, r.boxEdge = Plate(r.boxF, 10, { 0.945, 0.851, 0.541, 0.1 }, { 0.945, 0.851, 0.541, 0.45 })
    r.boxF:Hide()
    -- 완료 토끼 도장 (작게, 반납할 때까지 이름 옆에)
    r.stamp = r:CreateTexture(nil, "OVERLAY", nil, 2)
    r.stamp:SetTexture(FLM .. "stamp"); r.stamp:SetSize(20, 20)
    r.stamp:SetPoint("LEFT", r.diff, "RIGHT", 4, 0)
    pcall(r.stamp.SetRotation, r.stamp, -0.21)
    r.stamp:Hide()
    r.objs = {}
    r:SetScript("OnClick", function(self, btn)
        local e = self.e
        if not e then return end
        if btn == "RightButton" then
            -- 오른쪽 클릭: 이번 길에서 빼기 (퀘스트 포기는 고르기 판에서) · 반납 상자면 상자째
            for _, ge in ipairs(self.group or {}) do Sel()[ge.id] = nil end
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
        fs.strike = r:CreateTexture(nil, "OVERLAY"); fs.strike:SetTexture(WHITE); fs.strike:SetHeight(1.5)
        fs.strike:SetVertexColor(0.56, 0.86, 0.61, 0.9); fs.strike:Hide()
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

    -- 목표 달성 · 퀘스트 완료 띠 (A안): 머리 줄 바로 아래 얇은 띠, 3초 뒤 걷혀요 (접기 단추와 안 겹침)
    local gp = CreateFrame("Frame", nil, trk)
    gp:SetHeight(26)
    gp:SetFrameLevel(trk:GetFrameLevel() + 6)
    gp.fill, gp.edge = Plate(gp, 9, { 0.184, 0.353, 0.212, 0.94 }, { 0.56, 0.86, 0.61, 1 })
    gp.ck = gp:CreateTexture(nil, "ARTWORK"); gp.ck:SetSize(14, 14); gp.ck:SetPoint("LEFT", 8, 0)
    gp.fs = Font(gp, 13, { 0.9, 1, 0.91 }); gp.fs:SetPoint("LEFT", gp.ck, "RIGHT", 5, 0); gp.fs:SetShadowColor(0, 0, 0, 0)
    gp.sub = Font(gp, 11.5, { 0.9, 1, 0.91 }); gp.sub:SetPoint("LEFT", gp.fs, "RIGHT", 7, 0); gp.sub:SetPoint("RIGHT", gp, "RIGHT", -8, 0)
    gp.sub:SetJustifyH("LEFT"); gp.sub:SetWordWrap(false); gp.sub:SetShadowColor(0, 0, 0, 0); gp.sub:SetAlpha(0.8)
    function gp:Style(full)
        if full then
            if self.fill.SetColor then self.fill:SetColor({ P.acc[1], P.acc[2], P.acc[3], 0.97 }) end
            if self.edge.SetColor then self.edge:SetColor({ P.accHi[1], P.accHi[2], P.accHi[3], 1 }) end
            self.ck:SetTexture(FLM .. "stamp"); self.ck:SetSize(18, 18)
            self.fs:SetTextColor(P.ink[1], P.ink[2], P.ink[3]); self.sub:SetTextColor(P.ink[1], P.ink[2], P.ink[3])
        else
            if self.fill.SetColor then self.fill:SetColor({ 0.184, 0.353, 0.212, 0.94 }) end
            if self.edge.SetColor then self.edge:SetColor({ 0.56, 0.86, 0.61, 1 }) end
            self.ck:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready"); self.ck:SetSize(13, 13)
            self.fs:SetTextColor(0.9, 1, 0.91); self.sub:SetTextColor(0.9, 1, 0.91)
        end
    end
    gp:SetScript("OnUpdate", function(self, el)
        self.left = (self.left or 0) - el
        if self.left <= 0 then
            self:Hide()
            if RefreshTracker then RefreshTracker() end
            return
        end
        local age = (self.dur or 3) - self.left
        local a = math.min(1, age / 0.18)
        if self.left < 0.35 then a = self.left / 0.35 end
        self:SetAlpha(a)
    end)
    gp:Hide()
    trk.goal = gp

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
    -- 근처 반납을 알아서 길 앞으로 (C안): 싸우는 중이 아니고, 아직 앞에 없을 때만
    function trk.AutoFront(g)
        if not g or InCombatLockdown() or UnitAffectingCombat("player") then return end
        trk.nearHold = trk.nearHold or {}
        if trk.nearHold[g.npc] then return end
        local route = Route()
        local first = route[1]
        if first and first.done and TurnNpc(first) == g.npc then return end   -- 이미 맨 앞
        local before = {}
        for i, id in ipairs(CDB.route) do before[i] = id end
        local beforeTotal = CDB.total
        trk.PullNear()
        Toast("근처 반납 " .. #g.list .. "개를 앞으로 옮겼어요", g.npc, "되돌리기", function()
            CDB.route = before
            CDB.total = beforeTotal
            trk.nearHold[g.npc] = true
            RefreshTracker(); RefreshBoard()
        end, "근처 반납 " .. #g.list .. "개를 앞으로", g.npc)
        if trk.band and trk.band:IsShown() then trk.band.left = 5 end
    end
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
            -- 되돌리기 한 NPC는 멀어지면(150m 밖) 다시 옮길 수 있게
            for npc in pairs(self.nearHold or {}) do
                if not (g and g.npc == npc) then self.nearHold[npc] = nil end
            end
            if sig ~= (self.nearSig or "") then
                self.nearSig = sig
                if g then
                    if DB.autoNear ~= false and CDB.route and #CDB.route > 0 then
                        self.AutoFront(g)
                    else
                        NearToast(g)
                    end
                end
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
        if not (px and x) then r.arrow:Hide(); r.ring:SetProgress(0); r.dist:SetText("") return end
        local yd, dx, dy = Yards(m, px, py, x, y)
        local ang = yd and math.atan2(dy, dx) or math.atan2(-(x - px) * 1.5, -(y - py))
        local f = GetPlayerFacing and GetPlayerFacing()
        if f then
            -- 당근 방향은 부드럽게 따라가요 (걸을 때 위치 값이 조금씩 튀어도 안 떨리게)
            local want = ang - f
            local cur = self.navAng or want
            local d = (want - cur + math.pi) % (2 * math.pi) - math.pi
            if math.abs(d) < 0.03 then cur = cur else cur = cur + d * 0.35 end
            self.navAng = cur
            r.arrow:SetRotation(cur); r.arrow:Show()
        else r.arrow:Hide() end
        -- 링: 이 퀘를 따라가기 시작했을 때(가장 멀었을 때) 거리 대비 얼마나 왔나
        if yd then
            if self.navId ~= e.id then self.navId = e.id; self.navMax = yd end
            if yd > (self.navMax or 0) then self.navMax = yd end
            local p = (yd < 15) and 1 or (1 - yd / math.max(self.navMax, 1))
            p = math.floor(p * 40 + 0.5) / 40      -- 2.5% 단위로만 움직여서 링 끝이 덜 떨리게
            r.ring:SetProgress(p)
            if yd < 15 then
                r.dist:SetText(""); r.distKo:SetText("여기"); r.distKo:Show()
            else
                r.distKo:Hide()
                r.dist:SetText(yd >= 1000 and ("%.1fk"):format(yd / 1000) or ("%dm"):format(yd)); r.dist:SetTextColor(1, 0.945, 0.957)
            end
        else
            r.ring:SetProgress(0); r.dist:SetText(""); r.distKo:Hide()
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

----------------------------------------------------------------------
-- 목표 달성 (D안): 목표가 다 차는 순간 판 머리 초록 알약 + 그 퀘 줄 반짝 + 르엘 소리
----------------------------------------------------------------------
local goal                -- { id, t, full }
local stampFx             -- 도장 효과 중인 퀘 { id, big }
local newAt = {}          -- 새로 길에 넣은 퀘 id → 넣은 시각 ("새 퀘" 꼬리표 1분)
local GOAL_SEC = 8
-- 소리: 목표 하나 참 → 짧은 "또롱"(goal1) / 퀘스트 완료 → 깡총깡총깡총 + 오르골(done)
--   DB.sndOff = true 면 둘 다 꺼요
local SND_DIR = "Interface\\AddOns\\ForgLeveling\\media\\"
local sndHandle
local function PlayOgg(name)
    if sndHandle and StopSound then pcall(StopSound, sndHandle, 200) end
    local ok, will, h = pcall(PlaySoundFile, SND_DIR .. name .. ".ogg", "Master")
    sndHandle = ok and will and h or nil
end
local function DoneSound() PlayOgg("done") end
-- 물어볼 때 (새 퀘 넣을까요? · 근처 반납 들를까요?): 깡총 + "띠링?"
local function AskSound() if not DB.sndOff then PlayOgg("ask") end end
local function Voice(kind)
    if DB.sndOff then return end
    if kind == "zone" then return end
    if kind == "goal" then PlayOgg("goal1") else DoneSound() end
end
-- 퀘스트 완료: 토끼 도장 쾅 (A안)
--   0~0.15초 크게(140%) → 제 크기로 튕기며 찍힘 + 고리 두 개 퍼짐, 0.9초까지 머문 뒤 작아지며 이름 옆 작은 도장으로
--   싸우는 중이면 절반 크기
local function StampFx(id)
    if not trk or DB.fxOff then return end
    local row
    for _, r in ipairs(trk.rows or {}) do if r:IsShown() and r.e and r.e.id == id then row = r break end end
    if not row then return end
    local fx = trk.stampFx
    if not fx then
        fx = CreateFrame("Frame", nil, trk)
        fx:SetFrameStrata(trk:GetFrameStrata()); fx:SetFrameLevel(trk:GetFrameLevel() + 30)
        fx:SetSize(80, 80)
        fx.r1 = fx:CreateTexture(nil, "ARTWORK", nil, 1); fx.r1:SetTexture(FLM .. "stamp_ring")
        fx.r2 = fx:CreateTexture(nil, "ARTWORK", nil, 1); fx.r2:SetTexture(FLM .. "stamp_ring")
        fx.big = fx:CreateTexture(nil, "OVERLAY", nil, 3); fx.big:SetTexture(FLM .. "stamp")
        for _, t in ipairs({ fx.r1, fx.r2, fx.big }) do t:SetPoint("CENTER") end
        fx.r1:SetVertexColor(P.acc[1], P.acc[2], P.acc[3]); fx.r2:SetVertexColor(P.acc[1], P.acc[2], P.acc[3])
        pcall(fx.big.SetRotation, fx.big, -0.21)
        trk.stampFx = fx
    end
    local k = (InCombatLockdown() or UnitAffectingCombat("player")) and 0.5 or 1
    local size = 78 * k
    fx:ClearAllPoints(); fx:SetPoint("CENTER", row, "TOPLEFT", math.min(trk:GetWidth() * 0.62, 220), -24)
    stampFx = { id = id, big = true }
    fx.t = 0
    fx:Show()
    fx:SetScript("OnUpdate", function(self, el)
        self.t = self.t + el
        local t = self.t
        -- 도장: 0.15초 동안 140% → 100% (살짝 튕김)
        local s
        if t < 0.15 then
            local u = t / 0.15
            s = 1.4 - 0.48 * u * u            -- 92% 까지 눌렸다가
        elseif t < 0.25 then
            s = 0.92 + 0.08 * ((t - 0.15) / 0.1)
        elseif t < 0.9 then
            s = 1
        else
            s = math.max(0.26, 1 - (t - 0.9) / 0.25 * 0.74)   -- 작아지며 사라짐 (이름 옆 작은 도장으로)
        end
        local a = (t < 0.06 and t / 0.06) or (t > 1.0 and math.max(0, 1 - (t - 1.0) / 0.15)) or 1
        self.big:SetSize(size * s, size * s); self.big:SetAlpha(a)
        -- 고리 두 개: 찍히는 순간부터 퍼지며 흐려짐
        local function Ring(tex, delay)
            local u = (t - 0.12 - delay) / 0.45
            if u < 0 or u > 1 then tex:Hide() return end
            local rs = size * (1.05 + 0.75 * u)
            tex:SetSize(rs, rs); tex:SetAlpha(0.7 * (1 - u)); tex:Show()
        end
        Ring(self.r1, 0); Ring(self.r2, 0.1)
        if t > 1.15 then
            self:Hide(); self:SetScript("OnUpdate", nil)
            stampFx = nil
            if RefreshTracker then RefreshTracker() end
        end
    end)
end

local function GoalLive(e)
    return goal and e and goal.id == e.id and (GetTime() - goal.t) < GOAL_SEC
end
local function Goal(id, full, sub)
    goal = { id = id, t = GetTime(), full = full }
    if full then
        -- "퀘스트를 완료했습니다." + 길에 할 퀘가 남았으면 "다음 퀘스트로", 없으면 "반납하러"
        local more = false
        for _, e in ipairs(Route()) do
            if not e.done and e.id ~= id then more = true; break end
        end
        Voice(more and "next" or "done")
    else
        Voice("goal")      -- 목표 하나만 찬 건 짧은 효과음
    end
    if trk and trk.goal and not DB.trkFold then
        local g = trk.goal
        g:Style(full)
        g.fs:SetText(full and "퀘스트 완료!" or "목표 달성!")
        g.sub:SetText(full and "반납하러 가요" or (sub or ""))
        g.dur = 3; g.left = 3
        g:SetAlpha(0)
        g:Show()
        if RefreshTracker then RefreshTracker() end
    end
    C_Timer.After(GOAL_SEC + 0.1, function() if RefreshTracker then RefreshTracker() end end)
    if full then
        -- 줄이 반납 모양으로 다시 그려진 다음에 찍어요
        C_Timer.After(0.05, function()
            if RefreshTracker then RefreshTracker() end
            StampFx(id)
        end)
    end
end
local prevObj = {}
local function CheckGoals()
    local hitId, hitFull, hitSub
    local seen = {}
    for _, e in ipairs(log) do
        if e.id then
            seen[e.id] = true
            local cur = { done = e.done }
            for j, o in ipairs(e.objs) do cur[j] = o.done end
            local p = prevObj[e.id]
            if p then
                if e.done and p.done == false then hitId, hitFull = e.id, true
                elseif not hitId then
                    for j = 1, #e.objs do
                        if cur[j] and p[j] == false then
                            hitId = e.id
                            local o = e.objs[j]
                            hitSub = o and ((o.have and o.need) and ("%s %d/%d"):format(o.text, o.have, o.need) or o.text) or nil
                            break
                        end
                    end
                end
            end
            prevObj[e.id] = cur
        end
    end
    for id in pairs(prevObj) do if not seen[id] then prevObj[id] = nil end end
    if hitId then Goal(hitId, hitFull, hitSub) end
end

RefreshTracker = function()
    if not trk then return end
    -- 반납 상자가 다 비면(그 NPC 반납을 다 했으면) "반납 끝!" 띠 2초
    do
        local nowNpc = {}
        for _, id in ipairs(CDB.route or {}) do
            local e = byId[id]
            local npc = e and Sel()[id] and TurnNpc(e)
            if npc then nowNpc[npc] = nowNpc[npc] or {}; table.insert(nowNpc[npc], id) end
        end
        for npc, ids in pairs(trk.lastNpcs or {}) do
            if not nowNpc[npc] then
                local gone = true
                for _, id in ipairs(ids) do if byId[id] then gone = false end end
                if gone and trk.goal and not DB.trkFold then
                    local g = trk.goal
                    g:Style(true); g.fs:SetText("반납 끝!"); g.sub:SetText(npc)
                    g.dur = 2; g.left = 2; g:SetAlpha(0); g:Show()
                end
            end
        end
        trk.lastNpcs = nowNpc
    end
    -- 근처 반납 노란 띠
    local near = NearTurnins()
    trk.nearG = near
    -- 근처 반납이 새로 생기면 한 번 "띠링?" (같은 NPC면 다시 안 울려요)
    if near and near.npc ~= trk.nearSnd then trk.nearSnd = near.npc; if AskSound then AskSound() end
    elseif not near then trk.nearSnd = nil end
    if near and not DB.trkFold and DB.autoNear == false then
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
    -- 목표 달성 · 완료 띠: 위의 띠들 바로 아래
    if trk.goal:IsShown() then
        trk.goal:ClearAllPoints()
        trk.goal:SetPoint("TOPLEFT", trk.head, "BOTTOMLEFT", 0, -6 - nearH); trk.goal:SetPoint("TOPRIGHT", trk.head, "BOTTOMRIGHT", 0, -6 - nearH)
        nearH = nearH + 32
    end
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
    -- 같은 NPC 반납은 한 상자로 (C안)
    local items, npcItem = {}, {}
    for i, e in ipairs(route) do
        local npc = DB.groupTurnin ~= false and TurnNpc(e)
        if npc and npcItem[npc] then
            table.insert(npcItem[npc].group, e)
        else
            local it = { e = e, idx = i }
            if npc then it.group = { e }; it.npc = npc; npcItem[npc] = it end
            items[#items + 1] = it
        end
    end
    local nearG = (DB.groupTurnin ~= false) and NearTurnins() or nil
    for k = 1, math.min(#items, maxq) do
        local it = items[k]
        local i = it.idx
        local e = it.e
        local need = 20 + math.max(1, e.done and 1 or #e.objs) * 15 + 8
        if shown > 0 and (-y + need + 22) > room then break end
        shown = shown + 1
        local r = trk.rows[shown] or MakeRow(shown)
        r.e = e
        r.group = it.group
        r.cur = (k == 1)
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
        local isNew = false
        for _, ge in ipairs(it.group or { e }) do
            if newAt[ge.id] and (GetTime() - newAt[ge.id]) < 60 then isNew = true end
        end
        if it.group then
            r.title:SetText(("%s에게 반납 %d"):format(it.npc, #it.group) .. (isNew and " |cff8fdc9b새 반납|r" or ""))
        else
            r.title:SetText(isNew and (e.title .. " |cff8fdc9b새 퀘|r") or e.title)
        end
        if e.done then r.title:SetTextColor(YEL[1], YEL[2], YEL[3]) else r.title:SetTextColor(P.tx[1], P.tx[2], P.tx[3]) end
        local dt, dk, dc = Diff(e)
        r.diff:Set(dt, dc or dk)
        r.diff:SetShown(not it.group)
        r.boxF:SetShown(it.group and true or false)
        if it.group then
            local hot = r.cur or (nearG and nearG.npc == it.npc)
            if r.boxFill.SetColor then r.boxFill:SetColor({ 0.945, 0.851, 0.541, hot and 0.2 or 0.1 }) end
            if r.boxEdge.SetColor then r.boxEdge:SetColor({ 0.945, 0.851, 0.541, hot and 0.95 or 0.45 }) end
            r.boxF:SetAlpha((hot or k <= 2) and 1 or 0.75)
        end
        r.stamp:SetShown(e.done and not it.group and not (stampFx and stampFx.id == e.id and stampFx.big) and true or false)
        local diffW = it.group and 0 or (r.diff:GetWidth() + 8)
        r.title:SetWidth(math.min(r.title:GetStringWidth() + 2, W - 28 - diffW - (r.cur and 82 or 0) - ((e.done and not it.group) and 24 or 0)))
        r.ring:SetShown(r.cur and true or false); r.dist:SetShown(r.cur and true or false)
        if not r.cur then r.distKo:Hide() end
        if not r.cur then r.dist:SetText("") end
        -- 목표 줄
        local live = GoalLive(e)
        r.hl:SetShown(live and true or false); r.hlBar:SetShown(live and true or false)
        local lines = {}
        if it.group then
            -- 상자: 퀘 이름들 한 줄 + NPC 앞이면 안내
            local names = {}
            for _, ge in ipairs(it.group) do
                names[#names + 1] = ge.title
            end
            lines[1] = { table.concat(names, " · "), false }
            if nearG and nearG.npc == it.npc and nearG.d < 15 then
                lines[2] = { #it.group > 1 and ("▶ 말 걸면 %d개 다 반납할 수 있어요"):format(#it.group) or "▶ 말 걸면 반납할 수 있어요", false, "next" }
            end
        elseif e.done then
            local g = guide[e.key]
            if live then
                for _, o in ipairs(e.objs) do
                    local t = (o.have and o.need) and ("%s %d/%d"):format(o.text, o.have, o.need) or o.text
                    lines[#lines + 1] = { "· " .. t, true, "strike" }
                end
                lines[#lines + 1] = { "▶ 이제 반납하러 가요", false, "next" }
            else
                lines[1] = { "· " .. Progress(e), false }
            end
        else
            local nextMarked = false
            for _, o in ipairs(e.objs) do
                local t = (o.have and o.need) and ("%s %d/%d"):format(o.text, o.have, o.need) or o.text
                if live and o.done then
                    lines[#lines + 1] = { "· " .. t, true, "strike" }
                elseif live and not o.done and not nextMarked then
                    nextMarked = true
                    lines[#lines + 1] = { "▶ 이제 이거: " .. t, false, "next" }
                else
                    lines[#lines + 1] = { "· " .. t, o.done }
                end
            end
            if #lines == 0 then lines[1] = { "· " .. Progress(e), false } end
        end
        -- 목표 줄: 길면 다음 줄로 넘겨요 (잘리지 않게)
        local oy = 20
        for j, l in ipairs(lines) do
            local fs = ObjLine(r, j)
            fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", r, "TOPLEFT", 30, -oy); fs:SetWidth(W - 34)
            fs:SetText(l[1])
            if l[3] == "strike" then fs:SetTextColor(0.56, 0.86, 0.61)
            elseif l[3] == "next" then fs:SetTextColor(P.accHi[1], P.accHi[2], P.accHi[3])
            elseif l[2] then fs:SetTextColor(0.54, 0.48, 0.46) else fs:SetTextColor(0.9, 0.84, 0.82) end
            fs:Show()
            -- 다 찬 목표에 가로줄
            if l[3] == "strike" then
                local sw = 60
                pcall(function() local v = fs:GetStringWidth(); if type(v) == "number" then sw = v end end)
                fs.strike:ClearAllPoints(); fs.strike:SetPoint("TOPLEFT", fs, "TOPLEFT", 10, -7)
                fs.strike:SetWidth(math.max(4, math.min(sw, W - 34) - 10)); fs.strike:Show()
            else
                fs.strike:Hide()
            end
            oy = oy + math.max(15, math.ceil(fs:GetStringHeight() or 13) + 3)
        end
        for j = #lines + 1, #r.objs do r.objs[j]:Hide(); r.objs[j].strike:Hide() end
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
    local rest = 0
    for k = shown + 1, #items do rest = rest + (items[k].group and #items[k].group or 1) end
    -- 보류 (물어봤는데 안 넣은 위험한 퀘)
    local held, heldName = 0, nil
    for id in pairs(CDB.held or {}) do
        local he = byId[id]
        if he and not Sel()[id] then held = held + 1; heldName = heldName or he.title else CDB.held[id] = nil end
    end
    local moreTxt = rest > 0 and ("+ %d개 더"):format(rest) or nil
    if held > 0 then
        local h = ("|cff9a8a86보류 %d · %s%s (퀘판에서 넣기)|r"):format(held, heldName or "", held > 1 and " 외" or "")
        moreTxt = moreTxt and (moreTxt .. "   " .. h) or h
    end
    if moreTxt then
        trk.more:ClearAllPoints(); trk.more:SetPoint("TOPLEFT", trk, "TOPLEFT", 0, y - 2)
        trk.more:SetText(moreTxt)
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

-- OpenMap(이어 붙인 지도)이 보이는 중이면: 지도 m의 (x, y 0~1)가 세계 지도 그림판 위 어디인지 (0~1, 밖일 수도)
-- nil = OpenMap 아님(평소대로), false = 못 놓음
local function OMCanvas(m, x, y)
    local OM = _G.OpenMapAPI
    if not (OM and OM.major == 1 and (OM.version or 0) >= 2 and OM.IsStitched and OM.IsStitched()) then return end
    if not (m and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return false end
    local ok, cont, v = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x, y))
    if not (ok and cont and v) then return false end
    local ok2, cx, cy = pcall(OM.CanvasFromWorldPos, cont, v.x, v.y)
    if ok2 and cx then return cx, cy end
    return false
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
    -- OpenMap이 이어 붙인 지도를 보여 주는 중이면 옆 지역까지 이어서 그려요
    local stitched = OMCanvas(here, 0.5, 0.5) ~= nil
    if not (m and (m == here or stitched) and W and W > 0) then
        for _, bd in ipairs(wmLayer.badges or {}) do bd:Hide() end
        wmLayer:Finish(); return
    end
    -- 내 지역 지도(%) → 그림판 위 자리
    local function At(x, y)
        if stitched then
            local cx, cy = OMCanvas(here, x / 100, y / 100)
            if cx then return cx * 100, cy * 100 end
            return
        end
        return x, y
    end
    local pts = {}
    for _, p in ipairs(RoutePoints(here)) do
        if stitched then
            local cx, cy = At(p[1], p[2])
            if cx then pts[#pts + 1] = { cx, cy, p[3], p[4], p[5] } end
        elseif p[1] >= 0 and p[1] <= 100 and p[2] >= 0 and p[2] <= 100 then
            pts[#pts + 1] = p   -- 옆 지역 목표는 지도 위에 안 그려요
        end
    end
    local px, py = PlayerXY(here)
    if px then px, py = At(px, py) end
    local scale = math.max(0.5, W / 1002)
    if stitched then scale = 1 / math.max(0.05, canvas:GetScale() or 1) * 0.9 end   -- 확대해도 화면에서 같은 크기
    local line = {}
    if px then line[1] = { px, py } end
    for _, p in ipairs(pts) do line[#line + 1] = p end
    for i = 2, #line do
        local a, b = line[i - 1], line[i]
        local ax, ay, bx, by = a[1] / 100 * W, -a[2] / 100 * H, b[1] / 100 * W, -b[2] / 100 * H
        local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
        local step = 14 * scale
        local cnt = math.min(500, math.floor(len / step))
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
        if e.done then local x, y = QuestPos(e, m); if x and x >= 0 and x <= 100 and y >= 0 and y <= 100 then done = done + 1 end
        elseif InZone(e, m) then here = here + 1 end
    end
    if here + done == 0 then return end
    seenZone[zone] = true
    if Voice then Voice("zone") end
    Toast(zone .. " 도착!", ("받아 둔 퀘 중 여기서 할 것 %d개 · 완료 %d개"):format(here, done), "고르기", function()
        MakeBoard(); board:Show()
    end, zone, ("할 것 %d · 완료 %d"):format(here, done))
end

-- 새 퀘를 받으면 (B안): 혼자 하기 좋은 퀘는 알아서 길에 넣고, 위험한 퀘만 물어봐요
--   위험: 정예 · 던전 · 공격대 · 파티 퀘, 내 레벨보다 3 이상 높은 퀘, 다른 대륙 퀘
--   물어본 퀘를 안 넣으면 "보류"로 남아요 (퀘판에서 넣을 수 있어요)
local function RiskOf(e)
    if e.tag then return TAG_NAME[e.tag] or "정예" end
    if e.group and e.group > 1 then return "파티" end
    local me = UnitLevel("player") or 1
    if (e.level or 0) >= me + 3 then return "레벨 " .. e.level end
    local z = ZoneIdByName(ZoneKey(e))
    local here = PlayerMap()
    if z and here then
        local c1, c2 = ContinentOf(z), ContinentOf(here)
        if c1 and c2 and c1 ~= c2 then return "다른 대륙" end
    end
end
-- 토끼 추천 순서가 있으면 새 퀘를 그 순서 안의 가장 덜 돌아가는 자리에 끼워요
--   (그냥 두면 추천 밖 퀘로 맨 뒤에 붙어서, 바로 옆 퀘가 반납들 뒤로 밀렸어요)
local function InsertIntoRec(id)
    local rec = CDB.rec
    if not (rec and rec.order) then return end
    for _, rid in ipairs(rec.order) do if rid == id then return end end
    local m = PlayerMap()
    local e = byId[id]
    local nx, ny
    if e then nx, ny = QuestPos(e, m) end      -- ("e and QuestPos()"는 값 하나만 돌려줘서 y가 빠졌어요)
    if not (nx and ny) then table.insert(rec.order, id) return end
    local px, py = PlayerXY(m)
    local pts = { { px or nx, py or ny } }          -- 0번 = 내 자리
    local idx = { 0 }
    for i, rid in ipairs(rec.order) do
        local re = byId[rid]
        local x, y
        if re then x, y = QuestPos(re, m) end
        if x and y then pts[#pts + 1] = { x, y }; idx[#idx + 1] = i end
    end
    local function d(a, b) return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2) end
    local new = { nx, ny }
    local bestAt, bestCost = #rec.order + 1, math.huge
    for k = 1, #pts do
        local a, b = pts[k], pts[k + 1]
        local cost = b and (d(a, new) + d(new, b) - d(a, b)) or d(a, new)
        if cost < bestCost then
            bestCost = cost
            bestAt = b and idx[k + 1] or (#rec.order + 1)
        end
    end
    table.insert(rec.order, bestAt, id)
end

local function AddToRoute(id)
    InsertIntoRec(id)
    Sel()[id] = true
    CDB.route = BuildOrder()
    CDB.total = (CDB.total or 0) + 1
    if CDB.held then CDB.held[id] = nil end
    newAt[id] = GetTime()
    C_Timer.After(61, function() if RefreshTracker then RefreshTracker() end end)
end
local function NewQuestToast(id)
    if not (id and CDB.route and #CDB.route > 0) then return end
    local e = byId[id]
    if not e or Sel()[id] then return end
    local risk = RiskOf(e)
    if not risk then
        AddToRoute(id)
        local pos = 0
        for i, rid in ipairs(CDB.route) do if rid == id then pos = i break end end
        Toast("+ 길에 넣었어요", e.title .. (pos > 0 and (" · " .. pos .. "번 자리") or ""), "빼기", function()
            Sel()[id] = nil
            CDB.route = BuildOrder()
            CDB.total = math.max(0, (CDB.total or 1) - 1)
            newAt[id] = nil
            RefreshTracker(); RefreshBoard()
        end, "+ 길에 넣었어요", e.title)
        if trk and trk.band and trk.band:IsShown() then trk.band.left = 5 end
        RefreshTracker(); RefreshBoard()
        return
    end
    -- 위험한 퀘: 물어봐요 (안 누르면 보류)
    CDB.held = CDB.held or {}
    CDB.held[id] = true
    AskSound()
    Toast(risk .. " · " .. e.title, "혼자 하기 어려울 수 있어요. 길에 넣을까요?", "넣기", function()
        AddToRoute(id)
        RefreshTracker(); RefreshBoard()
    end, risk .. " · " .. e.title, "넣을까요? 안 넣으면 보류로 남아요")
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
        CheckGoals()
        -- 로그에서 사라진 퀘(반납 · 포기)는 고른 목록에서도 빼요
        for id in pairs(Sel()) do if not byId[id] then Sel()[id] = nil end end
        -- 길 밖 퀘가 완료되면 반납을 길에 넣어요 (C안)
        CDB.doneAll = CDB.doneAll or {}
        local added = {}
        local following = CDB.route and #CDB.route > 0
        for _, e in ipairs(log) do
            if e.id and not e.failed then
                local was = CDB.doneAll[e.id]
                if following and DB.autoTurnin ~= false and e.done and was == false and not Sel()[e.id] then
                    added[#added + 1] = e
                end
                CDB.doneAll[e.id] = e.done and true or false
            end
        end
        for id in pairs(CDB.doneAll) do if not byId[id] then CDB.doneAll[id] = nil end end
        if #added > 0 then
            for _, e in ipairs(added) do AddToRoute(e.id) end
            local e1 = added[1]
            Toast("+ 반납 넣었어요", e1.title .. (#added > 1 and (" 외 " .. (#added - 1) .. "개") or ""), "빼기", function()
                for _, e in ipairs(added) do Sel()[e.id] = nil; newAt[e.id] = nil end
                CDB.route = BuildOrder()
                CDB.total = math.max(0, (CDB.total or #added) - #added)
                RefreshTracker(); RefreshBoard()
            end, "+ 반납 넣었어요", e1.title)
            if trk and trk.band and trk.band:IsShown() then trk.band.left = 5 end
        end
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
        CheckGoals()      -- 처음엔 지금 상태만 기억 (소리 안 남)
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
    elseif msg:find("^소리") then
        local a = msg:gsub("^소리%s*", "")
        if a == "끔" or a == "끄기" then
            DB.sndOff = true; Print("퀘스트 소리 끔")
        elseif a == "켬" or a == "켜기" then
            DB.sndOff = nil; DoneSound(); Print("퀘스트 소리 켬")
        else
            Print("퀘스트 소리: " .. (DB.sndOff and "끔" or "켬") .. "  ·  /퀘판 소리 켬 · 끔")
            if not DB.sndOff then DoneSound() end
        end
    elseif msg == "목표" then
        local e = Route()[1] or log[1]
        if e then Goal(e.id, false, "시험 목표 1/1") end
    elseif msg == "도장" then
        -- 시험: 맨 위 퀘에 완료 도장을 찍어 봐요
        local e = Route()[1] or log[1]
        if e then Goal(e.id, true) end
    elseif msg:find("^효과") then
        local a = msg:gsub("^효과%s*", "")
        if a == "끔" or a == "끄기" then DB.fxOff = true elseif a == "켬" or a == "켜기" then DB.fxOff = nil end
        Print("완료 도장 효과: " .. (DB.fxOff and "끔" or "켬") .. "  ·  /퀘판 효과 켬 · 끔  ·  /퀘판 도장 (시험)")
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
-- 큰 지도(Leel Map)가 따라가는 길을 그릴 때 씀: 내 지역 지도 번호와 길 점들 (0~1, 옆 지역은 범위 밖 값)
_G.LeelQuestRoute = function()
    if not (CDB and CDB.route and #CDB.route > 0 and DB.mapLines ~= false) then return end
    local m = PlayerMap()
    if not m then return end
    local out = {}
    for _, p in ipairs(RoutePoints(m)) do
        out[#out + 1] = { x = p[1] / 100, y = p[2] / 100, n = p[3], done = p[4], title = p[5] and p[5].title }
    end
    return m, out
end

