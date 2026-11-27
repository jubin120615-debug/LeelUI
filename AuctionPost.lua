-- 르엘 UI · 경매장 일괄 등록 (B안: 경매장 오른쪽에 붙는 날개)
-- 가방에서 팔 수 있는 템을 모아 → 템마다 지금 최저가를 찾아 → 최저가보다 1동 싸게
-- 게임 규칙: 등록은 "누를 때마다 하나" → [다음 올리기] 단추(또는 스페이스)를 연타하면 끝까지
-- 안전장치: 7일 평균의 40% 아래면 빼기 · 상점이 더 나으면 빼기 · 내가 이미 최저면 건너뛰기 · 시세 없으면 평균가/빼기

local ADDON, ns = ...
local C = ns.C
local L = function(s) return ns.L and ns.L(s) or s end
local AHC = C_AuctionHouse
local CC = C_Container or {}
local GetInfo = CC.GetContainerItemInfo
local NumSlots = CC.GetContainerNumSlots or _G.GetContainerNumSlots
local BAG_LAST = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or (NUM_BAG_SLOTS or 4)
if BAG_LAST < (NUM_BAG_SLOTS or 4) then BAG_LAST = NUM_BAG_SLOTS or 4 end
local DAY = 86400

local function DB()
    local d = ns.db
    if not d then return nil end
    d.ahp = d.ahp or {}
    local a = d.ahp
    if a.on == nil then a.on = true end
    if a.undercut == nil then a.undercut = true end      -- 최저가보다 1동 싸게 (끄면 같게)
    if a.dump == nil then a.dump = true end              -- 7일 평균의 40% 아래면 빼기
    if a.vendor == nil then a.vendor = true end          -- 상점이 더 나으면 빼기
    if a.mine == nil then a.mine = true end              -- 내가 이미 최저면 건너뛰기
    if a.noMarket == nil then a.noMarket = "avg" end     -- 시세 없으면: avg = 평균가 · skip = 빼기
    if a.dur == nil then a.dur = 1 end                   -- 1 = 12시간 · 2 = 24시간 · 3 = 48시간
    if a.grey == nil then a.grey = false end             -- 회색 템도
    a.skip = a.skip or {}                                -- [itemID] = true : 늘 빼기
    return a
end
ns.AHPostDB = DB

local function Money(c)
    if ns.AH and ns.AH.Money then return ns.AH.Money(c) end
    return GetCoinTextureString and GetCoinTextureString(math.floor(c or 0)) or tostring(c)
end
local function Avg7(id)
    local book = ns.AH and ns.AH.Book and ns.AH.Book()
    local r = book and book[id]
    if not (r and r.h) then return nil end
    local s, n = 0, 0
    local today = math.floor(time() / DAY)
    for d, v in pairs(r.h) do if d >= today - 7 and v and v > 0 then s = s + v; n = n + 1 end end
    if n == 0 then return nil end
    return s / n
end
local function Remember(id, unit)
    -- 경매장 시세 기록에도 같이 넣어요 (툴팁 시세가 새로워져요)
    local book = ns.AH and ns.AH.Book and ns.AH.Book()
    if not (book and id and unit and unit > 0) then return end
    local r = book[id]
    if not r then r = { h = {} }; book[id] = r end
    r.m, r.t = unit, time()
    local d = math.floor(time() / DAY)
    r.h = r.h or {}
    if not r.h[d] or unit < r.h[d] then r.h[d] = unit end
end

----------------------------------------------------------------------
-- 목록: 가방에서 팔 수 있는 템
--   물품(천 · 약초 …) = 한 줄에 전부 · 장비 = 하나씩
----------------------------------------------------------------------
local list = {}          -- { id, name, icon, q, link, loc, qty, com, key, low, lowT, mine, price, state, why }
local byKey = {}
local function Loc(bag, slot) return ItemLocation and ItemLocation:CreateFromBagAndSlot(bag, slot) end
local function KeyOf(e) return e.com and ("c" .. e.id) or ("i" .. e.bag .. ":" .. e.slot) end

