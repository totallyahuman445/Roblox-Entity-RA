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

local SquealEnabled = false  -- Carbon ceramic or damaged brake squeal on that specific wheel.
local SmokeEnabled  = true	 -- Tyre smoke on that specific wheel.	
local F             = false
local FR            = false
local FL            = false
local M             = false
local MR            = false
local ML            = false
local R             = false
local RR            = false
local RL            = false

local wheelparent = script.Parent.Parent.Parent
local wheeltype = script.Parent.Parent.Parent.Name
local Wheels = script.Parent.Parent.Parent.Parent
local _Tune = require(script.Parent.Parent.Parent.Parent.Parent.Settings)
local car = script.Parent.Parent.Parent.Parent.Parent.Settings.Interface.Car.Value
local weight = _Tune.Weight
local children = Wheels:GetChildren()
local number_of_wheels = #children
local TweenService  = game:GetService("TweenService")

if SquealEnabled == true then
	wheelparent:SetAttribute("Squeal", true)
end

if SmokeEnabled == true then
	wheelparent:SetAttribute("Smoke", true)
end

if wheeltype == "FR" and _Tune.FSwayBarEnabled == true then
	local F = false
	local FR = true
	local FL = false
	local M = false
	local MR = false
	local ML = false
	local R = false
	local RR = false
	local RL = false
	local FSwayBar = script.Parent.Parent.Parent.SuspensionGeometry.LowerArmF:FindFirstChild("FSwayBar")
	if FSwayBar then
		FSwayBar.Enabled = true
		FSwayBar.Visible = _Tune.FSwayBarVisible
		FSwayBar.Color = BrickColor.new(_Tune.FSwayBarColor)
		FSwayBar.Thickness = _Tune.FSwayBarThicknesss
		FSwayBar.LimitsEnabled = _Tune.FSwayBarLimits
		FSwayBar.LimitAngle0 = _Tune.FSwaybarLimitAngle0
		FSwayBar.LimitAngle1 = _Tune.FSwaybarLimitAngle1
	end
end

if wheeltype == "RR" and _Tune.FSwayBarEnabled == true then
	local F = false
	local FR = false
	local FL = false
	local M = false
	local MR = false
	local ML = false
	local R = false
	local RR = true
	local RL = false
	local RSwayBar = script.Parent.Parent.Parent.SuspensionGeometry.LowerArmB:FindFirstChild("RSwayBar")
	if RSwayBar then
		RSwayBar.Enabled = true
		RSwayBar.Visible = _Tune.RSwayBarVisible
		RSwayBar.Color = BrickColor.new(_Tune.RSwayBarColor)
		RSwayBar.Thickness = _Tune.RSwayBarThicknesss
		RSwayBar.LimitsEnabled = _Tune.RSwayBarLimits
		RSwayBar.LimitAngle0 = _Tune.RSwaybarLimitAngle0
		RSwayBar.LimitAngle1 = _Tune.RSwaybarLimitAngle1
	end
end

local value = weight/number_of_wheels
local Debounce = false
if _Tune.RunningOver == true then
	script.Parent.Touched:connect(function(hit)
		if not Debounce then
			if hit and hit.Parent and hit.Parent:FindFirstChild("Humanoid") then
				hit.Parent.Humanoid.Health = hit.Parent.Humanoid.Health - value/7.5
				Debounce = true
				wait(2)           --Change cooldown here.
				Debounce = false
			end
		end
	end)
end