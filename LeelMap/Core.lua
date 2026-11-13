-- Leel Map / Core.lua
-- 르엘 UI 세계 지도(M키): 분홍 둥근 창 + 지역 이름·레벨 알약, 아래 좌표 줄(내 위치·마우스),
-- 지역에 마우스를 올리면 레벨 알약(와우 난이도 색을 살짝 부드럽게), 작은 창 지도, 걸을 때 흐려짐
-- 블리자드 지도 기능(작은 지도 miniWorldMap, 걸을 때 흐림 mapFade)은 그대로 쓰고 모양·정보만 더함

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
    acc   = { 0.949, 0.702, 0.761 },
    accHi = { 1.00, 0.84, 0.88 },
    ink   = { 0.227, 0.11, 0.141 },
    tx    = { 0.965, 0.925, 0.91 },
    tx2   = { 0.81, 0.635, 0.616 },
    plate = { 0.125, 0.094, 0.086, 0.97 },
}

local defaults = { mini = true, fade = true, fadeAlpha = 0.4, coords = true, levels = true, skin = true }
local db

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cfff2b3c2[Leel Map]|r " .. msg)
end

local function Font(parent, size, color, file)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    if not (file and fs:SetFont(file, size, "")) then LeelFont(fs, size, "") end
    fs:SetShadowColor(0, 0, 0, 0.85)
    fs:SetShadowOffset(1, -1)
    color = color or C.tx
    fs:SetTextColor(color[1], color[2], color[3])
    return fs
end

-- 둥근 사각 판 (텍스처 9조각으로 모서리 유지)
local function RoundTex(parent, layer, sub, file, c, a)
    local t = parent:CreateTexture(nil, layer, nil, sub or 0)
    t:SetTexture(MEDIA .. file)
    pcall(t.SetTextureSliceMargins, t, 16, 16, 16, 16)
    if Enum and Enum.UITextureSliceMode then pcall(t.SetTextureSliceMode, t, Enum.UITextureSliceMode.Stretched) end
    t:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1)
    return t
end

----------------------------------------------------------------------
-- 지역 레벨 → 난이도 색 (블리자드 지도 글자와 같은 계산, 색만 살짝 부드럽게)
----------------------------------------------------------------------
local function Soft(c)
    local k = 0.22   -- 크림색 쪽으로 22% 섞기
    return { c.r + (1 - c.r) * k, c.g + (0.95 - c.g) * k, c.b + (0.94 - c.b) * k }
end

local function Same(a, b)
    return a and b and math.abs(a.r - b.r) < 0.01 and math.abs(a.g - b.g) < 0.01 and math.abs(a.b - b.b) < 0.01
end

local function Difficulty(minL, maxL)
    local lvl = UnitLevel("player") or 1
    local c, hint
    if lvl < minL then
        c = GetQuestDifficultyColor(minL)
        hint = (minL - lvl >= 5) and "너무 어려워요" or "조금 어려워요"
    elseif lvl > maxL then
        c = GetQuestDifficultyColor(maxL - 2)
        hint = Same(c, QuestDifficultyColors and QuestDifficultyColors.trivial) and "경험치 거의 없어요" or "쉬워요"
    else
        c = (QuestDifficultyColors and QuestDifficultyColors.difficult) or { r = 1, g = 0.82, b = 0 }
        hint = "딱 맞아요"
    end
    return Soft(c), hint
end

-- 게임이 지역 레벨을 안 주면 쓰는 클래식 지역 레벨표 (uiMapID 기준)
local ZONE_LEVELS = {
    -- 칼림도어
    [1411] = { 1, 10 }, [1412] = { 1, 10 }, [1438] = { 1, 10 }, [1413] = { 10, 25 }, [1439] = { 10, 20 },
    [1442] = { 15, 27 }, [1440] = { 18, 30 }, [1441] = { 25, 35 }, [1443] = { 30, 40 }, [1445] = { 35, 45 },
    [1444] = { 40, 50 }, [1446] = { 40, 50 }, [1447] = { 45, 55 }, [1448] = { 48, 55 }, [1449] = { 48, 55 },
    [1451] = { 55, 60 }, [1452] = { 55, 60 },
    -- 동부 왕국
    [1420] = { 1, 10 }, [1426] = { 1, 10 }, [1429] = { 1, 10 }, [1421] = { 10, 20 }, [1436] = { 10, 20 },
    [1432] = { 10, 20 }, [1433] = { 15, 25 }, [1431] = { 18, 30 }, [1437] = { 20, 30 }, [1424] = { 20, 30 },
    [1416] = { 30, 40 }, [1417] = { 30, 40 }, [1434] = { 30, 45 }, [1418] = { 35, 45 }, [1435] = { 35, 45 },
    [1425] = { 40, 50 }, [1427] = { 43, 50 }, [1419] = { 45, 55 }, [1428] = { 50, 58 }, [1422] = { 51, 58 },
    [1423] = { 53, 60 }, [1430] = { 55, 60 },
}

local function Levels(mapID)
    if not mapID then return end
    if C_Map.GetMapLevels then
        local ok, minL, maxL = pcall(C_Map.GetMapLevels, mapID)
        if ok and minL and maxL and minL > 0 and maxL > 0 then return minL, maxL end
    end
    local z = ZONE_LEVELS[mapID]
    if z then return z[1], z[2] end
end

local function LevelText(minL, maxL)
    return minL == maxL and tostring(maxL) or (minL .. "-" .. maxL)
end

----------------------------------------------------------------------
-- 지도 창 꾸미기
----------------------------------------------------------------------
local header, coords, tip
local ns_skinErr
local SkinChrome, SkinQuestLog, TintChecks

local function HideRegion(r)
    if r and r.SetAlpha then
        r:SetAlpha(0)
        pcall(hooksecurefunc, r, "SetAlpha", function(self, a) if a and a > 0 then self:SetAlpha(0) end end)
    end
