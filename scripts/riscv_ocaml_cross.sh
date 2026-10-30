#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Does OCaml 4.14's riscv backend work from this machine? (plan_riscv.md,
# decision 6.) configure has no -target-arch as ocaml-light's has: a
# cross compiler is the host's bytecode ocamlc and ocamlrun building an
# ocamlopt whose Config says riscv, with GNU's cross tools. A program by
# it (the GC, exceptions, Printf, a fused float) run under qemu-riscv64.
# Nothing here is installed or used by a build.
#
# usage: scripts/riscv_ocaml_cross.sh DIR    (DIR: a new directory)

set -e
W=$1
[ -n "$W" ] && [ ! -e "$W" ] || { echo "usage: $0 NEWDIR"; exit 1; }
mkdir -p "$W"
W=$(cd "$W" && pwd)
V=$(ocamlopt -version)
P=riscv64-linux-gnu-
opam source ocaml-base-compiler.$V --dir "$W/src" > /dev/null
cd "$W/src"
./configure --prefix="$W/inst" > ../configure.log 2>&1
make -j8 world > ../world.log 2>&1
cp runtime/ocamlrun ../ocamlrun.host

sed -i -E "s/^ARCH=.*/ARCH=riscv/; s/^MODEL=.*/MODEL=riscv64/;
  s/^ASM=.*/ASM=${P}as/; s/^ASPP=.*/ASPP=${P}gcc -c/;
  s/^CC=.*/CC=${P}gcc/; s/^MKEXE=.*/MKEXE=${P}gcc -Wl,-E/" Makefile.config
# (configure's answer for arm64; 4.14 has no such context for riscv)
sed -i 's/^#define HAS_STACK_OVERFLOW_DETECTION.*//' runtime/caml/s.h
rm -f asmcomp/arch.ml asmcomp/proc.ml asmcomp/selection.ml asmcomp/CSE.ml
rm -f asmcomp/reload.ml asmcomp/scheduling.ml asmcomp/emit.ml asmcomp/emit.mlp
rm -f asmcomp/*.cm[oixa] asmcomp/*.o utils/config.ml utils/config.cm[oi]
make ocamlopt > ../ocamlopt.log 2>&1
make -C stdlib allopt > ../stdlib.log 2>&1
make -C runtime clean > /dev/null 2>&1 || true
make -C runtime libasmrun.a > ../runtime.log 2>&1
cp runtime/libasmrun.a stdlib/

mkdir "$W/t"
cd "$W/t"
cat > h.ml <<'EOF'
let rec fib n = if n < 2 then n else fib (n - 1) + fib (n - 2)
let fma a b c = a *. b +. c
let () =
  Printf.printf "hello riscv64 %d %d-bit\n" (fib 25) Sys.word_size;
  Printf.printf "%h\n" (fma (Sys.opaque_identity 0.1) 0.2 0.3);
  let l = List.init 200000 string_of_int in
  Gc.full_major ();
  Printf.printf "%d\n" (List.length (List.sort compare l));
  try raise Not_found with Not_found -> print_endline "exn ok"
EOF
../ocamlrun.host ../src/ocamlopt -nostdlib -I ../src/stdlib -S -o h h.ml
file h | cut -d, -f1-4
qemu-riscv64 -L /usr/riscv64-linux-gnu ./h
echo "fused multiply-adds in the assembly: $(grep -c 'fmadd\.d' h.s)"
