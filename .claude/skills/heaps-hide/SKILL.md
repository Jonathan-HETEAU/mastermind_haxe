---
name: heaps-hide
description: Use Hide, the Heaps editor (levels, prefabs, FX, shader graphs, CastleDB data), with a Heaps game - build and run Hide, load .prefab / .l3d / .fx files in the game with hrt.prefab, reload them live, register your own prefab types and show them in the editor with a plugin. Use it whenever a Heaps project uses -lib hide, hrt.prefab, hxd.Res.<x>.load().make(), .prefab/.l3d/.fx/.shgraph files or res/props.json, when someone wants a level editor for a Heaps game, or when part of a level made in Hide is missing in the game.
---

# Hide, the Heaps editor

Hide edits the files of the game's `res/` folder; the game loads them with the Hide runtime
(`hrt` package, `-lib hide`). The full guide, with a tested example project, is
https://github.com/Jonathan-HETEAU/Heapheapheaps/blob/main/guides/02-hide.md (French:
`guides/fr/02-hide.md`; example: `guides/examples/hide`). This skill keeps what you need to act.

## Build and run the editor

```sh
# Libraries from git: format heaps castle hxbit hscript hxnodejs domkit hx3compat, and
# haxelib git hashlink https://github.com/HaxeFoundation/hashlink master other/haxelib/
git clone https://github.com/HeapsIO/hide && haxelib dev hide hide
cd hide && haxe hide.hxml                    # bin/hide.js (Hide and the game need the same Heaps)
```

Download the NW.js **SDK** (https://nwjs.io) into `bin/nwjs`, then run `bin/hide.cmd` (Windows),
`nwjs/nw .` from `bin` (Linux), or copy `bin` into `nwjs.app/Contents/Resources/app.nw` (macOS).
**Project > Open...**: the folder that contains `res/`.

## Load a level in the game

```haxe
var level : hrt.prefab.Prefab;

function load() {
	root.removeChildren();
	level = hxd.Res.level.load().make(root);      // root: an h3d.scene.Object (or h2d.Object)
	for( s in level.findAll(Spinner) )            // find(Class), findAll(Class), getOpt(Class, name)
		trace(s.name);
}
// in init(): load(); hxd.Res.level.watch(load);  // saved in Hide -> rebuilt in the game (initLocal)
```

`load()` returns the cached template of the file; `make(parent)` creates its objects and returns
the instance. An `hrt.prefab.Object3D` gives its object with `local3d`.

**The prefab types used by the files must be compiled into the game.** A type registers itself
when its class is compiled, and Haxe only compiles used classes; an unknown type loads as
`hrt.prefab.Unknown`, silently, without object. List them in the hxml:

```hxml
-lib heaps
-lib hide
-main Main
# The Hide prefab types the levels use: each one registers itself when compiled.
hrt.prefab.Light
hrt.prefab.l3d.Box
-js main.js
```

On HashLink, `--macro include("hrt.prefab")` compiles them all; on the web it fails ("You cannot
access the sys package") because some only exist on desktop. To find the types a file uses:
`grep -o '"type": "[a-z0-9]*"' res/level.prefab | sort -u`, then the class registered under each
name: `grep -rn 'register("box"' $(haxelib libpath hide)hrt`.

## Your own prefab type

```haxe
class Spinner extends hrt.prefab.Object3D {
	@:s public var speed : Float = 0.5;           // saved in the file when not the default
	@:s public var color : Int = 0xFF8000;

	override function makeObject( parent3d : h3d.scene.Object ) : h3d.scene.Object {
		return new SpinnerMesh(parent3d);
	}

	override function updateInstance( ?propName : String ) {   // called again on each edit in Hide
		super.updateInstance(propName);
		var mesh = cast(local3d, SpinnerMesh);
		mesh.speed = speed;
		mesh.material.color.setColor(color);
	}

	#if editor                                    // Hide only: menu entry and properties panel
	override function getHideProps() : hide.prefab.HideProps {
		return { icon : "refresh", name : "Spinner" };
	}

	override function edit( ctx : hide.prefab.EditContext ) {
		super.edit(ctx);
		var props = new hide.Element('<div class="group" name="Spinner"><dl>
			<dt>Speed</dt><dd><input type="range" min="0" max="4" field="speed"/></dd>
			<dt>Color</dt><dd><input type="color" field="color"/></dd>
		</dl></div>');
		ctx.properties.add(props, this, function(propName) ctx.onChange(this, propName));
	}
	#end

	static var _ = hrt.prefab.Prefab.register("spinner", Spinner);   // the "type" in the files
}
```

Hide knows the game's types through a **plugin**, the game classes compiled for the editor:

```hxml
# hide-plugin.hxml (HideImports.hx contains: import Spinner;)
-cp src
-lib hide
-lib hxnodejs
-lib domkit
-lib castle
--macro hide.Plugin.init()
-js hide-plugin.js
-dce no
HideImports
```

and `res/props.json`: `{ "plugins": ["../hide-plugin.js"] }` (path relative to `res/`). After
`haxe hide-plugin.hxml`, reopen the project or press Ctrl+F5 in Hide: **New... > 3D > Spinner**.
Rebuild the plugin whenever a prefab class changes. The upstream README of Hide omits
`-lib domkit`, without which the build fails with "Please add -lib domkit".

## Files and shortcuts

`.prefab` / `.l3d`: scene editor; `.fx` / `.fx2d`: effects on a timeline (`hrt.prefab.fx.FX`);
`.shgraph`: shader graphs; `data.cdb`: CastleDB tables (**Database** menu). Prefabs are JSON
(tab-indented, default values omitted): readable and diffable.

In the scene editor: right button + Z Q S D (W also forward) to fly, F to frame the selection,
W / E / R move / rotate / scale gizmos, Ctrl+D duplicate, F2 rename, Ctrl+S save
(all in `bin/defaultProps.json`, keys `key.*`).

## Troubleshooting

| Problem | Cause |
|---|---|
| A node of the level is missing in the game, without error | its type is not compiled into the game: add its class to the hxml |
| A game type is missing from **New...** in Hide | the plugin is not built, not declared in `res/props.json`, or not reloaded |
| `Please add -lib domkit` building the plugin | add `-lib domkit` to `hide-plugin.hxml` |
| `You cannot access the sys package while targeting js` | `include("hrt.prefab")` on the web: list the needed types |
| `haxe hide.hxml` fails | Hide needs recent Heaps and libraries from git, of the same period |
| `h3d.scene.CameraController is abstract` | a recent Heaps: use `h3d.scene.CameraController.OrbitCameraController` (or a fixed camera) |
