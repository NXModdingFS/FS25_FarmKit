NXRealisticWheelPhysics = NXRealisticWheelPhysics or {}
NXRealisticWheelPhysics.enabled = true

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

local function nxGetWetness()
    if g_currentMission == nil then return 0 end
    local weather = g_currentMission.environment and g_currentMission.environment.weather
    if weather == nil or weather.getGroundWetness == nil then return 0 end
    return nxClamp(weather:getGroundWetness() or 0, 0, 1)
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

local function nxApplyGripReduction(wp, onField, wetness)
    if wp == nil then return end
    local st = nxGetWheelState(wp)

    if st.gripBase == nil then
        st.gripBase = {
            maxLatFriction  = wp.maxLatFriction,
            maxLongFriction = wp.maxLongFriction,
            frictionScale   = wp.frictionScale
        }
    end

    if not onField then
        if st.gripBase.maxLatFriction  ~= nil then wp.maxLatFriction  = st.gripBase.maxLatFriction  end
        if st.gripBase.maxLongFriction ~= nil then wp.maxLongFriction = st.gripBase.maxLongFriction end
        if st.gripBase.frictionScale   ~= nil then wp.frictionScale   = st.gripBase.frictionScale   end
        return
    end

    local tire = nxDetectTireType(wp)
    local dryF = nxClamp(CFG.gripDryFieldFactor * tire.gripMult, 0.5, 1.0)
    local wetF = nxClamp(CFG.gripWetFieldFactor * tire.gripMult, 0.4, 1.0)

    local scale
    if wetness < CFG.gripMinWetness then
        scale = dryF
    else
        local t = nxClamp((wetness - CFG.gripMinWetness) / (1.0 - CFG.gripMinWetness), 0, 1)
        scale = nxLerp(dryF, wetF, t)
    end

    if st.gripBase.maxLatFriction  ~= nil and type(wp.maxLatFriction)  == "number" then wp.maxLatFriction  = st.gripBase.maxLatFriction  * scale end
    if st.gripBase.maxLongFriction ~= nil and type(wp.maxLongFriction) == "number" then wp.maxLongFriction = st.gripBase.maxLongFriction * scale end
    if st.gripBase.frictionScale   ~= nil and type(wp.frictionScale)   == "number" then wp.frictionScale   = st.gripBase.frictionScale   * scale end
end

local function nxApplyWheelSink(wp, vehicle, onField, slip, dt)
    if wp == nil then return end
    local st = nxGetWheelState(wp)

    if st.origRadius == nil then st.origRadius = wp.radiusOriginal or wp.radius end

    local dtSec = dt / 1000
    local target = 0
    if onField and slip > CFG.sinkSlipMin then
        local t = nxClamp((slip - CFG.sinkSlipMin) / (CFG.sinkSlipFull - CFG.sinkSlipMin), 0, 1)
        target = t * nxDetectTireType(wp).sinkMult
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

local function nxApplySlipDeformation(wp, vehicle, onField, slip, wetness, wx, wz, speedKmh)
    if wp == nil or vehicle == nil or not vehicle.isServer then return end
    if not onField then return end
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

local function nxApplyViscousBrake(wp, vehicle, onField, slip, wetness)
    if wp == nil or vehicle == nil then return end
    if not vehicle.isServer then return end
    if not onField or slip < CFG.brakeSlipMin then return end

    local slipOver = slip - CFG.brakeSlipMin
    local force = CFG.brakeBase + CFG.brakeFromSlip * slipOver
    if wetness > CFG.gripMinWetness then
        local t = nxClamp(wetness, 0, 1)
        force = force * nxLerp(1.0, CFG.brakeWetMult, t)
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
    if not NXRealisticWheelPhysics.enabled then return end
    if wp == nil then return end

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

    local onField = nxIsOnField(wx, wz)
    local wetness = nxGetWetness()

    nxApplyGripReduction(wp, onField, wetness)
    nxApplyWheelSink(wp, vehicle, onField, slip, dt)
    nxApplySlipDeformation(wp, vehicle, onField, slip, wetness, wx, wz, speedKmh)
    nxApplyDeformSuspension(wp, onField, slip, dt)
    nxApplyViscousBrake(wp, vehicle, onField, slip, wetness)
    nxUpdateSlipBoost(wp, onField, slip, wetness)

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
        if not NXRealisticWheelPhysics.enabled then return end

        local slip = 0
        if self.netInfo and self.netInfo.slip then slip = math.abs(self.netInfo.slip)
        elseif self.slip then slip = math.abs(self.slip) end

        pcall(nxOnWheelPhysics, self, dt)
        if slip > 0.20 then pcall(nxTryPaint, self, self.vehicle, slip) end

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

    print("[FS25_FarmKit] RealisticWheelPhysics: hooks installed")
    return true
end

if not rawget(_G, "_NXRealisticWheelPhysics_bootstrapped") then
    _G._NXRealisticWheelPhysics_bootstrapped = true
    nxInstallHook()
end
