-- LeelUI / Profile.lua
-- 설정 나누기: 르엘 UI(+ Leel Map · Mark · Spot) 설정을 글자 한 줄로 내보내고, 다른 컴퓨터·친구가 붙여 넣어 가져오기
-- 허브 > 편의 > 설정 나누기

local _, ns = ...
local C = ns.C

local DBS = { "LeelUIDB", "LeelMapDB", "LeelMarkDB", "LeelSpotDB" }
local PREFIX = "LEELUI1:"

----------------------------------------------------------------------
-- 표 → 글자 (숫자 · 글자 · 참거짓 · 표만)
----------------------------------------------------------------------
local function Ser(v, depth)
    depth = depth or 0
    if depth > 12 then return "nil" end
    local t = type(v)
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "0" end
        return string.format("%.6g", v)
    elseif t == "boolean" then return v and "true" or "false"
    elseif t == "string" then return string.format("%q", v)
    elseif t == "table" then
        local out = {}
        for k, val in pairs(v) do
            local kt = type(k)
            if (kt == "string" or kt == "number") and type(val) ~= "function" and type(val) ~= "userdata" then
                local ks = kt == "string" and string.format("[%q]", k) or ("[" .. Ser(k) .. "]")
                out[#out + 1] = ks .. "=" .. Ser(val, depth + 1)
            end
        end
        return "{" .. table.concat(out, ",") .. "}"
    end
    return "nil"
end

-- base64 (표 하나로 4글자씩 · 긴 설정도 바로)
local B = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BI = {}
for i = 1, #B do BI[B:byte(i)] = i - 1 end
local floor = math.floor
local function Enc(data)
    local out, n = {}, 0
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local v = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1, c2, c3, c4 = floor(v / 262144) % 64, floor(v / 4096) % 64, floor(v / 64) % 64, v % 64
        n = n + 1
        out[n] = B:sub(c1 + 1, c1 + 1) .. B:sub(c2 + 1, c2 + 1)
            .. (b and B:sub(c3 + 1, c3 + 1) or "=") .. (c and B:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end
local function Dec(data)
    data = data:gsub("[^%w%+/]", "")
    local out, n = {}, 0
    for i = 1, #data, 4 do
        local a, b, c, d = data:byte(i, i + 3)
        a, b = BI[a], b and BI[b]
        if not (a and b) then break end
        c, d = c and BI[c], d and BI[d]
        local v = a * 262144 + b * 4096 + (c or 0) * 64 + (d or 0)
        local x1, x2, x3 = floor(v / 65536), floor(v / 256) % 256, v % 256
        n = n + 1
        if not c then out[n] = string.char(x1)
        elseif not d then out[n] = string.char(x1, x2)
        else out[n] = string.char(x1, x2, x3) end
    end
    return table.concat(out)
end

-- pick = { LeelUIDB = true, ... } 고른 것만 (없으면 전부)
function ns.ExportProfile(pick)
    local pack = {}
    for _, n in ipairs(DBS) do
        if type(_G[n]) == "table" and (not pick or pick[n]) then pack[n] = _G[n] end
    end
    local GM = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    pack.ver = GM and GM("LeelUI", "Version") or nil
    return PREFIX .. Enc("return " .. Ser(pack))
end

-- 글자 → 표 (아무 코드도 못 돌게 빈 환경에서 읽기)
function ns.ReadProfile(text)
    text = (text or ""):gsub("%s", "")
    if text:sub(1, #PREFIX) ~= PREFIX then return nil, "르엘 UI 설정 글자가 아니에요." end
    local src = Dec(text:sub(#PREFIX + 1))
    if not src:find("^return {") then return nil, "글자가 잘렸거나 깨졌어요." end
    local fn = loadstring(src)
    if not fn then return nil, "글자가 잘렸거나 깨졌어요." end
    setfenv(fn, {})
    local ok, pack = pcall(fn)
    local any = false
    if ok and type(pack) == "table" then
        for _, n in ipairs(DBS) do if type(pack[n]) == "table" then any = true end end
    end
    if not any then return nil, "읽을 수 없는 설정이에요." end
    return pack
end

function ns.ApplyProfile(pack)
    for _, n in ipairs(DBS) do
        if type(pack[n]) == "table" then
            _G[n] = pack[n]
        end
    end
    if ns.db then ns.db = _G.LeelUIDB end
end

----------------------------------------------------------------------
-- 창: 글자 상자 + 단추 (르엘 판)
----------------------------------------------------------------------
local win
local function Window()
    if win then return win end
    win = CreateFrame("Frame", "LeelUI_ProfileWin", UIParent)
    win:SetSize(460, 300)
    win:SetPoint("CENTER", 0, 60)
    win:SetFrameStrata("FULLSCREEN_DIALOG")   -- 허브(DIALOG)보다 위
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    ns.RoundPlate(win, 18, { 0.114, 0.082, 0.078, 0.97 }, { 0.949, 0.702, 0.761, 0.6 })
    tinsert(UISpecialFrames, "LeelUI_ProfileWin")

    win.title = ns.Font(win, 17, C.acc)
    win.title:SetPoint("TOPLEFT", 20, -16)
    win.hint = ns.Font(win, 12, C.tx2)
    win.hint:SetPoint("TOPLEFT", win.title, "BOTTOMLEFT", 0, -6)
    win.hint:SetWidth(420); win.hint:SetJustifyH("LEFT")

    local box = CreateFrame("Frame", nil, win)
    box:SetPoint("TOPLEFT", 18, -74); box:SetPoint("BOTTOMRIGHT", -18, 58)
    ns.RoundPlate(box, 12, { 0.07, 0.05, 0.05, 1 }, { 0.949, 0.702, 0.761, 0.3 })
    local sf = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 10, -8); sf:SetPoint("BOTTOMRIGHT", -28, 8)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true); eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(380)
    eb:SetScript("OnEscapePressed", function() win:Hide() end)
    sf:SetScrollChild(eb)
    win.eb = eb

    local function Btn(label, primary, x, fn)
        local b = ns.MakeButton(win, label, primary, fn)
        b:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", x, 16)
        return b
    end
    win.close = Btn("닫기", false, -18, function() win:Hide() end)
    win.ok = Btn("가져오기", true, -110, function()
        local pack, err = ns.ReadProfile(eb:GetText())
        if not pack then ns.Print(err) return end
        StaticPopupDialogs["LEELUI_PROFILE_APPLY"] = {
            text = "지금 설정을 붙여 넣은 설정으로 바꿀까요?\n바꾸면 다시 불러와요.",
            button1 = "바꾸기", button2 = "취소",
            OnAccept = function() ns.ApplyProfile(pack); ReloadUI() end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
        StaticPopup_Show("LEELUI_PROFILE_APPLY")
    end)
    win:Hide()
    return win
end

function ns:ShowProfileExport()
    local w = Window()
    w.title:SetText("내 설정 내보내기")
    w.hint:SetText("아래 글자를 Ctrl+A, Ctrl+C로 복사해서 친구에게 보내거나 다른 컴퓨터에 붙여 넣어요.")
    w.ok:Hide()
    w.eb:SetText(ns.ExportProfile())
    w:Show(); w:Raise()
    w.eb:SetFocus(); w.eb:HighlightText()
end

function ns:ShowProfileImport()
    local w = Window()
    w.title:SetText("설정 가져오기")
    w.hint:SetText("받은 설정 글자를 아래에 붙여 넣고(Ctrl+V) '가져오기'를 눌러요. 르엘 UI · 지도 · 징 · 반짝 상자 설정이 바뀌어요.")
    w.ok:Show()
    w.eb:SetText("")
    w:Show(); w:Raise()
    w.eb:SetFocus()
end

----------------------------------------------------------------------
-- 허브 > 설정 나누기 (B안): [보내기 | 받기] 탭 · 토끼가 편지를 나르는 그림 · 1-2-3 단계 카드
--   허브가 ns.HubSharePane(pane, x, y, w) 로 그리고, 다른 칸으로 가면 ns.HubShareHide()
----------------------------------------------------------------------
do
    local PARTS = {
        { "LeelUIDB", "르엘 UI", "hb_ui", "화면 · 채팅 · 퀘스트" },
        { "LeelMapDB", "Leel Map", "hb_map", "지도 · 미니맵" },
        { "LeelMarkDB", "징", "hb_mark", "징 표시" },
        { "LeelSpotDB", "반짝 상자", "hb_spot", "Leel Spot" },
    }
    local S = { tab = 1, pick = nil, out = false, copied = false, pack = nil, err = nil }
    local f
    local GREY = { 0.56, 0.48, 0.46 }
    local DARK = { 0.165, 0.125, 0.118, 0.95 }

    local function Pick()
        if not S.pick then
            S.pick = {}
            for _, pt in ipairs(PARTS) do S.pick[pt[1]] = type(_G[pt[1]]) == "table" end
        end
        return S.pick
    end
    local function PickN()
        local n, all = 0, 0
        for _, pt in ipairs(PARTS) do
            if type(_G[pt[1]]) == "table" then all = all + 1; if Pick()[pt[1]] then n = n + 1 end end
        end
        return n, all
    end

    local function Box(parent, r, fill, edge)
        local fr = CreateFrame("Frame", nil, parent)
        fr.fill, fr.edge = ns.RoundPlate(fr, r, fill, edge)
        return fr
    end
    local function Edit(parent)
        local bx = Box(parent, 8, { 0.07, 0.05, 0.05, 1 }, { 0.949, 0.702, 0.761, 0.35 })
        bx:SetHeight(28)
        local eb = CreateFrame("EditBox", nil, bx)
        eb:SetPoint("TOPLEFT", 9, -2); eb:SetPoint("BOTTOMRIGHT", -9, 2)
        eb:SetAutoFocus(false); eb:SetMaxLetters(0)
        eb:SetFontObject(ChatFontNormal)
        eb:SetTextColor(0.8, 0.72, 0.7)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        bx.eb = eb
        return bx
    end

    -- 단계 카드: 숫자 · 제목 · 설명 (+ 안에 넣을 것)
    local function StepCard(i)
        local c = Box(f, 14, DARK, { 1, 1, 1, 0.06 })
        c.no = c:CreateFontString(nil, "OVERLAY"); c.no:SetFont(ns.NUM or ns.FONT, 26, ""); c.no:SetText(i)
        c.no:SetTextColor(C.acc[1], C.acc[2], C.acc[3]); c.no:SetPoint("TOPLEFT", 16, -12)
        c.title = ns.Font(c, 14, C.tx); c.title:SetPoint("TOPLEFT", 16, -46)
        c.body = ns.Font(c, 11.5, GREY); c.body:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -7)
        c.body:SetJustifyH("LEFT"); c.body:SetJustifyV("TOP")
        if c.body.SetSpacing then c.body:SetSpacing(3) end
        c.btn = ns.MakeButton(c, "", true, nil, 90)
        c.btn:SetPoint("BOTTOMLEFT", 16, 14)
        return c
    end
    local function CardState(c, st)   -- "done" · "now" · ""
        c:SetAlpha(st == "done" and 0.55 or 1)
        if st == "now" then c.edge:SetColor(C.acc, 0.9); c.fill:SetColor({ 0.2, 0.15, 0.145 }, 0.98)
        else c.edge:SetColor({ 1, 1, 1 }, 0.06); c.fill:SetColor({ 0.165, 0.125, 0.118 }, 0.95) end
    end

    -- 단추 색: 분홍(누를 차례) / 어두운 판 · 글자 색도 같이 (만들 때 색이 그대로 남지 않게)
    local function Style(b, primary)
        b.primary = primary and true or false
        local c = b.primary and C.ink or C.tx
        b.fs:SetTextColor(c[1], c[2], c[3]); b.fs:SetShadowColor(0, 0, 0, b.primary and 0 or 0.85)
        b:Paint(false)
    end
    local Paint
    local function Build(parent)
        f = CreateFrame("Frame", nil, parent)
        -- 탭
        f.tabs = Box(f, 15, { 0.165, 0.125, 0.118, 0.95 }, { 1, 1, 1, 0.05 })
        f.tabs:SetSize(208, 32); f.tabs:SetPoint("TOPLEFT", 0, 0)
        f.tab = {}
        for i, label in ipairs({ "보내기", "받기" }) do
            local b = CreateFrame("Button", nil, f.tabs)
            b:SetSize(98, 24); b:SetPoint("LEFT", 4 + (i - 1) * 102, 0)
            b.bg = ns.RoundRect(b, 12, C.acc, "ARTWORK", 0, 0)
            b.fs = ns.Font(b, 12.5, C.tx); b.fs:SetPoint("CENTER", 0, 0); b.fs:SetText(label)
            b:SetScript("OnClick", function() if S.tab ~= i then S.tab = i; Paint() end end)
            f.tab[i] = b
        end
        -- 배달 그림
        local sc = Box(f, 16, { 0.16, 0.12, 0.115, 0.95 }, { 1, 1, 1, 0.06 })
        sc:SetPoint("TOPLEFT", 0, -46); sc:SetHeight(150)
        f.scene = sc
        sc.pc = {}
        for i = 1, 2 do
            local pc = Box(sc, 9, { 0.09, 0.07, 0.065, 1 }, { 0.42, 0.34, 0.33, 1 })
            pc:SetSize(92, 62)
            pc.ic = pc:CreateTexture(nil, "OVERLAY"); pc.ic:SetTexture(ns.MEDIA .. (i == 1 and "hb_ui" or "hb_party"))
            pc.ic:SetSize(28, 28); pc.ic:SetPoint("CENTER"); pc.ic:SetVertexColor(C.acc[1], C.acc[2], C.acc[3])
            pc.fs = ns.Font(sc, 11.5, C.tx2); pc.fs:SetPoint("TOP", pc, "BOTTOM", 0, -8)
            sc.pc[i] = pc
        end
        sc.dash = {}
        for i = 1, 40 do
            local d = sc:CreateTexture(nil, "ARTWORK"); d:SetTexture(ns.WHITE); d:SetSize(8, 2)
            d:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.7); sc.dash[i] = d
        end
        -- 토끼 + 편지 (왼쪽 → 오른쪽으로 깡총깡총)
        local cr = CreateFrame("Frame", nil, sc); cr:SetSize(52, 40); cr:SetFrameLevel(sc:GetFrameLevel() + 3)
        local hop = CreateFrame("Frame", nil, cr); hop:SetAllPoints()
        hop.bun = hop:CreateTexture(nil, "ARTWORK"); hop.bun:SetTexture(ns.MEDIA .. "bunny"); hop.bun:SetSize(36, 36); hop.bun:SetPoint("BOTTOMLEFT", 0, 0)
        hop.env = hop:CreateTexture(nil, "OVERLAY"); hop.env:SetTexture(ns.MEDIA .. "mmi_mail"); hop.env:SetSize(24, 24)
        hop.env:SetPoint("BOTTOMLEFT", hop.bun, "BOTTOMRIGHT", -12, -2); hop.env:SetRotation(math.rad(-10))
        local hg = hop:CreateAnimationGroup(); hg:SetLooping("REPEAT")
        local u = hg:CreateAnimation("Translation"); u:SetOffset(0, 6); u:SetDuration(0.22); u:SetOrder(1); u:SetSmoothing("OUT")
        local dn = hg:CreateAnimation("Translation"); dn:SetOffset(0, -6); dn:SetDuration(0.22); dn:SetOrder(2); dn:SetSmoothing("IN")
        local mg = cr:CreateAnimationGroup(); mg:SetLooping("REPEAT")
        local fi = mg:CreateAnimation("Alpha"); fi:SetFromAlpha(0); fi:SetToAlpha(1); fi:SetDuration(0.3); fi:SetOrder(1)
        local mv = mg:CreateAnimation("Translation"); mv:SetDuration(2.6); mv:SetOrder(1)
        local fo = mg:CreateAnimation("Alpha"); fo:SetFromAlpha(1); fo:SetToAlpha(0); fo:SetDuration(0.3); fo:SetStartDelay(2.3); fo:SetOrder(1)
        sc.cr, sc.mv, sc.hg, sc.mg = cr, mv, hg, mg

        -- 단계 카드 3장
        f.cards = { StepCard(1), StepCard(2), StepCard(3) }
        -- 1번(보내기): 담을 것 고르기
        local c1 = f.cards[1]
        c1.ck = {}
        for i, pt in ipairs(PARTS) do
            local r = CreateFrame("Button", nil, c1); r:SetHeight(22)
            r.box = CreateFrame("Frame", nil, r); r.box:SetSize(16, 16); r.box:SetPoint("LEFT", 0, 0)
            r.e = ns.RoundRect(r.box, 5, C.acc, "ARTWORK", 0, 0)
            r.f = ns.RoundRect(r.box, 4, { 0.173, 0.133, 0.125 }, "ARTWORK", 1, 2)
            r.m = r.box:CreateTexture(nil, "OVERLAY"); r.m:SetTexture("Interface\\Buttons\\UI-CheckBox-Check"); r.m:SetSize(20, 20); r.m:SetPoint("CENTER", 1, 0)
            r.ic = r:CreateTexture(nil, "OVERLAY"); r.ic:SetTexture(ns.MEDIA .. pt[3]); r.ic:SetSize(14, 14); r.ic:SetPoint("LEFT", 24, 0)
            r.ic:SetVertexColor(C.accHi[1], C.accHi[2], C.accHi[3])
            r.fs = ns.Font(r, 12.5, C.tx); r.fs:SetPoint("LEFT", 44, 0); r.fs:SetText(pt[2])
            r:SetScript("OnClick", function()
                if type(_G[pt[1]]) ~= "table" then return end
                Pick()[pt[1]] = not Pick()[pt[1]]; S.out = false; S.copied = false; Paint()
            end)
            r:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                ns.TSet(GameTooltip, pt[2], 1, 0.84, 0.88)
                ns.TAdd(GameTooltip, type(_G[pt[1]]) == "table" and pt[4] or "이 컴퓨터엔 설치 안 돼 있어요", 0.84, 0.63, 0.61)
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            c1.ck[i] = r
        end
        -- 2번(보내기): 꺼낸 글자 칸 · 1번(받기): 붙여 넣는 칸
        f.outBox = Edit(f.cards[2])
        f.outBox.eb:SetScript("OnTextChanged", function(self, user)
            if user and f.outText then self:SetText(f.outText); self:HighlightText() end
        end)
        f.outBox.eb:SetScript("OnKeyDown", function(self, key)
            if key == "C" and IsControlKeyDown() and not S.copied then
                C_Timer.After(0.05, function() S.copied = true; Paint() end)
            end
        end)
        f.outBox.eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        -- 붙여 넣기: 긴 글자를 칸에 다 넣으면 게임이 멈춰요 → 글자를 한쪽에 모으고(OnChar) 다음 화면에서 한 번만 읽기
        --   칸에는 앞부분만 보여요 (SetMaxBytes)
        f.inBox = Edit(f.cards[1])
        local ieb = f.inBox.eb
        ieb:SetMaxBytes(200)
        local buf, nb, at = {}, 0, 0
        local function Flush(self)
            self:SetScript("OnUpdate", nil)
            local t = table.concat(buf, "", 1, nb)
            buf, nb = {}, 0
            if #t < 20 then t = self:GetText() or "" end   -- 손으로 친 글자
            if t:gsub("%s", "") == "" then S.pack, S.err = nil, nil
            else S.pack, S.err = ns.ReadProfile(t) end
            self:ClearFocus()
            Paint()
        end
        ieb:SetScript("OnChar", function(self, ch)
            local now = GetTime()
            if at ~= now then buf, nb, at = {}, 0, now; self:SetScript("OnUpdate", Flush) end
            nb = nb + 1; buf[nb] = ch
        end)
        ieb:SetScript("OnTextChanged", function(self, user)
            if (self:GetText() or "") == "" and (S.pack or S.err) then S.pack, S.err = nil, nil; Paint() end
        end)
        -- 2번(받기): 들어 있는 것 줄
        f.has = {}
        for i = 1, #PARTS + 1 do
            local fs = ns.Font(f.cards[2], 12, C.tx); f.has[i] = fs
        end
        f.done = ns.Font(f.cards[3], 12, C.acc)
    end

    local function Layout(w)
        local sc = f.scene
        sc:SetWidth(w)
        local L, R = math.floor(w * 0.2), math.floor(w * 0.8)
        sc.pc[1]:ClearAllPoints(); sc.pc[1]:SetPoint("CENTER", sc, "TOPLEFT", L, -62)
        sc.pc[2]:ClearAllPoints(); sc.pc[2]:SetPoint("CENTER", sc, "TOPLEFT", R, -62)
        local x0, x1 = L + 46 + 14, R - 46 - 14
        local n = 0
        for x = x0, x1 - 8, 16 do
            n = n + 1; local d = sc.dash[n]; if not d then break end
            d:ClearAllPoints(); d:SetPoint("LEFT", sc, "TOPLEFT", x, -62); d:Show()
        end
        for i = n + 1, #sc.dash do sc.dash[i]:Hide() end
        sc.cr:ClearAllPoints(); sc.cr:SetPoint("BOTTOMLEFT", sc, "TOPLEFT", x0 - 6, -60)
        sc.mg:Stop(); sc.mv:SetOffset(math.max(40, x1 - x0 - 40), 0); sc.mg:Play(); sc.hg:Play()

        local cols = w >= 560 and 3 or 1
        local gap = 12
        local cw = cols == 3 and math.floor((w - gap * 2) / 3) or w
        local ch = 214
        for i, c in ipairs(f.cards) do
            c:ClearAllPoints(); c:SetSize(cw, ch)
            if cols == 3 then c:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) * (cw + gap), -(46 + 150 + 14))
            else c:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(46 + 150 + 14) - (i - 1) * (ch + gap)) end
            c.body:SetWidth(cw - 32)
        end
        f.cw = cw
        return 46 + 150 + 14 + (cols == 3 and ch or (ch * 3 + gap * 2)) + 10
    end

    Paint = function()
        if not f then return end
        for i, b in ipairs(f.tab) do
            local on = i == S.tab
            b.bg:SetColor(C.acc, on and 1 or 0)
            local c = on and C.ink or C.tx2
            b.fs:SetTextColor(c[1], c[2], c[3]); b.fs:SetShadowColor(0, 0, 0, on and 0 or 0.85)
        end
        local sc = f.scene
        local c1, c2, c3 = f.cards[1], f.cards[2], f.cards[3]
        for _, c in ipairs(f.cards) do c.btn:Hide(); c.body:Show() end
        for _, r in ipairs(c1.ck) do r:Hide() end
        for _, fs in ipairs(f.has) do fs:Hide() end
        f.outBox:Hide(); f.inBox:Hide(); f.done:Hide()
        if f.keys then f.keys:Hide(); f.keys.ag:Stop() end
        local cw = f.cw or 260

        if S.tab == 1 then
            sc.pc[1].ic:SetTexture(ns.MEDIA .. "hb_ui"); sc.pc[1].fs:SetText("내 컴퓨터")
            sc.pc[2].ic:SetTexture(ns.MEDIA .. "hb_party"); sc.pc[2].fs:SetText("친구 · 노트북 · 부캐")
            local n, all = PickN()
            -- 1. 담을 것 고르기
            c1.title:SetText("담을 것 고르기")
            c1.body:SetText(ns.L("%d개 중 |cfff2b3c2%d개|r"):format(all, n))
            for i, r in ipairs(c1.ck) do
                local key = PARTS[i][1]
                local has = type(_G[key]) == "table"
                local on = has and Pick()[key]
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", c1.body, "BOTTOMLEFT", 0, -8 - (i - 1) * 25); r:SetWidth(cw - 32)
                r.m:SetShown(on and true or false)
                r.e:SetColor(has and C.acc or { 0.4, 0.33, 0.32 }, 1)
                r:SetAlpha(has and 1 or 0.45)
                r:Show()
            end
            -- 2. 글자 복사하기
            c2.title:SetText("글자 복사하기")
            if S.out then
                c2.body:SetText(S.copied and "복사됐어요!" or "글자가 골라졌어요. 이제 이 키만 누르면 끝!")
                f.outBox:ClearAllPoints(); f.outBox:SetPoint("TOPLEFT", c2.body, "BOTTOMLEFT", 0, -12); f.outBox:SetWidth(cw - 32)
                f.outBox:Show()
                -- 키 그림: [Ctrl] + [C] (복사 전엔 콩콩 깜빡)
                local kc = f.keys
                if not kc then
                    kc = CreateFrame("Frame", nil, f.cards[2]); kc:SetSize(120, 26)
                    local function Key(label, w, x)
                        local k = CreateFrame("Frame", nil, kc); k:SetSize(w, 24); k:SetPoint("LEFT", x, 0)
                        ns.RoundPlate(k, 6, { 0.26, 0.2, 0.19, 1 }, { 0.949, 0.702, 0.761, 0.8 })
                        local fs = ns.Font(k, 12, C.accHi); fs:SetPoint("CENTER", 0, 1); fs:SetText(label)
                    end
                    Key("Ctrl", 46, 0)
                    local plus = ns.Font(kc, 13, C.tx2); plus:SetPoint("LEFT", 52, 0); plus:SetText("+")
                    Key("C", 28, 66)
                    local ag = kc:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
                    local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(1); a:SetToAlpha(0.35); a:SetDuration(0.6); a:SetSmoothing("IN_OUT")
                    kc.ag = ag
                    f.keys = kc
                end
                kc:ClearAllPoints(); kc:SetPoint("TOPLEFT", f.outBox, "BOTTOMLEFT", 0, -10)
                kc:SetShown(not S.copied)
                if S.copied then kc.ag:Stop() else kc.ag:Play() end
            else
                c2.body:SetText("[복사하기]를 누르고\nCtrl+C 한 번이면 끝.")
                if f.keys then f.keys:Hide(); f.keys.ag:Stop() end
            end
            c2.btn:SetLabel(S.copied and "다시 복사하기" or "복사하기"); Style(c2.btn, not S.copied)
            c2.btn:SetScript("OnClick", function()
                if n == 0 then ns.Print("담을 것을 하나 이상 골라 주세요.") return end
                f.outText = ns.ExportProfile(Pick())
                S.out, S.copied = true, false
                Paint()
                f.outBox.eb:SetText(f.outText); f.outBox.eb:SetCursorPosition(0)
                f.outBox.eb:SetFocus(); f.outBox.eb:HighlightText()
            end)
            c2.btn:Show()
            -- 3. 보내기
            c3.title:SetText("보내기")
            c3.body:SetText("디스코드 · 카톡 · 메모장에 붙여 넣어서 보내요. 받는 쪽은 |cfff2b3c2'받기'|r 탭에.")
            if S.copied then
                f.done:SetText("복사됐어요! 이제 붙여 넣어 보내요")
                f.done:ClearAllPoints(); f.done:SetPoint("BOTTOMLEFT", c3, "BOTTOMLEFT", 16, 20); f.done:Show()
            end
            CardState(c1, n > 0 and "done" or "now")
            CardState(c2, n == 0 and "" or (S.copied and "done" or "now"))
            CardState(c3, S.copied and "now" or "")
            c1:SetAlpha(1)   -- 고르기는 언제든 바꿀 수 있게 흐리지 않아요
        else
            sc.pc[1].ic:SetTexture(ns.MEDIA .. "hb_party"); sc.pc[1].fs:SetText("친구 · 다른 컴퓨터")
            sc.pc[2].ic:SetTexture(ns.MEDIA .. "hb_ui"); sc.pc[2].fs:SetText("내 컴퓨터")
            -- 1. 붙여 넣기
            c1.title:SetText("붙여 넣기")
            c1.body:SetText("받은 글자를 아래 칸에 |cfff2b3c2Ctrl+V|r")
            f.inBox:ClearAllPoints(); f.inBox:SetPoint("TOPLEFT", c1.body, "BOTTOMLEFT", 0, -12); f.inBox:SetWidth(cw - 32)
            f.inBox:Show()
            c1.btn:SetLabel("지우기"); Style(c1.btn, false)
            c1.btn:SetScript("OnClick", function() f.inBox.eb:SetText(""); f.inBox.eb:SetFocus() end)
            c1.btn:SetShown((f.inBox.eb:GetText() or "") ~= "")
            -- 2. 들어 있는 것
            c2.title:SetText("들어 있는 것")
            if S.pack then
                c2.body:SetText(S.pack.ver and ("v" .. tostring(S.pack.ver) .. " 에서 보낸 설정") or "받은 설정")
                for i, pt in ipairs(PARTS) do
                    local fs = f.has[i]
                    local in_ = type(S.pack[pt[1]]) == "table"
                    fs:SetText(in_ and ("|TInterface\\Buttons\\UI-CheckBox-Check:16:16:0:0|t " .. pt[2]) or ("|cff8f7b76–  " .. pt[2] .. " 없음|r"))
                    fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", c2.body, "BOTTOMLEFT", 0, -10 - (i - 1) * 22); fs:Show()
                end
            elseif S.err then
                c2.body:SetText("|cffff8a8a" .. S.err .. "|r\n글자를 처음부터 끝까지 다 복사했는지 봐 주세요.")
            else
                c2.body:SetText("붙여 넣으면 뭐가 들었는지\n먼저 보여줘요.")
            end
            -- 3. 바꾸기
            c3.title:SetText("바꾸기")
            c3.body:SetText("지금 설정이 받은 설정으로 바뀌고 다시 불러와요. 없는 것은 그대로 둬요.")
            c3.btn:SetLabel("이 설정으로 바꾸기"); Style(c3.btn, S.pack and true or false)
            c3.btn:SetScript("OnClick", function()
                local pack = S.pack
                if not pack then ns.Print("먼저 받은 글자를 붙여 넣어 주세요.") return end
                StaticPopupDialogs["LEELUI_PROFILE_APPLY"] = {
                    text = "지금 설정을 받은 설정으로 바꿀까요?\n바꾸면 다시 불러와요.",
                    button1 = "바꾸기", button2 = "취소",
                    OnAccept = function() ns.ApplyProfile(pack); ReloadUI() end,
                    timeout = 0, whileDead = true, hideOnEscape = true,
                }
                StaticPopup_Show("LEELUI_PROFILE_APPLY")
            end)
            c3.btn:Show()
            CardState(c1, S.pack and "done" or "now")
            CardState(c2, S.pack and "done" or "")
            CardState(c3, S.pack and "now" or "")
        end
    end

    function ns.HubSharePane(pane, x, y, w)
        if not f then Build(pane) end
        f:SetParent(pane)
        f:ClearAllPoints(); f:SetPoint("TOPLEFT", pane, "TOPLEFT", x, y)
        local h = Layout(w)
        f:SetSize(w, h)
        f:Show()
        Paint()
        return h
    end
    function ns.HubShareHide()
        if f then f:Hide(); f.scene.mg:Stop(); f.scene.hg:Stop() end
    end
    function ns.HubShareTab(i) S.tab = i; Paint() end
