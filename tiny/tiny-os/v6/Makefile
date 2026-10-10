# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# tiny-os v6: xv6's kind of kernel for tiny-machine, in C by tiny-c -tm
# and a page of .tm (docs/plans/plan_tiny_os.md):
#
#   make run          the kernel on tiny-machine, the disk fs.img: sh
#   make check        usertests, and a script through sh, on a fresh disk
#
# The kernel: entry.tm first (the machine starts at 0), the C, end.tm
# last (where the free pages start). The programs: a.out files (tiny-cpu
# -a, linked at 0x800000), start.tm first, with libc and usys.tm; the
# disk: tiny-mkfs's, the programs in its root. The tools from the PATH
# (after `dune install`), or from ix's bin/.
#
# What is built goes to _make/ and nowhere else (as dune's _build and
# mini-mk's _mk): the kernel's assembly and kernel.img, user/*.tm, bin/
# the programs, fs.img the disk; make clean removes it.

export PATH := $(abspath ../../../bin):$(PATH)

TC = tiny-c
CPU = tiny-cpu
MACHINE = tiny-machine
MKFS = tiny-mkfs

O = _make
KERNEL = entry.tm ../libc/udivmod.tm $(O)/main.tm $(O)/vm.tm $(O)/proc.tm $(O)/fs.tm $(O)/file.tm end.tm
UPROGS = init sh cat echo ls mkdir rm wc usertests
ULIB = ../libc/start.tm ../libc/udivmod.tm $(O)/libc.tm user/usys.tm

all: $(O)/kernel.img $(O)/fs.img

$(O)/%.tm: %.c defs.h
	@mkdir -p $(@D)
	$(TC) -tm -o $@ $<

$(O)/kernel.img: $(KERNEL)
	$(MACHINE) -o $@ $(KERNEL)

$(O)/libc.tm: ../libc/libc.c ../libc/libc.h
	@mkdir -p $(@D)
	$(TC) -tm -o $@ $<

$(O)/user/%.tm: user/%.c user/user.h
	@mkdir -p $(@D)
	$(TC) -tm -o $@ $<

$(O)/bin/%: $(ULIB) $(O)/user/%.tm
	@mkdir -p $(@D)
	$(CPU) -a $@ $(ULIB) $(O)/user/$*.tm

$(O)/fs.img: $(addprefix $(O)/bin/,$(UPROGS))
	$(MKFS) $@ $^

run: $(O)/kernel.img $(O)/fs.img
	$(MACHINE) -d $(O)/fs.img $(O)/kernel.img

# the output of both, on fresh disks, against check.expected
check: $(O)/kernel.img $(O)/fs.img
	cp $(O)/fs.img $(O)/check.img
	echo usertests | timeout 120 $(MACHINE) -d $(O)/check.img $(O)/kernel.img > $(O)/check.out
	cp $(O)/fs.img $(O)/check.img
	printf 'echo hi | cat > f; cat f; ls f; wc f; rm f; cat f\n' | timeout 120 $(MACHINE) -d $(O)/check.img $(O)/kernel.img >> $(O)/check.out
	rm -f $(O)/check.img
	diff check.expected $(O)/check.out && rm $(O)/check.out && echo "tiny-os v6: check ok"

clean:
	rm -rf $(O)

.PHONY: all run check clean
.SECONDARY:
