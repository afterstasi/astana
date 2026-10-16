ITEM.name = "Mała Paczka"
ITEM.description = "Mniejsza, rozpakowana paczka."
ITEM.model = "models/hls/alyxports/cardboard_box_1_small.mdl"
ITEM.category = "Paczki"
ITEM.width = 1
ITEM.height = 1

-- Opcjonalnie: co można z nią zrobić w EQ
ITEM.functions.Sprawdz = {
    OnRun = function(item)
        item.player:Notify("To mała paczka gotowa do dalszej obróbki.")
        return false
    end
}