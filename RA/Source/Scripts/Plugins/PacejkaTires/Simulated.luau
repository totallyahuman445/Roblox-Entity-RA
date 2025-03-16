local car = script.Parent.Parent.Car.Value
local values = script.Parent.Parent:WaitForChild("Values")
local event = car:WaitForChild("Friction")
local player=game.Players.LocalPlayer

local _Tune = require(car.Settings)
local _WheelTune = require(script.Parent.Tune)
local Units = require(car.Settings.Units)

local UserInputService = game:GetService("UserInputService")
local HapticService = game:GetService("HapticService")
local RunService = game:GetService("RunService")

wait()
--Load SmokePart
event:FireServer("create", _WheelTune)

--Wheels Array
local WheelData = {}
for _, v in next, car.Wheels:GetChildren() do
	local data = {}
	data.Object = v
	data.Temperature = _WheelTune.AmbientTemp
	data.Dirt = 0
	data.Stress = 0
	data.Ray = nil
	data.Material = ""
	data.SmokePart = v:WaitForChild("SmokePart")
	data.FlexCollision = data.Object:FindFirstChild("Collision")
	WheelData[v.Name] = data
end

--Open/Load Heat Data
if _WheelTune.SaveHeatData then
	local wd = car:FindFirstChild("HeatData")
	if wd then
		local t = tick()-wd.STime.Value
		for name, data in WheelData do
			if wd:FindFirstChild(name) then
				local front = string.find(name, "F")
				data.Temperature = wd[name]:GetAttribute("Temperature") - 60*t*(front and _WheelTune.FCooling or _WheelTune.RCooling)
				data.Dirt = wd[name]:GetAttribute("Dirt")
			end
		end
	end
end

--Close/Store Heat Data
car.DriveSeat.ChildRemoved:connect(function(child)
	if child.Name=="SeatWeld" then
		if _WheelTune.SaveHeatData then
			local wd=car:FindFirstChild("HeatData")
			if not wd then
				wd = script.Parent.HeatData:Clone()
				wd.Parent = car
			end
			for name, data in WheelData do
				local config = wd:FindFirstChild(name) or Instance.new("Configuration", wd)
				config.Name = name
				config:SetAttribute("Temperature", data.Temperature)
				config:SetAttribute("Dirt", data.Dirt)
			end
			wd.STime.Value=tick()
		end
		event:FireServer("stop")
		if HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1) then
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
		end
	end
end)

--Ray Data
local rayParams = RaycastParams.new()
rayParams.FilterDescendantsInstances = {car}
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local materialSort = {

	road = {
		"SmoothPlastic",
		"Asphalt",
		"Plastic",
		"Slate",
		"Concrete",
		"Granite",
		"Brick",
		"Pebble",
		"Marble",
		"Cobblestone",
		"Rock",
		"Basalt",
		"Wood",
		"WoodPlanks",
		"Ground",
		"Pavement",
		"Salt",
		"CorrodedMetal",
		"CrackedLava",
		"DiamondPlate",
		"Fabric",
		"Foil",
		"ForceField",
		"Glass",
		"Metal",
		"Neon",
		"Sandstone",
		"Limestone"
	},
	
	leaf = {
		"LeafyGrass",
	},

	dirt = {
		"Grass",
		"Ground",
		"LeafyGrass",
	},
	
	mud = {
		"Mud",
	},

	sand = {
		"Sand",
	},

	snow = {
		"Glacier",
		"Snow",
	},
	
	ice = {
		"Ice",
	},
	
	water = {
		"Water",
	}

}

