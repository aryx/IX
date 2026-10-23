\title{prof}{1}{devtools}

# NAME
prof – where a program's instructions went, function by function

# SYNOPSIS
**prof**
[ **-n** *count* ]
[ **-diff** *base* ]
[ **-a** *name* ]
*profile*
*file.map* ...

# DESCRIPTION
*Prof* reads a *profile*, each instruction's address and how many
times it ran (\man{5i}{1}'s **-prof**, or \man{qemu}{1}'s for a whole
system, there one in 1024), and the link's map of the program (\man{ld}{1}'s
**-map**, which \man{mk}{1}'s mkfiles write beside each program: *doom.map*
for *doom*), and prints the total, then the functions with the most
instructions, each with its share. A count goes to the last function
at or before its address. A name is mini-ml's (*f19_draw_column*: the
19th function of its unit; *<>*, local to its file) or the C's and the
runtime's (*ml_alloc*, *copy<>*).

**-n** *count*
:    The first *count* functions only.

**-diff** *base*
:    The profile *base*, of a shorter run of the same program, taken
     off first: what is left is what the longer run did more (a
     game's frames, its start taken off). Every instruction is
     counted, nothing is sampled, so the difference is exact.

**-a** *name*
:    One function's instructions instead, each with its count,
     disassembled from the program beside the map: what a compiler's
     change is decided on.

# EXAMPLES
Where mini-ml spends its time compiling one of its own units, the
compiler built for arm by ix's tools (\man{ml}{1}, `mini-mk O=5`):

```
cd languages/ml
5i -prof typ.prof ../../_mk/5/languages/ml/mini-ml -m 5 -O3 \
    -I ../../lib_core/core ... -o /tmp/x.5 Typing.ml
prof -n 6 typ.prof ../../_mk/5/languages/ml/mini-ml.map
```

prints

```
2,084,742,179 instructions
         count      %  function
   303,847,042   14.6  copy<>
   222,459,472   10.7  collect<>
   169,892,834    8.1  cmp<>
    73,366,051    3.5  f21_go<>
    70,503,952    3.4  div<>
    54,248,238    2.6  f52_byte<>
```

the collector (*copy*, *collect*) a quarter, polymorphic comparison
8%, arm's division (no instruction for it) 3%. A game's frames alone,
the start taken off:

```
cd games/fps/doom
5i -prof 1.prof doom -dump-frame 1 f.ppm -script up:1-31
5i -prof 31.prof doom -dump-frame 31 f.ppm -script up:1-31
prof -diff 1.prof 31.prof doom.map
prof -diff 1.prof -a draw_column 31.prof doom.map
```

# SEE ALSO
\man{5i}{1}, \man{qemu}{1}, \man{ld}{1}, \man{stats}{1};
docs/plans/plan_profiler.md, plan_mini_toolchain_optimization.md

# DIFFERENCES
Unix's *prof* and Plan 9's sample the program counter at a clock's
tick, or count calls compiled in with **-p**; this one counts every
instruction the emulator ran, and needs nothing of the program.

# BUGS
A total of more than a thousand million instructions on a machine of
31-bit integers (mini-9pi) overflows; **-a** refuses there.
