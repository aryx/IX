#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Every unit mini-ml compiles is made after the units of its directory
# of objects it names: an edge of mk's graph (direct or not) for each
# of mini-ml -depend's lines. mini-ml inlines from a unit's summary
# (X.inline) when it is there; without the edge the two are compiled
# side by side, by NPROC, and which ended first decides the object: a
# right program either way, so a build's tests pass, and only two
# builds compared differ, one run in two or three (test-fixpoint on
# GitHub, 2026-10-28: tiny/'s TinyBrowserHttp after TinyBrowserText,
# which the .depend left out). Here the graph itself is read, the same
# answer whatever the timing: mini-mk -n -a -dg in each directory (its
# compiles, then the prerequisites under each target), nothing built
# but the .depend files; in $B (a build's, its libraries made: make
# test's), else mkconfig's _mk.
#
# Usage: [B=dir] depend_edges.sh [dir...]   (default: the top mkfile's
#   LIBS and DIRS, games' CATEGORIES for games: it runs a mini-mk in each)

IX=$(cd "$(dirname "$0")/.." && pwd)
cd $IX || exit 1
export MKSHELL=mini-rc PATH=$IX/bin:$PATH
W=$(mktemp -d); trap 'rm -rf $W' EXIT
# variables of a mkfile as mini-mk reads them: MKFILE VAR...
vars() {
  { echo "<$1"; printf 'vars-of-test:V:\n\techo'; shift
    for v in "$@"; do printf ' $%s' $v; done; echo " > $W/vars"; } > $W/vars.mk
  mini-mk -f $W/vars.mk vars-of-test > /dev/null && cat $W/vars
}
if [ $# = 0 ]; then
  # (lib_core and troff in both)
  set -- $(vars $IX/mkfile LIBS DIRS | tr ' ' '\n' | grep -vx games |
    awk '!seen[$0]++')
  set -- "$@" $(cd games && vars $IX/games/mkfile CATEGORIES |
    tr ' ' '\n' | sed 's,^,games/,')
fi

# DIR: the edges it lacks, a line each, and its counts on the last line
check() {
  local d=$1 o=$W/$(echo $1 | tr / _)
  (cd $d && mini-mk -n -a -dg ${B:+B=$B} > $o.dg 2> $o.err) ||
    { echo "$d: mini-mk -n failed: $(tail -1 $o.err)"; echo "count 0 0"; return; }
  # the compiles: mini-ml ... -o OBJ SRC (not -start's), as
  # "OBJ SRC -I dir...": its object, its source, where it looks; a
  # source mk does not know before the recipe runs (mklib's $f: rc's)
  # found as mklib finds it, in the line's -I directories here
  grep -E '^mini-ml .* -o [^ ]+\.[57] [^ ]+$' $o.dg | grep -v -- ' -start ' |
    awk '{ obj = ""; inc = "";
           for (i = 2; i < NF; i++) {
             if ($i == "-o") obj = $(i + 1)
             if ($i == "-I") inc = inc " -I " $(i + 1) }
           print obj, $NF, inc }' |
    while read -r obj src inc; do
      if [[ $src != *.ml ]]; then
        u=${obj##*/}; u=${u%.*}; src=
        for i in $inc; do
          [ $i = -I ] && continue
          case $i in /*) f=$i/$u.ml;; *) f=$d/$i/$u.ml;; esac
          [ -f $f ] && { src=$i/$u.ml; break; }
        done
        [ -n "$src" ] || continue
      fi
      echo "$obj $src $inc"
    done > $o.cc
  # for each directory of objects: mini-ml -depend over its units, the
  # sources' directories first (where each was compiled from)
  : > $o.want
  for od in $(awk '{ sub("/[^/]*$", "", $1); print $1 }' $o.cc | sort -u); do
    awk -v od=$od '{ x = $1; sub("/[^/]*$", "", x) } x == od' $o.cc > $o.g
    units=$(awk '{ u = $2; sub(".*/", "", u); sub("\\.ml$", "", u); print u }' $o.g)
    # (the directory itself first, as mkprog's compiles have -I . first:
    # else a unit named as one of another directory's, mini-dotnet's CLI
    # as the linker's, could be read from there)
    srcs=$( { echo "-I ."; awk '{ s = $2; if (s !~ /\//) s = "./" s
                  sub("/[^/]*$", "", s); print "-I " s }' $o.g; } | awk '!seen[$0]++')
    incs=$(awk '{ $1 = ""; $2 = ""; print }' $o.g | head -1)
    # (its lines on another directory's summary, a library's X.inline,
    # left out: the top mkfile builds the libraries first, by another mk)
    (cd $d && mini-ml -depend $od $srcs $incs $units) 2>> $o.err |
      awk -v od=$od 'index($2, od "/") == 1' >> $o.want
  done
  O=$(awk '{ print $1; exit }' $o.cc | sed 's/.*\.//')
  # the graph: a target, then each of its prerequisites two columns
  # further in (before the recipes); is each wanted edge a path in it?
  awk -v O=$O '
    FILENAME == ARGV[1] {
      if ($0 ~ /^mini-ml |^mkdir |^cp |^echo |^#/) { done = 1 }
      if (done) next
      n = match($0, /[^ ]/) - 1; at[n] = $1
      if (n > 0) { e[at[n - 2], ++ne[at[n - 2]]] = $1 }
      next }
    { gsub("\\$O", O); sub(":$", "", $1); want[++nw] = $1 " " $2 }
    function reach(a, b,   q, h, t, x, i, seen) {
      q[1] = a; h = 1; t = 1; seen[a] = 1
      while (h <= t) { x = q[h++]
        for (i = 1; i <= ne[x]; i++) {
          if (e[x, i] == b) return 1
          if (!(e[x, i] in seen)) { seen[e[x, i]] = 1; q[++t] = e[x, i] } } }
      return 0 }
    END { bad = 0
      for (i = 1; i <= nw; i++) { split(want[i], p, " ")
        if (!reach(p[1], p[2])) { bad++; sub(".*/", "", p[1]); sub(".*/", "", p[2])
          print "missing: " p[1] " names " p[2] ", no edge: side by side" } }
      print "count", nw, bad }' $o.dg $o.want | sed "s,^missing: ,$d: ,"
}

# (the directories side by side, the machine's cores: 28 s to 2.3 here;
# JOBS=1, one after the other)
export -f check; export W B
printf '%s\n' "$@" | xargs -P ${JOBS:-$(nproc)} -I{} bash -c \
  '[ -f {}/mkfile ] || { echo "{}: no mkfile"; echo "count {} 1 1"; exit; }
   check {} > $W/out.$$; sed "s,^count ,count {} ," $W/out.$$' > $W/all
grep -v "^count " $W/all
read -r total bad < <(awk '/^count / { n += $3; b += $4 }
  END { print n + 0, b + 0 }' $W/all)
echo "$((total - bad)) of $total units' edges in mk's graph"
# (none: nothing read, a check of nothing)
[ $bad = 0 ] && [ $total -gt 0 ]
