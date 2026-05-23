NXDustMechanics = NXDustMechanics or {}

NXDustMechanics.MIN_SPEED_KMH      = 0.2
NXDustMechanics.AREA_TOLERANCE_MS  = 1400
NXDustMechanics.FADE_TAIL_MS       = 4000
NXDustMechanics.LOG_PREFIX         = "[FS25_FarmKit] DustMechanics: "

NXDustMechanics.TYPE_MULT = {
    BALER = 1.5, CLEANING   = 1.4, COMBINE    = 1.5, CULTIVATOR = 2.0,
    CUTTER = 1.2, MOWER     = 1.2, MULCHER    = 1.5, PLOW       = 2.0,
    ROLLER = 1.5, SOWING    = 2.0, WEEDER     = 1.5, WINDROW    = 1.2,
    WHEELS = 2.5
}

NXDustMechanics.FADE_TAIL_MS_BY_TOOL = {
    COMBINE    = 8000,
    PLOW       = 7000,
    CULTIVATOR = 7000,
    MULCHER    = 5000,
    CLEANING   = 5000,
    BALER      = 4000,
    ROLLER     = 4000,
    SOWING     = 3000,
    MOWER      = 2500,
    WEEDER     = 2500,
    CUTTER     = 2000,
    WINDROW    = 1500,
    WHEELS     = 1500
}

NXDustMechanics.dustEnabled    = true
NXDustMechanics.dustMultiplier = 2.0

NXDustMechanics.hooksAttached  = false

local function nxSafe(fn)
    local ok, result = pcall(fn)
    if ok then return result end
    return nil
end

local function nxClamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function nxClosestIndex(list, target)
    local best, bestDiff = 1, math.huge
    for i, v in ipairs(list) do
        local d = math.abs(v - target)
        if d < bestDiff then bestDiff, best = d, i end
    end
    return best
end

local function nxAssignFocusIds(elem)
    if elem == nil then return end
    elem.focusId = FocusManager:serveAutoFocusId()
    for _, child in pairs(elem.elements or {}) do
        nxAssignFocusIds(child)
    end
end

function NXDustMechanics.getWeatherFactor()
    local weather = g_currentMission and g_currentMission.environment and g_currentMission.environment.weather
    if weather == nil then return 1.25 end

    local since = nxSafe(function() return weather:getTimeSinceLastRain() end) or 120
    if since <  10 then return 0.15 end
    if since <  30 then return 0.55 end
    if since < 120 then return 0.95 end
    return 1.25
end

function NXDustMechanics.getEffectiveMultiplier(toolName, isWheelSystem)
    if not NXDustMechanics.dustEnabled then return 1.0 end
    local typeMult  = NXDustMechanics.TYPE_MULT[toolName] or 1.0
    local wheelMult = isWheelSystem and 1.2 or 1.0
    local rain      = NXDustMechanics.getWeatherFactor()
    return nxClamp(NXDustMechanics.dustMultiplier * typeMult * rain * wheelMult, 0.1, 20.0)
end

function NXDustMechanics.getVehicleSpeed(vehicle)
    if vehicle == nil or vehicle.getLastSpeed == nil then return 0 end
    return nxSafe(function() return vehicle:getLastSpeed(true) end) or 0
end

function NXDustMechanics.isVehicleOnField(vehicle)
    if vehicle == nil or vehicle.getIsOnField == nil then return true end
    local r = nxSafe(function() return vehicle:getIsOnField() end)
    return r == nil or r == true
end

function NXDustMechanics.isVehicleTurnedOn(vehicle)
    if vehicle == nil then return false end
    if vehicle.spec_turnOnVehicle == nil then return true end
    return nxSafe(function() return vehicle:getIsTurnedOn() end) == true
end

function NXDustMechanics.isVehicleLowered(vehicle)
    if vehicle == nil or vehicle.getIsLowered == nil then return true end
    local r = nxSafe(function() return vehicle:getIsLowered(true) end)
    return r == nil or r == true
end

function NXDustMechanics.hasRecentSpecActivity(spec)
    if spec == nil or spec.lastAreaBiggerZeroTime == nil or spec.lastAreaBiggerZeroTime <= 0 then
        return false
    end
    return (g_time - spec.lastAreaBiggerZeroTime) <= NXDustMechanics.AREA_TOLERANCE_MS
end

local NX_RECENT_SPECS = {
    "workArea", "plow", "cultivator", "subsoiler", "discHarrow", "powerHarrow",
    "spader", "stubbleCultivator", "roller", "sowingMachine", "weeder",
    "mulcher", "windrower", "mower", "baler", "combine", "cutter"
}

