#!/bin/sh
# Creates a Heaps game project that builds for the web (WebGL) and for HashLink.
#
#   new-project.sh <dir> [--3d] [--domkit]
#
#   --3d      the starting scene is 3D (a lit, turning cube) instead of 2D (a square to move)
#   --domkit  adds DomKit: a HUD component (src/ui/HudComp.hx) styled by res/ui/style.css
#
# The folder must not exist yet. Nothing is downloaded: the libraries must be installed
# (haxelib heaps, hlsdl for HashLink, domkit with --domkit).
set -e

usage() { echo "usage: $0 <dir> [--3d] [--domkit]" >&2; exit 2; }
[ $# -ge 1 ] || usage
dir=$1; shift
mode=2d; domkit=no
for a in "$@"; do
	case $a in
		--3d) mode=3d ;;
		--domkit) domkit=yes ;;
		*) usage ;;
	esac
done
[ -e "$dir" ] && { echo "$dir already exists" >&2; exit 1; }
name=$(basename "$dir")

mkdir -p "$dir/src" "$dir/res"

libs="-lib heaps"
macro=""
if [ $domkit = yes ]; then
	libs="$libs
-lib domkit"
	# DomKit finds a component <hud> in the class ui.HudComp; older DomKit versions need the path.
	macro='
--macro domkit.Macros.registerComponentsPath("ui.$Comp")'
fi

cat > "$dir/build-js.hxml" <<EOF
-cp src
$libs$macro
-main Main
-js bin/game.js
EOF

cat > "$dir/build-hl.hxml" <<EOF
-cp src
$libs$macro
-lib hlsdl
-main Main
-hl bin/game.hl
EOF

cat > "$dir/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>$name</title>
<style>html, body { margin: 0; padding: 0; height: 100%; overflow: hidden; background: #000; } #webgl { width: 100%; height: 100%; }</style>
</head>
<body>
<!-- globalEvents="1": the game gets the keyboard without a click on the canvas first. -->
<canvas id="webgl" globalEvents="1"></canvas>
<script src="bin/game.js"></script>
</body>
</html>
EOF

# res/.tmp/: what Heaps converts from the resources (fonts, models), rebuilt when needed.
cat > "$dir/.gitignore" <<'EOF'
bin/
*.sav
res/.tmp/
EOF

# hxd.Res needs a res/ folder; this file keeps it in git and is a resource like any other.
echo "Resources of the game: images, sounds, fonts, levels. Read them with hxd.Res (hxd.Res.res_readme for this file)." > "$dir/res/res_readme.txt"

main_static='
	static function main() {
		#if hl
		// Reads res/ from the disk and reloads a file when it changes (run hl from the project folder).
		hxd.res.Resource.LIVE_UPDATE = true;
		hxd.Res.initLocal();
		#else
		// Embeds res/ in the JavaScript file.
		hxd.Res.initEmbed();
		#end
		new Main();
	}
}'

hud_field=""; hud_init=""; hud_update=""
if [ $domkit = yes ]; then
	hud_field='
	var style : h2d.domkit.Style;
	var hud : ui.HudComp;
'
	hud_init='
		hud = new ui.HudComp(s2d);
		style = new h2d.domkit.Style();
		style.load(hxd.Res.ui.style); // reloaded when the file changes (HashLink with initLocal)
		style.addObject(hud);
'
	hud_update='
		style.sync(dt);'
fi

if [ $mode = 2d ]; then
	text_init='
		var help = new h2d.Text(hxd.res.DefaultFont.get(), s2d);
		help.text = "Arrows, Z Q S D, W A S D or a gamepad to move";
		help.setPosition(8, HEIGHT - 20);
'
	[ $domkit = yes ] && text_init=""
	cat > "$dir/src/Main.hx" <<EOF
/**
	The game: a square that moves with the keyboard or a gamepad.
**/
class Main extends hxd.App {

	/** Size of the virtual screen, in pixels: the scene is scaled to fit the window. **/
	static inline var WIDTH = 320;
	static inline var HEIGHT = 180;

	/** Speed of the square, in pixels per second. **/
	static inline var SPEED = 120.;