end

local function MakePill(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(44, 20)
    p.bg = p:CreateTexture(nil, "BACKGROUND")
    p.bg:SetTexture(MEDIA .. "pill22")   -- 끝이 완전히 둥근 알약 (9조각)
    pcall(p.bg.SetTextureSliceMargins, p.bg, 11, 11, 11, 11)
    p.bg:SetAllPoints()
    p.text = Font(p, 14, C.ink, NUM)
    p.text:SetShadowColor(0, 0, 0, 0)
    p.text:SetPoint("CENTER", 0, 0)
    p.bg:SetVertexColor(0.18, 0.137, 0.129, 1)
    p.rim = p:CreateTexture(nil, "BORDER")
    p.rim:SetTexture(MEDIA .. "pill22rim")
    pcall(p.rim.SetTextureSliceMargins, p.rim, 11, 11, 11, 11)
    p.rim:SetAllPoints()
    p.rim:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.55)
    function p:Set(minL, maxL)
        -- 르엘 판(어두운 알약 + 분홍 테) 위에 숫자만 난이도 색
        local c = Difficulty(minL, maxL)
        self.text:SetTextColor(c[1], c[2], c[3])
        self.text:SetText(LevelText(minL, maxL))
        self:SetWidth(math.max(34, self.text:GetStringWidth() + 16))
        self:Show()
    end
    return p
end

local function UpdateHeader()
    if not header then return end
    local mapID = WorldMapFrame:GetMapID()
    local info = mapID and C_Map.GetMapInfo(mapID)
    header.name:SetText(info and info.name or "")
    local minL, maxL = Levels(mapID)
    if minL and db.levels then header.pill:Set(minL, maxL) else header.pill:Hide() end
end

local function Skin()
    local wm = WorldMapFrame
    local bf = wm and wm.BorderFrame
    if not bf or wm.leelSkinned then return end
    wm.leelSkinned = true

    -- 블리자드 테두리·초상화·제목 숨김 (버튼은 그대로 동작)
    for _, k in ipairs({ "NineSlice", "PortraitContainer", "Bg", "TopTileStreaks", "InsetBorderTop", "Underlay" }) do
        HideRegion(bf[k])
    end
    if bf.TitleContainer and bf.TitleContainer.TitleText then HideRegion(bf.TitleContainer.TitleText) end
    if bf.portrait then HideRegion(bf.portrait) end

    -- 어두운 둥근 판 (지도 뒤) + 분홍 테두리 (지도 위)
    local plate = RoundTex(wm, "BACKGROUND", -8, "panel", C.plate)
    plate:SetPoint("TOPLEFT", bf, "TOPLEFT", -3, 3)
    plate:SetPoint("BOTTOMRIGHT", bf, "BOTTOMRIGHT", 3, -3)
    local rim = RoundTex(bf, "OVERLAY", 7, "rim", C.acc, 0.65)
    rim:SetPoint("TOPLEFT", bf, "TOPLEFT", -3, 3)
    rim:SetPoint("BOTTOMRIGHT", bf, "BOTTOMRIGHT", 3, -3)

    -- 머리: 토끼 + 지역 이름 + 레벨 알약
    header = CreateFrame("Frame", nil, bf)
    header:SetFrameLevel(bf:GetFrameLevel() + 10)
    header:SetSize(300, 22)
    header:SetPoint("TOPLEFT", bf, "TOPLEFT", 8, -2)
    local ic = header:CreateTexture(nil, "ARTWORK")
    ic:SetTexture(MEDIA .. "icon")
    ic:SetSize(20, 20)
    ic:SetPoint("LEFT", 0, 0)
    header.name = Font(header, 15, C.tx)
    header.name:SetPoint("LEFT", ic, "RIGHT", 6, 0)
    header.pill = MakePill(header)
    header.pill:SetPoint("LEFT", header.name, "RIGHT", 8, 0)
    hooksecurefunc(wm, "OnMapChanged", UpdateHeader)
    UpdateHeader()


    -- 지도 그림 네 귀퉁이를 둥글게 (판 색 귀퉁이를 덮음) + 안쪽 얇은 테
    local sc = wm.ScrollContainer
    if sc then
        local cf = CreateFrame("Frame", nil, wm)
        cf:SetAllPoints(sc)
        cf:SetFrameStrata("HIGH")
        cf:SetFrameLevel(wm.BorderFrame:GetFrameLevel() + 14)   -- 좌표 줄(+12) 위로
        cf:EnableMouse(false)
        local R = 12
        local spec = {
            { "TOPLEFT", 0, 1, 0, 1 }, { "TOPRIGHT", 1, 0, 0, 1 },
            { "BOTTOMLEFT", 0, 1, 1, 0 }, { "BOTTOMRIGHT", 1, 0, 1, 0 },
        }
        for _, s in ipairs(spec) do
            local t = cf:CreateTexture(nil, "OVERLAY")
            t:SetTexture(MEDIA .. "corner")
            t:SetTexCoord(s[2], s[3], s[4], s[5])
            t:SetSize(R, R)
            t:SetPoint(s[1])
            t:SetVertexColor(C.plate[1], C.plate[2], C.plate[3], 1)
        end
        local edge = RoundTex(cf, "OVERLAY", 1, "rim", { 0, 0, 0 }, 0.55)
        edge:SetPoint("TOPLEFT", -1, 1); edge:SetPoint("BOTTOMRIGHT", 1, -1)
    end

    local ok, err = pcall(SkinChrome)
    if not ok then ns_skinErr = "버튼: " .. tostring(err); Print("지도 버튼 꾸미기 오류: " .. tostring(err)) end
    local ok2, err2 = pcall(SkinQuestLog)
    if not ok2 then ns_skinErr = "퀘스트: " .. tostring(err2); Print("퀘스트 목록 꾸미기 오류: " .. tostring(err2)) end
