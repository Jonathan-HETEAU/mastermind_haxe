/** The sounds of the game: the files of res/sound, made by tools/audio/make_sounds.py. **/
enum Sound {
	/** A stone dropped into a cup of the board. **/
	Place;
	/** A stone taken from the velvet tray. **/
	Pick;
	/** A stone lifted out of its cup. **/
	Remove;
	/** The cursor moves along the row. **/
	Move;
	/** The brass button that validates a row. **/
	Button;
	/** A gold peg (right color, right place) or a silver one (right color, wrong place). **/
	PegGood;
	PegBad;
	/** An action that cannot be done. **/
	Invalid;
	/** The walnut lid slides away from the secret code. **/
	Lid;
	Win;
	Lose;
	/** The stones gathered for a new game. **/
	Restart;
}

/**
	Plays the sounds by name, now or after a delay. A sound with variants (`place_1.wav`,
	`place_2.wav`...) plays one of them at random, so that frequent sounds do not repeat; a
	missing file stays silent. Sounds can be turned off (key M), and the choice is saved.
**/
class Audio {
	public static var on(default, set):Bool = load();

	private static var pending:Array<{delay:Float, sound:Sound, volume:Float}> = [];
	private static var variants = new Map<Sound, Array<String>>();

	/** Plays a sound, after `delay` seconds if given. **/
	public static function play(sound:Sound, delay:Float = 0, volume:Float = 1) {
		if (!on)
			return;
		if (delay > 0)
			pending.push({delay: delay, sound: sound, volume: volume});
		else
			playNow(sound, volume);
	}

	/** Plays the delayed sounds when their time comes: call it every frame. **/
	public static function update(dt:Float) {
		for (p in pending.copy()) {
			p.delay -= dt;
			if (p.delay <= 0) {
				pending.remove(p);
				playNow(p.sound, p.volume);
			}
		}
	}

	/** Forgets the delayed sounds (a new game starts). **/
	public static function cancel() {
		pending = [];
	}

	private static function playNow(sound:Sound, volume:Float) {
		var files = filesOf(sound);
		if (files.length == 0)
			return;
		var file = files[Std.random(files.length)];
		#if debug
		trace('sound $file');
		#end
		hxd.Res.load(file).toSound().play(false, volume);
	}

	/** `res/sound/<name>.wav`, or its variants `<name>_1.wav`, `<name>_2.wav`... (`PegGood` is `peg_good`). **/
	private static function filesOf(sound:Sound):Array<String> {
		var files = variants.get(sound);
		if (files == null) {
			var name = ~/([a-z])([A-Z])/g.replace(sound.getName(), "$1_$2").toLowerCase();
			files = [];
			var i = 1;
			while (hxd.Res.loader.exists('sound/${name}_$i.wav'))
				files.push('sound/${name}_${i++}.wav');
			if (files.length == 0 && hxd.Res.loader.exists('sound/$name.wav'))
				files.push('sound/$name.wav');
			variants.set(sound, files);
		}
		return files;
	}

	static function set_on(value:Bool):Bool {
		on = value;
		if (!value)
			cancel();
		hxd.Save.save({soundOn: value}, "mastermind");
		return value;
	}

	static function load():Bool {
		return hxd.Save.load({soundOn: true}, "mastermind").soundOn;
	}
}
