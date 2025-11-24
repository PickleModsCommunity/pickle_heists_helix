if Config.Framework ~= "qb" then return end

print("QB Core bridge server loaded")

local AddedItems = {}

function GetIdentifier(source)
	local Player = exports['qb-core']:GetPlayer(source)
    if not AddedItems[source] and Config.Debug then
        AddedItems[source] = true
        for i=1, #Config.Default.required do
            exports['qb-inventory']:AddItem(source, Config.Default.required[i].name, Config.Default.required[i].amount)
        end
    end
	if not Player then return end
    return Player.PlayerData.citizenid
end

function AddMoney(source, amount)
    exports['qb-core']:Player(source, 'AddMoney', 'cash', amount)
end

function GetItemCount(source, name)
    local amount = exports['qb-inventory']:GetItemCount(source, name) or 0
    return amount
end

function RemoveItem(source, name, amount)
    local Player = exports['qb-core']:GetPlayer(source)
    if not Player then return end
    return exports['qb-inventory']:RemoveItem(source, name, amount)
end

function GetPolicePlayers()
    local tbl = {}
    local players = exports['qb-core']:GetPlayers()
    for _, player in pairs(players) do
        local Player = exports['qb-core']:GetPlayer(player)
        if Player and Player.PlayerData.job.type == 'leo' then
            tbl[#tbl + 1] = player
        end
    end
    return tbl
end

function ShowNotification(source, message)
    TriggerClientEvent(source, 'QBCore:Notify', message)
end