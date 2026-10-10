# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# tiny-kernel: TinyKernel.ml (../TinyKernel.ml), a free kernel in ML for
# tiny-machine (docs/notes_tiny_kernel.md):
#
#   make run          the kernel on tiny-machine: sh on the console
#   make check        mltests, and a script through sh, against check.expected;
#                     then three recorded sessions, the mouse and the keys
#                     from a file, the screen at the halt against its sum:
#                     paint.events (paint on the screen), windows.events
#                     (tiny-windows: three windows, ls, paint in one, a
#                     move, a delete, one brought to the front) and
#                     nested.events (tiny-windows in a window of
#                     tiny-windows, two windows in it), play.events (square,
#                     a game on ../TinyPlayground.ml, in a window: the
#                     arrows) and tetris.events (tetris in a window: six
#                     pieces moved, turned and dropped). A minute and a
#                     quarter
#
# The kernel: entry.tm first (the machine starts at 0), the runtime
# (TinyML's, by tiny-c -tm), the rows TinyGraphics.ml draws by (draw.tm),
# the machine's font (font.tm, made of mini-9pi's console's: 128
# characters of 8 by 16 bits), the kernel (tiny-ml -tm: memory.ml,
# ../TinyGraphics.ml and ../TinyKernel.ml, one program), end.tm last. Its
# files come after it in boot.img: for each program a name, a line, its
# size, a line, its bytes; an empty line at the end (no disk). The
# programs are tiny-cpu's own images (tiny-cpu -o, linked at 0: the
# kernel runs each at the start of its partition), start.tm first, with
# libc (../TinyC/libc/) and sys.tm; cat, echo, ls, wc, mkdir and rm are
# t6's too (tiny-os/t6/user/ has links to them).
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
KERNEL = entry.tm ../TinyC/libc/udivmod.tm $(O)/runtime.tm draw.tm $(O)/font.tm $(O)/kernel.tm end.tm
FONT = ../../kernels/lib_machine/font1.bin
PROGS = sh mltests paint tiny-windows square tetris cat echo ls wc mkdir rm
L = ../TinyC/libc
ULIB = $(L)/start.tm $(L)/udivmod.tm $(O)/libc.tm user/sys.tm

all: $(O)/boot.img

$(O)/kernel.tm: memory.ml ../TinyGraphics.ml ../TinyKernel.ml
	@mkdir -p $(@D)
	$(TML) -tm -o $@ memory.ml ../TinyGraphics.ml ../TinyKernel.ml

# the font's bytes, and k_font(), where they are (an ML integer)
$(O)/font.tm: $(FONT)
	@mkdir -p $(@D)
	printf 'k_font:\n\tla\tr13, font\n\tshli\tr13, r13, 1\n\tori\tr13, r13, 1\n\tret\nfont:\n' > $@
	od -An -v -tu1 -w16 $(FONT) | sed -e 's/^ */\t.byte\t/' -e 's/  */, /g' >> $@
	printf '\t.align\t4\n' >> $@

$(O)/runtime.tm: runtime.c ../TinyML/core.c
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

# a program in ML (tiny-windows: ../TinyWindows.ml, after ../TinyDraw.ml):
# compiled by tiny-ml -tm, with mlsys.c, TinyML's runtime and the
# system calls as ML's externals, which has the heap from 384 KB
$(O)/user/tiny-windows.tm: ../TinyDraw.ml ../TinyWindows.ml
	@mkdir -p $(@D)
	$(TML) -tm -o $@ ../TinyDraw.ml ../TinyWindows.ml
$(O)/user/mlsys.tm: ../TinyML/core.c
MLLINK = mkdir -p $(@D) && $(CPU) -o $@ $(ULIB) $(O)/user/mlsys.tm $(O)/user/$(@F).tm && \
	{ test $$(stat -c %s $@) -lt 393216 || { echo "$@: over 384 KB, where mlsys.c has its heap"; rm $@; exit 1; }; }
$(O)/bin/tiny-windows: $(ULIB) $(O)/user/mlsys.tm $(O)/user/tiny-windows.tm
	@$(MLLINK)

# a game: on ../TinyPlayground.ml, whose calls are calls.ml's; its last
# file runs it (square: the playground's test's)
PLAY = user/calls.ml ../TinyDraw.ml ../TinyPlayground.ml
SQUARE = ../tests/TinyPlayground_tests/Square.ml ../tests/TinyPlayground_tests/machine.ml
$(O)/user/square.tm: $(PLAY) $(SQUARE)
	@mkdir -p $(@D)
	$(TML) -tm -o $@ $(PLAY) $(SQUARE)
$(O)/bin/square: $(ULIB) $(O)/user/mlsys.tm $(O)/user/square.tm
	@$(MLLINK)
$(O)/user/tetris.tm: $(PLAY) ../TinyTetris.ml user/tetris.ml
	@mkdir -p $(@D)
	$(TML) -tm -o $@ $(PLAY) ../TinyTetris.ml user/tetris.ml
$(O)/bin/tetris: $(ULIB) $(O)/user/mlsys.tm $(O)/user/tetris.tm
	@$(MLLINK)

# a program that draws: with draw.c, the messages (draw.h)
$(O)/user/paint.tm: user/draw.h
$(O)/bin/paint: $(ULIB) $(O)/user/draw.tm $(O)/user/paint.tm
	@mkdir -p $(@D)
	$(CPU) -o $@ $(ULIB) $(O)/user/draw.tm $(O)/user/paint.tm

BINS = $(addprefix $(O)/bin/,$(PROGS))

$(O)/boot.img: $(O)/kernel.img $(BINS)
	cp $(O)/kernel.img $@
	for f in $(BINS); do printf '%s\n%d\n' $$(basename $$f) $$(stat -c %s $$f) >> $@; cat $$f >> $@; done
	printf '\n' >> $@
	@test $$(stat -c %s $@) -lt 1572864 || { echo "$@: over 1.5 MB, where runtime.c has the kernel's stack of values"; rm $@; exit 1; }

run: $(O)/boot.img
	$(MACHINE) $(O)/boot.img

check: $(O)/boot.img
	echo mltests | timeout 300 $(MACHINE) $(O)/boot.img > $(O)/check.out
	printf 'echo hi | cat > f; cat f; ls; wc < f; rm f; cat f; mkdir d; cd d; echo x > g; cd ..; cat d/g\n' | timeout 300 $(MACHINE) $(O)/boot.img >> $(O)/check.out
	diff check.expected $(O)/check.out
	for s in paint windows nested play tetris; do \
	  timeout 300 $(MACHINE) -events $$s.events -screen $(O)/check.ppm $(O)/boot.img > /dev/null || exit 1; \
	  cksum < $(O)/check.ppm > $(O)/check.sum; diff $$s.cksum $(O)/check.sum || { echo "tiny-kernel: $$s.events: another screen ($(O)/check.ppm)"; exit 1; }; \
	done
	rm $(O)/check.out $(O)/check.ppm $(O)/check.sum && echo "tiny-kernel: check ok"

clean:
	rm -rf $(O)

.PHONY: all run check clean
.SECONDARY:
