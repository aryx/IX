###############################################################################
# Prelude
###############################################################################

# The usual entry points; dune does the work (make, make test). Then
# ix built by ix (make ix, make test-ix...), and everything (make
# test-all): see below.

###############################################################################
# Main targets
###############################################################################

all:
	dune build

test: all
	./_build/default/builder/tests/Test.exe
	./tiny/tests/TinyBuildSystem_test.sh
	./_build/default/shell/tests/Test.exe
	./tiny/tests/TinyShell_test.sh
	./_build/default/editors/ed/tests/Test.exe
	./tiny/tests/TinyEditor_test.sh
	./linker/tests/golden.sh
	./generators/tests/tokens.sh
	./generators/tests/trees.sh
	./_build/default/database/tests/Test.exe
	./tiny/tests/TinyDatabase_test.sh 20
	./_build/default/languages/smalltalk/tests/Test.exe
	./_build/default/languages/scheme/tests/Test.exe
	./_build/default/languages/pascal/tests/Test.exe
	./_build/default/languages/prolog/tests/Test.exe
	./languages/prolog/tests/run.sh
	./languages/datalog/tests/run.sh
	./languages/c/facts/tests/run.sh
	./languages/ml/facts/tests/run.sh
	./editors/turbopascal/tests/keys.sh
	./_build/default/editors/emacs/tests/Test.exe
	./editors/emacs/tests/keys.sh
	./editors/emacs/tests/terminal.py
	./_build/default/examples/gui4/tests/Test.exe
	./_build/default/apps/office/tests/Test.exe
	./_build/default/lib_graphics/pdf/tests/Test.exe
	./apps/page/tests/frames.sh
	./_build/default/lib_graphics/images/tests/Test.exe
	./apps/office/tests/image.sh
	./lib_compression/tests/check.py 50
	./_build/default/lib_crypto/tests/Test.exe
	./_build/default/lib_networking/tests/Test.exe
	./networking/tests/served.sh
	./networking/tests/tls.sh
	./_build/default/browsers/html/tests/Test.exe
	./browsers/lynx/tests/session.sh
	./_build/default/browsers/javascript/tests/Test.exe
	./browsers/javascript/tests/scripts.sh
	./_build/default/browsers/css/tests/Test.exe
	./_build/default/browsers/engine/tests/Test.exe
	./browsers/engine/tests/boxes.sh
	./browsers/netscape/tests/frames.sh
	./_build/default/lib_crypto/tests/Vectors.exe | cmp - lib_crypto/tests/Vectors.expected
	./version_control/tests/objects.sh
	./version_control/tests/query.py 10
	./version_control/tests/session.py 10
	./version_control/tests/git9_tests.sh
	./version_control/tests/net.sh
	./tiny/tests/TinyVCS_test.sh 10
	./tiny/tests/TinyCPUArm_test.sh
	./tiny/tests/TinyMachinePi_test.sh
	./tiny/tests/TinyCPU_test.sh
	./tiny/tests/TinyMachine_test.sh
	./tiny/tests/TinyGraphics_test.sh
	./tiny/tests/TinyPlayground_test.sh
	./tiny/tests/TinyTetris_test.sh
	$(MAKE) -C tiny/tiny-os clean all
	$(MAKE) -C tiny/tiny-os/v6 check
	$(MAKE) -C tiny/tiny-os/t6 check
	$(MAKE) -C tiny/TinyKernel check
	./machine/tests/decode_check.py
	./machine/tests/decode_check.py --random 5000
	./machine/tests/decode_check.py -64
	./machine/tests/decode_check.py -64 --random 5000
	./machine/tests/decode_check.py -64fp --random 5000
	./machine/tests/decode_check.py machine/tests/words_arm_system.txt
	./machine/tests/decode_check.py -64 machine/tests/words_arm64_system.txt
	./machine/tests/random_blocks.py 3000 30
	./machine/tests/random_blocks.py -64 3000 30
	./machine/tests/random_blocks.py -vfp 1000 30
	./machine/tests/random_blocks.py -64fp 1000 30

# The mini- and tiny- programs in opam's bin, for the mkfiles (ix built
# by ix: mini-mk, then mkfiles/check.sh) and for use anywhere.
install: all
	dune install

# The website's machine (docs/t-ix.html; plan_web.md): tiny-machine by
# js_of_ocaml and the kernels' images, put in the assets' repository,
# which its own GitHub Pages serve (the playground's programs are there
# too): the page loads js/ix/TinyMachineWeb.bc.js and fetches
# ix/tiny-kernel/boot.img, or ix/v6/ and ix/t6/'s kernel.img and fs.img.
# Then, by hand: commit and push the assets first, the page after, so
# that no page points at a file not yet online.
ASSETS ?= $(HOME)/github/assets
website:
	set -e; d=$$(mktemp -d); trap "rm -rf $$d" EXIT; \
	for k in tiny-kernel v6 t6; do ./tiny-machine -web $$d/$$k $$k; mkdir -p $(ASSETS)/ix/$$k; done; \
	mkdir -p $(ASSETS)/js/ix; \
	install -m 644 $$d/tiny-kernel/TinyMachineWeb.js $(ASSETS)/js/ix/TinyMachineWeb.bc.js; \
	install -m 644 $$d/tiny-kernel/boot.img $(ASSETS)/ix/tiny-kernel/; \
	for k in v6 t6; do install -m 644 $$d/$$k/kernel.img $$d/$$k/fs.img $(ASSETS)/ix/$$k/; done
	@echo "website: $(ASSETS)/js/ix and $(ASSETS)/ix written (git -C $(ASSETS) status)"

