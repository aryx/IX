# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# forty conversations in the Inbox, as a list of erin's would have kept
# them: more than a screen, a scrollbar
for n in $(seq 1 40); do
  $PIM add mail:$n stamp=message account=erin mailbox=INBOX uid=$n \
    "in=INBOX $n" thread=$n 'labels=(\Inbox)' 'flags=(\Seen)' \
    "from=Person $n <p$n@ix>" "subject=message number $n" \
    "date=Thu, 29 Oct 2026 10:00:00 +0000"
done
