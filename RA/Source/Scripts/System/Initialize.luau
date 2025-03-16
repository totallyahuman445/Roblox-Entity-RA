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
			   
*I assume you know what you're doing if you're gonna change something here.* ]]--

--[[START]]

_BuildVersion = require(script.Parent.Version)

--[[Weld functions]]
local PGS_ON = workspace:PGSIsEnabled()
if not PGS_ON then
	error("RA no longer supports Legacy physics solving, sorry!")
end

function MakeWeld(x,y,type,s) 
	if type==nil then type="Weld" end
	local W=Instance.new(type,x) 
	W.Part0=x W.Part1=y 
	W.C0=x.CFrame:inverse()*x.CFrame 
	W.C1=y.CFrame:inverse()*x.CFrame 
	if type=="Motor" and s~=nil then 
		W.MaxVelocity=s 
	end 
	return W	
end

function ModelWeld(a,b) 
	if a:IsA("BasePart") then 
		MakeWeld(b,a,"Weld") 
	elseif a:IsA("Model") then 
		for i,v in pairs(a:GetChildren()) do 
			ModelWeld(v,b) 
		end 
	end 
end

function UnAnchor(a) 
	if a:IsA("BasePart") then a.Anchored=false  end for i,v in pairs(a:GetChildren()) do UnAnchor(v) end 
end

--[[Initialize]]
script.Parent:WaitForChild("Interface")
script.Parent:WaitForChild("Plugins")
script.Parent:WaitForChild("Version")

local car=script.Parent.Parent
local _Tune=require(script.Parent)
local Units = require(script.Parent.Units)


wait(_Tune.LoadDelay)

local Drive=car.Wheels:GetChildren()

--Remove Existing Mass
function DReduce(p)
	for i,v in pairs(p:GetDescendants())do
		if v:IsA("BasePart") then
			v.Massless = true --but it's just this line
		end
	end
end
DReduce(car)



--[[Wheel Configuration]]	

--Store Reference Orientation Function
function getParts(model,t,a)
	for i,v in pairs(model:GetChildren()) do
		if v:IsA("BasePart") then table.insert(t,{v,a.CFrame:toObjectSpace(v.CFrame)})
		elseif v:IsA("Model") then getParts(v,t,a)
		end
	end
end

function GetCarCenter(a)
	local centerF = Vector3.new()
	local centerR = Vector3.new()
	local countF = 0
	local countR = 0
	for i,v in next, car.Wheels:GetChildren() do
		if v.Name=="FL" or v.Name=="FR" or v.Name=="F" then
			centerF = centerF+v.CFrame.p
			countF = countF+1
		else
			centerR = centerR+v.CFrame.p
			countR = countR+1
		end
	end
	centerF = centerF/countF
	centerR = centerR/countR
	local center = CFrame.lookAt(centerR:Lerp(centerF,a or .5),centerF)
	return center
end

--PGS/Legacy
local fDistX=_Tune.FWsBoneLen*math.cos(math.rad(_Tune.FWsBoneAngle))
local fDistY=_Tune.FWsBoneLen*math.sin(math.rad(_Tune.FWsBoneAngle))
local rDistX=_Tune.RWsBoneLen*math.cos(math.rad(_Tune.RWsBoneAngle))
local rDistY=_Tune.RWsBoneLen*math.sin(math.rad(_Tune.RWsBoneAngle))

local fSLX=_Tune.FSusLength*math.cos(math.rad(_Tune.FSusAngle))
local fSLY=_Tune.FSusLength*math.sin(math.rad(_Tune.FSusAngle))
local rSLX=_Tune.RSusLength*math.cos(math.rad(_Tune.RSusAngle))
local rSLY=_Tune.RSusLength*math.sin(math.rad(_Tune.RSusAngle))

