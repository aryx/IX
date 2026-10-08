#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# make test-kernels-ix: mini-xv6's and mini-9pi's checks with the
# images ix's tools made (their mkfiles' check), on the Pi 4 (arm64)
# and the Pi 1 (arm, mini-mk O=5), side by side but mini-9pi's two
# boards one after the other: its network test's web server has one
# port. A check says "ok" for each thing checked and a mkfile's recipe
# does not stop at the first that is not: so the lines are counted
# here (mini-xv6: 6 on the Pi 4, 7 on the Pi 1, whose screen is also
# compared with the C kernel's; mini-9pi: 13), and fewer is a failure.
# usage: tests/kernels_ix.sh     (after make kernels-ix)

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd $ROOT
export PATH=$ROOT/bin:$PATH
W=$(mktemp -d); trap 'rm -rf $W' EXIT
(cd kernels/xv6 && true | mini-mk check > $W/xv6-7.log 2>&1) &
(cd kernels/xv6 && true | mini-mk O=5 check > $W/xv6-5.log 2>&1) &
(cd kernels/9pi && true | mini-mk check > $W/9pi-7.log 2>&1; true | mini-mk O=5 check > $W/9pi-5.log 2>&1) &
wait
failures=0
for k in xv6-7:6 9pi-7:13 xv6-5:7 9pi-5:13; do
  name=${k%:*}; want=${k#*:}
  grep -a '^ok ' $W/$name.log
  n=$(grep -ac '^ok ' $W/$name.log)
  if [ $n != $want ]; then
    echo "FAIL mini-${name%-*} by ix (O=${name#*-}): $n of its $want checks pass"
    grep -av '^ok ' $W/$name.log | tail -15 | cut -c1-200
    failures=$((failures + 1))
  fi
done
echo "kernels-ix: $failures failure(s)"
[ $failures = 0 ]
