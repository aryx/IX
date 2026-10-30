#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-pim against mini-maild (docs/plans/plan_mail.md, stages 2 and 3).
# Sent by SMTP: a message to two users of mini-maild's domain, one in
# Bcc:, and one of elsewhere, logged in; each user's file compared with
# the message (the Received: line apart, the Bcc: gone, a line starting
# with a dot whole); the relay refused. Read by IMAP: a question, its
# answer (Windows-1252, quoted-printable) and a newsletter listed as two
# conversations, unread; the answer read, its text UTF-8; replied to
# (threaded, quoted, the text UTF-8 in quoted-printable) and forwarded
# with a file attached (plan_mail.md, stage 7); snoozed and back; the
# newsletter
# archived, gone from INBOX, still in All Mail (and in a French Gmail's,
# [Gmail]/Tous les messages, found by its \All); a search; the password
# in the store's file, and refused when others may read it. Then, the
# server gone, the same read from mini-pim's store (-offline), and a
# server not there; the store's items searched, added, set, shown with
# their links both ways; a sender made a contact, her page. No network but this machine's, and never Gmail.
#
# usage: session.sh [dir]
#   dir: where mini-pim and mini-maild are (default: dune's,
#        _build/default/apps/pim)

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
B=${1:-$ROOT/_build/default/apps/pim}
if [ $# -ge 1 ]; then PIM=$B/mini-pim; MAILD=$B/mini-maild
else PIM=$B/Pim.exe; MAILD=$B/Maild.exe; fi
W=$(mktemp -d); trap 'kill $pid $fr 2> /dev/null; rm -rf $W' EXIT
mkdir $W/spool
# (mini-pim's store the test's, never ~/.ix-pim)
export PIM_STORE=$W/store

$MAILD -p 0 -i 0 $W/spool > $W/log 2>&1 &
pid=$!
n=0
until grep -q 'serving' $W/log || [ $n -ge 50 ]; do sleep 0.1; n=$((n + 1)); done
S=$(grep -o 'SMTP on [0-9.:]*' $W/log | cut -d' ' -f3)
I=$(grep -o 'IMAP on [0-9.:]*' $W/log | cut -d' ' -f3)
[ -n "$S" ] && [ -n "$I" ] ||
  { echo "FAIL mini-maild did not start: $(cat $W/log)"; exit 1; }

fail=0
# what $W/out should have: its line, or the whole of it
has() { grep -q -- "$1" $W/out || { echo "FAIL $2: $(cat $W/out)"; fail=1; }; }
is() { [ "$(cat $W/out)" = "$1" ] || { echo "FAIL $2:"; cat $W/out; fail=1; }; }

# sent
from='From: Alice <alice@ix>\nTo: Bob <bob@ix>, carol@elsewhere\n'
body='Subject: lunch\n\nNoon?\n.a line with a dot\n'
printf "${from}Bcc: dave@ix\n$body" > $W/m
printf "$from$body" > $W/want
echo secret | timeout 20 $PIM -s $S -plain -u alice@ix send $W/m > $W/out 2>&1
has '^sent to 2, refused: 550 not a relay' "the outcome"
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

# read: erin's mailbox, a question, its answer, a newsletter
printf 'From: Alice <alice@ix>\nTo: erin@ix\nSubject: the plan
Date: Thu, 29 Oct 2026 10:00:00 +0100\nMessage-ID: <1@ix>

See you at noon.\n' > $W/a
printf 'From: Carol <carol@ix>\nTo: erin@ix\nSubject: Re: the plan
Date: Thu, 29 Oct 2026 11:00:00 +0100\nMessage-ID: <2@ix>
References: <1@ix>\nContent-Type: text/plain; charset=windows-1252
Content-Transfer-Encoding: quoted-printable

=93Yes=94, =E0 midi.\n' > $W/b
printf 'From: news@ix\nTo: erin@ix\nSubject: weekly\n\nnews\n' > $W/c
for m in a b c; do timeout 20 $PIM -s $S -plain send $W/$m > /dev/null; done
pim() { echo secret | timeout 20 $PIM -s $I -plain -u erin@ix "$@" > $W/out 2>&1; }
pim list
is "    3 *            news@ix              weekly
    2 * 2026-10-29 Carol (2)            Re: the plan" "two conversations, unread"
pim read 2
is "From: Carol <carol@ix>
To: erin@ix
Date: Thu, 29 Oct 2026 11:00:00 +0100
Subject: Re: the plan

“Yes”, à midi." "the answer read, UTF-8"
# a reply to all, edited, sent: to Carol, threaded, the text quoted
pim -all reply 2
cp $W/out $W/r
is "To: Carol <carol@ix>
Subject: Re: the plan
In-Reply-To: <2@ix>
References: <1@ix> <2@ix>



On Thu, 29 Oct 2026 11:00:00 +0100, Carol <carol@ix> wrote:
> “Yes”, à midi." "a reply's draft"
sed -i '0,/^$/s//\nAgreed./' $W/r
echo secret | timeout 20 $PIM -s $S -plain -u erin@ix send $W/r > $W/out 2>&1
is "sent to 1" "the reply sent"
f=$W/spool/carol/1
grep -q '^From: erin@ix$' $f && grep -q '^In-Reply-To: <2@ix>$' $f &&
  grep -q '^Content-Type: text/plain; charset=utf-8$' $f &&
  grep -q '^Agreed\.$' $f && grep -q '^> =E2=80=9CYes' $f ||
  { echo "FAIL the reply as carol has it:"; cat $f; fail=1; }
# a forward, a file attached: a draft, sent as one
pim forward 2
{ echo "To: dave@ix"; echo "Attach: $W/a"; cat $W/out; } > $W/fwd
echo secret | timeout 20 $PIM -s $S -plain -u erin@ix send $W/fwd > $W/out 2>&1
is "sent to 1" "the forward sent"
f=$W/spool/dave/2
grep -q '^Subject: Fwd: Re: the plan$' $f &&
  grep -q '^---------- Forwarded message ---------$' $f &&
  grep -q 'filename="a"' $f ||
  { echo "FAIL the forward as dave has it:"; cat $f; fail=1; }
pim -q from:carol list
is "    2   2026-10-29 Carol                Re: the plan" "a search; read now"
pim archive 3
pim list
is "    2 * 2026-10-29 Carol (2)            Re: the plan" "archived: out of INBOX"
pim -m '[Gmail]/All Mail' list
has '^    3 \*  *news@ix' "archived: kept in All Mail"
# snoozed on Thursday the 29th until monday: out of the Inbox, and back
# in it on Monday, its item saying so (the Inbox listed first: an item
# knows the UID of the mailbox it was last listed in)
pim list
pim -today 2026-10-29 snooze 2 monday
is "until 2026-11-02" "snoozed until the next Monday"
pim -today 2026-10-29 list
is "" "snoozed: out of the Inbox"
pim -today 2026-11-01 list
is "" "not yet on Sunday"
pim -today 2026-11-02 list
has "Carol (2)  *Re: the plan" "Monday: back in the Inbox"
grep -l '^woke: 2026-11-02' $PIM_STORE/items/* > /dev/null ||
  { echo "FAIL no item woke"; fail=1; }

# the password in the store's file, nothing on standard input; refused
# when others may read it
(umask 077; echo secret > $PIM_STORE/password)
timeout 20 $PIM -s $I -plain -u erin@ix list < /dev/null > $W/out 2>&1
has "Re: the plan" "the password from ~/.ix-pim/password"
chmod 644 $PIM_STORE/password
timeout 20 $PIM -s $I -plain -u erin@ix list < /dev/null > $W/out 2>&1
has "others may read it" "a password file others may read: refused"
rm $PIM_STORE/password

# All Mail in a French Gmail: mini-pim asks for [Gmail]/All Mail, and
# selects the mailbox LIST says is \All
$MAILD -p 0 -i 0 -a '[Gmail]/Tous les messages' $W/spool > $W/frlog 2>&1 &
fr=$!
n=0
until grep -q 'serving' $W/frlog || [ $n -ge 50 ]; do sleep 0.1; n=$((n + 1)); done
F=$(grep -o 'IMAP on [0-9.:]*' $W/frlog | cut -d' ' -f3)
echo secret | timeout 20 $PIM -s $F -plain -u erin@ix list \
  -m '[Gmail]/All Mail' > $W/out 2>&1
has '^    3 \*  *news@ix' "All Mail found by its \\All, its name French"
kill $fr; wait $fr 2> /dev/null
pim list
kill $pid; wait $pid 2> /dev/null
# offline: what the last list and read kept
pim -offline list
is "    2 * 2026-10-29 Carol (2)            Re: the plan" "offline: the last list"
pim -offline read 2
has "à midi" "offline: a message read before, from the cache"
pim -offline read 1
has "not read yet" "offline: one never read"
# the store (plan_pim.md, stage 2): Carol's message found among the
# items, a task made of answering it, and each found from the other
$PIM search from:carol is:message > $W/out
id=$(cut -d' ' -f1 $W/out)
case "$id" in mail:*) ;; *) echo "FAIL search: $(cat $W/out)"; fail=1;; esac
$PIM add task:answer title="answer Carol" due=2026-11-05 re=$id
$PIM search is:task before:2026-11-06 > $W/out
has '^task:answer  *task  *answer Carol$' "a task found by its day"
$PIM show $id > $W/out
has '^  re: task:answer  *task  *answer Carol$' "the message's page: the task"
$PIM set task:answer due= && $PIM show task:answer > $W/out
grep -q '^due:' $W/out && { echo "FAIL due= kept"; fail=1; }
has "^  re: $id  *message  *Re: the plan$" "the task's page: the message"
# People: Carol made a contact from her message; her page, the mail
$PIM -u erin@ix contact 2 > $W/out
is "contact:carol@ix" "the sender a contact"
$PIM people > $W/out
has '^contact:carol@ix  *contact  *Carol$' "the address book"
$PIM show contact:carol@ix > $W/out
has "^  $id  *message  *Re: the plan$" "a person's page: the mail with her"
# the calendar (plan_pim.md, stage 3): an event captured in a line,
# Carol found in People; an invitation's file imported; the day's
# agenda: a Tuesday's events, and the task late the day after its day
$PIM -today 2026-10-29 event lunch with carol tue 12:30 > $W/out
has '^when: 2026-11-03 12:30$' "an event's day and time from words"
has '^with: contact:carol@ix$' "an event's person from People"
printf 'BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:standup@ix\r
DTSTART:20261026T093000\r\nRRULE:FREQ=WEEKLY;BYDAY=MO,TU\r
SUMMARY:standup\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n' > $W/i.ics
$PIM import $W/i.ics > $W/out
has '^event:standup@ix  *event  *standup$' "an iCalendar file imported"
$PIM -today 2026-11-03 today > $W/out
has '^9:30  *standup$' "today: a repeating event's day"
has '^12:30  *lunch with carol$' "today: the event, after it by time"
$PIM set task:answer due=2026-11-05 && $PIM -today 2026-11-06 today > $W/out
has '^late  *answer Carol$' "today: the task, late"
timeout 20 $PIM -s $S -plain send $W/m > $W/out 2>&1 &&
  { echo "FAIL sent to a server not there"; fail=1; }
has "$S" "no reason said"

[ $fail = 0 ] &&
  echo "mini-pim, mini-maild: sent by SMTP, read by IMAP, archived, offline"
exit $fail
