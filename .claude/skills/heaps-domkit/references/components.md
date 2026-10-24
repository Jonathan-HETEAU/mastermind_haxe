# DomKit components of Heaps and their CSS properties

Generated from `h2d/domkit/BaseComponents.hx` (Heaps git, October 2026). A component also has
the properties of the one it extends. Check an older Heaps with:
`grep -n '@:uiComp\|@:p' $(haxelib libpath heaps)h2d/domkit/BaseComponents.hx`.

| Component | Heaps class | Extends | Properties |
|---|---|---|---|
| `object` | `h2d.Object` |  | `x`, `y`, `alpha`, `rotation`, `visible`, `scale`, `scale-x`, `scale-y`, `blend`, `filter`, `filter-smooth`, `margin`, `margin-left`, `margin-right`, `margin-top`, `margin-bottom`, `align`, `halign`, `valign`, `position`, `offset`, `offset-x`, `offset-y`, `min-width`, `min-height`, `force-line-break`, `auto-size`, `auto-size-width`, `auto-size-height` |
| `drawable` | `h2d.Drawable` | `object` | `tint`, `smooth`, `color-adjust`, `tile-wrap` |
| `mask` | `h2d.Mask` | `object` | `width`, `height` |
| `video` | `h2d.Video` | `drawable` | `src`, `loop` |
| `bitmap` | `h2d.Bitmap` | `drawable` | `src`, `src-pos`, `src-flip-x`, `src-flip-y`, `src-pos-x`, `src-pos-y`, `width`, `height` |
| `text` | `h2d.Text` | `drawable` | `font`, `letter-spacing`, `line-spacing`, `line-break`, `word-break`, `max-width`, `text-align`, `text-shadow`, `color` |
| `html-text` | `h2d.HtmlText` | `text` | `condense-white`, `propagate-interactive-node`, `tags` |
| `scale-grid` | `h2d.ScaleGrid` | `drawable` | `ignore-scale`, `border-scale`, `tile-borders`, `tile-center`, `width`, `height` |
| `flow` | `h2d.Flow` | `object` | `width`, `height`, `max-width`, `max-height`, `background-id`, `background`, `background-tile`, `background-tile-pos`, `background-tile-pos-x`, `background-tile-pos-y`, `background-alpha`, `background-smooth`, `background-repeat`, `debug`, `layout`, `vertical`, `horizontal`, `stack`, `multiline`, `padding`, `padding-left`, `padding-right`, `padding-top`, `padding-bottom`, `hspacing`, `vspacing`, `spacing`, `fill-width`, `fill-height`, `overflow`, `scroll-wheel-speed`, `reverse`, `content-align`, `content-valign`, `content-halign`, `cursor`, `propagate`, `inline-block` |
| `input` | `h2d.TextInput` | `text` | `width`, `cursor`, `selection`, `edit`, `background-color`, `multiline` |

## Values

| Kind | Syntax |
|---|---|
| Color | `#RGB`, `#RRGGBB`, `rgb(r, g, b)`, `rgba(r, g, b, a)` with `a` from 0 to 1, a CSS color name (`white`, `red`...). `#RRGGBBAA` is **not** read as an alpha: use `rgba()`. |
| Flow `background` | `transparent`; a color; `#000 0.5` (color and alpha); a tile and scale-grid borders `"ui/frame.png" 4 4` or `... 4 4 4 4`; `disc(color [alpha])` |
| Tile (`src`, `background-tile`) | a resource path (`"ui/icon.png"`), a color, `color width height`, `tile("path", size)`, `grid("path", columns, rows)`, `hgrid(...)`, `vgrid(...)`, `none` |
| `font` | `default`, a font resource (`url("fonts/title.fnt")`), optionally followed by SDF parameters; `group(...)` combines fonts |
| `text-shadow` | `dx dy [color [alpha]]` or `none` |
| `layout` | `horizontal`, `vertical`, `stack` (children on top of each other) |
| `padding`, `margin` | one to four numbers, in the CSS order: `8`, `8 16` (vertical horizontal), `8 16 4`, `8 16 4 0` (top right bottom left) |
| `content-align` / `align` | `left`, `middle`, `right` and/or `top`, `middle`, `bottom` (`middle middle` centers both ways); `auto` |
| `cursor` | `default`, `button`, `move`, `textinput`, `hide`, `none`, `ns-resize`, `ew-resize`... |
| Sizes | numbers without unit (pixels of the scene); `none` where marked (`min-width: none`) |

Variables (as in LESS): `@title-font: url("fonts/title.fnt");` then `font: @title-font;`.
Selectors: `name`, `.class`, `#id`, the pseudo-classes `:hover`, `:active`, `:focus`, `:disabled`,
`:first-child`, `:last-child`, descendants (`menu button text`), children (`>`), and nesting with `&`
(`button { &.selected { ... } }`). `transition: background 0.5;`
animates a property.

