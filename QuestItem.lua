-- LeelUI / QuestItem.lua
-- 퀘템 ↔ 몹 연결 (D안): 퀘스트에 써야 하는 템이 가방에 있고, 지금 대상이 그 템을 쓸 몹이면
--   * 몹 이름표 위에 템 아이콘 (반짝)
--   * 대상 창 오른쪽에 템 단추 → 누르면 바로 사용 (오른쪽 클릭: 이 몹에선 그만 보기)
-- 몹 알아내는 순서: 내가 예전에 이 템을 쓴 몹(기억) → Questie 몹 정보 → 게임 툴팁의 퀘스트 줄 → 템 설명에 나온 이름

local _, ns = ...
local C = ns.C

local function DB()
    ns.db.qitem = ns.db.qitem or {}
    local d = ns.db.qitem
    if d.on == nil then d.on = true end
    d.mobs = d.mobs or {}      -- itemID → { [몹 이름] = true }
    d.no = d.no or {}          -- itemID → { [몹 이름] = true }  (그만 보기)
    return d
end
ns.QItemDB = DB

----------------------------------------------------------------------
-- 가방의 "쓸 수 있는 퀘템" 찾기 + 어느 퀘스트 템인지
----------------------------------------------------------------------
local function NumSlots(b)
    if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(b) end
    return GetContainerNumSlots and GetContainerNumSlots(b) or 0
end
local function ItemID(b, s)
    if C_Container and C_Container.GetContainerItemID then return C_Container.GetContainerItemID(b, s) end
    return GetContainerItemID and GetContainerItemID(b, s)
end
local function ItemInfo(id)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not f then return end
    local _, _, _, _, icon, classID = f(id)
    return icon, classID
end
local function ItemName(id)
    local n = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or (GetItemInfo and GetItemInfo(id))
    return n
end
local function ItemSpell(id)
    local f = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    if not f then return end
    local ok, name, spellID = pcall(f, id)
    if ok then return name, spellID end
end

