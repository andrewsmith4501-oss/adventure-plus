# Audio credits and license

Every sound effect, ambient loop and music track in this folder was synthesised
from scratch by [`tools/make_audio.py`](../../tools/make_audio.py) using numpy.
No samples, recordings or third-party sound libraries were used.

**License: CC0 1.0 (public domain).** You may use, change and share these files
for any purpose without asking or giving credit.

To change a sound, edit its function in `tools/make_audio.py` and run:

```
python3 tools/make_audio.py            # everything
python3 tools/make_audio.py music      # or just sfx, ambience, music
```

It needs Python 3 with numpy, and ffmpeg built with libvorbis.

| Group | Files |
| --- | --- |
| Movement | step_grass, step_stone, step_wood, jump, land, splash, glider_open, glider_close |
| Blocks | hit_block, break_soft, break_stone, break_wood, break_leaves, break_glass, place, vent_place |
| Combat | swing, enemy_hit, enemy_defeat, enemy_hop, hurt |
| Quest and puzzles | goal, quest, plate_on, plate_off, door, node, talk1-3, craft, pickup, deny, ui_click |
| Wind | gust, gust_warn, glide_wind (loop), vent_loop (loop) |
| Ambience (loops) | amb_meadow, amb_steppes, amb_hollow |
| Music (loops) | music_hearthvale, music_steppes, music_hollow |
