-- LeelUI / Quest.lua
-- 퀘스트 자동 받기: 말 걸면 수락, 고를 보상이 없으면 완료까지. 보상 고르기는 직접 (가장 비싼 보상에 분홍 표시)
-- Shift 누른 채 말 걸면 그때만 쉬어요.

local _, ns = ...
local C = ns.C
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo  -- 새 클라이언트는 C_Item 쪽에만 있음

local function DB()
    ns.db.quest = ns.db.quest or {}
    local d = ns.db.quest
    local def = { on = true, accept = true, complete = true, gossip = false, best = true, skipTrivial = true }
    for k, v in pairs(def) do if d[k] == nil then d[k] = v end end
    return d
end
ns.QuestDB = DB

----------------------------------------------------------------------
-- 작은 분홍 알약 알림 (화면 위 가운데). 가방 한눈에도 같이 씀
----------------------------------------------------------------------
local pills = {}
function ns.PillToast(text, icon, warn)
    local t
    -- 같은 알림이 이미 떠 있으면 새로 쌓지 않고 그 알림 시간만 다시 시작
    for _, p in ipairs(pills) do
        if p:IsShown() and p.text == text then
            p.t = 0; p:SetAlpha(1)
            return
        end
    end
    for _, p in ipairs(pills) do if not p:IsShown() then t = p break end end
    if not t then
        t = CreateFrame("Frame", nil, UIParent)
        t:SetHeight(30)
        t:SetFrameStrata("HIGH")
        t.fill, t.edge = ns.RoundPlate(t, 15, { 0.125, 0.094, 0.086, 0.96 }, { 0.949, 0.702, 0.761, 0.65 })
        t.disc = t:CreateTexture(nil, "ARTWORK")
        t.disc:SetTexture(ns.MEDIA .. "circle"); t.disc:SetSize(22, 22); t.disc:SetPoint("LEFT", 5, 0)
        t.ic = t:CreateTexture(nil, "OVERLAY")
        t.ic:SetSize(14, 14); t.ic:SetPoint("CENTER", t.disc)
        t.ic:SetVertexColor(C.ink[1], C.ink[2], C.ink[3], 1)
        t.fs = ns.Font(t, 12.5)
        t.fs:SetPoint("LEFT", t.disc, "RIGHT", 7, 0)
        t:SetScript("OnUpdate", function(self, el)
            self.t = (self.t or 0) + el
            if self.t > 4 then
                local a = 1 - (self.t - 4) / 0.5
                if a <= 0 then self:Hide() else self:SetAlpha(a) end
            end
        end)
        t:SetScript("OnHide", function() C_Timer.After(0, ns.PillReflow) end)
        pills[#pills + 1] = t
    end
    local c = warn and { 1, 0.56, 0.64 } or C.acc
    t.disc:SetVertexColor(c[1], c[2], c[3], 1)
    t.edge:SetColor(c, 0.75)
    t.ic:SetTexture(ns.MEDIA .. (icon or "hb_quest"))
    t.fs:SetText(text)
    t.text = text
    t:SetWidth(t.fs:GetStringWidth() + 48)
    t.t, t.order = 0, GetTime()
    t:SetAlpha(1)
    t:Show()
    ns.PillReflow()
end

function ns.PillReflow()
    local shown = {}
    for _, p in ipairs(pills) do if p:IsShown() then shown[#shown + 1] = p end end
    table.sort(shown, function(a, b) return a.order < b.order end)
    for i, p in ipairs(shown) do
        p:ClearAllPoints()
        p:SetPoint("TOP", UIParent, "TOP", 0, -150 - (i - 1) * 36)
    end
end

----------------------------------------------------------------------
local function Paused()
    local d = DB()
    return not d.on or IsShiftKeyDown()
end

local G = C_GossipInfo or {}

-- 대화창: 받을 퀘 / 끝난 퀘 고르기
local function OnGossip()
    if Paused() then return end
    local d = DB()
    -- 끝난 퀘스트 먼저
    if d.complete then
        if G.GetActiveQuests then
            for _, q in ipairs(G.GetActiveQuests() or {}) do
                if q.isComplete and q.questID then G.SelectActiveQuest(q.questID) return end
            end
        end
    end
    if d.accept then
        if G.GetAvailableQuests then
            for _, q in ipairs(G.GetAvailableQuests() or {}) do
                if q.questID and not (d.skipTrivial and q.isTrivial) then
                    G.SelectAvailableQuest(q.questID) return
                end
            end
        end
    end
    -- 퀘스트가 하나도 없고 대화가 하나뿐이면 넘기기 (기본 꺼짐)
    if d.gossip and G.GetOptions then
        local av = G.GetAvailableQuests and #(G.GetAvailableQuests() or {}) or 0
        local ac = G.GetActiveQuests and #(G.GetActiveQuests() or {}) or 0
        local opts = G.GetOptions() or {}
        if av == 0 and ac == 0 and #opts == 1 and opts[1].gossipOptionID and G.SelectOption then
            G.SelectOption(opts[1].gossipOptionID)
        end
    end
end

-- 옛날식 퀘스트 인사창 (퀘스트가 여러 개인 NPC)
local function OnGreeting()
    if Paused() then return end
    local d = DB()
    if d.complete then
        for i = 1, (GetNumActiveQuests() or 0) do
            local _, done = GetActiveTitle(i)
            if done then SelectActiveQuest(i) return end
        end
    end
    if d.accept then
        for i = 1, (GetNumAvailableQuests() or 0) do
            local trivial = IsAvailableQuestTrivial and IsAvailableQuestTrivial(i)
            if not (d.skipTrivial and trivial) then SelectAvailableQuest(i) return end
        end
    end
end

-- 받기는 여기서, '퀘스트 받음' 알림은 진짜로 받아졌을 때(QUEST_ACCEPTED) 한 번만
local lastDetail, lastDetailAt = nil, 0
local function OnDetail()
    if Paused() or not DB().accept then return end
    local title = GetTitleText and GetTitleText()
    -- 같은 퀘 창이 연달아 다시 열리면 (다른 자동 수락 애드온, 대화창 되돌아옴) 한 번만 받기
    if title and title == lastDetail and GetTime() - lastDetailAt < 3 then return end
    lastDetail, lastDetailAt = title, GetTime()
    if QuestGetAutoAccept and QuestGetAutoAccept() then
        if AcknowledgeAutoAcceptQuest then AcknowledgeAutoAcceptQuest() end
    else
        AcceptQuest()
    end
end

local toasted = {}
local function OnAccepted(a1, a2)
    if not DB().on then return end
    -- 버전에 따라 (questID) 또는 (퀘스트 번호, questID)
    local qid = a2 or a1
    if type(qid) ~= "number" then return end
    if toasted[qid] and GetTime() - toasted[qid] < 10 then return end
    toasted[qid] = GetTime()
    local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qid)
    if not title or title == "" then title = lastDetail end
    if title then ns.PillToast("퀘스트 받음  |cff9fe3a8" .. title .. "|r", "hb_quest") end
end

local function OnProgress()
    if Paused() or not DB().complete then return end
    if IsQuestCompletable() then CompleteQuest() end
end

----------------------------------------------------------------------
-- 보상: 고를 게 없으면 받기, 있으면 가장 비싼 것에 분홍 표시만
----------------------------------------------------------------------
local mark
local function ChoiceButton(i)
    local rf = _G.QuestInfoRewardsFrame
    if rf and rf.RewardButtons and rf.RewardButtons[i] then return rf.RewardButtons[i] end
    return _G["QuestInfoRewardsFrameQuestInfoItem" .. i] or _G["QuestInfoItem" .. i]
end

local function MarkBest()
    if mark then mark:Hide() end
    if not DB().best then return end
    local n = GetNumQuestChoices() or 0
    if n < 2 then return end
    local best, bestPrice = nil, 0
    for i = 1, n do
        local link = GetQuestItemLink("choice", i)
        local _, _, _, _, _, _, _, _, _, _, price = GetItemInfo(link or "")
        local _, _, count = GetQuestItemInfo("choice", i)
        price = (price or 0) * math.max(1, count or 1)
        if price > bestPrice then best, bestPrice = i, price end
    end
    local btn = best and ChoiceButton(best)
    if not btn then return end
    if not mark then
        -- A안: 둥근 분홍 테 (모서리는 원 테두리 그림 4조각 + 2px 선) + 위에 값 알약
        mark = CreateFrame("Frame", nil, UIParent)
        mark:SetFrameStrata("DIALOG")
        local R, T = 10, 2
        local PK = C.acc
        local function corner(point, l, r, t, b)
            local c = mark:CreateTexture(nil, "OVERLAY")
            c:SetTexture(ns.MEDIA .. "ring")
            c:SetTexCoord(l, r, t, b)
            c:SetSize(R, R)
            c:SetPoint(point)
            c:SetVertexColor(PK[1], PK[2], PK[3], 1)
        end
        corner("TOPLEFT", 0, 0.5, 0, 0.5); corner("TOPRIGHT", 0.5, 1, 0, 0.5)
        corner("BOTTOMLEFT", 0, 0.5, 0.5, 1); corner("BOTTOMRIGHT", 0.5, 1, 0.5, 1)
        local function line(p1, p2, horiz)
            local e = mark:CreateTexture(nil, "OVERLAY")
            e:SetColorTexture(PK[1], PK[2], PK[3], 1)
            if horiz then
                e:SetPoint(p1 .. "LEFT", R, 0); e:SetPoint(p1 .. "RIGHT", -R, 0); e:SetHeight(T)
            else
                e:SetPoint("TOP" .. p1, 0, -R); e:SetPoint("BOTTOM" .. p1, 0, R); e:SetWidth(T)
            end
        end
        line("TOP", nil, true); line("BOTTOM", nil, true); line("LEFT"); line("RIGHT")

        -- 값 알약: 토끼 금화 + 가장 비싸요 · 값
        local tag = CreateFrame("Frame", nil, mark)
        tag:SetHeight(20)
        tag:SetPoint("BOTTOM", mark, "TOP", 0, -4)
        tag:SetFrameLevel(mark:GetFrameLevel() + 2)
        ns.RoundPlate(tag, 10, { 0.125, 0.094, 0.086, 0.97 }, { PK[1], PK[2], PK[3], 1 })
        local coin = tag:CreateTexture(nil, "ARTWORK")
        coin:SetTexture(ns.MEDIA .. "coin_g"); coin:SetSize(16, 16); coin:SetPoint("LEFT", 3, 0)
        local fs = ns.Font(tag, 11, { 1, 0.84, 0.87 })
        fs:SetPoint("LEFT", coin, "RIGHT", 4, 0)
        mark.tag, mark.fs = tag, fs
    end
    mark:SetParent(btn)
    mark:SetFrameLevel(btn:GetFrameLevel() + 5)
    mark:ClearAllPoints()
    mark:SetPoint("TOPLEFT", btn, "TOPLEFT", -4, 4)
    mark:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 4, -4)
    local money = ns.BunnyMoney and ns.BunnyMoney(bestPrice, 11) or GetCoinTextureString(bestPrice)
    mark.fs:SetText("가장 비싸요  |cff9a8a86·|r  |cffffffff" .. money .. "|r")
    mark.tag:SetWidth(mark.fs:GetStringWidth() + 32)
    mark:Show()
end

local function OnComplete()
    MarkBest()
    if Paused() or not DB().complete then return end
    local n = GetNumQuestChoices() or 0
    if n <= 1 then
        GetQuestReward(n == 1 and 1 or nil)
    end
end

local function OnTurnedIn(questID, xp)
    if not DB().on then return end
    local title = (C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)) or ""
    local msg = "퀘스트 완료"
    if title ~= "" then msg = msg .. "  " .. title end
    if xp and xp > 0 then msg = msg .. "  |cff9fe3a8+" .. (BreakUpLargeNumbers and BreakUpLargeNumbers(xp) or xp) .. " 경험치|r" end
    ns.PillToast(msg, "hb_quest")
end

----------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS",
                     "QUEST_COMPLETE", "QUEST_TURNED_IN", "QUEST_FINISHED", "QUEST_ACCEPTED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, a1, a2)
    if not ns.db then return end
    if event == "GOSSIP_SHOW" then OnGossip()
    elseif event == "QUEST_GREETING" then OnGreeting()
    elseif event == "QUEST_DETAIL" then OnDetail()
    elseif event == "QUEST_PROGRESS" then OnProgress()
    elseif event == "QUEST_COMPLETE" then OnComplete()
    elseif event == "QUEST_TURNED_IN" then OnTurnedIn(a1, a2)
    elseif event == "QUEST_ACCEPTED" then OnAccepted(a1, a2)
    elseif event == "QUEST_FINISHED" then if mark then mark:Hide() end
    end
end)
