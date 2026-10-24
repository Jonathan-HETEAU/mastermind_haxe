package ui;

import Controls.Action;

/**
	A vertical list of choices for the keyboard, the gamepad and the mouse: Up / Down select,
	Confirm runs the selected choice, Back runs `onBack`. The selected choice is drawn brighter.
**/
class Menu extends h2d.Flow {
	static inline var COLOR = 0x9090A0;
	static inline var SELECTED_COLOR = 0xFFD080;

	/** Called by the Back action (Escape, gamepad B). **/
	public dynamic function onBack() {}

	var items : Array<{ text : h2d.Text, mouse : h2d.Interactive, run : Void -> Void }> = [];
	var selected = 0;

	public function new( ?parent ) {
		super(parent);
		layout = Vertical;
		verticalSpacing = 4;
		horizontalAlign = Middle;
	}

	/** Adds a choice; `label` can be changed later with `setLabel`. **/
	public function add( label : String, run : Void -> Void ) {
		var index = items.length;
		var text = new h2d.Text(hxd.res.DefaultFont.get(), this);
		text.text = label;
		var mouse = new h2d.Interactive(0, 0, text);
		mouse.onOver = _ -> select(index);
		mouse.onClick = _ -> confirm();
		items.push({ text : text, mouse : mouse, run : run });
		setLabel(index, label);
	}

	public function setLabel( index : Int, label : String ) {
		var item = items[index];
		item.text.text = label;
		// The mouse area follows the size of the text.
		item.mouse.width = item.text.textWidth;
		item.mouse.height = item.text.textHeight;
		refresh();
	}

	/** Handles a menu action. Returns whether it was used. **/
	public function onAction( a : Action ) : Bool {
		switch a {
			case Up: select((selected + items.length - 1) % items.length);
			case Down: select((selected + 1) % items.length);
			case Confirm: confirm();
			case Back: Audio.play(UiBack); onBack();
			default: return false;
		}
		return true;
	}

	function select( index : Int ) {
		if( index == selected )
			return;
		selected = index;
		Audio.play(UiMove);
		refresh();
	}

	function confirm() {
		Audio.play(UiConfirm);
		items[selected].run();
	}

	function refresh() {
		for( i => item in items )
			item.text.textColor = i == selected ? SELECTED_COLOR : COLOR;
	}
}
