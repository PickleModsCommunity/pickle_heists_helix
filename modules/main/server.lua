local Heists = {}
local JoinedPlayers = {}
local CarryingPlayers = {}

function PowerboxInteraction(heistId, powerBoxIndex)
    local heist = Heists[heistId]
    local powerBox = heist.powerBoxes[powerBoxIndex]
    if powerBox.cooldown then
        return
    end
    powerBox.cooldown = true
    Timer.SetTimeout(function()
        powerBox.cooldown = false
    end, 2500)
    if powerBox.interactable and powerBox.interactable:IsValid() then
        powerBox.interactable:K2_DestroyActor()
    end
    if powerBox.triggerAlarm then
        StartHeistAlarm(heistId)
    end
    for i=1, #powerBox.targetGates do
        local v = heist.gates[powerBox.targetGates[i]]
        if not v.open then
            v.open = true
            Lib.transformActorLerp(v.object, 2.0, {
                position = {
                    start = v.coords + vector3(0, 0, v.open and 0 or Config.Default.gateTransitionHeight),
                    finish = v.coords + vector3(0, 0, v.open and Config.Default.gateTransitionHeight or 0),
                },
                scale = {
                    start = v.open and Config.Default.gateScale or vector3(Config.Default.gateScale.X, Config.Default.gateScale.Y, 0.0),
                    finish = v.open and vector3(Config.Default.gateScale.X, Config.Default.gateScale.Y, 0.0) or Config.Default.gateScale,
                },
            })
        end
    end
end

function LootInteraction(source, heistId, lootIndex)
    local heist = Heists[heistId]
    local loot = heist.loot[lootIndex]
    if loot.attachment then 
        local identifier = GetIdentifier(source)
        if identifier == loot.attachment.identifier then
            local ped = GetPlayerPawn(source)
            loot.isPickedUp = nil
            loot.coords = GetEntityCoords(ped)
            loot.heading = GetEntityHeading(ped)
            Lib.DeleteObject(loot.object)
            local getawayVehicle = heist.getawayVehicle
            local origin, boxExtent = getawayVehicle:GetActorBounds(true, nil, nil, true)
            local fwd = getawayVehicle:GetActorForwardVector()
            local target = GetEntityCoords(getawayVehicle) + fwd * (-boxExtent.Y)
            if GetDistanceBetweenCoords(loot.coords, target) < 200.0 then
                loot.object = nil
                loot.index = lootIndex
                table.insert(heist.storedLoot, loot)
                loot.attachment = {
                    identifier = "vehicle",
                }
                if #heist.storedLoot == heist.maxLoot then
                    ShowNotification(source, "You have collected all the loot - escape to the fence location to sell it!")
                end
                BroadcastEvent("pickle-heists:updateHeistLoot", heistId, heist.storedLoot)
            else
                loot.object = Lib.CreateObject(Config.Loot[loot.type].model, loot.coords - vector3(0, 0, 100.0), vector3(0, loot.heading, 0))
                local InteractableActor = Interactable({
                    {
                        Text = 'Pickup Loot',
                        Input = '/Game/Helix/Input/Actions/IA_Interact.IA_Interact',
                        Action = function(CubeActor, Instigator)
                            local Controller = Instigator and Instigator:GetController()
                            LootInteraction(Controller, heistId, lootIndex)
                        end,
                    }
                })
                InteractableActor:SetInteractableProp(loot.object)
                loot.interactable = InteractableActor
                loot.attachment = nil
            end
            CarryingPlayers[GetIdentifier(source)] = nil
            BroadcastEvent("pickle-heists:updateLoot", heistId, lootIndex, loot)
        end
        TriggerClientEvent(source, "pickle-heists:setCarryingLoot", nil, nil)
        return
    end
    if CarryingPlayers[GetIdentifier(source)] then return end
    if loot.interactable and loot.interactable:IsValid() then
        loot.interactable:K2_DestroyActor()
    end
    Lib.AttachEntityToCharacter(loot.object, GetPlayerPawn(source), 'hand_r', vector3(0, 0, 0), vector3(0, 0, 0), {
        scale = vector3(1.0, 1.0, 1.0),
    })
    loot.isPickedUp = GetIdentifier(source)
    loot.attachment = {
        identifier = GetIdentifier(source),
    }
    CarryingPlayers[GetIdentifier(source)] = {
        index = lootIndex,
    }
    BroadcastEvent("pickle-heists:updateLoot", heistId, lootIndex, loot)
    TriggerClientEvent(source, "pickle-heists:setCarryingLoot", heistId, lootIndex)
end

