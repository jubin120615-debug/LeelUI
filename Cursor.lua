-- LeelUI / Cursor.lua
-- 마우스 효과: ① 클릭 퐁  ② 반짝 꼬리  ③ 가리키는 것에 따라 작은 반응
-- 커서 그림 자체는 못 바꿔서, 커서 위치를 따라 둘레에 그림을 그려요.
-- 허브 > 화면 > 마우스: ns.db.cfxClick / cfxReact / cfxTrail (기본 켬)
local ADDON, ns = ...

local M = ns.MEDIA or ("Interface\\AddOns\\" .. ADDON .. "\\media\\")
local PINK  = { 0.95, 0.70, 0.76 }
local CREAM = { 1.00, 0.89, 0.63 }
local RED   = { 1.00, 0.42, 0.42 }
local GOLD  = { 1.00, 0.83, 0.30 }
local DOT   = { 1.00, 0.84, 0.88 }

local fx = CreateFrame("Frame", nil, UIParent)
fx:SetAllPoints(UIParent)
fx:SetFrameStrata("TOOLTIP")
fx:SetFrameLevel(9000)
fx:EnableMouse(false)

local function On(k) return not (ns.db and ns.db[k] == false) end

-- 커서 위치 (UIParent 좌표)
local function CursorXY()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
end

----------------------------------------------------------------------
-- 조각 (그림 하나가 잠깐 살다 사라짐)
----------------------------------------------------------------------
local pool, live = {}, {}
local function Spawn(tex, x, y, o)
    local p = table.remove(pool)
    if not p then
        p = { t = fx:CreateTexture(nil, "OVERLAY") }
    end
    local t = p.t
    t:SetTexture(M .. tex)
    t:SetBlendMode(o.add and "ADD" or "BLEND")
    local c = o.c or PINK
    t:SetVertexColor(c[1], c[2], c[3], 1)
    p.x, p.y = x, y
    p.vx, p.vy = o.vx or 0, o.vy or 0
    p.g = o.g or 0
    p.s0, p.s1 = o.s0 or 10, o.s1 or o.s0 or 10
    p.a0, p.a1 = o.a0 or 1, o.a1 or 0
    p.life, p.age = o.life or 0.4, 0
    p.spin = o.spin
    t:SetRotation(0)
    t:Show()
    live[#live + 1] = p
    return p
end

local function Step(dt)
    for i = #live, 1, -1 do
        local p = live[i]
        p.age = p.age + dt
        local k = p.age / p.life
        if k >= 1 then
            p.t:Hide()
            pool[#pool + 1] = table.remove(live, i)
        else
            local e = 1 - (1 - k) * (1 - k)       -- 처음 빠르고 끝에 느리게
            p.vy = p.vy - p.g * dt
            p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
            local s = p.s0 + (p.s1 - p.s0) * e
            p.t:SetSize(s, s)
            p.t:ClearAllPoints()
            p.t:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p.x, p.y)
            p.t:SetAlpha(p.a0 + (p.a1 - p.a0) * k)
            if p.spin then p.t:SetRotation(p.spin * p.age) end
        end
    end
end

----------------------------------------------------------------------
-- ① 클릭 퐁: 짧게 눌렀다 뗐을 때만 (카메라 돌리기 끌기는 빼요)
----------------------------------------------------------------------
local function Pop(x, y, right)
    local c = right and CREAM or PINK
    Spawn("ring", x, y, { c = c, s0 = 6, s1 = 46, a0 = 1, a1 = 0, life = 0.38 })
    Spawn("circle", x, y, { c = c, s0 = 10, s1 = 2, a0 = 0.8, a1 = 0, life = 0.18, add = true })
    local n = right and 2 or 3
    for i = 1, n do
        local ang = math.rad(60 + (i - 1) * (60 / math.max(n - 1, 1)) + math.random(-12, 12))
        local sp = math.random(70, 110)
        Spawn("fx_heart", x, y, { c = c, s0 = 9, s1 = 13, a0 = 1, a1 = 0, life = 0.55,
            vx = math.cos(ang) * sp, vy = math.sin(ang) * sp, g = 160 })
    end
end

local press = {}
local function CheckButton(btn, right, now)
    local down = IsMouseButtonDown(btn)
    local p = press[btn]
    if down and not p then
        local x, y = CursorXY()
        press[btn] = { t = now, x = x, y = y }
    elseif not down and p then
        press[btn] = nil
        local x, y = CursorXY()
        if now - p.t < 0.3 and math.abs(x - p.x) + math.abs(y - p.y) < 12 then
            Pop(x, y, right)
        end
    end
end

----------------------------------------------------------------------
-- ② 반짝 꼬리: 움직일 때만
----------------------------------------------------------------------
local lastX, lastY, trailAcc, trailN = nil, nil, 0, 0
local function Trail(x, y, dt)
    if not lastX then lastX, lastY = x, y; return end
    local dx, dy = x - lastX, y - lastY
    local dist = math.sqrt(dx * dx + dy * dy)
    lastX, lastY = x, y
    if dt <= 0 or dist / dt < 120 then return end
    trailAcc = trailAcc + dist
    while trailAcc >= 9 do
        trailAcc = trailAcc - 9
        trailN = trailN + 1
        local f = trailAcc / math.max(dist, 1)
        local px, py = x - dx * f, y - dy * f
        if trailN % 7 == 0 then
            Spawn("fx_star", px + math.random(-6, 6), py + math.random(-6, 6),
                { c = { 1, 0.95, 0.80 }, s0 = 12, s1 = 4, a0 = 0.95, a1 = 0, life = 0.45, add = true, spin = 3 })
        else
            Spawn("circle", px, py, { c = DOT, s0 = 7, s1 = 1.5, a0 = 0.75, a1 = 0, life = 0.35 })
        end
    end
end

----------------------------------------------------------------------
-- ③ 가리키는 것에 따라 반응 (게임 화면 위에서만)
----------------------------------------------------------------------
local OX, OY = 11, -12          -- 커서 끝(왼쪽 위)에서 그림 가운데쪽으로
local react = CreateFrame("Frame", nil, fx)
react:SetSize(1, 1)
react:Hide()
local spin = react:CreateTexture(nil, "OVERLAY")
spin:SetTexture(M .. "fx_dash"); spin:SetSize(40, 40); spin:SetPoint("CENTER")
local heart = react:CreateTexture(nil, "OVERLAY")
heart:SetTexture(M .. "fx_heart"); heart:SetSize(13, 13); heart:SetPoint("CENTER", 18, 14)

local function Safe(f, ...)
    local ok, v = pcall(f, ...)
    if not ok then return nil end
    local ok2, plain = pcall(function() return v and true or false end)
    return ok2 and plain or nil
end

local function OverWorld()
    local foc
    if GetMouseFoci then
        local t = GetMouseFoci(); foc = t and t[1]
    elseif GetMouseFocus then
        foc = GetMouseFocus()
    end
    return foc == nil or foc == WorldFrame
end

local mode, sparkT, reactT = nil, 0, 0
local function ReadMode()
    if not OverWorld() or not UnitExists("mouseover") then return nil end
    if Safe(UnitIsDead, "mouseover") then
        local guid = UnitGUID("mouseover")
        if CanLootUnit and guid then
            local ok, has = pcall(CanLootUnit, guid)
            if ok and has then return "loot" end
        end
        return nil
    end
    if Safe(UnitCanAttack, "player", "mouseover") then return "enemy" end
    if not Safe(UnitIsPlayer, "mouseover") and Safe(UnitIsFriend, "player", "mouseover") then return "npc" end
    return nil
end

local function React(x, y, dt)
    reactT = reactT + dt
    if reactT > 0.1 then reactT = 0; mode = ReadMode() end
    if not mode then react:Hide(); return end
    react:ClearAllPoints()
    react:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x + OX, y + OY)
    react:Show()
    local tm = GetTime()
    if mode == "enemy" then
        spin:Show(); heart:Hide()
        spin:SetVertexColor(RED[1], RED[2], RED[3], 0.9)
        spin:SetRotation(-tm * 1.2)
    elseif mode == "npc" then
        spin:Hide(); heart:Show()
        heart:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
        local b = 1 + 0.12 * math.sin(tm * 6)
        heart:SetSize(13 * b, 13 * b)
    else  -- loot: 별이 반짝
        spin:Hide(); heart:Hide()
        sparkT = sparkT - dt
        if sparkT <= 0 then
            sparkT = 0.28
            Spawn("fx_star", x + OX + math.random(-18, 20), y + OY + math.random(-16, 18),
                { c = { 1, 0.95, 0.75 }, s0 = 4, s1 = 14, a0 = 1, a1 = 0, life = 0.5, add = true, spin = 2 })
        end
    end
