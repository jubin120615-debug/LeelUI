-- LeelUI / Hub.lua
-- 르엘 허브: 르엘 애드온 전부를 한 창에서 켜고 끄고 설정 (미니맵 토끼 / /르엘)

local _, ns = ...
local C = ns.C

local W, H = 580, 492
local RAIL = 214
local HEAD = 54
local TOP = 96   -- 머리 + 분류 알약 줄
local FOOT = 50

local function Print(msg) if ns.Print then ns.Print(msg) else print("|cfff2b3c2[르엘 UI]|r " .. msg) end end

----------------------------------------------------------------------
-- 애드온 정보 도우미
----------------------------------------------------------------------
local A = C_AddOns or {}
local function Exists(name)
    local ok, n = pcall(A.GetAddOnInfo or GetAddOnInfo, name)
    return ok and n ~= nil
end
local function Loaded(name)
    local f = A.IsAddOnLoaded or IsAddOnLoaded
    local ok, v = pcall(f, name)
    return ok and v and true or false
end
local function Enabled(name)
    local f = A.GetAddOnEnableState or GetAddOnEnableState
    local ok, v = pcall(f, name, UnitName("player"))
    if not ok then ok, v = pcall(f, UnitName("player"), name) end
    return ok and (tonumber(v) or 0) > 0
end
local function SetEnabled(name, on)
    local f = on and (A.EnableAddOn or EnableAddOn) or (A.DisableAddOn or DisableAddOn)
    pcall(f, name)
end
local function Version(name)
    local f = A.GetAddOnMetadata or GetAddOnMetadata
    local ok, v = pcall(f, name, "Version")
    return ok and v or ""
end
local function MExists(m) return m.builtin or Exists(m.key) end
local function MLoaded(m) return m.builtin or Loaded(m.key) end
local function MEnabled(m) return m.builtin or Enabled(m.key) end
local function MVersion(m) return Version(m.builtin and "LeelUI" or m.key) end

local function Slash(key, msg)
    local fn = SlashCmdList and SlashCmdList[key]
    if fn then fn(msg or "") return true end
end

