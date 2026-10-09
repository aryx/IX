#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Stage 1 of docs/plans/plan_browser.md: what of mini-chrome a
# Wikipedia article runs. mini-chrome and the playground are copied
# to a directory (neither is touched), each library given bisect_ppx's
# instrumentation, built in one dune workspace (so the playground's
# modules are counted too, not opam's), and the article loaded by
# mini-chrome-software without a screen (SDL's dummy driver), by
# mini-curl and by mini-lynx. coverage.py then says, for each file of
# survey.sh's sets, the definitions never run.
#
# The runs, each without scripts and with them (threads=off, cache=off:
# what the plan keeps):
#   first:  1000x700, the first screen (one column)
#   scroll: the same, a page down 56 times, to the article's end
#   wide:   1400x900 (the three columns: the grid)
#   act:    1400x900, a link clicked, then the Search button
# Not run, so the report says nothing true of them: a text typed in a
# field and a form sent (-script's keys did not reach the field: Forms'
# submission, Browser_forms), Back and Forward (the window's, not
# copied), a page of http:// (Http_request).
#
# usage: browsers/coverage.sh [-v] DIR [mini-chrome [playground]]
#   DIR: where the copy, its build and the runs go (kept: 700 MB);
#        with a build there already, only the runs and the report
#   -v:  each definition never run, by file
# needs: bisect_ppx in the opam switch (4.14.2 has it), the network

set -u
V=; [ "${1:-}" = -v ] && { V=-v; shift; }
[ $# -ge 1 ] || { sed -n '5,30p' "$0"; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
D=$(realpath -m $1); M=${2:-$HOME/github/mini-chrome}; P=${3:-$HOME/playground}
U=https://en.wikipedia.org/wiki/OCaml
mkdir -p $D && cd $D || exit 1

if [ ! -d mini-chrome ]; then
  rsync -a --exclude=_build --exclude=_build5 --exclude=.git $M/ mini-chrome/
  rsync -aL --exclude=_build --exclude=.git --exclude='*.mp4' $P/ playground/
  rm -f mini-chrome/bin   # a link into mini-chrome's own _build
  echo '(lang dune 3.0)' > dune-workspace
  for f in $(grep -rl -E '^\((library|executables?)\s*$' --include=dune \
      mini-chrome/languages mini-chrome/libs mini-chrome/src mini-chrome/tools playground/libs playground/playground); do
    sed -i -E 's/^\((library|executables?)\s*$/&\n (instrumentation (backend bisect_ppx))/' $f
  done
fi
dune build --instrument-with bisect_ppx mini-chrome/src/main mini-chrome/tools 2>&1 | head -20
B=$D/_build/default/mini-chrome
[ -x $B/src/main/software/MiniChrome.exe ] || { echo "no build"; exit 1; }

export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
rm -rf runs
run() {   # name, scripts, size, last frame, script
  mkdir -p runs/$1-$2
  (cd runs/$1-$2 && BISECT_FILE=$PWD/b timeout 400 $B/src/main/software/MiniChrome.exe -size $3 -dump-frame $4 page.png \
     ${5:+-script "$5"} -v url=$U profile=off cache=off threads=off scripts=$2 > out.txt 2>&1
   echo "  $1-$2: $(grep -c ' GET ' out.txt) requests, page.png $(stat -c %s page.png 2> /dev/null) bytes")
}
keys=$(for i in $(seq 430 12 1100); do printf 'space:%d,' $i; done)
for m in off on; do
  run first $m 1000x700 420 "" &
  run scroll $m 1000x700 1120 "${keys%,}" &
  run wide $m 1400x900 420 "" &
  # the mouse's place is from the window's middle, y up
  run act $m 1400x900 1300 "at(-171;90):421-600,click:430,at(157;343):801-1000,click:810" &
done
wait
mkdir -p runs/curl runs/lynx
(cd runs/curl && BISECT_FILE=$PWD/b $B/tools/curl/MiniCurl.exe -v -o page.html $U > out.txt 2>&1)
(cd runs/lynx && BISECT_FILE=$PWD/b $B/tools/lynx/MiniLynx.exe -dump $U > out.txt 2>&1)

src="--source-path . --source-path _build/default"
off=$(for r in first-off scroll-off wide-off act-off curl lynx; do printf -- '--coverage-path runs/%s ' $r; done)
on=$(for r in first-on scroll-on wide-on act-on; do printf -- '--coverage-path runs/%s ' $r; done)
bisect-ppx-report coveralls off.json $off $src
bisect-ppx-report coveralls on.json $off $on $src
$HERE/survey.sh -files $D/sets.txt $M $P > /dev/null
python3 $HERE/coverage.py $V sets.txt off.json on.json
