FarmKitDlgFrame = {}
local DlgFrame_mt = Class(FarmKitDlgFrame, MessageDialog)

local MATERIAL_KEYS = { "lime", "fertilizer", "liquidFertilizer", "herbicide", "manure", "slurry", "digestate" }
local MATERIAL_FILL_TYPE_L10N = {
    lime             = "fillType_lime",
    fertilizer       = "fillType_fertilizer",
    liquidFertilizer = "fillType_liquidFertilizer",
    herbicide        = "fillType_herbicide",
    manure           = "fillType_manure",
    slurry           = "fillType_liquidManure",
    digestate        = "fillType_digestate"
}

function FarmKitDlgFrame.new(target, i18n)
    local self = MessageDialog.new(target, DlgFrame_mt)

    self.i18n = i18n or g_i18n

    self.sectionData = {}
    self.currentField = nil
    self.organicNitrogenMode = "soil"
    self.customMaterialKey = nil
    self.customMaterialFillTypeName = nil
    self.customMaterialTitle = ""
    self.isCustomMaterialVisible = false

    return self
end

function FarmKitDlgFrame:getText(key, fallback)
    if key ~= nil and self.i18n ~= nil and self.i18n.hasText ~= nil and self.i18n:hasText(key) then
        return self.i18n:getText(key)
    end
    return tostring(fallback or key or "")
end

function FarmKitDlgFrame:getBracketUnitText(key, fallback)
    return string.format("[%s]", self:getText(key, fallback))
end

function FarmKitDlgFrame:buildHeaderText(labelText, unitText)
    local label = tostring(labelText or "")
    local unit  = tostring(unitText or "")
    if label == "" then return unit end
    if unit  == "" then return label end
    return string.format("%s %s", label, unit)
end

function FarmKitDlgFrame:getMaterialHeaderText(materialKey)
    local shortKey = "nx_header_" .. materialKey
    local labelText
    if self.i18n ~= nil and self.i18n.hasText ~= nil and self.i18n:hasText(shortKey) then
        labelText = self.i18n:getText(shortKey)
    else
        labelText = self:getText(MATERIAL_FILL_TYPE_L10N[materialKey], materialKey)
    end
    return self:buildHeaderText(labelText, self:getBracketUnitText("unit_literShort", "l"))
end

function FarmKitDlgFrame:updateHeaderTexts()
    if self.fieldHeader            ~= nil then self.fieldHeader:setText(self:getText("nx_header_field", "Field Num")) end
    if self.sizeHeader             ~= nil then self.sizeHeader:setText(self:buildHeaderText(self:getText("ui_fieldArea", "Area"), self:getBracketUnitText("unit_haShort", "ha"))) end
    if self.limeHeader             ~= nil then self.limeHeader:setText(self:getMaterialHeaderText("lime")) end
    if self.fertilizerHeader       ~= nil then self.fertilizerHeader:setText(self:getMaterialHeaderText("fertilizer")) end
    if self.liquidFertilizerHeader ~= nil then self.liquidFertilizerHeader:setText(self:getMaterialHeaderText("liquidFertilizer")) end
    if self.herbicideHeader        ~= nil then self.herbicideHeader:setText(self:getMaterialHeaderText("herbicide")) end
    if self.manureHeader           ~= nil then self.manureHeader:setText(self:getMaterialHeaderText("manure")) end
    if self.slurryHeader           ~= nil then self.slurryHeader:setText(self:getMaterialHeaderText("slurry")) end
    if self.digestateHeader        ~= nil then self.digestateHeader:setText(self:getMaterialHeaderText("digestate")) end
end

function FarmKitDlgFrame:onGuiSetupFinished()
    FarmKitDlgFrame:superClass().onGuiSetupFinished(self)

    if self.farmKitTable ~= nil then
        if self.farmKitTable.setDataSource ~= nil then self.farmKitTable:setDataSource(self) end
        if self.farmKitTable.setDelegate   ~= nil then self.farmKitTable:setDelegate(self)   end
    end

    self:updateHeaderTexts()
end

function FarmKitDlgFrame:onCreate()
    FarmKitDlgFrame:superClass().onCreate(self)
end

function FarmKitDlgFrame:onOpen()
    FarmKitDlgFrame:superClass().onOpen(self)

    self.currentField = nil

    self:applyOrganicNitrogenButtonVisibility()

    if FarmKit ~= nil and FarmKit.getOrganicNitrogenMode ~= nil then
        self:setOrganicNitrogenMode(FarmKit:getOrganicNitrogenMode())
    end

    if self.seedToggleButton ~= nil then
        self.seedToggleButton:setInputAction(InputAction.MENU_EXTRA_1)
        self.seedToggleButton:setText(self:getText("ui_seed_btn", "Show seed data"))
        self.seedToggleButton:setDisabled(true)
    end

    if self.organicNitrogenButton ~= nil then
        self.organicNitrogenButton:setInputAction(InputAction.MENU_EXTRA_2)
    end

    self:requestData()

    self:setSoundSuppressed(true)
    if self.farmKitTable ~= nil then
        FocusManager:setFocus(self.farmKitTable)
    end
    self:setSoundSuppressed(false)