function FenceInteraction(source, heistId, lootIndex)
    local heist = Heists[heistId]
    local loot = heist.loot[lootIndex]
    if not loot or not loot.attachment or loot.attachment.identifier ~= GetIdentifier(source) then 
        return
    end
    loot.attachment = {
        identifier = "world",
    }
    Lib.DeleteObject(loot.object)
    if loot.rewarded then return end
    if Config.Loot[loot.type].rewardType == "cash" then
        local lootReward = math.random(loot.amount.min, loot.amount.max)
        AddMoney(source, lootReward)
        ShowNotification(source, "You have sold the loot for $" .. lootReward .. "!")
    else
        ShowNotification(source, "There is no reward for this loot type (" .. loot.type .. ")!")
    end
    loot.coords = GetEntityCoords(GetPlayerPawn(source))
    loot.heading = GetEntityHeading(GetPlayerPawn(source))
    loot.rewarded = true
    loot.object = Lib.CreateObject(Config.Loot[loot.type].model, loot.coords - vector3(0, 0, 100.0), vector3(0, loot.heading, 0))
    BroadcastEvent("pickle-heists:updateLoot", heistId, lootIndex, loot)
end

function StartHeistAlarm(heistId)
    local heist = Heists[heistId]
    local heistCfg = Config.Heists[heist.index]
    if not heist or heist.alarmActive then return end
    heist.alarmActive = true
    local policePlayers = GetPolicePlayers()
    for i=1, #policePlayers do
        ShowNotification(policePlayers[i], "There is a bank robbery in progress at " .. heistCfg.label .. "!")
    end
    BroadcastEvent("pickle-heists:updateHeistAlarm", heistId, heist.alarmActive)
end

RegisterServerEvent('pickle-heists:playerJoined', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return end
    if JoinedPlayers[identifier] then
        return
    end
    JoinedPlayers[identifier] = true
    Timer.SetTimeout(function()
        TriggerClientEvent(source, "pickle-heists:syncHeists", Heists, os.time())
    end, 1000)
end)

RegisterServerEvent('pickle-heists:withdrawLootFromVehicle', function(source, heistId)
    local heist = Heists[heistId]
    local loot = heist.storedLoot[1]
    if not loot then return end
    local loot = heist.loot[loot.index]
    table.remove(heist.storedLoot, 1)
    loot.object = Lib.CreateObject(Config.Loot[loot.type].model, loot.coords - vector3(0, 0, 100000.0), vector3(0, loot.heading, 0))
    local tempInteractable = Interactable({
        {
            Text = 'Pickup Loot',
            Input = '/Game/Helix/Input/Actions/IA_Interact.IA_Interact',
            Action = function(CubeActor, Instigator)
                LootInteraction(Instigator:GetController(), heistId, loot.index)
            end,
        }
    })
    tempInteractable:SetInteractableProp(loot.object)
    Timer.SetTimeout(function()
        if tempInteractable and tempInteractable:IsValid() then
            tempInteractable:K2_DestroyActor()
        end
        Lib.AttachEntityToCharacter(loot.object, GetPlayerPawn(source), 'hand_r', vector3(0, 0, 0), vector3(0, 0, 0), {
            scale = vector3(1.0, 1.0, 1.0),
        })
    end, 100)
    loot.isPickedUp = GetIdentifier(source)
    loot.attachment = {
        identifier = GetIdentifier(source),
    }
    CarryingPlayers[GetIdentifier(source)] = {
        index = loot.index,
    }
    BroadcastEvent("pickle-heists:updateLoot", heistId, loot.index, loot)
    TriggerClientEvent(source, "pickle-heists:setCarryingLoot", heistId, loot.index)
    BroadcastEvent("pickle-heists:updateHeistLoot", heistId, heist.storedLoot)
end)

-- RegisterServerEvent('pickle-heists:powerboxInteraction', function(source, heistId, powerBoxIndex)

-- end)

RegisterServerEvent('pickle-heists:lootInteraction', function(source, heistId, lootIndex)
    LootInteraction(source, heistId, lootIndex)
end)

RegisterServerEvent('pickle-heists:powerboxInteraction', function(source, heistId, powerBoxIndex)
    ShowNotification(source, "The power box has been successfully disabled!")
    PowerboxInteraction(heistId, powerBoxIndex)
end)

RegisterServerEvent('pickle-heists:startHeistAlarm', function(source, heistId)
    StartHeistAlarm(heistId)
end)

RegisterServerEvent('pickle-heists:requestHeistVehicle', function(source, heistId)
    if not Heists[heistId] then return end
    TriggerClientEvent(source, "pickle-heists:updateHeistVehicle", heistId, Heists[heistId].getawayVehicle)
end)

