package model;

/** What happened during an update: the screen turns it into sounds, particles and shakes. **/
enum FieldEvent {
	/** The ship fired a bullet from (x, y). **/
	Shot( x : Float, y : Float );
	/** A bullet hit `a`: it is gone, replaced by two smaller ones unless it was a small one. **/
	Destroyed( a : Asteroid, points : Int );
	/** `a` hit the ship: one life lost, the ship blinks and cannot be hit for a while. **/
	ShipHit( a : Asteroid );
	/** The last life was lost. **/
	GameOver;
}

class Asteroid {
	/** Radius of each size, in pixels (index = size). **/
	public static final RADIUS = [0., 5., 9., 14.];

	/** Unique in a game: the screen derives the shape of the rock from it. **/
	public var id(default, null) : Int;
	/** 3 big, 2 medium, 1 small. **/
	public var size(default, null) : Int;
	public var x : Float;
	public var y : Float;
	public var vx : Float;
	public var vy : Float;
	/** Rotation in radians, for the display only. **/
	public var angle : Float;
	public var spin : Float;
	public var radius(get, never) : Float;

	public function new( id, size, x, y, vx, vy, spin ) {
		this.id = id;
		this.size = size;
		this.x = x;
		this.y = y;
		this.vx = vx;
		this.vy = vy;
		this.spin = spin;
		angle = 0;
	}

	inline function get_radius() return RADIUS[size];
}

class Bullet {
	public var x : Float;
	public var y : Float;

	public function new( x, y ) {
		this.x = x;
		this.y = y;
	}
}

/**
	The rules and the state of a game: the ship, its bullets and the falling asteroids.

	No Heaps import: `test/TestField.hx` runs these rules with the interpreter (`haxe test.hxml`),
	without a window. Positions are in pixels of a `WIDTH` x `HEIGHT` field, y going down; times
	are in seconds.
**/
class Field {
	public static inline var WIDTH = 320;
	public static inline var HEIGHT = 180;

	public static inline var SHIP_SPEED = 130.;
	public static inline var SHIP_RADIUS = 5.;
	/** The ship stays below this line, away from where the asteroids appear. **/
	public static inline var SHIP_TOP = 60.;
	public static inline var BULLET_SPEED = 260.;
	public static inline var FIRE_DELAY = 0.16;
	public static inline var LIVES = 3;
	public static inline var INVINCIBLE_TIME = 2.;
	/** Points for a small, medium and big asteroid (index = size). **/
	public static final POINTS = [0, 100, 50, 20];

	/** Longest step of the simulation: a long frame is cut into short steps, so that a bullet
		never goes through an asteroid between two frames. **/
	static inline var MAX_STEP = 1 / 60;

	public var shipX(default, null) : Float = WIDTH / 2;
	public var shipY(default, null) : Float = HEIGHT - 20;
	public var lives(default, null) = LIVES;
	public var score(default, null) = 0;
	/** Seconds played: the game gets harder with it. **/
	public var time(default, null) = 0.;
	/** Seconds left during which the ship cannot be hit (after a hit). **/
	public var invincible(default, null) = 0.;
	public var over(default, null) = false;
	public var asteroids(default, null) : Array<Asteroid> = [];
	public var bullets(default, null) : Array<Bullet> = [];
	/** Whether asteroids appear by themselves. The tests turn it off and place their own. **/
	public var spawning = true;

	var random : Random;
	var nextId = 0;
	var fireCooldown = 0.;
	var spawnTimer = 1.;

	public function new( seed = 1 ) {
		random = new Random(seed);
	}

	/**
		Plays `dt` seconds. `moveX`, `moveY`: the direction asked by the player, -1 to 1 on each
		axis (analog sticks give values in between); `fire`: the fire button is held.
	**/
	public function update( dt : Float, moveX : Float, moveY : Float, fire : Bool ) : Array<FieldEvent> {
		var events = [];
		while( dt > 0 && !over ) {
			var s = Math.min(dt, MAX_STEP);
			step(s, moveX, moveY, fire, events);
			dt -= s;
		}
		return events;
	}

	/** Seconds between two new asteroids: from 1.2 s at the start to 0.35 s after a minute. **/
	public function spawnDelay() : Float {
		return Math.max(0.35, 1.2 - time * 0.014);
	}

