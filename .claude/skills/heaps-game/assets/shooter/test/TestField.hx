import model.Field;

/** Checks the rules without a window: `haxe test.hxml`. **/
class TestField {
	static var checks = 0;

	static function main() {
		shipMoves();
		shipFires();
		bigAsteroidSplits();
		smallAsteroidIsDestroyed();
		shipLosesLives();
		asteroidsFallAndLeave();
		longFrame();
		sameSeedSameGame();
		trace('all $checks checks passed');
	}

	/** A field without random asteroids, for the tests that place their own. **/
	static function empty() : Field {
		var f = new Field();
		f.spawning = false;
		return f;
	}

	static function shipMoves() {
		var f = empty();
		var x = f.shipX, y = f.shipY;
		f.update(0.5, 1, 0, false);
		check(f.shipX > x && f.shipY == y, "the ship moves right");
		f.update(10, 1, 0, false);
		check(f.shipX <= Field.WIDTH - Field.SHIP_RADIUS, "the ship stays in the field (right)");
		f.update(10, -1, -1, false);
		check(f.shipX >= Field.SHIP_RADIUS && f.shipY == Field.SHIP_TOP, "the ship stays in the field (top left)");
		var diagonal = empty(), straight = empty();
		var x0 = diagonal.shipX, y0 = diagonal.shipY;
		diagonal.update(0.2, 1, -1, false);
		straight.update(0.2, 1, 0, false);
		check(Math.abs(dist(diagonal, x0, y0) - dist(straight, x0, y0)) < 0.001, "a diagonal is not faster");
	}

	static function shipFires() {
		var f = empty();
		var events = f.update(0.01, 0, 0, true);
		check(f.bullets.length == 1 && events[0].match(Shot(_, _)), "fire shoots a bullet");
		f.update(0.05, 0, 0, true);
		check(f.bullets.length == 1, "no second bullet before the delay");
		f.update(Field.FIRE_DELAY, 0, 0, true);
		check(f.bullets.length == 2, "a second bullet after the delay");
		f.update(2, 0, 0, false);
		check(f.bullets.length == 0, "bullets leave the field");
	}

	static function bigAsteroidSplits() {
		var f = empty();
		f.addAsteroid(3, f.shipX, 40);
		// One bullet: fire during one frame only.
		var events = f.update(0.01, 0, 0, true).concat(f.update(0.5, 0, 0, false));
		var destroyed = [for( e in events ) switch e { case Destroyed(a, p): a.size + ":" + p; default: null; }].filter(s -> s != null);
		check(destroyed.join(",") == "3:20" && f.score == 20, "a big asteroid is hit for 20 points");
		check(f.asteroids.length == 2 && f.asteroids.filter(a -> a.size == 2).length == 2, "it splits into two medium ones");
		check(f.asteroids[0].vx < 0 && f.asteroids[1].vx > 0, "which fly apart");
	}

	static function smallAsteroidIsDestroyed() {
		var f = empty();
		f.addAsteroid(1, f.shipX, 60);
		f.update(0.01, 0, 0, true);
		f.update(0.5, 0, 0, false);
		check(f.asteroids.length == 0 && f.score == 100, "a small asteroid disappears, 100 points");
	}

	static function shipLosesLives() {
		var f = empty();
		f.addAsteroid(2, f.shipX, f.shipY);
		var events = f.update(0.01, 0, 0, false);
		check(f.lives == Field.LIVES - 1 && events[0].match(ShipHit(_)), "an asteroid on the ship takes a life");
		f.addAsteroid(2, f.shipX, f.shipY);
		f.update(0.01, 0, 0, false);
		check(f.lives == Field.LIVES - 1, "no second hit while blinking");
		f.update(Field.INVINCIBLE_TIME, 0, 0, false);
		check(f.lives == Field.LIVES - 2, "hit again once the blinking is over");
		var over = false;
		while( !f.over ) {
			f.update(Field.INVINCIBLE_TIME, 0, 0, false);
			f.addAsteroid(2, f.shipX, f.shipY);
			for( e in f.update(0.01, 0, 0, false) )
				if( e == GameOver )
					over = true;
		}
		check(over && f.lives == 0, "game over after the last life");
		var x = f.shipX;
		check(f.update(1, 1, 0, true).length == 0 && f.shipX == x, "nothing moves after the game over");
	}

	static function asteroidsFallAndLeave() {
		var f = new Field(42);
		f.update(3, 0, 0, false);
		check(f.asteroids.length > 0, "asteroids appear");
		var a = f.asteroids[0], y = a.y;
		f.update(0.1, 0, 0, false);
		check(a.y > y, "they fall");
		var g = empty();
		g.addAsteroid(1, 10, Field.HEIGHT - 2, 0, 100);
		g.update(1, 0, 0, false);
		check(g.asteroids.length == 0, "they disappear at the bottom");
		check(new Field().spawnDelay() > f.spawnDelay() || f.time < 1, "it gets harder");
		var late = empty();
		late.update(120, 0, 0, false);
		check(late.spawnDelay() == 0.35, "up to a limit");
	}

	/** A long frame (the tab was hidden...) is played in short steps: the bullet does not go through. **/
	static function longFrame() {
		var f = empty();
		f.addAsteroid(1, f.shipX, 50);
		f.update(1, 0, 0, true);
		check(f.score == 100, "a bullet hits even in a one-second frame");
	}

	static function sameSeedSameGame() {
		var a = new Field(7), b = new Field(7);
		for( i in 0...300 ) {
			var mx = Math.sin(i / 20);
			a.update(1 / 60, mx, 0, i % 3 == 0);
			b.update(1 / 60, mx, 0, i % 3 == 0);
		}
		check(a.asteroids.length == b.asteroids.length && a.score == b.score && a.shipX == b.shipX, "the same seed and inputs give the same game");
	}

	static function dist( f : Field, x : Float, y : Float ) : Float {
		return Math.sqrt((f.shipX - x) * (f.shipX - x) + (f.shipY - y) * (f.shipY - y));
	}

	static function check( ok : Bool, what : String ) {
		checks++;
		if( !ok )
			throw "FAILED: " + what;
	}
}