local function Collect()
    local d = DB()
    local old = byKey
    list, byKey = {}, {}
    for bag = 0, BAG_LAST do
        for slot = 1, (NumSlots(bag) or 0) do
            local info = GetInfo(bag, slot)
            if info and info.itemID and not info.isBound and (d.grey or (info.quality or 1) > 0) then
                local loc = Loc(bag, slot)
                local ok, valid = pcall(AHC.IsSellItemValid, loc, false)
                if ok and valid then
                    local okc, st = pcall(AHC.GetItemCommodityStatus, loc)
                    local com = okc and Enum and Enum.ItemCommodityStatus and st == Enum.ItemCommodityStatus.Commodity
                    local k = com and ("c" .. info.itemID) or ("i" .. bag .. ":" .. slot)
                    local e = byKey[k]
                    if e then
                        e.qty = e.qty + (info.stackCount or 1)
                    else
                        local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(info.itemID)
                        e = { id = info.itemID, icon = info.iconFileID, q = info.quality, link = info.hyperlink,
                              name = (not com and info.hyperlink and info.hyperlink:match("%[(.-)%]")) or name or (info.hyperlink and info.hyperlink:match("%[(.-)%]")) or ("#" .. info.itemID),   -- 장비는 접미사까지 ("기사의 …")
                              bag = bag, slot = slot, loc = loc, qty = info.stackCount or 1, com = com, state = "wait" }
                        local o = old[k]
                        if o and o.id == e.id then   -- 앞서 찾은 값 · 상태 이어받기
                            e.low, e.lowT, e.mine, e.price, e.state, e.why, e.key = o.low, o.lowT, o.mine, o.price, o.state, o.why, o.key
                            if e.state == "posting" then e.state = "ready" end
                        end
                        if d.skip[e.id] then e.state, e.why = "skip", "늘 빼기" end
                        byKey[k] = e
                        list[#list + 1] = e
                    end
                end
            end
        end
    end
    -- 다 올린 줄은 가방에서 사라져요 → 앞서 올린 줄을 "올림"으로 남겨 보여줘요
    for k, o in pairs(old) do
        if o.state == "done" and not byKey[k] then byKey[k] = o; list[#list + 1] = o end
    end
    table.sort(list, function(a, b)
        local oa = (a.state == "done" and 0) or (a.state == "skip" and 2) or 1
        local ob = (b.state == "done" and 0) or (b.state == "skip" and 2) or 1
        if oa ~= ob then return oa < ob end
        return (a.name or "") < (b.name or "")
    end)
end

----------------------------------------------------------------------
-- 가격 정하기 (최저 −1동 · 안전장치)
----------------------------------------------------------------------
local function Decide(e)
    local d = DB()
    if e.state == "done" or (e.state == "skip" and e.why == "늘 빼기") then return end
    if e.low == nil then e.state = "wait"; return end
    local unit
    if e.low == false then   -- 경매장에 매물이 없어요
        local avg = Avg7(e.id)
        if d.noMarket == "avg" and avg then unit = math.floor(avg)
        else e.state, e.why = "skip", "시세 없음"; return end
    else
        if e.mine and d.mine then e.state, e.why = "skip", "내가 이미 최저"; return end
        unit = e.low - (d.undercut and 1 or 0)
        if unit < 1 then unit = 1 end
        local avg = Avg7(e.id)
        if d.dump and avg and unit < avg * 0.4 then e.state, e.why = "skip", "평균의 40% 아래"; return end
    end
    if d.vendor then
        local sell = select(11, (C_Item and C_Item.GetItemInfo or GetItemInfo)(e.id))
        if sell and sell > 0 and unit * 0.95 <= sell then e.state, e.why = "skip", "상점이 나아요"; return end
    end
    e.price = unit
    e.state, e.why = "ready", nil
end

----------------------------------------------------------------------
-- 최저가 찾기 (하나씩 · 게임이 숨 돌릴 틈을 주면서)
----------------------------------------------------------------------
local finding     -- 지금 찾는 줄
local seenKey = {} -- itemID → 게임이 결과를 돌려준 열쇠 (블리자드 등록 창이 찾은 것도)
local findT = 0
local Paint
local function Sorts() return { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } } end

local function ReadResult(e)
    if e.com then
        local okN, n = pcall(AHC.GetNumCommoditySearchResults, e.id)
        if not okN or not n or n == 0 then return false end
        local ok, r = pcall(AHC.GetCommoditySearchResultInfo, e.id, 1)
        if not (ok and r and r.unitPrice) then return false end
        -- 내 것만 맨 위에 있으면 "내가 최저"
        local mine = (r.numOwnerItems or 0) > 0 and (r.numOwnerItems or 0) >= (r.quantity or 0)
        return r.unitPrice, mine
    else
        -- 게임이 돌려준 열쇠(접미사 · 템레벨까지 맞는 것)가 있으면 그걸로 읽어요
        local key, okN, n
        for _, k in ipairs({ e.rkey, seenKey[e.id], e.key }) do
            if k then
                key = k; okN, n = pcall(AHC.GetNumItemSearchResults, k)
                if okN and n and n > 0 then break end
            end
        end
        if not okN or not n or n == 0 then return false end
        local ok, r = pcall(AHC.GetItemSearchResultInfo, key, 1)
        if not (ok and r and r.buyoutAmount and r.buyoutAmount > 0) then return false end
        return r.buyoutAmount / math.max(1, r.quantity or 1), r.containsOwnerItem and true or false
    end
end

-- 경매장 시세 책에 방금(age초 안) 적힌 최저가 (블리자드 창 · 오른쪽 클릭으로 본 것도 여기 적혀요)
local function Fresh(id, age)
    local book = ns.AH and ns.AH.Book and ns.AH.Book()
    local r = book and book[id]
    if r and r.m and r.m > 0 and r.t and time() - r.t <= age then return r.m end
end

local function Found(e, low, mine)
    if low == false and not e.com then
        local f = Fresh(e.id, 1800)   -- 내 찾기가 빈손이어도 30분 안에 본 시세가 있으면 그걸로
        if f then low, mine = f, false end
    end
    e.low, e.mine, e.lowT = low, mine, GetTime()
    if low and low ~= false and not mine then Remember(e.id, low) end
    Decide(e)
    finding = nil
    if Paint then Paint() end
end

local function FindNext()
    if finding then
        if GetTime() - findT > 2.5 then
            -- 대답 이벤트를 못 받았어도 결과가 와 있을 수 있어요 → 직접 읽어 봐요
            local e = finding
            local low, mine = ReadResult(e)
            if low then Found(e, low, mine) return end
            -- 장비(접미사 붙은 템 "전투력의 …"): 접미사 없는 넓은 찾기로 한 번 더
            if not e.com and not e.wide then
                e.wide = true
                e.key = AHC.MakeItemKey(e.id)
                finding = nil; e.state = "wait"
                return
            end
            Found(e, false, false)   -- 그래도 없으면 "매물 없음"
        end
        return
    end
    if not (AHC.IsThrottledMessageSystemReady and AHC.IsThrottledMessageSystemReady()) then return end
    for _, e in ipairs(list) do
        if e.state == "wait" or (e.state == "ready" and e.lowT and GetTime() - e.lowT > 90) then
            -- 장비: 방금(5분 안) 본 시세가 있으면 찾지 않고 바로 (빨라요)
            local f = not e.com and e.state == "wait" and Fresh(e.id, 300)
            if f then Found(e, f, false) return end
            if not e.key then
                if e.com then e.key = AHC.MakeItemKey(e.id)
                else local ok, k = pcall(AHC.GetItemKeyFromItem, e.loc); e.key = ok and k or AHC.MakeItemKey(e.id) end
            end
            finding, findT = e, GetTime()
            e.state = "find"
            e.rkey = nil
            -- 장비는 경매 등록 창과 같은 찾기 (접미사 붙은 녹색 템도 같은 것끼리)
            local ok
            if not e.com and not e.wide and AHC.SendSellSearchQuery then ok = pcall(AHC.SendSellSearchQuery, e.key, Sorts(), true) end
            if not ok then ok = pcall(AHC.SendSearchQuery, e.key, Sorts(), true) end
            if not ok then Found(e, false, false) end
            if Paint then Paint() end
            return
        end
    end
end

----------------------------------------------------------------------
-- 올리기 (단추 · 스페이스 = 누를 때마다 하나)
----------------------------------------------------------------------
local posting
local stats = { n = 0, money = 0 }
local function Next()
    for _, e in ipairs(list) do if e.state == "ready" then return e end end
end
local function Post()
    if posting then return end
    local e = Next()
    if not e then return end
    local d = DB()
    -- 오래된 가격이면 먼저 다시 찾아요 (이번 누름은 찾기만)
    if not e.confirm and (not e.lowT or GetTime() - e.lowT > 90) then e.state = "wait"; Paint(); return end
    -- 가방에서 아직 그 칸에 있는지
    local info = GetInfo(e.bag, e.slot)
    if not (info and info.itemID == e.id) then Collect(); for _, x in ipairs(list) do Decide(x) end; Paint(); return end
    local dur = d.dur or 1
    local deposit
    if e.com then deposit = select(2, pcall(AHC.CalculateCommodityDeposit, e.id, dur, e.qty))
    else deposit = select(2, pcall(AHC.CalculateItemDeposit, e.loc, dur, 1)) end
    if type(deposit) == "number" and GetMoney() < deposit then ns.Print(L("보증금이 모자라요.")); return end
    posting = e
    e.state = "posting"
    local ok, err
    if e.confirm then   -- 게임이 물었던 확인에 "예"
        e.confirm = nil
        if e.com then ok, err = pcall(AHC.ConfirmPostCommodity, e.loc, dur, e.qty, e.price)
        else ok, err = pcall(AHC.ConfirmPostItem, e.loc, dur, 1, nil, e.price) end
    elseif e.com then ok, err = pcall(AHC.PostCommodity, e.loc, dur, e.qty, e.price)
    else ok, err = pcall(AHC.PostItem, e.loc, dur, 1, nil, e.price) end
    if not ok then posting = nil; e.state, e.why = "skip", "올리기 실패"; ns.Print(L("올리기가 막혔어요: ") .. tostring(err)) end
    Paint()
    C_Timer.After(6, function() if posting == e then posting = nil; if e.state == "posting" then e.state = "ready" end; Paint() end end)
end
ns.AHPost = Post

----------------------------------------------------------------------
-- 날개 (경매장 오른쪽에 딱 붙어요)
----------------------------------------------------------------------
local W, ROWH, MAXROWS = 380, 46, 9
local P, rows, off = nil, {}, 0
local ACC = C and C.acc or { 0.949, 0.702, 0.761 }
local DOT = { done = { 0.62, 0.89, 0.75 }, ready = ACC, posting = ACC, find = { 1, 0.82, 0.35 }, wait = { 0.44, 0.38, 0.37 }, skip = { 0.95, 0.6, 0.6 } }
local LAB = { done = "올림", ready = "준비", posting = "올리는 중", find = "최저가 찾는 중", wait = "대기", skip = "" }

local function Font(parent, size, col)
    if ns.Font then return ns.Font(parent, size, col) end
    local f = parent:CreateFontString(nil, "OVERLAY"); f:SetFont(STANDARD_TEXT_FONT, size, "")
    if col then f:SetTextColor(col[1], col[2], col[3]) end
    return f
end

local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, P)
    r:SetHeight(ROWH - 2)
    r:SetPoint("TOPLEFT", P, "TOPLEFT", 10, -48 - (i - 1) * ROWH)
    r:SetPoint("RIGHT", P, "RIGHT", -10, 0)
    r.hi = r:CreateTexture(nil, "BACKGROUND"); r.hi:SetAllPoints(); r.hi:SetColorTexture(ACC[1], ACC[2], ACC[3], 0.13)
    r.dot = r:CreateTexture(nil, "ARTWORK"); r.dot:SetTexture(ns.MEDIA .. "circle"); r.dot:SetSize(8, 8); r.dot:SetPoint("LEFT", 4, 0)
    r.ic = r:CreateTexture(nil, "ARTWORK"); r.ic:SetSize(32, 32); r.ic:SetPoint("LEFT", r.dot, "RIGHT", 8, 0); r.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = Font(r, 13.5, { 0.94, 0.89, 0.87 }); r.name:SetPoint("TOPLEFT", r.ic, "TOPRIGHT", 9, -1); r.name:SetWidth(170)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.st = Font(r, 11, { 0.66, 0.59, 0.57 }); r.st:SetPoint("BOTTOMLEFT", r.ic, "BOTTOMRIGHT", 9, 1)
    r.price = Font(r, 14, { 1, 1, 1 }); r.price:SetPoint("TOPRIGHT", -4, -4); r.price:SetJustifyH("RIGHT")   -- 숫자 글꼴엔 금 · 은 · 동 글자가 없어요
    r.low = Font(r, 10.5, { 0.56, 0.5, 0.48 }); r.low:SetPoint("BOTTOMRIGHT", -4, 3)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnEnter", function(self)
        if not self.e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.e.link then GameTooltip:SetHyperlink(self.e.link) else GameTooltip:SetItemByID(self.e.id) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L("오른쪽 클릭: 이 템은 늘 빼기 / 다시 넣기"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self, btn)
        local e = self.e; if not e or btn ~= "RightButton" then return end
        local d = DB()
        if d.skip[e.id] then d.skip[e.id] = nil; e.state, e.why = "wait", nil
        else d.skip[e.id] = true; e.state, e.why = "skip", "늘 빼기" end
        Decide(e); Paint()
    end)
    rows[i] = r
    return r
