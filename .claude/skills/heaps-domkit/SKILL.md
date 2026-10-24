---
name: heaps-domkit
description: Build game UI in Heaps with DomKit - components declared with an XML-like markup inside Haxe classes (@:uiComp, static var SRC), styled by CSS files from res/ with live reload. Use it whenever you create or fix menus, HUDs, dialogs, buttons, option screens or any h2d.Flow based UI in a Heaps game, write or debug a DomKit .css/.less stylesheet, or hit DomKit errors such as "Could not load component", "Expected attribute name", "Too many arguments" in Style.hx, or a style that does not apply.
---

# Game UI with DomKit

DomKit adds to Heaps what HTML and CSS give to a web page: a component declares its children in
a markup (`SRC`), and a stylesheet in `res/` sets their look (sizes, colors, fonts, layout).
The look can then change without recompiling (HashLink reloads the CSS while the game runs),
and a menu is a few lines of markup instead of dozens of `h2d.Flow` settings.

A complete, tested example (a HUD and a menu with keyboard and mouse) is in
`${CLAUDE_SKILL_DIR}/assets/example`; the components and their CSS properties are listed in
[references/components.md](references/components.md).

## Setup

```hxml
-lib heaps
-lib domkit
# Where the components of the game are (see "Finding components"); required before May 2025:
--macro domkit.Macros.registerComponentsPath("ui.$Comp")
```