end

function FarmKitDlgFrame:onClose()
    FarmKitDlgFrame:superClass().onClose(self)
end

function FarmKitDlgFrame:onClickOk()
    return false
end

function FarmKitDlgFrame:inputEvent(action, value, eventUsed)
    if eventUsed or value == 0 then
        return eventUsed
    end

    if action == InputAction.MENU_EXTRA_1 then
        self:onClickToggleSeed()
        return true
    elseif action == InputAction.MENU_EXTRA_2 then
        if self.organicNitrogenButton ~= nil and self.organicNitrogenButton:getVisible() then
            self:onClickOrganicNitrogenMode()
            return true
        end
    end

    return FarmKitDlgFrame:superClass().inputEvent(self, action, value, eventUsed)
end

function FarmKitDlgFrame:requestData()
    self:prepareForFieldDataRequest()

    if FarmKit ~= nil and FarmKit.requestFieldEntriesForDialog ~= nil then
        FarmKit:requestFieldEntriesForDialog()
        return
    end

    if NXFarmKitShared ~= nil and NXFarmKitShared.collectFieldEntries ~= nil then
        self:setFieldEntries(NXFarmKitShared.collectFieldEntries())
    end
end

function FarmKitDlgFrame:prepareForFieldDataRequest()
    self:applyOrganicNitrogenButtonVisibility()

    if self.seedToggleButton ~= nil then
        self.seedToggleButton:setDisabled(self.currentField == nil)
    end
end

function FarmKitDlgFrame:setFieldEntries(entries, organicNitrogenMode)
    self.sectionData = {}
    self.currentField = nil

    if organicNitrogenMode ~= nil then
        self:setOrganicNitrogenMode(organicNitrogenMode)
    end

    self:resolveCustomMaterialDisplayFromEntries(entries or {})

    if NXFarmKitShared ~= nil and NXFarmKitShared.buildSections ~= nil then
        self.sectionData = NXFarmKitShared.buildSections(entries or {})
    end

    if self.seedToggleButton ~= nil then
        self.seedToggleButton:setDisabled(true)
    end

    if self.farmKitTable ~= nil and self.farmKitTable.reloadData ~= nil then
        self.farmKitTable:reloadData()
    end
end

function FarmKitDlgFrame:onClickToggleSeed()
    if self.currentField == nil or g_gui == nil then return end

    local seedDialogName = (FarmKit and FarmKit.GUI and FarmKit.GUI.SEED_NAME) or "NXSeedDlgFrame"
    local dialog = g_gui.guis ~= nil and g_gui.guis[seedDialogName] or nil
    if dialog == nil or dialog.target == nil or dialog.target.setFieldData == nil then return end

    dialog.target:setFieldData(self.currentField)
    g_gui:showDialog(seedDialogName)
end

function FarmKitDlgFrame:getIsPrecisionFarmingActive()
    return NXFarmKitShared ~= nil
        and NXFarmKitShared.getIsPrecisionFarmingActive ~= nil
        and NXFarmKitShared.getIsPrecisionFarmingActive() == true
end

function FarmKitDlgFrame:applyOrganicNitrogenButtonVisibility()
    if self.organicNitrogenButton == nil then return end
    local visible = self:getIsPrecisionFarmingActive()
    self.organicNitrogenButton:setVisible(visible)
    if visible then
        self:updateOrganicNitrogenButtonText()
    end
end

function FarmKitDlgFrame:getOrganicNitrogenModeText(mode)
    if tostring(mode or "soil") == "plant" then
        return self:getText("ui_organicNitrogenMode_plant", "Plant target")
    end
    return self:getText("ui_organicNitrogenMode_soil", "Soil value")
end

function FarmKitDlgFrame:updateOrganicNitrogenButtonText()
    if self.organicNitrogenButton == nil then return end
    local prefix = self:getText("ui_organicNitrogenMode_label", "Organic N mode")
    self.organicNitrogenButton:setText(string.format("%s: %s", prefix, self:getOrganicNitrogenModeText(self.organicNitrogenMode)))
end

function FarmKitDlgFrame:setOrganicNitrogenMode(mode)
    self.organicNitrogenMode = tostring(mode or "soil")
    self:updateOrganicNitrogenButtonText()
end

function FarmKitDlgFrame:onClickOrganicNitrogenMode()
    local nextMode = tostring(self.organicNitrogenMode or "soil") == "soil" and "plant" or "soil"
    self:setOrganicNitrogenMode(nextMode)

    if FarmKit ~= nil and FarmKit.requestOrganicNitrogenModeChange ~= nil then
        FarmKit:requestOrganicNitrogenModeChange(nextMode)
    end
end