StaticPopupDialogs["LEELUI_HUB_RELOAD"] = {
    text = "|cfff2b3c2르엘 허브|r\n다시 불러와야 적용돼요.\n지금 다시 불러올까요?",
    button1 = "다시 불러오기",
    button2 = "나중에",
    OnAccept = function() ReloadUI() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

----------------------------------------------------------------------
-- 모듈 목록 + 오른쪽 설정 내용
----------------------------------------------------------------------
local function MapDB() return LeelMapDB or {} end
local function MarkDB() return LeelMarkDB or {} end
local function SpotDB() return LeelSpotDB or {} end
local function GuideDB() return ForgLevelingDB or {} end
local function SpotRefresh() if LeelSpotAPI and LeelSpotAPI.Refresh then LeelSpotAPI.Refresh() end end
local function SpotSet(k, v)
    if not LeelSpotDB then return end
    LeelSpotDB[k] = v
    SpotRefresh()
end

-- 시전바 모양 고르기 (하나만 켜짐)
local function SetCastStyle(style)
    if (ns.db.castStyle or "bunny") == style then return end
    ns.db.castStyle = style
    StaticPopup_Show("LEELUI_HUB_RELOAD")
end

local MODULES = {
    {
        key = "LeelUI", title = "|cfff2b3c2르엘|r UI", sub = "위쪽 HUD, 미니맵", icon = "hb_ui",
        always = true,
        desc = "내 체력, 대상 창이 있는 위쪽 HUD. 허브도 여기에 들어 있어요.",
        items = {
            { t = "slider", label = "위쪽 HUD 크기", min = 50, max = 150,
              get = function() return math.floor((ns.db.scale or 0.7) * 100 + 0.5) end,
              set = function(v)
                  ns:SetHudScale(v / 100)
                  if InCombatLockdown() then Print("전투가 끝나면 HUD 크기가 바뀌어요.") end
              end },
            { t = "toggle", label = "기본 플레이어/대상 창 숨기기", hint = "다시 불러오기 후 적용",
              get = function() return ns.db.hideBlizzard end,
              set = function(v) ns.db.hideBlizzard = v; StaticPopup_Show("LEELUI_HUB_RELOAD") end },
            { t = "toggle", label = "가운데에 대상과 거리", hint = "끄면 예전처럼 전투 시간",
              get = function() return not ns.db.centerTime end,
              set = function(v)
                  ns.db.centerTime = not v
                  local fr = ns.hudFrames
                  if fr and fr.center then fr.center:Apply() end
              end },
            { t = "toggle", label = "미니맵 아이콘",
              get = function() return not ns.db.minimap.hide end,
              set = function(v)
                  ns:SetMinimapShown(v)
                  if not v then Print("아이콘을 숨겼어요. /르엘 로 허브를 열 수 있어요.") end
              end },
            { t = "toggle", label = "미니맵 아이콘 정리", hint = "길잡이 버튼은 숨기고 토끼 하나만",
              get = function() return ns.db.hub.tidy end,
              set = function(v) ns.db.hub.tidy = v; ns:ApplyHubTidy() end },
            { t = "button", label = "HUD 위치 초기화",
              run = function() ns:ResetPosition(); Print("HUD 위치를 처음대로 돌렸어요.") end },
        },
    },
    {
        key = "LeelUI_Plates", builtin = true, cat = "view",
        title = "적 이름표", sub = "토끼 레벨, 몹 등급, 선공", icon = "hb_plate",
        desc = "적 머리 위 분홍 이름표. 왼쪽 스위치는 다시 불러오기 후 적용.",
        onoff = { reload = true, get = function() return ns.db.nameplates end,
                  set = function(v) ns.db.nameplates = v end },
        items = {
            { t = "slider", label = "이름표 크기", min = 40, max = 150,
              get = function() return math.floor((ns.db.npScale or 1) * 100 + 0.5) end,
              set = function(v) ns.db.npScale = v / 100; if ns.RefreshNameplates then ns:RefreshNameplates() end end },
            { t = "toggle", label = "선공 / 비선공 구별", hint = "선공은 분홍 바, 비선공은 크림색 바",
              get = function() return ns.db.npAggro ~= false end,
              set = function(v) ns.db.npAggro = v; if ns.RefreshPlateInfo then ns:RefreshPlateInfo() end end },
            { t = "toggle", label = "퀘스트 몹 표시", hint = "Questie 퀘스트 원",
              get = function() return ns.db.questCircle ~= false end,
              set = function(v) ns.db.questCircle = v; if ns.RefreshNameplates then ns:RefreshNameplates() end end },
        },
    },
    {
        key = "LeelUI_Minimap", builtin = true, always = true, cat = "view",
        title = "미니맵", sub = "르엘 미니맵", icon = "hb_minimap",
        desc = "동그란 지도 + 아래 버튼 줄. 휠 = 확대/축소.\n옮기기: 아래 '이동 모드'. 애드온 아이콘은 네 칸 버튼 하나로.",
        items = {
            { t = "toggle", label = "르엘 미니맵 쓰기", hint = "끄면 블리자드 기본 (다시 불러오기)",
              get = function() return ns.db.mmStyle ~= "blizz" end,
              set = function(v) ns:SetMinimapStyle(v and "bar" or "blizz") end },
            { t = "button", label = "미니맵 위치 초기화",
              run = function() if ns.ResetMinimapPosition then ns:ResetMinimapPosition() end; Print("미니맵을 처음 자리로 돌렸어요.") end },
            { t = "toggle", label = "다른 애드온 아이콘 모으기",
              get = function() return ns.db.mmCollect ~= false end,
              set = function(v) ns.db.mmCollect = v; StaticPopup_Show("LEELUI_HUB_RELOAD") end },
        },
    },
    {
        key = "LeelUI_Cast", builtin = true, always = true, cat = "view",
        title = "시전바", sub = "깡충 토끼, 발자국", icon = "hb_cast",
        desc = "모양을 바꾸면 다시 불러오기 후 적용.\n자리 옮기기는 아래 '이동 모드'.",
        items = {
            { t = "toggle", label = "깡충 토끼", hint = "알약 바 위를 토끼가 달려가요 (화면 가운데 아래)",
              get = function() return (ns.db.castStyle or "bunny") == "bunny" end,
              set = function() SetCastStyle("bunny") end },
            { t = "toggle", label = "토끼 발자국", hint = "발자국 6개가 하나씩 찍혀요 (화면 가운데 아래)",
              get = function() return ns.db.castStyle == "paw" end,
              set = function() SetCastStyle("paw") end },
            { t = "toggle", label = "예전 얇은 바", hint = "위쪽 HUD 아래에 붙은 얇은 바",
              get = function() return ns.db.castStyle == "hud" end,
              set = function() SetCastStyle("hud") end },
            { t = "toggle", label = "내 시전바만 보기", hint = "대상(적)의 시전바는 숨겨요",
              get = function() return ns.db.castMineOnly end,
              set = function(v)
                  ns.db.castMineOnly = v and true or false
                  local tc = ns.casts and ns.casts.target
                  if tc then
                      if v then tc.casting, tc.finishing = false, false; tc:SetScript("OnUpdate", nil); tc:Hide(); if tc.OnLayout then tc:OnLayout() end end
                  end
              end },
            { t = "button", label = "시전바 위치 초기화",
              run = function() if ns.ResetCastPosition then ns:ResetCastPosition() end; Print("시전바 위치를 처음대로 돌렸어요.") end },
        },
    },
    {
        key = "LeelUI_Font", builtin = true, always = true, cat = "view",
        title = "|cfff2b3c2르엘|r 글씨체", sub = "게임 글씨 바꾸기", icon = "hb_font",
        desc = "재접속 = 캐릭터 선택 화면에 갔다 오기\n내 글꼴: LeelUI\\MyFonts 폴더의 '글꼴 넣는 법' 참고",
        items = {
            { t = "choice", label = "기본 글씨", hint = "메뉴, 퀘스트, 툴팁", slot = "body", when = "now" },
            { t = "choice", label = "이름/제목", hint = "이름표, 창 제목", slot = "name", when = "now" },
            { t = "choice", label = "채팅", hint = "채팅창, 말풍선", slot = "chat", when = "now" },
            { t = "choice", label = "숫자", hint = "피해, 게임 숫자", slot = "num", when = "relog" },
            { t = "choice", label = "글씨 크기", hint = "기본 글씨, 채팅", slot = "size", when = "now" },
            { t = "button", label = "추천 조합", run = function() ns:SetFontPreset(); Print("추천 조합: 기본 글씨와 채팅은 고운돋움, 이름/제목은 주아.") end },
            { t = "button", label = "다시 불러오기", run = function() ReloadUI() end },
        },
    },
    {
        key = "LeelMap", title = "Leel Map", sub = "세계 지도", icon = "hb_map", slash = "LEELMAP",
        desc = "작은 지도 창, 걸을 때 흐려짐, 좌표, 지역 레벨.",
        items = {
            { t = "toggle", label = "걸을 때 흐리게", get = function() return MapDB().fade end, cmd = "흐림" },
            { t = "toggle", label = "좌표 줄", get = function() return MapDB().coords end, cmd = "좌표" },
            { t = "toggle", label = "지역 레벨", get = function() return MapDB().levels end, cmd = "레벨" },
            { t = "toggle", label = "작은 창 지도", hint = "지도를 다시 열면 적용", get = function() return MapDB().mini end, cmd = "작게" },
            { t = "button", label = "지도 위치 초기화", cmd = "위치" },
        },
    },
    {
        key = "LeelUI_Party", builtin = true, cat = "party",
        title = "파티 프레임", sub = "둥근 파티 창", icon = "hb_party",
        desc = "르엘 파티 프레임. 왼쪽 스위치는 다시 불러오기 후 적용.\n자리 옮기기는 아래 '이동 모드'.",
        onoff = { reload = true, get = function() return ns.db.party end,
                  set = function(v) ns.db.party = v end },
        items = {
            { t = "slider", label = "파티 프레임 크기", min = 50, max = 150,
              get = function() return math.floor((ns.db.partyScale or 0.75) * 100 + 0.5) end,
              set = function(v)
                  ns:SetPartyScale(v / 100)
                  if InCombatLockdown() then Print("전투가 끝나면 파티 프레임 크기가 바뀌어요.") end
              end },
            { t = "toggle", label = "기본 파티 창 숨기기", hint = "다시 불러오기 후 적용",
              get = function() return ns.db.partyHideBlizzard ~= false end,
              set = function(v) ns.db.partyHideBlizzard = v; StaticPopup_Show("LEELUI_HUB_RELOAD") end },
            { t = "button",
              label = function() return "배치: " .. ((ns.PARTY_LAYOUT_NAMES or {})[ns.db.partyLayout or "row"] or "가로 줄") end,
              run = function() ns:CyclePartyLayout() end },
            { t = "button", label = "위치 초기화",
              run = function() ns:ResetPartyPosition(); Print("파티 프레임 위치를 처음대로 돌렸어요.") end },
        },
    },
    {
        key = "LeelMark", title = "Leel Mark", sub = "파티 징", icon = "hb_mark", slash = "LEELMARK",
        desc = "자동 징 찍기 바. 단축키는 게임 메뉴 > 단축키 > 애드온.",
        items = {
            { t = "toggle", label = "징 바 보이기", hint = "꺼도 단축키는 동작",
              get = function() return MarkDB().show ~= "never" end,
              set = function(v) if v then Slash("LEELMARK", "보이기") else Slash("LEELMARK", "숨기기") end end },
            { t = "toggle", label = "솔로일 때도 보이기",
              get = function() return MarkDB().show == "always" end,
              set = function() if MarkDB().show ~= "never" then Slash("LEELMARK", "보이기") end end },
            { t = "toggle", label = "파티 채팅 알림", get = function() return MarkDB().announce end, cmd = "알림" },
            { t = "button", label = "바 위치 초기화", cmd = "위치" },
        },
    },
    {
        key = "LeelSpot", title = "Leel Spot", sub = "퀘스트 물건", icon = "hb_spot", slash = "LEELSPOT",
        desc = "퀘스트 물건 위 토끼 이름표와 분홍 선.",
        items = {
            { t = "toggle", label = "이름표 켜기",
              get = function() return SpotDB().on ~= false end,
              set = function(v) Slash("LEELSPOT", v and "켜기" or "끄기") end },
            { t = "toggle", label = "퀘스트 물건만", hint = "끄면 모든 물건에 표시",
              get = function() return not SpotDB().all end, cmd = "퀘만" },
            { t = "toggle", label = "물건 가리키는 선",
              get = function() return (SpotDB().stem or 34) > 0 end,
              set = function(v) Slash("LEELSPOT", v and "선 34" or "선 0") end },
            { t = "button", label = "점검", cmd = "점검" },
        },
    },
    {
        key = "ForgLeveling", title = "|cfff2b3c2르엘|r 길잡이", sub = "레벨링 안내", icon = "hb_guide", slash = "FORGLEVELING",
        desc = "레벨링 길잡이 (forg.gg 자료).",
        items = {
            { t = "button", label = "길잡이 창 열기", cmd = "" },
            { t = "toggle", label = "미니맵 버튼", hint = "미니맵 아이콘 정리를 켜면 숨겨져요",
              get = function() return not GuideDB().minimapHide end,
              set = function(v)
                  if not ForgLevelingDB then return end
                  ForgLevelingDB.minimapHide = not v
                  local b = _G.ForgLevelingMinimapButton
                  if b then b:SetShown(v) end
              end },
        },
    },
    {
        key = "LeelUI_Shop", builtin = true, cat = "util",
        title = "상점 토끼", sub = "자동 수리, 잡템 판매", icon = "hb_shop",
        desc = "상인 창을 열면 알아서. Shift 누른 채 열면 이번엔 쉬어요.\n안 팔고 싶은 회색 템은 가방에서 Alt+클릭.",
        onoff = { get = function() return ns.ShopDB().on end,
                  set = function(v) ns.ShopDB().on = v end },
        items = {
            { t = "toggle", label = "자동 수리", hint = "돈이 모자라면 건너뛰어요",
              get = function() return ns.ShopDB().repair end, set = function(v) ns.ShopDB().repair = v end },
            { t = "toggle", label = "회색 잡템 자동 판매",
              get = function() return ns.ShopDB().sell end, set = function(v) ns.ShopDB().sell = v end },
            { t = "toggle", label = "판매 결과 알려주기", hint = "상인 창 위에 작은 판 + 채팅 한 줄",
              get = function() return ns.ShopDB().report end, set = function(v) ns.ShopDB().report = v end },
            { t = "button", label = function() return "안 팔기 목록 비우기 (" .. ns:ShopKeepCount() .. ")" end,
              run = function() ns:ShopClearKeep() end },
        },
    },
    {
        key = "LeelUI_Quest", builtin = true, cat = "util",
        title = "퀘스트 자동", sub = "받기, 완료", icon = "hb_quest",
        desc = "말만 걸면 받고, 고를 보상이 없으면 완료까지. 보상 고르기는 직접.\nShift 누른 채 말 걸면 그때만 쉬어요.",
        onoff = { get = function() return ns.QuestDB().on end, set = function(v) ns.QuestDB().on = v end },
        items = {
            { t = "toggle", label = "자동 수락",
              get = function() return ns.QuestDB().accept end, set = function(v) ns.QuestDB().accept = v end },
            { t = "toggle", label = "자동 완료", hint = "보상을 골라야 하면 멈춰요",
              get = function() return ns.QuestDB().complete end, set = function(v) ns.QuestDB().complete = v end },
            { t = "toggle", label = "가장 비싼 보상 표시", hint = "팔 때 제일 비싼 보상에 분홍 테",
              get = function() return ns.QuestDB().best end, set = function(v) ns.QuestDB().best = v end },
            { t = "toggle", label = "회색 퀘스트 건너뛰기", hint = "내 레벨보다 한참 낮은 퀘는 안 받아요",
              get = function() return ns.QuestDB().skipTrivial end, set = function(v) ns.QuestDB().skipTrivial = v end },
            { t = "toggle", label = "대화 하나뿐이면 넘기기", hint = "퀘스트 없이 대화 고르기 하나만 있을 때",
              get = function() return ns.QuestDB().gossip end, set = function(v) ns.QuestDB().gossip = v end },
        },
    },
    {
        key = "LeelUI_Bags", builtin = true, cat = "util",
        title = "르엘 가방", sub = "통합 가방, 남은 칸", icon = "hb_bag",
        desc = "가방 5개를 분홍 창 하나로. 창 머리를 끌면 옮겨져요.\n미니맵 아래 숫자: 클릭 = 가방 열기, Shift+끌기 = 옮기기.",
        onoff = { get = function() return ns.BagsDB().on end,
                  set = function(v) ns.BagsDB().on = v; if ns.UpdateBags then ns.UpdateBags() end end },
        items = {
            { t = "header", label = "가방 창",
              btn = { label = "위치 초기화", run = function() ns.BagsDB().winPos = nil; local w = _G.LeelUI_Bag; if w and w.Place then w.Place() end end } },
            { t = "header", label = "남은 칸",
              btn = { label = "숫자 위치 초기화", run = function() ns.BagsDB().chipPos = nil; local c = _G.LeelUI_BagChip; if c and c.Place then c.Place() end end } },
            { t = "toggle", label = "미니맵 아래 숫자",
              get = function() return ns.BagsDB().chip end,
              set = function(v) ns.BagsDB().chip = v; if ns.UpdateBags then ns.UpdateBags() end end },
            { t = "toggle", label = "거의 찼을 때 알림", hint = "남은 칸 3개 이하가 되는 순간 한 번",
              get = function() return ns.BagsDB().warn end,
              set = function(v) ns.BagsDB().warn = v end },
            { t = "header", label = "꽉 찼을 때" },
            { t = "toggle", label = "버릴 템 고르기 창", hint = "제일 싼 템 3개 + 각각 버리기 버튼 (전투가 끝나면 떠요)",
              get = function() return ns.BagsDB().full ~= false end,
              set = function(v) ns.BagsDB().full = v; if not v and ns.HideBagFull then ns.HideBagFull() end end },
        },
    },
    {
        key = "LeelUI_LootWin", builtin = true, cat = "util",
        title = "줍기 창", sub = "분홍 줍기 창", icon = "hb_bag",
        desc = "루팅 창을 르엘 모양으로. 마우스 근처에 떠요.\n왼쪽 스위치를 끄면 게임 기본 창 (다시 불러오기 후 적용).",
        onoff = { reload = true, get = function() return ns.LootDB().win end,
                  set = function(v) ns.LootDB().win = v end },
        items = {
            { t = "toggle", label = "자동 줍기", hint = "게임 설정. 켜면 창 없이 바로 주워요",
              get = function() return GetCVar("autoLootDefault") == "1" end,
              set = function(v) SetCVar("autoLootDefault", v and "1" or "0") end },
        },
    },
    {
        key = "LeelUI_Loot", builtin = true, cat = "util",
        title = "르엘 줍기", sub = "시체 반짝 상자", icon = "hb_loot",
        needs = "LeelSpot", needsText = "상자는 Leel Spot이 그려요.\n애드온 목록에서 Leel Spot을 켜고 다시 불러오면 설정할 수 있어요.",
        desc = "주울 게 남은 가장 가까운 시체 하나에 반짝 상자.\n높이는 '미리보기'를 누르고 시체 앞에서 맞추면 쉬워요.",
        onoff = { get = function() return Loaded("LeelSpot") and SpotDB().loot ~= false end,
                  set = function(v) SpotSet("loot", v) end },
        items = {
            { t = "toggle", label = "죽은 몹 이름표 숨기기", hint = "0% 체력바 대신 상자만",
              get = function() return ns.db.npHideDead ~= false end,
              set = function(v) ns.db.npHideDead = v; if ns.RefreshDeadPlates then ns:RefreshDeadPlates() end end },
            { t = "toggle", label = "여러 시체 표시", hint = "가까운 건 큰 상자, 나머지는 작고 흐린 상자",
              get = function() return SpotDB().lootMulti ~= false end,
              set = function(v) SpotSet("lootMulti", v) end },
            { t = "toggle", label = "통통 튀는 움직임",
              get = function() return SpotDB().lootBob ~= false end,
              set = function(v) SpotSet("lootBob", v) end },
            { t = "slider", label = "상자 높이  (왼쪽 = 시체 쪽 아래)", min = -200, max = 40, fmt = "%d",
              get = function() return SpotDB().lootY or -70 end,
              set = function(v) SpotSet("lootY", v) end },
            { t = "slider", label = "상자 크기", min = 60, max = 160,
              get = function() return math.floor((SpotDB().lootSize or 1) * 100 + 0.5) end,
              set = function(v) SpotSet("lootSize", v / 100) end },
            { t = "button", label = "미리보기 5초",
              run = function() if LeelSpotAPI and LeelSpotAPI.Preview then LeelSpotAPI.Preview(5) end end },
            { t = "button", label = "기본값으로",
              run = function()
                  if not LeelSpotDB then return end
                  LeelSpotDB.lootY, LeelSpotDB.lootSize, LeelSpotDB.lootBob = -70, 1.0, true
                  SpotRefresh()
              end },
        },
    },
}
ns.HUB_MODULES = MODULES

-- 대분류 (알약). 애드온이 하나도 없는 분류는 안 보여요
local CATS = {
    { key = "view",  label = "화면",       icon = "hb_c_view" },
    { key = "map",   label = "지도/길",  icon = "hb_c_map" },
    { key = "party", label = "파티/전투", icon = "hb_c_party" },
    { key = "util",  label = "편의",       icon = "hb_c_util" },
}
local MOD_CAT = { LeelUI = "view", LeelMap = "map", LeelSpot = "map", ForgLeveling = "map", LeelMark = "party" }
for _, m in ipairs(MODULES) do m.cat = m.cat or MOD_CAT[m.key] or "util" end
local curCat = "view"

----------------------------------------------------------------------
-- 부품
----------------------------------------------------------------------
local function Switch(parent)
    local sw = CreateFrame("Frame", nil, parent)
    sw:SetSize(36, 18)
    local bg = ns.RoundRect(sw, 9, nil, "ARTWORK", 0, 0)
    local knob = sw:CreateTexture(nil, "OVERLAY"); knob:SetSize(12, 12)
    knob:SetTexture(ns.MEDIA .. "circle")
    function sw:Set(on, onPink)
        if on then
            bg:SetColor(onPink and C.ink or C.acc, 1)
            local k = onPink and C.accHi or C.ink
            knob:SetVertexColor(k[1], k[2], k[3], 1)
            knob:ClearAllPoints(); knob:SetPoint("RIGHT", -3, 0)
        else
            bg:SetColor({ 1, 1, 1 }, 0.14)
            knob:SetVertexColor(C.tx2[1], C.tx2[2], C.tx2[3], 1)
            knob:ClearAllPoints(); knob:SetPoint("LEFT", 3, 0)
        end
    end
    return sw
end

local function IconDisc(parent, size, file)
    local h = CreateFrame("Frame", nil, parent)
    h:SetSize(size, size)
    h.bg = h:CreateTexture(nil, "ARTWORK")
    h.bg:SetTexture(ns.MEDIA .. "circle"); h.bg:SetAllPoints()
    h.ic = h:CreateTexture(nil, "OVERLAY")
    h.ic:SetTexture(ns.MEDIA .. file)
    h.ic:SetSize(size * 0.6, size * 0.6); h.ic:SetPoint("CENTER")
    return h
end

----------------------------------------------------------------------
-- 창 만들기
----------------------------------------------------------------------
local hub
local sel = 1

local function Refresh() end -- 아래에서 다시 정의

local function BuildPane(f)
    local pane = CreateFrame("Frame", nil, f)
    pane:SetPoint("TOPLEFT", RAIL + 1, -TOP)
    pane:SetPoint("BOTTOMRIGHT", 0, FOOT)
    pane.title = ns.Font(pane, 15)
    pane.title:SetPoint("TOPLEFT", 18, -16)
    pane.ver = ns.Num(pane, 12, C.tx2, false)
    pane.ver:SetPoint("LEFT", pane.title, "RIGHT", 8, -1)
    pane.desc = ns.Font(pane, 11, { 0.62, 0.54, 0.52 })
    pane.desc:SetPoint("TOPLEFT", 18, -38)
    pane.desc:SetPoint("RIGHT", -18, 0)
    pane.desc:SetJustifyH("LEFT")
    pane.note = ns.Font(pane, 12, C.tx2)
    pane.note:SetPoint("TOPLEFT", 18, -70)
    pane.note:SetPoint("RIGHT", -18, 0)
    pane.note:SetJustifyH("LEFT")
    pane.rows, pane.btns = {}, {}
    return pane
end

local function ClearPane(pane)
    for _, r in ipairs(pane.rows) do r:Hide() end
    for _, r in ipairs(pane.choices or {}) do r:Hide() end
    for _, r in ipairs(pane.sliders or {}) do r:Hide() end
    if pane.input then pane.input:Hide() end
    if dd then dd:Hide() end
    for _, b in ipairs(pane.btns) do b:Hide() end
    for _, h in ipairs(pane.heads or {}) do h:Hide() end
    pane.note:SetText("")
end

-- 묶음 제목 줄: 분홍 작은 제목 + 가는 선 (+ 오른쪽 작은 글자 버튼)
local function HeaderRow(pane, i)
    pane.heads = pane.heads or {}
    local h = pane.heads[i]
    if h then return h end
    h = CreateFrame("Frame", nil, pane)
    h:SetHeight(20)
    h.label = ns.Font(h, 11.5, C.acc); h.label:SetPoint("LEFT", 0, 0)
    h.line = h:CreateTexture(nil, "BORDER")
    h.line:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.25); h.line:SetHeight(1)
    h.line:SetPoint("LEFT", h.label, "RIGHT", 8, 0)
    h.btn = CreateFrame("Button", nil, h)
    h.btn:SetHeight(18)
    h.btn.fs = ns.Font(h.btn, 10.5, { 0.62, 0.54, 0.52 }); h.btn.fs:SetPoint("RIGHT", 0, 0)
    h.btn:SetScript("OnEnter", function(self) self.fs:SetTextColor(C.accHi[1], C.accHi[2], C.accHi[3]) end)
    h.btn:SetScript("OnLeave", function(self) self.fs:SetTextColor(0.62, 0.54, 0.52) end)
    h.btn:SetPoint("RIGHT", 0, 0)
    pane.heads[i] = h
    return h
