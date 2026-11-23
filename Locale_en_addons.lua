-- LeelUI / Locale_en_addons.lua
-- 영어 번역 (4단계: Leel Map · Leel Mark · Leel Spot)

local _, ns = ...
local E = ns.EN

E["너무 어려워요"] = "Way too hard"
E["조금 어려워요"] = "A bit hard"
E["경험치 거의 없어요"] = "Almost no XP"
E["쉬워요"] = "Easy"
E["딱 맞아요"] = "Just right"
E["퀘스트: "] = "Quest: "
E["나 · "] = "Me · "
E["마우스 · "] = "Mouse · "
E["누르면 마지막 마우스 좌표를 찍기 칸에"] = "Click to put the last mouse coordinates in the pin box"
E["이 지도에는 핀을 찍을 수 없어요 (지역 지도에서 해 주세요)"] = "Can't drop a pin on this map (use a zone map)"
E["%s %.1f, %.1f 에 핀을 찍었어요 · 지우기 = [찍기] 오른쪽 클릭"] = "Dropped a pin at %s %.1f, %.1f · clear = right-click [Pin]"
E["찍기"] = "Pin"
E["좌표를 \"45.3, 62.1\" 처럼 넣어 주세요"] = "Enter coordinates like \"45.3, 62.1\""
E["핀을 지웠어요"] = "Pin cleared"
E["지금 보는 지도에 핀 + 길 안내"] = "Pin + guide on the map you're viewing"
E["오른쪽 클릭: 핀 지우기"] = "Right-click: clear pin"
E["끌어서 지도 옮기기"] = "Drag to move the map"
E["/lmap 위치 : 처음 자리로"] = "/lmap reset : back to the default spot"
E["|cfff2b3c2Leel Map|r\n\nOpenMap을 찾았어요.\n이어 붙인 지도는 그대로 쓰고, OpenMap 설정 단추와 르엘 UI와 겹치는 기능(친구·길드 위치, 위치 공유, 핀 공유, 던전 지도 옆 칸, 좌표 알약)은 숨겼어요. 길드원 위치는 Leel Map이 보여줘요.\n\n지금 다시 불러올까요?"] = "|cfff2b3c2Leel Map|r\n\nFound OpenMap.\nThe stitched map stays, and OpenMap's settings button and features that overlap LeelUI (friend·guild positions, position sharing, pin sharing, dungeon map side panel, coordinate pill) are hidden. Leel Map shows guildmate positions.\n\nReload now?"
E["|cfff2b3c2Leel Map|r\n\nLeatrix Maps를 찾았어요.\n안 가 본 곳 밝히기(연분홍)를 켜고, 겹치는 기능은 Leel Map 쪽으로 맞출게요.\n\n지금 다시 불러올까요?"] = "|cfff2b3c2Leel Map|r\n\nFound Leatrix Maps.\nI'll turn on revealing unexplored areas (light pink) and align overlapping features with Leel Map.\n\nReload now?"
E["작은 창 지도 "] = "Windowed map "
E[" (지도를 다시 열면 적용)"] = " (applies when you reopen the map)"
E["걸을 때 흐림 "] = "Fade while walking "
E["켬 ("] = "On ("
E["/lmap 찍기 45.3 62.1 처럼 써 주세요"] = "Use it like /lmap pin 45.3 62.1"
E["좌표 줄 "] = "Coordinate row "
E["지역 레벨 표시 "] = "Zone levels "
E["출구"] = "Exits"
E["내 위치 길드에 알리기 끔"] = "Share my position with guild off"
E["내 위치 길드에 알리기 켬"] = "Share my position with guild on"
E["시험"] = "Test"
E["지도 자리를 처음대로 돌렸어요. 지도를 다시 열어 보세요."] = "Map position reset. Reopen the map."
E["지도 창 꾸미기 "] = "Style the map window "
E[" (/reload 후 적용)"] = " (applies after /reload)"
E["/lmap 작게 · 흐림 (또는 흐림 40) · 좌표 · 레벨 · 위치 · 꾸미기 · 점검"] = "/lmap mini · fade (or fade 40) · coords · levels · reset · skin · debug"
E["레벨 %d %s"] = "Level %d %s"
E["클릭: 귓말 · 오른쪽 클릭: 길 안내 핀"] = "Click: whisper · right-click: guide pin"
E[" 쪽에 길 안내 핀을 찍었어요"] = " guide pin dropped"
E["이 지도에는 핀을 찍을 수 없어요"] = "Can't drop a pin on this map"
E["지금 접속한 길드원이 없어요\n(르엘 지도를 쓰는 길드원만 보여요)"] = "No guildmates online right now\n(only guildmates using Leel Map are shown)"
E["르엘 UI 쓰는 길드원"] = "Guildmates using LeelUI"
E["누르면 목록 · 목록에서 클릭하면 그 지역 지도로, 오른쪽 클릭은 귓말"] = "Click for the list · click in the list to open that zone's map, right-click to whisper"
E["르엘 UI를 쓰는 길드원끼리 지도에서 서로 위치가 보여요. 끄려면 허브 > Leel Map > \"내 위치 길드에 알리기\""] = "Guildmates using LeelUI can see each other's positions on the map. To turn it off: Hub > Leel Map > \"Share my position with guild\""
E["지금은 내 위치를 알 수 없어요"] = "Can't tell your position right now"
E["토끼친구(시험)"] = "Bunny buddy (test)"
E["내 오른쪽 위에 시험용 토끼를 세웠어요. 지도와 미니맵을 열어 보세요 (40초 뒤 사라져요)"] = "Placed a test bunny to your upper right. Open the map and minimap (gone in 40 seconds)"
E["지금 위치가 보이는 길드원이 없어요 (르엘 UI를 쓰는 길드원만 보여요)"] = "No guildmates with visible positions right now (only guildmates using LeelUI are shown)"
E["레벨 %s  %s"] = "Level %s  %s"
E["클릭하면 그 지역 지도로"] = "Click to open that zone's map"
E["한 번 넘어가 보면 실제 길 자리로 옮겨져요"] = "Cross it once and it moves to the actual path spot"
E["%s (%d) 출구:"] = "%s (%d) exits:"
E["다녀 본 길"] = "Path I've walked"
E["경계"] = "Border"
E["다이아"] = "Diamond"
E["세모"] = "Triangle"
E["달"] = "Moon"
E["해골"] = "Skull"
E["징을 찍을 수 없어요: "] = "Can't set the mark: "
E[" 덫"] = " Trap"
E[" 변이"] = " Polymorph"
E[" 혼절"] = " Sap"
E["30m 안에 징을 찍을 적이 없어요. 조금 더 다가가서 눌러 주세요."] = "No enemies to mark within 30m. Move a bit closer and press again."
E["징을 찍을 적이 안 보여요. (적 이름표가 켜져 있어야 해요)"] = "Can't see enemies to mark. (Enemy nameplates must be on)"
E["해골 먼저"] = "Skull first"
E["X 다음"] = "X next"
E["는 "] = " is "
E["멀리 있는 "] = "far away "
E["마리는 뺐어요"] = " left out"
E[" 먼저"] = " first"
E[" 다음"] = " next"
E["파티에 있을 때 알릴 수 있어요."] = "You can announce when you're in a party."
E["번째로 잡아요"] = " to kill"
E["왼쪽 클릭: 대상에 찍기 · 오른쪽 클릭: 대상 징 지우기"] = "Left-click: mark target · right-click: clear target's mark"
E[" 님 약속"] = "'s plan"
E["끌어서 옮기기 · 징에 마우스 = 약속 서랍 · 단축키(애드온 > Leel Mark) · /lmark"] = "Drag to move · hover a mark = plan drawer · keybinds (AddOns > Leel Mark) · /lmark"
E["대상(없으면 가장 가까운 몹) 둘레 무리에만 약속표 순서대로 빈 징을 채워요 (시전 몹·정예 먼저). 전투 밖에서만"] = "Fills empty marks in plan order only on the pack around your target (or the nearest mob) (casters·elites first). Out of combat only"
E["전투 중에는 자동을 쓸 수 없어요. 징 단추나 마우스 단축키를 써 주세요."] = "Auto can't be used in combat. Use the mark buttons or the mouseover keybind."
E["공격대에서는 공격대장·부공격대장만 징을 찍을 수 있어요."] = "In a raid, only the leader·assistants can set marks."
E["자동 매크로:\n"] = "Auto macro:\n"
E["약속 알리기"] = "Announce plan"
E["파티 채팅에 징 약속을 한 줄로 (징 그림) · 르엘 UI 쓰는 파티원 이름표에도 같은 순서가 보여요"] = "Posts the mark plan as one line in party chat (mark icons) · party members using LeelUI see the same order on nameplates"
E["지우기"] = "Clear"
E["모든 징을 지워요"] = "Clears all marks"
E["자동으로 징 찍기 (전투 밖)"] = "Auto mark (out of combat)"
E["징 모두 지우기"] = "Clear all marks"
E["마우스 올린 몹에 다음 징"] = "Next mark on mouseover mob"
E[" 님의 징 약속표를 받았어요 (이름표 순서가 같아져요)"] = "'s mark plan received (nameplate order now matches)"
E["게임 규칙상 채팅 명령으로는 징을 못 찍어요. 바의 단추나 단축키를 써 주세요."] = "Game rules don't allow marking from chat commands. Use the bar buttons or keybinds."
E["바를 항상 보여요."] = "Bar always shown."
E["바는 파티일 때만 보여요."] = "Bar shown only in party."
E["바를 숨겼어요. /lmark 보이기 로 다시 켜요. (단축키는 계속 동작)"] = "Bar hidden. Turn it back on with /lmark show. (Keybinds still work)"
E["자동으로 찍을 때 파티 채팅 알림 "] = "Party chat notice when auto marking "
E["바 크기 "] = "Bar size "
E["무리"] = "Pack"
E["자동: "] = "Auto: "
E["대상 둘레 가까운 무리만 찍어요"] = "Marks only the nearby pack around your target"
E["보이는 적 전부 찍어요"] = "Marks all visible enemies"
E["점검 "] = "Debug "

