NXRealisticWheelPhysics = NXRealisticWheelPhysics or {}
NXRealisticWheelPhysics.enabled = true

-- Per-field-ground-type multipliers. Looked up via FieldDensityMap.GROUND_TYPE channel.
-- Values inspired by Mud System Physics's profiles, tuned down for FarmKit's lighter physics.
--   gripMult   <1.0 = less grip (wheels slip more on this surface)
--   sinkMult   scales wheel-radius reduction under slip (bog depth)
--   deformMult scales the rut deformation depth
--   brakeMult  scales viscous brake drag
local GROUND_PROFILES = {
    [1]  = { name = "StubbleTillage", gripMult = 0.88, sinkMult = 1.10, deformMult = 1.05, brakeMult = 1.00 },
    [2]  = { name = "Cultivated",     gripMult = 0.82, sinkMult = 1.35, deformMult = 1.25, brakeMult = 1.20 },
    [3]  = { name = "Seedbed",        gripMult = 0.85, sinkMult = 1.20, deformMult = 1.10, brakeMult = 1.10 },
    [4]  = { name = "Plowed",         gripMult = 0.75, sinkMult = 1.60, deformMult = 1.50, brakeMult = 1.40 },
    [5]  = { name = "RolledSeedbed",  gripMult = 0.92, sinkMult = 0.90, deformMult = 0.80, brakeMult = 0.85 },
    [6]  = { name = "Ridge",          gripMult = 0.85, sinkMult = 1.20, deformMult = 1.15, brakeMult = 1.10 },
    [7]  = { name = "Sown",           gripMult = 0.95, sinkMult = 0.80, deformMult = 0.70, brakeMult = 0.80 },
    [8]  = { name = "DirectSown",     gripMult = 0.95, sinkMult = 0.85, deformMult = 0.75, brakeMult = 0.85 },
    [9]  = { name = "Planted",        gripMult = 0.95, sinkMult = 0.85, deformMult = 0.75, brakeMult = 0.85 },
    [10] = { name = "RidgeSown",      gripMult = 0.93, sinkMult = 0.95, deformMult = 0.85, brakeMult = 0.90 },
    [11] = { name = "Rollerlines",    gripMult = 0.98, sinkMult = 0.70, deformMult = 0.60, brakeMult = 0.75 },
    [12] = { name = "HarvestReady",   gripMult = 0.95, sinkMult = 0.85, deformMult = 0.75, brakeMult = 0.85 },
    [13] = { name = "HarvestReadyO",  gripMult = 0.95, sinkMult = 0.85, deformMult = 0.75, brakeMult = 0.85 },
    [14] = { name = "Grass",          gripMult = 1.00, sinkMult = 0.50, deformMult = 0.40, brakeMult = 0.60 },
    [15] = { name = "GrassCut",       gripMult = 1.00, sinkMult = 0.50, deformMult = 0.40, brakeMult = 0.60 }
}

local DEFAULT_ON_FIELD_PROFILE = { name = "OnField", gripMult = 1.0, sinkMult = 1.0, deformMult = 1.0, brakeMult = 1.0 }

local CFG = {
    slipThreshold      = 0.20,
    minSpeedKmh        = 1.0,
    minSpeedMs         = 0.3,

    frontDiffFactor    = 0.55,
    rearDiffFactor     = 0.55,
    bothDiffFactor     = 0.60,
    fourWDFactor       = 0.40,

    wetMin             = 0.05,
    wetThresholdFloor  = 0.08,

    weightMinT         = 5.0,
    weightMaxT         = 25.0,
    weightThresholdFloor = 0.12,

    vtpPressureMin     = 0.8,
    vtpPressureMax     = 2.4,

    gripMinWetness     = 0.15,
    gripDryFieldFactor = 0.97,
    gripWetFieldFactor = 0.82,

    rainSlipWetnessMin = 0.25,   -- ground wetness at which rain-slip starts
    rainSlipMult       = 0.88,   -- grip factor at full wetness (all surfaces, on or off field)
    winterSlipTempC    = -3.0,   -- at/below this air temp, icy grip applies everywhere
    winterSlipMult     = 0.80,   -- grip factor on frozen/icy ground

    sinkSlipMin        = 0.20,
    sinkSlipFull       = 0.70,
    sinkMaxFactor      = 0.96,
    sinkSpeedIn        = 0.6,
    sinkSpeedOut       = 1.2,

    deformSlipMin      = 0.35,
    deformSlipFull     = 0.80,
    deformMaxDepth     = 0.12,
    deformTickDepth    = 0.0015,
    deformWetMult      = 1.3,
    deformIntervalMs   = 500,
    deformRadiusMul    = 0.65,
    deformHardness     = 0.25,
    deformMinSpeedKmh  = 0.8,
    deformBehindOffset = 0.8,

    deformDisableDisplacement = true,
    deformDampingMult  = 2.2,
    deformSpringMult   = 0.70,
    deformSusSpeedIn   = 6.0,
    deformSusSpeedOut  = 1.5,

    brakeSlipMin       = 0.40,
    brakeBase          = 0.3,
    brakeFromSlip      = 0.5,
    brakeRatio         = 0.005,
    brakeMaxRatio      = 0.10,
    brakeWetMult       = 1.2,

    slipBoostMin       = 0.20,
    slipBoostFull      = 0.65,
    slipBoostMaxMult   = 4.0,
    slipBoostWetMult   = 1.8,

    tireRefWidth       = 0.50,
    tireRefRadius      = 0.70,
}

local TIRE_PROFILES = {
    { keys = {"street","road","highway","asphalt","strasse"},                    gripMult=0.75, damageMult=1.4, slipThresholdMult=0.7, sinkMult=1.3 },
    { keys = {"forest","forst","log","skidder","nokian"},                        gripMult=1.10, damageMult=1.5, slipThresholdMult=1.1, sinkMult=0.8 },
    { keys = {"terra","wide","breit","flotation","low pressure","niederdruck"},  gripMult=1.05, damageMult=0.6, slipThresholdMult=1.2, sinkMult=0.6 },
    { keys = {"twin","dual","doppel","zwilling"},                                gripMult=1.05, damageMult=0.5, slipThresholdMult=1.3, sinkMult=0.5 },
    { keys = {"track","band","raupe","crawler","belt"},                          gripMult=1.15, damageMult=0.3, slipThresholdMult=1.5, sinkMult=0.3 },
}

NXRealisticWheelPhysics.displaySlip = 0.0

local tireTypeCache = {}
local wheelStates   = {}
local deformLastMs  = {}
local deformAccum   = {}
local currentMaxSlip = 0.0
local frameMaxSlip   = 0.0

local function nxClamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function nxLerp(a, b, t) return a + (b - a) * t end

local function nxGetSpeedKmh(vehicle)
    if vehicle == nil then return 0 end
    if vehicle.getLastSpeed ~= nil then return math.abs(vehicle:getLastSpeed() or 0) end
    return math.abs((vehicle.lastSpeed or 0) * 3600)
end

local function nxIsOnField(wx, wz)
    if g_farmlandManager == nil then return false end
    return g_farmlandManager:getFarmlandAtWorldPosition(wx, wz) ~= nil
end

