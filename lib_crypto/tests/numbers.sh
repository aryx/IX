#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# lib_crypto as a benchmark of mini-ml's code against ocamlopt's
# (docs/plans/plan_mini_toolchain_optimization.md, its third): the
# instructions each takes for a kind of work of Speed.ml, the program's
# start taken off. Loops over arrays of ints, and nothing else: no
# closure applied, little allocated, so what it measures is the code of
# a loop's body (values kept in registers or not, an index checked or
# not), where mini-xv6's scheduler measures calls and allocation.
#   aes, ghash, chacha20, poly1305   a kilobyte: bytes and small ints
#   sha256                           a kilobyte: int32, boxed by mini-ml
#   x25519, ecdsa, rsa               one operation: Bignum's product,
#                                    two multiplications a limb
# mini-ml's are the guest's, under mini-5i, the same at every run: for
# arm64, and for arm, whose ints have 31 bits and which runs other
# code for it (limbs of 14 and 13 bits, words in halves: so its column
# is not to be held against ocamlopt's). ocamlopt's are this machine's
# (OCaml 4.14), counted by valgrind.
# usage: lib_crypto/tests/numbers.sh   (dune build, and mini-mk O=7 and O=5 in lib_crypto/tests, first)
cd "$(dirname "$0")/../.."
NATIVE=_build/default/lib_crypto/tests/Speed.exe
FIVE=_build/default/machine/Main.exe
mini() { $FIVE -s _mk/$1/lib_crypto/tests/speed $2 1 2>&1 > /dev/null | awk '/^mini-5i:/ { print $2 }'; }
native() { command -v valgrind > /dev/null && valgrind --tool=callgrind --callgrind-out-file=/dev/null $NATIVE $1 1 2>&1 > /dev/null | awk '/Collected/ { print $4 }'; }
s7=$(mini 7 nothing); s5=$(mini 5 nothing); sn=$(native nothing)
printf "%-10s %14s %14s %7s %14s\n" "" "mini-ml arm64" ocamlopt ratio "mini-ml arm"
printf "%-10s %14d %14d %7.1f %14d\n" "the start" $s7 ${sn:-0} $(echo "$s7 / ${sn:-1}" | bc -l) $s5
for w in aes ghash chacha20 poly1305 sha256 x25519 ecdsa rsa; do
  a=$(( $(mini 7 $w) - s7 )); b=$(( $(mini 5 $w) - s5 )); n=$(( $(native $w) - ${sn:-0} ))
  printf "%-10s %14d %14d %7.1f %14d\n" $w $a $n $(echo "$a / $n" | bc -l) $b
done
