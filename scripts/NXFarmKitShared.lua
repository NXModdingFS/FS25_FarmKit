NXFarmKitShared = NXFarmKitShared or {}

function NXFarmKitShared.getSafeNumber(value)
    local number = tonumber(value) or 0
    if number < 0 then
        return 0
    end

    return number
end

function NXFarmKitShared.round(value, decimals)
    local factor = 10 ^ (tonumber(decimals) or 0)
    return math.floor((tonumber(value) or 0) * factor + 0.5) / factor
end

function NXFarmKitShared.getCurrentPlayerFarmId()
    if g_currentMission == nil or g_farmManager == nil then
        return FarmlandManager ~= nil and FarmlandManager.NO_OWNER_FARM_ID or 0
    end

    local farm = nil

    if g_currentMission.playerUserId ~= nil and g_farmManager.getFarmByUserId ~= nil then
        farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
    end

    if farm ~= nil and farm.farmId ~= nil then
        return farm.farmId
    end

    return FarmlandManager ~= nil and FarmlandManager.NO_OWNER_FARM_ID or 0
end

function NXFarmKitShared.getFarmIdForField(field)
    if field ~= nil and field.farmland ~= nil and field.farmland.id ~= nil and g_farmlandManager ~= nil and g_farmlandManager.getFarmlandOwner ~= nil then
        local ownerFarmId = g_farmlandManager:getFarmlandOwner(field.farmland.id)
        if ownerFarmId ~= nil then
            return ownerFarmId
        end
    end

    return NXFarmKitShared.getCurrentPlayerFarmId()
end

function NXFarmKitShared.getTextOrFallback(key, fallback)
    if g_i18n ~= nil and g_i18n.hasText ~= nil and g_i18n:hasText(key) then
        return g_i18n:getText(key)
    end

    return tostring(fallback or "")
end

function NXFarmKitShared.getFarmLabelText()
    local fallback = "Farm"
    if tostring(g_languageSuffix or "_en") == "_de" then
        fallback = "Hof"
    end

    return NXFarmKitShared.getTextOrFallback("ui_farm", fallback)
end

function NXFarmKitShared.getFarmTitle(farmId)
    if FarmlandManager ~= nil and farmId == FarmlandManager.NO_OWNER_FARM_ID then
        return NXFarmKitShared.getTextOrFallback("ui_farmlandUnowned", "Unowned")
    end

    return NXFarmKitShared.getTextOrFallback("nx_section_yourFarm", "Your Farm")
end

function NXFarmKitShared.getFieldDisplayId(field)
    if field == nil then
        return "-"
    end

    if field.getId ~= nil then
        local fieldId = field:getId()
        if fieldId ~= nil then
            return tostring(fieldId)
        end
    end

    if field.fieldId ~= nil then
        return tostring(field.fieldId)
    end

    if field.id ~= nil then
        return tostring(field.id)
    end

    if field.fieldIndex ~= nil then
        return tostring(field.fieldIndex)
    end

    return "-"
end

function NXFarmKitShared.getFieldAreaHa(field)
    if field == nil then
        return 0
    end

    if field.getAreaHa ~= nil then
        return NXFarmKitShared.getSafeNumber(field:getAreaHa())
    end

    if field.fieldArea ~= nil then
        return NXFarmKitShared.getSafeNumber(field.fieldArea)
    end

    if field.areaHa ~= nil then
        return NXFarmKitShared.getSafeNumber(field.areaHa)
    end

    if field.areaInHa ~= nil then
        return NXFarmKitShared.getSafeNumber(field.areaInHa)
    end

    if field.farmland ~= nil and field.farmland.areaInHa ~= nil then
        return NXFarmKitShared.getSafeNumber(field.farmland.areaInHa)
    end

    return 0
end

function NXFarmKitShared.getFieldCenterWorldPosition(field)
    if field == nil then
        return nil, nil
    end

    if field.getCenterOfFieldWorldPosition ~= nil then
        local centerX, centerZ = field:getCenterOfFieldWorldPosition()
        if centerX ~= nil and centerZ ~= nil then
            return centerX, centerZ
        end
    end

    if field.posX ~= nil and field.posZ ~= nil then
        return field.posX, field.posZ
    end

    if field.x ~= nil and field.z ~= nil then
        return field.x, field.z
    end

    return nil, nil
end

function NXFarmKitShared.getFieldDensityMapPolygon(field)
    if field == nil or field.getDensityMapPolygon == nil then
        return nil
    end

    local success, polygon = pcall(field.getDensityMapPolygon, field)
    if success and polygon ~= nil then
        return polygon
    end

    return nil
end

