ITEM.name = "Disinfectant Spray"
ITEM.description = "A Zero's GenLab SWEP. Using this item gives the weapon."
ITEM.model = "models/zerochain/props_bloodlab/zbl_w_spray.mdl"
ITEM.width = 2
ITEM.height = 1
ITEM.category = "GenLab"
ITEM.weaponClass = "zbl_spray"

ITEM.functions.Equip = {
    name = "Equip",
    tip = "Equip this weapon.",
    icon = "icon16/gun.png",
    OnRun = function(item)
        local client = item.player
        if not IsValid(client) then return false end

        client:Give(item.weaponClass)
        client:SelectWeapon(item.weaponClass)
        return true
    end,
    OnCanRun = function(item)
        return not IsValid(item.entity)
    end
}