end

local function ToggleRow(pane, i)
    local r = pane.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, pane)
    r:SetHeight(36)
    r.name = ns.Font(r, 13); r.name:SetPoint("TOPLEFT", 0, -6)
    r.hint = ns.Font(r, 10.5, { 0.62, 0.54, 0.52 }); r.hint:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
    r.sw = Switch(r); r.sw:SetPoint("RIGHT", 0, 0)
    -- 하위 설정 표시 (└)
    r.tv = r:CreateTexture(nil, "BORDER"); r.tv:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.45)
    r.tv:SetWidth(1.5); r.tv:SetPoint("TOPLEFT", 6, 2); r.tv:SetPoint("BOTTOMLEFT", r, "LEFT", 6, 0)
    r.th = r:CreateTexture(nil, "BORDER"); r.th:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.45)
    r.th:SetHeight(1.5); r.th:SetPoint("LEFT", 6, 0); r.th:SetWidth(8)
    r.line = r:CreateTexture(nil, "BORDER")
    r.line:SetColorTexture(0.839, 0.627, 0.612, 0.10); r.line:SetHeight(1)
    r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT")
    r:SetScript("OnEnter", function(self) self.name:SetTextColor(1, 1, 1) end)
    r:SetScript("OnLeave", function(self) self.name:SetTextColor(C.tx[1], C.tx[2], C.tx[3]) end)
    pane.rows[i] = r
    return r
