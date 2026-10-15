#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The differential tests: the same mkfiles through mini-mk, 9base's mk
# (plan9port's, as packaged by Debian) and xix's omk.
#
#   differential.sh record [case.mk ...]  write case.out from 9base's mk
#   differential.sh check  [case.mk ...]  compare mini-mk with case.out
#                                         (or case.mini.out, where mini-mk
#                                         differs from 9base on purpose)
#   differential.sh live   [case.mk ...]  compare all three, live
#
# A case is a mkfile in corpus/ whose first lines are directives,
# comments to mk, run in order:
#
#   #!setup touch -d '2026-01-01 10:00:00' foo.c    (sh, in a fresh dir)
#   #!args -n foo                                   (one run of mk each)
#
# Each run's output (stdout and stderr) is printed after "$ mk args",
# with its exit status, the directory replaced by DIR. The environment
# is emptied but for PATH and HOME, so NPROC, MKSHELL and the rest come
# from the case.

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CORPUS=$ROOT/builder/tests/corpus
MINIMK=${MINIMK:-$ROOT/_build/default/builder/Main.exe}
MK=${MK:-/usr/lib/plan9/bin/mk}
OMK=${OMK:-$(command -v omk)}

mode=${1:-check}
[ $# -gt 0 ] && shift
cases=${*:-$CORPUS/*.mk}

# the records were made with GNU's tools (wc, echo, cat -v, touch -d):
# on macOS, coreutils' (Homebrew's gnubin) first, where it is
for d in /opt/homebrew /usr/local; do
  [ "$(uname)" = Darwin ] && [ -d $d/opt/coreutils/libexec/gnubin ] && { GNUBIN=$d/opt/coreutils/libexec/gnubin; break; }
done
[ -n "$GNUBIN" ] && export PATH=$GNUBIN:$PATH
# a case that wants 9base's rc (MKSHELL=rc) or GNU's ar (its U): without
# them (macOS: Byron Rakitzis's rc, BSD's ar), skipped
needs_rc="mkshell"
needs_gnu_ar="archive"
RC9=/usr/lib/plan9/bin/rc
# sub-second times: OCaml's Unix.stat (4.14) gives whole seconds on macOS
needs_subsecond="subsecond"

# coreutils' timeout, by its path (the environment is emptied): gtimeout on macOS
TIMEOUT=$(command -v timeout || command -v gtimeout)

run_case() {
  prog=$1 case=$2
  # resolved: macOS's /var is /private/var, the path the program prints
  dir=$(cd "$(mktemp -d)" && pwd -P)
  cp "$case" "$dir/mkfile"
  (
    cd "$dir" || exit 1
    grep '^#!' mkfile | while IFS= read -r line; do
      case $line in
        '#!setup '*) sh -c "${line#'#!setup '}";;
        '#!args'*)
          args=${line#'#!args'}; args=${args# }
          echo "\$ mk $args"
          # shellcheck disable=SC2086
          env -i PATH="$PATH" HOME=/nonexistent "$TIMEOUT" 20 $prog $args 2>&1 </dev/null
          echo "[exit $?]";;
      esac
    done
  ) | sed "s|$dir|DIR|g"
  rm -rf "$dir"
}

status=0
for case in $cases; do
  name=$(basename "$case" .mk)
  out=${case%.mk}.out
  case $mode in
    record)
      run_case "$MK" "$case" > "$out"
      echo "recorded $name";;
    check)
      case " $needs_rc " in *" $name "*) [ -x $RC9 ] || { echo "skip $name (no 9base rc: $RC9)"; continue; };; esac
      case " $needs_subsecond " in *" $name "*) [ "$(uname)" = Darwin ] && { echo "skip $name (OCaml's Unix.stat: whole seconds on macOS)"; continue; };; esac
      case " $needs_gnu_ar " in *" $name "*) ar --version 2> /dev/null | grep -q GNU || { echo "skip $name (no GNU ar)"; continue; };; esac
      # a documented difference from 9base: mini-mk's own expected output
      [ -f "${case%.mk}.mini.out" ] && out=${case%.mk}.mini.out
      if run_case "$MINIMK" "$case" | diff -u "$out" - > /tmp/$$.diff; then
        echo "ok   $name"
      else
        echo "FAIL $name"; cat /tmp/$$.diff; status=1
      fi;;
    live)
      run_case "$MK" "$case" > /tmp/$$.mk
      run_case "$MINIMK" "$case" > /tmp/$$.mini
      # omk prints a recipe as |recipe| and colours its errors: strip both
      if [ -n "$OMK" ]; then
        run_case "$OMK" "$case" | sed -e 's/^|\(.*\)|$/\1/' -e 's/\x1b\[[0-9;]*m//g' > /tmp/$$.omk
      fi
      # (a case with a .mini.out differs from mk on purpose: said, not a failure)
      if cmp -s /tmp/$$.mk /tmp/$$.mini; then r="mini-mk=mk"
      elif [ -f "${case%.mk}.mini.out" ]; then r="mini-mk!=mk (on purpose)"
      else r="mini-mk!=mk"; status=1; fi
      if [ -n "$OMK" ]; then
        if cmp -s /tmp/$$.mk /tmp/$$.omk; then r="$r omk=mk"; else r="$r omk!=mk"; fi
      fi
      echo "$r  $name";;
  esac
done
rm -f /tmp/$$.*
exit $status
