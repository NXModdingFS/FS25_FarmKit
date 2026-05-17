FarmKit = FarmKit or {}
FarmKit.VERSION = "1.0.0.0"
FarmKit.MOD_NAME = g_currentModName or "FS25_FarmKit"
FarmKit.MOD_DIR = g_currentModDirectory or ""

FarmKit.GUI = {
    PROFILES_XML  = "gui/NXGuiProfiles.xml",
    DLG_XML       = "gui/NXFarmKitDlgFrame.xml",
    DLG_LUA       = "gui/NXFarmKitDlgFrame.lua",
    DLG_NAME      = "FarmKitDlgFrame",
    SEED_XML      = "gui/NXSeedDlgFrame.xml",
    SEED_LUA      = "gui/NXSeedDlgFrame.lua",
    SEED_NAME     = "NXSeedDlgFrame"
}

FarmKit.NETWORK_MATERIAL_KEYS = {
    "lime", "fertilizer", "liquidFertilizer", "herbicide",
    "manure", "slurry", "digestate"
}

FarmKit.ORGANIC_NITROGEN_MODE_SOIL = "soil"
FarmKit.ORGANIC_NITROGEN_MODE_PLANT = "plant"
FarmKit.SETTINGS_RELATIVE_PATH = "modSettings/FS25_FarmKit.xml"
FarmKit.FIELD_ENTRY_CACHE_TTL_MS = 5000
FarmKit.SERVER_CACHE_WARMUP_FIELDS_PER_UPDATE = 1

FarmKit.dialogController = nil
FarmKit.isInitialized = false
FarmKit.organicNitrogenMode = FarmKit.ORGANIC_NITROGEN_MODE_SOIL
FarmKit.fieldEntryNetworkCache = {}
FarmKit.fieldEntryServerCache = {}
FarmKit.serverFieldCacheWarmup = nil

function FarmKit:logWarning(message)
    print(string.format("Warning: [%s] %s", self.MOD_NAME, message))
end

function FarmKit:getPath(relativePath)
    return Utils.getFilename(relativePath, self.MOD_DIR)
end

function FarmKit:fileExists(relativePath)
    local fullPath = self:getPath(relativePath)
    return fileExists(fullPath), fullPath
end

function FarmKit:sourceFile(relativePath)
    local exists, fullPath = self:fileExists(relativePath)
    if not exists then
        self:logWarning("Missing source file: " .. relativePath)
        return false
    end
    source(fullPath)
    return true
end

function FarmKit:normalizeOrganicNitrogenMode(mode)
    local safeMode = string.lower(tostring(mode or ""))
    if safeMode == self.ORGANIC_NITROGEN_MODE_PLANT then
        return self.ORGANIC_NITROGEN_MODE_PLANT
    end
    return self.ORGANIC_NITROGEN_MODE_SOIL
end

function FarmKit:getOrganicNitrogenMode()
    return self:normalizeOrganicNitrogenMode(self.organicNitrogenMode)
end

function FarmKit:getSettingsBasePath()
    if type(getUserProfileAppPath) == "function" then
        local userProfilePath = getUserProfileAppPath()
        if userProfilePath ~= nil and userProfilePath ~= "" then
            return userProfilePath
        end
    end

    if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
        local savegameDirectory = g_currentMission.missionInfo.savegameDirectory
        if savegameDirectory ~= nil and savegameDirectory ~= "" then
            return savegameDirectory
        end
    end

    return nil
end

function FarmKit:getSettingsFilePath()
    local base = self:getSettingsBasePath()
    if base == nil or base == "" then return nil end
    return base .. "/" .. self.SETTINGS_RELATIVE_PATH
end

function FarmKit:loadSettings()
    self.organicNitrogenMode = self.ORGANIC_NITROGEN_MODE_SOIL

    local settingsFilePath = self:getSettingsFilePath()
    if settingsFilePath == nil or not fileExists(settingsFilePath) then return end

    local xmlFile = loadXMLFile("nxFarmKitSettingsLoad", settingsFilePath)
    if xmlFile == nil or xmlFile == 0 then return end

    local savedMode = getXMLString(xmlFile, "farmKitSettings.organicNitrogen#mode")
    self.organicNitrogenMode = self:normalizeOrganicNitrogenMode(savedMode)

    delete(xmlFile)
end

function FarmKit:saveSettings()
    local base = self:getSettingsBasePath()
    local settingsFilePath = self:getSettingsFilePath()
    if base == nil or settingsFilePath == nil then return end

    createFolder(base .. "/modSettings")

    local xmlFile = createXMLFile("nxFarmKitSettingsSave", settingsFilePath, "farmKitSettings")
    if xmlFile == nil or xmlFile == 0 then
        self:logWarning("Could not create settings XML")
        return
    end

    setXMLString(xmlFile, "farmKitSettings.organicNitrogen#mode", self:getOrganicNitrogenMode())
    saveXMLFile(xmlFile)
    delete(xmlFile)
