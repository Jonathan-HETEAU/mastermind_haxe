package view;

import h2d.Bitmap;
import h2d.Interactive;
import h2d.Object;
import h2d.Tile;
import mastermind.Mastermind;

/**
	Draws a `Mastermind` game and reports the clicks of the player.

	The board, from top to bottom (sizes in pixels of the 768x1536 virtual screen, see `Main`):
	- the secret (hidden until the end) and the restart button;
	- `MAX_ATTEMPTS` rows of holes, filled from the bottom, each with its feedback on the right;
	- the palette of colors.

	The view holds no game state. `refresh(game, selected)` redraws everything that depends on
	the state, from scratch: with 50 pegs at most this costs nothing, and the screen can never
	disagree with the model. Only the parts that never change (holes, backgrounds, palette, buttons)
	are created once, in the constructor.

	The view does not change the game either: it calls the `on*` callbacks and the owner (`Game`)
	decides what to do.
**/
class BoardView extends Object {
	/** Size of a hole, of a peg and of a button. **/
	public static inline var CELL = 128;

	/** Size of a feedback peg (four of them fit in a cell). **/
	public static inline var SMALL = 64;

	/** Width of the board, in pixels. **/
	public static inline var WIDTH = 6 * CELL;

	/** Height of the board, in pixels. **/
	public static inline var HEIGHT = 12 * CELL;

	static inline var BOARD_X = SMALL;
	static inline var FEEDBACK_X = BOARD_X + Mastermind.CODE_SIZE * CELL;
	static inline var PALETTE_Y = (Mastermind.MAX_ATTEMPTS + 1) * CELL;

	/** The player clicked the color `color` of the palette. **/
	public dynamic function onPickColor(color:Color) {}

	/** The player clicked the hole `hole` of the current row. **/
	public dynamic function onClickHole(hole:Int) {}

	public dynamic function onSubmit() {}

	public dynamic function onRestart() {}

	var pegTiles:Map<Color, Tile>;
	var secretPegs:Array<Bitmap> = [];

	/** The pegs and feedback of the submitted rows and the pegs of the current row. **/
	var pegs:Object;

	/** The clickable holes of the current row; moved up after each guess. **/
	var currentRow:Object;

	var submitButton:Bitmap;
	var selection:Bitmap;
	var paletteX:Map<Color, Float> = [];

	public function new(?parent:Object) {
		super(parent);
		// The resources are loaded once and cached by hxd.Res: calling toTile() again is cheap.
		var img = hxd.Res.Image;
		pegTiles = [
			Black => img.pion_noir.toTile(),
			White => img.pion_blanc.toTile(),
			Yellow => img.pion_jaune.toTile(),
			Blue => img.pion_bleu.toTile(),
			Red => img.pion_rouge.toTile(),
			Green => img.pion_vert.toTile(),
		];

		// Secret: a cover over each hidden peg.
		for (i in 0...Mastermind.CODE_SIZE) {
			new Bitmap(img.secret.toTile(), this).setPosition(BOARD_X + i * CELL, 0);
			var peg = new Bitmap(null, this);
			peg.setPosition(BOARD_X + i * CELL, 0);
			secretPegs.push(peg);
		}
		button(img.restart.toTile(), FEEDBACK_X, 0, () -> onRestart());

		// Rows: empty holes and feedback backgrounds.
		for (r in 0...Mastermind.MAX_ATTEMPTS) {
			for (i in 0...Mastermind.CODE_SIZE)
				new Bitmap(img.cell.toTile(), this).setPosition(BOARD_X + i * CELL, rowY(r));
			new Bitmap(img.secret.toTile(), this).setPosition(FEEDBACK_X, rowY(r));
		}
		pegs = new Object(this);

		currentRow = new Object(this);
		for (i in 0...Mastermind.CODE_SIZE) {
			var hole = new Interactive(CELL, CELL, currentRow);
			hole.x = BOARD_X + i * CELL;
			hole.onClick = _ -> onClickHole(i);
		}
		submitButton = button(img.validate.toTile(), FEEDBACK_X, 0, () -> onSubmit(), currentRow);

		// Palette, in the order of the Color enum.
		selection = new Bitmap(img.selection.toTile(), this);
		selection.y = PALETTE_Y;
		for (i => color in Mastermind.COLORS) {
			var peg = new Bitmap(pegTiles[color], this);
			peg.setPosition(i * CELL, PALETTE_Y);
			peg.alpha = 0.7;
			paletteX[color] = peg.x;
			var it = new Interactive(CELL, CELL, peg);
			it.onOver = _ -> peg.alpha = 1;
			it.onOut = _ -> peg.alpha = 0.7;
			it.onClick = _ -> onPickColor(color);
		}
	}

	/**
		Redraws the parts that depend on the state of the game.
		@param selected the color picked in the palette, if any.
	**/
	public function refresh(game:Mastermind, selected:Null<Color>) {
		pegs.removeChildren();
		for (r => attempt in game.attempts) {
			for (i => color in attempt.guess)
				peg(color, BOARD_X + i * CELL, rowY(r));
			drawFeedback(attempt.feedback, rowY(r));
		}

		var playing = game.status == Playing;
		currentRow.visible = playing;
		if (playing) {
			var r = game.attempts.length;
			currentRow.y = rowY(r);
			for (i => color in game.guess)
				if (color != null)
					peg(color, BOARD_X + i * CELL, rowY(r));
			submitButton.visible = game.canSubmit();
		}

		selection.visible = playing && selected != null;
		if (selected != null)
			selection.x = paletteX[selected];

		for (i => peg in secretPegs) {
			peg.tile = pegTiles[game.secret[i]];
			peg.visible = !playing;
		}
	}

	/** Two by two: the well placed pegs first, then the misplaced ones, then empty holes. **/
	function drawFeedback(f:Feedback, y:Float) {
		var img = hxd.Res.Image;
		for (k in 0...Mastermind.CODE_SIZE) {
			var tile = k < f.wellPlaced ? img.good.toTile() : k < f.wellPlaced + f.misplaced ? img.bad.toTile() : img.cell_mini.toTile();
			new Bitmap(tile, pegs).setPosition(FEEDBACK_X + (k % 2) * SMALL, y + Std.int(k / 2) * SMALL);
		}
	}

	function peg(color:Color, x:Float, y:Float) {
		new Bitmap(pegTiles[color], pegs).setPosition(x, y);
	}

	function button(tile:Tile, x:Float, y:Float, onClick:() -> Void, ?parent:Object) {
		var b = new Bitmap(tile, parent == null ? this : parent);
		b.setPosition(x, y);
		new Interactive(CELL, CELL, b).onClick = _ -> onClick();
		return b;
	}

	/** Rows are filled from the bottom: attempt 0 is the lowest row. **/
	static function rowY(attempt:Int):Float {
		return (Mastermind.MAX_ATTEMPTS - attempt) * CELL;
	}
}
