local PLUGIN = PLUGIN
local CHAR = ix.meta.character
local META = FindMetaTable("Player")
	
PLUGIN.name = "Survival System"
PLUGIN.author = "ZeMysticalTaco"
PLUGIN.description = "A survival system consisting of hunger and thirst."

local speed = 100
local decay = 10

ix.config.Add("hungerDecaySpeed", speed, "Speed at which hunger should decay.", nil, { data = {min = 1, max = 600}, category = "Survival System" })
ix.config.Add("hungerDecayAmount", decay, "Amount at which hunger should decay", nil, { data = {min = 0, max = 5}, category = "Survival System" })
ix.config.Add("thirstDecaySpeed", speed, "Speed at which thirst should decay.", nil, { data = {min = 1, max = 600}, category = "Survival System"})
ix.config.Add("thirstDecayAmount", decay, "Amount at which thirst should decay", nil, { data = {min = 0, max = 5}, category = "Survival System"})
ix.config.Add("survivalResetOnRespawn", true, "Reset hunger and thirst to 100 when player respawns", nil, { category = "Survival System"})
ix.config.Add("survivalHealthDamage", 1, "Health damage per tick when starving/dehydrated", nil, { data = {min = 1, max = 10}, category = "Survival System" })
ix.config.Add("survivalHealthDamageInterval", 10, "Seconds between health damage ticks", nil, { data = {min = 5, max = 60}, category = "Survival System"})

ix.config.Add("toxinIncreaseSpeed", 10, "Seconds between toxin increases while outdoors.", nil, { data = {min = 1, max = 120}, category = "Survival System" })
ix.config.Add("toxinIncreaseAmount", 1, "Amount toxin increases while outdoors.", nil, { data = {min = 0, max = 5}, category = "Survival System" })
ix.config.Add("toxinDecreaseSpeed", 5, "Seconds between toxin decreases while indoors.", nil, { data = {min = 1, max = 120}, category = "Survival System" })
ix.config.Add("toxinDecreaseAmount", 1, "Amount toxin decreases while indoors.", nil, { data = {min = 0, max = 5}, category = "Survival System" })
ix.config.Add("toxinBloodMin", 33, "Toxin level at which coughing fits can start producing blood.", nil, { data = {min = 0, max = 100}, category = "Survival System" })

ix.command.Add("SetHunger", {
	description = "Set a player's hunger value.",
	adminOnly = true,
	arguments = {
		ix.type.character,
		ix.type.number
	},
	OnRun = function(self, client, targetChar, hunger)
		local target = targetChar:GetPlayer()

		if not IsValid(target) then
			return "Target player is not valid."
		end

		hunger = math.Clamp(hunger, 0, 100)
		target:SetHunger(hunger)

		client:Notify("You have set " .. target:Name() .. "'s hunger to " .. hunger .. ".")

		return true
	end
})

ix.command.Add("SetThirst", {
	description = "Set a player's thirst value.",
	adminOnly = true,
	arguments = {
		ix.type.character,
		ix.type.number
	},
	OnRun = function(self, client, targetChar, thirst)
		local target = targetChar:GetPlayer()

		if not IsValid(target) then
			return "Target player is not valid."
		end

		thirst = math.Clamp(thirst, 0, 100)
		target:SetThirst(thirst)

		client:Notify("You have set " .. target:Name() .. "'s thirst to " .. thirst .. ".")

		return true
	end
})
ix.command.Add("SetToxin", {
	description = "Set a player's toxin value.",
	adminOnly = true,
	arguments = {
		ix.type.character,
		ix.type.number
	},
	OnRun = function(self, client, targetChar, toxin)
		local target = targetChar:GetPlayer()

		if not IsValid(target) then
			return "Target player is not valid."
		end

		toxin = math.Clamp(toxin, 0, 100)
		target:SetToxin(toxin)

		client:Notify("You have set " .. target:Name() .. "'s toxin to " .. toxin .. ".")

		return true
	end
})

