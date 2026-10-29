import haxe.ds.Option;
import model.Mastermind;

using Lambda;

/** Checks the rules: `haxe test.hxml`. **/
class TestMastermind {
	static function main() {
		testScore();
		testGame();
		testRandom();
		trace("all tests passed");
	}

	static function testScore() {
		checkScore([Red, Blue, Green, Yellow], [Red, Blue, Green, Yellow], 4, 0, "the right code");
		checkScore([Red, Blue, Green, Yellow], [White, White, Black, Black], 0, 0, "no common color");
		checkScore([Red, Blue, Green, Yellow], [Yellow, Green, Blue, Red], 0, 4, "all colors misplaced");
		checkScore([Red, Blue, Green, Yellow], [Red, Green, White, Black], 1, 1, "one placed, one misplaced");
		// A pion of the secret is counted once, as good before bad.
		checkScore([Red, Red, Blue, Blue], [Red, Blue, Red, White], 1, 2, "repeated colors in both");
		checkScore([Red, Blue, Green, Yellow], [Red, Red, Red, Red], 1, 0, "a placed pion is not also misplaced");
		checkScore([Red, Red, Green, Yellow], [Blue, Blue, Red, Black], 0, 1, "one pion of the guess, two in the secret");
		checkScore([Blue, Black, Black, Black], [Red, Blue, Blue, Blue], 0, 1, "three pions of the guess, one in the secret");
	}

	static function testGame() {
		var game = new Mastermind([Red, Blue, Green, Yellow], 2);
		check(!game.isComplete(), "an empty row cannot be validated");
		check(game.validate().length == 0, "validating an incomplete row does nothing");
		fill(game, [Red, Red, Red, Red]);
		check(game.place(1, None)[0].equals(PionRemoved(1)), "a cell can be emptied");
		check(!game.isComplete(), "a row with an empty cell cannot be validated");
		check(game.place(4, Some(Red)).length == 0, "a cell outside the row is ignored");
		check(game.place(1, Some(Blue))[0].equals(PionPlaced(1, Blue)), "a pion is placed");
		var events = game.validate();
		check(events.length == 1 && events[0].equals(RowValidated(2, 0)), "the row is scored");
		check(game.tries.length == 1 && game.tries[0].good == 2, "the row is kept");
		check(game.current.foreach(c -> c.equals(None)), "the next row starts empty");
		check(game.state == Play, "the game goes on");

		fill(game, [White, White, White, White]);
		events = game.validate();
		check(events[1] == GameLost && game.state == Lost, "the game is lost after the last try");
		check(game.place(0, Some(Red)).length == 0, "nothing can be placed once the game is over");

		var game = new Mastermind([Red, Blue, Green, Yellow]);
		check(game.maxTries == 10 && game.codeSize == 4, "10 tries of 4 pions by default");
		fill(game, [Red, Blue, Green, Yellow]);
		events = game.validate();
		check(events[1] == GameWon && game.state == Won, "the right code wins");
		check(!game.isComplete() && game.validate().length == 0, "nothing can be validated once the game is won");
	}

	static function testRandom() {
		var a = Mastermind.randomCode(new Random(42)), b = Mastermind.randomCode(new Random(42));
		check(a.length == 4 && a.toString() == b.toString(), "the same seed gives the same code");
		var seen = new Map<Color, Bool>();
		var random = new Random(7);
		for (i in 0...100)
			for (c in Mastermind.randomCode(random))
				seen[c] = true;
		check(Mastermind.COLORS.foreach(c -> seen.exists(c)), "every color is drawn");
	}

	static function fill(game:Mastermind, code:Code) {
		for (i => c in code)
			game.place(i, Some(c));
	}

	static function checkScore(secret:Code, guess:Code, good:Int, bad:Int, what:String) {
		var f = Mastermind.score(secret, guess);
		check(f.good == good && f.bad == bad, '$what: expected $good/$bad, got ${f.good}/${f.bad}');
	}

	static function check(ok:Bool, what:String) {
		if (!ok)
			throw "FAILED: " + what;
	}
}
