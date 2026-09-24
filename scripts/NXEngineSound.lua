NXEngineSound = NXEngineSound or {}
NXEngineSound.enabled = true

-- Realistic distance behaviour for vehicle drivetrain sounds (engine, gearbox, retarder):
--   * audible much further, with the range scaled by engine power (big machines carry)
--   * the engine's own linear fade is disabled and replaced by spherical-spreading falloff,
--     so volume drops the way real sound does and fades out smoothly at the range edge
--   * high frequencies are absorbed with distance (low-pass muffling)
--   * hills, buildings and static objects between you and the engine muffle it further
--   * Doppler pitch shift from the real closing speed between camera and engine
-- The game's own per-sample update runs first; we only rescale its result.

local RANGE_MIN_M      = 180    -- smallest engine
local RANGE_MAX_M      = 380    -- biggest engine
local RANGE_PER_KW     = 0.55
local AUX_RANGE_SCALE  = 0.55   -- gearbox / retarder whine carries less than the engine

local REF_MIN_M        = 6      -- full-volume radius floor (the sample's inner range is used if larger)
local REF_MAX_M        = 25
local ROLLOFF_EXP      = 0.75   -- 1.0 = pure inverse distance; a touch gentler keeps mid-range engines present
local EDGE_FADE_START  = 0.75   -- fraction of range where the final fade to silence begins

local AIR_MUFFLE       = 0.70   -- low-pass gain lost at the range edge
local OCCLUDED_VOLUME  = 0.55
local OCCLUDED_LOWPASS = 0.40
local OCCLUSION_MS     = 300    -- how often each sample re-checks line of sight
local OCCLUSION_MIN_M  = 15
local OCCLUSION_MASK   = CollisionFlag ~= nil
    and (CollisionFlag.TERRAIN + CollisionFlag.BUILDING + CollisionFlag.STATIC_OBJECT) or nil
local OCCLUSION_RATE   = 3.0    -- per second, smoothing toward the occluded/clear target

local SPEED_OF_SOUND   = 343
local DOPPLER_MIN      = 0.90
local DOPPLER_MAX      = 1.10
local DOPPLER_RATE     = 4.0

local taggedSamples = setmetatable({}, { __mode = "k" })

local function nxClamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function nxSmooth(t)
    t = nxClamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

local function nxApproach(current, target, rate, dtSec)
    local k = nxClamp(rate * dtSec, 0, 1)
    return current + (target - current) * k
end

---------------------------------------------------------------------------
-- Range handling
---------------------------------------------------------------------------

local function nxApplyRange(sample)
    local tag = sample.nxEngineSound
    if tag == nil or sample.soundNode == nil or sample.soundNode == 0 then return end

    if tag.origOuter == nil then
        tag.origOuter = getAudioSourceRange(sample.soundNode)
        tag.origInner = getAudioSourceInnerRange(sample.soundNode)
        tag.refDist = nxClamp(tag.origInner or REF_MIN_M, REF_MIN_M, REF_MAX_M)
    end

    if NXEngineSound.enabled then
        -- outer = inner: the engine applies no fade of its own, we do all of it
        setAudioSourceRange(sample.soundNode, tag.range)
        setAudioSourceInnerRange(sample.soundNode, tag.range)
    else
        setAudioSourceRange(sample.soundNode, tag.origOuter)
        setAudioSourceInnerRange(sample.soundNode, tag.origInner)
    end
end

local function nxTag(sample, range)
    if type(sample) ~= "table" then return end
    sample.nxEngineSound = {
        range     = range,
        occlusion = 0,
        doppler   = 1,
        nextRayAt = 0
    }
    taggedSamples[sample] = true
    nxApplyRange(sample)
end

local function nxEngineRange(vehicle)
    local motor = vehicle.spec_motorized ~= nil and vehicle.spec_motorized.motor or nil
    local kw = motor ~= nil and motor.peakMotorPower or 0
    return nxClamp(RANGE_MIN_M + kw * RANGE_PER_KW, RANGE_MIN_M, RANGE_MAX_M)
end

function NXEngineSound.refreshAll()
    for sample in pairs(taggedSamples) do
        pcall(nxApplyRange, sample)
    end
end

---------------------------------------------------------------------------
-- Per-update factors
---------------------------------------------------------------------------

function NXEngineSound:occlusionCallback(hitObjectId, x, y, z, distance)
    return false
end

local function nxIsOccluded(cx, cy, cz, sx, sy, sz, dist)
    if OCCLUSION_MASK == nil or raycastClosest == nil then return false end
    local inv = 1 / dist
    -- stop a few metres short so the ground right under the machine doesn't count
    local hits = raycastClosest(cx, cy, cz, (sx - cx) * inv, (sy - cy) * inv, (sz - cz) * inv,
        dist - 3, "occlusionCallback", NXEngineSound, OCCLUSION_MASK)
    return hits ~= nil and hits > 0
end

local function nxFactors(sample, tag)
    local now = g_time or 0
    local dtSec = tag.lastAt ~= nil and math.max(0, (now - tag.lastAt) / 1000) or 0
    tag.lastAt = now

    local camera = getCamera ~= nil and getCamera() or nil
    if camera == nil or camera == 0 then return 1, 1, 1 end

    local cx, cy, cz = getWorldTranslation(camera)
    local sx, sy, sz = getWorldTranslation(sample.soundNode)
    local dist = MathUtil.vector3Length(sx - cx, sy - cy, sz - cz)
    local range = tag.range
    local ref = tag.refDist or REF_MIN_M

    -- spherical spreading beyond the reference radius, smooth fade out near the range edge
    local volume = (ref / math.max(dist, ref)) ^ ROLLOFF_EXP
    local edge = (dist / range - EDGE_FADE_START) / (1 - EDGE_FADE_START)
    volume = volume * (1 - nxSmooth(edge))

    -- air absorption takes the top end off first
    local lowpass = 1 - AIR_MUFFLE * nxSmooth(dist / range)

    -- line of sight
    if dist > OCCLUSION_MIN_M and dist < range then
        if now >= tag.nextRayAt then
            tag.nextRayAt = now + OCCLUSION_MS
            tag.blocked = nxIsOccluded(cx, cy, cz, sx, sy, sz, dist)
        end
    else
        tag.blocked = false
    end
    tag.occlusion = nxApproach(tag.occlusion, tag.blocked and 1 or 0, OCCLUSION_RATE, dtSec)
    volume  = volume  * (1 - (1 - OCCLUDED_VOLUME)  * tag.occlusion)
    lowpass = lowpass * (1 - (1 - OCCLUDED_LOWPASS) * tag.occlusion)

    -- Doppler from real-time change in distance (positive = moving apart)
    local target = 1
    if tag.lastDist ~= nil and dtSec > 0.001 then
        local radial = (dist - tag.lastDist) / dtSec
        target = nxClamp(SPEED_OF_SOUND / (SPEED_OF_SOUND + radial), DOPPLER_MIN, DOPPLER_MAX)
    end
    tag.lastDist = dist
    tag.doppler = nxApproach(tag.doppler, target, DOPPLER_RATE, dtSec)

    return nxClamp(volume, 0, 1), tag.doppler, nxClamp(lowpass, 0, 1)
end

local function nxUpdateSampleAttributes(soundManager, superFunc, sample, force)
    superFunc(soundManager, sample, force)

    if not NXEngineSound.enabled or sample == nil then return end
    local tag = sample.nxEngineSound
    if tag == nil or sample.soundSample == nil or sample.soundNode == nil then return end

    local ok, volume, pitch, lowpass = pcall(nxFactors, sample, tag)
    if not ok then return end

    setSampleVolume(sample.soundSample,
        volume * soundManager:getModifierFactor(sample, "volume") * soundManager:getCurrentSampleVolume(sample))
    setSamplePitch(sample.soundSample,
        pitch * soundManager:getModifierFactor(sample, "pitch") * soundManager:getCurrentSamplePitch(sample))
    setSampleFrequencyFilter(sample.soundSample, 1.0,
        lowpass * soundManager:getModifierFactor(sample, "lowpassGain") * soundManager:getCurrentSampleLowpassGain(sample),
        0.0, sample.current.lowpassCutoffFrequency, 0.0, sample.current.lowpassResonance)
end

-- the audio source can be rebuilt (e.g. sample reload); re-apply our range when it is
local function nxOnCreateAudioSource(soundManager, sample)
    if sample ~= nil and sample.nxEngineSound ~= nil then
        sample.nxEngineSound.origOuter = nil
        pcall(nxApplyRange, sample)
    end
end

---------------------------------------------------------------------------
-- Vehicle specialization: tags the drivetrain samples once they exist
---------------------------------------------------------------------------

function NXEngineSound.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Motorized, specializations)
end

