-- LeelUI / Locale_en.lua
-- 영어 번역 (1단계: 모던 모드 · 액션바 · 메뉴 줄 · 위쪽 대상 바 · 스킨 · 단축키 · UI 모드)
-- 키 = 코드 속 한국어 그대로 · 값 = 영어

local _, ns = ...
local E, P, F = ns.EN, ns.EN_PAT, ns.EN_FRAG

-- 언어 고르기
E["Language / 언어"] = "Language / 언어"
E["자동 / Auto"] = "Auto"
E["게임 언어를 따라가요 · 바꾸면 다시 불러오기"] = "Follows your game language · /reload after changing"

-- 메뉴 이름
E["캐릭터"] = "Character"; E["전문 기술"] = "Professions"; E["주문책"] = "Spellbook"; E["주문·특성"] = "Spells & Talents"
E["특성"] = "Talents"; E["업적"] = "Achievements"; E["퀘스트 일지"] = "Quest Log"; E["길드"] = "Guild"; E["친구"] = "Friends"
E["파티 찾기"] = "Group Finder"; E["탈것·펫"] = "Collections"; E["던전 안내"] = "Dungeon Journal"; E["지도"] = "Map"
E["상점"] = "Shop"; E["게임 메뉴"] = "Game Menu"; E["도움말"] = "Help"; E["가방"] = "Bags"; E["르엘 허브"] = "Leel Hub"
E["더보기"] = "More"; E["덜 쓰는 메뉴"] = "Less-used menus"; E["르엘 메뉴"] = "Leel Menu"
E["누르면 메뉴가 펼쳐져요"] = "Click to open the menu"; E["자리 · 크기는 이동 모드에서"] = "Move & resize in Move Mode"
E["오른쪽 클릭 = 위 줄에 꺼내 두기 · 줄에서 오른쪽 클릭 = 여기로"] = "Right-click = pin to the row · right-click on the row = back here"
E["오른쪽 클릭: 위 줄에 늘 보이게"] = "Right-click: always show on the row"
E["오른쪽 클릭: 더보기 판으로 넣기"] = "Right-click: move into More"
E["전투가 끝나면 바꿀 수 있어요."] = "You can change this after combat."

-- 이동 모드 이름
E["메뉴 줄"] = "Menu Row"; E["액션바"] = "Action Bar"; E["토끼 메뉴"] = "Bunny Menu"; E["대상 줄"] = "Target Bar"
E["메뉴 줄 크기"] = "Menu row size"; E["액션바 크기"] = "Action bar size"; E["토끼 메뉴 크기"] = "Bunny menu size"; E["대상 줄 크기"] = "Target bar size"

-- 액션바
E["변신"] = "Forms"; E["페이지"] = "Page"; E["고정"] = "Fixed"; E["이전 페이지"] = "Previous page"; E["다음 페이지"] = "Next page"
E["왼쪽 10칸만 바뀌어요 · 오른쪽은 그대로"] = "Only the left 10 slots change · the right stays"
E["허브에서 Z · X 키로 넘기게 할 수 있어요"] = "You can page with Z · X (set in the Hub)"
E["경험치 %d%% · 휴식 +%d%%"] = "XP %d%% · Rested +%d%%"
E["경험치 %d%%"] = "XP %d%%"
E["르엘 액션바는 준비 중이에요. 다음 업데이트에서 열려요."] = "Leel action bars are coming in a later update."
E["켰어요. /reload 하면 적용돼요."] = "Turned on. /reload to apply."
E["껐어요. /reload 하면 원래 바로 돌아가요."] = "Turned off. /reload to restore the default bars."
E["액션바·토끼 메뉴 자리를 처음대로."] = "Action bar & bunny menu positions reset."
E["켬"] = "on"; E["끔"] = "off"
E["전투가 끝나면 바뀌어요."] = "Will change after combat."

