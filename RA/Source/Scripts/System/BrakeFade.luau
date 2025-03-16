local FE = workspace.FilteringEnabled
local car = script.Parent.Car.Value
local _Tune = require(car.Settings)      
script.BrakeDefault.Value = _Tune.BrakeForce

while wait () do 
	if _Tune.BrakeFadeOn == true then
		if _Tune.HeatDisplay == true then
			script.Parent.Brake_Temperature.Visible = true
		end
		local FS = math.floor(car.Wheels.FL.Velocity.Magnitude+car.Wheels.FR.Velocity.Magnitude/2)
		local RS = math.floor(car.Wheels.RL.Velocity.Magnitude+car.Wheels.RR.Velocity.Magnitude/2)
		local wheelspeedcombined = FS+RS/20
		if script.Parent.Values.Brake.Value > 0 and _Tune.BrakeHeat*3 < _Tune.MaxBrakeTemp and wheelspeedcombined > 0 then
			_Tune.BrakeHeat = _Tune.BrakeHeat + (_Tune.BrakeHeatingSpeed)
			local reduction = (_Tune.BrakeForce*_Tune.BrakeHeat/_Tune.BrakeReductionStress)
			_Tune.BrakeForce = (_Tune.BrakeForce - reduction)
		elseif script.Parent.Values.Brake.Value < 1 and  _Tune.BrakeHeat > 0  and wheelspeedcombined ~=0 then
			wait(_Tune.BrakeCoolingSpeed)
			if  _Tune.BrakeHeat > _Tune.OperationTemp/3  then 
				_Tune.BrakeHeat = _Tune.BrakeHeat - _Tune.BrakeCooling*wheelspeedcombined
			elseif _Tune.BrakeHeat < _Tune.OperationTemp/3 then 
				_Tune.BrakeHeat = _Tune.OperationTemp/3  	
				_Tune.BrakeForce = script.BrakeDefault.Value
			end
		end
		script.Parent.Brake_Temperature.Temp.Text = math.floor(_Tune.BrakeHeat*3).. "Brake TEMP"
	end
end



