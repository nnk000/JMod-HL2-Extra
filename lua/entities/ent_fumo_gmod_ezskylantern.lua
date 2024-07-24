---RGB 255 200 70 
-- Jackarunda 2021 and Fumo 2024
AddCSLuaFile()
ENT.Type = "anim"
ENT.Author = "Fumo"
ENT.Category = "JMod - EZ HL:2 Extra"
ENT.Information = "Power grid destroyer 3000"
ENT.PrintName = "EZ Sky Lantern"
ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.JModGUIcolorable = true
---
ENT.JModEZstorable = true
ENT.JModPreferredCarryAngles = Angle(0, 0, 0)
---
local STATE_OFF, STATE_BURNIN, STATE_BURNT = 0, 1, 2

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "State")
	self:NetworkVar("Int", 1, "Fuel")
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

		return ent
	end

	function ENT:Initialize()
		self.Entity:SetModel("models/jmod/ez_skylantern.mdl")
		self.Entity:PhysicsInit(SOLID_VPHYSICS)
		self.Entity:SetMoveType(MOVETYPE_VPHYSICS)
		self.Entity:SetSolid(SOLID_VPHYSICS)
		self.Entity:DrawShadow(true)
		self.Entity:SetUseType(SIMPLE_USE)
		self.Entity:SetColor(Color(255, 200, 70))
		local phys = self.Entity:GetPhysicsObject()
		if phys:IsValid()then
			phys:Wake()
			phys:EnableGravity( true )
		end
		self:SetState(STATE_OFF)
		self:SetFuel(math.random(750, 1000))

		if istable(WireLib) then
			self.Inputs = WireLib.CreateInputs(self, {"Light"}, {"Ignites fuel in lantern"})
		end
	end

	function ENT:TriggerInput(iname, value)
		if iname == "Light" and value > 0 then
			self:Light()
		end
	end

	function ENT:PhysicsCollide(data, physobj)
		if data.DeltaTime > 0.2 then
			if data.Speed > 25 then
				self.Entity:EmitSound("physics/cardboard/cardboard_box_impact_soft2.wav")
			end
		end
	end

	function ENT:OnTakeDamage(dmginfo)
		self.Entity:TakePhysicsDamage(dmginfo)

		if JMod.LinCh(dmginfo:GetDamage(), 1, 50) then
			local Pos, State = self:GetPos(), self:GetState()

			if dmginfo:IsDamageType(DMG_BURN) then
				self:Light()
			else
				sound.Play("physics/cardboard/cardboard_box_break1.wav", Pos)
				self:Remove()
			end
		end
	end

	function ENT:Use(activator)
		local State = self:GetState()
		if State == STATE_BURNT then return end
		local Alt = activator:KeyDown(JMod.Config.General.AltFunctionKey)

		if State == STATE_OFF then
			if Alt then
				JMod.SetEZowner(self, activator)
				net.Start("JMod_ColorAndArm")
				net.WriteEntity(self)
				net.Send(activator)
			else
				activator:PickupObject(self)
				JMod.Hint(activator, "arm")
			end
		elseif State == STATE_BURNIN then
			activator:PickupObject(self)
		end
	end

	function ENT:Light()
		if self:GetState() == STATE_BURNT then return end
		self:SetState(STATE_BURNIN)
		self:EmitSound("snd_jack_littleignite.ogg", 50)
		self:SetSkin(1)
		self:StartMotionController()
		local phys = self.Entity:GetPhysicsObject()
		phys:Wake()
		phys:EnableGravity( false )
	end

	ENT.Arm = ENT.Light -- for compatibility with the ColorAndArm feature

	function ENT:Burnout()
		if self:GetState() == STATE_BURNT then return end
		self:SetState(STATE_BURNT)
		self:SetSkin(0)
		self:StopMotionController()
		local phys = self.Entity:GetPhysicsObject()
		phys:EnableGravity( true )
		SafeRemoveEntityDelayed(self, 5)
	end

	function ENT:Think()
		if self:GetState() == STATE_BURNT then return end
		local State, Fuel, Time, Pos = self:GetState(), self:GetFuel(), CurTime(), self:GetPos()
		local Up, Right, Forward = self:GetUp(), self:GetRight(), self:GetForward()
		if State == STATE_BURNIN then
			JMod.AeroDrag(self, self:GetUp() - Vector(0, 0, 1), 5, 1)
			for k, v in pairs(ents.FindInSphere(Pos, 30)) do
				if v.JModHighlyFlammableFunc then
					JMod.SetEZowner(v, self.EZowner)
					local Func = v[v.JModHighlyFlammableFunc]
					Func(v)
				end
			end

			if Fuel <= 0 then
				self:Burnout()

				return
			end

			self:SetFuel(Fuel - 1)
			self:NextThink(Time + .1)

			return true
		end
	end

	function ENT:PhysicsSimulate( phys, deltatime )
		local WindFactor = JMod.Wind * math.random(1, 25)
		local vLinear = WindFactor +  Vector(0, 0, math.random(5, 150)) * deltatime
		local vAngular = vector_origin

		return vAngular, vLinear, SIM_GLOBAL_FORCE

	end

