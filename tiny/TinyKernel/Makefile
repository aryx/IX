# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# tiny-kernel: TinyKernel.ml (../TinyKernel.ml), a free kernel in ML for
# tiny-machine (docs/notes_tiny_kernel.md):
#
#   make run          the kernel on tiny-machine: sh on the console
#   make check        mltests, a script through sh, the utilities through
#                     rc (utils: walk, du, cp, mv, xd, test, ln, grep, sort, ls -l...; pipes of six stages; ed and sam; emacs's
#                     ^C, M-x and a macro; office's page, a text and a sheet, saved; troff's text and web page of
#                     /examples/report.ixd), then the network (ping,
#                     get, and put kept across two boots, against
#                     tiny-machine's end of the wire, a
#                     packet lost, each packet as -net-trace says it,
#                     without its time), against check.expected;
#                     then three recorded sessions, the mouse and the keys
#                     from a file, the screen at the halt against its sum:
#                     paint.events (paint on the screen), windows.events
#                     (windows, tiny-windows: three windows, ls, paint in one, a
#                     move, a delete, one brought to the front) and
#                     nested.events (tiny-windows in a window of
#                     tiny-windows, two windows in it), play.events (square,
#                     a game on ../TinyLibPlayground.ml, in a window: the
#                     arrows) and tetris.events (tetris in a window: six
#                     pieces moved, turned and dropped; and its sounds,
#                     the speaker's samples as a WAV, against their sum) and calc.events
#                     (calc, on ../TinyLibGUI.ml, in a window: 12 * 3 = by its
#                     buttons, + 6 by the keys, a press taken back, a
#                     button held) and temp.events (temp, its two
#                     fields typed in, in a window) and emacs.events
#                     (emacs f in a window: two lines typed, a word
#                     killed and another typed, saved, quit, cat f);
#                     the office's (office, officesheet, officedraw,
#                     officepaint: a page, a sheet and its chart, a
#                     drawing, a paint, in a window); and with the
#                     network, ../tests/www's pages, the browser's (www,
#                     wwwlink, wwwback, wwwgo, wwwpicture, wwwwin,
#                     wwwscroll: the OCaml article, a link followed and
#                     back, a section gone to, its pictures, in a window,
#                     scrolled). A few minutes
#
# The kernel: entry.tm first (the machine starts at 0), the runtime
# (TinyML's, by tiny-c -tm), the rows TinyKernelGraphics.ml draws by (draw.tm),
# the machine's font (font.tm, made of mini-9pi's console's: 128
# characters of 8 by 16 bits), the kernel (tiny-ml -tm: memory.ml,
# TinyKernelGraphics.ml, TinyKernelNetwork.ml, TinyKernelAudio.ml and
# ../TinyKernel.ml, one program), end.tm last. Its
# files come after it in boot.img: for each program a name, a line, its
# size, a line, its bytes; an empty line at the end (no disk). The
# programs are tiny-cpu's own images (tiny-cpu -o, linked at 0: the
# kernel runs each at the start of its partition), start.tm first, with
# libc (../TinyCRuntime/) and sys.tm. A hard link is a name and a line
# "link utils" (what link() does, at the boot): utils (../TinyUtilities.ml, tiny-utils) is in the image once,
# under the name of each of its utilities (cat, ls, wc...). user/'s
# cat, echo, ls, wc, mkdir and rm in C are not in the image any more,
# but t6's (TinyKernel/steps/t6/user/ has links to them).
#
# user/ has the programs, a file each (the ones in C; an ML one's
# last file, which runs it); libc/ what a C program is linked with to
# call this kernel (user.h, sys.tm, draw.c, net.c); libml/ the same
# for an ML one (mlsys.c, calls.ml, TinyLibSystem.ml).
#
# What is built goes to _make/ and nowhere else, so that this
# directory shows the sources: _make/*.tm the kernel's assembly,
# kernel.img, user/*.tm the programs' assembly, bin/ the programs as
# they are in the image, boot.img the image; make clean removes it.
# The tools from the PATH (after `dune install`), or from ix's bin/.

export PATH := $(abspath ../../bin):$(PATH)

TML = tiny-ml
TC = tiny-c
CPU = tiny-cpu
MACHINE = tiny-machine

