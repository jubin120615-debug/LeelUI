-- 르엘 UI · 가방 골드 툴팁 (B안): 르엘 가방 아래 소지 골드에 마우스를 올리면
--   맨 위 내 캐릭 모두 합 (크게) · 어제보다 얼마 · 캐릭별 막대
--   "우편함에서 기다리는 것": 경매 판매금 · 창고 재료 우편 · 곧 사라질 우편 · 받으면 모두 얼마
--   Shift = 다른 진영 캐릭도
-- 와우는 다른 캐릭 우편함을 못 읽어요 → 그 캐릭이 우편함을 열었을 때 적어 두고, 창고로 보낸 우편은 보낼 때 더해 둬요
-- 기록 자리: 창고 부캐와 같은 ns.db.alts[서버-진영][캐릭] (gold · gh = 날마다 골드 · mail)

local ADDON, ns = ...
local C = ns.C
local L = function(s) return ns.L and ns.L(s) or s end
local DAY = 86400
local function Today() return math.floor(time() / DAY) end

local function Me() return ns.StashMeRec and ns.StashMeRec() end
local function Pretty(n) return ns.StashPretty and ns.StashPretty(n) or n end

----------------------------------------------------------------------
-- 기록
----------------------------------------------------------------------
local function RecordGold()
    local r = Me(); if not r then return end
    local g = GetMoney and GetMoney() or 0
    r.gold = g
    r.gh = r.gh or {}
    local d = Today()
    r.gh[d] = g
    for k in pairs(r.gh) do if k < d - 8 then r.gh[k] = nil end end
end

local function RecordMail()
    local r = Me(); if not r then return end
    local n = GetInboxNumItems and GetInboxNumItems() or 0
    local m = { n = n, money = 0, sold = 0, soldMoney = 0, stash = 0, items = 0, exp = nil, t = time() }
    for i = 1, n do
        local ok, _, _, _, subject, money, cod, daysLeft, hasItem = pcall(GetInboxHeaderInfo, i)
        if ok then
            money = tonumber(money) or 0
            m.money = m.money + money
            if hasItem then m.items = m.items + (tonumber(hasItem) or 1) end
            if type(subject) == "string" and subject:find("르엘 창고", 1, true) == 1 then m.stash = m.stash + 1 end
            local inv = GetInboxInvoiceInfo and GetInboxInvoiceInfo(i)
            if inv == "seller" then m.sold = m.sold + 1; m.soldMoney = m.soldMoney + money end
            if daysLeft and (not m.exp or daysLeft < m.exp) then m.exp = daysLeft end
        end
    end
    r.mail = m
end

-- 창고로 보낸 우편: 받는 캐릭 칸에 1통 더 (30일 뒤 사라져요)
function ns.GoldTipMailSent(target, items)
    if not (target and ns.StashAlts) then return end
    local a = ns.StashAlts()
    local r = a and a[target]
    if not r then r = {}; a[target] = r end
    local m = r.mail or { n = 0, money = 0, sold = 0, soldMoney = 0, stash = 0, items = 0, t = time() }
    m.n = (m.n or 0) + 1
    m.stash = (m.stash or 0) + 1
    m.items = (m.items or 0) + (items or 0)
    if not m.exp or m.exp > 30 then m.exp = 30 end
    r.mail = m
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_MONEY", "PLAYER_LOGOUT", "MAIL_INBOX_UPDATE", "MAIL_SHOW" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, e)
    if not ns.db then return end
    if e == "PLAYER_LOGIN" then C_Timer.After(3, RecordGold)
    elseif e == "PLAYER_MONEY" or e == "PLAYER_LOGOUT" then pcall(RecordGold)
    elseif e == "MAIL_INBOX_UPDATE" or e == "MAIL_SHOW" then C_Timer.After(0.3, function() pcall(RecordMail) end) end
end)

