-- LeelUI / Bags.lua
-- 르엘 가방: 가방 5개를 분홍 창 하나로 (분류 알약, 찾기, 정리, 돈) + 미니맵 아래 남은 칸 숫자, 거의 차면 알림

local _, ns = ...
local C = ns.C
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo  -- 새 클라이언트는 C_Item 쪽에만 있음

local function DB()
    ns.db.bags = ns.db.bags or {}
    local d = ns.db.bags
    local def = { on = true, chip = false, bar = true, warn = true, low = 3, skin = true }
    for k, v in pairs(def) do if d[k] == nil then d[k] = v end end
    d.skin = true -- 르엘 통합 가방은 항상 사용
    return d
end
ns.BagsDB = DB

local CC = C_Container or {}
local NumSlots = CC.GetContainerNumSlots or GetContainerNumSlots
local NumFree = CC.GetContainerNumFreeSlots or GetContainerNumFreeSlots

local function SlotInfo(bag, slot)
    if CC.GetContainerItemInfo then
        local ok, t = pcall(CC.GetContainerItemInfo, bag, slot)
        if ok and type(t) == "table" then return t.quality, t.stackCount, t.hyperlink, t.hasNoValue end
        return
    end
    if GetContainerItemInfo then
        local _, count, _, quality, _, _, link, _, noValue = GetContainerItemInfo(bag, slot)
        return quality, count, link, noValue
    end
end

-- 남은 칸 / 전체 칸 (일반 가방만: 화살통, 탄약 주머니 같은 특수 가방은 뺌)
local function Count()
    local free, total = 0, 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local n = NumSlots(bag) or 0
        local f, family = NumFree(bag)
        if n > 0 and (family == nil or family == 0) then
            total = total + n
            free = free + (f or 0)
        end
    end
    return free, total
end

local function GrayValue()
    local sum = 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (NumSlots(bag) or 0) do
            local q, count, link, noValue = SlotInfo(bag, slot)
            if link and not noValue then
                local _, _, iq, _, _, _, _, _, _, _, price = GetItemInfo(link)
                q = q or iq
                if q == 0 and price then sum = sum + price * (count or 1) end
            end
        end
    end
    return sum
end

local function Money(c)
    if GetCoinTextureString then return GetCoinTextureString(c) end
    return string.format("%d골 %d은", c / 10000, (c / 100) % 100)
end

-- 르엘 토끼 동전 (가방 아래 돈 표시)
local function Coin(k, sz) sz = sz or 15; return "|T" .. ns.MEDIA .. "coin_" .. k .. ":" .. sz .. ":" .. sz .. ":0:0|t" end
local function BunnyMoney(c, sz)
    c = tonumber(c) or 0
    local g, sv, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local t = {}
    if g > 0 then t[#t + 1] = Coin("g", sz) .. " " .. (BreakUpLargeNumbers and BreakUpLargeNumbers(g) or g) end
    if g > 0 or sv > 0 then t[#t + 1] = Coin("s", sz) .. " " .. sv end
    if cp > 0 or #t == 0 then t[#t + 1] = Coin("c", sz) .. " " .. cp end
    return table.concat(t, sz and " " or "   ")
end
ns.BunnyMoney = BunnyMoney

----------------------------------------------------------------------
-- 미니맵 아래 숫자
----------------------------------------------------------------------
local chip
local function BuildChip()
    chip = CreateFrame("Button", "LeelUI_BagChip", UIParent)
    chip:SetSize(86, 26)
    chip:SetFrameStrata("MEDIUM")
    chip:SetMovable(true)
    chip:SetClampedToScreen(true)
    chip:RegisterForDrag("LeftButton")
    chip:RegisterForClicks("LeftButtonUp")
    chip.fill, chip.edge = ns.RoundPlate(chip, 13, { 0.125, 0.094, 0.086, 0.95 }, { 0.949, 0.702, 0.761, 0.6 })
    chip.disc = chip:CreateTexture(nil, "ARTWORK")
    chip.disc:SetTexture(ns.MEDIA .. "circle"); chip.disc:SetSize(22, 22); chip.disc:SetPoint("LEFT", 3, 0)
    local ic = chip:CreateTexture(nil, "OVERLAY")
    ic:SetTexture(ns.MEDIA .. "bag_bunny"); ic:SetSize(20, 20); ic:SetPoint("CENTER", chip.disc, "CENTER", 0, 1)
    chip.num = ns.Num(chip, 16, C.tx)
    chip.num:SetPoint("LEFT", chip.disc, "RIGHT", 6, 0)
    chip.tot = ns.Font(chip, 10.5, C.tx2)
    chip.tot:SetPoint("LEFT", chip.num, "RIGHT", 3, -1)

    local function Place()
        local p = DB().chipPos
        chip:ClearAllPoints()
        if p then
            chip:SetPoint(p[1], UIParent, p[2], p[3], p[4])
        elseif ns.MinimapFoot then
            chip:SetPoint("TOP", ns.MinimapFoot, "BOTTOM", 0, -6)   -- 르엘 미니맵 아래 줄 밑
        elseif Minimap then
            chip:SetPoint("TOP", Minimap, "BOTTOM", 0, -8)
        else
            chip:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -200)
        end
    end
    chip.Place = Place
    Place()

    chip:SetScript("OnClick", function() if ToggleAllBags then ToggleAllBags() end end)
    chip:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
    chip:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        DB().chipPos = { "CENTER", "BOTTOMLEFT", math.floor(x + 0.5), math.floor(y + 0.5) }
        Place()
    end)
    chip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        local free, total = Count()
        GameTooltip:AddLine("|cfff2b3c2가방|r  남은 칸 " .. free .. " / " .. total)
        local g = GrayValue()
        if g > 0 then GameTooltip:AddLine("회색템 " .. Money(g), 0.84, 0.63, 0.61) end
        GameTooltip:AddLine("클릭: 가방 열기   Shift+끌기: 옮기기", 0.62, 0.54, 0.52)
        GameTooltip:Show()
    end)
    chip:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 거의 찼을 때 천천히 깜빡
    chip:SetScript("OnUpdate", function(self, el)
        if not self.warn then return end
        self.ph = (self.ph or 0) + el * 3
        local a = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(self.ph))
        self.edge:SetColor({ 1, 0.56, 0.64 }, a)
    end)
end

----------------------------------------------------------------------
-- 르엘 가방: 가방 5개를 분홍 창 하나로 (게임 가방 창 대신)
----------------------------------------------------------------------
local COLS, SZ, GAP, PAD = 12, 36, 4, 12
local HEAD, TABS, FOOT = 36, 30, 40
local GetInfo = function(bag, slot)
    if CC.GetContainerItemInfo then
        local ok, t = pcall(CC.GetContainerItemInfo, bag, slot)
        if ok then return t end
        return
    end
    local tex, count, locked, quality, _, _, link, _, noValue, id = GetContainerItemInfo(bag, slot)
    if not tex then return end
    return { iconFileID = tex, stackCount = count, isLocked = locked, quality = quality, hyperlink = link,
             hasNoValue = noValue, itemID = id }
end
local GetCooldown = CC.GetContainerItemCooldown or GetContainerItemCooldown

