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
  for d in $1 $2; do
    [ -f $d/$3.ml ] && { echo $d/$3.ml; return; }
  done
  # (a generated lexer or parser: the program's own, or an -I's, before any
  # other of that name, as shell's hand-written Parser.ml; generated: needs_gen)
  for d in $1 $2; do
    f=$(find _mk/7/$d -maxdepth 2 -name "$3.ml" 2> /dev/null | head -1)
    [ -n "$f" ] && { echo $f; return; }
  done
  f=$(find $1 -name "$3.ml" 2> /dev/null | head -1)
  [ -z "$f" ] && f=$(git ls-files '*.ml' | grep -E "/$3\.ml$" | head -1)
  # (a unit made in another program's directory, that alone of its name:
  # St_kernel.ml, made by mini-smalltalk's mkfile for mini-squeak too)
  [ -z "$f" ] && [ "$(find _mk/7 -name "$3.ml" 2> /dev/null | wc -l)" = 1 ] && f=$(find _mk/7 -name "$3.ml")
  echo $f
}

# a program's units: SRC's, or UNITS where SRC is a list of files to depend on,
# computed, as the kernels' mkfiles have it
units_of() { # mkfile
  local units=$(var $1 SRC)
  case $units in *'`'*) units=$(var $1 UNITS);; esac
  echo $units
}

# a program with a unit made and not yet (a lexer, a parser, St_kernel.ml's
# strings): to be built first (by mini-mk, in its directory; one at a time, the
# builds sharing _mk)
needs_gen() { # mkfile
  local dir=$(dirname $1) g u
  for g in $(find $dir -name '*.mly' -o -name '*.mll' 2> /dev/null); do
    u=$(basename $g); u=${u%.*}; u=${u^}
    [ -n "$(find _mk/7/$dir -name "$u.ml" 2> /dev/null | head -1)" ] || return 0
  done
  [ -n "$(missing_units $1)" ]
}

# the units no file is found for
missing_units() { # mkfile
  local u flags files
  read flags files < <(program_args $1)
  for u in $(units_of $1); do
    case " $files " in *"/$u.ml "*) ;; *) echo $u;; esac
  done
}

# the -I's (as -I,dir, words) and the files, of a mkfile, on one line;
# units not found are missing="..." to the caller
program_args() { # mkfile
  local mk=$1 dir=$(dirname $1) incs= flags= files= i u f
  missing=
  # (-I's of LIBI, and of INCLUDES where a mkfile writes its own; LIBDIRS,
  # from ix's top; a directory that is not there, as $B's, left out)
  for i in $(var $mk LIBI) $(var $mk INCLUDES) $(for d in $(var $mk LIBDIRS); do echo "$(var $mk TOP)/$d"; done); do
    case $i in -I|.|'') continue;; esac
    [ -d $dir/$i ] || continue
    i=$(realpath --relative-to=. $dir/$i)
    case " $incs " in *" $i "*) continue;; esac
    incs="$incs $i"; flags="$flags,-I,$i"
  done
  # (a library's folders, its mkfile's DIRS: troff's roff/, pic/...)
  for i in $incs; do
    [ -f $i/mkfile ] || continue
    for sub in $(var $i/mkfile DIRS); do
      [ "$sub" != . ] && [ -d $i/$sub ] && { incs="$incs $i/$sub"; flags="$flags,-I,$i/$sub"; }
    done
  done
  # (and their objects' directories, where a generated unit is: mini-ml's Parser)
  for i in $incs; do [ -d _mk/7/$i ] && flags="$flags,-I,_mk/7/$i"; done
  for u in $(units_of $mk); do
    f=$(unit_file $dir "$incs" $u)
    [ -n "$f" ] && files="$files $f"
  done
  echo "${flags:-,}$files"
}
