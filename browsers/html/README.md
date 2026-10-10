# browsers/html: HTML read into a tree

The author's mini-chrome's `languages/html` (`~/github/mini-chrome`),
**its first version** (`475a979`, 2026-09-30), the base of
[`plan_browser.md`](../../docs/plans/plan_browser.md) (stage 4):
`browsers/first_version.sh` takes that tree out of its history.

Each copied file says in one line where it comes from and what changed
(`ix: the author's mini-chrome's <path>, its first version; ...`).

## What was copied

8 modules, 1,185 lines of `.ml` and 638 of `.mli` there:

| module | what |
|---|---|
| `Dtd` | which elements and attributes are HTML 2.0's, which Netscape's |
| `Dom` | a page as a tree: elements, attributes, text |
| `Entities`, `Charset` | `&eacute;`; a page's bytes to UTF-8 |
| `Html_lexer`, `Html_tree` | tags and text; the tree, tags left open closed as browsers do |
| `Forms` | a form's controls and what it sends |
| `Line_mode` | the tree as lines of text, its links numbered: mini-lynx's |

And its tests, `tests/` (mini-chrome's `tests/html`: 44, Testo, dune's
only).

## What changed

No optional argument (mini-ml has none):

- `Dom.element name children` and `Dom.element_with attributes name
  children`; `Dom.attribute name e` and `Dom.attribute_any name e`
  (it was `~extensions:true`: a core element's Netscape attributes
  too).
- `Charset.detect` and `decode` take the content type, an option;
  `Line_mode.render` the width.
- Inside `Forms`, `Html_lexer` (`emit_text_as ~decode`), `Html_tree`,
  `Line_mode`; `Option.value` written out
  (`scripts/option_value.py`); a constructor said with its module.

**Fixed**: `</table>` and `</tr>` end a cell left open
(`Html_tree.end_tag`; `docs/plans/bugs/mini_chrome.md`, 1: today's
mini-chrome has it too).

**Added back** from later mini-chrome: `Line_mode`'s blocks (`div`,
`section`, a table's rows...) each a line of its own, 11 lines, which
came with mini-chrome's mini-lynx (`d3e138f`). With them `mini-lynx
-dump` of the Wikipedia article (354 KB, saved 2026-10-09) is today's
mini-chrome's text, byte for byte (1,977 lines without them, one line
where there were several).

**Added back** for a page's scripts (`browsers/webapi`, 2026-10-10):
`Dom.comment_name` and `Dom.hash`, and `Html_tree.parse_with ~comments`
and `of_string_with` (a comment kept as an element named `#comment`),
14 lines of mini-chrome's later `Dom` and `Html_tree`.

## What remains in mini-chrome

What its `languages/html` gained since (1,408 lines today): `Xml`
(`Svg`'s reader), and what the plan's table of cuts lists; each comes
when a site shows the want of it.
