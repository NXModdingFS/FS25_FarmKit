
FarmKitChainHook = {}
FarmKitChainHook.confDir = getUserProfileAppPath().. "modSettings/FS25_FarmKit/"
FarmKitChainHook.modDirectory = g_currentModDirectory
local modName = g_currentModName
FarmKitChainHook.chains = {}
FarmKitChainHook.lastSelectedChainId = 1

FarmKitChainHook.IdsDistanceViews = { 1, 2, 3, 4, 5, 10, 15, 20, 30, 40, 50 }
FarmKitChainHook.chainDistanceViews = { 10, 20, 30, 40, 50, 70, 100, 150, 200 }
FarmKitChainHook.booleans = { true, false }
FarmKitChainHook.steeringModes = { 1, 2, 3 }

FarmKitChainHook.IdsDistanceViewsTexts = { '1m', '2m', '3m', '4m', '5m', '10m', '15m', '20m', '30m', '40m', '50m' }
FarmKitChainHook.chainDistanceViewsTexts = { '10m', '20m', '30m', '40m', '50m', '70m', '100m', '150m', '200m' }
FarmKitChainHook.booleansTexts = { 'On', 'Off' }
FarmKitChainHook.steeringModesTexts = { g_i18n:getText('gui_nx_both'), g_i18n:getText('gui_nx_auto'), g_i18n:getText('gui_nx_manual') }

FarmKitChainHook.manualAttach = true
FarmKitChainHook.showHelp = true
FarmKitChainHook.showIds = false   -- FarmKit: chain-ID world text removed
FarmKitChainHook.IdsDistanceView = 5
FarmKitChainHook.chainDistanceView = 100
FarmKitChainHook.steeringMode = 1
FarmKitChainHook.autoOffVehicle = true   -- FarmKit: forced on so detach never blocks

FarmKitChainHook.manualAttachIndex = 1
FarmKitChainHook.showHelpIndex = 1
FarmKitChainHook.showIdsIndex = 2   -- FarmKit: chain-ID off (2 = off)
FarmKitChainHook.IdsDistanceViewIndex = 5
FarmKitChainHook.chainDistanceViewIndex = 7
FarmKitChainHook.steeringModeIndex = 1
FarmKitChainHook.autoOffVehicleIndex = 1   -- FarmKit: forced on (1 = on)

function FarmKitChainHook.appendedFunction(oldTarget, oldFunc, newTarget, newFunc)
	local superFunc = oldTarget[oldFunc]

	oldTarget[oldFunc] = function(...)
		superFunc(...)
		newTarget[newFunc](newTarget, ...)
	end
end
if InputHelpDisplay.MAX_NUM_ELEMENTS <= 6 then
		InputHelpDisplay.MAX_NUM_ELEMENTS = 10
end
function FarmKitChainHook:playerInputComponent_registerActionEvents(inputComponent)
	if inputComponent.player.isOwner then
		g_inputBinding:beginActionEventsModification(PlayerInputComponent.INPUT_CONTEXT_NAME)
		
		if g_dedicatedServerInfo ~= nil then
			return
		end
		if FarmKitChainHook.event_IDsPlayer == nil then
			FarmKitChainHook.event_IDsPlayer = {}
		end
		local actions = { InputAction.FARMKIT_MANUAL_ATTACH, InputAction.FARMKIT_ATTACH_HOOK, InputAction.FARMKIT_SWITCH, InputAction.FARMKIT_MOVE_HOOK_TRIGGER, InputAction.FARMKIT_MOVE_HOOK_LEFT, InputAction.FARMKIT_MOVE_HOOK_RIGHT,
						InputAction.FARMKIT_MOVE_HOOK_FORWARD, InputAction.FARMKIT_MOVE_HOOK_BACKWARD, InputAction.FARMKIT_MOVE_HOOK_UP, InputAction.FARMKIT_MOVE_HOOK_DOWN, InputAction.FARMKIT_OPEN_MENU }
		local _, eventId
		for _,actionName in pairs(actions) do
			local always = (actionName == InputAction.FARMKIT_CHANGE_MOVE_HOOK_LEFT or actionName == InputAction.FARMKIT_CHANGE_MOVE_HOOK_RIGHT or actionName == InputAction.FARMKIT_CHANGE_MOVE_HOOK_FORWARD or
							actionName == InputAction.FARMKIT_CHANGE_MOVE_HOOK_BACKWARD or actionName == InputAction.FARMKIT_CHANGE_MOVE_HOOK_UP or actionName == InputAction.FARMKIT_CHANGE_MOVE_HOOK_DOWN or actionName == InputAction.FARMKIT_MOVE_HOOK_TRIGGER) and true or false
			local success, eventId, otherEvents = g_inputBinding:registerActionEvent(actionName, self, FarmKitChainHook.actionCallbackPlayer, true, true, always, true, nil, true)
			g_inputBinding:setActionEventTextVisibility(eventId, false)
			FarmKitChainHook.event_IDsPlayer[actionName] = eventId
			if g_inputBinding ~= nil and g_inputBinding.events ~= nil and g_inputBinding.events[eventId] ~= nil then
				if actionName == 'something with lower priority' then
					g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_NORMAL)
				else
					g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_HIGH)
				end
				if actionName == InputAction.AUTOLOADWOOD2_TOGGLE_HELP then
					g_inputBinding:setActionEventTextVisibility(eventId, true)
				else
					g_inputBinding:setActionEventTextVisibility(eventId, FarmKitChainHook.showHelp)
				end
				g_inputBinding:setActionEventActive(eventId, false)
			end
			local colliding = false
			_, colliding, _ = g_inputBinding:checkEventCollision(actionName)
			if colliding then
				print(string.format("Warning: FarmKitChainHook got a colliding action for player: %s", actionName))
			end
		end
		g_inputBinding:endActionEventsModification()
	end
end
function getIndexFromElement(table, element)
	for index, el in pairs(table) do
		if type(element) == 'number' then
			if string.format("%.2f", element) == string.format("%.2f", el) then
				return index
			end
		else
			if element == el then
				return index
			end
		end
	end
	return false
end
function FarmKitChainHook.prerequisitesPresent(specializations)
	return true
end
function FarmKitChainHook.initSpecialization()
    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("FarmKitChainHook")
	AttacherJoints.registerAttacherJointXMLPaths(schema, "vehicle.towingChainHook.attacherJoints")

    schema:setXMLSpecializationType()
end
function FarmKitChainHook.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "isDetachAllowed", 		FarmKitChainHook.isDetachAllowed)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanBePickedUp", 	FarmKitChainHook.getCanBePickedUp)
	if FarmKitChainHook.twPlayer == nil then
		FarmKitChainHook.appendedFunction(PlayerInputComponent, "registerActionEvents", FarmKitChainHook, "playerInputComponent_registerActionEvents", false)
		--PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(PlayerInputComponent.registerGlobalPlayerActionEvents, FarmKitChainHook.registerActionEventsPlayer)
		--PlayerInputComponent.update = Utils.appendedFunction(PlayerInputComponent.update, FarmKitChainHook.playerInputComponent_update)
		FarmKitChainHook.twPlayer = true
	end
end
function FarmKitChainHook.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "attachVehicles", 					FarmKitChainHook.attachVehicles)
	SpecializationUtil.registerFunction(vehicleType, "detachVehicles", 					FarmKitChainHook.detachVehicles)
	SpecializationUtil.registerFunction(vehicleType, "playerInRange", 					FarmKitChainHook.playerInRange)
	SpecializationUtil.registerFunction(vehicleType, "getIsTurnedOn", 					FarmKitChainHook.getIsTurnedOn)
	SpecializationUtil.registerFunction(vehicleType, "mountHook", 						FarmKitChainHook.mountHook)
	SpecializationUtil.registerFunction(vehicleType, "unmountHook", 					FarmKitChainHook.unmountHook)
	SpecializationUtil.registerFunction(vehicleType, "switchToNextChain", 				FarmKitChainHook.switchToNextChain)
	SpecializationUtil.registerFunction(vehicleType, "getIsControlled", 				FarmKitChainHook.getIsControlled)
	SpecializationUtil.registerFunction(vehicleType, "toggleControlVehicle", 			FarmKitChainHook.toggleControlVehicle)
	SpecializationUtil.registerFunction(vehicleType, "getFirstAttacher", 				FarmKitChainHook.getFirstAttacher)
	SpecializationUtil.registerFunction(vehicleType, "getFirstVehicleAttached", 		FarmKitChainHook.getFirstVehicleAttached)
	SpecializationUtil.registerFunction(vehicleType, "getIsVehicleControlledByPlayer", 	FarmKitChainHook.getIsVehicleControlledByPlayer)
	SpecializationUtil.registerFunction(vehicleType, "getChainCanBeAttached", 			FarmKitChainHook.getChainCanBeAttached)
	SpecializationUtil.registerFunction(vehicleType, "moveHook", 						FarmKitChainHook.moveHook)
	SpecializationUtil.registerFunction(vehicleType, "saveConfigTc", 					FarmKitChainHook.saveConfigTc)
	SpecializationUtil.registerFunction(vehicleType, "loadConfigTc", 					FarmKitChainHook.loadConfigTc)
	SpecializationUtil.registerFunction(vehicleType, "updateManualSteering", 			FarmKitChainHook.updateManualSteering)
	SpecializationUtil.registerFunction(vehicleType, "vehicleIdToVehicle", 				FarmKitChainHook.vehicleIdToVehicle)
	SpecializationUtil.registerFunction(vehicleType, "vehicleToVehicleId", 				FarmKitChainHook.vehicleToVehicleId)
	SpecializationUtil.registerFunction(vehicleType, "updateDirtAndWear", 				FarmKitChainHook.updateDirtAndWear)
end
function FarmKitChainHook.registerEvents(vehicleType)
end
function FarmKitChainHook:onRegisterActionEvents(isSelected, isOnActiveVehicle)
	local spec = self.spec_towingChainHook
	
	if self.spec_attachable.attacherVehicle ~= nil then
		local firstAttVehicle = self:getFirstAttacher(self, nil, false)
		local firstVehicleAttached = self:getFirstVehicleAttached(self, nil, false)
		if firstAttVehicle ~= nil then
			if firstAttVehicle:getIsControlled() or self.spec_attachable.attacherVehicle:getIsControlled() then-------------------------------------------------------------------	ADDED
				if firstVehicleAttached ~= nil and self.isServer and not spec.isUsedSelf then
					if g_currentMission.missionInfo.automaticMotorStartEnabled then
						if not spec.controlVehicle and (spec.attachedVehicleThrottle or spec.steeringMode == 2 or spec.steeringMode == 3) then
							self:toggleControlVehicle(spec.attachedVehicleThrottle, spec.steeringMode, spec.reverseDrivingMode, true, false)
						end
					else
						if spec.controlVehicle and not firstVehicleAttached.spec_motorized.isMotorStarted then
							firstVehicleAttached:startMotor(false)
						elseif not spec.controlVehicle then
							if spec.attachedVehicleThrottle or spec.steeringMode == 2 or spec.steeringMode == 3 then
								self:toggleControlVehicle(spec.attachedVehicleThrottle, spec.steeringMode, spec.reverseDrivingMode, true, false)
							elseif firstVehicleAttached.spec_motorized.isMotorStarted then
								firstVehicleAttached:stopMotor(false)
							end
						end
					end
				end
				if spec.isAttached then
					FarmKitChainHook.selectedChainId = spec.chainId
				end
				self:loadConfigTc()
			else
				if firstVehicleAttached ~= nil and self.isServer and not spec.isUsedSelf then
					if spec.controlVehicle then
						Drivable.updateVehiclePhysics(firstVehicleAttached, 0, spec.reverseDrivingMode and spec.axisSteer or spec.axisSteer, false, 1)
						if g_currentMission.missionInfo.automaticMotorStartEnabled then
							self:toggleControlVehicle(spec.attachedVehicleThrottle, spec.steeringMode, spec.reverseDrivingMode, true, false)
						end
					end
				end
			end
		end
	end
	
	if g_dedicatedServerInfo ~= nil then
		return
	end
	if spec.event_IDs == nil then
		spec.event_IDs = {}
	else
		self:clearActionEventsTable(spec.event_IDs)
	end
	if self:getIsActiveForInput() then
		local actions = { InputAction.FARMKIT_ATTACH_VEHICLE, InputAction.FARMKIT_VEHICLE_THROTTLE, InputAction.FARMKIT_TOGGLE_STEERING_MODE, InputAction.FARMKIT_STEER_LEFT,
						InputAction.FARMKIT_STEER_RIGHT, InputAction.FARMKIT_CHANGE_ATTACHED_DIRECTION, InputAction.FARMKIT_OPEN_MENU_VEHICLE }
		for _,actionName in pairs(actions) do
			local always = (actionName == InputAction.FARMKIT_STEER_LEFT or actionName == InputAction.FARMKIT_STEER_RIGHT) and true or false
			local _, eventId = g_inputBinding:registerActionEvent(actionName, self, FarmKitChainHook.actionCallback, true, true, always, true)
			spec.event_IDs[actionName] = eventId
			if g_inputBinding ~= nil and g_inputBinding.events ~= nil and g_inputBinding.events[eventId] ~= nil then
				if actionName == InputAction.FARMKIT_STEER_LEFT or actionName == InputAction.FARMKIT_STEER_RIGHT then
					g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_NORMAL)
				elseif actionName == InputAction.FARMKIT_CHANGE_ATTACHED_DIRECTION then
					g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_HIGH)
				else
					g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_HIGH)
				end
				if actionName == InputAction.RC_TOGGLE_HELP then
					g_inputBinding:setActionEventTextVisibility(eventId, true)
				elseif actionName == InputAction.RC_TOGGLE or actionName == InputAction.RC_TOGGLE_ALL then
					g_inputBinding:setActionEventTextVisibility(eventId, false)
				else
					g_inputBinding:setActionEventTextVisibility(eventId, FarmKitChainHook.showHelp)
				end
				g_inputBinding:setActionEventActive(eventId, true)
			end
			local colliding = false
			_, colliding, _ = g_inputBinding:checkEventCollision(actionName)
			if colliding then
				if g_inputBinding.nameActions[actionName].bindings[1] ~= nil then
					if g_inputBinding.nameActions[actionName].bindings[1].inputString ~= nil then
						print(string.format('Warning: FarmKitChainHook got a colliding input action: %s', actionName)..' ('..g_inputBinding.nameActions[actionName].bindings[1].inputString..'). You can remap it in controls settings')
					end
				else
					print(string.format('Warning: FarmKitChainHook got a colliding input action: %s', actionName))
				end
			end
		end
	end
end
function FarmKitChainHook.registerEventListeners(vehicleType)
	for _,n in pairs( { "onLoad", "onPostLoad", "onLoadFinished", "onPreDelete", "onUpdate", "onUpdateTick", "onDraw", "onReadStream", "onWriteStream", "onRegisterActionEvents", "playerInputComponent_registerActionEvents", "moveHook", "attachVehicles", "detachVehicles", "mountHook", "unmountHook" } ) do
		SpecializationUtil.registerEventListener(vehicleType, n, FarmKitChainHook)
	end
