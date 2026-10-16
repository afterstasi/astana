
if (SERVER) then
	AddCSLuaFile("shared.lua")
end

if (CLIENT) then
	SWEP.Slot = 1
	SWEP.SlotPos = 10
	SWEP.DrawAmmo = false
	SWEP.PrintName = "Stamina Implant"
	SWEP.DrawCrosshair = false
end

SWEP.Instructions = "Passive. Optimizes your body's energy metabolism."
SWEP.Purpose = "Enhances the body's stamina attribute."
SWEP.Contact = ""
SWEP.Author = ""

SWEP.WorldModel = ""
SWEP.ViewModel = ""
SWEP.HoldType = "fist"

SWEP.Primary.DefaultClip = 0
SWEP.Primary.Automatic = false
SWEP.Primary.ClipSize = -1
SWEP.Primary.Ammo = ""

SWEP.Secondary.DefaultClip = 0
SWEP.Secondary.Automatic = false
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.Ammo = ""

SWEP.NoIronSightFovChange = true
SWEP.NoIronSightAttack = true
SWEP.LoweredAngles = Angle(60, 60, 60)
SWEP.IronSightPos = Vector(0, 0, 0)
SWEP.IronSightAng = Vector(0, 0, 0)
SWEP.NeverRaised = true
SWEP.FireWhenLowered = true

SWEP.ImplantStatBoost = { attribute = "stamina", amount = 5 }

function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end
