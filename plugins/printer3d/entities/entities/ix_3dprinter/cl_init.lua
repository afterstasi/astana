-- helix/plugins/printer3d/entities/entities/ix_3dprinter/cl_init.lua
include("shared.lua")

-- ──────────────────────────────────────────────
-- Hover tooltip (Helix's built-in entity info)
-- ──────────────────────────────────────────────

function ENT:OnPopulateEntityInfo(tooltip)
    -- Title row
    local nameRow = tooltip:AddRow("name")
    nameRow:SetText("3D Printer")
    nameRow:SetImportant()
    nameRow:SizeToContents()

    local recipe  = self:GetRecipe()
    local plastic = self:GetPlasticAmount()

    -- Single dynamic status row; background colour communicates state.
    local statusRow = tooltip:AddRow("status")

    if (!recipe) then
        -- Nothing selected yet.
        statusRow:SetText("No item selected — use a Printer Terminal.")
        statusRow.backgroundColor = Color(70, 70, 70, 230)

    elseif (self:GetPrinting()) then
        -- Mid-run: show countdown.
        local remaining = math.max(0, math.ceil(self:GetFinishTime() - CurTime()))
        statusRow:SetText("PRINTING: " .. recipe.name .. " (" .. remaining .. "s remaining)")
        statusRow.backgroundColor = Color(190, 140, 0, 230)

    elseif (plastic >= recipe.plasticCost) then
        -- Ready to fabricate — green, bold label as requested.
        statusRow:SetText("PRINTING: READY")
        statusRow.backgroundColor = Color(30, 160, 50, 230)

    else
        -- Needs more material.
        local need = recipe.plasticCost - plastic
        statusRow:SetText("PRINTING: INSUFFICIENT MATERIALS  (" ..
                          plastic .. " / " .. recipe.plasticCost ..
                          " — need " .. need .. " more)")
        statusRow.backgroundColor = Color(170, 40, 40, 230)
    end

    statusRow:SizeToContents()

    -- Extra info row: what's loaded and what's selected.
    if (recipe) then
        local infoRow = tooltip:AddRow("info")
        infoRow:SetText("Plastic loaded: " .. plastic ..
                        "   |   Selected: " .. recipe.name)
        infoRow:SizeToContents()
    end
end

-- ──────────────────────────────────────────────
-- Net: server opens the printer-side menu
-- ──────────────────────────────────────────────

net.Receive("ix_OpenPrinterMenu", function()
    local printer = net.ReadEntity()
    if (!IsValid(printer)) then return end

    if (IsValid(ix.gui.printerMenu)) then
        ix.gui.printerMenu:Remove()
    end

    ix.gui.printerMenu = vgui.Create("ixPrinterMenu")
    if (IsValid(ix.gui.printerMenu)) then
        ix.gui.printerMenu:SetEntity(printer)
    end
end)

-- ──────────────────────────────────────────────
-- ixPrinterMenu  —  insert plastic + FABRICATE
-- ──────────────────────────────────────────────

local PANEL = {}

function PANEL:Init()
    self:SetSize(360, 300)
    self:Center()
    self:SetTitle("")
    self:MakePopup()
    self:ShowCloseButton(true)
    self:SetDraggable(true)

    -- ── Header ──
    self.header = self:Add("DLabel")
    self.header:Dock(TOP)
    self.header:DockMargin(15, 40, 15, 4)
    self.header:SetFont("DermaLarge")
    self.header:SetTextColor(color_white)
    self.header:SetText("3D PRINTER")

    -- ── Dynamic status label ──
    self.statusLabel = self:Add("DLabel")
    self.statusLabel:Dock(TOP)
    self.statusLabel:DockMargin(15, 0, 15, 8)
    self.statusLabel:SetFont("DermaLarge")
    self.statusLabel:SetContentAlignment(5)
    self.statusLabel:SetText("")

    -- ── Details box: selected item + current plastic vs cost ──
    self.detailsBox = self:Add("DPanel")
    self.detailsBox:Dock(TOP)
    self.detailsBox:SetTall(68)
    self.detailsBox:DockMargin(15, 0, 15, 12)
    self.detailsBox.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 255))
    end

    self.detailsLabel = self.detailsBox:Add("DLabel")
    self.detailsLabel:Dock(FILL)
    self.detailsLabel:DockMargin(10, 6, 10, 6)
    self.detailsLabel:SetTextColor(color_white)
    self.detailsLabel:SetWrap(true)
    self.detailsLabel:SetAutoStretchVertical(true)

    -- ── Plastic insert controls ──
    self.insertRow = self:Add("DPanel")
    self.insertRow:Dock(TOP)
    self.insertRow:SetTall(32)
    self.insertRow:DockMargin(15, 0, 15, 6)
    self.insertRow.Paint = function() end   -- transparent

    self.insertAmount = self.insertRow:Add("DNumberWang")
    self.insertAmount:Dock(LEFT)
    self.insertAmount:SetWide(90)
    self.insertAmount:SetMin(1)
    self.insertAmount:SetMax(999)
    self.insertAmount:SetValue(1)
    self.insertAmount:SetTooltip("How many ration plastic to deposit.")

    self.insertButton = self.insertRow:Add("DButton")
    self.insertButton:Dock(FILL)
    self.insertButton:DockMargin(6, 0, 0, 0)
    self.insertButton:SetText("Insert Ration Plastic")
    self.insertButton:SetTooltip("Moves ration plastic from your inventory into the printer.")
    self.insertButton.DoClick = function()
        net.Start("ix_PrinterInsertPlastic")
            net.WriteEntity(self.entity)
            net.WriteUInt(math.Round(self.insertAmount:GetValue()), 16)
        net.SendToServer()
    end

    -- ── FABRICATE button ──
    self.fabricateButton = self:Add("DButton")
    self.fabricateButton:Dock(TOP)
    self.fabricateButton:SetTall(40)
    self.fabricateButton:DockMargin(15, 4, 15, 6)
    self.fabricateButton:SetText("FABRICATE")
    self.fabricateButton:SetFont("DermaLarge")
    self.fabricateButton:SetTooltip("Begin fabrication. The printer locks until the job is done.")
    self.fabricateButton.DoClick = function()
        net.Start("ix_PrinterFabricate")
            net.WriteEntity(self.entity)
        net.SendToServer()
        self:Remove()   -- close menu immediately; status visible on tooltip
    end
