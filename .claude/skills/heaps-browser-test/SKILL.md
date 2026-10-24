---
name: heaps-browser-test
description: Run a Heaps game (compiled to JavaScript) in headless Chromium to check that it really works - plays keyboard, mouse and gamepad inputs, takes screenshots, measures whether the picture moves, and reports console output and uncaught errors. Use it after changing a Heaps game whenever there is no screen to look at (cloud sessions, CI, an AI agent) or before saying "it works", to reproduce a bug seen in the browser, to check that a menu, a key binding or a gamepad mapping does what it should, or to get screenshots of a game for a README.
---

# Test a Heaps game in a headless browser

Compiling proves little about a game: a black screen, a menu that ignores the gamepad or an
exception at the first frame all compile. This skill runs the web build in Chromium (software
WebGL, no GPU needed), plays inputs and shows you what the player would see.

## Run

```sh
haxe build-js.hxml                                   # the web build of the game
node ${CLAUDE_SKILL_DIR}/scripts/run.js <folder with index.html> [options] [steps...]
```

The script serves the folder over HTTP, opens `index.html`, focuses the canvas (as a click
would), runs the steps in order and prints the console. Exit code 1 if the page threw an
uncaught error or one of its files could not be loaded (HTTP 404...).

| Step | Effect |
|---|---|
| `wait <ms>` | let the game run |
| `key <Key> [ms]` | press and release a key, held ms (100). Playwright names: `ArrowLeft`, `Space`, `Enter`, `Escape`, `KeyZ`, `Digit1`... |
| `down <Key>` / `up <Key>` | hold / release a key (movement over time) |
| `type <text>` | type characters |
| `click <x> <y>` | click at a point of the page (CSS pixels from the top left) |
| `move <x> <y>` | move the mouse there without clicking (hover effects, `onOver`, DomKit `:hover`) |
| `pad` | connect a fake standard gamepad, index 0 (do it before the other pad steps) |
| `pad <button> [ms] [index]` | press a gamepad button: `A B X Y LB RB LT RT BACK START LS RS UP DOWN LEFT RIGHT` |
| `stick <x> <y> [ms] [index]` | move the left stick (-1..1); back to 0 after ms if given |
| `shot <file.png>` | screenshot |
| `motion [ms] [x y w h]` | compares two screenshots ms apart (500): number of changed pixels, 0 = frozen picture; in a rectangle only if given (a scrolling background moves everywhere else) |
| `until <ms> <js>` | waits until a JavaScript expression is true, at most ms (a timeout counts as an error) |
| `log <ms> <text>` | waits until a console line (a `trace`) contains the text, at most ms |
| `eval <js>` | evaluate JavaScript in the page and print the result |
| `reload` | reload the page: the game restarts, `localStorage` (so `hxd.Save`) is kept |

Options: `--size 800x600` (window size), `--page other.html`, `--quiet` (only errors and
results), `--port n`, `--steps file.txt` (more steps, one per line, `#` comments: no shell
quoting for long scenarios).

Example: start a game from the title menu with the gamepad, walk right, check it animates and
look at the result:

```sh
node ${CLAUDE_SKILL_DIR}/scripts/run.js . --size 640x360 pad "pad A" "wait 500" \
  "down ArrowRight" "motion 400" "up ArrowRight" "shot /tmp/game.png"
```

Then **look at the screenshots** (open the PNG with the Read tool): the numbers say something
changed, only the picture says it is right.

## Waiting for the game instead of guessing

Fixed waits are fragile (how long until the game over?). Wait for the game itself:

- `trace` the moments that matter (`trace('game over: score $score')`) and wait for them:
  `log 60000 game over`.
- Expose the state to the page in debug builds, then query it with `until` and `eval`:

  ```haxe
  #if (js && debug)
  (cast js.Browser.window).game = this;   // in the screen or the app
  #end
  ```

  ```text
  until 5000 window.game != null
  eval window.game.field.lives
  until 60000 window.game.field.over
  ```

  Build with `-debug` for this; Haxe keeps the field names in JavaScript.

## Reading the results

- `PAGE ERROR: ...`: an uncaught exception. The stack names the Haxe classes and methods
  (`Main.update`); `-debug` also writes a source map, for the developer tools of a browser.
- `HTTP 404: .../something`: a file the page or the game loads is missing (wrong `-js` path in
  the hxml, or a resource loaded at runtime that is not served).
- `motion: 0 pixels changed`: nothing moves. Fine for a static menu; for a game in progress it
  usually means `update` is not running, the input was not received or the game is paused.
- `trace()` output appears as `console.log` lines: add traces to the game to check its state
  (`trace('level ' + level)`), they cost nothing to remove afterwards.

## Things that behave differently from a desktop browser

- **Keyboard**: Heaps listens to the keys on the canvas unless the canvas has
  `globalEvents="1"`. The script focuses the canvas so both cases work; a real player on a page
  without `globalEvents` must click the game first.
- **Gamepad**: the fake pad uses the standard mapping (`A`=0, `B`=1, `X`=2, `Y`=3, `LB`=4,
  `RB`=5, `LT`=6, `RT`=7, `BACK`=8, `START`=9, `LS`=10, `RS`=11, D-pad 12-15, left stick axes
  0-1), which is what `hxd.Pad` reads in browsers (`hxd.Pad.CONFIG_JS_STD`). `hxd.Pad.wait`
  callbacks run when `pad` connects it. Rumble does nothing.
- **Sound**: the browser is started with autoplay allowed; a real browser only plays sound after
  the first click or key press.
- **Speed**: rendering is done by the CPU (SwiftShader). 3D scenes can run at a few frames per
  second: use longer waits rather than concluding that the game is frozen, and do not measure
  performance this way.
- **Saves**: `hxd.Save` uses `localStorage`, empty at each run: every run starts without a save.
  To test loading a save, play until the game saves (or write it with an `eval` step), then
  `reload`.

## Requirements

Node.js and the `playwright` package (global or local: `npm install -g playwright`), with a
Chromium: the one Playwright installs (`npx playwright install chromium`), the one at
`/opt/pw-browsers/chromium` (Claude Code cloud sessions) or any path in `$CHROMIUM_PATH`.
