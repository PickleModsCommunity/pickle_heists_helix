if Config.Framework ~= "qb" then return end

print("QB Core bridge client loaded")

function ShowNotification(message)
    exports['qb-core']:Notify(message)
end

RegisterClientEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('pickle-heists:playerJoined')
end)