NXFarmKitHUD = NXFarmKitHUD or {}
NXFarmKitHUD.enabled = true
NXFarmKitHUD.installed   = false
NXFarmKitHUD.overlaysBuilt = false

NXFarmKitHUD.SLIP_WARNING = 0.15
NXFarmKitHUD.SLIP_DANGER  = 0.20

NXFarmKitHUD.COLOR_NORMAL  = { 0.0,  1.0,  0.0,  1.0 }
NXFarmKitHUD.COLOR_WARNING = { 1.0,  0.85, 0.0,  1.0 }
NXFarmKitHUD.COLOR_DANGER  = { 1.0,  0.15, 0.15, 1.0 }
NXFarmKitHUD.COLOR_WET     = { 0.55, 0.78, 1.0,  1.0 }
NXFarmKitHUD.COLOR_RAIN    = { 0.70, 0.85, 1.0,  1.0 }
NXFarmKitHUD.COLOR_NEUTRAL = { 0.95, 0.95, 0.95, 1.0 }
NXFarmKitHUD.COLOR_ICON    = { 1.0,  1.0,  1.0,  0.95 }
NXFarmKitHUD.COLOR_STUCK   = { 1.0,  0.15, 0.15, 1.0 }

NXFarmKitHUD.gapToGameInfoPx = 60
NXFarmKitHUD.segmentGapPx    = 14
NXFarmKitHUD.textSizePx      = 17
NXFarmKitHUD.baselineLiftPx  = 4
NXFarmKitHUD.iconSizePx      = 18
NXFarmKitHUD.iconTextPadPx   = 6

NXFarmKitHUD.wetIconFilename  = "gui/wet.dds"
NXFarmKitHUD.rainIconFilename = "gui/rain.dds"
NXFarmKitHUD.modDirectory     = g_currentModDirectory or NXFarmKitHUD.modDirectory or ""

NXFarmKitHUD.bgEnable    = true
NXFarmKitHUD.bgAlpha     = 0.45
NXFarmKitHUD.bgPadXPx    = 10
NXFarmKitHUD.bgPadYPx    = 4
NXFarmKitHUD.bgCapWidthPx = 10

local DAY_LENGTH_MS = 86400000

local function clamp01(v)
    if v ~= v or v == nil then return 0 end
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function safeNumber(obj, fn, default)
    if obj == nil or fn == nil then return default end
    local ok, v = pcall(fn, obj)
    if ok and type(v) == "number" then return v end
    return default
end

local function nxGetWeather()
    if g_currentMission ~= nil and g_currentMission.environment ~= nil then
        return g_currentMission.environment.weather
    end
    return nil
end

local function nxGetSlip()
    if NXRealisticWheelPhysics ~= nil and type(NXRealisticWheelPhysics.displaySlip) == "number" then
        return NXRealisticWheelPhysics.displaySlip
    end
    return 0
end

local function nxColorForSlip(slip)
    if slip >= NXFarmKitHUD.SLIP_DANGER  then return NXFarmKitHUD.COLOR_DANGER end
    if slip >= NXFarmKitHUD.SLIP_WARNING then return NXFarmKitHUD.COLOR_WARNING end
    return NXFarmKitHUD.COLOR_NORMAL
end

local function nxGetWetness()
    local w = nxGetWeather()
    if w == nil then return 0 end
    return clamp01(safeNumber(w, w.getGroundWetness, 0))
end

local function nxGetPrecipScale()
    local w = nxGetWeather()
    if w == nil then return 0 end
    local rain = clamp01(safeNumber(w, w.getRainFallScale, 0))
    local snow = clamp01(safeNumber(w, w.getSnowFallScale, 0))
    local hail = clamp01(safeNumber(w, w.getHailFallScale, 0))
    return math.max(rain, snow, hail)
end

local function nxIsPrecipType(wt)
    if wt == nil or WeatherType == nil then return false end
    if WeatherType.RAIN ~= nil and wt == WeatherType.RAIN then return true end
    if WeatherType.SNOW ~= nil and wt == WeatherType.SNOW then return true end
    if WeatherType.HAIL ~= nil and wt == WeatherType.HAIL then return true end
    return false
end

local function nxPrecipTypeName(wt)
    if wt == nil or WeatherType == nil then return nil end
    if WeatherType.RAIN ~= nil and wt == WeatherType.RAIN then return "Rain" end
    if WeatherType.SNOW ~= nil and wt == WeatherType.SNOW then return "Snow" end
    if WeatherType.HAIL ~= nil and wt == WeatherType.HAIL then return "Hail" end
    return nil
