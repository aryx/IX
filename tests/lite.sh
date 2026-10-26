#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# make test-lite: two minutes for a good confidence that nothing
# regressed, where make test-all (tests/all.sh) takes half an hour. Every
# family of programs by its fastest checks that mean something, nothing
# that needs a reference outside the repository, and all of them at
# once: the machine's cores are what makes it short.
# - dune's build (first, alone), and ix's types by OCaml 5.5 when its
#   opam switch is there;
# - each program's unit tests and differential tests, the linker's
#   recorded bytes, the generators against ocamllex and ocamlyacc, the
#   tiny programs' tests, tiny-kernel booted, the machines' decoders;
# - mini-ml: every file of ix compiled (a directory a job), programs of
#   today's OCaml compiled, linked and run against OCaml (four jobs);
# - ix built by ix, from nothing, each time (under _mk/lite: mini-mk's
#   jobs in parallel, NPROC, and the programs side by side): then, with
#   what was just built, mini-rc's and mini-ed's tests, the tiny
#   programs', the games' frames, the toolchain's
#   own output on a few files against dune's, a kernel's step and
#   mini-xv6 booted under mini-qemu.
# The jobs in three groups (plan_tests.md): shared (what both systems
# stand on: OCaml 5's types, lib_core by mini-ml), t-ix (the tiny
# programs, tiny-kernel) and m-ix (the mini programs, ix built by ix,
# which builds and tests the tiny programs too); one group alone when
# the change is in one system. A line for each job as soon as it ends,
# its group first ([t-ix] ...: grep keeps one), its seconds, the
# failures' first lines; at the end the failures again, a line a group,
# and the jobs past the budget, 2 minutes the whole and 1 a job (said,
# not a failure). The logs are kept when one fails. What this machine
# cannot do is said too, a "skip" line with its reason, and is not a
# failure: mini-xv6 without xv6's disk image (~/xv6), mini-9pi's two
# units that need its generated Memdata (principia's fonts), the arm64
# programs that mini-ml makes on a machine that does not run them
# (neither arm64 nor with qemu-aarch64 registered, binfmt_misc).
# usage: tests/lite.sh [mix] [tix]    (none: all; shared always)

# (the mkfiles' recipes are rc's: mkfiles/mkconfig)
export MKSHELL=mini-rc
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd $ROOT
export PATH=$ROOT/bin:$PATH
# the games' frames and sounds against ~/playground's own: test-all's
# suite playground, not here (its TinyVirtuaRacing alone was 4 minutes)
export PLAYGROUND=/nonexistent
W=$(mktemp -d)
# milliseconds: GNU's date has %N, BSD's (macOS) prints it as is, so perl there
if [ "$(date +%3N)" = 3N ]; then now() { perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000'; }
else now() { date +%s%3N; }; fi
begun=$(now)
dune build 2> $W/dune.log || { echo "FAIL dune build"; head -20 $W/dune.log; exit 1; }

# the groups (plan_tests.md): shared, what both systems stand on (OCaml
# 5's types, the sources as text, lib_core compiled by mini-ml); t-ix,
# the tiny programs and tiny-kernel; m-ix, the mini programs, mini-ml,
# and ix built by ix. The arguments choose (mix, tix; shared always), none all.
want_groups=" "
for a in "$@"; do
  case $a in
    mix|m-ix) want_groups+="m-ix ";;
    tix|t-ix) want_groups+="t-ix ";;
    *) echo "usage: tests/lite.sh [mix] [tix]"; exit 2;;
  esac
done
[ "$want_groups" = " " ] && want_groups=" m-ix t-ix "
G=shared
group() { G=$1; }
wanted() { [ $G = shared ] || [[ "$want_groups" == *" $G "* ]]; }
# a job: its name, then the command (its input an empty pipe: tests/all.sh says why)
names=()
groups=()
jobpids=()
job() {
  wanted || return 0
  local name=$1; shift
  names+=("$name"); groups+=($G)
  local k=$W/job${#names[@]}
  ( t0=$(now); if true | "$@" > $k.log 2>&1; then s=ok; else s=FAIL; fi
    # (renamed: the loop at the end never reads it half written)
    echo "$s $(( $(now) - t0 ))" > $k.st && mv $k.st $k.status ) &
  jobpids+=($!)
}
sh_() { bash -c "$1"; }
# what is left out here, and why
skips=()
skip() { wanted && skips+=("$(printf '%-8s' "[$G]") skip           $1 ($2)"); }
# does this machine run arm64's programs?
runs7=1
[ "$(uname -m)" = aarch64 ] || [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ] || runs7=
no7="arm64's programs do not run here"

# (each program's unit tests a job: the one that fails is named. Testo's
# directories first: each of the four makes them if they are not there,
# and two at once in a fresh checkout is "mkdir: EEXIST" for one)
mkdir -p tests/snapshots _build/testo/status

group shared
# ix by the other OCaml too, its types (@check, in _build5): CI builds
# with 4.14 and 5.5, a keyword of 5's (effect) once broke the second
# unseen (plan_tests.md); here when the switch is there and dune's
# build above was 4's
ocaml5=5.5.1
t5="ix by OCaml $ocaml5, its types"
has5() { command -v opam > /dev/null &&
  opam switch list -s 2> /dev/null | grep -qx $ocaml5; }
case $(ocamlfind ocamlopt -version) in
  5.*) skip "$t5" "dune's build is OCaml 5's already";;
  *) if has5; then
       job "$t5" opam exec --switch=$ocaml5 -- dune build @check --build-dir _build5
     else skip "$t5" "no opam switch $ocaml5"; fi;;
esac
job "every source is text" tests/text_files.sh

group t-ix
job "tiny-shell: scripts against 9base's rc" tiny/tests/TinyShell_test.sh
job "tiny-editor: sam's commands against 9base's sam" tiny/tests/TinyEditorLine_test.sh
job "tiny-db: random sessions against SQLite" tiny/tests/TinyDatabase_test.sh 5
job "tiny-vcs: its laws on random work" tiny/tests/TinyVCS_test.sh 3
job "tiny-cpu, tiny-assembler: programs, random listings" tiny/tests/TinyCPU_test.sh 50
job "tiny-machine: unit tests" tiny/tests/TinyMachine_test.sh
job "tiny-kernel: its graphics" tiny/tests/TinyKernelGraphics_test.sh
job "TinyLibPlayground: unit tests" tiny/tests/TinyLibPlayground_test.sh
job "tiny-tetris: recorded frames" tiny/tests/TinyAppTetris_test.sh
job "TinyLibGUI: unit tests" tiny/tests/TinyLibGUI_test.sh
job "TinyLibCore: unit tests" tiny/tests/TinyLibCore_test.sh
job "tiny-emacs: recorded screens" tiny/tests/TinyEditorScreen_test.sh
job "tiny-browser: pages" tiny/tests/TinyBrowser_test.sh
job "tiny-profiler: profiles" tiny/tests/TinyProfiler_test.sh
job "tiny-c: programs against cc" tiny/tests/TinyC_test.sh
job "tiny-ml: programs against OCaml" tiny/tests/TinyML_test.sh
# tiny-kernel booted (an image of its own: TinyKernel's _make is the
# sessions'), its tests in ML and a shell's files and pipe; its whole
# check (81 s, 12 minutes of cores) is make test's
tiny_kernel() {
  local o=$W/tiny-kernel m="tiny-machine -date 820540800 -seed 1"
  make -s -C tiny/TinyKernel O=$o $o/boot.img || return 1
  echo mltests | timeout 60 $m $o/boot.img > $o/mltests.out
  grep -q 'mltests: ALL OK' $o/mltests.out ||
    { tail -5 $o/mltests.out; return 1; }
  printf 'echo hi | cat > f; cat f; wc < f; rm f; cat f\n' |
    timeout 60 $m $o/boot.img > $o/sh.out
  # (its lines, not its banner, which says the memory's size)
  local l
  for l in '$ hi' '      1       1       3' 'cat: f: cannot open'; do
    grep -qxF "$l" $o/sh.out ||
      { echo "tiny-kernel: no \"$l\" in:"; cat $o/sh.out; return 1; }
  done
}
job "tiny-kernel: booted, mltests, a shell's files" tiny_kernel

