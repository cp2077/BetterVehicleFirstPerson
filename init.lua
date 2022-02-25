local BetterVehicleFirstPerson = { version = "1.4.0" }
local Config = require("Modules/Config")
local GameSession = require("Modules/GameSession")
local Cron = require("Modules/Cron")
local GameSettings = require("Modules/GameSettings")

local initialFOV = 51
local initialSensitivity = 50

local enabled = true
local disabledByApi = false
local isInGame = false

local isInVehicle = false
local curVehicle = nil
local isYFlipped = false

local API = {}

function API.Enable()
  enabled = true
  RefreshCameraIfNeeded()
end

function API.Disable()
  enabled = false
  RefreshCameraIfNeeded()
end

function API.IsEnabled()
  return enabled
end

function IsEnteringVehicle()
    return IsInVehicle() and Game.GetWorkspotSystem():GetExtendedInfo(Game.GetPlayer()).entering
end
function IsExitingVehicle()
    return IsInVehicle() and Game.GetWorkspotSystem():GetExtendedInfo(Game.GetPlayer()).exiting
end

function IsInVehicle()
    local player = Game.GetPlayer()
    return player and Game.GetWorkspotSystem():IsActorInWorkspot(player)
            and Game.GetWorkspotSystem():GetExtendedInfo(player).isActive
            and HasMountedVehicle()
            and IsPlayerDriver()
end

function SetFOV(fov)
    if fov ~= nil then
        Config.data.fov = fov
    end

    Game.GetPlayer():GetFPPCameraComponent():SetFOV(Config.data.fov)
end
function GetFOV()
    return Game.GetPlayer():GetFPPCameraComponent():GetFOV()
end
function ResetFOV()
    Game.GetPlayer():GetFPPCameraComponent():SetFOV(initialFOV)
end

function ChangeSensitivity(sensitivity)
	if sensitivity ~= nil then
		Config.data.sensitivity = sensitivity
	end

	GameSettings.Set('/controls/SteeringSensitivity', Config.data.sensitivity)
end
function ResetSensitivity()
	return ChangeSensitivity(initialSensitivity)
end


function TiltCamera()
    Game.GetPlayer():GetFPPCameraComponent():SetLocalOrientation(Quaternion.new((-0.06 * Config.data.tiltMult), 0.0, 0.0, 1.0))
end
function ResetTilt()
    Game.GetPlayer():GetFPPCameraComponent():SetLocalOrientation(Quaternion.new(0.00, 0.0, 0.0, 1.0))
end

function RaiseCamera()
    Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Vector4.new(0.0, -(0.02 * Config.data.zMult), (0.09 * Config.data.yMult), 1.0))
end
function ResetCamera()
    Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Vector4.new(0.0, 0, 0, 1.0))
end

function FlipY()
	GameSettings.Toggle('/controls/fppcameramouse/FPP_MouseInvertY')
	GameSettings.Toggle('/controls/fppcamerapad/FPP_PadInvertY')
    isYFlipped = not isYFlipped
end
function DoubleCheckY()
	if isYFlipped then
		GameSettings.Toggle('/controls/fppcameramouse/FPP_MouseInvertY')
		GameSettings.Toggle('/controls/fppcamerapad/FPP_PadInvertY')
		isYFlipped = false
    end
end

function StartPeek()
    local player = Game.GetPlayer()
    local vehicle = Game['GetMountedVehicle;GameObject'](player)
    if vehicle then
        if not Game.GetPlayer():FindVehicleCameraManager():IsTPPActive() then
			player:QueueEvent(NewObject('handle:vehicleCameraResetEvent'))
		end
    end

    Game.GetPlayer():GetFPPCameraComponent():SetLocalOrientation(Quaternion.new(0.0, 0.0, 100, 1.0))
    Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Vector4.new(-0.6, 0.0, 0.01, 1.0))
    FlipY()
end
function StopPeek()
    local player = Game.GetPlayer()
    local vehicle = Game['GetMountedVehicle;GameObject'](player)
    if vehicle then
        if not Game.GetPlayer():FindVehicleCameraManager():IsTPPActive() then
            player:QueueEvent(NewObject('handle:vehicleCameraResetEvent'))
        end
    end

    FlipY()
    DoubleCheckY()
    if enabled then
        TiltCamera()
        RaiseCamera()
    else
        Game.GetPlayer():GetFPPCameraComponent():SetLocalOrientation(Quaternion.new(0.0, 0.0, 0, 1.0))
        Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Vector4.new(0.0, 0.0, 0.0, 1.0))
    end
