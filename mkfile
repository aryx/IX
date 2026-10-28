# ix built by ix: mini-mk here, after make install (or with
# PATH=$PWD/bin:$PATH). The libraries first, then each program;
# what is made is under _mk/ (docs/plans/plan_mkfiles.md).
# mini-mk O=5: for arm (the programs, and the kernels' steps for the Pi 1;
# O=7's are the Pi 4's)
# (O and OS: mkconfig's, 7 and linux, or on Plan 9 its own)
TOP=.
<mkfiles/mkconfig
DIRS=lib_core assembler linker linker/tools languages/c database builder shell editors/ed \
 generators/lex generators/yacc languages/ml languages/scheme languages/pascal languages/prolog languages/datalog languages/forth editors/turbopascal/tty editors/emacs/tty machine version_control kernels/tools \
 typesetting/troff typesetting/man utilities/files utilities/misc utilities/namespace utilities/time utilities/pipe utilities/compare utilities/process utilities/text utilities/byte utilities/calc/hoc utilities/calc/dc utilities/calc/bc utilities/text/awk kernels/9pi/filesystems/user/dossrv kernels/9pi/devices/storage/user/fdisk lib_graphics/tests windows windows/tests apps/misc profilers/misc games editors/drscheme examples tiny
KERNELS=kernels/steps/step0 kernels/steps/step1 kernels/steps/step2 kernels/steps/step3

# The libraries first, side by side in waves (libs: below), each after
# the ones it needs (xix's and principia's top mkfiles: a directory
# then takes the libraries as they are, a stale one built again from
# here; mini-mk libs: the libraries alone), and the assembler (the others read its
# objects), then the rest side by side, each directory a mini-mk; the
# two that take another's objects after it (mini-ar the linker's,
# mini-bc mini-dc's machine, and the
# playground's programs of apps/ and examples/ the games' libraries: games/mkgames). NPROC is each mini-mk's own jobs.
# (old: one directory after the other, 3 minutes:
#   for d in $DIRS; do (cd $d && mini-mk O=$O) || exit 1; done
#   if [ $O = 7 ]; then for d in $KERNELS; do (cd $d && mini-mk) || exit 1; done; fi)
# (the machine's cores, 16 at most: there are as many directories at
# once; on Plan 9 a line of /dev/sysstat each)
NPROC=`{if(~ $#objtype 0) nproc | awk '{print ($1 > 16 ? 16 : $1)}'; if not wc -l < /dev/sysstat}
# (OS=plan9: mini-9pi's, kernels/9pi's Makefile; its games' two
# platforms, the draw device's and the software one, where Linux's is
# ppm)
PLATFORMS=`{if(~ $OS plan9) echo draw software; if not echo ppm}
LIBS=lib_core lib_crypto lib_compression lib_networking lib_graphics lib_playground lib_physics lib_juice lib_gui lib_audio \
 lib_networking/netcode lib_ai lib_playground/apis lib_playground/platforms ${PLATFORMS:%=lib_playground/platforms/%} \
 browsers/html browsers/css browsers/javascript browsers/engine browsers/webapi typesetting/troff
FIRST=$LIBS assembler
AFTER=linker/tools utilities/calc/dc utilities/calc/bc games editors/drscheme examples apps/office
all:V: libs
	@{cd assembler && $MK 'O='$O} || exit 1
	pids=()
	for(d in $DIRS) if(! ~ $d $FIRST $AFTER){ @{cd $d && $MK 'O='$O} & pids=($pids $apid) }
	@{cd linker && $MK 'O='$O && cd tools && $MK 'O='$O} & pids=($pids $apid)
	@{cd utilities/calc/dc && $MK 'O='$O && cd ../bc && $MK 'O='$O} & pids=($pids $apid)
	@{cd games && $MK 'O='$O && cd ../editors/drscheme && $MK 'O='$O && cd ../../examples && $MK 'O='$O && cd ../apps/office && $MK 'O='$O} & pids=($pids $apid)
	for(d in $KERNELS){ @{cd $d && $MK 'O='$O} & pids=($pids $apid) }
	for(p in $pids){ wait $p; ~ $status '' || exit 1 }

# (B given on when it was said, as games/mkfile does: tests/lite.sh's
# _mk/lite, where each library's own mkconfig would say _mk/$O)
# lib_core, then in waves: each library whose NEEDS (its mkfile's) are
# made, side by side, then the next (troff beside the browser's chain;
# 25 s to 13 for tests/lite.sh's). A library its NEEDS name not in LIBS,
# or a cycle: no wave, said, not a loop.
# old: one after the other, in LIBS's order:
#   for(d in $LIBS) @{cd $d && $MK 'O='$O 'OS='$OS $b} || exit 1
libs:V:
	b=(); if(~ $B /*) b='B='^$B
	@{cd lib_core && $MK 'O='$O 'OS='$OS $b} || exit 1
	made=lib_core
	todo=()
	for(d in $LIBS) if(! ~ $d lib_core) todo=($todo $d)
	while(! ~ $#todo 0){
		wave=()
		rest=()
		for(d in $todo){
			ok=1
			for(n in `{sed -n 's/^NEEDS=//p' $d/mkfile}) if(! ~ $n $made) ok=()
			if(~ $#ok 1) wave=($wave $d)
			if not rest=($rest $d)
		}
		if(~ $#wave 0){ echo 'libs: NEEDS not in LIBS, or a cycle:' $rest >[1=2]; exit 1 }
		pids=()
		for(d in $wave){ @{cd $d && $MK 'O='$O 'OS='$OS $b} & pids=($pids $apid) }
		for(p in $pids){ wait $p; ~ $status '' || exit 1 }
		made=($made $wave)
		todo=$rest
	}
	status=''

# every directory's .depend (mkfiles/mkdepend) made again, those
# whose mkfile includes mkprog, mklib, mkdepend or games/mkgames (each
# build makes them when older than a source: this, when in doubt)
depend:V:
	for(m in `{$WALK . | grep '/mkfile$' | grep -v -e '^\./_' -e '/\.claude/' | xargs grep -l -E -e '^<.*mkfiles/mk(prog|lib|depend)$' -e '^<.*games/mkgames$'}) {
		d=`{dirname $m}
		if(! ~ $d .) @{cd $d && $MK 'O='$O 'OS='$OS depend} || exit 1
	}

clean:V:
	rm -rf _mk
