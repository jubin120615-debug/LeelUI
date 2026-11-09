-- LeelUI / Auras.lua
-- 대상 HUD의 내 디버프: 블리자드 CustomAuraContainer(애드온용 공식 오라 표시) 사용
-- WoW Forever는 애드온이 오라 정보를 직접 못 읽음 → 게임이 채워 주는 버튼에 모양만 입힘
-- 모양: 동그란 아이콘 + 분홍 진행 링(남은 시간만큼) + 가운데 숫자 + 오른쪽 위 중첩

local _, ns = ...
local C = ns.C

local SIZE, GAP, MAX = 36, 6, 6   -- HUD 60%에서 화면상 약 22px

-- 남은 시간 표시 규칙 (게임 공식 숫자 서식기): 단위 글자 없이 숫자만
local durFmt
local function DurationFormatter()
    if durFmt ~= nil then return durFmt or nil end
    durFmt = false
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    local ok, f = pcall(function()
        local R = Enum.NumericRuleFormatRounding
        local fm = C_StringUtil.CreateNumericRuleFormatter()
        fm:SetBreakpoints({
            { threshold = 0,  format = "%d",  step = 1, rounding = R.Up },
            { threshold = 60, format = "%dm", components = { { div = 60, step = 1, rounding = R.Up } } },
        })
        return fm
    end)
    if ok and f then durFmt = f end
    return durFmt or nil
end

-- 버튼 하나 꾸미기 (게임이 버튼을 만들 때 한 번 불러 줌)
-- opt: size, ring(진행 링 색), num(남은 시간 글자 크기)
local function MakeInit(opt)
  return function(btn)
    local SIZE = opt.size
    btn:SetSize(SIZE, SIZE)

    local black = btn:CreateTexture(nil, "BACKGROUND", nil, -8)
    black:SetTexture(ns.MEDIA .. "circle")
    black:SetVertexColor(0, 0, 0, 0.95)
    black:SetPoint("TOPLEFT", -1, 1); black:SetPoint("BOTTOMRIGHT", 1, -1)

    local track = btn:CreateTexture(nil, "BACKGROUND", nil, -7)
    track:SetTexture(ns.MEDIA .. "ring")
    track:SetVertexColor(C.plate[1], C.plate[2], C.plate[3], 1)
    track:SetAllPoints()

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 4, -4); icon:SetPoint("BOTTOMRIGHT", -4, 4)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mask = btn:CreateMaskTexture()
    mask:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
    btn:SetIcon(icon)

    -- 남은 시간 = 분홍 링이 줄어듦
    local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cd:SetAllPoints()
    cd:SetSwipeTexture(ns.MEDIA .. "ring")
    cd:SetSwipeColor(opt.ring[1], opt.ring[2], opt.ring[3], 1)
    cd:SetReverse(true)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
    btn:SetDurationCooldown(cd)

    -- 가운데 남은 시간 숫자
    local over = CreateFrame("Frame", nil, btn)
    over:SetAllPoints()
    over:SetFrameLevel(cd:GetFrameLevel() + 2)
    local time = over:CreateFontString(nil, "OVERLAY")
    -- 숫자만 (단위 "초" 없이): 60초 미만은 "36", 그 이상은 "2m"
    local fmt = DurationFormatter()
    if fmt then
        time:SetFont(ns.NUM, opt.num, "OUTLINE")
        if not pcall(btn.SetDurationText, btn, time, { textFormatter = fmt }) then
            time:SetFont(ns.FONT, 12, "OUTLINE")
            pcall(btn.SetDurationText, btn, time)
        end
    else
        -- 숫자만 쓰는 기능이 없으면 게임 기본 표시("36초") + 한글 되는 글꼴
        time:SetFont(ns.FONT, 12, "OUTLINE")
        pcall(btn.SetDurationText, btn, time)
    end
    time:SetPoint("CENTER", 0, 0)

    -- 오른쪽 위 중첩 숫자
    local count = over:CreateFontString(nil, "OVERLAY")
    count:SetFont(ns.NUM, opt.num - 3, "OUTLINE")
    count:SetTextColor(C.accHi[1], C.accHi[2], C.accHi[3])
    count:SetPoint("TOPRIGHT", 4, 4)
    pcall(btn.SetApplicationCount, btn, count)
  end
end
local InitDebuff = MakeInit({ size = SIZE, ring = C.acc, num = 16 })
local BSIZE, BMAX = 28, 8
local InitBuff = MakeInit({ size = BSIZE, ring = { 0.62, 0.90, 0.76 }, num = 13 })   -- 버프: 민트 링, 조금 작게

function ns.CreateTargetDebuffs(f)
    local ok, cont = pcall(CreateFrame, "AuraContainer", nil, f, "CustomAuraContainerTemplate")
    if not ok or not cont then
        ns.debuffNote = "이 게임 버전엔 애드온용 오라 표시가 없어서 대상 디버프를 못 띄워요."
        return
    end

    local ok2, err = pcall(function()
        cont:SetPoint("TOPRIGHT", f.hp, "BOTTOMRIGHT", -28, -6)   -- 초상화 쪽(오른쪽)부터, 초상화와 띄워서
        if cont.SetFlowLayoutAnchorPoint then cont:SetFlowLayoutAnchorPoint("TOPRIGHT") end
        if cont.SetFlowLayoutGrowthDirection and AnchorUtil and AnchorUtil.FlowDirection then
            cont:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Down)
        end
        cont:AddAuraGroup("leelMine", "HARMFUL|PLAYER", {
            maxFrameCount = MAX,
            sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.Expiration or 0,
            sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal or 0,
            initializeFrame = InitDebuff,
            layout = { elementSpacing = GAP, elementWidth = SIZE, elementHeight = SIZE },
        })
        cont:SetUnit("target")
    end)
    if not ok2 then
        ns.debuffNote = "대상 디버프 설정 실패: " .. tostring(err)
        return
    end
    f.debuffs = cont

    -- 버프 줄: 디버프 줄 바로 아래, 오른쪽부터 (아군이면 내가 줄 버프 확인, 적이면 해제할 버프 확인)
    local ok3, bc = pcall(CreateFrame, "AuraContainer", nil, f, "CustomAuraContainerTemplate")
    if ok3 and bc then
        local ok4 = pcall(function()
            -- 오라 컨테이너에는 다른 프레임을 붙일 수 없음(게임 제한) → 체력바 기준으로 디버프 한 줄 아래
            bc:SetPoint("TOPRIGHT", f.hp, "BOTTOMRIGHT", -28, -6 - SIZE - 6)
            if bc.SetFlowLayoutAnchorPoint then bc:SetFlowLayoutAnchorPoint("TOPRIGHT") end
            if bc.SetFlowLayoutGrowthDirection and AnchorUtil and AnchorUtil.FlowDirection then
                bc:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Down)
            end
            bc:AddAuraGroup("leelBuffs", "HELPFUL", {
                maxFrameCount = BMAX,
                sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.Expiration or 0,
                sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal or 0,
                initializeFrame = InitBuff,
                layout = { elementSpacing = 5, elementWidth = BSIZE, elementHeight = BSIZE },
            })
            bc:SetUnit("target")
        end)
        if ok4 then f.buffs = bc else ns.debuffNote = "대상 버프 줄 설정 실패" end
    end

    -- 대상이 바뀌면 새로 채우기
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    ev:SetScript("OnEvent", function()
        pcall(cont.UpdateAllAuras, cont)
        if f.buffs then pcall(f.buffs.UpdateAllAuras, f.buffs) end
    end)
end
