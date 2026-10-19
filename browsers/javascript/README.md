# browsers/javascript: the language, and mini-node

The author's mini-chrome's `languages/javascript`
(`~/github/mini-chrome`, its `8af888e`, 2026-10-08), for
[`plan_browser.md`](../../docs/plans/plan_browser.md)'s stage 9
(scripts in a page): the engine of today, in its four directories,
where stage 8 had its first version's seven files (a teaching subset,
2,238 lines, without `switch`, `in`, classes, promises). 22 modules,
7,505 lines of `.ml` here, and 547 of JavaScript in a string.

Each copied file says in one line where it comes from (`ix: the
author's mini-chrome's <path> (its 8af888e)`).

## What was copied

| directory | modules | lines | what |
|---|---|---:|---|
| `parsing/` | `Js_lexer`, `Js_ast`, `Js_parse` | 1,589 | the tokens (a newline remembered, for the semicolons not written); the tree; statements by recursive descent, expressions by Pratt's binding powers |
| `values/` | `Js_value`, `Js_props`, `Js_operators`, `Js_string`; `Mini_opti`, `Per_domain` | 817 | a value, an object and its prototype, the conversions; a string as its UTF-8 bytes; the switch of the optimized paths |
| `eval/` | `Js_eval`, `Js_scope`, `Js_frame`, `Js_coroutine` | 1,615 | the tree walked: scopes, closures, classes, exceptions, a budget of steps; an async function stopped at an await (a thread) |
| `opti/` | `Js_quicken`, `Js_compile` | 547 | optimizations, not in m-ix's count (`docs/loc.md`): a copy of the tree with each name's place; a function's body compiled to closures. Each tells `Js_eval` of itself when the program starts (`Js_eval.quickener`, `compiler`): the engine runs the same without them, slower |
| `library/` | `Js_builtins`, `Js_globals`, `Js_json`, `Js_promise`, `Js_regexp`; `Js_prelude` | 2,507 | String, Array, Math, Date, Map, Set, Symbol, Proxy, JSON, promises, regular expressions by backtracking; `Js_prelude`: mini-chrome's `data/prelude/library.js` in a string (541 lines; 472 since `DataView` was cut) |

And its tests, `tests/` (mini-chrome's `tests/js` but `Unit_json`: 126,
Testo, dune's only; `MINI_OPTI=off` and `MINI_OPTI=walk` run the simple
paths and the body walked: the three agree).

The parser is written by hand, as mini-chrome's (`Js_parse.mli`, "Why
not yacc": the semicolons a newline stands for, an arrow function known
only at its `=>`), where ix's rule is ocamlyacc for a real grammar:
kept as copied; to be said otherwise.

## What changed

All of it for mini-ml, or for ix's rule that what reaches the system
takes a capability:

- **No optional argument**: two functions (`Js_eval.create ()` and
  `create_with log seed now`; `Js_parse.parse` and `parse_with ~aside`;
  `Js_frame.layout` and `layout_with`; `Js_promise.drain` and
  `drain_each`; `to_primitive` and `to_primitive_as`; `exec` and
  `exec_labelled`, `exec_block` and `exec_block_at`, `export` and
  `export_seen`), or the argument said (`declare_functions ~nested`,
  `Js_builtins.install ~now`, `match_array`'s and `expand`'s regexp).
- **No open type**: `Js_ast.code` is `No_code | Code of exn`, the
  compiled body an exception's value (`Js_value.Compiled`), where it
  was `type code = ..`.
