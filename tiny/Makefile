# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Build and test t-IX from tiny/ itself, as ../Makefile's tix and test-tix
# targets (their names work here too):
#
#   make         the tiny programs by dune (from here dune builds tiny/
#                alone: a no-op is 0.6 s, the whole tree's 4 s)
#   make test    the shared jobs and t-IX's of make test-lite (a minute)
#   make run     tiny-kernel on tiny-machine, sh on the console
#                (dune first, for the tools; then TinyKernel/'s make run,
#                which builds the boot image)
#   make run-window  the same in a window (tiny-machine -window)
#   make self-quick  t-IX building a few of its own targets on
#                tiny-kernel, compared with the host's (3 minutes)
#   make self    t-IX building itself on tiny-kernel, the image the same
#                as the host's (about an hour; both TinyKernel/'s, and
#                O=dir builds in another directory than TinyKernel/_make)
#   make loc     t-IX's lines alone (../scripts/stats/loc.py -t: the
#                files git knows, those apart said at the end)
#
# The tiny programs built by ix are the mkfile's (mini-mk); tiny-kernel
# has its own Makefile (TinyKernel/: make run, make check).

# TinyKernel/'s targets, after dune has built the tools they use
KERNEL_TARGETS = run run-window self self-quick

all:
	dune build
test:
	../tests/lite.sh tix
$(KERNEL_TARGETS) self-tix self-quick-tix: all
	$(MAKE) -C TinyKernel $(@:-tix=)
loc:
	cd .. && scripts/stats/loc.py -t

tix: all
test-tix: test

.PHONY: all test $(KERNEL_TARGETS) loc tix test-tix self-tix self-quick-tix
