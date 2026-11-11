-- LeelUI / Core.lua
-- 설정 저장, 공용 유틸, 슬래시 명령어

local ADDON, ns = ...
_G.LeelUI = ns

ns.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"
ns.FONT  = STANDARD_TEXT_FONT or "Fonts\\2002.TTF"
ns.WHITE = "Interface\\Buttons\\WHITE8X8"
ns.NUM   = ns.MEDIA .. "BarlowCondensed-ExtraBoldItalic.ttf"
ns.NUM_B = ns.MEDIA .. "BarlowCondensed-BoldItalic.ttf"

ns.defaults = {
    -- 처음 설치 기본값 = 슈엘 화면 (캐릭터 바로 아래 가운데, HUD 61%, 이름표 75%)
    point = { "CENTER", "CENTER", 0, -302 },
    scale = 0.61,
    npScale = 0.75,
    questCircle = true,
    hideBlizzard = true,
    nameplates = true,
    minimap = { hide = false, minimapPos = 225, lock = false },
    grid = true,
    party = true,
    partyHideBlizzard = true,
    partyScale = 0.75,
    partyLayout = "row",
    partyPoint = { "TOP", "TOP", 0, -250 },
    castStyle = "bunny",   -- bunny 깡충 토끼 / paw 발자국 / hud 예전 얇은 바
}

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd21f[르엘UI]|r " .. msg)
end
ns.Print = Print

----------------------------------------------------------------------
-- 비밀 값(secret value) 안전 처리
-- WoW Forever는 전투 중 일부 값을 애드온에게 숨김.
-- 화면에 넘기는 건 되지만 계산/비교는 안 되므로 전부 pcall로 감싼다.
----------------------------------------------------------------------
function ns.IsSecret(v)
    if issecretvalue then
        local ok, res = pcall(issecretvalue, v)
        return ok and res or false
    end
    return false
end

-- 숨겨진 값 때문에 에러가 나도 false로 처리
function ns.Try(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then return false end
    local ok2, b = pcall(function() return res and true or false end)
    return ok2 and b or false
end

function ns.SetBar(bar, cur, max)
    pcall(bar.SetMinMaxValues, bar, 0, max or 1)
    pcall(bar.SetValue, bar, cur or 0)
end

function ns.SetText(fs, v)
    if v == nil then fs:SetText("") return end
    if not pcall(fs.SetText, fs, v) then fs:SetText("") end
end

-- 체력 %: 계산 가능하면 직접, 숨겨진 값이면 게임 API에 맡기고, 그것도 안 되면 비움
function ns.HealthPercentText(fs, unit, cur, max)
    if not ns.IsSecret(cur) and not ns.IsSecret(max) then
        if max and max > 0 then
            fs:SetFormattedText("%d%%", math.floor(cur / max * 100 + 0.5))
        else
            fs:SetText("")
        end
        return
    end
    if UnitHealthPercent then
        local ok = pcall(function()
            local scale = CurveConstants and CurveConstants.ScaleTo100
            local pct = UnitHealthPercent(unit, true, scale)
            fs:SetFormattedText("%.0f%%", pct)
        end)
        if ok then return end
    end
    fs:SetText("")
end

----------------------------------------------------------------------
-- 전투 중에는 보호 프레임을 못 건드리므로, 전투가 끝나면 실행
----------------------------------------------------------------------
local queue = {}
function ns:RunOutOfCombat(key, fn)
    if InCombatLockdown() then
        queue[key] = fn
    else
        fn()
    end
end
local qf = CreateFrame("Frame")
qf:RegisterEvent("PLAYER_REGEN_ENABLED")
qf:SetScript("OnEvent", function()
    for k, fn in pairs(queue) do
        queue[k] = nil
        pcall(fn)
    end
end)

----------------------------------------------------------------------
-- 기본 블리자드 프레임 숨기기
----------------------------------------------------------------------
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

-- 대상 창은 시전바(TargetFrame.spellbar)를 빌려 써야 해서 지우지 않고
-- 투명 + 마우스 끔 + 화면 밖으로만 옮김 (게임이 대상 바뀔 때 보이기/숨기기를 해야 시전바가 살아 있음)
local function ParkTargetFrame()
    local tf = TargetFrame
    if not tf or InCombatLockdown() or tf.leelParking then return end
    tf.leelParking = true
    tf:SetClampedToScreen(false)
    tf:ClearAllPoints()
    tf:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -400, 400)
    tf.leelParking = false
