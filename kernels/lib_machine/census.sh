#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/plan_kernel_mini_ml.md: what the kernels are
# made of besides their OCaml, and what that code asks of ocaml-light's
# runtime, of gcc and of GNU's assembler: what a build by ix's tools
# (mini-ml, mini-cc, mini-asm, mini-ld) must give or replace.
# usage: kernels/lib_machine/census.sh

cd "$(dirname "$0")/.."
C="lib_machine/libc.c lib_machine/runtime.c lib_machine/usb.c lib_machine/machine.c lib_machine/pi4/machine.c lib_machine/pi1/machine.c"
echo "== the OCaml (lines, .ml and .mli)"
for d in lib_machine xv6 9pi; do echo "$(find $d -name '*.ml' -o -name '*.mli' | grep -v /build/ | xargs cat | wc -l) $d"; done
echo "== the C and the assembly (lines)"
wc -l $C lib_machine/pi4/start.s lib_machine/pi1/start.s 9pi/lib_graphics/c/*.c | sed 's/^/  /'
echo "== externals (C functions the OCaml names)"
echo "  lib_machine and xv6: $(grep -h '^external' lib_machine/*.ml lib_machine/pi4/Arch.ml xv6/*.ml | wc -l)   9pi: $(grep -rh '^external' 9pi --include=*.ml | wc -l)"
echo "== ocaml-light's runtime, as the C uses it"
cat $C | grep -o '\b\(Long_val\|Val_long\|Val_unit\|Int_val\|Val_int\|Val_bool\|Bool_val\|String_val\|string_length\|Field\|Store_field\|modify\|alloc_string\|copy_string\|alloc\|alloc_tuple\|callback2\?\|caml_named_value\|caml_main\|CAMLparam[0-9]\|CAMLlocal[0-9]\|CAMLreturn0\?\|local_roots\|scan_roots_hook\|do_local_roots\|caml_bottom_of_stack\|caml_last_return_address\|caml_gc_regs\|caml_exception_pointer\)\b' \
  | sort | uniq -c | sort -rn | awk '{printf "  %s %s", $1, $2} END {print ""}' | fold -s -w 100
echo "== gcc's own, in the C"
for p in '__asm__' '__attribute__' 'unsigned long long' 'va_list' '#include <'; do echo "  $(cat $C | grep -c -- "$p") $p"; done
echo "== the Pi4's start.s (GNU's assembler): its instructions and directives"
grep -o '^\s*\.\?[a-z][a-z0-9.]*' lib_machine/pi4/start.s | sed 's/^\s*//' | grep -v ':' | sort | uniq -c | sort -rn | awk '$1 > 1 || $2 ~ /^(eret|wfi|wfe|br|ret|\.)/ {printf "  %s %s", $1, $2} END {print ""}' | fold -s -w 100
echo "== the system instructions mini-ld knows on arm64 (goken's 7a has ERET, MRS, MSR, WFI...)"
echo "  $(grep -o '"\(SVC\|MSR\|MRS\|ERET\|WFI\|WFE\|ISB\|DSB\|TLBI\)[A-Z]*"' ../linker/Arm64.ml | sort -u | tr '\n' ' ')"
echo "== the disk images the kernels embed (start.s's .incbin)"
ls -l ${XV6:-$HOME/xv6}/forks/arm64-pi4/fs.img ${XV6:-$HOME/xv6}/forks/arm-pi1/user/fs.img 2>/dev/null | awk '{print "  " $5, $9}'
