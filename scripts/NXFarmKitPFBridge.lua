NXFarmKitPFBridge = {}

NXFarmKitPFBridge.VERSION = "1.0.0.0"
NXFarmKitPFBridge.LOG_PREFIX = "[FS25_FarmKit] PF-Bridge: "

NXFarmKitPFBridge.hooksInstalled = false
NXFarmKitPFBridge.loadMapHookInstalled = false
NXFarmKitPFBridge.initTerrainHookInstalled = false
NXFarmKitPFBridge.loggedWaiting = false

NXFarmKitPFBridge.pfNamespace = nil
NXFarmKitPFBridge.pfClass = nil
NXFarmKitPFBridge.pfInstance = nil
NXFarmKitPFBridge.soilMap = nil
NXFarmKitPFBridge.pHMap = nil
NXFarmKitPFBridge.nitrogenMap = nil
NXFarmKitPFBridge.coverMap = nil
NXFarmKitPFBridge.runtimeReady = false

local function bridgeInfo(fmt, ...)
    Logging.info(NXFarmKitPFBridge.LOG_PREFIX .. string.format(fmt, ...))
end

local function bridgeWarning(fmt, ...)
    Logging.warning(NXFarmKitPFBridge.LOG_PREFIX .. string.format(fmt, ...))
end

local function safeGlobal(name)
    local ok, value = pcall(function()
        return _G[name]
    end)

    if ok then
        return value
    end

    return nil
end

local function getPFNamespace()
    local pfNamespace = safeGlobal("FS25_precisionFarming")
    if type(pfNamespace) == "table" then
        return pfNamespace
    end

    return nil
end

local function getPFClass()
    local pfClass = safeGlobal("PrecisionFarming")
    if type(pfClass) == "table" then
        return pfClass, "global"
    end

    local pfNamespace = getPFNamespace()
    if type(pfNamespace) == "table" and type(pfNamespace.PrecisionFarming) == "table" then
        return pfNamespace.PrecisionFarming, "namespace"
    end

    return nil, nil
end

local function getPFInstance()
    local pfInstance = safeGlobal("g_precisionFarming")
    if type(pfInstance) == "table" then
        return pfInstance, "global"
    end

    local pfNamespace = getPFNamespace()
    if type(pfNamespace) == "table" and type(pfNamespace.g_precisionFarming) == "table" then
        return pfNamespace.g_precisionFarming, "namespace"
    end

    return nil, nil
end

local function isPrecisionFarmingLoaded()
    local modIsLoaded = safeGlobal("g_modIsLoaded")
    if type(modIsLoaded) == "table" then
        return modIsLoaded["FS25_precisionFarming"] == true
    end

    return getPFNamespace() ~= nil
end

function NXFarmKitPFBridge.updateAliases(instance, source)
    if type(instance) ~= "table" then
        return false
    end

    NXFarmKitPFBridge.pfInstance = instance
    NXFarmKitPFBridge.soilMap = instance.soilMap
    NXFarmKitPFBridge.pHMap = instance.pHMap
    NXFarmKitPFBridge.nitrogenMap = instance.nitrogenMap
    NXFarmKitPFBridge.coverMap = instance.coverMap
    NXFarmKitPFBridge.runtimeReady = NXFarmKitPFBridge.soilMap ~= nil
        and NXFarmKitPFBridge.pHMap ~= nil
        and NXFarmKitPFBridge.nitrogenMap ~= nil
        and NXFarmKitPFBridge.coverMap ~= nil

    _G.g_precisionFarming = instance

    if NXFarmKitPFBridge.pfClass ~= nil then
        _G.PrecisionFarming = NXFarmKitPFBridge.pfClass
    end

    if g_currentMission ~= nil then
        g_currentMission.g_precisionFarming = instance
    end

    return true
end

function NXFarmKitPFBridge.captureFromNamespace(source)
    local pfNamespace = getPFNamespace()
    local pfClass, classSource = getPFClass()
    local pfInstance, instanceSource = getPFInstance()

    NXFarmKitPFBridge.pfNamespace = pfNamespace
    NXFarmKitPFBridge.pfClass = pfClass

    if pfClass ~= nil then
        _G.PrecisionFarming = pfClass
    end

    if pfInstance ~= nil then
        return NXFarmKitPFBridge.updateAliases(pfInstance, source or instanceSource or "capture")
    end

    return false
end