end

local function nxFmtCountdown(ms)
    if ms == nil or ms == math.huge or ms < 0 then return nil end
    local totalMin = math.floor(ms / 60000 + 0.5)
    local h = math.floor(totalMin / 60)
    local m = totalMin - h * 60
    if h > 0 then
        return string.format("%dh %02dm", h, m)
    end
    return string.format("%dm", m)
end

local function nxGetTimeUntilNextPrecip()
    local weather = nxGetWeather()
    if weather == nil or weather.forecastItems == nil then return math.huge, nil end
    local env = weather.owner
    if env == nil or env.currentMonotonicDay == nil or env.dayTime == nil then return math.huge, nil end

    local curDay  = env.currentMonotonicDay
    local curTime = env.dayTime

    for i = 1, #weather.forecastItems do
        local inst = weather.forecastItems[i]
        if inst ~= nil and inst.startDay ~= nil and inst.startDayTime ~= nil then
            local obj = nil
            if weather.getWeatherObjectByIndex ~= nil then
                local ok, o = pcall(weather.getWeatherObjectByIndex, weather, inst.season, inst.objectIndex)
                if ok then obj = o end
            end
            local wt = obj ~= nil and obj.weatherType or nil
            if nxIsPrecipType(wt) then
                local dt = (inst.startDay - curDay) * DAY_LENGTH_MS + (inst.startDayTime - curTime)
                if dt > 0 then return dt, wt end
            end
        end
    end
    return math.huge, nil
end

local function nxGetTimeUntilCurrentPrecipEnds()
    local weather = nxGetWeather()
    if weather == nil or weather.forecastItems == nil or #weather.forecastItems == 0 then return math.huge, nil end
    local env = weather.owner
    if env == nil or env.currentMonotonicDay == nil or env.dayTime == nil or env.getDayAndDayTime == nil then return math.huge, nil end

    local inst = weather.forecastItems[1]
    if inst == nil or inst.startDay == nil or inst.startDayTime == nil or inst.duration == nil then
        return math.huge, nil
    end

    local obj = nil
    if weather.getWeatherObjectByIndex ~= nil then
        local ok, o = pcall(weather.getWeatherObjectByIndex, weather, inst.season, inst.objectIndex)
        if ok then obj = o end
    end
    local wt = obj ~= nil and obj.weatherType or nil
    if not nxIsPrecipType(wt) then return math.huge, nil end

    local endDay, endDayTime = env:getDayAndDayTime(inst.startDayTime + inst.duration, inst.startDay)
    if endDay == nil or endDayTime == nil then return math.huge, wt end

    local dt = (endDay - env.currentMonotonicDay) * DAY_LENGTH_MS + (endDayTime - env.dayTime)
    return math.max(0, dt), wt
end

local function nxIsControlledPermaStuck(cv)
    if cv == nil or NXRealisticWheelPhysics == nil or NXRealisticWheelPhysics.getIsPermaStuck == nil then return false end
    local root = cv
    if cv.getRootVehicle ~= nil then root = cv:getRootVehicle() or cv end
    return NXRealisticWheelPhysics.getIsPermaStuck(root) == true
end

local function nxTryCreateOverlay(name)
    if g_overlayManager == nil or g_overlayManager.createOverlay == nil then return nil end
    local ok, ov = pcall(g_overlayManager.createOverlay, g_overlayManager, name, 0, 0, 0, 0)
    if not ok or ov == nil then return nil end
    return ov
end

local function nxLoadIcon(modDir, relPath)
    if relPath == nil or modDir == nil then return nil end
    local path = Utils.getFilename(relPath, modDir)
    if path == nil or path == "" then return nil end
    local ok, ov = pcall(Overlay.new, path, 0, 0, 0, 0)
    if not ok or ov == nil then return nil end
    return ov
end

