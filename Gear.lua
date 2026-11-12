-- LeelUI / Gear.lua  (시험 중)
-- 장비 비교 A+B: 툴팁에 "르엘 점수"(내 역할 기준 점수 하나) + 토끼 한마디
--   * 못 끼는 장비(툴팁의 빨간 줄: 사슬 · 판금 · 레벨 · 직업)는 무조건 "못 껴요"
--   * 점수 = 능력치 × 역할별 무게 (탱커 · 근접 · 원거리 · 주문 · 힐러)
--   * 차이가 작으면 "비슷해요", 특수 효과가 있으면 "효과는 직접 봐 줘"
-- 지우고 싶으면: 허브에서 끄기, 또는 이 파일과 toc의 Gear.lua 줄을 지우면 끝

local _, ns = ...

local function DB()
    ns.db.gear = ns.db.gear or {}
    local d = ns.db.gear
    if d.on == nil then d.on = true end
    return d                       -- d.role = nil(자동) | "tank" | "melee" | "ranged" | "caster" | "healer"
end
ns.GearDB = DB

local ROLE_NAME = { tank = "탱커", melee = "근접 딜", ranged = "원거리 딜", caster = "주문 딜", healer = "힐러" }
ns.GearRoleName = ROLE_NAME

----------------------------------------------------------------------
-- 역할: 특성 포인트가 제일 많은 계열로 짐작
----------------------------------------------------------------------
local TREE_ROLE = {
    WARRIOR = { "melee", "melee", "tank" },
    PALADIN = { "healer", "tank", "melee" },
    HUNTER  = { "ranged", "ranged", "ranged" },
    ROGUE   = { "melee", "melee", "melee" },
    PRIEST  = { "healer", "healer", "caster" },
    SHAMAN  = { "caster", "melee", "healer" },
    MAGE    = { "caster", "caster", "caster" },
    WARLOCK = { "caster", "caster", "caster" },
    DRUID   = { "caster", "melee", "healer" },
}
local function ClassTag() local _, c = UnitClass("player"); return c end

local function GuessRole()
    local cls = ClassTag()
    local map = TREE_ROLE[cls] or { "melee", "melee", "melee" }
    local best, bp = 1, -1
    if GetNumTalentTabs and GetTalentTabInfo then
        for i = 1, (GetNumTalentTabs() or 0) do
            local ok, a, b, c, d = pcall(GetTalentTabInfo, i)
            -- 클래식: name, icon, pointsSpent / 다른 판: id, name, desc, icon, pointsSpent
            local pts = (type(c) == "number" and c) or (type(d) == "number" and d) or 0
            if ok then
                for _, v in ipairs({ a, b, c, d }) do if type(v) == "number" and v > pts and v < 100 then pts = v end end
            end
            if pts > bp then best, bp = i, pts end
        end
    end
    if bp <= 0 then
        -- 특성이 없으면 직업 기본
        local def = { WARRIOR = "melee", PALADIN = "melee", HUNTER = "ranged", ROGUE = "melee", PRIEST = "healer",
                      SHAMAN = "melee", MAGE = "caster", WARLOCK = "caster", DRUID = "melee" }
        return def[cls] or "melee"
    end
    return map[best] or "melee"
end

local function Role() return DB().role or GuessRole() end
ns.GearRole = Role

----------------------------------------------------------------------
-- 무게 (대략): 이 숫자만 고치면 판정이 바뀌어요
----------------------------------------------------------------------
-- 와우 포에버 기준 무게 (2026-11 조사)
--   * 아이템 능력치는 등급으로 붙어요: 적중도 10 = 1%, 치명타 등급 14 = 1% (근접 · 원거리 · 주문 공통)
--   * 근접 힘 1 = 전투력 2, 민첩 1 = 전투력 1(+치명), 무기 초당 공격력 1 ≈ 전투력 14 (야성 드루이드 포함)
--   * 치유량은 주문 피해에도 1/3 들어가요, 지능 1 = 마나 15, 정신력 = 전투 밖 마나 회복
--   * 우선순위: neverff · undying · MythicSim(시뮬) · chaosboost · world-of-warcraft-forever.wiki 를 맞춰 본 값
--   * 레벨업 중이라 체력은 모두 조금씩 (탱커는 크게)
-- 단위: 그 직업 · 역할의 제일 중요한 능력치 1점 = 1.0
local W = {}
local function Def(cls, role, t) W[cls] = W[cls] or {}; W[cls][role] = t end