	var player : h2d.Bitmap;
	/** A dummy pad until a real one is connected: no null checks. **/
	var pad = hxd.Pad.createDummy();
$hud_field
	override function init() {
		s2d.scaleMode = LetterBox(WIDTH, HEIGHT, true);
		engine.backgroundColor = 0x202030;
		player = new h2d.Bitmap(h2d.Tile.fromColor(0xE04040, 16, 16), s2d);
		player.setPosition((WIDTH - 16) / 2, (HEIGHT - 16) / 2);
$text_init$hud_init
		hxd.Pad.wait(p -> pad = p);
	}

	override function update( dt : Float ) {
		var dx = pad.xAxis, dy = pad.yAxis;
		// hxd.Key codes are characters: Key.Q is the key labelled Q, whatever the layout.
		if( hxd.Key.isDown(hxd.Key.LEFT) || hxd.Key.isDown(hxd.Key.Q) || hxd.Key.isDown(hxd.Key.A) ) dx = -1;
		if( hxd.Key.isDown(hxd.Key.RIGHT) || hxd.Key.isDown(hxd.Key.D) ) dx = 1;
		if( hxd.Key.isDown(hxd.Key.UP) || hxd.Key.isDown(hxd.Key.Z) || hxd.Key.isDown(hxd.Key.W) ) dy = -1;
		if( hxd.Key.isDown(hxd.Key.DOWN) || hxd.Key.isDown(hxd.Key.S) ) dy = 1;
		// dt is in seconds: the speed is the same at any frame rate.
		player.x = hxd.Math.clamp(player.x + dx * SPEED * dt, 0, WIDTH - player.tile.width);
		player.y = hxd.Math.clamp(player.y + dy * SPEED * dt, 0, HEIGHT - player.tile.height);$hud_update
	}
$main_static
EOF
else
	cat > "$dir/src/Main.hx" <<EOF
/**
	The game: a lit cube that turns, seen by a fixed camera.
**/
class Main extends hxd.App {

	var cube : h3d.scene.Mesh;
$hud_field
	override function init() {
		engine.backgroundColor = 0x202030;
		s3d.camera.pos.set(4, -6, 4);
		s3d.camera.target.set(0, 0, 0);

		// The unit cube is centered on its origin; the primitive is shared, the mesh is ours.
		cube = new h3d.scene.Mesh(h3d.prim.Cube.defaultUnitCube(), s3d);
		cube.material.color.setColor(0xE04040);
		var light = new h3d.scene.fwd.DirLight(new h3d.Vector(0.5, 0.8, -1), s3d);
		light.enableSpecular = true;
		cast(s3d.lightSystem, h3d.scene.fwd.LightSystem).ambientLight.set(0.3, 0.3, 0.3);
$hud_init
	}

	override function update( dt : Float ) {
		// dt is in seconds: half a turn per second at any frame rate.
		cube.rotate(0, 0, Math.PI * dt);$hud_update
	}
$main_static
EOF
fi

if [ $domkit = yes ]; then
	mkdir -p "$dir/src/ui" "$dir/res/ui"
	cat > "$dir/src/ui/HudComp.hx" <<'EOF'
package ui;

/**
	The HUD: a line of text at the top of the screen. Its look is in res/ui/style.css.
**/
@:uiComp("hud")
class HudComp extends h2d.Flow implements h2d.domkit.Object {

	static var SRC = <hud>
		<text public id="label" text={"Arrows or gamepad to move"}/>
	</hud>;

	public function new( ?parent ) {
		super(parent);
		initComponent();
	}
}
EOF
	cat > "$dir/res/ui/style.css" <<'EOF'
hud {
	padding: 8;
	background: rgba(0, 0, 0, 0.5); /* #RRGGBBAA is not supported: the alpha goes in rgba() */
}

hud text {
	color: #FFD080;
}
EOF
fi

cat > "$dir/README.md" <<EOF
# $name

| Command | Result |
|---|---|
| \`haxe build-js.hxml\` | \`bin/game.js\`: serve the folder (\`npx http-server\` or \`python3 -m http.server\`) and open \`index.html\` |
| \`haxe build-hl.hxml\` | \`bin/game.hl\`: run \`hl bin/game.hl\` from this folder (it reads \`res/\`) |
EOF

echo "created $dir ($mode$( [ $domkit = yes ] && echo ', domkit'))"
