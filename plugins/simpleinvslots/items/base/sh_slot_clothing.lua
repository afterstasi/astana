
local PLUGIN = PLUGIN

ITEM.base = "base_outfit"
ITEM.name = "Slot Clothing"
ITEM.description = "A suitcase full of clothes."
ITEM.model = Model("models/props_c17/suitcase_passenger_physics.mdl")
ITEM.category = "Slot Clothing"
ITEM.width = 1
ITEM.height = 1
ITEM.maxArmor = 0
ITEM.slot = "Head"

--[[
-- Slot types:
Head, Eyes, Face, Torso, Hands, Legs, Shoes, Outfit
-- This will change a player's skin after changing the model. Keep in mind it starts at 0.
ITEM.newSkin = 1
-- This will change a certain part of the model.
ITEM.replacements = {"group01", "group02"}
-- This will change the player's model completely.
ITEM.replacements = "models/manhack.mdl"
-- This will have multiple replacements.
ITEM.replacements = {
	{"male", "female"},
	{"group01", "group02"}
}

-- This will apply body groups.
ITEM.bodyGroups = {
	["blade"] = 1,
	["bladeblur"] = 1
}
]]--

if (CLIENT) then
	function ITEM:PopulateTooltip(tooltip)
		if self.maxArmor and self.maxArmor > 0 then
			local panel = tooltip:AddRowAfter("name", "armor")
			panel:SetBackgroundColor(derma.GetColor("Warning", tooltip))
			panel:SetText("Armor: " .. (self:GetData("equip") and LocalPlayer():Armor() or self:GetData("armor", self.maxArmor)))
			panel:SizeToContents()
		end

		local panel = tooltip:AddRowAfter("armor", "slot")
		panel:SetBackgroundColor(Color(200, 200, 200, 255))
		panel:SetText("Slot: " .. self.slot)
		panel:SizeToContents()
	end
end

function ITEM:OnEquipped()
	self.player:SetArmor(self:GetData("armor", self.maxArmor))
end

function ITEM:OnUnequipped()
	self:SetData("armor", math.Clamp(self.player:Armor(), 0, self.maxArmor))
	self.player:SetArmor(0)
end

function ITEM:Repair(amount)
	self:SetData("armor", math.Clamp(self:GetData("armor") + amount, 0, self.maxArmor))
end

function ITEM:OnLoadout()
	if (self:GetData("equip")) then
		self.player:SetArmor(self:GetData("armor", self.maxArmor))
	end
end

function ITEM:OnSave()
	if (self:GetData("equip")) then
		self:SetData("armor", math.Clamp(self.player:Armor(), 0, self.maxArmor))
	end
end

function ITEM:AddOutfit(client)
	local character = client:GetCharacter()

	self:SetData("equip", true)

	if (isfunction(self.OnGetReplacement)) then
		character:SetData("oldModel" .. self.outfitCategory,
			character:GetData("oldModel" .. self.outfitCategory, self.player:GetModel()))
		character:SetModel(self:OnGetReplacement())
	elseif (self.replacement or self.replacements) then
		character:SetData("oldModel" .. self.outfitCategory,
			character:GetData("oldModel" .. self.outfitCategory, self.player:GetModel()))

		if (istable(self.replacements)) then
			if (#self.replacements == 2 and isstring(self.replacements[1])) then
				character:SetModel(self.player:GetModel():gsub(self.replacements[1], self.replacements[2]))
			else
				for _, v in ipairs(self.replacements) do
					character:SetModel(self.player:GetModel():gsub(v[1], v[2]))
				end
			end
		else
			character:SetModel(self.replacement or self.replacements)
		end
	end

	local groups = character:GetData("groups", {})

	if (self.bodyGroups) then
		for k, value in pairs(self.bodyGroups) do
			local index = client:FindBodygroupByName(k)

			if (index > -1) then
				groups[index] = value
				character:SetData("groups", groups)
				client:SetBodygroup(index, value)
			end
		end
	end

	if (self.newSkin) then
		character:SetData("oldSkin" .. self.outfitCategory, self.player:GetSkin())
		self.player:SetSkin(self.newSkin)
	end

	self:OnEquipped()
end

function ITEM:RemoveOutfit(client)
	if !client then return end

	local character = client:GetCharacter()

	self:SetData("equip", false)

	-- restore the original player model
	if (character:GetData("oldModel" .. self.outfitCategory)) then
		character:SetModel(character:GetData("oldModel" .. self.outfitCategory))
		character:SetData("oldModel" .. self.outfitCategory, nil)
	end

	local groups = character:GetData("groups", {})

	if self.bodyGroups then
		for k in pairs(self.bodyGroups) do
			local index = client:FindBodygroupByName(k)

			if (index > -1) then
				groups[index] = 0
				character:SetData("groups", groups)
				client:SetBodygroup(index, 0)
			end
		end
	end

	-- restore the original player model skin
	if (self.newSkin) then
		if (character:GetData("oldSkin" .. self.outfitCategory)) then
			client:SetSkin(character:GetData("oldSkin" .. self.outfitCategory))
			character:SetData("oldSkin" .. self.outfitCategory, nil)
		else
			client:SetSkin(0)
		end
	end

	self:OnUnequipped()
end

function ITEM:CanTransfer(oldInventory, newInventory)
	if oldInventory and oldInventory.vars and oldInventory.vars.isBag then
		if PLUGIN.slots[oldInventory.vars.isBag] then
			return true
		end
	end

	if (newInventory and self:GetData("equip")) then
		return false
	end

	return true
end

if !ITEM.functions.EquipUn then ITEM.functions.EquipUn = {} end
if !ITEM.functions.Equip then ITEM.functions.Equip = {} end

ITEM.functions.EquipUn.OnCanRun = function()
	return false
end

ITEM.functions.Equip.OnCanRun = function()
	return false
end