-- 근접 (힘 직업): 힘 > 적중 > 치명 > 민첩
local STR_MELEE = { STR = 1.0, AGI = 0.5, AP = 0.5, CRIT = 0.8, HIT = 1.1, EXP = 1.0, HASTE = 0.7, DPS = 7, STA = 0.15, ARMOR = 0.004 }
Def("WARRIOR", "melee", STR_MELEE)
Def("PALADIN", "melee", { STR = 1.0, AGI = 0.45, AP = 0.5, CRIT = 0.8, HIT = 1.1, EXP = 1.0, HASTE = 0.7, INT = 0.3, SP = 0.4, DPS = 7, STA = 0.15, ARMOR = 0.004 })
Def("SHAMAN",  "melee", { STR = 1.0, AGI = 0.6, AP = 0.5, INT = 0.55, CRIT = 0.8, HIT = 1.1, EXP = 1.0, HASTE = 0.7, DPS = 7, STA = 0.15, ARMOR = 0.004 })
-- 근접 (민첩 직업): 민첩 > 적중 > 치명 > 전투력
Def("ROGUE",   "melee", { AGI = 1.0, STR = 0.55, AP = 0.55, CRIT = 0.9, HIT = 1.2, EXP = 1.1, HASTE = 0.75, DPS = 7.7, STA = 0.15, ARMOR = 0.004 })
Def("DRUID",   "melee", { AGI = 1.0, STR = 0.9, AP = 0.45, CRIT = 0.85, HIT = 1.0, EXP = 0.9, HASTE = 0.6, DPS = 6.3, STA = 0.15, ARMOR = 0.006 })
Def("HUNTER",  "melee", { AGI = 1.0, AP = 0.4, RAP = 0.4, INT = 0.35, CRIT = 0.7, HIT = 1.0, HASTE = 0.6, RDPS = 5.6, DPS = 2, STA = 0.15, ARMOR = 0.004 })
-- 원거리 (사냥꾼): 민첩 > 적중 > 치명 > 전투력 > 지능
Def("HUNTER",  "ranged", { AGI = 1.0, RAP = 0.4, AP = 0.4, INT = 0.35, CRIT = 0.7, HIT = 1.0, EXP = 0.3, HASTE = 0.6, RDPS = 5.6, DPS = 1, STA = 0.15, ARMOR = 0.004 })
-- 탱커: 체력 · 방어 · 회피 > 방어도 > 힘/민첩 > 적중
local TANK = { STA = 1.0, ARMOR = 0.05, DEF = 1.0, DODGE = 1.0, PARRY = 0.9, BLOCK = 0.6, BLOCKVAL = 0.3, STR = 0.5, AGI = 0.55, AP = 0.2, HIT = 0.6, EXP = 0.7, DPS = 2.5 }
Def("WARRIOR", "tank", TANK)
Def("PALADIN", "tank", { STA = 1.0, ARMOR = 0.05, DEF = 1.0, DODGE = 0.9, PARRY = 0.8, BLOCK = 0.7, BLOCKVAL = 0.4, STR = 0.45, AGI = 0.45, SP = 0.45, HIT = 0.6, EXP = 0.7, DPS = 2.5 })
Def("DRUID",   "tank", { STA = 1.0, ARMOR = 0.07, AGI = 0.8, DEF = 0.9, DODGE = 1.0, STR = 0.5, AP = 0.2, CRIT = 0.3, HIT = 0.5, EXP = 0.6, DPS = 3 })
-- 주문 딜: 주문력 > 적중 > 치명 > 지능 (흑마는 체력 · 정신력도)
local CASTER = { SP = 1.0, HEAL = 0.33, HIT = 1.1, CRIT = 0.7, HASTE = 0.7, INT = 0.35, SPI = 0.1, MP5 = 0.4, STA = 0.12, ARMOR = 0.002 }
Def("MAGE", "caster", CASTER)
Def("WARLOCK", "caster", { SP = 1.0, HEAL = 0.33, HIT = 1.1, CRIT = 0.6, HASTE = 0.7, INT = 0.3, SPI = 0.3, MP5 = 0.3, STA = 0.3, ARMOR = 0.002 })
Def("PRIEST", "caster", { SP = 1.0, HEAL = 0.33, HIT = 1.1, CRIT = 0.6, HASTE = 0.6, INT = 0.35, SPI = 0.3, MP5 = 0.4, STA = 0.12, ARMOR = 0.002 })
Def("SHAMAN", "caster", { SP = 1.0, HEAL = 0.33, HIT = 1.0, CRIT = 0.8, HASTE = 0.6, INT = 0.35, SPI = 0.1, MP5 = 0.5, STA = 0.12, ARMOR = 0.002 })
Def("DRUID",  "caster", { SP = 1.0, HEAL = 0.33, HIT = 1.0, CRIT = 0.75, HASTE = 0.6, INT = 0.35, SPI = 0.2, MP5 = 0.5, STA = 0.12, ARMOR = 0.002 })
Def("PALADIN","caster", { SP = 1.0, HEAL = 0.33, HIT = 1.0, CRIT = 0.7, HASTE = 0.6, INT = 0.4, SPI = 0.1, MP5 = 0.5, STR = 0.2, STA = 0.15, ARMOR = 0.002 })
-- 힐러: 주문력/치유량 > 지능 > 마나 회복(정신력 · 5초당 마나) > 치명
Def("PRIEST",  "healer", { SP = 1.0, HEAL = 1.0, INT = 0.55, MP5 = 1.0, SPI = 0.5, CRIT = 0.5, HASTE = 0.5, STA = 0.12, ARMOR = 0.002 })
Def("DRUID",   "healer", { SP = 1.0, HEAL = 1.0, SPI = 0.6, INT = 0.5, MP5 = 1.0, CRIT = 0.55, HASTE = 0.5, STA = 0.12, ARMOR = 0.002 })
Def("SHAMAN",  "healer", { SP = 1.0, HEAL = 1.0, INT = 0.55, SPI = 0.5, MP5 = 1.0, CRIT = 0.6, HASTE = 0.5, STA = 0.12, ARMOR = 0.002 })
Def("PALADIN", "healer", { SP = 1.0, HEAL = 1.0, INT = 0.65, CRIT = 0.75, MP5 = 1.0, SPI = 0.3, HASTE = 0.5, STA = 0.12, ARMOR = 0.002 })

