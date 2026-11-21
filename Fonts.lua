-- LeelUI / Fonts.lua
-- 르엘 글씨체: 게임 글씨를 르엘 톤 글꼴로 (기본 글씨 / 이름·제목 / 채팅 / 숫자 따로)
-- 글꼴은 모두 SIL OFL (무료 배포 가능): media/fonts/OFL-fonts.txt

local ADDON, ns = ...

local DIR = "Interface\\AddOns\\" .. ADDON .. "\\media\\fonts\\"

ns.FONT_LIST = {
    { key = "wow",     label = "와우 기본" },
    { key = "gowun",   label = "고운돋움", file = DIR .. "GowunDodum.ttf" },
    { key = "jua",     label = "주아",     file = DIR .. "Jua.ttf" },
    { key = "nanum",   label = "나눔고딕", file = DIR .. "NanumGothic.ttf" },
    { key = "dohyeon", label = "도현",     file = DIR .. "DoHyeon.ttf" },
    { key = "gaegu",   label = "개구",     file = DIR .. "Gaegu.ttf" },
    { key = "dongle",  label = "동글",     file = DIR .. "Dongle.ttf" },
    { key = "gamja",   label = "감자꽃",   file = DIR .. "GamjaFlower.ttf" },
    { key = "barlow",  label = "Barlow (숫자)", file = ns.NUM, numOnly = true },
}
-- 내 글꼴: LeelUI\MyFonts 폴더 + MyFonts\list.lua (직접 적어 넣기)
local MYDIR = "Interface\\AddOns\\" .. ADDON .. "\\MyFonts\\"
for _, e in ipairs(_G.LeelUI_MyFonts or {}) do
    local file, label
    if type(e) == "string" then file = e elseif type(e) == "table" then file, label = e[1] or e.file, e[2] or e.label end
    if type(file) == "string" and file ~= "" then
        if not file:lower():find("%.[ot]tf$") then file = file .. ".ttf" end
        label = label or file:gsub("%.[^.]+$", "")
        table.insert(ns.FONT_LIST, #ns.FONT_LIST, { key = "my_" .. file:lower(), label = label, file = MYDIR .. file, mine = true })
    end
end

local BY = {}
for _, f in ipairs(ns.FONT_LIST) do BY[f.key] = f end

ns.FONT_SIZES = {
    { key = 0.9, label = "90%" }, { key = 1.0, label = "100%" },
    { key = 1.1, label = "110%" }, { key = 1.2, label = "120%" }, { key = 1.3, label = "130%" },
}

-- nameK = 이름/제목 크기 · outline = 이름 테두리 (none / thin / thick) — 기본은 지금 그대로
local DEF = { body = "wow", name = "wow", chat = "wow", num = "wow", size = 1.0, nameK = 1.0, outline = "none" }

local function DB()
    ns.db.font = ns.db.font or {}
    local d = ns.db.font
    for k, v in pairs(DEF) do if d[k] == nil then d[k] = v end end
    return d
end

local function FileFor(slot)
    local f = BY[DB()[slot]]
    if not f or not f.file then return nil end
    if f.numOnly and slot ~= "num" then return nil end
    return f.file
end
ns.FontFileFor = FileFor

----------------------------------------------------------------------
-- 게임 글꼴 묶음 나누기
----------------------------------------------------------------------
local orig = {}      -- 처음 값 { file, size, flags }
local origChat = {}

local function Group(name)
    if name:find("^ChatFont") or name == "ChatBubbleFont" then return "chat" end
    if name:find("^Number") or name:find("Damage") then return "num" end
    if name:find("NamePlate") or name:find("UnitName") then return "name" end
    return "body"
end

local function IsTextFont(file)
    if type(file) ~= "string" then return false end
    local f = file:lower()
    -- 한글/기본 글꼴만 바꿈 (기호·특수 글꼴은 그대로)
    return f:find("2002") or f:find("k_pagetext") or f:find("frizqt") or f:find("arialn")
        or f:find("k_damage")
end

local function FontNames()
    if GetFonts then
        local ok, list = pcall(GetFonts)
        if ok and type(list) == "table" then return list end
    end
    return {}
end

local function Capture()
    for _, name in ipairs(FontNames()) do
        local obj = _G[name]
        if obj and obj.GetFont and not orig[name] then
            local ok, file, size, flags = pcall(obj.GetFont, obj)
            if ok and file and size then orig[name] = { file, size, flags } end
        end
    end
end

local function ApplyObjects()
    local d = DB()
    Capture()
    for name, o in pairs(orig) do
        local obj = _G[name]
        if obj and IsTextFont(o[1]) then
            local g = Group(name)
            local file = FileFor(g)
            local mult = (g == "body" or g == "chat") and (d.size or 1) or (g == "name" and (d.nameK or 1)) or 1
            local fl = o[3]
            if g == "name" and d.outline and d.outline ~= "none" then
                local base = (fl or ""):gsub("THICKOUTLINE", ""):gsub("OUTLINE", ""):gsub("^,+", ""):gsub(",+$", "")
                local add = d.outline == "thick" and "THICKOUTLINE" or "OUTLINE"
                fl = (base ~= "" and (base .. "," .. add)) or add
            end
            pcall(obj.SetFont, obj, file or o[1], o[2] * mult, fl)
        end
    end
    -- 채팅창은 창마다 따로 글꼴을 들고 있음
    local cf = FileFor("chat")
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame" .. i]
        if f and f.GetFont then
            if not origChat[i] then
                local ok, file, size, flags = pcall(f.GetFont, f)
                if ok and file then origChat[i] = { file, size, flags } end
            end
            local o = origChat[i]
            if o then
                local _, cur = f:GetFont()
                pcall(f.SetFont, f, cf or o[1], cur or o[2], o[3])
            end
        end
    end
end

-- 르엘 UI 자기 글씨: 만들 때 기록해 두고, 글꼴을 바꾸면 바로 다시 칠함
local DEFAULT_UI = ns.FONT
ns.uiTexts = setmetatable({}, { __mode = "k" })
function ns.TrackText(fs, size, flags)
    if fs then ns.uiTexts[fs] = { size, flags or "" } end
end

local function UIFontFile()
    return FileFor("name") or FileFor("body") or DEFAULT_UI
end

local function RefreshUI()
    local file = UIFontFile()
    if ns.FONT == file then return end
    ns.FONT = file
    for fs, v in pairs(ns.uiTexts) do
        local _, cur, fl = fs:GetFont()
        pcall(fs.SetFont, fs, file, cur or v[1], fl or v[2])
    end
end

-- 게임이 세계에 들어가기 전에만 바뀌는 것 (머리 위 이름, 피해 숫자)
local function ApplyGlobals()
    local name, num, body = FileFor("name"), FileFor("num"), FileFor("body")
    if body then STANDARD_TEXT_FONT = body end
    if name then UNIT_NAME_FONT = name; NAMEPLATE_FONT = name end
    if num then DAMAGE_TEXT_FONT = num end
    -- 르엘 UI 자기 글씨(이름표, HUD, 창 제목)는 이름/제목 글꼴
    ns.FONT = UIFontFile()
end

function ns:ApplyFonts()
    ApplyObjects()
end

-- 허브에서 바꿀 때
function ns:SetFontSlot(slot, value)
    DB()[slot] = value
    ApplyObjects()
    RefreshUI()
end

-- 허브 세부 설정 (이름 크기 · 이름 테두리 · 피해 숫자 크기)
function ns.FontOpt(k)
    if k == "dmg" then
        local ok, v = pcall(GetCVar, "WorldTextScale")
        return math.floor(((ok and tonumber(v)) or 1) * 100 + 0.5)
    end
    return DB()[k]
end
function ns.SetFontOpt(k, v)
    if k == "dmg" then pcall(SetCVar, "WorldTextScale", (tonumber(v) or 100) / 100) return end
    DB()[k] = v
    ApplyObjects()
end
-- 미리 보기용: 그 묶음의 지금 글꼴 (와우 기본이면 게임 원래 글꼴)
function ns.FontPreviewFile(slot)
    local f = FileFor(slot)
    if f then return f end
    Capture()
    local want = { body = "GameFontNormal", name = "SystemFont_NamePlate", chat = "ChatFontNormal", num = "NumberFontNormal" }
    local o = orig[want[slot] or ""]
    if o and o[1] then return o[1] end
    for name, o2 in pairs(orig) do if Group(name) == slot and IsTextFont(o2[1]) then return o2[1] end end
    return STANDARD_TEXT_FONT
end
function ns:SetFontReset()
    local d = DB()
    d.body, d.chat, d.name, d.num, d.size, d.nameK, d.outline = "wow", "wow", "wow", "wow", 1.0, 1.0, "none"
    ApplyObjects()
    RefreshUI()
end

function ns:SetFontPreset()
    local d = DB()
    d.body, d.chat, d.name = "gowun", "gowun", "jua"
    ApplyObjects()
    RefreshUI()
end

----------------------------------------------------------------------
-- 이벤트: Core 다음에 등록돼서 ns.db 가 이미 있음
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        if ns.db then DB(); ApplyGlobals() end
    elseif event == "PLAYER_LOGIN" then
        if not ns.db then return end
        ApplyObjects()
        -- 다른 애드온이 늦게 글꼴을 다시 칠하는 경우가 있어 한 번 더
        C_Timer.After(2, ApplyObjects)
    end
end)
