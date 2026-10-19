# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# v0, the first step before TinyKernel.ml: a page of kernel in
# tiny-machine's assembly, and four
# user programs linked with it (there is no loader):
#
#   make run          the image on tiny-machine
#   make listing      the image, listed
#
# The tools from the PATH (after `dune install`), or from ix's bin/.

export PATH := $(abspath ../../../../bin):$(PATH)

AS = tiny-assembler
LD = tiny-linker
MACHINE = tiny-machine

O = _make

all: $(O)/kernel.img

# the kernel first, at 0, then its programs, found by their labels
# (what is built goes to _make/)
$(O)/%.o: %.tm
	@mkdir -p $(@D)
	$(AS) -o $@ $<

$(O)/kernel.img: $(O)/kernel.o $(O)/a.o $(O)/b.o $(O)/c.o $(O)/d.o
	$(LD) -o $@ $^

run: $(O)/kernel.img
	$(MACHINE) $(O)/kernel.img

listing: $(O)/kernel.img
	$(MACHINE) -l $(O)/kernel.img

clean:
	rm -rf $(O)

.PHONY: all run listing clean