-- 그 직업에 없는 역할을 고르면 가까운 것으로
local ROLE_FALLBACK = {
    tank = function(cls) return W.WARRIOR.tank end,
    melee = function(cls) return STR_MELEE end,
    ranged = function(cls) return W.HUNTER.ranged end,
    caster = function(cls) return CASTER end,
    healer = function(cls) return W.PRIEST.healer end,
}

-- 적중이 이미 상한이면 적중 무게를 거의 0으로 (근접 · 원거리 8%, 주문 16%)
local function HitCapped(role)
    local ok, pct = pcall(function()
        if role == "caster" or role == "healer" then
            local r = (GetCombatRatingBonus and CR_HIT_SPELL) and GetCombatRatingBonus(CR_HIT_SPELL) or 0
            return r + ((GetSpellHitModifier and GetSpellHitModifier()) or 0)
        end
        local cr = (role == "ranged") and CR_HIT_RANGED or CR_HIT_MELEE
        local r = (GetCombatRatingBonus and cr) and GetCombatRatingBonus(cr) or 0
        return r + ((GetHitModifier and GetHitModifier()) or 0)
    end)
    if not ok or type(pct) ~= "number" or (issecretvalue and issecretvalue(pct)) then return false end
    local cap = (role == "caster" or role == "healer") and 16 or 8
    return pct >= cap
end

local wCache, wKey
local function Weights()
    local r, cls = Role(), ClassTag()
    local key = (cls or "") .. r
    if wCache and wKey == key then return wCache end
    local base = (W[cls] and W[cls][r]) or ROLE_FALLBACK[r](cls)
    local w = {}
    for k, v in pairs(base) do w[k] = v end
    if HitCapped(r) then w.HIT = (w.HIT or 0) * 0.1 end
    wCache, wKey = w, key
    return w
end
ns.GearWeights = Weights

local STAT_NAME = {
    STR = "힘", AGI = "민첩", STA = "체력", INT = "지능", SPI = "정신력", ARMOR = "방어도",
    AP = "전투력", RAP = "원거리 전투력", SP = "주문력", HEAL = "치유량", MP5 = "마나 회복",
    CRIT = "치명타", HIT = "적중", DEF = "방어 숙련", DODGE = "회피", PARRY = "무기 막기", BLOCK = "방패 막기",
    DPS = "무기 공격력", RDPS = "원거리 무기 공격력",
    EXP = "숙련", HASTE = "가속", BLOCKVAL = "방패 막기 수치",
}
-- 토끼가 쓰는 쉬운 말
local STAT_EASY = {
    STR = "힘", AGI = "민첩", STA = "체력", INT = "마나", SPI = "마나 회복", ARMOR = "방어도",
    AP = "공격력", RAP = "원거리 공격력", SP = "주문 위력", HEAL = "치유량", MP5 = "마나 회복",
    CRIT = "치명타", HIT = "적중", DEF = "방어", DODGE = "회피", PARRY = "막기", BLOCK = "방패 막기",
    DPS = "무기 공격력", RDPS = "원거리 무기 공격력",
    EXP = "숙련", HASTE = "가속", BLOCKVAL = "방패 막기",
}

----------------------------------------------------------------------
-- 능력치 읽기: GetItemStats + 착용 효과 글줄
----------------------------------------------------------------------
local KEYMAP = {
    ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_STAMINA_SHORT = "STA",
    ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_SPIRIT_SHORT = "SPI", RESISTANCE0_NAME = "ARMOR",
    ITEM_MOD_ATTACK_POWER_SHORT = "AP", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP",
    ITEM_MOD_SPELL_POWER_SHORT = "SP", ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SP",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL", ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
    ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
    ITEM_MOD_CRIT_RATING_SHORT = "CRIT", ITEM_MOD_HIT_RATING_SHORT = "HIT",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF", ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
    ITEM_MOD_PARRY_RATING_SHORT = "PARRY", ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
    ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVAL", ITEM_MOD_EXPERTISE_RATING_SHORT = "EXP",
    ITEM_MOD_HASTE_RATING_SHORT = "HASTE", ITEM_MOD_HASTE_MELEE_RATING_SHORT = "HASTE", ITEM_MOD_HASTE_SPELL_RATING_SHORT = "HASTE",
    ITEM_MOD_HASTE_RANGED_RATING_SHORT = "HASTE",
    ITEM_MOD_HIT_MELEE_RATING_SHORT = "HIT", ITEM_MOD_HIT_RANGED_RATING_SHORT = "HIT", ITEM_MOD_HIT_SPELL_RATING_SHORT = "HIT",
    ITEM_MOD_CRIT_MELEE_RATING_SHORT = "CRIT", ITEM_MOD_CRIT_RANGED_RATING_SHORT = "CRIT", ITEM_MOD_CRIT_SPELL_RATING_SHORT = "CRIT",
    ITEM_MOD_MANA_SHORT = nil,
}

local function Num(s) local t = (s or ""):gsub(",", ""); return tonumber(t) end

-- 착용 효과 한 줄에서 아는 능력치를 꺼냄. 모르는 효과면 nil
local function ParseEquipLine(t)
    local n
    -- 등급 글줄 (와우 포에버): "치명타 적중도가 14만큼", "적중도가 10만큼", "가속도가", "숙련도가"
    n = t:match("치명타 적중도가 ([%d,]+)") or t:match("치명타 등급이 ([%d,]+)")
    if n then return "CRIT", Num(n) end
    n = t:match("가속도가 ([%d,]+)") or t:match("가속 등급이 ([%d,]+)")
    if n then return "HASTE", Num(n) end
    n = t:match("숙련도가 ([%d,]+)") and not t:find("방어 숙련") and t:match("숙련도가 ([%d,]+)")
    if n then return "EXP", Num(n) end
    n = t:match("적중도가 ([%d,]+)") or t:match("적중 등급이 ([%d,]+)")
    if n then return "HIT", Num(n) end
    n = t:match("피해와 치유량이 최대 ([%d,]+)") or t:match("피해 및 치유량이 최대 ([%d,]+)") or t:match("주문력이 ([%d,]+)")
    if n then return "SP", Num(n) end
    n = t:match("치유량이 최대 ([%d,]+)") or t:match("치유량이 ([%d,]+)")
    if n then return "HEAL", Num(n) end
    n = t:match("5초마다 ([%d,]+)의 마나") or t:match("5초당 ([%d,]+)의 마나") or t:match("매 5초마다 마나가 ([%d,]+)")
    if n then return "MP5", Num(n) end
    n = t:match("원거리 전투력이 ([%d,]+)")
    if n then return "RAP", Num(n) end
    n = t:match("전투력이 ([%d,]+)")
    if n then return "AP", Num(n) end
    n = t:match("치명타.-([%d%.]+)%%")
    if n then return "CRIT", Num(n) * 14 end
    n = t:match("적중.-([%d%.]+)%%")
    if n then return "HIT", Num(n) * 10 end
    n = t:match("방어 숙련도가 ([%d,]+)") or t:match("방어 숙련도 %+([%d,]+)")
    if n then return "DEF", Num(n) end
    n = t:match("회피.-([%d%.]+)%%")
    if n then return "DODGE", Num(n) * 12 end
    n = t:match("무기 막기.-([%d%.]+)%%")
    if n then return "PARRY", Num(n) * 12 end
end

local function IsRed(c)
    if not c then return false end
    local r, g, b
    if type(c) == "table" then
        if c.GetRGB then r, g, b = c:GetRGB() else r, g, b = c.r, c.g, c.b end
    end
    return type(r) == "number" and r > 0.9 and (g or 1) < 0.3 and (b or 1) < 0.3
end

-- 툴팁 자료 → { stats = {}, effect = bool, red = "사슬" or nil }
local function ReadLines(data, out)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return end
    for i = 2, #data.lines do
        local ln = data.lines[i]
        local lt, rt = ln and ln.leftText, ln and ln.rightText
        if i <= 10 and not out.red then
            if type(rt) == "string" and rt ~= "" and IsRed(ln.rightColor) then out.red = rt
            elseif type(lt) == "string" and lt ~= "" and IsRed(ln.leftColor) then out.red = lt end
        end
        if type(lt) == "string" then
            local eq = lt:match("^착용 효과:%s*(.+)") or lt:match("^Equip:%s*(.+)")
            if eq then
                local k, v = ParseEquipLine(eq)
                if k and v then out.stats[k] = (out.stats[k] or 0) + v else out.effect = true end
            elseif lt:match("^사용 효과:") or lt:match("^발동 효과:") or lt:match("^Use:") or lt:match("^Chance on hit:") then
                out.effect = true
            end
            -- 무기 초당 공격력: "(초당 공격력 12.3)"
            local dps = lt:match("초당 공격력 ([%d%.]+)") or lt:match("([%d%.]+) damage per second")
            if dps then out.dps = tonumber(dps) end
        end
    end
end

local cache = {}
local function ItemInfo(link, data)
    if not link then return end
    local c = cache[link]
    if c and (not data or c.fromData) then return c end
    c = { stats = {}, effect = false }
    local getStats = (C_Item and C_Item.GetItemStats) or GetItemStats
    if getStats then
        local ok, t = pcall(getStats, link)
        if ok and type(t) == "table" then
            for k, v in pairs(t) do
                local key = KEYMAP[k]
                if key and type(v) == "number" then c.stats[key] = (c.stats[key] or 0) + v end
                if k == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" and type(v) == "number" then c.dps = v end
            end
        end
    end
    if not data and C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local ok, d = pcall(C_TooltipInfo.GetHyperlink, link)
        if ok then data = d end
    end
    ReadLines(data, c)
    c.fromData = data ~= nil
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if instant then
        local ok, _, _, _, equipLoc, _, classID = pcall(instant, link)
        if ok then c.equipLoc = equipLoc; c.classID = classID end
    end
    cache[link] = c
    return c
end