O = _make
# make check's check.expected, sessions (.events) and screens' sums (.cksum)
T = ../tests/TinyKernel_tests
KERNEL = entry.tm ../TinyCRuntime/udivmod.tm $(O)/runtime.tm draw.tm $(O)/font.tm $(O)/kernel.tm end.tm
FONT = ../../kernels/lib_machine/font1.bin
PROGS = sh rc emacs office troff mltests paint windows square tetris calc temp ping get put httpd utils ed bigmem www
# other names (hard links), a name:program each
LINKS = editor:emacs sam:ed
# utils's names (TinyUtilities.ml's table)
UTILS = [ basename cat cmp cp du echo grep ln ls mkdir mv pwd rm seq sleep sort tail tee test touch walk wc xd
L = ../TinyCRuntime
ULIB = $(L)/start.tm $(L)/udivmod.tm $(O)/libc.tm libc/sys.tm

all: $(O)/boot.img

$(O)/kernel.tm: ../TinyLibStd.ml memory.ml TinyKernelGraphics.ml TinyKernelNetwork.ml TinyKernelAudio.ml ../TinyKernel.ml
	@mkdir -p $(@D)
	$(TML) -tm -o $@ $^

# the font's bytes, and k_font(), where they are (an ML integer)
$(O)/font.tm: $(FONT)
	@mkdir -p $(@D)
	printf 'k_font:\n\tla\tr13, font\n\tshli\tr13, r13, 1\n\tori\tr13, r13, 1\n\tret\nfont:\n' > $@
	od -An -v -tu1 $(FONT) | awk 'NF { printf "\t.byte\t%s", $$1; for (i = 2; i <= NF; i++) printf ", %s", $$i; print "" }' >> $@
	printf '\t.align\t4\n' >> $@

$(O)/runtime.tm: ../TinyMLRuntime/core.c

$(O)/kernel.img: $(KERNEL)
	$(MACHINE) -o $@ $(KERNEL)

$(O)/libc.tm: $(L)/libc.c $(L)/libc.h
	@mkdir -p $(@D)
	$(TC) -tm -o $@ $<

# a file in C: the kernel's runtime.c, a program of user/, or what a
# program is linked with besides: libc/ for one in C (draw.c, net.c),
# libml/ for one in ML (mlsys.c)
$(O)/%.tm: %.c libc/user.h
	@mkdir -p $(@D)
	$(TC) -tm -o $@ $<

$(O)/bin/%: $(ULIB) $(O)/user/%.tm
	@mkdir -p $(@D)
	$(CPU) -o $@ $(ULIB) $(O)/user/$*.tm

# a program in ML: its files, below, compiled by tiny-ml -tm, with
# mlsys.c, TinyML's runtime and the system calls as ML's externals,
# which has the heap from 384 KB (windows, tiny-windows:
# ../TinyWindows.ml, after ../TinyLibDraw.ml)
ML = windows bigmem www square tetris calc temp rc utils ed emacs office troff
MLBINS = windows square tetris calc temp rc utils ed emacs office troff
$(patsubst %,$(O)/user/%.tm,$(ML)):
	@mkdir -p $(@D)
	$(TML) -tm -o $@ $^
$(O)/libml/mlsys.tm: ../TinyMLRuntime/core.c
$(patsubst %,$(O)/bin/%,$(MLBINS)): $(O)/bin/%: $(ULIB) $(O)/libml/mlsys.tm $(O)/user/%.tm
	@mkdir -p $(@D)
	$(CPU) -o $@ $(ULIB) $(O)/libml/mlsys.tm $(O)/user/$*.tm
	@test $$(wc -c < $@) -lt 393216 || { echo "$@: over 384 KB, where mlsys.c has its heap"; rm $@; exit 1; }
$(O)/user/windows.tm: ../TinyLibDraw.ml ../TinyWindows.ml

# a program that asks for more memory than 1 MB: linked as an a.out
# whose header asks for 8 MB (tiny-cpu -a 8), so tiny-kernel gives it an
# 8 MB partition and mlsys.c a heap of that size (bigmem: the test)
$(O)/user/bigmem.tm: user/bigmem.ml
$(O)/bin/bigmem: $(ULIB) $(O)/libml/mlsys.tm $(O)/user/bigmem.tm
	@mkdir -p $(@D)
	$(CPU) -a 8 $@ $(ULIB) $(O)/libml/mlsys.tm $(O)/user/bigmem.tm

# the web browser (www: ../TinyBrowser.ml, and user/www.ml, which runs
# it), linked as an a.out that asks for 10 MB: a page's lines live in
# its heap. Its code must stay under 384 KB, where mlsys.c's stack of
# values starts.
WWW = libml/calls.ml ../TinyLibStd.ml ../TinyLibDraw.ml ../TinyBrowser.ml user/www.ml
$(O)/user/www.tm: $(WWW)
$(O)/bin/www: $(ULIB) $(O)/libml/mlsys.tm $(O)/user/www.tm
	@mkdir -p $(@D)
	$(CPU) -a 10 $@ $(ULIB) $(O)/libml/mlsys.tm $(O)/user/www.tm
	@test $$(wc -c < $@) -lt 393216 || { echo "$@: over 384 KB, where mlsys.c has its stack of values"; rm $@; exit 1; }

# a game: on ../TinyLibPlayground.ml, whose calls are calls.ml's; its last
# file runs it (square: the playground's test's)
PLAY = libml/calls.ml ../TinyLibDraw.ml ../TinyLibPlayground.ml
SQUARE = ../tests/TinyLibPlayground_tests/Square.ml ../tests/TinyLibPlayground_tests/machine.ml
$(O)/user/square.tm: $(PLAY) $(SQUARE)
$(O)/user/tetris.tm: $(PLAY) ../TinyAppTetris.ml user/tetris.ml

# a program with widgets: on ../TinyLibGUI.ml, which draws by the
# playground's shapes (calc: ../TinyAppCalculator.ml; temp:
# ../TinyAppTemperature.ml)
$(O)/user/calc.tm: $(PLAY) ../TinyLibGUI.ml ../TinyAppCalculator.ml user/calc.ml
$(O)/user/temp.tm: $(PLAY) ../TinyLibGUI.ml ../TinyAppTemperature.ml user/temp.ml

# a tool of the host's that runs here too (rc: ../TinyShell.ml,
# tiny-shell): on ../TinyLibStd.ml, what it names of OCaml's standard
# library, and libml/TinyLibSystem.ml, the system's calls it asks for
# (the host's is ../TinyLibHost/TinyLibSystem.ml)
TOOL = libml/calls.ml ../TinyLibStd.ml libml/TinyLibSystem.ml
$(O)/user/rc.tm: $(TOOL) ../TinyShell.ml

# the utilities (utils: ../TinyUtilities.ml, tiny-utils), on the same
# library as rc, and ../TinyLibRegex.ml for grep
$(O)/user/utils.tm: $(TOOL) ../TinyLibRegex.ml ../TinyUtilities.ml

# the line editor (ed, and sam: ../TinyEditorLine.ml, tiny-editor), on
# the same library as rc, and grep's ../TinyLibRegex.ml
$(O)/user/ed.tm: $(TOOL) ../TinyLibRegex.ml ../TinyEditorLine.ml

# the screen editor (emacs: ../TinyEditorScreen.ml, the editor, run by
# ../TinyLibGUI.ml's run_canvas; user/emacs.ml, the few lines between)
EMACS = libml/calls.ml ../TinyLibStd.ml ../TinyLibDraw.ml ../TinyLibPlayground.ml ../TinyLibGUI.ml ../TinyEditorScreen.ml user/emacs.ml
$(O)/user/emacs.tm: $(EMACS)

# the office (../TinyOffice.ml, the page and its parts, run by
# ../TinyLibGUI.ml's run_canvas;
# user/office.ml, the few lines between)
OFFICE = libml/calls.ml ../TinyLibStd.ml ../TinyLibDraw.ml ../TinyLibPlayground.ml ../TinyLibGUI.ml ../TinyOffice.ml user/office.ml
$(O)/user/office.tm: $(OFFICE)

# troff (../TinyTroff.ml, a page as text or HTML, on the office's
# reading of it; user/troff.ml, the few lines between)
TROFF = libml/calls.ml ../TinyLibStd.ml ../TinyLibDraw.ml ../TinyLibPlayground.ml ../TinyLibGUI.ml ../TinyOffice.ml ../TinyTroff.ml user/troff.ml
$(O)/user/troff.tm: $(TROFF)

# a program that draws: with draw.c, the messages (draw.h); a demo, in
# examples/ (not counted by make loc)
$(O)/user/paint.tm: examples/paint.c libc/user.h libc/draw.h
	@mkdir -p $(@D)
	$(TC) -tm -o $@ $<
$(O)/bin/paint: $(ULIB) $(O)/libc/draw.tm $(O)/user/paint.tm
	@mkdir -p $(@D)
	$(CPU) -o $@ $(ULIB) $(O)/libc/draw.tm $(O)/user/paint.tm
# a program that reaches a machine by its name: with net.c
$(O)/bin/get $(O)/bin/put: $(O)/bin/%: $(ULIB) $(O)/libc/net.tm $(O)/user/%.tm
	@mkdir -p $(@D)
	$(CPU) -o $@ $(ULIB) $(O)/libc/net.tm $(O)/user/$*.tm

BINS = $(addprefix $(O)/bin/,$(PROGS))

# files to edit, in /examples: sources of programs, two in C (wc.c, the
# t6 step kernel's: steps/t6/user/) and two in OCaml, which emacs shows in colors (emacs
# /examples/emacs.ml: the editor around the editor); a page of the
# office's, which troff prints (office /examples/report.ixd, troff -h
# /examples/report.ixd)
EXAMPLES = steps/t6/user/wc.c user/sh.c user/emacs.ml ../TinyEditorScreen.ml examples/report.ixd

$(O)/boot.img: $(O)/kernel.img $(BINS) $(EXAMPLES)
	cp $(O)/kernel.img $@
	for f in $(BINS); do printf '%s\n%d\n' $$(basename $$f) $$(wc -c < $$f) >> $@; cat $$f >> $@; done
	for f in $(EXAMPLES); do printf 'examples/%s\n%d\n' $$(basename $$f) $$(wc -c < $$f) >> $@; cat $$f >> $@; done
	for u in $(UTILS); do printf '%s\nlink utils\n' "$$u" >> $@; done
	for l in $(LINKS); do printf '%s\nlink %s\n' $${l%%:*} $${l#*:} >> $@; done
	printf '\n' >> $@
	@test $$(wc -c < $@) -lt 4718592 || { echo "$@: over 4.5 MB, where runtime.c has the kernel's stack of values"; rm $@; exit 1; }

run: $(O)/boot.img
	$(MACHINE) $(O)/boot.img

# the recorded sessions, each against its screen's sum; the browser's
# read ../tests/www's pages
SCREENS = paint windows nested play tetris calc temp emacs emacsmx emacscolors office officesheet officedraw officepaint \
	www wwwlink wwwback wwwgo wwwpicture wwwwin wwwscroll
check: $(O)/boot.img
	echo mltests | timeout 300 $(MACHINE) $(O)/boot.img > $(O)/check.out
	echo bigmem | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'echo hi | cat > f; cat f; ls; wc < f; rm f; cat f; mkdir d; cd d; echo x > g; cd ..; cat d/g\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'rc\nx=(a b c); echo $$x $$#x $$x^.c\nfor(i in a b) echo $$i\nfn greet { echo hello $$1 }; greet you\ny=`{echo one two}; echo $$#y\n{ echo a; echo b } > f; cat f | wc; cat < f; rm f\n~ b $$x && echo b is in x\nnosuch || echo failed: $$status\nmkdir d; echo x > d/g; echo */g; cd /nowhere\necho x >> f\necho no >[1=2]\nexit\necho echo $$1 $$2 > s\nrc s from a file\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'rc\nmkdir -p d/e; cd d; pwd; echo hello > e/f; walk; du; cp e/f g; mv g e/h; ls e; cmp e/f e/h && echo same\nxd -c e/f; seq 2 2 6; tail -1 e/f; test -d e -a ! -f e && echo dir; [ -f nosuch ] || echo none\nmv e x; cd /; rm -r d; ls d\nexit\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'rc\nmkdir b; ln /wc b/wc; echo one two three | b/wc -w\necho hi > f; ln f g; echo bye > g; cat f; rm f; cat g\nln b c; ln nosuch c; ls c\nexit\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'rc\nls | grep \x27^t\x27 | sort -r\nls | grep -c \x27^(ls|wc|cat)$$\x27\nseq 12 -3 1 | sort -n; seq 5 | sort -r | grep -v \x27[2-4]\x27\ngrep \x27(\x27 sh; echo $$status\nexit\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'rc\nls -l /cat /utils /emacs /editor /ping\nls -l / > f; wc f; ls -l / | wc; cat f | grep -v zzz | wc\nexit\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'rc\nseq 30 | grep 1 | sort -rn | tail -3 | cat | wc -l\ntest -f no | cat | test -f no; echo $$status\nseq 3 | cat | cat | cat | cat | cat | wc -l\nexit\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'rc\necho hello world > f\ned f\n,x/o/c/0/\n$$a\nadded\n.\n,p\nw\nq\ncat f\nsam f\n,x/l+/c/L/\n,p\nq\nq\nls -l /ed /sam /emacs /editor\nexit\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	timeout 300 $(MACHINE) -events $(T)/emacskeys.events $(O)/boot.img >> $(O)/check.out
	timeout 300 $(MACHINE) -events $(T)/officekeys.events $(O)/boot.img >> $(O)/check.out
	printf 'rc\ntroff /examples/report.ixd\ntroff -h /examples/report.ixd > r.html; troff -p /examples/report.ixd > r.pdf; wc r.html r.pdf; troff\nexit\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	rm -rf $(O)/kept; mkdir $(O)/kept
	printf 'rc\necho hello world > notes; put notes\nseq 2000 > big; put big numbers\nput nosuch\nput notes ../x\nget \x27\x27\nexit\n' | timeout 300 $(MACHINE) -net $(O)/kept $(O)/boot.img >> $(O)/check.out
	cat $(O)/kept/notes >> $(O)/check.out; wc -c < $(O)/kept/numbers >> $(O)/check.out
	printf 'rc\nfor(f in `{get \x27\x27}) get $$f > $$f\ncat notes; wc numbers\nexit\n' | timeout 300 $(MACHINE) -net $(O)/kept $(O)/boot.img >> $(O)/check.out
	printf 'ping\nping 10.0.0.9\n' | timeout 300 $(MACHINE) -net . $(O)/boot.img >> $(O)/check.out
	printf 'get hello.txt\nget il.txt | wc\nget nothing\nget hello.txt 10.0.0.9\n' | timeout 300 $(MACHINE) -net ../tests/www -net-lose 7 -net-trace $(O)/boot.img >> $(O)/check.out 2> $(O)/check.trace
	cut -c15- $(O)/check.trace >> $(O)/check.out
	printf "rc\nget 'www OCaml' | wc\nget 'www https://en.wikipedia.org/wiki/OCaml#History' | wc\nget 'www Plan 9 from Bell Labs'\nexit\n" | timeout 300 $(MACHINE) -net ../tests/www $(O)/boot.img >> $(O)/check.out
	diff $(T)/check.expected $(O)/check.out
	for s in $(SCREENS); do \
	  timeout 300 $(MACHINE) -net ../tests/www -events $(T)/$$s.events -screen $(O)/check.ppm $(O)/boot.img > /dev/null || exit 1; \
	  cksum < $(O)/check.ppm > $(O)/check.sum; diff $(T)/$$s.cksum $(O)/check.sum || { echo "tiny-kernel: $$s.events: another screen ($(O)/check.ppm)"; exit 1; }; \
	done
	timeout 300 $(MACHINE) -events $(T)/tetris.events -audio $(O)/check.wav $(O)/boot.img > /dev/null
	cksum < $(O)/check.wav > $(O)/check.sum; diff $(T)/tetris.wav.cksum $(O)/check.sum || { echo "tiny-kernel: tetris.events: other sounds ($(O)/check.wav)"; exit 1; }
	rm $(O)/check.out $(O)/check.trace $(O)/check.ppm $(O)/check.wav $(O)/check.sum && echo "tiny-kernel: check ok"

clean:
	rm -rf $(O)

.PHONY: all run check clean
.SECONDARY:
