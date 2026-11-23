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
            if not (ns.MovePartNudge and ns.MovePartNudge(moves[key][1], moves[key][2])) then
                Nudge(moves[key][1], moves[key][2])
            end
        elseif key == "ESCAPE" and ns.MoveListOpen and ns.MoveListOpen() then
            self:SetPropagateKeyboardInput(false)
            ns.MoveListToggle(false)
        elseif key == "TAB" and ns.movePartEdit then
            self:SetPropagateKeyboardInput(false)
            if ns.MovePartTab then ns.MovePartTab(IsShiftKeyDown()) end
        elseif key == "ESCAPE" and ns.movePartEdit then
            self:SetPropagateKeyboardInput(false)
            if ns.MovePartEdit then ns.MovePartEdit(false) end
        elseif key == "ESCAPE" or key == "ENTER" then
            self:SetPropagateKeyboardInput(false)
            ns:SetMoveMode(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    -- 상단 바 (리뉴얼 A안): 화면 위 끝까지 꽉 찬 얇은 띠
    --   왼쪽 = 이동 모드 + 단축키 안내 · 가운데 = 고른 창 크기 − 100% + · 오른쪽 = 격자 · HUD 모으기 · 되돌리기 · 목록 | 완료
    local bar = CreateFrame("Frame", nil, UIParent)
    bar:SetFrameStrata("FULLSCREEN_DIALOG")
    bar:SetHeight(34)
    bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    bar:EnableMouse(true)
    local bgt = bar:CreateTexture(nil, "BACKGROUND"); bgt:SetAllPoints(); bgt:SetTexture(ns.WHITE)
    pcall(bgt.SetGradient, bgt, "VERTICAL", CreateColor(0.114, 0.082, 0.078, 0.95), CreateColor(0.145, 0.106, 0.102, 0.97))
    local line = bar:CreateTexture(nil, "BORDER"); line:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.7)
    line:SetHeight(1); line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
    local shd = bar:CreateTexture(nil, "BACKGROUND"); shd:SetTexture(ns.WHITE); shd:SetHeight(14)
    shd:SetPoint("TOPLEFT", bar, "BOTTOMLEFT"); shd:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT")
    pcall(shd.SetGradient, shd, "VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.45))

    local bun = bar:CreateTexture(nil, "ARTWORK"); bun:SetTexture(ns.MEDIA .. "bunny"); bun:SetSize(22, 22); bun:SetPoint("LEFT", 12, 0)
    local cfs = ns.Font(bar, 13, C.accHi); cfs:SetPoint("LEFT", bun, "RIGHT", 5, 0); cfs:SetText("이동 모드")
    local hint = ns.Font(bar, 11, { 0.66, 0.58, 0.565 }); hint:SetPoint("LEFT", cfs, "RIGHT", 10, 0)
    hint:SetText("끌기 = 옮기기 · 방향키 1칸 · Shift 10칸 · Esc = 끝")
    bar.hint = hint
    -- 가운데: 아무것도 안 골랐을 때 안내 (고르면 크기 도구가 이 자리에)
    bar.pick = ns.Font(bar, 11.5, { 0.66, 0.58, 0.565 }); bar.pick:SetPoint("CENTER", 0, 0)
    bar.pick:SetText("분홍 점선 창을 눌러 고르면 여기서 크기를 바꿔요")

    local function Btn(text, primary, fn, w)
        local bt = ns.MakeButton(bar, text, primary, fn, w)
        bt:SetHeight(24)
        return bt
    end
    local done = Btn("완료", true, function() ns:SetMoveMode(false) end)
    done:SetPoint("RIGHT", -10, 0)
    local sep = bar:CreateTexture(nil, "ARTWORK"); sep:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.3); sep:SetSize(1, 16)
    sep:SetPoint("RIGHT", done, "LEFT", -8, 0)
    local listBtn = Btn("목록", false, function() if ns.MoveListToggle then ns.MoveListToggle() end end)
    listBtn:SetPoint("RIGHT", sep, "LEFT", -8, 0)
    bar.listBtn = listBtn
    local undo = Btn("되돌리기", false, function() if ns.MoveUndoAsk then ns.MoveUndoAsk() end end)
    undo:SetPoint("RIGHT", listBtn, "LEFT", -6, 0)
    undo:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); ns.TSet(GameTooltip, "되돌리기")
        ns.TAdd(GameTooltip, "이동 모드를 켠 뒤 옮기고 바꾼 것을 모두 처음으로 (다시 불러오기)", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    undo:HookScript("OnLeave", function() GameTooltip:Hide() end)
    local joinBtn = Btn("HUD 모으기", false, function() ns:ResetHudParts() end)
    joinBtn:SetPoint("RIGHT", undo, "LEFT", -6, 0)
    local gridBtn
    gridBtn = Btn("", false, function()
        ns.db.grid = not ns.db.grid
        ShowGrid(ns.db.grid)
        gridBtn:SetLabel(ns.db.grid and "격자 끄기" or "격자 켜기")
    end)
    gridBtn:SetPoint("RIGHT", joinBtn, "LEFT", -6, 0)
    bar.gridBtn = gridBtn
    bar.doneBtn, bar.sepT, bar.undoBtn, bar.joinBtn = done, sep, undo, joinBtn
    -- 화면이 좁으면 단축키 안내는 숨겨요
    bar:SetScript("OnSizeChanged", function(self, w)
        hint:SetShown((w or 0) > 1150)
    end)

    m:Hide(); bar:Hide()
    ns.mover, ns.moverBar = m, bar
    C_Timer.After(0, function() if ns.MoveSizeHook then ns.MoveSizeHook(m, "Leel HUD 크기", "Leel HUD") end end)
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
-- 조각마다 크기 (HUD 전체 크기에 곱해요 · 100 = 그대로)
local PART_SIZE = { player = "내 창 크기", center = "가운데 크기", target = "대상 창 크기" }
local PART_TITLE = { player = "내 창", center = "가운데", target = "대상 창" }
function ns.HudPartScale(key)
    local t = ns.db and ns.db.partScale
    local v = t and tonumber(t[key]) or 100
    return math.max(0.4, math.min(2, v / 100))
end
function ns.SetHudPartScale(key, v)
    ns.db.partScale = ns.db.partScale or {}
    ns.db.partScale[key] = math.floor(tonumber(v) or 100)
    ns:ApplyHudParts()
end

function ns:ApplyHudParts()
    local fr, hud = ns.hudFrames, ns.hud
    if not (fr and hud) then return end
    ns:RunOutOfCombat("hudparts", function()
        for _, p in ipairs(PARTS) do
            local f = fr[p.key]
            if f then
                local o = PartOff(p.key) or { p.dx, p.dy }
                local sc = ns.HudPartScale(p.key)
                f:SetScale(sc)
                f:ClearAllPoints()
                f:SetPoint(p.point, hud, p.point, o[1] / sc, o[2] / sc)   -- 자리는 HUD 기준 그대로
            end
        end
        if ns.HudPlacePet then ns.HudPlacePet() end
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
    local k = f:GetScale()   -- 조각 크기만큼 HUD 단위로 바꿔서
    if p.point == "TOPLEFT" then
        x, y = f:GetLeft() * k - hud:GetLeft(), f:GetTop() * k - hud:GetTop()
    elseif p.point == "TOPRIGHT" then
        x, y = f:GetRight() * k - hud:GetRight(), f:GetTop() * k - hud:GetTop()
    else
        x = (f:GetLeft() + f:GetRight()) / 2 * k - (hud:GetLeft() + hud:GetRight()) / 2
        y = f:GetTop() * k - hud:GetTop()
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
function ns.HudPartMover(key) return partMovers and partMovers[key] end
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
            ns.MoveSizeHook(m, PART_SIZE[p.key], PART_TITLE[p.key])
            partMovers[p.key] = m
            m:SetScript("OnEnter", function()
                tint:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.16)
                GameTooltip:SetOwner(m, "ANCHOR_TOP")
                ns.TSet(GameTooltip, p.label .. " 옮기기")
                ns.TAdd(GameTooltip, "끌기: 이것만 옮기기 · 누르면 크기 줄 · 휠 = 크기", 1, 1, 1)
                ns.TAdd(GameTooltip, "셋 다 같이는 토끼 손잡이를 끌어요", 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end)
            m:SetScript("OnLeave", function() tint:SetColorTexture(1, 1, 1, 0.04); GameTooltip:Hide() end)
            m:SetScript("OnDragStart", function(self)
                if InCombatLockdown() then return end
                self.dragging = true
                f:StartMoving()
                if ns.MovePartDragStart then ns.MovePartDragStart(p, f) end
                -- 끄는 동안 토끼 · 점선이 따라와요
                self:SetScript("OnUpdate", function()
                    if ns.MovePartDragTick then ns.MovePartDragTick(p, f) end
                    if ns.RefreshHudHub then ns.RefreshHudHub() end
                end)
            end)
            m:SetScript("OnDragStop", function(self)
                self:SetScript("OnUpdate", nil)
                if not self.dragging then return end
                self.dragging = false
                f:StopMovingOrSizing()
                if ns.MovePartDragStop then ns.MovePartDragStop(p, f) end
                SavePart(p, f)
                if ns.MovePartMirrorSave then ns.MovePartMirrorSave(p) end
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
        ns.TSet(GameTooltip, "HUD 다 같이 옮기기")
        ns.TAdd(GameTooltip, "끌기: 놓인 모양 그대로 셋 다 같이", 1, 1, 1)
        ns.TAdd(GameTooltip, "오른쪽 클릭: 다시 모으기 · 처음 자리로", 0.8, 0.8, 0.8)
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

----------------------------------------------------------------------
-- 이동 모드에서 고른 것 바로 위에 크기 조절 줄: − 82% + · 처음 크기
-- (고르기 = 테두리를 누르기 · 끌기, 고른 테두리 위에서 휠 = 크기)
----------------------------------------------------------------------
local SIZE_DEFAULT = { ["Leel HUD 크기"] = function() return math.floor((ns.defaults.scale or 0.61) * 100 + 0.5) end,
                       ["파티 프레임 크기"] = function() return math.floor((ns.defaults.partyScale or 0.75) * 100 + 0.5) end,
                       ["액션바 크기"] = function() return 80 end, ["토끼 메뉴 크기"] = function() return 80 end,
                       ["내 창 크기"] = function() return 100 end, ["가운데 크기"] = function() return 100 end,
                       ["대상 창 크기"] = function() return 100 end, ["대상의 대상 크기"] = function() return 100 end,
                       ["펫 창 크기 (사냥꾼 · 흑마법사)"] = function() return 130 end }
-- 허브에 줄이 없을 때도 쓰는 조각 크기 (내 창 · 가운데 · 대상 창)
local function PartSize(key, label)
    return { t = "slider", label = label, min = 50, max = 160,
        get = function() return ns.db.partScale and ns.db.partScale[key] or 100 end,
        set = function(v) if ns.SetHudPartScale then ns.SetHudPartScale(key, v) end end }
end
local SIZE_FALLBACK = { ["내 창 크기"] = PartSize("player", "내 창 크기"), ["가운데 크기"] = PartSize("center", "가운데 크기"),
                        ["대상 창 크기"] = PartSize("target", "대상 창 크기") }
local function SizeItem(label)
    for _, m in ipairs(ns.HUB_MODULES or {}) do
        for _, it in ipairs(m.items or {}) do
            if it.t == "slider" and it.label == label then return it end
        end
    end
    return SIZE_FALLBACK[label]
end
local sizeBar, sizeSel
local function SizePaint()
    if not (sizeBar and sizeSel) then return end
    local ok, v = pcall(sizeSel.it.get)
    sizeBar.val:SetText((ok and v or "?") .. "%")
end
local function SizeSet(v)
    local it = sizeSel and sizeSel.it
    if not it then return end
    v = math.max(it.min, math.min(it.max, math.floor(v + 0.5)))
    pcall(it.set, v)
    SizePaint()
end
local function SizeBuild()
    -- 상단 캡슐 가운데 "고른 창" 칩: 고른 창 · 이름 · [− 61% +] · ↺(처음대로)
    --   조각 편집 중엔 이름 없이 [− 100% +] 만 (이름은 조각 칩이 보여줘요)
    local b = CreateFrame("Frame", nil, ns.moverBar)
    b:SetHeight(30)
    b:SetFrameLevel(ns.moverBar:GetFrameLevel() + 2)
    b.bg = ns.RoundRect(b, 15, { 0.06, 0.045, 0.042 }, "BACKGROUND", 0, 0); b.bg:SetColor({ 0.06, 0.045, 0.042 }, 0.75)
    b.cap = ns.Font(b, 10.5, { 0.66, 0.58, 0.565 }); b.cap:SetText("고른 창")
    b.title = ns.Font(b, 12.5, C.accHi)
    local st = CreateFrame("Frame", nil, b); st:SetSize(92, 22)
    local sbg = ns.RoundRect(st, 11, { 0.17, 0.13, 0.125 }, "BACKGROUND", 1, 0); sbg:SetColor({ 0.17, 0.13, 0.125 }, 1)
    local function Step(txt, d, point)
        local bt = CreateFrame("Button", nil, st); bt:SetSize(24, 22); bt:SetPoint(point, 0, 0)
        local fs = ns.Font(bt, 14, C.tx); fs:SetPoint("CENTER", 0, 1); fs:SetText(txt)
        local hl = bt:CreateTexture(nil, "HIGHLIGHT"); hl:SetTexture(ns.MEDIA .. "circle"); hl:SetPoint("CENTER"); hl:SetSize(20, 20); hl:SetVertexColor(1, 1, 1, 0.12)
        bt:SetScript("OnClick", function() if sizeSel then local ok, v = pcall(sizeSel.it.get); if ok then SizeSet(v + d * (IsShiftKeyDown() and 1 or 5)) end end end)
        return bt
    end
    b.minus, b.plus = Step("−", -1, "LEFT"), Step("+", 1, "RIGHT")
    b.val = ns.Num(st, 13, C.accHi); b.val:SetPoint("CENTER", 0, 0)
    b.st = st
    local r = CreateFrame("Button", nil, b); r:SetSize(22, 22)
    local ri = r:CreateTexture(nil, "ARTWORK"); ri:SetTexture("Interface\\Buttons\\UI-RefreshButton"); ri:SetPoint("CENTER"); ri:SetSize(14, 14); ri:SetVertexColor(0.9, 0.85, 0.83)
    local rh = r:CreateTexture(nil, "HIGHLIGHT"); rh:SetTexture(ns.MEDIA .. "circle"); rh:SetAllPoints(); rh:SetVertexColor(1, 1, 1, 0.12)
    r:SetScript("OnClick", function() local d = sizeSel and SIZE_DEFAULT[sizeSel.label]; if d then SizeSet(d()) end end)
    r:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); ns.TSet(GameTooltip, "크기 처음대로"); GameTooltip:Show() end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b.reset = r
    b:SetScript("OnUpdate", function(self)
        local x = 4
        if self.cap:IsShown() then
            x = 12
            self.cap:ClearAllPoints(); self.cap:SetPoint("LEFT", x, 0); x = x + self.cap:GetStringWidth() + 6
            self.title:ClearAllPoints(); self.title:SetPoint("LEFT", x, 0); x = x + self.title:GetStringWidth() + 8
        end
        self.st:ClearAllPoints(); self.st:SetPoint("LEFT", x, 0); x = x + 92 + 2
        if self.reset:IsShown() then self.reset:ClearAllPoints(); self.reset:SetPoint("LEFT", x, 0); x = x + 22 end
        self:SetWidth(x + 4)
    end)
    b:Hide()
    sizeBar = b
end

-- mover = 이동 모드 테두리, label = 허브의 크기 슬라이더 이름, title = 보일 이름
function ns.MoveSelect(mover, label, title)
    if not mover then
        sizeSel = nil
        if sizeBar then sizeBar:Hide() end
        return
    end
    local it = SizeItem(label)
    if not it then return end
    if not sizeBar then SizeBuild() end
    sizeSel = { mover = mover, it = it, label = label }
    sizeBar.title:SetText(title or label)
    sizeBar.reset:SetShown(SIZE_DEFAULT[label] and true or false)
    SizePaint()
    sizeBar:Show()
end

-- 이동 모드 테두리에 붙이기: 누르면 고르고, 고른 상태에서 휠 = 크기
function ns.MoveSizeHook(mover, label, title)
    if not mover or mover.leelSize then return end
    mover.leelSize = true
    mover:HookScript("OnMouseDown", function(self) ns.MoveSelect(self, label, title) end)
    mover:EnableMouseWheel(true)
    mover:SetScript("OnMouseWheel", function(self, d)
        if not (sizeSel and sizeSel.mover == self) then ns.MoveSelect(self, label, title) end
        local ok, v = pcall(sizeSel.it.get)
        if ok then SizeSet(v + d * (IsShiftKeyDown() and 1 or 5)) end
    end)
end

hooksecurefunc(ns, "SetMoveMode", function()
    if not ns.moving then ns.MoveSelect(nil) end
end)

-- 크기만 바꾸는 테두리 (대상의 대상 · 펫 창처럼 자리가 HUD에 붙어 있는 것)
--   이동 모드에서만 보여요 · 누르면 크기 줄 · 휠 = 크기
--   onToggle(on): 이동 모드가 켜지고 꺼질 때 (예시로 보이게 하기 등)
function ns.MoveSizeOnly(frame, label, title, onToggle)
    if not frame or frame.leelSizeOnly then return end
    local m = CreateFrame("Frame", nil, frame)
    m:SetPoint("TOPLEFT", -3, 3); m:SetPoint("BOTTOMRIGHT", 3, -3)
    m:SetFrameStrata("FULLSCREEN")
    m:EnableMouse(true)
    local tint = m:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints(); tint:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.1)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = m:CreateTexture(nil, "BORDER")
        e:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.9)
        if side == "TOP" or side == "BOTTOM" then e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(1)
        else e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(1) end
    end
    m:SetScript("OnEnter", function(self)
        tint:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.2)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        ns.TSet(GameTooltip, title .. " 크기", 1, 0.84, 0.88)
        ns.TAdd(GameTooltip, "누르면 위에 크기 줄 · 휠 = 크기", 1, 1, 1)
        ns.TAdd(GameTooltip, "자리는 HUD를 따라가요", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function() tint:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.1); GameTooltip:Hide() end)
    ns.MoveSizeHook(m, label, title)
    m:Hide()
    frame.leelSizeOnly = m
    hooksecurefunc(ns, "SetMoveMode", function()
        local on = ns.moving and not InCombatLockdown()
        if onToggle then pcall(onToggle, on and true or false) end
        m:SetShown(on and frame:IsShown() and true or false)
    end)
    return m
