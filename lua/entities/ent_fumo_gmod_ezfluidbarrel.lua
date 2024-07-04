-- Jackarunda 2021
AddCSLuaFile()
ENT.Type = "anim"
ENT.PrintName = "EZ Fluid Barrel"
ENT.Author = "Jackarunda, TheOnly8Z, Fumo, AdventureBoots"
ENT.Category = "JMod - EZ HL:2 Extra"
ENT.NoSitAllowed = true
ENT.Spawnable = true
ENT.AdminSpawnable = true
---
ENT.JModPreferredCarryAngles = Angle(0, 0, 0)
ENT.DamageThreshold = 120
ENT.IsJackyEZcrate = true
---
function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Resource")
	self:NetworkVar("String", 0, "ResourceType")
end

function ENT:ApplySupplyType(typ)
	self:SetResourceType(typ)
	self.EZsupplies = typ
	self.MaxResource = 100 * 25 -- slightly smaller than standard
end
---
function ENT:GetEZsupplies(typ)
	local Supplies = {[self:GetResourceType()] = self:GetResource()}
	if typ then
		if Supplies[typ] then
			return Supplies[typ]
		else
			return nil
		end
	else
		return Supplies
	end
end

function ENT:SetEZsupplies(typ, amt, setter)
	if not SERVER then print("[JMOD] - You can't set EZ supplies on client") return end
	if typ ~= self:GetResourceType() then return end
	if amt <= 0 then self:ApplySupplyType("generic") end
	self:SetResource(math.Clamp(amt, 0, self.MaxResource))
	self:CalcWeight()
