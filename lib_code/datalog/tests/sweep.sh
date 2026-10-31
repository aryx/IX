#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze -dead on every program with a mkfile's SRC, a report each
# and a line each: what is dead in that program's own units. Its units
# and -I's are the mkfile's. A unit's file: in the program's directory or
# its -I's, then _mk/7's (a generated lexer or parser), then anywhere under
# the directory, then the one of that name elsewhere in the tree. exit 0
# only: another's report is of a program partly read, and what the units
# not read call looks dead. Minutes: by hand, not in make test.
# usage: lib_code/datalog/tests/sweep.sh out-dir [limit-seconds]   (dune build, make first)
# ANALYZE: the program, if not dune's.
cd "$(dirname "$0")/../../.."
out=$1; limit=${2:-180}
export ANALYZE=${ANALYZE:-$PWD/_build/default/analyzers/Main.exe}
mkdir -p $out
git ls-files '*.ml' > $out/.all

# a mkfile's variable, its \-lines joined, $names inside it expanded
var() { # mkfile name
  local line v
  line=$(sed -e ':a' -e '/\\$/N; s/\\\n//; ta' "$1" | grep -E "^$2 ?=" | head -1 | sed -E "s/^$2 ?= ?//")
  while [[ $line =~ \$([A-Za-z_]+) ]]; do
    v=$(var "$1" "${BASH_REMATCH[1]}")
    line=${line//\$${BASH_REMATCH[1]}/$v}
  done
  echo "$line"
}

unit_file() { # directory, -I's, unit
  local d f
  for d in $1 $2 _mk/7/$1; do
    [ -f $d/$3.ml ] && { echo $d/$3.ml; return; }
  done
  f=$(find $1 -name "$3.ml" 2> /dev/null | head -1)
  [ -z "$f" ] && f=$(grep -E "/$3\.ml$" $out/.all | head -1)
  echo $f
}

one() { # a mkfile
  local mk=$1 dir=$(dirname $1) name files u f missing= incs= flags= i
  name=$(echo $dir | tr / _)
  for i in $(var $mk LIBI); do
    [ "$i" = -I ] || { i=$(realpath --relative-to=. $dir/$i); incs="$incs $i"; flags="$flags -I $i"; }
  done
  local src=$(var $mk SRC)
  case $src in *'`'*) printf '%-44s computed SRC, not analysed\n' $dir; return;; esac
  for u in $src; do
    f=$(unit_file $dir "$incs" $u)
    if [ -n "$f" ]; then files="$files $f"; else missing="$missing $u"; fi
  done
  echo $files > $out/$name.files
  local t0=$(date +%s)
  (ulimit -v 12000000; timeout $limit $ANALYZE -dead -L lib_core $flags $files) > $out/$name.out 2> $out/$name.err
  local st=$? t1=$(date +%s)
  if [ $st = 0 ]; then
    printf '%-44s %4ds %s%s\n' $dir $((t1 - t0)) "$(tail -1 $out/$name.out | sed -E 's/, 0 only through a pointer//' | cut -c1-90)" "${missing:+ missing:$missing}"
  else
    printf '%-44s %4ds NOT READ (exit %d): %s\n' $dir $((t1 - t0)) $st "$(head -1 $out/$name.err | cut -c1-80)"
  fi
}
export -f one unit_file var
export out limit
git grep -lE '^SRC ?=' -- '*mkfile' | xargs -P 8 -n 1 bash -c 'one "$0"' | sort | tee $out/SUMMARY