end

----------------------------------------------------------------------
-- 이동 모드 리뉴얼 (A안 + 목록 판)
--   옮길 수 있는 창 = 분홍 점선 + 이름 알약 · 마우스 = 진하게
--   고르면 = 분홍 실선 + 빛 + 네 모서리 손잡이 (끌면 크기) + 바로 위 도구 알약
--   화면은 살짝 어둡게 · 아래 알약 [목록] = 왼쪽 목록 판 (누르면 그 창 고르기 · 반짝)
--   [되돌리기] = 이동 모드를 켤 때 설정으로 (다시 불러오기)
----------------------------------------------------------------------
local skins = {}
local selMover
local PK = C.acc

local function Dash(parent, horiz)
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetTexture(ns.MEDIA .. (horiz and "mv_dash_h" or "mv_dash_v"), "REPEAT", "REPEAT")
    if horiz then t:SetHeight(1.5) else t:SetWidth(1.5) end
    return t
end

local function Fit(k)
    -- 창 크기와 상관없이 점선 · 알약 · 손잡이는 늘 같은 크기
    local m = k.mover
    local es = m:GetEffectiveScale()
    if not es or es <= 0 then return end
    k:SetScale(UIParent:GetEffectiveScale() / es)
    local w, h = k:GetWidth(), k:GetHeight()
    k.dt:SetTexCoord(0, w / 16, 0, 1); k.db:SetTexCoord(0, w / 16, 0, 1)
    k.dl:SetTexCoord(0, 1, 0, h / 16); k.dr:SetTexCoord(0, 1, 0, h / 16)
    -- 화면 맨 위에 붙은 창(미니맵 등)은 이름 알약이 화면 밖 · 상단 바 밑에 숨으니 안쪽으로
    if not k.part and k.pill then
        local top = k:GetTop()
        local ks = k:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local inside = top and (top * ks > UIParent:GetTop() - 44)
        if inside ~= k.pillIn then
            k.pillIn = inside
            k.pill:ClearAllPoints()
            if inside then k.pill:SetPoint("TOPLEFT", k, "TOPLEFT", 8, -6)
            else k.pill:SetPoint("LEFT", k, "TOPLEFT", 8, 0) end
        end
    end
end

local function Paint(k)
    local on = (selMover == k.mover)
    local hot = on or k.listHot   -- 목록 줄에 마우스 = 고른 것처럼 또렷하게 (손잡이는 빼고)
    local a = on and 1 or (k.hover and 0.95 or 0.6)
    for _, t in ipairs(k.dash) do t:SetShown(not hot); t:SetVertexColor(PK[1], PK[2], PK[3], a) end
    for _, t in ipairs(k.solid) do t:SetShown(hot) end
    k.glow:SetShown(hot)
    k.fill:SetColorTexture(PK[1], PK[2], PK[3], hot and 0.16 or (k.hover and 0.10 or 0.04))
    k.pill.bg:SetColor(on and PK or { 0.16, 0.12, 0.115 }, 1)
    k.pill.edge:SetColor(PK, on and 1 or 0.55)
    local c = on and C.ink or C.accHi
    k.pill.fs:SetTextColor(c[1], c[2], c[3]); k.pill.fs:SetShadowColor(0, 0, 0, on and 0 or 0.8)
    for _, hd in ipairs(k.handles) do hd:SetShown(on and k.sizeLabel ~= nil) end
    if k.part then k.pill:SetShown(on or k.hover) end
end

local function PaintAll() for _, k in ipairs(skins) do Paint(k) end; if ns.MoveBarCenter then ns.MoveBarCenter() end end

