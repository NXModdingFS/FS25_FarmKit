nxGui = {};

local nxGui_mt = Class(nxGui, MessageDialog);

function nxGui:new(target, custom_mt)
    local self = MessageDialog.new(target, custom_mt or nxGui_mt);
    self.returnScreenName = "";
    return self;	
end;

function nxGui:onGuiSetupFinished()
	nxGui:superClass().onGuiSetupFinished(self)
end
function nxGui:onCreate()
	--nxGui:superClass().onCreate(self)
end

function nxGui:onOpen()
    nxGui:superClass().onOpen(self);
	FocusManager:setFocus(self.backButton);
end;

function nxGui:onClose()
    nxGui:superClass().onClose(self);
end;

function nxGui:onClickBack()
    nxGui:superClass().onClickBack(self)
	self:onClose();
	--FarmKitChainHook:guiClosed()
end;

function nxGui:onClickOk()
    nxGui:superClass().onClickOk(self)
	FarmKitChainHook:settingsFromGui(self.manualAttach:getState(), self.showHelp:getState(), self.showIds:getState(), self.IdsDistanceView:getState(), self.chainDistanceView:getState(), self.steeringMode:getState(), self.autoOffVehicle:getState());
    self:onClickBack()
end;

function nxGui:onIngameMenuHelpTextChanged(element)
end;

function nxGui:onCreateNxGuiHeader(element)
	element:setTextInternal(g_i18n:getText('gui_nx_Setting'), false, true)
end;

function nxGui:onCreateManualAttach(element)
    self.manualAttach = element
	--element.labelElement.text = g_i18n:getText('gui_nx_manualAttach');
	--element.toolTipText = g_i18n:getText('gui_nx_manualAttachToolTip');
    local values = {}
    for i = 1, #FarmKitChainHook.booleansTexts, 1 do
        values[i] = FarmKitChainHook.booleansTexts[i]
    end
    element:setTexts(values)
end
function nxGui:setManualAttach(index)
    self.manualAttach:setState(index, false)
end

function nxGui:onCreateShowHelp(element)
    self.showHelp = element
	--element.labelElement.text = g_i18n:getText('gui_nx_showHelp');
	--element.toolTipText = g_i18n:getText('gui_nx_showHelpToolTip');
    local values = {}
    for i = 1, #FarmKitChainHook.booleansTexts, 1 do
        values[i] = FarmKitChainHook.booleansTexts[i]
    end
    element:setTexts(values)
end
function nxGui:setShowHelp(index)
    self.showHelp:setState(index, false)
end

function nxGui:onCreateShowIds(element)
    self.showIds = element
	--element.labelElement.text = g_i18n:getText('gui_nx_showIds');
	--element.toolTipText = g_i18n:getText('gui_nx_showIdsToolTip');
    local values = {}
    for i = 1, #FarmKitChainHook.booleansTexts, 1 do
        values[i] = FarmKitChainHook.booleansTexts[i]
    end	
	element:setTexts(values)
end
function nxGui:setShowIds(index)
    self.showIds:setState(index, false)
end

function nxGui:onCreateIdsDistanceView(element)
    self.IdsDistanceView = element
	--element.labelElement.text = g_i18n:getText('gui_nx_IdsDistanceView');
	--element.toolTipText = g_i18n:getText('gui_nx_IdsDistanceViewToolTip');
    local values = {}
    for i = 1, #FarmKitChainHook.IdsDistanceViewsTexts, 1 do
        values[i] = FarmKitChainHook.IdsDistanceViewsTexts[i]
    end
    element:setTexts(values)
end;
function nxGui:setIdsDistanceView(index)
    self.IdsDistanceView:setState(index, false)
end;

function nxGui:onCreateChainDistanceView(element)
    self.chainDistanceView = element
	--element.labelElement.text = g_i18n:getText('gui_nx_chainDistanceView');
	--element.toolTipText = g_i18n:getText('gui_nx_chainDistanceViewToolTip');
    local values = {}
    for i = 1, #FarmKitChainHook.chainDistanceViewsTexts, 1 do
        values[i] = FarmKitChainHook.chainDistanceViewsTexts[i]
    end
    element:setTexts(values)
end;
function nxGui:setChainDistanceView(index)
    self.chainDistanceView:setState(index, false)
end

function nxGui:onCreateSteeringMode(element)
    self.steeringMode = element
	--element.labelElement.text = g_i18n:getText('gui_nx_steeringMode');
	--element.toolTipText = g_i18n:getText('gui_nx_steeringModeToolTip');
	local values = {}
    for i = 1, #FarmKitChainHook.steeringModesTexts, 1 do
        values[i] = FarmKitChainHook.steeringModesTexts[i]
    end
    element:setTexts(values)
end;
function nxGui:setSteeringMode(index)
    self.steeringMode:setState(index, false)
end;

function nxGui:onCreateAutoOffVehicle(element)
    self.autoOffVehicle = element
	--element.labelElement.text = g_i18n:getText('gui_nx_autoOffVehicle');
	--element.toolTipText = g_i18n:getText('gui_nx_autoOffVehicleToolTip');
    local values = {}
    for i = 1, #FarmKitChainHook.booleansTexts, 1 do
        values[i] = FarmKitChainHook.booleansTexts[i]
    end
    element:setTexts(values)
end;
function nxGui:setAutoOffVehicle(index)
    self.autoOffVehicle:setState(index, false)
end;
function nxGui:onClickShowIds(element)
	self.IdsDistanceView:setDisabled(not FarmKitChainHook.booleans[self.showIds:getState()])
end
function nxGui:onClickResetButton()
    FarmKitChainHook:settingsResetGui()
end;