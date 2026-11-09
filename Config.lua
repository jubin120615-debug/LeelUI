-- LeelUI / Config.lua
-- 설정 창: 위치, 크기 슬라이더, 표시 토글 (미니맵 아이콘 좌클릭 또는 /leel)

local _, ns = ...
local C = ns.C

local W = 370
local PAD = 16

----------------------------------------------------------------------
-- 부품
----------------------------------------------------------------------
local function Line(parent, y)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(0.839, 0.627, 0.612, 0.18)
    t:SetHeight(1)
    t:SetPoint("TOPLEFT", 0, y)
    t:SetPoint("TOPRIGHT", 0, y)
    return t
end

local function Heading(parent, text, y)
    local fs = ns.Font(parent, 12, C.tx2)
    fs:SetText(text)
    fs:SetPoint("TOPLEFT", PAD, y)
    return fs
end

-- 슬라이더: 이름 + 큰 숫자 + 얇은 트랙
local function MakeSlider(parent, label, minV, maxV, y, get, set)
    local box = CreateFrame("Frame", nil, parent)
    box:SetPoint("TOPLEFT", PAD, y)
    box:SetPoint("TOPRIGHT", -PAD, y)
    box:SetHeight(52)

    local name = ns.Font(box, 13)
    name:SetText(label)
    name:SetPoint("TOPLEFT", 0, -2)
    local val = ns.Num(box, 18, C.accHi)
    val:SetPoint("TOPRIGHT", 0, 0)

    local s = CreateFrame("Slider", nil, box)
    s:SetOrientation("HORIZONTAL")
    s:SetHeight(18)
    s:SetPoint("TOPLEFT", 0, -22)
    s:SetPoint("TOPRIGHT", 0, -22)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(1)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)

    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(1, 1, 1, 0.14)
    track:SetHeight(4)
    track:SetPoint("LEFT"); track:SetPoint("RIGHT")
    local fill = s:CreateTexture(nil, "BORDER")
    fill:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 1)
    fill:SetHeight(4)
    fill:SetPoint("LEFT")
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(ns.MEDIA .. "circle")
    thumb:SetVertexColor(C.tx[1], C.tx[2], C.tx[3], 1)
    thumb:SetSize(14, 14)
    s:SetThumbTexture(thumb)

    local lo = ns.Num(box, 11, C.tx2, false); lo:SetText(minV); lo:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -1)
    local mid = ns.Num(box, 11, C.tx2, false); mid:SetText(100)
    mid:SetPoint("TOP", s, "BOTTOMLEFT", (100 - minV) / (maxV - minV) * (W - PAD * 2), -1)
    local hi = ns.Num(box, 11, C.tx2, false); hi:SetText(maxV); hi:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, -1)

    local function Show(v)
        val:SetFormattedText("%d%%", v)
        fill:SetWidth(math.max(1, (v - minV) / (maxV - minV) * (W - PAD * 2)))
    end

    s:SetScript("OnValueChanged", function(_, v, user)
        v = math.floor(v + 0.5)
        Show(v)
        if user then set(v) end
    end)
    s:SetScript("OnMouseWheel", function(self, d)
        local v = math.min(maxV, math.max(minV, self:GetValue() + d * 5))
        self:SetValue(v)
        set(v)
    end)

    function box:Refresh()
        local v = get()
        s:SetValue(v)
        Show(v)
    end
    return box
end

