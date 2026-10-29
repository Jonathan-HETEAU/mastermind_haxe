package model;

import haxe.ds.Option;

enum Color {
	Black;
	White;
	Yellow;
	Blue;
	Red;
	Green;
}

enum State {
	Play;
	Won;
	Lost;
}

/** What an action did: the view turns it into sounds and effects, the rules stay silent. **/
enum MastermindEvent {
	PionPlaced(column:Int, color:Color);
	PionRemoved(column:Int);
	RowValidated(good:Int, bad:Int);
	GameWon;
	GameLost;
}

typedef Code = Array<Color>;
typedef Feedback = {good:Int, bad:Int};
typedef Row = {code:Code, good:Int, bad:Int};

/**
	The rules and the state of a game of Mastermind.

	No Heaps import: the rules run anywhere, and `test/TestMastermind.hx` checks them with the
	interpreter (`haxe test.hxml`), without a window.
**/
class Mastermind {
	public static final COLORS:Array<Color> = Color.createAll();

	public var codeSize(default, null):Int;
	public var maxTries(default, null):Int;
	public var secret(default, null):Code;
	public var tries(default, null):Array<Row> = [];
	/** The row being filled: `None` for an empty cell. **/
	public var current(default, null):Array<Option<Color>>;
	public var state(default, null):State = Play;

	public function new(secret:Code, maxTries:Int = 10) {
		this.secret = secret.copy();
		this.codeSize = secret.length;
		this.maxTries = maxTries;
		this.current = [for (i in 0...codeSize) None];
	}

	/** A secret code of `size` colors, repetitions allowed. **/
	public static function randomCode(random:Random, size:Int = 4):Code {
		return [for (i in 0...size) COLORS[random.int(COLORS.length)]];
	}

	/**
		`good`: right color at the right place. `bad`: right color at another place, each pion of
		the secret counted at most once.
	**/
	public static function score(secret:Code, guess:Code):Feedback {
		var good = 0;
		var secretLeft = new Map<Color, Int>();
		var guessLeft = new Map<Color, Int>();
		for (i in 0...secret.length) {
			if (guess[i] == secret[i]) {
				good++;
			} else {
				secretLeft[secret[i]] = (secretLeft.exists(secret[i]) ? secretLeft[secret[i]] : 0) + 1;
				guessLeft[guess[i]] = (guessLeft.exists(guess[i]) ? guessLeft[guess[i]] : 0) + 1;
			}
		}
		var bad = 0;
		for (color => count in guessLeft)
			if (secretLeft.exists(color))
				bad += Std.int(Math.min(count, secretLeft[color]));
		return {good: good, bad: bad};
	}

	/** Puts a pion in a cell of the current row, or empties it with `None`. **/
	public function place(column:Int, color:Option<Color>):Array<MastermindEvent> {
		if (state != Play || column < 0 || column >= codeSize)
			return [];
		current[column] = color;
		return switch color {
			case Some(c): [PionPlaced(column, c)];
			case None: [PionRemoved(column)];
		}
	}

	/** The current row has a pion in every cell: it can be validated. **/
	public function isComplete():Bool {
		return state == Play && !current.contains(None);
	}

	/** Scores the current row, then starts the next one, or ends the game. **/
	public function validate():Array<MastermindEvent> {
		if (!isComplete())
			return [];
		var code = [for (cell in current) switch cell {
			case Some(c): c;
			case None: throw "unreachable";
		}];
		var feedback = score(secret, code);
		tries.push({code: code, good: feedback.good, bad: feedback.bad});
		current = [for (i in 0...codeSize) None];
		var events = [RowValidated(feedback.good, feedback.bad)];
		if (feedback.good == codeSize) {
			state = Won;
			events.push(GameWon);
		} else if (tries.length == maxTries) {
			state = Lost;
			events.push(GameLost);
		}
		return events;
	}
}

/** A seeded random generator: the same seed gives the same codes (tests, replays). **/
class Random {
	var seed:Float;

	public function new(seed:Int) {
		this.seed = seed <= 0 ? 1. : seed * 1.;
	}

	/** A number in [0, 1). **/
	public function float():Float {
		// Float literals: the Haxe interpreter would multiply two Ints with an overflow.
		// Exact in double precision: 16807 * (2^31 - 1) < 2^53.
		seed = (seed * 16807.) % 2147483647.;
		return (seed - 1) / 2147483646;
	}

	/** An integer in [0, max). **/
	public function int(max:Int):Int {
		return Std.int(float() * max);
	}
}
