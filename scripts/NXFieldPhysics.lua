NXFieldPhysics = NXFieldPhysics or {}

NXFieldPhysics.mudSprayerEnabled = true

NXFieldPhysics.defaultColor = { r = 0.2 / 5, g = 0.14 / 5, b = 0.08 / 5 }
NXFieldPhysics.excludedToolTypes = {
    "PLANTERS", "SEEDERS", "WEEDERS", "TEDDERS", "WINDROWERS",
    "PLOWS", "SUBSOILERS", "CULTIVATORS", "DISCHARROWS",
    "POWERHARROWS", "SPADERS", "ROLLERS"
}

function NXFieldPhysics.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Washable, specializations)
       and SpecializationUtil.hasSpecialization(Wheels, specializations)
end

function NXFieldPhysics.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished", NXFieldPhysics)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick",   NXFieldPhysics)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete",       NXFieldPhysics)
end

function NXFieldPhysics.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "nxLoadParticleSystemsForWheel", NXFieldPhysics.loadParticleSystemsForWheel)
    SpecializationUtil.registerFunction(vehicleType, "nxUpdateWheelDirtPS",           NXFieldPhysics.updateWheelDirtPS)
    SpecializationUtil.registerFunction(vehicleType, "nxGetDirtPSState",              NXFieldPhysics.getDirtPSState)
    SpecializationUtil.registerFunction(vehicleType, "nxSetPSColorRDC",               NXFieldPhysics.setPSColorRDC)
    SpecializationUtil.registerFunction(vehicleType, "nxSetParticleEmittingState",    NXFieldPhysics.setParticleEmittingState)
    SpecializationUtil.registerFunction(vehicleType, "nxRdpCompareColor",             NXFieldPhysics.rdpCompareColor)
end

function NXFieldPhysics:rdpCompareColor(color1, color2, threshold)
    if not color1 or not color2 then return false end
    return math.abs(color1.r - color2.r) < threshold
       and math.abs(color1.g - color2.g) < threshold
       and math.abs(color1.b - color2.b) < threshold
end

function NXFieldPhysics:onLoadFinished(savegame)
    self.nxFieldPhysicsEnabled = true

    local storeItem = g_storeManager:getItemByXMLFilename(self.configFileName)
    if storeItem ~= nil then
        local categoryName = storeItem.categoryName or storeItem.category
        if categoryName ~= nil then
            for _, typeName in ipairs(NXFieldPhysics.excludedToolTypes) do
                if typeName == categoryName then
                    self.nxFieldPhysicsEnabled = false
                    break
                end
            end
        end
    end

    local dirtColor = { 0.2, 0.14, 0.08 }
    if g_currentMission.environment ~= nil and g_currentMission.environment.getDirtColors ~= nil then
        dirtColor = g_currentMission.environment:getDirtColors()
    end

    local assets = g_currentMission.nxFieldPhysics
    if self.nxFieldPhysicsEnabled
        and assets ~= nil and assets.referenceShape ~= nil
        and assets.referencePS ~= nil
        and assets.referencePS.soilDry ~= nil and assets.referencePS.soilWet ~= nil
        and self.spec_wheels ~= nil and self.spec_wheels.wheels ~= nil and #self.spec_wheels.wheels > 0 then

        for _, wheel in ipairs(self.spec_wheels.wheels) do
            local refNode = wheel.node or wheel.driveNode or wheel.repr
            if refNode ~= nil and refNode ~= 0 then
                self:nxLoadParticleSystemsForWheel(refNode, wheel, dirtColor)
                if wheel.additionalWheels ~= nil then
                    for _, additionalWheel in pairs(wheel.additionalWheels) do
                        local addRefNode = additionalWheel.node or additionalWheel.driveNode or additionalWheel.repr or refNode
                        if addRefNode ~= nil and addRefNode ~= 0 then
                            self:nxLoadParticleSystemsForWheel(addRefNode, additionalWheel, dirtColor)
                        end
                    end
                end
            end
        end
    end

    self.nxDirtParticleSystemDirtyFlag = self:getNextDirtyFlag()
end

