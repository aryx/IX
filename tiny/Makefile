# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Build and test t-IX from tiny/ itself, as ../Makefile's tix, test-tix
# and self-tix targets do from the top:
#
#   make         builds the tiny programs with dune (from here, dune
#                builds tiny/ alone: a no-op takes 0.6 s, against 4 s
#                for the whole tree)
#   make test    runs the shared jobs of make test-lite and t-IX's own
#                (a minute)
#   make run     runs tiny-kernel on tiny-machine, with sh on the console
#                (dune runs first, for the tools; then TinyKernel/'s make
#                run, which builds the boot image)
#   make run-window  does the same in a window (tiny-machine -window)
#   make self-quick  has t-IX build a few of its own targets on
#                tiny-kernel, and compares them with the host's (3 minutes)
#   make self    has t-IX build itself on tiny-kernel, and checks that the
#                image is the same as the host's (about 50 minutes; both
#                targets are TinyKernel/'s, and O=dir builds in another
#                directory than TinyKernel/_make)
#   make check   checks t-IX's code with mini-analyze -caps, -dead, -bugs
#                and -exn, each against its recording (../Makefile's
#                check-tix, which builds the analyzer first; 20 s)
#   make loc     counts t-IX's lines alone (../scripts/stats/loc.py -t
#                counts the files git knows, and lists those set apart at
#                the end)
#   make clean   removes what the targets above wrote here: TinyKernel/'s
#                builds, the steps' builds, and tiny-build's digests
#                (dune's _build belongs to the whole tree, so
#                ../Makefile's clean removes it)
#
# The tiny programs that ix builds are built by the mkfile (mini-mk).
# tiny-kernel has its own Makefile (TinyKernel/: make run, make check).

# TinyKernel/'s targets, run after dune has built the tools they use
KERNEL_TARGETS = run run-window self self-quick

all:
	dune build
test:
	../tests/lite.sh tix
$(KERNEL_TARGETS): all
	$(MAKE) -C TinyKernel $@
check: all
	dune build ../analyzers/Main.exe
	$(MAKE) -C .. check-tix
loc:
	cd .. && scripts/stats/loc.py -t
clean:
	$(MAKE) -C TinyKernel clean
	$(MAKE) -C TinyKernel/steps clean
	find . -name .tiny-build -type f -exec rm -f {} +

.PHONY: all test $(KERNEL_TARGETS) check loc clean
