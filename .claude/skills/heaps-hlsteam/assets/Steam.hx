/**
	The Steam features of the game, in one place. Every call works without Steam (web build, a
	build launched outside Steam, a machine without the client): it then does nothing.
**/
class Steam {
	/** The Steam app id of the game (480 is Valve's test app "Spacewar"). **/
	public static inline var APP_ID = 480;

	public static var active(get, never) : Bool;

	/**
		Call first in `main`, before creating the app. Returns `false` if the game must quit
		because Steam restarts it through the Steam client.
	**/
	public static function init() : Bool {
		#if hlsteam
		// Not launched by Steam (and no steam_appid.txt next to the game): Steam relaunches it.
		if( steam.Api.restartIfNecessary(APP_ID) )
			return false;
		if( steam.Api.init(APP_ID) )
			steam.Api.onOverlay = open -> onOverlay(open);
		#end
		return true;
	}

	/** The Steam overlay opens (`true`) or closes: pause the game. **/
	public static dynamic function onOverlay( open : Bool ) {}

	public static function unlock( achievement : String ) {
		#if hlsteam
		if( steam.Api.active && !steam.Api.getAchievement(achievement) ) {
			steam.Api.setAchievement(achievement);
			steam.Api.storeStats(); // sends it: the "achievement unlocked" popup appears
		}
		#end
	}

	public static function addStat( stat : String, delta : Int ) {
		#if hlsteam
		if( steam.Api.active ) {
			steam.Api.setStatInt(stat, steam.Api.getStatInt(stat) + delta);
			steam.Api.storeStats();
		}
		#end
	}

	public static function submitScore( leaderboard : String, score : Int ) {
		#if hlsteam
		if( steam.Api.active )
			steam.Api.uploadLeaderboardScore(new steam.Api.LeaderboardScore(leaderboard, score, 0));
		#end
	}

	/** Writes a save to Steam Cloud; returns `false` without Steam: keep a local copy too. **/
	public static function cloudWrite( name : String, data : haxe.io.Bytes ) : Bool {
		#if hlsteam
		return steam.Api.active && steam.Cloud.isEnabled() && steam.Cloud.write(name, data);
		#else
		return false;
		#end
	}

	public static function cloudRead( name : String ) : Null<haxe.io.Bytes> {
		#if hlsteam
		if( steam.Api.active && steam.Cloud.isEnabled() && steam.Cloud.exists(name) )
			return steam.Cloud.read(name);
		#end
		return null;
	}

	static function get_active() {
		#if hlsteam
		return steam.Api.active;
		#else
		return false;
		#end
	}
}
