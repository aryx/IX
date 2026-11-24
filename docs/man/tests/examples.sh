#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The files the man pages' EXAMPLES name exist in ix. A page shows
# commands on files a reader is meant to find, and the tree moves under
# them: acid.md said apps/rio/Rio.ml after rio went to windows/rio/, and
# prolog.md ran queens.pl and family.pl, which were nowhere (both found
# by hand on 2026-11-23). A name with a directory must be the end of a
# file's path in ix (from ix's root, or from the tool's directory, as
# singml.md's programs/pong/Main.ml; $IX/, $P/ and the like taken off,
# as the pages define them); a name alone must be some file's of the
# tree. A path from / is the card's and is not looked for. The names in
# placeholders below are meant: a command's output, or any file of the
# reader's.
# usage: docs/man/tests/examples.sh
cd "$(dirname "$0")/../../.."
export LC_ALL=C

# a page's word: why it is no file of ix
placeholders='
analyze.md calc.dl      written by the example (-facts calc.c > calc.dl)
analyze.md flow.dl      written by the example (-flow calc.c > flow.dl)
datalog.md hello.dl     written by the example (-facts hello.c > hello.dl)
datalog.md facts.dl     any program'"'"'s facts
diff.md old.c           any two files
diff.md new.c           any two files
emacs-tty.md x.ml       any file
ml.md fact.ml           any unit
pascal.md hello.pas     any program (HELLO.PAS is the disk'"'"'s)
smalltalk.md Mine.st    the reader'"'"'s own classes
'
W=$(mktemp -d); trap 'rm -rf $W' EXIT
# (CI's docker image has no .git, .dockerignore's: the tree's files,
# what the build made left out)
git ls-files > $W/paths 2> /dev/null ||
  find . \( -name '_build*' -o -name _mk -o -name '_make*' -o -name .git \) -prune -o -type f -print |
    sed 's,^\./,,' > $W/paths
sed 's,.*/,,' $W/paths | sort -u > $W/names
failures=0 checked=0
for f in docs/man/*/*.md; do
  page=$(basename $f)
  # (EXAMPLES to the next section; the names with a source's extension)
  awk '/^# EXAMPLES/ { e = 1; next } /^# / { e = 0 } e' $f |
    grep -oE '[$A-Za-z_0-9/.~-]+\.(c|h|ml|mli|mll|mly|s|dl|pl|scm|fs|tig|pas|st|cs|acid|rc)\b' |
    sort -u > $W/words
  while read -r w; do
    case "$w" in /*|'~'*) continue;; esac
    if echo "$placeholders" | grep -q "^$page $w "; then continue; fi
    checked=$((checked + 1))
    case "$w" in
      */*)
        p=$(echo "$w" | sed -E 's,^\$[A-Za-z_]+/,,')
        # (a variable the page sets to a directory of ix: P=$IX/analyzers/datalog/points_to)
        case "$w" in '$'[A-Z]*/*)
          v=$(echo "$w" | sed -E 's,^\$([A-Za-z_]+)/.*,\1,')
          d=$(grep -oE "\b$v=\\\$IX/[A-Za-z_0-9/.-]+" $f | head -1 | sed 's,.*\$IX/,,')
          [ -n "$d" ] && p="$d/$p";;
        esac
        [ -e "$p" ] && continue
        grep -q "/$p\$" $W/paths && continue;;
      *) grep -qxF "$w" $W/names && continue;;
    esac
    echo "FAIL docs/man: $f's EXAMPLES name $w, which is not in ix"
    failures=$((failures + 1))
  done < $W/words
done
[ $failures = 0 ] && echo "ok docs/man: the $checked files the EXAMPLES name are in ix"
exit $failures