	/** Places an asteroid (tests, and the halves of a split one). **/
	public function addAsteroid( size : Int, x : Float, y : Float, vx = 0., vy = 0. ) : Asteroid {
		var a = new Asteroid(nextId++, size, x, y, vx, vy, (random.float() - 0.5) * 3);
		asteroids.push(a);
		return a;
	}

	function step( dt : Float, moveX : Float, moveY : Float, fire : Bool, events : Array<FieldEvent> ) {
		time += dt;

		// The ship: a diagonal is not faster than a straight line.
		var len = Math.sqrt(moveX * moveX + moveY * moveY);
		if( len > 1 ) {
			moveX /= len;
			moveY /= len;
		}
		shipX = clamp(shipX + moveX * SHIP_SPEED * dt, SHIP_RADIUS * 2, WIDTH - SHIP_RADIUS * 2);
		shipY = clamp(shipY + moveY * SHIP_SPEED * dt, SHIP_TOP, HEIGHT - SHIP_RADIUS * 2);
		if( invincible > 0 )
			invincible = Math.max(0, invincible - dt);

		fireCooldown -= dt;
		if( fire && fireCooldown <= 0 ) {
			var b = new Bullet(shipX, shipY - SHIP_RADIUS);
			bullets.push(b);
			fireCooldown = FIRE_DELAY;
			events.push(Shot(b.x, b.y));
		}

		for( b in bullets.copy() ) {
			b.y -= BULLET_SPEED * dt;
			if( b.y < -4 )
				bullets.remove(b);
		}

		if( spawning ) {
			spawnTimer -= dt;
			if( spawnTimer <= 0 ) {
				spawnTimer = spawnDelay();
				spawn();
			}
		}

		for( a in asteroids.copy() ) {
			a.x += a.vx * dt;
			a.y += a.vy * dt;
			a.angle += a.spin * dt;
			if( a.y - a.radius > HEIGHT || a.x + a.radius < 0 || a.x - a.radius > WIDTH )
				asteroids.remove(a);
		}

		for( b in bullets.copy() )
			for( a in asteroids )
				if( touches(b.x, b.y, 1, a) ) {
					bullets.remove(b);
					hit(a, events);
					break;
				}

		if( invincible <= 0 )
			for( a in asteroids )
				if( touches(shipX, shipY, SHIP_RADIUS, a) ) {
					asteroids.remove(a);
					lives--;
					invincible = INVINCIBLE_TIME;
					events.push(ShipHit(a));
					if( lives == 0 ) {
						over = true;
						events.push(GameOver);
					}
					break;
				}
	}

	function spawn() {
		// More big ones at the start, faster ones as time goes.
		var r = random.float();
		var size = r < 0.45 ? 3 : r < 0.8 ? 2 : 1;
		var radius = Asteroid.RADIUS[size];
		var speed = 25 + random.float() * 20 + Math.min(time * 0.6, 45);
		addAsteroid(size, radius + random.float() * (WIDTH - radius * 2), -radius, (random.float() - 0.5) * 24, speed);
	}

	function hit( a : Asteroid, events : Array<FieldEvent> ) {
		asteroids.remove(a);
		var points = POINTS[a.size];
		score += points;
		events.push(Destroyed(a, points));
		if( a.size > 1 )
			for( side in [-1, 1] ) {
				var r = Asteroid.RADIUS[a.size - 1];
				addAsteroid(a.size - 1, a.x + side * r, a.y, a.vx + side * (25 + random.float() * 20), a.vy * 0.8);
			}
	}

	static function touches( x : Float, y : Float, radius : Float, a : Asteroid ) : Bool {
		var dx = x - a.x, dy = y - a.y, r = radius + a.radius;
		return dx * dx + dy * dy < r * r;
	}

	static inline function clamp( v : Float, min : Float, max : Float ) : Float {
		return v < min ? min : v > max ? max : v;
	}
}

/**
	A seeded random generator (Park-Miller), the same on every platform: a game started with the
	same seed and the same inputs plays the same way (tests, replays).
**/
class Random {
	var seed : Float;

	public function new( seed : Int ) {
		this.seed = seed <= 0 ? 1. : seed * 1.;
	}

	/** A number in [0, 1). **/
	public function float() : Float {
		// Float literals: the Haxe interpreter would multiply two Ints with an overflow.
		// Exact in double precision: 16807 * (2^31 - 1) < 2^53.
		seed = (seed * 16807.) % 2147483647.;
		return (seed - 1) / 2147483646;
	}
}