end
function FarmKitChainHook:onLoad(savegame)
	self.spec_towingChainHook = {}
	local spec = self.spec_towingChainHook
	
    spec.attachPoint = I3DUtil.indexToObject(self.components, getXMLString(self.xmlFile.handle,"vehicle.towingChainHook#index"));
    spec.attachPointColli = I3DUtil.indexToObject(self.components, getXMLString(self.xmlFile.handle,"vehicle.towingChainHook#rootNode"));
    spec.firstComponent = I3DUtil.indexToObject(self.components, getXMLString(self.xmlFile.handle,"vehicle.towingChainHook#firstComponent"));
    self.rootNode = spec.attachPointColli
	spec.distance = Utils.getNoNil(getXMLFloat(self.xmlFile.handle, "vehicle.towingChainHook#distance"),2.2)
	spec.brakeForce = Utils.getNoNil(getXMLFloat(self.xmlFile.handle, "vehicle.towingChainHook#brakeForce"),1.2)
	spec.brakeForceIdle = Utils.getNoNil(getXMLFloat(self.xmlFile.handle, "vehicle.towingChainHook#brakeForceIdle"),0.1)
	spec.massAttached = Utils.getNoNil(getXMLFloat(self.xmlFile.handle, "vehicle.towingChainHook#massAttached"),0.15)
	spec.massDetached = Utils.getNoNil(getXMLFloat(self.xmlFile.handle, "vehicle.towingChainHook#massDetached"),0.03)
    spec.isUsed = false
	spec.isUsedSelf = false
    spec.joint = {};
    spec.lastVehicle = nil
	local baseName = "vehicle"
	spec.sampleAttach = g_soundManager:loadSampleFromXML(self.xmlFile.handle, baseName, "attachSound", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
	spec.inputChainAttachVehicle = false
	spec.inputChainVehicleThrottle = false
	spec.inputControlVehicle = false
	spec.attachedVehicleThrottle = false
	spec.controlVehicle = false
	FarmKitChainHook.input_manualAttach = false
	spec.timer = 0
	spec.firsRun = true
	spec.hookMounted = false
	spec.chainId = #FarmKitChainHook.chains + 1
	spec.isAttached = false
	spec.isInRange = false
	spec.axisSteer = 0
	spec.axisForward = 0
	spec.autoSteer = true
	spec.steeringMode = 1
	spec.steeringModeLast = 1
	spec.reverseDrivingMode = false
	spec.timerHook = 0
	spec.hookIsMoving = false
	spec.timer2 = 0
	spec.timer3 = 0
	spec.timer4 = 0
	spec.input_STEER_LEFT = false
	spec.input_STEER_RIGHT = false
	spec.debug = false
	spec.infoText3 = ''
	spec.deleted = false
	if self.selectionObject.vehicle.isVehicleSaved then
		FarmKitChainHook.chains[spec.chainId] = self
	end
	if FarmKitChainHook.selectedChainId == nil then
		FarmKitChainHook.selectedChainId = spec.chainId
	end
	--gui
	source(Utils.getFilename(FarmKitChainHook.modDirectory .. "gui/nxGui.lua")) 
    FarmKitChainHook.gui = {}
	g_gui:loadProfiles(FarmKitChainHook.modDirectory .. "gui/guiProfiles.xml")
    FarmKitChainHook.gui["nxSettingGui"] = nxGui:new()
	g_gui:loadGui(FarmKitChainHook.modDirectory .. "gui/nxGui.xml", "nxGui", FarmKitChainHook.gui.nxSettingGui)
	FarmKitChainHook:loadConfigTc()
end
function FarmKitChainHook:onPostLoad(savegame)
	local spec = self.spec_towingChainHook
end
function FarmKitChainHook:onLoadFinished(savegame)
	local spec = self.spec_towingChainHook
	
	if savegame ~= nil and (not savegame.resetVehicles or savegame.keepPosition) then
		local xmlFile = savegame.xmlFile.handle
		local key = savegame.key.."."..modName..".FarmKitChainHook"
		local isUsed = Utils.getNoNil(getXMLBool(xmlFile, key.."#isUsed"), spec.isUsed)
		local hookMounted = Utils.getNoNil(getXMLBool(xmlFile, key.."#hookMounted"), spec.hookMounted)
		
		if hookMounted then
			spec.hookMountedBack = getXMLBool(xmlFile, key.."#hookMountedBack")
			spec.hookX = getXMLFloat(xmlFile, key.."#hookX")
			spec.hookY = getXMLFloat(xmlFile, key.."#hookY")
			spec.hookZ = getXMLFloat(xmlFile, key.."#hookZ")
			local hookedVehicleId = getXMLString(xmlFile, key.."#hookedVehicleUniqueId")
			if hookedVehicleId ~= nil then
				spec.postMountHook = true
				spec.postMountHookVal = {hookedVehicleId}
			end
		end
		if isUsed then
			local attachedVehicleId = getXMLString(xmlFile, key.."#attachedVehicleUniqueId")
			local attacherJointId = getXMLInt(xmlFile, key.."#attacherJointId")
			if attachedVehicleId ~= nil and attacherJointId ~= nil then
				spec.postAttachVehicles = true
				spec.postAttachObjectVal = {attachedVehicleId, attacherJointId}
			end
		end
	end
end
function FarmKitChainHook:saveConfigTc()
	local spec = self.spec_towingChainHook

	if g_dedicatedServerInfo ~= nil then
		return
	end

	local configFile = FarmKitChainHook.confDir .. "FarmKitChainConfig.xml"
	createFolder(getUserProfileAppPath().. "modSettings/")
	createFolder(FarmKitChainHook.confDir)
	FarmKitChainHook.configXml = createXMLFile("FarmKitChain_XML", configFile, "FarmKitChainConfig")

	if FarmKitChainHook ~= nil then  
		setXMLBool(FarmKitChainHook.configXml, "FarmKitChainConfig.manualAttach", FarmKitChainHook.manualAttach)
		setXMLBool(FarmKitChainHook.configXml, "FarmKitChainConfig.showHelp", FarmKitChainHook.showHelp)
		setXMLBool(FarmKitChainHook.configXml, "FarmKitChainConfig.showIds", FarmKitChainHook.showIds)
		setXMLFloat(FarmKitChainHook.configXml, "FarmKitChainConfig.IdsDistanceView", FarmKitChainHook.IdsDistanceView)
		setXMLFloat(FarmKitChainHook.configXml, "FarmKitChainConfig.chainDistanceView", FarmKitChainHook.chainDistanceView)
		setXMLFloat(FarmKitChainHook.configXml, "FarmKitChainConfig.steeringMode", FarmKitChainHook.steeringMode)
		setXMLBool(FarmKitChainHook.configXml, "FarmKitChainConfig.autoOffVehicle", FarmKitChainHook.autoOffVehicle)
	end
	saveXMLFile(FarmKitChainHook.configXml)
end
function FarmKitChainHook:loadConfigTc()
	local spec = self.spec_towingChainHook
	
	if g_dedicatedServerInfo ~= nil then
		return
	end

	local configFile = FarmKitChainHook.confDir .. "FarmKitChainConfig.xml"
	if not fileExists(configFile) then
		FarmKitChainHook:saveConfigTc()
	else
		FarmKitChainHook.configXml = loadXMLFile("FarmKitChain_XML", configFile)
		if FarmKitChainHook ~= nil then
			FarmKitChainHook.manualAttach = getXMLBool(FarmKitChainHook.configXml, "FarmKitChainConfig.manualAttach")
			FarmKitChainHook.showHelp = getXMLBool(FarmKitChainHook.configXml, "FarmKitChainConfig.showHelp")
			FarmKitChainHook.showIds = false   -- FarmKit: chain-ID removed, ignore saved value
			FarmKitChainHook.IdsDistanceView = getXMLFloat(FarmKitChainHook.configXml, "FarmKitChainConfig.IdsDistanceView")
			FarmKitChainHook.chainDistanceView = getXMLFloat(FarmKitChainHook.configXml, "FarmKitChainConfig.chainDistanceView")
			FarmKitChainHook.steeringMode = getXMLFloat(FarmKitChainHook.configXml, "FarmKitChainConfig.steeringMode")
			FarmKitChainHook.autoOffVehicle = true   -- FarmKit: forced on, ignore saved value so detach never blocks
			
			FarmKitChainHook.manualAttachIndex = getIndexFromElement(FarmKitChainHook.booleans, FarmKitChainHook.manualAttach)
			FarmKitChainHook.showHelpIndex = getIndexFromElement(FarmKitChainHook.booleans, FarmKitChainHook.showHelp)
			FarmKitChainHook.showIdsIndex = getIndexFromElement(FarmKitChainHook.booleans, FarmKitChainHook.showIds)
			FarmKitChainHook.IdsDistanceViewIndex = getIndexFromElement(FarmKitChainHook.IdsDistanceViews, FarmKitChainHook.IdsDistanceView)
			FarmKitChainHook.chainDistanceViewIndex = getIndexFromElement(FarmKitChainHook.chainDistanceViews, FarmKitChainHook.chainDistanceView)
			FarmKitChainHook.steeringModeIndex = getIndexFromElement(FarmKitChainHook.steeringModes, FarmKitChainHook.steeringMode)
			FarmKitChainHook.autoOffVehicleIndex = getIndexFromElement(FarmKitChainHook.booleans, FarmKitChainHook.autoOffVehicle)
			
			FarmKitChainHook.gui.nxSettingGui:setManualAttach(FarmKitChainHook.manualAttachIndex)
			FarmKitChainHook.gui.nxSettingGui:setShowHelp(FarmKitChainHook.showHelpIndex)
			FarmKitChainHook.gui.nxSettingGui:setShowIds(FarmKitChainHook.showIdsIndex)
			FarmKitChainHook.gui.nxSettingGui:setIdsDistanceView(FarmKitChainHook.IdsDistanceViewIndex)
			FarmKitChainHook.gui.nxSettingGui:setChainDistanceView(FarmKitChainHook.chainDistanceViewIndex)
			FarmKitChainHook.gui.nxSettingGui:setSteeringMode(FarmKitChainHook.steeringModeIndex)
			FarmKitChainHook.gui.nxSettingGui:setAutoOffVehicle(FarmKitChainHook.autoOffVehicleIndex)
		else
			print("FarmKitChainHook: Error loading settings - FarmKitChainHook == nil")
		end
	end
end
function FarmKitChainHook:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_towingChainHook
	
	setXMLBool(xmlFile.handle, key.."#isUsed", spec.isUsed)
	setXMLBool(xmlFile.handle, key.."#hookMounted", spec.hookMounted)
	if spec.hookMounted then
		setXMLInt(xmlFile.handle, key.."#hookedVehicleId", spec.hookedVehicleId.rootNode)
		setXMLString(xmlFile.handle, key.."#hookedVehicleName", spec.hookedVehicleId:getFullName())
		local x,y,z = getWorldTranslation(spec.hookedVehicleId.rootNode)
		setXMLFloat(xmlFile.handle, key.."#hookedVehicleX", x)
		setXMLFloat(xmlFile.handle, key.."#hookedVehicleY", y)
		setXMLFloat(xmlFile.handle, key.."#hookedVehicleZ", z)
		setXMLBool(xmlFile.handle, key.."#hookMountedBack", spec.hookMountedBack)
		setXMLFloat(xmlFile.handle, key.."#hookX", spec.hookX)
		setXMLFloat(xmlFile.handle, key.."#hookY", spec.hookY)
		setXMLFloat(xmlFile.handle, key.."#hookZ", spec.hookZ)
		setXMLString(xmlFile.handle, key.."#hookedVehicleUniqueId", spec.hookedVehicleId:getUniqueId())
	end
	if spec.isUsed then
		setXMLInt(xmlFile.handle, key.."#attachedVehicleId", spec.joint.vehicleId.rootNode)
		setXMLString(xmlFile.handle, key.."#attachedVehicleUniqueId", spec.joint.vehicleId:getUniqueId())
		setXMLString(xmlFile.handle, key.."#attachedVehicleName", spec.joint.vehicleId:getFullName())
		setXMLInt(xmlFile.handle, key.."#attacherJointId", spec.joint.attacherJointId)
		local x,y,z = getWorldTranslation(spec.joint.vehicleId.rootNode)
		setXMLFloat(xmlFile.handle, key.."#attachedVehicleX", x)
		setXMLFloat(xmlFile.handle, key.."#attachedVehicleY", y)
		setXMLFloat(xmlFile.handle, key.."#attachedVehicleZ", z)
	end
end
function FarmKitChainHook:onPreDelete()
	local spec = self.spec_towingChainHook

	if self.selectionObject.vehicle.isVehicleSaved then
		if self.isServer and spec.isUsed then
			self:detachVehicles(false)
		end
		if self.isServer and spec.hookMounted then
			self:unmountHook(spec.hookedVehicleId, false)
		end
		FarmKitChainHook.chains[spec.chainId] = nil
		local count = 0
		if FarmKitChainHook.selectedChainId == spec.chainId then
			for k,v in pairs(FarmKitChainHook.chains) do
				if v ~= nil then
					count = count + 1
					FarmKitChainHook.selectedChainId = k
					FarmKitChainHook.lastSelectedChainId = k
					break
				end
			end
			if count == 0 then
				FarmKitChainHook.selectedChainId = 1
				FarmKitChainHook.lastSelectedChainId = 1
				if FarmKitChainHook.event_IDsPlayer ~= nil then
					for actionName,eventId in pairs(FarmKitChainHook.event_IDsPlayer) do
						g_inputBinding:setActionEventActive(eventId, false)
					end
				end
			end
		end
		spec.deleted = true
	end
end
function FarmKitChainHook:switchToNextChain()
	local currentFound = false
	local firstKey = nil
	local newKey = nil
	
	local anyChainInRange = false
	local activeYardersCount = 0
	for k,v in pairs(FarmKitChainHook.chains) do
		if v ~= nil and v.spec_towingChainHook.isInRange then
			anyChainInRange = true
			activeYardersCount = activeYardersCount + 1
		end
	end
	if activeYardersCount == 1 and FarmKitChainHook.chains[FarmKitChainHook.selectedChainId].spec_towingChainHook.isInRange then
		newKey = FarmKitChainHook.selectedChainId
	elseif activeYardersCount == 0 then
		newKey = FarmKitChainHook.lastSelectedChainId
	else
		for k,v in pairs(FarmKitChainHook.chains) do
			if firstKey == nil then
				firstKey = k
			end
			if currentFound and v.spec_towingChainHook.isInRange then
				newKey = k
				break
			end
			if k == FarmKitChainHook.selectedChainId then
				currentFound = true
			end
		end
		if newKey == nil then
			newKey = firstKey
		end
	end
	FarmKitChainHook.selectedChainId = newKey
	FarmKitChainHook.lastSelectedChainId = newKey
end
function FarmKitChainHook:toggleControlVehicle(throttle, steering, reverseDrivingMode, forced, noEventSend)
	local spec = self.spec_towingChainHook
	
	FarmKitChainToggleControlVehicleEvent.sendEvent(self, throttle, steering, reverseDrivingMode, forced, noEventSend)
	
	local changed = false
	if spec.attachedVehicleThrottle ~= throttle then
		spec.attachedVehicleThrottle = throttle
		if spec.steeringMode == 1 then
			changed = true
		end
	end
	if spec.steeringMode ~= steering then
		spec.steeringMode = steering
		if (spec.steeringMode == 1 or spec.steeringMode == 2 or (spec.steeringMode == 3 and spec.steeringModeLast == 1)) and not spec.attachedVehicleThrottle then
			changed = true
																-------------------------------------------------------------------------------------------		ADDED
		end
		spec.steeringModeLast = spec.steeringMode
	end
	if spec.reverseDrivingMode ~= reverseDrivingMode then
		spec.reverseDrivingMode = reverseDrivingMode
	end
	local firstAttVehicle = self:getFirstAttacher(self, nil, false)
	local firstVehicleAttached = self:getFirstVehicleAttached(self, nil, false)
	if firstVehicleAttached == nil and spec.firstVehicleAttachedLast ~= nil then
		firstVehicleAttached = spec.firstVehicleAttachedLast
	end
	if (changed or forced) and spec.isUsed and not spec.isUsedSelf then
		spec.controlVehicle = not spec.controlVehicle
		if spec.firstVehicleAttachedLast ~= nil and not entityExists(spec.firstVehicleAttachedLast.rootNode) then
			return
		end
		if spec.controlVehicle then
			firstVehicleAttached:raiseActive()
			firstVehicleAttached.spec_enterable.playerStyle = firstAttVehicle.spec_enterable.playerStyle	-------------Fix for VCA-----------------
			if self.isServer or not self.isServer then
				firstVehicleAttached.getIsControlled = FarmKitChainHook.getIsControlled
				firstVehicleAttached.getIsVehicleControlledByPlayer = FarmKitChainHook.getIsVehicleControlledByPlayer
				firstVehicleAttached:startMotor(false)
			end
			if not g_currentMission.missionInfo.automaticMotorStartEnabled then
				if not firstVehicleAttached.spec_motorized.isMotorStarted then
					firstVehicleAttached:startMotor(false)
				end
			end
		else
			if self.isServer or not self.isServer then
				firstVehicleAttached.getIsControlled = firstVehicleAttached.getIsControlledBackup
				firstVehicleAttached.getIsVehicleControlledByPlayer = firstVehicleAttached.getIsVehicleControlledByPlayerBackup
			end
			if firstVehicleAttached.spec_drivable ~= nil then
				if firstVehicleAttached.spec_drivable.reverserDirection ~= nil then
					FarmKitChainHook.leaveVehicle(firstVehicleAttached, firstVehicleAttached.leaveVehicle)
				end
				if not g_currentMission.missionInfo.automaticMotorStartEnabled then
					if firstVehicleAttached.spec_motorized.isMotorStarted then
						firstVehicleAttached:stopMotor(false)
					end
				end
			elseif firstVehicleAttached.spec_attachable ~= nil then
				if firstVehicleAttached.spec_attachable.attacherVehicle ~= nil then
					if firstVehicleAttached.spec_attachable.attacherVehicle.spec_drivable ~= nil then
						if firstVehicleAttached.spec_attachable.attacherVehicle.spec_drivable.reverserDirection ~= nil then
							----FarmKitChainHook.leaveVehicle(firstVehicleAttached.spec_attachable.attacherVehicle, firstVehicleAttached.spec_attachable.attacherVehicle.leaveVehicle)
						end
					end
				end
			end
		end
	end
end
function FarmKitChainHook:updateManualSteering(left, right, noEventSend)
	local spec = self.spec_towingChainHook
	
	FarmKitChainupdateManualSteeringEvent.sendEvent(self, left, right, noEventSend)
	
	spec.input_STEER_LEFT = left
	spec.input_STEER_RIGHT = right
end
function FarmKitChainHook:getFirstAttacher(vehicle, passVehicles, debug)
	local spec = self.spec_towingChainHook
	
	local firstAttacherVehicle = nil
	local firstAttacherVehicleTemp = nil
	local tempVehicle
	local lastTempVehicle
	if passVehicles == nil then
		passVehicles = {}
	end
	if vehicle.spec_attachable.attacherVehicle ~= nil then
		tempVehicle = vehicle
		lastTempVehicle = tempVehicle
		local j = 0
		while true do
			j = j + 1
			if j > 20 then break end
			if not entityExists(tempVehicle.rootNode) then
				break
			end
			if tempVehicle.spec_drivable ~= nil then
				firstAttacherVehicleTemp = tempVehicle
				passVehicles[tempVehicle] = tempVehicle
			end
			if tempVehicle.towingChainAttached then
				lastTempVehicle = tempVehicle
				passVehicles[tempVehicle] = tempVehicle
				tempVehicle = FarmKitChainHook.chains[tempVehicle.towingChainAttachedId]
			elseif tempVehicle.spec_towingChainHook ~= nil then
				if tempVehicle.spec_attachable.attacherVehicle ~= nil then
					lastTempVehicle = tempVehicle
					passVehicles[tempVehicle] = tempVehicle
					tempVehicle = tempVehicle.spec_attachable.attacherVehicle
				else
					break
				end
			elseif tempVehicle.spec_attachable ~= nil and tempVehicle.spec_attachable.attacherVehicle ~= nil and tempVehicle.spec_attachable.attacherVehicle ~= lastTempVehicle and passVehicles[tempVehicle.spec_attachable.attacherVehicle] == nil then
				lastTempVehicle = tempVehicle
				passVehicles[tempVehicle] = tempVehicle
				tempVehicle = tempVehicle.spec_attachable.attacherVehicle
			elseif tempVehicle.spec_attacherJoints ~= nil and tempVehicle.spec_attacherJoints.attachedImplements ~= nil and #tempVehicle.spec_attacherJoints.attachedImplements > 0 then
				local veh = nil
				local someAtt = false
				for i,implement in pairs(tempVehicle.spec_attacherJoints.attachedImplements) do
					if passVehicles[implement.object] == nil then
						someAtt = true
						passVehicles[implement.object] = implement.object
						veh = self:getFirstAttacher(implement.object, passVehicles, debug)
						if veh ~= nil then
							firstAttacherVehicleTemp = veh
							break
						end
					end
				end
				if veh ~= nil then
					firstAttacherVehicleTemp = veh
					break
				end
				if not someAtt then
					break
				end
			elseif firstAttacherVehicleTemp ~= nil then
				firstAttacherVehicle = firstAttacherVehicleTemp
				break
			else
				break
			end
			
		end
		firstAttacherVehicle = firstAttacherVehicleTemp
	end
	return firstAttacherVehicle
end
function FarmKitChainHook:getFirstVehicleAttached(vehicle, passVehicles, debug)
	local spec = self.spec_towingChainHook
	
	local firstVehicleAttached = nil
	local tempVehicle
	local lastTempVehicle
	if passVehicles == nil then
		passVehicles = {}
	end
	tempVehicle = vehicle
	lastTempVehicle = tempVehicle
	while true do
		if not entityExists(tempVehicle.rootNode) then
			break
		end
		if tempVehicle.spec_drivable ~= nil then
			firstVehicleAttached = tempVehicle
			break
		elseif tempVehicle.towingChainAttached and tempVehicle.spec_towingChainHook == nil and (FarmKitChainHook.chains[tempVehicle.towingChainAttachedId] ~= lastTempVehicle or passVehicles[FarmKitChainHook.chains[tempVehicle.towingChainAttachedId]] == nil) then
			FarmKitChainHook.chains[tempVehicle.towingChainAttachedId]:detachVehicles(false)
			break
		elseif tempVehicle.spec_towingChainHook ~= nil then
			if tempVehicle.spec_towingChainHook.isUsed then
				if tempVehicle.spec_towingChainHook.joint.vehicleId ~= lastTempVehicle then
					lastTempVehicle = tempVehicle
					passVehicles[tempVehicle] = tempVehicle
					tempVehicle =  tempVehicle.spec_towingChainHook.joint.vehicleId
				else
					FarmKitChainHook.chains[tempVehicle.towingChainAttachedId]:detachVehicles(false)
					break
				end
			else
				break
			end
		elseif tempVehicle.spec_attachable ~= nil and tempVehicle.spec_attachable.attacherVehicle ~= nil and tempVehicle.spec_attachable.attacherVehicle ~= lastTempVehicle and passVehicles[tempVehicle.spec_attachable.attacherVehicle] == nil then
			lastTempVehicle = tempVehicle
			passVehicles[tempVehicle] = tempVehicle
			tempVehicle = tempVehicle.spec_attachable.attacherVehicle
		elseif tempVehicle.spec_attacherJoints ~= nil and tempVehicle.spec_attacherJoints.attachedImplements ~= nil and #tempVehicle.spec_attacherJoints.attachedImplements > 0 then
			passVehicles[tempVehicle] = tempVehicle
			local veh = nil
			local someAtt = false
			for i,implement in pairs(tempVehicle.spec_attacherJoints.attachedImplements) do
				if passVehicles[implement.object] == nil then
					someAtt = true
					passVehicles[implement.object] = implement.object
					veh = self:getFirstVehicleAttached(implement.object, passVehicles, false)
					if veh ~= nil then
						firstVehicleAttached = veh
						break
					end
				end
			end
			if veh ~= nil then
				firstVehicleAttached = veh
				break
			end
			if not someAtt then
				break
			end
		
		else
			break
		end
	end
	if firstVehicleAttached ~= nil and (firstVehicleAttached.getIsControlledBackup == nil or firstVehicleAttached.getIsVehicleControlledByPlayerBackup == nil) then
		firstVehicleAttached.getIsControlledBackup = firstVehicleAttached.getIsControlled
		firstVehicleAttached.getIsVehicleControlledByPlayerBackup = firstVehicleAttached.getIsVehicleControlledByPlayer
	end
	return firstVehicleAttached
end
function FarmKitChainHook:getChainCanBeAttached(vehicle, passVehicles, debug, detach)
	local spec = self.spec_towingChainHook
	
	local firstVehicleAttached = nil
	local tempVehicle
	local lastTempVehicle
	if passVehicles == nil then
		passVehicles = {}
	end
		tempVehicle = vehicle
		lastTempVehicle = tempVehicle
		while true do
			if not entityExists(tempVehicle.rootNode) then
				break
			end
			if tempVehicle.towingChainAttached and not tempVehicle.towingChainAttachedSelf and tempVehicle.spec_towingChainHook == nil and (FarmKitChainHook.chains[tempVehicle.towingChainAttachedId] ~= lastTempVehicle or passVehicles[FarmKitChainHook.chains[tempVehicle.towingChainAttachedId]] == nil) then
				if detach then FarmKitChainHook.chains[tempVehicle.towingChainAttachedId]:detachVehicles(false) end
				return false
			elseif tempVehicle.spec_towingChainHook ~= nil then
				if tempVehicle.spec_towingChainHook.isUsed then
					if tempVehicle.spec_towingChainHook.joint.vehicleId ~= lastTempVehicle then
						lastTempVehicle = tempVehicle
						passVehicles[tempVehicle] = tempVehicle
						tempVehicle =  tempVehicle.spec_towingChainHook.joint.vehicleId
					else
						if detach then FarmKitChainHook.chains[tempVehicle.towingChainAttachedId]:detachVehicles(false) end
						return false
					end
				else
					break
				end
			elseif tempVehicle.spec_attachable ~= nil and tempVehicle.spec_attachable.attacherVehicle ~= nil and tempVehicle.spec_attachable.attacherVehicle ~= lastTempVehicle and passVehicles[tempVehicle.spec_attachable.attacherVehicle] == nil then
				lastTempVehicle = tempVehicle
				passVehicles[tempVehicle] = tempVehicle
				tempVehicle = tempVehicle.spec_attachable.attacherVehicle
			elseif tempVehicle.spec_attacherJoints ~= nil and tempVehicle.spec_attacherJoints.attachedImplements ~= nil and #tempVehicle.spec_attacherJoints.attachedImplements > 0 then
				passVehicles[tempVehicle] = tempVehicle
				local veh = nil
				local someAtt = false
				for i,implement in pairs(tempVehicle.spec_attacherJoints.attachedImplements) do
					if passVehicles[implement.object] == nil then
						someAtt = true
						passVehicles[implement.object] = implement.object
						if not self:getChainCanBeAttached(implement.object, passVehicles, debug, detach) then
							return false
						end
					end
				end
				if not someAtt then
					break
				end
			else
				break
			end
		end
	return true
end
function FarmKitChainHook:onUpdate(dt)
	local spec = self.spec_towingChainHook
	
	if spec.postAttachVehicles and (spec.hooksMounted or not spec.postMountHook) then
		spec.timer4 = spec.timer4 + dt
		if spec.timer4 > 100 then
			spec.timer4 = 0
			spec.postAttachVehicles = false
			if self.isServer then
				--local attachedVehicleId = self:vehicleIdToVehicle(spec.postAttachObjectVal[1])
				local attachedVehicleId = g_currentMission.vehicleSystem:getVehicleByUniqueId(spec.postAttachObjectVal[1])
				spec.lastVehicle = {}
				spec.lastVehicle[1] = attachedVehicleId
				spec.lastVehicle[2] = spec.postAttachObjectVal[2]
				self:attachVehicles(spec.lastVehicle[1],spec.lastVehicle[2], true)
			elseif self.isClient and g_dedicatedServerInfo == nil then
				--local attachedVehicleId = self:vehicleIdToVehicle(spec.vehicleIdAttached)
				--local attachedVehicleId = g_currentMission.vehicleSystem:getVehicleByUniqueId(spec.vehicleIdAttached)
				spec.lastVehicle = {}
				spec.lastVehicle[1] = spec.vehicleIdAttached
				spec.lastVehicle[2] = spec.jointIdAttached
				self:attachVehicles(spec.lastVehicle[1],spec.lastVehicle[2], true)
			end
		end
	end
	if spec.postMountHook then
		spec.timer3 = spec.timer3 + dt
		if spec.timer3 > 100 then
			spec.timer3 = 0
			spec.postMountHook = false
			if self.isServer then
				spec.lastVehicleHook = {}
				--local hookedVehicleId = self:vehicleIdToVehicle(spec.postMountHookVal[1])
				local hookedVehicleId = g_currentMission.vehicleSystem:getVehicleByUniqueId(spec.postMountHookVal[1])
				spec.lastVehicleHook[1] = hookedVehicleId
				self:mountHook(hookedVehicleId, spec.hookMountedBack, true)
				self:moveHook(spec.hookX, spec.hookY, spec.hookZ, true)
			elseif self.isClient and g_dedicatedServerInfo == nil then
				--local hookedVehicleId = self:vehicleIdToVehicle(spec.vehicleIdHooked)
				--local hookedVehicleId = g_currentMission.vehicleSystem:getVehicleByUniqueId(spec.vehicleIdHooked)
				spec.lastVehicleHook = {}
				spec.lastVehicleHook[1] = spec.vehicleIdHooked
				self:mountHook(spec.lastVehicleHook[1], spec.hookMountedBack, true)
				self:moveHook(spec.hookX, spec.hookY, spec.hookZ, true)
			end
			spec.hooksMounted = true
		end
	end
	
	if spec.justAttached or spec.justDetached then
		spec.timer2 = spec.timer2 + dt
		local i = 0
		for _,component in pairs(self.components) do
			local key = i..'>1'
			local col = I3DUtil.indexToObject(self.components, key)
			local mass
			local massAttached = spec.massAttached
			local massDetached = spec.massDetached
			if spec.justAttached then
				mass = spec.timer2 * (massAttached / 1000)
				if mass > massAttached then mass = massAttached end
				if mass < massDetached then mass = massDetached end
				setMass(component.node, mass)
			end
			if spec.justDetached then
				mass = (1000 - spec.timer2) * (massAttached / 1000)
				if mass < massDetached then mass = massDetached end
				setMass(component.node, mass)
			end
			i = i + 1
		end
		if spec.timer2 >= 1000 then
			spec.timer2 = 0
			spec.justAttached = false
			spec.justDetached = false
		end
	end
	if self.selectionObject.vehicle.isVehicleSaved then
		local i = 0
		if spec.firsRun then
			spec.timer = spec.timer + dt
			if spec.timer >= 2500 then
				spec.firsRun = false
				for _,component in pairs(self.components) do
					local key = i..'>1'
					local col = I3DUtil.indexToObject(self.components, key)
					setScale(col, 0.3,0.3,1)
					i = i + 1
				end
			end
		end
	end
	if self.spec_attachable.attacherVehicle ~= nil or spec.isUsed or FarmKitChainHook.playerInRange(self, spec.attachPoint, 3) or self.spec_attachable.attacherVehicle == nil then
		self:raiseActive()
	end
	spec.isAttached = self.spec_attachable.attacherVehicle ~= nil
	if self.isServer and spec.isUsed and (spec.joint.vehicleId.rootNode == nil or (spec.joint.vehicleId.rootNode ~= nil and not entityExists(spec.joint.vehicleId.rootNode))) then
		self:detachVehicles(false)
	end
	if self.isServer and spec.hookMounted and (spec.hookedVehicleId.rootNode == nil or (spec.hookedVehicleId.rootNode ~= nil and not entityExists(spec.hookedVehicleId.rootNode))) then
		self:unmountHook(spec.hookedVehicleId, false)
	end
	local chainIsSelected = (FarmKitChainHook.selectedChainId == spec.chainId)
	
	if not g_localPlayer:getIsInVehicle() and g_localPlayer ~= nil and self.selectionObject.vehicle.isVehicleSaved then
		target = g_localPlayer.rootNode
		local x,y,z = getWorldTranslation(target)
		local a,b,c = getWorldTranslation(spec.attachPoint)
		local distance = MathUtil.vector3Length(x-a, y-b, z-c)
		local chainIsSelected = (FarmKitChainHook.selectedChainId == spec.chainId)
		if distance <= FarmKitChainHook.chainDistanceView and (spec.isAttached or not spec.isAttached or spec.isUsed or FarmKitChainHook.playerInRange(self, spec.attachPoint, 3)) then
			spec.isInRange = true
		else
			spec.isInRange = false
		end
		local count = 0
		for i,chain in pairs(FarmKitChainHook.chains) do
			if chain ~= nil and chain.spec_towingChainHook.isInRange then
				count = count + 1
			end
		end
		if not spec.isInRange and FarmKitChainHook.selectedChainId == spec.chainId and count > 0 then
			FarmKitChainHook.switchToNextChain()
		end
		if spec.isInRange and count > 0 and FarmKitChainHook.showHelp then
			--g_currentMission:addExtraPrintText(g_i18n:getText('towingChainChain')..spec.chainId..": "..string.format("%.1f",distance) .. " m ("..(spec.isUsed and g_i18n:getText('towingChainAttached') or g_i18n:getText('towingChainNotAttached'))..", "..(spec.hookMounted and g_i18n:getText('towingChainMounted') or g_i18n:getText('towingChainNotMounted'))..(chainIsSelected and g_i18n:getText('towingChainSelected')..")" or ")"))
			g_currentMission:addExtraPrintText(g_i18n:getText('towingChainChain')..spec.chainId..":"..(chainIsSelected and '*' or ' ')..string.format("%.1f",distance) .. "m ("..(spec.isUsed and g_i18n:getText('towingChainAttached') or g_i18n:getText('towingChainNotAttached'))..", "..(spec.hookMounted and g_i18n:getText('towingChainMounted') or g_i18n:getText('towingChainNotMounted'))..')')
		end
		if FarmKitChainHook.playerInRange(self, self.rootNode, 6) then
			if FarmKitChainHook.playerInRange(self, self.rootNode, 3) then
				if g_localPlayer.hands.spec_hands.pickupDistance < 10 then
					g_localPlayer.hands.spec_hands.pickupDistance = 10
					--g_localPlayer.hands:consoleCommandToggleSuperStrength()
				end
			else
				if g_localPlayer.hands.spec_hands.pickupDistance > 2 then
					g_localPlayer.hands.spec_hands.pickupDistance = 2
					--g_localPlayer.hands:consoleCommandToggleSuperStrength()
				end
			end
		end
		local menuOpened = false
		if g_currentMission.hud ~= nil then
			if g_currentMission.hud.isMenuVisible ~= nil then
				menuOpened = g_currentMission.hud.isMenuVisible
			end
		end
		if FarmKitChainHook.showIds and not menuOpened then
			local text = chainIsSelected and '*'..tostring(spec.chainId)..'*' or tostring(spec.chainId)
			if FarmKitChainHook.playerInRange(self, self.rootNode, FarmKitChainHook.IdsDistanceView) then
				local object = I3DUtil.indexToObject(self.components, '10>')
				--local x,y,z = getWorldTranslation(object)
				local x,y,z = localToWorld(object, 0,0.5,0)
				Utils.renderTextAtWorldPosition(x, y, z, text, getCorrectTextSize(0.03), 0)
			end
			if spec.hookMounted and FarmKitChainHook.playerInRange(self, spec.hook, FarmKitChainHook.IdsDistanceView) then
				local x,y,z = getWorldTranslation(spec.hook)
				Utils.renderTextAtWorldPosition(x, y, z, text, getCorrectTextSize(0.03), 0)
			end
		end
	end
	
	if not self:getIsActiveForInput() and chainIsSelected then
		if spec.lastVehicle ~= nil then 
            if not spec.isUsed then
                if FarmKitChainHook.manualAttach and FarmKitChainHook.playerInRange(self, spec.attachPoint, 3) and FarmKitChainHook.input_manualAttach and (spec.isAttached or self.towingChainAttached or not spec.isAttached) then
					FarmKitChainHook.input_manualAttach = false
                    if spec.lastVehicle[1].towingChainAttached then
						g_currentMission:showBlinkingWarning(g_i18n:getText('towingChainThisVehicle')..' ('..spec.lastVehicle[1]:getFullName()..') '..g_i18n:getText('towingChainAlreadyAttached'), 2000)
					elseif not self:getChainCanBeAttached(spec.lastVehicle[1], nil, false, false) then
						g_currentMission:showBlinkingWarning(g_i18n:getText('towingChainAllChains'), 2000)
					else
						self:attachVehicles(spec.lastVehicle[1], spec.lastVehicle[2], false)
						g_soundManager:playSample(spec.sampleAttach)
					end
                end
            end
		else
            if spec.isUsed then
                if FarmKitChainHook.input_manualAttach then
					if not spec.controlVehicle or FarmKitChainHook.autoOffVehicle then
						if FarmKitChainHook.autoOffVehicle then						------------------------------------------------------------------------------------------			ADDED
							if spec.attachedVehicleThrottle then
								self:toggleControlVehicle(not spec.attachedVehicleThrottle, spec.steeringMode, spec.reverseDrivingMode, false, false)
							end
							if spec.steeringMode ~= 1 then
								self:toggleControlVehicle(spec.attachedVehicleThrottle, 1, spec.reverseDrivingMode, false, false)
							end
						end
						self:detachVehicles(false)
						g_soundManager:playSample(spec.sampleAttach)
						FarmKitChainHook.input_manualAttach = false
					elseif spec.attachedVehicleThrottle then
						g_currentMission:showBlinkingWarning(g_i18n:getText('towingChainThrottleOff'), 2000)
					elseif spec.steeringMode ~= 1 then
						g_currentMission:showBlinkingWarning(g_i18n:getText('towingChainSteeringOff'), 2000)
					end
                end
			end
        end
		if spec.lastVehicleHook ~= nil then
			if FarmKitChainHook.input_mountHook then
				FarmKitChainHook.input_mountHook = false
				if not spec.hookMounted then
					if not spec.lastVehicleHook[1].towingHookMounted then
						self:mountHook(spec.lastVehicleHook[1], nil, false)
					else
						g_currentMission:showBlinkingWarning(g_i18n:getText('towingChainAlreadyHook')..' '..spec.lastVehicleHook[1].towingHookMountedId, 2000)
					end
				elseif spec.hookMounted then
					if spec.lastVehicleHook[1] == spec.hookedVehicleId then
						if not spec.lastVehicleHook[1].towingChainAttached or (spec.lastVehicleHook[1].towingChainAttached and not spec.lastVehicleHook[1].mountedHookAttached) then
							self:unmountHook(spec.lastVehicleHook[1], false)
						else
							g_currentMission:showBlinkingWarning(g_i18n:getText('towingChainFirstDetach1')..' '..spec.lastVehicleHook[1].towingChainAttachedId..' '..g_i18n:getText('towingChainFirstDetach2'), 2000)
						end
					else
						g_currentMission:showBlinkingWarning(g_i18n:getText('towingChainFirstUnmount')..' '..spec.hookedVehicleId:getFullName(), 2000)
					end
				end
			end
		end
	elseif self:getIsActiveForInput() then
        if spec.lastVehicle ~= nil then 
            if not spec.isUsed then
                if spec.inputChainAttachVehicle and spec.isAttached then
					spec.inputChainAttachVehicle = false
					if spec.lastVehicle[1].towingChainAttached then
						g_currentMission:showBlinkingWarning(g_i18n:getText('towingChainThisVehicle')..' ('..spec.lastVehicle[1]:getFullName()..') '..g_i18n:getText('towingChainAlreadyAttached'), 2000)
					elseif not self:getChainCanBeAttached(spec.lastVehicle[1], nil, false, false) then
						g_currentMission:showBlinkingWarning(g_i18n:getText('towingChainAllChains'), 2000)
					else
						self:attachVehicles(spec.lastVehicle[1], spec.lastVehicle[2], false)
						g_soundManager:playSample(spec.sampleAttach)
					end
                end
            end
        else
            if spec.isUsed then
                if spec.inputChainAttachVehicle then
					if not spec.controlVehicle or FarmKitChainHook.autoOffVehicle then
						if FarmKitChainHook.autoOffVehicle then
							if spec.attachedVehicleThrottle then
								self:toggleControlVehicle(not spec.attachedVehicleThrottle, spec.steeringMode, spec.reverseDrivingMode, false, false)
							end
							if spec.steeringMode ~= 1 then
								self:toggleControlVehicle(spec.attachedVehicleThrottle, 1, spec.reverseDrivingMode, false, false)
							end
						end
						self:detachVehicles(false)
						g_soundManager:playSample(spec.sampleAttach)
						spec.inputChainAttachVehicle = false
					elseif spec.attachedVehicleThrottle then
						g_currentMission:showBlinkingWarning(g_i18n:getText('towingChainThrottleOff'), 2000)
					elseif spec.steeringMode ~= 1 then
						g_currentMission:showBlinkingWarning(g_i18n:getText('towingChainSteeringOff'), 2000)
					end
                end
            else
				if spec.inputChainAttachVehicle then
					if self.spec_attachable ~= nil then
						if self.spec_attachable.attacherVehicle ~= nil then
							local jointDesc = self.spec_attachable.attacherVehicle:getAttacherJointIndexFromObject(self)
							if jointDesc ~= nil then
								spec.isUsedSelf = true
								self:attachVehicles(self.spec_attachable.attacherVehicle, jointDesc, false)
								g_soundManager:playSample(spec.sampleAttach);
								spec.inputChainAttachVehicle = false
							end
						end
					end
				end
			end
        end
	end
	local firstAttVehicle = self:getFirstAttacher(self, nil, false)
	local firstVehicleAttached = self:getFirstVehicleAttached(self, nil, false)
	
	if spec.isUsed and not spec.isUsedSelf then
		self:getChainCanBeAttached(self, nil, false, true)
		if firstAttVehicle ~= nil then
			--spec.infoText3 = spec.infoText3..'first attacher - '..tostring(firstAttVehicle:getFullName())..'\n'
		else
			--spec.infoText3 = spec.infoText3..'first attacher - none\n'
		end
		if firstVehicleAttached ~= nil then
			--spec.infoText3 = spec.infoText3..'first att.Vehicle - '..tostring(firstVehicleAttached:getFullName())..'\n'
		else
			--spec.infoText3 = spec.infoText3..'first att.Vehicle - none\n'
		end
		if firstAttVehicle ~= nil and firstVehicleAttached ~= nil then
			spec.firstVehicleAttachedLast = firstVehicleAttached
			if firstAttVehicle.spec_enterable.getIsControlled ~= nil and (firstAttVehicle.spec_enterable:getIsControlled() or not firstAttVehicle.spec_enterable:getIsControlled()) and not firstVehicleAttached.spec_enterable.isControlled then-------------------------------------------------------------------------
				if firstVehicleAttached.spec_drivable ~= nil then
					local mode = 0
					local brake = 0
					if firstVehicleAttached.spec_drivable.reverserDirection ~= nil then
						if spec.steeringMode == 2 then
							local x,y,z
							if firstVehicleAttached.towingChainAttachedId ~= nil then
								x,y,z = getWorldTranslation(FarmKitChainHook.chains[firstVehicleAttached.towingChainAttachedId].spec_towingChainHook.transform)
							else
								x,y,z = getWorldTranslation(spec.transform)
							end
							local xx,yy,zz = worldToLocal(self.spec_attachable.attacherVehicle.rootNode, x,y,z)
							spec.infoText3 = spec.infoText3..'xx - '..string.format("%.3f",xx)..',        '..string.format("%.3f",yy)..','..string.format("%.3f",zz)..'\n'
							local a, b, c = localDirectionToWorld(firstVehicleAttached.rootNode, 0, 0, 1)
							local x, y, z = worldDirectionToLocal(self.spec_attachable.attacherVehicle.rootNode, a,b,c)
							local diffXX = x
							if firstVehicleAttached.movingDirection < 0 then
								diffXX = diffXX * -1
							end
							spec.infoText3 = spec.infoText3..'diffXX - '..string.format("%.3f",diffXX)..'\n'
							if self.spec_attachable.attacherVehicle:getLastSpeed() > 1 then
								if spec.axisSteerLast == nil then
									spec.axisSteerLast = 0
								end
								if diffXX < -0.01 and xx < 0 then
									spec.axisSteer = xx * 1.5
									mode = 1
								elseif diffXX > 0.01 and xx > 0 then
									spec.axisSteer = xx * 1.5
									mode = 2
								else
									if xx > 0.001 then
										spec.axisSteer =(xx * 0.2)
										mode = 31
									elseif xx < -0.001 then
										spec.axisSteer = (xx * 0.2)
										mode = 32
									else
										spec.axisSteer = 0
										mode = 0
									end
								end
								if firstVehicleAttached.movingDirection < 0 then
									spec.axisSteer = spec.axisSteer * -1
								end
								spec.axisSteerLast = spec.axisSteer
							end
						elseif spec.steeringMode == 3 then
							if spec.input_STEER_LEFT then
								if spec.axisSteer > -1 then
									spec.axisSteer = spec.axisSteer - 0.05
								else
									spec.axisSteer = -1
								end
							elseif spec.input_STEER_RIGHT then
								if spec.axisSteer < 1 then
									spec.axisSteer = spec.axisSteer + 0.05
								else
									spec.axisSteer = 1
								end
							else
								if spec.axisSteer < -0.05 then
									spec.axisSteer = spec.axisSteer + 0.05
								elseif spec.axisSteer > 0.05 then
									spec.axisSteer = spec.axisSteer - 0.05
								else
									spec.axisSteer = 0
								end
							end
						else
							spec.axisSteer = 0
						end
						
						local x,y,z = getWorldTranslation(spec.firstComponent)
						local a,b,c = getWorldTranslation(spec.attachPoint)
						local distance = MathUtil.vector3Length(x - a, y - b, z - c)
						spec.infoText3 = spec.infoText3..'distance - '..string.format("%.3f",distance)..'\n'
						spec.axisForward = 0
						if spec.attachedVehicleThrottle then
							if firstAttVehicle.spec_drivable.axisForward > 0 then
								spec.axisForward = distance / 3.2
							elseif  firstAttVehicle.spec_drivable.axisForward < 0 then
								spec.axisForward = firstAttVehicle.spec_drivable.axisForward
							end
						end
						if spec.controlVehicle then
							Drivable.updateVehiclePhysics(firstVehicleAttached, spec.reverseDrivingMode and -spec.axisForward or spec.axisForward, spec.reverseDrivingMode and spec.axisSteer or spec.axisSteer, false, dt)
						end
						if (firstAttVehicle.spec_drivable.axisForward == 0 or firstAttVehicle.spec_drivable.axisForward < 0) and firstAttVehicle.spec_drivable.cruiseControl.state == 0 then
							brake = 1
						elseif distance <= spec.distance then
							brake = spec.brakeForce - (distance / spec.distance)
						else
							brake = spec.brakeForceIdle
						end
						if brake ~= 0 or brake == 0 then
							firstVehicleAttached:brake(brake)
						end
						--[[local source = self.spec_attachable.attacherVehicle.rootNode
						if source ~= nil then
							local x,y,z = getWorldTranslation(source)
							local nx, ny, nz = localDirectionToWorld(source, 5, 0, 0)
							local yx, yy, yz = localDirectionToWorld(source, 0, 5, 0)
							local zx, zy, zz = localDirectionToWorld(source, 0, 0, 5)
							drawDebugLine(x,y,z, 1, 0, 0, x + nx, y + ny, z + nz, 1, 0, 0);
							drawDebugLine(x,y,z, 0, 1, 0, x + yx, y + yy, z + yz, 0, 1, 0);
							drawDebugLine(x,y,z, 0, 0, 1, x + zx, y + zy, z + zz, 0, 0, 1);
						end
						local source
						if firstVehicleAttached.towingChainAttachedId ~= nil then
							source = FarmKitChainHook.chains[firstVehicleAttached.towingChainAttachedId].spec_towingChainHook.transform
						else
							source = spec.transform
						end
						if source ~= nil then
							local x,y,z = getWorldTranslation(source)
							local nx, ny, nz = localDirectionToWorld(source, 3, 0, 0)
							local yx, yy, yz = localDirectionToWorld(source, 0, 3, 0)
							local zx, zy, zz = localDirectionToWorld(source, 0, 0, 3)
							drawDebugLine(x,y,z, 1, 0, 0, x + nx, y + ny, z + nz, 1, 0, 0);
							drawDebugLine(x,y,z, 0, 1, 0, x + yx, y + yy, z + yz, 0, 1, 0);
							drawDebugLine(x,y,z, 0, 0, 1, x + zx, y + zy, z + zz, 0, 0, 1);
						end]]
					end
					if spec.debug then
						spec.infoText3 = spec.infoText3..'axisSteer - '..string.format("%.3f",spec.axisSteer)..'\n'
						spec.infoText3 = spec.infoText3..'axisForward - '..string.format("%.3f",spec.axisForward)..'\n'
						spec.infoText3 = spec.infoText3..'brake - '..string.format("%.3f",brake)..'\n'
						spec.infoText3 = spec.infoText3..'mode - '..string.format("%.0f",mode)..'\n'
						spec.infoText3 = spec.infoText3..'getLastSpeed() - '..string.format("%.0f",self.spec_attachable.attacherVehicle:getLastSpeed())..'\n'
						spec.infoText3 = spec.infoText3..'reverserDirection - '..tostring(firstVehicleAttached.spec_drivable.reverserDirection)..'\n'
						spec.infoText3 = spec.infoText3..'reverserDir. Att. - '..tostring(firstAttVehicle.spec_drivable.reverserDirection)..'\n'
						spec.infoText3 = spec.infoText3..'cruiseControl Att. - '..tostring(firstAttVehicle.spec_drivable.cruiseControl.state)..'\n'
						spec.infoText3 = spec.infoText3..'movingDirection - '..tostring(firstVehicleAttached.movingDirection)..'\n'
						spec.infoText3 = spec.infoText3..'getBrakeForce() - '..tostring(firstVehicleAttached.spec_motorized.motor:getBrakeForce())..'\n'
						if self:getIsActiveForInput() then
							if spec.debug then
								renderText(0.7, 0.67, 0.015, spec.infoText3)
							end
						end
					end
					spec.infoText3 = ''
				elseif firstVehicleAttached.spec_attachable ~= nil then
					if firstVehicleAttached.spec_attachable.attacherVehicle ~= nil then
						if firstVehicleAttached.spec_attachable.attacherVehicle.spec_drivable ~= nil then
							if firstVehicleAttached.spec_attachable.attacherVehicle.spec_drivable.reverserDirection ~= nil then
								Drivable.updateVehiclePhysics(firstVehicleAttached.spec_attachable.attacherVehicle, firstAttVehicle.spec_drivable.axisForward, firstAttVehicle.spec_drivable.axisSide, firstAttVehicle.spec_drivable.doHandbrake, dt)
							end
						end
					end
				end
			end
		else
			if spec.controlVehicle and self.isServer then
				self:toggleControlVehicle(false, 1, false, true, false)
			end
			if firstVehicleAttached == nil and spec.firstVehicleAttachedLast ~= nil then
				if spec.firstVehicleAttachedLast == spec.joint.vehicleId then
					self:detachVehicles(false)
					spec.firstVehicleAttachedLast = nil
				end
			end
			
		end
	end
	
	if self.isClient then
		if self:getIsActiveForInput() then
			if spec.event_IDs ~= nil and g_dedicatedServerInfo == nil then
				for actionName,eventId in pairs(spec.event_IDs) do
					g_inputBinding:setActionEventTextVisibility(eventId, FarmKitChainHook.showHelp)
					if actionName == InputAction.FARMKIT_ATTACH_VEHICLE then
						g_inputBinding:setActionEventActive(eventId, true)
						if spec.lastVehicle == nil then
							g_inputBinding:setActionEventText(eventId, spec.isUsed and (spec.isUsedSelf and g_i18n:getText('towingChainSelfDetach') or g_i18n:getText('towingChainVehicleDetach')) or g_i18n:getText('towingChainSelfAttach'))
						else
							g_inputBinding:setActionEventText(eventId, g_i18n:getText('towingChainVehicleAttach'))
						end
					
					elseif actionName == InputAction.FARMKIT_VEHICLE_THROTTLE then
						g_inputBinding:setActionEventActive(eventId, (spec.isUsed and not spec.isUsedSelf) and true or false)
						g_inputBinding:setActionEventText(eventId, spec.attachedVehicleThrottle and g_i18n:getText('towingChainVehicleThrottleOff') or g_i18n:getText('towingChainVehicleThrottleOn'))
					
					elseif actionName == InputAction.FARMKIT_TOGGLE_STEERING_MODE then
						g_inputBinding:setActionEventActive(eventId, (spec.isUsed and not spec.isUsedSelf) and true or false)
						g_inputBinding:setActionEventText(eventId, spec.steeringMode==1 and g_i18n:getText('towingChainSteeringModeOff') or (spec.steeringMode==2 and g_i18n:getText('towingChainSteeringModeAuto') or g_i18n:getText('towingChainSteeringModeManual')))
					
					elseif actionName == InputAction.FARMKIT_STEER_LEFT or actionName == InputAction.FARMKIT_STEER_RIGHT then
						g_inputBinding:setActionEventActive(eventId, spec.steeringMode == 3)
					elseif actionName == InputAction.FARMKIT_CHANGE_ATTACHED_DIRECTION then
						g_inputBinding:setActionEventActive(eventId, (spec.isUsed and not spec.isUsedSelf and spec.attachedVehicleThrottle) and true or false)
						g_inputBinding:setActionEventText(eventId, spec.reverseDrivingMode and g_i18n:getText('towingChainAttachedDirectionBackward') or g_i18n:getText('towingChainAttachedDirectionForward'))
					end
				end
			end
		else
			if spec.hook ~= nil and chainIsSelected then
				if FarmKitChainHook.playerInRange(self, spec.hook, 4) then
					if spec.input_MOVE_HOOK_LEFT or spec.input_MOVE_HOOK_RIGHT or spec.input_MOVE_HOOK_FORWARD or spec.input_MOVE_HOOK_BACKWARD or spec.input_MOVE_HOOK_UP or spec.input_MOVE_HOOK_DOWN then
						spec.hookIsMoving = true
						local x, y, z = getTranslation(spec.hook)
						local origZ = spec.hookedVehicleId.spec_towingChainHook and -0.1 or spec.hookedVehicleId.size.length / 1.9 * (spec.hookMountedBack and -1 or 1)
						spec.timerHook = spec.timerHook + dt
						if spec.input_MOVE_HOOK_LEFT then
							if spec.timerHook > 1000 then
								x = x + 0.01
							else
								x = x + 0.001
							end
							if x > 10.5 then x = 10.5 end
						end
						if spec.input_MOVE_HOOK_RIGHT then
							if spec.timerHook > 1000 then
								x = x - 0.01
							else
								x = x - 0.001
							end
							if x < -1.5 then x = -1.5 end
						end
						if spec.input_MOVE_HOOK_FORWARD then
							if spec.timerHook > 1000 then
								z = z + 0.01
							else
								z = z + 0.001
							end
							if z > origZ + 2 then z = origZ + 2 end
						end
						if spec.input_MOVE_HOOK_BACKWARD then
							if spec.timerHook > 1000 then
								z = z - 0.01
							else
								z = z - 0.001
							end
							if z < origZ - 2 then z = origZ - 2 end
						end
						if spec.input_MOVE_HOOK_UP then
							if spec.timerHook > 1000 then
								y = y + 0.01
							else
								y = y + 0.001
							end
							if y > 2.5 then y = 2.5 end
						end
						if spec.input_MOVE_HOOK_DOWN then
							if spec.timerHook > 1000 then
								y = y - 0.01
							else
								y = y - 0.001
							end
							if y < 0 then y = 0 end
						end
						spec.hookX = x
						spec.hookY = y
						spec.hookZ = z
						setTranslation(spec.hook, x, y, z)
					else
						spec.timerHook = 0
					end
				else
					if spec.hookIsMoving then
						spec.hookIsMoving = false
						spec.input_MOVE_HOOK_TRIGGER = false
						spec.input_MOVE_HOOK_LEFT = false
						spec.input_MOVE_HOOK_RIGHT = false
						spec.input_MOVE_HOOK_FORWARD = false
						spec.input_MOVE_HOOK_BACKWARD = false
						spec.input_MOVE_HOOK_UP = false
						spec.input_MOVE_HOOK_DOWN = false
						self:moveHook(spec.hookX, spec.hookY, spec.hookZ, false)
					end
				end
			end
		end
		if FarmKitChainHook.event_IDsPlayer ~= nil and chainIsSelected then
			local anyChainInRange = false
			for k,v in pairs(FarmKitChainHook.chains) do
				if v ~= nil and v.spec_towingChainHook.isInRange then
					anyChainInRange = true
				end
			end
			for actionName,eventId in pairs(FarmKitChainHook.event_IDsPlayer) do
				g_inputBinding:setActionEventTextVisibility(eventId, FarmKitChainHook.showHelp)
				if actionName == InputAction.FARMKIT_SWITCH then
					g_inputBinding:setActionEventActive(eventId, anyChainInRange)
					g_inputBinding:setActionEventText(eventId, g_i18n:getText('input_FARMKIT_SWITCH')..' ( '..tostring(FarmKitChainHook.selectedChainId)..' )')
				elseif actionName == InputAction.FARMKIT_OPEN_MENU then
					g_inputBinding:setActionEventActive(eventId, true)
				elseif actionName == InputAction.FARMKIT_MANUAL_ATTACH then
					g_inputBinding:setActionEventActive(eventId, ((spec.lastVehicle ~= nil and (spec.isAttached or self.towingChainAttached or not spec.isAttached)) or spec.isUsed) and FarmKitChainHook.playerInRange(self, spec.attachPoint, 3) and FarmKitChainHook.manualAttach)
					g_inputBinding:setActionEventText(eventId, spec.isUsed and g_i18n:getText('towingChainVehicleDetach') or g_i18n:getText('towingChainVehicleAttach'))
				elseif actionName == InputAction.FARMKIT_ATTACH_HOOK then
					g_inputBinding:setActionEventActive(eventId, spec.lastVehicleHook ~= nil and (not spec.hookMounted or (spec.hookMounted and FarmKitChainHook.playerInRange(self, spec.hook, spec.lastVehicleHook[1].size.length/1.2))))
					if spec.lastVehicleHook ~= nil then
						g_inputBinding:setActionEventText(eventId, (spec.hookMounted and spec.lastVehicleHook[1] == spec.hookedVehicleId) and g_i18n:getText('towingChainUnmountHook')..' '..spec.lastVehicleHook[1]:getFullName() or g_i18n:getText('towingChainMountHook')..' '..spec.lastVehicleHook[1]:getFullName())
					end
				elseif actionName == InputAction.FARMKIT_MOVE_HOOK_TRIGGER then
					g_inputBinding:setActionEventActive(eventId, spec.hook ~= nil and FarmKitChainHook.playerInRange(self, spec.hook, 3) and not spec.hookedVehicleId.mountedHookAttached and not spec.hookedVehicleId.spec_towingChainHook)
				elseif actionName == InputAction.FARMKIT_MOVE_HOOK_LEFT or actionName == InputAction.FARMKIT_MOVE_HOOK_RIGHT or actionName == InputAction.FARMKIT_MOVE_HOOK_FORWARD or actionName == InputAction.FARMKIT_MOVE_HOOK_BACKWARD
				or actionName == InputAction.FARMKIT_MOVE_HOOK_UP or actionName == InputAction.FARMKIT_MOVE_HOOK_DOWN then
					g_inputBinding:setActionEventActive(eventId, spec.hook ~= nil and FarmKitChainHook.playerInRange(self, spec.hook, 4) and spec.input_MOVE_HOOK_TRIGGER)
				end
			end
		end
	end
	if self:getIsActiveForInput() then
		if spec.debug then
			spec.infoText = ''
			spec.infoText = spec.infoText..'selectedChainId - '..string.format("%.1f",FarmKitChainHook.selectedChainId)..'\n'
			spec.infoText = spec.infoText..'steeringMode - '..string.format("%.0f",spec.steeringMode)..'\n'
			spec.infoText = spec.infoText..'attachedVehicleThrottle - '..tostring(spec.attachedVehicleThrottle)..'\n'
			spec.infoText = spec.infoText..'controlVehicle - '..tostring(spec.controlVehicle)..'\n'
			spec.infoText = spec.infoText..'reverseDrivingMode - '..tostring(spec.reverseDrivingMode)..'\n'
			spec.infoText = spec.infoText..'----------------------------------------\n'
			renderText(0.7, 0.97, 0.015, spec.infoText)
		end
	end
	if self:getIsActiveForInput() or (not g_localPlayer:getIsInVehicle() and g_localPlayer ~= nil and FarmKitChainHook.selectedChainId == spec.chainId) then
		if spec.debug then
			spec.infoText2 = ''
			spec.infoText2 = spec.infoText2..'selectedChainId - '..string.format("%.1f",FarmKitChainHook.selectedChainId)..'\n'
			for i,chain in pairs(FarmKitChainHook.chains) do
				spec.infoText2 = spec.infoText2..'chain '..chain.spec_towingChainHook.chainId..':------------------------------------\n'
				if firstAttVehicle ~= nil then
					spec.infoText2 = spec.infoText2..'first attacher - '..tostring(firstAttVehicle:getFullName())..'\n'
				else
					spec.infoText2 = spec.infoText2..'first attacher - none\n'
				end
				if firstVehicleAttached ~= nil then
					spec.infoText2 = spec.infoText2..'first att.Vehicle - '..tostring(firstVehicleAttached:getFullName()) or 'none'..'\n'
				else
					spec.infoText2 = spec.infoText2..'first att.Vehicle - none\n'
				end
				if chain:getIsActive() then
					spec.infoText2 = spec.infoText2..'getIsActive - true\n'
				else
					spec.infoText2 = spec.infoText2..'getIsActive - false\n'
				end
				spec.infoText2 = spec.infoText2..'getIsActiveForInput - '..tostring(chain:getIsActiveForInput())..'\n'
				spec.infoText2 = spec.infoText2..'isAttached - '..tostring(chain.spec_towingChainHook.isAttached)..'\n'
				spec.infoText2 = spec.infoText2..'isUsed - '..tostring(chain.spec_towingChainHook.isUsed)..'\n'
				spec.infoText2 = spec.infoText2..'isUsedSelf - '..tostring(chain.spec_towingChainHook.isUsedSelf)..'\n'
				spec.infoText2 = spec.infoText2..'hookMounted - '..tostring(chain.spec_towingChainHook.hookMounted)..'\n'
				spec.infoText2 = spec.infoText2..'lastVehicle - '..tostring(chain.spec_towingChainHook.lastVehicle)..'\n'
				spec.infoText2 = spec.infoText2..'showHelp - '..tostring(FarmKitChainHook.showHelp)..'\n'
			end
			setTextColor(0,1,0,1)
			renderText(0.85, 0.92, 0.015, spec.infoText2)
		end
	end
end
function FarmKitChainHook:onUpdateTick(dt)
	local spec = self.spec_towingChainHook
	
	if self.spec_attachable.attacherVehicle ~= nil or spec.isUsed then
		self:raiseActive()
	end
	spec.lastVehicle = nil
	if (self:getIsActiveForInput() or FarmKitChainHook.manualAttach == true) and not spec.isUsed then
		local x,y,z = getWorldTranslation(spec.attachPoint)
		for k,v in pairs(g_currentMission.vehicleSystem.vehicles) do
			if v ~= self and v ~= self.spec_attachable.attacherVehicle then
				local vx, vy, vz = getWorldTranslation(v.rootNode);
				if MathUtil.vector3Length(x - vx, y - vy, z - vz) <= 50 then
					if v.spec_attacherJoints ~= nil then
						for index,joint in pairs(v.spec_attacherJoints.attacherJoints) do
							if joint.jointType == AttacherJoints.JOINTTYPE_TRAILER or joint.jointType == AttacherJoints.JOINTTYPE_TRAILERLOW or joint.jointType == AttacherJoints.JOINTTYPE_TOWINGHOOK then
								local x1,y1,z1 = getWorldTranslation(joint.jointTransform)
								local distance = MathUtil.vector3Length(x-x1,y-y1,z-z1)
								if distance <= 1.5 then   
									spec.lastVehicle = {}
									spec.lastVehicle[1] = v
									spec.lastVehicle[2] = index
									break
								end
							end
						end
						if v.spec_attacherJoints.attacherJoint ~= nil and spec.lastVehicle == nil then
							if v.attacherJoint.jointType == AttacherJoints.JOINTTYPE_TRAILER or v.attacherJoint.jointType == AttacherJoints.JOINTTYPE_TRAILERLOW or joint.jointType == AttacherJoints.JOINTTYPE_TOWINGHOOK then
								local x1,y1,z1 = getWorldTranslation(v.spec_attacherJoints.attacherJoint.node)
								local distance = MathUtil.vector3Length(x-x1,y-y1,z-z1)
								if distance <= 1 then                        
									spec.lastVehicle = {}
									spec.lastVehicle[1] = v
									spec.lastVehicle[2] = 0
									break
								end
							end
						end
					end
				end
			end
		end
    end
	spec.lastVehicleHook = nil
	if not self:getIsActiveForInput() and not g_localPlayer:getIsInVehicle() and g_localPlayer ~= nil then
		local x,y,z = getWorldTranslation(g_localPlayer.rootNode)
		for k,v in pairs(g_currentMission.vehicleSystem.vehicles) do
			if v ~= self and (not v.spec_towingChainHook or not v.spec_towingChainHook.isAttached) then
				local vx, vy, vz
				if v.spec_towingChainHook ~= nil then
					vx, vy, vz = getWorldTranslation(v.spec_towingChainHook.firstComponent)
				else
					vx, vy, vz = getWorldTranslation(v.rootNode)
				end
				local distance = MathUtil.vector2Length(x - vx, z - vz)
				if distance <= v.size.length / 1.2 then
					if v.spec_attacherJoints ~= nil then
						spec.lastVehicleHook = {}
						spec.lastVehicleHook[1] = v
						break
					end
				end
			end
		end
    end
	if spec.hookMounted and spec.hookedVehicleId ~= nil and spec.hookedVehicleId.spec_washable ~= nil then
		if spec.hookedVehicleId.spec_washable.washableNodes ~= nil and spec.hookedVehicleId.spec_washable.washableNodes[1] ~= nil and spec.hookedVehicleId.spec_washable.washableNodes[1].nodes ~= nil then
			for node, _ in pairs(spec.hookedVehicleId.spec_washable.washableNodes[1].nodes) do
				local x, y, z, w = getShaderParameter(node, "scratches_dirt_snow_wetness")
				if x ~= spec.wearLast or y ~= spec.dirtLast then
					spec.wearLast = x
					spec.dirtLast = y
					self:updateDirtAndWear()
				end
				break
			end
		end
	end
end
function FarmKitChainHook:attachVehicles(vehicleId, jointId, noEventSend)
	local spec = self.spec_towingChainHook
	
    FarmKitChainAttachEvents.sendEvent(self, vehicleId, jointId,noEventSend)
	
    local joint = spec.joint
    joint.vehicle = vehicleId
    local jointFA = nil
	if jointId == 0 then
        jointFA = vehicleId.spec_attacherJoints.attacherJoint
    else
        jointFA = vehicleId.spec_attacherJoints.attacherJoints[jointId]
    end
	if vehicleId == self.spec_attachable.attacherVehicle then
		spec.isUsedSelf = true
	end
    if self.isServer then
        local colli = jointFA.rootNode;
        local colli2 = spec.attachPointColli
        local jointTransform = Utils.getNoNil(jointFA.jointTransform, jointFA.node)
        local jointTransform2 = spec.attachPoint
        local constr = JointConstructor:new()                 
        constr:setActors(colli2, colli)
        constr:setJointTransforms(jointTransform2,  jointTransform)
        for i=1, 3 do
            constr:setTranslationLimit(i-1, true, 0, 0)
            constr:setRotationLimit(i-1, i == 1 and 0 or -math.rad(10), i == 1 and 0 or math.rad(10))
        end;
        spec.joint.index = constr:finalize()
		if not spec.isUsedSelf then
			if vehicleId.spec_drivable ~= nil then
				if vehicleId.spec_drivable.reverserDirection ~= nil then
					vehicleId.getIsControlledBackup = vehicleId.getIsControlled
					vehicleId.getIsVehicleControlledByPlayerBackup = vehicleId.getIsVehicleControlledByPlayer
					FarmKitChainHook.leaveVehicle(vehicleId, vehicleId.leaveVehicle)
				end
			elseif vehicleId.spec_attachable ~= nil then
				if vehicleId.spec_attachable.attacherVehicle ~= nil then
					if vehicleId.spec_attachable.attacherVehicle.spec_drivable ~= nil then
						if vehicleId.spec_attachable.attacherVehicle.spec_drivable.reverserDirection ~= nil then
							----FarmKitChainHook.leaveVehicle(vehicleId.spec_attachable.attacherVehicle, vehicleId.spec_attachable.attacherVehicle.leaveVehicle)
						end
					end
				end
			end
		end
		spec.joint.attacherJointId = jointId
		if not spec.isUsedSelf then
			if vehicleId.leaveVehicle ~= nil then
				vehicleId.backupLeaveVehicle = vehicleId.leaveVehicle
			elseif vehicleId.spec_attachable ~= nil then
				if vehicleId.spec_attachable.attacherVehicle ~= nil then
					if vehicleId.spec_attachable.attacherVehicle.leaveVehicle ~= nil then
						----vehicleId.spec_attachable.attacherVehicle.backupLeaveVehicle = vehicleId.spec_attachable.attacherVehicle.leaveVehicle
					end
				end
			end
		end
		if not spec.isUsedSelf then
			spec.justAttached = true
			spec.justDetached = false
		end
    end
    vehicleId.forceIsActive = true
	spec.joint.vehicleId = vehicleId
    spec.isUsed = true
    spec.lastVehicle = nil
	
	if not spec.isUsedSelf then
		vehicleId.towingChainAttached = true
		vehicleId.towingChainAttachedId = spec.chainId
		if vehicleId.towingHookMounted ~= nil then
			vehicleId.mountedHookAttached = vehicleId.towingHookMounted and FarmKitChainHook.chains[vehicleId.towingHookMountedId].spec_towingChainHook.hookedVehicleAttacherIndex == jointId
		else
			vehicleId.mountedHookAttached = false
		end
		local x,y,z = getWorldTranslation(jointFA.jointTransform)
		local xx,yy,zz = worldToLocal(spec.joint.vehicleId.rootNode, x,y,z)
		spec.transform = createTransformGroup("transform")
		link(spec.joint.vehicleId.rootNode, spec.transform)
		setTranslation(spec.transform, 0,yy,zz+(zz>=0 and 1 or -1))
	else
		vehicleId.towingChainAttachedSelf = true																------------------------------------------------------------------------------		ADDED
	end
end
function FarmKitChainHook:detachVehicles(noEventSend)
	local spec = self.spec_towingChainHook
	
	if spec.controlVehicle and self.isServer then
		self:toggleControlVehicle(false, 1, false, true, false)
	end
	FarmKitChainDetachEvents.sendEvent(self, noEventSend)
    if self.isServer and spec.joint.vehicle.rootNode ~= nil and entityExists(spec.joint.vehicle.rootNode) then
		if not spec.isUsedSelf then
			if spec.joint.vehicleId.leaveVehicle ~= nil and spec.joint.vehicleId.backupLeaveVehicle ~= nil then
				spec.joint.vehicleId.leaveVehicle = spec.joint.vehicleId.backupLeaveVehicle
				spec.joint.vehicleId.backupLeaveVehicle = nil
			elseif spec.joint.vehicleId.spec_attachable ~= nil then
				if spec.joint.vehicleId.spec_attachable.attacherVehicle ~= nil then
					if spec.joint.vehicleId.spec_attachable.attacherVehicle.leaveVehicle ~= nil and spec.joint.vehicleId.spec_attachable.attacherVehicle.backupLeaveVehicle ~= nil then
						spec.joint.vehicleId.spec_attachable.attacherVehicle.leaveVehicle = spec.joint.vehicleId.spec_attachable.attacherVehicle.backupLeaveVehicle
						spec.joint.vehicleId.spec_attachable.attacherVehicle.backupLeaveVehicle = nil
					end
				end
			end
		end
        removeJoint(spec.joint.index)
		if not spec.isUsedSelf then
			if spec.joint.vehicle.spec_enterable ~= nil and spec.joint.vehicle.spec_motorized ~= nil and spec.joint.vehicle.spec_wheels ~= nil then
				if not spec.joint.vehicle.spec_enterable.isControlled and spec.joint.vehicle.spec_motorized.motor ~= nil and spec.joint.vehicle.spec_wheels.wheels~= nil then
					for k,wheel in pairs(spec.joint.vehicle.spec_wheels.wheels) do
						--setWheelShapeProps(wheel.node, wheel.wheelShape, 0, spec.joint.vehicleId.spec_motorized.motor:getBrakeForce() * wheel.brakeFactor, 0, wheel.rotationDamping)
					end
				end
			end
		end
		if not spec.isUsedSelf then
			spec.justDetached = true
			spec.justAttached = false
		end
    end
	if not spec.isUsedSelf then
		spec.joint.vehicleId.towingChainAttached = false
		spec.joint.vehicleId.towingChainAttachedId = nil
		spec.joint.vehicleId.mountedHookAttached = false
	end
    spec.joint.vehicle.forceIsActive = false
    spec.joint = nil
    spec.joint = {}
    spec.isUsed = false
	spec.isUsedSelf = false
	spec.attachedVehicleThrottle = false
	spec.steeringMode = 1
	spec.reverseDrivingMode = false
end
function FarmKitChainHook:mountHook(vehicleId, hookMountedBack, noEventSend)
	local spec = self.spec_towingChainHook
	
	if vehicleId ~= nil then
		local vehicle = vehicleId
		spec.hookI3d = g_i3DManager:loadSharedI3DFile(FarmKitChainHook.modDirectory..'hook.i3d', false, false)
		spec.hook = I3DUtil.indexToObject(spec.hookI3d, '0|0')
		spec.hookAttacher = I3DUtil.indexToObject(spec.hookI3d, '0|0|1')
		spec.washIndexes = {'0|0|0'}
		spec.washNodes = {}
		for i, node in pairs(spec.washIndexes) do
			spec.washNodes[i] = I3DUtil.indexToObject(spec.hookI3d, node)
		end
		local i=0
		while true do
			local baseName = string.format("vehicle.towingChainHook.attacherJoints.attacherJoint(%d)", i)
			if not hasXMLProperty(self.xmlFile.handle, baseName) then
				break
			end
			local attacherJoint = {}
			if vehicle:loadAttacherJointFromXML(attacherJoint, self.xmlFile, baseName, i) then
				table.insert(vehicle.spec_attacherJoints.attacherJoints, attacherJoint)
				attacherJoint.index = #vehicle.spec_attacherJoints.attacherJoints
				attacherJoint.jointTransform  = spec.hookAttacher
				spec.hookedVehicleAttacherIndex = attacherJoint.index
				attacherJoint.jointOrigRot = { getRotation(attacherJoint.jointTransform) }
				attacherJoint.jointOrigTrans = { getTranslation(attacherJoint.jointTransform) }
			end
			i = i + 1
		end
		spec.hookMountedBack = hookMountedBack
		if spec.hookMountedBack == nil then
			if not g_localPlayer:getIsInVehicle() and g_localPlayer ~= nil then
				local x,y,z = getWorldTranslation(g_localPlayer.rootNode)
				local xx,yy,zz = worldToLocal(vehicle.rootNode, x,y,z)
				spec.hookMountedBack = zz < 0
			end
		end
		if spec.hookX == nil and spec.hookY == nil and spec.hookZ == nil then
			spec.hookX = 0
			spec.hookY = vehicleId.spec_towingChainHook ~= nil and 0.5 or 1
			spec.hookZ = vehicleId.spec_towingChainHook ~= nil and 0 or ((vehicle.size.length/1.9) * (spec.hookMountedBack and -1 or 1))
		end
		setTranslation(spec.hook, spec.hookX, spec.hookY, spec.hookZ)
		setRotation(spec.hook, 0, vehicleId.spec_towingChainHook ~= nil and 0 or (spec.hookMountedBack and math.rad(0) or math.rad(180)), 0)
		--link(vehicle.rootNode, spec.hookI3d)
		local vehicleRoot = vehicleId.spec_towingChainHook ~= nil and vehicleId.spec_towingChainHook.firstComponent or vehicleId.rootNode
		link(vehicleRoot, spec.hook)
		spec.hookMounted = true
		spec.hookedVehicleId = vehicle
		vehicle.towingHookMounted = true
		vehicle.towingHookMountedId = spec.chainId
		self:updateDirtAndWear()
	end
	
	FarmKitChainMountHookEvent.sendEvent(self, vehicleId, spec.hookMountedBack, noEventSend)
end
function FarmKitChainHook:unmountHook(vehicleId, noEventSend)
	local spec = self.spec_towingChainHook
	
	if self.isServer then
		if vehicleId ~= nil then
			if vehicleId.towingChainAttached and FarmKitChainHook.chains[vehicleId.towingChainAttachedId].spec_towingChainHook.joint.attacherJointId == spec.hookedVehicleAttacherIndex then
				FarmKitChainHook.chains[vehicleId.towingChainAttachedId]:detachVehicles(false)
			end
		end
	end
	FarmKitChainUnmountHookEvent.sendEvent(self, vehicleId, noEventSend)
	spec.hookMounted = false
	spec.hookedVehicleId = nil
	if vehicleId ~= nil then
		removeJoint(vehicleId.spec_attacherJoints.attacherJoints[spec.hookedVehicleAttacherIndex].jointIndex)
		--vehicleId.spec_attacherJoints.attacherJoints[spec.hookedVehicleAttacherIndex] = nil
		table.remove(vehicleId.spec_attacherJoints.attacherJoints, spec.hookedVehicleAttacherIndex)
		vehicleId.towingHookMounted = false
		vehicleId.towingHookMountedId = 0
	end
	g_i3DManager:releaseSharedI3DFile(spec.hookI3d, false)
	if self.isServer then
		if vehicleId.rootNode ~= nil and entityExists(vehicleId.rootNode) then
			delete(spec.hook)
		end
	elseif self.isClient then
		if vehicleId ~= nil then
			delete(spec.hook)
		end
	end
	spec.hook = nil
	spec.hookAttacher  = nil
	spec.hookMountedBack = nil
	spec.hookX = nil
	spec.hookY = nil
	spec.hookZ = nil
end
function FarmKitChainHook:updateDirtAndWear()
	local spec = self.spec_towingChainHook
	
	if spec.hookedVehicleId.spec_washable ~= nil and spec.hookedVehicleId.spec_washable.washableNodes ~= nil and spec.hookedVehicleId.spec_washable.washableNodes[1] ~= nil and spec.hookedVehicleId.spec_washable.washableNodes[1].nodes ~= nil then
		for node, _ in pairs(spec.hookedVehicleId.spec_washable.washableNodes[1].nodes) do
			local x, y, z, w = getShaderParameter(node, "scratches_dirt_snow_wetness")
			for _, node in pairs(spec.washNodes) do
				setShaderParameter(node, "scratches_dirt_snow_wetness", x, y, z, w, false)
			end
			break
		end
	end
end
function FarmKitChainHook:moveHook(x, y, z, noEventSend)
	local spec = self.spec_towingChainHook
	
	setTranslation(spec.hook, x, y, z)
	spec.hookX = x
	spec.hookY = y
	spec.hookZ = z
	
	FarmKitChainMoveHookEvent.sendEvent(self, x, y, z, noEventSend)
end
function FarmKitChainHook:leaveVehicle(superFunc)
	local spec = self.spec_towingChainHook
	
    if not self:getIsControlled() then
		if superFunc ~= nil then
			superFunc(self)
		end
		if self.isServer then
			if self.spec_enterable ~= nil and self.spec_motorized ~= nil and self.spec_wheels ~= nil then
				if not self.spec_enterable.isControlled and self.spec_motorized.motor ~= nil and self.spec_wheels.wheels ~= nil then
					for k, wheel in pairs(self.spec_wheels.wheels) do
						--setWheelShapeProps(wheel.node, wheel.wheelShape, 0, self:getBrakeForce()*wheel.brakeFactor, 0.5, wheel.rotationDamping)
					end
				end
			end
		end
	end
end
function FarmKitChainHook:playerInRange(target, dist)
	local spec = self.spec_towingChainHook
	
	local inRange = false
	local source
	if not g_localPlayer:getIsInVehicle() and g_localPlayer ~= nil then
		source = g_localPlayer.rootNode
	end
	if source ~= nil and target ~= nil then
		local x,y,z = getWorldTranslation(target)
		local a,b,c = getWorldTranslation(source)
		local distance = MathUtil.vector3Length(x-a, y-b, z-c)
		if distance < dist then
			inRange = true
		end
	end
	return inRange
end
function FarmKitChainHook:getIsTurnedOn()
	local spec = self.spec_towingChainHook
	
    return spec.controlVehicle
end
function FarmKitChainHook:isDetachAllowed(superFunc)
	local spec = self.spec_towingChainHook
	
    if superFunc ~= nil then
        if not superFunc(self) then
            return false
        end
    end
    return (not spec.controlVehicle and not spec.isUsed)
end
function FarmKitChainHook:getCanBePickedUp(superFunc)
	return true
end
function FarmKitChainHook:getIsVehicleControlledByPlayer()
	return self.spec_enterable.isControlled
end
function FarmKitChainHook:getIsControlled()
	local spec = self.spec_towingChainHook
    
	return true
end
function FarmKitChainHook:onDraw()
	local spec = self.spec_towingChainHook
end
function FarmKitChainHook:actionCallback(actionName, keyStatus, arg4, arg5, arg6)
	local spec = self.spec_towingChainHook
	
	if self:getIsActiveForInput() then
		if keyStatus > 0 then
			if actionName == 'FARMKIT_ATTACH_VEHICLE' then
				spec.inputChainAttachVehicle = true
			elseif actionName == 'FARMKIT_VEHICLE_THROTTLE' then
				if self:getFirstVehicleAttached(self, nil, false) ~= nil then
					self:toggleControlVehicle(not spec.attachedVehicleThrottle, spec.steeringMode, spec.reverseDrivingMode, false, false)
				else
					g_currentMission:showBlinkingWarning(g_i18n:getText('towingChainNoDrivable'), 2000)
				end
			elseif actionName == 'FARMKIT_TOGGLE_STEERING_MODE' then
				if self:getFirstVehicleAttached(self, nil, false) ~= nil then
					local steeringMode = spec.steeringMode
					local max = FarmKitChainHook.steeringMode == 2 and 2 or 3
					local step = FarmKitChainHook.steeringMode == 3 and 2 or 1
					if steeringMode + step <= max then
						steeringMode = steeringMode + step
					else
						steeringMode = 1
					end
					self:toggleControlVehicle(spec.attachedVehicleThrottle, steeringMode, spec.reverseDrivingMode, false, false)
				else
					g_currentMission:showBlinkingWarning(g_i18n:getText('towingChainNoDrivable'), 2000)
				end
			elseif actionName == 'FARMKIT_CHANGE_ATTACHED_DIRECTION' then
				if self:getFirstVehicleAttached(self, nil, false) ~= nil then
					self:toggleControlVehicle(spec.attachedVehicleThrottle, spec.steeringMode, not spec.reverseDrivingMode, false, false)
				else
					g_currentMission:showBlinkingWarning(g_i18n:getText('towingChainNoDrivable'), 2000)
				end
			elseif actionName == 'FARMKIT_OPEN_MENU_VEHICLE' then
				if FarmKitChainHook.gui.nxSettingGui.isOpen then
					FarmKitChainHook.gui.nxSettingGui:onClickBack()
				elseif g_gui.currentGui == nil then
					FarmKitChainHook.gui.nxSettingGui:setManualAttach(FarmKitChainHook.manualAttachIndex)
					FarmKitChainHook.gui.nxSettingGui:setShowHelp(FarmKitChainHook.showHelpIndex)
					FarmKitChainHook.gui.nxSettingGui:setShowIds(FarmKitChainHook.showIdsIndex)
					FarmKitChainHook.gui.nxSettingGui:setIdsDistanceView(FarmKitChainHook.IdsDistanceViewIndex)
					FarmKitChainHook.gui.nxSettingGui:setChainDistanceView(FarmKitChainHook.chainDistanceViewIndex)
					FarmKitChainHook.gui.nxSettingGui:setSteeringMode(FarmKitChainHook.steeringModeIndex)
					FarmKitChainHook.gui.nxSettingGui:setAutoOffVehicle(FarmKitChainHook.autoOffVehicleIndex)
					FarmKitChainHook.gui.nxSettingGui.IdsDistanceView:setDisabled(not FarmKitChainHook.showIds)
					g_gui:showDialog("nxGui")
				end
			end
		elseif keyStatus == 0 then
			if actionName == 'FARMKIT_ATTACH_VEHICLE' then
				spec.inputChainAttachVehicle = false
			elseif actionName == 'FARMKIT_VEHICLE_THROTTLE' then
				spec.inputChainVehicleThrottle = false
			end
		end
		if actionName == 'FARMKIT_STEER_LEFT' then
			spec.input_STEER_LEFT = keyStatus > 0
			self:updateManualSteering(spec.input_STEER_LEFT, spec.input_STEER_RIGHT, false)
		elseif actionName == 'FARMKIT_STEER_RIGHT' then
			spec.input_STEER_RIGHT = keyStatus > 0
			self:updateManualSteering(spec.input_STEER_LEFT, spec.input_STEER_RIGHT, false)
		end
	end
end
function FarmKitChainHook:actionCallbackPlayer(actionName, keyStatus, arg4, arg5, arg6)
	local count = 0
	for i,chain in pairs(FarmKitChainHook.chains) do
		if chain ~= nil and chain.spec_towingChainHook.isInRange then
			count = count + 1
		end
	end
	--if count ~= 0 then
		if keyStatus > 0 then
			if count ~= 0 then
				if actionName == 'FARMKIT_MANUAL_ATTACH' then
					FarmKitChainHook.input_manualAttach = true
					--self:pickUpObject(false)
				elseif actionName == 'FARMKIT_ATTACH_HOOK' then
					FarmKitChainHook.input_mountHook = true
				elseif actionName == 'FARMKIT_SWITCH' then
					FarmKitChainHook.switchToNextChain()
				end
			end
			if actionName == 'FARMKIT_OPEN_MENU' then
				if FarmKitChainHook.gui.nxSettingGui.isOpen then
					FarmKitChainHook.gui.nxSettingGui:onClickBack()
				elseif g_gui.currentGui == nil then
					FarmKitChainHook.gui.nxSettingGui:setManualAttach(FarmKitChainHook.manualAttachIndex)
					FarmKitChainHook.gui.nxSettingGui:setShowHelp(FarmKitChainHook.showHelpIndex)
					FarmKitChainHook.gui.nxSettingGui:setShowIds(FarmKitChainHook.showIdsIndex)
					FarmKitChainHook.gui.nxSettingGui:setIdsDistanceView(FarmKitChainHook.IdsDistanceViewIndex)
					FarmKitChainHook.gui.nxSettingGui:setChainDistanceView(FarmKitChainHook.chainDistanceViewIndex)
					FarmKitChainHook.gui.nxSettingGui:setSteeringMode(FarmKitChainHook.steeringModeIndex)
					FarmKitChainHook.gui.nxSettingGui:setAutoOffVehicle(FarmKitChainHook.autoOffVehicleIndex)
					FarmKitChainHook.gui.nxSettingGui.IdsDistanceView:setDisabled(not FarmKitChainHook.showIds)
					g_gui:showDialog("nxGui")
				end
			end
		elseif keyStatus == 0 then
			if count ~= 0 then
				if actionName == 'FARMKIT_MANUAL_ATTACH' then
					FarmKitChainHook.input_manualAttach = false
				elseif actionName == 'FARMKIT_ATTACH_HOOK' then
					FarmKitChainHook.input_mountHook = false
				end
			end
		end
		
		local spec = FarmKitChainHook.chains[FarmKitChainHook.selectedChainId].spec_towingChainHook
		local chain = FarmKitChainHook.chains[FarmKitChainHook.selectedChainId]
		if actionName == 'FARMKIT_MOVE_HOOK_TRIGGER' then
			spec.input_MOVE_HOOK_TRIGGER = keyStatus > 0
		elseif actionName == 'FARMKIT_MOVE_HOOK_LEFT' then
			spec.input_MOVE_HOOK_LEFT = keyStatus > 0
			if keyStatus == 0 then chain:moveHook(spec.hookX, spec.hookY, spec.hookZ, false) end
		elseif actionName == 'FARMKIT_MOVE_HOOK_RIGHT' then
			spec.input_MOVE_HOOK_RIGHT = keyStatus > 0
			if keyStatus == 0 then chain:moveHook(spec.hookX, spec.hookY, spec.hookZ, false) end
		elseif actionName == 'FARMKIT_MOVE_HOOK_FORWARD' then
			spec.input_MOVE_HOOK_FORWARD = keyStatus > 0
			if keyStatus == 0 then chain:moveHook(spec.hookX, spec.hookY, spec.hookZ, false) end
		elseif actionName == 'FARMKIT_MOVE_HOOK_BACKWARD' then
			spec.input_MOVE_HOOK_BACKWARD = keyStatus > 0
			if keyStatus == 0 then chain:moveHook(spec.hookX, spec.hookY, spec.hookZ, false) end
		elseif actionName == 'FARMKIT_MOVE_HOOK_UP' then
			spec.input_MOVE_HOOK_UP = keyStatus > 0
			if keyStatus == 0 then chain:moveHook(spec.hookX, spec.hookY, spec.hookZ, false) end
		elseif actionName == 'FARMKIT_MOVE_HOOK_DOWN' then
			spec.input_MOVE_HOOK_DOWN = keyStatus > 0
			if keyStatus == 0 then chain:moveHook(spec.hookX, spec.hookY, spec.hookZ, false) end
		end
	--end
end
function FarmKitChainHook:settingsFromGui(manualAttachState, showHelpState, showIdsState, IdsDistanceViewState, chainDistanceViewState, steeringModeState, autoOffVehicleState)
	FarmKitChainHook.manualAttach = FarmKitChainHook.booleans[manualAttachState]
	FarmKitChainHook.showHelp = FarmKitChainHook.booleans[showHelpState]
	FarmKitChainHook.showIds = FarmKitChainHook.booleans[showIdsState]
	FarmKitChainHook.IdsDistanceView = FarmKitChainHook.IdsDistanceViews[IdsDistanceViewState]
	FarmKitChainHook.chainDistanceView = FarmKitChainHook.chainDistanceViews[chainDistanceViewState]
	FarmKitChainHook.steeringMode = FarmKitChainHook.steeringModes[steeringModeState]
	FarmKitChainHook.autoOffVehicle = FarmKitChainHook.booleans[autoOffVehicleState]

	FarmKitChainHook.manualAttachIndex = manualAttachState
	FarmKitChainHook.showHelpIndex = showHelpState
	FarmKitChainHook.showIdsIndex = showIdsState
	FarmKitChainHook.IdsDistanceViewIndex = IdsDistanceViewState
	FarmKitChainHook.chainDistanceViewIndex = chainDistanceViewState
	FarmKitChainHook.steeringModeIndex = steeringModeState
	FarmKitChainHook.autoOffVehicleIndex = autoOffVehicleState
	FarmKitChainHook:saveConfigTc()
end
function FarmKitChainHook:settingsResetGui()
	FarmKitChainHook.gui.nxSettingGui:setManualAttach(1)
	FarmKitChainHook.gui.nxSettingGui:setShowHelp(1)
	FarmKitChainHook.gui.nxSettingGui:setShowIds(1)
	FarmKitChainHook.gui.nxSettingGui:setIdsDistanceView(5)
	FarmKitChainHook.gui.nxSettingGui:setChainDistanceView(7)
	FarmKitChainHook.gui.nxSettingGui:setSteeringMode(1)
	FarmKitChainHook.gui.nxSettingGui:setSteeringMode(1)
	FarmKitChainHook.gui.nxSettingGui:setAutoOffVehicle(2)
end
function FarmKitChainHook:guiClosed()
	--[[FarmKitChainHook.gui.nxSettingGui:setManualAttach(FarmKitChainHook.manualAttachIndex)
	FarmKitChainHook.gui.nxSettingGui:setShowHelp(FarmKitChainHook.showHelpIndex)
	FarmKitChainHook.gui.nxSettingGui:setShowIds(FarmKitChainHook.showIdsIndex)
	FarmKitChainHook.gui.nxSettingGui:setIdsDistanceView(FarmKitChainHook.IdsDistanceViewIndex)
	FarmKitChainHook.gui.nxSettingGui:setChainDistanceView(FarmKitChainHook.chainDistanceViewIndex)
	FarmKitChainHook.gui.nxSettingGui:setSteeringMode(FarmKitChainHook.steeringModeIndex)
	FarmKitChainHook.gui.nxSettingGui:setAutoOffVehicle(FarmKitChainHook.autoOffVehicleIndex)]]
end
function FarmKitChainHook:onReadStream(streamId, connection)
	local spec = self.spec_towingChainHook
	
	local hookMounted = streamReadBool(streamId)
	if hookMounted then
		--local hookedVehicleId = streamReadString(streamId)
		local hookedVehicleId = NetworkUtil.readNodeObject(streamId)
		local hookMountedBack = streamReadBool(streamId)
		local hookX = streamReadFloat32(streamId)
		local hookY = streamReadFloat32(streamId)
		local hookZ = streamReadFloat32(streamId)
		if hookedVehicleId ~= nil and hookMountedBack ~= nil and hookX ~= nil and hookY ~= nil and hookZ ~= nil then
			spec.postMountHook = true
			spec.vehicleIdHooked = hookedVehicleId
			spec.hookMountedBack = hookMountedBack
			spec.hookX = hookX
			spec.hookY = hookY
			spec.hookZ = hookZ
		end
	end
    local isUsed = streamReadBool(streamId)
    if isUsed then
		--local attachedVehicleId = streamReadString(streamId)
		local attachedVehicleId = NetworkUtil.readNodeObject(streamId)
		local attacherJointId = streamReadInt32(streamId)
		if attachedVehicleId ~= nil and attacherJointId ~= nil then
			spec.postAttachVehicles = true
			spec.vehicleIdAttached = attachedVehicleId
			spec.jointIdAttached = attacherJointId
		end		
    end
	local throttle = streamReadBool(streamId)
	local steering = streamReadInt8(streamId)
	local reverse = streamReadBool(streamId)
	self:toggleControlVehicle(throttle, steering, reverse, false, true)
	if steering == 3 then
		local left = streamReadBool(streamId)
		local right = streamReadBool(streamId)
		self:updateManualSteering(left, right, true)
	end
end
function FarmKitChainHook:onWriteStream(streamId, connection)
	local spec = self.spec_towingChainHook
    streamWriteBool(streamId, spec.hookMounted)
	if spec.hookMounted then
		--local vehicle = self:vehicleToVehicleId(spec.hookedVehicleId)
		--local vehicle = spec.hookedVehicleId:getUniqueId()
		--streamWriteString(streamId, vehicle)
		NetworkUtil.writeNodeObject(streamId, spec.hookedVehicleId)
		streamWriteBool(streamId, spec.hookMountedBack)
		streamWriteFloat32(streamId, spec.hookX)
		streamWriteFloat32(streamId, spec.hookY)
		streamWriteFloat32(streamId, spec.hookZ)
	end
    streamWriteBool(streamId, spec.isUsed)
    if spec.isUsed then
		--local vehicle = self:vehicleToVehicleId(spec.joint.vehicle)
		--local vehicle = spec.joint.vehicle:getUniqueId()
		--streamWriteString(streamId, vehicle)
		NetworkUtil.writeNodeObject(streamId, spec.joint.vehicle)
        streamWriteInt32(streamId, spec.joint.attacherJointId)
    end
	streamWriteBool(streamId, spec.attachedVehicleThrottle)
	streamWriteInt8(streamId, spec.steeringMode)
	streamWriteBool(streamId, spec.reverseDrivingMode)
	if spec.steering == 3 then
		streamWriteBool(streamId, spec.input_STEER_LEFT)
		streamWriteBool(streamId, spec.input_STEER_RIGHT)
	end
end
function FarmKitChainHook:vehicleToVehicleId(vehicle)
	local id
	for k,v in pairs(g_currentMission.vehicleSystem.vehicles) do
		if v == vehicle then
			id = k
			break
		end
	end
	return id
end
function FarmKitChainHook:vehicleIdToVehicle(id)
	local vehicle
	for k,v in pairs(g_currentMission.vehicleSystem.vehicles) do
		if k == id then
			vehicle = v
			break
		end
	end
	return vehicle
end
------------------Events---------------------------
FarmKitChainAttachEvents = {};
FarmKitChainAttachEvents_mt = Class(FarmKitChainAttachEvents, Event);

InitEventClass(FarmKitChainAttachEvents, "FarmKitChainAttachEvents");

function FarmKitChainAttachEvents.emptyNew()
    local self = Event.new(FarmKitChainAttachEvents_mt);
	self.className="FarmKitChainAttachEvents";
    return self;
end
function FarmKitChainAttachEvents.new(vehicle, vehicleId, jointId)
    local self = FarmKitChainAttachEvents.emptyNew()
    self.vehicle = vehicle;
    self.vehicleId = vehicleId;
    self.jointId = jointId;
    return self;
end
function FarmKitChainAttachEvents:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId);
    self.vehicleId = NetworkUtil.readNodeObject(streamId);
    self.jointId = streamReadInt32(streamId);
    self:run(connection);
