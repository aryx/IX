# browsers/javascript: the language, and mini-node

The author's mini-chrome's `languages/javascript`
(`~/github/mini-chrome`), **its first version** (`475a979`,
2026-09-30), the base of
[`plan_browser.md`](../../docs/plans/plan_browser.md) (stage 8). A
teaching subset: what the playground's own pages ran. Today's
mini-chrome's is three times that (6,448 lines), grown for the sites
that are all scripts; what a site asks for is added back from it.

Each copied file says in one line where it comes from
(`ix: the author's mini-chrome's <path>, its first version`).

## What was copied

7 modules, 2,238 lines of `.ml` and 597 of `.mli` there:

| module | what |
|---|---|
| `Js_lexer` | the tokens; a newline remembered, for the semicolons not written |
| `Js_ast`, `Js_parse` | the tree; statements by recursive descent, expressions by Pratt's binding powers |
| `Js_value` | a value, an object and its prototype, the conversions |
| `Js_regexp` | regular expressions, by backtracking |
| `Js_builtins` | String, Array, Math, JSON.stringify, Date, console |
| `Js_eval` | the tree walked: scopes, closures, `this`, `new`, exceptions, a budget of steps |

And its tests, `tests/` (mini-chrome's `tests/js`: 30, Testo, dune's
only).

The parser is written by hand, as mini-chrome's (`Js_parse.mli`, "Why
not yacc": the semicolons a newline stands for, an arrow function known
only at its `=>`), where ix's rule is ocamlyacc for a real grammar:
kept as copied, 400 lines; to be said otherwise.

## What changed

- No optional argument: `Js_eval.create ()` and `Js_eval.create_with
  log seed now`; `Js_builtins.install ~now`.
- **No `~this` label**: a host function is `value -> value list ->
  value`, `this` first (61 places). mini-ml does not know the labels of
  a function taken out of a constructor (`Host_function (_, f)`), and
  the two arguments are of different types.
- `Js_regexp`: two small types (`escape`, `set_part`) where polymorphic
  variants were; `Js_value`: `exception Cycle` at the top (it was
  local); `Js_parse`: its exception is `Parse_error` (it was `Error`,
  as `result`'s constructor, which mini-ml mixed up); `infinity` and
  `nan` are Stdlib's (lib_core's `Float` has not them);
  `Option.value` written out.

## ix's own

`CLI.ml`, `Main.ml`: **mini-node**, written for ix after mini-chrome's
`tools/node`: a file run, `-e text`, or each line of the input run and
its value shown. The language alone: no `require`, no `process`, no
timers. Built by dune (`bin/mini-node`) and by mini-mk
(`_mk/7/browsers/javascript/`).

`tests/scripts.sh`, `tests/scripts/language.js`: 18 lines of output
over the language, the same by OCaml's build, by mini-ml's and by Node
(v the machine has); a console's lines.

## What it has not (found by trying, 2026-10-09)

`in`, `for (k in o)`, `delete`, `instanceof Error` true for a thrown
`new Error` (it says false: mini-chrome's first version's, not looked
into), `switch`, `do`, `finally`, `void`, labels, the comma operator,
the bitwise operators and shifts, `**`, `class`, destructuring,
template literals, `JSON.parse`, getters, generators, `async`,
modules, backreferences and lookarounds in a regular expression,
`(255).toString(16)` (it says 255). jQuery needs most of them: stage 9
(scripts in a page) starts by bringing back mini-chrome's `e74db65`
and what follows, a commit at a time.
