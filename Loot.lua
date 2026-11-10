-- LeelUI / Loot.lua
-- 르엘 줍기 창: 게임 기본 '아이템' 창 대신 분홍 카드 목록 (A)
-- 줍기 소식: 주운 템/돈을 캐릭터 머리 위에 알약으로 잠깐 (C). 자동 줍기 땐 창 없이 소식만,
-- 가방이 꽉 차서 못 주운 게 남으면 그때만 창.

local _, ns = ...
local C = ns.C

local function DB()
    ns.db.loot = ns.db.loot or {}
    local d = ns.db.loot
    if d.win == nil then d.win = true end
    d.feed = false -- 줍기 소식(C)은 안 씀: 줍기 창(A)만
    return d
end
ns.LootDB = DB

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo

local function QColor(q)
    local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    if q and GetItemQualityColor then
        local ok, r, g, b = pcall(GetItemQualityColor, q)
        if ok and r then return r, g, b end
    end
    return 1, 1, 1
end

local QNAME = { [0] = "하급", [1] = "일반", [2] = "고급", [3] = "희귀", [4] = "영웅", [5] = "전설" }

----------------------------------------------------------------------
-- A. 분홍 카드 목록 창
----------------------------------------------------------------------
local ROW_H, W = 44, 244
local win
local rows = {}

local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, win)
    r:SetSize(W - 16, ROW_H - 4)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.bg = ns.RoundRect(r, 11, { 0.949, 0.702, 0.761 }, "BACKGROUND", 1, 0)
    r.bg:SetColor({ 0.949, 0.702, 0.761 }, 0.06)
    r.bar = r:CreateTexture(nil, "ARTWORK")
    r.bar:SetTexture(ns.WHITE or "Interface\\Buttons\\WHITE8X8")
    r.bar:SetSize(3, ROW_H - 22); r.bar:SetPoint("LEFT", 5, 0)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(32, 32); r.icon:SetPoint("LEFT", 14, 0); r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.count = r:CreateFontString(nil, "OVERLAY")
    r.count:SetFont(ns.NUM or ns.FONT, 13, "OUTLINE"); r.count:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 1, -1)
    r.name = ns.Font(r, 12.5)
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 9, -1); r.name:SetPoint("RIGHT", -8, 0)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.sub = ns.Font(r, 10, { 0.62, 0.54, 0.52 })
    r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetTexture(ns.WHITE or "Interface\\Buttons\\WHITE8X8"); r.hl:SetAllPoints()
    r.hl:SetVertexColor(1, 0.84, 0.88, 0.06)
    r:SetScript("OnEnter", function(self)
        if not self.slot then return end
        if GetLootSlotType and GetLootSlotType(self.slot) == (Enum and Enum.LootSlotType and Enum.LootSlotType.Item or 1) then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetLootItem, GameTooltip, self.slot)
            GameTooltip:Show()
        end
        if CursorUpdate then CursorUpdate(self) end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide(); ResetCursor() end)
    r:SetScript("OnClick", function(self)
        if not self.slot then return end
        if IsModifiedClick() and HandleModifiedItemClick then
            local link = GetLootSlotLink(self.slot)
            if link and HandleModifiedItemClick(link) then return end
        end
        LootSlot(self.slot)
    end)
    rows[i] = r
    return r
end

local function MoneyText(text)
    -- 돈 칸 이름 예: "12 은\n40 동" → 한 줄로
    return (text or ""):gsub("\n", " ")
end