-- 툴팁 글줄 (게임이 주는 그대로)
local function TipLines(kind, arg)
    local out = {}
    if not (C_TooltipInfo and C_TooltipInfo[kind]) then return out end
    local ok, data = pcall(C_TooltipInfo[kind], arg)
    if ok and data and data.lines then
        for _, l in ipairs(data.lines) do
            if l.leftText and l.leftText ~= "" then out[#out + 1] = l.leftText end
        end
    end
    return out
end

local function Plain(s) return (s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s+", "") end

-- 퀘스트 목록 (제목, 목표 글)
local function QuestLog()
    local out = {}
    if not GetQuestLogTitle then return out end
    local n = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
    for i = 1, (type(n) == "number" and n or 0) do
        local title, _, _, isHeader, _, isComplete, _, id = GetQuestLogTitle(i)
        if title and not isHeader then
            local objs = {}
            if GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
                local ok, k = pcall(GetNumQuestLeaderBoards, i)
                for j = 1, (ok and k or 0) do
                    local ok2, text = pcall(GetQuestLogLeaderBoard, j, i)
                    if ok2 and text then objs[#objs + 1] = text end
                end
            end
            local special
            if GetQuestLogSpecialItemInfo then
                local ok, link = pcall(GetQuestLogSpecialItemInfo, i)
                if ok and type(link) == "string" then special = tonumber(link:match("item:(%d+)")) end
            end
            out[#out + 1] = { index = i, id = id, title = title, objs = objs, done = (isComplete == 1 or isComplete == true), special = special }
        end
    end
    return out
end

-- 템 이름이 퀘스트 목표 글 안에 있으면 그 퀘스트 템 (예: "불타는 보석" ⊂ "영혼이 깃든 불타는 보석 0/15")
local items = {}     -- { id, name, icon, quest(=QuestLog 항목), desc(템 설명 글 모음) }
local function Scan()
    wipe(items)
    local log = QuestLog()
    local seen = {}
    for b = 0, 4 do
        for s = 1, (NumSlots(b) or 0) do
            local id = ItemID(b, s)
            if id and not seen[id] then
                seen[id] = true
                local icon, classID = ItemInfo(id)
                local spell = ItemSpell(id)
                if spell then
                    local name = ItemName(id)
                    local pn = Plain(name)
                    local quest
                    for _, q in ipairs(log) do
                        if q.special == id then quest = q break end
                    end
                    if not quest and pn ~= "" then
                        for _, q in ipairs(log) do
                            for _, o in ipairs(q.objs) do
                                if Plain(o):find(pn, 1, true) then quest = q break end
                            end
                            if quest then break end
                        end
                    end
                    if quest or classID == 12 then
                        items[#items + 1] = { id = id, name = name, icon = icon, quest = quest,
                                              desc = table.concat(TipLines("GetItemByID", id), " ") }
                    end
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- 지금 대상에 쓸 템 고르기
----------------------------------------------------------------------
local QTips
local function QuestieQuestsFor(unit)
    local out = {}
    if QTips == nil then
        QTips = false
        if QuestieLoader and QuestieLoader.ImportModule then
            local ok, m = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieTooltips")
            if ok and m then QTips = m end
        end
    end
    if not (QTips and QTips.lookupByKey) then return out end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or type(guid) ~= "string" then return out end
    local kind, _, _, _, _, npc = strsplit("-", guid)
    if (kind ~= "Creature" and kind ~= "Vehicle") or not npc then return out end
    local tips = QTips.lookupByKey["m_" .. npc]
    if not tips then return out end
    for _, tip in pairs(tips) do
        local qid = tip.questId or (tip.objective and (tip.objective.questId or (tip.objective.QuestData and tip.objective.QuestData.Id)))
        if qid then out[qid] = true end
    end
    return out
end

local function Pick(unit)
    if #items == 0 or not UnitExists(unit) or UnitIsDead(unit) or not UnitCanAttack("player", unit) then return end
    local ok, name = pcall(UnitName, unit)
    if not ok or type(name) ~= "string" then return end
    local d = DB()
    -- 1) 예전에 이 몹에 쓴 템
    for _, it in ipairs(items) do
        if d.mobs[it.id] and d.mobs[it.id][name] and not (d.no[it.id] and d.no[it.id][name]) then return it, "기억" end
    end
    -- 2) Questie가 아는 이 몹의 퀘스트
    local qs = QuestieQuestsFor(unit)
    -- Questie 없이: 툴팁 · 잡아 본 몹 기억으로 아는 퀘스트 제목
    local titles = ns.QuestMobTitles and ns.QuestMobTitles(unit) or {}
    for _, it in ipairs(items) do
        if it.quest and titles[it.quest.title] and not it.quest.done and not (d.no[it.id] and d.no[it.id][name]) then return it, "퀘스트 몹" end
    end
    for _, it in ipairs(items) do
        if it.quest and it.quest.id and qs[it.quest.id] and not it.quest.done and not (d.no[it.id] and d.no[it.id][name]) then return it, "Questie" end
    end
    -- 3) 게임 툴팁에 퀘스트 이름이 붙어 있으면
    local lines = TipLines("GetUnit", unit)
    for _, it in ipairs(items) do
        if it.quest and not it.quest.done and not (d.no[it.id] and d.no[it.id][name]) then
            for i = 2, #lines do
                if lines[i] == it.quest.title then return it, "툴팁" end
            end
        end
    end
    -- 4) 템 설명에 몹 이름이 나오면
    local pn = Plain(name)
    for _, it in ipairs(items) do
        if pn ~= "" and Plain(it.desc):find(pn, 1, true) and not (d.no[it.id] and d.no[it.id][name]) then return it, "설명" end
    end
end

----------------------------------------------------------------------
-- 그리기: 이름표 위 아이콘 + 대상 창 옆 단추
----------------------------------------------------------------------
local btn, plateIcon, current