RegisterServerEvent('pickle-heists:startHeistZone', function(source, heistId, zone)
    local heist = Heists[heistId]
    local heistCfg = Config.Heists[heist.index]
    if not heist or heist.active then return end
    if zone == "enter" then
        for i=1, #heist.players do
            if heist.players[i] == source then
                return
            end
        end
        table.insert(heist.players, source)
    elseif zone == "leave" then
        for i=1, #heist.players do
            if heist.players[i] == source then
                table.remove(heist.players, i)
            end
        end
    elseif zone == "start" then
        if #heist.players >= heist.minPlayers then
            if os.time() < heist.nextStart then
                return
            end
            if not ProcessRequirements(source, heistCfg.required) then return end
            StartHeist(heistId)
        end
    end
    BroadcastEvent("pickle-heists:updateHeistPlayers", heistId, heist.players)
end)

RegisterServerEvent('pickle-heists:setHeistStage', function(source, heistId, stage)
    local heist = Heists[heistId]
    if not heist then return end
    if stage == "escape" and not heist.stage then
        heist.stage = "escape"
        for i=1, #heist.players do
            ShowNotification(heist.players[i], "You have escaped the area - go to the fence location to sell the loot!")
            TriggerClientEvent(heist.players[i], "pickle-heists:setHeistStage", heistId, "escape")
        end
    elseif stage == "finish" and heist.stage == "escape" then
        heist.stage = "finish"
        for i=1, #heist.players do
            ShowNotification(heist.players[i], "You have completed the heist - enjoy your loot!")
        end
        FinishHeist(heistId)
    end
end)

RegisterServerEvent('pickle-heists:fenceInteraction', function(source, heistId)
    local identifier = GetIdentifier(source)
    if not identifier or not CarryingPlayers[identifier] then return end
    FenceInteraction(source, heistId, CarryingPlayers[identifier].index)
end)

function StartHeist(heistId)
    local heist = Heists[heistId]
    if not heist or heist.active then return end
    local heistCfg = Config.Heists[heist.index]
    heist.active = true
    heist.getawayVehicle = Lib.CreateVehicle(heistCfg.getawayVehicle.model, heistCfg.getawayVehicle.coords, vector3(0, heistCfg.getawayVehicle.heading, 0))
    if not heist.getawayVehicle or not heist.getawayVehicle:IsValid() then
        print("[ERROR] Failed to create getaway vehicle")
        return FinishHeist(heistId)
    end
    -- Lib.DeleteTrigger(heist.startTrigger)
    heist.startTrigger = nil
    for i=1, #heistCfg.loot do
        local loot = heistCfg.loot[i]
        local object = Lib.CreateObject(Config.Loot[loot.type].model, loot.coords, vector3(0, loot.heading, 0))
        local InteractableActor = Interactable({
            {
                Text = 'Pickup Loot',
                Input = '/Game/Helix/Input/Actions/IA_Interact.IA_Interact',
                Action = function(CubeActor, Instigator)
                    local Controller = Instigator and Instigator:GetController()
                    LootInteraction(Controller, heistId, i)
                end,
            }
        })
        InteractableActor:SetInteractableProp(object)
        table.insert(heist.loot, {
            object = object,
            interactable = InteractableActor,
            type = loot.type,
            amount = loot.amount,
            coords = loot.coords,
            heading = loot.heading,
        })
    end
    for i=1, #heist.powerBoxes do
        local InteractableActor = Interactable({
            {
                Text = 'Open Gate',
                SubText = 'Press F to open the gate',
                Input = '/Game/Helix/Input/Actions/IA_Interact.IA_Interact',
                Action = function(CubeActor, Instigator)
                    -- PowerboxInteraction(heistId, i)
                    TriggerClientEvent(Instigator:GetController(), "pickle-heists:powerboxInteraction", heistId, i)
                end,
            }
        })
        InteractableActor:SetInteractableProp(heist.powerBoxes[i].object)
        heist.powerBoxes[i].interactable = InteractableActor
    end
    heist.fenceLocation = heistCfg.fenceLocation
    heist.sirens = heistCfg.sirens
    for i=1, #heist.players do
        ShowNotification(heist.players[i], "The heist has started - get into the vault and carry the loot into the getaway vehicle!")
    end
    -- local debugHeist = {}
    -- for k,v in pairs(heist) do
    --     if k ~= "getawayVehicle" then
    --         debugHeist[k] = v
    --     end
    -- end
    BroadcastEvent("pickle-heists:startHeist", heistId, heist)
end

function FinishHeist(heistId)
    local heist = Heists[heistId]
    heist.active = false
    for i=1, #heist.loot do
        if heist.loot[i].interactable and heist.loot[i].interactable:IsValid() then
            heist.loot[i].interactable:K2_DestroyActor()
        end
        if heist.loot[i].object and heist.loot[i].object:IsValid() then
            Lib.DeleteObject(heist.loot[i].object)
        end
    end
    for k,v in pairs(heist.gates) do
        if v.object and v.object:IsValid() then
            Lib.DeleteObject(v.object)
        end
    end
    for i=1, #heist.powerBoxes do
        if heist.powerBoxes[i].object and heist.powerBoxes[i].object:IsValid() then
            Lib.DeleteObject(heist.powerBoxes[i].object)
        end
        if heist.powerBoxes[i].interactable and heist.powerBoxes[i].interactable:IsValid() then
            heist.powerBoxes[i].interactable:K2_DestroyActor()
        end
    end
    heist.storedLoot = {}
    heist.players = {}
    BroadcastEvent("pickle-heists:finishHeist", heistId, heist)
    Timer.SetTimeout(function()
        InitializeHeist(heistId, heist.index)
    end, 1000)
