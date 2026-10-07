#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-lex against ocamllex (plan_lex_yacc.md, decision 6, the first
# level): each of ix's .mll made a lexer by the two, and every file of
# a corpus read by both, the tokens printed with their positions (a
# token as its bytes, marshalled): no difference.
# ocamllex's lexer runs on OCaml's Lexing; mini-lex's on lib_core's,
# compiled by OCaml in the stdlib's place. Both with the parser's token
# type only (taken from ocamlyacc's Parser.mli), not its parser.
# usage: tokens.sh        (after dune build)

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
B=$ROOT/_build/default
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0

cat > $W/dump.ml <<'EOT'
(* a file's tokens: each its file and line, its span, its bytes; an error ends them *)
let hex s = String.concat "" (List.map (fun c -> Printf.sprintf "%02x" (Char.code c)) (List.init (String.length s) (String.get s)))
let () =
  Array.iteri (fun i file -> if i > 0 then begin
    let text = In_channel.with_open_bin file In_channel.input_all in
    let lexbuf = Lexing.from_string text in
    Printf.printf "== %s\n" file;
    Start.reset ();
    let rec go () =
      match Lexer.token lexbuf with
      | tok ->
          let s = Marshal.to_string tok [] in
          Printf.printf "%s:%d %d-%d %s\n" lexbuf.Lexing.lex_curr_p.Lexing.pos_fname lexbuf.Lexing.lex_curr_p.Lexing.pos_lnum (Lexing.lexeme_start lexbuf) (Lexing.lexeme_end lexbuf)
            (hex (String.sub s 20 (String.length s - 20)));
          if tok <> Parser.EOF then go ()
      | exception e -> Printf.printf "exception %s\n" (Printexc.to_string e)
    in
    go () end) Sys.argv
EOT

# name, the .mll's directory, the modules its header names (their files), what
# puts the lexer back at its start between two files, the corpus
check() {
  local name=$1 dir=$2 extra=$3 reset=$4; shift 4
  local d=$W/$name; mkdir -p $d/ref $d/mini
  # the token type alone: Parser.mli's first declaration
  awk '/^type token/,/^$/' $B/$dir/Parser.mli > $d/Parser.ml
  echo "let reset () = $reset" > $d/Start.ml
  for v in ref mini; do cp $d/Parser.ml $W/dump.ml $d/$v/; for f in $extra; do cp $f $d/$v/; done; done
  cp $B/$dir/Lexer.ml $d/ref/
  $B/generators/lex/Main.exe -o $d/mini/Lexer.ml $ROOT/$dir/Lexer.mll > /dev/null || { echo "FAIL $name: mini-lex"; failures=$((failures + 1)); return; }
  cp $ROOT/lib_core/parsing/Lexing.ml $ROOT/lib_core/parsing/Lexing.mli $d/mini/
  for v in ref mini; do
    # Start after the lexer, which it names
    (cd $d/$v && cp ../Start.ml . && ocamlfind ocamlopt -w -a -I $B/lib_core/commons/.ix_core.objs/byte -o dump.exe \
       $([ $v = mini ] && echo Lexing.mli Lexing.ml) $(for f in $extra; do basename $f; done) Parser.ml Lexer.ml Start.ml dump.ml 2> err.txt) \
      || { echo "FAIL $name: OCaml on the $v lexer: $(head -3 $d/$v/err.txt)"; failures=$((failures + 1)); return; }
    local t0=$(date +%s%N); $d/$v/dump.exe "$@" > $d/$v.txt 2>&1; eval "ms_$v=$(( ($(date +%s%N) - t0) / 1000000 ))"
  done
  if cmp -s $d/ref.txt $d/mini.txt; then echo "ok $name: $# files, $(grep -vc '^==' $d/ref.txt) tokens the same (ocamllex's lexer ${ms_ref} ms, mini-lex's ${ms_mini} ms)"
  else echo "FAIL $name: $(diff $d/ref.txt $d/mini.txt | head -5)"; failures=$((failures + 1)); fi
}

cd $ROOT
# ix's own sources, and what the lexer refuses or reads oddly
check ml languages/ml "" "()" $(tests/ix_files.sh | grep -E '\.mli?$') $ROOT/generators/tests/tokens/*.ml
# the lexer's header names Ast for its line count only
mkdir -p $W/stub; echo 'let line = ref 1' > $W/stub/Ast.ml
check sql database "$W/stub/Ast.ml" "Lexer.state := Lexer.Initial; Ast.line := 1" $(find database/tests ~/github/chidb/tests -name '*.sql' 2>/dev/null) $ROOT/generators/tests/tokens/*.sql

# what mini-lex doesn't read is refused, with the line (the one read to, for what is missing)
refused() {
  printf "$2" > $W/bad.mll
  local got=$($B/generators/lex/Main.exe -o $W/bad.ml $W/bad.mll 2>&1 | sed 's|.*bad.mll:||')
  if [ "$got" = "$1" ]; then echo "ok refused: $1"; else echo "FAIL refused: $1, got: $got"; failures=$((failures + 1)); fi
}
refused "2: r1 # r2 is not read by mini-lex" 'rule t = parse\n | _ # "a" { 1 }\n'
refused "1: shortest is not read by mini-lex" 'rule t = shortest\n | _ { 1 }\n'
refused "2: digit: no regexp of that name" 'rule t = parse\n | digit+ { 1 }\n'
refused "3: an action is not ended" 'rule t = parse\n | _\n { f (\n'
refused "3: an action expected" 'rule t = parse\n | "a"\n'
refused "2: rule expected" 'let d = [ "ab" ]\n'
echo "$failures failures"
[ $failures = 0 ]
