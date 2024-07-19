-- AdventureBoots 2023 but stolen by Fumo 2024
AddCSLuaFile()
ENT.Type = "anim"
ENT.Author = "Fumo"
ENT.Information = "glhfggwpezpznore"
ENT.PrintName = "EZ Projector"
ENT.Category = "JMod - EZ HL:2 Extra"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.JModEZstorable = true
ENT.Base = "ent_jack_gmod_ezmachine_base"
---
ENT.Model = "models/jmod/ez_projector.mdl"
ENT.Mass = 30
ENT.SpawnHeight = 10
ENT.JModPreferredCarryAngles = Angle(0, 180, 0)
ENT.EZupgradable = false
ENT.EZcolorable = false
ENT.StaticPerfSpecs = {
	MaxDurability = 70,
	MaxElectricity = 50
}
ENT.DynamicPerfSpecs = {
	Armor = .3
}
--

local STATE_BROKEN, STATE_OFF, STATE_ON = -1, 0, 1
---

if(SERVER)then
	function ENT:SetupWire()
		if not(istable(WireLib)) then return end
		local WireInputs = {"Toggle [NORMAL]", "On-Off [NORMAL]"}
		local WireInputDesc = {"Greater than 1 toggles machine on and off", "1 turns on, 0 turns off"}
		self.Inputs = WireLib.CreateInputs(self, WireInputs, WireInputDesc)
		--
		local WireOutputs = {"State [NORMAL]"}
		local WireOutputDesc = {"The state of the machine \n-1 is broken \n0 is off \n1 is on"}
		for _, typ in ipairs(self.EZconsumes) do
			if typ == JMod.EZ_RESOURCE_TYPES.BASICPARTS then typ = "Durability" end
			local ResourceName = string.Replace(typ, " ", "")
			local ResourceDesc = "Amount of "..ResourceName.." left"
			--
			local OutResourceName = string.gsub(ResourceName, "^%l", string.upper).." [NORMAL]"
			table.insert(WireOutputs, OutResourceName)
			table.insert(WireOutputDesc, ResourceDesc)
		end
		self.Outputs = WireLib.CreateOutputs(self, WireOutputs, WireOutputDesc)
	end

	function ENT:UpdateWireOutputs()
		if not istable(WireLib) then return end
		WireLib.TriggerOutput(self, "State", self:GetState())
		for _, typ in ipairs(self.EZconsumes) do
			if typ == JMod.EZ_RESOURCE_TYPES.BASICPARTS then
				WireLib.TriggerOutput(self, "Durability", self.Durability)
			else
				local MethodName = JMod.EZ_RESOURCE_TYPE_METHODS[typ]
				if MethodName then
					local ResourceGetMethod = self["Get"..MethodName]
					if ResourceGetMethod then
						local ResourceName = string.Replace(typ, " ", "")
						WireLib.TriggerOutput(self, string.gsub(ResourceName, "^%l", string.upper), ResourceGetMethod(self))
					end
				end
			end
		end
	end

	function ENT:TriggerInput(iname, value)
		local State, Owner = self:GetState(), JMod.GetEZowner(self)
		if State < 0 then return end
		if iname == "On-Off" then
			if value == 1 then
				self:TurnOn(Owner)
			elseif value == 0 then
				self:TurnOff(Owner)
			end
		elseif iname == "Toggle" then
			if value > 0 then
				if State == 0 then
					self:TurnOn(Owner)
				elseif State > 0 then
					self:TurnOff(Owner)
				end
			end
		end
	end

	function ENT:CustomInit()
		self:SetUseType(ONOFF_USE)
		self.StuckStick = nil
		self.StuckTo = nil
		self.NextStick = 0
		self:SetSkin(1)
	end

	function ENT:TurnOn(activator)
		if self:GetState() ~= STATE_OFF then return end

		if (self:GetElectricity() > 0) then
			if IsValid(activator) then self.EZstayOn = true end
			self:SetState(STATE_ON)
			self:SetSkin(0)
		else
			JMod.Hint(activator, "nopower")
		end
	end
	
	function ENT:TurnOff(activator)
		if (self:GetState() <= 0) then return end
		if IsValid(activator) then self.EZstayOn = nil end
		self:SetState(STATE_OFF)
		self:SetSkin(1)
		end
	end

	function ENT:OnBreak()
		self:SetSkin(2)
	end
	
	function ENT:OnRepair()
		self:SetSkin(1)
	end
	function ENT:Use(activator, activatorAgain, onOff)
		local Dude = activator or activatorAgain
		local Time = CurTime()

		if tobool(onOff) then
			local State = self:GetState()
			local Alt = Dude:KeyDown(JMod.Config.General.AltFunctionKey)

			if State == STATE_BROKEN then
				JMod.Hint(Dude, "destroyed", self)

				return
			elseif State == STATE_OFF then
				if Alt then
					self:TurnOn(Dude)
					self:EmitSound("snd_jack_minearm.ogg", 60, 100)
				else
					constraint.RemoveConstraints(self, weld)
					self.StuckStick = nil
					self.StuckTo = nil
					Dude:PickupObject(self)
					self.NextStick = Time + .5
					JMod.Hint(Dude, "sticky")
				end
			elseif State == STATE_ON then
				if Alt then
					self:EmitSound("snd_jack_minearm.ogg", 60, 70)
					self:TurnOff(Dude)
				else
					constraint.RemoveConstraints(self, weld)
					self.StuckStick = nil
					self.StuckTo = nil
					Dude:PickupObject(self)
					self.NextStick = Time + .5
					JMod.Hint(Dude, "sticky")
				end
			end
		else
			if self:IsPlayerHolding() and (self.NextStick < Time) then
				local Tr = util.QuickTrace(Dude:GetShootPos(), Dude:GetAimVector() * 150, {self, Dude})

				if Tr.Hit and IsValid(Tr.Entity:GetPhysicsObject()) and not Tr.Entity:IsNPC() and not Tr.Entity:IsPlayer() then
					self.NextStick = Time + .5
					self:SetPos(Tr.HitPos + Tr.HitNormal * 12)

					-- crash prevention
					if Tr.Entity:GetClass() == "func_breakable" then
						timer.Simple(0, function()
							self:GetPhysicsObject():Sleep()
						end)
					else
						local Weld = constraint.Weld(self, Tr.Entity, 0, Tr.PhysicsBone, 3000, false, false)
						self.StuckTo = Tr.Entity
						self.StuckStick = Weld
					end

					self:EmitSound("snd_jack_claythunk.ogg", 65, math.random(80, 120))
					Dude:DropObject()
					JMod.Hint(Dude, "arm")
				end
			end
		end
	end
	

	function ENT:Think()
		local State, Time = self:GetState(), CurTime()
		--local SelfPos, Up, Right, Forward = self:GetPos(), self:GetUp(), self:GetRight(), self:GetForward()

		self:UpdateWireOutputs()
		if State == STATE_ON then
			self:ConsumeElectricity(0.05)
		end

		self:NextThink(Time + 1)
		return true
	end


	function ENT:OnRemove()
		if self.ElectricalCallbacks then
			for k, v in pairs(self.ElectricalCallbacks) do
				if (IsValid(Entity(k))) then
					Entity(k):RemoveCallback("PhysicsCollide", v)
				end
			end
		end
	end

	function ENT:PostEntityPaste(ply, ent, createdEntities)
		local Time = CurTime()
		JMod.SetEZowner(self, ply, true)
		ent.NextRefillTime = Time + math.Rand(0, 3)
		ent.NextResourceThinkTime = 0
		ent.NextStick = 0
	end

