/** What is saved. Add fields freely: `hxd.Save.load` fills the ones missing in older saves. **/
typedef SaveData = {
	/** The level to continue from, -1 when there is no game in progress. **/
	var level : Int;
	var music : Bool;
	var sounds : Bool;
}

/**
	The saved game and options, kept with `hxd.Save`: `game.sav` in the working directory on
	HashLink, the `localStorage` of the browser on the web. Saved at the start of each level and
	when an option changes.
**/
class Progress {
	static inline var NAME = "game";

	static var data : SaveData;

	static function get() : SaveData {
		if( data == null ) {
			var defaults : SaveData = { level : -1, music : true, sounds : true };
			// The defaults when there is no save or it cannot be read; the fields added since
			// the save was written get their default value.
			data = hxd.Save.load(defaults, NAME);
		}
		return data;
	}

	public static function hasGame() : Bool {
		return get().level >= 0;
	}

	public static function level() : Int {
		return get().level;
	}

	public static function saveLevel( level : Int ) {
		get().level = level;
		write();
	}

	/** The last level is won: nothing to continue. **/
	public static function clearGame() {
		get().level = -1;
		write();
	}

	public static function musicOn() : Bool {
		return get().music;
	}

	public static function soundsOn() : Bool {
		return get().sounds;
	}

	public static function saveOptions( music : Bool, sounds : Bool ) {
		get().music = music;
		get().sounds = sounds;
		write();
	}

	static function write() {
		hxd.Save.save(data, NAME);
	}
}
