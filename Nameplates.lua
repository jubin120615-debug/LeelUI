-- LeelUI / Nameplates.lua
-- 적 이름표: 15px 알약 바 + 검은 외곽, 체력 %, 대상 강조, 6px 시전바,
-- 내 디버프(게임 디버프 칸을 옮겨 붙임), 퀘스트 원(칼 / 줍는 손 / 체크) — Questie가 있으면 그 자료, 없으면 QuestMobs.lua

local _, ns = ...

local Try = ns.Try
local C = ns.C
local active = {}   -- unit -> 우리 이름표 프레임

local W, H = 164, 15
local CAST_H, CAST_ICON = 10, 0
local CAST_COLOR = { int = { 1, 0.54, 0.44 }, no = { C.grey[1], C.grey[2], C.grey[3] }, stop = { 0.85, 0.25, 0.30 } }
local DEB_SIZE = 20

-- 허브 > 적 이름표 세부 설정 (기본값 = 지금 모습)
local NP_DEF = { cast = "all", deb = true, combo = true, size = 100, hpTxt = "pct", lvRank = "both", nameAdd = 0,
                 shine = true, dim = 62, tapped = "grey", exec = "off", aggro = true, raid = "left" }
local function NPO(k)
    local t = ns.db and ns.db.npO
    local v = t and t[k]
    if v == nil then return NP_DEF[k] end
    return v
end
ns.NPOpt = NPO
local function SizeK() return (tonumber(NPO("size")) or 100) / 100 end

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

