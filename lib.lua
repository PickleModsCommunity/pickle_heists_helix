local _print = print
local DEBUG_MODE = Config.Debug or false
function print(...)
    _print("[".. _G.__PackageName .."][".. (HPlayer and "client" or "server") .. "]: ", ...)
end

Lib = {}
Lib.Intervals = {}
Lib.ShutdownFunctions = {}
Lib.Objects = {}
Lib.Vehicles = {}
Lib.RaycastThreads = {}
Lib.Triggers = {}
Lib.SetInterval = function(func, ms)
    local inputTimer = Timer.SetInterval(func, ms)
    Lib.Intervals[inputTimer] = true
    return inputTimer
end
Lib.ClearInterval = function(thread)
    Timer.ClearInterval(thread)
    Lib.Intervals[thread] = nil
end
Lib.CreateThread = function(func)
    -- Timer.CreateThread(func)
    -- use xpcall to catch errors
    local success, error = xpcall(func, function(err)
        print("Error in thread: " .. err)
    end)
    if not success then
        print(success, error)
    end
end
Lib.Wait = function(ms)
    Timer.Wait(ms)
end
Lib.ClearThread = function(thread)
    ClearThread(thread)
end
Lib.startShutdown = function()
    for k, v in pairs(Lib.ShutdownFunctions) do
        v()
    end
    Lib.ShutdownFunctions = {}
end
Lib.onShutdown = function(func)
    table.insert(Lib.ShutdownFunctions, func)
end
Lib.print = function(...)
    print(...)
end
Lib.CreateObject = function(model, position, rotation)
    local object = StaticMesh(
        Vector(position.X, position.Y, position.Z),
        Rotator(rotation.X, rotation.Y, rotation.Z),
        model,
        CollisionType.StaticOnly,
        false
    )
    if not HPlayer then 
        object:GetComponentByClass(UE.UStaticMeshComponent):SetIsReplicated(true)
    end
    -- object:K2_GetRootComponent():SetMobility(UE.EComponentMobility.Movable)
    Lib.Objects[object] = true
    return object
end
Lib.CreateVehicle = function(model, position, rotation)
    local coords = UE.FVector(position.X, position.Y, position.Z)
    local rot = UE.FRotator(rotation.X, rotation.Y, rotation.Z)
    local vehicle = HVehicle(coords, rot, model, "QueryAndPhysics", true)
    vehicle:SetFuel(100.0)
    Lib.Vehicles[vehicle] = true
    return vehicle
end
Lib.DeleteVehicle = function(vehicle)
    DeleteEntity(vehicle)
    Lib.Vehicles[vehicle] = nil
end
Lib.AttachEntityToCharacter = function(object, character, boneName, coords, rotation, args)
    args = args or {}
    args.scale = args.scale or vector3(1.0, 1.0, 1.0)
    args.collision = args.collision or CollisionType.NoCollision
    local mesh = character:GetCharacterBaseMesh()
    local objectComponent = object:K2_GetRootComponent()
    objectComponent:SetCollisionEnabled(CollisionType.NoCollision)
    objectComponent:SetMobility(UE.EComponentMobility.Movable)
    objectComponent:K2_AttachToComponent(mesh, boneName or 'hand_r', UE.EAttachmentRule.KeepRelative, UE.EAttachmentRule.KeepRelative, UE.EAttachmentRule.KeepRelative, true)
    object:K2_SetActorRelativeLocation(Vector(coords.X, coords.Y, coords.Z), false, nil, true)
    object:K2_SetActorRelativeRotation(Rotator(rotation.X, rotation.Y, rotation.Z), false, nil, true)
    object:SetActorScale3D(Vector(args.scale.X, args.scale.Y, args.scale.Z))
    return object
end
Lib.AttachEntityToEntity = function(object, entity, boneName, coords, rotation, args)
    args = args or {}
    args.scale = args.scale or vector3(1.0, 1.0, 1.0)
    args.collision = args.collision or CollisionType.NoCollision
    local entityComponent = entity:K2_GetRootComponent()
    local objectComponent = object:K2_GetRootComponent()
    objectComponent:SetCollisionEnabled(CollisionType.NoCollision)
    objectComponent:SetMobility(UE.EComponentMobility.Movable)
    objectComponent:K2_AttachToComponent(entityComponent, boneName or 'root', UE.EAttachmentRule.KeepRelative, UE.EAttachmentRule.KeepRelative, UE.EAttachmentRule.KeepRelative, true)
    object:K2_SetActorRelativeLocation(Vector(coords.X, coords.Y, coords.Z), false, nil, true)
    object:K2_SetActorRelativeRotation(Rotator(rotation.X, rotation.Y, rotation.Z), false, nil, true)
    object:SetActorScale3D(Vector(args.scale.X, args.scale.Y, args.scale.Z))
end
Lib.DetachEntity = function(object, args)
    args = args or {}
    args.physics = args.physics or false
    args.collision = args.collision or CollisionType.StaticOnly
    local objectComponent = object:K2_GetRootComponent()
    object:K2_DetachFromActor(UE.EDetachmentRule.KeepWorld, UE.EDetachmentRule.KeepWorld, UE.EDetachmentRule.KeepWorld)
    objectComponent:SetCollisionEnabled(args.collision)