end
function FarmKitChainAttachEvents:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle);
    NetworkUtil.writeNodeObject(streamId, self.vehicleId);
    streamWriteInt32(streamId, self.jointId);
end
function FarmKitChainAttachEvents:run(connection)
    FarmKitChainHook.attachVehicles(self.vehicle, self.vehicleId, self.jointId, true);
    if not connection:getIsServer() then
        g_server:broadcastEvent(FarmKitChainAttachEvents.new(self.vehicle, self.vehicleId, self.jointId), nil, connection, self.vehicle);
    end
end
function FarmKitChainAttachEvents.sendEvent(vehicle, vehicleId, jointId, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(FarmKitChainAttachEvents.new(vehicle, vehicleId, jointId), nil, nil, vehicle);
        else
            g_client:getServerConnection():sendEvent(FarmKitChainAttachEvents.new(vehicle, vehicleId, jointId));
        end
    end
end

FarmKitChainDetachEvents = {}
FarmKitChainDetachEvents_mt = Class(FarmKitChainDetachEvents, Event)

InitEventClass(FarmKitChainDetachEvents, "FarmKitChainDetachEvents")

function FarmKitChainDetachEvents.emptyNew()
    local self = Event.new(FarmKitChainDetachEvents_mt)
	self.className="FarmKitChainDetachEvents"
    return self
end
function FarmKitChainDetachEvents.new(vehicle)
    local self = FarmKitChainDetachEvents.emptyNew()
    self.vehicle = vehicle;
    return self
end
function FarmKitChainDetachEvents:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self:run(connection)
end
function FarmKitChainDetachEvents:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
end
function FarmKitChainDetachEvents:run(connection)
    FarmKitChainHook.detachVehicles(self.vehicle, true)
    if not connection:getIsServer() then
        g_server:broadcastEvent(FarmKitChainDetachEvents.new(self.vehicle), nil, connection, self.vehicle)
    end
end
function FarmKitChainDetachEvents.sendEvent(vehicle, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(FarmKitChainDetachEvents.new(vehicle), nil, nil, vehicle)
        else
            g_client:getServerConnection():sendEvent(FarmKitChainDetachEvents.new(vehicle))
        end
    end
end

FarmKitChainMountHookEvent = {};
FarmKitChainMountHookEvent_mt = Class(FarmKitChainMountHookEvent, Event);

InitEventClass(FarmKitChainMountHookEvent, "FarmKitChainMountHookEvent");

function FarmKitChainMountHookEvent.emptyNew()
    local self = Event.new(FarmKitChainMountHookEvent_mt);
	self.className="FarmKitChainMountHookEvent";
    return self;
end
function FarmKitChainMountHookEvent.new(object, vehicleId, hookMountedBack)
    local self = FarmKitChainMountHookEvent.emptyNew()
    self.object = object;
    self.vehicleId = vehicleId;
    self.hookMountedBack = hookMountedBack;
    return self;
end
function FarmKitChainMountHookEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId);
    self.vehicleId = NetworkUtil.readNodeObject(streamId);
	self.hookMountedBack = streamReadBool(streamId)
    self:run(connection);
end
function FarmKitChainMountHookEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object);
    NetworkUtil.writeNodeObject(streamId, self.vehicleId);
	streamWriteBool(streamId, self.hookMountedBack)
