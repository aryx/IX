#!/bin/bash
# Claude Code
#
# Copyright (C) 2026 Yoann Padioleau
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public License
# (LGPL) as published by the Free Software Foundation; either version
# 2 of the License, or (at your option) any later version.
#
# ix's own files of the C library (../ix/: fmt.c, vlrt.c) against the
# host's: compiled by gcc beside glibc (host/u.h renames their
# functions), then
# - fmt_check: snprint's floats in 29 formats and strtod on what glibc
#   prints, on random doubles (any bits, decimals, usual sizes,
#   denormals) and chosen ones; 5 times count doubles
# - vlrt_check: each function for arm's vlongs against gcc's 64 bits
# (On arm and arm64 themselves, by mini-cc: languages/ml/tests/modern/
# float_formats.ml, and every program of ix for arm.)
# usage: check.sh [count]      (20000: a minute)
set -u
D=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d); trap 'rm -rf $W' EXIT
gcc -O2 -w -I$D/host -o $W/fmt_check $D/fmt_check.c || exit 1
gcc -O2 -w -fplan9-extensions -o $W/vlrt_check $D/vlrt_check.c || exit 1
status=0
$W/vlrt_check || status=1
$W/fmt_check ${1:-20000} || status=1
exit $status
