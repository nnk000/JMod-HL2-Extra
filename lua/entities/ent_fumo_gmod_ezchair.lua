AddCSLuaFile()
ENT.Type = "anim"
ENT.PrintName = "Chair"
ENT.Author = "Basipek, AdventureBoots, Fumo"
ENT.Category = "JMod - EZ HL:2 Extra"
ENT.Spawnable = true
ENT.Mass = 15
ENT.JModEZstorable = true
ENT.JModPreferredCarryAngles = Angle(45, 180, 0)
local STATE_FOLDED, STATE_UNFOLDED = 0, 1
local MODEL_FOLDED, MODEL_UNFOLDED = "models/jmod/ezchair_folded.mdl","models/jmod/ezchair.mdl"

if (CLIENT) then
	function ENT:Draw()
		self.Entity:DrawModel()
	end
elseif (SERVER) then

	function ENT:Initialize()
		self.State = STATE_FOLDED
		self.Entity:SetModel(MODEL_FOLDED)
		self.Entity:PhysicsInit(SOLID_VPHYSICS)
		self.Entity:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid( SOLID_VPHYSICS )
		local phys = self.Entity:GetPhysicsObject()
		if phys:IsValid()then
			phys:Wake()
			phys:SetMass(15)
		end
		
		self:SetUseType(SIMPLE_USE)
		
		--self:CreatePod()
	end

	function ENT:CreatePod()
		if(IsValid(self.Pod))then
            self.Pod:SetParent(nil)
            self.Pod:Fire("kill")
            self.Pod = nil
        end
		self.Pod = ents.Create("prop_vehicle_prisoner_pod")
		self.Pod:SetModel("models/nova/airboat_seat.mdl")
		local Ang, Up, Right, Forward = self:GetAngles(), self:GetUp(), self:GetRight(), self:GetForward()
		self.Pod:SetPos(self:GetPos()+Up*-1-Right*0+Forward*0)
		Ang:RotateAroundAxis(Up, -90)
		--Ang:RotateAroundAxis(Forward, 0)
		Ang:RotateAroundAxis(Right, 0)
		self.Pod:SetAngles(Ang)
		self.Pod:Spawn()
		self.Pod:Activate()
		self.Pod:SetParent(self)
		self.Pod:SetNoDraw(true)
		self.Pod:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
		self.Pod:Fire("lock")
		--self.Pod.IsJackyPod = true
		--self.Pod.EZvehicleEjectPos = 
		--self.Pod:SetNotSolid(true)
		--self.Pod:Fire("lock", "", 0)
		--self.Pod:SetThirdPersonMode(false)
		--self.Pod:SetCameraDistance(0)
	end
	
	function ENT:PhysicsCollide(data, physobj)
		if data.DeltaTime > 0.2 then
			if data.Speed > 100 then
				self.Entity:EmitSound("SolidMetal.ImpactSoft")
			end
		end
	end


	function ENT:Fold()
		self.State = STATE_FOLDED
		--JMod.SetEZowner(self, nil)
		if(IsValid(self.Pod))then
            self.Pod:SetParent(nil)
            self.Pod:Fire("kill")
            self.Pod = nil
        end

		self:SetModel(MODEL_FOLDED)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)    
		self:SetSolid(SOLID_VPHYSICS)
		self:DrawShadow(true)
		self:SetUseType(SIMPLE_USE)

		sound.Play("snds_jack_gmod/beartrap_set.ogg", self:GetPos(), 65, math.random(90, 110))
		
		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:Wake()
			phys:SetMass(self.Mass)
		end
		self:SetPos(self:GetPos() + Vector(0, 0, 0))
	end

	function ENT:UnFold()
		self.State = STATE_UNFOLDED
		self:SetModel(MODEL_UNFOLDED)
		
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)    
		self:SetSolid(SOLID_VPHYSICS)
		self:DrawShadow(true)
		self:SetUseType(SIMPLE_USE)
		
		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:Wake()
			phys:SetMass(self.Mass)
		end
		local SelfPos = self:LocalToWorld(self:OBBCenter())
		local Tr = util.TraceLine({
			start = SelfPos + Vector(0, 0, 50),
			endpos = SelfPos - Vector(0, 0, 100),
		})
		if (Tr.Hit) then
			self:SetPos(Tr.HitPos + Tr.HitNormal)
		end
		sound.Play("snds_jack_gmod/beartrap_set.ogg", self:GetPos(), 65, math.random(90, 110))
		self:CreatePod()
		local UpTrace = util.QuickTrace(self:GetPos(), Vector(0, 0, 16), self)
		self:SetPos(UpTrace.HitPos)
	end

	function ENT:Use(ply)
		if not (ply:IsPlayer()) then return end
		local Alt = ply:KeyDown(JMod.Config.General.AltFunctionKey)
		if not IsValid(self.Pod) then self:CreatePod() end
		if (Alt) then
			if (self.State == STATE_UNFOLDED) then
				self:Fold()
			elseif (self.State == STATE_FOLDED) then
				self:UnFold()
			end
		else
			if (self.State == STATE_UNFOLDED) then
				if not IsValid(self.Pod:GetDriver()) then -- Get inside if already yours
					self.Pod.EZvehicleEjectPos = self.Pod:WorldToLocal(ply:GetPos())
					self.Pod:Fire("EnterVehicle", "nil", 0, ply, ply)
				end
			elseif (self.State == STATE_FOLDED) then
				ply:PickupObject(self)
			end
		end
	end

	function ENT:OnRemove()
		if(self.Pod)then -- machines with seats
		  if(IsValid(self.Pod) and IsValid(self.Pod:GetDriver()))then
				self.Pod:GetDriver():ExitVehicle()
				self.Pod:Remove()
			end
		end
	end
end