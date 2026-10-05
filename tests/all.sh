#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The whole of ix's tests, one suite after the other (make test-all):
# each suite's output kept in a log, a line said for each (ok, FAIL,
# or skipped with what it lacks), the list again at the end. A suite
# that fails does not stop the others. A suite whose references are not
# on this machine (goken, ocaml-light, chidb, principia, xv6's ports,
# the QEMUs) is skipped, and said so: the first ones need only dune.
#
#   tests/all.sh             every suite (half an hour: -l says about how long)
#   tests/all.sh -l          the suites, what each is, what it needs
#   tests/all.sh ix arm      those suites only
#   tests/all.sh -quick      those of a few minutes each
# The logs: $IX_TEST_LOGS, or /tmp/ix-test-all.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd $ROOT
export PATH=$ROOT/bin:$PATH
LOGS=${IX_TEST_LOGS:-/tmp/ix-test-all}
QEMU64=/home/pad/work/TOOLCHAINS/qemu/build/qemu-system-aarch64

# name @ minutes @ quick @ what it needs (a test, or empty) @ what it is @ the command
suites() {
cat <<'END'
build@1@q@@dune builds every program, by OCaml@make all
test@6@q@@make test: each program's own tests, the references recorded in the repository@make test
ml@6@q@@make test-ml: mini-ml on today's OCaml (tests/modern/ against OCaml), every file of ix compiled, the preprocessor@make test-ml
differential@1@q@@make test-differential: mini-mk against plan9port's mk and xix's omk, when they are installed@make test-differential
goken@25@@[ -x $HOME/goken/ROOT/arch/boot-gcc/bin/5c ]@make test-goken: the toolchain against goken's (5a 5l -f 5c, 7a 7l 7c), byte for byte@make test-goken
ocaml@30@@[ -d $HOME/ocaml-light ] && [ -x $HOME/goken/ROOT/arch/boot-gcc/bin/5c ]@make test-ocaml: tiny-ml and mini-ml against ocaml-light's ocamlopt (built first: kernel/ocaml-light.sh)@kernel/ocaml-light.sh arm64 && kernel/ocaml-light.sh arm && make test-ocaml
chidb@3@q@[ -d $HOME/github/chidb ]@make test-chidb: mini-chidb against chidb@make test-chidb
ix@5@@@make test-ix: ix built by ix (mini-mk over the mkfiles), each program against dune's, the tiny programs' tests, the kernels' steps and mini-xv6 booted@make test-ix
fixpoint@2@@@make test-fixpoint: ix built by its own build, the same files@make test-fixpoint
arm@2@@command -v qemu-arm > /dev/null && mkfiles/runs_arm.sh@make test-arm: ix for arm built by ix, its programs run under qemu-arm@make test-arm
fixpoint-arm@2@@command -v qemu-arm > /dev/null && mkfiles/runs_arm.sh@make test-fixpoint-arm: ix for arm built by its arm programs, twice: the same files@make test-fixpoint-arm
pi@3@@[ -d $HOME/principia ] && [ -d $HOME/xv6 ] && command -v qemu-system-arm > /dev/null@make test-pi: mini-qemu against QEMU, the kernels by ocaml-light and gcc (their steps, mini-xv6 on both boards, mini-9pi)@make test-pi
kernels-ix@6@@[ -d $HOME/principia ] && [ -f $HOME/xv6/forks/arm64-pi4/fs.img ] && [ -x $QEMU64 ]@make test-kernels-ix: the kernels built by ix, on the Pi 4: mini-xv6's and mini-9pi's checks, the Makefiles' own@make test-kernels-ix
github@2@@[ -n "$IX_TEST_NET" ]@make test-github: ix cloned from GitHub by mini-git (set IX_TEST_NET=1: it needs the network)@make test-github
END
}

if [ "${1:-}" = -l ]; then
  suites | while IFS='@' read -r name minutes quick needs what cmd; do
    printf "%-13s %3s min  %s\n" "$name" "$minutes" "$what"
    [ -n "$needs" ] && { eval "$needs" 2> /dev/null && printf "%24s(has what it needs)\n" "" || printf "%24s(would be skipped here: %s)\n" "" "$needs"; }
  done
  exit 0
fi
quick=; [ "${1:-}" = -quick ] && { quick=1; shift; }
mkdir -p $LOGS
summary=$LOGS/summary.txt; : > $summary
failed=0
while IFS='@' read -r name minutes q needs what cmd <&3; do
  if [ $# -gt 0 ]; then case " $* " in *" $name "*) ;; *) continue;; esac
  elif [ -n "$quick" ] && [ -z "$q" ]; then continue; fi
  if [ -n "$needs" ] && ! eval "$needs" 2> /dev/null; then
    line=$(printf "skipped %-13s (not here: %s)" "$name" "$needs")
  else
    printf "....... %-13s %s\n" "$name" "$what"
    start=$(date +%s)
    # (its input an empty pipe: not this script's, and not a file or a
    # terminal, on which some tests' answers depend)
    if true | bash -c "$cmd" > $LOGS/$name.log 2>&1; then status=ok; else status=FAIL; failed=$((failed + 1)); fi
    took=$(( $(date +%s) - start ))
    line=$(printf "%-7s %-13s %3d min %02d s   %s" $status "$name" $((took / 60)) $((took % 60)) "$LOGS/$name.log")
    [ $status = FAIL ] && line="$line
$(grep -a '^FAIL\|[a-z0-9]-FAIL\|Error \|!=\| differ\|[1-9][0-9]* failure' $LOGS/$name.log | grep -v 'expected to\|XFAIL\|on purpose' | tail -5 | cut -c1-160 | sed 's/^/          /')"
  fi
  echo "$line"; echo "$line" >> $summary
done 3< <(suites)
echo
echo "== ix's tests, $(date +%Y-%m-%d): $failed suite(s) failed"
cat $summary
# the times, kept (docs/test_times.md): a row for this run, each suite
# its minutes and seconds, a failed one marked
row=$(grep -a '^ok \|^FAIL ' $summary | awk '{ printf "%s%s %d:%s%s", (n++ ? ", " : ""), $2, $3, $5, ($1 == "FAIL" ? " (FAIL)" : "") }')
[ -n "$row" ] && echo "| $(date +%Y-%m-%d) | \`$(git rev-parse --short HEAD)\`$(git diff --quiet || echo +) | $row |" >> $ROOT/docs/test_times.md
[ $failed = 0 ]
