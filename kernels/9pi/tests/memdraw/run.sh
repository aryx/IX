#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# lib_memdraw's faster paths against its general loop, on the host:
# its sources compiled by OCaml with a stand-in for the kernel's
# Machine (the images' memory the heap's, nothing flushed) and its
# two calls of the machine (Memdraw's rows and host_general, the
# general loop's) made OCaml's, then Grey.ml's draws compared.
#   usage: tests/memdraw/run.sh      (from kernels/9pi; ocamlfind)
set -e
cd "$(dirname "$0")/../.."
d=$(mktemp -d)
trap 'rm -rf $d' EXIT
cp lib_graphics/Memdata.ml lib_graphics/Memdata.mli lib_graphics/lib_memdraw/Memchan.ml* lib_graphics/lib_memdraw/Memimage.ml* \
  lib_graphics/lib_memdraw/Memgeneral.ml* lib_graphics/lib_memdraw/Memdraw.ml* tests/memdraw/Grey.ml $d/
sed -i 's/^external rows : .*$/let rows (_ : Bytes.t) (_ : int) (_ : int) (_ : int) (_ : string) : unit = failwith "rows"/;
  s/^external host_general : .*$/let host_general (_ : Bytes.t) (_ : Bytes.t) (_ : Bytes.t) (_ : Bytes.t) : int = -1/' $d/Memdraw.ml
cat > $d/Machine.ml <<'EOF'
module Imag = struct
  let alloc n = Bytes.make n '\000'
  let free (_ : Bytes.t) = ()
  let copy (_ : Bytes.t) (_ : Bytes.t) (_ : int array) = failwith "copy"
  let rows (_ : Bytes.t) (_ : int) (_ : int) (_ : int) (_ : int) = failwith "rows"
  let flush (_ : Bytes.t) (_ : int array) = ()
  let quiet () = ()
end
module Phys = struct let write (_ : int) (_ : string) = () end
EOF
cd $d
ocamlfind ocamlopt -w -a -package unix Memdata.mli Memdata.ml Memchan.mli Memchan.ml Machine.ml Memimage.mli Memimage.ml \
  Memgeneral.mli Memgeneral.ml Memdraw.mli Memdraw.ml Grey.ml -o grey
./grey
