import hxd.Key;

/** What the player can do, whatever the device. **/
enum Action {
	/** Moves the cursor of the current row. **/
	Left;
	Right;
	/** Selects the previous / next color of the palette. **/
	PrevColor;
	NextColor;
	/** Selects a color of the palette by its number (0 to 5) and places it. **/
	PickColor(index:Int);
	/** Places the selected color under the cursor. **/
	Place;
	/** Empties the cell under the cursor, or the one before when it is already empty. **/
	Erase;
	/** Validates the current row; plays again once the game is over. **/
	Validate;
	Restart;
}

/**
	The keyboard and the gamepads, read as actions.

	The game never tests keys or buttons: it gets the actions pressed since the last frame
	(`pressed()`). Changing a key or adding a device only changes this class.
**/
class Controls {
	/** How far a stick must be pushed to count as a direction. **/
	static inline var STICK = 0.5;

	/**
		The keys of each action. `Key` codes are characters: `Key.Z` is the key labelled Z on any
		layout, so Z Q S D (AZERTY) and W A S D (QWERTY) both work, with the arrows.
	**/
	static final KEYS:Map<Action, Array<Int>> = [
		Left => [Key.LEFT, Key.Q, Key.A],
		Right => [Key.RIGHT, Key.D],
		PrevColor => [Key.UP, Key.Z, Key.W],
		NextColor => [Key.DOWN, Key.S],
		Place => [Key.SPACE],
		Erase => [Key.BACKSPACE, Key.DELETE],
		Validate => [Key.ENTER, Key.NUMPAD_ENTER],
		Restart => [Key.R],
	];

	/** The digit keys 1 to 6, on the main keyboard and the numeric keypad, pick the colors. **/
	static final COLOR_KEYS:Array<Array<Int>> = [for (i in 0...6) [Key.NUMBER_1 + i, Key.NUMPAD_1 + i]];

	/** The gamepad actions, and whether their button or direction is held. **/
	static final PAD_ACTIONS:Array<Action> = [Left, Right, PrevColor, NextColor, Place, Erase, Validate, Restart];

	private var pads:Array<hxd.Pad> = [];
	/** Keyboard presses since the last frame, from the events: a quick tap is never missed. **/
	private var keyPresses:Array<Action> = [];
	/** Gamepad state at the last frame, to see the presses. **/
	private var padBefore = new Map<Action, Bool>();

	public function new() {
		// On the window rather than the scene: after a click on an h2d.Interactive, the scene
		// listeners no longer get the keys.
		hxd.Window.getInstance().addEventTarget(onEvent);
		// Called for each pad already connected and each one connected later.
		hxd.Pad.wait(function(p) {
			pads.push(p);
			p.onDisconnect = function() pads.remove(p);
		});
	}

	private function onEvent(e:hxd.Event) {
		if (e.kind != EKeyDown)
			return;
		for (action => keys in KEYS)
			if (keys.contains(e.keyCode))
				keyPresses.push(action);
		for (i => keys in COLOR_KEYS)
			if (keys.contains(e.keyCode))
				keyPresses.push(PickColor(i));
	}

	/** The actions pressed since the last call: call it once per frame. **/
	public function pressed():Array<Action> {
		var list = keyPresses;
		keyPresses = [];
		for (action in PAD_ACTIONS) {
			var now = false;
			for (p in pads)
				now = now || padDown(p, action);
			if (now && !padBefore[action])
				list.push(action);
			padBefore[action] = now;
		}
		return list;
	}

	/** D-pad or stick: cursor and color; A places, B or X erases, Y validates, Back restarts. **/
	private static function padDown(p:hxd.Pad, action:Action):Bool {
		var c = p.config;
		return switch action {
			case Left: p.isDown(c.dpadLeft) || p.xAxis < -STICK;
			case Right: p.isDown(c.dpadRight) || p.xAxis > STICK;
			case PrevColor: p.isDown(c.dpadUp) || p.yAxis < -STICK;
			case NextColor: p.isDown(c.dpadDown) || p.yAxis > STICK;
			case Place: p.isDown(c.A);
			case Erase: p.isDown(c.B) || p.isDown(c.X);
			case Validate: p.isDown(c.Y);
			case Restart: p.isDown(c.back);
			case PickColor(_): false;
		}
	}
}
