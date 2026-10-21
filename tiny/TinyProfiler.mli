(* tiny-prof: where a program's instructions went, by function. It reads
 * a profile written by tiny-cpu -prof or tiny-machine -prof (every
 * instruction run, counted by its address) and tiny-linker's maps of
 * what ran (-map: each label's address), and prints the functions that
 * ran most, with their share.
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
 * The addresses of the labels come from the link itself (tiny-linker
 * writes the map as it writes the image), so the names cannot disagree
 * with what ran. A
 * count goes to the last label at or before its address. A label that
 * a compiler makes inside a function (tiny-ml's TinyBrowser.L12, tiny-c's
 * tm.L51) is not a function, so its counts go to the function before
 * it; an assembly loop's labels (row_copy2) are kept, as they say which
 * loop. tiny-ml's functions are named TinyBrowser.f151_browse: shown as browse.
 *
 * A profile of tiny-machine separates the kernel's instructions (-k
 * names its map) from the programs', and the programs by the base of
 * their window, their partition: -u names the map of one program,
 * the one with the most instructions unless -base says which. The
 * others are counted as "another program".
 *
 * With -diff base, a profile of a shorter run (the same session without
 * what is measured) is taken off first: a page down, measured as a
 * session with eight of them less the same session with none.
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
 * (old: the .tm files given, in their link's order, and assembled
 * again by tiny-prof, before tiny-linker)
 *
 * The first line said how the eight page downs divided between the
 * kernel (drawing what www asks for) and www (making the messages). The
 * lines under it named the functions, and three findings came out of
 * them, each checked by profiling again after the change:
 *
 * - The kernel drew a text a character at a time, each character a
 *   whole draw (a rectangle clipped against three images, then 16 rows
 *   of row_mask): draw, row_mask and the ML around them were most of
 *   the kernel's share, some 13,000 instructions a character. Now one
 *   call of draw.tm's glyphs draws a whole text, a word at a time, and
 *   glyphs3 is 2% of the eight page downs.
 * - row_copy2, the loop copying the screen onto itself, then came first
 *   (38% of the kernel's): the glide of a page down copies the page's
 *   area at each of its steps. Unrolled, four words a turn; what is left
 *   is the price of seeing the page move.
 * - In www, ml_concat and the collector after it (mlsys.copy,
 *   mlsys.collect, ml_alloc): over half of www's share was concatenating
 *   strings to build the drawing messages, two concatenations a number.
 *   TinyLibDraw now makes the bytes of the numbers up to 1023 once.
 *   The profile also showed skip (lines_between walking the page's list
 *   of lines from its end), so the lines are kept in an array too.
 *
 * The page down went from about 7.7 million instructions to 5.4, the
 * arrow from over a million to 0.4 (plan_tiny_browser.md's status has
 * the table). A function in the list is the place to look, not the
 * answer: draw was not slow, it was called 80 times where once would
 * do; the profile says where, reading the code says why.
 *
 * mini-qemu has the same pair, with sampling: -prof F counts every
 * 1024th pc (raspberry/observe/Prof.ml), and a script maps them to a
 * kernel's functions (kernels/9pi/tests/perf/pcprof.py). Here every
 * instruction is counted: the machine is slow enough for that to cost
 * little more than running it, and two runs give the same profile.
 *
 * cs-history:
 * Unix's prof (1973 or so) counted where the program was at each tick
 * of the clock, the kernel adding one to a histogram of addresses
 * (profil(2)); gprof (Graham, Kessler and McKusick, 1982) added who
 * called whom. A machine that is a program can do better than sample:
 * it counts every instruction, and disturbs nothing, not even the
 * kernel with its interrupts off.
 *
 * References: plan_tiny_browser.md (the profile that found where www's
 * time went, before this program existed); raspberry/observe/Prof.mli.
 *)

(* the program: its arguments to its exit status *)
val main : < Cap.stdout; Cap.stderr; Cap.argv; Cap.open_in; .. > -> int
