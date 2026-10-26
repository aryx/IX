###############################################################################
# Prelude
###############################################################################

# The usual entry points; dune does the work (make, make test: before
# each commit, two minutes; docs/testing.md). Then ix built by
# ix (make ix, make test-ix...), and everything (make test-all): see
# below.

###############################################################################
# Main targets
###############################################################################

# (the mkfiles' recipes are rc's, mini-rc's: mkfiles/mkconfig)
export MKSHELL = mini-rc
all:
	dune build
# t-IX alone (tiny/), or m-IX (the rest), as test-tix and test-mix: a
# no-op is 0.6 s and 3 where make's is 4 (dune checks every rule of
# what it builds, each time)
tix:
	dune build ./tiny
MIX_DIRS = $(filter-out tiny/ docs/ bin/ _%, $(wildcard */))
mix:
	dune build $(MIX_DIRS:%/=./%)

# The mini- and tiny- programs in opam's bin, for the mkfiles (ix built
# by ix: mini-mk, then mkfiles/check.sh) and for use anywhere.
install: all
	dune install

clean:
	dune clean
	rm -rf _mk

# (tiny-c and tiny-ml on random programs, against the host's cc and
# OCaml, in $(TINY_W); see tiny/tests/TinyC_fuzz.py and TinyML_fuzz.py)
TINY_W = /tmp/ix-tiny
# make test is the gate, make test-lite (below). make test-long: the
# long forms of what the gate runs short, one after the other,
# test-all's suite long: the random tests' full counts, tiny-c's and
# tiny-ml's fuzzers, tiny-kernel's steps and its whole check (26
# sessions, its screens and sounds), the decoders' random words and
# their system instructions (docs/plans/plan_tests.md)
test: test-lite
test-long: all
	./tiny/tests/TinyDatabase_test.sh 20
	./version_control/tests/query.py 10
	./version_control/tests/session.py 10
	./tiny/tests/TinyVCS_test.sh 10
	./tiny/tests/TinyCPU_test.sh
	mkdir -p $(TINY_W)/c && ./tiny/tests/TinyC_fuzz.py --32 $(TINY_W)/c 30 && RECORD=1 ./tiny/tests/TinyC_test.sh $(TINY_W)/c/*.c
	mkdir -p $(TINY_W)/ml && ./tiny/tests/TinyML_fuzz.py --31 $(TINY_W)/ml 30 && RECORD=1 ./tiny/tests/TinyML_test.sh $(TINY_W)/ml/*.ml
	$(MAKE) -C tiny/TinyKernel/steps clean all
	$(MAKE) -C tiny/TinyKernel/steps/t6 check
	$(MAKE) -C tiny/TinyKernel check
	./machine/tests/decode_check.py --random 5000
	./machine/tests/decode_check.py -64 --random 5000
	./machine/tests/decode_check.py -64fp --random 5000
	./machine/tests/decode_check.py machine/tests/words_arm_system.txt
	./machine/tests/decode_check.py -64 machine/tests/words_arm64_system.txt
	./machine/tests/random_blocks.py 3000 30
	./machine/tests/random_blocks.py -64 3000 30
	./machine/tests/random_blocks.py -vfp 1000 30
	./machine/tests/random_blocks.py -64fp 1000 30

# The website's machine (docs/t-ix.html; plan_web.md): tiny-machine by
# js_of_ocaml and the kernels' images, put in the assets' repository,
# which its own GitHub Pages serve (the playground's programs are there
# too): the page loads js/ix/TinyMachineWeb.bc.js and fetches
# ix/tiny-kernel/boot.img (and, as the other end of the machine's wire,
# ix/tiny-kernel/www/'s documents), or ix/t6/'s kernel.img and fs.img.
# Then, by hand: the number after ?v= in docs/t-ix.html changed (a
# browser keeps the program it has otherwise), the assets committed and
# pushed first, the page after, so that no page points at a file not
# yet online.
ASSETS ?= $(HOME)/github/assets
website:
	set -e; d=$$(mktemp -d); trap "rm -rf $$d" EXIT; \
	for k in tiny-kernel t6; do ./tiny-machine -web $$d/$$k $$k; mkdir -p $(ASSETS)/ix/$$k; done; \
	mkdir -p $(ASSETS)/js/ix; \
	install -m 644 $$d/tiny-kernel/TinyMachineWeb.js $(ASSETS)/js/ix/TinyMachineWeb.bc.js; \
	install -m 644 $$d/tiny-kernel/boot.img $(ASSETS)/ix/tiny-kernel/; \
	mkdir -p $(ASSETS)/ix/tiny-kernel/www; install -m 644 $$d/tiny-kernel/www/* $(ASSETS)/ix/tiny-kernel/www/; \
	install -m 644 $$d/t6/kernel.img $$d/t6/fs.img $(ASSETS)/ix/t6/
	$(MAKE) website-mini
	@echo "website: $(ASSETS)/js/ix and $(ASSETS)/ix written (git -C $(ASSETS) status)"

# m-IX's page (docs/m-ix.html; plan_web.md, stage 1): mini-qemu's board
# compiled to JavaScript (raspberry/web: release, the whole program
# compiled at once), mini-9pi's kernel built for a page (ix-web: with
# mini-usbd in it; the emulator moves its bytes) and its SD
# card, both by gzip (the page undoes it; -n: no date in them, the same
# bytes for the same files, since every new card is 13 MB more in the
# assets' history). The same by hand after it: ?v= in docs/m-ix.html.
# (website-mini-js: the board's JavaScript alone, when only the emulator
# changed: the card is not written again)
website-mini-js:
	dune build --profile release ./raspberry/web/MiniQemuWeb.bc.js 2> /dev/null
	mkdir -p $(ASSETS)/js/ix
	install -m 644 _build/default/raspberry/web/MiniQemuWeb.bc.js $(ASSETS)/js/ix/
website-mini: website-mini-js
	kernels/ocaml-light.sh arm > /dev/null
	$(MAKE) -C kernels/9pi BOARD=pi1 ix-web card > /dev/null
	mkdir -p $(ASSETS)/ix/mini-9pi
	gzip -9 -n -c kernels/9pi/kernel-pi1-web.img > $(ASSETS)/ix/mini-9pi/kernel.img.gz
	gzip -9 -n -c kernels/9pi/build/card.img > $(ASSETS)/ix/mini-9pi/card.img.gz

###############################################################################
# Tests against the references
###############################################################################

# The same corpus through plan9port (9base) mk and xix's omk too, when
# they are installed; see builder/tests/differential.sh.
test-differential: all
	./builder/tests/differential.sh live

# The toolchain against goken (~/goken, built, with its libcs): C
# programs with its libc, byte for byte and run; see linker/tests/
# (golden.sh record re-records the fixtures' bytes from goken). The
# compiler's listings against 5c -O0's and 7c -O0's, on the corpus, on
# languages/c/tests/c/ and on random programs; see languages/c/tests/ (and
# MINICC=1 linker/tests/libc.sh for the executables mini-cc and mini-ld
# make).
GOKEN_W = /tmp/ix-goken
test-goken: all
	./linker/tests/libc.sh 5 $(GOKEN_W)/libc5 $(HOME)/goken/tests/c/hello_libc/*.c
	./linker/tests/libc.sh 7 $(GOKEN_W)/libc7 $(HOME)/goken/tests/c/hello_libc/*.c
	./languages/c/tests/listing.sh 5 $(GOKEN_W)/listing5 $(HOME)/goken/tests/c/hello_libc/*.c languages/c/tests/c/*.c
	./languages/c/tests/listing.sh 7 $(GOKEN_W)/listing7 $(HOME)/goken/tests/c/hello_libc/*.c languages/c/tests/c/*.c
	./languages/c/tests/fuzz.sh $(GOKEN_W)/fuzz 150
	P9DIFF=$(GOKEN_W)/p9diff ./version_control/tests/diff_fuzz.py 500
	./machine/tests/corpus.py 5 $(GOKEN_W)/libc5/*/*.exe
	./machine/tests/corpus.py 7 $(GOKEN_W)/libc7/*/*.exe
	GOOS=plan9 H=-H2 ./linker/tests/libc.sh 5 $(GOKEN_W)/plan9_5 $(HOME)/goken/tests/c/hello_libc/*.c
	./machine/tests/plan9.py $(GOKEN_W)/plan9_5 $(GOKEN_W)/libc5

# mini-ml against ocaml-light's ocamlopt for arm64 and arm
# (kernels/ocaml-light.sh arm64 and arm build them in
# /tmp/ix-ocaml-light-*), and goken: its front end and type checker
# over the corpus (languages/ml/tests/), its programs (tests/tiny/,
# ocaml-light's test/, random ones of tiny/tests/TinyML_fuzz.py), on
# arm64 and, under qemu-arm, on arm, run and compared with ocamlopt's.
# (not Moretest/io.ml and patmatch.ml: there mini-ml is OCaml 4.14's and
# no longer ocaml-light's, an index out of bounds an exception and \b,
# \r in an escaped string, which tests/modern/stdlib.ml checks)
OCAML_LIGHT_TESTS = $(addprefix $(HOME)/ocaml-light/test/,fib.ml takc.ml taku.ml sieve.ml quicksort.ml soli.ml bdd.ml boyer.ml nucleic.ml KB Moretest/letstar.ml Moretest/bigints.ml Moretest/equality.ml Moretest/signals.ml Moretest/wc.ml Moretest/testrandom.ml)
test-ocaml: all
	mkdir -p $(GOKEN_W)/tinyml && ./tiny/tests/TinyML_fuzz.py $(GOKEN_W)/tinyml 100
	./languages/ml/tests/corpus.sh
	./languages/ml/tests/types.sh
	./languages/ml/tests/run.sh 7 $(GOKEN_W)/ml7 languages/ml/tests/tiny/*.ml languages/ml/tests/runtime/*.ml
	LIVE=1 ./languages/ml/tests/run.sh 7 $(GOKEN_W)/ml7 $(OCAML_LIGHT_TESTS)
	LIVE=1 ./languages/ml/tests/run.sh 5 $(GOKEN_W)/ml5 $(addprefix languages/ml/tests/tiny/,arith.ml closures.ml compare.ml exceptions.ml gc.ml lists.ml loops.ml strings.ml variants.ml)
	LIVE=1 ./languages/ml/tests/run.sh 7 $(GOKEN_W)/ml7 $(GOKEN_W)/tinyml/*.ml

# The database against chidb (~/github/chidb, built): the course's
# .dbmf cases (in make test too, when chidb's checkout is there), the
# SQL corpus (stdout, stderr, the file, and SQLite reading it), the
# B-trees alone, and random sessions; see database/tests/.
test-chidb: all
	./_build/default/database/tests/Test.exe
	./database/tests/differential.sh
	./database/tests/btree_differential.sh
	./database/tests/fuzz.py 1 40

# mini-ml on today's OCaml: tests/modern/, each program run by OCaml and
# by mini-ml's executable (arm64), the same output; every file of ix
# compiled (compile_ix.sh); the preprocessor. (true |: a test asks
# whether its input is a file.)
test-ml: all
	true | ./languages/ml/tests/modern.sh
	./languages/ml/tests/compile_ix.sh
	./languages/ml/tests/pp.sh

# mini-qemu against QEMU (plan_pi.md): 9pi's session, the Pi1 xv6
# ports' boots and graphics, the Pi4's boot and 16 of usertests' tests
# (on a copy of xv6 with 4MB of RAM, fast: xv6_pi4.py), and 3 on its
# four cores; mini-xv6's steps (kernels/test.sh: OCaml bare-metal on the
# Pi1, under mini-qemu and QEMU; ocaml-light cross-built once); needs
# ~/principia, ~/xv6 and the QEMUs (see raspberry/tests/). With
# XV6_USERTESTS=-u, the Pi1 ports' full usertests too.
# (side by side: tests/pi.sh, which has the list)
test-pi: all
	./tests/pi.sh $(XV6_USERTESTS)

# Speed regressions: the build when nothing changed (mini-9pi's
# programs, the top mini-mk) and a game's frames a second on mini-9pi
# under QEMU, each against a limit from the author's machine, the only
# one they are for; each measure added to tests/speed_history.txt.
test-speed:
	./tests/speed.sh

# mini-git over the Internet: ix cloned from GitHub by mini-git (https,
# through curl), checked by git fsck and walk.
test-github: all
	rm -rf /tmp/ix-github && ./_build/default/version_control/Main.exe clone https://github.com/aryx/IX /tmp/ix-github
	git --git-dir=/tmp/ix-github/.git fsck --strict
	cd /tmp/ix-github && $(CURDIR)/_build/default/version_control/Main.exe walk -q

###############################################################################
# ix built by ix
###############################################################################

# ix built by ix (docs/plans/plan_mkfiles.md): mini-mk over the
# mkfiles, with the programs dune built (./bin) the first time; what is
# made is under _mk/7 (arm64) and _mk/5 (arm). No OCaml from INRIA, no
# gcc, no GNU binutils in it: mini-ml, mini-lex, mini-yacc, mini-cc,
# mini-asm, mini-ar, mini-ld.
IXPATH = PATH=$(CURDIR)/bin:$$PATH
ix: all
	$(IXPATH) mini-mk
ix-arm: all
	$(IXPATH) mini-mk O=5
# the kernels by ix's tools, for the Pi 4 (docs/plans/plan_kernel_mini_ml.md;
# they take xv6's disk image and principia's programs, as their Makefiles)
kernels-ix: ix ix-arm
	cd kernels/xv6 && $(IXPATH) mini-mk && $(IXPATH) mini-mk O=5
	cd kernels/9pi && $(IXPATH) mini-mk && $(IXPATH) mini-mk O=5

# What ix built by ix is checked by:
# - test-ix: each program against dune's build of it (the toolchain's
#   output byte for byte, the others' differential tests), the tiny
#   programs' tests, the kernels' steps and mini-xv6 booted under
#   mini-qemu and QEMU (mkfiles/check.sh)
# - test-fixpoint: ix built twice, by dune's programs then by the first
#   build's alone: the same files (mkfiles/fixpoint.sh)
# - test-arm: the arm programs, under qemu-arm (mkfiles/check_arm.sh);
#   test-fixpoint-arm: ix for arm built again by them, twice
# - test-kernels-ix: mini-xv6's and mini-9pi's checks, on the Pi 4
# - self: ix built by ix in its own system, t-ix in tiny-kernel and
#   m-ix in mini-9pi (the Pi 2 under QEMU), side by side, each file the
#   host's (tiny/TinyKernel's make self, kernels/9pi's); hours.
#   self-quick: a part of each, a few minutes
test-ix: all
	true | ./mkfiles/check.sh
test-fixpoint: all
	./mkfiles/fixpoint.sh
test-arm: all
	true | ./mkfiles/check_arm.sh
test-fixpoint-arm: all
	./mkfiles/fixpoint.sh 5
test-kernels-ix: all
	./tests/kernels_ix.sh

self self-quick:
	$(MAKE) --no-print-directory -j2 $@-tix $@-mix
self-tix self-quick-tix: all
	$(MAKE) -C tiny/TinyKernel $(@:-tix=)
self-mix self-quick-mix: all
	$(MAKE) -C kernels/9pi $(@:-mix=)

###############################################################################
# All the tests
###############################################################################

# Everything: every suite of this file, one after the other, each in
# its log, a line for each and the list at the end; a suite whose
# references are not on this machine is skipped, and said. Half an hour.
# tests/all.sh -l lists them; tests/all.sh ix arm runs those two.
test-all:
	./tests/all.sh

# Under two minutes, before each commit, for a good confidence that
# nothing regressed (docs/plans/plan_tests.md): every family of programs
# by its fastest checks that mean something, all at once on the
# machine's cores (about 120 jobs): unit and differential tests, the
# linker's recorded bytes, every file of ix compiled by mini-ml and
# programs run, tiny-kernel booted, ix built by ix from nothing (in the
# run's own directory: runs of several sessions at once), then used:
# its toolchain against dune's, its programs' tests, a kernel's step and
# mini-xv6 booted. tests/lite.sh says each job's seconds, a line a group
# and the jobs past the budget.
# test-tix, test-mix: one system's jobs alone, for a change in it (and
# the shared ones: OCaml 5's types, the sources as text, lib_core by
# mini-ml); t-ix about a minute.
#
# What it leaves out, on purpose (make test-all has them all):
# - what needs a reference outside the repository: goken's toolchain
#   (test-goken), ocaml-light's ocamlopt (test-ocaml), chidb
#   (test-chidb), plan9port's mk (test-differential), QEMU and the C
#   kernels (test-pi; mini-xv6 here is booted under mini-qemu only);
# - arm: ix built for arm and run under qemu-arm (test-arm,
#   test-fixpoint-arm);
# - the fixed point: ix built again by the build it just made
#   (test-fixpoint); here the first build is made, and used;
# - mini-9pi by ix, and mini-xv6's whole check (the session, the screen,
#   USB, usertests: test-kernels-ix): here mini-xv6 only boots to sh;
# - the long forms of what it has: the random tests' full counts, the
#   rest of tests/modern/, each tiny program built by ix run through
#   its tests (make test-long, test-ix).
test-lite:
	./tests/lite.sh
test-tix:
	./tests/lite.sh tix
test-mix:
	./tests/lite.sh mix
# git commit's guard (tests/guard.sh, a pre-commit hook): the files left
# out of a commit in the directories it touches, said; once per clone
hooks:
	git config core.hooksPath tests/hooks

###############################################################################
# Docker
###############################################################################

# Build and test in a fresh Ubuntu, as GitHub Actions does
# (.github/workflows/docker.yml): the short tests (make test-lite).
# build-docker-test-all: the whole suite there (make test-all, half an hour), what
# GitHub Actions runs as its backup; an arm64 machine.
build-docker:
	docker build -t "ix" .

build-docker-ocaml5:
	docker build -t "ix" --build-arg OCAML_VERSION=5.5.1 .

build-docker-test-all:
	docker build --progress=plain -t "ix-all" --build-arg TESTS=all .

###############################################################################
# Developer targets
###############################################################################

# Lines of OCaml, C and assembly, per mini program, tiny program and library
# (scripts/stats/loc.py; -v: each subdirectory, each tests/, ...). Its
# last lines: what is not counted, the alternatives and the optional
# (compat/, opti/, the kernel's steps and reference build, the
# systems of kernels/ other than mini-9pi and mini-xv6, mini-smalltalk):
# their sum and each one's lines (-v: a row each, with why).
# docs/loc.md is the log of its last numbers: scripts/stats/loc.py -l
# prints today's line.
loc:
	scripts/stats/loc.py
loc-v:
	scripts/stats/loc.py -v

# See https://github.com/aryx/codemap and https://github.com/aryx/fork-efuns
visual:
	codemap -screen_size 3 -filter semgrep -efuns_client efuns_client -emacs_client /dev/null .
visual-all:
	codemap -screen_size 3                 -efuns_client efuns_client -emacs_client /dev/null .

.PHONY: all tix mix install website website-mini website-mini-js test test-differential test-goken test-ocaml test-chidb test-pi clean loc loc-v build-docker build-docker-ocaml5 build-docker-test-all \
  test-ml ix ix-arm kernels-ix test-ix test-fixpoint test-arm test-fixpoint-arm test-kernels-ix self self-quick self-tix self-quick-tix self-mix self-quick-mix test-all test-lite test-tix test-mix hooks test-long test-github visual visual-all