- **No functor**: a table of names is a `Hashtbl` (it was
  `Hashtbl.Make`'s of strings: an optimization).
- **No `'a.` annotation**: `Js_parse.inside` and `Js_json`'s `items`
  are defined before the recursive group that uses them at two types;
  `body_in` gives statements.
- **No `lazy`**: the prelude is read at its first use and kept by hand.
- **No polymorphic variant**: `Js_regexp`'s `escape` and `set_part`,
  `Js_parse`'s `accessor`. No local exception (`Js_value.Cycle`).
  `Js_parse`'s exception is `Parse_error` (it was `Error`, as
  `result`'s). `Option.value` written out; `infinity`, `nan`, `asin`
  are Stdlib's.
- **A label through a function's value is annotated** (`Host_function
  (_, (f : this:value -> value list -> value))`, six places): the
  `~this` label stays, where the first version's port dropped it.
- **The engine reaches no system**: the debugging switches are values a
  host sets (`Js_value.throws_left`, `throws_not`, `stack_words`,
  `Js_parse.syntax_context`), where they were the environment's
  `JS_THROWS`, `JS_THROWS_NOT`, `JS_STACK`, `JS_SYNTAX`; what they say
  goes to `Js_value.say` (nothing by default), and the clock a run is
  stopped by is `Js_value.wall_clock` (0 by default: no stop by the
  clock, the budget of steps still).
- **Left out**: `Js_slice` (the window alive while a script runs: a
  thread and the clock, 96 lines) and its test; `Stopwatch`.

lib_core gained `Float.is_finite`.

## ix's own

`CLI.ml`, `Main.ml`: **mini-node**, written for ix after mini-chrome's
`tools/node`: a file run, `-e text`, or each line of the input run and
its value shown. The language alone: no `require`, no `process`, no
timers. Built by dune (`bin/mini-node`) and by mini-mk
(`_mk/7/browsers/javascript/`: `mkfile`, the units of the four
directories found by name).

`tests/scripts.sh`, `tests/scripts/language.js` and `modern.js`
(classes, destructuring, templates, async and await, generators,
`switch`, labels, `JSON.parse`): the same output by OCaml's build, by
mini-ml's and by Node (the one the machine has); a console's lines.
An async function runs on lib_core's threads there, which are
cooperative.

## Remains

- `Object.prototype.toString.call(e)` is the error's text, not
  "[object Error]" (`e instanceof TypeError` is right since
  2026-10-11: `docs/plans/bugs/mini_chrome.md`, `tests/scripts/errors.js`).
- **Cut** (2026-10-19, `plan_browser.md`, "Smaller", A): `Js_prelude`'s
  `DataView`, numbers of any size read in bytes and floats by IEEE
  754's bits (a page that decodes a file's, not one that is read);
  `ArrayBuffer` and a typed array's `buffer` stay (`TextDecoder`, a
  body of bytes). Its test.
- **Cut** (2026-10-19): ES modules, `Js_module` and the parser's
  `import` and `export`, `import()` and `import.meta` (of the eight
  sites of `coverage_ix.sh` only old.reddit.com's scripts are modules,
  and its page is blank anyway); mini-node runs a file as a script.
  With them `Js_parse`'s `aside` and `Js_eval.read_ahead`, the parse
  memo of mini-chrome's worker pool. Their test, `Unit_js_module`.
- **Generators read, not run** (2026-10-19, `plan_browser.md`, C):
  `function*` and `yield` are parsed -- MediaWiki's startup compiles
  `async function* x() {}` with `new Function` and, if that fails,
  loads none of Wikipedia's scripts -- but calling a generator throws
  "not supported here" (`Js_eval`'s generator, its coroutine and its
  iterator gone). No site of the coverage calls one.
- **A string is its UTF-8 bytes** (2026-10-19, `plan_browser.md`, C;
  the author: "let's remove JS_utf16 if in practice mini-netscape still
  display correctly most pages using accents"): `Js_string` in the
  place of `Js_utf16` (UTF-16's units over UTF-8's bytes, for Gmail's
  startup), 200 lines to 60. "é".length is 2, charCodeAt a byte;
  for-of, Array.from and a pattern's dot still take characters;
  case changes ASCII's letters only; atob and btoa are right for ASCII
  alone. The French, German, Spanish, Polish and Japanese Wikipedias,
  and the five sites, the same pictures both ways. Its tests:
  `Unit_js_string`, the UTF-16 ones gone.
- Kept, by the coverage: a direct `eval` (4 lines).
- 32-bit arm (ints of 31 bits): not tried.
