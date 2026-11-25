-- 르엘 UI · 경매장 시세 (A안: 툴팁 아래 3줄)
-- 경매장에서 본 가격을 서버 · 진영별로 기억 → 가방 · 은행 · 우편 어디서든 템 툴팁에
--   🐰 경매 최저 · 🐰 7일 평균 · 상점 판매 · 🐰 ×N 묶음 · "몇 시간 전 시세"
-- 시세 모으기: 경매장에서 찾기만 해도 그 쪽 결과를 기억 + 경매장 창 "시세 훑기" (전체 · 15분에 한 번)
local ADDON, ns = ...
local C = ns.C
local L = function(s) return ns.L and ns.L(s) or s end

local A = {}
ns.AH = A
local DAY = 86400

local function DB()
    local d = ns.db
    if not d then return nil end
    d.ah = d.ah or {}
    local a = d.ah
    if a.tip == nil then a.tip = true end
    if a.avg == nil then a.avg = true end
    -- 게임 툴팁에 "판매 가격"이 이미 있어요 → 기본 꺼짐 (처음 판에서 켜진 채 저장된 것도 한 번 끔)
    if a.vendor == nil or (a.v or 1) < 2 then a.vendor = false; a.v = 2 end
    if a.cmp == nil then a.cmp = true end
    a.data = a.data or {}
    return a
end
A.DB = DB

