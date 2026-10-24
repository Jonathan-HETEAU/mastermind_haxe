---
name: heaps-game
description: How to write a game with the Heaps engine (Haxe) the way that works - structure (rules separated from the view, screens and menus), hxd.App life cycle, frame-rate independent movement, keyboard and gamepad input with action mapping, resources and hot reload, sprites and sprite sheets, text and fonts, music and sound effects, saving progress with hxd.Save, and testing. Use it whenever you write, extend, review or refactor Heaps game code (h2d, hxd, s2d, s3d, hxd.App), add a feature such as a menu, a pause screen, controls, sound or a save system, or when the user asks for best practices for a Heaps game.
---

# Writing a game with Heaps

These are the practices that held up in real Heaps games (a Mastermind, a puzzle game with
menus, pause, save, sounds and two-player gamepad play). Each one says why, so you can judge
when it does not apply. Check unfamiliar APIs with the **heaps-docs** skill.

## Start from the skeleton

Two small complete games apply everything below; both are built and played for the web and
HashLink. Start a game from one of them, or read their files when adding one of these features
to an existing game:

- `${CLAUDE_SKILL_DIR}/assets/skeleton`: turn by turn (a grid puzzle). Title menu (continue,
  new game, music and sound options, quit), levels, pause menu, save, sound and music by name,
  keyboard and gamepad, rules tested without a window.
- `${CLAUDE_SKILL_DIR}/assets/shooter`: real time (a shooter, "Astéroïdes", built from the
  skeleton). Movement and fire held every frame, analog stick, simulation in short steps,
  drawing with `h2d.Graphics`, particles, screen shake, best score, game over panel; its
  `README.md` lists what it adds to the skeleton.

```sh
cp -r ${CLAUDE_SKILL_DIR}/assets/skeleton <folder>    # then: haxe build-js.hxml, haxe test.hxml
```

Skeleton files:

| File | Shows |
|---|---|
| `src/Main.hx` | the stack of screens, the actions sent to the top screen |
| `src/Controls.hx` | keyboard and gamepads read as actions, presses from events and pad edges |
| `src/Audio.hx` | sounds by name, random variants, missing files silent, music loop and ducking |
| `src/Progress.hx` | `hxd.Save` with defaults and fields added by later versions |
| `src/model/World.hx`, `test/TestWorld.hx` | rules without Heaps, tested with `--interp` |
| `src/screen/GameScreen.hx` | redraw from the state, events turned into feedback, pause overlay |
| `src/ui/Menu.hx` | a menu for keyboard, gamepad and mouse |

## Structure: keep the rules out of the view

```
src/Main.hx       the hxd.App: creates the screens, forwards update and events
src/model/        the rules and the state: plain Haxe, no h2d/h3d/hxd import
src/screen/       one class per screen: title, game, options, end...
src/ui/           reusable UI: menus, HUD (with DomKit: heaps-domkit skill)
res/              images, sounds, fonts, levels (read with hxd.Res)
test/             tests of the model, run with `haxe test.hxml` (--interp)
```

- **The model knows nothing about Heaps.** It can then be tested without a window
  (`-main TestRules --interp`), read on its own, and drawn by any view. The view never changes the
  model: it reports what the player did, the screen calls the model, then redraws.
- **Redraw from the state** rather than patching the display after each move. Removing and
  re-creating a few hundred bitmaps costs nothing, and the screen can never disagree with the
  model. Keep objects that never change (backgrounds, buttons) and only re-create what depends on
  the state. Move to incremental updates only for thousands of objects or per-frame animation.
- **The model emits events** (`LevelWon`, `CrateMoved`, `Bumped`...) that the view turns into
  sounds, shakes and particles: feedback stays out of the rules, and adding a sound does not
  touch them.

## hxd.App life cycle

- `init()` runs once, when the engine is ready: create the scenes there, not in the constructor.
- `update(dt)` runs every frame. `dt` is in **seconds**: multiply speeds by it
  (`x += speed * dt`) so the game runs the same at 30, 60 or 144 frames per second. Avoid counting
  frames; `hxd.Timer.tmod` (1 at 60 FPS) exists for code written in frames.
- `onResize()` runs when the window changes size. With a fixed virtual resolution
  (`s2d.scaleMode = LetterBox(320, 180, true)`), most games never need it: positions are in
  virtual pixels and the scene is scaled for you (`true` = whole-number scale, crisp pixel art).
  Other modes: `Resize` (the default: 1 unit = 1 pixel), `Stretch`, `Fixed`, `Zoom`, `AutoZoom`.
- `s2d` is the 2D scene, drawn over `s3d`, the 3D scene. `setScene(scene)` replaces the 2D scene
  and **disposes the previous one** by default: pass `false` to keep a screen you will come back
  to (pause, options).

## Real-time games

- The model gets `update(dt, inputs)` every frame and returns events; the screen draws its state
  (shooter: `Field.update(dt, moveX, moveY, fire)`).
- **Cut long frames into short steps** inside the model (`while( dt > 0 ) step(min(dt, 1/60))`):
  a fast object then cannot cross another between two frames (bullets through enemies), and the
  rules behave the same at any frame rate. Heaps already limits `dt`: after a frame longer than
  `hxd.Timer.maxDeltaTime` (0.5 s, a pause of the browser tab for instance), `dt` keeps its
  previous value; and on the web `dt` is smoothed over frames (`hxd.Timer.smoothFactor`, 0.95;
  0 on HashLink).
- **While paused, do not update anything** (model, particles, background): return early from
  `update`, the pause menu only needs the actions.
- **Pause when the window loses the focus** (`EFocusLost` event): the player went to another
  window (skeleton: `Controls.onFocusLost`).
- Deterministic logic (replays, network, tests): a seeded random generator in the model instead
  of `Std.random` (shooter: `Random` in `Field.hx`).

## Screens and menus

One class per screen, each with its own `h2d.Scene` (or its own root object), its `update(dt)`
and its actions; `Main` keeps a **stack**: pushing an options screen keeps the title below,
popping it comes back (skeleton: `Main.hx`). A pause menu is better as an overlay in the game
scene, so the level stays visible behind it (skeleton: `GameScreen.openPause`).

Things players expect, cheap to do from the start:

- Every menu works with the keyboard **and** the gamepad (arrows/D-pad move, Enter/A confirms,
  Escape/B goes back), not only the mouse: keep a "selected" index and a CSS class or a marker.
- Pause (Escape / Start) with Resume, Restart, Options, Main menu.
- "Continue" on the title screen when a save exists.
- Keys shared between play and menus: when fire and confirm are the same key (Space, A), a
  player still firing confirms the game over menu at once; make that menu wait a moment
  (shooter: `OVER_DELAY`). Do not give one key two actions that a screen treats differently in
  the same frame (Escape as both `Back` and `Pause` opens and closes the pause at once).
- Create the next screen **after** saving: `Main.inst.show(new TitleScreen())` built before
  `Progress.save...` shows the old best score (shooter: `GameScreen.leave(TitleScreen.new)`).

## Input

- **Read actions, not keys.** Map each action (`Left`, `Jump`, `Confirm`...) to several keys and
  gamepad buttons in one place (skeleton: `Controls.hx`): remapping, two players on one keyboard
  and gamepad support then cost one table each.
- Poll in `update` for movement: `hxd.Key.isDown(code)` (held), `isPressed` (went down this
  frame), `isReleased`. For menus and text, use the events: a key pressed and released within
  one frame is seen by the events but not by `isPressed`. Listen on the window,
  `hxd.Window.getInstance().addEventTarget(e -> if( e.kind == EKeyDown ) onKey(e.keyCode))`
  (skeleton: `Controls.hx`), not with `s2d.addEventListener`: after a click on an
  `h2d.Interactive` (a button), it has the keyboard focus and the scene listeners no longer get
  the keys.
- `hxd.Key` codes are **characters**: `Key.Z` is the key labelled Z, on any keyboard layout. For
  AZERTY and QWERTY players, accept both Z Q S D and W A S D (plus the arrows).
