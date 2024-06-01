-- Fumo 2024
AddCSLuaFile()
ENT.Type = "anim"
ENT.Author = "Fumo"
ENT.Information = "points"
ENT.PrintName = "Compass"
ENT.Category = "JMod - EZ HL:2 Extra"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.JModEZstorable = true
ENT.JModPreferredCarryAngles = Angle(0, -90, 90)






if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_lab/compass01.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:DrawShadow(true)
		self:SetUseType(SIMPLE_USE)
		---
		local Phys = self:GetPhysicsObject()

		timer.Simple(.01, function()
			if IsValid(Phys) then
				Phys:SetMass(2)
				Phys:Wake()
			end
		end)
	end

	function ENT:PhysicsCollide(data, physobj)
		if data.DeltaTime > 0.2 and data.Speed > 50 then
			self:EmitSound("physics/plastic/plastic_box_impact_soft" .. math.random(1, 3) .. ".wav", 60, math.random(70, 130))
		end
	end

	function ENT:Use(ply)
			ply:PickupObject(self)
	end

	function ENT:Think()
		local Time = CurTime()
	end
end

if CLIENT then
	function ENT:Initialize()

	end
		
	function ENT:Think()
	local Time = CurTime()
		local SelfAng = self:GetAngles()
		self:ManipulateBoneAngles(1, Angle(-SelfAng.y, 0, 0), false)
	end

	function ENT:Draw()
		self:DrawModel()
	end

	language.Add("ent_fumo_gmod_compass", "Compass")
end
