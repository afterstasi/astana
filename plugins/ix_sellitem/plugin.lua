PLUGIN.name = "Item Sell Stands"
PLUGIN.author = "Custom"
PLUGIN.description = "Right click an item in your inventory to place a physical, examinable 'for sale' stand in the world. Other players can walk up, press E, and buy it on the spot. Unsold stands return to your inventory the moment you disconnect."

--------------------------------------------------------------------
-- CONFIG -- tweak these to taste
--------------------------------------------------------------------

-- Max distance (units) a player can place their stand from themselves.
PLUGIN.maxSellDistance = 96

-- Max distance (units) another player can stand from a stand to interact with it.
PLUGIN.interactDistance = 150

-- Absolute price ceiling, just to keep things sane.
PLUGIN.maxPrice = 1000000

--------------------------------------------------------------------
-- LANGUAGE STRINGS
--------------------------------------------------------------------

ix.lang.AddTable("english", {
    sellItem = "Sell",
    sellItemTip = "Place this item for sale in the world.",

    sellItemPriceTitle = "Set a Price",
    sellItemPriceDesc = "How much should \"%s\" sell for?",
    sellItemPricePlaceholder = "Enter price...",
    sellItemConfirmBtn = "Next",

    sellItemPlacementHelp = "Left Click: Place        Q / E: Rotate        Right Click: Cancel",

    sellItemBuyTitle = "Purchase Item",
    sellItemBuyDesc = "%s is selling \"%s\" for %s. Would you like to buy it?",
    sellItemYes = "Yes",
    sellItemNo = "No",

    sellItemNotEnoughMoney = "You don't have enough money to buy that.",
    sellItemBought = "You purchased \"%s\" for %s.",
    sellItemSold = "%s purchased your \"%s\" for %s.",
    sellItemReturned = "Your unsold item \"%s\" was returned to your inventory.",
    sellItemPickedUp = "You picked your item back up.",
    sellItemNoLongerAvailable = "That item is no longer available.",
    sellItemPurchaseFailed = "Something went wrong with that purchase -- you've been refunded.",
})

--------------------------------------------------------------------
-- FONTS (client)
--------------------------------------------------------------------

function PLUGIN:LoadFonts()
    surface.CreateFont("ixSellItemFont", {
        font = "Roboto",
        size = 30,
        weight = 800,
        antialias = true
    })

    surface.CreateFont("ixSellItemFontSmall", {
        font = "Roboto",
        size = 19,
        weight = 600,
        antialias = true
    })
end

print("[ix_sellitem] plugin.lua loaded on " .. (SERVER and "SERVER" or "CLIENT") .. ".")
