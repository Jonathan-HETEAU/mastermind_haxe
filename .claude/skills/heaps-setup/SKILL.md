---
name: heaps-setup
description: Install the Heaps game engine toolchain (Haxe, haxelib libraries, HashLink) and create, build and run a Heaps game for the web (WebGL) and HashLink. Use it whenever someone starts a new Heaps or Haxe game, sets up a machine or a CI for Heaps, writes or fixes .hxml build files, installs HashLink (hl) on Linux, Windows or macOS, or gets library version errors (DomKit "Too many arguments", "RuleStyle has no field pos", hlsdl or SDL2/SDL3 mismatches, "Library heaps is not installed", "Missing canvas #webgl").
---

# Heaps setup: toolchain, new project, build and run

Heaps is built from git more than from releases: Heaps, DomKit and `hlsdl` (the HashLink binding
of SDL) change together, so most build failures come from libraries of different periods. Pick
a coherent set first, then create the project.

## 1. Choose a coherent set of versions

| Set | Haxe | Heaps / DomKit | HashLink and `hlsdl` | When |
|---|---|---|---|---|
| **Current** | 4.3.x | git `master` of both | git `master` (SDL3), `haxelib dev hlsdl <hashlink>/libs/sdl` | new projects |
| **SDL2 (April 2025)** | 4.3.x | heaps `f7d5acf`, domkit `675f088` | release **1.15**, the last one with SDL2 | a distribution without SDL3, or an existing game pinned there |

Known incompatibilities (all seen in real builds):

- The haxelib releases Heaps 2.1.0 / 2.1.1 do not compile with DomKit 1.0 ("Too many arguments",
  "RuleStyle has no field pos", "currentRuleStyles") and their `h2d.domkit.Style` does not compile
  for the web (`LocalFileSystem.LocalEntry`). Use git versions.
- Heaps after 22 April 2025 needs a newer `hlsdl` than the one of HashLink 1.15; HashLink after
  1.15 needs SDL3. So: recent Heaps ⇒ HashLink from git with SDL3; HashLink 1.15 ⇒ Heaps
  `f7d5acf` or older.
- The `hlsdl` Haxe library must come from the same HashLink as the installed `sdl.hdll`:
  `haxelib dev hlsdl <hashlink sources>/libs/sdl`.

Write the chosen versions in the README of the game, with the commands: the next person (or the
CI) will need exactly them.

## 2. Install

```sh
# Haxe 4.3: https://haxe.org/download/ (or the package of the distribution), then:
haxelib setup ~/haxelib
haxelib git heaps https://github.com/HeapsIO/heaps
haxelib install format                                      # needed by heaps
haxelib git domkit https://github.com/HeapsIO/domkit        # for UI with CSS (heaps-domkit skill)
haxelib git hxbit https://github.com/ncannasse/hxbit        # for binary saves and networking
haxelib install hscript                                     # optional, for h2d.Console scripts
```

To pin a commit: `git -C $(haxelib libpath heaps) checkout <commit>` (or clone anywhere and
`haxelib dev heaps <folder>`).

**HashLink** (to run `.hl` files; the web needs nothing more than a browser):

- **Linux**, from source:
  ```sh
  # Debian/Ubuntu dependencies; for 1.15 use libsdl2-dev instead of libsdl3-dev
  sudo apt-get install build-essential git libpng-dev libturbojpeg-dev libvorbis-dev libopenal-dev \
       libsdl3-dev libglu1-mesa-dev libmbedtls-dev libuv1-dev libsqlite3-dev
  git clone https://github.com/HaxeFoundation/hashlink     # add --branch 1.15 for the SDL2 set
  cd hashlink && make && sudo make install && sudo ldconfig
  haxelib dev hlsdl $(pwd)/libs/sdl
  ```
  If the SSL part fails (mbedTLS too recent for 1.15), the games do not need it:
  `make LIBS="fmt sdl openal ui uv sqlite heaps"`.
