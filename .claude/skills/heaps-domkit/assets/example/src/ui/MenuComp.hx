package ui;

/**
	A menu: a title and one button per choice. The selected button has the class `selected`,
	so the CSS decides how it looks; arrows/Enter (or a gamepad, see Controls in heaps-game)
	call `selectNext` and `confirm`.
**/
@:uiComp("menu")
class MenuComp extends h2d.Flow implements h2d.domkit.Object {

	static var SRC = <menu>
		<text class="title" text={title}/>
		for( label in labels )
			<button(label) id="buttons[]"/>
		<text class="hint" text={hint} if(hint != null)/>
	</menu>;

	/** Called with the index of the confirmed choice. **/
	public dynamic function onChoice( index : Int ) {}

	var selected = 0;

	public function new( title : String, labels : Array<String>, ?hint : String, ?parent ) {
		super(parent);
		initComponent();
		for( i => b in buttons ) {
			b.onClick = () -> { select(i); confirm(); };
			b.onOver = () -> select(i);
		}
		select(0);
	}

	public function selectNext( delta : Int ) {
		select((selected + delta + buttons.length) % buttons.length);
	}

	public function confirm() {
		onChoice(selected);
	}

	function select( i : Int ) {
		buttons[selected].dom.removeClass("selected");
		selected = i;
		buttons[selected].dom.addClass("selected");
	}
}

/** A button: a label in a flow that reacts to the mouse (`:hover`, `:active` in the CSS). **/
@:uiComp("button")
class ButtonComp extends h2d.Flow implements h2d.domkit.Object {

	static var SRC = <button>
		<text public id="label" text={text}/>
	</button>;

	public dynamic function onClick() {}
	public dynamic function onOver() {}

	public function new( text : String, ?parent ) {
		super(parent);
		initComponent();
		enableInteractive = true;
		interactive.onClick = _ -> onClick();
		interactive.onOver = _ -> { dom.hover = true; onOver(); };
		interactive.onOut = _ -> dom.hover = false;
		interactive.onPush = _ -> dom.active = true;
		interactive.onRelease = _ -> dom.active = false;
	}
}