function NXDustMechanics.hasAnyRecentActivity(vehicle)
    if vehicle == nil then return false end
    for _, name in ipairs(NX_RECENT_SPECS) do
        if NXDustMechanics.hasRecentSpecActivity(vehicle["spec_" .. name]) then
            return true
        end
    end
    return false
end

function NXDustMechanics.canVehicleWorkGround(vehicle, requireLowered)
    if not NXDustMechanics.isVehicleTurnedOn(vehicle) then return false end
    if not NXDustMechanics.isVehicleOnField(vehicle)  then return false end
    if requireLowered and not NXDustMechanics.isVehicleLowered(vehicle) then return false end
    if NXDustMechanics.getVehicleSpeed(vehicle) < NXDustMechanics.MIN_SPEED_KMH then return false end

    local doGround = vehicle.getDoGroundManipulation ~= nil
        and (nxSafe(function() return vehicle:getDoGroundManipulation() end) == true)
        or false

    return doGround or NXDustMechanics.hasAnyRecentActivity(vehicle)
end

local function nxGetFadeTailMs(toolName)
    local byTool = NXDustMechanics.FADE_TAIL_MS_BY_TOOL
    if type(byTool) == "table" and toolName ~= nil then
        local v = byTool[toolName]
        if type(v) == "number" then return v end
    end
    return NXDustMechanics.FADE_TAIL_MS or 0
end

local function nxCaptureOriginals(ps)
    if ps.nxOrigEmit == nil then
        ps.nxOrigEmit = ps.emitCountScale or 1.0
    end
    if ps.nxOrigLife == nil then
        local life = 1000
        if ps.geometry ~= nil and getParticleSystemLifespan ~= nil then
            life = nxSafe(function() return getParticleSystemLifespan(ps.geometry) end) or 1000
        end
        ps.nxOrigLife = life
    end
end

function NXDustMechanics.applyToParticleSystem(ps, toolName, isWheelSystem, shouldEmit)
    if ps == nil then return end
    nxCaptureOriginals(ps)

    local now = g_time or 0
    local fadeMs = nxGetFadeTailMs(toolName)
    local emit, life
    local forceEmittingOn = false
    local releaseForcedEmit = false

    if NXDustMechanics.dustEnabled and shouldEmit then
        local m = NXDustMechanics.getEffectiveMultiplier(toolName, isWheelSystem)
        emit = nxClamp(ps.nxOrigEmit * m, 0.05, 30.0)
        life = math.max(80, math.floor(ps.nxOrigLife * nxClamp(0.9 + m * 0.35, 0.25, 4.0)))
        ps.nxBoostedEmit = emit
        ps.nxBoostedLife = life
        ps.nxFadeUntil   = now + fadeMs
    elseif NXDustMechanics.dustEnabled and fadeMs > 0
        and ps.nxFadeUntil ~= nil and now < ps.nxFadeUntil
        and ps.nxBoostedEmit ~= nil then
        local t = (ps.nxFadeUntil - now) / fadeMs
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
        -- ramp emission rate toward 0 so the fade actually stops new particles
        emit = nxClamp(ps.nxBoostedEmit * t, 0.0, 30.0)
        -- ramp lifespan from boost back to orig over the fade window so
        -- in-flight particles don't get truncated when the window expires
        local boostedLife = ps.nxBoostedLife or ps.nxOrigLife
        life = math.max(80, math.floor(ps.nxOrigLife + (boostedLife - ps.nxOrigLife) * t))
        forceEmittingOn  = true
        ps.nxForcedEmit  = true
    else
        if ps.nxForcedEmit then
            releaseForcedEmit = true
            ps.nxForcedEmit   = nil
        end
        emit = ps.nxOrigEmit
        life = ps.nxOrigLife
        ps.nxFadeUntil = nil
    end

    if ParticleUtil ~= nil and ParticleUtil.setEmitCountScale ~= nil and ps.nxLastEmit ~= emit then
        ps.nxLastEmit = emit
        ParticleUtil.setEmitCountScale(ps, emit)
    end
    if ParticleUtil ~= nil and ParticleUtil.setParticleLifespan ~= nil and ps.nxLastLife ~= life then
        ps.nxLastLife = life
        ParticleUtil.setParticleLifespan(ps, life)
    end
    if ParticleUtil ~= nil and ParticleUtil.setEmittingState ~= nil then
        if forceEmittingOn then
            ParticleUtil.setEmittingState(ps, true)
        elseif releaseForcedEmit then
            ParticleUtil.setEmittingState(ps, false)
        end
    end
end