local function Fill()
    local n = GetNumLootItems() or 0
    local shown = 0
    for i = 1, n do
        local tex, name, qty, _, quality, locked, isQuest = GetLootSlotInfo(i)
        local r = Row(i)
        if tex then
            shown = shown + 1
            r.slot = i
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 8, -40 - (shown - 1) * ROW_H)
            r.icon:SetTexture(tex)
            r.icon:SetDesaturated(locked and true or false)
            local money = GetLootSlotType and GetLootSlotType(i) == (Enum and Enum.LootSlotType and Enum.LootSlotType.Money or 2)
            if money then
                r.name:SetText(MoneyText(name)); r.name:SetTextColor(1, 0.84, 0.42)
                r.sub:SetText("돈"); r.bar:SetVertexColor(1, 0.84, 0.42, 1)
                r.count:SetText("")
            else
                local cr, cg, cb = QColor(quality)
                r.name:SetText(name or ""); r.name:SetTextColor(cr, cg, cb)
                r.bar:SetVertexColor(cr, cg, cb, 1)
                r.sub:SetText(isQuest and "|cffffd76a퀘스트 템|r" or (QNAME[quality or 1] or ""))
                r.count:SetText((qty and qty > 1) and qty or "")
            end
            r:Show()
        else
            r.slot = nil
            r:Hide()
        end
    end
    for i = n + 1, #rows do rows[i].slot = nil; rows[i]:Hide() end
    win:SetHeight(40 + shown * ROW_H + 44)
    return shown
end

local function Title()
    local name
    if UnitExists("target") and UnitIsDead("target") then name = UnitName("target") end
    if not name and UnitExists("mouseover") and UnitIsDead("mouseover") then name = UnitName("mouseover") end
    return name or "줍기"
end

local function PlaceAtCursor()
    win:ClearAllPoints()
    local x, y = GetCursorPosition()
    local s = win:GetEffectiveScale()
    win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s - 30, y / s + 20)
end

local function BuildWin()
    win = CreateFrame("Frame", "LeelUI_Loot", UIParent)
    win:SetSize(W, 160)
    win:SetFrameStrata("HIGH")
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:SetMovable(true); win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
    ns.RoundPlate(win, 16, { 0.125, 0.094, 0.086, 0.97 }, { 0.949, 0.702, 0.761, 0.7 })

    local bunny = win:CreateTexture(nil, "ARTWORK")
    bunny:SetTexture(ns.MEDIA .. "bag_bunny"); bunny:SetSize(24, 24); bunny:SetPoint("TOPLEFT", 10, -8)
    win.title = ns.Font(win, 13, C.accHi)
    win.title:SetPoint("LEFT", bunny, "RIGHT", 7, 0); win.title:SetPoint("RIGHT", -34, 0)
    win.title:SetJustifyH("LEFT"); win.title:SetWordWrap(false)

    local x = CreateFrame("Button", nil, win)
    x:SetSize(20, 20); x:SetPoint("TOPRIGHT", -9, -10)
    local xt = x:CreateTexture(nil, "ARTWORK"); xt:SetTexture(ns.MEDIA .. "hb_x"); xt:SetAllPoints()
    xt:SetVertexColor(C.tx[1], C.tx[2], C.tx[3], 0.7)
    x:SetScript("OnEnter", function() xt:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1) end)
    x:SetScript("OnLeave", function() xt:SetVertexColor(C.tx[1], C.tx[2], C.tx[3], 0.7) end)
    x:SetScript("OnClick", function() win.open = false; win.fading = nil; CloseLoot(); win:Hide() end)

    win.all = ns.MakeButton(win, "모두 줍기", true, function()
        for i = 1, (GetNumLootItems() or 0) do
            if GetLootSlotInfo(i) then LootSlot(i) end
        end
    end, 96)
    win.all:SetHeight(26)
    win.all:SetPoint("BOTTOM", 0, 10)

    -- ESC로 닫으면 줍기도 끝내기
    win:SetScript("OnHide", function() if win.open then win.open = false; CloseLoot() end end)
    tinsert(UISpecialFrames, "LeelUI_Loot")
    win:Hide()
end

local HOLD, FADE = 0.2, 0.01   -- 다 주운 뒤 보여 주는 시간, 사라지는 시간

local function ShowWin()
    if not win then BuildWin() end
    win.title:SetText(Title())
    win.fading = nil
    win:SetScript("OnUpdate", nil)
    win:SetAlpha(1)
    win.all:Show()
    for _, r in ipairs(rows) do r:SetAlpha(1); r.icon:SetDesaturated(false); r.count:SetTextColor(1, 1, 1) end
    if Fill() == 0 then return end
    PlaceAtCursor()
    win.open = true
    win:Show()
