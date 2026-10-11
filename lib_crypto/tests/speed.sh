#!/bin/sh
# Each kind of work of Speed.ml, timed: speed.sh <command that runs speed> [times]
#   lib_crypto/tests/speed.sh _build/default/lib_crypto/tests/Speed.exe 100
#   lib_crypto/tests/speed.sh "mini-5i _mk/5/lib_crypto/tests/speed" 1
# (a kilobyte each for sha256, chacha20, poly1305, gcm; one operation
# for the others), the start's time ("nothing") to be taken off.
run=$1; n=${2:-1}
for w in nothing sha256 chacha20 poly1305 poly1305-simple gcm aes ghash x25519 p256 ecdsa rsa; do
  s=$(date +%s.%N); $run $w $n; e=$(date +%s.%N)
  printf "%-16s %8.2f s for %d\n" $w $(echo "$e - $s" | bc) $n
done
