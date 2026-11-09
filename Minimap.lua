-- LeelUI / Minimap.lua
-- 미니맵 아이콘: 표준 LibDataBroker + LibDBIcon 사용
-- (Leatrix Plus 등 미니맵 정리 애드온이 정상 버튼으로 인식)

local ADDON, ns = ...
local C = ns.C

local NAME        = "LeelUI"
local ICON        = ns.MEDIA .. "icon"
local ICON_ACTIVE = ns.MEDIA .. "icon_active"

ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") or ""

local LDB  = LibStub("LibDataBroker-1.1", true)
local Icon = LibStub("LibDBIcon-1.0", true)
local obj

local function Tooltip(tt)
    tt:AddDoubleLine("르엘 UI", ns.VERSION, C.acc[1], C.acc[2], C.acc[3], C.tx2[1], C.tx2[2], C.tx2[3])
    tt:AddLine(" ")
    tt:AddDoubleLine("|cffffe08a좌클릭|r", "르엘 허브", 1, 1, 1, 1, 1, 1)
    tt:AddDoubleLine("|cffffe08a우클릭|r", ns.moving and "이동 모드 끄기" or "이동 모드 켜기", 1, 1, 1, 1, 1, 1)
    if not ns.db.minimap.lock then
        tt:AddDoubleLine("|cffffe08a드래그|r", "아이콘 옮기기", 1, 1, 1, 1, 1, 1)
    end
    if InCombatLockdown() then
        tt:AddLine(" ")
        tt:AddLine("전투 중에는 이동할 수 없어요", C.tx2[1], C.tx2[2], C.tx2[3])
    end
end

function ns:CreateMinimapButton()
    if obj or not (LDB and Icon) then return end

    obj = LDB:NewDataObject(NAME, {
        type  = "launcher",
        label = "르엘 UI",
        icon  = ICON,
        OnClick = function(_, button)
            if button == "RightButton" then
                ns:ToggleMoveMode()
            else
                ns:ToggleHub()
            end
        end,
        OnTooltipShow = Tooltip,
    })

    Icon:Register(NAME, obj, ns.db.minimap)
    ns:RegisterCompartment()

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function() ns:UpdateMinimapButton() end)
    ns:UpdateMinimapButton()
end

-- 상태: 평소 / 이동 모드(반전 그림) / 전투 중(회색)
function ns:UpdateMinimapButton()
    if not obj then return end
    obj.icon = ns.moving and ICON_ACTIVE or ICON
    local b = Icon:GetMinimapButton(NAME)
    if b and b.icon then
        b.icon:SetDesaturated(InCombatLockdown() and not ns.moving)
    end
end

function ns:SetMinimapShown(show)
    ns.db.minimap.hide = not show
    if not obj then return end
    if show then Icon:Show(NAME) else Icon:Hide(NAME) end
end

function ns:SetMinimapLocked(lock)
    ns.db.minimap.lock = lock
    if not obj then return end
    if lock then Icon:Lock(NAME) else Icon:Unlock(NAME) end
end

----------------------------------------------------------------------
-- 애드온 모음 목록 (미니맵 옆) — 아이콘을 숨겨도 여기서 열 수 있게
----------------------------------------------------------------------
function ns:RegisterCompartment()
    if ns.compartment or not (AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon) then return end
    ns.compartment = true
    pcall(AddonCompartmentFrame.RegisterAddon, AddonCompartmentFrame, {
        text = "르엘 UI",
        icon = ICON,
        notCheckable = true,
        registerForAnyClick = true,
        func = function(_, data)
            if data and data.buttonName == "RightButton" then
                ns:ToggleMoveMode()
            else
                ns:ToggleHub()
            end
        end,
        funcOnEnter = function(button)
            GameTooltip:SetOwner(button, "ANCHOR_LEFT")
            Tooltip(GameTooltip)
            GameTooltip:Show()
        end,
        funcOnLeave = function() GameTooltip:Hide() end,
    })
end
