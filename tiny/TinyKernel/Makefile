# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# tiny-kernel: TinyKernel.ml (../TinyKernel.ml), a free kernel in ML for
# tiny-machine (docs/notes_tiny_kernel.md):
#
#   make run          the kernel on tiny-machine: sh on the console
#   make check        mltests, a script through sh, then the network (ping
#                     and get against tiny-machine's end of the wire, a
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
#                     pieces moved, turned and dropped) and calc.events
#                     (calc, on ../TinyLibGUI.ml, in a window: 12 * 3 = by its
#                     buttons, + 6 by the keys, a press taken back, a
#                     button held) and temp.events (temp, its two
#                     fields typed in, in a window); and two with the
#                     network: wiki.events (wiki mandelbrot: a picture
#                     from the wire's other end, ../tests/www's, painted
#                     a row a message) and wikiwin.events (the same in a
#                     window of tiny-windows), a row's packet lost in
#                     each, the screen the same. A minute and a half
#
# The kernel: entry.tm first (the machine starts at 0), the runtime
# (TinyML's, by tiny-c -tm), the rows TinyKernelGraphics.ml draws by (draw.tm),
# the machine's font (font.tm, made of mini-9pi's console's: 128
# characters of 8 by 16 bits), the kernel (tiny-ml -tm: memory.ml,
# TinyKernelGraphics.ml and ../TinyKernel.ml, one program), end.tm last. Its
# files come after it in boot.img: for each program a name, a line, its
# size, a line, its bytes; an empty line at the end (no disk). The
# programs are tiny-cpu's own images (tiny-cpu -o, linked at 0: the
# kernel runs each at the start of its partition), start.tm first, with
# libc (../TinyCRuntime/) and sys.tm; cat, echo, ls, wc, mkdir and rm are
# t6's too (TinyKernel/steps/t6/user/ has links to them).
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
PROGS = sh mltests paint windows square tetris calc temp ping get wiki httpd cat echo ls wc mkdir rm
L = ../TinyCRuntime
ULIB = $(L)/start.tm $(L)/udivmod.tm $(O)/libc.tm user/sys.tm

all: $(O)/boot.img

$(O)/kernel.tm: memory.ml TinyKernelGraphics.ml TinyKernelNetwork.ml ../TinyKernel.ml
	@mkdir -p $(@D)
	$(TML) -tm -o $@ memory.ml TinyKernelGraphics.ml TinyKernelNetwork.ml ../TinyKernel.ml

# the font's bytes, and k_font(), where they are (an ML integer)
$(O)/font.tm: $(FONT)
	@mkdir -p $(@D)
	printf 'k_font:\n\tla\tr13, font\n\tshli\tr13, r13, 1\n\tori\tr13, r13, 1\n\tret\nfont:\n' > $@
	od -An -v -tu1 $(FONT) | awk 'NF { printf "\t.byte\t%s", $$1; for (i = 2; i <= NF; i++) printf ", %s", $$i; print "" }' >> $@
	printf '\t.align\t4\n' >> $@

$(O)/runtime.tm: runtime.c ../TinyMLRuntime/core.c
	@mkdir -p $(@D)
	$(TC) -tm -o $@ $<

$(O)/kernel.img: $(KERNEL)
	$(MACHINE) -o $@ $(KERNEL)

$(O)/libc.tm: $(L)/libc.c $(L)/libc.h
	@mkdir -p $(@D)
	$(TC) -tm -o $@ $<

$(O)/user/%.tm: user/%.c user/user.h
	@mkdir -p $(@D)
	$(TC) -tm -o $@ $<

$(O)/bin/%: $(ULIB) $(O)/user/%.tm
	@mkdir -p $(@D)
	$(CPU) -o $@ $(ULIB) $(O)/user/$*.tm

# a program in ML (windows, tiny-windows: ../TinyWindows.ml, after
# ../TinyLibDraw.ml):
# compiled by tiny-ml -tm, with mlsys.c, TinyML's runtime and the
# system calls as ML's externals, which has the heap from 384 KB
$(O)/user/windows.tm: ../TinyLibDraw.ml ../TinyWindows.ml
	@mkdir -p $(@D)
	$(TML) -tm -o $@ ../TinyLibDraw.ml ../TinyWindows.ml
$(O)/user/mlsys.tm: ../TinyMLRuntime/core.c
MLLINK = mkdir -p $(@D) && $(CPU) -o $@ $(ULIB) $(O)/user/mlsys.tm $(O)/user/$(@F).tm && \
	{ test $$(wc -c < $@) -lt 393216 || { echo "$@: over 384 KB, where mlsys.c has its heap"; rm $@; exit 1; }; }
$(O)/bin/windows: $(ULIB) $(O)/user/mlsys.tm $(O)/user/windows.tm
	@$(MLLINK)

# a game: on ../TinyLibPlayground.ml, whose calls are calls.ml's; its last
# file runs it (square: the playground's test's)
PLAY = user/calls.ml ../TinyLibDraw.ml ../TinyLibPlayground.ml
SQUARE = ../tests/TinyLibPlayground_tests/Square.ml ../tests/TinyLibPlayground_tests/machine.ml
$(O)/user/square.tm: $(PLAY) $(SQUARE)
	@mkdir -p $(@D)
	$(TML) -tm -o $@ $(PLAY) $(SQUARE)
