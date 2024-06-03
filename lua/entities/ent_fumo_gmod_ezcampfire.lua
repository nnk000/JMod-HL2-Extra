-- Jackarunda 2021 but stolen by Fumo 2024
AddCSLuaFile()
ENT.Base = "ent_jack_gmod_ezmachine_base"
ENT.Type = "anim"
ENT.PrintName = "EZ Campfire"
ENT.Author = "Fumo"
ENT.Category = "JMod - EZ HL:2 Extra"
ENT.Information = "glhfggwpezpznore"
ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
ENT.Model = "models/jmod/ez_campfire.mdl"
ENT.Mass = 45
ENT.JModPreferredCarryAngles = Angle(0, 0, 0)
ENT.EZconsumes = {
	JMod.EZ_RESOURCE_TYPES.BASICPARTS,
	JMod.EZ_RESOURCE_TYPES.WOOD,
	JMod.EZ_RESOURCE_TYPES.COAL,
	JMod.EZ_RESOURCE_TYPES.IRONORE,
	JMod.EZ_RESOURCE_TYPES.LEADORE,
	JMod.EZ_RESOURCE_TYPES.ALUMINUMORE,
	JMod.EZ_RESOURCE_TYPES.COPPERORE,
	JMod.EZ_RESOURCE_TYPES.TUNGSTENORE,
	JMod.EZ_RESOURCE_TYPES.TITANIUMORE,
	JMod.EZ_RESOURCE_TYPES.SILVERORE,
	JMod.EZ_RESOURCE_TYPES.GOLDORE,
	JMod.EZ_RESOURCE_TYPES.URANIUMORE,
	JMod.EZ_RESOURCE_TYPES.PLATINUMORE,
	JMod.EZ_RESOURCE_TYPES.SAND
}
ENT.FlexFuels = {JMod.EZ_RESOURCE_TYPES.WOOD, JMod.EZ_RESOURCE_TYPES.COAL}
ENT.EZcolorable = false
---
ENT.StaticPerfSpecs={
	MaxDurability = 90,
	Armor = .7
}
local STATE_BROKEN, STATE_FINE, STATE_PROCESSING = -1, 0, 1
function ENT:CustomSetupDataTables()
	self:NetworkVar("Float", 1, "Progress")
	self:NetworkVar("Float", 2, "Ore")
	self:NetworkVar("String", 0, "OreType")