for _,v in pairs(Drive) do
	--Apply Wheel Density
	if v.Name=="FL" or v.Name=="FR" or v.Name=="F" then
		if v:IsA("BasePart") then
			if v.CustomPhysicalProperties == nil then v.CustomPhysicalProperties = PhysicalProperties.new(v.Material) end
			v.CustomPhysicalProperties = PhysicalProperties.new(
				(_Tune.FWheelWeight*Units.Mass_kg)/(math.pi*(v.Size.Y/2)^2*(v.Size.X)),
				v.CustomPhysicalProperties.Friction,
				v.CustomPhysicalProperties.Elasticity,
				v.CustomPhysicalProperties.FrictionWeight,
				v.CustomPhysicalProperties.ElasticityWeight
			)
		end
	else
		if v:IsA("BasePart") then
			if v.CustomPhysicalProperties == nil then v.CustomPhysicalProperties = PhysicalProperties.new(v.Material) end
			v.CustomPhysicalProperties = PhysicalProperties.new(
				(_Tune.RWheelWeight*Units.Mass_kg)/(math.pi*(v.Size.Y/2)^2*(v.Size.X)),
				v.CustomPhysicalProperties.Friction,
				v.CustomPhysicalProperties.Elasticity,
				v.CustomPhysicalProperties.FrictionWeight,
				v.CustomPhysicalProperties.ElasticityWeight
			)
		end		
	end

	--Resurface Wheels
	for _,a in pairs({"Top","Bottom","Left","Right","Front","Back"}) do
		v[a.."Surface"]=Enum.SurfaceType.SmoothNoOutlines
	end
	
	--Save wheel part positions
	local WParts = {}
	for _, a in next, v.Parts:GetDescendants() do
		if not a:IsA("BasePart") then continue end
		table.insert(WParts, {a, v.CFrame:ToObjectSpace(a.CFrame)})
	end
	for _, a in next, v.WheelFixed:GetDescendants() do
		if not a:IsA("BasePart") then continue end
		table.insert(WParts, {a, v.CFrame:ToObjectSpace(a.CFrame)})
	end

	--Align Wheels
	if v.Name=="FL" then
		v.CFrame = v.CFrame*CFrame.Angles(math.rad(_Tune.FCaster),math.rad(-_Tune.FToe),math.rad(_Tune.FCamber))
	elseif v.Name=="FR" then
		v.CFrame = v.CFrame*CFrame.Angles(math.rad(-_Tune.FCaster),math.rad(_Tune.FToe),math.rad(_Tune.FCamber))
	elseif v.Name=="RL" then
		v.CFrame = v.CFrame*CFrame.Angles(math.rad(_Tune.RCaster),math.rad(-_Tune.RToe),math.rad(_Tune.RCamber))
	elseif v.Name=="RR" then
		v.CFrame = v.CFrame*CFrame.Angles(math.rad(-_Tune.RCaster),math.rad(_Tune.RToe),math.rad(_Tune.RCamber))
	end
	
	for _, a in next, WParts do
		a[1].CFrame = v.CFrame*a[2]
	end

	--[[Chassis Assembly]]
	--Create Steering Axle
	local arm=Instance.new("Part",v)
	arm.Name="Arm"
	arm.Anchored=true
	arm.CanCollide=false
	arm.FormFactor=Enum.FormFactor.Custom
	arm.Size=Vector3.new(_Tune.AxleSize,_Tune.AxleSize,_Tune.AxleSize)
	arm.CFrame=v.CFrame
	arm.CustomPhysicalProperties = PhysicalProperties.new(math.clamp(_Tune.AxleDensity, 0.01, 100),0,0,100,100)
	arm.TopSurface=Enum.SurfaceType.Smooth
	arm.BottomSurface=Enum.SurfaceType.Smooth
	arm.Transparency=1

	--Create Wheel Spindle
	local base=arm:Clone()
	base.Parent=v
	base.Name="Base"
	base.CFrame=arm.CFrame*CFrame.new(0,_Tune.AxleSize,0)
	
	local SteerOuter = (_Tune.LockToLock*180)/_Tune.SteerRatio
	local SteerInner = math.min(SteerOuter-(SteerOuter*(1-_Tune.Ackerman)),SteerOuter*1.2)

	--Create Steering Anchor
	local axle=arm:Clone()
	axle.Parent=v
	axle.Name="Axle"
	axle.CFrame=v.CFrame*CFrame.new(v.Size.X/2+_Tune.AxleSize/2,0,0)
	axle.LeftSurface=Enum.SurfaceType.Hinge

	--Create Powered Axle
	local axlep=arm:Clone()
	axlep.Parent=v
	axlep.Name='AxleP'
	axlep.CFrame=v.CFrame*CFrame.Angles(0,math.rad((v.Name=="FR" or v.Name=="RR") and 0 or 180),0)
	MakeWeld(axlep,axle)

	--Create Suspension
	if _Tune.SuspensionEnabled==true then
		local SuspensionGeometry=v:FindFirstChild("SuspensionGeometry")
		if SuspensionGeometry then
			for _, a in next, SuspensionGeometry:GetDescendants() do
				if a.Name == "Weld" then
					if a:IsA("BasePart") then
						MakeWeld(a, car.DriveSeat)
					elseif a:IsA("Model") then
						ModelWeld(a, car.DriveSeat)
					end
				end
			end
			MakeWeld(SuspensionGeometry.Hub,base)
			if SuspensionGeometry:FindFirstChild("SpringTop") then
				MakeWeld(SuspensionGeometry.SpringTop, car.DriveSeat)
			end

			local susparts=SuspensionGeometry:GetDescendants()
			for _,p in pairs(susparts) do
				if p:IsA('Part') then
					if _Tune.CustomSuspensionDensity~=0 then
						p.CustomPhysicalProperties=PhysicalProperties.new(math.clamp(_Tune.CustomSuspensionDensity, 0.01, 100),0,0,0,0)
					else
						p.CustomPhysicalProperties=PhysicalProperties.new(math.clamp(_Tune.CustomSuspensionDensity, 0.01, 100),0,0,0,0)
						p.Massless=true
					end
				end
			end

			if _Tune.SusVisible==true then
				for _,p in pairs(susparts) do
					if p:IsA('Part') then
						p.Transparency=0
					elseif p:IsA("SpringConstraint") or p:IsA("HingeConstraint") or p:IsA("BallSocketConstraint") then
						p.Visible=true
					end
				end
			else
				for _,p in pairs(susparts) do
					if p:IsA('Part') then
						p.Transparency=1
					elseif p:IsA("SpringConstraint") or p:IsA("HingeConstraint") or p:IsA("BallSocketConstraint") then
						p.Visible=false
					end
				end
			end

			local g = Instance.new("BodyGyro",SuspensionGeometry.Hub)
			g.Name = "Stabilizer"
			g.MaxTorque = Vector3.new(0,0,1)
			g.P = 0

			sp=SuspensionGeometry:FindFirstChild('Spring')
			sp.LimitsEnabled = true
			sp.Visible=_Tune.SpringsVisible
			sp.Radius=_Tune.SusRadius
			sp.Thickness=_Tune.SusThickness
			sp.Color=BrickColor.new(_Tune.SusColor)
			sp.Coils=_Tune.SusCoilCount
			
			if v.Name == "FL" or v.Name=="FR" or v.Name =="F" then
				g.D = _Tune.FGyroDampening
				sp.Damping = _Tune.FSusDamping * Units.Damping_N_sdivm
				sp.Stiffness = _Tune.FSusStiffness * 9806.65 * Units.Stiffness_Ndivm -- 9806.65 converts kgf/mm to N/m
				sp.FreeLength = _Tune.FSusLength+_Tune.FPreCompress
				sp.MaxLength = _Tune.FSusLength+_Tune.FExtensionLim
				sp.MinLength = _Tune.FSusLength-_Tune.FCompressLim
			else
				g.D = _Tune.RGyroDampening
				sp.Damping = _Tune.RSusDamping * Units.Damping_N_sdivm
				sp.Stiffness = _Tune.RSusStiffness * 9806.65 * Units.Stiffness_Ndivm
				sp.FreeLength = _Tune.RSusLength+_Tune.RPreCompress
				sp.MaxLength = _Tune.RSusLength+_Tune.RExtensionLim
				sp.MinLength = _Tune.RSusLength-_Tune.RCompressLim
			end
		else
			local legacyCFrame = v.CFrame*CFrame.Angles(math.rad(90),0,math.rad(90)) -- not gonna bother fixing the entire thing so i just put this because it works
			
			local sa=arm:Clone()
			sa.Parent=v
			sa.Name="#SA"
			sa.CFrame = (legacyCFrame)*CFrame.Angles(-math.pi/2,-math.pi/2,0)
			if v.Name == "FL" or v.Name=="FR" or v.Name =="F" then
				local aOff = _Tune.FAnchorOffset
				sa.CFrame=legacyCFrame*CFrame.new(_Tune.AxleSize/2,-fDistX,-fDistY)*CFrame.new(aOff[3],aOff[1],-aOff[2])*CFrame.Angles(-math.pi/2,-math.pi/2,0)
			else
				local aOff = _Tune.RAnchorOffset
				sa.CFrame=legacyCFrame*CFrame.new(_Tune.AxleSize/2,-rDistX,-rDistY)*CFrame.new(aOff[3],aOff[1],-aOff[2])*CFrame.Angles(-math.pi/2,-math.pi/2,0)
			end

			local sb=sa:Clone()
			sb.Parent=v
			sb.Name="#SB"
			sb.CFrame=sa.CFrame*CFrame.new(0,0,_Tune.AxleSize)
			sb.FrontSurface=Enum.SurfaceType.Hinge	

			local g = Instance.new("BodyGyro",sb)
			g.Name = "Stabilizer"
			g.MaxTorque = Vector3.new(0,0,1)
			g.P = 0

			local sf1 = Instance.new("Attachment",sa)
			sf1.Name = "SAtt"

			local sf2 = sf1:Clone()
			sf2.Parent = sb

			-- adds spring offset
			if v.Name == "FL" or v.Name == "FR" or v.Name == "F" then
				local aOff = _Tune.FSpringOffset
				if v.Name == "FL" then
					sf1.Position = Vector3.new(fDistX-fSLX+aOff[1],-fDistY+fSLY+aOff[2],_Tune.AxleSize/2+aOff[3])
					sf2.Position = Vector3.new(fDistX+aOff[1],-fDistY+aOff[2],-_Tune.AxleSize/2+aOff[3])
				else
					sf1.Position = Vector3.new(fDistX-fSLX+aOff[1],-fDistY+fSLY+aOff[2],_Tune.AxleSize/2-aOff[3])
					sf2.Position = Vector3.new(fDistX+aOff[1],-fDistY+aOff[2],-_Tune.AxleSize/2-aOff[3])
				end
			elseif v.Name == "RL" or v.Name=="RR" or v.Name == "R" then
				local aOff = _Tune.RSpringOffset
				if v.Name == "RL" then
					sf1.Position = Vector3.new(rDistX-rSLX+aOff[1],-rDistY+rSLY+aOff[2],_Tune.AxleSize/2+aOff[3])
					sf2.Position = Vector3.new(rDistX+aOff[1],-rDistY+aOff[2],-_Tune.AxleSize/2+aOff[3])
				else
					sf1.Position = Vector3.new(rDistX-rSLX+aOff[1],-rDistY+rSLY+aOff[2],_Tune.AxleSize/2-aOff[3])
					sf2.Position = Vector3.new(rDistX+aOff[1],-rDistY+aOff[2],-_Tune.AxleSize/2-aOff[3])
				end
			end

			sb:MakeJoints()
			--there was axle:makejoints here I believe, but the new powered axle manually welds itself so I ditched it

			local sp = Instance.new("SpringConstraint",v)
			sp.Name = "Spring"
			sp.Attachment0 = sf1
			sp.Attachment1 = sf2
			sp.LimitsEnabled = true

			sp.Visible=_Tune.SusVisible
			sp.Radius=_Tune.SusRadius
			sp.Thickness=_Tune.SusThickness
			sp.Color=BrickColor.new(_Tune.SusColor)
			sp.Coils=_Tune.SusCoilCount

			if v.Name == "FL" or v.Name=="FR" or v.Name =="F" then
				g.D = _Tune.FGyroDampening
				sp.Damping = _Tune.FSusDamping * Units.Damping_N_sdivm
				sp.Stiffness = _Tune.FSusStiffness * 9806.65 * Units.Stiffness_Ndivm
				sp.FreeLength = _Tune.FSusLength+_Tune.FPreCompress
				sp.MaxLength = _Tune.FSusLength+_Tune.FExtensionLim
				sp.MinLength = _Tune.FSusLength-_Tune.FCompressLim
			else
				g.D = _Tune.RGyroDampening
				sp.Damping = _Tune.RSusDamping * Units.Damping_N_sdivm
				sp.Stiffness = _Tune.RSusStiffness * 9806.65 * Units.Stiffness_Ndivm
				sp.FreeLength = _Tune.RSusLength+_Tune.RPreCompress
				sp.MaxLength = _Tune.RSusLength+_Tune.RExtensionLim
				sp.MinLength = _Tune.RSusLength-_Tune.RCompressLim
			end

			MakeWeld(car.DriveSeat,sa)
			MakeWeld(sb,base)
		end
		v.Massless=false
	else
		MakeWeld(car.DriveSeat,base)
	end

	--Lock Rear Steering Axle
	if _Tune.FWSteer=='Static' or _Tune.FWSteer=='Speed' or _Tune.FWSteer=='Both' then
	else
		if v.Name == "RL" or v.Name == "RR" or v.Name=="R" then
			MakeWeld(base,axle)
		end
	end

	MakeWeld(arm,axle)

	arm:MakeJoints()

	--Weld Miscelaneous Parts
	if v:FindFirstChild("SuspensionFixed")~=nil then
		ModelWeld(v.SuspensionFixed,car.DriveSeat)
	end
	if v:FindFirstChild("WheelFixed")~=nil then
		ModelWeld(v.WheelFixed,axle)
	end
	if v:FindFirstChild("Fixed")~=nil then
		ModelWeld(v.Fixed,arm)
	end

	--Weld Wheel Parts
	if v:FindFirstChild("Parts")~=nil then
		ModelWeld(v.Parts,v)
	end

	--Add Steering Gyro
	if v:FindFirstChild("Steer") then
		v:FindFirstChild("Steer"):Destroy()
	end
	
	if v.Name=='FR' or v.Name=='FL' or v.Name=='F' then
		local steer=Instance.new("BodyGyro",arm)
		steer.Name="Steer"
		steer.P=_Tune.SteerP
		steer.D=_Tune.SteerD
		steer.MaxTorque=Vector3.new(0,_Tune.SteerMaxTorque,0)
		steer.cframe=v.CFrame
	else
		if (_Tune.FWSteer=='Static' or _Tune.FWSteer=='Speed' or _Tune.FWSteer=='Both') then
			local steer=Instance.new("BodyGyro",arm)
			steer.Name="Steer"
			steer.P=_Tune.SteerP
			steer.D=_Tune.SteerD
			steer.MaxTorque=Vector3.new(0,_Tune.SteerMaxTorque,0)
			steer.cframe=v.CFrame
		end
	end
	--Add Stabilization Gyro
	local gyro=Instance.new("BodyGyro",v)
	gyro.Name="Stabilizer"
	gyro.MaxTorque=Vector3.new(1,0,1)
	gyro.P=0
	if v.Name=="FL" or v.Name=="FR"  or v.Name=="F" then
		gyro.D=_Tune.FGyroDamp
	else
		gyro.D=_Tune.RGyroDamp
	end
	
	--Add rotation constraint
	local rotationAttachment0 = Instance.new("Attachment", base)
	rotationAttachment0.Name = "RotationAttachment0"
	rotationAttachment0.Position = Vector3.new(0, -_Tune.AxleSize/2, 0)
	rotationAttachment0.Orientation = Vector3.new(0, 0, 90)
	local rotationAttachment1 = Instance.new("Attachment", arm)
	rotationAttachment1.Name = "RotationAttachment1"
	rotationAttachment1.Position = Vector3.new(0, _Tune.AxleSize/2, 0)
	rotationAttachment1.Orientation = Vector3.new(0, 0, 90)
	local rotationHinge = Instance.new("HingeConstraint", base)
	rotationHinge.Name = "Rotate"
	rotationHinge.LimitsEnabled = true
	rotationHinge.UpperAngle = math.max(SteerOuter, SteerInner)
	if v.Name == "RL" or v.Name == "RR" or v.Name == "R" then
		rotationHinge.UpperAngle = math.max(_Tune.RSteerOuter, _Tune.RSteerInner)
	end
	rotationHinge.LowerAngle = -rotationHinge.UpperAngle
	rotationHinge.Attachment0 = rotationAttachment0
	rotationHinge.Attachment1 = rotationAttachment1

	--Add Motors
	local AV=Instance.new("HingeConstraint",v)
	AV.ActuatorType='Motor'
	AV.Attachment0=Instance.new("Attachment",v.AxleP)
	v.AxleP.Attachment.Name='AA'
	AV.Attachment1=Instance.new("Attachment",v)
	AV.Attachment1.Orientation = Vector3.new(0, (v.Name=="FR" or v.Name=="RR") and 0 or 180, 0)
	v.Attachment.Name='AB'
	AV.Name="#AV"
	AV.AngularVelocity=0
	AV.MotorMaxTorque=0

	local BV=Instance.new("HingeConstraint",v)
	BV.ActuatorType='Motor'
	BV.Attachment0=Instance.new("Attachment",v.AxleP)
	v.AxleP.Attachment.Name='BA'
	BV.Attachment1=Instance.new("Attachment",v)
	BV.Attachment1.Orientation = Vector3.new(0, (v.Name=="FR" or v.Name=="RR") and 0 or 180, 0)
	v.Attachment.Name='BB'
	BV.Name="#BV"
	BV.AngularVelocity=0
	BV.MotorMaxTorque=_Tune.PBrakeForce * 9.80665 * Units.Force_N
