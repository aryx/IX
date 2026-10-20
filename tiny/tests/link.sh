# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# For the tests, sourced (ROOT set): link_tm out file.tm..., each file
# assembled by tiny-assembler to an object beside out (out.1.o...), an
# object (.o) taken as it is, then all linked by tiny-linker into the
# image out, the first at 0. TA and TL: the two programs (dune's by
# default; mkfiles/check.sh gives ix's).
# ml_lib dir: tiny-ml's standard library, TinyLibCore/'s modules in
# their order, compiled by $TML into dir (each -nostdlib after the ones
# before it: X.tm, X.tmi, X.o), for tiny-ml -L dir; LIB_O its objects,
# to link after a program's.
TA=${TA:-$ROOT/_build/default/tiny/TinyAssembler.exe}
TL=${TL:-$ROOT/_build/default/tiny/TinyLinker.exe}
link_tm() {
  local out=$1 f k=0 objs=()
  shift
  for f in "$@"; do
    case $f in
      *.o) objs+=($f) ;;
      *) k=$((k + 1)); objs+=($out.$k.o); $TA -o $out.$k.o $f || return 1 ;;
    esac
  done
  $TL -o $out "${objs[@]}"
}
CORE="Stdlib Char Seq List String Bytes Array Option Int64 Filename Buffer Hashtbl Common Sha1"
ml_lib() {
  local dir=$1 m before=
  mkdir -p $dir
  LIB_O=
  for m in $CORE; do
    $TML -c -nostdlib -o $dir/$m.tm $before $ROOT/tiny/TinyLibCore/$m.ml && $TA -o $dir/$m.o $dir/$m.tm || return 1
    before="$before $dir/$m.tmi"; LIB_O="$LIB_O $dir/$m.o"
  done
}
