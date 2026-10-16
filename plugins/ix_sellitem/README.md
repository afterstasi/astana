# Item Sell Stands (Helix Plugin)

Right click any item in your inventory and a **Sell** option appears. Picking it:

1. Asks you to set a price (simple popup with a number field).
2. Drops you into a placement mode: a translucent "ghost" of the item follows
   your crosshair so you can see exactly where it'll land.
   - **Q / E** — rotate the ghost
   - **Left Click** — place it (only works while the ghost is "valid" / green)
   - **Right Click** — cancel and keep the item in your inventory
3. The item disappears from your inventory and a physical stand appears in
   the world, with the item's **name and price floating above the front of
   the model**.
4. Anyone else who walks up and presses **E** gets a **Yes / No** purchase
   prompt. Confirming charges their character and gives them the item;
   you get paid automatically if you're still online.
5. Press **E** on your own stand to pick it back up at any time.
6. **Not persistent** — if you disconnect while a stand is still up unsold,
   it's instantly removed and the item is placed back in your inventory
   before you fully leave. Nothing is left behind on the map.

## Installation

1. Drop the `ix_sellitem` folder into your schema's (or `helix/`) `plugins/`
   directory, so you end up with:
   ```
   plugins/ix_sellitem/plugin.lua
   plugins/ix_sellitem/sh_sellitem.lua
   plugins/ix_sellitem/sv_sellitem.lua
   plugins/ix_sellitem/cl_sellitem.lua
   plugins/ix_sellitem/entities/entities/ix_sellitem/...
   ```
2. Enable it the way you enable any other Helix plugin (it loads
   automatically if it's just sitting in `plugins/`, or via
   `ix.plugin.Load("ix_sellitem")` if your schema loads plugins by name).
3. Restart the server / `changelevel` the map.

No database/SQL changes are required — stands are entirely in-memory and
clean up on their own, which is what gives you the "not persistent"
behavior for free.

## Configuration

Open `plugin.lua` and edit the top of the file:

```lua
PLUGIN.maxSellDistance = 96     -- how far from yourself you can place a stand
PLUGIN.interactDistance = 150   -- how close someone must be to buy/use a stand
PLUGIN.maxPrice = 1000000       -- price ceiling
```

To stop a specific item from ever being sellable (quest items, keys, etc.),
add this to that item's file:

```lua
ITEM.NoSell = true
```

(Items already flagged `ITEM.NoDrop = true` are automatically excluded too,
since something that can't be dropped shouldn't be sellable either.)

## How it fits together

- **`plugin.lua`** — boilerplate, config, language strings, font registration.
- **`sv_sellitem.lua`** — injects the `Sell` action into every item
  (`PLUGIN:InitializedItems`), handles the net messages for starting a sale,
  finalizing placement, buying, and the disconnect-return safety net.
- **`cl_sellitem.lua`** — the price dialog, the ghost/placement controller
  (Q/E rotation, click-to-place), and the Yes/No buy popup.
- **`entities/entities/ix_sellitem/`** — the actual world entity for a
  listed item. Server side holds the real item data (`uniqueID` + full data
  table) needed to recreate it; only display info (name/price/seller) is
  networked to clients. Client side just draws the model plus a 3D2D
  name/price tag in front of it.

## Known limitations / things to double check on your build

- This assumes the common Helix conventions: `item.player`, `item:GetID()`,
  `ix.item.instances`, `inventory:Add/Remove`, `character:GetMoney()` /
  `:SetMoney()`, `client:NotifyLocalized()`, and the `InitializedItems` /
  `KeyPress` / `LoadFonts` plugin hooks. These are stable across recent
  Helix versions, but if your fork has renamed anything, you'll need to
  adjust the corresponding calls.
- `inventory:Add()` is treated as possibly returning a "deferred" promise
  (Helix's usual pattern) — the code handles both that and a plain
  synchronous return, so it should work either way.
- Items inside nested/bag inventories aren't specifically handled — selling
  pulls from whatever inventory the item currently reports as its owner's
  via `item.player`/`item.invID`. If your schema has bags-within-bags, test
  that flow before relying on it.
- The ghost uses the `models/wireframe` material layered under a translucent
  tint for the "see exactly where it'll go" effect. If that material isn't
  present in your mounted content, the tint alone still clearly reads as a
  placement ghost (green = valid spot, red = invalid).
- Position/distance are re-validated server side when placing and when
  buying, but this isn't a full anti-exploit suite (no swept collision
  checks, no rate limiting beyond the buy-prompt throttle). Fine for normal
  roleplay use; harden further if you expect adversarial players.
