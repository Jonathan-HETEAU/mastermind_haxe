package game;

import haxe.ds.Option;
import hxd.BitmapData;
import h2d.Scene;
import h2d.Tile;
import h2d.Object;
import h2d.Bitmap;
import model.Mastermind;

class GameController {
	public var menu:() -> Void;
	public var restart:() -> Void;

	public function new() {}
}

/**
	Draws a `Mastermind` and turns the clicks into actions on it. The view never changes the
	board by itself: after each action, `redraw` rebuilds everything that depends on the state.
**/
class Game {
	private static var CELL_SIZE:Int = 128;
	private static var RESULT_SIZE:Int = 64;

	private static var NBR_TRIES = 10;
	private static var CODE_SIZE = 4;

	private var TILE_CELL_MINI:Tile;
	private var TILE_RES_BAD:Tile;
	private var TILE_RES_GOOD:Tile;
	private var TILE_CELL:Tile;
	private var TILE_SECRET:Tile;
	private var TILE_VALIDATE:Tile;
	private var TILE_SELECTION:Tile;
	private var TILE_RESTART:Tile;
	private var TILE_PIONS:Map<Color, Tile>;
	private var CURSOR_PIONS:Map<Color, BitmapData>;

	private var mastermind:Mastermind;
	/** The color picked in the palette, put in the next cell clicked. **/
	private var currentPion:Option<Color> = None;

	/** Everything that depends on the state: rebuilt by `redraw`. **/
	private var board:Object;
	/** The player closed the end of game panel to look at the board. **/
	private var endPanelHidden:Bool = false;

	private var gameController:GameController;
	private var scene:Scene;

	public function new(controller:GameController, ?seed:Int) {
		this.scene = new Scene();
		this.scene.scaleMode = ScaleMode.LetterBox(6 * CELL_SIZE, 12 * CELL_SIZE);
		this.gameController = controller;
		if (seed == null)
			seed = Std.random(0x7FFFFFFE) + 1;
		this.mastermind = new Mastermind(Mastermind.randomCode(new Random(seed), CODE_SIZE), NBR_TRIES);
		#if (js && debug)
		(cast js.Browser.window).game = this;
		#end
	}

	public function init(game:Main) {
		initRessources();
		drawBoardGame();
		drawRestart();
		drawMenu();
		this.board = new Object(this.scene);
		redraw();
	}

	public function getScene():Scene {
		return scene;
	}

	private function initRessources() {
		this.TILE_CELL_MINI = hxd.Res.Image.cell_mini.toTile();
		this.TILE_RES_BAD = hxd.Res.Image.bad.toTile();
		this.TILE_RES_GOOD = hxd.Res.Image.good.toTile();
		this.TILE_CELL = hxd.Res.Image.cell.toTile();
		this.TILE_SECRET = hxd.Res.Image.secret.toTile();
		this.TILE_SELECTION = hxd.Res.Image.selection.toTile();
		this.TILE_VALIDATE = hxd.Res.Image.validate.toTile();
		this.TILE_RESTART = hxd.Res.Image.restart.toTile();
		this.TILE_PIONS = [
			Red => hxd.Res.Image.pion_rouge.toTile(),
			Black => hxd.Res.Image.pion_noir.toTile(),
			White => hxd.Res.Image.pion_blanc.toTile(),
			Blue => hxd.Res.Image.pion_bleu.toTile(),
			Green => hxd.Res.Image.pion_vert.toTile(),
			Yellow => hxd.Res.Image.pion_jaune.toTile(),
		];
		this.CURSOR_PIONS = [
			Red => hxd.Res.Image.pion_rouge.toBitmap(),
			Black => hxd.Res.Image.pion_noir.toBitmap(),
			White => hxd.Res.Image.pion_blanc.toBitmap(),
			Blue => hxd.Res.Image.pion_bleu.toBitmap(),
			Green => hxd.Res.Image.pion_vert.toBitmap(),
			Yellow => hxd.Res.Image.pion_jaune.toBitmap(),
		];
	}

