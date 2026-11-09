-- 미니맵 버튼: 왼쪽 클릭 = 창 열기/닫기, 오른쪽 클릭 = 완료 기록 다시 확인, 드래그 = 위치 이동
local ADDON = ...

local btn = CreateFrame("Button", "ForgLevelingMinimapButton", Minimap)
btn:SetSize(31, 31)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)
btn:SetMovable(true)
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btn:RegisterForDrag("LeftButton")
btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local overlay = btn:CreateTexture(nil, "OVERLAY")
overlay:SetSize(53, 53)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT")

local bg = btn:CreateTexture(nil, "BACKGROUND")
bg:SetSize(20, 20)
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bg:SetPoint("TOPLEFT", 7, -5)

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetSize(20, 20)
icon:SetTexture("Interface\\AddOns\\ForgLeveling\\media\\logo")
icon:SetPoint("TOPLEFT", 6, -5)

local function DB()
  ForgLevelingDB = ForgLevelingDB or {}
  return ForgLevelingDB
end

-- 미니맵 둘레 위치 계산 (네모 미니맵 애드온도 대략 맞게)
local function UpdatePosition()
  local angle = math.rad(DB().minimapAngle or 215)
  local x, y = math.cos(angle), math.sin(angle)
  local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
  local r = (Minimap:GetWidth() / 2) + 5
  if shape ~= "ROUND" then
    -- 네모 미니맵: 원 대신 사각형 테두리에 붙임
    local m = math.max(math.abs(x), math.abs(y))
    x, y = x / m, y / m
    r = r * 0.95
  end
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", x * r, y * r)
end

local function OnUpdateDrag()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local s = Minimap:GetEffectiveScale()
  px, py = px / s, py / s
  DB().minimapAngle = math.deg((math.atan2 or math.atan)(py - my, px - mx)) % 360
  UpdatePosition()
end

btn:SetScript("OnDragStart", function(self)
  self:LockHighlight()
  self:SetScript("OnUpdate", OnUpdateDrag)
end)
btn:SetScript("OnDragStop", function(self)
  self:SetScript("OnUpdate", nil)
  self:UnlockHighlight()
end)

btn:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 7, -6) end)
btn:SetScript("OnMouseUp", function() icon:SetPoint("TOPLEFT", 6, -5) end)

btn:SetScript("OnClick", function(_, button)
  local cmd = SlashCmdList and SlashCmdList.FORGLEVELING
  if not cmd then return end
  if button == "RightButton" then
    cmd("scan")
  elseif IsShiftKeyDown and IsShiftKeyDown() then
    cmd("mode")
  else
    cmd("")
  end
end)

btn:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("르엘 길잡이", 0.95, 0.70, 0.76)
  local shown = ForgLevelingFrame and ForgLevelingFrame:IsShown()
  GameTooltip:AddLine(shown and "창이 열려 있어요" or "창이 닫혀 있어요", 0.8, 0.8, 0.8)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("왼쪽 클릭: 창 열기/닫기", 0.4, 1, 0.4)
  GameTooltip:AddLine("Shift+클릭: 자세히 / 간략 보기 전환", 0.4, 1, 0.4)
  GameTooltip:AddLine("오른쪽 클릭: 완료한 퀘스트 다시 확인", 0.4, 1, 0.4)
  GameTooltip:AddLine("드래그: 버튼 위치 옮기기", 0.4, 1, 0.4)
  GameTooltip:AddLine("/forg minimap: 버튼 숨기기/보이기", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

btn.UpdatePosition = function() UpdatePosition() end

local function Apply()
  if DB().minimapHide then btn:Hide() else btn:Show(); UpdatePosition() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() Apply() end)

-- /forg minimap 명령을 기존 슬래시 명령 앞에 끼워 넣음
local function Hook()
  local orig = SlashCmdList and SlashCmdList.FORGLEVELING
  if not orig then return end
  SlashCmdList.FORGLEVELING = function(msg)
    local m = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if m == "minimap" or m == "미니맵" then
      DB().minimapHide = not DB().minimapHide
      Apply()
      DEFAULT_CHAT_FRAME:AddMessage("|cfff2b3c2[르엘 길잡이]|r 미니맵 버튼 " ..
        (DB().minimapHide and "숨김 (/forg minimap 으로 다시 보이기)" or "보이기"))
      return
    end
    return orig(msg)
  end
end
Hook()
