-- Leel Spot: 눌러서 줍는 퀘스트 물건 위에 르엘 분홍 이름표
-- 게임 기본 "상호작용 키(소프트 타깃)"가 고른 물건(softinteract)의 이름표 자리에 알약을 붙인다.
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

local NUM = MEDIA .. "BarlowCondensed-ExtraBoldItalic.ttf"

local C = {
    plate = { 0.125, 0.094, 0.086, 0.94 },
    pink  = { 0.949, 0.702, 0.761 },
    soft  = { 1.0, 0.839, 0.878 },
    cream = { 0.965, 0.925, 0.910 },
    dim   = { 0.80, 0.64, 0.62 },
}
local DEFAULTS = { on = true, all = false, size = 1.0, y = 0, key = true, stem = 34 }
local db

local function P(msg) print("|cfff2b3c2[Leel Spot]|r " .. msg) end
local function Slice(t, m) pcall(t.SetTextureSliceMargins, t, m, m, m, m) end

----------------------------------------------------------------------
-- 게임 설정: 상호작용 키가 물건도 고르게
----------------------------------------------------------------------
local function ApplyCVars()
    if InCombatLockdown() then return end
    local any = (Enum and Enum.SoftTargetEnableFlags and Enum.SoftTargetEnableFlags.Any) or 3
    pcall(SetCVar, "softTargetInteract", any)
    pcall(SetCVar, "SoftTargetIconGameObject", "1")
    pcall(SetCVar, "SoftTargetIconInteract", "1")
    -- 물건 고르는 범위 넓히기 (없는 설정이면 조용히 무시)
    pcall(SetCVar, "SoftTargetInteractArc", "2")
    pcall(SetCVar, "SoftTargetInteractRange", "15")
    local sz = tonumber(GetCVar("SoftTargetNameplateSize") or "0") or 0
    if sz <= 0 then pcall(SetCVar, "SoftTargetNameplateSize", "19") end
end

----------------------------------------------------------------------
-- 이름표 (알약)
----------------------------------------------------------------------
local pill = CreateFrame("Frame", "LeelSpotPill", UIParent)
pill:SetFrameStrata("MEDIUM")
pill:SetSize(120, 30)
pill:Hide()

local bg = pill:CreateTexture(nil, "BACKGROUND")
bg:SetTexture(MEDIA .. "pill22"); Slice(bg, 11)
bg:SetAllPoints(); bg:SetVertexColor(C.plate[1], C.plate[2], C.plate[3], C.plate[4])
local rim = pill:CreateTexture(nil, "BORDER")
rim:SetTexture(MEDIA .. "pill22rim"); Slice(rim, 11)
rim:SetAllPoints(); rim:SetVertexColor(C.pink[1], C.pink[2], C.pink[3], 0.75)

local halo = pill:CreateTexture(nil, "BACKGROUND", nil, -2)
halo:SetTexture(MEDIA .. "circle")
halo:SetSize(40, 40)
halo:SetVertexColor(C.pink[1], C.pink[2], C.pink[3], 0.35)
halo:SetBlendMode("ADD")

local icon = pill:CreateTexture(nil, "ARTWORK")
icon:SetTexture(MEDIA .. "bunny")
icon:SetSize(26, 26)
icon:SetPoint("LEFT", pill, "LEFT", 2, 0)
halo:SetPoint("CENTER", icon, "CENTER")

local nameFS = pill:CreateFontString(nil, "OVERLAY")
LeelFont(nameFS, 12.5, "")
nameFS:SetShadowOffset(1, -1); nameFS:SetShadowColor(0, 0, 0, 0.8)
nameFS:SetTextColor(C.cream[1], C.cream[2], C.cream[3])
nameFS:SetPoint("LEFT", icon, "RIGHT", 6, 0)
nameFS:SetWordWrap(false)

