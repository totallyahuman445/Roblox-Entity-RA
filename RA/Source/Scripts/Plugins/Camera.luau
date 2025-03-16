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

-- Math Functions and Constants
local MIN = math.min
local MAX = math.max 

local RANDOM = math.random

local EXP = math.exp

local SQRT = math.sqrt

local SIN = math.sin 
local COS = math.cos 
local ACOS = math.acos
local ATAN2 = math.atan2
local PI = math.pi

local VEC3 = Vector3.new 
local CF = CFrame.new

local COMPONENTS = CF().components

local CAMERA_TYPE = Enum.CameraType.Scriptable

local mouseon = false

-- Settings
local Settings = {
	DEFAULT_VIEW_MODE = 0, --0: TPV, 1: FPV 

	TOP_SPEED_THRESHOLD = 300, 

	TPV_ORIGIN_OFFSET_X = 0,
	TPV_ORIGIN_OFFSET_Y = 3,
	TPV_ORIGIN_OFFSET_Z = 0,

	TPV_OFFSET_Y = 3.5,

	TPV_OFFSET_MIN = 22, --studs magnitude
	TPV_OFFSET_MAX = 22,
	TPV_OFFSET_GROWTH = 0, --studs per unit velocity

	TPV_ROTATION_SPEED = 4.4, 

	MANUAL_ROTATION_MIN = -PI / 3,
	MANUAL_ROTATION_MAX = 4 * PI / 3,
	MANUAL_ROTATION_SPEED = 0.05,

	TPV_TILT_MAX = PI / 15,
	TPV_TILT_SPEED = .2,
	TPV_TILT_RETURN_SPEED = 1,

	TPV_VERTICLE_FREQ = 12,
	TPV_VERTICLE_DAMP = 0.35,

	FPV_OFFSET_Y = 2.8,

	FPV_OFFSET_MIN = -0.25,
	FPV_OFFSET_MAX = 0.2,

	FPV_ROTATION_SPEED = 2.2,

	FPV_ROTATION_Y_GROWTH = 0,
	FPV_ROTATION_X_GROWTH = 0,

	FPV_ROTATION_X_DAMP = 0.35,
	FPV_ROTATION_X_FREQ = 17,

	FPV_ROTATION_Y_MIN = PI / 4,
	FPV_ROTATION_Y_MAX = 3 * PI / 4,
	FPV_ROTATION_X_MIN = -PI / 7,
	FPV_ROTATION_X_MAX = PI / 7,

	WIND_SHAKE_FREQUENCY_MAX = 0.6, -- Speed of camera shake
	WIND_SHAKE_FREQUENCY_GROWTH = 0.00004, -- How speed of camera shake increases with speed
	WIND_SHAKE_AMPLITUDE_MAX = 0.15, -- Camera Shake Max
	WIND_SHAKE_AMPLITUDE_GROWTH = 0.00006, -- How much camera shake increases with speed

	COLLISION_BUMP_MAX = 0,
	COLLISION_BUMP_GROWTH = 0.0008,
	COLLISION_BUMP_THRESHOLD = 600,
	COLLISION_BUMP_DELAY = 0.07,
	COLLISION_BUMP_FREQ = 15, 
	COLLISION_BUMP_DAMP = 0.3
}

-- Services and instances
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Player = game:GetService("Players").LocalPlayer
local Camera = workspace.CurrentCamera
local Car = script.Parent:WaitForChild("Car").Value
local DriverSeat = Car:WaitForChild("DriveSeat")
local Gear = script.Parent:WaitForChild("Values"):WaitForChild("Gear")
local viewMode = Settings.DEFAULT_VIEW_MODE 

local currentGear = Gear.Value

local rotatingManually = false

local forwardVelocity = 0
local horizontalVelocity = 0

local collisionBump = 0
local collisionBumpTarget = 0
local collisionBumpVelocity = 0
local collisionBumpTimestamp

local mousePositionX = 0
local mousePositionY = 0

