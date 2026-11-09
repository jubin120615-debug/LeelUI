-- LeelUI / Hub.lua
-- 르엘 허브: 르엘 애드온 전부를 한 창에서 켜고 끄고 설정 (미니맵 토끼 / /르엘)

local _, ns = ...
local C = ns.C

local W, H = 580, 460
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
    text = "|cfff2b3c2르엘 허브|r\n애드온을 켜고 끈 건 다시 불러와야 적용돼요.\n지금 다시 불러올까요?",
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

local MODULES = {
    {
        key = "LeelUI", title = "|cfff2b3c2르엘|r UI", sub = "유닛, 이름표, 파티", icon = "hb_ui",
        always = true,
        desc = "르엘 UI 본체. 허브도 여기에 들어 있어요.",
        items = {
            { t = "toggle", label = "미니맵 아이콘 정리", hint = "길잡이 버튼은 숨기고 토끼 하나만",
              get = function() return ns.db.hub.tidy end,
              set = function(v) ns.db.hub.tidy = v; ns:ApplyHubTidy() end },
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
    if pane.input then pane.input:Hide() end
    if dd then dd:Hide() end
    for _, b in ipairs(pane.btns) do b:Hide() end
    pane.note:SetText("")
end

local function ToggleRow(pane, i)
    local r = pane.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, pane)
    r:SetHeight(36)
    r.name = ns.Font(r, 13); r.name:SetPoint("TOPLEFT", 0, -6)
    r.hint = ns.Font(r, 10.5, { 0.62, 0.54, 0.52 }); r.hint:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
    r.sw = Switch(r); r.sw:SetPoint("RIGHT", 0, 0)
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
    pane.ver:SetText(MVersion(m) ~= "" and ("v" .. MVersion(m)) or "")
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

    local y, ti, bi, ci = -66, 0, 0, 0
    local lastBtn
    for _, it in ipairs(m.items) do
        if it.t == "choice" then
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
            r.hint:SetText(it.hint or ""); r.hint:SetShown(it.hint ~= nil)
            r.sw:Set(it.get() and true or false)
            r:SetScript("OnClick", function(self)
                local new = not (it.get() and true or false)
                if it.set then it.set(new) elseif it.cmd then Slash(m.slash, it.cmd) end
                C_Timer.After(0, function() self.sw:Set(it.get() and true or false) end)
            end)
            r:Show()
            y = y - (it.hint and 42 or 34)
        else
            bi = bi + 1
            local b = PaneButton(pane, bi)
            b:SetLabel(it.label)
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
        if m.always then
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
    local hint = ns.Font(f, 11, { 0.62, 0.54, 0.52 })
    hint:SetText("스위치 = 애드온 켜기/끄기 (다시 불러오기 필요)")
    hint:SetPoint("BOTTOMLEFT", 18, 19)
    f.moveBtn = ns.MakeButton(f, "이동 모드", true, function() ns:ToggleMoveMode(); Refresh() end, 96)
    f.moveBtn:SetPoint("BOTTOMRIGHT", -14, 11)
    local cfg = ns.MakeButton(f, "르엘 UI 상세 설정", false, function() ns:ToggleConfig() end)
    cfg:SetPoint("RIGHT", f.moveBtn, "LEFT", -8, 0)

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
