-- LeelUI / Shop.lua
-- 상점 토끼: 상인 창을 열면 회색 잡템 자동 판매 + 장비 자동 수리
-- Shift 누른 채 상인을 열면 이번엔 쉬어요. 가방에서 Alt+클릭 = 안 팔기 목록

local _, ns = ...
local C = ns.C
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo  -- 새 클라이언트는 C_Item 쪽에만 있음

local function Print(msg) if ns.Print then ns.Print(msg) else print("|cfff2b3c2[르엘 UI]|r " .. msg) end end

local function DB()
    ns.db.shop = ns.db.shop or {}
    local d = ns.db.shop
    if d.on == nil then d.on = true end
    if d.repair == nil then d.repair = true end
    if d.sell == nil then d.sell = true end
    if d.report == nil then d.report = true end
    d.keep = d.keep or {}
    return d
end
ns.ShopDB = DB

----------------------------------------------------------------------
-- 가방 API (새/옛 클라이언트 둘 다)
----------------------------------------------------------------------
local CC = C_Container or {}
local NumSlots = CC.GetContainerNumSlots or GetContainerNumSlots
local UseItem = CC.UseContainerItem or UseContainerItem
local ItemLink = CC.GetContainerItemLink or GetContainerItemLink

local function SlotInfo(bag, slot)
    if CC.GetContainerItemInfo then
        local ok, t = pcall(CC.GetContainerItemInfo, bag, slot)
        if ok and type(t) == "table" then
            return t.quality, t.stackCount, t.hyperlink, t.itemID, t.hasNoValue, t.isLocked
        end
        return
    end
    if GetContainerItemInfo then
        local _, count, locked, quality, _, _, link, _, noValue, id = GetContainerItemInfo(bag, slot)
        return quality, count, link, id, noValue, locked
    end
end

local function IDFromLink(link)
    return link and tonumber(link:match("item:(%d+)"))
end

-- 판매가 (게임이 아직 모르면 nil)
local function Price(link)
    if not link then return nil end
    local ok, _, _, q, _, _, _, _, _, _, _, price = pcall(GetItemInfo, link)
    if not ok then return nil end
    return price, q
end

local function Money(c)
    if GetCoinTextureString then return GetCoinTextureString(c) end
    return string.format("%d골 %d은 %d동", c / 10000, (c / 100) % 100, c % 100)
end

local function BAGS() return 0, (NUM_BAG_SLOTS or 4) end

