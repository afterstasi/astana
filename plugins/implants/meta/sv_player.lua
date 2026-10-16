
local playerMeta = FindMetaTable("Player")

-- A function to handle a player's implants.
function playerMeta:HandleImplants()
	local visionImplant = self:GetWeapon("ix_visionimplant")
	local thermalImplant = self:GetWeapon("ix_thermalimplant")
	local stealthImplant = self:GetWeapon("ix_stealthimplant")
	local isRagdolled = IsValid(self.ixRagdoll)
	local isAlive = self:Alive()
	local plyVelocity = self:GetVelocity()
	local untilVelAlpha = math.max(0, plyVelocity:Length() - 75)
	local weapon = self:GetActiveWeapon()

	if (IsValid(visionImplant) and visionImplant:IsActivated() and isAlive and !isRagdolled and ((self:HasWeapon("ix_thermalimplant") and !thermalImplant:IsActivated()) or !self:HasWeapon("ix_thermalimplant"))) then
		self:SetNetVar("vision", true)
	else
		self:SetNetVar("vision", false)
	end
	
	if (IsValid(thermalImplant) and thermalImplant:IsActivated() and isAlive and !isRagdolled and ((self:HasWeapon("ix_visionimplant") and !visionImplant:IsActivated()) or !self:HasWeapon("ix_visionimplant"))) then
		self:SetNetVar("thermal", true)
	else
		self:SetNetVar("thermal", false)
	end

	if (IsValid(stealthImplant) and stealthImplant:IsActivated() and isAlive and !isRagdolled and self:HasWeapon("ix_stealthimplant")) then
		self:SetNetVar("stealth", true)
	else
		self:SetNetVar("stealth", false)
	end
	
	if (IsValid(stealthImplant) and stealthImplant:IsActivated() and isAlive and !isRagdolled) then
		if (!self.lastMaterial) then
			self.lastMaterial = self:GetMaterial()
		end
		
		if (!self.lastColor) then
			self.lastColor = {self:GetColor()}
		end
		self:ResetParts()
		if untilVelAlpha >= 70 then 
			self:SetMaterial("models/shadertest/predator")
			self:SetColor(Color(255, 255, 255, 200))
			self:SetDSP(12)
			weapon:SetMaterial("models/shadertest/predator", true)
		else
			self:SetMaterial("sprites/heatwave")
			self:SetColor(Color(255, 255, 255, 0))
			self:SetDSP(14)
			weapon:SetMaterial("sprites/heatwave", true)
		end
		--self:DrawViewModel(false)

	elseif (self.lastMaterial and self.lastColor) then
		--self:DrawViewModel(true)
		self:SetDSP(0)
		self:SetMaterial(self.lastMaterial)
		self:SetColor(unpack(self.lastColor))
		
		self.lastMaterial = nil
		self.lastColor = nil

		local character = self:GetCharacter()
		local inventory = character:GetInventory()

		for _, v in pairs(inventory:GetItems()) do
			if (v:GetData("equip") == true and v.pacData or v.pacDataFemale or v.pacDataMale or v.pacDataBackpack or v.pacDataOTA) then
				if self:IsFemale() and  v.pacDataFemale then
					self:AddPart(v.uniqueID .. "female", v)
				elseif !self:IsFemale() and  v.pacDataMale then
					self:AddPart(v.uniqueID .. "male", v)
				elseif self:IsOTA() and v.pacDataOTA then
					self:AddPart(v.uniqueID .. "OTA", v)
				elseif !self:GetCharacter():HasBackpack() and v.pacDataBackpack and v:GetData("equip") == true then
					self:AddPart(v.uniqueID, v)
				elseif self:GetCharacter():HasBackpack() and v.pacDataBackpack and v:GetData("equip") == true  then
					self:AddPart(v.uniqueID .. "Backpack", v)
				else 
					self:AddPart(v.uniqueID, v)
				end
				--client:AddPart(v.uniqueID, v)
			end
		end
		timer.Simple( 0.5, function() -- FUCK YOU. WHY DO YOU NEED A DELAY! PICE OF SHIT
			local charPanel = self:GetCharacter():GetCharPanel();
			for _, v in pairs(charPanel:GetItems()) do
				if (v.pacData) then
					self:AddPart(v.uniqueID, v)
				end
			end
		end)
	end

	if (IsValid(stealthImplant) and !stealthImplant:IsActivated() and isAlive and !isRagdolled) then
		if (!self.lastMaterial) then
			self.lastMaterial = self:GetMaterial()
		end
		if self:GetActiveWeapon():GetMaterial() == "sprites/heatwave" then
			self:GetActiveWeapon():SetMaterial(self:GetActiveWeapon().lastMaterial, true)
		end
	end
end

