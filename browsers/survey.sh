#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/plan_browser.md: what each program of
# the author's mini-chrome stands on (the modules its main names, and
# theirs, by ocamldep), the part of it a Wikipedia article asks for,
# by where it would go in ix, what mini-ml says of each of its files
# (its first refusal only: a file has others behind it), the constructs
# mini-ml has not, counted, and what ix has already.
# As apps/office/survey.sh, which is TinyOffice's.
# usage: browsers/survey.sh [-ml] [-net] [-log] [-files F] [mini-chrome [playground]]
#   -ml:  also mini-ml's first refusal of each file (a minute)
#   -net: also the article itself, asked of Wikipedia by mini-curl
#   -log: also how each of mini-chrome's files grew (its lines in the
#         first commit, 2026-09-30, the playground's TinyChrome moved;
#         now; the commits that changed it): what was added since, and
#         its commits say for which site, is the first place to cut
#   -files F: also each set's files written to F, a line "where file"
#         (browsers/coverage.sh's, which says what of each the article runs)

cd "$(dirname "$0")"
ML=; NET=; LOG=; FILES=
while [ "${1#-}" != "$1" ]; do case $1 in -ml) ML=1;; -net) NET=1;; -log) LOG=1;; -files) FILES=$(realpath $2); : > $FILES; shift;; esac; shift; done
M=${1:-$HOME/github/mini-chrome}
P=${2:-$HOME/playground}
T=..
[ -d $M/languages/css ] || { echo "no $M/languages/css"; exit 1; }
[ -d $P/libs ] || { echo "no $P/libs"; exit 1; }
D=$(mktemp -d); trap 'rm -rf $D' EXIT

# every file, mini-chrome's first: a name both have (Url, Http, Png)
# is mini-chrome's, as its dune files say (-open Network, -open Images)
{ find $M/languages $M/libs $M/src $M/tools -name '*.ml' | sort
  # an interface alone (box_types.mli: types, no .ml)
  for i in $(find $M/languages $M/libs $M/src -name '*.mli' | sort); do [ -f ${i%i} ] || echo $i; done
  find $P/libs $P/playground -name '*.ml' -not -path '*/tests/*' -not -path '*/web/*' | sort
} > $D/files
xargs ocamldep -modules < $D/files > $D/deps 2> /dev/null

# the modules ix has: a playground module of the same name is not to
# copy (a mini-chrome module of that name is another thing: counted)
find $T/lib_core $T/lib_graphics $T/lib_playground $T/lib_gui $T/lib_compression $T/lib_crypto -name '*.ml' \
  | sed 's|.*/||; s/\.ml$//' | sort -u > $D/here
# ix's Zlib is the playground's Zlib, Inflate, Deflate, Adler32 and Crc32
printf 'Inflate\nDeflate\nAdler32\nCrc32\n' >> $D/here

