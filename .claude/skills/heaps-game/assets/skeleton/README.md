# Game

| Command | Result |
|---|---|
| `haxe build-js.hxml` | `bin/game.js`: serve the folder (`npx http-server -c-1 .`) and open `index.html` |
| `haxe build-hl.hxml` | `bin/game.hl`: `hl bin/game.hl` from this folder (reads `res/`, reloads changed files) |
| `haxe test.hxml` | tests of the rules (`test/TestWorld.hx`), without a window |

Controls: arrows, Z Q S D or W A S D to move and choose, Enter or Space to confirm, Escape to go
back or pause, P to pause; gamepad: D-pad or left stick, A, B, Start.

| File | Role |
|---|---|
| `src/Main.hx` | the stack of screens; sends the frames and the actions to the top one |
| `src/Controls.hx` | keyboard and gamepads read as actions (`Up`, `Confirm`, `Pause`...) |
| `src/Audio.hx` | sound effects and musics by name; missing files are silent |
| `src/Progress.hx` | the save (`hxd.Save`): level to continue, options |
| `src/model/World.hx` | the rules and the state, without Heaps |
| `src/screen/` | `TitleScreen` (continue, new game, options), `GameScreen` (level, pause menu) |
| `src/ui/Menu.hx` | a list of choices for keyboard, gamepad and mouse |
| `res/sound/`, `res/music/` | the sounds to make: see the `README.txt` files |

## Versions

Write here the versions the game is built with (see the heaps-setup skill), for example:
Haxe 4.3.7, Heaps git `<commit>`, HashLink git `<commit>` (SDL3, `haxelib dev hlsdl <hashlink>/libs/sdl`).