end

function SaveConfig()
    Config.SaveConfig()
    DoubleCheckY()
end

function HasMountedVehicle()
    return not not Game['GetMountedVehicle;GameObject'](Game.GetPlayer())
end
function IsPlayerDriver()
    local veh = Game['GetMountedVehicle;GameObject'](Game.GetPlayer())
    if veh then
        return veh:IsPlayerDriver()
    end
end
function GetMountedVehicleRecord()
    local veh = Game['GetMountedVehicle;GameObject'](Game.GetPlayer())
    if veh then
        return veh:GetRecord()
    end
end

function IsPlayerDriver()
    local veh = Game['GetMountedVehicle;GameObject'](Game.GetPlayer())
    if veh then
        return veh:IsPlayerDriver()
    end
end

function GetCurrentPreset()
    return { Config.data.tiltMult, Config.data.yMult, Config.data.zMult, Config.data.fov, Config.data.sensitivity}
end

function GetVehicleMan(vehicle)
    return vehicle:Manufacturer():Type().value
end
function GetVehicleModel(vehicle)
    return vehicle:Model():Type().value
end

function SetGlobalPreset()
    local gKey = ("global_preset")
    local gPreset = {
        ["man"] = "global",
        ["model"] = "n/a",
        ["preset"] = GetCurrentPreset()
    }

    Config.data.perCarPresets[gKey] = gPreset

    SaveConfig()
end

function AddVehiclePreset()
    local vehicle = curVehicle or GetMountedVehicleRecord()

    local vehMan = GetVehicleMan(vehicle)
    local vehModel = GetVehicleModel(vehicle)
    local vehKey = (vehMan .. vehModel)
    local vehPreset = {
        ["man"] = vehMan,
        ["model"] = vehModel,
        ["preset"] = GetCurrentPreset()
    }

    Config.data.perCarPresets[vehKey] = vehPreset

    SaveConfig()
end

function GetGlobalPreset()
    local gKey = "global_preset"
    local gPreset = Config.data.perCarPresets[gKey]

    if gPreset then
        return gPreset.preset
    end

    return nil
end

function GetVehiclePreset(vehicle)
    if not vehicle then
        return nil
    end

    local vehMan = GetVehicleMan(vehicle)
    local vehModel = GetVehicleModel(vehicle)
    local vehKey = (vehMan .. vehModel)
    local vehPreset = Config.data.perCarPresets[vehKey]
    if vehPreset then
        --catch error?
        --if vehPreset.preset[5] == nil then
        --	vehPreset.preset[5] = initialSensitivity
        --end
        --
        --^ is obsolete, I added iteration through all car presets
        --in Config.lua - Migrate() function
        return vehPreset.preset
    end

    return nil
end

function ApplyAutoPreset()
    local vehicle = GetMountedVehicleRecord()
    curVehicle = vehicle

    if Config.data.autoSetPerCar then
        local preset = GetVehiclePreset(vehicle)
        local gPreset = GetGlobalPreset()

        if preset then
            ApplyPreset(preset)
            RefreshCameraIfNeeded()
        elseif gPreset then
            ApplyPreset(gPreset)
            RefreshCameraIfNeeded()
        end
    else
        local gPreset = GetGlobalPreset()
        if gPreset then
            ApplyPreset(gPreset)
            RefreshCameraIfNeeded()
        end
    end
end

function OnVehicleEntered()
    initialSensitivity = GameSettings.Get('/controls/SteeringSensitivity')

    ApplyAutoPreset()

    -- TODO: is this ever changing for different players?
    -- initialFOV = GetFOV()
    if not enabled then
        return
    end

    TiltCamera()
    RaiseCamera()

    SetFOV()

    ChangeSensitivity()
end

function OnVehicleEntering()
    if not enabled then
        ResetCamera()
        ResetTilt()
        return
    end

    TiltCamera()
    RaiseCamera()
end

function OnVehicleExiting()
    ResetCamera()
    ResetTilt()
    ResetFOV()
    ResetSensitivity()
    curVehicle = nil
end

function OnVehicleExited()
    if enabled then
        ResetCamera()
        ResetTilt()
        ResetSensitivity()
    end