function NXFarmKitPFBridge.pfLoadMapHook(self, superFunc, filename)
    local result
    if superFunc ~= nil then
        result = superFunc(self, filename)
    end

    NXFarmKitPFBridge.updateAliases(self, "loadMap")

    local pfNamespace = NXFarmKitPFBridge.pfNamespace
    if pfNamespace ~= nil then
        pfNamespace.g_precisionFarming = self
    end

    return result
end

function NXFarmKitPFBridge.pfInitTerrainHook(self, superFunc, mission, terrainId, filename)
    local result
    if superFunc ~= nil then
        result = superFunc(self, mission, terrainId, filename)
    end

    NXFarmKitPFBridge.updateAliases(self, "initTerrain")

    local pfNamespace = NXFarmKitPFBridge.pfNamespace
    if pfNamespace ~= nil then
        pfNamespace.g_precisionFarming = self
    end

    return result
end

function NXFarmKitPFBridge.installHooks()
    if NXFarmKitPFBridge.hooksInstalled then
        return true
    end

    local pfNamespace = getPFNamespace()
    local pfClass, pfClassSource = getPFClass()

    NXFarmKitPFBridge.pfNamespace = pfNamespace
    NXFarmKitPFBridge.pfClass = pfClass

    if type(NXFarmKitPFBridge.pfClass) ~= "table" then
        if isPrecisionFarmingLoaded() and not NXFarmKitPFBridge.loggedWaiting then
            bridgeWarning("PrecisionFarming class not visible yet; waiting")
            NXFarmKitPFBridge.loggedWaiting = true
        end
        return false
    end

    if not NXFarmKitPFBridge.loadMapHookInstalled and type(NXFarmKitPFBridge.pfClass.loadMap) == "function" then
        NXFarmKitPFBridge.pfClass.loadMap = Utils.overwrittenFunction(
            NXFarmKitPFBridge.pfClass.loadMap,
            NXFarmKitPFBridge.pfLoadMapHook
        )
        NXFarmKitPFBridge.loadMapHookInstalled = true
    end

    if not NXFarmKitPFBridge.initTerrainHookInstalled and type(NXFarmKitPFBridge.pfClass.initTerrain) == "function" then
        NXFarmKitPFBridge.pfClass.initTerrain = Utils.overwrittenFunction(
            NXFarmKitPFBridge.pfClass.initTerrain,
            NXFarmKitPFBridge.pfInitTerrainHook
        )
        NXFarmKitPFBridge.initTerrainHookInstalled = true
    end

    NXFarmKitPFBridge.hooksInstalled = NXFarmKitPFBridge.loadMapHookInstalled
        and NXFarmKitPFBridge.initTerrainHookInstalled

    if NXFarmKitPFBridge.hooksInstalled then
        bridgeInfo("installed hooks on PrecisionFarming.loadMap/initTerrain (source=%s)", tostring(pfClassSource))
    else
        bridgeWarning(
            "partial hook install (loadMap=%s initTerrain=%s)",
            tostring(NXFarmKitPFBridge.loadMapHookInstalled),
            tostring(NXFarmKitPFBridge.initTerrainHookInstalled)
        )
    end

    return NXFarmKitPFBridge.hooksInstalled
end

function NXFarmKitPFBridge.getProvider()
    if NXFarmKitPFBridge.runtimeReady then
        return NXFarmKitPFBridge
    end

    return nil
end

function NXFarmKitPFBridge:getInstance()
    return self.pfInstance
end

function NXFarmKitPFBridge:getSoilMap()
    return self.soilMap
end

function NXFarmKitPFBridge:getPHMap()
    return self.pHMap
end

function NXFarmKitPFBridge:getNitrogenMap()
    return self.nitrogenMap
end

function NXFarmKitPFBridge:getCoverMap()
    return self.coverMap
end

function NXFarmKitPFBridge:loadMap(filename)
    self:installHooks()
    self:captureFromNamespace("bridgeLoadMap")
end

function NXFarmKitPFBridge:update(dt)
    if not self.hooksInstalled then
        self:installHooks()
    end

    if self.runtimeReady then
        return
    end

    self:captureFromNamespace("bridgeUpdate")
end

function NXFarmKitPFBridge:deleteMap()
    self.runtimeReady = false
    self.pfInstance = nil
    self.soilMap = nil
    self.pHMap = nil
    self.nitrogenMap = nil
    self.coverMap = nil
    self.loggedWaiting = false
end

NXFarmKitPFBridge:installHooks()
NXFarmKitPFBridge:captureFromNamespace("bridgeBootstrap")
addModEventListener(NXFarmKitPFBridge)
