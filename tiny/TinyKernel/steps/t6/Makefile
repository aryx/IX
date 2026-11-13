# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# t6, a free kernel in C, a step before TinyKernel.ml
# (docs/plans/done/plan_tiny_os.md):
#
#   make run          runs the kernel on tiny-machine, with the disk
#                     fs.img, and sh
#   make check        runs t6tests, and a script through sh, on a fresh disk
#
# The kernel is entry.s first (the machine starts at 0), then the C. The
# programs are tiny-ld's images (linked at 0, because t6 runs each one
# at the start of its partition), with start.s first, then libc and
# sys.s. The disk is a FAT (tiny-mkfat). The tools come from the PATH
# (after `dune install`), or from ix's bin/.
#
# What is built goes to _make/ and nowhere else (as with dune's _build
# and mini-mk's _mk): the kernel's objects and kernel.img, user/*.o,
# bin/ with the programs, and fs.img, the disk. make clean
# removes it.

export PATH := $(abspath ../../../../bin):$(PATH)

TC = tiny-cc
AS = tiny-as
LD = tiny-ld
MACHINE = tiny-machine
MKFS = tiny-mkfat

O = _make
L = ../../../runtime/c
KERNEL = $(O)/entry.o $(O)/udivmod.o $(O)/main.o $(O)/proc.o $(O)/file.o
UPROGS = init sh cat echo ls mkdir rm wc t6tests
ULIB = $(O)/start.o $(O)/udivmod.o $(O)/libc.o $(O)/libc/sys.o

all: $(O)/kernel.img $(O)/fs.img

$(O)/%.o: %.c t6.h
	@mkdir -p $(@D)
	$(TC) -o $@ $<

# An object of assembly, from a .s here or from the C runtime's (tiny-cc
# writes the objects of the C files itself).
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

# The output of both, each run on a fresh disk, is compared with
# check.expected.
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