E["바 자리를 처음대로 돌렸어요."] = "Bar position reset."
E["/lmark 보이기 · 숨기기 · 알림 · 무리 · 크기 80 · 위치"] = "/lmark show · hide · announce · pack · scale 80 · reset"
E["단축키: 게임 메뉴 > 단축키 > 애드온 > Leel Mark (자동 · 지우기 · 마우스 올린 몹에 다음 징)"] = "Keybinds: Game Menu > Key Bindings > AddOns > Leel Mark (auto · clear · next mark on mouseover mob)"
E["|r  줍기"] = "|r  loot"
E["/lspot 또는 /물건"] = "/lspot"
E["  켜기 · 끄기  — 이름표 켜고 끄기"] = "  on · off  — turn labels on and off"
E["  퀘만  — 퀘스트 물건(진행도 있는 것)에만 표시 / 다시 치면 모든 물건"] = "  quest  — show only on quest objects (with progress) / again for all objects"
E["  크기 0.8~1.6  — 이름표 크기"] = "  size 0.8~1.6  — label size"
E["  선 숫자  — 이름표에서 물건까지 선 길이 (기본 34, 0이면 끔)"] = "  stem number  — line length from label to object (default 34, 0 = off)"
E["  높이 숫자  — 선 끝 위치 위아래 미세 조정 (기본 0)"] = "  y number  — fine-tune the line end up/down (default 0)"
E["  시체  — 주울 시체 위 반짝 상자 켜고 끄기"] = "  loot  — sparkle box over lootable corpses on/off"
E["  여러시체  — 다른 주울 시체에도 작은 상자 켜고 끄기"] = "  multi  — small boxes on other lootable corpses on/off"
E["  시체높이 숫자  — 상자 위아래 (기본 -70, 더 작게 = 더 아래로)"] = "  looty number  — box up/down (default -70, smaller = lower)"
E["  반짝  — 게임 반짝이(테두리 강조 대신) 켜고 끄기"] = "  sparkle  — game sparkle (instead of border highlight) on/off"
E["  점검  — 지금 고른 물건 정보"] = "  debug  — info on the selected object"
E["켰어요."] = "On."
E["껐어요."] = "Off."
E["모든 물건에 표시해요 (퀘스트 물건만 분홍)."] = "Shown on all objects (quest objects in pink)."
E["퀘스트 물건에만 표시해요."] = "Shown only on quest objects."
E["예: /lspot 크기 1.2"] = "e.g. /lspot size 1.2"
E["높이 "] = "Height "
E["예: /lspot 높이 10"] = "e.g. /lspot y 10"
E["전투 끝나고 해주세요."] = "Please do it after combat."
E["지금 상호작용 키: "] = "Current interact key: "
E["  (예: /lspot 키 F)"] = "  (e.g. /lspot key F)"
E[" = 상호작용(줍기)"] = " = interact (loot)"
E["  |cff9d8a86(원래: "] = "  |cff9d8a86(was: "
E["선 길이 "] = "Line length "
E[" (선 끔)"] = " (line off)"
E["예: /lspot 선 40  (0이면 끔)"] = "e.g. /lspot stem 40  (0 = off)"
E["주울 시체에 반짝 상자를 띄워요."] = "Sparkle box on lootable corpses."
E["시체 표시를 껐어요."] = "Corpse marker off."
E["다른 주울 시체에도 작은 상자를 띄워요."] = "Small boxes on other lootable corpses too."
E["가장 가까운 시체 하나만 띄워요."] = "Only the nearest corpse."
E["시체 상자 높이 "] = "Corpse box height "
E["예: /물건 시체높이 -100  (더 작을수록 아래)"] = "e.g. /lspot looty -100  (smaller = lower)"
E["멀리서도 퀘스트 물건이 반짝여요. (처음엔 게임을 껐다 켜야 보일 수 있어요)"] = "Quest objects sparkle from afar. (The first time you may need to restart the game)"
E["반짝이를 끄고 테두리 강조로 돌렸어요. 게임을 껐다 켜야 완전히 돌아가요."] = "Sparkle off, back to border highlight. Restart the game for it to fully revert."
E["키 칩 보여요."] = "Key chip shown."
E["키 칩 숨겨요."] = "Key chip hidden."

