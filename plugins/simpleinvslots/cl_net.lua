local PLUGIN = PLUGIN

net.Receive("ixOpenEquipmentSlotsOnSearch", function()
    local count = net.ReadUInt(4)
    local inventoryIDs = {}

    for _ = 1, count do
        local name = net.ReadString()
        local id = net.ReadUInt(32)
        inventoryIDs[name] = id
    end

    PLUGIN:CreateSearchEquipmentButtons(inventoryIDs)
end)