- Gamepads: `hxd.Pad.wait(p -> ...)` is called for each pad connected, now or later; start with
  `hxd.Pad.createDummy()` to avoid null checks. Buttons through `p.config` (`p.isDown(p.config.A)`).
  Sticks: `p.xAxis` / `p.yAxis` go from -1 to 1 and are 0 inside `p.axisDeadZone` (0.1; raise it
  to 0.2 for worn sticks). Use the analog value for movement (shooter: `Controls.moveX`), and a
  threshold (`> 0.5`) only to turn a stick into a direction for menus. Menus need the **press**,
  not the state: compare with the previous frame. Handle `p.onDisconnect`. Wrap
  `p.rumble(...)` in `try`: not every pad and platform supports it.

## Resources

- `hxd.Res.<folder>.<file>` is typed and checked at compile time: a missing file is a compile
  error. Names: other characters than letters, digits and `_` become `_`; folders starting with
  `.` or `_` are ignored.
- `hxd.Res.initEmbed()` for the web (the files go into the `.js`), `hxd.Res.initLocal()` on
  HashLink while developing: with `hxd.res.Resource.LIVE_UPDATE = true`, images, sounds and CSS
  reload when the file changes, and `res.watch(callback)` reloads your own data (levels).
- For optional files or names built at runtime: `hxd.Res.loader.exists("sound/jump.wav")` then
  `hxd.Res.load("sound/jump.wav").toSound()`. Missing optional files can then stay silent (useful
  for placeholder sounds).
- Images: `hxd.Res.hero.toTile()` (cached: calling it again is cheap). Sprite sheets:
  `tile.split(frames)` (one row), `tile.gridFlatten(size)` or `tile.grid(size)`, `tile.sub(x, y, w, h)`;
  `new h2d.Anim(frames, fps, parent)` plays them. Many sprites of one texture: `h2d.SpriteBatch`
  or `h2d.TileGroup` (one draw call).
- Text: `new h2d.Text(hxd.res.DefaultFont.get(), parent)` for debug; for the game, a bitmap
  font (`.fnt` + `.png`, from BMFont, Hiero...): `hxd.Res.fonts.title.toFont()`, or
  `toSdfFont(size)` for a font that stays sharp when scaled. Check that a font has all the
  characters of your texts: the default font of Heaps has Latin-1 (é, è, à, ç, ï, «, »...) but
  not `œ`, `Œ`, `’` (typographic apostrophe), `€` or `…`.

## Sound

- `hxd.Res.sound.jump.play()` plays once; it returns a `Channel`: keep it for music
  (`play(true, 0.6)` loops at 60 % volume, then `channel.stop()`, `channel.volume = ...`,
  `channel.fadeTo(0, 1.5)`).
- Formats: `.wav` and `.mp3` everywhere; `.ogg` only on HashLink (or with `-lib stb_ogg_sound`).
  Prefer `.wav` for short effects and `.mp3` for music.
- Browsers only start audio after the first click or key press: a title screen that waits for
  "press a key" solves it.
- Centralize sounds in one class with one name per event (`Sfx.UiMove`, `Sfx.Jump`...): it is the
  list of the sounds to make, the place for volumes and the on/off option, and a missing file
  can be silent instead of crashing (skeleton: `Audio.hx`). Variants (`jump_2.wav`,
  `jump_3.wav`) picked at random keep frequent sounds from becoming tiresome.

## Saves

`hxd.Save.save(data, "mygame")` / `hxd.Save.load(defaults, "mygame")` store any value
serializable by `haxe.Serializer`: a file `mygame.sav` in the working directory on HashLink,
`localStorage` in a browser. When the save lacks fields added by a later version of the game,
`load` gives them their value in `defaults` (recursively in objects). Keep the save a small
typedef (level reached, options) and save at clear moments (start of a level, options changed,
game over). For large or binary data, or many objects referencing each other, see the
**heaps-hxbit** skill.

## Checking your work

- Test the rules: a `test.hxml` with `-main TestRules --interp` runs them without a window, in
  a second. The interpreter differs from the targets on one point: a `Float` variable that holds
  a whole number, multiplied by an `Int` literal, overflows as a 32-bit integer
  (`f = 123456789; f * 16807` gives 469048755). Write float literals (`16807.`) in such
  computations (random generators, hashes).
- Check the real game: build for the web and run it in a headless browser with the
  **heaps-browser-test** skill (inputs, screenshots, errors), especially when there is no screen.
- `trace` prints to the console (browser) or the terminal (HashLink); `h2d.Console` gives an
  in-game console with commands.
