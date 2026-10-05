#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# lib_core/'s stdlib against ocaml-light's stdlib/, its origin
# (README.md), as a diff but shorter: each file changed with its lines
# added and removed, each new one, each of ocaml-light's not taken;
# then the counts. -v: the diffs.
# Here a file is in a directory (xix's layout) and its name has a
# capital: collections/List.ml is ocaml-light's stdlib/list.ml.
# usage: diff_ocaml_stdlib.sh [-v]    (ocaml-light: ~/ocaml-light, or OCAML_LIGHT=...)

D=$(cd "$(dirname "$0")" && pwd)
verbose=; [ "${1:-}" = -v ] && verbose=1
OL=${OCAML_LIGHT:-$HOME/ocaml-light}

same=0; changed=0; own=0
against() {   # ours (from lib_core/), its origin
  if [ ! -f "$2" ]; then own=$((own + 1)); echo "new:      $1"; return; fi
  if cmp -s "$D/$1" "$2"; then same=$((same + 1)); return; fi
  changed=$((changed + 1))
  echo "changed:  $1  (+$(diff "$2" "$D/$1" | grep -c "^>") -$(diff "$2" "$D/$1" | grep -c "^<"))"
  [ -n "$verbose" ] && diff -u "$2" "$D/$1"
}

lower() { local b=$(basename $1); echo $(echo ${b:0:1} | tr A-Z a-z)${b:1}; }
taken=" "
for f in $(cd $D && ls core/*.ml* base/*.ml* collections/*.ml* printing/*.ml* parsing/*.ml* system/*.ml*); do
  against $f $OL/stdlib/$(lower $f); taken="$taken$(lower $f) "
done
not=0
for f in $(cd $OL/stdlib && ls *.ml *.mli); do
  case "$taken" in *" $f "*) ;; *) not=$((not + 1)); echo "not taken: $f";; esac
done
echo "$same files as ocaml-light's, $changed changed, $own new; $not of ocaml-light's not taken"