-- 모서리 손잡이로 크기: 고른 창 가운데에서 커서까지 거리 비율만큼
local function Handle(k, point)
    local hd = CreateFrame("Button", nil, k)
    hd:SetSize(10, 10); hd:SetPoint("CENTER", k, point, 0, 0)
    hd:SetFrameLevel(k:GetFrameLevel() + 4)
    local r = hd:CreateTexture(nil, "BORDER"); r:SetTexture(ns.MEDIA .. "circle"); r:SetAllPoints(); r:SetVertexColor(PK[1], PK[2], PK[3], 1)
    local d = hd:CreateTexture(nil, "ARTWORK"); d:SetTexture(ns.MEDIA .. "circle"); d:SetPoint("TOPLEFT", 2, -2); d:SetPoint("BOTTOMRIGHT", -2, 2); d:SetVertexColor(1, 1, 1, 1)
    hd:RegisterForDrag("LeftButton")
    hd:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP"); ns.TSet(GameTooltip, "끌면 크기"); GameTooltip:Show()
    end)
    hd:SetScript("OnLeave", function() GameTooltip:Hide() end)
    hd:SetScript("OnDragStart", function(self)
        if InCombatLockdown() or not (sizeSel and sizeSel.mover == k.mover) then return end
        local ok, v = pcall(sizeSel.it.get)
        if not ok then return end
        local cx, cy = k.mover:GetCenter()
        local es = k.mover:GetEffectiveScale()
        local ux, uy = GetCursorPosition()
        local d0 = math.sqrt((ux - cx * es) ^ 2 + (uy - cy * es) ^ 2)
        if d0 < 4 then return end
        self.drag = { v = v, d0 = d0, cx = cx * es, cy = cy * es }
        self:SetScript("OnUpdate", function(s2)
            local dd = s2.drag
            if not dd then return end
            local nx, ny = GetCursorPosition()
            local d1 = math.sqrt((nx - dd.cx) ^ 2 + (ny - dd.cy) ^ 2)
            local want = dd.v * d1 / dd.d0
            local st = IsShiftKeyDown() and 1 or 5
            want = math.floor(want / st + 0.5) * st
            if want ~= s2.last then s2.last = want; SizeSet(want) end
            if ns.MoveSizeTag then ns.MoveSizeTag(s2.last or dd.v, dd.v) end
        end)
        if ns.MoveGhost then ns.MoveGhost(k.mover) end
    end)
    hd:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil); self.drag = nil; self.last = nil
        if ns.MoveSizeTag then ns.MoveSizeTag(nil) end
        if ns.MoveGhost then ns.MoveGhost(nil) end
    end)
    return hd
end

function ns.MoveSkin(m, title, sizeLabel)
    if not m or m.leelSkin then return m and m.leelSkin end
    -- 예전 겉모양(노란 · 분홍 테, 가운데 글씨)은 숨기고 새 겉모양을 위에
    for _, r in ipairs({ m:GetRegions() }) do pcall(r.SetAlpha, r, 0) end
    local k = CreateFrame("Frame", nil, m)
    k:SetAllPoints(m)
    k:SetFrameLevel(m:GetFrameLevel() + 1)
    k:EnableMouse(false)
    k.mover, k.title, k.sizeLabel = m, title, sizeLabel
    k.fill = k:CreateTexture(nil, "BACKGROUND"); k.fill:SetAllPoints()
    k.dt, k.db, k.dl, k.dr = Dash(k, true), Dash(k, true), Dash(k, false), Dash(k, false)
    k.dt:SetPoint("TOPLEFT"); k.dt:SetPoint("TOPRIGHT"); k.db:SetPoint("BOTTOMLEFT"); k.db:SetPoint("BOTTOMRIGHT")
    k.dl:SetPoint("TOPLEFT"); k.dl:SetPoint("BOTTOMLEFT"); k.dr:SetPoint("TOPRIGHT"); k.dr:SetPoint("BOTTOMRIGHT")
    k.dash = { k.dt, k.db, k.dl, k.dr }
    k.solid = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = k:CreateTexture(nil, "OVERLAY"); e:SetColorTexture(PK[1], PK[2], PK[3], 1)
        if side == "TOP" or side == "BOTTOM" then e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(2)
        else e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(2) end
        k.solid[#k.solid + 1] = e
    end
    k.glow = k:CreateTexture(nil, "BACKGROUND", nil, -1); k.glow:SetTexture(ns.MEDIA .. "soft_glow"); k.glow:SetBlendMode("ADD")
    k.glow:SetPoint("TOPLEFT", -18, 18); k.glow:SetPoint("BOTTOMRIGHT", 18, -18); k.glow:SetVertexColor(PK[1], PK[2], PK[3], 0.35)
    -- 이름 알약 (왼쪽 위 · 테 위에 걸쳐서)
    local pill = CreateFrame("Frame", nil, k); pill:SetHeight(18); pill:SetPoint("LEFT", k, "TOPLEFT", 8, 0)
    pill:SetFrameLevel(k:GetFrameLevel() + 3)
    pill.edge = ns.RoundRect(pill, 10, PK, "BACKGROUND", 0, -1)
    pill.bg = ns.RoundRect(pill, 9, { 0.16, 0.12, 0.115 }, "BACKGROUND", 1, 0)
    pill.fs = ns.Font(pill, 11); pill.fs:SetPoint("CENTER", 0, 0); pill.fs:SetText(title or "")
    pill:SetWidth(pill.fs:GetStringWidth() + 16)
    k.pill = pill
    -- HUD 조각은 이름이 초상화 · 글씨를 가리지 않게: 아래 바깥쪽 · 마우스 올렸거나 고른 것만
    local PARTSET = { ["내 창"] = 1, ["가운데"] = 1, ["대상 창"] = 1, ["펫 창"] = 1, ["대상의 대상"] = 1 }
    if PARTSET[title or ""] then
        k.part = true
        pill:ClearAllPoints(); pill:SetPoint("TOPLEFT", k, "BOTTOMLEFT", 6, 4)
    end
    k.handles = { Handle(k, "TOPLEFT"), Handle(k, "TOPRIGHT"), Handle(k, "BOTTOMLEFT"), Handle(k, "BOTTOMRIGHT") }
    k:SetScript("OnShow", function(self) Fit(self); Paint(self) end)
    k:SetScript("OnSizeChanged", function(self) Fit(self) end)
    m:HookScript("OnEnter", function() k.hover = true; Paint(k) end)
    m:HookScript("OnLeave", function() k.hover = false; Paint(k) end)
    -- 크기 줄이 없는 창도 누르면 "고른 창" 표시
    m:HookScript("OnMouseDown", function()
        if not k.sizeLabel then
            if ns.MoveSelect then ns.MoveSelect(nil) end
            selMover = m; PaintAll()
        end
    end)
    m.leelSkin = k
    skins[#skins + 1] = k
    Fit(k); Paint(k)
    return k
end

-- 크기 줄이 있는 창은 테두리에 붙일 때 같이 새 겉모양
do
    local orig = ns.MoveSizeHook
    ns.MoveSizeHook = function(mover, label, title)
        orig(mover, label, title)
        if mover and not mover.leelSkin then
            local t = title or (label and label:gsub("%s*크기.*$", "")) or ""
            ns.MoveSkin(mover, t, label)
        end
    end
end
hooksecurefunc(ns, "MoveSelect", function(mover)
    selMover = mover
    PaintAll()
end)

-- HUD 전체 테두리: 조각이 흩어지면 숨기고(지금처럼) 붙어 있으면 보이기
if ns.RefreshHudHub then
    hooksecurefunc(ns, "RefreshHudHub", function()
        local k = ns.mover and ns.mover.leelSkin
        if not k then return end
        if ns.MoveGroupApply then ns.MoveGroupApply() end
    end)
end

----------------------------------------------------------------------
-- 화면 살짝 어둡게 (게임 화면만 · 르엘 창들은 그대로 밝게)
----------------------------------------------------------------------
local dim
local function Dim(on)
    if on and not dim then
        dim = CreateFrame("Frame", nil, UIParent)
        dim:SetAllPoints(); dim:SetFrameStrata("BACKGROUND"); dim:SetFrameLevel(0); dim:EnableMouse(false)
        local t = dim:CreateTexture(nil, "BACKGROUND"); t:SetAllPoints(); t:SetColorTexture(0.04, 0.025, 0.025, 0.35)
    end
    if dim then dim:SetShown(on) end
end

----------------------------------------------------------------------
-- 목록 판 (왼쪽 · 접어 두기 · 누르면 그 창 고르기 + 반짝)
----------------------------------------------------------------------
local list, ListPaint
local function Flash(k)
    if not k.flash then
        local f = k:CreateTexture(nil, "OVERLAY", nil, 7); f:SetAllPoints(); f:SetColorTexture(PK[1], PK[2], PK[3], 0.4); f:SetBlendMode("ADD")
        local ag = f:CreateAnimationGroup()
        local a1 = ag:CreateAnimation("Alpha"); a1:SetFromAlpha(0); a1:SetToAlpha(1); a1:SetDuration(0.18); a1:SetOrder(1)
        local a2 = ag:CreateAnimation("Alpha"); a2:SetFromAlpha(1); a2:SetToAlpha(0); a2:SetDuration(0.5); a2:SetOrder(2)
        ag:SetScript("OnFinished", function() f:SetAlpha(0) end)
        f:SetAlpha(0)
        k.flash, k.flashAg = f, ag
    end
    k.flashAg:Stop(); k.flashAg:Play()
end
-- [목록] A안: 상단 탭 바로 아래로 내려오는 판
--   찾기 칸 · 묶음(내 HUD / 화면 · 채팅 · 바 / 파티 · 주사위) · 줄마다 크기 숫자 · ↺ 크기 처음대로 · ◉ 잠깐 숨기기
--   줄에 마우스 = 화면의 그 창이 빛나고 판에서 선이 이어져요 · 누르면 고르기 + 반짝 · Esc / [목록] = 닫기
local LROW, LW = 24, 300
local function LRect(f)
    if not (f and f:IsVisible() and f:GetLeft()) then return nil end
    local sc = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return { l = f:GetLeft() * sc, r = f:GetRight() * sc, t = f:GetTop() * sc, b = f:GetBottom() * sc }
end
local tmpHide = {}
local function Group(t)
    if t == "Leel HUD" or t == "시전바" then return 1, "내 HUD" end
    if t:find("파티") or t:find("주사위") then return 3, "파티 · 주사위" end
    return 2, "화면 · 채팅 · 바"
end
local function Why(k)
    local t = k.title or ""
    if t:find("펫") then return "펫 없음" end
    if t:find("파티") then return "파티 아님" end
    return "안 보임"
end
local function SizeOf(k)
    local it = k.sizeLabel and SizeItem(k.sizeLabel)
    if not it then return nil end
    local ok, v = pcall(it.get)
    return ok and v or nil
end
-- 목록 줄에 마우스 = 그 창만 밝게, 나머지는 어둡게 (구멍 뚫린 어둠 4장)
local spot
local function Wire(row, k)
    if not spot then
        spot = CreateFrame("Frame", nil, UIParent)
        spot:SetAllPoints(); spot:SetFrameStrata("FULLSCREEN"); spot:SetFrameLevel(200); spot:EnableMouse(false)
        spot.p = {}
        for i2 = 1, 4 do
            local t = spot:CreateTexture(nil, "BACKGROUND"); t:SetColorTexture(0.03, 0.02, 0.02, 0.62)
            spot.p[i2] = t
        end
        spot:Hide()
    end
    spot.want = row
    if not row then
        -- 줄 사이를 옮겨 다닐 때 깜빡이지 않게 한 프레임 기다렸다가
        C_Timer.After(0, function() if not spot.want then spot:Hide() end end)
        return
    end
    local r = LRect(k.mover)
    if not r then spot:Hide() return end
    local pad = 6
    local L, R, T, B = r.l - pad, r.r + pad, r.t + pad, r.b - pad
    local W, H = UIParent:GetSize()
    local p = spot.p
    -- 위 · 아래 (가로 전체) · 왼쪽 · 오른쪽 (구멍 높이만큼)
    p[1]:ClearAllPoints(); p[1]:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, T); p[1]:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    p[2]:ClearAllPoints(); p[2]:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0); p[2]:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", W, math.max(B, 0))
    p[3]:ClearAllPoints(); p[3]:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, math.max(B, 0)); p[3]:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", math.max(L, 0), math.min(T, H))
    p[4]:ClearAllPoints(); p[4]:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", math.min(R, W), math.max(B, 0)); p[4]:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", W, math.min(T, H))
    p[1]:SetShown(T < H); p[2]:SetShown(B > 0); p[3]:SetShown(L > 0); p[4]:SetShown(R < W)
    if not spot:IsShown() then
        spot:SetAlpha(0); spot:Show()
        local t = 0
        spot:SetScript("OnUpdate", function(self, e)
            t = t + e
            local u = math.min(1, t / 0.12)
            self:SetAlpha(u)
            if u >= 1 then self:SetScript("OnUpdate", nil) end
        end)
    end