end

function RefreshCameraIfNeeded()
    SaveConfig()
    if isInVehicle and enabled then
        TiltCamera()
        RaiseCamera()
        SetFOV()
        ChangeSensitivity()
    elseif isInVehicle and not enabled then
        ResetCamera()
        ResetTilt()
        ResetFOV()
        ResetSensitivity()
    end
end

local presets = {
    -- default
    { 1.150, 0.9, -0.2, 56, 50 },
    { 1.050, 0.8, -3.810, 58, 50 },
    { 1.170, 0.810, 7, 49, 50 },
    { 0.950, 0.610, -10, 70, 50 },
    { 0.950, 0.500, -13, 87, 50 },
    -- car-specific
    -- ...
}

function IsSamePreset(pr)
    return math.abs(Config.data.tiltMult - pr[1]) < 0.01 and
            math.abs(Config.data.yMult - pr[2]) < 0.01 and
            math.abs(Config.data.zMult - pr[3]) < 0.01 and
            math.abs(Config.data.fov - pr[4]) < 0.01 and
            math.abs(Config.data.sensitivity - pr[5]) < 0.01
end

function DeletePreset(key)
    Config.data.perCarPresets[key] = nil
    SaveConfig()
end
function ApplyPreset(pr)
    Config.data.tiltMult = pr[1]
    Config.data.yMult = pr[2]
    Config.data.zMult = pr[3]
    Config.data.fov = pr[4]
    Config.data.sensitivity = pr[5]
end


