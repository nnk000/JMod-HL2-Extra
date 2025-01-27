-- Jackarunda 2021 but stolen by Fumo 2024
AddCSLuaFile()
ENT.Base = "ent_jack_gmod_ezmachine_base"
ENT.Type = "anim"
ENT.PrintName = "EZ Induction Furnace"
ENT.Author = "Fumo"
ENT.Category = "JMod - EZ HL:2 Extra"
ENT.Information = "Smelts stuff, need A LOT of power"
ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.Model = "models/jmod/ez_induction_furnace.mdl"
ENT.Mass = 110
ENT.JModPreferredCarryAngles = Angle(0, 0, 0)
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
ENT.EZconsumes = {
	JMod.EZ_RESOURCE_TYPES.BASICPARTS,
	JMod.EZ_RESOURCE_TYPES.POWER,
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
ENT.FlexFuels = {JMod.EZ_RESOURCE_TYPES.POWER}
ENT.EZcolorable = false
---
ENT.StaticPerfSpecs={
	MaxDurability = 90,
	MaxElectricity = 250,
	MaxOre = 150,
	Armor = 3
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
		if not(self.EZowner)then self:SetColor(Color(255, 255, 255)) end
		self:SetProgress(0)
		self:SetOre(0)
		self:SetOreType("generic")
		self.NextEffThink = 0
		self.NextSmeltThink = 0
		self.NextEnvThink = 0
	end


	function ENT:SetupWire()
		if not(istable(WireLib)) then return end
		self.Inputs = WireLib.CreateInputs(self, {"ToggleState [NORMAL]", "OnOff [NORMAL]"}, {"Toggles the machine on or off with an input > 0", "1 turns on, 0 turns off"})
		---
		local WireOutputs = {"State [NORMAL]", "Grade [NORMAL]", "Progress [NORMAL]", "Power [NORMAL]", "Ore [NORMAL]", "OreType [STRING]"}
		local WireOutputDesc = {"The state of the machine \n-1 is broken \n0 is off \n1 is on", "The machine grade", "Machine's progress", "Machine's flex power left", "Amount of ore left", "The type of ore it's processing"}
		for _, typ in ipairs(self.EZconsumes) do
			if typ == JMod.EZ_RESOURCE_TYPES.BASICPARTS then typ = "Durability" end
			local ResourceName = string.Replace(typ, " ", "")
			local ResourceDesc = "Amount of "..ResourceName.." left"
			--
			if not(string.Right(ResourceName, 3) == "ore") and not(ResourceName == "sand") and not(table.HasValue(self.FlexFuels, typ)) then
				local OutResourceName = string.gsub(ResourceName, "^%l", string.upper).." [NORMAL]"
				table.insert(WireOutputs, OutResourceName)
				table.insert(WireOutputDesc, ResourceDesc)
			end
		end
		self.Outputs = WireLib.CreateOutputs(self, WireOutputs, WireOutputDesc)
	end

	function ENT:UpdateWireOutputs()
		if istable(WireLib) then
			WireLib.TriggerOutput(self, "State", self:GetState())
			WireLib.TriggerOutput(self, "Grade", self:GetGrade())
			WireLib.TriggerOutput(self, "Progress", self:GetProgress())
			WireLib.TriggerOutput(self, "Durability", self.Durability)
			WireLib.TriggerOutput(self, "Power", self:GetElectricity())
			WireLib.TriggerOutput(self, "Ore", self:GetOre())
			WireLib.TriggerOutput(self, "OreType", self:GetOreType())
		end
	end

	function ENT:ResourceLoaded(typ, accepted)
		local State = self:GetState()
		if (State == STATE_PROCESSING) then self:SetSkin(1) end
		if typ == self:GetOreType() and accepted >= 1 then
			self:SetBodygroup( 1 , 1 )
		end
	end

	function ENT:Use(activator)
		local Alt = activator and JMod.IsAltUsing(activator)
		local State = self:GetState()
		if(State == STATE_FINE) then
			if (self:GetElectricity() > 0) then
				if Alt then
					self:TurnOn(activator)
				end
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
		if (self:GetOre() > 0) then	self:SetSkin(1) end
		self:EmitSound("plats/train_use1.wav")
		timer.Simple(0.1, function()
			if(self.SoundLoop)then self.SoundLoop:Stop() end
			self.SoundLoop = CreateSound(self, "vehicles/apc/apc_idle1.wav")
			self.SoundLoop:SetSoundLevel(50)
			self.SoundLoop:Play()
		end)
	end

	function ENT:TurnOff(activator)
		if (self:GetState() <= STATE_FINE) then return end
		self:SetState(STATE_FINE)
		self:SetSkin(0)
		self:ProduceResource()
		if(self.SoundLoop)then self.SoundLoop:Stop() end
	end

	function ENT:OnBreak()
		if(self.SoundLoop)then self.SoundLoop:Stop() end
	end

	function ENT:Think()
		local State, Time, OreTyp = self:GetState(), CurTime(), self:GetOreType()
		self:UpdateWireOutputs()
		if (State == STATE_PROCESSING) then
			if (self.NextSmeltThink < Time) then
				self.NextSmeltThink = Time + 1
				if (self:WaterLevel() > 0) then 
					self:TurnOff() 
					self:EmitSound("snds_jack_gmod/hiss.ogg", 120, 90)
					return 
				end
				if not OreTyp then self:TurnOff() return end

				self:ConsumeElectricity(.1)

				if OreTyp and not(self:GetOre() <= 0) then
					local OreConsumeAmt = 1.5
					local MetalProduceAmt = 1 * JMod.SmeltingTable[OreTyp][2]
					self:SetOre(self:GetOre() - OreConsumeAmt)
					self:SetProgress(self:GetProgress() + MetalProduceAmt)
					self:ConsumeElectricity(4)
					if self:GetProgress() >= 100 then
						self:ProduceResource()
					end
				else
					self:ProduceResource()
				end
			end
		end
		self:NextThink(Time + .1)
	end

	function ENT:ProduceResource()
		local SelfPos, Forward, Up, Right, OreType = self:GetPos(), self:GetForward(), self:GetUp(), self:GetRight(), self:GetOreType()
		local amt = math.Clamp(math.floor(self:GetProgress()), 0, 100)

		local spawnVec = self:WorldToLocal(SelfPos + Forward * 16 + Up * 40)
		local spawnAng = self:GetAngles()
		if self:GetOre() < 0 then
			self:SetOre(0)
		end
		local ejectVec = Up * 50
		self:SetBodygroup(1, 0)
		self:SetSkin(0)
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
			self:EmitSound("snds_jack_gmod/ding.ogg", 80, 120)
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
		self.MaxOre = 150
		--models/props_interiors/pot02a.mdl
		--models/props_junk/garbage_metalcan002a.mdl
	end

	function ENT:DrawTranslucent()
		local State = self:GetState()
		local SelfPos,SelfAng=self:GetPos(),self:GetAngles()
		local Up,Right,Forward=SelfAng:Up(),SelfAng:Right(),SelfAng:Forward()
		---
		local BasePos = SelfPos + Up*30
		local Obscured = false--util.TraceLine({start=EyePos(),endpos=BasePos,filter={LocalPlayer(),self},mask=MASK_OPAQUE}).Hit
		local Closeness = LocalPlayer():GetFOV()*(EyePos():Distance(SelfPos))
		local DetailDraw = Closeness < 32000 -- cutoff point is 400 units when the fov is 90 degrees
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
				DisplayAng:RotateAroundAxis(Up, 180)
				local Opacity = math.random(50, 200)
				cam.Start3D2D(BasePos - Up * 17.5 + Right * -18 + Forward * 0, DisplayAng, .06)
				--draw.SimpleTextOutlined("JMOD","JMod-Display",0,0,Color(255,255,255,Opacity),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,3,Color(0,0,0,Opacity))
				local ProFrac = self:GetProgress() / 100
				local OreFrac = self:GetOre() / self.MaxOre
				local ElecFrac = self:GetElectricity() / self.MaxElectricity
				local R, G, B = JMod.GoodBadColor(ProFrac)
				local OR, OG, OB = JMod.GoodBadColor(OreFrac)
				local ER, EG, EB = JMod.GoodBadColor(ElecFrac)
				draw.SimpleTextOutlined("POWER "..math.Round(ElecFrac * 100).."%","JMod-Display",0,0,Color(ER, EG, EB, Opacity),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,3,Color(0,0,0,Opacity))
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
	language.Add("ent_fumo_gmod_ezinductionfurnace","EZ Induction Furnace")
end