clean:
	dune clean
	rm -rf _mk

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
	./tiny/tests/TinyAssembler_test.sh
	./tiny/tests/TinyC_test.sh
	./tiny/tests/TinyML_test.sh
	mkdir -p $(GOKEN_W)/tinyc32 && ./tiny/tests/TinyC_fuzz.py --32 $(GOKEN_W)/tinyc32 100 && ./tiny/tests/TinyC_test.sh $(GOKEN_W)/tinyc32/*.c
	./languages/c/tests/listing.sh 5 $(GOKEN_W)/listing5 $(HOME)/goken/tests/c/hello_libc/*.c languages/c/tests/c/*.c
	./languages/c/tests/listing.sh 7 $(GOKEN_W)/listing7 $(HOME)/goken/tests/c/hello_libc/*.c languages/c/tests/c/*.c
	./languages/c/tests/fuzz.sh $(GOKEN_W)/fuzz 150
	P9DIFF=$(GOKEN_W)/p9diff ./version_control/tests/diff_fuzz.py 500
	./machine/tests/corpus.py 5 $(GOKEN_W)/libc5/*/*.exe
	./machine/tests/corpus.py 7 $(GOKEN_W)/libc7/*/*.exe
	GOOS=plan9 H=-H2 ./linker/tests/libc.sh 5 $(GOKEN_W)/plan9_5 $(HOME)/goken/tests/c/hello_libc/*.c
	./machine/tests/plan9.py $(GOKEN_W)/plan9_5 $(GOKEN_W)/libc5

# The ML compilers against ocaml-light's ocamlopt for arm64 and arm
# (kernels/ocaml-light.sh arm64 and arm build them in
# /tmp/ix-ocaml-light-*), and goken: tiny-ml on random programs, their
# outputs recorded by ocamlopt, then compared (make test-goken compares
# the recorded ones; see tiny/tests/TinyML_fuzz.py); mini-ml's front end and
# type checker over the corpus (languages/ml/tests/), its programs
# (tests/tiny/, ocaml-light's test/, the random ones), on arm64 and, under
# qemu-arm, on arm, run and compared with ocamlopt's.
# (not Moretest/io.ml and patmatch.ml: there mini-ml is OCaml 4.14's and
# no longer ocaml-light's, an index out of bounds an exception and \b,
# \r in an escaped string, which tests/modern/stdlib.ml checks)
OCAML_LIGHT_TESTS = $(addprefix $(HOME)/ocaml-light/test/,fib.ml takc.ml taku.ml sieve.ml quicksort.ml soli.ml bdd.ml boyer.ml nucleic.ml KB Moretest/letstar.ml Moretest/bigints.ml Moretest/equality.ml Moretest/signals.ml Moretest/wc.ml Moretest/testrandom.ml)
test-ocaml: all
	mkdir -p $(GOKEN_W)/tinyml && ./tiny/tests/TinyML_fuzz.py $(GOKEN_W)/tinyml 100 && RECORD=1 ./tiny/tests/TinyML_test.sh $(GOKEN_W)/tinyml/*.ml
	mkdir -p $(GOKEN_W)/tinyml31 && ./tiny/tests/TinyML_fuzz.py --31 $(GOKEN_W)/tinyml31 100 && RECORD=1 ./tiny/tests/TinyML_test.sh $(GOKEN_W)/tinyml31/*.ml
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

###############################################################################
# All the tests
###############################################################################

# Everything: every suite of this file, one after the other, each in
# its log, a line for each and the list at the end; a suite whose
# references are not on this machine is skipped, and said. Half an hour.
# tests/all.sh -l lists them; tests/all.sh ix arm runs those two.
test-all:
	./tests/all.sh
# (the suites of a few minutes)
test-quick:
	./tests/all.sh -quick

# Under a minute, for a good confidence that nothing regressed: every
# family of programs by its fastest checks that mean something, all at
# once on the machine's cores (30 jobs): unit and differential tests,
# the linker's recorded bytes, every file of ix compiled by mini-ml and
# programs run, ix built by ix from nothing (under _mk/lite), then used:
# its toolchain against dune's, a kernel's step and mini-xv6 booted.
# tests/lite.sh says each job's seconds.
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
#   its tests, mini-git's objects and network tests (make test, test-ix).
test-lite:
	./tests/lite.sh

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

.PHONY: all install website test test-differential test-goken test-ocaml test-chidb test-pi clean loc loc-v build-docker build-docker-ocaml5 build-docker-test-all \
  test-ml ix ix-arm kernels-ix test-ix test-fixpoint test-arm test-fixpoint-arm test-kernels-ix test-all test-quick test-lite test-github visual visual-all