group m-ix
job "libc: ix's fmt and vlrt against glibc and gcc" lib_core/libc/tests/check.sh 1000
job "libc: memmove, memset and arm's division, the machines' assembly" lib_core/libc/tests/mem_check.sh
job "mini-ml -pp" languages/ml/tests/pp.sh
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
job "games: recorded frames" games/tests/frames.sh
job "games: recorded sounds" games/tests/audio.sh
job "mini-music: recorded frames and sounds" sh_ 'apps/music/tests/frames.sh && apps/music/tests/audio.sh'
job "mini-drscheme: recorded frames" editors/drscheme/tests/frames.sh
job "examples: recorded frames" examples/tests/frames.sh
job "mini-office: recorded frames" apps/office/tests/frames.sh
job "gui4: unit tests" _build/default/examples/gui4/tests/Test.exe
job "mini-office: unit tests" _build/default/apps/office/tests/Test.exe
job "lib_graphics/images, svg: unit tests" sh_ '_build/default/lib_graphics/images/tests/Test.exe && _build/default/lib_graphics/svg/tests/Test.exe'
job "lib_crypto: the standards' vectors" _build/default/lib_crypto/tests/Test.exe
job "mini-play: a file of each format, its samples" lib_audio/tests/play.sh
job "lib_networking: unit tests" _build/default/lib_networking/tests/Test.exe
job "mini-curl, mini-httpd: a directory served, TLS with openssl's server" sh_ 'networking/tests/served.sh && networking/tests/tls.sh'
job "browsers/html: unit tests" _build/default/browsers/html/tests/Test.exe
job "mini-lynx: a recorded session" browsers/lynx/tests/session.sh
job "mini-troff, mini-man: a page of ix's own" typesetting/tests/sample.sh
job "browsers/javascript: unit tests, three ways" browsers/javascript/tests/modes.sh
job "browsers/webapi: unit tests" _build/default/browsers/webapi/tests/Test.exe
job "browsers/css: unit tests" _build/default/browsers/css/tests/Test.exe
job "browsers/engine: unit tests, a page's boxes" sh_ '_build/default/browsers/engine/tests/Test.exe && browsers/engine/tests/boxes.sh'
job "mini-netscape: recorded frames, the profile, the helpers" sh_ 'browsers/netscape/tests/frames.sh && browsers/netscape/tests/profile.sh && browsers/netscape/tests/helpers.sh'
job "mini-node: its scripts" browsers/javascript/tests/scripts.sh
job "mini-rc: recorded cases" shell/tests/differential.sh
job "mini-ed: recorded cases" editors/ed/tests/differential.sh
job "mini-mk: recorded cases" builder/tests/differential.sh
job "mini-hoc: recorded cases" utilities/calc/hoc/tests/differential.sh
job "mini-awk: recorded cases" utilities/text/awk/tests/differential.sh
job "mini-dc: recorded cases" utilities/calc/dc/tests/differential.sh
job "mini-bc: recorded cases" utilities/calc/bc/tests/differential.sh
job "mini-asm, mini-ld: recorded executables" linker/tests/golden.sh
job "mini-lex: ocamllex's tokens" generators/tests/tokens.sh
job "mini-yacc: ocamlyacc's trees" generators/tests/trees.sh
job "mini-git: sessions, queries" sh_ 'version_control/tests/session.py 3 && version_control/tests/query.py 3'
job "mini-5i: decoders, random blocks" sh_ 'machine/tests/decode_check.py && machine/tests/decode_check.py -64 && machine/tests/random_blocks.py 300 30 && machine/tests/random_blocks.py -64 300 30 && machine/tests/random_blocks.py -vfp 100 30'

# mini-ml, m-ix's compiler: programs of today's OCaml, in four jobs
# (each builds the stdlib first)
M=languages/ml/tests/modern
if [ -n "$runs7" ]; then
job "mini-ml: stdlib, formats, fields" languages/ml/tests/modern.sh $M/stdlib.ml $M/hashtables.ml $M/formats.ml $M/fields.ml $M/constructors.ml
job "mini-ml: floats, digests, marshal" languages/ml/tests/modern.sh $M/floats.ml $M/digests.ml $M/marshalled.ml $M/engines.ml
job "mini-ml: files, unix, signals" languages/ml/tests/modern.sh $M/files.ml $M/unix_calls.ml $M/unix_sockets.ml $M/signals.ml
job "mini-ml: the runtime from C" sh_ "languages/ml/tests/run.sh 7 $W/rt languages/ml/tests/runtime/*.ml languages/ml/tests/tiny/exceptions.ml languages/ml/tests/tiny/gc.ml"
else skip "mini-ml: its programs run, against OCaml" "$no7"; fi
# every file of ix compiled by mini-ml: a directory a job, in the group
# of what it holds (lib_core both systems', tiny t-ix's)
compiles() { languages/ml/tests/compile_ix.sh "$@" | tee /dev/stderr | tail -1 | grep -q '^\([1-9][0-9]*\) of \1 compile'; }
for d in lib_core tiny assembler linker languages/c languages/ml languages/scheme languages/prolog languages/datalog languages/forth "languages/pascal lib_terminal" generators database builder shell editors machine raspberry version_control kernels "lib_compression lib_crypto lib_networking networking browsers" "games lib_playground lib_juice lib_ai lib_graphics lib_gui examples apps languages/formula"; do
  case $d in lib_core) group shared;; tiny) group t-ix;; *) group m-ix;; esac
  job "mini-ml compiles ${d%% *}" compiles $d