end


----------------------------------------------------------------------
-- 길 표시(세계 > 칼림도어 > 지역) 알약 단추 + 오른쪽 위 동그란 버튼 (A안)
-- 게임 버튼은 그대로 두고 그림만 가린 뒤 우리 모양을 얹음 → 누르는 기능 그대로
----------------------------------------------------------------------
local function HideButtonArt(b)
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local t = b[get] and b[get](b)
        if t then HideRegion(t) end
    end
end

local function StripRegions(fr, keep)
    for _, r in ipairs({ fr:GetRegions() }) do
        if r:GetObjectType() == "Texture" and not (keep and keep[r]) then HideRegion(r) end
    end
end

local function Pill(b, inset)
    inset = inset or 0
    local bg = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetTexture(MEDIA .. "pill22")
    pcall(bg.SetTextureSliceMargins, bg, 11, 11, 11, 11)
    bg:SetPoint("TOPLEFT", inset, -1); bg:SetPoint("BOTTOMRIGHT", -inset, 1)
    local rim = b:CreateTexture(nil, "BACKGROUND", nil, -6)
    rim:SetTexture(MEDIA .. "pill22rim")
    pcall(rim.SetTextureSliceMargins, rim, 11, 11, 11, 11)
    rim:SetAllPoints(bg)
    return bg, rim
end

local function PaintNav(b, current)
    if not b.leelBg then return end
    local fs = b.GetFontString and b:GetFontString() or b.text
    if current then
        b.leelBg:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
        b.leelRim:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0)
        if fs then fs:SetTextColor(C.ink[1], C.ink[2], C.ink[3]); fs:SetShadowColor(0, 0, 0, 0) end
        if b.leelArrow then b.leelArrow:SetVertexColor(C.ink[1], C.ink[2], C.ink[3], 1) end
    else
        b.leelBg:SetVertexColor(0.18, 0.137, 0.129, 0.95)
        b.leelRim:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.45)
        if fs then fs:SetTextColor(C.tx[1], C.tx[2], C.tx[3]); fs:SetShadowColor(0, 0, 0, 0.6) end
        if b.leelArrow then b.leelArrow:SetVertexColor(C.tx2[1], C.tx2[2], C.tx2[3], 1) end
    end
end

local function StyleNavButton(b)
    if not b.leelBg then
        HideButtonArt(b)
        for _, k in ipairs({ "arrowUp", "arrowDown", "selected" }) do HideRegion(b[k]) end
        StripRegions(b)
        b.leelBg, b.leelRim = Pill(b, 4)
        local fs = b.GetFontString and b:GetFontString()
        if fs then LeelFont(fs, 12, "") end
        local mab = b.MenuArrowButton
        if mab then
            HideButtonArt(mab)
            if mab.Art then HideRegion(mab.Art) end
            local a = mab:CreateTexture(nil, "ARTWORK")
            a:SetTexture(MEDIA .. "ic_down")
            a:SetSize(11, 11)
            a:SetPoint("CENTER", -2, 0)
            b.leelArrow = a
        end
    end
end

local function PaintNavBar(nav)
    if not nav or not nav.navList then return end
    local last
    for i, b in ipairs(nav.navList) do
        StyleNavButton(b)
        if b:IsShown() then last = b end
    end
    for _, b in ipairs(nav.navList) do PaintNav(b, b == last) end
    -- 블리자드 길 표시는 화살표 모양이라 단추끼리 겹치게 붙어 있음 → 알약 사이를 6px 띄움
    local prev
    for _, b in ipairs(nav.navList) do
        if b:IsShown() then
            if prev then
                b:ClearAllPoints()
                b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
            end
            prev = b
        end
    end
end

local function RoundButton(b, icon, filled)
    if not b or b.leelRound then return end
    b.leelRound = true
    HideButtonArt(b)
    StripRegions(b)
    local bg = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetTexture(MEDIA .. "circle")
    bg:SetSize(24, 24); bg:SetPoint("CENTER")
    local ring = b:CreateTexture(nil, "BACKGROUND", nil, -6)
    ring:SetTexture(MEDIA .. "rim")
    ring:SetSize(24, 24); ring:SetPoint("CENTER")
    local ic = b:CreateTexture(nil, "ARTWORK", nil, 7)
    ic:SetTexture(MEDIA .. icon)
    ic:SetSize(13, 13); ic:SetPoint("CENTER")
    if filled then
        bg:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1); ring:SetAlpha(0)
        ic:SetVertexColor(C.ink[1], C.ink[2], C.ink[3], 1)
    else
        bg:SetVertexColor(0.18, 0.137, 0.129, 0.97)
        ring:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.6)
        ic:SetVertexColor(C.tx[1], C.tx[2], C.tx[3], 1)
    end
    b:HookScript("OnEnter", function() ic:SetVertexColor(1, 1, 1, 1) end)
    b:HookScript("OnLeave", function()
        if filled then ic:SetVertexColor(C.ink[1], C.ink[2], C.ink[3], 1) else ic:SetVertexColor(C.tx[1], C.tx[2], C.tx[3], 1) end
    end)
end

