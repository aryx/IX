#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-pim sends to mini-maild (docs/plans/plan_mail.md, stage 2): a
# message to two users of mini-maild's domain, one in Bcc:, and one of
# elsewhere, logged in; each user's file compared with the message (the
# Received: line apart, the Bcc: gone, a line starting with a dot whole);
# the relay refused; then a server not there. No network but this
# machine's, and never Gmail.
#
# usage: sent.sh [dir]
#   dir: where mini-pim and mini-maild are (default: dune's,
#        _build/default/apps/pim)

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
B=${1:-$ROOT/_build/default/apps/pim}
if [ $# -ge 1 ]; then PIM=$B/mini-pim; MAILD=$B/mini-maild
else PIM=$B/Pim.exe; MAILD=$B/Maild.exe; fi
W=$(mktemp -d); trap 'kill $pid 2> /dev/null; rm -rf $W' EXIT
mkdir $W/spool

$MAILD -p 0 $W/spool > $W/log 2>&1 &
pid=$!
n=0
until grep -q 'serving' $W/log || [ $n -ge 50 ]; do sleep 0.1; n=$((n + 1)); done
S=$(grep -o '127.0.0.1:[0-9]*' $W/log)
[ -n "$S" ] || { echo "FAIL mini-maild did not start: $(cat $W/log)"; exit 1; }

fail=0
from='From: Alice <alice@ix>\nTo: Bob <bob@ix>, carol@elsewhere\n'
body='Subject: lunch\n\nNoon?\n.a line with a dot\n'
printf "${from}Bcc: dave@ix\n$body" > $W/m
printf "$from$body" > $W/want
echo secret | timeout 20 $PIM send -s $S -plain -u alice@ix $W/m > $W/out 2>&1
grep -q '^sent to 2, refused: 550 not a relay' $W/out ||
  { echo "FAIL the outcome: $(cat $W/out)"; fail=1; }
for u in bob dave; do
  f=$W/spool/$u/1
  [ -f $f ] || { echo "FAIL nothing for $u"; fail=1; continue; }
  head -1 $f | grep -q '^Received: from mini-pim by ix with SMTP;$' ||
    { echo "FAIL $u's Received: $(head -1 $f)"; fail=1; }
  tail -n +3 $f | cmp -s - $W/want ||
    { echo "FAIL $u's message:"; tail -n +3 $f; fail=1; }
done
[ -e $W/spool/carol ] && { echo "FAIL carol of elsewhere has mail"; fail=1; }
grep -q '^bob 1 lunch$' $W/log ||
  { echo "FAIL mini-maild's log: $(cat $W/log)"; fail=1; }

kill $pid; wait $pid 2> /dev/null
timeout 20 $PIM send -s $S -plain $W/m > $W/out 2>&1 &&
  { echo "FAIL sent to a server not there"; fail=1; }
grep -q "$S" $W/out || { echo "FAIL no reason said: $(cat $W/out)"; fail=1; }

[ $fail = 0 ] &&
  echo "mini-pim, mini-maild: a message sent, delivered, the relay refused"
exit $fail