end
local function IconBtn(parent, tex, tip, fn)
    local b = CreateFrame("Button", nil, parent); b:SetSize(18, 18)
    local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(ns.MEDIA .. "circle"); bg:SetAllPoints(); bg:SetVertexColor(0.17, 0.13, 0.125, 1)
    b.ic = b:CreateTexture(nil, "ARTWORK"); b.ic:SetTexture(tex); b.ic:SetPoint("TOPLEFT", 3, -3); b.ic:SetPoint("BOTTOMRIGHT", -3, 3)
    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetTexture(ns.MEDIA .. "circle"); hl:SetAllPoints(); hl:SetVertexColor(PK[1], PK[2], PK[3], 0.35)
    b:SetScript("OnClick", fn)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); ns.TSet(GameTooltip, type(tip) == "function" and tip(self) or tip); GameTooltip:Show()
        local r = self:GetParent(); if r.k then r.k.listHot = true; Paint(r.k); Wire(r, r.k) end
    end)
    b:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        local r = self:GetParent(); if r.k then r.k.listHot = false; Paint(r.k); Wire(nil) end
    end)
    return b
end
local function SetTmpHide(k, on)
    local mv = k.mover
    if on and not tmpHide[mv] then
        tmpHide[mv] = mv:IsMouseEnabled() and 1 or 0
        mv:SetAlpha(0.12); mv:EnableMouse(false)
    elseif not on and tmpHide[mv] then
        mv:SetAlpha(1); mv:EnableMouse(tmpHide[mv] == 1); tmpHide[mv] = nil
    end
end

local function Row(i)
    local r = list.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, list.body); r:SetHeight(LROW - 2)
    r.hl = ns.RoundRect(r, 8, PK, "BACKGROUND", 0, 0)
    r.bar = r:CreateTexture(nil, "ARTWORK"); r.bar:SetColorTexture(PK[1], PK[2], PK[3], 1); r.bar:SetSize(2, 14); r.bar:SetPoint("LEFT", 0, 0)
    r.ic = CreateFrame("Frame", nil, r); r.ic:SetSize(18, 18); r.ic:SetPoint("LEFT", 6, 0)
    local ib = ns.RoundRect(r.ic, 5, { 0.23, 0.17, 0.16 }, "BACKGROUND", 0, 0); ib:SetColor({ 0.23, 0.17, 0.16 }, 1)
    r.icT = ns.Font(r.ic, 10, C.accHi); r.icT:SetPoint("CENTER", 0, 0)
    r.fs = ns.Font(r, 12); r.fs:SetPoint("LEFT", r.ic, "RIGHT", 7, 0)
    r.why = ns.Font(r, 10, { 0.55, 0.47, 0.45 }); r.why:SetPoint("LEFT", r.fs, "RIGHT", 6, 0)
    r.hide = IconBtn(r, ns.MEDIA .. "hb_c_view", function(self)
        local k = self:GetParent().k
        return (k and tmpHide[k.mover]) and "다시 보이기" or "이동 모드에서 잠깐 숨기기 (겹쳐서 뒤 창을 못 누를 때)"
    end, function(self)
        local k = self:GetParent().k
        if k then SetTmpHide(k, not tmpHide[k.mover]); ListPaint() end
    end)
    r.hide:SetPoint("RIGHT", -4, 0)
    r.reset = IconBtn(r, "Interface\\Buttons\\UI-RefreshButton", "크기 처음대로", function(self)
        local k = self:GetParent().k
        local it = k and k.sizeLabel and SizeItem(k.sizeLabel)
        local d = k and k.sizeLabel and SIZE_DEFAULT[k.sizeLabel]
        if it and d then pcall(it.set, d()); if sizeSel and sizeSel.mover == k.mover then SizePaint() end; ListPaint() end
    end)
    r.reset:SetPoint("RIGHT", r.hide, "LEFT", -4, 0)
    r.pct = ns.Num(r, 12, C.accHi); r.pct:SetPoint("RIGHT", r.reset, "LEFT", -8, 0)
    r:SetScript("OnEnter", function(self) if self.k then self.k.listHot = true; Paint(self.k); Wire(self, self.k) end end)
    r:SetScript("OnLeave", function(self) if self.k then self.k.listHot = false; Paint(self.k); Wire(nil) end end)
    r:SetScript("OnClick", function(self)
        local kk = self.k
        if not kk then return end
        if tmpHide[kk.mover] then SetTmpHide(kk, false) end
        if kk.sizeLabel and ns.MoveSelect then ns.MoveSelect(kk.mover, kk.sizeLabel, kk.title)
        else if ns.MoveSelect then ns.MoveSelect(nil) end; selMover = kk.mover; PaintAll() end
        if kk:IsVisible() then Flash(kk) end
        ListPaint()
    end)
    list.rows[i] = r
    return r
end
local function Head(i)
    local h = list.heads[i]
    if h then return h end
    h = CreateFrame("Frame", nil, list.body); h:SetHeight(18)
    h.fs = ns.Font(h, 10.5, { 0.66, 0.58, 0.565 }); h.fs:SetPoint("LEFT", 6, -2)
    h.n = ns.Font(h, 10.5, { 0.66, 0.58, 0.565 }); h.n:SetPoint("RIGHT", -6, -2)
    list.heads[i] = h
    return h
end

function ListPaint()
    if not list then return end
    local q = list.search:GetText() or ""
    local groups = { {}, {}, {} }
    local gname = {}
    for _, k in ipairs(skins) do
        if not k.part and (q == "" or (k.title or ""):find(q, 1, true)) then
            local gi, gn = Group(k.title or "")
            gname[gi] = gn
            table.insert(groups[gi], k)
        end
    end
    local y, ri, hi = -40, 0, 0
    for gi = 1, 3 do
        local g = groups[gi]
        if #g > 0 then
            hi = hi + 1
            local h = Head(hi)
            h.fs:SetText(gname[gi]); h.n:SetText(#g)
            h:ClearAllPoints(); h:SetPoint("TOPLEFT", 10, y); h:SetPoint("TOPRIGHT", -10, y); h:Show()
            y = y - 20
            for _, k in ipairs(g) do
                ri = ri + 1
                local r = Row(ri)
                r.k = k
                local vis = k.mover:IsShown() and k:IsVisible() or (tmpHide[k.mover] ~= nil)
                local sel = (selMover == k.mover)
                local th = tmpHide[k.mover] ~= nil
                r.fs:SetText(k.title or "?")
                r.icT:SetText((k.title or "?"):match("^[%z\1-\127\194-\244][\128-\191]*") or "?")
                local c = vis and C.tx or { 0.5, 0.45, 0.44 }
                r.fs:SetTextColor(c[1], c[2], c[3])
                r.why:SetText(not vis and Why(k) or (th and "숨김" or ""))
                local v = SizeOf(k)
                r.pct:SetText(v and (v .. "%") or "—")
                r.reset:SetShown(v ~= nil and SIZE_DEFAULT[k.sizeLabel] ~= nil)
                r.reset:SetAlpha(vis and 1 or 0.4)
                r.hide:SetShown(vis)
                r.hide.ic:SetVertexColor(th and PK[1] or 0.85, th and PK[2] or 0.8, th and PK[3] or 0.78, th and 1 or 0.8)
                r.hl:SetColor(PK, sel and 0.2 or 0)
                r.bar:SetShown(sel)
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 8, y); r:SetPoint("TOPRIGHT", -8, y)
                r:Show()
                y = y - LROW
            end
            y = y - 4
        end
    end
    for i = ri + 1, #list.rows do list.rows[i]:Hide() end
    for i = hi + 1, #list.heads do list.heads[i]:Hide() end
    list.empty:SetShown(ri == 0)
    if ri == 0 then y = y - 22 end
    list:SetHeight(-y + 8)
end

local function BuildList()
    list = CreateFrame("Frame", nil, UIParent)
    list:SetFrameStrata("FULLSCREEN_DIALOG"); list:SetWidth(LW); list:SetClampedToScreen(true)
    list:EnableMouse(true)
    ns.RoundPlate(list, 14, { 0.114, 0.082, 0.078, 0.97 }, { 0.949, 0.702, 0.761, 0.55 })
    list.body = CreateFrame("Frame", nil, list); list.body:SetAllPoints()
    list.rows, list.heads = {}, {}
    -- 찾기 칸
    local sb = CreateFrame("EditBox", nil, list)
    sb:SetHeight(24); sb:SetPoint("TOPLEFT", 10, -10); sb:SetPoint("TOPRIGHT", -10, -10)
    sb:SetAutoFocus(false); sb:SetFontObject(ChatFontNormal); sb:SetTextInsets(26, 8, 0, 0)
    local sbg = ns.RoundRect(sb, 12, { 0.07, 0.05, 0.047 }, "BACKGROUND", 0, 0); sbg:SetColor({ 0.07, 0.05, 0.047 }, 1)
    local si = sb:CreateTexture(nil, "ARTWORK"); si:SetTexture(ns.MEDIA .. "hb_search"); si:SetSize(12, 12); si:SetPoint("LEFT", 9, 0)
    si:SetVertexColor(0.6, 0.53, 0.51)
    local ph = ns.Font(sb, 11, { 0.48, 0.41, 0.39 }); ph:SetPoint("LEFT", 26, 0); ph:SetText("창 이름 찾기")
    sb:SetScript("OnTextChanged", function(self) ph:SetShown(self:GetText() == ""); ListPaint() end)
    sb:SetScript("OnEscapePressed", function(self)
        if self:GetText() ~= "" then self:SetText("") else self:ClearFocus() end
    end)
    sb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    list.search = sb
    list.empty = ns.Font(list, 11.5, { 0.6, 0.53, 0.51 }); list.empty:SetPoint("TOP", 0, -46); list.empty:SetText("찾는 창이 없어요")
    list:Hide()
end

local function ListBtnLook(open)
    if ns.MovePartBar and ns.moving then ns.MovePartBar() end
end