end

SLASH_LEELPROFILE1 = "/르엘설정"
SlashCmdList.LEELPROFILE = function(msg)
    if (msg or ""):find("가져") then ns:ShowProfileImport() else ns:ShowProfileExport() end
end

----------------------------------------------------------------------
-- 퀘스티 르엘 추천 설정: 지도 · 미니맵엔 받을 퀘 "!" + 진행 목표(잡을 몹 · 드랍 아이템) (반납 아이콘만 끄기)
--   퀘스티 추적기 · 이름표 표시는 끄기 (르엘 UI 것을 써요)
--   내가 눌러야만 바뀌어요. 처음 한 번만 물어봐요 (ns.db.questiePresetAsked)
----------------------------------------------------------------------
local QP = {
    enabled = true, enableMapIcons = true, enableMiniMapIcons = true,
    enableAvailable = true, enableObjectives = true, enableTurnins = false,
    trackerEnabled = false, nameplateEnabled = false,
}
local function QProfile()
    local Q = _G.Questie
    return Q and Q.db and Q.db.profile
end
function ns.QuestieIsPreset()
    local p = QProfile()
    if not p then return false end
    for k, v in pairs(QP) do if (p[k] ~= false) ~= v then return false end end
    return true
end
function ns.QuestiePresetApply()
    local p = QProfile()
    if not p then ns.Print("퀘스티가 없거나 아직 켜지는 중이에요.") return end
    for k, v in pairs(QP) do p[k] = v end
    ReloadUI()