end
function FarmKitChainMountHookEvent:run(connection)
	if self.object ~= nil then
		self.object:mountHook(self.vehicleId, self.hookMountedBack, true)
	end
    if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
    end
end
function FarmKitChainMountHookEvent.sendEvent(vehicle, vehicleId, hookMountedBack, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(FarmKitChainMountHookEvent.new(vehicle, vehicleId, hookMountedBack), nil, nil, vehicle);
        else
            g_client:getServerConnection():sendEvent(FarmKitChainMountHookEvent.new(vehicle, vehicleId, hookMountedBack));
        end
    end
end

FarmKitChainUnmountHookEvent = {};
FarmKitChainUnmountHookEvent_mt = Class(FarmKitChainUnmountHookEvent, Event);

InitEventClass(FarmKitChainUnmountHookEvent, "FarmKitChainUnmountHookEvent");

function FarmKitChainUnmountHookEvent.emptyNew()
    local self = Event.new(FarmKitChainUnmountHookEvent_mt);
	self.className="FarmKitChainUnmountHookEvent";
    return self;
end
function FarmKitChainUnmountHookEvent.new(object, vehicleId)
    local self = FarmKitChainUnmountHookEvent.emptyNew()
    self.object = object;
    self.vehicleId = vehicleId;
    return self;
end
function FarmKitChainUnmountHookEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId);
    self.vehicleId = NetworkUtil.readNodeObject(streamId);
    self:run(connection);
