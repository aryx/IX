#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# ocaml-light cross-compiled for the Pis (plan_kernel.md): a clone of
# ~/ocaml-light (untouched) configured with -target-arch arm (the Pi1's)
# or arm64 (the Pi4's), built (make world, make opt) and installed in
# $OCL (default /tmp/ix-ocaml-light-ARCH): its ocamlopt emits that
# architecture's code, its stdlib is compiled for it, and the runtime's
# sources are in $OCL/src for the kernel's Makefile to compile
# freestanding. About 5 minutes; kept until /tmp is cleared.
#
# The clone gets ocaml-light-patches/*.patch (fixes found by the kernels,
# reported in docs/bugs/ocaml_light.md, until ~/ocaml-light has
# them); a build without the current patches is rebuilt.
#
# Usage: ocaml-light.sh [arm|arm64]

ARCH=${1:-arm}
OCL=${OCL:-/tmp/ix-ocaml-light-$ARCH}
PATCHES=$(cd "$(dirname "$0")" && pwd)/ocaml-light-patches
STAMP="$(cat $PATCHES/*.patch 2>/dev/null | md5sum | cut -c1-12)"
[ -x $OCL/bin/ocamlopt ] && [ "$(cat $OCL/patches 2>/dev/null)" = "$STAMP" ] && { echo "ocaml-light for $ARCH: $OCL (already built)"; exit 0; }
set -e
# claude: the Pi1's cross tools, if ix's configure wrote them in
# Makefile.config (no GNU cross compiler, macOS: clang), given to
# ocaml-light's configure (configure-cross-tools.patch's options)
CONFIG=$(dirname "$PATCHES")/../Makefile.config
conf() { sed -n "s/^$1 = //p" "$CONFIG" 2>/dev/null; }
TOOLS=()
if [ $ARCH = arm ] && [ -n "$(conf PI1_CC)" ]; then
  TOOLS=(-nativecc "$(conf PI1_CC)" -as "$(conf PI1_AS)" -aspp "$(conf PI1_CC)")
elif [ $ARCH = arm ] && ! command -v arm-linux-gnueabihf-gcc > /dev/null; then
  echo "ocaml-light.sh: no arm-linux-gnueabihf-gcc, and no PI1_CC in Makefile.config: run ix's ./configure" >&2; exit 1
fi
rm -rf $OCL
git clone -q ${OCAML_LIGHT:-$HOME/ocaml-light} $OCL/src
cd $OCL/src
for p in $PATCHES/*.patch; do git apply $p; done
./configure -target-arch $ARCH "${TOOLS[@]}" -bindir $OCL/bin -libdir $OCL/lib -mandir $OCL/man > $OCL/configure.log
make world > $OCL/world.log 2>&1
make opt > $OCL/opt.log 2>&1
make install installopt > $OCL/install.log 2>&1
echo "$STAMP" > $OCL/patches
echo "ocaml-light for $ARCH: $OCL"
