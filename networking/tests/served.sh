#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-curl reads what mini-httpd serves: a directory made here (a
# page, bytes of every value, a file of 300 KB, a name with a space, a
# directory with an index and one without), each file asked and
# compared with the one on the disk; then what is refused (above the
# directory, a file not there, a POST) and a redirection followed.
# No network but this machine's.
#
# usage: served.sh [dir]
#   dir: where mini-curl and mini-httpd are (default: dune's,
#        _build/default/networking; mini-mk's: _mk/7/networking)

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
if [ $# -ge 1 ]; then CURL=$1/mini-curl; HTTPD=$1/mini-httpd
else CURL=$ROOT/_build/default/networking/Curl.exe; HTTPD=$ROOT/_build/default/networking/Httpd.exe; fi
W=$(mktemp -d); trap 'kill $pid 2> /dev/null; rm -rf $W' EXIT
mkdir -p $W/site/sub $W/site/bare
echo '<!doctype html><title>hello</title><p>A page.' > $W/site/index.html
python3 -c 'import sys; sys.stdout.buffer.write(bytes(range(256)) * 4)' > $W/site/bytes.bin
python3 -c 'import random; r = random.Random(1); open(sys.argv[1], "wb").write(bytes(r.randrange(256) for _ in range(300000)))' $W/site/large.bin 2> /dev/null ||
  python3 -c 'import random, sys; r = random.Random(1); open(sys.argv[1], "wb").write(bytes(r.randrange(256) for _ in range(300000)))' $W/site/large.bin
echo 'a name with a space' > "$W/site/a name.txt"
echo '<p>sub' > $W/site/sub/index.html
echo 'x' > $W/site/bare/x.txt
echo 'secret' > $W/secret.txt

$HTTPD -p 0 $W/site > $W/log 2>&1 &
pid=$!
n=0; until grep -q 'serving' $W/log || [ $n -ge 50 ]; do sleep 0.1; n=$((n + 1)); done
U=$(grep -o 'http://127.0.0.1:[0-9]*' $W/log)
[ -n "$U" ] || { echo "FAIL mini-httpd did not start: $(cat $W/log)"; exit 1; }

fail=0
same() { # a URL's path, the file it is
  $CURL "$U$1" > $W/got 2> $W/err && cmp -s $W/got "$2" || { echo "FAIL $1: $(head -c 200 $W/err)"; fail=1; }
}
says() { # mini-curl's arguments, then what its output has
  local want=${@: -1}
  $CURL "${@:1:$#-1}" > $W/got 2>&1; grep -q "$want" $W/got || { echo "FAIL ${*:1:$#-1}: no \"$want\" in: $(head -c 200 $W/got)"; fail=1; }
}
same / $W/site/index.html
same /index.html $W/site/index.html
same /bytes.bin $W/site/bytes.bin
same /large.bin $W/site/large.bin
same /a%20name.txt "$W/site/a name.txt"
same /sub/ $W/site/sub/index.html
same '/index.html?x=1' $W/site/index.html
says -i $U/index.html 'Content-Type: text/html; charset=utf-8'
says -i $U/bytes.bin 'Content-Length: 1024'
says $U/bare/ '<li><a href="x.txt">x.txt</a>'
says -i $U/sub 'HTTP/1.1 301 Moved Permanently'
says -L $U/sub '<p>sub'
says -i $U/nothing 'HTTP/1.1 404 Not Found'
says -i $U/../secret.txt 'HTTP/1.1 403 Forbidden'
says -i $U/%2e%2e/secret.txt 'HTTP/1.1 403 Forbidden'
says -i -d a=1 $U/index.html 'HTTP/1.1 405 Method Not Allowed'
says -f $U/nothing 'mini-curl: the server answered 404'
says -v $U/index.html '> GET /index.html HTTP/1.1'
says ftp://127.0.0.1/ 'mini-curl'
# the system's curl, where there is one, reads the same server
if command -v curl > /dev/null; then
  curl -s $U/large.bin | cmp -s - $W/site/large.bin || { echo "FAIL curl reads another large.bin"; fail=1; }
fi
[ $fail = 0 ] && echo "ok: mini-curl and mini-httpd, $(grep -c . $W/log) lines of log"
exit $fail
