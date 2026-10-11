import view.BoardView;

/**
	Entry point: the application and the life of the games.

	The board is drawn on a virtual screen of `BoardView.WIDTH` x `BoardView.HEIGHT` pixels, scaled
	to the window with `LetterBox` (black bars, same aspect ratio): the game code never deals with
	the real size of the window.
**/
class Main extends hxd.App {
	var game:Game;

	override function init() {
		hxd.Window.getInstance().title = "Mastermind";
		s2d.scaleMode = LetterBox(BoardView.WIDTH, BoardView.HEIGHT);
		newGame();
	}

	/** Replaces the current game, if any, by a new one with a new secret. **/
	function newGame() {
		if (game != null)
			game.dispose();
		game = new Game(s2d);
		game.onRestart = newGame;
	}

	static function main() {
		// Resources embedded in the program (res/ folder): nothing to load at run time, works on every target.
		hxd.Res.initEmbed();
		new Main();
	}
}
