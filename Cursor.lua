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

-- 허브 > 마우스 세부 설정 (기본값 = 지금 모습)
local CFX_DEF = { size = 100, col = "pink", shape = "heart", trail = "mid", combat = "on", find = false }
local function CO(k)
    local t = ns.db and ns.db.cfxO
    local v = t and t[k]
    if v == nil then return CFX_DEF[k] end
    return v
end
ns.CfxOpt = CO
function ns.SetCfxOpt(k, v) ns.db.cfxO = ns.db.cfxO or {}; ns.db.cfxO[k] = v end
-- 색: 분홍(기본 · 오른클릭은 크림) · 직업 색 · 흰색
local function Col(base)
    local m = CO("col")
    if m == "white" then return { 1, 0.98, 0.97 } end
    if m == "class" then
        local _, cls = UnitClass("player")
        local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
        if c then return { c.r, c.g, c.b } end
    end
    return base
end
local SHAPE = { heart = "fx_heart", star = "fx_star", dot = "circle" }
local TRAIL_K = { short = 0.55, mid = 1, long = 1.7 }

-- 커서 위치 (UIParent 좌표)
local function CursorXY()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
end

----------------------------------------------------------------------
-- 조각 (그림 하나가 잠깐 살다 사라짐)
----------------------------------------------------------------------
-- 조각 묶음: 화면(UIParent)용 하나 + 허브 미리 보기용 하나 (같은 코드)
local function Particles(host, anchor)
local pool, live = {}, {}
local function Spawn(tex, x, y, o)
    local p = table.remove(pool)
    if not p then
        p = { t = host:CreateTexture(nil, "OVERLAY") }
    end
    local k = (tonumber(CO("size")) or 100) / 100
    if o.s0 then o.s0 = o.s0 * k end
    if o.s1 then o.s1 = o.s1 * k end
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
            p.t:SetPoint("CENTER", anchor, "BOTTOMLEFT", p.x, p.y)
            p.t:SetAlpha(p.a0 + (p.a1 - p.a0) * k)
            if p.spin then p.t:SetRotation(p.spin * p.age) end
        end
    end
end
return Spawn, Step, live
end
local Spawn, Step, live = Particles(fx, UIParent)

----------------------------------------------------------------------
-- ① 클릭 퐁: 짧게 눌렀다 뗐을 때만 (카메라 돌리기 끌기는 빼요)
----------------------------------------------------------------------
local function Pop(x, y, right, sp)
    sp = sp or Spawn
    local c = Col(right and CREAM or PINK)
    sp("ring", x, y, { c = c, s0 = 6, s1 = 46, a0 = 1, a1 = 0, life = 0.38 })
    sp("circle", x, y, { c = c, s0 = 10, s1 = 2, a0 = 0.8, a1 = 0, life = 0.18, add = true })
    local n = right and 2 or 3
    local tex = SHAPE[CO("shape")] or "fx_heart"
    for i = 1, n do
        local ang = math.rad(60 + (i - 1) * (60 / math.max(n - 1, 1)) + math.random(-12, 12))
        local spd = math.random(70, 110)
        sp(tex, x, y, { c = c, s0 = 9, s1 = 13, a0 = 1, a1 = 0, life = 0.55,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd, g = 160, spin = (tex == "fx_star") and 3 or nil })
    end
end
-- 커서 찾기: 커서 둘레로 큰 링이 조여들어요
local function Find(x, y, sp)
    sp = sp or Spawn
    local c = Col(PINK)
    sp("ring", x, y, { c = c, s0 = 150, s1 = 18, a0 = 0, a1 = 1, life = 0.45 })
    sp("ring", x, y, { c = c, s0 = 110, s1 = 14, a0 = 0, a1 = 0.9, life = 0.55 })
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
local function MakeTrail(sp)
local lastX, lastY, trailAcc, trailN = nil, nil, 0, 0
return function(x, y, dt)
    if x == nil then lastX = nil return end
    if not lastX then lastX, lastY = x, y; return end
    local dx, dy = x - lastX, y - lastY
    local dist = math.sqrt(dx * dx + dy * dy)
    lastX, lastY = x, y
    if dt <= 0 or dist / dt < 120 then return end
    local lk = TRAIL_K[CO("trail")] or 1
    local dc = Col(DOT)
    trailAcc = trailAcc + dist
    while trailAcc >= 9 do
        trailAcc = trailAcc - 9
        trailN = trailN + 1
        local f = trailAcc / math.max(dist, 1)
        local px, py = x - dx * f, y - dy * f
        if trailN % 7 == 0 then
            sp("fx_star", px + math.random(-6, 6), py + math.random(-6, 6),
                { c = { 1, 0.95, 0.80 }, s0 = 12, s1 = 4, a0 = 0.95, a1 = 0, life = 0.45 * lk, add = true, spin = 3 })
        else
            sp("circle", px, py, { c = dc, s0 = 7, s1 = 1.5, a0 = 0.75, a1 = 0, life = 0.35 * lk })
        end
    end
