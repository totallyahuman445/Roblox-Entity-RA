local car = script.Parent.Parent
local _Tune = require(car.Settings)
local Units = require(car.Settings.Units)
local RunService = game:GetService("RunService")
local functionTable = {
	create = function(_WheelTune)
		for _, v in next, car.Wheels:GetChildren() do
			if not v:FindFirstChild("SmokePart") then
				local caster = string.find(v.Name, "F") and _Tune.FCaster or _Tune.RCaster
				caster = (v.Name == "FR" or v.Name == "RR") and -caster or caster
				local smokePart = v:FindFirstChild("SmokePart") or v.Arm:Clone()
				smokePart.Name = "SmokePart"
				smokePart.Massless = true
				smokePart:ClearAllChildren()
				smokePart.CFrame = CFrame.new((v.CFrame * CFrame.new(0, -v.Size.Y/2, 0)).Position) * v.Arm.CFrame.Rotation
				smokePart.Parent = v
				local sa0 = Instance.new("Attachment", v.Base)
				sa0.Name = "SmokePartAttachment0"
				local sa1 = Instance.new("Attachment", smokePart)
				sa1.Name = "SmokePartAttachment1"
				sa1.Position = Vector3.new(0, v.Size.Y, 0)
				local smokePartRigidConstraint = Instance.new("RigidConstraint", smokePart)
				smokePartRigidConstraint.Attachment0 = sa0
				smokePartRigidConstraint.Attachment1 = sa1
				for _, a in next, script:GetChildren() do
					if smokePart:FindFirstChild(a.Name) then continue end
					local clone = a:Clone()
					clone.Parent = smokePart
				end
				-- create trails
				local trailAttachmentPart = v:FindFirstChild("TrailAttachmentPart") or smokePart:Clone()
				trailAttachmentPart:ClearAllChildren()
				trailAttachmentPart.Name = "TrailAttachmentPart"
				trailAttachmentPart.Parent = v
				local ta0 = Instance.new("Attachment", v)
				local ta1 = Instance.new("Attachment", trailAttachmentPart)
				ta1.Position = Vector3.new(0, v.Size.Y/2, 0)
				local tapalign = Instance.new("AlignPosition", trailAttachmentPart)
				tapalign.ReactionForceEnabled = true
				tapalign.RigidityEnabled = true
				tapalign.Attachment0 = ta0
				tapalign.Attachment1 = ta1
				local tapOrientation = Instance.new("AlignOrientation", trailAttachmentPart)
				tapOrientation.RigidityEnabled = true
				tapOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
				tapOrientation.Attachment0 = ta1
				local a0 = Instance.new("Attachment", trailAttachmentPart)
				a0.Name = "TrailAttachment0"
				local a1 = Instance.new("Attachment", trailAttachmentPart)
				a1.Name = "TrailAttachment1"
				if _WheelTune.TireFlex then
					v.CanCollide = false
					
					local collision = v:FindFirstChild("Collision") or Instance.new("Part", v)
					collision.Name = "Collision"
					collision.CanCollide = true -- set false for now we will make it collide in loop
					collision.CFrame = v.CFrame
					collision.Transparency = _WheelTune.ShowTF and .5 or 1
					collision.Shape = Enum.PartType.Cylinder
					collision.Size = v.Size
					ta0.Parent = v.Collision
					
					local gc = Instance.new("BodyForce", collision)
					gc.Name = "#FORCE"
					gc.Force = Vector3.new(0, 0 > 0 and collision.Mass*(workspace.Gravity) or 0, 0)
					
					local mainAttachment = Instance.new("Attachment", collision)
					mainAttachment.Orientation = v["AB"].Orientation

					local force = Instance.new("AlignPosition", collision)
					force.ReactionForceEnabled = true
					force.Attachment0 = v["AB"]
					force.Attachment1 = mainAttachment
					force.ForceLimitMode = Enum.ForceLimitMode.Magnitude
					force.ForceRelativeTo = Enum.ActuatorRelativeTo.World
					force.Responsiveness = 200
					force.MaxVelocity = 10

					local rotationForce = Instance.new("AlignOrientation", collision)
					rotationForce.ReactionTorqueEnabled = true
					rotationForce.RigidityEnabled = true
					rotationForce.Attachment0 = v["AB"]
					rotationForce.Attachment1 = mainAttachment
					rotationForce.Responsiveness = math.huge

					local limiter = Instance.new("SpringConstraint", collision)
					limiter.Name = "Limiter"
					limiter.Damping = 0
					limiter.Stiffness = 0
					limiter.MaxForce = 0
					limiter.Coils = 0
					limiter.Attachment0 = v["AB"]
					limiter.Attachment1 = mainAttachment
					limiter.LimitsEnabled = true
					limiter.FreeLength = 0

					if string.find(v.Name, "F") then
						limiter.MaxLength = _WheelTune.FTireThickness/Units.Length_mm
					else
						limiter.MaxLength = _WheelTune.RTireThickness/Units.Length_mm
					end
				end
				if v:GetAttribute("Smoke") == false then
					v.SmokePart.Sound_road:Destroy()
					v.SmokePart.Smoke_road:Destroy()
				end
				local TAPRayParams = RaycastParams.new()
				TAPRayParams.FilterType = Enum.RaycastFilterType.Exclude
				TAPRayParams.FilterDescendantsInstances = {car}
				if _WheelTune.TireMarkTransparencyLevels > 0 then
					for m = 1, 4 do
						for i = 1, _WheelTune.TireMarkTransparencyLevels do
							local name = "Trail"..((m==1 and "road") or (m==2 and "snow") or (m==3 and "sand") or (m==4 and "dirt" or "leaf") or (m==5 and "mud") or "") .. i
							local trail = smokePart:FindFirstChild(name) or Instance.new("Trail", smokePart)
							trail.Name = name
							trail.Transparency = NumberSequence.new(_WheelTune.TireMarkTransparency)
							trail.Texture = "rbxassetid://14987871952"
							trail.TextureMode = Enum.TextureMode.Static
							trail.Lifetime = 20
							trail.Enabled = false
							trail.Attachment0 = a0
							trail.Attachment1 = a1
							trail:SetAttribute("stress", i/_WheelTune.TireMarkTransparencyLevels)
							if m == 1 then
								trail.Color = ColorSequence.new(Color3.new(0, 0, 0))
							elseif m == 2 then
								trail.Color = ColorSequence.new(Color3.fromRGB(205, 250, 255))
							elseif m == 3 then
								trail.Color = ColorSequence.new(Color3.fromRGB(255, 241, 136))
							elseif m == 4 then
								trail.Color = ColorSequence.new(Color3.fromRGB(255, 173, 102))
							elseif m == 5 then
								trail.Color = ColorSequence.new(Color3.fromRGB(140, 103, 43))
							else
								trail.Color = ColorSequence.new(Color3.new(0, 0, 0))
							end
						end
					end
				end
				
			end
		end
	end,
	update = function(wheel, materialType, smokeStress, rayNormal, dt)
		-- Set smokepart data
		local smokePart = wheel:FindFirstChild("SmokePart")
		if not smokePart then return end
		local currentSound = smokePart:FindFirstChild("Sound_" .. materialType)
		local currentSound2 = smokePart:FindFirstChild("Sound2_" .. materialType)
		local currentSmoke = smokePart:FindFirstChild("Smoke_" .. materialType)
		local currentSmoke2 = smokePart:FindFirstChild("Smoke2_" .. materialType)
		for _, d in next, smokePart:GetChildren() do 
			if d:IsA("Sound") and (d ~= currentSound or not rayNormal) then d.Playing = false end
			if d:IsA("Sound") and (d ~= currentSound2 or not rayNormal) then d.Playing = false end
			if d:IsA("ParticleEmitter") and (d ~= currentSmoke or not rayNormal) then d.Enabled = false end
			if d:IsA("ParticleEmitter") and (d ~= currentSmoke2 or not rayNormal) then d.Enabled = false end
			if d:IsA("Trail") then
				d.Enabled = false
				if string.find(d.Name, materialType) and d:GetAttribute("stress") < smokeStress^3 and rayNormal then
					d.Enabled = true
				end
			end			
		end
		if currentSound then
			-- Sound
			if not currentSound.Playing then
				currentSound.TimePosition = Random.new():NextNumber() * currentSound.TimeLength --avoid overlapping sounds
			end
			currentSound.Playing = true
			currentSound.Volume = smokeStress ^ 3 * 1.4
			currentSound.PlaybackSpeed = 0.5 * smokeStress + 0.7
		end
		if currentSound2 then
			-- Secondary sound
			if not currentSound2.Playing then
				currentSound2.TimePosition = Random.new():NextNumber() * currentSound.TimeLength --avoid overlapping sounds
			end
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
			-- Kickback
			currentSmoke2.Enabled = true
			currentSmoke2.Rate = smokeStress^10 * 100
		end
		local compression = 1
		if wheel:FindFirstChild("Collision") then
			compression = math.clamp((wheel.Position-wheel.Collision.Position).Magnitude/.1, 0, 1)
		end
		local trailAttachmentPart = wheel:FindFirstChild("TrailAttachmentPart")
		if trailAttachmentPart then
			trailAttachmentPart.TrailAttachment0.Position = Vector3.new(wheel.Size.X/2-.2 + .1*compression, .02, 0)
			trailAttachmentPart.TrailAttachment1.Position = Vector3.new(-wheel.Size.X/2+.2 - .1*compression, .02, 0)
			trailAttachmentPart.AlignOrientation.CFrame = CFrame.lookAt(smokePart.Position, (smokePart.CFrame * CFrame.new(0, 0, -5 + math.min(wheel.Velocity.Magnitude, 5))).Position+wheel.Velocity, rayNormal or smokePart.CFrame.UpVector)
		end
		
		smokePart.SmokePartAttachment1.Position = Vector3.new(0, wheel.Size.Y, 0) + smokePart.CFrame:VectorToObjectSpace(wheel.Velocity)*dt
	end,
	stop = function()
		for _, wheel in next, car.Wheels:GetChildren() do
			if wheel:IsA("BasePart") == false then continue end
			if wheel:FindFirstChild("SmokePart") == nil then continue end
			for _, d in next, wheel.SmokePart:GetChildren() do
				if d:IsA("Sound") then d.Playing = false end
				if d:IsA("ParticleEmitter") then d.Enabled = false end
				if d:IsA("Trail") then d.Enabled = false end
			end
		end
	end,
}

script.Parent.OnServerEvent:Connect(function(player, func, ...)
	if functionTable[func] then
		functionTable[func](...)
	end
end)
