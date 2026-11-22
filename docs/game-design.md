# Sanny Doo: game design (first build, 2026-11-21)

The first build makes lots of assumptions on purpose so Sam can play it and react.
Everything below is a starting point to change after playtesting.

## The game in one line

Sanny Doo flies with his wings through side-scrolling levels full of spikes and
monsters, collects coins, buys better weapons and armor, learns magic, and beats
King Grumble at the end.

## Flying (two styles, pick on the title screen or in the pause menu)

| Style | Controls | Feel |
|---|---|---|
| Free Fly (default) | Arrows/WASD fly in any direction; Space or X shoots | Easier; good for younger players |
| Flappy | Space or Up flaps, gravity pulls down; left/right moves; X shoots | Harder, more skill |

On phones and tablets: slide your left thumb anywhere on the left side to fly, hold SHOOT on the right (Flappy adds a FLAP button), tap the magic boxes to cast, and the || button pauses. Holding the phone upright shows "Turn your phone sideways".

The screen scrolls right by itself. Ground is safe to touch; spikes and monsters are not.

## Levels

| # | Name | New things |
|---|---|---|
| 1 | Home Sweet Home | Starts at Sam's house drawing. Blobs, ground spikes, spike balls |
| 2 | Tall Tree Forest | Thorny towers with a gap to fly through, bats |
| 3 | Spiky Caves | Ceiling spikes, spitters that shoot ink |
| 4 | Stormy Sky | Beat-spikes that pop up on the music's beat, spiky monsters |
| 5 | King Grumble's Castle | Boss fight with 3 phases; he attacks on the beat |

Each level has a checkpoint halfway. Dying keeps your coins and restarts at the checkpoint.

## Getting stronger (RPG parts)

- **Coins** buy upgrades at the house shop: 4 weapons (Pencil Darts, Ink Blaster, Star Wand, Thunder Pen), 3 armors (Cardboard, Pot Helmet, Knight), 3 Heart Jars, 2 Magic Jars.
- **XP** from monsters raises Sanny's level: more magic each level, +1 heart every 2 levels, +1 damage every 3 levels.
- **Magic** is learned by finishing levels, cast with keys 1 to 4, and uses magic points that refill slowly:

| Key | Magic | Learned after | Does |
|---|---|---|---|
| 1 | Heal | Level 1 | +2 hearts |
| 2 | Poison Cloud | Level 2 | Green cloud that poisons monsters |
| 3 | Teleport | Level 3 | Zap ahead, briefly safe |
| 4 | Flood | Level 4 | Wave that hurts every monster and washes away spike balls |

## Rhythm parts (small, not a rhythm game)

- Every level has a looping song; a beat circle at the top pops on each beat.
- A shot tapped right on the beat does double damage, refills a little magic, and every 4 in a row gives a coin.
- Beat-spikes (level 4 and the castle) go up and down with the beat.
- King Grumble attacks on the beat, so listening helps dodging.

## Art

- Sanny Doo and the house are Sam's actual drawings, cut out of the photos by `tools/extract_ink.gd`. Sanny's wings are separate pieces so they flap.
- Everything else (monsters, spikes, coins, buttons) is drawn in code with wobbly pen lines in the same style, with faces like Sam's (oval eyes, big open mouth).
- Assumption to check: Sam's drawings are pen only, but monsters, coins, hearts and the boss get light crayon-color fills so a child can tell them apart at a glance. Easy to switch to pen only.
- Font: Patrick Hand (SIL Open Font License, `assets/fonts/OFL.txt`).

## Open questions for after the first playtest

- Which flying style does Sam like? Should the other one go away?
- Is it too hard or too easy? (Scroll speed, monster health and boss health are numbers in `scripts/game.gd`.)
- What should King Grumble and the other monsters look like? Sam could draw them, and they can be cut out like Sanny.
- More rhythm, less, or about right?
