#!/usr/bin/env bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze FLAG on m-ix's programs as ix's build links them: one
# call over the build's manifests (mini-ld -map's), each program read as
# linked, its library's and its generated files (mini-lex's, mini-yacc's)
# among them, the runs merged by mini-analyze; the kernels the build has
# too (mini-9pi's, mkkernel's link writing its manifest). Each report once, sorted,
# recorded: -caps caps_ix.txt, -bugs bugs_ix.txt, -dead dead_all_ix.txt
# (what every program that has the
# file says), -exn exn_ix.txt (by program, lib_core's that every program
# may raise left out: compare.sh's exn_lines). The reports are known
# ones, read (analyzers/datalog/README.md); -check fails on any other
# answer, a new report the first. Compared without line numbers (an edit
# above a function moves it); a generated file by its place in _mk/7.
# A build of a part (make test's): the recorded lines of files no
# manifest of it names, or that it does not give, not known here, left
# out; a new line fails.
# (old, before the manifests: the 44 programs read from their mkfiles,
# mk_units.sh, sweep.sh, their lexers by generated.sh, merged here)
# usage: analyzers/datalog/tests/ix_check.sh [-v] -caps|-dead|-bugs|-exn [out-file|-check]
#   -v: the build read, the directories made and removed
#   MK: the build (_mk/7: make ix first); ANALYZE: the analyzer, if not dune's.
cd "$(dirname "$0")/../../.."
export LC_ALL=C
ANALYZE=${ANALYZE:-_build/default/analyzers/Main.exe}
MK=${MK:-_mk/7}
[ -x "${ANALYZE%% *}" ] || { echo "no analyzer: $ANALYZE"; exit 2; }
verbose=; [ "${1:-}" = -v ] && { verbose=1; shift; }
flag=$1; out=$2; check=; show=
case $flag in
  -caps|-bugs|-exn) expected=analyzers/datalog/tests/${flag#-}_ix.txt;;
  -dead) expected=analyzers/datalog/tests/dead_all_ix.txt;;
  *) echo "usage: ix_check.sh [-v] -caps|-dead|-bugs|-exn [out-file|-check]"; exit 2;;
esac
[ -n "$(find $MK -name '*.manifest' 2> /dev/null | head -1)" ] ||
  { echo "ix_check.sh: no ix build in $MK (make ix)"; exit 2; }
W=$(mktemp -d); trap 'rm -rf $W; [ -n "$verbose" ] && echo "ix_check.sh: removed $W" >&2' EXIT
[ -n "$verbose" ] && echo "ix_check.sh: reading the build in $MK; made $W: the answer, the manifests' strings" >&2
if [ "$out" = -check ]; then check=1; out=$W/out; fi
if [ -z "$out" ]; then show=1; out=$W/out; fi
. analyzers/datalog/tests/compare.sh
notes=$(notes_of $expected)
$ANALYZE $flag $MK > $W/answer 2> $W/err ||
  { grep -v WARNING $W/err | tail -5; echo "FAIL mini-analyze $flag on m-ix's programs: not all read"; exit 1; }
# (the reports, not the programs' list under them; a generated file by
# its place in _mk/7, wherever MK is)
gen() { sed "s|^$(cd $MK && pwd)/|_mk/7/|; s|^${MK%/}/|_mk/7/|"; }
sed '/^[0-9]* reports, over the/,$d' $W/answer | gen |
  if [ $flag = -exn ]; then exn_lines by; else cat; fi > $W/all
sort -u $W/all > $out
if [ -n "$show" ]; then cat $out; exit 0; fi
if [ -z "$check" ]; then
  keep_notes "$notes" $out; echo "$(grep -vc '^#' $out) reports: $out"; exit 0
fi
# (a file no manifest of this build names, or a program it has not, not
# known here: a part's; -exn's lines are a program's)
find $MK -name '*.manifest' -exec cat {} + | tr -c '[:print:]' '\n' > $W/named
sed -n '/^[0-9]* reports, over the/,$p' $W/answer | tail -n +2 | tr ' ' '\n' | grep . > $W/programs
grep -hv '^#' $expected $out | sed 's/: .*//; s/:[0-9]*$//' | sort -u | while read -r f; do
  case $f in
    _mk/7/*) [ -f "$MK/${f#_mk/7/}" ] || echo "$f";;
    *.ml|*.mli|*.c) grep -qaF "$f" $W/named || echo "$f";;
    *) grep -qxF "$f" $W/programs || echo "$f";;
  esac
done > $W/unknown
# (a part, some lines not known: a line it does not give, of a file a
# program it has not reported on (lib_graphics' Display, one program's
# of the whole), not known either; a new line fails all the same)
if [ -s $W/unknown ]; then
  bare_line < $out | sort -u > $W/now
  grep -v '^#' $expected | bare_line | sort -u | comm -23 - $W/now | sed 's/: .*//; s/:[0-9]*$//' >> $W/unknown
fi
compare "mini-analyze $flag on m-ix's programs" $out $expected $W/unknown
st=$?
exit $st