-- Ground-type profile lookup. Returns the matching profile (or DEFAULT_ON_FIELD_PROFILE)
-- when wheel is on a recognized field surface; returns nil when off-field.
local groundTypeMapDataCache = nil
local function nxGetGroundProfile(wx, wz)
    if NXFarmKitShared == nil or NXFarmKitShared.getGroundTypeAtWorldPos == nil then
        return nxIsOnField(wx, wz) and DEFAULT_ON_FIELD_PROFILE or nil
    end

    if groundTypeMapDataCache == nil then
        groundTypeMapDataCache = NXFarmKitShared.getGroundTypeMapData()
    end
    if groundTypeMapDataCache == nil then
        return nxIsOnField(wx, wz) and DEFAULT_ON_FIELD_PROFILE or nil
    end

    local idx = NXFarmKitShared.getGroundTypeAtWorldPos(groundTypeMapDataCache, wx, wz)
    if idx ~= nil then
        local prof = GROUND_PROFILES[idx]
        if prof ~= nil then return prof end
        return DEFAULT_ON_FIELD_PROFILE
    end

    return nxIsOnField(wx, wz) and DEFAULT_ON_FIELD_PROFILE or nil
end

-- ===== Off-field mud: water + terrain mud/dirt layers =====
-- Driving through water (puddles, fords) or across a map's mud/dirt terrain texture
-- bogs the vehicle the same way a soft field does.
local WATER_PROFILE = {
    name = "Water", source = "water",
    gripMult = 0.55, sinkMult = 2.0, deformMult = 0.0, brakeMult = 2.2
}

local MUD_LAYER_IGNORES = { "CONCRETE", "STONE", "GRAVEL", "ASPHALT", "ROAD", "PAVE", "COBBLE" }

local nxMudLayers            = nil    -- { { id=, kind= }, ... }
local nxMudLayerScanned      = false
local nxMudLayerTerrainNode  = nil

local function nxGetTerrainNode()
    if g_currentMission ~= nil and g_currentMission.terrainRootNode ~= nil then
        return g_currentMission.terrainRootNode
    end
    return g_terrainNode
end