local progFS = pill:CreateFontString(nil, "OVERLAY")
progFS:SetFont(NUM, 15, "")
progFS:SetShadowOffset(1, -1); progFS:SetShadowColor(0, 0, 0, 0.8)
progFS:SetTextColor(C.soft[1], C.soft[2], C.soft[3])
progFS:SetPoint("LEFT", nameFS, "RIGHT", 6, 0)

-- 키 칩 (상호작용 키가 묶여 있을 때만)
local key = CreateFrame("Frame", nil, pill)
key:SetSize(52, 18)
key:SetPoint("LEFT", pill, "RIGHT", 4, 0)

-- 물건 가리키는 선 + 끝 점
local stem = pill:CreateTexture(nil, "BACKGROUND", nil, -1)
stem:SetColorTexture(1, 1, 1, 1)
stem:SetWidth(2)
stem:SetPoint("TOP", pill, "BOTTOM", 0, 1)
pcall(stem.SetGradient, stem, "VERTICAL",
    CreateColor(C.pink[1], C.pink[2], C.pink[3], 0.35), CreateColor(C.pink[1], C.pink[2], C.pink[3], 0.95))
local dot = pill:CreateTexture(nil, "ARTWORK")
dot:SetTexture(MEDIA .. "circle"); dot:SetSize(8, 8)
dot:SetVertexColor(C.pink[1], C.pink[2], C.pink[3], 1)
dot:SetPoint("CENTER", stem, "BOTTOM", 0, 0)
local dotGlow = pill:CreateTexture(nil, "BACKGROUND", nil, -2)
dotGlow:SetTexture(MEDIA .. "circle"); dotGlow:SetSize(22, 22); dotGlow:SetBlendMode("ADD")
dotGlow:SetVertexColor(C.pink[1], C.pink[2], C.pink[3], 0.45)
dotGlow:SetPoint("CENTER", dot, "CENTER")
local kbg = key:CreateTexture(nil, "BACKGROUND")
kbg:SetTexture(MEDIA .. "pill22"); Slice(kbg, 9); kbg:SetAllPoints()
kbg:SetVertexColor(C.pink[1], C.pink[2], C.pink[3], 1)
local kFS = key:CreateFontString(nil, "OVERLAY")
LeelFont(kFS, 11, ""); kFS:SetTextColor(0.227, 0.11, 0.141)
kFS:SetPoint("CENTER")

-- 은은하게 숨쉬기
local ag = halo:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
local a1 = ag:CreateAnimation("Alpha"); a1:SetFromAlpha(0.35); a1:SetToAlpha(0.9); a1:SetDuration(0.8)
a1:SetSmoothing("IN_OUT")

local function KeyText()
    local k = GetBindingKey("INTERACTTARGET")
    if not k then return nil end
    k = GetBindingText and GetBindingText(k, "KEY_", true) or k
    return k
end

local function Layout(hasProg)
    local w = 2 + 26 + 6 + 10
    local okN, nw = pcall(function() return nameFS:GetUnboundedStringWidth() + 0 end)
    if not okN or type(nw) ~= "number" then nw = 110 end
    w = w + math.min(nw, 200)
    if hasProg then
        local okP, pw = pcall(function() return progFS:GetUnboundedStringWidth() + 0 end)
        w = w + 6 + ((okP and pw) or 24)
    end
    pill:SetWidth(math.max(70, w))
    nameFS:SetWidth(math.min(nw, 200) + 2)
end

