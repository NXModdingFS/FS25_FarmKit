NXCropDamage = NXCropDamage or {}
NXCropDamage.enabled = true

-- Replaces the all-or-nothing wheel crop destruction with a speed-driven model.
-- Every time the game is about to flatten crop under a wheel, we decide whether that
-- patch actually goes down. Each ground cell carries a fixed "toughness" value, so the
-- same speed over the same spot always gives the same answer: crawling back and forth
-- does not slowly erase the crop, and the damage that does happen is patchy, not a
-- solid stripe. Care (row-crop) wheels never reach this: the base game already skips them.

local CREEP_KMH      = 5.0    -- at or below: crop always survives
local FULL_KMH       = 40.0   -- at or above: the curve tops out
local CURVE_POWER    = 1.6    -- >1 keeps low working speeds gentle, bites hard in transit
local MAX_CHANCE     = 0.97

local CELL_SIZE      = 0.5    -- metres per ground cell for the toughness pattern
local REF_WIDTH      = 0.50   -- tyre contact width that counts as "normal"

local STEER_MAX_MULT = 0.50   -- extra when fully steered (tyres scrub sideways)
local STEER_FULL_RAD = 0.60
local WET_MAX_MULT   = 0.35   -- extra on fully wet ground
local MASS_REF_T     = 10.0
local MASS_EXP       = 0.25

local function nxClamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function nxSmooth(t)
    t = nxClamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

-- Integer-mixing hash kept inside double precision (no bit ops in Lua 5.1).
local function nxCellToughness(x, z)
    local cx = math.floor(x / CELL_SIZE)
    local cz = math.floor(z / CELL_SIZE)
    local h = (cx * 92837111 + cz * 689287499 + 40503) % 1048573
    h = (h * 1103515245 + 12345) % 2147483648
    h = (h * 1103515245 + 12345) % 2147483648
    return h / 2147483648
end

local function nxSpeedChance(kmh)
    if kmh <= CREEP_KMH then return 0 end
    local t = nxSmooth((kmh - CREEP_KMH) / (FULL_KMH - CREEP_KMH))
    return t ^ CURVE_POWER
end

local function nxGroundWetness()
    local env = g_currentMission ~= nil and g_currentMission.environment or nil
    local weather = env ~= nil and env.weather or nil
    if weather ~= nil and weather.getGroundWetness ~= nil then
        local ok, w = pcall(weather.getGroundWetness, weather)
        if ok and type(w) == "number" then return nxClamp(w, 0, 1) end
    end
    return 0
end

local function nxVehicleSpeed(vehicle)
    if vehicle.getLastSpeed ~= nil then
        local ok, v = pcall(vehicle.getLastSpeed, vehicle)
        if ok and type(v) == "number" then return math.abs(v) end
    end
    if type(vehicle.lastSpeedReal) == "number" then return math.abs(vehicle.lastSpeedReal) * 3600 end
    return 0
end

local function nxMassFactor(vehicle)
    if vehicle.getTotalMass == nil then return 1 end
    local ok, m = pcall(vehicle.getTotalMass, vehicle)
    if not ok or type(m) ~= "number" or m <= 0 then return 1 end
    return nxClamp((m / MASS_REF_T) ^ MASS_EXP, 0.75, 1.35)
end

function NXCropDamage.getDestroyChance(wd, x0, z0, x1, z1)
    local wheel = wd.wheel
    local vehicle = wheel ~= nil and wheel.vehicle or nil
    if vehicle == nil then return 1 end

    local chance = nxSpeedChance(nxVehicleSpeed(vehicle))
    if chance <= 0 then return 0 end

    -- footprint: the first triangle edge spans the destruction node's width
    local width = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
    chance = chance * nxClamp(width / REF_WIDTH, 0.4, 1.8)

    local steer = math.abs(wheel.physics ~= nil and wheel.physics.steeringAngle or 0)
    chance = chance * (1 + STEER_MAX_MULT * nxClamp(steer / STEER_FULL_RAD, 0, 1))

    chance = chance * (1 + WET_MAX_MULT * nxGroundWetness())
    chance = chance * nxMassFactor(vehicle)

    return nxClamp(chance, 0, MAX_CHANCE)
end

-- Shared with Ground Physics grass flattening: does this wheel patch go down right now?
function NXCropDamage.patchGoesDown(wd, x0, z0, x1, z1, x2, z2)
    local ok, chance = pcall(NXCropDamage.getDestroyChance, wd, x0, z0, x1, z1)
    if not ok then return true end
    return nxCellToughness((x0 + x1 + x2) / 3, (z0 + z1 + z2) / 3) < chance
end

function NXCropDamage.destroyFruitArea(wd, superFunc, x0, z0, x1, z1, x2, z2, ...)
    if NXCropDamage.enabled and not NXCropDamage.patchGoesDown(wd, x0, z0, x1, z1, x2, z2) then
        return nil
    end
    return superFunc(wd, x0, z0, x1, z1, x2, z2, ...)
end

if not rawget(_G, "_NXCropDamage_bootstrapped") then
    _G._NXCropDamage_bootstrapped = true
    if WheelDestruction ~= nil and WheelDestruction.destroyFruitArea ~= nil then
        WheelDestruction.destroyFruitArea = Utils.overwrittenFunction(WheelDestruction.destroyFruitArea, NXCropDamage.destroyFruitArea)
    else
        Logging.warning("[FarmKit] WheelDestruction.destroyFruitArea not found - speed-based crop damage disabled")
    end
end
