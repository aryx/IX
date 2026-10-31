# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A program's units and -I's, by its mkfile (sweep.sh's, dynamic.sh's;
# sourced). A unit's file: in the program's directory or its -I's, then
# _mk/7's (a generated lexer or parser), then anywhere under the directory,
# then the one of that name elsewhere in the tree. Run from ix's root.

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
  [ -z "$f" ] && f=$(git ls-files '*.ml' | grep -E "/$3\.ml$" | head -1)
  echo $f
}

# the -I's (as -I,dir, words) and the files, of a mkfile, on one line;
# units not found are missing="..." to the caller
program_args() { # mkfile
  local mk=$1 dir=$(dirname $1) incs= flags= files= i u f
  missing=
  for i in $(var $mk LIBI); do
    [ "$i" = -I ] || { i=$(realpath --relative-to=. $dir/$i); incs="$incs $i"; flags="$flags,-I,$i"; }
  done
  for u in $(var $mk SRC); do
    f=$(unit_file $dir "$incs" $u)
    [ -n "$f" ] && files="$files $f"
  done
  echo "${flags:-,}$files"
}
