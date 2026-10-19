#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of TinyLibCore/, tiny-ml's standard library:
# 1. each module's .mli a subset of OCaml's own module: OCaml compiles
#    module _ : sig <the .mli> end = struct include List end (Hashtbl's
#    create without its ?random, as tiny programs call it); not Common
#    and Sha1, lib_core's and lib_crypto's;
# 2. TinyLibCore_tests/std.ml calls the modules' functions and prints the
#    results. OCaml runs the program on its own library, which says what
#    to expect (std.expected, recorded by RECORD=1 with the ocaml that
#    is in the PATH); tiny-ml builds it, tiny-cpu runs it (linked as
#    TinyML_test.sh's programs): the same lines;
# 3. digests.ml's digests (Sha1), on tiny-cpu, the same as sha1sum's.
# (old: TinyLibStd_test.sh, of TinyLibStd.ml, a file given to tiny-ml
# before a tool's)
# usage: TinyLibCore_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TML=${TML:-$ROOT/_build/default/tiny/TinyML.exe}
TC=${TC:-$ROOT/_build/default/tiny/TinyC.exe}
CPU=${CPU:-$ROOT/_build/default/tiny/TinyCPU.exe}
. $ROOT/tiny/tests/link.sh
L=$ROOT/tiny/TinyCRuntime
C=$ROOT/tiny/TinyLibCore
T=$ROOT/tiny/tests/TinyLibCore_tests
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0

for m in Stdlib Char Seq List String Bytes Array Option Filename Buffer Hashtbl; do
  fix=; [ $m = Hashtbl ] && fix="let create n = create n"
  printf 'module _ : sig\n%s\nend = struct include %s %s end\n' "$(cat $C/$m.mli)" $m "$fix" > $W/sig_$m.ml
  if out=$(ocaml $W/sig_$m.ml 2>&1) && [ -z "$out" ]; then echo "ok $m.mli: OCaml's $m has it"
  else echo "FAIL $m.mli: $(echo "$out" | grep -m3 -i 'error\|val\|type')"; failures=$((failures + 1)); fi
done

[ -n "${RECORD:-}" ] && ocaml $T/std.ml > $T/std.expected
cat > $W/main.c <<END
#include "$ROOT/tiny/TinyMLRuntime/core.c"
static value vstack[32768];
static value space0[65536];
static value space1[65536];
void main(void) { ml_run(vstack, space0, space1, 65536, 64); flush(); exit(0); }
END
printf 'exit:\n\tldw\tr1, 0(sp)\n\tsys\t0\n' > $W/exit.tm
$TC -o $W/main.tm $W/main.c || { echo "FAIL the runtime: tiny-c"; exit 1; }
for p in std digests; do
  if $TML -o $W/$p.tm $T/$p.ml && link_tm $W/$p.img $L/start.tm $L/udivmod.tm $W/exit.tm $W/$p.tm $W/main.tm; then
    timeout 60 $CPU $W/$p.img > $W/$p.out 2>&1
  else echo "FAIL $p: tiny-ml or the link"; failures=$((failures + 1)); fi
done
if diff $T/std.expected $W/std.out; then echo "ok std: OCaml's lines"; else echo "FAIL std"; failures=$((failures + 1)); fi

# the same strings as digests.ml's, through sha1sum
{ for s in "" abc "$(printf 'a%.0s' {1..55})" "$(printf 'a%.0s' {1..56})" "$(printf 'a%.0s' {1..64})"; do printf '%s' "$s" | sha1sum | cut -d' ' -f1; done
  for i in $(seq 0 1999); do printf '%s lines of the tiny machine\n' $i; done | sha1sum | cut -d' ' -f1; } > $W/sha1.expected
if diff $W/sha1.expected $W/digests.out; then echo "ok sha1: sha1sum's digests"; else echo "FAIL sha1"; failures=$((failures + 1)); fi
echo "$failures failure(s)"
[ $failures = 0 ]