local tpvRotation = PI / 2
local tpvRotationTarget -- only used for manual rotation
local tpvTilt = 0

local tpvOffset = Settings.TPV_OFFSET_MIN
local tpvOffsetTarget = Settings.TPV_OFFSET_MIN
local tpvOffsetVelocity = 0

local tpvVerticleVelocity = 0
local tpvVerticlePosition = DriverSeat.Position.Y

local fpvRotationY = PI / 2
local fpvRotationX = 0

local fpvRotationYTarget = fpvRotationY
local fpvRotationXTarget = fpvRotationX

local fpvRotationXVelocity = 0

local fpvOffset = Settings.FPV_OFFSET_MIN
local fpvOffsetTarget = Settings.FPV_OFFSET_MIN

local ox, oy, oz, oxx, oyx, ozx, oxy, oyy, ozy, oxz, oyz, ozz = COMPONENTS(DriverSeat.CFrame)
local cx, cy, cz, cxx, cyx, czx, cxy, cyy, czy, cxz, cyz, czz = ox, oy, oz, oxx, oyx, ozx, oxy, oyy, ozy, oxz, oyz, ozz

local function setCharacterTransparency(t)
	for _, k in pairs(Player.Character:GetChildren()) do
		if (k:IsA("BasePart")) then 
			k.LocalTransparencyModifier = t
		elseif (k:IsA("Accessory")) then 
			k:WaitForChild("Handle").LocalTransparencyModifier = t
		end
	end
end

local function updateSpring(dt, position, target, velocity, dampening, frequency)
	local x = position - target
	local omegaZeta = frequency * dampening
	local alpha = frequency * SQRT(1 - dampening * dampening)
	local exp = EXP(-dt * omegaZeta)
	local cos = COS(dt * alpha) 
	local sin = SIN(dt * alpha)
	local c2 = (velocity + x * omegaZeta) / alpha
	local newPosition = target + exp * (x * cos + c2 * sin)
	local newVelocity = -exp * ((x * omegaZeta - c2 * alpha) * cos + (x * alpha + c2 * omegaZeta) * sin)
	return newPosition, newVelocity
end

local function isFinite(k)
	return(k == k and k ~= math.huge and k ~= -math.huge)
end

local function getYAngleBetween(x1, z1, x2, z2)
	return(ATAN2(x2 * z1 - z2 * x1, x2 * x1 + z2 * z1))
end

script.Parent.Values.MouseSteerOn.Changed:connect(function(property)
	if script.Parent.Values.MouseSteerOn.Value == true then
		mouseon = true
	else
		mouseon = false
	end
end)
UserInputService.InputBegan:connect(function(inputObject, inputProcessed)
	if mouseon == false then
		if (inputObject.UserInputType == Enum.UserInputType.MouseButton2) then 
			tpvRotationTarget = tpvRotation
			local newMousePosition = UserInputService:GetMouseLocation()
			mousePositionX = newMousePosition.X
			mousePositionY = newMousePosition.Y
			rotatingManually = true
		elseif (rotatingManually == false) and (inputObject.UserInputType == Enum.UserInputType.Keyboard) then 
			if (inputObject.KeyCode == Enum.KeyCode.V) then 
				if (viewMode == 0) then 
					viewMode = 1
					setCharacterTransparency(1)
				else
					viewMode = 0
					setCharacterTransparency(0)
				end
			end
		end
	end
end)

UserInputService.InputEnded:connect(function(inputObject, inputProcessed)
	if (inputObject.UserInputType == Enum.UserInputType.MouseButton2) then 
		rotatingManually = false
		fpvRotationYTarget = PI / 2
		fpvRotationXTarget = 0
	end
end)

UserInputService.InputChanged:connect(function(inputObject, inputProcessed)
	if (inputObject.UserInputType == Enum.UserInputType.MouseMovement) then 
		if (rotatingManually) then 
			local newMousePosition = UserInputService:GetMouseLocation()
			if (viewMode == 0) then 
				tpvRotationTarget = tpvRotation + Settings.MANUAL_ROTATION_SPEED * (newMousePosition.X - mousePositionX)
			elseif (viewMode == 1) then 
				fpvRotationYTarget = fpvRotationYTarget + Settings.FPV_ROTATION_Y_GROWTH * (newMousePosition.X - mousePositionX)
				fpvRotationXTarget = fpvRotationXTarget + Settings.FPV_ROTATION_X_GROWTH * (mousePositionY - newMousePosition.Y)
				if (fpvRotationYTarget > Settings.FPV_ROTATION_Y_MAX) then 
					fpvRotationYTarget = Settings.FPV_ROTATION_Y_MAX
				elseif (fpvRotationYTarget < Settings.FPV_ROTATION_Y_MIN) then 
					fpvRotationYTarget = Settings.FPV_ROTATION_Y_MIN
				end
				if (fpvRotationXTarget > Settings.FPV_ROTATION_X_MAX) then 
					fpvRotationXTarget = Settings.FPV_ROTATION_X_MAX
				elseif (fpvRotationXTarget < Settings.FPV_ROTATION_X_MIN) then 
					fpvRotationXTarget = Settings.FPV_ROTATION_X_MIN
				end
			end		
			mousePositionX = newMousePosition.X
			mousePositionY = newMousePosition.Y	
		end
	end
end)

local function updateManualRotation(dt)
	tpvRotation = tpvRotation + dt * Settings.TPV_ROTATION_SPEED * (tpvRotationTarget - tpvRotation)
	tpvVerticlePosition = oy
end

