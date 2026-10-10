#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-netscape's profile (Browser_profile) and its cookies, the program
# run twice on a directory of its own: a page zoomed in, and the second
# run's frame is the zoomed one without a key; a window of another size
# (the flag window), and the second run's is that large; a server's cookie (a
# small one here, Python's) kept in cookies.txt if it has a date, said
# back by the second run, and seen by the page's script but the
# HttpOnly one.
# usage: browsers/netscape/tests/profile.sh [dir]
#   dir: where the program is (default: dune's, _build/default/browsers)
cd "$(dirname "$0")/../../.."
D=${1:-_build/default/browsers}/netscape
N=$D/Netscape.exe; [ -x $N ] || N=$D/netscape
T=$(mktemp -d); trap 'kill $SERVER 2>/dev/null; rm -rf $T' EXIT
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok $1"; else echo "FAIL $1: $2, not $3"; fail=1; fi; }
PAGE=browsers/netscape/tests/pages/pictures.html

# the zooms
$N -dump-frame 14 $T/in.ppm -fixed-time 1000 profile=off url=$PAGE -script 'Control:9-12,=:10,=:12' > /dev/null
$N -dump-frame 14 $T/first.ppm -fixed-time 1000 profile=$T/p url=$PAGE -script 'Control:9-12,=:10,=:12' > /dev/null
check "the zoom is written" "$(cat $T/p/preferences)" "zoom file 1.25"
$N -dump-frame 14 $T/second.ppm -fixed-time 1000 profile=$T/p url=$PAGE > /dev/null
check "and read: the second run's frame is the zoomed one" "$(cksum < $T/second.ppm)" "$(cksum < $T/in.ppm)"

# the window's size
$N -dump-frame 4 $T/w.ppm -fixed-time 1000 profile=$T/p window=1400x700 url=$PAGE > /dev/null
check "the window's size is written, the zoom kept" "$(tr '\n' ';' < $T/p/preferences)" "window 1400 700;zoom file 1.25;"
$N -dump-frame 4 $T/w2.ppm -fixed-time 1000 profile=$T/p url=$PAGE > /dev/null
check "and read: the second run's picture is that large" "$(head -c 15 $T/w2.ppm | tr "\n" " " | sed "s/ $//")" "P6 1400 700 255"

# the cookies
cat > $T/server.py <<'PY'
import http.server, sys
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        open(sys.argv[1], "a").write("%s Cookie: %s\n" % (self.path, self.headers.get("Cookie", "none")))
        body = b"<p id=out>?</p><script>document.cookie = 'js=3; Max-Age=3600'; document.title = document.cookie;</script>"
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(body)))
        if self.path == "/":
            self.send_header("Set-Cookie", "sid=42; Max-Age=3600; HttpOnly")
            self.send_header("Set-Cookie", "session=1")
            self.send_header("Set-Cookie", "old=1; Max-Age=0")
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a): pass
s = http.server.HTTPServer(("127.0.0.1", 0), H)
open(sys.argv[2], "w").write(str(s.server_port))
s.serve_forever()
PY
python3 $T/server.py $T/log $T/port & SERVER=$!
for i in 1 2 3 4 5 6 7 8 9 10; do [ -s $T/port ] && break; sleep 0.2; done
A=http://127.0.0.1:$(cat $T/port)
$N -dump-frame 20 $T/x.ppm -fixed-time 1000 profile=$T/p url=$A/ > /dev/null
check "the cookies with a date are written, the script's too" "$(grep -v '^#' $T/p/cookies.txt | cut -f1,2,3,4,6,7 | sort | tr '\t\n' ' ;')" "127.0.0.1 FALSE / FALSE js 3;"
check "the HttpOnly one marked" "$(grep '^#HttpOnly_' $T/p/cookies.txt | cut -f1,6,7 | tr '\t' ' ')" "#HttpOnly_127.0.0.1 sid 42"
check "its owner's alone" "$(stat -c %a $T/p/cookies.txt)" "600"
$N -dump-frame 20 $T/x.ppm -fixed-time 1000 profile=$T/p url=$A/again > /dev/null
check "the first request says none, the second run's says them back" "$(tr '\n' ';' < $T/log)" "/ Cookie: none;/again Cookie: sid=42; js=3;"
$N -dump-frame 20 $T/x.ppm -fixed-time 1000 profile=off url=$A/off > /dev/null
check "profile=off: none said" "$(tail -1 $T/log)" "/off Cookie: none"
exit $fail
