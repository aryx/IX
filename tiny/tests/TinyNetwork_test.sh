#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The tests of TinyNetwork.ml (plan_tiny_network.md):
# 1. on the host, with no machine: TinyNetwork_tests/Host.ml, its laws
#    a line each (addresses, the checksum on known values, a packet
#    read, damaged, cut; an echo asked, answered, heard), against
#    host.expected; RECORD=1 records it;
# 2. a ping's two packets as a capture, read by tcpdump when there is
#    one: code that is not ours says whether the two checksums of each
#    are right;
# 3. on tiny-machine, in tiny-kernel (tiny-ml's build of the same
#    file): ping answered by tiny-machine's end of the wire (-net), its
#    packets as -net-trace says them; that is tiny/TinyKernel's make
#    check, not run here.
# usage: TinyNetwork_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOST=${HOST:-$ROOT/_build/default/tiny/tests/TinyNetwork_tests/Host.exe}
E=$ROOT/tiny/tests/TinyNetwork_tests/host.expected
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

$HOST $W/ping.pcap > $W/host.out 2>&1 || fail "host: the run"
[ -n "${RECORD:-}" ] && cp $W/host.out $E
if grep -q '^FAIL' $W/host.out; then fail "host: $(grep -c '^FAIL' $W/host.out) laws"; grep '^FAIL' $W/host.out; fi
if cmp -s $W/host.out $E; then echo "ok host: $(grep -c '^ok' $W/host.out) laws, its lines"; else fail "host: its lines"; diff $E $W/host.out | head -10; fi

if command -v tcpdump > /dev/null; then
  tcpdump -vnr $W/ping.pcap > $W/tcpdump.out 2>&1
  if [ "$(grep -c 'ICMP echo' $W/tcpdump.out)" = 2 ] && ! grep -qi 'bad\|wrong\|truncated' $W/tcpdump.out; then
    echo "ok tcpdump: a question and an answer, no checksum called bad"
  else fail "tcpdump: $(cat $W/tcpdump.out)"; fi
else echo "-- tcpdump: not here, not checked"; fi

echo "TinyNetwork_test: $failures failures"
exit $((failures > 0))
