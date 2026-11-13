# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# v0, the first step before TinyKernel.ml: a page of kernel in
# tiny-machine's assembly, and four user programs linked with it (there
# is no loader):
#
#   make run          runs the image on tiny-machine
#   make listing      lists the image
#
# The tools come from the PATH (after `dune install`), or from ix's bin/.

export PATH := $(abspath ../../../../bin):$(PATH)

AS = tiny-as
LD = tiny-ld
MACHINE = tiny-machine

O = _make

all: $(O)/kernel.img

# The kernel is linked first, at 0, then its programs, which it finds by
# their labels (what is built goes to _make/).
$(O)/%.o: %.s
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
