package view;

/** Stars scrolling down at three speeds: the ship seems to fly up. **/
class Starfield extends h2d.Graphics {
	static final SPEEDS = [8., 18., 40.];
	static final COLORS = [0x505878, 0x8890B0, 0xE0E8FF];
	static inline var PER_LAYER = 30;

	var stars : Array<{ x : Float, y : Float, layer : Int }> = [];
	var width : Int;
	var height : Int;

	public function new( width : Int, height : Int, ?parent ) {
		super(parent);
		this.width = width;
		this.height = height;
		for( layer in 0...SPEEDS.length )
			for( i in 0...PER_LAYER )
				stars.push({ x : Math.random() * width, y : Math.random() * height, layer : layer });
		update(0);
	}

	public function update( dt : Float ) {
		clear();
		for( s in stars ) {
			s.y += SPEEDS[s.layer] * dt;
			if( s.y > height ) {
				s.y -= height;
				s.x = Math.random() * width;
			}
			beginFill(COLORS[s.layer]);
			drawRect(Std.int(s.x), Std.int(s.y), 1, s.layer == 2 ? 2 : 1);
		}
		endFill();
	}
}