--Runtime Loops
local sandForce = Vector3.new()
local mudForce = Vector3.new()
local deltaTime = 1
RunService.Heartbeat:Connect(function(dt)
	deltaTime = dt
	for name, data in next, WheelData do
		-- Apply sand and mud force
		data.Object:ApplyImpulseAtPosition(sandForce * dt, data.Object.Position)
		data.Object:ApplyImpulseAtPosition(mudForce * dt, data.Object.Position)
		local stress = 0
		local count = 0

		for name, data in next, WheelData do
			local rotSpeed = math.abs(data.Object.RotVelocity:Dot(data.SmokePart.CFrame.RightVector))
			local rotLinearSpeed = rotSpeed*(data.Object.Size.Y/2)
			local speed = values.Velocity.Value.Magnitude
			local diff = math.abs(rotLinearSpeed-speed)

			local ray = nil -- Assuming they are the same material
			local materialType = ""

			local front = string.find(name, "F")

			-- Rays
			-- Two rays, one for the inside and outside of the wheel for camber support.
			local rayI = workspace:Raycast(
				data.Object.Position,
				-data.SmokePart.CFrame.UpVector * (data.Object.Size.Y/2 + .1),
				rayParams)
			local rayO = workspace:Raycast(
				data.Object.Position,
				-data.SmokePart.CFrame.UpVector * (data.Object.Size.Y/2 + .1),
				rayParams)
			ray = rayI or rayO
			if ray then
				-- Run a loop through the materialSort table. Set materialType and break when a material is found.
				for name, values in next, materialSort do
					if table.find(values, ray.Material.Name) then
						materialType = name
						break
					end
				end
			end
			data.Ray = ray
			data.Material = materialType

			-- Slip
			local vstress = (math.max(ray and diff/20 or 0, ray and materialType~="road" and rotSpeed/50 or 0) + (front and _WheelTune.FSpeedStress or _WheelTune.RSpeedStress)*(rotLinearSpeed/(Units.Velocity_mdivs/3.6)/100))
			if ray and materialType ~= "road" then
				local random = Random.new():NextNumber() * speed
				if random > 20 then
					data.Object.Velocity += Vector3.new(0, math.random(0, _WheelTune.DirtBumps), 0) * math.min(speed/100, 5)
				end
			end
			if vstress > 0.05 * (60/(1/dt)) and vstress > data.Stress then 
				data.Stress = math.min(data.Stress + 0.05 * (60/(1/dt)), math.min(vstress, 1))
			else
				data.Stress = math.max(data.Stress - 0.05 * (60/(1/dt)), vstress)	
			end

			-- Update dirt
			if materialType ~= "road" and materialType ~= "" then
				data.Dirt = 1
			else
				data.Dirt = math.max(data.Dirt - (front and _WheelTune.FDirtFadeRate or _WheelTune.RDirtFadeRate) * (rotSpeed/100) * (60/(1/dt)), 0)
			end

			-- Apply friction
			local materialHeatFactor = materialType ~= "road" and .01 or 1
			if _WheelTune.TireWearOn then
				if front then
					data.Temperature = math.clamp(data.Temperature + (data.Stress*(_WheelTune.FHeating+_WheelTune.FCooling)*materialHeatFactor - _WheelTune.FCooling) * (60/(1/dt)), _WheelTune.AmbientTemp, _WheelTune.FMaxTemp)
				else
					data.Temperature = math.clamp(data.Temperature + (data.Stress*(_WheelTune.RHeating+_WheelTune.RCooling)*materialHeatFactor - _WheelTune.RCooling) * (60/(1/dt)), _WheelTune.AmbientTemp, _WheelTune.RMaxTemp)
				end
				local coldLoss = front and 
					(_WheelTune.FColdStats[1] * (1/(math.exp(_WheelTune.FColdStats[2]*(data.Temperature/100-_WheelTune.FColdStats[3]))+1))) or 
					(_WheelTune.RColdStats[1] * (1/(math.exp(_WheelTune.RColdStats[2]*(data.Temperature/100-_WheelTune.RColdStats[3]))+1)))
				local heatLoss = front and 
					(_WheelTune.FHotStats[1] * (-(1/(math.exp(_WheelTune.FHotStats[2]*(data.Temperature/100-_WheelTune.FHotStats[3]))+1))+1)) or 
					(_WheelTune.RHotStats[1] * (-(1/(math.exp(_WheelTune.RHotStats[2]*(data.Temperature/100-_WheelTune.RHotStats[3]))+1))+1))
				if front then
					data.Object.CustomPhysicalProperties = PhysicalProperties.new(
						((_Tune.FWheelWeight-(_WheelTune.TireFlex and _WheelTune.FTireWeight or 0))*Units.Mass_kg)/(math.pi*(data.Object.Size.Y/2)^2*(data.Object.Size.X)),
						_WheelTune.FMaxFriction - coldLoss - heatLoss - data.Dirt*_WheelTune.FDirtLoss,
						data.Object.CurrentPhysicalProperties.Elasticity,
						data.Object.CurrentPhysicalProperties.FrictionWeight,
						data.Object.CurrentPhysicalProperties.ElasticityWeight
					)
				else
					data.Object.CustomPhysicalProperties = PhysicalProperties.new(
						((_Tune.RWheelWeight-(_WheelTune.TireFlex and _WheelTune.RTireWeight or 0))*Units.Mass_kg)/(math.pi*(data.Object.Size.Y/2)^2*(data.Object.Size.X)),
						_WheelTune.RMaxFriction - coldLoss - heatLoss - data.Dirt*_WheelTune.RDirtLoss,
						data.Object.CurrentPhysicalProperties.Elasticity,
						data.Object.CurrentPhysicalProperties.FrictionWeight,
						data.Object.CurrentPhysicalProperties.ElasticityWeight
					)
				end
			else
				if front then
					data.Object.CustomPhysicalProperties = PhysicalProperties.new(
						((_Tune.FWheelWeight-(_WheelTune.TireFlex and _WheelTune.FTireWeight or 0))*Units.Mass_kg)/(math.pi*(data.Object.Size.Y/2)^2*(data.Object.Size.X)),
						_WheelTune.FMaxFriction - data.Dirt*_WheelTune.FDirtLoss,
						data.Object.CurrentPhysicalProperties.Elasticity,
						data.Object.CurrentPhysicalProperties.FrictionWeight,
						data.Object.CurrentPhysicalProperties.ElasticityWeight
					)
				else
					data.Object.CustomPhysicalProperties = PhysicalProperties.new(
						((_Tune.RWheelWeight-(_WheelTune.TireFlex and _WheelTune.RTireWeight or 0))*Units.Mass_kg)/(math.pi*(data.Object.Size.Y/2)^2*(data.Object.Size.X)),
						_WheelTune.RMaxFriction - data.Dirt*_WheelTune.RDirtLoss,
						data.Object.CurrentPhysicalProperties.Elasticity,
						data.Object.CurrentPhysicalProperties.FrictionWeight,
						data.Object.CurrentPhysicalProperties.ElasticityWeight
					)
				end
			end
			if ray and materialType == "sand" then
				sandForce = ((-data.Object.Velocity.Unit * ( ((data.Object.Velocity.Magnitude*Units.Velocity_mdivs*3.6)*(_WheelTune.SandForce*Units.Force_N*9.80665))^2 / (50*Units.Velocity_mdivs*3.6)^2) ))
			else
				sandForce = Vector3.new()
			end
			
			if ray and materialType == "mud" then
				mudForce = ((-data.Object.Velocity.Unit * ( ((data.Object.Velocity.Magnitude*Units.Velocity_mdivs*3.6)*(_WheelTune.MudForce*Units.Force_N*9.80665))^2 / (50*Units.Velocity_mdivs*3.6)^2) ))
			else
				mudForce = Vector3.new()
			end
			
			-- Update UI
			data.Object:SetAttribute("Temperature", data.Temperature)
			data.Object:SetAttribute("Dirt", data.Dirt)

			-- Update haptic values
			stress += data.Stress
			count += 1

			-- Tire flex
			if _WheelTune.TireFlex and data.FlexCollision then
				data.FlexCollision.CustomPhysicalProperties = PhysicalProperties.new(
					((string.find(name, "F") and _WheelTune.FTireWeight or _WheelTune.RTireWeight)*Units.Mass_kg)/(math.pi*(data.Object.Size.Y/2)^2*(data.Object.Size.X)),
					data.Object.CurrentPhysicalProperties.Friction,
					data.Object.CurrentPhysicalProperties.Elasticity,
					data.Object.CurrentPhysicalProperties.FrictionWeight,
					data.Object.CurrentPhysicalProperties.ElasticityWeight
				)
				data.FlexCollision["#FORCE"].Force = Vector3.new(0, 0 > 0 and data.FlexCollision.Mass*(workspace.Gravity) or 0, 0)
				data.Object["#FORCE"].Force = Vector3.new(0, 0 > 0 and data.Object.Mass*(workspace.Gravity-0) or 0, 0)

				if string.find(name, "F") then
					data.FlexCollision.AlignPosition.MaxForce = _WheelTune.FPressureForce*100
				else
					data.FlexCollision.AlignPosition.MaxForce = _WheelTune.RPressureForce*100
				end
			end
			
			-- Smoke
			local currentSound = data.SmokePart:FindFirstChild("Sound_" .. materialType)
			local currentSound2 = data.SmokePart:FindFirstChild("Sound_" .. materialType)
			local currentSmoke = data.SmokePart:FindFirstChild("Smoke_" .. materialType)
			local currentSmoke2 = data.SmokePart:FindFirstChild("Smoke_" .. materialType)
			local smokeStress = math.clamp(data.Stress - _WheelTune.SmokeStressOffset/100, 0, 1)
			if _WheelTune.Effects == "Local" then
				-- Set smokepart data
				for _, d in next, data.SmokePart:GetChildren() do 
					if d:IsA("Sound") and (d ~= currentSound or not ray) then d.Playing = false end
					if d:IsA("Sound") and (d ~= currentSound2 or not ray) then d.Playing = false end
					if d:IsA("ParticleEmitter") and (d ~= currentSmoke or not ray) then d.Enabled = false end
					if d:IsA("ParticleEmitter") and (d ~= currentSmoke2 or not ray) then d.Enabled = false end
					if d:IsA("Trail") then
						d.Enabled = false
						if string.find(d.Name, materialType) and d:GetAttribute("stress") < smokeStress^3 and ray then
							d.Enabled = true
						end
					end			
				end
				if currentSound then
					-- Sound
					currentSound.Playing = true
					currentSound.Volume = smokeStress ^ 3 * 1.4
					currentSound.PlaybackSpeed = 0.5 * smokeStress + 0.7
				end
				if currentSound2 then
					-- Sound
					currentSound2.Playing = true
					currentSound2.Volume = smokeStress ^ 3 * 1.4
					currentSound2.PlaybackSpeed = 0.5 * smokeStress + 0.7
				end
				if currentSmoke then
					-- Smoke
					currentSmoke.Enabled = true
					currentSmoke.Rate = smokeStress^10 * 100
				end
				if currentSmoke2 then
					-- Smoke
					currentSmoke2.Enabled = true
					currentSmoke2.Rate = smokeStress^10 * 100
				end
				local compression = 1
				if data.Object:FindFirstChild("Collision") then
					compression = math.clamp((data.Object.Position-data.Object.Collision.Position).Magnitude/.1, 0, 1)
				end
				local trailAttachmentPart = data.Object:FindFirstChild("TrailAttachmentPart")
				if trailAttachmentPart then
					trailAttachmentPart.TrailAttachment0.Position = Vector3.new(data.Object.Size.X/2-.2 + .1*compression, .02, 0)
					trailAttachmentPart.TrailAttachment1.Position = Vector3.new(-data.Object.Size.X/2+.2 - .1*compression, .02, 0)
					trailAttachmentPart.AlignOrientation.CFrame = CFrame.lookAt(data.SmokePart.Position, (data.SmokePart.CFrame * CFrame.new(0, 0, -5 + math.min(data.Object.Velocity.Magnitude, 5))).Position+data.Object.Velocity, ray and ray.Normal or data.SmokePart.CFrame.UpVector)
				end
			end
		end
		-- Haptics
		local lastInput = game:GetService("UserInputService"):GetLastInputType()
		if HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1) and ((_WheelTune.Haptics == "Controller" or _WheelTune.Haptics == "Both" and string.find(lastInput.Name, "Gamepad")) or (_WheelTune.Haptics == "Mobile" or _WheelTune.Haptics == "Both" and lastInput == Enum.UserInputType.Touch)) then
			stress /= count
			stress = math.clamp(stress/2, 0, .5)
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, stress)
		end
	end
end)

--Everything else
if _WheelTune.Effects == "All" then
	local rate = _WheelTune.SmokePollingRate
	local lastTick = tick()
	while wait(rate) do
		for name, data in next, WheelData do
			local ray = data.Ray
			local materialType = data.Material
			local smokeStress = math.clamp(data.Stress - _WheelTune.SmokeStressOffset/100, 0, 1)
			event:FireServer("update", data.Object, materialType, smokeStress, ray and ray.Normal, deltaTime)
		end
	end
end
