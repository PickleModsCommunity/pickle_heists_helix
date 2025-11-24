local LocalHeists = {}
local RenderTexts = {}
local blockingInput = false
local CurrentLoot = nil
local CurrentPowerBox = nil

my_webui = WebUI('pickle-heists', 'pickle-heists/html/index.html')

my_webui:RegisterEventHandler('disableInput', function(_, cb)
    my_webui:SetInputMode(0)
    cb(true)
end)

function UpdateInteractTextPosition(id, coords, scale)
    my_webui:SendEvent('updateInteractTextPosition', {
        id = id,
        top = coords.Y,
        left = coords.X,
        scale = scale,
    })
end

function ShowInteractText(id,text)
    my_webui:SendEvent('setInteractText', {
        id = id,
        text = text,
    })
end

function HideInteractText(id)
    my_webui:SendEvent('hideInteractText', {
        id = id,
    })
end

local RenderText = {}
RenderText.__index = RenderText

function RenderText:new(text, worldCoords, scale, maxDistance)
    local self = setmetatable({}, RenderText)
    self.id = math.random(1, 1000000)
    self.text = text
    self.coords = worldCoords
    self.scale = scale or 1.0
    self.maxDistance = maxDistance or 200.0

    self.interval = Lib.SetInterval(function()
        local ped = GetPlayerPawn(HPlayer)
        if not ped then return end
        local playerCoords = GetEntityCoords(ped)
        local screenPos = Vector2D()
        local Controller = HPlayer
        local onScreen = Controller:ProjectWorldLocationToScreen(self.coords, screenPos, false)
        if onScreen then
            local dist = GetDistanceBetweenCoords(playerCoords, self.coords)
            local scale = 1.0 - (dist / self.maxDistance)
            if scale < 0 then scale = 0 end
            if scale > 1 then scale = 1 end
            ShowInteractText(self.id, self.text)
            UpdateInteractTextPosition(self.id, screenPos, scale)
        end
    end, 1)
    return self
end

function RenderText:destroy()
    if self.interval then
        Lib.ClearInterval(self.interval)
        self.interval = nil
    end
    HideInteractText(self.id)
end


Lib.onShutdown(function()
    my_webui:Destroy()
    for i=1, #RenderTexts do
        RenderTexts[i]:destroy()
    end
    RenderTexts = {}
end)

function StopHeistAlarm(heistId)
    if not LocalHeists[heistId] then return end
    for i=1, #LocalHeists[heistId].sirens do
        LocalHeists[heistId].sirens[i].light:K2_DestroyActor()
        Lib.DeleteObject(LocalHeists[heistId].sirens[i].object)
        LocalHeists[heistId].sirens[i] = nil
    end
    LocalHeists[heistId].sirens = {}
end

function StartHeistAlarm(heistId)
    local heist = Heists[heistId]
    if not heist or not LocalHeists[heistId] then return end
    StopHeistAlarm(heistId)
    for i=1, #heist.sirens do
        local siren = heist.sirens[i]
        LocalHeists[heistId].sirens[i] = {
            light = Light(
                Vector(siren.coords.X, siren.coords.Y, siren.coords.Z),
                Rotator(0,0,0),
                LinearColor(0.4, 0.0, 0.0, 1.0),
                LightType.Spot, 5000, 1000, 30, 0.2, 5000, 
                true, true, true
            ),
            object = Lib.CreateObject("/Engine/BasicShapes/Sphere.Sphere", siren.coords, vector3(0, 0, 0))
        }
        local Component = LocalHeists[heistId].sirens[i].object:K2_GetComponentsByClass(UE.UPrimitiveComponent)[1]
        local Material = Component:CreateDynamicMaterialInstance(0, UE.UObject.Load("/Game/Items_HL/Materials/MI_Metal.MI_Metal"), nil)
        LocalHeists[heistId].sirens[i].object:SetMaterial(0, Material)
        LocalHeists[heistId].sirens[i].object:SetActorScale3D(vector3(0.1, 0.1, 0.1))
    end
    local heading = 0.0
    LocalHeists[heistId].sirenInterval = Lib.SetInterval(function()
        for i=1, #heist.sirens do
            local siren = heist.sirens[i]
            heading = heading + 0.1
            if heading > 360 then heading = 0 end
            SetEntityRotation(LocalHeists[heistId].sirens[i].light, Rotator(-30.0, heading, 0.0))
        end
    end, 1)