E["줍기"] = "Loot"

-- 이어 붙인 문장 (패턴)
local P = ns.EN_PAT
local function L(a) return ns.L(a) end
local function OnOff(a) return (a == "끔" and "off") or (a == "켬" and "on") or a end
-- Leel Map
P[#P + 1] = { "^나 · (.+)$", "Me · %1" }
P[#P + 1] = { "^마우스 · (.+)$", "Mouse · %1" }
P[#P + 1] = { "^작은 창 지도 (.-) %(지도를 다시 열면 적용%)$", function(a) return "Windowed map " .. OnOff(a) .. " (applies when you reopen the map)" end }
P[#P + 1] = { "^걸을 때 흐림 켬 %((%d+)%%%)$", "Fade while walking on (%1%%)" }
P[#P + 1] = { "^걸을 때 흐림 끔$", "Fade while walking off" }
P[#P + 1] = { "^좌표 줄 (.+)$", function(a) return "Coordinate row " .. OnOff(a) end }
P[#P + 1] = { "^지역 레벨 표시 (.+)$", function(a) return "Zone levels " .. OnOff(a) end }
P[#P + 1] = { "^지도 창 꾸미기 (.-) %(/reload 후 적용%)$", function(a) return "Style the map window " .. OnOff(a) .. " (applies after /reload)" end }
P[#P + 1] = { "^(.+) 쪽에 길 안내 핀을 찍었어요$", "Guide pin dropped at %1" }
-- Leel Mark
P[#P + 1] = { "^징을 찍을 수 없어요: (.*)$", "Can't set the mark: %1" }
P[#P + 1] = { "^(.-) 덫$", function(a) return L(a) .. " Trap" end }
P[#P + 1] = { "^(.-) 변이$", function(a) return L(a) .. " Polymorph" end }
P[#P + 1] = { "^(.-) 혼절$", function(a) return L(a) .. " Sap" end }
P[#P + 1] = { "^(%d+)번째로 잡아요$", "Kill #%1" }
P[#P + 1] = { "^(.+) 님 약속$", "%1's plan" }
P[#P + 1] = { "^자동 매크로:\n(.*)$", "Auto macro:\n%1" }
P[#P + 1] = { "^(.+) 님의 징 약속표를 받았어요 %(이름표 순서가 같아져요%)$", "Received %1's mark plan (nameplate order now matches)" }
P[#P + 1] = { "^자동으로 찍을 때 파티 채팅 알림 (.+)$", function(a) return "Party chat notice when auto marking " .. OnOff(a) end }
P[#P + 1] = { "^바 크기 (%d+)%%$", "Bar size %1%%" }
P[#P + 1] = { "^자동: (.+)$", function(a) return "Auto: " .. L(a) end }
P[#P + 1] = { "^점검 켬: 자동을 누르면 만든 매크로를 채팅에 보여 줘요$", "Debug on: auto shows the generated macro in chat" }
P[#P + 1] = { "^점검 끔$", "Debug off" }
-- Leel Spot
P[#P + 1] = { "^크기 ([%d%.]+)$", "Size %1" }
P[#P + 1] = { "^높이 (%-?[%d%.]+)$", "Height %1" }
P[#P + 1] = { "^지금 상호작용 키: (.-)  %(예: /lspot 키 F%)$", function(a) return "Current interact key: " .. L(a) .. "  (e.g. /lspot key F)" end }
P[#P + 1] = { "^(.-) = 상호작용%(줍기%)(.*)$", function(a, b) return a .. " = interact (loot)" .. b:gsub("%(원래: ", "(was: ") end }
P[#P + 1] = { "^선 길이 (%d+) %(선 끔%)$", "Line length %1 (line off)" }
P[#P + 1] = { "^선 길이 (%d+)$", "Line length %1" }
P[#P + 1] = { "^시체 상자 높이 (%-?%d+)$", "Corpse box height %1" }
