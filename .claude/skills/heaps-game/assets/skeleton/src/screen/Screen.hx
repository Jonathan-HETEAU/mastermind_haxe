package screen;

import Controls.Action;

/**
	A screen of the game: its own 2D scene, its frames and its actions. `Main` keeps the screens
	in a stack and only shows and updates the top one.
**/
class Screen {
	public var scene(default, null) : h2d.Scene;

	public function new() {
		scene = new h2d.Scene();
		// A fixed virtual resolution, scaled by whole numbers to fit the window: crisp pixels.
		scene.scaleMode = LetterBox(Main.WIDTH, Main.HEIGHT, true);
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

	function text( s : String, x : Float, y : Float, scale = 1. ) : h2d.Text {
		var t = new h2d.Text(hxd.res.DefaultFont.get(), scene);
		t.text = s;
		t.setScale(scale);
		t.setPosition(x - t.textWidth * scale / 2, y);
		return t;
	}
}