end

function RegisterHeist(heistId, heist, serverTime)
    Heists[heistId] = heist
    LocalHeists[heistId] = {
        gates = {},
        powerBoxes = {},
        loot = {},
        sirens = {},
        renderTexts = {},
        fenceTrigger = nil,
        interval = nil,
        sirenInterval = nil,
    }
    if heist.alarmActive then
        StartHeistAlarm(heistId)
    end
    if heist.active then
        LocalHeists[heistId].renderTexts = {
            RenderText:new("", GetEntityCoords(heist.getawayVehicle), 1.0, 200.0),
            RenderText:new("", heist.fenceLocation.coords + vector3(0, 0, 100), 1.0, heist.fenceLocation.size.X * 2),
        }
        LocalHeists[heistId].fenceTrigger = Lib.Trigger(heist.fenceLocation.coords, Rotator(0, heist.fenceLocation.heading, 0), heist.fenceLocation.size, TriggerType.Box, true, function(source, inZone, isInteracting)
            if isInteracting then
                TriggerServerEvent('pickle-heists:fenceInteraction', heistId)
            end
        end)
        LocalHeists[heistId].escapeTrigger = Lib.Trigger(
            heist.startLocation.coords, 
            Rotator(0, heist.startLocation.heading, 0), 
            heist.startLocation.areaSize, 
            TriggerType.Box, 
            true, 
            function(source, inZone, isInteracting)
                if not inZone then
                    TriggerServerEvent('pickle-heists:setHeistStage', heistId, "escape")
                end
            end
        )
        if heist.stage and heist.stage == "escape" then
            LocalHeists[heistId].finishTrigger = Lib.Trigger(Heists[heistId].fenceLocation.coords, Rotator(0, LocalHeists[heistId].fenceLocation.heading, 0), Heists[heistId].fenceLocation.areaSize, TriggerType.Box, true, function(source, inZone, isInteracting)
                local heist = Heists[heistId]
                if not inZone then
                    TriggerServerEvent('pickle-heists:setHeistStage', heistId, "finish")
                end
            end)
        end
    else
        LocalHeists[heistId].startTrigger = Lib.Trigger(heist.startLocation.coords, Rotator(0, heist.startLocation.heading, 0), heist.startLocation.size, TriggerType.Box, true, function(source, inZone, isInteracting)
            local heist = Heists[heistId]
            if isInteracting then
                TriggerServerEvent('pickle-heists:startHeistZone', heistId, "start")
            elseif inZone then
                TriggerServerEvent('pickle-heists:startHeistZone', heistId, "enter")
            else
                TriggerServerEvent('pickle-heists:startHeistZone', heistId, "leave")
            end
        end)
        LocalHeists[heistId].renderTexts = {
            RenderText:new("", heist.startLocation.coords, 1.0, heist.startLocation.size.X * 2),
        }
    end
    LocalHeists[heistId].interval = Lib.SetInterval(function()
        local heist = Heists[heistId]
        -- Update the position of the render text for the getaway vehicle.
        if heist.active then
            local renderText = LocalHeists[heistId].renderTexts[1]
            local fenceRenderText = LocalHeists[heistId].renderTexts[2]
            local getawayVehicle = heist.getawayVehicle
            if not getawayVehicle then
                return
            end
            local origin, boxExtent = getawayVehicle:GetActorBounds(true, nil, nil, true)
            local fwd = getawayVehicle:GetActorForwardVector()
            local target = GetEntityCoords(getawayVehicle) + fwd * (-boxExtent.Y)
            if CurrentLoot then
                renderText.text = "PRESS [E] TO STORE LOOT (".. #heist.storedLoot .." / ".. heist.maxLoot ..")"
                fenceRenderText.text = "PRESS [E] TO SELL LOOT"
            else
                renderText.text = "PRESS [E] TO RETRIEVE LOOT (".. #heist.storedLoot .." / ".. heist.maxLoot ..")"
                fenceRenderText.text = "EQUIP LOOT TO SELL HERE"
            end
            renderText.coords = vector3(target.X, target.Y, target.Z + boxExtent.Z)
        else
            if LocalHeists[heistId].timeLeft then
                local startLocationRenderText = LocalHeists[heistId].renderTexts[1]
                startLocationRenderText.text = "COOLDOWN: ".. LocalHeists[heistId].timeLeft .." seconds"
            else
                local startLocationRenderText = LocalHeists[heistId].renderTexts[1]
                startLocationRenderText.text = (#heist.players >= heist.minPlayers and "PRESS [E] TO START HEIST" or "WAITING FOR PLAYERS") .. " (".. #heist.players .." / ".. heist.maxPlayers ..")"
            end
        end
    end, 1)
    if serverTime and serverTime < heist.nextStart then
        LocalHeists[heistId].timeLeft = heist.nextStart - serverTime
        LocalHeists[heistId].cooldownInterval = Lib.SetInterval(function()
            local heist = Heists[heistId]
            local localHeist = LocalHeists[heistId]
            if localHeist.timeLeft > 0 then
                localHeist.timeLeft = localHeist.timeLeft - 1
            else
                Lib.ClearInterval(localHeist.cooldownInterval)
                localHeist.cooldownInterval = nil
                localHeist.timeLeft = nil
            end
        end, 1000)
    end
end

function FinishHeist(heistId)
    if not LocalHeists[heistId] then return end
    for i=1, #LocalHeists[heistId].renderTexts do
        LocalHeists[heistId].renderTexts[i]:destroy()
    end
    LocalHeists[heistId].renderTexts = {}
    for i=1, #LocalHeists[heistId].sirens do
        LocalHeists[heistId].sirens[i].light:K2_DestroyActor()
        Lib.DeleteObject(LocalHeists[heistId].sirens[i].object)
        LocalHeists[heistId].sirens[i] = nil
    end
    if LocalHeists[heistId].escapeTrigger then
        Lib.DeleteTrigger(LocalHeists[heistId].escapeTrigger)
        LocalHeists[heistId].escapeTrigger = nil
    end
    if LocalHeists[heistId].finishTrigger then
        Lib.DeleteTrigger(LocalHeists[heistId].finishTrigger)
        LocalHeists[heistId].finishTrigger = nil
    end
    if LocalHeists[heistId].fenceTrigger then
        Lib.DeleteTrigger(LocalHeists[heistId].fenceTrigger)
        LocalHeists[heistId].fenceTrigger = nil
    end
    if LocalHeists[heistId].startTrigger then
        Lib.DeleteTrigger(LocalHeists[heistId].startTrigger)
        LocalHeists[heistId].startTrigger = nil
    end
    Lib.ClearInterval(LocalHeists[heistId].interval)
    LocalHeists[heistId].interval = nil
    Lib.ClearInterval(LocalHeists[heistId].sirenInterval)
    LocalHeists[heistId].sirenInterval = nil
    LocalHeists[heistId] = nil
end

Lib.onShutdown(function()
    for heistId, heist in pairs(LocalHeists) do
        StopHeistAlarm(heistId)
    end
    LocalHeists = {}
end)

if Config.Debug then
    Timer.SetTimeout(function()
        local pcoords = GetEntityCoords(GetPlayerPawn(HPlayer))
        print(pcoords)
    end, 1000)
end


RegisterClientEvent('pickle-heists:syncHeists', function(heists, serverTime)
    Heists = heists
    for heistId, heist in pairs(Heists) do
        if heist.getawayVehicle then
            heist.getawayVehicle = heist.getawayVehicle.Object
        end
        RegisterHeist(heistId, heist, serverTime)
    end
end)

RegisterClientEvent('pickle-heists:initializeHeist', function(heistId, heist, serverTime)
    if not Heists[heistId] then return end
    Heists[heistId] = heist
    if heist.getawayVehicle then
        heist.getawayVehicle = heist.getawayVehicle.Object
    end
    RegisterHeist(heistId, heist, serverTime)
end)

RegisterClientEvent('pickle-heists:updateHeistVehicle', function(heistId, vehicle)
    if not Heists[heistId] then return end
    if vehicle and vehicle.Object then
        print("Updating heist vehicle", heistId, vehicle.Object)
        Heists[heistId].getawayVehicle = vehicle.Object
        if LocalHeists[heistId] and LocalHeists[heistId].requestVehicleInterval then
            Lib.ClearInterval(LocalHeists[heistId].requestVehicleInterval)
            LocalHeists[heistId].requestVehicleInterval = nil
        end
    end
end)

RegisterClientEvent('pickle-heists:setHeistStage', function(heistId, stage)
    local heist = Heists[heistId]
    if not heist or not heist.active then return end
    if not LocalHeists[heistId] then return end
    if LocalHeists[heistId].escapeTrigger then
        Lib.DeleteTrigger(LocalHeists[heistId].escapeTrigger)
        LocalHeists[heistId].escapeTrigger = nil
    end
    LocalHeists[heistId].finishTrigger = Lib.Trigger(heist.fenceLocation.coords, Rotator(0, heist.fenceLocation.heading, 0), heist.fenceLocation.areaSize, TriggerType.Box, true, function(source, inZone, isInteracting)
        local heist = Heists[heistId]
        if not inZone then
            TriggerServerEvent('pickle-heists:setHeistStage', heistId, "finish")
        end
    end)
end)

if Config.Debug then
    Timer.SetTimeout(function()
        TriggerServerEvent('pickle-heists:playerJoined')
    end, 1000)
end


RegisterClientEvent('pickle-heists:setCarryingLoot', function(heistId, lootIndex)
    if not heistId or not lootIndex then 
        CurrentLoot = nil
        return
    end
    CurrentLoot = {
        heistId = heistId,
        lootIndex = lootIndex,
    }
end)

RegisterClientEvent('pickle-heists:updateHeistLoot', function(heistId, storedLoot)
    Heists[heistId].storedLoot = storedLoot
end)

RegisterClientEvent('pickle-heists:powerboxInteraction', function(heistId, powerBoxIndex)
    CurrentPowerBox = {
        heistId = heistId,
        powerBoxIndex = powerBoxIndex,
    }
    my_webui:SetInputMode(1)
    my_webui:SendEvent('startGame', {
        reward = 1, -- The amount of money to reward.
        wireCount = 1, -- The amount of wires to fix.
        wireWidth = 500 * 0.01, -- The width of each wire.
        time = 60, -- The time to fix all wires.
        maxWeldFails = 3 -- The maximum amount of fails until completely failing.
    })
end)

RegisterClientEvent('pickle-heists:updateHeistAlarm', function(heistId, alarmActive)
    if not LocalHeists[heistId] then return end
    LocalHeists[heistId].alarmActive = alarmActive 
    if alarmActive then
        StartHeistAlarm(heistId)
    else
        StopHeistAlarm(heistId)
    end
end)

RegisterClientEvent('pickle-heists:updateHeistPlayers', function(heistId, players)
    if not Heists[heistId] then return end
    Heists[heistId].players = players
end)

RegisterClientEvent("pickle-heists:startHeist", function(heistId, heist)
    if not Heists[heistId] then return end
    Heists[heistId] = heist
    if heist.getawayVehicle then
        heist.getawayVehicle = heist.getawayVehicle.Object
    end
    if not LocalHeists[heistId] then
        RegisterHeist(heistId, heist)
    else
        if not LocalHeists[heistId].fenceTrigger then
            LocalHeists[heistId].fenceTrigger = Lib.Trigger(heist.fenceLocation.coords, Rotator(0, heist.fenceLocation.heading, 0), heist.fenceLocation.size, TriggerType.Box, true, function(source, inZone, isInteracting)
                if isInteracting then
                    TriggerServerEvent('pickle-heists:fenceInteraction', heistId)
                end
            end)
        end
        if not LocalHeists[heistId].escapeTrigger then
            LocalHeists[heistId].escapeTrigger = Lib.Trigger(heist.startLocation.coords, Rotator(0, heist.startLocation.heading, 0), heist.startLocation.areaSize, TriggerType.Box, true, function(source, inZone, isInteracting)
                if not inZone then
                    TriggerServerEvent('pickle-heists:setHeistStage', heistId, "escape")
                end
            end)
        end
        if LocalHeists[heistId].startTrigger and LocalHeists[heistId].startTrigger:IsValid() then
            Lib.DeleteTrigger(LocalHeists[heistId].startTrigger)
            LocalHeists[heistId].startTrigger = nil
        end
        if heist.alarmActive then
            StartHeistAlarm(heistId)
        end
        for i=1, #LocalHeists[heistId].renderTexts do
            LocalHeists[heistId].renderTexts[i]:destroy()
        end
        LocalHeists[heistId].renderTexts = {
            RenderText:new("", heist.getawayVehicle and GetEntityCoords(heist.getawayVehicle) or vector3(0, 0, 0), 1.0, 200.0),
            RenderText:new("", heist.fenceLocation.coords + vector3(0, 0, 100), 1.0, heist.fenceLocation.size.X * 2),
        }
    end
    if not heist.getawayVehicle then
        print("No getaway vehicle found, requesting from server")
        LocalHeists[heistId].requestVehicleInterval = Lib.SetInterval(function()
            -- I blame you for this
            TriggerServerEvent('pickle-heists:requestHeistVehicle', heistId)
        end, 1000)
    else
        print("Getaway vehicle found, updating render texts")
    end
end)

RegisterClientEvent("pickle-heists:finishHeist", function(heistId, heist)
    if not Heists[heistId] then return end
    Heists[heistId] = heist
    FinishHeist(heistId)
end)

my_webui:RegisterEventHandler('endGame', function(data)
    if data.success and CurrentPowerBox then
        TriggerServerEvent('pickle-heists:powerboxInteraction', CurrentPowerBox.heistId, CurrentPowerBox.powerBoxIndex)
    elseif not data.success then
        TriggerServerEvent('pickle-heists:startHeistAlarm', CurrentPowerBox.heistId)
    end
    my_webui:SetInputMode(0)
    CurrentPowerBox = nil
end)


Input.BindKey('E', function() 
    if not CurrentLoot then 
        local targetHeistId = nil
        local pcoords = GetEntityCoords(GetPlayerPawn(HPlayer))
        local dist = 1000000.0
        for heistId, heist in pairs(Heists) do
            if heist.active and heist.getawayVehicle then
                local getawayVehicle = heist.getawayVehicle
                local d = GetDistanceBetweenCoords(pcoords, GetEntityCoords(getawayVehicle))
                if d < dist then
                    dist = d
                    targetHeistId = heistId
                end
            end
        end
        if targetHeistId and dist < 600.0 then
            local heist = Heists[targetHeistId]
            local getawayVehicle = heist.getawayVehicle
            if not getawayVehicle then
                return
            end
            local origin, boxExtent = getawayVehicle:GetActorBounds(true, nil, nil, true)
            local fwd = getawayVehicle:GetActorForwardVector()
            local target = GetEntityCoords(getawayVehicle) + fwd * (-boxExtent.Y)
            if GetDistanceBetweenCoords(pcoords, target) < 200.0 then
                TriggerServerEvent('pickle-heists:withdrawLootFromVehicle', targetHeistId)
            end
        end
    else
        TriggerServerEvent('pickle-heists:lootInteraction', CurrentLoot.heistId, CurrentLoot.lootIndex)
    end
end, 'Pressed')

Input.BindKey('F', function() 
    if not CurrentLoot then 
        return
    end
    TriggerServerEvent('pickle-heists:lootInteraction', CurrentLoot.heistId, CurrentLoot.lootIndex)
end, 'Pressed')