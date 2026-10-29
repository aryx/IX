#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What of browsers/ itself the chosen sites run (docs/plans/plan_browser.md,
# "Smaller"): coverage.sh measured mini-chrome's tree before the copy;
# this measures ix's. The libraries browsers/ stands on and browsers/ are
# copied to a directory (the checkout is not touched: other sessions
# build in it), browsers/'s libraries given bisect_ppx's instrumentation,
# and each site loaded by mini-netscape without a window, with scripts
# and without, its first screen and a page scrolled to the end; and by
# mini-lynx. coverage.py then says, for each file, the definitions never
# run, without scripts and with them; coverage_sites.py, what each site's
# scripts reach beyond what a page of one line of script does.
#
# usage: browsers/survey/coverage_ix.sh [-v] DIR [site...]
#   DIR:  the copy, its build and the runs (kept; again: the runs only,
#         after the copy refreshed)
#   site: an address (default: the list below)
#   -v:   each definition never run, by file
# needs: bisect_ppx in the opam switch (4.14.2 has it), the network

set -u
V=; [ "${1:-}" = -v ] && { V=-v; shift; }
[ $# -ge 1 ] || { sed -n '5,22p' "$0"; exit 2; }
HERE=$(cd "$(dirname "$0")/../.." && pwd)
D=$(realpath -m $1); shift
SITES=${*:-"https://en.wikipedia.org/wiki/OCaml https://en.wikipedia.org/wiki/Plan_9_from_Bell_Labs
  https://news.ycombinator.com https://ocaml.org https://lwn.net https://old.reddit.com
  https://docs.python.org/3/tutorial/index.html https://www.craigslist.org/about/sites"}
mkdir -p $D && cd $D || exit 1

# the copy: tracked and untracked files, not ignored ones
(cd $HERE && git ls-files --cached --others --exclude-standard dune-project \
   lib_core lib_crypto lib_networking lib_compression lib_graphics lib_playground \
   lib_audio lib_gui lib_physics lib_terminal browsers) |
  rsync -a --files-from=- $HERE/ src/
echo '(lang dune 3.7)' > src/dune-workspace
for f in $(grep -rl -E '^\((library|executables?)\s*$' --include=dune src/browsers | grep -v /tests/); do
  grep -q bisect_ppx $f || sed -i -E 's/^\((library|executables?)\s*$/&\n (instrumentation (backend bisect_ppx))/' $f
done
(cd src && dune build --root . --instrument-with bisect_ppx browsers/netscape/Netscape.exe browsers/lynx/Lynx.exe 2>&1 | head -20)
B=$D/src/_build/default/browsers
[ -x $B/netscape/Netscape.exe ] || { echo "no build"; exit 1; }

rm -rf runs
mkdir -p runs/0-on-first   # the baseline: what every page's scripts reach (coverage_sites.py)
(cd runs/0-on-first && BISECT_FILE=$PWD/b $B/netscape/Netscape.exe -dump-frame 20 page.ppm -fixed-time 1000 \
   'url=data:text/html,<p>x<script>var a=1</script>' scripts=on profile=off > out.txt 2>&1)
run() {   # dir, url, scripts, frame, script
  mkdir -p runs/$1
  (cd runs/$1 && BISECT_FILE=$PWD/b timeout 600 $B/netscape/Netscape.exe -dump-frame $4 page.ppm -fixed-time 1000 \
     ${5:+-script "$5"} url=$2 scripts=$3 profile=off window=1400x900 console=on > out.txt 2>&1
   echo "  $1: page.ppm $(stat -c %s page.ppm 2> /dev/null) bytes, $(grep -ci error out.txt) lines saying error")
}
keys=$(for i in $(seq 260 6 560); do printf 'space:%d,' $i; done)
n=0
for u in $SITES; do
  n=$((n+1))
  for m in off on; do
    run $n-$m-first $u $m 250 "" &
    run $n-$m-scroll $u $m 600 "${keys%,}" &
  done
  mkdir -p runs/$n-lynx
  (cd runs/$n-lynx && BISECT_FILE=$PWD/b timeout 120 $B/lynx/Lynx.exe $u > out.txt 2>&1) &
  echo "$n $u" >> runs/sites.txt
  wait
done

cd src
off=$(for r in ../runs/*-off-* ../runs/*-lynx; do printf -- '--coverage-path %s ' $r; done)
on=$(for r in ../runs/*-on-*; do printf -- '--coverage-path %s ' $r; done)
bisect-ppx-report coveralls ../off.json $off
bisect-ppx-report coveralls ../on.json $off $on
for f in $(find browsers -name '*.ml' -not -path '*/tests/*' -not -path '*/sdl/*' | sort); do
  echo "$(dirname $f) $f"
done > ../sets.txt
python3 $HERE/browsers/survey/coverage.py $V ../sets.txt ../off.json ../on.json
for n in $(seq 0 $(wc -l < ../runs/sites.txt)); do
  bisect-ppx-report coveralls ../on$n.json $(for r in ../runs/$n-on-*; do printf -- '--coverage-path %s ' $r; done)
done
python3 $HERE/browsers/survey/coverage_sites.py ..
