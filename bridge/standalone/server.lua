if Config.Framework ~= "standalone" then return end

function AddMoney(source, amount)
    -- No need to add money, standalone framework doesn't have money
end

function GetItemCount(source, name)
    return 10000 -- Pass any item check.
end

function RemoveItem(source, name, amount)
    return true
end

function GetPolicePlayers()
    return {}
end

function ShowNotification(source, message)
    print(source, message)
end