end
---
if SERVER then
	function ENT:SpawnFunction(ply, tr)
		local SpawnPos = tr.HitPos + tr.HitNormal * 18
		local ent = ents.Create(self.ClassName)
		ent:SetAngles(Angle(0, 0, 0))
		ent:SetPos(SpawnPos)
		JMod.SetEZowner(ent, ply)
		ent:Spawn()
		ent:Activate()
		--local effectdata=EffectData()
		--effectdata:SetEntity(ent)
		--util.Effect("propspawn",effectdata)

		return ent
	end

	function ENT:Initialize()
		self:SetModel("models/jmod/ez_fluidbarrel.mdl")
		--self:SetModelScale(1.5,0)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:DrawShadow(true)
		self:SetUseType(SIMPLE_USE)
		---
		self:SetResource(0)
		self:ApplySupplyType("generic")
		self.EZconsumes = {JMod.EZ_RESOURCE_TYPES.CHEMICALS, JMod.EZ_RESOURCE_TYPES.COOLANT, JMod.EZ_RESOURCE_TYPES.FUEL, JMod.EZ_RESOURCE_TYPES.OIL, JMod.EZ_RESOURCE_TYPES.WATER}
		self.LastOpenTime = 0
		self.NextUse = 0
		self.NextLoad = 0
		---
		if istable(WireLib) then
			self.Outputs = WireLib.CreateOutputs(self, {"Type [STRING]", "Amount Left [NORMAL]"}, {"Will be 'generic' by default", "Amount of resources left in the crate"})
		end
		---
		timer.Simple(.01, function()
			self:CalcWeight()
		end)
	end

	function ENT:PhysicsCollide(data, physobj)
		if data.DeltaTime > 0.2 then
			if data.Speed > 100 then
				self.Entity:EmitSound("Wood.ImpactHard")
			end
		end
	end

	function ENT:CalcWeight()
		local Frac = self:GetResource() / self.MaxResource
		self:GetPhysicsObject():SetMass(120 + Frac * 300)
		self:GetPhysicsObject():Wake()
		if (WireLib) then
			WireLib.TriggerOutput(self, "Type", self:GetResourceType())
			WireLib.TriggerOutput(self, "Amount Left", self:GetResource())
		end
	end

	function ENT:OnTakeDamage(dmginfo)
		self.Entity:TakePhysicsDamage(dmginfo)

		if (dmginfo:GetDamage() > self.DamageThreshold) and not(self.Destroyed) then
			self.Destroyed = true
			local Pos = self:GetPos()
			sound.Play("Wood_Crate.Break", Pos)
			sound.Play("Wood_Box.Break", Pos)

			if self.ChildEntity ~= "" and self:GetResource() > 0 then
				for i = 1, math.floor(self:GetResource() / 100) do
					local Box = ents.Create(self.ChildEntity)
					Box:SetPos(Pos + self:GetUp() * 20)
					Box:SetAngles(self:GetAngles())
					Box:Spawn()
					Box:Activate()
				end
			end

			self:Remove()
		end
	end

	function ENT:Use(activator)
		JMod.Hint(activator, "crate")
		local Resource = self:GetResource()
		if self.NextUse > CurTime() then return end
		self.NextUse = CurTime() + 2
		if Resource <= 0 then return end
		local Box, Given = ents.Create(JMod.EZ_RESOURCE_ENTITIES[self:GetResourceType()]), math.min(Resource, 100 * JMod.Config.ResourceEconomy.MaxResourceMult)
		Box:SetPos(self:GetPos() + self:GetUp() * -28 + self:GetForward() * 34)
		Box:SetAngles(self:GetAngles())
		Box:Spawn()
		Box:Activate()
		Box:SetResource(Given)
		Box.NextLoad = CurTime() + 2
		self:SetResource(Resource - Given)
		self:EmitSound("snds_jack_gmod/liquid_load.ogg", 90, 80)
		self:CalcWeight()
		
		if self:GetResource() <= 0 then
			self:SetColor(Color(255, 255, 255))
			self:ApplySupplyType("generic")
		end
	end

	function ENT:Think()
	end

	--pfahahaha
	--Fumo: why
	function ENT:OnRemove()
	end

	--aw fuck you
	--Fumo: no u
	function ENT:TryLoadResource(typ, amt)
		local Time = CurTime()
		if self.NextLoad > Time then return 0 end
		if amt <= 0 then return 0 end
		local Fluidcol = {
			["chemicals"] = Color(110,255,0),
			["coolant"] = Color(0,255,203),
			["fuel"] = Color(255,0,0),
			["oil"] = Color(40,40,40),
			["water"] = Color(0,178,255)
		}
		-- If unloaded, we set our type to the item type
		if self:GetResource() <= 0 and self:GetResourceType() == "generic" then
			self:ApplySupplyType(typ)
		end

		-- Consider the loaded type
		if typ == self:GetResourceType() then
			local Resource = self:GetResource()
			local Missing = self.MaxResource - Resource
			if Missing <= 0 then return 0 end
			local Accepted = math.min(Missing, amt)
			self:SetColor(Fluidcol[typ])
			self:SetResource(Resource + Accepted)
			self:CalcWeight()
			self.NextLoad = Time + .5

			return Accepted
		end

		return 0
	end

	function ENT:PostEntityPaste(ply)
		self.NextLoad = 0
	end
elseif CLIENT then
	local TxtCol = Color(150, 150, 150, 220)

	function ENT:Draw()
		local Ang, Pos = self:GetAngles(), self:GetPos()
		local Closeness = LocalPlayer():GetFOV() * EyePos():Distance(Pos)
		local DetailDraw = Closeness < 30000 -- cutoff point is 500 units when the fov is 90 degrees
		local ResourceName = string.upper(self:GetResourceType())
		self:DrawModel()

		if DetailDraw then
			local Up, Right, Forward, Resource = Ang:Up(), Ang:Right(), Ang:Forward(), tostring(self:GetResource())
			Ang:RotateAroundAxis(Ang:Up(), 180)
			Ang:RotateAroundAxis(Ang:Forward(), 90)
			cam.Start3D2D(Pos + Up * 6 - Forward * 0 + Right * -27, Ang, .15)
			draw.SimpleText("FUMO INDUSTRIES", "JMod-Stencil-S", 0, 0, TxtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText(ResourceName, "JMod-Stencil-S", 0, 32, TxtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText(Resource .. " UNITS", "JMod-Stencil-S", 0, 70, TxtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			cam.End3D2D()
		end
	end

	language.Add("ent_fumo_gmod_ezfluidbarrel", "EZ Fluid Barrel")
end