local win, holders, buttons = nil, {}, {}
local curTab, query = "all", ""
-- 새로 들어온 아이템 (C안): 아이템 번호별 개수가 늘면 "새로", 가방 맨 위 따로 한 줄에 모아요
local baseCount        -- itemID → 개수 (마지막으로 본 것)
local newIDs = {}      -- itemID → true (새로 들어옴)
local seenIDs = {}     -- itemID → true (마우스를 올려서 분홍 점은 지움)
local Layout
local openedBy

local TABS_DEF = {
    { key = "all",   label = "전부" },
    { key = "equip", label = "장비" },
    { key = "use",   label = "소모품" },
    { key = "mat",   label = "재료" },
    { key = "quest", label = "퀘스트" },
    { key = "gray",  label = "회색템" },
}

-- 아이템 분류 (classID: 0 소모품, 2 무기, 4 방어구, 5 시약, 7 직업용품(약초·가죽·천·광석), 12 퀘스트)
local function Matches(info)
    if not info then return curTab == "all" and query == "" end
    local ok = true
    if curTab ~= "all" then
        local _, _, q, _, _, _, _, _, _, _, _, classID = GetItemInfo(info.hyperlink or info.itemID or "")
        q = info.quality or q
        if curTab == "equip" then ok = classID == 2 or classID == 4
        elseif curTab == "use" then ok = classID == 0
        elseif curTab == "mat" then ok = classID == 7 or classID == 5
        elseif curTab == "quest" then ok = classID == 12 or (info.isQuestItem == true)
        elseif curTab == "gray" then ok = q == 0 end
    end
    if ok and query ~= "" then
        local name = info.itemName or (GetItemInfo(info.hyperlink or info.itemID or ""))
        ok = name and name:lower():find(query, 1, true) and true or false
    end
    return ok
end

local function MakeButton(bag, slot)
    local holder = holders[bag]
    local name = "LeelUI_Bag" .. bag .. "Slot" .. slot
    local ok, b = pcall(CreateFrame, "ItemButton", name, holder, "ContainerFrameItemButtonTemplate")
    if not ok or not b then b = CreateFrame("Button", name, holder, "ContainerFrameItemButtonTemplate") end
    b:SetID(slot)
    -- 가방 번호는 부모(holder)의 SetID로만 알려줌.
    -- b.bagID 같은 값을 애드온이 직접 넣으면 '오염'돼서, 펫 먹이 주기처럼 주문으로 아이템을 고를 때
    -- 게임이 사용을 막아요 (LeelUI가 지원하는 기능이 차단되었습니다).
    b:SetSize(SZ, SZ)
    -- 게임 칸 테두리 숨기고 둥근 칸
    local nt = b.GetNormalTexture and b:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    local slotBg = CreateFrame("Frame", nil, b)
    slotBg:SetPoint("TOPLEFT", -2, 2); slotBg:SetPoint("BOTTOMRIGHT", 2, -2)
    slotBg:SetFrameLevel(math.max(0, b:GetFrameLevel() - 1))
    b.leelBg = ns.RoundRect(slotBg, 7, { 0.24, 0.19, 0.18 }, "BACKGROUND", 0, 0)
    b.leelEdge = slotBg
    -- 새 아이템 분홍 점 (마우스를 올리면 지워져요)
    local dotF = CreateFrame("Frame", nil, b)
    dotF:SetSize(11, 11); dotF:SetPoint("CENTER", b, "TOPRIGHT", -2, -2)
    dotF:SetFrameLevel(b:GetFrameLevel() + 6)
    local ring = dotF:CreateTexture(nil, "ARTWORK"); ring:SetTexture(ns.MEDIA .. "circle"); ring:SetAllPoints(); ring:SetVertexColor(0.125, 0.094, 0.086, 1)
    local dot = dotF:CreateTexture(nil, "OVERLAY"); dot:SetTexture(ns.MEDIA .. "circle"); dot:SetPoint("TOPLEFT", 2, -2); dot:SetPoint("BOTTOMRIGHT", -2, 2)
    dot:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    dotF:Hide()
    b.leelNew = dotF
    b:HookScript("OnEnter", function(self)
        local id = self.leelItemID
        if id and newIDs[id] and not seenIDs[id] then
            seenIDs[id] = true
            for _, bb in pairs(buttons) do for _, x in pairs(bb) do if x.leelItemID == id then x.leelNew:Hide() end end end
        end
    end)
    buttons[bag] = buttons[bag] or {}
    buttons[bag][slot] = b
    return b
end

-- 퀘스트 표시: 시작 아이템 = 노란 테 + 오른쪽 위 노란 "!" / 이미 받은 퀘의 수집품 = 얇은 노란 테
local QuestInfo = CC.GetContainerItemQuestInfo or GetContainerItemQuestInfo
local function QuestMark(b)
    if b.leelQ then return b.leelQ end
    local q = CreateFrame("Frame", nil, b)
    q:SetAllPoints()
    q:SetFrameLevel(b:GetFrameLevel() + 4)
    q.edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = q:CreateTexture(nil, "OVERLAY")
        e:SetColorTexture(1, 0.82, 0, 1)
        if side == "TOP" or side == "BOTTOM" then
            e:SetPoint(side .. "LEFT", -1, side == "TOP" and 1 or -1); e:SetPoint(side .. "RIGHT", 1, side == "TOP" and 1 or -1)
        else
            e:SetPoint("TOP" .. side, side == "LEFT" and -1 or 1, 1); e:SetPoint("BOTTOM" .. side, side == "LEFT" and -1 or 1, -1)
        end
        q.edges[#q.edges + 1] = e
    end
    q.bang = CreateFrame("Frame", nil, q)
    q.bang:SetSize(17, 17)
    q.bang:SetPoint("CENTER", b, "TOPRIGHT", -2, -2)
    local ring = q.bang:CreateTexture(nil, "ARTWORK"); ring:SetTexture(ns.MEDIA .. "circle"); ring:SetAllPoints()
    ring:SetVertexColor(0.11, 0.08, 0.07, 1)
    local dot = q.bang:CreateTexture(nil, "ARTWORK", nil, 1); dot:SetTexture(ns.MEDIA .. "circle")
    dot:SetPoint("TOPLEFT", 2, -2); dot:SetPoint("BOTTOMRIGHT", -2, 2)
    dot:SetVertexColor(1, 0.82, 0, 1)
    local fs = q.bang:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.NUM or ns.FONT, 12, ""); fs:SetText("!")
    fs:SetTextColor(0.23, 0.11, 0.14); fs:SetPoint("CENTER", 0.5, 0)
    b.leelQ = q
    return q
end

-- 툴팁에 "퀘스트 시작 아이템" 줄이 있는지 (API가 questID를 안 줄 때 대비). 아이템 번호별로 기억
local startsCache = {}
local STARTS = _G.ITEM_STARTS_QUEST or "퀘스트 시작 아이템"
local function TipStartsQuest(bag, slot, id)
    if id and startsCache[id] ~= nil then return startsCache[id] end
    local TI = C_TooltipInfo
    if not (TI and TI.GetBagItem) then return false end
    local ok, data = pcall(TI.GetBagItem, bag, slot)
    if not (ok and type(data) == "table" and data.lines) then return false end
    local found = false
    for _, line in ipairs(data.lines) do
        if line.leftText == nil and TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, line) end
        local t = line.leftText
        if type(t) == "string" and (t == STARTS or t:find(STARTS, 1, true)) then found = true break end
    end
    if id then startsCache[id] = found end
    return found
end

