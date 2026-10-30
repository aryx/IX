#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-pim's window (docs/plans/plan_mail.md, stage 5) against
# mini-maild: four messages sent to erin (a question, its answer in
# Windows-1252, a newsletter, an invitation), then the window run without one
# (lib_playground's ppm platform), a session a line of frames.expected:
# its name, its arguments, the SHA-256 of the frame it ends with (as
# games/tests/frames.sh). Each session has an empty store of its own,
# so each gets the mail with g, the password typed; they run one after
# the other, in the list's order, the archives last (they change the
# server's Inbox; a reply sent goes to carol, not erin). RECORD=1 writes the sums again; FRAMES=dir keeps each
# session's last frame there as a PNG (python3 and PIL), to look at.
#
# usage: frames.sh [dir]
#   dir: where mini-pim and mini-maild are (default: dune's,
#        _build/default/apps/pim)

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
# (the same day and Date: on any machine: Zone)
export TZ=UTC
B=${1:-$ROOT/_build/default/apps/pim}
if [ $# -ge 1 ]; then PIM=$B/mini-pim; MAILD=$B/mini-maild
else PIM=$B/Pim.exe; MAILD=$B/Maild.exe; fi
E=$ROOT/apps/pim/tests/frames.expected
W=$(mktemp -d); trap 'kill $pid 2> /dev/null; rm -rf $W' EXIT
mkdir $W/spool

$MAILD -p 0 -i 0 $W/spool > $W/log 2>&1 &
pid=$!
n=0
until grep -q 'serving' $W/log || [ $n -ge 50 ]; do sleep 0.1; n=$((n + 1)); done
S=$(grep -o 'SMTP on [0-9.:]*' $W/log | cut -d' ' -f3)
I=$(grep -o 'IMAP on [0-9.:]*' $W/log | cut -d' ' -f3)
[ -n "$S" ] && [ -n "$I" ] ||
  { echo "FAIL mini-maild did not start: $(cat $W/log)"; exit 1; }

printf 'From: Alice <alice@ix>\nTo: erin@ix\nSubject: the plan
Date: Thu, 29 Oct 2026 10:00:00 +0100\nMessage-ID: <1@ix>

See you at noon.\nBring the map.\n' > $W/a
printf 'From: Carol <carol@ix>\nTo: erin@ix\nSubject: Re: the plan
Date: Thu, 29 Oct 2026 11:00:00 +0100\nMessage-ID: <2@ix>
References: <1@ix>\nContent-Type: text/plain; charset=windows-1252
Content-Transfer-Encoding: quoted-printable

=93Yes=94, =E0 midi.\n' > $W/b
printf 'From: news@ix\nTo: erin@ix\nSubject: weekly
Date: Wed, 28 Oct 2026 09:00:00 +0000\n\nnews\n' > $W/c
printf 'From: Dan <dan@ix>\nTo: erin@ix\nSubject: Invitation: tea
Date: Tue, 27 Oct 2026 08:00:00 +0000\nMIME-Version: 1.0
Content-Type: multipart/mixed; boundary=b

--b\nContent-Type: text/plain\n\nTea on Friday at 3pm? It is 4,50 € each.\nEve Martin <eve@ix> comes too.
--b\nContent-Type: text/calendar; method=REQUEST; name=invite.ics

BEGIN:VCALENDAR\nMETHOD:REQUEST\nBEGIN:VEVENT\nUID:tea@ix
DTSTART:20261030T150000\nDTEND:20261030T160000\nSUMMARY:tea with Dan
LOCATION:the garden\nEND:VEVENT\nEND:VCALENDAR
--b--\n' > $W/d
for m in a b c d; do
  timeout 20 $PIM -s $S -plain send $W/$m > /dev/null ||
    { echo "FAIL sending $m"; exit 1; }
done

fail=0
: > $W/new
while IFS='|' read -r name args sum; do
  [ -z "$name" ] && continue
  mkdir $W/$name
  # (a session's store made first by tests/seed/<name>.sh, if there is
  # one: mini-pim's commands, $PIM)
  [ -f $ROOT/apps/pim/tests/seed/$name.sh ] &&
    PIM_STORE=$W/$name/store PIM=$PIM sh $ROOT/apps/pim/tests/seed/$name.sh
  eval "set -- $args"; frames=$1; shift
  PIM_STORE=$W/$name/store timeout 30 $PIM -dump-frame $frames $W/$name/f.ppm \
    -fixed-time 1000 "$@" user=erin server=$I smtp=$S plain > /dev/null 2> $W/$name/err ||
    { echo "FAIL $name: $(head -1 $W/$name/err)"; fail=1; continue; }
  got=$(sha256sum < $W/$name/f.ppm | cut -d' ' -f1)
  echo "$name|$args|$got" >> $W/new
  [ -n "${FRAMES:-}" ] && mkdir -p $FRAMES &&
    python3 -c "import sys; from PIL import Image
Image.open(sys.argv[1]).save(sys.argv[2])" $W/$name/f.ppm $FRAMES/$name.png
  if [ -n "${RECORD:-}" ]; then echo "recorded $name"
  elif [ "$got" = "$sum" ]; then echo "ok $name"
  else echo "FAIL $name: its frame is another (FRAMES=dir to see it)"; fail=1; fi
done < $E
[ -n "${RECORD:-}" ] && cp $W/new $E
exit $fail
