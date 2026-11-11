-- LeelUI / Nameplates.lua
-- 적 이름표: 15px 알약 바 + 검은 외곽, 체력 %, 대상 강조, 6px 시전바,
-- 내 디버프(게임 디버프 칸을 옮겨 붙임), Questie 퀘스트 원(칼 / 줍는 손 / 체크)

local _, ns = ...

local Try = ns.Try
local C = ns.C
local active = {}   -- unit -> 우리 이름표 프레임

local W, H = 164, 15
local DEB_SIZE = 20

----------------------------------------------------------------------
-- 블리자드(와 다른 애드온) 이름표 숨기기 / 되돌리기
-- 게임이 대상 바꿀 때 투명도를 되돌리므로, 숨김 상태면 곧바로 0으로 고정
----------------------------------------------------------------------
local function KeepHidden(self, a)
    if self.leelHidden and a and a > 0 then self:SetAlpha(0) end
end

local function HideFrame(child, hide)
    if not child.leelHooked then
        child.leelHooked = true
        pcall(hooksecurefunc, child, "SetAlpha", KeepHidden)
    end
    child.leelHidden = hide
    pcall(child.SetAlpha, child, hide and 0 or 1)
end

local function SetBlizzAlpha(plate, a)
    for _, child in ipairs({ plate:GetChildren() }) do
        if not child.isLeel then HideFrame(child, a == 0) end
    end
end

-- Questie가 나중에 붙이는 주머니 아이콘도 숨김 (우리 원으로 대신 표시)
local function HideQuestieIcon(plate, hide)
    for _, child in ipairs({ plate:GetChildren() }) do
        if not child.isLeel and child.Icon and child.lastIcon ~= nil then
            HideFrame(child, hide)
        end
    end
end

----------------------------------------------------------------------
-- 작은 부품
----------------------------------------------------------------------
local function Outline(fs, size, file)
    fs:SetFont(file or ns.FONT, size, "OUTLINE")
    if not file and ns.TrackText then ns.TrackText(fs, size, "OUTLINE") end
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetShadowOffset(1, -1)
    return fs
end

-- 몹 등급 → 토끼 머리
local BADGE = 18
-- 몹 등급 = 레벨 앞 동그란 토끼 배지 (분홍 일반 / 금빛+왕관 정예 / 은빛+반짝 희귀 / 빨강+뿔 보스 / 회색 하찮음)
local RANK = {
    normal    = { tex = "rb_normal" },
    elite     = { tex = "rb_elite" },
    rare      = { tex = "rb_rare" },
    rareelite = { tex = "rb_rareelite" },
    boss      = { tex = "rb_boss" },
    minus     = { tex = "rb_trivial", small = true },
    trivial   = { tex = "rb_trivial" },
}

-- 비선공(중립) 몹: 크림색 바 + 크림색 이름
local CREAM_TOP, CREAM_BOT = { 1.00, 0.93, 0.76 }, { 0.95, 0.76, 0.48 }
local CREAM_NAME = { 1.00, 0.89, 0.63 }
local function PaintCream(holder)
    local fill = holder.fill
    if fill.SetGradient and CreateColor then
        fill:SetVertexColor(1, 1, 1, 1)
        fill:SetGradient("VERTICAL",
            CreateColor(CREAM_BOT[1], CREAM_BOT[2], CREAM_BOT[3], 1),
            CreateColor(CREAM_TOP[1], CREAM_TOP[2], CREAM_TOP[3], 1))
    else
        fill:SetVertexColor(CREAM_BOT[1], CREAM_BOT[2], CREAM_BOT[3], 1)
    end
end

-- 바·이름 색: 하찮음 회색 / 비선공 크림 / 선공 분홍
local function PaintPlate(f)
    if f.trivial then
        ns.PaintFlat(f.hp, C.grey)
        f.name:SetTextColor(0.78, 0.80, 0.83)
    elseif f.calm then
        PaintCream(f.hp)
        f.name:SetTextColor(CREAM_NAME[1], CREAM_NAME[2], CREAM_NAME[3])
    else
        ns.PaintHealth(f.hp)
        f.name:SetTextColor(C.tx[1], C.tx[2], C.tx[3])
    end
end

local function Circle(parent, layer, sub, size, c, a)
    local t = parent:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(ns.MEDIA .. "circle")
    t:SetSize(size, size)
    t:SetPoint("CENTER")
    t:SetVertexColor(c[1], c[2], c[3], a or 1)
    return t
end

----------------------------------------------------------------------
-- 이름표 만들기
----------------------------------------------------------------------
local function Build(plate)
    local f = CreateFrame("Frame", nil, plate)
    f.isLeel = true
    f:SetSize(W + 30, 70)
    f:SetPoint("CENTER", plate, "CENTER", 0, 4)

    -- 체력바: 검은 외곽 2px + 장미색 테두리 + 판
    f.hp = ns.CreateSkewBar(f, W, H, { inset = 2, noShadow = true })
    f.hp:SetPoint("CENTER", f, "CENTER", 0, 6)
    local black = f.hp:CreateTexture(nil, "BACKGROUND", nil, -1)
    black:SetTexture(ns.MEDIA .. "pill16")
    black:SetVertexColor(0, 0, 0, 0.85)
    black:SetPoint("TOPLEFT", -2, 2); black:SetPoint("BOTTOMRIGHT", 2, -2)
    f.glow = f.hp:CreateTexture(nil, "BACKGROUND", nil, -2)
    f.glow:SetTexture(ns.MEDIA .. "pill16")
    f.glow:SetBlendMode("ADD")
    f.glow:SetPoint("TOPLEFT", -6, 6); f.glow:SetPoint("BOTTOMRIGHT", 6, -6)
    f.glow:Hide()
    ns.PaintHealth(f.hp)

    f.pct = Outline(f.hp.over:CreateFontString(nil, "OVERLAY"), 13, ns.NUM)
    f.pct:SetTextColor(1, 1, 1)

    -- 이름 줄 (가운데): [등급 토끼 배지] 레벨 이름
    f.title = CreateFrame("Frame", nil, f)
    f.title:SetSize(1, 18)
    f.title:SetPoint("BOTTOM", f.hp, "TOP", 0, 3)
    f.head = CreateFrame("Frame", nil, f.title)
    f.head:SetSize(BADGE, BADGE)
    f.head:SetPoint("LEFT", f.title, "LEFT", 0, 1)
    f.headTex = f.head:CreateTexture(nil, "ARTWORK")
    f.headTex:SetAllPoints()
    f.headTex:SetTexture(ns.MEDIA .. "rb_normal")
    f.lv = Outline(f.title:CreateFontString(nil, "OVERLAY"), 13, ns.NUM)
    f.lv:SetPoint("LEFT", f.head, "RIGHT", 3, 0)
    f.name = Outline(f.title:CreateFontString(nil, "OVERLAY"), 13)
    f.name:SetPoint("LEFT", f.lv, "RIGHT", 4, 0)

    -- 시전바 6px
    f.cast = ns.CreateSkewBar(f, W, 6, { inset = 1, noShadow = true, shape = "pill32" })
    f.cast:SetPoint("TOP", f.hp, "BOTTOM", 0, -4)
    f.castName = Outline(f:CreateFontString(nil, "OVERLAY"), 10)
    f.castName:SetPoint("TOPLEFT", f.cast, "BOTTOMLEFT", 2, -2)
    f.castTag = Outline(f:CreateFontString(nil, "OVERLAY"), 10)
    f.castTag:SetPoint("TOPRIGHT", f.cast, "BOTTOMRIGHT", -2, -2)
    f.cast:Hide(); f.castName:Hide(); f.castTag:Hide()

    -- 연계 점수 구슬: 바 아래 왼쪽 (오른쪽은 퀘스트 개수 꼬리표 자리)
    f.combo = ns.CreateDots(f, 60, 12)
    f.combo:Hide()

    -- 디버프 자리: 게임이 그리는 디버프 칸(AurasFrame)을 여기로 옮겨 붙임
    f.debRow = CreateFrame("Frame", nil, f)
    f.debRow:SetSize(W, DEB_SIZE)

    -- 퀘스트 원 (체력바 오른쪽 끝)
    local q = CreateFrame("Frame", nil, f)
    q:SetSize(28, 28)
    q:SetPoint("CENTER", f.hp, "RIGHT", 0, 0)
    q:SetFrameLevel(f.hp.over:GetFrameLevel() + 2)
    Circle(q, "BACKGROUND", 0, 36, { 0, 0, 0 }, 0.75)
    Circle(q, "BACKGROUND", 1, 34, C.plate, 1)
    Circle(q, "BACKGROUND", 2, 30, { 0, 0, 0 }, 0.9)
    q.fill = Circle(q, "BORDER", 0, 28, C.acc, 1)
    q.icon = q:CreateTexture(nil, "ARTWORK")
    q.icon:SetSize(22, 22)
    q.icon:SetPoint("CENTER")
    -- 개수 꼬리표 (원 아래, B안)
    q.tag = CreateFrame("Frame", nil, q)
    q.tag:SetSize(24, 12)
    q.tag:SetPoint("CENTER", q, "BOTTOM", 0, -1)
    q.tagEdge = ns.RoundRect(q.tag, 6, { 0, 0, 0 }, "ARTWORK", 0, -1)
    q.tagEdge:SetColor({ 0, 0, 0 }, 0.8)
    q.tagBg = ns.RoundRect(q.tag, 6, C.accHi, "ARTWORK", 1, 0)
    q.count = q.tag:CreateFontString(nil, "OVERLAY")
    q.count:SetFont(ns.NUM, 10, "")
    q.count:SetPoint("CENTER", 0, 0)
    -- 퀘스트 여러 개 배지
    q.badge = CreateFrame("Frame", nil, q)
    q.badge:SetSize(13, 13)
    q.badge:SetPoint("CENTER", q, "TOPRIGHT", -3, -3)
    Circle(q.badge, "ARTWORK", 0, 15, { 0, 0, 0 }, 0.8)
    Circle(q.badge, "ARTWORK", 1, 13, C.dmg, 1)
    q.badgeText = q.badge:CreateFontString(nil, "OVERLAY")
    q.badgeText:SetFont(ns.NUM, 10, "")
    q.badgeText:SetPoint("CENTER", 0, 0)
    q:Hide()
    f.quest = q

    -- 징표(공격대 대상 표시): 체력바 왼쪽
    f.raid = f:CreateTexture(nil, "OVERLAY", nil, 7)
    f.raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    f.raid:SetSize(24, 24)
    f.raid:SetPoint("RIGHT", f.hp, "LEFT", -4, 0)
    f.raid:Hide()

    plate.leel = f
    return f
end

local function UpdateRaid(f, unit)
    -- 숨겨진 값이어도 에러 없이: 통째로 pcall
    local ok, shown = pcall(function()
        local idx = GetRaidTargetIndex(unit)
        if not idx then return false end
        SetRaidTargetIconTexture(f.raid, idx)
        return true
    end)
    f.raid:SetShown(ok and shown or false)
end

-- 레벨+이름 묶음 가운데 정렬
-- (전투 중 이름이 숨겨진 값이면 글자 폭도 숨겨져서 계산 불가 → 바 폭으로 대신)
local function FitTitle(f)
    local function Wd(fs, fb)
        local ok, v = pcall(function() return math.max(fs:GetStringWidth() or 0, 0) end)
        return ok and v or fb
    end
    f.title:SetWidth(BADGE + 3 + Wd(f.lv, 16) + 4 + Wd(f.name, W - 40))
end

-- 블리자드 디버프 아이콘 줄을 우리 체력바 아래(debRow)에 고정
local function PinFrame(fr)
    if fr.leelMoving or not fr.leelAnchor then return end
    fr.leelMoving = true
    fr:ClearAllPoints()
    fr:SetPoint("TOPLEFT", fr.leelAnchor, "TOPLEFT", 0, 0)
    fr.leelMoving = false
end

-- 블리자드 디버프 아이콘을 르엘 C안으로: 동그란 아이콘 + 분홍 진행 링 + 가운데 숫자
-- (남은 시간은 숨겨진 값이라 게임의 쿨다운 표시를 그대로 쓰고 모양만 바꿈)
local function FindCooldown(item)
    if item.Cooldown then return item.Cooldown end
    for _, ch in ipairs({ item:GetChildren() }) do
        if ch.GetObjectType and ch:GetObjectType() == "Cooldown" then return ch end
    end
end

local function StyleAuraItems(list)
    for _, item in ipairs({ list:GetChildren() }) do
        if not item.leelStyled then
            item.leelStyled = true
            local ring = ns.MEDIA .. "ring"
            -- 바깥 검은 원 + 링 바탕(어두운 판색)
            local black = item:CreateTexture(nil, "BACKGROUND", nil, -8)
            black:SetTexture(ns.MEDIA .. "circle")
            black:SetVertexColor(0, 0, 0, 0.95)
            black:SetPoint("TOPLEFT", -1, 1); black:SetPoint("BOTTOMRIGHT", 1, -1)
            local track = item:CreateTexture(nil, "BACKGROUND", nil, -7)
            track:SetTexture(ring)
            track:SetVertexColor(C.plate[1], C.plate[2], C.plate[3], 1)
            track:SetAllPoints()

            -- 아이콘: 링 안쪽으로 줄이고 동그랗게 자르기
            local icon = item.Icon or item.icon
            if icon then
                pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92)
                icon:ClearAllPoints()
                icon:SetPoint("TOPLEFT", item, "TOPLEFT", 3, -3)
                icon:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -3, 3)
                local mask = item:CreateMaskTexture()
                mask:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                mask:SetAllPoints(icon)
                pcall(icon.AddMaskTexture, icon, mask)
            end

            -- 남은 시간 = 분홍 링이 줄어듦, 숫자는 가운데
            local cd = FindCooldown(item)
            if cd then
                cd:ClearAllPoints()
                cd:SetAllPoints(item)
                pcall(cd.SetSwipeTexture, cd, ring)
                pcall(cd.SetSwipeColor, cd, C.acc[1], C.acc[2], C.acc[3], 1)
                pcall(cd.SetReverse, cd, true)
                pcall(cd.SetDrawEdge, cd, false)
                pcall(cd.SetDrawBling, cd, false)
                local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
                if not fs then
                    for _, r in ipairs({ cd:GetRegions() }) do
                        if r.GetObjectType and r:GetObjectType() == "FontString" then fs = r break end
                    end
                end
                if fs then
                    fs:SetFont(ns.NUM, 11, "OUTLINE")
                    fs:ClearAllPoints()
                    fs:SetPoint("CENTER", item, "CENTER", 0, 0)
                end
            end

            -- 중첩 숫자: 오른쪽 위 작은 숫자
            local count = (item.CountFrame and item.CountFrame.Count) or item.Count
            if count and count.SetFont then
                count:SetFont(ns.NUM, 9, "OUTLINE")
                count:SetTextColor(C.accHi[1], C.accHi[2], C.accHi[3])
            end

            -- 블리자드 기본 테두리는 숨김
            for _, key in ipairs({ "Border", "DebuffBorder", "IconBorder" }) do
                local t = item[key]
                if t and t.SetAlpha then t:SetAlpha(0) end
            end
        end
    end
end

local function PinAuras(af)
    local list = af.DebuffListFrame or af
    PinFrame(list)
    if af.DebuffListFrame then StyleAuraItems(af.DebuffListFrame) end
end

-- 디버프 줄 위치: 시전 중이면 시전바 글자 아래, 아니면 체력바 바로 아래
local function PlaceDebuffs(f)
    -- 위에서부터: 체력바 → 연계 점수 → 시전바(+글자) → 내 디버프. 없는 줄은 접힘
    local last, gap = f.hp, -4
    if f.combo:IsShown() then
        f.combo:ClearAllPoints()
        f.combo:SetPoint("TOPLEFT", f.hp, "BOTTOMLEFT", 6, -4)
        last = f.combo
    end
    f.cast:ClearAllPoints()
    f.cast:SetPoint("TOPLEFT", last, "BOTTOMLEFT", last == f.combo and -6 or 0, -4)
    f.cast:SetWidth(W)
    f.debRow:ClearAllPoints()
    if f.cast:IsShown() then
        f.debRow:SetPoint("TOPLEFT", f.cast, "BOTTOMLEFT", 2, -17)
    elseif last == f.combo then
        f.debRow:SetPoint("TOPLEFT", f.combo, "BOTTOMLEFT", -4, -5)
    else
        f.debRow:SetPoint("TOPLEFT", f.hp, "BOTTOMLEFT", 2, -7)
    end
    if f.auras then PinAuras(f.auras) end
end

-- 연계 점수: 연계 점수 쓰는 상태(기력)일 때, 지금 대상이거나 점수가 쌓인 몹에만
local function UpdateCombo(f, unit)
    local show = false
    if ns.UsesCombo() and not f.tapped then
        local n = ns.ComboOn(unit)
        local isTarget = Try(UnitIsUnit, unit, "target")
        local has = Try(function() return n and n > 0 end)
        if n ~= nil and (isTarget or has) then
            f.combo:SetCount(n)
            show = true
        end
    end
    if show ~= f.combo:IsShown() then
        f.combo:SetShown(show)
        PlaceDebuffs(f)
    end
end

-- 체력 %: 퀘스트 원이 있으면 원에 안 가리게 왼쪽으로
local function PlacePct(f)
    f.pct:ClearAllPoints()
    f.pct:SetPoint("RIGHT", f.hp, "RIGHT", f.quest:IsShown() and -18 or -8, 0)
end

----------------------------------------------------------------------
-- 갱신: 체력, 정보, 테두리
----------------------------------------------------------------------
-- 남의 몹 + 퀘스트 원(A안): 원 안 그림을 자물쇠로, 원은 회색, 개수는 흐리게. 바 끝 자물쇠는 숨김
local function TapQuest(f)
    local q = f.quest
    local onQuest = q:IsShown()
    if f.lock then f.lock:SetShown((f.tapped and not onQuest) and true or false) end
    q.fill:SetDesaturated(false); q.icon:SetDesaturated(false)
    q:SetAlpha(1)
    if f.tapped and onQuest then
        q.fill:SetVertexColor(0.29, 0.27, 0.275, 1)
        q.icon:SetTexture(ns.MEDIA .. "lock")
        q.icon:SetSize(26, 26)
        q.icon:SetVertexColor(0.93, 0.90, 0.91, 1)
        q.tag:SetAlpha(0.55)
        q.badge:SetAlpha(0.55)
    else
        if q.iconFile then q.icon:SetTexture(q.iconFile) end
        if q.fillColor then q.fill:SetVertexColor(q.fillColor[1], q.fillColor[2], q.fillColor[3], 1) end
        q.icon:SetSize(22, 22)
        q.icon:SetVertexColor(1, 1, 1, 1)
        q.tag:SetAlpha(1)
        q.badge:SetAlpha(1)
    end
end

-- 다른 사람이 먼저 친 몹(선점): 회색 바 + 빗금, 퀘스트 원은 흐리게
local function UpdateTap(f, unit)
    local tapped = UnitIsTapDenied and Try(UnitIsTapDenied, unit) or false
    if tapped == f.tapped then return end
    f.tapped = tapped
    ns.SetTapped(f.hp, tapped)
    -- C안: 바 끝 동그란 자물쇠 + 이름 가로줄 + 토끼 배지 흑백
    if tapped and not f.lock then
        local lk = CreateFrame("Frame", nil, f.hp.over)
        lk:SetSize(17, 17)
        lk:SetPoint("CENTER", f.hp, "RIGHT", 3, 0)
        lk:SetFrameLevel(f.hp.over:GetFrameLevel() + 4)
        local bg = lk:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(ns.MEDIA .. "circle"); bg:SetVertexColor(0.54, 0.51, 0.53, 1)
        bg:SetPoint("TOPLEFT", -1.5, 1.5); bg:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
        local in2 = lk:CreateTexture(nil, "BORDER")
        in2:SetTexture(ns.MEDIA .. "circle"); in2:SetVertexColor(0.17, 0.15, 0.16, 1)
        in2:SetAllPoints()
        local ic = lk:CreateTexture(nil, "ARTWORK")
        ic:SetTexture(ns.MEDIA .. "lock"); ic:SetPoint("CENTER"); ic:SetSize(11, 11)
        ic:SetVertexColor(0.92, 0.89, 0.90, 1)
        f.lock = lk
    end
    f.headTex:SetDesaturated(tapped and true or false)
    f.headTex:SetAlpha(tapped and 0.7 or 1)
    if tapped then
        f.lvColor = f.lvColor or { f.lv:GetTextColor() }
        f.lv:SetTextColor(0.72, 0.69, 0.70)
    elseif f.lvColor then
        f.lv:SetTextColor(f.lvColor[1], f.lvColor[2], f.lvColor[3]); f.lvColor = nil
    end
    ns.SetStrike(f.name, tapped)
    if not tapped then
        PaintPlate(f)
    else
        f.name:SetTextColor(0.76, 0.73, 0.74)
    end
    TapQuest(f)
end

-- 죽은 몹: 이름표는 숨김 (주울 게 있으면 Leel Spot이 반짝 상자를 대신 띄움)
local function UpdateDead(f, unit)
    local dead = (ns.db.npHideDead ~= false) and Try(UnitIsDead, unit) and true or false
    if f.dead == dead then return end
    f.dead = dead
    f:SetAlpha(dead and 0 or 1)
end

local function UpdateHealth(f, unit)
    UpdateDead(f, unit)
    local cur, max = UnitHealth(unit), UnitHealthMax(unit)
    ns.SetBar(f.hp.bar, cur, max)
    ns.HealthPercentText(f.pct, unit, cur, max)
    UpdateTap(f, unit)
end

local function UpdateInfo(f, unit)
    ns.SetText(f.name, UnitName(unit))
    if f.tapped then ns.SetStrike(f.name, true) end

    local lvl = UnitLevel(unit)
    local c = C.accHi
    if ns.IsSecret(lvl) then
        ns.SetText(f.lv, lvl)
    elseif lvl and lvl < 0 then
        f.lv:SetText("??"); c = { 1, 0.54, 0.44 }
    else
        f.lv:SetText(lvl or "")
        local getColor = GetCreatureDifficultyColor or GetQuestDifficultyColor
        if getColor and lvl then
            local d = getColor(lvl); c = { d.r, d.g, d.b }
        end
    end
    f.lvColor = nil   -- 새 몹 색으로 (남의 몹이면 UpdateTap이 다시 회색으로)
    f.lv:SetTextColor(c[1], c[2], c[3])
    if f.tapped then f.lvColor = { c[1], c[2], c[3] }; f.lv:SetTextColor(0.72, 0.69, 0.70) end

    -- 몹 등급 (숨겨진 값이면 일반으로)
    local rank = "normal"
    pcall(function()
        local cls = UnitClassification(unit)
        if cls == "elite" or cls == "rare" or cls == "rareelite" or cls == "minus" or cls == "trivial" then rank = cls end
        if cls == "worldboss" then rank = "boss" end
    end)
    pcall(function()
        if (UnitIsBossMob and UnitIsBossMob(unit)) or (not ns.IsSecret(lvl) and lvl and lvl < 0) then rank = "boss" end
    end)
    f.trivial = UnitIsTrivial and Try(UnitIsTrivial, unit) or false
    if f.trivial and rank == "normal" then rank = "trivial" end
    local R = RANK[rank] or RANK.normal
    f.rank = rank
    f.headTex:SetTexture(ns.MEDIA .. R.tex)
    -- 선공/비선공: 중립(노랑) 몹은 먼저 안 때려요 → 크림색 바
    local calm = false
    if ns.db.npAggro ~= false then
        -- ns.Try는 참/거짓만 돌려줘서 반응 숫자는 직접 읽어요 (숨겨진 값이면 선공으로)
        local ok, r = pcall(UnitReaction, unit, "player")
        if ok then
            local ok2, isCalm = pcall(function() return r == 4 end)
            calm = (ok2 and isCalm) and true or false
        end
    end
    f.calm = calm
    f:SetScale(R.small and 0.82 or 1)
    PaintPlate(f)
    if f.trivial then f.lv:SetTextColor(0.60, 0.63, 0.67) end
    FitTitle(f)
    f.tapped = nil
end

-- 테두리: 평소 장미색 / 내 대상 흰색 + 빛 / 나를 공격 중 빨강 + 빛
-- 대상이 있으면 대상이 아닌 이름표는 살짝 흐리게
local function UpdateBorder(f, unit)
    local isTarget = Try(UnitIsUnit, unit, "target")
    local aggro = Try(function()
        local st = UnitThreatSituation("player", unit)
        return st and st >= 2
    end)
    local c, a = C.edge, C.edge[4]
    f.glow:Hide()
    if aggro then
        c, a = C.dmg, 1
        f.glow:SetVertexColor(C.dmg[1], C.dmg[2], C.dmg[3], 0.45); f.glow:Show()
    elseif isTarget then
        c, a = { 1, 1, 1 }, 1
        f.glow:SetVertexColor(1, 0.84, 0.88, 0.4); f.glow:Show()
    end
    f.hp.border:SetVertexColor(c[1], c[2], c[3], a)
    if isTarget then f.name:SetTextColor(1, 1, 1)
    elseif not f.tapped then
        if f.trivial then f.name:SetTextColor(0.78, 0.80, 0.83)
        elseif f.calm then f.name:SetTextColor(CREAM_NAME[1], CREAM_NAME[2], CREAM_NAME[3])
        else f.name:SetTextColor(C.tx[1], C.tx[2], C.tx[3]) end
    end

    local alpha = 1
    if not isTarget and UnitExists("target") then alpha = 0.62 end
    if f.trivial then alpha = alpha * 0.8 end
    if f.dead then alpha = 0 end
    f:SetAlpha(alpha)

    local base = 0
    local uf = f:GetParent().UnitFrame
    if uf then base = uf:GetFrameLevel() end
    f:SetFrameLevel(base + (isTarget and 20 or 10))
    f:SetScale((ns.db.npScale or 1) * (isTarget and 1.08 or 1))
