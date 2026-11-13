(* tiny-prof: shows where a program's instructions went, by function.
 * It reads a profile written by tiny-cpu -prof or tiny-machine -prof,
 * which counts every instruction run by its address, and the maps that
 * tiny-ld wrote for what ran (with -map: the address of each label).
 * It prints the functions that ran most, with their share.
 *
 *     tiny-machine -prof p boot.img          a session, counted
 *     tiny-prof p -k kernel.img.map -u bin/www.map
 *
 *     12,345,678 instructions: the kernel 58.6%, programs 41.4%
 *         count      %     function
 *       989,893   8.0  k  row_copy2
 *       862,816   7.0  u  browse
 *       ...
 *
 * The addresses of the labels come from the link itself (tiny-ld
 * writes the map as it writes the image), so the names cannot disagree
 * with what ran. A count goes to the last label at or before its
 * address. A label that a compiler makes inside a function (tiny-ml's
 * TinyBrowser.L12, tiny-cc's tm.L51) is not a function, so its counts
 * go to the function before it. The labels of a loop in assembly
 * (row_copy2) are kept, because they tell which loop. tiny-ml names its
 * functions like TinyBrowser.f151_browse, which is shown as browse.
 *
 * A profile of tiny-machine separates the kernel's instructions (-k
 * gives the kernel's map) from those of the programs, and tells the
 * programs apart by the base of their window, that is, their
 * partition. -u gives the map of one program: by default the one with
 * the most instructions, unless -base says which. The other programs
 * are counted as "another program".
 *
 * With -diff base, the profile of a shorter run (the same session
 * without what is being measured) is subtracted first. For example, to
 * measure a page down, we take a session with eight page downs minus
 * the same session with none.
 *
 * A worked example: why www scrolled slowly (2026-10-16).
 *
 * The question was where the instructions of a page down go. A recorded
 * session makes it repeatable: www OCaml typed, then, once the page and
 * its pictures are in, eight spaces (eight page downs). A second session
 * is the same with one key that does nothing (x), the baseline: what
 * the first costs more than the second is the eight page downs alone.
 *
 *     printf '20000000 k www OCaml\\n\n600000000 k        \n' > pages.events
 *     printf '20000000 k www OCaml\\n\n600000000 k x\n' > base.events
 *     tiny-machine -prof base.prof -net tiny/tests/www -events base.events \
 *       tiny/TinyKernel/_make/boot.img
 *     tiny-machine -prof pages.prof -net tiny/tests/www -events pages.events \
 *       tiny/TinyKernel/_make/boot.img
 *
 * Then the maps of what ran, the kernel's and www's (tiny/TinyKernel's
 * Makefile links each with -map):
 *
 *     M=tiny/TinyKernel/_make
 *     tiny-prof -diff base.prof pages.prof -k $M/kernel.img.map \
 *       -u $M/bin/www.map
 *
 * The first line said how the eight page downs divided between the
 * kernel (drawing what www asks for) and www (making the messages). The
 * lines under it named the functions, and three findings came out of
 * them, each checked by profiling again after the change:
 *
 * - The kernel drew a text one character at a time, and each character
 *   was a whole draw: a rectangle clipped against three images, then 16
 *   rows of row_mask. draw, row_mask and the ML code around them were
 *   most of the kernel's share, some 13,000 instructions per character.
 *   Now one call of glyphs, in kdraw.s, draws a whole text, a word at a
 *   time, and glyphs3 is 2% of the eight page downs.
 * - row_copy2, the loop that copies the screen onto itself, then came
 *   first (38% of the kernel's share): the glide of a page down copies
 *   the page's area at each of its steps. It is now unrolled, four
 *   words per iteration; what remains is the price of seeing the page
 *   move.
 * - In www, ml_concat came first, with the collector after it
 *   (mlsys.copy, mlsys.collect, ml_alloc): over half of www's share was
 *   concatenating strings to build the drawing messages, two
 *   concatenations per number.
 *   TinyLibDraw now makes the bytes of the numbers up to 1023 once.
 *   The profile also showed skip (lines_between walked the page's list
 *   of lines from its end), so the lines are now kept in an array too.
 *
 * The page down went from about 7.7 million instructions to 5.4, and
 * the arrow key from over a million to 0.4 (the status section of
 * plan_tiny_browser.md has the table). A function in the list is the
 * place to look, not the answer: draw was not slow, it was called 80
 * times where once would do. The profile tells where; reading the code
 * tells why.
 *
 * twin:
 * mini-qemu has the same pair, with sampling: -prof F counts every
 * 1024th pc (raspberry/observe/Prof.ml), and a script maps them to a
 * kernel's functions (kernels/9pi/tests/perf/pcprof.py).
 *
 * Plan 9's emulators had the idea first: vi and 5i count every
 * instruction fetched by its address, and with the program's symbol
 * table they print the count and share of each function ($ip; see
 * iprofile in principia's machine/5i/stats.c, whose columns are
 * cycles, %, symbol and file). mini-5i has it too: its -prof counts
 * every pc of one program, and m-ix's mini-prof (profilers/misc), this
 * one's twin, reads that file as well as mini-qemu's.
 *
 * dropped:
 * The functions are all it shows. m-ix's mini-prof (profilers/misc)
 * can also list one function's instructions with their counts (-a),
 * read from the program and decoded, which is what a compiler's back
 * end is tuned on; here that means reading tiny-machine -l's listing
 * beside the profile. Names come only from tiny-ld's maps, not from
 * an executable's symbols. There is no source file (5i's iprofile
 * prints each function's), nor who called whom (gprof's graph).
 *
 * twist:
 * Every instruction is counted on a machine with a kernel, where
 * mini-qemu, the twin that runs one, samples a pc in 1024: the machine
 * is slow enough for that to cost little more than running it, and two
 * runs give the same profile. mini-5i's -prof counts every instruction
 * too, but of one program with no kernel; here the kernel's counts and
 * the program's are told apart, named by their own maps (-k, -u).
 *
 * cs-history:
 * Unix's prof (1973 or so) counted where the program was at each tick
 * of the clock, the kernel adding one to a histogram of addresses
 * (profil(2)); gprof (Graham, Kessler and McKusick, 1982) added who
 * called whom. A machine that is a program can do better than sample:
 * it counts every instruction, and disturbs nothing, not even the
 * kernel with its interrupts off. Later profilers went both ways:
 * counting, by rewriting the program to count its basic blocks (MIPS's
 * pixie, ATOM) or by running it on a simulated machine as here (Shade,
 * Valgrind's Cachegrind and Callgrind); or sampling a whole machine at
 * once, kernel and programs, at little cost (DCPI, Linux's perf,
 * Google-Wide Profiling), drawn since as flame graphs.
 *
 * references:
 *  - plan_tiny_browser.md: the profile that found where www's time
 *    went, before this program existed
 *  - raspberry/observe/Prof.mli
 *  - D. E. Knuth, "An Empirical Study of FORTRAN Programs" (Software:
 *    Practice and Experience, 1971): statements counted as they run,
 *    and most of the time in a few of them
 *  - Unix Programmer's Manual, prof(1) and profil(2): the clock's
 *    histogram of addresses
 *  - S. L. Graham, P. B. Kessler and M. K. McKusick, "gprof: a Call
 *    Graph Execution Profiler" (SIGPLAN Compiler Construction, 1982)
 *  - Plan 9's prof(1), with tprof and kprof: a program's and the
 *    kernel's profiles, the counterparts of vi's and 5i's
 *  - R. F. Cmelik and D. Keppel, "Shade: A Fast Instruction-Set
 *    Simulator for Execution Profiling" (SIGMETRICS, 1994): profiling
 *    by simulating the machine, as tiny-machine does
 *  - A. Srivastava and A. Eustace, "ATOM: A System for Building
 *    Customized Program Analysis Tools" (PLDI, 1994): counts by
 *    rewriting the binary
 *  - T. Ball and J. R. Larus, "Optimally Profiling and Tracing
 *    Programs" (TOPLAS, 1994) and "Efficient Path Profiling" (MICRO,
 *    1996): counting a few edges and deriving the rest
 *  - J. M. Anderson et al., "Continuous Profiling: Where Have All the
 *    Cycles Gone?" (SOSP, 1997): DCPI, sampling a whole machine, the
 *    kernel too
 *  - N. Nethercote and J. Seward, "Valgrind: A Framework for Heavyweight
 *    Dynamic Binary Instrumentation" (PLDI, 2007): Cachegrind's counts
 *    of every instruction, the closest to this program
 *  - G. Ren et al., "Google-Wide Profiling: A Continuous Profiling
 *    Infrastructure for Data Centers" (IEEE Micro, 2010)
 *  - T. Mytkowicz, A. Diwan, M. Hauswirth and P. F. Sweeney,
 *    "Evaluating the Accuracy of Java Profilers" (PLDI, 2010): samplers
 *    that disagree, where a count cannot
 *  - C. Curtsinger and E. D. Berger, "Coz: Finding Code that Counts
 *    with Causal Profiling" (SOSP, 2015): what a speedup would gain,
 *    the worked example's "the place to look, not the answer"
 *  - B. Gregg, "The Flame Graph" (CACM, 2016)
 *)

(* The program: its arguments (its name first), and how it exits. *)
val main :
  < Cap.stdout; Cap.stderr; Cap.open_in; .. > -> string array -> Exit.t