ix.command.Add("SetArea", {
	description = "Edits the current area you are in. Use NIL or -1 to keep values unchanged.",
	adminOnly = true,
	arguments = {
		bit.bor(ix.type.string, ix.type.optional), -- new name
		bit.bor(ix.type.string, ix.type.optional), -- type
		bit.bor(ix.type.number, ix.type.optional), -- display
		bit.bor(ix.type.number, ix.type.optional), -- r
		bit.bor(ix.type.number, ix.type.optional), -- g
		bit.bor(ix.type.number, ix.type.optional)  -- b
	},
	argumentNames = {
		"Name or NIL",
		"Type or NIL",
		"Display 0/1 or -1",
		"Red or -1",
		"Green or -1",
		"Blue or -1"
	},
	OnRun = function(self, client, newName, newType, display, r, g, b)
		local currentName = client:GetArea()
		if not currentName then	return "Safety Check. You are not inside an area nor do you have a LastArea val." end
		if not client:IsInArea() then return "Safety Check. You are not inside a valid areas bounding box but have a LastArea. Please move into the areas bounding box to make sure you are editing the right place!" end
		local area = ix.area.stored[currentName]
		if not area then
			return "Current area could not be resolved."
		end
		area.properties = area.properties or {}
		area.properties.color = area.properties.color or {}
		if newType and string.lower(newType) ~= "nil" then
			area.type = string.lower(newType)
		end
		if display ~= nil and display ~= -1 then
			area.properties.display = display == 1
		end
		if r ~= nil and r ~= -1 then
			area.properties.color.r = math.Clamp(r, 0, 255)
		end
		if g ~= nil and g ~= -1 then
			area.properties.color.g = math.Clamp(g, 0, 255)
		end
		if b ~= nil and b ~= -1 then
			area.properties.color.b = math.Clamp(b, 0, 255)
		end
		if ((newName and string.lower(newName) ~= "nil") and string.lower(newName) ~= string.lower(currentName)) then
			if ix.area.stored[newName] then
				return "An area with that name already exists."
			end
			ix.log.Add(client,"areaAdd",newName)
			ix.area.Create(newName,(area.type or "area"),(area.startPosition or Vector(0,0,0)),(area.endPosition or Vector(10,10,10)),false,(area.properties or {
				["color"] = Color(255,255,255), 
				["display"] = true}
			) )
			ix.log.Add(client,"areaRemove",currentName)
			ix.area.Remove(currentName,false)
		else
			ix.log.Add(client,"areaAdd",(((newName && string.lower((newName or "")) ~= "nil") and newName or currentName) or "<ERR>"))
		end
		-- print("--==[ Area Edit Trace Start | '"..(currentName or ">ERR<").."' | '"..(newName or ">ERR<").."' ]==--")
		-- PrintTable(area)
		-- print("--==[ End ]==--")
		return "Area updated. Check to see if its all correct. with /AreaEdit!"
	end
})

-- Inner monologue messages
local hungerMonologues = {
	[20] = {"I need to find food soon...", "My stomach feels empty...", "When did I last eat?"},
	[10] = {"I'm so hungry...", "I need food desperately...", "My body is crying out for sustenance..."},
	[5] = {"I can barely think straight from hunger...", "Food... I need food...", "Everything hurts from starvation..."}
}

local thirstMonologues = {
	[20] = {"My mouth is getting dry...", "I could really use some water...", "When did I last drink?"},
	[10] = {"I'm so thirsty...", "I need water desperately...", "My throat feels like sandpaper..."},
	[5] = {"I can barely swallow...", "Water... I need water...", "My lips are cracked and dry..."}
}

local toxinMonologues = {
	[20] = {"My head feels a little foggy...", "My chest feels tight for some reason...","My skin feels oddly warm..."},
	[50] = {"My thoughts are getting slower and.. heavier...", "My muscles are feeling weak. Like they are lagging behind...","My heartbeat feels so tired.. It's-- working harder than it should..."},
	[80] = {"It feels hard to stay upright...", "My body feels absolutely vile... Legs and arms are taking effort...","I feel dizzy... The ground looks nice to nap on..."}
}

do -- SHARED --
	function PLUGIN:SetupAreaProperties()
        ix.area.AddType("gas")
    end
	function CHAR:InGasArea()
		local player = self:GetPlayer()
		local currentArea = player:GetArea() or nil
		if (currentArea) then
			local stored = ix.area.stored[player:GetArea()] or nil
			if (stored and player:GetMoveType() ~= MOVETYPE_NOCLIP) then
				local clientPos = player:GetPos() + player:OBBCenter()
				return (stored.type == 'gas' and clientPos:WithinAABox(stored.startPosition, stored.endPosition)), stored
			end
		else
			return false
		end
	end
	
	function META:InGasArea()
		local character = self:GetCharacter()
		if (character) then
			return character:InGasArea()
		else
			return false
		end
	end