function FarmKitDlgFrame:getCustomMaterialDefinitionByKey(materialKey)
    if materialKey == nil or NXFarmKitShared == nil or NXFarmKitShared.getCustomMapFertilizerDefinitions == nil then
        return nil
    end

    for _, definition in ipairs(NXFarmKitShared.getCustomMapFertilizerDefinitions()) do
        if definition ~= nil and definition.key == materialKey then return definition end
    end

    return nil
end

function FarmKitDlgFrame:getFillTypeTitleByName(fillTypeName)
    local safe = tostring(fillTypeName or "")
    if safe == "" then return "" end

    if g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeByName ~= nil then
        local fillType = g_fillTypeManager:getFillTypeByName(safe)
        if fillType ~= nil and fillType.title ~= nil and fillType.title ~= "" then
            return fillType.title
        end
    end

    return self:getText("fillType_" .. safe, safe)
end

function FarmKitDlgFrame:resolveCustomMaterialDisplayFromEntries(entries)
    self.customMaterialKey = nil
    self.customMaterialFillTypeName = nil
    self.customMaterialTitle = ""
    self.isCustomMaterialVisible = false

    for _, entry in ipairs(entries or {}) do
        if type(entry) == "table" and type(entry.customMaterials) == "table" then
            local materialKeys = {}
            for k, m in pairs(entry.customMaterials) do
                if m ~= nil then materialKeys[#materialKeys + 1] = k end
            end
            table.sort(materialKeys, function(a, b) return tostring(a) < tostring(b) end)

            for _, materialKey in ipairs(materialKeys) do
                local material = entry.customMaterials[materialKey]
                if material ~= nil then
                    local fillTypeName = tostring(material.fillTypeName or "")
                    if fillTypeName == "" then
                        local definition = self:getCustomMaterialDefinitionByKey(materialKey)
                        if definition ~= nil then fillTypeName = tostring(definition.sprayType or "") end
                    end

                    self.customMaterialKey = materialKey
                    self.customMaterialFillTypeName = fillTypeName
                    self.customMaterialTitle = self:getFillTypeTitleByName(fillTypeName)
                    self.isCustomMaterialVisible = self.customMaterialTitle ~= ""
                    self:updateCustomMaterialHeader()
                    return
                end
            end
        end
    end

    self:updateCustomMaterialHeader()
end

function FarmKitDlgFrame:updateCustomMaterialHeader()
    if self.customMaterialHeader == nil then return end
    self.customMaterialHeader:setVisible(self.isCustomMaterialVisible == true)
    self.customMaterialHeader:setText(self:buildHeaderText(self.customMaterialTitle or "", self:getBracketUnitText("unit_literShort", "l")))
end

function FarmKitDlgFrame:getNumberOfSections()
    return #self.sectionData
end

function FarmKitDlgFrame:getNumberOfItemsInSection(list, section)
    local sectionData = self.sectionData[section]
    if sectionData == nil or sectionData.fields == nil then return 0 end
    return #sectionData.fields
end

function FarmKitDlgFrame:getTitleForSectionHeader(list, section)
    local sectionData = self.sectionData[section]
    return (sectionData ~= nil and sectionData.title) or ""
end

function FarmKitDlgFrame:populateCellForItemInSection(list, section, index, cell)
    local function setText(name, value)
        local element = cell:getAttribute(name)
        if element ~= nil then element:setText(value) end
    end

    local sectionData = self.sectionData[section]
    if sectionData == nil or sectionData.fields == nil then return end

    local entry = sectionData.fields[index]
    if entry == nil then return end

    setText("field", tostring(entry.fieldId or ""))
    setText("size",  g_i18n:formatNumber(entry.areaHa or 0, 2))

    local materials = entry.materials or {}
    for _, key in ipairs(MATERIAL_KEYS) do
        local material = materials[key] or {}
        setText(key, g_i18n:formatNumber(math.floor((material.totalLiters or 0) + 0.5), 0))
    end

    local customMaterialElement = cell:getAttribute("customMaterial")
    if customMaterialElement ~= nil then
        customMaterialElement:setVisible(self.isCustomMaterialVisible == true)
    end

    if self.isCustomMaterialVisible == true and self.customMaterialKey ~= nil and type(entry.customMaterials) == "table" then
        local customMaterial = entry.customMaterials[self.customMaterialKey]
        local totalLiters = customMaterial ~= nil and tonumber(customMaterial.totalLiters) or 0
        setText("customMaterial", g_i18n:formatNumber(math.floor(totalLiters + 0.5), 0))
    else
        setText("customMaterial", "")
    end
end

function FarmKitDlgFrame:onListSelectionChanged(list, section, index)
    local sectionData = self.sectionData[section]
    local entry = nil
    if sectionData ~= nil and sectionData.fields ~= nil then
        entry = sectionData.fields[index]
    end

    self.currentField = entry

    if self.seedToggleButton ~= nil then
        self.seedToggleButton:setDisabled(entry == nil)
    end

    if entry ~= nil then
        self:playSample(GuiSoundPlayer.SOUND_SAMPLES.HOVER)
    end
end

function FarmKitDlgFrame:onClickBack()
    self:close()
end