end

function FarmKit:applyOrganicNitrogenMode(mode, shouldPersist)
    local normalizedMode = self:normalizeOrganicNitrogenMode(mode)
    self.organicNitrogenMode = normalizedMode

    if shouldPersist == true then
        self:saveSettings()
    end

    if self.dialogController ~= nil and self.dialogController.setOrganicNitrogenMode ~= nil then
        self.dialogController:setOrganicNitrogenMode(normalizedMode)
    end

    return normalizedMode
end

function FarmKit:requestOrganicNitrogenModeChange(mode)
    local normalizedMode = self:normalizeOrganicNitrogenMode(mode)
    self:applyOrganicNitrogenMode(normalizedMode, true)
    self:requestFieldEntriesForDialog()
    return true
end

function FarmKit:getCurrentTimeMs()
    if g_currentMission ~= nil and g_currentMission.time ~= nil then
        return tonumber(g_currentMission.time) or 0
    end
    if rawget(_G, "g_time") ~= nil then
        return tonumber(g_time) or 0
    end
    return math.floor(os.clock() * 1000)
end

function FarmKit:clearFieldEntryCache()
    self.fieldEntryNetworkCache = {}
    self.fieldEntryServerCache = {}
    self.serverFieldCacheWarmup = nil
end

function FarmKit:getCachedFieldEntries(mode)
    local normalizedMode = self:normalizeOrganicNitrogenMode(mode)
    local cacheEntry = type(self.fieldEntryNetworkCache) == "table" and self.fieldEntryNetworkCache[normalizedMode] or nil
    if type(cacheEntry) ~= "table" then return nil end

    local ttlMs = tonumber(self.FIELD_ENTRY_CACHE_TTL_MS) or 0
    if ttlMs > 0 then
        local ageMs = self:getCurrentTimeMs() - (tonumber(cacheEntry.timestamp) or 0)
        if ageMs < 0 or ageMs > ttlMs then
            self.fieldEntryNetworkCache[normalizedMode] = nil
            return nil
        end
    end

    return cacheEntry.entries
end

function FarmKit:setCachedFieldEntries(mode, entries)
    local normalizedMode = self:normalizeOrganicNitrogenMode(mode)
    self.fieldEntryNetworkCache = self.fieldEntryNetworkCache or {}
    self.fieldEntryNetworkCache[normalizedMode] = {
        timestamp = self:getCurrentTimeMs(),
        entries = entries or {}
    }
end