end

function Paint()
    if not P or not P:IsShown() then return end
    local total, done, est = 0, 0, 0
    for _, e in ipairs(list) do
        if e.state ~= "skip" then total = total + 1 end
        if e.state == "done" then done = done + 1 end
        if e.state == "ready" and e.price then est = est + e.price * (e.com and e.qty or 1) end
    end
    P.count:SetText(done .. "/" .. total)
    local maxOff = math.max(0, #list - MAXROWS)
    if off > maxOff then off = maxOff end
    for i = 1, MAXROWS do
        local r = Row(i)
        local e = list[i + off]
        r.e = e
        if e then
            local col = DOT[e.state] or DOT.wait
            r.dot:SetVertexColor(col[1], col[2], col[3], 1)
            r.ic:SetTexture(e.icon or 134400)
            local qc = e.q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[e.q]
            r.name:SetText(e.name .. (e.qty > 1 and ("  |cffa99692×" .. e.qty .. "|r") or ""))
            if qc and e.q ~= 1 then r.name:SetTextColor(qc.r, qc.g, qc.b) else r.name:SetTextColor(0.94, 0.89, 0.87) end
            r.st:SetText(L(e.state == "skip" and (e.why or "빠짐") or LAB[e.state] or ""))
            r.st:SetTextColor(col[1], col[2], col[3])
            if e.price and e.state ~= "skip" then r.price:SetText(Money(e.price)); r.price:SetAlpha(1)
            else r.price:SetText("|cff8f7f7b—|r") end
            if e.low and e.low ~= false then r.low:SetText(L("최저") .. " " .. Money(e.low))
            elseif e.low == false then r.low:SetText(L("매물 없음")) else r.low:SetText("") end
            r.hi:SetShown(e == Next() or e.state == "posting")
            r:SetAlpha(e.state == "skip" and 0.55 or 1)
            r:Show()
        else r:Hide() end
    end
    P.empty:SetShown(#list == 0)
    P.prog:SetWidth(math.max(1, (P.track:GetWidth() or 300) * (total > 0 and done / total or 0)))
    P.est:SetText(L("예상") .. "\n" .. Money(est))
    local nx = Next()
    if nx then P.Go(nx.confirm and L("확인하고 올리기 · Space") or L("다음 올리기 · Space"), true)
    elseif finding then P.Go(L("최저가 찾는 중 …"), false)
    else P.Go(L(done > 0 and "다 올렸어요" or "올릴 템이 없어요"), false) end
end

local function Build()
    local host = _G.AuctionHouseFrame
    if P or not host then return end
    P = CreateFrame("Frame", "LeelUI_AHPost", host)
    P:SetWidth(W)
    P:SetPoint("TOPLEFT", host, "TOPRIGHT", -2, -2)
    P:SetPoint("BOTTOMLEFT", host, "BOTTOMRIGHT", -2, 2)
    P:SetFrameLevel(host:GetFrameLevel() + 5)
    P:EnableMouse(true)
    P.bg = P:CreateTexture(nil, "BACKGROUND"); P.bg:SetAllPoints(); P.bg:SetColorTexture(0.078, 0.063, 0.063, 0.97)
    if ns.RoundRect then
        pcall(function() P.bg:Hide(); P.rr = ns.RoundRect(P, 18, { 0.078, 0.063, 0.063 }, "BACKGROUND", 0, 0) end)
    end
    -- 왼쪽 분홍 줄 (경매장과 이어 보이게)
    P.edge = P:CreateTexture(nil, "ARTWORK"); P.edge:SetColorTexture(ACC[1], ACC[2], ACC[3], 1); P.edge:SetWidth(3)
    P.edge:SetPoint("TOPLEFT", 0, -10); P.edge:SetPoint("BOTTOMLEFT", 0, 10)
    P.title = Font(P, 17, { 0.96, 0.92, 0.91 }); P.title:SetPoint("TOPLEFT", 16, -14); P.title:SetText(L("일괄 등록"))
    P.sub = Font(P, 11.5, { 0.66, 0.59, 0.57 }); P.sub:SetPoint("BOTTOMLEFT", P.title, "BOTTOMRIGHT", 8, 1)
    P.count = P:CreateFontString(nil, "OVERLAY"); P.count:SetFont(ns.NUM or ns.FONT, 17, ""); P.count:SetTextColor(ACC[1], ACC[2], ACC[3])
    P.count:SetPoint("TOPRIGHT", -40, -14)
    local x = CreateFrame("Button", nil, P); x:SetSize(20, 20); x:SetPoint("TOPRIGHT", -12, -12)
    x.t = x:CreateTexture(nil, "ARTWORK"); x.t:SetAllPoints(); x.t:SetTexture(ns.MEDIA .. "hb_x"); x.t:SetVertexColor(0.66, 0.59, 0.57)
    if not x.t:GetTexture() then x.t:SetColorTexture(0.5, 0.4, 0.4, 1) end
    x:SetScript("OnClick", function() P:Hide(); P.closed = true end)
    x:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(L("이번엔 닫기")); GameTooltip:AddLine(L("경매장을 다시 열면 또 떠요 · 아예 끄기는 허브 > 경매장 시세"), 0.7, 0.7, 0.7, true); GameTooltip:Show() end)
    x:SetScript("OnLeave", function() GameTooltip:Hide() end)
    P.empty = Font(P, 13, { 0.56, 0.5, 0.48 }); P.empty:SetPoint("TOP", 0, -90); P.empty:SetText(L("가방에 팔 수 있는 템이 없어요"))
    P:EnableMouseWheel(true)
    P:SetScript("OnMouseWheel", function(_, dlt) off = math.max(0, off - dlt); Paint() end)
    -- 아래: 진행 막대 · 예상 · 큰 단추
    P.track = P:CreateTexture(nil, "ARTWORK"); P.track:SetColorTexture(0.23, 0.17, 0.16, 1); P.track:SetHeight(4)
    P.track:SetPoint("BOTTOMLEFT", 14, 66); P.track:SetPoint("BOTTOMRIGHT", -14, 66)
    P.prog = P:CreateTexture(nil, "OVERLAY"); P.prog:SetColorTexture(ACC[1], ACC[2], ACC[3], 1); P.prog:SetHeight(4)
    P.prog:SetPoint("LEFT", P.track, "LEFT", 0, 0); P.prog:SetWidth(1)
    P.est = Font(P, 11.5, { 0.66, 0.59, 0.57 }); P.est:SetPoint("BOTTOMLEFT", 16, 16); P.est:SetJustifyH("LEFT")
    local go = ns.MakeButton and ns.MakeButton(P, L("다음 올리기 · Space"), true, function() Post() end, 220)
    if not go then go = CreateFrame("Button", nil, P, "UIPanelButtonTemplate"); go:SetScript("OnClick", function() Post() end) end
    go:SetHeight(40); go:SetWidth(240); go:SetPoint("BOTTOMRIGHT", -14, 14)
    P.go = go
    function P.Go(text, on)
        if go.SetLabel then go:SetLabel(text) else go:SetText(text) end
        go:SetWidth(240)
        if on then go:Enable(); go:SetAlpha(1) else go:Disable(); go:SetAlpha(0.5) end
    end
    -- 스페이스 = 다음 올리기 (글 쓰는 중이 아닐 때만 · 다른 키는 그대로 게임으로)
    P:EnableKeyboard(true)
    P:SetPropagateKeyboardInput(true)
    P:SetScript("OnKeyDown", function(self, key)
        if key == "SPACE" and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()) and Next() and not InCombatLockdown() then
            self:SetPropagateKeyboardInput(false); Post()
        elseif not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
    end)
    -- 찾기 일꾼 (0.3초마다 하나씩)
    local t = 0
    P:SetScript("OnUpdate", function(_, el) t = t + el; if t > 0.3 then t = 0; FindNext() end end)
    P:Hide()