----------------------------------------------------------------------
-- 퀘스트 진행도: 툴팁 줄에서 "3/8" 찾기 (비밀값이면 그냥 생략)
----------------------------------------------------------------------
-- 퀘스트 목록 목표에서 물건 이름 찾기 ("로켓 자동차 파편: 3/8")
local function FromQuestLog(name)
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return nil end
    local ok, a, b = pcall(function()
        if type(name) ~= "string" or name == "" then return nil end
        local n = C_QuestLog.GetNumQuestLogEntries() or 0
        for i = 1, n do
            local qid = C_QuestLog.GetQuestIDForLogIndex and C_QuestLog.GetQuestIDForLogIndex(i)
            if not qid then
                local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(i)
                qid = info and not info.isHeader and info.questID
            end
            if qid and qid > 0 then
                local objs = C_QuestLog.GetQuestObjectives(qid)
                for _, o in ipairs(objs or {}) do
                    local t = o.text
                    if type(t) == "string" and not o.finished and t:find(name, 1, true) then
                        local x, y = o.numFulfilled, o.numRequired
                        if not (x and y and y > 0) then
                            x, y = t:match("(%d+)%s*/%s*(%d+)")
                            x, y = tonumber(x), tonumber(y)
                        end
                        if x and y then return x, y end
                        return 0, 1
                    end
                end
            end
        end
    end)
    if ok and a then return a, b end
    return nil
end

-- Questie 자료: 물건 이름 → 물건 ID → 그 물건이 걸린 퀘스트 목표 (이름이 달라도 찾음)
local function FromQuestie(name)
    if not (QuestieLoader and LibQuestieDB and LibQuestieDB.Object and LibQuestieDB.Object.IdsByName) then return nil end
    local ok, a, b = pcall(function()
        if type(name) ~= "string" or name == "" then return nil end
        local QT = QuestieLoader:ImportModule("QuestieTooltips")
        if not (QT and QT.lookupByKey) then return nil end
        local ids = LibQuestieDB.Object.IdsByName(name)
        local found
        for _, id in ipairs(ids or {}) do
            for _, tip in pairs(QT.lookupByKey["o_" .. id] or {}) do
                local o = tip.objective
                if o and not tip.name then
                    pcall(function() if o.Update and not (o.IsSourceItem or o.IsRequiredSourceItem) then o:Update() end end)
                    local x, y = tonumber(o.Collected), tonumber(o.Needed)
                    if x and y and y > 0 then
                        if x < y then return x, y end
                        found = found or { x, y }
                    else
                        found = found or { 0, 1 }
                    end
                end
            end
        end
        if found then return found[1], found[2] end
    end)
    if ok and a then return a, b end
    return nil
end

local function FindProgress()
    local okN, nm = pcall(UnitName, "softinteract")
    if okN then
        local a, b = FromQuestie(nm)
        if a then return a, b end
        a, b = FromQuestLog(nm)
        if a then return a, b end
    end
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetUnit, "softinteract")
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    for i = 2, #data.lines do
        local line = data.lines[i]
        local okL, a, b = pcall(function()
            local t = line and line.leftText
            if type(t) ~= "string" then return nil end
            local x, y = t:match("(%d+)%s*/%s*(%d+)")
            return tonumber(x), tonumber(y)
        end)
        if okL and a and b and b > 0 then return a, b end
    end
    return nil
end

----------------------------------------------------------------------
-- 붙이기 / 떼기
----------------------------------------------------------------------
local curPlate

local function HideBlizzIcon(plate, hide)
    pcall(function()
        local st = plate.UnitFrame and plate.UnitFrame.SoftTargetFrame
        if st then st:SetAlpha(hide and 0 or 1) end
    end)
end

-- 게임 기본 물건 아이콘(약초 꽃, 톱니 등)은 물건이면 항상 숨김
local muted
local function Mute(plate)
    if muted and muted ~= plate then HideBlizzIcon(muted, false) end
    muted = plate
    if plate then HideBlizzIcon(plate, true) end
end

local function Detach()
    curPlate = nil
    ag:Stop()
    pill:ClearAllPoints()
    pill:Hide()
end

local function HasSoft()
    local okE, exists = pcall(UnitExists, "softinteract")
    if okE and exists then return true end
    local okG, guid = pcall(UnitGUID, "softinteract")
    return okG and guid ~= nil
end

