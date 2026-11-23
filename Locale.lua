-- LeelUI / Locale.lua
-- 언어: 자동(게임 언어) · 한국어 · English
--  * 코드에는 한국어를 그대로 두고, 영어일 때 화면에 그리는 순간 바꿔요
--    - ns.Font 로 만든 글자 (허브 · 판 · 이름 등): SetText / SetFormattedText 때 저절로
--    - 채팅 알림 (ns.Print) · 툴팁은 ns.L(...) 로
--  * 번역은 ns.EN (정확히 같은 문장) · ns.EN_PAT (패턴) · ns.EN_FRAG (문장 속 조각)
--  * 번역이 없는 문장은 한국어 그대로 보여요

local _, ns = ...

ns.EN = ns.EN or {}
ns.EN_PAT = ns.EN_PAT or {}
ns.EN_FRAG = ns.EN_FRAG or {}

local function GameKo()
    local ok, l = pcall(GetLocale)
    return ok and l == "koKR"
end

-- 지금 언어: "ko" 또는 "en"
function ns.LANG()
    local v = ns.db and ns.db.lang
    if v == "ko" or v == "en" then return v end
    return GameKo() and "ko" or "en"
end
local function EnOn() return ns.LANG() == "en" end
ns.EnOn = EnOn

local HANGUL = "[\234-\237][\128-\191][\128-\191]"
local fragSorted
local function Frags()
    if fragSorted then return fragSorted end
    fragSorted = {}
    for k, v in pairs(ns.EN_FRAG) do fragSorted[#fragSorted + 1] = { k, v } end
    table.sort(fragSorted, function(a, b) return #a[1] > #b[1] end)
    return fragSorted
end

-- 한 마디: 색 코드를 떼고 정확히 · 패턴 순서로 찾아봐요
local function Seg(seg)
    if not seg:find(HANGUL) then return seg end
    local pre, body, post = seg:match("^(|c%x%x%x%x%x%x%x%x)(.-)(|r)$")
    if not pre then pre, body = seg:match("^(|c%x%x%x%x%x%x%x%x)(.+)$") end
    if not pre then body, post = seg:match("^(.-)(|r)$") end
    body = body or seg
    local e = ns.EN[body]
    if not e then
        for _, p in ipairs(ns.EN_PAT) do
            local r, n = body:gsub(p[1], p[2])
            if n > 0 then e = r; break end
        end
    end
    if not e then return seg end
    return (pre or "") .. e .. (post or "")
end

local function Tr(s)
    if type(s) ~= "string" or s == "" then return s end
    if issecretvalue and issecretvalue(s) then return s end
    if not s:find(HANGUL) then return s end
    local e = ns.EN[s]
    if e then return e end
    local out = s
    for _, p in ipairs(ns.EN_PAT) do
        local r, n = s:gsub(p[1], p[2])
        if n > 0 then out = r; break end
    end
    if not out:find(HANGUL) then return out end
    -- 긴 문장 속 아는 조각만 바꿔요 (" · 사거리 밖" 같은 것)
    for _, f in ipairs(Frags()) do
        if out:find(f[1], 1, true) then
            out = out:gsub(f[1]:gsub("[%%%^%$%(%)%.%[%]%*%+%-%?]", "%%%0"), (f[2]:gsub("%%", "%%%%")))
        end
    end
    -- " · " 로 이은 문장은 마디마다 다시 찾아봐요
    if out:find(HANGUL) and out:find(" · ", 1, true) then
        local parts, pos = {}, 1
        while true do
            local i, j = out:find(" · ", pos, true)
            local seg = out:sub(pos, (i or 0) - 1)
            parts[#parts + 1] = Seg(seg)
            if not i then break end
            pos = j + 1
        end
        out = table.concat(parts, " · ")
    end
    return out
end

-- 화면에 쓸 글: 영어면 번역 · 아니면 그대로
function ns.L(s)
    if not EnOn() then return s end
    local ok, r = pcall(Tr, s)
    return ok and r or s
end

-- 툴팁 줄 (GameTooltip:AddLine 대신)
function ns.TAdd(t, s, ...) return t:AddLine(ns.L(s), ...) end
function ns.TSet(t, s, ...) return t:SetText(ns.L(s), ...) end
function ns.TDbl(t, a, b, ...) return t:AddDoubleLine(ns.L(a), ns.L(b), ...) end

-- ns.Font 로 만든 글자는 저절로 번역
local function Wrap(fs)
    if not fs or fs.leelL then return fs end
    fs.leelL = true
    local st, sft = fs.SetText, fs.SetFormattedText
    fs.SetText = function(self, t, ...)
        if type(t) == "string" and EnOn() then t = ns.L(t) end
        return st(self, t, ...)
    end
    fs.SetFormattedText = function(self, f, ...)
        if type(f) == "string" and EnOn() then f = ns.L(f) end
        return sft(self, f, ...)
    end
    return fs
end
ns.LWrap = Wrap
if ns.Font then
    local F = ns.Font
    ns.Font = function(...) return Wrap(F(...)) end
end

-- 채팅 알림
if ns.Print then
    local Pr = ns.Print
    ns.Print = function(msg) return Pr(ns.L(msg)) end
end

-- /leel lang en · ko · auto
local lev = CreateFrame("Frame")
lev:RegisterEvent("PLAYER_LOGIN")
lev:SetScript("OnEvent", function()
    local orig = SlashCmdList and SlashCmdList.LEELUI
    if orig then
        SlashCmdList.LEELUI = function(msg)
            local a = (msg or ""):lower():match("^lang%s*(%a*)")
            if a then
                if a == "en" or a == "english" then ns.db.lang = "en"
                elseif a == "ko" or a == "kr" or a == "korean" then ns.db.lang = "ko"
                else ns.db.lang = "auto" end
                DEFAULT_CHAT_FRAME:AddMessage("|cffffd21f[LeelUI]|r Language: " .. (ns.db.lang == "auto" and ("auto (" .. ns.LANG() .. ")") or ns.db.lang) .. " · /reload to apply")
                if StaticPopup_Show then StaticPopup_Show("LEELUI_HUB_RELOAD") end
                return
            end
            return orig(msg)
        end
    end
    -- 영어로 처음 켜면 한 줄 안내
    if ns.db and EnOn() and not ns.db.langNoticed then
        ns.db.langNoticed = true
        C_Timer.After(6, function()
            DEFAULT_CHAT_FRAME:AddMessage("|cffffd21f[LeelUI]|r LeelUI is shown in English. Type |cffffffff/leel lang ko|r for Korean (한국어).")
        end)
    end
end)
