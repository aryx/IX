#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What mini-netscape's optimizations buy (docs/plans/plan_browser.md,
# 2026-10-11): a page loaded with each switch off in turn, then with
# all on, the seconds and the frame's sum (the same picture is the
# check that a fast path is its simple one). Not a test: the page is
# the live one by default, and the clock is the machine's.
#   keep=off     a connection a request        (Keep_alive)
#   settle=off   a layout at each script task  (Tab.settle)
#   draw=all     every line's shapes at once   (Browser_draw.later)
#   view=each    the view made at each frame   (Netscape.view)
# usage: browsers/netscape/tests/perf.sh [-callgrind] [url [frames [dir]]]
#   -callgrind: one load under valgrind instead, and where its
#     instructions go: the functions by their own cost, and who calls
#     the comparison of any two values (List.mem, List.assoc_opt: the
#     usual finding)
#   dir: where the program is (default: dune's, _build/default/browsers)
cd "$(dirname "$0")/../../.."
CG=; [ "$1" = -callgrind ] && { CG=1; shift; }
URL=${1:-https://en.wikipedia.org/wiki/OCaml}; FRAMES=${2:-250}
D=${3:-_build/default/browsers}/netscape
N=$D/Netscape.exe; [ -x $N ] || N=$D/netscape
T=$(mktemp -d); trap 'rm -rf $T' EXIT
run() { $N -dump-frame $FRAMES $T/f.ppm -fixed-time 1000 worker=wait profile=off url=$URL "$@" > /dev/null 2> $T/err; }
if [ -n "$CG" ]; then
  valgrind --tool=callgrind --callgrind-out-file=$T/cg.out $N -dump-frame $FRAMES $T/f.ppm -fixed-time 1000 worker=wait profile=off url=$URL > /dev/null 2> $T/log
  grep "refs" $T/log
  exec python3 browsers/netscape/tests/callgrind_top.py $T/cg.out 30 "caml_c_call [" "List__mem_607 " "List__assoc_opt_623 "
fi
for off in keep=off settle=off draw=all view=each ""; do
  /usr/bin/time -f "%e %U %M" -o $T/time bash -c "$(declare -f run); N=$N FRAMES=$FRAMES T=$T URL=$URL run $off"
  read real user kb < $T/time
  printf "%-11s %6.2f s  %6.2f s of processor  %4d MB  frame %s\n" "${off:-all on}" $real $user $((kb / 1024)) "$(cksum < $T/f.ppm | cut -d' ' -f1)"
done