end

function PANEL:SetEntity(entity)
    self.entity = entity
end

-- Runs every frame; keeps labels & button state in sync with networked vars.
function PANEL:Think()
    if (!IsValid(self.entity)) then self:Remove() return end

    local recipe  = self.entity:GetRecipe()
    local plastic = self.entity:GetPlasticAmount()

    if (!recipe) then
        self.statusLabel:SetText("NO ITEM SELECTED")
        self.statusLabel:SetTextColor(Color(190, 190, 190))
        self.detailsLabel:SetText(
            "Use a Printer Terminal to choose what to build.\n" ..
            "Plastic loaded: " .. plastic)
        self.fabricateButton:SetEnabled(false)

    elseif (self.entity:GetPrinting()) then
        local remaining = math.max(0, math.ceil(self.entity:GetFinishTime() - CurTime()))
        self.statusLabel:SetText("PRINTING...  " .. remaining .. "s")
        self.statusLabel:SetTextColor(Color(255, 200, 0))
        self.detailsLabel:SetText(
            "Building: " .. recipe.name .. "\n" ..
            "Plastic remaining: " .. plastic)
        self.fabricateButton:SetEnabled(false)

    elseif (plastic >= recipe.plasticCost) then
        self.statusLabel:SetText("PRINTING: READY")
        self.statusLabel:SetTextColor(Color(60, 220, 80))
        self.detailsLabel:SetText(
            recipe.name .. "\n" ..
            "Plastic: " .. plastic .. " / " .. recipe.plasticCost .. " ✓")
        self.fabricateButton:SetEnabled(true)

    else
        local need = recipe.plasticCost - plastic
        self.statusLabel:SetText("INSUFFICIENT MATERIALS")
        self.statusLabel:SetTextColor(Color(220, 60, 60))
        self.detailsLabel:SetText(
            recipe.name .. "\n" ..
            "Plastic: " .. plastic .. " / " .. recipe.plasticCost ..
            "  (need " .. need .. " more)")
        self.fabricateButton:SetEnabled(false)
    end
end

function PANEL:Paint(w, h)
    draw.RoundedBox(4, 0, 0, w, h, Color(35, 35, 35, 240))
end

vgui.Register("ixPrinterMenu", PANEL, "DFrame")
