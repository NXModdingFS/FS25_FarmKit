NXLoadSpill = NXLoadSpill or {}
NXLoadSpill.enabled   = true
NXLoadSpill.installed = false

local TYPE_EXCLUDE_KEYWORDS = { "car", "truck", "utility", "rtv", "baler", "wrapper", "mower", "mulcher" }

local FILL_CATEGORY_ALLOW = {
    BULK = true, GRAIN = true, SEEDS = true, FERTILIZER = true,
    LIME = true, MANURE = true, SILAGE = true, ROOTCROP = true,
    CHAFF = true, WOODCHIPS = true, MINERAL_FEED = true, FORAGE = true,
}

local vehicleStates  = setmetatable({}, { __mode = "k" })
local dischargeState = setmetatable({}, { __mode = "k" })

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function lerp(a, b, t) return a + (b - a) * t end

local function lowercase(s) return type(s) == "string" and string.lower(s) or "" end

local function nxTypeNameExcluded(vehicle)
    local name = lowercase(vehicle.typeName)
    if name == "" then return false end
    for _, kw in ipairs(TYPE_EXCLUDE_KEYWORDS) do
        if string.find(name, kw, 1, true) then return true end
    end
    return false
end

local function nxIsApplicableVehicle(vehicle)
    if vehicle == nil or vehicle.isServer ~= true then return false end
    if vehicle.rootNode == nil or vehicle.rootNode == 0 then return false end
    if vehicle.spec_fillUnit == nil then return false end
    local units = vehicle.spec_fillUnit.fillUnits
    if type(units) ~= "table" or #units == 0 then return false end
    if nxTypeNameExcluded(vehicle) then return false end
    return true
end

local function nxFillTypeAllowed(fillTypeIndex)
    if fillTypeIndex == nil or fillTypeIndex == 0 then return false end
    if g_fillTypeManager == nil then return false end
    local ft = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
    if ft == nil then return false end

    if type(ft.physicalSurfaceMaterialName) == "string" then
        if string.find(ft.physicalSurfaceMaterialName, "liquid", 1, true) then return false end
    end

    if type(ft.categoryNames) == "table" then
        for _, catName in ipairs(ft.categoryNames) do
            if FILL_CATEGORY_ALLOW[string.upper(tostring(catName))] then return true end
        end
    end

    if type(g_fillTypeManager.getCategoryByName) == "function" and type(ft.name) == "string" then
        local upperName = string.upper(ft.name)
        for category in pairs(FILL_CATEGORY_ALLOW) do
            if string.find(upperName, category, 1, true) then return true end
        end
    end

    return false
end

local function nxGetTipAngle(vehicle)
    local _, upY, _ = localDirectionToWorld(vehicle.rootNode, 0, 1, 0)
    return math.acos(clamp(upY or 1, -1, 1))
end

local function nxGetTipSide(vehicle)
    local _, rY, _ = localDirectionToWorld(vehicle.rootNode, 1, 0, 0)
    return (rY or 0) > 0 and -1 or 1
end

local function nxGetSpeedKmh(vehicle)
    if vehicle.getLastSpeed == nil then return 0 end
    local ok, v = pcall(vehicle.getLastSpeed, vehicle, true)
    if ok and type(v) == "number" then return math.abs(v) end
    return 0
end

local function nxIsCoverClosed(vehicle)
    local spec = vehicle.spec_cover
    if spec == nil then return false end
    if type(spec.state) == "number" then return spec.state == 0 end
    if type(spec.coverState) == "number" then return spec.coverState == 0 end
    if spec.isOpen == false then return true end
    if type(spec.coverAnimation) == "table" and type(spec.coverAnimation.animTime) == "number" then
        return spec.coverAnimation.animTime <= 0.001
    end
    return false
end

local function nxOpenCover(vehicle)
    if vehicle.setCoverState == nil then return end
    pcall(vehicle.setCoverState, vehicle, 1, false)
end

local function nxComputeSpillFactor(tipAngle, coverClosed)
    local effective = tipAngle
    if coverClosed and tipAngle < math.rad(60) then
        effective = tipAngle - math.rad(15)
    end
    if effective <= math.rad(15)  then return 0 end
    if effective >= math.rad(120) then return 1 end
    return clamp((effective - math.rad(15)) / (math.rad(120) - math.rad(15)), 0, 1)
end

local function nxDepositOnGround(vehicle, fillTypeIndex, volume, tipSide)
    if volume <= 0 then return 0 end
    if FSDensityMapUtil == nil then return 0 end

    local fn = FSDensityMapUtil.updateFillTypeArea
            or FSDensityMapUtil.updateFillType
    if fn == nil then return 0 end

    local deposited = volume * 0.70
    if deposited <= 0 then return 0 end

    local sideX = tipSide * 1.6
    local halfW = 1.0
    local halfL = 2.25

    local x0, _, z0 = localToWorld(vehicle.rootNode, sideX - halfW, 0, -halfL)
    local x1, _, z1 = localToWorld(vehicle.rootNode, sideX + halfW, 0, -halfL)
    local x2, _, z2 = localToWorld(vehicle.rootNode, sideX + halfW, 0,  halfL)

    pcall(fn, x0, z0, x1, z1, x2, z2, fillTypeIndex)
    return deposited
end

