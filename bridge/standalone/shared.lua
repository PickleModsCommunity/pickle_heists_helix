if Config.Framework ~= "standalone" then return end

function GetIdentifier(Player)
    if not Player and HPlayer then Player = HPlayer end
    return Player:GetLyraPlayerState():GetHelixUserId()
end