# ix built by ix: run mini-mk here, after make install (or with
# PATH=$PWD/bin:$PATH). It builds the libraries first, then each
# program; what is made goes under _mk/ (docs/plans/plan_mkfiles.md).
# mini-mk O=5 builds for arm (the programs, and the kernels' steps for
# the Pi 1; O=7's are for the Pi 4).
# (O and OS come from mkconfig: 7 and linux, or on Plan 9 its own.)
TOP=.
<mkfiles/mkconfig
DIRS=lib_core assembler linker linker/tools languages/c database builder shell editors/ed \
 generators/lex generators/yacc languages/ml languages/scheme languages/pascal languages/prolog languages/datalog languages/forth languages/dotnet languages/dotnet/csc languages/tiger editors/turbopascal/tty editors/emacs/tty machine version_control kernels/tools \
 typesetting/troff typesetting/man utilities/files utilities/misc utilities/namespace utilities/time utilities/pipe utilities/compare utilities/process utilities/text utilities/byte utilities/archive utilities/calc/hoc utilities/calc/dc utilities/calc/bc utilities/text/awk kernels/9pi/filesystems/user/dossrv kernels/9pi/devices/storage/user/fdisk lib_graphics/tests windows/rio windows/rio/tests windows/desktop apps/misc apps/files apps/maps profilers/misc debuggers/where debuggers/acid games editors/drscheme examples tiny
KERNELS=kernels/steps/step0 kernels/steps/step1 kernels/steps/step2 kernels/steps/step3

# The libraries are built first, side by side in waves (libs: below),
# each after the ones it needs. As in xix's and principia's top
# mkfiles, a directory then takes the libraries as they are, and a
# stale one is built again from here; mini-mk libs builds the libraries
# alone. The assembler comes next, because the others read its objects.
# Then the rest are built side by side, a mini-mk for each directory.
# Beside them run three chains of directories that take another's
# objects, each built in order: the linker, then mini-ar (linker/tools),
# which takes its objects; mini-dc, then mini-bc, which takes its
# machine; and games, then editors/drscheme, examples and apps/office,
# which take the games' libraries (games/mkgames). NPROC is each
# mini-mk's own number of jobs.
# (The directories are built side by side because one after the other
# takes 3 minutes.)
# (NPROC is the machine's cores, 16 at most; on Plan 9 each core is a
# line of /dev/sysstat. It does not cap the directories: every one of
# them is started at once.)
NPROC=`{if(~ $#objtype 0) nproc | awk '{print ($1 > 16 ? 16 : $1)}'; if not wc -l < /dev/sysstat}
# (OS=plan9 is for mini-9pi, and kernels/9pi's Makefile sets it. Its
# games have two platforms, the draw device's and the software one,
# where Linux's is ppm.)
PLATFORMS=`{if(~ $OS plan9) echo draw software; if not echo ppm}
LIBS=lib_core lib_mime lib_crypto lib_compression lib_executable lib_networking lib_graphics lib_playground lib_playground/physics lib_playground/juice lib_gui lib_audio \
 lib_playground/netcode lib_playground/ai lib_playground/apis lib_playground/platforms ${PLATFORMS:%=lib_playground/platforms/%} \
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

# (B is passed on when it was given, as games/mkfile does: tests/lite.sh
# gives _mk/lite, where each library's own mkconfig would say _mk/$O.)
# libs builds lib_core, then the others in waves. A wave is every
# library whose NEEDS (from its mkfile) are made, built side by side;
# then comes the next wave. troff is built beside the browser's chain,
# and the waves take tests/lite.sh's libraries from 25 s, one after the
# other in LIBS's order, to 13 s. When a library's NEEDS name one that
# is not in LIBS, or when there is a cycle, no wave can be made, and
# libs says so and stops instead of looping.
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

# depend makes every directory's .depend (mkfiles/mkdepend) again, in
# the directories whose mkfile includes mkprog, mklib, mkdepend or
# games/mkgames. Each build makes them when they are older than a
# source; use this target when in doubt.
depend:V:
	for(m in `{$WALK . | grep '/mkfile$' | grep -v -e '^\./_' -e '/\.claude/' | xargs grep -l -E -e '^<.*mkfiles/mk(prog|lib|depend)$' -e '^<.*games/mkgames$'}) {
		d=`{echo $m | sed 's,/[^/]*$,,'}
		if(! ~ $d .) @{cd $d && $MK 'O='$O 'OS='$OS depend} || exit 1
	}

clean:V:
	rm -rf _mk
