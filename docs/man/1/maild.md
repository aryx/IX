\title{maild}{1}{network}

# NAME
maild – mail taken by SMTP and read by IMAP, on this machine

# SYNOPSIS
**maild**
[ **-p** *port* ]
[ **-i** *port* ]
[ **-d** *domain* ]
[ **-a** *name* ]
*spool*

# DESCRIPTION
*Maild* is the other end of \man{pim}{1}'s mail when it is not Gmail:
it takes mail for its *domain* by SMTP, keeps each message a file,
`spool/`*user*`/`*uid*, numbered as it comes, and serves them by IMAP,
with Gmail's extensions (labels, conversations, `X-GM-RAW` searches)
far enough for *pim*. It listens on 127.0.0.1 only, one client at a
time on either port, and takes any user and password: it is a test's
server, and why *pim*'s tests never talk to Gmail.

Its first line says where it serves; then each message taken is a
line, its user, its number and its subject. A message's flags and
labels (`\Inbox` when it comes) are kept while it runs, not written.

**-p** *port*
:    SMTP's port, 2525 when not said; 0, one the system chooses.

**-i** *port*
:    IMAP's port, 1143 when not said; 0 as for **-p**.

**-d** *domain*
:    The domain it takes mail for, `ix` when not said.

**-a** *name*
:    The name of the mailbox that has every message, Gmail's
     `[Gmail]/All Mail` when not said (a French Gmail's is
     `[Gmail]/Tous les messages`; *pim* finds it by its `\All`).

# EXAMPLES
```
maild /tmp/spool &
pim -s 127.0.0.1:2525 -plain send letter
echo secret | pim -s 127.0.0.1:1143 -plain -u bob@ix list
```

# SEE ALSO
\man{pim}{1}, \man{httpd}{1}

# DIAGNOSTICS
A port taken, or a spool that is not a directory, is said, and the
status is not empty.
