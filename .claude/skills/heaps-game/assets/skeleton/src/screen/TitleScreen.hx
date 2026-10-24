package screen;

import Controls.Action;

/** The title: continue, new game, options, quit. **/
class TitleScreen extends Screen {
	var menu : ui.Menu;

	public function new() {
		super();
		text("MY GAME", Main.WIDTH / 2, 24, 3);
		menu = new ui.Menu(scene);
		var hasGame = Progress.hasGame();
		if( hasGame )
			menu.add('Continue (level ${Progress.level() + 1})', () -> Main.inst.show(new GameScreen(Progress.level())));
		menu.add("New game", () -> Main.inst.show(new GameScreen(0)));
		var first = hasGame ? 2 : 1;
		menu.add(musicLabel(), () -> {
			Audio.musicOn = !Audio.musicOn;
			saveOptions();
			menu.setLabel(first, musicLabel());
		});
		menu.add(soundLabel(), () -> {
			Audio.soundsOn = !Audio.soundsOn;
			saveOptions();
			menu.setLabel(first + 1, soundLabel());
		});
		#if hl
		menu.add("Quit", () -> hxd.System.exit());
		#end
		menu.setPosition(Main.WIDTH / 2 - menu.outerWidth / 2, 80);
	}

	override function onShow() {
		Audio.music(Title);
	}

	override function onAction( a : Action ) {
		menu.onAction(a);
	}

	static function musicLabel() return "Music: " + (Audio.musicOn ? "on" : "off");

	static function soundLabel() return "Sounds: " + (Audio.soundsOn ? "on" : "off");

	static function saveOptions() {
		Progress.saveOptions(Audio.musicOn, Audio.soundsOn);
	}
}
