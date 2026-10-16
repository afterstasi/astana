AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:DrawShadow(true)
end

--------------------------------------------------------------------
-- self.ixUniqueID / self.ixItemData are kept SERVER ONLY -- they hold
-- everything needed to recreate the real item later (on purchase or
-- on return-to-owner). Only display info gets networked to clients.
--------------------------------------------------------------------
function ENT:SetItemInfo(uniqueID, data, name, price, sellerName, sellerSteamID64)
    self.ixUniqueID = uniqueID
    self.ixItemData = data or {}

    self:SetNWString("ixItemName", name or "Item")
    self:SetNWInt("ixPrice", price or 0)
    self:SetNWString("ixSellerName", sellerName or "Someone")
    self:SetNWString("ixSellerSteamID", sellerSteamID64 or "")
end

function ENT:GetItemName() return self:GetNWString("ixItemName", "Item") end
function ENT:GetPrice() return self:GetNWInt("ixPrice", 0) end
function ENT:GetSellerCharName() return self:GetNWString("ixSellerName", "Someone") end
function ENT:GetSellerSteamID() return self:GetNWString("ixSellerSteamID", "") end

--------------------------------------------------------------------
-- Called when a player presses E on this stand.
-- Owner -> picks the item back up.
-- Anyone else -> gets a buy confirmation prompt (throttled to avoid spam).
--------------------------------------------------------------------
function ENT:Interact(client)
    if (self.ixSold) then return end

    if (client:SteamID64() == self:GetSellerSteamID()) then
        self:ReturnToOwner(client, true)
        return
    end

    self.ixLastPrompt = self.ixLastPrompt or {}
    local steamID = client:SteamID64()

    if (self.ixLastPrompt[steamID] and CurTime() < self.ixLastPrompt[steamID]) then return end
    self.ixLastPrompt[steamID] = CurTime() + 1

    net.Start("ixSellItem.PromptBuy")
        net.WriteEntity(self)
        net.WriteString(self:GetItemName())
        net.WriteString(self:GetSellerCharName())
        net.WriteUInt(self:GetPrice(), 32)
    net.Send(client)
end

--------------------------------------------------------------------
-- Finalizes a purchase: charges the buyer, pays the seller (if still
-- online), gives the buyer the item, and removes the stand.
--------------------------------------------------------------------
function ENT:CompleteSale(client)
    if (self.ixSold) then return end
    if (client:SteamID64() == self:GetSellerSteamID()) then return end -- can't buy your own listing

    local buyerChar = client:GetCharacter()
    if (!buyerChar) then return end

    local price = self:GetPrice()

    if (buyerChar:GetMoney() < price) then
        client:NotifyLocalized("sellItemNotEnoughMoney")
        return
    end

    self.ixSold = true -- lock immediately to prevent a double-buy race

    local seller = player.GetBySteamID64(self:GetSellerSteamID())
    local itemName = self:GetItemName()
    local uniqueID = self.ixUniqueID
    local data = self.ixItemData

    buyerChar:SetMoney(buyerChar:GetMoney() - price)

    local function finish()
        client:NotifyLocalized("sellItemBought", itemName, PLUGIN:FormatMoney(price))

        if (IsValid(seller) and IsValid(seller:GetCharacter())) then
            local sellerChar = seller:GetCharacter()
            sellerChar:SetMoney(sellerChar:GetMoney() + price)
            seller:NotifyLocalized("sellItemSold", buyerChar:GetName(), itemName, PLUGIN:FormatMoney(price))
        end

        if (IsValid(self)) then
            self:Remove()
        end
    end

    local function fail()
        -- Refund the buyer if granting the item somehow failed.
        buyerChar:SetMoney(buyerChar:GetMoney() + price)
        client:NotifyLocalized("sellItemPurchaseFailed")
        self.ixSold = false
    end

    local result = buyerChar:GetInventory():Add(uniqueID, 1, data)

    -- Helix's inventory:Add commonly returns a "deferred" promise object;
    -- support both that and a plain synchronous return for safety.
    if (istable(result) and result.Next) then
        result:Next(finish)

        if (result.Catch) then
            result:Catch(fail)
        end
    else
        finish()
    end
end

--------------------------------------------------------------------
-- Gives the item back to the seller -- used both for a manual pickup
-- (owner pressed E on their own stand) and for the automatic return
-- that happens when the owner disconnects with the stand still up.
--------------------------------------------------------------------
function ENT:ReturnToOwner(client, isManualPickup)
    if (!IsValid(client)) then
        self:Remove()
        return
    end

    local character = client:GetCharacter()
    local itemName = self:GetItemName()
    local uniqueID = self.ixUniqueID
    local data = self.ixItemData

    if (!IsValid(character)) then
        self:Remove()
        return
    end

    local function finish()
        if (IsValid(client)) then
            if (isManualPickup) then
                client:NotifyLocalized("sellItemPickedUp")
            else
                client:NotifyLocalized("sellItemReturned", itemName)
            end
        end

        -- Explicitly save -- if this is happening because the player is
        -- disconnecting we can't rely on hook ordering with the core
        -- autosave to have inserted this item first.
        if (character.Save) then
            character:Save()
        end

        if (IsValid(self)) then
            self:Remove()
        end
    end

    local result = character:GetInventory():Add(uniqueID, 1, data)

    if (istable(result) and result.Next) then
        result:Next(finish)
    else
        finish()
    end
end