end

----------------------------------------------------------------------
-- 시전바
----------------------------------------------------------------------
local function StopCast(f)
    f.cast:SetScript("OnUpdate", nil)
    f.cast:Hide(); f.castName:Hide(); f.castTag:Hide()
    PlaceDebuffs(f)
end

local function UpdateCast(f, unit)
    if f.blizzCast then return end   -- 게임 시전바를 빌려 쓰는 중이면 게임이 알아서 그림
    local ok = pcall(function()
        local name, text, _, startMS, endMS, _, _, notInt = UnitCastingInfo(unit)
        local channel = false
        if not name then
            name, text, _, startMS, endMS, _, notInt = UnitChannelInfo(unit)
            channel = true
        end
        if not name then StopCast(f) return end

        local dur = endMS - startMS
        f.cast.bar:SetMinMaxValues(0, dur)
        if notInt then
            f.cast.fill:SetVertexColor(C.grey[1], C.grey[2], C.grey[3], 1)
            f.castTag:SetText("차단 불가")
            f.castTag:SetTextColor(C.tx2[1], C.tx2[2], C.tx2[3])
        else
            f.cast.fill:SetVertexColor(1, 0.54, 0.44, 1)
            f.castTag:SetText("차단 가능")
            f.castTag:SetTextColor(1, 0.70, 0.65)
        end
        f.castName:SetText(ns.CastLabel and ns.CastLabel((text ~= nil and text ~= "") and text or name) or name)
        f.castName:SetTextColor(1, 0.70, 0.65)

        f.cast:SetScript("OnUpdate", function()
            local now = GetTime() * 1000
            if now >= endMS then StopCast(f) return end
            f.cast.bar:SetValue(channel and (endMS - now) or (now - startMS))
        end)
        f.cast:Show(); f.castName:Show(); f.castTag:Show()
        PlaceDebuffs(f)
    end)
    if not ok then StopCast(f) end   -- 숨겨진 값이면 시전바 생략
end

----------------------------------------------------------------------
-- 내 디버프: WoW Forever는 애드온이 오라 정보를 읽는 걸 막음
-- → 게임이 직접 그리는 블리자드 디버프 칸(UnitFrame.AurasFrame)을
--   숨기지 않고 남겨서 우리 체력바 아래로 옮김 (남은 시간도 게임이 그림)
----------------------------------------------------------------------
local function AttachAuras(f, plate)
    local uf = plate and plate.UnitFrame
    local af = uf and uf.AurasFrame
    if not af then return end
    f.auras = af
    pcall(af.SetIgnoreParentAlpha, af, true)   -- 숨긴 블리자드 이름표와 달리 보이게
    local list = af.DebuffListFrame or af
    list.leelAnchor = f.debRow
    list:SetScale(1.3)   -- 블리자드 기본(0.75배)보다 크게 → 남은 시간 숫자가 안 잘리게
    if not list.leelHooked then
        list.leelHooked = true
        hooksecurefunc(list, "SetPoint", PinFrame)
        -- 아이콘이 새로 생길 때마다 테두리 입히기
        if list.Layout then hooksecurefunc(list, "Layout", function(self) StyleAuraItems(self) end) end
        list:HookScript("OnShow", function(self) StyleAuraItems(self) end)
    end
    -- 적 버프 줄은 숨김 (내 디버프만)
    if af.BuffListFrame then HideFrame(af.BuffListFrame, true) end
    PinAuras(af)
end

----------------------------------------------------------------------
-- 시전바: 전투 중 시전 정보(시간·이름)는 숨겨진 값이라 애드온이 직접 못 그림
-- → 디버프처럼 블리자드 이름표 시전바를 빌려 와서 우리 알약 자리에 고정 + 모양만 입힘
--   (색: 게임 기본 = 끊을 수 있음 주황 / 못 끊음 회색)
----------------------------------------------------------------------
local function PinCast(cb)
    local f = cb.leelOwner
    if cb.leelMoving or not f then return end
    cb.leelMoving = true
    cb:ClearAllPoints()
    cb:SetPoint("TOPLEFT", f.cast, "TOPLEFT", 1, -1)
    cb:SetPoint("BOTTOMRIGHT", f.cast, "BOTTOMRIGHT", -1, 1)
    if cb.Text then
        cb.Text:ClearAllPoints()
        cb.Text:SetPoint("TOPLEFT", f.cast, "BOTTOMLEFT", 2, -2)
    end
    cb.leelMoving = false
end

local function SyncCast(cb)
    local f = cb.leelOwner
    if not f then return end
    f.cast:SetShown(cb:IsShown())
    PlaceDebuffs(f)
end

