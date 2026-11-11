-- LeelUI / QuestMobs.lua
-- Questie 없이 "이 몹이 내 퀘스트 몹인지" 알아내기
--   1) 게임 툴팁에 붙는 퀘스트 줄 (퀘스트 이름 + " - 목표: 3/10")
--   2) 내가 잡아서 목표 숫자가 오른 몹을 기억 (잡기 목표는 바로, 줍기 목표는 시체를 뒤졌을 때)
--   3) 게임이 "퀘스트 관련 몹"이라고만 알려 줄 때 (숫자 없이)
-- ns.QuestMobInfo(unit) → { done, open, loot, have, need } 또는 nil  (이름표 퀘스트 원, 퀘템 알림이 씀)

local _, ns = ...

local function DB()
    ns.db.qmobs = ns.db.qmobs or {}   -- 몹 이름 → { [퀘스트 제목] = 목표 이름 }
    return ns.db.qmobs
end

local function Plain(s) return (s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end

----------------------------------------------------------------------
-- 퀘스트 목록 (제목 → 목표들)
----------------------------------------------------------------------
local quests = {}       -- title → { done, objs = { {name, have, need, done, kind} } }
local function ParseObj(text, kind, fin)
    text = Plain(text)
    local name, a, b = text:match("^(.-)%s*:%s*(%d+)%s*/%s*(%d+)%s*$")
    if not name then a, b, name = text:match("^(%d+)%s*/%s*(%d+)%s+(.+)$") end
    name = name or text
    a, b = tonumber(a), tonumber(b)
    local done = fin and true or (a and b and a >= b) or false
    return { name = name, have = a, need = b, done = done, kind = kind }
end

local function ReadLog()
    local out = {}
    if not GetQuestLogTitle then quests = out return end
    local n = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
    for i = 1, (type(n) == "number" and n or 0) do
        local title, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)
        if title and not isHeader then
            local q = { done = (isComplete == 1 or isComplete == true), objs = {} }
            local ok, k = pcall(GetNumQuestLeaderBoards, i)
            for j = 1, (ok and k or 0) do
                local ok2, text, kind, fin = pcall(GetQuestLogLeaderBoard, j, i)
                if ok2 and text then q.objs[#q.objs + 1] = ParseObj(text, kind, fin) end
            end
            out[title] = q
        end
    end
    quests = out
end

----------------------------------------------------------------------
-- 최근에 쓰러뜨린 몹 / 뒤진 시체
----------------------------------------------------------------------
local kills, loots = {}, {}     -- { name, guid, t }
local function Push(list, name, guid)
    if type(name) ~= "string" or name == "" then return end
    for _, k in ipairs(list) do if guid and k.guid == guid then return end end
    table.insert(list, 1, { name = name, guid = guid, t = GetTime() })
    while #list > 12 do table.remove(list) end
end

local watchUnits = { "target", "mouseover", "focus" }
local alive = {}                  -- guid → name (살아 있을 때 본 적 있는 적)
local function Watch()
    for _, u in ipairs(watchUnits) do
        local ok, can = pcall(UnitCanAttack, "player", u)
        if ok and can then
            local okG, guid = pcall(UnitGUID, u)
            local okN, name = pcall(UnitName, u)
            if okG and okN and type(guid) == "string" and type(name) == "string" and guid:find("^Creature") then
                local okD, dead = pcall(UnitIsDead, u)
                if okD and dead then
                    if alive[guid] then Push(kills, name, guid); alive[guid] = nil end
                else
                    alive[guid] = name
                end
            end
        end
    end
end

local function Recent(list, secs)
    local now = GetTime()
    local k = list[1]
    if k and now - k.t <= secs then return k.name end
end

----------------------------------------------------------------------
-- 목표 숫자가 오르면 → 방금 잡은/뒤진 몹을 이 목표 몹으로 기억
----------------------------------------------------------------------
local last = {}     -- "title\1obj" → have
local function Learn()
    Watch()
    local d = DB()
    for title, q in pairs(quests) do
        for _, o in ipairs(q.objs) do
            local key = title .. "\1" .. o.name
            local prev = last[key]
            if prev and o.have and o.have > prev then
                local who
                if o.kind == "monster" then
                    who = Recent(kills, 5) or Recent(loots, 5)
                else
                    who = Recent(loots, 6) or Recent(kills, 4)
                end
                if who then
                    d[who] = d[who] or {}
                    d[who][title] = o.name
                end
            end
            if o.have then last[key] = o.have end
        end
    end
end

----------------------------------------------------------------------
-- 이 몹 정보
----------------------------------------------------------------------
local function FromTooltip(unit, out)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return end
    local cur
    for i = 2, #data.lines do
        local t = data.lines[i] and data.lines[i].leftText
        if type(t) == "string" then
            t = Plain(t)
            if quests[t] then
                cur = t
            elseif cur and t:find("^%s*%-") then
                local o = ParseObj(t:gsub("^%s*%-%s*", ""), nil, nil)
                -- 퀘스트 목록의 같은 목표에서 종류(잡기/줍기)를 가져옴
                for _, qo in ipairs(quests[cur].objs) do
                    if qo.name == o.name then o.kind = qo.kind; o.done = qo.done; o.have = qo.have or o.have; o.need = qo.need or o.need end
                end
                out[#out + 1] = o
            end
        end
    end
end

function ns.QuestMobInfo(unit)
    local okN, name = pcall(UnitName, unit)
    if not okN or type(name) ~= "string" then return end
    local list = {}
    FromTooltip(unit, list)
    if #list == 0 then
        local mem = DB()[name]
        if mem then
            for title, objName in pairs(mem) do
                local q = quests[title]
                if q then
                    for _, o in ipairs(q.objs) do
                        if o.name == objName then list[#list + 1] = o end
                    end
                end
            end
        end
    end
    if #list == 0 then
        local f = C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest
        if f then
            local ok, r = pcall(f, unit)
            if ok and r == true then return { done = false, open = 1, loot = false } end
        end
        return
    end
    local open, first = 0, nil
    for _, o in ipairs(list) do
        if not o.done then open = open + 1; first = first or o end
    end
    local o = first or list[1]
    return {
        done = first == nil, open = open,
        loot = o.kind ~= nil and o.kind ~= "monster",
        have = o.have, need = o.need,
        quests = list,
    }
end

-- 이 몹이 걸린 퀘스트 제목들 (퀘템 알림용)
function ns.QuestMobTitles(unit)
    local okN, name = pcall(UnitName, unit)
    local out = {}
    if okN and type(name) == "string" and DB()[name] then
        for title in pairs(DB()[name]) do out[title] = true end
    end
    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
        if ok and type(data) == "table" and type(data.lines) == "table" then
            for i = 2, #data.lines do
                local t = data.lines[i] and data.lines[i].leftText
                if type(t) == "string" and quests[Plain(t)] then out[Plain(t)] = true end
            end
        end
    end
    return out
end

----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, e)
    if e == "PLAYER_LOGIN" then
        ReadLog()
        for title, q in pairs(quests) do
            for _, o in ipairs(q.objs) do if o.have then last[title .. "\1" .. o.name] = o.have end end
        end
        self:RegisterEvent("QUEST_LOG_UPDATE")
        self:RegisterEvent("LOOT_OPENED")
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        local acc = 0
        self:SetScript("OnUpdate", function(_, el)
            acc = acc + el
            if acc > 0.25 then acc = 0; Watch() end
        end)
        return
    end
    if e == "QUEST_LOG_UPDATE" then
        ReadLog(); Learn()
    elseif e == "LOOT_OPENED" then
        -- 시체를 뒤졌으면 그 몹 이름 (대상이 죽은 적이면 그 이름, 아니면 방금 쓰러뜨린 몹)
        local ok, dead = pcall(UnitIsDead, "target")
        local okC, can = pcall(UnitCanAttack, "player", "target")
        local okN, name = pcall(UnitName, "target")
        local okG, guid = pcall(UnitGUID, "target")
        if ok and dead and okN and type(name) == "string" and (okC and can or true) then
            Push(loots, name, okG and guid or nil)
        elseif kills[1] then
            Push(loots, kills[1].name, kills[1].guid)
        end
    else
        Watch()
    end
end)
