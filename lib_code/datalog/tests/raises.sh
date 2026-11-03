#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze -bugs on mini-ml's runtime (runtime.c, its parts included)
# and lib_core's units with externals: each external's [@@raise E]
# against what its C raises (lib_code/datalog/bugs/raises.dl), the
# report against raises_ix.txt. An annotation the C does not back fails;
# one added, or a C raise added, is -record'ed. A second.
# usage: lib_code/datalog/tests/raises.sh [-record]   (dune build first)
# ANALYZE: the program, if not dune's.
cd "$(dirname "$0")/../../.."
ANALYZE=${ANALYZE:-_build/default/analyzers/Main.exe}
T=lib_code/datalog/tests
L=lib_core/libc/include
ml=$(grep -rl '^external' lib_core --include=*.ml | grep -v 'dotnet\|plan9\|tests' | sort)
out=$($ANALYZE -bugs -I $L -I $L/arch/arm -I $L/utf -I languages/ml/runtime languages/ml/runtime/runtime.c $ml 2>&1)
if [ "${1:-}" = -record ]; then echo "$out" > $T/raises_ix.txt; echo "recorded $T/raises_ix.txt"
elif [ "$out" = "$(cat $T/raises_ix.txt)" ]; then echo "ok raises: lib_core's externals against the runtime's C ($(tail -1 $T/raises_ix.txt))"
else echo "FAIL raises: not raises_ix.txt"; diff $T/raises_ix.txt <(echo "$out") | head -10; exit 1; fi
