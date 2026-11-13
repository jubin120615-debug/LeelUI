-- LeelUI / Trade.lua
-- 전문기술 창: 재료(예: 양모 두루마리)를 누르면 그 재료를 만드는 제작식으로 바로 가요.
-- 쉬프트/컨트롤 클릭은 원래대로(채팅 링크, 미리보기) 둬요.
local ADDON, ns = ...

local hooked = false
local MAX_REAGENTS = 8

local function ItemID(link)
    return link and tonumber(link:match("item:(%d+)"))
end

local function Toast(msg)
    if ns.PillToast then ns.PillToast(msg, "hb_bag")
    else UIErrorsFrame:AddMessage(msg, 1, 0.8, 0.85) end
end

-- 지금 목록에서 itemID를 만드는 줄 번호
local function FindRecipe(itemID)
    if not (itemID and GetNumTradeSkills) then return nil end
    for i = 1, GetNumTradeSkills() do
        local _, kind = GetTradeSkillInfo(i)
        if kind and kind ~= "header" and kind ~= "subheader" then
            if ItemID(GetTradeSkillItemLink(i)) == itemID then return i end
        end
    end
end

-- 접힌 묶음 · 검색어 · "재료 있는 것만"에 가려졌을 수 있어서 다 풀어봐요
local function Unhide()
    pcall(function()
        if TradeSkillFrameAvailableFilterCheckButton and TradeSkillFrameAvailableFilterCheckButton:GetChecked() then
            TradeSkillFrameAvailableFilterCheckButton:SetChecked(false)
            if TradeSkillOnlyShowMakeable then TradeSkillOnlyShowMakeable(false) end
        end
    end)
    pcall(function()
        local box = TradeSkillFrameSearchBox or TradeSkillFrameEditBox
        if box and box:GetText() ~= "" then
            box:SetText("")
            if SetTradeSkillItemNameFilter then SetTradeSkillItemNameFilter(nil) end
        end
    end)
    pcall(function() if SetTradeSkillSubClassFilter then SetTradeSkillSubClassFilter(0, 1, 1) end end)
    pcall(function() if SetTradeSkillInvSlotFilter then SetTradeSkillInvSlotFilter(0, 1, 1) end end)
    pcall(ExpandTradeSkillSubClass, 0)
end

-- 고른 줄이 목록 화면에 보이도록 스크롤
local function ScrollTo(i)
    local sf = TradeSkillListScrollFrame
    local shown = TRADE_SKILLS_DISPLAYED or 8
    local h = TRADE_SKILL_HEIGHT or 16
    if not sf then return end
    local maxOff = math.max(0, GetNumTradeSkills() - shown)
    local off = math.min(maxOff, math.max(0, i - math.floor(shown / 2)))
    if FauxScrollFrame_SetOffset then FauxScrollFrame_SetOffset(sf, off) end
    local bar = sf.ScrollBar or TradeSkillListScrollFrameScrollBar
    if bar then bar:SetValue(off * h) end
end

local function Select(i)
    if TradeSkillFrame_SetSelection then TradeSkillFrame_SetSelection(i)
    elseif SelectTradeSkill then SelectTradeSkill(i) end
    ScrollTo(i)
    if TradeSkillFrame_Update then TradeSkillFrame_Update() end
end

local function ReagentLink(btn)
    local idx = GetTradeSkillSelectionIndex and GetTradeSkillSelectionIndex()
    if not idx or idx == 0 then return end
    return GetTradeSkillReagentItemLink(idx, btn:GetID())
end

local function OnClick(btn, mouse)
    if mouse ~= "LeftButton" or IsModifiedClick() then return end
    local link = ReagentLink(btn)
    local id = ItemID(link)
    if not id then return end
    local i = FindRecipe(id)
    if not i then
        Unhide()
        i = FindRecipe(id)
    end
    if i then
        PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
        Select(i)
    else
        Toast("이 재료는 여기서 만들 수 없어요")
    end
end

local function OnEnter(btn)
    local id = ItemID(ReagentLink(btn))
    if not id or not GameTooltip:IsOwned(btn) then return end
    local can = FindRecipe(id)
    if not can then return end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("클릭하면 만드는 법으로 가요", 0.95, 0.70, 0.76)
    GameTooltip:Show()
end

local function Hook()
    if hooked or not TradeSkillFrame then return end
    local found = 0
    for r = 1, MAX_REAGENTS do
        local b = _G["TradeSkillReagent" .. r]
        if b then
            b:HookScript("OnClick", OnClick)
            b:HookScript("OnEnter", OnEnter)
            found = found + 1
        end
    end
    hooked = found > 0
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("TRADE_SKILL_SHOW")
ev:SetScript("OnEvent", function(_, e, name)
    if e == "ADDON_LOADED" and name ~= "Blizzard_TradeSkillUI" then return end
    Hook()
end)
if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_TradeSkillUI") then Hook() end
