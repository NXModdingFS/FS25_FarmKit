NXFarmKitSettings = NXFarmKitSettings or {}
NXFarmKitSettings.SETTINGS_FILE = "modSettings/FS25_FarmKit_Settings.xml"

NXFarmKitSettings.values = {
    mudSprayerEnabled   = true,
    densityEnabled      = true,
    dustEnabled         = true,
    dustMultiplier      = 2.0,
    plowingEnabled      = true,
    wheelPhysicsEnabled = true,
    hudEnabled          = true
}

NXFarmKitSettings.SETTINGS_ORDER = {
    "mudSprayerEnabled",
    "densityEnabled",
    "dustEnabled",
    "dustMultiplier",
    "plowingEnabled",
    "wheelPhysicsEnabled",
    "hudEnabled"
}

NXFarmKitSettings.SETTINGS       = nil
NXFarmKitSettings.menuInstalled  = false
NXFarmKitSettings.controls       = {}
NXFarmKitSettings.isChanging     = false

local function nxAssignFocusIds(elem)
    if elem == nil then return end
    elem.focusId = FocusManager:serveAutoFocusId()
    for _, c in pairs(elem.elements or {}) do nxAssignFocusIds(c) end
end

local function nxClosestIndex(list, target)
    local best, bestDiff = 1, math.huge
    for i, v in ipairs(list) do
        local d = math.abs(v - target)
        if d < bestDiff then bestDiff, best = d, i end
    end
    return best
end