end

function ns:HideBlizzard()
    if InCombatLockdown() then return end
    for _, fr in ipairs({ PlayerFrame, ComboFrame, PetFrame }) do
        if fr then
            fr:UnregisterAllEvents()
            fr:Hide()
            fr:SetParent(hiddenParent)
        end
    end
    local tf = TargetFrame
    if tf and not tf.leelParked then
        tf.leelParked = true
        tf:SetAlpha(0)
        hooksecurefunc(tf, "SetAlpha", function(self, a) if a and a > 0 then self:SetAlpha(0) end end)
        pcall(tf.EnableMouse, tf, false)
        local tot = tf.totFrame or _G.TargetFrameToT
        if tot then pcall(tot.EnableMouse, tot, false) end
        hooksecurefunc(tf, "SetPoint", function() if not tf.leelParking then ParkTargetFrame() end end)
        ParkTargetFrame()
    end
end

----------------------------------------------------------------------
-- 로딩
----------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        -- 처음 설치면 예전 버전 옮기기(v2~v5 크기 조정)를 건너뛰고 기본값 그대로
        if not LeelUIDB or next(LeelUIDB) == nil then LeelUIDB = { v = 5 }; ns.freshInstall = true end
        for k, v in pairs(ns.defaults) do
            if LeelUIDB[k] == nil then
                LeelUIDB[k] = type(v) == "table" and CopyTable(v) or v
            end
        end
        -- v2: 기본 크기 축소 (기존 사용자도 한 번 적용)
        if (LeelUIDB.v or 1) < 2 then
            LeelUIDB.scale = 0.7
            LeelUIDB.v = 2
        end
        -- v3: 리뉴얼로 이름표가 얇아져서 기본 크기 0.9
        if LeelUIDB.v < 3 then
            LeelUIDB.npScale = 0.9
            LeelUIDB.v = 3
        end
        -- v4: 미니맵 설정을 LibDBIcon 형식으로 옮김
        if LeelUIDB.minimapPos or LeelUIDB.minimapHide ~= nil or LeelUIDB.minimapLock ~= nil then
            LeelUIDB.minimap.minimapPos = LeelUIDB.minimapPos or 225
            LeelUIDB.minimap.hide = LeelUIDB.minimapHide or false
            LeelUIDB.minimap.lock = LeelUIDB.minimapLock or false
            LeelUIDB.minimapPos, LeelUIDB.minimapHide, LeelUIDB.minimapLock = nil, nil, nil
        end
        -- v5: 이름표가 두꺼워져서 기본 크기 100%
        if (LeelUIDB.v or 3) < 5 then
            LeelUIDB.npScale = 1.0
            LeelUIDB.v = 5
        end
        ns.db = LeelUIDB
    elseif event == "PLAYER_LOGIN" then
        ns:CreateHUD()
        if ns.debuffNote then Print(ns.debuffNote) end
        if ns.db.hideBlizzard then ns:HideBlizzard() end
        if ns.db.nameplates then
            local ok, err = pcall(ns.EnableNameplates, ns)
            if not ok then Print("이름표 적용 실패: " .. tostring(err)) end
        end
        if ns.db.party then
            local ok, err = pcall(ns.CreateParty, ns)
            if not ok then Print("파티 프레임 적용 실패: " .. tostring(err)) end
        end
        ns.moving = false
        ns:CreateMinimapButton()
        Print("로드 완료. 미니맵 토끼 아이콘이나 |cffffffff/leel|r 로 르엘 허브를 열 수 있어요.")
    end
end)

