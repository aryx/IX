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
dirs() { for d in $(tests/ix_files.sh "$1" | grep -E '\.ml[ily]?$' | grep -v '/tests/' | xargs -n1 dirname | sort -u); do echo -n "-I $d -I _build/default/$d "; done; }
# lib_core: ix's commons, and the stdlib
shared="$(dirs lib_core) $(dirs lib_compression) $(dirs lib_crypto) $(dirs lib_networking) $(dirs lib_graphics) $(dirs assembler) $(dirs machine)"
# not the tests (the author: "let's not compile testing code with mini-ml for now": they
# use Testo and Alcotest), nor the stdlib itself, nor what needs SDL (Tsdl: mini-qemu's
# window, and its Main, which opens it; "it would require too many things"; tiny-machine's
# window the same, the one tiny program over Sdl_display, which tiny/mkfile does not build;
# mini-squeak's window, and lib_playground's platform with one, mini-drscheme's)
# the kernel's Memdata is generated from principia's fonts (its Makefile's, conf/mkpixdata.py):
# where it was not built, the two units that name it are left out
memdata=kernels/9pi/build/pi1-ocaml
nomem='^$'; [ -d $memdata ] || nomem='^kernels/9pi/lib_graphics/lib_memdraw/(Memchan|Memfont)\.ml$'
# mini-singularity's Programs is generated too (its mkfile's PROGRAMS, their names in an array,
# what each is granted): one of no name here, which has its types
W=$(mktemp -d); trap 'rm -rf $W' EXIT
(echo 'let names : string array = [||]'
 echo 'type grant = Registers of int * int | Interrupt of int'
 echo 'let grants : grant list array = [||]') > $W/Programs.ml
# and what mini-singml makes (its mkfile's MADE and g_%.given): the contracts' modules of
# their declarations, and each program's Given of its manifest (none: nothing)
SINGML=$ROOT/_build/default/kernels/singularity/singml/Main.exe
S=kernels/singularity
mkdir -p $W/contracts
for c in $S/contracts/*.contract; do $SINGML -o $W/contracts $c > /dev/null; done
for f in $(tests/ix_files.sh "$@" | grep -E '\.ml$' | grep -vE "$nomem" | grep -vE '/tests/|^lib_core/(core|base|collections|printing|parsing|system)/|^raspberry/(Sdl_display|Main)\.ml$|^tiny/TinyMachineWindow\.ml$|^languages/smalltalk/hosts/sdl/|^lib_playground/platforms/sdl/|^editors/turbopascal/hosts/sdl/'); do
  d=${f%%/*}; all[$d]=$((${all[$d]:-0} + 1))
  # the program's root: languages/c, languages/ml, or the top directory
  root=$d; [ $d = languages ] && root=$(echo $f | cut -d/ -f1-2)
  # (the kernels' host tools are programs of their own: lib_core's Chan, not mini-9pi's)
  # (and mini-oberon a kernel of its own: its Files and its Display, not the others')
  case $f in kernels/oberon/*) root=kernels/oberon;; kernels/squeak/*) root=kernels/squeak;; kernels/tools/*) root=kernels/tools;; kernels/9pi/filesystems/user/*|kernels/9pi/devices/storage/user/*|kernels/9pi/buses/user/*) root=$(dirname $f);; esac
  # (mini-singularity's programs: each its own, with its Given, the contracts and lib/, as
  # its mkfile's PMLI; the contracts' Console before lib_core's)
  # (mini-singml: over mini-ml's parser and its Ast)
  case $f in
  $S/programs/*)
    root=$(dirname $f); g=$W/g_$(basename $root); m=$root/Main.manifest; [ -f $m ] || m=/dev/null
    [ -d $g ] || { mkdir -p $g; $SINGML -given -o $g $m > /dev/null; }
    incs[$root]="-I $g -I $W/contracts -I $S/lib -I $S/contracts";;
  $S/singml/*) root=$S/singml; incs[$root]="$(dirs $S/singml) $(dirs languages/ml)";;
  # (the playground: its library before lib_core, whose commons/ has a Cmd of its own; a
  # platform's Playground_platform, the one without a window, for the games)
  # (and what stands on it that is no game: lib_gui, the playground's programs of apps/
  # and examples/, with the language and the kits they are linked with: games/mkgames's WITH)
  games/*|lib_playground/*|lib_physics/*|lib_gui/*|examples/*|editors/drscheme/*|apps/kits/*|apps/office/*) root=games; incs[$root]="-I examples -I examples/gui4 -I apps/office/document -I apps/office/richtext -I apps/office/paint -I apps/office/draw -I apps/office/shapes -I apps/office/parts -I apps/office/file_menu -I apps/office/sheet -I apps/office/formula -I apps/office -I apps/kits -I lib_gui -I languages/scheme -I lib_playground/platforms/ppm -I lib_playground/platforms -I lib_playground -I lib_playground/core -I lib_playground/random -I lib_playground/layers -I lib_playground/apis -I lib_playground/ways -I lib_physics -I lib_graphics/software -I lib_graphics";;
  # (mini-turbopascal: a Tui program of lib_terminal's, over mini-pascal)
  editors/turbopascal/*) root=editors/turbopascal; incs[$root]="$(dirs editors/turbopascal) $(dirs lib_terminal) $(dirs languages/pascal) -I lib_playground/random";;
  esac
  [ -z "${incs[$root]:-}" ] && incs[$root]=$(dirs $root)
  [ $root = kernels ] && [ -d $memdata ] && incs[$root]="${incs[$root]} -I $memdata"
  [ $root = kernels ] && incs[$root]="${incs[$root]} -I $W"
  # (mini-usbd: with the kernel's lib_usb, which it shares)
  [ $root = kernels/9pi/buses/user/usbd ] && incs[$root]="$(dirs kernels/9pi/buses/user/usbd) $(dirs kernels/9pi/buses/lib_usb)"
  # (mini-mkfs: with the kernel's lib_xv6fs)
  [ $root = kernels/tools ] && incs[$root]="$(dirs kernels/tools) $(dirs kernels/9pi/filesystems/lib_xv6fs)"
  # (mini-squeak: with Smalltalk, which is languages/smalltalk's; its Which is made by its mkfile)
  # (mini-pascal: with lib_terminal's Talk, and Lehmer under it; lib_terminal the same)
  [ $root = languages/pascal ] && incs[$root]="$(dirs languages/pascal) -I lib_terminal -I lib_playground/random"
  [ $root = lib_terminal ] && incs[$root]="-I lib_terminal -I lib_playground/random"
  [ $root = kernels/squeak ] && { mkdir -p $W/squeak; echo 'let system = Squeak.Squeak let depth = 16' > $W/squeak/Which.ml; incs[$root]="$(dirs kernels/squeak) $(dirs languages/smalltalk) -I $W/squeak"; }
  [ $root = kernels/9pi/filesystems/user/dossrv ] && incs[$root]="$(dirs kernels/9pi/filesystems/user/dossrv) $(dirs kernels/9pi/filesystems/lib_fat)"
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
