include("shared.lua")

local TAG_SCALE = 0.1
local MAX_DRAW_DIST_SQR = 700 * 700

function ENT:Draw()
    self:DrawModel()
end

function ENT:DrawTranslucent()
    self:DrawModel()
    self:DrawSaleTag()
end

--------------------------------------------------------------------
-- Renders the item's name and price floating just in front of the
-- model, facing outward, so anyone walking up can read it at a glance.
--------------------------------------------------------------------
function ENT:DrawSaleTag()
    local ply = LocalPlayer()
    if (!IsValid(ply) or ply:GetPos():DistToSqr(self:GetPos()) > MAX_DRAW_DIST_SQR) then return end

    local mins, maxs = self:GetModelBounds()
    mins = mins or Vector(-8, -8, -8)
    maxs = maxs or Vector(8, 8, 8)

    local forwardOffset = math.max(maxs.x, -mins.x, maxs.y, -mins.y, 4) + 2
    local heightOffset = maxs.z + 6

    local pos = self:GetPos() + self:GetForward() * forwardOffset + self:GetUp() * heightOffset
    local ang = self:GetAngles()

    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    cam.Start3D2D(pos, ang, TAG_SCALE)
        local name = self:GetItemName()
        local price = PLUGIN:FormatMoney(self:GetPrice())

        draw.SimpleTextOutlined(name, "ixSellItemFont", 0, 0, color_white,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)

        draw.SimpleTextOutlined(price, "ixSellItemFontSmall", 0, 30, Color(140, 255, 180),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
    cam.End3D2D()
end
