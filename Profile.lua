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
