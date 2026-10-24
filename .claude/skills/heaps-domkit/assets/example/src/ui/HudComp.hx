package ui;

/**
	The HUD: a line of text at the top of the screen. Its look is in res/ui/style.css.
**/
@:uiComp("hud")
class HudComp extends h2d.Flow implements h2d.domkit.Object {

	static var SRC = <hud>
		<text public id="label" text={"Choose with the arrows or the mouse"}/>
	</hud>;

	public function new( ?parent ) {
		super(parent);
		initComponent();
	}
}
