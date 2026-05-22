NXFarmKitPF = NXFarmKitPF or {}

NXFarmKitPF.runtimeUnavailableLogged = false
NXFarmKitPF.xmlFallbackLogged = false
NXFarmKitPF._pfDataCache = nil
NXFarmKitPF._mapCustomPFCache = nil
NXFarmKitPF._customPFBackendLogged = false
NXFarmKitPF.PF_FALLOW_REFERENCE_FRUIT = "WHEAT"
NXFarmKitPF.PF_LIME_LOAD_BUFFER_LITERS_PER_HA = 175
NXFarmKitPF.PF_LIME_AFTER_MAX_REST_AREA_RATIO = 0.20
NXFarmKitPF.PF_LIME_AFTER_SIGNIFICANT_REST_STATES = 3
NXFarmKitPF.PF_LIME_PRACTICAL_REST_AREA_RATIO_MAX = 0.30
NXFarmKitPF.PF_LIME_PRACTICAL_NEIGHBOR_RADIUS_FACTOR = 1.60
NXFarmKitPF.PF_LIME_PRACTICAL_MIN_NEED_NEIGHBORS = 2
NXFarmKitPF.PF_NITROGEN_LOAD_BUFFER_STATES = 2.75
NXFarmKitPF.PF_NITROGEN_AFTER_MAX_REST_STATES = 3
NXFarmKitPF.PF_FALLOW_NITROGEN_EXTRA_LOAD_BUFFER_STATES = 7.0
NXFarmKitPF.ORGANIC_NITROGEN_MODE_SOIL = "soil"
NXFarmKitPF.ORGANIC_NITROGEN_MODE_PLANT = "plant"
NXFarmKitPF.DEBUG_ORGANIC_TARGET_COMPARE = false

NXFarmKitPF.RUNTIME_COVER_UNSAMPLED_VALUE = "0"
NXFarmKitPF.RUNTIME_COVER_SAMPLED_VALUE = "7"
NXFarmKitPF.RUNTIME_GROUND_FILTER_MIN_SHARE = 0.75

local VALID_GROUNDTYPE_MIN = 1
local VALID_GROUNDTYPE_MAX = 15

local COVER_METHOD_CANDIDATES = {
    "getLevelAtWorldPos",
    "getTypeIndexAtWorldPos",
    "getValueAtWorldPos",
    "getInternalValueAtWorldPos",
    "getIsCoveredAtWorldPos"
}

local function pfLogWarning(message)
    local modName = (rawget(_G, "FarmKit") ~= nil and FarmKit.MOD_NAME) or "FS25_FarmKit"
    print(string.format("Warning: [%s] %s", modName, tostring(message)))
end

local function pfLogOrganicDebug(message)
    local modName = (rawget(_G, "FarmKit") ~= nil and FarmKit.MOD_NAME) or "FS25_FarmKit"
    print(string.format("Info: [%s] DEBUG %s", modName, tostring(message)))
end

function NXFarmKitPF.logOrganicTargetComparison(field, sampleIndex, soilTypeIndex, nitrogenKgPerHa, organicNitrogenTargetKgPerHa, nitrogenTargetKgPerHa, activeFruitTypeName, usedFallowReference)
    if NXFarmKitPF.DEBUG_ORGANIC_TARGET_COMPARE ~= true then
        return
    end

    local fieldId = NXFarmKitShared.getFieldDisplayId(field)
    pfLogOrganicDebug(string.format(
        "OrganicN compare field=%s sample=%d soilType=%s currentN=%.2f soilTarget=%.2f plantTarget=%.2f fruit=%s fallowRef=%s",
        tostring(fieldId),
        tonumber(sampleIndex) or 0,
        tostring(soilTypeIndex),
        NXFarmKitShared.getSafeNumber(nitrogenKgPerHa),
        NXFarmKitShared.getSafeNumber(organicNitrogenTargetKgPerHa),
        NXFarmKitShared.getSafeNumber(nitrogenTargetKgPerHa),
        tostring(activeFruitTypeName or "nil"),
        tostring(usedFallowReference == true)
    ))
end

function NXFarmKitPF.normalizeKey(value)
    local safeValue = tostring(value or "")
    safeValue = string.upper(safeValue)
    safeValue = string.gsub(safeValue, "%s+", "")
    return safeValue
end

function NXFarmKitPF.normalizeFruitTypeName(fruitTypeName)
    local normalizedFruitTypeName = NXFarmKitPF.normalizeKey(fruitTypeName)
    if normalizedFruitTypeName == "" or normalizedFruitTypeName == "UNKNOWN" then
        return nil
    end

    local aliases = {
        FIELDGRASS = "GRASS",
        MEADOWGRASS = "MEADOW",
        GRASSCUT = "GRASS",
        GRASSWINDROW = "GRASS",
        DRYGRASSWINDROW = "DRYGRASS",
        FRESHGRASSWINDROW = "GRASS"
    }

    return aliases[normalizedFruitTypeName] or normalizedFruitTypeName
end

function NXFarmKitPF.getOrganicNitrogenMode()
    if rawget(_G, "FarmKit") ~= nil and FarmKit.getOrganicNitrogenMode ~= nil then
        return FarmKit:getOrganicNitrogenMode()
    end

    return NXFarmKitPF.ORGANIC_NITROGEN_MODE_SOIL
end

function NXFarmKitPF.isOrganicNitrogenSprayType(sprayTypeName)
    local normalizedSprayTypeName = NXFarmKitPF.normalizeKey(sprayTypeName)

    if normalizedSprayTypeName == "MANURE"
        or normalizedSprayTypeName == "LIQUIDMANURE"
        or normalizedSprayTypeName == "DIGESTATE" then
        return true
    end

    if rawget(_G, "NXFarmKitShared") ~= nil
        and NXFarmKitShared.isCustomMapOrganicSprayType ~= nil then
        return NXFarmKitShared.isCustomMapOrganicSprayType(sprayTypeName)
    end

    return false
end

function NXFarmKitPF.getNitrogenTargetKgPerHaForSample(sample, sprayTypeName)
    if sample == nil then
        return nil
    end

    if NXFarmKitPF.isOrganicNitrogenSprayType(sprayTypeName) then
        local organicNitrogenMode = NXFarmKitPF.getOrganicNitrogenMode()

        if organicNitrogenMode == NXFarmKitPF.ORGANIC_NITROGEN_MODE_SOIL then
            local normalizedSprayTypeName = NXFarmKitPF.normalizeKey(sprayTypeName)

            if normalizedSprayTypeName == "MANURE" and sample.manureNitrogenTargetKgPerHa ~= nil then
                return sample.manureNitrogenTargetKgPerHa
            end

            if normalizedSprayTypeName == "LIQUIDMANURE" and sample.slurryNitrogenTargetKgPerHa ~= nil then
                return sample.slurryNitrogenTargetKgPerHa
            end

            if normalizedSprayTypeName == "DIGESTATE" and sample.digestateNitrogenTargetKgPerHa ~= nil then
                return sample.digestateNitrogenTargetKgPerHa
            end

            if sample.customNitrogenTargetKgPerHaBySprayType ~= nil then
                local customNitrogenTargetKgPerHa = sample.customNitrogenTargetKgPerHaBySprayType[normalizedSprayTypeName]
                if customNitrogenTargetKgPerHa ~= nil then
                    return customNitrogenTargetKgPerHa
                end
            end

            if sample.organicNitrogenTargetKgPerHa ~= nil then
                return sample.organicNitrogenTargetKgPerHa
            end
        end
    end

    return sample.nitrogenTargetKgPerHa
end

