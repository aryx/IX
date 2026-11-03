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
# usage: analyzers/datalog/tests/sweep.sh out-dir [limit-seconds]   (dune build, make first)
# ANALYZE: the program, if not dune's.
cd "$(dirname "$0")/../../.."
out=$1; limit=${2:-180}
export ANALYZE=${ANALYZE:-$PWD/_build/default/analyzers/Main.exe}
mkdir -p $out

. analyzers/datalog/tests/mk_units.sh

one() { # a mkfile
  local mk=$1 dir=$(dirname $1) name files flags
  name=$(echo $dir | tr / _)
  case "$(var $mk SRC)$(var $mk UNITS)" in *'`'*'`'*) printf '%-44s computed units, not analysed\n' $dir; return;; esac
  read flags files < <(program_args $mk)
  flags=${flags//,/ }
  # (a unit missing: what it calls would look dead, as in a unit not read)
  local missing=$(missing_units $mk | tr '\n' ' ')
  if [ -n "$missing" ]; then printf '%-44s    - NOT READ: no file for %s\n' $dir "$missing"; return; fi
  echo $files > $out/$name.files
  local t0=$(date +%s)
  (ulimit -v 12000000; timeout $limit $ANALYZE ${FLAG:--dead} -L lib_core $flags $files) > $out/$name.out 2> $out/$name.err
  local st=$? t1=$(date +%s)
  if [ $st = 0 ]; then
    printf '%-44s %4ds %s\n' $dir $((t1 - t0)) "$(tail -1 $out/$name.out | sed -E 's/, 0 only through a pointer//' | cut -c1-90)"
  else
    printf '%-44s %4ds NOT READ (exit %d): %s\n' $dir $((t1 - t0)) $st "$(head -1 $out/$name.err | cut -c1-80)"
  fi
}
export -f one
export out limit FLAG
for mk in $(git grep -lE '^SRC ?=' -- '*mkfile'); do
  needs_gen $mk && (cd $(dirname $mk) && MKSHELL=mini-rc PATH=$PWD/../../bin:$OLDPWD/bin:$PATH timeout 600 mini-mk > /dev/null 2>&1)
done
git grep -lE '^SRC ?=' -- '*mkfile' |  xargs -P 8 -n 1 bash -c '. analyzers/datalog/tests/mk_units.sh; one "$0"' | sort | tee $out/SUMMARY
