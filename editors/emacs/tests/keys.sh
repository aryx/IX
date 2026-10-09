#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-emacs with no screen (docs/plans/plan_emacs.md, stages 2 to 4): a
# session is a file and a line of keys (mini-emacs-tty -keys), what it
# leaves the screen as text, and the file if it was saved. Each by
# dune's build must be keys.expected's (read by a person once: efuns
# needs GTK and is not run), and mini-ml's build's the same (as it is,
# arm64; -5: arm, under mini-5i).
# usage: editors/emacs/tests/keys.sh [-5] [-record] [mk's tree]
#   (dune build, and mini-mk O=7 or O=5 in editors/emacs/tty, first;
#   mk's tree: where _mk is, when it is not here)
cd "$(dirname "$0")/../../.."
ROOT=$PWD
O=7; RUN=; RECORD=
[ "${1:-}" = -5 ] && { O=5; RUN=$ROOT/_build/default/machine/Main.exe; shift; }
[ "${1:-}" = -record ] && { RECORD=1; shift; }
NATIVE=$ROOT/_build/default/editors/emacs/tty/Main.exe
MINI=$(cd ${1:-.} && pwd)/_mk/$O/editors/emacs/tty/mini-emacs-tty
EXPECTED=$ROOT/editors/emacs/tests/keys.expected
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
FILE=f.txt; OPTS=
session() { # its name, its file's text (none: no file named; -: one named that is not there), its keys
  rm -rf $W/$FILE $W/d; [ -n "$2" ] && [ "$2" != - ] && printf "$2" > $W/$FILE
  # (and a directory, for the names completed)
  mkdir -p $W/d/sub; printf 'hello\n' > $W/d/a.txt; printf 'x\n' > $W/d/ab.txt
  echo "== $1: $3"
  (cd $W && if [ -n "$2" ]; then "${@:4}" $OPTS -keys "$3" $FILE; else "${@:4}" $OPTS -keys "$3"; fi 2>&1; echo "exit $?")
  case "$3" in *"C-x C-s"*) echo "-- $FILE:"; (cd $W && cat $FILE 2>&1);; esac
  case "$3" in *"C-x C-w"*) echo "-- d/new.txt:"; (cd $W && cat d/new.txt 2>&1);; esac
}
# a file of a language, its screen with how its cells are shown (-colors)
colored() { FILE=$2; OPTS=-colors; session "$1" "${@:3}"; FILE=f.txt; OPTS=; }
lines=$(seq 1 60 | tr '\n' '|' | sed 's/|/\\n/g')
text='one two three\nfour five six\nseven two nine\n'
all() {
  session first '' '' "$@"
  session typed '' '8x40 =hello Enter =world' "$@"
  session file 'ab\n\tc\nd\n' '6x44 ArrowDown C-e' "$@"
  # the keys' names: a prefix shown, a key bound to nothing, Escape for Meta
  session prefix 'ab\n' '6x44 C-x' "$@"
  session undefined 'ab\n' '6x44 C-x =z' "$@"
  session undefined-key 'ab\n' '6x44 C-z' "$@"
  session escape 'one two three\n' '6x44 Escape =f Escape' "$@"
  # moves: a character, a word, a line and its column kept past a short one
  session words 'one two, three\n' '6x44 A-f A-f A-f A-b =X' "$@"
  session column 'a long line\n\nshort\nanother long line\n' '8x44 C-e C-n C-n C-n =X' "$@"
  session column-tab 'abcdefghij\n\tx\n' '6x44 C-f C-f C-f C-n =X' "$@"
  session ends 'one\ntwo\n' '6x44 C-p A-> C-n' "$@"
  session utf8 'h\303\251llo w\303\266rld\n' '6x44 C-f C-f =X C-e C-b Backspace C-a C-d C-d' "$@"
  # the text changed, and saved
  session save 'one\ntwo\n' '6x44 C-n Enter =1.5 Tab =x C-x C-s' "$@"
  session delete 'one\ntwo\n' '6x44 C-e C-d Delete Backspace C-x C-s' "$@"
  session new - '6x44 =text Enter C-x C-s' "$@"
  session nofile '' '6x44 =text C-x C-s' "$@"
  # the frame moves over the text
  session scroll "$lines" '8x44 C-v C-v' "$@"
  session scroll-back "$lines" '8x44 C-v C-v C-v A-v' "$@"
  session scroll-point "$lines" '8x44 C-n C-n C-n C-n C-n C-n C-n' "$@"
  session scroll-ends "$lines" '8x44 A-> PageUp A-< PageUp' "$@"
  session recenter "$lines" '8x44 C-v C-n C-n C-l' "$@"
  session fold 'a line that is longer than the frame is folded, here twice\nshort\n' '8x24 C-e =! C-n' "$@"
  session fold-scroll 'a line that is longer than the frame is folded, here twice\nb\nc\nd\ne\n' '6x24 A->' "$@"
  session control 'a\001b\177c\377d\n' '6x44 C-e' "$@"
  # characters: two columns for a wide one, none for a combining accent, a byte that is none
  session unicode 'ascii\n\344\270\255\346\226\207\345\255\227 wide|\ne\314\201 combining|\n\360\237\230\200 emoji|\nbad \377 byte|\ntab\t\344\270\255\t|\n' '9x40 C-n C-f C-f =X C-n C-n C-n C-n C-e' "$@"
  session unicode-fold '\344\270\255\346\226\207\345\255\227 wide|\n' "5x12 =$(printf '\303\251\346\226\207')" "$@"
  # the minibuffer: a file's name completed, a buffer's, a command's
  session find-file "$text" '6x60 C-x C-f =d Tab' "$@"
  session find-file-names "$text" '6x60 C-x C-f =d Tab Tab' "$@"
  session find-file-found "$text" '6x60 C-x C-f =d Tab =a. Tab Enter' "$@"
  session find-file-none "$text" '6x60 C-x C-f =zz Tab' "$@"
  session find-file-edited "$text" '6x60 C-x C-f =d/zzz/a.txt A-b A-b A-Backspace Enter' "$@"
  session find-file-directory "$text" '6x60 C-x C-f =d Enter' "$@"
  session minibuffer-quit "$text" '6x60 C-x C-f C-g' "$@"
  session minibuffer-twice "$text" '6x60 C-x C-f C-x C-f' "$@"
  session buffer-default "$text" '6x60 C-x C-f =d/a.txt Enter C-x b' "$@"
  session buffer-back "$text" '6x60 C-n C-x C-f =d/a.txt Enter C-x b Enter =Z' "$@"
  session buffer-name "$text" '6x60 C-x C-f =d/a.txt Enter C-x b Enter C-x b =a Tab Enter' "$@"
  session buffer-new "$text" '6x60 C-x b =notes Enter =text' "$@"
  session buffer-kill "$text" '6x60 C-x C-f =d/a.txt Enter C-x k Enter' "$@"
  session buffer-kill-modified "$text" '6x60 =X C-x k Enter' "$@"
  session buffer-kill-yes "$text" '6x60 =X C-x k Enter =yes Enter' "$@"
  session write-file "$text" '6x60 C-k C-x C-w =d/new.txt Enter' "$@"
  session mx "$text" '6x60 A-x =forward_w Tab Enter' "$@"
  session mx-names "$text" '6x60 A-x =forward_ Tab' "$@"
  session mx-none "$text" '6x60 A-x =nosuch Enter' "$@"
  session exit-modified "$text" '6x60 =X C-x C-c' "$@"
  # the kill ring, the mark, undo
  session kill-lines "$text" '8x60 C-k C-k C-k C-k C-n C-y C-y' "$@"
  session kill-words "$text" '6x60 A-d C-n A-d C-y A-y' "$@"
  session kill-backward "$text" '6x60 A-f A-f A-Backspace A-Backspace C-e C-y' "$@"
  session region "$text" '6x60 C-Space C-n C-n A-w C-w C-y C-x C-x =|' "$@"
  session region-none "$text" '6x60 C-w' "$@"
  session yank-pop-none "$text" '6x60 C-k C-y C-f A-y' "$@"
  session undo-words "$text" '6x60 =abc Space =def Space =ghi C-_ C-_' "$@"
  session undo-all "$text" '6x60 C-k C-k C-x u C-x u C-x u' "$@"
  # searches, replacements
  session search "$text" '6x60 C-s =two' "$@"
  session search-next "$text" '6x60 C-s =two C-s' "$@"
  session search-failing "$text" '6x60 C-s =two C-s C-s' "$@"
  session search-done "$text" '6x60 C-s =two C-s Enter =X' "$@"
  session search-quit "$text" '6x60 C-s =two C-s C-g =X' "$@"
  session search-delete "$text" '6x60 C-s =tx Backspace =h' "$@"
  session search-backward "$text" '6x60 A-> C-r =two C-r Enter =X' "$@"
  session search-again "$text" '6x60 C-s =two Enter C-s C-s C-s Enter =X' "$@"
  session search-regexp "$text" '6x60 Escape C-s =t.o|f.ve Enter =X' "$@"
  session search-regexp-bad "$text" '6x60 Escape C-s =(' "$@"
  session replace-query "$text" '6x60 A-% =two Enter =2 Enter' "$@"
  session replace-no-yes "$text" '6x60 A-% =two Enter =2 Enter =n =y' "$@"
  session replace-rest-undo "$text" '6x60 A-% =e Enter =E Enter =y =! C-_' "$@"
  session replace-quit "$text" '6x60 A-% =e Enter =E Enter =y =q' "$@"
  session replace-regexp "$text" '6x60 A-x =replace_r Tab Enter =[aeiou]+ Enter =_ Enter' "$@"
  session replace-string "$text" '6x60 A-x =replace_s Tab Enter =. Enter =! Enter' "$@"
  # windows
  session split "$text" '12x60 C-x 2 C-n =X C-x o =Y' "$@"
  session split-three "$lines" '12x60 C-x 3 C-x o C-x 2 C-x o C-x C-f =d/a.txt Enter' "$@"
  session split-delete "$text" '12x60 C-x 3 C-x o C-x 2 C-x o C-x 0 =Z' "$@"
  session split-one "$text" '12x60 C-x 3 C-x o C-x 2 C-x 1 =Z C-x 0' "$@"
  session split-small "$text" '5x60 C-x 2' "$@"
  session split-minibuffer "$text" '12x60 C-x 2 C-x C-f C-x o' "$@"
  session split-kill "$text" '12x60 C-x 2 C-x o C-x k Enter' "$@"
  # the languages: a file's colors by its name, the parenthesis that matches, TAB and C-j
  colored ocaml a.ml '(* a comment *)\nlet rec fact (n : int) : int =\n  if n < 2 then 1 else n * fact (n - 1)\ntype t = A | B of string\nlet () = print_endline ("hi" ^ String.make 2 (Char.chr 120))\n' '8x64 C-n' "$@"
  colored c a.c '#include <u.h>\n/* a comment */\nint main(int argc, char **argv) {\n\tif (argc > 1) return MAX;\n\tprint("hello %%d", 42);\n}\n' '9x64 C-n' "$@"
  colored scheme a.scm '; a comment\n(define (fact n)\n  (if (< n 2) 1 (+ n (fact (- n 1)))))\n(define pi 3.14) "str"\n' '7x64' "$@"
  colored pascal a.pas "program Queens; { eight }\nvar n : integer;\nprocedure Try(c : integer);\nbegin if c > 8 then writeln('done') end;\n" '7x64' "$@"
  colored asm a.s 'TEXT main(SB), $0\n\tMOVW $1, R0 // one\nloop:\n\tB loop\n' '7x64' "$@"
  colored smalltalk a.st "Object subclass: #Point\n  instanceVariableNames: 'x y'!\n!Point methodsFor: 'a'!\nx\n  \"the x\"\n  ^x + 1! !\n" '9x64' "$@"
  colored no-mode a.txt 'let x = (1)\n' '4x40' "$@"
  colored paren-after a.ml 'let f x = (g (h x) [1; 2])\n' '4x40 C-e' "$@"
  colored paren-at a.ml 'let f x = (g (h x) [1; 2])\n' '4x40 A-f A-f A-f C-f C-f C-f C-f C-f C-f' "$@"
  colored paren-none a.ml 'let f x = (g (h x\n' '4x40 C-e C-b C-b C-b C-b' "$@"
  colored colors-typed a.ml - '4x40 =let Space =f Space =x Space == Space ="a Space =(*' "$@"
  colored colors-fold a.ml 'let s = "a string that is folded at the frame'"'"'s width" (* and a comment *)\n' '5x30' "$@"
  colored colors-unicode a.ml '(* \344\270\255\346\226\207 e\314\201 *) let s = "\303\251t\303\251"\n' '4x40' "$@"
  colored colors-scrolled a.ml "$(seq 1 30 | sed 's/.*/let v& = "&" (* & *)/' | tr '\n' '|' | sed 's/|/\\n/g')" '6x40 C-v C-v C-v' "$@"
  colored search-shown a.txt "$text" '6x40 C-s =two C-s' "$@"
  colored replace-shown a.txt "$text" '6x40 A-% =five Enter =5 Enter' "$@"
  FILE=a.ml session indent - '6x40 =let Space =f Space == Enter Tab =if Space =x Enter Tab Tab =y C-j =z Enter =w Tab' "$@"
  FILE=a.ml session indent-more 'let f =\n  1\n' '6x40 C-n Tab Tab C-a Tab' "$@"
  FILE=a.c session tab-in-c 'int x;\n' '6x40 Tab C-j =y' "$@"
  session newline-indented '\t  x\n' '6x40 C-e C-j =y C-a C-j =z' "$@"
  # the screen's size
  session small 'one\ntwo\nthree\n' '3x12 C-n C-n' "$@"
  session tiny 'one\n' '1x5 =x' "$@"
  session nokey '' 'F99' "$@"
}
all $NATIVE > $W/native
if [ -n "$RECORD" ]; then cp $W/native $EXPECTED; echo "recorded: $(grep -c '^== ' $EXPECTED) sessions, $(wc -l < $EXPECTED) lines"; exit 0; fi
if cmp -s $W/native $EXPECTED; then echo "ok mini-emacs's screens by dune: $(grep -c '^== ' $EXPECTED) sessions, $(wc -l < $EXPECTED) lines"
else echo "FAIL mini-emacs's screens by dune"; diff $EXPECTED $W/native | head -20; failures=$((failures + 1)); fi
if [ -x $MINI ]; then
  all $RUN $MINI > $W/mini
  # mini-5i has no statx (docs/plans/bugs/ix.md): a directory is not
  # listed there, nor known to be one; without those four sessions
  if [ $O = 5 ]; then
    for f in native mini; do
      grep -v '^mini-5i: unimplemented system call' $W/$f | awk '/^== /{skip = ($2 ~ /^find-file(-names|-found|-directory)?:$/)} !skip' > $W/few; mv $W/few $W/$f
    done
  fi
  if cmp -s $W/native $W/mini; then echo "ok mini-emacs's screens by mini-ml ($O) as by dune"
  else echo "FAIL mini-emacs's screens by mini-ml ($O)"; diff $W/native $W/mini | head -20; failures=$((failures + 1)); fi
else echo "not run: $MINI is not built"; fi
[ $failures = 0 ]
