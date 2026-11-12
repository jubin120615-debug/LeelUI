-- LeelUI / Chat.lua
-- 르엘 채팅창 (D안): 왼쪽 채널 기둥 + 분홍 테 카드 + 머리줄 + 입력 알약 + "새 글 N개" 알약
-- 글 내용은 블리자드 그대로. 겉모양과 탭만 바꿈. 묶여 있는(도킹된) 채팅창만 다룸.
-- 끄기: 허브 > 화면 > 채팅창 (다시 불러오기)

local _, ns = ...
local C = ns.C

local RAIL, HEAD, EDIT, PAD = 52, 28, 28, 8
local CORAL = { 1, 0.48, 0.40 }

local function DB()
    ns.db.chat = ns.db.chat or {}
    local d = ns.db.chat
    if d.on == nil then d.on = true end
    return d
end
ns.ChatDB = DB

local function Docked()
    local list = {}
    local ok, frames = pcall(FCFDock_GetChatFrames, GENERAL_CHAT_DOCK)
    if ok and frames then
        for _, f in ipairs(frames) do list[#list + 1] = f end
    end
    if #list == 0 then list[1] = ChatFrame1 end
    return list
end

local function Selected()
    local ok, f = pcall(FCFDock_GetSelectedWindow, GENERAL_CHAT_DOCK)
    return (ok and f) or SELECTED_CHAT_FRAME or ChatFrame1
end

local function TabOf(f) return _G[f:GetName() .. "Tab"] end

local function TabName(f)
    local tab = TabOf(f)
    local t = tab and (tab.Text or _G[tab:GetName() .. "Text"])
    local s = t and t:GetText()
    if not s or s == "" then s = f.name or "" end
    return s
end

-- 기둥 글씨: 너무 길면 앞 2글자
local function Short(s)
    if not s then return "" end
    local n = 0
    for _ in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end
    if n <= 3 then return s end
    local out, i = "", 0
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        i = i + 1
        if i > 2 then break end
        out = out .. ch
    end
    return out
end

----------------------------------------------------------------------
-- 블리자드 겉모양 숨기기
----------------------------------------------------------------------
local hidden = CreateFrame("Frame"); hidden:Hide()

local function KillTex(t)
    if not t or t.leelKilled then return end
    t.leelKilled = true
    t:SetAlpha(0)
    hooksecurefunc(t, "SetAlpha", function(self, a) if a and a > 0 then self:SetAlpha(0) end end)
end

local function StripFrame(f)
    if f.leelStripped then return end
    f.leelStripped = true
    for _, n in ipairs(CHAT_FRAME_TEXTURES or {}) do KillTex(_G[f:GetName() .. n]) end
    if f.Background then KillTex(f.Background) end
    -- 오른쪽 아래 끝으로 가기 단추는 우리 알약이 대신
    if f.ScrollToBottomButton then f.ScrollToBottomButton:SetAlpha(0); f.ScrollToBottomButton:EnableMouse(false) end
    local bf = _G[f:GetName() .. "ButtonFrame"]
    if bf then
        KillTex(bf); bf:EnableMouse(false)
        for _, c in ipairs({ bf:GetChildren() }) do
            if c ~= _G.ChatFrameMenuButton and c ~= _G.ChatFrameChannelButton and c ~= _G.QuickJoinToastButton then pcall(c.EnableMouse, c, false) end
        end
    end
    -- 탭은 안 보이게 (클릭은 기둥이 대신)
    local tab = TabOf(f)
    if tab then
        tab:SetAlpha(0)
        tab:EnableMouse(false)
        hooksecurefunc(tab, "SetAlpha", function(self, a) if a and a > 0 then self:SetAlpha(0) end end)
    end
end

local function SkinEditBox(f)
    local eb = _G[f:GetName() .. "EditBox"]
    if not eb or eb.leelSkin then return eb end
    eb.leelSkin = true
    for _, n in ipairs({ "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }) do
        local t = _G[eb:GetName() .. n] or eb[n]
        if t then KillTex(t) end
    end
    if eb.NineSlice then eb.NineSlice:SetAlpha(0) end
    local bg = CreateFrame("Frame", nil, eb)
    bg:SetPoint("TOPLEFT", 0, -1); bg:SetPoint("BOTTOMRIGHT", 0, 1)
    bg:SetFrameLevel(math.max(0, eb:GetFrameLevel() - 1))
    eb.leelFill, eb.leelEdge = ns.RoundPlate(bg, 13, { 0.165, 0.122, 0.114, 1 }, { 0.949, 0.702, 0.761, 0.45 })
    eb:SetHeight(EDIT)
    eb:ClearAllPoints()
    eb:SetPoint("TOPLEFT", f, "BOTTOMLEFT", -2, -8)
    eb:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 2, -8)
    return eb
end

-- 입력 알약 테두리 = 말할 채널 색
local function PaintEdit(eb)
    if not eb or not eb.leelEdge then return end
    local ok = pcall(function()
        local t = eb:GetAttribute("chatType")
        local info = t and ChatTypeInfo and ChatTypeInfo[t]
        if t == "CHANNEL" then
            local n = eb:GetAttribute("channelTarget")
            info = n and ChatTypeInfo["CHANNEL" .. n] or info
        end
        if info and info.r then
            eb.leelEdge:SetColor({ info.r, info.g, info.b }, 0.85)
        else
            eb.leelEdge:SetColor({ 0.949, 0.702, 0.761 }, 0.45)
        end
    end)
    if not ok then eb.leelEdge:SetColor({ 0.949, 0.702, 0.761 }, 0.45) end
end

----------------------------------------------------------------------
-- 판 + 기둥 + 머리줄
----------------------------------------------------------------------
local plate, rail, head, newPill
local HeadChips
local items = {}      -- [frame] = 기둥 단추
local unread = {}     -- [frame] = 새 글 수
local whisper = {}    -- [frame] = 귓말 왔음
local pending = 0     -- 지금 창에서 위로 올려 볼 때 쌓인 새 글
-- 작은 기둥 (2안): 창이 낮아 탭이 다 안 들어가면 탭 · 아래 단추를 아이콘만 남은 작은 칸으로
local small = false   -- (작은 기둥 모드는 안 써요: 넘치는 탭은 더보기로)
local FULL_H, SMALL_W, SMALL_H = RAIL - 10, 32, 30
local bottomBtns = {}

-- 기둥 그림: 탭 이름으로
local function IconFor(f)
    local n = TabName(f) or ""
    if n:find("전투") then return "ci_combat" end
    if n:find("길드") then return "ci_guild" end
    if n:find("파티") or n:find("공대") or n:find("던전") then return "ci_party" end
    if n:find("귓") then return "ci_whisper" end
    return "ci_chat"
end

-- 머리줄 채널 칩: 이 탭이 받는 글 종류
local CHIPS = {
    { key = "CHANNEL", name = "공개", col = { 0.910, 0.725, 0.541 } },
    { key = "GUILD", name = "길드", col = { 0.561, 0.863, 0.612 } },
    { key = "PARTY", name = "파티", col = { 0.624, 0.737, 0.957 } },
    { key = "RAID", name = "공대", col = { 0.957, 0.627, 0.549 } },
    { key = "WHISPER", name = "귓말", col = { 0.929, 0.627, 0.839 } },
}
local chipPool = {}
local function HeadChip(n)
    local c = chipPool[n]
    if c then return c end
    c = {}
    c.dot = head:CreateTexture(nil, "ARTWORK")
    c.dot:SetTexture(ns.MEDIA .. "circle"); c.dot:SetSize(7, 7)
    c.text = ns.Font(head, 12, C.tx)
    c.text:SetShadowOffset(1, -1); c.text:SetShadowColor(0, 0, 0, 0.8)
    chipPool[n] = c
    return c
end
HeadChips = function(f)
    if not head then return end
    local has = {}
    pcall(function()
        for _, t in ipairs(f.messageTypeList or {}) do has[t] = true end
        if f.channelList and #f.channelList > 0 then has.CHANNEL = true end
    end)
    local x, n = 0, 0
    pcall(function() x = head.title:GetStringWidth() end)
    if type(x) ~= "number" or (issecretvalue and issecretvalue(x)) then x = 30 end
    x = x + 22
    for _, d in ipairs(CHIPS) do
        if has[d.key] then
            n = n + 1
            local c = HeadChip(n)
            c.dot:SetVertexColor(d.col[1], d.col[2], d.col[3], 1)
            c.dot:ClearAllPoints(); c.dot:SetPoint("LEFT", head, "LEFT", x, -1)
            c.text:SetText(d.name)
            c.text:ClearAllPoints(); c.text:SetPoint("LEFT", c.dot, "RIGHT", 4, 0)
            c.dot:Show(); c.text:Show()
            local w = 26
            pcall(function()
                local tw = c.text:GetStringWidth()
                if type(tw) == "number" and not (issecretvalue and issecretvalue(tw)) then w = tw end
            end)
            x = x + 7 + 4 + w + 11
        end
    end
    for i = n + 1, #chipPool do chipPool[i].dot:Hide(); chipPool[i].text:Hide() end
end

local function RailItem(i)
    local b = items[i]
    if b then return b end
    b = CreateFrame("Button", nil, rail)
    b:SetSize(RAIL - 10, RAIL - 10)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.fill = ns.RoundRect(b, 13, { 0.173, 0.133, 0.125 }, "BACKGROUND", 0, 0)
    b.bar = b:CreateTexture(nil, "ARTWORK")
    b.bar:SetTexture(ns.WHITE); b.bar:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    b.bar:SetSize(3, 18); b.bar:SetPoint("RIGHT", b, "LEFT", -3, 0)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(17, 17); b.icon:SetPoint("TOP", 0, -6)
    b.text = ns.Font(b, 10.5, C.tx2)
    b.text:SetPoint("BOTTOM", 0, 5)
    b.text:SetWidth(RAIL - 12); b.text:SetWordWrap(false)
    -- 새 글 숫자
    b.badge = CreateFrame("Frame", nil, b)
    b.badge:SetSize(18, 16); b.badge:SetPoint("CENTER", b, "TOPRIGHT", -3, -3)
    b.badge:SetFrameLevel(b:GetFrameLevel() + 3)
    ns.RoundRect(b.badge, 8, { 0.13, 0.09, 0.085 }, "BACKGROUND", 0, -1)
    b.badgeFill = ns.RoundRect(b.badge, 8, CORAL, "BACKGROUND", 1, 0)
    b.badgeText = b.badge:CreateFontString(nil, "OVERLAY")
    b.badgeText:SetFont(ns.NUM, 11, ""); b.badgeText:SetPoint("CENTER", 0, 0)
    b.badgeText:SetTextColor(1, 1, 1)
    b.badge:Hide()
    -- 귓말 점
    b.dot = b:CreateTexture(nil, "OVERLAY")
    b.dot:SetTexture(ns.MEDIA .. "circle"); b.dot:SetSize(10, 10)
    b.dot:SetPoint("CENTER", b, "TOPRIGHT", -3, -3)
    b.dot:SetVertexColor(1, 0.62, 0.82, 1)
    local ag = b.dot:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(1); a:SetToAlpha(0.3); a:SetDuration(0.6)
    b.dot:SetScript("OnShow", function() ag:Play() end)
    b.dot:SetScript("OnHide", function() ag:Stop() end)
    b.dot:Hide()

    b:SetScript("OnClick", function(self, btn)
        local tab = self.frame and TabOf(self.frame)
        if not tab then return end
        if btn == "RightButton" then
            tab:EnableMouse(true); pcall(tab.Click, tab, "RightButton"); tab:EnableMouse(false)
        else
            pcall(FCFDock_SelectWindow, GENERAL_CHAT_DOCK, self.frame)
        end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TabName(self.frame or ChatFrame1))
        local n = unread[self.frame] or 0
        if n > 0 then GameTooltip:AddLine("새 글 " .. n .. "개", 1, 0.62, 0.55) end
        if whisper[self.frame] then GameTooltip:AddLine("귓말이 왔어요", 1, 0.62, 0.82) end
        GameTooltip:AddLine("오른쪽 클릭: 탭 메뉴 (이름 바꾸기, 설정)", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Shift + 끌기: 채팅창 옮기기", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function() if IsShiftKeyDown() then ChatFrame1:StartMoving() end end)
    b:SetScript("OnDragStop", function()
        ChatFrame1:StopMovingOrSizing()
        pcall(FCF_SavePositionAndDimensions, ChatFrame1)
    end)
    items[i] = b
    return b
end

local function PaintRail()
    if not rail then return end
    local sel = Selected()
    local list = Docked()
    -- 넘치는 탭은 "···" 더보기로 (1안): 내가 정한 창 높이에 들어가는 만큼만 기둥에 보여요
    --   지금 탭 · 새 글 온 탭 · 귓말 온 탭이 먼저 보이고, 나머지는 원래 순서대로
    local show, hidden = {}, {}
    do
        local have = rail:GetHeight() or 0
        local extra = DB().autoGrow or 0
        local base = have - extra
        local avail = base - PAD - (30 + 10) - ((RAIL - 12 + 8) * 3 + 8)
        local maxN = math.floor(avail / (FULL_H + 8))
        if base <= 0 or #list <= maxN then
            for _, f in ipairs(list) do show[#show + 1] = f end
        else
            local room = math.max(1, maxN - 1)          -- 한 칸은 "···" 자리
            local pick = {}
            local function Take(f) if not pick[f] and room > 0 then pick[f] = true; room = room - 1 end end
            Take(sel)
            for _, f in ipairs(list) do if whisper[f] then Take(f) end end
            for _, f in ipairs(list) do if (unread[f] or 0) > 0 then Take(f) end end
            for _, f in ipairs(list) do Take(f) end
            for _, f in ipairs(list) do
                if pick[f] then show[#show + 1] = f else hidden[#hidden + 1] = f end
            end
        end
    end
    local y = -PAD
    for i, f in ipairs(show) do
        local b = RailItem(i)
        b.frame = f
        b:ClearAllPoints()
        b:SetPoint("TOP", rail, "TOP", 2, y)
        y = y - FULL_H - 8
        b.text:SetText(Short(TabName(f)))
        b.icon:SetTexture(ns.MEDIA .. IconFor(f))
        local on = f == sel
        if on then
            b.fill:SetColor(C.acc); b.text:SetTextColor(C.ink[1], C.ink[2], C.ink[3]); b.bar:Show()
            b.icon:SetVertexColor(C.ink[1], C.ink[2], C.ink[3], 1)
            unread[f] = 0; whisper[f] = nil
        else
            b.fill:SetColor({ 0.173, 0.133, 0.125 }); b.text:SetTextColor(C.tx2[1], C.tx2[2], C.tx2[3]); b.bar:Hide()
            b.icon:SetVertexColor(C.tx2[1], C.tx2[2], C.tx2[3], 1)
        end
        local n = unread[f] or 0
        b.dot:SetShown(whisper[f] and true or false)
        if n > 0 and not whisper[f] then
            b.badgeText:SetText(n > 99 and "99" or n)
            b.badge:SetWidth(math.max(16, b.badgeText:GetStringWidth() + 8))
            b.badge:Show()
        else
            b.badge:Hide()
        end
        b:Show()
    end
    for i = #show + 1, #items do items[i]:Hide() end
    -- "···" 더보기 단추 + 펼침 목록
    if rail.more then
        local mb = rail.more
        mb.hidden = hidden
        if #hidden > 0 then
            mb:ClearAllPoints(); mb:SetPoint("TOP", rail, "TOP", 2, y)
            y = y - 30 - 8
            local sum, wh = 0, false
            for _, f in ipairs(hidden) do sum = sum + (unread[f] or 0); if whisper[f] then wh = true end end
            mb.dot:SetShown(wh)
            if sum > 0 and not wh then
                mb.badgeText:SetText(sum > 99 and "99" or sum)
                mb.badge:SetWidth(math.max(16, mb.badgeText:GetStringWidth() + 8)); mb.badge:Show()
            else mb.badge:Hide() end
            mb:Show()
            if mb.pop:IsShown() then mb.Fill() end
        else
            mb:Hide(); mb.pop:Hide()
        end
    end
    if rail.plus then
        rail.plus:ClearAllPoints()
        rail.plus:SetPoint("TOP", rail, "TOP", 2, y)
    end
    -- 탭이 늘어 기둥 아래 단추(친구 · 음성 · 메뉴)와 겹치면 채팅창을 위로 늘리고,
    -- 탭이 줄면 늘렸던 만큼 다시 줄여요 (아래 끝은 그대로, 내가 정한 크기보다 작아지진 않아요)
    do
        local f1 = ChatFrame1
        local have, H = rail:GetHeight() or 0, f1:GetHeight() or 0
        if have > 0 and H > 0 and not InCombatLockdown() then
            local db = DB()
            local extra = db.autoGrow or 0
            if extra > H - 60 then extra = 0 end
            local base = H - extra                          -- 내가 정한 크기
            local need = -y + 30 + 10 + (RAIL - 12 + 8) * 3 + 8
            local needH = need - (have - H)                 -- 단추가 안 겹치는 채팅창 높이
            local target = math.max(base, needH)
            db.autoGrow = target - base
            if math.abs(target - H) > 0.5 then
                local l, b = f1:GetLeft(), f1:GetBottom()
                if l and b then
                    pcall(function()
                        f1:SetHeight(target)
                        f1:ClearAllPoints()
                        f1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
                        FCF_SavePositionAndDimensions(f1)
                        if db.pos then db.pos[4] = math.floor(target + 0.5) end
                    end)
                end
            end
        end
    end
    if head then
        head.title:SetText(TabName(sel))
        HeadChips(sel)
    end
end

local function Build()
    local f1 = ChatFrame1
    plate = CreateFrame("Frame", "LeelUI_ChatPlate", UIParent)
    plate:SetFrameStrata("BACKGROUND")
    plate:SetPoint("TOPLEFT", f1, "TOPLEFT", -(RAIL + PAD + 4), HEAD + PAD)
    plate:SetPoint("BOTTOMRIGHT", f1, "BOTTOMRIGHT", PAD, -(EDIT + PAD + 10))
    plate.fill, plate.edge = ns.RoundPlate(plate, 16, { 0.114, 0.082, 0.078, 0.93 }, { 0.949, 0.702, 0.761, 0.45 })

    rail = CreateFrame("Frame", nil, plate)
    rail:SetFrameStrata("LOW")
    rail:SetPoint("TOPLEFT", 1, -1)
    rail:SetPoint("BOTTOMLEFT", 1, 1)
    rail:SetWidth(RAIL + 2)
    local rb = ns.RoundRect(rail, 15, { 0.129, 0.094, 0.086 }, "BACKGROUND", 0, 0)
    local sq = rail:CreateTexture(nil, "BACKGROUND", nil, 1)   -- 오른쪽은 각지게
    sq:SetTexture(ns.WHITE); sq:SetVertexColor(0.129, 0.094, 0.086, 1)
    sq:SetPoint("TOPRIGHT"); sq:SetPoint("BOTTOMRIGHT"); sq:SetWidth(16)
    rail.bg, rail.sq = rb, sq
    local line = rail:CreateTexture(nil, "BORDER")
    line:SetTexture(ns.WHITE); line:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.16)
    line:SetPoint("TOPRIGHT"); line:SetPoint("BOTTOMRIGHT"); line:SetWidth(1)
    -- + 새 창
    local plus = CreateFrame("Button", nil, rail)
    plus:SetSize(RAIL - 14, 30)
    local pr = ns.RoundRect(plus, 11, { 0.35, 0.29, 0.28 }, "BACKGROUND", 0, 0)
    local pin = ns.RoundRect(plus, 10, { 0.129, 0.094, 0.086 }, "BACKGROUND", 1, 1)
    local pi = plus:CreateTexture(nil, "ARTWORK")
    pi:SetTexture(ns.MEDIA .. "ci_plus"); pi:SetSize(14, 14); pi:SetPoint("CENTER")
    pi:SetVertexColor(0.6, 0.52, 0.5)
    plus:SetScript("OnClick", function() pcall(FCF_OpenNewWindow) end)
    plus:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("새 채팅 탭 만들기"); GameTooltip:Show()
    end)
    plus:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rail.plus = plus

    -- "···" 더보기: 기둥에 못 들어간 탭 모음
    local mb = CreateFrame("Button", nil, rail)
    mb:SetSize(RAIL - 10, 30)
    mb.fill = ns.RoundRect(mb, 11, { 0.173, 0.133, 0.125 }, "BACKGROUND", 0, 0)
    mb.t = ns.Font(mb, 16, C.acc); mb.t:SetPoint("CENTER", 0, 2); mb.t:SetText("···")
    mb.badge = CreateFrame("Frame", nil, mb)
    mb.badge:SetSize(18, 16); mb.badge:SetPoint("CENTER", mb, "TOPRIGHT", -3, -3)
    mb.badge:SetFrameLevel(mb:GetFrameLevel() + 3)
    ns.RoundRect(mb.badge, 8, { 0.13, 0.09, 0.085 }, "BACKGROUND", 0, -1)
    ns.RoundRect(mb.badge, 8, CORAL, "BACKGROUND", 1, 0)
    mb.badgeText = mb.badge:CreateFontString(nil, "OVERLAY")
    mb.badgeText:SetFont(ns.NUM, 11, ""); mb.badgeText:SetPoint("CENTER", 0, 0); mb.badgeText:SetTextColor(1, 1, 1)
    mb.badge:Hide()
    mb.dot = mb:CreateTexture(nil, "OVERLAY"); mb.dot:SetTexture(ns.MEDIA .. "circle"); mb.dot:SetSize(10, 10)
    mb.dot:SetPoint("CENTER", mb, "TOPRIGHT", -3, -3); mb.dot:SetVertexColor(1, 0.62, 0.82, 1); mb.dot:Hide()
    -- 펼침 목록
    local pop = CreateFrame("Frame", nil, mb)
    pop:SetFrameStrata("DIALOG")
    pop:SetPoint("TOPLEFT", mb, "TOPRIGHT", 10, 4)
    pop:SetWidth(130)
    ns.RoundPlate(pop, 10, { 0.125, 0.094, 0.086, 0.97 }, { 0.949, 0.702, 0.761, 0.7 })
    pop:EnableMouse(true)
    pop:Hide()
    pop.rows = {}
    mb.pop = pop
    function mb.Fill()
        local list = mb.hidden or {}
        for i, f in ipairs(list) do
            local r = pop.rows[i]
            if not r then
                r = CreateFrame("Button", nil, pop)
                r:SetHeight(24)
                r.hl = r:CreateTexture(nil, "BACKGROUND"); r.hl:SetAllPoints(); r.hl:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.15); r.hl:Hide()
                r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(15, 15); r.icon:SetPoint("LEFT", 8, 0)
                r.icon:SetVertexColor(C.tx2[1], C.tx2[2], C.tx2[3], 1)
                r.text = ns.Font(r, 12, C.tx); r.text:SetPoint("LEFT", r.icon, "RIGHT", 7, 0); r.text:SetJustifyH("LEFT")
                r.n = ns.Font(r, 11, CORAL); r.n:SetPoint("RIGHT", -8, 0)
                r:SetScript("OnEnter", function(self) self.hl:Show() end)
                r:SetScript("OnLeave", function(self) self.hl:Hide() end)
                r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                r:SetScript("OnClick", function(self, btn)
                    local tab = self.frame and TabOf(self.frame)
                    if btn == "RightButton" and tab then
                        tab:EnableMouse(true); pcall(tab.Click, tab, "RightButton"); tab:EnableMouse(false)
                    elseif self.frame then
                        pcall(FCFDock_SelectWindow, GENERAL_CHAT_DOCK, self.frame)
                    end
                    pop:Hide()
                end)
                pop.rows[i] = r
            end
            r.frame = f
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", pop, "TOPLEFT", 4, -5 - (i - 1) * 25)
            r:SetPoint("RIGHT", pop, "RIGHT", -4, 0)
            r.icon:SetTexture(ns.MEDIA .. IconFor(f))
            r.text:SetText(TabName(f))
            local n = unread[f] or 0
            r.n:SetText(whisper[f] and "귓말" or (n > 0 and (n > 99 and "99+" or tostring(n)) or ""))
            r:Show()
        end
        for i = #list + 1, #pop.rows do pop.rows[i]:Hide() end
        pop:SetHeight(10 + #list * 25)
    end
    mb:SetScript("OnClick", function()
        if pop:IsShown() then pop:Hide() else mb.Fill(); pop:Show() end
    end)
    mb:SetScript("OnEnter", function(self)
        self.fill:SetColor({ 0.26, 0.19, 0.18 })
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("다른 탭 " .. #(self.hidden or {}) .. "개")
        GameTooltip:AddLine("누르면 목록이 열려요", 0.8, 0.8, 0.8); GameTooltip:Show()
    end)
    mb:SetScript("OnLeave", function(self) self.fill:SetColor({ 0.173, 0.133, 0.125 }); GameTooltip:Hide() end)
    mb:Hide()
    rail.more = mb

    head = CreateFrame("Frame", nil, plate)
    head:SetFrameStrata("LOW")
    head:SetPoint("TOPLEFT", rail, "TOPRIGHT", 0, 0)
    head:SetPoint("TOPRIGHT", plate, "TOPRIGHT", 0, 0)
    head:SetHeight(HEAD + 4)
    head.title = ns.Font(head, 15, C.tx)
    head.title:SetPoint("LEFT", 12, -1)
    local hl = head:CreateTexture(nil, "BORDER")
    hl:SetTexture(ns.WHITE); hl:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.14)
    hl:SetPoint("BOTTOMLEFT", 6, 0); hl:SetPoint("BOTTOMRIGHT", -6, 0); hl:SetHeight(1)
    -- 톱니: 지금 탭 메뉴
    local gear = CreateFrame("Button", nil, head)
    gear:SetSize(22, 22); gear:SetPoint("RIGHT", -8, -1)
    ns.RoundRect(gear, 8, { 0.173, 0.133, 0.125 }, "BACKGROUND", 0, 0)
    local gi = gear:CreateTexture(nil, "ARTWORK")
    gi:SetTexture(ns.MEDIA .. "ci_gear"); gi:SetSize(13, 13); gi:SetPoint("CENTER")
    gi:SetVertexColor(0.85, 0.75, 0.75)
    gear:SetScript("OnClick", function()
        local tab = TabOf(Selected())
        if tab then tab:EnableMouse(true); pcall(tab.Click, tab, "RightButton"); tab:EnableMouse(false) end
    end)
    gear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText("이 탭 설정 (채널 고르기, 이름, 글씨 크기)"); GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function() GameTooltip:Hide() end)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    -- 머리 줄을 끌면 채팅창 이동 (블리자드 화면 편집 없이)
    head:SetScript("OnDragStart", function() if ns.ChatStartMove then ns.ChatStartMove() end end)
    head:SetScript("OnDragStop", function() if ns.ChatStopMove then ns.ChatStopMove() end end)

    -- 새 글 알약 (위로 올려 보는 중일 때)
    newPill = CreateFrame("Button", nil, plate)
    newPill:SetFrameStrata("MEDIUM")
    newPill:SetSize(96, 22)
    newPill:SetPoint("BOTTOM", f1, "BOTTOM", 0, 4)
    ns.RoundRect(newPill, 11, C.acc, "BACKGROUND", 0, 0)
    newPill.text = ns.Font(newPill, 12, C.ink)
    newPill.text:SetShadowColor(0, 0, 0, 0)
    newPill.text:SetPoint("CENTER", 0, 0)
    newPill:SetScript("OnClick", function()
        local f = Selected()
        pcall(f.ScrollToBottom, f)
        pending = 0; newPill:Hide()
    end)
    newPill:Hide()

    -- 메뉴·음성 단추는 기둥 아래로
    -- 메뉴·음성·친구 단추: 기둥 단추와 같은 둥근 네모 + 분홍 선 아이콘 (A안). 누르면 하는 일은 그대로
    local SZ = RAIL - 12
    local function Skin(btn, icon, k, tip)
        if not btn then return end
        bottomBtns[#bottomBtns + 1] = btn
        -- 블리자드가 다시 옮기면(이용 시간 알림 · 토스트 등) 기둥 자리로 돌려놔요
        local function Pin()
            if btn.leelPinning then return end
            btn.leelPinning = true
            pcall(function()
                if btn:GetParent() ~= rail then btn:SetParent(rail) end
                btn:ClearAllPoints()
                if small then
                    btn:SetPoint("BOTTOM", rail, "BOTTOM", 1, 6 + (SMALL_H + 4) * k)
                    btn:SetScale(1); btn:SetSize(SMALL_W, SMALL_H)
                else
                    btn:SetPoint("BOTTOM", rail, "BOTTOM", 1, 8 + (SZ + 8) * k)
                    btn:SetScale(1); btn:SetSize(SZ, SZ)
                end
            end)
            btn.leelPinning = false
        end
        btn.leelPin = Pin
        if not btn.leelPinHooked then
            btn.leelPinHooked = true
            hooksecurefunc(btn, "SetPoint", function() if not btn.leelPinning then C_Timer.After(0, Pin) end end)
            hooksecurefunc(btn, "SetParent", function(_, p) if not btn.leelPinning and p ~= rail then C_Timer.After(0, Pin) end end)
            hooksecurefunc(btn, "SetScale", function() if not btn.leelPinning then C_Timer.After(0, Pin) end end)
        end
        pcall(function()
            Pin()
            btn:SetAlpha(1); btn:EnableMouse(true)
            -- 블리자드 그림 숨기기 (숫자 글씨는 남김)
            for _, r in ipairs({ btn:GetRegions() }) do
                if r:GetObjectType() == "Texture" then KillTex(r) end
            end
            for _, k in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
                local t = btn[k] and btn[k](btn)
                if t then KillTex(t) end
            end
            local holder = CreateFrame("Frame", nil, btn)
            holder:SetAllPoints()
            holder:SetFrameLevel(btn:GetFrameLevel())
            local fill = ns.RoundRect(holder, 13, { 0.173, 0.133, 0.125 }, "BACKGROUND", 0, 0)
            local ic = holder:CreateTexture(nil, "ARTWORK")
            ic:SetTexture(ns.MEDIA .. icon); ic:SetSize(19, 19); ic:SetPoint("CENTER")
            ic:SetVertexColor(C.tx2[1], C.tx2[2], C.tx2[3], 1)
            btn:HookScript("OnEnter", function()
                fill:SetColor({ 0.26, 0.19, 0.18 }); ic:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
            end)
            btn:HookScript("OnLeave", function()
                fill:SetColor({ 0.173, 0.133, 0.125 }); ic:SetVertexColor(C.tx2[1], C.tx2[2], C.tx2[3], 1)
            end)
            btn.leelIcon, btn.leelFill = ic, fill
        end)
    end
    Skin(_G.ChatFrameMenuButton, "ci_emote", 0)
    Skin(_G.ChatFrameChannelButton, "ci_voice", 1)
    local qj = _G.QuickJoinToastButton
    Skin(qj, "ci_social", 2)
    -- 친구 접속 수: 오른쪽 위 빨간 숫자 알약
    if qj and qj.FriendCount then
        pcall(function()
            local fc = qj.FriendCount
            local badge = CreateFrame("Frame", nil, qj)
            badge:SetSize(18, 16); badge:SetPoint("CENTER", qj, "TOPRIGHT", -3, -3)
            badge:SetFrameLevel(qj:GetFrameLevel() + 5)
            ns.RoundRect(badge, 8, { 0.13, 0.09, 0.085 }, "BACKGROUND", 0, -1)
            ns.RoundRect(badge, 8, CORAL, "BACKGROUND", 1, 0)
            fc:SetParent(badge)
            fc:ClearAllPoints(); fc:SetPoint("CENTER", badge, "CENTER", 0, 0)
            fc:SetFont(ns.NUM, 11, ""); fc:SetTextColor(1, 1, 1); fc:SetShadowOffset(0, 0)
            local function Fit()
                local t = fc:GetText()
                local show = t and t ~= "" and t ~= "0"
                badge:SetShown(show and true or false)
                if show then badge:SetWidth(math.max(16, fc:GetStringWidth() + 8)) end
            end
            hooksecurefunc(fc, "SetText", Fit); hooksecurefunc(fc, "SetFormattedText", Fit)
            Fit()
        end)
    end
end

----------------------------------------------------------------------
-- 새 글 세기
----------------------------------------------------------------------
local COUNT = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_CHANNEL",
    "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER",
}
local WHISPER = { CHAT_MSG_WHISPER = true, CHAT_MSG_BN_WHISPER = true }

local function OnChat(event, ...)
    local sel = Selected()
    local args = { ... }
    for _, f in ipairs(Docked()) do
        local gets = false
        pcall(function()
            if not f:IsEventRegistered(event) then return end
            if event == "CHAT_MSG_CHANNEL" then
                local base = args[9]
                if base and ChatFrame_ContainsChannel and not ChatFrame_ContainsChannel(f, base) then return end
            end
            gets = true
        end)
        if gets then
            if f ~= sel then
                unread[f] = (unread[f] or 0) + 1
                if WHISPER[event] then whisper[f] = true end
            else
                local ok, bottom = pcall(f.AtBottom, f)
                if ok and not bottom then pending = pending + 1 end
            end
        end
    end
    PaintRail()
end

----------------------------------------------------------------------
-- 글 앞 [길드] [1. 공개 - 지역] 글자를 작은 색 칩으로 (눌러서 그 채널로 말하기는 그대로)
----------------------------------------------------------------------
local LINKCHIP = {
    GUILD = "cc_guild", OFFICER = "cc_officer", PARTY = "cc_party", PARTY_LEADER = "cc_party",
    RAID = "cc_raid", RAID_LEADER = "cc_raid", RAID_WARNING = "cc_raid",
    INSTANCE_CHAT = "cc_inst", INSTANCE_CHAT_LEADER = "cc_inst",
}
local function ChanChip(name)
    if not name then return "cc_chan" end
    if name:find("거래") or name:find("Trade") then return "cc_trade" end
    if name:find("파티찾기") or name:find("LookingForGroup") then return "cc_lfg" end
    if name:find("지역") or name:find("Local") then return "cc_local" end
    if name:find("공개") or name:find("General") then return "cc_general" end
    return "cc_chan"
end

local function ChipTag(tex, size)
    local h = math.floor((size or 13) * 1.15 + 0.5)
    return ("|T%s%s:%d:%d:0:-1|t"):format(ns.MEDIA, tex, h, h * 2)
end

local function Chipify(f, text)
    if type(text) ~= "string" then return text end
    local _, size = f:GetFont()
    local out = text:gsub("|Hchannel:([^|]+)|h%[([^%]]*)%]|h", function(link, label)
        local tex
        local kind = link:match("^([^:]+)")
        if kind and kind:lower() == "channel" then
            tex = ChanChip(label)
        else
            tex = LINKCHIP[link] or LINKCHIP[kind or ""]
        end
        if not tex then return nil end
        return "|Hchannel:" .. link .. "|h" .. ChipTag(tex, size) .. "|h"
    end)
    -- 귓속말 (받음/보냄)
    if out:find("귓속말") and not out:find("cc_whisper") then
        out = ChipTag("cc_whisper", size) .. " " .. out
    end
    return out
end

local function HookMessages(f)
    if f.leelChip or f == ChatFrame2 then return end
    f.leelChip = true
    local orig = f.AddMessage
    f.AddMessage = function(self, text, ...)
        if DB().chips ~= false then
            local ok, t2 = pcall(Chipify, self, text)
            if ok and t2 then text = t2 end
        end
        return orig(self, text, ...)
    end
end

-- 입력 알약 오른쪽 보내기 단추
local function SendButton(eb)
    if not eb or eb.leelSend then return end
    local b = CreateFrame("Button", nil, eb)
    b:SetSize(22, 22); b:SetPoint("RIGHT", eb, "RIGHT", -4, 0)
    ns.RoundRect(b, 11, C.acc, "BACKGROUND", 0, 0)
    local i = b:CreateTexture(nil, "ARTWORK")
    i:SetTexture(ns.MEDIA .. "ci_send"); i:SetSize(12, 12); i:SetPoint("CENTER", 1, 0)
    i:SetVertexColor(C.ink[1], C.ink[2], C.ink[3], 1)
    b:SetScript("OnClick", function() pcall(ChatEdit_OnEnterPressed, eb) end)
    eb.leelSend = b
    local function Inset()
        local l, _, t, bt = eb:GetTextInsets()
        if l then eb:SetTextInsets(l, 30, t, bt) end
    end
    Inset()
    if ChatEdit_UpdateHeader then hooksecurefunc("ChatEdit_UpdateHeader", function(e) if e == eb then Inset() end end) end
end

----------------------------------------------------------------------
-- 켜기
----------------------------------------------------------------------
local function Apply()
    for _, f in ipairs(Docked()) do
        StripFrame(f)
        HookMessages(f)
        local eb = SkinEditBox(f)
        SendButton(eb)
        if eb and not eb.leelHooked then
            eb.leelHooked = true
            eb:HookScript("OnShow", function(self) PaintEdit(self) end)
            eb:HookScript("OnTextChanged", function(self) PaintEdit(self) end)
        end
    end
    if GeneralDockManager then KillTex(GeneralDockManager) end
    PaintRail()
end

----------------------------------------------------------------------
-- 떨어져 나온 탭 다시 붙이기: 르엘 기둥이 탭을 대신하니까, 밖에 떠 있는 채팅 창은 기둥으로 돌려요
--   (허브 "탭 따로 띄우기 허용"을 켜면 그대로 둬요)
----------------------------------------------------------------------
local function Redock()
    if DB().allowFloat or InCombatLockdown() or not FCF_DockFrame then return end
    local dock = _G.GENERAL_CHAT_DOCK
    for i = 2, (NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame" .. i]
        if f and f:IsShown() and not f.isDocked and not f.isTemporary then
            local n = (dock and dock.DOCKED_CHAT_FRAMES and #dock.DOCKED_CHAT_FRAMES or 1) + 1
            pcall(FCF_DockFrame, f, n, false)
        end
    end
end
ns.ChatRedock = Redock

-- 채팅창 판(왼쪽 기둥 · 머리줄 · 입력줄 포함)이 화면 밖으로 안 나가게
local function ClampInsets()
    local f = ChatFrame1
    if not f or f.leelClamping then return end
    f.leelClamping = true
    pcall(f.SetClampRectInsets, f, -(RAIL + PAD + 4), PAD, HEAD + PAD, -(EDIT + PAD + 10))
    f.leelClamping = false
end
local function KeepOnScreen()
    if not plate or InCombatLockdown() then return end
    local l, r, t, b = plate:GetLeft(), plate:GetRight(), plate:GetTop(), plate:GetBottom()
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    if not (l and r and t and b and W and H) then return end
    local dx, dy = 0, 0
    if l < 0 then dx = -l elseif r > W then dx = W - r end
    if b < 0 then dy = -b elseif t > H then dy = H - t end
    if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then return end
    local f = ChatFrame1
    local fl, fb = f:GetLeft(), f:GetBottom()
    if not (fl and fb) then return end
    pcall(function()
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", math.floor(fl + dx + 0.5), math.floor(fb + dy + 0.5))
        if f.SetUserPlaced then f:SetUserPlaced(true) end
        FCF_SavePositionAndDimensions(f)
        if DB().pos then DB().pos[1] = math.floor(fl + dx + 0.5); DB().pos[2] = math.floor(fb + dy + 0.5) end
    end)
end
ns.ChatKeepOnScreen = KeepOnScreen

local function Init()
    if not ns.db or DB().on == false then return end
    if plate then return end
    -- 처음 설치: 채팅창을 왼쪽 아래 기본 자리·크기로 (1920×1080 기준 왼쪽 70, 아래 133, 294×299)
    if ns.freshInstall and not DB().placed and not InCombatLockdown() then
        pcall(function()
            local sx = UIParent:GetWidth() / 1920
            local sy = UIParent:GetHeight() / 1080
            ChatFrame1:ClearAllPoints()
            ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", math.floor(70 * sx + 0.5), math.floor(133 * sy + 0.5))
            ChatFrame1:SetSize(294, 299)
            if ChatFrame1.SetUserPlaced then ChatFrame1:SetUserPlaced(true) end
            FCF_SavePositionAndDimensions(ChatFrame1)
        end)
    end
    DB().placed = true
    Build()
    Apply()
    ClampInsets()
    if ChatFrame1.SetClampRectInsets then
        hooksecurefunc(ChatFrame1, "SetClampRectInsets", function() C_Timer.After(0, ClampInsets) end)
    end
    Redock()
    C_Timer.After(2, function() Redock(); KeepOnScreen() end)
    -- 탭을 끌다 놓으면(떨어져 나오면) 바로 다시 붙여요
    if FCF_StopDragging then hooksecurefunc("FCF_StopDragging", function() C_Timer.After(0.1, Redock) end) end
    if FCF_UndockWindow then hooksecurefunc("FCF_UndockWindow", function() C_Timer.After(0.1, Redock) end) end
    ns:SetChatAlpha(DB().alpha or 0)
    if FCFDock_SelectWindow then hooksecurefunc("FCFDock_SelectWindow", function() pending = 0; PaintRail() end) end
    if FCFDock_UpdateTabs then hooksecurefunc("FCFDock_UpdateTabs", function() C_Timer.After(0, Apply) end) end
    if FCF_DockFrame then hooksecurefunc("FCF_DockFrame", function() C_Timer.After(0, Apply) end) end
    if ChatEdit_UpdateHeader then hooksecurefunc("ChatEdit_UpdateHeader", PaintEdit) end
    if FCF_Close then hooksecurefunc("FCF_Close", function() C_Timer.After(0, PaintRail) end) end
    if FCF_SetTabText then hooksecurefunc("FCF_SetTabText", function() C_Timer.After(0, PaintRail) end) end

    local ev = CreateFrame("Frame")
    for _, e in ipairs(COUNT) do ev:RegisterEvent(e) end
    ev:SetScript("OnEvent", function(_, e, ...) OnChat(e, ...) end)

    -- 위로 올려 보는 중이면 "새 글 N개 ↓"
    local t = 0
    plate:SetScript("OnUpdate", function(_, el)
        t = t + el
        if t < 0.2 then return end
        t = 0
        local f = Selected()
        local ok, bottom = pcall(f.AtBottom, f)
        if ok and not bottom then
            newPill.text:SetText(pending > 0 and ("새 글 " .. pending .. "개 ↓") or "맨 아래로 ↓")
            newPill:SetWidth(newPill.text:GetStringWidth() + 26)
            newPill:Show()
        else
            pending = 0
            newPill:Hide()
        end
    end)
end

-- 배경 진하기 (0 = 완전 투명, 100 = 꽉 찬 판). 테두리와 기둥 단추는 그대로
function ns:SetChatAlpha(v)
    DB().alpha = v
    if not plate then return end
    local a = (v or 0) / 100
    plate.fill:SetColor({ 0.114, 0.082, 0.078 }, a * 0.95)
    -- 테두리 그림은 판 전체를 칠한 분홍이라(안쪽은 판이 덮음), 판이 투명하면 분홍 막이 비쳐 보임
    -- → 판이 옅을수록 테두리도 같이 옅게 (0%면 완전 투명)
    plate.edge:SetColor({ 0.949, 0.702, 0.761 }, a * 0.45)
    rail.bg:SetColor({ 0.129, 0.094, 0.086 }, math.min(1, a * 1.1))
    rail.sq:SetVertexColor(0.129, 0.094, 0.086, math.min(1, a * 1.1))
end

-- 지금 채팅창 자리·크기 기록 (기본값 만들 때 씀)
local function SaveGeo()
    local f = ChatFrame1
    if not (ns.db and f and f:GetLeft()) then return end
    DB().geo = {
        left = math.floor(f:GetLeft() + 0.5), bottom = math.floor(f:GetBottom() + 0.5),
        w = math.floor(f:GetWidth() + 0.5), h = math.floor(f:GetHeight() + 0.5),
        sw = math.floor(UIParent:GetWidth() + 0.5), sh = math.floor(UIParent:GetHeight() + 0.5),
    }
end

----------------------------------------------------------------------
-- 채팅창 옮기기 · 크기: 르엘 이동 모드 + 머리 줄 끌기 (블리자드 화면 편집 대신)
-- 자리는 우리 설정에 저장하고, 게임이 화면 편집 배치로 되돌려도 다시 맞춰요
----------------------------------------------------------------------
local function SavePos()
    local f = ChatFrame1
    if not (f and f:GetLeft()) then return end
    DB().pos = { math.floor(f:GetLeft() + 0.5), math.floor(f:GetBottom() + 0.5),
                 math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5) }
    pcall(FCF_SavePositionAndDimensions, f)
end

local applying = false
local function ApplyPos()
    local p = DB().pos
    if not (p and ChatFrame1) or InCombatLockdown() then return end
    applying = true
    pcall(function()
        local f = ChatFrame1
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", p[1], p[2])
        if p[3] and p[4] then f:SetSize(p[3], p[4]) end
        if f.SetUserPlaced then f:SetUserPlaced(true) end
    end)
    applying = false
end
ns.ApplyChatPos = ApplyPos

local function Movable()
    local f = ChatFrame1
    pcall(f.SetMovable, f, true)
    pcall(f.SetResizable, f, true)
    pcall(f.SetClampedToScreen, f, true)
end

function ns.ChatStartMove()
    if InCombatLockdown() then return end
    Movable()
    pcall(ChatFrame1.StartMoving, ChatFrame1)
end
function ns.ChatStopMove()
    pcall(ChatFrame1.StopMovingOrSizing, ChatFrame1)
    if ns.ChatKeepOnScreen then ns.ChatKeepOnScreen() end
    SavePos()
end

-- 이동 모드일 때 채팅창 위에 덮는 분홍 상자 (끌기 = 옮기기, 오른쪽 위 모서리 = 크기)
local mover
function ns:SetChatMoveMode(on)
    if not plate then return end
    if on and not mover then
        mover = CreateFrame("Frame", nil, UIParent)
        mover:SetFrameStrata("DIALOG")
        mover:SetAllPoints(plate)
        mover:EnableMouse(true)
        mover:RegisterForDrag("LeftButton")
        local tint = mover:CreateTexture(nil, "BACKGROUND")
        tint:SetAllPoints(); tint:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.10)
        for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
            local e = mover:CreateTexture(nil, "BORDER")
            e:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.9)
            if side == "TOP" or side == "BOTTOM" then
                e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(2)
            else
                e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(2)
            end
        end
        local lb = ns.Font(mover, 13, C.accHi)
        lb:SetPoint("CENTER"); lb:SetText("채팅창\n끌면 옮기기 · 오른쪽 위 손잡이로 크기")
        mover:SetScript("OnDragStart", ns.ChatStartMove)
        mover:SetScript("OnDragStop", ns.ChatStopMove)
        -- 크기 손잡이 (아래 끝은 그대로, 위·오른쪽으로 늘리고 줄여요)
        local grip = CreateFrame("Button", nil, mover)
        grip:SetSize(22, 22); grip:SetPoint("TOPRIGHT", -2, -2)
        grip:SetSize(26, 26)
        local gt = grip:CreateTexture(nil, "OVERLAY")
        gt:SetTexture(ns.MEDIA .. "grip_resize"); gt:SetAllPoints()
        local gh = grip:CreateTexture(nil, "HIGHLIGHT")
        gh:SetTexture(ns.MEDIA .. "circle"); gh:SetAllPoints(); gh:SetVertexColor(1, 1, 1, 0.25); gh:SetBlendMode("ADD")
        grip:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText("끌면 크기 조절"); GameTooltip:Show()
        end)
        grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
        grip:RegisterForDrag("LeftButton")
        grip:SetScript("OnDragStart", function()
            if InCombatLockdown() then return end
            Movable()
            if ChatFrame1.SetResizeBounds then pcall(ChatFrame1.SetResizeBounds, ChatFrame1, 200, 120, 900, 900) end
            pcall(ChatFrame1.StartSizing, ChatFrame1, "TOPRIGHT")
        end)
        grip:SetScript("OnDragStop", function()
            pcall(ChatFrame1.StopMovingOrSizing, ChatFrame1)
            DB().autoGrow = 0          -- 직접 정한 크기를 새 기준으로
            SavePos()
            C_Timer.After(0, function() pcall(PaintRail) end)   -- 낮아졌으면 작은 기둥으로
        end)
    end
    if mover then mover:SetShown(on and true or false) end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGOUT")
boot:RegisterEvent("PLAYER_LOGIN")
pcall(boot.RegisterEvent, boot, "EDIT_MODE_LAYOUTS_UPDATED")
boot:RegisterEvent("PLAYER_REGEN_ENABLED")
boot:SetScript("OnEvent", function(_, e)
    if e == "PLAYER_LOGOUT" then pcall(SaveGeo) return end
    if e == "PLAYER_LOGIN" then
        C_Timer.After(1, function() pcall(Init); pcall(ApplyPos) end)
        C_Timer.After(4, function() pcall(ApplyPos); pcall(KeepOnScreen) end)    -- 화면 편집 배치가 늦게 덮어써도 다시
        return
    end
    if ns.db and DB().on ~= false then C_Timer.After(0.2, function() pcall(ApplyPos) end) end
end)
