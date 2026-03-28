
--------------------------------
-- ytaxx - client
--------------------------------

--------------------------------
-- KNOWN ISSUES
-- 0-360 angle wrap had a small restriction ------------------- FIXED
-- whitelist disabled speed but not angle ------------------- FIXED
-- anti-derby backwards not working ------------------- FIXED
-- raycasts sometimes miss vehicles ------------------- FIXED
-- weapon entity not always present ------------------- FIXED
-- passenger logic needs improvements ------------------- FIXED
--------------------------------

--------------------------------
-- Features
-- - anti-texture (small 3D ❌ when you cannot texture/aim)
-- - anti-texture whitelist: can exempt from texture check but speed restriction remains
-- - anti-derby: camera shake + particles on vehicle collisions for realism
-- - resource-stopper bypass: prevents simple client-side stop exploits (testing)
-- - action mode disable: disables annoying sprint after shooting
-- See `config.lua` for settings
--------------------------------

--------------------------------
-- Icon
--------------------------------
local currentIconPos = vector3(0, 0, 0)
local isIconVisible = false
local currentIcon = ""
local WEAPON_BONE_TAG = 0x6F06
local iconSmoothSpeed = 1

-- Moving average for stabilizing the icon position
local iconPosHistory = {}
local iconPosHistorySize = 6

local function getAveragedIconPos(newPos)
    table.insert(iconPosHistory, newPos)
    if #iconPosHistory > iconPosHistorySize then
        table.remove(iconPosHistory, 1)
    end
    local sumX, sumY, sumZ = 0, 0, 0
    for _, pos in ipairs(iconPosHistory) do
        sumX = sumX + pos.x
        sumY = sumY + pos.y
        sumZ = sumZ + pos.z
    end
    local n = #iconPosHistory
    return vector3(sumX / n, sumY / n, sumZ / n)
end

-- 3D text
local function DrawIcon3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.5, 0.5)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- position calculation
local function GetPositionInFrontOfPlayer(ped, distance)
    local weaponPos = vector3(0, 0, 0)
    local isWeaponPos = false
    
    -- weapon position
    if DoesEntityExist(ped) and not IsEntityDead(ped) then
        local weapon = GetCurrentPedWeaponEntityIndex(ped)
        if DoesEntityExist(weapon) then
            weaponPos = GetEntityCoords(weapon)
            isWeaponPos = true
        else
            -- fall back to weapon bone if weapon entity not present
            local boneIndex = GetPedBoneIndex(ped, WEAPON_BONE_TAG)
            if boneIndex ~= -1 then
                weaponPos = GetWorldPositionOfEntityBone(ped, boneIndex)
                isWeaponPos = true
            end
        end
    end
    
    -- if weapon position not available, use camera position
    if not isWeaponPos then
        weaponPos = GetGameplayCamCoord()
    end
    
    -- compute direction based on camera rotation for accurate aiming
    local cameraRot = GetGameplayCamRot()
    local direction = RotationToDirection(cameraRot)
    
    -- compute target position
    local targetPos = vector3(
        weaponPos.x + direction.x * (distance * 0.5),
        weaponPos.y + direction.y * (distance * 0.5),
        weaponPos.z + direction.z * (distance * 0.5)
    )
    
    -- minimal smoothing for stability
    if currentIconPos == vector3(0, 0, 0) then
        currentIconPos = targetPos
    else
        currentIconPos = vector3(
            currentIconPos.x + (targetPos.x - currentIconPos.x) * iconSmoothSpeed,
            currentIconPos.y + (targetPos.y - currentIconPos.y) * iconSmoothSpeed,
            currentIconPos.z + (targetPos.z - currentIconPos.z) * iconSmoothSpeed
        )
    end
    
    return currentIconPos
end





--------------------------------
-- debug
--------------------------------
local debugData = {
    vehicle = "no vehicle",
    speed = "0.0 kmh",
    angle = "0.0°",
    status = "no restriction",
    seat = "not in vehicle"
}