function BetterVehicleFirstPerson:New()
    registerForEvent("onInit", function()
        initialSensitivity = GameSettings.Get('/controls/SteeringSensitivity')
        Config.InitConfig()

        Cron.Every(0.2, function()
            if not enabled then
              return
            end

            if not Config or not Config.isReady then
                return
            end

            if not isInGame then
              return
            end

            local isInVehicleNext = IsInVehicle() and not IsEnteringVehicle() and not IsExitingVehicle()

            if IsEnteringVehicle() then
                OnVehicleEntering()
            elseif IsExitingVehicle() then
                OnVehicleExiting()
            elseif isInVehicleNext == true and isInVehicle == false then
                OnVehicleEntered()
            elseif isInVehicleNext == false and isInVehicle == true then
                OnVehicleExited()
            end

            isInVehicle = isInVehicleNext
        end)

        Observe('hudCarController', 'RegisterToVehicle', function(_, registered)
            if not registered then
                OnVehicleExited()
            end
        end)

        -- Fires with loaded save file too
        Observe('hudCarController', 'OnPlayerAttach', function()
            if isInVehicle and enabled then
                RefreshCameraIfNeeded()
            end
        end)

        -- Fires when execting
        Observe('hudCarController', 'OnUnmountingEvent', function()
            OnVehicleExited()
        end)

        GameSession.OnStart(function()
          isInGame = true
        end)

        GameSession.OnEnd(function()
          isInGame = false
        end)

        GameSession.OnPause(function()
          isInGame = false
        end)

        GameSession.OnResume(function()
          isInGame = true
        end)
    end)

    registerForEvent("onOverlayOpen", function() isOverlayOpen = true end)
    registerForEvent("onOverlayClose", function() isOverlayOpen = false end)

    registerForEvent("onUpdate", function(delta)
        Cron.Update(delta)
    end)

    registerInput("peek", "Peek Through Window", function(keydown)
        if not IsInVehicle() then
            DoubleCheckY()
            return
        end

        if keydown then
            StartPeek()
        else
            StopPeek()
        end
    end)
    registerHotkey("VehicleFPPCameraEnabled", "Toggle Enabled", function()
        if isInVehicle then
            enabled = not enabled
            RefreshCameraIfNeeded()
        end
    end)

    registerForEvent("onDraw", function()
        if not isOverlayOpen or not Config or not Config.isReady then
            return
        end

        ImGui.PushStyleVar(ImGuiStyleVar.WindowMinSize, 300, 40)
        ImGui.PushStyleColor(ImGuiCol.Border, 0, 0, 0, 0)
        ImGui.PushStyleColor(ImGuiCol.TitleBg, 0, 0, 0, 0.8)
        ImGui.PushStyleColor(ImGuiCol.TitleBgActive, 0, 0, 0, 0.8)
        ImGui.PushStyleColor(ImGuiCol.WindowBg, 0, 0, 0, 0.8)
        ImGui.PushStyleColor(ImGuiCol.Button, 0.25, 0.35, 0.45, 0.8)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.35, 0.45, 0.55, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.35, 0.45, 0.5)
        ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.25, 0.35, 0.45, 0.8)

        ImGui.Begin("VehicleFPPCamera", ImGuiWindowFlags.AlwaysAutoResize)
        ImGui.SetWindowFontScale(1)

        -- toggle enabled
        enabled, toggleEnabled = ImGui.Checkbox("Enabled", enabled)
        if toggleEnabled then
            RefreshCameraIfNeeded()
        end

        if enabled and isInVehicle then
			local globalVehiclePreset = GetGlobalPreset()
            local curVehiclePreset = GetVehiclePreset(GetMountedVehicleRecord())
            if not curVehiclePreset or not IsSamePreset(curVehiclePreset) then
                --ImGui.PushStyleColor(ImGuiCol.Text, 0.60, 0.40, 0.20, 1.0)
                ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.53, 0.14, 1.0)

				if not globalVehiclePreset then
					ImGui.Text(" THESE VALUES HAVEN'T YET BEEN SAVED ")
				else
					if not IsSamePreset(globalVehiclePreset) then
						ImGui.Text(" THESE VALUES HAVEN'T YET BEEN SAVED ")
					else
						ImGui.Text("")
					end
				end

                ImGui.PopStyleColor(1)
            else
                ImGui.Text("")
            end

            -- Tilt control
            -- luacheck:ignore lowercase-global
            Config.data.tiltMult, isTiltChanged = ImGui.DragFloat(" Tilt Multiplier ", Config.data.tiltMult, 0.01, -1, 5)
            if isTiltChanged then
                RefreshCameraIfNeeded()
            end

            -- Y control
            Config.data.yMult, isYChanged = ImGui.DragFloat(" Y Multiplier ", Config.data.yMult, 0.01, -2, 3)
            if isYChanged then
                RefreshCameraIfNeeded()
            end

            -- Z control
            Config.data.zMult, isZChanged = ImGui.DragFloat(" Z Multiplier ", Config.data.zMult, 0.01, -70, 15)
            if isZChanged then
                RefreshCameraIfNeeded()
            end

            -- FOV control
            Config.data.fov, isFovChanged = ImGui.DragFloat(" FOV ", Config.data.fov, 1, 30, 95)
            if isFovChanged then
                RefreshCameraIfNeeded()
            end

			-- Sensitivity control
			Config.data.sensitivity, isSensitivityChanged = ImGui.DragFloat(" Steering sensitivity ", Config.data.sensitivity, 1, 0, 100)
			if isSensitivityChanged then
                RefreshCameraIfNeeded()
			end

            -- Predefined presets
            ImGui.Text("Built-in presets: ")
            if ImGui.SmallButton(" 1 ") then
                ApplyPreset(presets[1])
                RefreshCameraIfNeeded()
            end
            ImGui.SameLine()
            if ImGui.SmallButton(" 2 ") then
                ApplyPreset(presets[2])
                RefreshCameraIfNeeded()
            end
            ImGui.SameLine()
            if ImGui.SmallButton(" 3 ") then
                ApplyPreset(presets[3])
                RefreshCameraIfNeeded()
            end
            ImGui.SameLine()
            if ImGui.SmallButton(" 4 ") then
                ApplyPreset(presets[4])
                RefreshCameraIfNeeded()
            end
            ImGui.SameLine()
            if ImGui.SmallButton(" 5 ") then
                ApplyPreset(presets[5])
                RefreshCameraIfNeeded()
            end
            ImGui.Text("")
            ImGui.Separator()

            -- Save global preset
            if not globalVehiclePreset then
                ImGui.Text("")
                ImGui.Text(" The global preset ")
                ImGui.Text(" hasn't been established yet. ")
                ImGui.Text("")
                if ImGui.Button((" Save as new global preset ")) then
                    SetGlobalPreset()
                end

                ImGui.Text("")
                ImGui.Separator()
            else
                if not IsSamePreset(globalVehiclePreset) then
                    local function CurSetupIsDiffMsg()
                        ImGui.Text("")
                        ImGui.Text(" Current setup is different from the global preset. ")
                    end
                    if curVehiclePreset then
                        if IsSamePreset(curVehiclePreset) then
                            ImGui.Text("")
                            ImGui.Text(" Vehicle preset overrides the global preset. ")
                        else
                            CurSetupIsDiffMsg()
                        end
                    else
                        CurSetupIsDiffMsg()
                    end

                    -- Save global preset
                    if ImGui.Button((" Save global preset ")) then
                        SetGlobalPreset()
                    end

                    -- Reset global preset
                    if ImGui.Button((" Load global preset ")) then
                        ApplyPreset(globalVehiclePreset)
                        RefreshCameraIfNeeded()
                    end
                else
                    local function globPresetHasBeenLoadedMsg()
                        ImGui.Text("")
                        ImGui.Text(" The global preset has been loaded! ")
                    end
                    if curVehiclePreset then
                        if IsSamePreset(curVehiclePreset) then
                            ImGui.Text("")
                            ImGui.Text(" The global and vehicle presets are the same")
                        else
                            globPresetHasBeenLoadedMsg()
                        end
                    else
                        globPresetHasBeenLoadedMsg()
                    end

                end

                ImGui.Text("")
                ImGui.Separator()
            end
            ImGui.Text("")

            -- Presets manager
            if curVehicle then
                local carName = GetVehicleMan(curVehicle) .. " " .. GetVehicleModel(curVehicle)

                -- "You're driving %CarName%" message
                ImGui.Text(" You're driving ")
                ImGui.SameLine()
                ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.86, 0.47, 1.0)
                ImGui.Text(("%q "):format(carName))
                ImGui.PopStyleColor(1)

                -- Save preset for a vehicle
                if curVehiclePreset then
                    if not IsSamePreset(curVehiclePreset) then
                        if ImGui.Button((" Save %q preset "):format(carName)) then
                            AddVehiclePreset()
                        end
                    else
                        ImGui.Text(" The vehicle preset has been loaded ")
                    end
                else
                    if ImGui.Button((" Save as new %q preset "):format(carName)) then
                        AddVehiclePreset()
                    end
                end

                -- Reset preset
                if curVehiclePreset and not IsSamePreset(curVehiclePreset) then
                    if ImGui.Button((" Load %s preset "):format(carName)) then
                        ApplyPreset(curVehiclePreset)
                        RefreshCameraIfNeeded()
                    end
                end
                ImGui.Text("")
                ImGui.Separator()
                ImGui.Text("")

                ImGui.BeginChild("percarpresets", 500, 300)
                -- Preset list
                for i, pr in pairs(Config.data.perCarPresets) do
                    if pr.man ~= "global" then
                        local isSamePreset = IsSamePreset(pr.preset)

                        -- Load Preset Button
                        ImGui.PushID(tostring(i))
                        if isSamePreset then
                            ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.5, 0.5, 0.4)
                            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.5, 0.5, 0.5, 0.4)
                            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.5, 0.5, 0.5, 0.4)
                        end
                        if ImGui.Button(" Load ") and not isSamePreset then
                            ApplyPreset(pr.preset)
                            RefreshCameraIfNeeded()
                        end
                        if isSamePreset then
                            ImGui.PopStyleColor(3)
                        end
                        ImGui.PopID()
                        ImGui.SameLine()

                        -- Delete Preset Button
                        ImGui.PushID("del" .. tostring(i))
                        ImGui.PushStyleColor(ImGuiCol.Button, 0.60, 0.20, 0.30, 0.8)
                        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.70, 0.20, 0.30, 1.0)
                        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.70, 0.20, 0.30, 0.5)
                        if ImGui.Button(" Delete ") then
                            DeletePreset((pr.man .. pr.model))
                        end
                        ImGui.PopStyleColor(3)
                        ImGui.PopID()
                        ImGui.SameLine()

                        -- Preset Name
                        if isSamePreset then
                            ImGui.PushStyleColor(ImGuiCol.Text, 0.1, 0.7, 0.2, 1)
                        end
                        ImGui.Text(pr.man .. " " .. pr.model)
                        if isSamePreset then
                            ImGui.PopStyleColor()
                        end
                    end
                end
                ImGui.EndChild()
            end
        end

        ImGui.End()
        ImGui.PopStyleVar(1)
        ImGui.PopStyleColor(8)
    end)

    return {
      version = BetterVehicleFirstPerson.version,
      api = API
    }
end

return BetterVehicleFirstPerson:New()
