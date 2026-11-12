-- 멀리 있는 물건 토끼 기능은 빼기로 했어요.
-- 예전에 찍어 둔 토끼 길 표시가 남아 있으면 한 번 지워요.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if LeelSpotDB and LeelSpotDB.ghostLeft then
        if C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
        LeelSpotDB.ghostLeft = nil
    end
    if LeelSpotDB then LeelSpotDB.ghost = nil end
end)
