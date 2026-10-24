package model;

/** What a move did: the screen turns it into sounds and effects, the rules stay silent. **/
enum WorldEvent {
	Moved;
	Bumped;
	Won;
}

/**
	The rules and the state of a level: walls, the player and the goal.

	No Heaps import: the rules run anywhere, and `test/TestWorld.hx` checks them with the
	interpreter (`haxe test.hxml`), without a window.
**/
class World {
	/** The levels: `#` wall, `.` floor, `@` player, `*` goal. **/
	public static final LEVELS = [
		[
			"#########",
			"#@..#..*#",
			"#.#.#.#.#",
			"#.#...#.#",
			"#########",
		],
		[
			"###########",
			"#@#...#...#",
			"#.#.#.#.#.#",
			"#...#...#*#",
			"###########",
		],
	];

	public var width(default, null) : Int;
	public var height(default, null) : Int;
	public var playerX(default, null) : Int;
	public var playerY(default, null) : Int;
	public var goalX(default, null) : Int;
	public var goalY(default, null) : Int;
	public var won(default, null) = false;

	var walls : Array<Bool> = [];

	public function new( level : Int ) {
		var rows = LEVELS[level];
		height = rows.length;
		width = rows[0].length;
		for( y => row in rows )
			for( x in 0...width ) {
				var c = row.charAt(x);
				walls.push(c == "#");
				if( c == "@" ) { playerX = x; playerY = y; }
				if( c == "*" ) { goalX = x; goalY = y; }
			}
	}

	public function isWall( x : Int, y : Int ) : Bool {
		return x < 0 || y < 0 || x >= width || y >= height || walls[x + y * width];
	}

	/** Moves the player by one cell. Does nothing once the level is won. **/
	public function move( dx : Int, dy : Int ) : Array<WorldEvent> {
		if( won )
			return [];
		if( isWall(playerX + dx, playerY + dy) )
			return [Bumped];
		playerX += dx;
		playerY += dy;
		if( playerX == goalX && playerY == goalY ) {
			won = true;
			return [Moved, Won];
		}
		return [Moved];
	}
}
