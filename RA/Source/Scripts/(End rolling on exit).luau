local car = script.Parent.Parent.Parent
local ds = car:WaitForChild("DriveSeat",3)
if ds ~= nil then
	script.Parent.Parent.ChildRemoved:Connect(function(x)
		if x.Name == "SeatWeld" then
			script.Parent.MaxForce = Vector3.new(0,0,0)
		end
	end)
end