function ns.MoveListToggle(force)
    if not list then BuildList() end
    local open = force
    if open == nil then open = not list:IsShown() end
    if open then
        list:ClearAllPoints(); list:SetPoint("TOP", ns.moverBar, "BOTTOM", 0, -14)
        ListPaint()
        list:Show()
        -- 쓱 내려오기
        local t = 0
        list:SetAlpha(0)
        list:SetScript("OnUpdate", function(self, e)
            t = t + e
            local u = math.min(1, t / 0.15)
            local ez = 1 - (1 - u) ^ 3
            self:SetAlpha(ez)
            self:ClearAllPoints(); self:SetPoint("TOP", ns.moverBar, "BOTTOM", 0, -14 + 10 * (1 - ez))
            if u >= 1 then self:SetScript("OnUpdate", nil) end
        end)
    else
        list:SetScript("OnUpdate", nil)
        list.search:ClearFocus()
        list:Hide()
        Wire(nil)
        for _, k in ipairs(skins) do k.listHot = false end
        PaintAll()
    end
    ListBtnLook(open)
end
function ns.MoveListOpen() return list and list:IsShown() end
hooksecurefunc(ns, "MoveSelect", function() if list and list:IsShown() then ListPaint() end end)
hooksecurefunc(ns, "SetMoveMode", function()
    if not ns.moving then
        for mv, en in pairs(tmpHide) do mv:SetAlpha(1); mv:EnableMouse(en == 1); tmpHide[mv] = nil end
        if list then ns.MoveListToggle(false) end
    end
end)

----------------------------------------------------------------------
-- 되돌리기: 이동 모드를 켤 때 설정을 기억 → 되돌리면 다시 불러오기
----------------------------------------------------------------------
local snap
local function Copy(t, seen)
    if type(t) ~= "table" then return t end
    seen = seen or {}
    if seen[t] then return seen[t] end
    local o = {}; seen[t] = o
    for k2, v in pairs(t) do o[k2] = Copy(v, seen) end
    return o
end
StaticPopupDialogs["LEELUI_MOVE_UNDO"] = {
    text = "이동 모드를 켠 뒤 옮기고 바꾼 것을 모두 처음으로 되돌릴까요?\n(다시 불러오기를 해요)",
    button1 = "되돌리기", button2 = "취소",
    OnAccept = function()
        if not snap or not ns.db then return end
        for k2 in pairs(ns.db) do ns.db[k2] = nil end
        for k2, v in pairs(snap) do ns.db[k2] = v end
        ReloadUI()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}
function ns.MoveUndoAsk()
    if not snap then ns.Print("되돌릴 게 없어요.") return end
    StaticPopup_Show("LEELUI_MOVE_UNDO")
end

hooksecurefunc(ns, "SetMoveMode", function()
    Dim(ns.moving)
    if ns.moving then
        snap = Copy(ns.db)
        if ns.MoveFxEnter then ns.MoveFxEnter() end
        C_Timer.After(0, function() for _, k in ipairs(skins) do if k:IsVisible() then Fit(k) end end; PaintAll() end)
    else
        if ns.MoveFxExit then ns.MoveFxExit() end
        selMover = nil
        if list then list:Hide() end
    end
end)

----------------------------------------------------------------------
-- 상단 바 가운데: 고른 창이 없으면 안내 글씨, 크기 줄이 없는 창이면 이름만
----------------------------------------------------------------------
function ns.MoveBarCenter()
    local bar = ns.moverBar
    if not (bar and bar.pick) then return end
    if (sizeBar and sizeBar:IsShown()) or ns.movePartEdit then bar.pick:Hide() return end
    local k = selMover and selMover.leelSkin
    if k then
        bar.pick:SetText("고른 창  |cffffd6e0" .. (k.title or "") .. "|r  · 끌어서 옮기기")
    else
        bar.pick:SetText("창을 눌러 고르세요")
    end
    bar.pick:Show()
end

----------------------------------------------------------------------
-- 들어갈 때 효과 (1안): 바가 위에서 내려오고 → 화면이 어두워지며 격자 → 창 테두리가 차례로 톡톡
--   나갈 때 = 바가 올라가며 사라짐 · ns.db.moveFx == false 면 효과 없이 바로
----------------------------------------------------------------------
local fx = CreateFrame("Frame")
fx:Hide()
local function BarY(y)
    local bar = ns.moverBar
    bar:ClearAllPoints()
    bar:SetPoint("TOP", UIParent, "TOP", 0, y - 10)   -- 캡슐은 화면 위에서 10px 떠 있어요
end
local function Back(u) u = math.max(0, math.min(1, u)); local c = 1.6; return 1 + (c + 1) * (u - 1) ^ 3 + c * (u - 1) ^ 2 end
local function Ease(u) u = math.max(0, math.min(1, u)); return 1 - (1 - u) ^ 3 end
local function FxReset()
    fx:SetScript("OnUpdate", nil); fx:Hide()
    if ns.moverBar then BarY(0); ns.moverBar:SetAlpha(1) end
    if dim then dim:SetAlpha(1) end
    if grid then grid:SetAlpha(1) end
    for _, k in ipairs(skins) do k:SetAlpha(1); k.fxAt = nil end
end