local function nxBuildMultiplierList()
    local values, strings = {}, {}
    for percent = 50, 500, 10 do
        values[#values + 1]  = percent / 100
        strings[#strings + 1] = string.format("%d%%", percent)
    end
    return values, strings
end

local function nxOnOffStrings()
    return { g_i18n:getText("nx_setting_on"), g_i18n:getText("nx_setting_off") }
end

local function nxEnsureSettings()
    if NXFarmKitSettings.SETTINGS ~= nil then return end
    local multValues, multStrings = nxBuildMultiplierList()

    NXFarmKitSettings.SETTINGS = {
        mudSprayerEnabled   = { default = 1, values = { true, false }, strings = nxOnOffStrings() },
        densityEnabled      = { default = 1, values = { true, false }, strings = nxOnOffStrings() },
        dustEnabled         = { default = 1, values = { true, false }, strings = nxOnOffStrings() },
        dustMultiplier      = { default = nxClosestIndex(multValues, 2.0), values = multValues, strings = multStrings },
        plowingEnabled      = { default = 1, values = { true, false }, strings = nxOnOffStrings() },
        wheelPhysicsEnabled = { default = 1, values = { true, false }, strings = nxOnOffStrings() },
        hudEnabled          = { default = 1, values = { true, false }, strings = nxOnOffStrings() }
    }
end

function NXFarmKitSettings.applyToSubsystems()
    local v = NXFarmKitSettings.values

    if rawget(_G, "NXFieldPhysics") ~= nil then
        NXFieldPhysics.mudSprayerEnabled = v.mudSprayerEnabled == true
    end
    if rawget(_G, "NXFieldPhysicsDensity") ~= nil then
        NXFieldPhysicsDensity:setEnabled(v.densityEnabled == true)
    end

    if rawget(_G, "NXDustMechanics") ~= nil then
        NXDustMechanics.dustEnabled    = v.dustEnabled == true
        NXDustMechanics.dustMultiplier = v.dustMultiplier or 2.0
    end

    if rawget(_G, "NXRealisticPlowing") ~= nil then
        NXRealisticPlowing.enabled = v.plowingEnabled == true
    end

    if rawget(_G, "NXRealisticWheelPhysics") ~= nil then
        NXRealisticWheelPhysics.enabled = v.wheelPhysicsEnabled == true
    end

    if rawget(_G, "NXFarmKitHUD") ~= nil then
        NXFarmKitHUD.enabled = v.hudEnabled == true
    end
end

function NXFarmKitSettings.getValue(id)
    return NXFarmKitSettings.values[id]
end

function NXFarmKitSettings.setValue(id, value)
    NXFarmKitSettings.values[id] = value
    NXFarmKitSettings.applyToSubsystems()
end

function NXFarmKitSettings.getStateIndex(id)
    nxEnsureSettings()
    local s = NXFarmKitSettings.SETTINGS[id]
    if s == nil then return 1 end
    local v = NXFarmKitSettings.values[id]
    if v == nil then return s.default end
    if type(v) == "boolean" then return v and 1 or 2 end
    return nxClosestIndex(s.values, v)
end

local function nxXmlPath()
    return Utils.getFilename(NXFarmKitSettings.SETTINGS_FILE, getUserProfileAppPath())
end

function NXFarmKitSettings.load()
    nxEnsureSettings()
    local path = nxXmlPath()
    if not fileExists(path) then
        NXFarmKitSettings.applyToSubsystems()
        return
    end

    local xml = loadXMLFile("NXFarmKitSettingsXML", path)
    if xml == 0 then return end

    local function readBool(key)
        local v = getXMLBool(xml, "nx.settings#" .. key)
        if v ~= nil then NXFarmKitSettings.values[key] = v end
    end
    local function readFloat(key)
        local v = getXMLFloat(xml, "nx.settings#" .. key)
        if v ~= nil then NXFarmKitSettings.values[key] = v end
    end

    readBool("mudSprayerEnabled")
    readBool("densityEnabled")
    readBool("dustEnabled")
    readFloat("dustMultiplier")
    readBool("plowingEnabled")
    readBool("wheelPhysicsEnabled")
    readBool("hudEnabled")

    delete(xml)
    NXFarmKitSettings.applyToSubsystems()
end

function NXFarmKitSettings.save()
    createFolder(getUserProfileAppPath() .. "modSettings/")
    local path = nxXmlPath()

    local xml = fileExists(path)
        and loadXMLFile("NXFarmKitSettingsXML", path)
        or  createXMLFile("NXFarmKitSettingsXML", path, "nx")
    if xml == 0 then return end

    local v = NXFarmKitSettings.values
    setXMLBool(xml,  "nx.settings#mudSprayerEnabled",   v.mudSprayerEnabled   == true)
    setXMLBool(xml,  "nx.settings#densityEnabled",      v.densityEnabled      == true)
    setXMLBool(xml,  "nx.settings#dustEnabled",         v.dustEnabled         == true)
    setXMLFloat(xml, "nx.settings#dustMultiplier",      v.dustMultiplier or 2.0)
    setXMLBool(xml,  "nx.settings#plowingEnabled",      v.plowingEnabled      == true)
    setXMLBool(xml,  "nx.settings#wheelPhysicsEnabled", v.wheelPhysicsEnabled == true)
    setXMLBool(xml,  "nx.settings#hudEnabled",          v.hudEnabled          == true)

    saveXMLFile(xml)
    delete(xml)
end

NXFarmKitSettingsEvent = NXFarmKitSettingsEvent or {}
if not NXFarmKitSettingsEvent._init then
    NXFarmKitSettingsEvent._init = true
    local mt = Class(NXFarmKitSettingsEvent, Event)
    InitEventClass(NXFarmKitSettingsEvent, "NXFarmKitSettingsEvent")
    NXFarmKitSettingsEvent.classMt = mt
end

function NXFarmKitSettingsEvent.emptyNew()
    return Event.new(NXFarmKitSettingsEvent.classMt)
end

function NXFarmKitSettingsEvent.new(values)
    local self = NXFarmKitSettingsEvent.emptyNew()
    self.values = values or {}
    return self
end

function NXFarmKitSettingsEvent:readStream(streamId, connection)
    self.values = {
        mudSprayerEnabled   = streamReadBool(streamId),
        densityEnabled      = streamReadBool(streamId),
        dustEnabled         = streamReadBool(streamId),
        dustMultiplier      = streamReadFloat32(streamId),
        plowingEnabled      = streamReadBool(streamId),
        wheelPhysicsEnabled = streamReadBool(streamId),
        hudEnabled          = streamReadBool(streamId)
    }
    self:run(connection)
end

function NXFarmKitSettingsEvent:writeStream(streamId, connection)
    local v = self.values
    streamWriteBool(streamId,    v.mudSprayerEnabled   == true)
    streamWriteBool(streamId,    v.densityEnabled      == true)
    streamWriteBool(streamId,    v.dustEnabled         == true)
    streamWriteFloat32(streamId, v.dustMultiplier or 2.0)
    streamWriteBool(streamId,    v.plowingEnabled      == true)
    streamWriteBool(streamId,    v.wheelPhysicsEnabled == true)
    streamWriteBool(streamId,    v.hudEnabled          == true)
end

function NXFarmKitSettingsEvent:run(connection)
    if not connection:getIsServer() and NXFarmKitSettings.isChanging then
        NXFarmKitSettings.isChanging = false
        return
    end

    for k, val in pairs(self.values) do
        NXFarmKitSettings.values[k] = val
    end
    NXFarmKitSettings.applyToSubsystems()
    NXFarmKitSettings.refreshUI()

    if not connection:getIsServer() then
        NXFarmKitSettings.broadcastFromServer()
    end
end

function NXFarmKitSettings.broadcastFromServer()
    if g_server ~= nil then
        g_server:broadcastEvent(NXFarmKitSettingsEvent.new(NXFarmKitSettings.values))
    end
end

function NXFarmKitSettings.sendToServer()
    if g_client ~= nil and not g_currentMission:getIsServer() then
        g_client:getServerConnection():sendEvent(NXFarmKitSettingsEvent.new(NXFarmKitSettings.values))
    end
end

NXFarmKitSettingsControls = NXFarmKitSettingsControls or {}

function NXFarmKitSettingsControls:onMenuOptionChanged(state, menuOption)
    local id = menuOption.id
    local s = NXFarmKitSettings.SETTINGS[id]
    if s == nil then return end

    NXFarmKitSettings.values[id] = s.values[state]
    NXFarmKitSettings.applyToSubsystems()

    NXFarmKitSettings.isChanging = true
    NXFarmKitSettings.save()

    if g_currentMission:getIsServer() then
        NXFarmKitSettings.broadcastFromServer()
    else
        NXFarmKitSettings.sendToServer()
    end
end

function NXFarmKitSettings.refreshUI()
    local menu = g_gui and g_gui.screenControllers and g_gui.screenControllers[InGameMenu]
    if menu == nil or not menu.isOpen then return end

    for _, control in pairs(NXFarmKitSettings.controls or {}) do
        if control.id ~= nil and NXFarmKitSettings.SETTINGS[control.id] ~= nil then
            control:setState(NXFarmKitSettings.getStateIndex(control.id))
        end
    end
end

function NXFarmKitSettings.injectMenu()
    if NXFarmKitSettings.menuInstalled then return end
    nxEnsureSettings()

    local ui = g_gui and g_gui.screenControllers and g_gui.screenControllers[InGameMenu]
    local settingsPage = ui and ui.pageSettings
    local layout = settingsPage and settingsPage.generalSettingsLayout
    if layout == nil then return end

    local boolTemplate = settingsPage.checkWoodHarvesterAutoCutBox
        or settingsPage.checkWoodHarvesterWoodDestroyBox
        or settingsPage.showFieldInfoBox
    local multiTemplate = settingsPage.multiVolumeVoiceBox
        or settingsPage.soundVolumeEnvironmentBox

    if boolTemplate == nil or multiTemplate == nil then return end

    local header
    for _, e in ipairs(layout.elements) do
        if e.name == "sectionHeader" and e.clone ~= nil then
            header = e:clone(layout)
            break
        end
    end
    if header ~= nil then
        header:setText(g_i18n:getText("nx_menu_section_title"))
        nxAssignFocusIds(header)
        table.insert(settingsPage.controlsList, header)
        NXFarmKitSettings.controls.sectionHeader = header
    end

    for _, id in ipairs(NXFarmKitSettings.SETTINGS_ORDER) do
        local s = NXFarmKitSettings.SETTINGS[id]
        local isBoolean = #s.values == 2 and type(s.values[1]) == "boolean"
        local template = isBoolean and boolTemplate or multiTemplate

        local box = template:clone(layout)
        box.id = id .. "Box"

        local opt = box.elements[1]
        opt.id = id
        opt.target = NXFarmKitSettingsControls
        opt:setCallback("onClickCallback", "onMenuOptionChanged")
        opt:setDisabled(false)
        opt:setTexts({ unpack(s.strings) })
        opt:setState(NXFarmKitSettings.getStateIndex(id))

        local tip = opt.elements[1]
        if tip ~= nil then tip:setText(g_i18n:getText("nx_menu_" .. id .. "_tooltip")) end
        local label = box.elements[2]
        if label ~= nil then label:setText(g_i18n:getText("nx_menu_" .. id)) end

        nxAssignFocusIds(box)
        table.insert(settingsPage.controlsList, box)
        NXFarmKitSettings.controls[id] = opt
    end

    layout:invalidateLayout()

    if InGameMenuSettingsFrame ~= nil and InGameMenuSettingsFrame.onFrameOpen ~= nil then
        InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
            local canEdit = g_currentMission == nil
                or g_currentMission:getIsServer()
                or g_currentMission.isMasterUser
            for _, id in ipairs(NXFarmKitSettings.SETTINGS_ORDER) do
                local c = NXFarmKitSettings.controls[id]
                if c ~= nil then
                    c:setState(NXFarmKitSettings.getStateIndex(id))
                    c:setDisabled(not canEdit)
                end
            end
        end)
    end

    NXFarmKitSettings.menuInstalled = true
end

Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function()
    NXFarmKitSettings.load()
    NXFarmKitSettings.injectMenu()
end)
