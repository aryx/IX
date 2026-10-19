#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-netscape's helper programs (Browser_helpers): fake ones on the
# PATH, each writing what it was given to a file -- mpv for a link to a
# film of YouTube's, clicked (given the address, the page staying);
# mini-page for a PDF file (given a file of its bytes); a program of
# ~/.mailcap's for a type of its own; a program of the profile's
# preferences, before the built-in one; and none at all with
# helpers=off.
# usage: browsers/netscape/tests/helpers.sh [dir]
#   dir: where the program is (default: dune's, _build/default/browsers)
cd "$(dirname "$0")/../../.."
D=${1:-_build/default/browsers}/netscape
N=$D/Netscape.exe; [ -x $N ] || N=$D/netscape
T=$(mktemp -d); trap 'rm -rf $T' EXIT
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok $1"; else echo "FAIL $1: $2, not $3"; fail=1; fi; }
mkdir -p $T/bin $T/home
for p in mpv mini-page show gv; do
  printf '#!/bin/sh\necho %s "$@" >> %s/said\n[ -f "$1" ] && head -c 5 "$1" >> %s/said && echo >> %s/said\nexit 0\n' $p $T $T $T > $T/bin/$p
  chmod +x $T/bin/$p
done
run() { HOME=$T/home PATH=$T/bin:$PATH $N worker=wait -fixed-time 1000 "$@" > /dev/null 2>&1; }
said() { cat $T/said 2>/dev/null | sed "s#$T#T#g; s#mini-netscape-[0-9-]*#F-#g" | tr '\n' ';'; rm -f $T/said; }

run -dump-frame 6 $T/a.ppm profile=off url=browsers/netscape/tests/pages/helpers.html -script 'at(-238;364):1-3,click:2'
check "a link to YouTube, clicked: mpv given the address" "$(said)" "mpv https://www.youtube.com/watch?v=x;"
run -dump-frame 3 $T/b.ppm profile=off url=lib_graphics/pdf/tests/data/shapes.pdf
check "a PDF file: mini-page given a file of its bytes" "$(said)" "mini-page /tmp/F-shapes.pdf;%PDF-;"
printf 'application/x-xtest; show %%s\n# a comment\n' > $T/home/.mailcap
run -dump-frame 3 $T/c.ppm profile=off 'url=data:application/x-xtest,hello'
check "a document of a type ~/.mailcap has: its program given a file of it" "$(said)" "show /tmp/F-x-xtest,hello;hello;"
mkdir -p $T/p; printf 'helper application/pdf gv %%s\n' > $T/p/preferences
run -dump-frame 3 $T/d.ppm profile=$T/p url=lib_graphics/pdf/tests/data/shapes.pdf
check "the profile's helper first, and kept in its preferences" "$(said)|$(cat $T/p/preferences)" "gv /tmp/F-shapes.pdf;%PDF-;|helper application/pdf gv %s"
run -dump-frame 3 $T/e.ppm profile=off helpers=off url=lib_graphics/pdf/tests/data/shapes.pdf
check "helpers=off: nothing run" "$(said)" ""
exit $fail
