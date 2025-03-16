--[[START]]
script.Parent:WaitForChild("Car")
script.Parent:WaitForChild("IsOn")
script.Parent:WaitForChild("ControlsOpen")
script.Parent:WaitForChild("Values")

--[[Dependencies]]
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local car = script.Parent.Car.Value
local _Tune = require(car.Settings)
local Units = require(car.Settings.Units)
local playerModule = require(player.PlayerScripts:WaitForChild("PlayerModule"))
local ison = script.Parent.IsOn
local vl = script.Parent.Values
local FE = workspace.FilteringEnabled
game.Players.LocalPlayer.PlayerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeLeft

--[[Rev Body Shake]]
if _Tune.RevShake == true then
	game["Run Service"].RenderStepped:connect(function()
		local Drop = _Tune.RevShakeForce - (script.Parent.Values.Velocity.Value.Magnitude/5)
		if Drop < 0 then
			Drop = 0
		end
		if script.Parent.Values.Gear.Value == 0 then
			car.Body.Engine.RevBodyShake.Force = Vector3.new((150*script.Parent.Values.Throttle.Value)*Drop,0,0)
		else
			car.Body.Engine.RevBodyShake.Force = Vector3.new(0,0,0)
		end
	end)
end

--[[Output Scaling Factor]]
local FBrakeForce =_Tune.BrakeForce * 9.80665 * Units.Force_N*_Tune.BrakeBias-- conversion to SI unit
local RBrakeForce =_Tune.BrakeForce * 9.80665 * Units.Force_N*(1-_Tune.BrakeBias)
local PBrakeForceF = _Tune.PBrakeForce * 9.80665 * Units.Force_N*_Tune.PBrakeBias
local PBrakeForceR = _Tune.PBrakeForce * 9.80665 * Units.Force_N*(1-_Tune.PBrakeBias)
local EBrakeForce = _Tune.EBrakeForce
local SteerOuter  = _Tune.SteerOuter
local SteerInner  = _Tune.SteerInner
local RSteerOuter = _Tune.RSteerOuter
local RSteerInner = _Tune.RSteerInner

if not workspace:PGSIsEnabled() then
	error("PGS is not enabled: RA will not work.")
end

--[[Status Vars]]
local boolToNum = {[true] = 1, [false] = 0}
local min = math.min
local max = math.max

local _IsOn = _Tune.AutoStart
if _Tune.AutoStart and (_Tune.Engine or _Tune.Electric) then script.Parent.IsOn.Value=true end
local LOOPEDFORCE = _Tune.BrakeForce * 9.80665 * Units.Force_N
local LOOPEDBIAS = _Tune.BrakeBias
local _GSteerT=0
local _GSteerC=0
local _GThrot=0
local _InThrot=0
local _IThrot=0
local _GBrake=0
local _InBrake=0
local _IBrake=0

local _ClPressing = false
local _PlayerClutch = false
local _GClutch = 0
local _ABSAmt = 0
local _Clutch = 0
local _ClutchKick = 0
local _ClutchModulate = 0
local _RPM = _Tune.StartRPM
local _HP = 0
local _OutTorque = 0
local _CGear = car.Settings.Interface.Values.Gear.Value
local _PGear = _CGear
local _ShiftUp = false
local _ShiftDn = false
local _Shifting = false
local _spLimit = 0
local _SConfig = _Tune.S_Config
local _Boost = 0
local _TCount = 0
local _TPsi = 0
local _TBoost = 0
local _SCount = 0
local _SPsi = 0
local _SBoost = 0
local _NH = 0
local _NT = 0
local _EH = 0
local _ET = 0
local _TH = 0
local _TT = 0
local _SH = 0
local _ST = 0
local _BH = 0
local _BT = 0
local _SuperSpoolValue = 0
local _TBoostGoal = 0
local _ABSTracker = {}
local _TCSTracker = {}
local _CVTRatio = _Tune.CVTMaxRatio
local _CurrentRatio = _Tune.Ratios[_CGear+2]
local _FlywheelEnergy = 0

local _TMode = _Tune.TransModes[1]

local _MSteer = false
local _SteerL = false
local _SteerR = false
local _PBrake = car.Settings.Interface.Values.PBrake.Value
local _TCS = _Tune.TCSEnabled
local _TCSActive = false
local _TCSAmt = 0
local _ABS = _Tune.ABSEnabled
local _ABSActive = false

local FlipWait=tick()
local FlipDB=false

local _InControls = false
local _LastInputWasGamepad = false

local revLimiting = false

local _WheelSpeedsTable = {}
local _WheelSpeeds = {}
local _CarCenter = CFrame.new()
local autoshiftvers = _Tune.AutoShiftVers
local _OldVelocity = Vector3.new()

local _DragFactor = 1

--[[Shutdown]]
car.DriveSeat.ChildRemoved:connect(function(child) 
	if child.Name=="SeatWeld" and child:IsA("Weld") then
		GuiService.TouchControlsEnabled = true
		script.Parent:Destroy()
	end
end)

--[[Controls]]
local _CTRL = _Tune.Controls
local Controls = Instance.new("Folder",script.Parent)
Controls.Name = "Controls"
for i,v in next, (_CTRL) do
	local a=Instance.new("StringValue",Controls)
	a.Name=i
	a.Value=v.Name
	a.Changed:connect(function()
		if i=="MouseThrottle" or i=="MouseBrake" then
			if a.Value == "MouseButton1" or a.Value == "MouseButton2" then
				_CTRL[i]=Enum.UserInputType[a.Value]
			else
				_CTRL[i]=Enum.KeyCode[a.Value]
			end
		else
			_CTRL[i]=Enum.KeyCode[a.Value]
		end
	end)
end

--Deadzone Adjust
local _PPH = _Tune.Peripherals
	for i,v in next, (_PPH) do
	local a = Instance.new("IntValue",Controls)
	a.Name = i
	a.Value = v
	a.Changed:connect(function() 
		a.Value=math.min(100,math.max(0,a.Value))
		_PPH[i] = a.Value
	end)
end

function GetCarCenter()
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
	local center = CFrame.lookAt(centerR:Lerp(centerF,.5),centerF)
	return center
end

-- Value creator
local function setValue(type, name, value, parent)
	local valueObj = (parent or script.Parent.Values):FindFirstChild(name)
	if not valueObj then
		valueObj = Instance.new(type .. "Value", (parent or script.Parent.Values))
		valueObj.Name = name
	end
	valueObj.Value = value
end
local function getValue(name, parent)
	local valueObj = (parent or script.Parent.Values):FindFirstChild(name)
	return valueObj and valueObj.Value
end

setValue("Bool", "AutoClutch", true)

