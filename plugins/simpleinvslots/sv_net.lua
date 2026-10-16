net.Receive("ixOpenEquipmentSlotsOnSearch", function(_, client)
    local count = net.ReadUInt(4)
    local inventoryIds = {}

    for i = 1, count do
        inventoryIds[i] = net.ReadUInt(32)
    end

    for _, v in ipairs(inventoryIds) do
        if not ix.item.inventories[v] then continue end
        ix.item.inventories[v]:RemoveReceiver(client)
    end
end)