-- 스위치: 이름 + 오른쪽 토글
local function MakeToggle(parent, label, y, get, set)
    local row = CreateFrame("Button", nil, parent)
    row:SetPoint("TOPLEFT", PAD, y)
    row:SetPoint("TOPRIGHT", -PAD, y)
    row:SetHeight(30)

    local name = ns.Font(row, 13)
    name:SetText(label)
    name:SetPoint("LEFT")

    local sw = CreateFrame("Frame", nil, row)
    sw:SetSize(36, 18)
    sw:SetPoint("RIGHT")
    local bg = ns.RoundRect(sw, 9, nil, "BACKGROUND", 0, 0)
    local knob = sw:CreateTexture(nil, "ARTWORK"); knob:SetSize(12, 12)
    knob:SetTexture(ns.MEDIA .. "circle")

    function row:Refresh()
        local on = get()
        if on then
            bg:SetColor(C.acc, 1)
            knob:SetVertexColor(C.ink[1], C.ink[2], C.ink[3], 1)
            knob:ClearAllPoints(); knob:SetPoint("RIGHT", -3, 0)
        else
            bg:SetColor({ 1, 1, 1 }, 0.14)
            knob:SetVertexColor(C.tx2[1], C.tx2[2], C.tx2[3], 1)
            knob:ClearAllPoints(); knob:SetPoint("LEFT", 3, 0)
        end
    end
    row:SetScript("OnClick", function(self)
        set(not get())
        self:Refresh()
    end)
    row:SetScript("OnEnter", function() name:SetTextColor(1, 1, 1) end)
    row:SetScript("OnLeave", function() name:SetTextColor(C.tx[1], C.tx[2], C.tx[3]) end)
    return row
end

----------------------------------------------------------------------
-- 창
----------------------------------------------------------------------
local panel