Heaps and DomKit must be of the same period (errors in `h2d/domkit/Style.hx` such as "Too many
arguments" or "RuleStyle has no field pos" mean they are not: see the **heaps-setup** skill).

```haxe
style = new h2d.domkit.Style();
style.load(hxd.Res.ui.style);   // res/ui/style.css (or .less); reloaded when it changes
style.addObject(menu);          // each root component; its children are styled with it
// in update(dt):
style.sync(dt);                 // applies classes, :hover, transitions and reloaded files
```

## A component

```haxe
package ui;

@:uiComp("button")                       // the name used in markup and CSS: <button>, button { }
class ButtonComp extends h2d.Flow implements h2d.domkit.Object {

	static var SRC = <button>
		<text public id="label" text={text}/>
	</button>;

	public dynamic function onClick() {}

	public function new( text : String, ?parent ) {
		super(parent);
		initComponent();                     // creates the children of SRC; fields exist after it
		enableInteractive = true;            // h2d.Flow creates `interactive`
		interactive.onClick = _ -> onClick();
		interactive.onOver = _ -> dom.hover = true;    // drives :hover in the CSS
		interactive.onOut = _ -> dom.hover = false;
		interactive.onPush = _ -> dom.active = true;   // drives :active
		interactive.onRelease = _ -> dom.active = false;
	}
}
```

The markup, inside `SRC`:

| Markup | Meaning |
|---|---|
| `<text text={expr}/>` | an attribute in braces is a Haxe expression (here the `text` field); constructor arguments are in scope |
| `<flow class="panel title">` | CSS classes; `id="name"` too (`#name` in CSS) |
| `<text id="label"/>`, `<text public id="label"/>` | creates a field `label` (private or public) holding the object |
| `<button("Resume") id="ok"/>` | arguments of the component's constructor |
| `for( l in labels ) <button(l) id="buttons[]"/>` | one child per item; `id="x[]"` collects them in an array field |
| `<text text={hint} if(hint != null)/>` | created only if the condition holds. `if(...)` must be the **last** attribute (otherwise "Expected attribute name") |
| `<bitmap src={tile}/>`, `<flow>`, `<object>`, `<html-text>`, `<input>`... | the built-in components (references/components.md) |

At runtime: `dom.addClass("selected")`, `dom.removeClass(...)`, `dom.toggleClass(c, on)`,
`dom.hover`, `dom.active`, `dom.disabled`, `dom.focus` change what the CSS matches.

## Finding components: naming

For `<title>` in a markup, DomKit looks for a class named after the component, `Title` or
`TitleComp` (`pause-menu` -> `PauseMenu` / `PauseMenuComp`), **as seen from the file of the
markup**: same file, same package, or imported. Other places need their package registered:
`--macro domkit.Macros.registerComponentsPath("ui.widgets.$")` (`$` is the class name; DomKit
before May 2025 only searched the registered paths and the Heaps base components).

**"Could not load component 'title'"** means no such class is visible:

- the class is in another package: `import ui.widgets.Title;` in the file of the markup, or
  register the package;
- the class has another name (`@:uiComp("title") class Heading` is **not** found): rename it
  `Title` or `TitleComp`.

## CSS

```css
@title-font: url("ui/title.fnt");      /* variables, as in LESS */

menu {
	layout: vertical;                  /* horizontal | vertical | stack */
	content-align: middle top;
	padding: 12 24;                    /* numbers, no unit */
	vspacing: 6;
	background: #102040 0.8;           /* color and alpha */
	.title { font: @title-font; color: white; }
}

button {
	min-width: 140;
	background: #304060;
	transition: background 0.2;
	&.selected { background: #5070A0; text { color: white; } }
	&:hover { background: #406080; }
}
```

Pitfalls:

- `#RRGGBBAA` is not read as an alpha: the number is taken as `0xRRGGBBAA` and its low 24 bits
  become an opaque color (`#00000080` is dark blue, `#FF000080` is navy, not red). Write
  `rgba(0, 0, 0, 0.5)`, or `color alpha` for a flow background (`background: #000 0.5`).
- Properties are those of the component **class** (references/components.md): `font` and `color`
  are on `text`, not on a `flow`; style the `text` inside (`button text { color: ... }`).
- A component that is not given to `style.addObject` (directly or as a child of one) gets no
  style at all.
- A component is matched by its **tag**: when `<text class="title">` becomes a `<title>`
  component, the rules on `.title` stop matching (silently); write `title { ... }`, and style
  its inner `text` (`title text { font: ...; }`).
- Do not name a component method like a method of `h2d.Object` / `h2d.Flow` (`move`, `remove`,
  `scale`, `rotate`...): "Field move should be declared with 'override'".
- Fonts in CSS are resources: `url("ui/title.fnt")` (bitmap font, with its `.png`). `default` is
  the Heaps default font.

## Keyboard and gamepad navigation

DomKit has no focus navigation: keep the selected index in the component, put a CSS class on
the selected child (`selected`), and call `selectNext(±1)` / `confirm()` from the key or gamepad
actions (the example's `MenuComp`; the **heaps-game** skill shows the action mapping).

Listen to the keys on the window, `hxd.Window.getInstance().addEventTarget(onEvent)`, not with
`s2d.addEventListener`: a button that was clicked (its `h2d.Interactive`) takes the keyboard
focus and receives the keys first, so a scene listener stops seeing them after a mouse click.

## Debugging

- **Check the CSS at compile time.** At runtime a misspelled property, or one the component does
  not have, is ignored without a message. `domkit.Macros.checkCSS` turns them into compilation
  errors (`res/ui/style.css:55: Unknown property colr`), but it must run once the components are
  typed: copy `${CLAUDE_SKILL_DIR}/assets/example/src/CssCheck.hx` into the game and add
  `--macro CssCheck.check("res/ui/style.css")` to the hxml (as the example does). Calling
  `checkCSS` directly from `--macro` fails with "Could not load component".
- A syntax error in the stylesheet stops the game at `style.load`, with `file:line: message`.
- On HashLink with `initLocal`, saving the CSS while the game runs reloads it and lists the
  invalid properties and values in a red panel at the bottom of the screen.
- `style.allowInspect = true`: a middle click on an element shows its component, classes and
  applied properties.
- Look at the result with the **heaps-browser-test** skill (screenshots of the web build).
