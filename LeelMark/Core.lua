-- Leel Mark / Core.lua
-- 파티 징 찍기 (A안: 가로 알약 바)
--   [토끼] [해골][X][네모][달][세모][다이아][동그라미][별] [자동] [지우기]
--   · 징 단추: 지금 대상에 그 징 (한 번 더 누르면 지움 = 게임 기본 동작)
--   · 자동: 보이는 적 이름표에 우선순위대로 빈 징 채우기
--   · 마우스 단축키: 몹에 마우스를 올리고 단축키 → 누를 때마다 해골 → X → 네모 …
--   · 지우기: 모든 징 지우기
-- 포에버(12.x)에서는 애드온이 징 찍기(SetRaidTarget)를 직접 못 함 → 블리자드 보안 단추(raidtarget·매크로)로 찍음
--   (자동은 전투 밖에서만 미리 매크로를 만들어 둘 수 있음)
-- 징 번호: 1 별, 2 동그라미, 3 다이아, 4 세모, 5 달, 6 네모, 7 X, 8 해골

local ADDON = ...
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"
local FONT = STANDARD_TEXT_FONT or "Fonts\\2002.TTF"
-- 르엘 UI 글씨체를 따라감 (허브에서 바꾸면 바로 바뀜)
local function LeelFont(fs, size, flags)
    local L = _G.LeelUI
    local ok = fs:SetFont((L and L.FONT) or FONT, size, flags or "")
    if L and L.TrackText then L.TrackText(fs, size, flags or "") end
    return ok
end

local C = {
    acc = { 0.949, 0.702, 0.761 }, ink = { 0.227, 0.11, 0.141 },
    tx = { 0.965, 0.925, 0.91 }, tx2 = { 0.81, 0.635, 0.616 },
    plate = { 0.125, 0.094, 0.086, 0.96 }, btn = { 0.18, 0.137, 0.129, 1 },
}
local MARK_NAME = { "별", "동그라미", "다이아", "세모", "달", "네모", "X", "해골" }
local BAR_ORDER = { 8, 7, 6, 5, 4, 3, 2, 1 }

local defaults = { pos = nil, show = "group", announce = false, scale = 1, order = true }
local db

-- 영어 (르엘 UI 언어 설정을 따라가요)
local function T(s) local L = _G.LeelUI; if L and L.L then return L.L(s) end return s end
local function TipAdd(s, ...) return GameTooltip:AddLine(T(s), ...) end
local function TipSet(s, ...) return GameTooltip:SetText(T(s), ...) end
local function EN() local L = _G.LeelUI; return L and L.EnOn and L.EnOn() or false end
local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cfff2b3c2[Leel Mark]|r " .. T(msg)) end

----------------------------------------------------------------------
-- 징 읽기·찍기 (숨겨진 값이어도 에러 없이)
----------------------------------------------------------------------
local function GetMark(unit)
    local ok, idx = pcall(function()
        local i = GetRaidTargetIndex(unit)
        if i and i > 0 then return i end
    end)
    return ok and idx or nil
end

local RememberMark   -- 아래에서 채워요 (내가 찍은 징 기억)
local MarkMemoryOf   -- 이름표 몹 → 내가 찍은 징 (기억)
local ns_warned = false
local function SetMark(unit, idx)
    local ok, err = pcall(SetRaidTarget, unit, idx)
    if not ok and not ns_warned then
        ns_warned = true
        Print("징을 찍을 수 없어요: " .. tostring(err))
    end
    return ok
end

local function Try(fn, ...)
    local ok, r = pcall(fn, ...)
    if not ok then return false end
    local ok2, b = pcall(function() return r and true or false end)
    return ok2 and b or false
end

local function CanMark()
    if IsInRaid() then
        return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
    end
    return true
end

----------------------------------------------------------------------
-- 역할 징: 파티에 그 직업이 있을 때만 (사냥꾼 네모=얼음 덫, 마법사 달=변이, 도적 별=혼절)
----------------------------------------------------------------------
local function GroupClasses()
    local has, who = {}, {}
    local function add(u)
        local ok, _, file = pcall(UnitClass, u)
        if ok and type(file) == "string" then
            has[file] = true
            who[file] = who[file] or UnitName(u)
        end
    end
    add("player")
    for i = 1, GetNumSubgroupMembers() do add("party" .. i) end
    return has, who
end

local PlanOrder   -- 아래에서 채워요: 바에 보이는 약속(칠 순서 → CC)대로만 찍기
local function AutoOrder()
    if PlanOrder then
        local o, r = PlanOrder()
        if o and #o > 0 then return o, r end
    end
    local has, who = GroupClasses()
    local order, roles = { 8, 7 }, {}
    if has.HUNTER then order[#order + 1] = 6; roles[6] = (who.HUNTER or "사냥꾼") .. " 덫" end
    if has.MAGE then order[#order + 1] = 5; roles[5] = (who.MAGE or "마법사") .. " 변이" end
    if has.ROGUE then order[#order + 1] = 1; roles[1] = (who.ROGUE or "도적") .. " 혼절" end
    for _, i in ipairs({ 4, 3, 2, 6, 5, 1 }) do
        local dup = false
        for _, o in ipairs(order) do if o == i then dup = true end end
        if not dup then order[#order + 1] = i end
    end
    return order, roles
end

----------------------------------------------------------------------
-- 자동: 보이는 적 이름표 → 점수순 → 빈 징 채우기
----------------------------------------------------------------------
-- 점수: 시전 중 +100 · 정예 +50 · 마나 몹(주문 · 치유) +20 · 체력 많을수록 +최대 19 · 대상 +5 (같은 점수면 대상 먼저)
--   던전에선 게임이 몹 정보를 숨길 때가 있어요 → 못 읽은 건 0점 (Score 두 번째 값 = 읽은 것 / 숨김 표시 · /lmark 우선)
local function Score(u, isTarget)
    local s, why = 0, {}
    local function part(name, fn, add)
        local ok, r = pcall(fn)
        if not ok then why[#why + 1] = name .. "?" return end
        if r then s = s + (type(r) == "number" and r or add); why[#why + 1] = name end
    end
    part("시전", function() local a = UnitCastingInfo(u) or UnitChannelInfo(u); return a ~= nil end, 100)
    part("정예", function() local c = UnitClassification(u); return c == "elite" or c == "rareelite" or c == "worldboss" end, 50)
    part("마나", function() return UnitPowerType(u) == 0 end, 20)
    part("체력", function() return math.min(UnitHealthMax(u) / 1000, 19) end, 0)
    if isTarget then s = s + 5; why[#why + 1] = "대상" end
    return s, table.concat(why, " ")
end

local function issecretvalue_safe(v)
    if issecretvalue then local ok, r = pcall(issecretvalue, v); return ok and r end
    return false
end

-- 거리 구간 (르엘 UI 거리 재기 사용, 없으면 상호작용 거리만)
local function Range(u)
    local L = _G.LeelUI
    if L and L.UnitRange then
        local ok, r, maxR = pcall(L.UnitRange, u)
        if ok then
            if type(r) == "number" then return r end
            if r == "far" then return (maxR or 40) + 10 end
        end
    end
    if Try(CheckInteractDistance, u, 3) then return 10 end
    if Try(CheckInteractDistance, u, 4) then return 28 end
    return 45
end

-- 화면 위 이름표 가운데 (실제 픽셀)
-- 블리자드 이름표는 위치를 못 재게 막혀 있어서(재면 오류) 르엘 UI 이름표 판으로 재고, 그것도 막히면 포기
local function PlatePos(plate)
    for _, fr in ipairs({ plate.leel, plate.UnitFrame and plate.UnitFrame.leel }) do
        if fr and fr.GetCenter then
            local ok, x, y, s = pcall(function()
                local cx, cy = fr:GetCenter()
                return cx, cy, fr:GetEffectiveScale()
            end)
            if ok and type(x) == "number" and type(y) == "number" and not issecretvalue_safe(x) then
                return x * s, y * s
            end
        end
    end
end

-- 징 찍을 무리: 기준 몹(대상, 없으면 가장 가까운 몹) 둘레의 몹만
--   나와 30m 안 + 화면에서 가까이 붙어 있고(화면 높이의 22% 안) 나와의 거리도 비슷한 몹
--   대상을 잡고 누르면: 거리 제한 없이 그 대상 둘레 무리 (멀리 있는 무리도 미리 찍기)
--   대상이 없으면: 나와 40m 안에서 가장 가까운 무리
local NEAR = 40
-- 대상의 이름표 자리 (던전에선 몹 비교가 숨겨져서 이름표로 바로 찾아요)
local function TargetTok()
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    if ok and plate then return plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit) end
end
local function IsTarget(u, tt) return (tt and u == tt) or Try(UnitIsUnit, u, "target") end
local function KeepPack(list)
    local tt = TargetTok()
    local hasTarget = false
    for _, c in ipairs(list) do if IsTarget(c.unit, tt) then hasTarget = true break end end
    -- 1) 대상이 없을 때만 멀리 있는 몹을 먼저 빼기
    local near, cut = {}, 0
    for _, c in ipairs(list) do
        c.range = Range(c.unit)
        if hasTarget or c.range <= NEAR then near[#near + 1] = c else cut = cut + 1 end
    end
    list = near
    if #list <= 1 then return list, cut end
    local anchor
    for _, c in ipairs(list) do
        if IsTarget(c.unit, tt) then anchor = c break end
    end
    if not anchor then
        local us = UIParent:GetEffectiveScale()
        local cx, cy = UIParent:GetWidth() * us / 2, UIParent:GetHeight() * us / 2
        for _, c in ipairs(list) do
            local d = c.x and ((c.x - cx) ^ 2 + (c.y - cy) ^ 2) or 1e9
            c.key = c.range * 100000 + d
            if not anchor or c.key < anchor.key then anchor = c end
        end
    end
    anchor.range = anchor.range or Range(anchor.unit)
    local sh = UIParent:GetHeight() * UIParent:GetEffectiveScale()   -- 이름표 좌표와 같은 단위
    local lim = sh * 0.22
    local keep = {}
    for _, c in ipairs(list) do
        local ok = c == anchor
        if not ok then
            local dr = math.abs((c.range or 45) - (anchor.range or 45))
            if c.x and anchor.x then
                local d = math.sqrt((c.x - anchor.x) ^ 2 + (c.y - anchor.y) ^ 2)
                ok = d <= lim and dr <= 20   -- 던전에선 거리를 대충(10 · 28 · 45m)만 알아서 넉넉히
            else
                ok = dr <= 20   -- 화면 위치를 못 재면 나와의 거리가 비슷한 몹
            end
        end
        if ok then keep[#keep + 1] = c else cut = cut + 1 end
    end
    return keep, cut
end

local function Candidates()
    local list, used = {}, {}
    local tt = TargetTok and TargetTok()
    for i, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local u = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if u and Try(UnitCanAttack, "player", u) and not Try(UnitIsDead, u) then
            -- 이미 징이 있는 몹은 건너뛰기 (던전에선 징이 숨겨져서 내가 찍은 기억으로도)
            local m = GetMark(u) or (MarkMemoryOf and MarkMemoryOf(u))
            if m then
                used[m] = true
            elseif not Try(UnitIsTapDenied, u) then
                local x, y = PlatePos(plate)
                local isT = (tt and u == tt) or Try(UnitIsUnit, u, "target")
                local sc, why = Score(u, isT)
                list[#list + 1] = { unit = u, score = sc, why = why, x = x, y = y, i = i, isT = isT }
            end
        end
    end
    local cut
    if db.packOnly ~= false then list, cut = KeepPack(list) end
    local tm = GetMark("target")
    if tm then used[tm] = true end
    -- 같은 점수면: 대상 → 대상과 화면에서 가까운 몹 → 이름표 순서 (늘 같은 결과가 나오게)
    local ax, ay
    for _, c in ipairs(list) do if c.isT then ax, ay = c.x, c.y end end
    for _, c in ipairs(list) do c.d = (ax and c.x) and ((c.x - ax) ^ 2 + (c.y - ay) ^ 2) or 1e12 end
    table.sort(list, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        if a.d ~= b.d then return a.d < b.d end
        return a.i < b.i
    end)
    return list, used, cut or 0
end

local function Announce(text)
    if not db.announce or not IsInGroup() then return end
    local ch = IsInRaid() and "RAID" or "PARTY"
    pcall(SendChatMessage, "[Leel Mark] " .. text, ch)
end

-- 내가 찍은 징 기억 (몹 GUID → 징): 던전 · 전투 중엔 게임이 징 번호를 숨겨서 이름표가 못 읽을 때 대신 써요
--   던전에선 GUID 도 숨겨질 수 있어서 이름표 자리(nameplateN)로도 기억해요 (이름표가 사라지면 = 죽거나 멀어지면 지움)
local assigned, byTok = {}, {}
local function GUIDOf(u)
    local ok, g = pcall(UnitGUID, u)
    if ok and type(g) == "string" and not issecretvalue_safe(g) then return g end
end
local function PlateTok(u)
    if type(u) == "string" and u:find("^nameplate%d+$") then return u end
    -- 대상 · 마우스 몹의 이름표를 바로 (던전 전투 중엔 몹 비교가 숨겨져도 이건 돼요)
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, u)
        if ok and plate then
            local t = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
            if type(t) == "string" and not issecretvalue_safe(t) then return t end
        end
    end
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local t = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if t then
            local ok, same = pcall(UnitIsUnit, t, u)
            if ok and not issecretvalue_safe(same) and same then return t end
        end
    end
end
MarkMemoryOf = function(u)
    local g = GUIDOf(u)
    if g and assigned[g] then return assigned[g] end
    return byTok[u]
end
RememberMark = function(u, m)
    for k, v in pairs(assigned) do if v == m then assigned[k] = nil end end   -- 같은 징은 한 몹에만
    for k, v in pairs(byTok) do if v == m then byTok[k] = nil end end
    local g = GUIDOf(u)
    if g then assigned[g] = m end
    local t = PlateTok(u)
    if t then byTok[t] = m end
end

-- 르엘 쓰는 파티원끼리 징 나누기 (던전에선 몹을 서로 가리킬 수 없어서 "내 대상"으로만)
--   보내는 쪽: 내 대상에 찍은 징 → "T|징"  · 지우기 → "C"
--   받는 쪽: 보낸 사람의 대상 이름표(party1target 등)를 게임에 물어서 그 이름표에 징을 기억
local SHARE = "LeelMarkT"
local function ShareChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not IsInGroup(LE_PARTY_CATEGORY_HOME) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end
local function ShareSend(msg)
    local ch = ShareChannel()
    if ch and C_ChatInfo and C_ChatInfo.SendAddonMessage then pcall(C_ChatInfo.SendAddonMessage, SHARE, msg, ch) end
end
-- u 에 m 을 찍었어요: u 가 내 대상이면 파티에 알려요
local function ShareIfTarget(u, m)
    local tu, tt = PlateTok(u), PlateTok("target")
    if u == "target" or (tu and tt and tu == tt) then ShareSend("T|" .. m) end
end
local function ShareRecv(sender, msg)
    local who = Short and Short(sender) or (sender:match("^([^%-]+)") or sender)
    if msg == "C" then wipe(assigned); wipe(byTok)
    else
        local m = tonumber(msg:match("^T|(%d)$") or "")
        if not m or m < 1 or m > 8 then return end
        local unit
        local n = IsInRaid() and 40 or 4
        for i = 1, n do
            local u = (IsInRaid() and "raid" or "party") .. i
            if UnitExists(u) then
                local ok, un = pcall(UnitName, u)
                if ok and type(un) == "string" and not issecretvalue_safe(un) and un == who then unit = u break end
            end
        end
        if not unit then return end
        local tok = PlateTok(unit .. "target")
        if not tok then return end
        for k, v in pairs(byTok) do if v == m then byTok[k] = nil end end
        for k, v in pairs(assigned) do if v == m then assigned[k] = nil end end
        byTok[tok] = m
        local g = GUIDOf(tok); if g then assigned[g] = m end
    end
    if _G.LeelUI and _G.LeelUI.MarkRefresh then pcall(_G.LeelUI.MarkRefresh) end
end

-- 자동: 전투 밖에서 누르는 순간(PreClick) 우선순위를 계산해 "/tm [@nameplateN] ~징" 매크로를 만들어 둠
local function BuildAutoMacro()
    local list, used, cut = Candidates()
    if #list == 0 then
        if cut > 0 then return nil, "40m 안에 징을 찍을 적이 없어요. 찍을 몹을 대상으로 잡고 누르면 멀어도 돼요." end
        if next(used) then return nil, "보이는 적에 이미 징이 다 있어요." end
        return nil, "징을 찍을 적이 안 보여요. (적 이름표가 켜져 있어야 해요)"
    end
    local order, roles = AutoOrder()
    local lines, oi, got = {}, 1, {}
    for _, c in ipairs(list) do
        while order[oi] and used[order[oi]] do oi = oi + 1 end
        local m = order[oi]
        if not m then break end
        lines[#lines + 1] = ("/tm [@%s] ~%d"):format(c.unit, m)
        got[m] = true
        RememberMark(c.unit, m)
        ShareIfTarget(c.unit, m)
        oi = oi + 1
    end
    local parts = {}
    local en = EN()
    if got[8] then parts[#parts + 1] = en and "Skull first" or "해골 먼저" end
    if got[7] then parts[#parts + 1] = en and "X next" or "X 다음" end
    for m, r in pairs(roles) do if got[m] then parts[#parts + 1] = en and (T(MARK_NAME[m]) .. ": " .. T(r)) or (MARK_NAME[m] .. "는 " .. r) end end
    if cut > 0 then parts[#parts + 1] = en and (cut .. " far away left out") or ("멀리 있는 " .. cut .. "마리는 뺐어요") end
    return table.concat(lines, "\n"), table.concat(parts, " · ")
end

----------------------------------------------------------------------
-- 징 약속표: 징마다 뜻 (잡는 순서 · CC 맡은 사람)
--   기본 = 파티 직업을 보고 자동 (해골 1번 · X 2번 · 사냥꾼 네모 덫 · 마법사 달 변이 · 도적 별 혼절 · 나머지 3번…)
--   징 아래 글씨를 누르면 바꾸기: 자동 → 순서 → 변이 → 덫 → 혼절 → 안 씀
--   [약속 알리기] = 파티 채팅 한 줄 (징 그림) + 르엘 UI 쓰는 파티원에게 약속표 보내기 (이름표 순서가 같아져요)
----------------------------------------------------------------------
local CC_CLASS = { ["변이"] = "MAGE", ["덫"] = "HUNTER", ["혼절"] = "ROGUE" }
local CC_MARK = { [6] = "덫", [5] = "변이", [1] = "혼절" }
local CYCLE = { "auto", "kill", "변이", "덫", "혼절", "off" }
local PREFIX = "LEELMARK"
local remote   -- 다른 파티원이 보낸 약속표 { plan = {}, from = 이름 }

local function ClassColorHex(file)
    local c = file and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
    return c and { c.r, c.g, c.b } or { 0.85, 0.78, 0.76 }
end

local function MyPlan()
    local has, who = GroupClasses()
    local roles = db.roles or {}
    local plan, kill = {}, {}
    for _, idx in ipairs({ 8, 7, 4, 3, 2, 6, 5, 1 }) do
        local r = roles[idx] or "auto"
        if r == "auto" then
            local cc = CC_MARK[idx]
            if cc and has[CC_CLASS[cc]] then r = cc else r = "kill" end
        end
        if r == "kill" then kill[#kill + 1] = idx
        elseif r ~= "off" then
            local cls = CC_CLASS[r]
            plan[idx] = { kind = "cc", role = r, who = (cls and who[cls]) or "", cls = cls }
        end
    end
    -- D안: 칠 순서는 바에서 바꾼 순서(db.killOrder)를 따라요 (없는 징은 뒤에 기본 순서로)
    local ko = db.killOrder or {}
    local pos = {}
    for i, idx in ipairs(ko) do pos[idx] = i end
    local base = {}
    for i, idx in ipairs(kill) do base[idx] = i end
    table.sort(kill, function(a, b)
        local pa, pb = pos[a] or (100 + base[a]), pos[b] or (100 + base[b])
        return pa < pb
    end)
    for n, idx in ipairs(kill) do plan[idx] = { kind = "kill", n = n } end
    return plan
end

local Plan
PlanOrder = function()
    local plan = Plan()
    local kill, order, roles = {}, {}, {}
    for idx = 1, 8 do local p = plan[idx]; if p and p.kind == "kill" then kill[#kill + 1] = { idx, p.n } end end
    table.sort(kill, function(a, b) return a[2] < b[2] end)
    for _, e in ipairs(kill) do order[#order + 1] = e[1] end
    -- CC 징은 칠 순서 다음에 (남는 몹에게) · 안 씀 징은 절대 안 찍어요
    for _, idx in ipairs({ 5, 6, 1, 2, 3, 4, 7, 8 }) do
        local p = plan[idx]
        if p and p.kind == "cc" then order[#order + 1] = idx; roles[idx] = ((p.who and p.who ~= "") and (p.who .. " ") or "") .. p.role end
    end
    return order, roles
end
function Plan()
    if remote and remote.plan and IsInGroup() then return remote.plan, remote.from end
    return MyPlan()
end

local function PackPlan(plan)
    local t = {}
    for idx = 1, 8 do
        local p = plan[idx]
        if p then t[#t + 1] = idx .. ":" .. (p.kind == "kill" and ("k" .. p.n) or ("c" .. p.role .. ":" .. (p.who or "") .. ":" .. (p.cls or ""))) end
    end
    return "P1;" .. table.concat(t, ";")
end
local function UnpackPlan(msg)
    if not msg or msg:sub(1, 3) ~= "P1;" then return nil end
    local plan = {}
    for part in msg:sub(4):gmatch("[^;]+") do
        local idx, rest = part:match("^(%d):(.+)$")
        idx = tonumber(idx)
        if idx and rest then
            local n = rest:match("^k(%d+)$")
            if n then plan[idx] = { kind = "kill", n = tonumber(n) }
            else
                local role, who, cls = rest:match("^c([^:]*):([^:]*):?(.*)$")
                if role then plan[idx] = { kind = "cc", role = role, who = who, cls = (cls ~= "" and cls) or nil } end
            end
        end
    end
    return plan
end

-- 지금 보이는 적에게 찍힌 징
local function UsedMarks()
    local used = {}
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local u = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        local m = u and GetMark(u)
        if m then used[m] = true end
    end
    local tm = GetMark("target"); if tm then used[tm] = true end
    return used
end

local RT = { "{rt1}", "{rt2}", "{rt3}", "{rt4}", "{rt5}", "{rt6}", "{rt7}", "{rt8}" }
local function PlanText(plan)
    local used = UsedMarks()
    local any = next(used) ~= nil
    local kills = {}
    for idx, p in pairs(plan) do
        if p.kind == "kill" and ((any and used[idx]) or (not any and p.n <= 2)) then kills[#kills + 1] = { idx, p.n } end
    end
    table.sort(kills, function(a, b) return a[2] < b[2] end)
    local parts, chain = {}, {}
    for i, k in ipairs(kills) do
        if EN() then chain[#chain + 1] = RT[k[1]] .. (i == 1 and " first" or (i == 2 and " next" or (" #" .. i)))
        else chain[#chain + 1] = RT[k[1]] .. (i == 1 and " 먼저" or (i == 2 and " 다음" or (" " .. i .. "번"))) end
    end
    if #chain > 0 then parts[#parts + 1] = table.concat(chain, " → ") end
    for _, idx in ipairs({ 5, 6, 1, 2, 3, 4, 7, 8 }) do
        local p = plan[idx]
        if p and p.kind == "cc" and (not any or used[idx]) then
            parts[#parts + 1] = RT[idx] .. " " .. ((p.who ~= "" and (p.who .. " ")) or "") .. (EN() and T(p.role) or p.role)
        end
    end
    return table.concat(parts, " · ")
end

local function SendPlan()
    if not IsInGroup() then Print("파티에 있을 때 알릴 수 있어요.") return end
    local plan = MyPlan()
    remote = nil
    local text = PlanText(plan)
    local ch = IsInRaid() and "RAID" or "PARTY"
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not IsInGroup(LE_PARTY_CATEGORY_HOME) then ch = "INSTANCE_CHAT" end
    if text ~= "" then pcall(SendChatMessage, "[Leel Mark] " .. text, ch) end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then pcall(C_ChatInfo.SendAddonMessage, PREFIX, PackPlan(plan), ch) end
end

_G.LeelMarkAPI = {
    -- 징 번호 → { kind = "kill", n = 순서 } 또는 { kind = "cc", role = "변이", who = 이름 }
    Plan = function() if not db then return {} end return (Plan()) end,
    OrderOn = function() return db and db.order ~= false end,
    -- 몹 GUID → 내가 찍은 징 (게임이 징 번호를 숨길 때 이름표가 대신 써요)
    MarkOf = function(guid) return guid and assigned[guid] end,
    MarkOfPlate = function(tok) return tok and byTok[tok] end,
}

----------------------------------------------------------------------
-- 바 (르엘 UI: 어두운 알약 + 분홍 테)
----------------------------------------------------------------------
local bar
local ResetSweep
local labels = {}
local PaintLabels

local function Slice(t, m) pcall(t.SetTextureSliceMargins, t, m, m, m, m) end

local function PillTex(parent, file, m, c, a, layer, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetTexture(MEDIA .. file)
    Slice(t, m)
    t:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1)
    return t
end

local function Tip(b, title, line)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        TipAdd(title, 1, 1, 1)
        if line then TipAdd(line, C.tx2[1], C.tx2[2], C.tx2[3], true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- B안: 평소엔 작은 바 (징 + 순서 배지) · 징에 마우스를 올리면 아래로 약속 서랍
--   징 왼쪽 클릭 = 지금 대상에 그 징 · 오른쪽 클릭 = 대상 징 지우기 (보안 단추)
--   징 순서 = 약속표 순서 (1번 · 2번 … → CC → 안 씀) · 전투 중엔 순서를 못 바꿔서 끝나면 다시 세워요
--   서랍: [징] 자동 · 순서 · 변이 · 덫 · 혼절 · 안 씀 (전투 중엔 안 열려요)
local BTN, GAP = 30, 6
local rows = {}
local drawer, drawerIdx
local OpenDrawer
local function MarkBtn(parent, idx)
    local b = CreateFrame("Button", "LeelMarkBtn" .. idx, parent, "SecureActionButtonTemplate")
    b:SetSize(BTN, BTN)
    b:SetAttribute("type", "raidtarget")
    b:SetAttribute("unit", "target")
    b:SetAttribute("marker", idx)
    b:SetAttribute("action1", "toggle")
    b:SetAttribute("action2", "clear")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("useOnKeyDown", false)
    local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(MEDIA .. "circle"); bg:SetAllPoints()
    bg:SetVertexColor(C.btn[1], C.btn[2], C.btn[3], 1)
    b.ring = b:CreateTexture(nil, "BORDER"); b.ring:SetTexture(MEDIA .. "ring"); b.ring:SetAllPoints()
    b.ring:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.35)
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    SetRaidTargetIconTexture(ic, idx)
    ic:SetSize(19, 19); ic:SetPoint("CENTER")
    -- 순서 배지 (이름표와 같은 분홍 동그라미) · CC 징 = 맡은 사람 직업 색 점
    b.badge = CreateFrame("Frame", nil, b); b.badge:SetSize(15, 15); b.badge:SetPoint("CENTER", b, "TOPRIGHT", -3, -3)
    b.badge:SetFrameLevel(b:GetFrameLevel() + 3)
    local bo = b.badge:CreateTexture(nil, "ARTWORK"); bo:SetTexture(MEDIA .. "circle"); bo:SetPoint("CENTER"); bo:SetSize(18, 18)
    bo:SetVertexColor(C.plate[1], C.plate[2], C.plate[3], 1)
    b.badgeIn = b.badge:CreateTexture(nil, "ARTWORK", nil, 1); b.badgeIn:SetTexture(MEDIA .. "circle"); b.badgeIn:SetAllPoints()
    b.badgeFs = b.badge:CreateFontString(nil, "OVERLAY"); if _G.LeelUI and _G.LeelUI.LWrap then _G.LeelUI.LWrap(b.badgeFs) end; LeelFont(b.badgeFs, 10, ""); b.badgeFs:SetPoint("CENTER", 0, 0)
    b.badgeFs:SetTextColor(C.ink[1], C.ink[2], C.ink[3])
    b:SetScript("OnEnter", function(self)
        self.ring:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        TipAdd(MARK_NAME[idx], 1, 1, 1)
        local p = self.plan
        if p and p.kind == "kill" then TipAdd(p.n .. "번째로 잡아요", 1, 0.84, 0.88)
        elseif p then TipAdd(((p.who ~= "" and (p.who .. " ")) or "") .. p.role, 1, 0.84, 0.88)
        else TipAdd("안 씀", 0.6, 0.55, 0.53) end
        TipAdd("왼쪽 클릭: 대상에 찍기 · 오른쪽 클릭: 대상 징 지우기", C.tx2[1], C.tx2[2], C.tx2[3])
        GameTooltip:Show()
        if OpenDrawer then OpenDrawer(idx) end
    end)
    b:SetScript("OnLeave", function(self)
        self.ring:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], self.hot and 1 or 0.35)
        GameTooltip:Hide()
    end)
    rows[idx] = b
    return b
end

-- 약속 서랍
local CHIPS = { { "auto", "자동" }, { "kill", "순서" }, { "변이", "변이" }, { "덫", "덫" }, { "혼절", "혼절" }, { "off", "안 씀" } }
local function BuildDrawer()
    drawer = CreateFrame("Frame", nil, bar)
    drawer:SetHeight(30); drawer:SetFrameLevel(bar:GetFrameLevel() + 10)
    local bg = PillTex(drawer, "pill22", 11, C.plate, 0.98); bg:SetAllPoints()
    local rim = PillTex(drawer, "pill22rim", 11, C.acc, 0.5, "BORDER"); rim:SetAllPoints()
    drawer.ic = drawer:CreateTexture(nil, "ARTWORK"); drawer.ic:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    drawer.ic:SetSize(18, 18); drawer.ic:SetPoint("LEFT", 8, 0)
    drawer.chips = {}
    local x = 8 + 18 + 6
    for k, c in ipairs(CHIPS) do
        local ch = CreateFrame("Button", nil, drawer); ch:SetHeight(22)
        ch.bg = PillTex(ch, "pill22", 11, C.btn, 1); ch.bg:SetAllPoints()
        ch.fs = ch:CreateFontString(nil, "OVERLAY"); if _G.LeelUI and _G.LeelUI.LWrap then _G.LeelUI.LWrap(ch.fs) end; LeelFont(ch.fs, 11.5, ""); ch.fs:SetPoint("CENTER")
        ch.key = c[1]
        ch:SetScript("OnClick", function(self)
            if not drawerIdx then return end
            db.roles = db.roles or {}
            db.roles[drawerIdx] = (self.key ~= "auto") and self.key or nil
            remote = nil
            PaintLabels()
        end)
        ch:SetScript("OnEnter", function(self) if not self.on then self.fs:SetTextColor(1, 1, 1) end end)
        ch:SetScript("OnLeave", function(self) if not self.on then self.fs:SetTextColor(C.tx[1], C.tx[2], C.tx[3]) end end)
        drawer.chips[k] = ch
    end
    drawer:Hide()
    -- 바 · 서랍 밖으로 마우스가 나가면 닫기
    drawer:SetScript("OnUpdate", function(self, e)
        self.t = (self.t or 0) + e
        if self.t < 0.25 then return end
        self.t = 0
        if InCombatLockdown() or not (bar:IsMouseOver(4, -4, -4, 4) or self:IsMouseOver(4, -4, -4, 4)) then self:Hide() end
    end)
end
local function PaintDrawer()
    if not (drawer and drawer:IsShown() and drawerIdx) then return end
    SetRaidTargetIconTexture(drawer.ic, drawerIdx)
    local has, who = GroupClasses()
    local cur = (db.roles and db.roles[drawerIdx]) or "auto"
    local x = 8 + 18 + 6
    for _, ch in ipairs(drawer.chips) do
        local t = ch.key == "auto" and "자동" or (ch.key == "kill" and "순서" or (ch.key == "off" and "안 씀" or ch.key))
        local cls = CC_CLASS[ch.key]
        if cls and who[cls] then t = t .. " · " .. who[cls] end
        ch.fs:SetText(t)
        ch:SetWidth(ch.fs:GetStringWidth() + 18)
        ch:ClearAllPoints(); ch:SetPoint("LEFT", drawer, "LEFT", x, 0); x = x + ch:GetWidth() + 4
        ch.on = (cur == ch.key)
        ch.bg:SetVertexColor((ch.on and C.acc or C.btn)[1], (ch.on and C.acc or C.btn)[2], (ch.on and C.acc or C.btn)[3], 1)
        local fc = ch.on and C.ink or ((cls and not has[cls]) and { 0.6, 0.55, 0.53 } or C.tx)
        ch.fs:SetTextColor(fc[1], fc[2], fc[3])
    end
    drawer:SetWidth(x + 4)
end
OpenDrawer = function(idx)
    if InCombatLockdown() or not bar then return end
    if not drawer then BuildDrawer() end
    drawerIdx = idx
    local b = rows[idx]
    drawer:ClearAllPoints(); drawer:SetPoint("TOP", bar, "BOTTOM", 0, -4)
    drawer:Show()
    PaintDrawer()
end

-- 동그란 아이콘 단추 (자동 = 분홍 · 나머지 = 어두운)
local function RoundIcon(b, icon, filled)
    b:SetSize(32, 32)
    local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(MEDIA .. "circle"); bg:SetAllPoints()
    local c = filled and C.acc or C.btn; bg:SetVertexColor(c[1], c[2], c[3], 1)
    local ring = b:CreateTexture(nil, "BORDER"); ring:SetTexture(MEDIA .. "ring"); ring:SetAllPoints()
    ring:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], filled and 0 or 0.45)
    local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetTexture(MEDIA .. icon); ic:SetSize(15, 15); ic:SetPoint("CENTER")
    local fc = filled and C.ink or C.tx; ic:SetVertexColor(fc[1], fc[2], fc[3], 1)
    b:HookScript("OnEnter", function() ring:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1) end)
    b:HookScript("OnLeave", function() ring:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], filled and 0 or 0.45) end)
end

-- 징 찍기 단추: 분홍 알약 + 글씨 + 단축키
local function KeyPill(b)
    b:SetHeight(28)
    local bg = PillTex(b, "pill22", 11, C.acc, 1); bg:SetAllPoints()
    b.fs = b:CreateFontString(nil, "OVERLAY"); LeelFont(b.fs, 12.5, ""); b.fs:SetPoint("LEFT", 12, 0); b.fs:SetTextColor(C.ink[1], C.ink[2], C.ink[3])
    b.fs:SetText(T("징 찍기"))
    b.kb = CreateFrame("Frame", nil, b); b.kb:SetHeight(18)
    local kbg = PillTex(b.kb, "pill22", 9, C.ink, 1); kbg:SetAllPoints()
    b.kfs = b.kb:CreateFontString(nil, "OVERLAY"); LeelFont(b.kfs, 11, ""); b.kfs:SetPoint("CENTER"); b.kfs:SetTextColor(C.acc[1], C.acc[2], C.acc[3])
    b.kb:SetPoint("LEFT", b.fs, "RIGHT", 7, 0)
    function b:PaintKey()
        local k = GetBindingKey and GetBindingKey("CLICK LeelMarkAuto:LeftButton")
        if k and GetBindingText then k = GetBindingText(k, "KEY_", true) or k end
        local w = 12 + self.fs:GetStringWidth() + 12
        if k and k ~= "" then
            self.kfs:SetText(k); self.kb:SetWidth(self.kfs:GetStringWidth() + 12); self.kb:Show()
            w = w + 7 + self.kb:GetWidth() - 4
        else self.kb:Hide() end
        self:SetWidth(w)
    end
    b:PaintKey()
end

-- 줄 순서 · 글씨 · 흐리게
local orderPending = false
local function ROrder(plan)
    local list = {}
    for idx = 1, 8 do
        local p = plan[idx]
        local key
        if not p then key = 300 + idx
        elseif p.kind == "kill" then key = p.n
        else local cr = ({ [5] = 1, [6] = 2, [1] = 3 })[idx]; key = cr and (100 + cr) or (150 + idx) end
        list[#list + 1] = { idx, key }
    end
    table.sort(list, function(a, b) return a[2] < b[2] end)
    return list
end
-- D안 바: [토끼] 칠 순서 징 1 → 2 → 3 | CC 맡기기 | + | [징 찍기 키] 나팔 지우개
--   전투가 시작되면 칠 순서 줄만 남기고 접혀요 (지금 칠 징 = 금테 · 잡은 징 = 흐리게) · 끝나면 다시 펴짐
--   바 안에 보안 단추가 있어서 자리 바꾸기는 전투 밖(또는 전투가 막 시작될 때)에만
local RAID_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local GOLD = { 1, 0.82, 0.35 }
local function KillList(plan)
    local l = {}
    for idx = 1, 8 do local p = plan[idx]; if p and p.kind == "kill" then l[#l + 1] = { idx, p.n } end end
    table.sort(l, function(a, b) return a[2] < b[2] end)
    return l
end
local function CCList(plan)
    local l = {}
    for _, idx in ipairs({ 5, 6, 1, 2, 3, 4, 7, 8 }) do local p = plan[idx]; if p and p.kind == "cc" then l[#l + 1] = idx end end
    return l
end
local function MoveEarlier(idx, later)
    local plan = MyPlan()
    local l = KillList(plan)
    local ord = {}
    for _, e in ipairs(l) do ord[#ord + 1] = e[1] end
    for i, x in ipairs(ord) do
        if x == idx then
            local j = later and i + 1 or i - 1
            if ord[j] then ord[i], ord[j] = ord[j], ord[i] end
            break
        end
    end
    db.killOrder = ord
    remote = nil
    PaintLabels()
end
local function Chip(i)
    local c = bar.chips[i]
    if c then return c end
    c = CreateFrame("Button", nil, bar); c:SetSize(BTN, BTN)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local bg = c:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(MEDIA .. "circle"); bg:SetAllPoints(); bg:SetVertexColor(C.btn[1], C.btn[2], C.btn[3], 1)
    c.ring = c:CreateTexture(nil, "BORDER"); c.ring:SetTexture(MEDIA .. "ring"); c.ring:SetPoint("TOPLEFT", -2, 2); c.ring:SetPoint("BOTTOMRIGHT", 2, -2)
    c.ic = c:CreateTexture(nil, "ARTWORK"); c.ic:SetTexture(RAID_TEX); c.ic:SetSize(19, 19); c.ic:SetPoint("CENTER")
    c.badge = CreateFrame("Frame", nil, c); c.badge:SetSize(15, 15); c.badge:SetPoint("CENTER", c, "TOPRIGHT", -3, -3)
    c.badge:SetFrameLevel(c:GetFrameLevel() + 3)
    local bo = c.badge:CreateTexture(nil, "ARTWORK"); bo:SetTexture(MEDIA .. "circle"); bo:SetPoint("CENTER"); bo:SetSize(18, 18)
    bo:SetVertexColor(C.plate[1], C.plate[2], C.plate[3], 1)
    c.badgeIn = c.badge:CreateTexture(nil, "ARTWORK", nil, 1); c.badgeIn:SetTexture(MEDIA .. "circle"); c.badgeIn:SetAllPoints()
    c.badgeIn:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    c.badgeFs = c.badge:CreateFontString(nil, "OVERLAY"); LeelFont(c.badgeFs, 10, ""); c.badgeFs:SetPoint("CENTER", 0, 0)
    c.badgeFs:SetTextColor(C.ink[1], C.ink[2], C.ink[3])
    c:SetScript("OnClick", function(self, btn)
        if InCombatLockdown() or not self.idx then return end
        if btn == "RightButton" then OpenDrawer(self.idx) else MoveEarlier(self.idx, IsShiftKeyDown()) end
    end)
    c:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        TipAdd(MARK_NAME[self.idx or 8], 1, 1, 1)
        TipAdd((self.n or 0) .. "번째로 잡아요", 1, 0.84, 0.88)
        TipAdd("왼쪽 클릭: 앞으로 · Shift+클릭: 뒤로 · 오른쪽 클릭: 뜻 바꾸기 (변이 · 덫 · 안 씀 …)", C.tx2[1], C.tx2[2], C.tx2[3], true)
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bar.chips[i] = c
    return c
end
local function Arrow(i)
    local a = bar.arrows[i]
    if a then return a end
    a = bar:CreateFontString(nil, "OVERLAY"); LeelFont(a, 13, ""); a:SetText("›"); a:SetTextColor(C.tx2[1], C.tx2[2], C.tx2[3])
    bar.arrows[i] = a
    return a
end
local function CCChip(i)
    local c = bar.ccs[i]
    if c then return c end
    c = CreateFrame("Button", nil, bar); c:SetHeight(24)
    c.bg = PillTex(c, "pill22", 11, C.btn, 1); c.bg:SetAllPoints()
    c.ic = c:CreateTexture(nil, "ARTWORK"); c.ic:SetTexture(RAID_TEX); c.ic:SetSize(16, 16); c.ic:SetPoint("LEFT", 5, 0)
    c.fs = c:CreateFontString(nil, "OVERLAY"); LeelFont(c.fs, 11, ""); c.fs:SetPoint("LEFT", c.ic, "RIGHT", 4, 0)
    c:SetScript("OnClick", function(self) if not InCombatLockdown() and self.idx then OpenDrawer(self.idx) end end)
    c:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP"); TipAdd(MARK_NAME[self.idx or 5], 1, 1, 1)
        TipAdd("누르면 뜻 바꾸기 (순서 · 변이 · 덫 · 혼절 · 안 씀)", C.tx2[1], C.tx2[2], C.tx2[3], true); GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bar.ccs[i] = c
    return c
end
local function Sep(i)
    local t = bar.seps[i]
    if not t then t = bar:CreateTexture(nil, "BORDER"); t:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.3); t:SetSize(1, 22); bar.seps[i] = t end
    return t
end
-- + : 안 쓰는 징 고르기 (누르면 칠 순서 맨 뒤에)
local picker
local function OpenPicker()
    if InCombatLockdown() then return end
    if not picker then
        picker = CreateFrame("Frame", nil, bar); picker:SetHeight(30); picker:SetFrameLevel(bar:GetFrameLevel() + 10)
        local bg = PillTex(picker, "pill22", 11, C.plate, 0.98); bg:SetAllPoints()
        local rim = PillTex(picker, "pill22rim", 11, C.acc, 0.5, "BORDER"); rim:SetAllPoints()
        picker.b = {}
        picker:SetScript("OnUpdate", function(self, e)
            self.t = (self.t or 0) + e
            if self.t < 0.25 then return end
            self.t = 0
            if InCombatLockdown() or not (bar:IsMouseOver(4, -4, -4, 4) or self:IsMouseOver(4, -4, -4, 4)) then self:Hide() end
        end)
    end
    local plan = MyPlan()
    local x = 6
    for _, b in ipairs(picker.b) do b:Hide() end
    local k = 0
    for _, idx in ipairs({ 8, 7, 6, 5, 4, 3, 2, 1 }) do
        if not plan[idx] then
            k = k + 1
            local b = picker.b[k]
            if not b then
                b = CreateFrame("Button", nil, picker); b:SetSize(24, 24)
                b.ic = b:CreateTexture(nil, "ARTWORK"); b.ic:SetTexture(RAID_TEX); b.ic:SetAllPoints()
                b:SetScript("OnClick", function(self)
                    db.roles = db.roles or {}; db.roles[self.idx] = "kill"
                    local ko = db.killOrder or {}
                    for i = #ko, 1, -1 do if ko[i] == self.idx then table.remove(ko, i) end end
                    -- 지금 순서를 그대로 적어 두고 맨 뒤에 붙여요
                    local l = KillList(MyPlan()); local ord = {}
                    for _, e in ipairs(l) do if e[1] ~= self.idx then ord[#ord + 1] = e[1] end end
                    ord[#ord + 1] = self.idx
                    db.killOrder = ord; remote = nil
                    picker:Hide(); PaintLabels()
                end)
                picker.b[k] = b
            end
            b.idx = idx; SetRaidTargetIconTexture(b.ic, idx)
            b:ClearAllPoints(); b:SetPoint("LEFT", picker, "LEFT", x, 0); x = x + 28
            b:Show()
        end
    end
    if k == 0 then return end
    picker:SetWidth(x + 4)
    picker:ClearAllPoints(); picker:SetPoint("TOP", bar, "BOTTOM", 0, -4); picker:Show()
end

-- 자리 잡기 (전투 밖 · 또는 전투가 막 시작될 때만)
local function Layout(combat)
    if InCombatLockdown() then return end
    local plan = Plan()
    local kl, cl = KillList(plan), CCList(plan)
    local x = 8 + 30 + 6
    local si = 0
    local function S() si = si + 1; local t = Sep(si); t:ClearAllPoints(); t:SetPoint("LEFT", bar, "LEFT", x, 0); t:Show(); x = x + 7 end
    S()
    for _, c in ipairs(bar.chips) do c:Hide() end
    for _, a in ipairs(bar.arrows) do a:Hide() end
    for _, c in ipairs(bar.ccs) do c:Hide() end
    for i, e in ipairs(kl) do
        if i > 1 then local a = Arrow(i - 1); a:ClearAllPoints(); a:SetPoint("LEFT", bar, "LEFT", x, 0); a:Show(); x = x + 9 end
        local c = Chip(i); c.idx, c.n = e[1], e[2]
        SetRaidTargetIconTexture(c.ic, e[1]); c.badgeFs:SetText(e[2])
        c:ClearAllPoints(); c:SetPoint("LEFT", bar, "LEFT", x, 0); c:Show()
        x = x + BTN + 4
    end
    if not combat then
        if #cl > 0 then
            x = x + 2; S()
            local has, who = GroupClasses()
            for i, idx in ipairs(cl) do
                local p = plan[idx]
                local c = CCChip(i); c.idx = idx
                SetRaidTargetIconTexture(c.ic, idx)
                c.fs:SetText(T(p.role) .. ((p.who and p.who ~= "") and (" · " .. p.who) or ""))
                local cc = ClassColorHex(p.cls); c.fs:SetTextColor(cc[1], cc[2], cc[3])
                c:SetWidth(5 + 16 + 4 + c.fs:GetStringWidth() + 9)
                c:ClearAllPoints(); c:SetPoint("LEFT", bar, "LEFT", x, 0); c:Show()
                x = x + c:GetWidth() + 4
            end
        end
        if not bar.plus then
            local p = CreateFrame("Button", nil, bar); p:SetSize(22, 22)
            local bg = p:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(MEDIA .. "circle"); bg:SetAllPoints(); bg:SetVertexColor(C.btn[1], C.btn[2], C.btn[3], 1)
            p.fs = p:CreateFontString(nil, "OVERLAY"); LeelFont(p.fs, 15, ""); p.fs:SetPoint("CENTER", 0, 1); p.fs:SetText("+"); p.fs:SetTextColor(C.acc[1], C.acc[2], C.acc[3])
            p:SetScript("OnClick", OpenPicker)
            Tip(p, "징 더하기", "안 쓰는 징을 칠 순서 맨 뒤에 넣어요")
            bar.plus = p
        end
        bar.plus:ClearAllPoints(); bar.plus:SetPoint("LEFT", bar, "LEFT", x + 2, 0); bar.plus:Show(); x = x + 28
    elseif bar.plus then bar.plus:Hide() end
    x = x + 2; S()
    bar.auto:ClearAllPoints(); bar.auto:SetPoint("LEFT", bar, "LEFT", x, 0); x = x + bar.auto:GetWidth() + 6
    if combat then
        bar.tell:Hide(); bar.clr:Hide()
    else
        bar.tell:Show(); bar.clr:Show()
        bar.tell:ClearAllPoints(); bar.tell:SetPoint("LEFT", bar, "LEFT", x, 0); x = x + 26 + 4
        bar.clr:ClearAllPoints(); bar.clr:SetPoint("LEFT", bar, "LEFT", x, 0); x = x + 26 + 4
    end
    for i = si + 1, #bar.seps do bar.seps[i]:Hide() end
    bar:SetWidth(x + 6)
    bar.combatLayout = combat
end

PaintLabels = function()
    if not bar then return end
    local plan, from = Plan()
    -- 줄 모양이 바뀌었으면 다시 세우기 (전투 밖에서만)
    local key = ""
    for _, e in ipairs(KillList(plan)) do key = key .. e[1] end
    key = key .. "|"
    for _, idx in ipairs(CCList(plan)) do local p = plan[idx]; key = key .. idx .. (p.role or "") .. (p.who or "") end
    if key ~= bar.orderKey or (bar.combatLayout and not InCombatLockdown()) then
        if InCombatLockdown() then orderPending = true
        else orderPending = false; bar.orderKey = key; Layout(false) end
    end
    -- 지금 칠 징 (르엘 이름표가 고른 것) = 금테 · 그보다 앞 순서 = 잡음(흐리게)
    local L = _G.LeelUI
    local cur = L and L.MarkCurrent
    local fight = InCombatLockdown() or UnitAffectingCombat("player")
    for _, c in ipairs(bar.chips) do
        if c:IsShown() and c.n then
            local isCur = cur and cur.idx == c.idx
            local done = fight and cur and cur.n and c.n < cur.n
            c:SetAlpha(done and 0.35 or 1)
            if isCur then c.ring:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
            else c.ring:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], c:IsMouseOver() and 1 or 0.35) end
        end
    end
    if bar.fromFs then bar.fromFs:SetText(from and (from .. " 님 약속") or "") end
    PaintDrawer()
end

local function SavePos()
    local x, y = bar:GetCenter()
    if x then db.pos = { math.floor(x + 0.5), math.floor(y + 0.5) } end
end

local function ApplyPos()
    bar:ClearAllPoints()
    if db.pos then
        bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", db.pos[1], db.pos[2])
    else
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190)
    end
end

local pendingShow = false
local function UpdateShown()
    if not bar then return end
    if InCombatLockdown() then pendingShow = true return end   -- 보안 단추가 든 바는 전투 중에 못 숨김
    pendingShow = false
    local show = db.show == "always" or (db.show == "group" and IsInGroup())
    bar:SetShown(show)
end

-- 마우스 단축키: 누를 때마다 마우스 올린 몹에 다음 징 (전투 중에도 되도록 보안 처리기 안에서 순서를 셈)
local sweepBtn
ResetSweep = function()
    if sweepBtn and not InCombatLockdown() then sweepBtn:SetAttribute("idx", 0) end
end

local function CreateSweep()
    sweepBtn = CreateFrame("Button", "LeelMarkSweep", UIParent, "SecureActionButtonTemplate, SecureHandlerBaseTemplate")
    sweepBtn:RegisterForClicks("AnyUp", "AnyDown")
    sweepBtn:SetAttribute("useOnKeyDown", false)
    sweepBtn:SetAttribute("type", "macro")
    sweepBtn:SetAttribute("idx", 0)
    sweepBtn:SetAttribute("macrotext", "")
    SecureHandlerWrapScript(sweepBtn, "OnClick", sweepBtn, [[
        if down then return false end
        local i = (self:GetAttribute("idx") or 0) + 1
        if i > 8 then i = 1 end
        self:SetAttribute("idx", i)
        local m = string.sub("87654321", i, i)
        self:SetAttribute("macrotext", "/tm [@mouseover,harm,nodead] ~" .. m)
    ]])
end

local function CreateBar()
    bar = CreateFrame("Frame", "LeelMarkBar", UIParent)
    bar:SetHeight(44)
    bar:SetScale(db.scale or 1)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    local bg = PillTex(bar, "pill44", 22, C.plate)
    bg:SetAllPoints()
    local rim = PillTex(bar, "pill44rim", 22, C.acc, 0.6, "BORDER")
    rim:SetAllPoints()

    -- 토끼: 끌어서 옮기기
    local bun = CreateFrame("Button", nil, bar)
    bun:SetSize(30, 30)
    bun:SetPoint("LEFT", 8, 0)
    local bt = bun:CreateTexture(nil, "ARTWORK")
    bt:SetTexture(MEDIA .. "icon"); bt:SetAllPoints()
    bun:RegisterForDrag("LeftButton")
    -- 바 안에 보안 단추가 있어서 전투 중엔 게임이 옮기기를 막아요 → 전투 밖에서만
    bun:SetScript("OnDragStart", function()
        if InCombatLockdown() then Print("전투 중엔 바를 옮길 수 없어요. 전투가 끝나고 옮겨 주세요.") return end
        bar.moving = true; bar:StartMoving()
    end)
    bun:SetScript("OnDragStop", function()
        if not bar.moving or InCombatLockdown() then return end
        bar.moving = false; bar:StopMovingOrSizing(); SavePos(); ApplyPos()
    end)
    Tip(bun, "Leel Mark", "끌어서 옮기기 · 징 왼쪽 클릭 = 앞으로 · 오른쪽 클릭 = 뜻 바꾸기 · 단축키(애드온 > Leel Mark) · /lmark")
    -- 다른 파티원 약속을 따를 때: 바 위에 작게
    bar.fromFs = bar:CreateFontString(nil, "OVERLAY"); if _G.LeelUI and _G.LeelUI.LWrap then _G.LeelUI.LWrap(bar.fromFs) end; LeelFont(bar.fromFs, 10.5, ""); bar.fromFs:SetTextColor(1, 0.84, 0.88)
    bar.fromFs:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 14, 2)

    bar.seps = {}
    bar.chips, bar.arrows, bar.ccs = {}, {}, {}

    local auto = CreateFrame("Button", "LeelMarkAuto", bar, "SecureActionButtonTemplate, SecureHandlerBaseTemplate")
    auto:RegisterForClicks("AnyUp", "AnyDown"); auto:SetAttribute("useOnKeyDown", false)
    KeyPill(auto)
    Tip(auto, "징 찍기", "전투 밖: 대상(없으면 가장 가까운 몹) 둘레 무리에 칠 순서대로 한 번에 · 전투 중: 마우스 올린 몹(없으면 대상)에 다음 징")
    auto:SetAttribute("type", "macro")
    auto:SetAttribute("macrotext", "")
    -- 키 하나: 전투 밖 = 무리 전부 · 전투 중 = 마우스 올린 몹(없으면 대상)에 아직 안 쓴 다음 징
    --   전투 중엔 게임이 단추 내용을 못 바꾸게 해서, 보안 처리기 안에서 순서를 세요 (전투 시작 때 남은 징 순서를 넣어 둠)
    SecureHandlerWrapScript(auto, "OnClick", auto, [[
        if down then return false end
        if not PlayerInCombat() then return end
        -- 마우스 올린 몹이 칠 수 있는 살아 있는 적이 아니면 아무것도 안 해요 (순서도 안 넘어가요)
        if not SecureCmdOptionParse("[@mouseover,harm,nodead][@target,harm,nodead] ok") then return false end
        local ord = self:GetAttribute("cord") or "87432651"
        local i = (self:GetAttribute("cidx") or 0) + 1
        if i > string.len(ord) then i = 1 end
        self:SetAttribute("cidx", i)
        self:SetAttribute("macrotext", "/tm [@mouseover,harm,nodead][@target,harm,nodead] ~" .. string.sub(ord, i, i))
    ]])
    auto:SetScript("PostClick", function(self, _, down)
        if down or not InCombatLockdown() then return end
        local m = tonumber((self:GetAttribute("macrotext") or ""):match("~(%d)$") or "")
        if not m then return end
        -- 매크로와 같은 규칙으로: 마우스 올린 몹이 칠 수 있는 살아 있는 적이면 그 몹, 아니면 대상
        -- 매크로와 같은 규칙: 마우스 올린 살아 있는 적 → 없으면 대상 (이름표 위에 마우스를 올리면 게임이 마우스 몹으로 안 쳐줘요)
        local u = "target"
        if UnitExists("mouseover") and Try(UnitCanAttack, "player", "mouseover") and not Try(UnitIsDead, "mouseover") then u = "mouseover" end
        RememberMark(u, m)
        ShareIfTarget(u, m)
        if _G.LeelUI and _G.LeelUI.MarkRefresh then pcall(_G.LeelUI.MarkRefresh) end
    end)
    auto:SetScript("PreClick", function(self, _, down)
        if down then return end
        if InCombatLockdown() then return end
        if not CanMark() then Print("공격대에서는 공격대장·부공격대장만 징을 찍을 수 있어요.") self:SetAttribute("macrotext", "") return end
        local text, msg = BuildAutoMacro()
        self:SetAttribute("macrotext", text or "")
        if db.debug and text then Print("자동 매크로:\n" .. text) end
        -- 같은 안내는 5초에 한 번만 (마우스 단추에 묶으면 여러 번 눌려요)
        if not text then
            if msg ~= self.lastMsg or GetTime() - (self.lastMsgT or 0) > 5 then Print(msg) end
            self.lastMsg, self.lastMsgT = msg, GetTime()
        elseif msg ~= "" then Announce(msg) end
        ResetSweep()
    end)
    local tell = CreateFrame("Button", nil, bar)
    RoundIcon(tell, "ic_horn", false); tell:SetSize(26, 26)
    Tip(tell, "약속 알리기", "파티 채팅에 징 약속을 한 줄로 (징 그림) · 르엘 UI 쓰는 파티원 이름표에도 같은 순서가 보여요")
    tell:SetScript("OnClick", function() SendPlan() end)
    local clr = CreateFrame("Button", "LeelMarkClear", bar, "SecureActionButtonTemplate")
    clr:RegisterForClicks("AnyUp", "AnyDown"); clr:SetAttribute("useOnKeyDown", false)
    RoundIcon(clr, "ic_eraser", false); clr:SetSize(26, 26)
    Tip(clr, "지우기", "모든 징을 지워요")
    clr:SetAttribute("type", "raidtarget")
    clr:SetAttribute("action", "clear-all")
    clr:HookScript("OnClick", function(_, _, down) if not down then ResetSweep(); wipe(assigned); wipe(byTok); ShareSend("C") end end)
    bar.auto, bar.tell, bar.clr = auto, tell, clr

    ApplyPos()
    UpdateShown()
    local t0 = 0
    bar:SetScript("OnUpdate", function(_, e) t0 = t0 + e; if t0 > 0.4 then t0 = 0; PaintLabels() end end)
    PaintLabels()
end

----------------------------------------------------------------------
-- 로딩 · 이벤트 · 명령어
----------------------------------------------------------------------
BINDING_HEADER_LEELMARK = "Leel Mark"
_G["BINDING_NAME_CLICK LeelMarkAuto:LeftButton"] = "징 찍기 (전투 밖 = 무리 전부 · 전투 중 = 마우스 올린 몹에 다음 징)"
_G["BINDING_NAME_CLICK LeelMarkClear:LeftButton"] = "징 모두 지우기"
_G["BINDING_NAME_CLICK LeelMarkSweep:LeftButton"] = "마우스 올린 몹에 다음 징"

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:SetScript("OnEvent", function(_, event, arg1, ...)
    if event == "NAME_PLATE_UNIT_REMOVED" then
        if arg1 then byTok[arg1] = nil end
        return
    end
    if event == "ADDON_LOADED" and arg1 == ADDON then
        LeelMarkDB = LeelMarkDB or {}
        for k, v in pairs(defaults) do if LeelMarkDB[k] == nil then LeelMarkDB[k] = v end end
        db = LeelMarkDB
    elseif event == "PLAYER_LOGIN" then
        CreateSweep()
        CreateBar()
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX); pcall(C_ChatInfo.RegisterAddonMessagePrefix, SHARE) end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg, chan, sender = arg1, select(1, ...)
        if prefix == SHARE then
            if type(msg) ~= "string" or #msg > 8 or type(sender) ~= "string" then return end
            if not (chan == "PARTY" or chan == "RAID" or chan == "INSTANCE_CHAT") then return end
            local me = UnitName("player")
            if (sender:match("^([^%-]+)") or sender) == me then return end
            ShareRecv(sender, msg)
            return
        end
        if prefix ~= PREFIX or not sender then return end
        local me = UnitName("player")
        local short = sender:match("^([^%-]+)") or sender
        if short == me then return end
        local plan = UnpackPlan(msg)
        if plan then
            remote = { plan = plan, from = short }
            Print(short .. " 님의 징 약속표를 받았어요 (이름표 순서가 같아져요)")
            if PaintLabels then PaintLabels() end
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        UpdateShown()
        if not IsInGroup() then remote = nil end
        if PaintLabels then PaintLabels() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingShow then UpdateShown() end
        if orderPending and PaintLabels then PaintLabels() end
        ResetSweep()
    elseif event == "UPDATE_BINDINGS" then
        if bar and bar.auto and bar.auto.PaintKey and not InCombatLockdown() then bar.auto:PaintKey(); bar.orderKey = nil; PaintLabels() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- D안: 전투가 시작되면 칠 순서 줄만 남기고 접기 (이 순간까진 자리를 바꿀 수 있어요)
        if bar and bar:IsShown() then pcall(Layout, true) end
        if drawer then drawer:Hide() end
        -- 전투 직전: 낡은 자동 매크로가 엉뚱한 몹에 찍지 않게 비움
        local a = _G.LeelMarkAuto
        if a then
            a:SetAttribute("macrotext", "")
            -- 전투 중 같은 키 = 아직 안 쓴 징부터 약속 순서대로
            local order = AutoOrder()
            local used = UsedMarks()
            -- 던전에선 징이 숨겨져서 못 읽어요 → 내가 찍어 둔 기억도 쓴 징으로 쳐요
            for _, v in pairs(byTok) do used[v] = true end
            for _, v in pairs(assigned) do used[v] = true end
            local rest, all = {}, {}
            for _, m in ipairs(order) do all[#all + 1] = m; if not used[m] then rest[#rest + 1] = m end end
            for _, m in ipairs(order) do if used[m] then rest[#rest + 1] = m end end   -- 다 쓰면 처음 징부터 다시
            a:SetAttribute("cord", table.concat(#rest > 0 and rest or all))
            a:SetAttribute("cidx", 0)
        end
    end
end)

SLASH_LEELMARK1 = "/lmark"
SLASH_LEELMARK2 = "/징"
SlashCmdList.LEELMARK = function(msg)
    local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
    if cmd == "자동" or cmd == "auto" or cmd == "지우기" or cmd == "clear" then
        Print("게임 규칙상 채팅 명령으로는 징을 못 찍어요. 바의 단추나 단축키를 써 주세요.")
    elseif cmd == "보이기" or cmd == "show" then
        db.show = (db.show == "always") and "group" or "always"
        UpdateShown()
        Print(db.show == "always" and "바를 항상 보여요." or "바는 파티일 때만 보여요.")
    elseif cmd == "숨기기" or cmd == "hide" then
        db.show = "never"; UpdateShown()
        Print("바를 숨겼어요. /lmark 보이기 로 다시 켜요. (단축키는 계속 동작)")
    elseif cmd == "알림" or cmd == "announce" then
        db.announce = not db.announce
        Print("자동으로 찍을 때 파티 채팅 알림 " .. (db.announce and "켬" or "끔"))
    elseif cmd == "크기" or cmd == "scale" then
        local n = tonumber(arg)
        if n then
            if n > 3 then n = n / 100 end
            db.scale = math.min(1.6, math.max(0.6, n))
            bar:SetScale(db.scale); ApplyPos()
            Print("바 크기 " .. math.floor(db.scale * 100 + 0.5) .. "%")
        end
    elseif cmd == "무리" or cmd == "pack" then
        db.packOnly = (db.packOnly == false)
        Print("자동: " .. (db.packOnly ~= false and "대상 둘레 가까운 무리만 찍어요" or "보이는 적 전부 찍어요"))
    elseif cmd == "우선" or cmd == "prio" then
        -- 지금 누르면 어떤 몹에 무슨 징이 갈지 · 점수에 쓴 것 (? = 게임이 숨겨서 못 읽음)
        local list, used = Candidates()
        local order = AutoOrder()
        local oi = 1
        Print(("후보 %d마리 · 순서 %s"):format(#list, table.concat(order, ",")))
        for _, c in ipairs(list) do
            while order[oi] and used[order[oi]] do oi = oi + 1 end
            local m = order[oi]; oi = oi + 1
            local nm = ""; pcall(function() local x = UnitName(c.unit); if not issecretvalue_safe(x) then nm = x or "" end end)
            Print(("%s %s → %s · 점수 %s (%s)"):format(c.unit, nm, m and T(MARK_NAME[m]) or "없음", tostring(math.floor(c.score)), c.why or ""))
        end
    elseif cmd == "점검" or cmd == "debug" then
        db.debug = not db.debug
        Print("점검 " .. (db.debug and "켬: 자동을 누르면 만든 매크로를 채팅에 보여 줘요" or "끔"))
    elseif cmd == "위치" or cmd == "reset" then
        db.pos = nil; ApplyPos()
        Print("바 자리를 처음대로 돌렸어요.")
    else
        Print("/lmark 보이기 · 숨기기 · 알림 · 무리 · 우선 · 크기 80 · 위치")
        Print("단축키: 게임 메뉴 > 단축키 > 애드온 > Leel Mark (자동 · 지우기 · 마우스 올린 몹에 다음 징)")
    end
end
