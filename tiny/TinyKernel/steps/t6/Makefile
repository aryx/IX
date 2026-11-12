# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# t6, a free kernel in C, a step before TinyKernel.ml
# (docs/plans/done/plan_tiny_os.md):
#
#   make run          the kernel on tiny-machine, the disk fs.img: sh
#   make check        t6tests, and a script through sh, on a fresh disk
#
# The kernel: entry.s first (the machine starts at 0), then the C. The
# programs are tiny-ld's images (linked at 0: t6 runs each at the
# start of its partition), start.s first, with libc and
# sys.s; the disk is a FAT (tiny-mkfat -fat). The tools from the PATH
# (after `dune install`), or from ix's bin/.
#
# What is built goes to _make/ and nowhere else (as dune's _build and
# mini-mk's _mk): the kernel's assembly, its objects and kernel.img, user/*.s, bin/
# the programs, fs.img the disk; make clean removes it.

export PATH := $(abspath ../../../../bin):$(PATH)

TC = tiny-cc
AS = tiny-as
LD = tiny-ld
MACHINE = tiny-machine
MKFS = tiny-mkfat

O = _make
L = ../../../runtime
KERNEL = $(O)/entry.o $(O)/udivmod.o $(O)/main.o $(O)/proc.o $(O)/file.o
UPROGS = init sh cat echo ls mkdir rm wc t6tests
ULIB = $(O)/start.o $(O)/udivmod.o $(O)/libc.o $(O)/libc/sys.o

all: $(O)/kernel.img $(O)/fs.img

$(O)/%.o: %.c t6.h
	@mkdir -p $(@D)
	$(TC) -o $@ $<

# an object of assembly: of a .s here, or of the C runtime's (tiny-cc
# writes the C's objects; old: their .s, assembled by a rule here)
$(O)/%.o: %.s
	@mkdir -p $(@D)
	$(AS) -o $@ $<
$(O)/%.o: $(L)/%.s
	@mkdir -p $(@D)
	$(AS) -o $@ $<
.SECONDARY:

$(O)/kernel.img: $(KERNEL)
	$(LD) -o $@ $(KERNEL)

$(O)/libc.o: $(L)/libc.c $(L)/libc.h
	@mkdir -p $(@D)
	$(TC) -o $@ $<

$(O)/user/%.o: user/%.c libc/user.h
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
