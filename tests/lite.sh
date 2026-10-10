#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# make test-lite: half a minute for a good confidence that nothing
# regressed, where make test-all (tests/all.sh) takes half an hour. Every
# family of programs by its fastest checks that mean something, nothing
# that needs a reference outside the repository, and all of them at
# once: the machine's cores are what makes it short.
# - dune's build (first, alone);
# - each program's unit tests and differential tests, the linker's
#   recorded bytes, the generators against ocamllex and ocamlyacc, the
#   tiny programs' tests, the machines' decoders;
# - mini-ml: every file of ix compiled (a directory a job), programs of
#   today's OCaml compiled, linked and run against OCaml (four jobs);
# - ix built by ix, from nothing, each time (under _mk/lite: mini-mk's
#   jobs in parallel, NPROC, and the programs side by side; the tiny
#   programs twice, on lib_core and on TinyLib): then, with what was
#   just built, mini-rc's and mini-ed's tests, the tiny programs' on
#   TinyLib, the games' frames, the toolchain's
#   own output on a few files against dune's, a kernel's step and
#   mini-xv6 booted under mini-qemu.
# A line for each job, its seconds, the failures' first lines; the
# logs are kept when one fails. What this machine cannot do is said
# too, a "skip" line with its reason, and is not a failure: mini-xv6
# without xv6's disk image (~/xv6), mini-9pi's two units that need
# its generated Memdata (principia's fonts), the arm64 programs that mini-ml
# makes on a machine that does not run them (neither arm64 nor with
# qemu-aarch64 registered, binfmt_misc).
# usage: tests/lite.sh

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd $ROOT
export PATH=$ROOT/bin:$PATH
W=$(mktemp -d)
now() { date +%s%3N; }
begun=$(now)
dune build 2> $W/dune.log || { echo "FAIL dune build"; head -20 $W/dune.log; exit 1; }

