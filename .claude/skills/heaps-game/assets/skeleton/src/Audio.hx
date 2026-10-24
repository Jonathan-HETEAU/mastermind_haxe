/**
	The sound effects: `res/sound/<name>.wav` (or `.mp3`; `.ogg` on HashLink only), or one of its
	variants picked at random (`<name>_2.wav`, `<name>_3.wav`...). A missing file is silent, so the
	game runs before its sounds exist, and this list is the list of the sounds to make.
**/
enum abstract Sfx(String) to String {
	var UiMove = "ui_move";
	var UiConfirm = "ui_confirm";
	var UiBack = "ui_back";
	var Pause = "pause";
	var Step = "step";
	var Bump = "bump";
	var Goal = "goal";
}

/** The musics, played in a loop: `res/music/<name>.mp3` (or `.wav`). **/
enum abstract Music(String) to String {
	var Title = "title";
	var Game = "game";
}

/** Plays the sounds and the music, following the options. **/
class Audio {
	static inline var MUSIC_VOLUME = 0.6;
	/** Music volume while the game is paused. **/
	static inline var DUCKED_VOLUME = 0.2;

	public static var soundsOn = true;
	public static var musicOn(default, set) = true;

	static var current : Null<Music>;
	static var channel : Null<hxd.snd.Channel>;
	static var ducked = false;
	static var found = new Map<String, Array<hxd.res.Sound>>();

	public static function play( sfx : Sfx, volume = 1. ) {
		if( !soundsOn )
			return;
		var variants = find('sound/$sfx');
		if( variants.length > 0 )
			variants[Std.random(variants.length)].play(false, volume);
	}

	/** Plays `m` in a loop, unless it is already the current music. **/
	public static function music( m : Music ) {
		if( m == current )
			return;
		current = m;
		restartMusic();
	}

	/** Lowers the music (pause) or puts it back. **/
	public static function duck( on : Bool ) {
		ducked = on;
		if( channel != null )
			channel.volume = ducked ? DUCKED_VOLUME : MUSIC_VOLUME;
	}

	static function set_musicOn( on : Bool ) {
		musicOn = on;
		restartMusic();
		return on;
	}

	static function restartMusic() {
		if( channel != null ) {
			channel.stop();
			channel = null;
		}
		if( !musicOn || current == null )
			return;
		var s = find('music/$current');
		if( s.length > 0 )
			channel = s[0].play(true, ducked ? DUCKED_VOLUME : MUSIC_VOLUME);
	}

	/** The files of a sound and of its variants, looked up once. **/
	static function find( base : String ) : Array<hxd.res.Sound> {
		var list = found.get(base);
		if( list == null ) {
			list = [];
			var i = 1;
			while( true ) {
				var s = file(i == 1 ? base : '${base}_$i');
				if( s == null )
					break;
				list.push(s);
				i++;
			}
			found.set(base, list);
		}
		return list;
	}

	static function file( path : String ) : Null<hxd.res.Sound> {
		for( ext in ["wav", "mp3" #if hl , "ogg" #end] )
			if( hxd.Res.loader.exists('$path.$ext') )
				return hxd.Res.load('$path.$ext').toSound();
		return null;
	}
}
