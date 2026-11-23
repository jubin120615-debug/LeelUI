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

local function AutoOrder()
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
local function Score(u)
    local s = 0
    if Try(function() return UnitCastingInfo(u) or UnitChannelInfo(u) end) then s = s + 100 end   -- 시전 중
    if Try(function() local c = UnitClassification(u); return c == "elite" or c == "rareelite" or c == "worldboss" end) then s = s + 50 end
    if Try(function() return UnitPowerType(u) == 0 end) then s = s + 20 end   -- 마나 쓰는 몹(주문형·치유형)
    local okh, hm = pcall(function() return UnitHealthMax(u) / 1000 end)
    if okh and type(hm) == "number" then s = s + math.min(hm, 19) end
    return s
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
local NEAR = 30   -- 나와 이 거리(미터)보다 먼 몹은 대상이어도 안 찍어요
local function KeepPack(list)
    -- 1) 멀리 있는 몹은 먼저 빼기
    local near, cut = {}, 0
    for _, c in ipairs(list) do
        c.range = Range(c.unit)
        if c.range <= NEAR then near[#near + 1] = c else cut = cut + 1 end
    end
    list = near
    if #list <= 1 then return list, cut end
    local anchor
    for _, c in ipairs(list) do
        if Try(UnitIsUnit, c.unit, "target") then anchor = c break end
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
                ok = d <= lim and dr <= 10
            else
                ok = dr <= 5   -- 화면 위치를 못 재면 나와의 거리 구간이 같은 몹만
            end
        end
        if ok then keep[#keep + 1] = c else cut = cut + 1 end
    end
    return keep, cut
end

local function Candidates()
    local list, used = {}, {}
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local u = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if u and Try(UnitCanAttack, "player", u) and not Try(UnitIsDead, u) then
            local m = GetMark(u)
            if m then
                used[m] = true
            elseif not Try(UnitIsTapDenied, u) then
                local x, y = PlatePos(plate)
                list[#list + 1] = { unit = u, score = Score(u), x = x, y = y }
            end
        end
    end
    local cut
    if db.packOnly ~= false then list, cut = KeepPack(list) end
    local tm = GetMark("target")
    if tm then used[tm] = true end
    table.sort(list, function(a, b) return a.score > b.score end)
    return list, used, cut or 0
end

local function Announce(text)
    if not db.announce or not IsInGroup() then return end
    local ch = IsInRaid() and "RAID" or "PARTY"
    pcall(SendChatMessage, "[Leel Mark] " .. text, ch)
end

-- 자동: 전투 밖에서 누르는 순간(PreClick) 우선순위를 계산해 "/tm [@nameplateN] ~징" 매크로를 만들어 둠
local function BuildAutoMacro()
    local list, used, cut = Candidates()
    if #list == 0 then
        if cut > 0 then return nil, "30m 안에 징을 찍을 적이 없어요. 조금 더 다가가서 눌러 주세요." end
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
    for n, idx in ipairs(kill) do plan[idx] = { kind = "kill", n = n } end
    return plan
end

local function Plan()
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
PaintLabels = function()
    if not bar then return end
    local plan, from = Plan()
    local used = UsedMarks()
    local any = next(used) ~= nil
    local tm = GetMark("target")
    for idx, r in pairs(rows) do
        local p = plan[idx]
        r.plan = p
        if p and p.kind == "kill" then
            r.badge:Show(); r.badgeIn:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1); r.badgeFs:SetText(p.n)
        elseif p then
            local c = ClassColorHex(p.cls)
            r.badge:Show(); r.badgeIn:SetVertexColor(c[1], c[2], c[3], 1); r.badgeFs:SetText("")
        else
            r.badge:Hide()
        end
        r:SetAlpha((not p) and 0.35 or ((any and not used[idx]) and 0.45 or 1))
        r.hot = (tm == idx)
        r.ring:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], (r.hot or r:IsMouseOver()) and 1 or 0.35)
    end
    if bar.fromFs then bar.fromFs:SetText(from and (from .. " 님 약속") or "") end
    PaintDrawer()
    -- 징 순서 다시 세우기 (전투 밖에서만)
    local key = ""
    local list = ROrder(plan)
    for _, e in ipairs(list) do key = key .. e[1] end
    if key ~= bar.orderKey then
        if InCombatLockdown() then orderPending = true return end
        orderPending = false
        bar.orderKey = key
        local x = 8 + 30 + 12
        for _, e in ipairs(list) do
            local r = rows[e[1]]
            r:ClearAllPoints(); r:SetPoint("LEFT", bar, "LEFT", x, 0)
            x = x + BTN + GAP
        end
    end
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
    bun:SetScript("OnDragStart", function() bar:StartMoving() end)
    bun:SetScript("OnDragStop", function() bar:StopMovingOrSizing(); SavePos(); ApplyPos() end)
    Tip(bun, "Leel Mark", "끌어서 옮기기 · 징에 마우스 = 약속 서랍 · 단축키(애드온 > Leel Mark) · /lmark")
    -- 다른 파티원 약속을 따를 때: 바 위에 작게
    bar.fromFs = bar:CreateFontString(nil, "OVERLAY"); if _G.LeelUI and _G.LeelUI.LWrap then _G.LeelUI.LWrap(bar.fromFs) end; LeelFont(bar.fromFs, 10.5, ""); bar.fromFs:SetTextColor(1, 0.84, 0.88)
    bar.fromFs:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 14, 2)

    for idx = 1, 8 do MarkBtn(bar, idx) end
    local marksEnd = 8 + 30 + 12 + 8 * BTN + 7 * GAP
    local function Sep(x)
        local t = bar:CreateTexture(nil, "BORDER"); t:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.3); t:SetSize(1, 22)
        t:SetPoint("LEFT", bar, "LEFT", x, 0)
    end
    Sep(8 + 30 + 5); Sep(marksEnd + 6)

    local auto = CreateFrame("Button", "LeelMarkAuto", bar, "SecureActionButtonTemplate")
    auto:RegisterForClicks("AnyUp", "AnyDown"); auto:SetAttribute("useOnKeyDown", false)
    RoundIcon(auto, "ic_wand", true)
    Tip(auto, "자동", "대상(없으면 가장 가까운 몹) 둘레 무리에만 약속표 순서대로 빈 징을 채워요 (시전 몹·정예 먼저). 전투 밖에서만")
    auto:SetAttribute("type", "macro")
    auto:SetAttribute("macrotext", "")
    auto:SetScript("PreClick", function(self, _, down)
        if down then return end
        if InCombatLockdown() then Print("전투 중에는 자동을 쓸 수 없어요. 징 단추나 마우스 단축키를 써 주세요.") return end
        if not CanMark() then Print("공격대에서는 공격대장·부공격대장만 징을 찍을 수 있어요.") self:SetAttribute("macrotext", "") return end
        local text, msg = BuildAutoMacro()
        self:SetAttribute("macrotext", text or "")
        if db.debug and text then Print("자동 매크로:\n" .. text) end
        if not text then Print(msg) elseif msg ~= "" then Announce(msg) end
        ResetSweep()
    end)
    local tell = CreateFrame("Button", nil, bar)
    RoundIcon(tell, "ic_horn", false)
    Tip(tell, "약속 알리기", "파티 채팅에 징 약속을 한 줄로 (징 그림) · 르엘 UI 쓰는 파티원 이름표에도 같은 순서가 보여요")
    tell:SetScript("OnClick", function() SendPlan() end)
    local clr = CreateFrame("Button", "LeelMarkClear", bar, "SecureActionButtonTemplate")
    clr:RegisterForClicks("AnyUp", "AnyDown"); clr:SetAttribute("useOnKeyDown", false)
    RoundIcon(clr, "ic_eraser", false)
    Tip(clr, "지우기", "모든 징을 지워요")
    clr:SetAttribute("type", "raidtarget")
    clr:SetAttribute("action", "clear-all")
    clr:HookScript("OnClick", function(_, _, down) if not down then ResetSweep() end end)
    auto:SetPoint("LEFT", bar, "LEFT", marksEnd + 13, 0)
    tell:SetPoint("LEFT", auto, "RIGHT", 6, 0)
    clr:SetPoint("LEFT", tell, "RIGHT", 6, 0)
    bar:SetWidth(marksEnd + 13 + 3 * 32 + 2 * 6 + 8)

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
_G["BINDING_NAME_CLICK LeelMarkAuto:LeftButton"] = "자동으로 징 찍기 (전투 밖)"
_G["BINDING_NAME_CLICK LeelMarkClear:LeftButton"] = "징 모두 지우기"
_G["BINDING_NAME_CLICK LeelMarkSweep:LeftButton"] = "마우스 올린 몹에 다음 징"

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:SetScript("OnEvent", function(_, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        LeelMarkDB = LeelMarkDB or {}
        for k, v in pairs(defaults) do if LeelMarkDB[k] == nil then LeelMarkDB[k] = v end end
        db = LeelMarkDB
    elseif event == "PLAYER_LOGIN" then
        CreateSweep()
        CreateBar()
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg, _, sender = arg1, select(1, ...)
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
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- 전투 직전: 낡은 자동 매크로가 엉뚱한 몹에 찍지 않게 비움
        local a = _G.LeelMarkAuto
        if a then a:SetAttribute("macrotext", "") end
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
    elseif cmd == "점검" or cmd == "debug" then
        db.debug = not db.debug
        Print("점검 " .. (db.debug and "켬: 자동을 누르면 만든 매크로를 채팅에 보여 줘요" or "끔"))
    elseif cmd == "위치" or cmd == "reset" then
        db.pos = nil; ApplyPos()
        Print("바 자리를 처음대로 돌렸어요.")
    else
        Print("/lmark 보이기 · 숨기기 · 알림 · 무리 · 크기 80 · 위치")
        Print("단축키: 게임 메뉴 > 단축키 > 애드온 > Leel Mark (자동 · 지우기 · 마우스 올린 몹에 다음 징)")
    end
end