function NXFieldPhysics:loadParticleSystemsForWheel(refNode, wheel, dirtColor)
    wheel.nxDirtPS = {}

    local assets = g_currentMission.nxFieldPhysics
    local emitterShape = clone(assets.referenceShape, false, false, false)
    link(refNode, emitterShape)

    local x, y, z
    if wheel.wheelTire == nil then
        x, y, z = localToLocal(wheel.driveNode or wheel.node, refNode, 0, 0, 0)
    else
        x, y, z = localToLocal(wheel.wheelTire, refNode, 0, 0, 0)
    end

    local wp = wheel.physics or wheel
    local radius = wp.radiusOriginal or wp.radius or wheel.radius or 0.5
    local width  = wp.width or wheel.width or 0.5

    setTranslation(emitterShape, x + (wheel.xOffset or 0), y, z)
    setRotation(emitterShape, 0, 0, 0)
    setScale(emitterShape, 2 * width, 2 * radius, 2 * radius)

    for _, name in ipairs({ "soilDry", "soilWet" }) do
        local reference = assets.referencePS[name]
        if reference ~= nil then
            wheel.nxDirtPS[name] = {}
            local psClone = clone(reference.shape, true, false, true)
            ParticleUtil.loadParticleSystemFromNode(psClone, wheel.nxDirtPS[name], false, reference.worldSpace, reference.forceFullLifespan)
            ParticleUtil.setEmitterShape(wheel.nxDirtPS[name], emitterShape)

            wheel.nxDirtPS[name].isActive = false
            wheel.nxDirtPS[name].particleSpeed       = ParticleUtil.getParticleSystemSpeed(wheel.nxDirtPS[name]) or 1
            wheel.nxDirtPS[name].particleRandomSpeed = ParticleUtil.getParticleSystemSpeedRandom(wheel.nxDirtPS[name]) or 1

            local particleColor = { r = dirtColor[1], g = dirtColor[2], b = dirtColor[3] }
            if particleColor.r == 0.2 then particleColor = NXFieldPhysics.defaultColor end
            wheel.nxDirtPS[name].rdcColor = { r = particleColor.r, g = particleColor.g, b = particleColor.b }
            setShaderParameter(wheel.nxDirtPS[name].shape, "psColor", particleColor.r, particleColor.g, particleColor.b, 1, false)
        end
    end
end

function NXFieldPhysics:onDelete()
    if not self.nxFieldPhysicsEnabled then return end
    if self.spec_wheels == nil or self.spec_wheels.wheels == nil then return end

    for _, wheel in pairs(self.spec_wheels.wheels) do
        if wheel.nxDirtPS ~= nil then
            ParticleUtil.deleteParticleSystems(wheel.nxDirtPS)
        end
        if wheel.additionalWheels ~= nil then
            for _, additionalWheel in pairs(wheel.additionalWheels) do
                if additionalWheel.nxDirtPS ~= nil then
                    ParticleUtil.deleteParticleSystems(additionalWheel.nxDirtPS)
                end
            end
        end
    end
end

function NXFieldPhysics:onUpdateTick(dt)
    if not self.nxFieldPhysicsEnabled then return end
    if NXFieldPhysics.mudSprayerEnabled == false then return end

    local vehicleActive = self:getIsActive()

    if self.isServer then
        if vehicleActive then
            self.nxOnDeactivateCalled = false

            local groundWet = false
            local weather = g_currentMission.environment ~= nil and g_currentMission.environment.weather or nil
            if weather ~= nil then
                groundWet = weather:getIsRaining() or false
                local rainFallScale = weather:getRainFallScale() or 0
                if rainFallScale > 0.02 then groundWet = true end
            end

            for i, wheel in pairs(self.spec_wheels.wheels) do
                if wheel.nxDirtPS ~= nil then
                    for name, ps in pairs(wheel.nxDirtPS) do
                        local previousActive = ps.isActive
                        ps.isActive = self:nxGetDirtPSState(nil, wheel, ps, groundWet)
                        ParticleUtil.setEmittingState(ps, ps.isActive)
                        if previousActive ~= ps.isActive then
                            self:nxSetParticleEmittingState(i, -1, name, ps.isActive)
                        end
                        if wheel.additionalWheels ~= nil then
                            for a, additionalWheel in pairs(wheel.additionalWheels) do
                                if additionalWheel.nxDirtPS ~= nil then
                                    for name2, ps2 in pairs(additionalWheel.nxDirtPS) do
                                        local previousAdd = ps2.isActive
                                        ps2.isActive = self:nxGetDirtPSState(wheel, additionalWheel, ps2, groundWet)
                                        ParticleUtil.setEmittingState(ps2, ps2.isActive)
                                        if previousAdd ~= ps2.isActive then
                                            self:nxSetParticleEmittingState(i, a, name2, ps2.isActive)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        elseif not self.nxOnDeactivateCalled then
            self.nxOnDeactivateCalled = true
            NXFieldPhysics.onDeactivate(self)
        end
    end

    if self.isClient and vehicleActive then
        for _, wheel in pairs(self.spec_wheels.wheels) do
            if wheel.nxDirtPS ~= nil then
                local netInfo = (wheel.physics and wheel.physics.netInfo) or wheel.netInfo
                if netInfo ~= nil and netInfo.xDrive ~= nil then
                    if netInfo.nxXDriveLast == nil then
                        netInfo.nxXDriveLast = netInfo.xDrive
                    end
                    local xDriveDiff = netInfo.xDrive - netInfo.nxXDriveLast
                    if xDriveDiff > math.pi then
                        netInfo.nxXDriveLast = netInfo.nxXDriveLast + 2 * math.pi
                    elseif xDriveDiff < -math.pi then
                        netInfo.nxXDriveLast = netInfo.nxXDriveLast - 2 * math.pi
                    end
                    xDriveDiff = netInfo.xDrive - netInfo.nxXDriveLast
                    netInfo.nxXDriveLast = netInfo.xDrive

                    local wheelRotSpeed = math.deg(xDriveDiff) / (0.001 * dt)
                    local wheelRotFactor = math.abs(wheelRotSpeed) / 1080

                    local wp = wheel.physics or wheel
                    local radius = wp.radiusOriginal or wp.radius or wheel.radius or 0.5
                    wheelRotFactor = wheelRotFactor * radius

                    local steeringAngle = netInfo.steeringAngle or wheel.steeringAngle or 0

                    self:nxUpdateWheelDirtPS(wheel, wheelRotFactor, steeringAngle)
                    if wheel.additionalWheels ~= nil then
                        for _, additionalWheel in pairs(wheel.additionalWheels) do
                            self:nxUpdateWheelDirtPS(additionalWheel, wheelRotFactor, steeringAngle, wheel)
                        end
                    end
                end
            end
        end
    end
end

function NXFieldPhysics:onDeactivate()
    if not self.nxFieldPhysicsEnabled or not self.isServer then return end

    for i, wheel in pairs(self.spec_wheels.wheels) do
        if wheel.nxDirtPS ~= nil then
            for name, ps in pairs(wheel.nxDirtPS) do
                if ps.isActive then
                    ParticleUtil.setEmittingState(ps, false)
                    ps.isActive = false
                    self:nxSetParticleEmittingState(i, -1, name, false)
                end
            end
            if wheel.additionalWheels ~= nil then
                for a, additionalWheel in pairs(wheel.additionalWheels) do
                    if additionalWheel.nxDirtPS ~= nil then
                        for name, ps in pairs(additionalWheel.nxDirtPS) do
                            if ps.isActive then
                                ParticleUtil.setEmittingState(ps, false)
                                ps.isActive = false
                                self:nxSetParticleEmittingState(i, a, name, false)
                            end
                        end
                    end
                end
            end
        end
    end
end

function NXFieldPhysics:getDirtPSState(parent, wheel, ps, groundWet)
    local wp = wheel.physics or wheel

    local hasSoilContact = wp.hasSoilContact or false
    if wp.netInfo ~= nil and wp.netInfo.hasSoilContact ~= nil then
        hasSoilContact = wp.netInfo.hasSoilContact
    end

    local hasSnowContact = wp.hasSnowContact or false

    if parent ~= nil then
        local pwp = parent.physics or parent
        if not hasSoilContact then
            hasSoilContact = pwp.hasSoilContact or false
            if pwp.netInfo ~= nil and pwp.netInfo.hasSoilContact ~= nil then
                hasSoilContact = pwp.netInfo.hasSoilContact
            end
        end
        if wp.hasSnowContact == nil then hasSnowContact = pwp.hasSnowContact or false end
    end

    if not hasSoilContact then return false end

    local isActive = not hasSnowContact

    if isActive then
        if ps == wheel.nxDirtPS.soilDry then
            local activate = not groundWet
            if self.spec_mudSystem ~= nil then
                local mfsu = g_currentMission.mudFieldSinkUpdater
                if mfsu ~= nil and mfsu.fieldSinkAmount ~= nil and mfsu.fieldSinkAmount < 0.99 then
                    activate = true
                end
            end
            isActive = activate
        elseif ps == wheel.nxDirtPS.soilWet then
            isActive = self.spec_mudSystem == nil and groundWet
        end
    end

    return isActive
end

