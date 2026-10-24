import screen.Screen;

/**
	The application: a stack of screens. The top one is shown, updated and gets the actions;
	`push` puts a screen over the current one (an options screen over the title), `pop` comes
	back to it, `show` replaces them all.
**/
class Main extends hxd.App {
	/** Size of the virtual screen, in pixels: the size of the field of the game. **/
	public static inline var WIDTH = model.Field.WIDTH;
	public static inline var HEIGHT = model.Field.HEIGHT;

	public static var inst(default, null) : Main;

	public var controls(default, null) : Controls;

	var screens : Array<Screen> = [];

	override function init() {
		inst = this;
		engine.backgroundColor = 0x000000;
		controls = new Controls();
		controls.onFocusLost = () -> screens[screens.length - 1].onFocusLost();
		Audio.musicOn = Progress.musicOn();
		Audio.soundsOn = Progress.soundsOn();
		show(new screen.TitleScreen());
	}

	public function push( s : Screen ) {
		screens.push(s);
		// false: the previous scene is kept, it comes back with pop().
		setScene(s.scene, false);
		s.onShow();
	}

	public function pop() {
		screens.pop().dispose();
		var top = screens[screens.length - 1];
		setScene(top.scene, false);
		top.onShow();
	}

	public function show( s : Screen ) {
		while( screens.length > 0 )
			screens.pop().dispose();
		push(s);
	}

	override function update( dt : Float ) {
		// The actions go to the top screen; a screen may change the stack while handling one.
		for( a in controls.pressed() )
			screens[screens.length - 1].onAction(a);
		screens[screens.length - 1].update(dt);
	}

	static function main() {
		#if hl
		hxd.res.Resource.LIVE_UPDATE = true;
		hxd.Res.initLocal();
		#else
		hxd.Res.initEmbed();
		#end
		new Main();
	}
}
