local QBCore = exports['qb-core']:GetCoreObject()
local isLoggedIn = LocalPlayer.state['isLoggedIn']
local zones = {}
local currentArea = 0
local inSellerZone = false
local lightOn = false
local currentDivingLocation = {
    area = 0,
    blip = {
        radius = nil,
        label = nil
    }
}
local currentGear = {
    mask = 0,
    tank = 0,
    oxygen = 0,
    enabled = false
}

-- Functions

local function createCoral(coords) -- Create coral prop in Box Zone for qb-target interction
    local propModel = "prop_coral_pillar_01"
    RequestModel(propModel) while not HasModelLoaded(propModel) do Wait(0) end
    local prop = CreateObject(propModel, coords.x, coords.y, coords.z - 1.5, false)
    FreezeEntityPosition(prop, true)
    SetEntityInvincible(prop, true)
    SetModelAsNoLongerNeeded(propModel)
end

local function callCops()
    local call = math.random(1, 3)
    local chance = math.random(1, 3)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    if call == chance then
        TriggerServerEvent('qb-diving:server:CallCops', coords)
    end
end

local function deleteGear()
	if currentGear.mask ~= 0 then
        DetachEntity(currentGear.mask, 0, 1)
        DeleteEntity(currentGear.mask)
		currentGear.mask = 0
    end

	if currentGear.tank ~= 0 then
        DetachEntity(currentGear.tank, 0, 1)
        DeleteEntity(currentGear.tank)
		currentGear.tank = 0
	end

    currentGear.oxygen = 0
end

local function gearAnim()
    RequestAnimDict("clothingshirt")
    while not HasAnimDictLoaded("clothingshirt") do
        Wait(0)
    end
	TaskPlayAnim(PlayerPedId(), "clothingshirt", "try_shirt_positive_d", 8.0, 1.0, -1, 49, 0, 0, 0, 0)
end

local function takeCoral(coral)
    if Config.CoralLocations[currentDivingLocation.area].coords.Coral[coral].PickedUp then return end

    local ped = PlayerPedId()
    local times = math.random(2, 5)
    if math.random() > Config.CopsChance then callCops() end
    FreezeEntityPosition(ped, true)
    QBCore.Functions.Progressbar("take_coral", Lang:t("info.collecting_coral"), times * 1000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = "weapons@first_person@aim_rng@generic@projectile@thermal_charge@",
        anim = "plant_floor",
        flags = 16,
    }, {}, {}, function() -- Done
        Config.CoralLocations[currentDivingLocation.area].coords.Coral[coral].PickedUp = true
        TriggerServerEvent('qb-diving:server:TakeCoral', currentDivingLocation.area, coral, true)
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
    end, function() -- Cancel
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
    end)
end

