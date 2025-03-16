--[[ Welcome, tuner.
    ____  ___ 
   / __ \/   | Entity 
  / /_/ / /| | Roblox car chassis 
 / _, _/ ___ | 0.50.7 
/_/ |_/_/  |_| GitHub:   https://github.com/totallyahuman445/Roblox-Entity-R-Series
			   Document: https://docs.google.com/document/d/1WvOWw7ST4ZWpsCfXM3abJTTBkCA40NsayIEIdCRJOYM/edit?usp=sharing
			   Server:   https://discord.gg/JM5k8AVb
			   Log:		 https://docs.google.com/document/d/1SLW5NOAysg2rE6C52WEPnmOas_MNbeVNEv0xv2f__ps/edit?usp=sharing 
			   Credits:  https://docs.google.com/document/d/1-mIgEhmugHfVUDz4vzZMS7XYMoEdLKedy0MedRqvbyA/edit?usp=sharing 
--]]

local Tune = {}
-- It is recommended that you go to: https://www.desmos.com/calculator/lhxwlpppyh
-- to tune your vehicle's tires.

--[[Misc]]
	Tune.SaveHeatData				= true													-- Whether to save heat data when leaving the car
	Tune.TireWearOn					= false													-- False sets friction to maximum
	Tune.Haptics					= "Both"												-- Tire slippage will activate the small motor ("Controller", "Mobile", "Both", "Off")
	Tune.AmbientTemp				= workspace:GetAttribute("GlobalTemperature") or 28 	-- In celcius
	
	Tune.DirtBumps					= 20													-- Aggresiveness of artificial bumps in dirt-, sand-, and snow-type surfaces (0 for none)
	Tune.SandForce					= 10				    								-- Force in kgf of sand for every 50 km/h. This force is applied exponentially (0 for none)
	Tune.MudForce					= 5				    								    -- Force in kgf of sand for every 50 km/h. This force is applied exponentially (0 for none)

--[[Aesthetics]]
	Tune.Effects					= "All"													-- Turns smoke effects on or off, "All" for viewable by everyone, "Local" for only viewable by you, "Off" for none.
	Tune.SmokeStressOffset			= 5														-- Offsets the stress required to activate smoke-related effects (in percent, higher means less smoke).
	Tune.SmokePollingRate			= 1/60													-- "All" setting only. This changes how often the server gets data to run the smoke effects. Higher = more delay.
	Tune.TireMarkTransparencyLevels	= 8														-- How many levels of transparency there are (0 for no marks)
	Tune.TireMarkTransparency		= .95													-- The transparency of the tire marks

--[[Friction]]
	Tune.FMinTemp					= 8														-- Minimum temperature of the front tires in celcius
	Tune.FMaxTemp					= 100													-- Maximum temperature of the front tires in celcius
	Tune.FMaxFriction				= 1.7													-- Maximum friction of the front tires
	Tune.FColdStats					= {.72, 11.7, .32}										-- Loss, Sharpness, Offset
	Tune.FHotStats					= {1.56, 18.3, 1.05}									-- Loss, Sharpness, Offset
	Tune.FDirtLoss					= .1													-- Friction loss from dirty tires
	Tune.FDirtFadeRate				= .001													-- The rate that dirt fades
	Tune.FHeating					= .01													-- Heat gain from maximum slippage
	Tune.FCooling					= .002													-- Heat loss at no slippage
	Tune.FSpeedStress				= .04													-- Stress generated at 100 km/h

	Tune.RMinTemp					= 8														-- Minimum temperature of the rear tires in celcius
	Tune.RMaxTemp					= 100													-- Maximum temperature of the rear tires in celcius
	Tune.RMaxFriction				= 1.7													-- Maximum friction of the rear tires
	Tune.RColdStats					= {.72, 11.7, .32}										-- Loss, Sharpness, Offset
	Tune.RHotStats					= {1.56, 18.3, 1.05}									-- Loss, Sharpness, Offset
	Tune.RDirtLoss					= .1													-- Friction loss from dirty tires
	Tune.RDirtFadeRate				= .001													-- The rate that dirt fades
	Tune.RHeating					= .01													-- Heat gain from maximum slippage
	Tune.RCooling					= .002													-- Heat loss at no slippage
	Tune.RSpeedStress				= .04													-- Stress generated at 100 km/h	

--[[Tire Flex]]
	Tune.TireFlex					= true													-- Uses a separate collision to simulate tire flex
	Tune.ShowTF						= false													-- Debug tire flex

	Tune.FPressureForce				= 22													-- Pressure force (no unit)
	Tune.FTireThickness				= 50													-- Tire sidewall thickness in milimetres
	Tune.FTireWeight				= 9														-- Tire weight in kg

	Tune.RPressureForce				= 22													-- Pressure force (no unit)
Tune.RTireThickness				= 50													-- Tire sidewall thickness in milimetres
	Tune.RTireWeight				= 9														-- Tire weight in kg

return Tune
