# WirtWare

Rapid-fire microgames in the style of WarioWare, made with Godot 4.7.

Each microgame lasts a few seconds. You see a one-word prompt, then you have to work out what to do before the fuse runs out. Win to score, lose to drop a heart. Between games, Wirt (the host, a kid in a floppy cone hat) reacts to how you did.

A run has three stages. Each stage is 10 microgames and then a boss. Every 4 wins within a stage the game speeds up. Beating a boss is worth 5 points and gives a heart back. Losing to a boss costs a heart, and you fight it again. After the third boss the run loops back to stage one, faster and at full difficulty.

| Stage | Look borrowed from | Boss | Boss fight |
| --- | --- | --- | --- |
| 1 Graveyard Shift | 8 Bit Evil Returns | Mr Hat | Left/right as Jon, who fires stakes on his own. Dodge top-hat tornadoes and, later, diving bats |
| 2 Tlaloc's Temple | Tlaloc's Curse | Tlaloc | Breakout against his stone face. Rain and darts come in the angry phase |
| 3 Snail Lord's Swamp | 8 Bit Evil Returns + Hemlock's Tower | Snail Lord | Tap the goo, crows and toads before they crack the screen. Tap him when he comes out of his shell |

Difficulty is 1 in stage one, 2 in stage two and 3 in stage three and every later lap.

## Controls

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Move | Arrow keys / WASD | D-pad / left stick | On-screen arrows |
| Action | Space / Z / Enter | A | On-screen A button |
| Pointer games | Mouse | — | Finger |

WirtWare is portrait-first: the game is a 720×1280 (9:16) canvas, laid out for a phone held upright. On phones, each microgame shows only the buttons it needs, along the bottom edge. On tall phones they sit in the spare space under the game. On shorter ones they float over the game's floor.

## Microgames

Most microgames change their look per stage, using the stage's art.

| Prompt | Folder | What you do |
| --- | --- | --- |
| DODGE! | `dodge` | Move left and right to avoid falling things until time runs out |
| PUMP IT! | `pump` | Mash the action button to blow something up until it pops |
| CATCH! | `catch` | Slide the basket under the falling treat |
| STOP! | `stop` | Press the button while the needle is in the glowing zone |
| POP 'EM! | `pop` | Tap every ghost / spirit / wisp |
| JUMP! | `jump` | Jump over the obstacles |
| COPY! | `copy` | Press the arrow sequence shown, in order |
| DRAW! | `duel` | Wait for "FIRE!", then shoot. Too early or too late loses |
| LAND! | `land` | Hold the button to brake, and touch down slowly |
| SORT! | `sort` | Send each item to its bin |
| WHACK! | `whack` | Press the arrow that matches the hole something pops out of. A wrong swing loses |
| SCRUB! | `scrub` | Hold and scrub the grime off |
| SLICE! | `slice` | Swipe through everything before it falls |
| TRACE! | `trace` | Drag along a wiggly path from start to finish without leaving it |
| FLICK! | `flick` | Flick the ball into the target. One shot |
| FEED! | `feed` | Drag each snack into the mouth |
| WIND IT! | `crank` | Spin your finger around the crank until the box pops |
| FOLLOW! | `follow` | Keep your finger on the wandering light until time runs out |
| SWIPE! | `swipe` | Swipe the way each arrow points. Red arrows mean the opposite way |

New ones, each a nod to another game in the Scareathon arcade:

| Prompt | Folder | Homage to | What you do |
| --- | --- | --- | --- |
| LEAP! | `leap` | Salmon Run 2 | Time the button to leap a salmon up the waterfall steps |
| CARVE! | `carve` | Jack O'Lantern | Drag along the dotted face to carve the pumpkin |
| PET IT! | `pet` | Cryptlins | Rub the gremlin, but stop when it bares its teeth |
| GLIDE! | `glide` | Daughter Of The Wind | Steer the glider through the gaps in the clouds |
| BLAST! | `blast` | Denver Vs The Universe | Shoot the saucer before it abducts a building. Shots are limited |
| SLIDE! | `slide` | Penguin Slide | Steer the penguin through the slalom gates |
| JAM! | `jam` | One Man Band | Hit the button on each note |
| PHONE HOME! | `phone` | Phone Home | Mash to pedal until the bike lifts off past the moon |
| SHAKE! | `shake` | Snow Globe | Rub back and forth to shake the snow up |
| CLIMB! | `climb` | Hemlock's Tower | Alternate left and right to climb the tower |

## Project layout