local function updateDynamicRotation(dt)
	local velocity = DriverSeat.Velocity
	local vx, vy, vz = velocity.X, velocity.Y, velocity.Z
	local speed = SQRT(vx * vx + vy * vy + vz * vz)
	local newForwardVelocity = (vx * ozx + vy * ozy + vz * ozz) * -1
	local newHorizontalVelocity = vx * oxx + vy * oxy + vz * oxz
	local forwardAcceleration = (newForwardVelocity - forwardVelocity) / dt
	local horizontalAcceleration = (newHorizontalVelocity - horizontalVelocity) / dt
	forwardVelocity = newForwardVelocity
	horizontalVelocity = newHorizontalVelocity
	if (viewMode == 0) then 
		--Handle verticle damping
		local rxd = tpvVerticlePosition - oy
		local omz = Settings.TPV_VERTICLE_FREQ * Settings.TPV_VERTICLE_DAMP
		local alp = Settings.TPV_VERTICLE_FREQ * SQRT(1 - Settings.TPV_VERTICLE_DAMP * Settings.TPV_VERTICLE_DAMP)
		local exp = EXP(-dt * omz)
		local cos = COS(dt * alp) 
		local sin = SIN(dt * alp)
		local c2 = (tpvVerticleVelocity + rxd * omz) / alp
		tpvVerticlePosition = oy + exp * (rxd * cos + c2 * sin)
		tpvVerticleVelocity = -exp * ((rxd * omz - c2 * alp) * cos + (rxd * alp + c2 * omz) * sin)
		oy = tpvVerticlePosition
		--Handle collision bumps
		if (collisionBumpTimestamp ~= nil) and (tick() - collisionBumpTimestamp > Settings.COLLISION_BUMP_DELAY) then 
			if (collisionBump < collisionBumpTarget) then 
				collisionBump = MIN(collisionBumpTarget, collisionBump + dt * 12)
			elseif (collisionBump > collisionBumpTarget) then 
				collisionBump = MAX(collisionBumpTarget, collisionBump - dt * 12)
			else 
				collisionBumpTarget = 0
				collisionBumpTimestamp = nil
			end
		elseif (collisionBumpTimestamp == nil) then 
			--Move toward 0 with spring
			local rxd = collisionBump - collisionBumpTarget
			local omz = Settings.COLLISION_BUMP_FREQ * Settings.COLLISION_BUMP_DAMP
			local alp = Settings.COLLISION_BUMP_FREQ * SQRT(1 - Settings.COLLISION_BUMP_DAMP * Settings.COLLISION_BUMP_DAMP)
			local exp = EXP(-dt * omz)
			local cos = COS(dt * alp) 
			local sin = SIN(dt * alp)
			local c2 = (collisionBumpVelocity + rxd * omz) / alp
			collisionBump = collisionBumpTarget + exp * (rxd * cos + c2 * sin)
			collisionBumpVelocity = -exp * ((rxd * omz - c2 * alp) * cos + (rxd * alp + c2 * omz) * sin)
			--Check if we have a new collision
			if (horizontalAcceleration > Settings.COLLISION_BUMP_THRESHOLD) then
				collisionBumpVelocity = 0
				collisionBumpTarget = MIN(Settings.COLLISION_BUMP_MAX, horizontalAcceleration * Settings.COLLISION_BUMP_GROWTH)
				collisionBumpTimestamp = tick()
			elseif (horizontalAcceleration < -Settings.COLLISION_BUMP_THRESHOLD) then 
				collisionBumpVelocity = 0
				collisionBumpTarget = MAX(-Settings.COLLISION_BUMP_MAX, horizontalAcceleration * Settings.COLLISION_BUMP_GROWTH)
				collisionBumpTimestamp = tick()
			end
		end
		ox = ox + collisionBump * oxx
		oy = oy + collisionBump * 0.5
		oz = oz + collisionBump * oxz 
		--Apply wind shake
		local amplitude = MIN(Settings.WIND_SHAKE_AMPLITUDE_MAX, newForwardVelocity * Settings.WIND_SHAKE_AMPLITUDE_GROWTH)
		local frequency = MIN(Settings.WIND_SHAKE_FREQUENCY_MAX, newForwardVelocity * Settings.WIND_SHAKE_FREQUENCY_GROWTH)
		local t = tick()
		ox = ox + amplitude * COS(frequency * t)
		oy = oy + amplitude * SIN(frequency * t)
		oz = oz + amplitude * COS(frequency * t)
	end
	--Set TPV Offset
	if (DriverSeat.Throttle == -1) then 
		tpvOffsetTarget = Settings.TPV_OFFSET_MIN * 0.95
		tpvOffset = tpvOffset + dt * 2.5 * (tpvOffsetTarget - tpvOffset)
	elseif (newForwardVelocity < Settings.TOP_SPEED_THRESHOLD and forwardAcceleration < 0) then 
		tpvOffsetTarget = Settings.TPV_OFFSET_MIN
		tpvOffset = tpvOffset + dt * 2 * (tpvOffsetTarget - tpvOffset)
	else 
		tpvOffsetTarget = MIN(Settings.TPV_OFFSET_MAX, Settings.TPV_OFFSET_MIN + Settings.TPV_OFFSET_GROWTH * speed)
		tpvOffset = tpvOffset + dt * 2.5 * (tpvOffsetTarget - tpvOffset)
	end
	--Set FPV Offset
	fpvOffsetTarget = forwardAcceleration 
	if (fpvOffsetTarget > Settings.FPV_OFFSET_MAX) then 
		fpvOffsetTarget = Settings.FPV_OFFSET_MAX
	elseif (fpvOffsetTarget < Settings.FPV_OFFSET_MIN) then 
		fpvOffsetTarget = Settings.FPV_OFFSET_MIN
	end
	fpvRotationXTarget = -ACOS(oyy)
	if (fpvRotationXTarget > Settings.FPV_ROTATION_X_MAX) then 
		fpvRotationXTarget = Settings.FPV_ROTATION_X_MAX
	elseif (fpvRotationXTarget < Settings.FPV_ROTATION_X_MIN) then 
		fpvRotationXTarget = Settings.FPV_ROTATION_X_MIN
	end
	fpvOffset = fpvOffset + dt * 0.5 * (fpvOffsetTarget - fpvOffset)
	--TPV Rotation and Tilt
	if (speed > 1) and (DriverSeat.Steer == 1) then 
		tpvTilt = tpvTilt + dt * Settings.TPV_TILT_SPEED * (Settings.TPV_TILT_MAX - tpvTilt) * (Settings.TPV_TILT_MAX - tpvTilt)
	elseif (speed > 1) and (DriverSeat.Steer == -1) then 
		tpvTilt = tpvTilt - dt * Settings.TPV_TILT_SPEED * (Settings.TPV_TILT_MAX + tpvTilt) * (Settings.TPV_TILT_MAX + tpvTilt)
	else 
		tpvTilt = tpvTilt - dt * Settings.TPV_TILT_RETURN_SPEED * tpvTilt
	end	
	local rotationOffset = getYAngleBetween(-ozx, -ozz, -czx, -czz)
	if (isFinite(rotationOffset) and math.abs(rotationOffset) > 0.0001) then 
		tpvRotation = tpvRotation + rotationOffset * dt * Settings.TPV_ROTATION_SPEED
	end
end

local function updateTPV(dt)
	--Fix up the origin axis
	local ozm = SQRT(ozx * ozx + ozz * ozz)
	ozx, ozy, ozz = ozx / ozm, 0, ozz / ozm
	oyx, oyy, oyz = 0, 1, 0
	--Get new right vector
	oxx = ozz 
	oxy = 0
	oxz = -ozx
	--Adjust trail origin
	ox = ox + Settings.TPV_ORIGIN_OFFSET_X * oxx + Settings.TPV_ORIGIN_OFFSET_Z * ozx
	oy = oy + Settings.TPV_ORIGIN_OFFSET_Y
	oz = oz + Settings.TPV_ORIGIN_OFFSET_X * oxz + Settings.TPV_ORIGIN_OFFSET_Z * ozz
	--Set Camera Back Vector
	czx = COS(tpvRotation) * tpvOffset
	czy = Settings.TPV_OFFSET_Y
	czz = SIN(tpvRotation) * tpvOffset
	local czm = SQRT(czx * czx + czy * czy + czz * czz)
	czx, czy, czz = czx / czm, czy / czm, czz / czm		
	--Set Camera Right Vector
	cxx = SIN(tpvRotation)
	cxy = 0
	cxz = -COS(tpvRotation)		
	--Rotate Camera Right Vector(tilt)
	cxx = cxx * COS(tpvTilt) + (czy * cxz) * SIN(tpvTilt)		
	cxy = (czz * cxx - czx * cxz) * SIN(tpvTilt)		
	cxz = cxz * COS(tpvTilt) - (czy * cxx) * SIN(tpvTilt)		
	local cxm = SQRT(cxx * cxx + cxy * cxy + cxz * cxz)
	cxx, cxy, cxz = cxx / cxm, cxy / cxm, cxz / cxm
	--Set Camera Up Vector
	cyx = czy * cxz - czz * cxy
	cyy = czz * cxx - czx * cxz
	cyz = czx * cxy - czy * cxx
	local cym = SQRT(cyx * cyx + cyy * cyy + cyz * cyz)
	cyx, cyy, cyz = cyx / cym, cyy / cym, cyz / cym
	--Set Camera Position
	cx = ox + czx * czm
	cy = oy + czy * czm
	cz = oz + czz * czm
end

