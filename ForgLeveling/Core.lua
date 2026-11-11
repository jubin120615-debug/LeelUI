local ADDON, ns = ...
local D = ns.data
local VERSION = "4.3.1"

local DB, CDB              -- 계정 공통 / 캐릭터별 저장
local current = 1          -- 지금 보고 있는 구간 index
local manual = false       -- 사용자가 직접 넘겼으면 레벨업해도 자동 이동 안 함
local tab = 1              -- 자세히 보기에서 고른 탭
local tabAuto = true       -- 탭을 지금 있는 지역으로 자동으로 맞출지

if DEFAULT_CHAT_FRAME then
  DEFAULT_CHAT_FRAME:AddMessage("|cfff2b3c2[르엘 길잡이]|r 애드온 로드됨 (v" .. VERSION .. ")")
end

---------------------------------------------------------------------------
-- 색 · 글꼴
---------------------------------------------------------------------------
local C = {
  bg     = { 0.071, 0.078, 0.090, 0.95 },
  surf   = { 0.094, 0.106, 0.122, 1 },
  raise  = { 0.125, 0.141, 0.165, 1 },
  line   = { 0.165, 0.184, 0.212, 1 },
  line2  = { 0.204, 0.227, 0.259, 1 },
  text   = { 0.902, 0.890, 0.863 },
  muted  = { 0.541, 0.565, 0.600 },
  faint  = { 0.365, 0.388, 0.424 },
  accent = { 0.886, 0.651, 0.231 },
  warn   = { 0.843, 0.455, 0.373 },
  hunt   = { 0.788, 0.443, 0.353 },
  ok     = { 0.373, 0.561, 0.306 },
  row    = { 0, 0, 0, 0.22 },
}
local BADGE = {
  get  = { c = { 0.914, 0.773, 0.290 }, g = "!" },
  turn = { c = { 0.886, 0.651, 0.231 }, g = "?" },
  hunt = { c = { 0.843, 0.380, 0.310 }, tex = "Interface\\CURSOR\\Attack" },
  ok   = { c = { 0.373, 0.561, 0.306 }, tex = "Interface\\RaidFrame\\ReadyCheck-Ready" },
}
local function MakeBadge(parent, size)
  local b = CreateFrame("Frame", nil, parent)
  b:SetSize(size, size)
  b.circle = b:CreateTexture(nil, "ARTWORK")
  b.circle:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  b.circle:SetAllPoints()
  b.glyph = b:CreateFontString(nil, "OVERLAY")
  b.glyph:SetFont(STANDARD_TEXT_FONT or "Fonts\\2002.TTF", math.floor(size * 0.66), "")
  b.glyph:SetPoint("CENTER", 0, 0)
  b.glyph:SetTextColor(0.10, 0.08, 0.03)
  b.icon = b:CreateTexture(nil, "OVERLAY")
  b.icon:SetSize(size * 0.7, size * 0.7)
  b.icon:SetPoint("CENTER")
  function b:SetKind(kind, dim)
    local d = BADGE[kind] or BADGE.get
    self.circle:SetVertexColor(d.c[1], d.c[2], d.c[3], dim and 0.6 or 1)
    if d.tex then
      self.icon:SetTexture(d.tex); self.icon:Show(); self.glyph:SetText("")
      if kind == "hunt" then
        -- 붉은 동그라미 위 흰 칼 (커서 그림을 흑백으로 바꿔 하얗게)
        self.icon:SetSize(self:GetWidth() * 0.62, self:GetWidth() * 0.62)
        if self.icon.SetDesaturated then self.icon:SetDesaturated(true) end
        self.icon:SetVertexColor(1, 1, 1)
      else
        self.icon:SetSize(self:GetWidth() * 0.7, self:GetWidth() * 0.7)
        if self.icon.SetDesaturated then self.icon:SetDesaturated(false) end
        self.icon:SetVertexColor(1, 1, 1)
      end
    else
      self.icon:Hide(); self.glyph:SetText(d.g)
    end
  end
  return b
end

local ICON = {
  get  = "Interface\\GossipFrame\\AvailableQuestIcon",
  turn = "Interface\\GossipFrame\\ActiveQuestIcon",
  hunt = "Interface\\CURSOR\\Attack",
  ok   = "Interface\\RaidFrame\\ReadyCheck-Ready",
  circle = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
  arrow = "Interface\\Minimap\\MiniMap-QuestArrow",
}
local HX = { text = "e6e3dc", muted = "8a9099", faint = "5d636c", accent = "e2a63b", warn = "d7745f" }
local function col(name, s) return "|cff" .. HX[name] .. s .. "|r" end

local FONT = STANDARD_TEXT_FONT or "Fonts\\2002.TTF"
-- 르엘 UI 글씨체를 따라감 (허브에서 바꾸면 바로 바뀜)
local function LeelFont(fs, size, flags)
    local L = _G.LeelUI
    local ok = fs:SetFont((L and L.FONT) or FONT, size, flags or "")
    if L and L.TrackText then L.TrackText(fs, size, flags or "") end
    return ok
end

local WHITE = "Interface\\Buttons\\WHITE8x8"

local ApiObjectivePos -- 게임이 지도에 표시하는 퀘스트 위치 (아래에서 채움)

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cfff2b3c2[르엘 길잡이]|r " .. msg)
end

local function FS(parent, size, c, justify)
  local s = parent:CreateFontString(nil, "OVERLAY")
  LeelFont(s, size, "")
  c = c or C.text
  s.__c = c
  s:SetTextColor(c[1], c[2], c[3])
  s:SetShadowOffset(1, -1)
  s:SetShadowColor(0, 0, 0, C.__shadow or 0.6)
  s:SetJustifyH(justify or "LEFT")
  s:SetWordWrap(false)
  return s
end

local function Tex(parent, c, layer)
  local t = parent:CreateTexture(nil, layer or "ARTWORK")
  t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
  t.__c = c
  return t
end

local function Backdrop(fr, bg, edge)
  if not fr.SetBackdrop then return end
  fr.__bg, fr.__edge = bg, edge
  local rnd = rawget(fr, "__round")
  if C.__round and rnd and C.__roundfn then
    -- 귀여운 테마: 둥근 모서리 (모서리 그림 + 직선으로 직접 그림)
    fr:SetBackdrop(nil)
    C.__roundfn(fr, bg, edge, rnd)
    return
  end
  local rr0 = rawget(fr, "__rr")
  if rr0 then for _, t in ipairs(rr0) do t:Hide() end end
  fr:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  fr:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
  fr:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4] or 1)
end

local BD = BackdropTemplateMixin and "BackdropTemplate" or nil

-- 납작한 버튼
local function FlatButton(parent, text, w, h)
  local b = CreateFrame("Button", nil, parent, BD)
  b.__round = 8
  b:SetSize(w, h or 24)
  b.label = FS(b, 11, C.muted, "CENTER")
  b.label:SetPoint("CENTER", 0, 0)
  b.label:SetText(text)
  b.active = false
  function b:Paint()
    local col
    if self.active then
      Backdrop(self, { C.accent[1], C.accent[2], C.accent[3], 0.14 }, { C.accent[1], C.accent[2], C.accent[3], 0.5 })
      col = C.accent
    elseif self.hover then
      Backdrop(self, C.raise, C.line2)
      col = C.text
    else
      Backdrop(self, { 0, 0, 0, 0 }, C.line)
      col = C.muted
    end
    self.label:SetTextColor(col[1], col[2], col[3])
    local ic = rawget(self, "icon")
    if ic then ic:SetVertexColor(col[1], col[2], col[3]) end
  end
  function b:SetActive(on) self.active = on and true or false; self:Paint() end
  function b:SetText(t) self.label:SetText(t) end
  b:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
  b:SetScript("OnLeave", function(self) self.hover = false; self:Paint() end)
  b:Paint()
  return b
end

---------------------------------------------------------------------------
-- 데이터 준비
---------------------------------------------------------------------------
-- 퀘스트 이름 비교용: 괄호 설명, 앞쪽 [레벨] 표시, 공백·기호를 지움
local function Norm(s)
  if not s then return "" end
  s = s:gsub("^%[[^%]]*%]%s*", "")
  s = s:gsub("%b()", "")
  s = s:gsub("[%s%p]", "")
  return s
end

local function BracketForLevel(lv)
  for i, b in ipairs(D.brackets) do
    if lv >= b.min and lv <= b.max then return i end
  end
  return lv < 1 and 1 or #D.brackets
end

local guideByKey = {} -- 정규화 이름 → { q, zone }  (가장 가까운 레벨 구간 것)
local function PrepareData()
  for bi, b in ipairs(D.brackets) do
    local hb = D.hubs and D.hubs[bi] or {}
    for _, z in ipairs(b.zones) do
      local hz = hb[z.name] or {}
      local seen = {}
      for qi, q in ipairs(z.quests) do
        q.idx = qi
        q.key = Norm(q[2])
        local h = hz[q[2]]
        if type(h) == "table" then
          seen[q[2]] = (seen[q[2]] or 0) + 1
          h = h[seen[q[2]]]
        end
        q.hub = h
        if q[4] and not guideByKey[q.key] then guideByKey[q.key] = { q = q, zone = z.name } end
      end
    end
  end
end

---------------------------------------------------------------------------
-- 퀘스트 로그 읽기 (목표 진행도 포함)
---------------------------------------------------------------------------
local logIDs = {}    -- questID → 제목 (반납 감지용)
local logList = {}   -- 지금 퀘스트 로그 { title, key, id, level, state, objs }
local logByKey = {}
local logById = {}

local function ParseObjective(text, have, need, done)
  text = text or ""
  local name, a, b = text:match("^(.-)%s*:%s*(%d+)%s*/%s*(%d+)%s*$")
  if not name then
    a, b, name = text:match("^(%d+)%s*/%s*(%d+)%s+(.+)$")
  end
  if name and name ~= "" then text = name end
  have = have or tonumber(a)
  need = need or tonumber(b)
  if done == nil and have and need then done = have >= need end
  return { text = text, have = have, need = need, done = done and true or false }
end

local function ReadObjectivesNew(id)
  local out = {}
  if not (id and C_QuestLog and C_QuestLog.GetQuestObjectives) then return out end
  local ok, list = pcall(C_QuestLog.GetQuestObjectives, id)
  if ok and type(list) == "table" then
    for _, o in ipairs(list) do
      out[#out + 1] = ParseObjective(o.text, o.numFulfilled, o.numRequired, o.finished)
    end
  end
  return out
end

local function ReadObjectivesOld(index)
  local out = {}
  if not (GetNumQuestLeaderBoards and GetQuestLogLeaderBoard) then return out end
  local ok, n = pcall(GetNumQuestLeaderBoards, index)
  if not ok or not n then return out end
  for i = 1, n do
    local ok2, text, _, finished = pcall(GetQuestLogLeaderBoard, i, index)
    if ok2 and text then out[#out + 1] = ParseObjective(text, nil, nil, finished and true or nil) end
  end
  return out
end

-- 목표가 다 찼는데 게임이 완료 표시를 안 줄 때도 완료로 봄 (숫자 6/6 같은 것도 확인)
function ns.AllObjDone(done, objs)
  if done or type(objs) ~= "table" or #objs == 0 then return done and true or false end
  for _, o in ipairs(objs) do
    local full = o.done or (o.need and o.need > 0 and o.have and o.have >= o.need)
    if not full then return false end
  end
  return true
end

local function ReadQuestLog()
  local t, list = {}, {}
  local found = false
  if C_QuestLog and C_QuestLog.GetInfo and C_QuestLog.GetNumQuestLogEntries then
    local ok = pcall(function()
      for i = 1, (C_QuestLog.GetNumQuestLogEntries()) do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.title then
          local done = info.questID and C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID)
          local objs = ReadObjectivesNew(info.questID)
          if (not objs or #objs == 0) and GetQuestLogLeaderBoard then objs = ReadObjectivesOld(i) end
          done = ns.AllObjDone(done, objs)
          local e = { title = info.title, key = Norm(info.title), id = info.questID, level = info.level,
                      state = done and 2 or 1, objs = objs }
          list[#list + 1] = e
          t[e.key] = e.state
          if info.questID then logIDs[info.questID] = info.title end
          found = true
        end
      end
    end)
    if not ok then found = false end
  end
  if not found and GetNumQuestLogEntries and GetQuestLogTitle then
    t, list = {}, {}
    local n = GetNumQuestLogEntries()
    for i = 1, n do
      local title, level, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
      if title and not isHeader then
        local done = (isComplete == 1 or isComplete == true)
        if not done and questID and IsQuestComplete then
          local ok, r = pcall(IsQuestComplete, questID)
          if ok and r then done = true end
        end
        local objs = ReadObjectivesOld(i)
        if #objs == 0 then objs = ReadObjectivesNew(questID) end
        done = ns.AllObjDone(done, objs)
        local e = { title = title, key = Norm(title), id = questID, level = level,
                    state = done and 2 or 1, objs = objs }
        list[#list + 1] = e
        t[e.key] = e.state
        if questID then logIDs[questID] = title end
      end
    end
  end
  logList, logByKey, logById = list, {}, {}
  for _, e in ipairs(list) do
    logByKey[e.key] = e
    if e.id then logById[e.id] = e end
  end
  return t
end

-- 상태: 3=반납 완료, 2=완료 가능, 1=진행 중, nil=안 받음
local function QuestState(q, log)
  if CDB.manual[q.key] == true then return 3 end
  if CDB.manual[q.key] == false then return log[q.key] end
  if log[q.key] then return log[q.key] end
  if CDB.done[q.key] then return 3 end
  return nil
end

local function IsSkipped(key, log)
  local k = CDB and CDB.skip and CDB.skip[key]
  if not k then return false end
  if k == "get" and log and log[key] then return false end
  return true
end

-- 퀘스트 번호로 완료 여부 (같은 이름 연계 퀘스트 구분용)
local function QuestIdDone(id)
  if not id then return false end
  if CDB and CDB.doneIds and CDB.doneIds[id] then return true end
  local f = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
  if f then
    local ok, r = pcall(f, id)
    if ok and r then return true end
  end
  return false
end

local function PlayerZone()
  local z = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
  return z
end

---------------------------------------------------------------------------
-- 웨이포인트
---------------------------------------------------------------------------
local function SetWaypoint(mapID, x, y, title)
  if not mapID and C_Map and C_Map.GetBestMapForUnit then
    mapID = C_Map.GetBestMapForUnit("player")
  end
  -- 점선 길: 웨이포인트를 찍었을 때만. 같은 곳을 다시 찍으면 끔
  if mapID and x and y then
    local t = ns.trail
    if t and t.map == mapID and math.abs(t.x - x) < 0.05 and math.abs(t.y - y) < 0.05 then
      ns.trail = nil
      Print("점선 길을 껐어요")
      if ns.trailRefresh then ns.trailRefresh() end
      return
    end
    ns.trail = { map = mapID, x = x, y = y, label = title }
    if ns.trailRefresh then ns.trailRefresh() end
  end
  -- 지도 핀(TomTom·게임 핀)은 지도를 가려서 안 찍음. 점선 길만 씀
  Print(("%s (%.1f, %.1f)까지 점선 길을 그렸어요. 다시 누르면 꺼요"):format(title, x, y))
end

-- 자동 길 안내: 지금 할 일이 바뀌면 조용히 새 위치로 점선 길을 옮김 (끄기 토글 없음)
local function AutoWaypoint(mapID, x, y, title)
  if not mapID and C_Map and C_Map.GetBestMapForUnit then
    mapID = C_Map.GetBestMapForUnit("player")
  end
  if not (mapID and x and y) then return end
  ns.trail = { map = mapID, x = x, y = y, label = title }
  if ns.trailRefresh then ns.trailRefresh() end
end

---------------------------------------------------------------------------
-- 창 뼈대
---------------------------------------------------------------------------
local FULL_W, FULL_H = 452, 640
local MINI_W = 240
local PAD = 14

local f = CreateFrame("Frame", "ForgLevelingFrame", UIParent, BD)
f:SetSize(FULL_W, FULL_H)
f:SetPoint("CENTER")
f:SetFrameStrata("MEDIUM")
f:SetClampedToScreen(true)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p, _, rp, x, y = self:GetPoint()
  DB.point = { p, rp, x, y }
end)
Backdrop(f, C.bg, C.line2)
f:Hide()

-- 머리: 지역 이름, 레벨 범위, 보기 전환, 닫기
local zoneFS = FS(f, 16, C.text)
zoneFS:SetPoint("TOPLEFT", PAD, -14)
local rangeFS = FS(f, 11, C.muted)
rangeFS:SetPoint("BOTTOMLEFT", zoneFS, "BOTTOMRIGHT", 8, 1)

local closeB = FlatButton(f, "X", 24, 24)
closeB:SetPoint("TOPRIGHT", -10, -10)
closeB:SetScript("OnClick", function() f:Hide(); DB.shown = false end)

local segFull = FlatButton(f, "자세히", 50, 24)
local segMini = FlatButton(f, "간략", 42, 24)
segMini:SetPoint("RIGHT", closeB, "LEFT", -8, 0)
segFull:SetPoint("RIGHT", segMini, "LEFT", 1, 0)
local gearB = CreateFrame("Button", nil, f, BD)
gearB:SetSize(30, 22)
gearB:SetPoint("RIGHT", segFull, "LEFT", -6, 0)
gearB.txt = FS(gearB, 10, C.muted, "CENTER"); gearB.txt:SetPoint("CENTER"); gearB.txt:SetText("설정")
Backdrop(gearB, { 0, 0, 0, 0 }, C.line)
gearB:SetScript("OnEnter", function(self)
  Backdrop(self, C.raise, C.line2)
  GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine("설정", C.accent[1], C.accent[2], C.accent[3]); GameTooltip:Show()
end)
gearB:SetScript("OnLeave", function(self) Backdrop(self, { 0, 0, 0, 0 }, C.line); GameTooltip:Hide() end)

-- 자세히 보기 전용: 구간 이동, 정렬, 숨김
local fullOnly = {}
local prevB = FlatButton(f, "<", 26, 26)
prevB:SetPoint("TOPLEFT", PAD, -46)
local stepB = FlatButton(f, "", 80, 26)
stepB:SetPoint("LEFT", prevB, "RIGHT", -1, 0)
stepB:EnableMouse(false)
local nextB = FlatButton(f, ">", 26, 26)
nextB:SetPoint("LEFT", stepB, "RIGHT", -1, 0)
local lvB = FlatButton(f, "", 66, 26)
lvB:SetPoint("LEFT", nextB, "RIGHT", 8, 0)
local hideB = FlatButton(f, "완료 숨김", 66, 26)
hideB:SetPoint("TOPRIGHT", -PAD, -46)
local sortB = FlatButton(f, "거점순", 54, 26)
local planB = FlatButton(f, "루트 만들기", 72, 26)
planB:SetPoint("RIGHT", sortB, "LEFT", -6, 0)
fullOnly[#fullOnly + 1] = planB
sortB:SetPoint("RIGHT", hideB, "LEFT", -6, 0)
for _, w in ipairs({ prevB, stepB, nextB, lvB, hideB, sortB }) do fullOnly[#fullOnly + 1] = w end

-- 진행 막대
local barBG = Tex(f, C.line)
barBG:SetHeight(3)
local barFill = Tex(f, C.accent)
barFill:SetHeight(3)
barFill:SetPoint("LEFT", barBG, "LEFT", 0, 0)
local progFS = FS(f, 11, C.muted, "RIGHT")

-- 탭
local tabs = {}
local tabLine = Tex(f, C.line)
tabLine:SetHeight(1)
local function GetTab(i)
  local t = tabs[i]
  if t then return t end
  t = CreateFrame("Button", nil, f)
  t:SetHeight(30)
  t.name = FS(t, 12, C.muted)
  t.name:SetPoint("LEFT", 8, 0)
  t.cnt = FS(t, 10, C.faint)
  t.cnt:SetPoint("LEFT", t.name, "RIGHT", 5, 0)
  t.under = Tex(t, C.accent)
  t.under:SetHeight(2)
  t.under:SetPoint("BOTTOMLEFT", 4, 0)
  t.under:SetPoint("BOTTOMRIGHT", -4, 0)
  t.hl = Tex(t, { 1, 1, 1, 0.04 }, "HIGHLIGHT")
  t.hl:SetAllPoints()
  tabs[i] = t
  return t
end

-- 목록 영역
local scroll = CreateFrame("ScrollFrame", nil, f)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(FULL_W - 2 * PAD, 10)
scroll:SetScrollChild(content)
local thumb = Tex(f, C.line2)
thumb:SetWidth(3)

local function MaxScroll()
  return math.max(0, (content:GetHeight() or 0) - (scroll:GetHeight() or 0))
end
local function UpdateThumb()
  local viewH, contH = scroll:GetHeight() or 0, content:GetHeight() or 0
  if DB and DB.mode == "mini" or contH <= viewH + 1 or viewH <= 0 then thumb:Hide(); return end
  local h = math.max(24, viewH * viewH / contH)
  local pos = (scroll:GetVerticalScroll() or 0) / MaxScroll()
  thumb:ClearAllPoints()
  thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 6, -pos * (viewH - h))
  thumb:SetHeight(h)
  thumb:Show()
end
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(self, d)
  local v = math.min(MaxScroll(), math.max(0, (self:GetVerticalScroll() or 0) - d * 44))
  self:SetVerticalScroll(v)
  UpdateThumb()
end)

-- 바닥: 던전
local footLine = Tex(f, C.line)
footLine:SetHeight(1)
local footFS = FS(f, 11, C.muted)
footFS:SetWordWrap(true)
fullOnly[#fullOnly + 1] = footLine
fullOnly[#fullOnly + 1] = footFS

---------------------------------------------------------------------------
-- 목록 줄
---------------------------------------------------------------------------
local Render -- forward
-- 레벨 관련 도우미 (회색 판정 등)
local LV = {}
-- 회색 기준: 내 레벨 - 이 값보다 낮으면 회색 (게임 함수가 있으면 그걸 씀)
function LV.GreenRange()
  if GetQuestGreenRange then
    local ok, r = pcall(GetQuestGreenRange)
    if ok and tonumber(r) then return tonumber(r) end
  end
  local lv = UnitLevel("player") or 1
  if lv <= 5 then return 5 elseif lv <= 39 then return math.floor(lv / 10) + 5 elseif lv <= 59 then return math.floor(lv / 5) + 1 else return 12 end
end
function LV.IsGrey(level)
  level = tonumber(level)
  if not level or level <= 0 then return false end
  return ((UnitLevel("player") or 1) - level) > LV.GreenRange()
end
function LV.SkipGrey() return DB and DB.skipGrey ~= false end
local TogglePrio -- forward (아래 BuildPlan 뒤에서 채움)
local inCombat = false
local ApplyAlpha
local rows, used = {}, 0
local y = 0
local CW = FULL_W - 2 * PAD

local function RowTooltip(self)
  local q, e = self.q, self.e
  if not q and not e then return end
  -- (아래에서 st, e 사용)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(q and q[2] or e.title, C.accent[1], C.accent[2], C.accent[3])
  if q then
    GameTooltip:AddLine("퀘스트 레벨 " .. q[1] .. (q.hub and ("   거점 " .. q.hub) or ""), 1, 1, 1)
  elseif e.level then
    GameTooltip:AddLine("퀘스트 레벨 " .. e.level, 1, 1, 1)
  end
  local st = self.state
  local label = st == 3 and "반납 완료" or st == 2 and "목표 완료, 반납하세요" or st == 1 and "진행 중" or "아직 안 받음"
  GameTooltip:AddLine("상태: " .. label, C.text[1], C.text[2], C.text[3])
  if e and e.objs and #e.objs > 0 then
    GameTooltip:AddLine(" ")
    for _, o in ipairs(e.objs) do
      local cnt = (o.have and o.need) and ("  " .. o.have .. "/" .. o.need) or ""
      local c = o.done and C.faint or C.text
      GameTooltip:AddLine(o.text .. cnt, c[1], c[2], c[3])
    end
  end
  if q then
    if q[3] then GameTooltip:AddLine(" "); GameTooltip:AddLine("주는 NPC: " .. q[3] .. (q[6] and ("  (" .. q[6] .. ")") or ""), C.muted[1], C.muted[2], C.muted[3]) end
    if q[4] then
      GameTooltip:AddLine(("좌표 %.1f, %.1f"):format(q[4], q[5]), C.muted[1], C.muted[2], C.muted[3])
    end
    if st == 1 and e and e.id then
      GameTooltip:AddLine("클릭: 지도에서 수행 지역 보기", C.accent[1], C.accent[2], C.accent[3])
      if q[4] then GameTooltip:AddLine("Shift+클릭: 퀘스트 주는 곳 웨이포인트", C.accent[1], C.accent[2], C.accent[3]) end
    elseif q[4] then
      GameTooltip:AddLine("클릭: 웨이포인트", C.accent[1], C.accent[2], C.accent[3])
    end
    GameTooltip:AddLine("오른쪽 클릭: 완료 표시 켜기/끄기", C.accent[1], C.accent[2], C.accent[3])
  end
  local pk = (q and q.key) or (e and e.key)
  if pk then
    local on = CDB.prio and CDB.prio[pk]
    GameTooltip:AddLine(on and "Ctrl+클릭: '먼저 하기' 끄기" or "Ctrl+클릭: 이 퀘스트 먼저 하기 (루트 맨 앞으로)", 0.4, 1, 0.4)
  end
  GameTooltip:Show()
end

-- 전체 지도를 열고 그 퀘스트를 선택 (게임이 수행 지역을 표시)
local function OpenQuestOnMap(id, title)
  if not id then Print("이 퀘스트는 퀘스트 로그에 없어서 지도에 표시할 수 없어요."); return end
  if InCombatLockdown and InCombatLockdown() then Print("전투 중에는 지도를 열 수 없어요. 전투가 끝나면 다시 눌러 주세요."); return end
  if QuestMapFrame_OpenToQuestDetails and pcall(QuestMapFrame_OpenToQuestDetails, id) then return end
  local idx
  if GetQuestLogIndexByID then local ok, r = pcall(GetQuestLogIndexByID, id); if ok then idx = r end end
  if (not idx or idx == 0) and C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
    local ok, r = pcall(C_QuestLog.GetLogIndexForQuestID, id); if ok then idx = r end
  end
  if idx and idx > 0 and SelectQuestLogEntry then pcall(SelectQuestLogEntry, idx) end
  if C_QuestLog and C_QuestLog.SetSelectedQuest then pcall(C_QuestLog.SetSelectedQuest, id) end
  local m
  if C_Map and C_Map.GetBestMapForUnit then local ok, r = pcall(C_Map.GetBestMapForUnit, "player"); if ok then m = r end end
  if OpenWorldMap and pcall(OpenWorldMap, m) then return end
  if WorldMapFrame and not WorldMapFrame:IsShown() then
    if ToggleWorldMap then pcall(ToggleWorldMap) elseif ShowUIPanel then pcall(ShowUIPanel, WorldMapFrame) end
  end
  if WorldMapFrame and m and WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, m) end
end

local function RowClick(self, button)
  local q = self.q
  if IsControlKeyDown and IsControlKeyDown() and button ~= "RightButton" then
    local key = (q and q.key) or (self.e and self.e.key)
    if key and TogglePrio then TogglePrio(key, (q and q[2]) or (self.e and self.e.title)) end
    return
  end
  if not q and self.wp and button ~= "RightButton" then
    local w = self.wp
    SetWaypoint(w.map, w.x, w.y, w.title)
    return
  end
  if not q then
    if self.e and self.e.id and button ~= "RightButton" then OpenQuestOnMap(self.e.id, self.e.title) end
    return
  end
  if button == "RightButton" and CDB.skip and CDB.skip[q.key] then
    CDB.skip[q.key] = nil
    Print("건너뛰기 취소: " .. q[2])
    Render()
    return
  end
  if button == "RightButton" then
    if self.state == 3 then
      CDB.manual[q.key] = false
      CDB.done[q.key] = nil
      Print("완료 표시 해제: " .. q[2])
    else
      CDB.manual[q.key] = true
      Print("완료로 표시: " .. q[2])
    end
    Render()
  elseif self.state == 2 and self.e and self.e.id and ApiObjectivePos and ApiObjectivePos(self.e.id) then
    local m, x, yy = ApiObjectivePos(self.e.id)
    SetWaypoint(m, x, yy, q[2] .. " 반납")
  elseif self.state == 1 and self.e and self.e.id and not IsShiftKeyDown() then
    OpenQuestOnMap(self.e.id, q[2])
  elseif q[4] then
    local map = D.maps[q[6] or self.zone]
    SetWaypoint(map, q[4], q[5], q[2] .. (q[3] and (" (" .. q[3] .. ")") or ""))
  end
end

local function GetRow()
  used = used + 1
  local r = rows[used]
  if not r then
    r = CreateFrame("Button", nil, content)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.hl = Tex(r, { 1, 1, 1, 0.05 }, "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.stripe = Tex(r, C.accent)
    r.stripe:SetWidth(2)
    r.stripe:SetPoint("TOPLEFT", 0, -4)
    r.stripe:SetPoint("BOTTOMLEFT", 0, 4)
    r.num = FS(r, 10, C.faint, "RIGHT")
    r.num:SetWidth(18)
    r.lv = FS(r, 10, C.faint, "RIGHT")
    r.lv:SetWidth(18)
    r.name = FS(r, 12, C.text)
    r.right = FS(r, 10, C.faint, "RIGHT")
    r.right:SetWidth(70)
    r:SetScript("OnEnter", RowTooltip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", RowClick)
    rows[used] = r
  end
  r.q, r.e, r.zone, r.state, r.wp = nil, nil, nil, nil, nil
  r.stripe:Hide()
  r.num:SetText(""); r.lv:SetText(""); r.right:SetText(""); r.name:SetText("")
  r.name:SetWordWrap(false)
  r:Show()
  return r
end

local function Place(r, h, gap, width)
  y = y + (gap or 0)
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
  r:SetSize(width or CW, h)
  y = y + h
end

-- 줄 종류 ---------------------------------------------------------------
local function AddLabel(text, gap, size, c, width)
  local r = GetRow()
  r:EnableMouse(false)
  LeelFont(r.name, size or 11, "")
  c = c or C.muted
  r.name:SetTextColor(c[1], c[2], c[3])
  r.name:ClearAllPoints()
  r.name:SetPoint("LEFT", 0, 0)
  r.name:SetPoint("RIGHT", 0, 0)
  r.name:SetWordWrap(true)
  r.name:SetText(text)
  local h = math.max(16, (r.name:GetStringHeight() or 12) + 4)
  Place(r, h, gap, width)
  return r
end

local function StateTag(st)
  if st == 2 then return "  " .. col("accent", "반납")
  elseif st == 1 then return "  " .. col("muted", "진행") end
  return ""
end

-- 퀘스트 줄. opts: num, level, name, npc, right, state, q, e, zone, width, compact
local function AddQuest(o)
  local r = GetRow()
  r:EnableMouse(true)
  r.q, r.e, r.zone, r.state = o.q, o.e, o.zone, o.state
  r.wp = o.wp
  local st = o.state
  local lvNum = o.level or 0
  local plv = UnitLevel("player") or 1

  LeelFont(r.name, 12, "")
  local c = C.text
  if st == 3 then c = C.faint
  elseif not st and lvNum > plv + 2 then c = C.warn
  elseif not st and lvNum > 0 and lvNum < plv - 5 then c = C.muted end
  r.name:SetTextColor(c[1], c[2], c[3])

  if st == 2 or st == 1 then
    local sc = st == 2 and C.accent or C.muted
    r.stripe:SetColorTexture(sc[1], sc[2], sc[3], 1)
    r.stripe:Show()
  end

  local x = 8
  r.num:ClearAllPoints(); r.lv:ClearAllPoints(); r.name:ClearAllPoints(); r.right:ClearAllPoints()
  if not o.compact then
    r.num:SetPoint("LEFT", 2, 0)
    r.num:SetText(o.num and tostring(o.num) or "")
    r.lv:SetPoint("LEFT", 24, 0)
    r.lv:SetText(lvNum > 0 and tostring(lvNum) or "")
    x = 48
  end
  r.right:SetPoint("RIGHT", 0, 0)
  r.right:SetText(o.right or "")
  r.name:SetPoint("LEFT", x, 0)
  r.name:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
  local nm = o.name
  if st == 3 then nm = nm .. "  " .. col("faint", "완료") end
  if st ~= 3 and o.q and IsSkipped(o.q.key, logByKey) then nm = nm .. "  " .. col("faint", "건너뜀") end
  if not o.compact then nm = nm .. StateTag(st) end
  if o.npc and not o.compact and st ~= 3 then nm = nm .. "  " .. col("faint", o.npc) end
  r.name:SetText(nm)
  Place(r, 21, o.gap or 0, o.width)
  return r
end

-- 목표 진행 줄
local function AddObjectives(e, indent, width, limit)
  if not e or not e.objs then return end
  local n = 0
  for _, ob in ipairs(e.objs) do
    n = n + 1
    if limit and n > limit then
      AddLabel(col("faint", ("   목표 %d개 더"):format(#e.objs - limit)), 0, 10, C.faint, width)
      break
    end
    local r = GetRow()
    r:EnableMouse(false)
    LeelFont(r.name, 11, "")
    local c = ob.done and C.faint or C.muted
    r.name:SetTextColor(c[1], c[2], c[3])
    r.name:ClearAllPoints(); r.right:ClearAllPoints()
    r.right:SetPoint("RIGHT", 0, 0)
    r.name:SetPoint("LEFT", indent, 0)
    r.name:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
    r.name:SetText(ob.text)
    if ob.have and ob.need then
      if ob.done then
        r.right:SetText(col("faint", ob.have .. "/" .. ob.need))
      else
        r.right:SetText(col("text", tostring(ob.have)) .. col("faint", "/" .. ob.need))
      end
    elseif ob.done then
      r.right:SetText(col("faint", "완료"))
    end
    Place(r, 17, 0, width)
  end
end

local function Coord(q) return (q and q[4]) and ("%.1f, %.1f"):format(q[4], q[5]) or "" end

local function SortedQuests(z)
  local list = {}
  for _, q in ipairs(z.quests) do list[#list + 1] = q end
  if DB.sort == "hub" then
    table.sort(list, function(a, b)
      local ha, hb = a.hub or 99, b.hub or 99
      if ha ~= hb then return ha < hb end
      if a[1] ~= b[1] then return a[1] < b[1] end
      return a.idx < b.idx
    end)
  end
  return list
end

-- 로그 퀘스트를 가이드와 맞춰 봄 (지금 구간 먼저)
local function GuideFor(key, b)
  for _, z in ipairs(b.zones) do
    for _, q in ipairs(z.quests) do
      if q.key == key then return q, z.name end
    end
  end
  local g = guideByKey[key]
  if g then return g.q, g.zone end
end

---------------------------------------------------------------------------
-- 그리기
---------------------------------------------------------------------------
-- 머리 버튼: 귀여운 테마는 간격 띄운 알약 모양, 기본은 붙은 탭
function LV.HeaderStyle(mini)
  local M = "Interface\\AddOns\\ForgLeveling\\media\\"
  if not LV.hdrIcons then
    LV.hdrIcons = true
    local function tip(b, title, desc)
      local en, lv = b:GetScript("OnEnter"), b:GetScript("OnLeave")
      b:SetScript("OnEnter", function(self)
        if en then en(self) end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(title, C.accent[1], C.accent[2], C.accent[3])
        if desc then GameTooltip:AddLine(desc, C.text[1], C.text[2], C.text[3], true) end
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function(self) if lv then lv(self) end; GameTooltip:Hide() end)
    end
    local function addIcon(b, name, sz)
      b.icon = b:CreateTexture(nil, "ARTWORK")
      b.icon:SetSize(sz, sz); b.icon:SetPoint("CENTER")
      b.icon:SetTexture(M .. name)
    end
    addIcon(segFull, "ic_full", 14); segFull:SetText("")
    addIcon(segMini, "ic_mini", 14); segMini:SetText("")
    addIcon(closeB, "ic_close", 11); closeB:SetText("")
    tip(segFull, "자세히", "단계 전체를 크게 보여 줘요")
    tip(segMini, "간략", "지금 할 일만 작게 보여 줘요")
    tip(closeB, "닫기", "/forg 로 다시 열 수 있어요")
    addIcon(gearB, "ic_gear", 14); gearB.txt:SetText("")
    LV.helpB = FlatButton(f, "", 22, 22)
    addIcon(LV.helpB, "ic_help", 13)
    tip(LV.helpB, "사용설명서", "버튼, 클릭 방법, 명령어를 알려 줘요")
    LV.helpB:SetScript("OnClick", function() if LV.ShowHelp then LV.ShowHelp() end end)
    gearB.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
    gearB:SetScript("OnEnter", function(self)
      Backdrop(self, C.raise, C.line2)
      self.icon:SetVertexColor(C.text[1], C.text[2], C.text[3])
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine("설정", C.accent[1], C.accent[2], C.accent[3]); GameTooltip:Show()
    end)
    gearB:SetScript("OnLeave", function(self)
      Backdrop(self, { 0, 0, 0, 0 }, C.line)
      self.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
      GameTooltip:Hide()
    end)
  end
  for _, b in ipairs({ LV.helpB, gearB, segFull, segMini, closeB }) do b:SetSize(22, 22); b.__round = 11 end
  LV.helpB:ClearAllPoints(); LV.helpB:SetPoint("RIGHT", gearB, "LEFT", -4, 0)
  LV.helpB:Paint()
  segMini:ClearAllPoints(); segMini:SetPoint("RIGHT", closeB, "LEFT", -4, 0)
  segFull:ClearAllPoints(); segFull:SetPoint("RIGHT", segMini, "LEFT", -4, 0)
  gearB:ClearAllPoints(); gearB:SetPoint("RIGHT", segFull, "LEFT", -4, 0)
  segFull:Paint(); segMini:Paint(); closeB:Paint()
  Backdrop(gearB, { 0, 0, 0, 0 }, C.line)
  gearB.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
end

local function LayoutChrome(mini)
  for _, w in ipairs(fullOnly) do if mini then w:Hide() else w:Show() end end
  for _, t in ipairs(tabs) do t:Hide() end
  tabLine:SetShown(not mini)
  segFull:SetActive(not mini)
  segMini:SetActive(mini)
  segFull:SetWidth(mini and 42 or 50)
  segMini:SetWidth(mini and 36 or 42)
  closeB:SetSize(mini and 22 or 24, mini and 22 or 24)
  LV.HeaderStyle(mini)
  rangeFS:SetShown(not mini)
  LeelFont(zoneFS, mini and 13 or 16, "")
  zoneFS:ClearAllPoints()
  if not LV.brandFS then
    LV.brandFS = FS(f, 11, C.faint)
    LV.brandFS:SetPoint("TOPLEFT", PAD, -17)
    LV.brandFS:SetText("|cfff2b3c2Leel|r |cfff6ece8Guide|r")
  end
  LV.isMini = mini
  if not LV.mascot then
    LV.mascot = f:CreateTexture(nil, "ARTWORK")
    LV.mascot:SetSize(28, 28)
    LV.mascot:SetPoint("TOPLEFT", PAD - 4, -7)
    LV.mascot:SetTexture("Interface\\AddOns\\ForgLeveling\\media\\mascot")
  end
  LV.mascot:Hide()
  LV.brandFS:ClearAllPoints()
  -- 머리 버튼(높이 22, 위 -10)과 세로 가운데를 맞춤. 좁은 간략 창은 짧게
  if not LV.logo then
    LV.logo = f:CreateTexture(nil, "ARTWORK")
    LV.logo:SetSize(20, 20)
    LV.logo:SetTexture("Interface\\AddOns\\ForgLeveling\\media\\logo")
  end
  LV.logo:ClearAllPoints()
  LV.logo:SetPoint("LEFT", f, "TOPLEFT", PAD - 2, -21)
  LV.logo:SetShown(mini)
  LV.brandFS:SetPoint("LEFT", f, "TOPLEFT", PAD + 22, -21)
  -- 이름: 르엘 UI HUD 숫자와 같은 Barlow 기울임 굵은 글꼴 (없으면 기본 글꼴)
  if not LV.brandFS:SetFont("Interface\\AddOns\\ForgLeveling\\media\\BarlowCondensed-ExtraBoldItalic.ttf", 16, "") then
    LeelFont(LV.brandFS, 13, "")
  end
  LV.brandFS:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  LV.brandFS.__c = C.accent
  LV.brandFS:SetText("|cfff2b3c2Leel|r |cfff6ece8Guide|r")   -- Leel 분홍 + Guide 크림
  LV.brandFS:SetShown(mini)
  if mini then
    -- 간략 보기: 위 줄은 버튼, 둘째 줄에 지역·단계 이름을 넓게 (잘리지 않게)
    zoneFS:SetPoint("TOPLEFT", PAD, -40)
    zoneFS:SetWidth(MINI_W - 2 * PAD - 44)
  else
    zoneFS:SetPoint("TOPLEFT", PAD, -14)
    zoneFS:SetWidth(0)
  end

  local barTop = mini and -60 or -84
  barBG:ClearAllPoints()
  progFS:ClearAllPoints()
  if mini then
    progFS:Show()
    progFS:SetPoint("TOPRIGHT", -PAD, -41)
    barBG:SetPoint("TOPLEFT", PAD, barTop)
    barBG:SetPoint("RIGHT", -PAD, 0)
  else
    progFS:Show()
    progFS:SetPoint("TOPRIGHT", -PAD, barTop + 6)
    barBG:SetPoint("TOPLEFT", PAD, barTop)
    barBG:SetPoint("RIGHT", progFS, "LEFT", -10, 0)
  end

  scroll:ClearAllPoints()
  if mini then
    scroll:Hide()
    thumb:Hide()
  else
    scroll:Show()
    tabLine:ClearAllPoints()
    tabLine:SetPoint("TOPLEFT", 0, -128)
    tabLine:SetPoint("TOPRIGHT", 0, -128)
    footLine:ClearAllPoints()
    footLine:SetPoint("BOTTOMLEFT", 0, 52)
    footLine:SetPoint("BOTTOMRIGHT", 0, 52)
    footFS:ClearAllPoints()
    footFS:SetPoint("TOPLEFT", footLine, "BOTTOMLEFT", PAD, -10)
    footFS:SetPoint("RIGHT", -PAD, 0)
    scroll:SetPoint("TOPLEFT", PAD, -132)
    scroll:SetPoint("BOTTOMRIGHT", -PAD, 56)
  end
end

local Route -- 아래 간략 보기 쪽에서 채움 (두 보기가 같은 경로를 씀)
local HuntPos -- 사냥 위치 (게임이 알려 주는 곳, 또는 지난번 진행한 곳)

local function RenderFull(b, log, lv)
  CW = FULL_W - 2 * PAD
  content:SetWidth(CW)
  f:SetSize(FULL_W, FULL_H)
  rangeFS:SetText(("Lv %d-%d"):format(b.min, b.max))
  stepB:SetText(("구간 %d / %d"):format(current, #D.brackets))
  lvB:SetText("내 레벨 " .. lv)
  sortB:SetText(DB.sort == "guide" and "따라하기" or DB.sort == "plan" and "계획" or DB.sort == "route" and "경로순" or DB.sort == "hub" and "거점순" or "레벨순")
  sortB:SetActive(DB.sort ~= "level")
  hideB:SetActive(DB.hideDone)

  -- 구간 전체 진행
  local tDone, tAll = 0, 0
  local zstat = {}
  for zi, z in ipairs(b.zones) do
    local d = 0
    for _, q in ipairs(z.quests) do if QuestState(q, log) == 3 then d = d + 1 end end
    zstat[zi] = d
    tDone, tAll = tDone + d, tAll + #z.quests
  end
  progFS:SetText(col("muted", "완료 ") .. col("text", tostring(tDone)) .. col("muted", " / " .. tAll))
  local bw = FULL_W - 2 * PAD - ((progFS:GetStringWidth() or 60) + 10)
  barFill:SetWidth(math.max(1, bw * (tAll > 0 and tDone / tAll or 0)))

  -- 탭: 지역들 + 내 퀘스트
  local ntab = #b.zones + 1
  if tabAuto then
    local pz = PlayerZone()
    tab = 1
    for zi, z in ipairs(b.zones) do if z.name == pz then tab = zi end end
  end
  if tab > ntab then tab = 1 end
  zoneFS:SetText(tab == ntab and "내 퀘스트" or b.zones[tab].name)
  local x = PAD - 8
  for i = 1, ntab do
    local t = GetTab(i)
    local isMy = i == ntab
    t.name:SetText(isMy and "내 퀘스트" or b.zones[i].name)
    t.cnt:SetText(isMy and tostring(#logList) or (zstat[i] .. "/" .. #b.zones[i].quests))
    local w = (t.name:GetStringWidth() or 60) + (t.cnt:GetStringWidth() or 20) + 22
    t:SetWidth(w)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", x, -98)
    x = x + w + 2
    local on = i == tab
    t.under:SetShown(on)
    local c = on and C.text or C.muted
    t.name:SetTextColor(c[1], c[2], c[3])
    t:SetScript("OnClick", function() tab = i; tabAuto = false; scroll:SetVerticalScroll(0); Render() end)
    t:Show()
  end

  if tab == ntab then
    -- 내 퀘스트: 반납할 것 → 진행 중, 레벨순
    local list = {}
    for _, e in ipairs(logList) do list[#list + 1] = e end
    table.sort(list, function(a, c)
      if a.state ~= c.state then return a.state > c.state end
      return (a.level or 0) < (c.level or 0)
    end)
    if #list == 0 then
      AddLabel("퀘스트 로그가 비어 있어요.", 10, 12, C.muted)
    end
    local lastSt
    for _, e in ipairs(list) do
      if e.state ~= lastSt then
        AddLabel(e.state == 2 and "반납할 것" or "진행 중", lastSt and 10 or 6, 11, C.muted)
        lastSt = e.state
      end
      local q, zn = GuideFor(e.key, b)
      AddQuest({ name = e.title, level = e.level or (q and q[1]), state = e.state, q = q, e = e,
                 zone = zn, right = Coord(q), npc = zn })
      if e.state == 1 then AddObjectives(e, 48) end
    end
  else
    local z = b.zones[tab]
    if tab == 1 and b.tips then
      for _, t in ipairs(b.tips) do AddLabel(t, 4, 11, C.faint) end
      y = y + 4
    end
    if DB.sort == "route" or DB.sort == "plan" then
      local steps, isHere = Route(b, log, lv, tab)
      local inRoute = {}
      if not isHere then
        AddLabel(col("faint", "지금 이 지역에 있지 않아서 거리 대신 거점 순서로 이었어요."), 2, 10, C.faint)
      end
      for i, st in ipairs(steps) do
        local head = col(i == 1 and "accent" or "text", i .. "단계") .. "   " .. col("text", st.titleText)
        if st.x then head = head .. "   " .. col("faint", ("%.1f, %.1f"):format(st.x, st.y)) end
        if st.zone and st.zone ~= z.name and st.kind ~= "hunt" then head = head .. "   " .. col("muted", st.zone) end
        AddLabel(head, i == 1 and 4 or 12, 11, C.text)
        if st.kind == "hunt" then
          inRoute[st.key] = true
          local e = logByKey[st.key] or st.e
          local q = st.q
          AddQuest({ level = (e and e.level) or (q and q[1]), name = st.title, state = 1, q = q, e = e,
                     zone = st.zone, right = Coord(q) })
          AddObjectives(e, 48)
        else
          for _, a in ipairs(st.acts) do
            inRoute[a.key] = true
            local q = a.q
            local stt = a.kind == "turn" and 2 or QuestState(q or {}, log)
            AddQuest({ wp = a.x and { map = a.map or D.maps[a.zone or st.zone], x = a.x, y = a.y, title = a.title } or nil,
                       level = (q and q[1]) or a.level, name = a.title, state = stt, q = q, e = logByKey[a.key],
                       zone = st.zone, right = a.x and ("%.1f, %.1f"):format(a.x, a.y) or Coord(q) })
          end
        end
      end
      -- 경로에 안 들어간 나머지 (레벨이 높거나 위치를 모르는 것)
      local others = {}
      for _, q in ipairs(SortedQuests(z)) do
        local st = QuestState(q, log)
        if not inRoute[q.key] and not (DB.hideDone and st == 3) then others[#others + 1] = { q = q, st = st } end
      end
      if #others > 0 then
        AddLabel(col("muted", "그 밖의 퀘스트") .. "   " .. col("faint", "레벨이 높거나, 게시판·아이템으로 시작하거나, 이미 끝낸 것"), 14, 11, C.muted)
        for _, o in ipairs(others) do
          local q = o.q
          local npc = q[3] and (q[3] .. (q[6] and (" @" .. q[6]) or "")) or nil
          AddQuest({ level = q[1], name = q[2], npc = npc, right = Coord(q), state = o.st, q = q,
                     e = logByKey[q.key], zone = z.name })
          if o.st == 1 then AddObjectives(logByKey[q.key], 48) end
        end
      end
    end
    local list = (DB.sort == "route" or DB.sort == "plan") and {} or SortedQuests(z)
    local lastHub = false
    for i, q in ipairs(list) do
      local st = QuestState(q, log)
      if not (DB.hideDone and st == 3) then
        if DB.sort == "hub" and q.hub ~= lastHub then
          AddLabel(q.hub and (col("text", "거점 " .. q.hub)) or col("text", "거점 없음") .. col("faint", "  게시판, 아이템으로 시작"),
            lastHub == false and 4 or 10, 11, C.text)
          lastHub = q.hub
        end
        local npc = q[3] and (q[3] .. (q[6] and (" @" .. q[6]) or "")) or nil
        AddQuest({ num = i, level = q[1], name = q[2], npc = npc, right = Coord(q), state = st, q = q,
                   e = logByKey[q.key], zone = z.name })
        if st == 1 then AddObjectives(logByKey[q.key], 48) end
      end
    end
  end

  -- 던전
  if b.dungeons and #b.dungeons > 0 then
    local parts = {}
    for _, d in ipairs(b.dungeons) do parts[#parts + 1] = col("faint", tostring(d[1])) .. " " .. col("text", d[2]) end
    footFS:SetText(col("muted", "레벨 맞는 던전") .. "     " .. table.concat(parts, "     "))
  else
    footFS:SetText(col("faint", "이 구간에 맞는 던전 없음"))
  end
end

---------------------------------------------------------------------------
-- 간략 보기: "지금 할 일" 카드 (들를 곳을 묶어 가까운 순으로)
---------------------------------------------------------------------------
local atan2 = math.atan2 or math.atan
local DIRS = { "동", "북동", "북", "북서", "서", "남서", "남", "남동" }

local function PlayerPos()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
  local ok, x, yy = pcall(function()
    local m = C_Map.GetBestMapForUnit("player")
    if not m then return end
    local p = C_Map.GetPlayerMapPosition(m, "player")
    if not p then return end
    local px, py = p:GetXY()
    return px * 100, py * 100
  end)
  if ok and x and yy and (x > 0 or yy > 0) then return x, yy end
end

local function Dist(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return math.sqrt(dx * dx + dy * dy) end

local function Direction(px, py, x, yy)
  if not px then return nil end
  local d = Dist(px, py, x, yy)
  if d < 2.5 then return "바로 근처예요" end
  local a = math.deg(atan2(py - yy, x - px)) % 360
  local i = math.floor(((a + 22.5) % 360) / 45) + 1
  return "지금 위치에서 " .. DIRS[i] .. "쪽"
end

-- 사냥 위치 -------------------------------------------------------------
local function ZoneOfMap(m)
  if not m then return nil end
  for name, id in pairs(D.maps) do if id == m then return name end end
  if C_Map and C_Map.GetMapInfo then
    local ok, info = pcall(C_Map.GetMapInfo, m)
    if ok and info and info.name then return info.name end
  end
end

ApiObjectivePos = function(id)
  if not id then return end
  local m
  if C_Map and C_Map.GetBestMapForUnit then
    local ok, r = pcall(C_Map.GetBestMapForUnit, "player"); if ok then m = r end
  end
  if m and C_QuestLog and C_QuestLog.GetQuestsOnMap then
    local ok, list = pcall(C_QuestLog.GetQuestsOnMap, m)
    if ok and type(list) == "table" then
      for _, info in ipairs(list) do
        if info.questID == id and info.x and info.y and (info.x > 0 or info.y > 0) then
          return m, info.x * 100, info.y * 100
        end
      end
    end
  end
  if QuestPOIGetIconInfo then
    local ok, _, x, yy = pcall(QuestPOIGetIconInfo, id)
    if ok and x and yy and (x > 0 or yy > 0) then return m, x * 100, yy * 100 end
  end
end

-- 반환: zone, x, y, 출처("game" / "learned")
HuntPos = function(key, id, e)
  -- 와우 포에버는 게임 퀘스트 위치(POI)가 엉뚱한 곳을 줄 때가 있어 Questie 목표 위치를 먼저 씀
  if e and e.id and LV.QObjPos then
    local qm, qx, qy, qn = LV.QObjPos(e)
    if qx then return ZoneOfMap(qm) or PlayerZone(), qx, qy, "questie", qm, qn end
  end
  local m, x, yy = ApiObjectivePos(id)
  if x then return ZoneOfMap(m) or PlayerZone(), x, yy, "game", m end
  local L = DB and DB.learned and DB.learned[key]
  if L then return L.zone, L.x, L.y, "learned", L.map end
end

-- 목표 숫자가 오를 때 서 있던 곳을 기억 (계정 공통)
local lastSum = {}
local function LearnProgress()
  if not DB then return end
  DB.learned = DB.learned or {}
  local px, py = PlayerPos()
  local m
  if C_Map and C_Map.GetBestMapForUnit then
    local ok, r = pcall(C_Map.GetBestMapForUnit, "player"); if ok then m = r end
  end
  for _, e in ipairs(logList) do
    local sum = 0
    for _, o in ipairs(e.objs or {}) do sum = sum + (o.have or (o.done and 1 or 0)) end
    local prev = lastSum[e.key]
    if prev and sum > prev and CDB then
      -- 지금 잡고 있는 퀘스트: 이 사냥 단계를 맨 앞에 보여 줌
      CDB.activeHunt = { key = e.key, id = e.id, t = time and time() or 0 }
    end
    if prev and sum > prev and px then
      local L = DB.learned[e.key]
      local zone = PlayerZone()
      if L and L.zone == zone and L.n then
        -- 여러 번 진행한 곳의 평균
        local n = math.min(L.n, 9)
        L.x = (L.x * n + px) / (n + 1)
        L.y = (L.y * n + py) / (n + 1)
        L.n = L.n + 1
      else
        DB.learned[e.key] = { zone = zone, x = px, y = py, n = 1, map = m }
      end
    end
    lastSum[e.key] = sum
  end
end

-- "북동쪽 · 가까움"
local function DirShort(px, py, x, yy)
  if not px then return nil end
  local d = Dist(px, py, x, yy)
  if d < 2.5 then return C.__cute and "바로 앞이에요" or "바로 근처" end
  local a = math.deg(atan2(py - yy, x - px)) % 360
  local i = math.floor(((a + 22.5) % 360) / 45) + 1
  local feel = C.__cute and (d < 10 and "가까워요" or d < 25 and "조금 멀어요" or "멀어요")
               or (d < 10 and "가까움" or d < 25 and "보통" or "멀리")
  return DIRS[i] .. "쪽 · " .. feel
end

local snap -- 지금 단계 (끝날 때까지 고정)
local wpFollow -- 웨이포인트를 찍은 단계 (할 일이 끝나면 다음 위치로 옮김)

---------------------------------------------------------------------------
-- Questie 정보 (설치돼 있으면): 받을 수 있는 퀘스트, 반납 NPC 위치
---------------------------------------------------------------------------
local QCache -- { avail = {[qid]=info}, comp = {[qid]=info} } 또는 false
local questieAnnounced = false

local function ReadQuestie()
  local QL = _G.QuestieLoader
  if not (QL and QL.ImportModule) then return false end
  local ok, QM = pcall(QL.ImportModule, QL, "QuestieMap")
  if not ok or type(QM) ~= "table" or type(QM.questIdFrames) ~= "table" then return false end
  local avail, comp, obj = {}, {}, {}
  local n = 0
  for qid, frames in pairs(QM.questIdFrames) do
    if type(frames) == "table" then
      for _, fname in pairs(frames) do
        local fr = type(fname) == "string" and _G[fname] or fname
        local d = type(fr) == "table" and fr.data
        if type(d) == "table" and fr.x and fr.y and fr.UiMapID and (d.Type == "available" or d.Type == "complete") then
          local qd = type(d.QuestData) == "table" and d.QuestData or {}
          local list = d.Type == "available" and avail or comp
          local info = list[qid]
          if not info then
            info = { qid = qid, title = qd.name, level = tonumber(qd.level), req = tonumber(qd.requiredLevel), pts = {} }
            list[qid] = info
          end
          info.pts[#info.pts + 1] = { map = fr.UiMapID, x = fr.x, y = fr.y, npc = d.Name }
          n = n + 1
        end
      end
    end
  end
  if n == 0 then return false end
  if not questieAnnounced then
    questieAnnounced = true
    Print("Questie 정보로 경로를 짜요 (경로순일 때). 받기와 반납 위치를 Questie에서 가져와요.")
  end
  return { avail = avail, comp = comp, obj = obj }
end

-- 설정: 던전/그룹 퀘스트 넘기기
local excludeCache = {}
LV.repCache = {}
function LV.IsRepeatQ(qid)
  local c = LV.repCache[qid]
  if c ~= nil then return c end
  c = false
  local QL = _G.QuestieLoader
  local ok, QDB = false, nil
  if QL and QL.ImportModule then ok, QDB = pcall(QL.ImportModule, QL, "QuestieDB") end
  if ok and type(QDB) == "table" then
    for _, fn in ipairs({ "IsRepeatable", "IsDailyQuest", "IsWeeklyQuest" }) do
      local f = QDB[fn]
      if type(f) == "function" then
        local ok2, r = pcall(f, qid)
        if ok2 and r then c = true; break end
      end
    end
  end
  LV.repCache[qid] = c
  return c
end

local function IsExcludedQuest(qid, inLog)
  if not qid or not DB then return false end
  -- 반복·일일·주간 퀘스트(지도에 파란색)는 받기 추천에서 뺌. 이미 받은 건 그대로 안내
  if not inLog and DB.skipRepeat ~= false and LV.IsRepeatQ(qid) then return true end
  if not DB.skipDungeon and not DB.skipGroup then return false end
  local c = excludeCache[qid]
  if c == nil then
    c = { dungeon = false, group = false }
    local QL = _G.QuestieLoader
    local QDB
    if QL and QL.ImportModule then
      local ok, m = pcall(QL.ImportModule, QL, "QuestieDB"); if ok then QDB = m end
    end
    local function ask(fname)
      local fn = QDB and QDB[fname]
      if type(fn) ~= "function" then return nil end
      local ok, r = pcall(fn, qid)
      if ok and r ~= nil then return r and true or false end
      ok, r = pcall(fn, QDB, qid)
      if ok and r ~= nil then return r and true or false end
    end
    c.dungeon = ask("IsDungeonQuest") or false
    c.group = ask("IsGroupQuest") or false
    -- 게임 퀘스트 태그도 확인 (퀘스트 로그에 있는 경우)
    local tagf = (C_QuestLog and C_QuestLog.GetQuestTagInfo) or GetQuestTagInfo
    if tagf then
      local ok, info = pcall(tagf, qid)
      local tid = ok and (type(info) == "table" and info.tagID or info) or nil
      if tid == 81 or tid == 62 then c.dungeon = true end
      if tid == 1 then c.group = true end
    end
    excludeCache[qid] = c
  end
  return (DB.skipDungeon and c.dungeon) or (DB.skipGroup and c.group) or false
end

local function PlayerMapID()
  if C_Map and C_Map.GetBestMapForUnit then
    local ok, r = pcall(C_Map.GetBestMapForUnit, "player"); if ok then return r end
  end
end

-- 여러 위치 중 지금 지도에 있는 것, 그중 가장 가까운 것
local function BestPoint(pts, m, px, py)
  local best, bd
  for _, p in ipairs(pts) do
    if not m or p.map == m then
      local d = (px and Dist(px, py, p.x, p.y)) or 0
      if not best or d < bd then best, bd = p, d end
    end
  end
  return best
end

-- 할 일을 하러 갈 위치. 반납은 Questie 반납 NPC → 게임 지도 표시 → 사이트 데이터 순
local function MakeAct(kind, q, e, title, defaultZone, n)
  local a = { kind = kind, q = q, e = e, key = (q and q.key) or (e and e.key), title = title or (q and q[2]) or (e and e.title), n = n }
  if kind == "turn" and e and e.id and QCache and QCache.comp[e.id] then
    local m = PlayerMapID()
    local px, py = PlayerPos()
    local p = BestPoint(QCache.comp[e.id].pts, m, px, py) or QCache.comp[e.id].pts[1]
    if p then
      a.x, a.y, a.map, a.npc = p.x, p.y, p.map, p.npc
      a.zone = ZoneOfMap(p.map) or PlayerZone()
      return a
    end
  end
  if kind == "turn" and e and e.id then
    local m, x, yy = ApiObjectivePos(e.id)
    if x then
      a.x, a.y, a.map = x, yy, m
      a.zone = ZoneOfMap(m) or PlayerZone()
      a.fromGame = true
      return a
    end
  end
  if q and q[4] then
    a.x, a.y, a.zone, a.npc = q[4], q[5], q[6] or defaultZone, q[3]
  end
  return a
end

-- Questie가 지금 지도에 "받을 수 있다"고 표시한 퀘스트
local function QuestieGets(log, lv, zoneName)
  local out = {}
  if not QCache then return out end
  local m = PlayerMapID()
  local px, py = PlayerPos()
  for qid, info in pairs(QCache.avail) do
    local p = BestPoint(info.pts, m, px, py)
    local title = info.title
    if p and title then
      local key = Norm(title)
      local lvq = info.level or 0
      local okLevel = (lvq == 0 or (lvq <= lv + 2 and (lvq >= lv - 6 or not LV.IsGrey(lvq)))) and (not info.req or info.req <= lv)
      if LV.SkipGrey() and LV.IsGrey(lvq) then okLevel = false end
      if okLevel and not log[key] and not CDB.done[key] and CDB.manual[key] ~= true and not IsSkipped(key, log) and not IsExcludedQuest(qid) then
        out[#out + 1] = { kind = "get", key = key, title = title, level = lvq > 0 and lvq or nil, qid = qid,
                          x = p.x, y = p.y, map = p.map, zone = zoneName, npc = p.npc, fromQuestie = true }
      end
    end
  end
  table.sort(out, function(a, b) return (a.level or 0) < (b.level or 0) end)
  return out
end


---------------------------------------------------------------------------
-- 루트 만들기: 지금 지역의 퀘스트를 모두 읽어 레벨 → 위치 순으로 고정 루트 생성
---------------------------------------------------------------------------
local function QModule(name)
  local QL = _G.QuestieLoader
  if not (QL and QL.ImportModule) then return end
  local ok, m = pcall(QL.ImportModule, QL, name)
  if ok and type(m) == "table" then return m end
end

local function QQuery(kind, id, key)
  local QDB = QModule("QuestieDB")
  if not QDB then return end
  local fn = QDB["Query" .. kind .. "Single"]
  if type(fn) ~= "function" then return end
  local ok, r = pcall(fn, id, key)
  if ok and r ~= nil then return r end
  ok, r = pcall(fn, QDB, id, key)
  if ok then return r end
end

local areaMapCache = {}
local function AreaToMap(areaId)
  if areaMapCache[areaId] ~= nil then return areaMapCache[areaId] end
  local ZDB = QModule("ZoneDB")
  local r = false
  if ZDB and type(ZDB.GetUiMapIdByAreaId) == "function" then
    local ok, v = pcall(ZDB.GetUiMapIdByAreaId, ZDB, areaId)
    if ok and v then r = v else
      ok, v = pcall(ZDB.GetUiMapIdByAreaId, areaId)
      if ok and v then r = v end
    end
  end
  areaMapCache[areaId] = r
  return r
end

local function SpawnsOnMap(spawns, m, out)
  if type(spawns) ~= "table" then return end
  for areaId, list in pairs(spawns) do
    if type(list) == "table" and AreaToMap(areaId) == m then
      for _, p in ipairs(list) do
        if type(p) == "table" and tonumber(p[1]) and p[1] > 0 then out[#out + 1] = { p[1], p[2] } end
      end
    end
  end
end

-- 가장 많이 모인 곳의 중심
local function Cluster(points)
  if #points == 0 then return end
  local cells, bestK, bestN = {}, nil, 0
  for _, p in ipairs(points) do
    local k = math.floor(p[1] / 10) * 100 + math.floor(p[2] / 10)
    cells[k] = (cells[k] or 0) + 1
    if cells[k] > bestN then bestK, bestN = k, cells[k] end
  end
  local cx, cy = math.floor(bestK / 100), bestK % 100
  local sx, sy, n = 0, 0, 0
  for _, p in ipairs(points) do
    local gx, gy = math.floor(p[1] / 10), math.floor(p[2] / 10)
    if math.abs(gx - cx) <= 1 and math.abs(gy - cy) <= 1 then sx, sy, n = sx + p[1], sy + p[2], n + 1 end
  end
  if n == 0 then return end
  return sx / n, sy / n
end

local function IdList(list)
  local r = {}
  if type(list) == "table" then
    for _, o in ipairs(list) do
      if type(o) == "table" then r[#r + 1] = o[1] elseif type(o) == "number" then r[#r + 1] = o end
    end
  end
  return r
end

-- 수행 지역 (몬스터, 오브젝트, 아이템 드랍). 반환: x, y, 목표가 있는지
local function ObjectiveArea(qid, m)
  local objs = QQuery("Quest", qid, "objectives")
  if type(objs) ~= "table" then return nil, nil, nil end
  local pts, any = {}, false
  for _, id in ipairs(IdList(objs[1])) do any = true; SpawnsOnMap(QQuery("NPC", id, "spawns"), m, pts) end
  for _, id in ipairs(IdList(objs[2])) do any = true; SpawnsOnMap(QQuery("Object", id, "spawns"), m, pts) end
  for _, id in ipairs(IdList(objs[3])) do
    any = true
    for _, n in ipairs(IdList(QQuery("Item", id, "npcDrops"))) do SpawnsOnMap(QQuery("NPC", n, "spawns"), m, pts) end
    for _, o in ipairs(IdList(QQuery("Item", id, "objectDrops"))) do SpawnsOnMap(QQuery("Object", o, "spawns"), m, pts) end
  end
  if type(objs[5]) == "table" then
    for _, kc in ipairs(objs[5]) do
      if type(kc) == "table" and type(kc[1]) == "table" then
        any = true
        for _, n in ipairs(kc[1]) do SpawnsOnMap(QQuery("NPC", n, "spawns"), m, pts) end
      end
    end
  end
  local x, y = Cluster(pts)
  return x, y, any
end

local function NpcPoint(ids, m, px, py, anyMap)
  local best
  for _, n in ipairs(IdList(ids)) do
    local pts = {}
    SpawnsOnMap(QQuery("NPC", n, "spawns"), m, pts)
    for _, p in ipairs(pts) do
      local d = px and Dist(px, py, p[1], p[2]) or 0
      if not best or d < best.d then best = { x = p[1], y = p[2], d = d, npc = QQuery("NPC", n, "name"), map = m } end
    end
  end
  if best or not anyMap then return best end
  -- 지금 지도에 없으면 다른 지역에서 찾기
  for _, n in ipairs(IdList(ids)) do
    local spawns = QQuery("NPC", n, "spawns")
    if type(spawns) == "table" then
      for areaId, list in pairs(spawns) do
        local um = AreaToMap(areaId)
        if um and type(list) == "table" and type(list[1]) == "table" and tonumber(list[1][1]) then
          return { x = list[1][1], y = list[1][2], d = 999, npc = QQuery("NPC", n, "name"), map = um, away = true }
        end
      end
    end
  end
end

local function FinisherPoint(qid, m, px, py)
  local fb = QQuery("Quest", qid, "finishedBy")
  if type(fb) ~= "table" then return end
  return NpcPoint(fb[1], m, px, py, true)
end

local function BuildPlan(quiet)
  local m = PlayerMapID()
  local pz = PlayerZone()
  local lv = UnitLevel("player") or 1
  local px, py = PlayerPos()
  local log = ReadQuestLog()
  QCache = ReadQuestie()
  if not m then Print("지금 위치의 지도를 읽을 수 없어요."); return end

  local quests = {}
  local function addQuest(q) quests[#quests + 1] = q end
  -- 호위 퀘스트: 받자마자 바로 해야 함 (NPC가 출발하면 기다려 주지 않음)
  local ESC = { "호위", "escort", "보호하", "데려다", "구출" }
  local function hasEsc(t)
    if type(t) ~= "string" then return false end
    local l = t:lower()
    for _, w in ipairs(ESC) do if l:find(w, 1, true) then return true end end
    return false
  end
  -- 회색 퀘스트라도 다음 편이 회색이 아니면 연계를 위해 남김
  local skipGrey = LV.SkipGrey()
  local nGrey = 0
  local function GreyDrop(qid, level)
    if not skipGrey or not LV.IsGrey(level) then return false end
    local n = QQuery("Quest", qid, "nextQuestInChain")
    if type(n) == "table" then n = n[1] end
    n = tonumber(n)
    if n and n > 0 then
      local nl = tonumber(QQuery("Quest", n, "questLevel") or QQuery("Quest", n, "level"))
      if nl and not LV.IsGrey(nl) then return false end
    end
    return true
  end
  local function IsEscort(qid, e)
    if e then
      for _, o in ipairs(e.objs or {}) do if hasEsc(o.text) and not (o.need and o.need > 1) then return true end end
    end
    local ot = QQuery("Quest", qid, "objectivesText")
    if type(ot) == "table" then for _, t in ipairs(ot) do if hasEsc(t) then return true end end
    elseif hasEsc(ot) then return true end
    return false
  end

  -- 1) 이미 가진 퀘스트
  for _, e in ipairs(logList) do
    -- 회색: 진행 중이면 빼고, 목표를 끝낸 건 반납만 남김
    local greyOut = e.id and e.state ~= 2 and GreyDrop(e.id, e.level)
    if greyOut then nGrey = nGrey + 1 end
    if e.id and not greyOut and not IsSkipped(e.key, log) and not IsExcludedQuest(e.id, true) then
      local q = { qid = e.id, key = e.key, title = e.title, level = e.level or 0, inLog = true, state = e.state, tasks = {} }
      if e.state == 1 and (IsEscort(e.id, e) or (hasEsc(e.title) and not (e.objs and e.objs[1] and e.objs[1].need and e.objs[1].need > 1))) then q.escort = true end
      if e.state == 1 and ((e.objs and #e.objs > 0) or q.escort) then
        local ax, ay
        if LV.QObjPos then
          local qm, qx, qy = LV.QObjPos(e)
          if qx and qm == m then ax, ay = qx, qy end
        end
        if not ax then
          local am, gx, gy = ApiObjectivePos(e.id)
          if gx and am == m then ax, ay = gx, gy end
        end
        if not ax then ax, ay = ObjectiveArea(e.id, m) end
        -- 위치 정보가 없으면 내가 진행했던 곳을 씀
        local L = not ax and DB.learned and DB.learned[e.key]
        if L and (not L.map or L.map == m) then ax, ay = L.x, L.y end
        q.tasks[#q.tasks + 1] = { kind = "do", x = ax, y = ay }
      end
      local tp
      if QCache and QCache.comp[e.id] then
        local pts = QCache.comp[e.id].pts
        local p = BestPoint(pts, m, px, py) or pts[1]
        if p then tp = { x = p.x, y = p.y, npc = p.npc, map = p.map } end
      end
      if not tp then tp = FinisherPoint(e.id, m, px, py) end
      q.tasks[#q.tasks + 1] = { kind = "turn", x = tp and tp.x, y = tp and tp.y, npc = tp and tp.npc, map = tp and tp.map }
      addQuest(q)
    end
  end

  -- 2) 받을 수 있는 퀘스트 (Questie)
  local nAvail = 0
  if QCache then
    for qid, info in pairs(QCache.avail) do
      local p = BestPoint(info.pts, m, px, py)
      local title = info.title
      if p and title then
        local key = Norm(title)
        local lq = info.level or 0
        local okLevel = (lq == 0 or (lq <= lv + 3 and (lq >= lv - 6 or not LV.IsGrey(lq)))) and (not info.req or info.req <= lv)
        if okLevel and GreyDrop(qid, lq) then okLevel = false end
        if okLevel and not log[key] and not CDB.done[key] and CDB.manual[key] ~= true and not IsSkipped(key, log) and not IsExcludedQuest(qid) then
          local q = { qid = qid, key = key, title = title, level = lq, tasks = {} }
          if IsEscort(qid) then q.escort = true end
          q.tasks[#q.tasks + 1] = { kind = "get", x = p.x, y = p.y, npc = p.npc }
          local ox, oy, hasObj = ObjectiveArea(qid, m)
          if hasObj ~= false then q.tasks[#q.tasks + 1] = { kind = "do", x = ox, y = oy } end
          local tp = FinisherPoint(qid, m, p.x, p.y)
          q.tasks[#q.tasks + 1] = { kind = "turn", x = tp and tp.x, y = tp and tp.y, npc = tp and tp.npc, map = tp and tp.map }
          addQuest(q)
          nAvail = nAvail + 1
        end
      end
    end
  end
  -- 3) 연계 퀘스트 미리 넣기 (최대 3편)
  local inPlan = {}
  for _, q in ipairs(quests) do inPlan[q.qid] = true end
  local nChain = 0
  local function NextOf(qid)
    local n = QQuery("Quest", qid, "nextQuestInChain")
    if type(n) == "table" then n = n[1] end
    n = tonumber(n)
    if n and n > 0 then return n end
  end
  local base = {}
  for _, q in ipairs(quests) do base[#base + 1] = q end
  for _, q in ipairs(base) do
    local prev = q
    for depth = 1, 3 do
      local nid = NextOf(prev.qid)
      if not nid or inPlan[nid] or QuestIdDone(nid) then break end
      local title = QQuery("Quest", nid, "name")
      local lq = tonumber(QQuery("Quest", nid, "questLevel") or QQuery("Quest", nid, "level")) or prev.level
      local rq = tonumber(QQuery("Quest", nid, "requiredLevel")) or 0
      if not title or lq > lv + 4 or rq > lv + 2 or IsExcludedQuest(nid) or GreyDrop(nid, lq) then break end
      -- 받는 곳: 앞 편 반납 위치 근처의 시작 NPC
      local lastT = prev.tasks[#prev.tasks]
      local sb = QQuery("Quest", nid, "startedBy")
      local sp = type(sb) == "table" and NpcPoint(sb[1], m, lastT and lastT.x, lastT and lastT.y) or nil
      if not sp and lastT and lastT.x and (not lastT.map or lastT.map == m) then sp = { x = lastT.x, y = lastT.y, npc = lastT.npc } end
      if not sp then break end
      local key = Norm(title)
      local cq = { qid = nid, key = key, title = title, level = lq, tasks = {}, after = prev, chain = depth + (prev.chain or 0) }
      cq.tasks[#cq.tasks + 1] = { kind = "get", x = sp.x, y = sp.y, npc = sp.npc }
      local ox, oy, hasObj = ObjectiveArea(nid, m)
      if hasObj ~= false then cq.tasks[#cq.tasks + 1] = { kind = "do", x = ox, y = oy } end
      local tp = FinisherPoint(nid, m, sp.x, sp.y)
      cq.tasks[#cq.tasks + 1] = { kind = "turn", x = tp and tp.x, y = tp and tp.y, npc = tp and tp.npc, map = tp and tp.map }
      addQuest(cq)
      inPlan[nid] = true
      nChain = nChain + 1
      prev = cq
    end
  end

  if #quests == 0 then
    if not quiet then Print("이 지역에서 할 퀘스트를 찾지 못했어요.") end
    CDB.plan = { map = m, zone = pz, tasks = {}, made = time and time() or 0 }
    DB.sort = "plan"
    return 0
  end

  -- 4) 순서용 레벨: 내 레벨보다 2 이상 낮은 퀘스트는 모두 같은 급으로 봄
  --    (20레벨에게 14레벨·18레벨 퀘는 둘 다 쉬우니 가까운 곳 먼저). '먼저 하기'는 맨 앞.
  CDB.prio = CDB.prio or {}
  local nPrio = 0
  for _, q in ipairs(quests) do
    local pr = CDB.prio[q.key] or (q.after and q.after.prio)
    q.prio = pr and true or nil
    if pr then nPrio = nPrio + 1 end
    q.plv = pr and -100 or math.max(q.level or 0, lv - 2)
    -- 내 레벨 +3 이상 퀘스트는 너무 어려움: 수행(사냥)은 맨 뒤로 미룸 (레벨 오르면 자동으로 다시 짬)
    q.hard = (not pr) and (q.level or 0) >= lv + 3 or nil
    if q.escort and q.inLog then q.plv = -200; q.hard = nil end
  end
  table.sort(quests, function(a, b) if a.plv ~= b.plv then return a.plv < b.plv end return a.title < b.title end)
  for _, q in ipairs(quests) do q.next = 1 end
  local order = {}
  local cx, cy = px, py
  local function ready(q) return q.tasks[q.next] and (not q.after or not q.after.tasks[q.after.next]) end
  local function push(q)
    local t = q.tasks[q.next]
    q.next = q.next + 1
    order[#order + 1] = { kind = t.kind, qid = q.qid, key = q.key, title = q.title, level = q.level,
                          x = t.x, y = t.y, npc = t.npc, approx = t.approx, chain = q.chain,
                          map = t.map, zone = t.map and t.map ~= m and ZoneOfMap(t.map) or nil, hard = q.hard }
    if t.x and (not t.map or t.map == m) then cx, cy = t.x, t.y end
  end
  local function isLocal(t) return t.x and (not t.map or t.map == m) end
  -- 어려운 퀘스트의 수행 단계 (쉬운 일이 남아 있으면 건너뜀)
  local function hardDo(q, t) return q.hard and t and t.kind == "do" end

  if DB.planMode == "level" then
    local guard = 0
    while guard < 600 do
      guard = guard + 1
      local bandMin
      local function ready(q) return q.tasks[q.next] and (not q.after or not q.after.tasks[q.after.next]) end
      local hasLocal, hasEasy = false, false
      for _, q in ipairs(quests) do
        local t = ready(q) and q.tasks[q.next]
        if t and (not t.map or t.map == m) then hasLocal = true end
        if t and not hardDo(q, t) then hasEasy = true end
      end
      -- 레벨 묶음은 지금 할 수 있는 일(다른 지역 일은 지금 지역 일이 남아 있으면 제외) 기준
      for _, q in ipairs(quests) do
        local t = ready(q) and q.tasks[q.next]
        if t and hasEasy and hardDo(q, t) then t = nil end
        if t and not (hasLocal and t.map and t.map ~= m) then bandMin = bandMin and math.min(bandMin, q.plv) or q.plv end
      end
      if not bandMin then break end
      local best, bd
      for _, q in ipairs(quests) do
        local t = ready(q) and q.tasks[q.next]
        if t and q.plv < -50 and (not best or q.plv < best.plv) then best, bd = q, -999 end
      end
      for _, q in ipairs(quests) do
        local t = ready(q) and q.tasks[q.next]
        if t and t.map and t.map ~= m and hasLocal then t = nil end
        if t and hasEasy and hardDo(q, t) then t = nil end
        if t and bd ~= -999 then
          local d = (cx and t.x) and Dist(cx, cy, t.x, t.y) or (t.x and 30 or 60)
          if t.map and t.map ~= m then d = 80 end
          -- 연계 다음 편은 앞 편 반납 직후 바로 이어서
          if q.after and t.kind == "get" and d < 4 then d = d - 3 end
          local inBand = q.plv <= bandMin + 1 or not hasLocal
          -- 다음 묶음이라도 바로 옆이면 같이 처리
          if inBand or d < 4 then
            local score = d + (q.plv - bandMin) * 0.5
            if t.kind == "turn" then score = score - 2 end
            if not best or score < bd then best, bd = q, score end
          end
        end
      end
      if not best then break end
      local t = best.tasks[best.next]
      best.next = best.next + 1
      order[#order + 1] = { kind = t.kind, qid = best.qid, key = best.key, title = best.title, level = best.level,
                            x = t.x, y = t.y, npc = t.npc, approx = t.approx, chain = best.chain,
                            map = t.map, zone = t.map and t.map ~= m and ZoneOfMap(t.map) or nil }
      if t.x and (not t.map or t.map == m) then cx, cy = t.x, t.y end
    end
  else
    -- 구역 단위: 가까운 할 일끼리 구역으로 묶고, 구역 안에서는 할 수 있는 걸 다 끝냄
    local pts = {}
    for _, q in ipairs(quests) do
      for _, t in ipairs(q.tasks) do if isLocal(t) then pts[#pts + 1] = t end end
    end
    local parent = {}
    for i = 1, #pts do parent[i] = i end
    local function find(i) while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end return i end
    local TH = 7
    for i = 1, #pts do
      for j = i + 1, #pts do
        if Dist(pts[i].x, pts[i].y, pts[j].x, pts[j].y) < TH then
          local a, b = find(i), find(j)
          if a ~= b then parent[a] = b end
        end
      end
    end
    for i, t in ipairs(pts) do t.cl = find(i) end

    local cc -- 지금 구역
    local guard = 0
    while guard < 800 do
      guard = guard + 1
      -- 0) 호위 중인 퀘스트·먼저 하기는 위치와 상관없이 바로
      local best, bd
      for _, q in ipairs(quests) do
        local t = ready(q) and q.tasks[q.next]
        if t and q.plv < -50 and (not best or q.plv < best.plv) then best = q end
      end
      -- 1) 지금 구역에서 할 수 있는 일: 가까운 순
      if cc and not best then
        for _, q in ipairs(quests) do
          local t = ready(q) and q.tasks[q.next]
          if t and t.cl == cc and not hardDo(q, t) then
            local d = cx and Dist(cx, cy, t.x, t.y) or 0
            if t.kind == "turn" then d = d - 1 end
            if not best or d < bd then best, bd = q, d end
          end
        end
      end
      if best then
        push(best)
      else
        -- 2) 다음 구역: 레벨이 가장 낮은 구역들(+2 이내) 중 가장 가까운 곳
        local clMin, clNear, clQ = {}, {}, {}
        local gMin
        for _, q in ipairs(quests) do
          local t = ready(q) and q.tasks[q.next]
          if t and t.cl and not hardDo(q, t) then
            local d = cx and Dist(cx, cy, t.x, t.y) or 0
            clMin[t.cl] = clMin[t.cl] and math.min(clMin[t.cl], q.plv) or q.plv
            if not clNear[t.cl] or d < clNear[t.cl] then clNear[t.cl], clQ[t.cl] = d, q end
            gMin = gMin and math.min(gMin, q.plv) or q.plv
          end
        end
        local pick, pd
        -- 지금 서 있는 곳 바로 옆 구역은 레벨이 조금 높아도(+4) 먼저
        for cl, lvMin in pairs(clMin) do
          if clNear[cl] < TH * 1.5 and lvMin <= gMin + 4 and (not pick or clNear[cl] < pd) then pick, pd = cl, clNear[cl] end
        end
        if not pick then
          for cl, lvMin in pairs(clMin) do
            if lvMin <= gMin + 2 and (not pick or clNear[cl] < pd) then pick, pd = cl, clNear[cl] end
          end
        end
        if pick then
          cc = pick
          push(clQ[pick])
        else
          -- 3) 위치 모르는 일 → 4) 다른 지역 일
          local q2
          for _, q in ipairs(quests) do
            local t = ready(q) and q.tasks[q.next]
            if t and not t.x and (not t.map or t.map == m) and not hardDo(q, t) and (not q2 or q.plv < q2.plv) then q2 = q end
          end
          if not q2 then
            -- 다른 지역 일 (쉬운 것 먼저), 마지막으로 어려운 퀘스트 수행
            for _, q in ipairs(quests) do
              local t = ready(q) and q.tasks[q.next]
              if t and not hardDo(q, t) and (not q2 or q.plv < q2.plv) then q2 = q end
            end
            if not q2 then
              for _, q in ipairs(quests) do
                local t = ready(q) and q.tasks[q.next]
                if t and (not q2 or q.plv < q2.plv) then q2 = q end
              end
            end
          end
          if not q2 then break end
          push(q2)
        end
      end
    end
  end

  -- 호위 퀘스트: 받기 바로 다음에 수행 (사이에 다른 일 넣지 않음)
  local escQ = {}
  for _, q in ipairs(quests) do if q.escort then escQ[q.qid] = true end end
  for qid in pairs(escQ) do
    local gi, di
    for i, t in ipairs(order) do
      if t.qid == qid and t.kind == "get" then gi = i end
      if t.qid == qid and t.kind == "do" then di = i end
    end
    if gi and di and di > gi + 1 then
      local d = table.remove(order, di)
      table.insert(order, gi + 1, d)
    end
  end
  for _, t in ipairs(order) do if escQ[t.qid] then t.escort = true end end
  CDB.plan = { map = m, zone = pz, tasks = order, made = time and time() or 0 }
  DB.sort = "plan"
  snap, wpFollow = nil, nil
  local msg = ("%s, 퀘스트 %d개 (새로 받을 것 %d개, 연계 %d개), 할 일 %d개"):format(pz, #quests, nAvail, nChain, #order)
  if nPrio > 0 then msg = msg .. (", 먼저 하기 %d개"):format(nPrio) end
  if nGrey > 0 then msg = msg .. (", 회색 퀘 %d개 뺌"):format(nGrey) end
  local nHard = 0
  for _, q in ipairs(quests) do if q.hard then nHard = nHard + 1 end end
  if nHard > 0 then msg = msg .. (", 레벨 높은 퀘 %d개는 뒤로"):format(nHard) end
  if quiet then return #order, msg end
  Print("루트를 만들었어요: " .. msg)
  return #order, msg
end

TogglePrio = function(key, title)
  CDB.prio = CDB.prio or {}
  if CDB.prio[key] then
    CDB.prio[key] = nil
    Print("먼저 하기 해제: " .. (title or key))
  else
    CDB.prio[key] = true
    Print("먼저 하기: " .. (title or key) .. " — 루트 맨 앞으로 옮겼어요.")
  end
  BuildPlan(true)
  snap, wpFollow = nil, nil
  if Render then Render() end
end

-- 계획의 할 일 하나가 끝났는지 (퀘스트 번호 기준, 없으면 이름 기준)
local function TaskDone(t, log)
  if IsSkipped(t.key, log) then return true end
  if CDB.manual[t.key] == true and not (t.qid and logById[t.qid]) then return true end
  if t.qid then
    local e = logById[t.qid]
    local comp = QuestIdDone(t.qid)
    if t.kind == "get" then return e ~= nil or comp
    elseif t.kind == "do" then return (e and e.state == 2) or comp
    else return comp and not e end
  end
  local st = log[t.key]
  if t.kind == "get" then return st ~= nil or CDB.done[t.key] or false
  elseif t.kind == "do" then return st == 2 or CDB.done[t.key] or false
  else return (CDB.done[t.key] and not st) or false end
end

-- 저장된 루트를 단계로
local planNote
local function PlanSteps(log)
  planNote = nil
  local P = CDB.plan
  local m = PlayerMapID()
  if not P then planNote = "none"; return {} end
  if m and P.map ~= m then planNote = "other"; return {} end
  local steps, last = {}, nil
  for _, t in ipairs(P.tasks) do
    local done = TaskDone(t, log)
    if not done then
      if t.kind == "do" then
        steps[#steps + 1] = { kind = "hunt", key = t.key, qid = t.qid, title = t.title, e = (t.qid and logById[t.qid]) or logByKey[t.key], zone = P.zone,
                              ox = t.x, oy = t.y, omap = P.map, level = t.level, chain = t.chain, escort = t.escort }
        last = nil
      else
        local a = { kind = t.kind, key = t.key, qid = t.qid, title = t.title, level = t.level, x = t.x, y = t.y,
                    map = t.map or P.map, zone = t.zone or P.zone, npc = t.npc, e = (t.qid and logById[t.qid]) or logByKey[t.key], chain = t.chain }
        -- 반납: Questie가 지금 그리고 있는 반납 위치가 있으면 그걸 씀 (다른 지역 포함)
        if t.kind == "turn" and t.qid and QCache and QCache.comp[t.qid] then
          local pts = QCache.comp[t.qid].pts
          local p = BestPoint(pts, P.map) or pts[1]
          if p then
            a.x, a.y, a.map, a.npc = p.x, p.y, p.map, p.npc or a.npc
            a.zone = (p.map == P.map) and P.zone or (ZoneOfMap(p.map) or a.zone)
          end
        end
        if last and a.x and last.x and last.map == a.map and Dist(last.x, last.y, a.x, a.y) < 3 then
          last.acts[#last.acts + 1] = a
        else
          last = { kind = "go", zone = a.zone, x = a.x, y = a.y, map = a.map, acts = { a }, npcs = {} }
          steps[#steps + 1] = last
        end
        if a.npc then
          local seen = false
          for _, nm in ipairs(last.npcs) do if nm == a.npc then seen = true end end
          if not seen then last.npcs[#last.npcs + 1] = a.npc end
        end
        if not a.x then last = nil end
      end
    end
  end
  -- 방금 목표 숫자가 오른 퀘스트(3분 이내)는 사냥 단계를 맨 앞으로
  local A = CDB.activeHunt
  if A and time and (time() - (A.t or 0)) < 180 then
    for idx, st in ipairs(steps) do
      if st.kind == "hunt" and ((A.id and st.qid == A.id) or st.key == A.key) then
        if idx > 1 then table.remove(steps, idx); table.insert(steps, 1, st) end
        st.active = true
        break
      end
    end
  end
  -- 이미 받은 호위 퀘스트는 항상 맨 앞 (루트를 다시 짜기 전이라도)
  for idx, st in ipairs(steps) do
    if st.kind == "hunt" and st.escort and st.e then
      if idx > 1 then table.remove(steps, idx); table.insert(steps, 1, st) end
      break
    end
  end
  return steps
end

-- 반납한 뒤 그 자리에 새로 생긴 퀘스트(연계 다음 편 등)를 루트에 끼워 넣기
local function AutoSupplement()
  local P = CDB.plan
  if not P or DB.sort ~= "plan" then return end
  local m = PlayerMapID()
  if not m or m ~= P.map then return end
  local log = ReadQuestLog()
  QCache = ReadQuestie()
  if not QCache then return end
  local px, py = PlayerPos()
  if not px then return end
  local lv = UnitLevel("player") or 1
  local inPlan = {}
  for _, t in ipairs(P.tasks) do if t.qid then inPlan[t.qid] = true end end
  local gets, rest, names = {}, {}, {}
  for qid, info in pairs(QCache.avail) do
    if not inPlan[qid] and info.title then
      local p = BestPoint(info.pts, m, px, py)
      local lq = info.level or 0
      local okLevel = (lq == 0 or (lq <= lv + 4 and lq >= lv - 6)) and (not info.req or info.req <= lv)
      local key = Norm(info.title)
      if p and Dist(px, py, p.x, p.y) < 6 and okLevel and not logById[qid] and not QuestIdDone(qid) and not IsSkipped(key, log) and not IsExcludedQuest(qid) then
        local base = { qid = qid, key = key, title = info.title, level = lq }
        local function T(kind, x, y, npc, approx)
          local t = { kind = kind, x = x, y = y, npc = npc, approx = approx }
          for k, v in pairs(base) do t[k] = v end
          return t
        end
        gets[#gets + 1] = T("get", p.x, p.y, p.npc)
        local ox, oy, hasObj = ObjectiveArea(qid, m)
        local list = {}
        if hasObj ~= false then list[#list + 1] = T("do", ox, oy) end
        local tp = FinisherPoint(qid, m, p.x, p.y)
        list[#list + 1] = T("turn", tp and tp.x or p.x, tp and tp.y or p.y, tp and tp.npc or p.npc, not tp)
        rest[#rest + 1] = { level = lq, tasks = list }
        names[#names + 1] = info.title
      end
    end
  end
  if #gets == 0 then return false end
  -- 같은 규칙(레벨 1순위, 위치 2순위)으로 루트 전체를 다시 짬
  BuildPlan(true)
  snap = nil
  Print("근처에 새 퀘스트 " .. #gets .. "개가 생겨서 루트를 다시 짰어요: " .. table.concat(names, ", "))
  if Render then Render() end
  return true
end

-- 자동 루트: 루트가 없거나, 다른 지역이거나, 다 끝났으면 새로 짬
local autoPending, autoLast = false, 0
local function AutoPlan(reason)
  if not DB or not DB.autoPlan then return end
  if LV.Instance() then return end
  if DB.sort == "guide" and reason ~= "manual" then return end
  if InCombatLockdown and InCombatLockdown() then autoPending = reason or true; return end
  local now = GetTime and GetTime() or 0
  if now - autoLast < 8 and reason ~= "levelup" and reason ~= "accept" then return end
  QCache = ReadQuestie()
  if not QCache then return end
  local m = PlayerMapID()
  if not m then return end
  local log = ReadQuestLog()
  local need
  if reason == "levelup" then need = "레벨 업"
  elseif reason == "accept" and CDB.plan then need = "퀘스트 받음"
  elseif not CDB.plan then need = "루트 없음"
  elseif CDB.plan.map ~= m then need = "지역 이동"
  else
    local left = false
    for _, t in ipairs(CDB.plan.tasks) do if not TaskDone(t, log) then left = true; break end end
    if not left then need = "루트 완료" end
  end
  if not need then return end
  autoLast = now
  local n, msg = BuildPlan(true)
  snap, wpFollow = nil, nil
  if n and n > 0 and need == "퀘스트 받음" then
    -- 받을 때마다 채팅이 쌓이지 않게 조용히
  elseif n and n > 0 then
    Print(("자동으로 루트를 짰어요 (%s): %s"):format(need, msg or ""))
  elseif need ~= "레벨 업" then
    Print("이 지역에서 할 퀘스트가 없어요. 다음 지역으로 이동해 보세요.")
  end
  if Render then Render() end
end

-- 거점순 / 레벨순: 자세히 보기 목록과 똑같은 순서로 한 퀘스트씩
local function BuildListSteps(b, log, lv, zoneName, z)
  local steps, covered = {}, {}
  local last
  for i, q in ipairs(SortedQuests(z)) do
    local st = QuestState(q, log)
    if st ~= 3 and IsSkipped(q.key, log) then covered[q.key] = true end
    if st ~= 3 and not IsSkipped(q.key, log) then
      covered[q.key] = true
      local zone = q[6] or z.name
      if st == 1 then
        steps[#steps + 1] = { kind = "hunt", e = logByKey[q.key], q = q, key = q.key, zone = zone, title = q[2], n = i }
        last = nil
      else
        local act = MakeAct(st == 2 and "turn" or "get", q, logByKey[q.key], q[2], z.name, i)
        if last and act.x and last.x and last.zone == act.zone and Dist(last.x, last.y, act.x, act.y) < 3 then
          last.acts[#last.acts + 1] = act
        else
          last = { kind = "go", zone = act.zone or zone, x = act.x, y = act.y, map = act.map, acts = { act }, npcs = {} }
          steps[#steps + 1] = last
        end
        if act.npc then
          local seen = false
          for _, nm in ipairs(last.npcs) do if nm == act.npc then seen = true end end
          if not seen then last.npcs[#last.npcs + 1] = act.npc end
        end
        if not act.x then last = nil end
      end
    end
  end
  -- 이 지역 목록에 없는 내 퀘스트는 뒤에 붙임
  local extraTurn = {}
  for _, e in ipairs(logList) do
    if not covered[e.key] and not IsSkipped(e.key, log) then
      if e.state == 2 then
        local q2 = GuideFor(e.key, b)
        local a = MakeAct("turn", q2, e, e.title, nil)
        if a.x then
          steps[#steps + 1] = { kind = "go", zone = a.zone, x = a.x, y = a.y, map = a.map, acts = { a }, npcs = a.npc and { a.npc } or {} }
        else
          extraTurn[#extraTurn + 1] = a
        end
      elseif e.objs and #e.objs > 0 then
        local q, zn = GuideFor(e.key, b)
        steps[#steps + 1] = { kind = "hunt", e = e, q = q, key = e.key, zone = q and (q[6] or zn), title = e.title }
      end
    end
  end
  if #extraTurn > 0 then steps[#steps + 1] = { kind = "go", acts = extraTurn, npcs = {}, unknown = true } end
  return steps
end

-- 들를 곳 만들기
local function BuildSteps(b, log, lv, zoneName, z, usePos, useQuestie)
  if DB.sort ~= "route" then return BuildListSteps(b, log, lv, zoneName, z) end
  local stops = {}
  local function stopFor(a)
    for _, s in ipairs(stops) do
      if s.zone == a.zone and s.x and Dist(s.x, s.y, a.x, a.y) < 3 then return s end
    end
    local s = { kind = "go", zone = a.zone, x = a.x, y = a.y, map = a.map, acts = {}, npcs = {} }
    stops[#stops + 1] = s
    return s
  end
  local function addAct(a)
    local s = stopFor(a)
    s.acts[#s.acts + 1] = a
    if a.npc then
      local seen = false
      for _, n in ipairs(s.npcs) do if n == a.npc then seen = true end end
      if not seen then s.npcs[#s.npcs + 1] = a.npc end
    end
  end

  local hunts, unknownTurn = {}, {}
  for _, e in ipairs(logList) do
    local q, zn = GuideFor(e.key, b)
    if IsSkipped(e.key, log) then
      -- 건너뜀
    elseif e.state == 2 then
      local a = MakeAct("turn", q, e, e.title, zn)
      if a.x then addAct(a) else unknownTurn[#unknownTurn + 1] = a end
    elseif e.objs and #e.objs > 0 then
      hunts[#hunts + 1] = { kind = "hunt", e = e, q = q, key = e.key, zone = q and (q[6] or zn), title = e.title }
    end
  end
  if useQuestie then
    for _, a in ipairs(QuestieGets(log, lv, zoneName)) do addAct(a) end
  else
    for _, q in ipairs(SortedQuests(z)) do
      if q[4] and not QuestState(q, log) and q[1] <= lv + 2 and not IsSkipped(q.key, log) then addAct(MakeAct("get", q, nil, q[2], z.name)) end
    end
  end

  -- 가까운 순 (지금 지역 먼저, 다른 지역은 뒤로)
  local here, away = {}, {}
  for _, s in ipairs(stops) do if s.zone == zoneName then here[#here + 1] = s else away[#away + 1] = s end end
  local px, py
  if usePos then px, py = PlayerPos() end
  local ordered = {}
  if px then
    local cx, cy = px, py
    while #here > 0 do
      local bi, bd = 1, math.huge
      for i, s in ipairs(here) do
        local d = Dist(cx, cy, s.x, s.y)
        -- 반납이 있는 곳은 조금 더 가깝게 쳐서 먼저 들르게
        for _, a in ipairs(s.acts) do if a.kind == "turn" then d = d * 0.7; break end end
        if d < bd then bi, bd = i, d end
      end
      local s = table.remove(here, bi)
      ordered[#ordered + 1] = s
      cx, cy = s.x, s.y
    end
  else
    for _, s in ipairs(here) do ordered[#ordered + 1] = s end
  end
  for _, s in ipairs(away) do ordered[#ordered + 1] = s end

  -- 사냥은 첫 번째 들를 곳 다음에
  local steps = {}
  if ordered[1] then steps[#steps + 1] = ordered[1] end
  for _, h in ipairs(hunts) do steps[#steps + 1] = h end
  for i = 2, #ordered do steps[#steps + 1] = ordered[i] end
  if #unknownTurn > 0 then steps[#steps + 1] = { kind = "go", acts = unknownTurn, npcs = {}, unknown = true } end
  return steps, px, py
end

local function ActDone(a, log)
  if a.qid and a.fromPlan ~= false and ((CDB.plan and DB.sort == "plan") or DB.sort == "guide") then return TaskDone(a, log) end
  if a.kind == "turn" then
    if log[a.key] then return false end
    return CDB.done[a.key] or CDB.manual[a.key] == true or false
  elseif a.kind == "get" then
    return log[a.key] ~= nil or CDB.done[a.key] or CDB.manual[a.key] == true or false
  end
  return false
end

local function StepDone(s, log)
  if s.kind == "hunt" and s.qid and (DB.sort == "plan" or DB.sort == "guide") then return TaskDone({ kind = "do", qid = s.qid, key = s.key }, log) end
  if s.kind == "hunt" then
    local st = log[s.key]
    return st == 2 or (st == nil)
  end
  for _, a in ipairs(s.acts) do if not ActDone(a, log) then return false end end
  return true
end

local function StepTitle(s, zoneName)
  if s.kind == "hunt" then return (s.n and (s.n .. ".  ") or "") .. (s.escort and "호위: " or (C.__cute and "" or "사냥: ")) .. s.title end
  if s.unknown and s.acts and s.acts[1] and s.acts[1].kind == "get" then return s.acts[1].title .. " 받기 (위치 정보 없음)" end
  if s.unknown then return "반납하기 (NPC 위치 정보 없음)" end
  if not s.x and s.acts and s.acts[1] then return s.acts[1].title .. " 시작하기" end
  local who = s.npcs[1]
  local t
  if not who and s.acts and s.acts[1] and s.acts[1].kind == "turn" then t = "반납: " .. s.acts[1].title
  elseif not who then t = "다음 장소로 가세요"
  elseif #s.npcs > 1 then t = who .. " 외 " .. (#s.npcs - 1) .. "명에게 가세요"
  else t = who .. "에게 가세요" end
  return t
end

local function StepSummary(s)
  if s.kind == "hunt" then
    local e = logByKey[s.key] or s.e
    if not e then return s.ox and ("수행 지역 %.1f, %.1f"):format(s.ox, s.oy) or "받은 뒤 수행" end
    for _, o in ipairs(e.objs or {}) do
      if not o.done then
        if o.have and o.need then return o.text .. "  " .. o.have .. "/" .. o.need end
        return o.text
      end
    end
    return "목표 완료"
  end
  local nt, ng = 0, 0
  for _, a in ipairs(s.acts) do if a.kind == "turn" then nt = nt + 1 else ng = ng + 1 end end
  local p = {}
  if nt > 0 then p[#p + 1] = "반납 " .. nt end
  if ng > 0 then p[#p + 1] = "받기 " .. ng end
  return table.concat(p, ", ")
end

-- 퀘스트 레벨 표시: 게임처럼 난이도 색 (빨강·주황·노랑·초록·회색)
function LV.LvColor(level)
  local lv = UnitLevel("player") or 1
  local d = level - lv
  local light = C.__shadow == 0 -- 밝은 테마는 진한 색으로 (노랑이 안 보이므로)
  if d >= 5 then return light and "d9342b" or "ff4030"
  elseif d >= 3 then return light and "e0702a" or "ff8a3a"
  elseif d >= -2 then return light and "c48a00" or "f2d43a"
  elseif not LV.IsGrey(level) then return light and "3e9b54" or "5fbf4a"
  else return light and "9a9a9a" or "8a8a8a" end
end
function LV.LvTag(level)
  level = tonumber(level)
  if not level or level <= 0 then return "" end
  return "|cff" .. LV.LvColor(level) .. "[" .. level .. "]|r "
end
-- "7.  사냥: ..." 처럼 번호가 있으면 번호 뒤에 레벨 붙이기
function LV.WithTag(tag, text)
  text = text or ""
  local n, rest = text:match("^(%d+%.%s+)(.*)$")
  if n then return n .. tag .. rest end
  return tag .. text
end
function LV.Plain(t) return t and (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
function LV.ActLevel(a)
  return tonumber(a.level) or (a.e and tonumber(a.e.level)) or (a.q and tonumber(a.q[1])) or nil
end
function LV.HuntLevel(s)
  local e = logByKey[s.key] or s.e
  return tonumber(s.level) or (e and tonumber(e.level)) or (s.q and tonumber(s.q[1])) or nil
end
-- 장소 단계의 레벨들 (중복 없이, 낮은 순, 최대 3개)
function LV.StepLevelTags(s, log)
  local seen, list = {}, {}
  for _, a in ipairs(s.acts or {}) do
    local l = LV.ActLevel(a)
    if l and not seen[l] and not (log and ActDone and ActDone(a, log)) then seen[l] = true; list[#list + 1] = l end
  end
  table.sort(list)
  local out = {}
  for i = 1, math.min(3, #list) do out[#out + 1] = LV.LvTag(list[i]) end
  return table.concat(out, "")
end

-- 화면 조각 --------------------------------------------------------------
local miniRoot = CreateFrame("Frame", nil, f)
miniRoot:SetPoint("TOPLEFT", 0, -66)
miniRoot:SetPoint("TOPRIGHT", 0, -66)
miniRoot:SetHeight(10)
miniRoot:Hide()

local card = CreateFrame("Frame", nil, miniRoot, BD)
card:SetPoint("TOPLEFT", PAD, -6)
card:SetPoint("TOPRIGHT", -PAD, -6)
Backdrop(card, { C.accent[1], C.accent[2], C.accent[3], 0.07 }, { C.accent[1], C.accent[2], C.accent[3], 0.45 })

local cNum = FS(card, 28, C.accent)
cNum:SetPoint("TOPLEFT", 12, -10)
cNum:Hide()
local cOf = FS(card, 10, C.muted, "RIGHT")
cOf:SetPoint("TOPRIGHT", -10, -14)
local cBig = FS(card, 17, C.accent, "RIGHT")
cBig:SetPoint("BOTTOMRIGHT", cOf, "BOTTOMLEFT", -3, -1)

-- 나침반: 목적지 방향 화살표 (캐릭터가 보는 방향 기준)
local compass = CreateFrame("Frame", nil, card)
compass:SetSize(42, 42)
compass:SetPoint("TOPLEFT", 10, -10)
compass.ring = compass:CreateTexture(nil, "BACKGROUND")
compass.ring:SetTexture(ICON.circle); compass.ring:SetAllPoints()
compass.bg = compass:CreateTexture(nil, "BORDER")
compass.bg:SetTexture(ICON.circle); compass.bg:SetPoint("TOPLEFT", 2.5, -2.5); compass.bg:SetPoint("BOTTOMRIGHT", -2.5, 2.5)
compass.bg:SetVertexColor(0.06, 0.07, 0.08, 0.95)
compass.arrow = compass:CreateTexture(nil, "ARTWORK")
compass.arrow:SetTexture(ICON.arrow); compass.arrow:SetSize(40, 40); compass.arrow:SetPoint("CENTER")
compass.n = FS(compass, 8, C.muted, "CENTER"); compass.n:SetPoint("TOP", 0, -3); compass.n:SetText("N")
local atan2c = math.atan2 or math.atan
local function CompassTint(c) compass.ring:SetVertexColor(c[1], c[2], c[3], 1) end
local compassAcc = 0
compass:SetScript("OnUpdate", function(self, el)
  compassAcc = compassAcc + el
  if compassAcc < 0.05 then return end
  compassAcc = 0
  if not self.tx then self.arrow:SetAlpha(0.25); return end
  local px, py = PlayerPos()
  if not px or not self.sameMap then self.arrow:SetAlpha(0.25); self.arrow:SetRotation(0); return end
  self.arrow:SetAlpha(1)
  local bearing = atan2c(self.tx - px, -(self.ty - py))
  local facing = GetPlayerFacing and GetPlayerFacing()
  self.n:SetShown(facing == nil)
  self.arrow:SetRotation(-(bearing + (facing or 0)))
end)
local dots = {}
local miniSortB = FlatButton(miniRoot, "경로순", 48, 20)
local miniPlanB = FlatButton(miniRoot, "루트 만들기", 70, 20)
miniPlanB:SetPoint("RIGHT", miniSortB, "LEFT", -6, 0)
miniSortB:SetScript("OnClick", function()
  DB.sort = DB.sort == "route" and "hub" or DB.sort == "hub" and "level" or (DB.sort == "level" and CDB.plan) and "plan" or (DB.sort ~= "guide" and ns.guide) and "guide" or "route"
  Render()
end)
local cGoto = FS(card, 14, C.text)
cGoto:SetWordWrap(true)
cGoto:SetPoint("TOPLEFT", 60, -12)
local cSub = FS(card, 10, C.muted)
cSub:SetWordWrap(true)
cSub:SetPoint("TOPLEFT", cGoto, "BOTTOMLEFT", 0, -3)

local todos = {}
local function GetTodo(i)
  local t = todos[i]
  if t then return t end
  t = CreateFrame("Button", nil, card, BD)
  t.__round = 8
  t:SetHeight(20)
  t.hl = Tex(t, { 1, 1, 1, 0.05 }, "HIGHLIGHT")
  t.hl:SetPoint("TOPLEFT", -4, 0); t.hl:SetPoint("BOTTOMRIGHT", 4, 0)
  t:SetScript("OnClick", function(self)
    local a = self.act
    if a and a.x then
      SetWaypoint(a.map or D.maps[a.zone or self.zone], a.x, a.y, a.title .. (a.npc and (" (" .. a.npc .. ")") or ""))
    end
  end)
  t:SetScript("OnEnter", function(self)
    local a = self.act
    if not a then
      if self.full then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.full, C.text[1], C.text[2], C.text[3], true)
        GameTooltip:Show()
      end
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(a.title, C.accent[1], C.accent[2], C.accent[3])
    if a.fromGame then GameTooltip:AddLine("반납 위치: 게임 지도 표시 기준", C.text[1], C.text[2], C.text[3])
    elseif a.npc then GameTooltip:AddLine((a.kind == "turn" and "반납: " or "받기: ") .. a.npc, C.text[1], C.text[2], C.text[3]) end
    if a.x then
      GameTooltip:AddLine(("좌표 %.1f, %.1f"):format(a.x, a.y), C.muted[1], C.muted[2], C.muted[3])
      GameTooltip:AddLine("클릭: 이 퀘스트 위치로 웨이포인트", C.accent[1], C.accent[2], C.accent[3])
    end
    GameTooltip:Show()
  end)
  t:SetScript("OnLeave", function() GameTooltip:Hide() end)
  t.bg = Tex(t, { 0, 0, 0, 0.22 }, "BACKGROUND")
  t.bg:SetAllPoints()
  t.box = CreateFrame("Frame", nil, t, BD)
  t.box:SetSize(12, 12)
  t.box:SetPoint("TOPLEFT", 0, -4)
  t.box:Hide()
  t.badge = MakeBadge(t, 18)
  t.badge:SetPoint("TOPLEFT", 5, -4)
  t.fs = FS(t, 12, C.text)
  t.fs:SetWordWrap(true)
  t.fs:SetPoint("TOPLEFT", t, "TOPLEFT", 28, -6)
  t.cnt = FS(t, 11, C.text, "RIGHT")
  t.cnt:SetPoint("TOPRIGHT", -8, -6)
  t.track = Tex(t, { 1, 1, 1, 0.08 })
  t.track:SetHeight(5)
  t.track:SetPoint("BOTTOMLEFT", 28, 6); t.track:SetPoint("BOTTOMRIGHT", -8, 6)
  t.fill = Tex(t, C.hunt)
  t.fill:SetHeight(5)
  t.fill:SetPoint("LEFT", t.track, "LEFT", 0, 0)
  todos[i] = t
  return t
end

-- 아이콘 버튼 (카드 오른쪽 위)
local function IconButton(tex, title, desc, fallback, primary, coords, size)
  local b = CreateFrame("Button", nil, card, BD)
  b.__round = 8
  b:SetSize(24, 24)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(size or 16, size or 16)
  b.icon:SetPoint("CENTER")
  local ok = b.icon:SetTexture(tex)
  if coords then b.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) end
  b.txt = FS(b, 11, C.text, "CENTER")
  b.txt:SetPoint("CENTER")
  if ok == false then b.icon:Hide(); b.txt:SetText(fallback) end
  function b:Paint()
    if self.hover then
      Backdrop(self, primary and { C.accent[1], C.accent[2], C.accent[3], 0.32 } or C.raise, primary and C.accent or C.line2)
    elseif primary then
      Backdrop(self, { C.accent[1], C.accent[2], C.accent[3], 0.18 }, C.accent)
    else
      Backdrop(self, { 0, 0, 0, 0 }, C.line)
    end
  end
  b:SetScript("OnEnter", function(self)
    self.hover = true; self:Paint()
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(title, C.accent[1], C.accent[2], C.accent[3])
    if desc then GameTooltip:AddLine(self.desc or desc, C.text[1], C.text[2], C.text[3], true) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(self) self.hover = false; self:Paint(); GameTooltip:Hide() end)
  b:SetScript("OnMouseDown", function(self) self.icon:SetPoint("CENTER", 1, -1) end)
  b:SetScript("OnMouseUp", function(self) self.icon:SetPoint("CENTER", 0, 0) end)
  b:Paint()
  return b
end

local wpBtn = IconButton("Interface\\Minimap\\MiniMap-QuestArrow", "길 안내", "지도와 미니맵에 여기까지 점선 길을 그려요. 다시 누르면 꺼요", "W", true, nil, 18)
local mapBtn = IconButton("Interface\\Icons\\INV_Misc_Map_01", "지도에서 보기", "전체 지도에서 수행 지역을 보여 줘요", "M", false, { 0.08, 0.92, 0.08, 0.92 })
local skipBtn = IconButton("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", "건너뛰기", "이 단계를 순서에서 빼요. 자세히 보기에서 오른쪽 클릭하면 되돌려요", ">", false, nil, 22)
wpBtn.__base = { "Interface\\Minimap\\MiniMap-QuestArrow", nil, 18, "ic_pin" }
mapBtn.__base = { "Interface\\Icons\\INV_Misc_Map_01", { 0.08, 0.92, 0.08, 0.92 }, 16, "ic_map" }
skipBtn.__base = { "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", nil, 22, "ic_skip" }
-- 귀여운 테마: 직접 그린 아이콘 + 동그란 버튼
function LV.CuteIcons(cute)
  for _, b in ipairs({ wpBtn, mapBtn, skipBtn }) do
    local bs = b.__base
    b.icon:Show(); b.txt:SetText("")
    if cute then
      b.icon:SetTexture("Interface\\AddOns\\ForgLeveling\\media\\" .. bs[4])
      b.icon:SetTexCoord(0, 1, 0, 1)
      b.icon:SetSize(19, 19)
      b.__round = 12
    else
      b.icon:SetTexture(bs[1])
      if bs[2] then b.icon:SetTexCoord(bs[2][1], bs[2][2], bs[2][3], bs[2][4]) else b.icon:SetTexCoord(0, 1, 0, 1) end
      b.icon:SetSize(bs[3], bs[3])
      b.__round = 8
    end
    b:Paint()
  end
end

local thenFS = FS(miniRoot, 10, C.muted)
local nexts = {}
local function GetNext(i)
  local r = nexts[i]
  if r then return r end
  r = CreateFrame("Button", nil, miniRoot)
  r:SetHeight(34)
  r.hl = Tex(r, { 1, 1, 1, 0.04 }, "HIGHLIGHT"); r.hl:SetAllPoints()
  -- 지역 구분선 (지역이 바뀌는 곳에만): ● 여기 / ✈ 이동
  r.zone = FS(r, 11, C.text)
  r.zone:SetPoint("TOPLEFT", 0, -3)
  r.zoneLine = Tex(r, C.line, "BACKGROUND")
  r.zoneLine:SetHeight(1)
  r.zoneLine:SetPoint("LEFT", r.zone, "RIGHT", 6, 0)
  r.zoneLine:SetPoint("RIGHT", r, "RIGHT", 0, 0)
  -- 구역 이름 (구역이 바뀌는 곳에만)
  r.area = FS(r, 10, C.accent)
  r.area:SetPoint("TOPLEFT", 0, -4)
  r.areaLine = Tex(r, C.line, "BACKGROUND")
  r.areaLine:SetHeight(1)
  r.areaLine:SetPoint("LEFT", r.area, "RIGHT", 6, 0)
  r.areaLine:SetPoint("RIGHT", r, "RIGHT", 0, 0)
  -- 세로선 + 아이콘
  r.vline = Tex(r, C.line2, "BACKGROUND")
  r.vline:SetWidth(2)
  r.icon = MakeBadge(r, 18)
  r.nb = CreateFrame("Frame", nil, r, BD)
  r.nb:SetSize(1, 1)
  r.nb:Hide()
  r.n = FS(r.nb, 11, C.muted, "CENTER")
  r.t = FS(r, 12, C.text)
  r.t:SetPoint("TOPLEFT", 28, -4)
  r.t:SetPoint("RIGHT", -2, 0)
  r.s = FS(r, 10, C.faint)
  r.s:SetPoint("TOPLEFT", r.t, "BOTTOMLEFT", 0, -2)
  r.s:SetPoint("RIGHT", -2, 0)
  r.co = FS(r, 10, C.faint, "RIGHT")
  r.co:SetPoint("RIGHT", 0, 0)
  r:SetScript("OnClick", function(self)
    local s = self.step
    if s and s.x then SetWaypoint(s.map or D.maps[s.zone], s.x, s.y, StepTitle(s)) end
  end)
  r:SetScript("OnEnter", function(self)
    local s = self.step
    if not s then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(s.titleText or "", C.accent[1], C.accent[2], C.accent[3])
    if s.zone then GameTooltip:AddLine(s.zone, C.muted[1], C.muted[2], C.muted[3]) end
    if s.x then
      GameTooltip:AddLine(("좌표 %.1f, %.1f"):format(s.x, s.y), C.muted[1], C.muted[2], C.muted[3])
      GameTooltip:AddLine("클릭: 웨이포인트", C.accent[1], C.accent[2], C.accent[3])
    end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  nexts[i] = r
  return r
end

local function MapFor(s) return s and s.zone and D.maps[s.zone] end

-- 두 보기가 함께 쓰는 경로. zi = 지역 번호(없으면 지금 있는 지역)
Route = function(b, log, lv, zi, forceHere)
  local pz = PlayerZone()
  local here = nil
  for i, zz in ipairs(b.zones) do if zz.name == pz then here = i end end
  local useQ = DB.sort == "route" and QCache and (forceHere or (zi and zi == here))
  local z, isHere, steps, px, py
  if DB.sort == "guide" and ns.guide then
    local title
    steps, title = LV.GuideSteps(log)
    if steps then
      z = { name = title or pz, quests = {} }
    else
      -- 이 지역엔 따라하기가 없음(30레벨 이후 등): 1~60 레벨링 정보 + 퀘스트 데이터로 자동 루트
      local m = PlayerMapID()
      local now = GetTime and GetTime() or 0
      if m and not LV.Instance() and (not CDB.plan or CDB.plan.map ~= m) and now - (LV.fbBuilt or -99) > 10 then
        LV.fbBuilt = now
        BuildPlan(true)
        DB.sort = "guide"
        if LV.fbZone ~= m then
          LV.fbZone = m
          Print(pz .. "에는 따라하기가 없어서 자동 루트로 안내해요. (지역별 퀘스트 목록은 자세히 보기)")
        end
      end
      z = { name = pz .. " (자동 루트)", quests = {} }
      steps = PlanSteps(log)
    end
    isHere = true
  elseif DB.sort == "plan" then
    z = { name = (CDB.plan and CDB.plan.zone) or pz, quests = {} }
    isHere = true
    steps = PlanSteps(log)
  elseif useQ then
    z = { name = pz, quests = {} }
    isHere = true
    steps, px, py = BuildSteps(b, log, lv, pz, z, true, true)
  else
    zi = zi or here or 1
    z = b.zones[zi]
    isHere = (zi == here)
    steps, px, py = BuildSteps(b, log, lv, z.name, z, isHere)
  end

  if DB.sort == "guide" then snap = nil end
  if isHere and DB.sort ~= "guide" then
    -- 지금 단계는 끝날 때까지 그대로 (체크 표시가 보이도록)
    if snap and (snap.bracket ~= current or snap.zone ~= z.name or snap.sort ~= DB.sort or StepDone(snap.step, log)) then snap = nil end
    -- 새 순서의 첫 단계가 지금 단계와 다르면 (앞쪽 퀘스트가 새로 생김 등) 새 순서를 따름
    if snap and steps[1] then
      local first = steps[1]
      local same = false
      local function has(key)
        if snap.step.kind == "hunt" then return snap.step.key == key end
        for _, a in ipairs(snap.step.acts) do if a.key == key and not ActDone(a, log) then return true end end
        return false
      end
      if first.kind == "hunt" then same = has(first.key)
      else for _, a in ipairs(first.acts) do if has(a.key) then same = true; break end end end
      if not same then snap = nil end
    end
    if snap then
      local keys = {}
      if snap.step.kind == "hunt" then keys[snap.step.key] = true
      else for _, a in ipairs(snap.step.acts) do keys[a.key] = true end end
      local rest = {}
      for _, s in ipairs(steps) do
        if s.kind == "hunt" then
          if not keys[s.key] then rest[#rest + 1] = s end
        else
          local acts = {}
          for _, a in ipairs(s.acts) do if not keys[a.key] then acts[#acts + 1] = a end end
          if #acts > 0 then s.acts = acts; rest[#rest + 1] = s end
        end
      end
      table.insert(rest, 1, snap.step)
      steps = rest
    elseif steps[1] then
      snap = { bracket = current, zone = z.name, sort = DB.sort, step = steps[1] }
    end
  end
  for _, s in ipairs(steps) do
    s.titleText = StepTitle(s)
    s.summary = StepSummary(s)
  end
  return steps, isHere, z, px, py
end

---------------------------------------------------------------------------
-- 던전 모드: 던전 안에서는 그 던전 퀘스트만, 나오면 던전 퀘스트 반납만
---------------------------------------------------------------------------
function LV.Instance()
  if not IsInInstance then return nil end
  local ok, inInst, itype = pcall(IsInInstance)
  if not ok or not inInst or (itype ~= "party" and itype ~= "raid") then return nil end
  local name = GetInstanceInfo and select(1, GetInstanceInfo()) or GetRealZoneText and GetRealZoneText() or "던전"
  return name or "던전"
end

-- 지금 던전의 지역 번호 (Questie 표: 인스턴스 번호 → 지역 번호)
function LV.DungeonArea(iname)
  local ZDB = QModule("ZoneDB")
  if not ZDB then return nil end
  local iid = GetInstanceInfo and select(8, GetInstanceInfo())
  local a = iid and ZDB.instanceIdToAreaId and ZDB.instanceIdToAreaId[iid]
  if not a and iname and ZDB.GetAreaIdByName then
    local ok, r = pcall(ZDB.GetAreaIdByName, ZDB, iname); if ok then a = r end
  end
  return tonumber(a)
end

function LV.ZoneMatch(zs, area)
  if not zs or not area then return false end
  if zs == area then return true end
  local ZDB = QModule("ZoneDB")
  if ZDB and ZDB.GetParentZoneId then
    local ok, p = pcall(ZDB.GetParentZoneId, ZDB, zs)
    if ok and p == area then return true end
  end
  return false
end

-- 이 던전에서 받을 수 있는데 아직 안 받은 퀘스트.
-- 전체 퀘스트를 한 번에 훑으면 게임이 "실행 시간 초과"로 멈추므로 여러 프레임에 나눠 훑음.
-- 훑는 중이면 nil 반환 (끝나면 화면을 다시 그림)
function LV.DungeonOffers(area, log)
  LV.offerCache = LV.offerCache or {}
  local list = LV.offerCache[area]
  if not list then
    if LV.scanArea == area then return nil end -- 이미 훑는 중
    local QDB = QModule("QuestieDB")
    if not (QDB and type(QDB.QuestPointers) == "table") then LV.offerCache[area] = {}; return {} end
    local ids = {}
    for qid in pairs(QDB.QuestPointers) do ids[#ids + 1] = qid end
    local QP = QModule("QuestiePlayer")
    local found, i = {}, 1
    LV.scanArea = area
    LV.scanFrame = LV.scanFrame or CreateFrame("Frame")
    LV.scanFrame:SetScript("OnUpdate", function(self)
      local stop = math.min(#ids, i + 149)
      for k = i, stop do
        local qid = ids[k]
        local zs = tonumber(QQuery("Quest", qid, "zoneOrSort"))
        if zs and zs > 0 and LV.ZoneMatch(zs, area) then
          local ok = true
          if QP and QP.HasRequiredRace then
            local s1, r = pcall(QP.HasRequiredRace, QQuery("Quest", qid, "requiredRaces")); if s1 and r == false then ok = false end
          end
          if ok and QP and QP.HasRequiredClass then
            local s2, r = pcall(QP.HasRequiredClass, QQuery("Quest", qid, "requiredClasses")); if s2 and r == false then ok = false end
          end
          if ok then found[#found + 1] = qid end
        end
      end
      i = stop + 1
      if i > #ids then
        self:SetScript("OnUpdate", nil)
        LV.offerCache[area] = found
        LV.scanArea = nil
        if Render then Render() end
      end
    end)
    return nil
  end
  local lv = UnitLevel("player") or 1
  local out = {}
  for _, qid in ipairs(list) do
    local rq = tonumber(QQuery("Quest", qid, "requiredLevel")) or 0
    local title = QQuery("Quest", qid, "name")
    if title and rq <= lv and not logById[qid] and not QuestIdDone(qid) and not IsExcludedQuest(qid) then
      out[#out + 1] = { id = qid, title = title, key = Norm(title), level = tonumber(QQuery("Quest", qid, "questLevel") or QQuery("Quest", qid, "level")) }
    end
  end
  return out
end

-- 받기 단계 (퀘스트 주는 NPC, 보통 던전 밖)
function LV.GetSteps(list, m, px, py)
  local steps, byNpc = {}, {}
  for _, o in ipairs(list) do
    local sb = QQuery("Quest", o.id, "startedBy")
    local sp = type(sb) == "table" and NpcPoint(sb[1], m, px, py, true) or {}
    local zone = (sp.map and ZoneOfMap(sp.map)) or nil
    local a = { kind = "get", key = o.key, qid = o.id, title = o.title, level = o.level, x = sp.x, y = sp.y, map = sp.map, zone = zone, npc = sp.npc }
    local s = sp.npc and byNpc[sp.npc]
    if s then s.acts[#s.acts + 1] = a
    else
      s = { kind = "go", acts = { a }, npcs = sp.npc and { sp.npc } or {}, x = sp.x, y = sp.y, map = sp.map, zone = zone, unknown = not sp.x or nil }
      steps[#steps + 1] = s
      if sp.npc then byNpc[sp.npc] = s end
    end
  end
  return LV.SortNear(steps, m, px, py)
end

-- 이 퀘스트가 지금 들어와 있는 던전의 퀘스트인지
function LV.InThisDungeon(e, m, iname, area)
  if not e or not e.id then return false end
  LV.dqMemo = LV.dqMemo or {}
  local mk = (iname or "") .. ":" .. e.id
  if LV.dqMemo[mk] ~= nil then return LV.dqMemo[mk] end
  local r = LV.InThisDungeonRaw(e, m, iname, area)
  LV.dqMemo[mk] = r
  return r
end
function LV.InThisDungeonRaw(e, m, iname, area)
  if area and LV.ZoneMatch(tonumber(QQuery("Quest", e.id, "zoneOrSort")), area) then return true end
  if m then
    local am = ApiObjectivePos(e.id)
    if am and am == m then return true end
    local ox = ObjectiveArea(e.id, m)
    if ox then return true end
  end
  local zs = tonumber(QQuery("Quest", e.id, "zoneOrSort"))
  if zs and zs > 0 then
    local um = AreaToMap(zs)
    if um and m and um == m then return true end
    local zn = um and ZoneOfMap(um)
    if zn and iname and zn == iname then return true end
  end
  return false
end

-- 가까운 순으로 정렬: 지금 지도에 있는 곳(가까운 순) → 다른 지역 → 위치 모름
function LV.SortNear(steps, m, px, py)
  local function key(s)
    if not s.x then return 3, 0 end
    if s.map and m and s.map ~= m then return 2, 0 end
    return 1, (px and Dist(px, py, s.x, s.y)) or 0
  end
  table.sort(steps, function(a, b)
    local ga, da = key(a)
    local gb, db = key(b)
    if ga ~= gb then return ga < gb end
    return da < db
  end)
  return steps
end

-- 반납 단계 만들기 (같은 NPC끼리 묶음)
function LV.TurnSteps(list, m, px, py)
  local steps, byNpc = {}, {}
  for _, e in ipairs(list) do
    local tp
    if QCache and QCache.comp[e.id] then
      local pts = QCache.comp[e.id].pts
      local p = BestPoint(pts, m, px, py) or pts[1]
      if p then tp = { x = p.x, y = p.y, npc = p.npc, map = p.map } end
    end
    tp = tp or FinisherPoint(e.id, m, px, py) or {}
    local zone = (tp.map and ZoneOfMap(tp.map)) or PlayerZone()
    local a = { kind = "turn", key = e.key, qid = e.id, title = e.title, level = e.level, x = tp.x, y = tp.y,
                map = tp.map, zone = zone, npc = tp.npc, e = e }
    local s = tp.npc and byNpc[tp.npc]
    if s then
      s.acts[#s.acts + 1] = a
    else
      s = { kind = "go", acts = { a }, npcs = tp.npc and { tp.npc } or {}, x = tp.x, y = tp.y, map = tp.map, zone = zone, unknown = not tp.x or nil }
      steps[#steps + 1] = s
      if tp.npc then byNpc[tp.npc] = s end
    end
  end
  return LV.SortNear(steps, m, px, py)
end

-- 기본 단계(steps)를 던전 상황에 맞게 바꿈. 바꿨으면 (새 단계, 제목) 반환
function LV.DungeonSteps(steps, log)
  local iname = LV.Instance()
  local m = PlayerMapID()
  local px, py = PlayerPos()
  if iname then
    QCache = QCache or ReadQuestie()
    local area = LV.DungeonArea(iname)
    local hunts, done, ids = {}, {}, {}
    for _, e in ipairs(logList) do
      if not IsSkipped(e.key, log) and LV.InThisDungeon(e, m, iname, area) then
        ids[e.id] = true
        if e.state == 2 then done[#done + 1] = e
        elseif e.state == 1 then
          hunts[#hunts + 1] = { kind = "hunt", key = e.key, qid = e.id, title = e.title, e = e, zone = iname, level = e.level, dungeon = true }
        end
      end
    end
    -- 들어와 있는 동안 계속 기억 (나갈 때 반납 목록으로 씀)
    LV.lastDungeon = LV.lastDungeon and LV.lastDungeon.name == iname and LV.lastDungeon or { name = iname, ids = {} }
    for id in pairs(ids) do LV.lastDungeon.ids[id] = true end
    local out = hunts
    for _, s in ipairs(LV.TurnSteps(done, m, px, py)) do out[#out + 1] = s end
    LV.dungeonNote = nil
    if #out == 0 then
      -- 받은 던전 퀘스트가 없음: 받을 수 있는 곳을 보여 줌
      local offers = {}
      if area then offers = LV.DungeonOffers(area, log) end
      if offers == nil then
        LV.dungeonNote = "scanning"
      elseif #offers > 0 then
        out = LV.GetSteps(offers, m, px, py)
        LV.dungeonNote = "offers"
        if LV.offerPrinted ~= iname then
          LV.offerPrinted = iname
          local names = {}
          for i = 1, math.min(5, #offers) do names[#names + 1] = offers[i].title end
          Print(("%s: 받은 던전 퀘스트가 없어요. 받을 수 있는 퀘스트 %d개 (%s%s) — 주는 곳을 간략 보기에 띄웠어요."):format(
            iname, #offers, table.concat(names, ", "), #offers > 5 and " 등" or ""))
        end
      else
        LV.dungeonNote = "none"
      end
    end
    return out, iname
  end
  -- 던전에서 막 나옴: 그 던전 퀘스트 반납만
  if LV.lastDungeon then
    CDB.dungeonExit = { name = LV.lastDungeon.name, ids = LV.lastDungeon.ids, t = time and time() or 0 }
    LV.lastDungeon = nil
    snap, wpFollow = nil, nil
  end
  local X = CDB.dungeonExit
  if X then
    local list = {}
    for _, e in ipairs(logList) do
      if e.id and X.ids[e.id] and e.state == 2 and not IsSkipped(e.key, log) then list[#list + 1] = e end
    end
    if #list == 0 then CDB.dungeonExit = nil; return nil end
    return LV.TurnSteps(list, m, px, py), X.name .. " 반납"
  end
end


---------------------------------------------------------------------------
-- 따라하기 모드: forg.gg "순서대로 따라 하기" 단계를 그대로 따라감 (Guide.lua)
---------------------------------------------------------------------------
LV.START = { Orc = "durotar", Troll = "durotar", Tauren = "mulgore", Scourge = "tirisfal-glades", Undead = "tirisfal-glades" }

function LV.GuideMap(name)
  if not name or name == "" then return nil end
  if D.maps[name] then return D.maps[name] end
  if name == "듀로타" then return 1411 elseif name == "멀고어" then return 1412 end
  DB.mapLearn = DB.mapLearn or {}
  if PlayerZone() == name then
    local m = PlayerMapID()
    if m then DB.mapLearn[name] = m end
  end
  return DB.mapLearn[name]
end

-- 이 캐릭터가 받을 수 있는 퀘스트인지 (종족·직업 제한)
function LV.QuestOK(id)
  local QP = QModule("QuestiePlayer")
  if not QP then return true end
  if QP.HasRequiredRace then
    local ok, r = pcall(QP.HasRequiredRace, QQuery("Quest", id, "requiredRaces")); if ok and r == false then return false end
  end
  if QP.HasRequiredClass then
    local ok, r = pcall(QP.HasRequiredClass, QQuery("Quest", id, "requiredClasses")); if ok and r == false then return false end
  end
  return true
end

function LV.GetDone(g, log)
  local id, name, lv = g[1], g[2], g[3]
  if logById[id] or QuestIdDone(id) then return true end
  local key = Norm(name)
  if IsSkipped(key, log) or CDB.done[key] or CDB.manual[key] == true then return true end
  if not LV.QuestOK(id) then return true end
  if (lv or 0) == 0 then lv = tonumber(QQuery("Quest", id, "questLevel") or QQuery("Quest", id, "level")) or 0 end
  if LV.SkipGrey() and LV.IsGrey(lv) then return true end
  -- Questie가 "지금 받을 수 있다"고 표시하지 않는 퀘스트(선행 퀘스트 미완료, 이미 지난 퀘스트 등)는 막지 않음
  if QCache and QCache.avail and not QCache.avail[id] then return true end
  return false
end

function LV.TurnIds(t)
  local out = {}
  for raw in (t[5] or ""):gmatch("[^,]+") do
    local nm = raw:gsub("^%s+", ""):gsub("%s+$", "")
    local id = ns.guide.ids[nm]
    if id then out[#out + 1] = { id = id, name = nm } end
  end
  return out
end

function LV.StepDoneG(S, log)
  for _, g in ipairs(S.gets) do if not LV.GetDone(g, log) then return false end end
  for _, t in ipairs(S.turns) do
    for _, q in ipairs(LV.TurnIds(t)) do
      if logById[q.id] and not IsSkipped(Norm(q.name), log) then return false end
    end
  end
  return true
end

function LV.GuideZone(log)
  log = log or ReadQuestLog()
  local G = ns.guide
  if not G then return nil end
  CDB.guide = CDB.guide or { floor = {} }
  CDB.guide.floor = CDB.guide.floor or {}
  local pz = PlayerZone()
  local function find(slug) for _, z in ipairs(G.zones) do if z.slug == slug then return z end end end
  local function hasLeft(z)
    local fl = CDB.guide.floor[z.slug] or 1
    for i = fl, #z.steps do if not LV.StepDoneG(z.steps[i], log) then return true end end
    return false
  end
  if CDB.guide.pin then local z = find(CDB.guide.pin); if z then return z end end
  -- 지금 있는 지역에 따라하기가 있으면 그것
  for _, z in ipairs(G.zones) do if z.name == pz and hasLeft(z) then return z end end
  -- 수도(비행 조련사·전달 퀘스트)에 잠깐 들른 경우: 하던 가이드 유지
  local CITY = { ["오그리마"] = true, ["썬더 블러프"] = true, ["언더시티"] = true }
  if CITY[pz] and CDB.guide.zone then local z = find(CDB.guide.zone); if z and hasLeft(z) then return z end end
  -- 그 밖의 지역(30레벨 이후 등): 따라하기 없음 → 자동 루트로
  return nil
end

-- Questie와 같은 지도 라이브러리를 같이 쓰므로, Questie가 모든 핀을 훑을 때 오류가 안 나게 맞춰 둠
--  · 말풍선: data가 있어야 함 (없으면 오류) → 빈 data, hidden으로 건너뜀
--  · 크기 조절: data.GetIconScale이 있어야 함 → 0을 돌려줘서 크기를 안 바꿈
function LV.QuestieSafe(b)
  b.data = { GetIconScale = function() return 0 end, IconScale = 0 }
  b.hidden = true
  b.GlowUpdate = function() end
end

-- HereBeDragons 찾기: Questie는 이름을 바꾼 사본(HereBeDragonsQuestie)을 씀
function LV.HBD()
  if not LibStub then return nil, nil end
  local h = LibStub("HereBeDragons-2.0", true) or LibStub("HereBeDragonsQuestie-2.0", true)
  local p = LibStub("HereBeDragons-Pins-2.0", true) or LibStub("HereBeDragonsQuestie-Pins-2.0", true)
  return h, p
end

-- 지금 목적지를 세계 지도와 미니맵에 핀으로 표시 (Questie에 들어 있는 HereBeDragons 사용)
function LV.UpdatePin()
  local _, HBDP = LV.HBD()
  if not HBDP then return end
  if not LV.pinRef then
    local function make(size)
      local b = CreateFrame("Frame", nil, UIParent)
      b:SetSize(size, size)
      b.ring = b:CreateTexture(nil, "ARTWORK")
      b.ring:SetAllPoints()
      b.ring:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
      b.ring:SetVertexColor(0.08, 0.06, 0.03, 0.9)
      b.dot = b:CreateTexture(nil, "OVERLAY")
      b.dot:SetSize(size * 0.7, size * 0.7)
      b.dot:SetPoint("CENTER")
      b.dot:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
      b.dot:SetVertexColor(0.886, 0.651, 0.231, 1)
      b:EnableMouse(true)
      b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("르엘 길잡이 목적지", 0.886, 0.651, 0.231)
        if self.label then GameTooltip:AddLine(self.label, 1, 1, 1) end
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      -- Questie 말풍선이 같은 라이브러리의 핀을 모두 훑을 때 오류 안 나게 (빈 data + 건너뛰기 표시)
      LV.QuestieSafe(b)
      return b
    end
    LV.pinRef = {}
    LV.pinWorld = make(26)
    LV.pinMini = make(16)
  end
  -- 호박색 목적지 원은 쓰지 않음 (웨이포인트 점선만 씀)
  local w = nil
  local key = w and w.map and w.x and ("%d:%.1f:%.1f"):format(w.map, w.x, w.y) or nil
  if key == LV.pinKey then return end
  LV.pinKey = key
  pcall(HBDP.RemoveAllWorldMapIcons, HBDP, LV.pinRef)
  pcall(HBDP.RemoveAllMinimapIcons, HBDP, LV.pinRef)
  LV.pinCur = key and w or nil
  LV.trailKey = nil
  if LV.UpdateTrail then LV.UpdateTrail() end
  if not key then return end
  LV.pinWorld.label, LV.pinMini.label = w.label, w.label
  pcall(HBDP.AddWorldMapIconMap, HBDP, LV.pinRef, LV.pinWorld, w.map, w.x / 100, w.y / 100, 3) -- 3 = 상위 지도에도 표시
  pcall(HBDP.AddMinimapIconMap, HBDP, LV.pinRef, LV.pinMini, w.map, w.x / 100, w.y / 100, true, true) -- 가장자리에 붙어 방향 표시
end

-- 내 캐릭터 → 목적지 점선 (세계 지도 + 미니맵)
function LV.UpdateTrail()
  local HBD, HBDP = LV.HBD()
  if not HBD or not HBDP then return end
  if not LV.trailRefW then
    LV.trailRefW, LV.trailRefM = {}, {}
    LV.trailW, LV.trailM = {}, {}
    local function dot(size)
      local b = CreateFrame("Frame", nil, UIParent)
      b:SetSize(size, size)
      b.t = b:CreateTexture(nil, "OVERLAY")
      b.t:SetAllPoints()
      b.t:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
      LV.QuestieSafe(b)
      return b
    end
    for i = 1, 40 do LV.trailW[i] = dot(4); LV.trailM[i] = dot(4) end
  end
  local w = ns.trail
  local on = w and DB and DB.mapTrail ~= false
  local px, py, pinst, tx, ty, tinst
  if on then
    local ok
    ok, px, py, pinst = pcall(HBD.GetPlayerWorldPosition, HBD)
    if not ok then px = nil end
    ok, tx, ty, tinst = pcall(HBD.GetWorldCoordinatesFromZone, HBD, w.x / 100, w.y / 100, w.map)
    if not ok then tx = nil end
    if not (px and py and tx and ty) or pinst ~= tinst then on = false end
  end
  -- 3미터 넘게 움직였을 때만 다시 그림
  local zoom = (Minimap and Minimap.GetZoom and Minimap:GetZoom()) or 0
  local key = on and ("%d:%d:%d:%d:%d"):format(math.floor(px / 3), math.floor(py / 3), math.floor(tx), math.floor(ty), zoom) or "off"
  if key == LV.trailKey then return end
  LV.trailKey = key
  pcall(HBDP.RemoveAllWorldMapIcons, HBDP, LV.trailRefW)
  pcall(HBDP.RemoveAllMinimapIcons, HBDP, LV.trailRefM)
  if not on then return end
  local dx, dy = tx - px, ty - py
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 15 then
    ns.trail = nil
    Print("도착했어요! 점선 길을 껐어요")
    return
  end
  -- 세계 지도: 길이와 상관없이 고르게 최대 40개, 미니맵: 8미터 간격 (가까운 것만 보임)
  local nW = math.min(30, math.max(3, math.floor(dist / 100)))
  -- 미니맵 확대 정도에 맞춰 점 사이를 화면에서 약 11픽셀로 (붙어서 실선처럼 보이지 않게)
  local DIAM = { 466.67, 400, 333.33, 266.67, 200, 133.33 }
  local inside = IsIndoors and IsIndoors()
  local diam = inside and ({ 300, 240, 180, 120, 80, 50 })[zoom + 1] or DIAM[zoom + 1] or 466.67
  local mw = (Minimap and Minimap.GetWidth and Minimap:GetWidth()) or 140
  if type(mw) ~= "number" or mw <= 0 then mw = 140 end
  local stepM = diam / mw * 11
  local nM = math.min(40, math.floor(dist / stepM))
  local c = C.accent
  for i = 1, nW do
    local k = i / (nW + 1)
    local d = LV.trailW[i]
    d.t:SetVertexColor(c[1], c[2], c[3], 0.9)
    pcall(HBDP.AddWorldMapIconWorld, HBDP, LV.trailRefW, d, pinst, px + dx * k, py + dy * k, 0) -- 0 = 지역 지도에서만 (대륙 지도에선 굵은 선처럼 보여서 숨김)
  end
  for i = 1, nM do
    local k = (i * stepM) / dist
    if k >= 1 then break end
    local d = LV.trailM[i]
    d.t:SetVertexColor(c[1], c[2], c[3], 0.95)
    pcall(HBDP.AddMinimapIconWorld, HBDP, LV.trailRefM, d, pinst, px + dx * k, py + dy * k, false, false)
  end
end
ns.trailRefresh = function() LV.trailKey = nil; LV.UpdateTrail() end
do
  local tf, acc = CreateFrame("Frame"), 0
  tf:SetScript("OnUpdate", function(_, el)
    acc = acc + (el or 0)
    if acc < 0.4 then return end
    acc = 0
    if ns.trail or LV.trailKey ~= "off" then LV.UpdateTrail() end
  end)
end

-- Questie 목표 아이콘 중 아직 안 끝난 목표의 가장 가까운 곳 (지금 지도 우선)
function LV.QObjPos(e)
  -- 그 퀘스트 하나의 Questie 아이콘만 읽음 (전체를 훑으면 Questie가 느려짐), 5초 캐시
  local tnow = GetTime and GetTime() or 0
  LV.qobj = LV.qobj or {}
  local c = LV.qobj[e.id]
  if not c or tnow - c.t > 5 then
    c = { t = tnow, pts = {} }
    LV.qobj[e.id] = c
    local QM = QModule("QuestieMap")
    local frames = QM and type(QM.questIdFrames) == "table" and QM.questIdFrames[e.id]
    if type(frames) == "table" then
      for _, fname in pairs(frames) do
        local fr = type(fname) == "string" and _G[fname] or fname
        local d = type(fr) == "table" and fr.data
        if type(d) == "table" and d.ObjectiveIndex and fr.x and fr.y and fr.UiMapID and #c.pts < 300 then
          c.pts[#c.pts + 1] = { map = fr.UiMapID, x = fr.x, y = fr.y, npc = d.Name, idx = d.ObjectiveIndex }
        end
      end
    end
  end
  local pts = c.pts
  if #pts == 0 then return nil end
  local open = {}
  for _, p in ipairs(pts) do
    local o = e.objs and e.objs[p.idx]
    if not (o and o.done) then open[#open + 1] = p end
  end
  if #open == 0 then open = pts end
  local m = PlayerMapID()
  local px, py = PlayerPos()
  local p = BestPoint(open, m, px, py) or open[1]
  if p then return p.map, p.x, p.y, p.npc end
end

-- 이 퀘스트의 "하는 곳" 원: 같은 단계 → 같은 지역 다른 단계 → (못 맞춘 원이 하나뿐이면) 그 원
function LV.RingFor(z, gi, id)
  local function scan(S)
    for _, r in ipairs(S.rings or {}) do
      for _, q in ipairs(r[1]) do if q == id then return r[2], r[3] end end
    end
  end
  local x, y = scan(z.steps[gi] or {})
  if x then return x, y end
  for _, S in ipairs(z.steps) do x, y = scan(S); if x then return x, y end end
  local unk
  for _, r in ipairs((z.steps[gi] or {}).rings or {}) do
    for _, q in ipairs(r[1]) do if q == 0 then if unk then return nil end; unk = r end end
  end
  if unk then return unk[2], unk[3] end
end

-- 따라하기 단계를 간략 보기 단계 목록으로 바꿈
function LV.GuideSteps(log)
  local z = LV.GuideZone(log)
  if not z then return nil end
  CDB.guide.zone = z.slug
  local fl = CDB.guide.floor[z.slug] or 1
  local idx
  for i = fl, #z.steps do
    if not LV.StepDoneG(z.steps[i], log) then idx = i; break end
  end
  if not idx then return nil end
  -- 새 단계로 넘어오면 알림 + 요령
  local mark = z.slug .. ":" .. idx
  if LV.lastGuideMark and LV.lastGuideMark ~= mark then
    Print(("다음 단계: %s (%d/%d)"):format(z.steps[idx].t, idx, #z.steps))
  end
  if LV.lastGuideMark ~= mark then
    LV.lastGuideMark = mark
    for _, tip in ipairs(z.steps[idx].tips or {}) do Print("|cffe2a63b" .. tip .. "|r") end
  end
  local zmap = LV.GuideMap(z.name)
  local steps = {}
  local tnow = GetTime and GetTime() or 0
  if not QCache or tnow - (LV.qcT or -99) > 15 then LV.qcT = tnow; QCache = ReadQuestie() end
  local px, py = PlayerPos()
  local pm = PlayerMapID()
  local function add(S, gi)
    local seen = {}
    -- 1) 받기 (같은 NPC끼리)
    local byNpc = {}
    for _, g in ipairs(S.gets) do
      if not LV.GetDone(g, log) then
        local city = (g[7] or ""):match("([^|]+)에서") 
        local map = (city and LV.GuideMap(city)) or zmap
        local npc = (g[4] ~= "" and not g[4]:match("^Lv ") and g[4] ~= "포에버 신규") and g[4] or nil
        local gx, gy = g[5], g[6]
        -- 사이트에 위치가 없으면 Questie가 그리는 "!" 위치를 씀
        if not gx and QCache and QCache.avail and QCache.avail[g[1]] then
          local p = BestPoint(QCache.avail[g[1]].pts, pm, px, py)
          if p then gx, gy, npc = p.x, p.y, npc or p.npc; if p.map then map = p.map end end
        end
        local a = { kind = "get", key = Norm(g[2]), qid = g[1], title = g[2], level = g[3] > 0 and g[3] or nil,
                    x = gx, y = gy, map = map, zone = city or z.name, npc = npc, guide = true,
                    note = (g[7] or ""):find("받아만") and "받아만 둬요" or nil }
        local k = (npc or g[2]) .. (city or "")
        local st = byNpc[k]
        if st then st.acts[#st.acts + 1] = a
        else
          st = { kind = "go", acts = { a }, npcs = npc and { npc } or {}, x = gx, y = gy, map = map, zone = city or z.name, gstep = gi, unknown = not gx or nil }
          byNpc[k] = st
          steps[#steps + 1] = st
        end
      end
    end
    -- 2) 하기 (이 단계 퀘스트 중 진행 중인 것)
    local ids = {}
    for _, g in ipairs(S.gets) do ids[#ids + 1] = g[1] end
    for _, t in ipairs(S.turns) do for _, q in ipairs(LV.TurnIds(t)) do ids[#ids + 1] = q.id end end
    for _, id in ipairs(ids) do
      local e = logById[id]
      if e and e.state == 1 and not seen[id] and not IsSkipped(e.key, log) then
        seen[id] = true
        local hs = { kind = "hunt", key = e.key, qid = id, title = e.title, e = e, zone = z.name, level = e.level, gstep = gi }
        -- 사이트 지도의 점선 원(하는 곳)
        local rx, ry = LV.RingFor(z, gi, id)
        if rx then hs.ox, hs.oy, hs.omap = rx, ry, zmap end
        steps[#steps + 1] = hs
      end
    end
    -- 3) 반납 (목표를 끝낸 것)
    for _, t in ipairs(S.turns) do
      local acts = {}
      local city = (t[2] ~= "" and t[2]) or nil
      local map = (city and LV.GuideMap(city)) or zmap
      for _, q in ipairs(LV.TurnIds(t)) do
        local e = logById[q.id]
        if e and e.state == 2 and not IsSkipped(e.key, log) then
          acts[#acts + 1] = { kind = "turn", key = e.key, qid = q.id, title = e.title, level = e.level, x = t[3], y = t[4],
                              map = map, zone = city or z.name, npc = t[1], e = e, guide = true }
        end
      end
      if #acts > 0 then
        steps[#steps + 1] = { kind = "go", acts = acts, npcs = { t[1] }, x = t[3], y = t[4], map = map, zone = city or z.name, gstep = gi }
      end
    end
  end
  add(z.steps[idx], idx)
  local nNow = #steps
  -- 그다음에 보여 줄 게 적으면 다음 단계들을 더 이어 붙임 (최대 3단계 앞까지)
  local j = idx + 1
  while #steps < 6 and z.steps[j] and j <= idx + 3 do add(z.steps[j], j); j = j + 1 end
  LV.guideNow = { zone = z, idx = idx, nNow = nNow }
  -- 간략 보기 머리글이 좁아서 단계 이름을 앞에 (지역 이름은 마우스를 올리면)
  return steps, ("%d/%d %s"):format(idx, #z.steps, z.steps[idx].t)
end

-- 창 위쪽은 그대로 두고 아래로만 늘고 줄게 (위 = 미니맵, 아래 = 미터기)
local OBSTACLES = { "DetailsBaseFrame1", "DetailsBaseFrame2", "DetailsBaseFrame3", "SkadaBarWindowSkada",
                    "Recount_MainWindow", "TinyDPSFrame" }
function LV.AvailH()
  local top = f:GetTop()
  if not top then return nil end
  local s = f:GetEffectiveScale()
  local fl, fr = (f:GetLeft() or 0) * s, (f:GetRight() or 0) * s
  local limit = 20
  for _, n in ipairs(OBSTACLES) do
    local o = _G[n]
    if o and o.IsShown and o:IsShown() and o:GetTop() then
      local os = o:GetEffectiveScale()
      local ol, or2, ot = (o:GetLeft() or 0) * os, (o:GetRight() or 0) * os, o:GetTop() * os
      if or2 > fl and ol < fr and ot < top * s then
        limit = math.max(limit, ot + 28 * os)   -- 미터기 제목 줄 자리까지
      end
    end
  end
  return top - limit / s - 6
end
function LV.KeepTop()
  if InCombatLockdown and InCombatLockdown() and f:IsProtected() then return end
  local l, t = f:GetLeft(), f:GetTop()
  if not (l and t) or f.leelMoving then return end
  local p = DB.point
  if p and p[1] == "TOPLEFT" and p[2] == "BOTTOMLEFT" and math.abs((p[3] or 0) - l) < 0.5 and math.abs((p[4] or 0) - t) < 0.5 then return end
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
  DB.point = { "TOPLEFT", "BOTTOMLEFT", l, t }
end

-- 아래 가장자리 손잡이: 위아래(높이)만 마우스로 조절 (폭은 그대로)
do
  local g = CreateFrame("Button", nil, f)
  g:SetHeight(10)
  g:SetPoint("BOTTOMLEFT", 30, 0); g:SetPoint("BOTTOMRIGHT", -30, 0)
  g:SetFrameLevel(f:GetFrameLevel() + 20)
  local bar = g:CreateTexture(nil, "OVERLAY")
  bar:SetSize(36, 4); bar:SetPoint("CENTER", 0, 1)
  bar:SetColorTexture(1, 1, 1, 0.18)
  g:SetScript("OnEnter", function()
    bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.9)
    GameTooltip:SetOwner(g, "ANCHOR_BOTTOM")
    GameTooltip:SetText("위아래로 끌어서 높이 조절")
    GameTooltip:AddLine("오른쪽 클릭: 자동 높이로 되돌리기", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  g:SetScript("OnLeave", function() if not g.drag then bar:SetColorTexture(1, 1, 1, 0.18) end; GameTooltip:Hide() end)
  g:RegisterForClicks("RightButtonUp")
  g:SetScript("OnClick", function() if DB then DB.miniMaxH = nil; if Render then Render() end end end)
  g:SetScript("OnMouseDown", function(self, btn)
    if btn ~= "LeftButton" or not DB or DB.mode ~= "mini" then return end
    if LV.KeepTop then LV.KeepTop() end
    local _, cy = GetCursorPosition()
    self.drag = { y = cy / f:GetEffectiveScale(), h = f:GetHeight() }
    self:SetScript("OnUpdate", function()
      local _, ny = GetCursorPosition()
      ny = ny / f:GetEffectiveScale()
      local want = math.max(110, math.floor(self.drag.h + (self.drag.y - ny)))
      if not self.last or math.abs(self.last - want) >= 6 then
        self.last = want
        DB.miniMaxH = want
        if Render then Render() end
      end
    end)
  end)
  g:SetScript("OnMouseUp", function(self)
    self:SetScript("OnUpdate", nil); self.drag = nil; self.last = nil
    bar:SetColorTexture(1, 1, 1, 0.18)
  end)
  LV.sizeGrip = g
end

local function RenderMini(b, log, lv)
  f:SetWidth(MINI_W)
  cGoto:SetWidth(MINI_W - 2 * PAD - 60 - 52)
  cSub:SetWidth(MINI_W - 2 * PAD - 60 - 10)
  local pz = PlayerZone()
  local zi = 1
  for i, zz in ipairs(b.zones) do if zz.name == pz then zi = i end end
  local z = b.zones[zi]

  local tDone, tAll = 0, 0
  for _, zz in ipairs(b.zones) do
    for _, q in ipairs(zz.quests) do
      tAll = tAll + 1
      if QuestState(q, log) == 3 then tDone = tDone + 1 end
    end
  end
  zoneFS:SetText(z.name)
  rangeFS:SetText(tDone .. " / " .. tAll)
  progFS:SetText(col("muted", tDone .. "/" .. tAll))
  barFill:SetWidth(math.max(1, (MINI_W - 2 * PAD) * (tAll > 0 and tDone / tAll or 0)))

  miniSortB:SetText(DB.sort == "guide" and "따라하기" or DB.sort == "plan" and "계획" or DB.sort == "route" and "경로순" or DB.sort == "hub" and "거점순" or "레벨순")
  miniSortB:SetActive(false)
  local steps, _, rz = Route(b, log, lv, zi, true)
  local px, py = PlayerPos()
  if rz and rz.name then zoneFS:SetText(rz.name) end
  -- 던전 안 / 던전에서 막 나왔을 때
  local dsteps, dtitle = LV.DungeonSteps(steps, log)
  if dsteps then
    steps = dsteps
    zoneFS:SetText(dtitle)
  end

  local cur = steps[1]
  local yy = C.__cute and 18 or 6
  card:ClearAllPoints()
  card:SetPoint("TOPLEFT", PAD, -yy)
  card:SetPoint("TOPRIGHT", -PAD, -yy)
  for _, t in ipairs(todos) do t:Hide() end
  for _, d in ipairs(dots) do d:Hide() end
  for _, r in ipairs(nexts) do r:Hide() end

  compass.tx = nil
  LV.pinWant = nil
  if not cur then
    cNum:SetText("")
    cOf:SetText("")
    cBig:SetText("")
    if LV.bubble then LV.bubble:Hide() end
    if LV.chip then LV.chip:Hide() end
    CompassTint(C.line2)
    Backdrop(card, { 1, 1, 1, 0.03 }, C.line2)
    if LV.Instance() and LV.dungeonNote == "scanning" then
      cGoto:SetText("던전 퀘스트를 찾는 중이에요")
      cSub:SetText("잠시만 기다려 주세요.")
    elseif LV.Instance() then
      cGoto:SetText("이 던전 퀘스트가 없어요")
      cSub:SetText("퀘스트 목록에 이 던전 퀘스트가 없고, 받을 수 있는 퀘스트도 찾지 못했어요.")
    elseif DB.sort == "plan" and planNote == "none" then
      cGoto:SetText("아직 만든 루트가 없어요")
      cSub:SetText("아래 루트 만들기를 눌러 주세요.")
    elseif DB.sort == "plan" and planNote == "other" then
      cGoto:SetText("다른 지역용 루트예요")
      cSub:SetText("이 지역에서 루트 만들기를 다시 눌러 주세요.")
    elseif DB.sort == "plan" then
      cGoto:SetText("루트를 다 끝냈어요")
      cSub:SetText("루트 만들기를 다시 누르면 새로 받을 퀘스트로 이어서 짜요.")
    else
      cGoto:SetText("이 지역에서 할 일이 없어요")
      cSub:SetText("자세히 보기에서 다른 지역이나 다음 구간을 확인해 보세요.")
    end
    wpBtn:Hide(); mapBtn:Hide(); skipBtn:Hide()
    card:SetHeight(84)
    yy = yy + 84
    thenFS:Hide()
    miniSortB:ClearAllPoints()
    miniSortB:SetPoint("TOPRIGHT", miniRoot, "TOPRIGHT", -PAD, -(yy + 6))
    miniSortB:Show()
    yy = yy + 30
  else
    cNum:SetText("1")
    cOf:SetText("/ " .. #steps)
    cBig:SetText("1")
    -- 제목이 오른쪽 위 단계 번호(1 / 45)와 겹치지 않게 폭을 실제 글자 폭으로 계산
    do
      local numW = (cBig:GetStringWidth() or 10) + (cOf:GetStringWidth() or 24) + 3 + 10
      cGoto:SetWidth(math.max(80, (MINI_W - 2 * PAD) - 60 - numW - 8))
    end
    local isHunt = cur.kind == "hunt"
    local tint = isHunt and C.warn or C.accent
    -- 사냥 단계는 카드 전체를 붉게 (시안처럼 한눈에 구분)
    Backdrop(card, { tint[1], tint[2], tint[3], isHunt and 0.20 or 0.10 }, { tint[1], tint[2], tint[3], isHunt and 0.85 or 0.70 })
    CompassTint(tint)
    cBig:SetTextColor(tint[1], tint[2], tint[3])
    -- 귀여운 테마: 오른쪽 위 말풍선 알약 ("지금 할 일 1 / 37")
    if not LV.bubble then
      LV.bubble = CreateFrame("Frame", nil, card, BD)
      local okL, lvl = pcall(card.GetFrameLevel, card)
      LV.bubble:SetFrameLevel(((okL and type(lvl) == "number") and lvl or 1) + 5)
      LV.bubble.__round = 10
      LV.bubble:SetHeight(20)
      LV.bubble.t = FS(LV.bubble, 11, C.bg, "CENTER")
      LV.bubble.t:SetPoint("CENTER", 0, 0)
    end
    if C.__cute then
      cBig:SetText(""); cOf:SetText("")
      LV.bubble.t:SetText(((isHunt and "사냥 중! " or "지금 할 일 ") .. "1 / " .. #steps))
      LV.bubble.t:SetTextColor(C.bg[1], C.bg[2], C.bg[3])
      LV.bubble.t:SetShadowColor(0, 0, 0, 0)
      LV.bubble:SetWidth((LV.bubble.t:GetStringWidth() or 60) + 18)
      Backdrop(LV.bubble, tint, tint)
      LV.bubble:ClearAllPoints()
      LV.bubble:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, 10)
      LV.bubble:Show()
      cGoto:SetWidth((MINI_W - 2 * PAD) - 60 - 14)
    else
      LV.bubble:Hide()
    end

    -- 장소 단계: 아직 안 끝난 첫 할 일을 목표로 (제목, 좌표, 웨이포인트 모두)
    local tgt, tx, tyy, tzone
    if cur.kind ~= "hunt" and cur.acts then
      local undoneNpcs, seen = {}, {}
      for _, a in ipairs(cur.acts) do
        if not ActDone(a, log) then
          if not tgt and a.x then tgt = a end
          local nm = a.npc or (a.fromGame and ("반납:" .. a.title)) or nil
          if nm and not seen[nm] then seen[nm] = true; undoneNpcs[#undoneNpcs + 1] = nm end
        end
      end
      if tgt then
        tx, tyy, tzone = tgt.x, tgt.y, tgt.zone or cur.zone
        local others = #undoneNpcs - 1
        if tgt.fromGame then
          cGoto:SetText("반납하러 가세요")
        elseif tgt.npc then
          cGoto:SetText(tgt.npc .. (others > 0 and (" 외 " .. others .. "명") or "") .. "에게 가세요")
        else
          cGoto:SetText(StepTitle(cur, pz))
        end
      else
        cGoto:SetText(StepTitle(cur, pz))
      end
    else
      if C.__cute then
        cGoto:SetText((StepTitle(cur, pz):gsub("^%d+%.%s+", "")))
      else
        cGoto:SetText(LV.WithTag(LV.LvTag(LV.HuntLevel(cur)), StepTitle(cur, pz)))
      end
    end
    local sub = {}
    local hz, hx, hy, hsrc, hmap
    if cur.kind == "hunt" then
      local e = logByKey[cur.key] or cur.e
      local qn
      hz, hx, hy, hsrc, hmap, qn = HuntPos(cur.key, e and e.id, e)
      if qn then cur.qnpc = qn end
      if not hx and cur.ox then hz, hx, hy, hsrc, hmap = pz, cur.ox, cur.oy, "questie", cur.omap end
      if hx then
        if hz and hz ~= pz then sub[#sub + 1] = "|cffffc27a→ " .. hz .. "|r" end
        if cur.qnpc then sub[#sub + 1] = cur.qnpc end
        sub[#sub + 1] = (hsrc == "learned" and "지난번 진행한 곳 " or hsrc == "questie" and "수행 지역 " or "수행 위치 ") .. ("%.1f, %.1f"):format(hx, hy)
        if hz == pz then
          local dir = DirShort(px, py, hx, hy)
          if dir then sub[#sub + 1] = dir end
        end
        compass.tx, compass.ty, compass.sameMap = hx, hy, (hz == pz)
        LV.pinWant = { map = hmap or (hz and D.maps[hz]) or (hz == pz and PlayerMapID()) or nil, x = hx, y = hy, label = cur.qnpc or cur.title }
      else
        sub[#sub + 1] = "지도에서 보기로 수행 지역을 확인하세요"
      end
    elseif tx or cur.x then
      local gx, gy, gz = tx or cur.x, tyy or cur.y, tzone or cur.zone
      if gz and gz ~= pz then sub[#sub + 1] = "|cffffc27a→ " .. gz .. "|r" end
      sub[#sub + 1] = ("%.1f, %.1f"):format(gx, gy)
      if gz == pz then
        local dir = DirShort(px, py, gx, gy)
        if dir then sub[#sub + 1] = dir end
      end
      compass.tx, compass.ty, compass.sameMap = gx, gy, (gz == pz)
      LV.pinWant = { map = (tgt and tgt.map) or cur.map or (gz and D.maps[gz]) or (gz == pz and PlayerMapID()) or nil, x = gx, y = gy,
                     label = (tgt and tgt.npc) or (cur.npcs and cur.npcs[1]) or LV.Plain(cGoto:GetText()) }
    end
    if cur.kind ~= "hunt" and not tx and not cur.x and not cur.unknown then
      local isTurn = cur.acts and cur.acts[1] and cur.acts[1].kind == "turn"
      if isTurn then
        sub[#sub + 1] = "반납 위치 정보가 없어요. 퀘스트 로그의 반납 안내나 지도의 ? 표시를 확인해 주세요"
      else
        sub[#sub + 1] = "시작 위치 정보가 없어요. 아이템을 주워서 시작하거나 게시판에서 받는 퀘스트일 수 있어요. 못 찾겠으면 건너뛰기를 눌러 주세요"
      end
    end
    cSub:SetText(table.concat(sub, "  "))

    -- 귀여운 테마: 레벨을 말랑한 알약으로 ("레벨 딱 맞아요 [19]")
    if not LV.chip then
      LV.chip = CreateFrame("Frame", nil, card, BD)
      LV.chip.__round = 8
      LV.chip:SetHeight(16)
      LV.chip.t = FS(LV.chip, 10, C.ok, "CENTER")
      LV.chip.t:SetPoint("CENTER", 0, 0)
    end
    local chipLv = cur.kind == "hunt" and LV.HuntLevel(cur) or nil
    local chipOn = C.__cute and chipLv and chipLv > 0
    if chipOn then
      local d = chipLv - (UnitLevel("player") or 1)
      local word, cc
      if d >= 5 then word, cc = "많이 어려워요", C.warn
      elseif d >= 3 then word, cc = "조금 어려워요", C.warn
      elseif d >= -2 then word, cc = "레벨 딱 맞아요", C.ok
      elseif not LV.IsGrey(chipLv) then word, cc = "쉬워요", C.ok
      else word, cc = "너무 쉬워요", C.muted end
      LV.chip.t:SetText(("%s  [%d]"):format(word, chipLv))
      LV.chip.t:SetTextColor(cc[1], cc[2], cc[3])
      LV.chip.t:SetShadowColor(0, 0, 0, 0)
      LV.chip:SetWidth((LV.chip.t:GetStringWidth() or 60) + 16)
      Backdrop(LV.chip, { cc[1], cc[2], cc[3], 0.16 }, { cc[1], cc[2], cc[3], 0.45 })
      LV.chip:ClearAllPoints()
      if cSub:GetText() and cSub:GetText() ~= "" then
        LV.chip:SetPoint("TOPLEFT", cSub, "BOTTOMLEFT", 0, -4)
      else
        LV.chip:SetPoint("TOPLEFT", cGoto, "BOTTOMLEFT", 0, -4)
      end
      LV.chip:Show()
    else
      LV.chip:Hide()
    end

    -- 할 일 목록
    local subH = (cSub:GetText() and cSub:GetText() ~= "") and math.max(12, cSub:GetStringHeight() or 12) or 0
    if chipOn then subH = subH + 20 end
    local gotoH = math.max(16, cGoto:GetStringHeight() or 16)
    local ty = -12 - math.max(42, gotoH + 3 + subH) - 10
    local items = {}
    if cur.kind == "hunt" then
      local e = logByKey[cur.key] or cur.e
      for _, o in ipairs(e and e.objs or {}) do
        items[#items + 1] = { text = o.text, done = o.done, cnt = (o.have and o.need) and (o.have .. "/" .. o.need) or nil,
                              have = o.have, need = o.need, hunt = true }
      end
    else
      for _, a in ipairs(cur.acts) do
        items[#items + 1] = { text = ((a.n and not C.__cute) and (a.n .. ".  ") or "") .. LV.LvTag(LV.ActLevel(a)) .. a.title .. (a.chain and (" (연계 " .. (a.chain + 1) .. "편)") or "") .. (a.kind == "turn" and " 반납" or " 받기"), done = ActDone(a, log), turn = a.kind == "turn", act = a }
      end
    end
    -- 사냥 목표가 2개 이상이면 작은 칸 2열로 (창이 길어지지 않게)
    local twoCol = false -- 2열은 이름이 잘려서 안 씀 (한 줄 모양 유지)
    local cellW = math.floor((MINI_W - 2 * PAD - 24 - 4) / 2)
    for i, it in ipairs(items) do
      local t = GetTodo(i)
      t:ClearAllPoints()
      t.full = nil
      if twoCol then
        local col = (i - 1) % 2
        t:SetPoint("TOPLEFT", card, "TOPLEFT", 12 + col * (cellW + 4), ty)
        t:SetWidth(cellW)
        t:SetHeight(28)
        t.badge:Hide()
        LeelFont(t.fs, 10, "")
        t.fs:SetWordWrap(false)
        t.fs:ClearAllPoints(); t.fs:SetPoint("TOPLEFT", t, "TOPLEFT", 6, -5)
        LeelFont(t.cnt, 10, "")
        t.cnt:ClearAllPoints(); t.cnt:SetPoint("TOPRIGHT", -5, -5)
        t.cnt:SetText(it.cnt or "")
        local cw2 = (it.cnt and it.cnt ~= "") and ((t.cnt:GetStringWidth() or 24) + 4) or 0
        t.fs:SetWidth(cellW - 11 - cw2)
        t.fs:SetText(it.text)
        t.full = it.text .. (it.cnt and ("  " .. it.cnt) or "")
        local dc = it.done and C.faint or C.text
        t.fs:SetTextColor(dc[1], dc[2], dc[3]); t.cnt:SetTextColor(dc[1], dc[2], dc[3])
        local rc = it.done and { C.row[1], C.row[2], C.row[3], C.row[4] * 0.55 } or C.row
        if C.__cute then t.bg:Hide(); Backdrop(t, rc, rc) else t.bg:SetColorTexture(rc[1], rc[2], rc[3], rc[4]); t.bg:Show(); if t.SetBackdrop then t:SetBackdrop(nil) end end
        t.track:ClearAllPoints(); t.track:SetPoint("BOTTOMLEFT", 6, 5); t.track:SetPoint("BOTTOMRIGHT", -5, 5)
        t.track:SetHeight(3); t.fill:SetHeight(3)
        if it.have and it.need and it.need > 0 then
          t.track:Show(); t.fill:Show()
          t.fill:SetWidth(math.max(1, (cellW - 11) * math.min(1, it.have / it.need)))
          local fc = it.done and C.ok or C.hunt
          t.fill:SetColorTexture(fc[1], fc[2], fc[3], 1)
        else
          t.track:Hide(); t.fill:Hide()
        end
        t.act, t.zone = nil, cur.zone
        t:EnableMouse(true)
        t:Show()
        if col == 1 or i == #items then ty = ty - 28 - 4 end
      else
      -- 한 줄짜리(기본) 모양으로 되돌림
      t.badge:Show()
      LeelFont(t.fs, 12, "")
      t.fs:SetWordWrap(true)
      t.fs:ClearAllPoints(); t.fs:SetPoint("TOPLEFT", t, "TOPLEFT", 28, -6)
      LeelFont(t.cnt, 11, "")
      t.cnt:ClearAllPoints(); t.cnt:SetPoint("TOPRIGHT", -8, -6)
      t.track:ClearAllPoints(); t.track:SetPoint("BOTTOMLEFT", 28, 6); t.track:SetPoint("BOTTOMRIGHT", -8, 6)
      t.track:SetHeight(5); t.fill:SetHeight(5)
      t:SetPoint("TOPLEFT", card, "TOPLEFT", 12, ty)
      t:SetPoint("RIGHT", card, "RIGHT", -12, 0)
      local iconTex = it.done and ICON.ok or it.hunt and ICON.hunt or it.turn and ICON.turn or ICON.get
      t.badge:SetKind(it.done and "ok" or it.hunt and "hunt" or it.turn and "turn" or "get")
      if it.done then
        t.fs:SetTextColor(C.faint[1], C.faint[2], C.faint[3])
        t.cnt:SetTextColor(C.faint[1], C.faint[2], C.faint[3])
        t.bg:SetColorTexture(C.row[1], C.row[2], C.row[3], C.row[4] * 0.55)
        if C.__cute then t.bg:Hide(); Backdrop(t, { C.row[1], C.row[2], C.row[3], C.row[4] * 0.55 }, { C.row[1], C.row[2], C.row[3], 0.6 }) else t.bg:Show(); if t.SetBackdrop then t:SetBackdrop(nil) end end
      else
        t.fs:SetTextColor(C.text[1], C.text[2], C.text[3])
        t.cnt:SetTextColor(C.text[1], C.text[2], C.text[3])
        t.bg:SetColorTexture(C.row[1], C.row[2], C.row[3], C.row[4])
        if C.__cute then t.bg:Hide(); Backdrop(t, C.row, C.row) else t.bg:Show(); if t.SetBackdrop then t:SetBackdrop(nil) end end
      end
      t.cnt:SetText(it.cnt or "")
      local inner = MINI_W - 2 * PAD - 24
      -- 개수(1/60) 실제 폭만큼 비워서 글자와 겹치지 않게
      local cntW = (it.cnt and it.cnt ~= "") and ((t.cnt:GetStringWidth() or 30) + 10) or 0
      t.fs:SetWidth(inner - 28 - 8 - cntW)
      t.fs:SetText(it.text)
      local th = math.max(26, (t.fs:GetStringHeight() or 14) + 12)
      local showBar = it.hunt and it.have and it.need and it.need > 0
      if showBar then
        th = th + 8
        t.track:Show(); t.fill:Show()
        local frac = math.min(1, it.have / it.need)
        t.fill:SetWidth(math.max(1, (inner - 36) * frac))
        local fc = it.done and C.ok or C.hunt
        t.fill:SetColorTexture(fc[1], fc[2], fc[3], 1)
      else
        t.track:Hide(); t.fill:Hide()
      end
      t:SetHeight(th)
      t.act, t.zone = it.act, cur.zone
      t:EnableMouse(it.act ~= nil and it.act.x ~= nil)
      t:Show()
      ty = ty - th - 4
      end
    end

    local huntId = cur.kind == "hunt" and ((logByKey[cur.key] or cur.e or {}).id) or nil
    local hasWp = (cur.x ~= nil) or (hx ~= nil) or (tx ~= nil)
    if wpFollow and wpFollow.step == cur and tgt and wpFollow.key ~= tgt.key then
      wpFollow.key = tgt.key
      SetWaypoint(tgt.map or D.maps[tzone], tx, tyy, LV.Plain(cGoto:GetText()) or StepTitle(cur))
    end
    -- 퀘스트(지금 할 일)가 바뀌면 자동으로 그 위치까지 길 안내
    if DB.autoWay ~= false and hasWp then
      local wayKey = tostring(cur.key or StepTitle(cur)) .. "|" .. tostring(tgt and tgt.key) .. "|" .. tostring(hx)
      if LV.autoWayKey ~= wayKey then
        LV.autoWayKey = wayKey
        if hx then
          AutoWaypoint(hmap or (hz and D.maps[hz]), hx, hy, StepTitle(cur))
        else
          AutoWaypoint((tgt and tgt.map) or D.maps[tzone or cur.zone], tx or cur.x, tyy or cur.y,
            LV.Plain(cGoto:GetText()) or StepTitle(cur))
          wpFollow = { step = cur, key = tgt and tgt.key }
        end
      end
    end
    wpBtn:Hide(); mapBtn:Hide(); skipBtn:Hide()
    local function doSkip()
      local names = {}
      if cur.kind == "hunt" then
        CDB.skip[cur.key] = "hunt"
        names[#names + 1] = cur.title
      else
        for _, a in ipairs(cur.acts or {}) do
          if a.key and not ActDone(a, log) then
            CDB.skip[a.key] = a.kind
            names[#names + 1] = a.title
          end
        end
      end
      snap, wpFollow = nil, nil
      Print("건너뜀: " .. table.concat(names, ", ") .. "  |cff8a9099자세히 보기에서 오른쪽 클릭하면 되돌려요|r")
      Render()
    end

    -- 오른쪽 아래 아이콘: [웨이포인트] [지도] [건너뛰기]
    ty = ty - 4
    local xr = -10
    skipBtn:ClearAllPoints()
    skipBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", xr, ty)
    skipBtn:SetScript("OnClick", doSkip)
    skipBtn:Show()
    xr = xr - 28
    if huntId then
      mapBtn:ClearAllPoints()
      mapBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", xr, ty)
      mapBtn:SetScript("OnClick", function()
        OpenQuestOnMap(huntId, cur.title)
        -- 게임이 수행 지역을 모르는 퀘스트도 애드온 핀(호박색 원)이 보이게 그 지도를 띄움
        local w = LV.pinWant
        if w and w.map and WorldMapFrame and WorldMapFrame.SetMapID and not (InCombatLockdown and InCombatLockdown()) then
          pcall(WorldMapFrame.SetMapID, WorldMapFrame, w.map)
        end
      end)
      mapBtn:Show()
      xr = xr - 28
    end
    if hasWp then
      wpBtn:ClearAllPoints()
      wpBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", xr, ty)
      if hx then
        wpBtn:SetScript("OnClick", function() SetWaypoint(hmap or (hz and D.maps[hz]), hx, hy, StepTitle(cur)) end)
      else
        wpBtn:SetScript("OnClick", function()
          local gx, gy, gz = tx or cur.x, tyy or cur.y, tzone or cur.zone
          SetWaypoint((tgt and tgt.map) or D.maps[gz], gx, gy, LV.Plain(cGoto:GetText()) or StepTitle(cur))
          wpFollow = { step = cur, key = tgt and tgt.key }
        end)
      end
      wpBtn:Show()
    end
    ty = ty - 24
    card:SetHeight(-ty + 10)
    yy = yy + (-ty + 10)

    -- 그다음 + 정렬 버튼
    miniSortB:ClearAllPoints()
    miniSortB:SetPoint("TOPRIGHT", miniRoot, "TOPRIGHT", -PAD, -(yy + 6))
    miniSortB:Show()
    if #steps > 1 then
      thenFS:ClearAllPoints()
      thenFS:SetPoint("LEFT", miniRoot, "TOPLEFT", PAD, -(yy + 16))
      thenFS:SetText("그다음")
      thenFS:Show()
      yy = yy + 30
      -- 단계마다 위치 (구역이 바뀌는지 보려고)
      local function StepPos(st)
        if st.kind == "hunt" then
          local e = logByKey[st.key] or st.e
          local _, x, y2 = HuntPos(st.key, e and e.id, e)
          if x then return x, y2 end
          return st.ox, st.oy
        end
        return st.x, st.y
      end
      -- 단계가 있는 큰 지역 이름 (작은 장소가 아니라 돌발톱 산맥 같은 지역)
      local function StepZone(st)
        if st.kind == "hunt" then
          local e = logByKey[st.key] or st.e
          local hz = HuntPos(st.key, e and e.id, e)
          if hz then return hz end
        end
        return st.zone or pz
      end
      local function AreaName(st)
        if st.kind == "hunt" then
          local e = logByKey[st.key] or st.e
          local o = e and e.objs and e.objs[1]
          return "사냥터" .. (o and o.text and (" · " .. o.text:gsub("%s*처치$", "")) or "")
        end
        return st.npcs and st.npcs[1] and (st.npcs[1] .. " 근처") or nil
      end
      local lastN = math.min(#steps, LV.nextCap or 4) -- 그다음은 3개까지 (아래 창에 닿으면 줄여요)
      local prevX, prevY = StepPos(cur)
      local prevZone = cur.zone
      local prevG = cur.gstep
      local shownZone = nil
      for i = 2, lastN do
        local st = steps[i]
        local r = GetNext(i - 1)
        r.step = st
        local x, y2 = StepPos(st)
        -- 지역 구분선: 첫 줄과 지역이 바뀌는 곳
        local zn = StepZone(st)
        local zTop = 0
        if zn and zn ~= shownZone then
          shownZone = zn
          zTop = 20
          if zn == pz then
            r.zone:SetText("● " .. zn .. " (여기)")
            r.zone:SetTextColor(0.55, 0.84, 0.75)
            r.zoneLine:SetColorTexture(0.55, 0.84, 0.75, 0.35)
          else
            r.zone:SetText("→ " .. zn)
            r.zone:SetTextColor(1, 0.76, 0.48)
            r.zoneLine:SetColorTexture(1, 0.76, 0.48, 0.35)
          end
        end
        r.zone:SetShown(zTop > 0)
        r.zoneLine:SetShown(zTop > 0)
        local newArea = (st.zone ~= prevZone) or (x and prevX and Dist(x, y2, prevX, prevY) > 8) or (x and not prevX)
        local an = newArea and AreaName(st) or nil
        -- 따라하기: 다음 단계로 넘어가는 곳은 단계 이름을 소제목으로
        if st.gstep and st.gstep ~= prevG and LV.guideNow and LV.guideNow.zone.steps[st.gstep] then
          an = ("%d단계 · %s"):format(st.gstep, LV.guideNow.zone.steps[st.gstep].t)
        end
        prevG = st.gstep or prevG
        local top = (an and 20 or 0) + zTop
        r.area:ClearAllPoints()
        r.area:SetPoint("TOPLEFT", 0, -4 - zTop)
        r.area:SetText(an or "")
        r.area:SetShown(an ~= nil)
        r.areaLine:SetShown(an ~= nil)
        r.t:ClearAllPoints()
        r.t:SetPoint("TOPLEFT", 28, -4 - top)
        r.t:SetPoint("RIGHT", -2, 0)
        r.icon:ClearAllPoints()
        r.icon:SetPoint("TOPLEFT", 0, -3 - top)
        local kind = st.kind == "hunt" and "hunt" or (st.acts and st.acts[1] and st.acts[1].kind == "turn" and "turn") or "get"
        r.icon:SetKind(kind)
        r.icon:Show()
        r.vline:ClearAllPoints()
        r.vline:SetPoint("TOP", r, "TOPLEFT", 9, -21 - top)
        r.vline:SetPoint("BOTTOM", r, "BOTTOMLEFT", 9, -4)
        r.vline:SetShown(i < lastN)
        if C.__cute then
          -- 번호는 빼고 레벨 색 태그만
          r.t:SetText(LV.WithTag(st.kind == "hunt" and LV.LvTag(LV.HuntLevel(st)) or "", ((st.titleText or ""):gsub("^%d+%.%s+", ""))))
        else
          r.t:SetText(LV.WithTag(st.kind == "hunt" and LV.LvTag(LV.HuntLevel(st)) or "", st.titleText))
        end
        r.s:ClearAllPoints()
        r.s:SetPoint("TOPLEFT", r.t, "BOTTOMLEFT", 0, -2)
        r.s:SetPoint("RIGHT", -2, 0)
        local sm = StepSummary(st)
        if st.kind ~= "hunt" then sm = LV.StepLevelTags(st) .. sm end
        r.s:SetText(sm)
        r.co:SetText("")
        r:EnableMouse(st.x ~= nil)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", miniRoot, "TOPLEFT", PAD, -yy)
        r:SetPoint("RIGHT", miniRoot, "RIGHT", -PAD, 0)
        r:SetHeight(36 + top)
        r:Show()
        yy = yy + 36 + top
        if x then prevX, prevY = x, y2 end
        prevZone = st.zone
      end
      if #steps > lastN then
        local r = GetNext(lastN)
        r.step = nil
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", miniRoot, "TOPLEFT", PAD, -yy)
        r:SetPoint("RIGHT", miniRoot, "RIGHT", -PAD, 0)
        r.area:Hide(); r.areaLine:Hide(); r.vline:Hide(); r.zone:Hide(); r.zoneLine:Hide()
        r.icon:Hide()
        r.t:SetText("")
        r.s:ClearAllPoints()
        r.s:SetPoint("TOPLEFT", 28, -2)
        r.s:SetText(("단계 %d개 더 남았어요"):format(#steps - lastN))
        r.co:SetText("")
        r:EnableMouse(false)
        r:SetHeight(20)
        r:Show()
        yy = yy + 20
      end
    else
      thenFS:Hide()
      yy = yy + 30
    end
  end

  -- 응원 한 줄 (귀여운 테마)
  if not LV.cheer then
    LV.cheer = CreateFrame("Frame", nil, miniRoot, BD)
    LV.cheer:SetHeight(22)
    LV.cheer.t = FS(LV.cheer, 11, C.accent)
    LV.cheer.t:SetPoint("LEFT", 8, 0)
    LV.cheer.t:SetPoint("RIGHT", -8, 0)
  end
  if C.__cute then
    local today = date and date("%Y-%m-%d") or ""
    local n = (CDB.today and CDB.today.d == today and CDB.today.n) or 0
    local xp, xm = UnitXP and UnitXP("player") or 0, UnitXPMax and UnitXPMax("player") or 1
    local pct = xm > 0 and math.floor((1 - xp / xm) * 100 + 0.5) or 0
    local msg = n > 0 and ("오늘 반납 %d개 · 다음 레벨까지 %d%%"):format(n, pct) or ("다음 레벨까지 %d%%"):format(pct)
    LV.cheer.t:SetText(msg)
    LV.cheer.__round = 10
    Backdrop(LV.cheer, { C.accent[1], C.accent[2], C.accent[3], 0.14 }, { C.accent[1], C.accent[2], C.accent[3], 0.35 })
    LV.cheer.t:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
    LV.cheer:ClearAllPoints()
    LV.cheer:SetPoint("TOPLEFT", miniRoot, "TOPLEFT", PAD, -(yy + 4))
    LV.cheer:SetPoint("RIGHT", miniRoot, "RIGHT", -PAD, 0)
    LV.cheer:Show()
    yy = yy + 30
  else
    LV.cheer:Hide()
  end
  LV.UpdatePin()
  miniRoot:SetHeight(yy + 8)
  f:SetSize(MINI_W, 66 + yy + 14)
end

Render = function()
  if not f:IsShown() or not DB then return end
  for i = 1, used do rows[i]:Hide() end
  used, y = 0, 0

  local b = D.brackets[current]
  local lv = UnitLevel("player") or 1
  local log = ReadQuestLog()
  QCache = ReadQuestie()
  local mini = DB.mode == "mini"
  LayoutChrome(mini)
  if mini then
    miniRoot:Show()
    if LV.sizeGrip then LV.sizeGrip:Show() end
    -- 아래 다른 창(피해량 미터기 등)에 안 닿게 '그다음' 줄 수를 줄여요
    local avail = LV.AvailH and LV.AvailH() or nil
    if DB.miniMaxH then avail = math.min(avail or DB.miniMaxH, DB.miniMaxH) end
    for cap = 4, 1, -1 do
      LV.nextCap = cap
      RenderMini(b, log, lv)
      if not avail or f:GetHeight() <= avail then break end
    end
    if LV.KeepTop then LV.KeepTop() end
    return
  end
  miniRoot:Hide()
  if LV.sizeGrip then LV.sizeGrip:Hide() end
  RenderFull(b, log, lv)

  content:SetHeight(y + 8)
  local m = MaxScroll()
  if (scroll:GetVerticalScroll() or 0) > m then scroll:SetVerticalScroll(m) end
  UpdateThumb()
end

local function Show(index)
  current = math.max(1, math.min(#D.brackets, index))
  tabAuto = true
  scroll:SetVerticalScroll(0)
  Render()
end

local function SetMode(m)
  DB.mode = m
  scroll:SetVerticalScroll(0)
  Render()
end

prevB:SetScript("OnClick", function() manual = true; Show(current - 1) end)
nextB:SetScript("OnClick", function() manual = true; Show(current + 1) end)
lvB:SetScript("OnClick", function() manual = false; Show(BracketForLevel(UnitLevel("player"))) end)
sortB:SetScript("OnClick", function()
  DB.sort = DB.sort == "route" and "hub" or DB.sort == "hub" and "level" or (DB.sort == "level" and CDB.plan) and "plan" or (DB.sort ~= "guide" and ns.guide) and "guide" or "route"
  scroll:SetVerticalScroll(0)
  Render()
end)
hideB:SetScript("OnClick", function() DB.hideDone = not DB.hideDone; Render() end)
local function MakePlanClick()
  if InCombatLockdown and InCombatLockdown() then Print("전투가 끝나면 다시 눌러 주세요."); return end
  BuildPlan()
  scroll:SetVerticalScroll(0)
  Render()
end
planB:SetScript("OnClick", MakePlanClick)
miniPlanB:SetScript("OnClick", MakePlanClick)
local function PlanTip(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine("루트 만들기", C.accent[1], C.accent[2], C.accent[3])
  if DB.planMode == "level" then
    GameTooltip:AddLine("방식: 레벨 우선. 낮은 레벨부터, 같은 레벨대에서는 가까운 순.", C.text[1], C.text[2], C.text[3], true)
  else
    GameTooltip:AddLine("방식: 구역 단위. 가까운 할 일끼리 구역으로 묶고, 낮은 레벨 구역부터 가서 그 구역 일을 다 끝내요.", C.text[1], C.text[2], C.text[3], true)
  end
  GameTooltip:AddLine("/forg 레벨우선 으로 방식 바꾸기", C.muted[1], C.muted[2], C.muted[3])
  GameTooltip:AddLine("자동 루트: " .. (DB.autoPlan and "켜짐" or "꺼짐") .. "  (/forg 자동 으로 켜고 끄기)", C.muted[1], C.muted[2], C.muted[3])
  GameTooltip:Show()
end
for _, b in ipairs({ planB, miniPlanB }) do
  b:HookScript("OnEnter", PlanTip)
  b:HookScript("OnLeave", function() GameTooltip:Hide() end)
end
-- 루트 만들기 · 정렬 버튼을 아이콘으로 (이름과 설명은 마우스를 올리면 말풍선으로)
do
  local M = "Interface\\AddOns\\ForgLeveling\\media\\"
  local SORTN = { guide = "따라하기", plan = "계획", route = "경로순", hub = "거점순", level = "레벨순" }
  local SORTD = {
    guide = "forg.gg 가이드 순서 그대로 (가이드가 없는 지역은 자동 루트)",
    plan = "루트 만들기로 짠 순서",
    route = "가까운 곳부터 이어서",
    hub = "마을(거점)별로 묶어서",
    level = "퀘스트 레벨 낮은 순",
  }
  local function nextSort()
    local cur = DB.sort
    return cur == "route" and "hub" or cur == "hub" and "level" or (cur == "level" and CDB.plan) and "plan" or (cur ~= "guide" and ns.guide) and "guide" or "route"
  end
  local function iconize(b, tex, sz, bs)
    b.label:SetText("")
    b.SetText = function() end
    b:SetSize(bs, bs)
    b.__round = bs / 2
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(sz, sz); b.icon:SetPoint("CENTER")
    b.icon:SetTexture(M .. tex)
    b:Paint()
  end
  iconize(planB, "ic_route", 14, 24)
  iconize(miniPlanB, "ic_route", 12, 20)
  iconize(sortB, "ic_sort", 14, 24)
  iconize(miniSortB, "ic_sort", 12, 20)
  -- 정렬 버튼은 지금 방식에 맞는 아이콘으로 (Render가 SetText를 부를 때마다 바꿈)
  local function sortIcon(self)
    local k = DB and DB.sort or "level"
    if not SORTN[k] then k = "level" end
    self.icon:SetTexture(M .. "ic_s_" .. k)
  end
  sortB.SetText, miniSortB.SetText = sortIcon, sortIcon
  sortIcon(sortB); sortIcon(miniSortB)
  miniPlanB:ClearAllPoints(); miniPlanB:SetPoint("RIGHT", miniSortB, "LEFT", -4, 0)
  planB:ClearAllPoints(); planB:SetPoint("RIGHT", sortB, "LEFT", -4, 0)
  local function SortTip(self)
    local cur = DB.sort or "level"
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("정렬: " .. (SORTN[cur] or cur), C.accent[1], C.accent[2], C.accent[3])
    GameTooltip:AddLine(SORTD[cur] or "", C.text[1], C.text[2], C.text[3], true)
    local nx = nextSort()
    GameTooltip:AddLine("누르면 → " .. (SORTN[nx] or nx), C.muted[1], C.muted[2], C.muted[3])
    GameTooltip:Show()
  end
  for _, b in ipairs({ sortB, miniSortB }) do
    b:HookScript("OnEnter", SortTip)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    b:HookScript("OnClick", function(self) sortIcon(self); if self:IsMouseOver() then SortTip(self) end end)
  end
end
segFull:SetScript("OnClick", function() SetMode("full") end)
segMini:SetScript("OnClick", function() SetMode("mini") end)
f:SetScript("OnShow", function() Render() end)

---------------------------------------------------------------------------
-- 이벤트
---------------------------------------------------------------------------
local pending = false
local function QueueRender()
  if pending or not f:IsShown() then return end
  pending = true
  C_Timer.After(0.3, function() pending = false; Render() end)
end

local pendingTitle -- 반납 창에 떠 있는 퀘스트 제목

local function MarkTurnedIn(t)
  if not t or t == "" then return end
  CDB.done[Norm(t)] = true
  CDB.manual[Norm(t)] = nil
end

---------------------------------------------------------------------------
-- 이미 반납한 퀘스트 기록 읽기 (서버의 완료 퀘스트 목록 → 제목으로 바꿔 대조)
---------------------------------------------------------------------------
local scanTip
local function TitleFor(id)
  local t
  if C_QuestLog then
    if C_QuestLog.GetTitleForQuestID then
      local ok, r = pcall(C_QuestLog.GetTitleForQuestID, id); if ok then t = r end
    end
    if (not t or t == "") and C_QuestLog.GetQuestInfo then
      local ok, r = pcall(C_QuestLog.GetQuestInfo, id); if ok then t = r end
    end
  end
  if (not t or t == "") then
    if not scanTip then
      scanTip = CreateFrame("GameTooltip", "ForgLevelingScanTip", UIParent, "GameTooltipTemplate")
      scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    local ok = pcall(function()
      scanTip:ClearLines()
      scanTip:SetHyperlink("quest:" .. id)
    end)
    local fs = _G["ForgLevelingScanTipTextLeft1"]
    if ok and fs and fs.GetText then t = fs:GetText() end
  end
  if t == "" then t = nil end
  return t
end

local function GetCompletedIDs()
  local ids = {}
  if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
    local ok, list = pcall(C_QuestLog.GetAllCompletedQuestIDs)
    if ok and type(list) == "table" then
      for _, id in ipairs(list) do ids[#ids + 1] = id end
    end
  end
  if #ids == 0 and GetQuestsCompleted then
    local ok, t = pcall(GetQuestsCompleted)
    if ok and type(t) == "table" then
      for id, v in pairs(t) do if v then ids[#ids + 1] = id end end
    end
  end
  return ids
end

local dataKeys
local function DataKeys()
  if dataKeys then return dataKeys end
  dataKeys = {}
  for _, b in ipairs(D.brackets) do
    for _, z in ipairs(b.zones) do
      for _, q in ipairs(z.quests) do dataKeys[q.key or Norm(q[2])] = true end
    end
  end
  return dataKeys
end

local scanWaiting = {}
local function ApplyTitle(id, t)
  CDB.scanned[id] = t
  local k = Norm(t)
  if CDB.manual[k] == false then return false end
  if not CDB.done[k] then
    CDB.done[k] = true
    return DataKeys()[k] == true
  end
  return false
end

local function ScanCompleted(verbose, retry)
  local ids = GetCompletedIDs()
  if #ids == 0 then
    if verbose then Print("이 클라이언트에서는 완료 퀘스트 기록을 읽을 수 없어요. 오른쪽 클릭으로 직접 표시해 주세요.") end
    return
  end
  local newHits, unknown = 0, 0
  for _, id in ipairs(ids) do
    local t = CDB.scanned[id]
    if not t then
      t = TitleFor(id)
      if t then
        if ApplyTitle(id, t) then newHits = newHits + 1 end
      else
        unknown = unknown + 1
        scanWaiting[id] = true
        if C_QuestLog and C_QuestLog.RequestLoadQuestByID then
          pcall(C_QuestLog.RequestLoadQuestByID, id)
        end
      end
    elseif not CDB.done[Norm(t)] and CDB.manual[Norm(t)] ~= false then
      CDB.done[Norm(t)] = true
    end
  end
  if unknown > 0 and not retry then
    C_Timer.After(4, function() ScanCompleted(verbose, true) end)
  end
  if verbose or newHits > 0 then
    local hit = 0
    local keys = DataKeys()
    for k in pairs(CDB.done) do if keys[k] then hit = hit + 1 end end
    Print(("완료 기록 %d개 확인, 이 가이드에서 완료로 처리된 퀘스트 %d개%s"):format(
      #ids, hit, (unknown > 0 and not retry) and " (이름 불러오는 중)" or ""))
  end
  Render()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("QUEST_ACCEPTED")
ev:RegisterEvent("QUEST_COMPLETE")
ev:RegisterEvent("QUEST_FINISHED")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
pcall(ev.RegisterEvent, ev, "UNIT_QUEST_LOG_CHANGED")
pcall(ev.RegisterEvent, ev, "QUEST_WATCH_UPDATE")
pcall(ev.RegisterEvent, ev, "QUEST_TURNED_IN")
pcall(ev.RegisterEvent, ev, "QUEST_REMOVED")
pcall(ev.RegisterEvent, ev, "QUEST_DATA_LOAD_RESULT")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "PLAYER_LOGIN" then
    ForgLevelingDB = ForgLevelingDB or { shown = true }
    DB = ForgLevelingDB
    if not DB.sortV2 then DB.sort = "route"; DB.sortV2 = true end
    DB.sort = DB.sort or "route"
    DB.mode = DB.mode or "full"
    ForgLevelingCharDB = ForgLevelingCharDB or {}
    CDB = ForgLevelingCharDB
    CDB.done = CDB.done or {}
    CDB.manual = CDB.manual or {}
    CDB.scanned = CDB.scanned or {}
    CDB.skip = CDB.skip or {}
    CDB.prio = CDB.prio or {}
    if DB.hideDone == nil then DB.hideDone = true end
    if DB.autoPlan == nil then DB.autoPlan = true end
    if DB.skipGrey == nil then DB.skipGrey = true end
    if DB.mapPin == nil then DB.mapPin = true end
    if DB.mapTrail == nil then DB.mapTrail = true end
    if DB.autoWay == nil then DB.autoWay = true end
    if DB.skipRepeat == nil then DB.skipRepeat = true end
    if not DB.themeIntro then
      DB.themeIntro = true
      DB.theme = DB.theme or "A"
      C_Timer.After(7, function() Print("새 꾸미기: |cffffa9bd모카 크림|r으로 바꿨어요. 설정 > 꾸미기 또는 /forg 테마 a | b | c | 기본") end)
    end
    if LV.ApplyTheme then LV.ApplyTheme() end
    if not DB.guideIntro and ns.guide then
      DB.guideIntro = true
      DB.sort = "guide"
      C_Timer.After(6, function() Print("새 기능: |cffe2a63b따라하기|r — forg.gg 순서대로 따라 하기 단계를 그대로 보여 줘요. 정렬 버튼으로 다른 방식과 바꿀 수 있어요. /forg 단계 로 단계 목록") end)
    end
    DB.planMode = DB.planMode or "area"
    DB.alpha = DB.alpha or 0.95
    DB.textAlpha = DB.textAlpha or 1
    if DB.hoverOpaque == nil then DB.hoverOpaque = true end
    if DB.combatFade == nil then DB.combatFade = true end
    C_Timer.After(0.1, function() ApplyAlpha() end)
    PrepareData()
    if DB.point then
      f:ClearAllPoints()
      f:SetPoint(DB.point[1], UIParent, DB.point[2], DB.point[3], DB.point[4])
    end
    current = BracketForLevel(UnitLevel("player"))
    ReadQuestLog()
    if DB.shown then f:Show() end
    Print("/forg 창 열기, /forg 간략 · /forg 자세히 보기 전환")
    C_Timer.After(3, function() ScanCompleted(true) end)
    C_Timer.After(5, function() AutoPlan("login") end)
  elseif not DB then
    return
  elseif event == "PLAYER_REGEN_DISABLED" then
    inCombat = true
    ApplyAlpha()
  elseif event == "PLAYER_REGEN_ENABLED" then
    inCombat = false
    ApplyAlpha()
    if autoPending then
      local r = autoPending
      autoPending = false
      C_Timer.After(1, function() AutoPlan(type(r) == "string" and r or nil) end)
    end
  elseif event == "PLAYER_LEVEL_UP" then
    LV.happyUntil = (GetTime and GetTime() or 0) + 10
    C_Timer.After(10.5, function() if Render then Render() end end)
    C_Timer.After(2, function() AutoPlan("levelup") end)
    local lv = tonumber(arg1) or UnitLevel("player")
    local nb = BracketForLevel(lv)
    if nb ~= current and not manual then
      local b = D.brackets[nb]
      Print(("새 구간: Lv %d-%d %s"):format(b.min, b.max, b.title))
      Show(nb)
    else
      QueueRender()
    end
  elseif event == "ZONE_CHANGED_NEW_AREA" then
    tabAuto = true
    QueueRender()
    C_Timer.After(3, function() AutoPlan("zone") end)
  elseif event == "QUEST_DATA_LOAD_RESULT" then
    if arg1 and scanWaiting[arg1] then
      scanWaiting[arg1] = nil
      local t = TitleFor(arg1)
      if t then ApplyTitle(arg1, t); QueueRender() end
    end
  elseif event == "QUEST_ACCEPTED" then
    -- 퀘스트를 받으면 실제 수행 위치(게임 지도 표시)가 생기므로 루트를 다시 짬.
    -- 여러 개를 연달아 받으면 마지막에 한 번만.
    ReadQuestLog()
    QueueRender()
    if DB.sort == "plan" then
      ev.acceptGen = (ev.acceptGen or 0) + 1
      local g = ev.acceptGen
      C_Timer.After(3, function() if ev.acceptGen == g then AutoPlan("accept") end end)
    end
  elseif event == "QUEST_COMPLETE" then
    pendingTitle = GetTitleText and GetTitleText() or nil
  elseif event == "QUEST_TURNED_IN" then
    local today = date and date("%Y-%m-%d") or ""
    if not CDB.today or CDB.today.d ~= today then CDB.today = { d = today, n = 0 } end
    CDB.today.n = CDB.today.n + 1
    LV.happyUntil = (GetTime and GetTime() or 0) + 8
    C_Timer.After(8.5, function() if Render then Render() end end)
    if arg1 then CDB.doneIds = CDB.doneIds or {}; CDB.doneIds[arg1] = true end
    if DB.sort == "plan" and CDB.plan then
      C_Timer.After(1.5, function()
        if not AutoSupplement() then AutoPlan("turnin") end
      end)
    end
    local t = (arg1 and logIDs[arg1]) or pendingTitle
    if (not t) and arg1 and C_QuestLog and C_QuestLog.GetTitleForQuestID then
      t = C_QuestLog.GetTitleForQuestID(arg1)
    end
    MarkTurnedIn(t)
    pendingTitle = nil
    QueueRender()
  elseif event == "QUEST_FINISHED" then
    local t = pendingTitle
    pendingTitle = nil
    if t then
      C_Timer.After(1, function()
        local log = ReadQuestLog()
        if not log[Norm(t)] then MarkTurnedIn(t) end
        QueueRender()
      end)
    end
  else
    ReadQuestLog()
    LearnProgress()
    QueueRender()
  end
end)


---------------------------------------------------------------------------
-- 점검: 클라이언트가 애드온에 어떤 퀘스트 정보를 열어 주는지 (/forg 점검)
---------------------------------------------------------------------------
local function Probe()
  local function has(path)
    local t = _G
    for part in path:gmatch("[^%.]+") do
      if type(t) ~= "table" then return false end
      t = t[part]
    end
    return t ~= nil
  end
  local function yn(b) return b and "|cff33ff33있음|r" or "|cffd7745f없음|r" end
  local m
  if C_Map and C_Map.GetBestMapForUnit then local ok, r = pcall(C_Map.GetBestMapForUnit, "player"); if ok then m = r end end
  Print(("점검 시작  지도 ID: %s  지역: %s  클라이언트: %s"):format(tostring(m), PlayerZone(),
    tostring(GetBuildInfo and select(4, GetBuildInfo()) or "?")))
  local apis = {
    "C_QuestLine.GetAvailableQuestLines", "C_QuestLine.RequestQuestLinesForMap",
    "C_QuestLog.GetQuestsOnMap", "QuestPOIGetIconInfo", "C_QuestLog.GetQuestObjectives",
    "C_QuestLog.GetAllCompletedQuestIDs", "GetQuestsCompleted", "C_QuestLog.GetQuestDifficultyLevel",
    "C_QuestLog.GetTitleForQuestID", "C_TaskQuest.GetQuestsForPlayerByMapID", "C_QuestOffer",
    "C_Minimap.GetTrackingInfo",
  }
  for _, a in ipairs(apis) do Print("  " .. a .. ": " .. yn(has(a))) end

  -- 지도에 표시되는 내 퀘스트
  if m and C_QuestLog and C_QuestLog.GetQuestsOnMap then
    local ok, list = pcall(C_QuestLog.GetQuestsOnMap, m)
    Print(("  지도 위 내 퀘스트: %s개"):format(ok and type(list) == "table" and #list or "읽기 실패"))
  end
  -- 끝낸 퀘스트
  local ok, ids = pcall(function()
    if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then return #C_QuestLog.GetAllCompletedQuestIDs() end
    if GetQuestsCompleted then local n = 0; for _ in pairs(GetQuestsCompleted()) do n = n + 1 end; return n end
  end)
  Print(("  끝낸 퀘스트 기록: %s개"):format(ok and tostring(ids) or "읽기 실패"))

  -- 받을 수 있는 퀘스트 (지도의 ! 표시)
  if m and C_QuestLine and C_QuestLine.GetAvailableQuestLines then
    if C_QuestLine.RequestQuestLinesForMap then pcall(C_QuestLine.RequestQuestLinesForMap, m) end
    C_Timer.After(1.5, function()
      local ok2, lines = pcall(C_QuestLine.GetAvailableQuestLines, m)
      if not ok2 or type(lines) ~= "table" then Print("  받을 수 있는 퀘스트: 읽기 실패"); return end
      Print(("  받을 수 있는 퀘스트 (지도의 ! 표시): %d개"):format(#lines))
      for i = 1, math.min(5, #lines) do
        local q = lines[i]
        local lvl
        if C_QuestLog and C_QuestLog.GetQuestDifficultyLevel then
          local ok3, r = pcall(C_QuestLog.GetQuestDifficultyLevel, q.questID); if ok3 then lvl = r end
        end
        Print(("    %s  (ID %s, 레벨 %s, 좌표 %.1f, %.1f)"):format(tostring(q.questName), tostring(q.questID),
          tostring(lvl or q.questLevel or "?"), (q.x or 0) * 100, (q.y or 0) * 100))
      end
      Print("점검 끝. 채팅창을 캡처해서 보내 주세요.")
    end)
  else
    Print("  받을 수 있는 퀘스트 목록 기능: |cffd7745f없음|r")
    Print("점검 끝. 채팅창을 캡처해서 보내 주세요.")
  end
end

-- 2차 점검: 지도의 ! 표시가 어디서 오는지 찾기 (/forg 점검2)
local function Probe2()
  local function out(t) Print(t) end
  local m
  if C_Map and C_Map.GetBestMapForUnit then local ok, r = pcall(C_Map.GetBestMapForUnit, "player"); if ok then m = r end end
  out("2차 점검 시작 (지도 ID " .. tostring(m) .. ")")

  -- 1) 퀘스트 관련 기능 이름 목록
  for _, ns in ipairs({ "C_QuestOffer", "C_QuestLine", "C_QuestHub", "C_QuestSession", "C_QuestInfoSystem" }) do
    local t = _G[ns]
    if type(t) == "table" then
      local names = {}
      for k, v in pairs(t) do if type(v) == "function" then names[#names + 1] = k end end
      table.sort(names)
      out(("  %s: %s"):format(ns, #names > 0 and table.concat(names, ", ") or "(비어 있음)"))
    end
  end
  local extra = {}
  for k, v in pairs(_G) do
    if type(k) == "string" and type(v) == "table" and k:match("^C_") and (k:find("Quest") or k:find("Offer")) then extra[#extra + 1] = k end
  end
  table.sort(extra)
  out("  퀘스트 관련 C_ 이름: " .. table.concat(extra, ", "))

  -- 2) C_QuestOffer 함수 중 인자 없이 / 지도 ID로 부를 만한 것 시험
  local qo = _G.C_QuestOffer
  if type(qo) == "table" then
    for k, fn in pairs(qo) do
      if type(fn) == "function" and (k:find("^Get") or k:find("^Is")) then
        local ok, r = pcall(fn, m)
        local desc
        if not ok then desc = "오류" elseif type(r) == "table" then desc = "표 " .. #r .. "개" else desc = tostring(r) end
        out(("    C_QuestOffer.%s(%s) -> %s"):format(k, tostring(m), desc))
        if ok and type(r) == "table" and r[1] then
          local fields = {}
          local first = r[1]
          if type(first) == "table" then
            for fk, fv in pairs(first) do fields[#fields + 1] = fk .. "=" .. tostring(fv) end
            out("      예시: " .. table.concat(fields, ", "))
          else
            out("      예시: " .. tostring(first))
          end
        end
      end
    end
  end

  -- 3) 지도를 열고 ! 표시를 그리는 그림 종류 찾기
  if InCombatLockdown and InCombatLockdown() then out("  전투 중이라 지도 점검은 건너뜀"); return end
  if WorldMapFrame and not WorldMapFrame:IsShown() then
    if ToggleWorldMap then pcall(ToggleWorldMap) elseif ShowUIPanel then pcall(ShowUIPanel, WorldMapFrame) end
  end
  if WorldMapFrame and m and WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, m) end
  C_Timer.After(1.5, function()
    -- 받을 수 있는 퀘스트 다시 시도 (지도가 열린 뒤)
    if C_QuestLine and C_QuestLine.GetAvailableQuestLines and m then
      local ok, lines = pcall(C_QuestLine.GetAvailableQuestLines, m)
      out(("  지도 연 뒤 받을 수 있는 퀘스트: %s"):format(ok and type(lines) == "table" and (#lines .. "개") or "읽기 실패"))
    end
    if not (WorldMapFrame and WorldMapFrame.pinPools) then out("  지도 핀 정보를 읽을 수 없어요"); out("2차 점검 끝. 캡처해서 보내 주세요."); return end
    local rows = {}
    for template, pool in pairs(WorldMapFrame.pinPools) do
      local n = 0
      local sample
      if pool.EnumerateActive then
        for pin in pool:EnumerateActive() do
          n = n + 1
          if not sample then sample = pin end
        end
      end
      if n > 0 then rows[#rows + 1] = { template = tostring(template), n = n, pin = sample } end
    end
    table.sort(rows, function(a, b) return a.n > b.n end)
    out("  지도에 그려진 핀 종류 (많은 순):")
    for i = 1, math.min(10, #rows) do
      local r = rows[i]
      local info = {}
      local p = r.pin
      for _, key in ipairs({ "questID", "questId", "id", "name", "questName", "title", "level", "questLevel", "normalizedX", "normalizedY" }) do
        if p[key] ~= nil then info[#info + 1] = key .. "=" .. tostring(p[key]) end
      end
      if p.GetPosition then
        local ok, x, yy = pcall(p.GetPosition, p)
        if ok and x then info[#info + 1] = ("pos=%.3f,%.3f"):format(x, yy or 0) end
      end
      out(("    %s  %d개  %s"):format(r.template, r.n, table.concat(info, " ")))
    end
    out("2차 점검 끝. 지도는 닫아도 돼요. 채팅창을 캡처해서 보내 주세요.")
  end)
end

-- 3차 점검: Questie 정보 읽기 (/forg 점검3)
local function Probe3()
  local out = Print
  local QL = _G.QuestieLoader
  out("3차 점검 시작. Questie 로더: " .. (QL and "있음" or "없음") ..
      "  Questie 버전: " .. tostring((_G.Questie and _G.Questie.version) or (GetAddOnMetadata and GetAddOnMetadata("Questie", "Version")) or (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Questie", "Version")) or "?"))
  if not QL or not QL.ImportModule then out("Questie 내부 기능을 찾지 못했어요."); return end
  local mods = {}
  for _, name in ipairs({ "QuestieDB", "QuestieMap", "QuestiePlayer", "QuestieQuest", "AvailableQuests", "ZoneDB", "QuestieLib", "QuestLogCache" }) do
    local ok, mod = pcall(QL.ImportModule, QL, name)
    mods[name] = ok and type(mod) == "table" and mod or nil
    local fnames = {}
    if mods[name] then
      for k, v in pairs(mods[name]) do if type(v) == "function" then fnames[#fnames + 1] = k end end
      table.sort(fnames)
    end
    out(("  %s: %s%s"):format(name, mods[name] and "있음" or "없음",
      (mods[name] and (name == "AvailableQuests" or name == "QuestieDB")) and ("  [" .. table.concat(fnames, ", ", 1, math.min(#fnames, 25)) .. "]") or ""))
  end

  -- 지도 아이콘 (퀘스트별)
  local QM = mods.QuestieMap
  local counts, sample = {}, {}
  if QM and QM.questIdFrames then
    local nq = 0
    for qid, frames in pairs(QM.questIdFrames) do
      nq = nq + 1
      for _, fname in pairs(frames) do
        local fr = _G[fname]
        local d = fr and fr.data
        if d then
          local t = tostring(d.Type)
          counts[t] = (counts[t] or 0) + 1
          if not sample[t] then sample[t] = fr end
        end
      end
    end
    local parts = {}
    for t, n in pairs(counts) do parts[#parts + 1] = t .. " " .. n end
    out(("  아이콘 달린 퀘스트 %d개, 아이콘 종류: %s"):format(nq, table.concat(parts, ", ")))
    for t, fr in pairs(sample) do
      local d = fr.data
      local qd = d.QuestData or {}
      out(("    [%s] 퀘스트 %s  이름 %s  레벨 %s  좌표 %s, %s  지도 %s  지역 %s"):format(
        t, tostring(d.Id), tostring(d.Name or qd.name), tostring(qd.level or d.Level),
        tostring(fr.x), tostring(fr.y), tostring(fr.UiMapID), tostring(fr.AreaID or d.AreaID)))
      local keys = {}
      for k in pairs(d) do keys[#keys + 1] = tostring(k) end
      table.sort(keys)
      out("      data 항목: " .. table.concat(keys, ", "))
    end
  else
    out("  QuestieMap.questIdFrames 없음")
  end

  -- 퀘스트 DB 예시 (내 로그의 첫 퀘스트)
  local DBm = mods.QuestieDB
  local e = logList[1]
  if DBm and e and e.id then
    local getq = DBm.GetQuest
    if getq then
      local ok, q = pcall(getq, e.id)
      if not ok then ok, q = pcall(getq, DBm, e.id) end
      if ok and type(q) == "table" then
        local keys = {}
        for k in pairs(q) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        out(("  DB 예시 [%s] 레벨 %s, 항목: %s"):format(tostring(q.name), tostring(q.level), table.concat(keys, ", ")))
        local fin = q.Finisher
        if type(fin) == "table" then out(("    반납: %s %s"):format(tostring(fin.Type), tostring(fin.Id))) end
      else
        out("  DB 예시 읽기 실패")
      end
    end
  end
  out("3차 점검 끝. 채팅창을 위로 올려 가며 전부 캡처해서 보내 주세요.")
end
---------------------------------------------------------------------------
-- 슬래시 명령
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- 설정 창
---------------------------------------------------------------------------
local setF = CreateFrame("Frame", "ForgLevelingSettings", UIParent, BD)
setF:SetSize(250, 10)
setF:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -4)
setF:SetFrameStrata("DIALOG")
setF:SetClampedToScreen(true)
-- 창 아래 자리가 모자라면 옆에, 옆도 안 되면 위에 붙임
function LV.PlaceSettings()
  local h = setF:GetHeight() or 300
  local bottom, left, right = f:GetBottom(), f:GetLeft(), f:GetRight()
  local sw = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1920
  local sf, uf = f:GetEffectiveScale() or 1, setF:GetEffectiveScale() or 1
  setF:ClearAllPoints()
  if type(bottom) ~= "number" or bottom * sf >= (h + 8) * uf then
    setF:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -4)
  elseif type(left) == "number" and left * sf >= (250 + 8) * uf then
    setF:SetPoint("TOPRIGHT", f, "TOPLEFT", -4, 0)
  elseif type(right) == "number" and (sw - right * sf / (UIParent:GetEffectiveScale() or 1)) >= 258 then
    setF:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, 0)
  else
    setF:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 4)
  end
end
Backdrop(setF, C.bg, C.line2)
setF:EnableMouse(true)
setF:Hide()
f:HookScript("OnHide", function() setF:Hide() end)
local setTitle = FS(setF, 13, C.text)
setTitle:SetPoint("TOPLEFT", 12, -10)
setTitle:SetText("설정")
local setRows = {}

local function ReplanIfNeeded()
  excludeCache = {}
  if DB.sort == "plan" and CDB.plan then BuildPlan(true); snap, wpFollow = nil, nil end
  Render()
end

-- 투명도 ------------------------------------------------------------------
local hoverOn = false
ApplyAlpha = function()
  if not DB then return end
  local a = DB.alpha or 0.95
  local ta = DB.textAlpha or 1
  if hoverOn and DB.hoverOpaque then a, ta = 1, 1 end
  if inCombat and DB.combatFade and not hoverOn then a, ta = a * 0.5, ta * 0.6 end
  if C.__round and f.__round then
    Backdrop(f, { C.bg[1], C.bg[2], C.bg[3], a }, { C.line2[1], C.line2[2], C.line2[3], math.min(1, a + 0.1) })
  elseif f.SetBackdropColor then
    f:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], a)
    f:SetBackdropBorderColor(C.line2[1], C.line2[2], C.line2[3], math.min(1, a + 0.1))
  end
  f:SetAlpha(ta)
end
do
  local acc = 0
  local hoverWatch = CreateFrame("Frame", nil, f)
  hoverWatch:SetScript("OnUpdate", function(_, el)
    acc = acc + el
    if acc < 0.15 then return end
    acc = 0
    local over = f:IsShown() and f:IsMouseOver() or false
    if over ~= hoverOn then hoverOn = over; ApplyAlpha() end
  end)
end

-- 슬라이더
local function MakeSlider(parent, onChange)
  local sl = CreateFrame("Button", nil, parent)
  sl:SetHeight(16)
  sl.track = Tex(sl, { 1, 1, 1, 0.08 })
  sl.track:SetHeight(6)
  sl.track:SetPoint("LEFT", 0, 0); sl.track:SetPoint("RIGHT", 0, 0)
  sl.fill = Tex(sl, C.accent)
  sl.fill:SetHeight(6)
  sl.fill:SetPoint("LEFT", sl.track, "LEFT", 0, 0)
  sl.knob = CreateFrame("Frame", nil, sl, BD)
  sl.knob:SetSize(14, 14)
  Backdrop(sl.knob, { 0.95, 0.89, 0.75 }, C.accent)
  sl.min, sl.max, sl.step = 0.2, 1, 0.05
  function sl:SetValue(v)
    v = math.max(self.min, math.min(self.max, v))
    v = math.floor(v / self.step + 0.5) * self.step
    self.value = v
    local w = self:GetWidth() or 200
    if w <= 0 then w = 200 end
    local frac = (v - self.min) / (self.max - self.min)
    self.fill:SetWidth(math.max(1, w * frac))
    self.knob:ClearAllPoints()
    self.knob:SetPoint("CENTER", self.track, "LEFT", w * frac, 0)
  end
  local function fromCursor(self)
    local x = GetCursorPosition()
    local sc = self:GetEffectiveScale()
    local left = self:GetLeft() or 0
    local w = self:GetWidth() or 1
    local frac = ((x / sc) - left) / w
    self:SetValue(self.min + frac * (self.max - self.min))
    if onChange then onChange(self.value) end
  end
  sl:SetScript("OnMouseDown", function(self)
    self.drag = true
    fromCursor(self)
    self:SetScript("OnUpdate", function(me) if me.drag then fromCursor(me) end end)
  end)
  sl:SetScript("OnMouseUp", function(self) self.drag = false; self:SetScript("OnUpdate", nil) end)
  return sl
end

local SETTINGS = {
  { key = "theme", label = "꾸미기", cycle = { "base", "A", "B", "C" }, desc = "누를 때마다 바뀌어요: 기본 → A 모카 크림 → B 말랑 나이트 → C 밤 솜사탕",
    after = function() if LV.ApplyTheme then LV.ApplyTheme() end end },
  { kind = "slider", key = "alpha", label = "창 투명도", default = 0.95 },
  { kind = "slider", key = "textAlpha", label = "글자·아이콘 진하기", default = 1 },
  { key = "hoverOpaque", label = "마우스를 올리면 진하게", desc = "평소엔 투명하게, 올리면 100%로", after = ApplyAlpha },
  { key = "combatFade", label = "전투 중에는 더 흐리게", desc = "전투가 끝나면 원래대로", after = ApplyAlpha },
  { key = "skipDungeon", label = "던전 퀘스트 넘기기", desc = "던전 안에서 하는 퀘스트를 루트에서 빼요", after = ReplanIfNeeded },
  { key = "skipGrey", label = "회색 퀘스트 넘기기", desc = "경험치를 거의 안 주는 퀘스트는 빼고, 끝낸 건 반납만", after = ReplanIfNeeded },
  { key = "skipRepeat", label = "반복 퀘스트 넘기기", desc = "지도에 파란색으로 뜨는 반복·일일 퀘스트는 받기 추천에서 빼요 (이미 받은 건 그대로 안내)", after = function() LV.repCache = {}; ReplanIfNeeded() end },
  { key = "skipGroup", label = "그룹(정예) 퀘스트 넘기기", desc = "여럿이 해야 하는 정예 퀘스트를 루트에서 빼요", after = ReplanIfNeeded },
  { key = "mapTrail", label = "웨이포인트까지 점선 길", desc = "핀 찍기를 누르면 지도와 미니맵에 내 위치에서 그곳까지 점선을 그려요. 도착하면 사라져요", after = function() LV.trailKey = nil; LV.UpdateTrail() end },
  { key = "autoWay", label = "퀘스트가 바뀌면 자동 길 안내", desc = "지금 할 일이 바뀌면 그 위치까지 점선 길을 알아서 그려요", after = function() LV.autoWayKey = nil; Render() end },
  { key = "autoPlan", label = "자동 루트", desc = "지역 이동, 레벨 업, 반납 후 새 퀘스트가 생기면 루트를 다시 짜요" },
  { key = "planMode", label = "구역 단위 루트", desc = "끄면 레벨 우선으로 짜요", on = "area", off = "level", after = ReplanIfNeeded },
  { key = "minimapHide", label = "미니맵 버튼 보이기", desc = "미니맵 둘레의 길잡이 버튼", invert = true,
    after = function()
      local mb = ForgLevelingMinimapButton
      if not mb then return end
      if DB.minimapHide then mb:Hide() else mb:Show(); if mb.UpdatePosition then mb.UpdatePosition() end end
    end },
}

local function SettingOn(o)
  local v = DB[o.key]
  if o.on then return v == o.on end
  if o.invert then return not v end
  return v and true or false
end

local function RefreshSettings()
  local yy = -34
  local W = 250
  for i, o in ipairs(SETTINGS) do
    local r = setRows[i]
    if not r then
      r = CreateFrame("Button", nil, setF)
      r.label = FS(r, 12, C.text)
      r.label:SetPoint("TOPLEFT", o.kind == "slider" and 0 or 22, -2)
      if o.kind == "slider" then
        r.val = FS(r, 12, C.accent, "RIGHT")
        r.val:SetPoint("TOPRIGHT", 0, -2)
        r.slider = MakeSlider(r, function(v)
          DB[o.key] = v
          r.val:SetText(math.floor(v * 100 + 0.5) .. "%")
          ApplyAlpha()
        end)
        r.slider:SetPoint("TOPLEFT", 0, -22)
        r.slider:SetPoint("RIGHT", 0, 0)
        r:EnableMouse(false)
      else
        r.box = CreateFrame("Frame", nil, r, BD)
        r.box:SetSize(14, 14)
        r.box:SetPoint("TOPLEFT", 0, -3)
        r.desc = FS(r, 10, C.faint)
        r.desc:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -3)
        r.desc:SetWordWrap(true)
        r.hl = Tex(r, { 1, 1, 1, 0.04 }, "HIGHLIGHT"); r.hl:SetPoint("TOPLEFT", -6, 2); r.hl:SetPoint("BOTTOMRIGHT", 6, -2)
        r:SetScript("OnEnter", function(self)
          local d = self.opt and self.opt.desc
          if not d then return end
          GameTooltip:SetOwner(self, "ANCHOR_LEFT")
          GameTooltip:AddLine(self.opt.label, C.accent[1], C.accent[2], C.accent[3])
          GameTooltip:AddLine(d, C.text[1], C.text[2], C.text[3], true)
          GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:SetScript("OnClick", function(self)
          local opt = self.opt
          if opt.cycle then
            local cur, nxt = DB[opt.key] or opt.cycle[1], opt.cycle[1]
            for ci, v in ipairs(opt.cycle) do if v == cur then nxt = opt.cycle[ci % #opt.cycle + 1] end end
            DB[opt.key] = nxt
          elseif opt.on then DB[opt.key] = (DB[opt.key] == opt.on) and opt.off or opt.on
          else DB[opt.key] = not DB[opt.key] end
          RefreshSettings()
          if opt.after then opt.after() end
        end)
      end
      setRows[i] = r
    end
    r.opt = o
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", setF, "TOPLEFT", 12, yy)
    r:SetPoint("RIGHT", setF, "RIGHT", -12, 0)
    r.label:SetText(o.cycle and (o.label .. ":  " .. col("accent", ((LV.THEMES and LV.THEMES[DB[o.key] or "base"]) or {}).name or "")) or o.label)
    local h
    if o.kind == "slider" then
      h = 42
      r:SetHeight(h)
      r:Show()
      r.slider:SetWidth(W - 24)
      local v = DB[o.key] or o.default
      r.slider:SetValue(v)
      r.val:SetText(math.floor(v * 100 + 0.5) .. "%")
    else
      -- 설명은 마우스를 올리면 뜨는 말풍선으로 (창이 길어져 화면 밖으로 잘리지 않게)
      r.desc:SetText("")
      h = 18
      r:SetHeight(h)
      if o.cycle or SettingOn(o) then Backdrop(r.box, C.accent, C.accent) else Backdrop(r.box, { 0, 0, 0, 0 }, C.line2) end
      r:Show()
    end
    yy = yy - h - (o.kind == "slider" and 6 or 5)
  end
  setF:SetHeight(-yy + 6)
  if LV.PlaceSettings then LV.PlaceSettings() end
end

gearB:SetScript("OnClick", function()
  if setF:IsShown() then setF:Hide() else RefreshSettings(); setF:Show() end
end)

---------------------------------------------------------------------------
-- 꾸미기 테마: 기본 / A 파스텔 크림 / B 말랑 나이트 / C 솜사탕 구름
---------------------------------------------------------------------------
LV.hexc = function(h, a)
  local r, g, b = tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
  return { r, g, b, a }
end
LV.THEMES = {
  base = { name = "기본 (어두운 호박색)" },
  A = { name = "A 모카 크림",
    bg = LV.hexc("2f2522", 0.96), surf = LV.hexc("3b2f2b", 1), raise = LV.hexc("45372f", 1), line = LV.hexc("5a463b", 1), line2 = LV.hexc("7a5d4c", 1),
    text = LV.hexc("fbeee2"), muted = LV.hexc("d4b8a6"), faint = LV.hexc("a88e7e"), accent = LV.hexc("ffa9bd"), warn = LV.hexc("ff8fa3"),
    hunt = LV.hexc("ff8fa3"), ok = LV.hexc("8fdcb4"), row = LV.hexc("241b19", 0.85),
    bget = LV.hexc("ffd27d"), bturn = LV.hexc("ffb48a"), bhunt = LV.hexc("ff8fa3"), bok = LV.hexc("8fdcb4"), bar = LV.hexc("ffb48a") },
  B = { name = "B 말랑 나이트",
    bg = LV.hexc("2b2840", 0.96), surf = LV.hexc("35314f", 1), raise = LV.hexc("3a3557", 1), line = LV.hexc("48416b", 1), line2 = LV.hexc("5d5590", 1),
    text = LV.hexc("f3eaff"), muted = LV.hexc("b9b0e6"), faint = LV.hexc("9d93c9"), accent = LV.hexc("ff9fc4"), warn = LV.hexc("ff8fab"),
    hunt = LV.hexc("ff8fab"), ok = LV.hexc("8be3c9"), row = LV.hexc("201d33", 0.85),
    bget = LV.hexc("ffd27d"), bturn = LV.hexc("ffb48a"), bhunt = LV.hexc("ff8fab"), bok = LV.hexc("8be3c9"), bar = LV.hexc("8be3c9") },
  C = { name = "C 밤 솜사탕",
    bg = LV.hexc("1f2440", 0.96), surf = LV.hexc("2a3054", 1), raise = LV.hexc("313860", 1), line = LV.hexc("3f4775", 1), line2 = LV.hexc("5a64a0", 1),
    text = LV.hexc("eef0ff"), muted = LV.hexc("b5bce8"), faint = LV.hexc("8d95c8"), accent = LV.hexc("a6b8ff"), warn = LV.hexc("c8a6ff"),
    hunt = LV.hexc("c8a6ff"), ok = LV.hexc("8fe0c6"), row = LV.hexc("181c33", 0.85),
    bget = LV.hexc("ffe08a"), bturn = LV.hexc("8fd3ff"), bhunt = LV.hexc("c8a6ff"), bok = LV.hexc("8fe0c6"), bar = LV.hexc("8fd3ff") },
}
LV.THEME_ORDER = { "base", "A", "B", "C" }
-- 기본 색을 저장해 둠 (기본 테마로 되돌릴 때)
function LV.SaveBase()
  if LV.BASEC then return end
  LV.BASEC = {}
  for k, v in pairs(C) do if type(v) == "table" then LV.BASEC[k] = { v[1], v[2], v[3], v[4] } end end
  LV.BASEB = {}
  for k, v in pairs(BADGE) do LV.BASEB[k] = { v.c[1], v.c[2], v.c[3] } end
end
LV.SaveBase()

LV.setc = function(dst, src) dst[1], dst[2], dst[3], dst[4] = src[1], src[2], src[3], src[4] end

-- 이미 만든 글자·바탕을 새 색으로 다시 칠함 (만들 때 쓴 색 표를 기억해 둠)
function LV.Repaint(fr)
  if not fr then return end
  if fr.__bg then Backdrop(fr, fr.__bg, fr.__edge) end
  if fr.Paint then pcall(fr.Paint, fr) end
  for _, r in ipairs({ fr:GetRegions() }) do
    local c = r.__c
    if c then
      if r.SetTextColor then
        r:SetTextColor(c[1], c[2], c[3])
        r:SetShadowColor(0, 0, 0, C.__shadow or 0.6)
      elseif r.SetColorTexture then
        r:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
      end
    end
  end
  for _, ch in ipairs({ fr:GetChildren() }) do LV.Repaint(ch) end
end

-- 둥근 사각형: 가운데·가장자리는 색 사각형, 네 모서리는 둥근 그림 (테두리선도 같은 방식)
C.__roundfn = function(fr, bg, edge, r)
  local M = "Interface\\AddOns\\ForgLeveling\\media\\"
  local rr = rawget(fr, "__rr")
  if not rr then
    rr = {}
    fr.__rr = rr
    local function tex(sub) local t = fr:CreateTexture(nil, "BACKGROUND", nil, sub); rr[#rr + 1] = t; return t end
    -- 채우기: 1 가운데, 2 왼쪽, 3 오른쪽, 4~7 모서리
    for i = 1, 3 do tex(-8) end
    for i = 1, 4 do local t = tex(-8); t:SetTexture(M .. "corner_fill") end
    -- 테두리: 8 위, 9 아래, 10 왼쪽, 11 오른쪽, 12~15 모서리
    for i = 1, 4 do tex(-7) end
    for i = 1, 4 do local t = tex(-7); t:SetTexture(M .. "corner_line") end
    local CO = { { 0, 1, 0, 1 }, { 1, 0, 0, 1 }, { 0, 1, 1, 0 }, { 1, 0, 1, 0 } } -- 왼위, 오른위, 왼아래, 오른아래
    for k = 1, 4 do
      rr[3 + k]:SetTexCoord(CO[k][1], CO[k][2], CO[k][3], CO[k][4])
      rr[11 + k]:SetTexCoord(CO[k][1], CO[k][2], CO[k][3], CO[k][4])
    end
  end
  if rawget(fr, "__rrR") ~= r then
    fr.__rrR = r
    local th = math.max(1, r * 5 / 32)
    local c, L, Rt = rr[1], rr[2], rr[3]
    c:ClearAllPoints(); c:SetPoint("TOPLEFT", r, 0); c:SetPoint("BOTTOMRIGHT", -r, 0)
    L:ClearAllPoints(); L:SetPoint("TOPLEFT", 0, -r); L:SetPoint("BOTTOMRIGHT", fr, "BOTTOMLEFT", r, r)
    Rt:ClearAllPoints(); Rt:SetPoint("TOPRIGHT", 0, -r); Rt:SetPoint("BOTTOMLEFT", fr, "BOTTOMRIGHT", -r, r)
    local P = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
    for k = 1, 4 do
      for _, t in ipairs({ rr[3 + k], rr[11 + k] }) do t:ClearAllPoints(); t:SetSize(r, r); t:SetPoint(P[k]) end
    end
    local top, bot, l2, r2 = rr[8], rr[9], rr[10], rr[11]
    top:ClearAllPoints(); top:SetPoint("TOPLEFT", r, 0); top:SetPoint("TOPRIGHT", -r, 0); top:SetHeight(th)
    bot:ClearAllPoints(); bot:SetPoint("BOTTOMLEFT", r, 0); bot:SetPoint("BOTTOMRIGHT", -r, 0); bot:SetHeight(th)
    l2:ClearAllPoints(); l2:SetPoint("TOPLEFT", 0, -r); l2:SetPoint("BOTTOMLEFT", 0, r); l2:SetWidth(th)
    r2:ClearAllPoints(); r2:SetPoint("TOPRIGHT", 0, -r); r2:SetPoint("BOTTOMRIGHT", 0, r); r2:SetWidth(th)
  end
  local ba, ea = bg[4] or 1, edge[4] or 1
  for i = 1, 3 do rr[i]:SetColorTexture(bg[1], bg[2], bg[3], ba) end
  for i = 4, 7 do rr[i]:SetVertexColor(bg[1], bg[2], bg[3], ba) end
  for i = 8, 11 do rr[i]:SetColorTexture(edge[1], edge[2], edge[3], ea) end
  for i = 12, 15 do rr[i]:SetVertexColor(edge[1], edge[2], edge[3], ea) end
  for _, t in ipairs(rr) do t:Show() end
end

function LV.ApplyTheme()
  LV.SaveBase()
  local key = (DB and DB.theme) or "base"
  local T = LV.THEMES[key] or LV.THEMES.base
  for k, v in pairs(LV.BASEC) do if C[k] then LV.setc(C[k], (T[k] and T[k]) or v) end end
  -- 반투명이 필요한 색은 기본 알파 유지
  if T.bg and not T.bg[4] then C.bg[4] = 0.95 end
  for k, v in pairs(LV.BASEB) do
    local tc = T["b" .. k]
    BADGE[k].c[1], BADGE[k].c[2], BADGE[k].c[3] = (tc or v)[1], (tc or v)[2], (tc or v)[3]
  end
  for _, k in ipairs({ "text", "muted", "faint", "accent", "warn" }) do
    HX[k] = ("%02x%02x%02x"):format(math.floor(C[k][1] * 255 + 0.5), math.floor(C[k][2] * 255 + 0.5), math.floor(C[k][3] * 255 + 0.5))
  end
  local cute = key ~= "base"
  C.__cute = cute or nil
  C.__round = cute and 14 or nil
  C.__shadow = T.light and 0 or 0.6
  C.bar = T.bar or C.accent
  f.__round, card.__round, setF.__round = 14, 12, 14
  if LV.CuteIcons then LV.CuteIcons(cute) end
  -- 나침반 안쪽 원
  local sb = T.surf or { 0.06, 0.07, 0.08 }
  compass.bg:SetVertexColor(sb[1], sb[2], sb[3], 0.95)
  -- 진행 막대: 귀여운 테마는 두껍고 줄무늬
  barBG:SetHeight(cute and 8 or 3)
  barFill:SetHeight(cute and 8 or 3)
  barFill.__c = C.bar
  barFill:SetColorTexture(C.bar[1], C.bar[2], C.bar[3], 1)
  if not LV.barStripe then
    LV.barStripe = f:CreateTexture(nil, "OVERLAY")
    LV.barStripe:SetAllPoints(barFill)
    pcall(LV.barStripe.SetTexture, LV.barStripe, "Interface\\AddOns\\ForgLeveling\\media\\stripe", "REPEAT", "REPEAT")
    if LV.barStripe.SetHorizTile then LV.barStripe:SetHorizTile(true) end
  end
  LV.barStripe:SetShown(cute)
  LV.Repaint(f)
  LV.Repaint(setF)
  if ApplyAlpha then ApplyAlpha() end
  if LV.mascot then LV.mascot:Hide() end
  if Render then Render() end
end


-- 게임 안 사용설명서 창
LV.HELP = {
  { "h", "처음 시작" },
  { "t", "채팅창에 |cffffd66e/forg|r (또는 |cffffd66e/길잡이|r) 를 치거나 미니맵 버튼을 누르면 창이 열려요. 창 머리를 끌면 옮길 수 있어요." },
  { "t", "Questie 애드온을 같이 켜 두면 퀘스트 위치를 정확히 알아요." },
  { "h", "화면 보는 법" },
  { "t", "|cffff9ab0지금 할 일|r  화살표가 가야 할 방향을 가리켜요. \"사냥 중!\"이면 몹 잡는 중이에요." },
  { "t", "|cffff9ab0거기서 할 일|r  받기 · 반납 · 사냥. |cffffd66e[24]|r 는 퀘스트 레벨이고, 빨갈수록 어려워요." },
  { "t", "|cffff9ab0진행 막대|r  차오를수록 이 지역 할 일이 끝나가요." },
  { "t", "|cffff9ab0그다음|r  다음 할 일 목록. 맨 아래 줄은 오늘 반납한 수와 다음 레벨까지 남은 경험치예요." },
  { "h", "버튼" },
  { "i", "ic_help", "사용설명서", "지금 이 창" },
  { "i", "ic_gear", "설정", "테마, 투명도, 넘길 퀘스트" },
  { "i", "ic_full", "자세히", "레벨 구간 전체 단계를 크게" },
  { "i", "ic_mini", "간략", "지금 할 일만 작게" },
  { "i", "ic_pin", "핀 찍기", "지도와 미니맵에 그곳까지 점선 길 (다시 누르면 꺼짐)" },
  { "i", "ic_map", "지도에서 보기", "큰 지도에서 수행 지역 보기" },
  { "i", "ic_skip", "건너뛰기", "이 단계를 순서에서 빼기" },
  { "i", "ic_route", "루트 만들기", "지금 퀘스트로 순서를 다시 짜기" },
  { "i", "ic_s_guide", "정렬: 따라하기", "forg.gg 가이드 순서" },
  { "i", "ic_s_route", "정렬: 경로순", "가까운 곳부터 이어서" },
  { "i", "ic_s_hub", "정렬: 거점순", "마을(거점)별로 묶어서" },
  { "i", "ic_s_level", "정렬: 레벨순", "퀘스트 레벨 낮은 순" },
  { "i", "ic_s_plan", "정렬: 계획", "루트 만들기로 짠 순서" },
  { "i", "logo", "미니맵 버튼", "클릭 열기/닫기 · Shift+클릭 보기 전환 · 끌어서 이동" },
  { "h", "목록에서 클릭" },
  { "t", "|cffff9ab0클릭|r  그 퀘스트를 지도에서 보기 (완료한 건 반납 위치까지 점선 길)" },
  { "t", "|cffff9ab0오른쪽 클릭|r  이미 한 퀘스트로 표시 / 다시 누르면 해제" },
  { "t", "|cffff9ab0Ctrl+클릭|r  이 퀘스트를 맨 앞으로 / 다시 누르면 해제" },
  { "h", "명령어" },
  { "t", "|cffffd66e/forg|r 열기·닫기    |cffffd66e/forg 간략|r · |cffffd66e/forg 자세히|r 보기 바꾸기" },
  { "t", "|cffffd66e/forg 설정|r 설정 창    |cffffd66e/forg 도움말|r 이 창" },
  { "t", "|cffffd66e/forg 먼저 퀘스트이름|r 맨 앞으로    |cffffd66e/forg 먼저해제|r 모두 해제" },
  { "t", "|cffffd66e/forg 단계 5|r · |cffffd66e/forg 다음단계|r 따라하기 단계 이동" },
  { "t", "|cffffd66e/forg 지역 불모의 땅|r 따라하기 지역 바꾸기" },
  { "t", "|cffffd66e/forg 테마 a|r (a · b · c · 기본) 창 색깔" },
  { "t", "|cffffd66e/forg 자동|r · |cffffd66e/forg 회색|r · |cffffd66e/forg 던전|r 켜고 끄기" },
  { "t", "|cffffd66e/forg reset|r 창 위치 초기화 (창이 화면 밖으로 사라졌을 때)" },
  { "h", "알아 두면 좋아요" },
  { "t", "• 제프라스 섬·듀로타·멀고어·티리스팔 숲·불모의 땅은 forg.gg 가이드 순서대로, 다른 지역은 자동 루트로 안내해요." },
  { "t", "• 퀘스트 받기·반납, 레벨 업, 지역 이동 때 순서를 다시 짜요. 이상하면 |cffff9ab0루트 만들기|r를 눌러 주세요." },
  { "t", "• 회색 퀘스트는 빼고, 내 레벨 +3 이상은 뒤로 미뤄요. 초록 퀘스트는 그대로 해요." },
  { "t", "• 던전에 들어가면 그 던전 퀘스트만, 나오면 반납할 곳만 가까운 순서로 보여 줘요." },
  { "t", "• 받은 호위 퀘스트와 지금 잡고 있는 사냥은 항상 맨 앞이에요." },
  { "t", "• 핀 찍기를 누르면 지도와 미니맵에 그곳까지 점선 길이 생겨요. 도착하거나 같은 핀을 다시 누르면 사라져요." },
  { "t", "• 지도에 아무것도 안 뜨면 Questie 설정에서 프로필 초기화를 해 보세요." },
}
function LV.ShowHelp()
  local H = LV.helpF
  if H then
    if H:IsShown() then H:Hide() else H:Show() end
    return
  end
  local W, HH = 420, 520
  H = CreateFrame("Frame", "ForgLevelingHelp", UIParent, BD)
  LV.helpF = H
  H:SetSize(W, HH)
  H:SetPoint("CENTER")
  H:SetFrameStrata("DIALOG")
  H:SetClampedToScreen(true)
  H:SetMovable(true); H:EnableMouse(true)
  H:RegisterForDrag("LeftButton")
  H:SetScript("OnDragStart", H.StartMoving)
  H:SetScript("OnDragStop", H.StopMovingOrSizing)
  H.__round = 14
  Backdrop(H, { C.bg[1], C.bg[2], C.bg[3], 0.97 }, C.line2)
  if UISpecialFrames then table.insert(UISpecialFrames, "ForgLevelingHelp") end
  local M = "Interface\\AddOns\\ForgLeveling\\media\\"
  local logo = H:CreateTexture(nil, "ARTWORK")
  logo:SetSize(24, 24); logo:SetPoint("TOPLEFT", 16, -14); logo:SetTexture(M .. "logo")
  local title = FS(H, 15, C.text)
  title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
  title:SetText("르엘 길잡이 사용설명서")
  local x = FlatButton(H, "", 22, 22)
  x.__round = 11
  x.icon = x:CreateTexture(nil, "ARTWORK"); x.icon:SetSize(11, 11); x.icon:SetPoint("CENTER"); x.icon:SetTexture(M .. "ic_close")
  x:SetPoint("TOPRIGHT", -12, -15)
  x:SetScript("OnClick", function() H:Hide() end)
  x:Paint()
  local sf = CreateFrame("ScrollFrame", nil, H)
  sf:SetPoint("TOPLEFT", 16, -50)
  sf:SetPoint("BOTTOMRIGHT", -16, 16)
  local ch = CreateFrame("Frame", nil, sf)
  ch:SetSize(W - 32, 10)
  sf:SetScrollChild(ch)
  local cw = W - 32
  local y = 0
  for _, it in ipairs(LV.HELP) do
    if it[1] == "h" then
      y = y + (y > 0 and 14 or 0)
      local t = FS(ch, 14, C.accent)
      t:SetPoint("TOPLEFT", 0, -y); t:SetText(it[2])
      local ln = ch:CreateTexture(nil, "ARTWORK")
      ln:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.35)
      ln:SetPoint("TOPLEFT", 0, -(y + 20)); ln:SetSize(cw, 1)
      y = y + 28
    elseif it[1] == "i" then
      local ic = ch:CreateTexture(nil, "ARTWORK")
      ic:SetSize(16, 16); ic:SetPoint("TOPLEFT", 4, -(y + 1)); ic:SetTexture(M .. it[2])
      if it[2] ~= "logo" and it[2] ~= "ic_pin" and it[2] ~= "ic_map" and it[2] ~= "ic_skip" then -- 흰 아이콘만 글자색으로
        ic:SetVertexColor(C.text[1], C.text[2], C.text[3])
      end
      local t = FS(ch, 12, C.text)
      t:SetPoint("TOPLEFT", 30, -(y + 2)); t:SetWidth(cw - 30)
      t:SetText("|cffff9ab0" .. it[3] .. "|r   " .. it[4])
      y = y + 24
    else
      local t = FS(ch, 12, C.text)
      t:SetPoint("TOPLEFT", 4, -y); t:SetWidth(cw - 8)
      t:SetJustifyH("LEFT"); t:SetSpacing(3)
      t:SetText(it[2])
      local h = t:GetStringHeight()
      if type(h) ~= "number" or h < 14 then h = 14 end
      y = y + h + 8
    end
  end
  ch:SetHeight(y + 10)
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(self, d)
    local mx = math.max(0, (y + 10) - self:GetHeight())
    local v = math.min(mx, math.max(0, self:GetVerticalScroll() - d * 40))
    self:SetVerticalScroll(v)
  end)
  local hint = FS(H, 10, C.faint)
  hint:SetPoint("BOTTOMRIGHT", -18, 6); hint:SetText("마우스 휠로 내려 보세요 · Esc로 닫기")
  H:Show()
end

SLASH_FORGLEVELING1 = "/forg"
SLASH_FORGLEVELING2 = "/레벨링"
SLASH_FORGLEVELING3 = "/길잡이"
SlashCmdList.FORGLEVELING = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if not DB then return end
  if msg == "reset" then
    DB.point = nil
    f:ClearAllPoints(); f:SetPoint("CENTER")
    f:Show(); DB.shown = true
    Print("창 위치를 초기화했어요.")
  elseif msg == "레벨우선" or msg == "구역" or msg == "동선" then
    DB.planMode = (DB.planMode == "level") and "area" or "level"
    Print("루트 방식: " .. (DB.planMode == "level" and "레벨 우선" or "구역 단위") .. ". 루트를 다시 짰어요.")
    BuildPlan(true); snap, wpFollow = nil, nil; Render()
  elseif msg == "점선" or msg == "trail" then
    local h, p = LV.HBD()
    local w = ns.trail
    local px, py, pi
    if h then local ok; ok, px, py, pi = pcall(h.GetPlayerWorldPosition, h); if not ok then px = nil end end
    Print(("점선 점검 · 지도 라이브러리 %s · 핀 %s · 목적지 %s · 내 위치 %s"):format(
      h and "있음" or "없음", p and "있음" or "없음",
      w and ("%s %.1f, %.1f"):format(tostring(w.map), w.x, w.y) or "없음 (핀 찍기를 눌러 주세요)",
      px and ("월드 %d"):format(pi or -1) or "못 읽음 (던전 안에서는 게임이 막아요)"))
    LV.trailKey = nil; LV.pinKey = nil; Render()
  elseif msg == "도움말" or msg == "설명서" or msg == "help" then
    LV.ShowHelp()
  elseif msg == "설정" or msg == "config" then
    f:Show(); DB.shown = true; RefreshSettings(); setF:Show()
  elseif msg == "던전" then
    DB.skipDungeon = not DB.skipDungeon
    Print("던전 퀘스트 넘기기: " .. (DB.skipDungeon and "켜짐" or "꺼짐"))
    ReplanIfNeeded()
  elseif msg:find("^먼저") or msg:find("^first") then
    local name = msg:gsub("^먼저%s*", ""):gsub("^first%s*", "")
    ReadQuestLog()
    if name == "" then
      local n = 0
      for k in pairs(CDB.prio or {}) do n = n + 1 end
      if n == 0 then
        Print("사용법: /forg 먼저 퀘스트이름 (이름 일부만 써도 돼요). /forg 먼저해제 로 모두 끄기")
      else
        CDB.prio = {}; BuildPlan(true); snap, wpFollow = nil, nil; Render()
        Print("먼저 하기를 모두 껐어요.")
      end
    elseif name == "해제" or name == "off" then
      CDB.prio = {}; BuildPlan(true); snap, wpFollow = nil, nil; Render()
      Print("먼저 하기를 모두 껐어요.")
    else
      local nn, hit = Norm(name)
      for _, e in ipairs(logList) do
        if e.key and e.key:find(nn, 1, true) then hit = e; break end
      end
      if hit then TogglePrio(hit.key, hit.title)
      else Print("퀘스트 목록에서 '" .. name .. "' 을(를) 찾지 못했어요.") end
    end
  elseif msg == "먼저해제" then
    CDB.prio = {}; BuildPlan(true); snap, wpFollow = nil, nil; Render()
    Print("먼저 하기를 모두 껐어요.")
  elseif msg == "회색" or msg == "grey" or msg == "gray" then
    ReadQuestLog()
    local list = {}
    for _, e in ipairs(logList) do
      if LV.IsGrey(e.level) then list[#list + 1] = e end
    end
    if #list == 0 then
      Print("퀘스트 목록에 회색 퀘스트가 없어요.")
    else
      Print(("회색 퀘스트 %d개 (경험치가 거의 없어요):"):format(#list))
      for _, e in ipairs(list) do
        local st = e.state == 2 and "|cff5fbf4a목표 완료 - 반납하면 끝|r" or "|cff8a9099진행 중 - 포기해도 괜찮아요|r"
        DEFAULT_CHAT_FRAME:AddMessage(("   |cff8a8a8a[%d]|r %s  %s"):format(e.level or 0, e.title, st))
      end
      Print("포기는 퀘스트 목록(L)에서 퀘스트를 고르고 [포기]를 누르세요. 설정의 '회색 퀘스트 넘기기'를 켜 두면 루트에서 자동으로 빠져요.")
    end
  elseif msg:find("^단계") or msg:find("^step") or msg == "다음단계" then
    local G = ns.guide
    if not G then Print("따라하기 데이터가 없어요."); return end
    ReadQuestLog()
    local z = LV.GuideZone()
    if not z then Print("지금 지역에는 따라하기가 없어요 (호드 따라하기: 제프라스 섬·듀로타·멀고어·티리스팔 숲·불모의 땅). /forg 지역 이름 으로 직접 고를 수 있어요."); return end
    local n = tonumber(msg:match("(%d+)"))
    local cur = LV.guideNow and LV.guideNow.zone == z and LV.guideNow.idx or 1
    if msg == "다음단계" then n = cur + 1 end
    if n then
      CDB.guide.floor[z.slug] = math.max(1, math.min(#z.steps, n))
      Print(("%s 따라하기를 %d단계(%s)부터 볼게요."):format(z.name, CDB.guide.floor[z.slug], z.steps[CDB.guide.floor[z.slug]].t))
      DB.sort = "guide"; snap, wpFollow = nil, nil; Render()
    else
      Print(("%s 따라하기 %d단계 (지금 %d단계). /forg 단계 번호 로 이동, /forg 다음단계 로 넘기기"):format(z.name, #z.steps, cur))
      for i, S in ipairs(z.steps) do
        DEFAULT_CHAT_FRAME:AddMessage(("   %s%d. %s  |cff8a9099퀘스트 Lv %s|r"):format(i == cur and "|cffe2a63b▶|r " or "", i, S.t, S.lv or ""))
      end
    end
  elseif msg:find("^지역") then
    local G = ns.guide
    local name = msg:gsub("^지역%s*", "")
    if name == "" then
      CDB.guide = CDB.guide or { floor = {} }; CDB.guide.pin = nil
      local names = {}
      for _, z in ipairs(G.zones) do names[#names + 1] = z.name end
      Print("따라하기 지역을 자동으로 골라요. 직접 고르려면 /forg 지역 이름 (" .. table.concat(names, ", ") .. ")")
    else
      for _, z in ipairs(G.zones) do
        if z.name:find(name, 1, true) then
          CDB.guide = CDB.guide or { floor = {} }; CDB.guide.pin = z.slug
          Print("따라하기 지역: " .. z.name .. " (자동으로 되돌리려면 /forg 지역)")
          DB.sort = "guide"; snap, wpFollow = nil, nil; Render()
          break
        end
      end
    end
  elseif msg:find("^테마") or msg:find("^theme") then
    local v = msg:gsub("^테마%s*", ""):gsub("^theme%s*", "")
    local map = { a = "A", b = "B", c = "C", ["기본"] = "base", base = "base" }
    if map[v] then DB.theme = map[v]; LV.ApplyTheme(); Print("꾸미기: " .. LV.THEMES[DB.theme].name)
    else Print("/forg 테마 a | b | c | 기본  (지금: " .. LV.THEMES[DB.theme or "base"].name .. ")") end
  elseif msg == "길안내" or msg == "길 안내" or msg == "autoway" then
    DB.autoWay = (DB.autoWay == false)
    LV.autoWayKey = nil
    Print("자동 길 안내: " .. (DB.autoWay and "켜짐" or "꺼짐"))
    Render()
  elseif msg == "자동" or msg == "auto" then
    DB.autoPlan = not DB.autoPlan
    Print("자동 루트: " .. (DB.autoPlan and "켜짐" or "꺼짐"))
    if DB.autoPlan then autoLast = 0; AutoPlan("manual") end
  elseif msg == "점검3" or msg == "probe3" then
    Probe3()
  elseif msg == "점검2" or msg == "probe2" then
    Probe2()
  elseif msg == "점검" or msg == "probe" then
    Probe()
  elseif msg == "scan" then
    ScanCompleted(true)
  elseif msg == "clear" then
    CDB.done, CDB.manual, CDB.scanned, CDB.skip = {}, {}, {}, {}
    Print("이 캐릭터의 완료 기록을 지웠어요.")
    Render()
  elseif msg == "간략" or msg == "mini" or msg == "compact" then
    f:Show(); DB.shown = true; SetMode("mini")
  elseif msg == "자세히" or msg == "full" then
    f:Show(); DB.shown = true; SetMode("full")
  elseif msg == "mode" or msg == "보기" then
    f:Show(); DB.shown = true; SetMode(DB.mode == "mini" and "full" or "mini")
  elseif tonumber(msg) then
    manual = true
    f:Show(); DB.shown = true
    Show(BracketForLevel(tonumber(msg)))
  else
    if f:IsShown() then f:Hide(); DB.shown = false
    else
      f:Show(); DB.shown = true
      if not manual then Show(BracketForLevel(UnitLevel("player"))) end
    end
  end
end