```
scenes/main.tscn            Entry scene (just runs scripts/main.gd)
scripts/main.gd             Game loop: stages, bosses, intermissions, speed-ups, lives, best score
scripts/stages.gd           The three stages: names, colours, art folder, boss
scripts/microgame.gd        `Microgame` base class that every game and boss extends
scripts/microgame_fx.gd     Sparks and floating words drawn over a microgame
scripts/mascot.gd           Wirt, the host, drawn and animated in code
scripts/backdrop.gd         The between-games scene for each stage
scripts/sfx.gd              Sfx autoload: sound effects, jingles and stage music, made in code
scripts/hearts.gd           Lives display
scripts/touch_controls.gd   On-screen buttons for phones
art/<stage>/                Pixel art borrowed from the arcade games (sizes in art/sizes.txt)
bosses/<name>/<name>.tscn   One folder per boss (named in Stages.THEMES)
microgames/<name>/<name>.tscn   One folder per microgame (found automatically)
tools/autopilot.gd          Plays by itself, for recording the arcade attract video
tools/shots.gd              Saves screenshots every so often, for checking the look
tools/mascot_preview.tscn   Wirt in every mood side by side
build/                      Web export, served by GitHub Pages
```

## Adding a microgame

1. Create `microgames/<name>/<name>.tscn` with a `Node2D` root. Give the root a script that `extends Microgame`.
2. Set the prompt and settings in `_init()`:
   ```gdscript
   extends Microgame

   func _init() -> void:
       prompt = "SHAKE!"            # the big instruction word
       controls_hint = "ARROW KEYS" # small hint under it
       duration = 4.0               # seconds before speed-up
       win_on_timeout = false       # true for "survive until time's up" games
       touch_hint = "TAP THE BUTTON" # hint shown on touch screens instead
       controls = Controls.BUTTON   # touch buttons: BUTTON, LEFT_RIGHT, ARROWS or POINTER
   ```
3. Set up the round in `_on_start()`. `difficulty` (1–3) and `stage` (0–2) are already set at this point. `Stages.theme(stage)` gives the stage's colours, and `draw_sprite("graveyard/ghost", frames, anim_frame(8, frames), pos, 4.0)` draws its art.
4. Call `win()` or `lose()` when the outcome is decided. Guard input with `is_playing()`.
5. For juice, use `Sfx.play("pop")`, `burst(pos, color)`, `popup("+1", pos)` and `shake(12)`. Main already plays the win/lose sounds and shakes the screen on a loss.
6. The screen is 720×1280 (portrait). The fuse bar runs along the top. If the game uses touch buttons (`BUTTON`, `LEFT_RIGHT`, `ARROWS`), keep the action above `CONTROLS_TOP` (y = 1060), because on shorter phones the buttons cover the area below it. `POINTER` games can use the whole screen.

The main loop picks up the new folder automatically. Speed-ups work through `Engine.time_scale`. Use `delta`, timers and tweens as normal and they all speed up together.

## Testing

Command-line options (after `--`):

| Option | Effect |
| --- | --- |
| `--game=<folder>` | Play only that microgame, over and over |
| `--stage=<0-2>` | Start on that stage |
| `--games=<n>` | Play n microgames per stage (1 gets to the bosses fast) |
| `--autopilot` | Start right away and play some games by itself |
| `--shots=<folder> --every=<s>` | Save a screenshot every s seconds (needs a window, not `--headless`) |
| `--mute` | No sound |

```
godot --path . -- --autopilot --stage=1 --games=1 --shots=C:/tmp/shots --every=0.5 --mute
godot --path . res://tools/mascot_preview.tscn
```

## Web build and the Scareathon arcade

WirtWare runs as a cabinet in the Scareathon arcade. The page loads `https://sclondon.github.io/WirtWare/build/index.html` in a 9:16 iframe. At game over the game posts `{ type: 'PLAYER_DIED', score }` to the parent page, where the score is microgames won plus 5 for each boss beaten.

To publish a new build:

```
godot --headless --path . --export-release "Web" build/index.html
git add build && git commit -m "Update web build" && git push
```

Then bump the `?v=` cache-buster on `WIRTWARE_URL` in the arcade page (`src/pages/Arcade/games.tsx` in scareathon-v3) to the new commit hash.

To re-record the attract video, run the game on autopilot with the movie maker, then convert the result to a 540×960 mp4 in `public/game-recordings/WirtWare.mp4`:

```
godot --path . --write-movie attract.avi --fixed-fps 30 --resolution 720x1280 --quit-after 560 -- --autopilot
```
