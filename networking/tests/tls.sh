#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# ix's TLS 1.3 against openssl's, on this machine: a self-signed
# certificate for localhost made here (a P-256 key, then an RSA one),
# `openssl s_server -www` with one cipher at a time, and mini-curl
# --cacert that certificate asks it for a page: over ChaCha20-Poly1305
# and over AES-128-GCM, the handshake signed by ECDSA and by RSA (PSS);
# refused when the certificate is not trusted (the system's roots), and
# when the host asked is another name (127.0.0.1). As the author's
# playground's Unit_tls_client. Skipped without openssl.
#
# usage: tls.sh [dir]     (dir: where mini-curl is; default: dune's)

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
if [ $# -ge 1 ]; then CURL=$1/mini-curl; else CURL=$ROOT/_build/default/networking/Curl.exe; fi
command -v openssl > /dev/null || { echo "skipped: no openssl"; exit 0; }
W=$(mktemp -d); trap 'kill $pid 2> /dev/null; rm -rf $W' EXIT
fail=0
port=$((21000 + $$ % 9000))
serve() { # the key's kind, the cipher suite
  local newkey="-newkey ec -pkeyopt ec_paramgen_curve:P-256"; [ $1 = rsa ] && newkey="-newkey rsa:2048"
  [ -f $W/$1.pem ] || openssl req -x509 $newkey -nodes -keyout $W/$1.key -out $W/$1.pem -days 2 -subj /CN=localhost -addext subjectAltName=DNS:localhost 2> /dev/null
  port=$((port + 1))
  openssl s_server -quiet -www -tls1_3 -ciphersuites $2 -accept $port -cert $W/$1.pem -key $W/$1.key > /dev/null 2>&1 &
  pid=$!
  # until it listens (5 s at most): a fixed half second was too short for
  # the first server on a loaded machine (the CI's: "Connection refused")
  local i; for i in $(seq 50); do (exec 3<> /dev/tcp/127.0.0.1/$port) 2> /dev/null && break; sleep 0.1; done
}
check() { # a name, what the output must have, mini-curl's arguments
  local name=$1 want=$2; shift 2
  timeout 30 $CURL "$@" > $W/got 2>&1; grep -q "$want" $W/got || { echo "FAIL $name: no \"$want\" in: $(head -c 300 $W/got)"; fail=1; }
}
serve ec TLS_CHACHA20_POLY1305_SHA256
check "ChaCha20-Poly1305, ECDSA" 'TLS_CHACHA20_POLY1305_SHA256' --cacert $W/ec.pem https://localhost:$port/
check "a root not trusted" 'issued by no one we trust' https://localhost:$port/
check "another name" 'the certificate is for localhost, not 127.0.0.1' --cacert $W/ec.pem https://127.0.0.1:$port/
kill $pid; wait $pid 2> /dev/null
serve rsa TLS_AES_128_GCM_SHA256
check "AES-128-GCM, RSA" 'TLS_AES_128_GCM_SHA256' --cacert $W/rsa.pem https://localhost:$port/
kill $pid; wait $pid 2> /dev/null
serve ec TLS_AES_128_GCM_SHA256
check "AES-128-GCM, ECDSA" 'TLS_AES_128_GCM_SHA256' --cacert $W/ec.pem https://localhost:$port/
[ $fail = 0 ] && echo "ok: TLS 1.3 with openssl's server, two ciphers, two kinds of key"
exit $fail
