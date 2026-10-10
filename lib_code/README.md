# lib_code: code as what a program reads

The author's playground's `libs/code/highlight` (`~/playground`):
`Highlight_code`, the categories a highlighter gives a file's tokens
(a keyword, a comment, a function where it is defined, a type) and a
file as lines of spans, the same for every language. A language's
highlighter is beside the language, and gives these:

| | the playground's | here |
|---|---|---|
| OCaml | `languages/ocaml` | `languages/ml/highlight/` |
| C | `languages/c` | `languages/c/highlight/` |
| assembly | `languages/asm` | `assembler/highlight/` |
| Smalltalk | `languages/smalltalk/Highlight_st` | `languages/smalltalk/highlight/` |
| Scheme, Pascal, Prolog | none | `languages/scheme/highlight/`, `languages/pascal/highlight/`, `languages/prolog/highlight/`: written for ix |

What draws them is mini-emacs (`editors/emacs/`): a mode a language,
its colors `Highlight`'s. The plan:
[`plan_emacs.md`](../docs/plans/plan_emacs.md).

Each copied file says in one line where it comes from and what
changed (`ix: the author's playground's <path>; ...`). The numbers
below are `scripts/playground_copies.sh lib_code languages/ml/highlight
languages/c/highlight assembler/highlight languages/smalltalk`'s,
against the playground at `028d8abf` (2026-10-06).

## What was copied

`Highlight_code` (2 files: 282 lines there, 110 here) and four
highlighters (16 files: 1,996 lines there, 1,412 here).

## What changed

- **An editor's colors, not a code map's.** `Highlight_code` has the
  categories, a span and `lines`. Gone: the colors (codemap's, as
  red, green and blue: an editor has its own, a terminal's eight), a
  category's name and its size seen from afar, and what a map of
  several files asks of each (the occurrences of a name, the
  definitions, the references: `analysis`). So each highlighter has
  `lines`, and no `analyze`.
- **The tokens, not the tree.** The playground's OCaml and C
  highlighters make two passes: a guess from each token and its
  neighbours, then, over it, what a parse of the file says of each
  name (its scope: a parameter, a local, a field). Here the first
  pass only: `Parse_ml` and `Ast_ml` (1,338 lines) and `Parse_c` and
  `Ast_c` (1,013) are not copied. For OCaml the second pass is ix's
  own, `Names_ml` (123 lines): mini-ml's parser is asked, an item of
  the program at a time, and its tree says where a parameter, a local
  and a field are; an item that does not parse (the one being typed)
  keeps the guess. C's highlighter says a keyword, a type's keyword,
  a number, a string, a comment, a constant in capitals, and no more
  of a name.
- **What mini-ml and mini-lex have not**: the two lexers' polymorphic
  variants are a type (`lexed`), and `Highlight_ml`'s (`binder`); a
  comment of `Lexer_ml.mll` that quoted a comment's end says it in
  words.
- `Highlight_asm` still colors an operand that is one of the file's
  labels; `Highlight_st` still follows the bindings it followed.

## What remains in the playground

The two parsers and their trees (above); each highlighter's tests
(`Unit_highlight_ml`, `Unit_lexer_ml`, `Unit_highlight_c`, `Test_asm`,
`Unit_highlight_st`: 412 lines): here mini-emacs's sessions show each
language's colors (`editors/emacs/tests/keys.sh`).