end

----------------------------------------------------------------------
-- 돌리기
----------------------------------------------------------------------
fx:SetScript("OnUpdate", function(_, dt)
    local db = ns.db
    -- 예전 한 줄 설정(cursorFx 0/1/2)을 세 스위치로 옮겨요
    if db and db.cursorFx ~= nil then
        if db.cursorFx == 0 then db.cfxClick, db.cfxReact, db.cfxTrail = false, false, false
        elseif db.cursorFx == 1 then db.cfxTrail = false end
        db.cursorFx = nil
    end
    local click, rea, trail = On("cfxClick"), On("cfxReact"), On("cfxTrail")
    local hidden = IsMouselooking and IsMouselooking()
    local x, y = CursorXY()
    if not hidden then
        local now = GetTime()
        if click then
            CheckButton("LeftButton", false, now)
            CheckButton("RightButton", true, now)
        else
            press.LeftButton, press.RightButton = nil, nil
        end
        if trail then Trail(x, y, dt) else lastX = nil end
        if rea then React(x, y, dt) else react:Hide() end
    else
        press.LeftButton, press.RightButton = nil, nil
        lastX = nil; react:Hide()
    end
    if #live > 0 then Step(dt) end
end)

function ns.CursorFxRefresh()
    if not On("cfxReact") then react:Hide() end
end