end

-- 고르기 줄: 이름 + 회색 설명 + 오른쪽 알약(현재 값, 그 글꼴로)
local function ChoiceRow(pane, i)
    pane.choices = pane.choices or {}
    local r = pane.choices[i]
    if r then return r end
    r = CreateFrame("Frame", nil, pane)
    r:SetHeight(36)
    r.name = ns.Font(r, 13); r.name:SetPoint("LEFT", 0, 0)
    r.hint = ns.Font(r, 10.5, { 0.62, 0.54, 0.52 }); r.hint:SetPoint("LEFT", r.name, "RIGHT", 8, -1)
    r.pill = CreateFrame("Button", nil, r)
    r.pill:SetHeight(24); r.pill:SetPoint("RIGHT", 0, 0)
    r.pill.bg = ns.RoundRect(r.pill, 12, { 0.23, 0.18, 0.17 }, "BACKGROUND", 0, 0)
    r.pill.fs = r.pill:CreateFontString(nil, "OVERLAY")
    r.pill.fs:SetPoint("LEFT", 12, 0)
    r.pill.ar = r.pill:CreateTexture(nil, "OVERLAY"); r.pill.ar:SetTexture(ns.MEDIA .. "hb_down")
    r.pill.ar:SetSize(11, 11); r.pill.ar:SetVertexColor(C.acc[1], C.acc[2], C.acc[3]); r.pill.ar:SetPoint("RIGHT", -9, 0)
    r.pill:SetScript("OnEnter", function(self) self.bg:SetColor({ 0.32, 0.25, 0.24 }, 1) end)
    r.pill:SetScript("OnLeave", function(self) self.bg:SetColor({ 0.23, 0.18, 0.17 }, 1) end)
    -- 적용 시점 꼬리표: 바로 / 다시 불러오기 / 재접속
    r.when = CreateFrame("Frame", nil, r)
    r.when:SetHeight(16)
    r.when:SetPoint("RIGHT", r.pill, "LEFT", -6, 0)
    r.when.bg = ns.RoundRect(r.when, 8, nil, "BACKGROUND", 0, 0)
    r.when.fs = ns.Font(r.when, 10); r.when.fs:SetPoint("CENTER", 0, 0)
    r.line = r:CreateTexture(nil, "BORDER")
    r.line:SetColorTexture(0.839, 0.627, 0.612, 0.10); r.line:SetHeight(1)
    r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT")
    pane.choices[i] = r
    return r
end

local function ChoiceOptions(slot)
    if slot == "size" then return ns.FONT_SIZES or {} end
    local out = {}
    for _, f in ipairs(ns.FONT_LIST or {}) do
        if not f.numOnly or slot == "num" then out[#out + 1] = f end
    end
    return out
end

local function LabelFor(slot, key)
    for _, o in ipairs(ChoiceOptions(slot)) do if o.key == key then return o.label, o.file end end
    return tostring(key)
end

local dd
local ShowPane
local function OpenDropdown(anchor, slot, onPick)
    if not dd then
        dd = CreateFrame("Frame", nil, hub)
        dd:SetFrameStrata("FULLSCREEN_DIALOG")
        dd:EnableMouse(true)
        ns.RoundPlate(dd, 12, { 0.125, 0.094, 0.086, 0.98 }, { 0.949, 0.702, 0.761, 0.6 })
        dd.items = {}
        dd:SetScript("OnUpdate", function(self)
            if not self:IsMouseOver(20, -20, -20, 20) and not (self.anchor and self.anchor:IsMouseOver()) then
                self.away = (self.away or 0) + 1
                if self.away > 40 then self:Hide() end
            else
                self.away = 0
            end
        end)
    end
    local opts = ChoiceOptions(slot)
    local cur = ns.db.font and ns.db.font[slot]
    local w = 150
    for i, o in ipairs(opts) do
        local b = dd.items[i]
        if not b then
            b = CreateFrame("Button", nil, dd)
            b:SetHeight(24)
            b.hl = ns.RoundRect(b, 10, nil, "BACKGROUND", 2, 0)
            b.fs = b:CreateFontString(nil, "OVERLAY"); b.fs:SetPoint("LEFT", 10, 0)
            b.tag = ns.Font(b, 10, { 0.62, 0.54, 0.52 }); b.tag:SetPoint("RIGHT", -8, 0)
            dd.items[i] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 25); b:SetPoint("TOPRIGHT", -6, -6 - (i - 1) * 25)
        if not (o.file and b.fs:SetFont(o.file, 14, "")) then b.fs:SetFont(ns.FONT, 13, "") end
        b.fs:SetText(o.label)
        b.tag:SetText("")
        local on = o.key == cur
        b.hl:SetColor(on and C.acc or { 1, 1, 1 }, on and 1 or 0)
        local tc = on and C.ink or C.tx
        b.fs:SetTextColor(tc[1], tc[2], tc[3])
        b:SetScript("OnEnter", function(self) if not on then self.hl:SetColor({ 1, 1, 1 }, 0.08) end end)
        b:SetScript("OnLeave", function(self) self.hl:SetColor(on and C.acc or { 1, 1, 1 }, on and 1 or 0) end)
        b:SetScript("OnClick", function() dd:Hide(); onPick(o.key) end)
        b:Show()
        w = math.max(w, b.fs:GetStringWidth() + 80)
    end
    for i = #opts + 1, #dd.items do dd.items[i]:Hide() end
    dd:SetSize(w, #opts * 25 + 12)
    dd.anchor = anchor
    dd.away = 0
    dd:ClearAllPoints()
    dd:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    dd:Show()
end

-- 글자 입력 줄 (파일 이름 등)
local function InputRow(pane)
    if pane.input then return pane.input end
    local r = CreateFrame("Frame", nil, pane)
    r:SetHeight(40)
    r.name = ns.Font(r, 13); r.name:SetPoint("TOPLEFT", 0, -2)
    r.hint = ns.Font(r, 10.5, { 0.62, 0.54, 0.52 }); r.hint:SetPoint("LEFT", r.name, "RIGHT", 8, -1)
    r.btn = ns.MakeButton(r, "추가", true, nil, 56)
    r.btn:SetHeight(24)
    r.btn:SetPoint("BOTTOMRIGHT", 0, 0)
    local box = CreateFrame("EditBox", nil, r)
    box:SetHeight(24)
    box:SetPoint("BOTTOMLEFT", 0, 0)
    box:SetPoint("RIGHT", r.btn, "LEFT", -6, 0)
    box:SetAutoFocus(false)
    box:SetFont(STANDARD_TEXT_FONT or ns.FONT, 12, "")
    box:SetTextInsets(10, 10, 0, 0)
    box:SetMaxLetters(80)
    box.bg = ns.RoundRect(box, 12, { 0.23, 0.18, 0.17 }, "BACKGROUND", 0, 0)
    box.ph = box:CreateFontString(nil, "ARTWORK"); box.ph:SetFont(STANDARD_TEXT_FONT or ns.FONT, 12, "")
    box.ph:SetTextColor(0.5, 0.44, 0.42); box.ph:SetPoint("LEFT", 10, 0)
    box.ph:SetText("예: Cafe24DongdongRegular.ttf")
    box:SetScript("OnTextChanged", function(self) self.ph:SetShown(self:GetText() == "") end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self) self.bg:SetColor({ 0.32, 0.25, 0.24 }, 1) end)
    box:SetScript("OnEditFocusLost", function(self) self.bg:SetColor({ 0.23, 0.18, 0.17 }, 1) end)
    r.box = box
    r.line = r:CreateTexture(nil, "BORDER")
    r.line:SetColorTexture(0.839, 0.627, 0.612, 0.10); r.line:SetHeight(1)
    r.line:SetPoint("BOTTOMLEFT", 0, -8); r.line:SetPoint("BOTTOMRIGHT", 0, -8)
    pane.input = r
    return r