local function setDivingLocation(divingLocation)
    if currentDivingLocation.area ~= 0 then
        for k in pairs(Config.CoralLocations[currentDivingLocation.area].coords.Coral) do
            if Config.UseTarget then
                exports['qb-target']:RemoveZone(k)
            else
                if next(zones) then zones[k]:destroy() end
            end
        end
    end
    currentDivingLocation.area = divingLocation
    for _, blip in pairs(currentDivingLocation.blip) do if blip then RemoveBlip(blip) end end
    local radiusBlip = AddBlipForRadius(Config.CoralLocations[currentDivingLocation.area].coords.Area, 100.0)
    SetBlipRotation(radiusBlip, 0)
    SetBlipColour(radiusBlip, 47)
    currentDivingLocation.blip.radius = radiusBlip
    local labelBlip = AddBlipForCoord(Config.CoralLocations[currentDivingLocation.area].coords.Area)
    SetBlipSprite(labelBlip, 597)
    SetBlipDisplay(labelBlip, 4)
    SetBlipScale(labelBlip, 0.7)
    SetBlipColour(labelBlip, 0)
    SetBlipAsShortRange(labelBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Lang:t("info.diving_area"))
    EndTextCommandSetBlipName(labelBlip)
    currentDivingLocation.blip.label = labelBlip
    for k, v in pairs(Config.CoralLocations[currentDivingLocation.area].coords.Coral) do
        if Config.UseTarget then
            exports['qb-target']:AddBoxZone('diving_coral_zone_'..k, v.coords, v.length, v.width, {
                name = 'diving_coral_zone_'..k,
                heading = v.heading,
                debugPoly = Config.Debug,
                minZ = v.coords.z - 3,
                maxZ = v.coords.z + 2
            }, {
                options = {
                    {
                        label = Lang:t("info.collect_coral"),
                        icon = 'fa-solid fa-water',
                        action = function()
                            takeCoral(k)
                        end,
                        canInteract = function()
                            return not v.PickedUp
                        end,
                    }
                },
                distance = 2.0
            })
            createCoral(v.coords)
        else
            zones[k] = BoxZone:Create(v.coords, v.length, v.width, {
                name = 'diving_coral_zone_'..k,
                heading = v.heading,
                debugPoly = Config.Debug,
                minZ = v.coords.z - 3,
                maxZ = v.coords.z + 2
            })
            zones[k]:onPlayerInOut(function(inside)
                if inside then
                    currentArea = k
                    exports['qb-core']:DrawText(Lang:t("info.collect_coral_dt"))
                else
                    currentArea = 0
                    exports['qb-core']:HideText()
                end
            end)
        end
    end
end

local function sellCoral()
    local playerPed = PlayerPedId()
    LocalPlayer.state:set("inv_busy", true, true)
    TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_STAND_IMPATIENT", 0, true)
    QBCore.Functions.Progressbar("sell_coral_items", Lang:t("info.checking_pockets"), math.random(2000, 4000), false, true, {}, {}, {}, {}, function() -- Done
        ClearPedTasks(playerPed)
        TriggerServerEvent('qb-diving:server:SellCoral')
        LocalPlayer.state:set("inv_busy", false, true)
    end, function() -- Cancel
        ClearPedTasksImmediately(playerPed)
        QBCore.Functions.Notify(Lang:t("error.canceled"), "error")
        LocalPlayer.state:set("inv_busy", false, true)
    end)
end

local function createSeller()
    for i = 1, #Config.SellLocations do
        local current = Config.SellLocations[i]
        current.model = type(current.model) == 'string' and GetHashKey(current.model) or current.model
        RequestModel(current.model)
        while not HasModelLoaded(current.model) do
            Wait(0)
        end
        local currentCoords = vector4(current.coords.x, current.coords.y, current.coords.z - 1, current.coords.w)
        local ped = CreatePed(0, current.model, currentCoords, false, false)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        if Config.UseTarget then
            exports['qb-target']:AddTargetEntity(ped, {
                options = {
                    {
                        label = Lang:t("info.sell_coral"),
                        icon = 'fa-solid fa-dollar-sign',
                        action = function()
                            sellCoral()
                        end
                    }
                },
                distance = 2.0
            })
        else
            local zone = BoxZone:Create(current.coords.xyz, current.zoneOptions.length, current.zoneOptions.width, {
                name = 'diving_coral_seller_'..i,
                heading = current.coords.w,
                debugPoly = Config.Debug,
                minZ = current.coords.z - 1.5,
                maxZ = current.coords.z + 1.5
            })
            zone:onPlayerInOut(function(inside)
                if inside then
                    inSellerZone = true
                    exports['qb-core']:DrawText(Lang:t("info.sell_coral_dt"))
                else
                    inSellerZone = false
                    exports['qb-core']:HideText()
                end
            end)
        end
    end
end

RegisterKeyMapping('toggleLight', 'Toggle Scuba Flashlight', 'keyboard', 'F')

RegisterCommand('toggleLight', function()
    local ped = PlayerPedId()
    if currentGear.enabled then
        if lightOn then
            SetEnableScubaGearLight(ped, false)
            lightOn = false
        else
            SetEnableScubaGearLight(ped, true)
            lightOn = true
        end
    end
end)

