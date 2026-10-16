-- helix/plugins/printer3d/entities/entities/ix_printerconsole/cl_init.lua
include("shared.lua")

-- ──────────────────────────────────────────────
-- Hover tooltip
-- ──────────────────────────────────────────────

function ENT:OnPopulateEntityInfo(tooltip)
    local nameRow = tooltip:AddRow("name")
    nameRow:SetText("Printer Terminal")
    nameRow:SetImportant()
    nameRow:SizeToContents()

    local descRow = tooltip:AddRow("desc")
    local printer = self:GetLinkedPrinter()

    if (IsValid(printer)) then
        local recipe = printer:GetRecipe()
        descRow:SetText("Linked  |  " ..
            (recipe and ("Selected: " .. recipe.name) or "No item selected"))
    else
        descRow:SetText("Searching for printer...")
    end

    descRow:SizeToContents()
end

-- ──────────────────────────────────────────────
-- Net: open terminal UI
-- ──────────────────────────────────────────────

net.Receive("ix_OpenPrinterConsole", function()
    local console = net.ReadEntity()
    if (!IsValid(console)) then return end

    if (IsValid(ix.gui.printerConsole)) then
        ix.gui.printerConsole:Remove()
    end

    ix.gui.printerConsole = vgui.Create("ixPrinterConsole")
    if (IsValid(ix.gui.printerConsole)) then
        ix.gui.printerConsole:SetEntity(console)
    end
end)

-- ──────────────────────────────────────────────
-- ixPrinterConsole  —  recipe selection UI
-- ──────────────────────────────────────────────

local PANEL = {}

function PANEL:Init()
    self:SetSize(480, 520)
    self:Center()
    self:SetTitle("")
    self:MakePopup()
    self:ShowCloseButton(true)
    self:SetDraggable(true)

    -- ── Header ──
    self.header = self:Add("DLabel")
    self.header:Dock(TOP)
    self.header:DockMargin(15, 40, 15, 2)
    self.header:SetFont("DermaLarge")
    self.header:SetTextColor(color_white)
    self.header:SetText("PRINTER TERMINAL")

    self.subheader = self:Add("DLabel")
    self.subheader:Dock(TOP)
    self.subheader:DockMargin(15, 0, 15, 10)
    self.subheader:SetFont("DermaDefault")
    self.subheader:SetTextColor(Color(180, 180, 180))
    self.subheader:SetText("Select an item, then press \"Set Recipe\" to queue it on the printer.")

    -- ── Live printer status (updated in Think) ──
    self.printerStatus = self:Add("DLabel")
    self.printerStatus:Dock(TOP)
    self.printerStatus:DockMargin(15, 0, 15, 8)
    self.printerStatus:SetFont("DermaDefault")
    self.printerStatus:SetTextColor(Color(140, 200, 140))
    self.printerStatus:SetText("")

    -- ── Recipe list ──
    self.recipeList = self:Add("DListView")
    self.recipeList:Dock(TOP)
    self.recipeList:SetTall(200)
    self.recipeList:DockMargin(15, 0, 15, 10)
    self.recipeList:SetMultiSelect(false)
    self.recipeList:AddColumn("Item"):SetFixedWidth(200)
    self.recipeList:AddColumn("Plastic Cost"):SetFixedWidth(100)
    self.recipeList:AddColumn("Time")

    if (!PRINTER_RECIPES or table.IsEmpty(PRINTER_RECIPES)) then
        -- This should never happen anymore (recipes are defined directly in
        -- sh_plugin.lua), but if it ever does, fail loudly instead of just
        -- showing a silently empty list - that's what made this bug so hard
        -- to track down the first time around.
        ErrorNoHalt("[Printer3D] PRINTER_RECIPES is empty on the client - the printer3d plugin may not be loaded correctly.\n")
        chat.AddText(Color(255, 120, 120), "[Printer3D] No recipes loaded - tell an admin to check the server console.")
    end

    local sorted = {}
    for recipeID, recipe in pairs(PRINTER_RECIPES or {}) do
        sorted[#sorted + 1] = { id = recipeID, data = recipe }
    end
    table.sort(sorted, function(a, b) return a.data.name < b.data.name end)

    for _, entry in ipairs(sorted) do
        local recipe = entry.data
        local line   = self.recipeList:AddLine(
            recipe.name,
            recipe.plasticCost .. " plastic",
            recipe.time .. "s"
        )
        line.recipeID = entry.id
        line:SetTooltip(
            (recipe.description or "No description available.") ..
            "\n\nCost: " .. recipe.plasticCost .. " ration plastic\n" ..
            "Time: " .. recipe.time .. "s"
        )
    end

    self.recipeList.OnRowSelected = function(_, _, line)
        self:ShowDetails(line.recipeID)
    end

    -- ── Details box ──
    self.detailsBox = self:Add("DPanel")
    self.detailsBox:Dock(TOP)
    self.detailsBox:SetTall(80)
    self.detailsBox:DockMargin(15, 0, 15, 12)
    self.detailsBox.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 255))
    end

    self.detailsLabel = self.detailsBox:Add("DLabel")
    self.detailsLabel:Dock(FILL)
    self.detailsLabel:DockMargin(10, 8, 10, 8)
    self.detailsLabel:SetFont("DermaDefault")
    self.detailsLabel:SetTextColor(color_white)
    self.detailsLabel:SetWrap(true)
    self.detailsLabel:SetAutoStretchVertical(true)
    self.detailsLabel:SetText("Select an item from the list above to see its details here.")

    -- ── Set recipe button ──
    self.selectButton = self:Add("DButton")
    self.selectButton:Dock(TOP)
    self.selectButton:SetTall(36)
    self.selectButton:DockMargin(15, 0, 15, 5)
    self.selectButton:SetFont("DermaLarge")
    self.selectButton:SetText("Set Recipe on Printer")
    self.selectButton:SetTooltip(
        "Tells the linked printer to queue this item once enough material is loaded.")
    self.selectButton.DoClick = function()
        local selected = self.recipeList:GetSelectedLine()
        if (!selected) then
            chat.AddText(Color(255, 100, 100), "Select a recipe from the list first.")
            return
        end

        local line = self.recipeList:GetLine(selected)
        net.Start("ix_PrinterConsoleSelect")
            net.WriteEntity(self.entity)
            net.WriteString(line.recipeID)
        net.SendToServer()
    end

    -- ── Clear button ──
    self.clearButton = self:Add("DButton")
    self.clearButton:Dock(TOP)
    self.clearButton:SetTall(32)
    self.clearButton:DockMargin(15, 0, 15, 5)
    self.clearButton:SetText("Clear Printer Selection")
    self.clearButton:SetTooltip("Removes the currently queued item from the printer.")
    self.clearButton.DoClick = function()
        net.Start("ix_PrinterConsoleSelect")
            net.WriteEntity(self.entity)
            net.WriteString("")
        net.SendToServer()
    end
