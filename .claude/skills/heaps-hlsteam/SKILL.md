---
name: heaps-hlsteam
description: Integrate Steam into a Heaps game running on HashLink with hlsteam - building steam.hdll, steam_appid.txt, initialization, achievements, stats, leaderboards, Steam Cloud saves, the overlay, Steam Deck checks, and shipping the right files. Use it whenever someone wants to release a Heaps/HashLink game on Steam, add achievements or leaderboards, use Steam Cloud, or uses the steam.* API (steam.Api, steam.Cloud, steam.UGC...) or gets errors loading steam.hdll / libsteam_api.
---

# Steam with hlsteam

hlsteam binds the Steamworks SDK for **HashLink** only: the web build has no Steam. Keep every
Steam call in one class that does nothing without Steam, so the same game runs on the web, from
the terminal while developing, and on Steam.

## Build the native part (once per platform)

1. Download the Steamworks SDK (versions 1.61 to 1.64 per the hlsteam README) from
   https://partner.steamgames.com/downloads/list, and put it in `$(haxelib libpath hlsteam)sdk`.
2. `export HASHLINK_SRC=<hashlink sources>` (the same HashLink as the `hl` you run).
3. Linux / macOS: `make` in the hlsteam folder (`make install` copies `steam.hdll` and
   `libsteam_api` to `/usr/local/lib`); Windows: `hlsteam.sln` in Visual Studio.

Ship next to the game: `steam.hdll` and the SDK's `steam_api64.dll` (Windows),
`libsteam_api.so` (Linux) or `libsteam_api.dylib` (macOS). While developing, put a
`steam_appid.txt` file with the app id next to the game (480 is Valve's test app): Steam then
accepts a game not launched from the client. Do not ship that file.

## Use it from one class

`${CLAUDE_SKILL_DIR}/assets/Steam.hx` is that class, compile-checked for HashLink with and
without `-lib hlsteam` and for the web: `init`, `unlock(achievement)`, `addStat`, `submitScore`,
`cloudWrite` / `cloudRead`, and `onOverlay` to pause the game. Copy it into the game and set
`APP_ID`. `#if hlsteam` is defined by `-lib hlsteam`, so the web hxml simply omits the library.

```haxe
static function main() {
	if( !Steam.init() )     // before anything else: false = Steam relaunches the game, quit
		return;
	hxd.Res.initEmbed();
	new Main();
}
```

```hxml
# build-steam.hxml: the HashLink build for Steam
-cp src
-lib heaps
-lib hlsdl
-lib hlsteam
-main Main
-hl bin/game.hl
```

How the API behaves (from `steam/Api.hx`):

- `steam.Api.init(appId)` returns `false` when the Steam API cannot start (client not running,
  no app id...); `steam.Api.active` then stays `false` and every call returns `false` / does
  nothing.
  `init` registers `steam.Api.sync` in the main loop: callbacks run without more code.
- Achievements and stats are defined in the Steamworks partner site by their **API name**.
  `setAchievement(name)` / `setStatInt(name, v)` change them locally; `storeStats()` sends them
  (and shows the "achievement unlocked" popup).
- Leaderboards: `uploadLeaderboardScore(new steam.Api.LeaderboardScore(name, score, detail))`;
  results come through `steam.Api.whenLeaderboardScoreUploaded` / `whenLeaderboardScoreDownloaded`.
- Steam Cloud: `steam.Cloud.write(name, bytes)`, `read`, `exists`, `isEnabled()`; the files are
  synchronized by Steam. Keep a local save too (see heaps-hxbit for the bytes).
- `steam.Api.onOverlay = open -> ...`: pause when the overlay opens.
- Also: `getCurrentGameLanguage()`, `isSteamRunningOnSteamDeck()`, `isDlcInstalled(id)`,
  `openOverlay(url)`, the `steam.ugc` package (Workshop items), `steam.Matchmaking` / `steam.Networking`
  (lobbies, P2P), `steam.Controller`. The hlsteam README marks stats and controllers as not
  well tested.

Look up any of them with the **heaps-docs** skill (`lookup.sh steam`), or read
`$(haxelib libpath hlsteam)steam/`. `example/Test.hx` of hlsteam tests achievements, cloud and
UGC.

## Testing

Nothing of this can be tested without the Steam client and an app id: check that the game
**still works without Steam** (web build, `hl` without `steam_appid.txt` on a machine without
Steam) and test the Steam features with the client running and `steam_appid.txt` set to the
game's id (or 480 to try the API).