local function Refresh()
    if not db or not db.on then Mute(nil); Detach() return end
    if not HasSoft() then Mute(nil); Detach() return end

    -- 물건에 이름표판이 없으면(포에버) 화면 가운데 위에 띄운다
    local okP, plate = pcall(C_NamePlate.GetNamePlateForUnit, "softinteract")
    if not okP then plate = nil end

    -- NPC는 빼고 물건(GameObject)에만
    local okG, isObj = pcall(function()
        local g = UnitGUID("softinteract")
        return type(g) ~= "string" or g:find("^GameObject") ~= nil
    end)
    if okG and not isObj then Mute(nil); Detach() return end
    Mute(plate)

    local a, b = FindProgress()
    if not a and not db.all then Detach() return end

    curPlate = plate

    local okN, name = pcall(UnitName, "softinteract")
    nameFS:SetText(okN and name or "")
    if a then
        progFS:SetText(a .. "/" .. b)
        progFS:Show()
        rim:SetVertexColor(C.pink[1], C.pink[2], C.pink[3], 0.85)
        icon:SetDesaturated(false); icon:SetAlpha(1)
        halo:Show(); ag:Play()
    else
        progFS:SetText(""); progFS:Hide()
        rim:SetVertexColor(C.dim[1], C.dim[2], C.dim[3], 0.45)
        icon:SetDesaturated(true); icon:SetAlpha(0.8)
        halo:Hide(); ag:Stop()
    end
    Layout(a ~= nil)

    local kt = nil -- 줍기 키 칩은 안 씀 (오른쪽 클릭으로 줍기)
    if kt then
        kFS:SetText("|cff3a1c24" .. kt .. "|r  줍기")
        key:SetWidth(kFS:GetUnboundedStringWidth() + 18)
        key:Show()
    else
        key:Hide()
    end

    pill:SetScale(db.size or 1)
    pill:ClearAllPoints()
    local L = db.stem or 34
    local okA = plate and pcall(pill.SetPoint, pill, "BOTTOM", plate, "CENTER", 0, L + (db.y or 0))
    if okA then
        stem:SetHeight(L); stem:SetShown(L > 0); dot:SetShown(L > 0); dotGlow:SetShown(L > 0 and a ~= nil)
    else
        stem:Hide(); dot:Hide(); dotGlow:Hide()
        curPlate = nil
        pill:ClearAllPoints()
        pill:SetPoint("CENTER", UIParent, "CENTER", 0, db.fy or 140)
    end
    pill:Show()
end

----------------------------------------------------------------------
-- 이벤트
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED")
ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
ev:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")

ev:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        LeelSpotDB = LeelSpotDB or {}
        db = LeelSpotDB
        if db.stem == nil then db.y = nil end -- 선 생기기 전 높이값 초기화
        if not db.v2 then db.all = false; db.v2 = true end -- 기본: 퀘스트 물건만
        for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
        ApplyCVars()
        return
    end
    if not db then return end
    if event == "PLAYER_REGEN_ENABLED" then ApplyCVars() return end
    if event == "NAME_PLATE_UNIT_REMOVED" then
        local ok, gone = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok and gone and gone == curPlate then Detach() end
        if ok and gone and gone == muted then HideBlizzIcon(muted, false); muted = nil end
        C_Timer.After(0, Refresh)
        return
    end
    -- 툴팁 정보가 한 박자 늦게 오는 경우가 있어 한 번 더
    Refresh()
    C_Timer.After(0.15, Refresh)
end)

----------------------------------------------------------------------
-- 명령어
----------------------------------------------------------------------
local function Help()
    P("/lspot 또는 /물건")
    print("  켜기 · 끄기  — 이름표 켜고 끄기")
    print("  퀘만  — 퀘스트 물건(진행도 있는 것)에만 표시 / 다시 치면 모든 물건")
    print("  크기 0.8~1.6  — 이름표 크기")
    print("  선 숫자  — 이름표에서 물건까지 선 길이 (기본 34, 0이면 끔)")
    print("  높이 숫자  — 선 끝 위치 위아래 미세 조정 (기본 0)")
    print("  점검  — 지금 고른 물건 정보")
end

local function Slash(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    if not db then return end
    if cmd == "켜기" or cmd == "on" then db.on = true; P("켰어요."); Refresh()
    elseif cmd == "끄기" or cmd == "off" then db.on = false; P("껐어요."); Detach()
    elseif cmd == "퀘만" or cmd == "quest" then
        db.all = not db.all
        P(db.all and "모든 물건에 표시해요 (퀘스트 물건만 분홍)." or "퀘스트 물건에만 표시해요."); Refresh()
    elseif cmd == "크기" or cmd == "size" then
        local n = tonumber(arg)
        if n and n >= 0.6 and n <= 2 then db.size = n; P("크기 " .. n); Refresh() else P("예: /lspot 크기 1.2") end
    elseif cmd == "높이" or cmd == "y" then
        local n = tonumber(arg)
        if n then db.y = n; P("높이 " .. n); Refresh() else P("예: /lspot 높이 10") end
    elseif cmd == "키" or cmd == "key" then
        if InCombatLockdown() then P("전투 끝나고 해주세요.") return end
        local k = (arg or ""):upper()
        if k == "" then P("지금 상호작용 키: " .. (KeyText() or "없음") .. "  (예: /lspot 키 F)") return end
        local old = GetBindingAction(k)
        SetBinding(k, "INTERACTTARGET")
        SaveBindings(GetCurrentBindingSet())
        P(k .. " = 상호작용(줍기)" .. ((old and old ~= "" and old ~= "INTERACTTARGET") and ("  |cff9d8a86(원래: " .. old .. ")|r") or ""))
        Refresh()
    elseif cmd == "선" or cmd == "stem" then
        local n = tonumber(arg)
        if n and n >= 0 and n <= 150 then db.stem = n; P("선 길이 " .. n .. (n == 0 and " (선 끔)" or "")); Refresh() else P("예: /lspot 선 40  (0이면 끔)") end
    elseif cmd == "키숨김" then db.key = not db.key; P(db.key and "키 칩 보여요." or "키 칩 숨겨요."); Refresh()
    elseif cmd == "점검" or cmd == "debug" then
        ApplyCVars()
        local okE, ex = pcall(UnitExists, "softinteract")
        P("softTargetInteract=" .. tostring(GetCVar("softTargetInteract")) ..
          "  물건아이콘=" .. tostring(GetCVar("SoftTargetIconGameObject")) ..
          "  키=" .. tostring(KeyText() or "없음"))
        local okG, guid = pcall(UnitGUID, "softinteract")
        local okN, nm = pcall(UnitName, "softinteract")
        local okP2, pl = pcall(C_NamePlate.GetNamePlateForUnit, "softinteract")
        P("GUID: " .. tostring(okG and guid or "없음") .. "  이름: " .. tostring(okN and nm or "?") ..
          "  판: " .. tostring(okP2 and pl ~= nil))
        P("Questie: " .. tostring(LibQuestieDB ~= nil) .. "  물건ID: " .. tostring((function()
            local ok, ids = pcall(function() return LibQuestieDB.Object.IdsByName(nm) end)
            return ok and ids and ids[1] or "없음" end)()))
        P("범위: " .. tostring(GetCVar("SoftTargetInteractRange")) .. "  각도: " .. tostring(GetCVar("SoftTargetInteractArc")))
        P("고른 물건: " .. ((okE and ex) and "있음" or "없음") ..
          "  이름표판: " .. tostring(curPlate ~= nil) ..
          "  진행도: " .. tostring((FindProgress()) or "없음"))
    else Help() end
end
SLASH_LEELSPOT1 = "/lspot"
SLASH_LEELSPOT2 = "/물건"
SlashCmdList.LEELSPOT = Slash
