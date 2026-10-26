#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Tests the part of TinyBrowser that reads a page and turns it into
# lines, printed as text by TinyBrowser_tests/Testutil_browser.ml.
# - On the host, built by OCaml (TinyBrowser_tests/Host.ml): the lines of
#   each page are compared with its .expected file. tags.html and
#   table.html are read at 40 columns (what each tag does, the
#   characters, the tables), and Wikipedia's OCaml article at 80
#   columns (www/OCaml.html, its REST HTML fetched on 2026-10-15; see
#   plan_tiny_browser.md). Then each page is read again in messages of
#   1, 7 and 1000 bytes, and must give the same lines however it is cut.
# - On tiny-cpu, built by tiny-ml (TinyBrowser_tests/Tm.ml, with
#   tm.c, heap.c and read.tm): the lines must be the same as OCaml's.
#   This runs in tiny-cpu's 1 MB of memory, with heap halves of 352 KB,
#   which the OCaml article fits in.
# RECORD=1 records the expected lines again (check them first).
# usage: TinyBrowser_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOST=${HOST:-$ROOT/_build/default/tiny/tests/TinyBrowser_tests/Host.exe}
TML=${TML:-$ROOT/_build/default/tiny/TinyML.exe}
TC=${TC:-$ROOT/_build/default/tiny/TinyC.exe}
CPU=${CPU:-$ROOT/_build/default/tiny/TinyCPU.exe}
. $ROOT/tiny/tests/link.sh
T=$ROOT/tiny/tests/TinyBrowser_tests
B=$ROOT/tiny/TinyBrowser
L=$ROOT/tiny/TinyCRuntime
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

# each page as file:width:name
PAGES="$T/tags.html:40:tags $T/table.html:40:table $ROOT/tiny/tests/www/OCaml.html:80:OCaml"

for p in $PAGES; do
  IFS=: read -r page width name <<< "$p"
  $HOST $width $page > $W/$name.out || fail "$name: the run"
  [ -n "${RECORD:-}" ] && cp $W/$name.out $T/$name.expected
  if cmp -s $W/$name.out $T/$name.expected; then echo "ok $name: its lines"; else fail "$name: its lines"; diff $T/$name.expected $W/$name.out | head -10; fi
  for size in 1 7 1000; do
    $HOST $width $page $size > $W/$name.$size.out
    if cmp -s $W/$name.out $W/$name.$size.out; then echo "ok $name: in messages of $size"; else fail "$name: in messages of $size"; diff $W/$name.out $W/$name.$size.out | head -6; fi
  done
done

# On tiny-cpu. The runtime and main are linked first, then the program,
# then the heap's arrays. In the other order, main would be too far
# for the start's call to reach it (a jump reaches 32K words).
if ml_lib $W/lib && $TML -L $W/lib -o $W/b.tm $B/TinyBrowserText.ml $B/TinyBrowserTokens.ml $B/TinyBrowserLines.ml $B/TinyBrowserPage.ml $T/Testutil_browser.ml $T/Tm.ml \
   && $TC -o $W/tm.tm $T/tm.c && $TC -o $W/heap.tm $T/heap.c && $TC -o $W/libc.tm $L/libc.c \
   && link_tm $W/b.img $L/start.tm $L/udivmod.tm $T/read.tm $W/libc.tm $W/tm.tm $W/b.tm $W/heap.tm $LIB_O; then
  for p in $PAGES; do
    IFS=: read -r page width name <<< "$p"
    timeout ${SLOW:-120} $CPU $W/b.img $width < $page > $W/$name.tm.out 2>&1
    if cmp -s $W/$name.out $W/$name.tm.out; then echo "ok $name: on tiny-cpu"; else fail "$name: on tiny-cpu"; diff $W/$name.out $W/$name.tm.out | head -6; fi
  done
else
  fail "tiny-ml: the build"
fi

echo "$failures failure(s)"
[ $failures = 0 ]
