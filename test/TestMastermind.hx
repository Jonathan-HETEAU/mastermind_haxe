import mastermind.Mastermind;

/**
	Tests of the rules, run with `haxe test.hxml` (Haxe interpreter, no window, no Heaps).
	Possible because `Mastermind` does not depend on Heaps.
**/
class TestMastermind {
	static var failures = 0;

	static function main() {
		// evaluate
		feedback([Red, Blue, Green, Yellow], [Red, Blue, Green, Yellow], 4, 0);
		feedback([Red, Blue, Green, Yellow], [Yellow, Green, Blue, Red], 0, 4);
		feedback([Red, Blue, Green, Yellow], [Black, Black, White, White], 0, 0);
		// A color repeated in the guess counts once if the secret has it once.
		feedback([Red, Blue, Green, Yellow], [Blue, Blue, Blue, Blue], 1, 0);
		feedback([Red, Blue, Green, Yellow], [Blue, Red, Red, Red], 0, 2);
		// A color repeated in the secret.
		feedback([Red, Red, Blue, Blue], [Blue, Blue, Red, Red], 0, 4);
		feedback([Red, Red, Blue, Blue], [Red, Blue, Red, Green], 1, 2);

		// A game won on the second guess.
		var game = new Mastermind([Red, Blue, Green, Yellow]);
		check("incomplete guess", !game.canSubmit() && game.submit() == null);
		guess(game, [Black, Blue, Green, Yellow]);
		check("not won yet", game.status == Playing && game.attempts.length == 1);
		check("new guess is empty", [for (c in game.guess) if (c != null) c].length == 0);
		guess(game, [Red, Blue, Green, Yellow]);
		check("won", game.status == Won && !game.place(0, Red));

		// A game lost after MAX_ATTEMPTS guesses.
		var game = new Mastermind([Red, Red, Red, Red]);
		for (_ in 0...Mastermind.MAX_ATTEMPTS)
			guess(game, [Blue, Blue, Blue, Blue]);
		check("lost", game.status == Lost && game.attempts.length == Mastermind.MAX_ATTEMPTS && !game.canSubmit());

		Sys.println(failures == 0 ? "All tests passed" : '$failures test(s) failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}

	static function guess(game:Mastermind, code:Code) {
		for (i => c in code)
			game.place(i, c);
		game.submit();
	}

	static function feedback(secret:Code, guess:Code, wellPlaced:Int, misplaced:Int) {
		var f = Mastermind.evaluate(secret, guess);
		check('$secret / $guess = ${f.wellPlaced} well placed, ${f.misplaced} misplaced', f.wellPlaced == wellPlaced && f.misplaced == misplaced);
	}

	static function check(name:String, ok:Bool) {
		if (!ok) {
			failures++;
			Sys.println('FAIL $name');
		}
	}
}
