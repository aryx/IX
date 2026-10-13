# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The steps before TinyKernel.ml: what ran on tiny-cpu and tiny-machine
# before a kernel in ML did, kept as kernels/steps/ keeps m-ix's
# kernel's, each built by the tiny tools as any program is built by its
# toolchain:
#   hello.c   a C program on the bare CPU (tiny-cpu answers its calls);
#   v0/       a page of kernel in assembly: traps, a timer, round robin;
#   t6/       a kernel in C: spawn, a partition a process, a FAT on a
#             disk, one kernel stack (TinyKernel.ml has no disk). Six of
#             its programs are tiny-kernel's own (links to ../user/).
# They share the C runtime, ../../TinyCRuntime/ (tiny-c -tm's: start.tm,
# udivmod.tm, libc.c, libc.h), whose system calls are tiny-cpu's and
# the kernels'. Not counted in t-ix's lines (make loc).
# (old: tiny/TinyKernel/steps/, with v6/, xv6's structure and names in C, 3,400
# lines: a faithful twin, which mini-xv6 is in m-ix, kernels/xv6/;
# removed on 2026-10-13, in git's history before)
#
#   make run          t6 on tiny-machine: its shell, on the console
#   make run-v0       v0
#   make run-hello    hello.c, compiled by tiny-c -tm, on tiny-cpu
#
# The tools from the PATH (after `dune install`), or from ix's bin/. A
# C program is compiled to .tm by tiny-c -tm, then linked by tiny-cpu
# after the runtime: start.tm first (the machine starts at 0), udivmod.tm,
# libc.

export PATH := $(abspath ../../../bin):$(PATH)

TC = tiny-c
CPU = tiny-cpu
VERSIONS = v0 t6
L = ../../TinyCRuntime

O = _make

all: $(O)/hello
	for v in $(VERSIONS); do $(MAKE) -C $$v all || exit 1; done

# (what is built goes to _make/, here and in each version's directory)
$(O)/libc.tm: $(L)/libc.c $(L)/libc.h
	@mkdir -p $(@D)
	$(TC) -tm -o $@ $<

$(O)/hello.tm: hello.c $(L)/libc.h
	@mkdir -p $(@D)
	$(TC) -tm -o $@ hello.c

$(O)/hello: $(L)/start.tm $(L)/udivmod.tm $(O)/libc.tm $(O)/hello.tm
	$(CPU) -o $@ $^

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
