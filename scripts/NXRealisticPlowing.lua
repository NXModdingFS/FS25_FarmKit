NXRealisticPlowing = NXRealisticPlowing or {}
NXRealisticPlowing.SPEC_FIELD = "nxRealisticPlowing"

NXRealisticPlowing.TUNING = {
    heightThreshold = 0.055,
    minSpeed        = 0.15,
    maxSpeed        = 25.0,
    widthScale      = 0.55,
    minPhysWidth    = 0.14,
    dampingMult     = 1.45,
    springMult      = 0.95,
    reactionSpeed   = 3.0,
    releaseSpeed    = 2.0,
    fieldOnly       = true,
    dampAllWheels   = false,
    disableCollision = false,
    preferPlowSide  = true
}

NXRealisticPlowing.enabled = true

local function nxClamp(v, lo, hi)
    if v == nil then return lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function nxMoveTowards(current, target, maxDelta)
    if current < target then return math.min(target, current + maxDelta) end
    if current > target then return math.max(target, current - maxDelta) end
    return current
end

function NXRealisticPlowing.prerequisitesPresent(specs)
    return SpecializationUtil.hasSpecialization(Wheels, specs)
end

function NXRealisticPlowing.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad",     NXRealisticPlowing)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", NXRealisticPlowing)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate",   NXRealisticPlowing)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete",   NXRealisticPlowing)
end

function NXRealisticPlowing:onLoad(savegame)
    local t = NXRealisticPlowing.TUNING
    self[NXRealisticPlowing.SPEC_FIELD] = {
        wheels    = {},
        sideBlend = { left = 0, right = 0 },
        tuning    = t
    }
end

function NXRealisticPlowing:onPostLoad(savegame)
    local spec = self[NXRealisticPlowing.SPEC_FIELD]
    if spec == nil then return end

    local wheels = (self.getWheels ~= nil and self:getWheels())
        or (self.spec_wheels ~= nil and self.spec_wheels.wheels)
        or nil
    if wheels == nil then return end

    for _, wheel in pairs(wheels) do
        local physics = wheel and wheel.physics
        if physics ~= nil then
            local baseWidth = physics.wheelShapeWidth or physics.width or 0.50
            spec.wheels[#spec.wheels + 1] = {
                wheel         = wheel,
                physics       = physics,
                isLeft        = wheel.isLeft == true,
                baseWidth     = baseWidth,
                baseOffset    = physics.wheelShapeWidthOffset or 0,
                baseCollision = physics.displacementCollisionEnabled ~= false,
                currentWidth  = baseWidth,
                lastWidth     = nil,
                lastDamping   = nil,
                lastSpring    = nil,
                lastCollision = nil
            }
        end
    end
end

function NXRealisticPlowing:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self[NXRealisticPlowing.SPEC_FIELD]
    if spec == nil or #spec.wheels == 0 then return end

    if not NXRealisticPlowing.enabled then
        for _, w in ipairs(spec.wheels) do NXRealisticPlowing.restoreWheel(w) end
        spec.sideBlend.left, spec.sideBlend.right = 0, 0
        return
    end

    local t = spec.tuning
    local side, _, onField = NXRealisticPlowing.detectSide(spec, t)

    local speed = (self.getLastSpeed ~= nil) and math.abs(self:getLastSpeed()) or 0
    if speed < t.minSpeed or speed > t.maxSpeed then side = nil end
    if t.fieldOnly and not onField then side = nil end

    if side == nil and t.preferPlowSide then
        side = NXRealisticPlowing.getPlowSide(self)
    end

    local dtSec = dt / 1000
    local leftTarget  = (side == "left")  and 1 or 0
    local rightTarget = (side == "right") and 1 or 0
    local lspeed = (leftTarget  > spec.sideBlend.left)  and t.reactionSpeed or t.releaseSpeed
    local rspeed = (rightTarget > spec.sideBlend.right) and t.reactionSpeed or t.releaseSpeed
    spec.sideBlend.left  = nxMoveTowards(spec.sideBlend.left,  leftTarget,  dtSec * lspeed)
    spec.sideBlend.right = nxMoveTowards(spec.sideBlend.right, rightTarget, dtSec * rspeed)

    for _, w in ipairs(spec.wheels) do
        NXRealisticPlowing.updateWheel(spec, w, dt)
    end