local function UpdateQuest(b, bag, slot, info)
    local isQuest, starter = false, false
    if info then
        local qid, active
        if QuestInfo then
            local ok, a, q2, act = pcall(QuestInfo, bag, slot)
            if ok then
                if type(a) == "table" then a, q2, act = a.isQuestItem, a.questID, a.isActive end
                isQuest = a and true or false
                qid, active = q2, act
            end
        end
        if qid then
            -- 퀘스트 목록에 진짜 있는지는 퀘스트 로그에 직접 물어봄 (가방 API 값보다 정확)
            local QL = C_QuestLog
            if QL and QL.IsOnQuest then
                local ok, on = pcall(QL.IsOnQuest, qid)
                if ok and on ~= nil then active = on end
            end
            starter = not active
            if active then isQuest = true end  -- 이미 받은 퀘의 시작 아이템 = 얇은 테
        else
            starter = TipStartsQuest(bag, slot, info.itemID)
        end
    end
    if not (isQuest or starter) then
        if b.leelQ then b.leelQ:Hide() end
        return
    end
    local q = QuestMark(b)
    local w = starter and 2 or 1
    for i, e in ipairs(q.edges) do
        if i <= 2 then e:SetHeight(w) else e:SetWidth(w) end
        e:SetAlpha(starter and 1 or 0.7)
    end
    q.bang:SetShown(starter)
    q:Show()
end

local function UpdateButton(b, bag, slot)
    local info = GetInfo(bag, slot)
    SetItemButtonTexture(b, info and info.iconFileID)
    SetItemButtonCount(b, info and info.stackCount or 0)
    if SetItemButtonDesaturated then SetItemButtonDesaturated(b, info and info.isLocked) end
    if SetItemButtonQuality then
        pcall(SetItemButtonQuality, b, info and info.quality, info and info.hyperlink)
    end
    local cd = b.Cooldown or _G[b:GetName() .. "Cooldown"]
    if cd and GetCooldown then
        local s, d, e = GetCooldown(bag, slot)
        if CooldownFrame_Set then CooldownFrame_Set(cd, s or 0, d or 0, e) end
    end
    b.hasItem = info and true or nil
    b.leelItemID = info and info.itemID or nil
    if b.leelNew then b.leelNew:SetShown(b.leelItemID and newIDs[b.leelItemID] and not seenIDs[b.leelItemID] and true or false) end
    UpdateQuest(b, bag, slot, info)
    -- 게임 가방이 평소에 꺼 주는 표시들: 우리가 안 끄면 처음부터 파랗게 빛남 (새 아이템 빛, 상점 빛 등)
    for _, k in ipairs({ "NewItemTexture", "BattlepayItemTexture", "ExtendedSlot", "JunkIcon", "UpgradeIcon", "BagIndicator" }) do
        local t = b[k]
        if t and t.Hide then t:Hide() end
    end
    for _, k in ipairs({ "flashAnim", "newitemglowAnim" }) do
        local a = b[k]
        if a and a.Stop then a:Stop() end
    end
    if not info and b.IconBorder then b.IconBorder:Hide() end
    if not info and b.IconOverlay then b.IconOverlay:Hide() end
    -- 빈 칸은 조금 더 어둡게, 회색템은 회색 테
    local q = info and info.quality
    if not info then
        b.leelBg:SetColor({ 0.20, 0.16, 0.15 }, 1)
    elseif q == 0 then
        b.leelBg:SetColor({ 0.42, 0.40, 0.39 }, 1)
    else
        b.leelBg:SetColor({ 0.24, 0.19, 0.18 }, 1)
    end
    b:SetAlpha(Matches(info) and 1 or 0.22)
end