function SkinChrome()
    local wm = WorldMapFrame
    local bf = wm.BorderFrame
    local nav = wm.NavBar or wm.navBar
    if nav then
        StripRegions(nav)
        if nav.overlay then StripRegions(nav.overlay) end
        if nav.InsetBorderBottomLeft then HideRegion(nav.InsetBorderBottomLeft) end
        if nav.overflow then
            HideButtonArt(nav.overflow)
            StripRegions(nav.overflow)
            local a = nav.overflow:CreateTexture(nil, "ARTWORK")
            a:SetTexture(MEDIA .. "ic_down"); a:SetSize(12, 12); a:SetPoint("CENTER")
            a:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
        end
        PaintNavBar(nav)
        if NavBar_AddButton then hooksecurefunc("NavBar_AddButton", function(self) if self == nav then PaintNavBar(nav) end end) end
        if NavBar_Reset then hooksecurefunc("NavBar_Reset", function(self) if self == nav then PaintNavBar(nav) end end) end
        if NavBar_OpenTo then hooksecurefunc("NavBar_OpenTo", function(self) if self == nav then PaintNavBar(nav) end end) end
        if NavBar_ClearTrailingButtons then hooksecurefunc("NavBar_ClearTrailingButtons", function() PaintNavBar(nav) end) end
        if NavBar_CheckLength then hooksecurefunc("NavBar_CheckLength", function(self) if self == nav then PaintNavBar(nav) end end) end
    end
    RoundButton(bf.CloseButton, "ic_x", true)
    local mm = bf.MaximizeMinimizeFrame
    if mm then
        StripRegions(mm)
        RoundButton(mm.MaximizeButton, "ic_max", false)
        RoundButton(mm.MinimizeButton, "ic_min", false)
    end
end


----------------------------------------------------------------------
-- 지도 옆 퀘스트 목록 (블리자드 QuestMapFrame = WorldMapFrame.QuestLog)
-- 줄마다 게임이 새로 그리므로, 목록이 갱신될 때마다 다시 칠함
----------------------------------------------------------------------
local function TintTree(fr, c, depth)
    if not fr or not fr.GetRegions then return end
    for _, r in ipairs({ fr:GetRegions() }) do
        if r:GetObjectType() == "Texture" then
            pcall(r.SetDesaturated, r, true)
            r:SetVertexColor(c[1], c[2], c[3], 1)
        end
    end
    if (depth or 0) > 0 then
        for _, ch in ipairs({ fr:GetChildren() }) do TintTree(ch, c, depth - 1) end
    end
end

-- 체크 표시: 그림 이름(atlas/파일)에 check가 들어간 것만 찾아 분홍으로
function TintChecks(fr, depth)
    if not fr or depth < 0 then return end
    for _, r in ipairs({ fr:GetRegions() }) do
        if r:GetObjectType() == "Texture" then
            local okA, atlas = pcall(r.GetAtlas, r)
            local okT, file = pcall(r.GetTexture, r)
            local name = ((okA and atlas) or "") .. " " .. tostring(okT and file or "")
            if name:lower():find("check") then
                pcall(r.SetDesaturated, r, true)
                r:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
            end
        end
    end
    for _, ch in ipairs({ fr:GetChildren() }) do TintChecks(ch, depth - 1) end
end

local function StyleQuestRows()
    local sf = QuestScrollFrame
    local cont = sf and sf.Contents
    if not cont then return end
    for _, row in ipairs({ cont:GetChildren() }) do
        if row.ButtonText then
            -- 지역 머리줄: 금색 판 숨기고 분홍 글씨 + 얇은 분홍 선
            if not row.leelLine then
                StripRegions(row)
                local ln = row:CreateTexture(nil, "ARTWORK")
                ln:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.28)
                ln:SetHeight(1)
                ln:SetPoint("BOTTOMLEFT", 4, 1); ln:SetPoint("BOTTOMRIGHT", -4, 1)
                row.leelLine = ln
                if row.CollapseButton then TintTree(row.CollapseButton, C.acc, 2) end
            end
            row.ButtonText:SetTextColor(C.acc[1], C.acc[2], C.acc[3])
        elseif row.Checkbox then
            TintTree(row.Checkbox, C.acc, 2)
        end
        TintChecks(row, 3)
    end
end

-- "퀘스트: 29/40" 같은 금색 글자를 차분한 색으로 (포에버 전용 글자라 이름을 몰라서 내용으로 찾음)
local function TintCountText(fr, depth)
    if not fr or depth < 0 then return end
    for _, r in ipairs({ fr:GetRegions() }) do
        if r:GetObjectType() == "FontString" then
            local ok, t = pcall(r.GetText, r)
            if ok and type(t) == "string" and t:find("%d+/%d+") then
                r:SetTextColor(C.accHi[1], C.accHi[2], C.accHi[3])
                -- 이 글자가 든 작은 칸의 금색 테두리를 알약으로
                local p = r:GetParent()
                if p and not p.leelPill and p.GetWidth and p:GetWidth() < 160 then
                    p.leelPill = true
                    StripRegions(p)
                    local pbg = p:CreateTexture(nil, "BACKGROUND", nil, -7)
                    pbg:SetTexture(MEDIA .. "pill22")
                    pcall(pbg.SetTextureSliceMargins, pbg, 11, 11, 11, 11)
                    pbg:SetVertexColor(0.18, 0.137, 0.129, 1)
                    pbg:SetAllPoints()
                end
            end
        end
    end
    for _, ch in ipairs({ fr:GetChildren() }) do TintCountText(ch, depth - 1) end
end

-- 스크롤바: 게임 그림은 숨기고 얇은 줄 + 분홍 손잡이
local function SkinScrollBar(sb)
    if not sb or sb.leelSkinned then return end
    sb.leelSkinned = true
    local function HideAll(fr, d)
        for _, r in ipairs({ fr:GetRegions() }) do if r:GetObjectType() == "Texture" then HideRegion(r) end end
        if d > 0 then for _, ch in ipairs({ fr:GetChildren() }) do HideAll(ch, d - 1) end end
    end
    HideAll(sb, 3)
    local track = sb.Track or sb
    local line = track:CreateTexture(nil, "BACKGROUND", nil, 7)
    line:SetColorTexture(1, 1, 1, 0.08)
    line:SetWidth(4)
    line:SetPoint("TOP", 0, 0); line:SetPoint("BOTTOM", 0, 0)
    local thumb = (sb.Track and sb.Track.Thumb) or sb.Thumb
    if thumb then
        local t = thumb:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.9)
        t:SetWidth(4)
        t:SetPoint("TOP", 0, -1); t:SetPoint("BOTTOM", 0, 1)
    end