done
group m-ix

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
# the tiny programs, on lib_core as m-ix's: `mk tiny` builds them, and
# their tests run on those
# (old: on t-ix's own copy of lib_core, tiny/TinyLibHost/, and built
# again on lib_core, not tested: plan_tiny_self_hosting.md's step 2)
tiny_tests() {
  local t=$K/tiny
  TS=$t/tiny-shell tiny/tests/TinyShell_test.sh && TE=$t/tiny-editor tiny/tests/TinyEditorLine_test.sh &&
  TD=$t/tiny-db tiny/tests/TinyDatabase_test.sh 5 && V=$t/tiny-vcs tiny/tests/TinyVCS_test.sh 3 &&
  TB=$t/tiny-build tiny/tests/TinyBuildSystem_test.sh && TA=$t/tiny-assembler TL=$t/tiny-linker T=$t/tiny-cpu tiny/tests/TinyCPU_test.sh 50
}
ix() {
  rm -rf $B
  # the libraries first, one after the other in their order (the top
  # mkfile's libs: a program's mkfile takes their archives as they are)
  (NPROC=32 mini-mk B=$B libs) > "$W/mk.libs.log" 2>&1 || { echo "mini-mk failed in libs:"; tail -3 "$W/mk.libs.log" | cut -c1-200; return 1; }
  mk assembler || return 1
  # side by side; the two that take another's objects after it (mini-ar
  # the linker's, tiny-vcs mini-git's SHA-1 and zlib)
  local pids=() d bad=0
  for d in languages/c languages/ml languages/prolog languages/datalog languages/forth generators/lex generators/yacc database builder shell editors/ed machine kernels/steps/step3 $xv6; do mk $d & pids+=($!); done
  (mk games && mk editors/drscheme && mk examples && mk apps/office && mk apps/music/rebirth) & pids+=($!)
  (mk linker && mk linker/tools) & pids+=($!)
  (mk version_control && mk tiny) & pids+=($!)
  mk lib_crypto/tests & pids+=($!)
  mk apps/music/play & pids+=($!)
  (mk networking && mk browsers/lynx) & pids+=($!)
  mk typesetting/man & pids+=($!)
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
  (! games/tests/audio.sh $K/games | grep '^FAIL') & pids+=($!)
  (! { apps/music/tests/frames.sh $K/apps; apps/music/tests/audio.sh $K/apps; } | grep '^FAIL') & pids+=($!)
  (! editors/drscheme/tests/frames.sh $K/editors | grep '^FAIL') & pids+=($!)
  (! examples/tests/frames.sh $K/examples | grep '^FAIL') & pids+=($!)
  (! apps/office/tests/frames.sh $K/apps | grep '^FAIL') & pids+=($!)
  (! lib_audio/tests/play.sh $K/apps/music/play/mini-play | grep -v "^play.sh:") & pids+=($!)
  ($K/lib_crypto/tests/vectors | cmp -s - lib_crypto/tests/Vectors.expected || { echo "lib_crypto by mini-ml: a vector differs"; exit 1; }) & pids+=($!)
  (! { networking/tests/served.sh $K/networking; networking/tests/tls.sh $K/networking; browsers/lynx/tests/session.sh $K; browsers/javascript/tests/scripts.sh $K/browsers/javascript; browsers/engine/tests/boxes.sh $K/browsers/engine/tests; browsers/netscape/tests/frames.sh $K/browsers; } | grep '^FAIL') & pids+=($!)
  (! typesetting/tests/sample.sh $K | grep '^FAIL') & pids+=($!)
  (tiny_tests > $W/tiny.log 2>&1 || { echo "a tiny program built by ix fails its tests:"; tail -5 $W/tiny.log | cut -c1-200; exit 1; }) & pids+=($!)
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
[ -n "$runs7" ] || skip "ix built by ix: its toolchain against dune's, its mini-rc and mini-ed, the tiny programs" "$no7"
job "ix built by ix, a kernel booted" ix

# each job's line as soon as it ends (so the order is the jobs' ends),
# its group first; then the skips and the failures again, a line for
# each group (its jobs, and when its last one ended), and the jobs past
# the budget (plan_tests.md: the whole 120 s, a job 60 s; said, not a
# failure)
tag() { printf '%-8s' "[$1]"; }
pad='                       '
failures=0
failed=()
slow=()
declare -A g_ok g_fail g_end
report() {
  local n=$1 k=$W/job$1 s ms g=${groups[$1-1]} name=${names[$1-1]}
  # no status: the job's shell itself died, a failure too
  read -r s ms < $k.status 2> /dev/null || { s=FAIL; ms=0; echo "(no status: the job's shell died)" >> $k.log; }
  printf "%s %-4s %5.1f s  %s\n" "$(tag $g)" $s $(echo "$ms / 1000" | bc -l) "$name"
  g_end[$g]=$(( $(now) - begun ))
  [ $ms -gt 60000 ] &&
    slow+=("$(tag $g) $(printf '%5.1f' $(echo "$ms / 1000" | bc -l)) s  $name")
  if [ $s = ok ]; then g_ok[$g]=$(( ${g_ok[$g]:-0} + 1 )); else
    failures=$((failures + 1)); failed+=("$(tag $g) FAIL           $name")
    g_fail[$g]=$(( ${g_fail[$g]:-0} + 1 ))
    # its lines that say a failure (Testo's are "[FAIL]", in colors: taken out;
    # not its legend, nor a test's name with "error" in it), then the log's
    # end: in Docker the log itself is gone with the build
    sed 's/\x1b\[[0-9;]*m//g' $k.log > $k.txt
    grep -a '^FAIL\|^\[FAIL\]\|[Ee]rror:\| differ\|!=\|[1-9][0-9]* failure\|failed\|fail$' $k.txt | grep -v ' 0 fail\|^\[RUN\]\|^\[PASS\]' | head -8 | cut -c1-160 | sed "s/^/$pad/"
    echo "$pad... the log's end:"
    grep -av '^\[RUN\]\|^\[PASS\]\|^$\|Path to captured log' $k.txt | tail -20 | cut -c1-160 | sed "s/^/$pad| /"
  fi
}
left=${#names[@]}
done_=()
while [ $left -gt 0 ]; do
  for n in $(seq 1 ${#names[@]}); do
    [ -n "${done_[n]}" ] && continue
    # ended: its status written, or its shell gone (then its status looked at again)
    [ -f $W/job$n.status ] || ! kill -0 ${jobpids[n-1]} 2> /dev/null || continue
    report $n; done_[n]=1; left=$((left - 1))
  done
  [ $left -gt 0 ] && sleep 0.2
done
wait
total=$(( $(now) - begun ))
for k in "${skips[@]}"; do echo "$k"; done
for k in "${failed[@]}"; do echo "$k"; done
for g in shared t-ix m-ix; do
  nskip=0
  for k in "${skips[@]}"; do [[ "$k" == "[$g]"* ]] && nskip=$((nskip + 1)); done
  [ -z "${g_end[$g]}" ] && [ $nskip = 0 ] && continue
  line="${g_ok[$g]:-0} ok"
  [ -n "${g_fail[$g]}" ] && line="$line, ${g_fail[$g]} FAIL"
  [ $nskip != 0 ] && line="$line, $nskip skipped"
  printf "== %-6s %-36s %4.0f s\n" $g "$line" \
    $(echo "${g_end[$g]:-0} / 1000" | bc -l)
done
if [ $total -gt 120000 ] || [ ${#slow[@]} != 0 ]; then
  echo "past the budget (plan_tests.md: 120 s, a job 60 s):"
  for k in "${slow[@]}"; do echo "  $k"; done
fi
printf "test-lite: %d jobs, %d failure(s), %d skipped, %.0f s\n" ${#names[@]} $failures ${#skips[@]} $(echo "$total / 1000" | bc -l)
if [ $failures = 0 ]; then rm -rf $W; else echo "the logs: $W"; fi
[ $failures = 0 ]