end
function FarmKitChainUnmountHookEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object);
    NetworkUtil.writeNodeObject(streamId, self.vehicleId);
end
function FarmKitChainUnmountHookEvent:run(connection)
	if self.object ~= nil then
		self.object:unmountHook(self.vehicleId, true)
	end
    if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
    end
end
function FarmKitChainUnmountHookEvent.sendEvent(vehicle, vehicleId, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(FarmKitChainUnmountHookEvent.new(vehicle, vehicleId), nil, nil, vehicle);
        else
            g_client:getServerConnection():sendEvent(FarmKitChainUnmountHookEvent.new(vehicle, vehicleId));
        end
    end
end

FarmKitChainToggleControlVehicleEvent = {};
FarmKitChainToggleControlVehicleEvent_mt = Class(FarmKitChainToggleControlVehicleEvent, Event);

InitEventClass(FarmKitChainToggleControlVehicleEvent, "FarmKitChainToggleControlVehicleEvent");

function FarmKitChainToggleControlVehicleEvent.emptyNew()
    local self = Event.new(FarmKitChainToggleControlVehicleEvent_mt);
	self.className="FarmKitChainToggleControlVehicleEvent";
    return self;
end
function FarmKitChainToggleControlVehicleEvent.new(object, throttle, steering, reverse, forced)
    local self = FarmKitChainToggleControlVehicleEvent.emptyNew()
    self.object = object
    self.throttle = throttle
    self.steering = steering
    self.reverse = reverse
    self.forced = forced
    return self
end
function FarmKitChainToggleControlVehicleEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId);
    self.throttle = streamReadBool(streamId)
    self.steering = streamReadInt8(streamId)
    self.reverse = streamReadBool(streamId)
    self.forced = streamReadBool(streamId)
    self:run(connection)
