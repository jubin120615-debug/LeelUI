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

-- base64
local B = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function Enc(data)
    return ((data:gsub(".", function(x)
        local r, b = "", x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0") end
        return r
    end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
        if #x < 6 then return "" end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
        return B:sub(c + 1, c + 1)
    end) .. ({ "", "==", "=" })[#data % 3 + 1])
end
local function Dec(data)
    data = data:gsub("[^" .. B .. "=]", "")
    return (data:gsub(".", function(x)
        if x == "=" then return "" end
        local r, f = "", (B:find(x, 1, true) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0") end
        return r
    end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
        if #x ~= 8 then return "" end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0) end
        return string.char(c)
    end))
end

function ns.ExportProfile()
    local pack = {}
    for _, n in ipairs(DBS) do
        if type(_G[n]) == "table" then pack[n] = _G[n] end
    end
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
    if not ok or type(pack) ~= "table" or type(pack.LeelUIDB) ~= "table" then
        return nil, "읽을 수 없는 설정이에요."
    end
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