# closure "roots" "cut" [all]: the files the roots stand on, a cut
# module and what it alone names left out; ix's own (above) said apart,
# in $D/had, unless all is said
closure() {
  awk -v roots="$1" -v cut="$2" -v M="$M/" -v had="$D/had" -v all="$3" '
    FILENAME ~ /here$/ { if (all == "") here[$1] = 1; next }
    { f = $1; sub(/:$/, "", f); m = f; sub(/.*\//, "", m); sub(/\.mli?$/, "", m)
      m = toupper(substr(m, 1, 1)) substr(m, 2)
      if (m in file) next
      file[m] = f; s = ""; for (i = 2; i <= NF; i++) s = s " " $i; deps[m] = s }
    END {
      n = split(cut, c, " "); for (i = 1; i <= n; i++) no[c[i]] = 1
      n = split(roots, todo, " ")
      for (i = 1; i <= n; i++) {
        m = todo[i]
        if (m in seen || !(m in file) || m in no) continue
        if (m in here && index(file[m], M) != 1) { if (!(m in h)) { h[m] = 1; printf "%s ", m > had }; continue }
        seen[m] = 1; print file[m]
        k = split(deps[m], d, " "); for (j = 1; j <= k; j++) todo[++n] = d[j]
      }
    }' $D/here $D/deps
}

lines() { cat /dev/null "$@" 2> /dev/null | wc -l; }
mls() { grep '\.ml$' $1; }
# a file's interface, and an interface alone
mlis() { mls $1 | sed 's/\.ml$/.mli/'; grep '\.mli$' $1; }
# a set of files by folder: its .ml lines, its .mli's, the modules
table() {   # the file of the list
  local ml=0 mli=0 n=0 a b
  for d in $(sed 's|/[^/]*$||' $1 | sort -u); do
    fs=$(grep "^$d/[^/]*$" $1)
    echo "$fs" > $D/fs; a=$(lines $(mls $D/fs)); b=$(lines $(mlis $D/fs))
    ml=$((ml + a)); mli=$((mli + b)); n=$((n + $(echo "$fs" | wc -l)))
    printf "  %6d %5d  %-34s %s\n" $a $b "$(echo $d | sed "s|^$M/||; s|^$P/|playground:|")" \
      "$(for f in $fs; do printf '%s(%d) ' $(basename ${f%i} .ml) $(lines $f); done)"
  done
  printf "  %6d %5d  all (%d files)\n" $ml $mli $n
}
total() { printf "%3d files, %6d lines of .ml, %6d of .mli" $(cat $1 | wc -l) $(lines $(mls $1)) $(lines $(mlis $1)); }

# the constructs mini-ml has not, in a set of files
constructs() {
  local ml=$(mls $1) mli=$(mlis $1)
  printf "  optional arguments: %d definitions (%d in the interfaces); labels in the interfaces: %d; polymorphic variants: %d lines; Map.Make and other functors: %d; let open: %d; lazy: %d; Bigarray: %d lines; Mutex, Condition, Thread: %d lines; objects (#, object): %d; exceptions defined: %d; Printf: %d lines; Hashtbl: %d lines\n" \
    $(cat /dev/null $ml | grep -c '^ *\(let\|and\).*[ (]?[(a-z]') $(cat /dev/null $mli 2> /dev/null | grep -c '?[a-z_]*:') \
    $(cat /dev/null $mli 2> /dev/null | grep -c '[ (]~\?[a-z_]*:[a-z( ]' ) \
    $(cat /dev/null $ml | grep -c '[ (|\[]`[A-Z]') $(cat /dev/null $ml | grep -c '\.Make\|^module.*functor\|^module [A-Z][a-z_]* *(') \
    $(cat /dev/null $ml | grep -c 'let open') $(cat /dev/null $ml | grep -c '\blazy\b\|Lazy\.') $(cat /dev/null $ml | grep -c 'Bigarray') \
    $(cat /dev/null $ml | grep -c 'Mutex\.\|Condition\.\|Thread\.') $(cat /dev/null $ml | grep -c '^ *object\b\|[a-z)]#[a-z]') \
    $(cat /dev/null $ml | grep -c '^exception') $(cat /dev/null $ml | grep -c 'Printf\.') $(cat /dev/null $ml | grep -c 'Hashtbl\.')
}
# made by mini-chrome's dune files (a data file as a string, a file chosen by OCaml's version)
generated="Ua_sheet Js_prelude Script_prelude Site_pages Site_pictures Tube_files Brotli_words Per_domain Worker_spawn"
# the modules a set names that are nobody's: OCaml's stdlib and opam's;
# those lib_core has not are the ones to look at
outside() {
  for m in $(grep -F -f <(sed 's/$/:/' $1) $D/deps | cut -d: -f2 | tr ' ' '\n' | sort -u); do
    grep -q "/$m\.mli\?:\|/$(echo ${m:0:1} | tr A-Z a-z)${m:1}\.mli\?:" $D/deps && continue
    case " $generated " in *" $m "*) continue;; esac
    find $T/lib_core $T/lib_graphics $T/lib_playground $T/lib_gui $T/lib_compression $T/lib_crypto -name "$m.ml" | grep -q . || printf "%s " $m
  done
}
# mini-ml's first refusal of each file of a set
inc=""
for d in system core base collections printing parsing concurrency commons; do inc="$inc -I $T/lib_core/$d"; done
for d in $T/lib_graphics/core $T/lib_graphics/geometry $T/lib_graphics/images $T/lib_graphics/software $T/lib_playground $T/lib_playground/core $T/lib_playground/random $T/lib_compression $T/lib_crypto; do inc="$inc -I $d"; done
for d in $(sed 's|/[^/]*$||' $D/files | sort -u); do inc="$inc -I $d"; done
refusals() {
  local err l none=0 n=0
  for f in $(mls $1); do
    n=$((n + 1))
    err=$($T/bin/mini-ml -m 7 -o /dev/null $inc $f 2>&1 > /dev/null | head -1)
    [ -z "$err" ] && { none=$((none + 1)); continue; }
    l=$(echo "$err" | grep -o "$(basename $f):[0-9]*:" | grep -o ':[0-9]*:' | tr -d ':')
    printf "  %-22s %s | %s\n" $(basename $f) "$(echo "$err" | sed "s/^\([^ ]*\.mli:[0-9]*\):.*/its \1/; s|^its .*/|its |; s/^[^ ]*\.ml:[0-9:]* *//" | cut -c1-40)" \
      "$([ "${l:-0}" -gt 0 ] && sed -n ${l}p $f | sed 's/^ *//' | cut -c1-56)"
  done
  echo "  $none of $n files compile as they are"
}
# how mini-chrome's files of a set grew since its first commit
grew() {
  local first=$(git -C $M rev-list --max-parents=0 HEAD | tail -1) was=0 now=0 new=0 f r old a b c
  git -C $M ls-tree -r --name-only $first > $D/first
  for f in $(mls $1 | grep "^$M/"); do
    r=${f#$M/}; b=$(lines $f); c=$(git -C $M log --oneline --follow -- $r | wc -l)
    old=$(grep "/$(basename $f)$" $D/first | head -1)
    if [ -n "$old" ]; then a=$(git -C $M show $first:$old | wc -l); was=$((was + a)); else a=-; new=$((new + b)); fi
    now=$((now + b))
    printf "    %-22s %5s -> %5d, %2d commits\n" $(basename $f) $a $b $c
  done
  echo "  since the first commit: $was lines then, $now now, $new of them in files that were not there"
}
show() {   # title, roots, cut
  echo "== $1"
  rm -f $D/had; closure "$2" "$3" > $D/set
  [ -n "$FILES" ] && sed "s|^|${1%%:*} |" $D/set >> $FILES
  table $D/set
  [ -f $D/had ] && echo "  ix has, not counted: $(cat $D/had)"
  constructs $D/set
  echo "  named and not in lib_core: $(outside $D/set)"
  [ -n "$ML" ] && refusals $D/set
  [ -n "$LOG" ] && grew $D/set
}

echo "== what each program of mini-chrome stands on (its main's modules and theirs; the playground's that ix has are in)"
for r in MiniChrome MiniFirefox MiniNetscape MiniMosaic MiniLynx MiniCurl MiniHttpd MiniNode; do
  closure "$r" "" all > $D/set
  printf "  %-14s %s\n" $r "$(total $D/set)"
done

# what ix's programs would stand on, by where it would go. The cuts:
# what a Wikipedia article does not ask for (plan_browser.md says why)
nocompress="Brotli Zstd"
notls="Tls12 P256"
nopictures="Webp Ico Gif"
noscripts="Browser_script Js_value Js_module Script_types Web_sockets Websocket Websocket_client"
nospeed="Stopwatch Per_domain Mini_opti Task_names Worker_spawn Css_animation Shadow_tree Frames"
cut="$nocompress $notls $nopictures $noscripts $nospeed"
# what Tls13 and X509 name
crypto="Sha256 Sha512 Chacha20 Poly1305 Aes Gcm Bignum Rsa Ecdsa Hmac Hkdf Chacha20_poly1305 X25519"

show "lib_crypto/: TLS 1.3's hashes, ciphers, key exchange and signatures" \
  "$crypto" "$cut"
show "lib_networking/: URLs, HTTP/1.1, cookies, TLS 1.3 and X.509, a request (crypto and compression apart)" \
  "Http_request Http_client Urlencoded" "$cut $crypto Gzip Huffman"
show "lib_compression/: gzip" "Gzip" "$cut"
show "lib_graphics/software/: pictures read (PNG, JPEG, SVG) and drawn (Blit)" \
  "Png Jpeg Svg Blit" "$cut Xml Dom"
show "browsers/html/: the tree, HTML and XML read" "Html_tree Charset Forms Line_mode Xml" "$cut"
show "browsers/css/: the sheets read, the cascade, the computed values" "Computed Css" "$cut Dom"
show "browsers/engine/: boxes laid out (flow, inline, tables, flexbox, grid), drawn, a page fetched" \
  "Browser_page Browser_forms Browser_history Hit Fetch Browser_url" \
  "$cut Dom Html_tree Html_lexer Charset Forms Line_mode Computed Cascade Css_syntax Css_values Selectors Looks Css_grid Css_logical Http Http_client Http_request Http_cache Cookie_jar Url Urlencoded Worker Png Jpeg Svg Gif"
show "the engine whole, the seven above (what mini-netscape needs besides its window)" \
  "Browser_page Browser_forms Browser_history Hit Fetch Browser_url Blit" "$cut"
show "browsers/javascript/: the engine (mini-node; no page asks it here)" "Js_eval Js_json Js_promise Js_regexp Js_builtins Js_globals" "Mini_opti Stopwatch"
show "browsers/webapi/: scripts in a page (the document, its events, timers, fetch; over the two engines)" "Browser_script" \
  "Web_sockets Websocket Websocket_client WebSocket AudioContext Stopwatch Per_domain Mini_opti Task_names Js_eval Js_value Js_module Js_json Js_promise Js_regexp Js_builtins Js_globals Js_props Js_operators Js_utf16 Js_coroutine Js_frame Js_scope Js_ast Js_parse Js_lexer Dom Dtd Shadow_tree Html_tree Html_lexer Charset Forms Computed Cascade Css Css_syntax Css_values Selectors Looks Browser_page Browser_url Box_tree Box_layout Html_layout Hit Http Http_client Http_request Url Urlencoded Cookie Cookie_jar Fetch Worker Base64 Lehmer"
echo "== the programs' own files (lines of .ml)"
for f in tools/netscape/MiniNetscape tools/mosaic/MiniMosaic src/chrome/Browser_tab tools/lynx/Lynx tools/lynx/MiniLynx tools/curl/Curl tools/curl/MiniCurl tools/httpd/Httpd tools/httpd/MiniHttpd tools/node/Node_host tools/node/MiniNode; do
  printf "  %5d %s\n" $(lines $M/$f.ml) $f.ml
done
echo "== the data read as OCaml strings at build time (lines)"
wc -l $M/data/css/ua.css $M/data/prelude/library.js | sed "s|$M/||; s/^/  /" | head -2
echo "  $(cat $M/data/prelude/web/*.js | wc -l) data/prelude/web/*.js ($(ls $M/data/prelude/web/*.js | wc -l) files: the page's objects written in JavaScript)"
echo "== mini-chrome's tests of what is above (Testo; lines of .ml by suite)"
for s in html css layout network network_unix images compression js browser tools xml; do
  printf "  %5d tests/%s\n" $(lines $M/tests/$s/*.ml) $s
done
echo "== the playground's Tiny browsers, for the size (lines)"
wc -l $P/apps/internet/Tiny{Mosaic,Netscape,Firefox,Chrome}.ml | sed "s|$P/||; s/^/  /"

if [ -n "$NET" ]; then
  U=https://en.wikipedia.org/wiki/OCaml
  echo "== the article ($U), asked by mini-curl"
  $M/bin/mini-curl -v $U > $D/page 2> $D/head
  echo "  $(cat $D/page | wc -c) bytes of HTML; $(grep -a -i '^< content-encoding' $D/head | tr -d '\r' | sed 's/< //')"
  echo "  style sheets linked: $(grep -o '<link rel="stylesheet"' $D/page | wc -l); <style>: $(grep -o '<style' $D/page | wc -l); scripts: $(grep -o '<script' $D/page | wc -l); tables: $(grep -o '<table' $D/page | wc -l)"
  echo "  pictures by kind: $(grep -o '<img[^>]*src="[^"?]*' $D/page | sed 's/.*\.//' | grep -v / | sort | uniq -c | tr '\n' ' ')"
  for s in $(grep -o '<link rel="stylesheet" href="[^"]*"' $D/page | sed 's/.*href="//; s/"$//; s/&amp;/\&/g'); do
    $M/bin/mini-curl "https://en.wikipedia.org$s" > $D/sheet 2> /dev/null
    echo "  a sheet: $(cat $D/sheet | wc -c) bytes; display: $(grep -o 'display:[a-z-]*' $D/sheet | sort | uniq -c | sort -rn | awk '{printf "%s(%d) ", $2, $1}' | sed 's/display://g')"
    echo "    float: $(grep -o 'float:' $D/sheet | wc -l); position: $(grep -o 'position:[a-z]*' $D/sheet | sort | uniq -c | awk '{printf "%s(%d) ", $2, $1}' | sed 's/position://g'); @media: $(grep -o '@media' $D/sheet | wc -l); var(): $(grep -o 'var(' $D/sheet | wc -l); calc(): $(grep -o 'calc(' $D/sheet | wc -l)"
  done
  echo "  the server's certificates (openssl): $(echo | timeout 10 openssl s_client -connect en.wikipedia.org:443 -servername en.wikipedia.org 2> /dev/null | grep 'a:PKEY\|Cipher is\|Server Temp' | sed 's/^ *//' | tr '\n' ';')"
fi
