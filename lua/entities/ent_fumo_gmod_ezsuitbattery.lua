-- Jackarunda 2023 but stolen by Fumo 2024
AddCSLuaFile()
ENT.Type = "anim"
ENT.Author = "Fumo"
ENT.Information = "glhfggwpezpznore"
ENT.PrintName = "EZ Suit Battery"
ENT.Category = "JMod - EZ HL:2 Extra"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.JModEZstorable = true

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/items/battery.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:DrawShadow(true)
		self:SetUseType(SIMPLE_USE)
		---
		local Phys = self:GetPhysicsObject()
		timer.Simple(.01, function()
			if IsValid(Phys) then
				Phys:SetMass(5)
				Phys:Wake()
			end
		end)
		---
		self.LastTouchedTime = CurTime()
		self.EZremoveSelf = self.EZremoveSelf or false
	end

	function ENT:PhysicsCollide(data, physobj)
		if data.DeltaTime > 0.2 and data.Speed > 50 then
			self:EmitSound("physics/plastic/plastic_box_impact_soft" .. math.random(1, 3) .. ".wav", 60, math.random(70, 130))
		end
	end

	function ENT:Use(ply)
		local Time = CurTime()
		local Alt = ply:KeyDown(JMod.Config.General.AltFunctionKey)

		if Alt then
			if ply:Armor() < ply:GetMaxArmor() then
				ply:SetArmor(math.min(ply:Armor() + 15, ply:GetMaxArmor()))
				sound.Play("items/battery_pickup.wav", self:GetPos(), 90, 100)

				self:Remove()
			end
		else
			ply:PickupObject(self)
			JMod.Hint(ply, "alt to use")
			self.EZremoveSelf = false
			self.LastTouchedTime = Time
		end
	end

	function ENT:Degenerate() 
		constraint.RemoveAll(self)
		self:SetNotSolid(true)
		self:DrawShadow(false)
		self:GetPhysicsObject():EnableCollisions(false)
		self:GetPhysicsObject():EnableGravity(false)
		self:GetPhysicsObject():SetVelocity(Vector(0, 0, -5))
		timer.Simple(2, function()
			if (IsValid(self)) then self:Remove() end
		end)
	end

	function ENT:Think()
		local Time = CurTime()
		if self.EZremoveSelf and (Time - 60 > self.LastTouchedTime) then
			self:Degenerate() 
		end
	end
elseif CLIENT then
	function ENT:Initialize()
		--
	end

	function ENT:Draw()
		self:DrawModel()
	end

	language.Add("ent_fumo_gmod_ezsuitbattery", "EZ Suit Battery")
end
