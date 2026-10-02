# ix built by ix: mini-mk here, after make install (or with
# PATH=$PWD/bin:$PATH). The libraries first, then each program;
# what is made is under _mk/ (docs/plans/plan_mkfiles.md).
DIRS=lib_core assembler

all:V:
	for d in $DIRS; do (cd $d && mini-mk) || exit 1; done

clean:V:
	rm -rf _mk
