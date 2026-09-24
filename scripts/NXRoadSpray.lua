NXRoadSpray = NXRoadSpray or {}
NXRoadSpray.enabled = true

-- Water thrown up by tyres on wet hard surfaces (asphalt, concrete, bridges and other
-- object roads; gravel throws a little). The counterpart of the mud sprayer in
-- NXFieldPhysics: it borrows the same wet-spray particle asset, recoloured to road water,
-- but runs its own emitter per wheel. Purely visual and computed locally on every client
-- from the wheel's contact state (WheelPhysics runs updateContactClient on clients),
-- speed and the weather, so it needs no network traffic.

local MIN_WETNESS    = 0.10    -- below this the road is just damp, no spray
local START_KMH      = 12.0    -- spray starts to appear
local FULL_KMH       = 70.0    -- spray at full strength
local RAIN_BOOST     = 0.5     -- extra while rain is actually falling (standing water)
local EMIT_GAIN      = 2.4
local REF_TYRE_AREA  = 0.30    -- width * radius of an average tyre
local SPEED_GAIN_MIN = 0.35
local SPEED_GAIN_MAX = 1.00
local WATER_COLOR    = { 0.52, 0.56, 0.60 }

local function nxClamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function NXRoadSpray.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Wheels, specializations)
end

function NXRoadSpray.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished", NXRoadSpray)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick",   NXRoadSpray)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete",       NXRoadSpray)
end

local function nxCreateEmitter(wheel)
    local assets = g_currentMission ~= nil and g_currentMission.nxFieldPhysics or nil
    if assets == nil or assets.referenceShape == nil or assets.referencePS == nil then return nil end
    local reference = assets.referencePS.soilWet
    if reference == nil then return nil end

    local refNode = wheel.node or wheel.driveNode or wheel.repr
    if refNode == nil or refNode == 0 then return nil end

    local wp = wheel.physics or wheel
    local radius = wp.radiusOriginal or wp.radius or wheel.radius or 0.5
    local width  = wp.width or wheel.width or 0.5

    local emitterShape = clone(assets.referenceShape, false, false, false)
    link(refNode, emitterShape)
    setRotation(emitterShape, 0, 0, 0)
    -- flatter than the mud emitter: water leaves the lower half of the tyre
    setScale(emitterShape, 2 * width, radius, 2 * radius)

    local ps = {}
    local psClone = clone(reference.shape, true, false, true)
    ParticleUtil.loadParticleSystemFromNode(psClone, ps, false, reference.worldSpace, reference.forceFullLifespan)
    ParticleUtil.setEmitterShape(ps, emitterShape)
    ParticleUtil.setEmittingState(ps, false)

    if getHasShaderParameter(ps.shape, "psColor") then
        setShaderParameter(ps.shape, "psColor", WATER_COLOR[1], WATER_COLOR[2], WATER_COLOR[3], 1, false)
    end

    return {
        ps          = ps,
        wheel       = wheel,
        emitter     = emitterShape,
        refNode     = refNode,
        tyreFactor  = nxClamp((width * radius) / REF_TYRE_AREA, 0.5, 2.0),
        baseSpeed   = ParticleUtil.getParticleSystemSpeed(ps) or 1,
        baseRandom  = ParticleUtil.getParticleSystemSpeedRandom(ps) or 1,
        emitting    = false
    }
end