end
if SERVER then
	function PLUGIN:OnCharacterCreated(client, character)
		character:SetData("hunger", 100)
		character:SetData("thirst", 100)
		character:SetData("toxin", 0)
	end
		
	function PLUGIN:PlayerLoadedCharacter(client, character)
		timer.Simple(0.25, function()
			client:SetLocalVar("hunger", character:GetData("hunger", 100))
			client:SetLocalVar("thirst", character:GetData("thirst", 100))
			client:SetLocalVar("toxin", character:GetData("toxin", 0))
		end)
	end

	function PLUGIN:PlayerSpawn(client)
		-- Only reset if player actually died (not just switching characters)
		if ix.config.Get("survivalResetOnRespawn", true) and client:GetNetVar("survivalJustDied", false) then
			timer.Simple(0.5, function()
				if IsValid(client) then
					client:SetHunger(100)
					client:SetThirst(100)
					client:SetToxin(0)
					client:SetNetVar("survivalJustDied", false)
				end
			end)
		else
			if client:GetNetVar("survivalJustDied", false) then
				client:SetNetVar("survivalJustDied", false)
			end
		end
	end

	function PLUGIN:PlayerDeath(client)
		-- Mark that player died so we can reset on respawn
		client:SetNetVar("survivalJustDied", true)
	end

	function PLUGIN:CharacterPreSave(character)
		local client = character:GetPlayer()

		if (IsValid(client)) then
			character:SetData("hunger", client:GetLocalVar("hunger", 0))
			character:SetData("thirst", client:GetLocalVar("thirst", 0))
			character:SetData("toxin", client:GetLocalVar("toxin", 0))
		end
	end

	local playerMeta = FindMetaTable("Player")

	function playerMeta:SetHunger(amount)
		local char = self:GetCharacter()

		if (char) then
			char:SetData("hunger", amount)
			self:SetLocalVar("hunger", amount)
		end
	end

	function playerMeta:SetThirst(amount)
		local char = self:GetCharacter()

		if (char) then
			char:SetData("thirst", amount)
			self:SetLocalVar("thirst", amount)
		end
	end

	function playerMeta:TickThirst(amount)
		local char = self:GetCharacter()

		if (char) then
			local oldThirst = char:GetData("thirst", 100)
			local newThirst = math.max(0, oldThirst - amount)

			char:SetData("thirst", newThirst)
			self:SetLocalVar("thirst", newThirst)

			-- Check for monologue triggers
			for threshold, messages in pairs(thirstMonologues) do
				if oldThirst > threshold and newThirst <= threshold then
					self:NotifyLocalized(messages[math.random(#messages)])
					break
				end
			end
		end
	end

	function playerMeta:TickHunger(amount)
		local char = self:GetCharacter()

		if (char) then
			local oldHunger = char:GetData("hunger", 100)
			local newHunger = math.max(0, oldHunger - amount)

			char:SetData("hunger", newHunger)
			self:SetLocalVar("hunger", newHunger)

			-- Check for monologue triggers
			for threshold, messages in pairs(hungerMonologues) do
				if oldHunger > threshold and newHunger <= threshold then
					self:NotifyLocalized(messages[math.random(#messages)])
					break
				end
			end
		end
	end
	function playerMeta:SetToxin(amount)
		local char = self:GetCharacter()
		local amountClamped = math.Clamp(amount, 0, 100)
		if char then
			local old = char:GetData("toxin", 0)
			if amount >= 100 then -- Perish.
				if amount > old then
					if self:Alive() then
						self:Kill()
					end
				end
			else -- Live! :)
				char:SetData("toxin", amountClamped)
				self:SetLocalVar("toxin", amountClamped)
			end
			for threshold, messages in pairs(toxinMonologues) do
				if old < threshold and amountClamped >= threshold then
					self:NotifyLocalized(messages[math.random(#messages)])
					break
				end
			end
		end
	end
		
	function playerMeta:GetToxin()
		local char = self:GetCharacter()
		if char then
			return char:GetData("toxin", 0)
		end
	end
		
	function playerMeta:TickToxin(amount)
		local char = self:GetCharacter()
		if char then
			local old = char:GetData("toxin", 0)
			local new = math.Clamp(old + amount, 0, 100)
			self:SetToxin(new)
		end
	end
	--[[function PLUGIN:IsPlayerIndoors(ply)
		local startPos = ply:EyePos()
		local endPos = startPos + Vector(0, 0, 8192)
		local tr = util.TraceLine({
			start = startPos,
			endpos = endPos,
			mask = MASK_VISIBLE_AND_NPCS,
			filter = ply
		})
		if tr.Hit and not tr.HitSky then
			return true
		end
		return false
	end--]]
	-- Sound effects for survival状态
	local lastHeartbeatPlayers = {}

	local survivalSounds = {
		stomach = {"player/suit_denydevice.wav"},
		heartbeat = {"player/heartbeat1.wav"},
		breathing = {"player/breathe1.wav"}
	}

	-- Coughing fits (toxin in the "Coughing Fits" bar range)
	util.AddNetworkString("ixToxinCough")
	util.AddNetworkString("ixToxinBlood")

	local COUGH_MIN = 25 -- matches the "Coughing Fits" bar status (0.25 - 0.40)
	local COUGH_MAX = 100

	local coughMessages = {
		[1] = {
			"coughs.",
			"clears their throat with a small cough.",
			"lets out a dry cough.",
			"coughs lightly into their fist.",
			"gives a quiet, scratchy cough."
		},
		[2] = {
			"coughs harshly.",
			"breaks into a rough, rattling cough.",
			"coughs several times, wincing.",
			"hacks out a wet-sounding cough.",
			"doubles over slightly with a heavy cough."
		},
		[3] = {
			"is wracked by a violent coughing fit.",
			"coughs uncontrollably, struggling to catch their breath.",
			"hacks and gags, coughing violently.",
			"convulses with deep, ragged coughs.",
			"doubles over, coughing so hard it looks painful."
		}
	}

	local bloodyCoughMessages = {
		[1] = {
			"coughs, flecks of blood speckling their lips.",
			"coughs weakly, a thin line of blood at the corner of their mouth.",
			"gives a wet cough, a bit of blood on their lips.",
			"coughs, spitting out a small fleck of blood.",
			"clears their throat with a wet cough, a faint red tinge on their lips."
		},
		[2] = {
			"coughs up a mouthful of blood.",
			"hacks wetly, spraying a mist of blood.",
			"coughs hard, blood spattering from their mouth.",
			"wheezes and coughs, spitting blood onto the ground.",
			"coughs roughly, blood dribbling down their chin."
		},
		[3] = {
			"is racked by a violent coughing fit, retching up gouts of blood.",
			"coughs up blood in thick, wet heaves.",
			"hacks and gags, blood spraying from their mouth with each cough.",
			"doubles over, coughing up a splatter of blood.",
			"convulses, coughing up blood uncontrollably."
		}
	}

	local coughSounds = {
		male = {
			"vo/npc/male01/cough01.wav", "vo/npc/male01/cough02.wav",
			"vo/npc/male01/cough03.wav", "vo/npc/male01/cough04.wav"
		},
		female = {
			"vo/npc/female01/cough01.wav", "vo/npc/female01/cough02.wav",
			"vo/npc/female01/cough03.wav", "vo/npc/female01/cough04.wav"
		}
	}

	-- Returns 0-1 position inside the coughing range, or nil if outside it.
	local function GetCoughFraction(toxin)
		if toxin < COUGH_MIN or toxin >= COUGH_MAX then return nil end
		return (toxin - COUGH_MIN) / (COUGH_MAX - COUGH_MIN)
	end

	function playerMeta:DoToxinCough(frac)
		local toxin = self:GetToxin() or 0
		local tier = frac < 0.33 and 1 or (frac < 0.66 and 2 or 3)

		-- Blood: possible once toxin passes the configured threshold, and more
		-- likely (30% -> 90%) the closer it gets to the top of the coughing range.
		local bloodMin = ix.config.Get("toxinBloodMin", 33)
		local bloodScale = 0
		local bloody = false

		if toxin >= bloodMin then
			bloodScale = math.Clamp((toxin - bloodMin) / math.max(COUGH_MAX - bloodMin, 1), 0, 1)
			bloody = math.random(100) <= Lerp(bloodScale, 30, 90)
		end

		-- Chat emote (once per fit)
		local pool = (bloody and bloodyCoughMessages or coughMessages)[tier]
		ix.chat.Send(self, "me", pool[math.random(#pool)])

		-- Higher toxin = longer fits with more coughs in a row
		local coughs = tier
		local shakeAmp = Lerp(frac, 1, 6)
		local shakeTime = Lerp(frac, 0.6, 1.8)
		local soundPool = self:IsFemale() and coughSounds.female or coughSounds.male

		for i = 1, coughs do
			timer.Simple((i - 1) * 0.55, function()
				if not IsValid(self) or not self:Alive() then return end

				-- Emit from the player entity so the sound is audible to the player and nearby listeners.
				-- A sound level of 70-80 gives nearby players a clear, positional cough.
				self:EmitSound(soundPool[math.random(#soundPool)], 75, math.random(95, 105))

				if bloody then
					self:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(1, 4) .. ".wav", 45)

					net.Start("ixToxinBlood")
						net.WriteEntity(self)
						net.WriteFloat(Lerp(bloodScale, 0.35, 0.8) * math.Rand(0.8, 1.2)) -- spray duration
						net.WriteFloat(bloodScale) -- 0-1 intensity
						-- Broadcast so the coughing player always receives their own blood event.
						-- The effect remains attached to the player entity on each client.
					net.Broadcast()
				end
			end)
		end

		net.Start("ixToxinCough")
			net.WriteFloat(shakeAmp)
			net.WriteFloat(shakeTime + (coughs - 1) * 0.55)
		net.Send(self)
	end

	function PLUGIN:PlayerTick(ply)
		if ply:GetNetVar("hungertick", 0) <= CurTime() then
			ply:SetNetVar("hungertick", ix.config.Get("hungerDecaySpeed", 300) + CurTime())
			ply:TickHunger(ix.config.Get("hungerDecayAmount", 1))
		end

		if ply:GetNetVar("thirsttick", 0) <= CurTime() then
			ply:SetNetVar("thirsttick", ix.config.Get("thirstDecaySpeed", 300) + CurTime())
			ply:TickThirst(ix.config.Get("thirstDecayAmount", 1))
		end

		-- Health degradation and effects
		local hunger	= ply:GetHunger() or 100
		local thirst	= ply:GetThirst() or 100
		local toxin		= ply:GetToxin() or 0
		local damageInterval = ix.config.Get("survivalHealthDamageInterval", 10)

		if hunger <= 0 or thirst <= 0 then
			if (ply:GetNetVar("survivaldamagetick", 0) <= CurTime()) then
				ply:SetNetVar("survivaldamagetick", CurTime() + damageInterval)

				if ply:Health() > 1 then
					local dmg = DamageInfo()
					dmg:SetDamage(ix.config.Get("survivalHealthDamage", 1))
					dmg:SetDamageType(DMG_GENERIC)
					ply:TakeDamageInfo(dmg)

					-- Clamp health to minimum 1
					if ply:Health() < 1 then
						ply:SetHealth(1)
					end
				end
			end
		end

		-- Sound cues
		if hunger <= 15 or thirst <= 15 or toxin >= 50 then
			if (ply:GetNetVar("survivalsoundtick", 0) <= CurTime()) then
				ply:SetNetVar("survivalsoundtick", CurTime() + math.random(15, 30))

				if hunger <= 5 or thirst <= 5 or toxin >= 75 then
					-- Stop previous heartbeat if playing
					if lastHeartbeatPlayers[ply] then
						ply:StopSound(survivalSounds.heartbeat[1])
					end
					ply:EmitSound(survivalSounds.heartbeat[1], 50, 100)
					lastHeartbeatPlayers[ply] = true
				elseif hunger <= 15 or toxin >= 50 then
					ply:EmitSound(survivalSounds.stomach[1], 50, 100)
				end
			end
		else
			-- Stop heartbeat when no longer critical
			if lastHeartbeatPlayers[ply] then
				ply:StopSound(survivalSounds.heartbeat[1])
				lastHeartbeatPlayers[ply] = nil
			end
		end

		-- Send survival status to client for visual effects
		local severity = 0
		if		hunger <= 5 or	thirst <= 5 or	toxin >= 80 then
			severity = 3
		elseif	hunger <= 15 or	thirst <= 15 or	toxin >= 50 then
			severity = 2
		elseif	hunger <= 30 or	thirst <= 30 or	toxin >= 30 then
			severity = 1
		end

		ply:SetNetVar("survivalSeverity", severity)
		-- local indoors = self:IsPlayerIndoors(ply)
		local toxinDecayTick,toxinProtection,toxinResistance,toxintick = (ply:GetNetVar("toxindecaytick", 0) <= CurTime()), (ply:GetNetVar("toxinProtection", 0) > CurTime()), (ply:GetNetVar("toxinResistance", 0) > CurTime()), (ply:GetNetVar("toxintick", 0) <= CurTime())
		if not ply:InGasArea() then
			if toxinDecayTick && not ply:IsCombine() then
				ply:SetNetVar("toxindecaytick", CurTime() + ix.config.Get("toxinDecreaseSpeed", 5))

				local cur = ply:GetToxin() or 0
				ply:SetToxin(cur - ix.config.Get("toxinDecreaseAmount", 1))
			end
		else
			if toxinDecayTick && not ply:IsCombine() then
				ply:SetNetVar("toxindecaytick", CurTime() + ix.config.Get("toxinDecreaseSpeed", 5))
				if toxinProtection then
					local cur = ply:GetToxin() or 0
				ply:SetToxin(cur - ix.config.Get("toxinDecreaseAmount", 1))
				end
			end
			local mult = 1
			if toxinProtection then
				mult = 0
			elseif toxinResistance then
				mult = 0.25
			end
			if toxintick && not ply:IsCombine() then
				ply:SetNetVar("toxintick", CurTime() + ix.config.Get("toxinIncreaseSpeed", 10))
				local cur = ply:GetToxin() or 0
				if mult > 0 then
					ply:SetToxin(cur + (ix.config.Get("toxinIncreaseAmount", 1) * mult))
				end
			end
		end
		local toxin = ply:GetToxin() or 0

		-- Coughing fits
		local coughFrac = GetCoughFraction(toxin)
		if coughFrac and ply:Alive() and not ply:IsCombine() then
			if ply:GetNetVar("toxincoughtick", 0) <= CurTime() then
				-- 25 toxin: roughly every 25s | 40 toxin: roughly every 8s (with some randomness)
				local interval = Lerp(coughFrac, 25, 8) * math.Rand(0.75, 1.25)
				ply:SetNetVar("toxincoughtick", CurTime() + interval)
				ply:DoToxinCough(coughFrac)
			end
		end

		if toxin >= 50 then
			if ply:GetNetVar("toxindamagetick", 0) <= CurTime() then
				ply:SetNetVar("toxindamagetick", CurTime() + 5)
				local dmg = math.Clamp(math.ceil((toxin - 50) * 0.2),0,12)
				local info = DamageInfo()
					info:SetDamage(dmg)
					info:SetDamageType(DMG_POISON)
					info:SetAttacker(game.GetWorld())
					info:SetInflictor(game.GetWorld())
				ply:TakeDamageInfo(info)
			end
		end
	end

	-- Movement speed penalty
	function PLUGIN:Move(ply, mv)
		local hunger = ply:GetHunger() or 100
		local thirst = ply:GetThirst() or 100
		local penalty = 1.0

		if hunger <= 5 or thirst <= 5 then
			penalty = 0.5 -- 50% speed
		elseif hunger <= 15 or thirst <= 15 then
			penalty = 0.7 -- 70% speed
		elseif hunger <= 30 or thirst <= 30 then
			penalty = 0.85 -- 85% speed
		end

		if penalty < 1.0 then
			mv:SetMaxSpeed(mv:GetMaxSpeed() * penalty)
			mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * penalty)
		end
	end
else
	-- Client-side visual effects
	local function DrawSurvivalEffects()
		local severity = LocalPlayer():GetNetVar("survivalSeverity", 0)

		if severity == 0 then return end

		local blurAmount = 0

		if severity == 2 then
			blurAmount = 2
		elseif severity == 3 then
			blurAmount = 4
		end

		-- Blur effect
		if blurAmount > 0 then
			DrawMotionBlur(0.1, blurAmount * 0.1, 0.01)
		end

		-- Subtle color desaturation for severe
		if severity >= 2 then
			local tab = {}
			tab["$pp_colour_addr"] = 0
			tab["$pp_colour_addg"] = 0
			tab["$pp_colour_addb"] = 0
			tab["$pp_colour_brightness"] = -0.02 * severity
			tab["$pp_colour_contrast"] = 1 + (0.1 * (severity - 1))
			tab["$pp_colour_colour"] = 1 - (0.2 * (severity - 1))
			tab["$pp_colour_mulr"] = 0
			tab["$pp_colour_mulg"] = 0
			tab["$pp_colour_mulb"] = 0
			DrawColorModify(tab)
		end
	end

	hook.Add("HUDPaint", "ixSurvivalEffects", DrawSurvivalEffects)

	-- Coughing screen shake
	local coughShake = {amp = 0, start = 0, finish = 0}

	net.Receive("ixToxinCough", function()
		coughShake.amp = net.ReadFloat()
		local duration = net.ReadFloat()
		coughShake.start = CurTime()
		coughShake.finish = CurTime() + duration
	end)

	hook.Add("CalcView", "ixToxinCoughShake", function(client, origin, angles, fov)
		if CurTime() >= coughShake.finish then return end

		-- Fade out over the duration of the fit
		local progress = (CurTime() - coughShake.start) / (coughShake.finish - coughShake.start)
		local strength = coughShake.amp * (1 - progress)
		local t = CurTime() * 25

		local newAngles = Angle(angles.p, angles.y, angles.r)
		newAngles.p = newAngles.p + math.sin(t) * strength * 0.6 + math.Rand(-0.2, 0.2) * strength
		newAngles.y = newAngles.y + math.cos(t * 0.8) * strength * 0.3
		newAngles.r = newAngles.r + math.sin(t * 1.3) * strength * 0.8

		return {origin = origin, angles = newAngles, fov = fov}
	end)

	-- Coughing blood spray (ported from Savee's Blood Vomiting addon: particle
	-- stream from the mouth + small ground stains drawn as manual mesh quads)
	local BLOOD = {
		stainMaterial = "decals/bloodstain_001",
		stainSizeMin = 5,
		stainSizeMax = 10,
		stainChance = 2,       -- 1 in N droplets leaves a stain
		velocityMin = 70,
		velocityMax = 150,
		maxStains = 400
	}

	local bloodParticles = {
		{"decals/flesh/blood1", 2}, {"decals/flesh/blood2", 2}, {"decals/flesh/blood3", 2},
		{"decals/flesh/blood4", 2}, {"decals/flesh/blood4", 2},
		{"decals/blood1", 2}, {"decals/blood2", 2}, {"decals/blood3", 2},
		{"decals/blood4", 2}, {"decals/blood5", 2}
	}

	local stains = {}
	local stainMat

	local function GetStainMaterial()
		if not stainMat then
			stainMat = Material(BLOOD.stainMaterial)
		end

		return stainMat
	end

	local function DrawStainQuad(mat, pos, normal, size)
		local up = Vector(0, 0, 1)
		if math.abs(normal:Dot(up)) > 0.99 then up = Vector(0, 1, 0) end

		local right = normal:Cross(up)
		right:Normalize()
		local forward = right:Cross(normal)
		forward:Normalize()

		local half = size * 0.5
		local v1 = pos - right * half - forward * half
		local v2 = pos + right * half - forward * half
		local v3 = pos + right * half + forward * half
		local v4 = pos - right * half + forward * half

		render.SetMaterial(mat)
		mesh.Begin(MATERIAL_TRIANGLES, 2)
			mesh.Position(v1) mesh.Normal(normal) mesh.TexCoord(0, 0, 0) mesh.Color(255, 255, 255, 255) mesh.AdvanceVertex()
			mesh.Position(v2) mesh.Normal(normal) mesh.TexCoord(0, 1, 0) mesh.Color(255, 255, 255, 255) mesh.AdvanceVertex()
			mesh.Position(v3) mesh.Normal(normal) mesh.TexCoord(0, 1, 1) mesh.Color(255, 255, 255, 255) mesh.AdvanceVertex()

			mesh.Position(v1) mesh.Normal(normal) mesh.TexCoord(0, 0, 0) mesh.Color(255, 255, 255, 255) mesh.AdvanceVertex()
			mesh.Position(v3) mesh.Normal(normal) mesh.TexCoord(0, 1, 1) mesh.Color(255, 255, 255, 255) mesh.AdvanceVertex()
			mesh.Position(v4) mesh.Normal(normal) mesh.TexCoord(0, 0, 1) mesh.Color(255, 255, 255, 255) mesh.AdvanceVertex()
		mesh.End()
	end

	hook.Add("PostDrawOpaqueRenderables", "ixToxinBloodStains", function()
		if #stains == 0 then return end

		render.SuppressEngineLighting(true)

		for i = 1, #stains do
			local st = stains[i]
			DrawStainQuad(st.mat, st.pos, st.normal, st.size)
		end

		render.SuppressEngineLighting(false)
	end)

	-- Stains are pure client-side render data, so map cleanups have to clear them manually.
	hook.Add("PostCleanupMap", "ixToxinBloodClearStains", function()
		table.Empty(stains)
	end)

	hook.Add("OnCleanup", "ixToxinBloodClearStainsType", function()
		table.Empty(stains)
	end)

	local function AddBloodStain(pos, normal)
		local mat = GetStainMaterial()

		if not mat or mat:IsError() then
			util.Decal("Blood", pos + normal, pos - normal) -- built-in fallback
			return
		end

		stains[#stains + 1] = {
			mat = mat,
			pos = pos + normal * 0.1, -- nudge off the surface to avoid z-fighting
			normal = normal,
			size = math.Rand(BLOOD.stainSizeMin, BLOOD.stainSizeMax)
		}

		if #stains > BLOOD.maxStains then
			table.remove(stains, 1)
		end
	end

	-- Mouth position + facing direction for a player model
	local function GetMouthTransform(ply)
		local bone = ply:LookupBone("ValveBiped.Bip01_Head1")

		if bone then
			local matrix = ply:GetBoneMatrix(bone)

			if matrix then
				local pos, ang = LocalToWorld(Vector(0, -2, 0), Angle(0, -92, 90), matrix:GetTranslation(), matrix:GetAngles())
				return pos, ang:Forward()
			end
		end

		local attID = ply:LookupAttachment("eyes")

		if attID and attID > 0 then
			local att = ply:GetAttachment(attID)

			if att then
				return att.Pos - att.Ang:Up() * 2.5 + att.Ang:Forward() * 1.5, att.Ang:Forward()
			end
		end

		local eyeAng = ply:EyeAngles()
		return ply:EyePos() - eyeAng:Up() * 3 + eyeAng:Forward() * 4, eyeAng:Forward()
	end

	local activeSprays = {}

	net.Receive("ixToxinBlood", function()
		local ply = net.ReadEntity()
		local duration = net.ReadFloat()
		local scale = net.ReadFloat()

		if not IsValid(ply) then return end

		-- The server broadcasts this so the victim always receives the event.
		-- Keep remote effects local to nearby players, but always show your own blood.
		local viewer = LocalPlayer()
		if ply ~= viewer and viewer:GetPos():DistToSqr(ply:GetPos()) > (3000 * 3000) then return end

		activeSprays[#activeSprays + 1] = {
			ply = ply,
			finish = CurTime() + duration,
			scale = scale,
			nextEmit = 0
		}
	end)

	hook.Add("Think", "ixToxinBloodSpray", function()
		if #activeSprays == 0 then return end

		local now = CurTime()

		for i = #activeSprays, 1, -1 do
			local spray = activeSprays[i]
			local ply = spray.ply

			if not IsValid(ply) or not ply:Alive() or now >= spray.finish then
				if spray.emitter then spray.emitter:Finish() end
				table.remove(activeSprays, i)
			elseif now >= spray.nextEmit then
				local mouthPos, mouthDir = GetMouthTransform(ply)

				spray.emitter = spray.emitter or ParticleEmitter(mouthPos, false)
				spray.emitter:SetPos(mouthPos)
				spray.nextEmit = now + math.Rand(0.05, 0.09)

				-- Heavier toxin = more droplets per puff and a slightly stronger spray
				local count = spray.scale > 0.66 and 2 or 1
				local speedMul = Lerp(spray.scale, 0.8, 1.3)

				for _ = 1, count do
					local effect = bloodParticles[math.random(#bloodParticles)]
					local part = spray.emitter:Add(effect[1], mouthPos)

					if part then
						part:SetDieTime(math.Rand(1.4, 2.2))
						part:SetStartAlpha(200)
						part:SetEndAlpha(90)

						local size = effect[2] * 0.6
						part:SetStartSize(size)
						part:SetEndSize(math.max(size - 1.5, 0))

						local dir = Vector(mouthDir.x, mouthDir.y, mouthDir.z)
						dir:Rotate(Angle(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10)))

						part:SetGravity(Vector(0, 0, -600))
						part:SetVelocity(dir * math.Rand(BLOOD.velocityMin, BLOOD.velocityMax) * speedMul)
						part:SetAngleVelocity(Angle(0, math.random(-90, 90), 0))
						part:SetAngles(Angle(0, math.random(0, 180), 90))

						part:SetCollide(true)
						part:SetCollideCallback(function(p, hitPos, normal)
							p:SetDieTime(0)

							if math.random(BLOOD.stainChance) == 1 then
								AddBloodStain(hitPos, normal)
							end
						end)
					end
				end
			end
		end
	end)

	ix.bar.Add(function()
		local status = ""
		local var = LocalPlayer():GetLocalVar("hunger", 0) * 0.01
		PLUGIN.hungerSmoothed = Lerp((FrameTime()*2),(PLUGIN.hungerSmoothed or 0),var)
		
		if var < 0.2 then
			status = "Starving"
		elseif var < 0.4 then
			status = "Hungry"
		elseif var < 0.6 then
			status = "Grumbling"
		elseif var < 0.8 then
			status = ""
		end

		return PLUGIN.hungerSmoothed, status
	end, Color(200, 149, 39), nil, "hunger")

	ix.bar.Add(function()
		local status = ""
		local var = LocalPlayer():GetLocalVar("thirst", 0) * 0.01
		PLUGIN.thirstSmoothed = Lerp((FrameTime()*2),(PLUGIN.thirstSmoothed or 0),var)

		if var < 0.2 then
			status = "Dehydrated"
		elseif var < 0.4 then
			status = "Lightly Dehydrated"
		elseif var < 0.6 then
			status = "Thirsty"
		elseif var < 0.8 then
			status = "Parched"
		end

		return PLUGIN.thirstSmoothed, status
	end, Color(0, 119, 101), nil, "thirst")

	ix.bar.Add(function()
		local status = ""
		local var = LocalPlayer():GetLocalVar("toxin", 0) * 0.01
		local toxinProtection,toxinResistance = (LocalPlayer():GetNetVar("toxinProtection", 0) > CurTime()), (LocalPlayer():GetNetVar("toxinResistance", 0) > CurTime())
		PLUGIN.toxinSmoothed = Lerp((FrameTime()*2),(PLUGIN.toxinSmoothed or 0),var)
		
		if 0.1 <= var && var < 0.25 then
			status = "Icky Feeling"
		elseif 0.25 <= var && var < 0.4 then
			status = "Coughing Fits"
		elseif 0.4 <= var && var < 0.5 then
			status = "Body Spoiling"
		elseif 0.5 <= var && var < 0.8 then
			status = "Skin Turning Green"
		elseif 0.8 <= var then
			status = "Wheezing Lungs Out"
		end
		if ((not toxinProtection) || (not toxinResistance)) then
			local txt = (toxinProtection and "Fully Protected" or (toxinResistance and "Partly Protected" or ""))
			if var < 0.1 then
				status = txt
			else
				status = (status.."   "..txt)
			end
		end
		return PLUGIN.toxinSmoothed, status
	end, Color(101, 149, 101), nil, "toxin")
end

local playerMeta = FindMetaTable("Player")

function playerMeta:GetHunger()
	local char = self:GetCharacter()

	if (char) then
		return char:GetData("hunger", 100)
	end
end

function playerMeta:GetThirst()
	local char = self:GetCharacter()

	if (char) then
		return char:GetData("thirst", 100)
	end
end

function PLUGIN:AdjustStaminaOffset(client, offset)
	if client:GetHunger() < 15 or client:GetThirst() < 20 then
		return -1
	end
end

local hunger_items = {
	["bleach"] = {
		["name"] = "Bleach",
		["model"] = "models/props_junk/garbage_plasticbottle001a.mdl",
		["desc"] = "A bottle of bleach, a common houseware product, this is a non-flammable production unit, still. Drinking it isn't a good idea.",
		["hunger"] = -50,
		["thirst"] = -50,
		["toxin"] = 50,
	},
	["beer"] = {
		["name"] = "Beer",
		["model"] = "models/props_junk/garbage_glassbottle003a.mdl",
		["desc"] = "A bottle of alcohol marketed to soothe the nerves and quench ones thirst. This is the only legal beverage sold in Astana.",
		["hunger"] = 0,
		["thirst"] = 20,
		["toxin"] = 15,
	},
	["ration1"] = {
		["name"] = "NuMeat InstaMeal",
		["model"] = "models/foodstuffs/numeat.mdl",
		["desc"] = "A government issue ration providing everything that a human being would need to eat in a single day, in short, the bare minimum, it is inexplicably cold. People spend their entire lives producing these.",
		["hunger"] = 30,
		["thirst"] = 30,
		["toxin"] = 20,
	},
		["chinafood"] = {
		["name"] = "Chinese Food",
		["model"] = "models/props_junk/garbage_takeoutcarton001a.mdl",
		["desc"] = "A paper box containing some sort of noodle and meat combination, whatever meat this is, it is chewy and tastes nothing like meat, not that you know what that tastes like anyway.",
		["hunger"] = 30,
		["thirst"] = 10,
		["toxin"] = 15,
	},
		["detox"] = {
   	 	["name"] = "De-Tox",
   	 	["model"] = "models/synapse/misc_props/synapse_medicine_bottles_1.mdl",
    	["desc"] = "A large pill bottle containing pills marketed for the removal of harmful toxins within one's body. They are highly addictive and force an incredibly uncomfortable bodily purge. Also, the pills are massive.",
    	["hunger"] = 0,
    	["thirst"] = -10,
   		["toxin"] = -15,
    	["sanityAdd"] = 20,
    	["useSound"] = "schiza/pills.mp3",
    	["useCooldown"] = 1.25,
    	["psychoTag"] = "Opioid",
    	["toleranceBuild"] = 1,
    	["addictionBuild"] = 2,
	},
	["vegetable_oil"] = {
		["name"] = "Vegetable Oil",
		["model"] = "models/props_junk/garbage_plasticbottle002a.mdl",
		["desc"] = "A bottle of vegetable oil, a common cooking product, drinking it raw isn't a good idea.",
		["hunger"] = -25,
		["thirst"] = -25,
		["toxin"] = 25,
	}
}

for k, v in pairs(hunger_items) do
	local ITEM = ix.item.Register(k, nil, false, nil, true)
	ITEM.name = v.name
	ITEM.description = v.desc
	ITEM.model = v.model
	ITEM.width = v.width or 1
	ITEM.height = v.height or 1
	ITEM.category = "SurvivalSystem"
	ITEM.hunger = v.hunger or 0
	ITEM.thirst = v.thirst or 0
	ITEM.toxin = v.toxin or 0
	ITEM.empty = v.empty or false
	function ITEM:GetDescription()
		return self.description
	end
	ITEM.functions.Consume = {
		name = "Consume",
		OnCanRun = function(item)
			if item.thirst != 0 then
				if item.player:GetCharacter():GetData("thirst", 100) >= 100 then
					return false
				end
			end
			if item.hunger != 0 then
				if item.player:GetCharacter():GetData("hunger", 100) >= 100 then
					return false
				end
			end
		end,
		OnRun = function(item)
			local hunger = item.player:GetCharacter():GetData("hunger", 100)
			local thirst = item.player:GetCharacter():GetData("thirst", 100)
			local toxin = item.player:GetCharacter():GetData("toxin", 0)
			item.player:SetHunger(hunger + item.hunger)
			item.player:SetThirst(thirst + item.thirst)
			item.player:SetToxin(toxin + item.toxin)
			item.player:EmitSound("physics/flesh/flesh_impact_hard6.wav")
			if item.empty then
				local inv = item.player:GetCharacter():GetInventory()
				inv:Add(item.empty)
			end
		end
	}
end