#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/plan_typesetting.md: principia's troff
# and the programs round it, counted; what its manual pages, its
# papers (.ms) and its books (LaTeX in .nw) really ask of a formatter
# (the requests, the escapes, the tables, the pictures, the equations,
# the commands, each counted); what the macro packages themselves ask
# of troff; and what ix already has to stand on.
# As scripts/stats/pdf_survey.sh.
# usage: scripts/stats/typesetting_survey.sh [principia] [goken]

cd "$(dirname "$0")"
T=../..
S=$(readlink -f ${1:-$HOME/github/principia-softwarica})
G=$(readlink -f ${2:-$HOME/goken})
[ -d $S/typesetting/troff ] || { echo "no $S/typesetting/troff"; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf $tmp' EXIT

# "n name  n name ..." on lines of at most 100 columns, the first $1 of them
row() { sort | uniq -c | sort -rn | head -${1:-1000} | awk '{printf "%s %s  ", $1, $2} END {print ""}' | fold -s -w 100 | sed 's/^/  /'; }
requests() { grep -ohE "^[.'][A-Za-z0-9]{1,2}" "$@" | tr "'" .; }
escapes() { grep -ohE '\\(\(..|\*\(..|\*.|f\(..|f.|s[-+]?[0-9]+|[a-zA-Z&|^0-9-])' "$@"; }
count() { grep -l "$1" "${@:2}" | wc -l; }
lines() { cat "$@" 2>/dev/null | wc -l; }

echo "== principia at $(git -C $S log -1 --format='%h %ad' --date=short): typesetting/, lines of .c .h .y .l"
for d in troff pic grap eqn tbl htmlroff troff2html page; do
  printf "  %6d %s\n" $(find $S/typesetting/$d -name '*.[chyl]' | xargs cat | wc -l) $d
done
printf "  %6d %s\n" $(lines $S/typesetting/misc/ms2html.c) misc/ms2html.c $(lines $S/typesetting/misc/deroff.c) misc/deroff.c $(lines $S/typesetting/misc/html2ms.c) misc/html2ms.c
echo "== the macro packages, and what they ask of troff"
for m in $(find $S $G -not -path '*/.git/*' \( -name tmac.s -o -name tmac.an \) | sort); do
  printf "  %s: %d lines; diversions (di da) %d, traps (wh ch) %d, environments (ev) %d, conditionals (if ie el) %d, registers set (nr) %d, strings (ds as) %d, macros (de am) %d\n" \
    "$(echo $m | sed "s|$S/|principia/|; s|$G/|goken/|")" $(lines $m) \
    $(grep -cE "^[.'] *d[ia]\b" $m) $(grep -cE "^[.'] *(wh|ch)\b" $m) $(grep -cE "^[.'] *ev\b" $m) \
    $(grep -cE "^[.'] *(if|ie|el)\b" $m) $(grep -cE "^[.'] *nr\b" $m) $(grep -cE "^[.'] *[da]s\b" $m) $(grep -cE "^[.'] *(de|am)\b" $m)
done

man=$(find $S/ROOT/docs/man/[1-8] -type f | sort)
echo "== the manual: $(echo "$man" | wc -l) files ($(count '^\.TH' $man) pages, with a .TH), $(lines $man) lines"
echo "  pages with a table (.TS) $(count '^\.TS' $man), a picture (.PS) $(count '^\.PS' $man), an equation (.EQ) $(count '^\.EQ' $man), a macro of their own (.de) $(count '^\.de' $man), a conditional (.if .ie) $(count '^\.i[fe]' $man)"
echo "  requests ($(requests $man | sort -u | wc -l) different), the 50 most used:"
requests $man | row 50
echo "  escapes, the 30 most used:"
escapes $man | row 30

ms=$(cd $S; git -c core.quotepath=off ls-files '*.ms' | sed "s|^|$S/|")
echo "== the papers: $(echo "$ms" | wc -l) .ms files, $(lines $ms) lines"
echo "  tables (.TS) $(cat $ms | grep -c '^\.TS'), pictures (.PS) $(cat $ms | grep -c '^\.PS'), equations (.EQ) $(cat $ms | grep -c '^\.EQ'), graphs (.G1) $(cat $ms | grep -c '^\.G1'), PostScript pictures (.BP) $(cat $ms | grep -c '^\.BP'), macros (.de) $(cat $ms | grep -c '^\.de'), conditionals $(cat $ms | grep -cE '^\.(if|ie|el)')"
echo "  lines, tables, pictures, equations, .BP, macros, conditionals of each:"
for f in $ms; do
  printf "  %5d %2d %2d %2d %2d %2d %2d %s\n" $(lines $f) $(grep -c '^\.TS' $f) $(grep -c '^\.PS' $f) $(grep -c '^\.EQ' $f) $(grep -c '^\.BP' $f) $(grep -c '^\.de' $f) $(grep -cE '^\.(if|ie|el)' $f) "$(echo $f | sed "s|$S/||")"
done | sort -rn | tee $tmp/each
echo "  papers with a table $(awk '$2 > 0' $tmp/each | wc -l), a picture $(awk '$3 > 0' $tmp/each | wc -l), an equation $(awk '$4 > 0' $tmp/each | wc -l), a .BP $(awk '$5 > 0' $tmp/each | wc -l), a macro $(awk '$6 > 0' $tmp/each | wc -l), a conditional $(awk '$7 > 0' $tmp/each | wc -l); with no table and no picture $(awk '$2 == 0 && $3 == 0' $tmp/each | wc -l)"
echo "  requests ($(requests $ms | sort -u | wc -l) different):"
requests $ms | row
echo "  escapes, the 30 most used:"
escapes $ms | row 30
echo "  lower-case requests (troff's own, not a macro package's) by the papers that use them:"
for r in sp br ta ft ps vs nr in ll ne if ie de ds tr nf fi ce ti di wh ch am so bp; do
  printf "    .%s %d in %d papers\n" $r $(cat $ms | grep -cE "^[.']$r\b") $(grep -lE "^[.']$r\b" $ms | wc -l)
done | awk '{printf "%s", $0} NR % 3 == 0 {print ""} END {print ""}'

echo "== the tables: what their format lines say (the lines between .TS and the first that ends in a dot)"
cat $ms $man | awk '/^\.TS/ {t = 1; next} t && /;$/ {print "O " $0; next} t {print "F " $0; if ($0 ~ /\.$/) t = 0}' > $tmp/tbl
echo "  options: $(grep '^O' $tmp/tbl | sed 's/^O //; s/;//' | tr ', ' '\n\n' | grep . | sed 's/(.*//' | sort | uniq -c | sort -rn | awk '{printf "%s %s  ", $1, $2}')"
echo "  column letters: $(grep '^F' $tmp/tbl | sed 's/^F //; s/([^)]*)//g; s/f(*[A-Z][A-Z]*)*//g' | grep -o '[a-zA-Z|^_=]' | sort | uniq -c | sort -rn | awk '{printf "%s %s  ", $1, $2}')"
echo "  text blocks (T{) $(cat $ms $man | grep -c 'T{$'), widths w(...) $(grep -c 'w(' $tmp/tbl) format lines, .T& $(cat $ms $man | grep -c '^\.T&')"

pics=$(cd $S; git ls-files '*.pic' | sed "s|^|$S/|")
echo "== the pictures: $(echo "$pics" | wc -l) .pic files, $(lines $pics) lines, and the $(cat $ms | grep -c '^\.PS') .PS of the papers"
# ".PS <file" is a picture read from a file: it has no .PE
{ cat $pics; cat $ms | awk '/^\.PS *</ {next} /^\.PS/ {p = 1; next} /^\.PE/ {p = 0} p'; } | grep -v '^"' > $tmp/pic
echo "  of the .PS, read from a file (.PS <file): $(cat $ms | grep -c '^\.PS *<')"
echo "  words of pic used ($(lines $tmp/pic) lines in all):"
grep -oE '\b(box|circle|ellipse|line|arrow|arc|spline|move|define|copy|sprintf|at|with|from|to|then|up|down|left|right|rad|wid|ht|width|height|dashed|dotted|invis|fill|cw|ccw|ljust|rjust|above|below|same|chop|by|between|last|scale|reset|sh|troff)\b|\[|\.(n|s|e|w|ne|nw|se|sw|c|start|end)\b|^[A-Z][A-Za-z0-9]*:' $tmp/pic | sed 's/^[A-Z].*:$/Label:/' | row

echo "== the equations: $(cat $ms $man | grep -c '^\.EQ') .EQ in the papers and the manual; words of eqn used:"
cat $ms $man | awk '/^\.EQ/ {p = 1; next} /^\.EN/ {p = 0} p' | grep -oE '\b(sub|sup|over|sqrt|from|to|sum|int|prod|left|right|pile|lpile|cpile|matrix|define|delim|size|roman|italic|bold|fat|mark|lineup|times|alpha|beta|pi|inf|partial|dot|hat|bar|vec|tilde|under|font|gsize|gfont)\b' | row

nw=$(cd $S; git ls-files '*.nw' | sed "s|^|$S/|")
cat $nw | awk '/^<<.*>>=$/ {c = 1; next} /^@( |$)/ {c = 0; next} !c' | grep -v '^ *%' > $tmp/prose
echo "== the books: $(echo "$nw" | wc -l) .nw files, $(lines $nw) lines, $(cat $nw | grep -c '^<<.*>>=$') code chunks; the prose between them, less its comments, $(lines $tmp/prose) lines"
echo "  commands ($(grep -oE '\\[a-zA-Z]+\*?' $tmp/prose | sort -u | wc -l) different), the 80 most used:"
grep -oE '\\[a-zA-Z]+\*?' $tmp/prose | row 80
echo "  the 80 are $(grep -oE '\\[a-zA-Z]+\*?' $tmp/prose | sort | uniq -c | sort -rn | head -80 | awk '{s += $1} END {print s}') of the $(grep -oE '\\[a-zA-Z]+\*?' $tmp/prose | wc -l) uses"
echo "  environments:"
grep -oE '\\begin\{[a-zA-Z*]+\}' $tmp/prose | sed 's/\\begin{//; s/}//' | row
echo "  packages: $(cat $nw $S/docs/latex/Packages.tex | grep -v '^ *%' | grep -oE '\\usepackage(\[[^]]*\])?\{[^}]*\}' | sed 's/.*{//; s/}//; s|.*/||' | sort | uniq -c | sort -rn | awk '{printf "%s %s  ", $1, $2}')"
echo "  classes: $(cat $nw | grep -v '^ *%' | grep -oE '\\documentclass(\[[^]]*\])?\{[^}]*\}' | sort | uniq -c | sort -rn | awk '{printf "%s %s  ", $1, $2}')"
# verbatim and \verb taken out first: a $ in them is a dollar
awk '/\\begin\{(verbatim|vdiagram|Verbatim)\}/ {v = 1} !v {print} /\\end\{(verbatim|vdiagram|Verbatim)\}/ {v = 0}' $tmp/prose | sed 's/\\verb\(.\)[^|+!"]*\1//g; s/\[\[[^]]*\]\]//g; s/\\\$//g' > $tmp/math
echo "  math: $(grep -c '\$' $tmp/math) lines with a \$ (outside verbatim, \\verb, [[ ]] and \\\$); in them: $(grep '\$' $tmp/math | grep -oE '\\(frac|sqrt|sum|int|times|to|log|ln|le|ge|leq|geq|ne|approx|infty|alpha|beta|pi|mu|lambda|in|cdot|ldots|rightarrow|Rightarrow|lfloor|rfloor|text|atop|pm|sim|equiv|bmod)\b|[_^]' | sort | uniq -c | sort -rn | awk '{printf "%s %s  ", $1, $2}')"
echo "  display math: \\[ $(grep -c '\\\[' $tmp/math), \$\$ $(grep -c '\$\$' $tmp/math), equation/align $(grep -cE '\\begin\{(equation|align|eqnarray|displaymath)' $tmp/prose)"
echo "  pictures included, by their kind: $(grep -oE '\\includegraphics(\[[^]]*\])?\{[^}]*\}' $tmp/prose | sed 's/.*{//; s/}//' | while read p; do f=$(cd $S; git ls-files | grep -m1 "/$(basename $p)\(\.\(png\|jpg\|gif\|pdf\|eps\|ps\)\)\?$"); [ -n "$f" ] && echo ${f##*.} || echo made-by-the-build; done | sort | uniq -c | awk '{printf "%s %s  ", $1, $2}')"
echo "  the macros the books share (docs/latex): \\newcommand $(cat $S/docs/latex/*.tex | grep -v '^ *%' | grep -c '\\newcommand'), \\newif $(cat $S/docs/latex/*.tex | grep -v '^ *%' | grep -c '\\newif'), \\def $(cat $S/docs/latex/*.tex | grep -v '^ *%' | grep -c '\\def\b'), \\newenvironment and its like $(cat $S/docs/latex/*.tex | grep -v '^ *%' | grep -cE '\\(newenvironment|DefineVerbatimEnvironment|newtcolorbox)')"
echo "  the smallest: $(for f in $nw; do printf "%d %s\n" $(lines $f) $(echo $f | sed "s|$S/||"); done | sort -n | head -6 | awk '{printf "%s (%s)  ", $2, $1}')"

echo "== what ix has (lines of .ml, of .mli)"
for u in apps/office/richtext/Page apps/office/richtext/Rich lib_graphics/pdf/Pdf_write lib_graphics/fonts/Standard_widths lib_playground/platforms/Shape_render_pdf lib_graphics/pdf/Pdf_render browsers/html/Line_mode lib_graphics/images/Png lib_graphics/images/Jpeg apps/page/Pageview; do
  printf "  %5d %5d %s\n" $(lines $T/$u.ml) $(lines $T/$u.mli) $u
done
echo "  ix's own documents in Markdown: $(cd $T; git ls-files '*.md' | wc -l) files, $(cd $T; git ls-files '*.md' | xargs cat | wc -l) lines"
echo "== ix's programs with a page in principia's manual, section 1 or 8 (mini-x for x)"
has=""; hasnot=""
for b in $(ls $T/bin | grep '^mini-' | sed 's/^mini-//'); do
  if [ -f $S/ROOT/docs/man/1/$b ] || [ -f $S/ROOT/docs/man/8/$b ]; then has="$has $b"; else hasnot="$hasnot $b"; fi
done
echo "  $(echo $has | wc -w) have:$has" | fold -s -w 100 | sed '2,$s/^/    /'
echo "  $(echo $hasnot | wc -w) have not (some are under another page's name):$hasnot" | fold -s -w 100 | sed '2,$s/^/    /'
echo "== what there is to compare with"
for p in $G/ROOT/arch/boot-gcc/bin/troff $G/ROOT/arch/boot-gcc/bin/tbl $G/ROOT/arch/boot-gcc/bin/eqn $G/ROOT/arch/boot-gcc/bin/pic $G/ROOT/arch/boot-gcc/bin/ms2html $G/ROOT/arch/boot-gcc/bin/deroff; do
  [ -x $p ] && echo "  goken's $(basename $p): built" || echo "  goken's $(basename $p): not built"
done
for p in nroff groff pic tbl eqn pdflatex mandoc; do
  command -v $p > /dev/null && echo "  this machine's $p: $(command -v $p)" || echo "  this machine's $p: none"
done
echo "  principia's own outputs, kept beside the sources: $(cd $S; git ls-files 'docs/articles/*.ps' | wc -l) .ps and $(cd $S; git ls-files 'docs/articles/*.pdf' | wc -l) .pdf in docs/articles"