end

function PANEL:SetEntity(entity)
    self.entity = entity
end

function PANEL:ShowDetails(recipeID)
    local recipe = ix.GetPrinterRecipe(recipeID)
    if (!recipe) then
        self.detailsLabel:SetText("Select an item from the list above to see its details here.")
        return
    end

    self.detailsLabel:SetText(
        recipe.name .. "\n" ..
        (recipe.description or "No description available.") ..
        "\n\nCost: " .. recipe.plasticCost .. " ration plastic   |   Time: " .. recipe.time .. "s"
    )
end

function PANEL:Think()
    if (!IsValid(self.entity)) then self:Remove() return end

    local printer = self.entity:GetLinkedPrinter()

    if (!IsValid(printer)) then
        self.printerStatus:SetText("Printer: searching...")
        self.printerStatus:SetTextColor(Color(190, 100, 100))
        return
    end

    local recipe  = printer:GetRecipe()
    local plastic = printer:GetPlasticAmount()

    if (printer:GetPrinting()) then
        local remaining = math.max(0, math.ceil(printer:GetFinishTime() - CurTime()))
        self.printerStatus:SetText(
            "Printer: PRINTING " .. (recipe and recipe.name or "?") ..
            " — " .. remaining .. "s remaining   |   Plastic: " .. plastic)
        self.printerStatus:SetTextColor(Color(255, 200, 60))

    elseif (recipe) then
        if (plastic >= recipe.plasticCost) then
            self.printerStatus:SetText(
                "Printer: READY — " .. recipe.name ..
                "   |   Plastic: " .. plastic .. " / " .. recipe.plasticCost)
            self.printerStatus:SetTextColor(Color(60, 220, 80))
        else
            self.printerStatus:SetText(
                "Printer: waiting for plastic — " .. recipe.name ..
                "   |   " .. plastic .. " / " .. recipe.plasticCost)
            self.printerStatus:SetTextColor(Color(220, 100, 60))
        end

    else
        self.printerStatus:SetText(
            "Printer: linked, no item selected   |   Plastic: " .. plastic)
        self.printerStatus:SetTextColor(Color(140, 200, 140))
    end
end

function PANEL:Paint(w, h)
    draw.RoundedBox(4, 0, 0, w, h, Color(35, 35, 35, 240))
end

vgui.Register("ixPrinterConsole", PANEL, "DFrame")