end

function ProcessRequirements(source, requirements)
    for _, requirement in pairs(requirements) do
        if requirement.type == "item" then
            if GetItemCount(source, requirement.name) < requirement.amount then 
                ShowNotification(source, "You don't have the required item: " .. requirement.name .. " (" .. requirement.amount .. ")")
                return false
            end
        end
    end
    for _, requirement in pairs(requirements) do
        if requirement.type == "item" and requirement.remove then
            RemoveItem(source, requirement.name, requirement.amount)
        end
    end
    return true
end

function InitializeHeist(heistId, index, skipSync)
    local heistCfg = Config.Heists[index]
    local heist = {
        index = index,
        players = {},
        minPlayers = heistCfg.minPlayers,
        maxPlayers = heistCfg.maxPlayers,
        active = false,
        alarmActive = false,
        gates = {},
        powerBoxes = {},
        loot = {},
        storedLoot = {},
        maxLoot = #heistCfg.loot,
        startLocation = heistCfg.startLocation,
        fenceLocation = heistCfg.fenceLocation,
        startTrigger = nil,
        initialized = os.time(),
        nextStart = os.time() + (heistCfg.cooldown * 60),
    }
    for gateName, gate in pairs(heistCfg.gates) do
        local object = Lib.CreateObject(Config.Default.gateModel, gate.coords, vector3(0, gate.heading, 0))
        local Component = object:K2_GetComponentsByClass(UE.UPrimitiveComponent)[1]
        local Material = Component:CreateDynamicMaterialInstance(0, UE.UObject.Load(Config.Default.gateMaterial), nil)
        object:SetMaterial(0, Material)
        object:SetActorScale3D(gate.scale)
        heist.gates[gateName] = {
            coords = gate.coords,
            heading = gate.heading,
            object = object,
            open = false,
        }
    end
    for i=1, #heistCfg.powerBoxes do
        local powerBox = heistCfg.powerBoxes[i]
        local object = Lib.CreateObject(Config.Default.powerBoxModel, powerBox.coords, vector3(0, powerBox.heading, 0))
        table.insert(heist.powerBoxes, {
            targetGates = powerBox.targetGates,
            object = object,
            coords = powerBox.coords,
            heading = powerBox.heading,
            interactable = nil,
            triggerAlarm = powerBox.triggerAlarm,
        })
    end
    Heists[heistId] = heist
    if not skipSync then
        BroadcastEvent("pickle-heists:initializeHeist", heistId, heist, os.time())
    end
end

Timer.SetTimeout(function()
    for i=1, #Config.Heists do
        local heistId
        repeat
            heistId = math.random(1, 100000)
        until not Heists[heistId]
        InitializeHeist(heistId, i, true)
        -- Timer.SetTimeout(function()
        --     StartHeist(heistId)
        -- end, 1000)
    end
end, 100)

Lib.onShutdown(function()
    for k,v in pairs(Heists) do
        for i=1, #v.powerBoxes do
            if v.powerBoxes[i].interactable and v.powerBoxes[i].interactable:IsValid() then
                v.powerBoxes[i].interactable:K2_DestroyActor()
            end
        end
        for i=1, #v.loot do
            if v.loot[i].interactable and v.loot[i].interactable:IsValid() then
                v.loot[i].interactable:K2_DestroyActor()
            end
        end
    end
end)

-- local open = false

-- local timer = Timer.CreateThread(function()
--     Timer.Wait(1000)
--     open = not open
--     for netId, netObject in pairs(GetNetworkedObjects()) do
--         if netObject.model == Config.Default.gateModel then
--             local netObject = GetNetworkObject(netId)
--             netObject.transformActorLerp(2.0, {
--                 position = {
--                     start = netObject.position + vector3(0, 0, open and 0 or Config.Default.gateTransitionHeight),
--                     finish = netObject.position + vector3(0, 0, open and Config.Default.gateTransitionHeight or 0),
--                 },
--                 scale = {
--                     start = open and Config.Default.gateScale or vector3(Config.Default.gateScale.X, Config.Default.gateScale.Y, 0.0),
--                     finish = open and vector3(Config.Default.gateScale.X, Config.Default.gateScale.Y, 0.0) or Config.Default.gateScale,
--                 },
--             })
--         end
--     end
-- end)