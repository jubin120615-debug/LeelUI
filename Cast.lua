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
    if b.kick then b.kick:Hide() end
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
    if b.OnPaint then b:OnPaint(kind) end
end

local function Hide(b)
    b.casting, b.finishing, b.mirroring = false, false, false
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

-- 귀여운 시전바: 숨겨진 값이면 블리자드 시전바의 값을 그대로 옮겨 받아 우리 모양으로 그림
-- (계산 없이 화면에 넘기기만 하므로 숨겨진 값이어도 됨)
local function MirrorTick(b)
    local bb = b.blizz
    if not bb then return end
    pcall(function() b.bar:SetMinMaxValues(bb:GetMinMaxValues()) end)
    pcall(function() b.bar:SetValue(bb:GetValue()) end)
    if not b.rawName and bb.Text then pcall(function() b.name:SetText(bb.Text:GetText()) end) end
    if not bb:IsShown() then
        b.away = (b.away or 0) + 1
        if b.away > 20 and not b.finishing then
            b.mirroring = false
            Hide(b)
        end
    else
        b.away = 0
    end
end

local function StartMirror(b, raw)
    local bb = b.blizz
    if not bb then return false end
    b.borrowing = false
    bb.leelForce = 0; bb:SetAlpha(0)
    b.mirroring, b.casting, b.finishing = true, true, false
    b.channel = raw and raw.channel or false
    b.castID, b.dur, b.away = nil, nil, 0
    b.bar:Show()
    local kind = b.unit == "player" and (b.channel and "ch" or "me") or "int"
    Paint(b, kind)
    if b.kick then b.kick:Hide() end   -- 끊을 수 있는지 알 수 없음
    b.lock:Hide()
    b.rawName = false
    if raw and raw.text then
        b.rawName = pcall(b.name.SetText, b.name, raw.text)
    end
    if raw and raw.tex then
        pcall(b.icon.SetTexture, b.icon, raw.tex)
    elseif bb.Icon then
        pcall(function() b.icon:SetTexture(bb.Icon:GetTexture()) end)
    end
    b.icon:Show(); b.name:Show()
    b.time:SetText(""); b.time:Show()
    MirrorTick(b)
    b:SetScript("OnUpdate", MirrorTick)
    b:Show()
    return true
end

local function Start(b)
    local u = b.unit
    local info, raw
    local ok = pcall(function()
        -- 두 번째 값(text)이 화면용 이름. 첫 값은 "Opening - No Text" 같은 내부 이름일 때가 있음
        local name, text, tex, s, e, _, castID, notInt, spellID = UnitCastingInfo(u)
        raw = { text = text or name, tex = tex, channel = false }
        local channel = false
        if not name then
            name, text, tex, s, e, _, notInt, spellID = UnitChannelInfo(u)
            channel = true
            raw = { text = text or name, tex = tex, channel = true }
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
        -- 숨겨진 값: 귀여운 시전바는 값만 옮겨 받고, 예전 바는 블리자드 시전바를 빌려 씀
        if b.cute then
            if not StartMirror(b, raw) then Hide(b) end
        elseif not StartBorrow(b) then
            Hide(b)
        end
        return
    end
    b.mirroring = false
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
    if b.mirroring then
        -- 값을 모르니 완료면 끝까지 채우기만
        if kind == "done" then pcall(function() local _, hi = b.bar:GetMinMaxValues(); b.bar:SetValue(hi) end) end
    else
        b.bar:SetValue(b.channel and 0 or b.dur)
        if kind == "done" and not b.channel then b.bar:SetValue(b.dur) end
    end
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

local function BuildHud(f, unit, mirrored, w)
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
    return b
end

local BuildBunny, BuildPaw  -- 아래 "귀여운 시전바"

local function CreateCast(f, unit, mirrored, w, style)
    local b
    if style == "bunny" then b = BuildBunny(f, unit, w); b.cute = true
    elseif style == "paw" then b = BuildPaw(f, unit); b.cute = true
    else b = BuildHud(f, unit, mirrored, w) end
    b.unit = unit
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
    local style = ns.db.castStyle or "bunny"
    if style == "bunny" or style == "paw" then
        local holder = ns:CreateCastHolder()
        local pc = CreateCast(holder, "player", false, 300, style)
        pc:SetPoint("BOTTOM", holder, "BOTTOM", 0, 6)
        local pbb = PlayerCastingBarFrame or CastingBarFrame
        SetupBlizz(pc, pbb)
        -- 게임 시전바는 값만 빌려 쓰고 화면에선 완전히 숨김:
        -- 끊김/완료 때 게임이 자체 애니메이션으로 다시 보이게 해서, 투명한 부모 밑에 둠 (보이는 상태는 유지 → 값은 계속 갱신)
        if pbb then
            local ghost = CreateFrame("Frame", "LeelUI_CastGhost", UIParent)
            ghost:SetAllPoints(UIParent)
            ghost:SetAlpha(0)
            local function Ghost(self)
                if self.leelGhosting then return end
                self.leelGhosting = true
                pcall(self.SetIgnoreParentAlpha, self, false)
                if self:GetParent() ~= ghost then pcall(self.SetParent, self, ghost) end
                self.leelGhosting = false
            end
            Ghost(pbb)
            pcall(hooksecurefunc, pbb, "SetParent", Ghost)
            pcall(hooksecurefunc, pbb, "SetIgnoreParentAlpha", function(self, v) if v then Ghost(self) end end)
        end
        local tc = CreateCast(holder, "target", false, 250, style)
        tc:SetPoint("BOTTOM", pc, "TOP", 0, style == "paw" and 26 or 30)
        local tf = TargetFrame
        SetupBlizz(tc, (tf and tf.spellbar) or _G.TargetFrameSpellBar)
        ns.casts = { player = pc, target = tc }
        return
    end
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
        local y = self:IsShown() and -51 or -17   -- 대상 자원 줄 자리만큼 아래로
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

----------------------------------------------------------------------
-- 귀여운 시전바 (화면 가운데 아래): 깡충 토끼 / 발자국
----------------------------------------------------------------------
local function KickTag(parent)
    local k = CreateFrame("Frame", nil, parent)
    k:SetSize(34, 16)
    ns.RoundRect(k, 8, { 0.85, 0.26, 0.18 }, "ARTWORK", 0, 0)
    local fs = ns.Font(k, 10.5, { 1, 1, 1 })
    fs:SetPoint("CENTER", 0, 0); fs:SetText("끊기")
    k:Hide()
    return k
end

local function SmallIcon(b, size)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(size, size)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local m = b:CreateMaskTexture()
    m:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(b.icon)
    b.icon:AddMaskTexture(m)
    local edge = b:CreateTexture(nil, "BORDER")
    edge:SetTexture(ns.MEDIA .. "circle"); edge:SetVertexColor(0.07, 0.05, 0.04, 1)
    edge:SetPoint("TOPLEFT", b.icon, -1.5, 1.5); edge:SetPoint("BOTTOMRIGHT", b.icon, 1.5, -1.5)
    b.lock = b:CreateTexture(nil, "ARTWORK")
    b.lock:SetTexture(ns.MEDIA .. "lock")
    b.lock:SetVertexColor(0.73, 0.70, 0.70, 1)
    b.lock:SetSize(12, 12)
end

-- 바 위 글씨 줄: [아이콘] 이름 [끊기/자물쇠] ........ 1.4
local function TopRow(b, w, anchor, yoff)
    SmallIcon(b, 18)
    b.icon:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 4, yoff)
    b.name = ns.Font(b, 14)
    b.name:SetWordWrap(false)
    b.name:SetJustifyH("LEFT")
    b.name:SetWidth(w - 110)
    b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.kick = KickTag(b)
    b.time = ns.Num(b, 18, C.tx)
    b.time:SetShadowOffset(0, -1)
    b.time:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", -4, yoff - 1)
end

-- 글자 폭 (숨겨진 이름이면 폭도 숨겨져서 계산 불가 → 기본값)
local function TextWidth(fs, maxW, fallback)
    local ok, w = pcall(function() return math.min(fs:GetStringWidth() or 0, maxW) end)
    if ok and w then return w end
    return fallback
end

local function PlaceTags(b)
    -- 이름 길이에 맞춰 끊기 / 자물쇠 붙이기
    local w = TextWidth(b.name, b.name:GetWidth(), 90)
    b.kick:ClearAllPoints(); b.kick:SetPoint("LEFT", b.name, "LEFT", w + 6, 0)
    b.lock:ClearAllPoints(); b.lock:SetPoint("LEFT", b.name, "LEFT", w + 5, 0)
end

-- 깡충 토끼: 알약 바 위를 토끼가 달려가고 끝에 하트(대상은 당근)
BuildBunny = function(f, unit, w)
    local b = ns.CreateSkewBar(f, w, 16, { inset = 3, noShadow = true, shape = "pill32" })
    b:SetFrameStrata("MEDIUM")
    TopRow(b, w, b, 5)
    b.goal = b.over:CreateTexture(nil, "OVERLAY")
    b.goal:SetTexture(ns.MEDIA .. (unit == "player" and "cb_heart" or "cb_carrot"))
    b.goal:SetSize(18, 18)
    b.goal:SetPoint("CENTER", b, "RIGHT", -2, 0)
    -- 토끼는 바 위에 따로 (바보다 한 층 위)
    local top = CreateFrame("Frame", nil, b)
    top:SetAllPoints(); top:SetFrameLevel(b:GetFrameLevel() + 6)
    b.bun = top:CreateTexture(nil, "OVERLAY")
    b.bun:SetTexture(ns.MEDIA .. "bunny")
    b.bun:SetSize(30, 30)
    -- 채워진 끝에 붙어서 따라감 (계산 없음 → 숨겨진 값이어도 됨)
    b.bun:SetPoint("CENTER", b.bar:GetStatusBarTexture(), "RIGHT", 0, 3)
    function b:OnPaint(kind)
        self.kick:SetShown(kind == "int")
        self.bun:SetRotation(kind == "fail" and math.rad(90) or 0)
        self.bun:SetDesaturated(kind == "fail" or kind == "lock")
        local big = kind == "done"
        self.goal:SetSize(big and 28 or 18, big and 28 or 18)
        local g = kind == "fail" and { 0.5, 0.45, 0.45 } or { 1, 1, 1 }
        self.goal:SetVertexColor(g[1], g[2], g[3], 1)
        PlaceTags(self)
    end
    hooksecurefunc(b.name, "SetText", function() PlaceTags(b) end)
    b.bar:HookScript("OnShow", function() b.bun:Show(); b.goal:Show() end)
    b.bar:HookScript("OnHide", function() b.bun:Hide(); b.goal:Hide() end)
    return b
end