function NXFarmKitHUD:buildOverlays()
    if self.overlaysBuilt then return end
    self.overlaysBuilt = true

    -- Weather glyphs (wet droplet + rain cloud). Bundled with the mod by permission
    -- from U_BMP / BioMod Production — see README credits.
    self.wetIcon  = nxLoadIcon(self.modDirectory, self.wetIconFilename)
    self.rainIcon = nxLoadIcon(self.modDirectory, self.rainIconFilename)

    if self.bgEnable then
        self.bgLeft   = nxTryCreateOverlay("gui.gameInfo_left")
        self.bgMiddle = nxTryCreateOverlay("gui.gameInfo_middle")
        self.bgRight  = nxTryCreateOverlay("gui.gameInfo_right")
        local a = self.bgAlpha or 0.45
        if self.bgLeft   ~= nil then self.bgLeft  :setColor(0, 0, 0, a) end
        if self.bgMiddle ~= nil then self.bgMiddle:setColor(0, 0, 0, a) end
        if self.bgRight  ~= nil then self.bgRight :setColor(0, 0, 0, a) end
    end
end

local function nxRenderShadowedText(x, y, size, text, color, shadowDX, shadowDY)
    setTextColor(0, 0, 0, 0.85)
    renderText(x + shadowDX, y - shadowDY, size, text)
    setTextColor(color[1], color[2], color[3], color[4])
    renderText(x, y, size, text)
end