end

function NXRealisticPlowing:onDelete()
    local spec = self[NXRealisticPlowing.SPEC_FIELD]
    if spec == nil then return end
    for _, w in ipairs(spec.wheels) do NXRealisticPlowing.restoreWheel(w) end
end

function NXRealisticPlowing.updateWheel(spec, w, dt)
    local physics = w.physics
    if physics == nil then return end

    local t = spec.tuning
    local sideKey   = w.isLeft and "left" or "right"
    local sideBlend = spec.sideBlend[sideKey] or 0
    local allBlend  = math.max(spec.sideBlend.left or 0, spec.sideBlend.right or 0)

    local targetWidth = w.baseWidth
    if sideBlend > 0 then
        local narrow = math.max(t.minPhysWidth, w.baseWidth * t.widthScale)
        targetWidth = w.baseWidth + (narrow - w.baseWidth) * sideBlend
    end
    local alpha = nxClamp((dt / 1000) * t.reactionSpeed, 0, 1)
    w.currentWidth = w.currentWidth + (targetWidth - w.currentWidth) * alpha

    if physics.setWheelShapeWidth ~= nil
        and (w.lastWidth == nil or math.abs(w.lastWidth - w.currentWidth) > 0.002) then
        physics:setWheelShapeWidth(w.currentWidth, w.baseOffset)
        w.lastWidth = w.currentWidth
    end

    local dampBlend = t.dampAllWheels and allBlend or sideBlend
    local damping = 1 + (t.dampingMult - 1) * dampBlend
    local spring  = 1 + (t.springMult  - 1) * dampBlend
    if physics.setSuspensionMultipliers ~= nil
        and (w.lastDamping == nil
            or math.abs(w.lastDamping - damping) > 0.005
            or math.abs(w.lastSpring  - spring)  > 0.005) then
        physics:setSuspensionMultipliers(spring, damping)
        w.lastDamping = damping
        w.lastSpring  = spring
    end

    if physics.setDisplacementCollisionEnabled ~= nil then
        local desired = w.baseCollision
        if t.disableCollision and sideBlend > 0.05 then desired = false end
        if w.lastCollision ~= desired then
            physics:setDisplacementCollisionEnabled(desired)
            w.lastCollision = desired
        end
    end
end

function NXRealisticPlowing.restoreWheel(w)
    local physics = w.physics
    if physics == nil then return end

    if physics.setWheelShapeWidth ~= nil
        and (w.lastWidth == nil or math.abs(w.lastWidth - w.baseWidth) > 0.002) then
        physics:setWheelShapeWidth(w.baseWidth, w.baseOffset)
        w.lastWidth = w.baseWidth
        w.currentWidth = w.baseWidth
    end

    if physics.setSuspensionMultipliers ~= nil
        and (w.lastDamping ~= 1 or w.lastSpring ~= 1) then
        physics:setSuspensionMultipliers(1, 1)
        w.lastDamping = 1
        w.lastSpring  = 1
    end

    if physics.setDisplacementCollisionEnabled ~= nil
        and w.lastCollision ~= w.baseCollision then
        physics:setDisplacementCollisionEnabled(w.baseCollision)
        w.lastCollision = w.baseCollision
    end
end

