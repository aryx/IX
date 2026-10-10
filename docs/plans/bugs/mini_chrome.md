# Bugs found in mini-chrome, from ix

ix's browser ([`plan_browser.md`](../plan_browser.md)) starts from the
first version of the author's mini-chrome (`~/github/mini-chrome`,
`475a979`) and brings back what it gained since. What its files, tried
here, got wrong is below, each with a reproduction; "today's too" says
that mini-chrome at `8af888e` (2026-10-07) still has it.

## 1. `</table>` does not end a table whose last cell is open

`languages/html/Html_tree.ml`, `end_tag`: an end tag looks for its
element up the stack and stops at `html`, `table`, `td`, `th` or
`caption`. For `</table>` (and `</tr>`) written while a cell is open,
the cell is on top: the search stops at once, the end tag is dropped,
and what follows the table is the cell's.

    <table><tr><td>d</table><p id=after>x</p>

The `<p>` is laid out inside the `<td>` (`browsers/engine/tests/Boxes.exe`:
`p#after` under `td`, 8 wide), where with `</td></tr>` written it is
under `body`, 384 wide. Today's too (its `end_tag` is the same line).

Fixed here (`browsers/html/Html_tree.ml`): `</table>` stops at `html`
only, `</tr>`, `</thead>`, `</tbody>` and `</tfoot>` at `html` and
`table`. `browsers/engine/tests/pages/small.html` has the case.

## 2. `e instanceof Error` is false for a caught `new Error` (first version)

`languages/javascript`, the first version's engine:

    try { throw new Error("x") } catch (e) { console.log(e instanceof Error) }

says `false`; Node says `true`.

Today's mini-chrome too (its `8af888e`, and ix's copy of its engine,
2026-10-10), for an error made by `new` and for one the engine throws:

    var e = new TypeError("x");
    console.log(e instanceof TypeError, e instanceof Error,
                Object.getPrototypeOf(e) === TypeError.prototype);

says `false false false` by `mini-node` (ix's and mini-chrome's `bin/mini-node`),
`true true true` by Node; `new T() instanceof T` and `[] instanceof
Array` are right. Fixed in ix (2026-10-11): an error is a plain
object with no prototype of its own, and nothing gave it its kind's;
`Js_builtins.error_proto` does, by its name, where an object's
prototype is looked up (`Js_props.proto_of`, `Object.getPrototypeOf`;
`browsers/javascript/tests/scripts/errors.js`). Not fixed in
mini-chrome.