end

function SkinQuestLog()
    local ql = WorldMapFrame.QuestLog or QuestMapFrame
    if not ql or ql.leelSkinned then return end
    ql.leelSkinned = true
    local qf = ql.QuestsFrame
    local sf = (qf and qf.ScrollFrame) or QuestScrollFrame
    if ql.Background then HideRegion(ql.Background) end
    if qf then
        StripRegions(qf)
        if qf.BorderFrame then StripRegions(qf.BorderFrame) end
        for _, k in ipairs({ "Background", "Edge" }) do if sf and sf[k] then HideRegion(sf[k]) end end
        local bg = RoundTex(qf, "BACKGROUND", -8, "panel", { 0.105, 0.078, 0.07, 0.97 })
        bg:SetAllPoints(qf)
        local sb = qf.SearchBox or (sf and sf.SearchBox)
        if sb then
            local keep = {}
            if sb.searchIcon then keep[sb.searchIcon] = true end
            StripRegions(sb, keep)
            local pbg = sb:CreateTexture(nil, "BACKGROUND", nil, -7)
            pbg:SetTexture(MEDIA .. "pill22")
            pcall(pbg.SetTextureSliceMargins, pbg, 11, 11, 11, 11)
            pbg:SetVertexColor(0.165, 0.125, 0.118, 1)
            pbg:SetPoint("TOPLEFT", -6, 1); pbg:SetPoint("BOTTOMRIGHT", 2, -1)
            local prim = sb:CreateTexture(nil, "BACKGROUND", nil, -6)
            prim:SetTexture(MEDIA .. "pill22rim")
            pcall(prim.SetTextureSliceMargins, prim, 11, 11, 11, 11)
            prim:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.4)
            prim:SetAllPoints(pbg)
            if sb.searchIcon then sb.searchIcon:SetVertexColor(C.tx2[1], C.tx2[2], C.tx2[3], 1) end
        end
        local dd = qf.SettingsDropdown or (sf and sf.SettingsDropdown)
        if dd then TintTree(dd, C.acc, 2) end
    end
    if sf and sf.ScrollBar then pcall(SkinScrollBar, sf.ScrollBar) end
    if QuestLogQuests_Update then
        hooksecurefunc("QuestLogQuests_Update", function()
            StyleQuestRows()
            TintCountText(ql, 4)
            C_Timer.After(0, StyleQuestRows)   -- 게임이 뒤늦게 다시 칠하는 것까지
        end)
    end
    TintCountText(ql, 4)
    if sf then sf:HookScript("OnShow", StyleQuestRows) end
    StyleQuestRows()
    -- 지도 위 작은 버튼들(필터·고정 핀·옆 패널)도 분홍 톤으로
    for _, k in ipairs({ "WorldMapTrackingOptionsButton", "WorldMapTrackingPinButton", "SidePanelToggle" }) do
        local b = WorldMapFrame[k]
        if b then TintTree(b, C.accHi, 2) end
    end
end

----------------------------------------------------------------------
-- 아래 좌표 줄 + 지역 레벨 알약(마우스 옆)
----------------------------------------------------------------------
local function Fmt(x, y)
    local ok, s = pcall(function()
        if not x or not y or x <= 0 or y <= 0 or x >= 1 or y >= 1 then return nil end
        return ("%.1f, %.1f"):format(x * 100, y * 100)
    end)
    return ok and s or nil
end

local function PlayerXY(mapID)
    local ok, x, y = pcall(function()
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then return pos:GetXY() end
    end)
    if ok then return Fmt(x, y) end
end

