#!/usr/bin/env bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze FLAG on a system's programs, each read as its build links
# it (its manifest), by one mini-analyze call; its reports once, sorted,
# against its recording (FLAG_SYSTEM.txt: caps_ix.txt, dead_tiny.txt...),
# without line numbers (an edit above a function moves it); -exn's by
# program, lib_core's exceptions every program may raise left out
# (compare.sh's exn_lines). The reports are known ones, read
# (analyzers/datalog/README.md): a new one fails, the day it comes.
# - tiny: t-IX's build, TIX (tiny/: make in tiny/ first; make test's
#   own, O=dir's dir/src), tiny-ld's manifests, its kernel among them,
#   and the executables dune builds under tiny/ (_build/default/tiny:
#   Dune_manifest); paths from tiny/ (-project tiny);
# - ix: ix's build, MK (_mk/7: make ix first; make test's own), mini-ld's
#   manifests, mini-9pi's kernel when built; a generated file by its
#   place in _mk/7, wherever MK is. A build of a part (make test's): a
#   recorded line of a file no manifest names, of a program not built,
#   or not given by it, not known there; a new line fails all the same.
# With no out-file, the reports on the standard output; -v: what is
# read, the directory made and removed.
# (old: tiny_check.sh and ix_check.sh, one each; before the manifests, a
# table of tiny's programs and the mkfiles read by mk_units.sh, sweep.sh)
# usage: analyzers/datalog/tests/check.sh tiny|ix [-v] -caps|-dead|-bugs|-exn [out-file|-check]
#   (dune build first) ANALYZE: the analyzer, if not dune's; TIX: t-IX's
#   build; MK: ix's build. Neither is built here: each says what makes it.
cd "$(dirname "$0")/../../.."
export LC_ALL=C
ANALYZE=${ANALYZE:-_build/default/analyzers/Main.exe}
TIX=${TIX:-tiny}
MK=${MK:-_mk/7}
usage="usage: check.sh tiny|ix [-v] -caps|-dead|-bugs|-exn [out-file|-check]"
system=$1; shift
verbose=; [ "${1:-}" = -v ] && { verbose=1; shift; }
flag=$1; out=$2; check=; show=
case $system in tiny|ix) ;; *) echo "$usage"; exit 2;; esac
case $flag in -caps|-dead|-bugs|-exn) ;; *) echo "$usage"; exit 2;; esac
expected=analyzers/datalog/tests/${flag#-}_$system.txt
# (no analyzer, being rebuilt say: every program would say nothing)
[ -x "${ANALYZE%% *}" ] || { echo "no analyzer: $ANALYZE"; exit 2; }
W=$(mktemp -d); trap 'rm -rf $W; [ -n "$verbose" ] && echo "check.sh: removed $W" >&2' EXIT
[ -n "$verbose" ] && echo "check.sh: made $W: the answer" >&2
if [ "$out" = -check ]; then check=1; out=$W/out; fi
if [ -z "$out" ]; then show=1; out=$W/out; fi
. analyzers/datalog/tests/compare.sh
notes=$(notes_of $expected)
case $system in
  tiny)
    what="tiny/'s programs"
    [ -n "$(find $TIX -name '*.manifest' 2> /dev/null | head -1)" ] ||
      { echo "check.sh: no t-IX build in $TIX (make in tiny/)"; exit 2; }
    programs="-project tiny $TIX _build/default/tiny";;
  ix)
    what="m-ix's programs"
    [ -n "$(find $MK -name '*.manifest' 2> /dev/null | head -1)" ] ||
      { echo "check.sh: no ix build in $MK (make ix)"; exit 2; }
    programs=$MK;;
esac
[ -n "$verbose" ] && echo "check.sh: mini-analyze $flag $programs" >&2
$ANALYZE $flag $programs > $W/answer 2> $W/err ||
  { grep -v WARNING $W/err | tail -5; echo "FAIL mini-analyze $flag on $what: not all read"; exit 1; }
# (the reports, not the programs' list under them; ix's generated files
# by their place in _mk/7)
gen() { if [ $system = ix ]; then sed "s|^$(cd $MK && pwd)/|_mk/7/|; s|^${MK%/}/|_mk/7/|"; else cat; fi; }
sed '/^[0-9]* reports, over the/,$d' $W/answer | gen |
  if [ $flag = -exn ]; then exn_lines by; else cat; fi | sort -u > $out
if [ -n "$show" ]; then cat $out; exit 0; fi
if [ -z "$check" ]; then
  keep_notes "$notes" $out; echo "$(grep -vc '^#' $out) reports: $out"; exit 0
fi
: > $W/unknown
if [ $system = ix ]; then
  # (a file no manifest of this build names, a program it has not: a
  # part's; -exn's lines are a program's)
  find $MK -name '*.manifest' -exec cat {} + | tr -c '[:print:]' '\n' > $W/named
  sed -n '/^[0-9]* reports, over the/,$p' $W/answer | tail -n +2 | tr ' ' '\n' | grep . > $W/programs
  grep -hv '^#' $expected $out | sed 's/: .*//; s/:[0-9]*$//' | sort -u | while read -r f; do
    case $f in
      _mk/7/*) [ -f "$MK/${f#_mk/7/}" ] || echo "$f";;
      *.ml|*.mli|*.c) grep -qaF "$f" $W/named || echo "$f";;
      *) grep -qxF "$f" $W/programs || echo "$f";;
    esac
  done > $W/unknown
  # (and then a line it does not give, of a file a program it has not
  # reported on, lib_graphics' Display, one program's of the whole)
  if [ -s $W/unknown ]; then
    bare_line < $out | sort -u > $W/now
    grep -v '^#' $expected | bare_line | sort -u | comm -23 - $W/now |
      sed 's/: .*//; s/:[0-9]*$//' >> $W/unknown
  fi
fi
compare "mini-analyze $flag on $what" $out $expected $W/unknown
