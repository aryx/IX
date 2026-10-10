# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# t6, tiny-os's free kernel (docs/plans/plan_tiny_os.md):
#
#   make run          the kernel on tiny-machine, the disk fs.img: sh
#   make check        t6tests, and a script through sh, on a fresh disk
#
# The kernel: entry.tm first (the machine starts at 0), then the C. The
# programs are tiny-cpu's own images (tiny-cpu -o, linked at 0: t6 runs
# each at the start of its partition), start.tm first, with libc and
# sys.tm; the disk is a FAT (tiny-mkfs -fat). The tools from the PATH
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
KERNEL = entry.tm ../libc/udivmod.tm $(O)/main.tm $(O)/proc.tm $(O)/file.tm
UPROGS = init sh cat echo ls mkdir rm wc t6tests
ULIB = ../libc/start.tm ../libc/udivmod.tm $(O)/libc.tm user/sys.tm

all: $(O)/kernel.img $(O)/fs.img

$(O)/%.tm: %.c t6.h
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
	$(CPU) -o $@ $(ULIB) $(O)/user/$*.tm

$(O)/fs.img: $(addprefix $(O)/bin/,$(UPROGS))
	$(MKFS) -fat $@ $^

run: $(O)/kernel.img $(O)/fs.img
	$(MACHINE) -d $(O)/fs.img $(O)/kernel.img

# the output of both, on fresh disks, against check.expected
check: $(O)/kernel.img $(O)/fs.img
	cp $(O)/fs.img $(O)/check.img
	echo t6tests | timeout 120 $(MACHINE) -d $(O)/check.img $(O)/kernel.img > $(O)/check.out
	cp $(O)/fs.img $(O)/check.img
	printf 'echo hi | cat > f; cat f; ls; wc < f; rm f; cat f\n' | timeout 120 $(MACHINE) -d $(O)/check.img $(O)/kernel.img >> $(O)/check.out
	rm -f $(O)/check.img
	diff check.expected $(O)/check.out && rm $(O)/check.out && echo "tiny-os t6: check ok"

clean:
	rm -rf $(O)

.PHONY: all run check clean
.SECONDARY:
