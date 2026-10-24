package view;

/** The ship and the asteroids, drawn with lines and fills (no image to make). **/
class Shapes {
	public static inline var SHIP_COLOR = 0x60E0FF;
	static inline var ROCK_FILL = 0x3A3440;
	static inline var ROCK_LINE = 0xB0A8B8;
	static inline var ROCK_POINTS = 10;

	/** The ship pointing up, centered on (x, y); `flame` 0 to 1 is the size of the jet. **/
	public static function ship( g : h2d.Graphics, x : Float, y : Float, flame : Float, scale = 1. ) {
		if( flame > 0 ) {
			g.lineStyle();
			g.beginFill(0xFFA030);
			g.moveTo(x - 2 * scale, y + 4 * scale);
			g.lineTo(x + 2 * scale, y + 4 * scale);
			g.lineTo(x, y + (5 + 5 * flame) * scale);
			g.endFill();
		}
		g.lineStyle(1, 0xFFFFFF);
		g.beginFill(SHIP_COLOR);
		g.moveTo(x, y - 7 * scale);
		g.lineTo(x + 6 * scale, y + 5 * scale);
		g.lineTo(x, y + 2 * scale);
		g.lineTo(x - 6 * scale, y + 5 * scale);
		g.lineTo(x, y - 7 * scale);
		g.endFill();
		g.lineStyle();
	}

	/** A rock of the given radius; `id` gives it its own irregular outline, kept while it turns. **/
	public static function rock( g : h2d.Graphics, id : Int, x : Float, y : Float, radius : Float, angle : Float ) {
		g.lineStyle(1, ROCK_LINE);
		g.beginFill(ROCK_FILL);
		for( i in 0...ROCK_POINTS + 1 ) {
			var k = i % ROCK_POINTS;
			var a = angle + k / ROCK_POINTS * Math.PI * 2;
			var r = radius * (0.72 + 0.28 * noise(id, k));
			if( i == 0 )
				g.moveTo(x + Math.cos(a) * r, y + Math.sin(a) * r);
			else
				g.lineTo(x + Math.cos(a) * r, y + Math.sin(a) * r);
		}
		g.endFill();
		g.lineStyle();
	}

	/** A number in [0, 1) that only depends on (id, k). **/
	static function noise( id : Int, k : Int ) : Float {
		var v = Math.sin(id * 12.9898 + k * 78.233) * 43758.5453;
		return v - Math.floor(v);
	}
}