local function Key()
    local r = (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName() or "?"
    return r .. "-" .. (UnitFactionGroup("player") or "?")
end
local function Book()
    local d = DB(); if not d then return nil end
    local k = Key()
    d.data[k] = d.data[k] or {}
    return d.data[k]
end
A.Book = Book

local function Today() return math.floor(time() / DAY) end

-- 한 템의 이번 가격 (1개 값 · 구리) 기록
-- r = { m = 지금 최저, t = 본 시각, n = 판매 수, h = { [날] = 그날 최저 } }
local function Put(book, id, unit, n, fresh)
    if not (id and unit and unit > 0) then return end
    local r = book[id]
    if not r then r = { h = {} }; book[id] = r end
    local now = time()
    if fresh or not r.t or now - r.t > 3600 or unit < (r.m or math.huge) then r.m = unit end
    r.t = now; r.n = n or r.n
    local d = Today()
    r.h = r.h or {}
    if not r.h[d] or unit < r.h[d] then r.h[d] = unit end
    for k in pairs(r.h) do if k < d - 7 then r.h[k] = nil end end
end

----------------------------------------------------------------------
-- 돈 글씨 (금 · 은 · 동 색)
----------------------------------------------------------------------
local function Money(c)
    c = math.floor((c or 0) + 0.5)
    local g, s, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local en = ns.EnOn and ns.EnOn()
    local G, S, CP = en and "g" or "금", en and "s" or "은", en and "c" or "동"
    local t = {}
    if g > 0 then t[#t + 1] = ("|cffffd27a%d|r%s"):format(g, G) end
    if s > 0 then t[#t + 1] = ("|cffd8d8d8%d|r%s"):format(s, S) end
    if cp > 0 and g < 100 then t[#t + 1] = ("|cffe8a060%d|r%s"):format(cp, CP) end
    if #t == 0 then return "|cffe8a0600|r" .. CP end
    return table.concat(t, " ")
end
A.Money = Money

local function Ago(t)
    local s = time() - (t or 0)
    if s < 3600 then return L("방금 본 시세") end
    if s < DAY then return (L("%d시간 전 시세")):format(math.floor(s / 3600)) end
    return (L("%d일 전 시세")):format(math.floor(s / DAY))
end

----------------------------------------------------------------------
-- 툴팁
----------------------------------------------------------------------
local BUN = "|T" .. (ns.MEDIA or "") .. "bunny:12:12|t "
local lastCount = {}

local function Bound(tt)
    local name = tt:GetName()
    if not name then return false end
    for i = 2, 5 do
        local fs = _G[name .. "TextLeft" .. i]
        local t = fs and fs:GetText()
        if t and (t == ITEM_SOULBOUND or t == ITEM_BIND_QUEST or t == ITEM_ACCOUNTBOUND or t == ITEM_BNETACCOUNTBOUND) then return true end
    end
    return false
end

local CUT = 0.95   -- 경매장 수수료 5% 뺀 값으로 비교
local function OnItem(tt)
    local d = DB()
    if not (d and d.tip) then return end
    if tt ~= GameTooltip and tt ~= _G.ItemRefTooltip then return end
    local ok, _, link = pcall(tt.GetItem, tt)
    if not ok or type(link) ~= "string" then return end
    local id = tonumber(link:match("item:(%d+)"))
    if not id then return end
    if Bound(tt) then return end
    local count = lastCount[tt] or 1
    if IsShiftKeyDown() then count = 1 end          -- Shift = 1개 기준
    local r = Book()[id]
    local GII = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local vendor = GII and select(11, GII(link)) or 0
    local acc = C.acc
    tt:AddLine(" ")
    if not (r and r.m) then
        tt:AddLine(BUN .. L("경매 시세 없음"), 0.55, 0.52, 0.6)
        return tt:Show()
    end
    local N = count > 1 and ("×" .. count .. " ") or ""
    local net = r.m * count * CUT
    if d.cmp ~= false and vendor and vendor > 0 then
        -- A안: 결론 한 줄 (초록 = 경매가 이득 · 주황 = 상점에 팔아요) + 같은 단위 두 줄
        local shop = vendor * count
        local diff = net - shop
        if diff >= 0 then
            tt:AddLine(BUN .. L("경매가 이득") .. " · +" .. Money(diff), 0.45, 0.95, 0.5)
        else
            tt:AddLine(BUN .. L("상점에 팔아요") .. " · +" .. Money(-diff), 1, 0.66, 0.3)
        end
        tt:AddDoubleLine(BUN .. L("경매") .. " " .. N .. L("(수수료 뺀)"), Money(net), acc[1], acc[2], acc[3], 1, 1, 1)
        tt:AddDoubleLine(L("상점") .. " " .. N, Money(shop), 0.75, 0.75, 0.78, 1, 1, 1)
    else
        tt:AddDoubleLine(BUN .. L("경매 최저"), Money(r.m), acc[1], acc[2], acc[3], 1, 1, 1)
        if count > 1 then tt:AddDoubleLine(BUN .. N .. L("묶음"), Money(r.m * count), acc[1], acc[2], acc[3], 1, 1, 1) end
    end
    if d.avg and r.h then
        local sum, n = 0, 0
        for _, v in pairs(r.h) do sum = sum + v; n = n + 1 end
        if n >= 2 then tt:AddDoubleLine(BUN .. L("7일 평균") .. " (" .. L("1개") .. ")", Money(sum / n), acc[1], acc[2], acc[3], 1, 1, 1) end
    end
    local tail = {}
    if count > 1 then tail[#tail + 1] = L("1개") .. " " .. Money(r.m) end
    tail[#tail + 1] = Ago(r.t)
    if r.n and r.n > 0 then tail[#tail + 1] = (L("%d개 판매 중")):format(r.n) end
    tt:AddLine(table.concat(tail, " · "), 0.5, 0.48, 0.56)
    tt:Show()
end

-- 가방 칸 툴팁이면 묶음 수 기억
local function SetCount(tt, n) lastCount[tt] = n end
pcall(hooksecurefunc, GameTooltip, "SetBagItem", function(tt, bag, slot)
    local n = 1
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot); n = info and info.stackCount or 1
    elseif GetContainerItemInfo then n = select(2, GetContainerItemInfo(bag, slot)) or 1 end
    SetCount(tt, n)
end)
pcall(hooksecurefunc, GameTooltip, "SetInventoryItem", function(tt, unit, slot)
    SetCount(tt, (GetInventoryItemCount and GetInventoryItemCount(unit, slot)) or 1)
end)
pcall(hooksecurefunc, GameTooltip, "SetInboxItem", function(tt, i, a)
    local ok, _, _, _, n = pcall(GetInboxItem, i, a or 1); SetCount(tt, ok and n or 1)
end)
GameTooltip:HookScript("OnHide", function(tt) lastCount[tt] = nil end)

if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt)
        A.calls = (A.calls or 0) + 1
        local ok, err = pcall(OnItem, tt)
        if not ok then A.err = tostring(err) end
    end)
else
    GameTooltip:HookScript("OnTooltipSetItem", function(tt) pcall(OnItem, tt) end)
    if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", function(tt) pcall(OnItem, tt) end) end
end

----------------------------------------------------------------------
-- 시세 모으기
----------------------------------------------------------------------
local scan        -- 전체 훑기 진행 { i, total, book, seen }
local btn, status
local AHC = C_AuctionHouse
local MODERN = AHC and AHC.ReplicateItems and true or false   -- 와우 포에버 = 새 경매장 (C_AuctionHouse)

-- 검색 칸 안 오른쪽 글 + 칸 아래 금색 막대 (A안)
--   kind: run = 노랑 (모으는 중) · ok = 초록 (3초) · err = 빨강 (4초)
local msgFS, barBG, barFill, msgTimer
function A.CD() return (C_AuctionHouse and C_AuctionHouse.SendBrowseQuery) and 120 or 900 end   -- 다시 훑기까지 (초)
local function Status(t, kind)
    if not msgFS then return end
    if msgTimer then msgTimer:Cancel(); msgTimer = nil end
    msgFS:SetText(t or "")
    if kind == "ok" then msgFS:SetTextColor(0.42, 1, 0.48)
    elseif kind == "err" then msgFS:SetTextColor(1, 0.42, 0.42)
    else msgFS:SetTextColor(1, 0.82, 0) end
    if (kind == "ok" or kind == "err") and t and t ~= "" then
        msgTimer = C_Timer.NewTimer(kind == "ok" and 3 or 4, function() msgTimer = nil; if msgFS then msgFS:SetText("") end end)
    end
    if A.PaintBtn then A.PaintBtn() end
end
local function Bar(p)
    if not barBG then return end
    if not p then barBG:Hide() return end
    barBG:Show()
    barFill:SetWidth(math.max(1, (barBG:GetWidth() or 100) * math.min(1, p)))
end
-- 찾기만 해도 저장 → 잠깐 모아서 "시세 N개 저장됨"
local flashN, flashT = 0, nil
local function Flash(n)
    if not n or n <= 0 then return end
    flashN = flashN + n
    if flashT then return end
    flashT = C_Timer.NewTimer(0.4, function()
        flashT = nil
        if not scan then Status((L("시세 %d개 저장됨")):format(flashN), "ok") end
        flashN = 0
    end)
end

-- 전체 훑기 한 칸 읽기 (새 경매장 = ReplicateItems · 예전 = getAll)
local function ReadAll(i)
    local count, buyout, itemId
    if MODERN then
        local r = { pcall(AHC.GetReplicateItemInfo, i - 1) }
        if not r[1] then return nil end
        count, buyout, itemId = r[4], r[11], r[18]
    else
        local _, _, c, _, _, _, _, _, _, bo, _, _, _, _, _, _, id = GetAuctionItemInfo("list", i)
        count, buyout, itemId = c, bo, id
    end
    if not (itemId and buyout and buyout > 0 and count and count > 0) then return nil end
    return itemId, buyout / count
end

-- 찾기 결과 → 기억
local function OnBrowse()
    if scan and not scan.browse then return end
    local book = Book(); if not book then return end
    if MODERN and AHC.GetBrowseResults then
        local ok, res = pcall(AHC.GetBrowseResults)
        if not ok or type(res) ~= "table" then return end
        local k = 0
        for _, r in ipairs(res) do
            local id = r.itemKey and r.itemKey.itemID
            if id and r.minPrice and r.minPrice > 0 then Put(book, id, r.minPrice, r.totalQuantity, false); k = k + 1 end
        end
        A.browseSeen = A.browseSeen or 0
        if scan and scan.browse then
            -- 전체 훑기 (빈 검색): 끝까지 더 불러오기
            scan.n = #res
            Status((L("경매장에서 받는 중… %d개")):format(#res), "run")
            Bar(math.min(0.95, #res / 3000))
            local full = AHC.HasFullBrowseResults and AHC.HasFullBrowseResults()
            if full then A.BrowseDone() else
                if not scan.more then
                    scan.more = true
                    C_Timer.After(0.3, function()
                        if scan and scan.browse then scan.more = nil; scan.last = GetTime(); pcall(AHC.RequestMoreBrowseResults) end
                    end)
                end
            end
        else
            if #res > A.browseSeen then Flash(#res - A.browseSeen) end   -- 새로 더 나온 만큼만
        end
        A.browseSeen = #res
    elseif GetNumAuctionItems then
        local n = GetNumAuctionItems("list") or 0
        if n == 0 or n > 50 then return end
        local best, cnt = {}, {}
        for i = 1, n do
            local id, unit = ReadAll(i)
            if id then
                if not best[id] or unit < best[id] then best[id] = unit end
                cnt[id] = (cnt[id] or 0) + 1
            end
        end
        for id, unit in pairs(best) do Put(book, id, unit, cnt[id], false) end
    end
end
-- 물품(천 · 약초 등) · 장비 자세히 보기 → 그 템 최저가
local function OnCommodity(itemID)
    if scan or not (MODERN and itemID) then return end
    local ok, r = pcall(AHC.GetCommoditySearchResultInfo, itemID, 1)
    if ok and r and r.unitPrice then
        local okN, n = pcall(AHC.GetCommoditySearchResultsQuantity, itemID)
        Put(Book(), itemID, r.unitPrice, okN and n or nil, true); Flash(1)
    end
end
local function OnItemSearch(itemKey)
    if scan or not (MODERN and type(itemKey) == "table" and itemKey.itemID) then return end
    local ok, r = pcall(AHC.GetItemSearchResultInfo, itemKey, 1)
    if ok and r and r.buyoutAmount and r.buyoutAmount > 0 then
        local okN, n = pcall(AHC.GetItemSearchResultsQuantity, itemKey)
        Put(Book(), itemKey.itemID, r.buyoutAmount / math.max(1, r.quantity or 1), okN and n or nil, true); Flash(1)
    end
end

local runner = CreateFrame("Frame")
runner:Hide()
runner:SetScript("OnUpdate", function()
    if not scan then runner:Hide() return end
    local stop = math.min(scan.total, scan.i + 500)   -- 한 번에 500개씩 (멈춤 없게)
    for i = scan.i, stop do
        local id, unit = ReadAll(i)
        if id then
            local s = scan.seen[id]
            if not s then scan.seen[id] = { unit, 1 } else
                if unit < s[1] then s[1] = unit end
                s[2] = s[2] + 1
            end
        end
    end
    scan.i = stop + 1
    local p = math.min(1, scan.i / math.max(1, scan.total))
    Status((L("시세 모으는 중 %d%%")):format(math.floor(p * 100)), "run"); Bar(p)
    if scan.i > scan.total then
        local book, k = scan.book, 0
        for id, s in pairs(scan.seen) do Put(book, id, s[1], s[2], true); k = k + 1 end
        local d = DB(); if d then d.lastAll = time() end
        scan = nil; runner:Hide()
        Bar(nil); Status((L("시세 %d개 저장")):format(k), "ok")
        ns.Print((L("경매장 시세 %d개를 저장했어요.")):format(k))
    end
end)

function A.ScanAll()
    if scan then return end
    local d = DB()
    local CD = A.CD()
    local left = d and d.lastAll and (CD - (time() - d.lastAll)) or 0
    if left > 0 then Status((L("%d분 뒤에 다시 훑을 수 있어요")):format(math.ceil(left / 60)), "err") return end
    if MODERN and AHC.SendBrowseQuery then
        -- 와우 포에버: 전체 목록 받기(ReplicateItems)가 막혀 있어요 → 빈 검색으로 모든 템 최저가를 끝까지 넘겨 받기
        scan = { browse = true, t0 = GetTime(), last = GetTime() }
        A.browseSeen = 0
        Status(L("경매장에 묻는 중…"), "run"); Bar(0.02)
        local q = { searchString = "", sorts = { { sortOrder = (Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0, reverseSort = false } },
                    filters = {}, itemClassFilters = {} }
        local ok = pcall(AHC.SendBrowseQuery, q)
        if not ok then scan = nil; Bar(nil); Status(L("지금은 전체 훑기를 할 수 없어요 · 잠시 뒤에 다시"), "err") return end
        -- 10초 동안 새 결과가 없으면 거기까지 받은 걸로 끝
        local function Watch()
            if not (scan and scan.browse) then return end
            if GetTime() - (scan.last or 0) > 10 then A.BrowseDone() return end
            C_Timer.After(1, Watch)
        end
        C_Timer.After(1, Watch)
        return
    end
    if not (QueryAuctionItems and CanSendAuctionQuery) then ns.Print(L("이 게임에선 전체 훑기를 쓸 수 없어요 · 찾기만 해도 시세가 쌓여요.")) return end
    local _, all = CanSendAuctionQuery()
    if not all then Status(L("지금은 전체 훑기를 할 수 없어요 · 잠시 뒤에 다시"), "err") return end
    scan = { i = 1, total = 0, book = Book(), seen = {}, wait = true }
    Status(L("경매장에 묻는 중…"), "run"); Bar(0)
    QueryAuctionItems("", nil, nil, 0, false, nil, true)
end

-- 전체 훑기 결과가 왔어요
local function OnAllReady()
    if not (scan and scan.wait) then return false end
    local n = MODERN and AHC.GetNumReplicateItems() or GetNumAuctionItems("list")
    scan.total = math.max(n or 0, 0); scan.wait = nil
    if scan.total == 0 then scan = nil; Bar(nil); Status(L("결과가 없어요"), "err") return true end
    runner:Show()
    return true
end
A.AllReady = OnAllReady
function A.BrowseDone()
    if not (scan and scan.browse) then return end
    local n = scan.n or 0
    scan = nil
    local d = DB(); if d then d.lastAll = time() end
    Bar(nil)
    if n == 0 then Status(L("결과가 없어요"), "err") return end
    Status((L("시세 %d개 저장")):format(n), "ok")
    ns.Print((L("경매장 시세 %d개를 저장했어요.")):format(n))
end

-- A안: 검색 칸 오른쪽 끝에 같은 높이 아이콘 · 칸 안 오른쪽에 상태 글 · 칸 아래 금색 진행 막대
local function MakeButton()
    local host = _G.AuctionHouseFrame or _G.AuctionFrame
    if btn or not host then return end
    local sbox = host.SearchBar and host.SearchBar.SearchBox
    local b = CreateFrame("Button", "LeelUI_AHScan", sbox and sbox:GetParent() or host)
    local sz = sbox and math.floor((sbox:GetHeight() or 22) + 0.5) or 22
    if sz < 18 or sz > 30 then sz = 22 end
    b:SetSize(sz, sz)
    if sbox then b:SetPoint("LEFT", sbox, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", host, "TOPLEFT", 160, -30) end
    b:SetFrameLevel((sbox or host):GetFrameLevel() + 2)
    if sbox then
        msgFS = sbox:CreateFontString(nil, "OVERLAY")
        pcall(msgFS.SetFont, msgFS, ns.FONT, 11, ""); msgFS:SetShadowOffset(1, -1)
        msgFS:SetPoint("RIGHT", sbox, "RIGHT", -8, 0); msgFS:SetJustifyH("RIGHT")
        barBG = sbox:CreateTexture(nil, "OVERLAY"); barBG:SetColorTexture(0, 0, 0, 0.55); barBG:SetHeight(3)
        barBG:SetPoint("TOPLEFT", sbox, "BOTTOMLEFT", 2, -2); barBG:SetPoint("TOPRIGHT", sbox, "BOTTOMRIGHT", -2, -2)
        barFill = sbox:CreateTexture(nil, "OVERLAY", nil, 1); barFill:SetColorTexture(1, 0.78, 0.12, 1); barFill:SetHeight(3)
        barFill:SetPoint("LEFT", barBG, "LEFT", 0, 0); barFill:SetWidth(1)
        barBG:SetScript("OnHide", nil); barBG:Hide()
        hooksecurefunc(barBG, "Hide", function() barFill:Hide() end); hooksecurefunc(barBG, "Show", function() barFill:Show() end)
        barFill:Hide()
    end
    local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetColorTexture(0, 0, 0, 0.85); bg:SetPoint("TOPLEFT", -1, 1); bg:SetPoint("BOTTOMRIGHT", 1, -1)
    local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetAllPoints(); ic:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- 금색 얇은 테 (즐겨찾기 단추와 같은 느낌)
    for _, sd in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 }, { "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
        local e = b:CreateTexture(nil, "OVERLAY")
        e:SetColorTexture(0.62, 0.52, 0.31, 1)
        e:SetPoint(sd[1], b, sd[1], 0, 0); e:SetPoint(sd[2], b, sd[2], 0, 0)
        if sd[3] == 1 then e:SetWidth(1) else e:SetHeight(1) end
    end
    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.18)
    b:SetScript("OnMouseDown", function() ic:SetPoint("TOPLEFT", 1, -1); ic:SetPoint("BOTTOMRIGHT", 1, -1) end)
    b:SetScript("OnMouseUp", function() ic:ClearAllPoints(); ic:SetAllPoints() end)
    local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate"); cd:SetAllPoints(); cd:SetDrawEdge(false)
    pcall(cd.SetHideCountdownNumbers, cd, true)
    b.cd = cd
    b.last = ""
    b:SetScript("OnClick", function() A.ScanAll(); A.PaintBtn() end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:AddLine(L("시세 훑기"), 1, 0.82, 0)
        GameTooltip:AddLine(L(A.CD() < 900 and "경매장 전체 시세 모으기 · 2분에 한 번" or "경매장 전체 시세 모으기 · 15분에 한 번"), 1, 1, 1)
        local d = DB()
        local line = (L("시세 %d개")):format(A.Count())
        if d and d.lastAll then line = Ago(d.lastAll) .. " · " .. line end
        GameTooltip:AddLine(line, 0.7, 0.68, 0.74)
        local left = d and d.lastAll and (A.CD() - (time() - d.lastAll)) or 0
        if left > 0 then GameTooltip:AddLine((L("%d분 뒤에 다시 훑을 수 있어요")):format(math.ceil(left / 60)), 0.94, 0.6, 0.4) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn = b
    A.PaintBtn()
end
-- 15분 기다림을 시계처럼 · 훑는 중엔 %
function A.PaintBtn()
    if not btn then return end
    local d = DB()
    local CD = A.CD()
    local left = d and d.lastAll and (CD - (time() - d.lastAll)) or 0
    if left > 0 and not scan then btn.cd:SetCooldown(GetTime() - (CD - left), CD) else btn.cd:Clear() end
end

local ev = CreateFrame("Frame")
-- 게임마다 있는 이벤트만 (와우 포에버는 새 경매장 · 예전 이벤트는 없어요)
pcall(ev.RegisterEvent, ev, "ADDON_LOADED")
for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "REPLICATE_ITEM_LIST_UPDATE", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
        "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED", "AUCTION_ITEM_LIST_UPDATE" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e, a1)
    if e == "ADDON_LOADED" then
        if (a1 == "Blizzard_AuctionHouseUI" or a1 == "Blizzard_AuctionUI") then
            local host = _G.AuctionHouseFrame or _G.AuctionFrame
            if host then host:HookScript("OnShow", function() if DB() then pcall(MakeButton); if btn then btn:SetShown(DB().tip ~= false) end end end) end
        end
        return
    end
    if not DB() then return end
    if e == "AUCTION_HOUSE_SHOW" then
        -- 경매장 창은 이 순간 처음 만들어져요 → 한 박자 뒤에 단추
        local function Go()
            local ok, err = pcall(MakeButton)
            if not ok and not A.warned then A.warned = true; ns.Print("경매장 단추 오류: " .. tostring(err)) end
            if btn then btn:SetShown(DB().tip ~= false); btn:Raise() end
        end
        Go(); C_Timer.After(0, Go); C_Timer.After(0.3, Go); Status("")
    elseif e == "AUCTION_HOUSE_CLOSED" then if scan then scan = nil; runner:Hide() end
    elseif e == "REPLICATE_ITEM_LIST_UPDATE" then pcall(OnAllReady)
    elseif e == "AUCTION_ITEM_LIST_UPDATE" then if not select(2, pcall(OnAllReady)) then pcall(OnBrowse) end
    elseif e == "COMMODITY_SEARCH_RESULTS_UPDATED" then pcall(OnCommodity, a1)
    elseif e == "ITEM_SEARCH_RESULTS_UPDATED" then pcall(OnItemSearch, a1)
    else
        if e == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then A.browseSeen = 0 end   -- 새로 찾기
        pcall(OnBrowse)
    end
end)

function A.Clear()
    local d = DB(); if d then d.data[Key()] = {}; d.lastAll = nil end
    ns.Print(L("경매장 시세를 비웠어요."))
end
function A.Count() local n = 0; for _ in pairs(Book() or {}) do n = n + 1 end; return n end

-- 점검: /르엘경매
SLASH_LEELAH1 = "/르엘경매"; SLASH_LEELAH2 = "/leelah"
SlashCmdList.LEELAH = function()
    local host = _G.AuctionHouseFrame or _G.AuctionFrame
    ns.Print(("경매장 시세: %d개 · 창 %s · 단추 %s · 새 경매장 %s"):format(A.Count(), host and (host:IsShown() and "열림" or "닫힘") or "없음",
        btn and (btn:IsVisible() and "보임" or "숨음") or "없음", MODERN and "예" or "아니오"))
    ns.Print(("툴팁 호출 %d번 · 마지막 오류: %s · 툴팁 켜짐: %s"):format(A.calls or 0, A.err or "없음", tostring(DB() and DB().tip)))
    if host and host:IsShown() and not btn then local ok, err = pcall(MakeButton); if not ok then ns.Print("단추 오류: " .. tostring(err)) end end
end