--Input Handler
function DealWithInput(input,IsRobloxFunction)
	if (UserInputService:GetFocusedTextBox()==nil) and not _InControls then --Ignore when UI Focus
		--Shift Down [Manual Transmission]
		if (input.KeyCode ==_CTRL["ContlrShiftDown"] or (_MSteer and input.KeyCode==_CTRL["MouseShiftDown"]) or ((not _MSteer) and input.KeyCode==_CTRL["ShiftDown"])) and ((_IsOn and ((_TMode=="Auto" and _CGear<=1) and _Tune.AutoShiftVers == "New") or _TMode=="Semi") or _TMode=="Manual") and input.UserInputState == Enum.UserInputState.Begin then
			if not _ShiftDn then _ShiftDn = true end
			
		--Shift Up [Manual Transmission]
		elseif (input.KeyCode ==_CTRL["ContlrShiftUp"] or (_MSteer and input.KeyCode==_CTRL["MouseShiftUp"]) or ((not _MSteer) and input.KeyCode==_CTRL["ShiftUp"])) and ((_IsOn and ((_TMode=="Auto" and _CGear<1) and _Tune.AutoShiftVers == "New") or _TMode=="Semi") or _TMode=="Manual") and input.UserInputState == Enum.UserInputState.Begin then
			if not _ShiftUp then _ShiftUp = true end
			
		--Toggle Clutch
		elseif (input.KeyCode ==_CTRL["ContlrClutch"] or (_MSteer and input.KeyCode==_CTRL["MouseClutch"]) or ((not _MSteer) and input.KeyCode==_CTRL["Clutch"])) and _TMode=="Manual" then
			if input.UserInputState == Enum.UserInputState.Begin then
				_ClPressing = true
				_PlayerClutch = true
			elseif input.UserInputState == Enum.UserInputState.End then
				_ClPressing = false
				_PlayerClutch = false
			end
		--Toggle PBrake
		elseif input.KeyCode ==_CTRL["ContlrPBrake"] or (_MSteer and input.KeyCode==_CTRL["MousePBrake"]) or ((not _MSteer) and input.KeyCode==_CTRL["PBrake"]) or ((not _MSteer) and input.KeyCode==_CTRL["PBrake2"]) then
			if input.UserInputState == Enum.UserInputState.Begin then
				_PBrake = not _PBrake
				car.Settings.Interface.Values.PBrake.Value = not car.Settings.Interface.Values.PBrake.Value
			elseif input.UserInputState == Enum.UserInputState.End then
				if car.DriveSeat.AssemblyLinearVelocity.Magnitude>5 then _PBrake = false car.Settings.Interface.Values.PBrake.Value = false end
			end
		--Toggle Transmission Mode
		elseif (input.KeyCode == _CTRL["ContlrToggleTMode"] or input.KeyCode==_CTRL["ToggleTransMode"]) and input.UserInputState == Enum.UserInputState.Begin then
			local n=1
			for i,v in next, (_Tune.TransModes) do
				if v==_TMode then n=i break end
			end
			n=n+1
			if n>#_Tune.TransModes then n=1 end
			_TMode = _Tune.TransModes[n]
		--Throttle
		elseif ((not _MSteer) and (input.KeyCode==_CTRL["Throttle"] or input.KeyCode == _CTRL["Throttle2"])) or ((((_CTRL["MouseThrottle"]==Enum.UserInputType.MouseButton1 or _CTRL["MouseThrottle"]==Enum.UserInputType.MouseButton2) and input.UserInputType == _CTRL["MouseThrottle"]) or input.KeyCode == _CTRL["MouseThrottle"])and _MSteer) then
			if input.UserInputState == Enum.UserInputState.Begin then
				_IThrot = 1
			else
				_IThrot = 0
			end
		--Brake
		elseif ((not _MSteer) and (input.KeyCode==_CTRL["Brake"] or input.KeyCode == _CTRL["Brake2"])) or ((((_CTRL["MouseBrake"]==Enum.UserInputType.MouseButton1 or _CTRL["MouseBrake"]==Enum.UserInputType.MouseButton2) and input.UserInputType == _CTRL["MouseBrake"]) or input.KeyCode == _CTRL["MouseBrake"])and _MSteer) then
			if input.UserInputState == Enum.UserInputState.Begin then
				_IBrake = 1
			else
				_IBrake = 0
			end
		--Steer Left
		elseif (not _MSteer) and (input.KeyCode==_CTRL["SteerLeft"] or input.KeyCode == _CTRL["SteerLeft2"]) then
			if input.UserInputState == Enum.UserInputState.Begin then
				_GSteerT = -1
				_SteerL = true
			else
				if _SteerR then
					_GSteerT = 1
				else
					_GSteerT = 0
				end
				_SteerL = false
			end
		--Steer Right
		elseif (not _MSteer) and (input.KeyCode==_CTRL["SteerRight"] or input.KeyCode == _CTRL["SteerRight2"]) then
			if input.UserInputState == Enum.UserInputState.Begin then
				_GSteerT = 1
				_SteerR = true
			else
				if _SteerL then
					_GSteerT = -1
				else
					_GSteerT = 0
				end
				_SteerR = false
			end
		--Toggle Mouse Controls
		elseif input.KeyCode ==_CTRL["ToggleMouseDrive"] then
			if input.UserInputState == Enum.UserInputState.End then
				_MSteer = not _MSteer
				_IThrot = 0
				_IBrake = 0
				_GSteerT = 0
			end
		--Toggle TCS
		elseif _Tune.TCSLocked == false then
			if _Tune.TCSEnabled and _IsOn and input.KeyCode == _CTRL["ToggleTCS"] or input.KeyCode == _CTRL["ContlrToggleTCS"] then
				if input.UserInputState == Enum.UserInputState.End 
					then _TCS = not _TCS 
				end
			end
		end
		--Toggle ABS
		if _Tune.ABSLocked == false then
			if _Tune.ABSEnabled and _IsOn and input.KeyCode == _CTRL["ToggleABS"] or input.KeyCode == _CTRL["ContlrToggleABS"] then
				if input.UserInputState == Enum.UserInputState.End 
					then _ABS = not _ABS 	
				end
			end
		end
		--Variable Controls
		if input.UserInputType.Name:find("Gamepad") then
			--Gamepad Steering
			if input.KeyCode == _CTRL["ContlrSteer"] then
				if input.Position.X>= 0 then
					local cDZone = math.min(.99,_Tune.Peripherals.ControlRDZone/100)
					if math.abs(input.Position.X)>cDZone then
						_GSteerT = (input.Position.X-cDZone)/(1-cDZone)
					else
						_GSteerT = 0
					end
				else
					local cDZone = math.min(.99,_Tune.Peripherals.ControlLDZone/100)
					if math.abs(input.Position.X)>cDZone then
						_GSteerT = (input.Position.X+cDZone)/(1-cDZone)
					else
						_GSteerT = 0
					end
				end
			--Gamepad Throttle
			elseif input.KeyCode == _CTRL["ContlrThrottle"] then
				_IThrot = math.max(0,input.Position.Z)
			--Gamepad Brake
			elseif input.KeyCode == _CTRL["ContlrBrake"] then
				_IBrake = input.Position.Z
			end
		end
	else
		_IThrot = 0
		_GSteerT = 0
		_IBrake = 0
	end
end
UserInputService.InputBegan:connect(DealWithInput)
UserInputService.InputChanged:connect(DealWithInput)
UserInputService.InputEnded:connect(DealWithInput)

