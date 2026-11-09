-- Leel Mark / Core.lua
-- 파티 징 찍기 (A안: 가로 알약 바)
--   [토끼] [해골][X][네모][달][세모][다이아][동그라미][별] [자동] [지우기]
--   · 징 단추: 지금 대상에 그 징 (한 번 더 누르면 지움 = 게임 기본 동작)
--   · 자동: 보이는 적 이름표에 우선순위대로 빈 징 채우기
--   · 마우스 단축키: 몹에 마우스를 올리고 단축키 → 누를 때마다 해골 → X → 네모 …
--   · 지우기: 모든 징 지우기
-- 포에버(12.x)에서는 애드온이 징 찍기(SetRaidTarget)를 직접 못 함 → 블리자드 보안 단추(raidtarget·매크로)로 찍음
--   (자동은 전투 밖에서만 미리 매크로를 만들어 둘 수 있음)
-- 징 번호: 1 별, 2 동그라미, 3 다이아, 4 세모, 5 달, 6 네모, 7 X, 8 해골

local ADDON = ...
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"
local FONT = STANDARD_TEXT_FONT or "Fonts\\2002.TTF"
-- 르엘 UI 글씨체를 따라감 (허브에서 바꾸면 바로 바뀜)
local function LeelFont(fs, size, flags)
    local L = _G.LeelUI
    local ok = fs:SetFont((L and L.FONT) or FONT, size, flags or "")
    if L and L.TrackText then L.TrackText(fs, size, flags or "") end
    return ok
end

local C = {
    acc = { 0.949, 0.702, 0.761 }, ink = { 0.227, 0.11, 0.141 },
    tx = { 0.965, 0.925, 0.91 }, tx2 = { 0.81, 0.635, 0.616 },
    plate = { 0.125, 0.094, 0.086, 0.96 }, btn = { 0.18, 0.137, 0.129, 1 },
}
local MARK_NAME = { "별", "동그라미", "다이아", "세모", "달", "네모", "X", "해골" }
local BAR_ORDER = { 8, 7, 6, 5, 4, 3, 2, 1 }

local defaults = { pos = nil, show = "group", announce = false, scale = 1 }
local db

local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cfff2b3c2[Leel Mark]|r " .. msg) end

----------------------------------------------------------------------
-- 징 읽기·찍기 (숨겨진 값이어도 에러 없이)
----------------------------------------------------------------------
local function GetMark(unit)
    local ok, idx = pcall(function()
        local i = GetRaidTargetIndex(unit)
        if i and i > 0 then return i end
    end)
    return ok and idx or nil
end

local ns_warned = false
local function SetMark(unit, idx)
    local ok, err = pcall(SetRaidTarget, unit, idx)
    if not ok and not ns_warned then
        ns_warned = true
        Print("징을 찍을 수 없어요: " .. tostring(err))
    end
    return ok
end

local function Try(fn, ...)
    local ok, r = pcall(fn, ...)
    if not ok then return false end
    local ok2, b = pcall(function() return r and true or false end)
    return ok2 and b or false
end

local function CanMark()
    if IsInRaid() then
        return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
    end
    return true
end

----------------------------------------------------------------------
-- 역할 징: 파티에 그 직업이 있을 때만 (사냥꾼 네모=얼음 덫, 마법사 달=변이, 도적 별=혼절)
----------------------------------------------------------------------
local function GroupClasses()
    local has, who = {}, {}
    local function add(u)
        local ok, _, file = pcall(UnitClass, u)
        if ok and type(file) == "string" then
            has[file] = true
            who[file] = who[file] or UnitName(u)
        end
    end
    add("player")
    for i = 1, GetNumSubgroupMembers() do add("party" .. i) end
    return has, who
end

local function AutoOrder()
    local has, who = GroupClasses()
    local order, roles = { 8, 7 }, {}
    if has.HUNTER then order[#order + 1] = 6; roles[6] = (who.HUNTER or "사냥꾼") .. " 덫" end
    if has.MAGE then order[#order + 1] = 5; roles[5] = (who.MAGE or "마법사") .. " 변이" end
    if has.ROGUE then order[#order + 1] = 1; roles[1] = (who.ROGUE or "도적") .. " 혼절" end
    for _, i in ipairs({ 4, 3, 2, 6, 5, 1 }) do
        local dup = false
        for _, o in ipairs(order) do if o == i then dup = true end end
        if not dup then order[#order + 1] = i end
    end
    return order, roles
end

----------------------------------------------------------------------
-- 자동: 보이는 적 이름표 → 점수순 → 빈 징 채우기
----------------------------------------------------------------------
local function Score(u)
    local s = 0
    if Try(function() return UnitCastingInfo(u) or UnitChannelInfo(u) end) then s = s + 100 end   -- 시전 중
    if Try(function() local c = UnitClassification(u); return c == "elite" or c == "rareelite" or c == "worldboss" end) then s = s + 50 end
    if Try(function() return UnitPowerType(u) == 0 end) then s = s + 20 end   -- 마나 쓰는 몹(주문형·치유형)
    local okh, hm = pcall(function() return UnitHealthMax(u) / 1000 end)
    if okh and type(hm) == "number" then s = s + math.min(hm, 19) end
    return s
end

local function Candidates()
    local list, used = {}, {}
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local u = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if u and Try(UnitCanAttack, "player", u) and not Try(UnitIsDead, u) then
            local m = GetMark(u)
            if m then
                used[m] = true
            elseif not Try(UnitIsTapDenied, u) then
                list[#list + 1] = { unit = u, score = Score(u) }
            end
        end
    end
    local tm = GetMark("target")
    if tm then used[tm] = true end
    table.sort(list, function(a, b) return a.score > b.score end)
    return list, used
end

local function Announce(text)
    if not db.announce or not IsInGroup() then return end
    local ch = IsInRaid() and "RAID" or "PARTY"
    pcall(SendChatMessage, "[Leel Mark] " .. text, ch)
end

-- 자동: 전투 밖에서 누르는 순간(PreClick) 우선순위를 계산해 "/tm [@nameplateN] ~징" 매크로를 만들어 둠
local function BuildAutoMacro()
    local list, used = Candidates()
    if #list == 0 then return nil, "징을 찍을 적이 안 보여요. (적 이름표가 켜져 있어야 해요)" end
    local order, roles = AutoOrder()
    local lines, oi, got = {}, 1, {}
    for _, c in ipairs(list) do
        while order[oi] and used[order[oi]] do oi = oi + 1 end
        local m = order[oi]
        if not m then break end
        lines[#lines + 1] = ("/tm [@%s] ~%d"):format(c.unit, m)
        got[m] = true
        oi = oi + 1
    end
    local parts = {}
    if got[8] then parts[#parts + 1] = "해골 먼저" end
    if got[7] then parts[#parts + 1] = "X 다음" end
    for m, r in pairs(roles) do if got[m] then parts[#parts + 1] = MARK_NAME[m] .. "는 " .. r end end
    return table.concat(lines, "\n"), table.concat(parts, " · ")
end

----------------------------------------------------------------------
-- 바 (르엘 UI: 어두운 알약 + 분홍 테)
----------------------------------------------------------------------
local bar
local ResetSweep

local function Slice(t, m) pcall(t.SetTextureSliceMargins, t, m, m, m, m) end

local function PillTex(parent, file, m, c, a, layer, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetTexture(MEDIA .. file)
    Slice(t, m)
    t:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1)
    return t
end

local function Tip(b, title, line)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(title, 1, 1, 1)
        if line then GameTooltip:AddLine(line, C.tx2[1], C.tx2[2], C.tx2[3], true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function MarkButton(parent, idx)
    local b = CreateFrame("Button", "LeelMarkBtn" .. idx, parent, "SecureActionButtonTemplate")
    b:SetSize(30, 30)
    b:SetAttribute("type", "raidtarget")
    b:SetAttribute("unit", "target")
    b:SetAttribute("marker", idx)
    b:SetAttribute("action1", "toggle")
    b:SetAttribute("action2", "clear")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(MEDIA .. "circle"); bg:SetAllPoints()
    bg:SetVertexColor(C.btn[1], C.btn[2], C.btn[3], 1)
    local ring = b:CreateTexture(nil, "BORDER")
    ring:SetTexture(MEDIA .. "ring"); ring:SetAllPoints()
    ring:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.35)
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    SetRaidTargetIconTexture(ic, idx)
    ic:SetSize(19, 19); ic:SetPoint("CENTER")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("useOnKeyDown", false)
    Tip(b, MARK_NAME[idx], "왼쪽 클릭: 대상에 찍기 · 오른쪽 클릭: 대상 징 지우기")
    b:HookScript("OnEnter", function() ring:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1) end)
    b:HookScript("OnLeave", function() ring:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.35) end)
    return b
end

local function PillButton(parent, name, label, icon, filled, tipTitle, tipLine)
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("useOnKeyDown", false)   -- 마우스·단축키 모두 손을 뗄 때 한 번만
    b:SetHeight(28)
    local bg = PillTex(b, "pill22", 11, filled and C.acc or C.btn, 1)
    bg:SetAllPoints()
    if not filled then
        local rim = PillTex(b, "pill22rim", 11, C.acc, 0.45, "BORDER")
        rim:SetAllPoints()
    end
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetTexture(MEDIA .. icon); ic:SetSize(14, 14)
    ic:SetPoint("LEFT", 12, 0)
    local col = filled and C.ink or C.tx
    ic:SetVertexColor(col[1], col[2], col[3], 1)
    local fs = b:CreateFontString(nil, "OVERLAY")
    LeelFont(fs, 12.5, "")
    fs:SetTextColor(col[1], col[2], col[3])
    fs:SetText(label)
    fs:SetPoint("LEFT", ic, "RIGHT", 5, 0)
    b:SetWidth(12 + 14 + 5 + fs:GetStringWidth() + 14)
    Tip(b, tipTitle, tipLine)
    return b
end

local function SavePos()
    local x, y = bar:GetCenter()
    if x then db.pos = { math.floor(x + 0.5), math.floor(y + 0.5) } end
end

local function ApplyPos()
    bar:ClearAllPoints()
    if db.pos then
        bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", db.pos[1], db.pos[2])
    else
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190)
    end
end

local pendingShow = false
local function UpdateShown()
    if not bar then return end
    if InCombatLockdown() then pendingShow = true return end   -- 보안 단추가 든 바는 전투 중에 못 숨김
    pendingShow = false
    local show = db.show == "always" or (db.show == "group" and IsInGroup())
    bar:SetShown(show)
end

-- 마우스 단축키: 누를 때마다 마우스 올린 몹에 다음 징 (전투 중에도 되도록 보안 처리기 안에서 순서를 셈)
local sweepBtn
ResetSweep = function()
    if sweepBtn and not InCombatLockdown() then sweepBtn:SetAttribute("idx", 0) end
end

local function CreateSweep()
    sweepBtn = CreateFrame("Button", "LeelMarkSweep", UIParent, "SecureActionButtonTemplate, SecureHandlerBaseTemplate")
    sweepBtn:RegisterForClicks("AnyUp", "AnyDown")
    sweepBtn:SetAttribute("useOnKeyDown", false)
    sweepBtn:SetAttribute("type", "macro")
    sweepBtn:SetAttribute("idx", 0)
    sweepBtn:SetAttribute("macrotext", "")
    SecureHandlerWrapScript(sweepBtn, "OnClick", sweepBtn, [[
        if down then return false end
        local i = (self:GetAttribute("idx") or 0) + 1
        if i > 8 then i = 1 end
        self:SetAttribute("idx", i)
        local m = string.sub("87654321", i, i)
        self:SetAttribute("macrotext", "/tm [@mouseover,harm,nodead] ~" .. m)
    ]])
end

local function CreateBar()
    bar = CreateFrame("Frame", "LeelMarkBar", UIParent)
    bar:SetHeight(42)
    bar:SetScale(db.scale or 1)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    local bg = PillTex(bar, "pill44", 22, C.plate)
    bg:SetAllPoints()
    local rim = PillTex(bar, "pill44rim", 22, C.acc, 0.6, "BORDER")
    rim:SetAllPoints()

    -- 토끼: 끌어서 옮기기
    local bun = CreateFrame("Button", nil, bar)
    bun:SetSize(30, 30)
    bun:SetPoint("LEFT", 6, 0)
    local bt = bun:CreateTexture(nil, "ARTWORK")
    bt:SetTexture(MEDIA .. "icon"); bt:SetAllPoints()
    bun:RegisterForDrag("LeftButton")
    bun:SetScript("OnDragStart", function() bar:StartMoving() end)
    bun:SetScript("OnDragStop", function() bar:StopMovingOrSizing(); SavePos(); ApplyPos() end)
    Tip(bun, "Leel Mark", "끌어서 옮기기 · 단축키(애드온 > Leel Mark)로 마우스 올린 몹에 순서대로 징 · /lmark")

    local prev = bun
    for _, idx in ipairs(BAR_ORDER) do
        local b = MarkButton(bar, idx)
        b:SetPoint("LEFT", prev, "RIGHT", prev == bun and 8 or 4, 0)
        prev = b
    end
    -- 자동: 매크로 단추. 전투 밖에서 누르는 순간 매크로를 새로 만듦
    local auto = PillButton(bar, "LeelMarkAuto", "자동", "ic_wand", true,
        "자동", "보이는 적에게 우선순위대로 빈 징을 채워요 (시전 몹·정예 먼저). 전투 밖에서만")
    auto:SetAttribute("type", "macro")
    auto:SetAttribute("macrotext", "")
    auto:SetScript("PreClick", function(self, _, down)
        if down then return end
        if InCombatLockdown() then Print("전투 중에는 자동을 쓸 수 없어요. 징 단추나 마우스 단축키를 써 주세요.") return end
        if not CanMark() then Print("공격대에서는 공격대장·부공격대장만 징을 찍을 수 있어요.") self:SetAttribute("macrotext", "") return end
        local text, msg = BuildAutoMacro()
        self:SetAttribute("macrotext", text or "")
        if db.debug and text then Print("자동 매크로:\n" .. text) end
        if not text then Print(msg) elseif msg ~= "" then Announce(msg) end
        ResetSweep()
    end)
    auto:SetPoint("LEFT", prev, "RIGHT", 8, 0)
    -- 지우기: 블리자드 보안 단추의 "모두 지우기"
    local clr = PillButton(bar, "LeelMarkClear", "지우기", "ic_eraser", false, "지우기", "모든 징을 지워요")
    clr:SetAttribute("type", "raidtarget")
    clr:SetAttribute("action", "clear-all")
    clr:HookScript("OnClick", function(_, _, down) if not down then ResetSweep() end end)
    clr:SetPoint("LEFT", auto, "RIGHT", 6, 0)

    bar:SetWidth(6 + 30 + 8 + 8 * 30 + 7 * 4 + 8 + auto:GetWidth() + 6 + clr:GetWidth() + 8)
    ApplyPos()
    UpdateShown()
end

----------------------------------------------------------------------
-- 로딩 · 이벤트 · 명령어
----------------------------------------------------------------------
BINDING_HEADER_LEELMARK = "Leel Mark"
_G["BINDING_NAME_CLICK LeelMarkAuto:LeftButton"] = "자동으로 징 찍기 (전투 밖)"
_G["BINDING_NAME_CLICK LeelMarkClear:LeftButton"] = "징 모두 지우기"
_G["BINDING_NAME_CLICK LeelMarkSweep:LeftButton"] = "마우스 올린 몹에 다음 징"

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        LeelMarkDB = LeelMarkDB or {}
        for k, v in pairs(defaults) do if LeelMarkDB[k] == nil then LeelMarkDB[k] = v end end
        db = LeelMarkDB
    elseif event == "PLAYER_LOGIN" then
        CreateSweep()
        CreateBar()
    elseif event == "GROUP_ROSTER_UPDATE" then
        UpdateShown()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingShow then UpdateShown() end
        ResetSweep()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- 전투 직전: 낡은 자동 매크로가 엉뚱한 몹에 찍지 않게 비움
        local a = _G.LeelMarkAuto
        if a then a:SetAttribute("macrotext", "") end
    end
end)

SLASH_LEELMARK1 = "/lmark"
SLASH_LEELMARK2 = "/징"
SlashCmdList.LEELMARK = function(msg)
    local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
    if cmd == "자동" or cmd == "auto" or cmd == "지우기" or cmd == "clear" then
        Print("게임 규칙상 채팅 명령으로는 징을 못 찍어요. 바의 단추나 단축키를 써 주세요.")
    elseif cmd == "보이기" or cmd == "show" then
        db.show = (db.show == "always") and "group" or "always"
        UpdateShown()
        Print(db.show == "always" and "바를 항상 보여요." or "바는 파티일 때만 보여요.")
    elseif cmd == "숨기기" or cmd == "hide" then
        db.show = "never"; UpdateShown()
        Print("바를 숨겼어요. /lmark 보이기 로 다시 켜요. (단축키는 계속 동작)")
    elseif cmd == "알림" or cmd == "announce" then
        db.announce = not db.announce
        Print("자동으로 찍을 때 파티 채팅 알림 " .. (db.announce and "켬" or "끔"))
    elseif cmd == "크기" or cmd == "scale" then
        local n = tonumber(arg)
        if n then
            if n > 3 then n = n / 100 end
            db.scale = math.min(1.6, math.max(0.6, n))
            bar:SetScale(db.scale); ApplyPos()
            Print("바 크기 " .. math.floor(db.scale * 100 + 0.5) .. "%")
        end
    elseif cmd == "점검" or cmd == "debug" then
        db.debug = not db.debug
        Print("점검 " .. (db.debug and "켬: 자동을 누르면 만든 매크로를 채팅에 보여 줘요" or "끔"))
    elseif cmd == "위치" or cmd == "reset" then
        db.pos = nil; ApplyPos()
        Print("바 자리를 처음대로 돌렸어요.")
    else
        Print("/lmark 보이기 · 숨기기 · 알림 · 크기 80 · 위치")
        Print("단축키: 게임 메뉴 > 단축키 > 애드온 > Leel Mark (자동 · 지우기 · 마우스 올린 몹에 다음 징)")
    end
end