local function CreateCoords()
    local wm = WorldMapFrame
    local sc = wm and wm.ScrollContainer
    if not sc or coords then return end
    coords = CreateFrame("Frame", nil, wm)
    coords:SetFrameStrata("HIGH")
    coords:SetFrameLevel(wm.BorderFrame:GetFrameLevel() + 12)
    coords:SetHeight(22)
    coords:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 0, 0)
    coords:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT", 0, 0)
    local bg = coords:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.10, 0.075, 0.07, 0.96)   -- 다른 애드온 좌표 글자가 비치지 않게 거의 불투명

    coords.meL = Font(coords, 12, C.tx2); coords.meL:SetText("내 위치")
    coords.meL:SetPoint("LEFT", 10, 0)
    coords.me = Font(coords, 15, C.tx, NUM)
    coords.me:SetPoint("LEFT", coords.meL, "RIGHT", 5, 0)
    coords.cur = Font(coords, 15, C.tx, NUM)
    coords.cur:SetPoint("RIGHT", -44, 0)   -- 오른쪽 아래 지도 도움말(?) 버튼 피해서
    coords.curL = Font(coords, 12, C.tx2); coords.curL:SetText("마우스")
    coords.curL:SetPoint("RIGHT", coords.cur, "LEFT", -5, 0)

    -- 마우스 옆 레벨 알약
    tip = CreateFrame("Frame", nil, UIParent)
    tip:SetFrameStrata("TOOLTIP")
    tip:SetSize(150, 40)
    local tbg = RoundTex(tip, "BACKGROUND", 0, "panel", C.plate); tbg:SetAllPoints()
    local trim = RoundTex(tip, "BORDER", 0, "rim", C.acc, 0.65); trim:SetAllPoints()
    tip.name = Font(tip, 13, C.tx)
    tip.name:SetPoint("TOPLEFT", 10, -7)
    tip.lv = Font(tip, 15, C.acc, NUM)
    tip.lv:SetPoint("LEFT", tip.name, "RIGHT", 7, 0)
    tip.hint = Font(tip, 11, C.tx2)
    tip.hint:SetPoint("TOPLEFT", tip.name, "BOTTOMLEFT", 0, -2)
    tip:Hide()

    local t = 0
    coords:SetScript("OnUpdate", function(self, el)
        -- OpenMap이 있으면 그쪽 좌표 줄을 써요 (이어 붙인 지도에서 우리 좌표는 맞지 않음)
        if _G.OpenMapAPI then self:Hide() return end
        t = t + el
        if t < 0.05 then return end
        t = 0
        local mapID = wm:GetMapID()
        coords.me:SetText(PlayerXY(mapID) or "-")
        local cx, cy
        if sc:IsMouseOver() then cx, cy = wm:GetNormalizedCursorPosition() end
        coords.cur:SetText(Fmt(cx, cy) or "-")

        -- 지역 레벨 알약
        local shown = false
        if db.levels and cx and wm.IsCanvasMouseFocus and wm:IsCanvasMouseFocus() then
            local ok, info = pcall(C_Map.GetMapInfoAtPosition, mapID, cx, cy)
            if ok and info and info.mapID ~= mapID then
                local minL, maxL = Levels(info.mapID)
                if minL then
                    local c, hint = Difficulty(minL, maxL)
                    tip.name:SetText(info.name or "")
                    tip.lv:SetText(LevelText(minL, maxL))
                    tip.lv:SetTextColor(c[1], c[2], c[3])
                    tip.hint:SetText(hint)
                    tip:SetWidth(math.max(tip.name:GetStringWidth() + tip.lv:GetStringWidth() + 30, tip.hint:GetStringWidth() + 22))
                    local s = UIParent:GetEffectiveScale()
                    local x, y = GetCursorPosition()
                    tip:ClearAllPoints()
                    tip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / s + 16, y / s + 6)
                    shown = true
                end
            end
        end
        tip:SetShown(shown)
    end)
    coords:SetScript("OnHide", function() if tip then tip:Hide() end end)
    coords:SetShown(db.coords)
end

----------------------------------------------------------------------
-- 작은 창 / 걸을 때 흐림
----------------------------------------------------------------------
-- 걸을 때 흐림: 블리자드 흐림 장치는 빼고(다른 애드온 설정과 싸우지 않게) 우리가 직접
local fader
local function ApplyFade()
    local wm = WorldMapFrame
    if not wm then return end
    if PlayerMovementFrameFader then pcall(PlayerMovementFrameFader.RemoveFrame, wm) end
    if not fader then
        fader = CreateFrame("Frame")
        fader:SetScript("OnUpdate", function(_, el)
            if not wm:IsShown() then return end
            local moving = false
            if db.fade and not wm:IsMouseOver() and not wm.leelMoving then
                local ok, m = pcall(IsPlayerMoving)
                moving = ok and m and true or false
            end
            local target = moving and db.fadeAlpha or 1
            local a = wm:GetAlpha()
            if math.abs(a - target) > 0.01 then
                wm:SetAlpha(a + (target - a) * math.min(1, el * 8))
            elseif a ~= target then
                wm:SetAlpha(target)
            end
        end)
    end
    if not db.fade then wm:SetAlpha(1) end
end

local function ApplyCVars()
    pcall(SetCVar, "miniWorldMap", db.mini and "1" or "0")
    pcall(SetCVar, "mapFade", "0")   -- 흐림은 Leel Map이 직접 함
end


----------------------------------------------------------------------
-- 지도 창 끌어서 옮기기 (작은 창일 때만, 위 제목 줄을 잡고 끌기)
-- 블리자드가 지도를 열 때마다 자리를 다시 잡으므로, 그 뒤에 저장한 자리로 되돌림
----------------------------------------------------------------------
local function IsMax()
    local wm = WorldMapFrame
    return wm.IsMaximized and wm:IsMaximized()
end

local pendingPos = false
local function RestorePos()
    local wm = WorldMapFrame
    local p = db and db.pos
    if not p or IsMax() or wm.leelMoving then return end
    -- 전투 중엔 지도(보호된 창)를 애드온이 옮기면 막히고, 그 여파로 ESC 닫기까지 꼬임 → 전투 끝나고 옮김
    if InCombatLockdown() then pendingPos = true return end
    pendingPos = false
    wm:ClearAllPoints()
    wm:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p[1], p[2])
end

local function SetupMover()
    local wm = WorldMapFrame
    local bf = wm.BorderFrame
    if not bf or wm.leelMover then return end
    local m = CreateFrame("Frame", nil, bf)
    wm.leelMover = m
    m:SetFrameLevel(bf:GetFrameLevel() + 20)
    m:SetPoint("TOPLEFT", bf, "TOPLEFT", 4, 0)
    m:SetPoint("TOPRIGHT", bf, "TOPRIGHT", -70, 0)
    m:SetHeight(26)
    m:EnableMouse(true)
    m:RegisterForDrag("LeftButton")
    m:SetScript("OnDragStart", function()
        if IsMax() or InCombatLockdown() then return end
        wm:SetMovable(true)
        wm:SetClampedToScreen(true)
        wm.leelMoving = true
        wm:StartMoving()
    end)
    m:SetScript("OnDragStop", function()
        wm:StopMovingOrSizing()
        wm.leelMoving = false
        local x, y = wm:GetCenter()
        if x then
            db.pos = { math.floor(x + 0.5), math.floor(y + 0.5) }
            RestorePos()
        end
    end)
    m:SetScript("OnEnter", function(self)
        if IsMax() then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("끌어서 지도 옮기기", 1, 1, 1)
        GameTooltip:AddLine("/lmap 위치 : 처음 자리로", C.tx2[1], C.tx2[2], C.tx2[3])
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if wm.SynchronizeDisplayState then hooksecurefunc(wm, "SynchronizeDisplayState", RestorePos) end
    -- 전투가 끝나면 미뤄 둔 자리 맞추기
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function() if pendingPos and wm:IsShown() then RestorePos() end end)
end

