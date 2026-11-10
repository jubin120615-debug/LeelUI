-- LeelUI / Config.lua
-- 예전 "상세 설정" 창은 르엘 허브로 합쳤어요. /leel 도 허브를 열어요.

local _, ns = ...

function ns:ToggleConfig()
    if ns.ToggleHub then ns:ToggleHub("LeelUI") end
end

function ns:RefreshConfig()
    if ns.RefreshHub then ns:RefreshHub() end
end
