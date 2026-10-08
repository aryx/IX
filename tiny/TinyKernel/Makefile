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
#                     arrows). About a minute
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
# libc and sys.tm; cat, echo, ls, wc, mkdir and rm are t6's, unchanged
# (tiny-os/t6/user/).
# The tools from the PATH (after `dune install`), or from ix's bin/.

export PATH := $(abspath ../../bin):$(PATH)

TML = tiny-ml
TC = tiny-c
CPU = tiny-cpu
MACHINE = tiny-machine

KERNEL = entry.tm ../tiny-os/libc/udivmod.tm runtime.tm draw.tm font.tm kernel.tm end.tm
FONT = ../../kernels/lib_machine/font1.bin
OURS = sh mltests paint tiny-windows square
T6 = cat echo ls wc mkdir rm
L = ../tiny-os/libc
ULIB = $(L)/start.tm $(L)/udivmod.tm $(L)/libc.tm user/sys.tm

all: boot.img

kernel.tm: memory.ml ../TinyGraphics.ml ../TinyKernel.ml
	$(TML) -tm -o $@ memory.ml ../TinyGraphics.ml ../TinyKernel.ml

# the font's bytes, and k_font(), where they are (an ML integer)
font.tm: $(FONT)
	printf 'k_font:\n\tla\tr13, font\n\tshli\tr13, r13, 1\n\tori\tr13, r13, 1\n\tret\nfont:\n' > $@
	od -An -v -tu1 -w16 $(FONT) | sed -e 's/^ */\t.byte\t/' -e 's/  */, /g' >> $@
	printf '\t.align\t4\n' >> $@

runtime.tm: runtime.c ../TinyML_core.c
	$(TC) -tm -o $@ $<

kernel.img: $(KERNEL)
	$(MACHINE) -o $@ $(KERNEL)

$(L)/libc.tm: $(L)/libc.c $(L)/libc.h
	$(TC) -tm -o $@ $<

user/%.tm: user/%.c user/user.h
	$(TC) -tm -o $@ $<

user/t6_%.tm: ../tiny-os/t6/user/%.c ../tiny-os/t6/user/user.h
	$(TC) -tm -o $@ $<

user/bin/%: $(ULIB) user/%.tm
	@mkdir -p user/bin
	$(CPU) -o $@ $(ULIB) user/$*.tm

# a program in ML (tiny-windows: ../TinyWindows.ml, after ../TinyDraw.ml):
# compiled by tiny-ml -tm, with mlsys.c, TinyML's runtime and the
# system calls as ML's externals, which has the heap from 384 KB
user/tiny-windows.tm: ../TinyDraw.ml ../TinyWindows.ml
	$(TML) -tm -o $@ ../TinyDraw.ml ../TinyWindows.ml
user/mlsys.tm: ../TinyML_core.c
MLLINK = mkdir -p user/bin && $(CPU) -o $@ $(ULIB) user/mlsys.tm user/$(@F).tm && \
	{ test $$(stat -c %s $@) -lt 393216 || { echo "$@: over 384 KB, where mlsys.c has its heap"; rm $@; exit 1; }; }
user/bin/tiny-windows: $(ULIB) user/mlsys.tm user/tiny-windows.tm
	@$(MLLINK)

# a game: on ../TinyPlayground.ml, whose calls are calls.ml's; its last
# file runs it (square: the playground's test's)
PLAY = user/calls.ml ../TinyDraw.ml ../TinyPlayground.ml
SQUARE = ../tests/TinyPlayground_tests/Square.ml ../tests/TinyPlayground_tests/machine.ml
user/square.tm: $(PLAY) $(SQUARE)
	$(TML) -tm -o $@ $(PLAY) $(SQUARE)
user/bin/square: $(ULIB) user/mlsys.tm user/square.tm
	@$(MLLINK)

# a program that draws: with draw.c, the messages (draw.h)
user/paint.tm: user/draw.h
user/bin/paint: $(ULIB) user/draw.tm user/paint.tm
	@mkdir -p user/bin
	$(CPU) -o $@ $(ULIB) user/draw.tm user/paint.tm

user/bin/t6_%: $(ULIB) user/t6_%.tm
	@mkdir -p user/bin
	$(CPU) -o $@ $(ULIB) user/t6_$*.tm

PROGS = $(addprefix user/bin/,$(OURS)) $(addprefix user/bin/t6_,$(T6))

boot.img: kernel.img $(PROGS)
	cp kernel.img $@
	for f in $(PROGS); do n=$$(basename $$f); printf '%s\n%d\n' $${n#t6_} $$(stat -c %s $$f) >> $@; cat $$f >> $@; done
	printf '\n' >> $@
	@test $$(stat -c %s $@) -lt 1572864 || { echo "$@: over 1.5 MB, where runtime.c has the kernel's stack of values"; rm $@; exit 1; }

run: boot.img
	$(MACHINE) boot.img

check: boot.img
	echo mltests | timeout 300 $(MACHINE) boot.img > check.out
	printf 'echo hi | cat > f; cat f; ls; wc < f; rm f; cat f; mkdir d; cd d; echo x > g; cd ..; cat d/g\n' | timeout 300 $(MACHINE) boot.img >> check.out
	diff check.expected check.out
	for s in paint windows nested play; do \
	  timeout 300 $(MACHINE) -events $$s.events -screen check.ppm boot.img > /dev/null || exit 1; \
	  cksum < check.ppm > check.sum; diff $$s.cksum check.sum || { echo "tiny-kernel: $$s.events: another screen (check.ppm)"; exit 1; }; \
	done
	rm check.out check.ppm check.sum && echo "tiny-kernel: check ok"

clean:
	rm -f kernel.img boot.img kernel.tm runtime.tm font.tm check.out check.ppm check.sum
	rm -rf user/bin $(addprefix user/,$(addsuffix .tm,$(OURS))) user/draw.tm user/mlsys.tm user/t6_*.tm

.PHONY: all run check clean
.SECONDARY:
