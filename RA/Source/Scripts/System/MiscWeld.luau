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
local MiscWeld = {}

function MakeWeld(x,y,type,s) 
	if type==nil then type="Weld" end
	local W=Instance.new(type)
	W.Part0=x W.Part1=y 
	W.C0=x.CFrame:inverse()*x.CFrame 
	W.C1=y.CFrame:inverse()*x.CFrame 
	W.Parent=x 
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

car = script.Parent.Parent.Parent
misc = car:WaitForChild("Misc")
---------------------------
--[[
	--Main anchor point is the DriveSeat <car.DriveSeat>	
	
	Usage:
		MakeWeld(Part1,Part2,WeldType*,MotorVelocity**) *default is "Weld"  **Applies to Motor welds only
		ModelWeld(Model,MainPart)
	Example:
		MakeWeld(car.DriveSeat,misc.PassengerSeat)
		MakeWeld(car.DriveSeat,misc.SteeringWheel,"Motor",.2)
		ModelWeld(car.DriveSeat,misc.Door)
]]

--Weld stuff here
car.DriveSeat.ChildAdded:connect(function(child)
	if child.Name=="SeatWeld" and child:IsA("Weld") and game.Players:GetPlayerFromCharacter(child.Part1.Parent)~=nil then
		child.C0=CFrame.new(0,-.5,0)*CFrame.fromEulerAnglesXYZ(-(math.pi/2),0,0)*CFrame.Angles(math.rad(13),0,0)
	end
end)
---------------------------
return MiscWeld