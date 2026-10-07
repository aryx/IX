# ix built by ix: mini-mk here, after make install (or with
# PATH=$PWD/bin:$PATH). The libraries first, then each program;
# what is made is under _mk/ (docs/plans/plan_mkfiles.md).
# mini-mk O=5: for arm (the programs, and the kernels' steps for the Pi 1;
# O=7's are the Pi 4's)
O=7
DIRS=lib_core assembler linker linker/tools languages/c database builder shell editor \
 generators/lex generators/yacc languages/ml machine version_control kernel/tools \
 utilities/files utilities/misc utilities/namespace utilities/time utilities/pipe utilities/compare utilities/process kernel/9pi/filesystems/user/dossrv kernel/9pi/devices/storage/user/fdisk lib_graphics/tests windows windows/tests applications/misc tiny
KERNELS=kernel/step0 kernel/step1 kernel/step2 kernel/step3

# The libraries and the assembler first (the others read their
# objects), then the rest side by side, each directory a mini-mk; the
# two that take another's objects after it (mini-ar the linker's,
# tiny-vcs mini-git's SHA-1 and zlib). NPROC is each mini-mk's own jobs.
# (old: one directory after the other, 3 minutes:
#   for d in $DIRS; do (cd $d && mini-mk O=$O) || exit 1; done
#   if [ $O = 7 ]; then for d in $KERNELS; do (cd $d && mini-mk) || exit 1; done; fi)
# (the machine's cores, 16 at most: there are as many directories at once)
NPROC=`{n=$(nproc); if [ $n -gt 16 ]; then n=16; fi; echo $n}
FIRST=lib_core assembler
AFTER=linker/tools tiny
all:V:
	for d in $FIRST; do (cd $d && mini-mk O=$O) || exit 1; done
	pids=
	for d in $DIRS; do
		case " $FIRST $AFTER " in *" $d "*) continue;; esac
		(cd $d && mini-mk O=$O) & pids="$pids $!"
	done
	(cd linker && mini-mk O=$O && cd tools && mini-mk O=$O) & pids="$pids $!"
	(cd version_control && mini-mk O=$O && cd ../tiny && mini-mk O=$O) & pids="$pids $!"
	for d in $KERNELS; do (cd $d && mini-mk O=$O) & pids="$pids $!"; done
	for p in $pids; do wait $p || exit 1; done

clean:V:
	rm -rf _mk