local function StyleCast(cb)
    if cb.leelStyled then return end
    cb.leelStyled = true
    for _, k in ipairs({ "Background", "Border", "Spark", "Icon", "BorderShield", "TextBorder",
                         "ImportantCastIndicator", "CastTargetIndicator", "CastTargetNameText", "Flash" }) do
        local r = cb[k]
        if r and r.SetAlpha then HideFrame(r, true) end
    end
    -- 채움을 알약 모양으로 자르기
    local function MaskFill()
        local fill = cb:GetStatusBarTexture()
        if fill and not fill.leelMasked then
            fill.leelMasked = true
            local m = cb:CreateMaskTexture()
            m:SetTexture(ns.MEDIA .. "pill32", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            m:SetAllPoints(cb)
            pcall(fill.AddMaskTexture, fill, m)
        end
    end
    MaskFill()
    hooksecurefunc(cb, "SetStatusBarTexture", MaskFill)
    if cb.Text then
        cb.Text:SetFont(ns.FONT, 10, "OUTLINE")
        cb.Text:SetShadowColor(0, 0, 0, 0.9)
        cb.Text:SetShadowOffset(1, -1)
        cb.Text:SetJustifyH("LEFT")
        cb.Text:SetTextColor(1, 0.70, 0.65)
    end
    hooksecurefunc(cb, "SetPoint", PinCast)
    cb:HookScript("OnShow", function(self) PinCast(self); SyncCast(self) end)
    cb:HookScript("OnHide", SyncCast)
end

local function AttachCast(f, plate)
    local uf = plate and plate.UnitFrame
    local cb = uf and ((uf.CastBarsContainer and uf.CastBarsContainer.castBar) or uf.castBar or uf.CastBar)
    if not cb then f.blizzCast = nil return end
    f.blizzCast = cb
    cb.leelOwner = f
    pcall(cb.SetIgnoreParentAlpha, cb, true)
    StyleCast(cb)
    f.cast.bar:Hide()            -- 우리 바는 판(바탕)만, 채움은 게임 시전바
    f.castName:Hide(); f.castTag:Hide()
    PinCast(cb)
    SyncCast(cb)
end

local function DetachCast(plate)
    local uf = plate and plate.UnitFrame
    local cb = uf and ((uf.CastBarsContainer and uf.CastBarsContainer.castBar) or uf.castBar or uf.CastBar)
    if not cb then return end
    cb.leelOwner = nil
    pcall(cb.SetIgnoreParentAlpha, cb, false)
end

local function DetachAuras(plate)
    local uf = plate and plate.UnitFrame
    local af = uf and uf.AurasFrame
    if not af then return end
    local list = af.DebuffListFrame or af
    list.leelAnchor = nil
    list:SetScale(1)
    if af.BuffListFrame then HideFrame(af.BuffListFrame, false) end
    pcall(af.SetIgnoreParentAlpha, af, false)
end

----------------------------------------------------------------------
-- Questie 퀘스트 원
----------------------------------------------------------------------
local QTooltips
local function QuestieTooltips()
    if QTooltips == nil then
        QTooltips = false
        if QuestieLoader and QuestieLoader.ImportModule then
            local ok, m = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieTooltips")
            if ok and m then QTooltips = m end
        end
    end
    return QTooltips or nil
end

-- 이 몹에 걸린 목표들: 진행 중 목표 수, 대표 목표(아이콘 종류, 모은 수/필요 수), 전부 완료 여부
local function QuestInfo(unit)
    local qt = QuestieTooltips()
    if not (qt and qt.lookupByKey and Questie) then return end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or type(guid) ~= "string" then return end
    local kind, _, _, _, _, npcId = strsplit("-", guid)
    if (kind ~= "Creature" and kind ~= "Vehicle") or not npcId then return end
    local tips = qt.lookupByKey["m_" .. npcId]
    if not tips then return end

    local open, first, last, seen = 0, nil, nil, {}
    for _, tip in pairs(tips) do
        local obj = tip.objective
        if obj and not seen[obj] then
            seen[obj] = true
            if obj.Update then pcall(obj.Update, obj) end
            last = obj
            if not obj.Completed then
                open = open + 1
                first = first or obj
            end
        end
    end
    if not last then return end
    local obj = first or last
    local isLoot = obj.Icon == Questie.ICON_TYPE_LOOT or obj.Icon == Questie.ICON_TYPE_OBJECT
    return {
        done = (first == nil),
        open = open,
        loot = isLoot,
        have = tonumber(obj.Collected),
        need = tonumber(obj.Needed),
    }
end

local function UpdateQuest(f, unit)
    local q = f.quest
    local ok, info = pcall(QuestInfo, unit)
    if not ok or not info or ns.db.questCircle == false then
        q:Hide()
        TapQuest(f)
        HideQuestieIcon(f:GetParent(), false)
        PlacePct(f)
        return
    end

    if info.done then
        q.fillColor = { 0.353, 0.29, 0.278 }
        q.iconFile = ns.MEDIA .. "q_done"
        q.tagBg:SetColor({ 0.54, 0.48, 0.46 })
        q.count:SetTextColor(C.tx[1], C.tx[2], C.tx[3])
    else
        q.fillColor = C.acc
        q.iconFile = ns.MEDIA .. (info.loot and "q_loot" or "q_slay")
        q.tagBg:SetColor(C.accHi)
        q.count:SetTextColor(C.ink[1], C.ink[2], C.ink[3])
    end

    if info.need and info.need > 0 then
        q.count:SetFormattedText("%d/%d", info.have or 0, info.need)
        q.tag:SetWidth(q.count:GetStringWidth() + 9)
        q.tag:Show()
    else
        q.tag:Hide()
    end

    q.badge:SetShown(info.open > 1)
    q.badgeText:SetText(info.open)

    q:Show()
    TapQuest(f)
    HideQuestieIcon(f:GetParent(), true)
    PlacePct(f)
end

----------------------------------------------------------------------
-- 이름표 붙이기 / 떼기
----------------------------------------------------------------------
-- 상호작용 대상(시체 줍기 표시용)에 게임이 억지로 만든 우호 NPC 이름표는 안 보이게
-- (우호 이름표를 켜 둔 경우는 그대로)
-- 우호 NPC: 이름만 남기고 나머지(체력바, 레벨, 시전바, 점 아이콘)는 숨기기
local function SetFriendlyBars(plate, hide)
    SetBlizzAlpha(plate, 1)
    local uf = plate.UnitFrame
    if not uf then return end
    local name = uf.name or uf.Name
    local holder = name and name.GetParent and name:GetParent()
    for _, f in ipairs({ uf:GetChildren() }) do
        if f.SetAlpha and f ~= holder then HideFrame(f, hide) end
    end
    for _, r in ipairs({ uf:GetRegions() }) do
        if r ~= name and r.SetAlpha then HideFrame(r, hide) end
    end
    if name and name.SetAlpha then HideFrame(name, false) end
end

local function FriendlyForced(unit)
    if GetCVar("nameplateShowFriends") == "1" then return false end
    return Try(UnitIsUnit, unit, "softinteract") and true or false
end

local function OnAdded(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end

    if not Try(UnitCanAttack, "player", unit) then
        if plate.leel then plate.leel:Hide() end
        DetachAuras(plate)
        DetachCast(plate)
        SetFriendlyBars(plate, FriendlyForced(unit))
        return
    end

    local f = plate.leel or Build(plate)
    f.unit = unit
    f.dead = nil
    active[unit] = f
    SetBlizzAlpha(plate, 0)
    f:Show()
    AttachAuras(f, plate)
    AttachCast(f, plate)
    UpdateInfo(f, unit)
    UpdateHealth(f, unit)
    UpdateCast(f, unit)
    UpdateRaid(f, unit)
    UpdateQuest(f, unit)
    f.tapped = nil; UpdateTap(f, unit)
    UpdateCombo(f, unit)
    UpdateBorder(f, unit)
    -- Questie 아이콘은 우리 다음에 붙을 수 있어서 한 번 더
    C_Timer.After(0.2, function() if active[unit] == f then UpdateQuest(f, unit) end end)
end

local function OnRemoved(unit)
    local f = active[unit]
    if f then
        StopCast(f)
        DetachAuras(f:GetParent())
        DetachCast(f:GetParent())
        f.blizzCast = nil
        f:Hide()
        active[unit] = nil
    end
end

-- 허브 스위치: 선공/비선공 구별 다시 그리기
function ns:RefreshPlateInfo()
    for u, f in pairs(active) do UpdateInfo(f, u); UpdateBorder(f, u) end
end

function ns:RefreshDeadPlates()
    for u, f in pairs(active) do
        f.dead = nil
        UpdateDead(f, u)
        if not f.dead then UpdateBorder(f, u) end
    end
end

function ns:RefreshNameplates()
    for u, f in pairs(active) do
        UpdateQuest(f, u)
        UpdateBorder(f, u)
    end
end

----------------------------------------------------------------------
-- 이벤트
----------------------------------------------------------------------
function ns:EnableNameplates()
    if not C_NamePlate or ns.npEvents then return end

    local ev = CreateFrame("Frame")
    ns.npEvents = ev
    for _, e in ipairs({
        "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED",
        "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_LEVEL",
        "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE",
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
        "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
        "UNIT_SPELLCAST_CHANNEL_UPDATE",
        "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
        "QUEST_LOG_UPDATE", "UNIT_FLAGS", "UNIT_POWER_FREQUENT", "RAID_TARGET_UPDATE",
        "PLAYER_SOFT_INTERACT_CHANGED", "UNIT_FACTION",
    }) do
        pcall(ev.RegisterEvent, ev, e)
    end

    local questPending = false
    ev:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            OnAdded(unit)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            OnRemoved(unit)
        elseif event == "PLAYER_SOFT_INTERACT_CHANGED" then
            for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
                local u = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
                if u and not Try(UnitCanAttack, "player", u) then SetFriendlyBars(plate, FriendlyForced(u)) end
            end
        elseif event == "RAID_TARGET_UPDATE" then
            for u, f in pairs(active) do UpdateRaid(f, u) end
        elseif event == "PLAYER_TARGET_CHANGED" then
            for u, f in pairs(active) do UpdateBorder(f, u); UpdateCombo(f, u) end
        elseif event == "UNIT_POWER_FREQUENT" then
            if unit == "player" then
                for u, f in pairs(active) do UpdateCombo(f, u) end
            end
        elseif event == "QUEST_LOG_UPDATE" then
            -- 퀘스트 진행이 바뀌면 잠깐 모아서 한 번에 갱신 (Questie가 먼저 반영하도록)
            if questPending then return end
            questPending = true
            C_Timer.After(0.5, function()
                questPending = false
                for u, f in pairs(active) do UpdateQuest(f, u) end
            end)
        else
            local f = unit and active[unit]
            if not f then return end
            if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS" then
                UpdateHealth(f, unit)
            elseif event == "UNIT_NAME_UPDATE" or event == "UNIT_LEVEL" or event == "UNIT_FACTION" then
                UpdateInfo(f, unit)
            elseif event:find("THREAT") then
                UpdateBorder(f, unit)
            else
                UpdateCast(f, unit)
            end
        end
    end)

    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local u = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if u then OnAdded(u) end
    end
end