function NXFieldPhysics:setPSColorRDC(ps, wheel, parentWheel)
    if self.spec_realDirtColor == nil then return end

    local targetColor = self.spec_realDirtColor.targetRDColor
    local colorSource = parentWheel or wheel
    if colorSource ~= nil and colorSource.targetRDColor ~= nil then
        targetColor = colorSource.targetRDColor
    end

    if targetColor == nil or not getHasShaderParameter(ps.shape, "psColor") then return end

    local particleColor = { r = targetColor.r, g = targetColor.g, b = targetColor.b }
    if particleColor.r == 0.2 then particleColor = NXFieldPhysics.defaultColor end

    if not self:nxRdpCompareColor(ps.rdcColor, particleColor, 0.0001) then
        ps.rdcColor.r, ps.rdcColor.g, ps.rdcColor.b = MathUtil.lerp3(
            ps.rdcColor.r, ps.rdcColor.g, ps.rdcColor.b,
            particleColor.r, particleColor.g, particleColor.b,
            0.1
        )
        setShaderParameter(ps.shape, "psColor", ps.rdcColor.r, ps.rdcColor.g, ps.rdcColor.b, 1, false)
    end
end

function NXFieldPhysics:updateWheelDirtPS(wheel, wheelRotFactor, steeringAngle, parentWheel)
    if wheel.nxDirtPS == nil then return end

    local wp = wheel.physics or wheel
    local radius = wp.radiusOriginal or wp.radius or 0.5
    if parentWheel ~= nil then
        local pwp = parentWheel.physics or parentWheel
        radius = pwp.radiusOriginal or pwp.radius or 0.5
    end

    local width = wp.width or wheel.width or 0.5
    local sizeScale = 2 * width * radius

    local groundWetness = 0
    local weather = g_currentMission.environment ~= nil and g_currentMission.environment.weather or nil
    if weather ~= nil and weather:getIsRaining() then groundWetness = 1 end

    for _, ps in pairs(wheel.nxDirtPS) do
        if ps.isActive then
            local mudSysDryScale = 1
            if self.spec_mudSystem ~= nil then
                local mfsu = g_currentMission.mudFieldSinkUpdater
                if mfsu ~= nil and mfsu.fieldSinkAmount ~= nil then
                    mudSysDryScale = math.max(1 - mfsu.fieldSinkAmount, 0)
                end
            end

            local speedEmitScale    = wheelRotFactor * sizeScale
            local speedEmitScaleWet = math.pow(2 * wheelRotFactor * sizeScale * groundWetness, 2)
            local emitScale = 0.5 * (speedEmitScale + speedEmitScaleWet)
            local slipBoost = wheel._nxSlipBoost or 1.0
            ParticleUtil.setEmitCountScale(ps, emitScale * mudSysDryScale * slipBoost)

            local speedFactor = 0.3 * wheelRotFactor
            local speed = math.min(ps.particleSpeed * speedFactor, 0.001)
            ParticleUtil.setParticleSystemSpeed(ps, speed * mudSysDryScale)
            ParticleUtil.setParticleSystemSpeedRandom(ps, (ps.particleRandomSpeed * speedFactor) * mudSysDryScale)

            local x, y, z
            if wheel.wheelTire == nil then
                x, y, z = localToLocal(wheel.driveNode or wheel.node, getParent(ps.emitterShape), wheel.xOffset or 0, 0, 0)
            else
                x, y, z = localToLocal(wheel.wheelTire, getParent(ps.emitterShape), 0, 0, 0)
            end
            setTranslation(ps.emitterShape, x, y, z)

            if self.movingDirection < 0 then
                setRotation(ps.emitterShape, 0, math.pi + steeringAngle, 0)
            else
                setRotation(ps.emitterShape, 0, steeringAngle, 0)
            end

            self:nxSetPSColorRDC(ps, wheel, parentWheel)
        end
    end
end

function NXFieldPhysics:setParticleEmittingState(i, a, psname, state, noEventSend)
    if g_currentMission.missionDynamicInfo.isMultiplayer then
        NXFieldPhysicsEvent.sendEvent(self, i, a, psname, state, noEventSend)

        local ps
        if a < 0 then
            ps = self.spec_wheels.wheels[i].nxDirtPS[psname]
        else
            ps = self.spec_wheels.wheels[i].additionalWheels[a].nxDirtPS[psname]
        end

        if ps ~= nil then
            ParticleUtil.setEmittingState(ps, state)
            ps.isActive = state
        end
    end
end

NXFieldPhysicsEvent = NXFieldPhysicsEvent or {}
if not NXFieldPhysicsEvent._classInitialized then
    NXFieldPhysicsEvent._classInitialized = true
    local NXFieldPhysicsEvent_mt = Class(NXFieldPhysicsEvent, Event)
    InitEventClass(NXFieldPhysicsEvent, "NXFieldPhysicsEvent")
    NXFieldPhysicsEvent.classMt = NXFieldPhysicsEvent_mt
end

function NXFieldPhysicsEvent.emptyNew()
    local self = Event.new(NXFieldPhysicsEvent.classMt)
    self.className = "NXFieldPhysicsEvent"
    return self
