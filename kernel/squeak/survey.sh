#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/plan_system_squeak.md: the author's
# Smalltalk in his playground (languages/smalltalk: the Blue Book's
# virtual machine in OCaml, its kernel and Squeak's Morphic in
# Smalltalk; apps/devtools/TinySqueak.ml, its host), their lines, what
# the machine asks of a host, what mini-ml says of each file, how fast
# it runs there; and what of ix a mini-squeak would stand on.
# usage: kernel/squeak/survey.sh [dir]
#   dir: the playground (default: ~/playground)

cd "$(dirname "$0")"
P=${1:-$HOME/playground}
S=$P/languages/smalltalk
T=../..
[ -d $S ] || { echo "no $S"; exit 1; }

echo "== the virtual machine (languages/smalltalk: OCaml)"
wc -l $S/St_*.ml | sort -rn | sed "s|$S/||;s/^/  /"
echo "  interfaces: $(cat $S/St_*.mli | wc -l) lines; Highlight_st (not the machine's): $(cat $S/Highlight_st.ml | wc -l)"
echo "== the system (Smalltalk, bootstrapped from its text)"
for d in kernel kernel/squeak kernel/morphic; do printf "%7d %s: %s\n" $(cat $S/$d/*.st | wc -l) $d "$(cd $S/$d && wc -l *.st | sed '$d' | awk '{ printf "%s %d  ", $2, $1 }')"; done
echo "== its hosts and tests"
wc -l $P/apps/devtools/TinySqueak.ml $P/apps/devtools/TinySmalltalk80.ml $S/tests/Unit_squeak.ml $S/tests/Unit_smalltalk.ml | sed '$d' | sed "s|$P/||;s/^/  /"
echo "  what the machine asks of a host (St_interp.mli's host): $(sed -n '/^type host = {/,/^}/p' $S/St_interp.mli | grep -o '^  [a-z_]* :' | tr -d ' :' | tr '\n' ' ')"
echo "  of the system under it: $(grep -ho 'Sys\.[a-z_]*\|Unix\.[a-z_]*\|open_in[a-z_]*\|In_channel\.[a-z_]*\|Random\.[a-z_]*' $S/St_*.ml | sort -u | tr '\n' ' ')"
echo "  floats: $(grep -ho 'Float\.[a-z_]*\|Int64\.[a-z_]*of_float\|Int64\.float_of_bits' $S/St_*.ml | sort -u | tr '\n' ' ')"
echo "== mini-ml on each file of the machine (the first thing it refuses)"
inc="-I $S"; for d in system core base collections printing parsing concurrency; do inc="$inc -I $T/lib_core/$d"; done
ok=0
for f in $S/St_*.ml; do
  err=$($T/bin/mini-ml -m 7 -o /dev/null $inc $f 2>&1 > /dev/null | head -1)
  if [ -z "$err" ]; then ok=$((ok + 1)); else
    n=$(echo "$err" | grep -o ':[0-9]*:' | head -1 | tr -d ':')
    printf "  %-18s %s | %s\n" $(basename $f) "$(echo "$err" | sed 's/^[^ ]*: *//' | cut -c1-40)" "$(sed -n ${n:-1}p $f | sed 's/^ *//' | cut -c1-60)"
  fi
done
echo "  $ok of $(ls $S/St_*.ml | wc -l) compile"
echo "  optional arguments: $(grep -c '?(\|?[a-z_]* ' $S/St_*.ml | awk -F: '$2 > 0' | wc -l) files; polymorphic variants: $(grep -l '\[ *`\|`[A-Z][a-z]* ' $S/St_*.ml | wc -l) files"
echo "== how fast, by ocamlopt on this machine (tests/bench, when built)"
B=$P/_build/default/languages/smalltalk/tests/bench/St_bench.exe
[ -x $B ] && timeout 300 $B 2> /dev/null | grep -E '^(morphic +50|morphs +(nothing|50 atoms|a window)|tools +(the Browser|a selector|a character|print it)|blue book +sends|squeak)' | sed 's/^/  /'
echo "== ix: what a mini-squeak would stand on"
echo "  the floating point in a kernel: $(grep -c 'floating point\|VFP' ../lib_machine/pi4/l.s ../lib_machine/pi1/l.s | tr '\n' ' ')(lines of the boots that turn it on)"
echo "  the framebuffer's depths in mini-qemu: $(grep -o '| 16 ->\|get_int32_le' $T/raspberry/Framebuffer.ml | tr '\n' ' ')"
wc -l ../oberon/display/Input.ml ../lib_machine/Usbhost.ml ../oberon/Main.ml | sed '$d' | sed 's/^/  /'