--[[Drivetrain Initialize]]
--- pog mobile Support Mod	
if UserInputService.TouchEnabled then
	local Buttons = script.Parent:WaitForChild("Mobile_Support")
	local Left = Buttons:WaitForChild("Left")
	local Right = Buttons:WaitForChild("Right")
	local Brake = Buttons:WaitForChild("Brake")
	local Gas = Buttons:WaitForChild("Gas")
	local Downshift = Buttons.Downshift
	local Upshift = Buttons.Upshift
	local Handbrake = Buttons:WaitForChild("Handbrake")
	local Startup = Buttons:WaitForChild("Startup")
	local On = script.Parent.IsOn
	
	if _Tune.AutoStart == true then
		Startup.Visible = false
		Startup.Selectable = false
	end
	
	local Thread = coroutine.wrap(function()
		while true do
			wait(.5)
			if _TMode == "Semi" or _TMode == "Manual" then
				Downshift.Visible = true
				Upshift.Visible = true
			else
				Downshift.Visible = false
				Upshift.Visible = false
			end
		end
	end)
	
	Thread()
	Buttons.Visible = true
	
	local function LeftTurn(Touch, GPE)
		if Touch.UserInputState == Enum.UserInputState.Begin then
			_GSteerT = -1
			_SteerL = true
		else
			if _SteerR then
				_GSteerT = 1
			else
				_GSteerT = 0
			end
			_SteerL = false
		end
	end
	Left.InputBegan:Connect(LeftTurn)
	Left.InputEnded:Connect(LeftTurn)
	--Left.InputChanged:Connect(LeftTurn)
	local function RightTurn(Touch, GPE)
		if Touch.UserInputState == Enum.UserInputState.Begin then
			_GSteerT = 1
			_SteerR = true
		else
			if _SteerL then
				_GSteerT = -1
			else
				_GSteerT = 0
			end
			_SteerR = false
		end
	end
	Right.InputBegan:Connect(RightTurn)
	Right.InputEnded:Connect(RightTurn)
	--Right.InputChanged:Connect(RightTurn)
	local function TouchThrottle(input, GPE)
		if input.UserInputState == Enum.UserInputState.Begin and _IsOn then
			_IThrot = 1
		else
			_IThrot = _Tune.IdleThrottle / 100
		end
	end
	Gas.InputBegan:Connect(TouchThrottle)
	Gas.InputEnded:Connect(TouchThrottle)
	--Gas.InputChanged:Connect(TouchThrottle)
	local function TouchBrake(input, GPE)
		if input.UserInputState == Enum.UserInputState.Begin then
			_IBrake = 1
		else
			_IBrake = 0
		end
	end
	Brake.InputBegan:Connect(TouchBrake)
	Brake.InputEnded:Connect(TouchBrake)
	--Brake.InputChanged:Connect(TouchBrake)
	local function TouchHandbrake(input, GPE)
		if input.UserInputState == Enum.UserInputState.Begin then
			_PBrake = not _PBrake
		elseif input.UserInputState == Enum.UserInputState.End then
			if car.DriveSeat.Velocity.Magnitude > 5 then
				_PBrake = false
			end
		end
	end
	Handbrake.InputBegan:Connect(TouchHandbrake)
	Handbrake.InputEnded:Connect(TouchHandbrake)
	
	local function TouchDownshift(input, GPE)
		if ((_IsOn and ((_TMode == "Auto" and _CGear <= 1) and _Tune.AutoShiftVers == "New") or _TMode == "Semi") or _TMode == "Manual") and input.UserInputState == Enum.UserInputState.Begin then
			if not _ShiftDn then
				_ShiftDn = true
			end
		end
	end
	
	Downshift.InputBegan:Connect(TouchDownshift)

	local function TouchUpshift(input, GPE)
		if ((_IsOn and ((_TMode == "Auto" and _CGear < 1) and _Tune.AutoShiftVers == "New") or _TMode == "Semi") or _TMode == "Manual") and input.UserInputState == Enum.UserInputState.Begin then
			if not _ShiftUp then
				_ShiftUp = true
			end
		end
	end
	Upshift.InputBegan:Connect(TouchUpshift)

end -- MOBILE SUPPORT IF STATEMEN

local Drive={}

--Power Front Wheels
	if _Tune.Config == "FWD" or _Tune.Config == "AWD" then for i,v in next, (car.Wheels:GetChildren()) do if v.Name=="FL" or v.Name=="FR" or v.Name=="F" then table.insert(Drive,v) end end end

--Power Rear Wheels
	if _Tune.Config == "RWD" or _Tune.Config == "AWD" then for i,v in next, (car.Wheels:GetChildren()) do if v.Name=="RL" or v.Name=="RR" or v.Name=="R" then table.insert(Drive,v) end end end

--Determine Wheel Size
local wDia = 0 for i,v in next, (Drive) do if v.Size.Y>wDia then wDia = v.Size.Y end end

--Pre-Toggled PBrake
for i,v in next, (car.Wheels:GetChildren()) do if (math.abs(v["#BV"].MotorMaxTorque-PBrakeForceF)<1) or (math.abs(v["#BV"].MotorMaxTorque-PBrakeForceR)<1) then _PBrake=false end end

--[[Throttle and Brake Input Smoothening]]
function Inputs(dt)
	local deltaTime = (60/(1/dt))
	if _InThrot <= _IThrot then
		_InThrot = math.min(_IThrot,_InThrot+(_Tune.ThrotAccel*deltaTime))
	else
		_InThrot = math.max(_IThrot,_InThrot-(_Tune.ThrotDecel*deltaTime))
	end
	if _InBrake <= _IBrake then
		_InBrake = math.min(_IBrake,_InBrake+(_Tune.BrakeAccel*deltaTime))
	else
		_InBrake = math.max(_IBrake,_InBrake-(_Tune.BrakeDecel*deltaTime))
	end
end

--[[Steering]]
SteerOuter = (_Tune.LockToLock*180)/_Tune.SteerRatio
SteerInner = math.min(SteerOuter-(SteerOuter*(1-_Tune.Ackerman)),SteerOuter*1.2)

function Steering(dt)
	local deltaTime = (60/(1/dt))
	local controller = _LastInputWasGamepad or (_Tune.MSteerUsesContlr and _MSteer or false)
	local SteerSpeed = controller and (_Tune.ContlrSteerSpeed>0 and _Tune.ContlrSteerSpeed or _Tune.Steerspeed) or _Tune.SteerSpeed
	local ReturnSpeed = controller and (_Tune.ContlrReturnSpeed>0 and _Tune.ContlrReturnSpeed or _Tune.ReturnSpeed) or _Tune.ReturnSpeed

	--Mouse Steer
	if _MSteer then
		local msWidth = math.max(1,mouse.ViewSizeX*_Tune.Peripherals.MSteerWidth/200)
		local mdZone = _Tune.Peripherals.MSteerDZone/100
		local mST = ((mouse.X-mouse.ViewSizeX/2)/msWidth)
		if math.abs(mST)<=mdZone then
			_GSteerT = 0
		else
			_GSteerT = (math.max(math.min((math.abs(mST)-mdZone),(1-mdZone)),0)/(1-mdZone))^_Tune.MSteerExp * (mST / math.abs(mST))
		end
	end
	
	--Interpolate Steering
	if _GSteerC < _GSteerT then
		if _GSteerC<0 then
			_GSteerC = math.min(_GSteerT,_GSteerC+(ReturnSpeed*deltaTime))
		else
			_GSteerC = math.min(_GSteerT,_GSteerC+(SteerSpeed*deltaTime))
		end
	else
		if _GSteerC>0 then
			_GSteerC = math.max(_GSteerT,_GSteerC-(ReturnSpeed*deltaTime))
		else
			_GSteerC = math.max(_GSteerT,_GSteerC-(SteerSpeed*deltaTime))
		end
	end
	
	--Steer Decay Multiplier
	local sDecay = (1-math.min(car.DriveSeat.AssemblyLinearVelocity.Magnitude/(Units.Velocity_mdivs/3.6)/_Tune.SteerDecay,1-(_Tune.MinSteer/100)))
	local rsDecay = (1-math.min(car.DriveSeat.AssemblyLinearVelocity.Magnitude/(Units.Velocity_mdivs/3.6)/_Tune.RSteerDecay,1-(_Tune.MinSteer/100)))
	
	--Apply Steering
	for i,v in next, car.Wheels:GetChildren() do
		if v.Name=="F" then
			v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-math.rad(_GSteerC*SteerInner*sDecay),0)
		elseif v.Name=="FL" then
			if _GSteerC>= 0 then
				v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-math.rad(_GSteerC*SteerOuter*sDecay),0)
			else
				v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-math.rad(_GSteerC*SteerInner*sDecay),0)
			end	
		elseif v.Name=="FR" then
			if _GSteerC>= 0 then
				v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-math.rad(_GSteerC*SteerInner*sDecay),0)
			else
				v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-math.rad(_GSteerC*SteerOuter*sDecay),0)
			end
		elseif v.Name=='R' then
			if _Tune.FWSteer=='None' then
			elseif _Tune.FWSteer=='Static' then
				v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,math.rad(_GSteerC*RSteerInner*rsDecay*math.max(0,1-(car.DriveSeat.Velocity.Magnitude/_Tune.RSteerSpeed))),0)
			elseif _Tune.FWSteer=='Speed' then
				v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-math.rad(_GSteerC*RSteerInner*rsDecay*math.min(1,(car.DriveSeat.Velocity.Magnitude/_Tune.RSteerSpeed))),0)
			elseif _Tune.FWSteer=='Both' then
				v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,math.rad(_GSteerC*RSteerInner*rsDecay*math.max(-1,1-(car.DriveSeat.Velocity.Magnitude/_Tune.RSteerSpeed))),0)
			end
		elseif v.Name=='RL' then
			if _Tune.FWSteer=='None' then
			elseif _Tune.FWSteer=='Static' then
				if _GSteerC>= 0 then
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,math.rad(_GSteerC*RSteerOuter*rsDecay*math.max(0,1-(car.DriveSeat.Velocity.Magnitude/_Tune.RSteerSpeed))),0)
				else
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,math.rad(_GSteerC*RSteerInner*rsDecay*math.max(0,1-(car.DriveSeat.Velocity.Magnitude/_Tune.RSteerSpeed))),0)
				end
			elseif _Tune.FWSteer=='Speed' then
				if _GSteerC>= 0 then
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-math.rad(_GSteerC*RSteerOuter*rsDecay*math.min(1,(car.DriveSeat.Velocity.Magnitude/_Tune.RSteerSpeed))),0)
				else
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-math.rad(_GSteerC*RSteerInner*rsDecay*math.min(1,(car.DriveSeat.Velocity.Magnitude/_Tune.RSteerSpeed))),0)
				end
			elseif _Tune.FWSteer=='Both' then
				if _GSteerC>= 0 then
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,math.rad(_GSteerC*RSteerOuter*rsDecay*math.max(-1,1-(car.DriveSeat.Velocity.Magnitude/_Tune.RSteerSpeed))),0)
				else
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,math.rad(_GSteerC*RSteerInner*rsDecay*math.max(-1,1-(car.DriveSeat.Velocity.Magnitude/_Tune.RSteerSpeed))),0)
				end
			end
		elseif v.Name=='RR' then
			if _Tune.FWSteer=='None' then
			elseif _Tune.FWSteer=='Static' then
				if _GSteerC>= 0 then
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,math.rad(_GSteerC*RSteerInner*rsDecay*math.max(0,1-(car.DriveSeat.Velocity.Magnitude/_Tune.RSteerSpeed))),0)
				else
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,math.rad(_GSteerC*RSteerOuter*rsDecay*math.max(0,1-(car.DriveSeat.Velocity.Magnitude/_Tune.RSteerSpeed))),0)
				end
			elseif _Tune.FWSteer=='Speed' then
				if _GSteerC>= 0 then
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-math.rad(_GSteerC*RSteerInner*rsDecay*math.min(1,(car.DriveSeat.Velocity.Magnitude/_Tune.RSteerSpeed))),0)
				else
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-math.rad(_GSteerC*RSteerOuter*rsDecay*math.min(1,(car.DriveSeat.Velocity.Magnitude/_Tune.RSteerSpeed))),0)
				end
			elseif _Tune.FWSteer=='Both' then
				if _GSteerC>= 0 then
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,math.rad(_GSteerC*RSteerInner*rsDecay*math.max(-1,1-(car.DriveSeat.Velocity.Magnitude/_Tune.RSteerSpeed))),0)
				else
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,math.rad(_GSteerC*RSteerOuter*rsDecay*math.max(-1,1-(car.DriveSeat.Velocity.Magnitude/_Tune.RSteerSpeed))),0)
				end
			end
		end
		if v:GetAttribute("SteerDisabled") then v.Arm.Steer.CFrame = v.Base.CFrame end
	end
