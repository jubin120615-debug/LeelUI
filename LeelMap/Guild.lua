-- Leel Map / Guild.lua
-- 길드원 위치: 르엘 UI를 쓰는 길드원끼리 몇 초마다 위치를 주고받아서
-- 세계 지도 · 미니맵에 직업 색 토끼 점으로, 세계 지도 왼쪽 위에 길드원 목록으로 보여줘요.
--   게임은 길드원 위치를 알려주지 않아서, 애드온끼리 길드 채널로 신호를 주고받아요 (채팅창엔 안 보여요)
--   허브 > Leel Map 에서 "내 위치 길드에 알리기" 를 끄면 내 위치는 보내지 않아요

local PREFIX = "LeelPos"
local LM = "Interface\\AddOns\\LeelUI\\media\\"
local FONT = STANDARD_TEXT_FONT or "Fonts\\2002.TTF"
local NUM = "Interface\\AddOns\\LeelMap\\media\\BarlowCondensed-ExtraBoldItalic.ttf"
local C = {
    acc = { 0.949, 0.702, 0.761 }, accHi = { 1.00, 0.84, 0.88 }, ink = { 0.227, 0.11, 0.141 },
    tx = { 0.965, 0.925, 0.91 }, tx2 = { 0.81, 0.635, 0.616 },
}
local SEND_EVERY, EXPIRE = 2, 45     -- 움직일 땐 2초마다 (점이 덜 늦게 따라와요)

local members = {}     -- 이름 → { map, x, y, lvl, cls, t }
-- 이번 접속만 쓰는 내 표시: 내가 보낸 신호가 돌아오면 이걸로 알아봐요 (이름 · 서버 표기와 상관없이)
local MYTAG = tostring(math.random(100000, 999999))

local function DB()
    LeelMapDB = LeelMapDB or {}
    local d = LeelMapDB
    if d.gShare == nil then d.gShare = true end
    if d.gShow == nil then d.gShow = true end
    if d.gHideInst == nil then d.gHideInst = true end
    return d
end

local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cfff2b3c2[Leel Map]|r " .. msg) end

local function Font(parent, size, color, file)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local L = _G.LeelUI
    fs:SetFont(file or (L and L.FONT) or FONT, size, "")
    fs:SetShadowColor(0, 0, 0, 0.9); fs:SetShadowOffset(1, -1)
    color = color or C.tx
    fs:SetTextColor(color[1], color[2], color[3])
    return fs
end

local function ClassColor(cls)
    local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    if c then return c.r, c.g, c.b end
    return C.acc[1], C.acc[2], C.acc[3]
end

local function MapName(m)
    local ok, info = pcall(C_Map.GetMapInfo, m)
    return ok and info and info.name or "?"
end

----------------------------------------------------------------------
-- 좌표 바꾸기 (지도 0~1 ↔ 세계 좌표)
----------------------------------------------------------------------
local function WorldPos(m, x, y)
    if not (m and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
    local ok, cont, v = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x, y))
    if ok and v then return cont, v.x, v.y end     -- x = 북, y = 서
end
-- src 지도의 (x, y)를 dst 지도 좌표로 (같은 대륙일 때만)
local function ToMap(src, x, y, dst)
    if src == dst then return x, y end
    local c1, wx, wy = WorldPos(src, x, y)
    local c0, ax, ay = WorldPos(dst, 0, 0)
    local _, bx, by = WorldPos(dst, 1, 1)
    if not (c1 and c0 and bx) or c1 ~= c0 then return end
    local dy, dx = by - ay, bx - ax
    if math.abs(dy) < 1e-6 or math.abs(dx) < 1e-6 then return end
    return (wy - ay) / dy, (wx - ax) / dx
end

-- OpenMap 이어 붙인 지도가 보이는 중이면 그림판 위 자리 (nil = OpenMap 아님, false = 못 놓음)
local function OMCanvas(m, x, y)
    local OM = _G.OpenMapAPI
    if not (OM and OM.major == 1 and (OM.version or 0) >= 2 and OM.IsStitched and OM.IsStitched()) then return end
    local cont, wx, wy = WorldPos(m, x, y)
    if not cont then return false end
    local ok, cx, cy = pcall(OM.CanvasFromWorldPos, cont, wx, wy)
    if ok and cx then return cx, cy end
    return false
end

local function MyPos()
    if not (C_Map and C_Map.GetBestMapForUnit) then return end
    local m = C_Map.GetBestMapForUnit("player")
    if not m then return end
    local ok, p = pcall(C_Map.GetPlayerMapPosition, m, "player")
    if not (ok and p) then return end
    local x, y = p:GetXY()
    if not x or (x == 0 and y == 0) then return end
    return m, x, y