function NXFarmKitHUD:render(gameInfoDisplay)
    if not self.enabled then return end
    if gameInfoDisplay == nil or gameInfoDisplay.getPosition == nil then return end

    local hud = g_currentMission and g_currentMission.hud
    if hud ~= nil then
        if hud.getIsVisible ~= nil then
            if not hud:getIsVisible() then return end
        elseif hud.isVisible ~= nil and not hud.isVisible then
            return
        end
    end
    if gameInfoDisplay.getVisible ~= nil and not gameInfoDisplay:getVisible() then return end

    self:buildOverlays()

    local cv = nil
    if g_currentMission ~= nil and g_currentMission.controlledVehicle ~= nil then
        cv = g_currentMission.controlledVehicle
    elseif g_localPlayer ~= nil and g_localPlayer.controlledVehicle ~= nil then
        cv = g_localPlayer.controlledVehicle
    end
    self.controlledVehicle = cv

    local sW = function(px)
        if gameInfoDisplay.scalePixelToScreenWidth ~= nil then
            return gameInfoDisplay:scalePixelToScreenWidth(px)
        end
        return px / 1920
    end
    local sH = function(px)
        if gameInfoDisplay.scalePixelToScreenHeight ~= nil then
            return gameInfoDisplay:scalePixelToScreenHeight(px)
        end
        return px / 1080
    end

    local gidX, gidY = gameInfoDisplay:getPosition()
    local gapX        = sW(self.gapToGameInfoPx)
    local segGap      = sW(self.segmentGapPx)
    local iconW       = sW(self.iconSizePx)
    local iconH       = sH(self.iconSizePx)
    local iconTextPad = sW(self.iconTextPadPx)
    local bgPadX      = sW(self.bgPadXPx)
    local bgPadY      = sH(self.bgPadYPx)
    local capW        = sW(self.bgCapWidthPx)
    local textSize    = gameInfoDisplay.clockTextSize or sH(self.textSizePx)
    local baselineY   = gidY + sH(self.baselineLiftPx)
    local shadowDX    = sW(1)
    local shadowDY    = sH(1)

    local segments = {}

    do
        local slip = nxGetSlip()
        segments[#segments + 1] = {
            text  = string.format("SLIP %d%%", math.floor(slip * 100 + 0.5)),
            color = nxColorForSlip(slip)
        }
        if cv ~= nil and nxIsControlledPermaStuck(cv) then
            segments[#segments + 1] = { text = "[STUCK]", color = NXFarmKitHUD.COLOR_STUCK }
        end
    end

    local wetPct = nxGetWetness()
    do
        local wetTxt = string.format("%d%%", math.floor(wetPct * 100 + 0.5))
        if self.wetIcon ~= nil then
            segments[#segments + 1] = { text = wetTxt, color = NXFarmKitHUD.COLOR_WET, icon = self.wetIcon }
        else
            segments[#segments + 1] = { text = "WET " .. wetTxt, color = NXFarmKitHUD.COLOR_WET }
        end
    end

    local precip = nxGetPrecipScale()
    do
        local rainTxt = string.format("%d%%", math.floor(precip * 100 + 0.5))
        if self.rainIcon ~= nil then
            segments[#segments + 1] = { text = rainTxt, color = NXFarmKitHUD.COLOR_RAIN, icon = self.rainIcon }
        else
            segments[#segments + 1] = { text = "RAIN " .. rainTxt, color = NXFarmKitHUD.COLOR_RAIN }
        end
    end

    local isPrecipNow = precip > 0.05
    local countdownText
    if isPrecipNow then
        local dt, wt = nxGetTimeUntilCurrentPrecipEnds()
        local cd = nxFmtCountdown(dt)
        if cd ~= nil then
            local tn = nxPrecipTypeName(wt) or "Rain"
            countdownText = string.format("\226\134\144 %s (%s)", cd, tn)
        end
    else
        local dt, wt = nxGetTimeUntilNextPrecip()
        local cd = nxFmtCountdown(dt)
        if cd ~= nil then
            local tn = nxPrecipTypeName(wt)
            if tn ~= nil then
                countdownText = string.format("\226\134\146 %s (%s)", cd, tn)
            else
                countdownText = string.format("\226\134\146 %s", cd)
            end
        end
    end
    if countdownText ~= nil then
        segments[#segments + 1] = { text = countdownText, color = NXFarmKitHUD.COLOR_NEUTRAL }
    end

    if #segments == 0 then return end

    setTextBold(true)
    local totalContentW = 0
    for i, seg in ipairs(segments) do
        local w = getTextWidth(textSize, seg.text)
        if seg.icon ~= nil then
            w = iconW + iconTextPad + w
        end
        seg.measuredW = w
        totalContentW = totalContentW + w
    end
    totalContentW = totalContentW + segGap * math.max(0, #segments - 1)

    local contentRight = gidX - gapX
    local contentLeft  = contentRight - totalContentW

    if self.bgEnable and self.bgLeft ~= nil and self.bgMiddle ~= nil and self.bgRight ~= nil then
        local panelW = totalContentW + bgPadX * 2
        local panelH = math.max(iconH, textSize) + bgPadY * 2
        local panelLeft = contentLeft - bgPadX
        local panelY    = baselineY - sH(2)
        local midX      = panelLeft + capW
        local midW      = math.max(0, panelW - capW * 2)
        local rightX    = panelLeft + panelW - capW

        if self.bgLeft.setPosition  ~= nil then self.bgLeft  :setPosition(panelLeft, panelY) end
        if self.bgLeft.setDimension ~= nil then self.bgLeft  :setDimension(capW,      panelH) end
        if self.bgLeft.render       ~= nil then self.bgLeft  :render() end

        if self.bgMiddle.setPosition  ~= nil then self.bgMiddle:setPosition(midX, panelY) end
        if self.bgMiddle.setDimension ~= nil then self.bgMiddle:setDimension(midW, panelH) end
        if self.bgMiddle.render       ~= nil then self.bgMiddle:render() end

        if self.bgRight.setPosition  ~= nil then self.bgRight :setPosition(rightX, panelY) end
        if self.bgRight.setDimension ~= nil then self.bgRight :setDimension(capW,   panelH) end
        if self.bgRight.render       ~= nil then self.bgRight :render() end
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)

    local x = contentLeft
    for i, seg in ipairs(segments) do
        if seg.icon ~= nil then
            local iconY = baselineY + textSize * 0.35 - iconH * 0.5
            seg.icon:setColor(NXFarmKitHUD.COLOR_ICON[1], NXFarmKitHUD.COLOR_ICON[2], NXFarmKitHUD.COLOR_ICON[3], NXFarmKitHUD.COLOR_ICON[4])
            if seg.icon.setPosition  ~= nil then seg.icon:setPosition(x, iconY) end
            if seg.icon.setDimension ~= nil then seg.icon:setDimension(iconW, iconH) end
            if seg.icon.render       ~= nil then seg.icon:render() end

            local textX = x + iconW + iconTextPad
            nxRenderShadowedText(textX, baselineY, textSize, seg.text, seg.color, shadowDX, shadowDY)
        else
            nxRenderShadowedText(x, baselineY, textSize, seg.text, seg.color, shadowDX, shadowDY)
        end
        x = x + seg.measuredW + segGap
    end

    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
end

local function nxInstall()
    if NXFarmKitHUD.installed then return end
    if g_currentMission == nil or g_currentMission.hud == nil then return end

    local gid = g_currentMission.hud.gameInfoDisplay
    if gid == nil or gid.draw == nil then return end

    gid.draw = Utils.appendedFunction(gid.draw, function(self)
        NXFarmKitHUD:render(self)
    end)

    NXFarmKitHUD.installed = true
end

if not rawget(_G, "_NXFarmKitHUD_bootstrapped") then
    _G._NXFarmKitHUD_bootstrapped = true
    Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, nxInstall)
end
