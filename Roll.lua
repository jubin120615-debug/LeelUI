-- LeelUI / Roll.lua
-- 르엘 주사위 창 (A+B+C): 파티에서 템이 나오면 뜨는 입찰 · 차비 · 포기 창
--   A 둥근 카드: 아이콘 둘레 등급 색 · 분홍 주사위 / 금화 / X 단추 · 분홍 시간 막대
--   B 결과 보드: 누른 템은 카드가 펼쳐져 파티원 주사위가 실시간으로 (채팅 글을 읽어서)
--   C 토끼 추천: 장비 비교(Gear.lua) 역할 기준으로 "입찰 추천 / 차비 추천" 단추가 빛나요
--      대신 눌러 주는 일은 없어요. "추천대로 모두 누르기"도 내가 눌러야만
-- 끄면 블리자드 기본 창이 그대로 나와요 (허브 > 파티·전투 > 주사위 창)

local _, ns = ...
local C = ns.C

local function DB()
    ns.db.roll = ns.db.roll or {}
    local d = ns.db.roll
    if d.on == nil then d.on = true end
    if d.rec == nil then d.rec = true end
    if d.board == nil then d.board = "mine" end   -- "off" | "mine" | "all"
    if d.greet == nil then d.greet = "all" end    -- 파티 인사 말풍선: "off" | "short" | "all"
    if d.hideWon == nil then d.hideWon = true end -- 블리자드 "다음을 획득했습니다" 알림 숨기기 (르엘 획득 알림과 겹쳐서)
    return d
end
ns.RollDB = DB

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
local W, PADX = 230, 8   -- 아코디언 폭 (티켓이 너무 길지 않게)
local CARD_H, PILL_H = 92, 30   -- 접힌 줄 높이
local PW = (W - 6) / 2   -- 접힌 반쪽 알약 폭
local PINK, GOLD, GREY = { 1, 0.561, 0.639 }, { 0.953, 0.773, 0.353 }, { 0.29, 0.227, 0.216 }
local TXT_UP, TXT_SIDE, TXT_NO = { 0.56, 0.91, 0.60 }, { 0.953, 0.773, 0.353 }, { 1, 0.60, 0.66 }

local function QColor(q)
    local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return { c.r, c.g, c.b } end
    return { 1, 1, 1 }
end
-- 이름만: "이름-서버" / 와우 포에버 채팅의 "이름 길드" 꼴도 앞 이름만 (와우 이름엔 띄어쓰기가 없어요)
local function Short(name) return name and (name:gsub("%-.*$", ""):gsub("%s.*$", "")) or "" end
local function ItemID(link) return link and tonumber(link:match("item:(%d+)")) end
local function P(m) print("|cfff2b3c2[르엘 주사위]|r " .. m) end

----------------------------------------------------------------------
-- 내 특성 · 역할 이름 ("야성 드루이드 기준 · 근접 딜")
----------------------------------------------------------------------
local function SpecName()
    if not (GetNumTalentTabs and GetTalentTabInfo) then return end
    local best, bp
    for i = 1, (GetNumTalentTabs() or 0) do
        local ok, a, b, c, d = pcall(GetTalentTabInfo, i)
        if ok then
            local name = (type(a) == "string" and a) or (type(b) == "string" and b) or nil
            local pts = (type(c) == "number" and c) or (type(d) == "number" and d) or 0
            for _, v in ipairs({ a, b, c, d }) do if type(v) == "number" and v > pts and v < 100 then pts = v end end
            if name and (not bp or pts > bp) then best, bp = name, pts end
        end
    end
    if bp and bp > 0 then return best end
end
local function BasisText()
    local cls = UnitClass("player") or ""
    local spec = SpecName()
    local role = ns.GearRole and ns.GearRoleName and ns.GearRoleName[ns.GearRole()]
    local auto = not (ns.GearDB and ns.GearDB().role)
    local t = (spec and (spec .. " ") or "") .. cls .. " 기준"
    if role then t = t .. " · " .. role .. (auto and "" or " (직접 고름)") end
    return t
end

----------------------------------------------------------------------
-- 토끼 추천: "need" | "greed" | nil, 색, 이유 한 줄
----------------------------------------------------------------------
-- 주 방어구 (이보다 가벼운 갑옷은 다른 사람 몫으로 차비)
local MAIN_ARMOR = { WARRIOR = 4, PALADIN = 4, HUNTER = 3, SHAMAN = 3, ROGUE = 2, DRUID = 2, PRIEST = 1, MAGE = 1, WARLOCK = 1 }
local ARMOR_NAME = { [1] = "천", [2] = "가죽", [3] = "사슬", [4] = "판금" }
local ARMOR_SLOT = { INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true, INVTYPE_ROBE = true, INVTYPE_WAIST = true,
    INVTYPE_LEGS = true, INVTYPE_FEET = true, INVTYPE_WRIST = true, INVTYPE_HAND = true }

