package mastermind;

/**
	The colors of the pegs.

	The rules iterate over `Mastermind.COLORS`, built from this enum: adding a color here is
	enough for the rules (the view still needs a picture for it).
**/
enum Color {
	Black;
	White;
	Yellow;
	Blue;
	Red;
	Green;
}

/** A combination of colors, one per hole. **/
typedef Code = Array<Color>;

/** The answer to a guess. **/
typedef Feedback = {
	/** Pegs of the right color in the right hole (black pegs in the board game). **/
	var wellPlaced:Int;

	/** Pegs of a color of the secret, but in another hole (white pegs). **/
	var misplaced:Int;
}

/** A submitted guess and its answer. **/
typedef Attempt = {
	var guess:Code;
	var feedback:Feedback;
}

enum Status {
	Playing;
	Won;
	Lost;
}

/**
	The rules and the state of a game of Mastermind.

	This class is the *model*: it knows nothing about Heaps (no `h2d`, no `hxd` import), so it can
	be read on its own, unit tested (`haxe test.hxml`), and drawn by any view. The view never
	changes it directly: it reports what the player did, the game (`Game`) calls the methods below
	and then asks the view to redraw itself from the new state.

	```haxe
	var game = new mastermind.Mastermind([Red, Blue, Blue, Green]);
	game.place(0, Red);
	game.place(1, Green);
	game.place(2, Blue);
	game.place(3, Yellow);
	var f = game.submit(); // { wellPlaced: 2, misplaced: 1 }
	```
**/
class Mastermind {
	/** Number of holes of a combination. **/
	public static inline var CODE_SIZE = 4;

	/** Number of guesses before the game is lost. **/
	public static inline var MAX_ATTEMPTS = 10;

	/** All the colors, in the order of the `Color` enum (the order of the palette). **/
	public static final COLORS:Array<Color> = Type.allEnums(Color);

	/** The combination to find. **/
	public var secret(default, null):Code;

	/** The submitted guesses, the first one first. **/
	public var attempts(default, null):Array<Attempt> = [];

	/** The guess being composed: `null` for an empty hole. **/
	public var guess(default, null):Array<Null<Color>>;

	public var status(default, null):Status = Playing;

	/**
		@param secret the combination to find; random if `null` (pass one to test the rules).
	**/
	public function new(?secret:Code) {
		if (secret != null && secret.length != CODE_SIZE)
			throw 'The secret must have $CODE_SIZE colors';
		this.secret = secret != null ? secret.copy() : randomCode();
		guess = emptyGuess();
	}

	/** A random combination (colors may repeat, as in the board game). **/
	public static function randomCode():Code {
		return [for (_ in 0...CODE_SIZE) COLORS[Std.random(COLORS.length)]];
	}

	/**
		Puts a peg of `color` in the hole `hole` of the current guess, replacing the one there.
		Does nothing once the game is over.
		@return whether the guess changed.
	**/
	public function place(hole:Int, color:Color):Bool {
		if (status != Playing || hole < 0 || hole >= CODE_SIZE || guess[hole] == color)
			return false;
		guess[hole] = color;
		return true;
	}

	/** Whether the current guess has a peg in every hole and can be submitted. **/
	public function canSubmit():Bool {
		if (status != Playing)
			return false;
		for (c in guess)
			if (c == null)
				return false;
		return true;
	}

	/**
		Submits the current guess: records it with its feedback, updates `status` and starts a new
		empty guess.
		@return the feedback, or `null` if the guess could not be submitted (see `canSubmit`).
	**/
	public function submit():Null<Feedback> {
		if (!canSubmit())
			return null;
		var code:Code = [for (c in guess) c];
		var feedback = evaluate(secret, code);
		attempts.push({guess: code, feedback: feedback});
		if (feedback.wellPlaced == CODE_SIZE)
			status = Won;
		else if (attempts.length == MAX_ATTEMPTS)
			status = Lost;
		guess = emptyGuess();
		return feedback;
	}

	/**
		Compares `guess` to `secret`.

		`wellPlaced` counts the holes with the same color. Among the other holes, each color counts
		`min(occurrences in the secret, occurrences in the guess)` misplaced pegs, so a color
		repeated in the guess is not counted more times than it is in the secret.
	**/
	public static function evaluate(secret:Code, guess:Code):Feedback {
		var wellPlaced = 0;
		var inSecret = [for (c in COLORS) c => 0];
		var inGuess = [for (c in COLORS) c => 0];
		for (i in 0...CODE_SIZE) {
			if (guess[i] == secret[i])
				wellPlaced++;
			else {
				inSecret[secret[i]]++;
				inGuess[guess[i]]++;
			}
		}
		var misplaced = 0;
		for (c in COLORS)
			misplaced += inSecret[c] < inGuess[c] ? inSecret[c] : inGuess[c];
		return {wellPlaced: wellPlaced, misplaced: misplaced};
	}

	static function emptyGuess():Array<Null<Color>> {
		return [for (_ in 0...CODE_SIZE) null];
	}
}
