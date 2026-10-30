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
	Draws a `Mastermind` and turns the clicks and the actions of `Controls` into moves on it. The
	view never changes the board by itself: after each move, `redraw` rebuilds everything that
	depends on the state.
**/
class Game {
	private static var CELL_SIZE:Int = 128;
	private static var RESULT_SIZE:Int = 64;

	private static var NBR_TRIES = 10;
	private static var CODE_SIZE = 4;

	/** The virtual screen, and where the board sits in the walnut case of `background.jpg`. Keep in sync with tools/art/make_art.py. **/
	private static var SCENE_WIDTH = 848;
	private static var SCENE_HEIGHT = 1696;
	private static var BOARD_X = 40;
	private static var BOARD_Y = 112;
	/** The palette lies in its velvet tray, a little below the last row. **/
	private static var PALETTE_Y = (NBR_TRIES + 1) * CELL_SIZE + 32;

	private static var GOLD = 0xD8B468;
	private static var IVORY = 0xEFE6CF;

	private var TILE_CELL_MINI:Tile;
	private var TILE_RES_BAD:Tile;
	private var TILE_RES_GOOD:Tile;
	private var TILE_CELL:Tile;
	private var TILE_LID:Tile;
	private var TILE_PANEL:Tile;
	private var TILE_VALIDATE:Tile;
	private var TILE_SELECTION:Tile;
	private var TILE_RESTART:Tile;
	private var TILE_PIONS:Map<Color, Tile>;
	private var CURSOR_PIONS:Map<Color, BitmapData>;

	private var mastermind:Mastermind;
	/** The color picked in the palette, put in the next cell clicked. **/
	private var currentPion:Option<Color> = None;
	/** The cell of the current row that the keyboard and the gamepad act on. **/
	private var cursor:Int = 0;

	/** The board, in the case drawn by the background. **/
	private var root:Object;
	/** Everything that depends on the state: rebuilt by `redraw`. **/
	private var board:Object;
	/** The player closed the end of game panel to look at the board. **/
	private var endPanelHidden:Bool = false;

	private var gameController:GameController;
	private var scene:Scene;

