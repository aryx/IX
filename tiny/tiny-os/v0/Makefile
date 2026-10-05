# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# tiny-os v0: a page of kernel in tiny-machine's assembly, and four
# user programs linked with it (there is no loader):
#
#   make run          the image on tiny-machine
#   make listing      the image, listed
#
# The tools from the PATH (after `dune install`), or from ix's bin/.

export PATH := $(abspath ../../../bin):$(PATH)

MACHINE = tiny-machine

all: kernel.img

# the kernel first, at 0, then its programs, found by their labels
kernel.img: kernel.tm a.tm b.tm c.tm d.tm
	$(MACHINE) -o $@ $^

run: kernel.img
	$(MACHINE) kernel.img

listing: kernel.img
	$(MACHINE) -l kernel.img

clean:
	rm -f kernel.img

.PHONY: all run listing clean
