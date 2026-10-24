/**
	A DomKit example: a HUD and a menu, two components styled by res/ui/style.css, driven by the
	keyboard and the mouse. On HashLink (initLocal), editing the CSS restyles the running game.
**/
class Main extends hxd.App {

	var style : h2d.domkit.Style;
	var menu : ui.MenuComp;

	override function init() {
		s2d.scaleMode = LetterBox(320, 180, true);
		engine.backgroundColor = 0x202030;

		var hud = new ui.HudComp(s2d);
		menu = new ui.MenuComp("Pause", ["Resume", "Options", "Main menu"], "Arrows and Enter", s2d);
		menu.setPosition(60, 30);
		menu.onChoice = i -> hud.label.text = 'Chosen: $i';

		style = new h2d.domkit.Style();
		style.load(hxd.Res.ui.style);
		// Each root component must be added: its children are styled with it.
		style.addObject(hud);
		style.addObject(menu);
		// Debugging the CSS: a middle click on an element shows its properties.
		// style.allowInspect = true;

		// The window gets every key. A listener on s2d would miss them after a click on a button:
		// the clicked h2d.Interactive takes the keyboard focus and receives the keys first.
		hxd.Window.getInstance().addEventTarget(onEvent);
	}

	function onEvent( e : hxd.Event ) {
		if( e.kind != EKeyDown )
			return;
		switch e.keyCode {
			case hxd.Key.UP: menu.selectNext(-1);
			case hxd.Key.DOWN: menu.selectNext(1);
			case hxd.Key.ENTER: menu.confirm();
			default:
		}
	}

	override function update( dt : Float ) {
		// Applies the CSS changes: classes, :hover, transitions, reloaded files.
		style.sync(dt);
	}

	static function main() {
		#if hl
		hxd.res.Resource.LIVE_UPDATE = true;
		hxd.Res.initLocal();
		#else
		hxd.Res.initEmbed();
		#end
		new Main();
	}
}
