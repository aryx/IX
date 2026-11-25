# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Build and test t-IX from tiny/ itself, as ../Makefile's tix, test-tix
# and self-tix targets do from the top:
#
#   make         builds t-IX with its own tools, here, beside the sources:
#                make host, then tiny-build TINY=tiny- over the Buildfile,
#                as build in /src does under t-IX (the programs, the
#                kernel, and the manifests mini-analyze reads; 2 s, 1 s
#                when nothing changed)
#   make rc      any other target is the Buildfile's: tiny-build TINY=tiny-
#                rc, as build rc under t-IX (make boot.img, make depend)
#   make host    builds the tiny tools for the host with dune (from here,
#                dune builds tiny/ alone: a no-op takes 0.6 s, against 4 s
#                for the whole tree); a convenience, ix built by ix being
#                the way to build it
#   make test    runs the shared jobs of make test-lite and t-IX's own
#                (a minute)
#   make run     runs tiny-kernel on tiny-machine, with sh on the console
#                (make host first, for the tools; then TinyKernel/'s make
#                run, which builds the boot image)
#   make run-window  does the same in a window (tiny-machine -window)
#   make self-quick  has t-IX build a few of its own targets on
#                tiny-kernel, and compares them with the host's (25 s)
#   make self    has t-IX build itself on tiny-kernel, and checks that the
#                image is the same as the host's (6 minutes on the
#                author's Mac, about 30 on a Neoverse N1; both
#                targets are TinyKernel/'s, and O=dir builds in another
#                directory than TinyKernel/_make)
#   make check   checks t-IX's code with mini-analyze -caps, -dead, -bugs
#                and -exn, each against its recording (../Makefile's
#                check-tix, which builds the analyzer first; 20 s)
#   make loc     counts t-IX's lines alone (../scripts/stats/loc.py -t
#                counts the files git knows, and lists those set apart at
#                the end)
#   make clean   removes what the targets above wrote here: build clean's
#                files, TinyKernel/'s builds, the steps' builds, and
#                tiny-build's digests (dune's _build belongs to the whole
#                tree, so ../Makefile's clean removes it). To run after a
#                change to a tool, tiny-ml, tiny-as...: the digests are
#                of the recipes and the sources, not of the tools (t-IX
#                does not imitate m-IX's dependencies on its tools, for
#                simplicity)
#
# The tiny programs that ix builds are built by the mkfile (mini-mk).
# tiny-kernel has its own Makefile (TinyKernel/: make run, make check),
# which runs the same build here for its images.

# The tools by their names on the host, tiny-ml... (../bin is dune's),
# tiny-shell running the recipes
export PATH := $(abspath ../bin):$(PATH)
BUILD = tiny-build TINY=tiny- -j 32

# TinyKernel/'s targets, run after dune has built the tools they use
KERNEL_TARGETS = run run-window self self-quick

all: host TinyKernel/kfont.s
	$(BUILD)
# Any target not below is the Buildfile's. (.DEFAULT's prerequisites
# are not made, hence the make in its recipe.)
.DEFAULT:
	$(MAKE) host TinyKernel/kfont.s
	$(BUILD) $@
# The font's pixels, which the Buildfile takes as they are (in /src
# under t-IX): TinyKernel/Makefile's rule
TinyKernel/kfont.s: TinyKernel/fonts/plan9.font
	$(MAKE) -C TinyKernel kfont.s
host:
	dune build
test:
	../tests/lite.sh tix
$(KERNEL_TARGETS): host
	$(MAKE) -C TinyKernel $@
check: host
	dune build ../analyzers/Main.exe
	$(MAKE) -C .. check-tix
loc:
	cd .. && scripts/stats/loc.py -t
clean:
	$(MAKE) -C TinyKernel clean
	$(MAKE) -C TinyKernel/steps clean
	find . -name .tiny-build -type f -exec rm -f {} +

.PHONY: all host test $(KERNEL_TARGETS) check loc clean
