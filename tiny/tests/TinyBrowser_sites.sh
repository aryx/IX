#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Live sites read by tiny-www: the ones mini-netscape's survey loads
# (browsers/survey/coverage_ix.sh) and a search (lite.duckduckgo.com).
# For each, in DIR: the page's lines at 80 columns as text (.txt, by
# TinyBrowser_tests/Host.exe, the page fetched by tiny-machine-fetch as
# www asks it), and www's screen after 40 s (.png, the native tiny-www
# without a window, its pictures as far as they came). Run before and
# after a change, then diff -r the two directories and look at the
# pictures. The sites change by themselves: run the two close together.
#
# usage: tiny/tests/TinyBrowser_sites.sh DIR [site...]
# needs: the network, ImageMagick's convert (the PNGs)

set -u
[ $# -ge 1 ] || { sed -n '5,15p' "$0"; exit 2; }
D=$(realpath -m $1); shift
cd "$(dirname "$0")/../.."
B=_build/default/tiny
dune build $B/tests/TinyBrowser_tests/Host.exe $B/TinyMachine/TinyMachineFetch.exe $B/sdl/www.exe || exit 1
SITES=${*:-"https://en.wikipedia.org/wiki/OCaml https://en.wikipedia.org/wiki/Plan_9_from_Bell_Labs
  https://news.ycombinator.com https://ocaml.org https://lwn.net https://old.reddit.com
  https://docs.python.org/3/tutorial/index.html https://www.craigslist.org/about/sites ?ocaml"}
mkdir -p $D
for u in $SITES; do
  n=$(echo "$u" | sed -E 's#https?://##; s#^\?#search_#; s#[/.?=&]+#_#g; s#_$##')
  # (www asks a Wikipedia article's REST HTML, a search DuckDuckGo's:
  # TinyMachinePeer.www_address)
  f=$(echo "$u" | sed -E 's#(wikipedia.org)/wiki/#\1/api/rest_v1/page/html/#; s#^\?#https://lite.duckduckgo.com/lite/?q=#')
  ( timeout 60 $B/TinyMachine/TinyMachineFetch.exe "$f" > $D/$n.html
    $B/tests/TinyBrowser_tests/Host.exe 80 $D/$n.html > $D/$n.txt
    echo "$n: $(wc -c < $D/$n.html) bytes, $(grep -c . $D/$n.txt) lines"
    SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy TINY_SCREEN=$D/$n.ppm \
      timeout 40 $B/sdl/www.exe "$u" < /dev/null > /dev/null 2>&1
    convert $D/$n.ppm $D/$n.png && rm -f $D/$n.ppm $D/$n.html ) &
done
wait
