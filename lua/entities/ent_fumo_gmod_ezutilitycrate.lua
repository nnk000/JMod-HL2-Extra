-- AdventureBoots 2023 but stolen by Fumo 2024
AddCSLuaFile()
ENT.Type = "anim"
ENT.PrintName = "EZ Utility Crate"
ENT.Author = "Jackarunda, AdventureBoots, TheOnly8Z, Fumo"
ENT.Category = "JMod - EZ HL:2 Extra"
ENT.NoSitAllowed = true
ENT.Spawnable = true
ENT.AdminSpawnable = true
---
ENT.JModPreferredCarryAngles = Angle(0, 180, 0)
ENT.DamageThreshold = 200
---
ENT.IsJackyEZcrate = true
---
function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Resource")
end

function ENT:GetEZsupplies(typ)
	local Supplies = self.Contents
	if typ then
		if Supplies[typ] and Supplies[typ] then
			return Supplies[typ]
		else
			return nil
		end
	else
		return Supplies
	end
end

function ENT:SetEZsupplies(typ, amt, setter)
	self.Contents[typ] = amt
	self:SetResource(math.Clamp(amt, 0, self.MaxResource))
	if SERVER then
		net.Start("ABoot_ContainerMenu")
			net.WriteBool(false)
			net.WriteEntity(self)
			net.WriteString(typ)
			net.WriteInt(amt, 32)
		net.Broadcast()
		self:CalcWeight()
	end
end
---

if SERVER then
	function ENT:SpawnFunction(ply, tr)
		local SpawnPos = tr.HitPos + tr.HitNormal * 40
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
		self:SetModel("models/aboot/ammocrate_aboot.mdl")
		self:SetMaterial("models/jmod/fumo_utility_crate")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:DrawShadow(true)
		self:SetUseType(SIMPLE_USE)
		---
		self:SetResource(0)
		self.MaxResource = 100 * 10 -- SMOL size
		self.EZconsumes = {}

		for k, v in pairs(JMod.EZ_RESOURCE_TYPES) do
			table.insert(self.EZconsumes, v)
		end

		self.Contents = {}

		for k, v in pairs(JMod.EZ_RESOURCE_TYPES) do
			self.Contents[v] = 0
		end

		self.NextLoad = 0
		self.NextUse = 0

		---
		timer.Simple(.01, function()
			self:CalcWeight()
		end)
	end

	function ENT:PhysicsCollide(data, physobj)
		if data.DeltaTime > 0.2 then
			if data.Speed > 100 then
				self.Entity:EmitSound("Metal_Box.ImpactSoft")
				self.Entity:EmitSound("Metal_Box.ImpactHard")
			end
		end
	end

	function ENT:CalcWeight()
		local Frac = self:GetResource() / self.MaxResource
		self:GetPhysicsObject():SetMass(150 + Frac * 300)
		self:GetPhysicsObject():Wake()
		self:SetResource(0)
		for k, v in pairs(self.Contents) do
			if v > 0 then
				self:SetResource(self:GetResource() + v)
			end
		end
	end

	function ENT:OnTakeDamage(dmginfo)
		self.Entity:TakePhysicsDamage(dmginfo)

		if dmginfo:GetDamage() > self.DamageThreshold then
			local Pos = self:GetPos()
			sound.Play("Metal_Box.Break", Pos)
			sound.Play("Metal_Box.Break", Pos)

			if self:GetResource() > 0 then
				for k, v in pairs(self.Contents) do
					for i = 1, math.floor(v / 100) do
						local Box = ents.Create(JMod.EZ_RESOURCE_ENTITIES[k])
						Box:SetPos(Pos + self:GetUp() * 20)
						Box:SetAngles(self:GetAngles())
						Box:Spawn()
						Box:Activate()
					end
				end
			end

			self:Remove()
		end
	end

	function ENT:Use(activator)
		local Time = CurTime()
		if self.NextUse > Time then return end
		self.NextUse = Time + 1
		JMod.Hint(activator, "crate")

		local TrimmedTable = {}
		for k, v in pairs(self.Contents) do
			if v > 0 then
				TrimmedTable[k] = v
			end
		end
		if table.IsEmpty(TrimmedTable) then return end
		net.Start("ABoot_ContainerMenu")
			net.WriteBool(true)
			net.WriteEntity(self)
			net.WriteTable(TrimmedTable)
		net.Send(activator)

		self:EmitSound("Ammo_Crate.Open")
	end

	function ENT:DropContents(ply, resTyp, amt)
		local AmountLeft = self.Contents[resTyp]
		if AmountLeft <= 0 then return end
		local Needed = math.min(amt, AmountLeft)
		for i = 1, math.ceil(Needed / 100) do
			timer.Simple(0.3 * i, function()
				if not IsValid(self) then return end
				local Box, Given = ents.Create(JMod.EZ_RESOURCE_ENTITIES[resTyp]), math.min(Needed, 100)
                Box:SetPos(self:GetPos() + self:GetForward() * 32 + self:GetUp() * 15)
				Box:SetAngles(self:GetAngles())
				Box:Spawn()
				Box:Activate()
				Box:SetEZsupplies(Box.EZsupplies, Given, self)
				Box.NextLoad = CurTime() + 2
				Needed = Needed - Given
				self:CalcWeight()
			end)
		end
		self.Contents[resTyp] = self.Contents[resTyp] - Needed
		self.NextUse = CurTime() + 1
	end

	function ENT:Think()
	end

	--pfahahaha
	function ENT:OnRemove()
	end

	function ENT:TryLoadResource(typ, amt, overrideTimer)
		local Time = CurTime()
		if (self.NextLoad > Time) and not(overrideTimer) then self.NextLoad = math.min(self.NextLoad, Time + .1) return 0 end
		if amt < 1 then return 0 end

		-- Consider the loaded type
		local Resource = self:GetResource()
		local Missing = self.MaxResource - Resource
		if Missing <= 0 then return 0 end
		local Accepted = math.min(Missing, amt)

		self.Contents[typ] = self.Contents[typ] + Accepted

		self:CalcWeight()
		self.NextLoad = Time + .5

		net.Start("ABoot_ContainerMenu")
			net.WriteBool(false)
			net.WriteEntity(self)
			net.WriteString(typ)
			net.WriteInt(self.Contents[typ], 32)
		net.Broadcast()

		return Accepted
	end

	function ENT:PostEntityPaste(ply, ent, createdEntities)
		self:CalcWeight()
		local Time = CurTime()
		self.NextLoad = Time
		self.NextUse = Time
	end