local function Gains(res, n)
    local names = ns.GearStatName or {}
    local out = {}
    for i = 1, math.min(n or 2, #(res.gains or {})) do
        local g = res.gains[i]
        local v = g.d
        local num = (math.abs(v - math.floor(v + 0.5)) < 0.05) and string.format("%d", math.floor(v + 0.5)) or string.format("%.1f", v)
        out[#out + 1] = (names[g.k] or g.k) .. " +" .. num
    end
    return table.concat(out, " · ")
end

local function RecommendBase(e)
    if not DB().rec then return end
    if e.canNeed == false then return "greed", TXT_NO, "● 입찰할 수 없는 템이에요", true end
    local res = ns.GearJudge and e.link and ns.GearJudge(e.link)
    if not res then return end                        -- 재료 · 퀘템 · 가방 같은 건 추천 없음
    local slotName = res.slot and ns.GearSlotName and ns.GearSlotName[res.slot] or "장비"
    -- "지금 낀 손 장비가" 처럼 자연스럽게 + 받침에 맞는 조사
    local KEEP = { ["반지"] = true, ["장신구"] = true, ["망토"] = true, ["무기"] = true, ["장비"] = true }
    local word = KEEP[slotName] and slotName or (slotName == "원거리" and "원거리 무기" or (slotName .. " 장비"))
    local function J(w, a, b)
        local b1, b2, b3 = w:byte(-3, -1)
        if b1 and b1 >= 0xEA and b1 <= 0xED then
            local code = ((b1 % 16) * 4096) + ((b2 % 64) * 64) + (b3 % 64)
            if code >= 0xAC00 and code <= 0xD7A3 then return w .. (((code - 0xAC00) % 28 ~= 0) and a or b) end
        end
        return w .. a
    end
    if res.kind == "cant" then
        return "greed", TXT_NO, "● 못 껴요" .. (res.reason and (" · " .. res.reason) or ""), true
    end
    -- 주 방어구가 아니면 (전사가 가죽 등) 차비
    if GetItemInfoInstant then
        local ok, _, _, _, equipLoc, _, classID, subID = pcall(GetItemInfoInstant, e.link)
        local _, cls = UnitClass("player")
        local main = MAIN_ARMOR[cls]
        if ok and classID == 4 and ARMOR_SLOT[equipLoc] and main and subID and subID >= 1 and subID <= 4 then
            if main >= 3 and (UnitLevel("player") or 60) < 40 then main = main - 1 end   -- 사슬 · 판금은 40레벨부터
            if subID < main then
                return "greed", TXT_SIDE, "● " .. (ARMOR_NAME[subID] or "") .. "은 주 방어구가 아니에요", true
            end
        end
    end
    if res.kind == "empty" then return "need", TXT_UP, "▲ " .. slotName .. " 칸이 비어 있어요 · 바로 끼자" end
    if res.kind == "twohand" then return nil, TXT_SIDE, "● 양손 무기를 들고 있어 비교가 어려워요" end
    local role = ns.GearRoleName and ns.GearRole and ns.GearRoleName[ns.GearRole()] or "내 역할"
    if #(res.gains or {}) == 0 and (res.new or 0) <= 0.5 then
        return "greed", TXT_SIDE, "● " .. role .. "에겐 쓸 능력치가 없어요", true
    end
    if res.kind == "up" then
        local g = Gains(res, 2)
        return "need", TXT_UP, "▲ 지금 낀 " .. word .. "보다 좋아요" .. (g ~= "" and (" · " .. g) or "")
    elseif res.kind == "down" then
        return "greed", TXT_SIDE, "● 지금 낀 " .. J(word, "이", "가") .. " 더 좋아요"
    end
    return nil, TXT_SIDE, "● 지금 낀 " .. J(word, "과", "와") .. " 비슷해요 · 취향대로"
end

----------------------------------------------------------------------
-- 파티원 배려: 이 템이 더 맞는 파티원이 있으면 알려주고 차비 쪽으로
----------------------------------------------------------------------
-- 무기 · 방어구를 쓸 수 있는 직업 (클래식)
local WEAPON_OK = {
    WARRIOR = { [0]=1,[1]=1,[2]=1,[3]=1,[4]=1,[5]=1,[6]=1,[7]=1,[8]=1,[10]=1,[13]=1,[15]=1,[16]=1,[18]=1 },
    PALADIN = { [0]=1,[1]=1,[4]=1,[5]=1,[6]=1,[7]=1,[8]=1 },
    HUNTER  = { [0]=1,[1]=1,[2]=1,[3]=1,[6]=1,[7]=1,[8]=1,[10]=1,[13]=1,[15]=1,[16]=1,[18]=1 },
    ROGUE   = { [2]=1,[3]=1,[4]=1,[7]=1,[13]=1,[15]=1,[16]=1,[18]=1 },
    PRIEST  = { [4]=1,[10]=1,[15]=1,[19]=1 },
    SHAMAN  = { [0]=1,[1]=1,[4]=1,[5]=1,[10]=1,[13]=1,[15]=1 },
    MAGE    = { [7]=1,[10]=1,[15]=1,[19]=1 },
    WARLOCK = { [7]=1,[10]=1,[15]=1,[19]=1 },
    DRUID   = { [4]=1,[5]=1,[10]=1,[13]=1,[15]=1 },
}
local SHIELD_OK = { WARRIOR = true, PALADIN = true, SHAMAN = true }
-- 능력치 묶음별로 "제일 잘 맞는(2) / 쓸 수는 있는(1)" 직업
local FIT = {
    agi  = { ROGUE = 2, HUNTER = 2, DRUID = 1, SHAMAN = 1, WARRIOR = 1 },
    str  = { WARRIOR = 2, PALADIN = 2, SHAMAN = 1, DRUID = 1 },
    cast = { MAGE = 2, WARLOCK = 2, PRIEST = 2, SHAMAN = 1, DRUID = 1, PALADIN = 1 },
    heal = { PRIEST = 2, DRUID = 2, SHAMAN = 2, PALADIN = 2 },
    tank = { WARRIOR = 2, PALADIN = 1, DRUID = 1 },
}
local function Family(link)
    local get = (C_Item and C_Item.GetItemStats) or GetItemStats
    local ok, t = pcall(get, link)
    if not (ok and type(t) == "table") then return end
    local v = function(k) return tonumber(t[k]) or 0 end
    local agi, str = v("ITEM_MOD_AGILITY_SHORT"), v("ITEM_MOD_STRENGTH_SHORT")
    local int, spi = v("ITEM_MOD_INTELLECT_SHORT"), v("ITEM_MOD_SPIRIT_SHORT")
    local sp, heal = v("ITEM_MOD_SPELL_POWER_SHORT") + v("ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"), v("ITEM_MOD_SPELL_HEALING_DONE_SHORT")
    local def = v("ITEM_MOD_DEFENSE_SKILL_RATING_SHORT") + v("ITEM_MOD_BLOCK_VALUE_SHORT") + v("ITEM_MOD_PARRY_RATING_SHORT")
    local caster = int + sp
    if heal > 0 or (spi > int and spi > 0 and agi + str == 0) then return "heal" end
    if def > 0 and def >= agi and def >= str then return "tank" end
    if agi > 0 and agi >= str and agi >= caster then return "agi" end
    if str > 0 and str >= caster then return "str" end
    if caster > 0 then return "cast" end
end
-- 그 직업 · 레벨이 이 템을 얼마나 원할까 (0 = 못 써요 · 안 맞아요)
local function FitOf(cls, lvl, link)
    if not (cls and link and GetItemInfoInstant) then return 0 end
    local ok, _, _, _, loc, _, classID, subID = pcall(GetItemInfoInstant, link)
    if not ok then return 0 end
    if classID == 2 then
        if not (WEAPON_OK[cls] and WEAPON_OK[cls][subID]) then return 0 end
    elseif classID == 4 then
        if subID == 6 then if not SHIELD_OK[cls] then return 0 end
        elseif ARMOR_SLOT[loc] and subID and subID >= 1 and subID <= 4 then
            local main = MAIN_ARMOR[cls] or 1
            if main >= 3 and (lvl or 60) < 40 then main = main - 1 end
            if subID > main or subID < main then return 0 end    -- 못 입거나 주 방어구가 아님
        end
    end
    local fam = Family(link)
    if not fam then return 1 end                                  -- 능력치 없는 템: 누구나 비슷
    return (FIT[fam] and FIT[fam][cls]) or 0
end
-- 파티원 중 이 템이 맞는 사람들 (나 빼고)
local function PartyFits(link)
    local out = {}
    local units = {}
    if IsInRaid and IsInRaid() then for i = 1, 40 do units[#units + 1] = "raid" .. i end
    else for i = 1, 4 do units[#units + 1] = "party" .. i end end
    for _, u in ipairs(units) do
        if UnitExists(u) and not UnitIsUnit(u, "player") then
            local _, cls = UnitClass(u)
            local f = FitOf(cls, UnitLevel(u), link)
            if f > 0 then
                local n = UnitName(u)
                if n and not (ns.IsSecret and ns.IsSecret(n)) then
                    out[#out + 1] = { name = Short(n), cls = cls, clsName = (UnitClass(u)), fit = f }
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.fit > b.fit end)
    return out
end
ns.RollPartyFits = PartyFits

-- 누구 몫인지: "천 장비 · 법사 · 사제 · 흑마법사 몫"
local CLS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local function WhoseText(link)
    local names = {}
    for want = 2, 1, -1 do
        for _, c in ipairs(CLS_ORDER) do
            if FitOf(c, 60, link) == want then names[#names + 1] = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c]) or c end
        end
        if #names > 0 then break end
    end
    local pre = ""
    if GetItemInfoInstant then
        local ok, _, _, _, loc, _, classID, subID = pcall(GetItemInfoInstant, link)
        if ok and classID == 4 and ARMOR_SLOT[loc] and ARMOR_NAME[subID] then pre = ARMOR_NAME[subID] .. " 장비 · " end
    end
    if #names == 0 then return pre ~= "" and (pre .. "다른 사람 몫") or nil end
    if #names > 3 then names = { names[1], names[2], names[3] } end
    return pre .. table.concat(names, " · ") .. " 몫"
end

local function Recommend(e)
    local rec, col, why, notMine = RecommendBase(e)
    e.party, e.notMine, e.whose = nil, nil, nil
    if not DB().rec or not e.link then return rec, col, why end
    local fits = (not e.test) and PartyFits(e.link) or {}
    if #fits > 0 then
        local names = {}
        for i = 1, math.min(2, #fits) do names[#names + 1] = fits[i].name .. "(" .. fits[i].clsName .. ")" end
        e.party = table.concat(names, ", ") .. (#fits > 2 and (" 외 " .. (#fits - 2) .. "명") or "")
        local _, myCls = UnitClass("player")
        local mine = FitOf(myCls, UnitLevel("player"), e.link)
        if rec == "need" and fits[1].fit > mine then
            rec, col, notMine = "greed", TXT_SIDE, true
        end
    end
    if notMine then
        e.notMine = true
        -- 파티에 맞는 사람이 있으면 그 사람 몫, 없으면 맞는 직업들
        e.whose = (#fits > 0) and (fits[1].name .. "(" .. fits[1].clsName .. ") 몫" .. (#fits > 1 and (" · 외 " .. (#fits - 1) .. "명") or "")) or WhoseText(e.link)
        -- 이유 줄은 짧은 원래 이유를 툴팁용으로 남기고, 카드엔 누구 몫인지
        e.whyLong = why
        return "greed", { 0.72, 0.65, 0.63 }, e.whose or why
    end
    return rec, col, why
end

----------------------------------------------------------------------
-- 판 · 카드
----------------------------------------------------------------------
local anchor, basis, bulk
local cards, active = {}, {}     -- active: 화면에 있는 카드 (순서)
local entries = {}               -- rollID → 자료
local test = false

-- C 젤리 유리: 둥근 판 + 윗면 하이라이트 + 아래 그림자 (게임에선 뒤 흐림이 안 돼서 반투명 색으로)
local PLUM = { 0.357, 0.165, 0.235 }
local function Jelly(fr, r)
    local j = {}
    j.glow = fr:CreateTexture(nil, "BACKGROUND", nil, -3); j.glow:SetTexture(ns.MEDIA .. "circle"); j.glow:SetBlendMode("ADD")
    j.glow:SetPoint("TOPLEFT", -5, 5); j.glow:SetPoint("BOTTOMRIGHT", 5, -5); j.glow:Hide()
    j.bg = ns.RoundRect(fr, r, { 1, 1, 1 }, "BACKGROUND", 0, 0)
    j.shade = fr:CreateTexture(nil, "BORDER"); j.shade:SetTexture(ns.WHITE)
    j.shade:SetPoint("BOTTOMLEFT", r * 0.6, 1); j.shade:SetPoint("BOTTOMRIGHT", -r * 0.6, 1); j.shade:SetHeight(math.max(3, r * 0.5))
    j.shine = fr:CreateTexture(nil, "BORDER", nil, 1); j.shine:SetTexture(ns.WHITE)
    j.shine:SetPoint("TOPLEFT", r * 0.7, -2); j.shine:SetPoint("TOPRIGHT", -r * 0.7, -2); j.shine:SetHeight(math.max(2, r * 0.35))
    function j:Set(c, a, glow)
        self.bg:SetColor(c, a)
        pcall(self.shade.SetGradient, self.shade, "VERTICAL", CreateColor(c[1] * 0.55, c[2] * 0.45, c[3] * 0.5, 0.45 * a), CreateColor(c[1], c[2], c[3], 0))
        pcall(self.shine.SetGradient, self.shine, "VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.75 * a))
        if glow then self.glow:SetVertexColor(glow[1], glow[2], glow[3], 0.32); self.glow:Show() else self.glow:Hide() end
    end
    return j
end
-- 유리판 (카드 · 반쪽 알약)
local function Glass(fr, r)
    local g = {}
    g.rim = ns.RoundRect(fr, r, { 1, 0.70, 0.77 }, "BACKGROUND", -1, -1); g.rim:SetColor({ 1, 0.70, 0.77 }, 0.55)
    g.bg = ns.RoundRect(fr, r, { 0.24, 0.13, 0.17 }, "BACKGROUND", 0, 0); g.bg:SetColor({ 0.24, 0.13, 0.17 }, 0.84)
    g.top = fr:CreateTexture(nil, "BACKGROUND", nil, 1); g.top:SetTexture(ns.WHITE)
    g.top:SetPoint("TOPLEFT", 2, -2); g.top:SetPoint("TOPRIGHT", -2, -2); g.top:SetHeight(18)
    pcall(g.top.SetGradient, g.top, "VERTICAL", CreateColor(1, 0.84, 0.89, 0), CreateColor(1, 0.84, 0.89, 0.16))
    g.line = fr:CreateTexture(nil, "BORDER"); g.line:SetTexture(ns.WHITE); g.line:SetHeight(1)
    g.line:SetPoint("TOPLEFT", r, -1); g.line:SetPoint("TOPRIGHT", -r, -1); g.line:SetVertexColor(1, 1, 1, 0.45)
    return g
end

-- B 리본 티켓: 어두운 판 + 자줏빛 테 + 왼쪽 등급 색 띠
local TK_BG, TK_RIM = { 0.165, 0.114, 0.122 }, { 0.42, 0.25, 0.28 }
local function Ticket(fr, r, stripW)
    local t = {}
    t.rim = ns.RoundRect(fr, r, TK_RIM, "BACKGROUND", -1, -1)
    t.bg = ns.RoundRect(fr, r, TK_BG, "BACKGROUND", 0, 0); t.bg:SetColor(TK_BG, 0.97)
    -- 등급 색 (C안): 왼쪽에서 은은하게 번지는 빛 + 위아래가 흐려지는 가는 줄
    t.wash = fr:CreateTexture(nil, "BORDER"); t.wash:SetTexture(ns.WHITE)
    t.wash:SetPoint("TOPLEFT", 1.5, -1.5); t.wash:SetPoint("BOTTOMLEFT", 1.5, 1.5); t.wash:SetWidth(90)
    t.strip = fr:CreateTexture(nil, "BORDER", nil, 1); t.strip:SetTexture(ns.WHITE)
    t.strip:SetPoint("TOPLEFT", 2.5, -r * 0.8); t.strip:SetPoint("BOTTOMLEFT", 2.5, r * 0.8); t.strip:SetWidth(2)
    t.strip2 = fr:CreateTexture(nil, "BORDER", nil, 1); t.strip2:SetTexture(ns.WHITE)
    t.strip2:SetPoint("BOTTOMLEFT", t.strip, "TOPLEFT", 0, 0); t.strip2:SetWidth(2); t.strip2:SetHeight(8)
    t.strip3 = fr:CreateTexture(nil, "BORDER", nil, 1); t.strip3:SetTexture(ns.WHITE)
    t.strip3:SetPoint("TOPLEFT", t.strip, "BOTTOMLEFT", 0, 0); t.strip3:SetWidth(2); t.strip3:SetHeight(8)
    -- 양옆 홈 (추첨권처럼 파인 자리)
    t.notch = {}
    for i, side in ipairs({ "LEFT", "RIGHT" }) do
        local rr = fr:CreateTexture(nil, "BORDER", nil, 2); rr:SetTexture(ns.MEDIA .. "circle")
        rr:SetSize(10, 10); rr:SetPoint("CENTER", fr, side, 0, 0); rr:SetVertexColor(TK_RIM[1], TK_RIM[2], TK_RIM[3], 1)
        local n = fr:CreateTexture(nil, "BORDER", nil, 3); n:SetTexture(ns.MEDIA .. "circle")
        n:SetSize(7, 7); n:SetPoint("CENTER", rr); n:SetVertexColor(0.137, 0.09, 0.098, 1)   -- 칸 색과 거의 같게
        t.notch[#t.notch + 1] = rr; t.notch[#t.notch + 1] = n
    end
    t.wash:SetVertexColor(1, 1, 1, 0); t.strip:SetVertexColor(1, 1, 1, 0); t.strip2:SetVertexColor(1, 1, 1, 0); t.strip3:SetVertexColor(1, 1, 1, 0)
    function t:Strip(c)
        self.strip:SetVertexColor(c[1], c[2], c[3], 0.55)
        pcall(self.strip2.SetGradient, self.strip2, "VERTICAL", CreateColor(c[1], c[2], c[3], 0.55), CreateColor(c[1], c[2], c[3], 0))
        pcall(self.strip3.SetGradient, self.strip3, "VERTICAL", CreateColor(c[1], c[2], c[3], 0), CreateColor(c[1], c[2], c[3], 0.55))
        pcall(self.wash.SetGradient, self.wash, "HORIZONTAL", CreateColor(c[1], c[2], c[3], 0.20), CreateColor(c[1], c[2], c[3], 0))
    end
    function t:Notch(on) for _, n in ipairs(self.notch) do n:SetShown(on) end end
    return t
end

local Anchor
local badge, logWin
local collapsed = false
local unlock = false
local talking = false   -- 토끼가 말풍선으로 인사하는 중 (뱃지 보이게)

----------------------------------------------------------------------
-- 토끼 뱃지: 경매 창은 여기서 튀어나오고, 누르면 기록장
--   자리 = 뱃지 가운데 (화면 기준), 경매 창은 화면 가운데 쪽으로 펼쳐져요
----------------------------------------------------------------------
local function Scale() return math.max(0.5, math.min(1.6, (DB().scale or 100) / 100)) end

function ns.RollPlace()
    local d = DB()
    local sc = Scale()
    if badge then
        badge:SetScale(sc)
        badge:ClearAllPoints()
        if d.bx and d.by then badge:SetPoint("CENTER", UIParent, "BOTTOMLEFT", d.bx / sc, d.by / sc)
        else badge:SetPoint("CENTER", UIParent, "TOPRIGHT", -150 / sc, -260 / sc) end
    end
    if anchor and badge then
        anchor:SetScale(sc)
        anchor:ClearAllPoints()
        local bx, by = badge:GetCenter()
        local W2, H2 = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
        local right = bx and (bx * sc) > W2
        local low = by and (by * sc) < H2
        local vp = low and "BOTTOM" or "TOP"
        if right then anchor:SetPoint(vp .. "RIGHT", badge, vp .. "LEFT", -10, low and -4 or 4)
        else anchor:SetPoint(vp .. "LEFT", badge, vp .. "RIGHT", 10, low and -4 or 4) end
        anchor.fromRight = right
    end
end
function ns.RollSavePos()
    if not badge then return end
    local sc = badge:GetScale()
    local x, y = badge:GetCenter()
    if not (x and y) then return end
    local d = DB()
    d.bx, d.by = x * sc, y * sc
    ns.RollPlace()
end
function ns.RollSetScale(v)
    v = math.floor(math.max(60, math.min(150, tonumber(v) or 100)) + 0.5)
    local d = DB()
    if badge and not d.bx then ns.RollSavePos() end
    d.scale = v
    ns.RollPlace()
end

local function BadgeShouldShow()
    local d = DB()
    if not d.on then return false end
    if ns.moving then return true end   -- 이동 모드: 옮기고 크기 바꾸게 보여요
    if unlock or talking or #active > 0 or d.badgeAlways then return true end
    if logWin and logWin:IsShown() then return true end
    return (IsInGroup and IsInGroup()) and true or false
end

local function PaintBadge()
    if not badge then return end
    badge:SetShown(BadgeShouldShow())
    local n, hot = 0, false
    for _, f in ipairs(active) do
        local e = f.e
        if e and not e.mine and not e.done then n = n + 1; if e.rec == "need" then hot = true end end
    end
    badge.count:SetShown(n > 0); badge.countFs:SetText(n)
    if badge.urgent and n > 0 then return end   -- 10초 남음 모션 중
    if badge.popAg and badge.popAg:IsPlaying() then return end
    if hot or unlock then badge.glow:Show(); badge.ag:Play() else badge.glow:Hide(); badge.ag:Stop() end
    if n > 0 and not badge.hopping then
        badge.hopping = true
        badge.idleAg:Stop(); badge.hopAg:Play()
    elseif n == 0 then
        badge.hopping = false; badge.hopAg:Stop()
        if not badge.idleAg:IsPlaying() then badge.idleAg:Play() end
    end
end
ns.RollPaintBadge = PaintBadge

-- 토끼 단추 옮기기: 끌어서 자유롭게 · 휠 = 크기 (이동 모드에서도 돼요)
function ns.RollUnlock(on)
    Anchor()
    unlock = on and true or false
    PaintBadge()
    if on then P("토끼 단추를 끌어서 옮겨요 (놓으면 끝). 휠 = 크기. 평소엔 파티 · 공격대에서만 보여요.") end
end

function ns.RollBadgePop()
    if not (badge and badge:IsShown()) then return end
    badge.idleAg:Stop(); badge.hopAg:Stop(); badge.hopping = false
    badge.popAg:Stop(); badge.popAg:Play(); badge.flashAg:Stop(); badge.flashAg:Play()
    C_Timer.After(0.45, function() if badge.count:IsShown() then badge.countAg:Play() end end)
    badge.popAg:SetScript("OnFinished", function() PaintBadge() end)
end

local function MakeBadge()
    if badge then return badge end
    local b = CreateFrame("Button", "LeelUI_RollBadge", UIParent)
    b:SetSize(44, 44)
    b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(20)
    b:SetMovable(true); b:SetClampedToScreen(true)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b.glow = b:CreateTexture(nil, "BACKGROUND", nil, -2)
    b.glow:SetTexture(ns.MEDIA .. "soft_glow"); b.glow:SetBlendMode("ADD")
    b.glow:SetPoint("CENTER", 0, -2); b.glow:SetSize(96, 96); b.glow:SetVertexColor(1, 0.561, 0.639, 1); b.glow:Hide()
    local ag = b.glow:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
    local al = ag:CreateAnimation("Alpha"); al:SetFromAlpha(0.2); al:SetToAlpha(0.75); al:SetDuration(0.7); al:SetSmoothing("IN_OUT")
    b.ag = ag
    -- 보물상자 토끼 그림 (테두리 · 배경 포함 한 장)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexture(ns.MEDIA .. "roll_badge_dice"); b.icon:SetSize(50, 50); b.icon:SetPoint("CENTER", 0, 0)   -- 유리 주사위 토끼
    -- 늘 은은한 뒤 빛 (유리 느낌)
    b.aura = b:CreateTexture(nil, "BACKGROUND", nil, -3); b.aura:SetTexture(ns.MEDIA .. "soft_glow"); b.aura:SetBlendMode("ADD")
    b.aura:SetPoint("CENTER", 0, -2); b.aura:SetSize(80, 80); b.aura:SetVertexColor(1, 0.561, 0.639, 0.25)
    -- 굴릴 템 수 (빨간 동그라미)
    b.count = CreateFrame("Frame", nil, b); b.count:SetSize(20, 20); b.count:SetPoint("CENTER", b, "TOPRIGHT", -4, -4)
    b.count:SetFrameLevel(b:GetFrameLevel() + 3)
    local cr = b.count:CreateTexture(nil, "ARTWORK"); cr:SetTexture(ns.MEDIA .. "circle"); cr:SetPoint("CENTER"); cr:SetSize(24, 24); cr:SetVertexColor(0.165, 0.122, 0.114)
    local cd = b.count:CreateTexture(nil, "ARTWORK", nil, 1); cd:SetTexture(ns.MEDIA .. "circle"); cd:SetAllPoints(); cd:SetVertexColor(1, 0.353, 0.431)
    b.countFs = b.count:CreateFontString(nil, "OVERLAY"); b.countFs:SetFont(ns.NUM or ns.FONT, 14, ""); b.countFs:SetPoint("CENTER", 0, 0)
    local cag = b.count:CreateAnimationGroup()
    local c1 = cag:CreateAnimation("Scale"); c1:SetScale(1.4, 1.4); c1:SetDuration(0.15); c1:SetOrder(1); c1:SetSmoothing("OUT")
    local c2 = cag:CreateAnimation("Scale"); c2:SetScale(1 / 1.4, 1 / 1.4); c2:SetDuration(0.2); c2:SetOrder(2); c2:SetSmoothing("IN")
    b.countAg = cag
    b.count:Hide()
    b.hop = b.icon
    -- 굴릴 게 있으면 콩콩
    local hag = b.icon:CreateAnimationGroup(); hag:SetLooping("REPEAT")
    local up = hag:CreateAnimation("Translation"); up:SetOffset(0, 3); up:SetDuration(0.18); up:SetOrder(1); up:SetSmoothing("OUT")
    local dn = hag:CreateAnimation("Translation"); dn:SetOffset(0, -3); dn:SetDuration(0.18); dn:SetOrder(2); dn:SetSmoothing("IN")
    local rest = hag:CreateAnimation("Alpha"); rest:SetFromAlpha(1); rest:SetToAlpha(1); rest:SetDuration(1.2); rest:SetOrder(3)
    b.hopAg = hag
    -- 평소: 4초마다 살짝 콩 + 기울기 (숨 쉬듯)
    -- 평소: 3초마다 살짝 떠올랐다 내려오기 (숨쉬기)
    local iag = b.icon:CreateAnimationGroup(); iag:SetLooping("REPEAT")
    local i1 = iag:CreateAnimation("Translation"); i1:SetOffset(0, 4); i1:SetDuration(1.5); i1:SetOrder(1); i1:SetSmoothing("IN_OUT")
    local i2 = iag:CreateAnimation("Translation"); i2:SetOffset(0, -4); i2:SetDuration(1.5); i2:SetOrder(2); i2:SetSmoothing("IN_OUT")
    b.idleAg = iag
    -- 템이 나왔을 때: 폴짝 뛰며 한 바퀴 + 뒤 빛 퍼짐 + 숫자 톡
    local pag = b.icon:CreateAnimationGroup()
    local p1 = pag:CreateAnimation("Translation"); p1:SetOffset(0, 14); p1:SetDuration(0.22); p1:SetOrder(1); p1:SetSmoothing("OUT")
    local pr1 = pag:CreateAnimation("Rotation"); pr1:SetDegrees(-180); pr1:SetDuration(0.22); pr1:SetOrder(1)
    local p2 = pag:CreateAnimation("Translation"); p2:SetOffset(0, -14); p2:SetDuration(0.22); p2:SetOrder(2); p2:SetSmoothing("IN")
    local pr2 = pag:CreateAnimation("Rotation"); pr2:SetDegrees(-180); pr2:SetDuration(0.22); pr2:SetOrder(2)
    local p3 = pag:CreateAnimation("Translation"); p3:SetOffset(0, 4); p3:SetDuration(0.1); p3:SetOrder(3); p3:SetSmoothing("OUT")
    local p4 = pag:CreateAnimation("Translation"); p4:SetOffset(0, -4); p4:SetDuration(0.1); p4:SetOrder(4); p4:SetSmoothing("IN")
    b.popAg = pag
    local fl = b:CreateTexture(nil, "BACKGROUND", nil, -1); fl:SetTexture(ns.MEDIA .. "soft_glow"); fl:SetBlendMode("ADD")
    fl:SetPoint("CENTER", 0, -2); fl:SetSize(110, 110); fl:SetVertexColor(1, 0.7, 0.78, 1); fl:SetAlpha(0)
    local fag = fl:CreateAnimationGroup()
    local fa1 = fag:CreateAnimation("Alpha"); fa1:SetFromAlpha(0); fa1:SetToAlpha(1); fa1:SetDuration(0.25); fa1:SetOrder(1)
    local fa2 = fag:CreateAnimation("Alpha"); fa2:SetFromAlpha(1); fa2:SetToAlpha(0); fa2:SetDuration(0.6); fa2:SetOrder(2)
    b.flashAg = fag
    -- 10초 남음: 부르르 떨기
    local sag = b.icon:CreateAnimationGroup(); sag:SetLooping("REPEAT")
    local s1 = sag:CreateAnimation("Translation"); s1:SetOffset(-2.5, 0); s1:SetDuration(0.05); s1:SetOrder(1)
    local s2 = sag:CreateAnimation("Translation"); s2:SetOffset(5, 0); s2:SetDuration(0.1); s2:SetOrder(2)
    local s3 = sag:CreateAnimation("Translation"); s3:SetOffset(-2.5, 0); s3:SetDuration(0.05); s3:SetOrder(3)
    local s4 = sag:CreateAnimation("Alpha"); s4:SetFromAlpha(1); s4:SetToAlpha(1); s4:SetDuration(0.2); s4:SetOrder(4)
    b.shakeAg = sag
    -- 반짝이 둘 (상자 위 · 오른쪽), 번갈아 반짝
    b.sparks = {}
    for i, pt in ipairs({ { 14, 12, 12, 0 }, { -15, 6, 9, 1.3 } }) do
        local sp = b:CreateTexture(nil, "OVERLAY")
        sp:SetTexture(ns.MEDIA .. "fx_star"); sp:SetBlendMode("ADD")
        sp:SetSize(pt[3], pt[3]); sp:SetPoint("CENTER", pt[1], pt[2]); sp:SetVertexColor(1, 0.95, 0.75); sp:SetAlpha(0)
        local sg = sp:CreateAnimationGroup(); sg:SetLooping("REPEAT")
        local d0 = sg:CreateAnimation("Alpha"); d0:SetFromAlpha(0); d0:SetToAlpha(0); d0:SetDuration(1.4 + pt[4]); d0:SetOrder(1)
        local a1 = sg:CreateAnimation("Alpha"); a1:SetFromAlpha(0); a1:SetToAlpha(1); a1:SetDuration(0.25); a1:SetOrder(2)
        local sc1 = sg:CreateAnimation("Scale"); sc1:SetDuration(0.5); sc1:SetOrder(2)
        if sc1.SetScaleFrom then sc1:SetScaleFrom(0.4, 0.4); sc1:SetScaleTo(1.2, 1.2) end
        local rt = sg:CreateAnimation("Rotation"); rt:SetDegrees(90); rt:SetDuration(0.5); rt:SetOrder(2)
        local a2 = sg:CreateAnimation("Alpha"); a2:SetFromAlpha(1); a2:SetToAlpha(0); a2:SetDuration(0.3); a2:SetOrder(3)
        sg:Play()
        b.sparks[i] = sp
    end
    -- 마우스 올리면 살짝 커지기 (부드럽게)
    b.size, b.target = 50, 50
    b:SetScript("OnUpdate", function(s2, el)
        -- 10초 남은 템이 있으면: 뒤 빛 빨강 깜빡 + 부르르
        s2.uT = (s2.uT or 0) + el
        if s2.uT > 0.25 then
            s2.uT = 0
            local urgent = false
            for _, f in ipairs(active) do
                local e = f.e
                if e and not e.mine and not e.done then
                    local left
                    if e.test then left = (e.endAt - GetTime()) * 1000 elseif GetLootRollTimeLeft then left = tonumber(GetLootRollTimeLeft(e.id)) end
                    if left and left > 0 and left <= 10000 then urgent = true break end
                end
            end
            if urgent ~= s2.urgent then
                s2.urgent = urgent
                if urgent then
                    s2.glow:SetVertexColor(1, 0.25, 0.35, 1); s2.glow:Show(); s2.ag:Play()
                    s2.hopAg:Stop(); s2.hopping = false; s2.shakeAg:Play()
                else
                    s2.glow:SetVertexColor(1, 0.561, 0.639, 1); s2.shakeAg:Stop(); PaintBadge()
                end
            end
        end
        if math.abs(s2.size - s2.target) < 0.2 then return end
        s2.size = s2.size + (s2.target - s2.size) * math.min(1, el * 14)
        s2.icon:SetSize(s2.size, s2.size)
    end)
    iag:Play()
    -- 끌기 = 옮기기 · 휠 = 크기 (예전처럼 자유롭게 · Shift + 휠은 언제나)
    b:SetScript("OnDragStart", function(s) s:StartMoving() end)
    b:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); ns.RollSavePos(); if unlock then ns.RollUnlock(false) end end)
    b:EnableMouseWheel(true)
    b:SetScript("OnMouseWheel", function(_, d)
        if unlock or IsShiftKeyDown() then ns.RollSetScale((DB().scale or 100) + d * 5) end
    end)
    b:SetScript("OnClick", function(_, btn)
        if ns.RollGreetHide then ns.RollGreetHide() end
        if btn == "RightButton" then
            if unlock then ns.RollUnlock(false); return end
            collapsed = not collapsed
            ns.RollRelayout()
        else
            if ns.RollFan then ns.RollFan() end
        end
    end)
    b:SetScript("OnEnter", function(s)
        s.target = 56
        s.icon:SetRotation(math.rad(8)); s.aura:SetVertexColor(1, 0.561, 0.639, 0.6)   -- 마우스: 살짝 기울고 뒤 빛 밝게
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cfff2b3c2르엘 주사위|r")
        GameTooltip:AddLine("클릭: 기록장 · 블랙리스트 · 미리 보기 · 설정", 0.85, 0.78, 0.76)
        GameTooltip:AddLine("오른쪽 클릭: 경매 창 접기 · 펴기", 0.85, 0.78, 0.76)
        GameTooltip:AddLine("끌기: 옮기기 · Shift + 휠: 크기 (" .. (DB().scale or 100) .. "%)", 0.85, 0.78, 0.76)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(s) s.target = 50; s.icon:SetRotation(0); s.aura:SetVertexColor(1, 0.561, 0.639, 0.25); GameTooltip:Hide() end)
    b:SetScript("OnMouseDown", function(s) s.target = 46 end)
    b:SetScript("OnMouseUp", function(s) s.target = s:IsMouseOver() and 56 or 50 end)
    badge = b
    ns.RollPlace()
    -- 이동 모드 테두리: 끌기 = 옮기기 · 누르면 크기 줄 · 휠 = 크기
    local m = CreateFrame("Frame", nil, b)
    m:SetPoint("TOPLEFT", -8, 8); m:SetPoint("BOTTOMRIGHT", 8, -8)
    m:SetFrameStrata("DIALOG")
    m:EnableMouse(true); m:RegisterForDrag("LeftButton")
    local tint = m:CreateTexture(nil, "BACKGROUND"); tint:SetAllPoints(); tint:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 0.12)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = m:CreateTexture(nil, "BORDER")
        e:SetColorTexture(C.acc[1], C.acc[2], C.acc[3], 1)
        if side == "TOP" or side == "BOTTOM" then e:SetPoint(side .. "LEFT"); e:SetPoint(side .. "RIGHT"); e:SetHeight(2)
        else e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side); e:SetWidth(2) end
    end
    local lab = ns.Font(m, 12, C.accHi); lab:SetPoint("BOTTOM", m, "TOP", 0, 4); lab:SetText("주사위 토끼")
    m:SetScript("OnDragStart", function() if not InCombatLockdown() then b:StartMoving() end end)
    m:SetScript("OnDragStop", function() b:StopMovingOrSizing(); ns.RollSavePos() end)
    -- 이동 모드 목록 · 테두리에서는 빼요 (토끼는 언제든 끌기 = 옮기기 · Shift + 휠 = 크기)
    m:Hide()
    b.mover = m; ns.RollMover = m
    return b
end
-- 이동 모드가 켜지고 꺼질 때: 토끼 단추 보이기 + 테두리
if ns.SetMoveMode then
    hooksecurefunc(ns, "SetMoveMode", function()
        if ns.moving and DB().on and not badge then MakeBadge() end
        if not badge then return end
        PaintBadge()
        badge.mover:Hide()
    end)
end

Anchor = function()
    if anchor then return anchor end
    MakeBadge()
    anchor = CreateFrame("Frame", "LeelUI_RollAnchor", UIParent)
    anchor:SetSize(W, 20)
    anchor:SetFrameStrata("DIALOG")
    anchor:Hide()
    -- 뱃지에서 튀어나오기
    local pop = anchor:CreateAnimationGroup()
    local sa = pop:CreateAnimation("Scale"); sa:SetDuration(0.18); sa:SetSmoothing("OUT")
    if sa.SetScaleFrom then sa:SetScaleFrom(0.4, 0.4); sa:SetScaleTo(1, 1) else sa:SetFromScale(0.4, 0.4); sa:SetToScale(1, 1) end
    local fa = pop:CreateAnimation("Alpha"); fa:SetFromAlpha(0); fa:SetToAlpha(1); fa:SetDuration(0.15)
    anchor.pop, anchor.popScale = pop, sa
    ns.RollPlace()
    -- 기준 알약: "야성 드루이드 기준 · 근접 딜"
    basis = CreateFrame("Frame", nil, anchor)
    basis:SetHeight(20)
    basis:SetPoint("BOTTOM", anchor, "BOTTOM", 0, 0)
    basis.bg = ns.RoundRect(basis, 10, { 0.165, 0.122, 0.114 }, "BACKGROUND", 0, 0)
    basis.bg:SetColor({ 0.165, 0.122, 0.114 }, 0.95)
    basis.fs = ns.Font(basis, 11, { 1, 0.70, 0.48 })
    basis.fs:SetPoint("CENTER", 0, 0)
    -- 여러 개일 때 아래 단추 줄
    bulk = CreateFrame("Frame", nil, anchor)
    bulk:SetSize(W, 26)
    bulk:Hide()
    local function Pill(text, col, fn)
        local b = CreateFrame("Button", nil, bulk)
        b:SetHeight(20)
        local gold = col == GOLD
        -- 유리 미니멀: 글자 + 밑줄만
        b.fs = ns.Font(b, 11, gold and GOLD or { 0.85, 0.80, 0.78 }); b.fs:SetPoint("CENTER", 0, 1)
        b.fs:SetText(text); b:SetWidth(b.fs:GetStringWidth() + 8)
        b.ul = b:CreateTexture(nil, "ARTWORK"); b.ul:SetTexture(ns.WHITE); b.ul:SetHeight(1.5)
        b.ul:SetPoint("BOTTOMLEFT", 4, 1); b.ul:SetPoint("BOTTOMRIGHT", -4, 1)
        local uc = gold and GOLD or { 1, 1, 1 }
        b.ul:SetVertexColor(uc[1], uc[2], uc[3], gold and 1 or 0.3)
        b:SetScript("OnClick", fn)
        b:SetScript("OnEnter", function() b.ul:SetVertexColor(uc[1], uc[2], uc[3], 1) end)
        b:SetScript("OnLeave", function() b.ul:SetVertexColor(uc[1], uc[2], uc[3], gold and 1 or 0.3) end)
        return b
    end
    bulk.rec = Pill("추천대로", GOLD, function() ns.RollAll("rec") end)
    bulk.pass = Pill("모두 포기", { 0.85, 0.78, 0.76 }, function() ns.RollAll("pass") end)
    bulk.rec:SetPoint("TOPLEFT", bulk, "TOPLEFT", 0, 0)
    bulk.rec:ClearAllPoints(); bulk.rec:SetPoint("TOPLEFT", bulk, "TOPLEFT", 2, 0)
    bulk.pass:SetPoint("LEFT", bulk.rec, "RIGHT", 10, 0)
    return anchor
end

local function RoundBtn(card, col, tex, label)
    local b = CreateFrame("Button", nil, card)
    b:SetSize(24, 24)
    b.glow = b:CreateTexture(nil, "BACKGROUND", nil, -2)
    b.glow:SetTexture(ns.MEDIA .. "circle"); b.glow:SetBlendMode("ADD")
    b.glow:SetPoint("CENTER"); b.glow:SetSize(34, 34); b.glow:Hide()
    b.ringT = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    b.ringT:SetTexture(ns.MEDIA .. "circle"); b.ringT:SetPoint("CENTER"); b.ringT:SetSize(29, 29)
    b.ringT:SetVertexColor(1, 0.957, 0.941, 1); b.ringT:Hide()
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetTexture(ns.MEDIA .. "circle"); b.bg:SetAllPoints()
    b.bg:SetVertexColor(col[1], col[2], col[3], 1)
    b.col = col
    b.ic = b:CreateTexture(nil, "ARTWORK")
    b.ic:SetTexture(ns.MEDIA .. tex); b.ic:SetSize(15, 15); b.ic:SetPoint("CENTER")
    if tex == "roll_x" then b.ic:SetVertexColor(0.85, 0.78, 0.76) end
    b.lbl = ns.Font(card, 9.5, { 0.85, 0.78, 0.76 })
    b.lbl:SetPoint("TOP", b, "BOTTOM", 0, -2)
    b.lbl:SetText(label); b.label = label; b.lbl:Hide()
    b.tip = label
    local ag = b.glow:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(0.15); a:SetToAlpha(0.45); a:SetDuration(0.8); a:SetSmoothing("IN_OUT")
    b.ag = ag
    b:SetScript("OnEnter", function(s)
        s.bg:SetVertexColor(math.min(1, s.col[1] + 0.12), math.min(1, s.col[2] + 0.12), math.min(1, s.col[3] + 0.12), 1)
        GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:AddLine(s.isRec and (s.tip .. "  |cffff8fa3(토끼 추천)|r") or s.tip)
        if s.isRec then GameTooltip:AddLine(BasisText(), 1, 0.7, 0.48) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(s) s.bg:SetVertexColor(s.col[1], s.col[2], s.col[3], 1); GameTooltip:Hide() end)
    return b
end

local function SetRec(b, on, col)
    if on then
        b.ringT:Show(); b.glow:SetVertexColor(col[1], col[2], col[3], 1); b.glow:Show(); b.ag:Play(); b.isRec = true
    else
        b.ringT:Hide(); b.glow:Hide(); b.ag:Stop(); b.isRec = false
    end
end

local ROW_H = 18
local function BoardRow(card, i)
    card.rows = card.rows or {}
    local r = card.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, card)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", card, "TOPLEFT", PADX, -(PILL_H + 2 + (i - 1) * ROW_H))
    r:SetPoint("RIGHT", card, "RIGHT", -PADX, 0)
    r.hl = ns.RoundRect(r, 8, PINK, "BACKGROUND", 0, 0); r.hl:SetColor(PINK, 0.16)
    r.crown = r:CreateTexture(nil, "ARTWORK"); r.crown:SetTexture(ns.MEDIA .. "crown")
    r.crown:SetSize(13, 13); r.crown:SetPoint("LEFT", 5, 0); r.crown:SetVertexColor(1, 0.84, 0.35)
    r.name = ns.Font(r, 11); r.name:SetPoint("LEFT", 22, 0); r.name:SetWidth(70); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.pill = CreateFrame("Frame", nil, r); r.pill:SetSize(34, 14); r.pill:SetPoint("LEFT", 108, 0)
    r.pill.bg = ns.RoundRect(r.pill, 7, PINK, "BACKGROUND", 1, 0)
    r.pill.fs = ns.Font(r.pill, 9); r.pill.fs:SetPoint("CENTER", 0, 0); r.pill.fs:SetShadowColor(0, 0, 0, 0)
    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetStatusBarTexture(ns.WHITE); r.bar:SetMinMaxValues(0, 100)
    r.bar:SetPoint("LEFT", 148, 0); r.bar:SetPoint("RIGHT", -32, 0); r.bar:SetHeight(4)
    r.barbg = r.bar:CreateTexture(nil, "BACKGROUND"); r.barbg:SetAllPoints(); r.barbg:SetColorTexture(0.227, 0.169, 0.157, 1)
    r.num = r:CreateFontString(nil, "OVERLAY"); r.num:SetFont(ns.NUM or ns.FONT, 13, ""); r.num:SetPoint("RIGHT", -4, 0)
    r.ban = r:CreateTexture(nil, "OVERLAY"); r.ban:SetTexture(ns.MEDIA .. "roll_ban"); r.ban:SetSize(11, 11)
    r.ban:SetPoint("LEFT", 94, 0); r.ban:SetVertexColor(1, 0.42, 0.5); r.ban:Hide()
    -- 이름에 마우스 = 블랙리스트 이유 · 오른쪽 클릭 = 블랙리스트에 넣기/빼기
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(s2)
        local b = s2.who and ns.BlackGet and ns.BlackGet(s2.who)
        if not b then return end
        GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffff6b7f블랙리스트|r  " .. s2.who)
        if b.note and b.note ~= "" then GameTooltip:AddLine(b.note, 1, 0.6, 0.66, true) end
        GameTooltip:AddLine(date("%m월 %d일", b.at or time()) .. " · 같이 만남 " .. (b.met or 0) .. "번", 0.6, 0.55, 0.53)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnMouseUp", function(s2, btn)
        if btn == "RightButton" and s2.who and ns.BlackAsk then ns.BlackAsk(s2.who) end
    end)
    card.rows[i] = r
    return r
end

-- C안: "입찰 · 차비 · ×" 한 줄 막대 단추
local function SegBtn(card, col, tex, label)
    local b = CreateFrame("Button", nil, card)
    b:SetHeight(24)
    b.col = col
    b.fill = b:CreateTexture(nil, "BACKGROUND", nil, 1); b.fill:SetTexture(ns.WHITE); b.fill:SetAllPoints()
    b.sep = b:CreateTexture(nil, "BORDER"); b.sep:SetTexture(ns.WHITE); b.sep:SetWidth(1.5)
    b.sep:SetPoint("TOPLEFT"); b.sep:SetPoint("BOTTOMLEFT"); b.sep:SetVertexColor(TK_RIM[1], TK_RIM[2], TK_RIM[3], 1)
    b.shine = b:CreateTexture(nil, "BORDER", nil, 1); b.shine:SetTexture(ns.WHITE); b.shine:SetHeight(1)
    b.shine:SetPoint("TOPLEFT", 1, 0); b.shine:SetPoint("TOPRIGHT", -1, 0); b.shine:SetVertexColor(1, 0.96, 0.78, 0.9)
    b.ic = b:CreateTexture(nil, "ARTWORK"); b.ic:SetTexture(ns.MEDIA .. tex); b.ic:SetSize(17, 17)
    -- 유리 미니멀: 글자 탭 (추천 칸만 금색 + 밑줄 + ★)
    b.ul = b:CreateTexture(nil, "ARTWORK"); b.ul:SetTexture(ns.WHITE); b.ul:SetHeight(2.5)
    b.ul:SetPoint("BOTTOMLEFT", 6, 0); b.ul:SetPoint("BOTTOMRIGHT", -6, 0); b.ul:Hide()
    function b:SetLabel(t, icon)
        self.ic:Hide()
        self.curLabel = t or self.curLabel
        if not self.fs then self.fs = ns.Font(self, 12); self.fs:SetShadowColor(0, 0, 0, 0) end
        self.fs:ClearAllPoints(); self.fs:SetPoint("CENTER", 0, 1)
        self.fs:SetText((self.curLabel or "포기") .. (self.isRec and " ★" or ""))
    end
    b.fs = ns.Font(b, 12); b.fs:SetShadowColor(0, 0, 0, 0)
    b.label = label
    b:SetLabel(label or "포기")
    b.tip = label or "포기"
    b:SetScript("OnEnter", function(s2)
        s2.hov = true; ns.RollSegPaint(s2)
        GameTooltip:SetOwner(s2, "ANCHOR_TOP"); GameTooltip:AddLine(s2.isRec and (s2.tip .. "  |cffff8fa3(토끼 추천)|r") or s2.tip)
        if s2.isRec then GameTooltip:AddLine(BasisText(), 1, 0.7, 0.48) end
        local e = s2:GetParent().e
        if e and e.notMine and e.whyLong then GameTooltip:AddLine(e.whyLong, 0.85, 0.78, 0.76, true) end
        if e and e.party then GameTooltip:AddLine("이 템이 맞는 파티원: " .. e.party, 0.56, 0.91, 0.6, true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(s2) s2.hov = false; ns.RollSegPaint(s2); GameTooltip:Hide() end)
    return b
end
-- 추천 칸 = 색으로 꽉 채움 + 흰 테, 나머지 = 진한 바탕 + 색 글씨
function ns.RollSegPaint(b)
    b.fill:SetAlpha(0); b.sep:Hide(); b.shine:Hide(); b.ic:Hide()
    if b.isRec then
        b.fs:SetTextColor(1, 0.82, 0.35); b.ul:SetVertexColor(1, 0.82, 0.35, 1); b.ul:Show()
    else
        local k = b.hov and 1 or (b.col == GREY and 0.45 or 0.72)
        b.fs:SetTextColor(k, k, k); b.ul:SetShown(b.hov and true or false); b.ul:SetVertexColor(1, 1, 1, 0.35)
    end
    b:SetLabel()
end

local function MakeCard(i)
    if cards[i] then return cards[i] end
    local f = CreateFrame("Frame", nil, Anchor())
    f:SetSize(W, CARD_H)
    f:EnableMouse(true)
    f.tk = Ticket(f, 10, 4)
    -- 파티 매너 띠 (내 장비가 아닐 때 맨 위)
    f.banBg = f:CreateTexture(nil, "BORDER", nil, 1); f.banBg:SetTexture(ns.WHITE)
    f.banBg:SetPoint("TOPLEFT", 6, -1.5); f.banBg:SetPoint("TOPRIGHT", -6, -1.5); f.banBg:SetHeight(18)
    pcall(f.banBg.SetGradient, f.banBg, "HORIZONTAL", CreateColor(0.29, 0.23, 0.24, 1), CreateColor(0.23, 0.17, 0.18, 1))
    f.banIc = f:CreateTexture(nil, "ARTWORK"); f.banIc:SetTexture(ns.MEDIA .. "bunny"); f.banIc:SetSize(13, 13); f.banIc:SetPoint("LEFT", f.banBg, "LEFT", 6, 0)
    f.banFs = ns.Font(f, 10.5, { 0.85, 0.78, 0.76 }); f.banFs:SetPoint("LEFT", f.banIc, "RIGHT", 4, 0); f.banFs:SetText("파티 매너 · 내 장비가 아니에요")
    f.banBg:Hide(); f.banIc:Hide(); f.banFs:Hide()
    -- 뜯는 선 (점선)
    f.dash = {}
    for i = 1, 22 do
        local d = f:CreateTexture(nil, "BORDER"); d:SetTexture(ns.WHITE); d:SetSize(5, 1.5)
        d:SetVertexColor(TK_RIM[1], TK_RIM[2], TK_RIM[3], 1); f.dash[i] = d
    end
    -- 단추 막대 테두리
    f.segbox = CreateFrame("Frame", nil, f); f.segbox:SetHeight(26)
    f.segrim = ns.RoundRect(f.segbox, 7, TK_RIM, "BACKGROUND", 0, 0)
    -- Shift + 끌기 = 위치 옮기기
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() if IsShiftKeyDown() and badge then badge:StartMoving() end end)
    f:SetScript("OnDragStop", function() if badge then badge:StopMovingOrSizing(); ns.RollSavePos() end end)
    -- 아이콘 (둘레 = 등급 색)
    local ic = CreateFrame("Button", nil, f)
    ic:SetSize(28, 28); ic:SetPoint("TOPLEFT", PADX, -6)
    ic.halo = ic:CreateTexture(nil, "BACKGROUND", nil, -2); ic.halo:SetTexture(ns.MEDIA .. "soft_glow")
    ic.halo:SetBlendMode("ADD"); ic.halo:SetPoint("CENTER"); ic.halo:SetSize(42, 42)
    ic.rim = ns.RoundRect(ic, 6, { 1, 1, 1 }, "BACKGROUND", 0, -2)
    ic.tex = ic:CreateTexture(nil, "ARTWORK"); ic.tex:SetAllPoints(); ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ic.count = ic:CreateFontString(nil, "OVERLAY"); ic.count:SetFont(ns.NUM or ns.FONT, 11, "OUTLINE"); ic.count:SetPoint("BOTTOMRIGHT", 2, -1)
    ic:SetScript("OnEnter", function(s)
        local e = f.e; if not e then return end
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        if e.test or not GameTooltip.SetLootRollItem then GameTooltip:SetHyperlink(e.link)
        else GameTooltip:SetLootRollItem(e.id) end
        GameTooltip:Show()
    end)
    ic:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ic:SetScript("OnClick", function() if f.e and f.e.link and HandleModifiedItemClick then HandleModifiedItemClick(f.e.link) end end)
    -- 유리 미니멀: 아이콘은 동그랗게 + 둘레 분홍 링 = 남은 시간
    local icm = ic:CreateMaskTexture()
    icm:SetTexture(ns.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); icm:SetAllPoints(ic.tex)
    ic.tex:AddMaskTexture(icm)
    ic.track = ic:CreateTexture(nil, "BACKGROUND", nil, 1); ic.track:SetTexture(ns.MEDIA .. "ring_thin")
    ic.track:SetPoint("TOPLEFT", -4, 4); ic.track:SetPoint("BOTTOMRIGHT", 4, -4); ic.track:SetVertexColor(1, 1, 1, 0.12)
    local cd = CreateFrame("Cooldown", nil, ic, "CooldownFrameTemplate")
    cd:SetPoint("TOPLEFT", -4, 4); cd:SetPoint("BOTTOMRIGHT", 4, -4)
    cd:SetSwipeTexture(ns.MEDIA .. "ring_thin"); cd:SetSwipeColor(1, 0.561, 0.639, 1)
    cd:SetReverse(true); cd:SetDrawEdge(false); cd:SetDrawBling(false)
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
    ic.cd = cd
    f.ic = ic
    f.name = ns.Font(f, 12); f.name:SetPoint("TOPLEFT", ic, "TOPRIGHT", 8, 1)
    f.name:SetWidth(W - 28 - PADX * 2 - 8 - 96); f.name:SetJustifyH("LEFT"); f.name:SetWordWrap(false)
    f.why = ns.Font(f, 10); f.why:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
    f.why:SetWidth(W - 28 - PADX * 2 - 8 - 96); f.why:SetJustifyH("LEFT"); f.why:SetWordWrap(false)
    -- 단추 셋
    f.need = SegBtn(f, PINK, "roll_btn_need", "입찰")
    f.greed = SegBtn(f, GOLD, "roll_btn_greed", "차비")
    f.pass = SegBtn(f, GREY, "roll_btn_pass", nil); f.pass:SetWidth(30)
    f.need:SetPoint("TOPLEFT", f.segbox, "TOPLEFT", 1.5, -1.5); f.need:SetPoint("BOTTOMLEFT", f.segbox, "BOTTOMLEFT", 1.5, 1.5)
    f.pass:SetPoint("TOPRIGHT", f.segbox, "TOPRIGHT", -1.5, -1.5); f.pass:SetPoint("BOTTOMRIGHT", f.segbox, "BOTTOMRIGHT", -1.5, 1.5)
    f.need:SetWidth((W - PADX * 2 - 3 - 30) / 2)
    f.greed:SetPoint("TOPLEFT", f.need, "TOPRIGHT", 0, 0); f.greed:SetPoint("BOTTOMRIGHT", f.pass, "BOTTOMLEFT", 0, 0)
    f.need.sep:Hide()
    for _, b in ipairs({ f.need, f.greed, f.pass }) do b:SetFrameLevel(f.segbox:GetFrameLevel() + 2) end
    f.need:SetScript("OnClick", function() ns.RollDo(f.e, 1) end)
    f.greed:SetScript("OnClick", function() ns.RollDo(f.e, 2) end)
    f.pass:SetScript("OnClick", function() ns.RollDo(f.e, 0) end)
    -- 반쪽 알약 글씨 ("차비 추천" · "입찰 78 · 1등")
    f.ptxt = ns.Font(f, 10.5); f.ptxt:SetJustifyH("LEFT"); f.ptxt:SetWordWrap(false)
    -- 고른 뒤: 오른쪽 위 분홍 알약 "입찰함 · 내 주사위 87"
    f.mine = CreateFrame("Frame", nil, f); f.mine:SetSize(110, 18); f.mine:SetPoint("RIGHT", f, "TOPRIGHT", -PADX - 14, -PILL_H / 2)
    f.mine.bg = ns.RoundRect(f.mine, 9, PINK, "BACKGROUND", 0, 0)
    f.mine.fs = ns.Font(f.mine, 10.5, C.ink); f.mine.fs:SetShadowColor(0, 0, 0, 0); f.mine.fs:SetPoint("CENTER")
    f.mine:Hide()
    -- 접힌 줄: 오른쪽 힌트 ("● 차비 추천") + 꺾쇠
    f.chev = f:CreateTexture(nil, "ARTWORK"); f.chev:SetTexture(ns.MEDIA .. "roll_chev"); f.chev:SetSize(10, 10)
    f.chev:SetPoint("RIGHT", f, "TOPRIGHT", -PADX, -PILL_H / 2); f.chev:SetVertexColor(0.72, 0.65, 0.63)
    f.hint = ns.Font(f, 10.5); f.hint:SetPoint("RIGHT", f.chev, "LEFT", -6, 0)
    -- 접힌 줄 클릭 = 펼치기 (안 고른 템) / 결과 보드 열고 닫기 (고른 템)
    f:SetScript("OnMouseUp", function(s2, btn)
        if btn ~= "LeftButton" or not s2.e then return end
        if IsModifiedClick and IsModifiedClick("CHATLINK") and s2.e.link and ChatEdit_InsertLink then ChatEdit_InsertLink(s2.e.link); return end
        ns.RollClickCard(s2)
    end)
    -- 반쪽 알약에 마우스 = 템 설명 + 모두의 주사위
    f:SetScript("OnEnter", function(s2)
        if not (s2.e and s2.isPill) then return end
        s2.tk.bg:SetColor({ 0.23, 0.16, 0.17 }, 1)
        ns.RollPillTip(s2)
    end)
    f:SetScript("OnLeave", function(s2) s2.tk.bg:SetColor(TK_BG, 0.97); GameTooltip:Hide() end)
    -- 시간 막대
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetStatusBarTexture(ns.WHITE); f.bar:SetMinMaxValues(0, 1)
    f.bar:SetPoint("BOTTOMLEFT", PADX, 4); f.bar:SetPoint("BOTTOMRIGHT", -PADX, 4); f.bar:SetHeight(3)
    f.barbg = f.bar:CreateTexture(nil, "BACKGROUND"); f.barbg:SetAllPoints(); f.barbg:SetColorTexture(1, 1, 1, 0.16)
    f.secs = f:CreateFontString(nil, "OVERLAY"); f.secs:SetFont(ns.NUM or ns.FONT, 20, ""); f.secs:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADX, -6)
    -- 유리 바탕 · 가는 테 · 등급 띠/구멍 없음
    f.tk.bg:SetColor({ 0.07, 0.047, 0.047 }, 0.78)
    f.tk.rim:SetColor({ 1, 1, 1 }, 0.12)
    f.tk.Strip = function() end
    f.tk:Notch(false); f.tk.Notch = function() end
    f.segrim:SetColor({ 1, 1, 1 }, 0)
    f.sepLine = f:CreateTexture(nil, "BORDER"); f.sepLine:SetTexture(ns.WHITE); f.sepLine:SetHeight(1)
    f.sepLine:SetPoint("BOTTOMLEFT", f.segbox, "TOPLEFT", -2, 1); f.sepLine:SetPoint("BOTTOMRIGHT", f.segbox, "TOPRIGHT", 2, 1)
    f.sepLine:SetVertexColor(1, 1, 1, 0.12)
    f:SetScript("OnUpdate", function(s, el)
        s.t = (s.t or 0) + el
        if s.t < 0.1 then return end
        s.t = 0
        ns.RollTick(s)
    end)
    f:Hide()
    cards[i] = f
    return f
end

----------------------------------------------------------------------
-- 그리기
----------------------------------------------------------------------
local RANK = { need = 3, greed = 2, pass = 1 }
local TYPE_TXT = { need = "입찰", greed = "차비", pass = "포기" }
local TYPE_COL = { need = PINK, greed = GOLD, pass = GREY }

local function ClassColorOf(name)
    local units = {}
    if IsInRaid and IsInRaid() then for i = 1, 40 do units[#units + 1] = "raid" .. i end
    else units[1] = "player"; for i = 1, 4 do units[#units + 1] = "party" .. i end end
    for _, u in ipairs(units) do
        if UnitExists(u) and Short(UnitName(u)) == name then
            local _, cls = UnitClass(u)
            local c = cls and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(cls)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]))
            if c then return { c.r, c.g, c.b } end
        end
    end
    return { 0.85, 0.78, 0.76 }
end

local function GroupNames()
    local out = {}
    if test then return { Short(UnitName("player")), "도적토끼", "루루", "방패곰", "빛의망치" } end
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do local n = UnitName("raid" .. i); if n then out[#out + 1] = Short(n) end end
    else
        out[1] = Short(UnitName("player"))
        for i = 1, 4 do local n = UnitName("party" .. i); if n then out[#out + 1] = Short(n) end end
    end
    return out
end

local focusE    -- 지금 펼친(고를) 템
local function BoardOn(e, f)
    local m = DB().board
    if m == "off" or not e.mine then return false end
    if m == "all" then return true end
    if f then return e.showBoard and true or false end   -- 줄을 누르면 펼치기
    return true
end

-- 펼칠 템: 내가 누른 것 > 아직 안 고른 것 중 맨 위
local function Focus()
    if focusE and not focusE.mine and not focusE.done then
        for _, f in ipairs(active) do if f.e == focusE then return focusE end end
    end
    focusE = nil
    for _, f in ipairs(active) do
        local e = f.e
        if e and not e.mine and not e.done then focusE = e; return e end
    end
end

-- 결과 줄 정리: 입찰 > 차비 > 포기 > 고민 중, 같은 종류면 숫자 큰 순
local function SortedRolls(e)
    local list, seen = {}, {}
    for name, r in pairs(e.rolls) do list[#list + 1] = { name = name, t = r.t, n = r.n }; seen[name] = true end
    for _, n in ipairs(GroupNames()) do if not seen[n] then list[#list + 1] = { name = n } end end
    table.sort(list, function(a, b)
        local ra, rb = RANK[a.t] or 0, RANK[b.t] or 0
        if ra ~= rb then return ra > rb end
        if (a.n or -1) ~= (b.n or -1) then return (a.n or -1) > (b.n or -1) end
        return a.name < b.name
    end)
    return list
end

local function Paint(f)
    local e = f.e
    if not e then return end
    local qc = QColor(e.quality)
    local chosen = e.mine ~= nil
    local pill = chosen or (Focus() ~= e)
    f.isPill = pill
    f.ic.tex:SetTexture(e.texture)
    f.ic.count:SetText((not pill and (e.count or 1) > 1) and e.count or "")
    f.ic.rim:SetColor({ 0.10, 0.07, 0.06 }, 0)
    f.ic.halo:SetShown(false)
    -- 아이콘 둘레 링 = 남은 시간 (고른 템은 링 없이)
    if not chosen and not e.done then
        local left
        if e.test then left = math.max(0, (e.endAt - GetTime()) * 1000)
        elseif GetLootRollTimeLeft then left = tonumber(GetLootRollTimeLeft(e.id)) or 0 end
        local total = (e.total or 0) / 1000
        if total > 0 and left then
            f.ic.cd:SetCooldown(GetTime() - (total - left / 1000), total); f.ic.cd:Show()
        end
        f.ic.track:Show()
    else
        f.ic.cd:Clear(); f.ic.cd:Hide(); f.ic.track:Hide()
    end
    f.ic.halo:SetSize(pill and 34 or 60, pill and 34 or 60)
    f.ic.halo:SetVertexColor(qc[1], qc[2], qc[3], pill and 0.30 or 0.40)
    local isz = pill and 16 or 34
    f.ic:SetSize(isz, isz)
    f.ic:ClearAllPoints()
    local ban = (not pill) and e.notMine
    f.banBg:SetShown(ban and true or false); f.banIc:SetShown(ban and true or false); f.banFs:SetShown(ban and true or false)
    local off = ban and 20 or 0
    if pill then f.ic:SetPoint("LEFT", f, "LEFT", 9, 0) else f.ic:SetPoint("TOPLEFT", PADX + 4, -(PADX + off)) end
    f.secs:ClearAllPoints()
    f.secs:SetPoint("RIGHT", f, "TOPRIGHT", -PADX - 2, -(PADX + off + 17))   -- 아이콘 옆 큰 숫자
    -- 펼친 카드 부분
    f.name:SetShown(not pill); f.why:SetShown(not pill); f.bar:Hide(); f.secs:SetShown(not pill)
    f.tk:Strip(qc); f.segbox:SetShown(not pill)
    if f.sepLine then f.sepLine:SetShown(not pill) end   -- 접힌 줄엔 단추 위 구분선이 없어요 (줄을 가로지르던 선)
    if pill then for _, d in ipairs(f.dash) do d:Hide() end; f.tk:Notch(false) end
    f.need:SetShown(not pill); f.greed:SetShown(not pill); f.pass:SetShown(not pill)
    f.mine:Hide(); f.hint:Hide(); f.chev:Hide(); if f.chip then f.chip:Hide() end; if f.clk then f.clk:Hide() end
    if f.rows then for _, r in ipairs(f.rows) do r:Hide() end end
    f.ptxt:SetShown(pill)
    if f.ptl and not pill then f.ptl:Hide(); f.ptlFill:Hide() end
    if not pill then
        f:SetSize(W, CARD_H)
        f.name:ClearAllPoints(); f.name:SetPoint("TOPLEFT", f.ic, "TOPRIGHT", 11, 1)
        f.name:SetWidth(W - PADX * 2 - isz - 8 - 4 - 34)
        f.name:SetWordWrap(true); if f.name.SetMaxLines then f.name:SetMaxLines(2) end
        f.name:SetText(e.name or ""); f.name:SetTextColor(qc[1], qc[2], qc[3])
        f.why:ClearAllPoints(); f.why:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -2)
        f.why:SetWidth(W - PADX * 2 - isz - 8 - 4 - 30)
        f.why:SetWordWrap(true); if f.why.SetMaxLines then f.why:SetMaxLines(3) end
        f.why:SetJustifyV("TOP")
        local col = e.whyCol or TXT_SIDE
        f.why:SetText(e.why or ""); f.why:SetTextColor(col[1], col[2], col[3])
        local can = e.canNeed ~= false
        f.need:SetAlpha(can and 1 or 0.35); f.need:EnableMouse(can)
        f.need.isRec = e.rec == "need"; f.greed.isRec = e.rec == "greed"; f.pass.isRec = false
        ns.RollSegPaint(f.need); ns.RollSegPaint(f.greed); ns.RollSegPaint(f.pass)
        -- 이름이 한 줄이면 단추를 위로 당겨 빈칸 없애기
        local block = math.max(isz, (f.name:GetStringHeight() or 14) + 2 + ((e.why and e.why ~= "") and (f.why:GetStringHeight() or 12) or 0))
        local segY = PADX + off + block + 6
        -- 내 장비가 아니면: 입찰은 작고 흐리게 · "차비로 양보"를 넓게
        local inner = W - PADX * 2 - 3 - 30
        if e.notMine then
            f.need:SetWidth(40); f.pass:SetWidth(44); f.need:SetLabel("입찰", false); f.greed:SetLabel("차비로 양보")
            f.need:SetAlpha(can and 0.45 or 0.3)
        else
            local third = (W - PADX * 2 - 4) / 3   -- 탭 세 개 같은 폭
            f.need:SetWidth(third); f.pass:SetWidth(third); f.need:SetLabel("입찰"); f.greed:SetLabel("차비")
        end
        f.segbox:ClearAllPoints(); f.segbox:SetPoint("TOPLEFT", f, "TOPLEFT", PADX + 2, -(segY + 4)); f.segbox:SetPoint("RIGHT", f, "RIGHT", -PADX, 0)
        -- 뜯는 선
        local dw = (W - 28) / #f.dash
        for _, d in ipairs(f.dash) do d:Hide() end   -- 유리 미니멀: 시간은 아이콘 링
        f:SetHeight(segY + 4 + 26 + 9)
        f.tk:Notch(true)
        return
    end
    -- 접힌 한 줄: 아이콘 · 이름 전체 · 오른쪽 상태 · 꺾쇠 · 줄 아래 남은 시간
    f:SetSize(W, PILL_H)
    f.ic:SetSize(20, 20); f.ic:ClearAllPoints(); f.ic:SetPoint("LEFT", f, "LEFT", 9, 0)
    if not f.ptl then
        f.ptl = f:CreateTexture(nil, "ARTWORK"); f.ptl:SetTexture(ns.WHITE); f.ptl:SetHeight(2)
        f.ptl:SetPoint("BOTTOMLEFT", 12, 3); f.ptl:SetPoint("BOTTOMRIGHT", -12, 3)
        f.ptl:SetVertexColor(0.227, 0.169, 0.157, 1)
        f.ptlFill = f:CreateTexture(nil, "ARTWORK", nil, 1); f.ptlFill:SetTexture(ns.WHITE); f.ptlFill:SetHeight(2)
        f.ptlFill:SetPoint("BOTTOMLEFT", f.ptl, "BOTTOMLEFT", 0, 0)
    end
    local live = not chosen and not e.done
    f.ptl:SetShown(false); f.ptlFill:SetShown(false)   -- 시간은 아이콘 링
    f.hint:ClearAllPoints()
    if live then f.chev:Show(); f.hint:SetPoint("RIGHT", f.chev, "LEFT", -6, 0) else f.hint:SetPoint("RIGHT", f, "RIGHT", -PADX - 2, 0) end
    f.ptxt:ClearAllPoints(); f.ptxt:SetPoint("LEFT", f.ic, "RIGHT", 8, 0); f.ptxt:SetPoint("RIGHT", f.hint, "LEFT", -8, 0)
    f.ptxt:SetText(e.name or ""); f.ptxt:SetTextColor(qc[1], qc[2], qc[3])
    local txt, col, chipT, chipN
    if not chosen then
        if e.notMine then txt, col = "내 템 아님", { 0.72, 0.65, 0.63 }
        elseif e.rec == "need" then txt, col = "입찰 ★", { 1, 0.82, 0.35 }
        elseif e.rec == "greed" then txt, col = "차비 ★", { 1, 0.82, 0.35 }
        else txt, col = "고르기", { 0.72, 0.65, 0.63 } end
    else
        local list = SortedRolls(e)
        local rank
        for i, it in ipairs(list) do if it.name == e.me then rank = i break end end
        local my = e.rolls[e.me]
        txt, col = TYPE_TXT[e.mine] or "", TYPE_COL[e.mine] or PINK
        if e.mine == "pass" then col = { 0.72, 0.65, 0.63 } end
        if my and my.n then txt = txt .. " " .. my.n .. ((rank and e.mine ~= "pass") and (" · " .. rank .. "등") or "") end
        if e.winner then
            if e.winner == e.me then txt = "|T" .. ns.MEDIA .. "crown:11:11:0:0:128:128:0:128:0:128:255:215:90|t 획득!"; col = { 1, 0.88, 0.54 }
            else
                local cc = ClassColorOf(e.winner)
                txt = ("|cff%02x%02x%02x%s|r"):format(math.floor(cc[1] * 255), math.floor(cc[2] * 255), math.floor(cc[3] * 255), e.winner)
                col = { 0.85, 0.80, 0.78 }
            end
            local wr = e.rolls[e.winner]
            if wr and wr.t and wr.t ~= "pass" then chipT, chipN = wr.t, wr.n end
        elseif e.allPassed then txt, col = "모두 포기", { 0.62, 0.55, 0.53 } end
    end
    -- 먹은 사람이 누른 단추: "입찰 80" / "차비 4" 작은 알약
    if not f.chip then
        f.chip = CreateFrame("Frame", nil, f); f.chip:SetHeight(16)
        f.chip.bg = ns.RoundRect(f.chip, 8, PINK, "BACKGROUND", 0, 0)
        f.chip.rim = ns.RoundRect(f.chip, 8, PINK, "BACKGROUND", -1, -1)
        f.chip.fs = ns.Font(f.chip, 10, PINK); f.chip.fs:SetPoint("CENTER", 0, 0)
    end
    -- 고른 뒤 결과를 기다리는 동안: 작은 파이 시계 + 남은 초 알약
    if not f.clk then
        local k = CreateFrame("Frame", nil, f); k:SetSize(36, 16)
        k.bg = ns.RoundRect(k, 8, { 1, 1, 1 }, "BACKGROUND", 0, 0); k.bg:SetColor({ 1, 1, 1 }, 0.07)
        k.dial = k:CreateTexture(nil, "ARTWORK"); k.dial:SetTexture(ns.MEDIA .. "circle"); k.dial:SetSize(11, 11)
        k.dial:SetPoint("LEFT", 4, 0); k.dial:SetVertexColor(1, 1, 1, 0.14)
        k.cd = CreateFrame("Cooldown", nil, k, "CooldownFrameTemplate")
        k.cd:SetAllPoints(k.dial); k.cd:SetSwipeTexture(ns.MEDIA .. "circle"); k.cd:SetReverse(true)
        k.cd:SetDrawEdge(false); k.cd:SetDrawBling(false)
        if k.cd.SetHideCountdownNumbers then k.cd:SetHideCountdownNumbers(true) end
        k.fs = k:CreateFontString(nil, "OVERLAY"); k.fs:SetFont(ns.NUM or ns.FONT, 12, ""); k.fs:SetPoint("LEFT", k.dial, "RIGHT", 4, 0)
        f.clk = k
    end
    local waiting = chosen and not e.winner and not e.allPassed and not e.done
    local clkW = 0
    if waiting then
        f.clk:ClearAllPoints(); f.clk:SetPoint("RIGHT", f, "RIGHT", -PADX - 2, 0); f.clk:Show()
        f.hint:ClearAllPoints(); f.hint:SetPoint("RIGHT", f.clk, "LEFT", -6, 0)
        local total = (e.total and e.total > 0) and e.total or 60000
        local left
        if e.test then left = math.max(0, (e.endAt - GetTime()) * 1000) elseif GetLootRollTimeLeft then left = tonumber(GetLootRollTimeLeft(e.id)) end
        left = left or 0
        f.clk.cd:SetCooldown(GetTime() - (total - left) / 1000, total / 1000)
        clkW = 42
    else
        f.clk:Hide()
    end
    local chipW = clkW
    if chipT then
        local cc = TYPE_COL[chipT] or PINK
        f.chip.bg:SetColor({ cc[1] * 0.25, cc[2] * 0.2, cc[3] * 0.2 }, 0.95); f.chip.rim:SetColor(cc, 0.6)
        f.chip.fs:SetText((TYPE_TXT[chipT] or "") .. (chipN and (" " .. chipN) or "")); f.chip.fs:SetTextColor(cc[1], cc[2], cc[3])
        chipW = (f.chip.fs:GetStringWidth() or 30) + 14
        f.chip:SetWidth(chipW)
        f.chip:ClearAllPoints(); f.chip:SetPoint("RIGHT", f, "RIGHT", -PADX - 2, 0); f.chip:Show()
        f.hint:ClearAllPoints(); f.hint:SetPoint("RIGHT", f.chip, "LEFT", -6, 0)
        chipW = chipW + 6
    else
        f.chip:Hide()
    end
    f.hint:SetText(txt); f.hint:SetTextColor(col[1], col[2], col[3]); f.hint:Show()
    f.ptxt:SetWidth(math.max(40, W - 12 - 20 - 8 - 8 - (f.hint:GetStringWidth() or 60) - chipW - (live and 22 or 10)))
end

function ns.RollPillTip(f)
    local e = f.e
    GameTooltip:SetOwner(f, "ANCHOR_BOTTOM")
    if e.link then pcall(GameTooltip.SetHyperlink, GameTooltip, e.link) else GameTooltip:AddLine(e.name or "") end
    if e.why and not e.mine then GameTooltip:AddLine(" "); GameTooltip:AddLine((e.notMine and "파티 매너 · 내 장비가 아니에요\n" or "") .. (e.whyLong or e.why), 1, 0.82, 0.6, true) end
    if e.party and not e.mine then GameTooltip:AddLine("맞는 파티원: " .. e.party, 0.56, 0.91, 0.6, true) end
    if e.mine or e.winner then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("모두의 선택", 0.73, 0.65, 0.63)
        local ICON = { need = "roll_btn_need", greed = "roll_btn_greed", pass = "roll_btn_pass" }
        local bestGreed, winNeed = nil, nil
        for _, it in ipairs(SortedRolls(e)) do
            local cc = ClassColorOf(it.name)
            local tc = TYPE_COL[it.t] or { 0.6, 0.55, 0.53 }
            local ic = ICON[it.t] and ("|T" .. ns.MEDIA .. ICON[it.t] .. ":12:12|t ") or "    "
            local crown = (e.winner == it.name) and (" |T" .. ns.MEDIA .. "crown:11:11:0:0:128:128:0:128:0:128:255:215:90|t") or ""
            local left = ("%s|cff%02x%02x%02x%s|r  |cff%02x%02x%02x%s|r%s"):format(ic,
                math.floor(tc[1] * 255), math.floor(tc[2] * 255), math.floor(tc[3] * 255), TYPE_TXT[it.t] or "고민 중…",
                math.floor(cc[1] * 255), math.floor(cc[2] * 255), math.floor(cc[3] * 255), it.name, crown)
            GameTooltip:AddDoubleLine(left, it.n and tostring(it.n) or "-", 1, 1, 1, tc[1], tc[2], tc[3])
            if it.t == "greed" and it.n and (not bestGreed or it.n > bestGreed) then bestGreed = it.n end
            if e.winner == it.name and it.t == "need" then winNeed = it.n end
        end
        if winNeed and bestGreed and bestGreed > winNeed then
            GameTooltip:AddLine(("입찰한 사람이 있으면 차비 %d보다 입찰 %d이 먼저 가져가요"):format(bestGreed, winNeed), 0.73, 0.65, 0.63, true)
        end
    else
        GameTooltip:AddLine("누르면 펼쳐서 고르기", 0.6, 0.55, 0.53)
    end
    GameTooltip:Show()
end

local function Relayout()
    Anchor()
    for _, f in ipairs(active) do if f.e then Paint(f) end end
    local y, open = 0, 0
    -- 펼친 카드 → 아직 안 고른 템 줄 → 고른 템 (결과 한 줄, 맨 아래로)
    local function place(f, h) f:ClearAllPoints(); f:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, y); y = y - h - 5 end
    for _, f in ipairs(active) do
        if f.e and not f.e.mine and not f.e.done then open = open + 1 end
    end
    for _, f in ipairs(active) do if f.e and not f.isPill then place(f, f:GetHeight()) end end
    for _, f in ipairs(active) do
        if f.e and f.isPill and not (f.e.mine or f.e.done) then place(f, PILL_H) end
    end
    for _, f in ipairs(active) do
        if f.e and f.isPill and (f.e.mine or f.e.done) then place(f, PILL_H) end
    end
    basis:SetShown(false)
    bulk:ClearAllPoints(); bulk:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, y - 1)
    bulk:SetShown(open >= 2)
    if open >= 2 then y = y - 22 end
    anchor:SetWidth(W)
    anchor:SetHeight(math.max(20, -y))
    local want = #active > 0 and not collapsed
    if want and not anchor:IsShown() then
        ns.RollPlace()
        local o = anchor.fromRight and "RIGHT" or "LEFT"
        if anchor.popScale.SetOrigin then anchor.popScale:SetOrigin(o, 0, 0) end
        anchor:Show(); anchor.pop:Stop(); anchor.pop:Play()
    elseif not want and anchor:IsShown() then
        anchor:Hide()
    elseif want then
        ns.RollPlace()
    end
    PaintBadge()
    if ns.RollBlackPlace then ns.RollBlackPlace() end
    if ns.RollGreetLayout then ns.RollGreetLayout() end
end
ns.RollRelayout = function() Relayout() end

local function Free(f)
    f:Hide(); f.e = nil
    for i, x in ipairs(active) do if x == f then table.remove(active, i) break end end
    Relayout()
end

local function CardFor(e)
    for _, f in ipairs(active) do if f.e == e then return f end end
end

local function Refresh(e)
    local f = e and CardFor(e)
    if f then Paint(f); Relayout() end
end

-- 기록장 (접속을 끊어도 남아요)
local function LogDB() ns.db.rollLog = ns.db.rollLog or {}; return ns.db.rollLog end
local function Hex(c) return string.format("%02x%02x%02x", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255)) end
local function SaveLog(e)
    if e.logged or not e.link then return end
    e.logged = true
    local rolls = {}
    for name, r in pairs(e.rolls) do
        rolls[#rolls + 1] = { name = name, t = r.t, n = r.n, c = Hex(ClassColorOf(name)) }
    end
    table.sort(rolls, function(x, y)
        local ra, rb = RANK[x.t] or 0, RANK[y.t] or 0
        if ra ~= rb then return ra > rb end
        return (x.n or -1) > (y.n or -1)
    end)
    local zone = e.test and "미리 보기" or ((GetInstanceInfo and GetInstanceInfo()) or (GetRealZoneText and GetRealZoneText()) or "")
    local L = LogDB()
    table.insert(L, 1, { at = time(), zone = zone, link = e.link, name = e.name, q = e.quality, tex = e.texture,
        win = e.winner, all = e.allPassed, mine = e.mine, me = e.me, rolls = rolls })
    while #L > 300 do table.remove(L) end
    if ns.RollLogPaint then ns.RollLogPaint() end
end

-- 카드만 숨기기 (자료는 결과 글이 올 때까지 계속 받아요)
local function HideCardLater(e, sec)
    C_Timer.After(sec, function()
        local f = CardFor(e)
        if f then Free(f) end
    end)
end

local function FinishLater(e, sec)
    if e.finishing then return end
    e.finishing = true
    C_Timer.After(sec, function()
        SaveLog(e)
        local f = CardFor(e)
        if f then Free(f) end
        entries[e.id] = nil
    end)
end

function ns.RollClickCard(f)
    local e = f.e
    if not e then return end
    if e.mine then return end
    if focusE ~= e then focusE = e end
    Relayout()
end

function ns.RollTick(f)
    local e = f.e
    if not e then return end

    local left
    if e.test then left = math.max(0, (e.endAt - GetTime()) * 1000)
    elseif GetLootRollTimeLeft then left = GetLootRollTimeLeft(e.id) end
    if e.done then left = 0 end
    left = tonumber(left) or 0
    local frac = e.total and e.total > 0 and math.min(1, left / e.total) or 0
    f.bar:SetValue(frac)
    local s = math.ceil(left / 1000)
    local red = s <= 10
    f.bar:SetStatusBarColor(red and 1 or PINK[1], red and 0.35 or PINK[2], red and 0.43 or PINK[3], 1)
    f.secs:SetText(e.done and "" or s)
    if f.clk and f.clk:IsShown() then
        f.clk.fs:SetText(s)
        local c = red and { 1, 0.353, 0.431 } or PINK
        f.clk.cd:SetSwipeColor(c[1], c[2], c[3], 1)
        if red then f.clk.fs:SetTextColor(1, 0.353, 0.431) else f.clk.fs:SetTextColor(0.85, 0.80, 0.78) end
        f.clk:SetWidth(4 + 11 + 4 + (f.clk.fs:GetStringWidth() or 12) + 7)
    end
    f.secs:SetTextColor(red and 1 or 0.949, red and 0.42 or 0.702, red and 0.5 or 0.761)
    -- 뜯는 선 = 남은 시간: 왼쪽부터 분홍으로 켜져 있다가 오른쪽부터 꺼져요 (10초 아래 = 빨강 + 깜빡)
    if f.ptlFill and f.isPill and f.ptl:IsShown() then
        local w = (f.ptl:GetWidth() or 0) * frac
        f.ptlFill:SetWidth(math.max(0.01, w))
        f.ptlFill:SetVertexColor(red and 1 or PINK[1], red and 0.35 or PINK[2], red and 0.43 or PINK[3], 1)
    end
    if f.dash and not f.isPill then
        local n = #f.dash
        local lit = math.ceil(frac * n)
        local blink = red and (math.floor(GetTime() * 4) % 2 == 0)
        for i, d in ipairs(f.dash) do
            if i <= lit then
                if red then
                    d:SetVertexColor(1, 0.35, 0.43, (i == lit and blink) and 0.35 or 1)
                else
                    d:SetVertexColor(PINK[1], PINK[2], PINK[3], 1)
                end
                d:SetHeight(2.5)
            else
                d:SetVertexColor(TK_RIM[1], TK_RIM[2], TK_RIM[3], 0.7); d:SetHeight(1.5)
            end
        end
    end
    if e.test and left <= 0 and not e.done then
        e.done = true
        if not e.winner then ns.RollTestFinish(e) end
    end
end

----------------------------------------------------------------------
-- 열기 · 누르기
----------------------------------------------------------------------
-- 이름 · 그림이 아직 안 받아진 템: 아는 것부터 채우고, 나중에 다시
local function FillItem(e)
    if not e.link then return true end
    local name, _, quality, _, _, _, _, _, _, tex = GetItemInfo(e.link)
    if (not e.name or e.name == "" or e.name == e.link or e.name == "불러오는 중…") and name then e.name = name end
    if not e.quality and quality then e.quality = quality end
    if not e.texture then
        e.texture = tex
        if not e.texture and GetItemInfoInstant then
            local ok, _, _, _, _, icon = pcall(GetItemInfoInstant, e.link)
            if ok then e.texture = icon end
        end
    end
    if (not e.name or e.name == "") then e.name = e.link:match("%[(.-)%]") end
    local ready = name ~= nil
    if not ready then
        local id = ItemID(e.link)
        if id and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    end
    e.waiting = not ready
    return ready
end

local function Open(e)
    entries[e.id] = e
    e.rolls = e.rolls or {}
    e.me = Short(UnitName("player"))
    FillItem(e)
    if e.waiting then
        e.why = "● 템 정보를 받는 중…"; e.whyCol = { 0.72, 0.65, 0.63 }
        if not e.name or e.name == "" then e.name = "불러오는 중…" end
    else
        e.rec, e.whyCol, e.why = Recommend(e)
    end
    collapsed = false
    if not e.why and e.link then
        -- 추천이 없는 템(재료 · 상자 등)은 종류만 회색으로
        local _, _, _, _, _, itype, isub = GetItemInfo(e.link)
        if itype then e.why = (isub and isub ~= itype) and (itype .. " · " .. isub) or itype; e.whyCol = { 0.72, 0.65, 0.63 } end
    end
    local f
    for i = 1, 8 do
        local c = MakeCard(i)
        if not c.e then f = c break end
    end
    if not f then return end
    f.e = e
    active[#active + 1] = f
    Paint(f)
    f:Show()
    Relayout()
    if ns.RollBadgePop then ns.RollBadgePop() end
end

local function OnStart(id, ms)
    if not (GetLootRollItemInfo and id) then return end
    local ok, tex, name, count, quality, bop, canNeed, canGreed = pcall(GetLootRollItemInfo, id)
    if not ok then return end
    local link = GetLootRollItemLink and GetLootRollItemLink(id)
    local total = tonumber(ms) or (GetLootRollTimeLeft and GetLootRollTimeLeft(id)) or 60000
    Open({ id = id, link = link, texture = tex, name = name, count = count, quality = quality, bop = bop,
           canNeed = canNeed, canGreed = canGreed, total = total })
end

local TYPE_OF = { [0] = "pass", [1] = "need", [2] = "greed", [3] = "greed" }
function ns.RollDo(e, rt)
    if not e or e.mine or e.done then return end
    if rt == 1 and e.canNeed == false then return end
    e.mine = TYPE_OF[rt]
    if e.test then
        local n = (rt ~= 0) and math.random(1, 100) or nil
        e.rolls[e.me] = { t = e.mine, n = n }
    else
        RollOnLoot(e.id, rt)
    end
    Refresh(e)
    if rt == 0 and DB().board ~= "all" then HideCardLater(e, 0.6) end
end

function ns.RollAll(how)
    local list = {}
    for _, f in ipairs(active) do if f.e and not f.e.mine and not f.e.done then list[#list + 1] = f.e end end
    for _, e in ipairs(list) do
        if how == "pass" then ns.RollDo(e, 0)
        elseif e.rec == "need" then ns.RollDo(e, 1)
        elseif e.rec == "greed" then ns.RollDo(e, 2) end
    end
end

----------------------------------------------------------------------
-- 채팅 글 읽기 (누가 무엇을 굴렸는지)
--   글 모양은 게임 글자(LOOT_ROLL_...)로 패턴을 만들어서 언어와 상관없이
----------------------------------------------------------------------
local function Pat(fmt)
    if type(fmt) ~= "string" or fmt == "" then return end
    local out, order, n, plain = { "^" }, {}, 0, 0
    local i = 1
    while i <= #fmt do
        local a, b, pos, typ = fmt:find("^%%(%d)%$([sd])", i)
        if a then
            n = n + 1; order[n] = tonumber(pos)
            out[#out + 1] = (typ == "d") and "(%d+)" or "(.-)"
            i = b + 1
        else
            a, b, typ = fmt:find("^%%([sd])", i)
            if a then
                n = n + 1; plain = plain + 1; order[n] = plain
                out[#out + 1] = (typ == "d") and "(%d+)" or "(.-)"
                i = b + 1
            else
                local c = fmt:sub(i, i)
                if c == "%" and fmt:sub(i + 1, i + 1) == "%" then out[#out + 1] = "%%"; i = i + 2
                else
                    out[#out + 1] = c:find("[%^%$%(%)%.%[%]%*%+%-%?%%]") and ("%" .. c) or c
                    i = i + 1
                end
            end
        end
    end
    out[#out + 1] = "$"
    return { pat = table.concat(out), order = order, hist = fmt:find("^|HlootHistory") ~= nil }
end
local function Match(m, msg)
    if not m then return end
    local caps = { msg:match(m.pat) }
    if #caps == 0 then return end
    local args = {}
    for j, v in ipairs(caps) do args[m.order[j]] = v end
    -- 와우 포에버: 글 앞에 "[전리품]" 기록 링크 번호(%d)가 붙어요 → 그 칸을 빼고 영어판 순서로
    if m.hist then
        local out = {}
        for k, v in pairs(args) do if k > 1 then out[k - 1] = v end end
        return out
    end
    return args
end

-- 영어판 기준 인자 순서: ROLLED = (숫자, 템, 이름) · 고름 = (이름, 템) · 나 = (템) · 획득 = (이름, 템)
local PATS
local function BuildPats()
    PATS = {}
    local function add(key, kind, t)
        local m = Pat(_G[key]); if m then m.kind, m.t = kind, t; PATS[#PATS + 1] = m end
    end
    add("LOOT_ROLL_ROLLED_NEED_ROLE_BONUS", "rolled", "need")
    add("LOOT_ROLL_ROLLED_NEED", "rolled", "need")
    add("LOOT_ROLL_ROLLED_GREED", "rolled", "greed")
    add("LOOT_ROLL_ROLLED_DE", "rolled", "greed")
    add("LOOT_ROLL_NEED_SELF", "self", "need")
    add("LOOT_ROLL_GREED_SELF", "self", "greed")
    add("LOOT_ROLL_DISENCHANT_SELF", "self", "greed")
    add("LOOT_ROLL_PASSED_SELF", "self", "pass")
    add("LOOT_ROLL_PASSED_SELF_AUTO", "self", "pass")
    add("LOOT_ROLL_NEED", "chose", "need")
    add("LOOT_ROLL_GREED", "chose", "greed")
    add("LOOT_ROLL_DISENCHANT", "chose", "greed")
    add("LOOT_ROLL_PASSED", "chose", "pass")
    add("LOOT_ROLL_PASSED_AUTO", "chose", "pass")
    add("LOOT_ROLL_PASSED_AUTO_FEMALE", "chose", "pass")
    for _, k in ipairs({ "NEED", "NEED_OFF_SPEC", "GREED", "DE", "TRANSMOG", "TRANSMOGRIFICATION" }) do
        add("LOOT_ROLL_YOU_WON_NO_SPAM_" .. k, "youwon2")
        add("LOOT_ROLL_WON_NO_SPAM_" .. k, "won2")
    end
    add("LOOT_ROLL_YOU_WON", "youwon")
    add("LOOT_ROLL_WON", "won")
    add("LOOT_ROLL_ALL_PASSED", "allpass")
    -- 예비: "○○님이 아이템을 획득했습니다" (굴림 결과 줄이 안 잡힐 때 누가 가져갔는지)
    add("LOOT_ITEM", "got")
    add("LOOT_ITEM_SELF", "gotself")
end

-- 같은 템이 여러 개면 아직 안 끝난 것 중 먼저 나온 것
local function FindEntry(link)
    local id = ItemID(link)
    if not id then return end
    local best
    for _, e in pairs(entries) do
        if ItemID(e.link) == id and not e.winner and not e.allPassed then
            if not best or e.id < best.id then best = e end
        end
    end
    return best
end

-- 기록: 게임 글 모양 + 못 알아들은 줄 (결과가 안 잡힐 때 원인 찾기용, 저장 파일에 최근 40줄)
local function RollDbg(kind, msg)
    ns.db.rolldbg = ns.db.rolldbg or {}
    local d = ns.db.rolldbg
    if kind == "fmt" then
        d.fmt = {}
        for k, v in pairs(_G) do
            if type(k) == "string" and k:find("^LOOT_ROLL_") and type(v) == "string" then d.fmt[k] = v end
        end
        return
    end
    d.lines = d.lines or {}
    table.insert(d.lines, date("%H:%M:%S") .. " [" .. kind .. "] " .. (msg or ""):gsub("|", "!"))
    while #d.lines > 40 do table.remove(d.lines, 1) end
end
ns.RollDbg = RollDbg

----------------------------------------------------------------------
-- 블랙리스트 굴림 알림: 블랙리스트가 입찰/차비하면 주사위 창 위에 빨간 띠 + 경고음 (나만 보여요)
----------------------------------------------------------------------
do
    local BH, BGAP, LIFE = 40, 4, 8
    local holder, pool, shown = nil, {}, {}
    local lastSnd = 0
    local SOUNDS = { warn = "leel_black_warn.ogg", chime = "leel_black_chime.ogg",
                     ding = function() return SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959 end,
                     alarm = function() return (SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3) or 12889 end }
    local function Opt()
        local d = DB()
        if d.blackAlert == nil then d.blackAlert = true end
        if not d.blackSnd2 then d.blackSound = "warn"; d.blackSnd2 = true end   -- 르엘 경고음을 기본으로
        return d
    end
    local function Sound(force)
        local k = Opt().blackSound
        if k == "off" or not SOUNDS[k] then return end
        local now = GetTime()
        if not force and now - lastSnd < 1.5 then return end
        lastSnd = now
        local snd = SOUNDS[k]
        if type(snd) == "string" then
            if PlaySoundFile then pcall(PlaySoundFile, ns.MEDIA .. snd, "Master") end
        elseif PlaySound then pcall(PlaySound, snd(), "Master") end
    end
    ns.RollBlackSound = function() Sound(true) end

    local function Place()
        if not holder then return end
        holder:ClearAllPoints()
        local a = _G.LeelUI_RollAnchor
        holder:SetScale(Scale())
        if a and a:IsShown() then
            holder:SetPoint("BOTTOMLEFT", a, "TOPLEFT", 0, 5)
        elseif badge and badge:IsShown() then
            holder:SetPoint("BOTTOM", badge, "TOP", 0, 6)
        else
            holder:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
        end
    end
    local function Layout()
        Place()
        local y = 0
        for i = #shown, 1, -1 do   -- 새 띠가 아래(주사위 창 쪽)
            local f = shown[i]
            f:ClearAllPoints(); f:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, y)
            y = y + BH + BGAP
        end
        holder:SetHeight(math.max(1, y))
    end
    local function Drop(f)
        f:Hide(); f.key = nil
        for i, x in ipairs(shown) do if x == f then table.remove(shown, i) break end end
        pool[#pool + 1] = f
        Layout()
    end
    local function New()
        local f = table.remove(pool)
        if f then return f end
        f = CreateFrame("Button", nil, holder)
        f:SetSize(W, BH)
        -- 주사위 카드와 같은 판: 어두운 판 + 옅은 빨간 테 + 왼쪽에서 번지는 빨간 빛
        f.rim = ns.RoundRect(f, 13, { 1, 0.42, 0.5 }, "BACKGROUND", -1, -1); f.rim:SetColor({ 1, 0.42, 0.5 }, 0.42)
        f.bg = ns.RoundRect(f, 13, { 0.133, 0.094, 0.090 }, "BACKGROUND", 0, 0); f.bg:SetColor({ 0.133, 0.094, 0.090 }, 0.97)
        f.wash = f:CreateTexture(nil, "BORDER"); f.wash:SetTexture(ns.WHITE)
        f.wash:SetPoint("TOPLEFT", 2, -2); f.wash:SetPoint("BOTTOMLEFT", 2, 2); f.wash:SetWidth(120)
        pcall(f.wash.SetGradient, f.wash, "HORIZONTAL", CreateColor(1, 0.42, 0.5, 0.16), CreateColor(1, 0.42, 0.5, 0))
        -- 템 아이콘 (등급 색 가는 테)
        f.ring = f:CreateTexture(nil, "ARTWORK"); f.ring:SetTexture(ns.MEDIA .. "circle"); f.ring:SetSize(29, 29); f.ring:SetPoint("LEFT", 7, 0)
        f.ringIn = f:CreateTexture(nil, "ARTWORK", nil, 1); f.ringIn:SetTexture(ns.MEDIA .. "circle"); f.ringIn:SetSize(26, 26)
        f.ringIn:SetPoint("CENTER", f.ring); f.ringIn:SetVertexColor(0.08, 0.06, 0.06, 1)
        f.ic = f:CreateTexture(nil, "OVERLAY"); f.ic:SetSize(24, 24); f.ic:SetPoint("CENTER", f.ring)
        if f.ic.SetMask then pcall(f.ic.SetMask, f.ic, ns.MEDIA .. "circle") end
        -- 블랙 표시: 아이콘 오른쪽 아래 작은 빨간 동그라미
        f.banBg = f:CreateTexture(nil, "OVERLAY", nil, 2); f.banBg:SetTexture(ns.MEDIA .. "circle"); f.banBg:SetSize(13, 13)
        f.banBg:SetPoint("CENTER", f.ring, "BOTTOMRIGHT", -3, 3); f.banBg:SetVertexColor(1, 0.42, 0.5, 1)
        f.ban = f:CreateTexture(nil, "OVERLAY", nil, 3); f.ban:SetTexture(ns.MEDIA .. "roll_ban"); f.ban:SetSize(9, 9)
        f.ban:SetPoint("CENTER", f.banBg); f.ban:SetVertexColor(0.165, 0.063, 0.082)
        -- 숫자 (주사위 카드 숫자와 같은 글꼴)
        f.num = f:CreateFontString(nil, "OVERLAY"); f.num:SetFont(ns.NUM or ns.FONT, 20, ""); f.num:SetPoint("RIGHT", -10, 0)
        f.num:SetShadowColor(0, 0, 0, 0.85); f.num:SetShadowOffset(1, -1)
        f.top = ns.Font(f, 9.5, { 1, 0.56, 0.64 }); f.top:SetPoint("BOTTOM", f.num, "TOP", 0, -3)
        -- 1줄: 이름 + 입찰/차비 칩 · 2줄: 템 이름 · 이유
        f.who = ns.Font(f, 12.5, { 1, 0.56, 0.64 }); f.who:SetPoint("BOTTOMLEFT", f, "LEFT", 43, 1)
        f.chip = CreateFrame("Frame", nil, f); f.chip:SetSize(30, 15); f.chip:SetPoint("LEFT", f.who, "RIGHT", 5, 0)
        f.chip.bg = ns.RoundRect(f.chip, 5, { 1, 1, 1 }, "BACKGROUND", 0, 0)
        f.chip.fs = ns.Font(f.chip, 10); f.chip.fs:SetPoint("CENTER", 0, 0)
        f.why = ns.Font(f, 10, { 0.62, 0.54, 0.52 }); f.why:SetPoint("LEFT", f.chip, "RIGHT", 6, 0); f.why:SetJustifyH("LEFT"); f.why:SetWordWrap(false)
        f.why:SetPoint("RIGHT", f.num, "LEFT", -8, 0)
        f.item = ns.Font(f, 11); f.item:SetPoint("TOPLEFT", f, "LEFT", 43, -2); f.item:SetJustifyH("LEFT"); f.item:SetWordWrap(false)
        f.item:SetPoint("RIGHT", f.num, "LEFT", -8, 0)
        -- 남은 시간 (아래 가는 분홍 줄)
        f.barbg = f:CreateTexture(nil, "ARTWORK"); f.barbg:SetTexture(ns.WHITE); f.barbg:SetHeight(1.5)
        f.barbg:SetPoint("BOTTOMLEFT", 14, 2); f.barbg:SetPoint("BOTTOMRIGHT", -14, 2); f.barbg:SetVertexColor(1, 0.42, 0.5, 0.15)
        f.bar = f:CreateTexture(nil, "OVERLAY"); f.bar:SetTexture(ns.WHITE); f.bar:SetHeight(1.5)
        f.bar:SetPoint("BOTTOMLEFT", 14, 2); f.bar:SetVertexColor(1, 0.56, 0.64, 0.75)
        f:RegisterForClicks("AnyUp")
        f:SetScript("OnClick", function(s2) Drop(s2) end)
        f:SetScript("OnEnter", function(s2)
            s2.hold = true; s2.rim:SetColor({ 1, 0.42, 0.5 }, 0.8)
            GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
            if s2.link then pcall(GameTooltip.SetHyperlink, GameTooltip, s2.link) else GameTooltip:AddLine(s2.iname or "") end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffff6b7f블랙리스트|r  " .. (s2.whoName or ""))
            if s2.note then GameTooltip:AddLine(s2.note, 1, 0.6, 0.66, true) end
            GameTooltip:AddLine("클릭 = 닫기", 0.6, 0.55, 0.53); GameTooltip:Show()
        end)
        f:SetScript("OnLeave", function(s2) s2.hold = nil; s2.rim:SetColor({ 1, 0.42, 0.5 }, 0.42); GameTooltip:Hide() end)
        f:SetScript("OnUpdate", function(s2, el)
            if s2.hold then s2:SetAlpha(1) return end
            s2.left = (s2.left or LIFE) - el
            local p = math.max(0, s2.left / LIFE)
            s2.bar:SetWidth(math.max(0.01, (W - 28) * p))
            -- 들어올 때 살짝 밀려 나오고, 끝날 때 흐려져요
            local age = LIFE - s2.left
            if age < 0.18 then s2:SetAlpha(age / 0.18) elseif s2.left < 0.6 then s2:SetAlpha(math.max(0, s2.left / 0.6)) else s2:SetAlpha(1) end
            if s2.left <= 0 then Drop(s2) end
        end)
        return f
    end

    local function IsTop(e, who)
        local best, bw
        for name, r in pairs(e.rolls or {}) do
            if r.n and r.t ~= "pass" then
                local sc = (RANK[r.t] or 0) * 1000 + r.n
                if not best or sc > best then best, bw = sc, name end
            end
        end
        return bw == who
    end

    -- e = 경매 자료 (link · texture · quality · name) · who = 이름 · t = need/greed · n = 숫자
    function ns.RollBlackAlert(e, who, t, n, force)
        if not force and not Opt().blackAlert then return end
        if t == "pass" or not n then return end
        local b = ns.BlackGet and ns.BlackGet(who)
        if not b and not force then return end
        b = b or { note = "템 먹튀 (미리 보기)" }
        -- A안: 화난 토끼가 말풍선으로 알려줘요 (토끼 단추가 없을 때만 예전 빨간 띠)
        if ns.RollTalkBlackRoll then
            local q = QColor(e.quality)
            local said = ns.RollTalkBlackRoll({
                key = (e.id or e.link or "") .. who, who = who, t = t, n = n, link = e.link,
                item = "|cff" .. Hex(q) .. "[" .. (e.name or (e.link and e.link:match("%[(.-)%]")) or "템") .. "]|r",
                top = IsTop(e, who), note = (b.note and b.note ~= "") and b.note or nil, cls = b.cls })
            if said then
                Sound()
                if Opt().blackChat ~= false then
                    local tc = (t == "need") and "8fe899" or "f3c55a"
                    P(("|cffff6b7f블랙리스트 %s|r님이 %s |cff%s%s|r → |cffffffff%d|r%s"):format(who, e.link or (e.name or "템"), tc, TYPE_TXT[t] or "", n, (b.note and b.note ~= "") and ("  |cff998a86(" .. b.note .. ")|r") or ""))
                end
                return
            end
        end
        if not holder then
            holder = CreateFrame("Frame", "LeelUI_RollBlack", UIParent)
            holder:SetSize(W, 1); holder:SetFrameStrata("DIALOG"); holder:SetFrameLevel(50)
        end
        local key = (e.id or e.link or "") .. who
        local f
        for _, x in ipairs(shown) do if x.key == key then f = x end end
        if not f then f = New(); shown[#shown + 1] = f end
        f.key, f.link, f.left = key, e.link, LIFE
        f:SetAlpha(0)
        local q = QColor(e.quality)
        f.ring:SetVertexColor(q[1], q[2], q[3], 1)
        f.ic:SetTexture(e.texture or 134400)
        local need = (t == "need")
        local cc = need and { 0.56, 0.91, 0.60 } or GOLD
        f.who:SetText(who)
        f.chip.fs:SetText(TYPE_TXT[t] or ""); f.chip.fs:SetTextColor(cc[1], cc[2], cc[3])
        f.chip:SetWidth(f.chip.fs:GetStringWidth() + 10)
        f.chip.bg:SetColor(cc, 0.16)
        local top = IsTop(e, who)
        local why = (b.note and b.note ~= "") and b.note or nil
        f.why:SetText(why or "블랙리스트")
        f.iname = e.name or (e.link and e.link:match("%[(.-)%]")) or "템"
        f.item:SetText(f.iname); f.item:SetTextColor(q[1], q[2], q[3])
        f.whoName, f.note = who, why
        f.num:SetText(n)
        f.top:SetText(top and "1등" or "")
        if top then f.num:SetTextColor(1, 0.42, 0.5) else f.num:SetTextColor(1, 0.82, 0.85) end
        f:Show()
        Layout()
        Sound()
        if Opt().blackChat ~= false then
            P(("|cffff6b7f블랙리스트 %s|r님이 %s |cff%s%s|r → |cffffffff%d|r%s"):format(who, e.link or (e.name or "템"), tc, TYPE_TXT[t] or "", n, why and ("  |cff998a86(" .. why .. ")|r") or ""))
        end
    end
    ns.RollBlackPlace = Place
    function ns.RollBlackTest()
        local e = { id = "t" .. GetTime(), name = "소금선견자의 투구", quality = 2, texture = 133071, rolls = { ["슈엘"] = { t = "greed", n = 42 } } }
        local first = shown[1]
        ns.RollBlackAlert(e, "슈엘", "greed", 42, true)
        local e2 = { id = "u" .. GetTime(), name = "용의 송곳니 단검", quality = 4, texture = 135641, rolls = { ["슈엘"] = { t = "need", n = 87 }, ["르엘"] = { t = "need", n = 64 } } }
        C_Timer.After(0.6, function() ns.RollBlackAlert(e2, "슈엘", "need", 87, true) end)
    end
end

local function OnLootMsg(msg)
    if not PATS then BuildPats() end
    local hit = false
    for _, m in ipairs(PATS) do
        local a = Match(m, msg)
        if a then
            hit = true
            if m.kind ~= "got" and m.kind ~= "gotself" then RollDbg(m.kind, msg) end
            if m.kind == "rolled" then
                local e = FindEntry(a[2]); if not e then return end
                local who = Short(a[3])
                e.rolls[who] = { t = m.t, n = tonumber(a[1]) }
                Refresh(e)
                if ns.RollBlackAlert and m.t ~= "pass" then ns.RollBlackAlert(e, who, m.t, tonumber(a[1])) end
            elseif m.kind == "self" then
                local e = FindEntry(a[1]); if not e then return end
                local r = e.rolls[e.me] or {}
                r.t = m.t; e.rolls[e.me] = r
                if not e.mine then e.mine = m.t end
                Refresh(e)
            elseif m.kind == "chose" then
                local e = FindEntry(a[2]); if not e then return end
                local who = Short(a[1])
                local r = e.rolls[who] or {}
                r.t = m.t; e.rolls[who] = r
                Refresh(e)
            elseif m.kind == "youwon" or m.kind == "won" or m.kind == "youwon2" or m.kind == "won2" then
                -- won = (이름, 템) · youwon = (템) · won2 = (이름, 숫자, 템) · youwon2 = (숫자, 템)
                local link = (m.kind == "youwon" and a[1]) or (m.kind == "won" and a[2]) or (m.kind == "youwon2" and a[2]) or a[3]
                local e = FindEntry(link); if not e then return end
                local mine = (m.kind == "youwon" or m.kind == "youwon2")
                e.winner = mine and e.me or Short(a[1])
                local n = (m.kind == "youwon2" and tonumber(a[1])) or (m.kind == "won2" and tonumber(a[2]))
                if n then local r = e.rolls[e.winner] or {}; r.n = r.n or n; r.t = r.t or e.mine or "need"; e.rolls[e.winner] = r end
                e.done = true
                Refresh(e)
                FinishLater(e, 10)   -- 누가 먹었는지 충분히 보이게
                if mine and ns.RollGreetWin then ns.RollGreetWin(e, n or (e.rolls[e.me] and e.rolls[e.me].n)) end
            elseif m.kind == "got" or m.kind == "gotself" then
                -- 굴림 중인 템일 때만 (그냥 주운 템은 무시)
                local link = (m.kind == "gotself") and a[1] or a[2]
                local e = FindEntry(link)
                if not e or not next(e.rolls) then return end
                e.winner = (m.kind == "gotself") and e.me or Short(a[1])
                e.done = true
                Refresh(e)
                FinishLater(e, 10)
            elseif m.kind == "allpass" then
                local e = FindEntry(a[1]); if not e then return end
                e.allPassed = true; e.done = true
                Refresh(e)
                FinishLater(e, 2.5)
            end
            return
        end
    end
    if not hit and msg:find("item:") and next(entries) then RollDbg("miss", msg) end
end

----------------------------------------------------------------------
-- 블리자드 기본 창 끄기 / 되살리기
----------------------------------------------------------------------
-- 게임 기본 주사위 창 숨기기: 이벤트를 듣는 곳이 판마다 달라서
--   1) START_LOOT_ROLL 을 듣는 프레임에서 빼고  2) 그래도 뜨는 기본 창은 뜨자마자 숨겨요
local function LootFrames()
    local out = {}
    for i = 1, (NUM_GROUP_LOOT_FRAMES or 4) do local g = _G["GroupLootFrame" .. i]; if g then out[#out + 1] = g end end
    return out
end
local function Blizz(off)
    local list = { UIParent, _G.GroupLootContainer, _G.GroupLootFrameContainer }
    for _, g in ipairs(LootFrames()) do list[#list + 1] = g end
    for _, f in pairs(list) do
        if f and f.IsEventRegistered then
            if off and f:IsEventRegistered("START_LOOT_ROLL") then
                f:UnregisterEvent("START_LOOT_ROLL"); f.leelRollOff = true
            elseif not off and f.leelRollOff then
                f:RegisterEvent("START_LOOT_ROLL"); f.leelRollOff = nil
            end
        end
    end
    -- 그래도 뜨는 창은 뜨자마자 숨김 (주사위는 그대로 남아 르엘 창에서 굴려요)
    for _, g in ipairs(LootFrames()) do
        if not g.leelHooked then
            g.leelHooked = true
            g:HookScript("OnShow", function(self)
                if DB().on then self:SetAlpha(0); self:Hide() else self:SetAlpha(1) end
            end)
        end
        if off and g:IsShown() then g:SetAlpha(0); g:Hide() end
        if not off then g:SetAlpha(1) end
    end
    local c = _G.GroupLootContainer
    if c and not c.leelHooked then
        c.leelHooked = true
        c.leelMouse = c:IsMouseEnabled()
        -- 투명하게만 하면 클릭을 계속 받아서 화면 가운데 클릭 · 룻 · 시점 돌리기가 막혀요 → 클릭도 꺼요
        c:HookScript("OnShow", function(self)
            if DB().on then self:SetAlpha(0); pcall(self.EnableMouse, self, false) else self:SetAlpha(1) end
        end)
    end
    if c then
        c:SetAlpha(off and 0 or 1)
        if off then pcall(c.EnableMouse, c, false) elseif c.leelMouse ~= nil then pcall(c.EnableMouse, c, c.leelMouse) end
        if off and c:IsShown() and #LootFrames() > 0 then
            local any = false
            for _, g in ipairs(LootFrames()) do if g:IsShown() then any = true end end
            if not any then pcall(c.Hide, c) end
        end
    end
end
if hooksecurefunc and _G.GroupLootFrame_OpenNewFrame then
    hooksecurefunc("GroupLootFrame_OpenNewFrame", function(id)
        if not DB().on then return end
        for _, g in ipairs(LootFrames()) do
            if g:IsShown() then g:SetAlpha(0); g:Hide() end
        end
    end)
end
-- 클래식 판: 기본 창이 직접 START_LOOT_ROLL 을 받아도 다음 화면에 숨김
local hideAfter = CreateFrame("Frame")
hideAfter:RegisterEvent("START_LOOT_ROLL")
hideAfter:SetScript("OnEvent", function()
    if not DB().on then return end
    C_Timer.After(0, function()
        for _, g in ipairs(LootFrames()) do if g:IsShown() then g:SetAlpha(0); g:Hide() end end
        local c = _G.GroupLootContainer
        if c then c:SetAlpha(0); pcall(c.EnableMouse, c, false) end
    end)
end)

-- 블리자드 주사위 획득 알림 ("다음을 획득했습니다 · 주사위 63"): 르엘 "획득!" 알림과 두 번 떠서 숨겨요
local function WonFrames()
    local out = {}
    local sys = _G.LootWonAlertSystem
    local pool = sys and (sys.alertFramePool or sys.pool)
    if pool and pool.EnumerateActive then for f in pool:EnumerateActive() do out[#out + 1] = f end end
    for i = 1, 8 do local f = _G["LootWonAlertFrame" .. i]; if f then out[#out + 1] = f end end
    return out
end
local function HideWonNow()
    for _, f in ipairs(WonFrames()) do
        if f:IsShown() and (f.rollType or f.RollTypeIcon or f.RollValue) then
            pcall(f.SetAlpha, f, 0); pcall(f.Hide, f)
        end
    end
end
local function BlizzWon(off)
    local af = _G.AlertFrame
    if af and af.IsEventRegistered then
        if off and af:IsEventRegistered("LOOT_ITEM_ROLL_WON") then af:UnregisterEvent("LOOT_ITEM_ROLL_WON"); af.leelWonOff = true
        elseif not off and af.leelWonOff then af:RegisterEvent("LOOT_ITEM_ROLL_WON"); af.leelWonOff = nil end
    end
    local sys = _G.LootWonAlertSystem
    if sys and not sys.leelHooked and hooksecurefunc and sys.AddAlert then
        sys.leelHooked = true
        hooksecurefunc(sys, "AddAlert", function(_, _, _, rollType, roll)
            if DB().on and DB().hideWon ~= false and (rollType or roll) then C_Timer.After(0, HideWonNow) end
        end)
    end
end
ns.RollBlizzWon = function() BlizzWon(DB().on and DB().hideWon ~= false) end

function ns.RollApply()
    local on = DB().on
    Blizz(on)
    BlizzWon(on and DB().hideWon ~= false)
    if not on then
        for _, f in ipairs({ unpack(active) }) do Free(f) end
        wipe(entries)
        if badge then PaintBadge() end
    else
        Anchor(); PaintBadge()
        for _, f in ipairs(active) do Paint(f) end
        if anchor then Relayout() end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("START_LOOT_ROLL")
ev:RegisterEvent("CANCEL_LOOT_ROLL")
ev:RegisterEvent("CHAT_MSG_LOOT")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(ev.RegisterEvent, ev, "GET_ITEM_INFO_RECEIVED")
pcall(ev.RegisterEvent, ev, "CANCEL_ALL_LOOT_ROLLS")
ev:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "PLAYER_LOGIN" then
        Blizz(DB().on)
        BlizzWon(DB().on and DB().hideWon ~= false)
        C_Timer.After(3, function() BlizzWon(DB().on and DB().hideWon ~= false) end)   -- AlertFrame이 늦게 준비되는 판
        pcall(RollDbg, "fmt")
        if DB().on then Anchor(); PaintBadge() end
        return
    end
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        if badge then PaintBadge() elseif DB().on then Anchor(); PaintBadge() end
        if ns.BlackCheckGroup then ns.BlackCheckGroup() end
        if ns.PartyBlackRefresh then pcall(ns.PartyBlackRefresh) end
        return
    end
    if not DB().on then return end
    if event == "START_LOOT_ROLL" then
        OnStart(a1, a2)
    elseif event == "CANCEL_LOOT_ROLL" then
        local e = entries[a1]
        if e then
            e.done = true
            Refresh(e)
            -- 보드가 열려 있으면 결과(획득 글)를 조금 기다렸다가 닫기
            if not (CardFor(e) and BoardOn(e)) then HideCardLater(e, 1) end
            FinishLater(e, (CardFor(e) and BoardOn(e)) and 5 or 3)
        end
    elseif event == "CANCEL_ALL_LOOT_ROLLS" then
        for _, e in pairs(entries) do if not e.test then e.done = true; FinishLater(e, 2) end end
    elseif event == "CHAT_MSG_LOOT" then
        if type(a1) == "string" then OnLootMsg(a1) end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        for _, f in ipairs(active) do
            local e = f.e
            if e and e.waiting and FillItem(e) then
                if e.name == "불러오는 중…" then e.name = GetItemInfo(e.link) or e.name end
                if ns.GearForget then ns.GearForget(e.link) end
                if not e.mine then e.rec, e.whyCol, e.why = Recommend(e) end
                if not e.why then
                    local _, _, _, _, _, itype, isub = GetItemInfo(e.link)
                    if itype then e.why = (isub and isub ~= itype) and (itype .. " · " .. isub) or itype; e.whyCol = { 0.72, 0.65, 0.63 } end
                end
                Paint(f)
            end
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        for _, f in ipairs(active) do
            local e = f.e
            if e and not e.mine then e.rec, e.whyCol, e.why = Recommend(e); Paint(f) end
        end
    end
end)

----------------------------------------------------------------------
-- 미리 보기: /르엘주사위 테스트 (내가 낀 장비로 가짜 템 3개, 가짜 파티원 4명)
----------------------------------------------------------------------
local testID = 9000
function ns.RollTestFinish(e)
    if e.winner then return end
    local best
    for name, r in pairs(e.rolls) do
        if r.n and r.t ~= "pass" then
            if not best or RANK[r.t] > RANK[best.t] or (RANK[r.t] == RANK[best.t] and r.n > best.n) then best = { name = name, t = r.t, n = r.n } end
        end
    end
    if best then e.winner = best.name else e.allPassed = true end
    e.done = true
    Refresh(e)
    FinishLater(e, 4)
end

function ns.RollTest()
    if not DB().on then P("주사위 창이 꺼져 있어요. 허브에서 켜 주세요."); return end
    test = true
    local picks = {}
    -- 가방 속 장비부터 (추천이 보이게), 모자라면 지금 낀 장비
    local CC = C_Container or {}
    local getLink = CC.GetContainerItemLink or _G.GetContainerItemLink
    local slots = CC.GetContainerNumSlots or _G.GetContainerNumSlots
    local skip = { INVTYPE_BAG = true, INVTYPE_AMMO = true, INVTYPE_TABARD = true, INVTYPE_BODY = true, INVTYPE_QUIVER = true, INVTYPE_NON_EQUIP_IGNORE = true, INVTYPE_NON_EQUIP = true, [""] = true }
    if getLink and slots then
        for bag = 0, 4 do
            for sl = 1, (slots(bag) or 0) do
                local l = getLink(bag, sl)
                if l and #picks < 3 and GetItemInfoInstant then
                    local ok, _, _, _, loc = pcall(GetItemInfoInstant, l)
                    if ok and type(loc) == "string" and loc:find("^INVTYPE_") and not skip[loc] then picks[#picks + 1] = l end
                end
            end
        end
    end
    for _, sl in ipairs({ 11, 16, 1, 5, 7, 10 }) do
        if #picks >= 3 then break end
        local l = GetInventoryItemLink and GetInventoryItemLink("player", sl)
        if l then picks[#picks + 1] = l end
    end
    if #picks == 0 then P("미리 보기는 장비를 하나라도 끼고 있어야 해요."); return end
    local fakes = { "도적토끼", "루루", "방패곰", "빛의망치" }
    for k, link in ipairs(picks) do
        testID = testID + 1
        local name, _, quality, _, _, _, _, _, _, tex = GetItemInfo(link)
        local e = { id = testID, link = link, texture = tex, name = name, count = 1, quality = math.max(2, quality or 2),
            canNeed = true, total = 30000, endAt = GetTime() + 30, test = true }
        Open(e)
        -- 가짜 파티원이 하나씩 굴려요
        for j, who in ipairs(fakes) do
            C_Timer.After(1.2 + j * 1.6 + k * 0.4, function()
                if not entries[e.id] or e.done then return end
                local t = (j == 3 and "pass") or ((j + k) % 3 == 0 and "greed") or "need"
                e.rolls[who] = { t = t, n = (t ~= "pass") and math.random(1, 100) or nil }
                Refresh(e)
            end)
        end
    end
    C_Timer.After(32, function() test = false end)
end
-- 미리 보기 바로 끝내기 (허브 [실제 자리에서 보기] → 허브로 돌아갈 때)
function ns.RollTestStop()
    for id, e in pairs(entries) do
        if e.test then
            e.done = true
            local f = CardFor(e)
            if f then Free(f) end
            entries[id] = nil
        end
    end
    test = false
    if ns.RollPaintBadge then ns.RollPaintBadge() end
end

----------------------------------------------------------------------
-- 르엘 주사위 기록장 (토끼 뱃지 클릭)
----------------------------------------------------------------------
local LW, LH, LROW, LROWS = 430, 470, 22, 16
local logFilter, logOff = "all", 0
local logRows = {}

local function LogList()
    local out, lastKey = {}, nil
    for _, it in ipairs(LogDB()) do
        local ok = true
        if logFilter == "won" then ok = it.win and it.win == it.me
        elseif logFilter == "need" then ok = it.mine == "need" end
        if ok then
            local key = date("%m/%d", it.at) .. "|" .. (it.zone or "")
            if key ~= lastKey then
                lastKey = key
                out[#out + 1] = { head = true, text = date("%m월 %d일", it.at):gsub("^0", ""):gsub(" 0", " ") .. "  ·  " .. (it.zone ~= "" and it.zone or "어딘가") }
            end
            out[#out + 1] = { it = it }
        end
    end
    return out
end

local function LogRow(i)
    if logRows[i] then return logRows[i] end
    local r = CreateFrame("Button", nil, logWin.list)
    r:SetHeight(LROW)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * LROW); r:SetPoint("RIGHT", 0, 0)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.hl = r:CreateTexture(nil, "HIGHLIGHT"); r.hl:SetTexture(ns.WHITE); r.hl:SetAllPoints(); r.hl:SetVertexColor(1, 0.561, 0.639, 0.10)
    r.head = ns.Font(r, 12, { 1, 0.878, 0.541 }); r.head:SetPoint("LEFT", 2, -2)
    r.time = r:CreateFontString(nil, "OVERLAY"); r.time:SetFont(ns.NUM or ns.FONT, 13, ""); r.time:SetPoint("LEFT", 4, 0)
    r.time:SetTextColor(0.54, 0.48, 0.46)
    r.ic = r:CreateTexture(nil, "ARTWORK"); r.ic:SetSize(18, 18); r.ic:SetPoint("LEFT", 46, 0); r.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = ns.Font(r, 12); r.name:SetPoint("LEFT", r.ic, "RIGHT", 7, 0); r.name:SetWidth(180); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.win = ns.Font(r, 12); r.win:SetPoint("RIGHT", -6, 0); r.win:SetJustifyH("RIGHT")
    r:SetScript("OnEnter", function(s)
        local it = s.it; if not it then return end
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        if it.link then pcall(GameTooltip.SetHyperlink, GameTooltip, it.link) end
        GameTooltip:AddLine(" ")
        if #it.rolls == 0 then GameTooltip:AddLine("굴린 기록 없음", 0.6, 0.55, 0.53) end
        for _, x in ipairs(it.rolls) do
            GameTooltip:AddDoubleLine("|cff" .. (x.c or "d8c6c1") .. x.name .. "|r  " .. (TYPE_TXT[x.t] or "고민 중") .. ((ns.IsBlack and ns.IsBlack(x.name)) and "  |cffff6b7f블랙리스트|r" or ""),
                x.n and tostring(x.n) or "-", 0.85, 0.78, 0.76, 1, 0.88, 0.54)
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(s, btn)
        local it = s.it
        if not it then return end
        if btn == "RightButton" then ns.RollLogMenu(s, it); return end
        if it.link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then ChatEdit_InsertLink(it.link) end
    end)
    logRows[i] = r
    return r
end

-- 기록 줄 오른쪽 클릭: 같이 굴린 사람 목록 → 블랙리스트에 넣기 / 빼기
local logMenu
function ns.RollLogMenu(owner, it)
    if not logMenu then
        local m = CreateFrame("Frame", nil, UIParent)
        m:SetFrameStrata("FULLSCREEN_DIALOG"); m:SetClampedToScreen(true); m:EnableMouse(true)
        m.tk = Ticket(m, 10, 4)
        m.title = ns.Font(m, 11, { 1, 0.42, 0.5 }); m.title:SetPoint("TOPLEFT", 14, -9)
        m.btns = {}
        m:SetScript("OnUpdate", function(s2, el)
            if s2:IsMouseOver(8, -8, -8, 8) then s2.idle = 0 else s2.idle = (s2.idle or 0) + el; if s2.idle > 1.2 then s2:Hide() end end
        end)
        m:Hide()
        logMenu = m
    end
    local m = logMenu
    m.tk:Strip({ 1, 0.42, 0.5 }); m.tk:Notch(false)
    local names = {}
    for _, x in ipairs(it.rolls or {}) do if x.name ~= it.me then names[#names + 1] = x end end
    m.title:SetText(#names > 0 and "블랙리스트" or "같이 굴린 사람이 없어요")
    for _, b in ipairs(m.btns) do b:Hide() end
    for i, x in ipairs(names) do
        local b = m.btns[i]
        if not b then
            b = CreateFrame("Button", nil, m); b:SetSize(170, 20)
            b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetTexture(ns.WHITE); b.hl:SetAllPoints(); b.hl:SetVertexColor(1, 0.42, 0.5, 0.15)
            b.ban = b:CreateTexture(nil, "ARTWORK"); b.ban:SetTexture(ns.MEDIA .. "roll_ban"); b.ban:SetSize(11, 11); b.ban:SetPoint("LEFT", 2, 0)
            b.fs = ns.Font(b, 11.5); b.fs:SetPoint("LEFT", 18, 0)
            b.act = ns.Font(b, 10.5, { 1, 0.6, 0.66 }); b.act:SetPoint("RIGHT", -2, 0)
            m.btns[i] = b
        end
        b:SetPoint("TOPLEFT", 12, -24 - (i - 1) * 20)
        local black = ns.IsBlack and ns.IsBlack(x.name)
        b.fs:SetText("|cff" .. (x.c or "d8c6c1") .. x.name .. "|r  |cff8a7a76" .. (TYPE_TXT[x.t] or "") .. (x.n and (" " .. x.n) or "") .. "|r")
        b.act:SetText(black and "빼기" or "넣기")
        b.ban:SetVertexColor(black and 1 or 0.55, black and 0.42 or 0.5, black and 0.5 or 0.5)
        b:SetScript("OnClick", function() m:Hide(); if ns.BlackAsk then ns.BlackAsk(x.name) end end)
        b:Show()
    end
    m:SetSize(194, 32 + math.max(1, #names) * 20 - (#names == 0 and 20 or 0) + 4)
    local cx, cy = GetCursorPosition()
    local sc = UIParent:GetEffectiveScale()
    m:ClearAllPoints(); m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / sc + 4, cy / sc + 4)
    m.idle = 0
    m:Show()
end

function ns.RollLogPaint()
    if not (logWin and logWin:IsShown()) then return end
    local list = LogList()
    logOff = math.max(0, math.min(logOff, #list - LROWS))
    for i = 1, LROWS do
        local r = LogRow(i)
        local x = list[i + logOff]
        r.it = x and x.it
        if not x then r:Hide()
        elseif x.head then
            r:Show(); r.head:SetText(x.text); r.head:Show()
            r.time:Hide(); r.ic:Hide(); r.name:Hide(); r.win:Hide(); r:EnableMouse(false)
        else
            local it = x.it
            r:Show(); r:EnableMouse(true); r.head:Hide()
            r.time:Show(); r.ic:Show(); r.name:Show(); r.win:Show()
            r.time:SetText(date("%H:%M", it.at))
            r.ic:SetTexture(it.tex)
            local qc = QColor(it.q)
            r.name:SetText(it.name or ""); r.name:SetTextColor(qc[1], qc[2], qc[3])
            local wtxt
            if it.win then
                local wn, wc
                for _, y in ipairs(it.rolls) do if y.name == it.win then wn, wc = y.n, y.c end end
                local me = it.win == it.me
                wtxt = (me and ("|T" .. ns.MEDIA .. "crown:12:12:0:0:128:128:0:128:0:128:255:215:90|t ") or "") .. "|cff" .. (wc or "d8c6c1") .. it.win .. "|r" .. (wn and ("  |cffffe08a" .. wn .. "|r") or "")
                if not me and it.mine and it.mine ~= "pass" then
                    for _, y in ipairs(it.rolls) do if y.name == it.me and y.n then wtxt = wtxt .. "  |cffff9aa8내 " .. y.n .. "|r" end end
                end
            elseif it.all then wtxt = "|cff8a7a76모두 포기|r"
            else wtxt = "|cff8a7a76결과 모름|r" end
            r.win:SetText(wtxt)
        end
    end
    local n = 0
    for _, x in ipairs(list) do if not x.head then n = n + 1 end end
    logWin.count:SetText(n .. "개")
    logWin.empty:SetShown(n == 0)
    for _, p in ipairs(logWin.pills) do
        local on = p.key == logFilter
        p.bg:SetColor(on and C.acc or { 0.165, 0.122, 0.114 }, 1)
        local tc = on and C.ink or { 0.79, 0.70, 0.68 }
        p.fs:SetTextColor(tc[1], tc[2], tc[3]); p.fs:SetShadowColor(0, 0, 0, on and 0 or 0.85)
    end
end

local function MakeLog()
    if logWin then return logWin end
    local w = CreateFrame("Frame", "LeelUI_RollLog", UIParent)
    w:SetSize(LW, LH); w:SetPoint("CENTER", 0, 40)
    w:SetFrameStrata("DIALOG"); w:SetToplevel(true)
    w:EnableMouse(true); w:SetMovable(true); w:RegisterForDrag("LeftButton"); w:SetClampedToScreen(true)
    w:SetScript("OnDragStart", w.StartMoving); w:SetScript("OnDragStop", w.StopMovingOrSizing)
    ns.RoundPlate(w, 14, { 0.118, 0.086, 0.078, 0.97 }, { 0.29, 0.204, 0.188, 1 })
    local bun = w:CreateTexture(nil, "ARTWORK"); bun:SetTexture(ns.MEDIA .. "bunny"); bun:SetSize(26, 26); bun:SetPoint("TOPLEFT", 14, -12)
    local title = ns.Font(w, 16, C.acc); title:SetPoint("LEFT", bun, "RIGHT", 8, 0); title:SetText("르엘 주사위 기록장")
    local x = CreateFrame("Button", nil, w); x:SetSize(24, 24); x:SetPoint("TOPRIGHT", -10, -12)
    x.t = x:CreateTexture(nil, "ARTWORK"); x.t:SetTexture(ns.MEDIA .. "roll_x"); x.t:SetAllPoints(); x.t:SetVertexColor(0.79, 0.70, 0.68)
    x:SetScript("OnClick", function() w:Hide() end)
    x:SetScript("OnEnter", function(s) s.t:SetVertexColor(C.acc[1], C.acc[2], C.acc[3]) end)
    x:SetScript("OnLeave", function(s) s.t:SetVertexColor(0.79, 0.70, 0.68) end)
    -- 거르기
    w.pills = {}
    local px = 14
    for _, d in ipairs({ { "all", "전부" }, { "won", "내가 얻은 것" }, { "need", "내가 입찰한 것" } }) do
        local p = CreateFrame("Button", nil, w); p:SetHeight(22); p.key = d[1]
        p.bg = ns.RoundRect(p, 11, C.acc, "BACKGROUND", 0, 0)
        p.fs = ns.Font(p, 11.5); p.fs:SetPoint("CENTER"); p.fs:SetText(d[2]); p:SetWidth(p.fs:GetStringWidth() + 22)
        p:SetPoint("TOPLEFT", px, -48); px = px + p:GetWidth() + 6
        p:SetScript("OnClick", function() logFilter = p.key; logOff = 0; ns.RollLogPaint() end)
        w.pills[#w.pills + 1] = p
    end
    w.count = ns.Font(w, 11.5, { 0.72, 0.65, 0.63 }); w.count:SetPoint("TOPRIGHT", -16, -52)
    w.list = CreateFrame("Frame", nil, w)
    w.list:SetPoint("TOPLEFT", 12, -80); w.list:SetPoint("TOPRIGHT", -12, -80); w.list:SetHeight(LROWS * LROW)
    w.list:EnableMouseWheel(true)
    w.list:SetScript("OnMouseWheel", function(_, d) logOff = logOff - d * 3; ns.RollLogPaint() end)
    w.empty = ns.Font(w, 12.5, { 0.62, 0.55, 0.53 }); w.empty:SetPoint("TOP", w.list, "TOP", 0, -60)
    w.empty:SetText("아직 기록이 없어요.\n파티에서 주사위를 굴리면 여기에 쌓여요."); w.empty:SetJustifyH("CENTER")
    -- 아래: 도움말 · 지우기 (두 번 눌러야)
    local hint = ns.Font(w, 10.5, { 0.54, 0.48, 0.46 }); hint:SetPoint("BOTTOMLEFT", 16, 14)
    hint:SetText("마우스 = 모두의 숫자 · 오른쪽 클릭 = 블랙리스트 · Shift+클릭 = 링크")
    local clr = CreateFrame("Button", nil, w); clr:SetSize(80, 22); clr:SetPoint("BOTTOMRIGHT", -14, 10)
    clr.bg = ns.RoundRect(clr, 11, { 0.165, 0.122, 0.114 }, "BACKGROUND", 0, 0)
    clr.fs = ns.Font(clr, 11, { 0.79, 0.70, 0.68 }); clr.fs:SetPoint("CENTER"); clr.fs:SetText("기록 지우기")
    clr:SetScript("OnClick", function(s)
        if s.armed then
            wipe(LogDB()); s.armed = nil; s.fs:SetText("기록 지우기"); s.fs:SetTextColor(0.79, 0.70, 0.68); ns.RollLogPaint()
        else
            s.armed = true; s.fs:SetText("한 번 더!"); s.fs:SetTextColor(1, 0.42, 0.5)
            C_Timer.After(3, function() if s.armed then s.armed = nil; s.fs:SetText("기록 지우기"); s.fs:SetTextColor(0.79, 0.70, 0.68) end end)
        end
    end)
    w:SetScript("OnShow", function() logOff = 0; ns.RollLogPaint(); PaintBadge() end)
    w:SetScript("OnHide", function() PaintBadge() end)
    tinsert(UISpecialFrames, "LeelUI_RollLog")
    w:Hide()
    logWin = w
    return w
end

function ns.RollLog(show)
    local w = MakeLog()
    if show == nil then show = not w:IsShown() end
    w:SetShown(show)
end

----------------------------------------------------------------------
-- 블랙리스트 (나만 보는 메모): 파티에 들어오면 알림 · 주사위 보드 · 파티 창 표시
----------------------------------------------------------------------
local function BL() ns.db.black = ns.db.black or {}; return ns.db.black end
local function Key(name) return name and Short(name) or nil end
function ns.BlackGet(name) local k = Key(name); return k and BL()[k] end
function ns.IsBlack(name) return ns.BlackGet(name) ~= nil end

local function ClassOfName(name)
    if UnitExists("target") and Short(UnitName("target")) == name and UnitIsPlayer("target") then local _, c = UnitClass("target"); return c end
    local units = { "player" }
    if IsInRaid and IsInRaid() then for i = 1, 40 do units[#units + 1] = "raid" .. i end else for i = 1, 4 do units[#units + 1] = "party" .. i end end
    for _, u in ipairs(units) do
        if UnitExists(u) and Short(UnitName(u)) == name then local _, c = UnitClass(u); return c end
    end
end
local function ClassHex(cls)
    local c = cls and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(cls)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]))
    if c then return { c.r, c.g, c.b } end
    return { 0.85, 0.78, 0.76 }
end

local function BlackChanged()
    if ns.PartyBlackRefresh then pcall(ns.PartyBlackRefresh) end
    if ns.BlackPaint then ns.BlackPaint() end
    for _, f in ipairs(active) do if f.e then Paint(f) end end
    if ns.RollFanPaint then ns.RollFanPaint() end
end

function ns.BlackAdd(name, note)
    local k = Key(name)
    if not k or k == "" then return end
    if k == Short(UnitName("player")) then P("나는 넣을 수 없어요."); return end
    local d = BL()
    local old = d[k]
    d[k] = { note = note or (old and old.note) or "", at = old and old.at or time(), cls = ClassOfName(k) or (old and old.cls), met = old and old.met or 0 }
    P("|cffff6b7f" .. k .. "|r 님을 블랙리스트에 넣었어요." .. ((note and note ~= "") and (" (" .. note .. ")") or ""))
    BlackChanged()
end
function ns.BlackRemove(name)
    local k = Key(name)
    if k and BL()[k] then BL()[k] = nil; P(k .. " 님을 블랙리스트에서 뺐어요."); BlackChanged() end
end

-- 이유를 물어보고 넣기 (이미 있으면 빼기 물어보기)
StaticPopupDialogs["LEELUI_BLACK_ADD"] = {
    text = "|cffff6b7f%s|r 님을 블랙리스트에 넣을까요?\n이유 (비워도 돼요)",
    button1 = "넣기", button2 = "취소", hasEditBox = 1, maxLetters = 60,
    OnAccept = function(self, data)
        local eb = self.editBox or self.EditBox
        ns.BlackAdd(data, eb and eb:GetText() or "")
    end,
    EditBoxOnEnterPressed = function(self, data)
        local p = self:GetParent()
        ns.BlackAdd(data, self:GetText() or "")
        p:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
}
StaticPopupDialogs["LEELUI_BLACK_DEL"] = {
    text = "|cffff6b7f%s|r 님을 블랙리스트에서 뺄까요?",
    button1 = "빼기", button2 = "취소",
    OnAccept = function(_, data) ns.BlackRemove(data) end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
}
function ns.BlackAsk(name)
    local k = Key(name)
    if not k or k == "" or k == Short(UnitName("player")) then return end
    if BL()[k] then StaticPopup_Show("LEELUI_BLACK_DEL", k, nil, k)
    else StaticPopup_Show("LEELUI_BLACK_ADD", k, nil, k) end
end

-- 오른쪽 클릭 메뉴(파티 · 공격대 · 대상 · 채팅 이름)에 "블랙리스트에 넣기"
do
    local TAGS = { "MENU_UNIT_PARTY", "MENU_UNIT_PLAYER", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_FRIEND", "MENU_UNIT_RAID", "MENU_UNIT_TARGET", "MENU_UNIT_CHAT_ROSTER" }
    local function NameFrom(ctx)
        if not ctx then return end
        local n = ctx.name
        if (not n) and ctx.unit and UnitIsPlayer(ctx.unit) then n = UnitName(ctx.unit) end
        if type(n) == "string" and ns.IsSecret and ns.IsSecret(n) then return end
        return n and Key(n)
    end
    if Menu and Menu.ModifyMenu then
        for _, tag in ipairs(TAGS) do
            pcall(Menu.ModifyMenu, tag, function(owner, root, ctx)
                local n = NameFrom(ctx)
                if not n or n == Short(UnitName("player")) then return end
                root:CreateDivider()
                root:CreateButton(ns.IsBlack(n) and "|cffff6b7f블랙리스트에서 빼기|r" or "|cffff6b7f블랙리스트에 넣기|r", function() ns.BlackAsk(n) end)
            end)
        end
    elseif hooksecurefunc and UnitPopup_ShowMenu then
        local OK = { PARTY = true, PLAYER = true, RAID_PLAYER = true, FRIEND = true, RAID = true, CHAT_ROSTER = true, TARGET = true }
        hooksecurefunc("UnitPopup_ShowMenu", function(_, which, unit, name)
            if UIDROPDOWNMENU_MENU_LEVEL ~= 1 or not OK[which] then return end
            local n = name or (unit and UnitIsPlayer(unit) and UnitName(unit))
            n = n and Key(n)
            if not n or n == Short(UnitName("player")) then return end
            local info = UIDropDownMenu_CreateInfo()
            info.text = ns.IsBlack(n) and "|cffff6b7f블랙리스트에서 빼기|r" or "|cffff6b7f블랙리스트에 넣기|r"
            info.notCheckable = true
            info.func = function() ns.BlackAsk(n) end
            UIDropDownMenu_AddButton(info)
        end)
    end
end

-- 파티에 새로 들어오면 알림
local seen = {}
local toast
local function Toast(name, b)
    if not toast then
        local t = CreateFrame("Frame", nil, UIParent)
        t:SetSize(420, 46); t:SetPoint("TOP", 0, -120); t:SetFrameStrata("DIALOG")
        t.edge = ns.RoundRect(t, 23, { 1, 0.42, 0.5 }, "BACKGROUND", -1, -2)
        t.bg = ns.RoundRect(t, 23, { 0.118, 0.086, 0.078 }, "BACKGROUND", 0, 0); t.bg:SetColor({ 0.118, 0.086, 0.078 }, 0.96)
        t.icbg = t:CreateTexture(nil, "ARTWORK"); t.icbg:SetTexture(ns.MEDIA .. "circle"); t.icbg:SetSize(34, 34); t.icbg:SetPoint("LEFT", 7, 0)
        t.icbg:SetVertexColor(1, 0.42, 0.5)
        t.ic = t:CreateTexture(nil, "OVERLAY"); t.ic:SetTexture(ns.MEDIA .. "roll_ban"); t.ic:SetSize(20, 20); t.ic:SetPoint("CENTER", t.icbg)
        t.ic:SetVertexColor(0.165, 0.063, 0.082)
        -- 두 줄을 판 가운데에 맞춰 (위 줄은 가운데 위, 아래 줄은 가운데 아래)
        t.l1 = ns.Font(t, 13.5); t.l1:SetPoint("BOTTOMLEFT", t, "LEFT", 50, 1); t.l1:SetJustifyH("LEFT")
        t.l2 = ns.Font(t, 11, { 1, 0.6, 0.66 }); t.l2:SetPoint("TOPLEFT", t, "LEFT", 50, -2); t.l2:SetJustifyH("LEFT")
        t.l2:SetWidth(350); t.l2:SetJustifyH("LEFT"); t.l2:SetWordWrap(false)
        t:EnableMouse(true); t:SetScript("OnMouseUp", function(s2) s2:Hide() end)
        local ag = t:CreateAnimationGroup()
        local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(0.6); a:SetStartDelay(7)
        ag:SetScript("OnFinished", function() t:Hide() end)
        t.ag = ag
        toast = t
    end
    local cc = ClassHex(b.cls)
    toast.l1:SetText(("|cff%s%s|r 님은 블랙리스트예요"):format(Hex(cc), name))
    toast.l2:SetText(((b.note and b.note ~= "") and ("\"" .. b.note .. "\" · ") or "") .. date("%m월 %d일", b.at or time()) .. " 넣음 · 같이 만남 " .. (b.met or 0) .. "번")
    local w = math.max(toast.l1:GetStringWidth(), math.min(350, toast.l2:GetStringWidth())) + 50 + 22
    toast:SetWidth(math.max(240, w))
    toast:Show(); toast:SetAlpha(1); toast.ag:Stop(); toast.ag:Play()
    if ns.RollBlackSound then ns.RollBlackSound() end   -- 블랙리스트 굴림 알림과 같은 경고음 (허브에서 고른 소리)
end

local wasGroup   -- nil = 아직 모름 (로그인 · 리로드 땐 인사 안 함)
local function CheckGroup()
    local now, fresh = {}, {}
    local units = {}
    if IsInRaid and IsInRaid() then for i = 1, 40 do units[#units + 1] = "raid" .. i end
    else for i = 1, 4 do units[#units + 1] = "party" .. i end end
    for _, u in ipairs(units) do
        local n = UnitExists(u) and UnitName(u)
        if n and not (ns.IsSecret and ns.IsSecret(n)) then
            n = Short(n); now[n] = true
            local b = BL()[n]
            if b and not seen[n] then
                if wasGroup ~= nil then b.met = (b.met or 0) + 1 end   -- 리로드 · 로그인 땐 안 셈
                if not b.cls then local _, c = UnitClass(u); b.cls = c end
                fresh[#fresh + 1] = { name = n, b = b }
                P("|cffff6b7f주의|r " .. n .. " 님은 블랙리스트예요" .. ((b.note and b.note ~= "") and (": " .. b.note) or ""))
            end
        end
    end
    seen = now
    local inG = (IsInGroup and IsInGroup()) and true or false
    local joined = inG and wasGroup == false
    wasGroup = inG
    if not inG and ns.RollGreetHide then ns.RollGreetHide(true) end
    if joined or #fresh > 0 then
        if not (ns.RollGreet and ns.RollGreet(joined, fresh)) then
            for _, x in ipairs(fresh) do Toast(x.name, x.b) end
        end
    end
    if ns.BlackPaint then ns.BlackPaint() end
    if ns.RollFanPaint then ns.RollFanPaint() end
end
ns.BlackCheckGroup = CheckGroup

----------------------------------------------------------------------
-- 파티 인사 말풍선 (B: 톡톡 차례 말풍선)
--   ① 안녕! 같이 가자 ② 내가 하는 일 4개 ③ 블랙리스트가 있으면 빨간 풍선
--   1초 간격으로 하나씩 · 지난 건 흐려짐 · 누르면 닫힘
----------------------------------------------------------------------
local GR = { list = {}, queue = {}, pool = {} }
local GR_BG, GR_RIM = { 0.227, 0.165, 0.173 }, { 0.42, 0.25, 0.28 }
local GR_RBG, GR_RRIM = { 0.29, 0.118, 0.141 }, { 1, 0.42, 0.5 }

-- 메신저 풍선: 토끼 쪽 모서리 하나만 각지게 (pt = "BOTTOMRIGHT" 등, nil = 다 둥글게)
local CORNER_TC = { TOPLEFT = { 0, 0.5, 0, 0.5 }, TOPRIGHT = { 0.5, 1, 0, 0.5 }, BOTTOMLEFT = { 0, 0.5, 0.5, 1 }, BOTTOMRIGHT = { 0.5, 1, 0.5, 1 } }
function GR.Corner(f, pt)
    for _, rr in ipairs({ f.rim, f.bg }) do
        for ci = 1, 4 do   -- RoundRect 는 모서리 4장을 먼저 만들어요 (그 뒤는 가운데 · 옆 막대)
            local t = rr.tex[ci]
            local p = t.leelPt
            if p == nil then p = t:GetPoint(1); t.leelPt = CORNER_TC[p] and p or false end
            p = t.leelPt
            if p then
                if p == pt then t:SetTexture(ns.WHITE); t:SetTexCoord(0, 1, 0, 1)
                else local tc = CORNER_TC[p]; t:SetTexture(ns.MEDIA .. "circle"); t:SetTexCoord(tc[1], tc[2], tc[3], tc[4]) end
            end
        end
    end
end

function GR.New()
    local f = table.remove(GR.pool)
    if f then return f end
    f = CreateFrame("Button", nil, UIParent)
    f:SetFrameStrata("DIALOG"); f:SetFrameLevel(60); f:SetClampedToScreen(true)
    f.rim = ns.RoundRect(f, 12, GR_RIM, "BACKGROUND", 0, 0)
    f.bg = ns.RoundRect(f, 12, GR_BG, "BACKGROUND", 2, 1.5)
    -- D안: 표정 스티커 (풍선 왼쪽 위로 삐져나와요)
    f.face = f:CreateTexture(nil, "OVERLAY", nil, 5); f.face:SetSize(50, 50); f.face:SetPoint("CENTER", f, "TOPLEFT", 14, -12)
    local fa = f.face:CreateAnimationGroup()
    local fs1 = fa:CreateAnimation("Scale"); fs1:SetDuration(0.16); fs1:SetOrder(1); fs1:SetSmoothing("OUT")
    if fs1.SetScaleFrom then fs1:SetScaleFrom(0.3, 0.3); fs1:SetScaleTo(1.15, 1.15) else fs1:SetFromScale(0.3, 0.3); fs1:SetToScale(1.15, 1.15) end
    local fs2 = fa:CreateAnimation("Scale"); fs2:SetDuration(0.1); fs2:SetOrder(2)
    if fs2.SetScaleFrom then fs2:SetScaleFrom(1.15, 1.15); fs2:SetScaleTo(1, 1) else fs2:SetFromScale(1.15, 1.15); fs2:SetToScale(1, 1) end
    f.facePop = fa
    local sk = f.face:CreateAnimationGroup()   -- 화났을 때 부들부들
    for i, dx in ipairs({ -3, 6, -6, 6, -3 }) do
        local t = sk:CreateAnimation("Translation"); t:SetOffset(dx, 0); t:SetDuration(0.05); t:SetOrder(i)
    end
    sk:SetLooping("NONE"); f.faceShake = sk
    f.l1 = ns.Font(f, 12.5); f.l1:SetPoint("TOPLEFT", 46, -9); f.l1:SetJustifyH("LEFT")
    f.lm = ns.Font(f, 12.5); f.lm:SetPoint("TOPLEFT", f.l1, "BOTTOMLEFT", 0, -3); f.lm:SetJustifyH("LEFT")
    f.l2 = ns.Font(f, 10.5, { 0.73, 0.65, 0.63 }); f.l2:SetPoint("TOPLEFT", f.l1, "BOTTOMLEFT", 0, -3); f.l2:SetJustifyH("LEFT")
    f.chips = {}
    local CH = { { "roll_sub_dice", "굴림 추천" }, { "roll_sub_log", "주사위 기록장" }, { "roll_sub_ban", "블랙리스트" }, { "roll_sub_gear", "설정" } }
    for i, c in ipairs(CH) do
        local ic = f:CreateTexture(nil, "ARTWORK"); ic:SetTexture(ns.MEDIA .. c[1]); ic:SetSize(20, 20)
        local fs = ns.Font(f, 11); fs:SetText(c[2]); fs:SetPoint("LEFT", ic, "RIGHT", 4, 0)
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        ic:SetPoint("TOPLEFT", 46 + col * 108, -30 - row * 24)
        f.chips[i] = { ic, fs }
    end
    local ag = f:CreateAnimationGroup()
    local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.22)
    local tr = ag:CreateAnimation("Translation"); tr:SetOffset(0, 6); tr:SetDuration(0.22); tr:SetSmoothing("OUT")
    f.inAg = ag
    local og = f:CreateAnimationGroup()
    local oa = og:CreateAnimation("Alpha"); oa:SetFromAlpha(1); oa:SetToAlpha(0); oa:SetDuration(0.35)
    og:SetScript("OnFinished", function() f:Hide(); f:SetAlpha(1) end)
    f.outAg = og
    f:SetScript("OnClick", function() ns.RollGreetHide() end)
    f:SetScript("OnEnter", function(s2)
        GR.hold = true
        if s2.kind == "broll" and s2.link then
            GameTooltip:SetOwner(s2, "ANCHOR_TOP"); pcall(GameTooltip.SetHyperlink, GameTooltip, s2.link)
            GameTooltip:AddLine("클릭 = 닫기", 0.6, 0.55, 0.53); GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function() GR.hold = false; GameTooltip:Hide() end)
    return f
end

function GR.Fill(f, kind, x)
    f.kind = kind
    local intro = kind == "intro"
    for _, c in ipairs(f.chips) do c[1]:SetShown(intro); c[2]:SetShown(intro) end
    f.l2:SetText(""); f.l2:SetWidth(0); f.l1:SetWidth(0)
    local red = kind == "black" or kind == "broll"
    local FACE = { hi = "happy", intro = "wink", black = "angry", broll = "angry", win = "star" }
    f.lm:SetText(""); f.lm:Hide(); f.link = nil
    f.l2:ClearAllPoints(); f.l2:SetPoint("TOPLEFT", f.l1, "BOTTOMLEFT", 0, -3)
    f.face:SetTexture(ns.MEDIA .. "roll_face_" .. (FACE[kind] or "happy"))
    f.l2:SetTextColor(0.73, 0.65, 0.63)
    f.bg:SetColor(red and GR_RBG or GR_BG); f.rim:SetColor(red and GR_RRIM or GR_RIM)
    f.col, f.rimc = red and GR_RBG or GR_BG, red and GR_RRIM or GR_RIM
    if kind == "hi" then
        local n = GetNumGroupMembers and GetNumGroupMembers() or 0
        f.l1:SetText("안녕! 같이 가자" .. ((n and n > 1) and (" |cffb9a6a0· " .. n .. "명 " .. ((IsInRaid and IsInRaid()) and "공격대" or "파티") .. "|r") or ""))
        f.l2:SetText("내가 주사위 봐줄게")
        f:SetSize(math.max(f.l1:GetStringWidth(), f.l2:GetStringWidth()) + 60, 44)
    elseif intro then
        f.l1:SetText("내가 하는 일 |cffb9a6a0(나를 누르면 펼쳐져)|r")
        f:SetSize(math.max(266, f.l1:GetStringWidth() + 60), 84)
    elseif kind == "broll" then
        -- "잠깐! 블랙리스트 슈엘이 / [투구]에 차비 눌렀어 → 42 / 지금 슈엘이 1등이야 · 메모: 템 먹튀"
        f.key, f.link = x.key, x.link
        local cc = x.cls and Hex(ClassHex(x.cls)) or "ffffff"
        f.l1:SetText(("|cffff8fab잠깐!|r 블랙리스트 |cff%s%s|r이"):format(cc, x.who))
        local tc = (x.t == "need") and "8fe899" or "f3c55a"
        f.lm:SetText(("%s에 |cff%s%s|r 눌렀어 → |cff%s%d|r"):format(x.item, tc, TYPE_TXT[x.t] or "", x.top and "ff6b7f" or "ffffff", x.n))
        f.lm:Show()
        f.l2:ClearAllPoints(); f.l2:SetPoint("TOPLEFT", f.lm, "BOTTOMLEFT", 0, -3)
        local tail = {}
        if x.top then tail[#tail + 1] = "지금 " .. x.who .. "이 1등이야" end
        if x.note then tail[#tail + 1] = "메모: " .. x.note end
        f.l2:SetText(table.concat(tail, " · ")); f.l2:SetTextColor(0.91, 0.73, 0.75)
        local w = math.min(320, math.max(f.l1:GetStringWidth(), f.lm:GetStringWidth(), f.l2:GetStringWidth()))
        f:SetSize(w + 60, 18 + f.l1:GetStringHeight() + 3 + f.lm:GetStringHeight() + ((#tail > 0) and (3 + f.l2:GetStringHeight()) or 0))
    elseif kind == "win" then
        f.l1:SetText("|cfff3c55a획득!|r " .. (x.link or x.name or "템"))
        f.l2:SetText(x.n and ("주사위 " .. x.n .. " · 축하해!") or "축하해!")
        f.l2:SetTextColor(1, 0.86, 0.55)
        f:SetSize(math.min(330, math.max(f.l1:GetStringWidth(), f.l2:GetStringWidth())) + 60, 44)
    else
        local b = x.b or {}
        f.l1:SetText(("|cffff8fab잠깐!|r 블랙리스트 |cff%s%s|r 님이 있어"):format(Hex(ClassHex(b.cls)), x.name))
        local note = (b.note and b.note ~= "") and ("메모: " .. b.note .. " · ") or ""
        f.l2:SetText(note .. (b.met or 1) .. "번째 만남"); f.l2:SetTextColor(0.91, 0.73, 0.75)
        local w = math.min(250, math.max(f.l1:GetStringWidth(), f.l2:GetStringWidth()))
        f.l2:SetWidth(w); f.l2:SetWordWrap(true)
        f:SetSize(w + 60, math.max(44, 18 + f.l1:GetStringHeight() + 3 + f.l2:GetStringHeight()))
    end
end

function GR.Layout()
    if not badge then return end
    local sc = badge:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local bx, by = badge:GetCenter()
    if not bx then return end
    local right = bx * sc > UIParent:GetWidth() / 2
    -- 위로 쌓을 자리가 있으면 새 풍선이 토끼 옆 (위쪽이 좁을 때만 아래로)
    local low = (UIParent:GetHeight() - by * sc) > 200
    local n = #GR.list
    for i, f in ipairs(GR.list) do
        f:SetScale(badge:GetEffectiveScale() / UIParent:GetEffectiveScale())
        f:ClearAllPoints()
        f:SetAlpha((i == n or f.kind == "black" or f.kind == "broll") and 1 or 0.6)
    end
    if n == 0 then return end
    -- 주사위 창이 열려 있으면 창 위로 쌓아요 (창에 가려지지 않게) · 새 말이 창 쪽(아래)
    if anchor and anchor:IsShown() then
        GR.list[n]:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 14, 8)
        for i = n - 1, 1, -1 do GR.list[i]:SetPoint("BOTTOMLEFT", GR.list[i + 1], "TOPLEFT", 0, 16) end
        for _, f in ipairs(GR.list) do GR.Corner(f, nil) end
        return
    end
    -- 채팅 순서: 오래된 건 위, 새것은 아래. 토끼에 가장 가까운 풍선만 토끼 쪽 모서리가 각져요
    local side, dx = right and "RIGHT" or "LEFT", right and -8 or 8
    local near
    if low then
        near = GR.list[n]
        near:SetPoint("BOTTOM" .. side, badge, "BOTTOM" .. (right and "LEFT" or "RIGHT"), dx, 6)
        for i = n - 1, 1, -1 do GR.list[i]:SetPoint("BOTTOM" .. side, GR.list[i + 1], "TOP" .. side, 0, 16) end
    else
        near = GR.list[1]
        near:SetPoint("TOP" .. side, badge, "TOP" .. (right and "LEFT" or "RIGHT"), dx, -6)
        for i = 2, n do GR.list[i]:SetPoint("TOP" .. side, GR.list[i - 1], "BOTTOM" .. side, 0, -16) end
    end
    for _, f in ipairs(GR.list) do GR.Corner(f, f == near and ((low and "BOTTOM" or "TOP") .. side) or nil) end
end

ns.RollGreetLayout = function() GR.Layout() end
function GR.Talk()
    if not badge then return end
    if not badge.talkAg then
        local g = badge.icon:CreateAnimationGroup()
        local u = g:CreateAnimation("Translation"); u:SetOffset(0, 5); u:SetDuration(0.12); u:SetOrder(1); u:SetSmoothing("OUT")
        local d = g:CreateAnimation("Translation"); d:SetOffset(0, -5); d:SetDuration(0.14); d:SetOrder(2); d:SetSmoothing("IN")
        badge.talkAg = g
    end
    badge.talkAg:Stop(); badge.talkAg:Play()
end

function GR.Push(kind, x)
    local f = GR.New()
    GR.Fill(f, kind, x)
    GR.list[#GR.list + 1] = f
    if #GR.list > 5 then local o = table.remove(GR.list, 1); o:Hide(); GR.pool[#GR.pool + 1] = o end
    f:Show(); f.outAg:Stop(); f.inAg:Stop(); f.inAg:Play()
    GR.Layout(); GR.Talk()
    f.facePop:Stop(); f.faceShake:Stop(); f.facePop:Play()
    if kind == "broll" then
        C_Timer.After(0.28, function() if f:IsShown() and f.kind == "broll" then f.faceShake:Play() end end)
    elseif kind == "black" then
        GR.sticky = true
        C_Timer.After(0.28, function() if f:IsShown() and f.kind == "black" then f.faceShake:Play() end end)
        if ns.RollBlackSound then ns.RollBlackSound() end
    elseif PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081) end
    GR.left = 8
end

function GR.Step()
    if not GR.ticker then
        GR.ticker = CreateFrame("Frame")
        GR.ticker:SetScript("OnUpdate", function(_, el)
            GR.wait = (GR.wait or 0) - el
            if #GR.queue > 0 and GR.wait <= 0 then
                local q = table.remove(GR.queue, 1)
                GR.Push(q[1], q[2]); GR.wait = 1
            elseif #GR.queue == 0 and #GR.list > 0 then
                if not GR.sticky and not GR.hold then
                    GR.left = (GR.left or 8) - el
                    if GR.left <= 0 then ns.RollGreetHide() end
                end
            elseif #GR.queue == 0 and #GR.list == 0 then
                GR.ticker:Hide()
            end
        end)
    end
    GR.ticker:Show()
end

-- joined: 방금 파티에 들어옴 · fresh: 새로 본 블랙 { {name, b} }
-- 말풍선을 띄웠으면 true (못 띄우면 예전 알림 쪽으로)
function ns.RollGreet(joined, fresh, force)
    local d = DB()
    if not force and (not d.on or d.greet == "off") then return false end
    Anchor(); PaintBadge()
    if not badge then return false end
    talking = true; PaintBadge()
    if joined then
        if #GR.list > 0 then ns.RollGreetHide(true); talking = true end
        GR.queue = {}
        GR.queue[#GR.queue + 1] = { "hi" }
        if d.greet ~= "short" then GR.queue[#GR.queue + 1] = { "intro" } end
        GR.wait = 0.8   -- 파티 창이 먼저 뜨도록 살짝 기다렸다가
    end
    local nb = 0
    for _, x in ipairs(fresh or {}) do
        nb = nb + 1
        if nb <= 3 then GR.queue[#GR.queue + 1] = { "black", x } end
    end
    if nb > 3 then GR.queue[#GR.queue + 1] = { "black", { name = "외 " .. (nb - 3) .. "명", b = { note = "블랙리스트 창에서 봐요", met = 0 } } } end
    if not joined and (GR.wait or 0) <= 0 then GR.wait = 0 end
    GR.Step()
    return true
end

-- 블랙리스트가 굴리면 화난 토끼가 바로 말해요 (같은 사람 · 같은 템은 풍선 하나를 고쳐 써요)
function ns.RollTalkBlackRoll(x)
    if not DB().on then return false end
    Anchor(); PaintBadge()
    if not badge then return false end
    talking = true; PaintBadge()
    for _, f in ipairs(GR.list) do
        if f.kind == "broll" and f.key == x.key then
            GR.Fill(f, "broll", x); GR.Layout(); GR.Talk()
            f.facePop:Stop(); f.faceShake:Stop(); f.faceShake:Play()
            GR.left = 8
            return true
        end
    end
    GR.Push("broll", x)
    GR.Step()
    return true
end

-- 템을 먹으면 반짝 토끼가 축하
function ns.RollGreetWin(e, n)
    local d = DB()
    if not d.on or d.greet == "off" then return end
    Anchor(); PaintBadge()
    if not badge then return end
    talking = true; PaintBadge()
    GR.queue[#GR.queue + 1] = { "win", { link = e.link, name = e.name, n = n } }
    GR.Step()
end

function ns.RollGreetHide(now)
    GR.queue = {}; GR.sticky = false; GR.hold = false
    for _, f in ipairs(GR.list) do
        if now then f:Hide() else f.outAg:Play() end
        GR.pool[#GR.pool + 1] = f
    end
    GR.list = {}
    if talking then talking = false; PaintBadge() end
end

function ns.RollGreetTest()
    ns.RollGreetHide(true)
    ns.RollGreet(true, { { name = "나쁜토끼", b = { note = "주사위 먹튀", met = 3, cls = "ROGUE" } } }, true)
    GR.queue[#GR.queue + 1] = { "win", { name = "|cff1eff00[소금선견자의 투구]|r", n = 42 } }
end

-- 블랙리스트 창
local blackWin
local BW, BROW, BROWS = 470, 40, 8
local blackOff = 0
local function InGroupNamed(n) return seen[n] end

local function Edit(parent, w, hint)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(w, 26); e:SetAutoFocus(false); e:SetFontObject(ChatFontNormal)
    e:SetTextInsets(10, 10, 0, 0)
    e.bg = ns.RoundRect(e, 13, { 0.165, 0.122, 0.114 }, "BACKGROUND", 0, 0)
    e.hint = ns.Font(e, 11.5, { 0.54, 0.48, 0.46 }); e.hint:SetPoint("LEFT", 11, 0); e.hint:SetText(hint)
    e:SetScript("OnTextChanged", function(s2) s2.hint:SetShown(s2:GetText() == "") end)
    e:SetScript("OnEscapePressed", e.ClearFocus)
    e:SetScript("OnEditFocusGained", function(s2) s2.bg:SetColor({ 0.23, 0.17, 0.16 }, 1) end)
    e:SetScript("OnEditFocusLost", function(s2) s2.bg:SetColor({ 0.165, 0.122, 0.114 }, 1) end)
    return e
end

local function BlackRows()
    local list = {}
    for n, b in pairs(BL()) do list[#list + 1] = { name = n, b = b } end
    table.sort(list, function(x, y)
        local ix, iy = InGroupNamed(x.name) and 1 or 0, InGroupNamed(y.name) and 1 or 0
        if ix ~= iy then return ix > iy end
        return (x.b.at or 0) > (y.b.at or 0)
    end)
    return list
end

function ns.BlackPaint()
    if not (blackWin and blackWin:IsShown()) then return end
    local list = BlackRows()
    blackOff = math.max(0, math.min(blackOff, #list - BROWS))
    for i = 1, BROWS do
        local r = blackWin.rows[i]
        local x = list[i + blackOff]
        if not x then r:Hide() else
            r:Show(); r.who = x.name
            local cc = ClassHex(x.b.cls)
            r.dot:SetVertexColor(cc[1], cc[2], cc[3])
            r.name:SetText(x.name); r.name:SetTextColor(cc[1], cc[2], cc[3])
            r.note:SetText((x.b.note and x.b.note ~= "") and x.b.note or "|cff8a7a76이유 없음|r")
            r.date:SetText(date("%m월 %d일", x.b.at or time()) .. "\n같이 만남 " .. (x.b.met or 0) .. "번")
            r.now:SetShown(InGroupNamed(x.name) and true or false)
            r.del.armed = nil; r.del.t:SetVertexColor(0.62, 0.55, 0.53)
        end
    end
    blackWin.count:SetText(#list .. "명")
    blackWin.empty:SetShown(#list == 0)
end

local function MakeBlack()
    if blackWin then return blackWin end
    local w = CreateFrame("Frame", "LeelUI_BlackList", UIParent)
    w:SetSize(BW, 470); w:SetPoint("CENTER", 0, 40)
    w:SetFrameStrata("DIALOG"); w:SetToplevel(true)
    w:EnableMouse(true); w:SetMovable(true); w:RegisterForDrag("LeftButton"); w:SetClampedToScreen(true)
    w:SetScript("OnDragStart", w.StartMoving); w:SetScript("OnDragStop", w.StopMovingOrSizing)
    ns.RoundPlate(w, 14, { 0.118, 0.086, 0.078, 0.97 }, { 0.29, 0.204, 0.188, 1 })
    local ib = w:CreateTexture(nil, "ARTWORK"); ib:SetTexture(ns.MEDIA .. "circle"); ib:SetSize(28, 28); ib:SetPoint("TOPLEFT", 14, -12); ib:SetVertexColor(1, 0.42, 0.5)
    local ic = w:CreateTexture(nil, "OVERLAY"); ic:SetTexture(ns.MEDIA .. "roll_ban"); ic:SetSize(17, 17); ic:SetPoint("CENTER", ib); ic:SetVertexColor(0.165, 0.063, 0.082)
    local title = ns.Font(w, 16, { 1, 0.56, 0.64 }); title:SetPoint("LEFT", ib, "RIGHT", 8, 0); title:SetText("블랙리스트")
    local sub = ns.Font(w, 11, { 0.72, 0.65, 0.63 }); sub:SetPoint("LEFT", title, "RIGHT", 10, -1); sub:SetText("같이 파티하기 싫은 사람 · 나만 보여요")
    local x = CreateFrame("Button", nil, w); x:SetSize(24, 24); x:SetPoint("TOPRIGHT", -10, -12)
    x.t = x:CreateTexture(nil, "ARTWORK"); x.t:SetTexture(ns.MEDIA .. "roll_x"); x.t:SetAllPoints(); x.t:SetVertexColor(0.79, 0.70, 0.68)
    x:SetScript("OnClick", function() w:Hide() end)
    -- 넣기 줄
    local en = Edit(w, 130, "이름"); en:SetPoint("TOPLEFT", 14, -50)
    local er = Edit(w, 214, "이유 (비워도 돼요)"); er:SetPoint("LEFT", en, "RIGHT", 6, 0); er:SetMaxLetters(60)
    local add = CreateFrame("Button", nil, w); add:SetSize(70, 26); add:SetPoint("LEFT", er, "RIGHT", 6, 0)
    add.bg = ns.RoundRect(add, 13, PINK, "BACKGROUND", 0, 0)
    add.fs = ns.Font(add, 12.5, C.ink); add.fs:SetShadowColor(0, 0, 0, 0); add.fs:SetPoint("CENTER"); add.fs:SetText("+ 넣기")
    local function DoAdd()
        local n = (en:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if n == "" then en:SetFocus(); return end
        ns.BlackAdd(n, er:GetText() or "")
        en:SetText(""); er:SetText(""); en:ClearFocus(); er:ClearFocus()
    end
    add:SetScript("OnClick", DoAdd)
    en:SetScript("OnEnterPressed", function() er:SetFocus() end)
    en:SetScript("OnTabPressed", function() er:SetFocus() end)
    er:SetScript("OnEnterPressed", DoAdd)
    -- 대상이 플레이어면 이름 칸에 미리
    w.fillTarget = function()
        if en:GetText() == "" and UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
            local n = UnitName("target"); if n and not (ns.IsSecret and ns.IsSecret(n)) then en:SetText(Short(n)) end
        end
    end
    local tip = ns.Font(w, 10.5, { 0.54, 0.48, 0.46 }); tip:SetPoint("TOPLEFT", 16, -84)
    tip:SetText("파티 창 · 대상 · 채팅 이름 오른쪽 클릭, 주사위 보드 줄 오른쪽 클릭으로도 넣어요")
    w.count = ns.Font(w, 11.5, { 0.72, 0.65, 0.63 }); w.count:SetPoint("TOPRIGHT", -16, -84)
    -- 목록
    local list = CreateFrame("Frame", nil, w)
    list:SetPoint("TOPLEFT", 12, -104); list:SetPoint("TOPRIGHT", -12, -104); list:SetHeight(BROWS * BROW)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, d) blackOff = blackOff - d; ns.BlackPaint() end)
    w.rows = {}
    for i = 1, BROWS do
        local r = CreateFrame("Button", nil, list)
        r:SetHeight(BROW - 2); r:SetPoint("TOPLEFT", 0, -(i - 1) * BROW); r:SetPoint("RIGHT", 0, 0)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r.line = r:CreateTexture(nil, "BACKGROUND"); r.line:SetTexture(ns.WHITE); r.line:SetHeight(1)
        r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT"); r.line:SetVertexColor(0.227, 0.169, 0.157, 1)
        r.hl = r:CreateTexture(nil, "HIGHLIGHT"); r.hl:SetTexture(ns.WHITE); r.hl:SetAllPoints(); r.hl:SetVertexColor(1, 0.42, 0.5, 0.08)
        r.dot = r:CreateTexture(nil, "ARTWORK"); r.dot:SetTexture(ns.MEDIA .. "circle"); r.dot:SetSize(18, 18); r.dot:SetPoint("LEFT", 4, 0)
        r.name = ns.Font(r, 13); r.name:SetPoint("TOPLEFT", 30, -4)
        r.note = ns.Font(r, 11, { 0.72, 0.65, 0.63 }); r.note:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
        r.note:SetWidth(260); r.note:SetJustifyH("LEFT"); r.note:SetWordWrap(false)
        r.now = CreateFrame("Frame", nil, r); r.now:SetSize(96, 16); r.now:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
        r.now.bg = ns.RoundRect(r.now, 8, { 1, 0.42, 0.5 }, "BACKGROUND", 0, 0)
        r.now.fs = ns.Font(r.now, 10, C.ink); r.now.fs:SetShadowColor(0, 0, 0, 0); r.now.fs:SetPoint("CENTER"); r.now.fs:SetText("지금 파티에 있어요")
        r.del = CreateFrame("Button", nil, r); r.del:SetSize(16, 16); r.del:SetPoint("RIGHT", -4, 0)
        r.del.t = r.del:CreateTexture(nil, "ARTWORK"); r.del.t:SetTexture(ns.MEDIA .. "roll_x"); r.del.t:SetAllPoints()
        r.del:SetScript("OnClick", function(s2)
            if s2.armed then ns.BlackRemove(r.who) else
                s2.armed = true; s2.t:SetVertexColor(1, 0.42, 0.5)
                C_Timer.After(3, function() if s2.armed then s2.armed = nil; s2.t:SetVertexColor(0.62, 0.55, 0.53) end end)
            end
        end)
        r.del:SetScript("OnEnter", function(s2) GameTooltip:SetOwner(s2, "ANCHOR_RIGHT"); GameTooltip:AddLine(s2.armed and "한 번 더 누르면 빼요" or "블랙리스트에서 빼기 (두 번 클릭)"); GameTooltip:Show() end)
        r.del:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r.date = ns.Font(r, 10.5, { 0.54, 0.48, 0.46 }); r.date:SetPoint("RIGHT", r.del, "LEFT", -10, 0); r.date:SetJustifyH("RIGHT")
        -- 클릭 = 이유 고치기 (넣기 줄에 불러오기)
        r:SetScript("OnClick", function(s2)
            local b = BL()[s2.who]; if not b then return end
            en:SetText(s2.who); er:SetText(b.note or ""); er:SetFocus()
        end)
        w.rows[i] = r
    end
    w.empty = ns.Font(w, 12.5, { 0.62, 0.55, 0.53 }); w.empty:SetPoint("TOP", list, "TOP", 0, -60); w.empty:SetJustifyH("CENTER")
    w.empty:SetText("아직 아무도 없어요.\n위에 이름을 쓰거나, 이름을 오른쪽 클릭해서 넣어요.")
    local hint = ns.Font(w, 10.5, { 0.54, 0.48, 0.46 }); hint:SetPoint("BOTTOMLEFT", 16, 14)
    hint:SetText("줄 클릭 = 이유 고치기 · X 두 번 = 빼기 · 파티에 들어오면 알려 줘요")
    w:SetScript("OnShow", function() w.fillTarget(); blackOff = 0; ns.BlackPaint() end)
    tinsert(UISpecialFrames, "LeelUI_BlackList")
    w:Hide()
    blackWin = w
    return w
end
function ns.BlackOpen(show)
    local w = MakeBlack()
    if show == nil then show = not w:IsShown() end
    w:SetShown(show)
end

----------------------------------------------------------------------
-- 토끼 단추 작은 단추들: 기록장 · 블랙리스트 · 미리 보기 · 설정
----------------------------------------------------------------------
local fan
local FAN = {
    { tex = "roll_sub_log", tip = "주사위 기록장", run = function() ns.RollLog(true) end },
    { tex = "roll_sub_ban", tip = "블랙리스트", run = function() ns.BlackOpen(true) end, ban = true },
    { tex = "roll_sub_dice", tip = "미리 보기 (가짜 주사위)", run = function() ns.RollTest() end },
    { tex = "roll_sub_gear", tip = "설정 (허브)", run = function()
        if ns.ToggleHub then ns:ToggleHub("LeelUI_Roll") elseif SlashCmdList.LEELUI then SlashCmdList.LEELUI("") end
    end },
}

function ns.RollFanPaint()
    if not fan then return end
    local n = 0
    for _ in pairs(BL()) do n = n + 1 end
    local inParty = 0
    for k in pairs(seen) do if BL()[k] then inParty = inParty + 1 end end
    local b = fan.btns[2]
    b.cnt:SetShown(n > 0); b.cntFs:SetText(n)
    if inParty > 0 and not b:IsMouseOver() then b.ring:SetVertexColor(1, 0.3, 0.42); b.ring:SetAlpha(0.8) elseif not b:IsMouseOver() then b.ring:SetAlpha(0) end
end

local function MakeFan()
    if fan then return fan end
    fan = CreateFrame("Frame", nil, badge)
    fan:SetAllPoints(badge); fan:SetFrameLevel(badge:GetFrameLevel() + 5)
    fan.btns = {}
    for i, d in ipairs(FAN) do
        local b = CreateFrame("Button", nil, fan)
        b:SetSize(44, 44)
        -- 어두운 받침 그림자: 밝은 배경에서도 또렷하게
        b.shade = b:CreateTexture(nil, "BACKGROUND", nil, -2); b.shade:SetTexture(ns.MEDIA .. "soft_glow")
        b.shade:SetPoint("CENTER", 0, -1); b.shade:SetSize(70, 70); b.shade:SetVertexColor(0, 0, 0, 0.6)
        -- 뒤 빛: 평소 없음 · 마우스 = 흰빛 · 블랙리스트가 파티에 있으면 빨간빛
        b.ring = b:CreateTexture(nil, "BACKGROUND", nil, -1); b.ring:SetTexture(ns.MEDIA .. "soft_glow"); b.ring:SetBlendMode("ADD")
        b.ring:SetPoint("CENTER", 0, -2); b.ring:SetSize(72, 72); b.ring:SetVertexColor(1, 1, 1); b.ring:SetAlpha(0)
        b.ic = b:CreateTexture(nil, "ARTWORK"); b.ic:SetTexture(ns.MEDIA .. d.tex); b.ic:SetAllPoints()
        b.cnt = CreateFrame("Frame", nil, b); b.cnt:SetSize(16, 16); b.cnt:SetPoint("CENTER", b, "TOPRIGHT", -3, -3); b.cnt:SetFrameLevel(b:GetFrameLevel() + 2)
        local cd = b.cnt:CreateTexture(nil, "ARTWORK"); cd:SetTexture(ns.MEDIA .. "circle"); cd:SetAllPoints(); cd:SetVertexColor(1, 0.353, 0.431)
        b.cntFs = b.cnt:CreateFontString(nil, "OVERLAY"); b.cntFs:SetFont(ns.NUM or ns.FONT, 12, ""); b.cntFs:SetPoint("CENTER")
        b.cnt:Hide()
        b:SetScript("OnEnter", function(s2)
            s2.ring:SetVertexColor(1, 0.561, 0.639); s2.ring:SetAlpha(0.8); s2.ic:SetSize(50, 50); s2.ic:ClearAllPoints(); s2.ic:SetPoint("CENTER")
            GameTooltip:SetOwner(s2, "ANCHOR_LEFT"); GameTooltip:AddLine(d.tip); GameTooltip:Show()
            fan.idle = 0
        end)
        b:SetScript("OnLeave", function(s2) GameTooltip:Hide(); s2.ring:SetAlpha(0); s2.ic:ClearAllPoints(); s2.ic:SetAllPoints(); ns.RollFanPaint() end)
        b:SetScript("OnClick", function() ns.RollFan(false); d.run() end)
        fan.btns[i] = b
    end
    -- 펼치기: 0.15초 동안 가운데에서 둥글게
    fan:SetScript("OnUpdate", function(s2, el)
        s2.p = math.min(1, (s2.p or 0) + el / 0.15)
        local p = 1 - (1 - s2.p) ^ 2
        for i, b in ipairs(s2.btns) do
            local a = math.rad(s2.angles[i])
            b:ClearAllPoints()
            b:SetPoint("CENTER", s2, "CENTER", math.cos(a) * 92 * p, math.sin(a) * 92 * p)
            b:SetAlpha(p)
        end
        -- 마우스가 떠나고 3초 지나면 접기
        if s2:IsMouseOver(110, -110, -110, 110) or badge:IsMouseOver() then s2.idle = 0
        else s2.idle = (s2.idle or 0) + el; if s2.idle > 3 then ns.RollFan(false) end end
    end)
    fan:Hide()
    return fan
end

function ns.RollFan(show)
    Anchor()
    MakeFan()
    if show == nil then show = not fan:IsShown() end
    if not show then fan:Hide(); return end
    -- 화면 가운데 쪽 · 위쪽으로 (아래 공간이 넓으면 아래로)
    local sc = badge:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x, y = badge:GetCenter()
    local right = x and (x * sc) > UIParent:GetWidth() / 2
    local up = not (y and (y * sc) > UIParent:GetHeight() - 120)
    local base = right and { 90, 120, 150, 180 } or { 90, 60, 30, 0 }
    if not up then for i, v in ipairs(base) do base[i] = -v end end
    fan.angles = base
    fan.p, fan.idle = 0, 0
    ns.RollFanPaint()
    fan:Show()
end

SLASH_LEELROLL1 = "/르엘주사위"
SLASH_LEELROLL2 = "/lroll"
SlashCmdList.LEELROLL = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "테스트" or msg == "test" then ns.RollTest()
    elseif msg == "기록" or msg == "log" then ns.RollLog(true)
    elseif msg == "블랙" or msg == "블랙리스트" then ns.BlackOpen(true)
    elseif msg == "끄기" then DB().on = false; ns.RollApply(); P("껐어요. 블리자드 기본 창이 나와요.")
    elseif msg == "켜기" then DB().on = true; ns.RollApply(); P("켰어요.")
    elseif msg == "위치" then local d = DB(); d.bx, d.by = nil, nil; d.scale = 100
        ns.RollPlace(); P("처음 자리 · 크기로 돌렸어요.")
    elseif msg == "이동" or msg == "옮기기" then ns.RollUnlock(true)
    elseif msg == "인사" then ns.RollGreetTest()
    else
        P("지금: " .. (DB().on and "켜짐" or "꺼짐") .. " · " .. BasisText())
        print("  /르엘주사위 테스트 — 가짜 템으로 미리 보기")
        print("  /르엘주사위 기록 — 주사위 기록장 · /르엘주사위 블랙 — 블랙리스트")
        print("  /르엘주사위 이동 — 자리 옮기기 · 크기 (마우스 휠)")
        print("  /르엘주사위 위치 — 처음 자리 · 크기로 (Shift + 카드 끌기로도 옮겨요)")
        print("  /르엘주사위 인사 — 파티 인사 말풍선 미리 보기")
        print("  /르엘주사위 끄기 · 켜기")
    end
end

-- 점검: /르엘마우스 — 지금 마우스 아래에서 클릭을 받는 창 이름 (룻 · 시점 돌리기가 막힐 때)
SLASH_LEELMOUSE1 = "/르엘마우스"
SlashCmdList.LEELMOUSE = function()
    local list = {}
    if GetMouseFoci then for _, f in ipairs(GetMouseFoci() or {}) do list[#list + 1] = f end
    elseif GetMouseFocus then list[1] = GetMouseFocus() end
    if #list == 0 then P("마우스 아래에 창이 없어요 (게임 화면이 클릭을 받는 상태)") return end
    for i, f in ipairs(list) do
        local name = (f.GetDebugName and f:GetDebugName()) or (f.GetName and f:GetName()) or tostring(f)
        local w, h = f:GetSize()
        P(("%d. %s · %dx%d · 보임 %s · 투명도 %.2f"):format(i, tostring(name), w or 0, h or 0, tostring(f:IsVisible()), f:GetEffectiveAlpha() or 1))
    end
    -- 화면을 크게 덮는데 안 보이는(투명한) 클릭 받는 창 찾기
    local sw, sh = UIParent:GetWidth() * UIParent:GetEffectiveScale(), UIParent:GetHeight() * UIParent:GetEffectiveScale()
    local n, f = 0, EnumerateFrames()
    while f do
        local ok, big = pcall(function()
            if not (f:IsVisible() and f:IsMouseEnabled()) then return false end
            local w, h = f:GetSize(); local sc = f:GetEffectiveScale()
            return (w * sc) * (h * sc) > sw * sh * 0.25 and (f:GetEffectiveAlpha() or 1) < 0.1
        end)
        if ok and big then
            n = n + 1
            local nm = (f.GetDebugName and f:GetDebugName()) or (f.GetName and f:GetName()) or tostring(f)
            P("투명한 큰 창: " .. tostring(nm))
        end
        f = EnumerateFrames(f)
    end
    if n == 0 then P("화면을 덮는 투명한 창은 없어요") end
end
