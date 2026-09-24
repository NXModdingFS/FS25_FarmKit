NXStrawRefeed = NXStrawRefeed or {}
NXStrawRefeed.enabled = true

-- A combine threshing with its header lowered over an existing straw windrow picks that
-- straw back up. It travels through the machine (a short transit delay) and comes out of
-- the rear swath outlet again. With the chopper engaged the straw is chopped and spread,
-- so nothing is re-dropped as a windrow.

local TRANSIT_SECS    = 2.2     -- header -> straw walkers -> swath outlet
local BUFFER_MAX_L    = 6000    -- straw the machine can hold in transit before the header stops taking more
local DROP_RATE_LPS   = 900     -- max straw release per second once it reaches the outlet
local FALLBACK_HALF_W = 0.9     -- swath line half-width used if the combine has no swath work area

local combineState = setmetatable({}, { __mode = "k" })

local function nxStrawFillType()
    if FillType ~= nil and FillType.STRAW ~= nil then return FillType.STRAW end
    if g_fillTypeManager ~= nil then
        return g_fillTypeManager:getFillTypeIndexByName("STRAW")
    end
    return nil
end

local function nxState(combine)
    local st = combineState[combine]
    if st == nil then
        st = { queue = {}, queued = 0, lineOffset = 0 }
        combineState[combine] = st
    end
    return st
end

local function nxFarmId(vehicle)
    if vehicle.getActiveFarm ~= nil then
        local ok, id = pcall(vehicle.getActiveFarm, vehicle)
        if ok and id ~= nil then return id end
    end
    if vehicle.getOwnerFarmId ~= nil then return vehicle:getOwnerFarmId() end
    return nil
end

local function nxCanAccessLand(farmId, x, z)
    local handler = g_currentMission ~= nil and g_currentMission.accessHandler or nil
    if farmId == nil or handler == nil or handler.canFarmAccessLand == nil then return true end
    local ok, allowed = pcall(handler.canFarmAccessLand, handler, farmId, x, z)
    return not ok or allowed ~= false
end

local function nxIsTurnedOn(vehicle)
    if vehicle.getIsTurnedOn == nil then return false end
    local ok, on = pcall(vehicle.getIsTurnedOn, vehicle)
    return ok and on == true
end

local function nxIsLowered(vehicle)
    if vehicle.getIsLowered == nil then return true end
    local ok, lowered = pcall(vehicle.getIsLowered, vehicle, false)
    return not ok or lowered == true
end

local function nxHeaderWorking(cutter)
    if cutter.spec_cutter == nil then return false end
    if not nxIsLowered(cutter) then return false end
    if cutter.spec_cutter.isWorking == true then return true end
    return nxIsTurnedOn(cutter)
end

