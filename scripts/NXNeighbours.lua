NXNeighbours = NXNeighbours or {}
NXNeighbours.maxWorkers = 0          -- set from the "Neighbours" setting (0 = off)
NXNeighbours.HARD_CAP   = 10         -- never more than this many neighbour workers, whatever the setting

-- Neighbour farmers working the map's open field contracts.
-- A hidden "Neighbours" farm takes a contract the same way a player would, gets the lease
-- vehicles, and a hired helper works the field. Differences from a player:
--   * the rig is moved from the shop to the field and hitched automatically
--   * the helper is free, and seed / fertiliser / herbicide / fuel are topped up for free
--   * harvested crop is taken out of the tank so harvesters never stop full
--   * once the job is done the contract is closed and the vehicles go away
-- Pay goes to the Neighbours farm, never to the player. Everything runs on the server.

local TICK_MS             = 2000
local FARM_NAME           = "Neighbours"
local FARM_MIN_BALANCE    = 1000000
local MIN_FREE_HELPERS    = 2        -- always leave this many helpers free for the player
local MIN_OPEN_CONTRACTS  = 3        -- always leave this many open field contracts for the player
local MIN_SPAWN_DIST      = 150      -- don't start a contract right in front of the player
local PREPARE_TIMEOUT_MS  = 90000
local SETTLE_MS           = 2500     -- let the hitched rig settle before the helper starts
local MAX_RETRIES         = 2
local COMPLETE_ENOUGH     = 0.90
local BLACKLIST_MS        = 30 * 60 * 1000
local TOPUP_BELOW         = 0.35     -- refill consumables below this fraction
local DRAIN_ABOVE         = 0.60     -- empty the grain tank above this fraction
local SKIP_TYPES          = { stonepick = true, deadwood = true, destructiblerocks = true, transport = true }

local state = {
    farmId       = nil,
    workers      = {},               -- [mission] = worker
    blacklist    = setmetatable({}, { __mode = "k" }),
    timer        = 0,
    adopted      = false,
    baseHirables = nil,
    hooked       = false
}

local function nxLog(fmt, ...)
    print(string.format("[FarmKit] Neighbours: " .. fmt, ...))
end

local function nxNow()
    return g_time or 0
end

local function nxLimit()
    return math.max(0, math.min(NXNeighbours.HARD_CAP, math.floor(NXNeighbours.maxWorkers or 0)))
end

local function nxCount()
    local n = 0
    for _ in pairs(state.workers) do n = n + 1 end
    return n
end

---------------------------------------------------------------------------
-- Farm
---------------------------------------------------------------------------

local function nxFindFarm()
    if state.farmId ~= nil and g_farmManager:getFarmById(state.farmId) ~= nil then
        return state.farmId
    end
    for _, farm in pairs(g_farmManager:getFarms() or {}) do
        if farm.name == FARM_NAME and farm.farmId ~= nil then
            state.farmId = farm.farmId
            return state.farmId
        end
    end
    return nil
end

local function nxCreateFarm()
    if g_farmManager.createFarm == nil then return nil end
    for _, args in ipairs({ { nil, nil }, { "", nil } }) do
        local ok, result = pcall(g_farmManager.createFarm, g_farmManager, FARM_NAME, 8, args[1], args[2])
        if ok and result ~= nil then break end
    end
    return nxFindFarm()
end

local function nxEnsureFunds()
    local farm = g_farmManager:getFarmById(state.farmId)
    if farm == nil or (farm.money or 0) >= FARM_MIN_BALANCE then return end
    local moneyType = MoneyType.OTHER or MoneyType.MISSIONS
    pcall(g_currentMission.addMoney, g_currentMission, 2 * FARM_MIN_BALANCE - (farm.money or 0), state.farmId, moneyType, false)
end

---------------------------------------------------------------------------
-- Picking a contract
---------------------------------------------------------------------------

