#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Hid's mice read on the host (Hidtest.ml): a line each, ok or FAIL.
cd "$(dirname "$0")/../../../../.." && dune build ./kernels/9pi/buses/lib_usb/tests/Hidtest.exe && ./_build/default/kernels/9pi/buses/lib_usb/tests/Hidtest.exe