end

--[[Vehicle Weight]]	
--Determine Current Mass
local mass=0

function getMass(p)
	for i,v in pairs(p:GetChildren())do
		if v:IsA("BasePart") and not v.Massless then
			mass=mass+v:GetMass()
		end
		getMass(v)
	end	
end
getMass(car)

--Apply Vehicle Weight
if mass<_Tune.Weight/2.205/8 then
	--Calculate Weight Distribution
	local centerF = Vector3.new()
	local centerR = Vector3.new()
	local countF = 0
	local countR = 0

	for i,v in pairs(Drive) do
		if v.Name=="FL" or v.Name=="FR" or v.Name=="F" then
			centerF = centerF+v.CFrame.p
			countF = countF+1
		else
			centerR = centerR+v.CFrame.p
			countR = countR+1
		end
	end
	centerF = centerF/countF
	centerR = centerR/countR
	local center = centerR:Lerp(centerF, _Tune.WeightDist/100)  

	--Create Weight Brick
	local weightB = Instance.new("Part",car.Body)
	weightB.Name = "#Weight"
	weightB.Anchored = true
	weightB.CanCollide = false
	weightB.BrickColor = BrickColor.new("Really black")
	weightB.TopSurface = Enum.SurfaceType.Smooth
	weightB.BottomSurface = Enum.SurfaceType.Smooth
	if _Tune.WBVisible then
		weightB.Transparency = .75			
	else
		weightB.Transparency = 1			
	end

	weightB.Size = Vector3.new(_Tune.WeightBSize[1],_Tune.WeightBSize[2],_Tune.WeightBSize[3])/Units.Length_mm
	local tdensity=(_Tune.Weight-mass*Units.Mass_kg)/(_Tune.WeightBSize[1]*_Tune.WeightBSize[2]*_Tune.WeightBSize[3]/1000)*1000
	weightB.CustomPhysicalProperties = PhysicalProperties.new(tdensity,0,0,0,0)
	--Real life mass in kg minus existing roblox mass converted to kg, divided by volume of the weight brick in cubic metres, divided by the density of water
	weightB.CFrame=(car.DriveSeat.CFrame-car.DriveSeat.Position+center)*CFrame.new(0,_Tune.CGHeight,0)

	--Density Cap
	if weightB.CustomPhysicalProperties.Density>=2 then
		warn( "\n\t [RA ".._BuildVersion.."]: Density too high for specified volume."
			.."\n\t Current Density:\t"..math.ceil(tdensity)
			.."\n\t Max Density:\t"..math.ceil(weightB.CustomPhysicalProperties.Density)
			.."\n\t Increase weight brick size to compensate.")
	end
