#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The sources of the switch's OCaml (4.14), for a kernel built with it
# (lib_machine/kernel.mk's COMPILER=ocaml, the Pi4 only): ocamlopt and
# its stdlib are the switch's own, but its runtime (libasmrun.a) is
# compiled for Linux, with a stack protector; the kernel's Makefile
# compiles the runtime's C again, freestanding, from the sources opam
# fetches here, in $OCAML_SRC (default /tmp/ix-ocaml-VERSION). The
# headers are the installed ones.
#
# Usage: ocaml.sh

V=$(ocamlopt -version)
OCAML_SRC=${OCAML_SRC:-/tmp/ix-ocaml-$V}
[ -f $OCAML_SRC/runtime/startup_nat.c ] && { echo "OCaml $V's sources: $OCAML_SRC (already there)"; exit 0; }
set -e
rm -rf $OCAML_SRC
opam source ocaml-base-compiler.$V --dir $OCAML_SRC > /dev/null
echo "OCaml $V's sources: $OCAML_SRC"