-- 나 · 펫 · 원
E["왼쪽 클릭 = 나를 대상 · 오른쪽 클릭 = 내 메뉴"] = "Left-click = target me · Right-click = my menu"
E["내 생명력"] = "My health"; E["펫"] = "Pet"
E["왼쪽 클릭 = 펫 기술 펼치기 · 접기"] = "Left-click = open / close pet skills"
E["오른쪽 클릭 = 펫 대상"] = "Right-click = target pet"
E["레벨 · 경험치"] = "Level · XP"; E["직업 자원"] = "Class resource"; E["진영 문장"] = "Faction crest"
E["마나"] = "Mana"; E["분노"] = "Rage"; E["집중"] = "Focus"; E["기력"] = "Energy"; E["연계 점수"] = "Combo points"; E["자원"] = "Resource"
E["왼쪽 클릭 = 보기 바꾸기 (레벨 → 자원 → 진영)"] = "Left-click = switch view (Level → Resource → Faction)"
E["오른쪽 클릭 = 빠른 설정"] = "Right-click = quick settings"
E["아래 숫자 = 오늘 명예 처치"] = "Number below = honorable kills today"

-- 빠른 설정 카드
E["빠른 설정"] = "Quick Settings"; E["버프 크기"] = "Buff size"; E["디버프 크기"] = "Debuff size"
E["HP · MP 줄 두께"] = "HP · MP bar height"; E["전투 효과 (혜성)"] = "Combat effect (comet)"; E["오른쪽 쪽 탭"] = "Right-side page tabs"
E["원 보기"] = "Ring view"; E["레벨"] = "Level"; E["진영"] = "Faction"; E["더 많은 설정 → 르엘 허브"] = "More settings → Leel Hub"

-- 버프 줄
E["이 게임 버전엔 애드온용 오라 칸이 없어서 버프 줄을 못 띄워요."] = "This game version has no addon aura frames, so the buff row can't be shown."

-- 오른쪽 쪽
E["왼쪽 아래 바 + 오른쪽 아래 바"] = "Bottom-left bar + bottom-right bar"
E["오른쪽 바 1 + 오른쪽 바 2"] = "Right bar 1 + right bar 2"
E["바 5 + 바 6"] = "Bar 5 + bar 6"

-- 위쪽 대상 바
E["정예"] = "Elite"; E["우두머리"] = "Boss"; E["희귀 정예"] = "Rare Elite"; E["희귀"] = "Rare"
E["못 끊음"] = "Can't interrupt"; E["끊을 수 있음"] = "Interruptible"
E["대상의 대상"] = "Target of target"; E["같이 치는 파티원"] = "Party on this target"
E["어그로 %d%%"] = "Threat %d%%"; E["어그로 나!"] = "Aggro: me!"; E["어그로 높음"] = "High threat"; E["어그로 낮음"] = "Low threat"
E["대상 예시"] = "Sample target"

-- 스킨
E["각진 전술형"] = "Angular Tactical"; E["로아풍 강철"] = "Black Steel"; E["실사 금테"] = "Gold Frame"; E["실사 쇠테"] = "Iron Frame"; E["분홍 (예전)"] = "Pink (classic)"
E["스킨을 바꿨어요. |cfff2b3c2/reload|r (허브 아래 '다시 불러오기') 하면 액션바가 바뀌어요."] = "Skin changed. |cfff2b3c2/reload|r (or 'Reload' at the bottom of the Hub) to update the action bars."
E["전투가 끝나면 스킨이 바뀌어요."] = "The skin will change after combat."
E["지금 입은 스킨이 내 스킨이 아니에요."] = "The current skin isn't one of your own."
E["공유 글이 아니에요. !LeelSkin: 으로 시작하는 글을 붙여 넣어 주세요."] = "That's not a share code. Paste text that starts with !LeelSkin:"
E["스킨을 끄고 입히기 전 모습으로 돌렸어요."] = "Skins off — restored the look from before."
E["/르엘스킨 원래대로 · /르엘스킨 공유 · /르엘스킨 !LeelSkin:...! (받기)"] = "/leelskin off · /leelskin share · /leelskin !LeelSkin:...! (import)"