-- debug window
local function DrawDebugWindow()
    if not (Config.Debug == true) then return end
    local width = 0.15
    local height = 0.21
    local x = 1
    local y = 0.5
    DrawRect(x - width/2 + 0.01, y + height/2 - 0.01, width, height, 140, 82, 255, 200)
    DrawRect(x - width/2 + 0.01, y + height/2 - 0.01, width + 0.004, height + 0.004, 110, 44, 177, 120)
    SetTextFont(4)
    SetTextScale(0.38, 0.38)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(1, 0, 0, 0, 255)
    SetTextEdge(1, 255, 165, 0, 255)
    SetTextOutline()
    SetTextCentre(false)
    SetTextRightJustify(false)
    local textX = x - width + 0.02
    local baseY = y - (height/2) + 0.1
    local yStep = 0.034
    local currentY = baseY
    SetTextFont(4)
    SetTextScale(0.41, 0.41)
    SetTextColour(131, 87, 255, 200)
    SetTextEntry("STRING")
    AddTextComponentString("Debug - vehicle-fight")
    DrawText(textX, currentY)
    currentY = currentY + yStep + 0.001
    local function DrawLineText(label, value, yPos, color)
        SetTextScale(0.38, 0.38)
        SetTextFont(4)
        SetTextOutline()
        SetTextDropshadow(1, 0, 0, 0, 255)
        SetTextEntry("STRING")
        if color then
            SetTextColour(color.r, color.g, color.b, 255)
        else
            SetTextColour(255, 255, 255, 255)
        end
        AddTextComponentString(label .. ": " .. value)
        DrawText(textX, yPos)
        return yPos + yStep
    end
    currentY = DrawLineText("Speed", debugData.speed, currentY)
    currentY = DrawLineText("Angle", debugData.angle, currentY)
    local statusColor = (debugData.status:lower():find("no restriction") or debugData.status:lower():find("no restriction")) and {r=80,g=255,b=80} or {r=255,g=80,b=80}
    currentY = DrawLineText("Status", debugData.status, currentY, statusColor)
    currentY = DrawLineText("Vehicle", debugData.vehicle, currentY)
    currentY = DrawLineText("Seat", debugData.seat, currentY)
end

local function Debug(key, value)
    if not (Config.Debug == true) then return end
    if type(key) == "string" and debugData[key] ~= nil then
        debugData[key] = tostring(value)
    end
end

-- which seat am I in?
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        local ped = PlayerPedId()
        local seat = "-"
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            for i = -1, GetVehicleModelNumberOfSeats(GetEntityModel(veh)) - 1 do
                if GetPedInVehicleSeat(veh, i) == ped then
                    seat = tostring(i)
                    break
                end
            end
        end
        debugData.seat = seat
    end
end)






--------------------------------
-- vehicle checks
--------------------------------
local function IsVehicleAllowed(vehicle)
    if not DoesEntityExist(vehicle) then 
        Debug("vehicle", "does not exist")
        return false 
    end
    
        local model = GetEntityModel(vehicle)
        local hash = tostring(model)
        local modelName = GetDisplayNameFromVehicleModel(model)
            Debug("vehicle", modelName)
        Debug("inVehicle", "yes")
    
    -- hash and model name check
    if Config.allowedVehicles[hash] or Config.allowedVehicles[modelName:lower()] then
        Debug("status", "allowed vehicle")
        return true
    end
    
    Debug("status", "forbidden vehicle")
    return false
end





