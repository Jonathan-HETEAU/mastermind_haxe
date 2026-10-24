package screen;

import Controls.Action;

/** The title: the best score, play, music and sound options, quit (HashLink). **/
class TitleScreen extends Screen {
	var stars : view.Starfield;
	var ship : h2d.Graphics;
	var menu : ui.Menu;
	var time = 0.;

	public function new() {
		super();
		stars = new view.Starfield(Main.WIDTH, Main.HEIGHT, scene);
		text("ASTÉROÏDES", Main.WIDTH / 2, 6, 3).textColor = view.Shapes.SHIP_COLOR;
		var best = Progress.best();
		var bestText = text(best > 0 ? 'Meilleur score : $best' : "Pas encore de record", Main.WIDTH / 2, 50);
		bestText.textColor = 0xFFD080;
		ship = new h2d.Graphics(scene);

		menu = new ui.Menu(scene);
		menu.add("Jouer", () -> Main.inst.show(new GameScreen()));
		// No music option before there is a music (res/music/README.txt).
		if( Audio.hasMusic() ) {
			var index = menu.count;
			menu.add(musicLabel(), () -> {
				Audio.musicOn = !Audio.musicOn;
				saveOptions();
				menu.setLabel(index, musicLabel());
			});
		}
		var index = menu.count;
		menu.add(soundLabel(), () -> {
			Audio.soundsOn = !Audio.soundsOn;
			saveOptions();
			menu.setLabel(index, soundLabel());
		});
		#if hl
		menu.add("Quitter", () -> hxd.System.exit());
		#end
		menu.setPosition(Main.WIDTH / 2 - menu.outerWidth / 2, 72);

		for( i => line in ["Bouger : flèches, ZQSD, WASD ou stick", "Tirer : Espace ou A     Pause : Échap ou Start"] )
			text(line, Main.WIDTH / 2, Main.HEIGHT - 32 + i * 13).textColor = 0x8890B0;
	}

	override function onShow() {
		Audio.music(Title);
	}

	override function onAction( a : Action ) {
		menu.onAction(a);
	}

	override function update( dt : Float ) {
		time += dt;
		stars.update(dt);
		// A ship hovering left of the menu, for the look.
		ship.clear();
		view.Shapes.ship(ship, Main.WIDTH / 2 - 90, 96 + Math.sin(time * 2) * 3, 0.6 + Math.random() * 0.4, 2);
	}

	static function musicLabel() return "Musique : " + (Audio.musicOn ? "oui" : "non");

	static function soundLabel() return "Sons : " + (Audio.soundsOn ? "oui" : "non");

	static function saveOptions() {
		Progress.saveOptions(Audio.musicOn, Audio.soundsOn);
	}
}
