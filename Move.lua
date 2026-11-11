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
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = m:CreateTexture(nil, "BORDER")
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
    cfs:SetText("이동 모드: 드래그해서 옮기기, 방향키 1px (Shift 10px) · 이 칸을 끌면 막대 이동")
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
    local w = chip:GetWidth() + 8 + done:GetWidth() + 8 + math.max(gridBtn:GetWidth(), 90) + 24 + 4 * 28 + 3 * 4
    bar:SetWidth(math.max(w, 400))

    m:Hide(); bar:Hide()
    ns.mover, ns.moverBar = m, bar
end

----------------------------------------------------------------------
-- 켜기 / 끄기
----------------------------------------------------------------------
function ns:SetMoveMode(on)
    if on and InCombatLockdown() then
        ns.Print("전투 중에는 이동 모드를 켤 수 없어요.")
        return
    end
    ns.moving = on and true or false
    if ns.SetPreview then ns:SetPreview(ns.moving) end
    if ns.SetPartyPreview then ns:SetPartyPreview(ns.moving) end
    ns.mover:SetShown(ns.moving)
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