end
function FarmKitChainToggleControlVehicleEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object);
    streamWriteBool(streamId, self.throttle)
    streamWriteInt8(streamId, self.steering)
    streamWriteBool(streamId, self.reverse)
    streamWriteBool(streamId, self.forced)
end
function FarmKitChainToggleControlVehicleEvent:run(connection)
	if self.object ~= nil then
		self.object:toggleControlVehicle(self.throttle, self.steering, self.reverse, self.forced, true)
	end
    if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
    end
end
function FarmKitChainToggleControlVehicleEvent.sendEvent(vehicle, throttle, steering, reverse, forced, noEventSend)
	if throttle ~= vehicle.throttle and steering ~= vehicle.steering and reverse ~= vehicle.reverse and forced ~= vehicle.forced then
		if noEventSend == nil or noEventSend == false then
			if g_server ~= nil then
				g_server:broadcastEvent(FarmKitChainToggleControlVehicleEvent.new(vehicle, throttle, steering, reverse, forced), nil, nil, vehicle)
			else
				g_client:getServerConnection():sendEvent(FarmKitChainToggleControlVehicleEvent.new(vehicle, throttle, steering, reverse, forced))
			end
		end
	end
end

FarmKitChainupdateManualSteeringEvent = {}
FarmKitChainupdateManualSteeringEvent_mt = Class(FarmKitChainupdateManualSteeringEvent, Event)

