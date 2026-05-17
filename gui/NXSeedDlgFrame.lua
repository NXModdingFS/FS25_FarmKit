NXSeedDlgFrame = {}
local DlgFrame_mt = Class(NXSeedDlgFrame, MessageDialog)

function NXSeedDlgFrame.new(target, i18n)
    local self = MessageDialog.new(target, DlgFrame_mt)
    self.i18n = i18n or g_i18n
    self.fieldData = nil
    self.seedEntries = {}
    return self
end

function NXSeedDlgFrame:copyAttributes(src)
    NXSeedDlgFrame:superClass().copyAttributes(self, src)
    self.i18n = src.i18n or g_i18n
    self.fieldData = nil
    self.seedEntries = {}
end

function NXSeedDlgFrame:getText(key, fallback)
    if key ~= nil and self.i18n ~= nil and self.i18n.hasText ~= nil and self.i18n:hasText(key) then
        return self.i18n:getText(key)
    end
    return tostring(fallback or key or "")
end

function NXSeedDlgFrame:getBracketUnitText(key, fallback)
    return string.format("[%s]", self:getText(key, fallback))
end

function NXSeedDlgFrame:buildHeaderText(labelText, unitText)
    local label = tostring(labelText or "")
    local unit  = tostring(unitText or "")
    if label == "" then return unit end
    if unit  == "" then return label end
    return string.format("%s %s", label, unit)
end

function NXSeedDlgFrame:updateStaticTexts()
    if self.seedHeaderFruit ~= nil then
        self.seedHeaderFruit:setText(self:getText("ui_seed_header_fruit", "Crop"))
    end
    if self.seedHeaderConsume ~= nil then
        self.seedHeaderConsume:setText(self:buildHeaderText(
            self:getText("ui_seed_header_consume", "Requirement"),
            self:getBracketUnitText("unit_literShort", "l")
        ))
    end
    if self.closeButton ~= nil then
        self.closeButton:setText(self:getText("button_close", "Close"))
    end
end

function NXSeedDlgFrame:onGuiSetupFinished()
    NXSeedDlgFrame:superClass().onGuiSetupFinished(self)

    if self.nxSeedTable ~= nil then
        if self.nxSeedTable.setDataSource ~= nil then
            self.nxSeedTable:setDataSource(self)
        end
        if self.nxSeedTable.setDelegate ~= nil then
            self.nxSeedTable:setDelegate(self)
        end
    end

    self:updateStaticTexts()
end

function NXSeedDlgFrame:onOpen()
    NXSeedDlgFrame:superClass().onOpen(self)

    if self.nxSeedTable ~= nil then
        FocusManager:setFocus(self.nxSeedTable)
    end
end

function NXSeedDlgFrame:onClickBack()
    self:close()
end

function NXSeedDlgFrame:setFieldData(fieldData)
    self.fieldData = fieldData
    self.seedEntries = {}

    local fieldId = "-"
    local areaHa = 0

    if type(fieldData) == "table" then
        fieldId = tostring(fieldData.fieldId or "-")
        areaHa = tonumber(fieldData.areaHa) or tonumber(fieldData.fieldArea) or 0
    else
        areaHa = tonumber(fieldData) or 0
    end

    if self.dialogTitleElement ~= nil then
        local headerText = string.format(
            self:getText("ui_seedFrame_header", "Seed requirement for field %s (%s %s)"),
            fieldId,
            self.i18n:formatNumber(areaHa, 2),
            self:getText("unit_haShort", "ha")
        )
        self.dialogTitleElement:setText(headerText)
    end

    if NXFarmKitShared ~= nil and NXFarmKitShared.collectSeedEntries ~= nil then
        local seedSource = type(fieldData) == "table" and fieldData or areaHa
        self.seedEntries = NXFarmKitShared.collectSeedEntries(seedSource)
    end

    if self.nxSeedTable ~= nil and self.nxSeedTable.reloadData ~= nil then
        self.nxSeedTable:reloadData()
    end
end

function NXSeedDlgFrame:getNumberOfSections()
    if #self.seedEntries > 0 then return 1 end
    return 0
end

function NXSeedDlgFrame:getNumberOfItemsInSection(list, section)
    if section ~= 1 then return 0 end
    return #self.seedEntries
end

function NXSeedDlgFrame:populateCellForItemInSection(list, section, index, cell)
    local entry = self.seedEntries[index]
    if entry == nil then return end

    local fruit = cell:getAttribute("fruit")
    if fruit ~= nil then fruit:setText(tostring(entry.title or "")) end

    local consume = cell:getAttribute("consume")
    if consume ~= nil then
        consume:setText(self.i18n:formatNumber(math.floor((entry.totalLiters or 0) + 0.5), 0))
    end
end