# a job: its name, then the command (its input an empty pipe: tests/all.sh says why)
names=()
job() {
  local name=$1; shift
  names+=("$name")
  local k=$W/job${#names[@]}
  ( t0=$(now); if true | "$@" > $k.log 2>&1; then s=ok; else s=FAIL; fi
    echo "$s $(( $(now) - t0 ))" > $k.status ) &
}
sh_() { bash -c "$1"; }
# what is left out here, and why
skips=()
skip() { skips+=("$1 ($2)"); }
# does this machine run arm64's programs?
runs7=1
[ "$(uname -m)" = aarch64 ] || [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ] || runs7=
no7="arm64's programs do not run here"

# (each program's unit tests a job: the one that fails is named. Testo's
# directories first: each of the four makes them if they are not there,
# and two at once in a fresh checkout is "mkdir: EEXIST" for one)
mkdir -p tests/snapshots _build/testo/status
job "mini-mk: unit tests" _build/default/builder/tests/Test.exe
job "mini-rc: unit tests" _build/default/shell/tests/Test.exe
job "mini-ed: unit tests" _build/default/editors/ed/tests/Test.exe
job "mini-chidb: unit tests" _build/default/database/tests/Test.exe
job "mini-smalltalk: unit tests" _build/default/languages/smalltalk/tests/Test.exe
job "mini-scheme: unit tests" _build/default/languages/scheme/tests/Test.exe
job "mini-pascal: unit tests" _build/default/languages/pascal/tests/Test.exe
job "mini-prolog: unit tests" _build/default/languages/prolog/tests/Test.exe
job "mini-prolog: the language, by text" languages/prolog/tests/run.sh -dune
job "mini-forth: the words, by text" languages/forth/tests/run.sh -dune
job "mini-datalog: its programs, naive and semi-naive" languages/datalog/tests/run.sh -dune
job "mini-cc -facts, -flow: a C file's facts, the pointer analysis and liveness on them" languages/c/facts/tests/run.sh
job "mini-ml -flow: SSA as facts, liveness and dominators against the compiler's" languages/ml/facts/tests/run.sh
job "mini-emacs: unit tests" _build/default/editors/emacs/tests/Test.exe
job "mini-emacs: recorded screens, and in a terminal" sh_ 'editors/emacs/tests/keys.sh && editors/emacs/tests/terminal.py'
job "games, mini-drscheme, examples, mini-office: recorded frames" sh_ 'games/tests/frames.sh && editors/drscheme/tests/frames.sh && examples/tests/frames.sh && apps/office/tests/frames.sh'
job "gui4: unit tests" _build/default/examples/gui4/tests/Test.exe
job "mini-office: unit tests" _build/default/apps/office/tests/Test.exe
job "lib_graphics/images, svg: unit tests" sh_ '_build/default/lib_graphics/images/tests/Test.exe && _build/default/lib_graphics/svg/tests/Test.exe'
job "lib_crypto: the standards' vectors" _build/default/lib_crypto/tests/Test.exe
job "lib_networking: unit tests" _build/default/lib_networking/tests/Test.exe
job "mini-curl, mini-httpd: a directory served, TLS with openssl's server" sh_ 'networking/tests/served.sh && networking/tests/tls.sh'
job "browsers/html: unit tests" _build/default/browsers/html/tests/Test.exe
job "mini-lynx: a recorded session" browsers/lynx/tests/session.sh
job "browsers/javascript: unit tests, three ways" browsers/javascript/tests/modes.sh
job "browsers/webapi: unit tests" _build/default/browsers/webapi/tests/Test.exe
job "browsers/css: unit tests" _build/default/browsers/css/tests/Test.exe
job "browsers/engine: unit tests, a page's boxes" sh_ '_build/default/browsers/engine/tests/Test.exe && browsers/engine/tests/boxes.sh'
job "mini-netscape: recorded frames" browsers/netscape/tests/frames.sh
job "mini-node: its scripts" browsers/javascript/tests/scripts.sh
job "mini-rc, mini-ed, mini-mk, mini-hoc, mini-awk, mini-dc, mini-bc: recorded cases" sh_ 'shell/tests/differential.sh && editors/ed/tests/differential.sh && builder/tests/differential.sh && utilities/calc/hoc/tests/differential.sh && utilities/text/awk/tests/differential.sh && utilities/calc/dc/tests/differential.sh && utilities/calc/bc/tests/differential.sh'
job "mini-asm, mini-ld: recorded executables" linker/tests/golden.sh
job "every source is text" tests/text_files.sh
job "mini-lex: ocamllex's tokens" generators/tests/tokens.sh
job "mini-yacc: ocamlyacc's trees" generators/tests/trees.sh
job "mini-git: sessions, queries" sh_ 'version_control/tests/session.py 3 && version_control/tests/query.py 3'
job "tiny: shell, editor, db, vcs" sh_ 'tiny/tests/TinyShell_test.sh && tiny/tests/TinyEditor_test.sh && tiny/tests/TinyDatabase_test.sh 5 && tiny/tests/TinyVCS_test.sh 3'
job "tiny: cpu, machine, graphics, arm, pi" sh_ 'tiny/tests/TinyCPU_test.sh 50 && tiny/tests/TinyMachine_test.sh && tiny/tests/TinyGraphics_test.sh && tiny/tests/TinyPlayground_test.sh && tiny/tests/TinyTetris_test.sh && tiny/tests/TinyCPUArm_test.sh'
job "mini-5i: decoders, random blocks" sh_ 'machine/tests/decode_check.py && machine/tests/decode_check.py -64 && machine/tests/random_blocks.py 300 30 && machine/tests/random_blocks.py -64 300 30 && machine/tests/random_blocks.py -vfp 100 30'
job "mini-ml -pp" languages/ml/tests/pp.sh
job "libc: ix's fmt and vlrt against glibc and gcc" lib_core/libc/tests/check.sh 1000

# mini-ml: programs of today's OCaml, in four jobs (each builds the stdlib first)
M=languages/ml/tests/modern
if [ -n "$runs7" ]; then
job "mini-ml: stdlib, formats, fields" languages/ml/tests/modern.sh $M/stdlib.ml $M/hashtables.ml $M/formats.ml $M/fields.ml $M/constructors.ml
job "mini-ml: floats, digests, marshal" languages/ml/tests/modern.sh $M/floats.ml $M/digests.ml $M/marshalled.ml $M/engines.ml
job "mini-ml: files, unix, signals" languages/ml/tests/modern.sh $M/files.ml $M/unix_calls.ml $M/unix_sockets.ml $M/signals.ml
job "mini-ml: the runtime from C" sh_ "languages/ml/tests/run.sh 7 $W/rt languages/ml/tests/runtime/*.ml languages/ml/tests/tiny/exceptions.ml languages/ml/tests/tiny/gc.ml"
else skip "mini-ml: its programs run, against OCaml" "$no7"; fi
# every file of ix: a directory a job
compiles() { languages/ml/tests/compile_ix.sh "$@" | tee /dev/stderr | tail -1 | grep -q '^\([1-9][0-9]*\) of \1 compile'; }
for d in assembler linker languages/c languages/ml languages/scheme languages/prolog languages/datalog languages/forth "languages/pascal lib_terminal" generators database builder shell editors machine raspberry version_control tiny kernels "lib_core lib_compression lib_crypto lib_networking networking browsers" "games lib_playground lib_graphics lib_gui examples apps languages/formula"; do
  job "mini-ml compiles ${d%% *}" compiles $d
done

# ix built by ix, from nothing: the libraries, the assembler (the others
# read its interfaces' objects), then the programs side by side
B=$ROOT/_mk/lite/7
K=$B
mk() { (cd $1 && NPROC=32 mini-mk B=$B) > "$W/mk.$(echo $1 | tr / _).log" 2>&1 || { echo "mini-mk failed in $1:"; tail -3 "$W/mk.$(echo $1 | tr / _).log" | cut -c1-200; return 1; }; }
# a kernel's image booted until its line is said, 15 seconds at most
boot() {
  local out=$W/boot.$RANDOM$RANDOM.txt n=0 pid
  mini-qemu -cpu cortex-a72 -M raspi4b -m 2G -kernel $1 -nographic < /dev/null > $out 2> /dev/null &
  pid=$!
  until grep -aq "$2" $out || [ $n -ge 150 ]; do sleep 0.1; n=$((n + 1)); done
  kill $pid 2> /dev/null; wait $pid 2> /dev/null
  grep -aq "$2" $out || { echo "$1: no \"$2\" in:"; head -5 $out; return 1; }
}
same() {   # the toolchain just built against dune's, on a few files: the same bytes
  # (an object is marshalled, and OCaml 5.5's Marshal writes a block's header
  # with its color, where 4.14's and mini-ml's write none: dune's by 4.14 only)
  case $(ocamlfind ocamlopt -version) in 4.*) ;; *) echo "the toolchain built by ix: not compared with dune's (OCaml $(ocamlfind ocamlopt -version))"; return 0;; esac
  $K/assembler/mini-asm -m 7 -o $W/a.7 kernels/lib_machine/pi4/l.s && bin/mini-asm -m 7 -o $W/b.7 kernels/lib_machine/pi4/l.s && cmp $W/a.7 $W/b.7 || return 1
  L=lib_core/libc; C="-I$L/include -I$L/include/utf -I$L -I$L/include/arch/arm64 -Darm64 -Dlinux"
  $K/languages/c/mini-cc -m 7 $C -o $W/a.o languages/ml/runtime/runtime.c && bin/mini-cc -m 7 $C -o $W/b.o languages/ml/runtime/runtime.c && cmp $W/a.o $W/b.o || return 1
  I=$(for d in core base collections printing parsing system commons; do echo -n "-I lib_core/$d "; done)
  $K/languages/ml/mini-ml -m 7 -I linker -I assembler $I -o $W/a.m linker/Arm64.ml && bin/mini-ml -m 7 -I linker -I assembler $I -o $W/b.m linker/Arm64.ml && cmp $W/a.m $W/b.m
}
# the tiny programs on t-ix's own library, runtime and C library
# (tiny/TinyLib/, mini-mk LIB=tiny: nothing of lib_core in them)
tinylib() { (cd tiny && NPROC=32 mini-mk B=$B LIB=tiny) > $W/mk.tinylib.log 2>&1 || { echo "mini-mk LIB=tiny failed in tiny:"; tail -3 $W/mk.tinylib.log | cut -c1-200; return 1; }; }
tinylib_tests() {
  local t=$K/tinylib
  TS=$t/tiny-shell tiny/tests/TinyShell_test.sh && TE=$t/tiny-editor tiny/tests/TinyEditor_test.sh &&
  TD=$t/tiny-db tiny/tests/TinyDatabase_test.sh 5 && V=$t/tiny-vcs tiny/tests/TinyVCS_test.sh 3 &&
  TB=$t/tiny-build tiny/tests/TinyBuildSystem_test.sh && T=$t/tiny-cpu tiny/tests/TinyCPU_test.sh 50 &&
  T=$t/tiny-arm A=$t/tiny-assembler tiny/tests/TinyCPUArm_test.sh
}
ix() {
  rm -rf $B
  mk lib_core && mk assembler || return 1
  # side by side; the two that take another's objects after it (mini-ar
  # the linker's, tiny-vcs mini-git's SHA-1 and zlib)
  local pids=() d bad=0
  for d in languages/c languages/ml languages/prolog languages/datalog languages/forth generators/lex generators/yacc database builder shell editors/ed machine kernels/steps/step3 $xv6; do mk $d & pids+=($!); done
  (mk games && mk editors/drscheme && mk examples && mk apps/office) & pids+=($!)
  (mk linker && mk linker/tools) & pids+=($!)
  (mk version_control && mk tiny && tinylib) & pids+=($!)
  mk lib_crypto/tests & pids+=($!)
  (mk networking && mk browsers/lynx) & pids+=($!)
  mk browsers/javascript & pids+=($!)
  mk browsers/engine/tests & pids+=($!)
  mk browsers/netscape & pids+=($!)
  for p in "${pids[@]}"; do wait $p || bad=1; done
  [ $bad = 0 ] || return 1
  echo "$(find $B -type f | wc -l) files, $(ls $B/*/mini-* $B/*/*/mini-* $B/tiny/tiny-* | wc -l) programs"
  # what was built, used: each check a job of its own
  pids=()
  if [ -n "$runs7" ]; then
  (same || { echo "the toolchain built by ix writes other bytes than dune's"; exit 1; }) & pids+=($!)
  (! MINIRC=$K/shell/mini-rc RC=$ROOT/bin/mini-rc ORC= shell/tests/differential.sh | grep '^FAIL') & pids+=($!)
  (! MINIED=$K/editors/ed/mini-ed ED=$ROOT/bin/mini-ed editors/ed/tests/differential.sh | grep '^FAIL') & pids+=($!)
  (! MINIPROLOG=$K/languages/prolog/mini-prolog languages/prolog/tests/run.sh -mini | grep '^FAIL\|^skipped') & pids+=($!)
  (! MINIFORTH=$K/languages/forth/mini-forth languages/forth/tests/run.sh -mini | grep '^FAIL\|^skipped') & pids+=($!)
  (! MINIDATALOG=$K/languages/datalog/mini-datalog languages/datalog/tests/run.sh -mini | grep '^FAIL\|^skipped') & pids+=($!)
  (! { ML=$K/languages/ml/mini-ml DATALOG=$K/languages/datalog/mini-datalog languages/ml/facts/tests/run.sh; CC=$K/languages/c/mini-cc DATALOG=$K/languages/datalog/mini-datalog languages/c/facts/tests/run.sh; } | grep '^FAIL') & pids+=($!)
  (! games/tests/frames.sh $K/games | grep '^FAIL') & pids+=($!)
  (! editors/drscheme/tests/frames.sh $K/editors | grep '^FAIL') & pids+=($!)
  (! examples/tests/frames.sh $K/examples | grep '^FAIL') & pids+=($!)
  (! apps/office/tests/frames.sh $K/apps | grep '^FAIL') & pids+=($!)
  ($K/lib_crypto/tests/vectors | cmp -s - lib_crypto/tests/Vectors.expected || { echo "lib_crypto by mini-ml: a vector differs"; exit 1; }) & pids+=($!)
  (! { networking/tests/served.sh $K/networking; networking/tests/tls.sh $K/networking; browsers/lynx/tests/session.sh $K; browsers/javascript/tests/scripts.sh $K/browsers/javascript; browsers/engine/tests/boxes.sh $K/browsers/engine/tests; browsers/netscape/tests/frames.sh $K/browsers; } | grep '^FAIL') & pids+=($!)
  (tinylib_tests > $W/tinylib.log 2>&1 || { echo "a tiny program on TinyLib fails its tests:"; tail -5 $W/tinylib.log | cut -c1-200; exit 1; }) & pids+=($!)
  fi
  boot $K/kernels/steps/step3/kernel8.img 'no process left to run' & pids+=($!)
  [ -n "$xv6" ] && { boot $K/kernels/xv6/kernel8.img 'init: starting sh' & pids+=($!); }
  for p in "${pids[@]}"; do wait $p || bad=1; done
  [ $bad = 0 ]
}
[ -d kernels/9pi/build/pi1-ocaml ] || skip "mini-ml compiles mini-9pi's Memchan and Memfont" "no generated Memdata: principia's fonts, mini-9pi's Makefile"
xv6=
if [ -f $HOME/xv6/forks/arm64-pi4/fs.img ]; then xv6=kernels/xv6
else skip "mini-xv6 built by ix and booted" "no xv6 disk image: ~/xv6/forks/arm64-pi4/fs.img"; fi
[ -n "$runs7" ] || skip "ix built by ix: its toolchain against dune's, its mini-rc and mini-ed, the tiny programs on TinyLib" "$no7"
job "ix built by ix, a kernel booted" ix