local function Score(info, slotKind)
    local w = Weights()
    local s, parts = 0, {}
    for k, v in pairs(info.stats) do
        local wk = w[k] or 0
        parts[k] = v * wk
        s = s + v * wk
    end
    if info.dps then
        local key = (slotKind == "ranged") and "RDPS" or "DPS"
        local wk = w[key] or 0
        parts[key] = info.dps * wk
        s = s + info.dps * wk
    end
    return s, parts
end

----------------------------------------------------------------------
-- 어느 칸과 비교할지
----------------------------------------------------------------------
local LOC_SLOT = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
local SLOT_NAME = { [1] = "머리", [2] = "목", [3] = "어깨", [5] = "가슴", [6] = "허리", [7] = "다리", [8] = "발",
    [9] = "손목", [10] = "손", [11] = "반지", [12] = "반지", [13] = "장신구", [14] = "장신구", [15] = "망토",
    [16] = "무기", [17] = "보조 손", [18] = "원거리" }

local DUAL = { WARRIOR = true, ROGUE = true, HUNTER = true }   -- 쌍수 가능 (주술사는 특성이 있어야 해서 빼요)

local function EquippedInfo(slot)
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
    if not link then return nil end
    local data
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local ok, d = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
        if ok then data = d end
    end
    return ItemInfo(link, data), link
end