-- Events

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    QBCore.Functions.TriggerCallback('qb-diving:server:GetDivingConfig', function(config, area)
        Config.CoralLocations = config
        setDivingLocation(area)
        createSeller()
        isLoggedIn = true
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
end)

RegisterNetEvent('qb-diving:client:NewLocations', function()
    QBCore.Functions.TriggerCallback('qb-diving:server:GetDivingConfig', function(config, area)
        Config.CoralLocations = config
        setDivingLocation(area)
    end)
end)

RegisterNetEvent('qb-diving:client:UpdateCoral', function(area, coral, bool)
    Config.CoralLocations[area].coords.Coral[coral].PickedUp = bool
end)

RegisterNetEvent('qb-diving:client:CallCops', function(coords, msg)
    PlaySound(-1, "Lose_1st", "GTAO_FM_Events_Soundset", 0, 0, 1)
    TriggerEvent("chatMessage", Lang:t("error.911_chatmessage"), "error", msg)
    local transG = 100
    local blip = AddBlipForRadius(coords.x, coords.y, coords.z, 100.0)
    SetBlipSprite(blip, 9)
    SetBlipColour(blip, 1)
    SetBlipAlpha(blip, transG)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Lang:t("info.blip_text"))
    EndTextCommandSetBlipName(blip)
    while transG ~= 0 do
        Wait(180 * 4)
        transG = transG - 1
        SetBlipAlpha(blip, transG)
        if transG == 0 then
            SetBlipSprite(blip, 2)
            RemoveBlip(blip)
            return
        end
    end
end)

RegisterNetEvent('qb-diving:client:UseGear', function(bool)
    local ped = PlayerPedId()
    if bool then
        if not IsPedSwimming(ped) and not IsPedInAnyVehicle(ped) then
            gearAnim()
            QBCore.Functions.TriggerCallback('qb-diving:server:RemoveGear', function(result, oxygen)
                if result then
                    QBCore.Functions.Progressbar("equip_gear", Lang:t("info.put_suit"), 5000, false, false, {}, {}, {}, {}, function() -- Done
                        deleteGear()
                        local maskModel = `p_d_scuba_mask_s`
                        local tankModel = `p_michael_scuba_tank_s`
                        RequestModel(tankModel)
                        while not HasModelLoaded(tankModel) do
                            Wait(0)
                        end
                        currentGear.tank = CreateObject(tankModel, 1.0, 1.0, 1.0, 1, 1, 0)
                        SetEntityCollision(currentGear.tank, false, false)
                        local bone1 = GetPedBoneIndex(ped, 24818)
                        AttachEntityToEntity(currentGear.tank, ped, bone1, -0.25, -0.25, 0.0, 180.0, 90.0, 0.0, 1, 1, 0, 0, 2, 1)
                        currentGear.oxygen = oxygen
                        RequestModel(maskModel)
                        while not HasModelLoaded(maskModel) do
                            Wait(0)
                        end
                        currentGear.mask = CreateObject(maskModel, 1.0, 1.0, 1.0, 1, 1, 0)
                        SetEntityCollision(currentGear.mask, false, false)
                        local bone2 = GetPedBoneIndex(ped, 12844)
                        AttachEntityToEntity(currentGear.mask, ped, bone2, 0.0, 0.0, 0.0, 180.0, 90.0, 0.0, 1, 1, 0, 0, 2, 1)
                        SetEnableScuba(ped, true)
                        SetPedMaxTimeUnderwater(ped, oxygen)
                        currentGear.enabled = true
                        ClearPedTasks(ped)
                        QBCore.Functions.Notify(Lang:t("error.take_off"), 'error', 5000)
                        Citizen.CreateThread(function()
                            while currentGear.enabled do
                                if IsPedSwimmingUnderWater(PlayerPedId()) then
                                    currentGear.oxygen = currentGear.oxygen-1
                                    if currentGear.oxygen == 300 then
                                        QBCore.Functions.Notify(Lang:t("warning.oxygen_five_minutes"), 'error')
                                    elseif currentGear.oxygen == 60 then
                                        QBCore.Functions.Notify(Lang:t("warning.oxygen_one_minute"), 'error')
                                    elseif currentGear.oxygen == 0 then
                                        QBCore.Functions.Notify(Lang:t("warning.oxygen_running_out"), 'error')
                                        SetPedMaxTimeUnderwater(ped, 30.0)
                                    elseif currentGear.oxygen == -30 then
                                        deleteGear()
                                        SetEnableScuba(ped, false)
                                        SetPedMaxTimeUnderwater(ped, 1.00)
                                        currentGear.enabled = false
                                    end
                                    local flashlight = 'Off'
                                    if lightOn then flashlight = 'On' end
                                    exports['qb-core']:DrawText("Oxygen Tank - Time Remaining: " .. currentGear.oxygen .. " seconds.<br>[F] Flashlight: "..flashlight, "left")
                                else
                                    exports['qb-core']:HideText()
                                end
                                Wait(1000)
                            end
                        end)
                    end)
                end
            end)
        else
            QBCore.Functions.Notify(Lang:t("error.not_standing_up"), 'error')
        end
    else
        if currentGear.enabled then
            gearAnim()
            QBCore.Functions.Progressbar("remove_gear", Lang:t("info.pullout_suit"), 5000, false, true, {}, {}, {}, {}, function() -- Done
                SetEnableScuba(ped, false)
                SetPedMaxTimeUnderwater(ped, 30.0)
                currentGear.enabled = false
                TriggerServerEvent('qb-diving:server:GiveBackGear', currentGear.oxygen)
                ClearPedTasks(ped)
                deleteGear()
                SetEnableScubaGearLight(ped, false)
                lightOn = false
                QBCore.Functions.Notify(Lang:t("success.took_out"))
            end)
        else
            QBCore.Functions.Notify(Lang:t("error.not_wearing"), 'error')
        end
    end
end)