end

function NXFieldPhysicsEvent.new(vehicle, wheel, additionalWheel, psname, state)
    local self = NXFieldPhysicsEvent.emptyNew()
    self.vehicle = vehicle
    self.wheel = wheel
    self.additionalWheel = additionalWheel
    self.psname = psname
    self.state = state
    return self
end

function NXFieldPhysicsEvent:readStream(streamId, connection)
    self.vehicle         = NetworkUtil.readNodeObject(streamId)
    self.wheel           = streamReadInt8(streamId)
    self.additionalWheel = streamReadInt8(streamId)
    self.psname          = streamReadString(streamId)
    self.state           = streamReadBool(streamId)
    self:run(connection)
end

function NXFieldPhysicsEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteInt8(streamId, self.wheel)
    streamWriteInt8(streamId, self.additionalWheel)
    streamWriteString(streamId, self.psname)
    streamWriteBool(streamId, self.state)
end

function NXFieldPhysicsEvent:run(connection)
    if self.vehicle ~= nil and self.vehicle.nxSetParticleEmittingState ~= nil then
        self.vehicle:nxSetParticleEmittingState(self.wheel, self.additionalWheel, self.psname, self.state, true)
        if not connection:getIsServer() then
            g_server:broadcastEvent(NXFieldPhysicsEvent.new(self.vehicle, self.wheel, self.additionalWheel, self.psname, self.state), nil, connection, self.vehicle)
        end
    end
end

function NXFieldPhysicsEvent.sendEvent(vehicle, wheel, additionalWheel, psname, state, noEventSend)
    if noEventSend == true then return end
    if g_server ~= nil then
        g_server:broadcastEvent(NXFieldPhysicsEvent.new(vehicle, wheel, additionalWheel, psname, state), nil, nil, vehicle)
    else
        g_client:getServerConnection():sendEvent(NXFieldPhysicsEvent.new(vehicle, wheel, additionalWheel, psname, state))
    end
end

NXFieldPhysicsDensity = NXFieldPhysicsDensity or {}

NXFieldPhysicsDensity.LOG_PREFIX = "[FS25_FarmKit] DensitySystem: "
NXFieldPhysicsDensity.SERVER_ONLY = true
NXFieldPhysicsDensity.RUN_BASEGAME_FIRST = true
NXFieldPhysicsDensity.enabled = true
NXFieldPhysicsDensity.initialized = false
NXFieldPhysicsDensity.hooksInstalled = false
NXFieldPhysicsDensity.targets = {}
NXFieldPhysicsDensity.originalLimitFlags = {}

NXFieldPhysicsDensity.DEFAULT_FRUITS = {
    { name = "MEADOW",     forced = true,  sourceState = "",             targetState = "" },
    { name = "GRASS",      forced = true,  sourceState = "",             targetState = "" },
    { name = "FIELDGRASS", forced = true,  sourceState = "",             targetState = "" }
}

NXFieldPhysicsDensity.SOFTEN_DROP = 3

NXFieldPhysicsDensity.fruits = nil

local function nxLog(text)
    print(NXFieldPhysicsDensity.LOG_PREFIX .. tostring(text))
end

local function nxUpperName(name)
    return string.upper(tostring(name or ""))
end

function NXFieldPhysicsDensity:getDefaultFruitsCopy()
    local copy = {}
    for _, entry in ipairs(self.DEFAULT_FRUITS) do
        copy[#copy + 1] = {
            name = entry.name,
            forced = entry.forced == true,
            sourceState = entry.sourceState or "",
            targetState = entry.targetState or ""
        }
    end
    return copy
end

function NXFieldPhysicsDensity:applyLoadedConfig(config)
    if type(config) ~= "table" then
        self.fruits = self:getDefaultFruitsCopy()
    elseif type(config.fruits) == "table" and #config.fruits > 0 then
        self.fruits = {}
        for _, entry in ipairs(config.fruits) do
            if type(entry) == "table" and entry.name ~= nil and entry.name ~= "" then
                self.fruits[#self.fruits + 1] = {
                    name = nxUpperName(entry.name),
                    forced = entry.forced == true,
                    sourceState = tostring(entry.sourceState or ""),
                    targetState = tostring(entry.targetState or "")
                }
            end
        end
    else
        self.fruits = self:getDefaultFruitsCopy()
    end

    self.initialized = false
    self.targets = {}
end

function NXFieldPhysicsDensity:getEnabled()
    return self.enabled == true
end

