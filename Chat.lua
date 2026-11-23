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
        ns.TSet(GameTooltip, TabName(self.frame or ChatFrame1))
        local n = unread[self.frame] or 0
        if n > 0 then ns.TAdd(GameTooltip, "새 글 " .. n .. "개", 1, 0.62, 0.55) end
        if whisper[self.frame] then ns.TAdd(GameTooltip, "귓말이 왔어요", 1, 0.62, 0.82) end
        ns.TAdd(GameTooltip, "오른쪽 클릭: 탭 메뉴 (이름 바꾸기, 설정)", 0.8, 0.8, 0.8)
        ns.TAdd(GameTooltip, "Shift + 끌기: 채팅창 옮기기", 0.8, 0.8, 0.8)
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
    -- 채팅창 크기는 내가 정한 그대로 (예전엔 탭 수에 따라 자동으로 늘렸다 줄여서 접속할 때마다 크기가 바뀌었어요)
    --   넘치는 탭은 "···" 더보기로 들어가요. 예전에 자동으로 늘린 만큼은 한 번 되돌려요
    do
        local db = DB()
        local extra = db.autoGrow or 0
        if extra > 0 and not InCombatLockdown() then
            local f1 = ChatFrame1
            local H = f1:GetHeight() or 0
            local l, bt = f1:GetLeft(), f1:GetBottom()
            if H - extra >= 120 and l and bt then
                pcall(function()
                    f1:SetHeight(H - extra)
                    f1:ClearAllPoints()
                    f1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, bt)
                    FCF_SavePositionAndDimensions(f1)
                    if db.pos then db.pos[4] = math.floor(H - extra + 0.5) end
                end)
            end
            db.autoGrow = 0
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
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); ns.TSet(GameTooltip, "새 채팅 탭 만들기"); GameTooltip:Show()
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
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); ns.TSet(GameTooltip, "다른 탭 " .. #(self.hidden or {}) .. "개")
        ns.TAdd(GameTooltip, "누르면 목록이 열려요", 0.8, 0.8, 0.8); GameTooltip:Show()
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
        GameTooltip:SetOwner(self, "ANCHOR_TOP"); ns.TSet(GameTooltip, "이 탭 설정 (채널 고르기, 이름, 글씨 크기)"); GameTooltip:Show()
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
    -- 음성 채널에 들어가면 나오는 소리 끄기 · 마이크 끄기 단추: 기둥 안 작은 네모 둘 (나란히)
    do
        local half = math.floor(SZ / 2) - 1
        local function Mini(btn, icon, side, isOff)
            if not btn then return end
            local function Pin()
                if btn.leelPinning then return end
                btn.leelPinning = true
                pcall(function()
                    if btn:GetParent() ~= rail then btn:SetParent(rail) end
                    btn:ClearAllPoints()
                    btn:SetPoint("BOTTOM", rail, "BOTTOM", 1 + side * (half / 2 + 1), 8 + (SZ + 8) * 3)
                    btn:SetScale(1); btn:SetSize(half, half)
                end)
                btn.leelPinning = false
            end
            if not btn.leelPinHooked then
                btn.leelPinHooked = true
                hooksecurefunc(btn, "SetPoint", function() if not btn.leelPinning then C_Timer.After(0, Pin) end end)
                hooksecurefunc(btn, "SetParent", function(_, p) if not btn.leelPinning and p ~= rail then C_Timer.After(0, Pin) end end)
            end
            pcall(function()
                Pin()
                for _, r in ipairs({ btn:GetRegions() }) do if r:GetObjectType() == "Texture" then KillTex(r) end end
                for _, k in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
                    local t = btn[k] and btn[k](btn); if t then KillTex(t) end
                end
                -- 블리자드가 상태마다 그림을 다시 넣어도 안 보이게
                for _, k in ipairs({ "SetNormalTexture", "SetPushedTexture", "SetNormalAtlas", "SetPushedAtlas" }) do
                    if btn[k] then hooksecurefunc(btn, k, function(self)
                        for _, g in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do local t = self[g] and self[g](self); if t then KillTex(t) end end
                    end) end
                end
                local h = CreateFrame("Frame", nil, btn); h:SetAllPoints(); h:SetFrameLevel(btn:GetFrameLevel() + 1)
                local fill = ns.RoundRect(h, 8, { 0.173, 0.133, 0.125 }, "BACKGROUND", 0, 0)
                local ic = h:CreateTexture(nil, "ARTWORK"); ic:SetTexture(ns.MEDIA .. icon); ic:SetSize(half - 4, half - 4); ic:SetPoint("CENTER")
                local sl = h:CreateTexture(nil, "OVERLAY"); sl:SetTexture(ns.MEDIA .. "ci_slash"); sl:SetAllPoints(ic); sl:SetVertexColor(CORAL[1], CORAL[2], CORAL[3], 1)
                local hover = false
                local function Paint()
                    local off = false
                    pcall(function() off = isOff() and true or false end)
                    sl:SetShown(off)
                    local c = hover and C.acc or (off and CORAL or C.tx2)
                    ic:SetVertexColor(c[1], c[2], c[3], 1)
                    fill:SetColor(hover and { 0.26, 0.19, 0.18 } or { 0.173, 0.133, 0.125 })
                end
                btn:HookScript("OnEnter", function() hover = true; Paint() end)
                btn:HookScript("OnLeave", function() hover = false; Paint() end)
                btn:HookScript("OnClick", function() C_Timer.After(0.1, Paint) end)
                local ev = CreateFrame("Frame")
                for _, e in ipairs({ "VOICE_CHAT_DEAFENED_CHANGED", "VOICE_CHAT_MUTED_CHANGED", "VOICE_CHAT_SILENCED_CHANGED", "VOICE_CHAT_CHANNEL_ACTIVATED" }) do pcall(ev.RegisterEvent, ev, e) end
                ev:SetScript("OnEvent", Paint)
                Paint()
            end)
        end
        local VC = C_VoiceChat
        Mini(_G.ChatFrameToggleVoiceDeafenButton, "ci_voice", -1, function() return VC and VC.IsDeafened and VC.IsDeafened() end)
        Mini(_G.ChatFrameToggleVoiceMuteButton, "ci_mic", 1, function() return VC and VC.IsMuted and VC.IsMuted() end)
    end
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
    if ns.EnOn and ns.EnOn() then tex = tex .. "_en" end      -- 영어 칩 그림
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

-- 시간 · 내 이름 강조 (허브)
-- 알림 소리 (허브에서 고르면 한 번 들려줘요)
--   pager = 삐삐 호출 "삐빅 삐빅" (르엘 소리 media/leel_at_pager.ogg, 기본)
--   게임 소리: ready = 준비 확인 · warn = 공격대 경보 · ding = 귓말 띵
--   새 소리 파일은 게임을 껐다 켜야 읽혀요 → 못 틀면 준비 확인 소리로 대신
local OWN = { pager = "leel_at_pager" }
function ns.ChatAtSound(snd)
    snd = snd or "pager"
    if snd ~= "off" and snd ~= "ready" and snd ~= "warn" and snd ~= "ding" then snd = "pager" end   -- 예전에 고른 시험 소리는 삐삐로
    if snd == "off" then return end
    if OWN[snd] then
        local ok, will = pcall(PlaySoundFile, ns.MEDIA .. OWN[snd] .. ".ogg", "Master")
        if ok and will then return end
        snd = "ready"
    end
    local id = (snd == "ready" and ((SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960))
        or (snd == "warn" and ((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959))
        or (snd == "pop" and 856)
        or ((SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081)
    pcall(PlaySound, id, "Master")
end

-- @불러 주기 (A안): 누가 "@내이름" 을 쓰면 그 줄 왼쪽 분홍 띠 + @이름 분홍 글씨 + 띵 (내가 쓴 말은 빼요)
local atSnd = 0
local function Mention(f, text, d)
    if d.atOn == false then return text end
    local me = UnitName("player")
    if type(me) ~= "string" or me == "" then return text end
    local who = text:match("|Hplayer:([^:|]+)")
    if who and who:gsub("%-.*$", "") == me then return text end
    -- 링크 · 색 코드를 뺀 글에서 "@이름" 찾기 (영어 이름은 대소문자 무시)
    local plain = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local lp, lm = plain:lower(), ("@" .. me):lower()
    local s0, e0 = lp:find(lm, 1, true)
    if not s0 then return text end
    local nx = plain:sub(e0 + 1, e0 + 1)
    if nx ~= "" and nx:match("%w") then return text end   -- 영어 이름이 더 길면 (@Leel → @Leelu) 아니에요 · 한글은 "@르엘님"도 알아들어요
    -- 글 안의 "@이름" 을 분홍으로 (링크 밖 글자만)
    local out, i, low = {}, 1, text:lower()
    while true do
        local a, b = low:find(lm, i, true)
        if not a then break end
        out[#out + 1] = text:sub(i, a - 1)
        out[#out + 1] = "|cffffb3c6" .. text:sub(a, b) .. "|r"
        i = b + 1
    end
    out[#out + 1] = text:sub(i)
    text = table.concat(out)
    local _, size = f:GetFont()
    local h = math.floor((size or 13) + 2.5)
    text = ("|TInterface\\Buttons\\WHITE8X8:%d:3:0:0:8:8:0:8:0:8:242:179:194|t "):format(h) .. text
    if not d.atSndV then d.atSnd = "pager"; d.atSndV = 1 end   -- 삐삐 호출로 정했어요 (한 번만)
    local snd = d.atSnd or "pager"
    if snd ~= "off" and GetTime() - atSnd > 1.5 and not (d.atCombat and InCombatLockdown()) then
        atSnd = GetTime()
        ns.ChatAtSound(snd)
    end
    return text
end

local function Decorate(f, text)
    if type(text) ~= "string" then return text end
    if issecretvalue and issecretvalue(text) then return text end
    local d = DB()
    do local ok, t = pcall(Mention, f, text, d); if ok and t then text = t end end
    if d.myName then
        local me = UnitName("player")
        if me and me ~= "" then
            local plain = text:gsub("|H.-|h.-|h", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if plain:find(me, 1, true) then
                local _, size = f:GetFont()
                local h = math.floor((size or 13) + 0.5)
                text = ("|T%sfx_heart:%d:%d:0:0:64:64:0:64:0:64:242:179:194|t "):format(ns.MEDIA, h, h) .. text
            end
        end
    end
    local ts = d.ts or "off"
    if ts ~= "off" then
        text = "|cff8a7a78" .. date(ts == "hms" and "%H:%M:%S" or "%H:%M") .. "|r " .. text
    end
    return text
end
ns.ChatDecorate = Decorate

local function HookMessages(f)
    if f.leelChip or f == ChatFrame2 then return end
    f.leelChip = true
    local orig = f.AddMessage
    f.AddMessage = function(self, text, ...)
        if DB().chips ~= false then
            local ok, t2 = pcall(Chipify, self, text)
            if ok and t2 then text = t2 end
        end
        local ok, t3 = pcall(Decorate, self, text)
        if ok and t3 then text = t3 end
        return orig(self, text, ...)
    end
end

-- 글씨 크기 · 글 흐려지기 (허브)
function ns.ChatApplyLook(user)
    local d = DB()
    for _, f in ipairs(Docked()) do
        if d.fsize and user then
            if FCF_SetChatWindowFontSize then pcall(FCF_SetChatWindowFontSize, nil, f, d.fsize)
            else local font, _, fl = f:GetFont(); pcall(f.SetFont, f, font, d.fsize, fl) end
        end
        if f.SetFading then pcall(f.SetFading, f, d.fade ~= false) end
    end
end
-- 귓말 소리 (허브)
do
    local wf = CreateFrame("Frame")
    wf:RegisterEvent("CHAT_MSG_WHISPER"); pcall(wf.RegisterEvent, wf, "CHAT_MSG_BN_WHISPER")
    wf:RegisterEvent("PLAYER_LOGIN")
    wf:SetScript("OnEvent", function(_, ev)
        if not ns.db then return end
        if ev == "PLAYER_LOGIN" then C_Timer.After(1, function() if DB().fade == false then ns.ChatApplyLook() end end) return end
        if DB().wSound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081, "Master") end
    end)
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
        if ns.MoveSkin then ns.MoveSkin(mover, "채팅창") end
        -- 크기 손잡이 (아래 끝은 그대로, 위·오른쪽으로 늘리고 줄여요)
        local grip = CreateFrame("Button", nil, mover)
        grip:SetSize(22, 22); grip:SetPoint("TOPRIGHT", -2, -2)
        grip:SetSize(26, 26)
        local gt = grip:CreateTexture(nil, "OVERLAY")
        gt:SetTexture(ns.MEDIA .. "grip_resize"); gt:SetAllPoints()
        local gh = grip:CreateTexture(nil, "HIGHLIGHT")
        gh:SetTexture(ns.MEDIA .. "circle"); gh:SetAllPoints(); gh:SetVertexColor(1, 1, 1, 0.25); gh:SetBlendMode("ADD")
        grip:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP"); ns.TSet(GameTooltip, "끌면 크기 조절"); GameTooltip:Show()
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

----------------------------------------------------------------------
-- 보낸 말 다시 쓰기 (B안): 입력칸에서 ↑ = 최근 보낸 말 목록이 입력칸 위로
--   ↑ ↓ 로 고르면 입력칸에 바로 들어가요 (채널도 같이) · Enter = 보내기
--   ← → 나 글을 고치면 목록만 닫혀요 · ↓ 를 끝까지 = 쓰던 글로 돌아가기 · Alt + ↑ 는 게임 기본 그대로
--   최근 5개 기억 (ns.db.chat.hist, 접속을 끊어도 남아요) · 허브 > 채팅창 > 보낸 말 다시 쓰기
----------------------------------------------------------------------
do
    local MAXH, SHOW, RH = 5, 5, 22   -- 최근 5개만 기억 · 5줄
    local pop, cur, draft, owner, filling = nil, 0, nil, nil, false
    local function H()
        local d = DB(); d.hist = d.hist or {}
        while #d.hist > MAXH do table.remove(d.hist) end   -- 예전에 20개까지 쌓인 것도 5개로
        return d.hist
    end
    local function On() return DB().histOn ~= false end
    local NAME = { SAY = "일반", PARTY = "파티", PARTY_LEADER = "파티", GUILD = "길드", OFFICER = "관리자", RAID = "공격대",
                   RAID_LEADER = "공격대", RAID_WARNING = "공격대 경보", INSTANCE_CHAT = "인스턴스", YELL = "외침", EMOTE = "감정",
                   WHISPER = "귓속말", BN_WHISPER = "귓속말" }
    local function Label(h)
        if h.text:sub(1, 1) == "/" then return "명령", { 0.8, 0.75, 0.72 } end
        local info = ChatTypeInfo and ChatTypeInfo[h.t or "SAY"]
        if h.t == "CHANNEL" and h.ch then info = ChatTypeInfo and ChatTypeInfo["CHANNEL" .. h.ch] or info end
        local c = (info and info.r) and { info.r, info.g, info.b } or { 1, 1, 1 }
        local n = NAME[h.t or "SAY"] or h.t or "일반"
        if h.t == "CHANNEL" then n = h.chName or ("채널 " .. (h.ch or "")) end
        if (h.t == "WHISPER" or h.t == "BN_WHISPER") and h.tell then n = "귓속말 · " .. h.tell end
        return n, c
    end
    -- 보낸 말 기억
    local function Remember(eb, text)
        if not On() or type(text) ~= "string" or not text:find("%S") then return end
        if issecretvalue and issecretvalue(text) then return end
        local t = eb:GetAttribute("chatType")
        local h = { text = text, t = t, at = time() }
        if t == "CHANNEL" then
            h.ch = eb:GetAttribute("channelTarget")
            local okN, _, nm = pcall(GetChannelName, h.ch or 0)
            if okN and type(nm) == "string" then h.chName = (nm:gsub("%s*%-.*$", "")) end
        elseif t == "WHISPER" or t == "BN_WHISPER" then
            h.tell = eb:GetAttribute("tellTarget")
        end
        local list = H()
        for i = #list, 1, -1 do if list[i].text == text and list[i].t == t then table.remove(list, i) end end
        table.insert(list, 1, h)
        while #list > MAXH do table.remove(list) end
    end

    local Close
    local function Fill(eb, h)
        filling = true
        if h.text:sub(1, 1) ~= "/" and h.t and h.t ~= eb:GetAttribute("chatType") then
            pcall(eb.SetAttribute, eb, "chatType", h.t)
            if h.t == "CHANNEL" and h.ch then pcall(eb.SetAttribute, eb, "channelTarget", h.ch) end
            if (h.t == "WHISPER" or h.t == "BN_WHISPER") and h.tell then pcall(eb.SetAttribute, eb, "tellTarget", h.tell) end
            if ChatEdit_UpdateHeader then pcall(ChatEdit_UpdateHeader, eb) end
        end
        eb:SetText(h.text); eb:SetCursorPosition(#h.text)
        filling = false
    end
    -- A안: 조용한 목록 · 왼쪽 얇은 채널 색 줄 · 오른쪽 보낸 시간 · 고른 줄은 옅은 분홍 + 얇은 테
    local PANEL = { 0.118, 0.086, 0.078 }
    local SELF = { 0.215, 0.160, 0.158 }
    local function Ago(at)
        if not at then return "" end
        local d = time() - at
        if d < 60 then return "방금" elseif d < 3600 then return math.floor(d / 60) .. "분"
        elseif d < 86400 then return math.floor(d / 3600) .. "시간" end
        return math.floor(d / 86400) .. "일"
    end
    local function Key(parent, text)
        local k = CreateFrame("Frame", nil, parent)
        k:SetHeight(15)
        k.edge = ns.RoundRect(k, 4, { 0.42, 0.33, 0.31 }, "BACKGROUND", 0, 0)
        k.bg = ns.RoundRect(k, 4, { 0.227, 0.18, 0.169 }, "BACKGROUND", 1, 1)
        k.fs = ns.Font(k, 9.5, { 0.85, 0.78, 0.76 }); k.fs:SetPoint("CENTER", 0, 0.5); k.fs:SetText(text)
        k:SetWidth(math.max(15, k.fs:GetStringWidth() + 9))
        return k
    end
    local function Row(i)
        local r = pop.rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, pop)
        r:SetHeight(RH)
        r.rim = ns.RoundRect(r, 9, { 0.949, 0.702, 0.761 }, "BACKGROUND", 0, 0); r.rim:SetColor({ 0.949, 0.702, 0.761 }, 0.45)
        r.fill = ns.RoundRect(r, 9, SELF, "BACKGROUND", 1, 1); r.fill:SetColor(SELF, 1)
        r.bar = r:CreateTexture(nil, "ARTWORK"); r.bar:SetTexture(ns.WHITE or "Interface\\Buttons\\WHITE8X8")
        r.bar:SetWidth(2.5); r.bar:SetPoint("TOPLEFT", 4, -5); r.bar:SetPoint("BOTTOMLEFT", 4, 5)
        r.ago = ns.Font(r, 10, { 0.49, 0.42, 0.40 }); r.ago:SetPoint("RIGHT", -10, 0); r.ago:SetJustifyH("RIGHT")
        r.fs = ns.Font(r, 12.5); r.fs:SetPoint("LEFT", 14, 0); r.fs:SetPoint("RIGHT", r.ago, "LEFT", -8, 0)
        r.fs:SetJustifyH("LEFT"); r.fs:SetWordWrap(false)
        r:SetScript("OnClick", function(self)
            if not owner or not self.h then return end
            cur = self.i; Fill(owner, self.h); pop.Paint(); owner:SetFocus()
        end)
        r:SetScript("OnEnter", function(self) if self.i ~= cur then for _, t in ipairs(self.fill.tex) do t:Show() end; self.fill:SetColor({ 0.16, 0.12, 0.115 }, 1) end end)
        r:SetScript("OnLeave", function() if pop.Paint then pop.Paint() end end)
        pop.rows[i] = r
        return r
    end
    local HEAD = 24
    local function Make()
        pop = CreateFrame("Frame", "LeelUI_ChatHistory", UIParent)
        pop:SetFrameStrata("DIALOG"); pop:SetClampedToScreen(true)
        pop.edge = ns.RoundRect(pop, 14, { 0.30, 0.22, 0.21 }, "BACKGROUND", -1, -1); pop.edge:SetColor({ 0.30, 0.22, 0.21 }, 0.9)
        pop.bg = ns.RoundRect(pop, 14, PANEL, "BACKGROUND", 0, 0); pop.bg:SetColor(PANEL, 0.96)
        pop.title = ns.Font(pop, 10.5, { 0.54, 0.46, 0.45 }); pop.title:SetPoint("TOPLEFT", 14, -8); pop.title:SetText("보낸 말")
        -- 오른쪽 위: [↑] [↓] 고르기  [Enter] 보내기
        local send = ns.Font(pop, 10.5, { 0.54, 0.46, 0.45 }); send:SetPoint("TOPRIGHT", -12, -8); send:SetText("보내기")
        local kE = Key(pop, "Enter"); kE:SetPoint("RIGHT", send, "LEFT", -4, 0)
        local pick = ns.Font(pop, 10.5, { 0.54, 0.46, 0.45 }); pick:SetPoint("RIGHT", kE, "LEFT", -10, 0); pick:SetText("고르기")
        local kD = Key(pop, "↓"); kD:SetPoint("RIGHT", pick, "LEFT", -4, 0)
        local kU = Key(pop, "↑"); kU:SetPoint("RIGHT", kD, "LEFT", -3, 0)
        pop.line = pop:CreateTexture(nil, "ARTWORK"); pop.line:SetTexture(ns.WHITE or "Interface\\Buttons\\WHITE8X8")
        pop.line:SetHeight(1); pop.line:SetPoint("TOPLEFT", 8, -HEAD); pop.line:SetPoint("TOPRIGHT", -8, -HEAD)
        pop.line:SetVertexColor(1, 1, 1, 0.05)
        pop.rows = {}
        function pop.Paint()
            local list = H()
            local n = math.min(SHOW, #list)
            local top = math.max(1, math.min(cur - SHOW + 1, #list - n + 1))
            if cur < top then top = cur end
            for i = 1, SHOW do
                local r = Row(i)
                local idx = top + n - i     -- 오래된 말이 위, 최근 말이 아래 (입력칸 쪽)
                local h = (i <= n) and list[idx] or nil
                if h then
                    r.h, r.i = h, idx
                    local _, c = Label(h)
                    local on = (idx == cur)
                    for _, t in ipairs(r.rim.tex) do t:SetShown(on) end
                    for _, t in ipairs(r.fill.tex) do t:SetShown(on) end
                    r.fill:SetColor(SELF, 1)
                    r.bar:SetVertexColor(c[1], c[2], c[3], on and 1 or 0.85)
                    local txt = h.text
                    if (h.t == "WHISPER" or h.t == "BN_WHISPER") and h.tell and h.text:sub(1, 1) ~= "/" then
                        txt = txt .. "  |cff8a7672→ " .. h.tell .. "|r"
                    elseif h.t == "CHANNEL" and h.chName then
                        txt = txt .. "  |cff8a7672" .. h.chName .. "|r"
                    end
                    r.fs:SetText(txt)
                    if on then r.fs:SetTextColor(1, 0.97, 0.96) else r.fs:SetTextColor(0.91, 0.86, 0.85) end
                    r.ago:SetText(Ago(h.at))
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", 6, -HEAD - 4 - (i - 1) * RH); r:SetPoint("TOPRIGHT", -6, -HEAD - 4 - (i - 1) * RH)
                    r:Show()
                else
                    r:Hide()
                end
            end
            pop:SetHeight(HEAD + 8 + n * RH)
        end
    end
    Close = function(restore)
        if not pop or not pop:IsShown() then return end
        pop:Hide()
        if restore and owner and draft then filling = true; owner:SetText(draft); owner:SetCursorPosition(#draft); filling = false end
        cur, draft = 0, nil
    end
    local function Open(eb)
        local list = H()
        if #list == 0 then return end
        if not pop then Make() end
        owner, draft, cur = eb, eb:GetText() or "", 1
        pop:ClearAllPoints()
        pop:SetPoint("BOTTOMLEFT", eb, "TOPLEFT", 0, 6)
        pop:SetWidth(math.max(260, eb:GetWidth()))
        pop:SetScale(eb:GetEffectiveScale() / UIParent:GetEffectiveScale())
        pop:Show(); pop.Paint()
        Fill(eb, list[cur])
    end
    local lastKey = 0
    -- 게임 기본 기록도 ↑ ↓ 에 글을 바꿔서, 한 박자 뒤에 우리 글로 다시 덮어요
    local function Later(eb, fn)
        eb.leelArrowAt = GetTime()
        fn()
        C_Timer.After(0, function() eb.leelArrowAt = GetTime(); fn() end)
    end
    local function OnArrow(eb, key)
        if not On() or (IsAltKeyDown and IsAltKeyDown()) then return end
        if ns.ChatAtOpen and ns.ChatAtOpen(eb) then return end   -- @이름 고르기 목록이 떠 있으면 그쪽이 화살표를 써요
        local now = GetTime()
        if now == lastKey then return end   -- 같은 누름이 두 번 오지 않게
        lastKey = now
        local open = pop and pop:IsShown() and owner == eb
        if key == "UP" then
            if not open then Open(eb)
            elseif cur < #H() then cur = cur + 1; pop.Paint() end
            if pop and pop:IsShown() then local h = H()[cur]; Later(eb, function() if h then Fill(eb, h) end end) end
        elseif key == "DOWN" then
            if not open then
                local t = eb:GetText()   -- 기본 기록이 바꾼 글은 그대로 두지 않고 되돌려요
                Later(eb, function() if eb:GetText() ~= t then filling = true; eb:SetText(t); eb:SetCursorPosition(#t); filling = false end end)
                return
            end
            if cur <= 1 then
                local d = draft or ""
                Close(false)
                Later(eb, function() filling = true; eb:SetText(d); eb:SetCursorPosition(#d); filling = false end)
            else
                cur = cur - 1; pop.Paint()
                local h = H()[cur]
                Later(eb, function() Fill(eb, h) end)
            end
        elseif key == "LEFT" or key == "RIGHT" then
            if open then Close(false) end
        end
    end
    local function Hook(eb)
        if not eb or eb.leelHist then return end
        eb.leelHist = true
        -- 화살표를 입력칸이 받게 (Alt 없이) · 끄면 게임 기본(Alt + 화살표)으로
        if On() and eb.SetAltArrowKeyMode then pcall(eb.SetAltArrowKeyMode, eb, false) end
        eb:HookScript("OnKeyDown", function(self, key) OnArrow(self, key) end)
        pcall(eb.HookScript, eb, "OnArrowPressed", function(self, key) OnArrow(self, key) end)
        eb:HookScript("OnTextChanged", function(self, user)
            local t = self:GetText() or ""
            if user and not filling and not (self.leelArrowAt and GetTime() - self.leelArrowAt < 0.2)
                and pop and pop:IsShown() and owner == self then Close(false) end
            if t ~= "" then self.leelHistLast = t else self.leelHistClr = GetTime() end
            self.leelHistTxt = t
        end)
        -- 보낸 말 기억: Enter 뒤 (지워지기 직전 글)
        -- (게임이 글을 지우는 때가 Enter 뒤일 수도, 앞일 수도 있어서 마지막으로 쓰여 있던 글을 기억해요)
        eb:HookScript("OnEnterPressed", function(self)
            local t = self.leelHistLast
            local sent = (self.leelHistTxt or "") ~= "" or (self.leelHistClr and GetTime() - self.leelHistClr < 0.1)
            self.leelHistLast = nil
            if pop and pop:IsShown() then Close(false) end
            if self.leelHistSent and GetTime() - self.leelHistSent < 0.2 then return end
            if sent and t and t ~= "" then Remember(self, t) end
        end)
        eb:HookScript("OnHide", function(self) if owner == self then Close(false) end end)
        -- ESC · 다른 곳 클릭: 입력칸이 꺼지면(숨지 않고 흐려지기만 해도) 목록도 같이 닫기
        eb:HookScript("OnEscapePressed", function(self) if owner == self then Close(false) end end)
        eb:HookScript("OnEditFocusLost", function(self)
            if owner ~= self then return end
            if pop and pop:IsShown() and pop:IsMouseOver() then return end   -- 목록 줄을 누르는 중이면 그대로
            Close(false)
        end)
    end
    ns.ChatHistApply = function()
        for i = 1, (NUM_CHAT_WINDOWS or 10) do
            local eb = _G["ChatFrame" .. i .. "EditBox"]
            if eb and eb.SetAltArrowKeyMode then pcall(eb.SetAltArrowKeyMode, eb, not On()) end
        end
    end
    SLASH_LEELCHATHIST1 = "/르엘채팅기록"
    SlashCmdList.LEELCHATHIST = function()
        local eb = ChatFrame1EditBox
        print(ns.L("|cfff2b3c2[르엘 채팅]|r 기억한 말 %d개 · 켜짐 %s · 연결 %s · Alt 화살표 %s"):format(#H(), tostring(On()),
            tostring(eb and eb.leelHist), tostring(eb and eb.GetAltArrowKeyMode and eb:GetAltArrowKeyMode())))
    end
    if ChatEdit_AddHistory then
        hooksecurefunc("ChatEdit_AddHistory", function(eb) if eb and eb.leelHist then Remember(eb, eb:GetText()); eb.leelHistSent = GetTime() end end)
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        C_Timer.After(1.5, function()
            for i = 1, (NUM_CHAT_WINDOWS or 10) do Hook(_G["ChatFrame" .. i .. "EditBox"]) end
        end)
    end)
end

----------------------------------------------------------------------
-- @이름 고르기 (D안): 입력칸에 @ 를 치면 파티원 · 접속 중 길드원 · 최근 말한 사람 목록이 입력칸 위로
--   ↑ ↓ 로 고르면 바로 "@이름 " 이 채워져요 · Tab = 맨 위 이름으로 채우기 · 계속 치면 좁혀져요
--   허브 > 채팅창 > @ 치면 이름 고르기
----------------------------------------------------------------------
do
    local SHOW, RH = 6, 22
    local pop, owner, list, cur, filling = nil, nil, {}, 0, false
    local recent = {}   -- { name, cls } 최근 말한 사람 (새 것이 앞)
    local function On() return DB().atPick ~= false end
    local function Short(n) return type(n) == "string" and not (issecretvalue and issecretvalue(n)) and (n:gsub("%-.*$", "")) or nil end
    local function Push(name, cls)
        name = Short(name)
        if not name or name == Short(UnitName("player")) then return end
        for i = #recent, 1, -1 do if recent[i][1] == name then table.remove(recent, i) end end
        table.insert(recent, 1, { name, cls })
        while #recent > 30 do table.remove(recent) end
    end
    local function Candidates(q)
        local out, seen = {}, {}
        local lq = (q or ""):lower()
        local function Add(name, cls, tag)
            name = Short(name)
            if not name or seen[name] or name == Short(UnitName("player")) then return end
            if lq ~= "" and name:lower():sub(1, #lq) ~= lq then return end
            seen[name] = true
            out[#out + 1] = { name = name, cls = cls, tag = tag }
        end
        if IsInRaid and IsInRaid() then
            for i = 1, 40 do local u = "raid" .. i; if UnitExists(u) then local _, c = UnitClass(u); Add(UnitName(u), c, "공대") end end
        else
            for i = 1, 4 do local u = "party" .. i; if UnitExists(u) then local _, c = UnitClass(u); Add(UnitName(u), c, "파티") end end
        end
        for _, r in ipairs(recent) do Add(r[1], r[2], "최근") end
        if IsInGuild and IsInGuild() and GetNumGuildMembers then
            local n = GetNumGuildMembers() or 0
            for i = 1, math.min(n, 500) do
                local ok, name, _, _, _, _, _, _, _, online, _, cls = pcall(GetGuildRosterInfo, i)
                if ok and online then Add(name, cls, "길드") end
                if #out >= 30 then break end
            end
        end
        return out
    end
    local function Query(eb)
        local t = eb:GetText() or ""
        local pos = eb:GetCursorPosition() or #t
        local before = t:sub(1, pos)
        if before:sub(1, 1) == "/" then return nil end
        local a, q = before:match("()@([^%s@]*)$")
        if not a then return nil end
        if a > 1 and not before:sub(a - 1, a - 1):match("%s") then return nil end   -- 메일 주소처럼 글자 뒤 @ 는 빼요
        return a, q, pos
    end
    local function Fill(eb, name)
        local a, _, pos = Query(eb)
        if not a then return end
        local t = eb:GetText() or ""
        local nt = t:sub(1, a - 1) .. "@" .. name .. " " .. t:sub(pos + 1)
        filling = true
        eb:SetText(nt); eb:SetCursorPosition(a + #name + 1)
        filling = false
    end
    local function Close() if pop then pop:Hide() end; cur = 0 end
    local function ClassCol(c) local cc = c and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c]; return cc and { cc.r, cc.g, cc.b } or { 0.85, 0.8, 0.78 } end
    local function Make()
        pop = CreateFrame("Frame", "LeelUI_ChatAt", UIParent)
        pop:SetFrameStrata("DIALOG"); pop:SetClampedToScreen(true)
        pop.edge = ns.RoundRect(pop, 12, { 0.949, 0.702, 0.761 }, "BACKGROUND", -1, -1); pop.edge:SetColor({ 0.949, 0.702, 0.761 }, 0.6)
        pop.bg = ns.RoundRect(pop, 12, { 0.118, 0.086, 0.078 }, "BACKGROUND", 0, 0); pop.bg:SetColor({ 0.118, 0.086, 0.078 }, 0.97)
        pop.hint = ns.Font(pop, 10, { 0.54, 0.46, 0.45 }); pop.hint:SetPoint("BOTTOMLEFT", 12, 6); pop.hint:SetText("↑ ↓ 고르기 · Tab 채우기")
        pop.rows = {}
        function pop.Paint()
            local n = math.min(SHOW, #list)
            for i = 1, SHOW do
                local r = pop.rows[i]
                if not r then
                    r = CreateFrame("Button", nil, pop); r:SetHeight(RH)
                    r.hl = ns.RoundRect(r, 8, { 0.949, 0.702, 0.761 }, "BACKGROUND", 1, 0)
                    r.dot = r:CreateTexture(nil, "ARTWORK"); r.dot:SetTexture(ns.MEDIA .. "circle"); r.dot:SetSize(12, 12); r.dot:SetPoint("LEFT", 8, 0)
                    r.fs = ns.Font(r, 12.5); r.fs:SetPoint("LEFT", r.dot, "RIGHT", 7, 0)
                    r.tag = ns.Font(r, 10, { 0.6, 0.52, 0.5 }); r.tag:SetPoint("RIGHT", -8, 0)
                    r:SetScript("OnClick", function(self) if owner and self.c then Fill(owner, self.c.name); Close(); owner:SetFocus() end end)
                    pop.rows[i] = r
                end
                local c = list[i]
                if i <= n and c then
                    r.c = c
                    local col = ClassCol(c.cls)
                    r.dot:SetVertexColor(col[1], col[2], col[3], 1)
                    r.fs:SetText(c.name); r.tag:SetText(c.tag or "")
                    r.hl:SetColor({ 0.949, 0.702, 0.761 }, i == cur and 0.22 or 0)
                    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 6, -6 - (i - 1) * RH); r:SetPoint("TOPRIGHT", -6, -6 - (i - 1) * RH)
                    r:Show()
                else
                    r:Hide(); r.c = nil
                end
            end
            pop:SetHeight(12 + n * RH + 18)
        end
    end
    local function Update(eb)
        if not On() or filling then return end
        local a, q = Query(eb)
        if not a then Close() return end
        list = Candidates(q)
        if #list == 0 then Close() return end
        if not pop then Make() end
        owner = eb
        if cur > #list or cur < 0 then cur = 0 end
        pop:ClearAllPoints(); pop:SetPoint("BOTTOMLEFT", eb, "TOPLEFT", 0, 6); pop:SetWidth(220)
        pop:SetScale(eb:GetEffectiveScale() / UIParent:GetEffectiveScale())
        pop:Show(); pop.Paint()
    end
    ns.ChatAtOpen = function(eb) return pop and pop:IsShown() and owner == eb end
    local function Pick(eb, step)
        local n = math.min(SHOW, #list)
        if n == 0 then return end
        cur = cur + step
        if cur < 1 then cur = n elseif cur > n then cur = 1 end
        local t = eb:GetText()
        local name = list[cur].name
        -- 게임 기본 기록이 화살표에 글을 바꿔서, 한 박자 뒤 우리 글로 다시
        C_Timer.After(0, function()
            filling = true; eb:SetText(t); filling = false
            pop.Paint()
        end)
        pop.Paint()
        eb.leelAtPick = name
    end
    local function Hook(eb)
        if not eb or eb.leelAt then return end
        eb.leelAt = true
        eb:HookScript("OnTextChanged", function(self, user) if user then Update(self) end end)
        eb:HookScript("OnKeyDown", function(self, key)
            if not ns.ChatAtOpen(self) then return end
            if key == "UP" then Pick(self, -1) elseif key == "DOWN" then Pick(self, 1)
            elseif key == "ESCAPE" then Close() end
        end)
        eb:HookScript("OnTabPressed", function(self)
            if not ns.ChatAtOpen(self) then return end
            local c = list[(cur > 0) and cur or 1]
            local t = self:GetText()
            if c then
                -- 게임 기본 Tab(채널 바꾸기 · 이름 완성)이 글을 바꿨으면 되돌린 뒤 채워요
                C_Timer.After(0, function() filling = true; self:SetText(t); filling = false; Fill(self, c.name); Close() end)
            end
        end)
        eb:HookScript("OnEnterPressed", function() Close() end)
        eb:HookScript("OnEscapePressed", function() Close() end)
        eb:HookScript("OnHide", function(self) if owner == self then Close() end end)
        eb:HookScript("OnEditFocusLost", function(self)
            if owner == self and not (pop and pop:IsMouseOver()) then Close() end
        end)
    end
    -- 화살표로 고른 이름은 Enter 대신 Tab 으로 채워요 (고른 줄 = 분홍)
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    for _, e in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
                         "CHAT_MSG_GUILD", "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL", "CHAT_MSG_INSTANCE_CHAT" }) do pcall(f.RegisterEvent, f, e) end
    f:SetScript("OnEvent", function(_, ev, _, sender, ...)
        if ev == "PLAYER_LOGIN" then
            C_Timer.After(1.6, function() for i = 1, (NUM_CHAT_WINDOWS or 10) do Hook(_G["ChatFrame" .. i .. "EditBox"]) end end)
            return
        end
        local guid = select(10, ...)
        local cls
        if type(guid) == "string" and not (issecretvalue and issecretvalue(guid)) and GetPlayerInfoByGUID then
            local ok, _, c = pcall(GetPlayerInfoByGUID, guid); if ok then cls = c end
        end
        pcall(Push, sender, cls)
    end)
end

----------------------------------------------------------------------
-- 파티원 말풍선 직업 색 (G안): 파티 중에 파티원(나 포함)이 말하면 머리 위 말풍선을
--   어두운 르엘 판 + 얇은 회색 테 + 왼쪽 세로 직업 색 띠로 (I안). 파티 아닌 사람 말풍선은 그대로.
--   던전 · 공격대 · 전장 안 말풍선은 게임이 못 바꾸게 막아서 기본 그대로예요.
--   허브 > 채팅창 > 파티원 말풍선 직업 색
----------------------------------------------------------------------
do
    local recent = {}   -- [말] = { col = {r,g,b}, at = 시간 }
    local function On() return DB().bubbleCls ~= false end
    -- "이름-서버" · 와우 포에버 채팅의 "이름 길드" 꼴도 앞 이름만 (와우 이름엔 띄어쓰기가 없어요)
    local function Short(n) return type(n) == "string" and (n:gsub("%-.*$", ""):gsub("%s.*$", "")) or nil end
    local function ClassOf(name)
        if not (IsInGroup and IsInGroup()) then return end
        local me = Short(UnitName("player"))
        local units = { "player" }
        if IsInRaid and IsInRaid() then for i = 1, 40 do units[#units + 1] = "raid" .. i end
        else for i = 1, 4 do units[#units + 1] = "party" .. i end end
        for _, u in ipairs(units) do
            if UnitExists(u) then
                local nm = Short(UnitName(u))
                if nm and nm == name then local _, c = UnitClass(u); return c end
            end
        end
        if name == me then local _, c = UnitClass("player"); return c end
    end
    local function Skin(child, col)
        if not child.leelBub then
            -- 글자 뒤에 깔리게: 말풍선 바깥 틀에 붙이고 한 단 아래로
            local s = CreateFrame("Frame", nil, child:GetParent() or child)
            s:SetFrameLevel(math.max(0, child:GetFrameLevel() - 2))
            -- I안 (시안 그대로): 직업 색 판을 깔고, 그 위에 어두운 판을 왼쪽으로 3px 비켜 얹어요
            --   → 왼쪽 테가 직업 색으로 두꺼워지고, 둥근 모서리를 따라 위아래로 살짝 감겨요
            s.cls = ns.RoundRect(s, 10, { 1, 1, 1 }, "BACKGROUND", 0, 0)
            s.body = CreateFrame("Frame", nil, s)
            s.body:SetPoint("TOPLEFT", 3, 0); s.body:SetPoint("BOTTOMRIGHT", 0, 0)
            s.body:SetFrameLevel(math.max(0, child:GetFrameLevel() - 1))   -- 글자보다는 아래
            s.body.rim = ns.RoundRect(s.body, 10, { 0.29, 0.23, 0.22 }, "BACKGROUND", 0, 0); s.body.rim:SetColor({ 0.29, 0.23, 0.22 }, 1)
            s.body.bg = ns.RoundRect(s.body, 10, { 0.118, 0.086, 0.078 }, "BACKGROUND", 1, 1); s.body.bg:SetColor({ 0.118, 0.086, 0.078 }, 0.95)
            child.leelBub = s
        end
        local s = child.leelBub
        local str = child.String or child.Text
        s:ClearAllPoints()
        if str then
            s:SetPoint("TOPLEFT", str, "TOPLEFT", -15, 8); s:SetPoint("BOTTOMRIGHT", str, "BOTTOMRIGHT", 12, -8)
        else
            s:SetAllPoints(child)
        end
        s.cls:SetColor(col, 1)
        s:Show()
        -- 기본 말풍선 그림 숨기기 (글자는 그대로)
        if child.NineSlice then child.NineSlice:SetAlpha(0) end
        if child.Tail then child.Tail:SetAlpha(0) end
        for _, r in ipairs({ child:GetRegions() }) do
            if r:GetObjectType() == "Texture" then r:SetAlpha(0); r.leelBubHid = true end
        end
        child.leelBubOn = true
    end
    local function Unskin(child)
        if not child.leelBubOn then return end
        child.leelBubOn = nil
        if child.leelBub then child.leelBub:Hide() end
        if child.NineSlice then child.NineSlice:SetAlpha(1) end
        if child.Tail then child.Tail:SetAlpha(1) end
        for _, r in ipairs({ child:GetRegions() }) do if r.leelBubHid then r:SetAlpha(1); r.leelBubHid = nil end end
    end
    local function Scan()
        if not (C_ChatBubbles and C_ChatBubbles.GetAllChatBubbles) then return end
        local ok, list = pcall(C_ChatBubbles.GetAllChatBubbles, false)   -- false = 던전 안 말풍선은 빼고
        if not ok or type(list) ~= "table" then return end
        local now = GetTime()
        for k, v in pairs(recent) do if now - v.at > 30 then recent[k] = nil end end
        for _, b in ipairs(list) do
            local okC, child = pcall(b.GetChildren, b)
            if okC and child and not (child.IsForbidden and child:IsForbidden()) then
                local str = child.String or child.Text
                if not str then
                    for _, r in ipairs({ child:GetRegions() }) do if r:GetObjectType() == "FontString" then str = r break end end
                    child.String = child.String or str
                end
                local okT, txt = pcall(str and str.GetText or function() end, str)
                local hit = okT and type(txt) == "string" and not (issecretvalue and issecretvalue(txt)) and recent[txt]
                if hit and On() then pcall(Skin, child, hit.col) else pcall(Unskin, child) end
            end
        end
    end
    local function Soon()
        C_Timer.After(0, Scan); C_Timer.After(0.1, Scan); C_Timer.After(0.4, Scan); C_Timer.After(1, Scan)
    end
    -- /르엘말풍선 : 말풍선이 안 바뀔 때 확인 (말풍선이 떠 있을 때 입력)
    SLASH_LEELBUBBLE1 = "/르엘말풍선"
    SlashCmdList.LEELBUBBLE = function()
        local P = function(t) print("|cfff2b3c2[르엘 말풍선]|r " .. t) end
        local n = 0; for _ in pairs(recent) do n = n + 1 end
        P(ns.L("켜짐 %s · 파티 %s · 기억한 말 %d · 파티 말풍선 설정 %s · 일반 말풍선 설정 %s"):format(tostring(On()),
            tostring(IsInGroup and IsInGroup()), n, tostring(GetCVar and GetCVar("chatBubblesParty")), tostring(GetCVar and GetCVar("chatBubbles"))))
        if not (C_ChatBubbles and C_ChatBubbles.GetAllChatBubbles) then P("C_ChatBubbles 없음") return end
        local ok, list = pcall(C_ChatBubbles.GetAllChatBubbles, true)
        if not ok or type(list) ~= "table" then P("말풍선 목록 못 읽음") return end
        P("지금 말풍선 " .. #list .. "개")
        for i, b in ipairs(list) do
            local forb = b.IsForbidden and b:IsForbidden()
            local kids = forb and 0 or select("#", b:GetChildren())
            local child = (not forb) and b:GetChildren() or nil
            local str = child and (child.String or child.Text)
            local txt = str and str:GetText()
            P(ns.L("%d: 막힘 %s · 자식 %d · 글 %s · 맞음 %s"):format(i, tostring(forb), kids, tostring(txt), tostring(txt and recent[txt] ~= nil)))
        end
    end
    local f = CreateFrame("Frame")
    for _, e in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" }) do pcall(f.RegisterEvent, f, e) end
    f:SetScript("OnEvent", function(_, _, msg, sender)
        if not On() or type(msg) ~= "string" or (issecretvalue and (issecretvalue(msg) or issecretvalue(sender))) then return end
        local cls = ClassOf(Short(sender))
        if not cls then return end
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
        if not c then return end
        recent[msg] = { col = { c.r, c.g, c.b }, at = GetTime() }
        Soon()
    end)
    ns.ChatBubbleRefresh = Scan
end

----------------------------------------------------------------------
-- 음성 채팅: 머리줄 오른쪽 소리 칩 (C안)
--   말하는 사람: 직업 아이콘 + 이름 (+ "외 N") + 움직이는 소리 막대 · 말 멈추면 1초 뒤 사라짐
--   블리자드 기본 "말하는 중" 알림은 투명하게 (허브 > 채팅창 "음성 채팅 칩")
----------------------------------------------------------------------
do
    local speaking, order = {}, {}      -- [key] = { name, cls, at }
    local chip
    local function VOn() return DB().on ~= false and DB().voiceChip ~= false end
    local function Build()
        if chip or not head then return chip end
        chip = CreateFrame("Frame", nil, head)
        chip:SetHeight(20); chip:SetPoint("RIGHT", head, "RIGHT", -36, -1)
        chip:SetFrameLevel(head:GetFrameLevel() + 3)
        ns.RoundRect(chip, 10, C.acc, "BACKGROUND", 0, 0)
        chip.ic = chip:CreateTexture(nil, "ARTWORK"); chip.ic:SetSize(16, 16); chip.ic:SetPoint("LEFT", 3, 0)
        chip.ic:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        chip.fs = ns.Font(chip, 11.5, { 0.1, 0.08, 0.09 }); chip.fs:SetShadowColor(0, 0, 0, 0); chip.fs:SetPoint("LEFT", chip.ic, "RIGHT", 4, 0)
        chip.more = ns.Font(chip, 10.5, { 0.42, 0.29, 0.31 }); chip.more:SetShadowColor(0, 0, 0, 0); chip.more:SetPoint("LEFT", chip.fs, "RIGHT", 3, 0)
        chip.bars = {}
        for i = 1, 3 do
            local b = chip:CreateTexture(nil, "ARTWORK"); b:SetTexture(ns.WHITE); b:SetVertexColor(0.23, 0.11, 0.14, 1)
            b:SetSize(3, 6); chip.bars[i] = b
        end
        chip:EnableMouse(true)
        chip:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            ns.TSet(GameTooltip, "음성 채팅 · 말하는 중", 1, 0.84, 0.88)
            for _, k in ipairs(order) do local s = speaking[k]; if s then GameTooltip:AddLine(s.name, 1, 1, 1) end end
            GameTooltip:Show()
        end)
        chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
        local t, acc = 0, 0
        chip:SetScript("OnUpdate", function(self, e)
            t = t + e; acc = acc + e
            for i, b in ipairs(self.bars) do b:SetHeight(4 + 7 * math.abs(math.sin(t * (6 + i * 1.7) + i))) end
            if acc < 0.25 then return end
            acc = 0
            local now, changed = GetTime(), false
            for k, s in pairs(speaking) do if s.off and now - s.off > 1 then speaking[k] = nil; changed = true end end
            if changed and ns.ChatVoicePaint then ns.ChatVoicePaint() end
        end)
        chip:Hide()
        return chip
    end
    function ns.ChatVoicePaint()
        local c = Build()
        if not c then return end
        wipe(order)
        for k, s in pairs(speaking) do order[#order + 1] = k end
        table.sort(order, function(a, b) return (speaking[a].at or 0) > (speaking[b].at or 0) end)
        local first = order[1] and speaking[order[1]]
        if not (VOn() and first) then
            c:Hide()
            for _, hc in ipairs(chipPool) do hc.dot:SetAlpha(1); hc.text:SetAlpha(1) end
            return
        end
        c.fs:SetText(first.name or "?")
        local tc = first.cls and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[first.cls]
        if tc then c.ic:SetTexCoord(tc[1], tc[2], tc[3], tc[4]); c.ic:Show() else c.ic:Hide() end
        c.more:SetText(#order > 1 and ns.L("외 " .. (#order - 1)) or "")
        -- 오른쪽부터 차례로: 소리 막대 → 외 N → 이름 → 아이콘 (막대가 늘 보이게)
        local function W(fs, def)
            local w = def
            pcall(function() local x = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth(); if type(x) == "number" and not (issecretvalue and issecretvalue(x)) then w = x end end)
            return w
        end
        for i, b in ipairs(c.bars) do b:ClearAllPoints(); b:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -7 - (3 - i) * 5, 5) end
        local mw = (#order > 1) and W(c.more, 20) or 0
        c.more:ClearAllPoints(); c.more:SetPoint("RIGHT", c, "RIGHT", -7 - 15 - 4, 0)
        local nw = math.min(W(c.fs, 50), 90)
        c.fs:SetWidth(nw); c.fs:SetWordWrap(false)
        c.fs:ClearAllPoints(); c.fs:SetPoint("RIGHT", c, "RIGHT", -7 - 15 - 4 - (mw > 0 and (mw + 3) or 0), 0)
        c.ic:ClearAllPoints(); c.ic:SetPoint("RIGHT", c.fs, "LEFT", -4, 0)
        c:SetWidth(3 + 16 + 4 + nw + (mw > 0 and (mw + 3) or 0) + 4 + 15 + 7)
        c:Show()
        -- 머리줄 채널 이름이 칩에 가리면 그 칩은 잠깐 숨겨요
        local left = c:GetLeft()
        for _, hc in ipairs(chipPool) do
            local r = hc.text:IsShown() and hc.text:GetRight()
            local dl = hc.dot:IsShown() and hc.dot:GetLeft()
            local ok = left and not (issecretvalue and (issecretvalue(left) or (r and issecretvalue(r)) or (dl and issecretvalue(dl))))
            -- 글자 끝이 칩에 닿거나, 점이 칩 바로 앞(글자가 들어갈 자리 없음)이면 숨김
            local over = ok and ((r and r > left - 4) or (dl and dl > left - 30)) or false
            hc.dot:SetAlpha(over and 0 or 1); hc.text:SetAlpha(over and 0 or 1)
        end
    end
    -- 블리자드 기본 알림 숨기기 (투명하게 · 기능은 그대로)
    local function Quiet()
        local m = _G.VoiceActivityManager
        if m and m.SetAlpha then pcall(m.SetAlpha, m, VOn() and 0 or 1) end
    end
    ns.ChatVoiceQuiet = Quiet
    local function Who(memberID, channelID)
        local guid
        if C_VoiceChat and C_VoiceChat.GetMemberGUID then
            local ok, g = pcall(C_VoiceChat.GetMemberGUID, memberID, channelID); if ok then guid = g end
        end
        local name, cls
        if guid and not (issecretvalue and issecretvalue(guid)) and GetPlayerInfoByGUID then
            local ok, _, c, _, _, _, n = pcall(GetPlayerInfoByGUID, guid)
            if ok then name, cls = n, c end
        end
        if not name and C_VoiceChat and C_VoiceChat.GetMemberName then
            local ok, n = pcall(C_VoiceChat.GetMemberName, memberID, channelID); if ok then name = n end
        end
        if issecretvalue and ((name and issecretvalue(name)) or (cls and issecretvalue(cls))) then return end
        return name, cls
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LOGIN")
    pcall(ev.RegisterEvent, ev, "VOICE_CHAT_CHANNEL_MEMBER_SPEAKING_STATE_CHANGED")
    pcall(ev.RegisterEvent, ev, "VOICE_CHAT_CHANNEL_DEACTIVATED")
    ev:SetScript("OnEvent", function(_, e, memberID, channelID, isSpeaking)
        if e == "PLAYER_LOGIN" then C_Timer.After(2, Quiet) return end
        if e == "VOICE_CHAT_CHANNEL_DEACTIVATED" then wipe(speaking); ns.ChatVoicePaint() return end
        if not VOn() then return end
        local key = tostring(channelID) .. ":" .. tostring(memberID)
        if isSpeaking then
            local name, cls = Who(memberID, channelID)
            speaking[key] = { name = name and Ambiguate(name, "short") or "?", cls = cls, at = GetTime() }
        elseif speaking[key] then
            speaking[key].off = GetTime()
        end
        ns.ChatVoicePaint()
    end)
end
