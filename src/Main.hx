import game.Game;



enum State {
	Game;
	Exit;
	Restart;
}

typedef CurrentState = {
	state:State,
	scene:Game
}

class Main extends hxd.App {
	private var state:CurrentState;
	/** Created once: each game gets the actions, a restart does not add listeners. **/
	private var controls:Controls;

	override function init() {
		hxd.Window.getInstance().title = "Mastermind";
		// The bands around the board, when the screen is not as tall as the game, are dark walnut.
		engine.backgroundColor = 0x1A0F08;
		controls = new Controls();
		switchState(Game);
	}

	public function switchState(state:State) {
		switch state {
			case Game | Restart:
				var controller = new game.GameController();
				controller.menu = function() {
					this.switchState(Exit);
				}
				controller.restart = function() {
					this.switchState(Restart);
				}
				this.state = {state: Game, scene: new Game(controller)};
			case Exit:
				hxd.System.exit();
		}
		this.state.scene.init(this);
		setScene(this.state.scene.getScene());
	}

	override function update(deltat:Float) {
		super.update(deltat);
		// A restart replaces the game while it handles an action: read the current one each time.
		for (action in controls.pressed())
			this.state.scene.onAction(action);
	}

	static function main() {
		hxd.Res.initEmbed();

		new Main();
	}
}