end

-- 크기 줄: 이름 + 큰 숫자 + 분홍 트랙 (휠로도 조절)
local function SliderRow(pane, i)
    pane.sliders = pane.sliders or {}
    local r = pane.sliders[i]
    if r then return r end
    r = CreateFrame("Frame", nil, pane)
    r:SetHeight(50)
    r.name = ns.Font(r, 13); r.name:SetPoint("TOPLEFT", 0, -4)
    r.val = ns.Num(r, 17, C.accHi); r.val:SetPoint("TOPRIGHT", 0, -1)
    local s = CreateFrame("Slider", nil, r)
    s:SetOrientation("HORIZONTAL")
    s:SetHeight(16)
    s:SetPoint("TOPLEFT", 0, -26); s:SetPoint("TOPRIGHT", 0, -26)
    s:SetValueStep(1)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)
    -- 트랙은 줄(r)에 붙이고 슬라이더를 그 위로 (손잡이가 가려지지 않게)
    local tr = CreateFrame("Frame", nil, r)
    tr:SetHeight(6); tr:SetPoint("LEFT", s, "LEFT"); tr:SetPoint("RIGHT", s, "RIGHT")
    s:SetFrameLevel(tr:GetFrameLevel() + 3)
    ns.RoundRect(tr, 3, nil, "BACKGROUND", 0, 0):SetColor({ 1, 1, 1 }, 0.14)
    r.fill = CreateFrame("Frame", nil, tr)
    r.fill:SetHeight(6); r.fill:SetPoint("LEFT")
    ns.RoundRect(r.fill, 3, C.acc, "BORDER", 0, 0)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(ns.MEDIA .. "circle"); thumb:SetSize(16, 16)
    thumb:SetVertexColor(C.accHi[1], C.accHi[2], C.accHi[3], 1)
    s:SetThumbTexture(thumb)
    r.s = s
    r.line = r:CreateTexture(nil, "BORDER")
    r.line:SetColorTexture(0.839, 0.627, 0.612, 0.10); r.line:SetHeight(1)
    r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT")
    function r:Paint(v)
        local lo, hi = self.s:GetMinMaxValues()
        self.val:SetFormattedText(self.fmt or "%d%%", v)
        local w = self.s:GetWidth(); if not w or w < 10 then w = 320 end
        self.fill:SetWidth(math.max(6, (v - lo) / math.max(1, hi - lo) * w))
    end
    s:SetScript("OnSizeChanged", function() r:Paint(math.floor(s:GetValue() + 0.5)) end)
    pane.sliders[i] = r
    return r
end

local function PaneButton(pane, i)
    local b = pane.btns[i]
    if b then return b end
    b = ns.MakeButton(pane, "", false, nil, 80)
    pane.btns[i] = b
    return b
end

ShowPane = function()
    local pane, m = hub.pane, MODULES[sel]
    ClearPane(pane)
    pane.title:SetText(m.title)
    pane.ver:SetText("") -- 버전은 머리의 르엘 UI 버전 하나만
    pane.desc:SetText(m.desc or "")

    if not MExists(m) then
        pane.note:SetText("이 컴퓨터에는 설치되어 있지 않아요.")
        return
    end
    if not MLoaded(m) then
        pane.note:SetText(MEnabled(m)
            and "켜 두었어요. 다시 불러오면 설정이 나타나요."
            or "꺼져 있어요. 왼쪽 스위치로 켜고 다시 불러오면 설정할 수 있어요.")
        return
    end

    if m.needs and not Loaded(m.needs) then
        pane.note:SetText(m.needsText or (m.needs .. " 애드온이 필요해요."))
        return
    end

    local y, ti, bi, ci, si, hi = -66, 0, 0, 0, 0, 0
    local lastBtn
    for _, it in ipairs(m.items) do
        if it.t == "header" then
            lastBtn = nil
            hi = hi + 1
            local h = HeaderRow(pane, hi)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 18, y - 4); h:SetPoint("TOPRIGHT", -18, y - 4)
            h.label:SetText(it.label)
            if it.btn then
                h.btn.fs:SetText(it.btn.label)
                h.btn:SetWidth(h.btn.fs:GetStringWidth() + 4)
                h.btn:SetScript("OnClick", function() it.btn.run(); C_Timer.After(0.05, ShowPane) end)
                h.btn:Show()
                h.line:SetPoint("RIGHT", h.btn, "LEFT", -8, 0)
            else
                h.btn:Hide()
                h.line:SetPoint("RIGHT", h, "RIGHT", 0, 0)
            end
            h:Show()
            y = y - 24
        elseif it.t == "slider" then
            lastBtn = nil
            si = si + 1
            local r = SliderRow(pane, si)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 18, y); r:SetPoint("TOPRIGHT", -18, y)
            r.name:SetText(it.label)
            r.fmt = it.fmt
            local s = r.s
            s:SetScript("OnValueChanged", nil)
            s:SetMinMaxValues(it.min, it.max)
            local v = it.get()
            s:SetValue(v); r:Paint(v)
            s:SetScript("OnValueChanged", function(_, nv, user)
                nv = math.floor(nv + 0.5)
                r:Paint(nv)
                if user then it.set(nv) end
            end)
            s:SetScript("OnMouseWheel", function(self, d)
                local nv = math.min(it.max, math.max(it.min, math.floor(self:GetValue() + 0.5) + d * 5))
                self:SetValue(nv)
                r:Paint(nv)
                it.set(nv)
            end)
            r:Show()
            y = y - 52
        elseif it.t == "choice" then
            lastBtn = nil
            ci = ci + 1
            local r = ChoiceRow(pane, ci)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 18, y); r:SetPoint("TOPRIGHT", -18, y)
            r.name:SetText(it.label)
            r.hint:SetText(it.hint or "")
            local cur = ns.db.font and ns.db.font[it.slot]
            local label, file = LabelFor(it.slot, cur)
            if not (file and r.pill.fs:SetFont(file, 14, "")) then r.pill.fs:SetFont(ns.FONT, 13, "") end
            r.pill.fs:SetText(label)
            r.pill.fs:SetTextColor(C.tx[1], C.tx[2], C.tx[3])
            r.pill:SetWidth(math.max(70, r.pill.fs:GetStringWidth() + 40))
            local W_ = { now = { "바로", C.acc, C.ink }, reload = { "다시 불러오기", { 0.32, 0.25, 0.24 }, C.tx },
                         relog = { "재접속", { 0.32, 0.25, 0.24 }, C.tx } }
            local w = it.when and W_[it.when]
            if w then
                r.when.fs:SetText(w[1])
                r.when.fs:SetTextColor(w[3][1], w[3][2], w[3][3]); r.when.fs:SetShadowColor(0, 0, 0, it.when == "now" and 0 or 0.85)
                r.when.bg:SetColor(w[2], 1)
                r.when:SetWidth(r.when.fs:GetStringWidth() + 14)
                r.when:Show()
            else
                r.when:Hide()
            end
            r.pill:SetScript("OnClick", function(self)
                if dd and dd:IsShown() and dd.anchor == self then dd:Hide() return end
                OpenDropdown(self, it.slot, function(key)
                    ns:SetFontSlot(it.slot, key)
                    if it.slot == "num" then
                        Print("피해 숫자 글꼴은 재접속(캐릭터 선택 화면에 갔다 오기) 후 바뀌어요.")
                    end
                    ShowPane()
                end)
            end)
            r:Show()
            y = y - 36
        elseif it.t == "input" then
            lastBtn = nil
            local r = InputRow(pane)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 18, y - 4); r:SetPoint("TOPRIGHT", -18, y - 4)
            r.name:SetText(it.label); r.hint:SetText(it.hint or "")
            r.btn:SetLabel(it.button or "추가"); r.btn:SetHeight(24)
            local function Go()
                local text = r.box:GetText()
                if it.run(text) then r.box:SetText("") end
                r.box:ClearFocus()
                C_Timer.After(0, ShowPane)
            end
            r.btn:SetScript("OnClick", Go)
            r.box:SetScript("OnEnterPressed", Go)
            r:Show()
            y = y - 54
        elseif it.t == "toggle" then
            lastBtn = nil
            ti = ti + 1
            local r = ToggleRow(pane, ti)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 18, y); r:SetPoint("TOPRIGHT", -18, y)
            r:SetHeight(it.hint and 42 or 34)
            r.name:SetText(it.label)
            r.name:ClearAllPoints(); r.name:SetPoint("TOPLEFT", it.child and 20 or 0, -6)
            r.tv:SetShown(it.child and true or false); r.th:SetShown(it.child and true or false)
            r.hint:SetText(it.hint or ""); r.hint:SetShown(it.hint ~= nil)
            r.sw:Set(it.get() and true or false)
            local on = not (it.dep and not it.dep())
            r:SetEnabled(on); r:SetAlpha(on and 1 or 0.4)
            r:SetScript("OnClick", function(self)
                local new = not (it.get() and true or false)
                if it.set then it.set(new) elseif it.cmd then Slash(m.slash, it.cmd) end
                C_Timer.After(0, function() self.sw:Set(it.get() and true or false); ShowPane() end)
            end)
            r:Show()
            y = y - (it.hint and 42 or 34)
        else
            bi = bi + 1
            local b = PaneButton(pane, bi)
            b:SetLabel(type(it.label) == "function" and it.label() or it.label)
            b:SetScript("OnClick", function()
                if it.run then it.run() elseif it.cmd then Slash(m.slash, it.cmd) end
                C_Timer.After(0.05, function() if hub:IsShown() then ShowPane() end end)
            end)
            b:ClearAllPoints()
            if lastBtn then b:SetPoint("LEFT", lastBtn, "RIGHT", 8, 0)
            else b:SetPoint("TOPLEFT", 18, y - 8); y = y - 44 end
            lastBtn = b
            b:Show()
        end
    end