end

-- 기간 이름은 게임 글을 그대로 (와우 포에버는 2 · 8 · 24시간처럼 판마다 달라요)
function ns.AHDurName(i)
    local g = ({ _G.AUCTION_DURATION_ONE, _G.AUCTION_DURATION_TWO, _G.AUCTION_DURATION_THREE })[i]
    if type(g) == "string" and g ~= "" then return g end
    return ({ L("12시간"), L("24시간"), L("48시간") })[i] or ""
end
local function SubText()
    local d = DB()
    local dur = ns.AHDurName and ns.AHDurName(d.dur or 1) or ""
    return L(d.undercut and "최저가 −1동" or "최저가와 같게") .. " · " .. dur
end

local function Open()
    local d = DB()
    if not d or not d.on or not AHC or not AHC.PostCommodity then return end
    Build()
    if not P or P.closed then return end
    Collect()
    for _, e in ipairs(list) do Decide(e) end
    P.sub:SetText(SubText())
    off = 0
    P:Show()
    Paint()
end
ns.AHPostOpen = function() if P then P.closed = false end; Open() end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_ADDED",
                     "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_HOUSE_POST_WARNING", "AUCTION_HOUSE_POST_ERROR", "BAG_UPDATE_DELAYED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e, a1)
    if not ns.db then return end
    if e == "AUCTION_HOUSE_SHOW" then
        if P then P.closed = false end
        stats.n, stats.money = 0, 0
        byKey = {}
        C_Timer.After(0.2, Open)
    elseif e == "AUCTION_HOUSE_CLOSED" then
        if stats.n > 0 then ns.Print((L("경매장에 %d개 올렸어요 · 예상 ")):format(stats.n) .. Money(stats.money)) end
        stats.n, stats.money = 0, 0
        finding, posting = nil, nil
        if P then P:Hide() end
    elseif e == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        if finding and finding.com and finding.id == a1 then
            local low, mine = ReadResult(finding)
            if low then Found(finding, low, mine) end
        end
    elseif e == "ITEM_SEARCH_RESULTS_UPDATED" or e == "ITEM_SEARCH_RESULTS_ADDED" then
        if type(a1) == "table" and a1.itemID then
            seenKey[a1.itemID] = a1
            -- 시세 책이 적힌 뒤에 "매물 없음" 줄을 한 번 더 채워요
            C_Timer.After(0.3, function()
                local ch
                for _, x in ipairs(list) do
                    if not x.com and x.low == false and x.state ~= "done" then
                        local f = Fresh(x.id, 120)
                        if f then x.low, x.mine, x.lowT = f, false, GetTime(); Decide(x); ch = true end
                    end
                end
                if ch and Paint then Paint() end
            end)
            if finding and not finding.com and a1.itemID == finding.id then
                finding.rkey = a1
                local low, mine = ReadResult(finding)
                if low then Found(finding, low, mine) end   -- 비어 있으면 조금 더 기다려요 (결과가 나눠 와요)
            else
                -- 블리자드 등록 창이 찾은 결과도 같은 템 줄에 채워요 (아직 매물 없음 · 기다리는 줄)
                for _, x in ipairs(list) do
                    if not x.com and x.id == a1.itemID and x ~= finding and (x.state == "wait" or x.low == false) then
                        x.rkey = a1
                        local low, mine = ReadResult(x)
                        if low then
                            x.low, x.mine, x.lowT = low, mine, GetTime()
                            if not mine then Remember(x.id, low) end
                            if x.state == "wait" then x.state = "ready" end
                            Decide(x)
                        end
                    end
                end
                if Paint then Paint() end
            end
        end
    elseif e == "AUCTION_HOUSE_AUCTION_CREATED" then
        local p = posting
        if p then
            posting = nil
            p.state = "done"
            stats.n = stats.n + 1
            stats.money = stats.money + (p.price or 0) * (p.com and p.qty or 1)
            C_Timer.After(0.3, function() if P and P:IsShown() then Collect(); for _, x in ipairs(list) do Decide(x) end; Paint() end end)
            Paint()
        end
    elseif e == "AUCTION_HOUSE_POST_WARNING" then
        -- 게임이 "가격이 많이 낮아요" 같은 확인을 물어요 → 다음 누름에 확인으로 넘겨요
        if posting then
            local p = posting
            ns.Print(L("게임이 확인을 물어요 · 한 번 더 누르면 그대로 올려요"))
            p.state = "ready"; posting = nil
            p.confirm = true
            Paint()
        end
    elseif e == "AUCTION_HOUSE_POST_ERROR" then
        if posting then posting.state, posting.why = "skip", "올리기 실패"; posting = nil; Paint() end
    elseif e == "BAG_UPDATE_DELAYED" then
        if P and P:IsShown() and not posting then
            Collect(); for _, x in ipairs(list) do Decide(x) end; Paint()
        end
    end
end)
