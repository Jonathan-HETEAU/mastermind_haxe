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

	override function init() {
		hxd.Window.getInstance().title = "Mastermind";
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
	}

	static function main() {
		hxd.Res.initEmbed();

		new Main();
	}
}
