# Sanny Doo: project guide for AI build partners

Read this first. Sanny Doo is a 2D flying game a dad is making with his son Sam.
Sam drew the hero (Sanny Doo) and the first area (his house with trees). The game
must keep looking like Sam's drawings: dark pen lines on paper, a bit wobbly, light
crayon color only inside shapes.

- **Engine:** Godot 4.7 (4.7.2 at `/Applications/Godot.app`), same as the sibling `frog-hopper` project.
- **Language:** GDScript. Feel values are commented constants at the top of each script.
- **Renderer:** GL Compatibility; Web export preset has threads off (runs on any static host).
- **Design doc:** `docs/game-design.md` (what is in the game and the assumptions made).

## How we work

- Personal repo. **Commits go straight to `main`, no pull requests** (decided 2026-11-21). An AI session works in `.worktrees/<name>`, rebases onto `origin/main`, pushes with `git push origin <branch>:main`, then removes the worktree folder and branch. An AI session works in `.worktrees/<name>`, rebases onto `origin/main`, pushes with `git push origin <branch>:main`, then removes the worktree folder and branch.
- The AI writes `.gd`, `.tscn` and `project.godot` directly. The human opens the project in Godot, presses **F5**, and playtests with Sam.
- Almost everything is built in code: scenes are a single root node with a script. Entities (monsters, spikes, coins) are plain `Node2D` scripts created with `preload(...).new()`.
- Scripts reference each other with `const X = preload("res://scripts/x.gd")`, not `class_name`, so the game runs without an editor-built class cache.
- Cross-object references (`level`, `player`) are untyped on purpose, so calls like `level.fx_text()` compile.

## Where things live

| Path | What |
|---|---|
| `assets/source/` | Sam's original photos. Never edit; the art is regenerated from these. |
| `assets/art/` | Ink cut out of the photos (Sanny body, two wings, the house) |
| `tools/extract_ink.gd` | Rebuilds `assets/art/` from the photos (run it after adding a new drawing) |
| `scripts/ink.gd` | The pen-drawing helpers every other visual uses (wobbly lines, circles, faces, Sam-style trees) |
| `scripts/game.gd` | Autoload: save data, shop prices, weapons, armor, spells, the level list, controls |
| `scripts/music.gd` | Autoload: songs made from math, plus the beat clock (rhythm features) |
| `scripts/sfx.gd` | Autoload: sound effects made from math |
| `scripts/level.gd` | Builds and runs a level from `Game.LEVELS`; collisions; boss start |
| `scripts/player.gd` | Sanny: both flying styles, shooting, magic, getting hurt |
| `scripts/touch_controls.gd` | Phone/tablet controls (slide-to-fly stick, SHOOT/FLAP buttons, tap magic boxes, pause); shown only on touch screens |
| `scripts/smoke.gd` | Automated playthrough and screenshots (see below) |

## Adding a new drawing from Sam

Photo it on plain paper, copy it to `assets/source/`, add a function in
`tools/extract_ink.gd` like `_extract_house`, then run:

```
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tools/extract_ink.gd
```

## Verifying changes

1. **Automated playthrough** (headless, about 15 seconds): buys every upgrade, flies all
   5 levels on autopilot casting every spell, beats the boss, saves and reloads.
   ```
   "/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --import
   "/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --fixed-fps 60 -- --smoke
   ```
   Must print `SMOKE PASS`. It uses its own save file, so it never touches Sam's save.
2. **Screenshots** (opens a window for a few seconds). Add `--touch` to show the phone controls, or `--touchcheck` (with `--resolution 800x450` before `--`) to test touch input in a window smaller than the game:
   `"/Applications/Godot.app/Contents/MacOS/Godot" --path . -- --shots --out=<folder>`
3. **Playing it.** Nothing automated checks whether flying feels good or whether Sam
   likes it. That is the real test.

## Web export

Same as frog-hopper: `mkdir -p build/web`, then
`"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --export-release "Web" build/web/index.html`.
`assets/source/` and `tools/` are excluded from the export. (Export ran cleanly on 2026-11-21; the exported build has not yet been played in a browser.)
