--[[ Welcome, tuner.
    ____  ___ 
   / __ \/   | Entity 
  / /_/ / /| | Roblox car chassis 
 / _, _/ ___ | 0.50.7 
/_/ |_/_/  |_| GitHub:   https://github.com/totallyahuman445/Roblox-Entity-R-Series
			   Document: https://docs.google.com/document/d/1WvOWw7ST4ZWpsCfXM3abJTTBkCA40NsayIEIdCRJOYM/edit?usp=sharing
			   Server:   https://discord.gg/bS2A448Vrk
			   Log:		 https://docs.google.com/document/d/1SLW5NOAysg2rE6C52WEPnmOas_MNbeVNEv0xv2f__ps/edit?usp=sharing 
			   Credits:  https://docs.google.com/document/d/1-mIgEhmugHfVUDz4vzZMS7XYMoEdLKedy0MedRqvbyA/edit?usp=sharing 
--]]

local Diffuser_Enabled        = false   --Sheds the Diffuser part and turns off diffuser code. This optimizes diffuserless cars.
local BD_Enabled              = false    --Controls blown diffuser code. This optimizes blown diffuserless cars and needs Diffuser_Enabled to be on to enable.

local Drag				      = .3		-- Drag coefficient of the car.
local DownforceF		      = 40		-- Front downforce in kgf at 200 km/h. 
local DownforceR		      = 80		-- Rear downforce in kgf at 200 km/h. 
local DownforceD		      = 70		-- Diffuser downforce in kgf at 200 km/h. 
local BlownDirect             = true    -- If the blown diffuser is direct or not. A direct blown diffuser results in downforce regardless of speed when the throttle is pressed.
local BlownDiffuser           = 60     	-- Blown diffuser downforce at 200 km/h.
local Slipstream		      = 60		-- How much drag is reduced in slipstream (in percent)
local SlipstreamTime	      = .7		-- Maximum amount of time you can be behind a car to gain slipstream.

local WindVolume       	      = 2	    -- Volume of wind at 200 km/h.
local BodyVolume		      = 1	    -- Volume of body sounds at 200 km/h.

local values = script.Parent.Values
local car = script.Parent.Car.Value
local player = game.Players.LocalPlayer
local Units = require(car.Settings.Units)
local RunService = game:GetService("RunService")
local weight = car.Body["#Weight"]

local _DragFactor = 1
local toKMH = (Units.Length_mm/1000) * 3.6
local fromKGF = 9.81*Units.Force_N
wait()
local wind = weight:FindFirstChild("WindSound") or Instance.new("Sound", weight)
wind.Name = "WindSound"
wind.RollOffMaxDistance = 30
wind.RollOffMinDistance = 10
wind.Looped = true
wind.SoundId = "rbxassetid://188608071"
local eq = wind:FindFirstChild("EQ") or Instance.new("EqualizerSoundEffect", wind)
eq.Name = "EQ"
eq.HighGain = -20
eq.LowGain = 10
eq.MidGain = -10
local body = weight:FindFirstChild("BodySound") or Instance.new("Sound", weight)
body.Name = "BodySound"
body.RollOffMaxDistance = 30
body.RollOffMinDistance = 10
body.Looped = true
body.SoundId = "rbxassetid://4471836491"
wind:Play()
body:Play()

local aeroParams = RaycastParams.new()
aeroParams.FilterDescendantsInstances = {car, player.Character}
aeroParams.FilterType = Enum.RaycastFilterType.Exclude
local aeroParamsFrom = RaycastParams.new()
aeroParamsFrom.FilterDescendantsInstances = {}
aeroParamsFrom.FilterType = Enum.RaycastFilterType.Exclude

wait()
for _, v in next, car:GetDescendants() do
	if v:IsA("BasePart") then
		v.EnableFluidForces = false
	end
end

RunService.Heartbeat:Connect(function(dt)
	-- Slipstream
	local toRay = workspace:Raycast(weight.Position, weight.CFrame.LookVector*1000, aeroParams)
	_DragFactor = 1
	if toRay then
		aeroParamsFrom.FilterDescendantsInstances = toRay.Instance:GetConnectedParts()
		local fromRay = workspace:Raycast(toRay.Position, -toRay.Instance.Velocity*SlipstreamTime, aeroParamsFrom)
		if fromRay and fromRay.Instance:IsDescendantOf(car) then
			_DragFactor = (1-(Slipstream/100))+(fromRay.Distance/(toRay.Instance.Velocity*SlipstreamTime).Magnitude*(Slipstream/100))
		end
	end
	
	-- Apply forces
	if Diffuser_Enabled == true then
		local diff = (values.Velocity.Value - workspace.GlobalWind).Magnitude * toKMH
		local dd = -(diff^2/(200)^2)*(DownforceD)*_DragFactor
		local diffuserRay = workspace:Raycast(car.Body.Diffuser.Position, -car.Body.Diffuser.CFrame.UpVector*(car.Body.Diffuser.Size.Y/2), aeroParams)
		if not diffuserRay then
			dd = 0
		end
		weight:ApplyImpulseAtPosition(weight.CFrame.UpVector*dt*(dd)*fromKGF, car.Body.Diffuser.Position)
		car.Body.Diffuser:SetAttribute("Downforce", dd)
	end
	
	local diff = (values.Velocity.Value - workspace.GlobalWind).Magnitude * toKMH
	local dd = -(diff^2/(200)^2)*(DownforceD)*_DragFactor
	local df  = -(diff^2/(200)^2)*(DownforceF)*_DragFactor
	local dr  = -(diff^2/(200)^2)*(DownforceR)*_DragFactor
	
	if Diffuser_Enabled == true and BD_Enabled == true then
		local br  = -(BlownDiffuser*values.Throttle.Value)
		local diffuserRay = workspace:Raycast(car.Body.Diffuser.Position, -car.Body.Diffuser.CFrame.UpVector*(car.Body.Diffuser.Size.Y/2), aeroParams)
		if BlownDirect == true then
			if not diffuserRay then
				br = 0
			end
			weight:ApplyImpulseAtPosition(weight.CFrame.UpVector*dt*(br)*fromKGF, car.Body.Diffuser.Position)
			car.Body.Diffuser:SetAttribute("BDForce", br)
		else
			if not diffuserRay then
				br = 0
			end
			weight:ApplyImpulseAtPosition(weight.CFrame.UpVector*dt*(br)*fromKGF, car.Body.Diffuser.Position)
			car.Body.Diffuser:SetAttribute("BDForce", br)
		end	
	end
	
	local dragForce = diff^2*(Drag/100)
	weight:ApplyImpulseAtPosition(weight.CFrame.UpVector*dt*(df)*fromKGF, car.Body.Downforce_WingF.Position)
	weight:ApplyImpulseAtPosition(weight.CFrame.UpVector*dt*(dr)*fromKGF, car.Body.Downforce_WingR.Position)
	weight:ApplyImpulseAtPosition(weight.CFrame.LookVector*dt*-dragForce*fromKGF, car.Body.Drag.Position)
	car.Body.Downforce_WingF:SetAttribute("Downforce", df)
	car.Body.Downforce_WingR:SetAttribute("Downforce", dr)
	car.Body.Drag:SetAttribute("DragForce", dragForce)

	wind.Volume = diff^2 * WindVolume / (200)^2
	body.Volume = diff^2 * BodyVolume / (200)^2
end)

if Diffuser_Enabled == false then
	car.Body.Diffuser:destroy()
end