local function nxMissionXZ(mission)
    local ok, a, b, c = pcall(mission.getWorldPosition, mission)
    if not ok or a == nil then return nil end
    if c ~= nil then return a, c end
    return a, b
end

local function nxTypeName(mission)
    return string.lower(tostring(mission.type ~= nil and mission.type.name or ""))
end

local function nxIsOpenFieldContract(mission)
    return mission.status == MissionStatus.CREATED
        and mission.farmId == nil
        and mission.field ~= nil
        and mission.hasLeasableVehicles ~= nil and mission:hasLeasableVehicles()
        and not SKIP_TYPES[nxTypeName(mission)]
end

local function nxAnyPreparing()
    for _, mission in ipairs(g_missionManager:getMissions()) do
        if mission.status == MissionStatus.PREPARING then return true end
    end
    return false
end

local function nxPickContract()
    local open, candidates = 0, {}
    local camX, camZ
    local camera = getCamera ~= nil and getCamera() or nil
    if camera ~= nil and camera ~= 0 then
        local x, _, z = getWorldTranslation(camera)
        camX, camZ = x, z
    end

    for _, mission in ipairs(g_missionManager:getMissions()) do
        if nxIsOpenFieldContract(mission) then
            open = open + 1
            local until_ = state.blacklist[mission]
            if until_ == nil or nxNow() > until_ then
                local x, z = nxMissionXZ(mission)
                local farEnough = x == nil or camX == nil
                    or MathUtil.vector2Length(x - camX, z - camZ) > MIN_SPAWN_DIST
                if farEnough then candidates[#candidates + 1] = mission end
            end
        end
    end

    if open <= MIN_OPEN_CONTRACTS or #candidates == 0 then return nil end
    return candidates[math.random(1, #candidates)]
end

---------------------------------------------------------------------------
-- Rigging: move the lease vehicles to the field and hitch them
---------------------------------------------------------------------------

local function nxIsDriver(vehicle)
    return vehicle.spec_motorized ~= nil and vehicle.getCanStartFieldWork ~= nil
end

local function nxYawOf(vehicle)
    local dx, _, dz = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)
    return math.atan2(dx, dz)
end

-- place `implement` so its input joint sits on `holder`'s attacher joint, then attach
local function nxHitch(holder, jointIndex, joint, implement, inputIndex, inputJoint)
    local yaw = nxYawOf(holder)
    local jx, jy, jz = getWorldTranslation(joint.jointTransform)
    local lx, ly, lz = worldToLocal(implement.rootNode, getWorldTranslation(inputJoint.node))
    local s, c = math.sin(yaw), math.cos(yaw)
    local rx = jx - (lx * c + lz * s)
    local rz = jz - (-lx * s + lz * c)
    implement:setAbsolutePosition(rx, jy - ly, rz, 0, yaw, 0)
    holder:attachImplement(implement, inputIndex, jointIndex, false, nil, false, true)
end

local function nxTryHitch(holder, implement)
    if holder.spec_attacherJoints == nil or implement.getInputAttacherJoints == nil then return false end
    local joints = holder:getAttacherJoints()
    local inputs = implement:getInputAttacherJoints()

    for jointIndex, joint in ipairs(joints) do
        if joint.jointIndex == 0 and joint.jointTransform ~= nil then
            for inputIndex, inputJoint in ipairs(inputs) do
                if inputJoint.jointType == joint.jointType and inputJoint.node ~= nil
                    and AttacherJoints.getAttacherJointCompatibility(holder, joint, implement, inputJoint) then
                    nxHitch(holder, jointIndex, joint, implement, inputIndex, inputJoint)
                    return true
                end
            end
        end
    end
    return false
end

local function nxRig(worker)
    local mission = worker.mission
    local driver
    for _, v in ipairs(mission.vehicles) do
        if nxIsDriver(v) then driver = v break end
    end
    if driver == nil then return false, "no drivable vehicle" end

    local x, z = nxMissionXZ(mission)
    if x == nil then return false, "no field position" end
    local yaw = math.random() * 2 * math.pi
    driver:setRelativePosition(x, 0.5, z, yaw)

    -- hitch everything else onto the driver or onto something already hitched (trailed chains)
    local placed = { driver }
    local pending = {}
    for _, v in ipairs(mission.vehicles) do
        if v ~= driver then pending[#pending + 1] = v end
    end

    local progress = true
    while progress and #pending > 0 do
        progress = false
        for i = #pending, 1, -1 do
            local implement = pending[i]
            for _, holder in ipairs(placed) do
                if nxTryHitch(holder, implement) then
                    placed[#placed + 1] = implement
                    table.remove(pending, i)
                    progress = true
                    break
                end
            end
        end
    end

    worker.driver = driver
    worker.yaw = yaw
    if #pending > 0 then
        nxLog("contract on field %s: %d vehicle(s) could not be hitched", tostring(mission.field:getId()), #pending)
    end
    return true
end

---------------------------------------------------------------------------
-- Helper
---------------------------------------------------------------------------

local function nxFreeHelpers()
    return g_helperManager ~= nil and #(g_helperManager.availableHelpers or {}) or 0
end

local function nxStartHelper(worker)
    local driver = worker.driver
    if driver == nil or driver.isDeleted then return false, "driver gone" end
    if nxFreeHelpers() <= MIN_FREE_HELPERS then return false, "no free helper" end

    local job = g_currentMission.aiJobTypeManager:createJob(AIJobType.FIELDWORK)
    job:applyCurrentState(driver, g_currentMission, state.farmId, true)
    local x, _, z = getWorldTranslation(driver.rootNode)
    job.positionAngleParameter:setPosition(x, z)
    job.positionAngleParameter:setAngle(nxYawOf(driver))
    job:setValues()

    local ok, err = job:validate(state.farmId)
    if not ok then return false, tostring(err) end

    job.getPricePerMs = function() return 0 end   -- neighbours pay their own helpers
    g_currentMission.aiSystem:startJob(job, state.farmId)
    return true
end

local function nxStopHelper(worker)
    local driver = worker.driver
    if driver ~= nil and not driver.isDeleted and driver.getIsAIActive ~= nil and driver:getIsAIActive() then
        pcall(driver.stopCurrentAIJob, driver, AIMessageSuccessFinishedJob.new())
    end
end

-- keep the player's own hire limit intact while neighbours are working
local function nxSyncHireLimit()
    if state.baseHirables == nil then state.baseHirables = g_currentMission.maxNumHirables end
    if state.baseHirables ~= nil then
        g_currentMission.maxNumHirables = state.baseHirables + nxCount()
    end
end

---------------------------------------------------------------------------
-- Consumables
---------------------------------------------------------------------------

local SPRAY_TYPES = {
    fertilize = { "FERTILIZER", "LIQUIDFERTILIZER" },
    spray     = { "HERBICIDE" },
    herbicide = { "HERBICIDE" },
    lime      = { "LIME" }
}

local function nxTopUp(vehicle, unitIndex, fillType)
    if unitIndex == nil or fillType == nil or fillType == FillType.UNKNOWN then return end
    local cap = vehicle:getFillUnitCapacity(unitIndex)
    if cap == nil or cap <= 0 or cap == math.huge then return end
    local level = vehicle:getFillUnitFillLevel(unitIndex) or 0
    if level < cap * TOPUP_BELOW and vehicle:getFillUnitSupportsFillType(unitIndex, fillType) then
        vehicle:addFillUnitFillLevel(state.farmId, unitIndex, cap - level, fillType, ToolType.UNDEFINED, nil)
    end
end

local function nxFirstSupported(vehicle, unitIndex, names)
    for _, name in ipairs(names or {}) do
        local ft = g_fillTypeManager:getFillTypeIndexByName(name)
        if ft ~= nil and vehicle:getFillUnitSupportsFillType(unitIndex, ft) then return ft end
    end
    return nil
end

local function nxService(worker)
    local typeName = nxTypeName(worker.mission)
    for _, v in ipairs(worker.mission.vehicles) do
        if not v.isDeleted and v.getFillUnitCapacity ~= nil then
            if v.spec_motorized ~= nil and v.getConsumerFillUnitIndex ~= nil then
                for _, ft in ipairs({ FillType.DIESEL, FillType.DEF }) do
                    if ft ~= nil then nxTopUp(v, v:getConsumerFillUnitIndex(ft), ft) end
                end
            end

            if v.spec_sowingMachine ~= nil then
                nxTopUp(v, v.spec_sowingMachine.fillUnitIndex, FillType.SEEDS)
            end

            if v.spec_sprayer ~= nil then
                local idx = v.spec_sprayer.fillUnitIndex
                local ft = v:getFillUnitFillType(idx)
                if ft == nil or ft == FillType.UNKNOWN then
                    ft = nxFirstSupported(v, idx, SPRAY_TYPES[typeName])
                        or nxFirstSupported(v, idx, { "FERTILIZER", "LIQUIDFERTILIZER", "HERBICIDE" })
                end
                nxTopUp(v, idx, ft)
            end

            if v.spec_combine ~= nil then
                local idx = v.spec_combine.fillUnitIndex
                local cap = v:getFillUnitCapacity(idx)
                local level = v:getFillUnitFillLevel(idx) or 0
                if cap ~= nil and cap > 0 and cap ~= math.huge and level > cap * DRAIN_ABOVE then
                    v:addFillUnitFillLevel(v:getOwnerFarmId(), idx, -level, v:getFillUnitFillType(idx), ToolType.UNDEFINED, nil)
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Worker lifecycle
---------------------------------------------------------------------------

local function nxMissionAlive(mission)
    for _, m in ipairs(g_missionManager:getMissions()) do
        if m == mission then return true end
    end
    return false
end

local function nxClose(worker, reason)
    nxStopHelper(worker)
    local mission = worker.mission
    if mission.status == MissionStatus.RUNNING or mission.status == MissionStatus.PREPARING then
        if (mission.completion or 0) >= COMPLETE_ENOUGH then
            pcall(mission.finish, mission, MissionFinishState.SUCCESS)
        else
            pcall(g_missionManager.cancelMission, g_missionManager, mission)
        end
    end
    worker.phase = "closing"
    worker.reason = reason
end

local function nxAbandon(worker, reason)
    state.blacklist[worker.mission] = nxNow() + BLACKLIST_MS
    nxLog("dropping contract on field %s: %s", tostring(worker.mission.field and worker.mission.field:getId()), reason)
    nxClose(worker, reason)
end

local function nxTickWorker(worker)
    local mission = worker.mission
    if not nxMissionAlive(mission) or mission.status == MissionStatus.DISMISSED then
        state.workers[mission] = nil
        return
    end

    if mission.status == MissionStatus.FINISHED then
        nxStopHelper(worker)
        pcall(g_missionManager.dismissMission, g_missionManager, mission)
        state.workers[mission] = nil
        return
    end

    if worker.phase == "closing" then return end

    local now = nxNow()
    if worker.phase == "preparing" then
        if mission.status == MissionStatus.RUNNING and #mission.vehicles == #(mission.vehiclesToLoad or {}) then
            local ok, result, why = pcall(nxRig, worker)
            if ok and result then
                worker.phase, worker.since = "settling", now
            else
                nxAbandon(worker, "could not rig vehicles: " .. tostring(ok and why or result))
            end
        elseif now - worker.since > PREPARE_TIMEOUT_MS then
            nxAbandon(worker, "vehicles never arrived")
        end
        return
    end

    if worker.phase == "settling" then
        if worker.driver ~= nil and not worker.driver.isDeleted and worker.driver:getIsAIActive() then
            worker.phase = "working"
        elseif now - worker.since >= SETTLE_MS then
            local ok, started, why = pcall(nxStartHelper, worker)
            if ok and started then
                worker.phase = "working"
            elseif ok and why == "no free helper" then
                worker.since = now  -- wait for a helper to free up
            else
                nxAbandon(worker, "helper could not start: " .. tostring(ok and why or started))
            end
        end
        return
    end

    if worker.phase == "working" then
        pcall(nxService, worker)

        local driver = worker.driver
        if driver == nil or driver.isDeleted then
            nxAbandon(worker, "vehicle lost")
            return
        end
        if not driver:getIsAIActive() then
            if (mission.completion or 0) >= COMPLETE_ENOUGH or worker.retries >= MAX_RETRIES then
                nxClose(worker, "job done")
            else
                worker.retries = worker.retries + 1
                worker.phase, worker.since = "settling", now
            end
        end
    end
end

local function nxNewWorker(mission, phase)
    local worker = { mission = mission, phase = phase, since = nxNow(), retries = 0 }
    state.workers[mission] = worker
    return worker
end

-- after loading a save, pick up contracts the neighbours were already working
local function nxAdoptRunning()
    for _, mission in ipairs(g_missionManager:getMissions()) do
        if mission.farmId == state.farmId and state.workers[mission] == nil and mission:getWasStarted() then
            local worker = nxNewWorker(mission, "settling")
            for _, v in ipairs(mission.vehicles) do
                if nxIsDriver(v) then worker.driver = v break end
            end
            if worker.driver == nil then nxClose(worker, "no driver after load") end
        end
    end
end

---------------------------------------------------------------------------
-- Main loop
---------------------------------------------------------------------------

function NXNeighbours:loadMap() end

function NXNeighbours:deleteMap()
    state.workers, state.farmId, state.adopted, state.baseHirables = {}, nil, false, nil
end

function NXNeighbours:update(dt)
    if g_currentMission == nil or not g_currentMission:getIsServer() or g_missionManager == nil then return end
    state.timer = state.timer + dt
    if state.timer < TICK_MS then return end
    state.timer = 0

    local limit = nxLimit()
    if state.farmId == nil then
        if limit == 0 then return end
        if nxFindFarm() == nil and nxCreateFarm() == nil then
            nxLog("could not create the %s farm; feature disabled this session", FARM_NAME)
            NXNeighbours.maxWorkers = 0
            return
        end
    end

    if not state.adopted then
        state.adopted = true
        pcall(nxAdoptRunning)
    end

    nxEnsureFunds()

    for _, worker in pairs(state.workers) do
        local ok, err = pcall(nxTickWorker, worker)
        if not ok then nxAbandon(worker, "error: " .. tostring(err)) end
    end

    -- wind down extra workers if the setting was lowered
    local active = {}
    for _, w in pairs(state.workers) do
        if w.phase ~= "closing" then active[#active + 1] = w end
    end
    for i = limit + 1, #active do
        nxClose(active[i], "setting lowered")
    end

    nxSyncHireLimit()

    if #active < limit and not nxAnyPreparing() and nxFreeHelpers() > MIN_FREE_HELPERS then
        local mission = nxPickContract()
        if mission ~= nil then
            local ok, result = pcall(g_missionManager.startMission, g_missionManager, mission, state.farmId, true)
            if ok and result == MissionStartState.OK then
                nxNewWorker(mission, "preparing")
            else
                state.blacklist[mission] = nxNow() + BLACKLIST_MS
            end
        end
    end
end

---------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------

if not rawget(_G, "_NXNeighbours_bootstrapped") then
    _G._NXNeighbours_bootstrapped = true

    -- the neighbours can hold several contracts at once
    MissionManager.hasFarmReachedMissionLimit = Utils.overwrittenFunction(MissionManager.hasFarmReachedMissionLimit,
        function(self, superFunc, farmId)
            if state.farmId ~= nil and farmId == state.farmId then return false end
            return superFunc(self, farmId)
        end)

    addModEventListener(NXNeighbours)
end
