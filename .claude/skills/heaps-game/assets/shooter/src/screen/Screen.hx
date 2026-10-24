package screen;

import Controls.Action;

/**
	A screen of the game: its own 2D scene, its frames and its actions. `Main` keeps the screens
	in a stack and only shows and updates the top one.
**/
class Screen {
	public static inline var BACKGROUND = 0x0A0A18;

	public var scene(default, null) : h2d.Scene;

	public function new() {
		scene = new h2d.Scene();
		// A fixed virtual resolution, scaled by whole numbers to fit the window: crisp pixels.
		scene.scaleMode = LetterBox(Main.WIDTH, Main.HEIGHT, true);
		// The field, a little lighter than the bars around it when the window has another shape.
		new h2d.Bitmap(h2d.Tile.fromColor(BACKGROUND, Main.WIDTH, Main.HEIGHT), scene);
	}

	/** The screen is shown: first time, or back from a screen pushed over it. **/
	public function onShow() {}

	/** An action was pressed (menus, moves). **/
	public function onAction( a : Action ) {}

	/** Every frame; `dt` is in seconds. **/
	public function update( dt : Float ) {}

	/** The window lost the focus: the player is doing something else. **/
	public function onFocusLost() {}

	public function dispose() {
		scene.dispose();
	}

	/** A text centered on x, its top at y. **/
	function text( s : String, x : Float, y : Float, scale = 1., ?parent : h2d.Object ) : h2d.Text {
		var t = new h2d.Text(hxd.res.DefaultFont.get(), parent == null ? scene : parent);
		t.text = s;
		t.setScale(scale);
		t.setPosition(x - t.textWidth * scale / 2, y);
		return t;
	}
}
