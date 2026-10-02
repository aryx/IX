# ix built by ix: mini-mk here, after make install (or with
# PATH=$PWD/bin:$PATH). The libraries first, then each program;
# what is made is under _mk/ (docs/plans/plan_mkfiles.md).
# mini-mk O=5: for arm
O=7
DIRS=lib_core assembler linker linker/tools languages/c database builder shell editor \
 generators/lex generators/yacc languages/ml machine version_control tiny \
 kernel/step0 kernel/step1

all:V:
	for d in $DIRS; do (cd $d && mini-mk O=$O) || exit 1; done

clean:V:
	rm -rf _mk
