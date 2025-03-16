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

-- All units derived from: https://create.roblox.com/docs/physics/units
-- Converting from the SI unit to the Roblox unit
local Units = {}

Units.Mass_kg = 0.0456									-- Mass in kilograms (kg)
Units.Length_mm = 280									-- Length in milimetres (mm)
Units.Force_N = .163									-- Force in Newtons (N)
Units.Stiffness_Ndivm = Units.Mass_kg					-- Stiffness in Newtons per metre (N/m)
Units.Damping_N_sdivm = Units.Mass_kg					-- Damping in Newton-seconds per metre (N*s/m)
Units.Velocity_mdivs = 1/(Units.Length_mm/1000)			-- Velocity in metres per second (m/s)
Units.Torque_nm = Units.Force_N/(Units.Length_mm/1000)	-- Torque in Newton-metres (Nm)
return Units