end
if(SERVER)then
	function ENT:CustomInit()
		local phys = self.Entity:GetPhysicsObject()
		if phys:IsValid()then
			phys:SetBuoyancyRatio(.3)
		end
		if not(self.EZowner)then self:SetColor(Color(255, 255, 255)) end
		self:SetProgress(0)
		self:SetOre(0)
		self:SetOreType("generic")
		self.MaxOre = 60
		self.NextEffThink = 0
		self.NextSmeltThink = 0
		self.NextEnvThink = 0
	end

	function ENT:ResourceLoaded(typ, accepted)
		if typ == self:GetOreType() and accepted >= 1 then
			self:TurnOn(self.EZowner)
		end
	end

	function ENT:Use(activator)
		local Alt = activator and activator:KeyDown(JMod.Config.General.AltFunctionKey)
		local State = self:GetState()
		if(State == STATE_FINE) then
			if (self:GetElectricity() > 0) then
				if Alt then
					self:TurnOn(activator)
				end
			else
				JMod.Hint(activator, "refillprimbench")
			end
		elseif (State == STATE_PROCESSING) then
			self:TurnOff(activator)
		else
			JMod.Hint(activator, "destroyed")
		end
	end

	function ENT:TurnOn(activator)
		local State = self:GetState()
		if (State == STATE_PROCESSING) or (State == STATE_BROKEN) then return end
		if (self:GetElectricity() <= 0) then JMod.Hint(activator, "refill") return end
		self:SetState(STATE_PROCESSING)
		self:EmitSound("snd_jack_littleignite.wav")
		timer.Simple(0.1, function()
			if(self.SoundLoop)then self.SoundLoop:Stop() end
			self.SoundLoop = CreateSound(self, "snds_jack_gmod/intense_fire_loop.wav")
			self.SoundLoop:SetSoundLevel(50)
			self.SoundLoop:Play()
		end)
	end

	function ENT:TurnOff(activator)
		if (self:GetState() <= STATE_FINE) then return end
		self:SetState(STATE_FINE)
		self:ProduceResource()
		if(self.SoundLoop)then self.SoundLoop:Stop() end
	end

	function ENT:Think()
		local State, Time, OreTyp = self:GetState(), CurTime(), self:GetOreType()
		local FirePos = self:GetPos() + self:GetUp() * 0 + self:GetRight() * 0 + self:GetForward() * 0

		if (State == STATE_PROCESSING) then
			if (self.NextSmeltThink < Time) then
				self.NextSmeltThink = Time + 1
				if (self:WaterLevel() > 0) then 
					self:TurnOff() 
					local Foof = EffectData()
					Foof:SetOrigin(FirePos)
					Foof:SetNormal(Vector(0, 0, 1))
					Foof:SetScale(10)
					Foof:SetStart(self:GetPhysicsObject():GetVelocity())
					util.Effect("eff_jack_gmod_ezsteam", Foof, true, true)
					self:EmitSound("snds_jack_gmod/hiss.wav", 120, 90)
					return 
				end
				if not OreTyp then self:TurnOff() return end

				self:ConsumeElectricity(.1)

				if OreTyp and not(self:GetOre() <= 0) then
					local OreConsumeAmt = .25
					local MetalProduceAmt = .4 * JMod.SmeltingTable[OreTyp][2]
					self:SetOre(self:GetOre() - OreConsumeAmt)
					self:SetProgress(self:GetProgress() + MetalProduceAmt)
					self:ConsumeElectricity(.5)
					if self:GetProgress() >= 100 then
						self:ProduceResource()
					end
				else
					self:ProduceResource()
				end
			end
			if (self.NextEffThink < Time) then
				self.NextEffThink = Time + .1
				local Eff = EffectData()
				Eff:SetOrigin(FirePos)
				Eff:SetNormal(self:GetUp())
				Eff:SetScale(.015)
				util.Effect("eff_jack_gmod_ezoilfiresmoke", Eff, true)
			end
			if (self.NextEnvThink < Time) then
				self.NextEnvThink = Time + 5

				local Tr = util.QuickTrace(FirePos, Vector(0, 0, 9e9), self)
				if not (Tr.HitSky) then
					for i = 1, 1 do
						local Gas = ents.Create("ent_jack_gmod_ezgasparticle")
						Gas:SetPos(Tr.HitPos)
						JMod.SetEZowner(Gas, self.EZowner)
						Gas:SetDTBool(0, true)
						Gas:Spawn()
						Gas:Activate()
						Gas.CurVel = (VectorRand() * math.random(1, 100))
					end
				end
			end
		end
		self:NextThink(Time + .1)
	end

	function ENT:PhysicsCollide(data, physobj)
		if data.DeltaTime > 0.2 then
			if data.Speed > 100 then
				self.Entity:EmitSound("Rock.ImpactSoft")
				self.Entity:EmitSound("Rock.ImpactHard")
			end
		end
	end

	function ENT:ProduceResource()
		local SelfPos, Forward, Up, Right, OreType = self:GetPos(), self:GetForward(), self:GetUp(), self:GetRight(), self:GetOreType()
		local amt = math.Clamp(math.floor(self:GetProgress()), 0, 100)

		local spawnVec = self:WorldToLocal(SelfPos + Forward * 36 + Up * 5)
		local spawnAng = self:GetAngles()
		local ejectVec = Up * 50

		if amt > 0 or OreType ~= "generic" then
			local RefinedType = JMod.SmeltingTable[OreType][1]
			timer.Simple(0.3, function()
				if IsValid(self) then
					JMod.MachineSpawnResource(self, RefinedType, amt, spawnVec, spawnAng, ejectVec, 200)
					if (OreType == JMod.EZ_RESOURCE_TYPES.SAND) and (amt >= 25) and math.random(0, 200) then
						JMod.MachineSpawnResource(self, JMod.EZ_RESOURCE_TYPES.DIAMOND, 1, spawnVec + Up * 4, spawnAng, ejectVec, false)
					end
				end
			end)
			self:SetProgress(0)
			self:EmitSound("snds_jack_gmod/ding.wav", 80, 120)
		end

		local OreLeft = self:GetOre()
		if OreLeft <= 0 then
			self:SetOreType("generic")
		elseif OreType ~= "generic" then
			self:SetOre(0)
			self:SetOreType("generic")
			JMod.MachineSpawnResource(self, OreType, OreLeft, spawnVec + Up * 4 + Right * 20, spawnAng, ejectVec, false)
		end
	end
	function ENT:OnRemove()
		if(self.SoundLoop)then self.SoundLoop:Stop() end
	end

