#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/plan_scheme.md and plan_pascal.md: the
# files of the author's playground that TinyDrScheme and TinyTurboPascal
# stand on and ix has not yet, their lines, what mini-ml says of each
# (its first refusal only: a file has others behind it), and the
# constructs mini-ml has not, counted.
# usage: apps/survey.sh [dir]
#   dir: the playground (default: ~/playground)

cd "$(dirname "$0")"
P=${1:-$HOME/playground}
T=..
[ -d $P/playground ] || { echo "no $P/playground"; exit 1; }

scheme="languages/sexpr/Sexpr languages/sexpr/Sexpr_read languages/scheme/Scheme_image languages/scheme/Scheme languages/scheme/Scheme_syntax languages/scheme/Scheme_prims languages/scheme/Scheme_prelude languages/scheme/Scheme_eval languages/scheme/Scheme_step"
drscheme="libs/gui/Text libs/gui/Text_edit playground/ways/Bigbang apps/devtools/TinyDrScheme"
pascal="languages/pascal/Pcode languages/pascal/Pascal_lexer languages/pascal/Pascal_compile languages/pascal/Pmachine languages/pascal/Pdebug languages/pascal/Pascal_disk"
terminal="libs/terminal/Line_discipline libs/terminal/Vt libs/terminal/Curses libs/terminal/Tui libs/terminal/Talk libs/terminal/unix/Tty_unix"
turbo="playground/ways/Teletype playground/ways/Textmode appkits/editor/Turbo_edit appkits/editor/Turbo_debug appkits/editor/Turbo_menus appkits/editor/Turbo_update appkits/editor/Turbo_view appkits/editor/Tui_turbo apps/devtools/TinyTurboPascal apps/devtools/tty/TinyTurboPascal"

# ix's own first (its Playground, Set, Scene2d, Lehmer: already copied),
# then the playground's for what is not here yet
inc=""
for d in . core random layers apis platforms/ppm platforms; do inc="$inc -I $T/lib_playground/$d"; done
inc="$inc -I $T/lib_graphics/software"
for d in libs/terminal libs/terminal/unix libs/gui languages/sexpr languages/scheme languages/pascal appkits/editor playground/ways; do inc="$inc -I $P/$d"; done
for d in system core base collections printing parsing concurrency commons; do inc="$inc -I $T/lib_core/$d"; done

# a file's lines, its interface's, and the first thing mini-ml refuses
survey() {
  local ml=0 mli=0 n i err
  for u in $*; do
    n=$(cat $P/$u.ml | wc -l); i=0; [ -f $P/$u.mli ] && i=$(cat $P/$u.mli | wc -l)
    ml=$((ml + n)); mli=$((mli + i))
    err=$($T/bin/mini-ml -m 7 -o /dev/null $inc $P/$u.ml 2>&1 > /dev/null | head -1)
    l=$(echo "$err" | grep -o "$u.ml:[0-9]*:" | grep -o ':[0-9]*:' | tr -d ':')
    printf "  %5d %5d %-42s %s | %s\n" $n $i $u.ml "$(echo "$err" | sed "s|$P/||; s/^\([^ ]*\.mli:[0-9]*\):.*/its \1/; s/^[^ ]*\.ml:[0-9:]* *//" | cut -c1-40)" "$([ "${l:-0}" -gt 0 ] && sed -n ${l}p $P/$u.ml | sed 's/^ *//' | cut -c1-48)"
  done
  printf "  %5d %5d all (%d files)\n" $ml $mli $(echo $* | wc -w)
}
# the constructs mini-ml has not, in a set of units
constructs() {
  local ml="" mli=""
  for u in $*; do ml="$ml $P/$u.ml"; [ -f $P/$u.mli ] && mli="$mli $P/$u.mli"; done
  printf "  optional arguments: %d definitions (%d in the interfaces); Map.Make: %d; let open: %d; Hashtbl: %d lines; to_seq: %d\n" \
    $(cat $ml | grep -c '^ *let.*[ (]?[(a-z]') $(cat $mli | grep -c '?[a-z_]*:') $(cat $ml | grep -c '\.Make') $(cat $ml | grep -c 'let open') $(cat $ml | grep -c 'Hashtbl') $(cat $ml | grep -c 'to_seq')
}