-- Threads

CreateThread(function()
    if isLoggedIn then
        QBCore.Functions.TriggerCallback('qb-diving:server:GetDivingConfig', function(config, area)
            Config.CoralLocations = config
            setDivingLocation(area)
            createSeller()
        end)
    end
    if Config.UseTarget then return end
    while true do
        local sleep = 1000
        if isLoggedIn then
            if currentArea ~= 0 then
                sleep = 0
                if IsControlJustPressed(0, 51) then -- E
                    takeCoral(currentArea)
                    exports['qb-core']:KeyPressed()
                    Wait(500)
                    exports['qb-core']:HideText()
                    sleep = 3000
                end
            end

            if inSellerZone then
                sleep = 0
                if IsControlJustPressed(0, 51) then -- E
                    sellCoral()
                    exports['qb-core']:KeyPressed()
                    Wait(500)
                    exports['qb-core']:HideText()
                    sleep = 3000
                end
            end
        end
        Wait(sleep)
    end
end)

if Config.Marker.UseMarker then
    local color = Config.Marker.Color
    local size = Config.Marker.Size
    local rotate = 0
    local face = 0
    local bounce = 0
    if Config.Marker.Rotate then
        rotate = 1
        face = 0
    else
        rotate = 0
        face = 1
    end
    if Config.Marker.Bounce then
        bounce = 1
    end
    CreateThread(function()
        while true do
            Wait(1)
            if currentDivingLocation.area ~= 0 then
                local pos = GetEntityCoords(PlayerPedId(), true)
                for k, v in pairs(Config.CoralLocations[currentDivingLocation.area].coords.Coral) do
                    if not v.PickedUp then
                        local dist = #(pos - vector3(v.coords.x, v.coords.y, v.coords.z))
                        if dist <= Config.Marker.Distance and (not Config.Marker.RequireFlashlight or (Config.Marker.RequireFlashlight and lightOn)) then
                            DrawMarker(Config.Marker.Type, v.coords.x, v.coords.y, v.coords.z + 4.5, 0, 0, 0, 0, 0.0, 0, size[1], size[2], size[3], color[1], color[2], color[3], color[4], bounce, face, 0, rotate)
                        end
                    end
                end
            else
                Wait(10000)
            end
        end
    end)
end