end

-- 주운 칸: 지우지 않고 흐리게 + '주웠어요' (무엇을 주웠는지 보이게)
local function MarkLooted(slot)
    local r = rows[slot]
    if not (r and r:IsShown() and r.slot) then return end
    r.slot = nil
    r.icon:SetDesaturated(true)
    r:SetAlpha(0.55)
    r.name:SetTextColor(0.55, 0.55, 0.55)
    r.bar:SetVertexColor(0.45, 0.45, 0.45, 1)
    r.count:SetTextColor(0.6, 0.6, 0.6)
    r.sub:SetText("")
end

local function AllLooted()
    for _, r in ipairs(rows) do if r:IsShown() and r.slot then return false end end
    return true
end

-- 다 주웠거나 줍기가 끝나면: 잠깐 보여 준 뒤 스르르 (마우스를 올리고 있으면 기다림)
local function HideWin(now)
    if not win or not win:IsShown() then return end
    win.open = false
    if now then win.fading = nil; win:Hide() return end
    if win.fading then return end
    win.fading = 0
    win.all:Hide()
    win:SetScript("OnUpdate", function(self, el)
        if not self.fading then self:SetScript("OnUpdate", nil) return end
        self.fading = self.fading + el
        if self.fading > HOLD then
            local a = 1 - (self.fading - HOLD) / FADE
            if a <= 0 then self.fading = nil; self:SetScript("OnUpdate", nil); self:Hide()
            else self:SetAlpha(a) end
        end
    end)
end

-- 게임 기본 창은 안 뜨게 (이벤트만 끊음. 줍기 기능은 그대로)
local function MuteBlizz()
    local lf = _G.LootFrame
    if not lf or lf.leelMuted then return end
    lf.leelMuted = true
    pcall(lf.UnregisterEvent, lf, "LOOT_OPENED")
    pcall(lf.UnregisterEvent, lf, "LOOT_SLOT_CLEARED")
    pcall(lf.UnregisterEvent, lf, "LOOT_SLOT_CHANGED")
    pcall(lf.UnregisterEvent, lf, "LOOT_CLOSED")
    hooksecurefunc(lf, "Show", function(self) if DB().win then self:Hide() end end)
end