end
Lib.DeleteObject = function(object)
    DeleteEntity(object)
    Lib.Objects[object] = nil
end
Lib.Raycast = function(settings, cb)
    if not HPlayer then return print("ERROR: You can't call Lib.Raycast from the server!") end
    return Timer.SetInterval(function()
        local w, h = HPlayer:GetViewportSize()
        local sp = UE.FVector2D(w * 0.5, h * 0.5)
    
        local pos, dir = UE.FVector(), UE.FVector()
        if not UE.UGameplayStatics.DeprojectScreenToWorld(HPlayer, sp, pos, dir) then return end
    
        local start = pos + dir * 25.0
        local stop  = start + dir * (settings.maxDistance or 5000.0)
        local hit = Trace:LineSingle(start, stop, UE.ETraceTypeQuery.Visibility, UE.EDrawDebugTrace.None)
        if hit then
            cb(hit)
        end
    end, settings.interval or 1000)
end
Lib.ClearRaycast = function(thread)
    Timer.ClearInterval(thread)
    Lib.RaycastThreads[thread] = nil
end
Lib.CopyTextToClipboard = function(text)
    my_webui:SetInputMode(1)
    my_webui:SendEvent('CopyTextToClipboard', text)
end
Lib.IsActorPlayer = function(actor)
    local label = UE.UKismetSystemLibrary.GetDisplayName(actor)
    return label:find("Character_Player") ~= nil
end
Lib.Trigger = function(coords, rotation, size, type, isPersistent, callback, color)
    if not HPlayer then return print("ERROR: You can't call Lib.Trigger from the server!") end
    local trig
    trig = Trigger(coords, rotation, size, type, isPersistent, function(self, character)
        if not character or not Lib.IsActorPlayer(character) then return end
        local source = character:GetController()
        Lib.Triggers[trig].inZone = true
        callback(source, Lib.Triggers[trig].inZone)
    end, color)
    Lib.Triggers[trig] = {inZone = false, callback = callback}
    local Shapes = trig:K2_GetComponentsByClass(UE.UShapeComponent)
    if Shapes[1] then
        Shapes[1].OnComponentEndOverlap:Add(HWorld, function(_, _, character)
            if not character or not Lib.IsActorPlayer(character) then return end
            local source = character:GetController()
            Lib.Triggers[trig].inZone = false
            callback(source, Lib.Triggers[trig].inZone)
        end)
    end
    return trig, function()
        return Lib.Triggers[trig].inZone
    end
end
Lib.DeleteTrigger = function(trig)
    trig:K2_DestroyActor()
    Lib.Triggers[trig] = nil
end
Lib.ExecuteZoneInteractions = function()
    for k, v in pairs(Lib.Triggers) do
        if v.inZone then
            v.callback(HPlayer, true, true)
        end
    end
end
Lib.transformActorLerp = function(object, duration, settings)
    Lib.CreateThread(function()
        local startLocation = settings.position.start
        local endLocation = settings.position.finish
        local startScale = settings.scale.start
        local endScale = settings.scale.finish
        SetEntityCoords(object, startLocation)
        object:SetActorScale3D(startScale)
        local alpha = 0.0
        local lerpDuration = duration * 10 -- Seconds
        local timerId
        timerId = Lib.SetInterval(function()
            local DeltaTime = UE.UGameplayStatics.GetWorldDeltaSeconds(object)
                -- Calculate the new alpha value
            alpha = alpha + DeltaTime / lerpDuration
            
            -- Clamp alpha between 0 and 1 to prevent overshooting
            alpha = math.min(1.0, alpha)
        
            -- -- Calculate the new location using Lerp
            local newLocation = UE.UKismetMathLibrary.VLerp(startLocation, endLocation, alpha)
            -- -- Set the actor's new location
            SetEntityCoords(object, newLocation)
            local newScale = UE.UKismetMathLibrary.VLerp(startScale, endScale, alpha)
            object:SetActorScale3D(Vector(newScale.X, newScale.Y, newScale.Z))
            if alpha >= 1 then
                Lib.ClearInterval(timerId)
                return
            end
        end, 1)
    end)
end
Lib.SetEntityMassScale = function(object, massScale)
    -- Needed to be implemented
end

function onShutdown()
    Lib.startShutdown()
    for k, v in pairs(Lib.Intervals) do
        Lib.ClearInterval(k)
    end
    Lib.Intervals = {}
    for k, v in pairs(Lib.Objects) do
        Lib.DeleteObject(k)
    end
    Lib.Objects = {}
    for k, v in pairs(Lib.RaycastThreads) do
        Lib.ClearRaycast(k)
    end
    Lib.RaycastThreads = {}
    for k, v in pairs(Lib.Triggers) do
        Lib.DeleteTrigger(k)
    end
    Lib.Triggers = {}
    for k, v in pairs(Lib.Vehicles) do
        Lib.DeleteVehicle(k)
    end
    Lib.Vehicles = {}
end

Input.BindKey('E', function() 
    if not HPlayer then return end
    Lib.ExecuteZoneInteractions()
end, 'Pressed')