#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-singml's check. The Pong contract's module made from its
# declaration (tests/Pong.contract) against the one written by hand
# (../contracts/Pong.ml): the same states, the same interface but for
# the comments, and mini-singularity's programs compile with it in the
# hand-written one's place. Then the declarations that are refused
# (tests/bad/), each with its message (tests/bad.expected).
# usage: tests/check.sh [mini-singml]     (default: the installed one; mini-ml too)
cd "$(dirname "$0")/.."
S=${1:-mini-singml}
T=$(mktemp -d); trap 'rm -rf $T' EXIT
K=..; L=../../../lib_core
I="-I $K/lib $(for d in system core base collections printing parsing concurrency; do echo -I $L/$d; done)"
fail=0
ok() { echo "ok mini-singml: $1"; }
no() { echo "FAIL mini-singml: $1"; fail=1; }

$S -o $T tests/Pong.contract > /dev/null && $S -o $T $K/contracts/Intro.contract > /dev/null || { no "Pong and Intro made"; exit 1; }

# the states: the lines of the contract's second table, a state each
states() { sed -n '/^    \[|$/,/^    |\]$/p' $1 | grep '^ *\((\* [0-9]* \*) \)\?("' | sed 's/(\* [0-9]* \*) //; s/^ *//'; }
diff <(states $T/Pong.ml) <(states $K/contracts/Pong.ml) && ok "the made Pong's states are the hand-written one's" || no "Pong's states"

# the interface: the values, types and modules, without the comments or the blank lines
interface() { perl -0pe 's/\(\*.*?\*\)//gs' $1 | sed 's/^ *//; s/ *$//' | grep -v '^$' | tr '\n' ' ' | sed 's/  */ /g; s/ | / /g; s/= | /= /g' | tr ' ' '\n' | grep -v '^|$' | tr '\n' ' '; }
[ "$(interface $T/Pong.mli)" = "$(interface $K/contracts/Pong.mli)" ] && ok "the made Pong's interface is the hand-written one's" || { no "Pong's interface"; diff <(interface $T/Pong.mli | tr ' ' '\n') <(interface $K/contracts/Pong.mli | tr ' ' '\n'); }

# the programs, compiled against the made modules
good=1
for m in Pong Intro; do mini-ml -m 7 -I $T $I -o $T/$m.7 $T/$m.ml || good=0; done
for p in $K/programs/*/Main.ml; do mini-ml -m 7 -I $T $I -o $T/p.7 $p || good=0; done
[ $good = 1 ] && ok "the made modules and the $(ls -d $K/programs/* | wc -l) programs compile" || no "the programs with the made modules"

# what is refused, and why
for f in tests/bad/*.contract; do $S -o $T $f 2>&1; done > $T/bad.txt
diff $T/bad.txt tests/bad.expected && ok "$(ls tests/bad/*.contract | wc -l) declarations refused, each with its message" || no "the refusals"
exit $fail