end
end
local Trail = MakeTrail(Spawn)

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
    if CO("combat") == "off" and InCombatLockdown() then click, rea, trail = false, false, false end
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
        if trail then Trail(x, y, dt) else Trail(nil) end
        if rea then React(x, y, dt) else react:Hide() end
    else
        press.LeftButton, press.RightButton = nil, nil
        Trail(nil); react:Hide()
    end
    if #live > 0 then Step(dt) end
end)

function ns.CursorFxRefresh()
    if not On("cfxReact") then react:Hide() end
end

----------------------------------------------------------------------
-- 커서 찾기 (허브): Ctrl 두 번 · 전투 시작할 때 커서 둘레로 링이 조여들어요
----------------------------------------------------------------------
do
    local fe = CreateFrame("Frame")
    fe:RegisterEvent("MODIFIER_STATE_CHANGED")
    fe:RegisterEvent("PLAYER_REGEN_DISABLED")
    local lastCtrl = 0
    fe:SetScript("OnEvent", function(_, ev, key, down)
        if not CO("find") then return end
        if ev == "PLAYER_REGEN_DISABLED" then local x, y = CursorXY(); Find(x, y) return end
        if (key == "LCTRL" or key == "RCTRL") and down == 1 then
            local now = GetTime()
            if now - lastCtrl < 0.4 then local x, y = CursorXY(); Find(x, y); lastCtrl = 0 else lastCtrl = now end
        end
    end)
end

----------------------------------------------------------------------
-- 허브 미리 보기: 같은 효과 코드로 작은 칸 안에서 커서가 돌아다녀요
--   (꼬리 → 클릭 퐁 → 적 위에서 빨간 점선 → 커서 찾기 링 · 3.6초마다 한 바퀴)
----------------------------------------------------------------------
function ns.CursorDemo(parent)
    local d = CreateFrame("Frame", nil, parent)
    d:SetSize(520, 140)
    d:SetClipsChildren(true)
    local sp, step = Particles(d, d)
    local tr = MakeTrail(sp)
    local mob = d:CreateTexture(nil, "ARTWORK"); mob:SetTexture(M .. "circle"); mob:SetVertexColor(0.16, 0.12, 0.11, 1)
    mob:SetSize(56, 44); mob:SetPoint("CENTER", d, "BOTTOMLEFT", 420, 62)
    local mobLab = d:CreateFontString(nil, "OVERLAY"); mobLab:SetFont(ns.FONT or STANDARD_TEXT_FONT, 11, ""); mobLab:SetText("적")
    mobLab:SetTextColor(1, 0.6, 0.6); mobLab:SetPoint("BOTTOM", mob, "TOP", 0, 4)
    local cur = d:CreateTexture(nil, "OVERLAY", nil, 7); cur:SetTexture("Interface\\CURSOR\\Point"); cur:SetSize(24, 24)
    local rs = d:CreateTexture(nil, "OVERLAY"); rs:SetTexture(M .. "fx_dash"); rs:SetSize(40, 40); rs:Hide()
    d.cur, d.mob, d.react = cur, mob, rs
    local t, clicked, found = 0, false, false
    d:SetScript("OnUpdate", function(self, dt)
        t = (t + dt) % 3.6
        local x, y
        if t < 1.6 then
            local k = t / 1.6
            x = 40 + 300 * k; y = 70 + 34 * math.sin(k * math.pi * 2)
        elseif t < 2.6 then
            local k = (t - 1.6) / 1.0
            x = 340 + 80 * k; y = 70 - 8 * k
        else
            x, y = 420, 62
        end
        cur:ClearAllPoints(); cur:SetPoint("TOPLEFT", self, "BOTTOMLEFT", x - 2, y + 2)
        if On("cfxTrail") then tr(x, y, dt) else tr(nil) end
        if t > 1.62 and t < 1.7 and not clicked then
            clicked = true
            if On("cfxClick") then Pop(x, y, false, sp) end
        elseif t < 1.6 then clicked = false end
        local over = t >= 2.6
        rs:SetShown(over and On("cfxReact"))
        if over then
            rs:ClearAllPoints(); rs:SetPoint("CENTER", self, "BOTTOMLEFT", x + 11, y - 12)
            local c = RED; rs:SetVertexColor(c[1], c[2], c[3], 0.9); rs:SetRotation(-GetTime() * 1.2)
        end
        if t > 3.0 and not found then
            found = true
            if CO("find") then Find(x, y, sp) end
        elseif t < 3.0 then found = false end
        step(dt)
    end)
    return d
end