function FarmKit:collectNetworkFields()
    local fields = {}

    if g_fieldManager ~= nil and g_fieldManager.fields ~= nil then
        for _, field in pairs(g_fieldManager.fields) do
            fields[#fields + 1] = field
        end
    end

    if g_fieldManager ~= nil and g_fieldManager.cpCustomFields ~= nil then
        for _, field in pairs(g_fieldManager.cpCustomFields) do
            fields[#fields + 1] = field
        end
    end

    return fields
end

function FarmKit:getNetworkFieldId(field)
    if field == nil or NXFarmKitShared == nil or NXFarmKitShared.getFieldDisplayId == nil then
        return nil
    end

    local fieldId = NXFarmKitShared.getFieldDisplayId(field)
    if fieldId == nil then return nil end

    return tostring(fieldId)
end

function FarmKit:compareNetworkFieldIds(a, b)
    local numericA, numericB = tonumber(a), tonumber(b)
    if numericA ~= nil and numericB ~= nil then
        return numericA < numericB
    end
    return tostring(a or "") < tostring(b or "")
end

function FarmKit:sortNetworkFieldsForProcessing(fields)
    local noOwnerFarmId = FarmlandManager ~= nil and FarmlandManager.NO_OWNER_FARM_ID or 0

    table.sort(fields, function(a, b)
        local farmIdA = NXFarmKitShared ~= nil and NXFarmKitShared.getFarmIdForField ~= nil and NXFarmKitShared.getFarmIdForField(a) or 0
        local farmIdB = NXFarmKitShared ~= nil and NXFarmKitShared.getFarmIdForField ~= nil and NXFarmKitShared.getFarmIdForField(b) or 0
        local isUnownedA = farmIdA == nil or farmIdA == 0 or farmIdA == noOwnerFarmId
        local isUnownedB = farmIdB == nil or farmIdB == 0 or farmIdB == noOwnerFarmId

        if isUnownedA ~= isUnownedB then
            return isUnownedA == true
        end

        if farmIdA ~= farmIdB then
            return (tonumber(farmIdA) or 0) < (tonumber(farmIdB) or 0)
        end

        return self:compareNetworkFieldIds(self:getNetworkFieldId(a), self:getNetworkFieldId(b))
    end)

    return fields
end

function FarmKit:appendScalarFingerprintParts(parts, prefix, sourceTable, allowedKeys)
    if type(sourceTable) ~= "table" then return end

    local keys = {}
    if type(allowedKeys) == "table" then
        for _, key in ipairs(allowedKeys) do
            local valueType = type(sourceTable[key])
            if valueType == "string" or valueType == "number" or valueType == "boolean" then
                keys[#keys + 1] = key
            end
        end
    else
        for key, value in pairs(sourceTable) do
            local keyType, valueType = type(key), type(value)
            if (keyType == "string" or keyType == "number") and (valueType == "string" or valueType == "number" or valueType == "boolean") then
                keys[#keys + 1] = key
            end
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    end

    for _, key in ipairs(keys) do
        local value = sourceTable[key]
        local valueType = type(value)
        if valueType == "number" then
            parts[#parts + 1] = string.format("%s%s=%.6f", prefix, tostring(key), value)
        elseif valueType == "boolean" then
            parts[#parts + 1] = string.format("%s%s=%s", prefix, tostring(key), value and "1" or "0")
        elseif valueType == "string" then
            parts[#parts + 1] = string.format("%s%s=%s", prefix, tostring(key), value)
        end
    end
end

function FarmKit:addHistogramFingerprintValue(histogram, value)
    if type(histogram) ~= "table" or value == nil then return end
    local key = tostring(value)
    histogram[key] = (histogram[key] or 0) + 1
end

function FarmKit:appendHistogramFingerprintParts(parts, prefix, histogram)
    if type(histogram) ~= "table" then return end

    local keys = {}
    for key, value in pairs(histogram) do
        if tonumber(value) ~= nil and tonumber(value) > 0 then
            keys[#keys + 1] = key
        end
    end

    table.sort(keys, function(a, b)
        local numericA, numericB = tonumber(a), tonumber(b)
        if numericA ~= nil and numericB ~= nil then return numericA < numericB end
        return tostring(a) < tostring(b)
    end)

    for _, key in ipairs(keys) do
        parts[#parts + 1] = string.format("%s%s=%d", prefix, tostring(key), math.floor((tonumber(histogram[key]) or 0) + 0.5))
    end
end

function FarmKit:createRuntimeProbeStats()
    return { count = 0, sum = 0, min = nil, max = nil, checksum = 0 }
end

function FarmKit:addRuntimeProbeStat(stats, value, pointIndex)
    if type(stats) ~= "table" then return end

    local numericValue = tonumber(value)
    if numericValue == nil then return end

    local quantizedValue = numericValue >= 0
        and math.floor(numericValue * 1000 + 0.5)
        or math.ceil(numericValue * 1000 - 0.5)

    stats.count = (stats.count or 0) + 1
    stats.sum = (stats.sum or 0) + quantizedValue
    stats.checksum = (stats.checksum or 0) + (quantizedValue * (tonumber(pointIndex) or 1))

    if stats.min == nil or quantizedValue < stats.min then stats.min = quantizedValue end
    if stats.max == nil or quantizedValue > stats.max then stats.max = quantizedValue end
end

function FarmKit:appendRuntimeProbeStats(parts, prefix, stats)
    if type(stats) ~= "table" or (tonumber(stats.count) or 0) <= 0 then return end

    parts[#parts + 1] = string.format("%scount=%d",    prefix, tonumber(stats.count) or 0)
    parts[#parts + 1] = string.format("%ssum=%d",      prefix, tonumber(stats.sum) or 0)
    parts[#parts + 1] = string.format("%smin=%d",      prefix, tonumber(stats.min) or 0)
    parts[#parts + 1] = string.format("%smax=%d",      prefix, tonumber(stats.max) or 0)
    parts[#parts + 1] = string.format("%schecksum=%d", prefix, tonumber(stats.checksum) or 0)
end

function FarmKit:appendPrecisionFarmingFingerprintParts(parts, field)
    if rawget(_G, "NXFarmKitPF") == nil
        or NXFarmKitShared == nil
        or NXFarmKitShared.getIsPrecisionFarmingActive == nil
        or not NXFarmKitShared.getIsPrecisionFarmingActive() then
        return
    end

    if NXFarmKitPF.getFruitContext ~= nil then
        local fruitTypeName, fruitTypeIndex = NXFarmKitPF.getFruitContext(field)
        if fruitTypeName ~= nil then parts[#parts + 1] = string.format("pfFruit=%s", tostring(fruitTypeName)) end
        if fruitTypeIndex ~= nil then parts[#parts + 1] = string.format("pfFruitIndex=%s", tostring(fruitTypeIndex)) end
    end

    local runtimeMaps = NXFarmKitPF.getRuntimeMaps ~= nil and NXFarmKitPF.getRuntimeMaps() or nil
    if runtimeMaps == nil then return end

    local samplePoints = NXFarmKitShared.getFieldSamplePoints ~= nil and NXFarmKitShared.getFieldSamplePoints(field) or nil
    if type(samplePoints) ~= "table" or #samplePoints <= 0 then
        if NXFarmKitShared.getFieldCenterWorldPosition ~= nil then
            local centerX, centerZ = NXFarmKitShared.getFieldCenterWorldPosition(field)
            if centerX ~= nil and centerZ ~= nil then
                samplePoints = { { x = centerX, z = centerZ } }
            end
        end
    end

    if type(samplePoints) ~= "table" or #samplePoints <= 0 then return end

    parts[#parts + 1] = string.format("pfProbeCount=%d", #samplePoints)

    local pHStats = self:createRuntimeProbeStats()
    local nitrogenStats = self:createRuntimeProbeStats()
    local coverHistogram, groundHistogram = {}, {}
    local coverAccessorName, groundMapData = nil, nil

    if runtimeMaps.coverMap ~= nil
        and NXFarmKitPF.resolveRuntimeCoverAccessor ~= nil
        and NXFarmKitPF.getRuntimeCoverValueAtWorldPos ~= nil then
        coverAccessorName = NXFarmKitPF.resolveRuntimeCoverAccessor(runtimeMaps.coverMap)
    end

    if NXFarmKitPF.getRuntimeGroundTypeMapData ~= nil
        and NXFarmKitPF.getRuntimeGroundTypeValueAtWorldPos ~= nil then
        groundMapData = NXFarmKitPF.getRuntimeGroundTypeMapData()
    end

    for pointIndex, point in ipairs(samplePoints) do
        local pointX, pointZ = point ~= nil and point.x, point ~= nil and point.z
        if pointX ~= nil and pointZ ~= nil then
            if runtimeMaps.pHMap ~= nil and runtimeMaps.pHMap.getLevelAtWorldPos ~= nil then
                local success, pHLevel = pcall(runtimeMaps.pHMap.getLevelAtWorldPos, runtimeMaps.pHMap, pointX, pointZ)
                if success and pHLevel ~= nil then self:addRuntimeProbeStat(pHStats, pHLevel, pointIndex) end
            end

            if runtimeMaps.nitrogenMap ~= nil and runtimeMaps.nitrogenMap.getLevelAtWorldPos ~= nil then
                local success, nitrogenLevel = pcall(runtimeMaps.nitrogenMap.getLevelAtWorldPos, runtimeMaps.nitrogenMap, pointX, pointZ)
                if success and nitrogenLevel ~= nil then self:addRuntimeProbeStat(nitrogenStats, nitrogenLevel, pointIndex) end
            end

            if coverAccessorName ~= nil then
                self:addHistogramFingerprintValue(coverHistogram, NXFarmKitPF.getRuntimeCoverValueAtWorldPos(runtimeMaps.coverMap, coverAccessorName, pointX, pointZ))
            end

            if groundMapData ~= nil then
                self:addHistogramFingerprintValue(groundHistogram, NXFarmKitPF.getRuntimeGroundTypeValueAtWorldPos(groundMapData, pointX, pointZ))
            end
        end
    end

    self:appendRuntimeProbeStats(parts, "pfPH.", pHStats)
    self:appendRuntimeProbeStats(parts, "pfN.", nitrogenStats)
    self:appendHistogramFingerprintParts(parts, "pfCover.", coverHistogram)
    self:appendHistogramFingerprintParts(parts, "pfGround.", groundHistogram)
end

function FarmKit:getFieldNetworkFingerprint(field)
    local parts = {}
    local areaHa = NXFarmKitShared ~= nil and NXFarmKitShared.getFieldAreaHa ~= nil and NXFarmKitShared.getFieldAreaHa(field) or 0
    local farmId = NXFarmKitShared ~= nil and NXFarmKitShared.getFarmIdForField ~= nil and NXFarmKitShared.getFarmIdForField(field) or 0

    parts[#parts + 1] = string.format("field=%s", tostring(self:getNetworkFieldId(field) or ""))
    parts[#parts + 1] = string.format("farm=%s", tostring(farmId or 0))
    parts[#parts + 1] = string.format("area=%.6f", tonumber(areaHa) or 0)

    if type(field) == "table" and type(field.farmland) == "table" and field.farmland.id ~= nil then
        parts[#parts + 1] = string.format("farmlandId=%s", tostring(field.farmland.id))
    end

    local scalarKeys = {
        "currentFruitTypeName", "fruitTypeName", "currentCropTypeName", "cropTypeName",
        "currentFruitTypeIndex", "fruitTypeIndex", "currentGrowthState", "growthState",
        "fruitState", "sprayFactor", "sprayLevel", "weedFactor", "weedState",
        "needsRolling", "needsPlowing", "needsLime", "isHarvested", "isPlanted"
    }
    self:appendScalarFingerprintParts(parts, "field.", field, scalarKeys)

    if field ~= nil and field.getFieldState ~= nil then
        local success, fieldState = pcall(field.getFieldState, field)
        if success and type(fieldState) == "table" then
            local stateKeys = {}
            for _, k in ipairs(scalarKeys) do stateKeys[#stateKeys + 1] = k end
            stateKeys[#stateKeys + 1] = "isSampled"
            stateKeys[#stateKeys + 1] = "sampled"
            stateKeys[#stateKeys + 1] = "coverValue"
            stateKeys[#stateKeys + 1] = "soilTypeIndex"
            stateKeys[#stateKeys + 1] = "groundTypeIndex"
            stateKeys[#stateKeys + 1] = "phState"
            stateKeys[#stateKeys + 1] = "nitrogenState"
            stateKeys[#stateKeys + 1] = "limeState"
            stateKeys[#stateKeys + 1] = "fertilizerState"
            self:appendScalarFingerprintParts(parts, "state.", fieldState, stateKeys)
        end
    end

    self:appendPrecisionFarmingFingerprintParts(parts, field)

    return table.concat(parts, "|")
end

function FarmKit:getServerFieldEntryCache(mode)
    local normalizedMode = self:normalizeOrganicNitrogenMode(mode)
    self.fieldEntryServerCache = self.fieldEntryServerCache or {}

    local cacheEntry = self.fieldEntryServerCache[normalizedMode]
    if type(cacheEntry) ~= "table" then
        cacheEntry = { entriesByFieldId = {}, fingerprintsByFieldId = {}, orderedFieldIds = {} }
        self.fieldEntryServerCache[normalizedMode] = cacheEntry
    end

    return cacheEntry
end

function FarmKit:buildFieldEntryForMode(field, mode)
    local requestedMode = self:normalizeOrganicNitrogenMode(mode or self:getOrganicNitrogenMode())
    local previousMode = self.organicNitrogenMode
    self.organicNitrogenMode = requestedMode

    local entry = nil
    if NXFarmKitShared ~= nil and NXFarmKitShared.buildFieldEntry ~= nil then
        entry = NXFarmKitShared.buildFieldEntry(field)
    end

    self.organicNitrogenMode = previousMode
    return entry
end

function FarmKit:refreshServerFieldCacheForField(mode, field, forceRefresh)
    local fieldId = self:getNetworkFieldId(field)
    if fieldId == nil or fieldId == "" then return nil, false end

    local cacheEntry = self:getServerFieldEntryCache(mode)
    local fingerprint = self:getFieldNetworkFingerprint(field)

    if forceRefresh ~= true
        and cacheEntry.entriesByFieldId[fieldId] ~= nil
        and cacheEntry.fingerprintsByFieldId[fieldId] == fingerprint then
        return fieldId, false
    end

    cacheEntry.entriesByFieldId[fieldId] = self:buildFieldEntryForMode(field, mode)
    cacheEntry.fingerprintsByFieldId[fieldId] = fingerprint
    return fieldId, true
end

function FarmKit:prepareServerFieldCacheWarmup(mode)
    local requestedMode = self:normalizeOrganicNitrogenMode(mode or self:getOrganicNitrogenMode())
    local fields = self:collectNetworkFields()
    self:sortNetworkFieldsForProcessing(fields)

    local warmupModes = { requestedMode }
    if NXFarmKitShared ~= nil
        and NXFarmKitShared.getIsPrecisionFarmingActive ~= nil
        and NXFarmKitShared.getIsPrecisionFarmingActive() then
        warmupModes[#warmupModes + 1] = requestedMode == self.ORGANIC_NITROGEN_MODE_SOIL
            and self.ORGANIC_NITROGEN_MODE_PLANT
            or self.ORGANIC_NITROGEN_MODE_SOIL
    end

    self.serverFieldCacheWarmup = {
        mode = requestedMode,
        modes = warmupModes,
        fields = fields,
        nextFieldIndex = 1,
        nextModeIndex = 1,
        finished = #fields == 0 or #warmupModes == 0
    }
end

function FarmKit:updateServerFieldCacheWarmup(dt)
    if g_server == nil then return end

    if self.serverFieldCacheWarmup == nil then
        self:prepareServerFieldCacheWarmup(self:getOrganicNitrogenMode())
    end

    local state = self.serverFieldCacheWarmup
    if state == nil or state.finished == true then return end

    local remaining = tonumber(self.SERVER_CACHE_WARMUP_FIELDS_PER_UPDATE) or 0
    while remaining > 0 and state.nextFieldIndex <= #state.fields do
        local warmupMode = state.modes[state.nextModeIndex] or self:getOrganicNitrogenMode()
        local field = state.fields[state.nextFieldIndex]

        self:refreshServerFieldCacheForField(warmupMode, field, false)

        state.nextModeIndex = state.nextModeIndex + 1
        if state.nextModeIndex > #state.modes then
            state.nextModeIndex = 1
            state.nextFieldIndex = state.nextFieldIndex + 1
        end

        remaining = remaining - 1
    end

    if state.nextFieldIndex > #state.fields then
        state.finished = true
    end
end

function FarmKit:getFieldEntriesForNetwork(mode, forceRefresh)
    local requestedMode = self:normalizeOrganicNitrogenMode(mode or self:getOrganicNitrogenMode())

    if g_server == nil then
        local entries = {}
        if NXFarmKitShared ~= nil and NXFarmKitShared.collectFieldEntries ~= nil then
            local previousMode = self.organicNitrogenMode
            self.organicNitrogenMode = requestedMode
            entries = NXFarmKitShared.collectFieldEntries()
            self.organicNitrogenMode = previousMode
        end
        return entries or {}
    end

    local cacheEntry = self:getServerFieldEntryCache(requestedMode)
    local fields = self:collectNetworkFields()
    self:sortNetworkFieldsForProcessing(fields)

    local activeFieldIds, orderedFieldIds = {}, {}
    for _, field in ipairs(fields) do
        local fieldId = self:refreshServerFieldCacheForField(requestedMode, field, forceRefresh)
        if fieldId ~= nil and fieldId ~= "" then
            activeFieldIds[fieldId] = true
            orderedFieldIds[#orderedFieldIds + 1] = fieldId
        end
    end

    for fieldId, _ in pairs(cacheEntry.entriesByFieldId) do
        if activeFieldIds[fieldId] ~= true then
            cacheEntry.entriesByFieldId[fieldId] = nil
            cacheEntry.fingerprintsByFieldId[fieldId] = nil
        end
    end

    cacheEntry.orderedFieldIds = orderedFieldIds

    local entries = {}
    for _, fieldId in ipairs(orderedFieldIds) do
        local entry = cacheEntry.entriesByFieldId[fieldId]
        if entry ~= nil then entries[#entries + 1] = entry end
    end

    return entries
end

function FarmKit:getCustomMaterialDefinitionByKey(materialKey)
    if materialKey == nil or NXFarmKitShared == nil or NXFarmKitShared.getCustomMapFertilizerDefinitions == nil then
        return nil
    end

    for _, definition in ipairs(NXFarmKitShared.getCustomMapFertilizerDefinitions()) do
        if definition ~= nil and definition.key == materialKey then return definition end
    end

    return nil
end

function FarmKit:getFirstCustomMaterialForNetwork(entry)
    if type(entry) ~= "table" or type(entry.customMaterials) ~= "table" then return nil, nil, nil end

    local materialKeys = {}
    for materialKey, material in pairs(entry.customMaterials) do
        if material ~= nil then materialKeys[#materialKeys + 1] = materialKey end
    end
    table.sort(materialKeys, function(a, b) return tostring(a) < tostring(b) end)

    for _, materialKey in ipairs(materialKeys) do
        local material = entry.customMaterials[materialKey]
        if material ~= nil then
            local fillTypeName = material.fillTypeName
            if fillTypeName == nil or fillTypeName == "" then
                local definition = self:getCustomMaterialDefinitionByKey(materialKey)
                if definition ~= nil then fillTypeName = definition.sprayType end
            end
            return materialKey, fillTypeName, material
        end
    end

    return nil, nil, nil
end

function FarmKit:writeFieldEntriesToStream(streamId, entries)
    local safeEntries = entries or {}
    streamWriteInt32(streamId, #safeEntries)

    for _, entry in ipairs(safeEntries) do
        streamWriteString(streamId, tostring(entry.fieldId or ""))
        streamWriteInt32(streamId, tonumber(entry.farmId) or 0)
        streamWriteFloat32(streamId, tonumber(entry.areaHa) or 0)
        streamWriteBool(streamId, entry.isPrecisionFarming == true)

        for _, materialKey in ipairs(self.NETWORK_MATERIAL_KEYS) do
            local material = (entry.materials ~= nil and entry.materials[materialKey]) or nil
            streamWriteFloat32(streamId, tonumber(material ~= nil and material.litersPerSecond or 0) or 0)
            streamWriteFloat32(streamId, tonumber(material ~= nil and material.litersPerHa or 0) or 0)
            streamWriteFloat32(streamId, tonumber(material ~= nil and material.totalLiters or 0) or 0)
        end

        local customMaterialKey, customFillTypeName, customMaterial = self:getFirstCustomMaterialForNetwork(entry)
        streamWriteBool(streamId, customMaterial ~= nil)

        if customMaterial ~= nil then
            streamWriteString(streamId, tostring(customMaterialKey or ""))
            streamWriteString(streamId, tostring(customFillTypeName or ""))
            streamWriteFloat32(streamId, tonumber(customMaterial.litersPerSecond) or 0)
            streamWriteFloat32(streamId, tonumber(customMaterial.litersPerHa) or 0)
            streamWriteFloat32(streamId, tonumber(customMaterial.totalLiters) or 0)
        end
    end
end

function FarmKit:readFieldEntriesFromStream(streamId)
    local entries = {}
    local numEntries = streamReadInt32(streamId)

    for entryIndex = 1, numEntries do
        local entry = {
            fieldId = streamReadString(streamId),
            rawField = nil,
            farmId = streamReadInt32(streamId),
            areaHa = streamReadFloat32(streamId),
            materials = {},
            customMaterials = {},
            isPrecisionFarming = streamReadBool(streamId)
        }

        for _, materialKey in ipairs(self.NETWORK_MATERIAL_KEYS) do
            entry.materials[materialKey] = {
                litersPerSecond = streamReadFloat32(streamId),
                litersPerHa = streamReadFloat32(streamId),
                totalLiters = streamReadFloat32(streamId)
            }
        end

        local hasCustomMaterial = streamReadBool(streamId)
        if hasCustomMaterial then
            local customMaterialKey = streamReadString(streamId)
            local customFillTypeName = streamReadString(streamId)
            entry.customMaterials[customMaterialKey] = {
                fillTypeName = customFillTypeName,
                litersPerSecond = streamReadFloat32(streamId),
                litersPerHa = streamReadFloat32(streamId),
                totalLiters = streamReadFloat32(streamId)
            }
        end

        entries[entryIndex] = entry
    end

    return entries
end

function FarmKit:applyFieldEntries(entries, organicNitrogenMode)
    if organicNitrogenMode ~= nil then
        self:applyOrganicNitrogenMode(organicNitrogenMode, false)
    end

    local activeMode = self:getOrganicNitrogenMode()
    self:setCachedFieldEntries(activeMode, entries or {})

    if self.dialogController ~= nil and self.dialogController.setFieldEntries ~= nil then
        self.dialogController:setFieldEntries(entries or {}, activeMode)
    end
end

function FarmKit:sendFieldEntriesToConnection(connection, organicNitrogenMode)
    if connection == nil or FarmKitFieldDataResponseEvent == nil then return end

    local requestedMode = self:normalizeOrganicNitrogenMode(organicNitrogenMode)
    local entries = self:getFieldEntriesForNetwork(requestedMode)

    connection:sendEvent(FarmKitFieldDataResponseEvent.new(entries, requestedMode))
end

function FarmKit:requestFieldEntriesForDialog()
    if self.dialogController ~= nil and self.dialogController.prepareForFieldDataRequest ~= nil then
        self.dialogController:prepareForFieldDataRequest()
    end

    local requestedMode = self:getOrganicNitrogenMode()

    if self.dialogController ~= nil and self.dialogController.setOrganicNitrogenMode ~= nil then
        self.dialogController:setOrganicNitrogenMode(requestedMode)
    end

    if g_server ~= nil then
        self:applyFieldEntries(self:getFieldEntriesForNetwork(requestedMode), requestedMode)
        return
    end

    if g_client ~= nil and g_client.getServerConnection ~= nil and FarmKitFieldDataRequestEvent ~= nil then
        local serverConnection = g_client:getServerConnection()
        if serverConnection ~= nil then
            serverConnection:sendEvent(FarmKitFieldDataRequestEvent.new(requestedMode))
            return
        end
    end

    self:applyFieldEntries({}, requestedMode)
end

FarmKitFieldDataRequestEvent = {}
local FarmKitFieldDataRequestEvent_mt = Class(FarmKitFieldDataRequestEvent, Event)
InitEventClass(FarmKitFieldDataRequestEvent, "FarmKitFieldDataRequestEvent")

function FarmKitFieldDataRequestEvent.emptyNew()
    local self = Event.new(FarmKitFieldDataRequestEvent_mt)
    self.organicNitrogenMode = "soil"
    return self
end

function FarmKitFieldDataRequestEvent.new(organicNitrogenMode)
    local self = FarmKitFieldDataRequestEvent.emptyNew()
    self.organicNitrogenMode = FarmKit:normalizeOrganicNitrogenMode(organicNitrogenMode)
    return self
end

function FarmKitFieldDataRequestEvent:readStream(streamId, connection)
    self.organicNitrogenMode = streamReadString(streamId)
    self:run(connection)
end

function FarmKitFieldDataRequestEvent:writeStream(streamId, connection)
    streamWriteString(streamId, tostring(self.organicNitrogenMode or "soil"))
end

function FarmKitFieldDataRequestEvent:run(connection)
    if connection ~= nil and not connection:getIsServer() then
        FarmKit:sendFieldEntriesToConnection(connection, self.organicNitrogenMode)
    end
end

FarmKitFieldDataResponseEvent = {}
local FarmKitFieldDataResponseEvent_mt = Class(FarmKitFieldDataResponseEvent, Event)
InitEventClass(FarmKitFieldDataResponseEvent, "FarmKitFieldDataResponseEvent")

function FarmKitFieldDataResponseEvent.emptyNew()
    local self = Event.new(FarmKitFieldDataResponseEvent_mt)
    self.entries = {}
    self.organicNitrogenMode = "soil"
    return self
end

function FarmKitFieldDataResponseEvent.new(entries, organicNitrogenMode)
    local self = FarmKitFieldDataResponseEvent.emptyNew()
    self.entries = entries or {}
    self.organicNitrogenMode = FarmKit:normalizeOrganicNitrogenMode(organicNitrogenMode)
    return self
end

function FarmKitFieldDataResponseEvent:readStream(streamId, connection)
    self.organicNitrogenMode = streamReadString(streamId)
    self.entries = FarmKit:readFieldEntriesFromStream(streamId)
    self:run(connection)
end

function FarmKitFieldDataResponseEvent:writeStream(streamId, connection)
    streamWriteString(streamId, tostring(self.organicNitrogenMode or "soil"))
    FarmKit:writeFieldEntriesToStream(streamId, self.entries)
end

function FarmKitFieldDataResponseEvent:run(connection)
    if connection ~= nil and connection:getIsServer() then
        FarmKit:applyFieldEntries(self.entries, self.organicNitrogenMode)
    end
end

function FarmKit:ShowFarmKitDlg(actionName, keyStatus)
    if not FarmKit.isInitialized or FarmKit.dialogController == nil then return end
    if g_gui == nil then return end

    g_gui:showDialog(FarmKit.GUI.DLG_NAME)
end

function FarmKit:loadMap()
    if self.isInitialized then return end

    self:sourceFile("scripts/NXFarmKitShared.lua")
    self:sourceFile("scripts/NXFarmKitPF.lua")
    self:sourceFile(self.GUI.DLG_LUA)
    self:sourceFile(self.GUI.SEED_LUA)

    self:loadSettings()
    self:clearFieldEntryCache()

    if g_server ~= nil then
        self:prepareServerFieldCacheWarmup(self:getOrganicNitrogenMode())
    end

    local dialogClass = rawget(_G, "FarmKitDlgFrame")
    if type(dialogClass) ~= "table" or type(dialogClass.new) ~= "function" then
        self:logWarning("Dialog class missing")
        return
    end

    g_gui:loadProfiles(self:getPath(self.GUI.PROFILES_XML))

    self.dialogController = dialogClass.new(nil, g_i18n)
    g_gui:loadGui(self:getPath(self.GUI.DLG_XML), self.GUI.DLG_NAME, self.dialogController)

    local seedClass = rawget(_G, "NXSeedDlgFrame")
    if type(seedClass) == "table" and type(seedClass.new) == "function" then
        self.seedDialogController = seedClass.new(nil, g_i18n)
        g_gui:loadGui(self:getPath(self.GUI.SEED_XML), self.GUI.SEED_NAME, self.seedDialogController)
    else
        self:logWarning("Seed dialog class missing")
    end

    self.isInitialized = true
end

function FarmKit:update(dt)
    if not self.isInitialized then return end
    if g_server ~= nil then
        self:updateServerFieldCacheWarmup(dt)
    end
end

function FarmKit:deleteMap()
    self:clearFieldEntryCache()
    self.dialogController = nil
    self.isInitialized = false
end

addModEventListener(FarmKit)

PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
    PlayerInputComponent.registerGlobalPlayerActionEvents,
    function(self, controlling)
        local _, actionEventId = g_inputBinding:registerActionEvent(
            InputAction.SHOW_FARMKIT_DLG,
            FarmKit,
            FarmKit.ShowFarmKitDlg,
            false, true, false, true, nil, true
        )

        if actionEventId ~= nil then
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
            g_inputBinding:setActionEventTextVisibility(actionEventId, true)
        end
    end
)