elseif CLIENT then

	function ENT:Think()
		local State, Fuel, Pos, Ang = self:GetState(), self:GetFuel(), self:GetPos(), self:GetAngles()

		if State == STATE_BURNIN then
			local Up, Right, Forward, Col = Ang:Up(), Ang:Right(), Ang:Forward(), self:GetColor()
			local R, G, B = math.Clamp(Col.r + 20, 0, 255), math.Clamp(Col.g + 20, 0, 255), math.Clamp(Col.b + 20, 0, 255)
			local DLight = DynamicLight(self:EntIndex())

			if DLight then
				DLight.Pos = Pos + Up * 3 + Vector(0, 0, 0)
				DLight.r = R
				DLight.g = G
				DLight.b = B
				DLight.Brightness = math.Rand(.5, 1) * 1
				DLight.Size = math.random(50, 100) * 1
				DLight.Decay = 15000
				DLight.DieTime = CurTime() + .3
				DLight.Style = 0
			end
		end
	end

	local GlowSprite = Material("sprites/mat_jack_basicglow")

	function ENT:Draw()
		self:DrawModel()
		local State, Fuel, Pos, Ang = self:GetState(), self:GetFuel(), self:GetPos(), self:GetAngles()
		local Up, Right, Forward, Col = Ang:Up(), Ang:Right(), Ang:Forward(), self:GetColor()
		local R, G, B = math.Clamp(Col.r + 20, 0, 255), math.Clamp(Col.g + 20, 0, 255), math.Clamp(Col.b + 20, 0, 255)

		if State == STATE_BURNIN then
			render.SetMaterial(GlowSprite)
			local EyeVec = EyePos() - Pos
			local EyeDir, Dist = EyeVec:GetNormalized(), EyeVec:Length()
			local DistFrac = math.Clamp(Dist, 0, 400) / 400

			for i = 1, 3 do
				render.DrawSprite(Pos + Up * (.5 + i) * 1 + VectorRand(), 20 * 1 - i, 20 * 1 - i, Color(R, G, B, math.random(100, 200)))
				render.DrawSprite(Pos + Up * (.5 + i) * 1 + VectorRand(), 10 * 1 - i, 10 * 1 - i, Color(255, 255, 255, math.random(100, 200)))
			end
		elseif State == STATE_OFF then
			local CapAng = Ang:GetCopy()
			CapAng:RotateAroundAxis(Right, 180)
			JMod.RenderModel(self.Cap, Pos - Up * 1, CapAng, nil, Vector(.85, 1, .8), nil, true)
		end
	end

	language.Add("ent_fumo_gmod_ezskylantern", "EZ Sky Lantern")
end