local function Setup()
    if not WorldMapFrame or WorldMapFrame.leelSetup then return end
    WorldMapFrame.leelSetup = true
    if db.skin then
        local ok, err = pcall(Skin)
        if not ok then
            ns_skinErr = tostring(err)
            Print("지도 꾸미기 오류: " .. ns_skinErr)
        end
    end
    local ok, err = pcall(CreateCoords)
    if not ok then Print("좌표 줄 오류: " .. tostring(err)) end
    local okm, errm = pcall(SetupMover)
    if not okm then Print("지도 옮기기 오류: " .. tostring(errm)) end
    -- 블리자드가 지도를 열 때 흐림(0.5)을 등록하므로, 그 뒤에 우리 값으로 다시 등록
    WorldMapFrame:HookScript("OnShow", function()
        C_Timer.After(0, ApplyFade)
        C_Timer.After(0, RestorePos)
        UpdateHeader()
    end)
end


----------------------------------------------------------------------
-- Leatrix Maps 같이 쓰기: 안 가 본 곳 밝히기(연분홍)만 켜고 Leel Map과 겹치는 기능은 끔
-- Leatrix는 로그아웃 때 자기 설정을 저장하므로, 우리는 그보다 뒤(로그아웃)에 덮어씀 → 다음 접속부터 적용
-- 처음 한 번만 맞추고, 그 뒤엔 사용자가 /ltm 에서 바꾼 값을 존중
----------------------------------------------------------------------
local LEATRIX_V = 1
local LEATRIX_SET = {
    RevealMap = "On", RevTint = "On",
    tintRed = 1.0, tintGreen = 0.78, tintBlue = 0.85, tintAlpha = 0.85,   -- 옅은 분홍
    SimpleMapFrame = "Off",   -- 지도 창 모양은 Leel Map이
    EnableMovement = "Off",   -- 옮기기도 Leel Map이
    UnlockMap = "Off", ScaleWorldMap = "Off",
    NoMapFade = "Off",        -- 걸을 때 흐림은 Leel Map이
    ShowCoords = "Off",       -- 좌표 줄도 Leel Map이
    ShowZoneLevels = "Off",   -- 지역 레벨 알약도 Leel Map이
    ShowZoneMenu = "Off",     -- 제목 줄 지역 메뉴는 길 표시 알약과 겹침
    ShowMinimapIcon = "Off",  -- 미니맵 버튼 하나 줄이기 (/ltm 으로 열 수 있음)
}

local function LeatrixInstalled()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Leatrix_Maps")
end

local function LeatrixPending()
    return LeatrixInstalled() and (db.leatrixV or 0) < LEATRIX_V
end

local function WriteLeatrix()
    if not LeatrixPending() or type(LeaMapsDB) ~= "table" then return end
    for k, v in pairs(LEATRIX_SET) do LeaMapsDB[k] = v end
    db.leatrixV = LEATRIX_V
end

----------------------------------------------------------------------
-- OpenMap(이어 붙인 세계 지도, 따로 설치)을 같이 쓰면: 지도 기능만 쓰고 겹치는 것은 끔 (처음 한 번)
--   친구·길드 위치(르엘 길드원 위치와 겹침), 내 위치 공유, 핀 공유, 처음 묻는 창들
----------------------------------------------------------------------
local OPENMAP_V = 3
local OPENMAP_SET = {
    friends = false, guild = false, friendsShare = false, shareAsked = true,
    pinsShared = false, presetAsked = true, minimapButton = false,
    mapButtons = false,   -- 지도 위 OpenMap 단추·즐겨찾기 줄 (설정 창 여는 곳)
    -- 던전 지도 · 우두머리/퀘스트/전리품 옆 칸 끔 (던전 정보는 NeedRoll 같은 따로 애드온으로)
    dungeonMaps = false, dungeonBosses = false, dungeonQuests = false, dungeonCard = false,
}
local function OpenMapInstalled()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("OpenMap")
end
-- 접속할 때마다 맞춰 두고(설정이 안 보이게), 처음 한 번만 "다시 불러오기"를 물어요
local function TuneOpenMap()
    if not OpenMapInstalled() then return false end
    local w = type(OpenMapDB) == "table" and OpenMapDB.worldmap
    if type(w) ~= "table" then return false end
    for k, v in pairs(OPENMAP_SET) do w[k] = v end
    if (db.openmapV or 0) >= OPENMAP_V then return false end
    db.openmapV = OPENMAP_V
    return true
end