function NXFarmKitPF.splitWhitespaceSeparatedNumbers(text)
    local values = {}
    local safeText = tostring(text or "")

    for token in string.gmatch(safeText, "[^%s]+") do
        local number = tonumber(token)
        if number ~= nil then
            values[#values + 1] = number
        end
    end

    return values
end

function NXFarmKitPF.getPrecisionFarmingBaseDirectory()
    local precisionFarmingClass = rawget(_G, "PrecisionFarming")
    if precisionFarmingClass ~= nil and precisionFarmingClass.BASE_DIRECTORY ~= nil and precisionFarmingClass.BASE_DIRECTORY ~= "" then
        return precisionFarmingClass.BASE_DIRECTORY
    end

    if g_modNameToDirectory ~= nil and g_modNameToDirectory["FS25_precisionFarming"] ~= nil then
        return g_modNameToDirectory["FS25_precisionFarming"]
    end

    return nil
end

function NXFarmKitPF.getPrecisionFarmingXmlFilename()
    local baseDirectory = NXFarmKitPF.getPrecisionFarmingBaseDirectory()
    if baseDirectory == nil or baseDirectory == "" then
        return nil
    end

    return Utils.getFilename("PrecisionFarming.xml", baseDirectory)
end

function NXFarmKitPF.loadPrecisionFarmingData()
    if NXFarmKitPF._pfDataCache ~= nil then
        return NXFarmKitPF._pfDataCache
    end

    local cache = {
        isLoaded = false,
        regularLimeKgPerHa = 0,
        limeUsagePerState = 0,
        pHValuePerState = 0,
        pHRealValueByState = {},
        optimalPHValueBySoilTypeIndex = {},
        fillTypeNitrogenAmount = {},
        regularNitrogenKgPerHaByFillType = {},
        applicationRateKgPerHaByFillType = {},
        fruitRequirementTargetByFruitName = {},
        seedUsagePerSqmByFruitName = {},
        nitrogenAmountPerState = 5,
        nitrogenDefaultRate = 0,
        nitrogenRealValueByState = {},
        defaultNitrogenTargetKgPerHaBySoilType = {}
    }

    local xmlFilename = NXFarmKitPF.getPrecisionFarmingXmlFilename()
    if xmlFilename == nil or xmlFilename == "" or not fileExists(xmlFilename) then
        NXFarmKitPF._pfDataCache = cache
        return cache
    end

    local xmlFile = loadXMLFile("nxFarmKitPrecisionFarmingXml", xmlFilename)
    if xmlFile == nil or xmlFile == 0 then
        NXFarmKitPF._pfDataCache = cache
        return cache
    end

    cache.regularLimeKgPerHa = NXFarmKitShared.getSafeNumber(getXMLFloat(xmlFile, "precisionFarming.pHMap.valueTransformations#regularUsage"))
    cache.limeUsagePerState = NXFarmKitShared.getSafeNumber(getXMLFloat(xmlFile, "precisionFarming.pHMap.limeUsage#usagePerState"))
    cache.pHValuePerState = NXFarmKitShared.getSafeNumber(getXMLFloat(xmlFile, "precisionFarming.pHMap.pHValues#pHValuePerState"))

    local phValueBaseKey = "precisionFarming.pHMap.pHValues.pHValue"
    local phValueIndex = 0

    while true do
        local phKey = string.format("%s(%d)", phValueBaseKey, phValueIndex)
        if not hasXMLProperty(xmlFile, phKey) then
            break
        end

        local stateValue = getXMLInt(xmlFile, phKey .. "#value")
        local realValue = getXMLFloat(xmlFile, phKey .. "#realValue")

        if stateValue ~= nil and realValue ~= nil then
            cache.pHRealValueByState[stateValue] = realValue
        end

        phValueIndex = phValueIndex + 1
    end

    local pHTransformationBaseKey = "precisionFarming.pHMap.valueTransformations.valueTransformation"
    local pHTransformationIndex = 0

    while true do
        local transformationKey = string.format("%s(%d)", pHTransformationBaseKey, pHTransformationIndex)
        if not hasXMLProperty(xmlFile, transformationKey) then
            break
        end

        local soilTypeIndex = getXMLInt(xmlFile, transformationKey .. "#soilTypeIndex")
        local optimalValue = getXMLFloat(xmlFile, transformationKey .. ".optimalValue#value")

        if soilTypeIndex ~= nil and optimalValue ~= nil then
            cache.optimalPHValueBySoilTypeIndex[soilTypeIndex] = optimalValue
        end

        pHTransformationIndex = pHTransformationIndex + 1
    end

    cache.nitrogenAmountPerState = NXFarmKitShared.getSafeNumber(getXMLFloat(xmlFile, "precisionFarming.nitrogenMap.nitrogenValues#amountPerState"))
    cache.nitrogenDefaultRate = NXFarmKitShared.getSafeNumber(getXMLFloat(xmlFile, "precisionFarming.nitrogenMap.nitrogenValues#defaultRate"))

    local nitrogenValueBaseKey = "precisionFarming.nitrogenMap.nitrogenValues.nitrogenValue"
    local nitrogenValueIndex = 0

    while true do
        local nitrogenKey = string.format("%s(%d)", nitrogenValueBaseKey, nitrogenValueIndex)
        if not hasXMLProperty(xmlFile, nitrogenKey) then
            break
        end

        local stateValue = getXMLInt(xmlFile, nitrogenKey .. "#value")
        local realValue = getXMLFloat(xmlFile, nitrogenKey .. "#realValue")

        if stateValue ~= nil and realValue ~= nil then
            cache.nitrogenRealValueByState[stateValue] = realValue
        end

        nitrogenValueIndex = nitrogenValueIndex + 1
    end

    local fertilizerUsageBaseKey = "precisionFarming.nitrogenMap.fertilizerUsage.nAmount"
    local usageIndex = 0

    while true do
        local usageKey = string.format("%s(%d)", fertilizerUsageBaseKey, usageIndex)
        if not hasXMLProperty(xmlFile, usageKey) then
            break
        end

        local fillTypeName = getXMLString(xmlFile, usageKey .. "#fillType")
        local amount = getXMLFloat(xmlFile, usageKey .. "#amount")

        if fillTypeName ~= nil and amount ~= nil and amount > 0 then
            cache.fillTypeNitrogenAmount[NXFarmKitPF.normalizeKey(fillTypeName)] = amount
        end

        usageIndex = usageIndex + 1
    end

    local applicationRatesBaseKey = "precisionFarming.nitrogenMap.applicationRates.applicationRate"
    local rateIndex = 0

    while true do
        local rateKey = string.format("%s(%d)", applicationRatesBaseKey, rateIndex)
        if not hasXMLProperty(xmlFile, rateKey) then
            break
        end

        local fillTypeName = getXMLString(xmlFile, rateKey .. "#fillType")
        local regularRate = getXMLFloat(xmlFile, rateKey .. "#regularRate")
        local normalizedFillTypeName = NXFarmKitPF.normalizeKey(fillTypeName)

        if fillTypeName ~= nil and regularRate ~= nil then
            cache.regularNitrogenKgPerHaByFillType[normalizedFillTypeName] = NXFarmKitShared.getSafeNumber(regularRate)
        end

        local soilIndex = 0
        while true do
            local soilKey = string.format("%s.soil(%d)", rateKey, soilIndex)
            if not hasXMLProperty(xmlFile, soilKey) then
                break
            end

            local soilTypeIndex = getXMLInt(xmlFile, soilKey .. "#soilTypeIndex")
            local soilRate = getXMLFloat(xmlFile, soilKey .. "#rate")

            if soilTypeIndex ~= nil and soilRate ~= nil and fillTypeName ~= nil then
                if cache.applicationRateKgPerHaByFillType[normalizedFillTypeName] == nil then
                    cache.applicationRateKgPerHaByFillType[normalizedFillTypeName] = {}
                end

                cache.applicationRateKgPerHaByFillType[normalizedFillTypeName][soilTypeIndex] = NXFarmKitShared.getSafeNumber(soilRate)
            end

            soilIndex = soilIndex + 1
        end

        rateIndex = rateIndex + 1
    end

    local fruitRequirementsBaseKey = "precisionFarming.nitrogenMap.fruitRequirements.fruitRequirement"
    local fruitRequirementIndex = 0

    while true do
        local fruitRequirementKey = string.format("%s(%d)", fruitRequirementsBaseKey, fruitRequirementIndex)
        if not hasXMLProperty(xmlFile, fruitRequirementKey) then
            break
        end

        local fruitTypeName = getXMLString(xmlFile, fruitRequirementKey .. "#fruitTypeName")
        local normalizedFruitTypeName = NXFarmKitPF.normalizeKey(fruitTypeName)
        local availableAsDefaultRate = getXMLBool(xmlFile, fruitRequirementKey .. "#availableAsDefaultRate") == true

        if fruitTypeName ~= nil then
            cache.fruitRequirementTargetByFruitName[normalizedFruitTypeName] = cache.fruitRequirementTargetByFruitName[normalizedFruitTypeName] or {}

            local soilIndex = 0
            while true do
                local soilKey = string.format("%s.soil(%d)", fruitRequirementKey, soilIndex)
                if not hasXMLProperty(xmlFile, soilKey) then
                    break
                end

                local soilTypeIndex = getXMLInt(xmlFile, soilKey .. "#soilTypeIndex")
                local targetLevel = getXMLFloat(xmlFile, soilKey .. "#targetLevel")

                if soilTypeIndex ~= nil and targetLevel ~= nil then
                    local safeTargetLevel = NXFarmKitShared.getSafeNumber(targetLevel)
                    cache.fruitRequirementTargetByFruitName[normalizedFruitTypeName][soilTypeIndex] = safeTargetLevel

                    if availableAsDefaultRate then
                        cache.defaultNitrogenTargetKgPerHaBySoilType[soilTypeIndex] = safeTargetLevel
                    end
                end

                soilIndex = soilIndex + 1
            end
        end

        fruitRequirementIndex = fruitRequirementIndex + 1
    end

    local fruitTypesBaseKey = "precisionFarming.seedRateMap.fruitTypes.fruitType"
    local fruitIndex = 0

    while true do
        local fruitKey = string.format("%s(%d)", fruitTypesBaseKey, fruitIndex)
        if not hasXMLProperty(xmlFile, fruitKey) then
            break
        end

        local fruitName = getXMLString(xmlFile, fruitKey .. "#name")
        local usagesText = getXMLString(xmlFile, fruitKey .. ".seedRates#usages")
        local usages = NXFarmKitPF.splitWhitespaceSeparatedNumbers(usagesText)

        if fruitName ~= nil and #usages > 0 then
            local usageIndexToUse = math.ceil(#usages / 2)
            cache.seedUsagePerSqmByFruitName[NXFarmKitPF.normalizeKey(fruitName)] = usages[usageIndexToUse]
        end

        fruitIndex = fruitIndex + 1
    end

    delete(xmlFile)

    cache.isLoaded = true
    NXFarmKitPF._pfDataCache = cache
    return cache
end

function NXFarmKitPF.getSeedUsagePerSqmForFruit(fieldData, fruit)
    local pfData = NXFarmKitPF.loadPrecisionFarmingData()
    if pfData == nil or pfData.isLoaded ~= true or fruit == nil or fruit.name == nil then
        return nil
    end

    return pfData.seedUsagePerSqmByFruitName[NXFarmKitPF.normalizeKey(fruit.name)]
end

function NXFarmKitPF.loadMapCustomPFData()
    if NXFarmKitPF._mapCustomPFCache ~= nil then
        return NXFarmKitPF._mapCustomPFCache
    end

    local cache = {
        isLoaded = false,
        baseDirectory = nil,
        modDescFilename = nil,
        mapXmlFilename = nil,
        mapPFNitrogenAmountByFillType = {},
        mapPFRegularRateKgPerHaByFillType = {},
        mapPFApplicationRateKgPerHaByFillType = {},
        mapPFAutoAdjustToFruitByFillType = {}
    }

    local mapXmlFilename, baseDirectory, modDescFilename = NXFarmKitShared.getCurrentMapXmlFilename()
    cache.baseDirectory = baseDirectory
    cache.modDescFilename = modDescFilename
    cache.mapXmlFilename = mapXmlFilename

    if mapXmlFilename ~= nil and mapXmlFilename ~= "" and fileExists(mapXmlFilename) then
        local xmlFile = loadXMLFile("nxFarmKitCurrentMapPFXml", mapXmlFilename)
        if xmlFile ~= nil and xmlFile ~= 0 then
            local applicationRateBaseKey = "map.precisionFarming.applicationRates.applicationRate"
            local applicationRateIndex = 0

            while true do
                local applicationRateKey = string.format("%s(%d)", applicationRateBaseKey, applicationRateIndex)
                if not hasXMLProperty(xmlFile, applicationRateKey) then
                    break
                end

                local fillTypeName = getXMLString(xmlFile, applicationRateKey .. "#fillType")
                local normalizedFillTypeName = NXFarmKitPF.normalizeKey(fillTypeName)

                if normalizedFillTypeName ~= "" then
                    cache.mapPFAutoAdjustToFruitByFillType[normalizedFillTypeName] = getXMLBool(xmlFile, applicationRateKey .. "#autoAdjustToFruit") == true

                    local regularRate = getXMLFloat(xmlFile, applicationRateKey .. "#regularRate")
                    if regularRate ~= nil then
                        cache.mapPFRegularRateKgPerHaByFillType[normalizedFillTypeName] = NXFarmKitShared.getSafeNumber(regularRate)
                    end

                    local soilIndex = 0
                    while true do
                        local soilKey = string.format("%s.soil(%d)", applicationRateKey, soilIndex)
                        if not hasXMLProperty(xmlFile, soilKey) then
                            break
                        end

                        local soilTypeIndex = getXMLInt(xmlFile, soilKey .. "#soilTypeIndex")
                        local soilRate = getXMLFloat(xmlFile, soilKey .. "#rate")

                        if soilTypeIndex ~= nil and soilRate ~= nil then
                            cache.mapPFApplicationRateKgPerHaByFillType[normalizedFillTypeName] = cache.mapPFApplicationRateKgPerHaByFillType[normalizedFillTypeName] or {}
                            cache.mapPFApplicationRateKgPerHaByFillType[normalizedFillTypeName][soilTypeIndex] = NXFarmKitShared.getSafeNumber(soilRate)
                        end

                        soilIndex = soilIndex + 1
                    end
                end

                applicationRateIndex = applicationRateIndex + 1
            end

            local fertilizerUsageBaseKey = "map.precisionFarming.fertilizerUsage.nAmount"
            local fertilizerUsageIndex = 0

            while true do
                local fertilizerUsageKey = string.format("%s(%d)", fertilizerUsageBaseKey, fertilizerUsageIndex)
                if not hasXMLProperty(xmlFile, fertilizerUsageKey) then
                    break
                end

                local fillTypeName = getXMLString(xmlFile, fertilizerUsageKey .. "#fillType")
                local normalizedFillTypeName = NXFarmKitPF.normalizeKey(fillTypeName)
                local amount = getXMLFloat(xmlFile, fertilizerUsageKey .. "#amount")

                if normalizedFillTypeName ~= "" and amount ~= nil and amount > 0 then
                    cache.mapPFNitrogenAmountByFillType[normalizedFillTypeName] = NXFarmKitShared.getSafeNumber(amount)
                end

                fertilizerUsageIndex = fertilizerUsageIndex + 1
            end

            delete(xmlFile)
        end
    end

    cache.isLoaded = true
    NXFarmKitPF._mapCustomPFCache = cache

    if NXFarmKitShared.DEBUG_CUSTOM_FERTILIZER_BACKEND == true and NXFarmKitPF._customPFBackendLogged ~= true then
        NXFarmKitShared.logBackendDebug(string.format(
            "Custom PF backend mapXml=%s applicationRates=%s nitrogenAmounts=%s",
            tostring(cache.mapXmlFilename or "nil"),
            NXFarmKitShared.joinSortedMapKeys(cache.mapPFApplicationRateKgPerHaByFillType),
            NXFarmKitShared.joinSortedMapKeys(cache.mapPFNitrogenAmountByFillType)
        ))
        NXFarmKitPF._customPFBackendLogged = true
    end

    return cache
end

function NXFarmKitPF.getCustomMapPFFillTypeNitrogenAmount(fillTypeName)
    local normalizedFillTypeName = NXFarmKitPF.normalizeKey(fillTypeName)
    if normalizedFillTypeName == "" then
        return nil
    end

    local cache = NXFarmKitPF.loadMapCustomPFData()
    return cache.mapPFNitrogenAmountByFillType[normalizedFillTypeName]
end

function NXFarmKitPF.getCustomMapPFRegularRateKgPerHa(fillTypeName)
    local normalizedFillTypeName = NXFarmKitPF.normalizeKey(fillTypeName)
    if normalizedFillTypeName == "" then
        return nil
    end

    local cache = NXFarmKitPF.loadMapCustomPFData()
    return cache.mapPFRegularRateKgPerHaByFillType[normalizedFillTypeName]
end

function NXFarmKitPF.getCustomMapPFApplicationRateKgPerHa(fillTypeName, soilTypeIndex)
    local normalizedFillTypeName = NXFarmKitPF.normalizeKey(fillTypeName)
    if normalizedFillTypeName == "" or soilTypeIndex == nil then
        return nil
    end

    local cache = NXFarmKitPF.loadMapCustomPFData()
    local bySoilType = cache.mapPFApplicationRateKgPerHaByFillType[normalizedFillTypeName]
    if bySoilType == nil then
        return nil
    end

    return bySoilType[soilTypeIndex]
end

function NXFarmKitPF.getRuntimeProvider()
    local bridge = rawget(_G, "NXFarmKitPFBridge")
    if type(bridge) ~= "table" then
        return nil
    end

    if type(bridge.getProvider) == "function" then
        local success, provider = pcall(bridge.getProvider)
        if success and type(provider) == "table" then
            return provider
        end
    end

    if bridge.runtimeReady == true then
        return bridge
    end

    return nil
end

function NXFarmKitPF.getRuntimeMaps()
    local provider = NXFarmKitPF.getRuntimeProvider()
    if provider == nil then
        return nil
    end

    local function getMap(getterName)
        if type(provider[getterName]) ~= "function" then
            return nil
        end

        local success, mapObject = pcall(provider[getterName], provider)
        if success and type(mapObject) == "table" then
            return mapObject
        end

        return nil
    end

    local maps = {
        provider = provider,
        soilMap = getMap("getSoilMap"),
        pHMap = getMap("getPHMap"),
        nitrogenMap = getMap("getNitrogenMap"),
        coverMap = getMap("getCoverMap")
    }

    if maps.soilMap ~= nil and maps.pHMap ~= nil and maps.nitrogenMap ~= nil and maps.coverMap ~= nil then
        return maps
    end

    return nil
end

function NXFarmKitPF.getTerrainYAtWorldPos(x, z)
    if g_terrainNode == nil or type(getTerrainHeightAtWorldPos) ~= "function" then
        return 0
    end

    local success, y = pcall(getTerrainHeightAtWorldPos, g_terrainNode, x, 0, z)
    if success then
        return NXFarmKitShared.getSafeNumber(y)
    end

    return 0
end

function NXFarmKitPF.decodeDensityMapChannelValue(densityBits, firstChannel, numChannels)
    if densityBits == nil or bit32 == nil then
        return nil
    end

    local mask = bit32.lshift(1, numChannels) - 1
    return bit32.band(bit32.rshift(densityBits, firstChannel), mask)
end

function NXFarmKitPF.getRuntimeGroundTypeMapData()
    if g_currentMission == nil or g_currentMission.fieldGroundSystem == nil then
        return nil
    end

    if FieldDensityMap == nil or FieldDensityMap.GROUND_TYPE == nil then
        return nil
    end

    if type(g_currentMission.fieldGroundSystem.getDensityMapData) ~= "function" then
        return nil
    end

    local success, mapId, firstChannel, numChannels = pcall(g_currentMission.fieldGroundSystem.getDensityMapData, g_currentMission.fieldGroundSystem, FieldDensityMap.GROUND_TYPE)
    if not success or tonumber(mapId) == nil or tonumber(mapId) == 0 then
        return nil
    end

    return {
        mapId = mapId,
        firstChannel = NXFarmKitShared.getSafeNumber(firstChannel),
        numChannels = NXFarmKitShared.getSafeNumber(numChannels)
    }
end

function NXFarmKitPF.getRuntimeGroundTypeValueAtWorldPos(mapData, x, z)
    if mapData == nil or mapData.mapId == nil or type(getDensityAtWorldPos) ~= "function" then
        return nil
    end

    local y = NXFarmKitPF.getTerrainYAtWorldPos(x, z)
    local success, densityBits = pcall(getDensityAtWorldPos, mapData.mapId, x, y, z)
    if not success then
        return nil
    end

    local groundTypeIndex = NXFarmKitPF.decodeDensityMapChannelValue(densityBits, mapData.firstChannel, mapData.numChannels)
    if groundTypeIndex == nil or groundTypeIndex < VALID_GROUNDTYPE_MIN or groundTypeIndex > VALID_GROUNDTYPE_MAX then
        return nil
    end

    return groundTypeIndex
end

function NXFarmKitPF.resolveRuntimeCoverAccessor(coverMap)
    if type(coverMap) ~= "table" then
        return nil
    end

    for _, methodName in ipairs(COVER_METHOD_CANDIDATES) do
        if type(coverMap[methodName]) == "function" then
            return methodName
        end
    end

    return nil
end

function NXFarmKitPF.getRuntimeCoverValueAtWorldPos(coverMap, accessorName, x, z)
    if type(coverMap) ~= "table" or type(coverMap[accessorName]) ~= "function" then
        return nil
    end

    local success, value = pcall(coverMap[accessorName], coverMap, x, z)
    if not success then
        local y = NXFarmKitPF.getTerrainYAtWorldPos(x, z)
        success, value = pcall(coverMap[accessorName], coverMap, x, y, z)
    end

    if not success then
        return nil
    end

    if type(value) == "boolean" then
        return value and 1 or 0
    end

    if tonumber(value) ~= nil then
        return tonumber(value)
    end

    return tostring(value)
end

function NXFarmKitPF.getHistogramEntryCount(histogram)
    local count = 0

    for _, value in pairs(histogram or {}) do
        if NXFarmKitShared.getSafeNumber(value) > 0 then
            count = count + 1
        end
    end

    return count
end

function NXFarmKitPF.getHistogramTotal(histogram)
    local total = 0

    for _, value in pairs(histogram or {}) do
        total = total + NXFarmKitShared.getSafeNumber(value)
    end

    return total
end

function NXFarmKitPF.getHistogramDominantKeyAndValue(histogram)
    local dominantKey = nil
    local dominantValue = -1

    for key, value in pairs(histogram or {}) do
        local safeValue = NXFarmKitShared.getSafeNumber(value)
        if safeValue > dominantValue then
            dominantValue = safeValue
            dominantKey = key
        end
    end

    return dominantKey, dominantValue
end

function NXFarmKitPF.buildRuntimeFieldPointContexts(field, maps, samplePoints)
    local pointContexts = {}
    local coverHistogram = {}
    local groundHistogram = {}
    local coverAccessorName = NXFarmKitPF.resolveRuntimeCoverAccessor(maps.coverMap)
    local groundMapData = NXFarmKitPF.getRuntimeGroundTypeMapData()

    for pointIndex, point in ipairs(samplePoints or {}) do
        local pointContext = {
            point = point,
            pointIndex = pointIndex,
            coverValue = nil,
            groundTypeIndex = nil
        }

        if coverAccessorName ~= nil then
            pointContext.coverValue = NXFarmKitPF.getRuntimeCoverValueAtWorldPos(maps.coverMap, coverAccessorName, point.x, point.z)
            if pointContext.coverValue ~= nil then
                local coverKey = tostring(pointContext.coverValue)
                coverHistogram[coverKey] = (coverHistogram[coverKey] or 0) + 1
            end
        end

        if groundMapData ~= nil then
            pointContext.groundTypeIndex = NXFarmKitPF.getRuntimeGroundTypeValueAtWorldPos(groundMapData, point.x, point.z)
            if pointContext.groundTypeIndex ~= nil then
                groundHistogram[pointContext.groundTypeIndex] = (groundHistogram[pointContext.groundTypeIndex] or 0) + 1
            end
        end

        pointContexts[#pointContexts + 1] = pointContext
    end

    local centerX, centerZ = NXFarmKitShared.getFieldCenterWorldPosition(field)
    local centerCoverValue = nil
    if coverAccessorName ~= nil and centerX ~= nil and centerZ ~= nil then
        centerCoverValue = NXFarmKitPF.getRuntimeCoverValueAtWorldPos(maps.coverMap, coverAccessorName, centerX, centerZ)
    end

    return pointContexts, coverHistogram, groundHistogram, centerCoverValue
end

function NXFarmKitPF.resolveRuntimeCoverValue(coverHistogram, centerCoverValue)
    local unsampledValue = tostring(NXFarmKitPF.RUNTIME_COVER_UNSAMPLED_VALUE)
    local sampledValue = tostring(NXFarmKitPF.RUNTIME_COVER_SAMPLED_VALUE)
    local unsampledCount = NXFarmKitShared.getSafeNumber(coverHistogram[unsampledValue])
    local sampledCount = NXFarmKitShared.getSafeNumber(coverHistogram[sampledValue])
    local total = NXFarmKitPF.getHistogramTotal(coverHistogram)
    local otherCount = math.max(total - unsampledCount - sampledCount, 0)

    if total <= 0 then
        if centerCoverValue ~= nil then
            return tostring(centerCoverValue), false
        end

        return nil, false
    end

    if otherCount <= 0 and unsampledCount > 0 and sampledCount <= 0 then
        return unsampledValue, false
    end

    if otherCount <= 0 and sampledCount > 0 and unsampledCount <= 0 then
        return sampledValue, false
    end

    if otherCount <= 0 and unsampledCount > 0 and sampledCount > 0 then
        if sampledCount > unsampledCount then
            return sampledValue, true
        end

        return unsampledValue, true
    end

    local dominantKey = NXFarmKitPF.getHistogramDominantKeyAndValue(coverHistogram)
    if dominantKey ~= nil then
        return tostring(dominantKey), true
    end

    if centerCoverValue ~= nil then
        return tostring(centerCoverValue), false
    end

    return nil, false
end

function NXFarmKitPF.resolveRuntimeGroundTypeIndex(groundHistogram)
    local dominantKey, dominantValue = NXFarmKitPF.getHistogramDominantKeyAndValue(groundHistogram)
    local total = NXFarmKitPF.getHistogramTotal(groundHistogram)
    if dominantKey == nil or total <= 0 then
        return nil, 0, false
    end

    local dominantShare = NXFarmKitShared.getSafeNumber(dominantValue) / total
    local applyFilter = NXFarmKitPF.getHistogramEntryCount(groundHistogram) > 1
        and dominantShare >= NXFarmKitShared.getSafeNumber(NXFarmKitPF.RUNTIME_GROUND_FILTER_MIN_SHARE)

    return tonumber(dominantKey), dominantShare, applyFilter
end

function NXFarmKitPF.buildRuntimeFieldContext(field, maps, samplePoints)
    local pointContexts, coverHistogram, groundHistogram, centerCoverValue = NXFarmKitPF.buildRuntimeFieldPointContexts(field, maps, samplePoints)
    local resolvedCoverValue, coverWasMixed = NXFarmKitPF.resolveRuntimeCoverValue(coverHistogram, centerCoverValue)
    local resolvedGroundTypeIndex, groundDominantShare, applyGroundFilter = NXFarmKitPF.resolveRuntimeGroundTypeIndex(groundHistogram)

    return {
        pointContexts = pointContexts,
        resolvedCoverValue = resolvedCoverValue,
        coverWasMixed = coverWasMixed == true,
        applyCoverFilter = resolvedCoverValue ~= nil and NXFarmKitPF.getHistogramEntryCount(coverHistogram) > 1,
        resolvedGroundTypeIndex = resolvedGroundTypeIndex,
        groundDominantShare = groundDominantShare,
        applyGroundFilter = applyGroundFilter == true
    }
end

function NXFarmKitPF.getFruitContext(field)
    if field == nil then
        return nil, nil
    end

    local fieldState = nil
    if field.getFieldState ~= nil then
        fieldState = field:getFieldState()
    end

    local function normalizeCandidate(candidate)
        return NXFarmKitPF.normalizeFruitTypeName(candidate)
    end

    local nameCandidates = {}

    local function addNameCandidate(value)
        if value ~= nil then
            nameCandidates[#nameCandidates + 1] = value
        end
    end

    if type(fieldState) == "table" then
        addNameCandidate(fieldState.currentFruitTypeName)
        addNameCandidate(fieldState.fruitTypeName)
        addNameCandidate(fieldState.currentCropTypeName)
        addNameCandidate(fieldState.cropTypeName)
    end

    addNameCandidate(field.currentFruitTypeName)
    addNameCandidate(field.fruitTypeName)
    addNameCandidate(field.currentCropTypeName)
    addNameCandidate(field.cropTypeName)

    for _, candidate in ipairs(nameCandidates) do
        local fruitTypeName = normalizeCandidate(candidate)
        if fruitTypeName ~= nil then
            return fruitTypeName, NXFarmKitShared.getFruitTypeIndexByName(fruitTypeName)
        end
    end

    local function resolveIndexCandidate(candidate)
        if type(candidate) ~= "number" or candidate <= 0 then
            return nil
        end

        local fruitTypeName = normalizeCandidate(NXFarmKitShared.getFruitTypeNameByIndex(candidate))
        if fruitTypeName ~= nil then
            return fruitTypeName, candidate
        end

        return nil
    end

    if type(fieldState) == "table" then
        local fruitTypeName, fruitTypeIndex = resolveIndexCandidate(fieldState.currentFruitTypeIndex)
        if fruitTypeName ~= nil then
            return fruitTypeName, fruitTypeIndex
        end

        fruitTypeName, fruitTypeIndex = resolveIndexCandidate(fieldState.fruitTypeIndex)
        if fruitTypeName ~= nil then
            return fruitTypeName, fruitTypeIndex
        end
    end

    local fruitTypeName, fruitTypeIndex = resolveIndexCandidate(field.currentFruitTypeIndex)
    if fruitTypeName ~= nil then
        return fruitTypeName, fruitTypeIndex
    end

    fruitTypeName, fruitTypeIndex = resolveIndexCandidate(field.fruitTypeIndex)
    if fruitTypeName ~= nil then
        return fruitTypeName, fruitTypeIndex
    end

    return nil, nil
end

function NXFarmKitPF.getFallowReferenceFruitContext()
    local fruitTypeName = NXFarmKitPF.normalizeFruitTypeName(NXFarmKitPF.PF_FALLOW_REFERENCE_FRUIT)
    local fruitTypeIndex = NXFarmKitShared.getFruitTypeIndexByName(fruitTypeName)

    return fruitTypeName, fruitTypeIndex
end

function NXFarmKitPF.getActiveFruitContextForSample(point, fallbackFruitTypeName, fallbackFruitTypeIndex)
    local fruitTypeName = nil
    local fruitTypeIndex = nil

    if rawget(_G, "FSDensityMapUtil") ~= nil and FSDensityMapUtil.getFruitTypeIndexAtWorldPos ~= nil then
        local detectedFruitTypeIndex = FSDensityMapUtil.getFruitTypeIndexAtWorldPos(point.x, point.z)
        if type(detectedFruitTypeIndex) == "number" and detectedFruitTypeIndex > 0 then
            fruitTypeIndex = detectedFruitTypeIndex
            fruitTypeName = NXFarmKitPF.normalizeFruitTypeName(NXFarmKitShared.getFruitTypeNameByIndex(detectedFruitTypeIndex))
        end
    end

    if fruitTypeIndex ~= nil and fruitTypeIndex > 0 and fruitTypeName ~= nil then
        return fruitTypeName, fruitTypeIndex, false
    end

    if fallbackFruitTypeIndex ~= nil and fallbackFruitTypeIndex > 0 and fallbackFruitTypeName ~= nil then
        return fallbackFruitTypeName, fallbackFruitTypeIndex, false
    end

    local fallowFruitTypeName, fallowFruitTypeIndex = NXFarmKitPF.getFallowReferenceFruitContext()
    return fallowFruitTypeName, fallowFruitTypeIndex, true
end

function NXFarmKitPF.getPFFillTypeNitrogenAmount(fillTypeName)
    local mapNitrogenAmount = NXFarmKitPF.getCustomMapPFFillTypeNitrogenAmount(fillTypeName)
    if mapNitrogenAmount ~= nil then
        return mapNitrogenAmount
    end

    local pfData = NXFarmKitPF.loadPrecisionFarmingData()
    if pfData == nil or pfData.isLoaded ~= true or fillTypeName == nil then
        return nil
    end

    return pfData.fillTypeNitrogenAmount[NXFarmKitPF.normalizeKey(fillTypeName)]
end

function NXFarmKitPF.getPFNitrogenKgPerHaFromLevel(level)
    local pfData = NXFarmKitPF.loadPrecisionFarmingData()
    if pfData == nil or pfData.isLoaded ~= true then
        return 0
    end

    local state = math.max(math.floor((tonumber(level) or 0) + 0.5), 0)
    if pfData.nitrogenRealValueByState[state] ~= nil then
        return NXFarmKitShared.getSafeNumber(pfData.nitrogenRealValueByState[state])
    end

    return NXFarmKitShared.getSafeNumber(state) * NXFarmKitShared.getSafeNumber(pfData.nitrogenAmountPerState)
end

function NXFarmKitPF.getPFPHRealValueFromLevel(level)
    local pfData = NXFarmKitPF.loadPrecisionFarmingData()
    if pfData == nil or pfData.isLoaded ~= true then
        return nil
    end

    local state = math.max(math.floor((tonumber(level) or 0) + 0.5), 0)
    if pfData.pHRealValueByState[state] ~= nil then
        return pfData.pHRealValueByState[state]
    end

    return nil
end

function NXFarmKitPF.getPFOptimalPHValueForSoilType(soilTypeIndex)
    local pfData = NXFarmKitPF.loadPrecisionFarmingData()
    if pfData == nil or pfData.isLoaded ~= true or soilTypeIndex == nil then
        return nil
    end

    return pfData.optimalPHValueBySoilTypeIndex[soilTypeIndex]
end

function NXFarmKitPF.getFillTypeIndexByName(fillTypeName)
    if fillTypeName == nil or g_fillTypeManager == nil or g_fillTypeManager.getFillTypeByName == nil then
        return nil
    end

    local fillType = g_fillTypeManager:getFillTypeByName(fillTypeName)
    if fillType == nil then
        return nil
    end

    return fillType.index or fillType.id
end

function NXFarmKitPF.getApplicationRateFillTypeName(rateEntry)
    if type(rateEntry) ~= "table" then
        return nil
    end

    local candidates = {
        rateEntry.fillTypeName,
        rateEntry.name
    }

    if type(rateEntry.fillType) == "string" then
        candidates[#candidates + 1] = rateEntry.fillType
    elseif type(rateEntry.fillType) == "table" then
        candidates[#candidates + 1] = rateEntry.fillType.name
        candidates[#candidates + 1] = rateEntry.fillType.title
    end

    for _, candidate in ipairs(candidates) do
        local normalizedCandidate = NXFarmKitPF.normalizeKey(candidate)
        if normalizedCandidate ~= nil and normalizedCandidate ~= "" then
            return normalizedCandidate
        end
    end

    return nil
end

function NXFarmKitPF.applicationRateMatchesFillType(rateEntry, sprayTypeName)
    if type(rateEntry) ~= "table" or sprayTypeName == nil then
        return false
    end

    local wantedFillTypeName = NXFarmKitPF.normalizeKey(sprayTypeName)
    local wantedFillTypeIndex = NXFarmKitPF.getFillTypeIndexByName(sprayTypeName)

    local entryFillTypeName = NXFarmKitPF.getApplicationRateFillTypeName(rateEntry)
    if entryFillTypeName ~= nil and entryFillTypeName == wantedFillTypeName then
        return true
    end

    local numericCandidates = {
        rateEntry.fillTypeIndex,
        rateEntry.fillTypeId
    }

    if type(rateEntry.fillType) == "number" then
        numericCandidates[#numericCandidates + 1] = rateEntry.fillType
    elseif type(rateEntry.fillType) == "table" then
        numericCandidates[#numericCandidates + 1] = rateEntry.fillType.index
        numericCandidates[#numericCandidates + 1] = rateEntry.fillType.id
    end

    if wantedFillTypeIndex ~= nil then
        for _, numericCandidate in ipairs(numericCandidates) do
            if tonumber(numericCandidate) == tonumber(wantedFillTypeIndex) then
                return true
            end
        end
    end

    return false
end

function NXFarmKitPF.getApplicationRateFromRateEntry(rateEntry, soilTypeIndex)
    if type(rateEntry) ~= "table" or soilTypeIndex == nil then
        return nil
    end

    local bySoilType = rateEntry.bySoilType or rateEntry.soils or rateEntry.bySoil
    if type(bySoilType) == "table" then
        local directValue = bySoilType[soilTypeIndex]
        if type(directValue) == "number" then
            return NXFarmKitShared.getSafeNumber(directValue)
        end

        for _, soilSettings in pairs(bySoilType) do
            if type(soilSettings) == "table" then
                local entrySoilTypeIndex = tonumber(soilSettings.soilTypeIndex or soilSettings.index or soilSettings.soilIndex)
                if entrySoilTypeIndex == tonumber(soilTypeIndex) then
                    local rate = soilSettings.rate
                    if rate == nil then
                        rate = soilSettings.value
                    end
                    if rate == nil then
                        rate = soilSettings.target
                    end
                    if rate ~= nil then
                        return NXFarmKitShared.getSafeNumber(rate)
                    end
                end
            end
        end
    end

    return nil
end

function NXFarmKitPF.getRuntimeApplicationRateKgPerHa(maps, sprayTypeName, soilTypeIndex)
    if maps == nil or maps.nitrogenMap == nil or soilTypeIndex == nil then
        return nil
    end

    local applicationRates = maps.nitrogenMap.applicationRates
    if type(applicationRates) ~= "table" then
        return nil
    end

    for _, rateEntry in pairs(applicationRates) do
        if NXFarmKitPF.applicationRateMatchesFillType(rateEntry, sprayTypeName) then
            local runtimeRateKgPerHa = NXFarmKitPF.getApplicationRateFromRateEntry(rateEntry, soilTypeIndex)
            if runtimeRateKgPerHa ~= nil then
                return runtimeRateKgPerHa
            end
        end
    end

    return nil
end

function NXFarmKitPF.getPFOrganicApplicationRateKgPerHa(maps, sprayTypeName, soilTypeIndex)
    if sprayTypeName == nil or soilTypeIndex == nil then
        return nil
    end

    local runtimeRateKgPerHa = NXFarmKitPF.getRuntimeApplicationRateKgPerHa(maps, sprayTypeName, soilTypeIndex)
    if runtimeRateKgPerHa ~= nil then
        return runtimeRateKgPerHa
    end

    local mapRateKgPerHa = NXFarmKitPF.getCustomMapPFApplicationRateKgPerHa(sprayTypeName, soilTypeIndex)
    if mapRateKgPerHa ~= nil then
        return mapRateKgPerHa
    end

    local pfData = NXFarmKitPF.loadPrecisionFarmingData()
    if pfData == nil or pfData.isLoaded ~= true then
        return nil
    end

    local normalizedSprayTypeName = NXFarmKitPF.normalizeKey(sprayTypeName)
    local bySoilType = pfData.applicationRateKgPerHaByFillType[normalizedSprayTypeName]
    if bySoilType == nil then
        return nil
    end

    return bySoilType[soilTypeIndex]
end

function NXFarmKitPF.getPFNitrogenDefaultTargetKgPerHa(maps, soilTypeIndex)
    if soilTypeIndex == nil then
        return nil
    end

    if maps ~= nil and maps.nitrogenMap ~= nil then
        local fruitRequirements = maps.nitrogenMap.fruitRequirements
        if type(fruitRequirements) == "table" and #fruitRequirements > 0 then
            local defaultRequirement = fruitRequirements[1]

            for _, fruitRequirement in ipairs(fruitRequirements) do
                if fruitRequirement ~= nil and fruitRequirement.availableAsDefaultRate == true then
                    defaultRequirement = fruitRequirement
                    break
                end
            end

            if defaultRequirement ~= nil and type(defaultRequirement.bySoilType) == "table" then
                for _, soilSettings in ipairs(defaultRequirement.bySoilType) do
                    if soilSettings ~= nil and soilSettings.soilTypeIndex == soilTypeIndex then
                        local targetLevel = soilSettings.targetLevel
                        if targetLevel ~= nil and maps.nitrogenMap.getNitrogenValueFromInternalValue ~= nil then
                            return NXFarmKitShared.getSafeNumber(maps.nitrogenMap:getNitrogenValueFromInternalValue(targetLevel))
                        end

                        return NXFarmKitPF.getPFNitrogenKgPerHaFromLevel(targetLevel)
                    end
                end
            end
        end
    end

    local pfData = NXFarmKitPF.loadPrecisionFarmingData()
    if pfData == nil or pfData.isLoaded ~= true then
        return nil
    end

    local xmlDefaultTargetKgPerHa = pfData.defaultNitrogenTargetKgPerHaBySoilType[soilTypeIndex]
    if xmlDefaultTargetKgPerHa ~= nil then
        return xmlDefaultTargetKgPerHa
    end

    if pfData.nitrogenDefaultRate ~= nil then
        if maps ~= nil and maps.nitrogenMap ~= nil and maps.nitrogenMap.getNitrogenValueFromInternalValue ~= nil then
            return NXFarmKitShared.getSafeNumber(maps.nitrogenMap:getNitrogenValueFromInternalValue(pfData.nitrogenDefaultRate))
        end

        return NXFarmKitPF.getPFNitrogenKgPerHaFromLevel(pfData.nitrogenDefaultRate)
    end

    return nil
end

function NXFarmKitPF.getPFNitrogenTargetKgPerHa(maps, fruitTypeName, fruitTypeIndex, soilTypeIndex)
    if soilTypeIndex == nil then
        return nil
    end

    if maps ~= nil and maps.nitrogenMap ~= nil and fruitTypeIndex ~= nil and fruitTypeIndex > 0 and maps.nitrogenMap.getNitrogenTargetLevel ~= nil then
        local targetLevel = maps.nitrogenMap:getNitrogenTargetLevel(fruitTypeIndex, soilTypeIndex)
        if targetLevel ~= nil and maps.nitrogenMap.getNitrogenValueFromInternalValue ~= nil then
            return NXFarmKitShared.getSafeNumber(maps.nitrogenMap:getNitrogenValueFromInternalValue(targetLevel))
        elseif targetLevel ~= nil then
            return NXFarmKitPF.getPFNitrogenKgPerHaFromLevel(targetLevel)
        end
    end

    local defaultTargetKgPerHa = NXFarmKitPF.getPFNitrogenDefaultTargetKgPerHa(maps, soilTypeIndex)
    if defaultTargetKgPerHa ~= nil then
        return defaultTargetKgPerHa
    end

    local pfData = NXFarmKitPF.loadPrecisionFarmingData()
    if pfData == nil or pfData.isLoaded ~= true or fruitTypeName == nil then
        return nil
    end

    local bySoilType = pfData.fruitRequirementTargetByFruitName[NXFarmKitPF.normalizeKey(fruitTypeName)]
    if bySoilType == nil then
        return nil
    end

    return bySoilType[soilTypeIndex]
end

function NXFarmKitPF.getPFNitrogenKgPerHaForStates(stateCount)
    local pfData = NXFarmKitPF.loadPrecisionFarmingData()
    if pfData == nil or pfData.isLoaded ~= true then
        return 0
    end

    local nitrogenAmountPerState = NXFarmKitShared.getSafeNumber(pfData.nitrogenAmountPerState)
    if nitrogenAmountPerState <= 0 then
        return 0
    end

    return NXFarmKitShared.getSafeNumber(stateCount) * nitrogenAmountPerState
end

function NXFarmKitPF.convertPFNitrogenAmountToLitersPerHa(sprayTypeName, nitrogenAmountKgPerHa)
    if nitrogenAmountKgPerHa == nil or nitrogenAmountKgPerHa <= 0 or sprayTypeName == nil then
        return 0
    end

    local nitrogenAmountPerUnit = NXFarmKitPF.getPFFillTypeNitrogenAmount(sprayTypeName)
    if nitrogenAmountPerUnit == nil or nitrogenAmountPerUnit <= 0 then
        return 0
    end

    local normalizedSprayTypeName = NXFarmKitPF.normalizeKey(sprayTypeName)

    if normalizedSprayTypeName == "LIQUIDMANURE" or normalizedSprayTypeName == "DIGESTATE" then
        return nitrogenAmountKgPerHa / nitrogenAmountPerUnit
    end

    local massPerLiter = NXFarmKitShared.getFillTypeMassPerLiter(sprayTypeName) or 1
    if massPerLiter <= 0 then
        massPerLiter = 1
    end

    return nitrogenAmountKgPerHa / (nitrogenAmountPerUnit * massPerLiter)
end

function NXFarmKitPF.getPFLitersPerHaByFillType(fillTypeName)
    local normalizedFillTypeName = NXFarmKitPF.normalizeKey(fillTypeName)

    if normalizedFillTypeName == "LIME" then
        local pfData = NXFarmKitPF.loadPrecisionFarmingData()
        if pfData == nil or pfData.isLoaded ~= true then
            return nil
        end

        local massPerLiter = NXFarmKitShared.getFillTypeMassPerLiter("LIME") or 1
        return pfData.regularLimeKgPerHa / massPerLiter
    end

    local mapRegularNitrogenKgPerHa = NXFarmKitPF.getCustomMapPFRegularRateKgPerHa(fillTypeName)
    if mapRegularNitrogenKgPerHa ~= nil then
        return NXFarmKitPF.convertPFNitrogenAmountToLitersPerHa(fillTypeName, mapRegularNitrogenKgPerHa)
    end

    local pfData = NXFarmKitPF.loadPrecisionFarmingData()
    if pfData == nil or pfData.isLoaded ~= true or fillTypeName == nil then
        return nil
    end

    local nitrogenAmount = pfData.regularNitrogenKgPerHaByFillType[normalizedFillTypeName]
    if nitrogenAmount == nil then
        return nil
    end

    return NXFarmKitPF.convertPFNitrogenAmountToLitersPerHa(fillTypeName, nitrogenAmount)
end

function NXFarmKitPF.getPFLimeLitersPerHaForSample(sample)
    if sample == nil or sample.soilTypeIndex == nil or sample.soilTypeIndex <= 0 then
        return nil
    end

    local currentPHLevel = tonumber(sample.pHLevel)
    local targetPHLevel = tonumber(sample.optimalPHLevel)

    if currentPHLevel == nil or targetPHLevel == nil then
        return nil
    end

    local pfData = NXFarmKitPF.loadPrecisionFarmingData()
    if pfData == nil or pfData.isLoaded ~= true then
        return nil
    end

    local limeUsagePerState = pfData.limeUsagePerState or 0
    if limeUsagePerState <= 0 then
        return 0
    end

    local missingPHStates = math.max(targetPHLevel - currentPHLevel, 0)
    if missingPHStates <= 0 then
        return 0
    end

    return missingPHStates * limeUsagePerState
end

function NXFarmKitPF.getPFMaterialLitersPerHaForSample(sample, sprayTypeName)
    if sample == nil or sprayTypeName == nil then
        return nil
    end

    local normalizedSprayTypeName = NXFarmKitPF.normalizeKey(sprayTypeName)
    if normalizedSprayTypeName == "HERBICIDE" then
        return nil
    end

    local currentNitrogenKgPerHa = NXFarmKitShared.getSafeNumber(sample.nitrogenKgPerHa)
    local targetNitrogenKgPerHa = NXFarmKitPF.getNitrogenTargetKgPerHaForSample(sample, sprayTypeName)

    if targetNitrogenKgPerHa == nil then
        return 0
    end

    local nitrogenAmountKgPerHa = math.max(NXFarmKitShared.getSafeNumber(targetNitrogenKgPerHa) - currentNitrogenKgPerHa, 0)
    return NXFarmKitPF.convertPFNitrogenAmountToLitersPerHa(sprayTypeName, nitrogenAmountKgPerHa)
end

function NXFarmKitPF.getAverageFromSamples(samples, callback)
    local total = 0
    local count = 0

    for _, sample in ipairs(samples or {}) do
        local value = callback(sample)
        if type(value) == "number" then
            total = total + value
            count = count + 1
        end
    end

    if count == 0 then
        return nil
    end

    return total / count
end

function NXFarmKitPF.getPFLimeRestAreaRatio(samples, practicalNeedMask)
    local sampleCount = #(samples or {})
    if sampleCount <= 0 then
        return 0
    end

    local pfData = NXFarmKitPF.loadPrecisionFarmingData()
    local limeUsagePerState = pfData ~= nil and pfData.isLoaded == true and NXFarmKitShared.getSafeNumber(pfData.limeUsagePerState) or 0
    local significantRestStates = NXFarmKitShared.getSafeNumber(NXFarmKitPF.PF_LIME_AFTER_SIGNIFICANT_REST_STATES)
    local significantRestLitersPerHa = significantRestStates * limeUsagePerState
    local needCount = 0

    for sampleIndex, sample in ipairs(samples or {}) do
        local litersPerHa = NXFarmKitPF.getPFLimeLitersPerHaForSample(sample) or 0

        if practicalNeedMask ~= nil and litersPerHa > 0 and practicalNeedMask[sampleIndex] ~= true then
            litersPerHa = 0
        end

        if significantRestLitersPerHa > 0 then
            if litersPerHa >= significantRestLitersPerHa then
                needCount = needCount + 1
            end
        elseif litersPerHa > 0 then
            needCount = needCount + 1
        end
    end

    return needCount / sampleCount
end

function NXFarmKitPF.getPFLimeAverageNearestSampleDistance(samples)
    local totalDistance = 0
    local distanceCount = 0

    for sampleIndex, sample in ipairs(samples or {}) do
        local sampleX = tonumber(sample ~= nil and sample.worldX)
        local sampleZ = tonumber(sample ~= nil and sample.worldZ)

        if sampleX ~= nil and sampleZ ~= nil then
            local nearestDistanceSq = nil

            for otherIndex, otherSample in ipairs(samples or {}) do
                if otherIndex ~= sampleIndex then
                    local otherX = tonumber(otherSample ~= nil and otherSample.worldX)
                    local otherZ = tonumber(otherSample ~= nil and otherSample.worldZ)

                    if otherX ~= nil and otherZ ~= nil then
                        local distanceX = sampleX - otherX
                        local distanceZ = sampleZ - otherZ
                        local distanceSq = (distanceX * distanceX) + (distanceZ * distanceZ)

                        if nearestDistanceSq == nil or distanceSq < nearestDistanceSq then
                            nearestDistanceSq = distanceSq
                        end
                    end
                end
            end

            if nearestDistanceSq ~= nil and nearestDistanceSq > 0 then
                totalDistance = totalDistance + math.sqrt(nearestDistanceSq)
                distanceCount = distanceCount + 1
            end
        end
    end

    if distanceCount <= 0 then
        return 0
    end

    return totalDistance / distanceCount
end

function NXFarmKitPF.getPFLimePracticalNeedMask(samples)
    local rawRestAreaRatio = NXFarmKitPF.getPFLimeRestAreaRatio(samples)
    local maxPracticalRestAreaRatio = NXFarmKitShared.getSafeNumber(NXFarmKitPF.PF_LIME_PRACTICAL_REST_AREA_RATIO_MAX)

    if rawRestAreaRatio <= 0 or rawRestAreaRatio > maxPracticalRestAreaRatio then
        return nil
    end

    local averageNearestDistance = NXFarmKitPF.getPFLimeAverageNearestSampleDistance(samples)
    if averageNearestDistance <= 0 then
        return nil
    end

    local neighborRadiusFactor = NXFarmKitShared.getSafeNumber(NXFarmKitPF.PF_LIME_PRACTICAL_NEIGHBOR_RADIUS_FACTOR)
    local neighborRadius = averageNearestDistance * neighborRadiusFactor
    if neighborRadius <= 0 then
        return nil
    end

    local minNeedNeighbors = math.max(math.floor(NXFarmKitShared.getSafeNumber(NXFarmKitPF.PF_LIME_PRACTICAL_MIN_NEED_NEIGHBORS)), 0)
    if minNeedNeighbors <= 0 then
        return nil
    end

    local needIndices = {}
    for sampleIndex, sample in ipairs(samples or {}) do
        local litersPerHa = NXFarmKitPF.getPFLimeLitersPerHaForSample(sample) or 0
        if litersPerHa > 0 then
            needIndices[#needIndices + 1] = sampleIndex
        end
    end

    if #needIndices <= 0 then
        return nil
    end

    local neighborRadiusSq = neighborRadius * neighborRadius
    local practicalNeedMask = {}

    for _, sampleIndex in ipairs(needIndices) do
        local sample = samples[sampleIndex]
        local sampleX = tonumber(sample ~= nil and sample.worldX)
        local sampleZ = tonumber(sample ~= nil and sample.worldZ)
        local neighborCount = 0

        if sampleX ~= nil and sampleZ ~= nil then
            for _, otherIndex in ipairs(needIndices) do
                if otherIndex ~= sampleIndex then
                    local otherSample = samples[otherIndex]
                    local otherX = tonumber(otherSample ~= nil and otherSample.worldX)
                    local otherZ = tonumber(otherSample ~= nil and otherSample.worldZ)

                    if otherX ~= nil and otherZ ~= nil then
                        local distanceX = sampleX - otherX
                        local distanceZ = sampleZ - otherZ
                        local distanceSq = (distanceX * distanceX) + (distanceZ * distanceZ)

                        if distanceSq <= neighborRadiusSq then
                            neighborCount = neighborCount + 1
                            if neighborCount >= minNeedNeighbors then
                                practicalNeedMask[sampleIndex] = true
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    return practicalNeedMask
end

function NXFarmKitPF.getPFLimePracticalAverageLitersPerHa(samples)
    local sampleCount = #(samples or {})
    if sampleCount <= 0 then
        return nil
    end

    local practicalNeedMask = NXFarmKitPF.getPFLimePracticalNeedMask(samples)
    local totalLitersPerHa = 0

    for sampleIndex, sample in ipairs(samples or {}) do
        local litersPerHa = NXFarmKitPF.getPFLimeLitersPerHaForSample(sample) or 0

        if practicalNeedMask ~= nil and litersPerHa > 0 and practicalNeedMask[sampleIndex] ~= true then
            litersPerHa = 0
        end

        totalLitersPerHa = totalLitersPerHa + litersPerHa
    end

    return totalLitersPerHa / sampleCount
end

function NXFarmKitPF.getPFLimeLoadLitersPerHa(rawLitersPerHa)
    local safeLitersPerHa = NXFarmKitShared.getSafeNumber(rawLitersPerHa)
    if safeLitersPerHa <= 0 then
        return 0
    end

    local loadBufferLitersPerHa = NXFarmKitShared.getSafeNumber(NXFarmKitPF.PF_LIME_LOAD_BUFFER_LITERS_PER_HA)
    return safeLitersPerHa + loadBufferLitersPerHa
end

function NXFarmKitPF.getPFLimeDisplayLitersPerHa(rawLitersPerHa, samples)
    local safeLitersPerHa = NXFarmKitShared.getSafeNumber(rawLitersPerHa)
    if safeLitersPerHa <= 0 then
        return 0
    end

    local practicalNeedMask = NXFarmKitPF.getPFLimePracticalNeedMask(samples)
    local restAreaRatio = NXFarmKitPF.getPFLimeRestAreaRatio(samples, practicalNeedMask)
    local maxRestAreaRatio = NXFarmKitShared.getSafeNumber(NXFarmKitPF.PF_LIME_AFTER_MAX_REST_AREA_RATIO)

    if restAreaRatio <= maxRestAreaRatio then
        return 0
    end

    return NXFarmKitPF.getPFLimeLoadLitersPerHa(safeLitersPerHa)
end

function NXFarmKitPF.getPFNitrogenAverageDeficitKgPerHa(samples, sprayTypeName)
    return NXFarmKitPF.getAverageFromSamples(samples, function(sample)
        if sample == nil then
            return 0
        end

        local currentNitrogenKgPerHa = NXFarmKitShared.getSafeNumber(sample.nitrogenKgPerHa)
        local targetNitrogenKgPerHa = NXFarmKitPF.getNitrogenTargetKgPerHaForSample(sample, sprayTypeName)
        if targetNitrogenKgPerHa == nil then
            return 0
        end

        return math.max(NXFarmKitShared.getSafeNumber(targetNitrogenKgPerHa) - currentNitrogenKgPerHa, 0)
    end) or 0
end

function NXFarmKitPF.areAllSamplesUsingFallowReference(samples)
    local hasSamples = false

    for _, sample in ipairs(samples or {}) do
        hasSamples = true

        if sample == nil or sample.usedFallowReference ~= true then
            return false
        end
    end

    return hasSamples
end

function NXFarmKitPF.getPFNitrogenLoadLitersPerHa(rawLitersPerHa, sprayTypeName, samples)
    local safeLitersPerHa = NXFarmKitShared.getSafeNumber(rawLitersPerHa)
    if safeLitersPerHa <= 0 or sprayTypeName == nil then
        return 0
    end

    local totalBufferStates = NXFarmKitShared.getSafeNumber(NXFarmKitPF.PF_NITROGEN_LOAD_BUFFER_STATES)

    local normalizedSprayTypeName = NXFarmKitPF.normalizeKey(sprayTypeName)
    if (normalizedSprayTypeName == "FERTILIZER" or normalizedSprayTypeName == "LIQUIDFERTILIZER") and NXFarmKitPF.areAllSamplesUsingFallowReference(samples) then
        totalBufferStates = totalBufferStates + NXFarmKitShared.getSafeNumber(NXFarmKitPF.PF_FALLOW_NITROGEN_EXTRA_LOAD_BUFFER_STATES)
    end

    local bufferKgPerHa = NXFarmKitPF.getPFNitrogenKgPerHaForStates(totalBufferStates)
    local bufferLitersPerHa = NXFarmKitPF.convertPFNitrogenAmountToLitersPerHa(sprayTypeName, bufferKgPerHa)

    return safeLitersPerHa + NXFarmKitShared.getSafeNumber(bufferLitersPerHa)
end

function NXFarmKitPF.getPFNitrogenDisplayLitersPerHa(rawLitersPerHa, sprayTypeName, samples)
    local safeLitersPerHa = NXFarmKitShared.getSafeNumber(rawLitersPerHa)
    if safeLitersPerHa <= 0 then
        return 0
    end

    local averageDeficitKgPerHa = NXFarmKitPF.getPFNitrogenAverageDeficitKgPerHa(samples, sprayTypeName)
    local maxRestKgPerHa = NXFarmKitPF.getPFNitrogenKgPerHaForStates(NXFarmKitPF.PF_NITROGEN_AFTER_MAX_REST_STATES)

    if averageDeficitKgPerHa <= maxRestKgPerHa then
        return 0
    end

    return NXFarmKitPF.getPFNitrogenLoadLitersPerHa(rawLitersPerHa, sprayTypeName, samples)
end

function NXFarmKitPF.getAverageLitersPerHa(samples, sprayTypeName)
    if sprayTypeName == "LIME" then
        return NXFarmKitPF.getPFLimePracticalAverageLitersPerHa(samples)
    end

    if sprayTypeName == "HERBICIDE" then
        return nil
    end

    -- Liquid Lime: PF doesn't model it as nitrogen; skip runtime sampling so the
    -- baseline rate (litersPerSecond * 36000) is preserved by the caller.
    if sprayTypeName == "LIQUIDLIME" then
        return nil
    end

    return NXFarmKitPF.getAverageFromSamples(samples, function(sample)
        return NXFarmKitPF.getPFMaterialLitersPerHaForSample(sample, sprayTypeName)
    end)
end

function NXFarmKitPF.getRuntimeFieldSamples(field)
    local maps = NXFarmKitPF.getRuntimeMaps()
    if maps == nil then
        if not NXFarmKitPF.runtimeUnavailableLogged then
            pfLogWarning("PF runtime unavailable - using Precision Farming XML values")
            NXFarmKitPF.runtimeUnavailableLogged = true
        end
        return {}
    end

    NXFarmKitPF.runtimeUnavailableLogged = false

    local fallbackFruitTypeName, fallbackFruitTypeIndex = NXFarmKitPF.getFruitContext(field)
    local customDefinitions = {}

    if rawget(_G, "NXFarmKitShared") ~= nil
        and NXFarmKitShared.getCustomMapFertilizerDefinitions ~= nil then
        customDefinitions = NXFarmKitShared.getCustomMapFertilizerDefinitions()
    end

    local samplePoints = NXFarmKitShared.getFieldSamplePoints(field)
    local fieldContext = NXFarmKitPF.buildRuntimeFieldContext(field, maps, samplePoints)

    local function collectSamples(useCoverFilter, useGroundFilter)
        local samples = {}

        for pointIndex, pointContext in ipairs(fieldContext.pointContexts or {}) do
            local point = pointContext.point
            if point ~= nil then
                local skipPoint = false

                if useCoverFilter and fieldContext.resolvedCoverValue ~= nil then
                    if tostring(pointContext.coverValue) ~= tostring(fieldContext.resolvedCoverValue) then
                        skipPoint = true
                    end
                end

                if not skipPoint and useGroundFilter and fieldContext.resolvedGroundTypeIndex ~= nil then
                    if tonumber(pointContext.groundTypeIndex) ~= tonumber(fieldContext.resolvedGroundTypeIndex) then
                        skipPoint = true
                    end
                end

                if not skipPoint then
                    local soilTypeIndex = nil
                    local pHLevel = nil
                    local nitrogenLevel = nil

                    if maps.soilMap.getTypeIndexAtWorldPos ~= nil then
                        soilTypeIndex = maps.soilMap:getTypeIndexAtWorldPos(point.x, point.z)
                    end

                    if soilTypeIndex ~= nil and soilTypeIndex > 0 then
                        if maps.pHMap.getLevelAtWorldPos ~= nil then
                            pHLevel = maps.pHMap:getLevelAtWorldPos(point.x, point.z)
                        end

                        if maps.nitrogenMap.getLevelAtWorldPos ~= nil then
                            nitrogenLevel = maps.nitrogenMap:getLevelAtWorldPos(point.x, point.z)
                        end
                    end

                    if soilTypeIndex ~= nil and soilTypeIndex > 0 and pHLevel ~= nil and nitrogenLevel ~= nil then
                        local pHRealValue = nil
                        if maps.pHMap.getPhValueFromInternalValue ~= nil then
                            pHRealValue = maps.pHMap:getPhValueFromInternalValue(pHLevel)
                        else
                            pHRealValue = NXFarmKitPF.getPFPHRealValueFromLevel(pHLevel)
                        end

                        local optimalPHLevel = nil
                        if maps.pHMap.getOptimalPHValueForSoilTypeIndex ~= nil then
                            optimalPHLevel = maps.pHMap:getOptimalPHValueForSoilTypeIndex(soilTypeIndex)
                        end
                        if optimalPHLevel == nil then
                            optimalPHLevel = NXFarmKitPF.getPFOptimalPHValueForSoilType(soilTypeIndex)
                        end

                        local optimalPHValue = nil
                        if optimalPHLevel ~= nil then
                            if maps.pHMap.getPhValueFromInternalValue ~= nil then
                                optimalPHValue = maps.pHMap:getPhValueFromInternalValue(optimalPHLevel)
                            else
                                optimalPHValue = NXFarmKitPF.getPFPHRealValueFromLevel(optimalPHLevel)
                            end
                        end

                        local nitrogenKgPerHa = 0
                        if maps.nitrogenMap.getNitrogenValueFromInternalValue ~= nil then
                            nitrogenKgPerHa = NXFarmKitShared.getSafeNumber(maps.nitrogenMap:getNitrogenValueFromInternalValue(nitrogenLevel))
                        else
                            nitrogenKgPerHa = NXFarmKitPF.getPFNitrogenKgPerHaFromLevel(nitrogenLevel)
                        end

                        local activeFruitTypeName, activeFruitTypeIndex, usedFallowReference = NXFarmKitPF.getActiveFruitContextForSample(point, fallbackFruitTypeName, fallbackFruitTypeIndex)
                        local nitrogenTargetKgPerHa = NXFarmKitPF.getPFNitrogenTargetKgPerHa(maps, activeFruitTypeName, activeFruitTypeIndex, soilTypeIndex)

                        local manureNitrogenTargetKgPerHa = NXFarmKitPF.getPFOrganicApplicationRateKgPerHa(maps, "MANURE", soilTypeIndex)
                        local slurryNitrogenTargetKgPerHa = NXFarmKitPF.getPFOrganicApplicationRateKgPerHa(maps, "LIQUIDMANURE", soilTypeIndex)
                        local digestateNitrogenTargetKgPerHa = NXFarmKitPF.getPFOrganicApplicationRateKgPerHa(maps, "DIGESTATE", soilTypeIndex)
                        local customNitrogenTargetKgPerHaBySprayType = {}

                        for _, definition in ipairs(customDefinitions) do
                            local customNitrogenTargetKgPerHa = NXFarmKitPF.getPFOrganicApplicationRateKgPerHa(maps, definition.sprayType, soilTypeIndex)
                            if customNitrogenTargetKgPerHa ~= nil then
                                customNitrogenTargetKgPerHaBySprayType[NXFarmKitPF.normalizeKey(definition.sprayType)] = customNitrogenTargetKgPerHa
                            end
                        end

                        local organicNitrogenTargetKgPerHa = manureNitrogenTargetKgPerHa
                        if organicNitrogenTargetKgPerHa == nil then
                            organicNitrogenTargetKgPerHa = slurryNitrogenTargetKgPerHa
                        end
                        if organicNitrogenTargetKgPerHa == nil then
                            organicNitrogenTargetKgPerHa = digestateNitrogenTargetKgPerHa
                        end
                        if organicNitrogenTargetKgPerHa == nil then
                            organicNitrogenTargetKgPerHa = nitrogenTargetKgPerHa
                        end

                        samples[#samples + 1] = {
                            source = "pf-runtime",
                            worldX = point.x,
                            worldZ = point.z,
                            soilTypeIndex = soilTypeIndex,
                            pHLevel = pHLevel,
                            pHRealValue = pHRealValue,
                            optimalPHLevel = optimalPHLevel,
                            optimalPHValue = optimalPHValue,
                            nitrogenLevel = nitrogenLevel,
                            nitrogenKgPerHa = nitrogenKgPerHa,
                            fruitTypeIndex = activeFruitTypeIndex,
                            fruitTypeName = activeFruitTypeName,
                            usedFallowReference = usedFallowReference == true,
                            nitrogenTargetKgPerHa = nitrogenTargetKgPerHa,
                            organicNitrogenTargetKgPerHa = organicNitrogenTargetKgPerHa,
                            manureNitrogenTargetKgPerHa = manureNitrogenTargetKgPerHa,
                            slurryNitrogenTargetKgPerHa = slurryNitrogenTargetKgPerHa,
                            digestateNitrogenTargetKgPerHa = digestateNitrogenTargetKgPerHa,
                            customNitrogenTargetKgPerHaBySprayType = customNitrogenTargetKgPerHaBySprayType
                        }

                        NXFarmKitPF.logOrganicTargetComparison(field, pointIndex, soilTypeIndex, nitrogenKgPerHa, organicNitrogenTargetKgPerHa, nitrogenTargetKgPerHa, activeFruitTypeName, usedFallowReference)
                    end
                end
            end
        end

        return samples
    end

    local attempts = {
        { fieldContext.applyCoverFilter == true, fieldContext.applyGroundFilter == true }
    }

    if fieldContext.applyGroundFilter == true then
        attempts[#attempts + 1] = { fieldContext.applyCoverFilter == true, false }
    end

    if fieldContext.applyCoverFilter == true and fieldContext.applyGroundFilter == true then
        attempts[#attempts + 1] = { false, true }
    end

    attempts[#attempts + 1] = { false, false }

    for _, attempt in ipairs(attempts) do
        local samples = collectSamples(attempt[1], attempt[2])
        if #samples > 0 then
            return samples
        end
    end

    return {}
end

function NXFarmKitPF.buildFieldEntry(field)
    local areaHa = NXFarmKitShared.getFieldAreaHa(field)
    local pfData = NXFarmKitPF.loadPrecisionFarmingData()
    local pfSamples = NXFarmKitPF.getRuntimeFieldSamples(field)
    local hasRuntimeSamples = #pfSamples > 0

    if not hasRuntimeSamples and not NXFarmKitPF.xmlFallbackLogged and pfData ~= nil and pfData.isLoaded == true then
    end

    local entry = {
        fieldId = NXFarmKitShared.getFieldDisplayId(field),
        rawField = field,
        farmId = NXFarmKitShared.getFarmIdForField(field),
        areaHa = areaHa,
        materials = {},
        customMaterials = {},
        isPrecisionFarming = true
    }

    local materialOrder = NXFarmKitShared.getMaterialDefinitionsWithCustomFertilizers()

    for _, definition in ipairs(materialOrder) do
        local litersPerSecond = NXFarmKitShared.getSprayTypeRate(definition.sprayType)
        if definition.isCustomMapFertilizer == true and definition.litersPerSecond ~= nil and definition.litersPerSecond > 0 then
            litersPerSecond = definition.litersPerSecond
        end

        local rawLitersPerHa = litersPerSecond * 36000
        local displayLitersPerHa = rawLitersPerHa
        local sourceName = definition.isCustomMapFertilizer == true and "map-sprayTypes" or "vanilla"

        local runtimeLitersPerHa = nil
        if hasRuntimeSamples then
            runtimeLitersPerHa = NXFarmKitPF.getAverageLitersPerHa(pfSamples, definition.sprayType)
        end

        if runtimeLitersPerHa ~= nil then
            rawLitersPerHa = runtimeLitersPerHa
            displayLitersPerHa = runtimeLitersPerHa

            if definition.isCustomMapFertilizer == true then
                sourceName = "map-pf-runtime"
            end
        elseif definition.isCustomMapFertilizer == true or (pfData ~= nil and pfData.isLoaded == true) then
            local xmlLitersPerHa = NXFarmKitPF.getPFLitersPerHaByFillType(definition.sprayType)
            if xmlLitersPerHa ~= nil then
                rawLitersPerHa = xmlLitersPerHa
                displayLitersPerHa = xmlLitersPerHa

                if definition.isCustomMapFertilizer == true then
                    local mapRegularRateKgPerHa = NXFarmKitPF.getCustomMapPFRegularRateKgPerHa(definition.sprayType)

                    if mapRegularRateKgPerHa ~= nil then
                        sourceName = "map-pf-xml"
                    else
                        sourceName = "pf-xml"
                    end
                end
            end
        end

        if definition.sprayType == "LIME" then
            if hasRuntimeSamples and runtimeLitersPerHa ~= nil then
                displayLitersPerHa = NXFarmKitPF.getPFLimeDisplayLitersPerHa(rawLitersPerHa, pfSamples)
            elseif pfData ~= nil and pfData.isLoaded == true then
                displayLitersPerHa = NXFarmKitPF.getPFLimeLoadLitersPerHa(rawLitersPerHa)
            end
        elseif definition.sprayType ~= "HERBICIDE" and definition.sprayType ~= "LIQUIDLIME" then
            if hasRuntimeSamples and runtimeLitersPerHa ~= nil then
                displayLitersPerHa = NXFarmKitPF.getPFNitrogenDisplayLitersPerHa(rawLitersPerHa, definition.sprayType, pfSamples)
            elseif pfData ~= nil and pfData.isLoaded == true then
                displayLitersPerHa = NXFarmKitPF.getPFNitrogenLoadLitersPerHa(rawLitersPerHa, definition.sprayType, pfSamples)
            end
        end

        local targetTable = entry.materials
        if definition.isCustomMapFertilizer == true then
            targetTable = entry.customMaterials
        end

        targetTable[definition.key] = {
            litersPerSecond = litersPerSecond,
            litersPerHa = displayLitersPerHa,
            totalLiters = NXFarmKitShared.calculateTotalLitersFromLitersPerHa(areaHa, displayLitersPerHa)
        }

        if definition.isCustomMapFertilizer == true then
            NXFarmKitShared.logCustomMaterialFieldData(
                field,
                definition.sprayType,
                sourceName,
                litersPerSecond,
                rawLitersPerHa,
                displayLitersPerHa,
                targetTable[definition.key].totalLiters
            )
        end
    end

    return entry
end

function NXFarmKitPF.clearPrecisionFarmingSavegameCache()
end

function NXFarmKitPF.logPFStatusOnce(mode)
end

function NXFarmKitPF.logPFSavegameIssue(message)
end

function NXFarmKitPF.logPFSoilMapInfo(message)
end