end

-- 나와의 거리 (야드), 같은 대륙이 아니면 nil
local function Dist(e)
    local m, x, y = MyPos()
    if not m then return end
    local c1, ax, ay = WorldPos(m, x, y)
    local c2, bx, by = WorldPos(e.map, e.x, e.y)
    if not (c1 and c2) or c1 ~= c2 then return end
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end
local function DistText(d)
    if not d then return "" end
    if d >= 1000 then return ("%.1fk"):format(d / 1000) end
    return ("%dm"):format(d)
end

local function Live()
    local now, out = GetTime(), {}
    for name, e in pairs(members) do
        if now - e.t > EXPIRE then members[name] = nil else e.name = name; out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

----------------------------------------------------------------------
-- 보내기 · 받기
----------------------------------------------------------------------
local last = { msg = nil, t = 0 }
local function Send(force)
    if not (IsInGuild and IsInGuild()) or not C_ChatInfo then return end
    local d = DB()
    local msg
    if not d.gShare or (d.gHideInst and IsInInstance and IsInInstance()) then
        msg = "0;" .. MYTAG
    else
        local m, x, y = MyPos()
        if m then
            local _, cls = UnitClass("player")
            msg = ("1;%d;%d;%d;%d;%s;%s"):format(m, math.floor(x * 10000), math.floor(y * 10000), UnitLevel("player") or 0, cls or "", MYTAG)
        else
            msg = "0;" .. MYTAG
        end
    end
    -- 같은 내용은 30초에 한 번만 (가만히 있을 때 덜 보내요), "0"(숨김)은 바뀔 때 한 번만
    if not force then
        if msg == last.msg and (msg:sub(1, 1) == "0" or GetTime() - last.t < 30) then return end
    end
    last.msg, last.t = msg, GetTime()
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "GUILD")
end

local function OnAddonMsg(prefix, msg, channel, sender)
    if prefix ~= PREFIX or channel ~= "GUILD" or type(msg) ~= "string" then return end
    local name = Ambiguate and Ambiguate(sender, "none") or sender
    -- 내가 보낸 신호는 무시 (서버 이름이 붙어 와도 "이름-서버" 앞부분으로 비교)
    local me = UnitName("player")
    if type(name) == "string" and me then
        local base = name:match("^([^%-%s@]+)")       -- "이름-서버", "이름 서버" 모두
        if name == me or base == me or name:find(me, 1, true) == 1 then return end
    end
    if msg == "?" then
        C_Timer.After(0.5 + math.random() * 3, function() Send(true) end)
        return
    end
    last.raw = last.raw or {}
    last.raw[name] = msg
    -- 구분자는 ";" (예전 버전 "|" 도 읽어요)
    local v, m, x, y, l, c, tag = strsplit(msg:find(";", 1, true) and ";" or "|", msg)
    if v == "0" then
        if m == MYTAG then return end
        members[name] = nil; return
    end
    if v ~= "1" or tag == MYTAG then return end
    m, x, y = tonumber(m), tonumber(x), tonumber(y)
    if not (m and x and y) then return end
    members[name] = { map = m, x = x / 10000, y = y / 10000, lvl = tonumber(l) or 0, cls = c ~= "" and c or nil, t = GetTime() }
end

----------------------------------------------------------------------
-- 토끼 점 (세계 지도 · 미니맵 공용)
----------------------------------------------------------------------
local function MakePin(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local o = b:CreateTexture(nil, "BACKGROUND"); o:SetTexture(LM .. "circle"); o:SetPoint("TOPLEFT", -2, 2); o:SetPoint("BOTTOMRIGHT", 2, -2); o:SetVertexColor(0, 0, 0, 0.9)
    b.disc = b:CreateTexture(nil, "BORDER"); b.disc:SetTexture(LM .. "circle"); b.disc:SetAllPoints()
    b.bun = b:CreateTexture(nil, "ARTWORK"); b.bun:SetTexture(LM .. "bunny"); b.bun:SetPoint("TOPLEFT", 1, -1); b.bun:SetPoint("BOTTOMRIGHT", -1, 1)
    b:SetScript("OnEnter", function(self)
        local e = self.e
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local r, g, bl = ClassColor(e.cls)
        GameTooltip:SetText(e.name, r, g, bl)
        local cname = e.cls and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[e.cls] or ""
        GameTooltip:AddLine(("레벨 %d %s"):format(e.lvl or 0, cname), 1, 1, 1)
        local d = Dist(e)
        GameTooltip:AddLine(MapName(e.map) .. (d and ("  ·  " .. DistText(d)) or ""), C.accHi[1], C.accHi[2], C.accHi[3])
        GameTooltip:AddLine("클릭: 귓말 · 오른쪽 클릭: 길 안내 핀", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self, btn)
        local e = self.e
        if not e then return end
        if btn == "RightButton" then
            local ok = pcall(function()
                C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(e.map, e.x, e.y))
                if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
            end)
            Print(ok and (e.name .. " 쪽에 길 안내 핀을 찍었어요") or "이 지도에는 핀을 찍을 수 없어요")
        elseif ChatFrame_SendTell then
            ChatFrame_SendTell(e.name)
        end
    end)
    return b
end
local function Paint(pin, e)
    pin.e = e
    local r, g, b = ClassColor(e.cls)
    pin.disc:SetVertexColor(r, g, b, 1)
end

----------------------------------------------------------------------
-- 세계 지도: 토끼 점 + 이름
----------------------------------------------------------------------
local wm = {}
local function WorldMapPaint()
    local W = _G.WorldMapFrame
    if not (W and W:IsShown() and W.ScrollContainer and W.ScrollContainer.Child) then return end
    local canvas = W.ScrollContainer.Child
    if not wm.layer then
        wm.layer = CreateFrame("Frame", nil, canvas)
        wm.layer:SetAllPoints(canvas)
        wm.anchors, wm.pins = {}, {}
    end
    wm.layer:SetFrameLevel(math.min(canvas:GetFrameLevel() + 6100, 9100))
    local list = DB().gShow and Live() or {}
    local m = W.GetMapID and W:GetMapID()
    local cw, ch = canvas:GetWidth(), canvas:GetHeight()
    local s = canvas:GetScale() or 1
    local n = 0
    if m and cw and cw > 0 then
        for _, e in ipairs(list) do
            local x, y = OMCanvas(e.map, e.x, e.y)
            local stitched = x ~= nil
            if not stitched then x, y = ToMap(e.map, e.x, e.y, m) end
            if x and (stitched or (x >= 0 and x <= 1 and y >= 0 and y <= 1)) then
                n = n + 1
                local a = wm.anchors[n]
                if not a then
                    a = CreateFrame("Frame", nil, wm.layer); a:SetSize(1, 1)
                    local pin = MakePin(a, 20)
                    pin:SetPoint("CENTER", a, "CENTER", 0, 0)
                    pin.name = Font(pin, 12, C.tx); pin.name:SetPoint("LEFT", pin, "RIGHT", 4, 0)
                    wm.anchors[n], wm.pins[n] = a, pin
                end
                local pin = wm.pins[n]
                a:ClearAllPoints(); a:SetPoint("CENTER", wm.layer, "TOPLEFT", x * cw, -y * ch)
                pin:SetScale(1 / s)       -- 확대해도 점 크기는 그대로
                Paint(pin, e)
                local r, g, b = ClassColor(e.cls)
                pin.name:SetText(e.name); pin.name:SetTextColor(r, g, b)
                pin:SetFrameLevel(wm.layer:GetFrameLevel() + 2)
                a:Show()
            end
        end
    end
    for i = n + 1, #(wm.anchors or {}) do wm.anchors[i]:Hide() end
end

----------------------------------------------------------------------
-- 세계 지도 왼쪽 위: "길드원 N" 알약 + 펼치는 목록
----------------------------------------------------------------------
local panel
local function PanelPaint()
    if not panel then return end
    local list = Live()
    local show = DB().gShow and #list > 0
    panel.pill:SetShown(show)
    if not show then panel.list:Hide() return end
    panel.pill.fs:SetText("길드원 " .. #list)
    panel.pill:SetWidth(panel.pill.fs:GetStringWidth() + 40)
    if not panel.list:IsShown() then return end
    local rows = panel.rows
    for i, e in ipairs(list) do
        local r = rows[i]
        if not r then
            r = CreateFrame("Button", nil, panel.list); r:SetHeight(22)
            r.hl = r:CreateTexture(nil, "BACKGROUND"); r.hl:SetAllPoints(); r.hl:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.15); r.hl:Hide()
            r.dot = r:CreateTexture(nil, "ARTWORK"); r.dot:SetTexture(LM .. "circle"); r.dot:SetSize(10, 10); r.dot:SetPoint("LEFT", 8, 0)
            r.nm = Font(r, 12.5); r.nm:SetPoint("LEFT", r.dot, "RIGHT", 6, 0)
            r.z = Font(r, 11, C.tx2); r.z:SetPoint("LEFT", r.nm, "RIGHT", 6, 0); r.z:SetWidth(120); r.z:SetJustifyH("LEFT"); r.z:SetWordWrap(false)
            r.d = Font(r, 13, C.accHi, NUM); r.d:SetPoint("RIGHT", -8, 0)
            r:SetScript("OnEnter", function(self) self.hl:Show() end)
            r:SetScript("OnLeave", function(self) self.hl:Hide() end)
            r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            r:SetScript("OnClick", function(self, btn)
                if not self.e then return end
                if btn == "RightButton" and ChatFrame_SendTell then ChatFrame_SendTell(self.e.name)
                elseif _G.WorldMapFrame and WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, self.e.map) end
            end)
            rows[i] = r
        end
        r.e = e
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", panel.list, "TOPLEFT", 4, -6 - (i - 1) * 23); r:SetPoint("RIGHT", panel.list, "RIGHT", -4, 0)
        local cr, cg, cb = ClassColor(e.cls)
        r.dot:SetVertexColor(cr, cg, cb, 1)
        r.nm:SetText(e.name); r.nm:SetTextColor(cr, cg, cb)
        r.z:SetText(("%d · %s"):format(e.lvl or 0, MapName(e.map)))
        local d = Dist(e)
        r.d:SetText(DistText(d))
        r:SetAlpha(d and 1 or 0.55)        -- 다른 대륙은 흐리게
        r:Show()
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    panel.list:SetHeight(12 + #list * 23)
end

local function MakePanel()
    local W = _G.WorldMapFrame
    if panel or not (W and W.ScrollContainer) then return end
    panel = {}
    local pill = CreateFrame("Button", nil, W.ScrollContainer)
    pill:SetSize(90, 24); pill:SetPoint("TOPLEFT", W.ScrollContainer, "TOPLEFT", 52, -12)   -- 왼쪽 위 동그란 지도 단추들 옆
    pill:SetFrameLevel(W.ScrollContainer:GetFrameLevel() + 50)
    local bg = pill:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(LM .. "pill32"); bg:SetAllPoints(); bg:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
    local ic = pill:CreateTexture(nil, "ARTWORK"); ic:SetTexture(LM .. "bunny"); ic:SetSize(18, 18); ic:SetPoint("LEFT", 5, 0)
    pill.fs = Font(pill, 12.5, C.ink); pill.fs:SetPoint("LEFT", ic, "RIGHT", 4, 0); pill.fs:SetShadowColor(0, 0, 0, 0)
    local list = CreateFrame("Frame", nil, pill)
    list:SetPoint("TOPLEFT", pill, "BOTTOMLEFT", 0, -6); list:SetWidth(260)
    local lb = list:CreateTexture(nil, "BACKGROUND"); lb:SetAllPoints(); lb:SetColorTexture(0.125, 0.094, 0.086, 0.95)
    local edge = list:CreateTexture(nil, "BORDER"); edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(2); edge:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.9)
    list:EnableMouse(true)
    list:Hide()
    pill:SetScript("OnClick", function() list:SetShown(not list:IsShown()); PanelPaint() end)
    pill:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT"); GameTooltip:SetText("르엘 UI 쓰는 길드원")
        GameTooltip:AddLine("누르면 목록 · 목록에서 클릭하면 그 지역 지도로, 오른쪽 클릭은 귓말", 0.85, 0.85, 0.85, true); GameTooltip:Show()
    end)
    pill:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.pill, panel.list, panel.rows = pill, list, {}
    pill:Hide()
end

