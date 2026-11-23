-- LeelUI / RankUp.lua
-- 단축바 주문 레벨 알림 (A+B안): 주문을 새로 배웠는데 단축바에는 아직 낮은 레벨이 있으면
--   A  화면 위 알약 "되살리기 4레벨 배웠어요 · 단축바 1칸은 아직 3레벨 [바꾸기] [그대로]"
--   B  바꿀 때까지 그 칸에 직업 색 테 + "↑" + 지금 레벨 숫자 · 마우스를 올리면 툴팁에 한 줄
-- 바꾸기는 전투 밖에서만 (게임 규칙) · 매크로 · 아이템 칸은 그대로
-- "일부러" 목록: 힐러처럼 낮은 레벨을 일부러 쓰는 칸은 표시하지 않아요 (허브 > 단축바 주문 레벨)

local _, ns = ...
local C = ns.C

local function DB()
    ns.db.rankup = ns.db.rankup or {}
    local d = ns.db.rankup
    if d.on == nil then d.on = true end
    if d.toast == nil then d.toast = true end
    if d.mark == nil then d.mark = true end
    d.keep = d.keep or {}      -- ["칸:주문ID"] = true  (일부러 낮게)
    return d
end
ns.RankDB = DB

----------------------------------------------------------------------
-- 주문 이름 · 레벨
----------------------------------------------------------------------
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then local ok, n = pcall(C_Spell.GetSpellName, id); if ok and n then return n end end
    local n = GetSpellInfo and GetSpellInfo(id)
    return n
end
local function RankOf(id)
    local sub
    if C_Spell and C_Spell.GetSpellSubtext then local ok, t = pcall(C_Spell.GetSpellSubtext, id); if ok then sub = t end end
    if type(sub) ~= "string" and GetSpellSubtext then local ok, t = pcall(GetSpellSubtext, id); if ok then sub = t end end
    if type(sub) ~= "string" then return nil end
    local n = sub:match("(%d+)")
    return n and tonumber(n) or nil
end

-- 이름 → 배운 가장 높은 레벨 (게임이 이름으로 찾으면 보통 배운 최고 레벨을 줘요)
function ns.RankByName(name)
    local id
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, name)
        if ok and type(info) == "table" then id = info.spellID end
    end
    if not id and GetSpellInfo then local ok, _, _, _, _, _, _, sid = pcall(GetSpellInfo, name); if ok then id = sid end end
    if not id then return end
    if IsPlayerSpell and not IsPlayerSpell(id) and not (IsSpellKnown and IsSpellKnown(id)) then return end
    local r = RankOf(id)
    if r then return { id = id, rank = r } end
end

-- 주문책: 이름 → 가장 높은 레벨 { id, rank }
local best = {}
local function Note(id)
    if not id then return end
    local name = SpellName(id)
    local r = RankOf(id)
    if name and r then
        local b = best[name]
        if not b or r > b.rank then best[name] = { id = id, rank = r } end
    end
end
local function ScanBook()
    wipe(best)
    local SB = C_SpellBook
    -- 새 방식 (C_SpellBook): 게임 판에 따라 옛 함수가 없어요
    if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookItemInfo then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local SPELL = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
        local okN, lines = pcall(SB.GetNumSpellBookSkillLines)
        for t = 1, (okN and lines or 0) do
            local okL, info = pcall(SB.GetSpellBookSkillLineInfo, t)
            if okL and type(info) == "table" then
                local off, num = info.itemIndexOffset or 0, info.numSpellBookItems or 0
                for i = off + 1, off + num do
                    local okI, it = pcall(SB.GetSpellBookItemInfo, i, bank)
                    if okI and type(it) == "table" and (it.itemType == SPELL or it.itemType == 1) and not it.isPassive then
                        Note(it.spellID or it.actionID)
                    end
                end
            end
        end
    end
    -- 옛 방식
    if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
        local BOOK = BOOKTYPE_SPELL or "spell"
        for t = 1, GetNumSpellTabs() or 0 do
            local _, _, offset, num = GetSpellTabInfo(t)
            for i = (offset or 0) + 1, (offset or 0) + (num or 0) do
                local ok, kind, id = pcall(GetSpellBookItemInfo, i, BOOK)
                if ok and kind == "SPELL" and id then Note(id) end
            end
        end
    end
