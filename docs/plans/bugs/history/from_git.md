# Bug fixes in ix's git history, as targets for new static analyses

Source: `git log` of /home/pad/github/ix (1,710 commits). 807 commits match
fix|bug|crash|wrong|overflow|Not_found|exception|leak|... in their messages,
and 210 touch docs/plans/bugs/*.md. I read the full messages of about 110
of them and the code diffs of about 25 small ones (marked "diff seen").
Only bugs in ix's own code are listed. Upstream bugs (goken, ocaml-light,
QEMU) and test-only flakiness are left out, unless ix's code had to change.

Legend for "SA" (could a static analysis catch it):
- AST: a syntactic or typed-tree pattern, one function at a time
- DF: intraprocedural dataflow
- IP: interprocedural, points-to, or call graph
- EXN: exception flow (mini-analyze -exn's family)
- NUM: numeric ranges, integer widths, or signs
- TY: types or annotations
- DYN: dynamic only (test, fuzzing, or emulator)

## 1. The bugs (73)

| # | commit | lang | file(s) | root cause (pattern) | fix | SA: kind + rule idea |
|---|---|---|---|---|---|---|
| 1 | 89e79b5e (diff seen) | ML | utilities/text/awk/Run.ml | END's handler catches Exit_program but not Next_file, so `END { nextfile }` dies of an uncaught exception | Next_file added to the handler | EXN, **already found by -exn's sweep**: an exception raised in a callee and not caught by any handler on the path to main |
| 2 | c5086383 (diff seen) | ML | shell/Process.ml | `try f () with _ -> 1` in a forked child: every exception (Sys_error...) is swallowed, and the child exits 1 silently | print `rc: <exn>`, then 1 | AST: a catch-all `with _ ->` handler that neither uses nor logs the exception, nor re-raises it ("silent catch-all") |
| 3 | 4f00134c (diff seen) | ML | lib_core/system/plan9/Unix.ml (execve) | `try put ... with Unix_error _ -> ()` while writing /env: a too-large variable is dropped, so the child runs with $LOCAL empty | report the error; kernel limit raised to 1 MB | AST: an error swallowed into `()` on a write or side-effect path; DF: a "partial success" result that is never checked |
| 4 | 7f7ce094 | ML | kernels/9pi sysrfork; shell/Eval.ml | the fork's Unix_error ("no free processes") is raised in rc's child and swallowed by #2's `with _`; a backquote's list cut short | the kernel waits for a slot; rc turns Unix_error into its Error | EXN: Unix_error from Unix.fork escapes or gets swallowed; rule: a call that may raise Unix_error inside a catch-all |
| 5 | 2ec2c2a1 | ML | 21 mains (playground programs, mini-lynx...) | `Failure "usage: ..."` raised at -help or at an unknown option, uncaught: "Fatal error: exception Failure" | Arg_.parse_argv, mains wrapped in Exit.catch | EXN: Failure escaping main; rule: an uncaught exception from an argument parser |
| 6 | 3471d975 | ML | tiny/TinyKernel graphics, TinyCalls | `Graphics "no memory for an image"` uncaught ends tiny-www; the region given to images was also too small | the exception turned into a -1 write; region sized right | EXN plus a constant-region error (DYN) |
| 7 | 92fd9e7e | C | languages/ml/runtime | an out-of-bounds index was a fatal error in the runtime, not Invalid_argument, so tiny-cpu's handler never ran | raise Invalid_argument, as OCaml does | TY/EXN: a runtime contract mismatch; check that primitives raise what the stdlib's .mli says |
| 8 | 92fd9e7e | ML | linker (arm64 encoder) | EORW/ANDW/ORRW with an all-ones 32-bit mask: no bitmask-immediate encoding exists, so an undefined instruction is emitted | use the register forms | NUM: an encoder's domain check (immediate encodable?) not enforced on every path; a rule over constant ranges at encoder calls |
| 9 | 3ef40c2a | ML | windows/ (mini-rio) | `Invalid_argument "index out of bounds"` kills a thread (not found; traces added) | backtrace support | NUM/EXN: array indexing without a bounds proof inside a thread loop; DYN in practice |
| 10 | d47f0829 (diff seen) | ML | games/shmup/TinyMissileCommand.ml | an LCG masked to 0x7fffffff keeps the sign bit on 31-bit ints, so `s / 65536 mod n` is negative and List.nth raises | `(s lsr 16) mod n` | NUM: `x mod n` with a possibly negative x flowing to List.nth or an array index; a 31-bit sign-range analysis |
| 11 | e92ae1ec | ML | lib_crypto/Sha1.ml | 32-bit words in native int masked by 0xffffffff; constants above 2^30 do not fit a 31-bit int, so every hash was wrong on arm | words in Int32 | NUM: int literal or `land 0xffffffff` beyond the target's max_int (31-bit); rule: literals > 2^30-1 or masks of 32 bits in code built for arm |
| 12 | 6a649689 | ML | languages/ml (Fold) | the constant folder wrapped computed values to the target's width but not literals (`let mask = 0xffffffff`): host and target summaries differ | wrap Econst too | NUM: host-int vs target-int confusion in a cross-compiler; a value of the host's width used as the target's |
| 13 | 7f15c58f (diff seen) | ML | languages/ml/ssa/Emit.ml | `2*n+1 < 256` overflows on 31 bits, so a large constant is taken as an 8-bit immediate (bit 31 lost); 0x80000000 is read with the host's width | compute in Int64, test n < 128 | NUM: an overflowing guard (`2*n+1 < k`); rule: a range test whose arithmetic can wrap at the int width |
| 14 | 7a8c6af7 (diff seen) | ML | lib_compression (Zlib adler32, crc32) | `(b lsl 16) lor a` then Int32.of_int loses the top bit on 31-bit ints | two 16-bit halves | NUM: a `lsl` whose result needs more than 31 bits; rule: (x lsl k) where range(x)+k > 30 |
| 15 | 70b6b2bf | ML | lib_crypto Bignum, Poly1305, Chacha20; lib_networking Clock | limb products overflow 31-bit ints; a date's seconds (1.7e9) past max_int on arm; a module's limb width read before its initializer ran (link order) | 14-bit limbs, int32, float seconds; link order | NUM, plus IP: toplevel-initialization order (a global read by another unit's initializer before its own unit ran) |
| 16 | af9d12fa | ML | lib_core plan9 Unix (LargeFile.lseek) | a 64-bit offset passed as an int: addresses near 0x80000000 are past 31 bits | two boxed int32 words | NUM/TY: Int64 squeezed through int |
| 17 | cc6eb618 | ML/C | kernel/step4 | 0x40000000 is not a 31-bit OCaml int (KERNBASE) | other representation | NUM: literal > max_int on a 31-bit target (as #11) |
| 18 | 9f1766f4 | C | languages/ml/runtime arrays.c, gc.c | Array.make of 8.2M words: the size does not fit a 32-bit header's 22 bits, so the header lies and the GC walk is lost | check n <= Max_wosize, raise Invalid_argument | NUM (C): a size flowing into a bit-field without a range check |
| 19 | 2fe7e116 (diff seen) | ML | languages/ml/simple/Lower.ml | `a && b`, `a \|\| b` lowered as a value-if: b is never a tail call, so String.for_all and is_utf_8 take a frame per character and overflow | tail if when in tail position | AST (on the compiler): a recursive call under && or \|\| in tail position; on programs: recursion depth proportional to input |
| 20 | 2fe7e116 | C/ML | runtime Hashtbl.hash; lib_core Hashtbl | the hash walks depth-first from the last field (similar rows collide: 13,852 in one bucket); the table doubles at each long bucket until past max_array_length | breadth-first hash; resize by count | DYN (perf); AST: a resize policy keyed on bucket length |
| 21 | f46346db | ML | browsers css (Css_syntax.components) | a call per token of a style sheet, non-tail: 62,000 deep, overflowing mini-ml's unchecked value stack and corrupting statics | a loop along a level; GC guard pages | IP: a non-tail self-recursion whose depth follows an input list or stream (rule: recursion on the tail of input data, not in tail position) |
| 22 | f46346db | C | languages/ml/runtime gc.c | nothing checks the value stack's overflow; it writes over stack_now and stack_roots | guard zone checked at collection | DYN (C) |
| 23 | 7ac6027f | ML | browsers/netscape Tab_worker; lib_core Thread | List.map (non-tail) over a page's strings on a 128 KB thread stack | large threads | IP: a non-tail List.map/fold_right over input-sized data in a thread with a small stack |
| 24 | 021c562b (diff seen) | ML | kernels/9pi Devmnt.rpc | a recursive wait called from inside a try handler (`with Not_found -> ... wait`): not a tail call, so each wake grows the 16 KB kernel stack | List.assoc_opt and match | AST: a self-call inside a `with` handler (or under a try) of a loop-like recursive function |
| 25 | 021c562b (diff seen) | ML | kernels/9pi/memory/Fault.ml | `Hashtbl.create 1024` keyed by page addresses (multiples of 4096): all in bucket 0; Hashtbl.remove recurses per binding, overflowing the kernel stack | 1021 buckets | AST/NUM: a Hashtbl with int keys of a fixed stride (aligned addresses) and a power-of-two size; plus the library's non-tail bucket walk |
| 26 | 5dc5fceb | ML | kernels/9pi Fault (Hashtbl.replace) | ocaml-light's Hashtbl.replace recursed per binding of a bucket: past the kernel stack | remove then add | IP: non-tail recursion reached from kernel code (a stack budget of 16 KB) |
| 27 | e53cac71 | ML | languages/dotnet | the interpreter's frame limit of 10,000 below what List.map of 10,000 needs | 30,000 | DYN (a limit) |
| 28 | 410d04a2 | ML | tiny ld | tiny-kernel's ld ran out of its value stack linking kernel.img | MEM_ld 48 to 64 | DYN |
| 29 | d22c56e4 (diff seen) | ML | languages/ml Unbox | Hashtbl.iter's order (that of the stdlib that built mini-ml) decided the slots of a block's boxes: the self-built compiler emits other bytes | sort before iterating | DF/IP: Hashtbl iteration order flowing into output bytes (rule: Hashtbl.iter or fold results reaching a writer without a sort) |
| 30 | 410d04a2 | ML | languages/ml Typing, Summary | Hashtbl.fold's order; Marshal's sharing differs between compilers: summaries not the same bytes | sort; Marshal No_sharing | the same DF rule; AST: Marshal.to_string without No_sharing for artefacts that must be reproducible |
| 31 | 56934c32 | ML | languages/c/opti | register assignment followed Hashtbl.fold's order | sorted | the same as #29 |
| 32 | ca664887 | ML | assembler Asm.save, linker Link.member_of | objects marshalled with sharing: the same code gives other bytes by mini-ml and by OCaml | No_sharing | the same as #30 |
| 33 | a2da2e93 | ML | tiny Marshal, TinyML interfaces | the same sharing problem; the reader also read out of bounds on No_sharing data | No_sharing honoured | AST plus NUM (bounds) |
| 34 | 423d5e76 | ML | tiny/TinyML.ml | interfaces written in a hash table's order | sorted | DF as #29 |
| 35 | 80c64ade | ML | tiny-ml interface record | OCaml 5's Marshal sets header bits for blocks of 8 fields or more: another .tmi | a record of 6 fields | DYN (compiler-dependent format) |
| 36 | 56934c32 (diff seen) | ML | lib_core List | `f a @ concat_map f l`: OCaml evaluates the right operand first, so f runs on the last element first (mini-ld's frame ref was wrong) | `let r = f a in r @ ...` | AST plus effects: both operands of an application or operator call effectful functions (evaluation-order dependence) |
| 37 | 56934c32 | ML | lib_core Printf | a partial application `Printf.sprintf "R%d"` wrote its text when applied, so it could be used only once | pieces kept until the last argument | DYN; AST: a partially applied printf reused (map) |
| 38 | b9fea684 (diff seen) | ML | lib_mime/Helpers.ml | `if c then (...) else e1; match ...`: the else is e1 alone, and the match runs on both branches (a program started twice) | begin ... end | AST: an else branch followed by `;` whose next expression is indented like the branch's body (indentation vs parse) |
| 39 | 17d84027 (diff seen) | ML | games/fps/quake/Model.ml | `w * (h lsr (2*k))` instead of `(w*h) lsr (2*k)`: the smallest mip is empty and read past | parenthesised | AST/NUM: a shift applied to one factor of a product computing a size; NUM: a 0-size buffer later indexed |
| 40 | 45dff8df | ML | tiny/TinyOffice.mli | `(**bold**` inside a comment opens a nested comment; the .mli does not compile | text reworded | AST/lexer: `(*` inside a comment (a compiler warning) |
| 41 | e7142150 (diff seen) | ML | tiny/TinyML.ml (write_interface) | a name defined twice at toplevel: both written, the earlier kept on read, with the later's type | keep the first entry | AST: duplicate toplevel binding (shadowing) at module level; in the compiler: a Hashtbl.replace that loses a duplicate |
| 42 | 63643fc5 | ML | mini-chidb grammar | a field name (alias) of two records: mini-ml took the other record type, by luck right until a type variable changed | record type annotated | TY: a field label of several records in scope with no annotation (the author's annotate-over-infer rule) |
| 43 | fbfc0317 | ML | games/fps/doom; draw platform | the platform caches a picture by its identity (==); Doom mutates its 2 buffers in place, so frames 1 and 2 are shown forever | a new record each frame | IP/points-to: a value used as a `==` cache key is mutated after insertion |
| 44 | eb5378a5 (diff seen) | ML | editors/turbopascal hosts/draw/Window | `!drawn != Some !model`: a freshly allocated Some is never physically equal, so the test is always true (repaint every tick) | match, then `m != !model` | AST: `==`/`!=` against a freshly built constructor, tuple, or record (always false or true) |
| 45 | 282b689b | ML | editors/emacs Top_window; lib_terminal draw | repaint only when the model `!=` the last one, but the model was mutated in place: nothing painted after the first screen | a new box after each key | IP: as #43, a mutable value compared by identity for change detection |
| 46 | dbee047d | ML | browsers/netscape Tab | a worker's copy of a tab carried its job back; the job was started again (2 or 3 runs of mini-page) | Tab.take_job | DF: a copied record keeps a "to do once" field (linear or ownership) |
| 47 | 283b8c49 | ML/C | runtime compare; lib_core List | `=` used compare's order (nan = nan); List.mem used `==` semantics (ocaml-light's); -. 0.0 lost the sign | IEEE relations; compare a x = 0 | AST: polymorphic `=` on floats where nan is possible; `==` where structural is meant |
| 48 | 62d811be (diff seen) | ML | kernels/9pi/files/Kchan.ml | `match old with Some o when o != c -> close o`: dup(1,1) left a reference count one too many, so a pipe was never closed and the shell hung | close the old chan always | DF: a refcount increment (incref) without a matching decref on one path (paired-operation analysis) |
| 49 | 15f1a021 | ML | tiny/TinyKernel procs | ended processes kept as zombies (slot plus 4 MB) until the parent waited; www never waits for play | records in an `ended` list | IP: a resource released only on a path (wait) that some callers never take |
| 50 | ca664887 | ML | kernels/9pi Kfs cache | cache pieces as strings of the kernel's heap, whose malloc never frees: 15 MB to 96 MB, kernel stuck | pages, given back | DYN (allocator semantics) |
| 51 | 8dd044c3 | C | languages/ml/runtime gc.c (Plan 9) | large blocks taken by sbrk, never given back; a doubling buffer grows memory each time | large blocks back in the halves on Plan 9 | DYN |
| 52 | f7b1aef0 | ML | builder/Recipe | read_file without Fun.protect: a channel leaked on a failed read | Files.read with protect | AST/DF: open_in without close on the exception path (Fun.protect or try/finally) |
| 53 | 35a236d8 | ML | kernels/9pi USB (usb_transfer) | a channel left enabled by a transfer to an unplugged device: no device answers after | disable it | DF: an enable/disable pair not closed on an error path |
| 54 | 1d2e41c8 (diff seen) | ML | shell (mini-rc) | `cflag` set only with -c and exported to children: a child rc runs the parent's -c command again, forking without end (46,880 processes) | cflag always set, empty without -c | DF: a global or exported variable set conditionally and never reset; rule: an "env leaks to child" state |
| 55 | c0d84a2c | ML | linker Link.add_object | an object with no line history takes the previous object's file's lines (state not reset between objects) | lines at 0 | DF: a loop-carried mutable state not reset per iteration |
| 56 | 7e01753b | mk | lib_core mkfile DEPDIRS | search-path order took commons/Source.ml before concurrency/Source.ml | order changed | DYN/build: a duplicate module name on the include path (a static check over -I's) |
| 57 | c06130a9 | ML | tiny/TinyKernel scheduler | runnable() stops a waiter and goes on after it; a tracer earlier in the list is passed over and never woken | restart the scan from the start | DYN (scheduler invariant); model checking |
| 58 | 19968c0e | ML | kernel/9pi Sysfile.syspread | #p's directory entries recomputed at each read: a process started between reads shifts them (ps lists twice) | a snapshot per open | DF: a directory stream re-derived per read (consistency) |
| 59 | 33d8ac7f | ML | lib_playground Plan9_loop | keys from /dev/kbd and characters from /dev/cons, read by two processes with no ordering: Enter before the line's end | edit keys from cons only | DYN (race) |
| 60 | 58e6e4bd | ML/C | lib_core/system/Unix.ml; runtime | a signal arriving between two system calls was never handled (handlers ran only after an EINTR) | run handlers after every call | DYN (race) |
| 61 | 4b81bbed | ML | lib_gui (Gui frame) | several updates per view share one frame record: the second update's click closes the menu the first opened | a frame per update | DYN |
| 62 | bd848c61 | ML | lib_core/concurrency/Source.ml | the source process re-reads at once and queues every read: rio draws every past mouse place | wait for the consumer's receive | DYN |
| 63 | 3c2a34e2 | ML | machine/process (mini-5i /proc) | the debugger's open of a FIFO blocks when the target died (no reader): mini-acid hangs | O_NONBLOCK, ENXIO handled | AST: open of a FIFO without O_NONBLOCK in a debugger or IPC path |
| 64 | 71f44c7b (diff seen) | C | kernels/lib_machine/pi1/machine.c | timer compare written as `CLO + us`, matched on equality: if CLO has passed it already, the next match is 71 minutes later | rewrite until ahead or rung | DYN (hardware race); AST: an equality-matched deadline register set from a fresh read |
| 65 | 7bcbc978 | C/asm | kernels/steps | libc's arm64 memmove uses LDP/STP at any address; with the MMU off that is an alignment fault | port's C memmove in the steps | DYN |
| 66 | 1d9dbcf1 | C | kernels/lib_machine pi1 | code pages written then I-cache invalidated by line without a write-buffer drain or BTB flush | full sync as Linux | DYN |
| 67 | 96d93db7 | asm | kernels/lib_machine/pi1/l.s | ix's l.s lacks start.s's data-abort entry for io_probe: a probe's fault halts the kernel | the entry added | AST: two twin files (start.s/l.s) diverging in a handler (a clone-consistency check) |
| 68 | c073a1cf | ML | kernels/9pi Devaudio | the probe assumed a missing device faults; QEMU's Pi 2 has RAM there: DMA loops forever | check a status bit | DYN |
| 69 | a1102550 (diff seen) | ML | kernels/9pi lib_usb/Hid.ml | `sc > 0x47` should be `>= 0x47`: Home (0x47) lost its escape | `>=` | NUM/DYN: off by one in a range test (only a spec could tell) |
| 70 | d7779b39 | ML | browsers/netscape view | `scale z (move scroll)`: the move is not scaled, so the page is scrolled by scroll/z | move by scroll*z | DYN (transform order) |
| 71 | 1666dfff / 80c64ade | ML | games doom View; lib_graphics Affine | libm sin/tan and arm64's fused multiply-add differ by platform: frames differ | fixed-point tables; exact quarter turns | AST: floats in code whose output must be bit-identical (a rule: a*b+c on floats in such code) |
| 72 | 91b1c185 | sh | shell/tests/differential.sh | `dir=$(cd "$(mktemp -d)" && pwd -P)`: a failed mktemp gives `cd ""`, which succeeds, so dir is the cwd, then `rm -rf "$dir"` | check mktemp's result | AST (shellcheck-like): rm -rf of a path from a command substitution not checked |
| 73 | cefb7851 | sh | tests/lite.sh | BSD date has no %N: each job's shell died before writing its status, and a missing status counted as a pass: "0 failures" | a missing status is FAIL | AST: absent result treated as success (fail-open) |

Also seen, and not listed one by one, because of their low static-analysis value:

- Build and portability: 3f1ae0f3 (od's spacing on macOS made a 146 KB
  invalid escape string), 4ec49c49 (bash 3.2, make 3.81, a filesystem
  blind to case), ad781950 (dash's printf and `\x27`), 14568e53 (no
  dirname on Plan 9), e79f1cb3, 7885c843 and 52cff8b5 (a .depend missing
  edges).
- A function missing from one platform's lib_core, found at link time:
  c5a9003e, 49aa3f10 and b3658d5b.
- Performance bugs (quadratic):
  - aab2542e: polymorphic `=` on `Some (image, row)` walks a whole image's
    tables.
  - 15b1741d and 7050542d: List.assoc in a loop.
  - 7140a998: a listing built by `acc ^ entry`.
  - a845f02f: a listing rebuilt at each read.
  - 1996be61: a blocking read stops every cooperative thread, and a
    constant 30 s timeout.
- 20ee0370: exec arguments past 15 dropped silently by mlsys.c, and a name
  in a directory longer than 20 bytes raised Invalid_argument in a kernel
  call. This is the same "silent truncation" class as #3.
- 0793775f: -v set the log level, but no Logs reporter was installed, so
  every line went nowhere. A static rule: Logs used and Logs.set_reporter
  reachable from main.

## 2. Recurring classes, ordered by count

| class | count | example commits | best analysis |
|---|---|---|---|
| A. Integer width: host 63 bits vs target 31 bits, overflow, sign | 11 | e92ae1ec, 6a649689, 7f15c58f, 7a8c6af7, 70b6b2bf, d47f0829, af9d12fa, cc6eb618, 9f1766f4, 92fd9e7e (EORW), 17d84027 | NUM: literal or mask > 2^30-1; `lsl` with a result past 30 bits; `mod` with a negative operand reaching an index; range guards that can wrap |
| B. Stack depth: non-tail recursion, recursion in a handler, small stacks | 10 | 2fe7e116, f46346db, 7ac6027f, 021c562b (Devmnt), 021c562b (Hashtbl), 5dc5fceb, e53cac71, 410d04a2, 22 (gc guard), 423d5e76 | IP: non-tail self-recursion over input-sized data; a self-call inside a `with` handler; non-tail List.map, fold_right or @ reached from kernel code or a small-stack thread |
| C. Exceptions uncaught, or swallowed by catch-all / `-> ()` | 9 | 89e79b5e, c5086383, 4f00134c, 7f7ce094, 2ec2c2a1, 3471d975, 92fd9e7e (runtime), 3ef40c2a, 20ee0370 | EXN (exists) plus AST: `with _ -> const` and `with E _ -> ()` without a log; Unix_error from fork, execve or open in a child |
| D. Concurrency, races, scheduling, cooperative threads | 9 | c06130a9, 19968c0e, 33d8ac7f, 58e6e4bd, 4b81bbed, bd848c61, 1996be61, 05a5042d, b6cb5f9d | mostly DYN; AST: a blocking read under cooperative threads |
| E. Non-reproducible output: Hashtbl order, Marshal sharing | 7 | d22c56e4, 410d04a2, 56934c32 (opti), ca664887, a2da2e93, 423d5e76, 80c64ade | DF/IP taint: Hashtbl.iter/fold, or Marshal without No_sharing, reaching bytes written to a file without a sort |
| F. Low-level C, asm, hardware | 8 | 71f44c7b, 7bcbc978, 1d9dbcf1, 96d93db7, c073a1cf, cc6eb618 (TTBCR order), 7dd029cc, 8dd044c3 | DYN; clone-consistency between start.s and l.s |
| G. Resource and refcount leaks, unpaired operations | 6 | 62d811be, 15f1a021, ca664887 (Kfs), f7b1aef0, 35a236d8, a847f22b | DF: paired-operation checks (incref/decref, open/close, enable/disable) on every path, the exception path included |
| H. Identity (==/!=) vs mutation in place; shared copies | 6 | eb5378a5, fbfc0317, 282b689b, dbee047d, 283b8c49, aab2542e (= where identity was meant) | AST: `==`/`!=` against a fresh allocation; points-to: a value used as an identity cache key or change detector is mutated in place |
| I. Stale or global state not reset, env inheritance | 4 | 1d2e41c8, c0d84a2c, 7e01753b, 0793775f | DF: a loop-carried ref written on some iterations only; an exported variable set conditionally |
| J. Syntax and precedence traps | 4 | b9fea684, 17d84027, 45dff8df, 56934c32 (`@` order) | AST: an else followed by `;` (indentation), a shift on a product's factor, `(*` in a comment, effectful operands of the same operator |
| K. Arithmetic or logic slips (off by one, transform order, floats) | 5 | a1102550, d7779b39, 1666dfff, 80c64ade (FMA), 283b8c49 (-0.0) | mostly DYN; AST for floats in bit-exact code |
| L. Shadowing and ambiguous names | 2 | e7142150, 63643fc5 | AST: duplicate toplevel binding; TY: a field label in several record types without annotation |
| M. Shell-script fail-open | 3 (+7 portability) | 91b1c185, cefb7851, 3f1ae0f3 | shellcheck-like: unchecked `$(...)` given to rm -rf or cd; a missing status counted as a pass |
| N. Quadratic performance | 6 | aab2542e, 15b1741d, 7050542d, 7140a998, a845f02f, 2fe7e116 (Hashtbl) | AST/IP: List.assoc, `@` or `^` accumulation inside a loop over the same data; polymorphic `=` on large records |

Some bugs count in two classes (2fe7e116, 56934c32, 92fd9e7e, ca664887).

## 3. The 15 most relevant for static analysis

1. **89e79b5e**: mini-awk's Next_file uncaught in END. EXN. Already found
   by mini-analyze -exn. It is the proof that the approach works.
2. **c5086383**: `try f () with _ -> 1` in rc's forked child.
   - AST rule: a catch-all handler whose body neither names the exception
     nor re-raises it, nor prints or logs it.
   - Cheap, and it would also have explained #4 (7f7ce094) earlier.
3. **4f00134c**: `with Unix_error _ -> ()` around the write of an
   environment variable.
   - AST rule: a handler that returns unit, on a call that performs an
     effect (put, write, Unix.*).
   - "Error swallowed on an effect path."
4. **2fe7e116**: `&&` and `||` not lowered as tail calls, so String.for_all
   and is_utf_8 overflow the stack.
   - IP rule: recursion through `&&` or `||` whose depth follows input
     length.
   - Also a self-check of mini-ml's Lower: every call in OCaml-tail position
     must be emitted as a tail call.
5. **f46346db**: Css_syntax.components, a non-tail call per token, 62,000
   deep.
   - IP rule: a self-recursive function, recursing on the rest of an input
     list or stream, with the call not in tail position.
   - Report it with its estimated depth driver.
6. **021c562b** (Devmnt.rpc): a recursive wait called from inside a `with`
   handler, so the kernel stack grows by 48 bytes per wake.
   - AST rule: a recursive call inside a try body or handler. It is never
     a tail call, and under mini-ml a try is a function.
   - The memory "kernel stack and recursion" already names this.
7. **021c562b / 5dc5fceb**: Hashtbl.remove and replace recursing per
   binding on the kernel stack, and power-of-two tables keyed by page
   addresses.
   - IP: library functions with non-tail recursion reachable from
     kernels/.
   - NUM/AST: Hashtbl.create 2^k with keys that are multiples of 4096.
8. **e92ae1ec / 6a649689 / 7a8c6af7 / cc6eb618**: int literals and masks
   of 32 bits (0xffffffff, 0x80000000, `lsl 16 lor`) in code built for
   31-bit arm.
   - NUM rule: a literal > 2^30-1, or a shift whose range exceeds 30 bits,
     in a unit compiled for O=5.
   - This is the largest class.
9. **d47f0829**: an LCG value masked with the sign bit kept, then `mod n`,
   then List.nth with a negative index.
   - NUM rule: a sign analysis on `mod` results flowing to List.nth,
     Array.get or String.get.
10. **7f15c58f**: `2*n+1 < 256`, a range guard that wraps on 31 bits, so
    an immediate gets the wrong value.
    - NUM rule: a comparison guard containing a multiplication or addition
      that may overflow the int width.
11. **d22c56e4** (with 410d04a2, 56934c32, 423d5e76): Hashtbl.iter or fold
    order deciding emitted bytes.
    - IP taint rule: data from Hashtbl.iter or fold reaching an
      output_string, a Buffer or Marshal sink without List.sort.
    - It matters for ix's fixed points.
12. **ca664887 / 410d04a2**: Marshal without No_sharing for objects and
    summaries that must be byte-identical.
    - AST rule: Marshal.to_* or output_value without the No_sharing flag in
      the toolchain's writers.
13. **56934c32**: `f a @ concat_map f l` evaluates its right side first, so
    the effects run in reverse order (mini-ld took the wrong frame).
    - AST plus an effect analysis: an operator or constructor application
      with two or more operands that call effectful functions.
14. **eb5378a5** (and fbfc0317, 282b689b): `!drawn != Some !model`, always
    true. Pictures and models mutated in place while a cache compares them
    by identity.
    - AST rule: `==`/`!=` against a freshly allocated value.
    - Points-to rule: a value stored as an identity key, then mutated in
      place (Bytes.set or a mutable field) through an alias.
15. **62d811be**: dup's refcount, `Some o when o != c -> close o`, leaves
    one reference too many, so a pipe is never closed and the shell hangs.
    - DF paired-operation rule: each incref must meet a decref or a store
      on every path.
    - Related, with the same shape: 15f1a021 (zombie slots), f7b1aef0
      (a channel without Fun.protect) and 35a236d8 (a USB channel left
      enabled).

Runners-up, all cheap AST rules:
- b9fea684: an else followed by `;`.
- e7142150: a duplicate toplevel definition.
- 63643fc5: an ambiguous record field label with no annotation.
- 1d2e41c8: a conditionally set global.
- 91b1c185: shellcheck on test scripts.