else
	--Existing Weight Is Too Massive
	warn( "\n\t [RA ".._BuildVersion.."]: Mass too high for specified weight."
		.."\n\t    Target Mass:\t"..math.ceil((_Tune.Weight*2.205)*8)
		.."\n\t    Current Mass:\t"..math.ceil(mass)
		.."\n\t Reduce part size or axle density to achieve desired weight.")
end

-- Gravcomp
for _, object in next, car:GetDescendants() do
	if not object:IsA("BasePart") then continue end
	if object.Massless == false then
		local attachment = Instance.new("Attachment", object)
		attachment.Name = "#FORCE_ATTACH"
		local force = Instance.new("VectorForce", object)
		force.Name = "#FORCE"
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.Attachment0 = attachment
		force.Force = Vector3.new(0, 0 > 0 and object.Mass*(workspace.Gravity) or 0, 0)
	end
end

-- Unanchor, no collide
for _, object in next, car:GetDescendants() do
	if not object:IsA("BasePart") then continue end
	for _, wheel in next, car.Wheels:GetChildren() do
		if wheel == object then continue end
		if object.CanCollide == false then continue end

		local noCollision = Instance.new("NoCollisionConstraint", object)
		noCollision.Part0 = object
		noCollision.Part1 = wheel
	end
end

