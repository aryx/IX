#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-open: fake programs on the PATH, each writing what it was given;
# a file by its kind, whatever its name, ~/.mailcap's rule first, what
# has no program said.
# usage: apps/files/tests/open.sh [dir]
#   dir: where the program is (default: dune's, _build/default/apps)
cd "$(dirname "$0")/../../.."
D=${1:-_build/default/apps}/files
O=$D/Open.exe; [ -x $O ] || O=$D/open
O=$PWD/$O
T=$(mktemp -d); trap 'rm -rf $T' EXIT
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok $1"; else echo "FAIL $1: $2, not $3"; fail=1; fi; }
mkdir -p $T/bin $T/home
for p in mini-page mini-play mini-netscape mini-emacs feh; do
  printf '#!/bin/sh\necho %s "$@" > %s/said\n' $p $T > $T/bin/$p
  chmod +x $T/bin/$p
done
run() { HOME=$T/home PATH=$T/bin:/usr/bin:/bin $O "$@" 2>&1; }
# (the program is not waited for: up to 3 s for what it wrote)
said() { local i; for i in $(seq 30); do [ -f $T/said ] && break; sleep 0.1; done; cat $T/said 2>/dev/null | sed "s#$T#T#g"; rm -f $T/said; }
cp lib_graphics/pdf/tests/data/shapes.pdf $T/a.pdf
run $T/a.pdf; check "a PDF file: mini-page given it" "$(said)" "mini-page T/a.pdf"
cp browsers/netscape/tests/pages/colors.png $T/lies.mp3
run $T/lies.mp3; check "a PNG named .mp3: mini-page, the bytes first" "$(said)" "mini-page T/lies.mp3"
cp lib_audio/tests/data/bell.mp2 $T/noname
run $T/noname; check "an MP2 with no extension: mini-play" "$(said)" "mini-play T/noname"
cp browsers/engine/tests/pages/small.html $T/p.html
run $T/p.html; check "HTML: mini-netscape" "$(said)" "mini-netscape T/p.html"
echo hello > $T/notes
run $T/notes; check "text: mini-emacs" "$(said)" "mini-emacs T/notes"
check "-n: the kind and the command, nothing run" "$(run -n $T/notes | sed "s#$T#T#g")|$(said)" "text/plain: mini-emacs T/notes|"
printf 'image/*; feh %%s\n' > $T/home/.mailcap
run $T/lies.mp3; check "~/.mailcap's rule first" "$(said)" "feh T/lies.mp3"
printf '\001\002\003' > $T/data
check "what has no program: said, and a failure" "$(run $T/data | sed "s#$T#T#g"; echo ${PIPESTATUS[0]})" "mini-open: T/data: no program for application/octet-stream
1"
exit $fail