-- 결과: { kind = "cant"|"empty"|"up"|"down"|"same", new, cur, diff, slot, reason, gain, loss, unused, effect }
local function Judge(link, data)
    local info = ItemInfo(link, data)
    if not info or not info.equipLoc or info.equipLoc == "" then return end
    local slots = LOC_SLOT[info.equipLoc]
    if not slots then return end
    local res = { effect = info.effect }
    if info.red then
        res.kind = "cant"; res.reason = info.red
        return res
    end
    -- 무기 칸 정리: 지금 양손 무기를 들고 있거나, 쌍수를 못 드는 직업이면 보조 손과 비교하지 않아요
    local mhLink = GetInventoryItemLink and GetInventoryItemLink("player", 16)
    local mhInfo = mhLink and ItemInfo(mhLink)
    local twoHanded = mhInfo and mhInfo.equipLoc == "INVTYPE_2HWEAPON"
    if info.equipLoc == "INVTYPE_WEAPON" then
        if twoHanded or not DUAL[ClassTag()] then slots = { 16 } end
    elseif slots[1] == 17 and twoHanded then
        res.kind = "twohand"
        return res
    end
    local kind = (slots[1] == 18) and "ranged" or nil
    local newS, newParts = Score(info, kind)
    res.new = newS

    -- 비교할 칸: 두 칸짜리(반지 · 장신구 · 한손 무기)는 더 약한 쪽
    local curS, curInfo, curSlot
    for _, sl in ipairs(slots) do
        local ci, cl = EquippedInfo(sl)
        if cl == link then return end            -- 지금 끼고 있는 그 템
        local sc = ci and Score(ci, kind) or -1  -- 빈 칸은 -1
        if curS == nil or sc < curS then curS, curInfo, curSlot = sc, ci, sl end
    end
    res.slot = curSlot
    if curS == nil or curS < 0 then res.kind = "empty"; return res end

    -- 능력치를 그대로 더해서 비교 (두손 무기 ↔ 지금 한손 + 보조 손)
    local function Raw(ci, into)
        for k, v in pairs(ci.stats) do into[k] = (into[k] or 0) + v end
        if ci.dps then local key = (kind == "ranged") and "RDPS" or "DPS"; into[key] = (into[key] or 0) + ci.dps end
    end
    local newRaw, curRaw = {}, {}
    Raw(info, newRaw); Raw(curInfo, curRaw)
    if info.equipLoc == "INVTYPE_2HWEAPON" then
        local oi = EquippedInfo(17)
        if oi then curS = curS + Score(oi); Raw(oi, curRaw) end
    end
    res.cur = curS
    res.diff = newS - curS

    -- 바뀌는 능력치를 셋으로: 늘어서 좋은 것 · 줄어서 아쉬운 것 · 이 역할은 안 쓰는 것
    local w = Weights()
    local gains, losses, unused = {}, {}, {}
    local keys = {}
    for k in pairs(newRaw) do keys[k] = true end
    for k in pairs(curRaw) do keys[k] = true end
    for k in pairs(keys) do
        local d = (newRaw[k] or 0) - (curRaw[k] or 0)
        if math.abs(d) >= 0.05 then
            local wd = d * (w[k] or 0)
            local e = { k = k, d = d, wd = wd }
            if (w[k] or 0) == 0 then unused[#unused + 1] = e
            elseif wd > 0 then gains[#gains + 1] = e
            else losses[#losses + 1] = e end
        end
    end
    table.sort(gains, function(x, y) return x.wd > y.wd end)
    table.sort(losses, function(x, y) return x.wd < y.wd end)
    table.sort(unused, function(x, y) return math.abs(x.d) > math.abs(y.d) end)
    res.gains, res.losses, res.unusedList = gains, losses, unused
    res.gain = gains[1] and gains[1].k
    res.loss = losses[1] and losses[1].k
    res.unused = unused[1] and unused[1].k
    local base = math.max(math.abs(curS), 4)
    if math.abs(res.diff) < math.max(1.5, base * 0.05) then res.kind = "same"
    elseif res.diff > 0 then res.kind = "up" else res.kind = "down" end
    return res
end
ns.GearJudge = Judge

----------------------------------------------------------------------
-- 보여 주기: 툴팁 줄 + 토끼 말풍선
----------------------------------------------------------------------
local C = ns.C or {}
local bubble
local function MakeBubble()
    if bubble then return bubble end
    local f = CreateFrame("Frame", "LeelUI_GearBubble", UIParent)
    f:SetFrameStrata("TOOLTIP"); f:SetFrameLevel(50)
    f:SetSize(200, 30)
    if ns.RoundRect then
        f.bg = ns.RoundRect(f, 10, { 1, 0.953, 0.965 }, "BACKGROUND", 0, 0)
    else
        local t = f:CreateTexture(nil, "BACKGROUND"); t:SetAllPoints(); t:SetColorTexture(1, 0.953, 0.965, 1)
    end
    local bun = f:CreateTexture(nil, "ARTWORK")
    bun:SetTexture((ns.MEDIA or "Interface\\AddOns\\LeelUI\\media\\") .. "bunny")
    bun:SetSize(24, 24); bun:SetPoint("LEFT", f, "LEFT", 5, 0)
    f.fs = f:CreateFontString(nil, "OVERLAY")
    if ns.Font then
        f.fs:Hide(); f.fs = ns.Font(f, 12, { 0.227, 0.133, 0.157 })
    else
        f.fs:SetFont(STANDARD_TEXT_FONT, 12, ""); f.fs:SetTextColor(0.227, 0.133, 0.157)
    end
    f.fs:SetShadowColor(0, 0, 0, 0)
    f.fs:SetPoint("LEFT", bun, "RIGHT", 6, 0)
    f.fs:SetJustifyH("LEFT"); f.fs:SetWordWrap(true)
    f.fs:SetWidth(240)
    f:Hide()
    bubble = f
    return f
end

-- 받침에 맞는 조사 (힘이 / 민첩이 / 체력이 · 마나가)
local function Josa(word, withJong, noJong)
    local last = word:match("[\128-\255]+$") or ""
    local b1, b2, b3 = last:byte(-3, -1)
    if b1 and b1 >= 0xEA and b1 <= 0xED then
        local code = ((b1 % 16) * 4096) + ((b2 % 64) * 64) + (b3 % 64)
        if code >= 0xAC00 and code <= 0xD7A3 then
            return word .. (((code - 0xAC00) % 28 ~= 0) and withJong or noJong)
        end
    end
    return word .. withJong
end

local function Names(list, n)
    local out = {}
    for i = 1, math.min(n or 2, #list) do out[#out + 1] = STAT_NAME[list[i].k] or list[i].k end
    return table.concat(out, " · ")
end

local function Say(res)
    local slotName = res.slot and SLOT_NAME[res.slot] or "지금 장비"
    local fx = res.effect and "\n특수 효과는 직접 봐 줘" or ""
    local roleName = ROLE_NAME[Role()] or ""
    local unusedNote = ""
    if res.unusedList and #res.unusedList > 0 then
        unusedNote = "\n|cff8a7a76" .. Josa(Names(res.unusedList, 2), "은", "는") .. " " .. roleName .. "에겐 거의 안 써|r"
    end
    if res.kind == "cant" then
        local r = res.reason or ""
        local lv = r:match("(%d+)")
        if lv and r:find("레벨") then return ("아직 못 껴. %s레벨이 되면 끼자!"):format(lv) end
        return ("이건 |cffc0392b%s|r 때문에 못 껴.\n상점에 팔자!"):format(r)
    elseif res.kind == "empty" then
        return ("%s 칸이 비어 있어. 바로 끼자!"):format(slotName) .. fx
    elseif res.kind == "twohand" then
        return "지금 양손 무기를 들고 있어서\n보조 손만으로는 비교가 어려워"
    end
    local G = (#res.gains > 0) and Names(res.gains, 2) or nil
    local L = (#res.losses > 0) and Names(res.losses, 2) or nil
    local txt
    if res.kind == "up" then
        txt = (G and ("|cff2e8b3a" .. Josa(G, "이", "가") .. "|r 늘어서 더 좋아.") or "지금 거보다 좋아.")
        txt = txt .. (L and ("\n" .. Josa(L, "은", "는") .. " 조금 줄지만 바로 끼자") or "\n바로 끼자")
    elseif res.kind == "down" then
        txt = (L and ("|cffc0392b" .. Josa(L, "이", "가") .. "|r 줄어서 손해야.") or "지금 거가 더 나아.")
        txt = txt .. (G and ("\n" .. Josa(G, "은", "는") .. " 늘지만 지금 거 그대로 쓰자") or "\n지금 거 그대로 쓰자")
    else
        if G and L then txt = Josa(G, "은", "는") .. " 늘고 " .. Josa(L, "은", "는") .. " 줄어.\n비슷해, 취향대로 골라"
        else txt = "비슷해. 취향대로 골라" end
    end
    return txt .. unusedNote .. fx
end

ns.GearSay = Say

local function ShowBubble(tt, res)
    if not DB().bubble then return end
    local f = MakeBubble()
    f.fs:SetText(Say(res))
    local w, h = 160, 14
    pcall(function() w = f.fs:GetStringWidth(); h = f.fs:GetStringHeight() end)
    if type(w) ~= "number" or (issecretvalue and issecretvalue(w)) then w = 160 end
    if type(h) ~= "number" or (issecretvalue and issecretvalue(h)) then h = 14 end
    f:SetSize(math.min(w, 240) + 46, math.max(30, h + 14))
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", tt, "TOPLEFT", 0, 6)
    f.owner = tt
    f:Show()
end

local function HideBubble(tt)
    if bubble and (not tt or bubble.owner == tt) then bubble:Hide() end
end

-- 툴팁 안 토끼 말풍선 (점수 · 숫자 없이 반말 조언)
--   툴팁에 빈 줄을 몇 개 만들어 자리를 잡고, 그 위에 토끼 + 연분홍 말풍선을 얹어요
local MEDIA = ns.MEDIA or "Interface\\AddOns\\LeelUI\\media\\"
local TXT = { 0.227, 0.133, 0.157 }
local RED, GRN, GRY = "|cffc0392b", "|cff2e8b3a", "|cff9a7f84"
local LINE_H = 14

local pads = {}       -- 툴팁마다 말풍선 하나
local function Pad(tt)
    local p = pads[tt]
    if p then return p end
    p = CreateFrame("Frame", nil, UIParent)
    p:SetFrameStrata("TOOLTIP")
    -- 아까처럼: 연분홍 둥근 판 하나, 토끼는 판 안 왼쪽
    p.box = CreateFrame("Frame", nil, p)
    p.box:SetAllPoints(p)
    if ns.RoundRect then ns.RoundRect(p.box, 10, { 1, 0.953, 0.965 }, "BACKGROUND", 0, 0)
    else local t = p.box:CreateTexture(nil, "BACKGROUND"); t:SetAllPoints(); t:SetColorTexture(1, 0.953, 0.965, 1) end
    -- 말풍선 꼬리: 오른쪽 아래, 툴팁 모서리의 토끼 쪽으로 (45도 돌린 네모)
    p.tail = p.box:CreateTexture(nil, "BACKGROUND", nil, 1)
    p.tail:SetTexture("Interface\\Buttons\\WHITE8X8"); p.tail:SetSize(10, 10)
    p.tail:SetVertexColor(1, 0.953, 0.965, 1)
    pcall(p.tail.SetRotation, p.tail, math.rad(45))
    p.tail:SetPoint("CENTER", p.box, "BOTTOMRIGHT", -12, 1)
    -- 줄마다 글씨 하나씩 (여러 줄 한 글씨는 잘려 보여서)
    p.rows = {}
    for i = 1, 7 do
        local fs = ns.Font and ns.Font(p.box, 12, TXT) or p.box:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        fs:SetJustifyH("LEFT"); fs:SetWordWrap(false); fs:SetShadowColor(0, 0, 0, 0)
        fs:SetTextColor(TXT[1], TXT[2], TXT[3])
        fs:SetPoint("TOPLEFT", p.box, "TOPLEFT", 11, -6 - (i - 1) * LINE_H)
        fs:SetPoint("RIGHT", p.box, "RIGHT", -6, 0)
        fs:Hide()
        p.rows[i] = fs
    end
    p.role = ns.Font and ns.Font(p.box, 10, { 0.6, 0.5, 0.52 }) or p.box:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    p.role:SetShadowColor(0, 0, 0, 0)
    p.role:SetPoint("TOPRIGHT", p.box, "TOPRIGHT", -8, -7)
    p.meas = ns.Font and ns.Font(p, 12, TXT) or p:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    p.meas:Hide()
    p:Hide()
    local function Reset()
        p:Hide()
        if p.minW then pcall(tt.SetMinimumWidth, tt, 0); p.minW = nil end
    end
    tt:HookScript("OnHide", Reset)
    pcall(tt.HookScript, tt, "OnTooltipCleared", Reset)
    pads[tt] = p
    return p
end

local function Width(p, line)
    p.meas:SetText(line)
    local w = 120
    pcall(function() local x = p.meas:GetStringWidth(); if type(x) == "number" and not (issecretvalue and issecretvalue(x)) then w = x end end)
    return w
end

-- 상황별 토끼 말 (첫 줄은 굵은 결론)
local function Talk(res)
    local role = ROLE_NAME[Role()] or ""
    local slotName = res.slot and SLOT_NAME[res.slot] or "장비"
    local G = res.gains and #res.gains > 0 and Names(res.gains, 2) or nil
    local L = res.losses and #res.losses > 0 and Names(res.losses, 2) or nil
    local lines = {}
    local function add(t) lines[#lines + 1] = t end
    if res.kind == "cant" then
        local r = res.reason or ""
        local lv = r:match("(%d+)")
        if lv and r:find("레벨") then
            add("아직 못 껴. " .. lv .. "레벨이 되면 끼자!")
        else
            local cname = UnitClass("player") or ""
            if r:find(":") or #r > 18 then add(RED .. r .. "|r 때문에 못 껴.")
            else add(Josa(cname, "은", "는") .. " " .. RED .. Josa(r, "을", "를") .. "|r 못 입어.") end
            add("상점에 팔자!")
        end
        return lines
    elseif res.kind == "empty" then
        add(Josa(slotName, "이", "가") .. " 비어 있어. 바로 끼자!")
    elseif res.kind == "up" then
        add(G and ("오! " .. GRN .. Josa(G, "이", "가") .. "|r 늘어서 더 좋아.") or ("오! 지금 " .. slotName .. "보다 좋아."))
        add(L and (RED .. Josa(L, "은", "는") .. "|r 조금 줄지만 바로 끼자!") or "바로 끼자!")
    elseif res.kind == "down" then
        add(L and (RED .. Josa(L, "이", "가") .. "|r 줄어서 손해야.") or "지금 거가 더 나아.")
        add(G and (GRN .. Josa(G, "은", "는") .. "|r 늘지만 지금 거 그대로 쓰자") or "지금 거 그대로 쓰자")
    else
        if G and L then add(GRN .. Josa(G, "은", "는") .. "|r 늘고 " .. RED .. Josa(L, "은", "는") .. "|r 줄어.") end
        add("비슷비슷해. 편한 걸로 골라.")
    end
    if res.unusedList and #res.unusedList > 0 then
        add(GRY .. Josa(Names(res.unusedList, 2), "은", "는") .. " " .. role .. "엔 거의 안 써.|r")
    end
    if res.effect then add(GRY .. "특수 효과는 직접 봐 줘.|r") end
    return lines
end

-- 툴팁 바로 위에 토끼 + 말풍선 (툴팁 안에는 아무것도 안 넣어요)
local function AddLines(tt, res)
    local lines
    if res.kind == "twohand" then
        lines = { "지금 양손 무기를 들고 있어서", GRY .. "보조 손만으로는 비교가 어려워.|r" }
    else
        lines = Talk(res)
    end
    local p = Pad(tt)
    for i, fs in ipairs(p.rows) do
        if lines[i] then fs:SetText(lines[i]); fs:Show() else fs:SetText(""); fs:Hide() end
    end
    local roleTag = ""      -- 역할 표시는 빼요 (회색 줄 "근접 딜엔 거의 안 써"로 충분)
    p.role:SetText(roleTag)
    local maxW = 0
    for i, l in ipairs(lines) do maxW = math.max(maxW, Width(p, l) + ((i == 1 and roleTag ~= "") and 64 or 0)) end
    p:SetSize(11 + maxW + 12, math.max(26, #lines * LINE_H + 11))
    p:ClearAllPoints()
    -- 툴팁 오른쪽 위 모서리의 토끼가 말하는 것처럼: 말풍선 오른쪽 아래를 그 토끼 위에
    p:SetPoint("BOTTOMRIGHT", tt, "TOPRIGHT", 8, 22)
    p:Show()
end

ns.GearAddLines = AddLines

local function OnItem(tt, data)
    if pads[tt] then pads[tt]:Hide() end
    if not DB().on then return end
    if tt ~= GameTooltip and tt ~= _G.ItemRefTooltip then return end
    local ok, _, link = pcall(tt.GetItem, tt)
    if not ok or type(link) ~= "string" then return end
    local okJ, res = pcall(Judge, link, data)
    if not okJ or not res then return end
    pcall(AddLines, tt, res)
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItem)
end


-- 장비를 바꾸면 점수 다시 계산
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("CHARACTER_POINTS_CHANGED")
ev:SetScript("OnEvent", function() wipe(cache); wCache = nil end)

----------------------------------------------------------------------
-- 명령: /장비  역할 탱커|근접|원거리|주문|힐러|자동 · 끄기 · 켜기 · 토끼
----------------------------------------------------------------------
local ROLE_IN = { ["탱커"] = "tank", ["탱"] = "tank", ["근접"] = "melee", ["원거리"] = "ranged", ["주문"] = "caster",
    ["딜러"] = "caster", ["힐러"] = "healer", ["힐"] = "healer", tank = "tank", melee = "melee", ranged = "ranged",
    caster = "caster", healer = "healer" }
local function P(m) print("|cfff2b3c2[르엘 장비]|r " .. m) end
function ns.GearSetRole(r)
    DB().role = r; wipe(cache); wCache = nil
    P("이제 " .. (r and ROLE_NAME[r] or ("자동 (" .. (ROLE_NAME[GuessRole()] or "") .. ")")) .. " 기준으로 비교해요.")
end
SLASH_LEELGEAR1 = "/장비"
SLASH_LEELGEAR2 = "/lgear"
SlashCmdList.LEELGEAR = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    if cmd == "역할" then
        if arg == "자동" or arg == "" then ns.GearSetRole(nil)
        elseif ROLE_IN[arg] then ns.GearSetRole(ROLE_IN[arg])
        else P("예: /장비 역할 힐러  (탱커 · 근접 · 원거리 · 주문 · 힐러 · 자동)") end
    elseif cmd == "끄기" then DB().on = false; P("장비 비교를 껐어요.")
    elseif cmd == "켜기" then DB().on = true; P("장비 비교를 켰어요.")
    else
        P("지금: " .. (DB().on and "켜짐" or "꺼짐") .. " · " .. (ROLE_NAME[Role()] or "") .. " 기준" .. (DB().role and "" or " (자동)"))
        print("  /장비 역할 힐러  — 탱커 · 근접 · 원거리 · 주문 · 힐러 · 자동")
        print("  /장비 끄기 · 켜기")
    end
end
