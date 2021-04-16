local BetterVehicleFirstPerson = { version = "1.2.5" }
local Config = require("Modules/Config")
local Cron = require("Modules/Cron")
local GameSettings = require("Modules/GameSettings")

--[[
TODO:
1. Camera should work for passenger seat, but have to be turned off for the combat mode.
   VehicleTransition SetVehFppCameraParams/ToDriverCombat
]]

local initialFOV = 51

local enabled = true

local isInVehicle = false
local curVehicle = nil

local isYFlipped = false

function IsEnteringVehicle()
    return IsInVehicle() and Game.GetWorkspotSystem():GetExtendedInfo(Game.GetPlayer()).entering
end
function IsExitingVehicle()
    return IsInVehicle() and Game.GetWorkspotSystem():GetExtendedInfo(Game.GetPlayer()).exiting
end

function IsInVehicle()
    return Game.GetWorkspotSystem():IsActorInWorkspot(Game.GetPlayer())
            and Game.GetWorkspotSystem():GetExtendedInfo(Game.GetPlayer()).isActive
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

function StartPeek()
    Game.GetPlayer():GetFPPCameraComponent():SetLocalOrientation(Quaternion.new(0.0, 0.0, 100, 1.0))
    Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Vector4.new(-0.6, 0.0, 0.01, 1.0))
end
function StopPeek()
    if enabled then
        TiltCamera()
        RaiseCamera()
    else
        Game.GetPlayer():GetFPPCameraComponent():SetLocalOrientation(Quaternion.new(0.0, 0.0, 0, 1.0))
        Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Vector4.new(0.0, 0.0, 0.0, 1.0))
    end
end
function FlipY()
	if not isYFlipped then 
		isYFlipped = true
	else
		isYFlipped = false
	end
	
	GameSettings.Toggle('/controls/fppcameramouse/FPP_MouseInvertY')
	GameSettings.Toggle('/controls/fppcamerapad/FPP_PadInvertY')
end
function DoubleCheckY()
	if isYFlipped then
		GameSettings.Toggle('/controls/fppcameramouse/FPP_MouseInvertY')
		GameSettings.Toggle('/controls/fppcamerapad/FPP_PadInvertY')
		isYFlipped = false
	end
end

function SaveConfig()
    Config.SaveConfig()
end


function OnVehicleExited()
    -- nothing?
    if not enabled then
        return
    end
	
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
    return { Config.data.tiltMult, Config.data.yMult, Config.data.zMult, Config.data.fov }
end

function GetVehicleMan(vehicle)
    return vehicle:Manufacturer():Type().value
end
function GetVehicleModel(vehicle)
    return vehicle:Model():Type().value
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

function GetVehiclePreset(vehicle)
    if not vehicle then
        return nil
    end

    local vehMan = GetVehicleMan(vehicle)
    local vehModel = GetVehicleModel(vehicle)
    local vehKey = (vehMan .. vehModel)
    local vehPreset = Config.data.perCarPresets[vehKey]
    if vehPreset then
        return vehPreset.preset
    end

    return nil
end

function ApplyAutoPreset()
    local vehicle = GetMountedVehicleRecord()
    curVehicle = vehicle

    if Config.data.autoSetPerCar then
        local preset = GetVehiclePreset(vehicle)
        if preset then
            ApplyPreset(preset)
            RefreshCameraIfNeeded()
        end
    end
end

function OnVehicleEntered()
    ApplyAutoPreset()

    -- TODO: is this ever changing for different players?
    -- initialFOV = GetFOV()
    if not enabled then
        return
    end

    TiltCamera()
    RaiseCamera()

    SetFOV()
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
    curVehicle = nil
end

function RefreshCameraIfNeeded()
    SaveConfig()
    if isInVehicle and enabled then
        TiltCamera()
        RaiseCamera()
        SetFOV()
    elseif isInVehicle and not enabled then
        ResetCamera()
        ResetTilt()
        ResetFOV()
    end
end

local presets = {
    -- default
    { 1.150, 0.9, -0.2, 56 },
    { 1.050, 0.8, -3.810, 58 },
    { 1.170, 0.810, 7, 49 },
    { 0.950, 0.610, -10, 70 },
    { 0.950, 0.500, -13, 87 },
    -- car-specific
    -- ...
}

function IsSamePreset(pr)
    return math.abs(Config.data.tiltMult - pr[1]) < 0.01 and
            math.abs(Config.data.yMult - pr[2]) < 0.01 and
            math.abs(Config.data.zMult - pr[3]) < 0.01 and
            math.abs(Config.data.fov - pr[4]) < 0.01
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
end


