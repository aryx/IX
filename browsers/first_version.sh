#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The base of docs/plans/plan_browser.md: mini-chrome's first commit
# (475a979, 2026-09-30: the playground's TinyChrome moved) with the
# playground of that hour (6154076a), which it stood on for its
# network, its pictures and its window. Both are taken out of their
# histories (git archive: neither checkout is touched) into DIR, built
# in one dune workspace, counted by survey.sh, and two sites loaded
# without a screen (SDL's dummy driver; Cairo's platform: the software
# one came two commits later), their frames written for a look.
#
# usage: browsers/first_version.sh DIR [mini-chrome [playground]]
#   DIR/mini-chrome, DIR/playground: the two trees, to read and copy from
#   DIR/*.png: the frames; DIR/survey.txt: the lines, by where they go

set -u
[ $# -ge 1 ] || { sed -n '5,18p' "$0"; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
D=$(realpath -m $1); M=${2:-$HOME/github/mini-chrome}; P=${3:-$HOME/playground}
MC=475a979; PC=6154076a
mkdir -p $D/mini-chrome $D/playground && cd $D || exit 1
git -C $M archive $MC | tar -x -C mini-chrome
git -C $P archive $PC | tar -x -C playground
rm -rf mini-chrome/bin; mkdir -p mini-chrome/tools   # survey.sh looks there
echo '(lang dune 3.0)' > dune-workspace
dune build mini-chrome/src/main 2>&1 | head -20
$HERE/survey.sh $D/mini-chrome $D/playground 2> /dev/null > survey.txt
grep -A1 '^== .*\(lib_\|browsers/\)' survey.txt | grep -v '^--' > /dev/null
awk '/^== (lib_|browsers\/)/ { t = $2 } /^ +[0-9]+ +[0-9]+ +all/ && t != "" { printf "  %-26s %6d .ml %6d .mli\n", t, $1, $2; t = "" }' survey.txt
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
for u in en.wikipedia.org/wiki/OCaml news.ycombinator.com; do
  n=$(echo ${u%%/*} | tr . _)
  s=$( { /usr/bin/time -f '%U s of processor, %M KB' timeout 300 _build/default/mini-chrome/src/main/MiniChrome.exe \
      -size 1400x900 -dump-frame 420 $n.png url=https://$u > /dev/null 2> $n.err; } 2>&1 | tail -1)
  echo "  $u: $D/$n.png, $(tail -1 $n.err)"
done
