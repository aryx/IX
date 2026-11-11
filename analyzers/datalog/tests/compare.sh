# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# An analysis's answer against its recording, the baseline (ix_check.sh's
# and tiny_check.sh's; sourced): compared without line numbers, the
# reports' own too (an edit above a function moves it), and without the
# files in $unknown (one a line: not read here), a recording's # lines
# its notes. Printed: ok, or the new reports whole (where they are now)
# and those gone (as recorded).

# -exn's lines: a toplevel's exception, without where it is raised (that
# list moves with every edit). An exception of lib_core's, which most
# programs may raise (Not_found, Failure, End_of_file...), is kept when
# the program raises it itself, by the functions that do (outside
# lib_core's files: a Hashtbl.find or a List.hd of the program's own),
# and left out when lib_core alone does; once a program, its units'
# toplevels each saying the same. The sites name files by their base
# name: lib_core's are its files' names. Invalid_argument always left
# out: every string's and array's index is one of its sites. (old: such
# an exception always left out, the program's own raises with it)
exn_lines() {
  grep 'the toplevel may let ' | awk -v libs="$(find lib_core -name '*.ml' \
      -not -path '*/tests/*' -exec basename {} \; | sort -u | tr '\n' ' ')" '
    BEGIN { n = split(libs, l, " "); for (i = 1; i <= n; i++) lib[l[i]] = 1 }
    { i = index($0, ", raised at ")
      head = i ? substr($0, 1, i - 1) : $0
      if (head ~ / let Invalid_argument escape$/) next
      if (head !~ / let (Failure|Not_found|Unix\.Unix_error|End_of_file|Sys_error|Queue\.Empty) escape$/) {
        print head; next }
      sites = i ? substr($0, i + 12) : ""; out = ""; split("", seen)
      while (match(sites, /[^ ,]+\.ml:[0-9]+ \([^)]*\)/)) {
        s = substr(sites, RSTART, RLENGTH); sites = substr(sites, RSTART + RLENGTH)
        f = s; sub(/:.*/, "", f)
        if (f in lib) continue
        fn = s; sub(/^[^(]*\(/, "", fn); sub(/\)$/, "", fn)
        if (!(fn in seen)) { seen[fn] = 1; out = out (out == "" ? "" : ", ") fn }
      }
      # (its units each the same: the first said)
      key = head; sub(/^[^:]*: /, "", key); key = key out
      if (out != "" && !(key in said)) { said[key] = 1; print head ", raised in " out }
    }'
}

# a recording's # lines (notes, a triage), read before it is written
# again, then put back
notes_of() { grep '^#' $1 2> /dev/null; }
keep_notes() { # notes answer
  [ -n "$1" ] && { echo "$1" | cat - $2 > $2.n; mv $2.n $2; }
  return 0
}

# a report without its line numbers
bare_line() { sed -E 's/:[0-9]+/:/g; s/ line [0-9]+/ line/g'; }

# its lines kept, a file's in the unknown left out; a file a line, first
# (a line that is no file: awk's first file never empty)
known() { # unknown-file answer
  awk -F: 'NR == FNR { u[$1]; next } !($1 in u)' \
    <({ cat $1 2> /dev/null; echo -; }) $2
}

compare() { # what answer recording unknown-file
  local what=$1 out=$2 expected=$3 unknown=$4 t=$(mktemp -d)
  known $unknown $out > $t/now; known $unknown <(grep -v '^#' $expected) > $t/was
  bare_line < $t/now | sort -u > $t/now.b
  bare_line < $t/was | sort -u > $t/was.b
  comm -13 $t/was.b $t/now.b > $t/new.b; comm -23 $t/was.b $t/now.b > $t/gone.b
  if [ ! -s $t/new.b ] && [ ! -s $t/gone.b ]; then
    echo "ok $what: as recorded ($(wc -l < $t/now.b))"; rm -rf $t; return 0
  fi
  echo "FAIL $what: $(wc -l < $t/new.b) new, $(wc -l < $t/gone.b) gone ($expected)"
  # (a new one by its place now; a gone one as recorded)
  paste -d '\t' <(bare_line < $t/now) $t/now | sort -t$'\t' -k1,1 |
    join -t$'\t' $t/new.b - | cut -f2- | sed 's/^/  new:  /'
  paste -d '\t' <(bare_line < $t/was) $t/was | sort -t$'\t' -k1,1 |
    join -t$'\t' $t/gone.b - | cut -f2- | sed 's/^/  gone: /'
  echo "  (a new one: fix it, or read it and record; one gone: record:"
  echo "   ${0#./} ${flag:-} $expected)"
  rm -rf $t; return 1
}
