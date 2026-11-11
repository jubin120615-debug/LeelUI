-- LeelUI / Move.lua
-- 이동 모드: 노란 테두리 + 드래그, 격자 스냅, 방향키 1px(Shift 10px), 전투 시작하면 자동 종료

local _, ns = ...
local C = ns.C

local SNAP = 8

----------------------------------------------------------------------
-- 위치 저장/적용 (화면 왼쪽 아래 기준 중심점 → 크기를 바꿔도 제자리)
----------------------------------------------------------------------
function ns:ApplyPosition()
    local p = ns.db.point
    ns.hud:ClearAllPoints()
    ns.hud:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function SaveCenter(x, y)
    ns.db.point = { "CENTER", "BOTTOMLEFT", math.floor(x + 0.5), math.floor(y + 0.5) }
    ns:ApplyPosition()
end

local function CurrentCenter()
    local x, y = ns.hud:GetCenter()
    return x, y
end

-- 크기를 바꿔도 화면 위치는 그대로
function ns:SetHudScale(v)
    ns:RunOutOfCombat("hudscale", function()
        local hud = ns.hud
        local cx, cy = hud:GetCenter()
        local s0 = hud:GetScale()
        hud:SetScale(v)
        ns.db.scale = v
        if cx then SaveCenter(cx * s0 / v, cy * s0 / v) end
    end)
end

function ns:ResetPosition()
    ns:RunOutOfCombat("reset", function()
        ns.db.point = CopyTable(ns.defaults.point)
        ns:ApplyPosition()
        -- 따로 옮긴 조각(내 창 · 거리 · 대상 창)도 제자리로
        ns.db.hudParts = nil
        if ns.ApplyHudParts then ns:ApplyHudParts() end
    end)
end

local function Nudge(dx, dy)
    if InCombatLockdown() then return end
    local x, y = CurrentCenter()
    if x then SaveCenter(x + dx, y + dy) end
end

----------------------------------------------------------------------
-- 화면 격자
----------------------------------------------------------------------
local grid
local function ShowGrid(show)
    if show and not grid then
        grid = CreateFrame("Frame", nil, UIParent)
        grid:SetAllPoints()
        grid:SetFrameStrata("BACKGROUND")
        local w, h = UIParent:GetSize()
        local step = 32
        for x = 0, w, step do
            local t = grid:CreateTexture(nil, "BACKGROUND")
            t:SetColorTexture(1, 1, 1, 0.06)
            t:SetSize(1, h)
            t:SetPoint("TOPLEFT", x, 0)
        end
        for y = 0, h, step do
            local t = grid:CreateTexture(nil, "BACKGROUND")
            t:SetColorTexture(1, 1, 1, 0.06)
            t:SetSize(w, 1)
            t:SetPoint("TOPLEFT", 0, -y)
        end
        local cv = grid:CreateTexture(nil, "BORDER")
        cv:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.35)
        cv:SetSize(1, h); cv:SetPoint("TOP", 0, 0)
        local ch = grid:CreateTexture(nil, "BORDER")
        ch:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.35)
        ch:SetSize(w, 1); ch:SetPoint("LEFT", 0, 0)
    end
    if grid then grid:SetShown(show) end
end

----------------------------------------------------------------------
-- 작은 버튼 (설정 창과 같은 모양)
----------------------------------------------------------------------
function ns.MakeButton(parent, text, primary, onClick, minW)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(28)
    b.fillR, b.edgeR = ns.RoundPlate(b, 14)
    local fs = ns.Font(b, 13, primary and C.ink or C.tx)
    fs:SetShadowColor(0, 0, 0, primary and 0 or 0.85)
    fs:SetPoint("CENTER")
    b.fs, b.primary = fs, primary

    function b:Paint(hover)
        if self.primary then
            local c = hover and C.accHi or C.acc
            self.fillR:SetColor(c, 1); self.edgeR:SetColor(c, 1)
        else
            self.fillR:SetColor(hover and { 0.27, 0.2, 0.19 } or C.plate, hover and 0.95 or C.plate[4])
            self.edgeR:SetColor(hover and C.acc or C.edge, hover and 0.8 or C.edge[4])
        end
    end
    function b:SetLabel(t)
        self.fs:SetText(t)
        self:SetWidth(math.max(minW or 0, self.fs:GetStringWidth() + 32))
    end

    b:SetScript("OnEnter", function(self) self:Paint(true) end)
    b:SetScript("OnLeave", function(self) self:Paint(false) end)
    b:SetScript("OnClick", onClick)
    b:Paint(false)
    b:SetLabel(text)
    return b