$(O)/bin/square: $(ULIB) $(O)/user/mlsys.tm $(O)/user/square.tm
	@$(MLLINK)
$(O)/user/tetris.tm: $(PLAY) ../TinyAppTetris.ml user/tetris.ml
	@mkdir -p $(@D)
	$(TML) -tm -o $@ $(PLAY) ../TinyAppTetris.ml user/tetris.ml
$(O)/bin/tetris: $(ULIB) $(O)/user/mlsys.tm $(O)/user/tetris.tm
	@$(MLLINK)

# a program with widgets: on ../TinyLibGUI.ml, which draws by the
# playground's shapes (calc: ../TinyAppCalculator.ml; temp:
# ../TinyAppTemperature.ml)
$(O)/user/calc.tm: $(PLAY) ../TinyLibGUI.ml ../TinyAppCalculator.ml user/calc.ml
	@mkdir -p $(@D)
	$(TML) -tm -o $@ $(PLAY) ../TinyLibGUI.ml ../TinyAppCalculator.ml user/calc.ml
$(O)/bin/calc: $(ULIB) $(O)/user/mlsys.tm $(O)/user/calc.tm
	@$(MLLINK)
$(O)/user/temp.tm: $(PLAY) ../TinyLibGUI.ml ../TinyAppTemperature.ml user/temp.ml
	@mkdir -p $(@D)
	$(TML) -tm -o $@ $(PLAY) ../TinyLibGUI.ml ../TinyAppTemperature.ml user/temp.ml
$(O)/bin/temp: $(ULIB) $(O)/user/mlsys.tm $(O)/user/temp.tm
	@$(MLLINK)

# a program that draws: with draw.c, the messages (draw.h)
$(O)/user/paint.tm: user/draw.h
$(O)/bin/paint: $(ULIB) $(O)/user/draw.tm $(O)/user/paint.tm
	@mkdir -p $(@D)
	$(CPU) -o $@ $(ULIB) $(O)/user/draw.tm $(O)/user/paint.tm
# a program that reaches a machine by its name: with net.c
$(O)/bin/get: $(O)/bin/%: $(ULIB) $(O)/user/net.tm $(O)/user/%.tm
	@mkdir -p $(@D)
	$(CPU) -o $@ $(ULIB) $(O)/user/net.tm $(O)/user/$*.tm
$(O)/user/wiki.tm: user/draw.h
$(O)/bin/wiki: $(ULIB) $(O)/user/draw.tm $(O)/user/wiki.tm
	@mkdir -p $(@D)
	$(CPU) -o $@ $(ULIB) $(O)/user/draw.tm $(O)/user/wiki.tm

BINS = $(addprefix $(O)/bin/,$(PROGS))

$(O)/boot.img: $(O)/kernel.img $(BINS)
	cp $(O)/kernel.img $@
	for f in $(BINS); do printf '%s\n%d\n' $$(basename $$f) $$(wc -c < $$f) >> $@; cat $$f >> $@; done
	printf '\n' >> $@
	@test $$(wc -c < $@) -lt 2621440 || { echo "$@: over 2.5 MB, where runtime.c has the kernel's stack of values"; rm $@; exit 1; }

run: $(O)/boot.img
	$(MACHINE) $(O)/boot.img

check: $(O)/boot.img
	echo mltests | timeout 300 $(MACHINE) $(O)/boot.img > $(O)/check.out
	printf 'echo hi | cat > f; cat f; ls; wc < f; rm f; cat f; mkdir d; cd d; echo x > g; cd ..; cat d/g\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	printf 'ping\nping 10.0.0.9\n' | timeout 300 $(MACHINE) -net . $(O)/boot.img >> $(O)/check.out
	printf 'get hello.txt\nget il.txt | wc\nget nothing\nget hello.txt 10.0.0.9\n' | timeout 300 $(MACHINE) -net ../tests/www -net-lose 7 -net-trace $(O)/boot.img >> $(O)/check.out 2> $(O)/check.trace
	cut -c15- $(O)/check.trace >> $(O)/check.out
	diff $(T)/check.expected $(O)/check.out
	for s in paint windows nested play tetris calc temp; do \
	  timeout 300 $(MACHINE) -events $(T)/$$s.events -screen $(O)/check.ppm $(O)/boot.img > /dev/null || exit 1; \
	  cksum < $(O)/check.ppm > $(O)/check.sum; diff $(T)/$$s.cksum $(O)/check.sum || { echo "tiny-kernel: $$s.events: another screen ($(O)/check.ppm)"; exit 1; }; \
	done
	for s in wiki wikiwin; do \
	  timeout 300 $(MACHINE) -net ../tests/www -net-lose 100 -events $(T)/$$s.events -screen $(O)/check.ppm $(O)/boot.img > /dev/null || exit 1; \
	  cksum < $(O)/check.ppm > $(O)/check.sum; diff $(T)/$$s.cksum $(O)/check.sum || { echo "tiny-kernel: $$s.events: another screen ($(O)/check.ppm)"; exit 1; }; \
	done
	rm $(O)/check.out $(O)/check.trace $(O)/check.ppm $(O)/check.sum && echo "tiny-kernel: check ok"

clean:
	rm -rf $(O)

.PHONY: all run check clean
.SECONDARY:
