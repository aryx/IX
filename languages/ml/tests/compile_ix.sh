#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-ml over all of ix's .ml (plan_ml_bootstrap.md, goal 2): each
# compiled (its names resolved, its types checked, its code made, the
# object to /dev/null); the other units found in its own directory,
# then its program's directories (languages/c's, the kernel's...), then
# the libraries several programs use (lib_core, assembler, machine...),
# then the stdlib (lib_core's). Then each kind of first
# error with its count, and the counts by top directory.
# With -v, each file's error. The kinds are the errors with their names
# taken out: "unbound module Fpath" and "unbound module Logs" are one.
# usage: compile_ix.sh [-v] [path...]

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
ML=${ML:-$ROOT/_build/default/languages/ml/Main.exe}
verbose=; [ "${1:-}" = -v ] && { verbose=1; shift; }
cd $ROOT
declare -A all bad kinds incs
# a program's directories: those with a .ml under its root
# (and dune's copy of each, for the Parser and the Lexer it made of a .mly and a .mll)
dirs() { for d in $(git ls-files -- "$1" | grep -E '\.ml[ily]?$' | grep -v '/tests/' | xargs -n1 dirname | sort -u); do echo -n "-I $d -I _build/default/$d "; done; }
# lib_core: ix's commons, and the stdlib
shared="$(dirs lib_core) $(dirs lib_compression) $(dirs lib_security) $(dirs lib_9p) $(dirs lib_graphics) $(dirs assembler) $(dirs machine)"
# not the tests (the author: "let's not compile testing code with mini-ml for now": they
# use Testo and Alcotest), nor the stdlib itself, nor what needs SDL (Tsdl: mini-qemu's
# window, and its Main, which opens it; "it would require too many things")
# the kernel's Memdata is generated from principia's fonts (its Makefile's, conf/mkpixdata.py):
# where it was not built, the two units that name it are left out
memdata=kernel/9pi/build/pi1-ocaml
nomem='^$'; [ -d $memdata ] || nomem='^kernel/9pi/lib_graphics/ocaml/(Memchan|Memfont)\.ml$'
for f in $(git ls-files -- "$@" | grep -E '\.ml$' | grep -vE "$nomem" | grep -vE '/tests/|^lib_core/(core|base|collections|printing|parsing|system)/|^raspberry/(Sdl_display|Main)\.ml$'); do
  d=${f%%/*}; all[$d]=$((${all[$d]:-0} + 1))
  # the program's root: languages/c, languages/ml, or the top directory
  root=$d; [ $d = languages ] && root=$(echo $f | cut -d/ -f1-2)
  # (the kernels' host tools are programs of their own: lib_core's Chan, not mini-9pi's)
  # (and mini-oberon a kernel of its own: its Files and its Display, not the others')
  case $f in kernel/oberon/*) root=kernel/oberon;; kernel/tools/*) root=kernel/tools;; kernel/9pi/filesystems/user/*|kernel/9pi/devices/storage/user/*|kernel/9pi/buses/user/*) root=$(dirname $f);; esac
  [ -z "${incs[$root]:-}" ] && incs[$root]=$(dirs $root)
  [ $root = kernel ] && [ -d $memdata ] && incs[$root]="${incs[$root]} -I $memdata"
  # (mini-usbd: with the kernel's lib_usb, which it shares)
  [ $root = kernel/9pi/buses/user/usbd ] && incs[$root]="$(dirs kernel/9pi/buses/user/usbd) $(dirs kernel/9pi/buses/lib_usb)"
  [ $root = kernel/9pi/filesystems/user/dossrv ] && incs[$root]="$(dirs kernel/9pi/filesystems/user/dossrv) $(dirs kernel/9pi/filesystems/lib_fat)"
  err=$($ML -m 7 -o /dev/null ${incs[$root]} $shared $f 2>&1 >/dev/null | head -1)
  [ -z "$err" ] && continue
  bad[$d]=$((${bad[$d]:-0} + 1))
  # the message without its file and line, its names and numbers out
  kind=$(echo "$err" | sed -E 's/^[^ ]*:[0-9]+: //; s/^[^ ]*: //' \
    | sed -E 's/(unbound (module|value|constructor|type|label)) .*/\1/; s/, [~a-zA-Z_.0-9]+:?( \.\( \))?:/:/; s/[0-9]+/N/g' | cut -c1-70)
  kinds[$kind]=$((${kinds[$kind]:-0} + 1))
  [ -n "$verbose" ] && echo "$f: $(echo "$err" | sed -E 's/^[^ ]*:([0-9]+): /\1: /' | cut -c1-140)"
done
for k in "${!kinds[@]}"; do printf "%5d  %s\n" ${kinds[$k]} "$k"; done | sort -rn
total=0; failed=0
for d in $(echo "${!all[@]}" | tr ' ' '\n' | sort); do
  printf "%-18s %4d files, %4d fail\n" $d ${all[$d]} ${bad[$d]:-0}
  total=$((total + ${all[$d]})); failed=$((failed + ${bad[$d]:-0}))
done
echo "$((total - failed)) of $total compile"