function BetterVehicleFirstPerson:New()
    registerForEvent("onInit", function()
        Config.InitConfig()

        Cron.Every(0.2, { tick = 1 }, function()
            if not Config or not Config.isReady or not Game.GetPlayer() then
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

        -- Observe('hudCarController', 'RegisterToVehicle', function(self, registered)
        --     if registered then
        --         OnVehicleEnter()
        --     else
        --         OnVehicleExit()
        --     end
        -- end)
        -- Observe('hudCarController', 'OnCameraModeChanged', function(mode, self)
        --     if mode then
        --         OnVehicleExit()
        --     else
        --         OnVehicleEnter()
        --     end
        -- end)

        -- Fires with loaded save file too
        Observe('hudCarController', 'OnPlayerAttach', function()
            if isInVehicle and enabled then
                RefreshCameraIfNeeded()
            end
        end)

        -- Fires when execting
        -- Observe('hudCarController', 'OnUnmountingEvent', function()
        --     OnVehicleExit()
        -- end)
        -- Observe('RadialWheelController', 'RegisterBlackboards', function(_, loaded)
        --     if not loaded then
        --         isInVehicle = false
        --         OnVehicleExit()
        --     end
        -- end)

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
	
			local peekplayer = Game.GetPlayer()
			local peekvehicle = Game['GetMountedVehicle;GameObject'](peekplayer)
			if peekvehicle then
				if not Game.GetPlayer():FindVehicleCameraManager():IsTPPActive() then
					peekplayer:QueueEvent(NewObject('handle:vehicleCameraResetEvent'))
				end
			end
		
			FlipY()
		
            StartPeek()
        else
			local peekplayer = Game.GetPlayer()
			local peekvehicle = Game['GetMountedVehicle;GameObject'](peekplayer)
			if peekvehicle then
				if not Game.GetPlayer():FindVehicleCameraManager():IsTPPActive() then
					peekplayer:QueueEvent(NewObject('handle:vehicleCameraResetEvent'))
				end
			end
			
			FlipY()
			DoubleCheckY()
			
            StopPeek()
        end
    end)
    registerHotkey("VehicleFPPCameraEnabled", "Toggle Enhanced Vehicle Camera Enabled", function()
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
            -- Tilt controll
            Config.data.tiltMult, tiltMultUsed = ImGui.DragFloat(" Tilt Multiplier ", Config.data.tiltMult, 0.01, 0, 5)
            if tiltMultUsed then
                RefreshCameraIfNeeded()
            end

            -- Raise controll
            Config.data.yMult, raiseMultUsed = ImGui.DragFloat(" Y Multiplier ", Config.data.yMult, 0.01, -1, 2)
            if raiseMultUsed then
                RefreshCameraIfNeeded()
            end

            -- Backoff controll
            Config.data.zMult, backoffMultUsed = ImGui.DragFloat(" Z Multiplier ", Config.data.zMult, 0.01, -55, 7)
            if backoffMultUsed then
                RefreshCameraIfNeeded()
            end

            -- Backoff controll
            Config.data.fov, fovChanged = ImGui.DragFloat(" FOV ", Config.data.fov, 1, 40, 95)
            if fovChanged then
                RefreshCameraIfNeeded()
            end
            -- Presets
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
            ImGui.Text("")

            ImGui.Text("Auto applied per-vehicle presets")

            -- Presets manager
            if curVehicle then
                local carName = GetVehicleMan(curVehicle) .. " " .. GetVehicleModel(curVehicle)
                if ImGui.Button(" Save for " .. carName .. " ") then
                    AddVehiclePreset()
                end
                ImGui.Text(" ")

                ImGui.BeginChild("percarpresets", 500, 300)

                for i, pr in pairs(Config.data.perCarPresets) do
                    local isSamePreset = IsSamePreset(pr.preset)
                    ImGui.PushID(tostring(i))
                    if isSamePreset then
                        ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.5, 0.5, 0.4)
                        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.5, 0.5, 0.5, 0.4)
                        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.5, 0.5, 0.5, 0.4)
                    end
                    if ImGui.Button(" Select ") and not isSamePreset then
                        ApplyPreset(pr.preset)
                        RefreshCameraIfNeeded()
                    end
                    if isSamePreset then
                        ImGui.PopStyleColor(3)
                    end
                    ImGui.PopID()
                    ImGui.SameLine()

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
                    if isSamePreset then
                        ImGui.PushStyleColor(ImGuiCol.Text, 0.1, 0.7, 0.2, 1)
                    end
                    ImGui.Text(pr.man .. " " .. pr.model)
                    if isSamePreset then
                        ImGui.PopStyleColor()
                    end
                end
                ImGui.EndChild()
            end
        end

        ImGui.End()
        ImGui.PopStyleVar(1)
        ImGui.PopStyleColor(8)
    end)

    return { ["version"] = BetterVehicleFirstPerson.version }
end

return BetterVehicleFirstPerson:New()