-- 미니맵 애드온 목록(나침반 단추)에서 OpenMap 칸을 빼요 (설정 창 여는 곳이라)
local function HideOpenMapEntry()
    if not OpenMapInstalled() then return end
    local comp = _G.AddonCompartmentFrame
    local list = comp and comp.registeredAddons
    if type(list) ~= "table" then return end
    local changed = false
    for i = #list, 1, -1 do
        local d = list[i]
        local t = type(d) == "table" and tostring(d.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower() or ""
        if t:find("openmap", 1, true) then table.remove(list, i); changed = true end
    end
    if changed and comp.UpdateDisplay then pcall(comp.UpdateDisplay, comp) end
end

StaticPopupDialogs["LEELMAP_OPENMAP"] = {
    text = "|cfff2b3c2Leel Map|r\n\nOpenMap을 찾았어요.\n이어 붙인 지도는 그대로 쓰고, OpenMap 설정 단추와 르엘 UI와 겹치는 기능(친구·길드 위치, 위치 공유, 핀 공유, 던전 지도 옆 칸)은 숨겼어요.\n\n지금 다시 불러올까요?",
    button1 = "다시 불러오기",
    button2 = "나중에",
    OnAccept = function() ReloadUI() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["LEELMAP_LEATRIX"] = {
    text = "|cfff2b3c2Leel Map|r\n\nLeatrix Maps를 찾았어요.\n안 가 본 곳 밝히기(연분홍)를 켜고, 겹치는 기능은 Leel Map 쪽으로 맞출게요.\n\n지금 다시 불러올까요?",
    button1 = "다시 불러오기",
    button2 = "나중에",
    OnAccept = function() ReloadUI() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

----------------------------------------------------------------------
-- 로딩 + 명령어
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            LeelMapDB = LeelMapDB or {}
            for k, v in pairs(defaults) do
                if LeelMapDB[k] == nil then LeelMapDB[k] = v end
            end
            db = LeelMapDB
            -- v2: 꾸미기가 꺼진 채로 저장된 경우 한 번 다시 켬
            if (db.v or 1) < 2 then db.skin = true; db.v = 2 end
        elseif arg1 == "Blizzard_WorldMap" and db then
            Setup()
        end
    elseif event == "PLAYER_LOGIN" then
        ApplyCVars()
        Setup()
        if LeatrixPending() then C_Timer.After(3, function() StaticPopup_Show("LEELMAP_LEATRIX") end)
        elseif TuneOpenMap() then C_Timer.After(3, function() StaticPopup_Show("LEELMAP_OPENMAP") end) end
        for _, t in ipairs({ 1, 4, 10 }) do C_Timer.After(t, HideOpenMapEntry) end
    elseif event == "PLAYER_LOGOUT" then
        WriteLeatrix()
    elseif event == "PLAYER_LEVEL_UP" then
        UpdateHeader()
    end
end)

SLASH_LEELMAP1 = "/lmap"
SLASH_LEELMAP2 = "/르엘맵"
SlashCmdList.LEELMAP = function(msg)
    local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
    if cmd == "작게" or cmd == "mini" then
        db.mini = not db.mini; ApplyCVars()
        Print("작은 창 지도 " .. (db.mini and "켬" or "끔") .. " (지도를 다시 열면 적용)")
    elseif cmd == "흐림" or cmd == "fade" then
        local n = tonumber(arg)
        if n then
            if n > 1 then n = n / 100 end
            db.fadeAlpha = math.min(0.9, math.max(0.1, n)); db.fade = true
        else
            db.fade = not db.fade
        end
        ApplyCVars(); ApplyFade()
        Print("걸을 때 흐림 " .. (db.fade and ("켬 (" .. math.floor(db.fadeAlpha * 100 + 0.5) .. "%)") or "끔"))
    elseif cmd == "좌표" or cmd == "coords" then
        db.coords = not db.coords
        if coords then coords:SetShown(db.coords) end
        Print("좌표 줄 " .. (db.coords and "켬" or "끔"))
    elseif cmd == "레벨" or cmd == "levels" then
        db.levels = not db.levels
        UpdateHeader()
        Print("지역 레벨 표시 " .. (db.levels and "켬" or "끔"))
    elseif cmd == "길드" or cmd == "guild" then
        local G = _G.LeelMapGuild
        if arg == "끔" or arg == "off" then LeelMapDB.gShare = false; if G then G.Send() end; Print("내 위치 길드에 알리기 끔")
        elseif arg == "켬" or arg == "on" then LeelMapDB.gShare = true; if G then G.Send() end; Print("내 위치 길드에 알리기 켬")
        elseif (arg == "시험" or arg == "test") and G then G.Test()
        elseif G then G.List() end
    elseif cmd == "위치" or cmd == "reset" then
        db.pos = nil
        if WorldMapFrame and WorldMapFrame:IsShown() then HideUIPanel(WorldMapFrame) end
        Print("지도 자리를 처음대로 돌렸어요. 지도를 다시 열어 보세요.")
    elseif cmd == "꾸미기" or cmd == "skin" then
        db.skin = not db.skin
        Print("지도 창 꾸미기 " .. (db.skin and "켬" or "끔") .. " (/reload 후 적용)")
    elseif cmd == "점검" or cmd == "debug" then
        -- 지도 창 구조 확인 (포에버 지도 테두리가 어떤 부품으로 되어 있는지)
        local wm = WorldMapFrame
        local bf = wm and wm.BorderFrame
        Print(("꾸미기=%s 적용=%s 오류=%s"):format(tostring(db.skin), tostring(wm and wm.leelSkinned), tostring(ns_skinErr)))
        local function dump(label, fr)
            if not fr then Print(label .. ": 없음") return end
            local keys = {}
            for k, v in pairs(fr) do
                if type(k) == "string" and type(v) == "table" and v.GetObjectType then
                    local ok, t = pcall(v.GetObjectType, v)
                    local shown = v.IsShown and v:IsShown() and "보임" or "숨김"
                    keys[#keys + 1] = k .. "(" .. (ok and t or "?") .. "," .. shown .. ")"
                end
            end
            table.sort(keys)
            Print(label .. ": " .. table.concat(keys, " "))
        end
        dump("WorldMapFrame", wm)
        dump("BorderFrame", bf)
        dump("QuestLog", wm and wm.QuestLog)
        dump("NavBar", wm and (wm.NavBar or wm.navBar))
        if bf then
            local regs = {}
            for _, r in ipairs({ bf:GetRegions() }) do
                local ok, tex = pcall(function() return r.GetTexture and r:GetTexture() or r:GetObjectType() end)
                regs[#regs + 1] = tostring(ok and tex or "?")
            end
            Print("BorderFrame 그림 " .. #regs .. "개: " .. table.concat(regs, " "))
        end
    else
        Print("/lmap 작게 · 흐림 (또는 흐림 40) · 좌표 · 레벨 · 위치 · 꾸미기 · 점검")
    end
end
