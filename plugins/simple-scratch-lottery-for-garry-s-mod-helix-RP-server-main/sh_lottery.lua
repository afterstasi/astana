
ITEM.name = "Scratch lottery"
ITEM.description = "Scratch it, test your luck.."
ITEM.model = "models/lottery_ticket/lottery_ticket.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.price = 20
ITEM.flag = "v"

local rewards = {
    { chance = 710, item = nil, message = "Unfortunately... you lose.", sound = "buttons/lever7.wav"  },
    { chance = 235, item = "lotterywin50",  message = "You win 50 tokens.", sound = "buttons/lever7.wav" },
    { chance = 52, item = "lotterywin100", message = "You win 100 tokens!", sound = "buttons/lever7.wav" },
    { chance = 3,  item = "lotterywin500", message = "Oh god, You win 500 tokens!", sound = "ambient/alarms/warningbell1.wav" },33
}

ITEM.functions = ITEM.functions or {}
ITEM.functions.Use = {
    name = "Scratch",
    OnCanRun = function(item, client)
        return true
    end,
    OnRun = function(item, data)
        local player = item.player
        if not IsValid(player) then return false end

        local char = player:GetCharacter()
        if not char then return false end

        local roll = math.random(1000)
        local total = 0
        local prize = rewards[1]

        for _, v in ipairs(rewards) do
            total = total + v.chance
            if roll <= total then
                prize = v
                break
            end
        end

        char:GetInventory():Remove(item.uniqueID, 1)

        if prize.item then
            char:GetInventory():Add(prize.item)
        end

        if prize.sound then
            player:EmitSound(prize.sound)
        end

        player:Notify(prize.message)

        return true
    end,
}