function NXDustMechanics.walkWorkParticles(vehicle, toolName, active)
    local spec = vehicle.spec_workParticles
    if spec == nil or spec.particles == nil then return end

    local speed   = NXDustMechanics.getVehicleSpeed(vehicle)
    local onField = NXDustMechanics.isVehicleOnField(vehicle)
    local doGround = vehicle.getDoGroundManipulation ~= nil
        and (nxSafe(function() return vehicle:getDoGroundManipulation() end) == true)
        or false
    local baseActive = active and doGround and onField and speed > NXDustMechanics.MIN_SPEED_KMH

    for _, container in pairs(spec.particles) do
        if container ~= nil and container.mappings ~= nil then
            for _, mapping in ipairs(container.mappings) do
                if mapping ~= nil and mapping.particleSystem ~= nil then
                    local on = baseActive
                    if mapping.groundRefNode and mapping.groundRefNode.isActive then
                        on = on and ((mapping.speedThreshold or 0) < speed)
                    end
                    if mapping.movingDirection then
                        on = on and (mapping.movingDirection == vehicle.movingDirection)
                    end
                    NXDustMechanics.applyToParticleSystem(mapping.particleSystem, toolName, false, on)
                end
            end
        end
    end
end

function NXDustMechanics.walkEffects(effects, toolName, active)
    if type(effects) ~= "table" then return end
    for _, e in ipairs(effects) do
        if e ~= nil and e.particleSystem ~= nil then
            NXDustMechanics.applyToParticleSystem(e.particleSystem, toolName, false, active)
        end
    end
end

function NXDustMechanics.walkParentEffects(parents, toolName, active)
    if type(parents) ~= "table" then return end
    for _, p in ipairs(parents) do
        if p ~= nil then
            local on = active and (p.isActive == nil or p.isActive == true)
            NXDustMechanics.walkEffects(p.effects, toolName, on)
        end
    end
end

function NXDustMechanics.walkWheels(vehicle, active)
    if vehicle == nil or vehicle.spec_wheels == nil or vehicle.spec_wheels.wheels == nil then return end
    for _, wheel in pairs(vehicle.spec_wheels.wheels) do
        if wheel.driveGroundParticleSystems ~= nil then
            for _, ps in ipairs(wheel.driveGroundParticleSystems) do
                NXDustMechanics.applyToParticleSystem(ps, "WHEELS", true, active)
            end
        end
    end
end

local function workParticleHandler(toolName, matchFn)
    return {
        tool   = toolName,
        class  = "WorkParticles",
        method = "onUpdateTick",
        mode   = "overwrite",
        check  = matchFn,
        active = function(v) return NXDustMechanics.canVehicleWorkGround(v, true) end,
        run    = function(v, a) NXDustMechanics.walkWorkParticles(v, toolName, a) end
    }
end

