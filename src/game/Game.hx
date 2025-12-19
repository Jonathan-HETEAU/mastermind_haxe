package game;

import hxd.BitmapData;
import h2d.Scene;
import h2d.Tile;
import h2d.Object;
import h2d.Bitmap;

enum Color {
	Black;
	White;
	Yellow;
	Blue;
	Red;
	Green;
}

enum Maybe<T> {
	None;
	Some(value:T);
}

enum State {
	Play;
	Pause;
	End;
	Restart;
}

typedef Code = Array<Color>;
typedef Row = {code:Code, good:Int, bad:Int};

class GameController {
	public var menu:() -> Void;
	public var restart:() -> Void;

	public function new() {}
}

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

	static function defaultGenerator():Code {
		var colors:Array<Color> = [Black, White, Yellow, Blue, Red, Green];
		return [for (c in 0...CODE_SIZE) colors[Std.random(colors.length)]];
	}

	private var state:State;
	private var secretCode:Code;
	private var tries:Array<Row>;
	private var currentTry:Array<Maybe<Color>>;
	private var currentPion:Maybe<Color>;

	private var tryObject:Object;
	private var secretObject:Object;
	private var pionsObject:Object;
	private var rowsObject:Object;
	private var resultsObject:Object;
	private var selectionObject:Object;

	public var generator:() -> Code = defaultGenerator;

	private var gameController:GameController;
	private var scene:Scene;

	public function new(controller:GameController) {
		this.scene = new Scene();
		this.scene.scaleMode = ScaleMode.LetterBox(6 * CELL_SIZE, 12 * CELL_SIZE);
		this.gameController = controller;
		this.state = Play;
		this.secretCode = generator();
		this.currentTry = [for (i in 0...CODE_SIZE) Maybe.None];
		this.tries = [];
		this.currentPion = None;
	}

	public function init(game:Main) {
		initRessources();
		drawBoardGame();
		drawRestart();
		drawMenu();
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

	private function drawBoardGame() {
		this.drawSecretObject(RESULT_SIZE, 0, this.scene);
		this.drawPionsObject(0, (NBR_TRIES + 1) * CELL_SIZE, this.scene);
		this.drawResults((CODE_SIZE * CELL_SIZE) + RESULT_SIZE, CELL_SIZE, this.scene);
		this.drawRows(RESULT_SIZE, CELL_SIZE, this.scene);
	}

	private function drawSecretObject(x:Float, y:Float, parent:Object) {
		this.secretObject = new Object(parent);
		this.secretObject.x = x;
		this.secretObject.y = y;
		for (c in 0...CODE_SIZE) {
			var bitmap = new Bitmap(TILE_SECRET, this.secretObject);
			bitmap.x = c * CELL_SIZE;
			var bitmap = new Bitmap(TILE_PIONS[this.secretCode[c]], this.secretObject);
			bitmap.visible = false;
			bitmap.x = c * CELL_SIZE;
		}
	}

	private function drawPionsObject(x:Float, y:Float, parent:Object) {
		this.pionsObject = new Object(parent);
		this.pionsObject.x = x;
		this.pionsObject.y = y;

		this.selectionObject = new Bitmap(TILE_SELECTION, pionsObject);
		this.selectionObject.visible = false;
		var p = 0;
		for (color => tile in TILE_PIONS) {
			var bitmap = new Bitmap(tile, pionsObject);
			bitmap.alpha = 0.7;
			var interaction = new h2d.Interactive(CELL_SIZE, CELL_SIZE, bitmap);
			interaction.onOver = function(event:hxd.Event) {
				bitmap.alpha = 1;
			}
			interaction.onOut = function(event:hxd.Event) {
				bitmap.alpha = 0.7;
			}
			var position = p;
			interaction.onClick = function(event:hxd.Event) {
				this.currentPion = Some(color);
				this.selectionObject.visible = true;
				this.selectionObject.x = position;
			}
			bitmap.x = p;
			p += CELL_SIZE;
		}
	}

	private function drawRows(x:Float, y:Float, parent:Object) {
		this.rowsObject = new Object(this.scene);
		this.rowsObject.x = x;
		this.rowsObject.y = y;
		for (r in 0...NBR_TRIES) {
			for (c in 0...CODE_SIZE) {
				var bitmap = new Bitmap(TILE_CELL, this.rowsObject);
				bitmap.x = c * CELL_SIZE;
				bitmap.y = r * CELL_SIZE;
				var interaction = new h2d.Interactive(CELL_SIZE, CELL_SIZE, bitmap);
				interaction.onClick = function(event:hxd.Event) {
					setPion(r, c);
				}
				
			}
		}
		this.tryObject = new Object(this.rowsObject);
		this.tryObject.y = (NBR_TRIES - 1) * CELL_SIZE;
	}

	private function drawResults(x:Float, y:Float, parent:Object) {
		this.resultsObject = new Object(parent);
		this.resultsObject.x = x;
		this.resultsObject.y = y;

		for (r in 0...NBR_TRIES) {
			var bitmap = new Bitmap(TILE_SECRET, this.resultsObject);
			bitmap.x = 0;
			bitmap.y = (r * CELL_SIZE);
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

	private function setPion(row:Int, colun:Int) {
		if (state == Play) {
			if (NBR_TRIES - row - 1 == tries.length) {
				currentTry[colun] = this.currentPion;
				this.refreshTry();
			}
		}
	}

	private function refreshTry() {
		tryObject.y = (NBR_TRIES - this.tries.length - 1) * CELL_SIZE;
		tryObject.removeChildren();
		var count = 0;
		for (i in 0...CODE_SIZE) {
			switch currentTry[i] {
				case Some(color):
					var bitmap = new Bitmap(TILE_PIONS[color], tryObject);
					bitmap.x = i * CELL_SIZE;
					count++;
				case None:
			}
		}

		if (count == CODE_SIZE) {
			var bitmap = new Bitmap(TILE_VALIDATE, tryObject);
			bitmap.x = CODE_SIZE * CELL_SIZE;
			var interaction = new h2d.Interactive(CELL_SIZE, CELL_SIZE, bitmap);
			interaction.onClick = function(event:hxd.Event) {
				this.validate();
			}
		}
	}

	private function validate() {
		var good = 0;
		var bad = 0;

		var test = [for (i in 0...CODE_SIZE) Black];

		for (i in 0...CODE_SIZE) {
			switch currentTry[i] {
				case Some(color):
					test[i] = color;
				case None:
					test[i] = Black;
			}
		}

		var badMap = new Map<Color, Int>();
		var goodMap = new Map<Color, Int>();

		for (color in TILE_PIONS.keys()) {
			goodMap.set(color, 0);
			badMap.set(color, 0);
		}

		for (i in 0...CODE_SIZE) {
			if (test[i] == secretCode[i]) {
				good++;
			} else {
				goodMap[secretCode[i]]++;
				badMap[test[i]]++;
			}
		}

		for (color in TILE_PIONS.keys()) {
			bad += Std.int(Math.min(goodMap[color], badMap[color]));
		}

		this.setResult({code: test, bad: bad, good: good});

		this.tryObject.removeChild(this.tryObject.getChildAt(4));
		if (good == CODE_SIZE || this.tries.length == NBR_TRIES) {
			state = End;
			for (child in this.secretObject.iterator()) {
				child.visible = true;
			}
		}
		this.tryObject = new Object(this.rowsObject);
		this.tryObject.y = (NBR_TRIES - this.tries.length - 1) * CELL_SIZE;
	}

	private function setResult(newRows:Row) {
		var y = (NBR_TRIES - this.tries.length - 1) * CELL_SIZE;
		var count = 0;

		for (x in 0...Std.int(CODE_SIZE / 2))
			for (j in 0...2) {
				var tile = new Bitmap(TILE_CELL_MINI, this.resultsObject);
				tile.x = x * RESULT_SIZE;
				tile.y = y + (j * RESULT_SIZE);
			}

		for (i in 0...newRows.good) {
			var bitmap = new Bitmap(TILE_RES_GOOD, this.resultsObject);
			bitmap.x = (count % 2) * RESULT_SIZE;
			bitmap.y = y + (Std.int(count / 2) * RESULT_SIZE);
			count++;
		}
		for (i in 0...newRows.bad) {
			var bitmap = new Bitmap(TILE_RES_BAD, this.resultsObject);
			bitmap.x = (count % 2) * RESULT_SIZE;
			bitmap.y = y + (Std.int(count / 2) * RESULT_SIZE);
			count++;
		}

		this.tries.push(newRows);
	}
}