----------------------------------------------------------------------
-- 결과 알림 (상인 창 위에 작은 분홍 판)
----------------------------------------------------------------------
local toast
local function Toast(lines)
    if not toast then
        toast = CreateFrame("Frame", "LeelUI_ShopToast", UIParent)
        toast:SetSize(250, 64)
        toast:SetFrameStrata("HIGH")
        ns.RoundPlate(toast, 14, { 0.125, 0.094, 0.086, 0.96 }, { 0.949, 0.702, 0.761, 0.6 })
        local disc = toast:CreateTexture(nil, "ARTWORK")
        disc:SetTexture(ns.MEDIA .. "circle"); disc:SetSize(30, 30); disc:SetPoint("LEFT", 12, 0)
        disc:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
        local ic = toast:CreateTexture(nil, "OVERLAY")
        ic:SetTexture(ns.MEDIA .. "hb_shop"); ic:SetSize(17, 17); ic:SetPoint("CENTER", disc)
        ic:SetVertexColor(C.ink[1], C.ink[2], C.ink[3], 1)
        toast.title = ns.Font(toast, 13, C.accHi)
        toast.title:SetPoint("TOPLEFT", disc, "TOPRIGHT", 10, 4)
        toast.title:SetText("상점 토끼")
        toast.body = ns.Font(toast, 11.5)
        toast.body:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -4)
        toast.body:SetJustifyH("LEFT")
        toast.body:SetSpacing(3)
        toast:SetScript("OnUpdate", function(self, el)
            self.t = (self.t or 0) + el
            if self.t > 6 then
                local a = 1 - (self.t - 6) / 0.6
                if a <= 0 then self:Hide() else self:SetAlpha(a) end
            end
        end)
    end
    toast.body:SetText(table.concat(lines, "\n"))
    toast:SetHeight(math.max(56, 34 + #lines * 16))
    toast:SetWidth(math.max(220, toast.body:GetStringWidth() + 70))
    toast:ClearAllPoints()
    -- 르엘 가방이 열려 있으면 가방 바로 위, 아니면 화면 위 가운데
    -- (상인 창 위에 붙이면 상인 창이 화면 왼쪽 위라서 구석에 떠요)
    local bag = _G.LeelUI_Bag
    if bag and bag:IsShown() then
        toast:SetPoint("BOTTOM", bag, "TOP", 0, 8)
    else
        toast:SetPoint("TOP", UIParent, "TOP", 0, -140)
    end
    toast:SetClampedToScreen(true)
    toast.t = 0
    toast:SetAlpha(1)
    toast:Show()
end

----------------------------------------------------------------------
-- 팔기 + 고치기
----------------------------------------------------------------------
local selling, queue, sold, soldN = false, nil, 0, 0
local open = false          -- 상인 창이 열려 있는지 (이벤트로 판단: 창 모양을 바꾼 애드온이 있어도)
local pass = 0
local ticker

local function Report(repaired, noMoney)
    local d = DB()
    if not d.report then return end
    local lines = {}
    if soldN > 0 then
        lines[#lines + 1] = string.format("회색 잡템 %d개 판매  |cff9fe3a8+%s|r", soldN, Money(sold))
    end
    if repaired and repaired > 0 then
        lines[#lines + 1] = "장비 수리  |cffff8fa3-" .. Money(repaired) .. "|r"
    elseif noMoney then
        lines[#lines + 1] = "|cffff8fa3수리할 돈이 부족해요|r (" .. Money(noMoney) .. " 필요)"
    end
    if #lines == 0 then return end
    lines[#lines + 1] = "|cffd6a09c남은 돈|r  " .. Money(GetMoney())
    Toast(lines)
    Print(table.concat(lines, ", "):gsub("  ", " "))
end

local function DoRepair()
    local d = DB()
    if not d.repair or not CanMerchantRepair or not CanMerchantRepair() then return end
    local cost, can = GetRepairAllCost()
    if not can or not cost or cost <= 0 then return end
    if GetMoney() < cost then return nil, cost end
    RepairAllItems()
    return cost
end

local Collect, SellStep
local function Finish()
    -- 한 번 더 훑기: 늦게 정보가 온 템, 팔다 잠겨 있던 템
    if pass < 3 then
        pass = pass + 1
        if ticker then ticker:Cancel(); ticker = nil end
        C_Timer.After(0.6, function()
            if not (selling and open) then return end
            queue = DB().sell and Collect() or {}
            if #queue == 0 then pass = 99; Finish() return end
            ticker = C_Timer.NewTicker(0.2, SellStep)
            SellStep()
        end)
        return
    end
    selling = false
    if ticker then ticker:Cancel(); ticker = nil end
    local repaired, noMoney = DoRepair()
    Report(repaired, noMoney)
end

SellStep = function()
    if not open then
        selling = false
        if ticker then ticker:Cancel(); ticker = nil end
        return
    end
    local n = 0
    while queue and #queue > 0 and n < 8 do
        local it = table.remove(queue, 1)
        -- 그 사이에 칸이 바뀌었으면 건너뜀
        local q, count, link, _, _, locked = SlotInfo(it.bag, it.slot)
        if link == it.link and not locked and (q == 0 or it.q == 0) then
            UseItem(it.bag, it.slot)
            sold = sold + (Price(link) or it.price or 0) * (count or 1)
            soldN = soldN + 1
            n = n + 1
        end
    end
    if not queue or #queue == 0 then Finish() end
end

Collect = function()
    local d = DB()
    local list = {}
    local first, last = BAGS()
    for bag = first, last do
        for slot = 1, (NumSlots(bag) or 0) do
            local q, _, link, id, noValue = SlotInfo(bag, slot)
            if link then
                local price, iq = Price(link)
                q = q or iq
                id = id or IDFromLink(link)
                if price == nil and id and C_Item and C_Item.RequestLoadItemDataByID then
                    pcall(C_Item.RequestLoadItemDataByID, id)
                end
                -- 판매가를 아직 몰라도 회색이면 팔기 (0원짜리만 제외)
                if q == 0 and not noValue and price ~= 0 and not d.keep[id] then
                    list[#list + 1] = { bag = bag, slot = slot, link = link, price = price, q = q }
                end
            end
        end
    end
    return list
end

-- 가방에 "안 팔기"로 정한 회색 템이 있는지
local function KeptJunkInBags()
    local d = DB()
    if not next(d.keep) then return false end
    local first, last = BAGS()
    for bag = first, last do
        for slot = 1, (NumSlots(bag) or 0) do
            local q, _, link, id = SlotInfo(bag, slot)
            id = id or IDFromLink(link)
            if link and q == 0 and id and d.keep[id] then return true end
        end
    end
    return false
end

local function OnMerchant()
    local d = DB()
    if not d.on or not open then return end
    if IsShiftKeyDown() then
        Print("Shift: 이번엔 상점 토끼가 쉬어요.")
        return
    end
    sold, soldN, pass = 0, 0, 0
    selling = true
    queue = d.sell and Collect() or {}
    if #queue == 0 then pass = 99; Finish() return end
    -- 게임의 "잡동사니 모두 팔기"가 있으면 그걸로 한 번에 (안 팔기 템이 가방에 없을 때)
    local sellAll = C_MerchantFrame and C_MerchantFrame.SellAllJunkItems
    if sellAll and not KeptJunkInBags() then
        for _, it in ipairs(queue) do
            local _, count = SlotInfo(it.bag, it.slot)
            sold = sold + (Price(it.link) or it.price or 0) * (count or 1)
            soldN = soldN + 1
        end
        local ok = pcall(sellAll)
        if ok then
            queue = {}
            pass = 2          -- 한 번만 더 훑어서 남은 게 있으면 하나씩
            Finish()
            return
        end
        sold, soldN = 0, 0
    end
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(0.2, SellStep)
    SellStep()
end

----------------------------------------------------------------------
-- 안 팔기 목록: 가방에서 Alt+클릭
----------------------------------------------------------------------
local function ToggleKeep(link)
    local id = IDFromLink(link)
    if not id then return end
    local _, q = Price(link)
    local d = DB()
    if d.keep[id] then
        d.keep[id] = nil
        Print(link .. " 다시 팔아요.")
    else
        if q ~= 0 then return end -- 회색 템만
        d.keep[id] = true
        Print(link .. " 안 팔기 목록에 넣었어요. (Alt+클릭으로 빼기)")
    end
end

if HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", function(link)
        if type(link) ~= "string" then return end
        if not (IsAltKeyDown() and not IsShiftKeyDown() and not IsControlKeyDown()) then return end
        if not (ns.db and DB().on) then return end
        -- 가방 칸 위에서 누른 것만
        local f = GetMouseFocus and GetMouseFocus()
        if not f and GetMouseFoci then f = GetMouseFoci()[1] end
        local p = f and f.GetParent and f:GetParent()
        local name = p and p.GetName and p:GetName() or ""
        if not (name:find("^ContainerFrame") or name:find("Bag")) then return end
        ToggleKeep(link)
    end)
end

function ns:ShopKeepCount()
    local n = 0
    for _ in pairs(DB().keep) do n = n + 1 end
    return n
end

function ns:ShopClearKeep()
    wipe(DB().keep)
    Print("안 팔기 목록을 비웠어요.")
end

-- 툴팁: 상인 앞에서 회색 템에 한 줄
local function OnTip(tip)
    if not (ns.db and DB().on and DB().sell) then return end
    local mf = _G.MerchantFrame
    if not (mf and mf:IsShown()) then return end
    local _, link = tip:GetItem()
    local id = IDFromLink(link)
    if not id then return end
    local _, q = Price(link)
    if DB().keep[id] then
        tip:AddLine("|cfff2b3c2상점 토끼|r: 안 팔기 (Alt+클릭으로 빼기)", 0.84, 0.63, 0.61)
    elseif q == 0 then
        tip:AddLine("|cfff2b3c2상점 토끼|r: Alt+클릭하면 안 팔기", 0.84, 0.63, 0.61)
    else
        return
    end
    tip:Show()
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip)
        if tip == GameTooltip then OnTip(tip) end
    end)
elseif GameTooltip:HasScript("OnTooltipSetItem") then
    GameTooltip:HookScript("OnTooltipSetItem", OnTip)
end

----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("MERCHANT_SHOW")
ev:RegisterEvent("MERCHANT_CLOSED")
ev:SetScript("OnEvent", function(_, event)
    if not ns.db then return end
    if event == "MERCHANT_SHOW" then
        open = true
        -- 상인 창이 다 열리고 가방 정보가 올 때까지 살짝 기다렸다가
        C_Timer.After(0.3, OnMerchant)
    else
        open = false
    end
    if event == "MERCHANT_CLOSED" and selling then
        selling = false
        if ticker then ticker:Cancel(); ticker = nil end
    end
end)
