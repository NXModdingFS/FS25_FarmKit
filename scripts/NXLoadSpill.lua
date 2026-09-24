NXLoadSpill = NXLoadSpill or {}
NXLoadSpill.enabled   = true
NXLoadSpill.installed = false

local BLOCKED_TYPE_TOKENS = {
    "shovel", "fork", "telehandler", "skidsteer",
    "car", "truck", "utility", "rtv",
    "baler", "wrapper", "mower", "mulcher",
}

local PERMITTED_FILL_GROUPS = {
    GRAIN = true, SEEDS = true, BULK = true,
    STRAW = true, HAY = true, CHAFF = true, FORAGE = true,
    SILAGE = true, ROOTCROP = true, WOODCHIPS = true,
    FERTILIZER = true, LIME = true, MINERAL = true, MANURE = true,
}

local PERMITTED_FILL_NAMES = {
    BARLEY = true, WHEAT = true, OAT = true, SORGHUM = true,
    SOYBEAN = true, SUNFLOWER = true, CANOLA = true,
    MAIZE = true, CORN = true, RICE = true, RICELONGGRAIN = true,
    POTATO = true, SUGARBEET = true, SUGARCANE = true,
    CHAFF = true, FORAGE = true,
    FERTILIZER = true, LIME = true, MINERAL_FEED = true,
}

local TICK_BASE_MS    = 175
local TICK_JITTER_MS  = 60

local ANGLE_START   = 0.2618
local ANGLE_FULL    = 2.0944
local COVER_BONUS   = 0.2094
local COVER_BREAK   = 1.1345

local REF_TIP_SPEED   = 22
local FLOW_MIN_MULT   = 0.60
local FLOW_MAX_MULT   = 1.70

local LOSS_TO_GROUND  = 0.72
local FULL_EMPTY_SECS = 28.0

local DEPOSIT_HALF_W  = 0.90
local DEPOSIT_HALF_L  = 2.00
local DEPOSIT_SIDE    = 1.40

local trailerCache = setmetatable({}, { __mode = "k" })
local nodeBackup   = setmetatable({}, { __mode = "k" })

local function nxClamp(v, lo, hi)
    return v < lo and lo or (v > hi and hi or v)
end