local function nxApplyFillUnitSpill(vehicle, unitIndex, unit, spillFactor, dtSec, tipSide)
    if unit == nil then return end
    local capacity = unit.capacity or 0
    local current  = unit.fillLevel or 0
    if capacity <= 0 or current <= 0 then return end

    local fillTypeIndex = unit.fillType
    if not nxFillTypeAllowed(fillTypeIndex) then return end

    local volume = (capacity / 30.0) * spillFactor * dtSec
    if volume <= 0 then return end
    if volume > current then volume = current end

    if vehicle.addFillUnitFillLevel ~= nil then
        local farmId = (vehicle.getOwnerFarmId and vehicle:getOwnerFarmId())
                       or FarmManager.SPECTATOR_FARM_ID or 0
        local toolType = ToolType ~= nil and ToolType.UNDEFINED or 0
        pcall(vehicle.addFillUnitFillLevel, vehicle, farmId, unitIndex,
              -volume, fillTypeIndex, toolType, nil)
    end

    nxDepositOnGround(vehicle, fillTypeIndex, volume, tipSide)
end

local function nxResetDischargeNode(dischargeNode, defaults)
    if dischargeNode == nil or defaults == nil then return end
    if defaults.maxDistance     ~= nil then dischargeNode.maxDistance     = defaults.maxDistance     end
    if defaults.minDistance     ~= nil then dischargeNode.minDistance     = defaults.minDistance     end
    if defaults.dischargeWidth  ~= nil then dischargeNode.dischargeWidth  = defaults.dischargeWidth  end
    if defaults.dischargeLength ~= nil then dischargeNode.dischargeLength = defaults.dischargeLength end
end

local function nxCaptureDischargeDefaults(vehicle)
    if dischargeState[vehicle] ~= nil then return dischargeState[vehicle] end
    local spec = vehicle.spec_dischargeable or vehicle.spec_trailer
    if spec == nil or type(spec.dischargeNodes) ~= "table" then return nil end

    local snapshot = {}
    for i, node in ipairs(spec.dischargeNodes) do
        snapshot[i] = {
            maxDistance     = node.maxDistance,
            minDistance     = node.minDistance,
            dischargeWidth  = node.dischargeWidth,
            dischargeLength = node.dischargeLength,
        }
    end
    dischargeState[vehicle] = snapshot
    return snapshot
end

local function nxIsDischargingNow(vehicle)
    local spec = vehicle.spec_dischargeable or vehicle.spec_trailer
    if spec == nil then return false end
    if type(spec.currentDischargeState) == "number" and Dischargeable ~= nil
       and Dischargeable.DISCHARGE_STATE_OFF ~= nil then
        return spec.currentDischargeState ~= Dischargeable.DISCHARGE_STATE_OFF
    end
    if type(spec.isTipping) == "boolean" then return spec.isTipping end
    return false
end

local function nxApplyDynamicTipFlow(vehicle)
    local spec = vehicle.spec_dischargeable or vehicle.spec_trailer
    if spec == nil or type(spec.dischargeNodes) ~= "table" then return end

    local defaults = nxCaptureDischargeDefaults(vehicle)
    if defaults == nil then return end

    if not nxIsDischargingNow(vehicle) then
        for i, node in ipairs(spec.dischargeNodes) do
            nxResetDischargeNode(node, defaults[i])
        end
        return
    end

    local t = clamp(nxGetSpeedKmh(vehicle) / 25.0, 0, 1)
    local mult = lerp(0.55, 1.85, t)

    for i, node in ipairs(spec.dischargeNodes) do
        local d = defaults[i]
        if d ~= nil then
            if d.maxDistance     ~= nil then node.maxDistance     = d.maxDistance     * mult end
            if d.dischargeWidth  ~= nil then node.dischargeWidth  = d.dischargeWidth  * mult end
            if d.dischargeLength ~= nil then node.dischargeLength = d.dischargeLength * mult end
        end
    end
end

local function nxTickVehicle(vehicle)
    local st = vehicleStates[vehicle]
    if st == nil then
        st = { lastCheckMs = -200 }
        vehicleStates[vehicle] = st
    end

    local now = g_time or 0
    local elapsedMs = now - st.lastCheckMs
    if elapsedMs < 200 then return end
    st.lastCheckMs = now
    local dtSec = elapsedMs / 1000

    local tipAngle = nxGetTipAngle(vehicle)
    if tipAngle <= math.rad(15) then return end

    local coverClosed = nxIsCoverClosed(vehicle)
    local factor = nxComputeSpillFactor(tipAngle, coverClosed)
    if factor <= 0 then return end

    if coverClosed and tipAngle >= math.rad(60) then
        nxOpenCover(vehicle)
    end

    local tipSide = nxGetTipSide(vehicle)
    local fillUnits = vehicle.spec_fillUnit.fillUnits
    for i, u in ipairs(fillUnits) do
        nxApplyFillUnitSpill(vehicle, i, u, factor, dtSec, tipSide)
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
        if nxIsApplicableVehicle(vehicle) then
            pcall(nxTickVehicle, vehicle)
            pcall(nxApplyDynamicTipFlow, vehicle)
        end
    end
end

if not rawget(_G, "_NXLoadSpill_bootstrapped") then
    _G._NXLoadSpill_bootstrapped = true
    addModEventListener(NXLoadSpill)
end