NXFarmKitShared.FIELD_SAMPLE_TARGET_COUNT = 64
NXFarmKitShared.FIELD_SAMPLE_MAX_COUNT = 128
NXFarmKitShared.FIELD_SAMPLE_MIN_STEP = 4
NXFarmKitShared.FIELD_SAMPLE_MAX_STEP = 16
NXFarmKitShared._fieldWorldPolygonCache = NXFarmKitShared._fieldWorldPolygonCache or {}
NXFarmKitShared._fieldSamplePointsCache = NXFarmKitShared._fieldSamplePointsCache or {}

function NXFarmKitShared.getFieldCacheKey(field)
    local rootNode = NXFarmKitShared.getFieldRootNode(field)
    if rootNode ~= nil and rootNode ~= 0 then
        return string.format("root:%s", tostring(rootNode))
    end

    local fieldId = NXFarmKitShared.getFieldDisplayId(field)
    if fieldId ~= nil and fieldId ~= "" and fieldId ~= "-" then
        return string.format("field:%s", tostring(fieldId))
    end

    return nil
end

function NXFarmKitShared.clearFieldSamplingCache()
    NXFarmKitShared._fieldWorldPolygonCache = {}
    NXFarmKitShared._fieldSamplePointsCache = {}
end

function NXFarmKitShared.getFieldRootNode(field)
    if field == nil then
        return nil
    end

    if field.rootNode ~= nil and field.rootNode ~= 0 then
        return field.rootNode
    end

    if field.fieldDimensions ~= nil and field.fieldDimensions ~= 0 then
        return field.fieldDimensions
    end

    return nil
end

function NXFarmKitShared.getNodeName(node)
    if node == nil or node == 0 or getName == nil then
        return nil
    end

    local success, name = pcall(getName, node)
    if success then
        return name
    end

    return nil
end

function NXFarmKitShared.getNodeWorldPosition(node)
    if node == nil or node == 0 or getWorldTranslation == nil then
        return nil, nil
    end

    local success, x, _, z = pcall(getWorldTranslation, node)
    if success then
        return x, z
    end

    return nil, nil
end

function NXFarmKitShared.findChildByNameRecursive(node, wantedName, depth)
    depth = depth or 0

    if node == nil or node == 0 or depth > 6 then
        return nil
    end

    if getNumOfChildren == nil or getChildAt == nil then
        return nil
    end

    local childCount = getNumOfChildren(node)
    for childIndex = 0, childCount - 1 do
        local childNode = getChildAt(node, childIndex)
        if childNode ~= nil and childNode ~= 0 then
            if NXFarmKitShared.getNodeName(childNode) == wantedName then
                return childNode
            end

            local foundNode = NXFarmKitShared.findChildByNameRecursive(childNode, wantedName, depth + 1)
            if foundNode ~= nil then
                return foundNode
            end
        end
    end

    return nil
end

