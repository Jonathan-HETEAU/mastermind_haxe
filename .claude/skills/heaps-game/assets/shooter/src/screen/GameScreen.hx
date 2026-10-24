package screen;

import Controls.Action;
import model.Field;

/**
	A game: plays the `Field` with the controls and draws it again every frame from its state.
	The events of the field become sounds, sparks, shakes and rumbles. Pause (Escape, P, Start, or
	the window losing the focus) opens a menu over the game; after the last life, a panel gives the
	score and saves the best one.
**/
class GameScreen extends Screen {
	/** Seconds before the game over panel accepts a choice: a player still firing does not
		restart by accident (fire and confirm share Space and the A button). **/
	static inline var OVER_DELAY = 1.2;

	var field : Field;
	/** Everything that shakes: the game, not the HUD nor the menus. **/
	var world : h2d.Object;
	var stars : view.Starfield;
	/** The asteroids, the bullets and the ship, drawn again every frame. **/
	var drawing : h2d.Graphics;
	var particles : view.Particles;
	var popups : h2d.Object;
	var scoreText : h2d.Text;
	var bestText : h2d.Text;
	var livesIcons : h2d.Graphics;
	var shownScore = -1;
	var shownLives = -1;
	var best : Int;
	var shake = 0.;
	var time = 0.;
	/** The pause overlay and its menu, while paused. **/
	var pause : Null<h2d.Flow>;
	var pauseMenu : ui.Menu;
	/** The game over panel and its menu, once shown. **/
	var overPanel : Null<h2d.Flow>;
	var overMenu : ui.Menu;
	var overTime = 0.;
	var newBest = false;

	public function new() {
		super();
		field = new Field(1 + Std.random(1000000));
		best = Progress.best();
		// The mask hides what is above the field (asteroids coming in) in the bars around it.
		var mask = new h2d.Mask(Main.WIDTH, Main.HEIGHT, scene);
		world = new h2d.Object(mask);
		stars = new view.Starfield(Main.WIDTH, Main.HEIGHT, world);
		drawing = new h2d.Graphics(world);
		particles = new view.Particles(world);
		popups = new h2d.Object(world);

		scoreText = new h2d.Text(hxd.res.DefaultFont.get(), scene);
		scoreText.setPosition(4, 2);
		bestText = new h2d.Text(hxd.res.DefaultFont.get(), scene);
		bestText.textColor = 0xFFD080;
		bestText.y = 2;
		livesIcons = new h2d.Graphics(scene);
		draw();
	}

	override function onShow() {
		Audio.music(Game);
	}

	override function onAction( a : Action ) {
		if( pause != null )
			pauseMenu.onAction(a);
		else if( overPanel != null )
			overMenu.onAction(a);
		else if( !field.over && (a == Back || a == Pause) )
			openPause();
	}

	override function onFocusLost() {
		if( pause == null && !field.over )
			openPause();
	}

	override function update( dt : Float ) {
		if( pause != null )
			return;
		time += dt;
		if( !field.over ) {
			var c = Main.inst.controls;
			for( e in field.update(dt, c.moveX(), c.moveY(), c.isDown(Fire)) )
				onEvent(e);
		} else {
			overTime += dt;
			if( overPanel == null && overTime > OVER_DELAY )
				showGameOver();
		}
		stars.update(dt);
		particles.update(dt);
		for( p in [for( o in popups ) o] ) {
			p.y -= 20 * dt;
			p.alpha -= dt * 1.5;
			if( p.alpha <= 0 )
				p.remove();
		}
		shake = Math.max(0, shake - dt * 8);
		world.setPosition((Math.random() - 0.5) * shake * 6, (Math.random() - 0.5) * shake * 6);
		draw();
	}

	function onEvent( e : FieldEvent ) {
		switch e {
			case Shot(_, _):
				Audio.play(Shoot, 0.5);
			case Destroyed(a, points):
				Audio.play(Explosion, 0.4 + a.size * 0.2);
				particles.burst(a.x, a.y, 6 + a.size * 6, 30 + a.size * 15, [0xB0A8B8, 0xFFD080, 0xFFFFFF]);
				popup('+$points', a.x, a.y);
				shake = Math.max(shake, a.size * 0.15);
			case ShipHit(a):
				Audio.play(ShipHit);
				particles.burst(a.x, a.y, 20, 60, [0xB0A8B8, 0xFFFFFF]);
				particles.burst(field.shipX, field.shipY, 30, 80, [view.Shapes.SHIP_COLOR, 0xFFA030, 0xFFFFFF]);
				shake = 1;
				Main.inst.controls.rumble(0.8, 0.3);
			case GameOver:
				// Saved at once: the best score is kept even if the window is closed now.
				newBest = Progress.submitScore(field.score);
				Audio.play(newBest ? Record : GameOver);
				Audio.duck(true);
				particles.burst(field.shipX, field.shipY, 60, 100, [view.Shapes.SHIP_COLOR, 0xFFA030, 0xFFFFFF]);
				shake = 1.5;
				trace('game over: score ${field.score}' + (newBest ? ", new best score" : ""));
		}
	}

