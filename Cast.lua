-- LeelUI / Cast.lua
-- HUD 시전바 (A안): 체력바·기력바와 같은 얇은 알약(높이 10) + 바 아래 한 줄 글씨
--   내 시전바: 기력바·마나선 아래 / 대상 시전바: 대상 체력바 바로 아래 (디버프는 시전 중에만 한 칸 내려감)
--   색: 분홍 내 시전, 하늘 정신 집중, 산호 끊을 수 있음, 회색+자물쇠 못 끊음, 흰빛 완료, 빨강 끊김
-- 시전 정보가 숨겨진 값이면(전투 중 대상 등) 계산을 못 하므로,
-- 블리자드 시전바(내 것: PlayerCastingBarFrame, 대상: TargetFrame.spellbar)를 빌려 와서 같은 자리에 모양만 입힘

local _, ns = ...
local C = ns.C

local H = 10
local COL = {
    me   = { 0.95, 0.70, 0.76 },
    ch   = { 0.66, 0.74, 0.95 },
    int  = { 1.00, 0.54, 0.44 },
    lock = { 0.61, 0.59, 0.59 },
    done = { 1.00, 0.97, 0.98 },
    fail = { 0.85, 0.26, 0.18 },
}
local NAMECOL = {
    me = C.tx, ch = { 0.81, 0.86, 1 }, int = { 1, 0.70, 0.65 },
    lock = { 0.79, 0.76, 0.76 }, done = { 1, 1, 1 }, fail = { 1, 0.56, 0.50 },
}

----------------------------------------------------------------------
-- 블리자드 시전바 빌려 쓰기 (숨겨진 값일 때만 보임)
----------------------------------------------------------------------
local HIDE_KEYS = { "Background", "Border", "BorderShield", "Icon", "Spark", "Flash", "TextBorder",
                    "ChargeFlash", "StandardGlow", "CraftGlow", "Shine", "BaseGlow", "WispGlow",
                    "Sparkles01", "Sparkles02", "EnergyGlow", "EnergyMask", "Shield", "InterruptGlow" }

local function ForceAlpha(self)
    if self.leelForce ~= nil and self:GetAlpha() ~= self.leelForce then
        self:SetAlpha(self.leelForce)
    end
end

local function PinBlizz(bb)
    local b = bb.leelOwner
    if not b or not b.borrowing or bb.leelMoving then return end
    bb.leelMoving = true
    bb:SetFrameStrata(b:GetFrameStrata())
    bb:SetFrameLevel(b:GetFrameLevel() + 3)
    bb:ClearAllPoints()
    bb:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    bb:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    if bb.Text then
        bb.Text:ClearAllPoints()
        if b.mirrored then
            bb.Text:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", -2, -3)
        else
            bb.Text:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 2, -3)
        end
    end
    bb.leelMoving = false
end