function NXFieldPhysicsDensity:setEnabled(value)
    local newValue = value == true
    if newValue == self.enabled then return end

    self.enabled = newValue

    if not newValue then
        for fruitTypeRef, originalValue in pairs(self.originalLimitFlags) do
            if type(fruitTypeRef) == "table" then
                fruitTypeRef.limitDestructionToField = originalValue
            end
        end
        self.originalLimitFlags = {}
        self.initialized = false
        self.targets = {}
    else
        self.initialized = false
        self.targets = {}
    end
end

function NXFieldPhysicsDensity:getFruitTypeByName(name)
    if g_fruitTypeManager == nil or name == nil then return nil end

    local upper = nxUpperName(name)

    if type(g_fruitTypeManager.getFruitTypeByName) == "function" then
        local ok, fruitType = pcall(g_fruitTypeManager.getFruitTypeByName, g_fruitTypeManager, upper)
        if ok and fruitType ~= nil then return fruitType end
    end

    if type(g_fruitTypeManager.getFruitTypeIndexByName) == "function" then
        local ok, index = pcall(g_fruitTypeManager.getFruitTypeIndexByName, g_fruitTypeManager, upper)
        if ok and index ~= nil then
            if type(g_fruitTypeManager.getFruitTypeByIndex) == "function" then
                local okByIndex, fruitType = pcall(g_fruitTypeManager.getFruitTypeByIndex, g_fruitTypeManager, index)
                if okByIndex and fruitType ~= nil then return fruitType end
            end
            if g_fruitTypeManager.indexToFruitType ~= nil then
                return g_fruitTypeManager.indexToFruitType[index]
            end
        end
    end

    return nil
end

function NXFieldPhysicsDensity:getGrowthStateByName(fruitType, stateName)
    if fruitType == nil or stateName == nil or stateName == "" then return nil end

    local stateStr = tostring(stateName)
    local upper = string.upper(stateStr)

    if type(fruitType.getGrowthStateByName) == "function" then
        local ok, state = pcall(fruitType.getGrowthStateByName, fruitType, upper)
        if ok and state ~= nil then return state end
    end

    if type(fruitType.nameToGrowthState) == "table" then
        local state = fruitType.nameToGrowthState[upper]
        if state ~= nil then return state end
    end

    return nil
end

function NXFieldPhysicsDensity:findFruitConfigByName(name)
    if self.fruits == nil then return nil end
    local upper = nxUpperName(name)
    for _, entry in ipairs(self.fruits) do
        if entry.name == upper then return entry end
    end
    return nil
end

function NXFieldPhysicsDensity:applyForcedWheelDestructionStates(fruitType, config)
    if config == nil or config.sourceState == nil or config.sourceState == "" then return end

    local sourceState = self:getGrowthStateByName(fruitType, config.sourceState)
    local targetState = self:getGrowthStateByName(fruitType, config.targetState)
    if sourceState == nil or targetState == nil then return end

    fruitType.minWheelDestructionState = sourceState
    fruitType.maxWheelDestructionState = sourceState
    fruitType.wheelDestructionState = targetState
end

function NXFieldPhysicsDensity:createTarget(fruitType)
    if fruitType == nil then return nil end

    local config = self:findFruitConfigByName(fruitType.name)
    local isForced = config ~= nil and config.forced == true

    if not isForced and fruitType.limitDestructionToField ~= false then
        return nil
    end

    if isForced then
        self:applyForcedWheelDestructionStates(fruitType, config)
    end

    local densityMapId = fruitType.terrainDataPlaneId
    local startChannel = fruitType.startStateChannel
    local numChannels = fruitType.numStateChannels
    local minState = fruitType.minWheelDestructionState
    local maxState = fruitType.maxWheelDestructionState
    local targetState = fruitType.wheelDestructionState

    if densityMapId == nil or startChannel == nil or numChannels == nil
        or minState == nil or maxState == nil or targetState == nil then
        return nil
    end

    local terrainRootNode = g_currentMission ~= nil and g_currentMission.terrainRootNode or nil

    local okModifier, modifier = pcall(DensityMapModifier.new, densityMapId, startChannel, numChannels, terrainRootNode)
    if not okModifier or modifier == nil then return nil end

    local okFilter, filter = pcall(DensityMapFilter.new, densityMapId, startChannel, numChannels, terrainRootNode)
    if not okFilter or filter == nil then return nil end

    return {
        name = tostring(fruitType.name or "UNKNOWN"),
        fruitType = fruitType,
        modifier = modifier,
        filter = filter,
        minState = minState,
        maxState = maxState,
        targetState = targetState
    }
end