	/** The parts of the board that never change: backgrounds, cells and palette. **/
	private function drawBoardGame() {
		this.drawSecretObject(RESULT_SIZE, 0, this.scene);
		this.drawPionsObject(0, (NBR_TRIES + 1) * CELL_SIZE, this.scene);
		this.drawResults((CODE_SIZE * CELL_SIZE) + RESULT_SIZE, CELL_SIZE, this.scene);
		this.drawRows(RESULT_SIZE, CELL_SIZE, this.scene);
	}

	private function drawSecretObject(x:Float, y:Float, parent:Object) {
		var secretObject = new Object(parent);
		secretObject.setPosition(x, y);
		for (c in 0...CODE_SIZE) {
			var bitmap = new Bitmap(TILE_SECRET, secretObject);
			bitmap.x = c * CELL_SIZE;
		}
	}

	private function drawPionsObject(x:Float, y:Float, parent:Object) {
		var pionsObject = new Object(parent);
		pionsObject.setPosition(x, y);
		for (p => color in Mastermind.COLORS) {
			var bitmap = new Bitmap(TILE_PIONS[color], pionsObject);
			bitmap.x = p * CELL_SIZE;
			bitmap.alpha = 0.7;
			var interaction = new h2d.Interactive(CELL_SIZE, CELL_SIZE, bitmap);
			interaction.onOver = function(event:hxd.Event) {
				bitmap.alpha = 1;
			}
			interaction.onOut = function(event:hxd.Event) {
				bitmap.alpha = 0.7;
			}
			interaction.onClick = function(event:hxd.Event) {
				this.currentPion = Some(color);
				redraw();
			}
		}
	}

	private function drawRows(x:Float, y:Float, parent:Object) {
		var rowsObject = new Object(parent);
		rowsObject.setPosition(x, y);
		for (r in 0...NBR_TRIES) {
			for (c in 0...CODE_SIZE) {
				var bitmap = new Bitmap(TILE_CELL, rowsObject);
				bitmap.x = c * CELL_SIZE;
				bitmap.y = r * CELL_SIZE;
				var interaction = new h2d.Interactive(CELL_SIZE, CELL_SIZE, bitmap);
				interaction.onClick = function(event:hxd.Event) {
					setPion(r, c);
				}
			}
		}
	}

	private function drawResults(x:Float, y:Float, parent:Object) {
		var resultsObject = new Object(parent);
		resultsObject.setPosition(x, y);
		for (r in 0...NBR_TRIES) {
			var bitmap = new Bitmap(TILE_SECRET, resultsObject);
			bitmap.y = r * CELL_SIZE;
		}
	}

	private function drawRestart() {
		var bitmap = new Bitmap(TILE_RESTART, this.scene);
		bitmap.x = RESULT_SIZE + (CELL_SIZE * CODE_SIZE);
		var interaction = new h2d.Interactive(CELL_SIZE, CELL_SIZE, bitmap);
		interaction.onClick = function(event:hxd.Event) {
			this.gameController.restart();
		}
	}

	private function drawMenu() {}

	public function update() {}

	/** The rows fill from the bottom: try `i` is on screen row `NBR_TRIES - 1 - i`. **/
	private static function rowY(tryIndex:Int):Float {
		return CELL_SIZE + (NBR_TRIES - 1 - tryIndex) * CELL_SIZE;
	}

	private function setPion(row:Int, column:Int) {
		// Only the cells of the row being filled can be changed.
		if (NBR_TRIES - 1 - row == mastermind.tries.length) {
			mastermind.place(column, this.currentPion);
			redraw();
		}
	}

	private function validate() {
		for (event in mastermind.validate())
			switch event {
				case GameWon:
					trace('game won in ${mastermind.tries.length} tries');
				case GameLost:
					trace('game lost');
				default:
			}
		redraw();
	}