end

----------------------------------------------------------------------
-- 이동 모드 겹침 화면
----------------------------------------------------------------------
function ns:CreateMover(hud)
    local m = CreateFrame("Frame", nil, hud)
    m:SetAllPoints()
    m:SetFrameStrata("DIALOG")
    m:EnableMouse(true)
    m:RegisterForDrag("LeftButton")

    local tint = m:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints()
    tint:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.07)
    m.look = { tint }
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = m:CreateTexture(nil, "BORDER")
        m.look[#m.look + 1] = e
        e:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 1)
        if side == "TOP" or side == "BOTTOM" then
            e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(3)
        else
            e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(3)
        end
    end

    m:SetScript("OnDragStart", function()
        if not InCombatLockdown() then hud:StartMoving() end
    end)
    m:SetScript("OnDragStop", function()
        hud:StopMovingOrSizing()
        local x, y = hud:GetCenter()
        if ns.db.grid then
            x = math.floor(x / SNAP + 0.5) * SNAP
            y = math.floor(y / SNAP + 0.5) * SNAP
        end
        SaveCenter(x, y)
    end)

    -- 방향키 미세 이동 (나머지 키는 게임으로 넘김)
    m:EnableKeyboard(true)
    m:SetScript("OnKeyDown", function(self, key)
        local d = IsShiftKeyDown() and 10 or 1
        local moves = { LEFT = { -d, 0 }, RIGHT = { d, 0 }, UP = { 0, d }, DOWN = { 0, -d } }
        if moves[key] then
            self:SetPropagateKeyboardInput(false)
            Nudge(moves[key][1], moves[key][2])
        elseif key == "ESCAPE" or key == "ENTER" then
            self:SetPropagateKeyboardInput(false)
            ns:SetMoveMode(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    -- 아래 도구 막대 (HUD 크기와 상관없이 원래 크기)
    local bar = CreateFrame("Frame", nil, UIParent)
    bar:SetFrameStrata("DIALOG")
    bar:SetHeight(28)
    -- 화면 맨 위 가운데에 따로 둬서 옮길 창들과 안 겹치게 (글씨 칸을 끌면 막대도 옮겨져요)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    local bp = ns.db.moveBarPos
    if bp then bar:SetPoint(bp[1], UIParent, bp[2], bp[3], bp[4])
    else bar:SetPoint("TOP", UIParent, "TOP", 0, -12) end

    local chip = CreateFrame("Frame", nil, bar)
    chip:SetHeight(28)
    chip:SetPoint("LEFT")
    ns.RoundPlate(chip, 14)
    local cfs = ns.Font(chip, 13)
    cfs:SetPoint("LEFT", 14, 0)
    cfs:SetText("이동 모드: 토끼 끌기 = 다 같이, 조각 끌기 = 그것만, 토끼 오른쪽 클릭 = 메뉴 · 이 칸을 끌면 막대 이동")
    chip:SetWidth(cfs:GetStringWidth() + 28)
    chip:EnableMouse(true)
    chip:RegisterForDrag("LeftButton")
    chip:SetScript("OnDragStart", function() bar:StartMoving() end)
    chip:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        local pt, _, rp, x, y = bar:GetPoint()
        ns.db.moveBarPos = { pt, rp, x, y }
    end)

    local done = ns.MakeButton(bar, "완료", true, function() ns:SetMoveMode(false) end)
    done:SetPoint("LEFT", chip, "RIGHT", 8, 0)

    local gridBtn
    gridBtn = ns.MakeButton(bar, "", false, function()
        ns.db.grid = not ns.db.grid
        ShowGrid(ns.db.grid)
        gridBtn:SetLabel(ns.db.grid and "격자 끄기" or "격자 켜기")
    end)
    gridBtn:SetPoint("LEFT", done, "RIGHT", 8, 0)
    bar.gridBtn = gridBtn
    local joinBtn = ns.MakeButton(bar, "HUD 모으기", false, function() ns:ResetHudParts() end)
    joinBtn:SetPoint("LEFT", gridBtn, "RIGHT", 8, 0)

    local arrows = { { "RIGHT", 1, 0, ">" }, { "DOWN", 0, -1, "v" },
                     { "UP", 0, 1, "^" }, { "LEFT", -1, 0, "<" } }
    local prev
    for _, a in ipairs(arrows) do
        local b = ns.MakeButton(bar, a[4], false, function()
            local d = IsShiftKeyDown() and 10 or 1
            Nudge(a[2] * d, a[3] * d)
        end, 28)
        b.fs:SetFont(ns.NUM, 16, "")
        b:SetWidth(28)
        if prev then b:SetPoint("RIGHT", prev, "LEFT", -4, 0) else b:SetPoint("RIGHT") end
        prev = b
    end

    -- 막대 폭 = 글씨 칸 + 완료 + 격자 + 방향 버튼들
    local w = chip:GetWidth() + 8 + done:GetWidth() + 8 + math.max(gridBtn:GetWidth(), 90) + 8 + joinBtn:GetWidth() + 24 + 4 * 28 + 3 * 4
    bar:SetWidth(math.max(w, 400))

    m:Hide(); bar:Hide()
    ns.mover, ns.moverBar = m, bar
end

----------------------------------------------------------------------
-- 켜기 / 끄기
----------------------------------------------------------------------
----------------------------------------------------------------------
-- HUD 조각 이동: 조각을 끌면 그것만, 토끼 손잡이를 끌면 셋 다 같이
----------------------------------------------------------------------
local PARTS = {
    { key = "player", point = "TOPLEFT",  dx = 0, dy = 0,   label = "내 창" },
    { key = "center", point = "TOP",      dx = 0, dy = -12, label = "거리" },
    { key = "target", point = "TOPRIGHT", dx = 0, dy = 0,   label = "대상 창" },
}

local function PartOff(key)
    ns.db.hudParts = ns.db.hudParts or {}
    return ns.db.hudParts[key]
end

function ns:ApplyHudParts()
    local fr, hud = ns.hudFrames, ns.hud
    if not (fr and hud) then return end
    ns:RunOutOfCombat("hudparts", function()
        for _, p in ipairs(PARTS) do
            local f = fr[p.key]
            if f then
                local o = PartOff(p.key) or { p.dx, p.dy }
                f:ClearAllPoints()
                f:SetPoint(p.point, hud, p.point, o[1], o[2])
            end
        end
        if ns.RefreshHudHub then ns.RefreshHudHub() end
    end)
end

function ns:ResetHudParts()
    ns.db.hudParts = nil
    ns:ApplyHudParts()
end

-- 조각을 끈 뒤: HUD 기준 자리(오프셋)로 바꿔 저장
local function SavePart(p, f)
    local hud = ns.hud
    local x, y
    if p.point == "TOPLEFT" then
        x, y = f:GetLeft() - hud:GetLeft(), f:GetTop() - hud:GetTop()
    elseif p.point == "TOPRIGHT" then
        x, y = f:GetRight() - hud:GetRight(), f:GetTop() - hud:GetTop()
    else
        x = (f:GetLeft() + f:GetRight()) / 2 - (hud:GetLeft() + hud:GetRight()) / 2
        y = f:GetTop() - hud:GetTop()
    end
    if ns.db.grid then
        x = math.floor(x / SNAP + 0.5) * SNAP
        y = math.floor(y / SNAP + 0.5) * SNAP
    end
    ns.db.hudParts = ns.db.hudParts or {}
    ns.db.hudParts[p.key] = { math.floor(x + 0.5), math.floor(y + 0.5) }
    ns:ApplyHudParts()
end

local partMovers
local function BuildPartMovers()
    if partMovers or not ns.hudFrames then return end
    partMovers = {}
    for _, p in ipairs(PARTS) do
        local f = ns.hudFrames[p.key]
        if f then
            f:SetMovable(true)
            local m = CreateFrame("Frame", nil, ns.mover)
            m:SetAllPoints(f)
            m:SetFrameLevel(ns.mover:GetFrameLevel() + 5)
            m:EnableMouse(true)
            m:RegisterForDrag("LeftButton")
            local tint = m:CreateTexture(nil, "BACKGROUND")
            tint:SetAllPoints(); tint:SetColorTexture(1, 1, 1, 0.04)
            for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
                local e = m:CreateTexture(nil, "BORDER")
                e:SetColorTexture(1, 0.95, 0.96, 0.55)
                if side == "TOP" or side == "BOTTOM" then
                    e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(1)
                else
                    e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(1)
                end
            end
            local lb = ns.Font(m, 12, C.accHi)
            lb:SetText(p.label)
            lb:SetPoint("BOTTOM", m, "TOP", 0, 2)
            m:SetScript("OnEnter", function()
                tint:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.16)
                GameTooltip:SetOwner(m, "ANCHOR_TOP")
                GameTooltip:SetText(p.label .. " 옮기기")
                GameTooltip:AddLine("끌기: 이것만 옮기기", 1, 1, 1)
                GameTooltip:AddLine("셋 다 같이는 토끼 손잡이를 끌어요", 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end)
            m:SetScript("OnLeave", function() tint:SetColorTexture(1, 1, 1, 0.04); GameTooltip:Hide() end)
            m:SetScript("OnDragStart", function(self)
                if InCombatLockdown() then return end
                self.dragging = true
                f:StartMoving()
                -- 끄는 동안 토끼 · 점선이 따라와요
                self:SetScript("OnUpdate", function() if ns.RefreshHudHub then ns.RefreshHudHub() end end)
            end)
            m:SetScript("OnDragStop", function(self)
                self:SetScript("OnUpdate", nil)
                if not self.dragging then return end
                self.dragging = false
                f:StopMovingOrSizing()
                SavePart(p, f)
            end)
            partMovers[#partMovers + 1] = m
        end
    end
end


----------------------------------------------------------------------
-- 토끼 손잡이: 끌면 셋 다 같이, 오른쪽 클릭 = 다시 모으기 · 처음 자리로
-- 붙어 있으면 HUD 위 가운데, 흩어지면 조각들 한가운데 + 점선
----------------------------------------------------------------------
local hub, hubMenu, dotLayer
local dots = {}
local DOTS_PER_LINE = 14

local function PartsJoined()
    local hp = ns.db.hudParts
    if not hp then return true end
    for _, p in ipairs(PARTS) do
        local o = hp[p.key]
        if o and (o[1] ~= p.dx or o[2] ~= p.dy) then return false end
    end
    return true
end

-- HUD 가운데 기준 상대 좌표 (HUD 크기 단위)
local function RelCenter(f)
    local hs, fs = ns.hud:GetEffectiveScale(), f:GetEffectiveScale()
    local hx, hy = ns.hud:GetCenter()
    local x, y = f:GetCenter()
    if not (hx and x) then return nil end
    return x * fs / hs - hx, y * fs / hs - hy
end

local function HubDrop()
    ns.hud:StopMovingOrSizing()
    local x, y = ns.hud:GetCenter()
    if ns.db.grid then
        x = math.floor(x / SNAP + 0.5) * SNAP
        y = math.floor(y / SNAP + 0.5) * SNAP
    end
    SaveCenter(x, y)
end

local function BuildHub()
    if hub then return end
    local m = ns.mover
    dotLayer = CreateFrame("Frame", nil, m)
    dotLayer:SetAllPoints(m)
    dotLayer:SetFrameLevel(m:GetFrameLevel() + 2)

    hub = CreateFrame("Button", nil, m)
    hub:SetSize(44, 44)
    hub:SetFrameLevel(m:GetFrameLevel() + 20)
    hub:SetClampedToScreen(true)
    local glow = hub:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(ns.MEDIA .. "circle")
    glow:SetPoint("TOPLEFT", -6, 6); glow:SetPoint("BOTTOMRIGHT", 6, -6)
    glow:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.28)
    local disc = hub:CreateTexture(nil, "BORDER")
    disc:SetTexture(ns.MEDIA .. "circle"); disc:SetAllPoints()
    disc:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    local ic = hub:CreateTexture(nil, "ARTWORK")
    ic:SetTexture(ns.MEDIA .. "bunny"); ic:SetAllPoints()
    local hl = hub:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(ns.MEDIA .. "circle"); hl:SetAllPoints(); hl:SetVertexColor(1, 1, 1, 0.22); hl:SetBlendMode("ADD")

    hub:EnableMouse(true)
    hub:RegisterForDrag("LeftButton")
    hub:RegisterForClicks("RightButtonUp")
    hub:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        if hubMenu then hubMenu:Hide() end
        self.dragging = true
        ns.hud:StartMoving()
    end)
    hub:SetScript("OnDragStop", function(self)
        if not self.dragging then return end
        self.dragging = false
        HubDrop()
    end)
    hub:SetScript("OnClick", function()
        hubMenu:SetShown(not hubMenu:IsShown())
    end)
    hub:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("HUD 다 같이 옮기기")
        GameTooltip:AddLine("끌기: 놓인 모양 그대로 셋 다 같이", 1, 1, 1)
        GameTooltip:AddLine("오른쪽 클릭: 다시 모으기 · 처음 자리로", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    hub:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 오른쪽 클릭 메뉴
    hubMenu = CreateFrame("Frame", nil, hub)
    hubMenu:SetFrameLevel(hub:GetFrameLevel() + 5)
    hubMenu:SetPoint("TOPLEFT", hub, "BOTTOMRIGHT", 4, 4)
    ns.RoundPlate(hubMenu, 12, { 0.114, 0.082, 0.078, 0.97 }, { 0.949, 0.702, 0.761, 0.8 })
    local b1 = ns.MakeButton(hubMenu, "다시 모으기", true, function()
        hubMenu:Hide(); ns:ResetHudParts()
    end, 104)
    b1:SetPoint("TOPLEFT", 6, -6)
    local b2 = ns.MakeButton(hubMenu, "처음 자리로", false, function()
        hubMenu:Hide(); ns:ResetPosition()
    end, 104)
    b2:SetPoint("TOPLEFT", b1, "BOTTOMLEFT", 0, -4)
    hubMenu:SetSize(math.max(b1:GetWidth(), b2:GetWidth()) + 12, 28 * 2 + 4 + 12)
    hubMenu:Hide()
end

local function Dot(i)
    local d = dots[i]
    if not d then
        d = dotLayer:CreateTexture(nil, "ARTWORK")
        d:SetTexture(ns.MEDIA .. "circle")
        d:SetSize(4, 4)
        d:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 0.85)
        dots[i] = d
    end
    return d