	public function new(controller:GameController, ?seed:Int) {
		this.scene = new Scene();
		this.scene.scaleMode = ScaleMode.LetterBox(SCENE_WIDTH, SCENE_HEIGHT);
		// Filtered textures: the art is drawn smooth, and shown smaller than drawn on most screens.
		this.scene.defaultSmooth = true;
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
		new Bitmap(hxd.Res.Image.background.toTile(), this.scene);
		this.root = new Object(this.scene);
		this.root.setPosition(BOARD_X, BOARD_Y);
		drawBoardGame();
		drawRestart();
		drawMenu();
		this.board = new Object(this.root);
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
		this.TILE_LID = hxd.Res.Image.lid.toTile();
		this.TILE_PANEL = hxd.Res.Image.panel.toTile();
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

	/** The parts of the board that never change: holes and palette. **/
	private function drawBoardGame() {
		this.drawSecretObject(RESULT_SIZE, 0, this.root);
		this.drawPionsObject(0, PALETTE_Y, this.root);
		this.drawResults((CODE_SIZE * CELL_SIZE) + RESULT_SIZE, CELL_SIZE, this.root);
		this.drawRows(RESULT_SIZE, CELL_SIZE, this.root);
	}

	/** The holes of the secret code, under the walnut lid while the game goes on. **/
	private function drawSecretObject(x:Float, y:Float, parent:Object) {
		var secretObject = new Object(parent);
		secretObject.setPosition(x, y);
		for (c in 0...CODE_SIZE) {
			var bitmap = new Bitmap(TILE_CELL, secretObject);
			bitmap.x = c * CELL_SIZE;
		}
	}

	private function drawPionsObject(x:Float, y:Float, parent:Object) {
		var pionsObject = new Object(parent);
		pionsObject.setPosition(x, y);
		for (p => color in Mastermind.COLORS) {
			var bitmap = new Bitmap(TILE_PIONS[color], pionsObject);
			bitmap.x = p * CELL_SIZE;
			var interaction = new h2d.Interactive(CELL_SIZE, CELL_SIZE, bitmap);
			interaction.onOver = function(event:hxd.Event) {
				bitmap.color.set(1.25, 1.25, 1.25);
			}
			interaction.onOut = function(event:hxd.Event) {
				bitmap.color.set(1, 1, 1);
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
		for (r in 0...NBR_TRIES)
			for (i in 0...CODE_SIZE)
				new Bitmap(TILE_CELL_MINI, resultsObject).setPosition((i % 2) * RESULT_SIZE, r * CELL_SIZE + Std.int(i / 2) * RESULT_SIZE);
	}

	private function drawRestart() {
		var bitmap = new Bitmap(TILE_RESTART, this.root);
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
			placeAt(column);
			redraw();
		}
	}

	/** Puts the selected color in a cell (or empties it when none is selected), then moves the cursor after it. **/
	private function placeAt(column:Int) {
		mastermind.place(column, this.currentPion);
		cursor = currentPion == None ? column : Std.int(Math.min(column + 1, CODE_SIZE - 1));
	}

	/** An action of the keyboard or of a gamepad, from `Controls`. **/
	public function onAction(action:Controls.Action) {
		if (mastermind.state != Play) {
			switch action {
				case Validate | Place | Restart:
					this.gameController.restart();
				default:
			}
			return;
		}
		switch action {
			case Left:
				cursor = (cursor + CODE_SIZE - 1) % CODE_SIZE;
			case Right:
				cursor = (cursor + 1) % CODE_SIZE;
			case PrevColor:
				selectColor(-1);
			case NextColor:
				selectColor(1);
			case PickColor(index):
				currentPion = Some(Mastermind.COLORS[index]);
				placeAt(cursor);
			case Place:
				if (currentPion != None)
					placeAt(cursor);
			case Erase:
				// Like a backspace: on an empty cell, erase the one before.
				if (mastermind.current[cursor] == None && cursor > 0)
					cursor--;
				mastermind.place(cursor, None);
			case Validate:
				validate();
				return;
			case Restart:
				this.gameController.restart();
				return;
		}
		redraw();
	}

	/** Moves the selection of the palette by `step` colors, around the palette. **/
	private function selectColor(step:Int) {
		var colors = Mastermind.COLORS;
		var index = switch currentPion {
			case Some(color): (colors.indexOf(color) + step + colors.length) % colors.length;
			case None: step > 0 ? 0 : colors.length - 1;
		}
		currentPion = Some(colors[index]);
	}

	private function validate() {
		for (event in mastermind.validate())
			switch event {
				case RowValidated(_, _):
					cursor = 0;
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
				selection.setPosition(palette.indexOf(color) * CELL_SIZE, PALETTE_Y);
			case None:
		}

		for (i => row in mastermind.tries) {
			for (c => color in row.code)
				drawPion(color, RESULT_SIZE + c * CELL_SIZE, rowY(i));
			drawResult(row, rowY(i));
		}

		if (mastermind.state == Play) {
			// The lid is a little larger than the holes it hides: 12 pixels on each side.
			new Bitmap(TILE_LID, board).setPosition(RESULT_SIZE - 12, -12);
			var y = rowY(mastermind.tries.length);
			for (c => cell in mastermind.current)
				switch cell {
					case Some(color):
						drawPion(color, RESULT_SIZE + c * CELL_SIZE, y);
					case None:
				}
			new Bitmap(TILE_SELECTION, board).setPosition(RESULT_SIZE + cursor * CELL_SIZE, y);
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
		var width = TILE_PANEL.width;
		var height = TILE_PANEL.height;
		var panel = new Object(board);
		panel.setPosition((SCENE_WIDTH - 2 * BOARD_X - width) / 2, 4 * CELL_SIZE - 40);

		new Bitmap(TILE_PANEL, panel);
		var close = new h2d.Interactive(width, height, panel);
		close.onClick = function(event:hxd.Event) {
			this.endPanelHidden = true;
			redraw();
		}

		var tries = mastermind.tries.length;
		if (mastermind.state == Won) {
			drawText("Gagné !", hxd.Res.fonts.title.toFont(), GOLD, 34, width, panel);
			drawText('Code trouvé en $tries ${tries == 1 ? "coup" : "coups"}', hxd.Res.fonts.text.toFont(), IVORY, 170, width, panel);
		} else {
			drawText("Perdu !", hxd.Res.fonts.title.toFont(), GOLD, 34, width, panel);
			drawText("Le code secret est dévoilé en haut", hxd.Res.fonts.text.toFont(), IVORY, 170, width, panel);
		}

		var replay = drawText("Rejouer", hxd.Res.fonts.title.toFont(), GOLD, 252, width, panel);
		replay.setScale(0.6);
		replay.maxWidth = width / 0.6;
		var bounds = replay.getBounds(panel);
		var interaction = new h2d.Interactive(bounds.width, bounds.height, panel);
		interaction.setPosition(bounds.x, bounds.y);
		interaction.onOver = function(event:hxd.Event) {
			replay.textColor = IVORY;
		}
		interaction.onOut = function(event:hxd.Event) {
			replay.textColor = GOLD;
		}
		interaction.onClick = function(event:hxd.Event) {
			this.gameController.restart();
		}
		drawText("ou Entrée, Espace, manette A", hxd.Res.fonts.small.toFont(), 0xB8A888, 338, width, panel);
	}

	/** A line of text centered in `width`, with a soft shadow under it. **/
	private function drawText(text:String, font:h2d.Font, color:Int, y:Float, width:Float, parent:Object):h2d.Text {
		var t = new h2d.Text(font, parent);
		t.maxWidth = width;
		t.textAlign = Center;
		t.textColor = color;
		t.dropShadow = {dx: 2, dy: 3, color: 0x000000, alpha: 0.6};
		t.text = text;
		t.y = y;
		return t;
	}

	private function drawPion(color:Color, x:Float, y:Float) {
		new Bitmap(TILE_PIONS[color], board).setPosition(x, y);
	}

	/** The good (gold) and bad (silver) pegs of a validated row, two by two. **/
	private function drawResult(row:Row, y:Float) {
		var x = RESULT_SIZE + CODE_SIZE * CELL_SIZE;
		var pegs = [for (i in 0...row.good) TILE_RES_GOOD].concat([for (i in 0...row.bad) TILE_RES_BAD]);
		for (i => tile in pegs)
			new Bitmap(tile, board).setPosition(x + (i % 2) * RESULT_SIZE, y + Std.int(i / 2) * RESULT_SIZE);
	}
}
