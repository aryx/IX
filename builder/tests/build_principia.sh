#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Principia built for real, twice: "mk; mk install; mk kernel" with
# goken's mk, then with mini-mk as mk (every mk a recipe calls is then
# mini-mk too), and every file of the two trees compared by its SHA-256.
#
#   build_principia.sh [pc|pi] [~/principia]
#
# The compilers and rc are goken's in both, and both trees are built at
# the same path, one after the other, because the objects hold their
# sources' paths. The source is principia's HEAD (git archive), so
# nothing is written in principia itself. What is left to differ is
# what holds the time, the kernel's KERNDATE and mothra's version, and
# one byte in a few libraries: goken's iar pads a member of odd size
# with a byte it never sets (the same objects archived twice by hand
# differ so too).
# Prints the two builds' statuses, the files' count and the ones that
# differ, each with how many of its bytes do; the logs and the trees
# stay in $OUT (default /tmp/build_principia).

TARGET=${1:-pc}
SRC=${2:-$HOME/principia}
HERE=$(cd "$(dirname "$0")/../.." && pwd)
MINIMK=${MINIMK:-$HERE/_build/default/builder/Main.exe}
GOKEN=${GOKEN:-$HOME/goken}
OUT=${OUT:-/tmp/build_principia}
rm -rf "$OUT"; mkdir -p "$OUT/minibin"
cp "$MINIMK" "$OUT/minibin/mk"

export MKSHELL=$GOKEN/bin/rc
export NPROC=${NPROC:-$(nproc)}
TOOLS=$GOKEN/bin:$GOKEN/ROOT/arch/boot-gcc/bin

for w in ref mini; do
  rm -rf "$OUT/work"; mkdir "$OUT/work"
  (cd "$SRC" && git archive HEAD) | tar -x -C "$OUT/work"
  ( cd "$OUT/work" || exit 1
    if [ $w = mini ]; then PATH=$OUT/minibin:$TOOLS:$PATH; else PATH=$TOOLS:$PATH; fi
    export PATH
    cp mkconfig.$TARGET mkconfig
    st=""
    mk; st="$st all:$?"; mk install; st="$st install:$?"; mk kernel; st="$st kernel:$?"
    echo "$st" > "$OUT/$w.st" ) > "$OUT/$w.log" 2>&1
  echo "$w ($(PATH=$( [ $w = mini ] && echo "$OUT/minibin:" )$TOOLS:$PATH command -v mk)):$(cat "$OUT/$w.st")"
  (cd "$OUT/work" && find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$OUT/$w.sha"
  rm -rf "$OUT/$w.tree"; mv "$OUT/work" "$OUT/$w.tree"
done

echo "files: $(wc -l < "$OUT/ref.sha") and $(wc -l < "$OUT/mini.sha"), $( (cd "$SRC" && git archive HEAD) | tar -t | grep -vc '/$') in the source"
diff "$OUT/ref.sha" "$OUT/mini.sha" | grep '^[<>]' | awk '{print $3}' | sort -u > "$OUT/differ"
echo "differ: $(wc -l < "$OUT/differ")"
while read -r f; do
  echo "$f: $(cmp -l "$OUT/ref.tree/$f" "$OUT/mini.tree/$f" 2>/dev/null | wc -l) bytes"
done < "$OUT/differ"