end

function ns.RefreshHudHub()
    if not (hub and ns.hud and ns.hudFrames and ns.moving) then return end
    local joined = PartsJoined()
    -- 붙어 있으면 큰 분홍 테, 떨어지면 테 대신 점선
    for _, t in ipairs(ns.mover.look or {}) do t:SetShown(joined) end
    ns.mover:EnableMouse(joined)

    local cx, cy, pts = 0, 0, {}
    for _, p in ipairs(PARTS) do
        local f = ns.hudFrames[p.key]
        if f and f:IsShown() then
            local x, y = RelCenter(f)
            if x then pts[#pts + 1] = { x, y }; cx, cy = cx + x, cy + y end
        end
    end
    local hx, hy
    if joined or #pts == 0 then
        hx, hy = 0, ns.hud:GetHeight() / 2 + 30
    else
        hx, hy = cx / #pts, cy / #pts
    end
    -- 토끼는 HUD 크기와 상관없이 원래 크기 → 좌표만 HUD 배율로 바꿔요
    hub:SetScale(1 / math.max(ns.hud:GetScale(), 0.1))
    local k = ns.hud:GetEffectiveScale() / hub:GetEffectiveScale()
    hub:ClearAllPoints()
    hub:SetPoint("CENTER", ns.mover, "CENTER", hx * k, hy * k)

    local n = 0
    if not joined then
        local r0 = 22 / k
        for _, pt in ipairs(pts) do
            local dx, dy = pt[1] - hx, pt[2] - hy
            local len = math.sqrt(dx * dx + dy * dy)
            if len > r0 + 20 then
                for j = 1, DOTS_PER_LINE do
                    local t = (r0 + (len - r0 - 18) * (j - 1) / (DOTS_PER_LINE - 1)) / len
                    n = n + 1
                    local d = Dot(n)
                    d:ClearAllPoints()
                    d:SetPoint("CENTER", dotLayer, "CENTER", hx + dx * t, hy + dy * t)
                    d:Show()
                end
            end
        end
    end
    for i = n + 1, #dots do dots[i]:Hide() end
end

function ns:SetMoveMode(on)
    if on and InCombatLockdown() then
        ns.Print("전투 중에는 이동 모드를 켤 수 없어요.")
        return
    end
    ns.moving = on and true or false
    if ns.SetPreview then ns:SetPreview(ns.moving) end
    if ns.SetPartyPreview then ns:SetPartyPreview(ns.moving) end
    if ns.SetChatMoveMode then ns:SetChatMoveMode(ns.moving) end
    if ns.moving then BuildPartMovers(); BuildHub() end
    ns.mover:SetShown(ns.moving)
    if ns.moving then ns.RefreshHudHub() elseif hubMenu then hubMenu:Hide() end
    ns.moverBar:SetShown(ns.moving)
    ns.moverBar.gridBtn:SetLabel(ns.db.grid and "격자 끄기" or "격자 켜기")
    ShowGrid(ns.moving and ns.db.grid)
    if ns.UpdateMinimapButton then ns:UpdateMinimapButton() end
    if ns.RefreshConfig then ns:RefreshConfig() end
end

function ns:ToggleMoveMode()
    ns:SetMoveMode(not ns.moving)
end

-- 전투가 시작되면 자동으로 끝냄
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function()
    if ns.moving then
        ns:SetMoveMode(false)
        ns.Print("전투가 시작돼서 이동 모드를 끝냈어요.")
    end
end)
