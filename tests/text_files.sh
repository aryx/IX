#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# ix's sources are text: no control byte in them but a tab and a
# newline. A byte written raw in a character or a string ('^@' where
# '\000' was meant) compiles the same, and git, file and an editor
# then take the whole file for a binary one: no diff, no blame, and a
# search skips it (linker/Exe.ml was so for two weeks, 2026-10-07).
# The sources by their names: OCaml's, C's, assembly, the scripts, the
# build files, the documents. Not the tests' data (a recorded console
# has its carriage returns and escapes).
#
# Usage: text_files.sh [path...]   (default: all of ix)

cd "$(dirname "$0")/.." || exit 1
bad=0; n=0
for f in $(tests/ix_files.sh "$@" | grep -E '\.(ml|mli|mll|mly|c|h|s|sh|py|rc|md|nw|opam)$|(^|/)(mkfile|Makefile|dune|dune-project|mkconfig)$' | grep -v ' '); do
  n=$((n + 1))
  # (-a: grep itself takes a file with a NUL for a binary one, and finds nothing in it)
  if LC_ALL=C grep -qaP '[\x00-\x08\x0b\x0e-\x1f\x7f]' "$f"; then
    bad=$((bad + 1))
    echo "FAIL $f: a control byte, at line $(LC_ALL=C grep -naP '[\x00-\x08\x0b\x0e-\x1f\x7f]' "$f" | head -1 | cut -d: -f1)"
  fi
done
echo "$((n - bad)) of $n sources are text"
[ $bad = 0 ]
