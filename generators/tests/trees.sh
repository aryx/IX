#!/bin/bash
# Claude Code
#
# Copyright (C) 2026 Yoann Padioleau
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public License
# (LGPL) as published by the Free Software Foundation; either version
# 2 of the License, or (at your option) any later version.
#
# mini-yacc against ocamlyacc (plan_lex_yacc.md, decision 6):
# - the automata: each of ix's grammars by ocamlyacc -v and by
#   mini-yacc -v, their states paired and compared (automata.py);
# - the trees: a front end made twice, by ocamllex and ocamlyacc on
#   OCaml's Lexing and Parsing, and by mini-lex and mini-yacc on
#   lib_core's (compiled by OCaml in the stdlib's place); every file of
#   a corpus parsed by both, its tree's bytes (marshalled, its
#   positions in it) or its error printed: no difference.
# usage: trees.sh        (after dune build)

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
B=$ROOT/_build/default
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
cd $ROOT

for g in database languages/c languages/ml; do
  n=$(echo $g | tr / _)
  ocamlyacc -v -b $W/ref_$n $g/Parser.mly 2> $W/ref_$n.err
  $B/generators/yacc/Main.exe -v -b $W/$n $g/Parser.mly > /dev/null 2> $W/$n.err || { echo "FAIL $g: mini-yacc: $(cat $W/$n.err)"; failures=$((failures + 1)); continue; }
  # the conflicts said the same (ocamlyacc: "2 shift/reduce conflicts.")
  if ! cmp -s $W/ref_$n.err $W/$n.err; then echo "FAIL $g: the conflicts: $(cat $W/ref_$n.err), mini-yacc: $(cat $W/$n.err)"; failures=$((failures + 1)); fi
  if r=$($ROOT/generators/tests/automata.py $W/ref_$n.output $W/$n.output); then echo "ok $g: $r"; else echo "FAIL $g: $r"; failures=$((failures + 1)); fi
done

# name, the directory, its modules before the parser (sources), the
# expression that parses a lexbuf (its tree, or an exception), the corpus
trees() {
  local name=$1 dir=$2 before=$3 parse=$4; shift 4
  local d=$W/$name; mkdir -p $d/ref $d/mini
  cat > $d/dump.ml <<EOT
let hex s = Digest.to_hex (Digest.string s)
let () =
  Array.iteri (fun i file -> if i > 0 then begin
    let lexbuf = Lexing.from_string (In_channel.with_open_bin file In_channel.input_all) in
    match $parse with
    | tree -> let s = Marshal.to_string tree [] in Printf.printf "%s %d %s\n" file (String.length s) (hex s)
    | exception Parsing.Parse_error -> Printf.printf "%s exception: a syntax error at %d\n" file (Lexing.lexeme_start lexbuf)
    | exception e -> Printf.printf "%s exception: %s at %d\n" file (Printexc.to_string e) (Lexing.lexeme_start lexbuf)
  end) Sys.argv
EOT
  for v in ref mini; do cp $d/dump.ml $d/$v/; for f in $before; do cp $ROOT/$f $d/$v/; done; done
  cp $B/$dir/Parser.ml $B/$dir/Parser.mli $B/$dir/Lexer.ml $d/ref/
  $B/generators/yacc/Main.exe -b $d/mini/Parser $ROOT/$dir/Parser.mly > /dev/null 2>&1 && $B/generators/lex/Main.exe -o $d/mini/Lexer.ml $ROOT/$dir/Lexer.mll > /dev/null \
    || { echo "FAIL $name: the generators"; failures=$((failures + 1)); return; }
  cp $ROOT/lib_core/parsing/*.ml $ROOT/lib_core/parsing/*.mli $d/mini/
  for v in ref mini; do
    (cd $d/$v && ocamlfind ocamlopt -w -a -I $B/lib_core/commons/.ix_core.objs/byte -I $B/lib_core/commons/.ix_core.objs/native -o dump.exe \
       $([ $v = mini ] && echo Lexing.mli Lexing.ml Parsing.mli Parsing.ml) $B/lib_core/commons/.ix_core.objs/native/common.cmx \
       $(for f in $before; do basename $f; done) Parser.mli Parser.ml Lexer.ml dump.ml 2> err.txt) \
      || { echo "FAIL $name: OCaml on the $v parser: $(head -5 $d/$v/err.txt)"; failures=$((failures + 1)); return; }
    local t0=$(date +%s%N); $d/$v/dump.exe "$@" > $d/$v.txt 2>&1; eval "ms_$v=$(( ($(date +%s%N) - t0) / 1000000 ))"
  done
  if cmp -s $d/ref.txt $d/mini.txt; then
    echo "ok $name: $# files, $(grep -c ' exception: ' $d/ref.txt) with an error: the same trees (ocamlyacc's parser ${ms_ref} ms, mini-yacc's ${ms_mini} ms)"
  else echo "FAIL $name: $(diff $d/ref.txt $d/mini.txt | head -5)"; failures=$((failures + 1)); fi
}

trees ml languages/ml "languages/ml/Ast.ml" \
  '(if Filename.check_suffix file ".mli" then Ast.Signature (Parser.interface Lexer.token lexbuf) else Ast.Structure (Parser.implementation Lexer.token lexbuf))' \
  $(git ls-files '*.ml' '*.mli') $ROOT/generators/tests/tokens/*.ml $ROOT/generators/tests/trees/*.ml
# the corpus' files without their shell commands (.headers on), and each of their lines alone
mkdir -p $W/sql
for f in $(find database/tests ~/github/chidb/tests -name '*.sql' 2>/dev/null); do
  grep -v '^\.' $f > $W/sql/$(basename $f)
  grep -v '^\.' $f | grep ';' | split -l 1 -a 4 - $W/sql/$(basename $f .sql)-
done
trees sql database "database/Ast.ml" '(Lexer.state := Lexer.Initial; Ast.line := 1; Parser.main Lexer.token lexbuf)' \
  $W/sql/* $ROOT/generators/tests/tokens/*.sql $ROOT/generators/tests/trees/*.sql

# what mini-yacc doesn't read, or a grammar that names what it has not, is refused with the line
refused() {
  printf "$2" > $W/bad.mly
  local got=$($B/generators/yacc/Main.exe -b $W/bad $W/bad.mly 2>&1 | sed 's|.*bad.mly:||')
  if [ "$got" = "$1" ]; then echo "ok refused: $1"; else echo "FAIL refused: $1, got: $got"; failures=$((failures + 1)); fi
}
refused "5: the error token is not read by mini-yacc" '%%token A\n%%start s\n%%type <int> s\n%%%%\ns: A error { 1 };\n'
refused "5: B: no token and no rule of that name" '%%token A\n%%start s\n%%type <int> s\n%%%%\ns: A B { 1 };\n'
refused "5: s: an action in the middle of a rule is not read by mini-yacc" '%%token A\n%%start s\n%%type <int> s\n%%%%\ns: A { 1 } A { 2 };\n'
refused '5: $3: the rule has 1 symbols' '%%token A\n%%start s\n%%type <int> s\n%%%%\ns: A { $3 };\n'
refused "2: %union is not read by mini-yacc" '%%token A\n%%union { }\n'
refused "0: s: %start, without its %type" '%%token A\n%%start s\n%%%%\ns: A { 1 };\n'
echo "$failures failures"
[ $failures = 0 ]