end

----------------------------------------------------------------------
-- 낮은 레벨 칸 찾기
----------------------------------------------------------------------
local low = {}          -- [칸] = { name, rank, bestId, bestRank, id }
local function ScanBars()
    wipe(low)
    for slot = 1, 360 do
        if HasAction(slot) then
            local kind, id = GetActionInfo(slot)
            if kind == "spell" and id then
                local name = SpellName(id)
                local b = name and best[name]
                local r = RankOf(id)
                -- 주문책이 낮은 레벨만 알려줄 때: 이름으로 가장 높은 배운 레벨을 다시 물어봐요
                local nb = name and ns.RankByName and ns.RankByName(name)
                if nb and (not b or nb.rank > b.rank) then b = nb; best[name] = nb end
                if b and r and b.rank > r and not DB().keep[slot .. ":" .. id] then
                    low[slot] = { name = name, rank = r, id = id, bestId = b.id, bestRank = b.rank }
                end
            end
        end
    end
end
local function LowOf(name)
    local list = {}
    for slot, l in pairs(low) do if not name or l.name == name then list[#list + 1] = slot end end
    table.sort(list)
    return list
end
ns.RankLowCount = function() local n = 0; for _ in pairs(low) do n = n + 1 end; return n end

----------------------------------------------------------------------
-- 바꾸기 (전투 밖에서만)
----------------------------------------------------------------------
local pending = false
local Refresh
local function Replace(name)
    if InCombatLockdown() then
        pending = name or true
        ns.Print("전투가 끝나면 단축바 주문을 새 레벨로 바꿔요.")
        return
    end
    ScanBook(); ScanBars()
    local done, names = 0, {}
    for _, slot in ipairs(LowOf(name ~= true and name or nil)) do
        local l = low[slot]
        if l and not GetCursorInfo() then
            local ok = pcall(PickupSpell, l.bestId)
            if ok and GetCursorInfo() then
                PlaceAction(slot)
                ClearCursor()
                done = done + 1
                names[l.name] = l.bestRank
            end
        end
    end
    if done > 0 then
        local parts = {}
        for n, r in pairs(names) do parts[#parts + 1] = n .. " " .. r .. "레벨" end
        ns.Print(ns.L("단축바 %d칸을 새 레벨로 바꿨어요: %s"):format(done, table.concat(parts, ", ")))
    end
    C_Timer.After(0.1, function() if Refresh then Refresh() end end)
end
ns.RankReplaceAll = function() Replace(true) end
ns.RankKeepAll = function()
    local d = DB()
    for slot, l in pairs(low) do d.keep[slot .. ":" .. l.id] = true end
    if Refresh then Refresh() end
end
ns.RankKeepClear = function() DB().keep = {}; ScanBook(); if Refresh then Refresh() end end

----------------------------------------------------------------------
-- B: 단축바 칸 표시 (직업 색 테 + ↑ + 지금 레벨)
----------------------------------------------------------------------
local function ClassCol()
    local _, cls = UnitClass("player")
    local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    return c and { c.r, c.g, c.b } or C.acc
end
ns.RankClassCol = ClassCol

local BTN_NAMES = {
    { "ActionButton", 12 }, { "MultiBarBottomLeftButton", 12 }, { "MultiBarBottomRightButton", 12 },
    { "MultiBarRightButton", 12 }, { "MultiBarLeftButton", 12 }, { "MultiBar5Button", 12 }, { "MultiBar6Button", 12 }, { "MultiBar7Button", 12 },
    { "BT4Button", 180 }, { "DominosActionButton", 180 }, { "ElvUI_Bar1Button", 12 }, { "ElvUI_Bar2Button", 12 }, { "ElvUI_Bar3Button", 12 },
    { "ElvUI_Bar4Button", 12 }, { "ElvUI_Bar5Button", 12 }, { "ElvUI_Bar6Button", 12 },
}
local function SlotOf(b)
    local s = b.action
    if not s and b.GetAttribute then
        local ok, a = pcall(b.GetAttribute, b, "action"); if ok then s = a end
    end
    if not s and b._state_action then s = b._state_action end
    if (not s or s == 0) and ActionButton_GetPagedID then local ok, p = pcall(ActionButton_GetPagedID, b); if ok then s = p end end
    return tonumber(s)
end
local function Mark(b)
    if b.leelRank then return b.leelRank end
    local m = CreateFrame("Frame", nil, b)
    m:SetAllPoints(b); m:SetFrameLevel(b:GetFrameLevel() + 8)
    m:EnableMouse(false)
    local edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = m:CreateTexture(nil, "OVERLAY"); e:SetTexture(ns.WHITE)
        if side == "TOP" or side == "BOTTOM" then e:SetPoint(side .. "LEFT", -1, 0); e:SetPoint(side .. "RIGHT", 1, 0); e:SetHeight(2)
        else e:SetPoint("TOP" .. side, 0, 1); e:SetPoint("BOTTOM" .. side, 0, -1); e:SetWidth(2) end
        edges[#edges + 1] = e
    end
    m.glow = m:CreateTexture(nil, "BACKGROUND"); m.glow:SetTexture(ns.MEDIA .. "soft_glow"); m.glow:SetBlendMode("ADD")
    m.glow:SetPoint("TOPLEFT", -10, 10); m.glow:SetPoint("BOTTOMRIGHT", 10, -10)
    local ag = m.glow:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
    local al = ag:CreateAnimation("Alpha"); al:SetFromAlpha(0.25); al:SetToAlpha(0.7); al:SetDuration(0.9); al:SetSmoothing("IN_OUT")
    m.ag = ag
    -- 오른쪽 위 ↑ 동그라미
    m.badge = CreateFrame("Frame", nil, m); m.badge:SetSize(16, 16); m.badge:SetPoint("CENTER", m, "TOPRIGHT", -2, -2)
    m.badge:SetFrameLevel(m:GetFrameLevel() + 2)
    local bk = m.badge:CreateTexture(nil, "BACKGROUND"); bk:SetTexture(ns.MEDIA .. "circle"); bk:SetPoint("TOPLEFT", -1.5, 1.5); bk:SetPoint("BOTTOMRIGHT", 1.5, -1.5); bk:SetVertexColor(0, 0, 0, 0.9)
    m.disc = m.badge:CreateTexture(nil, "ARTWORK"); m.disc:SetTexture(ns.MEDIA .. "circle"); m.disc:SetAllPoints()
    m.arrow = m.badge:CreateTexture(nil, "OVERLAY"); m.arrow:SetTexture(ns.MEDIA .. "np_arrow"); m.arrow:SetSize(10, 10); m.arrow:SetPoint("CENTER", 0, 0)
    pcall(m.arrow.SetRotation, m.arrow, math.pi); m.arrow:SetVertexColor(0.1, 0.07, 0.06, 1)
    -- 오른쪽 아래 지금 레벨
    m.rk = m:CreateFontString(nil, "OVERLAY"); m.rk:SetFont(ns.NUM or ns.FONT, 12, "OUTLINE"); m.rk:SetPoint("BOTTOMRIGHT", -2, 2)
    m.edges = edges
    m:Hide()
    b.leelRank = m
    return m
end
local seen = {}
local function Buttons()
    local out = {}
    for _, p in ipairs(BTN_NAMES) do
        for i = 1, p[2] do local b = _G[p[1] .. i]; if b then out[#out + 1] = b end end
    end
    return out
end
local function PaintMarks()
    local d = DB()
    local col = ClassCol()
    for _, b in ipairs(Buttons()) do
        local slot = SlotOf(b)
        local l = slot and low[slot]
        if l and d.on and d.mark and b:IsVisible() then
            local m = Mark(b)
            for _, e in ipairs(m.edges) do e:SetVertexColor(col[1], col[2], col[3], 1) end
            m.glow:SetVertexColor(col[1], col[2], col[3], 0.8)
            m.disc:SetVertexColor(col[1], col[2], col[3], 1)
            m.rk:SetText(l.rank); m.rk:SetTextColor(1, 1, 1)
            m:Show(); m.ag:Play()
            seen[b] = true
        elseif b.leelRank then
            b.leelRank:Hide(); b.leelRank.ag:Stop()
        end
    end
end

-- 툴팁 한 줄
if GameTooltip and GameTooltip.SetAction then
    hooksecurefunc(GameTooltip, "SetAction", function(tt, slot)
        local l = low[slot]
        if not (l and DB().on and DB().mark) then return end
        local col = ClassCol()
        tt:AddLine(ns.L("↑ %d레벨 · 배운 최고 %d레벨"):format(l.rank, l.bestRank), col[1], col[2], col[3])
        tt:AddLine("화면 위 알약 [바꾸기] 또는 허브 > 단축바 주문 레벨", 0.75, 0.75, 0.75)
        tt:Show()
    end)
end

----------------------------------------------------------------------
-- A: 화면 위 알약 [바꾸기] [그대로]
----------------------------------------------------------------------
local toast
local function Btn(p, text, hot, fn)
    local b = CreateFrame("Button", nil, p); b:SetHeight(20)
    b.bg = ns.RoundRect(b, 10, hot and C.acc or { 0.42, 0.35, 0.34 }, "ARTWORK", 0, 0)
    if not hot then b.in_ = ns.RoundRect(b, 9, { 0.125, 0.094, 0.086 }, "ARTWORK", 1, 1) end
    b.fs = ns.Font(b, 11.5, hot and C.ink or C.tx); b.fs:SetPoint("CENTER", 0, 0); b.fs:SetShadowColor(0, 0, 0, hot and 0 or 0.8)
    b.fs:SetText(text); b:SetWidth(b.fs:GetStringWidth() + 22)
    b:SetScript("OnClick", fn)
    return b
end
local function ShowToast(name)
    local list = LowOf(name)
    if #list == 0 then return end
    local l = low[list[1]]
    if not toast then
        toast = CreateFrame("Frame", "LeelUI_RankToast", UIParent)
        toast:SetFrameStrata("HIGH"); toast:SetHeight(32)
        toast:SetPoint("TOP", UIParent, "TOP", 0, -112)
        toast.fill, toast.edge = ns.RoundPlate(toast, 16, { 0.125, 0.094, 0.086, 0.97 }, { 0.949, 0.702, 0.761, 0.85 })
        toast.ic = toast:CreateTexture(nil, "ARTWORK"); toast.ic:SetSize(24, 24); toast.ic:SetPoint("LEFT", 5, 0)
        local mk = toast:CreateMaskTexture(); mk:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); mk:SetAllPoints(toast.ic); toast.ic:AddMaskTexture(mk)
        toast.fs = ns.Font(toast, 12.5); toast.fs:SetPoint("LEFT", toast.ic, "RIGHT", 8, 0)
        toast.keep = Btn(toast, "그대로", false, function() toast:Hide() end)
        toast.go = Btn(toast, "바꾸기", true, function() Replace(toast.name or true); toast:Hide() end)
        toast.keep:SetPoint("RIGHT", -6, 0); toast.go:SetPoint("RIGHT", toast.keep, "LEFT", -5, 0)
        toast:SetScript("OnUpdate", function(self, el)
            self.t = (self.t or 0) + el
            if self.t > 10 and not self:IsMouseOver() then
                local a = 1 - (self.t - 10) / 0.5
                if a <= 0 then self:Hide() else self:SetAlpha(a) end
            end
        end)
    end
    toast.name = name
    local tex = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(l.bestId)) or (GetSpellTexture and GetSpellTexture(l.bestId))
    toast.ic:SetTexture(tex)
    local acc = "|cffffd0db"
    toast.fs:SetText(ns.L("%s%s %d레벨|r 배웠어요 · 단축바 |cffff9a4d%d칸|r은 아직 %d레벨"):format(acc, l.name, l.bestRank, #list, l.rank))
    toast:SetWidth(5 + 24 + 8 + toast.fs:GetStringWidth() + 12 + toast.go:GetWidth() + 5 + toast.keep:GetWidth() + 8)
    toast.t = 0; toast:SetAlpha(1); toast:Show()
end

----------------------------------------------------------------------
Refresh = function()
    if not ns.db then return end
    ScanBook(); ScanBars(); PaintMarks()
end
ns.RankRefresh = Refresh

local learned = {}
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, e, a1)
    if e == "PLAYER_LOGIN" then
        if not ns.db then return end
        for _, x in ipairs({ "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE", "SPELLS_CHANGED", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
                             "UPDATE_BONUS_ACTIONBAR", "PLAYER_REGEN_ENABLED", "UPDATE_SHAPESHIFT_FORM" }) do pcall(self.RegisterEvent, self, x) end
        C_Timer.After(2, Refresh)
        return
    end
    if e == "LEARNED_SPELL_IN_TAB" or e == "LEARNED_SPELL_IN_SKILL_LINE" then
        local name = a1 and SpellName(a1)
        if name then learned[name] = true end
        -- 트레이너에서 여러 개를 한꺼번에 배워도 한 번에 (잠깐 모았다가)
        if not self.wait then
            self.wait = true
            C_Timer.After(1, function()
                self.wait = false
                Refresh()
                if DB().on and DB().toast then
                    for n in pairs(learned) do if #LowOf(n) > 0 then ShowToast(n); break end end
                end
                wipe(learned)
            end)
        end
        return
    end
    if e == "PLAYER_REGEN_ENABLED" and pending then
        local n = pending; pending = false
        Replace(n)
        return
    end
    if self.soon then return end
    self.soon = true
    C_Timer.After(0.3, function() self.soon = false; Refresh() end)
end)

-- 점검: /lrank  (주문책에서 읽은 주문 수 · 낮은 레벨 칸)
SLASH_LEELRANK1 = "/lrank"
SlashCmdList.LEELRANK = function(msg)
    local want = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    ScanBook(); ScanBars()
    local nb = 0; for _ in pairs(best) do nb = nb + 1 end
    print(("|cfff2b3c2[LeelUI rank]|r book=%d · low=%d · C_SpellBook=%s · GetNumSpellTabs=%s"):format(nb, ns.RankLowCount(),
        tostring(C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines ~= nil), tostring(GetNumSpellTabs ~= nil)))
    for slot, l in pairs(low) do print(("  slot %d: %s %d → %d"):format(slot, l.name, l.rank, l.bestRank)) end
    local n = 0
    for slot = 1, 360 do
        if HasAction(slot) and n < 14 then
            local kind, id = GetActionInfo(slot)
            local name = kind == "spell" and id and SpellName(id)
            if name and RankOf(id) and (want == "" or name:find(want, 1, true)) then
                local b = best[name]; local nb = ns.RankByName(name)
                n = n + 1
                print(("  slot %d · %s id%d r%s · book %s · name %s"):format(slot, tostring(name), id, tostring(RankOf(id)),
                    b and (b.id .. " r" .. b.rank) or "-", nb and (nb.id .. " r" .. nb.rank) or "-"))
            end
        end
    end
end
