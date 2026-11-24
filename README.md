# Adventure Plus

A co-op sandbox adventure for you and your friends: gather, build and craft like a block game, then climb any cliff, glide off any peak and fight your way through puzzles and dungeons. Built with [Godot 4](https://godotengine.org/).

The design lives in the project's design doc. This repository holds the game itself.

## Run it

1. Install **Godot 4.3 or newer** (the standard build, not .NET) from https://godotengine.org/download.
2. Open Godot, choose **Import**, and pick `project.godot` in this folder.
3. Press **F5** (or the play button) to run.

## Controls

| Key | Action |
| --- | --- |
| Mouse | Look around (the camera orbits behind your character) |
| W A S D | Move. Walk into a tall wall to climb it |
| Space | Jump. In the air: open or close the glider. On a wall: leap up |
| Shift | Sprint. On a wall or glider: let go |
| Left click | Hold to break a block, click to attack |
| Right click | Place the selected block |
| 1 to 9, mouse wheel | Choose a hotbar slot |
| F | Talk, read a tablet, use a Thread Node, open a chest, push a crate (also advances dialogue) |
| C | Crafting (some recipes need a workbench nearby) |
| E or I | Inventory: a 27-slot pack plus the hotbar. Click to move stacks, right-click to split, shift-click to swap between pack and hotbar, and a bin to throw things away |
| Q | Switch which quest is shown on screen |
| V | Switch between third and first person |
| Esc | Pause (music and sound volume are on the pause screen). Pausing also saves |

## What's in the game

**Hearthvale.** The starting valley: meadows, a river, low terraced cliffs and a camp where Bryn, an old Loomwright scholar, gives you the first quest.

**Gale Steppes.** A high windswept plateau behind a cliff wall, with mesas, Needle Rock (the Sky Shard sits on top) and pale blue Skyglass to mine. Gusts sweep across it every so often: you hear a whistle first, then the wind shoves you and drains stamina while you climb.

**The Windworn Hollow.** The first small dungeon, built into the great mesa. Its walls are Loomstone, which can't be mined or climbed. A sealed door needs weight on two pressure plates at once, then a tall wind shaft needs you to ride an updraft vent with your glider up to the Thread Node. Restoring the Node opens the roof so the wind carries you out.

**Quest: The Stilled Wind.** Talk to Bryn, craft a Leaf Glider, climb into the Steppes, find and solve the Hollow, and return. The reward is the Updraft Vent: a block you craft from stone and Skyglass and place anywhere to make your own glide routes. Side goals: defeat a Thornling, take the Sky Shard, glide far, build a vent.

**Wren and the bridge.** Wren, a tinkerer, is stuck with a cart by the river north-east of camp. Build a dry bridge across the river near the two red flag posts (any blocks and any height, as long as each step is at most one block) and Wren crosses it, moves to camp and sets up a workbench. The reward is the recipes for ladders and spring pads.

**Workbench and new blocks.** Craft a workbench from 4 planks. Standing near one unlocks Stone Bricks, Thatch and Lanterns, and after Wren's quest, Ladders (climb without using stamina, and they stick to anything, even Loomstone) and Spring Pads (step on one to be flung about six blocks up; open your glider at the top).

**The Hearthroot Shrine.** A Loomwright shrine built into the hills south-east of camp, across the river. Three rooms: push a crate onto a heavy plate, then get two crates onto two plates in the crate hall (a tablet slides the crates back if one gets stuck), then build your way up a smooth Loomstone ledge to restore the Thread Node. The reward is a Stamina Vessel (a bigger stamina ring).

**Lost caches.** Five chests hidden around the island, with riddles on a tablet by the camp fire: on a lonely mesa, on a meadow floating above the cliffs (you'll need vents or spring pads), in a glowing cave under the western hills, on the far south-east mesa and on the northern beach. They hold materials plus a Heart Vessel (one more heart) and Gale Wings (a faster glider that sinks more slowly).

**The wild lands.** The island is no longer the edge of the world. Past a short stretch of sea (swim, glide or build a bridge) an endless world goes on in every direction, the same every game because it comes from a fixed seed. It is made of biomes, each with its own name banner and music: the Open Sea, Sunmeadow Plains, Bramblewood forests, the Amber Dunes (cacti and Skyglass), the Rustrock Badlands (striped clay cliffs), the Frostpine Wilds (snowy pine woods) and the Frostspine Peaks (mountains with snow caps). Out there you'll find Loomwright ruins and watchtowers, and floating isles to glide up to, each with a chest of building materials. New blocks: Snow, Clay and Cactus. The world loads in 16 by 16 chunks on background threads as you travel, about 160 blocks around you, and anything you build or dig out there is kept when you walk away. Thornlings follow you out, too. Use the compass's Camp marker to find your way home.

**Saving.** Your world saves itself: every 45 seconds while you play, whenever you pause, and when you close the game window. Next time you start, the button says **Continue** and you pick up right where you were, with every block you placed or dug (on the island and out in the wild lands), your inventory, hearts, stamina, wings, quests, caches and puzzle doors as you left them. **New world** on the start or pause screen erases the save and starts over (it asks twice). Only what you change is saved, so the file stays small; the rest of the world grows back from its seed. On Windows the save is in `%APPDATA%\Godot\app_userdata\Adventure Plus\world.save`.

**Caves and ores.** The hills and mountains of the wild lands are riddled with caves: winding tunnels that break out on hillsides and, deeper in, wide caverns. They always stay above the sea, so they are dry. Underground spaces are shaded darker the lower their roof, so caves feel like caves (the Hollow and the shrine keep their light). The stone holds ore, drawn as stone with coloured flecks: **coal** in clumps near the surface, **iron ore** a little deeper (needs a Stone Pick), and rare glowing **Sunstone** deep under hills and mountains (needs an Iron Pick). Ore is in the island's stone too. Build a **Furnace** (8 stone, at a workbench), smelt **Iron Ingots** there from iron ore and coal, then forge an **Iron Pick** (mines everything much faster), an **Iron Sword** (4 damage) and a **Sunstone Sword** (6 damage). Coal and a stick also make lanterns. New side goals: find a cave, smelt iron, forge an Iron Pick, mine Sunstone.

**Compass and icons.** A compass strip at the top of the screen shows which way you face, with a white marker for camp and a gold marker for your tracked quest's next stop. Tools and items in the hotbar, inventory and crafting list are drawn as little pixel-art sprites (swords, pick, stick, glider, Sky Shard), and blocks as small cubes.

**Audio.** Footsteps that match the ground, block, combat, glider, puzzle and quest sounds, ambience for each area and a music track for Hearthvale, the Steppes, the Hollow and the shrine. Everything is generated by `tools/make_audio.py` and released as CC0; see [assets/audio/CREDITS.md](assets/audio/CREDITS.md).

## Project layout

| Path | What it is |
| --- | --- |
| `main.tscn` | Entry scene; everything else is built from code for now |
| `scripts/game.gd` | Sets up the scene; items, crafting, quests, dialogue, the Hollow and shrine puzzles, chests, gusts, vents, block interaction, mining and saving |
| `scripts/world.gd` | Voxel data, Hearthvale and Gale Steppes terrain, the Hollow, the shrine, the ford, the floating isle, the cave, the endless wild lands (biomes, ruins, caves and ores, chunk streaming on worker threads), saved edits, chunk meshes, collision and raycasts |
| `scripts/player.gd` | The hero: movement, climbing, gliding, updrafts, footsteps, animation and the camera |
| `scripts/npc.gd` | Bryn and Wren |
| `scripts/thornling.gd` | The Thornling enemy |
| `scripts/audio.gd` | Sound effects, ambience and music with cross-fades |
| `scripts/hud.gd` | Hearts, stamina, hotbar, quest panel, dialogue, banners, toasts and menus |
| `assets/audio/` | Generated sounds and music (CC0) |
| `tools/make_audio.py` | Regenerates every sound |
| `tests/playtest.gd` | Scripted playthrough of every quest with checks and screenshots |
| `tests/underground.gd` | Checks saving and loading (island and wild edits, inventory, quests, puzzles), caves, ores, smelting and New world |
| `tests/wild.gd` | Checks the wild lands: every biome appears, chunks stream in fast enough to glide, edits survive leaving, ruins have chests |
| `prototype/web/index.html` | The original browser prototype, kept for reference |

## Next steps

1. Two-player networked movement (co-op)
2. Light from lanterns and torches underground, and cave creatures
3. A Steppes enemy and a boss for the Hollow
4. More shrines and field puzzles, and day and night