Layout = function()
    if not win then return end
    if InCombatLockdown() then win.needLayout = true return end
    local fresh, rest = {}, {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local n = NumSlots(bag) or 0
        for slot = 1, n do
            local b = (buttons[bag] and buttons[bag][slot]) or MakeButton(bag, slot)
            local info = GetInfo(bag, slot)
            local id = info and info.itemID
            if id and newIDs[id] then fresh[#fresh + 1] = b else rest[#rest + 1] = b end
            b:Show()
        end
        for slot = n + 1, #(buttons[bag] or {}) do buttons[bag][slot]:Hide() end
    end
    local y = HEAD + TABS + 6
    local function Place(list)
        for i, b in ipairs(list) do
            local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", win, "TOPLEFT", PAD + 2 + col * (SZ + GAP), -(y + row * (SZ + GAP)))
        end
        y = y + math.max(1, math.ceil(#list / COLS)) * (SZ + GAP) - GAP
    end
    if #fresh > 0 then
        win.newLabel:ClearAllPoints(); win.newLabel:SetPoint("TOPLEFT", win, "TOPLEFT", PAD + 2, -y); win.newLabel:Show()
        win.newHint:Show()
        y = y + 18
        Place(fresh)
        y = y + 8
        win.restLabel:ClearAllPoints(); win.restLabel:SetPoint("TOPLEFT", win, "TOPLEFT", PAD + 2, -y); win.restLabel:Show()
        y = y + 18
    else
        win.newLabel:Hide(); win.newHint:Hide(); win.restLabel:Hide()
    end
    Place(rest)
    win:SetSize(PAD * 2 + 4 + COLS * (SZ + GAP) - GAP, y + 10 + FOOT)
    win.needLayout = false
end

-- 아이템 번호별 개수를 세서, 늘어난 것을 "새로"로
local function CountItems()
    local t = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (NumSlots(bag) or 0) do
            local info = GetInfo(bag, slot)
            if info and info.itemID then t[info.itemID] = (t[info.itemID] or 0) + (info.stackCount or 1) end
        end
    end
    return t
end
local function CheckNew()
    local now = CountItems()
    local changed = false
    if baseCount then
        for id, n in pairs(now) do
            if n > (baseCount[id] or 0) and not newIDs[id] then newIDs[id] = true; seenIDs[id] = nil; changed = true end
        end
    end
    -- 다 쓰거나 판 것은 새 목록에서도 빼요
    for id in pairs(newIDs) do if not now[id] then newIDs[id] = nil; seenIDs[id] = nil; changed = true end end
    baseCount = now
    if changed and win and win:IsShown() then Layout() end
    if changed and win and not win:IsShown() then win.needLayout = true end
end
local function ClearNew()
    if not next(newIDs) then return end
    newIDs, seenIDs = {}, {}
    if win then Layout() end
end

local function Refresh()
    if not win or not win:IsShown() then return end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (NumSlots(bag) or 0) do
            local b = buttons[bag] and buttons[bag][slot]
            if b then UpdateButton(b, bag, slot) end
        end
    end
    local free, total = Count()
    local low = free <= (DB().low or 3)
    win.free:SetText("남은 칸 " .. (low and "|cffff8fa3" or "|cfff6ece8") .. free .. "|r / " .. total)
    win.money:SetText(BunnyMoney(GetMoney()))
    -- 회색템 개수
    local gray = 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (NumSlots(bag) or 0) do
            local info = GetInfo(bag, slot)
            if info and info.quality == 0 then gray = gray + 1 end
        end
    end
    for _, p in ipairs(win.tabs) do
        local on = p.key == curTab
        p.fill:SetColor(on and C.acc or { 1, 1, 1 }, on and 1 or 0.08)
        local tc = on and C.ink or C.tx
        p.fs:SetTextColor(tc[1], tc[2], tc[3]); p.fs:SetShadowColor(0, 0, 0, on and 0 or 0.85)
        p.fs:SetText(p.key == "gray" and gray > 0 and (p.label .. " " .. gray) or p.label)
        p:SetWidth(p.fs:GetStringWidth() + 22)
    end
    local x = PAD
    for _, p in ipairs(win.tabs) do p:ClearAllPoints(); p:SetPoint("TOPLEFT", win, "TOPLEFT", x, -HEAD - 2); x = x + p:GetWidth() + 5 end
end

local function Pill(parent, text, primary, w)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 60, 24)
    b.fill = ns.RoundRect(b, 12, primary and C.acc or { 1, 1, 1 }, "BACKGROUND", 0, 0)
    if not primary then b.fill:SetColor({ 1, 1, 1 }, 0.08) end
    b.fs = ns.Font(b, 12, primary and C.ink or C.tx)
    if primary then b.fs:SetShadowColor(0, 0, 0, 0) end
    b.fs:SetPoint("CENTER", 0, 0); b.fs:SetText(text)
    b:SetScript("OnEnter", function(self) if primary then self.fill:SetColor(C.accHi, 1) else self.fill:SetColor({ 1, 1, 1 }, 0.16) end end)
    b:SetScript("OnLeave", function(self) if primary then self.fill:SetColor(C.acc, 1) else self.fill:SetColor({ 1, 1, 1 }, 0.08) end end)
    return b
end

local function BuildWindow()
    win = CreateFrame("Frame", "LeelUI_Bag", UIParent)
    win:SetFrameStrata("MEDIUM")
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        DB().winPos = { p, rp, x, y }
    end)
    tinsert(UISpecialFrames, "LeelUI_Bag")
    ns.RoundPlate(win, 18, { 0.125, 0.094, 0.086, 0.97 }, { 0.949, 0.702, 0.761, 0.6 })

    -- 머리: 가방 동그라미 + 르엘 가방 + 남은 칸 + 닫기
    local disc = win:CreateTexture(nil, "ARTWORK")
    disc:SetTexture(ns.MEDIA .. "circle"); disc:SetSize(26, 26); disc:SetPoint("TOPLEFT", PAD, -7)
    disc:SetVertexColor(0.23, 0.18, 0.17, 1)
    local ic = win:CreateTexture(nil, "OVERLAY")
    ic:SetTexture(ns.MEDIA .. "bag_bunny"); ic:SetSize(26, 26); ic:SetPoint("CENTER", disc, "CENTER", 0, 2)
    local title = ns.Font(win, 15)
    title:SetText("|cfff2b3c2르엘|r 가방"); title:SetPoint("LEFT", disc, "RIGHT", 8, 0)
    local close = CreateFrame("Button", nil, win)
    close:SetSize(24, 24); close:SetPoint("TOPRIGHT", -10, -8)
    local cbg = close:CreateTexture(nil, "ARTWORK"); cbg:SetTexture(ns.MEDIA .. "circle"); cbg:SetAllPoints()
    cbg:SetVertexColor(0.23, 0.18, 0.17, 1)
    local cx = close:CreateTexture(nil, "OVERLAY"); cx:SetTexture(ns.MEDIA .. "hb_x"); cx:SetSize(14, 14); cx:SetPoint("CENTER")
    close:SetScript("OnClick", function() win:Hide() end)
    close:SetScript("OnEnter", function() cbg:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1); cx:SetVertexColor(C.ink[1], C.ink[2], C.ink[3]) end)
    close:SetScript("OnLeave", function() cbg:SetVertexColor(0.23, 0.18, 0.17, 1); cx:SetVertexColor(1, 1, 1) end)
    win.free = ns.Font(win, 12)
    win.free:SetPoint("RIGHT", close, "LEFT", -10, 0)

    -- 분류 알약
    win.tabs = {}
    for _, t in ipairs(TABS_DEF) do
        local p = Pill(win, t.label, false)
        p.key, p.label = t.key, t.label
        p:SetScript("OnClick", function() curTab = t.key; Refresh() end)
        p:SetScript("OnLeave", function() Refresh() end)
        win.tabs[#win.tabs + 1] = p
    end

    -- 새로 들어온 것 줄 머리
    win.newLabel = ns.Font(win, 12, C.acc); win.newLabel:SetText("새로 들어온 것")
    win.newHint = ns.Font(win, 10.5, { 0.62, 0.54, 0.52 }); win.newHint:SetText("가방을 닫으면 제자리로")
    win.newHint:SetPoint("LEFT", win.newLabel, "RIGHT", 8, -1)
    win.restLabel = ns.Font(win, 12, { 0.81, 0.635, 0.616 }); win.restLabel:SetText("가방")
    win.newLabel:Hide(); win.newHint:Hide(); win.restLabel:Hide()

    -- 아래: 정리, 찾기, 돈
    local Sort = CC.SortBags or SortBags
    local sort = Pill(win, "정리", true, 58)
    sort:SetPoint("BOTTOMLEFT", PAD, 10)
    sort:SetScript("OnClick", function()
        if InCombatLockdown() then ns.Print("전투 중에는 정리할 수 없어요.") return end
        if Sort then Sort() end
    end)
    sort:SetShown(Sort ~= nil)

    local box = CreateFrame("EditBox", "LeelUI_BagSearch", win)
    box:SetSize(150, 24)
    box:SetPoint("LEFT", sort, "RIGHT", 6, 0)
    if not Sort then box:SetPoint("BOTTOMLEFT", PAD, 10) end
    box:SetAutoFocus(false)
    box:SetFont(ns.FONT, 12, "")
    box:SetTextInsets(28, 10, 0, 0)
    box:SetMaxLetters(40)
    box.bg = ns.RoundRect(box, 12, { 1, 1, 1 }, "BACKGROUND", 0, 0)
    box.bg:SetColor({ 1, 1, 1 }, 0.08)
    local mag = box:CreateTexture(nil, "ARTWORK")
    mag:SetTexture(ns.MEDIA .. "hb_search"); mag:SetSize(13, 13); mag:SetPoint("LEFT", 10, 0)
    mag:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    box.ph = box:CreateFontString(nil, "ARTWORK"); box.ph:SetFont(ns.FONT, 12, "")
    box.ph:SetTextColor(0.62, 0.54, 0.52); box.ph:SetPoint("LEFT", 28, 0); box.ph:SetText("찾기")
    box:SetScript("OnTextChanged", function(self)
        local t = self:GetText() or ""
        self.ph:SetShown(t == "")
        query = t:lower()
        Refresh()
    end)
    box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self) self.bg:SetColor({ 1, 1, 1 }, 0.16) end)
    box:SetScript("OnEditFocusLost", function(self) self.bg:SetColor({ 1, 1, 1 }, 0.08) end)
    win.box = box

    win.money = ns.Font(win, 12)
    if ns.NUM then win.money:SetFont(ns.NUM, 15, "") end
    win.money:SetPoint("BOTTOMRIGHT", -PAD - 2, 15)

    -- 가방마다 보이지 않는 자리 (아이템 칸이 어느 가방인지 알게)
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local h = CreateFrame("Frame", "LeelUI_BagHolder" .. bag, win)
        h:SetID(bag)
        h:SetAllPoints()
        -- 게임 아이템 칸 코드가 부모에게 묻는 것들
        h.GetBagID = function(self) return self:GetID() end
        h.IsCombinedBagContainer = function() return false end
        h.IsBankBag = function() return false end
        holders[bag] = h
    end

    local function Place()
        local p = DB().winPos
        win:ClearAllPoints()
        if p then win:SetPoint(p[1], UIParent, p[2], p[3], p[4])
        else win:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 110) end
    end
    win.Place = Place
    Place()
    win:SetScript("OnShow", function() if win.needLayout then Layout() end; Refresh(); PlaySound(SOUNDKIT and SOUNDKIT.IG_BACKPACK_OPEN or 862) end)
    win:SetScript("OnHide", function()
        openedBy = nil
        if not DB().keepNew then ClearNew() end
        win.box:SetText(""); win.box:ClearFocus()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_BACKPACK_CLOSE or 863)
    end)
    Layout()
    win:Hide()
