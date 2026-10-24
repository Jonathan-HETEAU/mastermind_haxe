import hxd.Key;

/** What the player can do, whatever the device. **/
enum Action {
	Up;
	Down;
	Left;
	Right;
	/** Enter, Space / gamepad A. **/
	Confirm;
	/** Escape, Backspace / gamepad B. **/
	Back;
	/** P / gamepad Start. **/
	Pause;
}

/**
	The keyboard and the gamepads, read as actions.

	The screens never test keys or buttons: they ask `isDown(action)` (held, for movement) or get
	the actions pressed since the last frame (`pressed()`, for menus and moves). Changing a key or
	adding a device only changes this class.
**/
class Controls {
	/** How far a stick must be pushed to count as a direction. **/
	static inline var STICK = 0.5;

	/** The keys of each action. `Key` codes are characters: `Key.Z` is the key labelled Z on any layout. **/
	static final KEYS : Map<Action, Array<Int>> = [
		Up => [Key.UP, Key.Z, Key.W],
		Down => [Key.DOWN, Key.S],
		Left => [Key.LEFT, Key.Q, Key.A],
		Right => [Key.RIGHT, Key.D],
		Confirm => [Key.ENTER, Key.SPACE],
		Back => [Key.ESCAPE, Key.BACKSPACE],
		Pause => [Key.P],
	];

	var pads : Array<hxd.Pad> = [];
	/** Keyboard presses since the last frame, from the events: a quick tap is never missed. **/
	var keyPresses : Array<Action> = [];
	/** Gamepad state at the last frame, to see the presses. **/
	var padBefore = new Map<Action, Bool>();

	/** Called when the window loses the focus (the player switched to another window). **/
	public dynamic function onFocusLost() {}

	public function new() {
		hxd.Window.getInstance().addEventTarget(onEvent);
		// Called for each pad already connected and each one connected later.
		hxd.Pad.wait(p -> {
			pads.push(p);
			p.onDisconnect = () -> pads.remove(p);
		});
	}

	function onEvent( e : hxd.Event ) {
		switch e.kind {
			case EKeyDown:
				for( action => keys in KEYS )
					if( keys.contains(e.keyCode) )
						keyPresses.push(action);
			case EFocusLost:
				onFocusLost();
			default:
		}
	}

	/** Whether the action is held, on the keyboard or any gamepad. **/
	public function isDown( action : Action ) : Bool {
		for( k in KEYS[action] )
			if( Key.isDown(k) )
				return true;
		for( p in pads )
			if( padDown(p, action) )
				return true;
		return false;
	}

	/** The actions pressed since the last call: call it once per frame. **/
	public function pressed() : Array<Action> {
		var list = keyPresses;
		keyPresses = [];
		for( action in Action.createAll() ) {
			var now = false;
			for( p in pads )
				now = now || padDown(p, action);
			if( now && !padBefore[action] )
				list.push(action);
			padBefore[action] = now;
		}
		return list;
	}

	/** Shakes the gamepads (not supported everywhere: errors are ignored). **/
	public function rumble( strength : Float, seconds : Float ) {
		for( p in pads )
			try p.rumble(strength, seconds) catch( _ : Dynamic ) {}
	}

	static function padDown( p : hxd.Pad, action : Action ) : Bool {
		var c = p.config;
		return switch action {
			case Up: p.isDown(c.dpadUp) || p.yAxis < -STICK;
			case Down: p.isDown(c.dpadDown) || p.yAxis > STICK;
			case Left: p.isDown(c.dpadLeft) || p.xAxis < -STICK;
			case Right: p.isDown(c.dpadRight) || p.xAxis > STICK;
			case Confirm: p.isDown(c.A);
			case Back: p.isDown(c.B);
			case Pause: p.isDown(c.start);
		}
	}
}