if(CLIENT)then

	function ENT:CustomInit()
		self.MaxElectricity = 100
		self.PixVis = util.GetPixelVisibleHandle()
		self:CreateLightProjection()
	end
	
	function ENT:CreateLightProjection()
		local ProjectyLight = ProjectedTexture() -- Create a projected texture
		self.ProjectyLight = ProjectyLight -- Assign it to the entity table so it may be accessed later
	
		-- Set it all up
		ProjectyLight:SetTexture( "effects/flashlight001" )
		ProjectyLight:SetFarZ( 1024 ) -- How far the light should shine
		ProjectyLight:SetBrightness( 1 )
		ProjectyLight:SetFOV( 100 )
		ProjectyLight:SetPos( self:GetPos() - Vector(0, 0, 64) ) -- Initial position and angles
		ProjectyLight:SetAngles( self:GetAngles() )
		ProjectyLight:Update()

	end
	
	function ENT:UpdateLightProjection()
		if IsValid(self.ProjectyLight) then
			self.ProjectyLight:SetPos(self:GetPos() + self:GetForward() * 7.5)
			self.ProjectyLight:SetAngles( self:GetAngles() )
			self.ProjectyLight:Update()
		else
			self:CreateLightProjection()
		end
	end
	
    function ENT:OnRemove()
        if (IsValid(self.ProjectyLight)) then
            self.ProjectyLight:Remove()
        end
    end
	
	function ENT:Think()
		local State, FT = self:GetState(), FrameTime()
		if State == STATE_ON then
			self:UpdateLightProjection()
		else
			if ( IsValid( self.ProjectyLight ) ) then
				self.ProjectyLight:Remove()
			end
		end
	end

	local GlowSprite = Material("sprites/mat_jack_basicglow")
	ENT.WantsTranslucency = true
	function ENT:DrawTranslucent()
		local Up, Right, Forward, State = self:GetUp(), self:GetRight(), self:GetForward(), self:GetState()
		local SelfPos, SelfAng = self:GetPos(), self:GetAngles()
		--
		local Obscured = util.TraceLine({start = EyePos(), endpos = SelfPos, filter = {LocalPlayer(), self}, mask = MASK_OPAQUE}).Hit
		local Closeness = LocalPlayer():GetFOV() * (EyePos():Distance(SelfPos))
		local DetailDraw = Closeness < 36000 -- cutoff point is 400 units when the fov is 90 degrees
		if State == STATE_BROKEN then DetailDraw = false end -- look incomplete to indicate damage, save on gpu comp too
		--if Obscured then DetailDraw = false end -- if obscured, at least disable details
		--
		self:DrawModel()
		--
		if DetailDraw then
			if State >= STATE_ON then
				local Opacity = math.random(50, 150)
				local DisplayAng = SelfAng:GetCopy()
				DisplayAng:RotateAroundAxis(DisplayAng:Up(), 180)
				DisplayAng:RotateAroundAxis(DisplayAng:Forward(), 90)

				cam.Start3D2D(SelfPos + Forward * 0 + Right * -11, DisplayAng, .1)
					draw.SimpleTextOutlined("POWER", "JMod-Display",0,-30,Color(255,255,255,Opacity),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,3,Color(0,0,0,Opacity))
					local ElecFrac=self:GetElectricity()/self.MaxElectricity
					local R,G,B = JMod.GoodBadColor(ElecFrac)
					draw.SimpleTextOutlined(tostring(math.Round(ElecFrac*100)).."%","JMod-Display",0,0,Color(R,G,B,Opacity),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,3,Color(0,0,0,Opacity))
				cam.End3D2D()
			end
		end
		if State == STATE_ON then
			render.SetMaterial(GlowSprite)
			local SpritePos = SelfPos + Forward * 0 + Up * 12.5 + Right * -2
			local Vec = (SpritePos - EyePos()):GetNormalized()
			render.DrawSprite(SpritePos - Vec * 5, 5, 5, Color(0, 255, 0))
			local SelfCol = self:GetColor()
			local MatLight = Material( "sprites/light_ignorez" )
			local LightNrm = self:GetForward()
            local LightPos = self:GetPos() + LightNrm * 8
            local ViewNormal = self:GetPos() - EyePos()
            local Dist = ViewNormal:Length()
            ViewNormal:Normalize()
            local ViewDot = ViewNormal:Dot( LightNrm * -1 )

            if ( ViewDot >= 0 ) then

                render.SetMaterial( MatLight )
                local Visibile = util.PixelVisible( LightPos, 8, self.PixVis )

                if ( !Visibile ) then return end

                local Size = math.Clamp( Dist * Visibile * ViewDot * 1, 64, 512 )

                Dist = math.Clamp( Dist, 32, 800 )
                local Alpha = math.Clamp( ( 1000 - Dist ) * Visibile * ViewDot, 0, 100 )
                local Col = self:GetColor()
                Col.a = Alpha

                render.DrawSprite( LightPos, Size, Size, Col )
                render.DrawSprite( LightPos, Size * 0.4, Size * 0.4, Color( 255, 255, 255, Alpha ) )
            end
				if ( ViewDot < 0.999 ) and ( ViewDot > -0.999 ) then
				local MatBeam = Material( "effects/lamp_beam" )
				render.SetMaterial( MatBeam )

				local BeamDot = .5
				local c = SelfCol

				render.StartBeam( 3 )
				render.AddBeam( LightPos - LightNrm * 5, 90, 0.0, Color( c.r, c.g, c.b, 255 * BeamDot) )
				render.AddBeam( LightPos + LightNrm * 100, 90, 0.5, Color( c.r, c.g, c.b, 64 * BeamDot) )
				render.AddBeam( LightPos + LightNrm * 200, 128, 1, Color( c.r, c.g, c.b, 0) )
				render.EndBeam()
			end
		else
			render.SetMaterial(GlowSprite)
			local SpritePos = SelfPos + Forward * 0 + Up * 12.5 + Right * 2
			local Vec = (SpritePos - EyePos()):GetNormalized()
			render.DrawSprite(SpritePos - Vec * 5, 5, 5, Color(255, 0, 0))
		end
	end
	language.Add("ent_fumo_gmod_ezprojector","EZ Projector")
end