----------------------------------------------------------------------
-- 미니맵: 가까운 길드원은 안에, 멀면 테두리에 붙어서 방향만
----------------------------------------------------------------------
local MM_OUT = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
local MM_IN  = { [0] = 300, 240, 180, 120, 80, 50 }
local mm = { pins = {} }
local function MinimapPaint()
    local M = _G.Minimap
    if not M then return end
    if not mm.layer then
        mm.layer = CreateFrame("Frame", nil, M); mm.layer:SetAllPoints(M)
    end
    mm.layer:SetFrameLevel(M:GetFrameLevel() + 6)
    local n = 0
    local m, px, py = MyPos()
    if m and DB().gShow then
        local c0, pn, pw = WorldPos(m, px, py)
        local zoom = M:GetZoom() or 0
        local diam = ((IsIndoors and IsIndoors()) and MM_IN or MM_OUT)[zoom] or 300
        local R = M:GetWidth() / 2
        local k = R * 2 / diam
        local rot = GetCVar and GetCVar("rotateMinimap") == "1"
        local f = rot and GetPlayerFacing and GetPlayerFacing() or 0
        local cs, sn = math.cos(f), math.sin(f)
        for _, e in ipairs(Live()) do
            local c1, en, ew = WorldPos(e.map, e.x, e.y)
            if c1 and c0 and c1 == c0 then
                local east, north = -(ew - pw), (en - pn)
                if rot then east, north = east * cs + north * sn, -east * sn + north * cs end
                local sx, sy = east * k, north * k
                local len = math.sqrt(sx * sx + sy * sy)
                local edge = len > R - 8
                if edge and len > 0 then sx, sy = sx / len * (R - 8), sy / len * (R - 8) end
                n = n + 1
                local pin = mm.pins[n]
                if not pin then pin = MakePin(mm.layer, 14); mm.pins[n] = pin end
                Paint(pin, e)
                pin:ClearAllPoints(); pin:SetPoint("CENTER", mm.layer, "CENTER", sx, sy)
                pin:SetAlpha(edge and 0.6 or 1)
                pin:SetFrameLevel(mm.layer:GetFrameLevel() + 1)
                pin:Show()
            end
        end
    end
    for i = n + 1, #mm.pins do mm.pins[i]:Hide() end
end

----------------------------------------------------------------------
-- 이벤트 · 시계
----------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_GUILD_UPDATE")
f:SetScript("OnEvent", function(_, e, ...)
    if e == "CHAT_MSG_ADDON" then OnAddonMsg(...) return end
    if e == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
        DB()
        if not LeelMapDB.gToldShare then
            LeelMapDB.gToldShare = true
            C_Timer.After(8, function()
                if IsInGuild and IsInGuild() then
                    Print("르엘 UI를 쓰는 길드원끼리 지도에서 서로 위치가 보여요. 끄려면 허브 > Leel Map > \"내 위치 길드에 알리기\"")
                end
            end)
        end
        -- 접속하면 다른 길드원에게 "위치 알려줘" 한 번 + 내 위치
        C_Timer.After(5, function()
            if IsInGuild and IsInGuild() and C_ChatInfo then pcall(C_ChatInfo.SendAddonMessage, PREFIX, "?", "GUILD") end
            Send(true)
        end)
        C_Timer.NewTicker(SEND_EVERY, function() Send(false) end)
        local acc = 0
        f:SetScript("OnUpdate", function(_, el)
            acc = acc + el
            if acc < 0.5 then return end
            acc = 0
            if _G.WorldMapFrame and WorldMapFrame:IsShown() then
                MakePanel(); WorldMapPaint(); PanelPaint()
            end
            MinimapPaint()
        end)
        return
    end
    if e == "PLAYER_ENTERING_WORLD" then C_Timer.After(2, function() Send(true) end) end
end)

-- 허브 · 명령어에서 씀
_G.LeelMapGuild = {
    Send = function() Send(true) end,
    Count = function() return #Live() end,
    Members = function() return Live() end,   -- 큰 지도용: { name, map, x, y, lvl, cls }
    ClassColor = function(cls) return ClassColor(cls) end,
    -- 혼자 확인용: 내 옆에 가짜 길드원 토끼를 40초 동안 세워요
    Test = function()
        local m, x, y = MyPos()
        if not m then Print("지금은 내 위치를 알 수 없어요") return end
        local _, cls = UnitClass("player")
        members["토끼친구(시험)"] = { map = m, x = x + 0.03, y = y - 0.02, lvl = UnitLevel("player"), cls = "PRIEST", t = GetTime() }
        Print("내 오른쪽 위에 시험용 토끼를 세웠어요. 지도와 미니맵을 열어 보세요 (40초 뒤 사라져요)")
    end,
    List = function()
        local list = Live()
        if #list == 0 then Print("지금 위치가 보이는 길드원이 없어요 (르엘 UI를 쓰는 길드원만 보여요)") return end
        for _, e in ipairs(list) do
            Print(("%s  Lv %d  %s  %s"):format(e.name, e.lvl or 0, MapName(e.map), DistText(Dist(e))))
            local raw = last.raw and last.raw[e.name]
            if raw then Print("  받은 신호: " .. raw:gsub("|", "||") .. "  (내 표시 " .. MYTAG .. ", 내 이름 " .. tostring(UnitName("player")) .. ")") end
        end
    end,
}