end

----------------------------------------------------------------------
-- 게임 가방 대신 열기
----------------------------------------------------------------------
local function UseLeelBag() return ns.db and true or false end -- 통합 가방은 항상

local function OpenBag(frame) if not win then return end; if frame and not win:IsShown() then openedBy = frame end; win:Show() end
local function CloseBag(frame) if win and (not frame or frame == openedBy or not openedBy) then win:Hide() end end
local function ToggleBag() if win then win:SetShown(not win:IsShown()) end end
ns.ToggleLeelBag = ToggleBag

local function TakeOver()
    -- 게임 가방 창은 열려도 바로 닫고, 여닫는 함수는 르엘 가방으로
    local function Silence(f)
        if f and not f.leelSilenced then
            f.leelSilenced = true
            f:HookScript("OnShow", function(self) if UseLeelBag() then self:Hide() end end)
        end
    end
    Silence(_G.ContainerFrameCombinedBags)
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do Silence(_G["ContainerFrame" .. i]) end

    -- 게임 함수를 바꿔치기하면 ESC(전투 중 지도/창 닫기) 같은 게임 보호 동작이 막힘
    -- → 게임 함수는 그대로 두고, 불린 "뒤에" 르엘 가방만 따라 열고 닫음 (같은 순간 여러 번 불려도 한 번만)
    local want = {}
    local function Settle()
        local w = want; want = {}
        if not UseLeelBag() or not win then return end
        -- 토글(B 키, 가방 버튼)이 먼저: 게임 함수가 안에서 여는 함수들을 또 불러도 무시
        if w.toggle then ToggleBag()
        elseif w.close and not w.open then CloseBag(w.closeFrame)
        elseif w.open then OpenBag(w.openFrame) end
    end
    local function Ask(kind, frame)
        if not next(want) then C_Timer.After(0, Settle) end
        want[kind] = true
        if kind == "open" and frame then want.openFrame = frame end
        if kind == "close" and frame then want.closeFrame = frame end
    end
    local function Hook(name, fn) if _G[name] then hooksecurefunc(name, fn) end end
    Hook("ToggleAllBags", function() Ask("toggle") end)
    Hook("ToggleBackpack", function() Ask("toggle") end)
    Hook("OpenAllBags", function(frame) Ask("open", frame) end)
    Hook("OpenBackpack", function() Ask("open") end)
    Hook("CloseAllBags", function(frame) Ask("close", frame) end)
    Hook("CloseBackpack", function() Ask("close") end)
    Hook("ToggleBag", function(id) if not id or id <= (NUM_BAG_SLOTS or 4) then Ask("toggle") end end)
    Hook("OpenBag", function(id) if not id or id <= (NUM_BAG_SLOTS or 4) then Ask("open") end end)
end

----------------------------------------------------------------------
local wasLow, wasFull, ready = false, false, false
local function Update()
    if not ns.db then return end
    local d = DB()
    local free, total = Count()
    local low = free <= (d.low or 3)

    if chip then
        local show = d.on and d.chip and total > 0
        chip:SetShown(show)
        chip.num:SetText(free)
        chip.tot:SetText(low and "칸 남음" or ("/ " .. total))
        chip.warn = show and low
        local c = low and { 1, 0.56, 0.64 } or { 0.23, 0.18, 0.17 }
        chip.disc:SetVertexColor(c[1], c[2], c[3], 1)
        if not low then chip.edge:SetColor({ 0.949, 0.702, 0.761 }, 0.6) end
        local nc = low and { 1, 0.56, 0.64 } or C.tx
        chip.num:SetTextColor(nc[1], nc[2], nc[3])
        chip:SetWidth(math.max(70, 40 + chip.num:GetStringWidth() + chip.tot:GetStringWidth()))
    end

    -- 넘어가는 순간에 한 번만 알림
    local full = total > 0 and free == 0
    -- 꽉 차는 순간 (거의 참 알림이 이미 지나간 뒤라도) 버릴 템 고르기 창
    if ready and d.on and full and not wasFull then
        if not (d.full ~= false and ns.ShowBagFull and ns.ShowBagFull()) and d.warn and ns.PillToast then
            ns.PillToast("가방이 꽉 찼어요", "hb_bag", true)
        end
    elseif ready and d.on and low and not wasLow and not full and total > 0 and d.warn and ns.PillToast then
        ns.PillToast("가방이 거의 찼어요. 남은 칸 " .. free, "hb_bag", true)
    end
    if ready then wasFull = full end  -- 접속/다시 불러오기 때 이미 꽉 차 있어도 한 번은 뜨게
    if free > 0 and ns.HideBagFull then ns.HideBagFull() end
    wasLow = low
    ready = true

    CheckNew()
    Refresh()
end
ns.UpdateBags = Update

local pending
local function Soon()
    if pending then return end
    pending = true
    C_Timer.After(0.05, function() pending = false; Update() end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_MONEY")
ev:RegisterEvent("BAG_UPDATE")
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "BAG_CONTAINER_UPDATE",
                     "GET_ITEM_INFO_RECEIVED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        DB()
        -- BuildChip()  -- 미니맵 아래 숫자: 다른 기능과 겹쳐서 뺐어요
        if DB().skin then
            BuildWindow()
            TakeOver()
        end
        C_Timer.After(1, Update)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if win and win.needLayout then Layout(); Refresh() end
    elseif event == "BAG_CONTAINER_UPDATE" then
        if win then Layout() end
        Soon()
    else
        if event == "BAG_UPDATE" and win then
            -- 가방을 새로 끼우면 칸 수가 바뀜
            local need = false
            for bag = 0, (NUM_BAG_SLOTS or 4) do
                local n = NumSlots(bag) or 0
                local have = 0
                for slot = 1, n do if buttons[bag] and buttons[bag][slot] and buttons[bag][slot]:IsShown() then have = have + 1 end end
                if have ~= n then need = true end
            end
            if need then Layout() end
        end
        Soon()
    end
end)


-- 진단: /르엘퀘  가방의 퀘스트 관련 템을 채팅창에 찍기
SLASH_LEELQDUMP1 = "/르엘퀘"
SLASH_LEELQDUMP2 = "/leelq"
SlashCmdList.LEELQDUMP = function()
    print("|cfff2b3c2[르엘 가방]|r 퀘스트 템 점검")
    local n = 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (NumSlots(bag) or 0) do
            local info = CC.GetContainerItemInfo and CC.GetContainerItemInfo(bag, slot)
            if info then
                local a, qid, act
                if QuestInfo then
                    local ok, x, y, z = pcall(QuestInfo, bag, slot)
                    if ok then
                        if type(x) == "table" then a, qid, act = x.isQuestItem, x.questID, x.isActive else a, qid, act = x, y, z end
                    end
                end
                local onq = qid and C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(qid)
                local done = qid and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(qid)
                startsCache[info.itemID or 0] = nil
                local tip = TipStartsQuest(bag, slot, nil)
                if a or qid or tip then
                    n = n + 1
                    print(string.format("%s  퀘템=%s 퀘번호=%s 받음=%s 툴팁시작=%s",
                        info.hyperlink or "?", tostring(a), tostring(qid), tostring(act), tostring(tip)))
                    if qid then print(string.format("   └ 퀘스트로그에있음=%s 완료한적=%s", tostring(onq), tostring(done))) end
                end
            end
        end
    end
    print("총 " .. n .. "개")
