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
	/** Space, X / gamepad A, X, RB, RT. **/
	Fire;
}

/**
	The keyboard and the gamepads, read as actions.

	The screens never test keys or buttons: they ask `isDown(action)` (held), `moveX()` /
	`moveY()` (the direction, analog with a stick) or get the actions pressed since the last frame
	(`pressed()`, for menus). Changing a key or adding a device only changes this class.
**/
class Controls {
	/** How far a stick must be pushed to count as a direction in menus. **/
	static inline var STICK = 0.5;
	/** Below this, a stick is at rest (worn sticks never quite go back to 0). **/
	static inline var DEAD_ZONE = 0.2;

	/** The keys of each action. `Key` codes are characters: `Key.Z` is the key labelled Z on any
		layout, so Z Q S D (AZERTY) and W A S D (QWERTY) both work. **/
	static final KEYS : Map<Action, Array<Int>> = [
		Up => [Key.UP, Key.Z, Key.W],
		Down => [Key.DOWN, Key.S],
		Left => [Key.LEFT, Key.Q, Key.A],
		Right => [Key.RIGHT, Key.D],
		Confirm => [Key.ENTER, Key.SPACE],
		Back => [Key.ESCAPE, Key.BACKSPACE],
		Pause => [Key.P],
		Fire => [Key.SPACE, Key.X],
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
			p.axisDeadZone = DEAD_ZONE;
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

	/** The horizontal direction asked, -1 (left) to 1 (right): keys and D-pad give -1, 0 or 1,
		a stick anything in between. **/
	public function moveX() : Float {
		return direction(Left, Right, p -> p.xAxis);
	}

	/** The vertical direction asked, -1 (up) to 1 (down). **/
	public function moveY() : Float {
		return direction(Up, Down, p -> p.yAxis);
	}

	function direction( minus : Action, plus : Action, axis : hxd.Pad -> Float ) : Float {
		var v = 0.;
		for( k in KEYS[minus] )
			if( Key.isDown(k) ) { v -= 1; break; }
		for( k in KEYS[plus] )
			if( Key.isDown(k) ) { v += 1; break; }
		for( p in pads ) {
			var c = p.config;
			if( p.isDown(minus == Left ? c.dpadLeft : c.dpadUp) ) v -= 1;
			if( p.isDown(plus == Right ? c.dpadRight : c.dpadDown) ) v += 1;
			v += axis(p);
		}
		return v < -1 ? -1 : v > 1 ? 1 : v;
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
			case Fire: p.isDown(c.A) || p.isDown(c.X) || p.isDown(c.RB) || p.isDown(c.RT);
		}
	}
}
