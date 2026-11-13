# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The steps before TinyKernel.ml: what ran on tiny-cpu and tiny-machine
# before a kernel in ML did. They are kept as kernels/steps/ keeps the
# steps of m-ix's kernel, and each is built by the tiny tools as any
# program is built by its toolchain:
#   hello.c   a C program on the bare CPU (tiny-cpu answers its calls);
#   v0/       a page of kernel in assembly: traps, a timer, round robin;
#   t6/       a kernel in C: spawn, a partition for each process, a FAT
#             on a disk, one kernel stack (TinyKernel.ml has its own
#             file system, KFS.ml). Its nine programs are in t6/user/.
# They share the C runtime, ../../runtime/c/ (tiny-cc's: start.s,
# udivmod.s, libc.c, libc.h), whose system calls are those of tiny-cpu
# and of the kernels. The steps are not counted in t-ix's lines (make
# loc).
#
#   make run          runs t6 on tiny-machine, with its shell on the console
#   make run-v0       runs v0
#   make run-hello    runs hello.c, compiled by tiny-cc, on tiny-cpu
#
# The tools come from the PATH (after `dune install`), or from ix's
# bin/. A C program is compiled to its object by tiny-cc, then linked by
# tiny-ld after the runtime: start.s first (the machine starts at 0),
# then udivmod.s and libc.

export PATH := $(abspath ../../../bin):$(PATH)

TC = tiny-cc
AS = tiny-as
LD = tiny-ld
CPU = tiny-cpu
VERSIONS = v0 t6
L = ../../runtime/c

O = _make

all: $(O)/hello
	for v in $(VERSIONS); do $(MAKE) -C $$v all || exit 1; done

# (what is built goes to _make/, here and in each version's directory)
$(O)/libc.o: $(L)/libc.c $(L)/libc.h
	@mkdir -p $(@D)
	$(TC) -o $@ $<

$(O)/hello.o: hello.c $(L)/libc.h
	@mkdir -p $(@D)
	$(TC) -o $@ hello.c

$(O)/%.o: $(L)/%.s
	@mkdir -p $(@D)
	$(AS) -o $@ $<
.SECONDARY:

$(O)/hello: $(O)/start.o $(O)/udivmod.o $(O)/libc.o $(O)/hello.o
	$(LD) -o $@ $^

run:
	$(MAKE) -C t6 run

run-v0:
	$(MAKE) -C v0 run

run-hello: $(O)/hello
	$(CPU) $(O)/hello one two

clean:
	rm -rf $(O)
	for v in $(VERSIONS); do $(MAKE) -C $$v clean; done

.PHONY: all run run-v0 run-hello clean
