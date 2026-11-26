-- LeelUI / Stash.lua
-- 창고 부캐 자동 보내기
--   ① 허브: 창고 캐릭 · 보낼 종류(천 · 광석 · 약초 …) · 템별 규칙 (늘 보내기 / 안 보내기 / N개 남기기)
--   ② 르엘 가방: 보낼 템 칸 구석에 봉투 · 가방 머리에 "루루에게 N칸" · 템 휠클릭 = 규칙 메뉴
--   ③ 우편함: 옆 판에 보낼 목록 · 단추 하나로 받는 사람 + 제목 + 12칸 채우기 (보내기는 게임 단추로 내가)
--   ④ 창고 캐릭: 우편함 "창고 우편 모두 받기" · "판매금 받기" · 은행 열면 "재료 은행에 넣기"
--   + 모든 캐릭 가방 · 은행 개수를 적어 두고 툴팁에 "창고 루루: 240 · 방패곰: 6"
-- 와우는 다른 캐릭 정보를 직접 못 읽어서, 캐릭마다 접속할 때 · 은행을 열 때 적어 둬요 (같은 계정 · 서버 + 진영별)

local _, ns = ...
local C = ns.C
local CC = C_Container or {}
local GetInfo = CC.GetContainerItemInfo
local NumSlots = CC.GetContainerNumSlots or _G.GetContainerNumSlots
local Pickup = CC.PickupContainerItem or _G.PickupContainerItem
local Split = CC.SplitContainerItem or _G.SplitContainerItem
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
-- 가방 끝 번호: 새 게임 판은 재료 가방(5번)이 따로 있어요 → 재료는 거기 들어가요
local BAG_LAST = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or (NUM_BAG_SLOTS or 4)
if BAG_LAST < (NUM_BAG_SLOTS or 4) then BAG_LAST = NUM_BAG_SLOTS or 4 end
local BANK_FIRST = (Enum and Enum.BagIndex and Enum.BagIndex.BankBag_1) or ((NUM_BAG_SLOTS or 4) + 1)
local SUBJ = "르엘 창고"
local ATT = _G.ATTACHMENTS_MAX_SEND or 12

local function P(m) print("|cfff2b3c2[르엘 창고]|r " .. ns.L(m)) end
-- 내 이름: 이 서버는 캐릭 이름이 "슈엘 유일"처럼 이름 + 뒷이름이고, UnitName 은 앞 이름("슈엘")만 줘요
--   → 뒷이름까지 붙여 "슈엘-유일"로 구분해요 (같은 앞 이름 캐릭이 서로 덮어쓰지 않게 · 우편 받는 사람도 이 꼴)
local meC
local function Me()
    if meC then return meC end
    local n, r = UnitFullName("player")
    if not n or n == "" then return UnitName("player") end
    if r and r ~= "" and not (issecretvalue and issecretvalue(r)) then meC = n .. "-" .. r; return meC end
    return n
end
ns.StashMe = Me
-- 보이는 이름: "슈엘-유일" → "슈엘 유일"
local function Pretty(n) return (tostring(n or ""):gsub("%-", " ")) end
ns.StashPretty = Pretty
local function RF() return (GetRealmName() or "?") .. "-" .. (UnitFactionGroup("player") or "?") end

-- 설정 (서버 · 진영마다)
local CAT_DEF = { cloth = true, metal = true, herb = true, leather = true, green = true }
function ns.StashDB()
    ns.db.stash = ns.db.stash or {}
    local k = RF()
    local s = ns.db.stash[k]
    if not s then
        s = {}; ns.db.stash[k] = s
    end
    if s.on == nil then s.on = false end
    s.cats = s.cats or {}
    for c, v in pairs(CAT_DEF) do if s.cats[c] == nil then s.cats[c] = v end end
    s.always = s.always or {}; s.never = s.never or {}; s.keep = s.keep or {}
    if s.tip == nil then s.tip = true end
    return s
end
local DB = ns.StashDB
-- 모든 캐릭 가방 · 은행 개수
local function Alts()
    ns.db.alts = ns.db.alts or {}
    local k = RF()
    ns.db.alts[k] = ns.db.alts[k] or {}
    return ns.db.alts[k]
end
ns.StashAlts = Alts
ns.StashRecord = function() end   -- 아래에서 채워요 (준비 화면이 불러요)
local function IsTarget() local s = DB(); return s.target and s.target == Me() end
local function Active() local s = DB(); return s.on and s.target and s.target ~= "" and s.target ~= Me() end

----------------------------------------------------------------------
-- 이 칸을 보낼까?
----------------------------------------------------------------------
-- 종류: 직업 재료(7)의 세부 · 보석(3) · 장비 녹색
local function CatOf(id, quality)
    if not (id and GetItemInfoInstant) then return end
    local ok, _, _, _, loc, _, classID, subID = pcall(GetItemInfoInstant, id)
    if not ok then return end
    if classID == 7 then
        if subID == 5 then return "cloth" elseif subID == 7 then return "metal" elseif subID == 9 then return "herb"
        elseif subID == 6 then return "leather" elseif subID == 8 then return "cook" elseif subID == 4 then return "gem"
        elseif subID == 12 then return "ench" elseif subID == 10 then return "elem" end
        return "elem"   -- 그 밖의 직업 재료 (진주 · 실 · 염료 …) = "원소 · 기타 직업 재료"
    elseif classID == 3 then return "gem"
    elseif (classID == 2 or classID == 4) and quality == 2 and loc and loc ~= "" and loc ~= "INVTYPE_NON_EQUIP_IGNORE" then return "green"
    end
    if quality == 0 then return "grey" end
end
ns.StashCatOf = CatOf
local function Wanted(info)
    if not info or not info.itemID or info.isBound then return false end
    local s = DB()
    local id = info.itemID
    if s.never[id] then return false end
    if s.always[id] then return true end
    local ok, _, _, _, _, _, classID = pcall(GetItemInfoInstant, id)
    if ok and classID == 12 then return false end   -- 퀘스트 템
    local c = CatOf(id, info.quality)
    return c and s.cats[c] and true or false
end

