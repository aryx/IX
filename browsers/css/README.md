# browsers/css: style sheets read, matched, computed

The author's mini-chrome's `languages/css` (`~/github/mini-chrome`),
**its first version** (`475a979`, 2026-09-30), the base of
[`plan_browser.md`](../../docs/plans/plan_browser.md) (stage 6, its
first half). Over `browsers/html` (`Dom`).

Each copied file says in one line where it comes from
(`ix: the author's mini-chrome's <path>, its first version`).

## What was copied

7 modules, 2,119 lines of `.ml` and 733 of `.mli` there, and `ua.css`:

| module | what |
|---|---|
| `Css_syntax` | a sheet's tokens, rules and declarations |
| `Selectors` | a selector read, and matched against an element and its ancestors |
| `Css_values` | lengths, `calc()`, colours |
| `Cascade` | which declaration wins: origin, specificity, order; `@media`, custom properties |
| `Computed` | each element's computed style, inherited down the tree |
| `Looks` | a word's look (size, weight, colour, link), as `Box_layout` gives each fragment; `<font size=>`'s scale |
| `Css` | a sheet's rules read and matched: a script's selectors (`querySelector`), a `style=` |
| `Ua_sheet` | `ua.css`, the browser's own sheet (53 lines), in a string |

And its tests, `tests/` (mini-chrome's `tests/css`: 30, Testo, dune's
only).

## What changed

No optional argument, each a pair of functions:

- `Selectors.matches` and `matches_visited visited`;
  `Cascade.cascade visited` and `explain visited` (it is said);
  `Computed.styles` and `styles_with visited ~quirks`.
- `Dom.attribute ~extensions:true` is `Dom.attribute_any`
  (`browsers/html`'s README).
- `Ua_sheet.ml` is kept: mini-chrome's dune makes it of `ua.css`; here
  neither dune nor mini-mk has a rule for it. To change the sheet,
  change the string.
- `Option.value` written out (`scripts/option_value.py`).

mini-ml takes the rest as it is.

## Cut

2026-10-19 (`docs/plans/plan_browser.md`, "Smaller", A), with
Mosaic's layout (`browsers/engine`'s README): `Looks`' table of each
element's look and box and what style sheets did to them (`look`,
`box`, `styled`, `length`), and `Css.cascade` and `page_sheet`, the
first lessons' cascade (`Unit_css` runs on `Cascade` now).

## What remains in mini-chrome

What its `languages/css` gained since (2,548 lines today): `Css_grid`'s
lines' names and spans (the module itself is here since 2026-10-11,
as its `add433e` first had it, 72 lines: the Wikipedia article's
three columns), `Css_logical`, `@layer`, the styles kept from one styling
to the next (speed).