----------------------------------------------------------------------
-- /leel 명령어
----------------------------------------------------------------------
SLASH_LEELUI1 = "/leel"
SLASH_LEELUI2 = "/luf"
SlashCmdList.LEELUI = function(msg)
    local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")
    if cmd == "" or cmd == "config" then
        ns:ToggleConfig()
    elseif cmd == "unlock" or cmd == "move" then
        ns:SetMoveMode(true)
    elseif cmd == "lock" then
        ns:SetMoveMode(false)
    elseif cmd == "scale" then
        local n = tonumber(arg)
        if n and n >= 0.5 and n <= 1.5 then
            ns:SetHudScale(n)
            Print("HUD 크기: " .. n)
        else
            Print("사용법: /leel scale 0.5~1.5 (예: /leel scale 0.8)")
        end
    elseif cmd == "npscale" then
        local n = tonumber(arg)
        if n and n >= 0.4 and n <= 1.5 then
            ns.db.npScale = n
            if ns.RefreshNameplates then ns:RefreshNameplates() end
            Print("이름표 크기: " .. n)
        else
            Print("사용법: /leel npscale 0.4~1.5 (예: /leel npscale 0.8)")
        end
    elseif cmd == "reset" then
        ns:ResetPosition()
        ns:SetHudScale(ns.defaults.scale)
        ns.db.npScale = ns.defaults.npScale
        if ns.RefreshNameplates then ns:RefreshNameplates() end
        if ns.party then
            ns:SetPartyScale(ns.defaults.partyScale)
            ns:ResetPartyPosition()
        else
            ns.db.partyScale = ns.defaults.partyScale
            ns.db.partyPoint = CopyTable(ns.defaults.partyPoint)
        end
        Print("위치와 크기를 처음대로 돌렸어요.")
    elseif cmd == "debug" then
        -- 대상에 내 디버프를 건 상태에서 실행: 디버프 정보가 어디까지 읽히는지 확인
        local function show(label, ...)
            local parts = { label }
            for i = 1, select("#", ...) do
                local v = select(i, ...)
                local ok, s = pcall(tostring, v)
                if ns.IsSecret(v) then s = "<숨김>" elseif not ok then s = "<?>" end
                parts[#parts + 1] = s
            end
            Print(table.concat(parts, "  "))
        end
        local U = C_UnitAuras or {}
        show("API:", "ByIndex=" .. tostring(U.GetAuraDataByIndex ~= nil),
            "InstanceIDs=" .. tostring(U.GetUnitAuraInstanceIDs ~= nil),
            "GetUnitAuras=" .. tostring(U.GetUnitAuras ~= nil),
            "AuraUtil=" .. tostring(AuraUtil and AuraUtil.ForEachAura ~= nil))
        for _, filter in ipairs({ "HARMFUL|PLAYER", "HARMFUL" }) do
            if U.GetAuraDataByIndex then
                local ok, a = pcall(U.GetAuraDataByIndex, "target", 1, filter)
                if not ok then
                    show(filter .. ":", "에러", a)
                elseif not a then
                    show(filter .. ":", "없음")
                else
                    show(filter .. ":", a.name, "icon", a.icon, "남은", a.expirationTime, "중첩", a.applications)
                end
            end
        end
        if U.GetUnitAuras then
            local ok, list = pcall(U.GetUnitAuras, "target", "HARMFUL|PLAYER")
            show("GetUnitAuras:", ok and (type(list) == "table" and #list or tostring(list)) or ("에러 " .. tostring(list)))
        end
        local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit("target")
        local uf = plate and plate.UnitFrame
        if uf then
            local keys = {}
            for k, v in pairs(uf) do
                if type(k) == "string" and type(v) == "table" and (k:find("Aura") or k:find("Buff") or k:find("Debuff")) then
                    keys[#keys + 1] = k
                end
            end
            show("이름표 오라 프레임:", #keys > 0 and table.concat(keys, ", ") or "없음")
        else
            show("이름표:", "대상 이름표 없음")
        end
    elseif cmd == "icon" then
        ns:SetMinimapShown(ns.db.minimap.hide)
        Print("미니맵 아이콘 " .. (ns.db.minimap.hide and "숨김" or "표시"))
    else
        Print("/leel 르엘 허브, move 이동 모드, scale 0.5~1.5, npscale 0.4~1.5, reset, icon")
    end
    if ns.RefreshConfig then ns:RefreshConfig() end
end