function ns.MoveFxEnter()
    FxReset()
    if ns.db.moveFx == false then return end
    PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
    BarY(60)
    if dim then dim:SetAlpha(0) end
    if grid then grid:SetAlpha(0) end
    local t, order, started = 0, nil, false
    fx:Show()
    fx:SetScript("OnUpdate", function(self, e)
        t = t + e
        if not started then
            -- 한 프레임 뒤 (테두리들이 다 보인 다음) 화면 가운데에서 가까운 순서로 줄 세우기
            started = true
            order = {}
            local cx, cy = UIParent:GetCenter()
            for _, k in ipairs(skins) do
                if k:IsVisible() then
                    local x, y = k.mover:GetCenter()
                    local s2 = k.mover:GetEffectiveScale() / UIParent:GetEffectiveScale()
                    k.fxD = x and ((x * s2 - cx) ^ 2 + (y * s2 - cy) ^ 2) or 0
                    order[#order + 1] = k
                end
                k:SetAlpha(0)
            end
            table.sort(order, function(a2, b2) return a2.fxD < b2.fxD end)
            local step = math.min(0.05, 0.3 / math.max(#order, 1))
            for i, k in ipairs(order) do k.fxAt = 0.25 + (i - 1) * step end
        end
        BarY(60 * (1 - Back(t / 0.32)))   -- 살짝 튕기며 내려와요
        if dim then dim:SetAlpha(Ease(t / 0.3)) end
        if grid then grid:SetAlpha(Ease((t - 0.15) / 0.25)) end
        local busy = t < 0.4
        for _, k in ipairs(order or {}) do
            if k.fxAt then
                local u = (t - k.fxAt) / 0.12
                if u > 0 and not k.fxPop then k.fxPop = true; if k:IsVisible() then Flash(k) end end
                k:SetAlpha(Ease(u))
                if u < 1 then busy = true end
            end
        end
        if not busy then
            for _, k in ipairs(skins) do k.fxPop = nil end
            FxReset()
        end
    end)
end

function ns.MoveFxExit()
    FxReset()
    if ns.db.moveFx == false or not ns.moverBar then return end
    local bar = ns.moverBar
    -- 끝난 바를 잠깐 다시 보여 주고 위로 올려 보내요 (눌리지 않게 단추는 바로 숨김)
    for _, c in ipairs({ bar:GetChildren() }) do c:SetAlpha(0) end
    bar:Show()
    local t = 0
    fx:Show()
    fx:SetScript("OnUpdate", function(self, e)
        t = t + e
        local u = Ease(t / 0.18)
        BarY(60 * u); bar:SetAlpha(1 - u)
        if u >= 1 or ns.moving then
            if not ns.moving then bar:Hide() end
            for _, c in ipairs({ bar:GetChildren() }) do c:SetAlpha(1) end
            FxReset()
        end
    end)
end

----------------------------------------------------------------------
-- Leel HUD 2단계 고르기 (A안)
--   평소 = HUD 테두리 하나 (조각들을 다 감싸요) · 누르면 HUD 전체 · 끌면 통째로 · 휠/손잡이 = 전체 크기
--   두 번 누르기 또는 상단 바 [조각 편집] = 조각마다 테두리 (내 창 · 가운데 · 대상 창 · 펫 창 · 대상의 대상)
--     다른 창은 흐려짐 · 상단 바 = Leel HUD › [조각 칩] · Tab = 다음 조각 · Esc/[전체로] = 돌아가기
--   끌 때 = 하늘색 맞춤선 + 거리 숫자 · 놓으면 살짝 붙기
--   [좌우 대칭] = 내 창 ↔ 대상 창 거울처럼 같이 · [크기 같이] = 두 창 크기 같이
----------------------------------------------------------------------
ns.movePartEdit = false
local PART_ORDER = { "내 창", "가운데", "대상 창", "펫 창", "대상의 대상" }
local GUIDE = { 0.5, 0.84, 1 }

local function SkinBy(title)
    for _, k in ipairs(skins) do if k.title == title then return k end end
end
local function UIRect(f)
    -- 화면(UIParent) 단위의 사각형
    if not (f and f:IsVisible() and f:GetLeft()) then return nil end
    local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return { l = f:GetLeft() * s, r = f:GetRight() * s, t = f:GetTop() * s, b = f:GetBottom() * s }
end

-- HUD 테두리 = 조각들을 다 감싸는 상자 (흩어져 있어도 하나)
local function GroupFit()
    local hud, m = ns.hud, ns.mover
    if not (hud and m and ns.hudFrames and hud:GetLeft()) then return end
    local L, R, T, B
    local function add(f)
        local r = UIRect(f)
        if not r then return end
        L = L and math.min(L, r.l) or r.l; R = R and math.max(R, r.r) or r.r
        T = T and math.max(T, r.t) or r.t; B = B and math.min(B, r.b) or r.b
    end
    for _, p in ipairs(PARTS) do add(ns.hudFrames[p.key]) end
    for _, t in ipairs({ "펫 창", "대상의 대상" }) do
        local k = SkinBy(t)
        if k then add(k.mover:GetParent()) end
    end
    if not L then return end
    local hs = hud:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local hl, hb = hud:GetLeft() * hs, hud:GetBottom() * hs
    local pad = 6
    m:ClearAllPoints()
    m:SetPoint("BOTTOMLEFT", hud, "BOTTOMLEFT", (L - pad - hl) / hs, (B - pad - hb) / hs)
    m:SetPoint("TOPRIGHT", hud, "BOTTOMLEFT", (R + pad - hl) / hs, (T + pad - hb) / hs)
end

local dimmed = {}
function ns.MoveGroupApply()
    local m = ns.mover
    if not (m and ns.moving) then return end
    local pe = ns.movePartEdit
    -- 토끼 손잡이 · 점선은 이제 안 써요 (전체 = HUD 테두리, 다시 모으기 = 상단 바)
    if hub then hub:Hide() end
    if dotLayer then dotLayer:Hide() end
    if not pe then GroupFit() end
    m:EnableMouse(not pe)
    local k = m.leelSkin
    if k then k:Show(); k:SetAlpha(pe and 0.35 or 1) end
    for key, pm in pairs(partMovers or {}) do
        if type(key) == "string" then pm:SetShown(pe) end
    end
    for _, t in ipairs({ "펫 창", "대상의 대상" }) do
        local sk = SkinBy(t)
        if sk then sk.mover:SetShown(pe and sk.mover:GetParent():IsShown()) end
    end
    -- 조각 편집 중에는 다른 창을 흐리게 · 못 누르게
    for _, s2 in ipairs(skins) do
        local mv = s2.mover
        if not s2.part and mv ~= m then
            if pe and not dimmed[mv] then
                dimmed[mv] = mv:IsMouseEnabled() and 1 or 0
                mv:SetAlpha(0.25); mv:EnableMouse(false)
            elseif not pe and dimmed[mv] then
                mv:SetAlpha(1); mv:EnableMouse(dimmed[mv] == 1)
                dimmed[mv] = nil
            end
        end
    end
    if ns.MovePartBar then ns.MovePartBar() end
    if ns.MoveBarCenter then ns.MoveBarCenter() end
end

function ns.MovePartEdit(on)
    if not ns.moving then return end
    ns.movePartEdit = on and true or false
    if ns.MoveSelect then ns.MoveSelect(nil) end
    ns.MoveGroupApply()
    if on then
        local k = SkinBy("내 창")
        if k and k.sizeLabel then ns.MoveSelect(k.mover, k.sizeLabel, k.title) end
        for _, t in ipairs(PART_ORDER) do local s2 = SkinBy(t); if s2 and s2.mover:IsVisible() then Fit(s2); Flash(s2) end end
    end
end

-- 평소에도 HUD 테두리가 조각들을 따라가게 (가볍게 0.2초마다)
local gf = CreateFrame("Frame")
gf.t = 0
gf:SetScript("OnUpdate", function(self, e)
    self.t = self.t + e
    if self.t < 0.2 then return end
    self.t = 0
    if ns.moving and not ns.movePartEdit then GroupFit() end
end)

-- 두 번 누르기 = 조각 편집
C_Timer.After(0, function()
    local m = ns.mover
    if not m then return end
    m:HookScript("OnMouseDown", function()
        local now = GetTime()
        if m.lastDown and now - m.lastDown < 0.35 then
            m.lastDown = nil
            ns.MovePartEdit(true)
        else
            m.lastDown = now
        end
    end)
end)

hooksecurefunc(ns, "SetMoveMode", function()
    if not ns.moving then
        if ns.movePartEdit then ns.movePartEdit = false end
        for mv, en in pairs(dimmed) do mv:SetAlpha(1); mv:EnableMouse(en == 1); dimmed[mv] = nil end
        if ns.MovePartBar then ns.MovePartBar() end
        if ns.MoveGuides then ns.MoveGuides(nil) end
    else
        ns.movePartEdit = false
        -- 다른 테두리들이 자기 보이기를 정한 뒤에 (한 프레임 뒤)
        C_Timer.After(0, ns.MoveGroupApply)
    end
end)

----------------------------------------------------------------------
-- 조각 고르기 · Tab · 방향키
----------------------------------------------------------------------
local function SelectPart(k)
    if not (k and k.sizeLabel) then return end
    ns.MoveSelect(k.mover, k.sizeLabel, k.title)
    if k:IsVisible() then Flash(k) end
end
function ns.MovePartTab(back)
    local list = {}
    for _, t in ipairs(PART_ORDER) do local k = SkinBy(t); if k and k.mover:IsVisible() then list[#list + 1] = k end end
    if #list == 0 then return end
    local cur = 0
    for i, k in ipairs(list) do if k.mover == selMover then cur = i end end
    local n = cur + (back and -1 or 1)
    if n < 1 then n = #list elseif n > #list then n = 1 end
    SelectPart(list[n])
end
local function PartOf(mover)
    for _, p in ipairs(PARTS) do if partMovers and partMovers[p.key] == mover then return p end end
end
local function Mirror(key) return (key == "player" and "target") or (key == "target" and "player") or nil end
function ns.MovePartNudge(dx, dy)
    if not ns.movePartEdit or InCombatLockdown() then return false end
    local p = PartOf(selMover)
    if not p then return true end   -- 펫 · 대상의 대상은 자리가 HUD를 따라가요
    local o = ns.db.hudParts and ns.db.hudParts[p.key] or { p.dx, p.dy }
    ns.db.hudParts = ns.db.hudParts or {}
    ns.db.hudParts[p.key] = { o[1] + dx, o[2] + dy }
    local mk = ns.db.moveMirror and Mirror(p.key)
    if mk then ns.db.hudParts[mk] = { -(o[1] + dx), o[2] + dy } end
    ns:ApplyHudParts()
    return true
end

----------------------------------------------------------------------
-- 맞춤선 · 거리 숫자 · 놓으면 붙기 · 좌우 대칭
----------------------------------------------------------------------
local gl
local function GuideLayer()
    if gl then return gl end
    gl = CreateFrame("Frame", nil, UIParent)
    gl:SetAllPoints(); gl:SetFrameStrata("FULLSCREEN_DIALOG"); gl:EnableMouse(false)
    local function line()
        local t = gl:CreateTexture(nil, "OVERLAY"); t:SetColorTexture(GUIDE[1], GUIDE[2], GUIDE[3], 0.9); t:Hide(); return t
    end
    gl.v, gl.h, gl.d = line(), line(), line()
    gl.v:SetWidth(1); gl.h:SetHeight(1); gl.d:SetHeight(1)
    local function tag()
        local f = CreateFrame("Frame", nil, gl); f:SetSize(10, 16)
        f.bg = ns.RoundRect(f, 7, { 0.05, 0.13, 0.19 }, "BACKGROUND", 0, 0); f.bg:SetColor({ 0.05, 0.13, 0.19 }, 0.9)
        f.fs = ns.Font(f, 10.5, { 0.75, 0.92, 1 }); f.fs:SetPoint("CENTER")
        function f:Set(text) self.fs:SetText(text); self:SetWidth(self.fs:GetStringWidth() + 12); self:Show() end
        f:Hide()
        return f
    end
    gl.vt, gl.dt = tag(), tag()
    return gl
end
function ns.MoveGuides(off)
    if off == nil and gl then gl.v:Hide(); gl.h:Hide(); gl.d:Hide(); gl.vt:Hide(); gl.dt:Hide() end
end

local snapDX, snapDY = 0, 0
local function Guides(p, f)
    local g = GuideLayer()
    local me = UIRect(f)
    if not me then return end
    local mcx, mcy = (me.l + me.r) / 2, (me.t + me.b) / 2
    local W, H = UIParent:GetSize()
    local xs, ys = { { W / 2, "화면 가운데" } }, {}
    local others = {}
    for _, q in ipairs(PARTS) do
        if q ~= p and not (ns.db.moveMirror and Mirror(p.key) == q.key) then
            local r = UIRect(ns.hudFrames[q.key])
            if r then
                others[#others + 1] = r
                xs[#xs + 1] = { r.l }; xs[#xs + 1] = { r.r }; xs[#xs + 1] = { (r.l + r.r) / 2 }
                ys[#ys + 1] = { r.t, "높이 같음" }; ys[#ys + 1] = { r.b }; ys[#ys + 1] = { (r.t + r.b) / 2 }
            end
        end
    end
    local TH = 6
    local bx, bdx, blab = nil, TH + 1, nil
    for _, c in ipairs(xs) do
        for _, mine in ipairs({ me.l, me.r, mcx }) do
            local d = c[1] - mine
            if math.abs(d) < math.abs(bdx) then bx, bdx, blab = c[1], d, c[2] end
        end
    end
    local by, bdy = nil, TH + 1
    for _, c in ipairs(ys) do
        for _, mine in ipairs({ me.t, me.b, mcy }) do
            local d = c[1] - mine
            if math.abs(d) < math.abs(bdy) then by, bdy = c[1], d end
        end
    end
    snapDX = bx and bdx or 0
    snapDY = by and bdy or 0
    g.v:SetShown(bx ~= nil); g.h:SetShown(by ~= nil)
    if bx then g.v:ClearAllPoints(); g.v:SetPoint("TOP", UIParent, "TOPLEFT", bx, 0); g.v:SetHeight(H) end
    if by then g.h:ClearAllPoints(); g.h:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, by); g.h:SetWidth(W) end
    if bx and blab then g.vt:ClearAllPoints(); g.vt:SetPoint("TOPLEFT", UIParent, "TOPLEFT", bx + 4, -40); g.vt:Set(blab) else g.vt:Hide() end
    -- 옆 조각과 거리 (세로로 겹치는 가장 가까운 것)
    local best, gx1, gx2
    for _, r in ipairs(others) do
        if r.b < me.t and r.t > me.b then
            local gap, a, b2
            if r.l >= me.r then gap, a, b2 = r.l - me.r, me.r, r.l
            elseif r.r <= me.l then gap, a, b2 = me.l - r.r, r.r, me.l end
            if gap and (not best or gap < best) then best, gx1, gx2 = gap, a, b2 end
        end
    end
    if best and best > 2 then
        local y = me.b - 8
        g.d:ClearAllPoints(); g.d:SetPoint("LEFT", UIParent, "BOTTOMLEFT", gx1, y); g.d:SetWidth(gx2 - gx1); g.d:Show()
        g.dt:ClearAllPoints(); g.dt:SetPoint("TOP", UIParent, "BOTTOMLEFT", (gx1 + gx2) / 2, y - 3)
        g.dt:Set(math.floor(best + 0.5) .. "px")
    else
        g.d:Hide(); g.dt:Hide()
    end
end

-- 지금 끄는 조각의 HUD 기준 자리 (SavePart 와 같은 계산)
local function OffNow(p, f)
    local hud = ns.hud
    local k = f:GetScale()
    if p.point == "TOPLEFT" then return f:GetLeft() * k - hud:GetLeft(), f:GetTop() * k - hud:GetTop()
    elseif p.point == "TOPRIGHT" then return f:GetRight() * k - hud:GetRight(), f:GetTop() * k - hud:GetTop() end
    return (f:GetLeft() + f:GetRight()) / 2 * k - (hud:GetLeft() + hud:GetRight()) / 2, f:GetTop() * k - hud:GetTop()
end
local function MirrorLive(p, f)
    local mk = ns.db.moveMirror and Mirror(p.key)
    local mf = mk and ns.hudFrames[mk]
    if not mf then return end
    local x, y = OffNow(p, f)
    local sc = ns.HudPartScale(mk)
    local pt = (mk == "player") and "TOPLEFT" or "TOPRIGHT"
    mf:ClearAllPoints(); mf:SetPoint(pt, ns.hud, pt, -x / sc, y / sc)
end

function ns.MovePartDragStart(p, f) snapDX, snapDY = 0, 0 end
function ns.MovePartDragTick(p, f)
    Guides(p, f)
    MirrorLive(p, f)
end
function ns.MovePartDragStop(p, f)
    ns.MoveGuides(nil)
    if (snapDX ~= 0 or snapDY ~= 0) and f:GetNumPoints() > 0 then
        local pt, rel, rp, x, y = f:GetPoint(1)
        local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
        f:ClearAllPoints(); f:SetPoint(pt, rel, rp, x + snapDX / s, y + snapDY / s)
    end
    snapDX, snapDY = 0, 0
end
function ns.MovePartMirrorSave(p)
    local mk = ns.db.moveMirror and Mirror(p.key)
    local o = mk and ns.db.hudParts and ns.db.hudParts[p.key]
    if not o then return end
    ns.db.hudParts[mk] = { -o[1], o[2] }
    ns:ApplyHudParts()
end

-- 크기 같이: 내 창 ↔ 대상 창
do
    local orig = ns.SetHudPartScale
    ns.SetHudPartScale = function(key, v)
        orig(key, v)
        local mk = ns.db and ns.db.moveSizeLink and Mirror(key)
        if mk then orig(mk, v) end
    end
end

----------------------------------------------------------------------
-- 크기 끌 때 숫자 꼬리표 + 원래 크기 윤곽
----------------------------------------------------------------------
local tagF, ghost
function ns.MoveSizeTag(v, v0)
    if not v then if tagF then tagF:Hide() end return end
    if not tagF then
        tagF = CreateFrame("Frame", nil, UIParent); tagF:SetFrameStrata("TOOLTIP"); tagF:SetSize(10, 20)
        local bg = ns.RoundRect(tagF, 10, PK, "BACKGROUND", 0, 0); bg:SetColor(PK, 1)
        tagF.fs = ns.Font(tagF, 12, C.ink); tagF.fs:SetPoint("CENTER"); tagF.fs:SetShadowColor(0, 0, 0, 0)
    end
    tagF.fs:SetText(v .. "%  |cff5a3a40· 원래 " .. v0 .. "%|r")
    tagF:SetWidth(tagF.fs:GetStringWidth() + 18)
    local s = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    tagF:ClearAllPoints(); tagF:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s + 16, y / s - 10)
    tagF:Show()
end
function ns.MoveGhost(mover)
    if not mover then if ghost then ghost:Hide() end return end
    if not ghost then
        ghost = CreateFrame("Frame", nil, UIParent); ghost:SetFrameStrata("FULLSCREEN"); ghost:EnableMouse(false)
        for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
            local e = ghost:CreateTexture(nil, "OVERLAY"); e:SetColorTexture(PK[1], PK[2], PK[3], 0.4)
            if side == "TOP" or side == "BOTTOM" then e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(1)
            else e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(1) end
        end
    end
    local r = UIRect(mover)
    if not r then return end
    ghost:ClearAllPoints()
    ghost:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", r.l, r.b)
    ghost:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", r.r, r.t)
    ghost:Show()
end

----------------------------------------------------------------------
-- 상단 바: 평소 [조각 편집] · 조각 편집 중 = Leel HUD › [칩들] … [좌우 대칭] [크기 같이] [HUD 모으기] [전체로] | 완료
----------------------------------------------------------------------
----------------------------------------------------------------------
-- 상단 바 A안: 떠 있는 유리 캡슐 + 아이콘
--   [토끼 구슬] 이동 모드 ●편집 중 | 고른 창 칩 | 격자 · 조각 · 되돌리기 · 목록 | [✓ 완료]
--   조각 편집: [토끼] 조각 편집 Leel HUD | [내 창|가운데|대상 창|펫 창|대상의 대상] − 100% + | 좌우 대칭 · 크기 같이 · 모으기 | 전체로 [✓ 완료]
----------------------------------------------------------------------
local ui
local DARK = { 0.13, 0.097, 0.093 }

-- 말풍선 (아이콘 아래)
local bubble
local function Bubble(owner, text)
    if not bubble then
        bubble = CreateFrame("Frame", nil, UIParent); bubble:SetFrameStrata("TOOLTIP"); bubble:SetHeight(20)
        local e = ns.RoundRect(bubble, 7, PK, "BACKGROUND", 0, -1); e:SetColor(PK, 0.45)
        local f = ns.RoundRect(bubble, 7, { 0.05, 0.035, 0.035 }, "BACKGROUND", 1, 0); f:SetColor({ 0.05, 0.035, 0.035 }, 0.97)
        bubble.fs = ns.Font(bubble, 11, C.tx); bubble.fs:SetPoint("CENTER")
    end
    if not owner then bubble:Hide() return end
    bubble.fs:SetText(text); bubble:SetWidth(bubble.fs:GetStringWidth() + 16)
    bubble:ClearAllPoints(); bubble:SetPoint("TOP", owner, "BOTTOM", 0, -6); bubble:Show()
end

local function IconB(tex, tip, fn)
    local b = CreateFrame("Button", nil, ns.moverBar); b:SetSize(34, 34)
    b.bg = b:CreateTexture(nil, "BACKGROUND", nil, 2); b.bg:SetTexture(ns.MEDIA .. "circle"); b.bg:SetAllPoints()
    b.ring = b:CreateTexture(nil, "BACKGROUND", nil, 1); b.ring:SetTexture(ns.MEDIA .. "circle"); b.ring:SetPoint("TOPLEFT", -1, 1); b.ring:SetPoint("BOTTOMRIGHT", 1, -1)
    b.ic = b:CreateTexture(nil, "ARTWORK"); b.ic:SetTexture(ns.MEDIA .. tex); b.ic:SetSize(17, 17); b.ic:SetPoint("CENTER")
    b.tip = tip
    function b:Look()
        local on, h = self.on, self.hover
        self.bg:SetVertexColor(on and PK[1] or 1, on and PK[2] or 1, on and PK[3] or 1, on and 0.2 or (h and 0.08 or 0))
        self.ring:SetVertexColor(PK[1], PK[2], PK[3], on and 0.75 or 0)
        local c = on and C.accHi or (h and { 1, 1, 1 } or C.tx)
        self.ic:SetVertexColor(c[1], c[2], c[3], 1)
        self.ic:ClearAllPoints(); self.ic:SetPoint("CENTER", 0, h and 1 or 0)   -- 마우스 = 살짝 떠오르기
    end
    b:SetScript("OnEnter", function(self) self.hover = true; self:Look(); Bubble(self, type(self.tip) == "function" and self.tip() or self.tip) end)
    b:SetScript("OnLeave", function(self) self.hover = false; self:Look(); Bubble(nil) end)
    b:SetScript("OnClick", function(self) fn(self); self:Look(); if self.hover then Bubble(self, type(self.tip) == "function" and self.tip() or self.tip) end end)
    b:Look()
    return b
end

local function Pill(text, primary, fn)
    local b = CreateFrame("Button", nil, ns.moverBar); b:SetHeight(32)
    b.glow = b:CreateTexture(nil, "BACKGROUND", nil, -2); b.glow:SetTexture(ns.MEDIA .. "soft_glow"); b.glow:SetBlendMode("ADD")
    b.glow:SetPoint("TOPLEFT", -12, 12); b.glow:SetPoint("BOTTOMRIGHT", 12, -12); b.glow:SetVertexColor(PK[1], PK[2], PK[3], primary and 0.45 or 0)
    b.edge = ns.RoundRect(b, 16, PK, "BACKGROUND", 0, -1)
    b.fill = ns.RoundRect(b, 16, PK, "BACKGROUND", 1, 0)
    b.fs = ns.Font(b, 12.5, primary and C.ink or C.tx); b.fs:SetShadowColor(0, 0, 0, primary and 0 or 0.8); b.fs:SetText(text)
    if primary then
        b.ic = b:CreateTexture(nil, "ARTWORK"); b.ic:SetTexture(ns.MEDIA .. "mv_check"); b.ic:SetSize(14, 14); b.ic:SetPoint("LEFT", 12, 0)
        b.ic:SetVertexColor(C.ink[1], C.ink[2], C.ink[3])
        b.fs:SetPoint("LEFT", b.ic, "RIGHT", 5, 0)
        b:SetWidth(12 + 14 + 5 + b.fs:GetStringWidth() + 14)
    else
        b.fs:SetPoint("CENTER")
        b:SetWidth(b.fs:GetStringWidth() + 28)
    end
    function b:Look()
        local h = self.hover
        if primary then
            self.fill:SetColor(h and C.accHi or PK, 1); self.edge:SetColor(C.accHi, 1)
        else
            self.fill:SetColor(h and { 0.24, 0.18, 0.17 } or { 0.17, 0.13, 0.125 }, 1); self.edge:SetColor(h and PK or { 0.29, 0.22, 0.21 }, h and 0.8 or 1)
        end
    end
    b:SetScript("OnEnter", function(self) self.hover = true; self:Look() end)
    b:SetScript("OnLeave", function(self) self.hover = false; self:Look() end)
    b:SetScript("OnClick", fn)
    b:Look()
    return b
end

local function Sep()
    local t = ns.moverBar:CreateTexture(nil, "ARTWORK"); t:SetTexture(ns.WHITE); t:SetSize(1, 22)
    pcall(t.SetGradient, t, "VERTICAL", CreateColor(PK[1], PK[2], PK[3], 0), CreateColor(PK[1], PK[2], PK[3], 0.55))
    t.isSep = true
    return t
end

-- 조각 칩 (한 덩어리 구획 단추)
local function BuildSeg()
    local seg = CreateFrame("Frame", nil, ns.moverBar); seg:SetHeight(28)
    local bg = ns.RoundRect(seg, 14, { 0.06, 0.045, 0.042 }, "BACKGROUND", 0, 0); bg:SetColor({ 0.06, 0.045, 0.042 }, 0.8)
    seg.chips = {}
    local x = 3
    for _, t in ipairs(PART_ORDER) do
        local c = CreateFrame("Button", nil, seg); c:SetHeight(22)
        c.sel = ns.RoundRect(c, 11, PK, "BACKGROUND", 1, 0)
        c.fs = ns.Font(c, 11.5, C.tx); c.fs:SetPoint("CENTER"); c.fs:SetText(t)
        c:SetWidth(c.fs:GetStringWidth() + 20)
        c:SetPoint("LEFT", x, 0); x = x + c:GetWidth()
        c.title = t
        c:SetScript("OnClick", function() SelectPart(SkinBy(t)) end)
        c:SetScript("OnEnter", function(self) if not self.on then self.fs:SetTextColor(1, 1, 1) end end)
        c:SetScript("OnLeave", function(self) if not self.on then local cc = self.vis and C.tx or { 0.45, 0.4, 0.39 }; self.fs:SetTextColor(cc[1], cc[2], cc[3]) end end)
        seg.chips[#seg.chips + 1] = c
    end
    seg:SetWidth(x + 3)
    return seg
end

local function BuildUI()
    local bar = ns.moverBar
    if ui or not bar then return end
    ui = {}
    -- 예전 단추 · 글씨 · 바탕은 모두 숨김
    for _, c in ipairs({ bar:GetChildren() }) do if c ~= sizeBar then c:Hide(); c.leelOld = true end end
    for _, r in ipairs({ bar:GetRegions() }) do if r ~= bar.pick then r:Hide() end end
    bar:SetHeight(44)
    -- 캡슐 모양: 바깥 분홍 빛 · 그림자 · 분홍 테 · 어두운 몸 · 위쪽 빛 한 줄 · 아래 분홍 빛줄
    local shd = bar:CreateTexture(nil, "BACKGROUND", nil, -8); shd:SetTexture(ns.MEDIA .. "soft_glow")
    shd:SetPoint("TOPLEFT", -30, 14); shd:SetPoint("BOTTOMRIGHT", 30, -26); shd:SetVertexColor(0, 0, 0, 0.7)
    local glo = bar:CreateTexture(nil, "BACKGROUND", nil, -7); glo:SetTexture(ns.MEDIA .. "soft_glow"); glo:SetBlendMode("ADD")
    glo:SetPoint("TOPLEFT", -26, 20); glo:SetPoint("BOTTOMRIGHT", 26, -20); glo:SetVertexColor(PK[1], PK[2], PK[3], 0.16)
    local edge = ns.RoundRect(bar, 22, PK, "BACKGROUND", -6, -1); edge:SetColor(PK, 0.42)
    local body = ns.RoundRect(bar, 22, DARK, "BACKGROUND", -5, 0); body:SetColor(DARK, 0.96)
    local hi = bar:CreateTexture(nil, "BORDER"); hi:SetColorTexture(1, 1, 1, 0.07); hi:SetHeight(1)
    hi:SetPoint("TOPLEFT", 20, -1); hi:SetPoint("TOPRIGHT", -20, -1)
    local ul = CreateFrame("Frame", nil, bar); ul:SetSize(260, 2); ul:SetPoint("TOP", bar, "BOTTOM", 0, -6)
    local u1 = ul:CreateTexture(nil, "ARTWORK"); u1:SetTexture(ns.WHITE); u1:SetPoint("TOPLEFT"); u1:SetPoint("BOTTOMRIGHT", ul, "BOTTOM", 0, 0)
    pcall(u1.SetGradient, u1, "HORIZONTAL", CreateColor(PK[1], PK[2], PK[3], 0), CreateColor(PK[1], PK[2], PK[3], 0.9))
    local u2 = ul:CreateTexture(nil, "ARTWORK"); u2:SetTexture(ns.WHITE); u2:SetPoint("TOPLEFT", ul, "TOP", 0, 0); u2:SetPoint("BOTTOMRIGHT")
    pcall(u2.SetGradient, u2, "HORIZONTAL", CreateColor(PK[1], PK[2], PK[3], 0.9), CreateColor(PK[1], PK[2], PK[3], 0))
    -- 토끼 구슬
    local orb = CreateFrame("Frame", nil, bar); orb:SetSize(32, 32)
    local og = orb:CreateTexture(nil, "BACKGROUND"); og:SetTexture(ns.MEDIA .. "soft_glow"); og:SetBlendMode("ADD")
    og:SetPoint("TOPLEFT", -10, 10); og:SetPoint("BOTTOMRIGHT", 10, -10); og:SetVertexColor(PK[1], PK[2], PK[3], 0.6)
    local od = orb:CreateTexture(nil, "BORDER"); od:SetTexture(ns.MEDIA .. "circle"); od:SetAllPoints(); od:SetVertexColor(PK[1], PK[2], PK[3], 1)
    local oh = orb:CreateTexture(nil, "BORDER", nil, 1); oh:SetTexture(ns.MEDIA .. "circle"); oh:SetSize(18, 14); oh:SetPoint("TOPLEFT", 5, -4)
    oh:SetVertexColor(1, 0.9, 0.93, 0.45)
    local ob = orb:CreateTexture(nil, "ARTWORK"); ob:SetTexture(ns.MEDIA .. "bunny"); ob:SetPoint("TOPLEFT", 4, -4); ob:SetPoint("BOTTOMRIGHT", -4, 4)
    ui.orb = orb
    -- 이동 모드 · ●편집 중
    local mb = CreateFrame("Frame", nil, bar); mb:SetHeight(30)
    mb.t = ns.Font(mb, 12.5, C.accHi); mb.t:SetPoint("TOPLEFT", 0, -1)
    mb.dot = mb:CreateTexture(nil, "ARTWORK"); mb.dot:SetTexture(ns.MEDIA .. "circle"); mb.dot:SetSize(6, 6); mb.dot:SetPoint("BOTTOMLEFT", 1, 4)
    mb.dot:SetVertexColor(0.5, 0.89, 0.63)
    mb.s = ns.Font(mb, 10, { 0.66, 0.58, 0.565 }); mb.s:SetPoint("BOTTOMLEFT", 10, 1)
    mb:EnableMouse(true)
    mb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); ns.TSet(GameTooltip, "이동 모드")
        ns.TAdd(GameTooltip, "분홍 점선 창 = 끌어서 옮기기 · 누르면 고르기 · 휠/모서리 = 크기", 1, 1, 1)
        ns.TAdd(GameTooltip, "방향키 1칸 · Shift 10칸 · Esc = 끝 (조각 편집 중엔 전체로)", 1, 1, 1)
        ns.TAdd(GameTooltip, "HUD 테두리 두 번 누르기 = 조각 편집 · Tab = 다음 조각", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    mb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ui.mode = mb
    ui.seps = { Sep(), Sep(), Sep() }
    -- 아이콘 단추
    ui.grid = IconB("mv_grid", function() return ns.db.grid and "격자 끄기" or "격자 켜기" end, function()
        ns.db.grid = not ns.db.grid; ShowGrid(ns.db.grid); ns.MovePartBar()
    end)
    ui.parts = IconB("mv_parts", "조각 편집 (HUD 나눠서 옮기기)", function() ns.MovePartEdit(true) end)
    ui.undo = IconB("mv_undo", "되돌리기 (이동 모드 켠 때로)", function() if ns.MoveUndoAsk then ns.MoveUndoAsk() end end)
    ui.list = IconB("mv_list", "목록", function() if ns.MoveListToggle then ns.MoveListToggle() end end)
    ui.mirror = IconB("mv_mirror", function() return "좌우 대칭: " .. (ns.db.moveMirror and "켬" or "끔") .. " (내 창 ↔ 대상 창 거울처럼)" end, function()
        ns.db.moveMirror = not ns.db.moveMirror
        if ns.db.moveMirror then
            local o = ns.db.hudParts and ns.db.hudParts.player
            if o then ns.db.hudParts.target = { -o[1], o[2] }; ns:ApplyHudParts() end
        end
        ns.MovePartBar()
    end)
    ui.link = IconB("mv_link", function() return "크기 같이: " .. (ns.db.moveSizeLink and "켬" or "끔") .. " (내 창 · 대상 창)" end, function()
        ns.db.moveSizeLink = not ns.db.moveSizeLink
        if ns.db.moveSizeLink then ns.SetHudPartScale("player", math.floor(ns.HudPartScale("player") * 100 + 0.5)) end
        ns.MovePartBar()
    end)
    ui.join = IconB("mv_join", "HUD 모으기 (조각을 처음 모양으로)", function() ns:ResetHudParts() end)
    ui.back = Pill("전체로", false, function() ns.MovePartEdit(false) end)
    ui.done = Pill("완료", true, function(self)
        -- 체크 한 번 반짝 → 끝
        self.ic:SetVertexColor(1, 1, 1); self.glow:SetVertexColor(1, 1, 1, 0.8)
        C_Timer.After(0.12, function()
            self.ic:SetVertexColor(C.ink[1], C.ink[2], C.ink[3]); self.glow:SetVertexColor(PK[1], PK[2], PK[3], 0.45)
            if ns.moving then ns:SetMoveMode(false) end
        end)
    end)
    ui.seg = BuildSeg()
    bar.pick:SetTextColor(0.66, 0.58, 0.565)
    bar:SetScript("OnSizeChanged", nil)
end

function ns.MovePartBar()
    local bar = ns.moverBar
    if not bar then return end
    BuildUI()
    if not ui then return end
    local on = ns.movePartEdit and ns.moving
    ui.mode.t:SetText(on and "조각 편집" or "이동 모드")
    ui.mode.dot:SetShown(not on)
    ui.mode.s:ClearAllPoints(); ui.mode.s:SetPoint("BOTTOMLEFT", on and 0 or 10, 1)
    ui.mode.s:SetText(on and "Leel HUD" or "편집 중")
    ui.mode:SetWidth(math.max(ui.mode.t:GetStringWidth(), ui.mode.s:GetStringWidth() + (on and 0 or 10)) + 2)
    ui.grid.on = ns.db.grid and true or false
    ui.list.on = (ns.MoveListOpen and ns.MoveListOpen()) and true or false
    ui.mirror.on = ns.db.moveMirror and true or false
    ui.link.on = ns.db.moveSizeLink and true or false
    for _, k in ipairs({ "grid", "parts", "undo", "list", "mirror", "link", "join" }) do ui[k]:Look() end
    for _, k in ipairs({ "grid", "parts", "undo", "list", "mirror", "link", "join", "back", "seg" }) do ui[k]:Hide() end
    local row = { ui.orb, ui.mode, ui.seps[1] }
    if on then
        ui.seg:Show(); row[#row + 1] = ui.seg
        row[#row + 1] = "SIZE"; row[#row + 1] = ui.seps[2]
        for _, k in ipairs({ "mirror", "link", "join" }) do ui[k]:Show(); row[#row + 1] = ui[k] end
        row[#row + 1] = ui.seps[3]
        ui.back:Show(); row[#row + 1] = ui.back
    else
        row[#row + 1] = "SIZE"; row[#row + 1] = ui.seps[2]
        for _, k in ipairs({ "grid", "parts", "undo", "list" }) do ui[k]:Show(); row[#row + 1] = ui[k] end
        row[#row + 1] = ui.seps[3]
    end
    row[#row + 1] = ui.done
    bar.row = row
    for _, c in ipairs(ui.seg.chips) do
        local k = SkinBy(c.title)
        c.vis = k and k.mover:IsVisible()
        c.on = k and selMover == k.mover
        c.sel:SetColor(PK, c.on and 1 or 0)
        local cc = c.on and C.ink or (c.vis and C.tx or { 0.45, 0.4, 0.39 })
        c.fs:SetTextColor(cc[1], cc[2], cc[3]); c.fs:SetShadowColor(0, 0, 0, c.on and 0 or 0.8)
    end
    if sizeBar then sizeBar.cap:SetShown(not on); sizeBar.title:SetShown(not on) end
end

-- 줄 세우기 (폭이 바뀌어도 늘 가운데)
local function RowLayout(bar)
    local row = bar.row
    if not row then return end
    local x = 6
    for idx, it in ipairs(row) do
        local gap = 6
        if it == "SIZE" then
            if sizeBar and sizeBar:IsShown() then
                sizeBar:ClearAllPoints(); sizeBar:SetPoint("LEFT", bar, "LEFT", x, 0)
                x = x + sizeBar:GetWidth() + gap
            elseif bar.pick:IsShown() then
                bar.pick:ClearAllPoints(); bar.pick:SetPoint("LEFT", bar, "LEFT", x + 4, 0)
                x = x + bar.pick:GetStringWidth() + 8 + gap
            end
        else
            if it.isSep then x = x + 2 end
            it:ClearAllPoints(); it:SetPoint("LEFT", bar, "LEFT", x, 0)
            if it.isSep then it:Show() end
            local w = it:GetWidth()
            x = x + w + gap + (it.isSep and 2 or 0) + (it == ui.orb and 2 or 0) + (it == ui.mode and 4 or 0)
            if it.isIcon then x = x - 4 end
        end
    end
    bar:SetWidth(x - 6 + 6)
end

local barSkinned
local function BarSkin()
    local bar = ns.moverBar
    if barSkinned or not bar then return end
    barSkinned = true
    BuildUI()
    bar:ClearAllPoints(); bar:SetPoint("TOP", UIParent, "TOP", 0, -10)
    bar:HookScript("OnUpdate", RowLayout)
    -- 예전 단추가 다시 보이지 않게
    for _, c in ipairs({ bar:GetChildren() }) do if c.leelOld then c:Hide() end end
    ns.MovePartBar()
end
do
    local origFx = ns.MoveFxEnter
    ns.MoveFxEnter = function() BarSkin(); if ns.MovePartBar then ns.MovePartBar() end; RowLayout(ns.moverBar); origFx() end
end
hooksecurefunc(ns, "SetMoveMode", function() if ns.moving then BarSkin() end end)
hooksecurefunc(ns, "MoveSelect", function() if ns.moving and ns.MovePartBar then ns.MovePartBar() end end)