local function nxRefreshMudLayerCache(terrainNode)
    nxMudLayers           = {}
    nxMudLayerScanned     = true
    nxMudLayerTerrainNode = terrainNode

    if terrainNode == nil or getTerrainNumOfLayers == nil or getTerrainLayerName == nil then
        nxMudLayerScanned = false   -- terrain not ready — allow retry next call
        return
    end

    local numLayers = getTerrainNumOfLayers(terrainNode) or 0
    for layerId = 0, numLayers - 1 do
        local name = getTerrainLayerName(terrainNode, layerId)
        if name ~= nil then
            local up = string.upper(name)
            local ignore = false
            for _, ig in ipairs(MUD_LAYER_IGNORES) do
                if string.find(up, ig, 1, true) ~= nil then ignore = true; break end
            end
            if not ignore then
                local kind = nil
                if string.find(up, "WATER", 1, true) ~= nil then kind = "WATER"
                elseif string.find(up, "DIRT", 1, true) ~= nil then kind = "DIRT"
                elseif string.find(up, "MUD", 1, true) ~= nil then kind = "MUD"
                end
                if kind ~= nil then
                    nxMudLayers[#nxMudLayers + 1] = { id = layerId, kind = kind }
                end
            end
        end
    end
end

-- Returns a dynamically-built profile when the wheel is on a mud/dirt terrain layer, else nil.
local function nxGetTerrainMudProfile(wx, wz)
    local terrainNode = nxGetTerrainNode()
    if terrainNode == nil then return nil end

    if not nxMudLayerScanned or nxMudLayerTerrainNode ~= terrainNode then
        nxRefreshMudLayerCache(terrainNode)
    end
    if nxMudLayers == nil or #nxMudLayers == 0 or getTerrainLayerAtWorldPos == nil then
        return nil
    end

    local bestW, bestKind = 0, nil
    for _, layer in ipairs(nxMudLayers) do
        local ok, w = pcall(getTerrainLayerAtWorldPos, terrainNode, layer.id, wx, 0, wz)
        if ok and type(w) == "number" and w > bestW then
            bestW = w
            bestKind = layer.kind
        end
    end
    if bestW <= 0.05 then return nil end

    local f = nxClamp(bestW, 0, 1)
    if bestKind == "DIRT" then f = f * 0.5 end   -- dirt tracks are firmer than mud
    if f <= 0.03 then return nil end

    return {
        name       = "TerrainMud_" .. tostring(bestKind),
        source     = "mudLayer",
        gripMult   = nxLerp(1.00, 0.62, f),
        sinkMult   = nxLerp(0.30, 1.80, f),
        deformMult = nxLerp(0.30, 1.30, f),
        brakeMult  = nxLerp(0.40, 1.60, f)
    }
end

local function nxIsWheelInWater(wp)
    if wp == nil then return false end
    if wp.hasWaterContact == true then return true end
    if wp.netInfo ~= nil and wp.netInfo.hasWaterContact == true then return true end
    if wp.wheel ~= nil and wp.wheel.hasWaterContact == true then return true end
    return false
end

-- Resolves the strongest surface profile under the wheel: field > terrain mud layer > water override.
local function nxResolveSurfaceProfile(wp, wx, wz)
    if nxIsWheelInWater(wp) then
        return WATER_PROFILE
    end

    local profile = nxGetGroundProfile(wx, wz)
    if profile ~= nil then return profile end

    return nxGetTerrainMudProfile(wx, wz)
end

-- Air temperature in Celsius (with safe fallbacks).
NXRealisticWheelPhysics.FREEZE_HARD_C = -1.0
local function nxGetAirTempC()
    if g_currentMission == nil or g_currentMission.environment == nil then return 10 end
    local env = g_currentMission.environment
    local weather = env.weather
    if weather ~= nil and weather.getCurrentTemperature ~= nil then
        local ok, t = pcall(weather.getCurrentTemperature, weather)
        if ok and type(t) == "number" then return t end
    end
    if env.getCurrentTemperature ~= nil then
        local ok, t = pcall(env.getCurrentTemperature, env)
        if ok and type(t) == "number" then return t end
    end
    return 10
end

local function nxIsFrozenGround()
    return nxGetAirTempC() <= NXRealisticWheelPhysics.FREEZE_HARD_C
end

-- ===== Per-vehicle sink meter =====
-- Accumulates under slip on field, decays under clean movement. 0..1.
-- Throttled to ~once per 50ms per vehicle so 4-wheel updates don't multiply growth.
local sinkStates           = setmetatable({}, { __mode = "k" })
local SINK_IN_RATE         = 0.30   -- /sec at full intensity
local SINK_OUT_RATE        = 0.45   -- /sec when not slipping
local SINK_SLIP_MIN        = 0.20   -- below this slip the meter doesn't grow
local SINK_STUCK_SPEED_KMH = 6.0    -- above this ground speed the vehicle counts as "working", not stuck

local function nxUpdateSinkMeter(vehicle, onField, slip, wetness, speedKmh)
    if vehicle == nil then return 0 end
    local now = g_time or 0
    local st = sinkStates[vehicle]
    if st == nil then
        st = { sink = 0.0, lastUpdateMs = now, maxSlipAccum = 0, hadFieldSlip = false }
        sinkStates[vehicle] = st
    end

    -- "Stuck" = slipping hard but barely moving. Working a field at speed (plowing,
    -- cultivating) produces high slip too, but that is NOT stuck — gate on low speed.
    local isStuckLike = onField
        and slip > SINK_SLIP_MIN
        and (speedKmh or 0) < SINK_STUCK_SPEED_KMH

    if isStuckLike and slip > st.maxSlipAccum then st.maxSlipAccum = slip end
    if isStuckLike then st.hadFieldSlip = true end

    local elapsed = now - (st.lastUpdateMs or now)
    if elapsed < 50 then return st.sink end

    local dtSec = elapsed / 1000
    if st.hadFieldSlip then
        local intensity = nxClamp((st.maxSlipAccum - SINK_SLIP_MIN) / (1.0 - SINK_SLIP_MIN), 0, 1)
        local wetGain = 1.0 + nxClamp(wetness or 0, 0, 1) * 0.5
        st.sink = math.min(1.0, st.sink + SINK_IN_RATE * dtSec * intensity * wetGain)
    else
        st.sink = math.max(0.0, st.sink - SINK_OUT_RATE * dtSec)
    end

    st.lastUpdateMs = now
    st.maxSlipAccum = 0
    st.hadFieldSlip = false
    return st.sink
end

function NXRealisticWheelPhysics.getSinkLevel(vehicle)
    if vehicle == nil then return 0 end
    local st = sinkStates[vehicle]
    return (st ~= nil and st.sink) or 0
end

-- ===== Body dirt tinting =====
-- Caches per-vehicle list of shapes with the `dirtColor` shader parameter, then
-- lerps each shape's tint toward a surface-derived target color (mud/snow/lime/manure/fertilizer).
local tintStates           = setmetatable({}, { __mode = "k" })
local TINT_REFRESH_MS      = 8000   -- re-scan vehicle tree every 8s (handles attached implements)
local TINT_UPDATE_MS       = 200    -- apply tint at ~5 Hz
local TINT_LERP_PER_UPDATE = 0.06   -- 6% of the way toward target per update tick
local TINT_RECURSION_DEPTH = 8

local TINT_COLORS = {
    mud         = { r = 0.06, g = 0.04, b = 0.02 },
    snow        = { r = 0.95, g = 0.96, b = 0.98 },
    lime        = { r = 0.82, g = 0.90, b = 0.82 },
    fertilizer  = { r = 0.36, g = 0.31, b = 0.20 },
    manure      = { r = 0.20, g = 0.14, b = 0.08 },
    liquidManure= { r = 0.16, g = 0.15, b = 0.09 }
}

local function nxIsShapeNode(node)
    if node == nil or node == 0 then return false end
    if entityExists ~= nil and not entityExists(node) then return false end
    if getHasClassId == nil or ClassIds == nil or ClassIds.SHAPE == nil then return false end
    local ok, isShape = pcall(getHasClassId, node, ClassIds.SHAPE)
    return ok and isShape == true
end

local function nxCollectDirtShapes(rootNode)
    local shapes = {}
    if rootNode == nil or rootNode == 0 then return shapes end
    if getNumOfChildren == nil or getChildAt == nil or getHasShaderParameter == nil then return shapes end

    local function recurse(node, depth)
        if node == nil or node == 0 or depth > TINT_RECURSION_DEPTH then return end
        -- Only call getHasShaderParameter on Shape nodes — calling it on Transform/AttacherJoint
        -- nodes raises a (logged) engine error even when wrapped in pcall.
        if nxIsShapeNode(node) and getHasShaderParameter(node, "dirtColor") then
            shapes[#shapes + 1] = node
        end
        local n = 0
        pcall(function() n = getNumOfChildren(node) or 0 end)
        for i = 0, n - 1 do
            local child = getChildAt(node, i)
            recurse(child, depth + 1)
        end
    end

    recurse(rootNode, 0)
    return shapes
end

local function nxGetVanillaDirtColor()
    if g_currentMission ~= nil and g_currentMission.environment ~= nil and g_currentMission.environment.getDirtColors ~= nil then
        local ok, base = pcall(g_currentMission.environment.getDirtColors, g_currentMission.environment)
        if ok and type(base) == "table" then
            return { r = base[1] or 0.18, g = base[2] or 0.14, b = base[3] or 0.10 }
        end
    end
    return { r = 0.18, g = 0.14, b = 0.10 }
end

-- Picks a surface tint based on what's at the wheel position. Returns nil for "no tint" (revert to vanilla).
local function nxResolveSurfaceTint(wx, wz, wetness, tempC, profile)
    -- In water the vehicle washes off — don't tint, let it lerp back to clean.
    if profile ~= nil and profile.source == "water" then
        return nil
    end

    -- Winter snow tint takes priority on field or off
    if tempC <= NXRealisticWheelPhysics.FREEZE_HARD_C then
        return TINT_COLORS.snow
    end

    -- Spray-type sampling (lime / fertilizer / manure / liquidManure). Best-effort, safe-call.
    -- FS25 API name varies between patches; try the common ones under pcall.
    local sprayIdx = nil
    if FSDensityMapUtil ~= nil then
        for _, fnName in ipairs({ "getSprayTypeIndexAtWorldPos", "getSprayTypeAtWorldPos", "getSprayTypeAtArea" }) do
            local fn = FSDensityMapUtil[fnName]
            if type(fn) == "function" then
                local ok, val = pcall(fn, wx, wz)
                if ok and type(val) == "number" and val > 0 then sprayIdx = val; break end
            end
        end
    end
    if sprayIdx ~= nil and g_sprayTypeManager ~= nil then
        local sprayType = nil
        if g_sprayTypeManager.getSprayTypeByIndex ~= nil then
            local ok2, st = pcall(g_sprayTypeManager.getSprayTypeByIndex, g_sprayTypeManager, sprayIdx)
            if ok2 then sprayType = st end
        end
        if sprayType ~= nil and sprayType.fillTypeIndex ~= nil and g_fillTypeManager ~= nil then
            local fillType = g_fillTypeManager:getFillTypeByIndex(sprayType.fillTypeIndex)
            if fillType ~= nil and fillType.name ~= nil then
                local n = string.upper(tostring(fillType.name))
                if n == "LIME" or n == "LIQUIDLIME" then return TINT_COLORS.lime end
                if n == "FERTILIZER" or n == "LIQUIDFERTILIZER" then return TINT_COLORS.fertilizer end
                if n == "MANURE" then return TINT_COLORS.manure end
                if n == "LIQUIDMANURE" or n == "DIGESTATE" then return TINT_COLORS.liquidManure end
            end
        end
    end

    -- Wet field → mud tint
    if profile ~= nil and (wetness or 0) > 0.20 then
        return TINT_COLORS.mud
    end

    return nil
end

local function nxApplyBodyTint(vehicle, wx, wz, wetness, tempC, profile)
    if vehicle == nil or vehicle.rootNode == nil then return end
    if entityExists ~= nil and not entityExists(vehicle.rootNode) then return end

    local now = g_time or 0
    local st = tintStates[vehicle]
    if st == nil then
        st = { shapes = nil, lastRefreshMs = -1e9, lastUpdateMs = -1e9, currentColor = nxGetVanillaDirtColor() }
        tintStates[vehicle] = st
    end

    if (now - st.lastRefreshMs) > TINT_REFRESH_MS or st.shapes == nil then
        st.shapes = nxCollectDirtShapes(vehicle.rootNode)
        st.lastRefreshMs = now
    end
    if #st.shapes == 0 then return end

    if (now - st.lastUpdateMs) < TINT_UPDATE_MS then return end
    st.lastUpdateMs = now

    local target = nxResolveSurfaceTint(wx, wz, wetness, tempC, profile)
    if target == nil then
        target = nxGetVanillaDirtColor()
    end

    local cur = st.currentColor
    cur.r = cur.r + (target.r - cur.r) * TINT_LERP_PER_UPDATE
    cur.g = cur.g + (target.g - cur.g) * TINT_LERP_PER_UPDATE
    cur.b = cur.b + (target.b - cur.b) * TINT_LERP_PER_UPDATE

    for i = #st.shapes, 1, -1 do
        local shape = st.shapes[i]
        if nxIsShapeNode(shape) and getHasShaderParameter(shape, "dirtColor") then
            local _, _, _, a = getShaderParameter(shape, "dirtColor")
            setShaderParameter(shape, "dirtColor", cur.r, cur.g, cur.b, a or 1, false)
        else
            table.remove(st.shapes, i)
        end
    end
end

-- ===== Engine bog (Realistic Engine Mode) =====
-- When the vehicle is sinking and the player is on the throttle, force the engine's target RPM
-- upward. Physically: wheels spinning free in mud transfer little load to the drivetrain, so the
-- engine "runs free" with high revs and no forward motion — the classic stuck-vehicle sound.
-- Throttled per-vehicle to avoid spamming setEqualizedMotorRpm.
NXRealisticWheelPhysics.engineRpmModeEnabled = true

local engineBogStates              = setmetatable({}, { __mode = "k" })
local ENGINE_BOG_UPDATE_MS         = 100
local ENGINE_BOG_SINK_MIN          = 0.30   -- below this sink level, no RPM lift
local ENGINE_BOG_THROTTLE_MIN      = 0.20   -- need player throttle (or AI) to lift
local ENGINE_BOG_SPEED_MAX         = 6.0    -- above this ground speed (km/h) the vehicle isn't stuck
local ENGINE_BOG_RPM_FRAC_AT_MIN   = 0.55   -- at sink=ENGINE_BOG_SINK_MIN → 55% of engine range
local ENGINE_BOG_RPM_FRAC_AT_FULL  = 0.95   -- at sink=1.0 → 95% of engine range

local function nxApplyEngineBog(vehicle, speedKmh)
    if vehicle == nil then return end
    if NXRealisticWheelPhysics.engineRpmModeEnabled ~= true then return end
    if not NXRealisticWheelPhysics.enabled then return end
    if not vehicle.isServer then return end
    if vehicle.getIsMotorStarted == nil or not vehicle:getIsMotorStarted() then return end
    if vehicle.getIsAIActive ~= nil and vehicle:getIsAIActive() then return end

    -- Moving at a working pace means you're not stuck — cut the bog immediately
    -- (faster than waiting for the sink meter to decay).
    if (speedKmh or nxGetSpeedKmh(vehicle)) >= ENGINE_BOG_SPEED_MAX then return end

    local now = g_time or 0
    local st = engineBogStates[vehicle]
    if st == nil then
        st = { lastUpdateMs = -1e9 }
        engineBogStates[vehicle] = st
    end
    if (now - st.lastUpdateMs) < ENGINE_BOG_UPDATE_MS then return end
    st.lastUpdateMs = now

    local sink = NXRealisticWheelPhysics.getSinkLevel(vehicle)
    if sink < ENGINE_BOG_SINK_MIN then return end

    local drv = vehicle.spec_drivable
    local throttle = (drv ~= nil and math.abs(drv.axisForward or 0)) or 0
    if throttle < ENGINE_BOG_THROTTLE_MIN then return end

    if vehicle.getMotor == nil then return end
    local motor = vehicle:getMotor()
    if motor == nil then return end

    local minRpm = motor:getMinRpm()
    local maxRpm = motor:getMaxRpm()
    if minRpm == nil or maxRpm == nil or maxRpm <= minRpm then return end

    -- Map sink into an RPM fraction of the engine's range
    local sinkT  = nxClamp((sink - ENGINE_BOG_SINK_MIN) / (1.0 - ENGINE_BOG_SINK_MIN), 0, 1)
    local rpmFrac = nxLerp(ENGINE_BOG_RPM_FRAC_AT_MIN, ENGINE_BOG_RPM_FRAC_AT_FULL, sinkT)
    -- Scale by throttle so lifting off the gas still lets RPM drop naturally
    local throttleScale = nxClamp(throttle, 0, 1)
    local targetRpm = minRpm + (maxRpm - minRpm) * rpmFrac * throttleScale

    -- Never lower below what the engine already wants — only lift
    local currentEq = motor:getEqualizedMotorRpm() or minRpm
    if targetRpm > currentEq then
        motor:setEqualizedMotorRpm(math.min(targetRpm, maxRpm * 0.995))
    end
end

-- ===== Speed cap when stuck + perma-stuck =====
-- As the sink meter climbs, cap the vehicle's top speed — a bogged machine can't move fast.
-- If the vehicle stays pinned at maximum sink, there is a small chance it becomes
-- "perma-stuck": it won't free itself and needs to be towed out.
NXRealisticWheelPhysics.permaStuckEnabled = true

local speedCapStates         = setmetatable({}, { __mode = "k" })
local SPEED_CAP_SINK_MIN     = 0.50    -- below this sink, no speed cap
local SPEED_CAP_STUCK_SINK   = 0.85    -- at/above this sink, full-stuck cap
local SPEED_CAP_MUD_KMH      = 14.0    -- cap at SPEED_CAP_SINK_MIN
local SPEED_CAP_STUCK_KMH    = 4.0     -- cap at SPEED_CAP_STUCK_SINK and beyond

local PERMA_STUCK_SINK_MIN     = 0.97    -- sink must be pinned this high...
local PERMA_STUCK_ARM_MS       = 8000    -- ...for this long before a roll is made
local PERMA_STUCK_CHANCE       = 0.15    -- roll chance once armed
local PERMA_STUCK_SPEED_KMH    = 1.0     -- speed cap while perma-stuck
local PERMA_STUCK_RELEASE_DIST = 7.0     -- metres of tow-drag needed to free the machine
local PERMA_STUCK_TIMEOUT_MS   = 180000  -- safety net: auto-release after 3 minutes

function NXRealisticWheelPhysics.getIsPermaStuck(vehicle)
    if vehicle == nil then return false end
    local st = speedCapStates[vehicle]
    return st ~= nil and st.permaStuck == true
end

local function nxApplySpeedCap(vehicle, speedKmh)
    if vehicle == nil then return end
    if not vehicle.isServer then return end
    if vehicle.getMotor == nil then return end

    local motor = vehicle:getMotor()
    if motor == nil or motor.setSpeedLimit == nil then return end

    local st = speedCapStates[vehicle]

    -- Feature disabled: release any cap / perma-stuck we previously applied, then bail.
    if not NXRealisticWheelPhysics.enabled then
        if st ~= nil and (st.applied or st.permaStuck) then
            motor:setSpeedLimit(math.huge)
            st.applied      = false
            st.permaStuck   = false
            st.armedSinceMs = nil
        end
        return
    end

    local now = g_time or 0
    if st == nil then
        st = { lastFrameMs = -1, applied = false, armedSinceMs = nil,
               permaStuck = false, permaStuckSinceMs = 0, permaTowDist = 0, permaLastSec = nil }
        speedCapStates[vehicle] = st
    end
    if st.lastFrameMs == now then return end   -- once per frame per vehicle (per-wheel dedup)
    st.lastFrameMs = now

    local sink = NXRealisticWheelPhysics.getSinkLevel(vehicle)
    speedKmh = speedKmh or nxGetSpeedKmh(vehicle)

    -- ----- Already perma-stuck -----
    if st.permaStuck then
        -- Free it by towing: accumulate only the distance covered ABOVE the machine's own
        -- capped speed — so flooring it at the 1 km/h cap makes zero progress, but a tow
        -- vehicle dragging it (even slowly) frees it after PERMA_STUCK_RELEASE_DIST metres.
        local capMs    = PERMA_STUCK_SPEED_KMH / 3.6
        local curMs    = (speedKmh or 0) / 3.6
        local nowSec   = now / 1000
        local dtSec    = nxClamp(nowSec - (st.permaLastSec or nowSec), 0, 1.0)
        st.permaLastSec = nowSec
        if curMs > capMs then
            st.permaTowDist = (st.permaTowDist or 0) + (curMs - capMs) * dtSec
        end

        if (st.permaTowDist or 0) >= PERMA_STUCK_RELEASE_DIST
            or (now - st.permaStuckSinceMs) > PERMA_STUCK_TIMEOUT_MS then
            st.permaStuck   = false
            st.armedSinceMs = nil
            st.permaTowDist = 0
            motor:setSpeedLimit(math.huge)
            st.applied = false
            return
        end
        motor:setSpeedLimit(PERMA_STUCK_SPEED_KMH)
        st.applied = true
        return
    end

    -- ----- Perma-stuck arming + roll (player vehicles only — never AI) -----
    if NXRealisticWheelPhysics.permaStuckEnabled == true
        and not (vehicle.getIsAIActive ~= nil and vehicle:getIsAIActive()) then
        if sink >= PERMA_STUCK_SINK_MIN then
            if st.armedSinceMs == nil then
                st.armedSinceMs = now
            elseif (now - st.armedSinceMs) >= PERMA_STUCK_ARM_MS then
                st.armedSinceMs = now   -- reset the window whether or not the roll hits
                if math.random() < PERMA_STUCK_CHANCE then
                    st.permaStuck        = true
                    st.permaStuckSinceMs = now
                    st.permaTowDist      = 0
                    st.permaLastSec      = now / 1000
                    motor:setSpeedLimit(PERMA_STUCK_SPEED_KMH)
                    st.applied = true
                    return
                end
            end
        else
            st.armedSinceMs = nil
        end
    end

    -- ----- Ordinary sink-driven speed cap -----
    if sink < SPEED_CAP_SINK_MIN then
        -- Release the cap once, on the falling edge
        if st.applied then
            motor:setSpeedLimit(math.huge)
            st.applied = false
        end
        return
    end

    local capKmh
    if sink >= SPEED_CAP_STUCK_SINK then
        capKmh = SPEED_CAP_STUCK_KMH
    else
        local t = nxClamp((sink - SPEED_CAP_SINK_MIN) / (SPEED_CAP_STUCK_SINK - SPEED_CAP_SINK_MIN), 0, 1)
        capKmh = nxLerp(SPEED_CAP_MUD_KMH, SPEED_CAP_STUCK_KMH, t)
    end

    motor:setSpeedLimit(capKmh)
    st.applied = true
end

local function nxGetWetness()
    if g_currentMission == nil then return 0 end
    local weather = g_currentMission.environment and g_currentMission.environment.weather
    if weather == nil or weather.getGroundWetness == nil then return 0 end
    return nxClamp(weather:getGroundWetness() or 0, 0, 1)
end

local function nxGetIsRaining()
    if g_currentMission == nil or g_currentMission.environment == nil then return false end
    local weather = g_currentMission.environment.weather
    if weather == nil or weather.getIsRaining == nil then return false end
    local ok, raining = pcall(weather.getIsRaining, weather)
    return ok and raining == true
end

local function nxGetMassTons(vehicle)
    if vehicle == nil then return 0 end
    if vehicle.getTotalMass ~= nil then
        local kg = vehicle:getTotalMass()
        if type(kg) == "number" and kg > 0 then return kg / 1000 end
    end
    local mSpec = vehicle.spec_motorized
    if mSpec ~= nil and type(mSpec.mass) == "number" then return mSpec.mass / 1000 end
    return 0
end

local function nxDetectTireType(wp)
    local cached = tireTypeCache[wp]
    if cached ~= nil then return cached end

    local result = { gripMult = 1.0, damageMult = 1.0, slipThresholdMult = 1.0, sinkMult = 1.0 }
    local wheel  = wp.wheel or wp
    local width  = wheel.width or 0.5
    local radius = wp.radiusOriginal or wheel.radius or 0.7

    local name = ""
    for _, key in ipairs({ "tireName", "tireFilename", "xmlFilename", "name" }) do
        if wheel[key] ~= nil then name = string.lower(tostring(wheel[key])); break end
    end
    if name == "" and wp.configName ~= nil then name = string.lower(tostring(wp.configName)) end

    local matched = false
    for _, profile in ipairs(TIRE_PROFILES) do
        for _, kw in ipairs(profile.keys) do
            if string.find(name, kw, 1, true) ~= nil then
                result.gripMult          = profile.gripMult
                result.damageMult        = profile.damageMult
                result.slipThresholdMult = profile.slipThresholdMult
                result.sinkMult          = profile.sinkMult
                matched = true
                break
            end
        end
        if matched then break end
    end

    if not matched then
        local refArea = (CFG.tireRefWidth or 0.5) * (CFG.tireRefRadius or 0.7)
        local areaRatio = (width * radius) / math.max(0.01, refArea)
        result.damageMult        = nxClamp(1.0 / areaRatio, 0.4, 2.0)
        result.sinkMult          = nxClamp(1.0 / areaRatio, 0.3, 1.8)
        result.gripMult          = nxClamp(0.9 + areaRatio * 0.1, 0.80, 1.15)
        result.slipThresholdMult = nxClamp(areaRatio * 0.9 + 0.1, 0.7, 1.5)
    end

    tireTypeCache[wp] = result
    return result
end

local function nxGetDiffSlipFactor(vehicle)
    if vehicle == nil then return 1.0 end

    local has4WD, hasFront, hasRear = false, false, false

    local wSpec = vehicle.spec_wheels
    if wSpec ~= nil and (wSpec.isFourWDActive == true or wSpec.fourWDIsActive == true) then has4WD = true end

    local mSpec = vehicle.spec_motorized
    if mSpec ~= nil then
        if mSpec.isFourWDActive == true or mSpec.fourWDIsActive == true then has4WD = true end
        if mSpec.differentials ~= nil then
            for _, d in ipairs(mSpec.differentials) do
                if d ~= nil and d.diffIsLocked == true then
                    if d.diffIndex == 0 then hasFront = true
                    elseif d.diffIndex == 1 then hasRear = true
                    else hasFront, hasRear = true, true end
                end
            end
        end
    end

    if has4WD then return CFG.fourWDFactor end
    if hasFront and hasRear then return CFG.bothDiffFactor end
    if hasFront then return CFG.frontDiffFactor end
    if hasRear  then return CFG.rearDiffFactor end
    return 1.0
end

local function nxGetVTPPressureBar(vehicle)
    if vehicle == nil then return nil end
    local spec = vehicle.spec_variableTirePressure
    if spec == nil or spec.currentFactor == nil then return nil end

    local fieldP = tonumber(spec.customFieldPressure or spec.fieldPressure) or 1.0
    local roadP  = tonumber(spec.customRoadPressure  or spec.roadPressure)  or 2.0
    local fieldF = spec.fieldDeformationFactor or 1.25
    local roadF  = spec.roadDeformationFactor  or 0.35
    local range  = roadF - fieldF
    if math.abs(range) < 0.001 then
        return (spec.isRoadMode == true) and roadP or fieldP
    end
    local t = nxClamp((spec.currentFactor - fieldF) / range, 0, 1)
    return fieldP + (roadP - fieldP) * t
end

local function nxGetVTPDamageFactor(vehicle)
    local p = nxGetVTPPressureBar(vehicle)
    if p == nil then return 1.0 end
    local range = CFG.vtpPressureMax - CFG.vtpPressureMin
    if range <= 0 then return 1.0 end
    return nxClamp((p - CFG.vtpPressureMin) / range, 0, 1)
end

local function nxEffectiveThreshold(vehicle)
    local th = CFG.slipThreshold

    local wet = nxGetWetness()
    if wet >= CFG.wetMin then
        local t = math.min(1.0, (wet - CFG.wetMin) / (1.0 - CFG.wetMin))
        local wetTh = nxLerp(CFG.slipThreshold, CFG.wetThresholdFloor, t)
        if wetTh < th then th = wetTh end
    end

    local tons = nxGetMassTons(vehicle)
    if tons > CFG.weightMinT then
        local t = math.min(1.0, (tons - CFG.weightMinT) / (CFG.weightMaxT - CFG.weightMinT))
        local wTh = nxLerp(CFG.slipThreshold, CFG.weightThresholdFloor, t)
        if wTh < th then th = wTh end
    end

    return th
end

local function nxGetWheelState(wp)
    local st = wheelStates[wp]
    if st == nil then
        st = {
            sinkFactor = 0.0,
            gripBase   = nil,
            origRadius = nil,
            deformBlend = 0.0,
            displacementDisabled = false,
            suspensionApplied = false
        }
        wheelStates[wp] = st
    end
    return st
end

local function nxPaintCultivated(wheel)
    if wheel == nil or wheel.repr == nil then return end
    local width  = (wheel.width or 0.5) * 0.5
    local length = math.max((wheel.width or 0.5) * 0.3, 0.15)

    local x0, _, z0 = localToWorld(wheel.repr,  width, 0, -length)
    local x1, _, z1 = localToWorld(wheel.repr, -width, 0, -length)
    local x2, _, z2 = localToWorld(wheel.repr,  width, 0,  length)

    FSDensityMapUtil.updateCultivatorArea(x0, z0, x1, z1, x2, z2, false, true, nil, nil, false, true)
    if FSDensityMapUtil.eraseTireTrack ~= nil then
        FSDensityMapUtil.eraseTireTrack(x0, z0, x1, z1, x2, z2)
    end
end

local function nxApplyGripReduction(wp, onField, wetness, profile, isFrozen, isRaining, tempC)
    if wp == nil then return end
    local st = nxGetWheelState(wp)

    if st.gripBase == nil then
        st.gripBase = {
            maxLatFriction  = wp.maxLatFriction,
            maxLongFriction = wp.maxLongFriction,
            frictionScale   = wp.frictionScale
        }
    end

    -- Grip scale starts at 1.0 (vanilla) and takes the worst of each penalty.
    local scale = 1.0

    -- Field grip loss — soft/loose farmland traction. Frozen ground is hard, so skip it there.
    if onField and not isFrozen then
        local tire = nxDetectTireType(wp)
        local dryF = nxClamp(CFG.gripDryFieldFactor * tire.gripMult, 0.5, 1.0)
        local wetF = nxClamp(CFG.gripWetFieldFactor * tire.gripMult, 0.4, 1.0)

        local fieldScale
        if wetness < CFG.gripMinWetness then
            fieldScale = dryF
        else
            local t = nxClamp((wetness - CFG.gripMinWetness) / (1.0 - CFG.gripMinWetness), 0, 1)
            fieldScale = nxLerp(dryF, wetF, t)
        end

        if profile ~= nil and type(profile.gripMult) == "number" then
            fieldScale = fieldScale * profile.gripMult
        end

        if fieldScale < scale then scale = fieldScale end
    end

    -- Rain slip — wet roads / grass / yards lose a little grip everywhere, on or off field.
    if isRaining == true then
        local w = nxClamp(wetness or 0, 0, 1)
        if w >= CFG.rainSlipWetnessMin then
            local t = nxClamp((w - CFG.rainSlipWetnessMin) / (1.0 - CFG.rainSlipWetnessMin), 0, 1)
            local rainScale = nxLerp(1.0, CFG.rainSlipMult, t)
            if rainScale < scale then scale = rainScale end
        end
    end

    -- Winter slip — icy/frozen ground is slippery on every surface.
    if tempC ~= nil and tempC <= CFG.winterSlipTempC then
        if CFG.winterSlipMult < scale then scale = CFG.winterSlipMult end
    end

    scale = nxClamp(scale, 0.30, 1.0)

    if st.gripBase.maxLatFriction  ~= nil and type(wp.maxLatFriction)  == "number" then wp.maxLatFriction  = st.gripBase.maxLatFriction  * scale end
    if st.gripBase.maxLongFriction ~= nil and type(wp.maxLongFriction) == "number" then wp.maxLongFriction = st.gripBase.maxLongFriction * scale end
    if st.gripBase.frictionScale   ~= nil and type(wp.frictionScale)   == "number" then wp.frictionScale   = st.gripBase.frictionScale   * scale end
end

local function nxApplyWheelSink(wp, vehicle, onField, slip, dt, profile)
    if wp == nil then return end
    local st = nxGetWheelState(wp)

    if st.origRadius == nil then st.origRadius = wp.radiusOriginal or wp.radius end

    local dtSec = dt / 1000
    local target = 0
    if onField and slip > CFG.sinkSlipMin then
        local t = nxClamp((slip - CFG.sinkSlipMin) / (CFG.sinkSlipFull - CFG.sinkSlipMin), 0, 1)
        target = t * nxDetectTireType(wp).sinkMult
        if profile ~= nil and type(profile.sinkMult) == "number" then
            target = target * profile.sinkMult
        end
    end

    if target > st.sinkFactor then
        st.sinkFactor = math.min(st.sinkFactor + CFG.sinkSpeedIn * dtSec, target)
    else
        st.sinkFactor = math.max(st.sinkFactor - CFG.sinkSpeedOut * dtSec, target)
    end

    local newRadius = st.origRadius * nxLerp(1.0, CFG.sinkMaxFactor, st.sinkFactor)

    if _G.__MudRadiusCombiner ~= nil and _G.__MudRadiusCombiner.apply ~= nil then
        wp.__ttdOrigRadius    = st.origRadius
        wp.__ttdDesiredRadius = newRadius
        if wp.__mpDesiredRadius == nil and wp.__fgDesiredRadius == nil then
            wp.radius = newRadius
            wp.isPositionDirty = true
            wp.isFrictionDirty = true
        end
    elseif vehicle ~= nil and vehicle.isServer then
        wp.radius = newRadius
        wp.isPositionDirty = true
        wp.isFrictionDirty = true
    end
end

local function nxApplySlipDeformation(wp, vehicle, onField, slip, wetness, wx, wz, speedKmh, profile, isFrozen)
    if wp == nil or vehicle == nil or not vehicle.isServer then return end
    if not onField or isFrozen then return end
    if g_currentMission == nil or TerrainDeformation == nil or g_currentMission.terrainRootNode == nil then return end
    if speedKmh < CFG.deformMinSpeedKmh then return end
    if type(slip) ~= "number" or slip <= 0 then return end

    local tire = nxDetectTireType(wp)
    local slipMin = CFG.deformSlipMin * (tire.slipThresholdMult or 1.0)
    if slip < slipMin then return end

    local nowMs = g_time or 0
    deformLastMs[wp] = deformLastMs[wp] or 0
    if (nowMs - deformLastMs[wp]) < CFG.deformIntervalMs then return end
    deformLastMs[wp] = nowMs

    deformAccum[wp] = deformAccum[wp] or 0
    local maxTotal = CFG.deformMaxDepth
    if deformAccum[wp] >= maxTotal then return end

    local slipT = nxClamp((slip - slipMin) / (CFG.deformSlipFull - slipMin), 0, 1)
    local depth = CFG.deformTickDepth * slipT * (tire.damageMult or 1.0)

    if wetness > 0.05 then
        local wetT = nxClamp(wetness, 0, 1)
        depth = depth * nxLerp(1.0, CFG.deformWetMult, wetT)
    end

    if profile ~= nil and type(profile.deformMult) == "number" then
        depth = depth * profile.deformMult
    end

    local remaining = maxTotal - deformAccum[wp]
    if depth > remaining then depth = remaining end
    if depth <= 0.0005 then return end

    deformAccum[wp] = deformAccum[wp] + depth

    local deformX, deformZ = wx, wz
    local node = wp.repr or wp.node or (wp.wheel and (wp.wheel.repr or wp.wheel.node))
    if node ~= nil and node ~= 0 then
        local dx, _, dz = localDirectionToWorld(node, 0, 0, -1)
        local len = math.sqrt(dx * dx + dz * dz)
        if len > 0.001 then
            deformX = wx + (dx / len) * CFG.deformBehindOffset
            deformZ = wz + (dz / len) * CFG.deformBehindOffset
        end
    end

    local wheelW = (wp.wheel and wp.wheel.width) or wp.width or 0.5
    local brushR = math.max(0.18, wheelW * CFG.deformRadiusMul)

    local deformer = TerrainDeformation.new(g_currentMission.terrainRootNode)
    if deformer == nil then return end
    deformer:enableAdditiveDeformationMode()
    deformer:setAdditiveHeightChangeAmount(-depth)
    deformer:addSoftCircleBrush(deformX, deformZ, brushR, nxClamp(CFG.deformHardness, 0.05, 0.98), 1.0, TerrainDeformation.NO_TERRAIN_BRUSH)

    local q = g_currentMission.terrainDeformationQueue
    if q ~= nil and q.queueJob ~= nil then
        local ok = pcall(function() q:queueJob(deformer, false, "nxOnDeformDone", NXRealisticWheelPhysics, nil) end)
        if not ok then
            ok = pcall(function() q:queueJob(deformer, "nxOnDeformDone", NXRealisticWheelPhysics, nil, false) end)
        end
        if not ok then
            deformer:apply(false, "nxOnDeformDone", NXRealisticWheelPhysics, nil)
            deformer:delete()
        end
    else
        deformer:apply(false, "nxOnDeformDone", NXRealisticWheelPhysics, nil)
        deformer:delete()
    end
end

function NXRealisticWheelPhysics.nxOnDeformDone(self, state, numDeforms, msg) end

local function nxApplyDeformSuspension(wp, onField, slip, dt)
    if wp == nil then return end
    local st = nxGetWheelState(wp)
    local dtSec = (dt or 16) / 1000

    local target = (onField and slip >= CFG.deformSlipMin) and 1.0 or 0.0
    if target > st.deformBlend then
        st.deformBlend = math.min(st.deformBlend + CFG.deformSusSpeedIn * dtSec, target)
    else
        st.deformBlend = math.max(st.deformBlend - CFG.deformSusSpeedOut * dtSec, target)
    end

    local physics = wp.physics or wp
    if wp.wheel ~= nil and wp.wheel.physics ~= nil then physics = wp.wheel.physics end

    if CFG.deformDisableDisplacement then
        local shouldDisable = st.deformBlend > 0.05
        if shouldDisable and not st.displacementDisabled then
            if physics.setDisplacementCollisionEnabled ~= nil then
                physics:setDisplacementCollisionEnabled(false)
                st.displacementDisabled = true
            elseif type(physics.displacementCollisionEnabled) == "boolean" then
                physics.displacementCollisionEnabled = false
                st.displacementDisabled = true
            end
        elseif not shouldDisable and st.displacementDisabled then
            if physics.setDisplacementCollisionEnabled ~= nil then
                physics:setDisplacementCollisionEnabled(true)
                st.displacementDisabled = false
            elseif type(physics.displacementCollisionEnabled) == "boolean" then
                physics.displacementCollisionEnabled = true
                st.displacementDisabled = false
            end
        end
    end

    if st.deformBlend > 0.01 then
        local damping = nxLerp(1.0, CFG.deformDampingMult, st.deformBlend)
        local spring  = nxLerp(1.0, CFG.deformSpringMult,  st.deformBlend)
        if physics.setSuspensionMultipliers ~= nil then
            physics:setSuspensionMultipliers(spring, damping)
            st.suspensionApplied = true
        elseif wp.suspDamping ~= nil and wp.suspSpring ~= nil then
            if st.origSuspDamping == nil then st.origSuspDamping = wp.suspDamping; st.origSuspSpring = wp.suspSpring end
            wp.suspDamping = st.origSuspDamping * damping
            wp.suspSpring  = st.origSuspSpring  * spring
            st.suspensionApplied = true
        end
    elseif st.suspensionApplied then
        if physics.setSuspensionMultipliers ~= nil then
            physics:setSuspensionMultipliers(1.0, 1.0)
            st.suspensionApplied = false
        elseif st.origSuspDamping ~= nil then
            wp.suspDamping = st.origSuspDamping
            wp.suspSpring  = st.origSuspSpring
            st.suspensionApplied = false
        end
    end
end

local function nxApplyViscousBrake(wp, vehicle, onField, slip, wetness, profile, isFrozen)
    if wp == nil or vehicle == nil then return end
    if not vehicle.isServer then return end
    if not onField or isFrozen or slip < CFG.brakeSlipMin then return end

    local slipOver = slip - CFG.brakeSlipMin
    local force = CFG.brakeBase + CFG.brakeFromSlip * slipOver
    if wetness > CFG.gripMinWetness then
        local t = nxClamp(wetness, 0, 1)
        force = force * nxLerp(1.0, CFG.brakeWetMult, t)
    end

    if profile ~= nil and type(profile.brakeMult) == "number" then
        force = force * profile.brakeMult
    end

    local vehicleBrake = 1.0
    if vehicle.getBrakeForce ~= nil then
        vehicleBrake = vehicle:getBrakeForce() or 1.0
    end

    local ratio = nxClamp(force * CFG.brakeRatio, 0, CFG.brakeMaxRatio)
    local addBrake = vehicleBrake * ratio
    if wp.brakeFactor ~= nil then
        wp.brakeFactor = (wp.brakeFactor or 0) + addBrake
    elseif wp.additionalBrakeForce ~= nil then
        wp.additionalBrakeForce = (wp.additionalBrakeForce or 0) + addBrake
    end
end

local function nxUpdateSlipBoost(wp, onField, slip, wetness)
    local wheel = wp.wheel or wp
    if wheel == nil then return end

    if not onField or slip < CFG.slipBoostMin then
        wheel._nxSlipBoost = 1.0
        return
    end

    local t = nxClamp((slip - CFG.slipBoostMin) / (CFG.slipBoostFull - CFG.slipBoostMin), 0, 1)
    local boost = 1.0 + (CFG.slipBoostMaxMult - 1.0) * t
    if wetness > CFG.gripMinWetness then
        boost = boost * nxLerp(1.0, CFG.slipBoostWetMult, nxClamp(wetness, 0, 1))
    end
    wheel._nxSlipBoost = boost
end

local function nxOnWheelPhysics(wp, dt)
    if wp == nil then return end

    local wheelOn = NXRealisticWheelPhysics.enabled
    local groundOn = NXFieldPhysicsDensity ~= nil and NXFieldPhysicsDensity.enabled
    if not wheelOn and not groundOn then return end

    local vehicle = wp.vehicle
        or (wp.wheel and wp.wheel.vehicle)
        or (wp.owner and (wp.owner.vehicle or wp.owner))
        or wp.object
        or (wp.getVehicle and wp:getVehicle())
    if vehicle == nil then return end

    local speedKmh = nxGetSpeedKmh(vehicle)
    if speedKmh < CFG.minSpeedKmh then return end

    local slip = 0
    if wp.netInfo and wp.netInfo.slip then slip = math.abs(wp.netInfo.slip)
    elseif wp.slip then slip = math.abs(wp.slip)
    end
    if slip > 1.0 then slip = 1.0 end

    local wx, _, wz = 0, 0, 0
    local node = wp.node or wp.repr or wp.driveNode
    if node == nil and wp.wheel ~= nil then node = wp.wheel.node or wp.wheel.repr or wp.wheel.driveNode end
    if node ~= nil and node ~= 0 then
        wx, _, wz = getWorldTranslation(node)
    elseif wp.positionX ~= nil then
        wx, wz = wp.positionX, wp.positionZ
    elseif vehicle.rootNode ~= nil then
        wx, _, wz = getWorldTranslation(vehicle.rootNode)
    end

    local profile   = nxResolveSurfaceProfile(wp, wx, wz)
    local onField   = profile ~= nil
    local isWater   = profile ~= nil and profile.source == "water"
    local wetness   = nxGetWetness()
    local tempC     = nxGetAirTempC()
    local isFrozen  = tempC <= NXRealisticWheelPhysics.FREEZE_HARD_C
    local isRaining = nxGetIsRaining()

    if wheelOn then
        nxApplyGripReduction(wp, onField, wetness, profile, isFrozen, isRaining, tempC)
        nxApplyDeformSuspension(wp, onField and not isFrozen, slip, dt)
        nxApplyViscousBrake(wp, vehicle, onField, slip, wetness, profile, isFrozen)
        nxUpdateSlipBoost(wp, onField and not isFrozen, slip, wetness)
        nxUpdateSinkMeter(vehicle, onField and not isFrozen, slip, wetness, speedKmh)
        nxApplyEngineBog(vehicle, speedKmh)
        nxApplyBodyTint(vehicle, wx, wz, wetness, tempC, profile)
    end

    -- Speed cap latches motor:setSpeedLimit, so it must run even when wheel physics is
    -- toggled off — the function self-releases any cap it previously applied.
    nxApplySpeedCap(vehicle, speedKmh)

    if groundOn then
        nxApplyWheelSink(wp, vehicle, onField and not isFrozen, slip, dt, profile)
        nxApplySlipDeformation(wp, vehicle, onField and not isWater, slip, wetness, wx, wz, speedKmh, profile, isFrozen)
    end

    if not onField or slip < CFG.deformSlipMin then
        deformAccum[wp] = nil
    end
end

local function nxTryPaint(wp, vehicle, slip)
    if not vehicle.isServer or slip <= 0.20 then return end
    local wheel = wp.wheel
    if wheel == nil or g_farmlandManager == nil then return end

    local node = wheel.repr or wheel.node or wheel.driveNode
    if node == nil or node == 0 then return end

    local wx, _, wz = getWorldTranslation(node)
    local farmland = g_farmlandManager:getFarmlandAtWorldPosition(wx, wz)
    if farmland == nil then return end

    local effectiveSlip = slip * nxGetDiffSlipFactor(vehicle)
    local th = nxEffectiveThreshold(vehicle) * (nxDetectTireType(wp).slipThresholdMult or 1.0)
    if effectiveSlip <= th then return end

    local vtp = nxGetVTPDamageFactor(vehicle)
    if vtp <= 0.0 then return end
    local adjustedTh = th + (1.0 - vtp) * (1.0 - th)
    if effectiveSlip <= adjustedTh then return end

    nxPaintCultivated(wheel)
end

local function nxInstallHook()
    if WheelPhysics == nil or WheelPhysics.serverUpdate == nil then
        print("[FS25_FarmKit] RealisticWheelPhysics: WheelPhysics.serverUpdate not available")
        return false
    end

    WheelPhysics.serverUpdate = Utils.appendedFunction(WheelPhysics.serverUpdate, function(self, dt, currentUpdateIndex, groundWetness)
        if self == nil or self.vehicle == nil then return end

        local wheelOn = NXRealisticWheelPhysics.enabled
        local groundOn = NXFieldPhysicsDensity ~= nil and NXFieldPhysicsDensity.enabled
        if not wheelOn and not groundOn then return end

        local slip = 0
        if self.netInfo and self.netInfo.slip then slip = math.abs(self.netInfo.slip)
        elseif self.slip then slip = math.abs(self.slip) end

        pcall(nxOnWheelPhysics, self, dt)
        if groundOn and slip > 0.20 then pcall(nxTryPaint, self, self.vehicle, slip) end

        local cv = nil
        if g_currentMission ~= nil and g_currentMission.controlledVehicle ~= nil then
            cv = g_currentMission.controlledVehicle
        elseif NXFarmKitHUD ~= nil and NXFarmKitHUD.controlledVehicle ~= nil then
            cv = NXFarmKitHUD.controlledVehicle
        elseif g_localPlayer ~= nil and g_localPlayer.controlledVehicle ~= nil then
            cv = g_localPlayer.controlledVehicle
        elseif g_currentMission ~= nil and g_currentMission.hud ~= nil and g_currentMission.hud.controlledVehicle ~= nil then
            cv = g_currentMission.hud.controlledVehicle
        end

        if cv ~= nil then
            local vehicle = self.vehicle
            local vehRoot = vehicle
            if vehicle.getRootVehicle ~= nil then vehRoot = vehicle:getRootVehicle() or vehicle end
            local cvRoot = cv
            if cv.getRootVehicle ~= nil then cvRoot = cv:getRootVehicle() or cv end

            if (vehRoot == cvRoot) or (vehicle == cv) then
                if slip > currentMaxSlip then currentMaxSlip = slip end
            end
        end
    end)

    FSBaseMission.update = Utils.appendedFunction(FSBaseMission.update, function(self, dt)
        local cv = nil
        if g_currentMission ~= nil and g_currentMission.controlledVehicle ~= nil then
            cv = g_currentMission.controlledVehicle
        elseif NXFarmKitHUD ~= nil and NXFarmKitHUD.controlledVehicle ~= nil then
            cv = NXFarmKitHUD.controlledVehicle
        elseif g_localPlayer ~= nil and g_localPlayer.controlledVehicle ~= nil then
            cv = g_localPlayer.controlledVehicle
        end
        if cv == nil then
            NXRealisticWheelPhysics.displaySlip = 0
            frameMaxSlip = 0
            currentMaxSlip = 0
            return
        end

        if currentMaxSlip > 0 then
            frameMaxSlip = currentMaxSlip
            currentMaxSlip = 0
        end

        if frameMaxSlip > NXRealisticWheelPhysics.displaySlip then
            NXRealisticWheelPhysics.displaySlip = frameMaxSlip
        else
            local decay = 1.0 - math.min(1.0, (dt or 16) / 1000 * 2.5)
            NXRealisticWheelPhysics.displaySlip = NXRealisticWheelPhysics.displaySlip * decay
            if NXRealisticWheelPhysics.displaySlip < 0.005 then NXRealisticWheelPhysics.displaySlip = 0 end
        end
    end)

    return true
end

if not rawget(_G, "_NXRealisticWheelPhysics_bootstrapped") then
    _G._NXRealisticWheelPhysics_bootstrapped = true
    nxInstallHook()
end