local flipG = Instance.new("BodyGyro",car.DriveSeat)
flipG.Name = "Flip"
flipG.D = 0
flipG.MaxTorque = Vector3.new(0,0,0)
flipG.P = 0

--[[Finalize Chassis]]	
--Misc Weld
wait()
for i,v in pairs(script:GetChildren()) do
	if v:IsA("ModuleScript") then
		require(v)
	end
end

--Weld Body
wait()
ModelWeld(car.Body,car.DriveSeat)

--Unanchor
wait()	
UnAnchor(car)

--[[Manage Plugins]]
script.Parent["Interface"].Car.Value=car
for i,v in pairs(script.Parent.Plugins:GetChildren()) do
	for _,a in pairs(v:GetChildren()) do
		if a:IsA("RemoteEvent") or a:IsA("RemoteFunction") then 
			a.Parent=car
			for _,b in pairs(a:GetChildren()) do
				if b:IsA("Script") then b.Disabled=false end
			end	
		end
	end
	v.Parent = script.Parent["Interface"]
end
script.Parent.Plugins:Destroy()

--[[Remove Character Weight]]
--Get Seats
local Seats = {}
function getSeats(p)
	for i,v in pairs(p:GetChildren()) do
		if v:IsA("VehicleSeat") or v:IsA("Seat") then
			local seat = {}
			seat.Seat = v
			seat.Parts = {}
			table.insert(Seats,seat)
		end
		getSeats(v)
	end	
end
getSeats(car)

--Store Physical Properties/Remove Mass Function
function getPProperties(mod,t)
	for i,v in pairs(mod:GetChildren()) do
		if v:IsA("BasePart") then
			if v.CustomPhysicalProperties == nil then v.CustomPhysicalProperties = PhysicalProperties.new(v.Material) end
			table.insert(t,{v,v.CustomPhysicalProperties})
			v.Massless = true
		end
		getPProperties(v,t)
	end			
end


--[[Driver Handling]]

--Driver Sit
car.DriveSeat:SetNetworkOwner(nil)
car.DriveSeat.ChildAdded:connect(function(child)
	if child.Name=="SeatWeld" and child:IsA("Weld") and game.Players:GetPlayerFromCharacter(child.Part1.Parent)~=nil then
		--Distribute Client Interface
		local p=game.Players:GetPlayerFromCharacter(child.Part1.Parent)
		car.DriveSeat:SetNetworkOwner(p)
		local mouseLockAlreadyEnabled = p.DevEnableMouseLock
		p.DevEnableMouseLock = false
		local g=script.Parent["Interface"]:Clone()
		g.Parent=p.PlayerGui
		if _Tune.ExitStop == true then
			local leave
			leave = car.DriveSeat.ChildRemoved:Connect(function(child)
				if child:IsA("Weld") and child.Name == "SeatWeld" then
					leave:Disconnect()
					for _,v in next, p.PlayerGui:GetChildren() do
						if v:IsA("ScreenGui") and v.Name == "Interface" then
							for _, v in next, v:GetDescendants() do
								if v:IsA("Script") then v.Disabled = true end
							end
							v:Destroy()
						end
					end
					car.DriveSeat:SetNetworkOwner(nil)
					p.DevEnableMouseLock = mouseLockAlreadyEnabled
				end
			end) --(remove gui on the server to prevent possible memory buildup)
		end
	end
end)

--Driver Leave
car.DriveSeat.ChildRemoved:connect(function(child)
	if child.Name=="SeatWeld" and child:IsA("Weld") then
		--Remove Flip Force
		if car.DriveSeat:FindFirstChild("Flip")~=nil then
			car.DriveSeat.Flip.MaxTorque = Vector3.new()
		end
		--Remove Wheel Force
		for i,v in next, car.Wheels:GetChildren() do
			if v:FindFirstChild("#AV")~=nil then
				if v["#AV"]:IsA("BodyAngularVelocity") then
					if v["#AV"].AngularVelocity.Magnitude>0 then
						v["#AV"].AngularVelocity = Vector3.new()
						v["#AV"].MaxTorque = Vector3.new()
					end
				else
					if v["#AV"].AngularVelocity>0 then
						v["#AV"].AngularVelocity = 0
						v["#AV"].MotorMaxTorque = 1e9
					end
				end
			end
		end
		--Fix steering
		for i,v in next, car.Wheels:GetChildren() do
			if v.Arm:FindFirstChild("Steer") then
				v.Arm.Steer.CFrame = v.Arm.CFrame
			end
		end
	end
end)