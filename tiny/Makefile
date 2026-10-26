# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# t-IX from tiny/, as ../Makefile's tix and test-tix (their names work
# here too):
#
#   make         the tiny programs by dune (from here dune builds tiny/
#                alone: a no-op is 0.6 s, the whole tree's 4)
#   make test    the shared jobs and t-IX's of make test-lite, a minute
#
# The tiny programs built by ix are the mkfile's (mini-mk); tiny-kernel
# has its own Makefile (TinyKernel/: make run, make check).

all:
	dune build
test:
	../tests/lite.sh tix

tix: all
test-tix: test

.PHONY: all test tix test-tix
