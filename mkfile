# Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyBuildSystem.ml)
#
# ix built by ix. Each directory has its own mkfile, which makes its
# library or its programs under _mk/; this one runs them, each after
# what it needs (docs/plans/plan_mkfiles.md).
#
#     mk                    on mini-9pi's card, in /src: every directory
#     mk libs               the libraries alone
#     mk install            the libraries where examples/ links them
#     mk self-quick         a part of lib_core and two programs, minutes
#     mini-mk MINI=mini-    on the host, for the host (arm64, Linux)
#     mini-mk MINI=mini- O=5 OS=plan9
#                           on the host, the card's build: the same
#                           directories, for the same files
#
# The tools are named as on the card (ml, cc, ld, mk...); MINI=mini-
# names the host's (mkfiles/mkconfig, which also says O, the machine,
# and OS, the system, when they are not given). NPROC is how many
# directories are built at once, and each directory's own jobs.
TOP=.
<mkfiles/mkconfig

# The libraries, then the directories of programs: those built for
# both systems, and each system's own. (PLATFORMS: the games' platforms,
# Linux's ppm, and on Plan 9 its draw device and a software one.)
PLATFORMS=`{if(~ $OS plan9) echo draw software; if not echo ppm}
#`
LIBS1=lib_mime lib_crypto lib_compression lib_executable lib_networking lib_graphics lib_playground \
 lib_playground/physics lib_playground/juice lib_gui lib_audio lib_playground/netcode lib_playground/ai \
 lib_playground/apis lib_playground/platforms ${PLATFORMS:%=lib_playground/platforms/%} \
 browsers/html browsers/css browsers/javascript browsers/engine browsers/webapi typesetting/troff
LIBS=lib_core $LIBS1
BOTH=linker linker/tools languages/c builder shell editors/ed generators/lex generators/yacc languages/ml \
 languages/scheme languages/pascal languages/prolog languages/dotnet languages/tiger typesetting/man \
 utilities/files utilities/misc utilities/namespace utilities/time utilities/pipe utilities/compare \
 utilities/process utilities/text utilities/byte utilities/archive utilities/calc/hoc utilities/calc/dc \
 utilities/calc/bc utilities/text/awk kernels/9pi/filesystems/user/dossrv \
 kernels/9pi/devices/storage/user/fdisk lib_graphics/tests windows/rio windows/rio/tests windows/desktop \
 apps/misc apps/files apps/maps profilers/misc games editors/drscheme apps/office
LINUX=database languages/datalog languages/forth languages/dotnet/csc editors/turbopascal/tty \
 editors/emacs/tty machine version_control kernels/tools debuggers/where debuggers/acid lib_gui/examples tiny \
 kernels/steps/step0 kernels/steps/step1 kernels/steps/step2 kernels/steps/step3
PLAN9=kernels/9pi/tests/hello kernels/9pi/tests/hog kernels/9pi/tests/tone kernels/9pi/tests/threads \
 kernels/9pi/tests/self lib_core/commons/tests kernels/9pi/buses/user/usbd apps/media/play \
 apps/music/rebirth languages/smalltalk languages/smalltalk/hosts/draw apps/page \
 editors/turbopascal/hosts/draw editors/emacs/draw networking browsers/lynx browsers/netscape

# (mkfiles/top.rc says DIRS, BOTH and the system's own; MORE, the games
# built again on Plan 9 for its software platform; and the libraries'
# order, a line for each from its mkfile's NEEDS, as
# lib_mime.dir:V: lib_core.dir)
# (mk makes the first target it reads: all, before those lines)
all:V: libs programs
<|. mkfiles/top.rc

libs:V: ${LIBS:%=%.dir}

programs:V: assembler.dir ${DIRS:%=%.dir} examples

# A directory is built by its own mk.
%.dir:V:
	cd $stem && $MK $ARGS

# What a directory waits for: the assembler for the libraries, since
# every tool reads its objects; a program for the libraries and the
# assembler; and five for another directory's objects.
assembler.dir:V: libs
${DIRS:%=%.dir}:V: libs assembler.dir
linker/tools.dir:V: linker.dir
utilities/calc/bc.dir:V: utilities/calc/dc.dir
editors/drscheme.dir lib_gui/examples.dir apps/office.dir:V: games.dir
languages/smalltalk/hosts/draw.dir:V: languages/smalltalk.dir

# install copies what a program links, the C library with its headers
# and each library of ML's with its units' interfaces, from where they
# are built to LIBDIR (mkfiles/install.rc says what goes where), as
# tiny/Buildfile's build install fills /lib: a program is then built
# with no source of ix's but its own. examples/ is built this way, here
# and in /examples on mini-9pi's card, whose /lib is this build's
# (kernels/9pi/Makefile); mk install LIBDIR=/lib fills it on the card.
# A library is copied when its archive is newer than the copy; a second
# mk compares them, once the libraries are built (the first one read
# their times before).
LIBDIR=$B/lib
install:V: libs
	$MK $ARGS 'LIBDIR='^$LIBDIR installed
installed:V: $LIBDIR/c/libc.a $LIBDIR/ml/lib_core/lib_core.a ${LIBS1:%=$LIBDIR/ml/%/lib.a}
$LIBDIR/c/libc.a: $L/libc.a
	$RC mkfiles/install.rc c
$LIBDIR/ml/lib_core/lib_core.a: $L/lib_core.a $L/std_exit.$O $L/runtime.$O
	$RC mkfiles/install.rc lib_core
$LIBDIR/ml/%/lib.a: $B/%/lib.a
	$RC mkfiles/install.rc $stem

# (LIB and D, where its programs go, as examples/ names them: this
# directory's ./_mk/7 is its ../_mk/7)
EXLIB=${LIBDIR:./%=.././%}
EXD=${B:./%=.././%}
examples:V: install
	cd examples && $MK $ARGS 'LIB='^$EXLIB 'D='^$EXD/examples

# make self-quick's build (kernels/9pi/tests/self.sh): lib_core's C
# library, its runtime and three units, then tests/self's two programs,
# one in C and one in OCaml, linked with those alone. It takes minutes
# on the card, where all of lib_core.a takes six.
self-quick:V:
	l=../_mk/$O-$OS/lib_core
	cd lib_core && $MK $ARGS $l/libc.a $l/runtime.$O $l/std_exit.$O $l/Stdlib.$O $l/List.$O $l/Printf.$O
	cd ../kernels/9pi/tests/self && $MK $ARGS

# depend makes every directory's .depend (mkfiles/mkdepend) again, in
# the directories whose mkfile includes mkprog, mklib, mkdepend or
# games/mkgames. Each build makes them when they are older than a
# source; use this target when in doubt.
depend:V:
	for(m in `{$WALK . | grep '/mkfile$' | grep -v -e '^\./_' -e '/\.claude/' | xargs grep -l -E -e '^<.*mkfiles/mk(prog|lib|depend)$' -e '^<.*games/mkgames$'}) {
		d=`{echo $m | sed 's,/[^/]*$,,'}
		if(! ~ $d .) @{cd $d && $MK $ARGS depend} || exit 1
	}

clean:V:
	rm -rf _mk
