#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-ml's parser over all of ix's .ml and .mli (plan_ml_bootstrap.md):
# each file that doesn't parse, with the line of its first error, then
# the counts by top directory.
# usage: parse_ix.sh [path-prefix...]

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
ML=${ML:-$ROOT/_build/default/languages/ml/Main.exe}
cd $ROOT
declare -A all bad
for f in $(git ls-files -- "$@" | grep -E '\.mli?$'); do
  d=${f%%/*}; all[$d]=$((${all[$d]:-0} + 1))
  err=$($ML -dast $f 2>&1 >/dev/null | grep -E 'syntax error|illegal|unterminated' | head -1)
  if [ -n "$err" ]; then
    bad[$d]=$((${bad[$d]:-0} + 1))
    l=$(echo "$err" | sed -E 's/^[^:]*:([0-9]+).*/\1/')
    echo "$f:$l: $(sed -n "${l}p" $f | cut -c1-120)"
  fi
done
for d in $(echo "${!all[@]}" | tr ' ' '\n' | sort); do
  printf "%-18s %4d files, %4d fail\n" $d ${all[$d]} ${bad[$d]:-0}
done