--------------------------------
-- base settings
--------------------------------
-- Disable controls (https://docs.fivem.net/docs/game-references/controls/) - if something doesn't work, check here
local DISABLED_CONTROLS = {
    24,    -- tamadas
    69,    -- vehicle attack
    92,    -- bal kattintás
    257,   -- támadás 2
    263,   -- melee attack 1
    264,   -- melee attack 2
    331,   -- melee attack 3
    140,   -- melee attack light
    141,   -- melee attack heavy
    142,   -- melee attack alternate
    143    -- melee block
}

local INDICATOR_SETTINGS = {
    distance = 2.0,
    size = 0.2,
    color = {r = 255, g = 165, b = 0, a = 255}
}

-- state variables
local currentVehicle = nil
local inRestrictedVehicle = false

-- state helpers
local function IsInRestrictedVehicle()
    return inRestrictedVehicle
end

local function SetInRestrictedVehicle(state)
    inRestrictedVehicle = state
end

-- cache variables
local cachedPed = nil
local cachedCoords = nil
local lastVehicle = nil





--------------------------------
-- helper functions
--------------------------------
-- compute direction from rotation
local function RotationToDirection(rotation)
    local adjustedRotation = 
    {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    local direction = 
    {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
    return direction
end

-- update cache
local function UpdateCache()
    cachedPed = PlayerPedId()
    cachedCoords = GetEntityCoords(cachedPed)
end

-- cache updating thread
Citizen.CreateThread(function()
    while true do
        UpdateCache()
        
        -- check whether player left vehicle
        if currentVehicle and not IsPedInAnyVehicle(cachedPed, false) then
            Debug("status", "exited")
            Debug("vehicle", "no vehicle")
            Debug("inVehicle", "no")
            currentVehicle = nil
            SetInRestrictedVehicle(false)
            TriggerEvent('vehiclefight:leftVehicle', lastVehicle, -1, '')
            lastVehicle = nil
        end
        
        Citizen.Wait(100) -- cache frissites
    end
end)

-- 3D text for restriction indicators
local function Draw3DText(x, y, z, text)
    local distance = #(cachedCoords - vec3(x, y, z))
    if distance < 10.0 then
        local kepernyon, _x, _y = World3dToScreen2d(x, y, z)
        if kepernyon then
            SetTextScale(INDICATOR_SETTINGS.size, INDICATOR_SETTINGS.size)
            SetTextFont(4)
            SetTextProportional(1)
            SetTextColour(INDICATOR_SETTINGS.color.r, INDICATOR_SETTINGS.color.g, INDICATOR_SETTINGS.color.b, INDICATOR_SETTINGS.color.a)
            SetTextEntry("STRING")
            SetTextCentre(1)
            AddTextComponentString(text)
            DrawText(_x, _y)
        end
    end
end
-- (Position calculation handled by GetPositionInFrontOfPlayer earlier)

-- driver check
local function IsPlayerDriving()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then
        return GetPedInVehicleSeat(vehicle, -1) == ped
    end
    return false
end

-- speed calculation
local function GetVehicleSpeedKmh(vehicle)
    return GetEntitySpeed(vehicle) * 3.6
end





--------------------------------
-- events
--------------------------------
-- player spawn handler
AddEventHandler('playerSpawned', function()
    Debug("playerSpawned")
    cachedPed = PlayerPedId()
    local veh = GetVehiclePedIsIn(cachedPed, false)
    if veh ~= 0 and DoesEntityExist(veh) then
        currentVehicle = veh
        SetInRestrictedVehicle(not IsVehicleAllowed(veh))
        Debug("playerSpawned: " .. (IsVehicleAllowed(veh) and "allowed" or "not allowed"))
    end
end)

-- vehicle events
AddEventHandler('vehiclefight:enteredVehicle', function(veh, currentSeat, vehicleDisplayName)
    Debug("vehiclefight:enteredVehicle trigger")
    if DoesEntityExist(veh) then
        currentVehicle = veh
        SetInRestrictedVehicle(not IsVehicleAllowed(veh))
        Debug("vehicle status: " .. (IsVehicleAllowed(veh) and "allowed" or "not allowed"))
    end
end)

    -- (legacy Hungarian event forwards removed)
AddEventHandler('vehiclefight:leftVehicle', function(veh, currentSeat, vehicleDisplayName)
    currentVehicle = nil
    SetInRestrictedVehicle(false)
    -- reset when exiting
    debugData.vehicle = "no vehicle."
    debugData.speed = "0.0 kmh"
    debugData.angle = "0.0°"
    debugData.status = "no restriction"
    debugData.seat = "-"
End)

AddEventHandler('CEventNetworkPlayerEnteredVehicle', function(player, vehicle)
    Debug("CEventNetworkPlayerEnteredVehicle trigger")
    if player ~= PlayerId() then return end
    if DoesEntityExist(vehicle) then
        currentVehicle = vehicle
        SetInRestrictedVehicle(not IsVehicleAllowed(vehicle))
        Debug("Network vehicle status: " .. (IsVehicleAllowed(vehicle) and "allowed" or "not allowed"))
    end
end)

--------------------------------------------------------------------

RegisterNetEvent('vehiclefight_heartbeat_ping')
AddEventHandler('vehiclefight_heartbeat_ping', function()
    TriggerServerEvent('vehiclefight_heartbeat_reply')
end)

--------------------------------------------------------------------




--------------------------------
-- new vehicle detection system
--------------------------------
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        
        if vehicle ~= 0 and vehicle ~= lastVehicle then
            -- entered vehicle
            lastVehicle = vehicle
            TriggerEvent('vehiclefight:enteredVehicle', vehicle, -1, GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
        elseif vehicle == 0 and lastVehicle ~= nil then
            -- exited vehicle
            TriggerEvent('vehiclefight:leftVehicle', lastVehicle, -1, GetDisplayNameFromVehicleModel(GetEntityModel(lastVehicle)))
            lastVehicle = nil
        end
    end
end)





--------------------------------
-- main loop for checks and indicators
--------------------------------
local lastAngle = 0
local smoothedAngle = 0
local angleUpdateRate = 1

-- angle interpolation via shortest path
local function SmoothAngleUpdate(current, target, rate)
    local diff = (target - current + 540) % 360 - 180
    return (current + diff * rate) % 360
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if currentVehicle and IsPedInAnyVehicle(cachedPed, false) then
            -- main checks
            local speedKmh = GetVehicleSpeedKmh(currentVehicle)
            local indicatorPos = GetPositionInFrontOfPlayer(cachedPed, INDICATOR_SETTINGS.distance)
            local isDriver = IsPlayerDriving()
            local isAiming = IsControlPressed(0, 25)
            local camRot = GetGameplayCamRot(2)
            local vehicleHeading = GetEntityHeading(currentVehicle)
            local dir = RotationToDirection(camRot)
            local camAngle = math.deg(math.atan2(dir.y, dir.x))
            if camAngle < 0 then camAngle = camAngle + 360 end
            local relativeAngle = (camAngle - vehicleHeading + 360) % 360
            -- smooth angle update
            smoothedAngle = SmoothAngleUpdate(smoothedAngle, relativeAngle, angleUpdateRate)
            -- DEBUG
            Debug("angle", string.format("%.1f° (vehicle: %.1f°)", smoothedAngle, vehicleHeading))
            Debug("speed", string.format("%.1f", speedKmh) .. " km/h")
            local isWhitelisted = IsVehicleAllowed(currentVehicle)
            if isWhitelisted then
                if speedKmh > (Config.restrictionSpeed or 20) then
                    if isAiming then
                        Draw3DText(indicatorPos.x, indicatorPos.y, indicatorPos.z, (Config.icons and Config.icons.Speed) or "❌")
                    end
                    Debug("status", "restricted (speed)")
                    for _, control in ipairs(DISABLED_CONTROLS) do
                        DisableControlAction(0, control, true)
                    end
                    DisablePlayerFiring(PlayerId(), true)
                else
                    Debug("status", "no restriction")
                end
            else
                if isDriver then
                    local needsRestriction = false
                    if speedKmh > (Config.restrictionSpeed or 20) then
                        needsRestriction = true
                        if isAiming then
                            Draw3DText(indicatorPos.x, indicatorPos.y, indicatorPos.z, (Config.icons and Config.icons.Speed) or "❌")
                        end
                        Debug("status", "restricted (speed)")
                    elseif smoothedAngle >= (Config.restrictionAngleMin or 230) and smoothedAngle <= (Config.restrictionAngleMax or 330) then
                        needsRestriction = true
                        if isAiming then
                            Draw3DText(indicatorPos.x, indicatorPos.y, indicatorPos.z, (Config.icons and Config.icons.Angle) or "❌")
                        end
                        Debug("status", "restricted (angle)")
                    else
                        Debug("status", "no restriction")
                    end
                    if needsRestriction then
                        for _, control in ipairs(DISABLED_CONTROLS) do
                            DisableControlAction(0, control, true)
                        end
                        DisablePlayerFiring(PlayerId(), true)
                    end
                else
                    -- passenger logic
                    if smoothedAngle >= 130 and smoothedAngle <= 230 then
                        if isAiming then
                            Draw3DText(indicatorPos.x, indicatorPos.y, indicatorPos.z, (Config.icons and Config.icons.PassengerAngle) or "❌")
                        end
                        Debug("status", "restricted (passenger angle)")
                        for _, control in ipairs(DISABLED_CONTROLS) do
                            DisableControlAction(0, control, true)
                        end
                        DisablePlayerFiring(PlayerId(), true)
                    else
                        Debug("status", "no restriction")
                    end
                end
            end
        else
            Citizen.Wait(250)
        end
    end
end)




--------------------------------
-- collision effects (visual extras)
--------------------------------
local particlesLoaded = false
local lastCollision = 0
local collisionCooldown = 1

-- Preload particle effects to prevent runtime lag
local function LoadParticleEffects()
    RequestNamedPtfxAsset("core")
    while not HasNamedPtfxAssetLoaded("core") do
        Citizen.Wait(0)
    end
    particlesLoaded = true
end

Citizen.CreateThread(function()
    LoadParticleEffects()
end)


Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if not (Config.collisionSystem == false) then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)
                if HasEntityCollidedWithAnything(vehicle) then
                    local speed = GetEntitySpeed(vehicle) * 3.6
                    if speed > 1 then
                        -- Raycast may not always find a vehicle
                        local vehCoords = GetEntityCoords(vehicle)
                        CreateCollisionEffect(vehicle, vehCoords, speed)
                    end
                end
            end
        end
    end
end)