echo "== Scheme: the language (lines, its .mli's, mini-ml's first refusal)"
survey $scheme
echo "== Scheme: TinyDrScheme and what it stands on that ix has not"
survey $drscheme
constructs $scheme $drscheme
echo "== Pascal: the language"
survey $pascal
echo "== Pascal: the terminal under it and under the IDE (libs/terminal)"
survey $terminal
echo "== Pascal: TinyTurboPascal, its IDE (appkits/editor) and the ways it is shown"
survey $turbo
printf "  %5d %5d %s\n" 0 $(cat $P/appkits/editor/Turbo_model.mli | wc -l) appkits/editor/Turbo_model.mli
constructs $pascal $terminal $turbo
echo "== the playground's tests of the two (Testo; lines)"
wc -l $P/languages/scheme/tests/Unit_*.ml $P/languages/pascal/tests/Unit_*.ml | sed "s|$P/||; s/^/  /"
echo "== its golden frames of the two programs (tests/2d/golden)"
echo "  $(ls $P/tests/2d/golden | grep 'TinyDrScheme\|TinyTurboPascal' | tr '\n' ' ')"
echo "== what ix has already"
echo "  ix's Playground.mli lacks, of the playground's values: $(diff <(grep -o '^val [a-z_0-9]*' $P/playground/Playground.mli | sort) <(grep -o '^val [a-z_0-9]*' $T/lib_playground/Playground.mli | sort) | grep '^<' | sed 's/< val //' | tr '\n' ' ')"
echo "  keys the Plan 9 loop names (Plan9_loop.key_name): $(grep -o '"[A-Z][a-z]*"' $T/lib_playground/platforms/Plan9_loop.ml | sort -u | tr '\n' ' ')"
echo "  lib_core's Unix: tcgetattr $(grep -c 'val tcgetattr' $T/lib_core/system/Unix.mli), select $(grep -c 'val select' $T/lib_core/system/Unix.mli); a Map in lib_core: $(ls $T/lib_core/*/Map.ml 2> /dev/null | wc -l)"
echo "  the draw device's own letters (lib_graphics's Font.string): $(grep -c 'val string' $T/lib_graphics/Font.mli); the draw platform uses them: $(grep -c 'Font\.' $T/lib_playground/platforms/draw/Playground_platform.ml)"

# The copies here against the playground's (plan_scheme.md's and
# plan_pascal.md's stage 1): each file with the lines it gained and
# lost, and the files that are ix's own
echo "== ix's copies against the playground's (lines here, +gained -lost)"
copy() {   # ix's directory, the playground's
  local here=$T/$1 there=$P/$2 f b
  for f in $here/*.ml $here/*.mli; do
    b=$(basename $f)
    if [ -f $there/$b ]; then printf "  %5d +%-4d -%-4d %s\n" $(cat $f | wc -l) $(diff $there/$b $f | grep -c '^>') $(diff $there/$b $f | grep -c '^<') $1/$b
    elif [ -z "$3" ] || [ ! -f $P/$3/$b ]; then printf "  %5d %-11s %s\n" $(cat $f | wc -l) "ix's own" $1/$b; fi
  done
}
copy languages/scheme languages/scheme languages/sexpr
copy languages/scheme languages/sexpr languages/scheme | grep -v "ix's own"
copy languages/pascal languages/pascal
copy lib_terminal libs/terminal
copy languages/scheme/tests languages/scheme/tests
copy languages/pascal/tests languages/pascal/tests
# (plan_scheme.md's stage 3 and plan_gui.md: TinyDrScheme, the gui and
# the 7GUIs)
copy lib_gui libs/gui
copy lib_playground/apis playground/apis
copy lib_playground/ways playground/ways
copy editors/drscheme apps/devtools
copy apps/office/formula languages/formula
copy apps/office/document appkits/document | grep -v "ix's own"
copy apps/office/sheet appkits/sheet appkits/sheet_view | grep -v "ix's own"
copy apps/office/sheet appkits/sheet_view appkits/sheet | grep -v "ix's own"
copy examples examples
copy examples/gui4 examples/gui4
copy examples/gui4/tests examples/gui4/tests
