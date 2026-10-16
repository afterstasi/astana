-- helix/plugins/fabryka/entities/entities/ix_konsola/cl_init.lua
include("shared.lua")

function ENT:OnPopulateEntityInfo(tooltip)
    local name = tooltip:AddRow("name")
    name:SetText("Konsola Sterownicza")
    name:SetImportant()
    name:SizeToContents()

    local desc = tooltip:AddRow("desc")
    -- Pobieramy zsynchronizowany licznik z shared.lua
    desc:SetText("ID przypisanych fabryk: " .. self:GetLinkedCount())
    desc:SizeToContents()
end

net.Receive("ix_OpenFactoryConsole", function()
    local consoleEntity = net.ReadEntity()
    -- Odbieramy tabelę połączonych ID z serwera
    local linkedIDs = net.ReadTable()

    if (not IsValid(consoleEntity)) then return end

    if (IsValid(ix.gui.factoryConsole)) then
        ix.gui.factoryConsole:Remove()
    end

    ix.gui.factoryConsole = vgui.Create("ixProductionConsole")
    if (IsValid(ix.gui.factoryConsole)) then
        ix.gui.factoryConsole:SetEntity(consoleEntity)
        -- NOWE: Przekazujemy listę do panelu, aby wypełnił DListView
        ix.gui.factoryConsole:PopulateLinkedFiles(linkedIDs)
    end
end)