# WirtWare

Rapid-fire microgames in the style of WarioWare, made with Godot 4.7.

Each microgame lasts a few seconds. You see a one-word prompt, then you have to work out what to do before the fuse runs out. Win to score, lose to drop a heart. Every 4 wins the game speeds up. Later games also get harder.

## Controls

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Move | Arrow keys / WASD | D-pad / left stick | On-screen arrows |
| Action | Space / Z / Enter | A | On-screen A button |
| Pointer games | Mouse | — | Finger |

WirtWare is portrait-first: the game is a 720×1280 (9:16) canvas, laid out for a phone held upright. On phones, each microgame shows only the buttons it needs, along the bottom edge. On tall phones they sit in the spare space under the game. On shorter ones they float over the game's floor.

## Microgames

| Prompt | Folder | What you do |
| --- | --- | --- |
| DODGE! | `dodge` | Move left and right to avoid falling rocks until time runs out |
| PUMP IT! | `pump` | Mash the action button to inflate a balloon until it pops |
| CATCH! | `catch` | Slide a basket under a falling apple |
| STOP! | `stop` | Press the button while the needle is in the green zone |
| POP 'EM! | `pop` | Click every balloon |
| JUMP! | `jump` | Jump over the cacti |
| COPY! | `copy` | Press the arrow sequence shown, in order |
| DRAW! | `duel` | Wait for "FIRE!", then shoot. Too early or too late loses |
| LAND! | `land` | Hold the button to thrust, and touch down slowly |
| SORT! | `sort` | Send circles to the left bin and squares to the right |
| WHACK! | `whack` | Press the arrow that matches the mole's hole. A wrong swing loses |
| SCRUB! | `scrub` | Hold the mouse button and scrub the grime off a plate |
| SLICE! | `slice` | Swipe the mouse through every fruit before it falls |
| TRACE! | `trace` | Drag along a wiggly path from start to finish without leaving it |
| FLICK! | `flick` | Flick a paper ball into the bin. One shot, and the bin moves on harder levels |
| FEED! | `feed` | Drag each snack into the monster's mouth |
| WIND IT! | `crank` | Spin your finger around the crank until the jack-in-the-box pops |
| FOLLOW! | `follow` | Keep your finger on the wandering firefly until time runs out |
| SWIPE! | `swipe` | Swipe the way each arrow points. Red arrows mean the opposite way |

The last six are built for touch screens but also work with a mouse (and SWIPE! with the arrow keys). Pointer games call `update_pointer()` each frame and read `pointer`, `pointer_down`, `pointer_pressed` and `pointer_released`. Use `touch_size()` for anything a finger has to hit, so it stays big enough on a small phone.

## Project layout

```
scenes/main.tscn            Entry scene (just runs scripts/main.gd)
scripts/main.gd             Game loop, HUD, speed-ups, lives, best score
scripts/microgame.gd        `Microgame` base class that every game extends
scripts/hearts.gd           Lives display
scripts/touch_controls.gd   On-screen buttons for phones
tools/autopilot.gd          Plays by itself, for recording the arcade attract video
build/                      Web export, served by GitHub Pages
microgames/<name>/<name>.tscn   One folder per microgame (found automatically)
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
3. Set up the round in `_on_start()`. `difficulty` (1–3) is already set at this point.
4. Call `win()` or `lose()` when the outcome is decided. Guard input with `is_playing()`.
5. The screen is 720×1280 (portrait). The fuse bar runs along the top. If the game uses touch buttons (`BUTTON`, `LEFT_RIGHT`, `ARROWS`), keep the action above `CONTROLS_TOP` (y = 1060), because on shorter phones the buttons cover the area below it. `POINTER` games can use the whole screen.

The main loop picks up the new folder automatically. To test one game over and over, select the `Main` node and set **Debug Microgame** in the inspector. You can also press F6 to run the microgame scene by itself.

Speed-ups work through `Engine.time_scale`. Use `delta`, timers and tweens as normal and they all speed up together.

## Web build and the Scareathon arcade

WirtWare runs as a cabinet in the Scareathon arcade. The page loads `https://sclondon.github.io/WirtWare/build/index.html` in a 9:16 iframe. At game over the game posts `{ type: 'PLAYER_DIED', score }` to the parent page, where the score is the number of microgames won.

To publish a new build:

```
godot --headless --path . --export-release "Web" build/index.html
git add build && git commit -m "Update web build" && git push
```

Then bump the `?v=` cache-buster on `WIRTWARE_URL` in the arcade page (`src/pages/Arcade/page.tsx` in scareathon-v3) to the new commit hash.

To re-record the attract video, run the game on autopilot with the movie maker, then convert the result to a 540×960 mp4 in `public/game-recordings/WirtWare.mp4`:

```
godot --path . --write-movie attract.avi --fixed-fps 30 --resolution 720x1280 --quit-after 560 -- --autopilot
```