elseif CLIENT then
	--include("jmod/cl_gui.lua")
	local TxtCol = Color(125, 125, 125, 220)

	function ENT:Initialize()
		self.MaxResource = 100 * 10
		self.Contents = {}

		for k, v in pairs(JMod.EZ_RESOURCE_TYPES) do
			self.Contents[v] = 0
		end
	end

	function ENT:Draw()
		local Ang, Pos = self:GetAngles(), self:GetPos()
		local Closeness = LocalPlayer():GetFOV() * EyePos():Distance(Pos)
		local DetailDraw = Closeness < 75000 -- cutoff point is 500 units when the fov is 90 degrees
		self:DrawModel()

		if DetailDraw then
			local Up, Right, Forward, Resource = Ang:Up(), Ang:Right(), Ang:Forward(), tostring(self:GetResource())
			Ang:RotateAroundAxis(Ang:Right(), 90)
			Ang:RotateAroundAxis(Ang:Up(), -90)
			cam.Start3D2D(Pos + Up * 9 - Forward * 17 + Right * 0, Ang, .11)
			draw.SimpleText("FUMO INDUSTRIES", "JMod-Stencil", 0, 0, TxtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText(Resource .. "/" .. tostring(self.MaxResource), "JMod-Stencil", 0, 85, TxtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			cam.End3D2D()
			---
			Ang:RotateAroundAxis(Ang:Right(), 180)
			cam.Start3D2D(Pos + Up * 9 + Forward * 17 - Right * 0, Ang, .11)
			draw.SimpleText("FUMO INDUSTRIES", "JMod-Stencil", 0, 0, TxtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText(Resource .. "/" .. tostring(self.MaxResource), "JMod-Stencil", 0, 85, TxtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			cam.End3D2D()
		end
	end

	language.Add("ent_fumo_gmod_ezutilitycrate", "EZ Utility Crate")
end