end


----------------------------------------------------------------------
-- 가방이 꽉 찼을 때: 제일 싼 템 3개 + 각각 버리기 버튼
-- (팔 값 = 개당 값 × 개수. 퀘스트 템, 값 0, 안 팔기 목록, 희귀 이상은 빼요)
----------------------------------------------------------------------
local full, fullPending, lastFullAt = nil, false, 0
local fullOfs, fullList = 0, nil  -- 다른 템 보기: 3개씩 넘기기
local keepOpen = false  -- 한 번 버리기 시작하면 닫기 전까지 창 유지 (다음 후보로 채움)

local function Candidates()
    local list = {}
    local keep = (ns.ShopDB and ns.ShopDB().keep) or {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (NumSlots(bag) or 0) do
            local info = GetInfo(bag, slot)
            if info and info.hyperlink and not info.hasNoValue and (info.quality or 9) <= 2 and not keep[info.itemID or 0] then
                local quest = false
                if QuestInfo then
                    local ok, a, qid = pcall(QuestInfo, bag, slot)
                    if ok then
                        if type(a) == "table" then a, qid = a.isQuestItem, a.questID end
                        quest = (a or qid) and true or false
                    end
                end
                if not quest then
                    local ok, name, _, _, _, _, _, _, _, _, _, price = pcall(GetItemInfo, info.hyperlink)
                    if ok and price and price > 0 then
                        list[#list + 1] = { bag = bag, slot = slot, link = info.hyperlink, name = name or "", id = info.itemID,
                            icon = info.iconFileID, count = info.stackCount or 1, quality = info.quality or 1,
                            value = price * (info.stackCount or 1) }
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.value < b.value end)
    return list
end