local function nxSmooth(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    return t * t * (3 - 2 * t)
end

local function nxLower(s)
    return type(s) == "string" and string.lower(s) or ""
end

local function nxSpeedKmh(vehicle)
    if vehicle.getLastSpeed == nil then return 0 end
    local ok, v = pcall(vehicle.getLastSpeed, vehicle, true)
    if ok and type(v) == "number" then return math.abs(v) end
    return 0
end

local function nxTypeBlocked(vehicle)
    local name = nxLower(vehicle.typeName)
    if name == "" then return false end
    for i = 1, #BLOCKED_TYPE_TOKENS do
        if string.find(name, BLOCKED_TYPE_TOKENS[i], 1, true) then
            return true
        end
    end
    return false
end

local function nxQualifies(vehicle)
    if vehicle == nil or vehicle.isServer ~= true then return false end
    if vehicle.rootNode == nil or vehicle.rootNode == 0 then return false end
    if vehicle.spec_fillUnit == nil then return false end
    local units = vehicle.spec_fillUnit.fillUnits
    if type(units) ~= "table" or #units == 0 then return false end
    if nxTypeBlocked(vehicle) then return false end
    return true
end

local function nxFillPermitted(fillTypeIndex)
    if fillTypeIndex == nil or fillTypeIndex == 0 then return false end
    if g_fillTypeManager == nil then return false end
    local ft = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
    if ft == nil then return false end

    if type(ft.physicalSurfaceMaterialName) == "string" then
        if string.find(ft.physicalSurfaceMaterialName, "liquid", 1, true) then
            return false
        end
    end

    if type(ft.name) == "string" then
        if PERMITTED_FILL_NAMES[string.upper(ft.name)] then return true end
    end

    if type(ft.categoryNames) == "table" then
        local cats = ft.categoryNames
        for i = 1, #cats do
            if PERMITTED_FILL_GROUPS[string.upper(tostring(cats[i]))] then
                return true
            end
        end
    end

    return false
end

local function nxTiltRad(vehicle)
    local _, upY, _ = localDirectionToWorld(vehicle.rootNode, 0, 1, 0)
    return math.acos(nxClamp(upY or 1, -1, 1))
end

local function nxTipSide(vehicle)
    local _, rY, _ = localDirectionToWorld(vehicle.rootNode, 1, 0, 0)
    return (rY or 0) > 0 and -1 or 1
end

local function nxCoverShut(vehicle)
    local spec = vehicle.spec_cover
    if spec == nil then return false end
    if type(spec.state)      == "number" then return spec.state == 0 end
    if type(spec.coverState) == "number" then return spec.coverState == 0 end
    if spec.isOpen           == false    then return true end
    if type(spec.coverAnimation) == "table"
       and type(spec.coverAnimation.animTime) == "number" then
        return spec.coverAnimation.animTime <= 0.001
    end
    return false
end

local function nxForceOpenCover(vehicle)
    if vehicle.setCoverState == nil then return end
    pcall(vehicle.setCoverState, vehicle, 1, false)
end

local function nxSpillIntensity(tilt, coverShut)
    local eff = tilt
    if coverShut and tilt < COVER_BREAK then
        eff = tilt - COVER_BONUS
        if eff < 0 then eff = 0 end
    end
    if eff <= ANGLE_START then return 0 end
    if eff >= ANGLE_FULL  then return 1 end
    return nxSmooth((eff - ANGLE_START) / (ANGLE_FULL - ANGLE_START))
end

local function nxScatter(vehicle, fillTypeIndex, volume, tipSide)
    if volume <= 0 then return end
    if FSDensityMapUtil == nil then return end

    local fn = FSDensityMapUtil.updateFillTypeArea
            or FSDensityMapUtil.updateFillType
    if fn == nil then return end

    local sideX = tipSide * DEPOSIT_SIDE
    local x0, _, z0 = localToWorld(vehicle.rootNode,
        sideX - DEPOSIT_HALF_W, 0, -DEPOSIT_HALF_L)
    local x1, _, z1 = localToWorld(vehicle.rootNode,
        sideX + DEPOSIT_HALF_W, 0, -DEPOSIT_HALF_L)
    local x2, _, z2 = localToWorld(vehicle.rootNode,
        sideX + DEPOSIT_HALF_W, 0,  DEPOSIT_HALF_L)

    pcall(fn, x0, z0, x1, z1, x2, z2, fillTypeIndex)
end

local function nxBleedUnit(vehicle, unitIndex, unit, intensity, dtSec, tipSide)
    if unit == nil then return end
    local capacity = unit.capacity or 0
    local current  = unit.fillLevel or 0
    if capacity <= 0 or current <= 0 then return end

    local fillTypeIndex = unit.fillType
    if not nxFillPermitted(fillTypeIndex) then return end

    local volume = (capacity / FULL_EMPTY_SECS) * intensity * dtSec
    if volume <= 0 then return end
    if volume > current then volume = current end

    if vehicle.addFillUnitFillLevel ~= nil then
        local farmId = (vehicle.getOwnerFarmId and vehicle:getOwnerFarmId())
                       or FarmManager.SPECTATOR_FARM_ID or 0
        local toolType = ToolType ~= nil and ToolType.UNDEFINED or 0
        pcall(vehicle.addFillUnitFillLevel, vehicle, farmId, unitIndex,
              -volume, fillTypeIndex, toolType, nil)
    end

    nxScatter(vehicle, fillTypeIndex, volume * LOSS_TO_GROUND, tipSide)
end

local function nxNodeRestore(node, backup)
    if node == nil or backup == nil then return end
    if backup.maxDistance     ~= nil then node.maxDistance     = backup.maxDistance     end
    if backup.minDistance     ~= nil then node.minDistance     = backup.minDistance     end
    if backup.dischargeWidth  ~= nil then node.dischargeWidth  = backup.dischargeWidth  end
    if backup.dischargeLength ~= nil then node.dischargeLength = backup.dischargeLength end
end

local function nxNodeBackup(vehicle)
    if nodeBackup[vehicle] ~= nil then return nodeBackup[vehicle] end
    local spec = vehicle.spec_dischargeable or vehicle.spec_trailer
    if spec == nil or type(spec.dischargeNodes) ~= "table" then return nil end

    local snap = {}
    local nodes = spec.dischargeNodes
    for i = 1, #nodes do
        local node = nodes[i]
        snap[i] = {
            maxDistance     = node.maxDistance,
            minDistance     = node.minDistance,
            dischargeWidth  = node.dischargeWidth,
            dischargeLength = node.dischargeLength,
        }
    end
    nodeBackup[vehicle] = snap
    return snap
end

local function nxIsTippingNow(vehicle)
    local spec = vehicle.spec_dischargeable or vehicle.spec_trailer
    if spec == nil then return false end
    if type(spec.currentDischargeState) == "number"
       and Dischargeable ~= nil
       and Dischargeable.DISCHARGE_STATE_OFF ~= nil then
        return spec.currentDischargeState ~= Dischargeable.DISCHARGE_STATE_OFF
    end
    if type(spec.isTipping) == "boolean" then return spec.isTipping end
    return false
end

local function nxAdaptFlow(vehicle)
    local spec = vehicle.spec_dischargeable or vehicle.spec_trailer
    if spec == nil or type(spec.dischargeNodes) ~= "table" then return end

    local backup = nxNodeBackup(vehicle)
    if backup == nil then return end

    local nodes = spec.dischargeNodes

    if not nxIsTippingNow(vehicle) then
        for i = 1, #nodes do
            nxNodeRestore(nodes[i], backup[i])
        end
        return
    end

    local t    = nxClamp(nxSpeedKmh(vehicle) / REF_TIP_SPEED, 0, 1)
    local mult = FLOW_MIN_MULT + (FLOW_MAX_MULT - FLOW_MIN_MULT) * nxSmooth(t)

    for i = 1, #nodes do
        local node = nodes[i]
        local d = backup[i]
        if d ~= nil then
            if d.maxDistance     ~= nil then node.maxDistance     = d.maxDistance     * mult end
            if d.dischargeWidth  ~= nil then node.dischargeWidth  = d.dischargeWidth  * mult end
            if d.dischargeLength ~= nil then node.dischargeLength = d.dischargeLength * mult end
        end
    end
end

local function nxPickJitter(vehicle)
    local seed = vehicle.rootNode or 0
    return (seed * 2654435761) % TICK_JITTER_MS
end

local function nxTickTrailer(vehicle)
    local st = trailerCache[vehicle]
    if st == nil then
        st = { dueAt = -1, jitter = nxPickJitter(vehicle), lastAt = -1 }
        trailerCache[vehicle] = st
    end

    local now = g_time or 0
    if st.dueAt > 0 and now < st.dueAt then return end

    local elapsedMs = (st.lastAt > 0) and (now - st.lastAt) or (TICK_BASE_MS + st.jitter)
    st.lastAt = now
    st.dueAt  = now + TICK_BASE_MS + st.jitter

    local tilt = nxTiltRad(vehicle)
    if tilt <= ANGLE_START then return end

    local coverShut = nxCoverShut(vehicle)
    local intensity = nxSpillIntensity(tilt, coverShut)
    if intensity <= 0 then return end

    if coverShut and tilt >= COVER_BREAK then
        nxForceOpenCover(vehicle)
    end

    local dtSec   = elapsedMs / 1000
    local tipSide = nxTipSide(vehicle)
    local units   = vehicle.spec_fillUnit.fillUnits
    for i = 1, #units do
        nxBleedUnit(vehicle, i, units[i], intensity, dtSec, tipSide)
    end
end

function NXLoadSpill:loadMap() end
function NXLoadSpill:deleteMap() end

function NXLoadSpill:update(dt)
    if not NXLoadSpill.enabled then return end
    if g_currentMission == nil then return end
    local list = g_currentMission.vehicles
    if list == nil then return end

    for _, vehicle in pairs(list) do
        if nxQualifies(vehicle) then
            pcall(nxTickTrailer, vehicle)
            pcall(nxAdaptFlow, vehicle)
        end
    end
end

if not rawget(_G, "_NXLoadSpill_bootstrapped") then
    _G._NXLoadSpill_bootstrapped = true
    addModEventListener(NXLoadSpill)
end
