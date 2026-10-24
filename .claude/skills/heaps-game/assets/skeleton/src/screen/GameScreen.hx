package screen;

import Controls.Action;
import model.World;

/**
	A level: draws the `World` and turns the actions into moves. Pause (Escape, P, Start, or the
	window losing the focus) opens a menu over the level. Reaching the goal goes to the next level,
	saved as the one to continue.
**/
class GameScreen extends Screen {
	static inline var CELL = 16;

	var level : Int;
	var world : World;
	/** Everything that depends on the state: rebuilt by `redraw`. **/
	var board : h2d.Object;
	/** The pause overlay and its menu, while paused. **/
	var pause : Null<h2d.Flow>;
	var pauseMenu : ui.Menu;

	public function new( level : Int ) {
		super();
		this.level = level;
		world = new World(level);
		board = new h2d.Object(scene);
		board.setPosition((Main.WIDTH - world.width * CELL) / 2, (Main.HEIGHT - world.height * CELL) / 2);
		text('Level ${level + 1}', Main.WIDTH / 2, 8);
		Progress.saveLevel(level);
		redraw();
	}

	override function onShow() {
		Audio.music(Game);
	}

	override function onAction( a : Action ) {
		if( pause != null ) {
			pauseMenu.onAction(a);
			return;
		}
		switch a {
			case Left: move(-1, 0);
			case Right: move(1, 0);
			case Up: move(0, -1);
			case Down: move(0, 1);
			case Back, Pause: openPause();
			default:
		}
	}

	override function onFocusLost() {
		if( pause == null )
			openPause();
	}

	function move( dx : Int, dy : Int ) {
		for( e in world.move(dx, dy) )
			switch e {
				case Moved: Audio.play(Step);
				case Bumped: Audio.play(Bump); Main.inst.controls.rumble(0.3, 0.1);
				case Won: Audio.play(Goal); won();
			}
		redraw();
	}

	function won() {
		if( level + 1 < World.LEVELS.length )
			Main.inst.show(new GameScreen(level + 1));
		else {
			Progress.clearGame();
			Main.inst.show(new TitleScreen());
		}
	}

	/** Rebuilds the board from the state of the world: it can never disagree with the rules. **/
	function redraw() {
		board.removeChildren();
		for( y in 0...world.height )
			for( x in 0...world.width )
				if( world.isWall(x, y) )
					cell(x, y, 0x505070);
		cell(world.goalX, world.goalY, 0x40C060);
		cell(world.playerX, world.playerY, 0xE04040);
	}

	function cell( x : Int, y : Int, color : Int ) {
		new h2d.Bitmap(h2d.Tile.fromColor(color, CELL - 1, CELL - 1), board).setPosition(x * CELL, y * CELL);
	}

	function openPause() {
		Audio.play(Pause);
		Audio.duck(true);
		pause = new h2d.Flow(scene);
		pause.backgroundTile = h2d.Tile.fromColor(0x000000, 1, 1, 0.7);
		pause.minWidth = Main.WIDTH;
		pause.minHeight = Main.HEIGHT;
		pause.horizontalAlign = pause.verticalAlign = Middle;
		pauseMenu = new ui.Menu(pause);
		pauseMenu.add("Resume", closePause);
		pauseMenu.add("Restart the level", () -> Main.inst.show(new GameScreen(level)));
		pauseMenu.add("Main menu", () -> Main.inst.show(new TitleScreen()));
		pauseMenu.onBack = closePause;
	}

	function closePause() {
		Audio.duck(false);
		pause.remove();
		pause = null;
	}
}