----------------------------------------------------------------------
-- 돈 글씨
----------------------------------------------------------------------
local function Money(c, big)
    c = math.floor((c or 0) + 0.5)
    local g, s, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local en = ns.EnOn and ns.EnOn()
    local G, S, CP = en and "g" or "금", en and "s" or "은", en and "c" or "동"
    local t = {}
    if g > 0 then t[#t + 1] = ("|cffffd25a%s|r%s"):format(BreakUpLargeNumbers and BreakUpLargeNumbers(g) or g, G) end
    if s > 0 or g > 0 then t[#t + 1] = ("|cffd8d8d8%d|r%s"):format(s, S) end
    if not big or g == 0 then if cp > 0 or #t == 0 then t[#t + 1] = ("|cffe8a060%d|r%s"):format(cp, CP) end end
    return table.concat(t, " ")
end
local function DaysAgo(t) return math.floor((time() - (t or time())) / DAY) end

----------------------------------------------------------------------
-- 툴팁 판
----------------------------------------------------------------------
local T, rows, mrows = nil, {}, {}
local W = 360
local ACC = C and C.acc or { 0.949, 0.702, 0.761 }

local function F(parent, size, col) return ns.Font(parent, size, col) end

local function Build()
    T = CreateFrame("Frame", "LeelUI_GoldTip", UIParent)
    T:SetFrameStrata("TOOLTIP")
    T:SetWidth(W)
    if ns.RoundPlate then ns.RoundPlate(T, 16, { 0.1, 0.075, 0.07, 0.98 }, { ACC[1], ACC[2], ACC[3], 0.55 }) end
    T.bun = T:CreateTexture(nil, "ARTWORK"); T.bun:SetTexture(ns.MEDIA .. "bunny"); T.bun:SetSize(26, 26); T.bun:SetPoint("TOPLEFT", 14, -14)
    T.lab = F(T, 11.5, { 0.66, 0.59, 0.57 }); T.lab:SetPoint("TOPLEFT", T.bun, "TOPRIGHT", 8, 2); T.lab:SetText(L("내 캐릭 모두"))
    T.total = F(T, 22, { 1, 1, 1 }); T.total:SetPoint("TOPLEFT", T.lab, "BOTTOMLEFT", 0, -3)
    T.delta = F(T, 11.5, { 0.62, 0.89, 0.75 }); T.delta:SetPoint("TOPRIGHT", -14, -16); T.delta:SetJustifyH("RIGHT")
    T.h1 = F(T, 12, ACC); T.h1:SetText(L("캐릭별"))
    T.h2 = F(T, 12, ACC); T.h2:SetText(L("우편함에서 기다리는 것"))
    T.foot = F(T, 11, { 0.56, 0.5, 0.48 })
    T:Hide()
end

local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, T); r:SetHeight(22)
    r.name = F(r, 12.5); r.name:SetPoint("LEFT", 0, 0); r.name:SetWidth(108); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.track = r:CreateTexture(nil, "ARTWORK"); r.track:SetColorTexture(0.23, 0.17, 0.16, 1); r.track:SetSize(120, 6)
    r.track:SetPoint("LEFT", 112, 0)
    r.bar = r:CreateTexture(nil, "OVERLAY"); r.bar:SetHeight(6); r.bar:SetPoint("LEFT", r.track, "LEFT", 0, 0)
    r.gold = F(r, 12.5, { 1, 1, 1 }); r.gold:SetPoint("RIGHT", 0, 0); r.gold:SetJustifyH("RIGHT")
    rows[i] = r
    return r
end
local function MRow(i)
    local r = mrows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, T); r:SetHeight(40)
    r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetColorTexture(0.14, 0.105, 0.098, 1)
    r.ic = r:CreateTexture(nil, "ARTWORK"); r.ic:SetTexture("Interface\\Icons\\INV_Letter_15"); r.ic:SetSize(18, 18); r.ic:SetPoint("LEFT", 8, 0)
    r.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.t1 = F(r, 12.5, { 0.94, 0.89, 0.87 }); r.t1:SetPoint("TOPLEFT", r.ic, "TOPRIGHT", 8, 4); r.t1:SetPoint("RIGHT", -8, 0)
    r.t1:SetJustifyH("LEFT"); r.t1:SetWordWrap(false)
    r.t2 = F(r, 11, { 0.66, 0.59, 0.57 }); r.t2:SetPoint("TOPLEFT", r.t1, "BOTTOMLEFT", 0, -3)
    mrows[i] = r
    return r