wait
failures=0
n=0
for name in "${names[@]}"; do
  n=$((n + 1)); k=$W/job$n
  read -r s ms < $k.status
  printf "%-4s %5.1f s  %s\n" $s $(echo "$ms / 1000" | bc -l) "$name"
  if [ $s = FAIL ]; then
    failures=$((failures + 1))
    # its lines that say a failure (Testo's are "[FAIL]", in colors: taken out;
    # not its legend, nor a test's name with "error" in it), then the log's
    # end: in Docker the log itself is gone with the build
    sed 's/\x1b\[[0-9;]*m//g' $k.log > $k.txt
    grep -a '^FAIL\|^\[FAIL\]\|[Ee]rror:\| differ\|!=\|[1-9][0-9]* failure\|failed\|fail$' $k.txt | grep -v ' 0 fail\|^\[RUN\]\|^\[PASS\]' | head -8 | cut -c1-160 | sed 's/^/              /'
    echo "              ... the log's end:"
    grep -av '^\[RUN\]\|^\[PASS\]\|^$\|Path to captured log' $k.txt | tail -20 | cut -c1-160 | sed 's/^/              | /'
  fi
done
for k in "${skips[@]}"; do echo "skip           $k"; done
printf "test-lite: %d jobs, %d failure(s), %d skipped, %.0f s\n" ${#names[@]} $failures ${#skips[@]} $(echo "($(now) - $begun) / 1000" | bc -l)
if [ $failures = 0 ]; then rm -rf $W; else echo "the logs: $W"; fi
[ $failures = 0 ]