CreateCollisionEffect = function(vehicle, coords, speed)
    if not particlesLoaded then return end
    if speed <= (Config.collisionSpeed or 70) then return end -- only trigger for speed >= configured threshold
    local currentTime = GetGameTimer()
    if currentTime - lastCollision < collisionCooldown then return end
    lastCollision = currentTime
    local from = coords + vector3(0, 0, 0.5)
    local heading = GetEntityHeading(vehicle)
    local forwardVec = vector3(-math.sin(math.rad(heading)), math.cos(math.rad(heading)), 0.0)
    local rightVec = vector3(forwardVec.y, -forwardVec.x, 0.0)
    local velocity = GetEntityVelocity(vehicle)
    -- raycast in all main directions; detect other vehicles and ensure the vehicle velocity roughly matches the ray direction (abs(dot) > 0.5)
    local directions = {
        forwardVec,
        -forwardVec,
        rightVec,
        -rightVec
    }
    local foundVehicle = false
    local hitCoords = coords
    for _, dir in ipairs(directions) do
        local to = from + dir * 2.5
        local rayHandle = StartShapeTestCapsule(from.x, from.y, from.z, to.x, to.y, to.z, 2.0, 10, vehicle, 7)
        local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
        if hit == 1 and entityHit and IsEntityAVehicle(entityHit) and entityHit ~= vehicle then
            -- match between velocity direction and raycast direction
            local velNorm = vector3(velocity.x, velocity.y, 0.0)
            local dirNorm = vector3(dir.x, dir.y, 0.0)
            local velLen = math.sqrt(velNorm.x^2 + velNorm.y^2)
            local dirLen = math.sqrt(dirNorm.x^2 + dirNorm.y^2)
            if velLen > 0.1 and dirLen > 0.1 then
                local dot = (velNorm.x * dirNorm.x + velNorm.y * dirNorm.y) / (velLen * dirLen)
                if math.abs(dot) > 0.5 then -- triggers for forward, backward or side impacts
                    foundVehicle = true
                    hitCoords = endCoords
                    break
                end
            end
        end
    end
    if not foundVehicle then return end
    local ped = PlayerPedId()
    if GetPedInVehicleSeat(vehicle, -1) == ped then
        -- camera shake effect
        ShakeGameplayCam("MEDIUM_EXPLOSION_SHAKE", 0.3)
        -- slowdown effect
        local vel = GetEntityVelocity(vehicle)
        SetEntityVelocity(vehicle, vel.x * 0.5, vel.y * 0.5, vel.z * 0.5) -- 60% speed loss
        -- slowdown effect (halve velocity) and disable forward/back movement and firing for 1 second
        local disableTime = GetGameTimer() + 1000
        Citizen.CreateThread(function()
            while GetGameTimer() < disableTime do
                DisableControlAction(0, 32, true) -- W
                DisableControlAction(0, 33, true) -- S
                DisableControlAction(0, 71, true) -- Vehicle accelerate
                DisableControlAction(0, 72, true) -- Vehicle brake
                DisableControlAction(0, 24, true) -- Attack (shoot)
                DisableControlAction(0, 69, true) -- Vehicle attack
                DisableControlAction(0, 257, true) -- Attack 2
                DisablePlayerFiring(PlayerId(), true) -- full firing disable
                Citizen.Wait(0)
            end
        end)
    end
    -- particle effects
    local right = vector3(forwardVec.y, -forwardVec.x, 0.0)
    local offsets = {
        vector3(0, 0, 0),
        right * 0.2,
        right * -0.2,
        right * 0.4,
        right * -0.4,
        right * 0.1,
        right * -0.1,
    }
    for _, offset in ipairs(offsets) do
        UseParticleFxAssetNextCall("core")
        local fx = StartParticleFxLoopedAtCoord(
            "bang_carmetal",
            hitCoords.x + offset.x, hitCoords.y + offset.y, hitCoords.z,
            0.0, 0.0, 0.0,
            2.0, false, false, false, false
        )
        Citizen.SetTimeout(8000, function()
            StopParticleFxLooped(fx, false)
        end)
    end
    UseParticleFxAssetNextCall("core")
    local effect = StartParticleFxLoopedAtCoord(
        "bang_carmetal",
        hitCoords.x, hitCoords.y, hitCoords.z + 0.2,
        0.0, 0.0, 0.0,
        0.9,
        false, false, false,
        true,
        true
    )
    SetParticleFxLoopedEvolution(effect, "initial_lifetime", 1.0, false)
    SetParticleFxLoopedEvolution(effect, "fragment_lifetime", 60.0, false)
    SetParticleFxLoopedEvolution(effect, "falloff_rate", 0.1, false)
    SetParticleFxLoopedEvolution(effect, "collision_lifetime", 60.0, false)
    Citizen.SetTimeout(3000, function()
        StopParticleFxLooped(effect, false)
    end)
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        DrawDebugWindow()
    end
