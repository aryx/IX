#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What ix has of the author's playground, file by file: the numbers and
# the lists behind the README.md of each directory copied from it
# (lib_playground/, lib_gui/, lib_physics/, games/...).
#
#   scripts/playground_copies.sh [-p dir] [group...]
#
#   dir:   the playground (default: ~/playground)
#   group: a directory of ix's of the table below (default: all of them)
#
# For a group, three lists:
#   copied  ix's file, the playground's, the lines of each, and the
#           lines of one that are not the other's (blank lines apart;
#           the "ix:" line that says where a file comes from is one)
#   own     ix's files there that the playground has not
#   left    the playground's files that ix has not
# A file's origin is what its "ix: the author's playground's <path>"
# line says, or the file at the same place in one of the group's
# directories, or the one file of the same name there (two of that
# name: ix's file is counted its own).

P=$HOME/playground
[ "$1" = -p ] && { P=$2; shift 2; }
[ -d $P/playground ] || { echo "no $P/playground"; exit 1; }
cd $(dirname $0)/..

# ix's directory, then the playground's directories it comes from
groups='lib_playground playground libs/core libs/random
lib_graphics/software libs/graphics
lib_gui libs/gui
lib_physics libs/physics
lib_terminal libs/terminal
apps/kits appkits
apps/office/formula languages/formula
languages/scheme languages/scheme languages/sexpr
languages/pascal languages/pascal
languages/smalltalk languages/smalltalk
games games
examples examples
editors/drscheme apps/devtools
editors/turbopascal appkits/editor apps/devtools/tty'

files() { # the source files under the directories given
  find "$@" -type f \( -name '*.ml' -o -name '*.mli' -o -name '*.st' -o -name '*.scm' -o -name '*.pas' -o -name '*.jhf' -o -name '*.sh' -o -name '*.expected' \) | sort
}
code() { grep -v '^ *$' $1; }

T=$(mktemp -d); trap 'rm -rf $T' EXIT
echo "$groups" | while read ix dirs; do
  [ $# -gt 0 ] && { case " $* " in *" $ix "*) ;; *) continue;; esac; }
  echo "== $ix (the playground's: $dirs)"
  (cd $P && files $dirs) > $T/theirs; : > $T/used; : > $T/own
  echo "-- copied: ix's file, the playground's, its lines, ix's, the playground's lines gone, ix's lines new"
  for f in $(files $ix); do
    o=$(sed -n "s/.*ix: [^;]*playground's \([A-Za-z_0-9\/.]*\.[a-z]*\).*/\1/p" $f | head -1)
    [ -f "$P/$o" ] || for d in $dirs; do o=$d/${f#$ix/}; [ -f $P/$o ] && break; o=; done
    [ -n "$o" ] || { o=$(grep "/$(basename $f)\$" $T/theirs); [ $(echo "$o" | wc -l) = 1 ] || o=; }
    if [ -n "$o" ] && [ -f $P/$o ]; then
      echo $o >> $T/used
      diff $(code $P/$o > $T/a; echo $T/a) $(code $f > $T/b; echo $T/b) > $T/d
      printf '%s %s %d %d %d %d\n' ${f#$ix/} $o $(wc -l < $P/$o) $(wc -l < $f) $(grep -c '^<' $T/d) $(grep -c '^>' $T/d)
    else echo "${f#$ix/} $(wc -l < $f)" >> $T/own
    fi
  done | column -t
  echo "-- own: ix's file, its lines"; column -t $T/own
  echo "-- left: the playground's file, its lines"
  grep -v -x -F -f $T/used $T/theirs | while read o; do echo "$o $(wc -l < $P/$o)"; done | column -t
  echo
done
