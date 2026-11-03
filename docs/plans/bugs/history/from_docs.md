# Past bugs in ix's own code, as targets for new analyses

Source: docs/plans/bugs/ix.md (all sections), ocaml_light.md, ocaml.md,
mini_chrome.md, chidb.md (read 2026-11-03). Only bugs in ix's own source
(OCaml programs/libraries incl. lib_core, mini-ml/mini-cc/mini-ld/mini-asm
compilers, tiny/, C runtime, kernels' C and assembly) are catalogued in full.
Usage/help-text mismatches, external tools (goken, OCaml, ocaml-light's
compiler, chidb) and build/test-script problems are listed briefly at the end.

Kinds of analysis: SYN = syntactic / semgrep-like on the AST; INTRA =
intraprocedural dataflow; INTER = interprocedural / points-to / call graph;
EXN = exception flow; TYPE = type-based; NUM = numeric range / constant
analysis (incl. target int width); RES = resource/refcount typestate;
CONC = concurrency; DYN = needs dynamic testing / a hardware model.

Class tags (used in the grouping at the end): INTW int width, STACK deep
recursion, HORD hash/iteration order nondeterminism, PERF quadratic/
algorithmic, EXN escaping exception, SWALLOW error silently dropped,
LIMIT fixed-size limit unchecked, CONC race, RES resource/refcount,
SEQ if/else-;-sequencing syntax, PHYS physical equality misuse,
INIT init/link order or stale state, EVAL evaluation order, LINK module
name clash / impl-vs-interface, HW hardware/emulator divergence, SEM
semantic divergence from the reference implementation (compiler/stdlib),
ENC encoder/codegen dropped or misplaced information, LOGIC plain logic
(geometry, off-by-one, tables), BLOCK blocking I/O without timeout.

## A. ix.md, "-h helps" (2026-09-28) and "to decide" tables

| id | lang | where | root cause (pattern) | found / fixed | static? | class |
|---|---|---|---|---|---|---|
| A1 mini-5i ELF taken as a.out | ML | machine/CLI.ml | parser fallback: Elf.parse rejects, then Plan9.parse accepts anything (no magic check) | running -h examples; open | SYN/INTRA weak: "a format parser's fallback branch has no validation"; mostly DYN | LOGIC |
| A2 mini-git relative clone path | ML | version_control | relative path passed where an absolute was assumed | -h examples; open | NO (DYN) | LOGIC |
| A3 mini-ld undefined at line 0 | ML | linker | reference's line not kept to the link: information dropped across a record | -h examples; open | INTER: a field set to a constant 0 at every construction site (-dead "field always constant") | ENC |
| A4 JS async deep recursion SIGBUS on macOS | ML | browsers/javascript eval/Js_coroutine.ml | recursion depth limit (max_depth 2000) sized for 8 MB main stack, run on a thread with 512 KB | -h examples; open | INTER+STACK: recursion reachable from a Thread.create'd function with depth bound vs thread stack size; hard | STACK |
| A5 mini-asm accepts unknown opcode / missing operand | ML | assembler | validation deferred to linker | -h; decision | n/a design | - |
| A6 mini-rc -z silently a flag var | ML | shell | unknown flag not rejected | -h; decision | n/a | - |

## B. ix.md, "manual pages" (2026-10-14)

| id | lang | where | root cause | found / fixed | static? | class |
|---|---|---|---|---|---|---|
| B1 Session.parse: Arg.Help/Bad made failwith | ML | lib_playground Session | exception converted to Failure, escaping to toplevel as "Fatal error" | writing man pages; fixed (Arg_.parse_argv, Exit.catch) | EXN: Failure reaches main uncaught (existing -exn) | EXN |
| B2 mini-node import run as script | ML | browsers/javascript | missing case: file with import not routed to module loader | man; fixed | NO | LOGIC |
| B3 mini-lynx file:// to network | ML | browsers/lynx | missing case on URL scheme | man; fixed | SYN weak: match on scheme string lacking "file" | LOGIC |
| B4 mini-touch -t 0 is now | ML | utilities | Unix.utimes 0.0 means now (API corner) | man; not fixed | SYN: Unix.utimes with literal 0.0 | SEM |
| B5 mini-cmp octal offsets | ML | utilities | int_of_string "010" decimal vs C's octal | man; not fixed | SYN: int_of_string on user number where C used strtol(…,0) | SEM |
| B6 mini-seq -f, mini-du, mini-awk -mf | ML | utilities | usage lists unimplemented options | man; not fixed | usage text (skip) | - |

## C. ix.md, "mini-ml (2026-10-01)" big table, rows in order

| id | lang | where | root cause (pattern) | found / fixed | static? kind, rule | class |
|---|---|---|---|---|---|---|
| C1 .mli val not defined in .ml | ML compiler | mini-ml | no check of a unit against its interface's values | tests/modern; not fixed then | TYPE: impl-vs-mli conformance (also D3 Tcp.timeout) | LINK |
| C2 Sys_error message lacks strerror | C runtime | languages/ml/runtime | runtime doesn't ask errno text | tests/modern | NO | SEM |
| C3 && / || right operand not tail | ML compiler | languages/ml/simple/Lower.ml `app` | %sequand/%sequor lowered as value `if`, never in tail position: `let rec go i = ... \|\| (... && go (i+1))` overflows | tests/modern + tiny-assembler `.space 262144`; fixed 2026-10-21 (C109) | SYN on user code: recursive call as right operand of &&/\|\| in a `let rec` (flag where compiler isn't OCaml); compiler-side: DYN | STACK |
| C4 stdout lost at fatal error | C runtime | runtime | buffer not flushed at abnormal exit | tests/modern; contract | INTER: output channels written but no at_exit flush on fatal path | SWALLOW |
| C5 a.(i) <- v evaluation order | ML compiler/tests | mini-ml, tiny-ml | evaluation order of array assignment operands differs between compilers | tests/tiny; .out regenerated 2026-10-03 | SYN: side-effecting subexpressions in two operands of one assignment/application | EVAL |
| C6 tests' .out recorded on 64 bits | test data | tests/tiny | int width in expected output | arm run | NUM (as INTW) | INTW |
| C7 flaky echo test | asm/harness | tiny-pi | unknown race, interrupts | make test; closed (removed) | DYN | CONC |
| C8 conditional branch too far after Follow | ML | mini-ld Follow | layout moves branch target beyond 1 MB reach; no veneer inserted | mkfiles; worked around -nofollow | NUM: branch displacement range check after relayout | ENC |
| C9 signal handlers never run | C runtime + lib_core | runtime | Sys.set_signal handler not installed; fixed by noting signal and running at syscall | mini-rc fn sigint; fixed 2026-10-02 | NO | SEM |
| C10 floats on arm FPA vs VFP | ML | mini-ld | wrong float instruction set chosen | tests/modern; fixed 2026-10-02 | NO | ENC |
| C11 ssa/Alloc slots via Hashtbl.iter | ML | mini-ml ssa/Alloc | register/slot numbering from Hashtbl.iter order: output depends on stdlib hash | built by mini-ml vs OCaml; fixed (values' order) | INTER/SYN: Hashtbl.iter/fold whose effects reach emitted output without a sort | HORD |
| C12 deep non-tail recursion 32 B/frame | ML compiler | mini-ml, List.map/@ | List.map, @, concat_map on long lists; mini-ml frames twice ocamlopt's | mini-ld linking mini-cc; rewrites (Link.load @) | INTER: non-tail recursion over a list whose length is input-proportional (List.map/@ on token/line/instruction lists) | STACK |
| C13 String.escaped differs | ML lib_core | lib_core | stdlib copy from ocaml-light, semantics differ | mini-lex output by builder; fixed | NO (differential) | SEM |
| C14 mini-ld slow (18 s) | ML | mini-ld | perf, unexplored (later C-D: List.assoc quadratic) | - | see D18 | PERF |
| C15 nan =, < by compare order | C runtime | runtime | float equality via generic compare | floats.ml; fixed | NO | SEM |
| C16 -. 0.0, abs_float sign | C runtime | runtime | sign of zero / nan bits | floats.ml | NO | SEM |
| C17 ceil/floor zero sign | C runtime | runtime | goken libc | floats.ml | NO | SEM |
| C18 %ld typed as int; %Ld refused; %S bad format | ML compiler | mini-ml Typing.format | format-string parser missing cases | formats.ml | NO | SEM |
| C19 sys_open flags ignored | C runtime | runtime | open flags parameter ignored: every file opened to write | files.ml | INTRA (C): a parameter never read in a function (unused param in syscall wrapper) | ENC |
| C20 unlabeled call to labeled fn | ML compiler | mini-ml typing | missing case: total application without labels | labels.ml | NO | SEM |
| C21 -7L parsed as negation | ML compiler | mini-ml lexer | - | boxed_ints.ml | NO | SEM |
| C22 `let f : t = fun` not generalized | ML compiler | mini-ml typing | value restriction with annotation | formats.ml | NO | SEM |
| C23 let rec f : t = function refused | ML compiler | mini-ml | missing case | constructors.ml | NO | SEM |
| C24 mini-cc -O registers by Hashtbl.fold | ML | mini-cc | register assignment order from Hashtbl.fold: nondeterministic across stdlibs | mini-cc built by mini-ml; sorted | SYN/INTER as C11 | HORD |
| C25 out of memory at 64 MB | C runtime | runtime gc | hard-coded heap limit | check.sh | LIMIT, NO | LIMIT |
| C26 `# 1 "file"` first line refused | ML | mini-ml lexer | rule required preceding newline | census | NO | SEM |
| C27 sqrt last bit / NaN | C runtime | runtime calls software sqrt | libc vs processor result | mini-5i random_blocks; fixed (FSQRTD) | NO | SEM |
| C28 Float.fma zero sign | ML lib_core | lib_core/base/Float | emulated fma loses low part at range end | random_blocks; open | NUM (float) hard | SEM |
| C29 out-of-bounds a fatal error, not exception | C runtime | runtime (ocaml-light's) | bounds check aborts instead of raising | tiny-cpu `match ... with exception _` | NO | SEM |
| C30 Open_append without Open_wronly read-only | C runtime | runtime open flags | flag mapping incomplete: checks Open_wronly only | tiny-vcs store empty; fixed 2026-10-02 | NO (spec) | SEM |
| C31 ~x of uint32 encoded as undefined instr | ML | mini-ld (7l's) | EORW $0xffffffff encoding case missing (32 bits of ones) | Sys.rename SIGILL; fixed in mini-ld (MVNW) | NUM: encoder's immediate classes, logical immediate of all ones | ENC |
| C32 mini-asm under mini-5i ENOENT / OOM | ML/C | machine | 1 GB bss vs 512 MB | open | LIMIT | LIMIT |
| C33 exception name in 4 words | C runtime | runtime predefined exceptions | fixed-size buffer 4 words: 16 chars on 64-bit, 8 on 32: names overran into next | run.sh 5; 8 words | NUM/C: string literal length vs. fixed array of words computed for 64-bit | INTW/LIMIT |
| C34 NULL vs nil macro clash | C | mlvalues.h | #define NULL nil vs gnu.h | GAS=1 build | SYN: conflicting macro defs | - (build) |
| C35 Marshal realloc vs 64 MB malloc abort | C runtime | runtime Marshal | growing buffer by realloc on allocator that never frees; abort silent | fixpoint.sh exit 1 silent; mmap buffers | RES: realloc growth on non-freeing allocator; abort() without message | LIMIT/SWALLOW |
| C36 linker instruction words in 31-bit int | ML | mini-ld (built for arm) | 32-bit instruction words and arm64 addresses in OCaml int: top bit lost on 32-bit host | mini-mk O=5 image diff; int32 words | NUM: values masked/shifted to bit 31 (`lsl 31`, `0x80000000`, `0xd5…`) in int on a 31-bit target | INTW |
| C37 function of 8 params on arm | ML compiler | mini-ml Gen/Lower | arity limit by register count; message and curry functions disagree (nregs vs nregs-1) | several programs; fixed 2026-10-22 | NO for compiler; SYN for user code (>7 params) | ENC |
| C38 signal between two system calls lost | C runtime + lib_core | runtime/stdlib | handler only run on EINTR; signal arriving between calls never observed | GH Actions 2/200; check after every Unix call | CONC: pending-flag checked only on an error path | CONC |
| C39 #p entries shift during multi-read dir | ML kernel | mini-9pi Sysfile.syspread | directory read by offset recomputed at each read; concurrent process creation shifts entries | 1/96 runs; snapshot at first read | CONC: offset-based iteration over a mutable collection recomputed per call | CONC |
| C40 hoc test race | test | session | harness | - | - | (infra) |
| C41 record type chosen by luck | ML (grammar) | database/sql/Parser.mly | `{ $1 with alias = $2 }`: field name shared by two record types, last defined wins | mini-ml stricter after 72379fc | TYPE: record-update with field name ambiguous across types in scope | TYPE/SEM |
| C42 sqrt stub panics | C kernel | kernels/lib_machine/libc.c | stub function (panic) reached by draw device | check-draw; Newton sqrt | INTER: call graph reaches a stub/panic function | SWALLOW |
| C43 Pi4 AArch32 first float undefined | asm kernel | lib_machine/pi4/start.s | FPEXC32_EL2.EN not set | boot on Pi4; fixed | DYN | HW |
| C44 USB channel stays enabled after unplug | C kernel | lib_machine/usb.c usb_transfer | timeout path leaves hardware channel enabled; every later transfer fails | QMP device_del; disable on entry | INTRA: on timeout/error path, state set at start not reset (typestate) | RES/HW |
| C45 Chan defined twice in kernel link | ML | kernels/9pi | two modules of one name linked | mini-mk after 8ac55c2; renamed Kchan | INTER/link: duplicate module names in one link set | LINK |
| C46 check said pass (grep hid diff) | infra | Makefile | - | - | - | (infra) |
| C47 GFX defined twice in Makefile | infra | Makefile | - | - | - | (infra) |
| C48 P9_server kept waiting read after clunk | ML | mini-rio P9_server | pending request not removed when its fid is clunked/flushed: answer given to stale reader | win-new.steps; fixed 2026-10-06 | RES: table entries keyed by fid not removed on close/flush (typestate add-without-remove) | RES |
| C49 Kdos DMDIR at bit 31 | ML kernel | Kdos, Kfs | `1 lsl 31` on 31-bit int; Kfs ignored mode | mkdir on FAT; fixed 2026-10-07 | NUM/SYN: `1 lsl 31` / `land 0x80000000` on int when target int is 31 bits | INTW |
| C50 mini-asm List.map over 278k lines | ML | assembler Lexer_asm.preprocess | List.map over file lines: a frame per line | singularity images.s; rev_map | INTER: List.map on input-sized list | STACK |
| C51 mini-git repack loses annotated tag | ML | version_control Packer | object walk missed a kind (tag objects); loose objects then deleted | git fsck; fixed | NO (missing case in graph walk); SYN weak: match on object kind lacking Tag | LOGIC |
| C52 Docker-only compile_ix failures | test | - | moved paths | - | - | (infra) |
| C53 framebuffer red/blue swapped | ML | raspberry/video/Framebuffer.ml, Sdl_display | pixel format bit layout | QMP dump vs QEMU | DYN | HW |
| C54 int literal too large silently wraps | ML compiler | mini-ml lexer | literal is host int, truncated to target width without error | Lehmer 2^31-1, Tetris died; not fixed (later fixed via Fold D?) | NUM/SYN: int literal ≥ 2^30 in code built for arm | INTW |
| C55 arm int / 0 segfault | C/runtime | mini-ml arm, libc divide | division by zero not checked before libc routine | with C54; not fixed | NUM: divisor possibly 0 | SEM |
| C56 kernel ticks undercounted | ML kernel | Main.devices | counts one tick per poll instead of elapsed time | Tetris slow; timer microseconds | NO | LOGIC |
| C57 FP regs not saved on trap | asm kernel | lib_machine/pi1/start.s save_user | trap frame lacks d0-d7/FPSCR | one pixel diff check-tetris; fixed | DYN | HW |
| C58 Lexing.engine reads past token | ML lib_core | lib_core Lexing | asks for refill at buffer end even in state with no transition | mini-hoc interactive; +5 lines | NO | SEM |
| C59 tanh large = NaN | C runtime | runtime tanh = sinh/cosh | inf/inf | hoc fuzzer | NUM (float) | SEM |
| C60 %.*f typed without int | ML compiler | Typing.format | missing case in format typing | mini-awk Cformat | NO | SEM |
| C61 int_of_string "+5" | C runtime | parse_int | missing case '+' | mini-awk | NO | SEM |
| C62 awk's rc under mini-qemu looks only in /boot | ML kernel? | unknown | unknown timing | open | DYN | CONC |
| C63 Follow puts RET after foreign TEXT | ML | mini-ld Follow (5l xfol) | layout follows a B into another function; RET rewritten by the wrong frame size | marshalled.ml segfault; B to TEXT ends flow | NO (encoder) | ENC |
| C64 Pi1 caches never on | asm/C kernel | pi1/start.s | control register missing cache bits | reading code | DYN | HW |
| C65 memmove backwards when not overlapping | C kernel | lib_machine/libc.c | direction test `dd < ss` without overlap check: always slow backward path | profile; fixed | SYN(C): memmove direction chosen without overlap test (perf) | PERF |
| C66 Plan9_loop sleeps a tick when late | ML | lib_playground Plan9_loop | sleep(1ms) rounds up to 10 ms tick | perf frames.sh | NO | PERF |
| C67 speed.sh frame measure | script | games | measure | - | - | (infra) |
| C68 held key stays down (USB queue) | ML kernel | Usbdwc.epread, Kusb | poll rate lower than device queue drain need | held.py | DYN | HW |
| C69 console echo off after rawon program dies | ML kernel | Devcons | raw mode cleared only on explicit rawoff, not on last close | author; open count | RES: mode toggled by open-ctl not reverted on close (refcount) | RES |
| C70 fps counted only drawn frames | ML | Plan9_loop | metric | - | - | LOGIC |
| C71 SD card not found on real Pi1 | ML kernel | Emmc | no delays, wrong clock | real board | DYN | HW |
| C72 USB not started on real Pi1 | C/ML kernel | usb.c, Usbdwc | controller init missing; split transactions missing; fix put in function not called by mini-9pi | real board | INTER: fix in usb_init which mini-9pi never calls (call graph reachability of an init function) | HW/INIT |
| C73 Emmc waits on a state bit | ML kernel | Emmc.bio | polled status bit (state) instead of interrupt bit (event); faster CPU reads early | real board caches on | DYN | HW |
| C74 I-cache not synced after code write | asm kernel | start.s cache_sync_range | missing write-buffer barrier + full I-cache invalidate | real board | DYN | HW |
| C75 curry8 undefined at link | ML compiler | Gen.func vs Lower.curry_funcs | two limits that must agree (nregs vs nregs-1) | DrScheme; fixed 2026-10-22 | NO | ENC |
| C76 DrScheme Enter before typed text | ML | DrScheme update | order of handling within frame | frame session | NO | EVAL/LOGIC |
| C77 Plan9_loop kbd vs cons unordered | ML | Plan9_loop | two input files read by two processes, no ordering | trace | CONC: two event sources merged without sequence | CONC |
| C78 tiny-kernel image overlaps VSTACK | C | tiny runtime.c VSTACK | fixed address of a stack overlaps loaded image growing past 1 MB; unchecked | boot.img > 1 MB; Makefile refuses | NUM: memory map constants vs. sizes; LIMIT | LIMIT |
| C79 float_of_string with underscores | C runtime | floats.c | strtod stops at '_' | fixpoint (TinyMachine 8_000_000.) | NO | SEM |
| C80 Gui frame opened by first update only | ML | lib_playground/apis Gui | per-frame state assumed one update per view | menu closes; frame per update | NO | INIT/LOGIC |
| C81 Ctrl-F9 = carriage return | ML kernel | Kbd.kbtabctrl | table entries for F keys copied | turbopascal | NO | LOGIC |
| C82 Redraw render_region rounding | ML | Redraw | different float expression association (p+433 vs p+512) gives off-by-one pixels | -dump-frame compare; render | NUM float | LOGIC |
| C83 `!drawn != Some !model` always true | ML | hosts/draw/Window | physical inequality against a freshly allocated `Some`: always true, repaint every tick | author slow; compare model | SYN: `e != Some _` / `e == C (…)` with an allocating constructor on one side | PHYS |
| C84 Filename.basename/dirname trailing slash | ML lib_core | lib_core/system/Filename.ml | ocaml-light semantics | keys.sh | NO | SEM |
| C85 mini-5i lacks statx | ML | machine/ | syscall missing in emulator | keys.sh -5 | NO | SEM |
| C86 Enter with typed chars in one tick lost | ML | Plan9_loop on_keys | merging events per tick loses order | session | NO | CONC/LOGIC |
| C87 thin strokes not drawn | ML | draw platform | polygon thinner than a pixel fills nothing | screens | NO | LOGIC |
| C88 mini-emacs model mutated in place, `!=` never true | ML | Window_draw / Top_window | change detection by physical inequality on a value mutated in place | author; box made anew | INTER/PHYS: `m != !model` where m is a mutable record updated in place (points-to: same object) | PHYS |
| C89 mini-emacs held key slow | ML | Frame | recomputation per key | perf; cache | NO | PERF |
| C90 Zlib.crc32 / Adler on 31-bit ints | ML | lib_compression/Zlib.ml (+Pack, Packer, Delta, Query) | 32-bit polynomial 0xedb88320 and `(b lsl 16) lor a` in int | PNG bad CRC under mini-5i; crc32_halves | NUM/SYN: int literal > 2^30-1, `lsl 16` of a 16-bit value, `land 0xffffffff` | INTW |
| C91 Hashtbl.replace never grows; find by = | ML lib_core | lib_core/collections/Hashtbl.ml | resize left in a TODO comment; equality inconsistent between find (=) and mem (compare) | mini-datalog quadratic; fixed 2026-10-10 | SYN: TODO in comment where code missing (weak); consistency of key comparison across a module's functions | PERF/SEM |
| C92 mini-5i lacks gettimeofday; Unix_error uncaught | ML | machine/ + mini-prolog | missing syscall; Unix_error escapes | prolog | EXN: Unix_error escaping from Unix.gettimeofday to main | EXN |
| C93 kernel panics on out-of-page in fault | ML kernel | kernels/9pi/init/Main.ml fault | handler catches only `eintr`; Error enovmem escapes to `guard` which panics | page shapes.pdf; check-hog | EXN: which exceptions reach `guard` (a panic) from Fault.fault | EXN |
| C94 mini-page memory: kernel 256 MB, space_overhead 700 | ML/config | kernel memory map, Plan9_loop | constants | - | NO | LIMIT |
| C95 Systimer mask under js_of_ocaml | ML | raspberry Systimer.until_next | `land 0xffffffff` no-op with 32-bit ints; `lsr 32` is `lsr 0` | node bench | NUM/SYN: `land 0xffffffff`, `lsr 32`, `lsl 32` on int when some target has 32-bit ints | INTW |
| C96 board time wraps after 35 min (js) | ML | MiniQemuWeb.ml | microsecond counter in 32-bit int | reading | NUM: monotone counter in int with no overflow handling | INTW |
| C97 tsleep wakes every tick; Array.to_list per wakeup | ML kernel | Proc | wrong wait channel; list building per call | profile | NO / PERF | PERF |
| C98 software cursor cost | ML kernel | memdraw | slow path | perf | NO | PERF |
| C99 menu 20M instructions | ML kernel | Memgeneral | slow general loop | perf | NO | PERF |
| C100 check-quick screens stale | test | - | - | - | - | (infra) |
| C101 kernel_heap_top undefined (mini-mk build) | C | lib_machine/pi1/machine.c | symbol defined in a file one build variant doesn't link | mini-mk O=5 | INTER/link: symbol references per build configuration | LINK |
| C102 Boot_bench -move clamped | bench | - | - | - | - | (infra) |
| C103 Memdraw no path for 1-bit mask | ML kernel | Memdraw.faster | missing fast path | perf | NO | PERF |
| C104 mini-qemu pace gave up when behind | ML | raspberry Main.loop | catch-up logic | window_lag.py | NO | LOGIC |
| C105 lib_crypto on arm: 63-bit assumptions | ML | lib_crypto Chacha20, Poly1305, Bignum | limbs/products sized for 63-bit ints | vectors under mini-5i; int32, 14-bit limbs | NUM: products of two values < 2^26 in int (52 bits) on a 31-bit target | INTW |
| C106 Clock.of_local seconds overflow | ML | Clock | `day * seconds_per_day` in int > 2^30 | reading | NUM: range of int multiplication | INTW |
| C107 Bignum.base_bits 0 at Poly1305 init | ML | lib_crypto, mkfiles link order | toplevel value of a module evaluated before the module it reads (link order); loop never ends | vectors hang; order + rule | INTER: toplevel initializer of unit A reads global of unit B linked after A (link-order dependency graph) | INIT |
| C108 Udp.ask without timeout | ML | lib_networking Udp | blocking read with no alarm (seconds param unused) | check-ix-net hang | INTRA: a parameter (`seconds`) never read; blocking read on network fd without timeout | BLOCK |
| C109 mini-xd reads whole file | ML | utilities xd | reads unbounded stream into Buffer before output; Failure escapes | xd /dev/random | EXN (Failure from Buffer.add) + design | EXN/LIMIT |
| C110 Bignum.of_bytes quadratic; all roots parsed | ML | lib_crypto Bignum, Tls_client | fold building bignum by shift+add per byte; eager parsing | callgrind | NO (complexity) | PERF |
| C111 tiny-ml record > 10 fields | ML compiler | tiny-ml | register limit | - | NO | ENC |
| C112 `a ^ b ^ data` copies data per part | ML | TinyKernelNetwork.ml | right-assoc `^` chain with large rightmost operand | perf | SYN: chain `e1 ^ e2 ^ ... ^ big` (n≥3) where last operand is a payload | PERF |
| C113 string byte read is a C call | ML compiler | tiny-ml | - | perf | NO | PERF |
| C114 unsigned division in string_alloc | C | tiny/TinyMLRuntime/core.c | `len / W` with W = sizeof (unsigned) makes division unsigned → software udiv | perf | SYN(C): int / sizeof(...) mixing signed/unsigned | PERF |
| C115 IL acks: rows dropped | ML | TinyKernelNetwork.ml | protocol window accounting | net trace | NO | LOGIC |
| C116 ^C lost: handler writes console queue | ML | TinyMachine.ml signal handler | signal handler mutates a queue the main loop is replacing (read-modify-write race) | linux.py; handler sets a flag | CONC/INTER: data written both inside a Sys.signal handler and in normal code | CONC |
| C117 static heap[65536] in every program | C | tiny/TinyCRuntime/libc.c | large initialized-zero static in data not bss | ls -l; not fixed | SYN(C): large static array in a format with no bss | LIMIT |
| C118 audio write faults (no PWM in QEMU) | C/ML kernel | Devaudio.start | MMIO to absent device | QEMU; io_probe | DYN; rule: every device start probes before write | HW |
| C119 TinyMissileCommand roll negative | ML | games TinyMissileCommand | `land 0x7fffffff` with 31-bit ints keeps sign; `mod n` negative → List.nth Invalid_argument | author on Pi 1; `lsr 16` | NUM: `x mod n` with x possibly negative used as index; `land 0x7fffffff` on 31-bit | INTW |
| C120 EMouseMove vs EMouseMoveBy | ML | Plan9_loop, SDL platform | an event constructor never produced | author | INTER: a variant constructor matched by consumers but never constructed anywhere (-dead on constructors) | LOGIC |
| C121 Audio.play renders each time | ML | lib_playground Audio | recompute; cache by `==` | perf | NO | PERF |
| C122 curry8 again | ML compiler | - | = C37 | - | - | ENC |
| C123 Ctrl-C no note | ML kernel | Devcons.input | missing feature | author | NO | LOGIC |
| C124 interrupt ends `. -i` shell | ML | mini-rc Eval.interrupt | interactive test by flag rather than input source | session | NO | LOGIC |
| C125 line after interrupt not run | ML | mini-rc | stale flag consumed by next command | session | INTRA: flag set asynchronously never reset at the point it should be | INIT |
| C126 USB with newer firmware | C kernel | usb.c | init sequence/timing | real board | DYN | HW |
| C127 Pi2 cores not started: core_go in cache | C kernel | cores_start | write to shared variable not flushed before waking a core with caches off | real board | DYN; rule: writes read by another core with caches off need flush | HW |
| C128 QEMU raspi2b memory under devices | ML kernel | Devaudio.start | probe assumption | QEMU | DYN | HW |
| C129 breakout missing row | ML | draw platform | open | - | DYN | LOGIC |
| C130 Tetris music cost | ML | Synth, Audio | rendering whole voice | perf | NO | PERF |
| C131 rio new window: stale button state | ML | mini-rio Window.pointer | initial state copied from a global last-seen state | script | INTRA: initial value taken from mutable global | INIT |
| C132 / C133 Event.sync waits once | ML lib_core | lib_core Event.sync (ocaml-light's) | `Condition.wait` not in a `while` loop re-checking the predicate; spurious/other wakeups read index -1 → Invalid_argument kills thread | check-tron; while loop | SYN: `Condition.wait` whose enclosing construct is not a `while` loop on the predicate (classic) | CONC |
| C134 Etherusb one frame per tick | ML kernel | Etherusb.poll | poll once | perf | NO | PERF |
| C135 Source producer unbounded | ML lib_core | lib_core/concurrency Source | producer writes each read to a pipe without backpressure | sweep.py; produce on receive | NO | CONC/PERF |
| C136 Pdf_render hershey ASCII only | ML | lib_graphics/pdf | missing cases | troff pdf | NO | LOGIC |
| C137 fuzz x0 = x0 | script | TinyC_fuzz.py | - | - | - | (infra) |
| C138 Css_syntax.components recursion | ML | browsers Css_syntax, rules_of_block | a call per token (62,000 deep); runtime value stack overflow unchecked → GC took int as pointer | YouTube segfault; loops + GUARD | INTER: recursion depth proportional to token count; C runtime: stack bound unchecked | STACK |
| C139 tiny-ml closure > 9 names | ML compiler | TinyML alloc_closure | register limit | step 6 | NO | ENC |
| C140 tiny-db takes short file as new | ML | tiny-db open_db | size test `< 16` instead of `= 0` | port | NO | LOGIC |
| C141 tiny-kernel file rebuilt on each write | ML | TinyKernel.ml data | string concatenation `sub ^ written ^ rest` per write | profile | SYN: `String.sub s 0 k ^ x ^ String.sub s …` in a write path (quadratic) | PERF |
| C142 tiny-build -j waits for pid -1 | ML | tiny-build | failed fork's -1 pid kept as running job; wait never returns it | build -j 3 hangs | INTRA: return value -1 of fork stored into a "running" set without check | SWALLOW |
| C143 tiny-kernel ld out of 32 MB, illegal instr | ML/C | tiny-kernel ld | limit reached silently | self-build | LIMIT | LIMIT |
| C144 make ignores MEM_ variable change | infra | Makefile | - | - | - | (infra) |
| C145 tiny ld value stack too small | ML/C | TinyLinker List.concat, @ | deep list ops | make self | STACK | STACK |
| C146 tiny stack runs into heap unseen | C | tiny core.c | stack bound unchecked; List.map fst over 10,000 tokens | cc on tiny-kernel; ml_vlimit | STACK + C: no bound check | STACK/LIMIT |
| C147 tiny-ml interface order by Hashtbl.iter | ML | tiny-ml | output order from table iteration | host vs kernel diff | HORD | HORD |
| C148 tiny-ml type names unified across units | ML compiler | tiny-ml | unqualified type names (Sha1's t = string) | debugging; open | NO | SEM |
| C149 name > 19 bytes hangs kernel | ML | TinyKernel dir | `String.make (20 - len)` negative → Invalid_argument not caught by kernel (catches only Bad) | ls /sys/src | EXN + NUM: String.make with possibly negative length; exception other than Bad escapes kernel loop | EXN/LIMIT |
| C150 args > 15 silently dropped | C | tiny mlsys.c u_exec | copy into fixed argv[15] truncates silently | step 8 | SYN(C): loop copying into fixed array bounded by `min(n, MAX)` without error | LIMIT/SWALLOW |
| C151 exec args without terminating 0 | C/ML | tiny load_prog | k_blit copy relying on pre-zeroed memory | step 8 | INTRA(C): string copy without terminator write | LIMIT |
| C152 tiny-build stamps saved only at end | ML | tiny-build | persistence only at successful end | killed build | NO | LOGIC |
| C153 tiny-ml interfaces differ: Marshal sharing | ML | tiny-ml | Marshal with sharing of structurally-equal values depends on construction order | step 8; No_sharing | SYN: Marshal.to_* without No_sharing writing files compared across builds | HORD |
| C154 lib_core Marshal No_sharing read | ML lib_core | Marshal.from_string | table sized from header 0 → index out of bounds | m-IX | NO | SEM |
| C155 red frame drawn every frame | ML | Plan9_loop | lateness logic | stats | NO | PERF/LOGIC |
| C156 mini-pi no network | config | mini-pi | - | - | - | (infra) |
| C157 thread value stack 32k words | C runtime + ML | Tab_worker, lib_core threads | thread stacks small and unchecked | HN on mini-9pi | STACK: recursion reachable from thread entry | STACK |
| C158 Tls_client read before write on kept conn | ML | lib_networking Tls_client.send/step | send queues, then step reads first: blocks waiting for server that waits for request | 30 s per request; flush | INTRA: on a request path, a blocking read precedes the write of buffered data | BLOCK |
| C159 Hid scancode `> 0x47` (Home) | ML kernel | Hid scancode (principia's too) | off-by-one boundary (`>` should be `>=`) | netscape keys | NO (off-by-one) | LOGIC |
| C160 zoom + scroll transform order | ML | browsers/netscape view | transform composition order (scale after move) | author | NO | LOGIC |
| C161 tiny-build reads 8 MB file whole to digest | ML | tiny-build | read whole file then concat | self; streaming Sha1 | NO / LIMIT | LIMIT |
| C162 Unix.fork after domain under OCaml 5 | ML | browsers Procs.spawn | fork forbidden after Domain.spawn | helpers.sh on 5.5.1 | INTER: Unix.fork reachable after Domain.spawn | CONC |
| C163 lite.sh B not passed | infra | mkfiles | - | - | - | (infra) |
| C164 plan9 Unix lacks create_process | ML lib_core | lib_core plan9/Unix.ml | one OS variant of a module missing a value the other has | mini-9pi build | TYPE/LINK: same-signature check across OS variants | LINK |
| C165 cursor never set | ML | Playground_platform | stub `()` | author | INTER: stub implementations reached | LOGIC |
| C166 netscape out of memory | ML | - | memory consumption | - | NO | LIMIT |
| C167 Pi2 freeze after quitting game | ? | open | - | - | DYN | HW |
| C168 && \|\| tail (fixed) | ML compiler | Lower.ml | = C3 fixed | - | see C3 | STACK |
| C169 runtime hash depth-first; Hashtbl doubles unboundedly | C runtime + lib_core | runtime hash, Hashtbl.resize | hash walked from last field (similar nodes collide); resize on bucket length doubles past max array | HN comments | NO (quality) / NUM: array size doubling with no cap | PERF/LIMIT |
| C170 progress bar | ML | Tab | pieces | - | NO | LOGIC |
| C171 mini-mk jobs share /env | ML | mini-mk Recipe.spawn | fork without private environment group: concurrent jobs overwrite each other's variables | self build NPROC=4; rfork RFENVG | CONC: process-global state written between fork and exec by parallel jobs | CONC |
| C172 Pi timer compare equality race | C kernel | pi1/machine.c timer_arm | read counter then write compare = now+10ms; compare on equality, lost if passed | build 73 min; loop until ahead | DYN; SYN(C): write of an absolute deadline computed from a read without re-check | HW/CONC |
| C173 Kfs pieces in non-freeing kernel heap | ML kernel | Kfs cache | cache memory from an allocator whose free does nothing | build stuck; Mmu.kalloc | RES: allocation via malloc-backed heap in a long-running cache | RES |
| C174 mkdir -p TOCTOU | ML | utilities mkdir | exists-then-create race; makedir re-checks | parallel build | SYN/INTRA: `if not (exists p) then mkdir p` without handling EEXIST | CONC |
| C175 mini-cc output differs: Asm.save sharing | ML | mini-cc Asm.save, Link.member_of | Marshal with sharing | self build | as C153 | HORD |
| C176 argv address not loaded | ML | netscape | missing case | author | NO | LOGIC |
| C177 grid repeat(auto-fill) | ML | Css_grid | missing case | author | NO | LOGIC |
| C178 tracer never woken | ML | tiny-kernel runnable | scheduler scan passed over a process made ready behind the cursor | trace session | NO | CONC |
| C179 dune package defined twice | infra | - | - | - | - | (infra) |
| C180 cameltry walls: if without begin..end | ML | lib_playground draw platform `rectangle` | `if c then a; else polygon` wrapped in an outer `if` without begin/end: `else` attaches to wrong if | author; begin..end | SYN: nested `if` without begin/end whose inner has `else`, inside a then-branch (dangling else) | SEQ |
| C181 Redraw only_in hash bucket | ML | Redraw | mini-ml's hash limited depth → all in one bucket | perf | NO | PERF |
| C182 Pi 2 clock 600 MHz | config | config.txt | - | - | - | HW |
| C183 two Collide modules (wrapped false) | ML | games doom vs lib_physics | duplicate module name across libraries, linked silently; segfault | frame dump; rename | INTER/link: duplicate unit names across the whole link set | LINK |
| C184 ssa Emit `small` host int vs target | ML compiler | ssa/Emit.ml | constant judged with host int; `2*n+1 < 256` wraps on 31 bits | fixpoint-arm; `tagged`, n<128 | NUM: arithmetic on constants compared with bound, overflow on target width | INTW |
| C185 exec arg > 1 KB refused | ML kernel | Usermem.user_string | each arg bounded by maxpath (1024) | self build; Exec.maxargs | LIMIT: wrong limit reused (path max for args) | LIMIT |
| C186 Pi4 Rng probe | ML/asm kernel | Rng.start | MMIO without probe | QEMU raspi4b | DYN | HW |
| C187 mini-cc drops `(void)*p` load | ML compiler | mini-cc | load whose value unused deleted even if volatile | io_probe | NO | SEM |
| C188 mini-ld -map %08x of 64-bit addr | ML | mini-ld | 64-bit address in 63-bit int | map file | NUM: address constants ≥ 2^62 in int | INTW |
| C189 arm shifts/min_int folded on host | ML compiler | mini-ml constant folding | folding with host's 63-bit ints | run.sh 5; open | NUM | INTW |

## D. ix.md, later sections

| id | lang | where | root cause (pattern) | found / fixed | static? | class |
|---|---|---|---|---|---|---|
| D1 Synth.louder no-op on Samples | ML | lib_playground Audio/Synth | map_voices skips a variant case (Samples returned unchanged) | quake master volume; fixed | SYN/INTER: a transformer function whose match returns the input unchanged for some constructor (identity branch) | LOGIC |
| D2 Array.make past Max_wosize | C runtime | make_vect, create_string | size checked only `n < 0`; header size field 22 bits on 32-bit truncated | doom music; raise + a GC invariant check | NUM(C): size stored into bitfield without range check | LIMIT |
| D3 register-index operand dropped | ML | mini-asm/mini-ld Arm64.aclass | parser reads the index; classifier looks at base and offset only → `ldrb w3,[x1]` | stage 2 attempt; now error | INTER/-dead: a record field written by the parser never read by the encoder (unread field facts exist) | ENC |
| D4 -boxed-floats float_array never ends | ML compiler | mini-ml | open | - | DYN | SEM |
| D5 summaries differ: Hashtbl.fold + Marshal sharing | ML | mini-ml Typing.places, min_max_globals, Summary.to_string | Hashtbl.fold order and Marshal sharing in emitted files | self-quick | as C11/C153 | HORD |
| D6 OCaml 5 Marshal header color | external | OCaml 5 | - | - | - | (external) |
| D7 Affine.rotate fma differences | ML | lib_graphics Affine | cos(pi/2)≠0 and FMA contraction differ by compiler | x86 frames | NUM float: sums of products in geometry compared bitwise | SEM |
| D8 Unbox sinking via Hashtbl.iter | ML compiler | mini-ml (b0d4877c) | Hashtbl.iter order in code emission | fixpoint | HORD | HORD |
| D9 maxenvsize 16 KB, execve drops error | ML kernel | Devenv, execve | env write error ignored; recipe got empty LOCAL | self-mix | SWALLOW: result of a write in a loop ignored | SWALLOW/LIMIT |
| D10 tiny-kernel dir listing rebuilt per read | ML | tiny-kernel | per-entry rebuild of full listing (quadratic) | net test timeout | PERF | PERF |
| D11 fork table full: no wait; rc swallows Unix_error | ML kernel + mini-rc | sysrfork; mini-rc Process.fork `with _ -> 1` | resource exhaustion error instead of waiting; child catch-all hides exception | self-mix | EXN/SWALLOW: `try … with _ ->` returning a status without printing | SWALLOW |
| D12 dup(1,1) leaks a reference | ML kernel | Kchan.fdalloc_at | incref done; close of old chan skipped when `o == c`; pipe never closes | reading code; fixed 2026-10-28 | RES: refcount incremented on all paths, decremented only when `o != c` (path-sensitive refcount balance) | RES |
| D13 tetris.wav sum | test | - | - | - | - | (infra) |
| D14 pprint does not advance offset | ML kernel | Sysproc.pprint | write at chan offset without updating offset; next write overwrites | trace; fixed | INTRA: a write through a shared offset field not followed by an update of that field (compare other writers) | LOGIC |
| D15 rc child `with _ -> 1` silent | ML | mini-rc Process.fork | catch-all handler with no message | reading; fixed | SYN: `with _ -> <constant>` with no logging (existing -exn could list) | SWALLOW |
| D16 tiny-machine-socket listen race | ML | tiny-machine-socket | listener re-bound per connection; connect refused in window | linux.py; one socket for run | CONC: close then re-open listening socket | CONC |
| D17 games mkfile NPROC × 7 out of memory | infra | games/mkfile | - | - | - | (infra) |
| D18 summaries read before written (no .depend) | infra/ML | mkfiles, mini-ml inlining | compile order race: unit compiled before dependency's summary exists → different code | self-mix | INTER on build graph: unit's opens/references vs build edges (tests/depend_edges.sh now) | INIT |
| D19 Sha1 on 31-bit ints; host keeps literal whole | ML | lib_crypto Sha1 + mini-ml -m 5 literals | 0xefcdab89 etc. in int, `land 0xffffffff` | self-mix; Int32 | NUM/SYN: int literal > max_int of 31-bit target | INTW |
| D20 Plan 9 has no dirname | infra | depend.rc | - | - | - | (infra) |
| D21 Fold doesn't wrap literals to target | ML compiler | mini-ml Fold | literal kept as host value; computed values wrapped | self-mix Chacha20.inline | NUM | INTW |
| D22 .depend absolute paths | infra | - | - | - | - | (infra) |
| D23 netscape OOM: LARGE blocks never freed on Plan 9 | C runtime | runtime large blocks (2a011cf9) | blocks from sbrk kept forever on a system that never gives memory back; doubling buffers fragment | self-mix; LARGE off on Plan 9 | RES: allocation from never-freed pool in a growth loop | RES/LIMIT |
| D24 tiny-ml exports first of two definitions | ML compiler | tiny-ml write/read_interface | list newest-first + Hashtbl.replace keeps the last read = earlier def | www session; first entry | SYN on user code: two toplevel `let` of the same name in one unit (shadowing) | LINK |
| D25 literal pool inside CASE table | ML | mini-ld linker/Arm.ml | layout check after every instruction, including inside a jump table | stage 4d | NO (encoder) | ENC |
| D26 Parser_asm List.assoc per branch | ML | mini-asm | List.assoc in a loop over the same list (quadratic) | profile; array | SYN: List.assoc/assoc_opt/mem on a list that grows in the same loop | PERF |
| D27 literal pool List.assoc_opt | ML | mini-ld arm64 | same | profile; Hashtbl | SYN as D26 | PERF |
| D28 openssl s_server never killed | infra | tls.sh | - | - | - | (infra) |
| D29 mini-rc -c exported cflag: fork bomb | ML | mini-rc | a global set only when -c given (never reset), exported to children via environment; child re-runs parent's command | 46,880 processes | INTRA: variable assigned only on one branch of option parsing, read unconditionally later (stale/inherited state) | INIT |
| D30 GAS=1 USED undefined | infra/C | runtime.c | macro from another header | - | SYN(C) | (infra) |
| D31 differential.sh mktemp empty → rm -rf cwd | infra (sh) | shell/tests/differential.sh | unchecked command result | - | shellcheck-like | (infra) |
| D32 tiny summaries race | infra | tiny/mkfile | as D18 | - | - | INIT |
| D33 DEPMORE edges missing | infra | mkfiles | as D18 | - | - | INIT |
| D34 .depend not remade on mkfile change | infra | depend.rc | - | - | - | (infra) |
| D35 goken MKSHELL inherited | infra | tests | - | - | - | (infra) |
| D36 corpus String.create | infra/external | ocaml-light tests | - | - | - | (external) |
| D37 mini-5i read_string across segments | ML | mini-5i Memory | range access assumed within one segment | tar differential | NUM: interval crossing a region boundary not split | LOGIC |
| D38 kernel.mk ld wrapper exec itself | infra | Makefile | - | - | - | (infra) |
| D39 9front memmove LDP unaligned with MMU off | asm (libc) | libc arm64 memmove/memset | unaligned 16-byte loads valid only on normal memory | QEMU -d int | DYN | HW |
| D40 stale objects vs R10 convention | build | _mk, mini-ml/mini-cc conventions | objects not rebuilt when compiler contract changes | Pi1 kernel `k` forever | build hygiene | (infra) |
| D41 history-less object's lines | ML | mini-ld Link.add_object | lines of an object without history attributed to the previous history | walk.sh | NO | ENC |
| D42 mini-5i VMOV S,R missing | ML | mini-5i | missing instruction | acid | NO | SEM |
| D43 acid stops at first error under mini-5i | ? | mini-5i | open | - | DYN | SEM |
| D44 Pi 2 by mini-ml: `k` forever | ? | open | - | - | DYN | HW |
| D45 dirreadall hid unopenable entries | C | lib_core/libc/os/linux/stat.c | entries it could not open silently skipped (error → skip); FIFO open blocks | mini-files move lost a file | SWALLOW: in a loop, an open failure → `continue` without report; open of arbitrary dir entry may block | SWALLOW |
| D46 full disk: file cut short, nothing said | ML kernel/program | Kfs write or caller | short write / error dropped | maps route; not fixed | SWALLOW: write result (count) not compared with requested length | SWALLOW |
| D47 Tcp.timeout const vs mli ref | ML | lib_networking tcp/plan9/Tcp.ml | OS variant implements `timeout` as float constant while .mli says `float ref`; mini-ml build accepted it | maps route; fixed | TYPE: implementation vs interface check per OS variant | LINK |
| D48 Fault.holders keys multiples of 4096 → one bucket → kernel stack overrun | ML kernel | kernels/9pi Fault.holders | Hashtbl.create 1024 with keys aligned to 4096 (identity hash) + recursive remove_bucket on 16 KB kernel stack | win-script.steps; gdb on kfault; 1021 buckets | NUM/SYN: Hashtbl over int keys that are multiples of a power of 2 with power-of-2 bucket count; STACK: recursion per bucket length in kernel | STACK/PERF |
| D49 Devmnt.rpc wait recursion in try handler | ML kernel | kernels/9pi Devmnt.rpc | self call inside `with` handler: not a tail call under mini-ml; 48 B per wakeup on 16 KB stack | desktop under QEMU; gdb | SYN: recursive call in a `try ... with` handler (or body) of a `let rec` (not tail in mini-ml; in body not tail in OCaml either) | STACK |
| D50 mini-analyze facts missed @@, \|>, table[0]() | ML | analyzers Closure_facts, Facts | missing cases for %apply/%revapply and array element call | -dead false positives | NO (analysis self-test) | LOGIC |
| D51 close_in flushes unread input | C runtime | io.c caml_close_channel → flush_chan | input channel's `len` (bytes left to read) written as if output; write fails silently (EBADF) | .NET runtime port; not fixed | INTRA(C): channel-direction typestate; write return value ignored | SWALLOW/RES |
| D52 self-quick-mix stops at languages/dotnet | infra | mkfile | - | - | - | (infra) |
| D53 string_of_float 100. → "100" | ML lib_core | Pervasives.string_of_float | `%.12g` without valid_float_lexem | dotnet test; not fixed | NO | SEM |
| D54 arm64 encoder refuses unscaled offset | ML | mini-ld Arm64.ml | only scaled form for positive offsets | JIT "odd offset: 21" | NO (encoder) | ENC |
| D55 mini-dotnet max_depth 10,000 | ML | mini-dotnet Frame.max_depth | depth limit lower than legitimate use | maps benchmark | LIMIT | LIMIT |
| D56 dotnet array = by reference | ML compiler | mini-ml -dotnet | `=` on arrays lowered to ceq | analyzer's `<> [\|\|]` | NO | SEM |
| D57 dotnet constant constructor allocated anew | ML compiler | mini-ml -dotnet Il_types | `None == None` false; broke Hashtbl.replace using `==` | prolog op table | NO (compiler) | SEM/PHYS |
| D58 div.un/rem.un int64 signed | ML | mini-dotnet Arith | unsigned opcodes mapped to signed for int64 only | C fuzz differential | SYN: match arms for Div_un mapping to signed Int64.div (copy-paste of signed branch) | SEM |
| D59 Helpers.run: `else a; match` | ML | apps files Helpers.run | `if … then (…) else a; match …`: the sequence's second part runs on both branches | author; begin | SYN: `if c then e1 else e2; e3` where e3 is a match/let and indentation shows it inside else | SEQ |
| D60 l.s missing kernel_data probe | asm kernel | lib_machine l.s (ix assembler variant) | two copies of the trap entry (start.s, l.s) diverged | shakedown | SYN: duplicated files that must agree (clone diff) | HW/LINK |
| D61 mini-datalog Datalog.questions List.map | ML | lib_code/datalog | List.map over all lines (382k) | facts load; rev_map | INTER: List.map on input-sized list | STACK |
| D62 oberon/singularity RAM_MB undefined | build | l.s include | - | - | - | (infra) |
| D63 mini-awk nextfile in END escapes | ML | utilities awk Run.run | END handler catches some control exceptions, not Next_file | found by mini-analyze -exn | EXN: (existing) control-flow exceptions escaping | EXN |
| D64 mini-mkfs balloc past image end | ML | Xv6fs.balloc | free-block count and image size disagree; Invalid_argument from String.blit | make card; not fixed | NUM: index into image bounded by a count computed separately (off-by-N); EXN for Invalid_argument | LIMIT/EXN |

## E. ocaml_light.md (ix's copy of its stdlib = lib_core counts as ix code)

| id | lang | where | root cause | static? | class |
|---|---|---|---|---|---|
| E1 -output-obj uses host ld | external | ocaml-light configure | - | - | (external) |
| E2 ARMv7-only flags | external | - | - | - | (external) |
| E3 List.init not tail recursive | ML stdlib (also lib_core) | List.init | non-tail recursion; 64 KB kernel stack | INTER as C12 | STACK |
| E4 int64 type from host | external | configure | host vs target width (same family as INTW) | - | (external; INTW pattern) |
| E5 stack argument frame descriptor off by 4 | external compiler | asmcomp/arm | frame size rounding with unaligned stack offset; fixed f89595a9 | - | (external) |
| E6 nan in structure equal (physical shortcut) | external, lib_core List.mem changed | compare.c | `v1 == v2` shortcut in `=` | - | SEM |
| E7 Bytes.of_string identity (aliasing literals) | ML lib_core | lib_core/base/Bytes | `bytes = string` and of_string returns same block: mutating bytes mutates a literal | INTER/points-to: Bytes.set on a value aliasing a string literal | PHYS/aliasing |
| E7b Float.infinity in comment only | ML lib_core | Float.ml | .mli val without .ml definition | TYPE (= C1) | LINK |
| E7c print_endline does not flush | ML lib_core | Pervasives | output ordering with child processes | INTER: output then fork/exec/Unix.write without flush | SWALLOW/EVAL |
| E7d Digest.file asks channel length | ML lib_core | Digest | in_channel_length on non-regular file | SYN | SEM |
| E7e Fun.protect finally positional; Int64.min wrong | ML lib_core | - | API divergence | NO | SEM |
| E8a List.concat_map / init right-to-left | ML lib_core | List | `f a @ concat_map f l`: evaluation order right-to-left → effects in reverse; mini-ld `rewrite` frame ref wrong | SYN: effectful f under `f x :: g …` / `f x @ g …` (evaluation order unspecified) | EVAL |
| E8b Printf.sprintf partially applied reused | ML lib_core | Printf | buffer captured at partial application, shared across uses (mutable state in closure) | INTER: closure capturing a mutable buffer allocated at partial application and reused | EVAL/PHYS |
| E9 Hashtbl.replace no resize, recursive bucket | ML (ocaml-light + lib_core) | Hashtbl | as C91; kernel stack overflow in Fault (kernel by ocaml-light) | STACK/PERF |

## F. ocaml.md, mini_chrome.md, chidb.md

| id | lang | where | root cause | static? | class |
|---|---|---|---|---|---|
| F1 arm64 derived pointer across allocation | external (OCaml) | ocamlopt CSE | ix workaround: read `Bytes.get b i` once (database/storage/Record.ml). A SYN rule could list ix code reading the same Bytes.get twice around an allocation | SYN (hazard list) | (external) |
| F2 OCaml 5 quoted string with `|\xf4}` | external | OCaml 5 lexer | SYN: non-UTF-8 bytes in quoted strings | (external) |
| F3 Html_tree end_tag stops at td for `</table>` | ML (ix copy) | browsers/html Html_tree.ml | stop-set for ancestor search wrong per tag (spec table) | NO | LOGIC |
| F4 Error objects lack prototype (instanceof) | ML (ix copy) | browsers/javascript Js_builtins | object constructed without prototype link for a kind | NO | LOGIC |
| F5 chidb: uninitialized stmt type; NULL returned then stored and dereferenced; type confusion in reg_compare; ival of text | external (C) | chidb | patterns relevant for ix C: use of uninitialized field, NULL-return deref, union read of wrong member | INTRA(C) | (external) |

## G. Skipped (usage text, external, infra) briefly

- Usage/help/man text only: A5, A6, B6, mini-merge3 argument order (Plan 9's own), mini-qemu -help, mini-asm/ld usages, mini-xargs status, mini-chidb DELETE, mini-dossrv -v, mini-ps on Linux, mini-rc rfork n.
- External: goken (EORW encoding came from 7l but the ix copy is C31), OCaml (F1, F2, D6), ocaml-light compiler/configure (E1, E2, E4, E5), chidb (F5), Ubuntu libgcc Thumb, GCC vectorizing.
- Build/test infrastructure (mkfiles, Makefiles, sh, tests): C34, C40, C46, C47, C52, C67, C100, C102, C137, C144, C156, C163, C179, D13, D17, D20, D22, D28, D30, D31, D34, D35, D36, D38, D40, D52, D62, run.sh S= path, /tmp ocaml-light paths. Recurring infra patterns worth noting: stale objects not rebuilt when the compiler changes (C341/D40, D34), missing build edges for inlining summaries (D18, D32, D33), unchecked command substitution (D31), self-exec wrapper (D38), env var leaking into sub-builds (D35, also D29 in ix code).

## H. Classes (bugs in ix's own code only; a bug may count under two classes)

| # | class | count | members (main) | analysis kind | facts needed |
|---|---|---|---|---|---|
| 1 | SEM: divergence from reference semantics (compiler, runtime, lib_core, emulator) | ~40 | C2, C9, C13, C15-18, C20-23, C26-30, C55, C58-61, C79, C84, C85, C148, C154, C187, D4, D7, D42, D53, D56-58, E6, E7d, E7e, B4, B5 | mostly DYN (differential tests: tests/modern, fuzz); a few SYN (D58 copy-paste branch) | none useful beyond AST; keep differential testing |
| 2 | HW: hardware / emulator divergence (kernel C, asm, drivers) | ~22 | C43, C44, C53, C57, C64, C68, C71-74, C118, C126-128, C172, C182, C186, D39, D44, D60, C167 | DYN (needs a hardware model); one SYN rule: every MMIO start path goes through io_probe; duplicate trap-entry files diverge | C call graph + MMIO base-address constants |
| 3 | INTW: int assumed wider than the target's 31 bits (or js 32) / host-vs-target constants | 19 | C6, C33, C36, C49, C54, C90, C95, C96, C105, C106, C119, C184, C188, C189, D19, D21, E4(ext), C162? no; plus Lehmer (C54), Adler (C90) | NUM + SYN: literals > 2^30-1, `1 lsl 31`, `land 0xffffffff`, `lsr 32`, products of 26-bit values, `mod` of possibly negative | constants per expression with their type (int vs Int32/Int64), shift amounts, and the build's target set (which units are built for O=5); a range domain over int expressions |
| 4 | STACK: unbounded non-tail recursion / unchecked stack bound | 17 | C3/C168, C12, C50, C138, C145, C146, C157, A4, D48, D49, D61, E3, E9, C12's Link.load @, List.map fst (C146), Css (C138), tiny ld (C145) | INTER: recursion whose depth ∝ input (List.map/@/concat on lists built from file lines/tokens), non-tail recursion in a `try` handler, && / \|\| right operand, recursion reachable from kernel code or threads | call graph with "call is in tail position" flag; facts for stdlib non-tail functions (List.map, @, concat, init, Hashtbl.remove_bucket); reachability from kernel entry / Thread.create roots; "list derived from input" taint (read_line, lexer tokens) |
| 5 | PERF: quadratic / algorithmic | 22 | C14, C65, C66, C89, C91, C97-99, C103, C110, C112-114, C121, C130, C134, C141, C155, C169, C181, D10, D26, D27, D48 | SYN for a few (List.assoc in a loop over a growing list, `^` chain with payload last, `String.sub ^ … ^ String.sub` per write, Array.to_list per call, Hashtbl over aligned int keys); rest needs profiling | loop/recursion nesting facts; which list is extended in the same loop it is searched |
| 6 | LOGIC: plain logic (missing cases, tables, geometry, off-by-one) | ~25 | A1, A2, B2, B3, C51, C56, C70, C76, C80, C81, C82, C86, C87, C104, C115, C120, C123, C124, C136, C140, C152, C159, C160, C165, C176, C177, D1, D14, D37, D50, F3, F4 | mostly NO; two good rules: constructor matched by consumers but never constructed (C120: needs constructor-use facts), transform returning input unchanged for some variant (D1) | constructor construction/match-site facts (extend -dead to constructors) |
| 7 | LIMIT: fixed-size limit hit silently or bound unchecked | 18 | C25, C32, C33, C35, C78, C94, C109, C117, C143, C146, C149, C150, C151, C161, C166, C169, C185, D2, D9, D23, D55, D64 | NUM in C (copy into fixed array clamped, size into bitfield), INTRA (unchecked length) | C array sizes and loop bounds; constants of memory maps; "clamp without error" pattern |
| 8 | ENC: encoder/codegen drops or misplaces information | 14 | A3, C8, C10, C19, C31, C37/C75/C122, C63, C111, C139, D3, D25, D41, D54 | INTER/-dead: a field parsed/stored but never read by its consumer (D3 register index, C19 open flags, A3 line); others DYN | existing unread-field facts (-dead) restricted to records flowing parser→encoder; unused parameter facts |
| 9 | EXN: exception escaping to main/kernel guard | 10 | B1, C92, C93, C109, C149, C119 (List.nth), D63, D64, C133 (Invalid_argument kills thread) | EXN (existing -exn) + roots: kernel `guard`, thread entry functions, signal handlers; Invalid_argument from String.make/blit/List.nth with computed arguments | exception-flow facts per function (exists); add roots: Thread.create argument, kernel trap entry; facts for stdlib functions raising Invalid_argument/Failure on argument ranges |
| 10 | CONC: races between threads, processes, signal handlers, events | 13 | C7, C38, C39, C62, C77, C86, C116, C132/133, C135, C162, C171, C174, C178, D16 | SYN (Condition.wait not under while; exists-then-create; Unix.fork after Domain.spawn reachable); INTER (data written both in a Sys.signal handler and in main code) | call graph roots for signal handlers (Sys.set_signal/Sys.signal arguments) and threads; global-variable write facts (exists for -caps? need mutable field/ref writes per function) |
| 11 | HORD: output depends on Hashtbl iteration order or Marshal sharing | 9 | C11, C24, C147, C153, C175, D5 (x2), D8, C242(Asm.save) | INTER taint: values from Hashtbl.iter/fold (or Marshal.to_* without No_sharing) reach a file written by the program without a sort | call graph + dataflow from Hashtbl.iter/fold callback effects (list accumulations) to output sinks (output_string, Marshal.to_channel); sort as sanitizer |
| 12 | SWALLOW: error silently dropped (catch-all, ignored write result, skip-on-error loop) | 11 | C4, C35, C42, C142, C150, D9, D11, D15, D45, D46, D51 | SYN (`with _ -> const` without print; result of write/Unix.write ignored); INTRA in C (return value of write/open unchecked; loop `continue` on error) | handler facts (catch-all, body has no I/O call); call-result-used facts; C front end: ignored return values |
| 13 | RES: resource / refcount / mode not released on some path | 8 | C44, C48, C69, C173, D12, D23, D51, C35 | RES typestate: incref without matching decref on a path (D12 `o == c`), a mode set by open not reset on close (C69), table entry added on request not removed on clunk/flush (C48) | path-sensitive SSA dataflow on fields (cref), pairing facts open/close per object; points-to for which chan |
| 14 | LINK: module name clash, impl vs interface, OS variant mismatch | 8 | C1, C45, C101, C164, C183, D24, D47, E7b | TYPE/whole-program: unit names unique across link set; impl conforms to .mli per OS variant (plan9/ vs linux/); duplicate toplevel names in a unit; symbol defined only in one build variant | unit name + path facts per link set (mkfiles), .mli signatures, per-OS variant mapping |
| 15 | INIT: initialisation / link order / stale state carried over | 8 | C72, C107, C125, C131, D18, D29, D32, D33 | INTER: toplevel initializer of A reads a global of B linked after A; option variable set only on one branch then exported/read; flag not reset before next command | toplevel-initializer facts (which globals a unit's init reads), link order from mkfiles |
| 16 | PHYS: physical equality / aliasing misuse | 5 | C83, C88, D57, E7, E8b | SYN (`!=`/`==` with a freshly allocated constructor operand); INTER/points-to (`!=` between two names that point to the same mutable object always false; Bytes.set on alias of literal) | points-to (exists: andersen.dl) + allocation-site facts for `Some`/constructors; mutation facts for records |
| 17 | SEQ: if/else and `;` / begin-end mis-nesting | 2 | C180, D59 | SYN on AST + source columns: `else e1; e2` where e2 is indented as part of else; nested if without begin/end swallowing an else | AST with source positions (column of each sequence element vs its `else`) |
| 18 | EVAL: evaluation-order dependence | 4 | C5, C76, E8a, E7c | SYN: two effectful subexpressions in one application/constructor/assignment (`f a :: g l`, `a.(i) <- v` with effects) | effect summary per function (does it write a ref/channel) |
| 19 | BLOCK: blocking network read without timeout / read before write | 2 | C108, C158 | INTRA/INTER: Unix.read/recv on socket not dominated by an alarm/select; unused `seconds` parameter | call graph + parameter-use facts |

Counts are approximate (some bugs in two classes; HW and SEM include open/unexplained ones).

## I. The 15 most analysis-relevant bugs (good targets, with a rule)

1. C132/C133 Event.sync (lib_core): `Condition.wait` not inside a `while` re-checking the predicate → index -1, thread killed. SYN rule: every `Condition.wait` must be the body of a `while` loop.
2. C3/C168 + D49 + D48: non-tail recursion that overflows (&& / \|\| right operand; recursive call inside a `try … with` handler in Devmnt.rpc; Hashtbl.remove_bucket on kernel 16 KB stack). SYN+INTER: `let rec f` whose self-call is in a try handler or && right operand; INTER: stdlib non-tail functions reachable from kernel code with large inputs.
3. C12/C50/C138/D61 (List.map over file lines/tokens: mini-asm, Css_syntax, Datalog.questions, tiny cc): INTER taint: List.map/@/concat/non-tail recursion over lists derived from file input.
4. C90/D19/C105 (Zlib CRC, Sha1, Chacha/Poly/Bignum on 31-bit ints): NUM/SYN: int literal > 0x3fffffff or `land 0xffffffff` / `lsl 31` in units built for O=5.
5. C119 TinyMissileCommand `land 0x7fffffff` then `mod n` negative → List.nth Invalid_argument: NUM + EXN: index from `mod` of a possibly negative value.
6. C184/D21/C189 (mini-ml constant folding/immediates by host int): NUM: in the compiler, arithmetic on Const values without wrapping to the target word (same rule as 4 applied to compiler-time arithmetic).
7. D12 dup(1,1): incref then close-old only `if o != c`: RES path-sensitive refcount balance on Kchan's cref.
8. C93 kernel fault handler catches only eintr; Error enovmem reaches `guard` → panic: EXN with kernel `guard` as root.
9. C11/C24/D5/D8/C147 Hashtbl.iter/fold order reaching emitted code/files, and C153/C175 Marshal with sharing: INTER taint from iteration callbacks to output sinks, sort as sanitizer; SYN: Marshal.to_* without No_sharing writing compared files.
10. C83/C88 `!drawn != Some !model` and in-place-mutated model compared by `!=`: SYN (constructor allocation operand of ==/!=) + points-to (both sides same object).
11. D59/C180 Helpers.run `else a; match` and draw platform dangling else: SYN with columns.
12. D3 register index parsed but ignored by Arm64.aclass (also C19 open flags ignored, A3 line 0): -dead's unread-field / unused-parameter facts focused on parser→encoder records.
13. C107 Bignum.base_bits read by Poly1305's toplevel before Bignum initialized (link order): INTER over toplevel initializers vs mkfile link order.
14. C183/C45/D24/D47/C164 duplicate unit names in a link (two Collide), duplicate toplevel names (tiny-ml), impl ≠ .mli per OS variant (Tcp.timeout const vs ref, Unix.create_process missing on plan9): whole-program LINK checks.
15. C116 signal handler mutating the console queue + C38 signals between syscalls + C171 shared /env across forked jobs: CONC: state written in a Sys.signal handler and in main code; fork without environment isolation for parallel jobs.

Runners-up: D11/D15/D45/D46/D51 swallowed errors (`with _ -> 1`, write count ignored, close_in writes on input channel), C108/C158 blocking read without timeout / read before write, C149/D64 Invalid_argument from String.make/blit with computed lengths, D29 mini-rc cflag set on one branch then exported (fork bomb), C141/C112/D26/D27 quadratic patterns.
