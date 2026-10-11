import mastermind.Mastermind;
import view.BoardView;

/**
	One game: connects the rules (`Mastermind`, the model) to the screen (`BoardView`, the view).

	Every action of the player follows the same path: the view reports it through a callback, the
	game updates the model, then asks the view to redraw itself from the model (`refresh`). The
	model never knows about the view and the view never changes the model, so each one can be
	changed or tested without the other.

	The color picked in the palette is kept here, not in the model: it is a state of the
	interface, not of the rules (it does not exist in the board game).
**/
class Game {
	/** Called when the player asks for a new game. **/
	public dynamic function onRestart() {}

	var model:Mastermind;
	var view:BoardView;
	var selected:Null<Color>;

	public function new(parent:h2d.Object) {
		model = new Mastermind();
		view = new BoardView(parent);
		view.onPickColor = color -> {
			selected = color;
			refresh();
		};
		view.onClickHole = hole -> {
			if (selected != null && model.place(hole, selected))
				refresh();
		};
		view.onSubmit = () -> {
			if (model.submit() != null)
				refresh();
		};
		view.onRestart = () -> onRestart();
		refresh();
	}

	function refresh() {
		view.refresh(model, selected);
	}

	/** Removes the board from the scene (its tiles stay cached in `hxd.Res`). **/
	public function dispose() {
		view.remove();
	}
}