end
StaticPopupDialogs["LEELUI_QUESTIE_PRESET"] = {
    text = "퀘스티를 르엘 추천대로 맞출까요?\n\n지도 · 미니맵엔 받을 퀘 |cfffac74d!|r 와 진행 목표(잡을 몹 · 드랍 아이템)가 보이고\n반납 아이콘, 퀘스티 추적기 · 이름표 표시는 꺼져요.\n\n바꾸면 다시 불러와요. (나중에 /questie 에서 언제든 되돌릴 수 있어요)",
    button1 = "맞추기", button2 = "그대로",
    OnAccept = function() if ns.db then ns.db.questiePresetAsked = true end; ns.QuestiePresetApply() end,
    OnCancel = function() if ns.db then ns.db.questiePresetAsked = true end end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}
function ns.QuestiePresetAsk()
    if not QProfile() then ns.Print("퀘스티가 없거나 아직 켜지는 중이에요.") return end
    if ns.QuestieIsPreset() then ns.Print("퀘스티가 이미 르엘 추천 설정이에요.") return end
    StaticPopup_Show("LEELUI_QUESTIE_PRESET")
end
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        C_Timer.After(10, function()
            if not ns.db or ns.db.questiePresetAsked then return end
            if not QProfile() or ns.QuestieIsPreset() then return end
            if InCombatLockdown() then return end
            StaticPopup_Show("LEELUI_QUESTIE_PRESET")
        end)
    end)