end

local function ClassHex(cls)
    local cc = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    return cc and cc.r or 0.85, cc and cc.g or 0.78, cc and cc.b or 0.76
end

local function Show(owner)
    if not ns.db then return end
    if not T then Build() end
    RecordGold()
    local myName = ns.StashMe and ns.StashMe()
    local all = IsShiftKeyDown()
    -- 모을 캐릭: 이 진영 (Shift = 모두)
    local list = {}
    local cur = ns.StashAlts and ns.StashAlts()
    for k, bucket in pairs(ns.db.alts or {}) do
        if type(bucket) == "table" and (all or bucket == cur) then
            for name, r in pairs(bucket) do
                if type(r) == "table" and (r.gold or r.mail) then
                    list[#list + 1] = { name = name, r = r, other = bucket ~= cur, fac = type(k) == "string" and k:match("%-(%a+)$") }
                end
            end
        end
    end
    table.sort(list, function(a, b) return (a.r.gold or 0) > (b.r.gold or 0) end)
    -- 합 · 어제
    local total, yest, maxg = 0, 0, 1
    local today = Today()
    for _, c in ipairs(list) do
        local g = c.r.gold or 0
        total = total + g
        if g > maxg then maxg = g end
        -- 어제(혹은 그 전 가장 가까운 날) 골드 · 없으면 지금 값
        local best, bd
        for d, v in pairs(c.r.gh or {}) do if d < today and (not bd or d > bd) then bd, best = d, v end end
        yest = yest + (best or g)
    end
    T.total:SetText(Money(total, true))
    local dlt = total - yest
    if math.abs(dlt) >= 10000 then
        T.delta:SetText(L("어제보다") .. "\n" .. (dlt > 0 and "+" or "-") .. math.floor(math.abs(dlt) / 10000) .. (ns.EnOn and ns.EnOn() and "g" or "금"))
        if dlt > 0 then T.delta:SetTextColor(0.62, 0.89, 0.75) else T.delta:SetTextColor(0.95, 0.6, 0.6) end
        T.delta:Show()
    else T.delta:Hide() end
    -- 캐릭별 막대
    local y = -62
    T.h1:ClearAllPoints(); T.h1:SetPoint("TOPLEFT", 14, y); y = y - 18
    for _, r in ipairs(rows) do r:Hide() end
    for i, c in ipairs(list) do
        if i > 12 then break end
        local r = Row(i)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 14, y); r:SetPoint("RIGHT", T, "RIGHT", -14, 0)
        local cr, cg, cb = ClassHex(c.r.cls)
        r.name:SetText(Pretty(c.name) .. (c.name == myName and " |cffa99692·|r" or "") .. (c.other and ("  |cff8f7f7b" .. L(c.fac == "Alliance" and "얼라" or "호드") .. "|r") or ""))
        r.name:SetTextColor(cr, cg, cb)
        local w = math.max(1, 120 * (c.r.gold or 0) / maxg)
        r.bar:SetWidth(w); r.bar:SetColorTexture(cr, cg, cb, 1)
        r.gold:SetText(Money(c.r.gold or 0, true))
        r:Show()
        y = y - 22
    end
    -- 우편
    for _, r in ipairs(mrows) do r:Hide() end
    local waiting, mi = 0, 0
    for _, c in ipairs(list) do
        local m = c.r.mail
        if m and (m.n or 0) > 0 then
            mi = mi + 1
            if mi == 1 then y = y - 8; T.h2:ClearAllPoints(); T.h2:SetPoint("TOPLEFT", 14, y); T.h2:Show(); y = y - 18 end
            local r = MRow(mi)
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 14, y); r:SetPoint("RIGHT", T, "RIGHT", -14, 0)
            local cr, cg, cb = ClassHex(c.r.cls)
            local parts = {}
            if (m.sold or 0) > 0 then parts[#parts + 1] = L("경매 판매") .. " " .. m.sold .. L("통") .. " " .. Money(m.soldMoney or 0, true) end
            local rest = (m.n or 0) - (m.sold or 0) - (m.stash or 0)
            if (m.stash or 0) > 0 then parts[#parts + 1] = L("창고 재료") .. " " .. m.stash .. L("통") end
            if rest > 0 then parts[#parts + 1] = L("우편") .. " " .. rest .. L("통") end
            local other = (m.money or 0) - (m.soldMoney or 0)
            if other > 0 then parts[#parts + 1] = Money(other, true) end
            r.t1:SetText(("|cff%02x%02x%02x%s|r  "):format(math.floor(cr * 255), math.floor(cg * 255), math.floor(cb * 255), Pretty(c.name)) .. table.concat(parts, " · "))
            local left = m.exp and math.floor(m.exp - (time() - (m.t or time())) / DAY)
            local seen = DaysAgo(m.t)
            local line = {}
            if left then
                if left <= 3 then line[#line + 1] = "|cfff29a9a" .. (left <= 0 and L("오늘 사라져요") or (left .. L("일 뒤 사라짐"))) .. "|r"
                else line[#line + 1] = left .. L("일 남음") end
            end
            line[#line + 1] = seen <= 0 and L("오늘 확인") or (seen .. L("일 전 확인"))
            r.t2:SetText(table.concat(line, " · "))
            r:Show()
            y = y - 44
            waiting = waiting + (m.money or 0)
        end
    end
    if mi == 0 then T.h2:Hide() end
    y = y - 6
    T.foot:ClearAllPoints(); T.foot:SetPoint("TOPLEFT", 14, y)
    local f = {}
    if waiting > 0 then f[#f + 1] = L("받으면 모두") .. " " .. Money(total + waiting, true) end
    f[#f + 1] = all and L("Shift 떼면 이 진영만") or L("Shift = 다른 진영 캐릭도")
    T.foot:SetText(table.concat(f, " · "))
    y = y - 18
    T:SetHeight(-y + 12)
    T:ClearAllPoints()
    T:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", 10, 8)
    T:SetClampedToScreen(true)
    T:Show()
end

ns.GoldTipShow = Show

----------------------------------------------------------------------
-- 르엘 가방 골드 자리에 마우스 칸
----------------------------------------------------------------------
local hot
local function Attach()
    local win = _G.LeelUI_Bag
    if hot or not (win and win.money) then return false end
    hot = CreateFrame("Frame", nil, win)
    hot:SetPoint("TOPLEFT", win.money, "TOPLEFT", -8, 6)
    hot:SetPoint("BOTTOMRIGHT", win.money, "BOTTOMRIGHT", 6, -6)
    hot:SetFrameLevel(win:GetFrameLevel() + 10)
    hot:EnableMouse(true)
    hot:SetScript("OnEnter", function(self) self.shift = IsShiftKeyDown(); pcall(Show, self) end)
    hot:SetScript("OnLeave", function() if T then T:Hide() end end)
    -- Shift 누르고 떼면 바로 다시 그려요
    hot:SetScript("OnUpdate", function(self)
        if T and T:IsShown() and IsShiftKeyDown() ~= self.shift then self.shift = IsShiftKeyDown(); pcall(Show, self) end
    end)
    return true
end
local tries = 0
local att = CreateFrame("Frame")
att:SetScript("OnUpdate", function(self, el)
    tries = tries + el
    if tries < 1 then return end
    tries = 0
    if Attach() then self:SetScript("OnUpdate", nil) end
end)
