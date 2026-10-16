
local PLUGIN = PLUGIN

PLUGIN.name = "Simple Inventory Slots"
PLUGIN.author = "Fruity"
PLUGIN.description = "Adds a simple inventory slots system for Helix with a clothing base to go with it. Get it on gmodstore."

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
ix.util.Include("cl_net.lua")
ix.util.Include("sv_net.lua")

PLUGIN.slots = {
	Head = {location = LEFT, pos = 1},
	Eyes = {location = LEFT, pos = 2},
	Face = {location = LEFT, pos = 3},
	Torso = {location = LEFT, pos = 4},
	Hands = {location = RIGHT, pos = 1},
	Legs = {location = RIGHT, pos = 2},
	Shoes = {location = RIGHT, pos = 3},
	Outfit = {location = RIGHT, pos = 4}
}

do
	for name, _ in pairs(PLUGIN.slots) do
		ix.inventory.Register(name, 1, 1, true)

		ix.char.RegisterVar(name, {
			field = name,
			fieldType = ix.type.number,
			default = 0,
			bNoDisplay = true,
			bNoNetworking = true,
			OnGet = function(character)
				local index = false
				for key, v in pairs(character.vars.inv) do
					if !v.vars.isBag then continue end
					if v.vars.isBag != name then continue end
					index = key
					break
				end

				if !index then
					error("Could not find inventory index of character ID "..character:GetID().."'s equip slot: "..name)
					return
				end

				return character.vars.inv and character.vars.inv[index]
			end,
		})
	end
end

function PLUGIN:IsEquipSlot(inventory)
	if !inventory then return false end
	if !inventory.vars then return false end
	if !inventory.vars.isBag then return false end
	if !self.slots[inventory.vars.isBag] then return false end -- isBag is always the name of the slot
	if inventory.storageInfo then return false end -- we're a storage

	return true
end

function PLUGIN:Notify(client, languageString)
	if client and IsValid(client) then
		client:NotifyLocalized(languageString or "")
	end
end

function PLUGIN:CanPlayerDropItem(client, item)
	local itemInstance = ix.item.instances[item]
	if !itemInstance then return end

	local oldInv = itemInstance.invID and ix.item.inventories[itemInstance.invID]
	if !oldInv then return end

	local worldInv = ix.item.inventories[0]

	return self:CanTransferItem(itemInstance, oldInv, worldInv)
end

function PLUGIN:CanTransferItem(item, oldInv, newInv)
	local oldChar = oldInv.owner and ix.char.loaded[oldInv.owner] -- The char trying to move the item
	if !oldChar then
		if oldInv.vars and oldInv.vars.isContainer then
			if newInv.owner and ix.char.loaded[newInv.owner] then
				oldChar = ix.char.loaded[newInv.owner]
			end
		else
			return
		end
	end

	local oldPlayer = oldChar.GetPlayer and oldChar:GetPlayer() -- The client trying to move the item

	if !self:IsEquipSlot(newInv) then -- We're trying to move an item out of the equipment slots
		-- Check for outfit being worn
		if self:IsEquipSlot(oldInv) then
			local outfitInv = oldChar.GetOutfit and oldChar:GetOutfit()
			if !outfitInv then return end

			if outfitInv.GetItems and #table.GetKeys(outfitInv:GetItems()) <= 0 then return end -- Outfit is empty so it's fine
			if item.slot and item.slot == "Outfit" then return end -- We're taking the outfit off so it's fine

			self:Notify(oldPlayer, "slotsWearingOutfit")
			return false
		end

		return
	end

	-- We're trying to move an item into the equipment slots
	if #table.GetKeys(newInv:GetItems()) >= 1 then return false end -- There is already an item in the slots

	-- We're trying to move an item that is not using the equipment base into the equipment slots
	if item.base != "base_slot_clothing" then
		self:Notify(oldPlayer, "slotsDoesNotFit")
		return false
	end

	-- We're trying to equip an item that is using the equipment base but it's missing a slot type
	if !item.slot then
		self:Notify(oldPlayer, "slotsMissingType")
		return false
	end

	-- We're trying to equip an item that is using the equipment base but it is not the right slot
	if item.slot != newInv.vars.isBag then
		self:Notify(oldPlayer, "slotsFitbutnoFit")
		return false
	end

	-- Check the new inventory's owner's outfit slot for an outfit before allowing transfer
	local character = newInv.owner and ix.char.loaded[newInv.owner]
	if !character then return end

	local outfitInv = character.GetOutfit and character:GetOutfit()
	if !outfitInv then return end

	if outfitInv.GetItems and #table.GetKeys(outfitInv:GetItems()) > 0 then
		self:Notify(oldPlayer, "slotsWearingOutfit2")
		return false
	end

	-- Also check the old inventory's owner's outfit slot
	local outfitInv2 = oldChar.GetOutfit and oldChar:GetOutfit()
	if !outfitInv2 then return end

	if outfitInv2.GetItems and #table.GetKeys(outfitInv2:GetItems()) > 0 then
		if !item:GetData("equip") then return end
		if item.slot and item.slot == "Outfit" then return end -- we're taking off the outfit
		self:Notify(oldPlayer, "slotsSearchedPersonOutfit")
		return false
	end

	return true
end