end



--[[Engine]]
local fFD = _Tune.FinalDrive*_Tune.FDMult
local fFDr = fFD*30/math.pi
local cGrav = workspace.Gravity*_Tune.InclineComp/32.2
local wDRatio = wDia*math.pi/60
local cfWRot = CFrame.Angles(math.pi/2,-math.pi/2,0)
local cfYRot = CFrame.Angles(0,math.pi,0)

--Electric Only Setup
if not _Tune.Engine and _Tune.Electric then 
	_Tune.Redline = _Tune.E_Redline 
	_Tune.PeakRPM = _Tune.E_Trans2 
	_Tune.Turbochargers = 0
	_Tune.Superchargers = 0
	_Tune.Clutch = false 
	_Tune.IdleRPM = 0 
end

--Aspiration Setup
_TCount = _Tune.Turbochargers
_TPsi = _Tune.T_Boost *_Tune.Turbochargers

_SCount = _Tune.Superchargers
_SPsi = _Tune.S_Boost*_Tune.Superchargers

--Powertrain
wait()

--Automatic Transmission
function Auto()
	local maxSpin=0
	for i,v in next, Drive do if _WheelSpeeds[v.Name]>maxSpin then maxSpin = _WheelSpeeds[v.Name] end end
	if _IsOn then
		if _Tune.AutoShiftVers == "Old" and _CGear == 0 then _CGear = 1 _ClPressing = false end
		if _CGear >= 1 then
			if (_CGear==1 and _InBrake > 0 and car.DriveSeat.AssemblyLinearVelocity.Magnitude < 5) and _Tune.AutoShiftVers == "Old" then
				_CGear = -1 _ClPressing = false
			elseif car.DriveSeat.AssemblyLinearVelocity.Magnitude > 5 and _Tune.ClutchType ~= "CVT" then
				if _Tune.AutoShiftMode == "RPM" then
					if _RPM>(_Tune.ShiftRPM+_Tune.AutoUpThresh) then
						if not _ShiftUp and not _Shifting then _ShiftUp = true end
					elseif math.max(math.min(maxSpin*_Tune.Ratios[_CGear+1]*fFDr,_Tune.Redline+100),0)<(_Tune.ShiftRPM-_Tune.AutoDownThresh) and _CGear>1 then
						if not _ShiftDn and not _Shifting then _ShiftDn = true end 
					end
				else
					if car.DriveSeat.AssemblyLinearVelocity.Magnitude > math.ceil(wDRatio*(_Tune.ShiftRPM+_Tune.AutoUpThresh)/_CurrentRatio/fFD) then
						if not _ShiftUp and not _Shifting then _ShiftUp = true end
					elseif car.DriveSeat.AssemblyLinearVelocity.Magnitude < math.ceil(wDRatio*(_Tune.ShiftRPM-_Tune.AutoDownThresh)/_Tune.Ratios[_CGear+1]/fFD) and _CGear>1 then
						if not _ShiftDn and not _Shifting then _ShiftDn = true end
					end
				end
			end
		else
			if (_InThrot > 0 and car.DriveSeat.AssemblyLinearVelocity.Magnitude < 5) and _Tune.AutoShiftVers == "Old" then
				_CGear = 1 _ClPressing = false
			end
		end
	end 
end

function Gear()
	local maxSpin=0
	for i,v in next, (Drive) do if _WheelSpeeds[v.Name]>maxSpin then maxSpin = _WheelSpeeds[v.Name] end end
	if _ShiftUp and not _Shifting then
		if (_TMode == "Manual" and not _ClPressing) or (_TMode == "Manual" and _Tune.ClutchRel and (_InThrot>0)) or _CGear == #_Tune.Ratios-2 or (_TMode ~= "Manual" and not _IsOn) then _ShiftUp = false return end
		local NextGear = math.min(_CGear+3,#_Tune.Ratios)
		if _TMode~="Manual" and _Tune.ClutchType ~= "CVT" then
			_Shifting = true
			if _CGear>0 then 
				if _Tune.AutoShiftType=="DCT" then 
					wait(_Tune.ShiftUpTime)
				elseif _Tune.AutoShiftType=="Rev" then
					repeat wait() until _RPM<=math.max(math.min(maxSpin*_Tune.Ratios[NextGear]*fFDr,_Tune.Redline-_Tune.RevBounce),_Tune.IdleRPM) or not _IsOn or _ShiftDn 
				end
			end
		end
		_ShiftUp = false
		_Shifting = false
		if _TMode ~= "Manual" and not _IsOn then return end
		if NextGear >= 4 and _Tune.ClutchType == "CVT" then return end  -- make sure it cannot go past 1st gear
		_CGear = math.min(_CGear+1,#_Tune.Ratios-2)
		if _TMode ~= "Manual" or (_TMode == "Manual" and _CGear == 1) and _IsOn then _ClPressing = false end
	end
	if _ShiftDn and not _Shifting then
		if (_TMode == "Manual" and not _ClPressing) or _CGear == -1 or (_TMode ~= "Manual" and not _IsOn) then _ShiftDn = false return end
		local PrevGear = math.min(_CGear+1,#_Tune.Ratios)
		if _TMode~="Manual" then
			_Shifting = true
			if _CGear>1 then 
				if _Tune.AutoShiftType=="DCT" then 
					wait(_Tune.ShiftDnTime)
				elseif _Tune.AutoShiftType=="Rev" then
					repeat wait() until _RPM>=math.max(math.min(maxSpin*_Tune.Ratios[PrevGear]*fFDr,_Tune.Redline-_Tune.RevBounce),_Tune.IdleRPM+_Tune.ClutchIdle) or not _IsOn or _ShiftUp
				end
			end
		end
		_ShiftDn = false
		_Shifting = false
		if _TMode ~= "Manual" and not _IsOn then return end
		_CGear = math.max(_CGear-1,-1)
		if _TMode ~= "Manual" or (_TMode == "Manual" and _CGear == -1) and _IsOn then _ClPressing = false end
	end
end

local _GoalRPM=0
local tqTCS = 1
local _StallOK = false
local ticc = tick()

-- Math Values
local N = boolToNum[_Tune.Engine]
local N1 = _Tune.Torque
local N2 = _Tune.Redline
local N3 = _Tune.IdleRPM
local N4 = _Tune.ValveSprings
local N5 = _Tune.ValveFloatSharpness
local N6 = _Tune.VVLSharpness
local N7 = _Tune.VVLTime
local N8 = _Tune.VVLValue
local N9 = _Tune.HighPerf
local N11 = _Tune.LowPerf
local N10 = _Tune.LowPerfSpread
local N12 = _Tune.ExhaustPressure
local N13 = _Tune.HorsepowerLimit

local E = boolToNum[_Tune.Electric]
local E1 = _Tune.E_Torque
local E2 = _Tune.E_Redline
local E3 = _Tune.E_DropSlope
local E4 = _Tune.E_TorqueDropRPM
local E5 = _Tune.E_TorqueDropCurve
local E6 = _Tune.E_TorqueDropSpread

local T = _Tune.Turbochargers
local T1 = _Tune.T_Boost
local T2 = _Tune.T_ExPressFactor
local T3 = _Tune.T_ExPressInf
local T4 = _Tune.T_SpoolTimeOffset
local T5 = _Tune.T_Efficiency
local T6 = _Tune.T_WGMaxPress
local T7 = _Tune.T_SpoolFactor
local T8 = _Tune.T_MinBoost

local S = _Tune.Superchargers
local S1 = _Tune.S_Boost
local S2 = _Tune.S_HighPerf
local S3 = _Tune.S_StartBoost
local S4 = _Tune.S_Efficiency

--Apply Power
function Engine(dt)
	local deltaTime = (60/(1/dt))
	
	--Average Rotational Speed Calculation
	local fwspeed=0
	local fwcount=0
	local rwspeed=0
	local rwcount=0

	for i,v in next, (car.Wheels:GetChildren()) do
		if v.Name=="FL" or v.Name=="FR" or v.Name == "F" then
			fwspeed=fwspeed+_WheelSpeeds[v.Name]
			fwcount=fwcount+1
		elseif v.Name=="RL" or v.Name=="RR" or v.Name == "R" then
			rwspeed=rwspeed+_WheelSpeeds[v.Name]
			rwcount=rwcount+1
		end
	end
	fwspeed=fwspeed/fwcount
	rwspeed=rwspeed/rwcount	
	local cwspeed=(fwspeed+rwspeed)/2

	local maxSpin=0
	local maxCount=0
	local revThrot=_GThrot
	for i,v in next, (Drive) do maxSpin = maxSpin + _WheelSpeeds[v.Name] maxCount = maxCount + 1 end
	maxSpin=maxSpin/maxCount
	local _WheelRPM = maxSpin*_CurrentRatio*fFDr
	
	--CVT
	if _Tune.ClutchType == "CVT" then
		_CVTRatio = math.clamp((_Tune.CVTRPM*_GThrot)/(maxSpin*fFDr), _Tune.CVTMinRatio, _Tune.CVTMaxRatio)
	end

	--Update ratio
	_CurrentRatio = _Tune.ClutchType == "CVT" and _CVTRatio or _Tune.Ratios[_CGear+2]
	_spLimit = (_Tune.Redline+100)/(fFDr*_CurrentRatio)
	
	--Neutral Gear
	if ((_CGear == 0 or _Shifting) and _IsOn) then 
		_ClPressing = true
		_Clutch = 1
		_StallOK = false
	end
	
	_FlywheelEnergy = math.max(_FlywheelEnergy-_Tune.Flywheel, 0)
	if _Clutch == 1 then
		_FlywheelEnergy = math.max((_RPM-_WheelRPM)/1000 * _GThrot * _Tune.FlywheelEnergy,0)
	end
	
	local revMin = 1
	local goalMin = 1
	local goalMax = _Tune.Redline+100
	if _Tune.Stall and _Tune.Clutch then revMin = 0 end
	
	if _Shifting and _ShiftUp then 
		_GThrot = _Tune.IdleThrottle/100
	elseif _Shifting and _ShiftDn then
		_GThrot = (_Tune.ShiftThrot/100)
	else
		if (_Tune.AutoShiftVers == "Old" and _CGear==-1 and _TMode=="Auto") then
			_GThrot = _InBrake
		else
			_GThrot = math.max(_InThrot, _Tune.IdleThrottle/100)
		end
	end
	
	if (_Tune.AutoShiftVers == "Old" and _CGear==-1 and _TMode=="Auto") then
		_GBrake = _InThrot
	else
		_GBrake = _InBrake
	end
	
	if not _IsOn then 
		ticc = tick()
		_Clutch = 1 
		if not script.Parent.Starting.Value then
			_GThrot = 0
		end
	end
	
	if ((_ClPressing and _CGear == 0) or (_PlayerClutch and _CGear ~= 0)) and _Tune.NeutralLimit then
		if (_CGear == 0 and not _Tune.LimitClutch) or _Tune.LimitClutch then
			goalMax = _Tune.NeutralRevRPM
		end
	end
	
	--Determine RPM
	-- Rev limiter/speed limiter
	if _RPM >= _Tune.Redline then
		revLimiting = true
	elseif _RPM < _Tune.Redline-_Tune.RevBounce then
		revLimiting = false
	end
	if revLimiting then
		_GThrot = _Tune.IdleThrottle/100
	end
	
	local limit = (_CGear<0 and _Tune.ReverseSpeed or _Tune.SpeedLimit)
	if limit > 0 then
		_GThrot = math.min(_GThrot, math.max(1 - math.clamp(((vl.Velocity.Value.Magnitude/(Units.Velocity_mdivs/3.6)) - (limit-_Tune.SLimitGradient) )/_Tune.SLimitGradient, 0, 1), _Tune.IdleThrottle/100))
		if _Tune.SLimitBrake then
			_GBrake = math.max(_GBrake, math.clamp((vl.Velocity.Value.Magnitude/(Units.Velocity_mdivs/3.6) - limit)/_Tune.SLimitGradient, 0, 1))
		end
	end

	-- Idle
	if _RPM<_Tune.IdleRPM and _IsOn then
		_GThrot = math.max(_GThrot, math.clamp((_Tune.IdleRPM-_RPM)/400, 0, 1))
	end
	
	if (_Tune.Engine or _Tune.Electric) and (not script.Parent.Starting.Value) then
		_GoalRPM = math.clamp(_RPM - (_Tune.RevDecay*deltaTime) + (_Tune.RevAccel*revThrot*deltaTime) - (math.clamp(math.max(_RPM-_Tune.IdleRPM,0)/math.max(_Tune.Redline-_Tune.IdleRPM,1),0,1)*_Tune.RevDecayRPM*deltaTime),goalMin,goalMax)
	end

	--Starting
	if script.Parent.Starting.Value then
		if _RPM > _Tune.StartRPM then
			script.Parent.IsOn.Value = true
			script.Parent.Starting.Value = false
			_GThrot = 0
		else
			_GoalRPM += _Tune.StartRPMAccel
			_GThrot = 1
		end
	end
	
	if _Tune.Clutch then
		if getValue("AutoClutch") and _IsOn then
			if _Tune.ClutchType == "Clutch" or _Tune.ClutchType == "CVT" then
				if _ClPressing then _ClutchKick = 1 end
				_ClutchKick = _ClutchKick*(_Tune.ClutchEngage/100)		
				local ClRPMInfluence = math.max((_RPM)*_Tune.ClutchRPMMult/(_Tune.Redline),0)
				if _Tune.ClutchMode == "New" then ClRPMInfluence = 0 end
				_ClutchModulate = math.min(((((script.Parent.Values.Velocity.Value.Magnitude/(Units.Velocity_mdivs/3.6)/_Tune.SpeedEngage)/math.abs(_CGear)) + ClRPMInfluence) - _ClutchKick), 1)
			elseif _Tune.ClutchType == "TorqueConverter" and _Tune.TQLock then
				if (_GThrot<=_Tune.IdleThrottle/100 and script.Parent.Values.Velocity.Value.Magnitude/(Units.Velocity_mdivs/3.6)<_Tune.SpeedEngage) or (_GThrot>_Tune.IdleThrottle/100 and (_RPM < _Tune.RPMEngage and _WheelRPM < _Tune.RPMEngage)) then
					_ClutchModulate = math.min(_ClutchModulate*(_Tune.ClutchEngage/100), 1)
				else
					_ClutchModulate = math.min(_ClutchModulate*(_Tune.ClutchEngage/100)+(1-(_Tune.ClutchEngage/100)), 1)
				end
			elseif _Tune.ClutchType == "TorqueConverter" and not _Tune.TQLock then
				_ClutchModulate = math.min((_RPM/_Tune.Redline)*.7, 1)
			end
			if not _ClPressing then _Clutch = math.min(1-_ClutchModulate,1) else _Clutch = 1 end
			_StallOK = (_Clutch<=.01) or _StallOK
		else
			_StallOK = _Tune.Stall
			_Clutch = script.Parent.Values.Clutch.Value
		end
	else
		_StallOK = false
		if not _ClPressing and not _Shifting then _Clutch = 0 else _Clutch = 1 end
	end
	
	-- Things that apply the clutch
	if vl.AutoClutch.Value and (script.Parent.Starting.Value or (_Tune.RemoveCreep and _RPM < _Tune.IdleRPM and _IThrot < .1) or revLimiting) then
		_Clutch = 1
	end

	local aRPM = math.max(math.min((_GoalRPM*_Clutch) + (_WheelRPM*(1-_Clutch)),_Tune.Redline+100),revMin)
	local clutchP = math.min(math.abs(aRPM-_RPM)/(_Tune.Flywheel*deltaTime),.9)
	if _ClPressing then clutchP = 0 end
	_RPM = _RPM*clutchP + aRPM*(1-clutchP)
	if _RPM > goalMax then
		_RPM = goalMax
	elseif _RPM < goalMin then
		_RPM = goalMin
	end
	_RPM = math.clamp(_RPM, 0, _Tune.Redline)

	if _RPM<=(_Tune.IdleRPM/4) and _StallOK and (tick()-ticc>=.2) then script.Parent.IsOn.Value = not _Tune.Stall end

	--Aspiration
	local TPsi = _TPsi/_TCount

	local _BThrot = _GThrot
	local _DThrot = _Tune.IdleThrottle/100
	
	--Aspiration
	if _GThrot > _SuperSpoolValue and _Tune.Engine and _Tune.Superchargers > 0 then
		if _BThrot <= _DThrot then
			_SuperSpoolValue = min(_SuperSpoolValue + _Tune.S_Sensitivity, _GThrot)
		end
	else
		if _BThrot <= _DThrot then
			_SuperSpoolValue = max(_SuperSpoolValue - _Tune.S_Sensitivity, _GThrot)
		end
	end

	local C1 = _SuperSpoolValue

	--Torque calculations
	local x = _RPM/1000
	if _Tune.Engine then
		_NT = 100*(N*max(N1/100-(N5^(x-N4)+N10^(x-N11))+(N9/10*x+max(-(1-N6)^(x-N7)+N8,0))+(math.clamp(_Tune.Roughness*math.sin(250*x*tick())/math.max(100*x,1), -_Tune.Roughness, _Tune.Roughness)),0))*(_RPM<10 and 0 or 1)
		_NH = (_NT*x/(_Tune.EqPoint/1000))
		if _Tune.Turbochargers~=0 then
			local minBoost = T8 / 100 * T1 * T
			if not _IsOn then minBoost = 0 end
			_TBoostGoal = math.max(_GThrot^_Tune.T_SpoolFactor * min(max((max(N12*(_NH/100)-T4,0)^T2)+(T3*(N12*(_NH/100))),0),T*(T1+max(N12*(_NH/100)-T6,0))), minBoost)

			if _TBoostGoal > _TBoost then
				_TBoost = math.max(math.min(_TBoost + _Tune.T_SpoolIncrease * _GThrot, _TBoostGoal), minBoost)
			elseif _TBoost > _TBoostGoal then
				_TBoost = math.max(math.max(_TBoost * _Tune.T_SpoolDecrease, _TBoostGoal), minBoost)
			end

			_TT = max(100*T5*_TBoost,0)
			_TH = (_TT*x/(_Tune.EqPoint/1000))
		else
			_TH,_TT = 0,0
		end
		if _Tune.Superchargers~=0 then
			_SBoost = C1*S*max((S1/10)*x-S2^x+S3,0)
			_ST = 100*(S4*_SBoost)
			_SH = (_ST*x/(_Tune.EqPoint/1000))
		else
			_SH,_ST = 0,0
		end
		_BH = _TH+_SH
		_BT = _TT+_ST
	else
		_NH,_NT = 0,0
		_TH,_TT = 0,0
		_SH,_ST = 0,0
		_BH,_BT = 0,0
	end

	if _Tune.Electric and _CGear~=0 then
		_ET = max(100*(E*(E1/100-max(E3*x-E3*(E4/1000),0)+E5*min(E6^(x-E4/1000)-1,0))),0)
		_EH = (_ET*x/(_Tune.EqPoint/1000))
	else
		_EH,_ET = 0,0
	end
	
	_OutTorque = math.clamp(min(_NT + _BT + _ET,N13>0 and N13*(_Tune.EqPoint/1000/x) or math.huge), 0, 1e6)
	_HP = _OutTorque*x/(_Tune.EqPoint/1000)
	_OutTorque*=_CurrentRatio*fFD
	
	local iComp =(_CarCenter.LookVector.Y)*cGrav
	if _CGear==-1 then iComp=-iComp end
	_OutTorque = _OutTorque*math.max(1,(1+iComp))
	
	--Update Wheels
	for i,v in next, (car.Wheels:GetChildren()) do
		--Reference Wheel Orientation
		local Ref=(CFrame.new(v.Position-((v.Arm.CFrame*cfWRot).lookVector),v.Position)*cfYRot).lookVector
		local aRef=1
		local diffMult=1
		local RRdiffMult=1
		local RLdiffMult=1
		local FRdiffMult=1
		local FLdiffMult=1
		if v.Name=="FL" or v.Name=="RL" then aRef=-1 end
		
		--Differential/Torque-Vectoring
		if v.Name=="FR" then
			local avg=((_WheelSpeeds[v.Name]/_WheelSpeeds["FL"])-1)*(_Tune.FDiffPreload/10)
			FRdiffMult=math.ceil(math.max(0,math.min(2,1-( ((_Tune.FDiffPower/100)*avg*_GThrot) + ((_Tune.FDiffCoast/100)*avg*(1-_GThrot)))))*100)/100
			FLdiffMult=2-FRdiffMult
		elseif v.Name=="FL" then
			local avg=((_WheelSpeeds[v.Name]/_WheelSpeeds["FR"])-1)*(_Tune.FDiffPreload/10)
			FLdiffMult=math.ceil(math.max(0,math.min(2,1-( ((_Tune.FDiffPower/100)*avg*_GThrot) + ((_Tune.FDiffCoast/100)*avg*(1-_GThrot)))))*100)/100
			FRdiffMult=2-FLdiffMult
		elseif v.Name=="RR" then
			local avg=((_WheelSpeeds[v.Name]/_WheelSpeeds["RL"])-1)*(_Tune.RDiffPreload/10)
			RRdiffMult=math.ceil(math.max(0,math.min(2,1-( ((_Tune.RDiffPower/100)*avg*_GThrot) + ((_Tune.RDiffCoast/100)*avg*(1-_GThrot)))))*100)/100
			RLdiffMult=2-RRdiffMult
		elseif v.Name=="RL" then
			local avg=((_WheelSpeeds[v.Name]/_WheelSpeeds["RR"])-1)*(_Tune.RDiffPreload/10)
			RLdiffMult=math.ceil(math.max(0,math.min(2,1-( ((_Tune.RDiffPower/100)*avg*_GThrot) + ((_Tune.RDiffCoast/100)*avg*(1-_GThrot)))))*100)/100
			RRdiffMult=2-RLdiffMult
		end
		--Output
	
		--Apply Power
		local on=1
		if not script.Parent.IsOn.Value then on=0 end
		local throt = _GThrot
		local brake = _GBrake
		local clutch=1
		if _ClPressing then clutch=0 end
		if _RPM < _Tune.IdleRPM then clutch = 0 end
		local tq = (_OutTorque+_FlywheelEnergy)/#Drive
				
		--Apply ABS
		local tqABS = 1
		if _ABS and brake>0 and math.abs(v.RotVelocity.Magnitude*(v.Size.Y/2)/(Units.Velocity_mdivs/3.6) - v.Velocity.Magnitude/(Units.Velocity_mdivs/3.6))-_Tune.ABSThreshold>0 then
			tqABS = math.max(0, _Tune.ABSLimit / 100)
		end
		if tqABS<1 then
			_ABSActive = true
		end
		_ABSAmt += tqABS
		_ABSTracker[v.Name] = 1 - tqABS
	
		local PBrakeV=0
		if _PBrake==true then PBrakeV=1 else PBrakeV=0 end
		
		local driven = false
		for _,a in next, (Drive) do if a==v then driven = true end end
		if driven then
			--Apply AWD Vectoring
			if _Tune.Config == "AWD" then
				local bias = (_Tune.TorqueVector+1)
				if string.find(v.Name,"F") then
					tq = tq*(2-bias)
				elseif string.find(v.Name,"R") then
					tq = tq*bias
				end
			end
			
			--Apply TCS
			tqTCS = 1
			if _TCS and throt>0 then
				tqTCS = 1-(math.min(math.max(0,math.abs(v.RotVelocity.Magnitude*(v.Size.Y/2)/(Units.Velocity_mdivs/3.6) - v.Velocity.Magnitude/(Units.Velocity_mdivs/3.6))-_Tune.TCSThreshold)/_Tune.TCSGradient,1)*(1-(_Tune.TCSLimit/100)))
			end
			if tqTCS < 1 then
				_TCSActive = true
			end
			_TCSAmt += tqTCS
			_TCSTracker[v.Name] = 1 - tqTCS
			
			--Update Forces
			local dir=1
			if _CGear==-1 then dir = -1 end
		
			local tqOUT = tq*1.356*Units.Torque_nm*(60/workspace:GetRealPhysicsFPS())*throt*tqTCS*on*clutch
			-- convert lb-ft to nm to roblox stuff
			
			if v.Name=='RR' then
				v["#AV"].MotorMaxTorque=tqOUT*RRdiffMult*diffMult
			elseif v.Name=='RL' then
				v["#AV"].MotorMaxTorque=tqOUT*RLdiffMult*diffMult
			elseif v.Name=='FR' then
				v["#AV"].MotorMaxTorque=tqOUT*FRdiffMult*diffMult
			elseif v.Name=='FL' then
				v["#AV"].MotorMaxTorque=tqOUT*FLdiffMult*diffMult
			else
				v["#AV"].MotorMaxTorque=tqOUT*diffMult
			end
			v["#AV"].AngularVelocity=_spLimit*dir
		
			if string.find(v.Name,"F") then
				v["#BV"].MotorMaxTorque=(FBrakeForce*(60/workspace:GetRealPhysicsFPS())*brake*tqABS)+(EBrakeForce*((1-throt)*(_RPM/_Tune.Redline)))+(PBrakeForceF*PBrakeV)
			else
				v["#BV"].MotorMaxTorque=(RBrakeForce*(60/workspace:GetRealPhysicsFPS())*brake*tqABS)+(EBrakeForce*((1-throt)*(_RPM/_Tune.Redline)))+(PBrakeForceR*PBrakeV)
			end
		else
			v["#AV"].MotorMaxTorque=0
			v["#AV"].AngularVelocity=0
			if string.find(v.Name,"F") then
				v["#BV"].MotorMaxTorque=(FBrakeForce*(60/workspace:GetRealPhysicsFPS())*brake*tqABS)+(PBrakeForceF*PBrakeV)
			else
				v["#BV"].MotorMaxTorque=(RBrakeForce*(60/workspace:GetRealPhysicsFPS())*brake*tqABS)+(PBrakeForceR*PBrakeV)
			end
		end
	end
end



--[[Flip]]
function Flip()
	--Detect Orientation
	if (car.DriveSeat.CFrame*CFrame.Angles(math.pi/2,0,0)).lookVector.y > .1 or FlipDB then
		FlipWait=tick()
		
	--Apply Flip
	else
		if tick()-FlipWait>=3 then
			FlipDB=true
			local gyro = car.DriveSeat.Flip
			gyro.maxTorque = Vector3.new(10000,0,10000)
			gyro.P=3000
			gyro.D=500
			wait(1)
			gyro.maxTorque = Vector3.new(0,0,0)
			gyro.P=0
			gyro.D=0
			FlipDB=false
		end
	end
end

--[[Run]]

--Print Version
local ver=require(car.Settings.Version)
print("RA "..ver)

--Runtime Loops

game:GetService("RunService").Heartbeat:connect(function(dt)
	--Update Internal Values
	_TCSAmt = #Drive
	_ABSAmt = #car.Wheels:GetChildren()
	_TCSActive = false
	_ABSActive = false
	_IsOn = script.Parent.IsOn.Value
	_InControls = script.Parent.ControlsOpen.Value
	_LastInputWasGamepad = string.find(UserInputService:GetLastInputType().Name, "Gamepad") and true or false
	
	FBrakeForce =_Tune.BrakeForce*_Tune.BrakeBias
	RBrakeForce =_Tune.BrakeForce*(1-_Tune.BrakeBias)
	
	--Update External Values
	setValue("Number", "Gear", _CGear)
	car.Settings.Interface.Values.Gear.Value = _CGear
	setValue("Number", "RPM", _RPM)
	setValue("Number", "Boost", _TBoost + _SBoost)
	setValue("Number", "BoostTurbo", _TBoost)
	setValue("Number", "BoostSuper", _SBoost)
	setValue("Number", "HpNatural", _NH)
	setValue("Number", "HpElectric", _EH)
	setValue("Number", "HpTurbo", _TH)
	setValue("Number", "HpSuper", _SH)
	setValue("Number", "HpBoosted", _BH)
	setValue("Number", "Horsepower", _HP)
	setValue("Number", "TqNatural", _NT)
	setValue("Number", "TqElectric", _ET)
	setValue("Number", "TqTurbo", _TT)
	setValue("Number", "TqSuper", _ST)
	setValue("Number", "TqBoosted", _TT + _ST)
	setValue("Number", "Torque", min(_NT + _BT + _ET,math.clamp(min(_NT + _BT + _ET,N13>0 and N13*(_Tune.EqPoint/1000/(_RPM/1000)) or math.huge), 0, 1e6)))
	setValue("String", "TransmissionMode", _TMode)
	setValue("Number", "Throttle", _GThrot)
	setValue("Number", "Brake", _GBrake)
	setValue("Number", "IThrottle", _IThrot)
	setValue("Number", "IBrake", _IBrake)
	if getValue("AutoClutch") then
		setValue("Number", "Clutch", _Clutch)
	end
	setValue("Number", "SteerC", _GSteerC)
	setValue("Number", "SteerT", _GSteerT)
	setValue("Bool", "PBrake", _PBrake)
	setValue("Bool", "TCS", _TCS)
	setValue("Bool", "TCSActive", _TCSActive)
	setValue("Number", "TCSAmt", 2-(_TCSAmt / #Drive))
	setValue("Bool", "ABS", _ABS)
	setValue("Number", "ABSAmt", 2-(_ABSAmt / #car.Wheels:GetChildren()))
	setValue("Bool", "ABSActive", _ABSActive)
	setValue("Bool", "MouseSteerOn", _MSteer)
	setValue("Vector3", "Velocity", car.DriveSeat.AssemblyLinearVelocity)
	setValue("CFrame", "CarCenter", GetCarCenter())
	for i, v in next, _TCSTracker do
		if not script.Parent.Values:FindFirstChild("TCSTracker") then
			Instance.new("Folder", script.Parent.Values).Name = "TCSTracker"
		end
		setValue("Number", i, v, script.Parent.Values.TCSTracker)
	end
	for i, v in next, _ABSTracker do
		if not script.Parent.Values:FindFirstChild("ABSTracker") then
			Instance.new("Folder", script.Parent.Values).Name = "ABSTracker"
		end
		setValue("Number", i, v, script.Parent.Values.ABSTracker)
	end
	for _, wheel in next, car.Wheels:GetChildren() do
		if not _WheelSpeedsTable[wheel.Name] then
			_WheelSpeedsTable[wheel.Name] = {}
		end
		table.insert(_WheelSpeedsTable[wheel.Name], wheel.RotVelocity.Magnitude)
		if #_WheelSpeedsTable[wheel.Name] > 6 then
			table.remove(_WheelSpeedsTable[wheel.Name], 1)
		end
		local avg = 0
		for _, a in next, _WheelSpeedsTable[wheel.Name] do
			avg += a
		end
		avg /= #_WheelSpeedsTable[wheel.Name]
		_WheelSpeeds[wheel.Name] = avg
	end
	local rot = 0
	for i, v in next, _WheelSpeeds do
		if not script.Parent.Values:FindFirstChild("WheelSpeeds") then
			Instance.new("Folder", script.Parent.Values).Name = "WheelSpeeds"
		end
		setValue("Number", i, v, script.Parent.Values.WheelSpeeds)
		rot += v*(car.Wheels[i].Size.Y/2)
	end
	setValue("Number", "AverageRotSpeed", rot/#car.Wheels:GetChildren())
	setValue("Vector3", "Acceleration", (car.DriveSeat.AssemblyLinearVelocity-_OldVelocity)*(1/dt))
	_OldVelocity = car.DriveSeat.AssemblyLinearVelocity
	setValue("Number", "DragFactor", _DragFactor)
	
	if getValue("DriveReady") then
		Inputs(dt)
		Steering(dt)
		Gear()
		Engine(dt)
	end
	
	--Automatic Transmission
	if _TMode == "Auto" then Auto() end
	--Flip
	if _Tune.AutoFlip then Flip() end

end)

setValue("Bool", "DriveReady", true)

for i, v in pairs(car.Wheels:GetChildren()) do
	if v.Name == "FL" then
		v["#AV"].AngularVelocity = 0
		v["#AV"].MotorMaxTorque = 0
		v["#AV"].MotorMaxAcceleration = 1e308
	end
	if v.Name == "FR" then
		v["#AV"].AngularVelocity = 0
		v["#AV"].MotorMaxTorque = 0
		v["#AV"].MotorMaxAcceleration = 1e308
	end
	if v.Name == "RL" then
		v["#AV"].AngularVelocity = 0
		v["#AV"].MotorMaxTorque = 0
		v["#AV"].MotorMaxAcceleration = 1e308
	end
	if v.Name == "RR" then
		v["#AV"].AngularVelocity = 0
		v["#AV"].MotorMaxTorque = 0
		v["#AV"].MotorMaxAcceleration = 1e308
	end
end

car.DriveSeat.ChildRemoved:connect(function(child) 
	if child.Name=="SeatWeld" and child:IsA("Weld") then 
		for i, v in pairs(car.Wheels:GetChildren()) do
			if v.Name == "FL" then
				v["#AV"].AngularVelocity = 0
				v["#AV"].MotorMaxTorque = 0
				v["#AV"].MotorMaxAcceleration = 0
			end
			if v.Name == "FR" then
				v["#AV"].AngularVelocity = 0
				v["#AV"].MotorMaxTorque = 0
				v["#AV"].MotorMaxAcceleration = 0
			end
			if v.Name == "RL" then
				v["#AV"].AngularVelocity = 0
				v["#AV"].MotorMaxTorque = 0
				v["#AV"].MotorMaxAcceleration = 0
			end
			if v.Name == "RR" then
				v["#AV"].AngularVelocity = 0
				v["#AV"].MotorMaxTorque = 0
				v["#AV"].MotorMaxAcceleration = 0
			end
		end
	end 
end)

function exitIsOn()
	if _Tune.AutoStart == false then
		if script.Parent.IsOn.Value == true then
			for i, v in pairs(car.Wheels:GetChildren()) do
				if _Tune.Config == "AWD" then
					if v.Name == "FL" then
						v["#BV"].MotorMaxTorque = _Tune.EBrakeForce
					end
					if v.Name == "FR" then
						v["#BV"].MotorMaxTorque = _Tune.EBrakeForce
					end
					if v.Name == "RL" then
						v["#BV"].MotorMaxTorque = _Tune.EBrakeForce
					end
					if v.Name == "RR" then
						v["#BV"].MotorMaxTorque = _Tune.EBrakeForce
					end	
				end
				if _Tune.Config == "FWD" then
					if v.Name == "FL" then
						v["#BV"].MotorMaxTorque = _Tune.EBrakeForce
					end
					if v.Name == "FR" then
						v["#BV"].MotorMaxTorque = _Tune.EBrakeForce
					end
					if v.Name == "RL" then
						v["#BV"].MotorMaxTorque = 0
					end
					if v.Name == "RR" then
						v["#BV"].MotorMaxTorque = 0
					end	
				end
				if _Tune.Config == "RWD" then
					if v.Name == "FL" then
						v["#BV"].MotorMaxTorque = 0
					end
					if v.Name == "FR" then
						v["#BV"].MotorMaxTorque = 0
					end
					if v.Name == "RL" then
						v["#BV"].MotorMaxTorque = _Tune.EBrakeForce
					end
					if v.Name == "RR" then
						v["#BV"].MotorMaxTorque = _Tune.EBrakeForce
					end	
				end
			end	
		end	
	end
end

car.DriveSeat.ChildRemoved:Connect(exitIsOn)

while wait() do
	local kmhcreep = _Tune.CreepSpeed * .994193907579735
	if _Tune.Creep == true then
		if (vl.Throttle.Value < _Tune.CreepMaxThrot and ison.value == true and vl.RPM.Value > 0 and vl.Velocity.Value.Magnitude < kmhcreep and (math.abs(vl.Gear.Value) > 0)) and (vl.Gear.Value < 2) and (vl.Brake.Value == 0) and (vl.PBrake.Value == false) then
			car.DriveSeat.Roll.MaxForce = Vector3.new(_Tune.CreepStrength,0,_Tune.CreepStrength)
		else
			car.DriveSeat.Roll.MaxForce = Vector3.new(0,0,0)
		end
		car.DriveSeat.Roll.Velocity = car.DriveSeat.CFrame.lookVector*(kmhcreep*(math.min(vl.Gear.Value,1)))
	end
end
