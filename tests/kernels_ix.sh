#!/bin/bash
# Claude Code
#
# Copyright (C) 2026 Yoann Padioleau
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public License
# (LGPL) as published by the Free Software Foundation; either version
# 2 of the License, or (at your option) any later version.
#
# make test-kernels-ix: mini-xv6's and mini-9pi's checks with the
# images ix's tools made (their mkfiles' check, on the Pi 4), the two
# side by side. A check says "ok" for each thing checked and a mkfile's
# recipe does not stop at the first that is not: so the lines are
# counted here, 6 for mini-xv6 and 13 for mini-9pi, and fewer is a
# failure.
# usage: tests/kernels_ix.sh     (after make kernels-ix)

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd $ROOT
export PATH=$ROOT/bin:$PATH
W=$(mktemp -d); trap 'rm -rf $W' EXIT
(cd kernel/xv6 && true | mini-mk check > $W/xv6.log 2>&1) &
(cd kernel/9pi && true | mini-mk check > $W/9pi.log 2>&1) &
wait
failures=0
for k in xv6:6 9pi:13; do
  name=${k%:*}; want=${k#*:}
  grep -a '^ok ' $W/$name.log
  n=$(grep -ac '^ok ' $W/$name.log)
  if [ $n != $want ]; then
    echo "FAIL mini-$name by ix: $n of its $want checks pass"
    grep -av '^ok ' $W/$name.log | tail -15 | cut -c1-200
    failures=$((failures + 1))
  fi
done
echo "kernels-ix: $failures failure(s)"
[ $failures = 0 ]
