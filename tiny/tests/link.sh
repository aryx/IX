# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# For the tests, sourced (ROOT set): link_tm out file.tm..., each file
# assembled by tiny-assembler to an object beside out (out.1.o...),
# then all linked by tiny-linker into the image out, the first at 0.
# TA and TL: the two programs (dune's by default; mkfiles/check.sh
# gives ix's).
TA=${TA:-$ROOT/_build/default/tiny/TinyAssembler.exe}
TL=${TL:-$ROOT/_build/default/tiny/TinyLinker.exe}
link_tm() {
  local out=$1 f k=0 objs=()
  shift
  for f in "$@"; do k=$((k + 1)); objs+=($out.$k.o); $TA -o $out.$k.o $f || return 1; done
  $TL -o $out "${objs[@]}"
}
