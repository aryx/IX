#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Where a TLS 1.3 handshake's instructions go, by source file: mini-curl
# (dune's, ocamlopt's code) fetching a page from openssl s_server on
# this machine, a self-signed certificate of P-256 then of RSA 2048,
# AES-128-GCM, counted by valgrind (callgrind), each function's own
# instructions summed by its file. mini-5i has no sockets, so mini-ml's
# handshake is not measured whole: its share of each file is numbers.sh's
# ratio times this (plan_mini_toolchain_optimization.md, 2026-11-02).
# usage: lib_crypto/tests/handshake.sh   (dune build first; openssl, valgrind)
cd "$(dirname "$0")/../.."
CURL=$PWD/_build/default/networking/Curl.exe
command -v openssl > /dev/null && command -v valgrind > /dev/null || { echo "skipped: no openssl or valgrind"; exit 0; }
W=$(mktemp -d); trap 'kill $pid 2> /dev/null; rm -rf $W' EXIT
port=$((24000 + $$ % 5000))
for k in ec rsa; do
  newkey="-newkey ec -pkeyopt ec_paramgen_curve:P-256"; [ $k = rsa ] && newkey="-newkey rsa:2048"
  openssl req -x509 $newkey -nodes -keyout $W/$k.key -out $W/$k.pem -days 2 -subj /CN=localhost -addext subjectAltName=DNS:localhost 2> /dev/null
  port=$((port + 1))
  openssl s_server -quiet -www -tls1_3 -ciphersuites TLS_AES_128_GCM_SHA256 -accept $port -cert $W/$k.pem -key $W/$k.key > /dev/null 2>&1 &
  pid=$!
  for i in $(seq 50); do (exec 3<> /dev/tcp/127.0.0.1/$port) 2> /dev/null && break; sleep 0.1; done
  (cd $W && timeout 120 valgrind --tool=callgrind --callgrind-out-file=$W/cg.$k $CURL --cacert $k.pem https://localhost:$port/ > /dev/null 2>&1)
  kill $pid; wait $pid 2> /dev/null
  echo "== a certificate of $k"
  callgrind_annotate --threshold=100 $W/cg.$k 2> /dev/null | grep -E '^ *[0-9,]+ \(' | grep -v PROGRAM \
    | sed -E 's/^ *([0-9,]+) \([^)]*\) +([^ :]*).*/\1 \2/' \
    | awk '{ n = $1; gsub(",", "", n); f = $2; sub(".*/", "", f); t[f] += n; s += n }
           END { printf "%12d  all\n", s; for (f in t) printf "%12d %5.1f%% %s\n", t[f], 100 * t[f] / s, f }' \
    | sort -rn | head -9
done
