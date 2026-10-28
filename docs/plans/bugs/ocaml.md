# Bugs found in OCaml itself

What ix's tests found in the OCaml compiler and runtime, for the
author to decide whether to report upstream. Found on 2026-09-24,
while fuzzing mini-chidb (`database/tests/fuzz.py 2 40`, session 39).

## arm64: a derived pointer reused across an allocation

**What**: in native code on arm64, a function that reads the same
`Bytes.get b i` twice, once before and once after an allocation, may
read the second time through an address computed for the first. If the
allocation runs a minor GC that moves `b` (a young block), the address
is stale and the read returns garbage. No `unsafe`, no C stub: plain
OCaml gives a wrong answer.

**Reproduction**: [`tests/ocaml_bugs/arm64_derived_pointer.ml`](../../../tests/ocaml_bugs/arm64_derived_pointer.ml),
standalone:

```ocaml
let rec go b pos acc =
  if pos >= Bytes.length b then acc
  else if Char.code (Bytes.get b pos) land 0x80 <> 0 then go b (pos + 1) (1000 :: acc)
  else go b (pos + 1) (Char.code (Bytes.get b pos) :: acc)
(* ... go (Bytes.copy b) 0 [] compared a million times with its first
 * result, with some allocation in between to move the GC *)
```

```
   $ ocamlfind ocamlopt arm64_derived_pointer.ml -o r && ./r
   bad: 102                          (should be 0)
```

Measured on an Ampere Altra (Neoverse-N1, 4K pages, Linux 6.12):

| compiler | bad results in 1,000,000 |
|---|---|
| 4.11.2 (opam, default-unsafe-string) | 107 |
| 4.14.2 | 102 |
| 5.3.0 | 173 |
| 4.14.2 bytecode (`ocamlc`) | 0 |

The counts are the same from run to run and when pinned to one CPU
(`taskset`): not a race, a miscompilation.

**Why** (read from `ocamlopt -S`, 4.14.2, a variant of the function
above): the test computes the byte's address `add x4, x3, x10` (`x3`
the bytes, `x10` the index) and loads through it; the `else` branch
then allocates the list cell (`sub x27, x27, #24`, `caml_call_gc` if
the minor heap is full) and loads the byte again with
`ldrb w14, [x4, #0]`, through the address computed before. The GC
updates `x3`, a root in the frame descriptor, but not `x4`, a pointer
into the middle of the block. The second read's address was shared
with the first, presumably by common subexpression elimination, which
must not keep a derived pointer live across a point where the GC can
run.

**How it showed**: mini-chidb's `Record.types` read a record's header this
way; a scan returned 29 rows where chidb and SQLite return 43, the
record of the 30th row read as `Invalid_type 244`, though its bytes
were right, and the same program in bytecode, or run with a debug
print, was right.

**Workaround in ix**: read the byte once into a variable
(`let c = Char.code (Bytes.get b i) in ...`), so that nothing is read
again after the allocation (`database/storage/Record.ml`, `types`, with a
`claude:` comment). Other code may have the pattern; nothing in the
compiler flags turns the sharing off (`ocamlopt -help` has no such
option).

**Status**: not found in OCaml's issue tracker by a web search
(2026-09-24); not reported.

## OCaml 5: a quoted string's | then bytes not UTF-8 then } refused

**What**: a quoted string `{id|...|id}` holds any bytes in OCaml
4.14. In 5.5.1 (5.x's lexer reads a closing delimiter's name as a
UTF-8 identifier), a `|` followed by bytes that are not UTF-8 and a
`}` inside it is taken for a delimiter, and its name refused: the
whole file is an error. Valid UTF-8 there (`|é}`) is accepted.
Found 2026-10-28: tiny/sdl's TinyFont.ml, grey.font's bytes in a
`{font|...|font}`, the bytes `|\xf4}` among them (make test's "ix by
OCaml 5.5.1"); the font is now written as `\xNN` escapes.

**Reproduction**:

```
$ printf 'let s = {x|a|\xf4}b|x}\nlet () = print_int (String.length s)\n' > q.ml
$ ocamlfind ocamlopt q.ml -o q && ./q          # 4.14.2
5
$ opam exec --switch=5.5.1 -- ocamlfind ocamlopt q.ml -o q
File "q.ml", line 1, characters 12-15:
Error: Invalid encoding of identifier �.
```