- **Windows**: a release zip of https://github.com/HaxeFoundation/hashlink/releases (add the folder
  to `PATH`), or build `hl.sln` with Visual Studio for a git version. DirectX instead of SDL:
  `-lib hldx` instead of `-lib hlsdl`.
- **macOS**: `brew install hashlink`, or build from source like Linux (`brew install sdl3 ...`).

Check: `haxe --version`, `haxelib list`, `hl --version`.

## 3. Create a project

For a real game (menus, pause, save, sounds, gamepad), start instead from the complete games of
the **heaps-game** skill (`assets/skeleton`, turn by turn; `assets/shooter`, real time). For a
bare project, a test or a prototype:

```sh
sh ${CLAUDE_SKILL_DIR}/scripts/new-project.sh <folder> [--3d] [--domkit]
```

It writes a project that compiles as is (2D: a square moved with the keyboard or a gamepad;
`--3d`: a lit turning cube; `--domkit`: a CSS-styled HUD component):

```
src/Main.hx        the hxd.App: init(), update(dt), main()
res/               the resources, read with hxd.Res (images, sounds, fonts, levels...)
build-js.hxml      -> bin/game.js, loaded by index.html
build-hl.hxml      -> bin/game.hl (same, plus -lib hlsdl)
index.html         the page: <canvas id="webgl" globalEvents="1">
```

Why these choices:

- `main()` uses `hxd.Res.initEmbed()` on the web (the resources are inside the `.js`) and
  `hxd.Res.initLocal()` with `hxd.res.Resource.LIVE_UPDATE = true` on HashLink: the game reads
  `res/` from the disk and reloads a file when it changes. Run `hl` from the project folder.
- `s2d.scaleMode = LetterBox(w, h, true)` gives a fixed virtual resolution with whole-number
  scaling (crisp pixel art), whatever the window size.
- The canvas must have the id `webgl` ("Missing canvas #webgl" otherwise). By default Heaps listens
  to the keyboard on the canvas, which needs a click first; `globalEvents="1"` listens on the
  whole page.

## 4. Build and run

```sh
haxe build-js.hxml && npx http-server -c-1 .   # or: python3 -m http.server; open http://localhost:8080
haxe build-hl.hxml && hl bin/game.hl
```

The web build must be served over HTTP (not opened as `file://`) as soon as it loads files.
To check a web build without a screen, use the **heaps-browser-test** skill.

Add `-debug` to an hxml for stack traces with line numbers; `-D js-source-map` maps the JS to
the Haxe sources in the browser tools. In VS Code: the "Haxe" extension, and "HashLink Debugger"
to debug `.hl` with breakpoints.

## 5. Errors

| Error | Cause and fix |
|---|---|
| `Library heaps is not installed` | `haxelib git heaps ...` (or `haxelib dev`), or a wrong `haxelib setup` folder. |
| `Too many arguments`, `RuleStyle has no field pos` (in `h2d/domkit/Style.hx`) | Heaps and DomKit of different periods: see section 1. |
| `Could not load component 'x'` | DomKit does not find the class of `<x>`: see the heaps-domkit skill. |
| `hlsdl` / `sdl.hdll` errors when running `hl`, or "Failed to load library sdl.hdll" | `hlsdl` and the installed HashLink differ: `haxelib dev hlsdl <hashlink>/libs/sdl`, rebuild. |
| `Missing canvas #webgl` | index.html has no `<canvas id="webgl">`. |
| Black page, `404` for `game.js` | the page and the `-js` output path do not match, or the page is opened as `file://`. |
| `hxd.Res` has no field `xxx` | the file is not under `res/` (or the `-D resourcesPath=DIR` folder), or is in a folder starting with `.` or `_` (ignored), or its name changed: characters other than letters, digits and `_` become `_` (`my-image.png` is `hxd.Res.my_image`). |
| `Resource directory not found in classpath 'res'`, then `Uncaught exception __invalid` | no `res/` folder next to the hxml (git does not keep empty folders: keep a file in it). |

Next steps: **heaps-game** for how to write the game, **heaps-docs** to look up an API.
