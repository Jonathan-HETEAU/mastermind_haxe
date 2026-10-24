/** What is saved. Add fields freely: `hxd.Save.load` fills the ones missing in older saves. **/
typedef SaveData = {
	/** The best score ever made. **/
	var best : Int;
	var music : Bool;
	var sounds : Bool;
}

/**
	The best score and the options, kept with `hxd.Save`: `asteroids.sav` in the working directory
	on HashLink, the `localStorage` of the browser on the web. Saved at the end of a game and when
	an option changes.
**/
class Progress {
	static inline var NAME = "asteroids";

	static var data : SaveData;

	static function get() : SaveData {
		if( data == null ) {
			var defaults : SaveData = { best : 0, music : true, sounds : true };
			// Returns the defaults when there is no save or it cannot be read; fills the fields
			// added since the save was written.
			data = hxd.Save.load(defaults, NAME);
		}
		return data;
	}

	public static function best() : Int {
		return get().best;
	}

	/** Records the score of a game; returns whether it is a new best score (then saved). **/
	public static function submitScore( score : Int ) : Bool {
		if( score <= get().best )
			return false;
		get().best = score;
		write();
		return true;
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
