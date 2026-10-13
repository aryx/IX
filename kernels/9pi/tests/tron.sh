#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The Makefile's check-tron: TinyTronscroll in mini-9pi under an
# emulator plays with the same game on this machine, over UDP.
#   tron.sh BUILD GAME join|host -- EMULATOR...
# BUILD: where the console's output is kept; GAME: this machine's game
# (the ppm platform's: no window, a script's keys, pace= frames a
# second); join: the guest joins this machine's game (10.0.2.2, the
# emulator's user network); host: it hosts, this machine's joins
# through the port the emulator forwards (hostfwd=udp:127.0.0.1:7777-:7777).
# This machine's player presses space in its eleventh second, when the
# guest has long been there (the title until then: the two exchange
# their keys from the first tick), and a round starts; nobody steers.
# Both say their ticks (ticks=on): the guest must reach tick 900 with
# the two games in agreement, a round's map among what is compared,
# and this machine's must say the same.

#   tron.sh BUILD GAME pair -- EMULATOR...
# pair: two guests, each the other's whole network (the emulator's
# socket network: what a cable between two boards is), one that hosts
# and one that joins. Both boot with the address boot.rc gives a
# guest; the second takes another, and its adapter another Ethernet
# address than the emulator's one for all. Each finds the other by
# ARP, which the user network above answers by itself. No key is
# typed: the title's ticks, to 600, in agreement on both.

B=$1; game=$2; mode=$3; shift 4
lib=$(dirname $0)/../../lib_machine
W=$(mktemp -d); trap 'kill $pid 2> /dev/null; rm -rf $W' EXIT
if [ $mode = pair ]; then
  $lib/session.py --quiet 0.3 --prompt "% " --timeout 90 --until "tick 600 agree" --out $B/qemu-tron-pair-host.txt \
    "tronscroll 'ticks=on' 'net=host' > /dev/null &" -- "$@" -device usb-net,netdev=n0,mac=52:54:00:12:34:56 -netdev socket,id=n0,listen=127.0.0.1:7789 > /dev/null 2>&1 &
  pid=$!
  sleep 1
  $lib/session.py --quiet 0.3 --prompt "% " --timeout 90 --until "tick 600 agree" --out $B/qemu-tron-pair-join.txt \
    "echo remove 10.0.2.15 255.255.255.0 > /net/ipifc/0/ctl; echo add 10.0.2.16 255.255.255.0 > /net/ipifc/0/ctl; tronscroll 'ticks=on' 'net=join' 'host=10.0.2.15' > /dev/null &" \
    -- "$@" -device usb-net,netdev=n0,mac=52:54:00:12:34:57 -netdev socket,id=n0,connect=127.0.0.1:7789 > /dev/null 2>&1
  joined=$?
  wait $pid; hosted=$?
  if [ $joined = 0 ] && [ $hosted = 0 ] && ! grep -q desync $B/qemu-tron-pair-host.txt $B/qemu-tron-pair-join.txt; then
    echo "ok 9pi: tronscroll, two guests joined by the emulator's cable: each at tick 600, in agreement"; exit 0
  else
    echo "FAIL 9pi: tronscroll, two guests: the host's $(grep '^tick' $B/qemu-tron-pair-host.txt | tail -1), the other's $(grep '^tick' $B/qemu-tron-pair-join.txt | tail -1)"; exit 1
  fi
fi
case $mode in
# (the guest's flags as rc takes them: a word with = in it is quoted)
join) here="net=host bind=0.0.0.0 port=7777"; there="'net=join' 'host=10.0.2.2'";;
host) here="net=join host=127.0.0.1 port=7777"; there="'net=host'";;
esac
$game -dump-frame 7000 $W/f.ppm -script space:600-700 pace=60 ticks=on $here > /dev/null 2> $W/here.err &
pid=$!
$lib/session.py --quiet 0.3 --prompt "% " --timeout 90 --until "tick 900 agree" --out $B/qemu-tron-$mode.txt \
  "tronscroll 'ticks=on' $there > /dev/null &" -- "$@"
status=$?
kill $pid 2> /dev/null; wait $pid 2> /dev/null
last=$(grep '^tick' $W/here.err | tail -1)
if [ $status = 0 ] && ! grep -q desync $B/qemu-tron-$mode.txt $W/here.err && [ -n "$last" ]; then
  echo "ok 9pi: tronscroll, the guest the one that ${mode}s: its tick 900 in agreement; this machine's last: $last"
else
  echo "FAIL 9pi: tronscroll, the guest the one that ${mode}s: the guest's $(grep '^tick' $B/qemu-tron-$mode.txt | tail -1), this machine's ${last:-nothing}"; exit 1
fi
