import model.World;

/** Checks the rules: `haxe test.hxml`. **/
class TestWorld {
	static function main() {
		var w = new World(0);
		check(w.move(-1, 0)[0] == Bumped, "a wall stops the player");
		check(w.move(1, 0)[0] == Moved && w.playerX == 2, "the player moves");
		// Every level can be won: walk the shortest path found by a breadth-first search.
		for( level in 0...World.LEVELS.length )
			check(solve(new World(level)), 'level $level can be won');
		trace("all tests passed");
	}

	static function solve( w : World ) : Bool {
		var seen = new Map<Int, Bool>();
		var todo = [[w.playerX, w.playerY]];
		while( todo.length > 0 ) {
			var p = todo.shift();
			if( p[0] == w.goalX && p[1] == w.goalY )
				return true;
			for( d in [[1, 0], [-1, 0], [0, 1], [0, -1]] ) {
				var x = p[0] + d[0], y = p[1] + d[1];
				if( !w.isWall(x, y) && !seen.exists(x + y * w.width) ) {
					seen.set(x + y * w.width, true);
					todo.push([x, y]);
				}
			}
		}
		return false;
	}

	static function check( ok : Bool, what : String ) {
		if( !ok )
			throw "FAILED: " + what;
	}
}