function NXRoadSpray:onLoadFinished(savegame)
    if not self.isClient then return end
    if self.spec_wheels == nil or type(self.spec_wheels.wheels) ~= "table" then return end

    local sprays = {}
    for _, wheel in ipairs(self.spec_wheels.wheels) do
        local ok, entry = pcall(nxCreateEmitter, wheel)
        if ok and entry ~= nil then sprays[#sprays + 1] = entry end
    end
    self.nxRoadSprays = sprays
end

function NXRoadSpray:onDelete()
    if self.nxRoadSprays == nil then return end
    local list = {}
    for _, s in ipairs(self.nxRoadSprays) do list[#list + 1] = s.ps end
    ParticleUtil.deleteParticleSystems(list)
    self.nxRoadSprays = nil
end

local function nxSetEmitting(s, state)
    if s.emitting ~= state then
        ParticleUtil.setEmittingState(s.ps, state)
        s.emitting = state
    end
end

local function nxAllOff(vehicle)
    for _, s in ipairs(vehicle.nxRoadSprays) do nxSetEmitting(s, false) end
end

-- 0..1 how much water is sitting on hard surfaces right now
local function nxRoadWater()
    local env = g_currentMission.environment
    local weather = env ~= nil and env.weather or nil
    if weather == nil then return 0 end

    local wet = 0
    if weather.getGroundWetness ~= nil then wet = weather:getGroundWetness() or 0 end
    if wet < MIN_WETNESS then return 0 end

    local water = (wet - MIN_WETNESS) / (1 - MIN_WETNESS)
    if weather.getRainFallScale ~= nil then
        water = water + RAIN_BOOST * (weather:getRainFallScale() or 0)
    end
    return nxClamp(water, 0, 1)
end

-- Terrain layer material ids (5th value of a terrain layer's "attributes"):
-- 7 = asphalt / concrete / rock, 6 = gravel, 2 = grass & forest floor, 1 = mud.
local SURFACE_SPRAY = { [7] = 1.0, [6] = 0.4 }

-- 0..1 how much spray this wheel's surface throws (0 = none)
local function nxSurfaceSpray(wheel)
    local wp = wheel.physics
    if wp == nil or wp.hasSnowContact == true or WheelContactType == nil then return 0 end

    local contact = wp.contact
    if contact == WheelContactType.OBJECT then return 1 end -- bridges, object roads, yards
    if contact ~= WheelContactType.GROUND then return 0 end
    if FieldGroundType ~= nil and wp.densityType ~= FieldGroundType.NONE then return 0 end

    return SURFACE_SPRAY[wp.lastTerrainAttribute] or 0
end

function NXRoadSpray:onUpdateTick(dt)
    local sprays = self.nxRoadSprays
    if sprays == nil or #sprays == 0 then return end

    if not NXRoadSpray.enabled or not self:getIsActive() then
        nxAllOff(self)
        return
    end

    local water = nxRoadWater()
    local kmh = (self.getLastSpeed ~= nil) and math.abs(self:getLastSpeed()) or 0
    if water <= 0 or kmh < START_KMH then
        nxAllOff(self)
        return
    end

    local speedT = nxClamp((kmh - START_KMH) / (FULL_KMH - START_KMH), 0, 1)
    local strength = speedT * speedT * water
    local speedGain = SPEED_GAIN_MIN + (SPEED_GAIN_MAX - SPEED_GAIN_MIN) * speedT
    local reversing = (self.movingDirection or 1) < 0

    for _, s in ipairs(sprays) do
        local surface = nxSurfaceSpray(s.wheel)
        if strength * surface > 0.001 then
            nxSetEmitting(s, true)
            ParticleUtil.setEmitCountScale(s.ps, EMIT_GAIN * strength * surface * s.tyreFactor)
            ParticleUtil.setParticleSystemSpeed(s.ps, s.baseSpeed * speedGain)
            ParticleUtil.setParticleSystemSpeedRandom(s.ps, s.baseRandom * speedGain)

            local steer = s.wheel.physics.steeringAngle or 0
            local x, y, z = localToLocal(s.wheel.driveNode or s.wheel.node, s.refNode, s.wheel.xOffset or 0, 0, 0)
            local radius = (s.wheel.physics or s.wheel).radius or 0.5
            setTranslation(s.emitter, x, y - radius * 0.5, z)
            setRotation(s.emitter, 0, reversing and (math.pi + steer) or steer, 0)
        else
            nxSetEmitting(s, false)
        end
    end
end

if not rawget(_G, "_NXRoadSpray_bootstrapped") then
    _G._NXRoadSpray_bootstrapped = true

    local SPEC_NAME   = "nxRoadSpray"
    local MOD_NAME    = g_currentModName
    local FULL_SPEC   = (MOD_NAME or "") .. "." .. SPEC_NAME
    local SCRIPT_PATH = (g_currentModDirectory or "") .. "scripts/NXRoadSpray.lua"

    if g_specializationManager:getSpecializationByName(FULL_SPEC) == nil then
        g_specializationManager:addSpecialization(SPEC_NAME, "NXRoadSpray", SCRIPT_PATH, MOD_NAME)
    end

    local function nxInjectSpec(typeManager)
        if typeManager == nil or typeManager.typeName ~= "vehicle" then return end
        for typeName, typeDef in pairs(typeManager:getTypes()) do
            if typeDef ~= nil and typeName ~= "locomotive"
                and typeDef.specializationsByName["wheels"] ~= nil
                and typeDef.specializationsByName[FULL_SPEC] == nil then
                typeManager:addSpecialization(typeName, FULL_SPEC)
            end
        end
    end

    TypeManager.validateTypes = Utils.appendedFunction(TypeManager.validateTypes, nxInjectSpec)
end
