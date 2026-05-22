NXFarmKitHUD = NXFarmKitHUD or {}
NXFarmKitHUD.enabled = true

NXFarmKitHUD.installed = false

NXFarmKitHUD.SLIP_WARNING = 0.15
NXFarmKitHUD.SLIP_DANGER  = 0.20

NXFarmKitHUD.COLOR_NORMAL  = { 0.0,  1.0,  0.0,  1.0 }
NXFarmKitHUD.COLOR_WARNING = { 1.0,  0.85, 0.0,  1.0 }
NXFarmKitHUD.COLOR_DANGER  = { 1.0,  0.15, 0.15, 1.0 }
NXFarmKitHUD.COLOR_WET     = { 0.45, 0.70, 1.0,  1.0 }
NXFarmKitHUD.COLOR_STUCK   = { 1.0,  0.15, 0.15, 1.0 }

local function nxGetSlip()
    if NXRealisticWheelPhysics ~= nil and type(NXRealisticWheelPhysics.displaySlip) == "number" then
        return NXRealisticWheelPhysics.displaySlip
    end
    return 0
end

local function nxColorFor(slip)
    if slip >= NXFarmKitHUD.SLIP_DANGER  then return NXFarmKitHUD.COLOR_DANGER end
    if slip >= NXFarmKitHUD.SLIP_WARNING then return NXFarmKitHUD.COLOR_WARNING end
    return NXFarmKitHUD.COLOR_NORMAL
end

local function nxGetWetnessPct()
    if g_currentMission == nil or g_currentMission.environment == nil then return 0 end
    local weather = g_currentMission.environment.weather
    if weather == nil or weather.getGroundWetness == nil then return 0 end
    local ok, w = pcall(weather.getGroundWetness, weather)
    if not ok or type(w) ~= "number" then return 0 end
    if w < 0 then w = 0 elseif w > 1 then w = 1 end
    return math.floor(w * 100 + 0.5)
end

local function nxIsControlledPermaStuck(cv)
    if cv == nil or NXRealisticWheelPhysics == nil or NXRealisticWheelPhysics.getIsPermaStuck == nil then
        return false
    end
    local root = cv
    if cv.getRootVehicle ~= nil then root = cv:getRootVehicle() or cv end
    return NXRealisticWheelPhysics.getIsPermaStuck(root) == true
end

-- Renders one centered, drop-shadowed label.
local function nxRenderLabel(speedMeter, x, y, textSize, text, color)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextBold(true)

    local sx = speedMeter:scalePixelToScreenWidth(2)
    local sy = speedMeter:scalePixelToScreenHeight(2)
    setTextColor(0, 0, 0, 0.85)
    renderText(x + sx, y - sy, textSize, text)

    setTextColor(color[1], color[2], color[3], color[4])
    renderText(x, y, textSize, text)

    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    setTextBold(false)
end

local function nxDrawReadouts(self, speedMeter)
    if not NXFarmKitHUD.enabled then return end
    if speedMeter == nil then return end

    local cv = self.controlledVehicle
    if cv == nil then return end

    local bg = speedMeter.speedBg
    if bg == nil or bg.x == nil or bg.y == nil then return end

    local xOff, yOff = speedMeter:scalePixelValuesToScreenVector(32, 18)
    local x = bg.x + xOff
    local y = bg.y + yOff
    local textSize = speedMeter:scalePixelToScreenHeight(20)
    local lineGap  = speedMeter:scalePixelToScreenHeight(19)

    -- Wheel slip %
    local slip = nxGetSlip()
    nxRenderLabel(speedMeter, x, y, textSize,
        string.format("%d%%", math.floor(slip * 100 + 0.5)), nxColorFor(slip))

    -- Ground wetness % (one line above the slip readout)
    local wetSize = speedMeter:scalePixelToScreenHeight(15)
    nxRenderLabel(speedMeter, x, y + lineGap, wetSize,
        string.format("%d%% wet", nxGetWetnessPct()), NXFarmKitHUD.COLOR_WET)

    -- Perma-stuck warning (one more line above)
    if nxIsControlledPermaStuck(cv) then
        nxRenderLabel(speedMeter, x, y + lineGap * 2, wetSize,
            "STUCK - NEEDS TOW", NXFarmKitHUD.COLOR_STUCK)
    end
end

local function nxInstall()
    if NXFarmKitHUD.installed then return end
    if g_currentMission == nil or g_currentMission.hud == nil then return end

    local hud = g_currentMission.hud
    if hud.drawControlledEntityHUD == nil then return end

    hud.drawControlledEntityHUD = Utils.appendedFunction(hud.drawControlledEntityHUD, function(self)
        if not self.isVisible then return end
        NXFarmKitHUD.controlledVehicle = self.controlledVehicle
        nxDrawReadouts(self, self.speedMeter)
    end)

    NXFarmKitHUD.installed = true
end

if not rawget(_G, "_NXFarmKitHUD_bootstrapped") then
    _G._NXFarmKitHUD_bootstrapped = true
    Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, nxInstall)
end