-- 단축키 정하기
E["키를 누르면 바뀌어요 · Delete = 지우기 · Esc = 끝"] = "Press a key to bind · Delete = clear · Esc = done"
E["단축키 정하기"] = "Keybind Mode"
E["단추 위에 마우스를 올리고 키를 누르세요 · Shift/Ctrl/Alt · 휠 · 마우스 3~5번도 돼요\nDelete = 지우기 · Esc = 끝"] = "Hover a button and press a key · Shift/Ctrl/Alt · wheel · mouse 3–5 work too\nDelete = clear · Esc = done"
E["완료"] = "Done"
E["전투가 시작돼서 단축키 정하기를 끝냈어요."] = "Combat started — keybind mode closed."
E["단축키를 저장했어요."] = "Keybinds saved."
E["전투가 끝나고 해 주세요."] = "Please do this after combat."
E["모던 액션바를 켜고 다시 불러오기 한 뒤에 쓸 수 있어요."] = "Turn on the Modern action bars and /reload first."
E["단축키 정하기: 단추 위에 마우스를 올리고 키를 누르세요. Esc = 끝"] = "Keybind Mode: hover a button and press a key. Esc = done"

-- UI 모드 (허브)
E["UI 모드"] = "UI Mode"; E["기본 · 모던"] = "Classic · Modern"
E["화면 전체 모습을 한 번에 바꿔요. 부분마다 따로 골라 섞을 수도 있어요 (섞으면 '사용자 지정').\n액션바 · 미니맵을 바꾸면 다시 불러오기가 필요해요."] = "Change the whole screen at once. You can also mix parts ('Custom').\nChanging the action bars or minimap needs a /reload."
E["고르면 아래가 한꺼번에 바뀌어요"] = "Picking one changes everything below"
E["기본"] = "Classic"; E["모던"] = "Modern"; E["사용자 지정"] = "Custom"
E["기본 = 게임 기본 액션바 + 둥근 미니맵 (지금까지 쓰던 르엘UI).\n모던 = 각진 액션바 · 위쪽 대상 바 · 네모 미니맵 · 투명 메뉴 줄 · 버프 / 디버프 줄.\n사용자 지정 = 아래에서 부분마다 따로 고른 상태."] = "Classic = default action bars + round minimap (the original LeelUI).\nModern = angular action bars · top target bar · square minimap · clear menu row · buff / debuff rows.\nCustom = parts picked separately below."
E["부분마다 고르기"] = "Pick each part"; E["다시 불러오기 후 적용"] = "Applies after /reload"; E["게임 기본"] = "Game default"
E["모던 = 가운데 레벨 링 + 양옆 생명력 · 마나 줄 + 날개 단추."] = "Modern = center level ring + health · mana bars on both sides + winged slots."
E["대상 표시"] = "Target display"; E["HUD 초상화"] = "HUD portrait"; E["위쪽 대상 바"] = "Top target bar"
E["위쪽 대상 바 = 화면 위 가운데 긴 줄 (어그로 · 대상의 대상 · 사거리 · 내 디버프)."] = "Top target bar = a long bar at the top center (threat · target of target · range · my debuffs)."
E["미니맵"] = "Minimap"; E["블리자드"] = "Blizzard"; E["동그라미"] = "Round"; E["네모"] = "Square"
E["메뉴"] = "Menu"; E["토끼 버튼"] = "Bunny button"; E["투명 메뉴 줄"] = "Clear menu row"
E["투명 메뉴 줄 = 자주 쓰는 것만 늘 보이고 나머지는 [더보기]."] = "Clear menu row = frequent menus always shown, the rest under [More]."
E["파티 창"] = "Party frames"; E["힐러 타일"] = "Healer tiles"; E["모던 (로아식)"] = "Modern"
E["모던 = 왼쪽 각진 직업 문장 + 이름 위 + 번호 칸 · 직업 색 체력 줄 · 해제할 디버프는 테 색으로. 세로 줄로 놓여요."] = "Modern = angular class crest on the left + name above + number tab · class-colored health · dispellable debuffs color the border. Stacked vertically."
E["버프 · 디버프"] = "Buffs · Debuffs"; E["생명력 · 마나 위"] = "Above health · mana"
E["생명력 줄 위 = 내 버프 (무기 강화 포함) · 마나 줄 위 = 내 디버프."] = "Above health = my buffs (incl. weapon enchants) · above mana = my debuffs."
E["액션바 단축키 정하기 (단추에 마우스 올리고 키 누르기)"] = "Set action bar keybinds (hover a button, press a key)"
E["모던 기본 자리로 돌리기 (액션바 · 대상 바 · 메뉴 줄 · 파티 창 · 미니맵)"] = "Reset to Modern default layout (bars · target bar · menu row · party · minimap)"
E["모던 기본 자리로 돌렸어요."] = "Reset to the Modern default layout."
E["모던 기본 자리로 맞췄어요 (미니맵 왼쪽 위 · 메뉴 줄 오른쪽 위 · 파티 창 왼쪽)."] = "Applied the Modern default layout (minimap top-left · menu row top-right · party left)."
E["파티 창을 모던(로아식)으로 바꿨어요. 다시 불러오기 하면 보여요."] = "Party frames switched to Modern. /reload to see them."
E["액션바가 모던일 때"] = "When the action bars are Modern"
E["모던으로 바꿨어요."] = "Switched to Modern."; E["기본으로 바꿨어요."] = "Switched to Classic."

