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
| C | Crafting |
| V | Switch between third and first person |
| Esc | Pause |

## What's in this first version

A port of the browser prototype everyone liked:

- A 96 x 96 voxel island with a tall cliff and a glowing Sky Shard on top
- Hold-to-break and place blocks, with a 9-slot hotbar
- Crafting: planks, sticks, wooden sword, stone pick, stone sword and a Leaf Glider
- Climbing any wall with a stamina ring, mantling over ledges and leaping up walls
- Gliding, swimming and fall damage
- Thornlings, hopping enemies that chase you, plus melee combat
- A short list of island goals that walks through the whole loop

## Project layout

| Path | What it is |
| --- | --- |
| `main.tscn` | Entry scene; everything else is built from code for now |
| `scripts/game.gd` | Sets up the scene, items, crafting, goals and block interaction |
| `scripts/world.gd` | Voxel data, terrain generation, chunk meshes, collision and raycasts |
| `scripts/player.gd` | The hero: movement, climbing, gliding, animation and the camera |
| `scripts/thornling.gd` | The Thornling enemy |
| `scripts/hud.gd` | Hearts, stamina, hotbar, goals, toasts and menus |
| `prototype/web/index.html` | The original browser prototype, kept for reference |

## Next steps

1. Two-player networked movement (co-op)
2. A bigger Hearthvale starting area
3. The first Gale Steppes dungeon