-- 이름표 퀘스트 원과 같은 모양: 검은 테 · 판 · 분홍 고리 안에 둥근 템 그림
local function Disc(f, layer, sub, size, color, a)
    local t = f:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(ns.MEDIA .. "circle"); t:SetSize(size, size); t:SetPoint("CENTER")
    t:SetVertexColor(color[1], color[2], color[3], a or 1)
    return t
end
local function RoundIcon(f, size)
    f.glow = Disc(f, "BACKGROUND", -1, size + 14, C.acc, 0.35)
    Disc(f, "BACKGROUND", 0, size + 2, { 0, 0, 0 }, 0.75)
    Disc(f, "BACKGROUND", 1, size, C.acc, 1)
    Disc(f, "BACKGROUND", 2, size - 4, { 0.114, 0.082, 0.078 }, 1)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(size - 7, size - 7); f.icon:SetPoint("CENTER")
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local m = f:CreateMaskTexture()
    m:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(f.icon)
    f.icon:AddMaskTexture(m)
    local ag = f:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
    local an = ag:CreateAnimation("Alpha"); an:SetFromAlpha(0.15); an:SetToAlpha(0.55); an:SetDuration(0.8)
    an:SetTarget(f.glow)
    ag:Play()
end

local function MakeButton()
    btn = CreateFrame("Button", "LeelUI_QuestItemButton", UIParent, "SecureActionButtonTemplate")
    btn:SetSize(38, 38)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("type1", "item")
    btn:SetFrameStrata("MEDIUM")
    RoundIcon(btn, 38)
    btn.cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cd:SetAllPoints(btn.icon)
    if btn.cd.SetSwipeTexture then btn.cd:SetSwipeTexture(ns.MEDIA .. "circle") end
    -- 아래 작은 알약: "쓰기" + 개수
    btn.say = CreateFrame("Frame", nil, btn)
    btn.say:SetHeight(16); btn.say:SetPoint("TOP", btn, "BOTTOM", 0, 3)
    btn.say:SetFrameLevel(btn:GetFrameLevel() + 3)
    ns.RoundRect(btn.say, 8, { 0, 0, 0 }, "ARTWORK", 0, -1):SetColor({ 0, 0, 0 }, 0.8)
    ns.RoundRect(btn.say, 8, C.accHi, "ARTWORK", 1, 0)
    btn.sayText = btn.say:CreateFontString(nil, "OVERLAY")
    btn.sayText:SetFont(ns.FONT, 10, ""); btn.sayText:SetTextColor(C.ink[1], C.ink[2], C.ink[3])
    btn.sayText:SetPoint("CENTER", 0, 0)
    btn:SetScript("OnEnter", function(self)
        if not current then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(current.id)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("클릭: 지금 대상에게 쓰기", 1, 0.84, 0.88)
        GameTooltip:AddLine("오른쪽 클릭: 이 몹에선 그만 보기", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:HookScript("OnClick", function(_, b, down)
        if down then return end
        if b == "RightButton" and current then
            local name = UnitName("target")
            if name then
                local d = DB()
                d.no[current.id] = d.no[current.id] or {}
                d.no[current.id][name] = true
                if d.mobs[current.id] then d.mobs[current.id][name] = nil end
                ns.Print(("%s 에는 [%s] 표시를 그만 보여줘요."):format(name, current.name or "?"))
                ns.QuestItemRefresh()
            end
        end
    end)
    -- 적 대상이 있을 때만 (전투 중에도 게임이 알아서 보였다 숨겼다)
    RegisterStateDriver(btn, "visibility", "[@target,harm,nodead] show; hide")
    btn:SetAlpha(0)
end

local function PlaceButton()
    if InCombatLockdown() then return end
    btn:ClearAllPoints()
    local t = ns.hudFrames and ns.hudFrames.target
    if t then btn:SetPoint("LEFT", t, "RIGHT", 10, 2)
    else btn:SetPoint("CENTER", UIParent, "CENTER", 220, -160) end
end

local function MakePlateIcon()
    plateIcon = CreateFrame("Frame", nil, UIParent)
    plateIcon:SetSize(26, 26)
    plateIcon:SetFrameStrata("LOW")
    RoundIcon(plateIcon, 26)
    plateIcon:Hide()
end

local function Count(id)
    local f = (C_Item and C_Item.GetItemCount) or GetItemCount
    return f and f(id) or 0
end

function ns.QuestItemRefresh()
    if not btn then return end
    local d = DB()
    local it, why = nil, nil
    if d.on then
        local ok, a, b = pcall(Pick, "target")
        if ok then it, why = a, b end
    end
    current = it
    if it then
        btn.icon:SetTexture(it.icon)
        local n = Count(it.id)
        btn.sayText:SetText(n > 1 and ("쓰기 " .. n) or "쓰기")
        btn.say:SetWidth(btn.sayText:GetStringWidth() + 12)
        btn:SetAlpha(1)
        if not InCombatLockdown() then btn:SetAttribute("item", "item:" .. it.id) end
        local start, dur = 0, 0
        local cdf = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
        if cdf then start, dur = cdf(it.id) end
        if start and dur and dur > 0 then btn.cd:SetCooldown(start, dur) else btn.cd:Clear() end
        -- 이름표 위
        local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
        local f = plate and (plate.leel or plate)
        if f and plate:IsShown() then
            plateIcon.icon:SetTexture(it.icon)
            plateIcon:SetParent(f)
            plateIcon:ClearAllPoints()
            plateIcon:SetPoint("BOTTOM", f.hp or f, "TOP", 0, f.hp and 20 or 4)
            plateIcon:SetFrameLevel(f:GetFrameLevel() + 10)
            plateIcon:Show()
        else
            plateIcon:Hide()
        end
    else
        btn:SetAlpha(0)
        plateIcon:Hide()
    end
end

----------------------------------------------------------------------
-- 이 템을 대상에게 쓰면 그 몹 이름을 기억 (다음부터 바로 표시)
----------------------------------------------------------------------
local function LearnUse(spellID)
    if not spellID then return end
    local name = UnitExists("target") and UnitCanAttack("player", "target") and UnitName("target")
    if type(name) ~= "string" then return end
    for _, it in ipairs(items) do
        local _, sid = ItemSpell(it.id)
        if sid == spellID then
            local d = DB()
            d.mobs[it.id] = d.mobs[it.id] or {}
            d.mobs[it.id][name] = true
            if d.no[it.id] then d.no[it.id][name] = nil end
            return
        end
    end
end

----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, e, a1, a2, a3)
    if e == "PLAYER_LOGIN" then
        if not ns.db then return end
        MakeButton(); MakePlateIcon()
        C_Timer.After(1, function() PlaceButton(); Scan(); ns.QuestItemRefresh() end)
        self:RegisterEvent("BAG_UPDATE_DELAYED")
        self:RegisterEvent("QUEST_LOG_UPDATE")
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:RegisterEvent("BAG_UPDATE_COOLDOWN")
        return
    end
    if e == "BAG_UPDATE_DELAYED" or e == "QUEST_LOG_UPDATE" then
        if self.pending then return end
        self.pending = true
        C_Timer.After(0.4, function() self.pending = false; Scan(); ns.QuestItemRefresh() end)
    elseif e == "PLAYER_TARGET_CHANGED" or e == "BAG_UPDATE_COOLDOWN" then
        ns.QuestItemRefresh()
    elseif e == "NAME_PLATE_UNIT_ADDED" then
        if a1 and UnitIsUnit(a1, "target") then C_Timer.After(0, ns.QuestItemRefresh) end
    elseif e == "PLAYER_REGEN_ENABLED" then
        PlaceButton(); ns.QuestItemRefresh()
    elseif e == "UNIT_SPELLCAST_SUCCEEDED" then
        if a1 == "player" then LearnUse(a3) end
    end
end)

-- 이동 모드로 대상 창을 옮기면 단추도 따라가게
if ns.ApplyHudParts then
    hooksecurefunc(ns, "ApplyHudParts", function() C_Timer.After(0.1, function() if btn then PlaceButton() end end) end)
end
