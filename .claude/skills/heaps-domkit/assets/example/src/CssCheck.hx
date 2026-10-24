/**
	Checks stylesheets against the DomKit components at compile time: an unknown property or an
	invalid value becomes a compilation error, with its line, instead of being silently ignored.

	In the hxml: `--macro CssCheck.check("res/ui/style.css")` (one call per file).
**/
class CssCheck {
	public static function check( file : String ) {
		#if macro
		// After typing, when all the components of the game are known.
		haxe.macro.Context.onAfterTyping(_ -> domkit.Macros.checkCSS(file));
		#end
	}
}