function NXEngineSound.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished", NXEngineSound)
end

function NXEngineSound:onLoadFinished(savegame)
    if not self.isClient then return end
    local spec = self.spec_motorized
    if spec == nil then return end

    local range = nxEngineRange(self)
    local auxRange = range * AUX_RANGE_SCALE

    for _, sample in ipairs(spec.motorSamples or {}) do nxTag(sample, range) end
    for _, sample in ipairs(spec.gearboxSamples or {}) do nxTag(sample, auxRange) end
    if spec.samples ~= nil and spec.samples.retarder ~= nil then
        nxTag(spec.samples.retarder, auxRange)
    end
end

if not rawget(_G, "_NXEngineSound_bootstrapped") then
    _G._NXEngineSound_bootstrapped = true

    SoundManager.updateSampleAttributes = Utils.overwrittenFunction(SoundManager.updateSampleAttributes, nxUpdateSampleAttributes)
    SoundManager.onCreateAudioSource = Utils.appendedFunction(SoundManager.onCreateAudioSource, nxOnCreateAudioSource)

    local SPEC_NAME   = "nxEngineSound"
    local MOD_NAME    = g_currentModName
    local FULL_SPEC   = (MOD_NAME or "") .. "." .. SPEC_NAME
    local SCRIPT_PATH = (g_currentModDirectory or "") .. "scripts/NXEngineSound.lua"

    if g_specializationManager:getSpecializationByName(FULL_SPEC) == nil then
        g_specializationManager:addSpecialization(SPEC_NAME, "NXEngineSound", SCRIPT_PATH, MOD_NAME)
    end

    local function nxInjectSpec(typeManager)
        if typeManager == nil or typeManager.typeName ~= "vehicle" then return end
        for typeName, typeDef in pairs(typeManager:getTypes()) do
            if typeDef ~= nil and typeName ~= "locomotive"
                and typeDef.specializationsByName["motorized"] ~= nil
                and typeDef.specializationsByName[FULL_SPEC] == nil then
                typeManager:addSpecialization(typeName, FULL_SPEC)
            end
        end
    end

    TypeManager.validateTypes = Utils.appendedFunction(TypeManager.validateTypes, nxInjectSpec)
end
