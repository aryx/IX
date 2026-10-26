#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# ocaml-light cross-compiled for the Pis (plan_kernel.md): a clone of
# ~/ocaml-light (what is committed) configured with -target-arch arm
# (the Pi1's) or arm64 (the Pi4's), built (make world, make opt) and installed in
# $OCL (default /tmp/ix-ocaml-light-ARCH): its ocamlopt emits that
# architecture's code, its stdlib is compiled for it, and the runtime's
# sources are in $OCL/src for the kernel's Makefile to compile
# freestanding. About 5 minutes; kept until /tmp is cleared.
#
# The fixes the kernels found (docs/plans/bugs/ocaml_light.md) are
# committed in ~/ocaml-light; a build of another commit is rebuilt.
#
# Usage: ocaml-light.sh [arm|arm64]

ARCH=${1:-arm}
OCL=${OCL:-/tmp/ix-ocaml-light-$ARCH}
SRC=${OCAML_LIGHT:-$HOME/ocaml-light}
STAMP=$(git -C $SRC rev-parse HEAD)
[ -x $OCL/bin/ocamlopt ] && [ "$(cat $OCL/commit 2>/dev/null)" = "$STAMP" ] && { echo "ocaml-light for $ARCH: $OCL (already built)"; exit 0; }
set -e
# claude: the Pi1's cross tools, if ix's configure wrote them in
# Makefile.config (no GNU cross compiler, macOS: clang), given to
# ocaml-light's configure (its -nativecc, -as and -aspp)
CONFIG=$(cd "$(dirname "$0")" && pwd)/../Makefile.config
conf() { sed -n "s/^$1 = //p" "$CONFIG" 2>/dev/null; }
TOOLS=()
if [ $ARCH = arm ] && [ -n "$(conf PI1_CC)" ]; then
  TOOLS=(-nativecc "$(conf PI1_CC)" -as "$(conf PI1_AS)" -aspp "$(conf PI1_CC)")
elif [ $ARCH = arm ] && ! command -v arm-linux-gnueabihf-gcc > /dev/null; then
  echo "ocaml-light.sh: no arm-linux-gnueabihf-gcc, and no PI1_CC in Makefile.config: run ix's ./configure" >&2; exit 1
fi
rm -rf $OCL
git clone -q $SRC $OCL/src
cd $OCL/src
./configure -target-arch $ARCH "${TOOLS[@]}" -bindir $OCL/bin -libdir $OCL/lib -mandir $OCL/man > $OCL/configure.log
make world > $OCL/world.log 2>&1
make opt > $OCL/opt.log 2>&1
make install installopt > $OCL/install.log 2>&1
echo "$STAMP" > $OCL/commit
echo "ocaml-light for $ARCH: $OCL"
