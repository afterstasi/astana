========================================
Looting System for Helix Framework (HL2RP)
========================================

Author: Frytek
Version: 1.0

----------------------------------------
1) Description
----------------------------------------
Looting System allows admins to place persistent loot containers in the world,
editable entirely in-game. Each container has customizable name, description,
model, tool requirements, respawn time, and loot tables with weighted chances.

Players can interact with containers by pressing USE. If conditions are met
(minimum nearby players, required tool, global player threshold), they begin
a timed search action. At completion, items are spawned from the configured
loot table, the container hides, and reappears after its cooldown.

Features:
• Context menu integration (C → RMB):
  – Edit Loot
  – Copy Loot Settings
  – Paste Loot Settings
• Visual editors for container data and loot tables
• Model browser (spawnmenu-style) with search & live preview
• Helix item browser for required tools
• Auto-save every 60 seconds + manual save/load/remove
• Persisted state: position, angles, frozen physics, lootData

----------------------------------------
2) Requirements
----------------------------------------
• Helix Framework (HL2RP branch recommended)
• Content: base HL2 props/items, or any mounted content packs

----------------------------------------
3) Installation
----------------------------------------
1. Drop the `looting` folder into `gamemodes/ixhl2rp/plugins/`.
2. Restart the server.
3. Plugin auto-loads.

File layout:
• sh_plugin.lua         – shared setup, context menu, commands
• sv_plugin.lua         – saving/loading logic, autosave, networking
• cl_plugin.lua         – client helpers
• cl_looteditor.lua     – container editor GUI
• cl_loottable.lua      – loot table editor GUI
• entities/entities/ix_custom_loot/*
  – shared.lua, init.lua, cl_init.lua (entity definition)

----------------------------------------
4) Gameplay Rules
----------------------------------------
Global restriction
• `LootingMinPlayersGlobal` – config option (default 0). Minimum online
  players required globally for looting to be possible.

Per-container restriction
• Minimum Players Nearby – set per container. Requires at least N other
  players within ~300 units to allow looting.

Tool requirement
• Optional. If set, the looter must have the specified Helix item uniqueID
  in their inventory.

Looting
• Interact with E. If requirements are met:
  – Progress bar runs for Loot Time
  – At completion, N items are drawn from weighted loot table
  – Items spawn in-world slightly above the container
  – Container hides, becomes non-solid, and reappears after Reset Time

----------------------------------------
5) Editing Containers (Admin)
----------------------------------------
Context Menu (recommended)
• Look at container → hold C → RMB → Edit Loot
• Copy Loot Settings → copies this container’s config
• Paste Loot Settings → pastes onto another container

Commands
• /EditLootEntity – edit entity aimed at
• /SaveAllLoot    – force save now
• /LoadAllLoot    – reload saved containers
• /RemoveLootTarget – delete aimed container + remove from saves

----------------------------------------
6) The Editor
----------------------------------------
Fields:
• Display Name       – floating name
• Description        – floating subtitle
• Model              – 3D model (… button opens model browser)
• Required Tool      – uniqueID of item needed to loot (… opens item browser)
• Respawn Time       – cooldown before reappearing
• Minimum Players Nearby – players required within ~300 units
• Items to Spawn     – number of items given per search
• Search Time        – action duration

Loot Table Editor
• Slider per item (0–100)
• Higher values = higher probability
• Spawn picks are weighted

----------------------------------------
7) Persistence
----------------------------------------
Auto-save
• Every 60 seconds, containers are saved to data store.

Manual
• /SaveAllLoot, /LoadAllLoot, /RemoveLootTarget

On shutdown
• Containers are auto-saved.

What is saved?
• Position, angles, frozen state, model, lootData, loot table

----------------------------------------
8) Configuration (Helix)
----------------------------------------
LootingMinPlayersGlobal
• Default: 0
• Minimum online players required for looting system-wide.

----------------------------------------
9) Networking (reference)
----------------------------------------
• ixLootEditorOpen     (sv→cl) – open editor GUI
• ixLootSaveData       (cl→sv) – save container data
• ixLootTableEditor    (sv→cl) – open loot table GUI
• ixLootTableSave      (cl→sv) – save loot table

----------------------------------------
10) License & Credits
----------------------------------------
Code
• by Frytek, all rights reserved for addon use

----------------------------------------
11) Notes & Support
----------------------------------------
• Containers spawn under Entities → Looting → Loot Container
• Frozen with physgun remain frozen across saves
• Model browser may show only mounted content
• Item browser uses ix.item.list, ensure your schema defines items
• Report issues with Helix version, map, and console errors

Enjoy!