----------------------------------------------------------------------
-- C. 줍기 소식 알약 (오른쪽)
----------------------------------------------------------------------
local pills = {}
local function Reflow()
    local list = {}
    for _, p in ipairs(pills) do if p:IsShown() then list[#list + 1] = p end end
    table.sort(list, function(a, b) return a.t0 > b.t0 end)
    -- 캐릭터(=방금 주운 시체) 머리 위: 새 소식이 아래, 지난 소식은 위로 밀려 올라감
    for i, p in ipairs(list) do
        p:ClearAllPoints()
        p:SetPoint("BOTTOM", UIParent, "CENTER", 0, 120 + (i - 1) * 32 + (p.rise or 0))
    end
end

local function Pill(icon, text, color)
    local p
    for _, q in ipairs(pills) do if not q:IsShown() then p = q break end end
    if not p then
        if #pills >= 6 then
            table.sort(pills, function(a, b) return a.t0 < b.t0 end)
            p = pills[1]
        else
            p = CreateFrame("Frame", nil, UIParent)
            p:SetHeight(28); p:SetFrameStrata("MEDIUM")
            p.fill, p.edge = ns.RoundPlate(p, 14, { 0.125, 0.094, 0.086, 0.94 }, { 0.949, 0.702, 0.761, 0.6 })
            p.ic = p:CreateTexture(nil, "ARTWORK"); p.ic:SetSize(22, 22); p.ic:SetPoint("LEFT", 3, 0)
            p.mask = p:CreateMaskTexture()
            p.mask:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            p.mask:SetAllPoints(p.ic); p.ic:AddMaskTexture(p.mask)
            p.fs = ns.Font(p, 12); p.fs:SetPoint("LEFT", p.ic, "RIGHT", 7, 0)
            p:SetScript("OnUpdate", function(self, el)
                self.t = self.t + el
                -- 살짝 떠오르기
                local r = math.min(12, self.t * 6)
                if math.abs((self.rise or 0) - r) > 0.5 then self.rise = r; Reflow() end
                if self.t < 0.25 then self:SetAlpha(self.t / 0.25)
                elseif self.t > 4 then
                    local a = 1 - (self.t - 4) / 0.6
                    if a <= 0 then self:Hide(); Reflow() else self:SetAlpha(a) end
                else self:SetAlpha(1) end
            end)
            pills[#pills + 1] = p
        end
    end
    p.ic:SetTexture(icon)
    p.fs:SetText(text)
    if color then p.fs:SetTextColor(color[1], color[2], color[3]) else p.fs:SetTextColor(C.tx[1], C.tx[2], C.tx[3]) end
    p:SetWidth(math.min(300, p.fs:GetStringWidth() + 44))
    p.t, p.t0, p.rise = 0, GetTime(), 0
    p:SetAlpha(0)
    p:Show()
    Reflow()
end

local looting, lastMoney = false, nil
local function OnLootMsg(text, author, guid)
    if not DB().feed or type(text) ~= "string" then return end
    local mine = (guid and guid == UnitGUID("player")) or (author and Ambiguate and Ambiguate(author, "short") == UnitName("player"))
    if not mine then return end
    local link = text:match("|c.-|H.-|h.-|h|r")
    if not link then return end
    local qty = tonumber(text:match("[x×](%d+)") or "") or 1
    local _, _, q, _, _, _, _, _, _, tex = GetItemInfo(link)
    local nm = link:match("%[(.-)%]") or link
    local r, g, b = QColor(q)
    Pill(tex or C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(link) or 134400,
        nm .. (qty > 1 and ("  |cffffd6e0×" .. qty .. "|r") or ""), { r, g, b })
end

----------------------------------------------------------------------
-- 이벤트
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_SLOT_CHANGED", "LOOT_CLOSED",
                     "CHAT_MSG_LOOT", "PLAYER_MONEY" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, a1, a2, ...)
    if event == "PLAYER_LOGIN" then
        DB()
        lastMoney = GetMoney()
        if DB().win then MuteBlizz() end
        return
    end
    if not ns.db then return end
    local d = DB()
    if event == "LOOT_OPENED" then
        looting = true
        if not d.win then return end
        -- 자동 줍기여도 창은 띄움: 주운 칸은 '주웠어요'로 남았다가 잠깐 뒤 사라짐
        ShowWin()
    elseif event == "LOOT_SLOT_CLEARED" then
        if win and win:IsShown() then
            MarkLooted(a1)
            if AllLooted() then HideWin() end
        end
    elseif event == "LOOT_SLOT_CHANGED" then
        if win and win:IsShown() and win.open then Fill() end
    elseif event == "LOOT_CLOSED" then
        HideWin()
        C_Timer.After(1, function() looting = false end)
    elseif event == "CHAT_MSG_LOOT" then
        local guid = select(10, ...) -- 12번째 인자
        OnLootMsg(a1, a2, guid)
    elseif event == "PLAYER_MONEY" then
        local now = GetMoney()
        if looting and d.feed and lastMoney and now > lastMoney and ns.BunnyMoney then
            Pill(ns.MEDIA .. "coin_s", ns.BunnyMoney(now - lastMoney, 12), { 1, 0.84, 0.42 })
        end
        lastMoney = now
    end
end)

-- 미리 보기: /르엘소식
SLASH_LEELLOOTFEED1 = "/르엘소식"
SlashCmdList.LEELLOOTFEED = function()
    Pill(134400, "줍기 소식 미리보기  |cffffd6e0×2|r", { 1, 1, 1 })
    if ns.BunnyMoney then Pill(ns.MEDIA .. "coin_s", ns.BunnyMoney(1240, 12), { 1, 0.84, 0.42 }) end
end