local function SetupBlizz(b, bb)
    if not bb or bb.leelOwner then return end
    bb.leelOwner = b
    b.blizz = bb
    pcall(bb.SetIgnoreParentAlpha, bb, true)
    for _, k in ipairs(HIDE_KEYS) do
        local r = bb[k]
        if r and r.SetAlpha then
            r:SetAlpha(0)
            pcall(hooksecurefunc, r, "SetAlpha", function(self, a) if a and a > 0 then self:SetAlpha(0) end end)
        end
    end
    local function MaskFill()
        local fill = bb.GetStatusBarTexture and bb:GetStatusBarTexture()
        if fill and not fill.leelMasked then
            fill.leelMasked = true
            local m = bb:CreateMaskTexture()
            m:SetTexture(ns.MEDIA .. "pill32", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            m:SetAllPoints(bb)
            pcall(fill.AddMaskTexture, fill, m)
        end
    end
    MaskFill()
    pcall(hooksecurefunc, bb, "SetStatusBarTexture", MaskFill)
    if bb.Text then
        bb.Text:SetFont(ns.FONT, 12, "")
        bb.Text:SetWidth(b:GetWidth() - 30)
        bb.Text:SetJustifyH(b.mirrored and "RIGHT" or "LEFT")
        bb.Text:SetWordWrap(false)
        bb.Text:SetShadowColor(0, 0, 0, 0.9)
        bb.Text:SetShadowOffset(1, -1)
    end
    -- 평소엔 투명, 빌려 쓸 때만 보임
    bb.leelForce = 0
    bb:SetAlpha(0)
    hooksecurefunc(bb, "SetAlpha", ForceAlpha)
    hooksecurefunc(bb, "SetPoint", PinBlizz)
    bb:HookScript("OnShow", function(self)
        PinBlizz(self)
        local o = self.leelOwner
        if o and o.borrowing then o:Show(); if o.OnLayout then o:OnLayout() end end
    end)
    bb:HookScript("OnHide", function(self)
        local o = self.leelOwner
        if o and o.borrowing then o.borrowing = false; o:Hide(); self.leelForce = 0; self:SetAlpha(0) end
    end)
end

local function StartBorrow(b)
    local bb = b.blizz
    if not bb then return false end
    b.borrowing = true
    b.casting = false
    b:SetScript("OnUpdate", nil)
    b.bar:Hide()
    b.icon:Hide(); b.name:Hide(); b.time:Hide(); b.lock:Hide()
    b.border:SetVertexColor(C.edge[1], C.edge[2], C.edge[3], C.edge[4])
    bb.leelForce = 1
    bb:SetAlpha(1)
    PinBlizz(bb)
    b:SetShown(bb:IsShown())
    if b.OnLayout then b:OnLayout() end
    return true
end

----------------------------------------------------------------------
-- 우리 시전바
----------------------------------------------------------------------
local function Paint(b, kind)
    ns.PaintFlat(b, COL[kind])
    local c = NAMECOL[kind]
    b.name:SetTextColor(c[1], c[2], c[3])
    if kind == "done" then
        b.border:SetVertexColor(1, 1, 1, 1)
    else
        b.border:SetVertexColor(C.edge[1], C.edge[2], C.edge[3], C.edge[4])
    end
end

local function Hide(b)
    b.casting, b.finishing = false, false
    b:SetScript("OnUpdate", nil)
    if not b.borrowing then b:Hide() end
    if b.OnLayout then b:OnLayout() end
end

-- 채집·상자 열기 등은 게임이 "Opening - No Text" 같은 영어 내부 이름을 줄 때가 있음
-- → 주문 번호로 한국어 이름을 다시 찾고, 그래도 없으면 "여는 중"
function ns.CastLabel(text, spellID)
    local bad = type(text) ~= "string" or text == "" or text:find("No Text") or text:find("^Opening")
    if not bad then return text end
    if spellID then
        local ok, nm = pcall(function()
            if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
            return (GetSpellInfo(spellID))
        end)
        if ok and type(nm) == "string" and nm ~= "" and not nm:find("No Text") then return nm end
    end
    return "여는 중"
end

local function OnTick(b)
    local now = GetTime()
    if now >= b.endT then
        b.bar:SetValue(b.channel and 0 or b.dur)
        b.time:SetText("")
        return
    end
    local v = now - b.startT
    b.bar:SetValue(b.channel and (b.dur - v) or v)
    b.time:SetFormattedText("%.1f", b.endT - now)
end

local function Start(b)
    local u = b.unit
    local info
    local ok = pcall(function()
        -- 두 번째 값(text)이 화면용 이름. 첫 값은 "Opening - No Text" 같은 내부 이름일 때가 있음
        local name, text, tex, s, e, _, castID, notInt, spellID = UnitCastingInfo(u)
        local channel = false
        if not name then
            name, text, tex, s, e, _, notInt, spellID = UnitChannelInfo(u)
            channel = true
            castID = nil
        end
        if not name then info = false return end
        local dur = (e - s) / 1000           -- 숨겨진 값이면 여기서 에러
        if dur <= 0 then info = false return end
        if text == nil or text == "" then text = name end
        text = ns.CastLabel(text, spellID)
        info = { name = text, tex = tex, s = s / 1000, e = e / 1000, dur = dur,
                 channel = channel, notInt = notInt and true or false, castID = castID }
    end)
    if not ok then
        -- 숨겨진 값: 블리자드 시전바를 빌려 씀
        if not StartBorrow(b) then Hide(b) end
        return
    end
    if b.borrowing and b.blizz then
        b.borrowing = false
        b.blizz.leelForce = 0; b.blizz:SetAlpha(0)
    end
    if not info then Hide(b) return end

    b.casting, b.finishing, b.channel = true, false, info.channel
    b.castID = info.castID
    b.startT, b.endT, b.dur = info.s, info.e, info.dur
    b.bar:Show()
    b.bar:SetMinMaxValues(0, info.dur)
    local kind
    if b.unit == "player" then
        kind = info.channel and "ch" or "me"
    else
        kind = info.notInt and "lock" or "int"
    end
    Paint(b, kind)
    b.lock:SetShown(kind == "lock")
    pcall(b.icon.SetTexture, b.icon, info.tex)
    b.icon:Show()
    ns.SetText(b.name, info.name); b.name:Show()
    b.time:Show()
    OnTick(b)
    b:SetScript("OnUpdate", OnTick)
    b:Show()
    if b.OnLayout then b:OnLayout() end
end

local function Finish(b, kind, label)
    if not b.casting or b.finishing then return end
    b.finishing = true
    b:SetScript("OnUpdate", nil)
    b.bar:SetValue(b.channel and 0 or b.dur)
    if kind == "done" and not b.channel then b.bar:SetValue(b.dur) end
    Paint(b, kind)
    b.lock:Hide()
    b.time:SetText("")
    if label then b.name:SetText(label) end
    local token = {}
    b.finishToken = token
    C_Timer.After(kind == "fail" and 0.5 or 0.25, function()
        if b.finishToken == token and b.finishing then Hide(b) end
    end)
end

-- castGUID가 지금 시전과 같은지 (모르면 같다고 봄)
local function SameCast(b, guid)
    if not b.castID or not guid then return true end
    local ok, same = pcall(function() return b.castID == guid end)
    return not ok or same
end

local function CreateCast(f, unit, mirrored, w)
    local b = ns.CreateSkewBar(f, w, H, { mirrored = mirrored, inset = 2, noShadow = true, shape = "pill32" })
    b.unit, b.mirrored = unit, mirrored
    b:SetFrameLevel(f.hp:GetFrameLevel() + 2)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(15, 15)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local m = b:CreateMaskTexture()
    m:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(b.icon)
    b.icon:AddMaskTexture(m)
    local iconEdge = b:CreateTexture(nil, "BORDER")
    iconEdge:SetTexture(ns.MEDIA .. "circle"); iconEdge:SetVertexColor(0.07, 0.05, 0.04, 1)
    iconEdge:SetPoint("TOPLEFT", b.icon, -1.5, 1.5); iconEdge:SetPoint("BOTTOMRIGHT", b.icon, 1.5, -1.5)

    b.name = ns.Font(b, 12)
    b.name:SetWordWrap(false)
    b.lock = b:CreateTexture(nil, "ARTWORK")
    b.lock:SetTexture(ns.MEDIA .. "lock")
    b.lock:SetVertexColor(0.73, 0.70, 0.70, 1)
    b.lock:SetSize(12, 12)
    b.time = ns.Num(b, 14, C.tx)
    b.time:SetShadowOffset(0, -1)

    if mirrored then
        b.icon:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", -2, -3)
        b.name:SetPoint("RIGHT", b.icon, "LEFT", -5, 0)
        b.lock:SetPoint("RIGHT", b.name, "LEFT", -4, 0)
        b.time:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 2, -2)
    else
        b.icon:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 2, -3)
        b.name:SetPoint("LEFT", b.icon, "RIGHT", 5, 0)
        b.lock:SetPoint("LEFT", b.name, "RIGHT", 4, 0)
        b.time:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", -2, -2)
    end
    b.name:SetWidth(w - 60)
    b.name:SetJustifyH(mirrored and "RIGHT" or "LEFT")
    b:Hide()

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_DELAYED",
                         "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP",
                         "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
                         "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" }) do
        pcall(ev.RegisterUnitEvent, ev, e, unit)
    end
    if unit == "target" then ev:RegisterEvent("PLAYER_TARGET_CHANGED") end
    ev:SetScript("OnEvent", function(_, event, _, guid)
        if ns.moving then return end
        if event == "PLAYER_TARGET_CHANGED" then
            b.finishToken = nil
            Hide(b)
            Start(b)
        elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
            or event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
            or event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            b.finishToken = nil
            Start(b)
        elseif b.borrowing then
            return   -- 빌린 시전바는 게임이 알아서 끝냄
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            if SameCast(b, guid) then Finish(b, "fail", "차단됨") end
        elseif event == "UNIT_SPELLCAST_FAILED" then
            if SameCast(b, guid) then Finish(b, "fail", "실패") end
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_STOP" then
            if not b.channel and SameCast(b, guid) then Finish(b, "done") end
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            if b.channel then Finish(b, "done") end
        end
    end)
    b.ev = ev
    return b