function NXRealisticPlowing.detectSide(spec, t)
    local leftSum, rightSum, leftN, rightN = 0, 0, 0, 0
    local onField = false

    for _, w in ipairs(spec.wheels) do
        local y = NXRealisticPlowing.getContactY(w)
        if y ~= nil then
            if w.isLeft then leftSum = leftSum + y; leftN = leftN + 1
            else             rightSum = rightSum + y; rightN = rightN + 1
            end
        end
        if NXRealisticPlowing.wheelOnField(w) then onField = true end
    end

    if leftN == 0 or rightN == 0 then return nil, 0, onField end

    local delta = (leftSum / leftN) - (rightSum / rightN)
    if math.abs(delta) < t.heightThreshold then return nil, math.abs(delta), onField end

    return (delta > 0) and "right" or "left", math.abs(delta), onField
end

function NXRealisticPlowing.getContactY(w)
    local wheel, physics = w.wheel, w.physics
    if wheel == nil or physics == nil then return nil end

    if physics.hasGroundContact and physics.lastContactY ~= nil then
        return physics.lastContactY
    end

    if getWheelShapeContactPoint ~= nil and physics.wheelShape ~= nil and physics.wheelShape ~= 0 and wheel.node ~= nil then
        local _, y, _ = getWheelShapeContactPoint(wheel.node, physics.wheelShape)
        if y ~= nil then return y end
    end

    if physics.netInfo ~= nil and wheel.node ~= nil and localToWorld ~= nil then
        local ni = physics.netInfo
        if ni.x ~= nil and ni.y ~= nil and ni.z ~= nil then
            local _, y, _ = localToWorld(wheel.node, ni.x, ni.y - (physics.radius or 0.5), ni.z)
            return y
        end
    end

    local node = wheel.repr or wheel.driveNode or wheel.node
    if node ~= nil and getWorldTranslation ~= nil then
        local _, y, _ = getWorldTranslation(node)
        return y
    end

    return nil
end

function NXRealisticPlowing.wheelOnField(w)
    local physics = w.physics
    if physics == nil then return false end

    if physics.getIsOnField ~= nil then return physics:getIsOnField() end

    if FieldGroundType ~= nil and physics.densityType ~= nil then
        return physics.densityType ~= FieldGroundType.NONE
            and physics.densityType ~= FieldGroundType.GRASS
            and physics.densityType ~= FieldGroundType.GRASS_CUT
    end

    return true
end

function NXRealisticPlowing.getPlowSide(vehicle)
    local root = vehicle.rootVehicle or vehicle
    for _, tool in pairs(root.childVehicles or {}) do
        if tool ~= nil and tool.spec_plow ~= nil then
            local lowered = (tool.getIsLowered ~= nil) and tool:getIsLowered(false) or true
            if lowered then
                if tool.spec_plow.rotationMax == true then return "left" end
                return "right"
            end
        end
    end
    return nil
end

if not rawget(_G, "_NXRealisticPlowing_bootstrapped") then
    _G._NXRealisticPlowing_bootstrapped = true

    local SPEC_NAME    = "nxRealisticPlowing"
    local FULL_SPEC    = (g_currentModName or "") .. "." .. SPEC_NAME
    local SCRIPT_PATH  = (g_currentModDirectory or "") .. "scripts/NXRealisticPlowing.lua"
    local MOD_NAME     = g_currentModName

    if g_specializationManager:getSpecializationByName(FULL_SPEC) == nil then
        g_specializationManager:addSpecialization(SPEC_NAME, "NXRealisticPlowing", SCRIPT_PATH, MOD_NAME)
    end

    local function nxInjectSpec(typeManager)
        if typeManager == nil or typeManager.typeName ~= "vehicle" then return end

        local count = 0
        for typeName, typeDef in pairs(typeManager:getTypes()) do
            if typeDef ~= nil and typeName ~= "locomotive" then
                local hasMotorized = typeDef.specializationsByName["motorized"] ~= nil
                local hasWheels    = typeDef.specializationsByName["wheels"] ~= nil
                if hasMotorized and hasWheels and typeDef.specializationsByName[FULL_SPEC] == nil then
                    typeManager:addSpecialization(typeName, FULL_SPEC)
                    count = count + 1
                end
            end
        end
    end

    TypeManager.validateTypes = Utils.appendedFunction(TypeManager.validateTypes, nxInjectSpec)
end