end

----------------------------------------------------------------------
-- 게임 메뉴(ESC)에 "르엘 UI" 단추 (D안): 게임 단추 모양 그대로 · "블리자드 샵" 아래
--   마우스를 올리면 분홍빛으로 물들어요 · 안 본 새 소식이 있으면 토끼가 편지를 들고 깡총
--   누르면 메뉴가 닫히고 르엘 허브가 열려요
----------------------------------------------------------------------
do
    local LABEL = "|T" .. ns.MEDIA .. "bunny:14:14:0:0|t  르엘 UI"
    local function Open()
        if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
        local hasNew = ns.HubNewsCount and ns.HubNewsCount() > 0
        C_Timer.After(0, function() if ns.ToggleHub then if hasNew then ns:ToggleHub("_news") else ns:ToggleHub() end end end)
    end
    -- 꾸미기: 분홍 물들기 + 편지 든 토끼
    local function Deco(b)
        if not b or b.leelDeco then return end
        b.leelDeco = true
        local t = b:CreateTexture(nil, "OVERLAY")
        t:SetTexture(ns.WHITE); t:SetBlendMode("ADD")
        t:SetPoint("TOPLEFT", 4, -4); t:SetPoint("BOTTOMRIGHT", -4, 4)
        t:SetVertexColor(0.95, 0.45, 0.62, 0.32); t:Hide()
        b.leelTint = t
        b:HookScript("OnEnter", function(self) if self.leelMine then self.leelTint:Show() end end)
        b:HookScript("OnLeave", function(self) self.leelTint:Hide() end)
        -- NEW: 토끼가 편지를 들고 깡총 (글 속 토끼는 숨기고 그 자리에 움직이는 토끼)
        local hop = CreateFrame("Frame", nil, b)
        hop:SetSize(14, 14); hop:SetFrameLevel(b:GetFrameLevel() + 5)
        hop.bun = hop:CreateTexture(nil, "ARTWORK"); hop.bun:SetTexture(ns.MEDIA .. "bunny"); hop.bun:SetAllPoints()
        hop.env = hop:CreateTexture(nil, "OVERLAY"); hop.env:SetTexture(ns.MEDIA .. "mmi_mail")
        hop.env:SetSize(14, 14); hop.env:SetPoint("CENTER", hop, "TOPLEFT", -2, 1)
        hop.dot = hop:CreateTexture(nil, "OVERLAY", nil, 2); hop.dot:SetTexture(ns.MEDIA .. "circle")
        hop.dot:SetSize(5, 5); hop.dot:SetPoint("CENTER", hop.env, "TOPRIGHT", -1, -2); hop.dot:SetVertexColor(1, 0.3, 0.48)
        hop.glow = hop:CreateTexture(nil, "BACKGROUND"); hop.glow:SetTexture(ns.MEDIA .. "soft_glow"); hop.glow:SetBlendMode("ADD")
        hop.glow:SetSize(34, 34); hop.glow:SetPoint("CENTER", hop.env, "CENTER"); hop.glow:SetVertexColor(1, 0.8, 0.4, 0.45)
        -- 깡총: 위로 3 · 아래로 3 · 쉬기
        local ag = hop:CreateAnimationGroup(); ag:SetLooping("REPEAT")
        local up = ag:CreateAnimation("Translation"); up:SetOffset(0, 3); up:SetDuration(0.18); up:SetOrder(1); up:SetSmoothing("OUT")
        local dn = ag:CreateAnimation("Translation"); dn:SetOffset(0, -3); dn:SetDuration(0.18); dn:SetOrder(2); dn:SetSmoothing("IN")
        local rest = ag:CreateAnimation("Alpha"); rest:SetFromAlpha(1); rest:SetToAlpha(1); rest:SetDuration(0.85); rest:SetOrder(3)
        hop.ag = ag
        -- 편지 살랑
        local eg = hop.env:CreateAnimationGroup(); eg:SetLooping("BOUNCE")
        local ro = eg:CreateAnimation("Rotation"); ro:SetDegrees(-22); ro:SetDuration(0.6); ro:SetSmoothing("IN_OUT")
        hop.env:SetRotation(math.rad(11))
        hop.eg = eg
        hop:Hide()
        b.leelNew = hop
        b:HookScript("OnShow", function(self) if ns.GMLeelPaint then ns.GMLeelPaint(self) end end)
    end
    local LABEL_NEW = "|T" .. ns.MEDIA .. "bunny:14:14:0:0:64:64:0:1:0:1|t  르엘 UI"   -- 같은 자리, 투명한 1픽셀
    local function Paint(b)
        if not (b and b.leelNew) then return end
        local hop = b.leelNew
        if b.leelTint then b.leelTint:Hide() end
        if not b.leelMine then hop:Hide(); hop.ag:Stop(); hop.eg:Stop(); return end
        local n = ns.HubNewsCount and ns.HubNewsCount() or 0
        if n > 0 then
            b:SetText(LABEL_NEW)
            local fs = b:GetFontString()
            hop:ClearAllPoints()
            if fs then hop:SetPoint("LEFT", fs, "LEFT", 0, 0) else hop:SetPoint("LEFT", b, "CENTER", -34, 0) end
            hop:Show(); hop.ag:Play(); hop.eg:Play()
        else
            b:SetText(LABEL)
            hop:Hide(); hop.ag:Stop(); hop.eg:Stop()
        end
    end
    ns.GMLeelPaint = Paint

    local GM = _G.GameMenuFrame
    if GM and GM.InitButtons and GM.AddButton then
        -- 새 게임 메뉴 (단추를 그때그때 만드는 방식)
        hooksecurefunc(GM, "InitButtons", function(self)
            -- 단추 통은 다시 쓰여서, 예전에 꾸민 단추가 다른 단추가 됐을 수 있어요 → 꾸밈 끄기
            if self.buttonPool then
                for other in self.buttonPool:EnumerateActive() do
                    if other.leelDeco then other.leelMine = nil; Paint(other) end
                end
            end
            local ok, b = pcall(self.AddButton, self, LABEL, Open)
            if not ok or not b then return end
            b.leelMine = true
            -- "블리자드 샵" 바로 아래로 (없으면 맨 위 묶음 끝)
            local after
            if self.buttonPool then
                for other in self.buttonPool:EnumerateActive() do
                    local tx = other.GetText and other:GetText()
                    if other ~= b and (tx == (BLIZZARD_STORE or "") or (tx and tx:find("샵"))) then after = other end
                end
            end
            if after and after.layoutIndex then b.layoutIndex = after.layoutIndex + 0.5; if self.MarkDirty then self:MarkDirty() end end
            Deco(b); Paint(b)
        end)
    elseif GM then
        -- 옛 게임 메뉴 (단추가 정해져 있는 방식): 애드온 단추 위에 끼워 넣기
        local b = CreateFrame("Button", "GameMenuButtonLeelUI", GM, "GameMenuButtonTemplate")
        b:SetText(LABEL)
        b.leelMine = true
        b:SetScript("OnClick", function() PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION or 852); Open() end)
        local function Place()
            local addons = _G.GameMenuButtonAddons or _G.GameMenuButtonUIOptions
            if not addons then return end
            if InCombatLockdown() then return end
            local p1, rel, p2, x, y = addons:GetPoint(1)
            if rel ~= b then
                b:ClearAllPoints(); b:SetPoint(p1 or "TOP", rel, p2 or "BOTTOM", x or 0, y or -1)
                addons:ClearAllPoints(); addons:SetPoint("TOP", b, "BOTTOM", 0, -1)
            end
            if not b.leelGrown then GM:SetHeight(GM:GetHeight() + b:GetHeight() + 2); b.leelGrown = true end
        end
        if GameMenuFrame_UpdateVisibleButtons then
            hooksecurefunc("GameMenuFrame_UpdateVisibleButtons", function() b.leelGrown = nil; Place() end)
        end
        GM:HookScript("OnShow", function() Place(); Paint(b) end)
        Deco(b)
    end
end