-- 발자국: 발자국 6개 줄이 왼쪽부터 칠해짐 (발자국 그림을 채움 막대로 써서 계산 없이)
BuildPaw = function(f, unit)
    local w, h = 208, 26
    local b = CreateFrame("Frame", nil, f)
    b:SetSize(w, h)
    b:SetFrameStrata("MEDIUM")
    -- 흐린 발자국 줄 (바탕)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(ns.MEDIA .. "cb_paws")
    bg:SetAllPoints()
    bg:SetVertexColor(1, 1, 1, 0.22)
    -- 칠해지는 발자국 줄
    b.bar = CreateFrame("StatusBar", nil, b)
    b.bar:SetAllPoints()
    b.bar:SetStatusBarTexture(ns.MEDIA .. "cb_paws")
    b.fill = b.bar:GetStatusBarTexture()
    b.border = b:CreateTexture(nil, "BACKGROUND"); b.border:SetAlpha(0)
    b.bar:HookScript("OnShow", function() bg:Show() end)
    b.bar:HookScript("OnHide", function() bg:Hide() end)
    -- 글씨는 발자국 아래 가운데
    SmallIcon(b, 16)
    b.name = ns.Font(b, 14)
    b.name:SetWordWrap(false)
    b.kick = KickTag(b)
    b.time = ns.Num(b, 18, C.tx)
    b.time:SetShadowOffset(0, -1)
    local row = CreateFrame("Frame", nil, b)
    row:SetSize(10, 18)
    row:SetPoint("TOP", b, "BOTTOM", 0, -3)
    local function Layout()
        local nw = TextWidth(b.name, 220, 90)
        local extra = (b.kick:IsShown() and 40 or 0) + (b.lock:IsShown() and 16 or 0)
        local total = 16 + 6 + nw + extra + 8 + 30
        b.icon:ClearAllPoints(); b.icon:SetPoint("LEFT", row, "CENTER", -total / 2, 0)
        b.name:ClearAllPoints(); b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
        b.kick:ClearAllPoints(); b.kick:SetPoint("LEFT", b.name, "RIGHT", 6, 0)
        b.lock:ClearAllPoints(); b.lock:SetPoint("LEFT", b.name, "RIGHT", 5, 0)
        b.time:ClearAllPoints(); b.time:SetPoint("LEFT", b.name, "RIGHT", 8 + extra, -1)
    end
    function b:OnPaint(kind)
        self.kick:SetShown(kind == "int")
        C_Timer.After(0, Layout)
    end
    hooksecurefunc(b.name, "SetText", function() Layout() end)
    return b
end

-- 가운데 아래 자리 (이동 모드로 옮기기)
function ns:CreateCastHolder()
    if ns.castHolder then return ns.castHolder end
    local h = CreateFrame("Frame", "LeelUI_CastHolder", UIParent)
    h:SetSize(320, 96)
    h:SetMovable(true)
    h:SetClampedToScreen(true)
    local function Apply()
        local p = ns.db.castPoint or { "BOTTOM", "BOTTOM", 0, 210 }
        h:ClearAllPoints()
        h:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end
    Apply()
    ns.ApplyCastPosition = Apply

    local m = CreateFrame("Frame", nil, h)
    m:SetAllPoints()
    m:SetFrameStrata("DIALOG")
    m:EnableMouse(true)
    m:RegisterForDrag("LeftButton")
    local tint = m:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints(); tint:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.10)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = m:CreateTexture(nil, "BORDER")
        e:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 1)
        if side == "TOP" or side == "BOTTOM" then
            e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(2)
        else
            e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(2)
        end
    end
    local lab = ns.Font(m, 12, C.accHi)
    lab:SetPoint("BOTTOM", m, "TOP", 0, 4); lab:SetText("시전바")
    m:SetScript("OnDragStart", function() if not InCombatLockdown() then h:StartMoving() end end)
    m:SetScript("OnDragStop", function()
        h:StopMovingOrSizing()
        local x, y = h:GetCenter()
        if ns.db.grid then x = math.floor(x / 8 + 0.5) * 8; y = math.floor(y / 8 + 0.5) * 8 end
        ns.db.castPoint = { "CENTER", "BOTTOMLEFT", math.floor(x + 0.5), math.floor(y + 0.5) }
        Apply()
    end)
    m:Hide()
    h.mover = m
    if ns.SetMoveMode then
        hooksecurefunc(ns, "SetMoveMode", function() m:SetShown(ns.moving and true or false) end)
    end
    ns.castHolder = h
    return h
end

function ns:ResetCastPosition()
    ns.db.castPoint = nil
    if ns.ApplyCastPosition then ns.ApplyCastPosition() end
end