	/** Draws the field as it is now: it can never disagree with the rules. **/
	function draw() {
		var g = drawing;
		g.clear();
		for( a in field.asteroids )
			view.Shapes.rock(g, a.id, a.x, a.y, a.radius, a.angle);
		g.beginFill(0xFFF080);
		for( b in field.bullets )
			g.drawRect(b.x - 0.5, b.y - 2, 1, 4);
		g.endFill();
		// The ship blinks while it cannot be hit.
		if( !field.over && (field.invincible <= 0 || Std.int(time * 12) % 2 == 0) )
			view.Shapes.ship(g, field.shipX, field.shipY, 0.5 + Math.random() * 0.5);

		if( field.score != shownScore ) {
			shownScore = field.score;
			scoreText.text = 'Score ${field.score}';
			// The best score follows the score once beaten.
			bestText.text = 'Record ${Std.int(Math.max(best, field.score))}';
			bestText.x = Main.WIDTH / 2 - bestText.textWidth / 2;
		}
		if( field.lives != shownLives ) {
			shownLives = field.lives;
			livesIcons.clear();
			for( i in 0...field.lives )
				view.Shapes.ship(livesIcons, Main.WIDTH - 8 - i * 12, 9, 0, 0.7);
		}
	}

	function popup( s : String, x : Float, y : Float ) {
		var t = new h2d.Text(hxd.res.DefaultFont.get(), popups);
		t.text = s;
		t.textColor = 0xFFD080;
		t.setPosition(x - t.textWidth / 2, y - 8);
	}

	/** A dark panel over the game, centered, with a title. **/
	function panel( title : String ) : h2d.Flow {
		var f = new h2d.Flow(scene);
		f.backgroundTile = h2d.Tile.fromColor(0x000000, 1, 1, 0.7);
		f.minWidth = Main.WIDTH;
		f.minHeight = Main.HEIGHT;
		f.layout = Vertical;
		f.verticalSpacing = 6;
		f.horizontalAlign = f.verticalAlign = Middle;
		var t = new h2d.Text(hxd.res.DefaultFont.get(), f);
		t.text = title;
		t.setScale(2);
		return f;
	}

	function openPause() {
		Audio.play(Pause);
		Audio.duck(true);
		pause = panel("PAUSE");
		pauseMenu = new ui.Menu(pause);
		pauseMenu.add("Reprendre", closePause);
		pauseMenu.add("Recommencer", () -> leave(GameScreen.new));
		pauseMenu.add("Menu principal", () -> leave(TitleScreen.new));
		pauseMenu.onBack = closePause;
	}

	function closePause() {
		Audio.duck(false);
		pause.remove();
		pause = null;
	}

	/**
		Leaves the game: its score counts for the best score even when it is not over. The next
		screen is created after the save, so that the title shows the new best score.
	**/
	function leave( next : () -> Screen ) {
		Progress.submitScore(field.score);
		Audio.duck(false);
		Main.inst.show(next());
	}

	function showGameOver() {
		overPanel = panel("PARTIE TERMINÉE");
		var score = new h2d.Text(hxd.res.DefaultFont.get(), overPanel);
		score.text = 'Score : ${field.score}';
		if( newBest ) {
			var t = new h2d.Text(hxd.res.DefaultFont.get(), overPanel);
			t.text = "Nouveau record !";
			t.textColor = 0xFFD080;
		} else {
			var t = new h2d.Text(hxd.res.DefaultFont.get(), overPanel);
			t.text = 'Record : ${Progress.best()}';
			t.textColor = 0x8890B0;
		}
		overMenu = new ui.Menu(overPanel);
		overMenu.add("Rejouer", () -> leave(GameScreen.new));
		overMenu.add("Menu principal", () -> leave(TitleScreen.new));
		overMenu.onBack = () -> leave(TitleScreen.new);
	}
}
