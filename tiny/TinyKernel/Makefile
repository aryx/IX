# Claude Code
#
# Copyright (C) 2026 Yoann Padioleau
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public License
# (LGPL) as published by the Free Software Foundation; either version
# 2 of the License, or (at your option) any later version.
#
# tiny-kernel: TinyKernel.ml (../TinyKernel.ml), a free kernel in ML for
# tiny-machine (docs/notes_tiny_kernel.md):
#
#   make run          the kernel on tiny-machine: sh on the console
#   make check        mltests, and a script through sh, against check.expected
#
# The kernel: entry.tm first (the machine starts at 0), the runtime
# (TinyML's, by tiny-c -tm), the kernel (tiny-ml -tm), end.tm last. Its
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

KERNEL = entry.tm ../tiny-os/libc/udivmod.tm runtime.tm kernel.tm end.tm
OURS = sh mltests
T6 = cat echo ls wc mkdir rm
L = ../tiny-os/libc
ULIB = $(L)/start.tm $(L)/udivmod.tm $(L)/libc.tm user/sys.tm

all: boot.img

kernel.tm: ../TinyKernel.ml
	$(TML) -tm -o $@ $<

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

user/bin/t6_%: $(ULIB) user/t6_%.tm
	@mkdir -p user/bin
	$(CPU) -o $@ $(ULIB) user/t6_$*.tm

PROGS = $(addprefix user/bin/,$(OURS)) $(addprefix user/bin/t6_,$(T6))

boot.img: kernel.img $(PROGS)
	cp kernel.img $@
	for f in $(PROGS); do n=$$(basename $$f); printf '%s\n%d\n' $${n#t6_} $$(stat -c %s $$f) >> $@; cat $$f >> $@; done
	printf '\n' >> $@

run: boot.img
	$(MACHINE) boot.img

check: boot.img
	echo mltests | timeout 300 $(MACHINE) boot.img > check.out
	printf 'echo hi | cat > f; cat f; ls; wc < f; rm f; cat f; mkdir d; cd d; echo x > g; cd ..; cat d/g\n' | timeout 300 $(MACHINE) boot.img >> check.out
	diff check.expected check.out && rm check.out && echo "tiny-kernel: check ok"

clean:
	rm -f kernel.img boot.img kernel.tm runtime.tm check.out
	rm -rf user/bin $(addprefix user/,$(addsuffix .tm,$(OURS))) user/t6_*.tm

.PHONY: all run check clean
.SECONDARY:
