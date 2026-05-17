NXFarmKitHUD = NXFarmKitHUD or {}
NXFarmKitHUD.enabled = true

NXFarmKitHUD.installed = false

NXFarmKitHUD.SLIP_WARNING = 0.15
NXFarmKitHUD.SLIP_DANGER  = 0.20

NXFarmKitHUD.COLOR_NORMAL  = { 0.0,  1.0,  0.0,  1.0 }
NXFarmKitHUD.COLOR_WARNING = { 1.0,  0.85, 0.0,  1.0 }
NXFarmKitHUD.COLOR_DANGER  = { 1.0,  0.15, 0.15, 1.0 }

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

local function nxDrawSlipReadout(self, speedMeter)
    if not NXFarmKitHUD.enabled then return end
    if speedMeter == nil then return end

    local cv = self.controlledVehicle
    if cv == nil then return end

    local bg = speedMeter.speedBg
    if bg == nil or bg.x == nil or bg.y == nil then return end

    local slip = nxGetSlip()
    local pct = math.floor(slip * 100 + 0.5)

    local xOff, yOff = speedMeter:scalePixelValuesToScreenVector(32, 18)
    local x = bg.x + xOff
    local y = bg.y + yOff
    local textSize = speedMeter:scalePixelToScreenHeight(20)

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextBold(true)

    local sx = speedMeter:scalePixelToScreenWidth(2)
    local sy = speedMeter:scalePixelToScreenHeight(2)
    setTextColor(0, 0, 0, 0.85)
    renderText(x + sx, y - sy, textSize, string.format("%d%%", pct))

    local r, g, b, a = unpack(nxColorFor(slip))
    setTextColor(r, g, b, a)
    renderText(x, y, textSize, string.format("%d%%", pct))

    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    setTextBold(false)
end

local function nxInstall()
    if NXFarmKitHUD.installed then return end
    if g_currentMission == nil or g_currentMission.hud == nil then return end

    local hud = g_currentMission.hud
    if hud.drawControlledEntityHUD == nil then return end

    hud.drawControlledEntityHUD = Utils.appendedFunction(hud.drawControlledEntityHUD, function(self)
        if not self.isVisible then return end
        NXFarmKitHUD.controlledVehicle = self.controlledVehicle
        nxDrawSlipReadout(self, self.speedMeter)
    end)

    NXFarmKitHUD.installed = true
    print("[FS25_FarmKit] HUD: slip readout attached")
end

if not rawget(_G, "_NXFarmKitHUD_bootstrapped") then
    _G._NXFarmKitHUD_bootstrapped = true
    Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, nxInstall)
end