local function updateFPV(dt)
	tpvVerticlePosition = oy
	--Spring stuff
	if (rotatingManually == false) then 
		local rxd = fpvRotationX - fpvRotationXTarget
		local omz = Settings.FPV_ROTATION_X_FREQ * Settings.FPV_ROTATION_X_DAMP
		local alp = Settings.FPV_ROTATION_X_FREQ * SQRT(1 - Settings.FPV_ROTATION_X_DAMP * Settings.FPV_ROTATION_X_DAMP)
		local exp = EXP(-dt * omz)
		local cos = COS(dt * alp) 
		local sin = SIN(dt * alp)
		local c2 = (fpvRotationXVelocity + rxd * omz) / alp
		fpvRotationX = fpvRotationXTarget + exp * (rxd * cos + c2 * sin)
		fpvRotationXVelocity = -exp * ((rxd * omz - c2 * alp) * cos + (rxd * alp + c2 * omz) * sin)
	else 
		fpvRotationX = fpvRotationX + dt * Settings.FPV_ROTATION_SPEED * (fpvRotationXTarget - fpvRotationX)
	end
	fpvRotationY = fpvRotationY + dt * Settings.FPV_ROTATION_SPEED * (fpvRotationYTarget - fpvRotationY) 
	--Adjust trail origin
	cx = ox + Settings.FPV_OFFSET_Y * oyx + fpvOffset * ozx
	cy = oy + Settings.FPV_OFFSET_Y * oyy + fpvOffset * ozy
	cz = oz + Settings.FPV_OFFSET_Y * oyz + fpvOffset * ozz
	--Set Back Vector
	local bx = COS(fpvRotationY)
	--local by = 0
	local bz = SIN(fpvRotationY)
	czx = bx * oxx + bz * ozx
	czy = bx * oxy + bz * ozy
	czz = bx * oxz + bz * ozz

	--local czx = bx * oxx + by * oyx + bz * ozx
	--local czy = bx * oxy + by * oyy + bz * ozy
	--local czz = bx * oxz + by * oyz + bz * ozz

	--Set Right Vector
	local rx = SIN(fpvRotationY)
	--local ry = 0
	local rz = -COS(fpvRotationY)
	cxx = rx * oxx + rz * ozx
	cxy = rx * oxy + rz * ozy
	cxz = rx * oxz + rz * ozz

	--local cxx = rx * oxx + ry * oyx + rz * ozx
	--local cxy = rx * oxy + ry * oyy + rz * ozy
	--local cxz = rx * oxz + ry * oyz + rz * ozz

	--Rotate Back Vector
	czx = czx * COS(fpvRotationX) + (cxy * czz - cxz * czy) * SIN(fpvRotationX)
	czy = czy * COS(fpvRotationX) + (cxz * czx - cxx * czz) * SIN(fpvRotationX)
	czz = czz * COS(fpvRotationX) + (cxx * czy - cxy * czx) * SIN(fpvRotationX)
	local czm = SQRT(czx * czx + czy * czy + czz * czz)
	czx, czy, czz = czx / czm, czy / czm, czz / czm
	--Set Camera Up Vector
	cyx = czy * cxz - czz * cxy
	cyy = czz * cxx - czx * cxz
	cyz = czx * cxy - czy * cxx
	local cym = SQRT(cyx * cyx + cyy * cyy + cyz * cyz)
	cyx, cyy, cyz = cyx / cym, cyy / cym, cyz / cym
end

local function step(dt)
	Camera.CameraType = CAMERA_TYPE
	ox, oy, oz, oxx, oyx, ozx, oxy, oyy, ozy, oxz, oyz, ozz = COMPONENTS(DriverSeat.CFrame)
	if (rotatingManually) then 
		updateManualRotation(dt)
	else 
		updateDynamicRotation(dt)
	end
	if (viewMode == 0) then 
		updateTPV(dt)
	elseif (viewMode == 1) then 
		updateFPV(dt)
	end
	--Update actual camera
	Camera.CoordinateFrame = CF(cx, cy, cz, cxx, cyx, czx, cxy, cyy, czy, cxz, cyz, czz)
end

local function initCameraEffect()
	RunService:BindToRenderStep("CarCamera", Enum.RenderPriority.Camera.Value + 1, step)
end

local function deinitCameraEffect()
	RunService:UnbindFromRenderStep("CarCamera")
	Camera.CameraType = Enum.CameraType.Custom
end

initCameraEffect()