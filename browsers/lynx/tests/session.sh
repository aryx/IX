#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-lynx on two pages served by mini-httpd: the first opened, its
# link 1 followed, "b" to come back, a link that is not there, "q";
# what it says compared with session.expected (the port, the system's
# choice, written as PORT, the directory as TMP). Then -dump of a file, and of a page that is
# not there. No network but this machine's.
#
# usage: session.sh [-u] [dir]
#   -u   session.expected written from this run
#   dir  where _mk's programs are (browsers/lynx/mini-lynx,
#        networking/mini-httpd under it); default: dune's

HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(cd $HERE/../../.. && pwd)
update=; [ "${1:-}" = -u ] && { update=1; shift; }
if [ $# -ge 1 ]; then set -- $(realpath $1); LYNX=$1/browsers/lynx/mini-lynx; HTTPD=$1/networking/mini-httpd
else LYNX=$ROOT/_build/default/browsers/lynx/Lynx.exe; HTTPD=$ROOT/_build/default/networking/Httpd.exe; fi
W=$(mktemp -d); trap 'kill $pid 2> /dev/null; rm -rf $W' EXIT
mkdir $W/site
cat > $W/site/menu.html <<'END'
<!doctype html><title>Menu</title>
<h1>Menu</h1>
<p>Soup of the day. See the <a href="recipes.html">recipes</a> or go back <a href="/">home</a>.
<div>A block</div><div>and another.</div>
<table><tr><td>soup<td>4<tr><td>bread<td>1</table>
END
cat > $W/site/recipes.html <<'END'
<title>Recipes</title><h2>Soup</h2><ul><li>Water<li>Salt &amp; p&eacute;pper</ul><pre>
  boil
    it</pre><p>Back to the <a href=menu.html>menu</a>.
END
$HTTPD -p 0 $W/site > $W/log 2>&1 &
pid=$!
n=0; until grep -q 'serving' $W/log || [ $n -ge 50 ]; do sleep 0.1; n=$((n + 1)); done
port=$(grep -o '127.0.0.1:[0-9]*' $W/log | cut -d: -f2)
[ -n "$port" ] || { echo "FAIL mini-httpd did not start"; exit 1; }
{ printf '1\nb\n7\nq\n' | $LYNX -w 60 http://127.0.0.1:$port/menu.html
  echo "== -dump of a file"
  (cd $W/site && $LYNX -dump -w 40 recipes.html)
  echo "== a page that is not there"
  $LYNX -dump http://127.0.0.1:$port/nothing.html
} 2>&1 | sed "s/127.0.0.1:$port/127.0.0.1:PORT/g; s|$W|TMP|g" > $W/got
[ -n "$update" ] && { cp $W/got $HERE/session.expected; echo "session.expected written"; exit 0; }
diff $HERE/session.expected $W/got > $W/diff && echo "ok: mini-lynx's session" || { echo "FAIL mini-lynx's session:"; head -20 $W/diff; exit 1; }
