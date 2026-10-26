#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The tests of TinyKernelNetwork.ml (plan_tiny_network.md):
# 1. on the host, with no machine: TinyKernelNetwork_tests/Host.ml, its laws
#    a line each (addresses, the checksum on known values, a packet
#    read, damaged, cut; an echo asked, answered, heard; IL: its
#    header, a conversation's packets with nothing lost and with one
#    lost, a port nobody listens on, nobody there; and two machines
#    over a wire that loses 0, 2, 10, 30 and 50 packets in a hundred,
#    by five seeds: every message once and in order, all of them up to
#    10, as many as arrived before one end gave up beyond), against
#    host.expected; RECORD=1 records it;
# 2. a ping's two packets and IL's conversation as a capture, read by
#    tcpdump when there is one: code that is not ours says whether
#    IP's checksums are right, and the echo's (it has no word on IL's:
#    "ip-proto-40");
# 3. on tiny-machine, in tiny-kernel (tiny-ml's build of the same
#    file): ping and get answered by tiny-machine's end of the wire
#    (-net tests/www), a packet lost (-net-lose), the packets as
#    -net-trace says them; that is tiny/TinyKernel's make check, not
#    run here;
# 4. tiny-kernel's network and this machine's programs (below).
# usage: TinyKernelNetwork_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOST=${HOST:-$ROOT/_build/default/tiny/tests/TinyKernelNetwork_tests/Host.exe}
E=$ROOT/tiny/tests/TinyKernelNetwork_tests/host.expected
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
    echo "ok tcpdump: a question, an answer and $(grep -c 'ip-proto-40' $W/tcpdump.out) packets of IL's, no checksum called bad"
  else fail "tcpdump: $(cat $W/tcpdump.out)"; fi
else echo "-- tcpdump: not here, not checked"; fi

# 4. On Linux (TinyKernelNetwork_tests/linux.py says what): tiny-kernel's get
#    reaching a web server of this machine through tiny-machine
#    -net-out, and its httpd read through -net-forward; when
#    tiny-kernel's image is built (make -C tiny/TinyKernel) and Python
#    is there. No Internet, no root.
# (IMAGE: another, as make test's own: the sessions rebuild this one)
IMAGE=${IMAGE:-$ROOT/tiny/TinyKernel/_make/boot.img}
MACHINE=${MACHINE:-$ROOT/_build/default/tiny/TinyMachine.exe}
if [ -f $IMAGE ] && [ -x $MACHINE ] && command -v python3 > /dev/null; then
  if timeout 200 python3 $ROOT/tiny/tests/TinyKernelNetwork_tests/linux.py $MACHINE $IMAGE $ROOT/tiny/tests/www > $W/linux.out 2>&1; then
    echo "ok linux: $(grep -c '^ok' $W/linux.out) checks (out, in, the capture)"
  else fail "linux"; grep -v '^ok' $W/linux.out | head -10; fi
else echo "-- linux: no image of tiny-kernel's (make -C tiny/TinyKernel), or no python3: not run"; fi

echo "TinyKernelNetwork_test: $failures failures"
exit $((failures > 0))
