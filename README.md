# Adventure Plus

A co-op sandbox adventure for you and your friends: gather, build and craft like a block game, then climb any cliff, glide off any peak and fight your way through puzzles and dungeons. Built with [Godot 4](https://godotengine.org/).

The design lives in the project's design doc. This repository holds the game itself.

## Run it

1. Install **Godot 4.3 or newer** (the standard build, not .NET) from https://godotengine.org/download.
2. Open Godot, choose **Import**, and pick `project.godot` in this folder.
3. Press **F5** (or the play button) to run.

## Play it on an Android phone

The game runs on Android phones as an app. You need an APK (the Android app file), then you install it once. Later versions install over the top and keep your saved world.

**Get the APK.** Each version is attached to the pull request or sent in the project thread as `AdventurePlus.apk`. To build one yourself, see *Build the APK* below.

**Install it (one time setup, about 2 minutes):**

1. Download `AdventurePlus.apk` on the phone (for example by opening the link in Chrome, or from Google Drive).
2. Open it from the download notification, or from **Files > Downloads**.
3. Android asks whether Chrome (or Files, or Drive) may install unknown apps. Tap **Settings**, turn on **Allow from this source**, then go back.
4. Tap **Install**. If Google Play Protect warns that it doesn't recognise the app, tap **More details > Install anyway**. (It's warning because the app is your own and isn't on the Play Store.)
5. Open **Adventure Plus** from your apps. Hold the phone sideways.

**Updating:** download and install the new APK the same way. It replaces the old one and your world is kept. To start fresh, use **New world** on the pause screen.

**The Godot app on your phone** is the Godot *editor* for Android. It can open this project folder too, but it is slow for a game this size and has no on-screen joystick of its own, so the APK is the better way to play.

### Touch controls

| On screen | Action |
| --- | --- |
| Left thumb, bottom left | Move (the stick appears where you touch). Walk into a tall wall to climb it |
| Drag on the right side | Look around |
| Jump | Jump. On a wall: leap up. Hold in water to swim up |
| Glide | In the air: open the glider. Tap again to close it |
| Climb | Grab the wall you're facing, or let go |
| Sprint | Hold to sprint |
| Hit | Hold to break a block, tap to attack |
| Place | Place the selected block where the crosshair aims |
| Block | Hold to raise your shield (shows up once you have one) |
| Use | Shows up when you can talk, read, open or push. Taps also move dialogue on |
| Hotbar slots | Tap to choose |
| Map, Bag, Craft, Quest, View, II | Map, inventory, crafting, switch quest, first or third person, pause |

In the inventory, the **Tap** button switches what a tap does: move a stack, take half (or put down one), or quick-move between pack and hotbar.

On a computer with a touchscreen the same controls appear when you touch the screen, and hide again when you press a key.

### Graphics setting

The pause screen has a **Graphics** button. **High** loads 10 chunks (160 blocks) around you with anti-aliasing, grass and flowers, and every lantern light. **Phone** loads 5 chunks, turns off anti-aliasing and plant tufts, draws the 3D view at 80% resolution, uses one nearby lantern light and only nearby shadows. Phones start on Phone, computers on High, and the choice is remembered.

### Build the APK

1. In Godot, open **Editor > Manage Export Templates** and download the templates for your Godot version.
2. Install a Java JDK 17 or newer and the Android SDK (Android Studio installs it), then set both paths in **Editor > Editor Settings > Export > Android**. Godot makes a debug signing key on its own.
3. **Project > Export**, pick the **Android** preset (already in `export_presets.cfg`) and **Export Project** with *Export With Debug* on. It writes `export/AdventurePlus.apk` (64-bit ARM, the kind every recent phone uses).

From the command line: `godot --headless --export-debug Android export/AdventurePlus.apk`.

## Controls

| Key | Action |
| --- | --- |
| Mouse | Look around (the camera orbits behind your character) |
| W A S D | Move. Walk into a tall wall to climb it |
| Space | Jump. In the air: open or close the glider. On a wall: leap up |
| Shift | Sprint. On a wall or glider: let go |
| Left click | Hold to break a block, click to attack |
| Right click | Place the selected block. With anything else in hand (a sword, nothing), hold to raise your shield |
| X | Hold to raise your shield, whatever you hold |
| M | Map: drag to move around, scroll to zoom, M or Esc to close |
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

**Map.** Press **M** (or **Map** on a phone) for a map that fills in as you explore. Everything within about 40 blocks of you is drawn from above as you go, in the colours of the ground (grass, sand, snow, stone, trees, water shaded by depth, hills with light and shadow); places you have never been stay dark. Climb or glide high and you see further (up to 70 blocks); underground you only map what is close. It marks you (an arrow pointing the way you face), the camp, your quest's next stop, and places you've found: the Windworn Hollow, the Hearthroot Shrine, Needle Rock and Wren. Drag to look around, scroll or pinch to zoom, and **Find me** jumps back to you. The explored map is saved with your world, chunk by chunk, so the endless wild lands only cost what you've seen.

**Shields.** Make a **Wooden Shield** (5 planks, 1 stick) or an **Iron Shield** (3 iron ingots, 2 planks) at a workbench. A shield works from anywhere in your inventory (the best one is used) and is worn on your back. Hold **right click** (with a sword or empty hand; with a block in hand right click still places it), **X**, or **Block** on a phone to raise it: you turn to face where the camera looks and walk at half speed, and can't attack or sprint. Hits from the front are blocked: no heart lost, the Thornling bounces back, and it costs stamina instead (22 for wood, 11 for iron). Raise the shield just as a hit lands (within 0.3 seconds) for a **perfect block**: it costs nothing and stuns the Thornling for a moment, a good time to strike. Hits from the side or behind still get through, and if a block costs more stamina than you have, your guard breaks. New side goals: block a Thornling, and land a perfect block.

**Compass and icons.** A compass strip at the top of the screen shows which way you face, with a white marker for camp and a gold marker for your tracked quest's next stop. In the hotbar, inventory and crafting list, blocks and block items are 3D pictures rendered from their real models (a lantern looks like a lantern, a workbench like a workbench), and tools and materials are pixel-art sprites.

**How things look.** Every block has a painted 16 by 16 pixel texture: grass with a green fringe over dirt, stone with cracks, bark and tree rings, planks, bricks, thatch, ores with coloured flecks (Sunstone's glow), snowy and dry grass, Loomwright stone and more. Lanterns, chests, workbenches, spring pads, flags, the riddle tablet, cacti and the Sky Shard are drawn as small models instead of cubes (they still fill their block for walking and climbing). Whatever you hold is shown in the hero's hand as its 3D model: blocks in the palm, a lantern carried by its handle, and swords, picks and other items as thick pixel-art shapes. Breaking a block pops its item out, and it flies to you. Meadows grow grass tufts, ferns and flowers that sway in the wind (dry tufts on the Steppes, dead bushes on sand); they are only for looks and never get in your way. The sky has a soft gradient, a square sun and drifting blocky clouds, the water ripples and glints, and the hero, Bryn, Wren and the Thornlings have faces, belts, boots, gear and soft shadows under their feet.

**Lantern light.** A lantern lights the blocks around it: light spreads about 10 blocks, fades with distance, bends around corners into tunnels but never shines through rock. Caves are now properly dark, so bring lanterns. The light is worked out once when a lantern is placed (or a block near one changes) and stored in the world's shape, so dozens of lanterns cost nothing per frame, and because lanterns are blocks it all comes back when you load a save. The hero, villagers and Thornlings near a lantern are lit by it too, and holding a lantern lights the area around you as you walk. The camp has lanterns by Bryn's door and one hanging inside.

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
| `scripts/art.gd` | How things look: paints the block textures, the block models (lanterns, chests...), item models and the terrain, item, water and sky shaders |
| `scripts/audio.gd` | Sound effects, ambience and music with cross-fades |
| `scripts/hud.gd` | Hearts, stamina, hotbar, quest panel, dialogue, banners, toasts and menus |
| `scripts/map.gd` | The map: paints explored columns into per-chunk pictures, saves them, and draws the map screen |
| `scripts/touch.gd` | On-screen controls for phones: move stick, look drag and buttons, with every finger tracked |
| `export_presets.cfg` | The Android export (signed debug APK, 64-bit ARM, landscape) |
| `assets/audio/` | Generated sounds and music (CC0) |
| `tools/make_audio.py` | Regenerates every sound |
| `tests/playtest.gd` | Scripted playthrough of every quest with checks and screenshots |
| `tests/underground.gd` | Checks saving and loading (island and wild edits, inventory, quests, puzzles), caves, ores, smelting and New world |
| `tests/visuals.gd` | Checks item models and icons, lantern light in a cave (and after saving and loading, and with many lanterns), and takes screenshots of the scenery and characters |
| `tests/touch.gd` | Sends pretend finger touches: stick, look, every button, hotbar taps, inventory tap modes, phone graphics, and screenshots at a phone's shape |
| `tests/map_shield.gd` | Checks the map filling in, opening and zooming, the shield recipe, blocking from the front only, perfect blocks, the guard breaking, the Map and Block buttons, and both surviving a save |
| `tests/wild.gd` | Checks the wild lands: every biome appears, chunks stream in fast enough to glide, edits survive leaving, ruins have chests |
| `prototype/web/index.html` | The original browser prototype, kept for reference |

## Next steps

1. Two-player networked movement (co-op)
2. Light from lanterns and torches underground, and cave creatures
3. A Steppes enemy and a boss for the Hollow
4. More shrines and field puzzles, and day and night