local CARD_W, CARD_GAP, FPAD = 104, 8, 12
local function BuildFull()
    local f = CreateFrame("Frame", "LeelUI_BagFull", UIParent)
    f:SetFrameStrata("DIALOG")
    f:SetPoint("TOP", UIParent, "TOP", 0, -130)
    f:SetSize(3 * CARD_W + 2 * CARD_GAP + FPAD * 2, 226)
    f:EnableMouse(true)
    f:SetMovable(true); f:RegisterForDrag("LeftButton"); f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    ns.RoundPlate(f, 16, { 0.125, 0.094, 0.086, 0.98 }, { 1, 0.56, 0.64, 0.9 })

    local disc = f:CreateTexture(nil, "ARTWORK")
    disc:SetTexture(ns.MEDIA .. "circle"); disc:SetSize(22, 22); disc:SetPoint("TOPLEFT", 12, -10)
    disc:SetVertexColor(1, 0.56, 0.64, 1)
    local ic = f:CreateTexture(nil, "OVERLAY")
    ic:SetTexture(ns.MEDIA .. "ic_trash"); ic:SetSize(15, 15); ic:SetPoint("CENTER", disc, "CENTER", 0, 0.5)
    ic:SetVertexColor(C.ink[1], C.ink[2], C.ink[3], 1)
    local title = ns.Font(f, 13, C.accHi)
    title:SetPoint("LEFT", disc, "RIGHT", 8, 0)
    title:SetText("가방이 꽉 찼어요 · 버릴 걸 골라요")
    f.title = title
    f.binDisc, f.binIc = disc, ic

    local x = CreateFrame("Button", nil, f)
    x:SetSize(20, 20); x:SetPoint("TOPRIGHT", -10, -11)
    local xt = x:CreateTexture(nil, "ARTWORK"); xt:SetTexture(ns.MEDIA .. "hb_x"); xt:SetAllPoints()
    xt:SetVertexColor(C.tx[1], C.tx[2], C.tx[3], 0.7)
    x:SetScript("OnEnter", function() xt:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1) end)
    x:SetScript("OnLeave", function() xt:SetVertexColor(C.tx[1], C.tx[2], C.tx[3], 0.7) end)
    x:SetScript("OnClick", function() f:Hide() end)
    f:SetScript("OnHide", function() keepOpen = false end)

    f.cards = {}
    for i = 1, 3 do
        local c = CreateFrame("Frame", nil, f)
        c:SetSize(CARD_W, 148)
        c:SetPoint("TOPLEFT", FPAD + (i - 1) * (CARD_W + CARD_GAP), -40)
        c.bg = ns.RoundRect(c, 12, { 1, 1, 1 }, "BACKGROUND", 2, 0); c.bg:SetColor({ 0.949, 0.702, 0.761 }, 0.06)

        local btn = CreateFrame("Button", nil, c)
        btn:SetSize(42, 42); btn:SetPoint("TOP", 0, -10)
        c.btn = btn
        c.edge = btn:CreateTexture(nil, "BACKGROUND"); c.edge:SetPoint("TOPLEFT", -1, 1); c.edge:SetPoint("BOTTOMRIGHT", 1, -1)
        c.icon = btn:CreateTexture(nil, "ARTWORK"); c.icon:SetAllPoints(); c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        c.count = btn:CreateFontString(nil, "OVERLAY")
        c.count:SetFont(ns.NUM or ns.FONT, 14, "OUTLINE"); c.count:SetPoint("BOTTOMRIGHT", -1, 1)
        btn:SetScript("OnEnter", function(self)
            if not c.data then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetBagItem, GameTooltip, c.data.bag, c.data.slot)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        c.val = c:CreateFontString(nil, "OVERLAY")
        c.val:SetFont(ns.NUM or ns.FONT, 13, ""); c.val:SetPoint("TOP", btn, "BOTTOM", 0, -6)
        c.val:SetTextColor(0.97, 0.76, 0.6)
        c.name = ns.Font(c, 11)
        c.name:SetPoint("TOP", c.val, "BOTTOM", 0, -4); c.name:SetWidth(CARD_W - 10); c.name:SetWordWrap(false)

        -- 오른쪽 위 자물쇠: 잠그면 버리기 후보 · 상점 토끼 자동 판매에서 빠져요 (상점 토끼 "안 팔기" 목록과 같은 목록)
        local lk = CreateFrame("Button", nil, c)
        lk:SetSize(24, 24); lk:SetPoint("TOPRIGHT", -4, -4)
        lk.bg = lk:CreateTexture(nil, "BACKGROUND"); lk.bg:SetTexture(ns.MEDIA .. "circle"); lk.bg:SetAllPoints()
        lk.ring = lk:CreateTexture(nil, "BORDER"); lk.ring:SetTexture(ns.MEDIA .. "mring")
        lk.ring:SetPoint("TOPLEFT", -1.5, 1.5); lk.ring:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
        lk.ic = lk:CreateTexture(nil, "ARTWORK"); lk.ic:SetSize(15, 15); lk.ic:SetPoint("CENTER", 0, 0.5)
        -- 평소: 반투명 어두운 동그라미 + 분홍 열린 자물쇠 / 올림: 꽉 찬 분홍 / 누름: 닫힌 자물쇠 + 흰 테
        function lk:Paint(state)
            local A = C.acc
            if state == "locked" then
                self.bg:SetVertexColor(A[1], A[2], A[3], 1); self.ring:SetVertexColor(1, 1, 1, 1)
                self.ic:SetTexture(ns.MEDIA .. "ic_lock"); self.ic:SetVertexColor(C.ink[1], C.ink[2], C.ink[3], 1)
            elseif state == "hover" then
                self.bg:SetVertexColor(A[1], A[2], A[3], 1); self.ring:SetVertexColor(A[1], A[2], A[3], 1)
                self.ic:SetTexture(ns.MEDIA .. "ic_lock_open"); self.ic:SetVertexColor(C.ink[1], C.ink[2], C.ink[3], 1)
            else
                self.bg:SetVertexColor(0.227, 0.165, 0.157, 0.9); self.ring:SetVertexColor(A[1], A[2], A[3], 0.45)
                self.ic:SetTexture(ns.MEDIA .. "ic_lock_open"); self.ic:SetVertexColor(A[1], A[2], A[3], 1)
            end
        end
        lk:Paint()
        lk:SetScript("OnEnter", function(self)
            self:Paint("hover")
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("잠그기", 1, 0.84, 0.88)
            GameTooltip:AddLine("버리기 후보 · 상점 토끼 자동 판매에서 빠져요", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("풀기: 가방에서 Alt+클릭", 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        lk:SetScript("OnLeave", function(self) self:Paint(); GameTooltip:Hide() end)
        lk:SetScript("OnClick", function(self)
            local d = c.data
            if not (d and d.id and ns.ShopDB) then return end
            ns.ShopDB().keep[d.id] = true
            GameTooltip:Hide()
            -- "찰칵": 닫힌 자물쇠를 잠깐 보여 주고 다음 후보로
            self:Paint("locked")
            c.del:SetLabel("잠갔어요"); c.del:SetEnabled(false)
            if ns.PillToast then ns.PillToast("잠갔어요  " .. d.link, "hb_bag") end
            keepOpen = true
            C_Timer.After(0.45, function()
                self:Paint(); c.del:SetLabel("버리기"); c.del:SetEnabled(true)
                ns.RefillCardInPlace(c)
            end)
        end)
        c.lock = lk

        c.del = ns.MakeButton(c, "버리기", true, nil, 76)
        c.del:SetHeight(24)
        c.del:SetPoint("BOTTOM", 0, 10)
        f.cards[i] = c
    end

    -- 아래 줄: 남은 칸 + 다른 템 보기
    f.slotsL = ns.Font(f, 12)  -- 한글은 한글 글꼴로 (숫자 글꼴엔 한글이 없어요)
    f.slotsL:SetPoint("BOTTOMLEFT", FPAD + 4, 15)
    f.slotsL:SetText("남은 칸"); f.slotsL:SetTextColor(0.85, 0.78, 0.76)
    f.slots = f:CreateFontString(nil, "OVERLAY")
    f.slots:SetFont(ns.NUM or ns.FONT, 13, ""); f.slots:SetPoint("LEFT", f.slotsL, "RIGHT", 6, 0)
    f.more = ns.MakeButton(f, "다른 템 보기", false, nil, 110)
    f.more:SetHeight(22); f.more:SetPoint("BOTTOMRIGHT", -FPAD, 10)
    f.more:SetScript("OnClick", function()
        fullOfs = fullOfs + 3
        if not fullList or fullOfs >= #fullList then fullOfs = 0 end
        ns.ShowBagFull(true)
    end)
    f:Hide()
    full = f
    -- ESC로 닫기
    if UISpecialFrames then tinsert(UISpecialFrames, "LeelUI_BagFull") end
end

-- 버린 템이 제목 앞 휴지통으로 "슝" 날아가고 휴지통이 덜컥 (끝나면 done)
local fly
local function FlyToBin(card, done)
    if not (full and full.binDisc and card and card.icon) then if done then done() end return end
    if not fly then
        fly = CreateFrame("Frame", nil, full)
        fly:SetFrameLevel(full:GetFrameLevel() + 20)
        fly:SetAllPoints(full)
        fly.t = fly:CreateTexture(nil, "OVERLAY")
        fly.t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
    local ix, iy = card.icon:GetCenter()
    local bx, by = full.binDisc:GetCenter()
    local L, B = full:GetLeft(), full:GetBottom()
    if not (ix and bx and L) then if done then done() end return end
    ix, iy, bx, by = ix - L, iy - B, bx - L, by - B
    fly.t:SetTexture(card.icon:GetTexture())
    card.icon:SetAlpha(0); card.count:SetAlpha(0); card.edge:SetAlpha(0)
    card.val:SetAlpha(0.35); card.name:SetAlpha(0.35)
    local mx, my = (ix + bx) / 2, math.max(iy, by) + 30       -- 위로 살짝 휘어서
    local T, el = 0.42, 0
    fly:Show()
    fly:SetScript("OnUpdate", function(self, dt)
        el = el + dt
        local k = math.min(1, el / T)
        local e = k * k * (3 - 2 * k)
        local a, b = (1 - e) * (1 - e), 2 * (1 - e) * e
        local x = a * ix + b * mx + e * e * bx
        local y = a * iy + b * my + e * e * by
        local sz = 42 * (1 - 0.88 * e)
        self.t:SetSize(sz, sz)
        self.t:ClearAllPoints(); self.t:SetPoint("CENTER", self, "BOTTOMLEFT", x, y)
        self.t:SetRotation(-3.5 * e)
        self.t:SetAlpha(1 - 0.4 * e)
        if k >= 1 then
            self:SetScript("OnUpdate", nil); self:Hide()
            -- 휴지통 덜컥
            local sh = 0
            local disc, ic = full.binDisc, full.binIc
            full:SetScript("OnUpdate", function(f2, d2)
                sh = sh + d2
                local q = math.min(1, sh / 0.35)
                local w = math.sin(q * math.pi * 3) * (1 - q)
                ic:SetRotation(w * 0.3)
                local z = 22 * (1 + 0.12 * math.sin(q * math.pi))
                disc:SetSize(z, z)
                if q >= 1 then
                    f2:SetScript("OnUpdate", nil); ic:SetRotation(0); disc:SetSize(22, 22)
                end
            end)
            -- 원래 칸은 비운 채로 두고(옛 템이 다시 보이지 않게) 바로 다음 템으로
            if done then done() end
        end
    end)
end

local function Destroy(d, card)
    local info = GetInfo(d.bag, d.slot)
    if not (info and info.hyperlink == d.link) then
        if ns.ShowBagFull then ns.ShowBagFull(true) end
        return
    end
    ClearCursor()
    local pick = CC.PickupContainerItem or PickupContainerItem
    pick(d.bag, d.slot)
    local gone = false
    if CursorHasItem() then
        DeleteCursorItem()
        gone = true
        if ns.PillToast then ns.PillToast("버렸어요  " .. d.link, "hb_bag") end
        keepOpen = true
    end
    ClearCursor()
    local function Refill()
        if full and full:IsShown() and not ns.ShowBagFull(true) then full:Hide() end
    end
    if gone and card then
        pcall(PlaySoundFile, ns.MEDIA .. "discard.ogg", "SFX")
        FlyToBin(card, function() C_Timer.After(0.05, function() ns.RefillCardInPlace(card) end) end)
    else
        -- 버린 자리에 다음으로 싼 템 채우기
        C_Timer.After(0.25, Refill)
    end
end

local function SlotCount()
    local free, total = 0, 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        total = total + (NumSlots(bag) or 0)
        free = free + ((NumFree and NumFree(bag)) or 0)
    end
    return free, total
end

local function FillCard(c, d)
    c.data = d
    if not d then c:Hide() return end
    c:SetScript("OnUpdate", nil)
    c.btn:ClearAllPoints(); c.btn:SetPoint("TOP", 0, -10)
    for _, r in ipairs({ c.btn, c.icon, c.count, c.edge, c.val, c.name }) do r:SetAlpha(1) end
    c.icon:SetTexture(d.icon)
    c.count:SetText(d.count > 1 and d.count or "")
    local r, g, b = 0.62, 0.62, 0.62
    if GetItemQualityColor then
        local ok, qr, qg, qb = pcall(GetItemQualityColor, d.quality)
        if ok and qr then r, g, b = qr, qg, qb end
    end
    c.edge:SetColorTexture(r, g, b, 1)
    c.val:SetText(BunnyMoney(d.value, 12))
    c.name:SetText(d.name)
    c.name:SetTextColor(r, g, b)
    c.del:SetScript("OnClick", function() Destroy(d, c) end)
    c:Show()
end

local function Footer(list)
    local free, total = SlotCount()
    local fc = free == 0 and "|cffff8fa3" or "|cfff8c39a"
    full.slots:SetText(fc .. free .. "|r|cff9a8a86 / " .. total .. "|r")
    full.title:SetText(free == 0 and "가방이 꽉 찼어요 · 버릴 걸 골라요" or "가방 정리 · 버릴 걸 골라요")
    local pages = math.ceil(#list / 3)
    if pages > 1 then
        full.more:SetLabel("다른 템 보기  " .. (math.floor(fullOfs / 3) + 1) .. "/" .. pages)
        full.more:Show()
    else
        full.more:Hide()
    end
end

local function Fill(list)
    if fullOfs >= #list then fullOfs = 0 end
    local n = math.min(3, #list - fullOfs)
    for i, c in ipairs(full.cards) do FillCard(c, list[fullOfs + i]) end
    full:SetWidth(n * CARD_W + (n - 1) * CARD_GAP + FPAD * 2)
    full:SetWidth(math.max(full:GetWidth(), 290))
    Footer(list)
    return n
end

-- 버리거나 잠근 칸만 다음 템으로 바꿔요 (다른 칸은 그대로) · 새 템은 아래에서 스윽 올라와요
local function Rise(c)
    local el = 0
    c.btn:SetAlpha(0); c.val:SetAlpha(0); c.name:SetAlpha(0)
    c.icon:SetAlpha(1); c.count:SetAlpha(1); c.edge:SetAlpha(1)   -- 날아가며 숨긴 것 되돌리기 (btn이 0이라 안 보임)
    c:SetScript("OnUpdate", function(self, dt)
        el = el + dt
        local k = math.min(1, el / 0.28)
        local e = 1 - (1 - k) * (1 - k)
        self.btn:ClearAllPoints(); self.btn:SetPoint("TOP", 0, -10 - 16 * (1 - e))
        self.btn:SetAlpha(e); self.val:SetAlpha(e); self.name:SetAlpha(e)
        if k >= 1 then self:SetScript("OnUpdate", nil) end
    end)
end
function ns.RefillCardInPlace(card)
    if not (full and full:IsShown() and card) then return end
    local list = Candidates()
    fullList = list
    if #list == 0 then
        card.icon:SetAlpha(1); card.count:SetAlpha(1); card.edge:SetAlpha(1); card.val:SetAlpha(1); card.name:SetAlpha(1)
        full:Hide() return
    end
    local function Key(d) return d and (d.bag .. ":" .. d.slot .. ":" .. tostring(d.link)) end
    local shown, old = {}, Key(card.data)
    for _, c in ipairs(full.cards) do
        if c ~= card and c:IsShown() and c.data then shown[Key(c.data)] = true end
    end
    local pick
    for _, d in ipairs(list) do
        local k = Key(d)
        if not shown[k] and k ~= old then pick = d break end
    end
    if pick then
        FillCard(card, pick)
        Rise(card)
    else
        card:Hide(); card.data = nil
        card.icon:SetAlpha(1); card.count:SetAlpha(1); card.edge:SetAlpha(1)
        local any = false
        for _, c in ipairs(full.cards) do if c:IsShown() then any = true end end
        if not any then full:Hide() return end
    end
    Footer(list)
end

-- force = 다시 그리기만 (이미 떠 있을 때)
function ns.ShowBagFull(force)
    -- 전투 중엔 띄우지 않고(싸우다 가리지 않게) 끝나면 띄워요
    if InCombatLockdown() then fullPending = true return true end
    if not force and GetTime() - lastFullAt < 3 then return full and full:IsShown() end
    local list = Candidates()
    if #list == 0 then return false end
    if not force and not (full and full:IsShown()) then fullOfs = 0 end
    fullList = list
    if not full then BuildFull() end
    Fill(list)
    lastFullAt = GetTime()
    full:Show()
    return true
end

function ns.HideBagFull()
    fullPending = false
    if keepOpen then return end
    if full and full:IsShown() then full:Hide() end
end

local fev = CreateFrame("Frame")
fev:RegisterEvent("PLAYER_REGEN_ENABLED")
fev:RegisterEvent("PLAYER_REGEN_DISABLED")
fev:RegisterEvent("UI_ERROR_MESSAGE")
local hiddenForCombat = false
fev:SetScript("OnEvent", function(_, event, a1, a2)
    if not ns.db or not DB().on or DB().full == false then return end
    if event == "PLAYER_REGEN_DISABLED" then
        -- 떠 있던 창은 전투 동안 숨겼다가, 끝나면 다시 (가방이 아직 꽉 차 있으면)
        if full and full:IsShown() then
            full:Hide()
            hiddenForCombat = true
            fullPending = true
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if fullPending then
            fullPending = false
            local back = hiddenForCombat
            hiddenForCombat = false
            if back then C_Timer.After(0.3, function() if not ns.ShowBagFull(true) then keepOpen = false end end) return end
            local free = 0
            for bag = 0, (NUM_BAG_SLOTS or 4) do free = free + ((NumFree and NumFree(bag)) or 0) end
            if free == 0 then C_Timer.After(0.3, function() ns.ShowBagFull(true) end) end
        end
    else
        -- 꽉 찬 채로 줍다가 '가방이 가득 찼습니다'가 뜨면 다시 보여주기
        local msg = type(a2) == "string" and a2 or a1
        if msg == _G.ERR_INV_FULL or msg == _G.ERR_LOOT_INV_FULL then
            if GetTime() - lastFullAt > 8 then ns.ShowBagFull() end
        end
    end
end)

-- 미리 보기: /르엘버리기  (가방이 안 차 있어도 후보 3개 창 띄우기)
SLASH_LEELBAGFULL1 = "/르엘버리기"
SlashCmdList.LEELBAGFULL = function()
    if not ns.ShowBagFull(true) then print("|cfff2b3c2[르엘 가방]|r 버릴 후보가 없어요.") end
end