-- 가방 전체에서 보낼 것: { {bag, slot, id, n, split}, ... } (남기기 개수만큼 빼고)
local skipNow = {}   -- 이번 우편함에서 체크 푼 템
local function SendList()
    local s = DB()
    local stacks, total = {}, {}
    for bag = 0, BAG_LAST do
        for slot = 1, (NumSlots(bag) or 0) do
            local info = GetInfo(bag, slot)
            if info and Wanted(info) and not skipNow[info.itemID] then
                local id = info.itemID
                stacks[id] = stacks[id] or {}
                table.insert(stacks[id], { bag = bag, slot = slot, n = info.stackCount or 1, locked = info.isLocked })
                total[id] = (total[id] or 0) + (info.stackCount or 1)
            end
        end
    end
    local out, kinds = {}, {}
    for id, list in pairs(stacks) do
        local keep = tonumber(s.keep[id]) or 0
        local left = total[id] - keep
        if left > 0 then
            table.sort(list, function(a, b) return a.n < b.n end)   -- 작은 묶음부터 보내고 큰 걸 남겨요
            kinds[#kinds + 1] = { id = id, n = left, keep = keep }
            for _, st in ipairs(list) do
                if left <= 0 then break end
                if not st.locked then
                    local take = math.min(st.n, left)
                    out[#out + 1] = { bag = st.bag, slot = st.slot, id = id, n = take, split = take < st.n }
                    left = left - take
                end
            end
        end
    end
    table.sort(kinds, function(a, b) return a.n > b.n end)
    return out, kinds
end
ns.StashSendList = SendList

----------------------------------------------------------------------
-- 캐릭 기록 (가방 · 은행 개수)
----------------------------------------------------------------------
local function Count(bags)
    local t = {}
    for _, bag in ipairs(bags) do
        for slot = 1, (NumSlots(bag) or 0) do
            local info = GetInfo(bag, slot)
            if info and info.itemID then t[info.itemID] = (t[info.itemID] or 0) + (info.stackCount or 1) end
        end
    end
    return t
end
local function MeRec()
    local a = Alts()
    local n = Me()
    if not n then return end
    local r = a[n] or {}
    a[n] = r
    -- 예전에 앞 이름만으로 적힌 칸은 지워요 (여러 캐릭이 덮어쓴 것)
    local short = UnitName("player")
    if short and short ~= n then
        for k, b in pairs(ns.db.alts) do
            if type(b) == "table" then b[short] = nil; if k ~= RF() and next(b) == nil then ns.db.alts[k] = nil end end
        end
    end
    local _, cls = UnitClass("player")
    r.cls, r.lvl, r.t = cls, UnitLevel("player"), time()
    return r
end
ns.StashMeRec = function() return MeRec() end
local function RecordBags()
    local r = MeRec(); if not r then return end
    local b = {}
    for i = 0, BAG_LAST do b[#b + 1] = i end
    r.bags = Count(b)
end
ns.StashRecord = function() pcall(MeRec); RecordBags() end
local function RecordBank()
    local r = MeRec(); if not r then return end
    local b = { _G.BANK_CONTAINER or -1 }
    local first = BANK_FIRST
    for i = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do b[#b + 1] = i end
    r.bank = Count(b)
end

-- 툴팁: 다른 캐릭이 가진 개수 (창고 캐릭은 맨 앞에 "창고")
if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
        if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
        if not ns.db or not DB().tip then return end
        local id = data and data.id
        if not id or (issecretvalue and issecretvalue(id)) then return end
        local s = DB()
        local parts, sum = {}, 0
        for name, r in pairs(Alts()) do
            if name ~= Me() then
                local n = ((r.bags and r.bags[id]) or 0) + ((r.bank and r.bank[id]) or 0)
                if n > 0 then
                    sum = sum + n
                    local cc = r.cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[r.cls]
                    local hex = cc and cc:GenerateHexColor() or "ffd8c6c1"
                    local lab = (name == s.target) and (ns.L("창고") .. " ") or ""
                    table.insert(parts, (name == s.target) and 1 or #parts + 1, lab .. "|c" .. hex .. Pretty(name) .. "|r " .. n)
                end
            end
        end
        if #parts == 0 then return end
        tt:AddLine("|cfff2b3c2" .. ns.L("내 캐릭") .. "|r  " .. table.concat(parts, "  ·  ") .. (#parts > 1 and ("  |cff8a7a76(" .. sum .. ")|r") or ""), 0.85, 0.78, 0.76, true)
    end)
end

----------------------------------------------------------------------
-- 판 (우편함 · 은행 옆) 공통 모양
----------------------------------------------------------------------
-- 우편함 · 은행 옆에 붙는 판은 블리자드 창과 어울리게 (어두운 바탕 + 금테 + 빨간 단추)
local ENV_ICON = "Interface\\Icons\\INV_Letter_15"
local function BlizzPlate(f)
    if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
    f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
                    tile = true, tileSize = 32, edgeSize = 20, insets = { left = 5, right = 5, top = 5, bottom = 5 } })
    f:SetBackdropColor(0.09, 0.07, 0.06, 0.96)
end
local function Icon(parent, size)
    local t = parent:CreateTexture(nil, "ARTWORK"); t:SetTexture(ENV_ICON); t:SetSize(size, size); t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local b = parent:CreateTexture(nil, "OVERLAY"); b:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    b:SetPoint("TOPLEFT", t, "TOPLEFT", -size * 0.28, size * 0.28); b:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", size * 0.28, -size * 0.28)
    return t
end
local function Panel(name, w)
    local f = CreateFrame("Frame", name, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(w, 100); f:SetFrameStrata("HIGH")
    BlizzPlate(f)
    local ic = Icon(f, 20); ic:SetPoint("TOPLEFT", 14, -12)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal"); f.title:SetPoint("LEFT", ic, "RIGHT", 8, 0)
    f.rows = {}
    f:Hide()
    return f
end
-- 블리자드 빨간 단추 (글 길이에 맞춰 넓이)
local function BlizzBtn(parent, h, minW)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetHeight(h or 22)
    function b:SetLabel(t)
        self:SetText(t)
        local fs = self:GetFontString()
        self:SetWidth(math.max(minW or 60, ((fs and fs:GetStringWidth()) or 60) + 24))
    end
    return b
end
local function Btn(parent, text, w, fn)
    local b = BlizzBtn(parent, 22, w)
    b:SetLabel(ns.L(text)); b:SetScript("OnClick", fn)
    return b
end
local function Row(f, i)
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, f); r:SetHeight(22)
    r.chk = r:CreateTexture(nil, "ARTWORK"); r.chk:SetTexture(ns.MEDIA .. "circle"); r.chk:SetSize(14, 14); r.chk:SetPoint("LEFT", 2, 0)
    r.ic = r:CreateTexture(nil, "ARTWORK"); r.ic:SetSize(18, 18); r.ic:SetPoint("LEFT", r.chk, "RIGHT", 6, 0); r.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.name:SetPoint("LEFT", r.ic, "RIGHT", 6, 0); r.name:SetWidth(170); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.n = r:CreateFontString(nil, "OVERLAY", "NumberFontNormal"); r.n:SetPoint("RIGHT", -4, 0)
    r.keep = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); r.keep:SetPoint("RIGHT", r.n, "LEFT", -6, 0)
    r:SetScript("OnEnter", function(self) if self.id then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetItemByID(self.id); GameTooltip:Show() end end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.rows[i] = r
    return r
end

----------------------------------------------------------------------
-- ③ 우편함: 보낼 목록 + 채우기
----------------------------------------------------------------------
local sendP, recvP
local BuildSend   -- 아래에서 만들어요 (띠의 '목록'이 먼저 불러요)
local filling, batchNo = false, 0
local function MailOpen() return MailFrame and MailFrame:IsShown() end
local function ToSendTab()
    if MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, nil, 2)
    elseif MailFrameTab2 then MailFrameTab2:Click() end
end
local function FreeAttach()
    for i = 1, ATT do if not (HasSendMailItem and HasSendMailItem(i)) and not GetSendMailItem(i) then return i end end
end
local function Fill(onDone)
    if filling or InCombatLockdown() or not MailOpen() then return end
    local s = DB()
    local list = SendList()
    if #list == 0 then if onDone then onDone(0) else P("보낼 템이 없어요.") end return end
    ToSendTab()
    batchNo = batchNo + 1
    if SendMailNameEditBox then SendMailNameEditBox:SetText(s.target) end
    if SendMailSubjectEditBox then SendMailSubjectEditBox:SetText(SUBJ .. " " .. batchNo) end
    filling = true
    local i, put = 0, 0
    local function Step()
        i = i + 1
        local e = list[i]
        local free = FreeAttach()
        if not e or not free or not MailOpen() then
            filling = false
            if onDone then onDone(put) return end
            if sendP and sendP:IsShown() then sendP.Paint() end
            if e and not free then P("12칸을 채웠어요. 보내기를 누르면 다음 묶음을 준비해요.") end
            return
        end
        ClearCursor()
        if e.split then Split(e.bag, e.slot, e.n) else Pickup(e.bag, e.slot) end
        if CursorHasItem and CursorHasItem() then
            ClickSendMailItemButton(free)
            if CursorHasItem() then ClearCursor() else put = put + 1 end
        end
        C_Timer.After(0.15, Step)
    end
    Step()
end
ns.StashFill = Fill

----------------------------------------------------------------------
-- 한 번에 보내기: 채우기 → 보내기 → 남으면 다음 우편 (A 단추 · B 띠)
----------------------------------------------------------------------
local run = nil   -- { mails, slots, cost }
local aBtn
local function Money(c) return GetCoinTextureString and GetCoinTextureString(c) or tostring(c) end
local function RunEnd(msg)
    local r = run; run = nil
    if r and r.mails > 0 then
        DB().progSent = true
        P(ns.L("창고로 보냈어요") .. ": " .. ns.L("우편") .. " " .. r.mails .. ns.L("통") .. " · " .. r.slots .. ns.L("칸") .. " · " .. ns.L("요금") .. " " .. Money(r.cost))
    end
    if msg then P(msg) end
    if ns.StashMailPaint then ns.StashMailPaint() end
end
local function RunNext()
    if not run then return end
    if not MailOpen() then RunEnd("우편함이 닫혀서 멈췄어요.") return end
    if InCombatLockdown() then RunEnd("전투 중이라 멈췄어요.") return end
    if ns.StashMailPaint then ns.StashMailPaint() end
    Fill(function(put)
        if not run then return end
        if put == 0 then RunEnd() return end
        local cost = (GetSendMailPrice and GetSendMailPrice()) or 0
        if GetMoney and GetMoney() < cost then RunEnd("우편 요금이 모자라요.") return end
        local pend = { put = put, cost = cost }
        run.pending = pend
        local s = DB()
        local ok = pcall(SendMail, s.target, (SendMailSubjectEditBox and SendMailSubjectEditBox:GetText()) or SUBJ, "")
        if not ok then RunEnd("보내기가 막혔어요 · 게임 '보내기'를 눌러 주세요.") return end
        -- 소식이 없으면 멈춰요 (게임이 "모르는 사람일 수도" 확인 창을 띄우면 그걸 누를 때까지 기다려요)
        local function Wait()
            if not (run and run.pending == pend) then return end
            local pop = StaticPopup_Visible and (StaticPopup_Visible("CONFIRM_MAIL_ITEM_UNREFUNDABLE") or StaticPopup_Visible("SEND_MAIL_UNKNOWN_RECIPIENT"))
            local anyPop = false
            for i = 1, 4 do local f = _G["StaticPopup" .. i]; if f and f:IsShown() then anyPop = true end end
            if pop or anyPop then pend.t = GetTime(); pend.popped = true; C_Timer.After(0.3, Wait) return end
            -- 확인 창을 '취소'로 닫았으면 바로 멈춰요 (보냈다면 곧 보냄 소식이 와요)
            if pend.popped and GetTime() - pend.t > 1.2 then RunEnd("보내기를 취소했어요.") return end
            if GetTime() - pend.t > 10 then RunEnd("보내기가 막혔어요 · 게임 '보내기'를 눌러 주세요.") return end
            C_Timer.After(1, Wait)
        end
        pend.t = GetTime()
        C_Timer.After(0.3, Wait)
    end)
end
function ns.StashSendAll()
    if run or filling then return end
    if not Active() then P("창고 캐릭을 아직 안 정했어요 · /leel → 창고 부캐에서 골라 주세요") return end
    if #SendList() == 0 then P("보낼 템이 없어요.") return end
    run = { mails = 0, slots = 0, cost = 0 }
    ToSendTab()
    C_Timer.After(0.1, RunNext)
end
function ns.StashStop() if run then RunEnd("멈췄어요.") end end
local function OnSent(ok)
    if not run then return false end
    local p = run.pending; run.pending = nil
    if not ok then RunEnd("보내기에 실패했어요 (받는 사람 이름을 확인해 주세요).") return true end
    if p then
        run.mails = run.mails + 1; run.slots = run.slots + p.put; run.cost = run.cost + p.cost
        if ns.GoldTipMailSent then pcall(ns.GoldTipMailSent, DB().target, p.put) end   -- 창고 캐릭 우편함에 1통 더 (골드 툴팁)
    end
    C_Timer.After(0.5, RunNext)
    return true
end

-- 우편 창 위에 붙여요 (위가 화면 밖이면 아래 탭 밑으로)
function ns.StashAbove(f, h)
    f:ClearAllPoints()
    local top, sTop = MailFrame:GetTop(), UIParent:GetTop()
    local sc = (MailFrame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    if top and sTop and (top * sc + h + 10) > sTop then
        f:SetPoint("TOPLEFT", MailFrame, "BOTTOMLEFT", 0, -40); f:SetPoint("TOPRIGHT", MailFrame, "BOTTOMRIGHT", 0, -40)
    else
        f:SetPoint("BOTTOMLEFT", MailFrame, "TOPLEFT", 0, 6); f:SetPoint("BOTTOMRIGHT", MailFrame, "TOPRIGHT", 0, 6)
    end
end

-- 지금 상태로 A · B 다시 그리기
function ns.StashMailPaint()
    if not MailOpen() or not Active() then
        if aBtn then aBtn:Hide() end
        return
    end
    local s = DB()
    local list, kinds = SendList()
    local slots = #list
    -- 무엇을: 많은 종류 2개까지 이름
    local names = {}
    for i = 1, math.min(2, #kinds) do
        local nm = (C_Item and C_Item.GetItemInfo or GetItemInfo)(kinds[i].id)
        names[#names + 1] = (nm or ("#" .. kinds[i].id)) .. " " .. kinds[i].n
    end
    if #kinds > 2 then names[#names + 1] = ns.L("외") .. " " .. (#kinds - 2) .. ns.L("종류") end
    -- A 단추: 우편함 탭 옆
    if not aBtn then
        aBtn = BlizzBtn(MailFrame, 22, 90)
        aBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        aBtn:SetScript("OnClick", function(self, btn)
            if btn == "RightButton" then
                if not sendP then BuildSend() end
                if sendP:IsShown() then sendP:Hide() else sendP:ClearAllPoints(); sendP:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 8, 0); sendP:Show(); sendP.Paint() end
            elseif run then ns.StashStop()
            else ns.StashSendAll() end
        end)
        aBtn:SetScript("OnEnter", function(self)
            local _, kk = SendList()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(ns.L(Pretty(DB().target) .. "에게"), 1, 0.82, 0)
            for i2 = 1, math.min(10, #kk) do
                local nm = (C_Item and C_Item.GetItemInfo or GetItemInfo)(kk[i2].id)
                GameTooltip:AddDoubleLine(nm or ("#" .. kk[i2].id), "x" .. kk[i2].n, 1, 1, 1, 1, 1, 1)
            end
            if #kk > 10 then GameTooltip:AddLine(ns.L("외") .. " " .. (#kk - 10) .. ns.L("종류"), 0.7, 0.7, 0.7) end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(ns.L("왼쪽 클릭: 보내기 · 오른쪽 클릭: 목록 (빼기)"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        aBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    local tab = _G.MailFrameTab2
    aBtn:ClearAllPoints()
    if tab then aBtn:SetPoint("LEFT", tab, "RIGHT", 8, 0) else aBtn:SetPoint("TOPLEFT", MailFrame, "BOTTOMLEFT", 0, -4) end
    if run then
        local done = run.slots + ((run.pending and run.pending.put) or 0)
        aBtn:SetLabel(ns.L("멈추기") .. " " .. done .. "/" .. (done + slots) .. ns.L("칸"))
        aBtn:Enable()
    else
        aBtn:SetLabel(ns.L("창고로 보내기") .. " " .. slots .. ns.L("칸"))
        aBtn:SetEnabled(slots > 0)
    end
    aBtn:Show()
end

function BuildSend()
    sendP = Panel("LeelUI_StashSend", 290)
    sendP.list = sendP:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sendP.fill = Btn(sendP, "이대로 보내기", 150, function() ns.StashSendAll() end, true)
    sendP.hint = sendP:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    function sendP.Paint()
        local s = DB()
        local list, kinds = SendList()
        sendP.title:SetText(ns.L(Pretty(s.target) .. "에게 보낼 것") .. "  |cffd8c6c1" .. #list .. ns.L("칸") .. "|r")
        local y = -38
        for _, r in ipairs(sendP.rows) do r:Hide() end
        local shown = 0
        -- 체크 푼 것도 보여 줘야 다시 켤 수 있어요
        local all = {}
        for _, k in ipairs(kinds) do all[#all + 1] = { id = k.id, n = k.n, keep = k.keep, on = true } end
        for id in pairs(skipNow) do all[#all + 1] = { id = id, n = 0, keep = 0, on = false } end
        for i, k in ipairs(all) do
            if i > 10 then break end
            local r = Row(sendP, i)
            r.id = k.id
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 12, y); r:SetPoint("RIGHT", -12, 0)
            local name, _, q, _, _, _, _, _, _, tex = (C_Item and C_Item.GetItemInfo or GetItemInfo)(k.id)
            r.ic:SetTexture(tex or 134400)
            r.name:SetText(name or ("#" .. k.id))
            local qc = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
            if qc then r.name:SetTextColor(qc.r, qc.g, qc.b) end
            r.n:SetText(k.on and ("×" .. k.n) or "")
            r.keep:SetText(k.keep > 0 and (k.keep .. ns.L("개 남김")) or "")
            if k.on then r.chk:SetVertexColor(1, 0.82, 0, 1) else r.chk:SetVertexColor(0.3, 0.24, 0.23, 1) end
            r:SetAlpha(k.on and 1 or 0.5)
            r:SetScript("OnClick", function(self)
                if skipNow[self.id] then skipNow[self.id] = nil else skipNow[self.id] = true end
                sendP.Paint(); if ns.StashMailPaint then ns.StashMailPaint() end
            end)
            r:Show()
            y = y - 23; shown = shown + 1
        end
        if #all > 10 then sendP.list:SetText(ns.L("그 밖에") .. " " .. (#all - 10) .. ns.L("종류")); sendP.list:ClearAllPoints(); sendP.list:SetPoint("TOPLEFT", 14, y - 2); sendP.list:Show(); y = y - 18
        else sendP.list:Hide() end
        sendP.fill:ClearAllPoints(); sendP.fill:SetPoint("TOPLEFT", 12, y - 8)
        sendP.fill:SetEnabled(#list > 0 and not filling)
        sendP.hint:ClearAllPoints(); sendP.hint:SetPoint("TOPLEFT", 12, y - 38); sendP.hint:SetWidth(266); sendP.hint:SetJustifyH("LEFT")
        sendP.hint:SetText(ns.L("줄을 누르면 이번엔 빼요 · 12칸씩 나눠서 우편을 이어 보내요"))
        sendP:SetHeight(-(y - 38) + (sendP.hint:GetStringHeight() or 24) + 12)
        if #all == 0 then sendP:Hide() end
    end
end

----------------------------------------------------------------------
-- ④ 창고 캐릭: 우편 받기
----------------------------------------------------------------------
local taking = false
local function InboxScan()
    local stash, sold, money = {}, {}, 0
    local n = GetInboxNumItems and GetInboxNumItems() or 0
    for i = 1, n do
        local _, _, sender, subject, m, cod, _, hasItem = GetInboxHeaderInfo(i)
        if (cod or 0) == 0 then
            if type(subject) == "string" and subject:find(SUBJ, 1, true) == 1 then stash[#stash + 1] = i
            else
                local inv = GetInboxInvoiceInfo and GetInboxInvoiceInfo(i)
                if inv == "seller" and (m or 0) > 0 then sold[#sold + 1] = i; money = money + m end
            end
        end
    end
    return stash, sold, money
end
local function TakeAll(which)
    if taking or not MailOpen() then return end
    taking = true
    if recvP then recvP.Paint() end
    local function Step()
        if not MailOpen() then taking = false; return end
        local stash, sold = InboxScan()
        local list = which == "sold" and sold or stash
        local idx = list[#list]   -- 뒤에서부터 (앞 번호가 안 밀리게)
        if not idx then
            taking = false
            if which ~= "sold" then DB().progRecv = true end
            if recvP then recvP.Paint() end
            return
        end
        if AutoLootMailItem then AutoLootMailItem(idx) end
        C_Timer.After(0.6, Step)
    end
    Step()
end
local function BuildRecv()
    -- 창고 캐릭: 우편함 탭 옆 빨간 단추 (창고 우편 받기 · 판매금 받기)
    recvP = CreateFrame("Frame", nil, MailFrame); recvP:SetSize(1, 1)
    recvP.b1 = BlizzBtn(recvP, 22, 90); recvP.b1:SetScript("OnClick", function() TakeAll("stash") end)
    recvP.b2 = BlizzBtn(recvP, 22, 80); recvP.b2:SetScript("OnClick", function() TakeAll("sold") end)
    function recvP.Paint()
        local stash, sold, money = InboxScan()
        local tab = _G.MailFrameTab2
        recvP.b1:ClearAllPoints()
        if tab then recvP.b1:SetPoint("LEFT", tab, "RIGHT", 8, 0) else recvP.b1:SetPoint("TOPLEFT", MailFrame, "BOTTOMLEFT", 0, -4) end
        recvP.b1:SetLabel(ns.L("창고 우편 받기") .. " " .. #stash .. ns.L("통"))
        recvP.b1:SetEnabled(#stash > 0 and not taking)
        recvP.b2:ClearAllPoints(); recvP.b2:SetPoint("LEFT", recvP.b1, "RIGHT", 2, 0)
        recvP.b2:SetLabel(ns.L("판매금 받기") .. " " .. #sold .. ns.L("통"))
        recvP.b2:SetShown(#sold > 0); recvP.b2:SetEnabled(not taking)
        recvP.b2:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(ns.L("경매 판매금"), 1, 0.82, 0); GameTooltip:AddLine(Money(money), 1, 1, 1); GameTooltip:Show() end)
        recvP.b2:SetScript("OnLeave", function() GameTooltip:Hide() end)
        recvP:SetShown(#stash > 0 or #sold > 0)
    end
end

----------------------------------------------------------------------
-- ④ 창고 캐릭: 은행 열면 재료 넣기
----------------------------------------------------------------------
local bankP, moving = nil, false
local function BankBags()
    local t = { _G.BANK_CONTAINER or -1 }
    local first = BANK_FIRST
    for i = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do t[#t + 1] = i end
    return t
end
local function BankDest(id)
    local maxStack = select(8, (C_Item and C_Item.GetItemInfo or GetItemInfo)(id)) or 1
    local empty
    for _, bag in ipairs(BankBags()) do
        for slot = 1, (NumSlots(bag) or 0) do
            local info = GetInfo(bag, slot)
            if info and info.itemID == id and (info.stackCount or 1) < maxStack and not info.isLocked then return bag, slot end
            if not info and not empty then empty = { bag, slot } end
        end
    end
    if empty then return empty[1], empty[2] end
end
local function BankList()
    local out = {}
    for bag = 0, BAG_LAST do
        for slot = 1, (NumSlots(bag) or 0) do
            local info = GetInfo(bag, slot)
            if info and Wanted(info) and not info.isLocked then out[#out + 1] = { bag = bag, slot = slot, id = info.itemID } end
        end
    end
    return out
end
local function ToBank()
    if moving or InCombatLockdown() then return end
    moving = true
    local list, i = BankList(), 0
    local function Step()
        i = i + 1
        local e = list[i]
        if not e or not (BankFrame and BankFrame:IsShown()) then
            moving = false; ClearCursor(); RecordBank(); RecordBags()
            if bankP then bankP.Paint() end
            return
        end
        local db, ds = BankDest(e.id)
        if not db then moving = false; P("은행에 빈칸이 없어요.") if bankP then bankP.Paint() end return end
        ClearCursor(); Pickup(e.bag, e.slot); Pickup(db, ds)
        if CursorHasItem and CursorHasItem() then ClearCursor() end
        C_Timer.After(0.25, Step)
    end
    Step()
end
local function BuildBank()
    bankP = Panel("LeelUI_StashBank", 240)
    bankP.b = Btn(bankP, "재료 은행에 넣기", 150, function() ToBank() end, true)
    function bankP.Paint()
        local n = #BankList()
        if n == 0 then bankP:Hide() return end
        bankP.title:SetText(ns.L("창고 정리") .. "  |cffd8c6c1" .. n .. ns.L("칸") .. "|r")
        bankP.b:ClearAllPoints(); bankP.b:SetPoint("TOPLEFT", 12, -38)
        bankP:SetHeight(74)
        bankP:Show()
    end
end

----------------------------------------------------------------------
-- ② 르엘 가방: 봉투 · 머리 알약 · 휠클릭 메뉴
----------------------------------------------------------------------
local menu
local function OpenMenu(owner, id)
    if not menu then
        menu = CreateFrame("Frame", "LeelUI_StashMenu", UIParent)
        menu:SetSize(220, 10); menu:SetFrameStrata("TOOLTIP")
        if ns.RoundPlate then ns.RoundPlate(menu, 10, { 0.10, 0.075, 0.07, 0.98 }, { C.acc[1], C.acc[2], C.acc[3], 0.6 }) end
        menu.items = {}
        menu:SetScript("OnUpdate", function(self) if not self:IsMouseOver(8, -8, -8, 8) and not (self.owner and self.owner:IsMouseOver()) then self:Hide() end end)
    end
    local s = DB()
    local name = (C_Item and C_Item.GetItemInfo or GetItemInfo)(id) or ("#" .. id)
    local opts = {
        { Pretty(s.target or "?") .. ns.L("에게 늘 보내기"), function() s.always[id] = true; s.never[id] = nil end, s.always[id] },
        { ns.L("이 템은 안 보내기"), function() s.never[id] = true; s.always[id] = nil; s.keep[id] = nil end, s.never[id] },
        { ns.L("20개만 남기고 보내기"), function() s.keep[id] = 20; s.never[id] = nil end, s.keep[id] == 20 },
        { ns.L("규칙 지우기 (종류대로)"), function() s.always[id] = nil; s.never[id] = nil; s.keep[id] = nil end, false },
    }
    for _, it in ipairs(menu.items) do it:Hide() end
    menu.head = menu.head or ns.Font(menu, 11, { 0.73, 0.65, 0.63 })
    menu.head:SetText(name); menu.head:ClearAllPoints(); menu.head:SetPoint("TOPLEFT", 12, -8)
    local y = -26
    for i, o in ipairs(opts) do
        local b = menu.items[i]
        if not b then
            b = CreateFrame("Button", nil, menu); b:SetHeight(22)
            b.fs = ns.Font(b, 12); b.fs:SetPoint("LEFT", 6, 0)
            b.hl = b:CreateTexture(nil, "BACKGROUND"); b.hl:SetAllPoints(); b.hl:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.18); b.hl:Hide()
            b:SetScript("OnEnter", function(self) self.hl:Show() end)
            b:SetScript("OnLeave", function(self) self.hl:Hide() end)
            menu.items[i] = b
        end
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 6, y); b:SetPoint("RIGHT", -6, 0)
        b.fs:SetText((o[3] and "|cffff8fa3● |r" or "") .. o[1])
        b:SetScript("OnClick", function() o[2](); menu:Hide(); if ns.UpdateBags then pcall(ns.UpdateBags) end end)
        b:Show()
        y = y - 22
    end
    menu:SetHeight(-y + 8)
    menu.owner = owner
    menu:ClearAllPoints(); menu:SetPoint("TOPLEFT", owner, "BOTTOMRIGHT", 0, 0)
    menu:Show()
end

local pillPend = false
function ns.StashMark(b, bag, slot, info)
    if not b.leelStashHook then
        b.leelStashHook = true
        b:HookScript("OnMouseUp", function(self, btn)
            if btn ~= "MiddleButton" or not ns.db then return end
            local s = DB()
            if not s.on or not s.target then return end
            local id = self.leelItemID
            if id then OpenMenu(self, id) end
        end)
    end
    local show = Active() and info and Wanted(info)
    if show and not b.leelEnv then
        local e = CreateFrame("Frame", nil, b); e:SetSize(15, 15); e:SetPoint("CENTER", b, "BOTTOMRIGHT", -3, 3)
        e:SetFrameLevel(b:GetFrameLevel() + 7)
        local bg = e:CreateTexture(nil, "ARTWORK"); bg:SetTexture(ns.MEDIA .. "circle"); bg:SetAllPoints(); bg:SetVertexColor(0.125, 0.094, 0.086, 1)
        local d = e:CreateTexture(nil, "ARTWORK", nil, 1); d:SetTexture(ns.MEDIA .. "circle"); d:SetPoint("TOPLEFT", 1.5, -1.5); d:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
        d:SetVertexColor(C.acc[1], C.acc[2], C.acc[3], 1)
        local ic = e:CreateTexture(nil, "OVERLAY"); ic:SetTexture("Interface\\Icons\\INV_Letter_15"); ic:SetPoint("TOPLEFT", 3, -3); ic:SetPoint("BOTTOMRIGHT", -3, 3)
        local m = e:CreateMaskTexture(); m:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); m:SetAllPoints(ic); ic:AddMaskTexture(m)
        b.leelEnv = e
    end
    if b.leelEnv then b.leelEnv:SetShown(show and true or false) end
    if not pillPend then pillPend = true; C_Timer.After(0.2, function() pillPend = false; if ns.StashPaintPill then ns.StashPaintPill() end end) end
end

-- 가방 머리 알약: "📮 루루에게 7칸"
local pill
local function PaintPill()
    -- 가방 머리 알약은 없앴어요 (우편함 단추가 저절로 보내요 · 보낼 템은 칸 구석 봉투로)
    if pill then pill:Hide() end
    do return end
    local win = _G.LeelUI_Bag
    if not win then return end
    if not pill then
        pill = CreateFrame("Frame", nil, win); pill:SetHeight(18); pill:SetFrameLevel(win:GetFrameLevel() + 5)
        pill.bg = ns.RoundRect(pill, 9, C.acc, "BACKGROUND", 0, 0); pill.bg:SetColor(C.acc, 0.22)
        pill.fs = ns.Font(pill, 11, { 1, 0.84, 0.88 }); pill.fs:SetPoint("CENTER", 0, 0)
        pill:SetPoint("TOP", win, "TOP", 0, -12)
    end
    if not Active() then pill:Hide() return end
    local list = SendList()
    if #list == 0 then pill:Hide() return end
    pill.fs:SetText(Pretty(DB().target) .. ns.L("에게") .. " " .. #list .. ns.L("칸"))
    pill:SetWidth((pill.fs:GetStringWidth() or 60) + 18)
    pill:Show()
    if win:IsVisible() then ns.StashTip("bag", pill) end
end
ns.StashPaintPill = PaintPill

----------------------------------------------------------------------
-- C안: 처음 한 번만 그 자리에 토끼 말풍선 (✕ 누르면 다시 안 떠요)
----------------------------------------------------------------------
local tip
local TIPS = {
    bag  = "봉투가 붙은 칸이 창고로 보낼 템이에요. 템을 휠클릭하면 '늘 보내기 · 안 보내기 · 20개 남기기'를 정할 수 있어요.",
    mail = "'채우기'를 누르면 받는 사람 · 템 12칸이 들어가요. 그다음 게임 '보내기'만 누르면 끝! 다음 묶음은 저절로 채워져요.",
    recv = "'모두 받기'를 누르면 창고 우편을 한 번에 받아요. 경매 판매금은 '판매금 받기'로 따로.",
    bank = "'재료 은행에 넣기'를 누르면 받은 재료를 은행 같은 칸에 쌓아 넣어요.",
}
function ns.StashTip(key, anchor)
    local s = DB()
    s.tips = s.tips or {}
    if s.tips[key] or not anchor or not anchor:IsVisible() then return end
    if not tip then
        tip = CreateFrame("Frame", "LeelUI_StashTip", UIParent); tip:SetFrameStrata("TOOLTIP"); tip:SetWidth(270)
        tip.bg = ns.RoundRect(tip, 12, { 1, 0.945, 0.957 }, "BACKGROUND", 0, 0); tip.bg:SetColor({ 1, 0.945, 0.957 }, 1)
        tip.ar = tip:CreateTexture(nil, "BACKGROUND", nil, 1); tip.ar:SetTexture("Interface\\Buttons\\WHITE8X8"); tip.ar:SetSize(12, 12)
        tip.ar:SetVertexColor(1, 0.945, 0.957, 1); tip.ar:SetRotation(math.rad(45)); tip.ar:SetPoint("CENTER", tip, "TOPLEFT", 30, 0)
        tip.head = ns.Font(tip, 13, { 0.76, 0.27, 0.42 }); tip.head:SetPoint("TOPLEFT", 12, -9); tip.head:SetText("처음이죠?"); tip.head:SetShadowColor(0, 0, 0, 0)
        tip.fs = ns.Font(tip, 12, { 0.23, 0.11, 0.14 }); tip.fs:SetPoint("TOPLEFT", tip.head, "BOTTOMLEFT", 0, -4); tip.fs:SetWidth(246)
        tip.fs:SetJustifyH("LEFT"); tip.fs:SetShadowColor(0, 0, 0, 0)
        tip.x = CreateFrame("Button", nil, tip); tip.x:SetSize(18, 18); tip.x:SetPoint("TOPRIGHT", -6, -6)
        tip.xfs = ns.Font(tip.x, 13, { 0.54, 0.35, 0.40 }); tip.xfs:SetPoint("CENTER"); tip.xfs:SetText("x"); tip.xfs:SetShadowColor(0, 0, 0, 0)
        tip.x:SetScript("OnClick", function() if tip.key then DB().tips[tip.key] = true end; tip:Hide() end)
        tip:SetScript("OnUpdate", function(self) if not (self.anchor and self.anchor:IsVisible()) then self:Hide() end end)
    end
    tip.key, tip.anchor = key, anchor
    tip.fs:SetText(ns.L(TIPS[key] or ""))
    tip:SetHeight(9 + 16 + 4 + (tip.fs:GetStringHeight() or 30) + 12)
    tip:ClearAllPoints(); tip:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -10, -10)
    tip:Show()
    s.tips[key] = true   -- 한 번 보였으면 다음부턴 안 떠요 (✕ 안 눌러도)
end

----------------------------------------------------------------------
-- 이벤트
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "MAIL_SEND_SUCCESS", "MAIL_FAILED",
                     "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
local bagPend = false
ev:SetScript("OnEvent", function(_, e)
    if not ns.db then return end
    if e == "PLAYER_LOGIN" then
        pcall(MeRec)   -- 접속하자마자 이름부터 적어요 (가방 개수는 조금 뒤)
        C_Timer.After(3, function() RecordBags(); PaintPill() end)
    elseif e == "BAG_UPDATE_DELAYED" then
        if bagPend then return end
        bagPend = true
        C_Timer.After(0.5, function()
            bagPend = false
            RecordBags(); PaintPill()
            if sendP and sendP:IsShown() and not filling then sendP.Paint() end
            if not run and not filling and MailOpen() then ns.StashMailPaint() end
            if bankP and bankP:IsShown() and not moving then bankP.Paint() end
        end)
    elseif e == "MAIL_SHOW" then
        if not ns.StashMailOpen then return end
        local ok, err = pcall(ns.StashMailOpen)
        if not ok then P("우편함 판 오류: " .. tostring(err)) end
    end
end)
-- 우편함이 열릴 때 (이벤트 + 우편 창 OnShow 둘 다 · 한 번만 돌아요)
local mailT = 0
function ns.StashMailOpen()
    if GetTime() - mailT < 0.5 then return end
    mailT = GetTime()
    do
        wipe(skipNow); batchNo = 0
        local s = DB()
        if s.on and not s.target then P("창고 캐릭을 아직 안 정했어요 · /leel → 창고 부캐에서 골라 주세요") end
        if not s.on or not s.target then return end
        if IsTarget() then
            if not recvP then BuildRecv() end
            C_Timer.After(0.5, function() recvP.Paint(); if recvP:IsShown() then ns.StashTip("recv", recvP.b1) end end)
        elseif Active() then
            -- 우편함 이벤트가 창보다 먼저 와요 → 창이 뜬 다음에 그려요
            C_Timer.After(0.05, ns.StashMailPaint)
            C_Timer.After(0.4, function() if aBtn and aBtn:IsShown() then ns.StashTip("mail", aBtn) end end)
        end
    end
end
if MailFrame then MailFrame:HookScript("OnShow", function() local ok, err = pcall(ns.StashMailOpen); if not ok then P("우편함 판 오류: " .. tostring(err)) end end) end
ev:HookScript("OnEvent", function(_, e)
    if not ns.db then return end
    if e == "MAIL_SHOW" then return
    elseif e == "MAIL_CLOSED" then
        if sendP then sendP:Hide() end
        if recvP then recvP:Hide() end
        if aBtn then aBtn:Hide() end
        if run then RunEnd() end
        filling, taking = false, false
    elseif e == "MAIL_INBOX_UPDATE" then
        if recvP and IsTarget() and MailOpen() and not taking then recvP.Paint() end
    elseif e == "MAIL_SEND_SUCCESS" then
        if OnSent(true) then return end
        -- 게임 '보내기'로 직접 보냈을 때: 숫자만 다시
        if batchNo > 0 then DB().progSent = true end
        C_Timer.After(0.6, function() if MailOpen() and Active() then ns.StashMailPaint(); if sendP and sendP:IsShown() then sendP.Paint() end end end)
    elseif e == "MAIL_FAILED" then
        OnSent(false)
    elseif e == "BANKFRAME_OPENED" then
        C_Timer.After(0.3, RecordBank)
        if IsTarget() and DB().on then
            if not bankP then BuildBank() end
            bankP:ClearAllPoints(); bankP:SetPoint("TOPLEFT", BankFrame, "TOPRIGHT", 8, 0)
            C_Timer.After(0.3, function() bankP.Paint(); if bankP:IsShown() then ns.StashTip("bank", bankP.b) end end)
        end
    elseif e == "BANKFRAME_CLOSED" then
        if bankP then bankP:Hide() end
    elseif e == "PLAYERBANKSLOTS_CHANGED" then
        if BankFrame and BankFrame:IsShown() and not moving then C_Timer.After(0.3, RecordBank) end
    end
end)

-- 허브: 창고 캐릭 고르기 목록 (같은 서버 · 진영 캐릭)
function ns.StashTargets()
    local out = { { key = "", label = "— 없음" } }
    -- 기록된 모든 캐릭 (서버 · 진영 묶음을 다 훑어요 · 다른 진영이면 표시)
    local names, seen = {}, {}
    local myK = RF()
    local myFac = UnitFactionGroup("player")
    for k, a in pairs(ns.db.alts or {}) do
        for name, r in pairs(a) do
            if name ~= Me() and not seen[name] then
                seen[name] = true
                local fac = type(k) == "string" and k:match("%-(%a+)$")
                names[#names + 1] = { n = name, r = r, other = (k ~= myK) and fac and fac ~= myFac, fac = fac }
            end
        end
    end
    table.sort(names, function(x, y) return x.n < y.n end)
    for _, o in ipairs(names) do
        local lab = Pretty(o.n) .. ((o.r and o.r.lvl) and (" · " .. o.r.lvl) or "")
        if o.other then lab = lab .. " · " .. ns.L(o.fac == "Alliance" and "얼라이언스" or "호드") .. ns.L(" (다른 진영)") end
        out[#out + 1] = { key = o.n, label = lab }
    end
    local t = DB().target
    if t and t ~= "" then local has = false; for _, o in ipairs(out) do if o.key == t then has = true end end; if not has then out[#out + 1] = { key = t, label = Pretty(t) } end end
    return out
end
function ns.StashRuleCount()
    local s = DB()
    local a, n, k = 0, 0, 0
    for _ in pairs(s.always) do a = a + 1 end
    for _ in pairs(s.never) do n = n + 1 end
    for _ in pairs(s.keep) do k = k + 1 end
    return a, n, k
end

-- A안: 허브 맨 위 처음 쓰기 5단계 (어디까지 했는지 저절로)
function ns.StashStep(i)
    local s = DB()
    local t = s.target
    local alt = t and Alts()[t]
    if t then t = Pretty(t) end
    local anyCat = false
    for _, v in pairs(s.cats) do if v then anyCat = true end end
    local done = {
        t ~= nil and t ~= "",
        alt ~= nil,
        anyCat,
        s.progSent == true,
        s.progRecv == true,
    }
    local text = {
        "창고 캐릭 정하기" .. (t and (" · " .. t) or ""),
        (t or "창고 캐릭") .. "으로 한 번 접속" .. (alt and alt.bank and " (은행 기록 있음)" or ""),
        "보낼 종류 고르기 (아래에서)",
        "우편함에서 '창고로 보내기' 한 번",
        (t or "창고 캐릭") .. "으로 접속 → 우편함 '모두 받기'",
    }
    local first
    for k = 1, 5 do if not done[k] then first = k break end end
    local mark = done[i] and "|cff9fe3c0● " or (i == first and "|cffff8fa3→ " or "|cff8a7a76· ")
    return mark .. i .. ". " .. ns.L(text[i]) .. "|r"
end

-- /르엘창고 : 지금 상태를 채팅에 (안 뜰 때 원인 찾기)
SLASH_LEELSTASH1 = "/르엘창고"
SLASH_LEELSTASH2 = "/leelstash"
SlashCmdList.LEELSTASH = function()
    if not ns.db then return end
    local s = DB()
    local n = 0; for _ in pairs(Alts()) do n = n + 1 end
    P("켜짐 " .. tostring(s.on) .. " · 나 " .. tostring(Me()) .. " · 창고 " .. tostring(s.target) .. " · 기록된 캐릭 " .. n)
    if Active() then
        local list = SendList()
        P("보낼 칸 " .. #list .. " · 우편함 " .. (MailOpen() and "열림" or "닫힘"))
        -- 가방 칸을 종류별로 세어 봐요 (왜 0인지)
        local tally, bound, total = {}, 0, 0
        for bag = 0, BAG_LAST do
            for slot = 1, (NumSlots(bag) or 0) do
                local info = GetInfo(bag, slot)
                if info and info.itemID then
                    total = total + 1
                    if info.isBound then bound = bound + 1
                    else
                        local _, _, _, _, _, cid, sid = GetItemInfoInstant(info.itemID)
                        local c = CatOf(info.itemID, info.quality) or ("c" .. tostring(cid) .. "." .. tostring(sid) .. "/q" .. tostring(info.quality))
                        tally[c] = (tally[c] or 0) + 1
                    end
                end
            end
        end
        local parts = {}
        for c, k in pairs(tally) do parts[#parts + 1] = c .. (s.cats[c] and "(켬)" or "") .. " " .. k end
        table.sort(parts)
        P("가방 " .. total .. "칸 · 귀속 " .. bound .. " · " .. table.concat(parts, ", "))
        if MailOpen() then pcall(ns.StashMailOpen) end
    elseif IsTarget() then
        P("이 캐릭이 창고예요 → 우편함에서 '모두 받기'")
    end
end