function NXFarmKitShared.getFieldWorldPolygonData(field)
    local cacheKey = NXFarmKitShared.getFieldCacheKey(field)
    if cacheKey ~= nil then
        local cachedData = NXFarmKitShared._fieldWorldPolygonCache[cacheKey]
        if cachedData ~= nil then
            return cachedData ~= false and cachedData or nil
        end
    end

    local rootNode = NXFarmKitShared.getFieldRootNode(field)
    if rootNode == nil or rootNode == 0 then
        if cacheKey ~= nil then
            NXFarmKitShared._fieldWorldPolygonCache[cacheKey] = false
        end
        return nil
    end

    local polygonPointsNode = NXFarmKitShared.findChildByNameRecursive(rootNode, "polygonPoints", 0)
    if polygonPointsNode == nil or polygonPointsNode == 0 then
        if cacheKey ~= nil then
            NXFarmKitShared._fieldWorldPolygonCache[cacheKey] = false
        end
        return nil
    end

    if getNumOfChildren == nil or getChildAt == nil then
        if cacheKey ~= nil then
            NXFarmKitShared._fieldWorldPolygonCache[cacheKey] = false
        end
        return nil
    end

    local points = {}
    local minX, maxX, minZ, maxZ
    local childCount = getNumOfChildren(polygonPointsNode)

    for childIndex = 0, childCount - 1 do
        local childNode = getChildAt(polygonPointsNode, childIndex)
        if childNode ~= nil and childNode ~= 0 then
            local x, z = NXFarmKitShared.getNodeWorldPosition(childNode)
            if x ~= nil and z ~= nil then
                points[#points + 1] = { x = x, z = z }

                if minX == nil or x < minX then
                    minX = x
                end
                if maxX == nil or x > maxX then
                    maxX = x
                end
                if minZ == nil or z < minZ then
                    minZ = z
                end
                if maxZ == nil or z > maxZ then
                    maxZ = z
                end
            end
        end
    end

    if #points < 3 then
        if cacheKey ~= nil then
            NXFarmKitShared._fieldWorldPolygonCache[cacheKey] = false
        end
        return nil
    end

    local polygonData = {
        points = points,
        minX = minX,
        maxX = maxX,
        minZ = minZ,
        maxZ = maxZ
    }

    if cacheKey ~= nil then
        NXFarmKitShared._fieldWorldPolygonCache[cacheKey] = polygonData
    end

    return polygonData
end

function NXFarmKitShared.getIsPointInsideWorldPolygon(x, z, polygonPoints)
    if polygonPoints == nil or #polygonPoints < 3 then
        return false
    end

    local isInside = false
    local pointCount = #polygonPoints
    local previousIndex = pointCount

    for pointIndex = 1, pointCount do
        local currentPoint = polygonPoints[pointIndex]
        local previousPoint = polygonPoints[previousIndex]

        local intersects = ((currentPoint.z > z) ~= (previousPoint.z > z))
        if intersects then
            local zDelta = previousPoint.z - currentPoint.z
            if zDelta ~= 0 then
                local crossX = (previousPoint.x - currentPoint.x) * (z - currentPoint.z) / zDelta + currentPoint.x
                if x < crossX then
                    isInside = not isInside
                end
            end
        end

        previousIndex = pointIndex
    end

    return isInside
end

function NXFarmKitShared.getFieldSamplePoints(field)
    if field == nil then
        return {}
    end

    local cacheKey = NXFarmKitShared.getFieldCacheKey(field)
    if cacheKey ~= nil then
        local cachedPoints = NXFarmKitShared._fieldSamplePointsCache[cacheKey]
        if cachedPoints ~= nil then
            return cachedPoints ~= false and cachedPoints or {}
        end
    end

    local polygonData = NXFarmKitShared.getFieldWorldPolygonData(field)
    if polygonData ~= nil then
        local areaSqm = NXFarmKitShared.getFieldAreaHa(field) * 10000
        local targetCount = math.max(1, math.floor(NXFarmKitShared.getSafeNumber(NXFarmKitShared.FIELD_SAMPLE_TARGET_COUNT)))
        local maxCount = math.max(targetCount, math.floor(NXFarmKitShared.getSafeNumber(NXFarmKitShared.FIELD_SAMPLE_MAX_COUNT)))
        local minStep = math.max(1, NXFarmKitShared.getSafeNumber(NXFarmKitShared.FIELD_SAMPLE_MIN_STEP))
        local maxStep = math.max(minStep, NXFarmKitShared.getSafeNumber(NXFarmKitShared.FIELD_SAMPLE_MAX_STEP))
        local step = math.sqrt(math.max(areaSqm, 1) / targetCount)

        if step < minStep then
            step = minStep
        elseif step > maxStep then
            step = maxStep
        end

        local hardLimitStep = math.sqrt(math.max(areaSqm, 1) / maxCount)
        if hardLimitStep > step then
            step = hardLimitStep
        end

        local startX = math.floor(polygonData.minX / step) * step
        local endX = math.ceil(polygonData.maxX / step) * step
        local startZ = math.floor(polygonData.minZ / step) * step
        local endZ = math.ceil(polygonData.maxZ / step) * step
        local points = {}
        local z = startZ

        while z <= endZ do
            local x = startX

            while x <= endX do
                local sampleX = x + step * 0.5
                local sampleZ = z + step * 0.5

                if NXFarmKitShared.getIsPointInsideWorldPolygon(sampleX, sampleZ, polygonData.points) then
                    points[#points + 1] = { x = sampleX, z = sampleZ }
                end

                x = x + step
            end

            z = z + step
        end

        if #points > maxCount then
            local limitedPoints = {}
            local pointCount = #points
            local lastSourceIndex = 0

            for limitedIndex = 1, maxCount do
                local sourceIndex = math.floor(((limitedIndex - 0.5) * pointCount / maxCount) + 0.5)
                if sourceIndex < 1 then
                    sourceIndex = 1
                elseif sourceIndex > pointCount then
                    sourceIndex = pointCount
                end

                if sourceIndex <= lastSourceIndex then
                    sourceIndex = math.min(lastSourceIndex + 1, pointCount)
                end

                limitedPoints[#limitedPoints + 1] = points[sourceIndex]
                lastSourceIndex = sourceIndex
            end

            points = limitedPoints
        end

        if #points > 0 then
            if cacheKey ~= nil then
                NXFarmKitShared._fieldSamplePointsCache[cacheKey] = points
            end
            return points
        end
    end

    local centerX, centerZ = NXFarmKitShared.getFieldCenterWorldPosition(field)
    if centerX ~= nil and centerZ ~= nil then
        local fallbackPoints = {
            { x = centerX, z = centerZ }
        }

        if cacheKey ~= nil then
            NXFarmKitShared._fieldSamplePointsCache[cacheKey] = fallbackPoints
        end

        return fallbackPoints
    end

    if cacheKey ~= nil then
        NXFarmKitShared._fieldSamplePointsCache[cacheKey] = false
    end

    return {}
end

function NXFarmKitShared.getSprayTypeRate(sprayTypeName)
    if g_sprayTypeManager == nil or g_sprayTypeManager.getSprayTypeByName == nil then
        return 0
    end

    local sprayType = g_sprayTypeManager:getSprayTypeByName(sprayTypeName)
    if sprayType == nil then
        return 0
    end

    return NXFarmKitShared.getSafeNumber(sprayType.litersPerSecond)
end

function NXFarmKitShared.calculateMaterialTotal(areaHa, litersPerSecond)
    return NXFarmKitShared.round(NXFarmKitShared.getSafeNumber(areaHa) * NXFarmKitShared.getSafeNumber(litersPerSecond) * 36000, 2)
end

function NXFarmKitShared.calculateTotalLitersFromLitersPerHa(areaHa, litersPerHa)
    return NXFarmKitShared.round(NXFarmKitShared.getSafeNumber(areaHa) * NXFarmKitShared.getSafeNumber(litersPerHa), 2)
end

function NXFarmKitShared.getFillTypeMassPerLiter(fillTypeName)
    if fillTypeName == nil or g_fillTypeManager == nil or g_fillTypeManager.getFillTypeByName == nil then
        return nil
    end

    local fillType = g_fillTypeManager:getFillTypeByName(fillTypeName)
    if fillType == nil or fillType.massPerLiter == nil or fillType.massPerLiter <= 0 then
        return nil
    end

    return fillType.massPerLiter * 1000
end

function NXFarmKitShared.getFruitTypeIndexByName(fruitTypeName)
    if fruitTypeName == nil or fruitTypeName == "" or g_fruitTypeManager == nil or g_fruitTypeManager.getFruitTypeByName == nil then
        return nil
    end

    local fruitType = g_fruitTypeManager:getFruitTypeByName(fruitTypeName)
    if fruitType == nil then
        return nil
    end

    return fruitType.index
end

function NXFarmKitShared.getFruitTypeNameByIndex(fruitTypeIndex)
    if fruitTypeIndex == nil or fruitTypeIndex <= 0 or g_fruitTypeManager == nil or g_fruitTypeManager.getFruitTypeByIndex == nil then
        return nil
    end

    local fruitType = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
    if fruitType == nil then
        return nil
    end

    return fruitType.name
end

function NXFarmKitShared.getIsPrecisionFarmingActive()
    return g_modIsLoaded ~= nil and g_modIsLoaded["FS25_precisionFarming"] == true
end

NXFarmKitShared.DEBUG_CUSTOM_FERTILIZER_BACKEND = false
NXFarmKitShared._mapCustomFertilizerCache = nil
NXFarmKitShared._customFertilizerBackendLogged = false

function NXFarmKitShared.logBackendDebug(message)
    if NXFarmKitShared.DEBUG_CUSTOM_FERTILIZER_BACKEND ~= true then
        return
    end

    local modName = (rawget(_G, "FarmKit") ~= nil and FarmKit.MOD_NAME) or "FS25_FarmKit"
    print(string.format("Info: [%s] DEBUG %s", modName, tostring(message)))
end

function NXFarmKitShared.normalizeKey(value)
    local safeValue = tostring(value or "")
    safeValue = string.upper(safeValue)
    safeValue = string.gsub(safeValue, "%s+", "")
    return safeValue
end

function NXFarmKitShared.getBaseMaterialDefinitions()
    return {
        { key = "lime", sprayType = "LIME" },
        { key = "fertilizer", sprayType = "FERTILIZER" },
        { key = "liquidFertilizer", sprayType = "LIQUIDFERTILIZER" },
        { key = "herbicide", sprayType = "HERBICIDE" },
        { key = "manure", sprayType = "MANURE" },
        { key = "slurry", sprayType = "LIQUIDMANURE" },
        { key = "digestate", sprayType = "DIGESTATE" }
    }
end

function NXFarmKitShared.getBaseSprayTypeNameSet()
    local names = {}

    for _, definition in ipairs(NXFarmKitShared.getBaseMaterialDefinitions()) do
        names[NXFarmKitShared.normalizeKey(definition.sprayType)] = true
    end

    return names
end

function NXFarmKitShared.createCustomMaterialKey(sprayTypeName)
    local normalizedSprayTypeName = NXFarmKitShared.normalizeKey(sprayTypeName)
    if normalizedSprayTypeName == "" then
        normalizedSprayTypeName = "UNKNOWN"
    end

    return "custom_" .. string.lower(normalizedSprayTypeName)
end

function NXFarmKitShared.addUniqueString(target, value)
    local safeValue = tostring(value or "")
    if safeValue == "" then
        return
    end

    for _, existingValue in ipairs(target) do
        if existingValue == safeValue then
            return
        end
    end

    target[#target + 1] = safeValue
end

function NXFarmKitShared.joinSortedMapKeys(valuesByKey)
    local keys = {}

    for key, value in pairs(valuesByKey or {}) do
        if value ~= nil then
            keys[#keys + 1] = tostring(key)
        end
    end

    table.sort(keys)
    return table.concat(keys, ",")
end

function NXFarmKitShared.getCurrentMapBaseDirectories()
    local directories = {}

    local function addDirectory(directory)
        local safeDirectory = tostring(directory or "")
        if safeDirectory == "" then
            return
        end

        NXFarmKitShared.addUniqueString(directories, safeDirectory)
    end

    if g_currentMission ~= nil then
        addDirectory(g_currentMission.baseDirectory)

        if g_currentMission.missionInfo ~= nil then
            addDirectory(g_currentMission.missionInfo.baseDirectory)
            addDirectory(g_currentMission.missionInfo.customEnvironment)
            addDirectory(g_currentMission.missionInfo.customEnvironmentDirectory)
        end

        if g_currentMission.missionDynamicInfo ~= nil then
            addDirectory(g_currentMission.missionDynamicInfo.baseDirectory)
            addDirectory(g_currentMission.missionDynamicInfo.customEnvironment)
            addDirectory(g_currentMission.missionDynamicInfo.customEnvironmentDirectory)
        end
    end

    return directories
end

function NXFarmKitShared.resolveFilenameAgainstDirectories(filename, directories)
    local safeFilename = tostring(filename or "")
    if safeFilename == "" then
        return nil
    end

    if fileExists(safeFilename) then
        return safeFilename
    end

    for _, directory in ipairs(directories or {}) do
        local candidateFilename = Utils.getFilename(safeFilename, directory)
        if candidateFilename ~= nil and candidateFilename ~= "" and fileExists(candidateFilename) then
            return candidateFilename
        end
    end

    return nil
end

function NXFarmKitShared.getCurrentMapModDescFilename()
    local baseDirectories = NXFarmKitShared.getCurrentMapBaseDirectories()

    for _, baseDirectory in ipairs(baseDirectories) do
        local modDescFilename = Utils.getFilename("modDesc.xml", baseDirectory)
        if modDescFilename ~= nil and modDescFilename ~= "" and fileExists(modDescFilename) then
            return modDescFilename, baseDirectory
        end
    end

    return nil, nil
end

function NXFarmKitShared.getCurrentMapXmlFilename()
    local modDescFilename, baseDirectory = NXFarmKitShared.getCurrentMapModDescFilename()

    if modDescFilename ~= nil and modDescFilename ~= "" and fileExists(modDescFilename) then
        local xmlFile = loadXMLFile("nxFarmKitCurrentMapModDesc", modDescFilename)
        if xmlFile ~= nil and xmlFile ~= 0 then
            local configFilename = getXMLString(xmlFile, "modDesc.maps.map(0)#configFilename")
            delete(xmlFile)

            local resolvedFilename = NXFarmKitShared.resolveFilenameAgainstDirectories(configFilename, { baseDirectory })
            if resolvedFilename ~= nil then
                return resolvedFilename, baseDirectory, modDescFilename
            end
        end
    end

    local filenameCandidates = {}
    local baseDirectories = NXFarmKitShared.getCurrentMapBaseDirectories()

    local function addCandidate(filename)
        local safeFilename = tostring(filename or "")
        if safeFilename ~= "" then
            filenameCandidates[#filenameCandidates + 1] = safeFilename
        end
    end

    if g_currentMission ~= nil then
        addCandidate(g_currentMission.mapXMLFilename)
        addCandidate(g_currentMission.mapXmlFilename)
        addCandidate(g_currentMission.configFilename)

        if g_currentMission.missionInfo ~= nil then
            addCandidate(g_currentMission.missionInfo.mapXMLFilename)
            addCandidate(g_currentMission.missionInfo.mapXmlFilename)
            addCandidate(g_currentMission.missionInfo.configFilename)
        end

        if g_currentMission.missionDynamicInfo ~= nil then
            addCandidate(g_currentMission.missionDynamicInfo.mapXMLFilename)
            addCandidate(g_currentMission.missionDynamicInfo.mapXmlFilename)
            addCandidate(g_currentMission.missionDynamicInfo.configFilename)
        end
    end

    for _, filename in ipairs(filenameCandidates) do
        local resolvedFilename = NXFarmKitShared.resolveFilenameAgainstDirectories(filename, baseDirectories)
        if resolvedFilename ~= nil then
            return resolvedFilename, nil, nil
        end
    end

    return nil, nil, nil
end

function NXFarmKitShared.loadMapCustomFertilizerData()
    if NXFarmKitShared._mapCustomFertilizerCache ~= nil then
        return NXFarmKitShared._mapCustomFertilizerCache
    end

    local cache = {
        isLoaded = false,
        baseDirectory = nil,
        modDescFilename = nil,
        mapXmlFilename = nil,
        sprayTypesXmlFilename = nil,
        customDefinitions = {},
        customDefinitionByName = {}
    }

    local baseSprayTypeNameSet = NXFarmKitShared.getBaseSprayTypeNameSet()

    local function ensureCustomDefinition(fillTypeName)
        local normalizedFillTypeName = NXFarmKitShared.normalizeKey(fillTypeName)
        if normalizedFillTypeName == "" then
            return nil
        end

        local existingDefinition = cache.customDefinitionByName[normalizedFillTypeName]
        if existingDefinition ~= nil then
            return existingDefinition
        end

        if baseSprayTypeNameSet[normalizedFillTypeName] == true then
            return nil
        end

        local definition = {
            key = NXFarmKitShared.createCustomMaterialKey(fillTypeName),
            sprayType = normalizedFillTypeName,
            normalizedSprayTypeName = normalizedFillTypeName,
            litersPerSecond = NXFarmKitShared.getSprayTypeRate(fillTypeName),
            sprayGroundType = nil,
            isCustomMapFertilizer = true
        }

        cache.customDefinitions[#cache.customDefinitions + 1] = definition
        cache.customDefinitionByName[normalizedFillTypeName] = definition
        return definition
    end

    local mapXmlFilename, baseDirectory, modDescFilename = NXFarmKitShared.getCurrentMapXmlFilename()
    cache.baseDirectory = baseDirectory
    cache.modDescFilename = modDescFilename
    cache.mapXmlFilename = mapXmlFilename

    if mapXmlFilename ~= nil and mapXmlFilename ~= "" and fileExists(mapXmlFilename) then
        local xmlFile = loadXMLFile("nxFarmKitCurrentMapXml", mapXmlFilename)
        if xmlFile ~= nil and xmlFile ~= 0 then
            if cache.baseDirectory == nil or cache.baseDirectory == "" then
                local sanitizedMapXmlFilename = string.gsub(mapXmlFilename, "\\", "/")
                cache.baseDirectory = string.match(sanitizedMapXmlFilename, "^(.*[/\\])") or ""
            end

            local sprayTypesRelativeFilename = getXMLString(xmlFile, "map.sprayTypes#filename")
            local sprayTypesXmlFilename = NXFarmKitShared.resolveFilenameAgainstDirectories(sprayTypesRelativeFilename, { cache.baseDirectory })
            cache.sprayTypesXmlFilename = sprayTypesXmlFilename

            if sprayTypesXmlFilename ~= nil and sprayTypesXmlFilename ~= "" and fileExists(sprayTypesXmlFilename) then
                local sprayTypesXmlFile = loadXMLFile("nxFarmKitCurrentMapSprayTypesXml", sprayTypesXmlFilename)
                if sprayTypesXmlFile ~= nil and sprayTypesXmlFile ~= 0 then
                    local sprayTypeBaseKey = "map.sprayTypes.sprayType"
                    local sprayTypeIndex = 0

                    while true do
                        local sprayTypeKey = string.format("%s(%d)", sprayTypeBaseKey, sprayTypeIndex)
                        if not hasXMLProperty(sprayTypesXmlFile, sprayTypeKey) then
                            break
                        end

                        local sprayTypeName = getXMLString(sprayTypesXmlFile, sprayTypeKey .. "#name")
                        local normalizedSprayTypeName = NXFarmKitShared.normalizeKey(sprayTypeName)
                        local sprayTypeType = NXFarmKitShared.normalizeKey(getXMLString(sprayTypesXmlFile, sprayTypeKey .. "#type"))

                        if normalizedSprayTypeName ~= "" and sprayTypeType == "FERTILIZER" and baseSprayTypeNameSet[normalizedSprayTypeName] ~= true then
                            local definition = ensureCustomDefinition(sprayTypeName)
                            if definition ~= nil then
                                definition.sprayType = normalizedSprayTypeName
                                definition.normalizedSprayTypeName = normalizedSprayTypeName
                                definition.litersPerSecond = NXFarmKitShared.getSafeNumber(getXMLFloat(sprayTypesXmlFile, sprayTypeKey .. "#litersPerSecond"))
                                definition.sprayGroundType = getXMLString(sprayTypesXmlFile, sprayTypeKey .. "#sprayGroundType")
                            end
                        end

                        sprayTypeIndex = sprayTypeIndex + 1
                    end

                    delete(sprayTypesXmlFile)
                end
            end

            delete(xmlFile)
        end
    end

    table.sort(cache.customDefinitions, function(a, b)
        return tostring(a.sprayType) < tostring(b.sprayType)
    end)

    cache.isLoaded = true
    NXFarmKitShared._mapCustomFertilizerCache = cache

    if NXFarmKitShared._customFertilizerBackendLogged ~= true and #cache.customDefinitions > 0 then
        local customSprayTypeNames = {}
        for _, definition in ipairs(cache.customDefinitions) do
            customSprayTypeNames[#customSprayTypeNames + 1] = tostring(definition.sprayType)
        end

        NXFarmKitShared.logBackendDebug(string.format(
            "Custom fertilizer backend mapXml=%s sprayTypesXml=%s customSprayTypes=%s",
            tostring(cache.mapXmlFilename or "nil"),
            tostring(cache.sprayTypesXmlFilename or "nil"),
            table.concat(customSprayTypeNames, ",")
        ))
        NXFarmKitShared._customFertilizerBackendLogged = true
    end

    return cache
end

function NXFarmKitShared.getCustomMapFertilizerDefinitions()
    local cache = NXFarmKitShared.loadMapCustomFertilizerData()
    return cache.customDefinitions or {}
end

function NXFarmKitShared.getMaterialDefinitionsWithCustomFertilizers()
    local definitions = NXFarmKitShared.getBaseMaterialDefinitions()

    for _, definition in ipairs(NXFarmKitShared.getCustomMapFertilizerDefinitions()) do
        definitions[#definitions + 1] = definition
    end

    return definitions
end

function NXFarmKitShared.getCustomMapFertilizerDefinition(sprayTypeName)
    local normalizedSprayTypeName = NXFarmKitShared.normalizeKey(sprayTypeName)
    if normalizedSprayTypeName == "" then
        return nil
    end

    local cache = NXFarmKitShared.loadMapCustomFertilizerData()
    return cache.customDefinitionByName[normalizedSprayTypeName]
end

function NXFarmKitShared.isCustomMapOrganicSprayType(sprayTypeName)
    local definition = NXFarmKitShared.getCustomMapFertilizerDefinition(sprayTypeName)
    if definition == nil then
        return false
    end

    local normalizedSprayGroundType = NXFarmKitShared.normalizeKey(definition.sprayGroundType)
    return normalizedSprayGroundType == "MANURE"
        or normalizedSprayGroundType == "LIQUIDMANURE"
        or normalizedSprayGroundType == "LIQUID_MANURE"
end

function NXFarmKitShared.logCustomMaterialFieldData(field, sprayTypeName, sourceName, litersPerSecond, rawLitersPerHa, displayLitersPerHa, totalLiters)
    local fieldId = NXFarmKitShared.getFieldDisplayId(field)

    NXFarmKitShared.logBackendDebug(string.format(
        "CustomFertilizer field=%s sprayType=%s source=%s litersPerSecond=%.4f rawLitersPerHa=%.2f displayLitersPerHa=%.2f totalLiters=%.2f",
        tostring(fieldId),
        tostring(sprayTypeName or "nil"),
        tostring(sourceName or "unknown"),
        NXFarmKitShared.getSafeNumber(litersPerSecond),
        NXFarmKitShared.getSafeNumber(rawLitersPerHa),
        NXFarmKitShared.getSafeNumber(displayLitersPerHa),
        NXFarmKitShared.getSafeNumber(totalLiters)
    ))
end

function NXFarmKitShared.compareFieldEntries(a, b)
    local numberA = tonumber(a.fieldId)
    local numberB = tonumber(b.fieldId)

    if numberA ~= nil and numberB ~= nil then
        return numberA < numberB
    end

    return tostring(a.fieldId) < tostring(b.fieldId)
end

function NXFarmKitShared.buildSections(fieldEntries)
    local sectionsByFarmId = {}
    local orderedFarmIds = {}

    for _, entry in ipairs(fieldEntries or {}) do
        local farmId = entry.farmId
        local section = sectionsByFarmId[farmId]

        if section == nil then
            section = {
                farmId = farmId,
                title = NXFarmKitShared.getFarmTitle(farmId),
                fields = {}
            }
            sectionsByFarmId[farmId] = section
            table.insert(orderedFarmIds, farmId)
        end

        table.insert(section.fields, entry)
    end

    for _, farmId in ipairs(orderedFarmIds) do
        table.sort(sectionsByFarmId[farmId].fields, NXFarmKitShared.compareFieldEntries)
    end

    local currentFarmId = NXFarmKitShared.getCurrentPlayerFarmId()
    local noOwnerFarmId = FarmlandManager ~= nil and FarmlandManager.NO_OWNER_FARM_ID or 0
    local result = {}

    if sectionsByFarmId[currentFarmId] ~= nil then
        table.insert(result, sectionsByFarmId[currentFarmId])
        sectionsByFarmId[currentFarmId] = nil
    end

    if sectionsByFarmId[noOwnerFarmId] ~= nil then
        table.insert(result, sectionsByFarmId[noOwnerFarmId])
        sectionsByFarmId[noOwnerFarmId] = nil
    end

    local remaining = {}
    for _, section in pairs(sectionsByFarmId) do
        if section ~= nil then
            table.insert(remaining, section)
        end
    end

    table.sort(remaining, function(a, b)
        return tostring(a.title) < tostring(b.title)
    end)

    for _, section in ipairs(remaining) do
        table.insert(result, section)
    end

    return result
end

function NXFarmKitShared.getFruitFillTitle(fruit)
    if fruit == nil then
        return "-"
    end

    if g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeByName ~= nil and fruit.name ~= nil then
        local fillType = g_fillTypeManager:getFillTypeByName(fruit.name)
        if fillType ~= nil and fillType.title ~= nil then
            return fillType.title
        end
    end

    return tostring(fruit.name or "-")
end

function NXFarmKitShared.collectSeedEntries(fieldData)
    local entries = {}
    local safeAreaHa = 0

    if type(fieldData) == "table" then
        safeAreaHa = tonumber(fieldData.areaHa) or tonumber(fieldData.fieldArea) or 0
    else
        safeAreaHa = tonumber(fieldData) or 0
    end

    safeAreaHa = NXFarmKitShared.getSafeNumber(safeAreaHa)

    if g_fruitTypeManager == nil or g_fruitTypeManager.getFruitTypes == nil then
        return entries
    end

    local pfProvider = rawget(_G, "NXFarmKitPF")
    local pfActive = NXFarmKitShared.getIsPrecisionFarmingActive() and type(pfProvider) == "table"

    for _, fruit in pairs(g_fruitTypeManager:getFruitTypes()) do
        if fruit ~= nil and fruit.allowsSeeding then
            local usagePerSqm = nil

            if pfActive and type(pfProvider.getSeedUsagePerSqmForFruit) == "function" then
                usagePerSqm = pfProvider.getSeedUsagePerSqmForFruit(fieldData, fruit)
            end

            if usagePerSqm == nil then
                usagePerSqm = NXFarmKitShared.getSafeNumber(fruit.seedUsagePerSqm)
            end

            local litersPerHa = NXFarmKitShared.getSafeNumber(usagePerSqm) * 10000
            table.insert(entries, {
                title = NXFarmKitShared.getFruitFillTitle(fruit),
                litersPerHa = NXFarmKitShared.round(litersPerHa, 2),
                totalLiters = NXFarmKitShared.round(safeAreaHa * litersPerHa, 2),
                fruitName = fruit.name
            })
        end
    end

    table.sort(entries, function(a, b)
        return tostring(a.title) < tostring(b.title)
    end)

    return entries
end

function NXFarmKitShared.buildVanillaFieldEntry(field)
    local areaHa = NXFarmKitShared.getFieldAreaHa(field)

    local entry = {
        fieldId = NXFarmKitShared.getFieldDisplayId(field),
        rawField = field,
        farmId = NXFarmKitShared.getFarmIdForField(field),
        areaHa = areaHa,
        materials = {},
        customMaterials = {},
        isPrecisionFarming = false
    }

    for _, definition in ipairs(NXFarmKitShared.getMaterialDefinitionsWithCustomFertilizers()) do
        local litersPerSecond = NXFarmKitShared.getSprayTypeRate(definition.sprayType)
        if definition.isCustomMapFertilizer == true and definition.litersPerSecond ~= nil and definition.litersPerSecond > 0 then
            litersPerSecond = definition.litersPerSecond
        end

        local litersPerHa = litersPerSecond * 36000
        local targetTable = definition.isCustomMapFertilizer == true and entry.customMaterials or entry.materials

        targetTable[definition.key] = {
            litersPerSecond = litersPerSecond,
            litersPerHa = litersPerHa,
            totalLiters = NXFarmKitShared.calculateTotalLitersFromLitersPerHa(areaHa, litersPerHa)
        }

        if definition.isCustomMapFertilizer == true then
            NXFarmKitShared.logCustomMaterialFieldData(
                field, definition.sprayType, "map-sprayTypes",
                litersPerSecond, litersPerHa, litersPerHa,
                targetTable[definition.key].totalLiters
            )
        end
    end

    return entry
end

function NXFarmKitShared.buildFieldEntry(field)
    if NXFarmKitShared.getIsPrecisionFarmingActive()
        and rawget(_G, "NXFarmKitPF") ~= nil
        and type(NXFarmKitPF.buildFieldEntry) == "function" then
        return NXFarmKitPF.buildFieldEntry(field)
    end

    return NXFarmKitShared.buildVanillaFieldEntry(field)
end

function NXFarmKitShared.collectFieldEntries()
    local entries = {}

    if g_fieldManager ~= nil and g_fieldManager.fields ~= nil then
        for _, field in pairs(g_fieldManager.fields) do
            table.insert(entries, NXFarmKitShared.buildFieldEntry(field))
        end
    end

    if g_fieldManager ~= nil and g_fieldManager.cpCustomFields ~= nil then
        for _, field in pairs(g_fieldManager.cpCustomFields) do
            table.insert(entries, NXFarmKitShared.buildFieldEntry(field))
        end
    end

    return entries
end