-- 패턴 (이름 · 숫자가 섞인 문장)
P[#P + 1] = { "^'(.+)' 스킨으로 저장했어요%.$", "Saved as skin '%1'." }
P[#P + 1] = { "^스킨 이름을 '(.+)'%(으%)로 바꿨어요%.$", "Renamed the skin to '%1'." }
P[#P + 1] = { "^'(.+)' 스킨을 지웠어요%.$", "Deleted skin '%1'." }
P[#P + 1] = { "^'(.+)'을 받았어요%. 허브 '입은 스킨'에서 골라 입혀 보세요%.$", "Received '%1'. Pick it under 'Current skin' in the Hub." }
P[#P + 1] = { "^내 스킨 (%d+)$", "My skin %1" }
P[#P + 1] = { "^받은 스킨 (%d+)$", "Imported skin %1" }
P[#P + 1] = { "^모양: (.+)%. /reload 하면 적용돼요%.$", "Style: %1. /reload to apply." }
P[#P + 1] = { "^페이지 넘기기 Z · X: (.+)$", "Page with Z · X: %1" }
P[#P + 1] = { "^버프 줄을 만들지 못했어요: (.*)$", "Couldn't create the buff row: %1" }
P[#P + 1] = { "^자리 맞추기 실패: (.*)$", "Couldn't apply the layout: %1" }
P[#P + 1] = { "^단축키: (.*)$", "Keybind: %1" }
P[#P + 1] = { "^스킨 쓰기: (.-) · 입은 스킨: (.*)$", "Skins: %1 · current: %2" }

-- 조각 (긴 문장 속에서만 바꿔요)
F[" · 치유 가능"] = " · healable"; F[" · 사거리 안"] = " · in range"; F[" · 사거리 밖"] = " · out of range"
F[" (나!)"] = " (me!)"; F[" (내 스킨)"] = " (mine)"; F["가운데 원 · "] = "Center ring · "
F["레벨 · 경험치"] = "Level · XP"; F["직업 자원"] = "Class resource"; F["진영 문장"] = "Faction crest"
F[" 쪽"] = " page"; F["없음"] = "none"; F["따라가는 중"] = "Following"
