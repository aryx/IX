# Is there a better language than ML for ix?

An analysis written while the question was being discussed
(2026-10-07); the author asked to keep it. The question: is there a
better language than OCaml (ocaml-light's subset, what mini-ml
compiles) for ix, and for the author's other educational projects such
as `~/playground/`, where the goals are clean code, small code, and
good performance with one language all the way down, without C
libraries?

The answer is no, stay with ML, but for a different reason than the
first one given. Nothing here was measured: section 5 says what
experiment would replace judgement by numbers.

## 1. The goals, as criteria

1. **Small programs.** Most of ix is symbolic code: assemblers,
   linkers, compilers, interpreters, emulators. Their size depends on
   algebraic data types, pattern matching, closures and a garbage
   collector.
2. **A compiler the project can own.** The language's compiler lives
   in ix and is built by ix (mini-ml; m-ix builds inside m-ix).
3. **Performance without C.** Kernels, pixels and virtual machines
   want fixed-width integers, flat data and predictable loops.
4. **A reference implementation.** ix also builds with stock OCaml
   4.14, which gives a second opinion on every program and a fast
   compiler while mini-ml grows.

## 2. First answer: the full languages

| language | gained | lost |
|---|---|---|
| Oberon-07 | the smallest compiler (about 3,000 lines), the precedent of a whole system in one language | no data types with cases, no pattern matching, no closures, no generics: the symbolic code would likely double or triple |
| Go | fixed-width integers, flat structs, good performance, Plan 9's lineage | no sum types; a compiler and a runtime too big to own (`~/goken` shows the size) |
| Rust, Zig | the best performance, no collector, control of the layout | compilers of hundreds of thousands of lines; Rust's programs are not small |
| Standard ML | a formal definition | nothing that matters here; OCaml's weaknesses kept |
| Scheme | the smallest implementation | static types, which keep a code base of this size refactorable |
| Haskell, Lean 4, Koka | elegance; reference counting in place of a collector (Perceus) is interesting for a kernel | large runtimes and compilers, performance harder to predict |

This table rules most languages out on criterion 2, the compiler's
size.

## 3. The objection: any language can be cut down

The author's objection: the table is not fair. OCaml itself is big; it
was reduced to ocaml-light, then to what mini-ml compiles. A mini-zig
or a mini-rust could be written the same way.

That is right, and it removes the compiler's size as a criterion. The
fair question is then: **what is left of the language in its subset,
and how big are the programs written in that subset?**

| mini-language | what the subset keeps | what it costs |
|---|---|---|
| mini-ml | data types, pattern matching, closures, a collector: nearly all that ix uses | tagged integers, boxed floats, no flat records |
| mini-go | almost all of Go 1.0, which subsets well (self-hosting subsets exist in a few thousand lines) | still no sum types: type switches and `if err != nil` lengthen the symbolic code |
| mini-zig | a cleaner C: tagged unions, slices, optionals, error unions | generics are comptime, so the compiler needs an interpreter; no closures, no nested patterns, memory managed by hand |
| mini-rust | data types, pattern matching, full control of the layout | traits and the borrow checker are the expensive parts, and without traits there are no usable collections |

The languages differ in where their value sits. ML's is in the cheap
part of the language: a few thousand lines of compiler give the data
types, the patterns and the closures. Rust's and Zig's is in the
expensive part: the borrow checker and the traits, comptime.

Rust has one trick worth knowing. A mini-rust could skip the borrow
checker and leave that check to rustc, as ix leaves a second opinion
to OCaml 4.14 (criterion 4); mrustc does this. It would still need
traits and monomorphized generics, and the programs would carry
lifetimes, `Box` and `&mut`: they would not be small.

## 4. What the objection opens

- **mini-go for the systems half.** For kernels, drivers and pixel
  loops, Go gives fixed-width integers and flat structs for nothing,
  and goken is already there as a reference. It loses on the
  compilers, assemblers and virtual machines, which are most of ix.
- **mini-rust without its borrow checker is ML with a layout and
  without a collector.** That is the same language as the one reached
  from the other side, by giving mini-ml unboxed types. The two roads
  meet; ML's starts from where ix is.

So the recommendation stands: keep ML, and fix its weak side in
mini-ml.

**ML's weak side**, as ix has met it:
- tagged integers: 31 bits on arm, where `1073741823 + 1` is 0 and a
  pixel of 32 bits does not fit (plan_system_squeak.md, stage 1);
- boxed floats, which cost in a rasterizer's or a game's loop;
- no flat array of records (pixels, vertices, page tables);
- the polymorphic comparison, slow and easy to call without seeing it.

**The fix** is in the compiler, since ix owns it: untagged 32 and
64-bit integers, flat records and arrays of floats, a few primitives
to read and write bytes. It is the direction OxCaml takes with its
unboxed types.

**Its cost** is criterion 4: an extension of mini-ml's language would
no longer build with OCaml 4.14. The way around is to keep each
extension behind an ordinary interface (`Int32`, a record of floats,
`Bytes`), which stock OCaml compiles boxed and mini-ml compiles flat.

**What is not the language's fault.** mini-ml's code runs the
Smalltalk interpreter ten times slower than ocamlopt's
(plan_system_squeak.md, stage 1). That is the compiler's quality
(inlining, unboxing, the registers), and another language would not
close it.

For `~/playground/` under stock OCaml, the same holds: records of
floats only, `float array` and `Bytes` for the pixels go most of the
way without C stubs
(`~/playground/docs/claude_notes/dev/notes_opti_ocaml.md`).

## 5. The experiment that would settle it

Port two modules to Go and to a subset of Rust, and compare lines and
speed with the OCaml:
- one symbolic: a pass of the assembler;
- one numeric: the software rasterizer's blit (`lib_graphics/`).

The first measures what sum types and patterns are worth, the second
what tagged integers and boxed floats cost.
