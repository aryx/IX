#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# lib_memdraw's faster paths against its general loop, on the host:
# its sources compiled by OCaml with a stand-in for the kernel's
# Machine (the images' memory the heap's, nothing flushed) and its
# two calls of the machine (Memdraw's rows and host_general, the
# general loop's) made OCaml's, then Grey.ml's draws compared. And
# Memdraw.scale against its reference (Scale.ml), the machine's loop
# runtime.c's own imag_scale, compiled here without the kernel.
#   usage: tests/memdraw/run.sh      (from kernels/9pi; ocamlfind)
set -e
cd "$(dirname "$0")/../.."
d=$(mktemp -d)
trap 'rm -rf $d' EXIT
cp lib_graphics/Memdata.ml lib_graphics/Memdata.mli lib_graphics/lib_memdraw/Memchan.ml* lib_graphics/lib_memdraw/Memimage.ml* \
  lib_graphics/lib_memdraw/Memgeneral.ml* lib_graphics/lib_memdraw/Memdraw.ml* tests/memdraw/Grey.ml tests/memdraw/Scale.ml $d/
sed -i 's/^external rows : .*$/let rows (_ : Bytes.t) (_ : int) (_ : int) (_ : int) (_ : string) : unit = failwith "rows"/;
  s/^external host_general : .*$/let host_general (_ : Bytes.t) (_ : Bytes.t) (_ : Bytes.t) (_ : Bytes.t) : int = -1/' $d/Memdraw.ml
cat > $d/Machine.ml <<'EOM'
module Imag = struct
  let alloc n = Bytes.make n '\000'
  let free (_ : Bytes.t) = ()
  let copy (_ : Bytes.t) (_ : Bytes.t) (_ : int array) = failwith "copy"
  let rows (_ : Bytes.t) (_ : int) (_ : int) (_ : int) (_ : int) = failwith "rows"
  external scale : Bytes.t -> Bytes.t -> int array -> unit = "imag_scale"
  let flush (_ : Bytes.t) (_ : int array) = ()
  let quiet () = ()
end
module Phys = struct let write (_ : int) (_ : string) = () end
EOM
# (imag_scale with what it asks of the kernel's arena: nothing is in it)
{ printf '#include <string.h>\n#include <caml/mlvalues.h>\n'
  printf 'static int imag_unlock = 0;\n#define IMAG_WORTH 16384\n'
  printf 'static int imag_in(value v) { (void)v; return 0; }\n'
  printf 'static int imag_begin(value d, long lo, long hi) { (void)d; (void)lo; (void)hi; return 0; }\n'
  printf 'static void imag_end(void) {}\n'
  sed -n '/^value imag_scale(/,/^}/p' ../lib_machine/runtime.c; } > $d/scale.c
cd $d
common="Memdata.mli Memdata.ml Memchan.mli Memchan.ml Machine.ml Memimage.mli Memimage.ml Memgeneral.mli Memgeneral.ml Memdraw.mli Memdraw.ml"
ocamlfind ocamlopt -w -a -package unix scale.c $common Grey.ml -o grey
ocamlfind ocamlopt -w -a -package unix scale.c $common Scale.ml -o scale
./grey
./scale