end

----------------------------------------------------------------------
-- 붙이기
----------------------------------------------------------------------
function ns:CreateHUDCasts(player, target, barX)
    -- 내 시전바: 기력바 시작점(barX + 14)에 맞춰, 마나선 아래
    local pc = CreateCast(player, "player", false, 220)
    pc:SetPoint("TOPLEFT", player, "TOPLEFT", barX + 14, -99)
    SetupBlizz(pc, PlayerCastingBarFrame or CastingBarFrame)

    -- 대상 시전바: 체력바 바로 아래, 시전 중엔 디버프를 한 칸 내림
    local tc = CreateCast(target, "target", true, 230)
    tc:SetPoint("TOPRIGHT", target.hp, "BOTTOMRIGHT", -14, -7)
    function tc:OnLayout()
        local cont = target.debuffs
        if not cont then return end
        local y = self:IsShown() and -40 or -6
        pcall(function()
            cont:ClearAllPoints()
            cont:SetPoint("TOPRIGHT", target.hp, "BOTTOMRIGHT", -28, y)
        end)
        local bc = target.buffs
        if bc then
            pcall(function()
                bc:ClearAllPoints()
                bc:SetPoint("TOPRIGHT", target.hp, "BOTTOMRIGHT", -28, y - 36 - 6)
            end)
        end
    end
    local tf = TargetFrame
    SetupBlizz(tc, (tf and tf.spellbar) or _G.TargetFrameSpellBar)

    ns.casts = { player = pc, target = tc }
end

-- 이동 모드 예시
function ns:SetCastPreview(on)
    local cs = ns.casts
    if not cs then return end
    for unit, b in pairs(cs) do
        if on then
            b.finishToken = nil
            b:SetScript("OnUpdate", nil)
            b.bar:Show()
            b.bar:SetMinMaxValues(0, 1)
            b.bar:SetValue(unit == "player" and 0.58 or 0.40)
            local kind = unit == "player" and "me" or "int"
            Paint(b, kind)
            b.lock:Hide()
            b.icon:SetTexture(unit == "player" and 132222 or 136197)
            b.icon:Show()
            b.name:SetText(unit == "player" and "시전 예시" or "대상 시전 예시"); b.name:Show()
            b.time:SetText(unit == "player" and "1.4" or "0.9"); b.time:Show()
            b:Show()
        else
            b.casting, b.finishing = false, false
            b:Hide()
            Start(b)
        end
        if b.OnLayout then b:OnLayout() end
    end
end
