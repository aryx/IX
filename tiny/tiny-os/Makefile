# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# tiny-os: an operating system for tiny-machine, built by the tiny
# tools as any program is built by its toolchain. A kernel per version,
# each in its directory with its Makefile (v0/: a page of assembly;
# v6/, xv6's kind of kernel, in C; t6/, its free variant: spawn, a
# FAT, one kernel stack), and what they share: the C
# runtime (libc/, a link to ../TinyC/libc/, tiny-c -tm's: start.tm,
# udivmod.tm, libc.c, libc.h), whose system calls are
# tiny-cpu's and the kernels'. Not TinyKernel.ml,
# mini-xv6 or mini-9pi, other projects of ix (docs/projects.md).
#
#   make run          v6 on tiny-machine: its shell, on the console
#   make run-v0       v0
#   make run-hello    hello.c, compiled by tiny-c -tm, on tiny-cpu
#
# The tools from the PATH (after `dune install`), or from ix's bin/. A
# C program is compiled to .tm by tiny-c -tm, then linked by tiny-cpu
# after the runtime: start.tm first (the machine starts at 0), udivmod.tm,
# libc.

export PATH := $(abspath ../../bin):$(PATH)

TC = tiny-c
CPU = tiny-cpu
VERSIONS = v0 v6 t6

O = _make

all: $(O)/hello
	for v in $(VERSIONS); do $(MAKE) -C $$v all || exit 1; done

# (what is built goes to _make/, here and in each version's directory)
$(O)/libc.tm: libc/libc.c libc/libc.h
	@mkdir -p $(@D)
	$(TC) -tm -o $@ $<

$(O)/hello.tm: hello.c libc/libc.h
	@mkdir -p $(@D)
	$(TC) -tm -o $@ hello.c

$(O)/hello: libc/start.tm libc/udivmod.tm $(O)/libc.tm $(O)/hello.tm
	$(CPU) -o $@ $^

run:
	$(MAKE) -C v6 run

run-v0:
	$(MAKE) -C v0 run

run-hello: $(O)/hello
	$(CPU) $(O)/hello one two

clean:
	rm -rf $(O)
	for v in $(VERSIONS); do $(MAKE) -C $$v clean; done

.PHONY: all run run-v0 run-hello clean