end

local function PaintPills()
    for _, p in ipairs(hub.pills) do
        local on = p.cat.key == curCat
        p.fill:SetColor(on and C.acc or { 1, 1, 1 }, on and 1 or 0.07)
        local tc = on and C.ink or C.tx
        p.fs:SetTextColor(tc[1], tc[2], tc[3]); p.fs:SetShadowColor(0, 0, 0, on and 0 or 0.85)
        local ic = on and C.ink or C.acc
        p.ic:SetVertexColor(ic[1], ic[2], ic[3], 1)
    end
end

local function PaintRail()
    PaintPills()
    local n = 0
    for i, row in ipairs(hub.rail) do
        local m = MODULES[i]
        if m.cat == curCat then
            n = n + 1
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 10, -TOP - 8 - (n - 1) * 50)
            row:Show()
        else
            row:Hide()
        end
        local on = i == sel
        row.fill:SetColor(on and C.acc or C.plate, on and 1 or 0)
        local nc = on and C.ink or C.tx
        -- 선택 배경이 분홍이라 "르엘" 분홍 글자가 묻힘 → 고른 줄은 색 코드 빼고 진한 글자
        row.name:SetText(on and m.title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or m.title)
        row.name:SetTextColor(nc[1], nc[2], nc[3])
        row.name:SetShadowColor(0, 0, 0, on and 0 or 0.85)
        local sc = on and { 0.48, 0.27, 0.32 } or { 0.62, 0.54, 0.52 }
        row.sub:SetTextColor(sc[1], sc[2], sc[3])
        row.sub:SetShadowColor(0, 0, 0, on and 0 or 0.85)
        row.disc.bg:SetVertexColor(on and 1 or C.acc[1], on and 0.89 or C.acc[2], on and 0.92 or C.acc[3], on and 1 or 0.14)
        local ic = on and C.ink or C.acc
        row.disc.ic:SetVertexColor(ic[1], ic[2], ic[3], 1)

        local exists = MExists(m)
        if m.onoff then
            row.tag:Hide(); row.sw:Show()
            row.sw:Set(m.onoff.get() and true or false, on)
        elseif m.always then
            row.sw:Hide(); row.tag:SetText(on and "|cff3a1c24항상|r" or "항상"); row.tag:Show()
        elseif not exists then
            row.sw:Hide(); row.tag:SetText("없음"); row.tag:Show()
        else
            row.tag:Hide(); row.sw:Show()
            row.sw:Set(Enabled(m.key), on)
        end
        row:SetAlpha(exists and 1 or 0.5)
    end
end

Refresh = function()
    if not hub or not hub:IsShown() then return end
    PaintRail()
    ShowPane()
    hub.moveBtn:SetLabel(ns.moving and "이동 모드 끄기" or "이동 모드")
end


----------------------------------------------------------------------
-- 르엘 소통방: 질문 · 제보 · 새 소식은 채채TV에서
----------------------------------------------------------------------
local CHANNEL  = "https://www.youtube.com/@채채TV_2"
local DOWNLOAD = "https://github.com/jubin120615-debug/LeelUI/releases/latest"
local NEWS = {
    { "1.3.5", "줍기 창이 분홍 카드로", "파티 링이 전투 중에도 시계 방향으로" },
    { "1.3.4", "르엘 가방 · 상점 토끼 · 시체 반짝 상자", "퀘스트 자동, 토끼 미니맵" },
    { "1.3.3", "르엘 허브 · 르엘 글씨체", "몹 등급 토끼 이름표" },
}
local PROBLEMS = { "오류 창이 떠요", "모양이 이상해요", "위치가 틀어져요", "기타" }

-- 르엘 애드온에서 난 마지막 오류 기억 (문제 알리기 한 줄에 넣음)
do
    local okH, orig = pcall(geterrorhandler)
    if okH and orig and seterrorhandler then
        pcall(seterrorhandler, function(msg, ...)
            if type(msg) == "string" and (msg:find("AddOns[\\/]Leel") or msg:find("AddOns[\\/]ForgLeveling")) then
                local f, l = msg:match("([%w_]+%.lua)[^%d]*(%d+)")
                ns.lastErr = f and (f .. ":" .. l) or msg:sub(1, 40)
            end
            return orig(msg, ...)
        end)
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("ADDON_ACTION_BLOCKED"); ev:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    ev:SetScript("OnEvent", function(_, _, who, what)
        if type(who) == "string" and (who:find("^Leel") or who == "ForgLeveling") then
            ns.lastErr = "차단:" .. tostring(what or "?")
        end
    end)
end

-- 읽기 전용 복사 칸: '복사'를 누르면 글자가 선택되고 Ctrl+C
local function CopyBox(parent, w)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(w, 28)
    ns.RoundRect(b, 9, { 0.08, 0.06, 0.06 }, "BACKGROUND", 0, 0)
    local e = CreateFrame("EditBox", nil, b)
    e:SetPoint("LEFT", 9, 0); e:SetPoint("RIGHT", -58, 0); e:SetHeight(20)
    e:SetAutoFocus(false)
    e:SetFontObject(ChatFontNormal)
    pcall(e.SetFont, e, ns.FONT, 11.5, "")
    e:SetTextColor(C.accHi[1], C.accHi[2], C.accHi[3])
    e:SetScript("OnTextChanged", function(self, user) if user and b.value then self:SetText(b.value); self:HighlightText() end end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    e:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0); b.tip:SetText("복사") end)
    local btn = CreateFrame("Button", nil, b)
    btn:SetSize(50, 20); btn:SetPoint("RIGHT", -4, 0)
    ns.RoundRect(btn, 10, C.acc, "ARTWORK", 0, 0)
    b.tip = ns.Font(btn, 10.5, C.ink); b.tip:SetShadowColor(0, 0, 0, 0); b.tip:SetPoint("CENTER"); b.tip:SetText("복사")
    btn:SetScript("OnClick", function() e:SetFocus(); e:HighlightText(); b.tip:SetText("Ctrl+C") end)
    function b:Set(t) self.value = t; e:SetText(t); e:SetCursorPosition(0) end
    b.edit = e
    return b
end

local talk
local function BuildTalk(f)
    local W2 = 360
    local t = CreateFrame("Frame", "LeelUI_Talk", f)
    t:SetSize(W2, 300)
    t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, FOOT + 6)
    t:SetFrameLevel(f:GetFrameLevel() + 20)
    t:EnableMouse(true)
    ns.RoundPlate(t, 16, { 0.125, 0.094, 0.086, 0.99 }, { 0.949, 0.702, 0.761, 0.9 })

    local bun = t:CreateTexture(nil, "ARTWORK")
    bun:SetTexture(ns.MEDIA .. "bag_bunny"); bun:SetSize(24, 24); bun:SetPoint("TOPLEFT", 12, -10)
    local title = ns.Font(t, 14, C.accHi); title:SetPoint("LEFT", bun, "RIGHT", 7, 0); title:SetText("르엘 소통방")
    local x = CreateFrame("Button", nil, t)
    x:SetSize(18, 18); x:SetPoint("TOPRIGHT", -10, -12)
    local xt = x:CreateTexture(nil, "ARTWORK"); xt:SetTexture(ns.MEDIA .. "hb_x"); xt:SetAllPoints()
    xt:SetVertexColor(C.tx[1], C.tx[2], C.tx[3], 0.7)
    x:SetScript("OnClick", function() t:Hide() end)

    -- 탭
    local pages, tabs = {}, {}
    local function Show(i)
        for k, pg in ipairs(pages) do pg:SetShown(k == i) end
        for k, tb in ipairs(tabs) do
            local on = k == i
            tb.bg:SetColor(on and C.acc or { 0.949, 0.702, 0.761 }, on and 1 or 0.12)
            tb.fs:SetTextColor(on and C.ink[1] or C.accHi[1], on and C.ink[2] or C.accHi[2], on and C.ink[3] or C.accHi[3])
            tb.fs:SetShadowColor(0, 0, 0, on and 0 or 0.8)
        end
        if pages[i].OnShow2 then pages[i].OnShow2() end
    end
    local tx = 12
    for i, label in ipairs({ "채채TV", "문제 알리기", "새 소식" }) do
        local b = CreateFrame("Button", nil, t)
        b:SetHeight(22)
        b.bg = ns.RoundRect(b, 11, C.acc, "BACKGROUND", 0, 0)
        b.fs = ns.Font(b, 11.5); b.fs:SetPoint("CENTER"); b.fs:SetText(label)
        b:SetWidth(b.fs:GetStringWidth() + 22)
        b:SetPoint("TOPLEFT", tx, -42)
        tx = tx + b:GetWidth() + 6
        b:SetScript("OnClick", function() Show(i) end)
        tabs[i] = b
        local pg = CreateFrame("Frame", nil, t)
        pg:SetPoint("TOPLEFT", 12, -74); pg:SetPoint("BOTTOMRIGHT", -12, 12)
        pages[i] = pg
    end

    -- 1. 채채TV
    do
        local pg = pages[1]
        local card = CreateFrame("Frame", nil, pg)
        card:SetPoint("TOPLEFT"); card:SetPoint("TOPRIGHT"); card:SetHeight(54)
        ns.RoundRect(card, 12, { 0.949, 0.702, 0.761 }, "BACKGROUND", 0, 0):SetColor({ 0.949, 0.702, 0.761 }, 0.12)
        local ic = card:CreateTexture(nil, "ARTWORK"); ic:SetTexture(ns.MEDIA .. "bag_bunny"); ic:SetSize(34, 34); ic:SetPoint("LEFT", 10, 0)
        local nm = ns.Font(card, 15, C.tx); nm:SetPoint("TOPLEFT", ic, "TOPRIGHT", 10, -2); nm:SetText("채채TV")
        local sub = ns.Font(card, 10.5, { 0.81, 0.64, 0.62 }); sub:SetPoint("TOPLEFT", nm, "BOTTOMLEFT", 0, -3)
        sub:SetText("르엘 UI 질문 · 제보 · 업데이트 소식은 여기서")
        local l1 = ns.Font(pg, 10.5, { 0.62, 0.54, 0.52 }); l1:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -10); l1:SetText("방송 (유튜브)")
        local b1 = CopyBox(pg, W2 - 24); b1:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -4); b1:Set(CHANNEL)
        local l2 = ns.Font(pg, 10.5, { 0.62, 0.54, 0.52 }); l2:SetPoint("TOPLEFT", b1, "BOTTOMLEFT", 0, -8); l2:SetText("최신 파일 받기 · GitHub (올리자마자 바로)")
        local b2 = CopyBox(pg, W2 - 24); b2:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 0, -4); b2:Set(DOWNLOAD)
        local note = ns.Font(pg, 10.5, { 0.62, 0.54, 0.52 }); note:SetPoint("TOPLEFT", b2, "BOTTOMLEFT", 0, -8)
        note:SetWidth(W2 - 24); note:SetJustifyH("LEFT")
        note:SetText("급한 수정은 GitHub에서 바로, 평소엔 CurseForge 앱 업데이트(검토 후).\n링크는 복사(Ctrl+C)해서 브라우저 주소창에 붙여 넣어요.")
    end

    -- 2. 문제 알리기
    do
        local pg = pages[2]
        local pick = 1
        local function Step(n, text, anchor, dy)
            local d = pg:CreateTexture(nil, "ARTWORK"); d:SetTexture(ns.MEDIA .. "circle"); d:SetSize(18, 18)
            d:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
            if anchor then d:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, dy) else d:SetPoint("TOPLEFT") end
            local num = pg:CreateFontString(nil, "OVERLAY"); num:SetFont(ns.NUM or ns.FONT, 12, ""); num:SetTextColor(C.ink[1], C.ink[2], C.ink[3])
            num:SetPoint("CENTER", d); num:SetText(n)
            local fs = ns.Font(pg, 12); fs:SetPoint("LEFT", d, "RIGHT", 7, 0); fs:SetText(text)
            return d
        end
        local s1 = Step(1, "어떤 문제였나요?")
        local chips, row = {}, CreateFrame("Frame", nil, pg)
        row:SetPoint("TOPLEFT", s1, "BOTTOMLEFT", 24, -6); row:SetSize(W2 - 48, 48)
        local box
        local function Line()
            local ver = Version("LeelUI")
            local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
            local t = "#르엘 " .. ver .. " · " .. PROBLEMS[pick]
            if ns.lastErr then t = t .. " · " .. ns.lastErr end
            if n > 0 then t = t .. " · 파티 " .. n .. "명" end
            return t
        end
        local function Paint()
            for i, c in ipairs(chips) do
                local on = i == pick
                c.bg:SetColor(on and { 1, 0.56, 0.64 } or { 1, 1, 1 }, on and 1 or 0.07)
                c.fs:SetTextColor(on and C.ink[1] or 0.81, on and C.ink[2] or 0.64, on and C.ink[3] or 0.62)
                c.fs:SetShadowColor(0, 0, 0, on and 0 or 0.8)
            end
            if box then box:Set(Line()) end
        end
        local cx, cy = 0, 0
        for i, label in ipairs(PROBLEMS) do
            local c = CreateFrame("Button", nil, row)
            c:SetHeight(20)
            c.bg = ns.RoundRect(c, 10, C.acc, "BACKGROUND", 0, 0)
            c.fs = ns.Font(c, 10.5); c.fs:SetPoint("CENTER"); c.fs:SetText(label)
            c:SetWidth(c.fs:GetStringWidth() + 18)
            if cx + c:GetWidth() > W2 - 48 then cx, cy = 0, cy - 24 end
            c:SetPoint("TOPLEFT", cx, cy)
            cx = cx + c:GetWidth() + 5
            c:SetScript("OnClick", function() pick = i; Paint() end)
            chips[i] = c
        end
        row:SetHeight(-cy + 22)
        local s2 = Step(2, "아래 줄을 복사해서 |cffffd6e0채채TV 방송 채팅|r에", row, -4)
        box = CopyBox(pg, W2 - 24); box:SetPoint("TOPLEFT", s2, "BOTTOMLEFT", 0, -6)
        Step(3, "화면을 찍어 두면 더 빨리 고쳐요 (|cffffd6e0PrtSc|r)", box, -10)
        pg.OnShow2 = Paint
        Paint()
    end

    -- 3. 새 소식
    do
        local pg = pages[3]
        local y = 0
        for i, n in ipairs(NEWS) do
            local v = pg:CreateFontString(nil, "OVERLAY"); v:SetFont(ns.NUM or ns.FONT, 15, ""); v:SetTextColor(C.accHi[1], C.accHi[2], C.accHi[3])
            v:SetPoint("TOPLEFT", 0, y); v:SetText(n[1])
            local a = ns.Font(pg, 12); a:SetPoint("TOPLEFT", 46, y); a:SetText(n[2])
            local b = ns.Font(pg, 10.5, { 0.62, 0.54, 0.52 }); b:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -3); b:SetText(n[3])
            if i > 1 then
                local ln = pg:CreateTexture(nil, "BORDER"); ln:SetColorTexture(0.949, 0.702, 0.761, 0.12); ln:SetHeight(1)
                ln:SetPoint("TOPLEFT", 0, y + 7); ln:SetPoint("TOPRIGHT", 0, y + 7)
            end
            y = y - 46
        end
        local note = ns.Font(pg, 10.5, { 0.62, 0.54, 0.52 }); note:SetPoint("TOPLEFT", 0, y - 2)
        note:SetText("새 버전 소식은 채채TV 방송 공지에서 먼저 알려요.")
    end

    t:SetScript("OnShow", function() Show(1) end)
    t:Hide()
    return t
end

local function Build()
    local f = CreateFrame("Frame", "LeelUI_Hub", UIParent)
    f:SetSize(W, H)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        ns.db.hub.pos = { p, rp, x, y }
    end)
    tinsert(UISpecialFrames, "LeelUI_Hub")
    ns.RoundPlate(f, 18, { 0.125, 0.094, 0.086, 0.97 }, { 0.949, 0.702, 0.761, 0.6 })

    -- 머리
    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(ns.MEDIA .. "bunny"); logo:SetSize(30, 30)
    logo:SetPoint("TOPLEFT", 16, -12)
    local title = ns.Font(f, 17)
    title:SetText("|cfff2b3c2르엘|r 허브")
    title:SetPoint("LEFT", logo, "RIGHT", 9, 0)
    local ver = ns.Num(f, 12, C.tx2, false)
    ver:SetText(Version("LeelUI") ~= "" and ("v" .. Version("LeelUI")) or "")
    ver:SetPoint("LEFT", title, "RIGHT", 8, -1)
    local slash = ns.Font(f, 11, { 0.62, 0.54, 0.52 })
    slash:SetText("/르엘")
    local close = CreateFrame("Button", nil, f)
    close:SetSize(26, 26)
    close:SetPoint("TOPRIGHT", -14, -14)
    local cbg = close:CreateTexture(nil, "ARTWORK"); cbg:SetTexture(ns.MEDIA .. "circle"); cbg:SetAllPoints()
    cbg:SetVertexColor(0.23, 0.18, 0.17, 1)
    local cx = close:CreateTexture(nil, "OVERLAY"); cx:SetTexture(ns.MEDIA .. "hb_x"); cx:SetSize(15, 15); cx:SetPoint("CENTER")
    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function() cbg:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1); cx:SetVertexColor(C.ink[1], C.ink[2], C.ink[3]) end)
    close:SetScript("OnLeave", function() cbg:SetVertexColor(0.23, 0.18, 0.17, 1); cx:SetVertexColor(1, 1, 1) end)
    slash:SetPoint("RIGHT", close, "LEFT", -10, 0)

    -- 분류 알약 줄
    f.pills = {}
    local px = 14
    for _, cat in ipairs(CATS) do
        local has = false
        for _, m in ipairs(MODULES) do if m.cat == cat.key then has = true end end
        if has then
            local p = CreateFrame("Button", nil, f)
            p:SetHeight(26)
            p.cat = cat
            p.fill = ns.RoundRect(p, 13, nil, "BACKGROUND", 2, 0)
            p.ic = p:CreateTexture(nil, "ARTWORK"); p.ic:SetTexture(ns.MEDIA .. cat.icon)
            p.ic:SetSize(14, 14); p.ic:SetPoint("LEFT", 11, 0)
            p.fs = ns.Font(p, 12); p.fs:SetText(cat.label)
            p.fs:SetPoint("LEFT", p.ic, "RIGHT", 5, 0)
            p:SetWidth(p.fs:GetStringWidth() + 42)
            p:SetPoint("TOPLEFT", px, -HEAD - 4)
            px = px + p:GetWidth() + 6
            p:SetScript("OnClick", function()
                curCat = cat.key
                if MODULES[sel].cat ~= curCat then
                    for i, m in ipairs(MODULES) do if m.cat == curCat then sel = i; break end end
                end
                Refresh()
            end)
            p:SetScript("OnEnter", function(self) if curCat ~= cat.key then self.fill:SetColor({ 1, 1, 1 }, 0.14) end end)
            p:SetScript("OnLeave", function() PaintPills() end)
            f.pills[#f.pills + 1] = p
        end
    end

    local function HLine(y)
        local t = f:CreateTexture(nil, "BORDER")
        t:SetColorTexture(0.949, 0.702, 0.761, 0.15); t:SetHeight(1)
        t:SetPoint("TOPLEFT", 1, y); t:SetPoint("TOPRIGHT", -1, y)
    end
    HLine(-TOP)
    local foot = f:CreateTexture(nil, "BORDER")
    foot:SetColorTexture(0.949, 0.702, 0.761, 0.15); foot:SetHeight(1)
    foot:SetPoint("BOTTOMLEFT", 1, FOOT); foot:SetPoint("BOTTOMRIGHT", -1, FOOT)
    local vline = f:CreateTexture(nil, "BORDER")
    vline:SetColorTexture(0.949, 0.702, 0.761, 0.12); vline:SetWidth(1)
    vline:SetPoint("TOPLEFT", RAIL, -TOP); vline:SetPoint("BOTTOMLEFT", RAIL, FOOT)

    -- 왼쪽 목록
    f.rail = {}
    for i, m in ipairs(MODULES) do
        local row = CreateFrame("Button", nil, f)
        row:SetSize(RAIL - 20, 46)
        row.fill = ns.RoundRect(row, 14, C.plate, "BACKGROUND", 2, 0)
        row.disc = IconDisc(row, 30, m.icon)
        row.disc:SetPoint("LEFT", 8, 0)
        row.name = ns.Font(row, 13); row.name:SetText(m.title)
        row.name:SetPoint("TOPLEFT", row.disc, "TOPRIGHT", 10, 1)
        row.sub = ns.Font(row, 10.5); row.sub:SetText(m.sub)
        row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
        row.sw = Switch(row); row.sw:SetPoint("RIGHT", -8, 0)
        row.tag = ns.Font(row, 11, C.tx2); row.tag:SetPoint("RIGHT", -10, 0)

        -- 스위치 누르면 애드온 켜기/끄기 (다시 불러오기 안내)
        local hit = CreateFrame("Button", nil, row)
        hit:SetAllPoints(row.sw)
        hit:SetScript("OnClick", function()
            if m.onoff then
                m.onoff.set(not m.onoff.get())
                sel = i
                Refresh()
                if m.onoff.reload then StaticPopup_Show("LEELUI_HUB_RELOAD") end
                return
            end
            if m.always or not Exists(m.key) then return end
            SetEnabled(m.key, not Enabled(m.key))
            sel = i
            Refresh()
            StaticPopup_Show("LEELUI_HUB_RELOAD")
        end)
        row:SetScript("OnClick", function() sel = i; Refresh() end)
        row:SetScript("OnEnter", function(self) if sel ~= i then self.fill:SetColor({ 1, 1, 1 }, 0.05) end end)
        row:SetScript("OnLeave", function() PaintRail() end)
        f.rail[i] = row
    end

    f.pane = BuildPane(f)

    -- 아래 줄
    local hint = ns.Font(f, 11.5, { 0.81, 0.64, 0.62 })
    hint:SetText("질문 · 제보 · 새 소식은 |cffffd6e0채채TV|r에서")
    hint:SetPoint("BOTTOMLEFT", 18, 19)
    f.talkBtn = ns.MakeButton(f, "소통하러 가기", true, function()
        talk = talk or BuildTalk(f)
        talk:SetShown(not talk:IsShown())
    end, 104)
    f.talkBtn:SetHeight(26)
    f.talkBtn:SetPoint("LEFT", hint, "RIGHT", 10, 0)
    f.moveBtn = ns.MakeButton(f, "이동 모드", true, function() ns:ToggleMoveMode(); Refresh() end, 96)
    f.moveBtn:SetPoint("BOTTOMRIGHT", -14, 11)

    f:SetScript("OnShow", function(self)
        local p = ns.db.hub.pos
        if p then self:ClearAllPoints(); self:SetPoint(p[1], UIParent, p[2], p[3], p[4]) end
        Refresh()
    end)
    f:Hide()
    return f
end

----------------------------------------------------------------------
-- 바깥에서 부르는 것
----------------------------------------------------------------------
function ns:ToggleHub(key)
    ns.db.hub = ns.db.hub or {}
    hub = hub or Build()
    if key then
        for i, m in ipairs(MODULES) do if m.key == key then sel = i; curCat = m.cat end end
        hub:Show(); Refresh()
        return
    end
    hub:SetShown(not hub:IsShown())
end

function ns:RefreshHub() Refresh() end

-- 미니맵 아이콘 정리: 길잡이 버튼 숨김 (토끼 하나만)
function ns:ApplyHubTidy()
    ns.db.hub = ns.db.hub or {}
    local b = _G.ForgLevelingMinimapButton
    if not b then return end
    if ns.db.hub.tidy then
        b:Hide()
        if not b.leelHooked then
            b.leelHooked = true
            hooksecurefunc(b, "Show", function(self) if ns.db.hub.tidy then self:Hide() end end)
        end
    elseif not (ForgLevelingDB and ForgLevelingDB.minimapHide) then
        b:Show()
    end
end

-- 이동 모드가 바뀌면 허브 단추 글자도
if hooksecurefunc then
    C_Timer.After(0, function()
        if ns.SetMoveMode then hooksecurefunc(ns, "SetMoveMode", function() Refresh() end) end
    end)
end

-- /르엘
SLASH_LEELHUB1 = "/르엘"
SLASH_LEELHUB2 = "/leelhub"
SlashCmdList.LEELHUB = function() ns:ToggleHub() end

-- 접속 후 아이콘 정리 적용 (길잡이 버튼이 만들어진 다음)
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    C_Timer.After(1, function()
        if ns.db then ns.db.hub = ns.db.hub or {}; ns:ApplyHubTidy() end
    end)
end)