	/** Rebuilds everything that depends on the state of the game and on the selected color. **/
	private function redraw() {
		board.removeChildren();

		var palette = Mastermind.COLORS;
		switch currentPion {
			case Some(color):
				var selection = new Bitmap(TILE_SELECTION, board);
				selection.setPosition(palette.indexOf(color) * CELL_SIZE, (NBR_TRIES + 1) * CELL_SIZE);
			case None:
		}

		for (i => row in mastermind.tries) {
			for (c => color in row.code)
				drawPion(color, RESULT_SIZE + c * CELL_SIZE, rowY(i));
			drawResult(row, rowY(i));
		}

		if (mastermind.state == Play) {
			var y = rowY(mastermind.tries.length);
			for (c => cell in mastermind.current)
				switch cell {
					case Some(color):
						drawPion(color, RESULT_SIZE + c * CELL_SIZE, y);
					case None:
				}
			if (mastermind.isComplete()) {
				var bitmap = new Bitmap(TILE_VALIDATE, board);
				bitmap.setPosition(RESULT_SIZE + CODE_SIZE * CELL_SIZE, y);
				var interaction = new h2d.Interactive(CELL_SIZE, CELL_SIZE, bitmap);
				interaction.onClick = function(event:hxd.Event) {
					validate();
				}
			}
		} else {
			for (c => color in mastermind.secret)
				drawPion(color, RESULT_SIZE + c * CELL_SIZE, 0);
			if (!endPanelHidden)
				drawEndPanel();
		}
	}

	/**
		The result of the game over the empty rows, with a button to play again. A click elsewhere
		on the panel closes it, to look at the board.
	**/
	private function drawEndPanel() {
		var width = (CODE_SIZE + 1) * CELL_SIZE + RESULT_SIZE;
		var height = 3 * CELL_SIZE;
		var panel = new Object(board);
		panel.setPosition((6 * CELL_SIZE - width) / 2, 4 * CELL_SIZE);

		var background = new h2d.Graphics(panel);
		background.beginFill(0x000000, 0.85);
		background.lineStyle(4, 0xC8A060);
		background.drawRect(0, 0, width, height);
		background.endFill();
		var close = new h2d.Interactive(width, height, panel);
		close.onClick = function(event:hxd.Event) {
			this.endPanelHidden = true;
			redraw();
		}

		var tries = mastermind.tries.length;
		if (mastermind.state == Won) {
			drawText("Gagné !", 8, 40, width, panel);
			drawText('Code trouvé en $tries ${tries == 1 ? "coup" : "coups"}', 3, 150, width, panel);
		} else {
			drawText("Perdu !", 8, 40, width, panel);
			drawText("Le code est révélé en haut", 3, 150, width, panel);
		}

		var replay = drawText("Rejouer", 5, 230, width, panel);
		replay.textColor = 0xC8A060;
		var bounds = replay.getBounds(panel);
		var interaction = new h2d.Interactive(bounds.width, bounds.height, panel);
		interaction.setPosition(bounds.x, bounds.y);
		interaction.onOver = function(event:hxd.Event) {
			replay.textColor = 0xFFFFFF;
		}
		interaction.onOut = function(event:hxd.Event) {
			replay.textColor = 0xC8A060;
		}
		interaction.onClick = function(event:hxd.Event) {
			this.gameController.restart();
		}
	}

	/** A line of text centered in `width`, with the default font scaled `scale` times. **/
	private function drawText(text:String, scale:Int, y:Float, width:Float, parent:Object):h2d.Text {
		var t = new h2d.Text(hxd.res.DefaultFont.get(), parent);
		t.setScale(scale);
		t.maxWidth = width / scale;
		t.textAlign = Center;
		t.text = text;
		t.y = y;
		return t;
	}

	private function drawPion(color:Color, x:Float, y:Float) {
		new Bitmap(TILE_PIONS[color], board).setPosition(x, y);
	}

	/** The good and bad pegs of a validated row, two by two. **/
	private function drawResult(row:Row, y:Float) {
		var x = RESULT_SIZE + CODE_SIZE * CELL_SIZE;
		for (i in 0...CODE_SIZE)
			new Bitmap(TILE_CELL_MINI, board).setPosition(x + (i % 2) * RESULT_SIZE, y + Std.int(i / 2) * RESULT_SIZE);
		var pegs = [for (i in 0...row.good) TILE_RES_GOOD].concat([for (i in 0...row.bad) TILE_RES_BAD]);
		for (i => tile in pegs)
			new Bitmap(tile, board).setPosition(x + (i % 2) * RESULT_SIZE, y + Std.int(i / 2) * RESULT_SIZE);
	}
}