elseif(CLIENT)then
	function ENT:CustomInit()
		--self.Camera=JMod.MakeModel(self,"models/props_combine/combinecamera001.mdl")
		self.MaxOre = 60
		--models/props_interiors/pot02a.mdl
		--models/props_junk/garbage_metalcan002a.mdl
	end

	function ENT:Think()
		local State, Fuel, Pos, Ang = self:GetState(), self:GetElectricity(), self:GetPos(), self:GetAngles()

		if State == STATE_PROCESSING then
			local Up, Right, Forward, Mult = Ang:Up(), Ang:Right(), Ang:Forward(), Fuel*0.005
			local DLight = DynamicLight(self:EntIndex())

			if DLight then
				DLight.Pos = Pos + Up * 10 + Vector(0, 0, 20)
				DLight.r = 255
				DLight.g = 245
				DLight.b = 65
				DLight.Brightness = math.Rand(.5, 1) * Mult
				DLight.Size = math.random(1300, 1500) * Mult * 0.5
				DLight.DieTime = CurTime() + .3
				DLight.Style = 0
			end
		end
	end

	function ENT:DrawTranslucent()
		local State = self:GetState()
		local SelfPos,SelfAng=self:GetPos(),self:GetAngles()
		local Up,Right,Forward=SelfAng:Up(),SelfAng:Right(),SelfAng:Forward()
		---
		local BasePos = SelfPos + Up*30
		local Obscured = false--util.TraceLine({start=EyePos(),endpos=BasePos,filter={LocalPlayer(),self},mask=MASK_OPAQUE}).Hit
		local Closeness = LocalPlayer():GetFOV()*(EyePos():Distance(SelfPos))
		local DetailDraw = Closeness < 20000 -- cutoff point is 400 units when the fov is 90 degrees
		if((not(DetailDraw))and(Obscured))then return end -- if player is far and sentry is obscured, draw nothing
		if(Obscured)then DetailDraw = false end -- if obscured, at least disable details
		if(self:GetState()<0)then DetailDraw = false end
		---
		self:DrawModel()
		---
		if(DetailDraw)then
			if(self:GetElectricity() > 0) then
				local DisplayAng = SelfAng:GetCopy()
				DisplayAng:RotateAroundAxis(Forward, 90)
				DisplayAng:RotateAroundAxis(Up, 90)
				local Opacity = math.random(50, 200)
				cam.Start3D2D(BasePos - Up * 14 + Right * 0 + Forward * 8, DisplayAng, .04)
				--draw.SimpleTextOutlined("JMOD","JMod-Display",0,0,Color(255,255,255,Opacity),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,3,Color(0,0,0,Opacity))
				local ProFrac = self:GetProgress() / 100
				local OreFrac = self:GetOre() / self.MaxOre
				local ElecFrac = self:GetElectricity() / self.MaxElectricity
				local R, G, B = JMod.GoodBadColor(ProFrac)
				local OR, OG, OB = JMod.GoodBadColor(OreFrac)
				local ER, EG, EB = JMod.GoodBadColor(ElecFrac)
				draw.SimpleTextOutlined("FUEL "..math.Round(ElecFrac * 100).."%","JMod-Display",0,0,Color(ER, EG, EB, Opacity),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,3,Color(0,0,0,Opacity))
				if (State == STATE_PROCESSING) then
					draw.SimpleTextOutlined("PROGRESS", "JMod-Display", 0, 30, Color(255, 255, 255, Opacity), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 3, Color(0, 0, 0, Opacity))
					draw.SimpleTextOutlined(tostring(math.Round(ProFrac * 100)) .. "%", "JMod-Display", 0, 60, Color(R, G, B, Opacity), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 3, Color(0, 0, 0, Opacity))
					draw.SimpleTextOutlined(string.upper(self:GetOreType()), "JMod-Display", 0, 90, Color(228, 215, 101, Opacity), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 3, Color(0, 0, 0, Opacity))
					draw.SimpleTextOutlined("REMAINING", "JMod-Display", 0, 120,Color(228, 215, 101, Opacity), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 3, Color(0, 0, 0, Opacity))
					draw.SimpleTextOutlined(tostring(math.Round(OreFrac * self.MaxOre)), "JMod-Display", 0, 150, Color(OR, OG, OB, Opacity), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 3, Color(0, 0, 0, Opacity))
				end
				cam.End3D2D()
			end
		end
	end
	language.Add("ent_fumo_gmod_ezcampfire","EZ Campfire")
end