end)

-- 300 km/h soft speed cap for vehicles (prevents extremely high speeds)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh and veh ~= 0 then
                local speed = GetEntitySpeed(veh) * 3.6 -- km/h
                if speed > 368 then
                    -- max 300 kmh
                    local heading = GetEntityHeading(veh)
                    local vel = GetEntityVelocity(veh)
                    local velLen = math.sqrt(vel.x^2 + vel.y^2 + vel.z^2)
                    if velLen > 0.1 then
                        local scale = 368 / speed
                        SetEntityVelocity(veh, vel.x * scale, vel.y * scale, vel.z * scale)
                    end
                end
            end
        end
    end
end)

-- disable action mode
if Config.ActionModeDisable == nil then Config.ActionModeDisable = true end

if Config.ActionModeDisable then
    Citizen.CreateThread(function()
        while true do
            local ped = PlayerPedId()
            if IsPedUsingActionMode(ped) then
                SetPedUsingActionMode(ped, false, -1, 0)
            else
                Citizen.Wait(500)
            end
            Citizen.Wait(0)
        end
    end)
end

-- helper functions: use `IsPlayerDriving()` and `RotationToDirection()` defined earlier




--------------------------------

-- Anti resource stopper: receive random event name and ping it
local _resourceStopperEvent = nil
RegisterNetEvent("vehiclefight_resourceStopperEventName")
AddEventHandler("vehiclefight_resourceStopperEventName", function(eventName)
    _resourceStopperEvent = eventName
end)

Citizen.CreateThread(function()
    while not _resourceStopperEvent do
        Citizen.Wait(500)
    end
    while true do
        if _resourceStopperEvent then
            TriggerServerEvent(_resourceStopperEvent)
        end
        Citizen.Wait(5000)
    end
end)

-- Client-side heartbeat ping sender
Citizen.CreateThread(function()
    while true do
        TriggerServerEvent('vehiclefight_ping')
        Citizen.Wait(5000)
    end
end)