InitEventClass(FarmKitChainupdateManualSteeringEvent, "FarmKitChainupdateManualSteeringEvent")

function FarmKitChainupdateManualSteeringEvent.emptyNew()
    local self = Event.new(FarmKitChainupdateManualSteeringEvent_mt)
	self.className="FarmKitChainupdateManualSteeringEvent"
    return self
end
function FarmKitChainupdateManualSteeringEvent.new(object, left, right)
    local self = FarmKitChainupdateManualSteeringEvent.emptyNew()
    self.object = object
    self.left = left
    self.right = right
    return self
end
function FarmKitChainupdateManualSteeringEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId);
    self.left = streamReadBool(streamId)
    self.right = streamReadBool(streamId)
    self:run(connection)
end
function FarmKitChainupdateManualSteeringEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object);
    streamWriteBool(streamId, self.left)
    streamWriteBool(streamId, self.right)
end
function FarmKitChainupdateManualSteeringEvent:run(connection)
	if self.object ~= nil then
		self.object:updateManualSteering(self.left, self.right, true)
	end
    if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
    end
end
function FarmKitChainupdateManualSteeringEvent.sendEvent(vehicle, left, right, noEventSend)
	if left ~= vehicle.left and right ~= vehicle.right then
		if noEventSend == nil or noEventSend == false then
			if g_server ~= nil then
				g_server:broadcastEvent(FarmKitChainupdateManualSteeringEvent.new(vehicle, left, right), nil, nil, vehicle)
			else
				g_client:getServerConnection():sendEvent(FarmKitChainupdateManualSteeringEvent.new(vehicle, left, right))
			end
		end
	end
end

FarmKitChainMoveHookEvent = {};
FarmKitChainMoveHookEvent_mt = Class(FarmKitChainMoveHookEvent, Event);

InitEventClass(FarmKitChainMoveHookEvent, "FarmKitChainMoveHookEvent");

function FarmKitChainMoveHookEvent.emptyNew()
    local self = Event.new(FarmKitChainMoveHookEvent_mt);
	self.className="FarmKitChainMoveHookEvent";
    return self;
end
function FarmKitChainMoveHookEvent.new(object, x, y, z)
    local self = FarmKitChainMoveHookEvent.emptyNew()
    self.object = object
    self.x = x
    self.y = y
    self.z = z
    return self
end
function FarmKitChainMoveHookEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId);
    self.x = streamReadFloat32(streamId)
    self.y = streamReadFloat32(streamId)
    self.z = streamReadFloat32(streamId)
    self:run(connection);
end
function FarmKitChainMoveHookEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object);
	streamWriteFloat32(streamId, self.x)
	streamWriteFloat32(streamId, self.y)
	streamWriteFloat32(streamId, self.z)
end
function FarmKitChainMoveHookEvent:run(connection)
	if self.object ~= nil then
		self.object:moveHook(self.x, self.y, self.z, true)
	end
    if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
    end
end
function FarmKitChainMoveHookEvent.sendEvent(vehicle, x, y, z, noEventSend)
	if x ~= vehicle.x and y ~= vehicle.y and z ~= vehicle.z then
		if noEventSend == nil or noEventSend == false then
			if g_server ~= nil then
				g_server:broadcastEvent(FarmKitChainMoveHookEvent.new(vehicle, x, y, z), nil, nil, vehicle)
			else
				g_client:getServerConnection():sendEvent(FarmKitChainMoveHookEvent.new(vehicle, x, y, z))
			end
		end
	end
end