-- 몹 등급 = 레벨 앞 아이콘 알약 (둥근 광택 알약 + 흰 모양 + 글자 · 일반 · 하찮음은 없음)
local BADGE = 0
local RANK = {
    elite     = { txt = "정예",      ic = "ic_shield", top = { 0.957, 0.812, 0.408 }, bot = { 0.851, 0.647, 0.227 }, ink = { 0.227, 0.149, 0.031 } },
    rare      = { txt = "희귀",      ic = "ic_star",   top = { 0.890, 0.914, 0.949 }, bot = { 0.682, 0.725, 0.788 }, ink = { 0.149, 0.188, 0.239 } },
    rareelite = { txt = "희귀 정예", ic = "ic_star",   top = { 0.769, 0.902, 1.000 }, bot = { 0.498, 0.737, 0.918 }, ink = { 0.071, 0.188, 0.290 } },
    boss      = { txt = "보스",      ic = "ic_crown",  top = { 1.000, 0.541, 0.541 }, bot = { 0.878, 0.290, 0.333 }, ink = { 0.227, 0.047, 0.071 } },
    minus     = { small = true },
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

-- 바·이름 색: 하찮음 회색 / 비선공 크림 / 선공 루비 레드
local function PaintPlate(f)
    -- 낮은(하찮은) 몹도 색은 그대로 (빨강 = 선공 · 크림 = 비선공), 대신 바를 얇게 + 흐리게 + 이름만 회색
    if f.aura then f.aura:Hide() end
    local low = f.trivial and true or false
    local k = SizeK()
    if f.lowShape ~= low or f.sizeK ~= k then
        f.lowShape, f.sizeK = low, k
        f.hp:SetSize(math.floor(W * k + 0.5), math.max(5, math.floor((low and (H - 5) or H) * k + 0.5)))
        f.pct:SetFont(ns.NUM, low and 10 or 13, "OUTLINE")
    end
    if f.calm then
        PaintCream(f.hp)
        f.name:SetTextColor(CREAM_NAME[1], CREAM_NAME[2], CREAM_NAME[3])
    else
        ns.PaintHealthRed(f.hp)
        f.name:SetTextColor(C.tx[1], C.tx[2], C.tx[3])
    end
    if low then f.name:SetTextColor(0.78, 0.80, 0.83) end
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
    -- 내 대상: 바를 따라 하얀 빛이 스윽 지나가요 (바 안쪽만 보이게 자름)
    local clip = CreateFrame("Frame", nil, f.hp)
    clip:SetPoint("TOPLEFT", 1, -1); clip:SetPoint("BOTTOMRIGHT", -1, 1)
    clip:SetClipsChildren(true); clip:SetFrameLevel(f.hp:GetFrameLevel() + 3)
    local sh = clip:CreateTexture(nil, "OVERLAY")
    sh:SetTexture(ns.MEDIA .. "soft_glow"); sh:SetBlendMode("ADD"); sh:SetVertexColor(1, 1, 1, 0.75)
    sh:SetSize(30, H * 2.4)
    clip.t = 0
    clip:SetScript("OnUpdate", function(self, el)
        self.t = (self.t + el) % 1.6
        local w = self:GetWidth() or W
        local x = -20 + (w + 40) * math.min(1, self.t / 1.1)   -- 1.1초 지나가고 0.5초 쉬어요
        sh:ClearAllPoints(); sh:SetPoint("CENTER", self, "LEFT", x, 0)
        sh:SetAlpha(self.t < 1.1 and 0.75 or 0)
    end)
    clip:Hide()
    f.shine = clip
    -- 내 대상 표시 (허브에서 고르기): 조준 = "착" 조여들고 천천히 돌아요 · 화살표 = 톡 떨어져 콩콩
    local sw = CreateFrame("Frame", nil, f); sw:SetSize(26, 26); sw:SetFrameLevel(f.hp:GetFrameLevel() + 8)
    sw.tex = sw:CreateTexture(nil, "OVERLAY"); sw.tex:SetAllPoints()
    sw:Hide()
    sw:SetScript("OnUpdate", function(self, el)
        self.t = (self.t or 0) + el
        local t = self.t
        -- 색 = 이 적 체력바 색 (선공 빨강 · 비선공 크림 · 남의 몹 회색)
        if f.tapped then self.tex:SetVertexColor(0.72, 0.69, 0.70)
        elseif f.calm then self.tex:SetVertexColor(1.00, 0.86, 0.60)
        else self.tex:SetVertexColor(0.949, 0.439, 0.498) end
        if self.style == "arrow" then
            local y, a = 0, 1
            if t < 0.2 then local k = 1 - (1 - t / 0.2) ^ 3; y = 16 * (1 - k); a = k
            else y = 4 * math.abs(math.sin((t - 0.2) * math.pi / 0.6)) end
            self:SetScale(1); self:SetAlpha(a)
            self:ClearAllPoints(); self:SetPoint("BOTTOM", f.hp, "TOP", 0, 22 + y)
            self.tex:SetRotation(0)
        else
            local sc, a = 1, 1
            if t < 0.2 then local k = 1 - (1 - t / 0.2) ^ 3; sc = 1.9 - 0.9 * k; a = k end
            self:SetScale(sc); self:SetAlpha(a)
            self:ClearAllPoints(); self:SetPoint("BOTTOM", f.hp, "TOP", 0, 20 / sc)
            self.tex:SetRotation(-t * 2 * math.pi / 4)   -- 4초에 한 바퀴
        end
    end)
    function sw:Stab()
        self.style = ns.db.npMark or "aim"
        self.ms = (tonumber(ns.db.npMarkScale) or 100) / 100   -- 허브 > 적 이름표 > 표시 크기
        if self.style == "arrow" then self:SetSize(22 * self.ms, 16 * self.ms); self.tex:SetTexture(ns.MEDIA .. "np_arrow")
        else self:SetSize(26 * self.ms, 26 * self.ms); self.tex:SetTexture(ns.MEDIA .. "np_aim") end
        self.t = 0; self:Show()
    end
    function sw:Off() self:Hide() end
    f.sword = sw
    -- 회색(레벨 낮은) 몹 아우라: 바는 회색, 둘레 빛으로 선공(빨강) · 비선공(노랑)
    f.aura = f.hp:CreateTexture(nil, "BACKGROUND", nil, -3)
    f.aura:SetTexture(ns.MEDIA .. "np_glow")          -- 가장자리가 흐려지는 빛 (부드럽게 번져요)
    f.aura:SetBlendMode("ADD")
    f.aura:SetPoint("TOPLEFT", -11, 11); f.aura:SetPoint("BOTTOMRIGHT", 11, -11)
    f.aura:Hide()
    ns.PaintHealthRed(f.hp)

    f.pct = Outline(f.hp.over:CreateFontString(nil, "OVERLAY"), 13, ns.NUM)
    f.pct:SetTextColor(1, 1, 1)

    -- 이름 줄 (가운데): [등급 토끼 배지] 레벨 이름
    f.title = CreateFrame("Frame", nil, f)
    f.title:SetSize(1, 18)
    f.title:SetPoint("BOTTOM", f.hp, "TOP", 0, 3)
    f.head = CreateFrame("Frame", nil, f.title)
    f.head:SetSize(1, 15)
    f.head:SetPoint("LEFT", f.title, "LEFT", 0, 0)
    do  -- 알약 = 왼끝 · 가운데 · 오른끝 (끝이 안 찌그러지게) · 진한 테 → 그라데이션 속 → 위쪽 광택
        local function Pill(layer, sub, grow)
            local function Piece(l, r)
                local t = f.head:CreateTexture(nil, layer, nil, sub)
                t:SetTexture(ns.MEDIA .. "circle"); t:SetTexCoord(l, r, 0, 1)   -- 동그라미 반쪽 = 완전히 둥근 끝
                return t
            end
            local h = 15 + grow * 2
            local L, M, R = Piece(0, 0.5), Piece(0.5, 0.5), Piece(0.5, 1)
            L:SetSize(h / 2, h); L:SetPoint("LEFT", -grow, 0)
            R:SetSize(h / 2, h); R:SetPoint("RIGHT", grow, 0)
            M:SetPoint("TOPLEFT", L, "TOPRIGHT"); M:SetPoint("BOTTOMRIGHT", R, "BOTTOMLEFT")
            return { L, M, R }
        end
        f.headEdge = Pill("BORDER", 0, 1.5)
        for _, t in ipairs(f.headEdge) do t:SetVertexColor(0.165, 0.102, 0.078, 1) end
        f.headParts = Pill("ARTWORK", 0, 0)
        f.headGloss = f.head:CreateTexture(nil, "ARTWORK", nil, 2)
        f.headGloss:SetTexture(ns.MEDIA .. "circle")
        f.headGloss:SetPoint("TOPLEFT", 5, -1.5); f.headGloss:SetPoint("TOPRIGHT", -5, -1.5)
        f.headGloss:SetHeight(3.5)
        f.headGloss:SetVertexColor(1, 1, 1, 0.38)
    end
    f.headIcon = f.head:CreateTexture(nil, "OVERLAY")
    f.headIcon:SetSize(9, 9)
    f.headIcon:SetPoint("LEFT", 5, 0)
    f.headTxt = f.head:CreateFontString(nil, "OVERLAY")
    f.headTxt:SetFont(ns.FONT, 10, "")
    f.headTxt:SetPoint("LEFT", f.headIcon, "RIGHT", 2.5, 0)
    f.head:Hide()
    f.lv = Outline(f.title:CreateFontString(nil, "OVERLAY"), 13, ns.NUM)
    f.lv:SetPoint("LEFT", f.title, "LEFT", 0, 0)
    f.name = Outline(f.title:CreateFontString(nil, "OVERLAY"), 13)
    f.name:SetPoint("LEFT", f.lv, "RIGHT", 4, 0)

    -- 시전바: 왼쪽 주문 아이콘 + 14px 바, 바 안에 주문 이름 · 남은 초, 끊을 수 있으면 둘레가 빛남
    -- 시전바 C: 10px 바 + 아래 주문 이름 13 굵게 · 오른쪽 "차단 가능/불가"
    f.cast = ns.CreateSkewBar(f, W, CAST_H, { inset = 1, noShadow = true, shape = "pill32" })
    f.cast:SetPoint("TOP", f.hp, "BOTTOM", 0, -4)
    f.castName = Outline(f:CreateFontString(nil, "OVERLAY"), 13)
    f.castName:SetPoint("TOPLEFT", f.cast, "BOTTOMLEFT", 2, -2)
    f.castName:SetPoint("RIGHT", f.cast, "RIGHT", -64, 0)
    f.castName:SetJustifyH("LEFT"); f.castName:SetWordWrap(false)
    f.castTag = Outline(f:CreateFontString(nil, "OVERLAY"), 11)
    f.castTag:SetPoint("TOPRIGHT", f.cast, "BOTTOMRIGHT", -2, -3)
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

local function PlaceRaid(f)
    f.raid:ClearAllPoints()
    if NPO("raid") == "top" then f.raid:SetPoint("BOTTOM", f.title, "TOP", 0, 2)
    else f.raid:SetPoint("RIGHT", f.hp, "LEFT", -4, 0) end
end
-- 징 번호가 숨겨진 값이면(던전 · 전투 중 등) 애드온이 직접 못 그려요
-- → 블리자드 이름표의 징 칸을 빌려 와서 우리 징 자리에 보이게 (게임이 알아서 그림)
local function BlizzRaid(f, on)
    local plate = f:GetParent()
    local uf = plate and plate.UnitFrame
    local rf = uf and (uf.RaidTargetFrame or uf.raidTargetFrame)
    if not rf then return end
    if on then
        if rf.leelHidden then HideFrame(rf, false) end
        pcall(rf.SetIgnoreParentAlpha, rf, true); pcall(rf.SetAlpha, rf, 1)
        pcall(function() rf:ClearAllPoints(); rf:SetPoint("CENTER", f.raid, "CENTER", 0, 0) end)
        rf.leelOn = true
    elseif rf.leelOn then
        rf.leelOn = nil
        pcall(rf.SetIgnoreParentAlpha, rf, false); pcall(rf.SetAlpha, rf, 0)   -- 우리 그림으로 그릴 땐 게임 징은 숨겨요 (두 개 겹쳐 보이지 않게)
    end
end
local function UpdateRaid(f, unit)
    PlaceRaid(f)
    -- 숨겨진 값이어도 에러 없이: 통째로 pcall
    local ok, shown, idx = pcall(function()
        local i = GetRaidTargetIndex(unit)
        if i == nil then return false end
        if issecretvalue and issecretvalue(i) then error("secret") end
        SetRaidTargetIconTexture(f.raid, i)
        return true, (i >= 1 and i <= 8) and i or nil
    end)
    -- 게임이 징을 숨겨도 Leel Mark 가 찍은 징이면 무슨 징인지 알아요 → 우리 그림으로 (크기를 바꿀 수 있게)
    local mem = (not ok) and ns.MarkMemory and ns.MarkMemory(unit)
    if mem then
        SetRaidTargetIconTexture(f.raid, mem); f.raid:Show()
        BlizzRaid(f, false)
        if ns.MarkOrderPaint then ns.MarkOrderPaint(f, unit, mem, false) end
        return
    end
    f.raid:SetShown(ok and shown or false)
    BlizzRaid(f, not ok)
    if ns.MarkOrderPaint then ns.MarkOrderPaint(f, unit, ok and shown and idx or nil, not ok) end
end

-- 허브: 레벨 · 등급 알약 보이기 · 이름 글씨 크기
local function ApplyTitle(f)
    local m = NPO("lvRank")
    if m ~= "both" and f.head:IsShown() then
        f.head:Hide()
        f.lv:ClearAllPoints(); f.lv:SetPoint("LEFT", f.title, "LEFT", 0, 0)
    end
    f.lv:SetAlpha(m == "off" and 0 or 1)
    f.name:ClearAllPoints()
    if m == "off" then f.name:SetPoint("LEFT", f.title, "LEFT", 0, 0)
    else f.name:SetPoint("LEFT", f.lv, "RIGHT", 4, 0) end
    local add = tonumber(NPO("nameAdd")) or 0
    if f.nameAdd ~= add then f.nameAdd = add; Outline(f.name, math.max(8, 13 + add)) end
end

-- 레벨+이름 묶음 가운데 정렬
-- (전투 중 이름이 숨겨진 값이면 글자 폭도 숨겨져서 계산 불가 → 바 폭으로 대신)
local function FitTitle(f)
    local function Wd(fs, fb)
        local ok, v = pcall(function() return math.max(fs:GetStringWidth() or 0, 0) end)
        return ok and v or fb
    end
    local pre = f.head:IsShown() and (f.head:GetWidth() + 5) or 0
    local lvw = (NPO("lvRank") == "off") and 0 or (Wd(f.lv, 16) + 4)
    f.title:SetWidth(pre + lvw + Wd(f.name, W - 40))
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
    f.cast:SetWidth(math.floor(W * SizeK() + 0.5))
    f.debRow:ClearAllPoints()
    if f.cast:IsShown() then
        f.debRow:SetPoint("TOPLEFT", f.cast, "BOTTOMLEFT", 2, -21)
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
    if NPO("combo") and ns.UsesCombo() and not f.tapped then
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
local RefreshInfo   -- 아래 UpdateInfo (선점이 풀리면 레벨·등급을 다시 읽음)
local function UpdateTap(f, unit)
    local tapped = UnitIsTapDenied and Try(UnitIsTapDenied, unit) or false
    if NPO("tapped") == "keep" then tapped = false end   -- 허브 '남의 몹: 그대로'

    if tapped == f.tapped then return end
    -- 레벨 맞춤 지역: 남이 친 몹은 그 사람 레벨로 보이다가, 선점이 풀리면 내 레벨 기준으로 바뀜
    -- 이때 레벨 바뀜 알림이 안 와서 이름표 레벨이 예전 숫자로 남음 → 선점이 바뀔 때마다 다시 읽기
    if f.tapped ~= nil and RefreshInfo then
        f.tapped = nil
        RefreshInfo(f, unit)
    end
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
    for _, t in ipairs(f.headParts) do t:SetDesaturated(tapped and true or false) end
    if f.headIcon then f.headIcon:SetDesaturated(tapped and true or false) end
    f.head:SetAlpha(tapped and 0.7 or 1)
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
    -- 징 순서용: 숨기기 설정과 상관없이 죽었는지 따로
    local reallyDead = Try(UnitIsDead, unit) and true or false
    if f.reallyDead ~= reallyDead then
        f.reallyDead = reallyDead
        if f.markN and ns.NPMarkScanOnly then C_Timer.After(0, ns.NPMarkScanOnly) end   -- 징 몹이 죽으면 바로 다음 몹으로
    end
    if f.dead == dead then return end
    f.dead = dead
    f:SetAlpha(dead and 0 or 1)
end

local function HpText(f, unit, cur, max)
    local m = NPO("hpTxt")
    if m == "off" then f.pct:SetText("") return end
    if m == "pct" then ns.HealthPercentText(f.pct, unit, cur, max) return end
    local ok = pcall(function()
        local n = BreakUpLargeNumbers and BreakUpLargeNumbers(cur) or tostring(cur)
        if m == "both" and max and max > 0 then
            f.pct:SetFormattedText("%s · %d%%", n, math.floor(cur / max * 100 + 0.5))
        else
            f.pct:SetText(n)
        end
    end)
    if not ok then
        if m == "both" then ns.HealthPercentText(f.pct, unit, cur, max) else ns.SetText(f.pct, cur) end
    end
end
-- 체력 낮으면 강조 (허브 '처형 구간'): 바를 주황으로
local EXEC_COL = { 1, 0.62, 0.25 }
local function UpdateExec(f, cur, max)
    local th = NPO("exec")
    local on = false
    if th ~= "off" and not f.tapped then
        local lim = (th == "35") and 0.35 or 0.20
        local ok, r = pcall(function() return max and max > 0 and (cur / max) <= lim end)
        on = ok and r and true or false
    end
    if f.execOn == on then return end
    f.execOn = on
    if on then ns.PaintFlat(f.hp, EXEC_COL) elseif not f.tapped then PaintPlate(f) end
end
local function UpdateHealth(f, unit)
    UpdateDead(f, unit)
    local cur, max = UnitHealth(unit), UnitHealthMax(unit)
    ns.SetBar(f.hp.bar, cur, max)
    HpText(f, unit, cur, max)
    UpdateTap(f, unit)
    UpdateExec(f, cur, max)
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
    local R = RANK[rank] or {}
    f.rank = rank
    if R.txt then
        for _, t in ipairs(f.headParts) do
            if t.SetGradient and CreateColor then
                t:SetVertexColor(1, 1, 1, 1)
                t:SetGradient("VERTICAL", CreateColor(R.bot[1], R.bot[2], R.bot[3], 1), CreateColor(R.top[1], R.top[2], R.top[3], 1))
            else
                t:SetVertexColor(R.top[1], R.top[2], R.top[3], 1)
            end
        end
        f.headIcon:SetTexture(ns.MEDIA .. R.ic)
        f.headIcon:SetVertexColor(1, 1, 1, 1)
        f.headTxt:SetText(R.txt)
        f.headTxt:SetTextColor(R.ink[1], R.ink[2], R.ink[3], 1)
        f.head:SetWidth(math.max(15, (f.headTxt:GetStringWidth() or 20) + 9 + 2.5 + 12))
        f.head:Show()
        f.lv:ClearAllPoints(); f.lv:SetPoint("LEFT", f.head, "RIGHT", 5, 0)
    else
        f.head:Hide()
        f.lv:ClearAllPoints(); f.lv:SetPoint("LEFT", f.title, "LEFT", 0, 0)
    end
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
    f.execOn = nil
    PaintPlate(f)
    if f.trivial then f.lv:SetTextColor(0.60, 0.63, 0.67) end
    ApplyTitle(f)
    FitTitle(f)
    f.tapped = nil
end
RefreshInfo = UpdateInfo

-- 테두리: 평소 장미색 / 내 대상 흰색 + 빛 / 나를 공격 중 빨강 + 빛
-- 대상이 있으면 대상이 아닌 이름표는 살짝 흐리게
local function UpdateBorder(f, unit)
    local isTarget = Try(UnitIsUnit, unit, "target")
    local aggro = NPO("aggro") and Try(function()
        local st = UnitThreatSituation("player", unit)
        return st and st >= 2
    end)
    local c, a = C.edge, C.edge[4]
    f.glow:Hide()
    if aggro then
        c, a = C.dmg, 1
        f.glow:SetVertexColor(C.dmg[1], C.dmg[2], C.dmg[3], 0.45); f.glow:Show()
    elseif isTarget then
        c, a = { 1, 0.561, 0.639 }, 1   -- 내 대상: 분홍 테 + 분홍 빛
        f.glow:SetVertexColor(1, 0.561, 0.639, 0.6); f.glow:Show()
    end
    if f.shine then
        if isTarget and not f.dead and NPO("shine") then if not f.shine:IsShown() then f.shine.t = 0 end; f.shine:Show() else f.shine:Hide() end
    end
    if f.sword and (ns.db.npMark or "aim") ~= "off" then
        local on = isTarget and not f.dead
        if on and (not f.wasTarget or f.sword.style ~= (ns.db.npMark or "aim") or f.sword.ms ~= (tonumber(ns.db.npMarkScale) or 100) / 100) then f.sword:Stab() elseif not on and f.wasTarget then f.sword:Off() end
        f.wasTarget = on
    elseif f.sword and f.wasTarget then f.sword:Off(); f.wasTarget = false end
    f.hp.border:SetVertexColor(c[1], c[2], c[3], a)
    if isTarget then f.name:SetTextColor(1, 1, 1)
    elseif not f.tapped then
        if f.trivial then f.name:SetTextColor(0.78, 0.80, 0.83)
        elseif f.calm then f.name:SetTextColor(CREAM_NAME[1], CREAM_NAME[2], CREAM_NAME[3])
        else f.name:SetTextColor(C.tx[1], C.tx[2], C.tx[3]) end
    end

    local alpha = 1
    if not isTarget and UnitExists("target") then alpha = (tonumber(NPO("dim")) or 62) / 100 end
    if f.trivial then alpha = alpha * 0.68 end
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
        local name, text, icon, startMS, endMS, _, _, notInt = UnitCastingInfo(unit)
        local channel = false
        if not name then
            name, text, icon, startMS, endMS, _, notInt = UnitChannelInfo(unit)
            channel = true
        end
        if not name then StopCast(f) return end
        local cm = NPO("cast")
        if cm == "off" or (cm == "int" and notInt) then StopCast(f) return end

        local dur = endMS - startMS
        f.cast.bar:SetMinMaxValues(0, dur)
        if notInt then
            f.cast.fill:SetVertexColor(C.grey[1], C.grey[2], C.grey[3], 1)
            f.castTag:SetText("차단 불가"); f.castTag:SetTextColor(C.tx2[1], C.tx2[2], C.tx2[3])
        else
            f.cast.fill:SetVertexColor(1, 0.54, 0.44, 1)
            f.castTag:SetText("차단 가능"); f.castTag:SetTextColor(1, 0.70, 0.65)
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
    -- 이름표는 재활용돼요: 전에 우호 이름표(시체 줍기 등)로 쓰일 때 숨겨 둔 게 남아 있으면 풀기
    if af.leelHidden then HideFrame(af, false) end
    if af.DebuffListFrame and af.DebuffListFrame.leelHidden then HideFrame(af.DebuffListFrame, false) end
    pcall(af.SetAlpha, af, 1)
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
    if not NPO("deb") then HideFrame(list, true) end
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
        cb.Text:SetPoint("RIGHT", f.cast, "RIGHT", -64, 0)
    end
    cb.leelMoving = false
end

-- 게임 시전바 값 읽기 (전투 중 숨겨진 값이면 nil)
local function Plain(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
local function SyncCast(cb)
    local f = cb.leelOwner
    if not f then return end
    local on = cb:IsShown()
    f.cast:SetShown(on); f.castTag:SetShown(on)
    if on then
        f.cast:SetScript("OnUpdate", function()
            -- 채움: 게임 바 값을 그대로 (전투 중 숨겨진 값이어도 바에는 넘길 수 있어요)
            pcall(function()
                f.cast.bar:SetMinMaxValues(cb:GetMinMaxValues())
                f.cast.bar:SetValue(cb:GetValue())
            end)
            local kind = cb.leelKind or "int"
            local ok2, ni = pcall(function() return Plain(cb.notInterruptible) end)
            if ok2 and ni ~= nil then kind = ni and "no" or (kind == "stop" and "stop" or "int") end
            local c = CAST_COLOR[kind]
            f.cast.fill:SetVertexColor(c[1], c[2], c[3], 1)
            local cm = NPO("cast")
            local hide = cm == "off" or (cm == "int" and kind == "no")
            local a = hide and 0 or 1
            if f.castHidA ~= a then f.castHidA = a; f.cast:SetAlpha(a); f.castTag:SetAlpha(a); pcall(cb.SetAlpha, cb, a) end
            if kind == "no" then
                f.castTag:SetText("차단 불가"); f.castTag:SetTextColor(C.tx2[1], C.tx2[2], C.tx2[3])
            else
                f.castTag:SetText("차단 가능"); f.castTag:SetTextColor(1, 0.70, 0.65)
            end
        end)
    else
        f.cast:SetScript("OnUpdate", nil)
    end
    PlaceDebuffs(f)
end

local function StyleCast(cb)
    if cb.leelStyled then return end
    cb.leelStyled = true
    for _, k in ipairs({ "Background", "Border", "Spark", "BorderShield", "TextBorder",
                         "ImportantCastIndicator", "CastTargetIndicator", "CastTargetNameText", "Flash" }) do
        local r = cb[k]
        if r and r.SetAlpha then HideFrame(r, true) end
    end
    -- 게임 시전바의 그림(줄무늬 채움 · 빛 · 반짝이)은 모두 숨기고 글씨 · 아이콘만 남겨요.
    -- 채움은 우리 바가 게임 바의 값을 그대로 받아서 르엘 단색으로 그려요 (SyncCast).
    -- 게임이 넘기는 채움 그림 이름으로 상태를 알아요: 보통 · 집중 = 끊을 수 있음, uninterruptable = 못 끊음, interrupted = 끊김
    local function HideRest()
        for _, r in ipairs({ cb:GetRegions() }) do
            if r ~= cb.Text and r.SetAlpha then HideFrame(r, true) end
        end
        for _, c in ipairs({ cb:GetChildren() }) do HideFrame(c, true) end
        local fill = cb:GetStatusBarTexture()
        if fill then HideFrame(fill, true) end
    end
    HideRest()
    hooksecurefunc(cb, "SetStatusBarTexture", function(self, tex)
        local ok, kind = pcall(function()
            if type(tex) ~= "string" then return nil end
            local t = tex:lower()
            if t:find("uninterrupt") or t:find("shield") then return "no" end
            if t:find("interrupted") then return "stop" end
            return "int"
        end)
        if ok and kind then self.leelKind = kind end
        HideRest()
    end)
    if cb.Text then
        cb.Text:SetFont(ns.FONT, 13, "OUTLINE")
        cb.Text:SetShadowColor(0, 0, 0, 0.9)
        cb.Text:SetShadowOffset(1, -1)
        cb.Text:SetJustifyH("LEFT")
        cb.Text:SetWordWrap(false)
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
    f.cast.bar:Show()            -- 채움은 우리 바가 게임 바 값을 받아서 그려요
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
    if not (qt and qt.lookupByKey and Questie) then
        -- Questie 없음: 게임 툴팁 · 내가 잡아 본 몹 기억으로 (QuestMobs.lua)
        if ns.QuestMobInfo then return ns.QuestMobInfo(unit) end
        return
    end
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

    -- 우호 이름표로 쓰일 때 숨겨 둔 블리자드 조각(디버프 칸 포함)부터 되돌리기
    local uf0 = plate.UnitFrame
    if uf0 then
        for _, ch in ipairs({ uf0:GetChildren() }) do
            if ch.leelHidden then HideFrame(ch, false) end
        end
        for _, r in ipairs({ uf0:GetRegions() }) do
            if r.leelHidden then HideFrame(r, false) end
        end
    end
    local f = plate.leel or Build(plate)
    f.unit = unit
    f.dead = nil; f.reallyDead = nil
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
        if f.sword then f.sword:Off(); f.wasTarget = false end
        f:Hide()
        active[unit] = nil
    end
end

----------------------------------------------------------------------
-- 허브 미리 보기: 진짜 이름표와 같은 코드(Build)로 만든 모형 3개
--   내 대상(선공 정예 · 퀘스트 원 · 시전 · 내 디버프) / 비선공 / 낮은 몹
----------------------------------------------------------------------
function ns.NPPreview(parent)
    -- A: 작은 전투 장면 (풀밭 · 몹 실루엣 · 멀수록 작고 흐리게) · B: 상황 버튼 · D: 줄 올리면 그 부분 반짝
    local o = CreateFrame("Frame", nil, parent)
    o:SetSize(600, 170)
    -- 이름표 3개: 내 대상(앞) · 비선공(뒤) · 낮은 몹(더 뒤)
    local defs = {
        { key = "tgt",  lv = 36, name = "붉은갈기 노움", rank = "elite", pct = 62, x = -140, y = 24, depth = 1,    body = { 50, 34 }, by = -68 },
        { key = "calm", lv = 34, name = "바위 독수리", rank = "normal", pct = 100, x = 110, y = 40, depth = 0.86, body = { 40, 30 }, by = -20 },
        { key = "low",  lv = 22, name = "들쥐", rank = "trivial", pct = 18, x = 235, y = 52, depth = 0.72, body = { 24, 18 }, by = -16 },
    }
    o.plates = {}
    for _, d in ipairs(defs) do
        local fake = CreateFrame("Frame", nil, o)
        fake:SetSize(W + 30, 70)
        local f = Build(fake)
        f.def = d
        f.hp.bar:SetMinMaxValues(0, 100); f.hp.bar:SetValue(d.pct)
        f.pct:SetText(d.pct .. "%")
        f.name:SetText(d.name)
        -- 내 디버프 모형 (게임이 그리는 칸 대신 그림만)
        f.pvDeb = {}
        for i, tex in ipairs({ 135817, 136118, 132090 }) do
            local b = CreateFrame("Frame", nil, f.debRow); b:SetSize(DEB_SIZE, DEB_SIZE)
            b:SetPoint("LEFT", f.debRow, "LEFT", (i - 1) * (DEB_SIZE + 3), 0)
            local bk = b:CreateTexture(nil, "BACKGROUND"); bk:SetColorTexture(0, 0, 0, 0.9); bk:SetPoint("TOPLEFT", -1, 1); bk:SetPoint("BOTTOMRIGHT", 1, -1)
            local t = b:CreateTexture(nil, "ARTWORK"); t:SetAllPoints(); t:SetTexture(tex); t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local tm = ns.Num and ns.Num(b, 10, { 1, 1, 1 }) or b:CreateFontString(nil, "OVERLAY"); tm:SetPoint("BOTTOM", b, "BOTTOM", 0, -1); tm:SetText(({ "12", "5", "8" })[i])
            f.pvDeb[i] = b
        end
        o.plates[#o.plates + 1] = f
        f.fake = fake
    end
    o.state = "all"

    -- 내 창 미리 보기처럼: 이름표 하나만 가운데 크게 (비선공 · 낮은 몹은 안 보여요)
    function o:Arrange()
        self:SetSize(W + 70, 120)
        for i, f in ipairs(self.plates) do
            f.fake:ClearAllPoints(); f.fake:SetPoint("CENTER", self, "CENTER", 0, 14)
            f.fake:SetShown(i == 1)
        end
    end
    o:Arrange()

    function o:Apply()
        local st = self.temp or self.state or "all"
        for _, f in ipairs(self.plates) do
            local d = f.def
            local main = d.key == "tgt"
            local isT = main and (st == "all" or st == "cast" or st == "quest" or st == "exec")
            local pct = (main and st == "exec") and 18 or d.pct
            f.hp.bar:SetValue(pct)
            -- 등급 알약 · 레벨 색 (UpdateInfo와 같게)
            local R = RANK[d.rank] or {}
            if R.txt then
                for _, t in ipairs(f.headParts) do
                    if t.SetGradient and CreateColor then
                        t:SetVertexColor(1, 1, 1, 1)
                        t:SetGradient("VERTICAL", CreateColor(R.bot[1], R.bot[2], R.bot[3], 1), CreateColor(R.top[1], R.top[2], R.top[3], 1))
                    else t:SetVertexColor(R.top[1], R.top[2], R.top[3], 1) end
                    t:SetDesaturated(false)
                end
                f.headIcon:SetTexture(ns.MEDIA .. R.ic)
                f.headTxt:SetText(R.txt); f.headTxt:SetTextColor(R.ink[1], R.ink[2], R.ink[3], 1)
                f.head:SetWidth(math.max(15, (f.headTxt:GetStringWidth() or 20) + 9 + 2.5 + 12))
                f.head:Show(); f.head:SetAlpha(1)
                f.lv:ClearAllPoints(); f.lv:SetPoint("LEFT", f.head, "RIGHT", 5, 0)
            else
                f.head:Hide(); f.lv:ClearAllPoints(); f.lv:SetPoint("LEFT", f.title, "LEFT", 0, 0)
            end
            f.lv:SetText(d.lv)
            local getColor = GetCreatureDifficultyColor or GetQuestDifficultyColor
            local c = getColor and getColor(d.lv)
            if c then f.lv:SetTextColor(c.r, c.g, c.b) end
            f.trivial = d.key == "low"
            f.calm = (d.key == "calm" or (main and st == "calm")) and ns.db.npAggro ~= false
            f.tapped = nil
            f.sizeK = nil
            ns.SetTapped(f.hp, false); ns.SetStrike(f.name, false)
            PaintPlate(f)
            local th = NPO("exec")
            if th ~= "off" and pct <= ((th == "35") and 35 or 20) then ns.PaintFlat(f.hp, EXEC_COL) end
            if f.trivial then f.lv:SetTextColor(0.60, 0.63, 0.67) end
            -- 남의 몹: 회색 바 + 이름 줄 + 알약 흑백
            local tap = main and st == "tap" and NPO("tapped") ~= "keep"
            if tap then
                ns.SetTapped(f.hp, true); ns.SetStrike(f.name, true)
                f.name:SetTextColor(0.76, 0.73, 0.74); f.lv:SetTextColor(0.72, 0.69, 0.70)
                for _, t in ipairs(f.headParts) do t:SetDesaturated(true) end
                f.head:SetAlpha(0.7)
            end
            ApplyTitle(f)
            FitTitle(f)
            -- 체력 글씨
            local hm = NPO("hpTxt")
            local hpN = BreakUpLargeNumbers and BreakUpLargeNumbers(pct * 20) or tostring(pct * 20)
            if hm == "off" then f.pct:SetText("")
            elseif hm == "num" then f.pct:SetText(hpN)
            elseif hm == "both" then f.pct:SetText(hpN .. " · " .. pct .. "%")
            else f.pct:SetText(pct .. "%") end
            -- 징표 (앞 몹: 해골)
            if main then SetRaidTargetIconTexture(f.raid, 8); PlaceRaid(f); f.raid:Show() else f.raid:Hide() end
            -- 테두리 · 빛 · 표시
            f.glow:Hide()
            local aggro = main and st == "aggro" and NPO("aggro")
            if isT then
                f.hp.border:SetVertexColor(1, 0.561, 0.639, 1)
                f.glow:SetVertexColor(1, 0.561, 0.639, 0.6); f.glow:Show()
                if NPO("shine") then if not f.shine:IsShown() then f.shine.t = 0 end; f.shine:Show() else f.shine:Hide() end
                if not tap then f.name:SetTextColor(1, 1, 1) end
                if (ns.db.npMark or "aim") ~= "off" then
                    if f.sword.style ~= (ns.db.npMark or "aim") or f.sword.ms ~= (tonumber(ns.db.npMarkScale) or 100) / 100 or not f.sword:IsShown() then f.sword:Stab() end
                else f.sword:Off() end
            else
                if aggro then
                    f.hp.border:SetVertexColor(C.dmg[1], C.dmg[2], C.dmg[3], 1)
                    f.glow:SetVertexColor(C.dmg[1], C.dmg[2], C.dmg[3], 0.45); f.glow:Show()
                else
                    f.hp.border:SetVertexColor(C.edge[1], C.edge[2], C.edge[3], C.edge[4])
                end
                f.shine:Hide(); f.sword:Off()
            end
            -- 퀘스트 원
            local q = f.quest
            if main and (st == "all" or st == "quest") and ns.db.questCircle ~= false then
                q.fill:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
                q.icon:SetTexture(ns.MEDIA .. "q_slay")
                q.tagBg:SetColor(C.accHi); q.count:SetTextColor(C.ink[1], C.ink[2], C.ink[3])
                q.count:SetText("3/8"); q.tag:SetWidth(q.count:GetStringWidth() + 9); q.tag:Show()
                q.badge:Hide(); q:Show()
            else q:Hide() end
            PlacePct(f)
            -- 시전바
            if main and (st == "all" or st == "cast") and NPO("cast") ~= "off" then
                f.cast.bar:SetMinMaxValues(0, 1); f.cast.bar:SetValue(0.55)
                f.cast.fill:SetVertexColor(1, 0.54, 0.44, 1)
                f.castName:SetText("화염 화살"); f.castName:SetTextColor(1, 0.70, 0.65)
                f.castTag:SetText("차단 가능"); f.castTag:SetTextColor(1, 0.70, 0.65)
                f.cast:SetAlpha(1); f.cast:Show(); f.castName:Show(); f.castTag:Show()
            else
                f.cast:Hide(); f.castName:Hide(); f.castTag:Hide()
            end
            for _, b in ipairs(f.pvDeb) do b:SetShown(main and (st == "all" or st == "cast") and NPO("deb") and true or false) end
            -- 연계 점수 구슬 (도적 · 드루면 늘, 아니면 그 줄에 마우스를 올릴 때만)
            local comboOn = main and NPO("combo") and (st == "combo" or (st == "all" and ns.UsesCombo and ns.UsesCombo()))
            if comboOn then pcall(f.combo.SetCount, f.combo, 3); f.combo:Show() else f.combo:Hide() end
            PlaceDebuffs(f)
            -- 대상이 있으면 나머지는 흐리게 · 낮은 몹은 더 흐리게 · 멀수록 작게
            local a = (main and st == "others") and (tonumber(NPO("dim")) or 62) / 100 or 1
            if f.trivial then a = a * 0.68 end
            f:SetAlpha(a)
            f:SetScale((ns.db.npScale or 1) * (isT and 1.08 or 1) * ((R.small) and 0.82 or 1))
        end
    end

    -- 줄에 마우스: 상황이 필요한 줄은 그 모습으로 잠깐 (시전 · 퀘스트 · 남의 몹 · 처형 · 공격 · 비선공 · 흐리게)
    local STATE_OF = { cast = "cast", quest = "quest", tap = "tap", exec = "exec", aggro = "aggro", calm = "calm", others = "others", combo = "combo" }
    function o:Temp(key)
        local want = key and STATE_OF[key] or nil
        if self.temp ~= want then self.temp = want; self:Apply() end
    end
    -- 강조할 부분 (허브가 그 둘레를 밝게)
    function o:Elem(key)
        local f = self.plates[1]
        if key == "bar" or key == "exec" or key == "aggro" or key == "tap" or key == "calm" then return f.hp
        elseif key == "pct" then return f.pct
        elseif key == "lv" or key == "name" then return f.title
        elseif key == "mark" then return (f.sword:IsShown() and f.sword) or f.title
        elseif key == "cast" then return f.cast, f.castName
        elseif key == "deb" then return f.debRow
        elseif key == "combo" then return f.combo
        elseif key == "quest" then return f.quest
        elseif key == "raid" then return f.raid
        end
        return f.hp, f.debRow:IsShown() and f.debRow or f.hp
    end
    o:Apply()
    ns.npPv = o
    return o
end

function ns.SetNPOpt(k, v)
    ns.db.npO = ns.db.npO or {}
    ns.db.npO[k] = v
    for u, f in pairs(active) do
        f.execOn = nil; f.sizeK = nil
        if k == "tapped" then f.tapped = nil end
        UpdateInfo(f, u); UpdateHealth(f, u); UpdateBorder(f, u); UpdateRaid(f, u)
        pcall(UpdateCombo, f, u)
        if f.auras then
            local list = f.auras.DebuffListFrame or f.auras
            HideFrame(list, not NPO("deb"))
        end
        f.castHidA = nil
        PlaceDebuffs(f)
    end
end

-- 허브 스위치: 선공/비선공 구별 다시 그리기
function ns:RefreshPlateInfo()
    for u, f in pairs(active) do UpdateInfo(f, u); UpdateBorder(f, u) end
end

function ns:RefreshDeadPlates()
    for u, f in pairs(active) do
        f.dead = nil; f.reallyDead = nil
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
    ns.NPMarkScanOnly = function() if ns.MarkOrderScan then ns.MarkOrderScan(active) end end
    ns.NPMarkRescan = function()
        for u, f in pairs(active) do UpdateRaid(f, u) end
        if ns.MarkOrderScan then ns.MarkOrderScan(active) end
    end
    ev:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            OnAdded(unit)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            OnRemoved(unit)
            if ns.MarkOrderScan then C_Timer.After(0, function() ns.MarkOrderScan(active) end) end
        elseif event == "PLAYER_SOFT_INTERACT_CHANGED" then
            for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
                local u = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
                if u and not Try(UnitCanAttack, "player", u) then SetFriendlyBars(plate, FriendlyForced(u)) end
            end
        elseif event == "RAID_TARGET_UPDATE" then
            ns.NPMarkRescan()
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

-- /르엘디버프 : 내 대상 이름표의 디버프 칸 상태 점검
SLASH_LEELNPDEB1 = "/르엘디버프"
SlashCmdList.LEELNPDEB = function()
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    if not plate then print(ns.L("|cffff8fab르엘|r 대상 이름표가 없어요 (적을 고르고 다시)")) return end
    local uf = plate.UnitFrame
    local af = uf and uf.AurasFrame
    if not af then print(ns.L("|cffff8fab르엘|r 디버프 칸(AurasFrame)이 없어요")) return end
    local list = af.DebuffListFrame or af
    local n, shown = 0, 0
    for _, it in ipairs({ list:GetChildren() }) do n = n + 1; if it:IsShown() then shown = shown + 1 end end
    print(ns.L("|cffff8fab르엘|r 디버프 칸: 보임=%s 투명도=%.2f 숨김표시=%s · 목록 보임=%s 투명도=%.2f · 아이콘 %d개(보임 %d) · CVar=%s"):format(
        tostring(af:IsShown()), af:GetAlpha() or -1, tostring(af.leelHidden), tostring(list:IsShown()), list:GetAlpha() or -1, n, shown,
        tostring(GetCVar("nameplateShowDebuffs"))))
end

----------------------------------------------------------------------
-- Leel Mark 약속표 → 이름표: 징 옆 "잡는 순서" 숫자 · CC 징 = 자물쇠 + 남은 시간 · 앞 순서가 사라지면 다음 몹 "다음!"
--   (르엘 이름표에서만 · Leel Mark 가 없으면 해골 1 · X 2 만)
----------------------------------------------------------------------
do
    local CC_SPELLS = { 118, 12824, 12825, 12826, 28271, 28272, 3355, 14308, 14309, 6770, 2070, 11297, 9484, 9485, 10955, 2637, 18657, 18658 }
    local ccNames
    local function CCNames()
        if ccNames then return ccNames end
        ccNames = {}
        for _, id in ipairs(CC_SPELLS) do
            local ok, n = pcall(function() return (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or (GetSpellInfo and GetSpellInfo(id)) end)
            if ok and type(n) == "string" then ccNames[n] = true end
        end
        return ccNames
    end
    local function PlanOf()
        local api = _G.LeelMarkAPI
        if api then
            if api.OrderOn and not api.OrderOn() then return nil end
            local ok, p = pcall(api.Plan)
            if ok and p then return p end
        end
        return { [8] = { kind = "kill", n = 1 }, [7] = { kind = "kill", n = 2 } }
    end
    local function Badge(f)
        if f.ordB then return f.ordB end
        local b = CreateFrame("Frame", nil, f); b:SetSize(15, 15); b:SetFrameLevel(f:GetFrameLevel() + 6)
        local r = b:CreateTexture(nil, "ARTWORK"); r:SetTexture(ns.MEDIA .. "circle"); r:SetPoint("CENTER"); r:SetSize(18, 18); r:SetVertexColor(0.1, 0.07, 0.065)
        local d = b:CreateTexture(nil, "ARTWORK", nil, 1); d:SetTexture(ns.MEDIA .. "circle"); d:SetAllPoints(); d:SetVertexColor(C.acc[1], C.acc[2], C.acc[3])
        b.fs = b:CreateFontString(nil, "OVERLAY"); b.fs:SetFont(ns.NUM or ns.FONT, 10.5, ""); b.fs:SetPoint("CENTER", 0, 0); b.fs:SetTextColor(C.ink[1], C.ink[2], C.ink[3])
        f.ordB = b
        -- 다음! 꼬리표 + 징 둘레 빛
        local n = CreateFrame("Frame", nil, f); n:SetSize(40, 18); n:SetFrameLevel(f:GetFrameLevel() + 6)
        n.bg = ns.RoundRect(n, 9, C.acc, "BACKGROUND", 0, 0); n.bg:SetColor(C.acc, 1)
        n.fs = ns.Font(n, 11.5, C.ink); n.fs:SetShadowColor(0, 0, 0, 0); n.fs:SetPoint("CENTER", 0, 0); n.fs:SetText("다음!")
        n:SetWidth(n.fs:GetStringWidth() + 16)
        n.glow = f:CreateTexture(nil, "OVERLAY", nil, 6); n.glow:SetTexture(ns.MEDIA .. "soft_glow"); n.glow:SetBlendMode("ADD")
        n.glow:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
        n:Hide(); n.glow:Hide()
        f.nextT = n
        -- 자물쇠 줄 (CC 징)
        local l = CreateFrame("Frame", nil, f); l:SetHeight(16); l:SetFrameLevel(f:GetFrameLevel() + 6)
        l.bg = ns.RoundRect(l, 8, { 0.11, 0.08, 0.075 }, "BACKGROUND", 0, 0); l.bg:SetColor({ 0.11, 0.08, 0.075 }, 0.92)
        l.ic = l:CreateTexture(nil, "ARTWORK"); l.ic:SetTexture(ns.MEDIA .. "ic_lock"); l.ic:SetSize(10, 10); l.ic:SetPoint("LEFT", 6, 0)
        l.ic:SetVertexColor(0.74, 0.82, 0.92)
        l.fs = ns.Font(l, 10, { 0.74, 0.82, 0.92 }); l.fs:SetPoint("LEFT", l.ic, "RIGHT", 4, 0)
        l:Hide()
        f.lockT = l
        return b
    end
    local function CCLeft(unit)
        local names = CCNames()
        local left
        pcall(function()
            for i = 1, 40 do
                local name, exp
                if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                    local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL")
                    if not a then break end
                    name, exp = a.name, a.expirationTime
                else
                    local n, _, _, _, _, e = UnitAura(unit, i, "HARMFUL")
                    if not n then break end
                    name, exp = n, e
                end
                if issecretvalue and (issecretvalue(name) or issecretvalue(exp)) then break end
                if name and names[name] then
                    left = (exp and exp > 0) and math.max(0, exp - GetTime()) or -1
                    break
                end
            end
        end)
        return left
    end
    local lockTick = CreateFrame("Frame")
    local locked = {}
    local function PaintLock(f, unit, p)
        local l = f.lockT
        local left = CCLeft(unit)
        local t = (p.who and p.who ~= "" and (p.who .. " ") or "") .. p.role
        if left and left >= 0 then t = t .. " 중 · " .. math.ceil(left) .. "초" elseif left then t = t .. " 중" end
        l.fs:SetText(t .. " · 건드리지 마요")
        l:SetWidth(6 + 10 + 4 + l.fs:GetStringWidth() + 8)
        l:ClearAllPoints(); l:SetPoint("TOP", f.hp, "BOTTOM", 0, -3)
        l:Show()
    end
    lockTick:SetScript("OnUpdate", function(self, e)
        self.t = (self.t or 0) + e
        if self.t < 0.25 then return end
        self.t = 0
        for f, d in pairs(locked) do
            if f.lockT:IsShown() and f.unit == d.unit then PaintLock(f, d.unit, d.p) else locked[f] = nil end
        end
    end)

    -- A안: "지금 칠 몹" = 남은 잡는 순서 중 가장 앞 징이 2배로 커지고 금색 고리가 맥박 · 나머지 징은 작고 흐리게 (글씨 없이)
    --   던전 · 전투 중엔 게임이 징 번호를 숨겨요 → Leel Mark 가 찍은 기억(몹 GUID)으로 대신 · 그림은 게임 징 칸을 빌려 와서
    local function MarkOf(unit)
        local api = _G.LeelMarkAPI
        if not (api and api.MarkOf) then return end
        local ok, g = pcall(UnitGUID, unit)
        if ok and type(g) == "string" and not (issecretvalue and issecretvalue(g)) then
            local m = api.MarkOf(g)
            if m then return m end
        end
        if api.MarkOfPlate then return api.MarkOfPlate(unit) end
    end
    ns.MarkMemory = MarkOf
    local function Icon(f)   -- 지금 보이는 징 그림 (게임 칸을 빌려 왔으면 그것)
        if f.raid:IsShown() then return f.raid end
        local plate = f:GetParent()
        local uf = plate and plate.UnitFrame
        local rf = uf and (uf.RaidTargetFrame or uf.raidTargetFrame)
        if rf and rf.leelOn then return rf, true end
    end
    local function Ring(f)
        if f.curRing then return f.curRing end
        local r = CreateFrame("Frame", nil, f); r:SetSize(54, 54); r:SetFrameLevel(f:GetFrameLevel() + 5)
        r.glow = r:CreateTexture(nil, "BACKGROUND"); r.glow:SetTexture(ns.MEDIA .. "soft_glow"); r.glow:SetBlendMode("ADD")
        r.glow:SetPoint("CENTER"); r.glow:SetSize(76, 76); r.glow:SetVertexColor(1, 0.80, 0.35, 1)
        r.ring = r:CreateTexture(nil, "ARTWORK"); r.ring:SetTexture(ns.MEDIA .. "ring"); r.ring:SetAllPoints(); r.ring:SetVertexColor(1, 0.82, 0.38, 1)
        local ag = r:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
        local sc = ag:CreateAnimation("Scale"); sc:SetDuration(0.55); sc:SetSmoothing("IN_OUT")
        if sc.SetScaleFrom then sc:SetScaleFrom(0.92, 0.92); sc:SetScaleTo(1.1, 1.1) else sc:SetFromScale(0.92, 0.92); sc:SetToScale(1.1, 1.1) end
        local al = ag:CreateAnimation("Alpha"); al:SetFromAlpha(0.55); al:SetToAlpha(1); al:SetDuration(0.55); al:SetSmoothing("IN_OUT")
        r:SetScript("OnShow", function() ag:Play() end); r:SetScript("OnHide", function() ag:Stop() end)
        r:Hide()
        f.curRing = r
        return r
    end
    local BASE = 24
    local function Big(f, mode)   -- mode: "cur" | "dim" | nil(보통)
        local ic, blz = Icon(f)
        local sz = (mode == "cur" and BASE * 2) or (mode == "dim" and BASE * 0.75) or BASE
        local al = (mode == "dim") and 0.55 or 1
        if not blz then f.raid:SetSize(sz, sz); f.raid:SetAlpha(al) end   -- 게임 징 칸(빌려 온 것)은 크기를 안 건드려요 (전투 중 막힘) · 고리만
        local r = f.curRing
        if mode == "cur" and ic then
            r = Ring(f)
            r:ClearAllPoints(); r:SetPoint("CENTER", f.raid, "CENTER", 0, 0)
            local rs = blz and (BASE + 12) or (sz + 14)   -- 게임 징 칸을 빌려 쓰면 징은 그대로 크기라 고리를 딱 맞게
            r:SetSize(rs, rs)
            r.glow:SetSize(rs * 1.4, rs * 1.4)
            r:Show()
        elseif r then r:Hide() end
        f.markMode = mode
    end

    local scanPend = false
    function ns.MarkOrderPaint(f, unit, idx, hidden)
        if not scanPend then   -- 새 이름표 · 징이 바뀌면 한 번 모아서 "지금 칠 몹" 다시 고르기
            scanPend = true
            C_Timer.After(0.05, function() scanPend = false; if ns.NPMarkScanOnly then ns.NPMarkScanOnly() end end)
        end
        if not idx and hidden then idx = MarkOf(unit) end   -- 게임이 징 번호를 숨길 때만 기억으로 (지워진 징을 다시 살리지 않게)
        local plan = idx and PlanOf()
        local p = plan and plan[idx]
        if f.ordB then f.ordB:Hide(); f.lockT:Hide(); locked[f] = nil end
        f.unit = unit
        f.markIdx = idx; f.markN = p and p.kind == "kill" and p.n or nil
        if not p or not Icon(f) then f.markN = nil; if f.markMode then Big(f, nil) end return end
        if p.kind ~= "kill" then
            Badge(f)
            locked[f] = { unit = unit, p = p }
            PaintLock(f, unit, p)
        end
    end

    local lastCur, lastCurN
    local function NowTag(f)
        local t = f.nowT
        if not t then
            t = CreateFrame("Frame", nil, f); t:SetSize(40, 18); t:SetFrameLevel(f:GetFrameLevel() + 8)
            t.bg = ns.RoundRect(t, 9, { 1, 0.82, 0.35 }, "BACKGROUND", 0, 0); t.bg:SetColor({ 1, 0.82, 0.35 }, 1)
            t.fs = ns.Font(t, 12, { 0.23, 0.16, 0.06 }); t.fs:SetShadowColor(0, 0, 0, 0); t.fs:SetPoint("CENTER", 0, 0); t.fs:SetText(ns.L("지금!"))
            t:SetWidth(t.fs:GetStringWidth() + 16)
            t.glow = f:CreateTexture(nil, "OVERLAY", nil, 6); t.glow:SetTexture(ns.MEDIA .. "soft_glow"); t.glow:SetBlendMode("ADD")
            t.glow:SetVertexColor(1, 0.80, 0.35, 1)
            f.nowT = t
        end
        t:ClearAllPoints(); t:SetPoint("BOTTOM", f.raid, "TOP", 0, 2)
        t.glow:ClearAllPoints(); t.glow:SetPoint("CENTER", f.raid); t.glow:SetSize(110, 110)
        t:Show(); t.glow:Show(); t:SetAlpha(1); t.glow:SetAlpha(1)
        local el = 0
        t:SetScript("OnUpdate", function(self, e)
            el = el + e
            local pulse = 0.5 + 0.5 * math.abs(math.sin(el * 7))
            self.glow:SetAlpha(el < 1.2 and pulse or math.max(0, 1 - (el - 1.2) / 0.6))
            if el > 1.7 then self:SetAlpha(math.max(0, 1 - (el - 1.7) / 0.3)) end
            if el > 2 then self:Hide(); self.glow:Hide(); self:SetScript("OnUpdate", nil) end
        end)
    end
    -- 남은 것 중 가장 앞 순서 = 지금 칠 몹 (죽어서 징이 사라지면 저절로 다음 몹으로)
    function ns.MarkOrderScan(act)
        local minN, minF
        for u, f in pairs(act) do
            local dead = f.reallyDead or f.dead
            if not dead then pcall(function() local d = UnitIsDead(u); if not (issecretvalue and issecretvalue(d)) then dead = d and true or false end end) end
            if dead then f.markN = nil end
            if f.markN then
                if not minN or f.markN < minN then minN, minF = f.markN, f end
            end
        end
        for _, f in pairs(act) do
            if f.markN then Big(f, f == minF and "cur" or "dim")
            elseif f.markMode then Big(f, nil) end
        end
        -- E안: 앞 몹이 죽어 다음 몹으로 넘어가는 순간 2초 "지금!" + 반짝
        if minF and lastCur and lastCur ~= minF and (not lastCurN or (minN or 0) > lastCurN) then NowTag(minF) end
        lastCur, lastCurN = minF, minN
        ns.MarkCurrent = minF and { idx = minF.markIdx, n = minN } or nil   -- Leel Mark 바가 금테로 같이 보여줘요
    end
    function ns.MarkRefresh()
        if ns.NPMarkRescan then ns.NPMarkRescan() end
    end
end

-- 점검: /르엘징 → 보이는 적 이름표마다 징 · 잡는 순서 · "지금 칠 몹" 표시 상태
SLASH_LEELNPMARK1 = "/르엘징"
SlashCmdList.LEELNPMARK = function()
    local P = function(m) print("|cfff2b3c2[르엘 징]|r " .. m) end
    local api = _G.LeelMarkAPI
    P("Leel Mark: " .. (api and "있음" or "없음") .. " · 순서 표시: " .. tostring(not (api and api.OrderOn and not api.OrderOn())))
    local n = 0
    for u, f in pairs(active) do
        n = n + 1
        local ok, i = pcall(GetRaidTargetIndex, u)
        local rd = (not ok) and "오류" or (i == nil and "없음") or ((issecretvalue and issecretvalue(i)) and "숨김") or tostring(i)
        local okG, g = pcall(UnitGUID, u)
        local gs = (not okG or g == nil) and "없음" or ((issecretvalue and issecretvalue(g)) and "숨김" or "읽음")
        local mem = (api and api.MarkOf and okG and type(g) == "string" and not (issecretvalue and issecretvalue(g))) and api.MarkOf(g) or nil
        mem = mem or (api and api.MarkOfPlate and api.MarkOfPlate(u))
        local nm = ""; pcall(function() local x = UnitName(u); if not (issecretvalue and issecretvalue(x)) then nm = x or "" end end)
        P(("%s %s · 징 %s · 기억 %s · GUID %s · 순서 %s · 표시 %s · 죽음 %s · 보임 %s"):format(u, nm, rd, tostring(mem), gs,
            tostring(f.markN), tostring(f.markMode), tostring(f.reallyDead), tostring(f:IsVisible())))
    end
    if n == 0 then P("르엘 이름표가 하나도 없어요 (르엘 이름표가 켜져 있어야 해요)") end
end
