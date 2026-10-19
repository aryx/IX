# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# t6, a free kernel in C, a step before TinyKernel.ml
# (docs/plans/done/plan_tiny_os.md):
#
#   make run          the kernel on tiny-machine, the disk fs.img: sh
#   make check        t6tests, and a script through sh, on a fresh disk
#
# The kernel: entry.tm first (the machine starts at 0), then the C. The
# programs are tiny-linker's images (linked at 0: t6 runs each at the
# start of its partition), start.tm first, with libc and
# sys.tm; the disk is a FAT (tiny-mkfs -fat). The tools from the PATH
# (after `dune install`), or from ix's bin/.
#
# What is built goes to _make/ and nowhere else (as dune's _build and
# mini-mk's _mk): the kernel's assembly, its objects and kernel.img, user/*.tm, bin/
# the programs, fs.img the disk; make clean removes it.

export PATH := $(abspath ../../../../bin):$(PATH)

TC = tiny-c
AS = tiny-assembler
LD = tiny-linker
MACHINE = tiny-machine
MKFS = tiny-mkfs

O = _make
L = ../../../TinyCRuntime
KERNEL = $(O)/entry.o $(O)/udivmod.o $(O)/main.o $(O)/proc.o $(O)/file.o
UPROGS = init sh cat echo ls mkdir rm wc t6tests
ULIB = $(O)/start.o $(O)/udivmod.o $(O)/libc.o $(O)/libc/sys.o

all: $(O)/kernel.img $(O)/fs.img

$(O)/%.tm: %.c t6.h
	@mkdir -p $(@D)
	$(TC) -o $@ $<

# an object: of a .tm made in _make/, of one here, or of the C runtime's
$(O)/%.o: $(O)/%.tm
	$(AS) -o $@ $<
$(O)/%.o: %.tm
	@mkdir -p $(@D)
	$(AS) -o $@ $<
$(O)/%.o: $(L)/%.tm
	@mkdir -p $(@D)
	$(AS) -o $@ $<
.SECONDARY:

$(O)/kernel.img: $(KERNEL)
	$(LD) -o $@ $(KERNEL)

$(O)/libc.tm: ../../../TinyCRuntime/libc.c ../../../TinyCRuntime/libc.h
	@mkdir -p $(@D)
	$(TC) -o $@ $<

$(O)/user/%.tm: user/%.c libc/user.h
	@mkdir -p $(@D)
	$(TC) -o $@ $<

$(O)/bin/%: $(ULIB) $(O)/user/%.o
	@mkdir -p $(@D)
	$(LD) -o $@ $(ULIB) $(O)/user/$*.o

$(O)/fs.img: $(addprefix $(O)/bin/,$(UPROGS))
	$(MKFS) $@ $^

run: $(O)/kernel.img $(O)/fs.img
	$(MACHINE) -d $(O)/fs.img $(O)/kernel.img

# the output of both, on fresh disks, against check.expected
check: $(O)/kernel.img $(O)/fs.img
	cp $(O)/fs.img $(O)/check.img
	echo t6tests | timeout 120 $(MACHINE) -d $(O)/check.img $(O)/kernel.img > $(O)/check.out
	cp $(O)/fs.img $(O)/check.img
	printf 'echo hi | cat > f; cat f; ls; wc < f; rm f; cat f\n' | timeout 120 $(MACHINE) -d $(O)/check.img $(O)/kernel.img >> $(O)/check.out
	rm -f $(O)/check.img
	diff check.expected $(O)/check.out && rm $(O)/check.out && echo "t6: check ok"

clean:
	rm -rf $(O)

.PHONY: all run check clean
.SECONDARY:
