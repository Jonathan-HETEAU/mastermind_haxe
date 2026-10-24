package view;

private typedef Particle = { x : Float, y : Float, vx : Float, vy : Float, life : Float, time : Float, color : Int, size : Float };

/** Sparks of explosions: only for the eyes, the rules never see them. **/
class Particles extends h2d.Graphics {
	var list : Array<Particle> = [];

	/** `count` sparks flying from (x, y) at up to `speed` pixels per second. **/
	public function burst( x : Float, y : Float, count : Int, speed : Float, colors : Array<Int> ) {
		for( i in 0...count ) {
			var a = Math.random() * Math.PI * 2, s = speed * (0.3 + Math.random() * 0.7);
			list.push({
				x : x, y : y,
				vx : Math.cos(a) * s, vy : Math.sin(a) * s,
				life : 0.4 + Math.random() * 0.5, time : 0,
				color : colors[Std.random(colors.length)],
				size : Math.random() < 0.3 ? 2 : 1,
			});
		}
	}

	public function update( dt : Float ) {
		clear();
		for( p in list.copy() ) {
			p.time += dt;
			if( p.time >= p.life ) {
				list.remove(p);
				continue;
			}
			p.x += p.vx * dt;
			p.y += p.vy * dt;
			p.vx *= Math.pow(0.1, dt);
			p.vy *= Math.pow(0.1, dt);
			beginFill(p.color, 1 - p.time / p.life);
			drawRect(p.x, p.y, p.size, p.size);
		}
		endFill();
	}
}