NXDustMechanics.HANDLERS = {
    workParticleHandler("PLOW",       function(v) return v.spec_plow ~= nil end),
    workParticleHandler("CULTIVATOR", function(v)
        return v.spec_cultivator ~= nil or v.spec_subsoiler ~= nil
            or v.spec_discHarrow ~= nil or v.spec_powerHarrow ~= nil
            or v.spec_spader     ~= nil or v.spec_stubbleCultivator ~= nil
    end),
    workParticleHandler("SOWING", function(v) return v.spec_sowingMachine ~= nil end),
    workParticleHandler("ROLLER", function(v) return v.spec_roller        ~= nil end),
    workParticleHandler("WEEDER", function(v) return v.spec_weeder        ~= nil end),

    {
        tool = "MOWER", class = "Mower", method = "onStartWorkAreaProcessing", mode = "overwrite",
        check  = function(v) return v.spec_mower ~= nil end,
        active = function(v)
            return v.spec_mower.isWorking == true and NXDustMechanics.canVehicleWorkGround(v, false)
        end,
        run = function(v, a) NXDustMechanics.walkParentEffects(v.spec_mower.dropEffects, "MOWER", a) end
    },
    {
        tool = "CUTTER", class = "Cutter", method = "onUpdateTick", mode = "overwrite",
        check  = function(v) return v.spec_cutter ~= nil end,
        active = function(v)
            return v.spec_cutter.isWorking == true and NXDustMechanics.canVehicleWorkGround(v, false)
        end,
        run = function(v, a) NXDustMechanics.walkEffects(v.spec_cutter.cutterEffects, "CUTTER", a) end
    },
    {
        tool = "MULCHER", class = "Mulcher", method = "onUpdateTick", mode = "overwrite",
        check  = function(v) return v.spec_mulcher ~= nil end,
        active = function(v)
            return v.spec_mulcher.isWorking == true and NXDustMechanics.canVehicleWorkGround(v, true)
        end,
        run = function(v, a) NXDustMechanics.walkParentEffects(v.spec_mulcher.effects, "MULCHER", a) end
    },
    {
        tool = "WINDROW", class = "Windrower", method = "onUpdateTick", mode = "overwrite",
        check  = function(v) return v.spec_windrower ~= nil end,
        active = function(v)
            return v.spec_windrower.isWorking == true and NXDustMechanics.canVehicleWorkGround(v, false)
        end,
        run = function(v, a) NXDustMechanics.walkParentEffects(v.spec_windrower.effects, "WINDROW", a) end
    },
    {
        tool = "BALER", class = "Baler", method = "onUpdateTick", mode = "overwrite",
        check  = function(v) return v.spec_baler ~= nil end,
        active = function(v)
            local s = v.spec_baler
            return NXDustMechanics.canVehicleWorkGround(v, true)
                and (NXDustMechanics.hasRecentSpecActivity(s) or NXDustMechanics.hasAnyRecentActivity(v))
        end,
        run = function(v, a) NXDustMechanics.walkEffects(v.spec_baler.fillEffects, "BALER", a) end
    },
    {
        tool = "COMBINE", class = "Combine", method = "onUpdateTick", mode = "overwrite",
        check  = function(v) return v.spec_combine ~= nil end,
        active = function(v)
            if not NXDustMechanics.isVehicleTurnedOn(v) or not NXDustMechanics.isVehicleOnField(v) then
                return false
            end
            local s = v.spec_combine
            return s.chopperPSenabled == true or s.strawPSenabled == true
                or NXDustMechanics.hasAnyRecentActivity(v)
        end,
        run = function(v, a)
            local s = v.spec_combine
            NXDustMechanics.walkEffects(s.chopperEffects, "COMBINE", a and s.chopperPSenabled == true)
            NXDustMechanics.walkEffects(s.strawEffects,   "COMBINE", a and s.strawPSenabled   == true)
        end
    },
    {
        tool = "CLEANING", class = "Combine", method = "onUpdateTick", mode = "overwrite",
        check  = function(v) return v.spec_combine ~= nil end,
        active = function(v)
            return NXDustMechanics.isVehicleTurnedOn(v) and NXDustMechanics.isVehicleOnField(v)
        end,
        run = function(v, a)
            local s = v.spec_combine
            if s.fillEffects == nil then return end
            for _, fe in ipairs(s.fillEffects) do
                if fe ~= nil and fe.particleType == "CLEANING_DUST" then
                    NXDustMechanics.applyToParticleSystem(fe.particleSystem, "CLEANING", false, a)
                end
            end
        end
    },
    {
        tool = "WHEELS", class = "Wheels", method = "onUpdateTick", mode = "append",
        check  = function(v) return v.spec_wheels ~= nil end,
        active = function(v)
            return NXDustMechanics.getVehicleSpeed(v) > NXDustMechanics.MIN_SPEED_KMH
                and NXDustMechanics.isVehicleOnField(v)
        end,
        run = function(v, a) NXDustMechanics.walkWheels(v, a) end
    }
}

function NXDustMechanics.attachHooks()
    if NXDustMechanics.hooksAttached then return end

    local groups = {}
    for _, h in ipairs(NXDustMechanics.HANDLERS) do
        local key = h.class .. "." .. h.method .. "." .. h.mode
        groups[key] = groups[key] or { class = h.class, method = h.method, mode = h.mode, list = {} }
        table.insert(groups[key].list, h)
    end

    for _, group in pairs(groups) do
        local cls = _G[group.class]
        if cls ~= nil and cls[group.method] ~= nil then
            local handlerList = group.list
            local function dispatch(self, ...)
                for _, h in ipairs(handlerList) do
                    if h.check(self, ...) == true then
                        h.run(self, h.active(self, ...) == true, ...)
                    end
                end
            end

            if group.mode == "append" then
                cls[group.method] = Utils.appendedFunction(cls[group.method], dispatch)
            else
                cls[group.method] = Utils.overwrittenFunction(cls[group.method], function(self, superFunc, ...)
                    if superFunc ~= nil then superFunc(self, ...) end
                    dispatch(self, ...)
                end)
            end
        end
    end

    NXDustMechanics.hooksAttached = true
end

function NXDustMechanics:loadMap()
    if g_currentMission ~= nil and g_currentMission:getIsClient() then
        NXDustMechanics.attachHooks()
    end
end

function NXDustMechanics:deleteMap()
end

addModEventListener(NXDustMechanics)