function NXFieldPhysicsDensity:initializeTargets()
    if self.initialized then return end
    self.initialized = true
    self.targets = {}

    if g_currentMission == nil or g_fruitTypeManager == nil then
        self.initialized = false
        return
    end

    local seen = {}
    local containers = {
        g_fruitTypeManager.fruitTypes,
        g_fruitTypeManager.indexToFruitType,
        g_fruitTypeManager.nameToFruitType,
        g_fruitTypeManager.nameToFruitTypeDesc
    }

    local function visit(fruitType)
        if type(fruitType) ~= "table" or seen[fruitType] then return end
        seen[fruitType] = true
        local target = self:createTarget(fruitType)
        if target ~= nil then self.targets[#self.targets + 1] = target end
    end

    for _, container in ipairs(containers) do
        if type(container) == "table" then
            for _, fruitType in pairs(container) do visit(fruitType) end
        end
    end

    for _, entry in ipairs(self.fruits or {}) do
        if entry.forced == true then
            visit(self:getFruitTypeByName(entry.name))
        end
    end

end

function NXFieldPhysicsDensity:applyTargetToArea(target, x0, z0, x1, z1, x2, z2)
    target.modifier:setParallelogramWorldCoords(x0, z0, x1, z1, x2, z2, DensityCoordType.POINT_POINT_POINT)

    local drop = NXFieldPhysicsDensity.SOFTEN_DROP or 3
    for sourceState = target.minState, target.maxState do
        target.filter:setValueCompareParams(DensityValueCompareType.EQUAL, sourceState)
        local softened = math.max(target.targetState, sourceState - drop)
        target.modifier:executeSet(softened, target.filter)
    end
end

function NXFieldPhysicsDensity:applyCustomLimitToFieldArea(x0, z0, x1, z1, x2, z2, vehicle)
    if not self.enabled then return end
    if self.SERVER_ONLY and g_server == nil then return end

    if g_farmlandManager ~= nil and g_farmlandManager.getFarmlandAtWorldPosition ~= nil then
        local px = x1 + x2 - x0
        local pz = z1 + z2 - z0
        local cx = (x0 + x1 + x2 + px) * 0.25
        local cz = (z0 + z1 + z2 + pz) * 0.25
        local samples = { x0, z0, x1, z1, x2, z2, px, pz, cx, cz }
        for i = 1, #samples, 2 do
            if g_farmlandManager:getFarmlandAtWorldPosition(samples[i], samples[i+1]) ~= nil then
                return
            end
        end
    end

    self:initializeTargets()
    if #self.targets == 0 then return end

    for _, target in ipairs(self.targets) do
        local ok, err = pcall(self.applyTargetToArea, self, target, x0, z0, x1, z1, x2, z2)
        if not ok then
            nxLog(string.format("Error applying destruction for '%s': %s", tostring(target.name), tostring(err)))
        end
    end
end

function NXFieldPhysicsDensity.wheelDestructionUpdate(wheelDestruction, dt)
    local self = NXFieldPhysicsDensity
    if not self.enabled then return end
    if self.SERVER_ONLY and g_server == nil then return end
    if wheelDestruction == nil or wheelDestruction.wheel == nil then return end
    if wheelDestruction.isCareWheel then return end
    if type(wheelDestruction.destructionNodes) ~= "table" then return end

    local vehicle = wheelDestruction.vehicle
    if vehicle ~= nil and vehicle.lastSpeedReal ~= nil and math.abs(vehicle.lastSpeedReal) <= 0.0002 then
        return
    end

    local wheel = wheelDestruction.wheel
    local physics = wheel.physics
    if physics == nil then return end
    if WheelContactType ~= nil and physics.contact == WheelContactType.NONE then return end

    for _, destructionNode in ipairs(wheelDestruction.destructionNodes) do
        local repr = wheel.repr
        local node = destructionNode.node
        if repr ~= nil and node ~= nil then
            local width = 0.5 * (destructionNode.width or 1)
            local length = math.min(0.5, width)
            local xShift, yShift, zShift = localToLocal(node, repr, 0, 0, 0)

            local x0, _, z0 = localToWorld(repr, xShift + width, yShift, zShift - length)
            local x1, _, z1 = localToWorld(repr, xShift - width, yShift, zShift - length)
            local x2, _, z2 = localToWorld(repr, xShift + width, yShift, zShift + length)

            self:applyCustomLimitToFieldArea(x0, z0, x1, z1, x2, z2, vehicle)
        end
    end
end

function NXFieldPhysicsDensity:installHooks()
    self.hooksInstalled = true
    return true
end

NXFieldPhysicsRegister = NXFieldPhysicsRegister or {}
NXFieldPhysicsRegister.modDirectory = g_currentModDirectory
NXFieldPhysicsRegister.modName = g_currentModName

function NXFieldPhysicsRegister:loadMap(name)
    g_currentMission.nxFieldPhysics = g_currentMission.nxFieldPhysics or {}
    g_currentMission.nxFieldPhysics.referencePS = g_currentMission.nxFieldPhysics.referencePS or {}

    local function loadPS(relativePath, key)
        local fullPath = Utils.getFilename(relativePath, self.modDirectory)
        local rootNode = loadI3DFile(fullPath, false, false, false)
        if rootNode == nil or rootNode == 0 then return nil end

        local psNode = I3DUtil.indexToObject(rootNode, "0")
        local ps = {}
        ParticleUtil.loadParticleSystemFromNode(psNode, ps, false, false, false)
        g_currentMission.nxFieldPhysics.referencePS[key] = ps
        link(getRootNode(), g_currentMission.nxFieldPhysics.referencePS[key].shape)
        return rootNode
    end

    self.psRootDry = loadPS("assets/NXMud/NXMudDry.i3d", "soilDry")
    self.psRootWet = loadPS("assets/NXMud/NXMudWet.i3d", "soilWet")

    local shapePath = Utils.getFilename("assets/NXMud/NXMudShape.i3d", self.modDirectory)
    self.shapeRoot = loadSharedI3DFile(shapePath, false, false)
    if self.shapeRoot ~= nil and self.shapeRoot ~= 0 then
        g_currentMission.nxFieldPhysics.referenceShape = getChildAt(self.shapeRoot, 0)
        link(getRootNode(), g_currentMission.nxFieldPhysics.referenceShape)
    end
end

function NXFieldPhysicsRegister:deleteMap()
    if g_currentMission.nxFieldPhysics ~= nil then
        if g_currentMission.nxFieldPhysics.referencePS ~= nil then
            for _, ps in pairs(g_currentMission.nxFieldPhysics.referencePS) do
                if ps.shape ~= nil then delete(ps.shape) end
            end
        end
        if g_currentMission.nxFieldPhysics.referenceShape ~= nil then
            delete(g_currentMission.nxFieldPhysics.referenceShape)
        end
    end
    if self.psRootDry ~= nil and self.psRootDry ~= 0 then delete(self.psRootDry); self.psRootDry = nil end
    if self.psRootWet ~= nil and self.psRootWet ~= 0 then delete(self.psRootWet); self.psRootWet = nil end
    if self.shapeRoot ~= nil and self.shapeRoot ~= 0 then delete(self.shapeRoot); self.shapeRoot = nil end
end

function NXFieldPhysicsDensity:loadMap()
    self.initialized = false
    self.targets = {}
    if self.fruits == nil then self.fruits = self:getDefaultFruitsCopy() end
    self:installHooks()
end

function NXFieldPhysicsDensity:update(dt)
    if not self.hooksInstalled then self:installHooks() end
end

function NXFieldPhysicsDensity:deleteMap()
    self.initialized = false
    self.targets = {}
    self.originalLimitFlags = {}
end

if not rawget(_G, "_NXFieldPhysics_bootstrapped") then
    _G._NXFieldPhysics_bootstrapped = true

    local SPEC_NAME = "nxFieldPhysics"
    local FULL_SPEC_NAME = NXFieldPhysicsRegister.modName .. "." .. SPEC_NAME
    local SCRIPT_PATH = NXFieldPhysicsRegister.modDirectory .. "scripts/NXFieldPhysics.lua"

    if g_specializationManager:getSpecializationByName(FULL_SPEC_NAME) == nil then
        g_specializationManager:addSpecialization(SPEC_NAME, "NXFieldPhysics", SCRIPT_PATH, NXFieldPhysicsRegister.modName)
    end

    local function nxInstallSpec(typeManager)
        if typeManager == nil or typeManager.typeName ~= "vehicle" then return end

        local count = 0
        for typeName, typeDef in pairs(typeManager:getTypes()) do
            if typeDef ~= nil and typeName ~= "locomotive" then
                local hasWashable = typeDef.specializationsByName["washable"] ~= nil
                local hasWheels   = typeDef.specializationsByName["wheels"] ~= nil
                if hasWashable and hasWheels and typeDef.specializationsByName[FULL_SPEC_NAME] == nil then
                    typeManager:addSpecialization(typeName, FULL_SPEC_NAME)
                    count = count + 1
                end
            end
        end
    end

    TypeManager.validateTypes = Utils.appendedFunction(TypeManager.validateTypes, nxInstallSpec)

    addModEventListener(NXFieldPhysicsRegister)
    addModEventListener(NXFieldPhysicsDensity)
end