local function nxCollectHeaders(combine)
    local list, seen = {}, {}
    local function add(v)
        if type(v) == "table" and v.spec_cutter ~= nil and not seen[v] then
            seen[v] = true
            list[#list + 1] = v
        end
    end

    add(combine)
    local attached = combine.spec_combine.attachedCutters
    if type(attached) == "table" then
        for k, v in pairs(attached) do
            add(k)
            add(v)
        end
    end
    return list
end

local function nxAreasOfType(vehicle, typeKey)
    local out = {}
    local spec = vehicle.spec_workArea
    if spec == nil or type(spec.workAreas) ~= "table" then return out end
    local wanted = WorkAreaType ~= nil and WorkAreaType[typeKey] or nil
    if wanted == nil then return out end

    for _, area in ipairs(spec.workAreas) do
        if area.type == wanted and area.start ~= nil and area.width ~= nil and area.height ~= nil then
            out[#out + 1] = area
        end
    end
    return out
end

local function nxAreaActive(vehicle, area)
    if vehicle.getIsWorkAreaActive == nil then return true end
    local ok, active = pcall(vehicle.getIsWorkAreaActive, vehicle, area)
    return not ok or active == true
end

local function nxPickupUnderHeader(combine, cutter, st, strawType, farmId)
    local room = BUFFER_MAX_L - st.queued
    if room <= 1 then return 0 end

    local picked = 0
    for _, area in ipairs(nxAreasOfType(cutter, "CUTTER")) do
        if room <= 1 then break end
        if nxAreaActive(cutter, area) then
            local sx, sy, sz, ex, ey, ez, radius = DensityMapHeightUtil.getLineByArea(area.start, area.width, area.height)
            if nxCanAccessLand(farmId, (sx + ex) * 0.5, (sz + ez) * 0.5) then
                local taken = -DensityMapHeightUtil.tipToGroundAroundLine(combine, -room, strawType,
                    sx, sy, sz, ex, ey, ez, radius, nil, nil, false, nil)
                if taken ~= nil and taken > 0 then
                    picked = picked + taken
                    room = room - taken
                end
            end
        end
    end
    return picked
end

local function nxSwathLine(combine)
    local areas = nxAreasOfType(combine, "COMBINESWATH")
    if #areas > 0 then
        -- same line setup the combine uses for its own swath (Combine.lua)
        return DensityMapHeightUtil.getLineByArea(areas[1].start, areas[1].width, areas[1].height, true)
    end

    local size = combine.size or {}
    local back = -((size.length or 8) * 0.5) + (size.lengthOffset or 0) - 0.5
    local sx, sy, sz = localToWorld(combine.rootNode, -FALLBACK_HALF_W, 0, back)
    local ex, ey, ez = localToWorld(combine.rootNode,  FALLBACK_HALF_W, 0, back)
    return sx, sy, sz, ex, ey, ez
end

local function nxReleaseAtOutlet(combine, st, strawType, dtSec)
    local now = g_time or 0
    local ready = 0
    for i = 1, #st.queue do
        local entry = st.queue[i]
        if now - entry.t >= TRANSIT_SECS * 1000 then ready = ready + entry.liters end
    end
    if ready <= 0 then return end

    local amount = math.min(ready, DROP_RATE_LPS * dtSec)
    if amount <= 0 then return end

    local swathMode = combine.spec_combine.isSwathActive ~= false
    local released = amount
    if swathMode then
        local sx, sy, sz, ex, ey, ez = nxSwathLine(combine)
        local dropped, lineOffset = DensityMapHeightUtil.tipToGroundAroundLine(combine, amount, strawType,
            sx, sy, sz, ex, ey, ez, 0, nil, st.lineOffset, false, nil, false)
        st.lineOffset = lineOffset or st.lineOffset
        released = dropped or 0
    end
    -- chopper mode: the straw is chopped and spread, so it simply leaves the machine

    local left = released
    while left > 0 and #st.queue > 0 do
        local head = st.queue[1]
        if head.liters <= left then
            left = left - head.liters
            table.remove(st.queue, 1)
        else
            head.liters = head.liters - left
            left = 0
        end
    end
    st.queued = math.max(0, st.queued - released)
end

local function nxTickCombine(combine, dt)
    local strawType = nxStrawFillType()
    if strawType == nil then return end

    local st = nxState(combine)
    local dtSec = dt / 1000

    if nxIsTurnedOn(combine) then
        local farmId = nxFarmId(combine)
        for _, cutter in ipairs(nxCollectHeaders(combine)) do
            if nxHeaderWorking(cutter) then
                local picked = nxPickupUnderHeader(combine, cutter, st, strawType, farmId)
                if picked > 0 then
                    st.queue[#st.queue + 1] = { t = g_time or 0, liters = picked }
                    st.queued = st.queued + picked
                end
            end
        end
    end

    -- anything already inside keeps flowing out, even once the header is raised
    if st.queued > 0 then
        nxReleaseAtOutlet(combine, st, strawType, dtSec)
    end
end

function NXStrawRefeed:loadMap() end
function NXStrawRefeed:deleteMap() end

function NXStrawRefeed:update(dt)
    if g_currentMission == nil or not g_currentMission:getIsServer() then return end
    if DensityMapHeightUtil == nil or DensityMapHeightUtil.tipToGroundAroundLine == nil then return end
    local list = g_currentMission.vehicles
    if list == nil then return end

    for _, vehicle in pairs(list) do
        if vehicle.spec_combine ~= nil and vehicle.rootNode ~= nil and vehicle.isServer then
            if NXStrawRefeed.enabled then
                pcall(nxTickCombine, vehicle, dt)
            elseif combineState[vehicle] ~= nil then
                combineState[vehicle] = nil
            end
        end
    end
end

if not rawget(_G, "_NXStrawRefeed_bootstrapped") then
    _G._NXStrawRefeed_bootstrapped = true
    addModEventListener(NXStrawRefeed)
end