local function Build()
    local f = CreateFrame("Frame", "LeelUI_Config", UIParent)
    f:SetSize(W, 10)
    f:SetPoint("CENTER", 120, 40)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "LeelUI_Config")   -- ESC로 닫기

    ns.RoundPlate(f, 16, { 0.184, 0.145, 0.133, 0.97 }, { 0.839, 0.627, 0.612, 0.45 })

    -- 제목
    local title = ns.Font(f, 15)
    title:SetText("|cfff2b3c2르엘|r UI")
    title:SetPoint("TOPLEFT", PAD, -16)
    local ver = ns.Num(f, 13, C.tx2, false)
    ver:SetText("v" .. (ns.VERSION or ""))
    ver:SetPoint("LEFT", title, "RIGHT", 10, -1)

    local close = CreateFrame("Button", nil, f)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -10, -12)
    for _, r in ipairs({ 45, -45 }) do
        local t = close:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(C.tx2[1], C.tx2[2], C.tx2[3], 1)
        t:SetSize(14, 2)
        t:SetPoint("CENTER")
        t:SetRotation(math.rad(r))
        close[r] = t
    end
    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function(self) for _, r in ipairs({ 45, -45 }) do self[r]:SetColorTexture(1, 1, 1, 1) end end)
    close:SetScript("OnLeave", function(self) for _, r in ipairs({ 45, -45 }) do self[r]:SetColorTexture(C.tx2[1], C.tx2[2], C.tx2[3], 1) end end)

    Line(f, -48)

    -- 위치
    local y = -64
    Heading(f, "위치", y)
    y = y - 22
    f.moveBtn = ns.MakeButton(f, "이동 모드", true, function() ns:ToggleMoveMode() end, 96)
    f.moveBtn:SetPoint("TOPLEFT", PAD, y)
    local reset = ns.MakeButton(f, "위치 초기화", false, function()
        ns:ResetPosition()
        ns.Print("HUD 위치를 처음대로 돌렸어요.")
    end)
    reset:SetPoint("LEFT", f.moveBtn, "RIGHT", 8, 0)
    y = y - 36
    f.layoutBtn = ns.MakeButton(f, "", false, function()
        ns:CyclePartyLayout()
        ns:RefreshConfig()
    end, 96)
    f.layoutBtn:SetPoint("TOPLEFT", PAD, y)
    local preset = ns.MakeButton(f, "파티 위치 초기화", false, function()
        ns:ResetPartyPosition()
        ns.Print("파티 프레임 위치를 처음대로 돌렸어요.")
    end)
    preset:SetPoint("LEFT", f.layoutBtn, "RIGHT", 8, 0)
    y = y - 44

    -- 크기
    Heading(f, "크기", y)
    y = y - 24
    f.hudScale = MakeSlider(f, "위쪽 HUD", 50, 150, y,
        function() return math.floor((ns.db.scale or 0.7) * 100 + 0.5) end,
        function(v)
            ns:SetHudScale(v / 100)
            if InCombatLockdown() then ns.Print("전투가 끝나면 HUD 크기가 바뀌어요.") end
        end)
    y = y - 62
    f.npScale = MakeSlider(f, "적 이름표", 40, 150, y,
        function() return math.floor((ns.db.npScale or 1) * 100 + 0.5) end,
        function(v)
            ns.db.npScale = v / 100
            if ns.RefreshNameplates then ns:RefreshNameplates() end
        end)
    y = y - 62
    f.partyScale = MakeSlider(f, "파티 프레임", 50, 150, y,
        function() return math.floor((ns.db.partyScale or 0.75) * 100 + 0.5) end,
        function(v)
            ns:SetPartyScale(v / 100)
            if InCombatLockdown() then ns.Print("전투가 끝나면 파티 프레임 크기가 바뀌어요.") end
        end)
    y = y - 70

    -- 표시
    Heading(f, "표시", y)
    y = y - 20
    local toggles = {
        { "기본 플레이어/대상 창 숨기기",
          function() return ns.db.hideBlizzard end,
          function(v) ns.db.hideBlizzard = v; ns.Print("기본 창 설정은 /reload 후 적용돼요.") end },
        { "적 이름표 바꾸기",
          function() return ns.db.nameplates end,
          function(v) ns.db.nameplates = v; ns.Print("이름표 설정은 /reload 후 적용돼요.") end },
        { "적 이름표 퀘스트 원 (Questie)",
          function() return ns.db.questCircle ~= false end,
          function(v) ns.db.questCircle = v; if ns.RefreshNameplates then ns:RefreshNameplates() end end },
        { "파티 프레임 쓰기",
          function() return ns.db.party end,
          function(v) ns.db.party = v; ns.Print("파티 프레임 설정은 /reload 후 적용돼요.") end },
        { "기본 파티 창 숨기기",
          function() return ns.db.partyHideBlizzard ~= false end,
          function(v) ns.db.partyHideBlizzard = v; ns.Print("기본 파티 창 설정은 /reload 후 적용돼요.") end },
        { "미니맵 아이콘",
          function() return not ns.db.minimap.hide end,
          function(v)
              ns:SetMinimapShown(v)
              if not v then ns.Print("아이콘을 숨겼어요. 미니맵 옆 애드온 목록이나 /leel 로 열 수 있어요.") end
          end },
        { "아이콘 위치 잠금",
          function() return ns.db.minimap.lock end,
          function(v) ns:SetMinimapLocked(v) end },
        { "이동할 때 격자에 맞추기",
          function() return ns.db.grid end,
          function(v) ns.db.grid = v end },
    }
    f.toggles = {}
    for _, t in ipairs(toggles) do
        local row = MakeToggle(f, t[1], y, t[2], t[3])
        tinsert(f.toggles, row)
        y = y - 32
    end

    y = y - 8
    Line(f, y)
    local foot = ns.Font(f, 11, C.tx2)
    foot:SetText("채팅창에 |cfff6ece8/leel|r 를 입력해도 이 창이 열려요")
    foot:SetPoint("TOPLEFT", PAD, y - 12)
    f:SetHeight(-(y - 38))

    f:SetScript("OnShow", function() ns:RefreshConfig() end)
    f:Hide()
    return f
end

function ns:RefreshConfig()
    if not panel or not panel:IsShown() then return end
    panel.moveBtn:SetLabel(ns.moving and "이동 모드 끄기" or "이동 모드")
    panel.hudScale:Refresh()
    panel.npScale:Refresh()
    panel.partyScale:Refresh()
    panel.layoutBtn:SetLabel("파티 배치: " .. ((ns.PARTY_LAYOUT_NAMES or {})[ns.db.partyLayout or "row"] or "가로 줄"))
    for _, row in ipairs(panel.toggles) do row:Refresh() end
end

function ns:ToggleConfig()
    panel = panel or Build()
    panel:SetShown(not panel:IsShown())
end
