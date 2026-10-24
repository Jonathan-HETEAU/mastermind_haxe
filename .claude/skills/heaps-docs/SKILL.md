---
name: heaps-docs
description: Find the exact API and a working example for anything in the Heaps game engine stack - Heaps (h2d, h3d, hxd, hxsl), HxBit, DomKit, hlsteam and Hide (hrt) - from the Heapheapheaps documentation (generated from the sources, one Markdown page per type), the library sources and the Heaps samples. Use it before writing or fixing Heaps/Haxe game code whenever you are not sure of a class, a method signature, an enum value or how a feature is meant to be used (sprites, tiles, text, fonts, flows, sound, input, gamepad, saves, resources, 3D, shaders, prefabs, networking, Steam), and when the user asks "how do I ... in Heaps".
---

# Heaps documentation and examples

Heaps has few tutorials and its API moves, so code written from memory is often wrong (renamed
classes, changed signatures, abstract classes). Check the API before using it; it takes seconds.

## 1. Look up a type

```sh
sh ${CLAUDE_SKILL_DIR}/scripts/lookup.sh flow                 # types whose name or summary match all the words
sh ${CLAUDE_SKILL_DIR}/scripts/lookup.sh --page h2d.Flow      # the full page: fields, signatures, docs
sh ${CLAUDE_SKILL_DIR}/scripts/lookup.sh --source hxd.Window  # its .hx files in the installed library (+ .js.hx, .hl.hx)
```

The pages come from https://github.com/Jonathan-HETEAU/Heapheapheaps (folder `content/`),
generated from the doc comments of the sources: 2,200 types, each with its signatures,
inheritance, platforms and a link to its source. The script caches what it downloads in
`~/.cache/heaps-docs`.

Without the script, read the indexes directly (raw Markdown):

- `https://raw.githubusercontent.com/Jonathan-HETEAU/Heapheapheaps/main/content/llms.txt`: the
  overview, with the guides.
- `.../content/llms/<lib>.txt` (`heaps`, `hxbit`, `domkit`, `hlsteam`, `hide`): every type with a
  one-line summary.
- `.../content/api/<lib>/<package>/<Type>.md`, e.g. `content/api/heaps/h2d/Flow.md`.
- `.../content/llms/<lib>-full.txt`: all the pages of a library in one file (Heaps: 1.7 MB, so
  search it rather than read it).

**The installed sources are the truth.** The documentation follows the git heads of the libraries
(October 2026); a game pinned to an older Heaps may differ. When a signature matters, read the
source of the version the game uses: `--source`, or `$(haxelib libpath heaps)`. A compile error
such as "has no field" or "is abstract" usually means the code and the installed version
disagree: read the source rather than guessing another name.

## 2. Find an example

The Heaps samples are small, complete programs, one feature each:
`$(haxelib libpath heaps)samples/<Name>.hx` (or https://github.com/HeapsIO/heaps/tree/master/samples).
Their resources are in `samples/res` and `samples/<name>_res`; a line `//PARAM=...` at the top
gives the extra compiler options a sample needs.

| Topic | Samples |
|---|---|
| 2D basics: objects, bitmaps, text | `Base2D`, `Text`, `HtmlText` |
| Drawing many tiles, sprite sheets | `DrawingTiles` (`TileGroup`, `SpriteBatch`), `Tiled` (Tiled `.tmx` maps) |
| Shapes, filters, masks | `GraphicsDraw`, `Polygons`, `Filters`, `Blur`, `Mask`, `AdjustColor` |
| Layout and UI | `Flows` (`h2d.Flow`), `Domkit` (components + CSS), `Input` (`TextInput`, `Console`), `SampleApp` (sliders, buttons) |
| Screen size, cameras | `ScaleMode2D` (all the `ScaleMode`s), `Camera2D`, `Fullscreen` |
| Mouse, keyboard, gamepad | `Interactive2D`, `Interactive` (3D picking), `MouseApi`, `Cursor`, `Pad` |
| Collisions | `CollideCheck`, `Bounds` (`h2d.col`) |
| Sound | `Sound` (music, effects, pitch, low pass, spatialization) |
| 2D particles | `Particles2d` |
| 3D basics: meshes, lights, camera | `Base3D`, `Helpers`, `Quaternion`, `PointLights`, `Shadows` |
| Models and animations (FBX / HMD) | `Skin`, `World` |
| PBR rendering | `Pbr`, `PbrLights`, `Lights`, `Sao`, `ScreenSpaceReflection` |
| Many objects, GPU particles | `MeshBatch`, `GpuParticles`, `Bindless` |
| Shaders (HXSL) | `ShaderAdvanced`, `CubeTexture`, `Stencil` |
| Networking with HxBit | `Network` (`hxd.net.SocketHost`) |
| Hide prefabs and FX | `FxView` (`-lib hide`) |
| Video | `Video` |

## 3. Guides

Hand-written, with examples that compile:

- Getting started: `content/guides/01-getting-started.md` (install, first app, web and
  HashLink, life cycle).
- Using Hide, the editor: `content/guides/02-hide.md` (French: `content/guides/fr/02-hide.md`).

The other skills of this plugin hold the practical knowledge: **heaps-setup** (toolchain, new
project, version problems), **heaps-game** (how to structure a game: screens, input, sound,
saves), **heaps-domkit** (UI), **heaps-hide**, **heaps-hxbit**, **heaps-hlsteam**,
**heaps-browser-test** (check a build in a headless browser).
